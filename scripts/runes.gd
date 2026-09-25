extends RefCounted

# Rune registry, backed by RuneData resources in res://data/runes/.
# Usage: const Runes = preload("res://scripts/runes.gd")
# Runes live on items ("sword|frost"). Learned ones are in PlayerData.known_runes.

const PATHS := {
	"frost": "res://data/runes/frost.tres",
	"fury": "res://data/runes/fury.tres",
	"swiftness": "res://data/runes/swiftness.tres",
	"warding": "res://data/runes/warding.tres",
	"stormfire": "res://data/runes/stormfire.tres",
	"smoldering_focus": "res://data/runes/smoldering_focus.tres",
	"frostbound_insight": "res://data/runes/frostbound_insight.tres",
}
const ALL := ["frost", "fury", "swiftness", "warding", "stormfire", "smoldering_focus", "frostbound_insight"]

# --- Rarity & equip limits (per character, across all equipped gear) ---------
enum { COMMON, RARE, EPIC, LEGENDARY }   # = RuneData.Rarity
const RARITY_NAMES := ["Common", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := [Color(0.85, 0.85, 0.85), Color(0.35, 0.6, 1.0), Color(0.75, 0.4, 1.0), Color(1.0, 0.55, 0.1)]
## Legendary runes equipped at once (any mix of ids).
const MAX_LEGENDARY := 1
## Epic runes equipped at once; each epic may only be equipped once.
const MAX_EPIC := 4
## Copies of the SAME rune by rarity, unless the rune sets max_equipped.
const DEFAULT_COPIES := [3, 3, 1, 1]
## Loot: relative chance of each rarity when an item rolls a rune.
const DROP_WEIGHTS := [60.0, 28.0, 10.0, 2.0]

static var _cache := {}

static func rarity(id: String) -> int:
	var r := get_resource(id)
	return clampi(int(r.rarity), 0, 3) if r else COMMON

static func rarity_name(id: String) -> String:
	return RARITY_NAMES[rarity(id)]

static func rarity_color(id: String) -> Color:
	return RARITY_COLORS[rarity(id)]

## How many copies of this rune one character may have equipped.
static func max_copies(id: String) -> int:
	var r := get_resource(id)
	if r and int(r.max_equipped) > 0:
		return int(r.max_equipped)
	return DEFAULT_COPIES[rarity(id)]

## `ids` = the rune on each equipped item ("" for none). Returns why that set
## breaks the limits, or "" if it's allowed.
static func check_limits(ids: Array) -> String:
	var counts := {}
	var legendary := 0
	var epic := 0
	for id in ids:
		var rid := str(id)
		if rid == "" or not PATHS.has(rid):
			continue
		counts[rid] = int(counts.get(rid, 0)) + 1
		match rarity(rid):
			LEGENDARY: legendary += 1
			EPIC: epic += 1
	if legendary > MAX_LEGENDARY:
		return "Only %d Legendary rune can be equipped at a time" % MAX_LEGENDARY
	if epic > MAX_EPIC:
		return "Only %d Epic runes can be equipped at a time" % MAX_EPIC
	for rid in counts:
		var cap := max_copies(rid)
		if int(counts[rid]) > cap:
			if cap == 1:
				return "%s can only be equipped once" % rune_name(rid)
			return "%s can only be equipped %d times" % [rune_name(rid), cap]
	return ""

## A rune from `pool`, weighted by rarity (DROP_WEIGHTS).
static func pick_weighted(pool: Array, rng: RandomNumberGenerator) -> String:
	if pool.is_empty():
		return ""
	var total := 0.0
	for id in pool:
		total += float(DROP_WEIGHTS[rarity(str(id))])
	var roll := rng.randf() * total
	for id in pool:
		roll -= float(DROP_WEIGHTS[rarity(str(id))])
		if roll <= 0.0:
			return str(id)
	return str(pool[pool.size() - 1])

static func get_resource(id: String) -> Resource:
	if not PATHS.has(id):
		return null
	if not _cache.has(id):
		_cache[id] = load(PATHS[id])
	return _cache[id]

static func unlock_level(id: String) -> int:
	var r := get_resource(id)
	return int(r.unlock_level) if r else 999

## Runes loot can roll: every rune unlocked at `level` plus runes already known.
static func unlocked_pool(level: int, known: Array = []) -> Array[String]:
	var out: Array[String] = []
	for id in ALL:
		if unlock_level(id) <= level or known.has(id):
			out.append(id)
	return out

static func rune_name(id: String) -> String:
	var r := get_resource(id)
	return r.display_name if r else ""

static func short_name(id: String) -> String:
	return rune_name(id).replace("Rune of ", "")

static func description(id: String) -> String:
	var r := get_resource(id)
	return r.description if r else ""

static func color(id: String) -> Color:
	var r := get_resource(id)
	return r.color if r else Color.WHITE

static func tooltip(id: String) -> String:
	if not PATHS.has(id):
		return ""
	var cap := max_copies(id)
	var limit := ""
	match rarity(id):
		LEGENDARY: limit = "Only %d Legendary rune can be equipped at a time." % MAX_LEGENDARY
		EPIC: limit = "Unique. Up to %d different Epic runes can be equipped." % MAX_EPIC
		_: limit = "Unique: only 1 can be equipped." if cap == 1 else "Up to %d can be equipped." % cap
	return "%s\n%s rune  •  %s\n%s\nDrag onto an equipped item to apply it." % [
		rune_name(id), rarity_name(id), limit, description(id)]

# Small rune glyph: diamond with carved lines.
static func draw_glyph(c: CanvasItem, center: Vector2, r: float, id: String) -> void:
	var col := color(id)
	var pts := PackedVector2Array([center + Vector2(0, -r), center + Vector2(r * 0.75, 0),
		center + Vector2(0, r), center + Vector2(-r * 0.75, 0)])
	c.draw_colored_polygon(pts, col.darkened(0.55))
	pts.append(pts[0])
	# Rare and better runes get a rarity-colored rim.
	c.draw_polyline(pts, rarity_color(id) if rarity(id) > COMMON else col, max(1.0, r * 0.15), true)
	var w: float = max(1.0, r * 0.14)
	match id:
		"frost":
			c.draw_line(center + Vector2(0, -r * 0.55), center + Vector2(0, r * 0.55), col, w)
			c.draw_line(center + Vector2(-r * 0.35, -r * 0.3), center + Vector2(r * 0.35, r * 0.3), col, w)
			c.draw_line(center + Vector2(r * 0.35, -r * 0.3), center + Vector2(-r * 0.35, r * 0.3), col, w)
		"fury":
			c.draw_polyline(PackedVector2Array([center + Vector2(-r * 0.3, -r * 0.5), center + Vector2(r * 0.2, -r * 0.05),
				center + Vector2(-r * 0.2, r * 0.05), center + Vector2(r * 0.3, r * 0.5)]), col, w)
		"swiftness":
			c.draw_line(center + Vector2(-r * 0.35, -r * 0.35), center + Vector2(r * 0.1, 0), col, w)
			c.draw_line(center + Vector2(r * 0.1, 0), center + Vector2(-r * 0.35, r * 0.35), col, w)
			c.draw_line(center + Vector2(0, -r * 0.35), center + Vector2(r * 0.4, 0), col, w)
			c.draw_line(center + Vector2(r * 0.4, 0), center + Vector2(0, r * 0.35), col, w)
		"warding":
			c.draw_arc(center, r * 0.35, 0, TAU, 12, col, w)
			c.draw_line(center + Vector2(0, -r * 0.55), center + Vector2(0, r * 0.55), col, w)
		"stormfire":
			# Lightning bolt over a small flame
			c.draw_polyline(PackedVector2Array([center + Vector2(r * 0.15, -r * 0.6), center + Vector2(-r * 0.2, -r * 0.05),
				center + Vector2(r * 0.15, -r * 0.05), center + Vector2(-r * 0.15, r * 0.35)]), Color(0.8, 0.85, 1.0), w)
			c.draw_arc(center + Vector2(0, r * 0.4), r * 0.18, PI, TAU, 8, col, w)
		"smoldering_focus":
			# Flame with a bright core
			c.draw_polyline(PackedVector2Array([center + Vector2(-r * 0.3, r * 0.4), center + Vector2(-r * 0.25, -r * 0.1),
				center + Vector2(0, -r * 0.55), center + Vector2(r * 0.25, -r * 0.1), center + Vector2(r * 0.3, r * 0.4),
				center + Vector2(-r * 0.3, r * 0.4)]), col, w)
			c.draw_circle(center + Vector2(0, r * 0.15), r * 0.14, Color(1.0, 0.95, 0.6))
		"frostbound_insight":
			# Eye with a snowflake pupil
			c.draw_arc(center, r * 0.4, PI * 0.15, PI * 0.85, 8, col, w)
			c.draw_arc(center, r * 0.4, PI * 1.15, PI * 1.85, 8, col, w)
			c.draw_circle(center, r * 0.13, Color(0.85, 0.97, 1.0))
