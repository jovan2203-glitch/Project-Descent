extends Node3D

# Ball Lightning: a slow orb that drifts along `direction` for `duration`
# seconds and stops at walls. Every `tick` seconds it zaps each enemy within
# `radius` that it can see: `damage` (a coefficient) as periodic Lightning
# damage from `source`, and it tells its source how many zaps landed
# (Player.ball_lightning_zapped gives the Energy). More than AOE_TARGET_CAP
# enemies share that many zaps' damage.
# With damage 0 it is only the picture (a party member's orb): the damage and
# the Energy come from its caster's machine.

const Combat = preload("res://scripts/combat_utils.gd")
const Balance = preload("res://scripts/balance.gd")

const GLOW := Color(0.45, 0.55, 1.0)
const CORE := Color(0.92, 0.95, 1.0)
## Height the orb floats at, above the caster's feet.
const FLOAT_HEIGHT := 1.1
const FADE_TIME := 0.3
## Seconds an arc to a zapped enemy stays on screen.
const ARC_TIME := 0.12
## Metres ahead the orb looks for a wall.
const WALL_GAP := 0.5

var direction := Vector3.FORWARD
var speed := 2.5
var duration := 8.0
var tick := 0.5
var radius := 5.0
var damage := 0.0
var tags := PackedStringArray(["Lightning", "Spell", "AoE"])
var source: Node = null   # the caster; damage and Energy are theirs
## Name of its zaps in logs and meters ("dot_<effect_id>").
var effect_id := "balllightning"

var _age := 0.0
var _tick_t := 0.0
var _ending := false
var _orb_mat: StandardMaterial3D
var _arc_mat: StandardMaterial3D
var _light: OmniLight3D
var _sparks: CPUParticles3D

static func spawn(scene: Node, at: Vector3, dir: Vector3, src: Node, dmg: float, reach: float,
		time: float, every: float, move_speed: float) -> Node3D:
	var n := Node3D.new()
	n.set_script(load("res://scripts/ball_lightning.gd"))
	var flat := Vector3(dir.x, 0.0, dir.z)
	n.direction = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	n.source = src
	n.damage = dmg
	n.radius = reach
	n.duration = time
	n.tick = maxf(every, 0.1)
	n.speed = move_speed
	scene.add_child(n)
	n.global_position = at
	return n

## Does an orb at `centre` reach `point`, with `pad` (the enemy's hitbox radius)
## to spare? Height is ignored.
static func in_reach(centre: Vector3, reach: float, point: Vector3, pad: float = 0.0) -> bool:
	return Vector2(point.x - centre.x, point.z - centre.z).length() <= reach + pad

## Zaps that count for Energy when `count` enemies are hit at once.
static func energy_zaps(count: int) -> int:
	return mini(maxi(count, 0), Balance.AOE_TARGET_CAP)

func _glow_mat(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

func _ready() -> void:
	_orb_mat = _glow_mat(Color(GLOW, 0.55), 2.5)
	_arc_mat = _glow_mat(CORE, 3.0)
	# A soft outer shell around a bright core.
	var shell := MeshInstance3D.new()
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 0.45
	shell_mesh.height = 0.9
	shell.mesh = shell_mesh
	shell.material_override = _orb_mat
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.2
	core_mesh.height = 0.4
	core.mesh = core_mesh
	core.material_override = _arc_mat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	# Sparks jumping off it.
	var bit := BoxMesh.new()
	bit.size = Vector3(0.05, 0.05, 0.22)
	bit.material = _arc_mat
	_sparks = CPUParticles3D.new()
	_sparks.amount = 14
	_sparks.lifetime = 0.35
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_sparks.emission_sphere_radius = 0.4
	_sparks.direction = Vector3.UP
	_sparks.spread = 180.0
	_sparks.gravity = Vector3.ZERO
	_sparks.initial_velocity_min = 1.0
	_sparks.initial_velocity_max = 2.4
	_sparks.mesh = bit
	add_child(_sparks)
	# One cool light, no shadows (cheap).
	_light = OmniLight3D.new()
	_light.light_color = GLOW
	_light.light_energy = 1.6
	_light.omni_range = radius + 1.0
	_light.shadow_enabled = false
	add_child(_light)

func _process(delta: float) -> void:
	if _ending:
		return
	_age += delta
	if _age >= duration:
		vanish()
		return
	_drift(delta)
	_tick_t += delta
	if _tick_t >= tick:
		_tick_t -= tick
		_zap()

## The orb goes away (its time is up).
func vanish() -> void:
	if _ending:
		return
	_ending = true
	_sparks.emitting = false
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_orb_mat, "albedo_color:a", 0.0, FADE_TIME)
	t.tween_property(_light, "light_energy", 0.0, FADE_TIME)
	t.chain().tween_callback(queue_free)

## Drift on, unless a wall is right ahead: then it stays where it is.
func _drift(delta: float) -> void:
	if speed <= 0.0:
		return
	var step := direction * speed * delta
	if Combat.line_of_sight(get_world_3d(), global_position, global_position + step + direction * WALL_GAP):
		global_position += step
	else:
		speed = 0.0

## Enemies the orb can zap right now: in reach and in its line of sight.
func _in_range() -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D) or not e.is_alive():
			continue
		if not in_reach(global_position, radius, e.global_position, Combat.hitbox_radius(e)):
			continue
		if Combat.line_of_sight(get_world_3d(), global_position, Combat.sight_point(e)):
			out.append(e)
	return out

func _zap() -> void:
	var hit := _in_range()
	if hit.is_empty():
		return
	var live := damage > 0.0 and source != null and is_instance_valid(source)
	var cs := get_node_or_null("/root/CombatSystem")
	var share := Balance.aoe_share(hit.size())
	for e in hit:
		_arc_to(Combat.sight_point(e))
		if live and cs:
			cs.deal_dot(source, e, damage * share, "lightning", effect_id, tags)
	if live and source.has_method("ball_lightning_zapped"):
		source.ball_lightning_zapped(energy_zaps(hit.size()))

## A short-lived arc from the orb to `to`.
func _arc_to(to: Vector3) -> void:
	var from := global_position
	var dist := from.distance_to(to)
	if dist < 0.1 or get_parent() == null:
		return
	var arc := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.06, 0.06, dist)
	arc.mesh = box
	arc.material_override = _arc_mat
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(arc)
	arc.global_position = (from + to) * 0.5
	var dir := (to - from) / dist
	arc.look_at(to, Vector3.RIGHT if absf(dir.dot(Vector3.UP)) > 0.98 else Vector3.UP)
	get_tree().create_timer(ARC_TIME).timeout.connect(arc.queue_free)
