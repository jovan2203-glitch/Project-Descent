@tool
extends McpTestSuite

# The Shadow book's talents on the ribbon layout (Talents.GROUPS): The Breach, Pack
# of Two, Strings Attached, the open ones, and Nightstring's empty short ribbon (the
# bow is not built yet). Their rules are in scripts/player/shadow_decay.gd,
# shadow_hounds.gd, shadow_strings.gd and shadow_talents.gd; the hooks are checked in
# the player's source.

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const Details = preload("res://scripts/core/details.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")

## Every talent of the book: key -> [group, ranks, the ability it needs ("" = none)].
const TREE := {
	# The Breach.
	"shadow_seep": ["The Breach", 3, ""], "shadow_interest": ["The Breach", 3, "calldue"],
	"shadow_held_open": ["The Breach", 2, ""], "shadow_hungry_dark": ["The Breach", 3, ""],
	"shadow_deep_call": ["The Breach", 3, ""], "shadow_running_over": ["The Breach", 3, "spill"],
	"shadow_bite_down": ["The Breach", 3, "gnaw"], "shadow_many_mouths": ["The Breach", 3, ""],
	"shadow_no_floor": ["The Breach", 3, "bottomless"], "shadow_small_change": ["The Breach", 3, "calldue"],
	"shadow_shut_tight": ["The Breach", 3, ""], "shadow_next_of_kin": ["The Breach", 3, ""],
	"shadow_grasping_hands": ["The Breach", 3, ""], "shadow_tainted_steel": ["The Breach", 3, ""],
	"shadow_ill_will": ["The Breach", 3, ""], "shadow_carrion": ["The Breach", 2, ""],
	"shadow_bitter_end": ["The Breach", 3, ""], "shadow_paid_in_full": ["The Breach", 2, ""],
	"shadow_rot_through": ["The Breach", 5, ""],
	# Pack of Two.
	"shadow_long_night": ["Pack of Two", 2, ""], "shadow_pincer": ["Pack of Two", 3, "bothatonce"],
	"shadow_still_wet": ["Pack of Two", 3, "openup"], "shadow_take_it_with_you": ["Pack of Two", 2, ""],
	"shadow_again": ["Pack of Two", 3, "bothatonce"], "shadow_slipped_leash": ["Pack of Two", 3, "offthechain"],
	"shadow_lean_and_hungry": ["Pack of Two", 3, ""], "shadow_out_of_the_hole": ["Pack of Two", 3, ""],
	"shadow_snarl": ["Pack of Two", 3, ""], "shadow_fed": ["Pack of Two", 2, ""],
	"shadow_worked_up": ["Pack of Two", 2, ""], "shadow_blood_up": ["Pack of Two", 3, ""],
	"shadow_stand_over": ["Pack of Two", 3, ""], "shadow_wide_pack": ["Pack of Two", 2, "runthemdown"],
	"shadow_fetch": ["Pack of Two", 3, ""], "shadow_thick_blood": ["Pack of Two", 3, ""],
	"shadow_scent_of_blood": ["Pack of Two", 3, ""], "shadow_share_the_kill": ["Pack of Two", 3, ""],
	"shadow_pack_leader": ["Pack of Two", 5, ""],
	# The open talents.
	"shadow_slow_death": ["Open", 3, ""], "shadow_wasting": ["Open", 3, ""], "shadow_finish_it": ["Open", 3, ""],
	"shadow_spite": ["Open", 3, ""], "shadow_feeding_frenzy": ["Open", 3, ""], "shadow_many_hands": ["Open", 3, ""],
	"shadow_lean_on_me": ["Open", 3, ""], "shadow_left_hanging": ["Open", 2, ""], "shadow_inevitable": ["Open", 5, ""],
	# Strings Attached.
	"shadow_heave": ["Strings Attached", 3, "hoist"], "shadow_long_thread": ["Strings Attached", 2, ""],
	"shadow_quick_hands": ["Strings Attached", 3, ""], "shadow_three_ply": ["Strings Attached", 3, ""],
	"shadow_first_stitch": ["Strings Attached", 2, ""], "shadow_spare_spool": ["Strings Attached", 2, ""],
	"shadow_hard_pull": ["Strings Attached", 3, "tug"], "shadow_full_harness": ["Strings Attached", 2, ""],
	"shadow_pass_it_on": ["Strings Attached", 3, ""], "shadow_taking_the_weight": ["Strings Attached", 2, ""],
	"shadow_fair_trade": ["Strings Attached", 3, ""], "shadow_snap_back": ["Strings Attached", 3, "pulltaut"],
	"shadow_hold_fast": ["Strings Attached", 3, ""], "shadow_give_and_take": ["Strings Attached", 3, "slack"],
	"shadow_firm_grip": ["Strings Attached", 3, ""], "shadow_loose_weave": ["Strings Attached", 2, ""],
	"shadow_long_drop": ["Strings Attached", 3, "stringup"], "shadow_nothing_wasted": ["Strings Attached", 2, ""],
	"shadow_steady_hands": ["Strings Attached", 5, ""],
}
## Each finished spec's capstone (its bottom-row talent).
const CAPSTONES := {"The Breach": "shadow_rot_through", "Pack of Two": "shadow_pack_leader",
	"Strings Attached": "shadow_steady_hands"}

func suite_name() -> String:
	return "shadow_tree"

func _near(a: float, b: float, msg: String = "") -> void:
	assert_true(absf(a - b) <= 0.001, "%s (%s vs %s)" % [msg, a, b])

# --- The tree ----------------------------------------------------------------------------

func test_the_whole_book_is_designed() -> void:
	var ids := Talents.in_tree("shadow")
	assert_eq(ids.size(), TREE.size(), "every slot of the Shadow book holds a talent")
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

## The agreed shape: 19 slots and ~50-60 ranks per finished spec, few that need one ability.
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
	assert_true(Talents.in_group("shadow", "Nightstring").is_empty(), "the unfinished bow has none yet")

func test_ribbons() -> void:
	assert_eq(Talents.columns_of("shadow"), 13)
	assert_eq(Talents.groups_of("shadow").size(), 5)
	assert_true(Talents.UNFINISHED_SPECS.has("Nightstring"))
	for g in CAPSTONES:
		var id := Talents.id_for_key(str(CAPSTONES[g]))
		assert_eq(Talents.tier_of(id), Talents.ROWS - 1, "%s's capstone is in the bottom row" % g)
		assert_true(Talents.capstone_gated(id))
		assert_contains(Talents.tooltip(id, 0), "Needs %d points in %s" % [Balance.CAPSTONE_GATE, g])
		assert_ne(str(Talents.get_talent(id).get("capstone", "")), "", "%s's capstone has a bonus at max rank" % g)
	assert_false(Talents.capstone_gated(Talents.id_for_key("shadow_seep")))
	assert_false(Talents.capstone_gated(Talents.id_for_key("shadow_inevitable")), "the spine has no gate")
	assert_true(Talents.TREE_VERSION >= 11, "the new tree refunds every point")
	assert_eq(Talents.links_in_tree("shadow").size(), 6, "two links per finished spec")
	for link in Talents.links_in_tree("shadow"):
		assert_eq(Talents.group_of(link[0]), Talents.group_of(link[1]), "a link stays in its spec's ribbon")
		assert_eq(Talents.col_of(link[0]), Talents.col_of(link[1]), "straight down one column")
		assert_true(Talents.tier_of(link[1]) - Talents.tier_of(link[0]) >= 2, "it skips a row")
	# No open talent names a school: they key off what you do.
	for id in Talents.in_group("shadow", Talents.OPEN_GROUP):
		assert_false(Talents.description(id).contains("Shadow"), "%s works with any book" % id)

# --- Rules -------------------------------------------------------------------------------

func test_breach_talents() -> void:
	var dot := PackedStringArray(["Shadow", "Spell", "DoT"])
	_near(DecayKit.seep_feed_pct("dot_corrupted", dot, true, 50.0), 50.0, "Lure: Wither's ticks")
	_near(DecayKit.seep_feed_pct("some_shadow_dot", dot, true, 50.0), 50.0, "Lure: any periodic Shadow damage")
	_near(DecayKit.seep_feed_pct(DecayKit.DECAY_HIT_ID, dot, true, 50.0), 0.0, "never the Breach's own ticks")
	_near(DecayKit.seep_feed_pct("corruption", dot, false, 50.0), 0.0, "not a direct hit")
	_near(DecayKit.seep_feed_pct("dot_fire", PackedStringArray(["Fire", "DoT"]), true, 50.0), 0.0, "only Shadow damage")
	_near(DecayKit.many_mouths_pct(25.0, Abilities.tags_of("pall"), 20.0), 30.0, "Many Mouths: Many Hands hits an area")
	_near(DecayKit.many_mouths_pct(25.0, Abilities.tags_of("erode"), 20.0), 25.0, "not a single-target spell")
	assert_eq(DecayKit.decay_tick_bonuses(0.0, 0.0, 0.0, false, 10.0, true), [[10.0, "Shut Tight"]], "Shut Tight on a closed Breach")
	assert_eq(DecayKit.decay_tick_bonuses(0.0, 0.0, 0.0, false, 10.0, false), [], "not on an open one")
	_near(DecayKit.hooked_claws_hold(10.0, 5.0, 0.0), Balance.HOOKED_CLAWS_HOLD, "Hooked Claws' capstone holds it open")
	_near(DecayKit.hooked_claws_hold(10.0, 5.0, Balance.HOOKED_CLAWS_MAX - 0.2), 0.2, "up to its cap")
	_near(DecayKit.hooked_claws_hold(10.0, 5.0, Balance.HOOKED_CLAWS_MAX), 0.0, "and no further")
	_near(DecayKit.hooked_claws_hold(4.0, 5.0, 0.0), 0.0, "a closed Breach stays closed")
	assert_true(ShadowTalentsKit.deep_call_spell(Abilities.tags_of("erode")), "Deep Call: Beckon")
	assert_true(ShadowTalentsKit.deep_call_spell(Abilities.tags_of("pall")), "and Many Hands")
	assert_false(ShadowTalentsKit.deep_call_spell(Abilities.tags_of("hoist")), "never a heal")
	var spell := Abilities.tags_of("erode")
	assert_true(ShadowTalentsKit.hungry_dark_applies(spell, false, false, true), "Hungry Dark")
	assert_false(ShadowTalentsKit.hungry_dark_applies(spell, false, false, false), "only on an open Breach")
	assert_false(ShadowTalentsKit.hungry_dark_applies(spell, false, true, true), "not a tick")
	assert_false(ShadowTalentsKit.hungry_dark_applies(Abilities.tags_of("sic"), false, false, true), "not an ability")

func test_hounds_talents() -> void:
	var tags := Abilities.tags_of("bothatonce")
	assert_true(ShadowTalentsKit.blood_up_applies(tags, true, false, true), "Blood Up")
	assert_false(ShadowTalentsKit.blood_up_applies(tags, true, false, false), "only while Roused")
	assert_false(ShadowTalentsKit.blood_up_applies(tags, false, false, true), "only what spends Fury")
	assert_false(ShadowTalentsKit.blood_up_applies(tags, true, true, true), "not a proc")
	_near(ShadowTalentsKit.snarl_fury("sic", 15.0, 10.0), 16.5, "Snarl: Sic builds more")
	_near(ShadowTalentsKit.snarl_fury("searingstrike", 15.0, 10.0), 15.0, "not another book's ability")
	_near(ShadowTalentsKit.snarl_fury("sic", 15.0, 0.0), 15.0, "no talent")
	assert_true(HoundsKit.scent_of_blood_applies(30, 100), "Scent of Blood")
	assert_false(HoundsKit.scent_of_blood_applies(50, 100))
	assert_false(HoundsKit.scent_of_blood_applies(null, 100), "something with no health")
	assert_eq(HoundsKit.pack_leader_steps(5.0, 30.0, 0.0), [3.0 * Balance.PACK_LEADER_TIME, 5.0], "three steps, 5 carried")
	assert_eq(HoundsKit.pack_leader_steps(0.0, 50.0, Balance.PACK_LEADER_MAX - 1.0), [1.0, 0.0], "up to its cap for the pair")
	assert_eq(HoundsKit.pack_leader_steps(0.0, 5.0, 0.0), [0.0, 5.0], "not a step yet")

func test_strings_talents() -> void:
	_near(StringsKit.string_tick_interval(1.0, false, 25.0), Balance.STRING_TICK / 1.25, "Quick Hands")
	_near(StringsKit.string_tick_mult(Balance.STRING_STACKS, 10.0, 100.0, 20.0), 1.1, "Three Ply")
	_near(StringsKit.string_tick_mult(1, 10.0, 20.0, 20.0), 1.2, "Hold Fast")
	_near(StringsKit.string_tick_mult(Balance.STRING_STACKS, 10.0, 20.0, 20.0), 1.32, "both")
	_near(StringsKit.string_tick_mult(1, 10.0, 100.0, 20.0), 1.0, "neither")
	assert_eq(StringsKit.string_share(1000, 20.0), int(round(1000 * Balance.STRING_SHARE_PCT / 100.0 * 1.2)), "Pass It On")
	assert_eq(StringsKit.string_share(1000), int(round(1000 * Balance.STRING_SHARE_PCT / 100.0)))
	_near(StringsKit.all_out_mult(0, true), 1.0 + Balance.STEADY_HANDS_ALL_OUT_PCT / 100.0, "Steady Hands' capstone")
	_near(StringsKit.all_out_mult(1, true), 1.0, "a String still in hand")
	_near(StringsKit.all_out_mult(0, false), 1.0, "no capstone")

func test_hooks_are_in_place() -> void:
	var src := PlayerSource.text()
	for hook in ["_talent(\"shadow_held_open\")", "_talent(\"shadow_many_mouths\")", "_talent(\"shadow_shut_tight\")",
			"_talent(\"shadow_grasping_hands\")", "_capstone(\"shadow_rot_through\")", "_paid_in_full()",
			"deep_call_spell(", "_talent(\"shadow_hungry_dark\")", "_talent(\"shadow_blood_up\")", "snarl_fury(",
			"_talent(\"shadow_fetch\")", "_talent(\"shadow_scent_of_blood\")", "fury_spent(cost)",
			"_talent(\"shadow_quick_hands\")", "_talent(\"shadow_three_ply\")", "_talent(\"shadow_hold_fast\")",
			"_talent(\"shadow_pass_it_on\")", "_talent(\"shadow_loose_weave\")", "_talent(\"shadow_firm_grip\")",
			"_talent(\"shadow_fair_trade\")", "_nothing_wasted()", "all_out_mult(string_charges()"]:
		assert_contains(src, hook)
	assert_contains(src, "stand > 0.0 and status.has(ROUSED_FX)", "Stand Over works while the Hounds are Roused")
	for label in ["Hungry Dark", "Blood Up", "Shut Tight", "Scent of Blood"]:
		assert_true(src.contains("\"%s\")" % label) or src.contains("\"%s\"" % label), "%s has its own damage line" % label)
	assert_eq(Details.HIT_NAMES.get(StringsKit.FAIR_TRADE_ID, ""), "Fair Trade", "its own meter line")
