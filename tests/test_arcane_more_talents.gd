@tool
extends McpTestSuite

# The second batch of Arcane melee talents (Practiced Hand, Heavy Hand, Curtain
# Call, No Loose Ends, Time Signature, Full House, Dress Rehearsal) and the
# Arcane book's bottom row (Silvered, Running Clock, Fine Edge).

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")
const Details = preload("res://scripts/core/details.gd")

# [key, name, ranks, the ability it needs, slot, values]
const TALENTS := [
	["arcane_practiced_hand", "Practiced Hand", 3, "swiftcut", "arcane_r5c3", [3.0, 6.0, 9.0]],
	["arcane_heavy_hand", "Heavy Hand", 2, "deepcut", "arcane_r5c5", [10.0, 20.0]],
	["arcane_curtain_call", "Curtain Call", 2, "encore", "arcane_r7c3", [10.0, 20.0]],
	["arcane_no_loose_ends", "No Loose Ends", 2, "latecut", "arcane_r8c3", [0.5, 1.0]],
	["arcane_time_signature", "Time Signature", 2, "encore", "arcane_r8c5", [0.25, 0.5]],
	["arcane_full_house", "Full House", 2, "widecut", "arcane_r9c3", [1.0, 2.0]],
	["arcane_dress_rehearsal", "Dress Rehearsal", 2, "doubletime", "arcane_r9c5", [2.0, 4.0]],
	["arcane_silvered", "Silvered", 5, "", "arcane_r10c2", [0.3, 0.6, 0.9, 1.2, 1.5]],
	["arcane_running_clock", "Running Clock", 5, "", "arcane_r10c4", [2.0, 4.0, 6.0, 8.0, 10.0]],
	["arcane_fine_edge", "Fine Edge", 5, "", "arcane_r10c6", [2.0, 4.0, 6.0, 8.0, 10.0]],
]
const CAPSTONES := ["arcane_no_loose_ends", "arcane_dress_rehearsal"]

func suite_name() -> String:
	return "arcane_more_talents"

func _player() -> GDScript:
	return load("res://scripts/player.gd")

func _id(key: String) -> String:
	return Talents.id_for_key(key)

func _desc(key: String) -> String:
	return Talents.description(_id(key))

func _typed_number(raw: String) -> String:
	var text := RegEx.create_from_string("\\{[^}]*\\}").sub(raw, "", true)
	var m := RegEx.create_from_string("[0-9]+([.,][0-9]+)?").search(text)
	return m.get_string() if m else ""

func _trace(id: String, key: int, amount: int) -> Dictionary:
	return {"id": id, "key": key, "amount": amount, "born": 0.0, "until": 10.0}

func test_they_are_in_the_tree() -> void:
	assert_eq(TALENTS.size(), 10)
	for row in TALENTS:
		var id := _id(str(row[0]))
		assert_eq(id, str(row[4]), "%s sits in its slot" % row[1])
		var t := Talents.get_talent(id)
		assert_eq(str(t.get("name", "")), str(row[1]))
		assert_eq(Talents.max_rank(id), int(row[2]))
		assert_eq(t.get("values", []), row[5], "%s: its numbers" % row[1])
		assert_eq(Talents.required_ability(id), str(row[3]))
		assert_true(bool(t.get("implemented", false)), "%s does something" % row[1])
		assert_true(TalentIcons.has_icon(id), "%s has an icon" % row[1])
		assert_eq(Talents.has_capstone(id), CAPSTONES.has(str(row[0])), "%s: capstone" % row[1])
		var tip := Talents.tooltip(id, 1)
		assert_eq(TextFill.leftover(tip), "", "%s: every placeholder is filled" % row[1])
		assert_false(tip.contains("?"), "%s: %s" % [row[1], tip])
		assert_eq(_typed_number(str(t.get("desc", ""))), "", "%s: no typed numbers" % row[1])
		assert_eq(_typed_number(str(t.get("capstone", ""))), "", "%s: no typed numbers in the capstone" % row[1])

func test_where_they_sit() -> void:
	var layout: Array = Talents.layout("arcane")
	assert_eq(layout[4], [1, 2, 3, 4, 5], "row 5 got two slots (and later its middle one)")
	assert_eq(layout[7], [1, 2, 4, 5], "row 8 got two slots")
	# The bottom row: five ranks each, nothing needed, no links.
	for key in ["arcane_silvered", "arcane_running_clock", "arcane_fine_edge"]:
		var id := _id(key)
		assert_eq(Talents.tier_of(id), Talents.ROWS - 1)
		assert_eq(Talents.max_rank(id), 5)
		assert_eq(Talents.required_ability(id), "")
		assert_true(Talents.sources_of(id).is_empty() and Talents.targets_of(id).is_empty())
	# Encore's three run straight down, the most important first.
	var showing := _id("arcane_second_showing")
	var signature := _id("arcane_time_signature")
	assert_true(Talents.targets_of(showing).has(signature))
	assert_true(Talents.tier_of(showing) < Talents.tier_of(signature))
	assert_eq(Talents.col_of(showing), Talents.col_of(signature))
	# One slot of the book is still empty.
	var empty := 0
	for id in Talents.in_tree("arcane"):
		var placeholder := bool(Talents.get_talent(id).get("placeholder", true))
		assert_eq(TalentIcons.has_icon(id), not placeholder, "%s: designed talents have an icon, empty ones don't" % id)
		if placeholder:
			empty += 1
	assert_eq(empty, 1)

func test_practiced_hand() -> void:
	var p := _player()
	assert_eq(p.practiced_hand_pct(9.0, 3), 27.0, "9% for each of three Traces")
	assert_eq(p.practiced_hand_pct(3.0, 1), 3.0)
	assert_eq(p.practiced_hand_pct(9.0, 0), 0.0, "no Traces: nothing")
	assert_eq(p.practiced_hand_pct(0.0, 3), 0.0)
	assert_eq(p.practiced_hand_pct(9.0, 6), 54.0, "more Traces during Double Time count too")
	assert_contains(_desc("arcane_practiced_hand"), "3 / 6 / 9% more damage for each Trace")

func test_heavy_hand() -> void:
	var p := _player()
	assert_eq(p.trace_amount("deepcut", 1000, 20.0), 1200)
	assert_eq(p.trace_amount("deepcut", 1000, 10.0), 1100)
	assert_eq(p.trace_amount("deepcut", 1000, 0.0), 1000)
	assert_eq(p.trace_amount("swiftcut", 1000, 20.0), 1000, "only Deep Cut's Trace")
	assert_eq(p.trace_amount("latecut", 1000, 20.0), 1000)
	assert_contains(_desc("arcane_heavy_hand"), "10 / 20% more damage than the strike dealt")

func test_curtain_call() -> void:
	assert_eq(Balance.CURTAIN_CALL_TRACES, 3)
	var p := _player()
	# (Encore has no cooldown any more: a full replay hits harder instead.)
	assert_eq(float(Abilities.get_resource("encore").cooldown), 0.0)
	assert_eq(p.curtain_call_pct(20.0, 3), 20.0)
	assert_eq(p.curtain_call_pct(10.0, 6), 10.0)
	assert_eq(p.curtain_call_pct(20.0, 2), 0.0, "fewer than three Traces: nothing")
	assert_eq(p.curtain_call_pct(0.0, 3), 0.0)
	assert_contains(_desc("arcane_curtain_call"), "replays 3 or more Traces")
	assert_contains(_desc("arcane_curtain_call"), "each replay deals 10 / 20% more damage")
	# What it adds is a line of its own on the damage meter.
	var rows: Array = Details.split_amount("encore", 720, false, [[p.CURTAIN_CALL_LABEL, 20.0]])
	assert_eq(rows.size(), 2)
	assert_eq(int(rows[0][1]), 600, "Encore's line keeps what the replay deals without it")
	assert_eq(str(rows[1][0]), "bonus:Curtain Call")
	assert_eq(int(rows[1][1]), 120)
	var src := PlayerSource.text()
	assert_contains(src, "_exact_hit(foe, amount, ENCORE_ID, \"arcane\", PackedStringArray(TRACE_TAGS), bonuses)")
	assert_false(src.contains("_cut_cooldown(ENCORE_ID"), "nothing shortens a cooldown Encore does not have")
	assert_false(src.contains("cooldowns.erase(ENCORE_ID)"))

func test_no_loose_ends() -> void:
	var p := _player()
	assert_eq(p.late_cut_delay(0.0), 3.0)
	assert_eq(p.late_cut_delay(0.5), 2.5)
	assert_eq(p.late_cut_delay(1.0), 2.0)
	assert_contains(_desc("arcane_no_loose_ends"), "0.5 / 1 sec sooner")
	assert_contains(Talents.capstone_text(_id("arcane_no_loose_ends")), "leaves a Trace of its own")
	# Is the first hit's Trace still there when the second lands?
	var t := [_trace("latecut", 4, 200), _trace("swiftcut", 5, 100)]
	assert_true(p.has_trace_key(t, 4))
	assert_false(p.has_trace_key(t, 9))
	assert_false(p.has_trace_key([], 4))
	# Late Cut's tooltip counts the delay with the talent.
	assert_false(str(Abilities.get_resource("latecut").description).contains("{b:LATE_CUT_DELAY}"))
	assert_contains(Abilities.tooltip("latecut"), "3 sec later")

func test_time_signature() -> void:
	var p := _player()
	assert_eq(p.time_signature_cut(0.5, 3), 1.5)
	assert_eq(p.time_signature_cut(0.25, 3), 0.75)
	assert_eq(p.time_signature_cut(0.5, 6), 3.0)
	assert_eq(p.time_signature_cut(0.5, 0), 0.0)
	assert_eq(p.time_signature_cut(0.0, 3), 0.0)
	assert_contains(_desc("arcane_time_signature"), "0.25 / 0.5 sec off the cooldowns of your other Arcane spells and abilities")
	assert_contains(_desc("arcane_time_signature"), "Interrupts are not affected")
	# What it reaches: everything in the Arcane book, never an interrupt.
	assert_true(p.shatter_cuts("arcane", false))
	assert_false(p.shatter_cuts("arcane", true))
	assert_false(p.shatter_cuts("frost", false))

func test_full_house() -> void:
	assert_eq(Balance.FULL_HOUSE_ENEMIES, 3)
	assert_eq(Balance.FULL_HOUSE_TIME, 6.0)
	assert_eq(Balance.FULL_HOUSE_PCT, 50.0)
	assert_eq(Balance.FULL_HOUSE_RADIUS, 5.0)
	var p := _player()
	# A Wide Cut into three or more sets up the next Encore.
	assert_true(p.full_house_ready(2.0, 3))
	assert_true(p.full_house_ready(1.0, 5))
	assert_false(p.full_house_ready(2.0, 2), "fewer than three enemies")
	assert_false(p.full_house_ready(0.0, 5), "not without the talent")
	# Each other enemy takes half of every replay, under Full House's own name.
	assert_eq(p.full_house_amount(600), 300)
	assert_eq(p.full_house_amount(333), 167, "rounded")
	assert_eq(p.full_house_amount(0), 0)
	assert_eq(Details.spell_name(p.FULL_HOUSE_HIT_ID), "Full House", "its own line on the meter")
	assert_ne(Details.spell_color(p.FULL_HOUSE_HIT_ID), Color(0.7, 0.7, 0.75))
	assert_false(Abilities.PATHS.has(p.FULL_HOUSE_HIT_ID), "no ability")
	var fx: Resource = p.make_full_house_fx()
	assert_eq(str(fx.display_name), "Full House")
	assert_eq(float(fx.duration), Balance.FULL_HOUSE_TIME)
	assert_false(bool(fx.is_debuff))
	assert_contains(str(fx.description), "50% of its damage")
	var desc := _desc("arcane_full_house")
	assert_contains(desc, "hits 3 or more enemies")
	assert_contains(desc, "your next %s within 6 sec" % Abilities.ability_name("encore"))
	assert_contains(desc, "up to 1 / 2 other enemies within 5 m")
	assert_contains(desc, "50% of its damage")
	var src := PlayerSource.text()
	assert_contains(src, "if full_house_ready(_talent(\"arcane_full_house\"), hit.size()):\n\t\tstatus.apply(make_full_house_fx(), self)")
	assert_contains(src, "_exact_hit(e, share, FULL_HOUSE_HIT_ID, \"arcane\", PackedStringArray(TRACE_TAGS), bonuses)")
	assert_contains(src, "\t\tstatus.remove(FULL_HOUSE_FX)\n", "the Encore uses it up")

func test_dress_rehearsal() -> void:
	var p := _player()
	assert_eq(p.double_time_time(0.0), 10.0)
	assert_eq(p.double_time_time(2.0), 12.0)
	assert_eq(p.double_time_time(4.0), 14.0)
	assert_contains(_desc("arcane_dress_rehearsal"), "2 / 4 sec longer")
	var cap := Talents.capstone_text(_id("arcane_dress_rehearsal"))
	assert_contains(cap, "The first %s during %s does not use up your Traces" % [Abilities.ability_name("encore"), Abilities.ability_name("doubletime")])
	assert_eq(str(Talents.get_talent(_id("arcane_dress_rehearsal")).get("capstone_requires", "")), "encore", "without Encore it does nothing")
	# The free one keeps the Traces whatever Second Showing rolls; the next one does not.
	assert_false(p.encore_uses_traces(0.0, 50.0, true))
	assert_false(p.encore_uses_traces(20.0, 99.0, true))
	assert_true(p.encore_uses_traces(0.0, 50.0, false))
	assert_true(p.encore_uses_traces(0.0, 50.0), "an Encore outside it is what it was")
	var fx: Resource = p.make_dress_rehearsal_fx(14.0)
	assert_eq(str(fx.display_name), "Dress Rehearsal")
	assert_eq(float(fx.duration), 14.0, "as long as Double Time lasts")
	assert_contains(str(fx.description), "does not use up your Traces")
	var src := PlayerSource.text()
	assert_contains(src, "var free: bool = status.has(DRESS_REHEARSAL_FX) and status.has(DOUBLE_TIME_FX)")
	assert_contains(src, "status.apply(make_dress_rehearsal_fx(time), self)")
	assert_false(str(Abilities.get_resource("doubletime").description).contains("{b:DOUBLE_TIME_TIME}"))
	assert_contains(Abilities.tooltip("doubletime"), "For 10 sec")

# --- The bottom row ------------------------------------------------------------------------

func test_silvered() -> void:
	var p := _player()
	assert_eq(p.silvered_heal(1000, 1.5), 15)
	assert_eq(p.silvered_heal(1000, 0.3), 3)
	assert_eq(p.silvered_heal(20000, 0.9), 180)
	assert_eq(p.silvered_heal(1000, 0.0), 0)
	assert_eq(Details.spell_name("silvered"), "Silvered", "its own line on the meter")
	assert_contains(_desc("arcane_silvered"), "0.3 / 0.6 / 0.9 / 1.2 / 1.5% of your maximum health")

func test_running_clock() -> void:
	var p := _player()
	# An Arcane spell: Lapse and Interval Ward's rate, plus the talent.
	assert_eq(p.arcane_cooldown_rate(1.0, true, true, 0.0), 1.0)
	assert_true(is_equal_approx(p.arcane_cooldown_rate(1.0, true, true, 10.0), 1.1))
	assert_true(is_equal_approx(p.arcane_cooldown_rate(2.0, true, true, 10.0), 2.1), "on top of Lapse")
	# An Arcane ability (the tank's, the melee's): the talent alone.
	assert_true(is_equal_approx(p.arcane_cooldown_rate(2.0, false, true, 10.0), 1.1), "Lapse is for spells")
	assert_true(is_equal_approx(p.arcane_cooldown_rate(1.0, false, true, 4.0), 1.04))
	# Anything else (another book, an interrupt): untouched.
	assert_eq(p.arcane_cooldown_rate(2.0, false, false, 10.0), 1.0)
	assert_contains(_desc("arcane_running_clock"), "2 / 4 / 6 / 8 / 10% faster")
	assert_contains(_desc("arcane_running_clock"), "Interrupts are not affected")

func test_fine_edge() -> void:
	assert_contains(_desc("arcane_fine_edge"), "2 / 4 / 6 / 8 / 10% more damage")
	assert_contains(_desc("arcane_fine_edge"), "a melee weapon in each hand")
	# What it counts: Arcane abilities (the tank's and the melee's), not spells.
	for id in ["swiftcut", "deepcut", "latecut", "widecut", "doubleup", "ripple", "missedbeat"]:
		var tags := Abilities.tags_of(id)
		assert_true(tags.has("Arcane") and tags.has("Ability"), "%s is an Arcane ability" % id)
	assert_false(Abilities.tags_of("unravel").has("Ability"))
