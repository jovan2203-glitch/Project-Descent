extends RefCounted

# Item instances (every item that exists is its own record).
# Usage: const ItemDB = preload("res://scripts/core/item_db.gd")
#
# Inventory / bank / equipment slots store an instance id like "#5f3a09c2000017".
# Each id maps to a record:
#   base        base item id ("sword") -> GearItemData in res://data/items/
#   runes    Array of rune ids (first one is the active rune today)
#   ilvl        item level (from the enemy level it dropped from)
#   rarity      0 Common, 1 Uncommon, 2 Rare, 3 Epic
#   rolled      random bonus stats rolled on drop, e.g. {"armor": 1}
#   durability / max_durability, stack (for future stackables)
# Items.gd resolves ids transparently, so UI code keeps calling Items.get_item(id).
# Old saves' "sword|frost" strings are converted with from_legacy().

const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic"]
const RARITY_COLORS := [Color(0.9, 0.9, 0.9), Color(0.35, 0.95, 0.35), Color(0.35, 0.6, 1.0), Color(0.75, 0.4, 1.0)]
## Random bonus stat pool: stat -> amount per roll at item level 1.
const ROLL_POOL := {"intellect": 1.0, "agility": 1.0, "strength": 1.0, "constitution": 1.0,
	"armor": 1.0, "haste": 2.0, "crit_chance": 2.0, "spell_power": 1.0, "attack_power": 1.0, "move_speed": 3.0}
const DEFAULT_DURABILITY := 100

static var records := {}      # id -> Dictionary
static var _counter := 0

static func is_instance_id(s: String) -> bool:
	return s.begins_with("#")

static func has(id: String) -> bool:
	return records.has(id)

static func get_record(id: String) -> Dictionary:
	return records.get(id, {})

static func new_id() -> String:
	_counter += 1
	var id := "#%08x%06x" % [randi(), _counter % 0xFFFFFF]
	while records.has(id):
		id = "#%08x%06x" % [randi(), _counter % 0xFFFFFF]
	return id

## Create a new item instance. Returns its id.
static func create(base: String, rune: String = "", ilvl: int = 1, rarity: int = 0, rolled: Dictionary = {}) -> String:
	var id := new_id()
	records[id] = {
		"base": base,
		"runes": [rune] if rune != "" else [],
		"ilvl": maxi(ilvl, 1),
		"rarity": clampi(rarity, 0, RARITY_NAMES.size() - 1),
		"rolled": rolled.duplicate(),
		"durability": DEFAULT_DURABILITY,
		"max_durability": DEFAULT_DURABILITY,
		"stack": 1,
	}
	return id

## Create an instance and roll `rarity` random bonus stats scaled by item level.
static func create_rolled(base: String, ilvl: int, rarity: int, rune: String = "") -> String:
	return create(base, rune, ilvl, rarity, roll_stats(rarity, ilvl))

static func roll_stats(rarity: int, ilvl: int) -> Dictionary:
	var out := {}
	var stats := ROLL_POOL.keys()
	for i in clampi(rarity, 0, 3):
		var stat: String = stats.pick_random()
		var amount := float(ROLL_POOL[stat]) * (1.0 + (maxi(ilvl, 1) - 1) * 0.25)
		out[stat] = float(out.get(stat, 0.0)) + roundf(amount)
	return out

## Old-style string ("sword" or "sword|frost") -> new instance id.
static func from_legacy(item: String) -> String:
	if item == "" or is_instance_id(item):
		return item
	var base := item.get_slice("|", 0)
	var rune := item.get_slice("|", 1) if item.contains("|") else ""
	return create(base, rune)

static func destroy(id: String) -> void:
	records.erase(id)

static func clear() -> void:
	records.clear()

# --- Save / load ------------------------------------------------------------------

## Records for the given ids only (items that no longer exist are not saved).
static func serialize(ids: Array) -> Dictionary:
	var out := {}
	for id in ids:
		if records.has(id):
			out[id] = records[id].duplicate(true)
	return out

static func load_records(saved: Variant) -> void:
	records.clear()
	if not (saved is Dictionary):
		return
	for id in saved:
		var r: Variant = saved[id]
		if not (r is Dictionary) or not is_instance_id(str(id)):
			continue
		records[str(id)] = {
			"base": str(r.get("base", "")),
			# "enchants" = saves from before runes were renamed
			"runes": Array(r.get("runes", r.get("enchants", []))).map(func(e): return str(e)),
			"ilvl": maxi(int(r.get("ilvl", 1)), 1),
			"rarity": clampi(int(r.get("rarity", 0)), 0, RARITY_NAMES.size() - 1),
			"rolled": r.get("rolled", {}) if r.get("rolled", {}) is Dictionary else {},
			"durability": int(r.get("durability", DEFAULT_DURABILITY)),
			"max_durability": int(r.get("max_durability", DEFAULT_DURABILITY)),
			"stack": maxi(int(r.get("stack", 1)), 1),
		}
