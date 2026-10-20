extends RefCounted

# Icons of the Martial archer, Sharpshooter (abilities.gd draws them through draw()).
# The engine shots are steel arrows on a blue (refill) glow; gold is Overcut and the
# Streak. Loose is a plain grey arrow: no glow, nothing to feed.
# Usage: const SharpshooterIcons = preload("res://scripts/ui/sharpshooter_icons.gd")

const STEEL := Color(0.86, 0.9, 0.96)
const WOOD := Color(0.62, 0.42, 0.24)
const FLETCH := Color(0.95, 0.95, 0.9)
const REFILL := Color(0.42, 0.72, 1.0)
const GOLD := Color(1.0, 0.83, 0.3)
const DIM := Color(0.6, 0.62, 0.68)

static func draw(c: Control, id: String, mid: Vector2, k: float) -> void:
	match id:
		"quickshot":
			_glow(c, mid, k, REFILL)
			_arrow(c, mid + Vector2(-12, 6) * k, mid + Vector2(12, -6) * k, k, STEEL)
			for i in 2:
				c.draw_line(mid + Vector2(-16, -2 + i * 6) * k, mid + Vector2(-9, -5 + i * 6) * k, Color(REFILL, 0.7), 1.4 * k, true)
		"pierce":
			_glow(c, mid, k, REFILL)
			for x: float in [-6.0, 4.0]:
				c.draw_circle(mid + Vector2(x, 0) * k, 4.5 * k, Color(0.25, 0.22, 0.3))
			_arrow(c, mid + Vector2(-16, 0) * k, mid + Vector2(16, 0) * k, k, STEEL)
		"spread":
			_glow(c, mid, k, REFILL)
			for a: float in [-0.45, 0.0, 0.45]:
				var d := Vector2(cos(a - PI * 0.5), sin(a - PI * 0.5))
				_arrow(c, mid + Vector2(0, 12) * k, mid + Vector2(0, 12) * k + d * 26.0 * k, k * 0.8, STEEL)
		"heavydraw":
			_glow(c, mid, k, REFILL)
			c.draw_arc(mid + Vector2(6, 0) * k, 14.0 * k, PI * 0.62, PI * 1.38, 16, WOOD, 2.6 * k, true)
			var top := mid + Vector2(6, 0) * k + Vector2(cos(PI * 0.62), sin(PI * 0.62)) * 14.0 * k
			var bot := mid + Vector2(6, 0) * k + Vector2(cos(PI * 1.38), sin(PI * 1.38)) * 14.0 * k
			var nock := mid + Vector2(12, 0) * k
			c.draw_line(top, nock, FLETCH, 1.2 * k, true)
			c.draw_line(bot, nock, FLETCH, 1.2 * k, true)
			_arrow(c, nock, mid + Vector2(-16, 0) * k, k, STEEL)
		"followup":
			_glow(c, mid, k, REFILL)
			_arrow(c, mid + Vector2(-12, 2) * k, mid + Vector2(12, -10) * k, k * 0.85, STEEL)
			_arrow(c, mid + Vector2(-12, 12) * k, mid + Vector2(12, 0) * k, k * 0.85, STEEL)
			c.draw_arc(mid + Vector2(-4, 8) * k, 9.0 * k, PI * 0.6, PI * 1.4, 10, Color(REFILL, 0.85), 1.6 * k, true)
		"loose":
			_arrow(c, mid + Vector2(-14, 10) * k, mid + Vector2(14, -10) * k, k, DIM)
		"breathe":
			c.draw_circle(mid, 15.0 * k, Color(REFILL, 0.14))
			for i in 3:
				var r := (5.0 + i * 4.0) * k
				c.draw_arc(mid + Vector2(-6, 0) * k, r, -PI * 0.35, PI * 0.35, 10, Color(FLETCH, 0.9 - i * 0.25), 1.6 * k, true)
			c.draw_circle(mid + Vector2(-8, 0) * k, 2.4 * k, GOLD)
		"fasthands":
			c.draw_circle(mid, 15.0 * k, Color(GOLD, 0.16))
			c.draw_arc(mid, 12.0 * k, -PI * 0.5, PI * 1.2, 20, GOLD, 2.2 * k, true)
			var tip := mid + Vector2(cos(PI * 1.2), sin(PI * 1.2)) * 12.0 * k
			c.draw_colored_polygon(PackedVector2Array([tip + Vector2(-4, -2) * k, tip + Vector2(4, -3) * k, tip + Vector2(0, 4) * k]), GOLD)
			_arrow(c, mid + Vector2(-7, 7) * k, mid + Vector2(7, -7) * k, k * 0.7, STEEL)

static func _glow(c: Control, mid: Vector2, k: float, col: Color) -> void:
	c.draw_circle(mid, 15.0 * k, Color(col, 0.16))

## An arrow from `tail` to `head`: shaft, steel head, white fletching.
static func _arrow(c: Control, tail: Vector2, head: Vector2, k: float, tip: Color) -> void:
	var d := (head - tail).normalized()
	var n := d.orthogonal()
	c.draw_line(tail, head - d * 4.0 * k, WOOD, 1.8 * k, true)
	c.draw_colored_polygon(PackedVector2Array([head, head - d * 6.0 * k + n * 3.2 * k, head - d * 6.0 * k - n * 3.2 * k]), tip)
	for s: float in [-1.0, 1.0]:
		c.draw_line(tail + d * 4.0 * k, tail - n * s * 3.5 * k, FLETCH, 1.4 * k, true)
