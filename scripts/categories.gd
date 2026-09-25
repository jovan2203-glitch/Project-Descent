extends RefCounted

# Ability / talent categories ("books"). Every ability belongs to one category
# (Abilities.CATEGORY_OF) and every category has its own talent tree (Talents).
# Usage: const Categories = preload("res://scripts/categories.gd")

const ORDER := ["fire", "frost", "lightning", "arcane", "shadow", "nature", "holy", "warrior", "rogue", "ranger"]

const INFO := {
	"fire": {"name": "Fire", "color": Color(0.95, 0.42, 0.15),
		"desc": "Burning attacks, explosions and damage over time."},
	"frost": {"name": "Frost", "color": Color(0.5, 0.85, 1.0),
		"desc": "Chilling attacks that slow, freeze and shatter."},
	"lightning": {"name": "Lightning", "color": Color(0.45, 0.55, 1.0),
		"desc": "Fast, chaining strikes and stunning blows."},
	"arcane": {"name": "Arcane", "color": Color(0.95, 0.45, 0.85),
		"desc": "Raw magic: missiles, blinks and mana tricks."},
	"shadow": {"name": "Shadow", "color": Color(0.58, 0.32, 0.82),
		"desc": "Corruption, life drain and weakening curses."},
	"nature": {"name": "Nature", "color": Color(0.45, 0.85, 0.35),
		"desc": "Poisons, roots, thorns and regrowth."},
	"holy": {"name": "Holy", "color": Color(1.0, 0.88, 0.45),
		"desc": "Healing, protection and bane of the undead."},
	"warrior": {"name": "Warrior", "color": Color(0.85, 0.3, 0.25),
		"desc": "Heavy weapons, rage and raw toughness."},
	"rogue": {"name": "Rogue", "color": Color(0.75, 0.75, 0.8),
		"desc": "Quick blades, evasion and lethal crits."},
	"ranger": {"name": "Ranger", "color": Color(0.65, 0.8, 0.35),
		"desc": "Bows, traps and precision from afar."},
}

static func cat_name(id: String) -> String:
	return str(INFO.get(id, {}).get("name", id.capitalize()))

static func color(id: String) -> Color:
	return INFO.get(id, {}).get("color", Color(0.7, 0.7, 0.7))

static func desc(id: String) -> String:
	return str(INFO.get(id, {}).get("desc", ""))

## Draw the category emblem centred in `c` (use from a Control's draw signal).
static func draw_emblem(c: Control, id: String) -> void:
	var s := c.size
	var mid := s / 2.0
	var k: float = min(s.x, s.y) / 64.0
	var col := color(id)
	var light := col.lightened(0.45)
	match id:
		"fire":
			var outer := PackedVector2Array([Vector2(0, -26), Vector2(7, -12), Vector2(15, -2),
				Vector2(17, 10), Vector2(11, 21), Vector2(0, 25), Vector2(-11, 21), Vector2(-17, 10),
				Vector2(-13, -3), Vector2(-8, 3), Vector2(-6, -10)])
			var inner := PackedVector2Array([Vector2(1, -6), Vector2(8, 6), Vector2(8, 15),
				Vector2(0, 21), Vector2(-8, 15), Vector2(-7, 6)])
			for i in outer.size():
				outer[i] = mid + outer[i] * k
			for i in inner.size():
				inner[i] = mid + inner[i] * k
			c.draw_colored_polygon(outer, col)
			c.draw_colored_polygon(inner, Color(1.0, 0.85, 0.4))
		"frost":
			for i in 3:
				var a := i * PI / 3.0 + PI / 2.0
				var v := Vector2(cos(a), sin(a)) * 22.0 * k
				c.draw_line(mid - v, mid + v, light, 3.0 * k, true)
				for sgn: float in [-1.0, 1.0]:
					var tip: Vector2 = mid + v * sgn * 0.6
					for off: float in [0.6, -0.6]:
						var n := Vector2(cos(a + off), sin(a + off)) * 7.0 * k * sgn
						c.draw_line(tip, tip + n, light, 2.2 * k, true)
			c.draw_circle(mid, 3.5 * k, Color.WHITE)
		"lightning":
			var bolt := PackedVector2Array([Vector2(4, -24), Vector2(-12, 3), Vector2(-1, 3),
				Vector2(-6, 24), Vector2(12, -4), Vector2(1, -4), Vector2(8, -24)])
			for i in bolt.size():
				bolt[i] = mid + bolt[i] * k
			c.draw_colored_polygon(bolt, light)
		"arcane":
			# Four-pointed star inside a rune circle
			c.draw_arc(mid, 21.0 * k, 0, TAU, 32, Color(col, 0.7), 2.0 * k, true)
			var star := PackedVector2Array()
			for i in 8:
				var a := TAU * i / 8.0 - PI / 2.0
				var r := (19.0 if i % 2 == 0 else 5.5) * k
				star.append(mid + Vector2(cos(a), sin(a)) * r)
			c.draw_colored_polygon(star, col)
			c.draw_circle(mid, 3.5 * k, Color(1, 0.9, 1))
		"shadow":
			# A watching eye
			var eye := PackedVector2Array()
			for i in 13:
				var t := float(i) / 12.0
				eye.append(mid + Vector2(-22 + 44 * t, -sin(t * PI) * 12.0) * k)
			for i in range(11, 0, -1):
				var t := float(i) / 12.0
				eye.append(mid + Vector2(-22 + 44 * t, sin(t * PI) * 12.0) * k)
			c.draw_colored_polygon(eye, col.darkened(0.2))
			c.draw_circle(mid, 8.0 * k, Color(0.12, 0.05, 0.18))
			c.draw_circle(mid, 4.0 * k, light)
		"nature":
			var leaf := PackedVector2Array()
			for i in 21:
				var t := float(i) / 20.0
				leaf.append(mid + Vector2(-20 + 40 * t, -sin(t * PI) * 13.0).rotated(-0.7) * k)
			for i in range(19, 0, -1):
				var t := float(i) / 20.0
				leaf.append(mid + Vector2(-20 + 40 * t, sin(t * PI) * 13.0).rotated(-0.7) * k)
			c.draw_colored_polygon(leaf, col)
			c.draw_line(mid + Vector2(-22, 0).rotated(-0.7) * k, mid + Vector2(18, 0).rotated(-0.7) * k,
				col.darkened(0.45), 2.0 * k, true)
		"holy":
			for i in 12:
				var a := TAU * i / 12.0
				var r1 := 14.0 if i % 2 == 0 else 15.0
				var r2 := 25.0 if i % 2 == 0 else 20.0
				c.draw_line(mid + Vector2(cos(a), sin(a)) * r1 * k, mid + Vector2(cos(a), sin(a)) * r2 * k,
					col, 2.5 * k, true)
			c.draw_circle(mid, 11.0 * k, col)
			c.draw_circle(mid, 6.0 * k, Color(1, 1, 0.9))
		"warrior":
			var blade := PackedVector2Array([Vector2(-3, 8), Vector2(-3, -20), Vector2(0, -26),
				Vector2(3, -20), Vector2(3, 8)])
			for i in blade.size():
				blade[i] = mid + blade[i] * k
			c.draw_colored_polygon(blade, Color(0.88, 0.88, 0.92))
			c.draw_line(mid + Vector2(-11, 9) * k, mid + Vector2(11, 9) * k, col, 4.0 * k, true)
			c.draw_line(mid + Vector2(0, 10) * k, mid + Vector2(0, 21) * k, Color(0.45, 0.28, 0.16), 4.0 * k, true)
			c.draw_circle(mid + Vector2(0, 23) * k, 3.0 * k, col)
		"rogue":
			for sgn: float in [-1.0, 1.0]:
				var d := Vector2(sgn, -1).normalized()
				var p := Vector2(-d.y, d.x)
				var base := mid - d * 8.0 * k
				var tip := mid + d * 22.0 * k
				c.draw_colored_polygon(PackedVector2Array([base + p * 3.0 * k, tip, base - p * 3.0 * k]),
					Color(0.9, 0.9, 0.95))
				c.draw_line(base + p * 7.0 * k, base - p * 7.0 * k, col.darkened(0.3), 3.0 * k, true)
				c.draw_line(base, base - d * 10.0 * k, Color(0.3, 0.22, 0.2), 3.5 * k, true)
		"ranger":
			c.draw_arc(mid + Vector2(-8, 0) * k, 22.0 * k, -1.25, 1.25, 20, Color(0.6, 0.42, 0.25), 3.5 * k, true)
			var top := mid + Vector2(-8 + cos(-1.25) * 22.0, sin(-1.25) * 22.0) * k
			var bot := mid + Vector2(-8 + cos(1.25) * 22.0, sin(1.25) * 22.0) * k
			c.draw_line(top, bot, Color(0.9, 0.9, 0.85), 1.2 * k, true)
			c.draw_line(mid + Vector2(-4, 0) * k, mid + Vector2(22, 0) * k, Color(0.75, 0.55, 0.35), 2.2 * k, true)
			c.draw_colored_polygon(PackedVector2Array([mid + Vector2(26, 0) * k, mid + Vector2(19, -4) * k,
				mid + Vector2(19, 4) * k]), light)
			c.draw_line(mid + Vector2(-4, 0) * k, mid + Vector2(-9, -4) * k, col, 2.0 * k, true)
			c.draw_line(mid + Vector2(-4, 0) * k, mid + Vector2(-9, 4) * k, col, 2.0 * k, true)
