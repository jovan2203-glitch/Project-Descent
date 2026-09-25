@tool
extends McpTestSuite

# Automated rule tests (run from the Godot AI plugin's test runner).
# They cover the pure game rules so later changes can't silently break them:
# damage maths, talents, progression, item instances, rune transfer, equip
# rules and loot tables.

const CombatSystem = preload("res://scripts/core/combat_system.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")
const Items = preload("res://scripts/items.gd")
const ItemDB = preload("res://scripts/core/item_db.gd")
const Talents = preload("res://scripts/talents.gd")
const LootTable = preload("res://scripts/data/loot_table_data.gd")
const LootEntry = preload("res://scripts/data/loot_entry_data.gd")

var _saved_records := {}

func suite_name() -> String:
	return "game_rules"

func setup() -> void:
	_saved_records = ItemDB.records.duplicate(true)

func teardown() -> void:
	ItemDB.records = _saved_records

func _pd() -> Node:
	var pd: Node = track(PlayerDataScript.new())
	pd._ready()
	return pd

# --- Damage maths -------------------------------------------------------------------

func test_damage_adds_bonus() -> void:
	var r := CombatSystem.compute_damage(2, 1, 0.0, 0.0, 0.0, 50.0, 50.0)
	assert_eq(r["amount"], 3)
	assert_false(r["crit"])
	assert_false(r["blocked"])

func test_damage_crit_doubles() -> void:
	var r := CombatSystem.compute_damage(3, 0, 25.0, 0.0, 0.0, 10.0, 99.0)
	assert_true(r["crit"], "roll 10 < 25% should crit")
	assert_eq(r["amount"], 6)

func test_damage_no_crit_above_chance() -> void:
	var r := CombatSystem.compute_damage(3, 0, 25.0, 0.0, 0.0, 30.0, 99.0)
	assert_false(r["crit"])
	assert_eq(r["amount"], 3)

func test_damage_block_uses_armor_and_caps_at_60() -> void:
	# 20 armor = 100% raw, capped at 60%.
	assert_true(CombatSystem.compute_damage(5, 0, 0.0, 20.0, 0.0, 99.0, 59.0)["blocked"])
	assert_false(CombatSystem.compute_damage(5, 0, 0.0, 20.0, 0.0, 99.0, 61.0)["blocked"])
	assert_eq(CombatSystem.compute_damage(5, 0, 0.0, 2.0, 0.0, 99.0, 5.0)["amount"], 0, "blocked hit deals 0")

func test_damage_resist_halves_but_min_one() -> void:
	assert_eq(CombatSystem.compute_damage(4, 0, 0.0, 0.0, 50.0, 99.0, 99.0)["amount"], 2)
	assert_eq(CombatSystem.compute_damage(1, 0, 0.0, 0.0, 90.0, 99.0, 99.0)["amount"], 1)

func test_damage_never_negative() -> void:
	assert_eq(CombatSystem.compute_damage(1, -5, 0.0, 0.0, 0.0, 99.0, 99.0)["amount"], 0)

# --- Talents & progression -------------------------------------------------------------

func test_talent_points_scale_with_level() -> void:
	assert_eq(Talents.points_for_level(1), 3)
	assert_eq(Talents.points_for_level(5), 7)

func test_every_category_has_a_full_tree() -> void:
	const Categories = preload("res://scripts/categories.gd")
	for cat in Categories.ORDER:
		for r in Talents.ROWS:
			assert_gt(Talents.in_row(cat, r).size(), 0, "%s row %d has talents" % [cat, r + 1])
		for id in Talents.in_tree(cat):
			assert_eq(Talents.category_of(id), cat)

func test_talent_row_gating() -> void:
	var pd := _pd()
	pd.level = 10
	assert_ne(pd.can_invest("warrior_iron_skin"), "", "row 2 locked with 0 points in row 1")
	for i in 3:
		assert_eq(pd.invest_talent("warrior_toughness"), "")
	assert_eq(pd.can_invest("warrior_iron_skin"), "", "row 2 unlocks after 3 points")
	assert_ne(pd.invest_talent("warrior_toughness"), "", "toughness max rank is 3")

func test_talent_rows_unlock_across_all_trees() -> void:
	var pd := _pd()
	pd.level = 10
	pd.invest_talent("fire_kindling")
	pd.invest_talent("frost_winters_chill")
	assert_ne(pd.can_invest("rogue_evasion"), "", "2 points in row 1 is not enough")
	pd.invest_talent("nature_thorns")
	assert_eq(pd.can_invest("rogue_evasion"), "", "3 points spread over trees open row 2 everywhere")
	assert_eq(pd.tree_points("fire"), 1)

func test_talent_budget_limited_by_level() -> void:
	var pd := _pd()
	pd.level = 1
	assert_eq(pd.invest_talent("warrior_toughness"), "")
	assert_eq(pd.invest_talent("rogue_keen_edge"), "")
	assert_eq(pd.invest_talent("rogue_keen_edge"), "")
	assert_eq(pd.talent_points_left(), 0)
	assert_ne(pd.invest_talent("ranger_fleet_foot"), "", "no points left at level 1")

func test_talent_refund_protects_lower_tiers() -> void:
	var pd := _pd()
	pd.level = 10
	for i in 3:
		pd.invest_talent("warrior_toughness")
	pd.invest_talent("frost_shatter")
	assert_ne(pd.can_refund("warrior_toughness"), "", "row 2 depends on 3 row-1 points")
	assert_eq(pd.can_refund("frost_shatter"), "")

func test_validate_talents_refunds_when_over_budget() -> void:
	var pd := _pd()
	pd.level = 1
	pd.talents = {"warrior_toughness": 3, "rogue_keen_edge": 3}
	assert_false(pd.validate_talents())
	assert_true(pd.talents.is_empty())

func test_xp_levels_up() -> void:
	var pd := _pd()
	assert_eq(pd.level, 1)
	pd.add_xp(PlayerDataScript.xp_to_next(1))
	assert_eq(pd.level, 2)
	assert_eq(pd.xp, 0)
	pd.add_xp(PlayerDataScript.xp_to_next(2) + 5)
	assert_eq(pd.level, 3)
	assert_eq(pd.xp, 5)

func test_level_stats_raise_max_health() -> void:
	var pd := _pd()
	pd.level = 5
	assert_eq(float(pd.total_stats().get("max_health", 0.0)), 4.0)

# --- Item instances ---------------------------------------------------------------------

func test_item_ids_are_unique() -> void:
	var a := ItemDB.create("sword")
	var b := ItemDB.create("sword")
	assert_ne(a, b)
	assert_true(ItemDB.is_instance_id(a))
	assert_eq(Items.base_id(a), "sword")

func test_legacy_string_converts() -> void:
	var id := ItemDB.from_legacy("sword|frost")
	assert_eq(Items.base_id(id), "sword")
	assert_eq(Items.rune_of(id), "frost")

func test_rolled_stats_merge_into_item() -> void:
	var id := ItemDB.create("helmet", "", 1, 1, {"damage": 2.0})
	var d := Items.get_item(id)
	assert_eq(float(d["stats"].get("damage", 0.0)), 2.0)
	assert_eq(d["rarity_name"], "Uncommon")

func test_item_records_roundtrip() -> void:
	var id := ItemDB.create("bow", "fury", 3, 2, {"armor": 1.0})
	var saved := ItemDB.serialize([id])
	ItemDB.clear()
	assert_false(ItemDB.has(id))
	ItemDB.load_records(saved)
	assert_true(ItemDB.has(id))
	assert_eq(Items.rune_of(id), "fury")
	assert_eq(int(ItemDB.get_record(id)["ilvl"]), 3)

# --- Rune transfer -------------------------------------------------------------------

func test_rune_transfer_moves_rune_and_destroys_source() -> void:
	var pd := _pd()
	var src := ItemDB.create("sword", "frost")
	var tgt := ItemDB.create("helmet")
	pd.bank[0] = src
	pd.bank[1] = tgt
	var err: String = pd.transfer_rune({"where": "bank", "index": 0}, {"where": "bank", "index": 1})
	assert_eq(err, "")
	assert_eq(pd.bank[0], "", "source removed")
	assert_false(ItemDB.has(src), "source record destroyed")
	assert_eq(Items.rune_of(pd.bank[1]), "frost")
	assert_true(pd.known_runes.has("frost"), "rune learned")

func test_rune_transfer_needs_runed_source() -> void:
	var pd := _pd()
	pd.bank[0] = ItemDB.create("sword")
	pd.bank[1] = ItemDB.create("helmet")
	assert_ne(pd.transfer_rune({"where": "bank", "index": 0}, {"where": "bank", "index": 1}), "")

func test_extract_learns_rune() -> void:
	var pd := _pd()
	pd.bank[3] = ItemDB.create("bow", "swiftness")
	assert_eq(pd.extract_rune({"where": "bank", "index": 3}), "")
	assert_eq(pd.bank[3], "")
	assert_true(pd.known_runes.has("swiftness"))

# --- Equip rules -----------------------------------------------------------------------

func test_equip_goes_to_item_slot_and_swaps() -> void:
	var pd := _pd()
	var h1 := ItemDB.create("helmet")
	var h2 := ItemDB.create("helmet")
	pd.inventory[0] = h1
	assert_eq(pd.equip_from_inventory(0), "")
	assert_eq(pd.equipment.get("Head", ""), h1)
	assert_eq(pd.inventory[0], "")
	pd.inventory[0] = h2
	assert_eq(pd.equip_from_inventory(0), "")
	assert_eq(pd.equipment.get("Head", ""), h2)
	assert_eq(pd.inventory[0], h1, "old helmet swapped into the bag")

func test_equip_empty_slot_errors() -> void:
	var pd := _pd()
	assert_ne(pd.equip_from_inventory(5), "")

func test_unequip_needs_bag_space() -> void:
	var pd := _pd()
	pd.equipment["Head"] = ItemDB.create("helmet")
	for i in pd.INVENTORY_SIZE:
		pd.inventory[i] = ItemDB.create("sword")
	assert_ne(pd.unequip("Head"), "", "bag full")
	pd.inventory[4] = ""
	assert_eq(pd.unequip("Head"), "")
	assert_false(pd.equipment.has("Head"))

func test_add_item_converts_base_id() -> void:
	var pd := _pd()
	assert_true(pd.add_item("sword"))
	assert_true(ItemDB.is_instance_id(pd.inventory[0]))

# --- Roguelike: level requirements, death, level lock ------------------------------------

func test_required_level_is_item_level() -> void:
	assert_eq(Items.required_level(ItemDB.create("sword", "", 7)), 7)
	assert_eq(Items.required_level("sword"), 1, "base ids have no requirement")

func test_higher_item_level_has_higher_stats() -> void:
	var lo := Items.get_item(ItemDB.create("chestplate", "", 1))
	var hi := Items.get_item(ItemDB.create("chestplate", "", 9))
	for s in lo["stats"]:
		assert_true(float(hi["stats"][s]) >= float(lo["stats"][s]), "%s grows with item level" % s)

func test_cannot_equip_above_level() -> void:
	var pd := _pd()
	pd.level = 3
	pd.inventory[0] = ItemDB.create("helmet", "", 5)
	assert_ne(pd.equip_from_inventory(0), "", "needs level 5")
	pd.level = 5
	assert_eq(pd.equip_from_inventory(0), "")

func test_death_resets_level_gear_and_abilities() -> void:
	var pd := _pd()
	pd.level = 12
	pd.equipment["Head"] = ItemDB.create("helmet", "frost", 3)
	pd.inventory[0] = ItemDB.create("sword")
	pd.bank[0] = ItemDB.create("bow")
	pd.learn_ability("icelance")
	pd.add_boon("strength", 1.0)
	var d: Dictionary = pd.apply_death()
	assert_eq(pd.level, 1)
	assert_true(pd.equipment.is_empty(), "equipped gear lost")
	assert_eq(pd.inventory[0], "", "bag lost")
	assert_ne(pd.bank[0], "", "bank kept")
	assert_true(pd.known_runes.has("frost"), "rune on lost gear is learned")
	assert_true(d["runes_learned"].has("frost"))
	assert_false(pd.has_ability("icelance"), "drafted abilities lost")
	assert_false(pd.action_bar.has("icelance"))
	assert_true(pd.has_ability("frostbolt"), "base kit stays")
	assert_true(pd.draft_boons.is_empty())

func test_level_lock_keeps_level_and_legal_gear() -> void:
	var pd := _pd()
	pd.level = 24
	assert_ne(pd.set_level_lock(30), "", "can't lock above your level")
	assert_ne(pd.set_level_lock(15), "", "multiples of 10 only")
	assert_eq(pd.set_level_lock(20), "")
	var keep := ItemDB.create("helmet", "", 18)
	var lose := ItemDB.create("chestplate", "", 23)
	pd.equipment["Head"] = keep
	pd.equipment["Chest"] = lose
	pd.apply_death()
	assert_eq(pd.level, 20)
	assert_eq(pd.equipment.get("Head", ""), keep, "wearable at 20: kept")
	assert_false(pd.equipment.has("Chest"), "needs 23: lost")
	assert_eq(Array(pd.pending_drafts), [2, 4, 6, 8, 10, 12, 14, 16, 18, 20], "drafts re-offered up to the lock")

func test_skill_cards_must_be_owned() -> void:
	var pd := _pd()
	assert_ne(pd.toggle_card("blink"), "", "not found yet")
	assert_true(pd.grant_card("blink"))
	assert_false(pd.grant_card("blink"), "no duplicates")
	assert_eq(pd.toggle_card("blink"), "")
	pd.apply_death()
	assert_true(pd.owned_cards.has("blink") and pd.equipped_cards.has("blink"), "cards survive death")

# --- Loot tables -------------------------------------------------------------------------

func _entry(id: String, chance: float, weight: float = 1.0) -> Resource:
	var e: Resource = LootEntry.new()
	e.item_id = StringName(id)
	e.chance = chance
	e.weight = weight
	return e

func test_loot_guaranteed_and_zero_chance() -> void:
	var t: Resource = LootTable.new()
	var g: Array[Resource] = [_entry("sword", 1.0)]
	var c: Array[Resource] = [_entry("bow", 0.0)]
	t.guaranteed = g
	t.chance_drops = c
	t.rune_chance = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 20:
		var drops: Array = t.roll(1, rng)
		assert_eq(drops.size(), 1)
		assert_eq(Items.base_id(drops[0]), "sword")

func test_loot_pool_nothing_weight() -> void:
	var t: Resource = LootTable.new()
	var p: Array[Resource] = [_entry("helmet", 1.0, 0.0)]
	t.pool = p
	t.pool_rolls = 5
	t.nothing_weight = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	assert_eq(t.roll(1, rng).size(), 0, "zero-weight entry never drops")

func test_loot_rarity_weights() -> void:
	var t: Resource = LootTable.new()
	t.rarity_weights = PackedFloat32Array([0.0, 0.0, 0.0, 1.0])
	var rng := RandomNumberGenerator.new()
	assert_eq(t.roll_rarity(rng), 3, "only Epic has weight")

func test_zombie_loot_file_loads() -> void:
	var t: Resource = load("res://data/loot/zombie.tres")
	assert_true(t != null and t.has_method("roll"), "zombie loot table loads")
	assert_eq(t.chance_drops.size(), 4)
