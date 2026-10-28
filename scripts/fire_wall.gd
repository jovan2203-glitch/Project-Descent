extends Node3D

# Wall of Fire: a line of flames across the ground for `duration` seconds.
# The wall's length runs along its local X axis and its thickness along local
# Z. Every `tick` seconds each enemy standing in it takes `damage` (a
# coefficient) as periodic Fire damage from `source`. With damage 0 it is only
# the visual (what the rest of the party sees).

const Combat = preload("res://scripts/combat_utils.gd")

var length := 8.0
var depth := 2.0
var duration := 8.0
var tick := 0.5
var damage := 0.25
var tags := PackedStringArray(["Fire", "Spell", "AoE"])
var source: Node = null   # the caster; damage is theirs
## Made by my free cast (Rune of the Wild Page): its hits are echoes too.
var echo := false
## Name of its ticks in logs and meters ("dot_<effect_id>"): Wall of Fire, the
## line Cinder Step leaves, a Smoldering Debris patch.
var effect_id := "walloffire"
## Passive damage (a Smoldering Debris patch): never builds or spends "your next
## Fire spell" buffs (DamageInfo.no_empower).
var passive := false

const FADE_TIME := 0.5
const FLAME_COLOR := Color(1.0, 0.5, 0.12)

var _age := 0.0
var _tick_t := 0.0
var _ending := false
var _ground_mat: StandardMaterial3D
var _flames: CPUParticles3D

## Is a point (in the wall's local space) inside a wall `wall_length` x
## `wall_depth`, with `pad` (the enemy's hitbox radius) to spare? Height is ignored.
static func in_wall(local: Vector3, wall_length: float, wall_depth: float, pad: float = 0.0) -> bool:
	return absf(local.x) <= wall_length * 0.5 + pad and absf(local.z) <= wall_depth * 0.5 + pad

func _ready() -> void:
	# Scorched, glowing strip on the ground.
	var strip := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(length, depth)
	quad.orientation = PlaneMesh.FACE_Y
	strip.mesh = quad
	strip.position.y = 0.04
	_ground_mat = StandardMaterial3D.new()
	_ground_mat.albedo_color = Color(FLAME_COLOR, 0.45)
	_ground_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ground_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ground_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	strip.material_override = _ground_mat
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(strip)

	# Flames rising along the whole length.
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.75, 0.3)
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.emission_enabled = true
	flame_mat.emission = FLAME_COLOR
	flame_mat.emission_energy_multiplier = 2.0
	var bit := PrismMesh.new()
	bit.size = Vector3(0.28, 0.55, 0.28)
	bit.material = flame_mat
	_flames = CPUParticles3D.new()
	_flames.amount = int(clampf(length * 9.0, 24.0, 120.0))
	_flames.lifetime = 0.7
	_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_flames.emission_box_extents = Vector3(length * 0.5, 0.05, depth * 0.35)
	_flames.direction = Vector3.UP
	_flames.spread = 12.0
	_flames.gravity = Vector3(0, 1.5, 0)
	_flames.initial_velocity_min = 1.6
	_flames.initial_velocity_max = 3.0
	_flames.scale_amount_min = 0.5
	_flames.scale_amount_max = 1.2
	_flames.mesh = bit
	_flames.position.y = 0.15
	add_child(_flames)

	# One warm light, no shadows (cheap).
	var light := OmniLight3D.new()
	light.light_color = FLAME_COLOR
	light.light_energy = 1.8
	light.omni_range = length * 0.5 + 3.0
	light.shadow_enabled = false
	light.position.y = 1.2
	add_child(light)

	# The first tick lands as the wall appears. Deferred: whoever spawned the wall
	# puts it in place right after adding it to the scene, so a tick fired from
	# here would burn the world origin instead (that lost every first tick).
	_burn.call_deferred()

func _process(delta: float) -> void:
	if _ending:
		return
	_age += delta
	if _age >= duration:
		_ending = true
		_flames.emitting = false
		var t := create_tween()
		t.tween_property(_ground_mat, "albedo_color:a", 0.0, FADE_TIME)
		t.tween_interval(_flames.lifetime)
		t.tween_callback(queue_free)
		return
	_tick_t += delta
	if _tick_t >= tick:
		_tick_t -= tick
		_burn()

func _burn() -> void:
	if damage <= 0.0 or source == null or not is_instance_valid(source):
		return
	var cs := get_node_or_null("/root/CombatSystem")
	if cs == null:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D) or not e.is_alive():
			continue
		if in_wall(to_local(e.global_position), length, depth, Combat.hitbox_radius(e)):
			Combat.run_as(source, echo, func(): cs.deal_dot(source, e, damage, "fire", effect_id, tags, null, -1.0, 1.0, passive))

func _enter_tree() -> void:
	echo = Combat.echoing(source)
