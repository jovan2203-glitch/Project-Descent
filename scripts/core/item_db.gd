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
#   stack       (for future stackables)
# Items never lose durability (there is none).
# Items.gd resolves ids transparently, so UI code keeps calling Items.get_item(id).
# Old saves' "sword|frost" strings are converted with from_legacy().

const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic"]
const RARITY_COLORS := [Color(0.9, 0.9, 0.9), Color(0.35, 0.95, 0.35), Color(0.35, 0.6, 1.0), Color(0.75, 0.4, 1.0)]
## Random bonus stat pool: stat -> amount per roll at item level 1.
const ROLL_POOL := {"intellect": 1.0, "agility": 1.0, "strength": 1.0, "constitution": 1.0,
	"armor": 1.0, "haste": 1.12, "crit_rating": 168.0, "spell_power": 1.0, "attack_power": 1.0, "move_speed": 3.0,
	"lifesteal": 0.3,
	# Avoidance (percent stats; balance.gd): Dodge, Parry, Block.
	"dodge": Balance.AVOIDANCE_ROLL, "parry": Balance.AVOIDANCE_ROLL, "block_chance": Balance.AVOIDANCE_ROLL}
## How likely each stat is to be rolled (default 1). Secondary stats are rare:
## Move Speed shows up on ~1 in 40 rolls, Lifesteal ~1 in 60. Lifesteal is
## tiny per roll (0.3% at item level 1, ~0.9% at 50), so 5% is hard to reach.
## Version of the item stat format (2 = Critical Strike Rating, haste cut 20%;
## 3 = stat squish: flat stats and rating x0.7, haste cut another 30%).
## Older saved records are migrated in load_records.
const STAT_VERSION := 3
## Dodge, Parry and Block are each rolled half as often as an ordinary stat.
const ROLL_WEIGHTS := {"move_speed": 0.25, "lifesteal": 0.15,
	"dodge": Balance.AVOIDANCE_ROLL_WEIGHT, "parry": Balance.AVOIDANCE_ROLL_WEIGHT, "block_chance": Balance.AVOIDANCE_ROLL_WEIGHT}
const Balance = preload("res://scripts/balance.gd")
const Stats = preload("res://scripts/core/stats.gd")
const Runes = preload("res://scripts/runes.gd")

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

## `armor_type` for "roll one": a piece of armor gets one of the four types at
## random; anything else has none.
const ROLL_ARMOR_TYPE := -2
const NO_ARMOR_TYPE := -1

## Is `base` a piece of armor (it has an armor type: Cloth, Light, Medium, Heavy)?
static func is_armor_piece(base: String) -> bool:
	return Balance.ARMOR_PIECES.has(base)

## The armor type a new or loaded record of `base` ends up with: `wanted` if it
## is one (0-3), a random one for ROLL_ARMOR_TYPE, none for anything that is not
## a piece of armor.
static func resolve_armor_type(base: String, wanted: int) -> int:
	if not is_armor_piece(base):
		return NO_ARMOR_TYPE
	if wanted >= 0 and wanted < Balance.ARMOR_TYPE_NAMES.size():
		return wanted
	return randi() % Balance.ARMOR_TYPE_NAMES.size()

## The armor type of item instance `id` (-1 = it has none).
static func armor_type_of(id: String) -> int:
	return int(records.get(id, {}).get("armor_type", NO_ARMOR_TYPE))

## Create a new item instance. Returns its id.
static func create(base: String, rune: String = "", ilvl: int = 1, rarity: int = 0, rolled: Dictionary = {},
		armor_type: int = ROLL_ARMOR_TYPE) -> String:
	var id := new_id()
	records[id] = {
		"base": base,
		"armor_type": resolve_armor_type(base, armor_type),
		"runes": [rune] if rune != "" else [],
		"ilvl": maxi(ilvl, 1),
		"rarity": clampi(rarity, 0, RARITY_NAMES.size() - 1),
		"rolled": rolled.duplicate(),
		"stack": 1,
		"stat_v": STAT_VERSION,
	}
	return id

## Create an instance and roll `rarity` random bonus stats scaled by item level.
static func create_rolled(base: String, ilvl: int, rarity: int, rune: String = "", armor_type: int = ROLL_ARMOR_TYPE) -> String:
	return create(base, rune, ilvl, rarity, roll_stats(rarity, ilvl), armor_type)

static func roll_stats(rarity: int, ilvl: int) -> Dictionary:
	var out := {}
	for i in clampi(rarity, 0, 3):
		var stat := _pick_roll_stat()
		out[stat] = float(out.get(stat, 0.0)) + roll_amount(stat, ilvl)
	return out

## One roll of `stat` at item level `ilvl` (as random rolls give it).
static func roll_amount(stat: String, ilvl: int) -> float:
	var amount := float(ROLL_POOL.get(stat, 1.0)) * (Stats.pct_scale(ilvl) if Stats.scales_like_percent(stat) else Stats.flat_unit(ilvl))
	# Percent stats (Haste 1.6%, Lifesteal 0.3%) keep one decimal; the rest are whole numbers.
	return roundf(amount * 10.0) / 10.0 if Stats.is_percent(stat) else roundf(amount)

## A random stat from ROLL_POOL, weighted by ROLL_WEIGHTS (secondary stats are rare).
static func _pick_roll_stat() -> String:
	var total := 0.0
	for s in ROLL_POOL:
		total += float(ROLL_WEIGHTS.get(s, 1.0))
	var r := randf() * total
	for s in ROLL_POOL:
		r -= float(ROLL_WEIGHTS.get(s, 1.0))
		if r <= 0.0:
			return str(s)
	return str(ROLL_POOL.keys()[0])

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
		if is_instance_id(str(id)) and saved[id] is Dictionary:
			records[str(id)] = _clean_record(saved[id])

## Adds records from somewhere else (another player's inspect snapshot) without
## touching yours: ids already known are skipped. Never saved (SaveSystem saves
## only your own items).
static func merge_records(saved: Variant) -> void:
	if not (saved is Dictionary):
		return
	for id in saved:
		if is_instance_id(str(id)) and saved[id] is Dictionary and not records.has(str(id)):
			records[str(id)] = _clean_record(saved[id])

## A saved record, checked and brought up to date.
static func _clean_record(r: Dictionary) -> Dictionary:
	var base := str(r.get("base", ""))
	var rec := {
		# A piece of armor saved before armor types existed gets the type it was
		# named after then (Iron = Heavy, Chain = Medium, Leather = Light).
		"armor_type": resolve_armor_type(base, int(r.get("armor_type", Balance.ARMOR_LEGACY_TYPE.get(base, NO_ARMOR_TYPE)))),
		"base": str(r.get("base", "")),
		# "enchants" = saves from before runes were renamed
		# (runes that no longer exist, like Smoldering Focus, are dropped)
		"runes": Array(r.get("runes", r.get("enchants", []))).map(func(e): return str(e)).filter(func(e): return Runes.PATHS.has(e)),
		"ilvl": maxi(int(r.get("ilvl", 1)), 1),
		"rarity": clampi(int(r.get("rarity", 0)), 0, RARITY_NAMES.size() - 1),
		"rolled": r.get("rolled", {}) if r.get("rolled", {}) is Dictionary else {},
		"stack": maxi(int(r.get("stack", 1)), 1),
		"stat_v": STAT_VERSION,
	}
	# Items saved before Critical Strike Rating: crit_chance -> rating, haste -20%
	# (once: the record is saved back with the current stat_v).
	if int(r.get("stat_v", 1)) < 2:
		rec["rolled"] = Stats.migrate_item_stats(rec["rolled"])
	# Items saved before the stat squish: smaller numbers, same worth; less haste.
	if int(r.get("stat_v", 1)) < 3:
		rec["rolled"] = Stats.squish_item_stats(rec["rolled"])
	# Mysterious Runes remember their revealed choices.
	if r.get("choices") is Array:
		rec["choices"] = Array(r["choices"]).map(func(x): return str(x))
	return rec
