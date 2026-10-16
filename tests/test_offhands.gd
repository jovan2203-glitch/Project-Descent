@tool
extends McpTestSuite

# Spellcasting gear: Off Hand items that aren't shields (tome, wand, lantern)
# and one-handed melee weapons with caster stats (ritual dagger, runed blade).

const Items = preload("res://scripts/items.gd")
const Stats = preload("res://scripts/core/stats.gd")
const ItemDB = preload("res://scripts/core/item_db.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")

const OFF_HANDS := ["tome", "wand", "lantern"]
const CASTER_ONE_HANDERS := ["ritual_dagger", "runed_blade"]

var _saved_records := {}

func suite_name() -> String:
	return "offhands"

func setup() -> void:
	_saved_records = ItemDB.records.duplicate(true)

func teardown() -> void:
	ItemDB.records = _saved_records

func test_registered() -> void:
	for id in OFF_HANDS + CASTER_ONE_HANDERS:
		assert_true(Items.ALL.has(id) and Items.PATHS.has(id), id)
		assert_false(Items.get_item(id).is_empty(), id)

func test_off_hands_fit_only_the_off_hand() -> void:
	for id in OFF_HANDS:
		assert_eq(str(Items.get_item(id).get("slot", "")), "Off Hand", id)
		assert_true(PlayerDataScript.fits_slot(id, "Off Hand"), id)
		assert_false(PlayerDataScript.fits_slot(id, "Main Hand"), id)
		assert_false(Items.get_item(id).has("weapon"), "%s is not a weapon" % id)
		assert_eq(Items.item_type(id), id, "item_type names the kind")

func test_caster_one_handers_dual_wield() -> void:
	for id in CASTER_ONE_HANDERS:
		assert_true(Items.is_one_handed_melee(id), id)
		assert_true(PlayerDataScript.fits_slot(id, "Main Hand"), id)
		assert_true(PlayerDataScript.fits_slot(id, "Off Hand"), id)
	assert_eq(Items.item_type("ritual_dagger"), "dagger", "counts as a dagger")
	assert_eq(Items.item_type("runed_blade"), "sword", "counts as a sword")

func test_spellcasting_stats() -> void:
	for id in ["tome", "wand", "ritual_dagger", "runed_blade"]:
		assert_true(float(Items.get_item(id)["stats"].get(Stats.SPELL_POWER, 0.0)) > 0.0, "%s gives Spell Power" % id)
	assert_true(float(Items.get_item("lantern")["stats"].get(Stats.STRENGTH, 0.0)) > 0.0, "the lantern is the Holy tank's off hand")

func test_they_drop() -> void:
	for table in ["zombie", "elite", "boss"]:
		var t: Resource = ResourceLoader.load("res://data/loot/%s.tres" % table, "", ResourceLoader.CACHE_MODE_IGNORE)
		var ids := []
		for e in t.get("pool"):
			ids.append(str(e.get("item_id")))
		for id in OFF_HANDS + CASTER_ONE_HANDERS:
			assert_true(ids.has(id), "%s can drop %s" % [table, id])

func test_what_counts_as_an_off_hand() -> void:
	for id in OFF_HANDS:
		assert_true(Items.is_off_hand_item(id), id)
	for id in ["shield", "dagger", "sword", "ritual_dagger", "staff", "helmet", ""]:
		assert_false(Items.is_off_hand_item(id), "%s is not an off hand" % id)

func test_requires_an_off_hand_text() -> void:
	var r: Resource = load("res://scripts/data/ability_data.gd").new()
	r.requires_off_hand = true
	r.requires_target = false
	assert_true(preload("res://scripts/abilities.gd")._build_tip(r, "test").contains("Requires an off hand"))

func test_rolled_copies_keep_their_slot() -> void:
	var item := ItemDB.create("tome", "", 30, 2)
	assert_eq(str(Items.get_item(item).get("slot", "")), "Off Hand")
	assert_true(Items.tooltip(item).contains("Off Hand"))
