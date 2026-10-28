extends RefCounted

# Icons of the Martial DPS, the Rogue, and of Martial Utility (abilities.gd draws
# them through draw()). Builders are steel with a teal Flow edge; their Kill forms
# are the same shapes in red (a Kill window colours the blades red, scripts/rogue_fx.gd).
# Usage: const RogueIcons = preload("res://scripts/ui/rogue_icons.gd")

const STEEL := Color(0.86, 0.9, 0.96)
const HILT := Color(0.5, 0.36, 0.24)
const FLOW := Color(0.35, 0.95, 0.85)
const KILL := Color(1.0, 0.26, 0.24)
const GOLD := Color(1.0, 0.83, 0.3)
const SHADE := Color(0.2, 0.18, 0.26)
const SKIN := Color(0.86, 0.66, 0.5)

static func draw(c: Control, id: String, mid: Vector2, k: float) -> void:
	match id:
		# The builders.
		"cut":
			_glow(c, mid, k, FLOW)
			_dagger(c, mid + Vector2(-4, 0) * k, Vector2(1, -1), k, STEEL)
			_dagger(c, mid + Vector2(4, 0) * k, Vector2(-1, -1), k, STEEL)
			c.draw_line(mid + Vector2(-14, 8) * k, mid + Vector2(14, -8) * k, Color(FLOW, 0.8), 1.6 * k, true)
		"whirl":
			_glow(c, mid, k, FLOW)
			c.draw_arc(mid, 12.0 * k, 0.0, TAU * 0.8, 24, Color(FLOW, 0.85), 2.2 * k, true)
			for a in [0.0, PI * 0.66, PI * 1.33]:
				var d := Vector2(cos(a), sin(a))
				_dagger(c, mid + d * 9.0 * k, d.orthogonal(), k * 0.6, STEEL)
		"dartin":
			_glow(c, mid, k, FLOW)
			for i in 3:
				c.draw_line(mid + Vector2(-16, -5 + i * 5) * k, mid + Vector2(-4, -5 + i * 5) * k, Color(FLOW, 0.5 + i * 0.15), 1.6 * k, true)
			_dagger(c, mid + Vector2(5, 0) * k, Vector2(1, 0), k, STEEL)
		"kickoff":
			_glow(c, mid, k, FLOW)
			c.draw_line(mid + Vector2(-8, 12) * k, mid + Vector2(0, 0) * k, SKIN, 4.0 * k, true)
			c.draw_line(mid + Vector2(0, 0) * k, mid + Vector2(12, -4) * k, SHADE, 4.0 * k, true)
			c.draw_arc(mid + Vector2(-4, -2) * k, 11.0 * k, PI * 0.9, PI * 1.9, 14, Color(FLOW, 0.85), 2.0 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-16, -2), Vector2(-12, -8), Vector2(-10, -1)]), FLOW)
		"twinstab":
			_glow(c, mid, k, FLOW)
			_dagger(c, mid + Vector2(-5, 2) * k, Vector2(0, -1), k, STEEL)
			_dagger(c, mid + Vector2(5, 2) * k, Vector2(0, -1), k, STEEL)
			c.draw_circle(mid + Vector2(0, -14) * k, 2.4 * k, FLOW)
		# The Kill.
		"goin":
			c.draw_circle(mid, 15.0 * k, Color(KILL, 0.22))
			for i in 5:
				c.draw_circle(mid + Vector2(-10 + i * 5, 10) * k, 2.0 * k, FLOW)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-8, 4), Vector2(0, -14), Vector2(8, 4)]), KILL)
		"closeitout":
			c.draw_circle(mid, 15.0 * k, Color(KILL, 0.18))
			_dagger(c, mid + Vector2(0, 4) * k, Vector2(0, 1), k * 1.2, STEEL)
			c.draw_arc(mid, 13.0 * k, -PI * 0.5, PI * 1.0, 18, KILL, 2.4 * k, true)
		"hityourstride":
			c.draw_circle(mid, 15.0 * k, Color(GOLD, 0.18))
			for i in 3:
				var x := -10.0 + i * 8.0
				c.draw_colored_polygon(_pts(mid, k, [Vector2(x, -8), Vector2(x + 7, 0), Vector2(x, 8)]), [FLOW, GOLD, KILL][i])
		"rollwithit":
			c.draw_arc(mid, 11.0 * k, PI * 0.2, PI * 1.9, 20, FLOW, 4.0 * k, true)
			c.draw_circle(mid + Vector2(0, -2) * k, 4.0 * k, SKIN)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(9, -9), Vector2(15, -5), Vector2(8, -2)]), FLOW)
		"snatch":
			c.draw_rect(Rect2(mid + Vector2(-9, 0) * k, Vector2(14, 12) * k), HILT)
			c.draw_line(mid + Vector2(-9, 3) * k, mid + Vector2(5, 3) * k, GOLD, 1.4 * k, true)
			c.draw_line(mid + Vector2(14, -14) * k, mid + Vector2(0, -2) * k, SKIN, 3.6 * k, true)
			for i in 3:
				c.draw_line(mid + Vector2(0, -2) * k, mid + Vector2(-4 + i * 3, -8) * k, SKIN, 2.0 * k, true)
			c.draw_circle(mid + Vector2(10, -12) * k, 2.6 * k, Color(1, 1, 0.9))
		# The Kill forms (the builders' shapes, in red).
		"gut":
			c.draw_circle(mid, 15.0 * k, Color(KILL, 0.2))
			_dagger(c, mid, Vector2(1, -1), k * 1.3, STEEL)
			c.draw_line(mid + Vector2(-12, 4) * k, mid + Vector2(12, 4) * k, KILL, 2.4 * k, true)
		"throughandthrough":
			c.draw_circle(mid, 15.0 * k, Color(KILL, 0.2))
			_dagger(c, mid + Vector2(-5, 0) * k, Vector2(1, 0), k, STEEL)
			_dagger(c, mid + Vector2(5, 6) * k, Vector2(-1, 0), k, STEEL)
			c.draw_line(mid + Vector2(0, -14) * k, mid + Vector2(0, 14) * k, KILL, 2.0 * k, true)
		"redwhirl":
			c.draw_circle(mid, 15.0 * k, Color(KILL, 0.2))
			c.draw_arc(mid, 12.0 * k, 0.0, TAU * 0.85, 24, KILL, 2.6 * k, true)
			c.draw_arc(mid, 7.0 * k, PI, TAU * 1.3, 16, Color(KILL, 0.7), 2.0 * k, true)
			for a in [PI * 0.25, PI * 1.25]:
				var d := Vector2(cos(a), sin(a))
				_dagger(c, mid + d * 10.0 * k, d.orthogonal(), k * 0.6, STEEL)
		"backflip":
			c.draw_circle(mid, 15.0 * k, Color(KILL, 0.2))
			c.draw_arc(mid + Vector2(-3, 0) * k, 10.0 * k, PI * 0.6, PI * 2.1, 18, KILL, 2.4 * k, true)
			for i in 3:
				_dagger(c, mid + Vector2(8, -8 + i * 7) * k, Vector2(1, 0), k * 0.5, STEEL)
		"drivethrough":
			c.draw_circle(mid, 15.0 * k, Color(KILL, 0.2))
			c.draw_circle(mid, 6.0 * k, SHADE)
			c.draw_line(mid + Vector2(-16, 0) * k, mid + Vector2(14, 0) * k, KILL, 2.6 * k, true)
			_dagger(c, mid + Vector2(10, 0) * k, Vector2(1, 0), k * 0.8, STEEL)
		# Martial Utility.
		"pintheshadow":
			c.draw_set_transform(mid + Vector2(0, 8) * k, 0.0, Vector2(1.0, 0.35))
			c.draw_circle(Vector2.ZERO, 13.0 * k, Color(SHADE, 0.95))
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			c.draw_circle(mid + Vector2(0, -8) * k, 3.5 * k, SKIN)
			c.draw_line(mid + Vector2(0, -4) * k, mid + Vector2(0, 6) * k, SKIN, 3.0 * k, true)
			_dagger(c, mid + Vector2(7, 4) * k, Vector2(0, 1), k * 0.8, STEEL)
		"overtheshoulder":
			c.draw_circle(mid + Vector2(0, 8) * k, 6.0 * k, SHADE)
			c.draw_arc(mid + Vector2(0, 6) * k, 13.0 * k, PI * 1.05, PI * 1.95, 16, STEEL, 2.2 * k, true)
			c.draw_circle(mid + Vector2(-12, 4) * k, 2.4 * k, SKIN)
			c.draw_circle(mid + Vector2(12, 4) * k, 2.4 * k, SKIN)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(10, -3), Vector2(15, 0), Vector2(10, 3)]), GOLD)
		"playdead":
			c.draw_line(mid + Vector2(-12, 6) * k, mid + Vector2(10, 6) * k, SHADE, 5.0 * k, true)
			c.draw_circle(mid + Vector2(13, 5) * k, 3.4 * k, SKIN)
			for i in 3:
				c.draw_line(mid + Vector2(4 + i * 4, -6 - i * 3) * k, mid + Vector2(7 + i * 4, -6 - i * 3) * k, Color(STEEL, 0.9), 1.6 * k, true)
			c.draw_line(mid + Vector2(-14, 10) * k, mid + Vector2(16, 10) * k, Color(STEEL, 0.4), 1.2 * k, true)
		"stonethrow":
			# A stone flying in on an arc, striking a raised fist aside.
			c.draw_arc(mid + Vector2(-4, 10) * k, 14.0 * k, -PI * 0.95, -PI * 0.35, 12, Color(STEEL, 0.5), 1.4 * k, true)
			c.draw_circle(mid + Vector2(5, -3) * k, 4.6 * k, Color(0.55, 0.52, 0.5))
			c.draw_circle(mid + Vector2(4, -4) * k, 2.0 * k, Color(0.72, 0.7, 0.68))
			c.draw_circle(mid + Vector2(12, 4) * k, 4.0 * k, SKIN)
			c.draw_line(mid + Vector2(12, 8) * k, mid + Vector2(14, 15) * k, SKIN, 3.0 * k, true)
			for i in 3:
				var a := -PI * 0.15 + i * 0.35
				c.draw_line(mid + Vector2(8, 0) * k + Vector2(cos(a), sin(a)) * 3.0 * k,
					mid + Vector2(8, 0) * k + Vector2(cos(a), sin(a)) * 7.0 * k, GOLD, 1.4 * k, true)

static func _glow(c: Control, mid: Vector2, k: float, col: Color) -> void:
	c.draw_circle(mid, 15.0 * k, Color(col, 0.14))

## A dagger at `at`, its point toward `dir`.
static func _dagger(c: Control, at: Vector2, dir: Vector2, k: float, col: Color) -> void:
	var d := dir.normalized()
	var side := d.orthogonal()
	var tip := at + d * 11.0 * k
	var base := at - d * 2.0 * k
	c.draw_colored_polygon(PackedVector2Array([tip, base + side * 2.4 * k, base - side * 2.4 * k]), col)
	c.draw_line(base + side * 4.0 * k, base - side * 4.0 * k, GOLD, 1.6 * k, true)
	c.draw_line(base, base - d * 6.0 * k, HILT, 2.4 * k, true)

static func _pts(mid: Vector2, k: float, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(mid + p * k)
	return out
