@tool
extends McpTestSuite

# The Fire and Lightning books' open talents: themed to their book, but they
# work with every book's spells and abilities. Fire: Feed the Flames, Last
# Ember, Tempered. Lightning: Change of Pace, Spillover, Dig In.

const Balance = preload("res://scripts/balance.gd")
const Stats = preload("res://scripts/core/stats.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")
const Details = preload("res://scripts/core/details.gd")
const StatusContainer = preload("res://scripts/core/status_container.gd")

# [key, name, ranks, slot, values]
const TALENTS := [
	["fire_feed_the_flames", "Feed the Flames", 3, "fire_r1c4", [2.0, 4.0, 6.0]],
	["fire_last_ember", "Last Ember", 2, "fire_r5c1", [50.0, 100.0]],
	["fire_tempered", "Tempered", 3, "fire_r5c7", [2.0, 4.0, 6.0]],
	["lightning_change_of_pace", "Change of Pace", 3, "lightning_r1c4", [1.0, 2.0, 3.0]],
	["lightning_spillover", "Spillover", 3, "lightning_r3c4", [5.0, 10.0, 15.0]],
	["lightning_dig_in", "Dig In", 3, "lightning_r4c4", [2.0, 4.0, 6.0]],
]

func suite_name() -> String:
	return "open_talents"

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

## Someone who can carry effects.
class _Body extends Node3D:
	func is_alive() -> bool:
		return true

func _carrier() -> Array:
	var body: Node = track(_Body.new())
	var status: Node = StatusContainer.new()
	body.add_child(status)
	return [body, status]

func test_they_are_in_the_tree() -> void:
	for row in TALENTS:
		var id := _id(str(row[0]))
		assert_eq(id, str(row[3]), "%s sits in its slot" % row[1])
		var t := Talents.get_talent(id)
		assert_eq(str(t.get("name", "")), str(row[1]))
		assert_eq(Talents.max_rank(id), int(row[2]))
		assert_eq(t.get("values", []), row[4], "%s: its numbers" % row[1])
		assert_eq(Talents.required_ability(id), "", "%s needs no ability: any build can take it" % row[1])
		assert_true(bool(t.get("implemented", false)), "%s does something" % row[1])
		assert_true(TalentIcons.has_icon(id), "%s has an icon" % row[1])
		var tip := Talents.tooltip(id, 1)
		assert_eq(TextFill.leftover(tip), "", "%s: every placeholder is filled" % row[1])
		assert_false(tip.contains("?"), "%s: %s" % [row[1], tip])
		assert_eq(_typed_number(str(t.get("desc", ""))), "", "%s: no typed numbers" % row[1])
		# None of them names a school: they key off what you do, not what you cast.
		for school in ["Fire", "Frost", "Lightning", "Arcane"]:
			assert_false(str(t.get("desc", "")).contains(school), "%s does not name %s" % [row[1], school])
		# A slot a talent once left (its saved points are moved on every load) is never reused.
		assert_false(Talents.MOVED.has(id), "%s is not a slot another talent moved out of" % id)

func test_where_they_sit() -> void:
	var fire: Array = Talents.layout("fire")
	assert_eq(fire[0], [0, 2, 3, 4, 6], "the middle of row 1")
	assert_eq(fire[4], [0, 2, 4, 6], "the edges of row 5")
	var lightning: Array = Talents.layout("lightning")
	assert_eq(lightning[0], [1, 2, 3, 4, 5])
	assert_eq(lightning[2], [0, 2, 3, 4, 6])
	assert_eq(lightning[3], [2, 3, 4])
	# Every slot of both books still holds a designed talent, each with an icon.
	for book in ["fire", "lightning"]:
		for id in Talents.in_tree(book):
			assert_false(bool(Talents.get_talent(id).get("placeholder", true)) and not Talents.FOLDED_INTO_ABILITIES.has(id), "%s is designed (or was folded into its ability)" % id)
			assert_true(TalentIcons.has_icon(id) or Talents.FOLDED_INTO_ABILITIES.has(id), "%s has an icon" % id)

# --- Fire -------------------------------------------------------------------------------

func test_feed_the_flames() -> void:
	assert_contains(_desc("fire_feed_the_flames"), "2 / 4 / 6% more damage")
	assert_contains(_desc("fire_feed_the_flames"), "one of your damage over time effects")
	# Which enemies count: any damage over time effect, as long as it is mine.
	var pair := _carrier()
	var status: Node = pair[1]
	var me: Node = track(_Body.new())
	var ally: Node = track(_Body.new())
	assert_false(status.has_dot_from(me))
	var slow := StatusContainer.make_buff("test_open_slow", "Slow", "move_speed", -10.0, 5.0, 1, Color.WHITE)
	status.apply(slow, me)
	assert_false(status.has_dot_from(me), "an effect that deals no damage does not count")
	var burn := StatusContainer.make_buff("test_open_burn", "Burn", "armor", 0.0, 5.0, 1, Color.WHITE)
	burn.stat_modifiers = {}
	burn.tick_damage = 0.1
	burn.tick_interval = 1.0
	status.apply(burn, ally)
	assert_false(status.has_dot_from(me), "an ally's burn is not mine")
	assert_true(status.has_dot_from(ally))
	status.apply(burn, me)
	assert_true(status.has_dot_from(me), "any damage over time effect of mine, whatever its school")
	assert_true(_has_method("res://scripts/player.gd", "_open_talents_modify"))

func test_last_ember() -> void:
	assert_contains(_desc("fire_last_ember"), "50 / 100% of a tick's damage")
	assert_contains(_desc("fire_last_ember"), "runs its full time")
	assert_true(_has_method("res://scripts/player.gd", "dot_last_tick_pct"), "StatusContainer asks the caster")
	var src := FileAccess.get_file_as_string("res://scripts/core/status_container.gd")
	assert_contains(src, "dot_last_tick_pct")
	assert_contains(src, "float(e[\"expires\"]) > 0.0", "an effect ended early does not tick again")

func test_tempered() -> void:
	assert_eq(Balance.TEMPERED_TIME, 8.0)
	assert_eq(Balance.TEMPERED_STACKS, 3)
	assert_contains(_desc("fire_tempered"), "increases your Armor by 2 / 4 / 6% for 8 sec, stacking up to 3 times")
	# Three blocks: three stacks of Armor, each a percentage of all the Armor you have.
	var pair := _carrier()
	var body: Node = pair[0]
	var status: Node = pair[1]
	var buff := StatusContainer.make_buff("test_open_tempered", "Tempered", Stats.ARMOR + Stats.PCT, 6.0,
		Balance.TEMPERED_TIME, Balance.TEMPERED_STACKS, Color.WHITE)
	for i in 5:
		status.apply(buff, body)
	assert_eq(status.stacks_of("test_open_tempered"), 3, "never more than three")
	assert_eq(status.stat_mod(Stats.ARMOR + Stats.PCT), 18.0)
	var raw := func(k): return {Stats.ARMOR: 1000.0, Stats.ARMOR + Stats.PCT: 18.0}.get(k, 0.0)
	assert_true(is_equal_approx(Stats.resolve(Stats.ARMOR, raw), 1180.0), "18% more Armor")
	# Armor no longer blocks, so the Armor a block gives can't make the next block likelier.
	assert_eq(Stats.resolve(Stats.BLOCK, raw), 0.0)
	assert_true(_has_method("res://scripts/player.gd", "_tempered"))

# --- Lightning ---------------------------------------------------------------------------

func test_change_of_pace() -> void:
	assert_eq(Balance.CHANGE_OF_PACE_TIME, 6.0)
	assert_eq(Balance.CHANGE_OF_PACE_STACKS, 3)
	var p := _player()
	assert_eq(FireLightningTalentsKit.change_of_pace_after(0, "", "frostbolt"), 1, "the first thing you use counts")
	assert_eq(FireLightningTalentsKit.change_of_pace_after(1, "frostbolt", "fireball"), 2, "something else: one more")
	assert_eq(FireLightningTalentsKit.change_of_pace_after(2, "fireball", "frostbolt"), 3, "going back to an earlier one is still a change")
	assert_eq(FireLightningTalentsKit.change_of_pace_after(3, "frostbolt", "fireball"), 3, "never more than three")
	assert_eq(FireLightningTalentsKit.change_of_pace_after(3, "fireball", "fireball"), 0, "the same one twice in a row ends it")
	assert_eq(FireLightningTalentsKit.change_of_pace_pct(3.0, 3), 9.0)
	assert_eq(FireLightningTalentsKit.change_of_pace_pct(1.0, 2), 2.0)
	assert_eq(FireLightningTalentsKit.change_of_pace_pct(3.0, 0), 0.0)
	assert_eq(FireLightningTalentsKit.change_of_pace_pct(3.0, 9), 9.0)
	var text := _desc("lightning_change_of_pace")
	assert_contains(text, "1 / 2 / 3% for 6 sec, stacking up to 3 times")
	assert_contains(text, "twice in a row ends it")

func test_spillover() -> void:
	assert_eq(Balance.SPILLOVER_RADIUS, 6.0)
	var p := _player()
	assert_true(FireLightningTalentsKit.spills_over(true, false, false, 100))
	assert_false(FireLightningTalentsKit.spills_over(false, false, false, 100), "only a critical strike")
	assert_false(FireLightningTalentsKit.spills_over(true, true, false, 100), "never a proc: what spilled does not spill on")
	assert_false(FireLightningTalentsKit.spills_over(true, false, true, 100), "never damage over time")
	assert_false(FireLightningTalentsKit.spills_over(true, false, false, 0))
	assert_eq(FireLightningTalentsKit.spillover_amount(1000, 15.0), 150)
	assert_eq(FireLightningTalentsKit.spillover_amount(1000, 5.0), 50)
	assert_eq(FireLightningTalentsKit.spillover_amount(333, 10.0), 33)
	assert_eq(Details.spell_name("spillover"), "Spillover", "its own line on the meter")
	assert_contains(_desc("lightning_spillover"), "5 / 10 / 15% of its damage jumps to another enemy within 6 m")

func test_dig_in() -> void:
	assert_eq(Balance.DIG_IN_TIME, 2.0)
	var p := _player()
	assert_false(FireLightningTalentsKit.dug_in(1.9))
	assert_true(FireLightningTalentsKit.dug_in(2.0))
	assert_true(FireLightningTalentsKit.dig_in_moved(Vector3.INF, Vector3.ZERO), "nowhere stopped yet")
	assert_false(FireLightningTalentsKit.dig_in_moved(Vector3(1, 0, 1), Vector3(1, 0, 1)))
	assert_false(FireLightningTalentsKit.dig_in_moved(Vector3.ZERO, Vector3(Balance.DIG_IN_SLACK * 0.5, 0, 0)), "a shuffle on the spot does not count")
	assert_true(FireLightningTalentsKit.dig_in_moved(Vector3.ZERO, Vector3(0.5, 0, 0)), "a step does")
	assert_true(FireLightningTalentsKit.dig_in_moved(Vector3.ZERO, Vector3(0, 1.0, 0)), "so does a jump")
	assert_contains(_desc("lightning_dig_in"), "stand still for 2 sec, you deal 2 / 4 / 6% more damage until you move")
