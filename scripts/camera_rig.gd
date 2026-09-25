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

	if camera:
		zoom = lerpf(zoom, target_zoom, 1.0 - exp(-zoom_smoothing * delta))
		camera.position = base_offset * zoom
