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
	"frostbound_insight": "res://data/runes/frostbound_insight.tres",
	# Epic Frost runes (PASSIVE: rule changes checked in player.gd with has_rune)
	"permafrost": "res://data/runes/permafrost.tres",
	"cold_precision": "res://data/runes/cold_precision.tres",
	"frozen_aegis": "res://data/runes/frozen_aegis.tres",
	"everlasting_rime": "res://data/runes/everlasting_rime.tres",
	# Epic Fire runes (PASSIVE: checked in player.gd with has_rune)
	"dull_edge": "res://data/runes/dull_edge.tres",
	"dull_mind": "res://data/runes/dull_mind.tres",
	"hair_trigger": "res://data/runes/hair_trigger.tres",
	"level_head": "res://data/runes/level_head.tres",
	# Rune spells (PASSIVE: the rune teaches a spell while it is on your gear, see TEACHES)
	"frostfire_bolt": "res://data/runes/frostfire_bolt.tres",
	"polarity": "res://data/runes/polarity.tres",
	# Rare Lightning rune (PASSIVE: Return Stroke without a parry, in player.gd)
	"resonance": "res://data/runes/resonance.tres",
	# Rare Lightning rune (PASSIVE: Capacitor makes the next Discharge instant, in player.gd)
	"bottled_lightning": "res://data/runes/bottled_lightning.tres",
	# Rare rune (PASSIVE: Phase Step and Flicker leave an image that casts my next spell too, in player.gd)
	"afterimage": "res://data/runes/afterimage.tres",
	# Rare Arcane rune (PASSIVE: Glint lets any spell be cast on the move, in player.gd)
	"momentum": "res://data/runes/momentum.tres",
	# Epic Arcane rune (PASSIVE: Mirror Sigil follows you and repeats less, in player.gd)
	"carried_sigil": "res://data/runes/carried_sigil.tres",
	# Rare Arcane rune (PASSIVE: Mirror Sigil also repeats Reflection shatters, in player.gd)
	"two_way_mirror": "res://data/runes/two_way_mirror.tres",
	# Rare Shadow rune, the Rune of the Trapdoor (PASSIVE: Break Ground is instant, on a cooldown, and opens the Breach for less time, in player.gd)
	"open_wound": "res://data/runes/open_wound.tres",
	# Rare Shadow rune, up to 3, the Rune of Invitation (PASSIVE: other books' spells add to an open Breach, for each copy, in player.gd)
	"rot": "res://data/runes/rot.tres",
	# Epic Shadow rune (PASSIVE: a Breach big enough to kill its enemy twice over deals all of its damage at once, in player.gd)
	"long_fall": "res://data/runes/long_fall.tres",
	# Epic Lightning rune (PASSIVE: Static, Overload and Grounded, in player.gd)
	"overload": "res://data/runes/overload.tres",
	# Legendary rune (PASSIVE: Shadow damage starts Dusk, Dawn follows it, in player.gd)
	"dusk_till_dawn": "res://data/runes/dusk_till_dawn.tres",
	# Menace: +30% threat from one damage type (PASSIVE, threat_bonus_pct)
	"menace_physical": "res://data/runes/menace_physical.tres",
	"menace_fire": "res://data/runes/menace_fire.tres",
	"menace_frost": "res://data/runes/menace_frost.tres",
	"menace_lightning": "res://data/runes/menace_lightning.tres",
	"menace_arcane": "res://data/runes/menace_arcane.tres",
	"menace_shadow": "res://data/runes/menace_shadow.tres",
	"menace_nature": "res://data/runes/menace_nature.tres",
	"menace_holy": "res://data/runes/menace_holy.tres",
	# Holy healer (the Hymns)
	"resounding": "res://data/runes/resounding.tres",
	"overture": "res://data/runes/overture.tres",
	# Holy tank (the Censer)
	"bright_burst": "res://data/runes/bright_burst.tres",
	# Prisms (the second Holy healer and the Holy archer)
	"fourth_facet": "res://data/runes/fourth_facet.tres",
}
const ALL := ["frost", "fury", "swiftness", "warding", "stormfire", "frostbound_insight",
	"permafrost", "cold_precision", "frozen_aegis", "everlasting_rime",
	"dull_edge", "dull_mind", "hair_trigger", "level_head", "frostfire_bolt", "polarity", "resonance", "bottled_lightning", "afterimage", "momentum", "carried_sigil", "two_way_mirror", "open_wound", "rot", "long_fall", "overload", "dusk_till_dawn", "resounding", "overture", "bright_burst", "fourth_facet",
	"menace_physical", "menace_fire", "menace_frost", "menace_lightning", "menace_arcane",
	"menace_shadow", "menace_nature", "menace_holy"]

## Runes that teach a spell while they are on your gear (rune id -> ability id).
## The spell is in the "Rune Spells" book and is never offered by a draft.
const TEACHES := {"frostfire_bolt": "frostfirebolt", "polarity": "polarstrike"}

## The spell rune `id` teaches ("" = none).
static func spell_of(id: String) -> String:
	return str(TEACHES.get(id, ""))

## The rune that teaches ability `ability_id` ("" = it isn't a rune spell).
static func rune_for_spell(ability_id: String) -> String:
	for rid in TEACHES:
		if str(TEACHES[rid]) == ability_id:
			return str(rid)
	return ""

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
## Rune families: only ONE rune of a family can be equipped at a time
## (id prefix -> family name shown in errors / tooltips).
const FAMILIES := {"menace_": "Menace", "dull_": "Dull"}

## The family prefix of a rune ("" = none).
static func family_of(id: String) -> String:
	for prefix in FAMILIES:
		if id.begins_with(prefix):
			return str(prefix)
	return ""

static var _cache := {}

## Is there at least one rune of this rarity? (Loot never rolls a rarity that
## has no rune. Dusk till Dawn is the only Legendary rune right now.)
static func any_of_rarity(r: int) -> bool:
	for id in ALL:
		if rarity(id) == r:
			return true
	return false

static func rarity(id: String) -> int:
	var r := get_resource(id)
	return clampi(int(r.rarity), 0, 3) if r else COMMON

static func rarity_name(id: String) -> String:
	return RARITY_NAMES[rarity(id)]

static func rarity_color(id: String) -> Color:
	return RARITY_COLORS[rarity(id)]

## How many copies of this rune one character may have equipped.
static func max_copies(id: String) -> int:
	if family_of(id) != "":
		return 1   # family runes (Menace): one per character, of the whole family
	var r := get_resource(id)
	if r and int(r.max_equipped) > 0:
		return int(r.max_equipped)
	return DEFAULT_COPIES[rarity(id)]

## `ids` = the rune on each equipped item ("" for none). Returns why that set
## breaks the limits, or "" if it's allowed.
static func check_limits(ids: Array) -> String:
	var counts := {}
	var families := {}
	var legendary := 0
	var epic := 0
	for id in ids:
		var rid := str(id)
		if rid == "" or not PATHS.has(rid):
			continue
		counts[rid] = int(counts.get(rid, 0)) + 1
		var fam := family_of(rid)
		if fam != "":
			families[fam] = int(families.get(fam, 0)) + 1
		match rarity(rid):
			LEGENDARY: legendary += 1
			EPIC: epic += 1
	if legendary > MAX_LEGENDARY:
		return "Only %d Legendary rune can be equipped at a time" % MAX_LEGENDARY
	if epic > MAX_EPIC:
		return "Only %d Epic runes can be equipped at a time" % MAX_EPIC
	for fam in families:
		if int(families[fam]) > 1:
			return "Only one %s rune can be equipped at a time" % FAMILIES[fam]
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

## The rune's description with its numbers filled in from its data and
## balance.gd (TextFill.rune): they are never typed into the text.
static func description(id: String) -> String:
	var r := get_resource(id)
	if r == null:
		return ""
	var text: String = preload("res://scripts/core/text_fill.gd").rune(r)
	# {taught}: what the spell this rune teaches does, with its real numbers.
	if text.contains("{taught}"):
		var abilities: GDScript = load("res://scripts/abilities.gd")
		var spell := str(TEACHES.get(id, ""))
		var taught: Resource = abilities.get_resource(spell) if spell != "" else null
		text = text.replace("{taught}", str(abilities.fill(spell, taught.description, Callable(), {})) if taught else "")
	return text

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
	var fam := family_of(id)
	if fam != "":
		limit = "Only one %s rune can be equipped at a time." % FAMILIES[fam]
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
		"frostbound_insight":
			# Eye with a snowflake pupil
			c.draw_arc(center, r * 0.4, PI * 0.15, PI * 0.85, 8, col, w)
			c.draw_arc(center, r * 0.4, PI * 1.15, PI * 1.85, 8, col, w)
			c.draw_circle(center, r * 0.13, Color(0.85, 0.97, 1.0))
		"permafrost":
			# Snowflake over a slow-burning ember line
			c.draw_line(center + Vector2(0, -r * 0.55), center + Vector2(0, r * 0.2), col, w)
			c.draw_line(center + Vector2(-r * 0.3, -r * 0.35), center + Vector2(r * 0.3, 0.0), col, w)
			c.draw_line(center + Vector2(r * 0.3, -r * 0.35), center + Vector2(-r * 0.3, 0.0), col, w)
			c.draw_line(center + Vector2(-r * 0.35, r * 0.42), center + Vector2(r * 0.35, r * 0.42), Color(0.85, 0.97, 1.0), w)
		"cold_precision":
			# Crosshair
			c.draw_arc(center, r * 0.32, 0, TAU, 12, col, w)
			c.draw_line(center + Vector2(0, -r * 0.6), center + Vector2(0, -r * 0.15), col, w)
			c.draw_line(center + Vector2(0, r * 0.15), center + Vector2(0, r * 0.6), col, w)
			c.draw_circle(center, r * 0.08, Color(0.9, 0.98, 1.0))
		"frozen_aegis":
			# Shield with a frost line
			c.draw_polyline(PackedVector2Array([center + Vector2(-r * 0.35, -r * 0.4), center + Vector2(r * 0.35, -r * 0.4),
				center + Vector2(r * 0.3, r * 0.1), center + Vector2(0, r * 0.5), center + Vector2(-r * 0.3, r * 0.1),
				center + Vector2(-r * 0.35, -r * 0.4)]), col, w)
			c.draw_line(center + Vector2(0, -r * 0.3), center + Vector2(0, r * 0.3), col, w)
		"dull_edge":
			# A blade with its tip cut off flat
			c.draw_line(center + Vector2(-r * 0.12, r * 0.55), center + Vector2(-r * 0.12, -r * 0.35), col, w)
			c.draw_line(center + Vector2(r * 0.12, r * 0.55), center + Vector2(r * 0.12, -r * 0.35), col, w)
			c.draw_line(center + Vector2(-r * 0.22, -r * 0.35), center + Vector2(r * 0.22, -r * 0.35), Color(0.95, 0.92, 0.85), w * 1.3)
			c.draw_line(center + Vector2(-r * 0.3, r * 0.3), center + Vector2(r * 0.3, r * 0.3), col, w)
		"dull_mind":
			# A head with a flat line where its top would be
			c.draw_arc(center + Vector2(0, r * 0.05), r * 0.34, 0.0, PI, 12, col, w)
			c.draw_line(center + Vector2(-r * 0.34, r * 0.05), center + Vector2(-r * 0.34, -r * 0.3), col, w)
			c.draw_line(center + Vector2(r * 0.34, r * 0.05), center + Vector2(r * 0.34, -r * 0.3), col, w)
			c.draw_line(center + Vector2(-r * 0.45, -r * 0.3), center + Vector2(r * 0.45, -r * 0.3), Color(0.95, 0.92, 0.85), w * 1.3)
			c.draw_arc(center + Vector2(0, r * 0.85), r * 0.4, PI * 1.2, PI * 1.8, 8, col, w)
		"level_head":
			# A head with a level line through it
			c.draw_arc(center + Vector2(0, -r * 0.1), r * 0.3, 0, TAU, 14, col, w)
			c.draw_line(center + Vector2(-r * 0.5, -r * 0.1), center + Vector2(r * 0.5, -r * 0.1), Color(0.95, 0.97, 1.0), w)
			c.draw_arc(center + Vector2(0, r * 0.75), r * 0.4, PI * 1.2, PI * 1.8, 8, col, w)
		"hair_trigger":
			# Two flames side by side (two charges)
			for sx in [-1.0, 1.0]:
				var at := center + Vector2(sx * r * 0.2, r * 0.1)
				c.draw_polyline(PackedVector2Array([at + Vector2(-r * 0.14, r * 0.3), at + Vector2(0, -r * 0.4),
					at + Vector2(r * 0.14, r * 0.3), at + Vector2(-r * 0.14, r * 0.3)]), col, w)
		"frostfire_bolt":
			# Half snowflake, half flame
			var ice := Color(0.6, 0.9, 1.0)
			var ember := Color(1.0, 0.6, 0.25)
			c.draw_line(center + Vector2(-r * 0.08, -r * 0.5), center + Vector2(-r * 0.08, r * 0.5), ice, w)
			c.draw_line(center + Vector2(-r * 0.08, -r * 0.1), center + Vector2(-r * 0.4, -r * 0.32), ice, w)
			c.draw_line(center + Vector2(-r * 0.08, r * 0.1), center + Vector2(-r * 0.4, r * 0.32), ice, w)
			c.draw_polyline(PackedVector2Array([center + Vector2(r * 0.1, r * 0.45), center + Vector2(r * 0.2, -r * 0.45),
				center + Vector2(r * 0.42, r * 0.12), center + Vector2(r * 0.1, r * 0.45)]), ember, w)
		"polarity":
			# A plus over a minus, a line between the two charges
			var plus := Color(0.6, 0.9, 1.0)
			c.draw_line(center + Vector2(-r * 0.22, -r * 0.32), center + Vector2(r * 0.22, -r * 0.32), plus, w)
			c.draw_line(center + Vector2(0, -r * 0.54), center + Vector2(0, -r * 0.1), plus, w)
			c.draw_line(center + Vector2(-r * 0.45, 0), center + Vector2(r * 0.45, 0), col, w * 0.7)
			c.draw_line(center + Vector2(-r * 0.22, r * 0.34), center + Vector2(r * 0.22, r * 0.34), Color(1.0, 0.5, 0.4), w)
		"bottled_lightning":
			# A stoppered bottle with a bolt inside it
			c.draw_polyline(PackedVector2Array([center + Vector2(-r * 0.12, -r * 0.5), center + Vector2(-r * 0.12, -r * 0.25),
				center + Vector2(-r * 0.32, -r * 0.05), center + Vector2(-r * 0.32, r * 0.5), center + Vector2(r * 0.32, r * 0.5),
				center + Vector2(r * 0.32, -r * 0.05), center + Vector2(r * 0.12, -r * 0.25), center + Vector2(r * 0.12, -r * 0.5)]), col, w)
			c.draw_line(center + Vector2(-r * 0.18, -r * 0.56), center + Vector2(r * 0.18, -r * 0.56), Color(0.92, 0.95, 1.0), w * 1.3)
			c.draw_polyline(PackedVector2Array([center + Vector2(r * 0.08, -r * 0.05), center + Vector2(-r * 0.12, r * 0.18),
				center + Vector2(r * 0.08, r * 0.18), center + Vector2(-r * 0.08, r * 0.42)]), Color(0.92, 0.95, 1.0), w)
		"resonance":
			# A blade with waves ringing out from both sides of it
			c.draw_line(center + Vector2(0, -r * 0.55), center + Vector2(0, r * 0.55), Color(0.92, 0.95, 1.0), w * 1.3)
			for sx in [-1.0, 1.0]:
				c.draw_arc(center, r * 0.26, (0.0 if sx > 0.0 else PI) - 0.75, (0.0 if sx > 0.0 else PI) + 0.75, 8, col, w)
				c.draw_arc(center, r * 0.46, (0.0 if sx > 0.0 else PI) - 0.55, (0.0 if sx > 0.0 else PI) + 0.55, 8, col, w)
		"overload":
			# A bolt bursting out of a ring
			c.draw_arc(center, r * 0.42, 0, TAU, 14, col, w)
			c.draw_polyline(PackedVector2Array([center + Vector2(r * 0.18, -r * 0.62), center + Vector2(-r * 0.2, -r * 0.02),
				center + Vector2(r * 0.16, -r * 0.02), center + Vector2(-r * 0.18, r * 0.62)]), Color(0.92, 0.95, 1.0), w * 1.3)
		"afterimage":
			# A figure and the fainter one it left behind
			for i in 2:
				var at := center + Vector2(r * (0.16 - i * 0.34), 0.0)
				var shade := col if i == 0 else Color(col, 0.5)
				c.draw_arc(at + Vector2(0, -r * 0.32), r * 0.13, 0, TAU, 10, shade, w)
				c.draw_line(at + Vector2(0, -r * 0.18), at + Vector2(0, r * 0.22), shade, w)
				c.draw_line(at + Vector2(0, r * 0.22), at + Vector2(-r * 0.12, r * 0.5), shade, w)
				c.draw_line(at + Vector2(0, r * 0.22), at + Vector2(r * 0.12, r * 0.5), shade, w)
		"momentum":
			# A spark and the three speed lines behind it
			for i in 3:
				var y := r * (-0.3 + i * 0.3)
				c.draw_line(center + Vector2(-r * 0.5, y), center + Vector2(-r * (0.05 + (0.15 if i == 1 else 0.0)), y), col, w)
			c.draw_line(center + Vector2(r * 0.05, 0), center + Vector2(r * 0.5, 0), Color(0.95, 0.9, 1.0), w * 1.3)
			c.draw_line(center + Vector2(r * 0.28, -r * 0.24), center + Vector2(r * 0.28, r * 0.24), Color(0.95, 0.9, 1.0), w * 1.3)
		"carried_sigil":
			# A sigil (ring and diamond) held up on a hand's arc
			c.draw_arc(center + Vector2(0, -r * 0.15), r * 0.3, 0, TAU, 14, col, w)
			c.draw_polyline(PackedVector2Array([center + Vector2(0, -r * 0.33), center + Vector2(r * 0.16, -r * 0.15),
				center + Vector2(0, r * 0.03), center + Vector2(-r * 0.16, -r * 0.15), center + Vector2(0, -r * 0.33)]),
				Color(0.95, 0.9, 1.0), w * 0.8)
			c.draw_arc(center + Vector2(0, r * 0.1), r * 0.42, PI * 0.2, PI * 0.8, 10, col, w)
		"two_way_mirror":
			# A mirror (tall diamond) with an arrow going through it each way
			c.draw_polyline(PackedVector2Array([center + Vector2(0, -r * 0.6), center + Vector2(r * 0.26, 0),
				center + Vector2(0, r * 0.6), center + Vector2(-r * 0.26, 0), center + Vector2(0, -r * 0.6)]), col, w)
			for sy in [-1.0, 1.0]:
				var y: float = r * 0.2 * sy
				var tip: float = r * 0.55 * sy
				c.draw_line(center + Vector2(-tip, y), center + Vector2(tip, y), Color(0.95, 0.9, 1.0), w)
				c.draw_line(center + Vector2(tip, y), center + Vector2(tip - r * 0.16 * sy, y - r * 0.12), Color(0.95, 0.9, 1.0), w)
				c.draw_line(center + Vector2(tip, y), center + Vector2(tip - r * 0.16 * sy, y + r * 0.12), Color(0.95, 0.9, 1.0), w)
		"open_wound":
			# Rune of the Trapdoor: a hatch in the floor, swung open
			c.draw_polyline(PackedVector2Array([center + Vector2(-r * 0.36, r * 0.4), center + Vector2(r * 0.36, r * 0.4),
				center + Vector2(r * 0.36, -r * 0.02), center + Vector2(-r * 0.36, -r * 0.02), center + Vector2(-r * 0.36, r * 0.4)]), col, w)
			c.draw_polyline(PackedVector2Array([center + Vector2(-r * 0.36, -r * 0.02), center + Vector2(-r * 0.2, -r * 0.55),
				center + Vector2(r * 0.44, -r * 0.42), center + Vector2(r * 0.36, -r * 0.02)]), Color(0.95, 0.9, 1.0), w)
		"rot":
			# Rune of Invitation: a hole, and three others asked in to it (rune id "rot")
			for i in 3:
				var a := TAU * i / 3.0 - PI / 2.0
				var d := Vector2(cos(a), sin(a))
				c.draw_line(center + d * r * 0.2, center + d * r * 0.36, col, w)
				c.draw_arc(center + d * r * 0.46, r * 0.11, 0, TAU, 8, Color(0.95, 0.9, 1.0), w * 0.8)
			c.draw_arc(center, r * 0.15, 0, TAU, 10, col, w)
		"long_fall":
			# A hole in the ground, and the way down into it
			c.draw_arc(center + Vector2(0, r * 0.1), r * 0.55, 0.35, PI - 0.35, 10, col, w)
			c.draw_arc(center + Vector2(0, r * 0.75), r * 0.55, PI + 0.35, TAU - 0.35, 10, col, w)
			c.draw_line(center + Vector2(0, -r * 0.62), center + Vector2(0, r * 0.3), Color(0.95, 0.9, 1.0), w)
			c.draw_line(center + Vector2(0, r * 0.3), center + Vector2(-r * 0.18, r * 0.1), Color(0.95, 0.9, 1.0), w)
			c.draw_line(center + Vector2(0, r * 0.3), center + Vector2(r * 0.18, r * 0.1), Color(0.95, 0.9, 1.0), w)
		"dusk_till_dawn":
			# A crescent moon on the left, a sun coming up over a line on the right
			var moon := Color(0.72, 0.62, 1.0)
			var sun := Color(1.0, 0.85, 0.45)
			c.draw_arc(center + Vector2(-r * 0.2, -r * 0.05), r * 0.28, PI * 0.5, PI * 1.5, 10, moon, w * 1.3)
			c.draw_arc(center + Vector2(-r * 0.04, -r * 0.05), r * 0.32, PI * 0.7, PI * 1.3, 8, moon, w)
			var rise := center + Vector2(r * 0.24, r * 0.14)
			c.draw_arc(rise, r * 0.15, PI, TAU, 8, sun, w * 1.3)
			c.draw_line(rise + Vector2(-r * 0.24, 0), rise + Vector2(r * 0.24, 0), sun, w)
			for i in 3:
				var ray := Vector2.from_angle(PI * (1.25 + i * 0.25))
				c.draw_line(rise + ray * r * 0.23, rise + ray * r * 0.35, sun, w)
		"everlasting_rime":
			# Closed ring with an inner ring (a shell that never breaks)
			c.draw_arc(center, r * 0.42, 0, TAU, 14, col, w)
			c.draw_arc(center, r * 0.2, 0, TAU, 10, Color(0.9, 0.98, 1.0), w)
		_:
			if id.begins_with("menace_"):
				# Exclamation mark (threat)
				c.draw_line(center + Vector2(0, -r * 0.5), center + Vector2(0, r * 0.12), col, w * 1.3)
				c.draw_circle(center + Vector2(0, r * 0.38), w * 0.8, col)
