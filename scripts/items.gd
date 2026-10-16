extends RefCounted

# Item registry, backed by GearItemData resources in res://data/items/.
# Usage: const Items = preload("res://scripts/items.gd")
#
# An item stored in inventory/bank/equipment is an ITEM INSTANCE id ("#5f3a...")
# whose record lives in ItemDB (base item, runes, item level, rarity, rolled
# stats). Every function here accepts an instance id, and still
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
	"greatsword": "res://data/items/greatsword.tres",   # two-handed melee (the Lightning tank's weapon)
	"dagger": "res://data/items/dagger.tres",
	"venom_fang": "res://data/items/venom_fang.tres",
	"shield": "res://data/items/shield.tres",
	# Spellcasting off hands and one-handers (base templates, tune later)
	"tome": "res://data/items/tome.tres",
	"wand": "res://data/items/wand.tres",
	"lantern": "res://data/items/lantern.tres",   # the Holy tank's off hand
	"ritual_dagger": "res://data/items/ritual_dagger.tres",
	"runed_blade": "res://data/items/runed_blade.tres",
	# Trinkets (Equip: procs / Use: actives)
	"storm_idol": "res://data/items/storm_idol.tres",
	"phoenix_ember": "res://data/items/phoenix_ember.tres",
	"berserker_tooth": "res://data/items/berserker_tooth.tres",
	"arcane_clockwork": "res://data/items/arcane_clockwork.tres",
	"frost_shard": "res://data/items/frost_shard.tres",
	"sand_hourglass": "res://data/items/sand_hourglass.tres",
	"sacred_reliquary": "res://data/items/sacred_reliquary.tres",
	# Mysterious Runes (not equippable): reveal in the main menu to learn a rune.
	"mystery_rune_0": "res://data/items/mystery_rune_0.tres",
	"mystery_rune_1": "res://data/items/mystery_rune_1.tres",
	"mystery_rune_2": "res://data/items/mystery_rune_2.tres",
	"mystery_rune_3": "res://data/items/mystery_rune_3.tres",
}
const ALL := ["helmet", "chestplate", "sword", "bow",
	"amulet", "pauldrons", "cloak", "gloves", "leggings", "boots", "ring_focus", "ring_might",
	"staff", "greatsword", "dagger", "venom_fang", "shield",
	"tome", "wand", "lantern", "ritual_dagger", "runed_blade",
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

## Base stats are multiplied by this for the item's level (same curve as rolled
## stats): flat stats (Intellect, Armor...) by Stats.flat_unit, percent stats
## (Haste, Crit, Move Speed) by the much gentler Stats.pct_scale.
static func stat_scale(ilvl: int, stat: String = "") -> float:
	if stat != "" and Stats.scales_like_percent(stat):
		return Stats.pct_scale(ilvl)
	return Stats.unit_for(stat, ilvl)

## Weapon damage coefficient -> real damage per hit at the player's level.
static func real_weapon_damage(coef: float) -> int:
	return int(round(coef * Stats.level_hit(Stats._player_level())))

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

# --- Mysterious Runes ------------------------------------------------------------

## Is this a Mysterious Rune (a consumable that reveals a rune choice)?
static func is_mystery_rune(item: String) -> bool:
	return base_id(item).begins_with("mystery_rune_")

## Rune rarity (Runes.COMMON..LEGENDARY) of a Mysterious Rune, -1 otherwise.
static func mystery_rarity(item: String) -> int:
	if not is_mystery_rune(item):
		return -1
	return clampi(int(base_id(item).trim_prefix("mystery_rune_")), 0, 3)

## Base item id of a Mysterious Rune of rune rarity `r`.
static func mystery_rune_base(r: int) -> String:
	return "mystery_rune_%d" % clampi(r, 0, 3)

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
#   Instances also get: rarity, rarity_name, rarity_color, ilvl, required_level.
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
	var armor_type := int(rec.get("armor_type", ItemDB.NO_ARMOR_TYPE)) if ItemDB.is_armor_piece(id) else ItemDB.NO_ARMOR_TYPE
	for s in d["stats"]:
		if armor_type >= 0 and str(s) == Stats.ARMOR:
			continue   # a piece of armor's Armor comes from its type (below), not from its template
		var v := float(d["stats"][s]) * stat_scale(ilvl, str(s))
		# Percent stats (Haste 1.6%...) keep one decimal, the rest are whole numbers.
		stats[s] = roundf(v * 10.0) / 10.0 if Stats.is_percent(str(s)) else roundf(v)
	# Armor types (balance.gd): the heavier the piece, the more Armor; the
	# lighter, the more of its type's stat. It is named and described by its type.
	if armor_type >= 0:
		var typed := armor_piece_stats(id, armor_type, ilvl)
		for s in typed:
			stats[s] = float(stats.get(s, 0.0)) + float(typed[s])
		out["name"] = armor_piece_name(id, armor_type)
		out["desc"] = "%s Armor" % armor_type_name(armor_type)
		out["armor_type"] = armor_type
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
	return out

# --- Armor types (Cloth, Light, Medium, Heavy) --------------------------------------
# Every piece of armor (Balance.ARMOR_PIECES) is one of four types, rolled when
# the item is made (ItemDB "armor_type"). The numbers are in balance.gd.

const Balance = preload("res://scripts/balance.gd")

## "Cloth", "Light", "Medium" or "Heavy" ("" for no type).
static func armor_type_name(armor_type: int) -> String:
	return str(Balance.ARMOR_TYPE_NAMES[armor_type]) if armor_type >= 0 and armor_type < Balance.ARMOR_TYPE_NAMES.size() else ""

## The armor type of an item (-1 = none: not a piece of armor, or not an instance).
static func armor_type_of(item: String) -> int:
	if not ItemDB.is_instance_id(item) or not ItemDB.is_armor_piece(base_id(item)):
		return ItemDB.NO_ARMOR_TYPE
	return ItemDB.armor_type_of(item)

## What a piece of armor of base `base` and type `armor_type` is called.
static func armor_piece_name(base: String, armor_type: int) -> String:
	var names: Array = Balance.ARMOR_PIECE_NAMES.get(base, [])
	if armor_type >= 0 and armor_type < names.size():
		return str(names[armor_type])
	return str(_base_dict(base).get("name", ""))

## The stats a piece of armor gets from its type at item level `ilvl`: its
## Armor, and its type's stat (Intellect, Agility, Strength or Constitution).
static func armor_piece_stats(base: String, armor_type: int, ilvl: int) -> Dictionary:
	if not Balance.ARMOR_PIECES.has(base) or armor_type < 0 or armor_type >= Balance.ARMOR_TYPE_NAMES.size():
		return {}
	var weight := float(Balance.ARMOR_PIECES[base])
	var unit := Stats.flat_unit(ilvl)
	var bonus := str(Balance.ARMOR_TYPE_STAT[armor_type])
	return {
		Stats.ARMOR: maxf(roundf(weight * float(Balance.ARMOR_TYPE_ARMOR[armor_type]) * unit), 1.0),
		bonus: maxf(roundf(weight * float(Balance.ARMOR_TYPE_STAT_AMOUNT[armor_type]) * unit), 1.0),
	}

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

## Item effect damage / heals are coefficients (1.0 = a standard hit), so they
## already grow with your level (an item's level = the level needed to wear it).
## Kept as a hook for extra per-item scaling.
static func effect_scale(_item: String) -> float:
	return 1.0

## Buff size of an effect: flat buffs are in flat units (Stats.flat_unit of
## your level, e.g. "+2 Attack Power" = +250 at level 50); percent stats stay.
static func scaled_buff(res: Resource, scale: float) -> float:
	var b := float(res.buff_amount)
	return b if Stats.is_percent(str(res.buff_stat)) else b * scale * Stats.unit_for(str(res.buff_stat), Stats._player_level())

static func item_type(item: String) -> String:
	return str(get_item(item).get("item_type", ""))

## Is this a one-handed melee weapon? Those can be held in the Off Hand too
## (dual wield: a one-handed melee weapon in each hand).
static func is_one_handed_melee(item: String) -> bool:
	var d := get_item(item)
	return str(d.get("weapon", "")) == "melee" and not bool(d.get("locks_offhand", false))

## Is this an off hand item (tome, wand, lantern...): made for the Off Hand,
## not a weapon and not a shield?
static func is_off_hand_item(item: String) -> bool:
	var d := get_item(item)
	return str(d.get("slot", "")) == "Off Hand" and not d.has("weapon") and str(d.get("item_type", "")) != "shield"

## An effect's description with {amount} (damage / heal) and {buff} (buff size)
## filled in for this item's level.
static func effect_text(item: String, res: Resource) -> String:
	if res == null:
		return ""
	# (Every number comes from the effect's data: see TextFill.rune.)
	return preload("res://scripts/core/text_fill.gd").rune(res, effect_scale(item))

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
		out["weapon_damage"] = float(real_weapon_damage(float(new_d.get("damage", 0)))) \
			- float(real_weapon_damage(float(old_weapon.get("damage", 0))))
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
		lines.append("%d damage  •  %.1f s  •  %s m range" % [real_weapon_damage(float(d["damage"])), d["attack_interval"], str(d["attack_range"])])
	for stat in d["stats"]:
		lines.append(stat_line(str(stat), float(d["stats"][stat])))
	lines.append_array(effect_lines(item))
	var e := rune_of(item)
	if e != "":
		var Runes = load("res://scripts/runes.gd")
		lines.append("%s rune — %s" % [Runes.rarity_name(e), Runes.description(e)])
	return "\n".join(lines)
