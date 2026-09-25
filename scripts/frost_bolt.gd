extends Node3D

# Homing frost bolt. Spawned by the player; flies to the target and deals damage on hit.

const Combat = preload("res://scripts/combat_utils.gd")

@export var speed: float = 14.0
@export var damage: int = 1

var target: Node3D
var source: Node = null      # the player; damage goes through source.deal_damage()
var is_proc := false         # fired by a rune
var ability_id := "frostbolt"
var _trail: CPUParticles3D
var _done := false

# Pooled (see Pool): visuals are built once in _ready; spawn() resets state.
static func spawn(scene: Node, at: Vector3, tgt: Node3D, src: Node, proc: bool = false,
		id: String = "frostbolt", dmg: int = 1) -> Node3D:
	var pool := scene.get_node_or_null("/root/Pool")
	var factory := func():
		var n := Node3D.new()
		n.set_script(load("res://scripts/frost_bolt.gd"))
		return n
	var bolt: Node3D = pool.acquire("frost_bolt", factory) if pool else factory.call()
	bolt.target = tgt
	bolt.source = src
	bolt.is_proc = proc
	bolt.ability_id = id
	bolt.damage = dmg
	bolt._done = false
	scene.add_child(bolt)
	bolt.global_position = at
	bolt._tint(id)
	if bolt._trail:
		bolt._trail.restart()
	# Party members see my bolt too (as a harmless visual).
	if src and is_instance_valid(src) and src.is_in_group("player"):
		var net := scene.get_node_or_null("/root/Net")
		if net:
			net.send_fx("bolt", at, tgt, id)
	return bolt

func _finish() -> void:
	if _done:
		return
	_done = true
	var pool := get_node_or_null("/root/Pool")
	if pool and has_meta("pool_key"):
		pool.release(self)
	else:
		queue_free()

const FROST_COLOR := Color(0.35, 0.85, 1.0)
var _mat: StandardMaterial3D
var _light: OmniLight3D

## Spell bolts take their book's color (Fire orange, Shadow purple...); Frost
## and unknown ids keep the icy blue. Re-applied on every spawn (pooled).
func _tint(id: String) -> void:
	if _mat == null:
		return
	var c := FROST_COLOR
	var cat: String = preload("res://scripts/abilities.gd").category_of(id)
	if cat != "" and cat != "frost":
		c = preload("res://scripts/categories.gd").color(cat)
	_mat.albedo_color = c.lightened(0.4)
	_mat.emission = c
	_light.light_color = c

func _ready() -> void:
	var core_mat := StandardMaterial3D.new()
	_mat = core_mat
	core_mat.albedo_color = Color(0.7, 0.95, 1.0)
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.35, 0.85, 1.0)
	core_mat.emission_energy_multiplier = 4.0

	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.14
	sphere.height = 0.28
	sphere.material = core_mat
	core.mesh = sphere
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)

	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 0.85, 1.0)
	light.light_energy = 2.0
	light.omni_range = 3.5
	add_child(light)
	_light = light

	# Icy trail
	var trail := CPUParticles3D.new()
	trail.amount = 40
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.gravity = Vector3.ZERO
	trail.direction = Vector3.ZERO
	trail.spread = 180.0
	trail.initial_velocity_min = 0.1
	trail.initial_velocity_max = 0.4
	trail.scale_amount_min = 0.5
	trail.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	trail.scale_amount_curve = curve
	var p_mesh := SphereMesh.new()
	p_mesh.radius = 0.07
	p_mesh.height = 0.14
	p_mesh.radial_segments = 6
	p_mesh.rings = 3
	p_mesh.material = core_mat
	trail.mesh = p_mesh
	add_child(trail)
	_trail = trail

func _physics_process(delta: float) -> void:
	if _done:
		return
	if not is_instance_valid(target) or not target.is_alive():
		_finish()
		return
	var aim := target.global_position + Vector3(0, 0.3, 0)
	var to_target := aim - global_position
	var step := speed * delta
	if to_target.length() <= step + 0.2:
		if is_instance_valid(source) and source.has_method("deal_damage"):
			source.deal_damage(target, damage, ability_id, is_proc)
		else:
			target.take_damage(damage)
		_finish()
		return
	var next := global_position + to_target.normalized() * step
	# Walls and rock stop the bolt.
	if not Combat.line_of_sight(get_world_3d(), global_position, next):
		_finish()
		return
	global_position = next
