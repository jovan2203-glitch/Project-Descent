extends Node3D

# Ice patch (Icy Retreat): a sheet of ice on the ground for `duration` seconds.
# Every `tick` seconds (the first as it forms) `on_tick` is called with every
# enemy standing on it - the archer's machine Chills them there.
# Without `on_tick` it is only the picture (a party member's patch): what it
# does comes from its caster's machine.

const Combat = preload("res://scripts/combat_utils.gd")

const ICE := Color(0.6, 0.9, 1.0)
const RIM := Color(0.92, 0.97, 1.0)
const FADE_TIME := 0.4

var radius := 4.0
var duration := 4.0
var tick := 1.0
var on_tick := Callable()

var _age := 0.0
var _tick_t := 0.0
var _ending := false
var _mats: Array[StandardMaterial3D] = []

static func spawn(scene: Node, at: Vector3, reach: float, time: float, every: float, each: Callable = Callable()) -> Node3D:
	var n := Node3D.new()
	n.set_script(load("res://scripts/ice_patch.gd"))
	n.radius = reach
	n.duration = time
	n.tick = maxf(every, 0.1)
	n.on_tick = each
	scene.add_child(n)
	n.global_position = at
	return n

## Is `point` on a patch of radius `reach` centred on `centre`, with `pad` (the
## enemy's hitbox radius) to spare? Height is ignored.
static func inside(centre: Vector3, reach: float, point: Vector3, pad: float = 0.0) -> bool:
	return Vector2(point.x - centre.x, point.z - centre.z).length() <= reach + pad

## Times a patch lasting `time` Chills what stands on it, once every `every`
## seconds (the first at once).
static func ticks(time: float, every: float) -> int:
	return int(ceil(maxf(time, 0.0) / maxf(every, 0.1)))

func _mat(c: Color, energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = energy
	_mats.append(m)
	return m

func _ready() -> void:
	# The sheet of ice, and a brighter rim so its edge reads on any floor.
	var sheet := MeshInstance3D.new()
	var sheet_mesh := CylinderMesh.new()
	sheet_mesh.top_radius = radius
	sheet_mesh.bottom_radius = radius
	sheet_mesh.height = 0.02
	sheet.mesh = sheet_mesh
	sheet.position.y = 0.04
	sheet.material_override = _mat(Color(ICE, 0.32), 0.6)
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sheet)
	var rim := MeshInstance3D.new()
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = maxf(radius - 0.12, 0.05)
	rim_mesh.outer_radius = radius
	rim.mesh = rim_mesh
	rim.position.y = 0.05
	rim.scale.y = 0.2
	rim.material_override = _mat(Color(RIM, 0.7), 1.5)
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rim)
	# A few jagged plates on it.
	var plate_mat := _mat(Color(RIM, 0.5), 1.0)
	for i in 6:
		var a := TAU * i / 6.0 + 0.4
		var plate := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(radius * 0.32, 0.03, radius * 0.12)
		plate.mesh = box
		plate.material_override = plate_mat
		plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		plate.position = Vector3(cos(a), 0.0, sin(a)) * radius * (0.35 + 0.12 * (i % 3)) + Vector3(0, 0.06, 0)
		plate.rotation.y = a * 1.7
		add_child(plate)
	# The first Chill lands as the ice forms. Deferred: whoever spawned it puts
	# it in place right after adding it to the scene.
	_pulse.call_deferred()

func _process(delta: float) -> void:
	if _ending:
		return
	_age += delta
	if _age >= duration:
		vanish()
		return
	_tick_t += delta
	if _tick_t >= tick:
		_tick_t -= tick
		_pulse()

## The ice melts.
func vanish() -> void:
	if _ending:
		return
	_ending = true
	var t := create_tween()
	t.set_parallel(true)
	for m in _mats:
		t.tween_property(m, "albedo_color:a", 0.0, FADE_TIME)
	t.chain().tween_callback(queue_free)

## Enemies standing on the ice.
func _targets() -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node3D and e.is_alive() and inside(global_position, radius, e.global_position, Combat.hitbox_radius(e)):
			out.append(e)
	return out

func _pulse() -> void:
	if _ending or not on_tick.is_valid():
		return
	for e in _targets():
		on_tick.call(e)
