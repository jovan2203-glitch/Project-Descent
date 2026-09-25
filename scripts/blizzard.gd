extends Node3D

# Blizzard area effect: icicles rain down for `duration` seconds. Every
# `wave_interval` a wave lands and damages every enemy inside `radius`.

const CIRCLE_SHADER: Shader = preload("res://shaders/aoe_circle.gdshader")
const Combat = preload("res://scripts/combat_utils.gd")

@export var radius: float = 2.5
@export var duration: float = 3.0
@export var wave_interval: float = 0.5
@export var damage: int = 1
@export var icicles_per_wave: int = 7
var source: Node = null   # the player; damage goes through source.deal_damage()

const FALL_HEIGHT := 6.0
const FALL_TIME := 0.3

var _waves_total: int
var _waves_spawned := 0
var _wave_timer := 0.0
var _ice_mat: StandardMaterial3D
var _icicle_mesh: PrismMesh
var _circle_mat: ShaderMaterial

func _ready() -> void:
	_waves_total = int(round(duration / wave_interval))

	_ice_mat = StandardMaterial3D.new()
	_ice_mat.albedo_color = Color(0.75, 0.95, 1.0)
	_ice_mat.emission_enabled = true
	_ice_mat.emission = Color(0.35, 0.8, 1.0)
	_ice_mat.emission_energy_multiplier = 2.0
	_ice_mat.roughness = 0.15

	_icicle_mesh = PrismMesh.new()
	_icicle_mesh.size = Vector3(0.14, 0.7, 0.14)
	_icicle_mesh.material = _ice_mat

	# Ground circle
	var circle := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(radius * 2.0, radius * 2.0)
	quad.orientation = PlaneMesh.FACE_Y
	circle.mesh = quad
	circle.position.y = 0.03
	_circle_mat = ShaderMaterial.new()
	_circle_mat.shader = CIRCLE_SHADER
	_circle_mat.set_shader_parameter("pulse", 1.0)
	circle.material_override = _circle_mat
	circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(circle)

	# Cold light
	var light := OmniLight3D.new()
	light.light_color = Color(0.45, 0.8, 1.0)
	light.light_energy = 1.6
	light.omni_range = radius + 3.0
	light.position.y = 2.0
	add_child(light)

	# Swirling snow
	var snow := CPUParticles3D.new()
	snow.amount = 80
	snow.lifetime = 1.4
	snow.position.y = 3.5
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	snow.emission_sphere_radius = radius
	snow.direction = Vector3(0, -1, 0)
	snow.spread = 25.0
	snow.gravity = Vector3(0, -2.0, 0)
	snow.initial_velocity_min = 1.0
	snow.initial_velocity_max = 2.0
	var flake := SphereMesh.new()
	flake.radius = 0.035
	flake.height = 0.07
	flake.radial_segments = 4
	flake.rings = 2
	flake.material = _ice_mat
	snow.mesh = flake
	add_child(snow)

	_spawn_wave()  # first wave right away

func _process(delta: float) -> void:
	if _waves_spawned >= _waves_total:
		return
	_wave_timer += delta
	if _wave_timer >= wave_interval:
		_wave_timer -= wave_interval
		_spawn_wave()

func _spawn_wave() -> void:
	_waves_spawned += 1
	for i in icicles_per_wave:
		_drop_icicle(i == 0)
	if _waves_spawned >= _waves_total:
		# Fade out after the last wave lands.
		var t := create_tween()
		t.tween_interval(FALL_TIME + 0.2)
		t.tween_method(func(a): _circle_mat.set_shader_parameter("fill_alpha", a), 0.18, 0.0, 0.4)
		t.parallel().tween_method(func(a): _circle_mat.set_shader_parameter("rim_alpha", a), 0.9, 0.0, 0.4)
		t.tween_callback(queue_free)

func _drop_icicle(deals_damage: bool) -> void:
	var angle := randf() * TAU
	var dist := sqrt(randf()) * radius * 0.9
	var ground := Vector3(cos(angle) * dist, 0.35, sin(angle) * dist)

	var ice := MeshInstance3D.new()
	ice.mesh = _icicle_mesh
	ice.rotation = Vector3(PI, randf() * TAU, 0)  # point down
	ice.position = ground + Vector3(0, FALL_HEIGHT, 0)
	ice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ice)

	var delay := randf() * 0.12
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_property(ice, "position", ground, FALL_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	if deals_damage:
		# One icicle per wave carries the damage so each wave hits exactly once.
		t.tween_callback(_damage_wave)
	t.tween_property(ice, "scale", Vector3(1.6, 0.05, 1.6), 0.15)
	t.tween_callback(ice.queue_free)

func _damage_wave() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D) or not e.is_alive():
			continue
		var d := Vector2(e.global_position.x - global_position.x, e.global_position.z - global_position.z)
		if d.length() <= radius + Combat.hitbox_radius(e):
			if is_instance_valid(source) and source.has_method("deal_damage"):
				source.deal_damage(e, damage, "blizzard")
			else:
				e.take_damage(damage)
