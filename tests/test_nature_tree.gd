@tool
extends McpTestSuite

# The Nature book's talents on the ribbon layout (Talents.GROUPS): Thornweaver,
# Shepherd, Colossus, Venomstring and the open ones. Their rules are in each spec's
# component (scripts/player/nature_*.gd) and nature_talents_open.gd; the hooks are
# checked in the player's source. (The older talents' rules: tests/test_nature_talents.gd.)

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const Details = preload("res://scripts/core/details.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")

## Every talent of the book: key -> [group, ranks, the ability it needs ("" = none)].
const TREE := {
	# Thornweaver.
	"nature_compost": ["Thornweaver", 1, "thornshot"], "nature_thick_mulch": ["Thornweaver", 2, ""],
	"nature_hunting_party": ["Thornweaver", 4, "briartiger"], "nature_bramble_burst": ["Thornweaver", 3, ""],
	"nature_well_rotted": ["Thornweaver", 3, ""], "nature_rich_soil": ["Thornweaver", 3, ""],
	"nature_second_growth": ["Thornweaver", 3, "mossback"], "nature_circling_hawk": ["Thornweaver", 3, "thornwing"],
	"nature_fertile_ground": ["Thornweaver", 3, "chokingvipers"], "nature_long_roots": ["Thornweaver", 3, ""],
	"nature_tight_weave": ["Thornweaver", 3, ""], "nature_old_roots": ["Thornweaver", 3, ""],
	"nature_steady_weave": ["Thornweaver", 3, ""], "nature_harvest": ["Thornweaver", 3, ""],
	"nature_leaf_litter": ["Thornweaver", 3, ""], "nature_hunted": ["Thornweaver", 3, ""],
	"nature_lush": ["Thornweaver", 3, ""], "nature_quickening": ["Thornweaver", 2, ""],
	"nature_overgrown": ["Thornweaver", 5, ""],
	# Shepherd.
	"nature_running_herd": ["Shepherd", 4, "fawn"], "nature_morning_dew": ["Shepherd", 3, "dewfall"],
	"nature_old_bark": ["Shepherd", 3, "rootguard"], "nature_return_flight": ["Shepherd", 3, "owl"],
	"nature_second_bud": ["Shepherd", 3, ""], "nature_deep_bloom": ["Shepherd", 3, "heartwoodelk"],
	"nature_long_bloom": ["Shepherd", 2, ""], "nature_heavy_petals": ["Shepherd", 3, ""],
	"nature_soft_weave": ["Shepherd", 3, ""], "nature_pollen": ["Shepherd", 3, ""], "nature_canopy": ["Shepherd", 3, ""],
	"nature_in_full_flower": ["Shepherd", 3, ""], "nature_close_herd": ["Shepherd", 3, ""],
	"nature_new_shoots": ["Shepherd", 3, ""], "nature_nectar": ["Shepherd", 3, ""],
	"nature_patient_hands": ["Shepherd", 3, ""], "nature_wide_grove": ["Shepherd", 2, ""],
	"nature_morning_mist": ["Shepherd", 3, ""], "nature_evergreen": ["Shepherd", 5, ""],
	# The open talents.
	"nature_rough_bark": ["Open", 3, ""], "nature_green_thumb": ["Open", 3, ""], "nature_undergrowth": ["Open", 3, ""],
	"nature_clinging_vines": ["Open", 2, ""], "nature_startle": ["Open", 3, ""], "nature_pack_hunter": ["Open", 3, ""],
	"nature_tending": ["Open", 3, ""], "nature_food_chain": ["Open", 3, ""], "nature_hibernate": ["Open", 2, ""],
	# Colossus.
	"nature_groundswell": ["Colossus", 3, ""], "nature_thick_sap": ["Colossus", 4, "heartsap"],
	"nature_crushing_grip": ["Colossus", 3, "giantshands"], "nature_rising_sap": ["Colossus", 3, ""],
	"nature_heavy_limbs": ["Colossus", 3, ""], "nature_broad_fist": ["Colossus", 2, "vinefist"],
	"nature_spreading_roots": ["Colossus", 3, "stomp"], "nature_firm_hold": ["Colossus", 3, ""],
	"nature_wide_awake": ["Colossus", 3, "awaken"], "nature_long_sap": ["Colossus", 2, ""],
	"nature_sap_run": ["Colossus", 3, ""], "nature_taproot": ["Colossus", 3, ""], "nature_long_limbs": ["Colossus", 3, ""],
	"nature_called_out": ["Colossus", 3, ""], "nature_creaking_bark": ["Colossus", 3, ""],
	"nature_brimming": ["Colossus", 3, ""], "nature_woodgrain": ["Colossus", 3, ""], "nature_old_oak": ["Colossus", 3, ""],
	"nature_old_growth": ["Colossus", 5, ""],
	# Venomstring.
	"nature_long_fangs": ["Venomstring", 3, "fangarrow"], "nature_lingering_venom": ["Venomstring", 4, "venomburst"],
	"nature_slow_acting": ["Venomstring", 2, ""], "nature_virulent": ["Venomstring", 3, ""],
	"nature_spring_trap": ["Venomstring", 2, "coilback"], "nature_hungry_venom": ["Venomstring", 2, ""],
	"nature_fresh_host": ["Venomstring", 3, ""], "nature_double_dose": ["Venomstring", 3, ""],
	"nature_quick_venom": ["Venomstring", 3, ""], "nature_swollen": ["Venomstring", 3, ""],
	"nature_full_brew": ["Venomstring", 3, ""], "nature_full_glands": ["Venomstring", 3, ""],
	"nature_spare_venom": ["Venomstring", 3, ""], "nature_running_venom": ["Venomstring", 3, ""],
	"nature_dragging_feet": ["Venomstring", 3, ""], "nature_dripping_tips": ["Venomstring", 3, ""],
	"nature_final_bite": ["Venomstring", 3, ""], "nature_first_bite": ["Venomstring", 2, ""],
	"nature_soaked_through": ["Venomstring", 5, ""],
}
## Each spec's capstone (its bottom-row talent).
const CAPSTONES := {"Thornweaver": "nature_overgrown", "Shepherd": "nature_evergreen",
	"Colossus": "nature_old_growth", "Venomstring": "nature_soaked_through"}

func suite_name() -> String:
	return "nature_tree"

func _src() -> String:
	return PlayerSource.text()

func _near(a: float, b: float, msg: String = "") -> void:
	assert_true(absf(a - b) <= 0.001, "%s (%s vs %s)" % [msg, a, b])

# --- The tree ----------------------------------------------------------------------------

func test_the_whole_book_is_designed() -> void:
	var ids := Talents.in_tree("nature")
	assert_eq(ids.size(), TREE.size(), "every slot of the Nature book holds a talent")
	for id in ids:
		assert_false(bool(Talents.get_talent(id).get("placeholder", true)), "%s is designed" % id)
	var names := {}
	for key in TREE:
		var id := Talents.id_for_key(key)
		assert_ne(id, "", "%s exists" % key)
		assert_eq(Talents.group_of(id), str(TREE[key][0]), "%s: its spec's ribbon" % key)
		assert_eq(Talents.max_rank(id), int(TREE[key][1]), "%s: ranks" % key)
		assert_eq(Talents.required_ability(id), str(TREE[key][2]), "%s: the ability it needs" % key)
		assert_true(TalentIcons.has_icon(id), "%s has an icon" % key)
		for rank in [0, Talents.max_rank(id)]:
			var tip := Talents.tooltip(id, rank)
			assert_eq(TextFill.leftover(tip), "", "%s: its text is filled in: %s" % [key, tip])
			assert_false(tip.contains("?"), "%s: %s" % [key, tip])
		var name := str(Talents.get_talent(id)["name"])
		assert_false(names.has(name), "%s: one talent per name" % name)
		names[name] = true

## The agreed shape: 19 slots and ~50-60 ranks per spec, few that need one ability.
func test_each_spec_is_deep_and_mostly_keyword_talents() -> void:
	var slots := {}
	var ranks := {}
	var requires := {}
	for key in TREE:
		var g := str(TREE[key][0])
		slots[g] = int(slots.get(g, 0)) + 1
		ranks[g] = int(ranks.get(g, 0)) + int(TREE[key][1])
		if str(TREE[key][2]) != "":
			requires[g] = int(requires.get(g, 0)) + 1
	for g in CAPSTONES:
		assert_eq(int(slots[g]), 19, "%s: 19 talents" % g)
		assert_true(int(ranks[g]) >= 50 and int(ranks[g]) <= 60, "%s: %d ranks" % [g, int(ranks[g])])
		assert_true(float(requires.get(g, 0)) / 19.0 <= 0.27, "%s: about a quarter at most need one ability (%d)" % [g, int(requires.get(g, 0))])
	assert_eq(int(slots["Open"]), 9, "nine open talents")

func test_ribbons() -> void:
	assert_eq(Talents.columns_of("nature"), 13)
	assert_eq(Talents.groups_of("nature").size(), 5)
	for g in CAPSTONES:
		assert_false(Talents.UNFINISHED_SPECS.has(g), "%s is built" % g)
		assert_true(Talents.SHAPES.has(g), "%s has a shape" % g)
		var id := Talents.id_for_key(str(CAPSTONES[g]))
		assert_eq(Talents.tier_of(id), Talents.ROWS - 1, "%s's capstone is in the bottom row" % g)
		assert_true(Talents.capstone_gated(id))
		assert_contains(Talents.tooltip(id, 0), "Needs %d points in %s" % [Balance.CAPSTONE_GATE, g])
		assert_ne(str(Talents.get_talent(id).get("capstone", "")), "", "%s's capstone has a bonus at max rank" % g)
	assert_false(Talents.capstone_gated(Talents.id_for_key("nature_compost")))
	assert_false(Talents.capstone_gated(Talents.id_for_key("nature_hibernate")), "the spine has no gate")
	assert_true(Talents.TREE_VERSION >= 12, "the new tree refunds every point")
	assert_eq(Talents.links_in_tree("nature").size(), 8, "two links per spec")
	for link in Talents.links_in_tree("nature"):
		assert_eq(Talents.group_of(link[0]), Talents.group_of(link[1]), "a link stays in its spec's ribbon")
		assert_eq(Talents.col_of(link[0]), Talents.col_of(link[1]), "straight down one column")
		assert_true(Talents.tier_of(link[1]) - Talents.tier_of(link[0]) >= 2, "it skips a row")
	# No open talent names a school: they key off what you do.
	for id in Talents.in_group("nature", Talents.OPEN_GROUP):
		assert_false(Talents.description(id).contains("Nature"), "%s works with any book" % id)

# --- Rules -------------------------------------------------------------------------------

func test_thornweaver_talents() -> void:
	_near(WeaverKit.mulch_life(10.0), Balance.MULCH_TIME + 10.0, "Thick Mulch")
	_near(WeaverKit.well_rotted_coef(0.6, 2, 50.0), 0.6, "Well Rotted: two old patches at +50%")
	_near(WeaverKit.well_rotted_coef(0.6, 0, 50.0), 0.0, "no old patches, nothing more")
	_near(WeaverKit.harvest_mana(10.0, Balance.HARVEST_PATCHES, 60.0), 6.0, "Harvest")
	_near(WeaverKit.harvest_mana(10.0, Balance.HARVEST_PATCHES - 1, 60.0), 0.0, "too few patches")
	_near(WeaverKit.quickening_cast(1.5, 20.0), 1.2, "Quickening")
	assert_true(NatureTalentsOpenKit.steady_weave_applies("thornshot", Abilities.tags_of("thornshot"), false, false), "Steady Weave: Thornshot has a cast time")
	assert_false(NatureTalentsOpenKit.steady_weave_applies("thornwing", Abilities.tags_of("thornwing"), false, false), "not an instant")
	assert_false(NatureTalentsOpenKit.steady_weave_applies("thornshot", Abilities.tags_of("thornshot"), true, false), "not a proc")
	_near(NatureTalentsOpenKit.lush_mult("thornshot", 9.0), 0.91, "Lush: a damage spell")
	_near(NatureTalentsOpenKit.lush_mult("dewfall", 9.0), 1.0, "not a heal")
	assert_true(NatureTalentsOpenKit.below(30.0, 100.0, Balance.HUNTED_HEALTH_PCT), "Hunted: low")
	assert_false(NatureTalentsOpenKit.below(50.0, 100.0, Balance.HUNTED_HEALTH_PCT))

func test_shepherd_talents() -> void:
	_near(ShepherdKit.blossom_life(6.0), Balance.BLOSSOM_TIME + 6.0, "Long Bloom")
	_near(ShepherdKit.fawn_keep(0.0), Balance.FAWN_FALLOFF)
	_near(ShepherdKit.fawn_keep(15.0), Balance.FAWN_FALLOFF + 0.15, "Close Herd")
	_near(ShepherdKit.fawn_keep(90.0), 1.0, "never more than the bounce before")
	_near(ShepherdKit.nectar_mana(1000.0, 3, 0.3), 9.0, "Nectar: three Blossoms")
	_near(NatureTalentsOpenKit.mist_mult("dewfall", 9.0), 0.91, "Morning Mist: a heal")
	_near(NatureTalentsOpenKit.mist_mult("rootguard", 9.0), 0.91, "a shield too")
	_near(NatureTalentsOpenKit.mist_mult("thornshot", 9.0), 1.0, "not a damage spell")
	assert_true(NatureTalentsOpenKit.nature_heal("fawn"))
	assert_false(NatureTalentsOpenKit.nature_heal("psalm"), "only the book's own heals")
	assert_true(HymnsKit.HYMN_DR_NAMES.has(ShepherdKit.CANOPY_FX), "Canopy reaches allies the way Full Bloom does")

func test_colossus_talents() -> void:
	_near(ColossusKit.sap_life(10.0), Balance.SAP_TIME + 10.0, "Long Sap")
	_near(ColossusKit.sap_heal_mult(Balance.SAP_MAX, false, 60.0, 100.0), 1.6, "Brimming at full Sap")
	_near(ColossusKit.sap_heal_mult(Balance.SAP_MAX - 1, false, 60.0, 100.0), 1.0, "not short of full")
	_near(ColossusKit.sap_heal_mult(1, true, 60.0, 100.0), 2.0, "Old Oak while low")
	assert_true(ColossusKit.old_growth_gives(150, 1000, 10.0, 0.0), "Old Growth's capstone: a big hit")
	assert_false(ColossusKit.old_growth_gives(100, 1000, 10.0, 0.0), "a small one does nothing")
	assert_false(ColossusKit.old_growth_gives(150, 1000, 10.0, 9.0), "not again so soon")
	assert_true(NatureTalentsOpenKit.heavy_limbs_applies("stomp", Abilities.tags_of("stomp"), false), "Heavy Limbs: Stomp spends Fury")
	assert_false(NatureTalentsOpenKit.heavy_limbs_applies("vinefist", Abilities.tags_of("vinefist"), false), "Vine Fist builds it")
	_near(NatureTalentsOpenKit.groundswell_fury("vinefist", 20.0, 15.0), 23.0, "Groundswell")
	_near(NatureTalentsOpenKit.groundswell_fury("sic", 20.0, 15.0), 20.0, "only Nature abilities")
	_near(NatureTalentsOpenKit.called_out_fury(1, 6.0), 6.0, "Called Out")
	_near(NatureTalentsOpenKit.called_out_fury(Balance.CALLED_OUT_ENEMIES + 1, 6.0), 0.0, "up to a few enemies")
	var hold := func(key: String, _f: String) -> float: return 1.0 if key == "nature_firm_hold" else 0.0
	for fx in ["grasped", "choked", "coiled"]:
		_near(Abilities.effect_time_bonus(load("res://data/effects/%s.tres" % fx), hold), 1.0, "Firm Hold: %s" % fx)

func test_venomstring_talents() -> void:
	_near(VenomstringKit.poison_mult(2, 0.0, 9.0), 1.0 + (Balance.TWO_POISONS_PCT + 9.0) / 100.0, "Double Dose")
	_near(VenomstringKit.poison_mult(3, 0.0, 9.0), 1.0 + Balance.STEEPED_PCT / 100.0, "only with two")
	_near(VenomstringKit.poison_life(4.0), Balance.POISON_TIME + 4.0, "Slow Acting")
	_near(VenomstringKit.poison_every(1.0, false, 9.0), Balance.POISON_TICK / 1.09, "Quick Venom")
	_near(VenomstringKit.venom_per_tick(1.5, 1.0), Balance.VENOM_PER_TICK + 2.5, "Full Glands, Soaked Through's capstone")
	assert_true(NatureTalentsOpenKit.bow_shot("fangarrow", Abilities.tags_of("fangarrow"), false))
	assert_true(NatureTalentsOpenKit.bow_shot("auto_ranged", PackedStringArray(), false), "auto-shots too")
	assert_false(NatureTalentsOpenKit.bow_shot("adderarrow", Abilities.tags_of("adderarrow"), true), "not a poison's tick")

func test_open_talents() -> void:
	assert_true(NatureTalentsOpenKit.startle_applies("thornshot", false, false, 100.0, 100.0))
	assert_false(NatureTalentsOpenKit.startle_applies("thornshot", false, false, 99.0, 100.0), "only at full health")
	assert_false(NatureTalentsOpenKit.startle_applies("thornburst", true, false, 100.0, 100.0), "not a proc")
	assert_eq(NatureTalentsOpenKit.food_chain_heal(1000, 3.0), 30, "Food Chain")
	assert_eq(str(Details.HIT_NAMES.get(NatureTalentsOpenKit.FOOD_CHAIN_ID, "")), "Food Chain", "its own meter line")

# --- Hooks -------------------------------------------------------------------------------

func test_hooks_in_place() -> void:
	var src := _src()
	for hook in [
		"mulch_life(_talent(\"nature_thick_mulch\"))", "Balance.MULCH_REACH + _talent(\"nature_long_roots\")",
		"well_rotted_coef(each, aged, _talent(\"nature_well_rotted\"))", "harvest_mana(resource_cost(id), used, _talent(\"nature_harvest\"))",
		"_talent(\"nature_leaf_litter\")", "quickening(spell, duration)   # Quickening", "_overgrown_leaves(int(used[0])",
		"blossom_life(_talent(\"nature_long_bloom\"))", "rolls(_talent(\"nature_second_bud\"), randf() * 100.0)",
		"rich_soil_per(Balance.ROOTGUARD_PER_BLOSSOM, _talent(\"nature_heavy_petals\"))",
		"rich_soil_per(Balance.ELK_PER_BLOSSOM, _talent(\"nature_heavy_petals\"))", "_pollen(who, n)",
		"nectar_mana(resource_max(\"mana\"), n, _talent(\"nature_nectar\"))", "_hymn_dr(who, CANOPY_FX, shade, Balance.CANOPY_TIME)",
		"fawn_keep(_talent(\"nature_close_herd\"))", "Balance.ROOTGUARD_SPREAD + _talent(\"nature_wide_grove\")",
		"Balance.EVERGREEN_FADE_HEAL * Balance.REFERENCE_HEAL", "heal_mult(tgt, id)",
		"sap_life(_talent(\"nature_long_sap\"))", "rolls(_talent(\"nature_sap_run\"), randf() * 100.0)",
		"sap_heal_mult(sap(), low, _talent(\"nature_brimming\"), _talent(\"nature_old_oak\"))",
		"float(n) * _talent(\"nature_taproot\")", "_talent(\"nature_long_limbs\")", "called_out()",
		"firm_hold_fury()", "_capstone(\"nature_old_growth\")", "_talent(\"nature_woodgrain\")",
		"poison_life(_talent(\"nature_slow_acting\"))", "_talent(\"nature_first_bite\")", "_talent(\"nature_quick_venom\")",
		"venom_per_tick(_talent(\"nature_full_glands\"), steeped_extra)", "_talent(\"nature_spare_venom\")",
		"_talent(\"nature_fresh_host\")", "_talent(\"nature_swollen\")", "dripping_tips(tgt)",
		"lush_mult(id, _talent(\"nature_lush\"))", "mist_mult(id, _talent(\"nature_morning_mist\"))",
		"hibernate_mult()", "_on_enemy_died_nature", "_talent(\"nature_groundswell\")",
	]:
		assert_contains(src, hook)
	var status := FileAccess.get_file_as_string("res://scripts/core/status_container.gd")
	assert_contains(status, "owner_node.self_absorb_mult()", "Woodgrain: shields I put on myself")
	assert_contains(status, "func has_slow_from(source: Node) -> bool:", "Dragging Feet: only my own slows")
