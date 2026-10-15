extends Node3D

# Cinder Rain: burning arrows fall on a circle for `duration` seconds. Every
# `tick` seconds each enemy standing in it takes `damage` (a coefficient) as
# periodic Fire damage from `source`. More than Balance.AOE_TARGET_CAP enemies
# share that many enemies' damage evenly (nobody ever takes 0). With damage 0
# it is only the visual (what the rest of the party sees).

const Combat = preload("res://scripts/combat_utils.gd")
const Balance = preload("res://scripts/balance.gd")

var radius := 4.0
var duration := 4.0
var tick := 0.5
var damage := 0.25
var tags := PackedStringArray(["Ability", "Fire", "Ranged", "AoE"])
var source: Node = null   # the archer; damage is theirs
## Name of its ticks in logs and meters ("dot_<effect_id>").
var effect_id := "cinderrain"

const FADE_TIME := 0.4
const GLOW := Color(1.0, 0.5, 0.12)
const FALL_HEIGHT := 7.0
const FALL_TIME := 0.22
const ARROWS_PER_SECOND := 16.0

var _age := 0.0
var _tick_t := 0.0
var _arrow_t := 0.0
var _ending := false
var _disc_mat: StandardMaterial3D
var _shaft_mesh: CylinderMesh
var _tip_mesh: CylinderMesh

## Is `point` inside the circle of radius `r` around `centre`, with `pad` (the
## enemy's hitbox radius) to spare? Height is ignored.
static func inside(centre: Vector3, r: float, point: Vector3, pad: float = 0.0) -> bool:
	return Vector2(point.x - centre.x, point.z - centre.z).length() <= r + pad

## Ticks it deals over its life: one as it lands, then one every `tick_time`.
static func tick_count(time: float, tick_time: float) -> int:
	return int(ceil(time / maxf(tick_time, 0.05) - 0.0001))

func _ready() -> void:
	# Scorched, glowing circle on the ground.
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.02
	cyl.radial_segments = 36
	cyl.rings = 1
	disc.mesh = cyl
	disc.position.y = 0.03
	_disc_mat = StandardMaterial3D.new()
	_disc_mat.albedo_color = Color(GLOW, 0.3)
	_disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_disc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	disc.material_override = _disc_mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.5, 0.34, 0.2)
	_shaft_mesh = CylinderMesh.new()
	_shaft_mesh.top_radius = 0.02
	_shaft_mesh.bottom_radius = 0.02
	_shaft_mesh.height = 0.7
	_shaft_mesh.material = wood
	var ember := StandardMaterial3D.new()
	ember.albedo_color = Color(1.0, 0.8, 0.35)
	ember.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember.emission_enabled = true
	ember.emission = GLOW
	ember.emission_energy_multiplier = 2.5
	_tip_mesh = CylinderMesh.new()
	_tip_mesh.top_radius = 0.06
	_tip_mesh.bottom_radius = 0.0
	_tip_mesh.height = 0.16
	_tip_mesh.material = ember

	# One warm light, no shadows (cheap).
	var light := OmniLight3D.new()
	light.light_color = GLOW
	light.light_energy = 1.6
	light.omni_range = radius + 3.0
	light.shadow_enabled = false
	light.position.y = 1.5
	add_child(light)

	for i in 5:
		_drop_arrow()
	_burn()   # the first tick lands with the first arrows

func _process(delta: float) -> void:
	if _ending:
		return
	_age += delta
	if _age >= duration:
		_ending = true
		var t := create_tween()
		t.tween_property(_disc_mat, "albedo_color:a", 0.0, FADE_TIME)
		t.tween_interval(0.3)
		t.tween_callback(queue_free)
		return
	_arrow_t += delta * ARROWS_PER_SECOND
	while _arrow_t >= 1.0:
		_arrow_t -= 1.0
		_drop_arrow()
	_tick_t += delta
	if _tick_t >= tick:
		_tick_t -= tick
		_burn()

## One burning arrow falling somewhere in the circle (visual only).
func _drop_arrow() -> void:
	var angle := randf() * TAU
	var dist := sqrt(randf()) * radius * 0.95
	var ground := Vector3(cos(angle) * dist, 0.3, sin(angle) * dist)
	var arrow := Node3D.new()
	var shaft := MeshInstance3D.new()
	shaft.mesh = _shaft_mesh
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arrow.add_child(shaft)
	var tip := MeshInstance3D.new()
	tip.mesh = _tip_mesh
	tip.position.y = -0.43
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arrow.add_child(tip)
	arrow.rotation = Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))
	arrow.position = ground + Vector3(0, FALL_HEIGHT, 0)
	add_child(arrow)
	var t := arrow.create_tween()
	t.tween_property(arrow, "position", ground, FALL_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_interval(0.35)
	t.tween_callback(arrow.queue_free)

func _burn() -> void:
	if damage <= 0.0 or source == null or not is_instance_valid(source):
		return
	var cs := get_node_or_null("/root/CombatSystem")
	if cs == null:
		return
	var hit: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node3D and e.is_alive() and inside(global_position, radius, e.global_position, Combat.hitbox_radius(e)):
			hit.append(e)
	var share: float = Balance.aoe_share(hit.size())
	for e in hit:
		cs.deal_dot(source, e, damage * share, "fire", effect_id, tags)
