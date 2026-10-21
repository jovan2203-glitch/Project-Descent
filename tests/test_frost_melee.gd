@tool
extends McpTestSuite

# Frost melee: the tank, Glacier Wall (a one-handed weapon and a shield; Ice
# Layers), and the DPS, Frostbitten Steel (a two-handed weapon; Glaze).
# Rules: scripts/player/frost_glacier.gd and frost_steel.gd.

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const Talents = preload("res://scripts/talents.gd")
const Runes = preload("res://scripts/runes.gd")
const Keywords = preload("res://scripts/core/keywords.gd")
const Details = preload("res://scripts/core/details.gd")
const StatusContainer = preload("res://scripts/core/status_container.gd")
const SaveSystemScript = preload("res://scripts/save_system.gd")

const TANK := ["rimeslash", "shatteringslam", "coldshoulder", "rimequake", "hailcoat", "hardrime", "glacialbulwark"]
const DPS := ["froststrike", "hoarcleave", "calving", "icebreaker", "rimeedge", "bitteredge", "blackfrost"]

func suite_name() -> String:
	return "frost_melee"

func _src() -> String:
	return PlayerSource.text()

func _spec(name: String) -> Array:
	for s in Abilities.SPECS["frost"]:
		if s[0] == name:
			return s[1]
	return []

func _near(a: float, b: float, msg: String = "") -> void:
	assert_true(absf(a - b) <= 0.001, "%s (%s vs %s)" % [msg, a, b])

# --- The kits --------------------------------------------------------------------------

func test_the_tank_kit_is_a_frost_spec() -> void:
	assert_eq(_spec("Glacier Wall"), TANK, "the Glacier Wall spec holds the kit")
	for id in TANK:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s loads" % id)
		assert_eq(Abilities.category_of(id), "frost", "%s is Frost" % id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is drafted, with a Skill Card" % id)
		assert_true(r.tags.has("Ability") and r.tags.has("Frost"), "%s is a Frost ability" % id)
		assert_eq(int(r.weapon_requirement), 1, "%s needs a melee weapon" % id)
		assert_true(bool(r.requires_shield), "%s needs a shield" % id)
		assert_false(bool(r.requires_two_hand), "%s is not for a two-hander" % id)
		var tip := Abilities.tooltip(id)
		assert_false(tip.contains("{") or tip.contains("}"), "%s: every number in its text is filled in: %s" % [id, tip])
		assert_contains(tip, "a shield", "%s says it needs a shield" % id)
	for id in ["coldshoulder", "rimequake", "hardrime"]:
		assert_true(Abilities.resource_of(id) in ["fury", ""], "%s: Fury or free" % id)
	assert_true(Abilities.generated_of("rimeslash") > 0 and Abilities.generated_of("shatteringslam") > 0, "the builders give Fury")
	assert_true(Abilities.OFF_GCD.has("coldshoulder"), "the taunt is off the global cooldown")
	assert_true(Abilities.LONG_REACH.has("coldshoulder"), "... and reaches past the weapon")
	assert_true(Abilities.OFF_GCD.has("glacialbulwark"))

func test_the_dps_kit_is_a_frost_spec() -> void:
	assert_eq(_spec("Frostbitten Steel"), DPS, "the Frostbitten Steel spec holds the kit")
	for id in DPS:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s loads" % id)
		assert_eq(Abilities.category_of(id), "frost", "%s is Frost" % id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is drafted, with a Skill Card" % id)
		assert_eq(int(r.weapon_requirement), 1, "%s needs a melee weapon" % id)
		assert_true(bool(r.requires_two_hand), "%s needs a two-handed weapon" % id)
		assert_false(bool(r.requires_shield))
		var tip := Abilities.tooltip(id)
		assert_false(tip.contains("{") or tip.contains("}"), "%s: every number in its text is filled in: %s" % [id, tip])
		assert_contains(tip, "two-handed", "%s says it needs a two-hander" % id)
	assert_eq(Abilities.cost_of("froststrike"), 0.0, "Winter's Bite builds Fury now")
	assert_true(Abilities.generated_of("froststrike") > 0 and Abilities.generated_of("hoarcleave") > 0)
	assert_true(Abilities.cost_of("icebreaker") > 0.0 and Abilities.cost_of("calving") > 0.0, "the finishers spend Fury")
	assert_true(Abilities.OFF_GCD.has("bitteredge"))
	assert_eq(str(Abilities.get_resource("bitteredge").on_hit_effect.id), "frozen", "Bitter Edge Freezes again")
	assert_eq(str(Abilities.get_resource("hoarcleave").on_hit_effect.id), "chilled")
	assert_eq(str(Abilities.get_resource("calving").on_hit_effect.id), "chilled")

func test_cold_comfort_keeps_rime_shell_alone() -> void:
	assert_eq(_spec("Cold Comfort"), ["rimeshell"])
	assert_false(Abilities.HEALS.has("rimeslash"), "Rime Slash gives no Rime Shell any more")

func test_skill_cards_climb_the_levels() -> void:
	var tank := TANK.map(func(id): return SkillCards.level_of(id))
	var dps := DPS.map(func(id): return SkillCards.level_of(id))
	assert_eq(tank, [2, 4, 6, 8, 10, 12, 16])
	assert_eq(SkillCards.level_of("froststrike"), 2, "the builder comes first")
	for lv in dps:
		assert_true(int(lv) >= 2 and int(lv) <= 50)

# --- Ice Layers ------------------------------------------------------------------------

func test_ice_layers() -> void:
	assert_eq(GlacierKit.max_layers(false), Balance.ICE_LAYERS_MAX)
	assert_eq(GlacierKit.max_layers(true), Balance.ICE_SHELF_LAYERS, "Rune of the Ice Shelf")
	assert_eq(GlacierKit.layer_amount(1000, 0.0, 0.0), int(round(1000.0 * Balance.ICE_LAYER_PCT / 100.0)))
	assert_eq(GlacierKit.layer_amount(1000, 10.0, 10.0), int(round(1000.0 * Balance.ICE_LAYER_PCT / 100.0 * 1.1 * 1.1)), "Rime Ward and Deep Strata")
	assert_eq(GlacierKit.layers_in(0, 40), 0)
	assert_eq(GlacierKit.layers_in(40, 40), 1)
	assert_eq(GlacierKit.layers_in(41, 40), 2, "a Layer partly used up still counts")
	assert_eq(GlacierKit.layers_in(200, 40), 5)
	assert_eq(GlacierKit.absorb_after(0, 40, 2, 5), 80)
	assert_eq(GlacierKit.absorb_after(60, 40, 9, 5), 200, "never past the cap")
	assert_eq(GlacierKit.rime_slash_layers(1), Balance.RIME_SLASH_LAYERS)
	assert_eq(GlacierKit.rime_slash_layers(Balance.RIME_SLASH_MANY_HITS), Balance.RIME_SLASH_LAYERS_MANY)
	_near(GlacierKit.quake_mult(0, 10.0), 1.0)
	_near(GlacierKit.quake_mult(5, 10.0), 1.5)
	_near(GlacierKit.slam_layers_coef(0, 0.0), 0.0)
	_near(GlacierKit.slam_layers_coef(5, 0.0), Balance.SHATTER_SLAM_PER_LAYER * 5.0)
	_near(GlacierKit.slam_layers_coef(5, 40.0), Balance.SHATTER_SLAM_PER_LAYER * 5.0 * 1.4, "Packed Ice")
	_near(GlacierKit.layer_fury(0.0), Balance.ICE_LAYER_FURY)
	_near(GlacierKit.layer_fury(6.0), Balance.ICE_LAYER_FURY + 6.0, "Cold Fury")

func test_a_hit_on_the_shield_breaks_whole_layers() -> void:
	# The Layers are one absorb: hits use it up and the Layers left are counted from it.
	var owner_node: Node = track(Node.new())
	var st: Node = StatusContainer.new()
	st.name = "Status"
	owner_node.add_child(st)
	var fx := StatusContainer.make_buff(GlacierKit.LAYERS_FX, "Ice Layers", "armor%", 0.0, Balance.ICE_LAYERS_TIME, 5, Color.WHITE)
	assert_true(st.apply(fx, owner_node))
	st.set_absorb(GlacierKit.LAYERS_FX, 200)
	assert_eq(GlacierKit.layers_in(st.absorb_left(GlacierKit.LAYERS_FX), 40), 5)
	assert_eq(st.absorb_damage(50), 0, "all of it soaked")
	assert_eq(GlacierKit.layers_in(st.absorb_left(GlacierKit.LAYERS_FX), 40), 4, "one Layer broke")
	assert_eq(st.absorb_damage(300), 150, "what is left gets through")
	assert_false(st.has(GlacierKit.LAYERS_FX), "the last Layer breaking ends them")

# --- Glaze -----------------------------------------------------------------------------

func test_glaze() -> void:
	assert_eq(FrostSteelKit.glaze_after(0, 1), 1)
	assert_eq(FrostSteelKit.glaze_after(4, 3), Balance.GLAZE_MAX, "never past the cap")
	_near(FrostSteelKit.glaze_mult(0, 8.0), 1.0)
	_near(FrostSteelKit.glaze_mult(5, 8.0), 1.4)
	_near(FrostSteelKit.glaze_mult(9, 8.0), 1.4, "only GLAZE_MAX counts")
	assert_eq(FrostSteelKit.hoarcleave_glaze(0), 0)
	assert_eq(FrostSteelKit.hoarcleave_glaze(1), Balance.HOARCLEAVE_GLAZE)
	assert_eq(FrostSteelKit.hoarcleave_glaze(9), Balance.HOARCLEAVE_MAX_GLAZE)
	_near(FrostSteelKit.ice_fall_mult(0, 12.0), 1.0)
	_near(FrostSteelKit.ice_fall_mult(9, 12.0), 1.0 + 0.12 * Balance.ICE_FALL_MAX_OTHERS, "Ice Fall counts up to its cap")
	_near(FrostSteelKit.glinting_crit(5, 1.0), 5.0)
	_near(FrostSteelKit.glinting_crit(9, 1.0), 5.0)

# --- Hooks -----------------------------------------------------------------------------

func test_hooks_are_in_place() -> void:
	var src := _src()
	assert_contains(src, "_glacier_use(id, res, w)   # Frost tank: Glacier Wall")
	assert_contains(src, "_steel_use(id, res, w)   # Frost DPS: Frostbitten Steel")
	assert_contains(src, "_glacier_precheck(id)   # Frost tank")
	assert_contains(src, "_steel_precheck(id)   # Frost DPS")
	assert_contains(src, "\t_tick_glacier()\n")
	assert_contains(src, "chance = adjust_crit(info, chance)   # Frost DPS: Glinting Rime")
	var cd := (load("res://scripts/player/fire_cooldowns.gd") as GDScript).source_code
	assert_contains(cd, "player.glacier._glacier_hit_taken(info)")
	var runes := (load("res://scripts/player/frost_runes_talents.gd") as GDScript).source_code
	assert_contains(runes, "player.frost_steel._bite_landed(was_cold)")
	assert_contains(runes, "player.frost_steel.black_frost_on()")
	assert_contains(runes, "player.frost_steel._hoar_blade_on_hit(info)")
	var more := (load("res://scripts/player/frost_more.gd") as GDScript).source_code
	assert_contains(more, "player.frost_steel._icebreaker_glaze()")
	assert_contains(more, "player.frost_steel._rime_edge_glaze(was_cold)")

func test_keywords_and_meter() -> void:
	for k in ["ice_layers", "glaze"]:
		assert_true(Keywords.KEYWORDS.has(k), "%s is a keyword" % k)
		assert_false(Keywords.keyword_text(k).contains("{"), "%s explains itself" % k)
	assert_true(Details.HIT_NAMES.has("hoar_blade"), "the Hoar Blade's hit has its own meter line")

# --- Talents and runes -----------------------------------------------------------------

const TALENTS := [
	# key, ability it needs ("" = none), ranks
	["frost_cold_sweep", "hoarcleave", 3], ["frost_ice_fall", "calving", 3], ["frost_long_dark", "blackfrost", 3],
	["frost_glinting_rime", "", 5], ["frost_packed_ice", "shatteringslam", 3], ["frost_turned_backs", "coldshoulder", 2],
	["frost_cold_fury", "", 3], ["frost_regelation", "hardrime", 3], ["frost_old_ice", "glacialbulwark", 3],
	["frost_deep_strata", "", 5], ["frost_long_glaze", "", 3], ["frost_biting_hold", "bitteredge", 2],
	["frost_deep_tremor", "rimequake", 3],
]

## Where the melee talents sit (the tree's layout comment in talents.gd says why).
const SLOTS := {
	"frost_cold_fury": "frost_r1c4", "frost_cold_sweep": "frost_r3c3", "frost_packed_ice": "frost_r3c5",
	"frost_biting_hold": "frost_r6c2", "frost_deep_tremor": "frost_r6c6", "frost_long_glaze": "frost_r7c3",
	"frost_turned_backs": "frost_r7c6", "frost_ice_fall": "frost_r8c3", "frost_regelation": "frost_r8c5",
	"frost_long_dark": "frost_r9c3", "frost_old_ice": "frost_r9c5", "frost_glinting_rime": "frost_r10c2",
	"frost_deep_strata": "frost_r10c6", "frost_instinct": "frost_r7c5",
}

func test_talents() -> void:
	for t in TALENTS:
		var id := Talents.id_for_key(str(t[0]))
		assert_true(id != "", "%s exists" % t[0])
		var d: Dictionary = Talents.get_talent(id)
		assert_eq(str(d.get("requires", "")), str(t[1]), "%s needs %s" % [t[0], t[1]])
		assert_eq(int(d.get("max_rank", 0)), int(t[2]), "%s ranks" % t[0])
	assert_true(Talents.has_capstone(Talents.id_for_key("frost_glinting_rime")))
	assert_true(Talents.has_capstone(Talents.id_for_key("frost_deep_strata")))
	assert_true(bool(Talents.get_talent("frost_r8c4").get("placeholder", false)), "Thick Hide's old slot stays empty")
	for key in SLOTS:
		assert_eq(Talents.id_for_key(str(key)), str(SLOTS[key]), "%s sits in %s" % [key, SLOTS[key]])

func test_frozen_instinct_keeps_its_points() -> void:
	# Frozen Instinct moved from row 7 column 6 to column 5 (save version 11 -> 12);
	# its old slot holds Turned Backs now, which must not get those points.
	assert_eq(SaveSystemScript.VERSION, 12)
	assert_eq(Talents.rearranged({"frost_r7c6": 3, "frost_r1c1": 2}, Talents.FROST_MELEE_MOVED, []),
		{"frost_r7c5": 3, "frost_r1c1": 2})
	var cfg := ConfigFile.new()
	cfg.set_value("talents", "ranks", {"frost_r7c6": 2})
	var ss: Node = track(SaveSystemScript.new())
	ss._migrate_11_to_12(cfg)
	assert_eq(cfg.get_value("talents", "ranks", {}), {"frost_r7c5": 2}, "the points follow Frozen Instinct")
	assert_eq(Talents.get_talent("frost_r7c6").get("name", ""), "Turned Backs")

func test_runes() -> void:
	for id in ["ice_shelf", "hoar_blade", "lone_floe"]:
		assert_true(Runes.ALL.has(id), "%s exists" % id)
		assert_false(Runes.description(id).contains("{"), "%s: every number filled in" % id)
	assert_eq(Runes.rarity_name("ice_shelf"), "Epic")
	assert_eq(Runes.rarity_name("hoar_blade"), "Epic")
	assert_eq(Runes.rarity_name("lone_floe"), "Rare")
	assert_eq(int(Runes.get_resource("lone_floe").max_equipped), 1, "the Lone Floe is unique")
