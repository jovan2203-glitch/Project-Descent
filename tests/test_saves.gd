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
	assert_true(SaveSystemScript.VERSION >= 9)
	var cfg := ConfigFile.new()
	cfg.set_value("talents", "ranks", {"nature_r1c3": 2, "nature_r2c7": 1, "nature_r3c2": 2, "nature_r10c6": 1, "frost_r1c1": 2})
	_ss()._migrate_8_to_9(cfg)
	var ranks: Dictionary = cfg.get_value("talents", "ranks", {})
	assert_eq(int(ranks.get("nature_r1c3", 0)), 2, "Running Herd keeps its points")
	assert_eq(int(ranks.get("nature_r2c7", 0)), 1, "Lingering Venom keeps its points")
	assert_false(ranks.has("nature_r3c2"), "an old empty slot is refunded")
	assert_false(ranks.has("nature_r10c6"), "an old empty slot is refunded")
	assert_eq(int(ranks.get("frost_r1c1", 0)), 2, "other books keep their points")

func test_v10_refunds_the_old_empty_martial_slots() -> void:
	assert_true(SaveSystemScript.VERSION >= 10)
	var cfg := ConfigFile.new()
	cfg.set_value("talents", "ranks", {"martial_r1c2": 2, "martial_r10c4": 1, "nature_r1c3": 2})
	_ss()._migrate_9_to_10(cfg)
	var ranks: Dictionary = cfg.get_value("talents", "ranks", {})
	assert_false(ranks.has("martial_r1c2"), "an old empty Martial slot is refunded")
	assert_false(ranks.has("martial_r10c4"), "an old empty Martial slot is refunded")
	assert_eq(int(ranks.get("nature_r1c3", 0)), 2, "other books keep their points")

func test_v11_refunds_the_folded_talents() -> void:
	assert_true(SaveSystemScript.VERSION >= 11)
	var cfg := ConfigFile.new()
	cfg.set_value("talents", "ranks", {"fire_r9c6": 2, "holy_r6c7": 1, "fire_r1c1": 3})
	_ss()._migrate_10_to_11(cfg)
	var ranks: Dictionary = cfg.get_value("talents", "ranks", {})
	assert_false(ranks.has("fire_r9c6"), "Furnace Heart's points are refunded")
	assert_false(ranks.has("holy_r6c7"), "Last Rites' points are refunded")
	assert_eq(int(ranks.get("fire_r1c1", 0)), 3, "other talents keep their points")
	assert_eq(Talents.FOLDED_INTO_ABILITIES.size(), 13)
	for id in Talents.FOLDED_INTO_ABILITIES:
		if id.begins_with("martial_") or id.begins_with("fire_") or id.begins_with("frost_") or id.begins_with("lightning_") or id.begins_with("arcane_") or id.begins_with("shadow_") or id.begins_with("nature_") or id.begins_with("holy_"):   # books on ribbons (Talents.GROUPS): their slots hold new talents
			continue
		assert_true(bool(Talents.get_talent(id).get("placeholder", false)), "%s is an empty slot now" % id)

func test_changed_talent_trees_refund_every_point() -> void:
	var id := Talents.id_for_key("frost_cold_fury")
	var cfg := ConfigFile.new()
	cfg.set_value("talents", "ranks", {id: 2})
	assert_eq(_ss()._loaded_talents(cfg), {}, "saved before talent trees had a version: all refunded")
	cfg.set_value("talents", "tree_version", Talents.TREE_VERSION - 1)
	assert_eq(_ss()._loaded_talents(cfg), {}, "saved under older trees: all refunded")
	cfg.set_value("talents", "tree_version", Talents.TREE_VERSION)
	assert_eq(int(_ss()._loaded_talents(cfg).get(id, 0)), 2, "same trees: points stay")

func test_a_talent_for_one_ability_needs_it_learned() -> void:
	var id := Talents.id_for_key("nature_running_herd")
	var knows_fawn := func(a: String) -> bool: return a == "fawn"
	var knows_none := func(_a: String) -> bool: return false
	assert_eq(int(_ss()._valid_talents({id: 2}, knows_fawn).get(id, 0)), 2, "kept with Fawn learned")
	assert_false(_ss()._valid_talents({id: 2}, knows_none).has(id), "dropped without it")

