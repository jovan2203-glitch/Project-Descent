extends Node3D
class_name RimeShellFx

# The picture of a Rime Shell on a character (you, a party member, the training
# ally): a pale bubble of ice around them that cracks as it soaks damage. One
# set of cracks once a third of its shield is gone, more once two thirds are,
# each with a quick flash. Visual only (a child node, no gameplay): swap it for
# a real model or shader later. Driven by RimeShellFx.show_on(host, on, cracks).

const NODE_NAME := "RimeShellFx"
const RADIUS := 1.05
const ICE := Color(0.62, 0.9, 1.0)
## Shield left (0..1) below which the shell shows 1 and 2 sets of cracks.
const CRACK_AT := [2.0 / 3.0, 1.0 / 3.0]
## Where each crack starts on the bubble: the first set, then the second.
const CRACKS := [
	[Vector3(0.6, 0.4, 0.7), Vector3(-0.7, 0.2, 0.6), Vector3(0.1, -0.3, -1.0)],
	[Vector3(-0.5, 0.7, -0.5), Vector3(0.9, -0.2, -0.3), Vector3(-0.2, 0.9, 0.4), Vector3(-0.8, -0.4, -0.3)],
]

var cracks := 0
var _bubble: MeshInstance3D
var _sets: Array = []   # one Node3D per set of cracks
var _mat: StandardMaterial3D

## Cracks to show for a shield with `fraction` (0..1) of it left.
static func cracks_for(fraction: float) -> int:
	if fraction > CRACK_AT[0]:
		return 0
	if fraction > CRACK_AT[1]:
		return 1
	return 2

## Show (or hide) `host`'s Rime Shell with `n` sets of cracks.
static func show_on(host: Node3D, on: bool, n: int = 0) -> void:
	if host == null or not is_instance_valid(host):
		return
	var fx := host.get_node_or_null(NODE_NAME) as RimeShellFx
	if not on:
		if fx:
			fx.queue_free()
		return
	if fx == null:
		fx = RimeShellFx.new()
		fx.name = NODE_NAME
		host.add_child(fx)
	fx.set_cracks(n)

func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.albedo_color = Color(ICE, 0.16)
	_bubble = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	_bubble.mesh = sphere
	_bubble.material_override = _mat
	_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bubble)
	var line := StandardMaterial3D.new()
	line.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line.albedo_color = Color(0.95, 0.98, 1.0)
	for group in CRACKS:
		var holder := Node3D.new()
		holder.visible = false
		add_child(holder)
		for start in group:
			_crack(holder, (start as Vector3).normalized(), line)
		_sets.append(holder)
	_apply()

## A zig-zag crack of three short white strokes on the bubble, from `dir`.
func _crack(parent: Node3D, dir: Vector3, mat: Material) -> void:
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
	var down := side.cross(dir).normalized()
	var at := dir
	for i in 3:
		var step := (down * 0.22 + side * (0.12 if i % 2 == 0 else -0.12)).normalized() * 0.24
		var to := (at + step).normalized()
		var seg := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.025, 0.025, at.distance_to(to) * RADIUS)
		seg.mesh = box
		seg.material_override = mat
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(seg)
		var mid := (at + to).normalized() * (RADIUS + 0.01)
		seg.position = mid
		seg.look_at_from_position(mid, to * (RADIUS + 0.01), mid.normalized())
		at = to

func set_cracks(n: int) -> void:
	n = clampi(n, 0, CRACKS.size())
	var more := n > cracks
	cracks = n
	if is_inside_tree():
		_apply()
		if more:
			_flash()

func _apply() -> void:
	for i in _sets.size():
		(_sets[i] as Node3D).visible = i < cracks
	if _mat:
		_mat.albedo_color = Color(ICE, 0.16 + 0.05 * cracks)

## A crack opened: the shell flashes white for a moment.
func _flash() -> void:
	if _mat == null:
		return
	var t := create_tween()
	_mat.albedo_color = Color(1, 1, 1, 0.45)
	t.tween_property(_mat, "albedo_color", Color(ICE, 0.16 + 0.05 * cracks), 0.25)
