extends CanvasLayer
class_name UIWindow

# A skinned window of the in-game UI's own (UI Options, UI setup, Trackers): a
# flat panel centred on the screen with a title bar you drag it by and a close
# button, on a layer above the HUD and Move UI. One of each at a time:
#   var w := UIWindow.make(tree, "UIOptions", "UI Options", Vector2(780, 540))
#   if w.is_new: w.body.add_child(...)

const LAYER := 110

var panel: PanelContainer
var body: VBoxContainer
var title_label: Label
var is_new := true
var _drag := false

## The open window called `node_name`, or a new one (is_new) with an empty body.
static func make(tree: SceneTree, node_name: String, title: String, size: Vector2) -> UIWindow:
	var old := tree.root.get_node_or_null(node_name) as UIWindow
	if old != null and not old.is_queued_for_deletion():
		old.is_new = false
		return old
	var w := UIWindow.new()
	w.name = node_name
	w.layer = LAYER
	w._build(title, size)
	tree.root.add_child.call_deferred(w)   # (opened from a button: the root may be busy)
	return w

static func is_open(tree: SceneTree, node_name: String) -> bool:
	var w := tree.root.get_node_or_null(node_name)
	return w != null and not w.is_queued_for_deletion()

func _build(title: String, size: Vector2) -> void:
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UISkin.backdrop(0.97, 8))
	panel.custom_minimum_size = size
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -size.x / 2.0
	panel.offset_right = size.x / 2.0
	panel.offset_top = -size.y / 2.0
	panel.offset_bottom = size.y / 2.0
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	head.mouse_default_cursor_shape = Control.CURSOR_MOVE
	head.gui_input.connect(_on_head_input)
	v.add_child(head)
	title_label = UISkin.label(title, 16, UISkin.accent())
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	var close := button("X", Vector2(26, 24))
	close.pressed.connect(queue_free)
	head.add_child(close)
	var line := ColorRect.new()
	line.color = UISkin.INNER
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(line)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	v.add_child(body)

func _on_head_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_drag = ev.pressed
	elif ev is InputEventMouseMotion and _drag:
		var vp := panel.get_viewport_rect().size
		var p: Vector2 = (panel.position + ev.relative).clamp(Vector2.ZERO, (vp - panel.size).max(Vector2.ZERO))
		panel.position = p

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		queue_free()

## A flat button in the skin's look.
static func button(text: String, min_size := Vector2(0, 26)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", UISkin.font(13))
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb := UISkin.button_box("hover" if s == "hover" else ("active" if s.contains("pressed") else "normal"))
		sb.bg_color = Color(0.1, 0.1, 0.12, 0.95) if s != "disabled" else Color(0.06, 0.06, 0.07, 0.8)
		sb.set_content_margin_all(4)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		b.add_theme_stylebox_override(s, sb)
	return b
