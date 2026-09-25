extends RefCounted

# Item registry, backed by GearItemData resources in res://data/items/.
# Usage: const Items = preload("res://scripts/items.gd")
#
# An item stored in inventory/bank/equipment is an ITEM INSTANCE id ("#5f3a...")
# whose record lives in ItemDB (base item, runes, item level, rarity, rolled
# stats, durability). Every function here accepts an instance id, and still
# understands the old "sword" / "sword|frost" strings (used by old saves and as
# base ids when creating items).

const ItemDB = preload("res://scripts/core/item_db.gd")
const GEAR_SCRIPT = preload("res://scripts/data/gear_item_data.gd")

const PATHS := {
	"helmet": "res://data/items/helmet.tres",
	"chestplate": "res://data/items/chestplate.tres",
	"sword": "res://data/items/sword.tres",
	"bow": "res://data/items/bow.tres",
	# Armor for the remaining slots
	"amulet": "res://data/items/amulet.tres",
	"pauldrons": "res://data/items/pauldrons.tres",
	"cloak": "res://data/items/cloak.tres",
	"gloves": "res://data/items/gloves.tres",
	"leggings": "res://data/items/leggings.tres",
	"boots": "res://data/items/boots.tres",
	"ring_focus": "res://data/items/ring_focus.tres",
	"ring_might": "res://data/items/ring_might.tres",
	# Weapons / off hand
	"staff": "res://data/items/staff.tres",
	"dagger": "res://data/items/dagger.tres",
	"venom_fang": "res://data/items/venom_fang.tres",
	"shield": "res://data/items/shield.tres",
	# Trinkets (Equip: procs / Use: actives)
	"storm_idol": "res://data/items/storm_idol.tres",
	"phoenix_ember": "res://data/items/phoenix_ember.tres",
	"berserker_tooth": "res://data/items/berserker_tooth.tres",
	"arcane_clockwork": "res://data/items/arcane_clockwork.tres",
	"frost_shard": "res://data/items/frost_shard.tres",
	"sand_hourglass": "res://data/items/sand_hourglass.tres",
	"sacred_reliquary": "res://data/items/sacred_reliquary.tres",
}
const ALL := ["helmet", "chestplate", "sword", "bow",
	"amulet", "pauldrons", "cloak", "gloves", "leggings", "boots", "ring_focus", "ring_might",
	"staff", "dagger", "venom_fang", "shield",
	"storm_idol", "phoenix_ember", "berserker_tooth", "arcane_clockwork",
	"frost_shard", "sand_hourglass", "sacred_reliquary"]
const Stats = preload("res://scripts/core/stats.gd")
## Kept for older callers; the real lists live in stats.gd.
const STAT_LABELS := Stats.LABELS
const PERCENT_STATS := Stats.PERCENT_STATS

static var _res_cache := {}
static var _dict_cache := {}

# --- Instance / rune helpers -----------------------------------------------------

static func base_id(item: String) -> String:
	if ItemDB.is_instance_id(item):
		return str(ItemDB.get_record(item).get("base", ""))
	return item.get_slice("|", 0)

static func runes_of(item: String) -> Array:
	if ItemDB.is_instance_id(item):
		return Array(ItemDB.get_record(item).get("runes", []))
	return [item.get_slice("|", 1)] if item.contains("|") else []

## The active rune ("" if none).
static func rune_of(item: String) -> String:
	var e := runes_of(item)
	return str(e[0]) if not e.is_empty() else ""

## Set (or clear with "") the rune. Instances are changed in place and the
## same id is returned; legacy strings return a new string.
static func with_rune(item: String, rune_id: String) -> String:
	if ItemDB.is_instance_id(item):
		if ItemDB.has(item):
			ItemDB.records[item]["runes"] = [rune_id] if rune_id != "" else []
		return item
	var b := base_id(item)
	return b if rune_id == "" else "%s|%s" % [b, rune_id]

## Base stats are multiplied by this for the item's level (same curve as rolled stats).
static func stat_scale(ilvl: int) -> float:
	return 1.0 + (maxi(ilvl, 1) - 1) * 0.25

## Player level needed to equip the item: its item level (1 - 50).
## Stats scale with item level, so stronger items need a higher level.
static func required_level(item: String) -> int:
	if not ItemDB.is_instance_id(item):
		return 1
	return clampi(int(ItemDB.get_record(item).get("ilvl", 1)), 1, 50)

static func rarity_of(item: String) -> int:
	return int(ItemDB.get_record(item).get("rarity", 0)) if ItemDB.is_instance_id(item) else 0

static func rarity_color(item: String) -> Color:
	return ItemDB.RARITY_COLORS[rarity_of(item)]

# --- Lookups ---------------------------------------------------------------------

static func get_resource(item: String) -> Resource:
	var id := base_id(item)
	if not PATHS.has(id):
		return null
	if not _res_cache.has(id):
		_res_cache[id] = load(PATHS[id])
	return _res_cache[id]

static func exists(item: String) -> bool:
	if ItemDB.is_instance_id(item):
		return ItemDB.has(item) and PATHS.has(base_id(item))
	return PATHS.has(base_id(item))

# Dictionary view used across the game:
#   name, slot, locks_offhand, color, desc, stats (base + rolled), and for weapons:
#   weapon ("melee"/"ranged"), damage, attack_interval, attack_range.
#   Instances also get: rarity, rarity_name, rarity_color, ilvl, durability, max_durability.
static func get_item(item: String) -> Dictionary:
	var id := base_id(item)
	if id == "" or not PATHS.has(id):
		return {}
	var d := _base_dict(id)
	if not ItemDB.is_instance_id(item):
		return d
	var rec := ItemDB.get_record(item)
	var out := d.duplicate()
	# Base stats grow with item level (higher level = higher stats, see stat_scale).
	var ilvl := int(rec.get("ilvl", 1))
	var stats := {}
	for s in d["stats"]:
		stats[s] = roundf(float(d["stats"][s]) * stat_scale(ilvl))
	var rolled: Dictionary = rec.get("rolled", {})
	for s in rolled:
		stats[s] = float(stats.get(s, 0.0)) + float(rolled[s])
	out["stats"] = stats
	out["rolled"] = rolled
	var r := int(rec.get("rarity", 0))
	out["rarity"] = r
	out["rarity_name"] = ItemDB.RARITY_NAMES[r]
	out["rarity_color"] = ItemDB.RARITY_COLORS[r]
	out["ilvl"] = ilvl
	out["required_level"] = required_level(item)
	out["durability"] = int(rec.get("durability", 100))
	out["max_durability"] = int(rec.get("max_durability", 100))
	return out

static func _base_dict(id: String) -> Dictionary:
	if _dict_cache.has(id):
		return _dict_cache[id]
	var r := get_resource(id)
	var d := {
		# SLOT_NAMES lookup instead of r.slot_name(): also works on editor
		# placeholder resources (automated tests run inside the editor).
		"name": r.display_name, "slot": GEAR_SCRIPT.SLOT_NAMES[int(r.slot)], "locks_offhand": r.locks_offhand,
		"color": r.color, "desc": r.description, "stats": r.stats,
		"rarity": 0, "rarity_name": ItemDB.RARITY_NAMES[0], "rarity_color": ItemDB.RARITY_COLORS[0], "ilvl": 1,
		"item_type": str(r.get("item_type") if r.get("item_type") != null else ""),
	}
	if r.weapon_type != 0:
		d["weapon"] = "melee" if r.weapon_type == 1 else "ranged"
		d["damage"] = r.weapon_damage
		d["attack_interval"] = r.attack_interval
		d["attack_range"] = r.attack_range
	_dict_cache[id] = d
	return d

static func item_name(item: String) -> String:
	# The rune isn't part of the name; tooltips show it on its own line under it.
	return str(get_item(item).get("name", ""))

# --- Item effects ("Equip:" procs and "Use:" actives, mostly trinkets) -------------

## The item's built-in passive effect (RuneData) or null.
static func equip_effect_of(item: String) -> Resource:
	var r := get_resource(item)
	return r.get("equip_effect") if r else null

## The item's active "Use:" effect (RuneData) or null.
static func use_effect_of(item: String) -> Resource:
	var r := get_resource(item)
	return r.get("use_effect") if r else null

## Item effect damage / heals / flat buffs grow with item level (+10% per level,
## gentler than stats). Percent buffs (haste, crit...) never scale.
const EFFECT_SCALE_PER_LEVEL := 0.1

static func effect_scale(item: String) -> float:
	if not ItemDB.is_instance_id(item):
		return 1.0
	return 1.0 + (maxi(int(ItemDB.get_record(item).get("ilvl", 1)), 1) - 1) * EFFECT_SCALE_PER_LEVEL

## Buff size of an effect at this scale (percent stats stay as they are).
static func scaled_buff(res: Resource, scale: float) -> float:
	var b := float(res.buff_amount)
	return b if Stats.is_percent(str(res.buff_stat)) else b * scale

static func item_type(item: String) -> String:
	return str(get_item(item).get("item_type", ""))

## An effect's description with {amount} (damage / heal) and {buff} (buff size)
## filled in for this item's level.
static func effect_text(item: String, res: Resource) -> String:
	if res == null:
		return ""
	var s := effect_scale(item)
	var t: String = res.description
	t = t.replace("{amount}", str(maxi(int(round(float(res.effect_amount) * s)), 1)))
	var b := scaled_buff(res, s)
	t = t.replace("{buff}", ("%d" % b) if is_equal_approx(b, round(b)) else ("%.1f" % b))
	return t

## "Equip: ..." / "Use: ... (60 s cooldown)" lines for tooltips (plain text).
static func effect_lines(item: String) -> Array[String]:
	var out: Array[String] = []
	var eq := equip_effect_of(item)
	if eq:
		out.append("Equip: " + effect_text(item, eq))
	var use := use_effect_of(item)
	if use:
		out.append("Use: %s (%s s cooldown)" % [effect_text(item, use), Stats.num(float(use.internal_cooldown))])
	return out

## Slot name for tooltips: "Finger" / "Trinket" for items that fit either
## slot of a pair (their data says "Finger 1" / "Trinket 1").
static func slot_label(item: String) -> String:
	var s := str(get_item(item).get("slot", ""))
	if s.begins_with("Finger ") or s.begins_with("Trinket "):
		return s.get_slice(" ", 0)
	return s

## "Neck  •  Amulet" line for tooltips (the description is left out when it
## would only repeat the slot, e.g. trinkets).
static func slot_line(item: String) -> String:
	var s := slot_label(item)
	var desc := str(get_item(item).get("desc", ""))
	if desc == "" or desc == s:
		return s
	return "%s  •  %s" % [s, desc]

static func stat_line(stat: String, value: float) -> String:
	return Stats.bonus_line(stat, value)

## What changes if `item` replaces `old_items` (whatever it would unequip:
## the item in its slot, plus the Off Hand for a two-hander).
## Returns {stat: delta} for every stat that changes (0 deltas left out),
## plus "weapon_damage" / "attack_interval" deltas when weapons are involved.
static func stat_changes(item: String, old_items: Array) -> Dictionary:
	var out := {}
	var new_d := get_item(item)
	for s in new_d.get("stats", {}):
		out[s] = float(out.get(s, 0.0)) + float(new_d["stats"][s])
	var old_weapon := {}
	for old in old_items:
		var d := get_item(str(old))
		if d.is_empty():
			continue
		for s in d.get("stats", {}):
			out[s] = float(out.get(s, 0.0)) - float(d["stats"][s])
		if d.has("weapon") and old_weapon.is_empty():
			old_weapon = d
	if new_d.has("weapon") or not old_weapon.is_empty():
		out["weapon_damage"] = float(new_d.get("damage", 0)) - float(old_weapon.get("damage", 0))
		if new_d.has("weapon") and not old_weapon.is_empty():
			out["attack_interval"] = float(new_d["attack_interval"]) - float(old_weapon["attack_interval"])
	for s in out.keys():
		if is_zero_approx(float(out[s])):
			out.erase(s)
	return out

static func tooltip(item: String) -> String:
	var d := get_item(item)
	if d.is_empty():
		return ""
	var lines: Array[String] = [item_name(item)]
	var rune := rune_of(item)
	if rune != "":
		lines.append(load("res://scripts/runes.gd").rune_name(rune))
	var head := "%s  •  Item Level %d" % [d["rarity_name"], d["ilvl"]]
	lines.append(head)
	var req := required_level(item)
	if req > 1:
		lines.append("Requires Level %d" % req)
	lines.append(slot_line(item))
	if d.has("weapon"):
		lines.append("%d damage  •  %.1f s  •  %s m range" % [d["damage"], d["attack_interval"], str(d["attack_range"])])
	for stat in d["stats"]:
		lines.append(stat_line(str(stat), float(d["stats"][stat])))
	lines.append_array(effect_lines(item))
	if d.has("durability"):
		lines.append("Durability %d / %d" % [d["durability"], d["max_durability"]])
	var e := rune_of(item)
	if e != "":
		var Runes = load("res://scripts/runes.gd")
		lines.append("%s rune — %s" % [Runes.rarity_name(e), Runes.description(e)])
	return "\n".join(lines)
