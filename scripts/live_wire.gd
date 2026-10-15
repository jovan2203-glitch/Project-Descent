extends Node3D

# Live Wire's tether: a thin crackling line between the caster and the enemy
# they are tethered to. Only the picture: the damage is the Live Wire effect on
# the enemy, and the caster's machine decides when the tether breaks (it calls
# vanish()). A party member's tether ends here on its own: after `duration`,
# when either end is gone, or when they move further apart than `break_range`.
# One tether per owner: a new one replaces the old.

const Combat = preload("res://scripts/combat_utils.gd")

const GROUP := "live_wires"
const CORE := Color(0.92, 0.95, 1.0)
const GLOW := Color(0.45, 0.55, 1.0)
## Height on the caster the line starts from.
const HAND_HEIGHT := 1.0

var from_node: Node3D
var to_node: Node3D
var duration := 10.0
## Metres apart at which the line ends by itself (0 = never by itself).
var break_range := 0.0
## "me" for my own, a party member's id for theirs.
var owner_key := ""

var _age := 0.0
var _line: MeshInstance3D
var _halo: MeshInstance3D

static func spawn(scene: Node, a: Node3D, b: Node3D, time: float, key: String, range_m: float = 0.0) -> Node3D:
	for w in scene.get_tree().get_nodes_in_group(GROUP):
		if str(w.owner_key) == key:
			w.vanish()
	var n := Node3D.new()
	n.set_script(load("res://scripts/live_wire.gd"))
	n.from_node = a
	n.to_node = b
	n.duration = time
	n.owner_key = key
	n.break_range = range_m
	scene.add_child(n)
	return n

## Has a tether stretched over `distance` metres snapped (it holds up to `range_m`)?
static func breaks_at(distance: float, range_m: float) -> bool:
	return range_m > 0.0 and distance > range_m

func _bar(width: float, c: Color, energy: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, width, 1.0)
	m.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = energy
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.top_level = true
	add_child(m)
	return m

func _ready() -> void:
	add_to_group(GROUP)
	_halo = _bar(0.14, Color(GLOW, 0.45), 2.0)
	_line = _bar(0.05, CORE, 3.0)
	_update()

func _ends_ok() -> bool:
	if from_node == null or to_node == null or not is_instance_valid(from_node) or not is_instance_valid(to_node):
		return false
	if to_node.has_method("is_alive") and not to_node.is_alive():
		return false
	return true

func _process(delta: float) -> void:
	_age += delta
	if _age >= duration or not _ends_ok():
		vanish()
		return
	_update()

func _update() -> void:
	if not _ends_ok():
		return
	var a := from_node.global_position + Vector3(0, HAND_HEIGHT, 0)
	var b: Vector3 = Combat.sight_point(to_node)
	var dist := a.distance_to(b)
	if breaks_at(dist, break_range):
		vanish()
		return
	if dist < 0.05:
		return
	var dir := (b - a) / dist
	var up := Vector3.RIGHT if absf(dir.dot(Vector3.UP)) > 0.98 else Vector3.UP
	# A little flicker so it reads as a current, not a rope.
	var pulse := 1.0 + 0.35 * sin(_age * 40.0)
	for bar in [_halo, _line]:
		bar.global_position = (a + b) * 0.5
		bar.look_at(b, up)
		bar.scale = Vector3(pulse if bar == _halo else 1.0, pulse if bar == _halo else 1.0, dist)

func vanish() -> void:
	if is_queued_for_deletion():
		return
	remove_from_group(GROUP)
	queue_free()
