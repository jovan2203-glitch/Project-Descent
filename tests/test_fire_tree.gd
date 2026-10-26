@tool
extends McpTestSuite

# The Fire book's talents on the column-group layout (Talents.GROUPS): Steady Flame,
# Slagforged, Forge Heat, Pitch and Cinder, and the open ones. Their rules are in
# each spec's component and scripts/player/fire_talents.gd; the hooks are checked
# in the player's source.

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")

## Every talent of the book: key -> [group, ranks, the ability it needs ("" = none)].
## (The Ember Volley choice slot's two talents count as one slot.)
const TREE := {
	# Steady Flame.
	"fire_stoked_breath": ["Steady Flame", 4, ""], "fire_tempered_flame": ["Steady Flame", 3, "fireball"],
	"fire_pressure_valve": ["Steady Flame", 3, "ventflames"], "fire_lean_fuel": ["Steady Flame", 3, ""],
	"fire_banked_coals": ["Steady Flame", 2, ""], "fire_afterburn": ["Steady Flame", 3, ""],
	"fire_damped_embers": ["Steady Flame", 3, "embervolley"], "fire_wild_embers": ["Steady Flame", 3, "embervolley"],
	"fire_volley_targets": ["Steady Flame", 2, "embervolley"],
	"fire_blowback": ["Steady Flame", 3, ""], "fire_long_burn": ["Steady Flame", 3, ""],
	"fire_stoked_kiln": ["Steady Flame", 3, ""], "fire_hold_the_heat": ["Steady Flame", 3, ""],
	"fire_long_focus": ["Steady Flame", 3, ""], "fire_clean_burn": ["Steady Flame", 3, ""],
	"fire_big_spend": ["Steady Flame", 3, ""], "fire_warm_start": ["Steady Flame", 2, ""],
	"fire_low_flame": ["Steady Flame", 3, ""], "fire_stay_lit": ["Steady Flame", 3, ""],
	"fire_smoldering_focus": ["Steady Flame", 5, ""],
	# Slagforged.
	"fire_thick_slag": ["Slagforged", 4, ""], "fire_hot_iron": ["Slagforged", 3, ""],
	"fire_slag_mending": ["Slagforged", 3, ""], "fire_deep_brand": ["Slagforged", 3, "brand"],
	"fire_clinker": ["Slagforged", 3, ""], "fire_hard_crust": ["Slagforged", 3, ""],
	"fire_set_hard": ["Slagforged", 2, ""], "fire_red_iron": ["Slagforged", 3, ""],
	"fire_marked_iron": ["Slagforged", 3, ""], "fire_fuel_the_forge": ["Slagforged", 3, ""],
	"fire_deep_slag": ["Slagforged", 2, ""], "fire_riveted": ["Slagforged", 3, "redhotrivet"],
	"fire_heavy_hammer": ["Slagforged", 3, "forgeblow"], "fire_glowing_seams": ["Slagforged", 3, ""],
	"fire_long_shell": ["Slagforged", 2, "moltenshell"], "fire_spatter": ["Slagforged", 3, ""],
	"fire_quick_temper": ["Slagforged", 3, ""], "fire_heat_shimmer": ["Slagforged", 3, ""],
	"fire_molten_heart": ["Slagforged", 5, ""],
	# The open talents.
	"fire_flash_point": ["Open", 3, ""], "fire_forge_hardened": ["Open", 3, ""],
	"fire_lingering_embers": ["Open", 3, ""], "fire_controlled_burn": ["Open", 3, ""],
	"fire_feed_the_flames": ["Open", 3, ""], "fire_last_ember": ["Open", 2, ""],
	"fire_tempered": ["Open", 3, ""], "fire_warm_blood": ["Open", 3, ""],
	# Forge Heat.
	"fire_white_heat": ["Forge Heat", 4, ""], "fire_bright_sparks": ["Forge Heat", 3, ""],
	"fire_slow_cooling": ["Forge Heat", 3, ""], "fire_afterglow": ["Forge Heat", 3, "quench"],
	"fire_spark_bite": ["Forge Heat", 3, ""], "fire_fresh_tinder": ["Forge Heat", 3, ""],
	"fire_hard_quench": ["Forge Heat", 3, ""], "fire_wide_flare": ["Forge Heat", 2, "flare"],
	"fire_banked_fire": ["Forge Heat", 3, "quench"], "fire_hammer_rhythm": ["Forge Heat", 3, ""],
	"fire_fold_again": ["Forge Heat", 2, "foldsteel"], "fire_deep_sear": ["Forge Heat", 3, ""],
	"fire_overheat": ["Forge Heat", 3, ""], "fire_steady_arm": ["Forge Heat", 3, ""],
	"fire_long_blast": ["Forge Heat", 2, "blastfurnace"], "fire_cold_steel": ["Forge Heat", 3, ""],
	"fire_quick_forge": ["Forge Heat", 3, ""], "fire_fed_furnace": ["Forge Heat", 3, ""],
	"fire_molten_edge": ["Forge Heat", 5, ""],
	# Pitch and Cinder.
	"fire_sticky_pitch": ["Pitch and Cinder", 4, ""], "fire_light_string": ["Pitch and Cinder", 3, ""],
	"fire_big_flash": ["Pitch and Cinder", 3, ""], "fire_long_coat": ["Pitch and Cinder", 3, ""],
	"fire_spreading_fire": ["Pitch and Cinder", 2, ""], "fire_dripping": ["Pitch and Cinder", 3, ""],
	"fire_double_coat": ["Pitch and Cinder", 2, "pitcharrow"], "fire_hot_shafts": ["Pitch and Cinder", 3, ""],
	"fire_second_light": ["Pitch and Cinder", 3, "touchoff"], "fire_ember_bed": ["Pitch and Cinder", 3, ""],
	"fire_wide_rain": ["Pitch and Cinder", 2, "cinderrain"], "fire_fuel_run": ["Pitch and Cinder", 3, ""],
	"fire_patient_fire": ["Pitch and Cinder", 3, ""], "fire_kindle_pack": ["Pitch and Cinder", 3, ""],
	"fire_long_brush": ["Pitch and Cinder", 2, "brushfire"], "fire_steady_bow": ["Pitch and Cinder", 3, ""],
	"fire_clean_shot": ["Pitch and Cinder", 3, ""], "fire_fire_line": ["Pitch and Cinder", 3, ""],
	"fire_pitch_black": ["Pitch and Cinder", 5, ""],
}
## Each spec's capstone (its bottom-row talent).
const CAPSTONES := {"Steady Flame": "fire_smoldering_focus", "Slagforged": "fire_molten_heart",
	"Forge Heat": "fire_molten_edge", "Pitch and Cinder": "fire_pitch_black"}

func suite_name() -> String:
	return "fire_tree"

func _src() -> String:
	return PlayerSource.text()

func _near(a: float, b: float, msg: String = "") -> void:
	assert_true(absf(a - b) <= 0.001, "%s (%s vs %s)" % [msg, a, b])

# --- The tree ----------------------------------------------------------------------------

func test_the_whole_book_is_designed() -> void:
	var ids := Talents.in_tree("fire")
	assert_eq(ids.size(), TREE.size() - 1, "every slot of the Fire book holds a talent (the choice slot holds two)")
	for id in ids:
		assert_false(bool(Talents.get_talent(id).get("placeholder", true)), "%s is designed" % id)
	var names := {}
	for key in TREE:
		var id := Talents.id_for_key(key)
		assert_ne(id, "", "%s exists" % key)
		assert_eq(Talents.group_of(id), str(TREE[key][0]), "%s: its spec's column group" % key)
		assert_eq(Talents.max_rank(id), int(TREE[key][1]), "%s: ranks" % key)
		assert_eq(Talents.required_ability(id), str(TREE[key][2]), "%s: the ability it needs" % key)
		assert_true(TalentIcons.has_icon(id), "%s has an icon" % key)
		var tip := Talents.tooltip(id, 0)
		assert_false(tip.contains("{") or tip.contains("}"), "%s: its text is filled in: %s" % [key, tip])
		var name := str(Talents.get_talent(id)["name"])
		assert_false(names.has(name), "%s: one talent per name" % name)
		names[name] = true
	for gone in ["fire_cool_under_fire", "fire_deep_crucible", "fire_kindling", "fire_forge_heat"]:
		assert_eq(Talents.id_for_key(gone), "", "%s is gone" % gone)

## The agreed shape: 19 slots and ~50+ ranks per spec, few that need one ability.
func test_each_spec_is_deep_and_mostly_keyword_talents() -> void:
	var slots := {}
	var ranks := {}
	var requires := 0
	for key in TREE:
		var g := str(TREE[key][0])
		if key == "fire_wild_embers":
			continue   # (the choice slot's second talent: one slot, one set of ranks)
		slots[g] = int(slots.get(g, 0)) + 1
		ranks[g] = int(ranks.get(g, 0)) + int(TREE[key][1])
		if str(TREE[key][2]) != "":
			requires += 1
	for g in CAPSTONES:
		assert_eq(int(slots[g]), 19, "%s: 19 talents" % g)
		assert_true(int(ranks[g]) >= 50 and int(ranks[g]) <= 60, "%s: %d ranks" % [g, int(ranks[g])])
	assert_true(float(requires) / (TREE.size() - 1) <= 0.25, "at most a quarter need one ability (%d of %d)" % [requires, TREE.size() - 1])

func test_column_groups() -> void:
	assert_eq(Talents.columns_of("fire"), 13)
	assert_eq(Talents.groups_of("fire").size(), 5)
	assert_ne(str(Talents.layout("fire")), str(Talents.layout("martial")), "a layout of its own")
	for g in CAPSTONES:
		var id := Talents.id_for_key(str(CAPSTONES[g]))
		assert_eq(Talents.tier_of(id), Talents.ROWS - 1, "%s's capstone is in the bottom row" % g)
		assert_true(Talents.capstone_gated(id))
		assert_contains(Talents.tooltip(id, 0), "Needs %d points in %s" % [Balance.CAPSTONE_GATE, g])
	assert_false(Talents.capstone_gated(Talents.id_for_key("fire_stoked_breath")))
	assert_false(Talents.capstone_gated(Talents.id_for_key("fire_tempered")), "the Open column has no gate")
	assert_true(Talents.TREE_VERSION >= 6, "the new tree refunds every point")
	for link in Talents.links_in_tree("fire"):
		assert_eq(Talents.group_of(link[0]), Talents.group_of(link[1]), "a link stays in its spec's ribbon")
		assert_eq(Talents.col_of(link[0]), Talents.col_of(link[1]), "straight down one column")
		assert_true(Talents.tier_of(link[1]) - Talents.tier_of(link[0]) >= 2, "it skips a row")

# --- Rules -------------------------------------------------------------------------------

func test_talent_maths() -> void:
	_near(FireTalentsKit.big_spend_pct(Balance.BIG_SPEND_FURY, 15.0), 15.0, "Big Spend at the line")
	_near(FireTalentsKit.big_spend_pct(Balance.BIG_SPEND_FURY - 1.0, 15.0), 0.0)
	_near(FireTalentsKit.low_flame_pct(Balance.LOW_FLAME_CRIT - 0.1, 9.0), 9.0, "Low Flame below the line")
	_near(FireTalentsKit.low_flame_pct(Balance.LOW_FLAME_CRIT, 9.0), 0.0)
	_near(FireTalentsKit.molten_heart_pct(Balance.MOLTEN_HEART_ABOVE, 10.0), 0.0, "Molten Heart: only stacks above the line")
	_near(FireTalentsKit.molten_heart_pct(Balance.MOLTEN_HEART_ABOVE + 3, 10.0), 30.0)
	_near(FireBowKit.pitch_speed("burning", 2, 2.0), 1.0 + (Balance.PITCH_LAYER_SPEED_PCT + 2.0) / 100.0 * 2.0, "Sticky Pitch")
	assert_eq(FireBowKit.layers_from("pitcharrow", false, 2), Balance.PITCH_ARROW_LAYERS + 2, "Double Coat")
	assert_true(FireTalentsKit.is_arrow("auto_ranged", PackedStringArray()))
	assert_true(FireTalentsKit.is_arrow("coalshot", Abilities.tags_of("coalshot")))
	assert_false(FireTalentsKit.is_arrow("dot_cinderrain", PackedStringArray(["Ranged", "Ability"])), "a tick is no arrow")

func test_hooks_are_in_place() -> void:
	var src := _src()
	assert_contains(src, "_fire_talents_outgoing(info)")
	assert_contains(src, "_fire_talents_incoming(info)")
	assert_contains(src, "out.append_array(crit_hit_bonus(info))   # Cold Steel")
	assert_contains(src, "_on_combat_start()   # Warm Start")
	assert_contains(src, "_talent(\"fire_lean_fuel\")")
	assert_contains(src, "_talent(\"fire_light_string\")")
	assert_contains(src, "_talent(\"fire_hold_the_heat\")")
	assert_contains(src, "cooldown_rate(str(id))   # (Steady Arm)")
	assert_contains(src, "_talent(\"fire_hammer_rhythm\")")
	for label in ["Clean Burn", "Low Flame", "Stoked Kiln", "Big Spend", "Red Iron", "Spark Bite", "Hard Quench", "Deep Sear",
			"Dripping", "Fire Line", "Big Flash", "Patient Fire", "Clean Shot", "Pitch Black", "Heat Shimmer", "Molten Heart", "Marked Iron"]:
		assert_contains(src, "\"%s\")" % label, "%s has its own damage line" % label)
	assert_eq(Abilities.COOLDOWN_TALENTS.get("redhotrivet", ""), "fire_riveted", "Riveted")
	assert_eq(str(Abilities.RADIUS_TALENTS["cinderrain"][0]), "fire_wide_rain", "Wide Rain")
