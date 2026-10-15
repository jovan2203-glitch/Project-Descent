@tool
extends Node3D

# The Breach (Shadow caster; "decay" in the code): what it looks like. Only a
# picture - the rules are in player.gd ("Shadow caster: Decay").
# (@tool only so tests/test_breach_fx.gd can build one inside the editor.)
#
# On an enemy: a hole in the ground under it, and hands on long arms clawing up
# out of the hole at its body. The more damage is in the Breach, the higher up
# the body they reach (reach()). While the Breach is open the rim of the hole
# glows; closed, the hole is narrower and its rim is dull.
# The enemy makes it from its own debuffs (sync(), called when they change), and
# the picture then reads them itself, so every machine in a party shows it - and
# it adds up everyone's Breach on that enemy. It goes when the debuffs do.
#
# burst(): the same hands as a one-off, for a spell landing (Break Ground,
# Gnaw, Call Due, Many Hands ...). They shoot up out of the ground, claw, and
# sink again.
# Usage: const BreachFx = preload("res://scripts/breach_fx.gd")

const Combat = preload("res://scripts/combat_utils.gd")
const Stats = preload("res://scripts/core/stats.gd")
const Balance = preload("res://scripts/balance.gd")

const NODE_NAME := "BreachFx"
## The two debuffs a Breach shows itself with (open, closed).
const OPEN_ID := "decay"
const CLOSED_ID := "decay_closed"

const DARK := Color(0.03, 0.0, 0.06)
const RIM_OPEN := Color(0.66, 0.36, 0.95)
const RIM_CLOSED := Color(0.36, 0.3, 0.44)
const ARM := Color(0.2, 0.1, 0.3)
const ARM_GLOW := Color(0.45, 0.2, 0.7)
const CLAW := Color(0.78, 0.62, 0.96)

## Seconds between two looks at the enemy's debuffs.
const POLL := 0.12
const APPEAR_TIME := 0.35
const VANISH_TIME := 0.4
## Share of the enemy's height the hands reach with next to nothing in the
## Breach, and with all it can show (a little over the head).
const LOW := 0.22
const HIGH := 1.12
## How wide the hole is, in body widths (and never narrower than MIN_RADIUS).
const HOLE_WIDTH := 1.7
const MIN_RADIUS := 0.55
## A closed hole is this much of an open one.
const CLOSED_SIZE := 0.72
## A burst: seconds its hands take to come up, stay, and sink.
const BURST_RISE := 0.12
const BURST_HOLD := 0.4
const BURST_SINK := 0.28
## A burst wider than this is a field of hands (Many Hands), not one hole.
const FIELD_RADIUS := 1.6

# --- A burst's settings (set by burst() before it is added to the scene) ------------
var burst_mode := false
var burst_radius := 0.7
var burst_count := 4
var burst_height := 1.0

var _built := false
var _hole: MeshInstance3D
var _rim: MeshInstance3D
var _hole_mat: StandardMaterial3D
var _rim_mat: StandardMaterial3D
## One entry per arm: {"lean": Node3D, "fore": MeshInstance3D, "wrist": Node3D,
## "th": thickness, "dist": metres from the middle, "phase", "speed", "tall"}
var _arms: Array = []
var _body := {"feet": -0.9, "height": 1.8, "radius": 0.4}
var _radius := 0.7
var _t := 0.0
var _poll_left := 0.0
var _grow := 0.0        # 0 = nothing out of the ground yet, 1 = all the way
var _reach := 0.0       # how far up the body the hands are (0-1), following _target
var _target := 0.0
var _open := true
var _hole_k := 1.0
var _gone := false

# --- What the rules ask of it (all static) ---------------------------------------------

## The Breach(es) on an enemy, read from its debuffs: {"on": is there one,
## "open": is any of them open, "amount": the damage left in all of them}.
static func read(status: Node) -> Dictionary:
	var out := {"on": false, "open": false, "amount": 0.0}
	if status == null or not is_instance_valid(status):
		return out
	var effects: Variant = status.get("effects")
	if not (effects is Dictionary):
		return out
	for e in (effects as Dictionary).values():
		if not (e is Dictionary):
			continue
		var res: Variant = (e as Dictionary).get("res")
		if not (res is Resource):
			continue
		var id := str((res as Resource).get("id"))
		if id != OPEN_ID and id != CLOSED_ID:
			continue
		out["on"] = true
		out["amount"] = float(out["amount"]) + float((e as Dictionary).get("stacks", 0))
		if id == OPEN_ID:
			out["open"] = true
	return out

## How far up the body the hands reach (0 = just out of the hole, 1 = over its
## head) with `amount` damage in the Breach of an enemy with `max_health` at
## `level`. Full reach: BREACH_FX_FULL_HITS standard hits of that level, or the
## enemy's whole health if that is less.
static func reach(amount: float, max_health: float, level: int) -> float:
	var full: float = Balance.BREACH_FX_FULL_HITS * Stats.level_hit(level)
	if max_health > 0.0:
		full = minf(full, max_health)
	return clampf(maxf(amount, 0.0) / maxf(full, 1.0), 0.0, 1.0)

## Share of the body's height the hands reach at `at` (0-1, see reach()).
static func arm_share(at: float) -> float:
	return lerpf(LOW, HIGH, clampf(at, 0.0, 1.0))

## The body the picture is fitted to, from its collision shape: {"feet": height
## of its feet (its origin is its middle), "height": how tall, "radius": how wide}.
static func body_of(body: Node) -> Dictionary:
	var out := {"feet": -0.9, "height": 1.8, "radius": 0.4}
	var cs := Combat._shape_node(body)
	if cs == null:
		return out
	var s: Shape3D = cs.shape
	var h := 1.8
	var r := 0.4
	if s is CapsuleShape3D:
		h = (s as CapsuleShape3D).height
		r = (s as CapsuleShape3D).radius
	elif s is CylinderShape3D:
		h = (s as CylinderShape3D).height
		r = (s as CylinderShape3D).radius
	elif s is SphereShape3D:
		r = (s as SphereShape3D).radius
		h = r * 2.0
	elif s is BoxShape3D:
		h = (s as BoxShape3D).size.y
		r = maxf((s as BoxShape3D).size.x, (s as BoxShape3D).size.z) * 0.5
	out["height"] = h * cs.scale.y
	out["radius"] = r * maxf(cs.scale.x, cs.scale.z)
	out["feet"] = cs.position.y - float(out["height"]) * 0.5
	return out

## Where `body` stands: the point on the ground under it.
static func ground_of(body: Node3D) -> Vector3:
	return body.global_position + Vector3(0.0, float(body_of(body)["feet"]), 0.0)

## Radius of the hole under a body `radius` wide.
static func hole_radius(radius: float) -> float:
	return maxf(radius * HOLE_WIDTH, MIN_RADIUS)

## Arms around a hole of `radius`.
static func arm_count(radius: float) -> int:
	return clampi(int(round(radius * 7.0)), 5, 8)

## Thickness of an arm at a hole of `radius` (bigger enemies, thicker arms).
static func thickness(radius: float) -> float:
	return 0.05 * clampf(radius / 0.7, 0.8, 1.8)

## How far out of the ground a burst's hands are `t` seconds in (0-1).
static func burst_grow(t: float) -> float:
	if t <= 0.0:
		return 0.0
	if t < BURST_RISE:
		return 1.0 - pow(1.0 - t / BURST_RISE, 2.0)
	if t < BURST_RISE + BURST_HOLD:
		return 1.0
	return clampf(1.0 - (t - BURST_RISE - BURST_HOLD) / BURST_SINK, 0.0, 1.0)

## Seconds a burst lasts.
static func burst_time() -> float:
	return BURST_RISE + BURST_HOLD + BURST_SINK

## An enemy's debuffs changed: put the picture on it if a Breach is there now.
## (It takes itself away when the Breach is gone.)
static func sync(enemy: Node3D) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return
	if enemy.get_node_or_null(NODE_NAME) != null:
		return
	if not bool(read(enemy.get_node_or_null("Status"))["on"]):
		return
	var n := Node3D.new()
	n.name = NODE_NAME
	n.set_script(load("res://scripts/breach_fx.gd"))
	enemy.add_child(n)

## Hands shoot up out of the ground at `at` (a point on the ground), claw and
## sink again: `count` of them within `radius`, `height` metres tall.
static func burst(scene: Node, at: Vector3, radius: float, count: int, height: float) -> Node3D:
	if scene == null or not is_instance_valid(scene):
		return null
	var n := Node3D.new()
	n.set_script(load("res://scripts/breach_fx.gd"))
	n.burst_mode = true
	n.burst_radius = maxf(radius, 0.35)
	n.burst_count = clampi(count, 1, 24)
	n.burst_height = maxf(height, 0.2)
	scene.add_child(n)
	if n.is_inside_tree():
		n.global_position = at + Vector3(0.0, 0.03, 0.0)
	else:
		n.position = at + Vector3(0.0, 0.03, 0.0)
		n._build()   # (not in a scene that is running: nothing calls _ready)
	return n

# --- Shared meshes and materials (every hole and hand uses the same ones) ---------------

static var _shared := {}

static func _mesh(kind: String) -> Mesh:
	if _shared.has(kind):
		return _shared[kind]
	var m: Mesh = null
	match kind:
		"fore":
			var c := CylinderMesh.new()
			c.top_radius = 0.7
			c.bottom_radius = 1.0
			c.height = 1.0
			c.radial_segments = 6
			c.rings = 1
			m = c
		"finger":
			var f := CylinderMesh.new()
			f.top_radius = 0.08
			f.bottom_radius = 1.0
			f.height = 1.0
			f.radial_segments = 5
			f.rings = 1
			m = f
		"palm":
			var s := SphereMesh.new()
			s.radius = 1.0
			s.height = 2.0
			s.radial_segments = 8
			s.rings = 4
			m = s
		"disc":
			var d := CylinderMesh.new()
			d.top_radius = 1.0
			d.bottom_radius = 1.0
			d.height = 0.02
			d.radial_segments = 32
			d.rings = 1
			m = d
		_:
			var t := TorusMesh.new()
			t.inner_radius = 0.9
			t.outer_radius = 1.0
			t.rings = 32
			t.ring_segments = 4
			m = t
	_shared[kind] = m
	return m

## What the arms (and, `claw`, the fingers) are made of.
static func _arm_mat(claw: bool) -> StandardMaterial3D:
	var key := "mat_claw" if claw else "mat_arm"
	if _shared.has(key):
		return _shared[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = CLAW if claw else ARM
	m.roughness = 0.9
	m.emission_enabled = true
	m.emission = CLAW if claw else ARM_GLOW
	m.emission_energy_multiplier = 1.1 if claw else 0.55
	_shared[key] = m
	return m

# --- Building it ------------------------------------------------------------------------

func _ready() -> void:
	_build()

func _flat_mat(c: Color, glow: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = Color(c.r, c.g, c.b)
		m.emission_energy_multiplier = glow
	return m

func _part(mesh: Mesh, mat: Material, to: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	to.add_child(mi)
	return mi

## A field of hands (a wide burst) has no single hole: only a faint stain.
func _is_field() -> bool:
	return burst_mode and burst_radius > FIELD_RADIUS

func _hole_alpha() -> float:
	return 0.28 if _is_field() else 0.92

## Makes the hole and the arms. (Called by _ready; a test may call it itself.)
func _build() -> void:
	if _built:
		return
	_built = true
	var count := burst_count
	if burst_mode:
		_radius = burst_radius
		_body = {"feet": 0.0, "height": burst_height, "radius": 0.0}
	else:
		_body = body_of(get_parent())
		_radius = hole_radius(float(_body["radius"]))
		position = Vector3(0.0, float(_body["feet"]) + 0.03, 0.0)
		count = arm_count(_radius)
	_hole_mat = _flat_mat(Color(DARK, 0.0), 0.0)
	_hole = _part(_mesh("disc"), _hole_mat, self)
	_hole.scale = Vector3(0.01, 1.0, 0.01)
	_rim_mat = _flat_mat(Color(RIM_OPEN, 0.0), 2.0)
	_rim = _part(_mesh("rim"), _rim_mat, self)
	_rim.position.y = 0.012
	_rim.scale = Vector3(0.01, 0.2, 0.01)
	_rim.visible = not _is_field()
	var th := thickness(minf(_radius, 0.9) if burst_mode else _radius)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in count:
		_arms.append(_make_arm(i, count, th, rng))
	if not burst_mode:
		_look()
	_pose()

## One arm: a forearm that is stretched to its length every frame, and a hand
## with four hooked fingers at the end of it. It stands at the edge of the hole
## and leans in over the middle.
func _make_arm(i: int, n: int, th: float, rng: RandomNumberGenerator) -> Dictionary:
	var a := TAU * i / float(maxi(n, 1)) + rng.randf_range(-0.25, 0.25)
	var dist := _radius * 0.72
	var turn := 0.0
	if burst_mode:
		if n == 1:
			dist = 0.0
		elif _is_field():
			dist = _radius * sqrt(rng.randf_range(0.04, 0.9))   # spread evenly over the area
			turn = rng.randf_range(-PI, PI)
	var pivot := Node3D.new()
	pivot.position = Vector3(cos(a), 0.0, sin(a)) * dist
	pivot.rotation.y = atan2(-cos(a), -sin(a)) + turn   # its +Z looks at the middle
	add_child(pivot)
	var lean := Node3D.new()
	pivot.add_child(lean)
	var fore := _part(_mesh("fore"), _arm_mat(false), lean)
	var wrist := Node3D.new()
	lean.add_child(wrist)
	var palm := _part(_mesh("palm"), _arm_mat(false), wrist)
	palm.position = Vector3(0.0, th * 1.1, 0.0)
	palm.scale = Vector3(th * 1.7, th * 1.5, th * 0.9)
	var finger_len := th * 4.2
	for f in 4:
		var knuckle := Node3D.new()
		knuckle.position = Vector3((f - 1.5) * th * 0.95, th * 2.1, 0.0)
		knuckle.rotation = Vector3(0.75, 0.0, -(f - 1.5) * 0.28)   # hooked forward, spread
		wrist.add_child(knuckle)
		var finger := _part(_mesh("finger"), _arm_mat(true), knuckle)
		finger.position = Vector3(0.0, finger_len * 0.5, 0.0)
		finger.scale = Vector3(th * 0.42, finger_len, th * 0.42)
	return {"lean": lean, "fore": fore, "wrist": wrist, "th": th, "dist": dist,
		"phase": rng.randf() * TAU, "speed": rng.randf_range(2.6, 4.2), "tall": rng.randf_range(0.82, 1.08)}

## How many arms it has.
func arms() -> int:
	return _arms.size()

## How far up the body its hands are right now (0-1), and where they are headed.
func shown_reach() -> float:
	return _reach

func target_reach() -> float:
	return _target

func is_open() -> bool:
	return _open

# --- Every frame ------------------------------------------------------------------------

func _process(delta: float) -> void:
	_advance(delta)

## Look at the enemy's debuffs: is the Breach still there, is it open, how much is in it.
func _look() -> void:
	var holder := get_parent()
	if holder == null or not is_instance_valid(holder):
		_gone = true
		return
	var st := read(holder.get_node_or_null("Status"))
	var alive: bool = not holder.has_method("is_alive") or bool(holder.call("is_alive"))
	_gone = not bool(st["on"]) or not alive
	if _gone:
		return
	_open = bool(st["open"])
	var max_health: Variant = holder.get("max_health")
	var level: int = int(holder.call("combat_level")) if holder.has_method("combat_level") else 1
	_target = reach(float(st["amount"]), float(max_health) if max_health != null else 0.0, level)

## Move everything on by `delta` seconds. (Called by _process; a test may call it itself.)
func _advance(delta: float) -> void:
	if not _built:
		return
	_t += delta
	if burst_mode:
		_grow = burst_grow(_t)
		if _t >= burst_time():
			queue_free()
			return
	else:
		_poll_left -= delta
		if _poll_left <= 0.0:
			_poll_left = POLL
			_look()
		_grow = move_toward(_grow, 0.0 if _gone else 1.0, delta / (VANISH_TIME if _gone else APPEAR_TIME))
		if _gone and _grow <= 0.0:
			queue_free()
			return
		_reach = lerpf(_reach, _target, 1.0 - exp(-delta * 3.0))
		_hole_k = lerpf(_hole_k, 1.0 if _open else CLOSED_SIZE, 1.0 - exp(-delta * 6.0))
	_pose()

## Put the hole and every arm where they are at this moment.
func _pose() -> void:
	var lit := _open or burst_mode
	var r := _radius * _hole_k * maxf(_grow, 0.01)
	_hole.scale = Vector3(r, 1.0, r)
	_hole_mat.albedo_color = Color(DARK, _hole_alpha() * _grow)
	_rim.scale = Vector3(r * 1.04, maxf(r, 0.3) * 0.5, r * 1.04)
	var rim_color := RIM_OPEN if lit else RIM_CLOSED
	_rim_mat.albedo_color = Color(rim_color, 0.9 * _grow)
	_rim_mat.emission = rim_color
	_rim_mat.emission_energy_multiplier = (2.0 + 0.6 * sin(_t * 3.0)) if lit else 0.45
	var top := burst_height if burst_mode else float(_body["height"]) * arm_share(_reach)
	var body_r := float(_body["radius"])
	for arm in _arms:
		var speed: float = arm["speed"]
		var phase: float = arm["phase"]
		var th: float = arm["th"]
		var length := maxf(top * float(arm["tall"]) * _grow * (0.88 + 0.12 * sin(_t * speed + phase + 1.1)), 0.001)
		# It leans in far enough to reach the body, and rakes at it.
		var gap := maxf(float(arm["dist"]) - body_r * 0.5, 0.0)
		var lean := arm["lean"] as Node3D
		lean.rotation.x = clampf(atan2(gap, maxf(length, 0.15)), 0.05, 0.85) + 0.24 * sin(_t * speed + phase)
		var fore := arm["fore"] as MeshInstance3D
		fore.position = Vector3(0.0, length * 0.5, 0.0)
		fore.scale = Vector3(th, length, th)
		var wrist := arm["wrist"] as Node3D
		wrist.position = Vector3(0.0, length, 0.0)
		wrist.rotation.x = 0.3 + 0.6 * (0.5 + 0.5 * sin(_t * speed * 2.0 + phase * 1.7))   # the fingers close and open
		wrist.scale = Vector3.ONE * clampf(_grow * 1.5, 0.05, 1.0)
