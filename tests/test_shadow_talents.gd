@tool
extends McpTestSuite

# The Shadow book's talents. Open ones (they work with every book's spells and
# abilities): Slow Death, Wasting, Finish It, Spite, Carrion, Inevitable. The
# caster's, around Decay: Seep, Interest, Next of Kin, Bitter End,
# No Floor, Small Change, Rot Through. (Tainted Steel: tests/test_shadow_kit.gd.)

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")

## [key, name, slot, ranks, values, the ability it needs ("" = an open talent)]
const WANT := [
	["shadow_slow_death", "Slow Death", "shadow_r1c2", 3, [2.0, 4.0, 6.0], ""],
	["shadow_wasting", "Wasting", "shadow_r1c4", 3, [2.0, 4.0, 6.0], ""],
	["shadow_finish_it", "Finish It", "shadow_r1c6", 3, [3.0, 6.0, 9.0], ""],
	["shadow_spite", "Spite", "shadow_r2c3", 3, [3.0, 6.0, 9.0], ""],
	["shadow_carrion", "Carrion", "shadow_r2c5", 2, [1.0, 2.0], ""],
	["shadow_inevitable", "Inevitable", "shadow_r10c5", 5, [2.0, 4.0, 6.0, 8.0, 10.0], ""],
	["shadow_seep", "Lure", "shadow_r4c3", 3, [17.0, 33.0, 50.0], "corruption"],
	["shadow_interest", "Interest", "shadow_r4c4", 3, [5.0, 10.0, 15.0], "calldue"],
	["shadow_next_of_kin", "Next of Kin", "shadow_r6c3", 3, [10.0, 20.0, 30.0], "blight"],
	["shadow_bitter_end", "Bitter End", "shadow_r6c5", 3, [33.0, 67.0, 100.0], "blight"],
	["shadow_no_floor", "No Floor", "shadow_r7c3", 3, [1.5, 2.5, 4.0], "bottomless"],
	["shadow_small_change", "Small Change", "shadow_r5c4", 3, [7.0, 13.0, 20.0], "calldue"],
	["shadow_rot_through", "Hooked Claws", "shadow_r10c3", 5, [2.0, 4.0, 6.0, 8.0, 10.0], "blight"],
	["shadow_running_over", "Wider Still", "shadow_r5c6", 3, [7.0, 13.0, 20.0], "spill"],
	["shadow_bite_down", "Bite Down", "shadow_r7c5", 3, [7.0, 13.0, 20.0], "gnaw"],
	# Two more open talents, on the edges of row 2.
	["shadow_thick_blood", "Thick Blood", "shadow_r2c1", 3, [15.0, 30.0, 45.0], ""],
	["shadow_feeding_frenzy", "Feeding Frenzy", "shadow_r2c7", 3, [2.0, 4.0, 6.0], ""],
	# Melee (the Hounds): the Hounds themselves down the left edge ...
	["shadow_lean_and_hungry", "Lean and Hungry", "shadow_r4c1", 3, [4.0, 8.0, 12.0], ""],
	["shadow_fed", "Fed", "shadow_r5c1", 2, [2.0, 4.0], ""],
	["shadow_worked_up", "Worked Up", "shadow_r6c1", 2, [2.0, 4.0], ""],
	["shadow_out_of_the_hole", "Out of the Hole", "shadow_r7c1", 3, [17.0, 33.0, 50.0], "blight"],
	["shadow_long_night", "Long Night", "shadow_r8c2", 2, [3.0, 6.0], ""],
	["shadow_take_it_with_you", "Take It With You", "shadow_r9c1", 2, [25.0, 50.0], ""],
	["shadow_pack_leader", "Pack Leader", "shadow_r10c4", 5, [3.0, 6.0, 9.0, 12.0, 15.0], ""],
	# ... and one ability's talents each down the right edge.
	["shadow_still_wet", "Still Wet", "shadow_r3c7", 3, [1.5, 2.5, 4.0], "openup"],
	["shadow_share_the_kill", "Share the Kill", "shadow_r4c7", 3, [33.0, 67.0, 100.0], "shadowstrike"],
	["shadow_pincer", "Pincer", "shadow_r5c7", 3, [10.0, 20.0, 30.0], "bothatonce"],
	["shadow_again", "Again", "shadow_r6c7", 3, [10.0, 20.0, 30.0], "bothatonce"],
	["shadow_stand_over", "Stand Over", "shadow_r7c7", 3, [0.7, 1.3, 2.0], "guarddogs"],
	["shadow_slipped_leash", "Slipped Leash", "shadow_r9c7", 3, [1.5, 2.5, 4.0], "offthechain"],
	# The healer (the Strings): the Strings themselves ...
	["shadow_first_stitch", "First Stitch", "shadow_r3c3", 2, [2.0, 4.0], ""],
	["shadow_long_thread", "Long Thread", "shadow_r3c5", 2, [2.0, 4.0], ""],
	["shadow_spare_spool", "Spare Spool", "shadow_r4c5", 2, [1.0, 2.0], ""],
	["shadow_full_harness", "Full Harness", "shadow_r8c3", 2, [3.0, 6.0], ""],
	["shadow_taking_the_weight", "Taking the Weight", "shadow_r8c5", 2, [5.0, 7.0], ""],
	["shadow_steady_hands", "Steady Hands", "shadow_r10c2", 5, [3.0, 6.0, 9.0, 12.0, 15.0], ""],
	# ... and one ability's talent each.
	["shadow_heave", "Heave", "shadow_r3c4", 3, [3.0, 7.0, 10.0], "hoist"],
	["shadow_long_drop", "Long Drop", "shadow_r8c6", 3, [0.3, 0.7, 1.0], "stringup"],
	["shadow_snap_back", "Snap Back", "shadow_r9c3", 3, [17.0, 33.0, 50.0], "pulltaut"],
	["shadow_give_and_take", "Give and Take", "shadow_r9c5", 3, [1.0, 2.0, 3.0], "slack"],
	# Three more open talents, with the healer's theme.
	["shadow_many_hands", "Helping Hands", "shadow_r1c1", 3, [2.0, 4.0, 6.0], ""],
	["shadow_lean_on_me", "Lean On Me", "shadow_r1c7", 3, [2.0, 4.0, 6.0], ""],
	["shadow_left_hanging", "Left Hanging", "shadow_r2c4", 2, [10.0, 20.0], ""],
	# Down the middle column under Small Change: caster, open, healer, melee.
	["shadow_deep_call", "Deep Call", "shadow_r6c4", 3, [0.15, 0.35, 0.5], "erode"],
	["shadow_ill_will", "Ill Will", "shadow_r7c4", 3, [5.0, 10.0, 15.0], ""],
	["shadow_hard_pull", "Hard Pull", "shadow_r8c4", 3, [0.7, 1.3, 2.0], "tug"],
	["shadow_wide_pack", "Wide Pack", "shadow_r9c4", 2, [1.0, 2.0], "runthemdown"],
]
const CAPSTONES := ["shadow_interest", "shadow_next_of_kin", "shadow_no_floor", "shadow_running_over",
	"shadow_worked_up", "shadow_take_it_with_you", "shadow_still_wet", "shadow_pincer", "shadow_slipped_leash",
	"shadow_heave", "shadow_taking_the_weight"]
## The healer's talents (what each does in the game: tests/test_strings.gd).
const STRING_TALENTS := ["shadow_first_stitch", "shadow_long_thread", "shadow_spare_spool", "shadow_full_harness",
	"shadow_taking_the_weight", "shadow_steady_hands", "shadow_heave", "shadow_long_drop", "shadow_snap_back", "shadow_give_and_take",
	"shadow_hard_pull"]
## The Hounds' talents (what each does in the game: tests/test_hounds.gd, test_talent_rules).
const HOUND_TALENTS := ["shadow_lean_and_hungry", "shadow_fed", "shadow_worked_up", "shadow_out_of_the_hole", "shadow_long_night",
	"shadow_take_it_with_you", "shadow_pack_leader", "shadow_still_wet", "shadow_share_the_kill", "shadow_pincer", "shadow_again",
	"shadow_stand_over", "shadow_slipped_leash"]

func suite_name() -> String:
	return "shadow_talents"

func _player() -> GDScript:
	return load("res://scripts/player.gd")

func _typed_number(raw: String) -> String:
	var text := RegEx.create_from_string("\\{[^}]*\\}").sub(raw, "", true)
	var m := RegEx.create_from_string("[0-9]+([.,][0-9]+)?").search(text)
	return m.get_string() if m else ""

func test_every_talent_sits_in_its_slot() -> void:
	for row in WANT:
		var id := Talents.id_for_key(str(row[0]))
		assert_eq(id, str(row[2]), "%s sits in its slot" % row[1])
		var t := Talents.get_talent(id)
		assert_eq(str(t.get("name", "")), str(row[1]))
		assert_eq(Talents.max_rank(id), int(row[3]), "%s: ranks" % row[1])
		assert_eq(t.get("values", []), row[4], "%s: what each rank gives" % row[1])
		assert_eq((t.get("values", []) as Array).size(), int(row[3]), "%s: a value for every rank" % row[1])
		assert_true(bool(t.get("implemented", false)), "%s does something" % row[1])
		assert_true(TalentIcons.has_icon(id), "%s has an icon" % row[1])
		assert_eq(Talents.required_ability(id), str(row[5]), "%s: the ability it needs" % row[1])
		assert_eq(_typed_number(str(t.get("desc", ""))), "", "%s: no number typed into its text" % row[1])
		for rank in range(1, int(row[3]) + 1):
			var tip := Talents.tooltip(id, rank)
			assert_eq(TextFill.leftover(tip), "", tip)
			assert_false(tip.contains("?"), tip)
			if str(row[5]) != "":
				assert_contains(tip, "Requires %s to be learned" % Abilities.ability_name(str(row[5])))
			else:
				assert_false(tip.contains("to be learned"), "%s is open to every build" % row[1])

## The caster's talents and the open ones, the Hounds', Baited Steel, and the empty slots.
func test_the_books_talents_and_empty_slots() -> void:
	assert_eq(Talents.layout("shadow"), [[0, 1, 3, 5, 6], [0, 2, 3, 4, 6], [0, 2, 3, 4, 6], [0, 2, 3, 4, 6], [0, 1, 3, 5, 6], [0, 2, 3, 4, 6],
		[0, 2, 3, 4, 6], [1, 2, 3, 4, 5], [0, 2, 3, 4, 6], [1, 2, 3, 4, 5]])
	for row in Talents.layout("shadow"):
		assert_true(row.size() >= Talents.MIN_PER_ROW and row.size() <= Talents.MAX_PER_ROW, "%s: two to seven in a row" % [row])
		for col in row:
			assert_true(row.has(Talents.COLUMNS - 1 - int(col)), "%s is mirrored around the middle" % [row])
	var designed := 0
	var empty := 0
	for id in Talents.in_tree("shadow"):
		if bool(Talents.get_talent(id).get("placeholder", true)):
			empty += 1
		else:
			designed += 1
	assert_eq(designed, WANT.size() + 1, "these, and Tainted Steel")
	assert_eq(empty, 2, "the bottom row's mirror of Steady Hands (the healer took the two that were empty before), and Cut Short's (folded into Hush)")
	# ... on an edge: the caster's talents keep to the middle.
	for id in Talents.in_tree("shadow"):
		if bool(Talents.get_talent(id).get("placeholder", true)):
			var col := int(id.get_slice("c", 1))   # "shadow_r8c2" -> 2 (columns 1 to 7)
			assert_true(col <= 2 or col >= 6 or id == "shadow_r4c5", "%s is on an edge" % id)

func test_running_over_bite_down_and_hush() -> void:
	var p := _player()
	# Running Over: bigger copies, and (capstone) each one open for a while at least.
	assert_eq(DecayKit.spill_amount(600.0), 300.0)
	assert_eq(DecayKit.spill_amount(600.0, 20.0), 420.0, "70% instead of 50%")
	assert_eq(Balance.RUNNING_OVER_OPEN_TIME, 5.0)
	assert_eq(DecayKit.spill_open_until(103.0, 100.0, false), 103.0, "as long as the Decay it came from")
	assert_eq(DecayKit.spill_open_until(103.0, 100.0, true), 105.0)
	assert_eq(DecayKit.spill_open_until(90.0, 100.0, true), 105.0, "from a closed one too")
	assert_eq(DecayKit.spill_open_until(112.0, 100.0, true), 112.0, "never less than it had")
	assert_contains(str(Abilities.get_resource("spill").description), "{spill_pct}")
	var tip := Abilities.tooltip("spill")
	assert_eq(TextFill.leftover(tip), "")
	assert_false(tip.contains("?"), tip)
	assert_contains(Talents.capstone_text(Talents.id_for_key("shadow_running_over")), "5 sec")
	# Bite Down: only the ticks Gnaw speeds up.
	assert_eq(DecayKit.bite_down_crit(true, 20.0), 20.0)
	assert_eq(DecayKit.bite_down_crit(false, 20.0), 0.0, "no Gnaw on it")
	assert_eq(DecayKit.bite_down_crit(true, 0.0), 0.0)
	# Stopping a cast takes time off Hush's cooldown (Cut Short was folded into it), never under what the interrupts share.
	assert_eq(DecayKit.hush_stop_cooldown(20.0, 4.0), 16.0)
	assert_eq(DecayKit.hush_stop_cooldown(20.0, 0.0), 20.0)
	assert_eq(DecayKit.hush_stop_cooldown(17.0, 4.0), Balance.INTERRUPT_SHARED_COOLDOWN, "never under the shared cooldown")
	assert_eq(DecayKit.hush_stop_cooldown(12.0, 4.0), 12.0, "nor does it add any")
	assert_true(float(Abilities.get_resource("hush").cooldown) - Balance.HUSH_INTERRUPT_REFUND >= Balance.INTERRUPT_SHARED_COOLDOWN, "all of it counts")
	assert_eq(Talents.id_for_key("shadow_cut_short"), "", "Cut Short is gone")

func test_capstones() -> void:
	for row in WANT:
		var id := Talents.id_for_key(str(row[0]))
		assert_eq(Talents.has_capstone(id), CAPSTONES.has(str(row[0])), str(row[1]))
		if not Talents.has_capstone(id):
			continue
		var text := Talents.capstone_text(id)
		assert_eq(TextFill.leftover(text), "", text)
		assert_false(text.contains("?"), text)
		assert_eq(_typed_number(str(Talents.get_talent(id).get("capstone", ""))), "", "%s: no number typed into its capstone" % row[1])
	# Interest's capstone is about Blight, which Call Due does not bring with it.
	assert_eq(str(Talents.get_talent(Talents.id_for_key("shadow_interest")).get("capstone_requires", "")), "blight")
	assert_contains(Talents.capstone_text(Talents.id_for_key("shadow_next_of_kin")), "50%")
	assert_contains(Talents.capstone_text(Talents.id_for_key("shadow_interest")), "5 sec")

## The Hounds' talents: the Hounds themselves down the left edge (they work
## whichever ability called them), one ability's talents each down the right.
func test_the_hounds_talents() -> void:
	var seen := {}
	for row in WANT:
		if not HOUND_TALENTS.has(str(row[0])):
			continue
		seen[str(row[0])] = true
		var id := Talents.id_for_key(str(row[0]))
		var col := int(Talents.col_of(id))   # 0 = the left edge
		var tip := Talents.tooltip(id, 1) + " " + Talents.capstone_text(id)
		if str(row[0]) == "shadow_pack_leader":
			assert_eq(int(Talents.tier_of(id)), Talents.ROWS - 1, "the five-rank one sits in the bottom row")
		elif str(row[5]) == "" or str(row[5]) == "blight":
			assert_true(col <= 1, "%s is on the left edge" % row[1])
			assert_contains(tip, "Hounds")
		else:
			assert_eq(col, Talents.COLUMNS - 1, "%s is on the right edge" % row[1])
			assert_true(Abilities.category_of(str(row[5])) == "shadow" and int(Abilities.get_resource(str(row[5])).weapon_requirement) == 1,
				"%s needs a Shadow melee ability" % row[1])
	assert_eq(seen.size(), HOUND_TALENTS.size(), "every one of them is in WANT")
	# Their numbers.
	assert_contains(Talents.tooltip(Talents.id_for_key("shadow_lean_and_hungry"), 3), "4 / 8 / 12%")
	assert_contains(Talents.tooltip(Talents.id_for_key("shadow_pack_leader"), 5), "3 / 6 / 9 / 12 / 15%")
	assert_contains(Talents.tooltip(Talents.id_for_key("shadow_thick_blood"), 3), "15 / 30 / 45%")
	assert_contains(Talents.tooltip(Talents.id_for_key("shadow_feeding_frenzy"), 1), "for 8 sec")
	assert_contains(Talents.capstone_text(Talents.id_for_key("shadow_worked_up")), "10%")
	assert_contains(Talents.capstone_text(Talents.id_for_key("shadow_still_wet")), "10%")
	assert_contains(Talents.capstone_text(Talents.id_for_key("shadow_pincer")), "10 Fury")
	assert_contains(Talents.capstone_text(Talents.id_for_key("shadow_take_it_with_you")), "already Roused")
	assert_contains(Talents.capstone_text(Talents.id_for_key("shadow_slipped_leash")), "third Hound")
	assert_contains(Talents.tooltip(Talents.id_for_key("shadow_share_the_kill"), 1), Abilities.ability_name("shadowstrike"))
	# Off the Chain and Open Up quote their time with the talent in it.
	assert_contains(str(Abilities.get_resource("offthechain").description), "{chain_time}")
	assert_contains(str(Abilities.get_resource("openup").description), "{fx_time}")
	# Linked top down: the most important first.
	for l in [["shadow_lean_and_hungry", "shadow_fed"], ["shadow_fed", "shadow_worked_up"],
			["shadow_long_night", "shadow_take_it_with_you"], ["shadow_pincer", "shadow_again"]]:
		var from := Talents.id_for_key(str(l[0]))
		var to := Talents.id_for_key(str(l[1]))
		assert_true(Talents.links_in_tree("shadow").has([from, to]), "%s opens %s" % l)
		assert_true(int(Talents.get_talent(from).get("tier", 0)) < int(Talents.get_talent(to).get("tier", 0)), "%s sits above %s" % l)

## The healer's talents: the Strings themselves need no one ability, the rest
## one of the healer's spells each; nothing of it sits in the middle of rows
## 5-7, where the line from Interest to Small Change runs.
func test_the_healers_talents() -> void:
	var seen := {}
	for row in WANT:
		if not STRING_TALENTS.has(str(row[0])):
			continue
		seen[str(row[0])] = true
		var id := Talents.id_for_key(str(row[0]))
		var tier := int(Talents.tier_of(id))   # 0 = the top row
		assert_false(int(Talents.col_of(id)) == 3 and tier >= 4 and tier <= 6, "%s keeps clear of Call Due's line" % row[1])
		if str(row[5]) != "":
			assert_eq(Abilities.category_of(str(row[5])), "shadow")
			assert_true(StringsKit.STRING_INSTANTS.has(str(row[5])) or _player().SUPPORT_CASTS.has(str(row[5])), "%s needs one of the healer's spells" % row[1])
	assert_eq(seen.size(), STRING_TALENTS.size(), "every one of them is in WANT")
	assert_eq(int(Talents.tier_of(Talents.id_for_key("shadow_steady_hands"))), Talents.ROWS - 1, "the five-rank one sits in the bottom row")
	# Their numbers.
	assert_contains(Talents.tooltip(Talents.id_for_key("shadow_steady_hands"), 5), "3 / 6 / 9 / 12 / 15%")
	assert_contains(Talents.tooltip(Talents.id_for_key("shadow_taking_the_weight"), 1), "5 / 7%")
	assert_contains(Talents.tooltip(Talents.id_for_key("shadow_taking_the_weight"), 1), "instead of 3%")
	assert_contains(Talents.capstone_text(Talents.id_for_key("shadow_taking_the_weight")), "40 m")
	assert_contains(Talents.capstone_text(Talents.id_for_key("shadow_taking_the_weight")), "30 m")
	assert_contains(Talents.tooltip(Talents.id_for_key("shadow_full_harness"), 1), "has 3 of your Strings")
	assert_contains(Talents.capstone_text(Talents.id_for_key("shadow_heave")), "0.5 sec")
	assert_contains(Talents.tooltip(Talents.id_for_key("shadow_give_and_take"), 3), "1 / 2 / 3 sec")
	assert_contains(Talents.tooltip(Talents.id_for_key("shadow_snap_back"), 1), "17 / 33 / 50%")
	assert_contains(Talents.tooltip(Talents.id_for_key("shadow_lean_on_me"), 1), "for 4 sec")
	assert_contains(Talents.tooltip(Talents.id_for_key("shadow_left_hanging"), 1), "10 / 20%")
	assert_false(Talents.tooltip(Talents.id_for_key("shadow_long_drop"), 1).contains("Frost Bolt"), "real damage numbers")
	# String and Slack quote their time with the talent in it.
	assert_contains(str(Abilities.get_resource("puppetstring").description), "{string_time}")
	assert_contains(str(Abilities.get_resource("slack").description), "{slack_time}")
	# Long Thread opens Spare Spool.
	var from := Talents.id_for_key("shadow_long_thread")
	var to := Talents.id_for_key("shadow_spare_spool")
	assert_true(Talents.links_in_tree("shadow").has([from, to]), "maxing Long Thread opens Spare Spool")
	assert_true(int(Talents.tier_of(from)) < int(Talents.tier_of(to)), "the more important one sits higher")
	assert_eq(int(Talents.col_of(from)), int(Talents.col_of(to)), "straight under it")

## The middle column: Deep Call, Ill Will, Hard Pull, Wide Pack.
func test_the_middle_column() -> void:
	var p := _player()
	# Deep Call: only on a target whose Breach is open, never under 0.2 sec.
	assert_eq(StringsKit.deep_call_cast(2.0, 0.5, true), 1.5)
	assert_eq(StringsKit.deep_call_cast(2.0, 0.5, false), 2.0, "the Breach is closed")
	assert_eq(StringsKit.deep_call_cast(2.0, 0.0, true), 2.0, "not without the talent")
	assert_eq(StringsKit.deep_call_cast(0.3, 0.5, true), 0.2)
	# Ill Will: crits of damage over time only (CombatSystem asks only for crits).
	assert_eq(ShadowTalentsKit.ill_will_bonus(true, 15.0), [15.0, "Ill Will"])
	assert_eq(ShadowTalentsKit.ill_will_bonus(false, 15.0), [], "a direct hit")
	assert_eq(ShadowTalentsKit.ill_will_bonus(true, 0.0), [])
	# Hard Pull: Tug's time, and Tug's tooltip quotes it with the talent in it.
	assert_eq(StringsKit.tug_time(), Balance.TUG_TIME)
	assert_eq(StringsKit.tug_time(2.0), Balance.TUG_TIME + 2.0)
	assert_contains(str(Abilities.get_resource("tug").description), "{tug_time}")
	# Wide Pack: more enemies per bite during Run Them Down.
	assert_eq(HoundsKit.run_down_targets(), Balance.RUN_DOWN_TARGETS)
	assert_eq(HoundsKit.run_down_targets(2.0), Balance.RUN_DOWN_TARGETS + 2)
	assert_contains(str(Abilities.get_resource("runthemdown").description), "{run_down_targets}")
	for id in ["tug", "runthemdown"]:
		var tip := Abilities.tooltip(id)
		assert_eq(TextFill.leftover(tip), "", tip)
		assert_false(tip.contains("?"), tip)
	# Small Change moved up under Interest; old saves keep its points.
	assert_eq(Talents.rearranged({"shadow_r8c4": 2}, Talents.SHADOW_MIDDLE_MOVED, []), {"shadow_r5c4": 2})

func test_call_dues_talents_are_linked_top_down() -> void:
	var from := Talents.id_for_key("shadow_interest")
	var to := Talents.id_for_key("shadow_small_change")
	assert_true(Talents.links_in_tree("shadow").has([from, to]), "maxing Interest opens Small Change")
	assert_true(int(Talents.get_talent(from).get("tier", 0)) < int(Talents.get_talent(to).get("tier", 0)), "the more important one sits higher")
	assert_eq(int(Talents.get_talent(from).get("col", 0)), int(Talents.get_talent(to).get("col", -1)), "straight down the middle")

func test_slow_death_and_wasting() -> void:
	var p := _player()
	assert_eq(ShadowTalentsKit.dot_speed_with(1.0, 0.0), 1.0)
	assert_true(is_equal_approx(ShadowTalentsKit.dot_speed_with(1.0, 6.0), 1.06), "6% more ticks in the same time")
	assert_true(is_equal_approx(ShadowTalentsKit.dot_speed_with(1.25, 4.0), 1.3), "on top of what already speeds it up")
	assert_eq(ShadowTalentsKit.dot_speed_with(1.0, -5.0), 1.0)
	# Decay asks for it itself.
	assert_eq(DecayKit.decay_interval(1.0, false, 0.0), 1.0)
	assert_true(is_equal_approx(DecayKit.decay_interval(1.0, false, 6.0), 1.0 / 1.06))
	assert_true(is_equal_approx(DecayKit.decay_interval(1.25, true, 4.0), 1.0 / (1.25 * 2.0 * 1.04)), "Haste, Gnaw and Wasting multiply")
	# Decay's ticks are exact hits: what my talents add to them is handed over by name.
	assert_eq(DecayKit.decay_tick_bonuses(0.0, 0.0, 0.0, false), [])
	assert_eq(DecayKit.decay_tick_bonuses(6.0, 10.0, 100.0, false), [[6.0, "Slow Death"], [10.0, "Hooked Claws"]], "Bitter End: only the last drop")
	assert_eq(DecayKit.decay_tick_bonuses(6.0, 10.0, 100.0, true), [[6.0, "Slow Death"], [10.0, "Hooked Claws"], [100.0, "Bitter End"]])
	assert_eq(DecayKit.decay_tick_bonuses(0.0, 0.0, 50.0, true), [[50.0, "Bitter End"]])

func test_finish_it_inevitable_and_carrion() -> void:
	var p := _player()
	assert_eq(Balance.FINISH_IT_HEALTH_PCT, 25.0)
	assert_true(ShadowTalentsKit.finish_it_applies(24.0, 100.0))
	assert_false(ShadowTalentsKit.finish_it_applies(25.0, 100.0), "below it, not at it")
	assert_false(ShadowTalentsKit.finish_it_applies(100.0, 100.0))
	assert_false(ShadowTalentsKit.finish_it_applies(0.0, 0.0), "something without health")
	assert_eq(Balance.INEVITABLE_TIME, 8.0)
	assert_false(ShadowTalentsKit.inevitable_applies(0.0, 100.0), "an enemy I never damaged")
	assert_false(ShadowTalentsKit.inevitable_applies(10.0, 18.0), "more than that long ago")
	assert_true(ShadowTalentsKit.inevitable_applies(10.0, 18.5))
	assert_eq(ShadowTalentsKit.carrion_mana(1000.0, 2.0), 20.0)
	assert_eq(ShadowTalentsKit.carrion_mana(1000.0, 0.0), 0.0)
	assert_eq(Balance.SPITE_TIME, 4.0)
	for m in ["_shadow_talents_modify", "_spite_on_hit_taken", "_spite_hit", "_on_enemy_died_shadow", "_note_first_hit", "interest_ready"]:
		var found := false
		for row in PlayerSource.methods_of(p):
			found = found or str(row["name"]) == m
		assert_true(found, "Player has %s" % m)

func test_call_due_with_interest_and_small_change() -> void:
	var p := _player()
	assert_eq(DecayKit.call_due_damage(1000.0), 1250.0)
	assert_eq(DecayKit.call_due_damage(1000.0, 15.0), 1400.0, "Interest adds to what Call Due adds")
	assert_eq(DecayKit.call_due_left(1000.0, 0.0), 0.0, "without Small Change it ends the Decay")
	assert_eq(DecayKit.call_due_left(1000.0, 20.0), 200.0)
	assert_eq(Balance.INTEREST_TIME, 5.0)
	# Its tooltip quotes the number with the talent in it.
	var desc := str(Abilities.get_resource("calldue").description)
	assert_contains(desc, "{call_due_pct}")
	assert_eq(_typed_number(desc), "")
	var tip := Abilities.tooltip("calldue")
	assert_eq(TextFill.leftover(tip), "")
	assert_false(tip.contains("?"), tip)

func test_lure() -> void:
	var p := _player()
	assert_eq(DecayKit.WITHER_TICK_ID, "dot_corrupted", "a tick of Wither's effect")
	assert_eq(str(Abilities.get_resource("corruption").on_hit_effect.id), "corrupted")
	assert_eq(DecayKit.seep_feed_pct("dot_corrupted", 50.0), 50.0)
	assert_eq(DecayKit.seep_feed_pct("dot_corrupted", 0.0), 0.0, "not without the talent")
	assert_eq(DecayKit.seep_feed_pct("dot_burning", 50.0), 0.0, "no other damage over time")
	assert_eq(DecayKit.seep_feed_pct("dot_decay", 50.0), 0.0, "Decay never feeds itself")
	assert_eq(DecayKit.decay_feed_pct("dot_corrupted", PackedStringArray(["Shadow", "Spell", "DoT"]), false, true), 0.0, "on its own a tick adds nothing")

func test_next_of_kin() -> void:
	var p := _player()
	assert_eq(DecayKit.kin_amount(1000.0, 0.0), 1000.0, "without it: what was left")
	assert_eq(DecayKit.kin_amount(1000.0, 30.0), 1300.0)
	assert_eq(Balance.NEXT_OF_KIN_SECOND_PCT, 50.0)
	assert_eq(DecayKit.kin_amount(1000.0, 30.0, true), 650.0, "the second enemy: half of what moved on")

func test_no_floor() -> void:
	var p := _player()
	assert_eq(DecayKit.bottomless_time(), 8.0)
	assert_eq(DecayKit.bottomless_time(4.0), 12.0)
	# Its capstone: an open Decay stays open until Bottomless is over.
	assert_true(DecayKit.decay_held_open(103.0, 100.0, 112.0), "it would close before Bottomless ends")
	assert_false(DecayKit.decay_held_open(115.0, 100.0, 112.0), "it is open for longer anyway")
	assert_false(DecayKit.decay_held_open(99.0, 100.0, 112.0), "a closed one stays closed")
	assert_false(DecayKit.decay_held_open(103.0, 100.0, 0.0), "no Bottomless, or no capstone")
	assert_false(DecayKit.decay_held_open(103.0, 113.0, 112.0), "Bottomless is over")
	var desc := str(Abilities.get_resource("bottomless").description)
	assert_contains(desc, "{bottomless_time}")
	var tip := Abilities.tooltip("bottomless")
	assert_eq(TextFill.leftover(tip), "")
	assert_false(tip.contains("?"), tip)
