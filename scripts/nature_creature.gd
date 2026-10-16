extends Node3D

# A creature of the Weaver (Nature caster), here for one strike. Only a picture:
# the hit itself is dealt by player.gd ("Nature caster: the Weaver") when the
# strike lands, so its timing follows Balance.WOVEN_STRIKE_DELAY / ROOTED_STRIKE_DELAY.
#   Woven (tiger, hawk): vines shoot from the caster's hand, braid together half
#   way and become the creature, which lunges and strikes, then unravels into
#   falling leaves.
#   Woven healers (fawn, owl: the Shepherd) do the same and heal instead.
#   Rooted (bear, viper, stag; roots, elk for the Shepherd): roots burst from the mulch, the creature grows out
#   of them, strikes, then sinks back into the mud.
#   The Colossus (Nature tank) uses limbs of one huge vine giant: a fist (woven,
#   over the shoulder), a hand that rises under an enemy and carries it to you,
#   a foot that stomps down from above, hands closing around you, the chest that
#   opens behind you; Awaken raises the whole giant behind you for a while.
# Every creature shares one bark material with glowing green-gold veins and one
# "grow" value (0 -> 1 to appear, back to 0 to go).
# Swap-ready: the bodies are built from simple meshes in _build_*(); real models
# (one ~0.5 s strike animation each) can replace them without touching gameplay.
# Usage: const NatureCreature = preload("res://scripts/nature_creature.gd")
#        NatureCreature.spawn(scene, "tiger", hand, enemy_pos)

const Balance = preload("res://scripts/balance.gd")

const BARK := Color(0.36, 0.25, 0.15)
const VEIN := Color(0.62, 1.0, 0.38)
const LEAF := Color(0.45, 0.85, 0.3)
const WOVEN := ["tiger", "hawk", "fawn", "owl", "fist"]
const VINE_COUNT := 3
const LEAVES := 8

var kind := "tiger"
var from := Vector3.ZERO
var to := Vector3.ZERO
var faint := false

var _body: Node3D
var _bark: StandardMaterial3D
var _vein: StandardMaterial3D
var _wings: Array[Node3D] = []
var _follow: Node3D = null   # the giant (Awaken) stands behind this one

## A creature of `kind` coming from `start` (the hand for a woven one, the mulch
## for a rooted one) to strike at `end`. `faint_` = a party member's.
static func spawn(scene: Node, kind_: String, start: Vector3, end: Vector3, faint_: bool = false, follow_: Node3D = null) -> Node3D:
	if scene == null or not is_instance_valid(scene) or not scene.is_inside_tree():
		return null
	var n := Node3D.new()
	n.set_script(load("res://scripts/nature_creature.gd"))
	n.kind = kind_
	n.from = start
	n.to = end
	n.faint = faint_
	n._follow = follow_
	scene.add_child(n)
	return n

func _ready() -> void:
	var alpha := 0.45 if faint else 1.0
	_bark = StandardMaterial3D.new()
	_bark.albedo_color = Color(BARK, alpha)
	_bark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bark.emission_enabled = true
	_bark.emission = BARK.lightened(0.2)
	_bark.emission_energy_multiplier = 0.4   # bright enough in a dark dungeon
	_vein = StandardMaterial3D.new()
	_vein.albedo_color = Color(VEIN, alpha)
	_vein.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_vein.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_vein.emission_enabled = true
	_vein.emission = VEIN
	_vein.emission_energy_multiplier = 2.0
	_body = Node3D.new()
	add_child(_body)
	match kind:
		"tiger":
			_build_tiger()
		"hawk":
			_build_hawk()
		"bear":
			_build_bear()
		"viper":
			_build_viper()
		"stag":
			_build_stag()
		"fawn":
			_build_fawn()
		"owl":
			_build_owl()
		"roots":
			_build_roots()
		"elk":
			_build_elk()
		"fist":
			_build_fist()
		"hand":
			_build_hand()
		"foot":
			_build_foot()
		"hands":
			_build_hands()
		"chest":
			_build_chest()
		"giant":
			_build_giant()
	_body.scale = Vector3.ONE * 0.01
	if kind == "foot":
		_run_foot()
	elif kind == "giant":
		_run_giant()
	elif kind in WOVEN:
		_run_woven()
	else:
		_run_rooted()

# --- The two ways in ---------------------------------------------------------------------

func _run_woven() -> void:
	var total := Balance.WOVEN_STRIKE_DELAY
	var vine_time := total * 0.45
	var lunge_time := total * 0.35
	var mid := from.lerp(to, 0.5)
	if kind == "hawk" or kind == "owl":
		mid += Vector3(0, 3.0, 0)   # it dives from above
	global_position = mid
	_face(to)
	_spawn_vines(from, mid, vine_time)
	var t := create_tween()
	t.tween_interval(vine_time)
	t.tween_property(_body, "scale", Vector3.ONE, total - vine_time - lunge_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var strike_at := to + (mid - to).normalized() * 0.6 + Vector3(0, 0.2, 0)
	t.tween_property(self, "global_position", strike_at, lunge_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(_leaves_fall)
	t.tween_property(_body, "scale", Vector3.ONE * 0.01, 0.3)
	t.tween_callback(queue_free)

func _run_rooted() -> void:
	var total := Balance.ROOTED_STRIKE_DELAY
	global_position = from
	_face(to)
	_spawn_roots(from, total * 0.5)
	_body.position = Vector3(0, -1.0, 0)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_body, "scale", Vector3.ONE, total * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_body, "position", Vector3.ZERO, total * 0.6)
	t.set_parallel(false)
	if kind == "stag":
		# It bounds to the target in an arc.
		var hop := create_tween()
		hop.tween_interval(total * 0.6)
		hop.tween_method(func(v: float): global_position = from.lerp(to, v) + Vector3(0, sin(v * PI) * 2.0, 0), 0.0, 1.0, total * 0.4)
		t.tween_interval(total * 0.4)
	elif kind == "elk" or kind == "chest":
		t.tween_property(_body, "rotation:x", 0.35, total * 0.2)   # it rears up and bellows
		t.tween_property(_body, "rotation:x", 0.0, total * 0.2)
	elif kind != "viper" and kind != "roots" and kind != "hands":
		var reach := to + (from - to).normalized() * 0.8
		t.tween_property(self, "global_position", reach, total * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		t.tween_property(_body, "rotation:y", TAU, total * 0.4)   # it coils around its prey
	t.tween_interval(0.35 if kind in ["viper", "roots", "hands", "chest"] else 0.15)
	# ... and sinks back into the mud.
	t.set_parallel(true)
	t.tween_property(_body, "position", Vector3(0, -1.2, 0), 0.45)
	t.tween_property(_body, "scale", Vector3.ONE * 0.4, 0.45)
	t.set_parallel(false)
	t.tween_callback(queue_free)

## The giant's foot comes down from above on `to`, cracks the ground, and goes.
func _run_foot() -> void:
	var total := Balance.ROOTED_STRIKE_DELAY
	global_position = to + Vector3(0, 4.0, 0)
	_face(from)
	var t := create_tween()
	t.tween_property(_body, "scale", Vector3.ONE, total * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "global_position", to, total * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func(): _spawn_roots(to, 0.2))
	t.tween_interval(0.25)
	t.tween_callback(_leaves_fall)
	t.tween_property(_body, "scale", Vector3.ONE * 0.01, 0.35)
	t.tween_callback(queue_free)

## Awaken: the whole giant grows up behind `_follow` (or stands at `from`), stays
## for AWAKEN_TIME, then unravels.
func _run_giant() -> void:
	global_position = from
	_face(to)
	_spawn_roots(from, 0.5)
	_body.position = Vector3(0, -2.0, 0)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_body, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_body, "position", Vector3.ZERO, 0.8)
	t.set_parallel(false)
	t.tween_interval(maxf(Balance.AWAKEN_TIME - 1.4, 0.1))
	t.tween_callback(_leaves_fall)
	t.tween_property(_body, "scale", Vector3.ONE * 0.01, 0.6)
	t.tween_callback(queue_free)

func _face(at: Vector3) -> void:
	var d := at - global_position
	d.y = 0.0
	if d.length() > 0.01:
		rotation.y = atan2(-d.x, -d.z)

## Vines from the hand to `end`, twisting around each other (ribbons: thin cylinders).
func _spawn_vines(start: Vector3, end: Vector3, time: float) -> void:
	var scene := get_tree().current_scene
	for i in VINE_COUNT:
		var vine := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.035
		m.bottom_radius = 0.05
		m.height = 1.0
		m.radial_segments = 5
		m.rings = 1
		m.material = _vein if i == 0 else _bark
		vine.mesh = m
		vine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		scene.add_child(vine)
		var off := Vector3(cos(TAU * i / VINE_COUNT), sin(TAU * i / VINE_COUNT), 0) * 0.15
		var a := start + off
		var b := end
		var span := maxf(a.distance_to(b), 0.05)
		var turn := along(b - a)
		vine.global_transform = Transform3D(turn.scaled_local(Vector3(1, 0.01, 1)), a)
		var t := vine.create_tween()
		t.tween_method(func(v: float):
			if is_instance_valid(vine):
				vine.global_transform = Transform3D(turn.scaled_local(Vector3(1, maxf(span * v, 0.01), 1)), a.lerp(b, v * 0.5)), 0.0, 1.0, time)
		t.tween_property(vine, "scale:x", 0.01, 0.2)
		t.tween_callback(vine.queue_free)

## Roots bursting up around `at`.
func _spawn_roots(at: Vector3, time: float) -> void:
	var scene := get_tree().current_scene
	for i in 4:
		var root := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = 0.09
		m.height = 1.1
		m.radial_segments = 5
		m.rings = 1
		m.material = _bark if i % 2 == 0 else _vein
		root.mesh = m
		root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		scene.add_child(root)
		var a := TAU * i / 4.0 + 0.4
		root.global_position = at + Vector3(cos(a) * 0.5, -0.6, sin(a) * 0.5)
		root.rotation = Vector3(cos(a) * 0.4, 0, -sin(a) * 0.4)
		var t := root.create_tween()
		t.tween_property(root, "global_position:y", at.y + 0.4, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_interval(0.3)
		t.tween_property(root, "global_position:y", at.y - 0.7, 0.4)
		t.tween_callback(root.queue_free)

## The woven creature unravels into leaves that drift down and fade.
func _leaves_fall() -> void:
	var scene := get_tree().current_scene
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(LEAF, 0.45 if faint else 1.0)
	leaf_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	leaf_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.08)
	q.material = leaf_mat
	for i in LEAVES:
		var leaf := MeshInstance3D.new()
		leaf.mesh = q
		leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		scene.add_child(leaf)
		var a := TAU * i / LEAVES
		leaf.global_position = global_position + Vector3(cos(a) * 0.3, 0.3 + 0.1 * (i % 3), sin(a) * 0.3)
		var land := leaf.global_position + Vector3(cos(a) * 0.6, -leaf.global_position.y + to.y + 0.05, sin(a) * 0.6)
		var t := leaf.create_tween()
		t.set_parallel(true)
		t.tween_property(leaf, "global_position", land, 0.7).set_ease(Tween.EASE_OUT)
		t.tween_property(leaf, "rotation", Vector3(a, a * 2.0, a), 0.7)
		t.tween_property(leaf_mat, "albedo_color:a", 0.0, 0.9)
		t.set_parallel(false)
		t.tween_callback(leaf.queue_free)

func _process(delta: float) -> void:
	for w in _wings:
		w.rotation.z = sin(Time.get_ticks_msec() / 60.0) * 0.6 * signf(w.position.x)
	if kind == "giant" and _follow != null and is_instance_valid(_follow):
		# The giant stands behind the one it fights through and turns with them.
		var want := _follow.global_position + _follow.global_transform.basis.z * 1.6
		global_position = global_position.lerp(want, minf(delta * 6.0, 1.0))
		rotation.y = lerp_angle(rotation.y, _follow.rotation.y, minf(delta * 6.0, 1.0))

# --- Bodies (placeholders built from simple meshes) ----------------------------------------

func _part(mesh: Mesh, at: Vector3, rot: Vector3 = Vector3.ZERO, vein: bool = false, parent: Node3D = null) -> MeshInstance3D:
	var p := MeshInstance3D.new()
	p.mesh = mesh
	p.material_override = _vein if vein else _bark
	p.position = at
	p.rotation = rot
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else _body).add_child(p)
	return p

func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 8
	m.rings = 2
	return m

func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 8
	m.rings = 4
	return m

func _rod(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 5
	m.rings = 1
	return m

## A glowing vein along a body part (from `a` to `b`).
func _vein_line(a: Vector3, b: Vector3, r: float = 0.025) -> void:
	var v := _part(_rod(r, a.distance_to(b)), a.lerp(b, 0.5), Vector3.ZERO, true)
	v.basis = along(b - a)

## A basis that turns a mesh's Y axis (a cylinder's length) to point along `dir`.
static func along(dir: Vector3) -> Basis:
	var d := dir.normalized() if dir.length() > 0.001 else Vector3.UP
	var up := Vector3.UP if absf(d.y) < 0.95 else Vector3.FORWARD
	return Basis.looking_at(d, up) * Basis(Vector3.RIGHT, -PI / 2.0)

## Four legs under a body of `length` x `height`.
func _legs(length: float, height: float, r: float) -> void:
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_part(_rod(r, height), Vector3(x * r * 2.2, height * 0.5, z * length * 0.35))

func _build_tiger() -> void:
	_part(_capsule(0.28, 1.4), Vector3(0, 0.65, 0), Vector3(PI / 2.0, 0, 0))
	_part(_sphere(0.24), Vector3(0, 0.85, -0.8))
	_part(_capsule(0.05, 0.8), Vector3(0, 0.8, 0.85), Vector3(PI / 3.0, 0, 0))
	_legs(1.2, 0.55, 0.08)
	_vein_line(Vector3(0, 0.93, 0.6), Vector3(0, 0.93, -0.6))
	_vein_line(Vector3(0.2, 0.8, 0.3), Vector3(0.2, 0.55, 0.1), 0.02)
	_vein_line(Vector3(-0.2, 0.8, -0.2), Vector3(-0.2, 0.55, -0.4), 0.02)
	_part(_sphere(0.04), Vector3(0.1, 0.92, -0.98), Vector3.ZERO, true)
	_part(_sphere(0.04), Vector3(-0.1, 0.92, -0.98), Vector3.ZERO, true)

func _build_hawk() -> void:
	_part(_capsule(0.14, 0.6), Vector3(0, 0, 0), Vector3(PI / 2.0, 0, 0))
	_part(_sphere(0.12), Vector3(0, 0.05, -0.32))
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(side * 0.1, 0.02, 0)
		_body.add_child(wing)
		var box := BoxMesh.new()
		box.size = Vector3(0.7, 0.03, 0.3)
		_part(box, Vector3(side * 0.35, 0, 0), Vector3.ZERO, false, wing)
		var edge := BoxMesh.new()
		edge.size = Vector3(0.7, 0.035, 0.04)
		_part(edge, Vector3(side * 0.35, 0.01, -0.13), Vector3.ZERO, true, wing)
		_wings.append(wing)
	_part(_sphere(0.03), Vector3(0, 0.1, -0.42), Vector3.ZERO, true)

func _build_bear() -> void:
	_part(_capsule(0.5, 1.7), Vector3(0, 0.95, 0), Vector3(PI / 2.0, 0, 0))
	_part(_sphere(0.36), Vector3(0, 1.35, -0.95))
	_part(_sphere(0.1), Vector3(0.22, 1.65, -0.9))
	_part(_sphere(0.1), Vector3(-0.22, 1.65, -0.9))
	_legs(1.4, 0.8, 0.15)
	_vein_line(Vector3(0, 1.45, 0.7), Vector3(0, 1.45, -0.6), 0.035)
	_vein_line(Vector3(0.45, 1.0, 0.4), Vector3(0.4, 0.6, -0.1), 0.03)
	_vein_line(Vector3(-0.45, 1.0, 0.2), Vector3(-0.4, 0.6, -0.3), 0.03)
	_part(_sphere(0.05), Vector3(0.14, 1.45, -1.25), Vector3.ZERO, true)
	_part(_sphere(0.05), Vector3(-0.14, 1.45, -1.25), Vector3.ZERO, true)

func _build_viper() -> void:
	# A coil of beads rising in a spiral, head up.
	for i in 9:
		var t := i / 8.0
		var a := t * TAU * 1.5
		_part(_sphere(0.11 - t * 0.04), Vector3(cos(a) * 0.4, 0.1 + t * 1.0, sin(a) * 0.4), Vector3.ZERO, i % 3 == 1)
	_part(_sphere(0.1), Vector3(cos(TAU * 1.5) * 0.4, 1.2, sin(TAU * 1.5) * 0.4 - 0.1))

func _build_stag() -> void:
	_part(_capsule(0.26, 1.3), Vector3(0, 1.0, 0), Vector3(PI / 2.0, 0, 0))
	_part(_capsule(0.1, 0.6), Vector3(0, 1.35, -0.6), Vector3(-PI / 5.0, 0, 0))
	_part(_sphere(0.15), Vector3(0, 1.65, -0.8))
	_legs(1.1, 0.95, 0.06)
	# Antlers: branching glowing veins.
	for side in [-1.0, 1.0]:
		var base := Vector3(side * 0.08, 1.78, -0.8)
		var tip := base + Vector3(side * 0.35, 0.55, 0.1)
		_vein_line(base, tip, 0.03)
		_vein_line(base.lerp(tip, 0.5), base.lerp(tip, 0.5) + Vector3(side * 0.05, 0.25, -0.15), 0.022)
		_vein_line(base.lerp(tip, 0.8), base.lerp(tip, 0.8) + Vector3(side * 0.2, 0.15, 0.05), 0.022)
	_vein_line(Vector3(0, 1.27, 0.55), Vector3(0, 1.27, -0.45))

func _build_fawn() -> void:
	# A small deer without antlers, pale spots along its back.
	_part(_capsule(0.18, 0.9), Vector3(0, 0.7, 0), Vector3(PI / 2.0, 0, 0))
	_part(_capsule(0.07, 0.4), Vector3(0, 0.95, -0.4), Vector3(-PI / 5.0, 0, 0))
	_part(_sphere(0.11), Vector3(0, 1.15, -0.55))
	for side in [-1.0, 1.0]:
		_part(_capsule(0.03, 0.2), Vector3(side * 0.1, 1.27, -0.5), Vector3(0, 0, side * 0.6))
	_legs(0.8, 0.65, 0.04)
	for z in [-0.2, 0.0, 0.2]:
		_part(_sphere(0.035), Vector3(0.08, 0.86, z), Vector3.ZERO, true)
		_part(_sphere(0.035), Vector3(-0.08, 0.86, z + 0.1), Vector3.ZERO, true)

func _build_owl() -> void:
	# A round owl, wings spread, two big glowing eyes.
	_part(_sphere(0.22), Vector3(0, 0, 0))
	_part(_sphere(0.16), Vector3(0, 0.22, -0.05))
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.position = Vector3(side * 0.15, 0.05, 0)
		_body.add_child(wing)
		var box := BoxMesh.new()
		box.size = Vector3(0.6, 0.03, 0.32)
		_part(box, Vector3(side * 0.3, 0, 0), Vector3.ZERO, false, wing)
		_wings.append(wing)
		_part(_sphere(0.05), Vector3(side * 0.07, 0.25, -0.18), Vector3.ZERO, true)
		_part(_capsule(0.025, 0.12), Vector3(side * 0.1, 0.38, -0.05), Vector3(0, 0, side * 0.4))

func _build_roots() -> void:
	# Roots rising in a ring and bending inward around the ally, like a cage.
	for i in 6:
		var a := TAU * i / 6.0
		var base := Vector3(cos(a) * 0.7, 0.0, sin(a) * 0.7)
		var top := Vector3(cos(a + 0.5) * 0.35, 1.7, sin(a + 0.5) * 0.35)
		var r := _part(_rod(0.06, base.distance_to(top)), base.lerp(top, 0.5), Vector3.ZERO, i % 2 == 1)
		r.basis = along(top - base)

func _build_elk() -> void:
	# A big elk with wide palm antlers and a glowing heart.
	_part(_capsule(0.42, 1.8), Vector3(0, 1.3, 0), Vector3(PI / 2.0, 0, 0))
	_part(_capsule(0.16, 0.8), Vector3(0, 1.8, -0.85), Vector3(-PI / 5.0, 0, 0))
	_part(_sphere(0.22), Vector3(0, 2.2, -1.1))
	_legs(1.5, 1.2, 0.09)
	_part(_sphere(0.14), Vector3(0, 1.4, -0.75), Vector3.ZERO, true)
	for side in [-1.0, 1.0]:
		var base := Vector3(side * 0.12, 2.38, -1.1)
		var tip := base + Vector3(side * 0.6, 0.55, 0.15)
		_vein_line(base, tip, 0.04)
		var palm := BoxMesh.new()
		palm.size = Vector3(0.5, 0.05, 0.3)
		_part(palm, tip + Vector3(side * -0.05, 0.05, 0), Vector3(0, 0, side * 0.5), true)
		_vein_line(base.lerp(tip, 0.5), base.lerp(tip, 0.5) + Vector3(0, 0.3, -0.2), 0.03)
	_vein_line(Vector3(0, 1.75, 0.8), Vector3(0, 1.75, -0.6), 0.04)

# The Colossus: limbs of one vine giant (about three times a person's height).

func _build_fist() -> void:
	# A fist of braided vines on a short forearm, glowing knuckles.
	var fist := BoxMesh.new()
	fist.size = Vector3(0.7, 0.6, 0.6)
	_part(fist, Vector3(0, 0, -0.2))
	_part(_capsule(0.24, 1.0), Vector3(0, 0, 0.45), Vector3(PI / 2.0, 0, 0))
	for x in [-0.24, -0.08, 0.08, 0.24]:
		_part(_sphere(0.07), Vector3(x, 0.2, -0.52), Vector3.ZERO, true)
	_vein_line(Vector3(0.25, 0.1, 0.9), Vector3(0.2, 0.1, -0.1), 0.03)
	_vein_line(Vector3(-0.25, -0.1, 0.8), Vector3(-0.2, -0.15, 0.0), 0.03)

func _build_hand() -> void:
	# A huge open hand reaching up out of the ground, fingers curled.
	var palm := BoxMesh.new()
	palm.size = Vector3(1.0, 0.25, 0.9)
	_part(palm, Vector3(0, 0.3, 0))
	for i in 4:
		var x := -0.36 + i * 0.24
		_part(_capsule(0.09, 0.7), Vector3(x, 0.75, -0.4), Vector3(-0.6, 0, 0))
	_part(_capsule(0.1, 0.6), Vector3(0.6, 0.6, 0.0), Vector3(0, 0, -0.8))
	_vein_line(Vector3(-0.3, 0.45, 0.3), Vector3(0.3, 0.45, -0.3), 0.035)
	_part(_capsule(0.3, 1.2), Vector3(0, -0.4, 0.2))

func _build_foot() -> void:
	# A giant foot and ankle, veins along the top.
	var sole := BoxMesh.new()
	sole.size = Vector3(1.4, 0.5, 2.2)
	_part(sole, Vector3(0, 0.25, -0.2))
	_part(_capsule(0.5, 2.0), Vector3(0, 1.3, 0.4))
	for x in [-0.45, -0.15, 0.15, 0.45]:
		_part(_sphere(0.16), Vector3(x, 0.3, -1.3))
	_vein_line(Vector3(0, 0.52, 0.6), Vector3(0, 0.52, -1.1), 0.045)
	_vein_line(Vector3(0.4, 1.6, 0.4), Vector3(0.4, 0.6, 0.2), 0.035)

func _build_hands() -> void:
	# Two giant hands closing around you, fingers meeting over your head.
	for side in [-1.0, 1.0]:
		var palm := BoxMesh.new()
		palm.size = Vector3(0.2, 1.4, 1.0)
		_part(palm, Vector3(side * 0.95, 0.8, 0), Vector3(0, 0, side * 0.15))
		for i in 4:
			var z := -0.36 + i * 0.24
			var base := Vector3(side * 0.9, 1.5, z)
			var top := Vector3(side * 0.25, 2.3, z)
			var f := _part(_rod(0.08, base.distance_to(top)), base.lerp(top, 0.5), Vector3.ZERO, i == 1)
			f.basis = along(top - base)
		_vein_line(Vector3(side * 0.86, 0.3, 0), Vector3(side * 0.86, 1.4, 0), 0.035)

func _build_chest() -> void:
	# The giant's chest behind you, split open over a glowing heart of sap.
	_part(_capsule(0.9, 3.2), Vector3(0, 1.6, 0))
	_part(_sphere(0.35), Vector3(0, 1.9, -0.75), Vector3.ZERO, true)
	for side in [-1.0, 1.0]:
		var door := BoxMesh.new()
		door.size = Vector3(0.5, 1.4, 0.15)
		_part(door, Vector3(side * 0.55, 1.9, -0.95), Vector3(0, side * 0.7, 0))
	_vein_line(Vector3(0, 2.4, -0.85), Vector3(0, 0.3, -0.85), 0.05)

func _build_giant() -> void:
	# The whole giant: legs, a broad trunk, arms and a head with glowing eyes.
	for side in [-1.0, 1.0]:
		_part(_capsule(0.32, 2.2), Vector3(side * 0.55, 1.1, 0))
		_part(_capsule(0.28, 2.4), Vector3(side * 1.25, 3.1, -0.1), Vector3(-0.3, 0, side * 0.25))
		var fist := BoxMesh.new()
		fist.size = Vector3(0.6, 0.6, 0.6)
		_part(fist, Vector3(side * 1.45, 1.9, -0.45))
		_vein_line(Vector3(side * 1.2, 4.0, 0.0), Vector3(side * 1.4, 2.2, -0.35), 0.04)
		_part(_sphere(0.09), Vector3(side * 0.2, 5.05, -0.45), Vector3.ZERO, true)
	_part(_capsule(0.95, 2.8), Vector3(0, 3.4, 0))
	_part(_sphere(0.5), Vector3(0, 5.0, -0.1))
	_vein_line(Vector3(0, 4.5, -0.9), Vector3(0, 2.4, -0.9), 0.06)
	_vein_line(Vector3(-0.5, 4.2, -0.8), Vector3(0.4, 2.9, -0.85), 0.04)
	for i in 5:
		var a := -0.8 + i * 0.4
		_vein_line(Vector3(sin(a) * 0.3, 5.4, -0.1), Vector3(sin(a) * 0.6, 5.9, 0.0), 0.03)
