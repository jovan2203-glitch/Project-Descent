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
const Stats = preload("res://scripts/core/stats.gd")
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

func test_damage_block_chance_caps_at_60() -> void:
	# 100% block chance is capped at 60%.
	assert_true(CombatSystem.compute_damage(5, 0, 0.0, 100.0, 0.0, 99.0, 59.0)["blocked"])
	assert_false(CombatSystem.compute_damage(5, 0, 0.0, 100.0, 0.0, 99.0, 61.0)["blocked"])
	assert_eq(CombatSystem.compute_damage(5, 0, 0.0, 10.0, 0.0, 99.0, 5.0)["amount"], 0, "blocked hit deals 0")

func test_armor_reduction_scales_with_level() -> void:
	# The same share of level-appropriate Armor takes off as much at any level.
	assert_true(absf(Stats.armor_reduction(40.0, 1) - Stats.armor_reduction(2000.0, 50)) < 0.001)
	assert_eq(Stats.armor_reduction(0.0, 10), 0.0)
	assert_eq(Stats.armor_reduction(1.0e9, 1), 60.0, "capped")

func test_level_50_standard_hit_is_about_500() -> void:
	var hit := Stats.level_hit(50)
	assert_true(hit >= 400.0 and hit <= 550.0, "level 50 standard hit %s" % hit)
	assert_true(Stats.level_hit(1) < Stats.level_hit(10), "grows with level")

func test_damage_resist_halves_but_min_one() -> void:
	assert_eq(CombatSystem.compute_damage(4, 0, 0.0, 0.0, 50.0, 99.0, 99.0)["amount"], 2)
	assert_eq(CombatSystem.compute_damage(1, 0, 0.0, 0.0, 90.0, 99.0, 99.0)["amount"], 1)

func test_damage_never_negative() -> void:
	assert_eq(CombatSystem.compute_damage(1, -5, 0.0, 0.0, 0.0, 99.0, 99.0)["amount"], 0)

# --- Talents & progression -------------------------------------------------------------

func test_talent_points_scale_with_level() -> void:
	assert_eq(Talents.points_for_level(1), 5)
	assert_eq(Talents.points_for_level(2), 7, "+1 for the level, +1 extra on even levels")
	assert_eq(Talents.points_for_level(3), 8)
	assert_eq(Talents.points_for_level(5), 11)
	assert_eq(Talents.points_for_level(49), 77)
	assert_eq(Talents.points_for_level(50), 80, "max level gives a bonus point")

func test_every_category_has_a_full_tree() -> void:
	const Categories = preload("res://scripts/categories.gd")
	var shapes := {}
	for cat in preload("res://scripts/categories.gd").ORDER:
		for r in Talents.ROWS:
			var n := Talents.in_row(cat, r).size()
			assert_true(n >= Talents.MIN_PER_ROW and n <= Talents.MAX_PER_ROW, "%s row %d has 2-4 talents" % [cat, r + 1])
			var cols: Array = Talents.layout(cat)[r].duplicate()
			var mirrored: Array = cols.map(func(c): return Talents.COLUMNS - 1 - int(c))
			mirrored.sort()
			cols.sort()
			assert_eq(cols, mirrored, "%s row %d is symmetrical" % [cat, r + 1])
		for id in Talents.in_tree(cat):
			assert_eq(Talents.category_of(id), cat)
		var shape := str(Talents.layout(cat))
		assert_false(shapes.has(shape), "%s has the same layout as %s" % [cat, shapes.get(shape, "")])
		shapes[shape] = cat

## Warrior, Rogue and Ranger are one book now: Martial. (The damage type its
## abilities deal is still called Physical.)
func test_martial_book_replaces_warrior_rogue_and_ranger() -> void:
	const Categories = preload("res://scripts/categories.gd")
	const Abilities = preload("res://scripts/abilities.gd")
	assert_eq(Categories.ORDER.size(), 8)
	assert_true(Categories.ORDER.has("martial"))
	assert_eq(Categories.cat_name("martial"), "Martial")
	for old in ["warrior", "rogue", "ranger"]:
		assert_false(Categories.ORDER.has(old), "%s is no longer a book" % old)
		assert_false(Categories.INFO.has(old))
		assert_false(Talents.LAYOUTS.has(old), "%s has no talent tree of its own" % old)
		assert_false(Talents.exists("%s_r1c3" % old), "old %s talent slots are gone (saved points in them are refunded)" % old)
	# Wiped and rebuilt: the book stays on the shelf (last, so no book moves).
	assert_eq(Categories.ORDER[-1], "martial")
	assert_false(Abilities.SPECS["martial"].is_empty(), "the Martial book is being rebuilt")
	# Every ability is in a book that exists (or in none: trinket buttons).
	for id in Abilities.ALL:
		var cat := Abilities.category_of(id)
		assert_true(cat == "" or cat == Categories.RUNE or Categories.ORDER.has(cat), "%s: book '%s' exists" % [id, cat])
	assert_eq(Talents.in_tree("martial").size(), 31, "one tree for the three of them")
	# The shelf shows the books in two even rows.
	assert_eq(Categories.shelf_columns(8), 4)
	assert_eq(Categories.shelf_columns(10), 5)
	assert_eq(Categories.shelf_columns(7), 4)
	assert_eq(Categories.shelf_columns(0), 1)

## The i-th talent (left to right) of a row (0-based) in a book. Keeps the tests
## independent of where the layouts put talents.
func _t(cat: String, row: int, i: int = 0) -> String:
	return Talents.in_row(cat, row)[i]

## The i-th talent of row `row` (0-based), across the books in order, that has 2 ranks
## and needs no ability: every book is designed now, so the rules are tested on these.
func _plain(row: int, i: int = 0, only: String = "") -> String:
	var found: Array[String] = []
	for cat in preload("res://scripts/categories.gd").ORDER:
		if only != "" and cat != only:
			continue
		for id in Talents.in_row(cat, row):
			if Talents.max_rank(id) == 2 and Talents.required_ability(id) == "":
				found.append(id)
	return found[i]

func test_talent_row_gating() -> void:
	Talents.set_links([])
	var pd := _pd()
	pd.level = 10
	assert_ne(pd.can_invest(_plain(1)), "", "row 2 locked with 0 points in row 1")
	for i in 2:
		assert_eq(pd.invest_talent(_plain(0)), "")
	assert_ne(pd.invest_talent(_plain(0)), "", "max rank is 2")
	assert_ne(pd.can_invest(_plain(1)), "", "2 points is not enough")
	assert_eq(pd.invest_talent(_plain(0, 1)), "")
	assert_eq(pd.can_invest(_plain(1)), "", "row 2 unlocks after 3 points")
	Talents.set_links(null)

func test_talent_rows_unlock_across_all_trees() -> void:
	Talents.set_links([])
	var pd := _pd()
	pd.level = 10
	pd.invest_talent(_t("fire", 0))
	pd.invest_talent(_t("frost", 0))   # (Nature's row 1 is two linked talents: they need their ability learned)
	assert_ne(pd.can_invest(_t("shadow", 1)), "", "2 points in row 1 is not enough")
	pd.invest_talent(_plain(0, 0, "holy"))
	assert_eq(pd.can_invest(_t("shadow", 1)), "", "3 points spread over trees open row 2 everywhere")
	assert_eq(pd.tree_points("fire"), 1)
	Talents.set_links(null)

func test_talent_budget_limited_by_level() -> void:
	var pd := _pd()
	pd.level = 1
	assert_eq(pd.invest_talent(_plain(0)), "")
	assert_eq(pd.invest_talent(_plain(0)), "")
	assert_eq(pd.invest_talent(_t("shadow", 0)), "")
	assert_eq(pd.invest_talent(_t("shadow", 0)), "")
	assert_eq(pd.invest_talent(_t("shadow", 0, 1)), "")
	assert_eq(pd.talent_points_left(), 0)
	assert_ne(pd.invest_talent(_t("holy", 0)), "", "no points left at level 1")

func test_talent_refund_protects_lower_tiers() -> void:
	Talents.set_links([])
	var pd := _pd()
	pd.level = 10
	pd.invest_talent(_plain(0))
	pd.invest_talent(_plain(0))
	pd.invest_talent(_plain(0, 1))
	pd.invest_talent(_t("shadow", 1))
	assert_ne(pd.can_refund(_plain(0)), "", "row 2 depends on 3 row-1 points")
	assert_eq(pd.can_refund(_t("shadow", 1)), "")
	Talents.set_links(null)

func test_talent_link_unlocks_past_row_lock() -> void:
	var src := _plain(0)
	var dst := _plain(3)
	var other := _plain(3, 1)
	Talents.set_links([[src, dst]])
	var pd := _pd()
	pd.level = 10
	assert_ne(pd.can_invest(dst), "", "row 4 locked")
	pd.invest_talent(src)
	assert_ne(pd.can_invest(dst), "", "source not maxed yet")
	pd.invest_talent(src)
	assert_eq(pd.can_invest(dst), "", "maxed source opens the linked talent")
	assert_eq(pd.invest_talent(dst), "")
	assert_ne(pd.can_refund(src), "", "linked talent depends on its maxed source")
	assert_eq(pd.can_refund(dst), "")
	assert_ne(pd.can_invest(other), "", "only the linked talent opens, not the row")
	Talents.set_links(null)

func test_talent_link_loop_is_not_valid() -> void:
	var a := _t("fire", 3)
	var b := _t("fire", 4)
	Talents.set_links([[a, b], [b, a]])
	assert_false(PlayerDataScript.talents_valid({a: 2, b: 2}), "links can't hold each other up")
	Talents.set_links(null)

func test_ice_shards_data_loads() -> void:
	const Abilities = preload("res://scripts/abilities.gd")
	const SkillCards = preload("res://scripts/skill_cards.gd")
	var r := Abilities.get_resource("iceshards")
	assert_true(r != null, "iceshards.tres loads")
	assert_eq(float(r.damage), 0.2)
	assert_eq(Abilities.category_of("iceshards"), "frost")
	assert_eq(SkillCards.ability_of("iceshards"), "iceshards")

func test_mana_is_on_the_health_scale() -> void:
	assert_eq(Stats.player_base_mana(1), 80.0, "20% less than level 1 base health (100)")
	assert_eq(Stats.player_base_mana(50), 2040.0)
	assert_eq(Stats.mana_unit(1), 8.0, "a cost point = 10% of base mana")
	var pd := _pd()
	pd.level = 10
	pd.changed.emit()
	assert_eq(float(pd.total_stats().get("max_mana", 0.0)), Stats.player_base_mana(10))

func test_frost_row3_row4_talent_values() -> void:
	var pd := _pd()
	pd.level = 20
	pd.talents = {"frost_r1c3": 3, Talents.id_for_key("frost_bolt_cast"): 3, Talents.id_for_key("frost_discipline"): 2}
	assert_eq(pd.talent_value("frost_bolt_cast"), 0.3)
	assert_eq(pd.talent_value("frost_discipline"), 3.0, "mana cost -3% at rank 2")
	assert_eq(pd.talent_value("frost_discipline", "values2"), 10.0, "threat -10% at rank 2")
	# Frozen Mind: Spell Power = 6% of Intellect at rank 3.
	pd.talents["frost_r4c1"] = 3
	pd.attribute_points = {"intellect": 10}
	pd.changed.emit()
	var t: Dictionary = pd.total_stats()
	var intel := Stats.from_totals(Stats.INTELLECT, t)
	var sp_without := intel * 0.5
	assert_true(absf(Stats.from_totals(Stats.SPELL_POWER, t) - (sp_without + intel * 0.06)) < 0.01,
		"spell power gets 6% of intellect on top")

func test_chilled_effect_id() -> void:
	assert_true(preload("res://scripts/core/effects.gd").get_effect("chilled") != null, "Bitter Cold checks for 'chilled'")

func test_frost_talent_values() -> void:
	var pd := _pd()
	pd.level = 10
	assert_eq(Talents.id_for_key("frost_haste"), "frost_r1c3")
	assert_eq(Talents.id_for_key("frost_absorb"), "frost_r1c7")
	assert_eq(pd.talent_value("frost_absorb"), 0.0)
	pd.invest_talent("frost_r1c7")
	pd.invest_talent("frost_r1c7")
	assert_eq(pd.talent_value("frost_absorb"), 10.0, "Rime Ward rank 2")
	pd.invest_talent("frost_r1c3")
	pd.changed.emit()
	assert_true(absf(float(pd.total_stats().get("haste", 0.0)) - 0.7) < 0.001, "Frozen Focus rank 1 = +0.7% haste")

func test_shard_proc_talent_needs_ice_shards() -> void:
	var pd := _pd()
	pd.level = 10
	pd.talents = {"frost_r1c3": 2, "frost_r1c7": 1, Talents.id_for_key("frost_shard_proc"): 1}
	assert_eq(pd.talent_value("frost_shard_proc"), 0.0, "Ice Shards not known")
	pd.learn_ability("iceshards")
	assert_eq(pd.talent_value("frost_shard_proc"), 10.0)

func test_validate_talents_refunds_when_over_budget() -> void:
	var pd := _pd()
	pd.level = 1
	pd.talents = {_plain(0): 2, _t("shadow", 0): 2, _t("fire", 0): 2}
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
	pd.changed.emit()
	assert_eq(float(pd.total_stats().get("max_health", 0.0)), Stats.player_base_health(5))

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

func test_crit_rating_converts_to_crit() -> void:
	var raw := func(k): return 175.0 if k == Stats.CRIT_RATING else 0.0
	assert_eq(Stats.CRIT_RATING_PER_PCT, 70.0, "stat squish: 70 rating = 1%")
	assert_true(absf(Stats.resolve(Stats.CRIT, raw) - 7.5) < 0.001, "5% base + 175 rating (2.5%)")
	assert_false(Stats.is_percent(Stats.CRIT_RATING), "rating is shown as a flat number")
	var d := Items.get_item(ItemDB.create("sword", "", 1))
	assert_eq(float(d["stats"].get("crit_rating", 0.0)), 168.0, "sword gives rating, not crit chance")
	assert_false(d["stats"].has("crit_chance"))

func test_old_saves_migrate_crit_and_haste() -> void:
	var saved := {"#00000001000001": {"base": "helmet", "ilvl": 5, "rolled": {"crit_chance": 3.0, "haste": 5.0, "armor": 4.0}}}
	ItemDB.load_records(saved)
	var rolled: Dictionary = ItemDB.get_record("#00000001000001")["rolled"]
	assert_eq(float(rolled.get("crit_rating", 0.0)), 252.0, "3% crit -> 360 rating (x100, +20%), squished to 252 (still 3.6%)")
	assert_false(rolled.has("crit_chance"))
	assert_eq(float(rolled.get("haste", 0.0)), 2.8, "haste -20%, then -30%")
	assert_eq(float(rolled.get("armor", 0.0)), 3.0, "flat stats x0.7 (each point is worth more)")
	# Loading it again (already migrated) changes nothing.
	ItemDB.load_records(ItemDB.serialize(["#00000001000001"]))
	assert_eq(float(ItemDB.get_record("#00000001000001")["rolled"].get("haste", 0.0)), 2.8, "migrates once")
	assert_eq(float(ItemDB.get_record("#00000001000001")["rolled"].get("armor", 0.0)), 3.0, "migrates once")

## Stat squish: numbers are 30% smaller and worth the same.
func test_stat_squish_keeps_results() -> void:
	# 100 Intellect before = 70 now: the same mana, spell crit and spell damage.
	var raw := func(k): return 70.0 if k == Stats.INTELLECT else 0.0
	assert_true(absf(Stats.resolve(Stats.MAX_MANA, raw) - 400.0) < 0.001, "mana of 100 old Intellect")
	assert_true(absf(Stats.resolve(Stats.SPELL_CRIT, raw) - 2.0) < 0.001, "spell crit of 100 old Intellect")
	var stat_of := func(s): return Stats.resolve(s, raw)
	assert_true(absf(Stats.power_bonus(PackedStringArray(["Spell"]), stat_of) - 30.0) < 0.001, "50 old Spell Power x 0.6")
	# (Armor no longer blocks: it reduces damage, see tests/test_armor.gd.)
	# Gear and flat buffs are 30% smaller.
	assert_true(absf(Stats.flat_unit(50) - 87.5) < 0.001, "flat unit at level 50")
	assert_eq(Stats.pool_unit(50), 125.0, "flat Max Health / Mana on gear is not squished")
	# Constitution: 20% less health per (old) point.
	var con := func(k): return 70.0 if k == Stats.CONSTITUTION else 0.0
	assert_true(absf(Stats.resolve(Stats.MAX_HEALTH, con) - 400.0) < 0.001, "100 old Constitution: 400 health (was 500)")

## Attribute points: Strength, Agility, Intellect, Constitution (no Health / Mana).
func test_attribute_choices() -> void:
	var pd := _pd()
	assert_eq(pd.ATTRIBUTE_ORDER, ["strength", "agility", "intellect", "constitution"])
	assert_false(pd.ATTRIBUTE_VALUES.has("max_health") or pd.ATTRIBUTE_VALUES.has("max_mana"))

func test_cast_times_include_bonus() -> void:
	const Balance = preload("res://scripts/balance.gd")
	assert_eq(float(Balance.ABILITIES["frostbolt"]["cast_time"]), 1.7)

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
	# (The same armor type for both: it decides which stats a piece carries.)
	var lo := Items.get_item(ItemDB.create("chestplate", "", 1, 0, {}, 3))
	var hi := Items.get_item(ItemDB.create("chestplate", "", 9, 0, {}, 3))
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
	pd.learn_ability("frostnova")
	pd.add_boon("strength", 1.0)
	var d: Dictionary = pd.apply_death()
	assert_eq(pd.level, 1)
	assert_true(pd.equipment.is_empty(), "equipped gear lost")
	assert_eq(pd.inventory[0], "", "bag lost")
	assert_ne(pd.bank[0], "", "bank kept")
	assert_true(pd.known_runes.has("frost"), "rune on lost gear is learned")
	assert_true(d["runes_learned"].has("frost"))
	assert_false(pd.has_ability("frostnova"), "drafted abilities lost")
	assert_false(pd.action_bar.has("frostnova"))
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

## A burst of changes rebuilds the UI once: learning many abilities is one `changed`,
## and `changed_late` (what the UI listens to) fires once per frame however many came.
func test_bursts_of_changes_rebuild_the_ui_once() -> void:
	var pd := _pd()
	var count := {"now": 0, "late": 0}
	var on_now := func(): count["now"] += 1
	var on_late := func(): count["late"] += 1
	pd.changed.connect(on_now)
	pd.changed_late.connect(on_late)
	var todo: Array = ["thornshot", "fawn", "vinefist", "fangarrow"].filter(func(id): return not pd.has_ability(id))
	pd.learn_abilities(todo)
	for id in todo:
		assert_true(pd.has_ability(id), "%s learned" % id)
	assert_eq(int(count["now"]), 1 if not todo.is_empty() else 0, "one change for all of them")
	pd.changed.emit()
	pd.changed.emit()
	assert_true(bool(pd._late_queued), "queued for the end of the frame")
	assert_eq(int(count["late"]), 0, "not yet")
	pd._emit_changed_late()   # (what the end of the frame runs, once)
	assert_eq(int(count["late"]), 1, "the UI hears it once")
	assert_false(bool(pd._late_queued))
	pd.changed.disconnect(on_now)
	pd.changed_late.disconnect(on_late)
