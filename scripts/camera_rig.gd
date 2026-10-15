extends Node3D

@export var target_path: NodePath

@export_group("Zoom")
@export var min_zoom: float = 0.3      # closest (fraction of starting distance)
@export var max_zoom: float = 1.6      # farthest
@export var zoom_step: float = 0.1     # per wheel notch / key press
@export var zoom_smoothing: float = 10.0

var target: Node3D
var camera: Camera3D
var base_offset: Vector3
var zoom: float = 1.0
var target_zoom: float = 1.0
## How fast the rig follows the target's HEIGHT (ramps, lower floors). The rig
## never turns or tilts: the camera keeps the angle it was given on every floor.
@export var height_smoothing: float = 12.0
var _height_offset := 0.0   # rig height minus target height, as placed in the scene
var _has_height := false

func _ready() -> void:
	if target_path != NodePath():
		target = get_node(target_path)
	camera = get_node_or_null("Camera3D")
	if camera:
		base_offset = camera.position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_change_zoom(-zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_change_zoom(zoom_step)
	elif event.is_action_pressed("zoom_in", true):
		_change_zoom(-zoom_step)
	elif event.is_action_pressed("zoom_out", true):
		_change_zoom(zoom_step)

func _change_zoom(amount: float) -> void:
	target_zoom = clampf(target_zoom + amount, min_zoom, max_zoom)

func _process(delta: float) -> void:
	if target:
		global_position.x = target.global_position.x
		global_position.z = target.global_position.z
		# Follow the target down ramps and onto lower floors. Without this the rig
		# stayed at the height of the first floor, so on a ramp the character slid
		# out of the centre of the view and the camera seemed to change its angle.
		if not _has_height:
			_has_height = true
			_height_offset = follow_offset(global_position.y, target.global_position.y)
		global_position.y = follow_height(global_position.y, target.global_position.y + _height_offset,
			height_smoothing, delta)

	if camera:
		zoom = lerpf(zoom, target_zoom, 1.0 - exp(-zoom_smoothing * delta))
		camera.position = base_offset * zoom

## Rig height minus target height when the level starts (the rig keeps it).
static func follow_offset(rig_y: float, target_y: float) -> float:
	return rig_y - target_y

## The rig's next height: eased toward `wanted` (a big jump, like a teleport, snaps).
static func follow_height(current: float, wanted: float, smoothing: float, delta: float) -> float:
	if absf(wanted - current) > 6.0:
		return wanted
	return lerpf(current, wanted, 1.0 - exp(-smoothing * delta))
