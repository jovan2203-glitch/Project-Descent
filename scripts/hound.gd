@tool
extends Node3D

# A Hound (Shadow melee): one of the two demon dogs that fight beside a
# character. Red hide, violet horns and spines, burning eyes. It climbs out of a
# hole in the ground, runs to whatever its owner is fighting (it dashes if that
# is more than a second's run away) and bites at it from the side, comes back to
# heel when there is nothing to bite, and sinks back into the ground when its
# time is up. A third one can join the pair for a while (Slipped Leash).
# Only a picture: the rules are in player.gd ("Shadow melee: the Hounds"). The
# owner's machine tells its own Hounds when a bite or a lunge lands (bite(),
# lunge(), leave()). A party member's Hounds (auto = true) follow that player's
# puppet, bite by themselves and leave when their time is over (Net "hounds" fx).
# The model is built here from simple shapes on a rig of its own: to swap in a
# real model, replace _build(); everything else only moves `_rig`, the head, the
# jaw, the leg pivots and the tail.
# (@tool only so tests/test_hounds.gd can build one inside the editor.)
# Usage: const Hound = preload("res://scripts/hound.gd")

const BreachFx = preload("res://scripts/breach_fx.gd")

const HIDE := Color(0.64, 0.07, 0.11)
const HIDE_DARK := Color(0.3, 0.03, 0.1)
const HORN := Color(0.62, 0.3, 0.98)
const EYE := Color(1.0, 0.22, 0.4)
const TOOTH := Color(0.96, 0.92, 1.0)
const GLOW := Color(0.85, 0.2, 0.55)
const HOLE := Color(0.03, 0.0, 0.06)
const RIM := Color(0.7, 0.3, 0.95)

## Metres per second it runs. Further behind than it can cover, it runs faster
## (CATCH_UP times its distance per second), and beyond TELEPORT it is simply there.
const RUN_SPEED := 9.0
const CATCH_UP := 2.5
const TELEPORT := 28.0
## Further from its prey than it runs in DASH_AFTER seconds, it dashes there
## instead: DASH_SPEED metres per second, low and stretched out, until it is
## within DASH_STOP metres of where it bites.
const DASH_AFTER := 1.0
const DASH_SPEED := 40.0
const DASH_STOP := 0.6
## Within this many metres of its spot it slows down, so it settles and does not snap.
const SETTLE := 0.8
const TURN := 10.0
## At heel: this far to its side of its owner, and this far behind.
const HEEL_SIDE := 1.15
const HEEL_BACK := 0.9
## At its prey: turned this far (radians, about 115 degrees) round the prey from
## the side its owner is on, and this far from the prey's edge.
const FLANK := 2.0
const STAND_OFF := 0.75
const RISE_TIME := 0.5
const LEAVE_TIME := 0.6
const BITE_TIME := 0.32
const LUNGE_TIME := 0.5
## Seconds between the bites a party member's Hound shows.
const AUTO_BITE := 1.5
## How far under the ground it starts and ends.
const DEPTH := 1.7
const HOLE_RADIUS := 0.8
const GAIT := 3.4          # radians of leg swing per metre run
## The meta a character carries its Hounds' pictures in (a party member's puppet).
const META := "hounds"

enum { RISING, OUT, LEAVING }

var owner_node: Node3D
var prey: Node3D
## -1: the one on its owner's left, +1: on the right, 0: a third one, behind
## its owner and on the far side of its prey.
var side := -1.0
## A party member's Hound: nothing tells it when to bite or to go.
var auto := false
## Seconds it has left (only an `auto` one counts them down itself).
var life := 30.0

var _built := false
var _state := RISING
var _t := 0.0             # seconds in this state
var _age := 0.0
var _at := Vector3.ZERO   # where it stands: a point on the ground
var _yaw := 0.0
var _speed := 0.0         # metres per second, last frame
var _gait := 0.0
var _bite := -1.0         # seconds into a bite (-1 = not biting)
var _lunge := -1.0
var _auto_bite := 0.0
var _drag := false
var _dashing := false     # on its way to prey that is far off
var _stretch := 0.0       # how far into its dash pose it is (0-1)
var _streak: MeshInstance3D
var _streak_mat: StandardMaterial3D
var _rig: Node3D
var _head: Node3D
var _jaw: Node3D
var _legs: Array = []     # {"hip": Node3D, "knee": Node3D, "phase": float}
var _tail: Array = []     # Node3D, root first
var _hole: MeshInstance3D
var _rim: MeshInstance3D
var _hole_mat: StandardMaterial3D
var _rim_mat: StandardMaterial3D

# --- What the rules ask of it (all static) ---------------------------------------------

## -1 for the first Hound of a pair, +1 for the second, 0 for a third (Slipped Leash).
static func side_of(index: int) -> float:
	match index % 3:
		0:
			return -1.0
		1:
			return 1.0
	return 0.0

## Where the Hound on `side` stands at heel: beside and a little behind its
## owner, who stands at `at` (a point on the ground) turned to `yaw`. A third
## one (side 0) walks behind the two.
static func heel_spot(at: Vector3, yaw: float, side_sign: float) -> Vector3:
	var back := HEEL_BACK if side_sign != 0.0 else HEEL_BACK + HEEL_SIDE
	return at + Vector3(side_sign * HEEL_SIDE, 0.0, back).rotated(Vector3.UP, yaw)

## Where it stands to bite: at the side of its prey (at `prey_at`, `reach` wide),
## round from where its owner stands (`from`), so the two Hounds and their owner
## are on three sides of it. A third one (side 0) takes the far side.
static func flank_spot(prey_at: Vector3, from: Vector3, reach: float, side_sign: float) -> Vector3:
	var dir := Vector3(from.x - prey_at.x, 0.0, from.z - prey_at.z)
	dir = dir.normalized() if dir.length() > 0.05 else Vector3.BACK
	var turn := side_sign * FLANK if side_sign != 0.0 else PI
	return prey_at + dir.rotated(Vector3.UP, turn) * (maxf(reach, 0.0) + STAND_OFF)

## Does it dash from `from` to prey at `to`? When that is more than DASH_AFTER
## seconds' run away.
static func dashes(from: Vector3, to: Vector3) -> bool:
	return Vector2(to.x - from.x, to.z - from.z).length() > RUN_SPEED * DASH_AFTER

## Seconds it takes to get from `from` to `to` (and to turn on what is there):
## its owner waits that long before its next bite counts. A dash covers a long
## way in well under the second a run would take.
static func travel_time(from: Vector3, to: Vector3) -> float:
	var dist := Vector2(to.x - from.x, to.z - from.z).length()
	if dashes(from, to):
		return minf(dist / DASH_SPEED, DASH_AFTER) + 0.15
	return dist / RUN_SPEED + 0.15

## The yaw of something looking along `dir` (characters look down -Z).
static func yaw_to(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)

## Where `n` is (a node outside a running scene has no global position).
static func where(n: Node3D) -> Vector3:
	return n.global_position if n.is_inside_tree() else n.position

## The point on the ground under `body` (its origin is its middle).
static func ground_point(body: Node3D) -> Vector3:
	return where(body) + Vector3(0.0, float(BreachFx.body_of(body)["feet"]), 0.0)

## How far out of the ground it is `t` seconds after it was called (0 = under
## it, 1 = all the way out).
static func rise(t: float) -> float:
	var k := clampf(t / RISE_TIME, 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 2.0)

## How far it has sunk `t` seconds after it was told to go (0-1).
static func sink(t: float) -> float:
	var k := clampf(t / LEAVE_TIME, 0.0, 1.0)
	return k * k

## Two Hounds for `whose` come up out of the ground: at `at_prey` if there is
## one, else at heel. `time` = seconds they stay; `is_auto` = a party member's.
static func call_pair(scene: Node, whose: Node3D, at_prey: Node3D, time: float, is_auto: bool) -> Array:
	var out: Array = []
	if scene == null or not is_instance_valid(scene) or whose == null or not is_instance_valid(whose):
		return out
	for i in 2:
		out.append(call_one(scene, whose, at_prey, time, is_auto, i))
	if is_auto:
		whose.set_meta(META, out)
	return out

## One Hound for `whose` comes up out of the ground: number `index` of the pack
## (0 and 1 are the pair, 2 a third that joins them: Slipped Leash). Null if
## there is nobody to follow.
static func call_one(scene: Node, whose: Node3D, at_prey: Node3D, time: float, is_auto: bool, index: int) -> Node3D:
	if scene == null or not is_instance_valid(scene) or whose == null or not is_instance_valid(whose):
		return null
	var h := Node3D.new()
	h.set_script(load("res://scripts/hound.gd"))
	h.owner_node = whose
	h.prey = at_prey if at_prey != null and is_instance_valid(at_prey) else null
	h.side = side_of(index)
	h.auto = is_auto
	h.life = time
	scene.add_child(h)
	if not h.is_inside_tree():
		h._build()   # (not in a scene that is running: nothing calls _ready)
	return h

## A party member's Hounds, from what their machine says: `time` seconds left
## (0 = they are gone), what they are on, whether they lunge right now, and how
## many there are (`count`: a third joins the pair for a while with Slipped Leash).
static func show_for(scene: Node, whose: Node3D, at_prey: Node3D, time: float, lunge_now: bool = false, count: int = 2) -> void:
	if whose == null or not is_instance_valid(whose):
		return
	var pair: Array = []
	if whose.has_meta(META):
		for h in whose.get_meta(META):
			if h != null and is_instance_valid(h) and not h.is_queued_for_deletion() and not h.leaving():
				pair.append(h)
	if time <= 0.0:
		for h in pair:
			h.leave(at_prey != null and is_instance_valid(at_prey))
		if whose.has_meta(META):
			whose.remove_meta(META)
		return
	if pair.is_empty():
		pair = call_pair(scene, whose, at_prey, time, true)
	# The third one has joined them, or its time is over.
	var want := clampi(count, 2, 3)
	while pair.size() > want:
		pair.pop_back().leave(at_prey != null and is_instance_valid(at_prey))
	while pair.size() >= 2 and pair.size() < want:
		var more := call_one(scene, whose, at_prey, time, true, pair.size())
		if more == null:
			break
		pair.append(more)
	whose.set_meta(META, pair)
	for h in pair:
		h.set_prey(at_prey)
		h.life = time
		if lunge_now:
			h.lunge()

# --- What its owner tells it -----------------------------------------------------------

## What to bite (null = come back to heel).
func set_prey(p: Node3D) -> void:
	prey = p if p != null and is_instance_valid(p) else null

## One of its bites landed: it snaps at its prey.
func bite() -> void:
	if _state == OUT and _lunge < 0.0:
		_bite = 0.0

## Both At Once: it leaps at its prey.
func lunge() -> void:
	if _state == OUT:
		_lunge = 0.0
		_bite = -1.0

## Its time is up (or its owner fell): it sinks back into the ground. `drag` =
## with its jaws shut on its prey.
func leave(drag: bool = false) -> void:
	if _state == LEAVING:
		return
	_state = LEAVING
	_t = 0.0
	_drag = drag
	_bite = -1.0
	_lunge = -1.0
	_dashing = false
	# What it drags down goes under with it: if it was still on its way there
	# (sent under early from heel: Bring It Down), it is at its prey now.
	if drag and _built and _prey_ok() and _owner_ok():
		var goal := _goal()
		if Vector2(goal.x - _at.x, goal.z - _at.z).length() > 1.0:
			_at = goal
			_yaw = yaw_to(ground_point(prey) - _at)
			_place()

func leaving() -> bool:
	return _state == LEAVING

## Is it out of the ground and on its feet?
func is_out() -> bool:
	return _state == OUT

## Where it stands (a point on the ground).
func spot() -> Vector3:
	return _at

## Is it dashing at prey that is far off?
func is_dashing() -> bool:
	return _dashing

# --- Shared meshes and materials (every Hound uses the same ones) -----------------------

static var _shared := {}

## Meshes one unit across, so a part's scale is its size in metres.
static func _mesh(kind: String) -> Mesh:
	if _shared.has(kind):
		return _shared[kind]
	var m: Mesh = null
	match kind:
		"ball":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 12
			s.rings = 6
			m = s
		"tube":
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 8
			c.rings = 1
			m = c
		"cone":
			var k := CylinderMesh.new()
			k.top_radius = 0.0
			k.bottom_radius = 0.5
			k.height = 1.0
			k.radial_segments = 6
			k.rings = 1
			m = k
		"box":
			m = BoxMesh.new()
		"disc":
			var d := CylinderMesh.new()
			d.top_radius = 1.0
			d.bottom_radius = 1.0
			d.height = 0.02
			d.radial_segments = 24
			d.rings = 1
			m = d
		_:
			var t := TorusMesh.new()
			t.inner_radius = 0.88
			t.outer_radius = 1.0
			t.rings = 24
			t.ring_segments = 4
			m = t
	_shared[kind] = m
	return m

static func _mat(kind: String) -> StandardMaterial3D:
	var key := "mat_" + kind
	if _shared.has(key):
		return _shared[key]
	var m := StandardMaterial3D.new()
	m.roughness = 0.75
	m.emission_enabled = true
	match kind:
		"hide":
			m.albedo_color = HIDE
			m.emission = HIDE
			m.emission_energy_multiplier = 0.45   # (it reads in a dark cave too)
		"dark":
			m.albedo_color = HIDE_DARK
			m.emission = HIDE_DARK
			m.emission_energy_multiplier = 0.35
		"horn":
			m.albedo_color = HORN
			m.emission = HORN
			m.emission_energy_multiplier = 1.6
		"eye":
			m.albedo_color = EYE
			m.emission = EYE
			m.emission_energy_multiplier = 3.5
		_:
			m.albedo_color = TOOTH
			m.emission = TOOTH
			m.emission_energy_multiplier = 0.5
	_shared[key] = m
	return m

# --- Building it ------------------------------------------------------------------------

func _ready() -> void:
	_build()

func _part(kind: String, mat: Material, to: Node3D, at: Vector3, size: Vector3, turn: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(kind)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	mi.scale = size
	mi.rotation = turn
	to.add_child(mi)
	return mi

func _pivot(to: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	to.add_child(n)
	return n

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

## Makes the Hound (it looks down -Z, its feet at y = 0) and the hole it comes
## out of, and puts it where it starts. (Called by _ready; a test may call it itself.)
func _build() -> void:
	if _built:
		return
	_built = true
	var hide := _mat("hide")
	var dark := _mat("dark")
	var horn := _mat("horn")
	var tooth := _mat("tooth")
	# The hole.
	_hole_mat = _flat_mat(Color(HOLE, 0.0), 0.0)
	_hole = _part("disc", _hole_mat, self, Vector3(0.0, 0.02, 0.0), Vector3(0.01, 1.0, 0.01))
	_rim_mat = _flat_mat(Color(RIM, 0.0), 2.0)
	_rim = _part("rim", _rim_mat, self, Vector3(0.0, 0.03, 0.0), Vector3(0.01, 0.3, 0.01))
	_rig = _pivot(self, Vector3.ZERO)
	# Body: a deep chest, a lean belly, heavy haunches.
	_part("ball", hide, _rig, Vector3(0.0, 0.68, -0.28), Vector3(0.46, 0.5, 0.6))
	_part("ball", hide, _rig, Vector3(0.0, 0.64, 0.12), Vector3(0.38, 0.4, 0.75))
	_part("ball", hide, _rig, Vector3(0.0, 0.66, 0.45), Vector3(0.42, 0.44, 0.5))
	_part("ball", dark, _rig, Vector3(0.0, 0.54, 0.1), Vector3(0.3, 0.26, 0.8))
	_part("ball", dark, _rig, Vector3(0.0, 0.9, -0.3), Vector3(0.3, 0.22, 0.36))
	_part("tube", hide, _rig, Vector3(0.0, 0.88, -0.52), Vector3(0.24, 0.42, 0.24), Vector3(-0.9, 0.0, 0.0))
	# Spines down its back, tallest over the shoulders.
	for i in 6:
		var k := i / 5.0
		_part("cone", horn, _rig, Vector3(0.0, lerpf(0.98, 0.9, k), lerpf(-0.42, 0.52, k)),
			Vector3(0.07, lerpf(0.3, 0.13, k), 0.07), Vector3(0.55, 0.0, 0.0))
	# Head.
	_head = _pivot(_rig, Vector3(0.0, 1.05, -0.78))
	_part("ball", hide, _head, Vector3.ZERO, Vector3(0.3, 0.27, 0.34))
	_part("box", dark, _head, Vector3(0.0, 0.08, -0.1), Vector3(0.3, 0.06, 0.14), Vector3(0.25, 0.0, 0.0))
	_part("box", hide, _head, Vector3(0.0, -0.03, -0.3), Vector3(0.19, 0.11, 0.36))
	_part("ball", dark, _head, Vector3(0.0, 0.0, -0.49), Vector3(0.1, 0.07, 0.07))
	for sx: float in [-1.0, 1.0]:
		_part("ball", _mat("eye"), _head, Vector3(0.11 * sx, 0.05, -0.15), Vector3.ONE * 0.07)
		_part("cone", horn, _head, Vector3(0.11 * sx, 0.2, 0.06), Vector3(0.085, 0.42, 0.085), Vector3(0.95, 0.0, -0.35 * sx))
		_part("cone", dark, _head, Vector3(0.15 * sx, 0.1, 0.08), Vector3(0.07, 0.16, 0.04), Vector3(0.5, 0.0, -0.9 * sx))
		_part("cone", tooth, _head, Vector3(0.07 * sx, -0.13, -0.43), Vector3(0.035, 0.11, 0.035), Vector3(PI, 0.0, 0.0))
		_part("cone", tooth, _head, Vector3(0.08 * sx, -0.11, -0.3), Vector3(0.03, 0.06, 0.03), Vector3(PI, 0.0, 0.0))
	_jaw = _pivot(_head, Vector3(0.0, -0.1, -0.1))
	_part("box", dark, _jaw, Vector3(0.0, -0.02, -0.2), Vector3(0.16, 0.06, 0.34))
	for sx: float in [-1.0, 1.0]:
		_part("cone", tooth, _jaw, Vector3(0.06 * sx, 0.05, -0.34), Vector3(0.03, 0.08, 0.03))
	# Legs: a hip that swings and a knee that bends, a paw with three claws.
	for row in [[-0.3, 0.62, 0.2, 0.0], [0.45, 0.6, 0.19, PI]]:
		for sx: float in [-1.0, 1.0]:
			var hip := _pivot(_rig, Vector3(float(row[2]) * sx, float(row[1]), float(row[0])))
			_part("tube", hide, hip, Vector3(0.0, -0.16, 0.0), Vector3(0.13, 0.34, 0.15))
			var knee := _pivot(hip, Vector3(0.0, -0.32, 0.0))
			_part("tube", dark, knee, Vector3(0.0, -0.14, 0.0), Vector3(0.09, 0.3, 0.1))
			_part("ball", dark, knee, Vector3(0.0, -0.29, -0.04), Vector3(0.14, 0.08, 0.2))
			for c in 3:
				_part("cone", horn, knee, Vector3((c - 1) * 0.045, -0.3, -0.15), Vector3(0.03, 0.09, 0.03), Vector3(-1.9, 0.0, 0.0))
			# (A trot: each leg moves with the one diagonally across from it.)
			_legs.append({"hip": hip, "knee": knee, "phase": float(row[3]) + (0.0 if sx < 0.0 else PI), "front": float(row[0]) < 0.0})
	# Tail: four joints and a barb.
	var joint := _pivot(_rig, Vector3(0.0, 0.74, 0.68))
	for i in 4:
		var thick := lerpf(0.09, 0.04, i / 3.0)
		_part("tube", hide if i < 2 else dark, joint, Vector3(0.0, 0.0, 0.11), Vector3(thick, 0.24, thick), Vector3(PI / 2.0, 0.0, 0.0))
		_tail.append(joint)
		if i == 3:
			_part("cone", horn, joint, Vector3(0.0, 0.0, 0.3), Vector3(0.1, 0.2, 0.03), Vector3(PI / 2.0, 0.0, 0.0))
		else:
			joint = _pivot(joint, Vector3(0.0, 0.0, 0.22))
	# The streak it leaves behind it in a dash.
	_streak_mat = _flat_mat(Color(GLOW, 0.0), 2.5)
	_streak = _part("box", _streak_mat, _rig, Vector3(0.0, 0.66, 1.45), Vector3(0.3, 0.28, 1.7))
	_streak.visible = false
	# Embers coming off it, and a little light of its own so it is never lost in the dark.
	var bit_mat := StandardMaterial3D.new()
	bit_mat.albedo_color = GLOW
	bit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bit_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var bit := QuadMesh.new()
	bit.size = Vector2(0.05, 0.05)
	bit.material = bit_mat
	var embers := CPUParticles3D.new()
	embers.amount = 8
	embers.lifetime = 0.9
	embers.local_coords = false
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 0.35
	embers.direction = Vector3.UP
	embers.spread = 35.0
	embers.gravity = Vector3(0.0, 0.5, 0.0)
	embers.initial_velocity_min = 0.1
	embers.initial_velocity_max = 0.4
	embers.mesh = bit
	embers.position = Vector3(0.0, 0.8, 0.0)
	_rig.add_child(embers)
	var light := OmniLight3D.new()
	light.light_color = GLOW
	light.light_energy = 0.9
	light.omni_range = 3.0
	light.shadow_enabled = false
	light.position = Vector3(0.0, 0.95, -0.2)
	_rig.add_child(light)
	# Where it comes up: beside its prey if it has one, else at heel.
	_at = _goal()
	if _owner_ok():
		_yaw = owner_node.rotation.y
	if _prey_ok():
		_yaw = yaw_to(ground_point(prey) - _at)
	_place()
	_pose(0.0)

## How many legs it has (a test asks).
func legs() -> int:
	return _legs.size()

# --- Every frame ------------------------------------------------------------------------

func _process(delta: float) -> void:
	_advance(delta)

func _owner_ok() -> bool:
	return owner_node != null and is_instance_valid(owner_node)

func _prey_ok() -> bool:
	return prey != null and is_instance_valid(prey) and (not prey.has_method("is_alive") or bool(prey.call("is_alive")))

## Where it wants to stand right now (a point on the ground).
func _goal() -> Vector3:
	if not _owner_ok():
		return _at
	var from := ground_point(owner_node)
	if _prey_ok():
		return flank_spot(ground_point(prey), from, float(BreachFx.body_of(prey)["radius"]), side)
	return heel_spot(from, owner_node.rotation.y, side)

func _place() -> void:
	if is_inside_tree():
		global_position = _at
	else:
		position = _at

## Move everything on by `delta` seconds. (Called by _process; a test may call it itself.)
func _advance(delta: float) -> void:
	if not _built:
		return
	_age += delta
	_t += delta
	if not _owner_ok() and _state != LEAVING:
		leave(false)   # whoever it followed is gone
	match _state:
		RISING:
			if _t >= RISE_TIME:
				_state = OUT
				_t = 0.0
		OUT:
			_move(delta)
			if auto:
				_auto(delta)
		LEAVING:
			if _t >= LEAVE_TIME:
				queue_free()
				return
	_pose(delta)

## Run to where it wants to stand, and turn the way it is going (or, standing,
## to its prey; with none, the way its owner looks).
func _move(delta: float) -> void:
	var goal := _goal()
	var flat := Vector2(goal.x - _at.x, goal.z - _at.z)
	var d := flat.length()
	# Prey more than a second's run away: it dashes there, and the dash ends
	# where it bites (or when there is nothing left to bite).
	if not _prey_ok():
		_dashing = false
	elif not _dashing and d > RUN_SPEED * DASH_AFTER:
		_dashing = true
	elif _dashing and d <= DASH_STOP:
		_dashing = false
	var moved := 0.0
	if d > TELEPORT and not _dashing:
		_at = goal
	elif d > 0.01:
		var pace := DASH_SPEED if _dashing else maxf(RUN_SPEED * clampf(d / SETTLE, 0.12, 1.0), d * CATCH_UP)
		moved = minf(d, pace * delta)
		_at.x += flat.x / d * moved
		_at.z += flat.y / d * moved
		_at.y = lerpf(_at.y, goal.y, clampf(moved / d, 0.0, 1.0))
	else:
		_at.y = goal.y
	_speed = moved / maxf(delta, 0.0001)
	_gait += moved * GAIT
	var look := _yaw
	if _speed > 1.2 and d > 0.05:
		look = atan2(-flat.x, -flat.y)
	elif _prey_ok():
		look = yaw_to(ground_point(prey) - _at)
	elif _owner_ok():
		look = owner_node.rotation.y
	_yaw = lerp_angle(_yaw, look, clampf(delta * TURN, 0.0, 1.0))
	_place()

## A party member's Hound: it counts its own time down and bites by itself.
func _auto(delta: float) -> void:
	life -= delta
	var fallen: bool = owner_node.has_method("is_alive") and not bool(owner_node.call("is_alive"))
	if life <= 0.0 or fallen:
		leave(_prey_ok() and not fallen)
		return
	if not _prey_ok():
		_auto_bite = AUTO_BITE * 0.5
		return
	_auto_bite -= delta
	if _auto_bite <= 0.0 and _speed < 1.0:
		_auto_bite = AUTO_BITE
		bite()

## Put every part where it is at this moment.
func _pose(delta: float) -> void:
	rotation.y = _yaw
	var under := 0.0   # how far under the ground it is (0-1)
	var hole := 0.0    # how open the hole under it is (0-1)
	if _state == RISING:
		under = 1.0 - rise(_t)
		hole = 1.0 - smoothstep(0.6, 1.0, _t / RISE_TIME)
	elif _state == LEAVING:
		under = sink(_t)
		hole = minf(_t / LEAVE_TIME * 4.0, 1.0) * (1.0 - smoothstep(0.85, 1.0, _t / LEAVE_TIME))
	var forward := 0.0
	var up := 0.0
	var pitch := 0.0
	var jaw := 0.14 + 0.06 * sin(_age * 2.3)   # panting
	if _bite >= 0.0:
		_bite += delta
		var k := _bite / BITE_TIME
		if k >= 1.0:
			_bite = -1.0
		else:
			forward = 0.45 * sin(k * PI)
			jaw = 0.95 if k < 0.45 else 0.0   # wide, then shut
	if _lunge >= 0.0:
		_lunge += delta
		var k := _lunge / LUNGE_TIME
		if k >= 1.0:
			_lunge = -1.0
		else:
			forward = 1.3 * sin(k * PI)
			up = 0.55 * sin(k * PI)
			pitch = 0.35 * cos(k * PI)   # nose up as it leaves the ground, down as it lands
			jaw = 1.0 if k < 0.5 else 0.0
	var head_down := 0.0
	if _state == LEAVING and _drag:
		jaw = 0.0          # shut on what it is taking with it
		head_down = 0.5
		forward = 0.3
	var run := clampf(_speed / RUN_SPEED, 0.0, 1.0)
	# A dash: low and long, legs stretched out fore and aft, jaws open, a streak behind it.
	_stretch = move_toward(_stretch, 1.0 if _dashing and _state == OUT else 0.0, delta * 9.0)
	var s := _stretch
	if s > 0.0 and _bite < 0.0 and _lunge < 0.0:
		jaw = lerpf(jaw, 0.7, s)
	var bob := (absf(sin(_gait)) * 0.06 * run + sin(_age * 2.3) * 0.012) * (1.0 - s)
	_rig.position = Vector3(0.0, up + bob - under * DEPTH - 0.1 * s, -forward)
	_rig.rotation.x = pitch
	_rig.scale = Vector3(1.0 - 0.1 * s, 1.0 - 0.16 * s, 1.0 + 0.4 * s)
	_head.rotation.x = 0.06 * sin(_age * 1.7) - head_down + 0.25 * s
	_head.rotation.y = 0.12 * sin(_age * 0.9 + side) * (1.0 - run)
	_jaw.rotation.x = -jaw
	for leg in _legs:
		var phase: float = _gait + float(leg["phase"])
		var reach := 1.15 if bool(leg["front"]) else -1.15   # (a positive turn swings the paw forward)
		(leg["hip"] as Node3D).rotation.x = lerpf(sin(phase) * 0.75 * run, reach, s)
		(leg["knee"] as Node3D).rotation.x = -lerpf(0.15 + 0.75 * maxf(sin(phase + 0.9), 0.0) * run, 0.1, s)
	_streak.visible = s > 0.02
	_streak_mat.albedo_color = Color(GLOW, 0.5 * s)
	for i in _tail.size():
		var seg := _tail[i] as Node3D
		seg.rotation.y = sin(_age * 3.2 - i * 0.7) * (0.2 + 0.2 * run)
		seg.rotation.x = -0.55 if i == 0 else 0.12
	var r := HOLE_RADIUS * maxf(hole, 0.01)
	_hole.visible = hole > 0.01
	_rim.visible = hole > 0.01
	_hole.scale = Vector3(r, 1.0, r)
	_hole_mat.albedo_color = Color(HOLE, 0.92 * hole)
	_rim.scale = Vector3(r * 1.04, 0.3, r * 1.04)
	_rim_mat.albedo_color = Color(RIM, 0.9 * hole)
