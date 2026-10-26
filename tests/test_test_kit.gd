@tool
extends McpTestSuite

# /testkit <spec> (scripts/core/test_kit.gd): level 50, the spec's abilities on the
# bars, Epic gear with the spec's stats and weapons all its abilities can use,
# every talent point spent legally for it. No runes. And /bug.

const TestKit = preload("res://scripts/core/test_kit.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")
const Abilities = preload("res://scripts/abilities.gd")
const Talents = preload("res://scripts/talents.gd")
const Items = preload("res://scripts/items.gd")
const ItemDB = preload("res://scripts/core/item_db.gd")

var _saved := {}

func suite_name() -> String:
	return "test_kit"

func setup() -> void:
	_saved = ItemDB.records.duplicate(true)

func teardown() -> void:
	ItemDB.records = _saved

func _pd() -> Node:
	var pd: Node = track(PlayerDataScript.new())
	pd.learned_abilities.clear()
	return pd

func test_finds_specs_by_rough_name() -> void:
	assert_eq(TestKit.find_spec("venomstring"), "Venomstring")
	assert_eq(TestKit.find_spec("venomstrike"), "Venomstring", "a close spelling still finds it")
	assert_eq(TestKit.find_spec("Pitch and Cinder"), "Pitch and Cinder")
	assert_eq(TestKit.find_spec("pitchandcinder"), "Pitch and Cinder")
	assert_eq(TestKit.find_spec("zzzz"), "")

func test_every_spec_gets_weapons_its_abilities_can_use() -> void:
	for spec in TestKit.specs():
		var w := TestKit.weapons_for(spec)
		assert_false(w.is_empty(), "%s gets weapons" % spec)
		if w.is_empty():
			continue
		for id in TestKit.abilities_of(spec):
			assert_true(TestKit.usable_with(id, str(w[0]), str(w[1])), "%s: %s works with %s / %s" % [spec, id, w[0], w[1]])

func test_every_spec_kit() -> void:
	for spec in TestKit.specs():
		var pd := _pd()
		var lines: Array = TestKit.apply(pd, spec)
		assert_true(str(lines[0]).begins_with("Test kit: %s" % spec), str(lines[0]))
		assert_eq(pd.level, pd.MAX_LEVEL)
		for b in TestKit.bar_buttons(TestKit.abilities_of(spec)):
			assert_true(pd.action_bar.has(b), "%s: %s is on a bar" % [spec, b])
		for id in TestKit.abilities_of(spec):
			assert_true(pd.has_ability(id), "%s: %s learned" % [spec, id])
		assert_eq(pd.talent_points_left(), 0, "%s: every talent point spent" % spec)
		assert_true(PlayerDataScript.talents_valid(pd.talents), "%s: a legal talent set" % spec)
		assert_true(pd.equipment.size() >= 13, "%s: a full set of gear" % spec)
		var main: String = TestKit.profile(spec)["stats"][0]
		var totals: Dictionary = pd.total_stats()
		assert_true(float(totals.get(main, 0.0)) > 500.0, "%s: plenty of %s (%s)" % [spec, main, totals.get(main, 0)])
		for slot in pd.equipment:
			assert_true(Items.runes_of(str(pd.equipment[slot])).is_empty(), "no runes")
			assert_eq(int(ItemDB.get_record(str(pd.equipment[slot])).get("rarity", 0)), 3, "Epic")
		pd.free()

func test_ribbon_spec_talents_go_to_the_spec() -> void:
	var pd := _pd()
	TestKit.apply(pd, "Steady Flame")
	assert_eq(pd.group_points("fire", "Steady Flame"), Talents.in_group("fire", "Steady Flame").reduce(
		func(n, id): return n + int(pd.talents.get(id, 0)), 0))
	assert_true(pd.group_points("fire", "Steady Flame") >= 40, "most points in the spec (%d)" % pd.group_points("fire", "Steady Flame"))
	pd.free()
	pd = _pd()
	TestKit.apply(pd, "Live Current")
	assert_true(pd.group_points("lightning", "Live Current") >= 40, "Lightning is on ribbons too (%d)" % pd.group_points("lightning", "Live Current"))
	pd.free()
	pd = _pd()
	TestKit.apply(pd, "Clockwork")
	assert_true(pd.group_points("arcane", "Clockwork") >= 40, "and Arcane (%d)" % pd.group_points("arcane", "Clockwork"))
	pd.free()

func test_commands_listed() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/core/debug_commands.gd")
	assert_contains(src, '"testkit":')
	assert_contains(src, '"bug":')
	assert_contains(src, 'cmd.begins_with("testkit_")', "/testkit_venomstring works too")
	assert_contains(src, 'gl.warn("bug", "BUG REPORT from')
