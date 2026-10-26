@tool
extends McpTestSuite

# The Frost book's talents on the column-group layout (Talents.GROUPS): Hard Winter,
# Cold Comfort, Frostbitten Steel, Glacier Wall, Winter Hunt and the open ones.
# Their rules are in scripts/player/frost_talents.gd and each spec's component;
# the hooks are checked in the player's source.

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const Details = preload("res://scripts/core/details.gd")

## Every talent of the book: key -> [group, ranks, the ability it needs ("" = none)].
const TREE := {
	# Hard Winter.
	"frost_chilled_dmg": ["Hard Winter", 3, ""], "frost_glass_cold": ["Hard Winter", 3, ""],
	"frost_bolt_cast": ["Hard Winter", 3, "frostbolt"], "frost_instinct": ["Hard Winter", 3, ""],
	"frost_hoarfrost": ["Hard Winter", 3, "hoarfrost"], "frost_hoarfrost_burst": ["Hard Winter", 3, "hoarfrost"],
	"frost_shard_proc": ["Hard Winter", 3, ""], "frost_shardstorm": ["Hard Winter", 3, "iceshards"],
	"frost_piercing_cold": ["Hard Winter", 3, "coldspike"], "frost_ice_needles": ["Hard Winter", 3, ""],
	"frost_splinter": ["Hard Winter", 2, "iceshards"], "frost_cold_snap": ["Hard Winter", 3, ""],
	"frost_snowdrift": ["Hard Winter", 3, ""], "frost_cold_front": ["Hard Winter", 3, ""],
	"frost_long_chill": ["Hard Winter", 3, ""], "frost_hard_freeze": ["Hard Winter", 3, ""],
	"frost_cold_well": ["Hard Winter", 3, ""], "frost_shatterpoint": ["Hard Winter", 3, ""],
	"frost_deep_freeze": ["Hard Winter", 5, ""],
	# Cold Comfort.
	"frost_deep_cracks": ["Cold Comfort", 3, ""], "frost_shard_spray": ["Cold Comfort", 3, ""],
	"frost_slow_runoff": ["Cold Comfort", 3, ""], "frost_thaw_water": ["Cold Comfort", 3, ""],
	"frost_last_shelter": ["Cold Comfort", 3, ""], "frost_cold_hands": ["Cold Comfort", 3, ""],
	"frost_cold_spread": ["Cold Comfort", 3, "breaktheice"], "frost_meltdown": ["Cold Comfort", 3, ""],
	"frost_long_frost": ["Cold Comfort", 3, ""], "frost_shard_reach": ["Cold Comfort", 2, ""],
	"frost_wide_lattice": ["Cold Comfort", 2, "frostlattice"], "frost_snowmelt": ["Cold Comfort", 3, ""],
	"frost_layered_veil": ["Cold Comfort", 2, "rimeveil"], "frost_ice_bath": ["Cold Comfort", 3, ""],
	"frost_deep_snow": ["Cold Comfort", 3, "rimefall"], "frost_cold_rush": ["Cold Comfort", 3, ""],
	"frost_close_weave": ["Cold Comfort", 3, "frostlattice"], "frost_splinterheal": ["Cold Comfort", 3, ""],
	"frost_frozen_hearth": ["Cold Comfort", 5, ""],
	# The open talents.
	"frost_haste": ["Open", 3, ""], "frost_int_sp": ["Open", 3, ""], "frost_absorb": ["Open", 3, ""],
	"frost_shield_armor": ["Open", 4, ""], "frost_ice_floe": ["Open", 2, ""], "frost_slow_dr": ["Open", 3, ""],
	"frost_glacial_heart": ["Open", 3, ""], "frost_discipline": ["Open", 3, ""], "frost_winter_coat": ["Open", 3, ""],
	# Frostbitten Steel.
	"frost_sharp_glaze": ["Frostbitten Steel", 3, ""], "frost_third_bite": ["Frostbitten Steel", 3, ""],
	"frost_long_glaze": ["Frostbitten Steel", 3, ""], "frost_glaze_hunger": ["Frostbitten Steel", 3, ""],
	"frost_cold_sweep": ["Frostbitten Steel", 3, "hoarcleave"], "frost_hard_glaze": ["Frostbitten Steel", 3, ""],
	"frost_honed_rime": ["Frostbitten Steel", 3, "rimeedge"], "frost_clean_break": ["Frostbitten Steel", 3, ""],
	"frost_ice_fall": ["Frostbitten Steel", 3, "calving"], "frost_splitting_cold": ["Frostbitten Steel", 3, ""],
	"frost_biting_hold": ["Frostbitten Steel", 2, "bitteredge"], "frost_shiver": ["Frostbitten Steel", 3, ""],
	"frost_rime_grip": ["Frostbitten Steel", 3, ""], "frost_cold_swing": ["Frostbitten Steel", 3, ""],
	"frost_long_dark": ["Frostbitten Steel", 3, "blackfrost"], "frost_thaw_strike": ["Frostbitten Steel", 3, ""],
	"frost_quick_rime": ["Frostbitten Steel", 3, ""], "frost_frost_heave": ["Frostbitten Steel", 3, ""],
	"frost_glinting_rime": ["Frostbitten Steel", 5, ""],
	# Glacier Wall.
	"frost_packed_ice": ["Glacier Wall", 3, "shatteringslam"], "frost_cold_fury": ["Glacier Wall", 3, ""],
	"frost_lasting_ice": ["Glacier Wall", 3, ""], "frost_deep_ice": ["Glacier Wall", 2, ""],
	"frost_deep_tremor": ["Glacier Wall", 3, "rimequake"], "frost_spent_ice": ["Glacier Wall", 3, ""],
	"frost_hoar_coat": ["Glacier Wall", 3, ""], "frost_cold_retort": ["Glacier Wall", 3, ""],
	"frost_turned_backs": ["Glacier Wall", 2, "coldshoulder"], "frost_rime_pressure": ["Glacier Wall", 3, ""],
	"frost_regelation": ["Glacier Wall", 3, "hardrime"], "frost_reforming": ["Glacier Wall", 3, ""],
	"frost_cracking_ice": ["Glacier Wall", 3, ""], "frost_steady_footing": ["Glacier Wall", 3, ""],
	"frost_old_ice": ["Glacier Wall", 3, "glacialbulwark"], "frost_rime_armor": ["Glacier Wall", 3, ""],
	"frost_slow_threat": ["Glacier Wall", 3, ""], "frost_full_strata": ["Glacier Wall", 3, ""],
	"frost_deep_strata": ["Glacier Wall", 5, ""],
	# Winter Hunt.
	"frost_cold_draw": ["Winter Hunt", 3, ""], "frost_frozen_quarry": ["Winter Hunt", 3, ""],
	"frost_pinning_frost": ["Winter Hunt", 3, ""], "frost_black_ice": ["Winter Hunt", 3, "icyretreat"],
	"frost_clean_shatter": ["Winter Hunt", 3, "shattershot"], "frost_frost_fletching": ["Winter Hunt", 3, ""],
	"frost_cold_harvest": ["Winter Hunt", 3, "rimefletch"], "frost_rime_tips": ["Winter Hunt", 3, ""],
	"frost_thin_ice": ["Winter Hunt", 3, "glacialdraw"], "frost_marked_ice": ["Winter Hunt", 3, ""],
	"frost_winter_quiver": ["Winter Hunt", 3, ""], "frost_splitting_arrow": ["Winter Hunt", 3, ""],
	"frost_deep_pin": ["Winter Hunt", 3, ""], "frost_numb_prey": ["Winter Hunt", 3, ""],
	"frost_swift_ice": ["Winter Hunt", 3, ""], "frost_ice_hunger": ["Winter Hunt", 3, ""],
	"frost_cold_eye": ["Winter Hunt", 3, ""], "frost_sleet_arrows": ["Winter Hunt", 2, ""],
	"frost_bitter_hunt": ["Winter Hunt", 5, ""],
}
## Each spec's capstone (its bottom-row talent).
const CAPSTONES := {"Hard Winter": "frost_deep_freeze", "Cold Comfort": "frost_frozen_hearth",
	"Frostbitten Steel": "frost_glinting_rime", "Glacier Wall": "frost_deep_strata", "Winter Hunt": "frost_bitter_hunt"}

func suite_name() -> String:
	return "frost_tree"

func _src() -> String:
	return PlayerSource.text()

func _near(a: float, b: float, msg: String = "") -> void:
	assert_true(absf(a - b) <= 0.001, "%s (%s vs %s)" % [msg, a, b])

# --- The tree ----------------------------------------------------------------------------

func test_the_whole_book_is_designed() -> void:
	var ids := Talents.in_tree("frost")
	assert_eq(ids.size(), TREE.size(), "every slot of the Frost book holds a talent")
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
	assert_eq(Talents.id_for_key("frost_marked_prey"), "", "Marked Prey became Frozen Quarry")

## The agreed shape: 19 slots and ~50+ ranks per spec, few that need one ability.
func test_each_spec_is_deep_and_mostly_keyword_talents() -> void:
	var slots := {}
	var ranks := {}
	var requires := 0
	for key in TREE:
		var g := str(TREE[key][0])
		slots[g] = int(slots.get(g, 0)) + 1
		ranks[g] = int(ranks.get(g, 0)) + int(TREE[key][1])
		if str(TREE[key][2]) != "":
			requires += 1
	for g in CAPSTONES:
		assert_eq(int(slots[g]), 19, "%s: 19 talents" % g)
		assert_true(int(ranks[g]) >= 50 and int(ranks[g]) <= 60, "%s: %d ranks" % [g, int(ranks[g])])
	assert_eq(int(slots["Open"]), 9, "nine open talents")
	assert_true(float(requires) / TREE.size() <= 0.25, "at most a quarter need one ability (%d of %d)" % [requires, TREE.size()])

func test_column_groups() -> void:
	assert_eq(Talents.columns_of("frost"), 16)
	assert_eq(Talents.groups_of("frost").size(), 6)
	for g in CAPSTONES:
		var id := Talents.id_for_key(str(CAPSTONES[g]))
		assert_eq(Talents.tier_of(id), Talents.ROWS - 1, "%s's capstone is in the bottom row" % g)
		assert_true(Talents.capstone_gated(id))
		assert_contains(Talents.tooltip(id, 0), "Needs %d points in %s" % [Balance.CAPSTONE_GATE, g])
	assert_false(Talents.capstone_gated(Talents.id_for_key("frost_glass_cold")))
	assert_false(Talents.capstone_gated(Talents.id_for_key("frost_discipline")), "the Open column has no gate")
	assert_true(Talents.TREE_VERSION >= 7, "the new tree refunds every point")
	for link in Talents.links_in_tree("frost"):
		assert_eq(Talents.group_of(link[0]), Talents.group_of(link[1]), "a link stays in its spec's ribbon")
		assert_eq(Talents.col_of(link[0]), Talents.col_of(link[1]), "straight down one column")
		assert_true(Talents.tier_of(link[1]) - Talents.tier_of(link[0]) >= 2, "it skips a row")

# --- Rules -------------------------------------------------------------------------------

func test_talent_maths() -> void:
	_near(FrostTalentsKit.cold_front_pct(2, 3.0), 6.0, "Cold Front per enemy")
	_near(FrostTalentsKit.cold_front_pct(Balance.COLD_FRONT_MAX + 4, 3.0), 3.0 * Balance.COLD_FRONT_MAX, "Cold Front stops at its cap")
	_near(FrostTalentsKit.bitter_hunt_pct(3, 5.0), 15.0, "Bitter Hunt per slow")
	_near(FrostHealerKit.runoff_every(0.0), 1.0, "Runoff once a second")
	_near(FrostHealerKit.runoff_every(45.0), 1.0 / 1.45, "Snowmelt: closer together")
	assert_true(FrostTalentsKit.freezes([load("res://data/effects/frozen.tres")]))
	assert_false(FrostTalentsKit.freezes([load("res://data/effects/chilled.tres")]))
	assert_true(FrostTalentsKit.is_frost_care("meltwater"), "Meltwater heals")
	assert_true(FrostTalentsKit.is_frost_care("rimeshell"), "Rime Shell shields")
	assert_false(FrostTalentsKit.is_frost_care("frostbolt"))
	assert_true(FrostBowKit.instinct_applies("frostbolt"), "Frozen Instinct: Frost Bolt")
	assert_true(FrostBowKit.instinct_applies("coldspike"), "... and every Frost spell with a cast time")
	assert_false(FrostBowKit.instinct_applies("frostnova"), "not an instant")
	assert_false(FrostBowKit.instinct_applies("fireball"), "not a Fire spell")

func test_hooks_are_in_place() -> void:
	var src := _src()
	assert_contains(src, "_frost_talents_outgoing(info)")
	assert_contains(src, "_frost_talents_incoming(info)")
	assert_contains(src, "crit_hit_bonus(info))   # Cold Eye")
	assert_contains(src, "_on_hit(info)")
	assert_contains(src, "_on_freeze(enemy)")
	assert_contains(src, "_on_thaw()")
	assert_contains(src, "finisher_cost(id, cost)")
	assert_contains(src, "attack_speed_vs(enemy)")
	assert_contains(src, "auto_fury(enemy")
	assert_contains(src, "shield_mult(")
	assert_contains(src, "cold_rush(")
	assert_contains(src, "heal_mult(tgt)")
	assert_contains(src, "_talent(\"frost_cold_hands\")")
	assert_contains(src, "_talent(\"frost_deep_ice\")")
	assert_contains(src, "_talent(\"frost_lasting_ice\")")
	assert_contains(src, "_talent(\"frost_glaze_hunger\")")
	assert_contains(src, "_talent(\"frost_hard_glaze\")")
	assert_contains(src, "_talent(\"frost_shard_reach\")")
	for label in ["Glass Cold", "Snowdrift", "Cold Front", "Sharp Glaze", "Third Bite", "Splitting Cold", "Full Strata",
			"Frozen Quarry", "Pinning Frost", "Bitter Hunt", "Frost Fletching", "Numb Prey", "Steady Footing", "Winter Coat"]:
		assert_contains(src, "\"%s\")" % label, "%s has its own damage line" % label)
	assert_eq(Details.HIT_NAMES.get(FrostTalentsKit.SPLITTING_ARROW_ID, ""), "Splitting Arrow", "its own meter line")
	assert_eq(Details.HIT_NAMES.get(FrostTalentsKit.COLD_RETORT_ID, ""), "Cold Retort", "its own meter line")

func test_deep_pin_lengthens_roots() -> void:
	var rooted: Resource = load("res://data/effects/rooted.tres")
	var bonus := Abilities.effect_time_bonus(rooted, func(key, _f): return 2.0 if key == "frost_deep_pin" else 0.0)
	_near(bonus, 2.0, "Deep Pin: any root of mine")
