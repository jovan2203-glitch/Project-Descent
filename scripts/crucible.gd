extends Node3D

# Crucible: a circle on the ground for `duration` seconds. Enemies standing in
# it take more periodic Fire damage FROM ITS OWNER (Balance.CRUCIBLE_DOT_PCT; the
# bonus is added on the owner's machine, which deals their ticks, see
# Player._on_damage_modify). Own only: a party member's Crucible is shown on
# every machine (Net "crucible" fx) so everyone can see it, but it never boosts
# anyone else's burns. One Crucible per owner: placing another moves it.

const Combat = preload("res://scripts/combat_utils.gd")

const GROUP := "crucibles"
const GLOW := Color(1.0, 0.55, 0.15)
const FADE_TIME := 0.35

var radius := 5.0
var duration := 10.0
## "me" for my own, a party member's id for theirs.
var owner_key := ""

var _age := 0.0
var _ending := false
var _disc_mat: StandardMaterial3D
var _rim_mat: StandardMaterial3D
var _embers: CPUParticles3D

## Put `key`'s Crucible at `at` (their old one goes).
static func spawn(scene: Node, at: Vector3, r: float, time: float, key: String) -> Node3D:
	for c in scene.get_tree().get_nodes_in_group(GROUP):
		if str(c.owner_key) == key:
			c.vanish()
	var n := Node3D.new()
	n.set_script(load("res://scripts/crucible.gd"))
	n.radius = r
	n.duration = time
	n.owner_key = key
	scene.add_child(n)
	n.global_position = at
	return n

## Is `point` inside the circle of radius `r` around `centre`, with `pad` (the
## enemy's hitbox radius) to spare? Height is ignored.
static func inside(centre: Vector3, r: float, point: Vector3, pad: float = 0.0) -> bool:
	return Vector2(point.x - centre.x, point.z - centre.z).length() <= r + pad

## Is `who` standing in `key`'s Crucible? ("me" = my own - the only one that
## boosts my burns. A party member's Crucible is just a picture here.)
static func covers(tree: SceneTree, who: Node3D, key: String = "me") -> bool:
	for c in tree.get_nodes_in_group(GROUP):
		if str(c.owner_key) == key and c.time_left() > 0.0 and inside(c.global_position, float(c.radius), who.global_position, Combat.hitbox_radius(who)):
			return true
	return false

## Seconds it still stands (0 once it is going away).
func time_left() -> float:
	return 0.0 if _ending else maxf(duration - _age, 0.0)

func _ready() -> void:
	add_to_group(GROUP)
	# Faint glowing floor.
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.02
	cyl.radial_segments = 40
	cyl.rings = 1
	disc.mesh = cyl
	disc.position.y = 0.03
	_disc_mat = _flat(Color(GLOW, 0.14))
	disc.material_override = _disc_mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	# Bright rim so the edge is easy to read.
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(radius - 0.14, 0.1)
	torus.outer_radius = radius
	torus.rings = 48
	torus.ring_segments = 4
	rim.mesh = torus
	rim.position.y = 0.06
	rim.scale.y = 0.35
	_rim_mat = _flat(Color(GLOW.lightened(0.25), 0.9))
	rim.material_override = _rim_mat
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rim)
	# A few embers drifting up from the whole circle.
	var bit_mat := StandardMaterial3D.new()
	bit_mat.albedo_color = Color(1.0, 0.8, 0.35)
	bit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var bit := QuadMesh.new()
	bit.size = Vector2(0.09, 0.09)
	bit.material = bit_mat
	bit_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_embers = CPUParticles3D.new()
	_embers.amount = int(clampf(radius * 8.0, 16.0, 64.0))
	_embers.lifetime = 1.4
	_embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_embers.emission_ring_axis = Vector3.UP
	_embers.emission_ring_height = 0.05
	_embers.emission_ring_radius = radius
	_embers.emission_ring_inner_radius = 0.0
	_embers.direction = Vector3.UP
	_embers.spread = 8.0
	_embers.gravity = Vector3(0, 0.6, 0)
	_embers.initial_velocity_min = 0.3
	_embers.initial_velocity_max = 0.9
	_embers.mesh = bit
	_embers.position.y = 0.1
	add_child(_embers)
	var light := OmniLight3D.new()
	light.light_color = GLOW
	light.light_energy = 1.1
	light.omni_range = radius + 2.0
	light.shadow_enabled = false
	light.position.y = 1.0
	add_child(light)

static func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _process(delta: float) -> void:
	if _ending:
		return
	_age += delta
	if _age >= duration:
		vanish()

## Stop counting as a Crucible right away, then fade out.
func vanish() -> void:
	if _ending:
		return
	_ending = true
	remove_from_group(GROUP)
	if _embers:
		_embers.emitting = false
	if not is_inside_tree() or _disc_mat == null:
		queue_free()
		return
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_disc_mat, "albedo_color:a", 0.0, FADE_TIME)
	t.tween_property(_rim_mat, "albedo_color:a", 0.0, FADE_TIME)
	t.chain().tween_interval(1.0)
	t.chain().tween_callback(queue_free)
