extends RefCounted

# Icons of the Martial warrior's Wheel (abilities.gd draws them through draw()):
# the four weapons, the four bar buttons and each weapon's four moves. Every
# weapon keeps its own colour, the same one it glows with on your back
# (scripts/weapon_wheel.gd), so a button shows at a glance which weapon it is.
# Usage: const WheelIcons = preload("res://scripts/ui/wheel_icons.gd")

const AXE := Color(0.95, 0.36, 0.3)
const SWORD := Color(0.78, 0.9, 1.0)
const HALBERD := Color(0.42, 0.95, 0.52)
const MAUL := Color(1.0, 0.7, 0.26)
const HAFT := Color(0.55, 0.4, 0.28)
const WHITE := Color(0.96, 0.96, 1.0)
## Weapon id -> its colour (the Wheel picture uses these too).
const COLORS := {"wheelgreataxe": AXE, "wheelgreatsword": SWORD, "wheelhalberd": HALBERD, "wheelmaul": MAUL}

static func draw(c: Control, id: String, mid: Vector2, k: float) -> void:
	match id:
		# The weapons: each upright, glowing.
		"wheelgreataxe":
			_glow(c, mid, k, AXE)
			_axe(c, mid, k, 0.0, AXE)
		"wheelgreatsword":
			_glow(c, mid, k, SWORD)
			_sword(c, mid, k, 0.0, SWORD)
		"wheelhalberd":
			_glow(c, mid, k, HALBERD)
			_halberd(c, mid, k, 0.0, HALBERD)
		"wheelmaul":
			_glow(c, mid, k, MAUL)
			_maul(c, mid, k, 0.0, MAUL)
		# The bar buttons: the four colours in a ring, and what kind of move it is.
		"quickswing":
			_ring(c, mid, k)
			c.draw_arc(mid, 8.0 * k, -PI * 0.8, -PI * 0.2, 10, WHITE, 2.4 * k, true)
		"fullswing":
			_ring(c, mid, k)
			c.draw_arc(mid, 8.0 * k, -PI * 1.0, PI * 0.1, 16, WHITE, 3.6 * k, true)
			c.draw_circle(mid + Vector2(8, 1) * k, 2.2 * k, WHITE)
		"weaponart":
			_ring(c, mid, k)
			_star(c, mid, 7.0 * k, WHITE)
		"wheelbreak":
			_ring(c, mid, k)
			for i in 5:
				var a := TAU * i / 5.0 + 0.3
				c.draw_colored_polygon(_shard(mid + Vector2(cos(a), sin(a)) * 5.0 * k, a, k * 0.8), WHITE)
		# Greataxe
		"hack":
			_axe(c, mid + Vector2(-2, 2) * k, k, -0.6, AXE)
			c.draw_arc(mid + Vector2(2, 0) * k, 14.0 * k, -PI * 0.55, -PI * 0.05, 10, Color(WHITE, 0.8), 1.8 * k, true)
		"chop":
			_axe(c, mid + Vector2(0, 1) * k, k, 0.0, AXE)
			for x in [-10.0, 0.0, 10.0]:
				c.draw_line(mid + Vector2(x, 13) * k, mid + Vector2(x * 1.3, 17) * k, WHITE, 1.6 * k, true)
		"rush":
			_axe(c, mid + Vector2(5, 3) * k, k, PI * 0.5, AXE)
			for y in [-8.0, 0.0, 8.0]:
				c.draw_line(mid + Vector2(-17, y) * k, mid + Vector2(-6, y) * k, Color(WHITE, 0.75), 1.8 * k, true)
		"shrapnel":
			c.draw_circle(mid, 4.0 * k, AXE)
			for i in 8:
				var a := TAU * i / 8.0
				c.draw_colored_polygon(_shard(mid + Vector2(cos(a), sin(a)) * 11.0 * k, a, k), AXE.lightened(0.2))
		# Greatsword
		"slash":
			_sword(c, mid, k, 0.7, SWORD)
			c.draw_arc(mid, 14.0 * k, PI * 0.9, PI * 1.5, 10, Color(WHITE, 0.8), 1.8 * k, true)
		"lunge":
			_sword(c, mid + Vector2(2, 0) * k, k, PI * 0.5, SWORD)
			for y in [-5.0, 5.0]:
				c.draw_line(mid + Vector2(-17, y) * k, mid + Vector2(-9, y) * k, Color(WHITE, 0.7), 1.6 * k, true)
		"bladeguard":
			c.draw_arc(mid + Vector2(0, 4) * k, 15.0 * k, PI * 1.1, PI * 1.9, 14, Color(SWORD, 0.7), 3.0 * k, true)
			_sword(c, mid, k, 0.0, SWORD)
		"shardlance":
			for i in 6:
				var a := PI * 0.75 + (i - 2.5) * 0.22
				var from := mid + Vector2(cos(a), sin(a)) * 16.0 * k
				c.draw_colored_polygon(_shard(from, a + PI, k * 0.9), SWORD)
			c.draw_circle(mid + Vector2(6, -6) * k, 3.4 * k, WHITE)
		# Halberd
		"jab":
			_halberd(c, mid, k, 0.6, HALBERD)
			c.draw_arc(mid + Vector2(0, 2) * k, 15.0 * k, -PI * 0.75, -PI * 0.05, 12, Color(WHITE, 0.8), 1.8 * k, true)
		"hook":
			_halberd(c, mid, k, -0.6, HALBERD)
			c.draw_arc(mid + Vector2(-8, -6) * k, 6.0 * k, PI * 0.2, PI * 1.3, 10, WHITE, 2.2 * k, true)
		"dragin":
			_halberd(c, mid + Vector2(4, 2) * k, k, PI * 0.5, HALBERD)
			c.draw_circle(mid + Vector2(-13, -6) * k, 3.2 * k, WHITE)
			c.draw_line(mid + Vector2(-13, -2) * k, mid + Vector2(-13, 6) * k, WHITE, 2.4 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-3, 10), Vector2(3, 13), Vector2(-3, 16)]), HALBERD.lightened(0.3))
		"flyinghead":
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-14, 4), Vector2(-6, -2), Vector2(-4, 8)]), HALBERD)
			for i in 4:
				c.draw_circle(mid + Vector2(-2 + i * 5, -3 - sin(i * 1.6) * 6.0) * k, 1.6 * k, Color(WHITE, 0.85))
			c.draw_circle(mid + Vector2(16, -2) * k, 2.4 * k, HALBERD.lightened(0.3))
		# Maul
		"thud":
			_maul(c, mid + Vector2(0, -2) * k, k, 0.5, MAUL)
			_star(c, mid + Vector2(9, 11) * k, 4.0 * k, WHITE)
		"crush":
			_maul(c, mid + Vector2(0, -3) * k, k, 0.0, MAUL)
			for v in [Vector2(-14, 16), Vector2(-5, 17), Vector2(5, 17), Vector2(14, 16)]:
				c.draw_line(mid + Vector2(0, 12) * k, mid + (v as Vector2) * k, WHITE, 1.5 * k, true)
		"earthshake":
			c.draw_line(mid + Vector2(-17, 8) * k, mid + Vector2(17, 8) * k, MAUL.darkened(0.2), 2.6 * k, true)
			c.draw_polyline(_pts(mid, k, [Vector2(-12, 8), Vector2(-6, 4), Vector2(0, 9), Vector2(6, 3), Vector2(12, 8)]), MAUL, 2.0 * k, true)
			for x in [-11.0, 11.0]:
				c.draw_line(mid + Vector2(x - 4, 14) * k, mid + Vector2(x + 4, 14) * k, WHITE, 2.4 * k, true)   # knocked flat
				c.draw_circle(mid + Vector2(x + 6, 13) * k, 1.8 * k, WHITE)
			_maul(c, mid + Vector2(0, -8) * k, k * 0.7, 0.0, MAUL)
		"faultline":
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-12, 14), Vector2(12, 14), Vector2(4, -14), Vector2(-4, -14)]), Color(MAUL, 0.35))
			c.draw_polyline(_pts(mid, k, [Vector2(0, 14), Vector2(-2, 6), Vector2(2, -2), Vector2(-1, -9), Vector2(1, -15)]), MAUL.lightened(0.3), 2.2 * k, true)
			c.draw_line(mid + Vector2(-2, 6) * k, mid + Vector2(-7, 2) * k, MAUL, 1.6 * k, true)
			c.draw_line(mid + Vector2(2, -2) * k, mid + Vector2(7, -5) * k, MAUL, 1.6 * k, true)

# --- Shapes (around `at`, turned by `angle`, sized by `k`) ---------------------------

static func _pts(mid: Vector2, k: float, raw: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in raw:
		out.append(mid + (p as Vector2) * k)
	return out

## `raw` points turned by `angle` around `at`.
static func _turned(at: Vector2, k: float, angle: float, raw: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in raw:
		out.append(at + (p as Vector2).rotated(angle) * k)
	return out

static func _haft(c: Control, at: Vector2, k: float, angle: float, from: float, to: float) -> void:
	c.draw_line(at + Vector2(0, from).rotated(angle) * k, at + Vector2(0, to).rotated(angle) * k, HAFT, 2.6 * k, true)

static func _axe(c: Control, at: Vector2, k: float, angle: float, col: Color) -> void:
	_haft(c, at, k, angle, 16, -14)
	c.draw_colored_polygon(_turned(at, k, angle, [Vector2(0, -13), Vector2(11, -17), Vector2(13, -7), Vector2(11, 2), Vector2(0, -3)]), col)
	c.draw_polyline(_turned(at, k, angle, [Vector2(11, -17), Vector2(13, -7), Vector2(11, 2)]), col.lightened(0.5), 1.4 * k, true)

static func _sword(c: Control, at: Vector2, k: float, angle: float, col: Color) -> void:
	c.draw_colored_polygon(_turned(at, k, angle, [Vector2(-2.5, 8), Vector2(2.5, 8), Vector2(2.5, -12), Vector2(0, -17), Vector2(-2.5, -12)]), col)
	c.draw_line(at + Vector2(-7, 8).rotated(angle) * k, at + Vector2(7, 8).rotated(angle) * k, col.darkened(0.3), 2.4 * k, true)
	_haft(c, at, k, angle, 9, 16)
	c.draw_line(at + Vector2(0, 6).rotated(angle) * k, at + Vector2(0, -14).rotated(angle) * k, Color(WHITE, 0.7), 0.9 * k, true)

static func _halberd(c: Control, at: Vector2, k: float, angle: float, col: Color) -> void:
	_haft(c, at, k, angle, 17, -12)
	c.draw_colored_polygon(_turned(at, k, angle, [Vector2(0, -12), Vector2(9, -14), Vector2(10, -6), Vector2(0, -6)]), col)   # blade
	c.draw_colored_polygon(_turned(at, k, angle, [Vector2(0, -12), Vector2(-6, -11), Vector2(-8, -15), Vector2(0, -9)]), col.darkened(0.15))   # hook
	c.draw_colored_polygon(_turned(at, k, angle, [Vector2(-1.5, -12), Vector2(1.5, -12), Vector2(0, -19)]), col.lightened(0.3))   # spike

static func _maul(c: Control, at: Vector2, k: float, angle: float, col: Color) -> void:
	_haft(c, at, k, angle, 16, -8)
	c.draw_colored_polygon(_turned(at, k, angle, [Vector2(-10, -16), Vector2(10, -16), Vector2(10, -6), Vector2(-10, -6)]), col)
	c.draw_line(at + Vector2(-10, -11).rotated(angle) * k, at + Vector2(10, -11).rotated(angle) * k, col.lightened(0.4), 1.2 * k, true)

static func _glow(c: Control, at: Vector2, k: float, col: Color) -> void:
	c.draw_circle(at, 17.0 * k, Color(col, 0.12))
	c.draw_circle(at, 12.0 * k, Color(col, 0.12))

## The four weapons' colours in a ring (the bar buttons).
static func _ring(c: Control, at: Vector2, k: float) -> void:
	var cols := [AXE, SWORD, HALBERD, MAUL]
	for i in 4:
		var a := -PI * 0.5 + TAU * i / 4.0
		c.draw_circle(at + Vector2(cos(a), sin(a)) * 15.0 * k, 3.0 * k, cols[i])

static func _shard(at: Vector2, angle: float, k: float) -> PackedVector2Array:
	return _turned(at, k, angle + PI * 0.5, [Vector2(0, -4), Vector2(2, 1), Vector2(-2, 1)])

static func _star(c: Control, at: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := -PI * 0.5 + TAU * i / 8.0
		pts.append(at + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.4))
	c.draw_colored_polygon(pts, col)
