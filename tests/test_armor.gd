@tool
extends McpTestSuite

# Armor: it reduces all the damage its wearer takes (it no longer blocks; Block
# is a stat of its own), and every piece of armor is one of four types: Cloth,
# Light, Medium or Heavy. The heavier, the more Armor; the lighter, the more of
# its type's stat.

const Balance = preload("res://scripts/balance.gd")
const Stats = preload("res://scripts/core/stats.gd")
const Items = preload("res://scripts/items.gd")
const ItemDB = preload("res://scripts/core/item_db.gd")
const CombatSystem = preload("res://scripts/core/combat_system.gd")
const DebugCommands = preload("res://scripts/core/debug_commands.gd")

const CLOTH := 0
const LIGHT := 1
const MEDIUM := 2
const HEAVY := 3
const PIECES := ["helmet", "pauldrons", "chestplate", "gloves", "leggings", "boots"]

var _saved_records := {}

func suite_name() -> String:
	return "armor"

func setup() -> void:
	_saved_records = ItemDB.records.duplicate(true)

func teardown() -> void:
	ItemDB.records = _saved_records

## Armor of a full set of `armor_type` at item level `ilvl` (plus a shield if asked).
func _set_armor(armor_type: int, ilvl: int, shield: bool = false) -> float:
	var total := 0.0
	for base in PIECES:
		var id := ItemDB.create(str(base), "", ilvl, 0, {}, armor_type)
		total += float(Items.get_item(id)["stats"].get(Stats.ARMOR, 0.0))
	if shield:
		total += float(Items.get_item(ItemDB.create("shield", "", ilvl))["stats"].get(Stats.ARMOR, 0.0))
	return total

# --- Armor reduces damage --------------------------------------------------------------

func test_armor_takes_a_share_off_all_damage() -> void:
	assert_eq(Balance.ARMOR_DR_CAP, 60.0)
	assert_eq(Stats.armor_reduction(0.0, 50), 0.0)
	assert_true(is_equal_approx(Stats.armor_reduction(Balance.ARMOR_DR_PER_LEVEL * 50.0, 50), 50.0), "that much Armor: half of it")
	assert_eq(Stats.armor_reduction(1.0e9, 50), Balance.ARMOR_DR_CAP, "capped")
	assert_true(Stats.armor_reduction(500.0, 50) > Stats.armor_reduction(250.0, 50), "more Armor, more off")
	assert_true(Stats.armor_reduction(500.0, 50) < 2.0 * Stats.armor_reduction(250.0, 50), "each point is worth a little less than the last")
	# With a resistance: one after the other.
	assert_true(is_equal_approx(Stats.mitigation(40.0, 0.0), 40.0))
	assert_true(is_equal_approx(Stats.mitigation(0.0, 25.0), 25.0))
	assert_true(is_equal_approx(Stats.mitigation(40.0, 50.0), 70.0), "40% then 50% of what is left")
	assert_true(Stats.mitigation(40.0, -50.0) < 40.0, "a weakness still counts against it")
	# In a hit: 40% off a hit of 1000 leaves 600. Nothing is blocked by Armor.
	var hit := CombatSystem.compute_damage(1000.0, 0.0, 0.0, 0.0, Stats.mitigation(40.0, 0.0), 99.0, 0.0)
	assert_eq(int(hit["amount"]), 600)
	assert_false(bool(hit["blocked"]))
	# A hit that can't be blocked (damage over time) is reduced all the same.
	var dot := CombatSystem.compute_damage(1000.0, 0.0, 0.0, 0.0, Stats.mitigation(40.0, 0.0), 99.0, 0.0, false, false)
	assert_eq(int(dot["amount"]), 600, "damage over time too")

func test_the_stat_panel_and_texts() -> void:
	var row := Stats.panel_line(Stats.ARMOR, 500.0)
	assert_contains(row, "Armor  500")
	assert_contains(row, "% less damage")
	assert_false(row.contains("block"))
	assert_contains(Stats.describe(Stats.ARMOR), "Reduces all the damage you take")
	assert_contains(Stats.describe(Stats.ARMOR), "60%")
	assert_false(Stats.describe(Stats.BLOCK).contains("Armor"), "Block's text no longer speaks of Armor")
	assert_contains(Stats.describe(Stats.BLOCK), "Strength")

# --- Armor types -------------------------------------------------------------------------

func test_four_types() -> void:
	assert_eq(Balance.ARMOR_TYPE_NAMES, ["Cloth", "Light", "Medium", "Heavy"])
	assert_eq(Balance.ARMOR_TYPE_ARMOR.size(), 4)
	assert_eq(Balance.ARMOR_TYPE_STAT, ["intellect", "agility", "strength", "constitution"])
	for i in range(1, 4):
		assert_true(float(Balance.ARMOR_TYPE_ARMOR[i]) > float(Balance.ARMOR_TYPE_ARMOR[i - 1]), "heavier: more Armor")
		assert_true(float(Balance.ARMOR_TYPE_STAT_AMOUNT[i]) < float(Balance.ARMOR_TYPE_STAT_AMOUNT[i - 1]), "lighter: more of its stat")
	assert_eq(Balance.ARMOR_PIECES.size(), 6, "Head, Shoulder, Chest, Gloves, Legs, Boots")
	for base in PIECES:
		assert_true(Balance.ARMOR_PIECES.has(base), "%s is a piece of armor" % base)
		assert_true(Items.PATHS.has(base))
		assert_eq((Balance.ARMOR_PIECE_NAMES[base] as Array).size(), 4, "%s has a name for every type" % base)
		assert_true(Balance.ARMOR_LEGACY_TYPE.has(base))
		assert_true(ItemDB.is_armor_piece(str(base)))
	for other in ["sword", "shield", "cloak", "amulet", "ring_might", "storm_idol"]:
		assert_false(ItemDB.is_armor_piece(other), "%s has no armor type" % other)
	# No two pieces share a name.
	var names := {}
	for base in Balance.ARMOR_PIECE_NAMES:
		for n in Balance.ARMOR_PIECE_NAMES[base]:
			assert_false(names.has(n), "two pieces are called %s" % n)
			names[n] = true

func test_a_piece_of_armor_has_a_type() -> void:
	var chest := ItemDB.create("chestplate", "", 50, 0, {}, HEAVY)
	assert_eq(Items.armor_type_of(chest), HEAVY)
	var d := Items.get_item(chest)
	assert_eq(str(d["name"]), "Plate Cuirass")
	assert_eq(int(d["armor_type"]), HEAVY)
	assert_eq(Items.slot_line(chest), "Chest  •  Heavy Armor")
	assert_contains(Items.tooltip(chest), "Heavy Armor")
	# Its Armor is its slot's weight in flat units; a Heavy piece also has Constitution.
	assert_eq(float(d["stats"][Stats.ARMOR]), roundf(3.0 * Stats.flat_unit(50)))
	assert_eq(float(d["stats"]["constitution"]), roundf(3.0 * 0.3 * Stats.flat_unit(50)))
	# The same piece in cloth: a fifth of the Armor, and Intellect instead.
	var robe := ItemDB.create("chestplate", "", 50, 0, {}, CLOTH)
	var r := Items.get_item(robe)
	assert_eq(str(r["name"]), "Silk Robe")
	assert_eq(float(r["stats"][Stats.ARMOR]), roundf(3.0 * 0.2 * Stats.flat_unit(50)))
	assert_eq(float(r["stats"]["intellect"]), roundf(3.0 * 0.75 * Stats.flat_unit(50)))
	assert_false(r["stats"].has("constitution"))
	assert_eq(Items.slot_line(robe), "Chest  •  Cloth Armor")
	# What the template gives besides Armor is kept (the chest's Max Health).
	assert_true(float(d["stats"].get("max_health", 0.0)) > 0.0)
	assert_eq(float(d["stats"]["max_health"]), float(r["stats"]["max_health"]))
	# Rolled stats still add on top.
	var rolled := ItemDB.create("chestplate", "", 50, 1, {Stats.ARMOR: 100.0}, HEAVY)
	assert_eq(float(Items.get_item(rolled)["stats"][Stats.ARMOR]), roundf(3.0 * Stats.flat_unit(50)) + 100.0)

func test_types_are_rolled_and_kept() -> void:
	# A new piece of armor gets one of the four; anything else gets none.
	var seen := {}
	for i in 80:
		var id := ItemDB.create("helmet")
		var t := ItemDB.armor_type_of(id)
		assert_true(t >= 0 and t <= 3)
		seen[t] = true
	assert_eq(seen.size(), 4, "every type drops")
	assert_eq(ItemDB.armor_type_of(ItemDB.create("sword")), ItemDB.NO_ARMOR_TYPE)
	assert_eq(ItemDB.armor_type_of(ItemDB.create("shield")), ItemDB.NO_ARMOR_TYPE)
	assert_eq(ItemDB.armor_type_of(ItemDB.create("sword", "", 1, 0, {}, HEAVY)), ItemDB.NO_ARMOR_TYPE, "a sword can't be Heavy")
	assert_eq(Items.armor_type_of("chestplate"), ItemDB.NO_ARMOR_TYPE, "a bare item name has no type")
	assert_eq(ItemDB.armor_type_of(ItemDB.create_rolled("gloves", 30, 2, "", LIGHT)), LIGHT)
	# Saving and loading keeps it.
	var id := ItemDB.create("leggings", "", 20, 0, {}, CLOTH)
	var saved := ItemDB.serialize([id])
	ItemDB.load_records(saved)
	assert_eq(ItemDB.armor_type_of(id), CLOTH)
	assert_eq(str(Items.get_item(id)["name"]), "Silk Trousers")

## Armor saved before types existed becomes what it was called then.
func test_old_armor_gets_the_type_it_was_named_after() -> void:
	var old := {}
	var want := {"helmet": HEAVY, "pauldrons": HEAVY, "chestplate": HEAVY, "gloves": LIGHT, "leggings": MEDIUM, "boots": LIGHT}
	var n := 0
	for base in want:
		n += 1
		old["#0000000000000%d" % n] = {"base": base, "runes": [], "ilvl": 10, "rarity": 0, "rolled": {}, "stack": 1, "stat_v": ItemDB.STAT_VERSION}
	old["#00000000000009"] = {"base": "sword", "runes": [], "ilvl": 10, "rarity": 0, "rolled": {}, "stack": 1, "stat_v": ItemDB.STAT_VERSION}
	ItemDB.load_records(old)
	n = 0
	for base in want:
		n += 1
		assert_eq(ItemDB.armor_type_of("#0000000000000%d" % n), int(want[base]), "%s" % base)
	assert_eq(ItemDB.armor_type_of("#00000000000009"), ItemDB.NO_ARMOR_TYPE)
	assert_eq(str(Items.get_item("#00000000000001")["name"]), "Plate Helm")
	assert_eq(str(Items.get_item("#00000000000004")["name"]), "Leather Grips", "the old gloves keep their name")
	assert_eq(str(Items.get_item("#00000000000005")["name"]), "Chain Leggings")

## A tank in full Heavy armor with a shield takes about 40% less; the lighter
## sets less, in even steps. The same at every level.
func test_what_a_full_set_is_worth() -> void:
	for level in [10, 50]:
		var cloth := Stats.armor_reduction(_set_armor(CLOTH, level), level)
		var light := Stats.armor_reduction(_set_armor(LIGHT, level), level)
		var medium := Stats.armor_reduction(_set_armor(MEDIUM, level), level)
		var heavy := Stats.armor_reduction(_set_armor(HEAVY, level), level)
		var tank := Stats.armor_reduction(_set_armor(HEAVY, level, true), level)
		assert_true(absf(cloth - 10.0) < 2.0, "Cloth at level %d: about 10%% (%.1f)" % [level, cloth])
		assert_true(absf(light - 18.5) < 2.0, "Light: about 18%% (%.1f)" % light)
		assert_true(absf(medium - 28.5) < 2.0, "Medium: about 28%% (%.1f)" % medium)
		assert_true(absf(heavy - 36.0) < 2.0, "Heavy: about 36%% (%.1f)" % heavy)
		assert_true(absf(tank - 40.0) < 2.0, "Heavy with a shield: about 40%% (%.1f)" % tank)
		assert_true(tank < Balance.ARMOR_DR_CAP)

func test_give_takes_an_armor_type() -> void:
	var want := DebugCommands.parse_give(["chestplate", "heavy", "epic", "50"])
	assert_eq(str(want["item"]), "chestplate")
	assert_eq(int(want["armor_type"]), HEAVY)
	assert_eq(int(want["rarity"]), 3)
	assert_eq(int(want["level"]), 50)
	assert_eq(int(DebugCommands.parse_give(["helmet", "rare", "cloth"])["armor_type"]), CLOTH, "in either order")
	assert_false(DebugCommands.parse_give(["helmet"]).has("armor_type"), "none named: the piece rolls a random one")
	assert_false(DebugCommands.parse_give(["heavy"]).has("armor_type"), "a type on its own is the item's name")
	assert_eq(str(DebugCommands.parse_give(["helmet", "rare"])["item"]), "helmet")
	assert_contains("\n".join(DebugCommands.give_help()), "cloth, light, medium or heavy")
