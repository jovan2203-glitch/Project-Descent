@tool
extends Node3D

# The Puppeteer (Shadow healer): the demon that floats behind a healer who has
# Strings out, and the threads themselves. Three pictures, one script:
#   DEMON    a horned demon hanging in the air behind its owner, arms out. A
#            short thread runs from its hands towards each one it holds and
#            fades out long before it gets there: nothing is strung across the
#            whole screen.
#   THREADS  the threads over someone on a String. They come down from above
#            (fading out a little way up) onto the head and shoulders, one more
#            for each String. They follow where the target stands but never how
#            it turns, and they sway, so they are not stiff.
#   FLOOR    Tangle: threads lying across the floor for a while.
# Only a picture: the rules are in player.gd ("Shadow healer: the Strings").
# The healer's machine calls hold() with everyone it holds; the party gets the
# same list through the "strings" fx (Net._fx) and calls hold() for the puppet.
# (@tool only so tests/test_strings.gd can build one inside the editor.)
# Usage: const Puppeteer = preload("res://scripts/puppeteer.gd")

const BreachFx = preload("res://scripts/breach_fx.gd")

const HIDE := Color(0.55, 0.07, 0.16)
const HIDE_DARK := Color(0.22, 0.03, 0.13)
const HORN := Color(0.62, 0.3, 0.98)
const EYE := Color(1.0, 0.25, 0.45)
const GLOW := Color(0.8, 0.25, 0.6)
## A thread to an ally, and one to an enemy.
const THREAD := Color(0.93, 0.86, 1.0)
const THREAD_ENEMY := Color(1.0, 0.35, 0.45)

## The meta a character carries its demon and threads in.
const META := "puppeteer"

enum { DEMON, THREADS, FLOOR }

## Where the demon hangs: this far behind its owner, this far above their middle.
const BACK := 1.5
const UP := 1.45
## How fast it closes on that spot and turns the way its owner faces (per
## second): slow enough that it drifts after them instead of being bolted on.
const FOLLOW := 5.0
const TURN := 3.5
## Metres a thread from its hand runs before it has faded out.
const HAND_THREAD := 2.2
const MAX_HAND_THREADS := 6
## Metres a thread over a target rises before it has faded out.
const THREAD_HEIGHT := 2.4
const THREAD_RADIUS := 0.014
## Seconds anything here takes to appear or to go.
const FADE := 0.35
## String Up: how far off the ground the enemy hangs.
const LIFT := 0.7

var kind := DEMON
var owner_node: Node3D
## THREADS: whom they hang over, how many Strings (1-3), and whether it is an enemy.
var target: Node3D
var count := 1
var enemy := false
## THREADS: also lift the target's model off the ground (String Up).
var lift := false
## DEMON: whom its threads run towards.
var targets: Array = []
## FLOOR: how wide the tangle is.
var radius := 5.0
## Seconds left (-1 = until it is told to leave).
var life := -1.0

var _built := false
var _age := 0.0
var _show := 0.0          # 0-1: how far it has appeared
var _leaving := false
var _at := Vector3.ZERO
var _yaw := 0.0
var _rig: Node3D
var _head: Node3D
var _arms: Array = []     # Node3D shoulder pivots
var _hands: Array = []    # Vector3: where each hand is, in the demon's own space
var _lines: Array = []    # MeshInstance3D threads
var _dirs: Array = []     # DEMON: the way each hand thread points (smoothed)
var _model: Node3D        # String Up: the model lifted
var _model_y := 0.0

# --- What the rules ask of it (all static) ---------------------------------------------

## Where the demon hangs for an owner at `at` (their middle) turned to `yaw`
## (characters look down -Z): behind them and above.
static func behind_spot(at: Vector3, yaw: float) -> Vector3:
	return at + Vector3(0.0, UP, BACK).rotated(Vector3.UP, yaw)

## Threads shown over someone with `strings` Strings: one more than that, two to four.
static func thread_count(strings: int) -> int:
	return clampi(strings, 1, 3) + 1

## How long the thread from a hand to something `dist` metres away is drawn.
static func hand_thread_length(dist: float) -> float:
	return clampf(dist, 0.3, HAND_THREAD)

## Where `n` is (a node outside a running scene has no global position).
static func where(n: Node3D) -> Vector3:
	return n.global_position if n.is_inside_tree() else n.position

## Show `whose` demon and the threads on everyone they hold. `held` =
## [[Node3D, Strings, is enemy], ...]; empty = everything goes.
static func hold(scene: Node, whose: Node3D, held: Array) -> void:
	if whose == null or not is_instance_valid(whose):
		return
	var st: Dictionary = whose.get_meta(META) if whose.has_meta(META) else {"demon": null, "threads": {}}
	var threads: Dictionary = st["threads"]
	var want := {}
	var nodes: Array = []
	for row in held:
		if not (row is Array) or (row as Array).size() < 3:
			continue
		var n: Variant = row[0]
		if n == null or not is_instance_valid(n) or not (n is Node3D):
			continue
		want[(n as Node).get_instance_id()] = row
		nodes.append(n)
	for key in threads.keys():
		var old: Variant = threads[key]
		if old == null or not is_instance_valid(old) or old.leaving():
			threads.erase(key)
		elif not want.has(key):
			old.leave()
			threads.erase(key)
	for key in want:
		var row: Array = want[key]
		if not threads.has(key):
			var made := _make(scene, THREADS, whose)
			if made == null:
				continue
			made.target = row[0]
			made._settle()
			threads[key] = made
		threads[key].set_count(int(row[1]), bool(row[2]))
	var demon: Variant = st["demon"]
	if demon != null and (not is_instance_valid(demon) or demon.leaving()):
		demon = null
	if nodes.is_empty():
		if demon != null:
			demon.leave()
		demon = null
	else:
		if demon == null:
			demon = _make(scene, DEMON, whose)
			if demon != null:
				demon._settle()
		if demon != null:
			demon.targets = nodes
	st["demon"] = demon
	if demon == null and threads.is_empty():
		if whose.has_meta(META):
			whose.remove_meta(META)
	else:
		whose.set_meta(META, st)

## `whose` demon (null if they have none out).
static func demon_of(whose: Node3D) -> Node3D:
	if whose == null or not is_instance_valid(whose) or not whose.has_meta(META):
		return null
	var d: Variant = (whose.get_meta(META) as Dictionary).get("demon")
	return d if d != null and is_instance_valid(d) else null

## The threads `whose` Strings show: target instance id -> the picture over it.
static func threads_of(whose: Node3D) -> Dictionary:
	if whose == null or not is_instance_valid(whose) or not whose.has_meta(META):
		return {}
	return (whose.get_meta(META) as Dictionary).get("threads", {})

## String Up: `foe` hangs off the ground on threads for `time` seconds.
static func string_up(scene: Node, foe: Node3D, time: float) -> Node3D:
	if foe == null or not is_instance_valid(foe):
		return null
	var t := _make(scene, THREADS, null)
	if t == null:
		return null
	t.target = foe
	t.set_count(3, true)   # (it is built already: dress it again)
	t.lift = true
	t.life = maxf(time, 0.1)
	t._settle()
	return t

## Tangle: threads across the floor at `at`, `r` metres wide, for `time` seconds.
static func tangle(scene: Node, at: Vector3, r: float, time: float) -> Node3D:
	var t := _make(scene, FLOOR, null, r)
	if t == null:
		return null
	t.life = maxf(time, 0.1)
	t._at = at
	t._place()
	return t

static func _make(scene: Node, what: int, whose: Node3D, r: float = 5.0) -> Node3D:
	if scene == null or not is_instance_valid(scene):
		return null
	var n := Node3D.new()
	n.set_script(load("res://scripts/puppeteer.gd"))
	n.kind = what
	n.owner_node = whose
	n.radius = r
	scene.add_child(n)
	if not n.is_inside_tree():
		n._build()   # (not in a scene that is running: nothing calls _ready)
	return n

# --- What its owner tells it -----------------------------------------------------------

func set_count(strings: int, is_enemy: bool) -> void:
	count = clampi(strings, 1, 3)
	enemy = is_enemy
	_dress()

## It goes: it fades out and frees itself.
func leave() -> void:
	_leaving = true

func leaving() -> bool:
	return _leaving

## How many threads it shows right now (THREADS).
func threads_shown() -> int:
	var shown := 0
	for l in _lines:
		if (l as MeshInstance3D).visible:
			shown += 1
	return shown

## Where it is (the demon: where it hangs; threads: whom they are over).
func spot() -> Vector3:
	return _at

# --- Shared meshes and materials -----------------------------------------------------------

static var _shared := {}

static func _mesh(what: String) -> Mesh:
	if _shared.has(what):
		return _shared[what]
	var m: Mesh = null
	match what:
		"ball":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 12
			s.rings = 6
			m = s
		"cone":
			var k := CylinderMesh.new()
			k.top_radius = 0.0
			k.bottom_radius = 0.5
			k.height = 1.0
			k.radial_segments = 6
			k.rings = 1
			m = k
		"tube":
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 8
			c.rings = 1
			m = c
		_:
			# A thread: a hair-thin tube one metre long, no ends.
			var t := CylinderMesh.new()
			t.top_radius = THREAD_RADIUS
			t.bottom_radius = THREAD_RADIUS
			t.height = 1.0
			t.radial_segments = 5
			t.rings = 1
			t.cap_top = false
			t.cap_bottom = false
			m = t
	_shared[what] = m
	return m

static func _mat(what: String) -> StandardMaterial3D:
	var key := "mat_" + what
	if _shared.has(key):
		return _shared[key]
	var m := StandardMaterial3D.new()
	m.roughness = 0.8
	m.emission_enabled = true
	match what:
		"hide":
			m.albedo_color = HIDE
			m.emission = HIDE
			m.emission_energy_multiplier = 0.5   # (it reads in a dark cave too)
		"dark":
			m.albedo_color = HIDE_DARK
			m.emission = HIDE_DARK
			m.emission_energy_multiplier = 0.4
		"horn":
			m.albedo_color = HORN
			m.emission = HORN
			m.emission_energy_multiplier = 1.6
		_:
			m.albedo_color = EYE
			m.emission = EYE
			m.emission_energy_multiplier = 3.5
	_shared[key] = m
	return m

## A thread's material: `c`, glowing a little, see-through at one end. `from_top`
## = solid at its top end (a thread leaving a hand) and gone at the bottom; else
## solid at the bottom (a thread on someone's shoulder) and gone at the top.
static func _thread_mat(c: Color, from_top: bool) -> StandardMaterial3D:
	var key := "thread_%s_%s" % [c.to_html(), from_top]
	if _shared.has(key):
		return _shared[key]
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.95 if from_top else 0.0))
	grad.set_color(1, Color(1, 1, 1, 0.0 if from_top else 0.95))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 4
	tex.height = 32
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 0.5)   # (a tube's side uses the top half of the texture)
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = tex
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shared[key] = m
	return m

# --- Building it ------------------------------------------------------------------------

func _ready() -> void:
	_build()

func _part(what: String, mat: Material, to: Node3D, at: Vector3, size: Vector3, turn: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(what)
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

## (Called by _ready; a test may call it itself.)
func _build() -> void:
	if _built:
		return
	_built = true
	match kind:
		DEMON:
			_build_demon()
		THREADS:
			for i in 4:
				_lines.append(_part("thread", _thread_mat(THREAD, false), self, Vector3.ZERO, Vector3.ONE))
			_dress()
		_:
			_build_floor()
	_settle()
	_pose(0.0)

## The demon: it looks down -Z like a character, its chest at y = 0. A hunched
## trunk that thins out to nothing below, a horned head, and two long arms held
## out over whoever stands in front of it.
func _build_demon() -> void:
	var hide := _mat("hide")
	var dark := _mat("dark")
	var horn := _mat("horn")
	_rig = _pivot(self, Vector3.ZERO)
	_part("ball", hide, _rig, Vector3(0.0, 0.0, 0.0), Vector3(0.78, 0.7, 0.5))
	_part("ball", dark, _rig, Vector3(0.0, -0.3, 0.06), Vector3(0.56, 0.62, 0.42))
	_part("cone", dark, _rig, Vector3(0.0, -0.95, 0.12), Vector3(0.46, 1.1, 0.36), Vector3(PI, 0.0, 0.0))
	_part("ball", hide, _rig, Vector3(0.0, 0.22, 0.1), Vector3(0.95, 0.34, 0.42))   # the hunch of its shoulders
	for i in 4:
		_part("cone", horn, _rig, Vector3(0.0, 0.34 - i * 0.2, 0.26 + i * 0.02), Vector3(0.07, 0.24 - i * 0.03, 0.07),
			Vector3(-1.1, 0.0, 0.0))   # spines down its back
	_head = _pivot(_rig, Vector3(0.0, 0.5, -0.2))
	_part("ball", hide, _head, Vector3.ZERO, Vector3(0.4, 0.42, 0.42))
	_part("ball", dark, _head, Vector3(0.0, -0.13, -0.16), Vector3(0.26, 0.2, 0.24))
	for sx: float in [-1.0, 1.0]:
		_part("ball", _mat("eye"), _head, Vector3(0.1 * sx, 0.04, -0.19), Vector3.ONE * 0.075)
		_part("cone", horn, _head, Vector3(0.17 * sx, 0.27, 0.02), Vector3(0.1, 0.5, 0.1), Vector3(0.25, 0.0, -0.5 * sx))
		_part("cone", _mat("eye"), _head, Vector3(0.06 * sx, -0.2, -0.24), Vector3(0.035, 0.1, 0.035), Vector3(PI, 0.0, 0.0))
	# Arms: out to the sides, forward and down, ending in long-fingered hands.
	for sx: float in [-1.0, 1.0]:
		var shoulder := _pivot(_rig, Vector3(0.44 * sx, 0.2, 0.0))
		var elbow := Vector3(0.42 * sx, -0.02, -0.34)
		var hand := Vector3(0.62 * sx, -0.3, -0.86)
		_limb(shoulder, Vector3.ZERO, elbow, 0.15, hide)
		_limb(shoulder, elbow, hand, 0.11, dark)
		_part("ball", hide, shoulder, hand, Vector3(0.2, 0.1, 0.22))
		for f in 4:
			_part("cone", horn, shoulder, hand + Vector3((f - 1.5) * 0.045, -0.12, -0.05), Vector3(0.03, 0.2, 0.03), Vector3(PI, 0.0, 0.0))
		_arms.append(shoulder)
		_hands.append(shoulder.position + hand)
	var light := OmniLight3D.new()
	light.light_color = GLOW
	light.light_energy = 0.8
	light.omni_range = 3.5
	light.shadow_enabled = false
	light.position = Vector3(0.0, 0.1, -0.5)
	_rig.add_child(light)
	for i in MAX_HAND_THREADS:
		var line := _part("thread", _thread_mat(THREAD, true), self, Vector3.ZERO, Vector3.ONE)
		line.visible = false
		_lines.append(line)
		_dirs.append(Vector3.FORWARD)

## A limb from `a` to `b` (in `to`'s space), `thick` across.
func _limb(to: Node3D, a: Vector3, b: Vector3, thick: float, mat: Material) -> void:
	var mi := _part("tube", mat, to, (a + b) / 2.0, Vector3(thick, a.distance_to(b), thick))
	mi.basis = _along(b - a, Vector3(thick, a.distance_to(b), thick))

## A basis whose Y axis points along `dir`, stretched by `size` along its own axes.
static func _along(dir: Vector3, size: Vector3 = Vector3.ONE) -> Basis:
	var d := dir.normalized() if dir.length() > 0.0001 else Vector3.UP
	var turned := Basis(Vector3.RIGHT, PI) if d.dot(Vector3.UP) < -0.999 else Basis(Quaternion(Vector3.UP, d))
	return turned * Basis.from_scale(size)

## Tangle: a dozen threads lying this way and that across the circle.
func _build_floor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 12:
		var a := rng.randf() * TAU
		var b := a + PI + rng.randf_range(-0.9, 0.9)
		var from := Vector3(cos(a), 0.0, sin(a)) * radius
		var to := Vector3(cos(b), 0.0, sin(b)) * radius
		var line := _part("thread", _flat_thread(), self, (from + to) / 2.0 + Vector3(0.0, 0.07 + 0.01 * i, 0.0), Vector3.ONE)
		line.basis = _along(to - from, Vector3(1.6, from.distance_to(to), 1.6))
		_lines.append(line)

static func _flat_thread() -> StandardMaterial3D:
	if _shared.has("flat_thread"):
		return _shared["flat_thread"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(THREAD, 0.85)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shared["flat_thread"] = m
	return m

## THREADS: the right number of them, in the right colour.
func _dress() -> void:
	if kind != THREADS or _lines.is_empty():
		return
	var mat := _thread_mat(THREAD_ENEMY if enemy else THREAD, false)
	var shown := thread_count(count)
	for i in _lines.size():
		var line := _lines[i] as MeshInstance3D
		line.material_override = mat
		line.visible = i < shown

# --- Every frame ------------------------------------------------------------------------

func _process(delta: float) -> void:
	_advance(delta)

func _owner_ok() -> bool:
	return owner_node != null and is_instance_valid(owner_node)

func _target_ok() -> bool:
	return target != null and is_instance_valid(target) and (not target.has_method("is_alive") or bool(target.call("is_alive")))

## Where it wants to be right now.
func _goal() -> Vector3:
	match kind:
		DEMON:
			return behind_spot(where(owner_node), owner_node.rotation.y) if _owner_ok() else _at
		THREADS:
			return where(target) if target != null and is_instance_valid(target) else _at
	return _at

## Put it where it belongs at once (when it is made).
func _settle() -> void:
	_at = _goal()
	if kind == DEMON and _owner_ok():
		_yaw = owner_node.rotation.y
	_place()

func _place() -> void:
	if is_inside_tree():
		global_position = _at
	else:
		position = _at
	rotation.y = _yaw

## Move everything on by `delta` seconds. (Called by _process; a test may call it itself.)
func _advance(delta: float) -> void:
	if not _built:
		return
	_age += delta
	if life > 0.0:
		life -= delta
		if life <= 0.0:
			_leaving = true
	# Whoever it belongs to is gone, or whoever it hangs over fell: so does it.
	if kind == DEMON and not _owner_ok():
		_leaving = true
	if kind == THREADS and (not _target_ok() or (owner_node != null and not _owner_ok())):
		_leaving = true
	_show = move_toward(_show, 0.0 if _leaving else 1.0, delta / FADE)
	if _leaving and _show <= 0.0:
		_put_down()
		queue_free()
		return
	var goal := _goal()
	match kind:
		DEMON:
			# It drifts after its owner and turns after them: never bolted to their back.
			_at = _at.lerp(goal, clampf(delta * FOLLOW, 0.0, 1.0))
			if _owner_ok():
				_yaw = lerp_angle(_yaw, owner_node.rotation.y, clampf(delta * TURN, 0.0, 1.0))
		THREADS:
			_at = _at.lerp(goal, clampf(delta * 20.0, 0.0, 1.0))
	_place()
	_pose(delta)

## Put every part where it is at this moment.
func _pose(delta: float) -> void:
	match kind:
		DEMON:
			_pose_demon(delta)
		THREADS:
			_pose_threads()
		_:
			for l in _lines:
				(l as MeshInstance3D).transparency = 1.0 - _show

func _pose_demon(delta: float) -> void:
	var grown := 0.2 + 0.8 * (1.0 - pow(1.0 - _show, 2.0))
	_rig.scale = Vector3.ONE * grown
	_rig.position = Vector3(0.0, sin(_age * 1.6) * 0.07 - (1.0 - _show) * 0.6, 0.0)
	_rig.rotation.x = -0.18 + sin(_age * 0.9) * 0.03   # leaning forward over whoever it holds
	_head.rotation.y = sin(_age * 0.7) * 0.18
	_head.rotation.x = -0.1 + sin(_age * 1.1) * 0.05
	for i in _arms.size():
		var arm := _arms[i] as Node3D
		arm.rotation.x = sin(_age * 1.3 + i * 1.7) * 0.08
		arm.rotation.z = sin(_age * 1.0 + i * 2.3) * 0.06
	# A short thread from a hand towards each one it holds, fading out on the way.
	var here := _at
	for i in _lines.size():
		var line := _lines[i] as MeshInstance3D
		var to: Variant = targets[i] if i < targets.size() else null
		if to == null or not is_instance_valid(to) or not (to is Node3D) or _show <= 0.02:
			line.visible = false
			continue
		var hand: Vector3 = _hands[i % _hands.size()] * grown + _rig.position
		var from := here + hand.rotated(Vector3.UP, _yaw)
		var want := where(to as Node3D) - from
		var dist := want.length()
		want = want.normalized() if dist > 0.05 else Vector3.DOWN
		want = (want + Vector3(0.0, -0.25, 0.0)).normalized()   # it hangs a little
		# (Only roughly at the target: the thread swings round to it, it does not snap.)
		var dir: Vector3 = (_dirs[i] as Vector3).slerp(want, clampf(delta * 6.0, 0.0, 1.0)) if delta > 0.0 else want
		if dir.length() < 0.5:
			dir = want
		_dirs[i] = dir.normalized()
		var local := (_dirs[i] as Vector3).rotated(Vector3.UP, -_yaw)
		var length := hand_thread_length(dist)
		line.visible = true
		line.position = hand + local * length / 2.0
		line.basis = _along(-local, Vector3(1.0, length, 1.0))   # its solid end at the hand
		line.transparency = 1.0 - _show

func _pose_threads() -> void:
	var feet := -0.9
	var wide := 0.4
	if target != null and is_instance_valid(target):
		var body: Dictionary = BreachFx.body_of(target)
		feet = float(body.get("feet", -0.9))
		wide = float(body.get("radius", 0.4))
	var head := absf(feet) - 0.06
	var ring := maxf(wide * 0.75, 0.24)
	var hang := LIFT * _lift_now() if lift else 0.0
	var spots := [Vector3(0.0, head, 0.0), Vector3(-ring, head - 0.32, 0.04), Vector3(ring, head - 0.32, -0.04),
		Vector3(0.0, head - 0.36, ring)]
	for i in _lines.size():
		var line := _lines[i] as MeshInstance3D
		if not line.visible:
			continue
		var foot: Vector3 = spots[i] + Vector3(0.0, hang, 0.0)
		# The top of each one drifts about on its own, so they sway.
		var top := foot + Vector3(sin(_age * 1.3 + i * 1.9) * 0.16, THREAD_HEIGHT, cos(_age * 1.1 + i * 2.6) * 0.16)
		line.position = (foot + top) / 2.0
		line.basis = _along(top - foot, Vector3(1.0, foot.distance_to(top), 1.0))
		line.transparency = 1.0 - _show
	if lift:
		_lift_model(hang)

## String Up: how far up the enemy is right now (0-1): up fast, held, then let down.
func _lift_now() -> float:
	if _leaving:
		return _show
	return clampf(_age / 0.25, 0.0, 1.0)

func _lift_model(up: float) -> void:
	if _model == null:
		var m: Variant = target.get_node_or_null("Model") if target != null and is_instance_valid(target) else null
		if not (m is Node3D):
			return
		_model = m
		_model_y = _model.position.y
	if is_instance_valid(_model):
		_model.position.y = _model_y + up

## The enemy is let down again (String Up over, or it died).
func _put_down() -> void:
	if _model != null and is_instance_valid(_model):
		_model.position.y = _model_y
	_model = null

func _exit_tree() -> void:
	_put_down()
