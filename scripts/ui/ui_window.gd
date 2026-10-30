extends CanvasLayer
class_name UIWindow

# A skinned window of the in-game UI's own (UI Options, UI setup, Trackers): a
# flat panel centred on the screen with a title bar you drag it by and a close
# button, on a layer above the HUD and Move UI. One of each at a time:
#   var w := UIWindow.make(tree, "UIOptions", "UI Options", Vector2(780, 540))
#   if w.is_new: w.body.add_child(...)
# Optional: w.enable_resize(min_size) adds a grip in the bottom-right corner;
# w.enable_minimize() a "_" button that folds it to its title bar. A resized
# window comes back at that size the next time it opens (this session).

const LAYER := 110

var panel: PanelContainer
var body: VBoxContainer
var title_label: Label
var is_new := true
var _drag := false
var _head: HBoxContainer
var _line: ColorRect
var _close: Button
var _min_size := Vector2.ZERO     # enable_resize: smallest size
var _resizing := false
var _minimized := false
var _full_h := 0.0                # height before folding
static var _sizes := {}           # window name -> size it was resized to

## The open window called `node_name`, or a new one (is_new) with an empty body.
static func make(tree: SceneTree, node_name: String, title: String, size: Vector2) -> UIWindow:
	var old := tree.root.get_node_or_null(node_name) as UIWindow
	if old != null and not old.is_queued_for_deletion():
		old.is_new = false
		return old
	var w := UIWindow.new()
	w.name = node_name
	w.layer = LAYER
	w._build(title, _sizes.get(node_name, size))
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
	_head = head
	title_label = UISkin.label(title, 16, UISkin.accent())
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	var close := button("X", Vector2(26, 24))
	close.pressed.connect(queue_free)
	head.add_child(close)
	_close = close
	var line := ColorRect.new()
	_line = line
	line.color = UISkin.INNER
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(line)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	v.add_child(body)

## A grip in the bottom-right corner: drag it to resize (never below `min_size`).
func enable_resize(min_size: Vector2) -> void:
	_min_size = min_size
	panel.custom_minimum_size = min_size
	var grip := Control.new()
	grip.name = "Grip"
	grip.custom_minimum_size = Vector2(16, 16)
	grip.size = Vector2(16, 16)
	grip.mouse_filter = Control.MOUSE_FILTER_STOP
	grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	grip.tooltip_text = "Drag to resize"
	grip.draw.connect(func():
		for i in 3:
			var d := 4.0 + i * 4.0
			grip.draw_line(Vector2(16 - d, 15), Vector2(15, 16 - d), Color(UISkin.TEXT, 0.5), 1.0, true))
	grip.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			_resizing = ev.pressed
		elif ev is InputEventMouseMotion and _resizing and not _minimized:
			var vp := panel.get_viewport_rect().size
			var want: Vector2 = (panel.size + ev.relative).max(_min_size).min(vp - panel.position)
			panel.size = want
			_sizes[name] = want)
	# (beside the panel, not in it: a container would lay it out; it follows the corner)
	add_child(grip)
	_place_grip(grip)
	panel.resized.connect(_place_grip.bind(grip))
	panel.item_rect_changed.connect(_place_grip.bind(grip))

func _place_grip(grip: Control) -> void:
	grip.position = panel.position + panel.size - grip.size
	grip.visible = not _minimized

## A "_" button by the close button: folds the window to its title bar and back.
func enable_minimize() -> void:
	var b := button("_", Vector2(26, 24))
	b.tooltip_text = "Minimize"
	b.pressed.connect(func():
		set_minimized(not _minimized)
		b.tooltip_text = "Restore" if _minimized else "Minimize")
	_head.add_child(b)
	_head.move_child(b, _close.get_index())

func set_minimized(on: bool) -> void:
	if on == _minimized:
		return
	_minimized = on
	if on:
		_full_h = panel.size.y
	body.visible = not on
	_line.visible = not on
	panel.custom_minimum_size = Vector2(panel.custom_minimum_size.x, 0.0 if on else _min_size.y)
	panel.size = Vector2(panel.size.x, 0.0 if on else maxf(_full_h, _min_size.y))
	var grip := get_node_or_null("Grip")
	if grip:
		grip.visible = not on

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
