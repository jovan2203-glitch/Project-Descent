extends RefCounted

# Icons of the Martial tank, the Brawler (abilities.gd draws them through draw()):
# the three strikes, Catch, the other buttons and the chain's nine moves. Each
# strike keeps its own colour, the same as its orb on your back
# (scripts/brawler_orbs.gd): Punch red, Kick green, Elbow blue, Catch white. A move
# is drawn in the colour of the strike that ends its chain.
# Usage: const BrawlerIcons = preload("res://scripts/ui/brawler_icons.gd")

const PUNCH := Color(1.0, 0.32, 0.28)
const KICK := Color(0.38, 0.95, 0.45)
const ELBOW := Color(0.4, 0.62, 1.0)
const CATCH := Color(0.97, 0.97, 1.0)
const GOLD := Color(1.0, 0.83, 0.3)
const WRAP := Color(0.93, 0.88, 0.78)
const SKIN := Color(0.86, 0.66, 0.5)
## Strike id -> its colour (the orbs and the chain strip use these too).
const COLORS := {"punch": PUNCH, "brawlkick": KICK, "elbow": ELBOW, "catch": CATCH}

static func draw(c: Control, id: String, mid: Vector2, k: float) -> void:
	match id:
		# The strikes.
		"punch":
			_glow(c, mid, k, PUNCH)
			_fist(c, mid + Vector2(2, 0) * k, k, PUNCH)
			for y in [-6.0, 0.0, 6.0]:
				c.draw_line(mid + Vector2(-17, y) * k, mid + Vector2(-9, y) * k, Color(PUNCH, 0.8), 1.8 * k, true)
		"brawlkick":
			_glow(c, mid, k, KICK)
			_leg(c, mid, k, KICK)
		"elbow":
			_glow(c, mid, k, ELBOW)
			_arm(c, mid, k, ELBOW)
		"catch":
			_glow(c, mid, k, CATCH)
			_open_hand(c, mid + Vector2(0, 3) * k, k)
			c.draw_arc(mid + Vector2(0, -4) * k, 13.0 * k, -PI * 0.9, -PI * 0.1, 12, Color(GOLD, 0.9), 2.0 * k, true)
		# The other buttons.
		"onemore":
			_orbs(c, mid + Vector2(0, -9) * k, k, [PUNCH, KICK, ELBOW])
			c.draw_arc(mid + Vector2(0, 4) * k, 9.0 * k, -PI * 0.2, PI * 1.4, 18, GOLD, 2.6 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(7, -3), Vector2(13, 3), Vector2(5, 5)]), GOLD)
		"toughitout":
			_shield_body(c, mid, k)
			for i in 3:
				c.draw_circle(mid + Vector2(-6 + i * 6, 3) * k, 2.2 * k, Color(0.55, 0.3, 0.6))
			c.draw_line(mid + Vector2(-9, -3) * k, mid + Vector2(9, -3) * k, Color(GOLD, 0.9), 2.0 * k, true)
		"comeon":
			_open_hand(c, mid + Vector2(-2, 2) * k, k)
			for i in 3:
				c.draw_arc(mid + Vector2(6, -6) * k, (5.0 + i * 4.0) * k, -PI * 0.25, PI * 0.25, 6, Color(WRAP, 0.85 - i * 0.2), 1.8 * k, true)
		"fightingstyle":
			_fist(c, mid + Vector2(-6, 2) * k, k * 0.8, WRAP)
			c.draw_line(mid + Vector2(4, 14) * k, mid + Vector2(12, -14) * k, Color(0.75, 0.78, 0.85), 3.0 * k, true)
			c.draw_line(mid + Vector2(2, 6) * k, mid + Vector2(12, 9) * k, Color(0.55, 0.4, 0.28), 2.6 * k, true)
			c.draw_arc(mid, 16.0 * k, PI * 0.15, PI * 0.85, 10, Color(GOLD, 0.7), 1.6 * k, true)
		"putemup":   # two fists raised in a guard over a purple bruise
			_glow(c, mid, k, Color(0.6, 0.35, 0.7))
			c.draw_circle(mid + Vector2(0, 9) * k, 6.0 * k, Color(0.6, 0.35, 0.7, 0.85))
			_fist(c, mid + Vector2(-7, -4) * k, k * 0.75, PUNCH)
			_fist(c, mid + Vector2(7, -4) * k, k * 0.75, ELBOW)
			c.draw_arc(mid + Vector2(0, -2) * k, 16.0 * k, -PI * 0.85, -PI * 0.15, 12, Color(GOLD, 0.8), 1.8 * k, true)
		# Chains that end with Punch.
		"rapidfists":
			for i in 3:
				_fist(c, mid + Vector2(-8 + i * 7, -6 + i * 6) * k, k * 0.6, PUNCH)
		"haymaker":
			_glow(c, mid, k, GOLD)
			_fist(c, mid + Vector2(4, 2) * k, k * 1.15, PUNCH)
			c.draw_arc(mid + Vector2(4, 2) * k, 15.0 * k, PI * 0.6, PI * 1.35, 12, GOLD, 2.6 * k, true)
		# Chains that end with Kick.
		"sweep":
			c.draw_arc(mid, 13.0 * k, 0.0, PI, 16, KICK, 3.0 * k, true)
			c.draw_line(mid + Vector2(-17, 10) * k, mid + Vector2(17, 10) * k, Color(WRAP, 0.6), 1.6 * k, true)
			_leg(c, mid + Vector2(0, -3) * k, k * 0.7, KICK)
		"roundhouse":
			_glow(c, mid, k, GOLD)
			c.draw_arc(mid, 14.0 * k, 0.0, TAU * 0.85, 24, KICK, 3.0 * k, true)
			c.draw_arc(mid, 9.0 * k, PI, TAU * 1.3, 18, Color(GOLD, 0.9), 2.0 * k, true)
			_leg(c, mid, k * 0.6, KICK)
		# Chains that end with Elbow.
		"clinch":
			_arm(c, mid + Vector2(-3, 0) * k, k * 0.8, ELBOW)
			_arm(c, mid + Vector2(3, 0) * k, k * -0.8, ELBOW)
		"shakeoff":
			_glow(c, mid, k, GOLD)
			for i in 4:
				var a := TAU * i / 4.0 + 0.4
				c.draw_circle(mid + Vector2(cos(a), sin(a)) * 11.0 * k, 2.6 * k, Color(0.55, 0.3, 0.6))
			_arm(c, mid, k * 0.7, ELBOW)
		# Chains that start with Catch.
		"turnitaround":
			_open_hand(c, mid + Vector2(-4, 3) * k, k * 0.8)
			c.draw_arc(mid, 13.0 * k, -PI * 0.1, PI * 1.1, 16, PUNCH, 2.6 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-15, 2), Vector2(-9, -4), Vector2(-9, 6)]), PUNCH)
		"throw":
			_open_hand(c, mid + Vector2(-7, 6) * k, k * 0.7)
			c.draw_arc(mid + Vector2(2, 6) * k, 13.0 * k, -PI, -PI * 0.15, 14, KICK, 2.6 * k, true)
			c.draw_circle(mid + Vector2(13, 0) * k, 4.0 * k, KICK)
		"takedown":
			c.draw_line(mid + Vector2(-16, 12) * k, mid + Vector2(16, 12) * k, WRAP, 2.4 * k, true)
			c.draw_colored_polygon(_pts(mid, k, [Vector2(-13, 9), Vector2(11, 6), Vector2(11, 10), Vector2(-13, 11)]), ELBOW)
			_arm(c, mid + Vector2(0, -6) * k, k * 0.7, ELBOW)

## A soft glow behind the picture.
static func _glow(c: Control, mid: Vector2, k: float, col: Color) -> void:
	c.draw_circle(mid, 15.0 * k, Color(col, 0.16))

## A wrapped fist (k may be negative to mirror it).
static func _fist(c: Control, at: Vector2, k: float, col: Color) -> void:
	var s := absf(k)
	c.draw_rect(Rect2(at + Vector2(-7, -6) * s, Vector2(14, 12) * s), WRAP)
	for i in 4:
		c.draw_circle(at + Vector2(-5 + i * 3.4, -6) * s, 1.8 * s, SKIN)
	c.draw_rect(Rect2(at + Vector2(-7, -6) * s, Vector2(14, 12) * s), col, false, 1.6 * s)
	c.draw_line(at + Vector2(-7, 1) * s, at + Vector2(7, 1) * s, Color(col, 0.7), 1.2 * s, true)

## A kicking leg: hip, knee, shin out to the side, foot.
static func _leg(c: Control, mid: Vector2, k: float, col: Color) -> void:
	var s := absf(k)
	c.draw_line(mid + Vector2(-10, 12) * s, mid + Vector2(-3, -2) * s, WRAP, 4.0 * s, true)
	c.draw_line(mid + Vector2(-3, -2) * s, mid + Vector2(12, -8) * s, col, 4.0 * s, true)
	c.draw_circle(mid + Vector2(13, -8) * s, 3.0 * s, col)

## A bent arm with the elbow out (k < 0 mirrors it).
static func _arm(c: Control, mid: Vector2, k: float, col: Color) -> void:
	var f := 1.0 if k >= 0.0 else -1.0
	var s := absf(k)
	c.draw_line(mid + Vector2(-10 * f, -10) * s, mid + Vector2(6 * f, 2) * s, WRAP, 4.0 * s, true)
	c.draw_line(mid + Vector2(6 * f, 2) * s, mid + Vector2(-6 * f, 12) * s, col, 4.0 * s, true)
	c.draw_circle(mid + Vector2(6 * f, 2) * s, 3.2 * s, col)

## An open hand, fingers up.
static func _open_hand(c: Control, at: Vector2, k: float) -> void:
	c.draw_rect(Rect2(at + Vector2(-6, -2) * k, Vector2(12, 10) * k), WRAP)
	for i in 4:
		c.draw_line(at + Vector2(-4.5 + i * 3, -2) * k, at + Vector2(-4.5 + i * 3, -11) * k, WRAP, 2.4 * k, true)
	c.draw_line(at + Vector2(6, 2) * k, at + Vector2(10, -4) * k, WRAP, 2.4 * k, true)

## Three orbs in a row.
static func _orbs(c: Control, at: Vector2, k: float, cols: Array) -> void:
	for i in cols.size():
		c.draw_circle(at + Vector2(-7 + i * 7, 0) * k, 3.0 * k, cols[i])

## A body braced behind crossed forearms.
static func _shield_body(c: Control, mid: Vector2, k: float) -> void:
	c.draw_circle(mid + Vector2(0, -10) * k, 4.0 * k, SKIN)
	c.draw_rect(Rect2(mid + Vector2(-9, -5) * k, Vector2(18, 18) * k), Color(WRAP, 0.9))
	c.draw_line(mid + Vector2(-10, -6) * k, mid + Vector2(10, 8) * k, ELBOW, 3.0 * k, true)
	c.draw_line(mid + Vector2(10, -6) * k, mid + Vector2(-10, 8) * k, PUNCH, 3.0 * k, true)

static func _pts(mid: Vector2, k: float, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(mid + p * k)
	return out
