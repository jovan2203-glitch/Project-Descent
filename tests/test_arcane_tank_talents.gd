@tool
extends McpTestSuite

# The Arcane tank's talents, down both edges of the Arcane book. Left, what makes
# and shatters Reflections: Sharp Edges, Clockwork, Spare Copy, Second Self, Wide
# Rings, On the Beat, Head Count. Right, staying alive: Light Feet, Empty Room,
# Bent Light, Understudy, Loud Exit, Good Likeness. And the Rune of the Two-Way
# Mirror (Rare): Mirror Sigil repeats Reflection shatters.

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const Stats = preload("res://scripts/core/stats.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")
const Details = preload("res://scripts/core/details.gd")
const Runes = preload("res://scripts/runes.gd")
const ItemDB = preload("res://scripts/core/item_db.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")

# [key, name, ranks, the ability it needs, slot, values]
const TALENTS := [
	["arcane_sharp_edges", "Sharp Edges", 3, "", "arcane_r2c1", [10.0, 20.0, 30.0]],
	["arcane_clockwork", "Clockwork", 2, "", "arcane_r3c1", [0.25, 0.5]],
	["arcane_spare_copy", "Spare Copy", 2, "", "arcane_r4c1", [10.0, 20.0]],
	["arcane_second_self", "Second Self", 2, "doubleup", "arcane_r5c2", [15.0, 30.0]],
	["arcane_wide_rings", "Wide Rings", 2, "ripple", "arcane_r7c1", [1.0, 2.0]],
	["arcane_on_the_beat", "On the Beat", 3, "missedbeat", "arcane_r8c2", [10.0, 20.0, 30.0]],
	["arcane_head_count", "Head Count", 2, "fullset", "arcane_r9c1", [2.0, 4.0]],
	["arcane_light_feet", "Light Feet", 3, "", "arcane_r2c7", [1.0, 2.0, 3.0]],
	["arcane_empty_room", "Empty Room", 3, "", "arcane_r3c7", [4.0, 8.0, 12.0]],
	["arcane_bent_light", "Bent Light", 2, "", "arcane_r4c7", [1.0, 2.0]],
	["arcane_understudy", "Understudy", 2, "standin", "arcane_r5c6", [2.0, 4.0]],
	["arcane_loud_exit", "Loud Exit", 1, "tradeplaces", "arcane_r7c7", [1.0]],
	["arcane_good_likeness", "Good Likeness", 2, "decoy", "arcane_r8c6", [1.0, 2.0]],
]
const CAPSTONES := ["arcane_sharp_edges", "arcane_wide_rings", "arcane_on_the_beat", "arcane_good_likeness"]
const SHATTER_TAGS := ["Arcane", "Ability", "AoE"]

var _saved_records := {}

func suite_name() -> String:
	return "arcane_tank_talents"

func setup() -> void:
	_saved_records = ItemDB.records.duplicate(true)

func teardown() -> void:
	ItemDB.records = _saved_records

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

func _has_method(path: String, method: String) -> bool:
	for m in PlayerSource.methods_of(load(path)):
		if str(m["name"]) == method:
			return true
	return false

# --- The tree ---------------------------------------------------------------------------

func test_they_are_in_the_tree() -> void:
	assert_eq(TALENTS.size(), 13)
	for row in TALENTS:
		var id := _id(str(row[0]))
		assert_eq(id, str(row[4]), "%s sits in its slot" % row[1])
		var t := Talents.get_talent(id)
		assert_eq(str(t.get("name", "")), str(row[1]))
		assert_eq(Talents.max_rank(id), int(row[2]))
		assert_eq(t.get("values", []), row[5], "%s: its numbers" % row[1])
		assert_eq(Talents.required_ability(id), str(row[3]))
		assert_false(bool(t.get("placeholder", true)), "%s is a real talent" % row[1])
		assert_true(bool(t.get("implemented", false)), "%s does something" % row[1])
		assert_true(TalentIcons.has_icon(id), "%s has an icon" % row[1])
		assert_eq(Talents.has_capstone(id), CAPSTONES.has(str(row[0])), "%s: capstone" % row[1])
		var tip := Talents.tooltip(id, 1)
		assert_eq(TextFill.leftover(tip), "", "%s: every placeholder is filled" % row[1])
		assert_false(tip.contains("?"), "%s: %s" % [row[1], tip])
		# Nothing in the texts is a typed number.
		assert_eq(_typed_number(str(t.get("desc", ""))), "", "%s: no typed numbers" % row[1])
		assert_eq(_typed_number(str(t.get("capstone", ""))), "", "%s: no typed numbers in the capstone" % row[1])

## The tank runs down both edges; rows 2, 3 and 9 got their edge slots for it.
func test_where_they_sit() -> void:
	var layout: Array = Talents.layout("arcane")
	assert_eq(layout[1], [0, 1, 3, 5, 6])
	assert_eq(layout[2], [0, 2, 4, 6])
	assert_eq(layout[8], [0, 2, 4, 6])
	for row in TALENTS:
		var col := Talents.col_of(str(row[4]))
		assert_true(col <= 1 or col >= 5, "%s is on an edge of the book" % row[1])
		assert_true(Talents.tier_of(str(row[4])) < Talents.ROWS - 1, "%s is above the bottom row" % row[1])
	# The caster's talents kept their slots.
	for pair in [["arcane_seventh_sigil", "arcane_r1c3"], ["arcane_etched_darts", "arcane_r2c2"],
			["arcane_polished_glass", "arcane_r3c3"], ["arcane_aftershock", "arcane_r4c4"]]:
		assert_eq(_id(str(pair[0])), str(pair[1]))
	# The last edge slot went to Crowd of One's talent.
	assert_eq(_id("arcane_full_crowd"), "arcane_r9c7")
	for id in Talents.in_tree("arcane"):
		assert_eq(TalentIcons.has_icon(id), not bool(Talents.get_talent(id).get("placeholder", true)),
			"%s: designed talents have an icon, empty ones don't" % id)

func test_links() -> void:
	for pair in [["arcane_sharp_edges", "arcane_clockwork"], ["arcane_clockwork", "arcane_spare_copy"],
			["arcane_light_feet", "arcane_empty_room"], ["arcane_empty_room", "arcane_bent_light"]]:
		var from := _id(str(pair[0]))
		var to := _id(str(pair[1]))
		assert_true(Talents.targets_of(from).has(to), "%s -> %s" % pair)
		assert_true(Talents.tier_of(from) < Talents.tier_of(to), "%s is the higher one" % pair[0])
		assert_eq(Talents.col_of(from), Talents.col_of(to), "straight down the edge")

# --- Left edge: making and shattering Reflections ------------------------------------------

func test_sharp_edges() -> void:
	assert_contains(_desc("arcane_sharp_edges"), "10 / 20 / 30% more damage")
	assert_eq(Balance.SHARP_EDGES_RADIUS, 7.0)
	var p := _player()
	assert_eq(ArcaneTankKit.shatter_radius_for(false), 5.0)
	assert_eq(ArcaneTankKit.shatter_radius_for(true), 7.0, "the capstone: further")
	var cap := Talents.capstone_text(_id("arcane_sharp_edges"))
	assert_contains(cap, "within 7 m")
	assert_contains(cap, "instead of 5 m")
	assert_eq(str(ArcaneTankKit.SHARP_EDGES_LABEL), "Sharp Edges")

func test_clockwork() -> void:
	var p := _player()
	assert_eq(ArcaneTankKit.shatter_cut(0.0), 0.5)
	assert_eq(ArcaneTankKit.shatter_cut(0.25), 0.75)
	assert_eq(ArcaneTankKit.shatter_cut(0.5), 1.0, "twice the time at max rank")
	assert_contains(_desc("arcane_clockwork"), "0.25 / 0.5 sec more")

func test_spare_copy() -> void:
	var p := _player()
	assert_true(ArcaneTankKit.dodge_uses_reflection(false, 0.0, 0.0), "without it a dodge always uses one up")
	assert_false(ArcaneTankKit.dodge_uses_reflection(true, 0.0, 50.0), "never during Crowd of One")
	assert_false(ArcaneTankKit.dodge_uses_reflection(false, 20.0, 19.9), "the chance came up: it stays")
	assert_true(ArcaneTankKit.dodge_uses_reflection(false, 20.0, 20.0))
	assert_true(ArcaneTankKit.dodge_uses_reflection(false, 10.0, 15.0))
	assert_contains(_desc("arcane_spare_copy"), "10 / 20% chance")
	assert_contains(_desc("arcane_spare_copy"), "It still shatters")

func test_second_self() -> void:
	assert_eq(Balance.SECOND_SELF_REFLECTIONS, 2)
	var p := _player()
	assert_eq(ArcaneTankKit.double_up_reflections(0.0, 0.0), 1)
	assert_eq(ArcaneTankKit.double_up_reflections(30.0, 29.0), 2)
	assert_eq(ArcaneTankKit.double_up_reflections(30.0, 30.0), 1)
	assert_eq(ArcaneTankKit.double_up_reflections(15.0, 14.0), 2)
	assert_contains(_desc("arcane_second_self"), "15 / 30% chance to create 2 Reflections")

func test_wide_rings() -> void:
	assert_eq(Balance.WIDE_RINGS_ENEMIES, 2)
	assert_true(Abilities.RADIUS_TALENTS.has("ripple"), "the game and the tooltip share Ripple's reach")
	assert_eq(str(Abilities.RADIUS_TALENTS["ripple"][0]), "arcane_wide_rings")
	assert_eq(float(Abilities.RADIUS_TALENTS["ripple"][1]), 1.0)
	var p := _player()
	assert_false(ArcaneTankKit.ripple_makes_reflection(2, false))
	assert_true(ArcaneTankKit.ripple_makes_reflection(2, true), "the capstone: two enemies are enough")
	assert_false(ArcaneTankKit.ripple_makes_reflection(1, true))
	assert_true(ArcaneTankKit.ripple_makes_reflection(3, false))
	assert_contains(_desc("arcane_wide_rings"), "1 / 2 m further")
	assert_contains(Talents.capstone_text(_id("arcane_wide_rings")), "2 or more enemies")
	# Ripple's tooltip counts the enemies with the capstone.
	assert_false(str(Abilities.get_resource("ripple").description).contains("RIPPLE_REFLECTION_ENEMIES"))
	assert_contains(Abilities.tooltip("ripple"), "3 or more enemies")

func test_on_the_beat() -> void:
	assert_contains(_desc("arcane_on_the_beat"), "10 / 20 / 30% more damage")
	assert_contains(Talents.capstone_text(_id("arcane_on_the_beat")), "no Reflections")
	assert_eq(str(ArcaneTankKit.ON_THE_BEAT_LABEL), "On the Beat")

func test_head_count() -> void:
	var p := _player()
	assert_eq(ArcaneTankKit.head_count_heal(1000, 2.0, 4), 80, "2% for each of four")
	assert_eq(ArcaneTankKit.head_count_heal(1000, 4.0, 4), 160)
	assert_eq(ArcaneTankKit.head_count_heal(1000, 4.0, 1), 40)
	assert_eq(ArcaneTankKit.head_count_heal(1000, 4.0, 0), 0, "already full: nothing made, nothing healed")
	assert_eq(ArcaneTankKit.head_count_heal(1000, 0.0, 4), 0)
	assert_eq(Details.spell_name("head_count"), "Head Count", "its own line on the meter")
	assert_true(_has_method("res://scripts/player.gd", "_full_set"))
	assert_contains(_desc("arcane_head_count"), "2 / 4% of your maximum health")

# --- Right edge: staying alive ------------------------------------------------------------

func _pd() -> Node:
	var pd: Node = track(PlayerDataScript.new())
	pd._ready()
	pd.level = 50
	return pd

func test_light_feet() -> void:
	var pd := _pd()
	var id := _id("arcane_light_feet")
	pd.inventory[0] = ItemDB.create("sword")
	assert_eq(pd.equip_from_inventory(0), "")
	pd.talents = {}
	var one_none := float(pd._compute_total_stats().get(Stats.DODGE, 0.0))
	pd.talents = {id: 3}
	assert_eq(float(pd._compute_total_stats().get(Stats.DODGE, 0.0)), one_none, "one weapon: nothing")
	pd.inventory[1] = ItemDB.create("dagger")
	assert_eq(pd.equip_from_inventory(1), "")
	assert_true(pd.has_dual_wield())
	pd.talents = {}
	var two_none := float(pd._compute_total_stats().get(Stats.DODGE, 0.0))
	pd.talents = {id: 3}
	assert_true(is_equal_approx(float(pd._compute_total_stats().get(Stats.DODGE, 0.0)), two_none + 3.0), "3% Dodge with a weapon in each hand")
	pd.talents = {id: 1}
	assert_true(is_equal_approx(float(pd._compute_total_stats().get(Stats.DODGE, 0.0)), two_none + 1.0))
	assert_contains(_desc("arcane_light_feet"), "1 / 2 / 3%")

func test_empty_room() -> void:
	var p := _player()
	assert_eq(ArcaneTankKit.empty_room_pct(12.0, 0, true), 12.0)
	assert_eq(ArcaneTankKit.empty_room_pct(12.0, 1, true), 0.0, "one Reflection is enough to switch it off")
	assert_eq(ArcaneTankKit.empty_room_pct(12.0, 0, false), 0.0, "only with a weapon in each hand")
	assert_eq(ArcaneTankKit.empty_room_pct(0.0, 0, true), 0.0)
	assert_contains(_desc("arcane_empty_room"), "4 / 8 / 12% less damage")
	assert_contains(_desc("arcane_empty_room"), "a melee weapon in each hand")

func test_bent_light() -> void:
	var p := _player()
	assert_eq(ArcaneTankKit.bent_light_pct(2.0, 4, "fire"), 8.0, "2% for each of four")
	assert_eq(ArcaneTankKit.bent_light_pct(1.0, 3, "arcane"), 3.0)
	assert_eq(ArcaneTankKit.bent_light_pct(2.0, 4, "physical"), 0.0, "never Physical damage")
	assert_eq(ArcaneTankKit.bent_light_pct(2.0, 0, "frost"), 0.0, "no Reflections: nothing")
	assert_eq(ArcaneTankKit.bent_light_pct(2.0, 9, "frost"), 8.0, "never more than four count")
	assert_eq(ArcaneTankKit.bent_light_pct(0.0, 4, "fire"), 0.0)
	assert_true(_has_method("res://scripts/player.gd", "_reflection_talents_incoming"))
	assert_contains(_desc("arcane_bent_light"), "1 / 2% less non-Physical damage")

func test_understudy() -> void:
	assert_contains(_desc("arcane_understudy"), "2 / 4 sec off its cooldown")
	assert_contains(_desc("arcane_understudy"), Abilities.ability_name("standin"))

func test_loud_exit() -> void:
	assert_contains(_desc("arcane_loud_exit"), Abilities.ability_name("tradeplaces"))
	assert_contains(_desc("arcane_loud_exit"), "shatter")
	assert_true(_has_method("res://scripts/player.gd", "_shatter_burst"), "what a shatter does, without using one up")
	# Trade Places' own text no longer says the opposite.
	assert_false(str(Abilities.get_resource("tradeplaces").description).contains("do not shatter"))

func test_good_likeness() -> void:
	var p := _player()
	assert_eq(ArcaneTankKit.decoy_time(0.0), 3.0)
	assert_eq(ArcaneTankKit.decoy_time(1.0), 4.0)
	assert_eq(ArcaneTankKit.decoy_time(2.0), 5.0)
	assert_contains(_desc("arcane_good_likeness"), "1 / 2 sec longer")
	assert_contains(Talents.capstone_text(_id("arcane_good_likeness")), "no longer needs or uses up a Reflection")
	assert_true(_has_method("res://scripts/player.gd", "decoy_needs_reflection"))
	# Decoy's tooltip counts its time with the talent.
	assert_false(str(Abilities.get_resource("decoy").description).contains("{b:DECOY_TIME}"))
	assert_contains(Abilities.tooltip("decoy"), "for 3 sec")

# --- Rune of the Two-Way Mirror -------------------------------------------------------------

func test_rune_of_the_two_way_mirror() -> void:
	assert_true(Runes.ALL.has("two_way_mirror"))
	var r := Runes.get_resource("two_way_mirror")
	assert_true(r != null)
	assert_eq(str(r.display_name), "Rune of the Two-Way Mirror")
	assert_eq(Runes.rarity("two_way_mirror"), Runes.RARE)
	assert_eq(Runes.max_copies("two_way_mirror"), 1)
	var text := Runes.description("two_way_mirror")
	assert_contains(text, Abilities.ability_name("mirrorsigil"))
	assert_contains(text, "shatter")
	assert_eq(TextFill.leftover(text), "")
	assert_eq(_typed_number(str(r.description)), "", "no typed numbers")
	var p := _player()
	assert_eq(str(ArcaneCasterKit.TWO_WAY_MIRROR_RUNE), "two_way_mirror")
	var shatter := PackedStringArray(SHATTER_TAGS)
	assert_false(ArcaneCasterKit.mirror_echoes(shatter, true, "reflection_shatter"), "without the rune a shatter is not repeated")
	assert_false(ArcaneCasterKit.mirror_echoes(shatter, true, "reflection_shatter", false))
	assert_true(ArcaneCasterKit.mirror_echoes(shatter, true, "reflection_shatter", true), "with it, it is")
	# The rune changes nothing else.
	var spell := PackedStringArray(["Arcane", "Spell"])
	assert_true(ArcaneCasterKit.mirror_echoes(spell, false, "unravel", true))
	assert_false(ArcaneCasterKit.mirror_echoes(spell, true, "mirrorsigil", true), "an echo is never repeated")
	assert_false(ArcaneCasterKit.mirror_echoes(shatter, false, "ripple", true), "nor the tank's other abilities")
	# It repeats at Mirror Sigil's own share (with Polished Glass, or carried).
	assert_eq(ArcaneCasterKit.mirror_pct(0.0, false), Balance.MIRROR_SIGIL_PCT)
	assert_eq(ArcaneCasterKit.echo_amount(1000, ArcaneCasterKit.mirror_pct(0.0, false)), int(round(1000.0 * Balance.MIRROR_SIGIL_PCT / 100.0)))
