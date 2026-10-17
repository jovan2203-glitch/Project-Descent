@tool
extends McpTestSuite

# Saves stay safe as content changes: version steps, and talents that only work
# with one ability (or empty slots) never keep points they shouldn't.

const SaveSystemScript = preload("res://scripts/save_system.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")
const Talents = preload("res://scripts/talents.gd")

func suite_name() -> String:
	return "saves"

func _ss() -> Node:
	return track(SaveSystemScript.new())

func test_v8_refunds_the_old_empty_nature_slots() -> void:
	assert_true(SaveSystemScript.VERSION >= 8)
	var cfg := ConfigFile.new()
	cfg.set_value("talents", "ranks", {"nature_r1c3": 2, "nature_r1c5": 1, "nature_r2c4": 3, "nature_r2c7": 1, "frost_r1c1": 2})
	_ss()._migrate_7_to_8(cfg)
	var ranks: Dictionary = cfg.get_value("talents", "ranks", {})
	for id in SaveSystemScript.NATURE_FILLED_SLOTS:
		assert_false(ranks.has(id), "%s refunded" % id)
	assert_eq(int(ranks.get("frost_r1c1", 0)), 2, "other talents keep their points")

func test_v9_refunds_every_other_old_nature_slot() -> void:
	assert_eq(SaveSystemScript.VERSION, 9)
	var cfg := ConfigFile.new()
	cfg.set_value("talents", "ranks", {"nature_r1c3": 2, "nature_r2c7": 1, "nature_r3c2": 2, "nature_r10c6": 1, "frost_r1c1": 2})
	_ss()._migrate_8_to_9(cfg)
	var ranks: Dictionary = cfg.get_value("talents", "ranks", {})
	assert_eq(int(ranks.get("nature_r1c3", 0)), 2, "Running Herd keeps its points")
	assert_eq(int(ranks.get("nature_r2c7", 0)), 1, "Lingering Venom keeps its points")
	assert_false(ranks.has("nature_r3c2"), "an old empty slot is refunded")
	assert_false(ranks.has("nature_r10c6"), "an old empty slot is refunded")
	assert_eq(int(ranks.get("frost_r1c1", 0)), 2, "other books keep their points")

func test_a_talent_for_one_ability_needs_it_learned() -> void:
	var id := Talents.id_for_key("nature_running_herd")
	var knows_fawn := func(a: String) -> bool: return a == "fawn"
	var knows_none := func(_a: String) -> bool: return false
	assert_eq(int(_ss()._valid_talents({id: 2}, knows_fawn).get(id, 0)), 2, "kept with Fawn learned")
	assert_false(_ss()._valid_talents({id: 2}, knows_none).has(id), "dropped without it")

