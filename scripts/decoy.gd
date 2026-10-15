extends Node3D

# A Decoy (Arcane tank): one of the tank's Reflections, sent to stand at a spot.
# For `duration` seconds the enemies around it attack it instead of whoever they
# were fighting; then it is gone, and the tank's own machine deals its burst
# (player.gd, "Decoy").
# It has no health: a blow on it lands on nothing (enemy.gd, _hits_decoy).
# A real one (taunt_radius > 0) only exists where enemies are simulated: offline,
# or on the host, which makes it for a party member too (Net.decoy). Everywhere
# else it is a picture.
# Usage: const Decoy = preload("res://scripts/decoy.gd")

const Reflections = preload("res://scripts/reflections.gd")
const Combat = preload("res://scripts/combat_utils.gd")

## Enemies can only be told to attack something in this group (enemy.gd, distract).
const GROUP := "decoys"
const FADE_TIME := 0.3
## Height of a character's centre over its feet: the Decoy's origin is there too,
## so enemies aim at it the way they aim at a player.
const CENTRE_HEIGHT := 0.9

## Whose it is (the player, or a party member's puppet): it looks like them, and
## an enemy it draws in fights them once it is gone.
var owner_body: Node3D = null
var duration := 3.0
## Metres around it from which enemies are made to attack it (0 = a picture only).
var taunt_radius := 0.0

var _age := 0.0
var _alive := true
var _mat: ShaderMaterial
var _ring_mat: StandardMaterial3D

## Stand a Decoy of `whose` at `at` (the height of a character's centre), facing
## `yaw`, for `time` seconds. `radius` > 0 makes it real: enemies within that
## many metres that can see it attack it.
static func spawn(scene: Node, whose: Node3D, at: Vector3, yaw: float, time: float, radius: float = 0.0) -> Node3D:
	if scene == null or not scene.is_inside_tree():
		return null
	var d := Node3D.new()
	d.set_script(load("res://scripts/decoy.gd"))
	d.owner_body = whose
	d.duration = maxf(time, 0.1)
	d.taunt_radius = maxf(radius, 0.0)
	scene.add_child(d)
	d.global_position = at
	d.rotation.y = yaw
	d.start()
	return d

## Is `enemy_pos` (an enemy with a hitbox `hitbox` metres wide on the ground)
## within `radius` metres of a Decoy at `decoy_pos`? Measured on the ground.
static func in_reach(decoy_pos: Vector3, enemy_pos: Vector3, hitbox: float, radius: float) -> bool:
	return Vector2(enemy_pos.x - decoy_pos.x, enemy_pos.z - decoy_pos.z).length() - hitbox <= radius

func _ready() -> void:
	_build()

## Enemies in reach turn on it. Called once it stands where it should.
func start() -> void:
	if taunt_radius <= 0.0 or not _alive:
		return
	add_to_group(GROUP)
	var whose: Node = owner_body if owner_body != null and is_instance_valid(owner_body) else null
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D) or not e.has_method("distract") or not e.is_alive():
			continue
		if not in_reach(global_position, e.global_position, Combat.hitbox_radius(e), taunt_radius):
			continue
		if not Combat.line_of_sight(get_world_3d(), Combat.sight_point(self), Combat.sight_point(e)):
			continue
		e.distract(self, duration, whose)

func _build() -> void:
	_mat = Reflections.glass_material()
	_mat.set_shader_parameter("fade", 0.0)
	var model: Node3D = null
	if owner_body != null and is_instance_valid(owner_body):
		model = owner_body.get_node_or_null("Model") as Node3D
	if model != null:
		var copy := Reflections.make_copy(model, _mat)
		add_child(copy)
		copy.rotation.x = 0.0   # (it stands, whatever its owner is doing)
		var anim := copy.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim != null and anim.has_animation("player/idle"):
			anim.play("player/idle")
	else:
		# No model to copy (a character that is still loading): a plain figure.
		var body := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.35
		cap.height = 1.7
		body.mesh = cap
		body.position.y = 0.85 - CENTRE_HEIGHT
		body.material_override = _mat
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(body)
	# A ring on the ground under it, so it is easy to find in a pack.
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.albedo_color = Color(Reflections.TINT.lightened(0.3), 0.0)
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.65
	torus.rings = 24
	torus.ring_segments = 4
	ring.mesh = torus
	ring.position.y = 0.05 - CENTRE_HEIGHT
	ring.scale.y = 0.35
	ring.material_override = _ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var t := create_tween().set_parallel(true)
	t.tween_method(_set_fade, 0.0, 1.0, FADE_TIME)
	t.tween_property(_ring_mat, "albedo_color:a", 0.85, FADE_TIME)

func _set_fade(v: float) -> void:
	if _mat:
		_mat.set_shader_parameter("fade", v)

func _set_flash(v: float) -> void:
	if _mat:
		_mat.set_shader_parameter("flash", v)

## Still standing? (Enemies stop attacking it the moment it is not.)
func is_alive() -> bool:
	return _alive

## An enemy's blow landed on it: it shimmers. Nothing is dealt.
func struck(_by: Node = null) -> void:
	if _alive and is_inside_tree():
		create_tween().tween_method(_set_flash, 0.6, 0.0, 0.2)

func _process(delta: float) -> void:
	if not _alive:
		return
	_age += delta
	if _age >= duration:
		vanish()

## It is gone: it swells, whitens and fades.
func vanish() -> void:
	if not _alive:
		return
	_alive = false
	if is_in_group(GROUP):
		remove_from_group(GROUP)
	if not is_inside_tree():
		queue_free()
		return
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "scale", Vector3.ONE * 1.3, FADE_TIME).set_ease(Tween.EASE_OUT)
	t.tween_method(_set_flash, 1.0, 0.0, FADE_TIME)
	t.tween_method(_set_fade, 1.0, 0.0, FADE_TIME)
	t.tween_property(_ring_mat, "albedo_color:a", 0.0, FADE_TIME)
	t.chain().tween_callback(queue_free)
