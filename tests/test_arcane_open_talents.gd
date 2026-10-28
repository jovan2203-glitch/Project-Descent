@tool
extends McpTestSuite

# The Arcane book's open talents: themed to the book (time, copies, mirrors) but
# they work with every book's spells and abilities. Quick Study, Two Minds,
# Echo, Mirror Finish, Overtime, Light Touch, Slipstream and Borrowed Time; and
# two more for one ability each, Keep Moving (Glint) and Full Crowd (Crowd of One).

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const Stats = preload("res://scripts/core/stats.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")
const Details = preload("res://scripts/core/details.gd")
const StatusContainer = preload("res://scripts/core/status_container.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")

# [key, name, ranks, the ability it needs, slot, values]
const TALENTS := [
	["arcane_quick_study", "Quick Study", 3, "", "arcane_r1c7", [1.0, 2.0, 3.0]],
	["arcane_two_minds", "Two Minds", 3, "", "arcane_r2c7", [4.0, 8.0, 12.0]],
	["arcane_echo", "Echo", 3, "", "arcane_r3c7", [2.0, 4.0, 6.0]],
	["arcane_mirror_finish", "Mirror Finish", 3, "", "arcane_r4c7", [0.1, 0.2, 0.3]],
	["arcane_overtime", "Overtime", 3, "", "arcane_r5c7", [5.0, 10.0, 15.0]],
	["arcane_light_touch", "Light Touch", 3, "", "arcane_r7c3", [5.0, 10.0, 15.0]],
	["arcane_slipstream", "Slipstream", 2, "", "arcane_r6c7", [10.0, 20.0]],
	["arcane_borrowed_time", "Borrowed Time", 3, "", "arcane_r9c7", [5.0, 10.0, 15.0]],
	["arcane_keep_moving", "Keep Moving", 3, "glint", "arcane_r6c3", [1.5, 2.5, 4.0]],
	["arcane_full_crowd", "Full Crowd", 2, "crowdofone", "arcane_r9c5", [1.0, 2.0]],
]
## The ones any build can take: no ability of the book is needed.
const OPEN := ["arcane_quick_study", "arcane_two_minds", "arcane_echo", "arcane_mirror_finish", "arcane_overtime",
	"arcane_light_touch", "arcane_slipstream", "arcane_borrowed_time"]

func suite_name() -> String:
	return "arcane_open_talents"

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
		var tip := Talents.tooltip(id, 1)
		assert_eq(TextFill.leftover(tip), "", "%s: every placeholder is filled" % row[1])
		assert_false(tip.contains("?"), "%s: %s" % [row[1], tip])
		assert_false(tip.contains("Frost Bolt"), "%s: real damage numbers" % row[1])
		assert_eq(_typed_number(str(t.get("desc", ""))), "", "%s: no typed numbers" % row[1])
		assert_eq(_typed_number(str(t.get("capstone", ""))), "", "%s: no typed numbers in the capstone" % row[1])
	for key in OPEN:
		assert_eq(Talents.required_ability(_id(key)), "", "%s needs no ability: any build can take it" % key)

## The open talents run down the spine of Arcane's ribbons, the plain stats first.
func test_on_the_spine() -> void:
	assert_eq(Talents.columns_of("arcane"), 13, "the ribbon layout")
	for key in ["arcane_quick_study", "arcane_two_minds", "arcane_echo", "arcane_mirror_finish", "arcane_overtime",
			"arcane_slipstream", "arcane_long_step", "arcane_spare_moment", "arcane_borrowed_time"]:
		assert_eq(Talents.group_of(_id(key)), Talents.OPEN_GROUP, "%s is on the spine" % key)
	assert_eq(Talents.tier_of(_id("arcane_quick_study")), 0)
	assert_eq(Talents.tier_of(_id("arcane_two_minds")), 1)
	assert_eq(Talents.max_rank(_id("arcane_borrowed_time")), 3, "three ranks on the spine")

func test_quick_study() -> void:
	var t := Talents.get_talent(_id("arcane_quick_study"))
	assert_eq(float(t.get("stats", {}).get(Stats.HASTE, 0.0)), 1.0, "1% Haste a rank")
	assert_contains(_desc("arcane_quick_study"), "1 / 2 / 3%")

func test_two_minds() -> void:
	assert_eq(PlayerDataScript.two_minds_gain(1000.0, 200.0, 12.0), 120.0, "12% of the higher")
	assert_eq(PlayerDataScript.two_minds_gain(200.0, 1000.0, 4.0), 40.0, "whichever of the two it is")
	assert_eq(PlayerDataScript.two_minds_gain(500.0, 500.0, 8.0), 40.0)
	assert_eq(PlayerDataScript.two_minds_gain(1000.0, 200.0, 0.0), 0.0)
	# On a character: the lower one goes up, the higher one stays.
	var pd: Node = track(PlayerDataScript.new())
	pd.level = 50
	pd.talents = {}
	var before: Dictionary = pd._compute_total_stats()
	var sp := Stats.from_totals(Stats.SPELL_POWER, before)
	var ap := Stats.from_totals(Stats.ATTACK_POWER, before)
	pd.talents = {_id("arcane_two_minds"): 3}
	var after: Dictionary = pd._compute_total_stats()
	var sp2 := Stats.from_totals(Stats.SPELL_POWER, after)
	var ap2 := Stats.from_totals(Stats.ATTACK_POWER, after)
	if sp < ap:
		assert_true(sp2 > sp or ap <= 0.0, "Spell Power is the lower one: it gains")
		assert_true(is_equal_approx(ap2, ap))
	else:
		assert_true(ap2 > ap or sp <= 0.0, "Attack Power is the lower one: it gains")
		assert_true(is_equal_approx(sp2, sp))
	assert_contains(_desc("arcane_two_minds"), "4 / 8 / 12% of the higher")

func test_echo() -> void:
	assert_eq(Balance.ECHO_PCT, 30.0)
	assert_eq(Balance.ECHO_ARCANE_PCT, 15.0)
	assert_eq(Balance.ECHO_ARCANE_CHANCE_MULT, 2)
	var p := _player()
	assert_eq(ArcaneOpenTalentsKit.echo_chance(6.0, false), 6.0)
	assert_eq(ArcaneOpenTalentsKit.echo_chance(6.0, true), 12.0, "Arcane: twice as often")
	assert_eq(ArcaneOpenTalentsKit.echo_chance(2.0, true), 4.0)
	assert_eq(ArcaneOpenTalentsKit.echo_share(false), 30.0)
	assert_eq(ArcaneOpenTalentsKit.echo_share(true), 15.0, "... for half as much")
	assert_eq(ArcaneCasterKit.echo_amount(1000, ArcaneOpenTalentsKit.echo_share(false)), 300)
	assert_eq(ArcaneCasterKit.echo_amount(1000, ArcaneOpenTalentsKit.echo_share(true)), 150)
	# What it repeats: the hits of spells and abilities, of any book.
	assert_true(ArcaneOpenTalentsKit.echoes(PackedStringArray(["Fire", "Spell"]), false, false, true))
	assert_true(ArcaneOpenTalentsKit.echoes(PackedStringArray(["Ability", "Lightning", "Melee"]), false, false, true))
	assert_true(ArcaneOpenTalentsKit.echoes(PackedStringArray(["Arcane", "Spell"]), false, false, true))
	assert_false(ArcaneOpenTalentsKit.echoes(PackedStringArray(["Fire", "Spell"]), true, false, true), "never a proc: no echo of an echo")
	assert_false(ArcaneOpenTalentsKit.echoes(PackedStringArray(["Fire", "Spell"]), false, true, true), "never damage over time")
	assert_false(ArcaneOpenTalentsKit.echoes(PackedStringArray(["Fire", "Spell"]), false, false, false), "only spells and abilities you know by name")
	assert_false(ArcaneOpenTalentsKit.echoes(PackedStringArray(["AutoAttack"]), false, false, true), "not auto-attacks")
	assert_eq(Details.line_name("echo"), "Echo", "its own line on the meter")
	# Mirror Sigil does not repeat an echo.
	assert_false(ArcaneCasterKit.mirror_echoes(PackedStringArray(["Arcane", "Spell"]), true, "echo"))
	var text := _desc("arcane_echo")
	assert_contains(text, "2 / 4 / 6% chance")
	assert_contains(text, "30% of the damage")
	assert_contains(text, "2 times as high")
	assert_contains(text, "15% of the damage")

func test_mirror_finish() -> void:
	assert_eq(Details.line_name("mirror_finish"), "Mirror Finish", "its own line on the meter")
	assert_true(_has_method("res://scripts/player.gd", "_mirror_finish"))
	var text := _desc("arcane_mirror_finish")
	assert_contains(text, "dodge, parry or block")
	assert_contains(text, "Arcane damage")
	# Real damage, three ranks of it, each bigger than the last.
	# (A hit's damage is quoted as a range, e.g. "5-6".)
	var m := RegEx.create_from_string("takes ([0-9]+)[0-9-]* / ([0-9]+)[0-9-]* / ([0-9]+)[0-9-]* Arcane damage").search(text)
	assert_true(m != null, text)
	if m != null:
		assert_true(int(m.get_string(1)) > 0)
		assert_true(int(m.get_string(2)) > int(m.get_string(1)))
		assert_true(int(m.get_string(3)) > int(m.get_string(2)))

func test_overtime() -> void:
	var p := _player()
	assert_eq(ArcaneOpenTalentsKit.overtime_mult(0.0), 1.0)
	assert_true(is_equal_approx(ArcaneOpenTalentsKit.overtime_mult(15.0), 1.15))
	assert_true(_has_method("res://scripts/player.gd", "self_buff_time_mult"), "StatusContainer asks the player")
	assert_contains(_desc("arcane_overtime"), "5 / 10 / 15% longer")
	# A buff someone puts on themselves lasts longer; one from someone else, or a debuff, does not.
	var me: Node = track(_LongBuffs.new())
	var other: Node = track(_LongBuffs.new())
	var status: Node = StatusContainer.new()
	me.add_child(status)
	var buff := StatusContainer.make_buff("test_overtime_buff", "Test", "armor", 1.0, 10.0, 1, Color.WHITE)
	status.apply(buff, me)
	assert_true(absf(status.remaining_of("test_overtime_buff") - 12.0) < 0.05, "20% longer on myself")
	status.remove("test_overtime_buff")
	status.apply(buff, other)
	assert_true(absf(status.remaining_of("test_overtime_buff") - 10.0) < 0.05, "someone else's buff on me: as it was")
	status.remove("test_overtime_buff")
	var bad := StatusContainer.make_buff("test_overtime_debuff", "Test", "armor", -1.0, 10.0, 1, Color.WHITE)
	bad.is_debuff = true
	status.apply(bad, me)
	assert_true(absf(status.remaining_of("test_overtime_debuff") - 10.0) < 0.05, "a debuff is no buff")

## Someone whose self-buffs last 20% longer.
class _LongBuffs extends Node3D:
	func is_alive() -> bool:
		return true
	func self_buff_time_mult(_res: Resource = null) -> float:
		return 1.2

func test_light_touch() -> void:
	assert_contains(_desc("arcane_light_touch"), "5 / 10 / 15% less threat")

func test_slipstream() -> void:
	assert_eq(Balance.SLIPSTREAM_TIME, 3.0)
	var p := _player()
	var moves: Array = ArcaneOpenTalentsKit.SLIPSTREAM_MOVES
	for id in ["blink", "flicker", "staticstep", "cinderstep", "icyretreat"]:
		assert_true(moves.has(id), "%s counts" % id)
		assert_true(Abilities.PATHS.has(id))
		assert_false(_desc("arcane_slipstream").contains(Abilities.ability_name(id)), "it names no ability of another book")
	assert_contains(_desc("arcane_slipstream"), "10 / 20% faster for 3 sec")
	assert_true(Abilities.tags_of("dartin").has("Movement"), "and any movement ability counts (code: the Movement tag)")

func test_borrowed_time() -> void:
	assert_eq(Balance.BORROWED_TIME_COOLDOWN, 20.0)
	var p := _player()
	assert_true(ArcaneOpenTalentsKit.borrowed_time_counts(20.0))
	assert_true(ArcaneOpenTalentsKit.borrowed_time_counts(90.0))
	assert_false(ArcaneOpenTalentsKit.borrowed_time_counts(19.9))
	assert_false(ArcaneOpenTalentsKit.borrowed_time_counts(0.0))
	# Abilities of every book count, by their cooldown alone.
	var long := 0
	var books := {}
	for id in Abilities.ALL:
		var r := Abilities.get_resource(id)
		if r != null and ArcaneOpenTalentsKit.borrowed_time_counts(float(r.cooldown)):
			long += 1
			books[Abilities.category_of(id)] = true
	assert_true(long >= 10, "plenty of abilities have a long cooldown")
	assert_true(books.size() >= 4, "in every kind of book")
	var text := _desc("arcane_borrowed_time")
	assert_contains(text, "cooldown of 20 sec or more")
	assert_contains(text, "5 / 10 / 15% more damage")

func test_keep_moving() -> void:
	assert_eq(Balance.KEEP_MOVING_CASTS, 2)
	var p := _player()
	assert_eq(ArcaneOpenTalentsKit.glint_time(0.0), Balance.GLINT_TIME)
	assert_eq(ArcaneOpenTalentsKit.glint_time(4.0), Balance.GLINT_TIME + 4.0)
	assert_contains(_desc("arcane_keep_moving"), "1.5 / 2.5 / 4 sec longer")
	assert_contains(Talents.capstone_text(_id("arcane_keep_moving")), "2 casts on the move")
	assert_false(str(Abilities.get_resource("glint").description).contains("{b:GLINT_TIME}"), "Glint's tooltip counts the talent")
	assert_contains(Abilities.tooltip("glint"), "within 4 sec")

func test_full_crowd() -> void:
	assert_contains(_desc("arcane_full_crowd"), "creates 1 / 2 Reflections")
	assert_contains(_desc("arcane_full_crowd"), Abilities.ability_name("crowdofone"))
