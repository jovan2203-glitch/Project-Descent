extends Node3D

# Cinderwing's phoenix: a small bird of flame that hovers by its owner. Every
# `interval` seconds it asks its owner to cast a heal (owner.phoenix_cast()),
# and it leaves after `casts` of them, or when its owner falls.
# With casts = 0 it is only the visual (a party member's phoenix): it follows
# their character for `duration` seconds and heals nothing here - the heals
# come from its owner's machine.
# Gameplay lives in Player.phoenix_cast(); this script is the bird (swap the
# meshes built in _ready for a real model later).

const FLAME := Color(1.0, 0.55, 0.15)
const CORE := Color(1.0, 0.9, 0.45)
const HOVER := Vector3(0.9, 1.5, 0.3)   # where it floats, relative to its owner
const FOLLOW := 6.0
const FADE_TIME := 0.4

var owner_node: Node3D
var casts := 0
var interval := 1.1
var duration := 16.5

var _age := 0.0
var _t := 0.0
var _done := 0
var _ending := false
var _body: Node3D
var _wings: Array[Node3D] = []
var _mats: Array[StandardMaterial3D] = []

static func spawn(scene: Node, who: Node3D, cast_count: int, cast_interval: float, time: float = -1.0) -> Node3D:
	var n := Node3D.new()
	n.set_script(load("res://scripts/phoenix.gd"))
	n.owner_node = who
	n.casts = cast_count
	n.interval = cast_interval
	n.duration = time if time > 0.0 else life_time(cast_count, cast_interval)
	scene.add_child(n)
	if who and is_instance_valid(who):
		n.global_position = who.global_position + HOVER
	return n

## Seconds a phoenix with `cast_count` heals stays.
static func life_time(cast_count: int, cast_interval: float) -> float:
	return maxi(cast_count, 0) * maxf(cast_interval, 0.0)

## Heals still to come.
func casts_left() -> int:
	return maxi(casts - _done, 0)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 2.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats.append(m)
	return m

func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	# Body: a stretched ember.
	var torso := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.13
	sph.height = 0.26
	sph.radial_segments = 12
	sph.rings = 6
	sph.material = _mat(CORE)
	torso.mesh = sph
	torso.scale = Vector3(0.8, 0.8, 1.7)
	torso.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(torso)
	# Head and beak.
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.08
	hs.height = 0.16
	hs.radial_segments = 10
	hs.rings = 5
	hs.material = _mat(CORE)
	head.mesh = hs
	head.position = Vector3(0, 0.07, -0.26)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(head)
	# Wings: two flat flames that flap.
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.06 * side, 0.03, -0.02)
		_body.add_child(pivot)
		var wing := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.5, 0.42, 0.02)
		prism.material = _mat(FLAME)
		wing.mesh = prism
		wing.rotation = Vector3(PI / 2.0, 0, -PI / 2.0 * side)   # flat, tip pointing outward
		wing.position = Vector3(0.24 * side, 0, 0.04)
		wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(wing)
		_wings.append(pivot)
	# Tail: a long flame trailing behind.
	var tail := MeshInstance3D.new()
	var tp := PrismMesh.new()
	tp.size = Vector3(0.16, 0.5, 0.02)
	tp.material = _mat(FLAME)
	tail.mesh = tp
	tail.rotation = Vector3(-PI / 2.0, 0, 0)   # flat, tip pointing back
	tail.position = Vector3(0, 0, 0.42)
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(tail)
	# Embers falling off it.
	var bit_mat := StandardMaterial3D.new()
	bit_mat.albedo_color = CORE
	bit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bit_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var bit := QuadMesh.new()
	bit.size = Vector2(0.06, 0.06)
	bit.material = bit_mat
	var embers := CPUParticles3D.new()
	embers.amount = 20
	embers.lifetime = 0.8
	embers.local_coords = false
	embers.direction = Vector3.DOWN
	embers.spread = 30.0
	embers.gravity = Vector3(0, -1.2, 0)
	embers.initial_velocity_min = 0.1
	embers.initial_velocity_max = 0.5
	embers.mesh = bit
	add_child(embers)
	var light := OmniLight3D.new()
	light.light_color = FLAME
	light.light_energy = 1.4
	light.omni_range = 4.0
	light.shadow_enabled = false
	add_child(light)
	# Appears with a small flash.
	scale = Vector3.ONE * 0.2
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if _ending:
		return
	var alive: bool = owner_node != null and is_instance_valid(owner_node) \
		and (not owner_node.has_method("is_alive") or owner_node.is_alive())
	if not alive:
		vanish()
		return
	_age += delta
	# Hover by the owner: a slow circle around the resting spot, a gentle bob, wings flapping.
	var spot := owner_node.global_position + HOVER.rotated(Vector3.UP, _age * 0.9) \
		+ Vector3(0, sin(_age * 2.6) * 0.12, 0)
	var before := global_position
	global_position = global_position.lerp(spot, clampf(delta * FOLLOW, 0.0, 1.0))
	var moved := global_position - before
	moved.y = 0.0
	if moved.length() > 0.001:
		_body.rotation.y = lerp_angle(_body.rotation.y, atan2(-moved.x, -moved.z), clampf(delta * 8.0, 0.0, 1.0))
	var flap := sin(_age * 11.0) * 0.6
	for i in _wings.size():
		_wings[i].rotation.z = flap * (1.0 if i == 0 else -1.0)
	if casts > 0:
		_t += delta
		if _t >= interval:
			_t -= interval
			_done += 1
			if owner_node.has_method("phoenix_cast"):
				owner_node.phoenix_cast()
			_pulse()
			if _done >= casts:
				vanish()
	elif _age >= duration:
		vanish()

## A quick swell of light each time it casts.
func _pulse() -> void:
	if _ending or _body == null:
		return
	var t := _body.create_tween()
	t.tween_property(_body, "scale", Vector3.ONE * 1.35, 0.08)
	t.tween_property(_body, "scale", Vector3.ONE, 0.18)

## Leave: fade out and free.
func vanish() -> void:
	if _ending:
		return
	_ending = true
	if not is_inside_tree():
		queue_free()
		return
	var t := create_tween()
	t.set_parallel(true)
	for m in _mats:
		t.tween_property(m, "albedo_color:a", 0.0, FADE_TIME)
	t.tween_property(self, "scale", Vector3.ONE * 0.3, FADE_TIME)
	t.chain().tween_callback(queue_free)
