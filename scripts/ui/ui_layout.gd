extends Node
class_name UILayout

# Move UI (Settings > Interface > "Move UI"), like ElvUI's /moveui: every in-game
# UI element can be dragged to a new place. In edit mode the screen darkens under
# a grid; each element gets a labelled box (a mover) to drag. Movers snap to the
# grid, to the other movers' edges and to the screen centre (hold Shift to place
# freely). Right-click a mover for exact X / Y, arrow nudges (Ctrl: 10 px) and
# Reset. The top bar: grid size, snapping, Reset All and Lock (Esc locks too).
#
# A moved element is saved as the nearest of 9 screen anchors (corners, edge
# middles, centre) plus an offset from it (Settings.ui_layout), so it stays put
# when the window size or the interface size changes. Elements that were never
# moved keep the HUD's own layout. HUD code registers each element once:
#   UILayout.register(get_tree(), node, "target_frame", "Target Frame", true)

const OVERLAY_LAYER := 100
const GRIDS := [16, 32, 64]
const SNAP_PX := 8.0            # edge / centre snapping reach
const NUDGE := 1.0
const NUDGE_BIG := 10.0
const MIN_MOVER := Vector2(80, 24)
const MOVER_COLOR := Color(0.25, 0.55, 1.0, 0.35)
const MOVER_HOVER := Color(0.35, 0.75, 1.0, 0.55)
const MOVER_BORDER := Color(0.55, 0.8, 1.0, 0.9)

var entries := {}               # key -> {"node": Control, "label": String}
var editing := false
var grid := 32
var snap := true
var _overlay: CanvasLayer
var _movers := {}               # key -> mover Panel
var _nudge: PanelContainer
var _nudge_key := ""

# --- Registry -------------------------------------------------------------------------

## The one registry (made the first time an element registers).
static func of(tree: SceneTree) -> UILayout:
	var n := tree.root.get_node_or_null("UILayout")
	if n == null:
		n = UILayout.new()
		n.name = "UILayout"
		tree.root.add_child.call_deferred(n)
	return n as UILayout

## `always`: show its mover even while the element is hidden (the target frame,
## the cast bar: hidden most of the time, but still worth placing).
static func register(tree: SceneTree, node: Control, key: String, label: String, always := false) -> void:
	if tree != null and node != null:
		of(tree).add(node, key, label, always)

func add(node: Control, key: String, label: String, always := false) -> void:
	entries[key] = {"node": node, "label": label, "always": always,
		"default": [node.offset_left, node.offset_top, node.offset_right, node.offset_bottom]}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Every frame: moved elements stay where they were put (whatever the HUD's own
## layout code does to them).
func _process(_delta: float) -> void:
	var screen := _screen()
	for key in entries.keys():
		var node: Variant = entries[key]["node"]
		if node == null or not is_instance_valid(node):
			entries.erase(key)
			continue
		var saved := _saved(key)
		if not saved.is_empty():
			var c := node as Control
			var at := position_for(saved, _size_of(c), screen)
			if c.global_position.distance_squared_to(at) > 0.01:
				c.global_position = at
	if editing:
		_sync_movers()

func _screen() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280, 720)

func _settings() -> Node:
	return get_node_or_null("/root/Settings")

func _saved(key: String) -> Dictionary:
	var s := _settings()
	if s == null:
		return {}
	var d: Variant = (s.get("ui_layout") as Dictionary).get(key, {}) if s.get("ui_layout") is Dictionary else {}
	return d if d is Dictionary else {}

func _store(key: String, d: Dictionary) -> void:
	var s := _settings()
	if s == null:
		return
	if d.is_empty():
		s.ui_layout.erase(key)
	else:
		s.ui_layout[key] = d
	s.save()

static func _size_of(c: Control) -> Vector2:
	var s := c.size
	return Vector2(maxf(s.x, 1.0), maxf(s.y, 1.0))

# --- Anchor + offset math (static: tests/test_ui_layout.gd) -----------------------------------

## The anchor (0 / 0.5 / 1 on each axis) nearest an element at `pos` of `size`.
static func anchor_for(pos: Vector2, size: Vector2, screen: Vector2) -> Vector2:
	var centre := pos + size / 2.0
	return Vector2(_third(centre.x, screen.x), _third(centre.y, screen.y))

static func _third(v: float, total: float) -> float:
	if v < total / 3.0:
		return 0.0
	if v > total * 2.0 / 3.0:
		return 1.0
	return 0.5

## What to save for an element at `pos`: its anchor and its offset from it.
static func save_for(pos: Vector2, size: Vector2, screen: Vector2) -> Dictionary:
	var a := anchor_for(pos, size, screen)
	var off := pos - a * screen + a * size
	return {"ax": a.x, "ay": a.y, "x": snappedf(off.x, 0.5), "y": snappedf(off.y, 0.5)}

## Where a saved element goes on a screen of `screen` (top-left corner).
static func position_for(saved: Dictionary, size: Vector2, screen: Vector2) -> Vector2:
	var a := Vector2(float(saved.get("ax", 0.0)), float(saved.get("ay", 0.0)))
	var off := Vector2(float(saved.get("x", 0.0)), float(saved.get("y", 0.0)))
	var pos := a * screen - a * size + off
	return pos.clamp(Vector2.ZERO, (screen - size).max(Vector2.ZERO))   # never off screen

## Snap a mover's top-left `pos` (size `size`) to the grid, and then to any of
## `edges` (x lines, y lines: other movers' edges and the screen centre) within reach.
static func snapped_pos(pos: Vector2, size: Vector2, grid_px: int, xs: Array, ys: Array) -> Vector2:
	var out := Vector2(snappedf(pos.x, grid_px), snappedf(pos.y, grid_px)) if grid_px > 0 else pos
	out.x = _snap_axis(pos.x, size.x, xs, out.x)
	out.y = _snap_axis(pos.y, size.y, ys, out.y)
	return out

static func _snap_axis(p: float, length: float, lines: Array, fallback: float) -> float:
	var best := fallback
	var best_d := SNAP_PX
	for l in lines:
		for edge in [[p, 0.0], [p + length, length], [p + length / 2.0, length / 2.0]]:
			var d := absf(float(edge[0]) - float(l))
			if d < best_d:
				best_d = d
				best = float(l) - float(edge[1])
	return best

# --- Edit mode ------------------------------------------------------------------------

func start_edit() -> void:
	if editing:
		return
	editing = true
	_overlay = CanvasLayer.new()
	_overlay.layer = OVERLAY_LAYER
	get_tree().root.add_child(_overlay)
	var shade := GridShade.new()
	shade.layout = self
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_close_nudge())
	_overlay.add_child(shade)
	for key in entries:
		_make_mover(key)
	_overlay.add_child(_top_bar())
	_sync_movers()

func stop_edit() -> void:
	if not editing:
		return
	editing = false
	_movers.clear()
	_nudge = null
	if _overlay:
		_overlay.queue_free()
	_overlay = null

func _unhandled_input(event: InputEvent) -> void:
	if editing and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		stop_edit()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Arrow keys nudge the mover whose panel is open.
	if not editing or _nudge_key == "" or not (event is InputEventKey) or not event.pressed:
		return
	var step := NUDGE_BIG if event.ctrl_pressed else NUDGE
	var d := Vector2.ZERO
	match event.keycode:
		KEY_LEFT: d.x = -step
		KEY_RIGHT: d.x = step
		KEY_UP: d.y = -step
		KEY_DOWN: d.y = step
	if d != Vector2.ZERO:
		_move_by(_nudge_key, d)
		get_viewport().set_input_as_handled()

func _top_bar() -> Control:
	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.95)
	sb.border_color = MOVER_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	bar.add_theme_stylebox_override("panel", sb)
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.offset_top = 12
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)
	var title := Label.new()
	title.text = "Move UI  —  drag a box; right-click for exact placement; Shift: no snapping"
	row.add_child(title)
	var g := OptionButton.new()
	for px in GRIDS:
		g.add_item("Grid %d" % px)
	g.selected = GRIDS.find(grid)
	g.item_selected.connect(func(i: int):
		grid = int(GRIDS[i])
		_overlay.get_child(0).queue_redraw())
	row.add_child(g)
	var sn := CheckButton.new()
	sn.text = "Snap"
	sn.button_pressed = snap
	sn.toggled.connect(func(on: bool): snap = on)
	row.add_child(sn)
	var reset_all := Button.new()
	reset_all.text = "Reset All"
	reset_all.pressed.connect(func():
		for key in entries:
			_store(key, {})
		_close_nudge()
		_restore_defaults())
	row.add_child(reset_all)
	var lock := Button.new()
	lock.text = "Lock"
	lock.pressed.connect(stop_edit)
	row.add_child(lock)
	return bar

## Elements that were reset go back to where the HUD put them (moving only
## ever changes an element's offsets, never its anchors).
func _restore_defaults() -> void:
	for key in entries:
		var c: Variant = entries[key]["node"]
		if _saved(key).is_empty() and c != null and is_instance_valid(c):
			var d: Array = entries[key]["default"]
			(c as Control).offset_left = d[0]
			(c as Control).offset_top = d[1]
			(c as Control).offset_right = d[2]
			(c as Control).offset_bottom = d[3]

func _make_mover(key: String) -> void:
	var m := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = MOVER_COLOR
	sb.border_color = MOVER_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	m.add_theme_stylebox_override("panel", sb)
	m.mouse_filter = Control.MOUSE_FILTER_STOP
	m.mouse_default_cursor_shape = Control.CURSOR_MOVE
	var l := Label.new()
	l.text = str(entries[key]["label"])
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(l)
	m.mouse_entered.connect(func(): sb.bg_color = MOVER_HOVER)
	m.mouse_exited.connect(func(): sb.bg_color = MOVER_COLOR)
	m.gui_input.connect(func(e: InputEvent): _mover_input(key, m, e))
	_overlay.add_child(m)
	_movers[key] = m

## Mover boxes follow their elements (a hidden one still gets a box to drag).
func _sync_movers() -> void:
	for key in _movers:
		if not entries.has(key):
			continue
		var c := entries[key]["node"] as Control
		var m: Panel = _movers[key]
		if c == null or not is_instance_valid(c):
			m.visible = false
			continue
		m.visible = c.visible or bool(entries[key]["always"])   # (a bar that is switched off has none)
		m.size = _size_of(c).max(MIN_MOVER)
		m.global_position = c.global_position

var _drag_key := ""
var _drag_from := Vector2.ZERO

func _mover_input(key: String, m: Control, e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT:
			_drag_key = key if e.pressed else ""
			_drag_from = e.global_position - m.global_position
		elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
			_open_nudge(key, m)
		m.accept_event()
	elif e is InputEventMouseMotion and _drag_key == key:
		var c := entries[key]["node"] as Control
		var size := _size_of(c)
		var to: Vector2 = e.global_position - _drag_from
		if snap and not e.shift_pressed:
			var lines := _snap_lines(key)
			to = snapped_pos(to, size, grid, lines[0], lines[1])
		_place(key, to)
		m.accept_event()

## Other movers' edges and the screen centre, as [x lines, y lines].
func _snap_lines(except: String) -> Array:
	var screen := _screen()
	var xs: Array = [0.0, screen.x / 2.0, screen.x]
	var ys: Array = [0.0, screen.y / 2.0, screen.y]
	for key in _movers:
		if key == except:
			continue
		var r: Rect2 = (_movers[key] as Control).get_global_rect()
		xs.append_array([r.position.x, r.end.x])
		ys.append_array([r.position.y, r.end.y])
	return [xs, ys]

func _place(key: String, pos: Vector2) -> void:
	var c := entries[key]["node"] as Control
	var screen := _screen()
	var size := _size_of(c)
	var d := save_for(pos.clamp(Vector2.ZERO, (screen - size).max(Vector2.ZERO)), size, screen)
	_store(key, d)
	c.global_position = position_for(d, size, screen)
	_refresh_nudge()

func _move_by(key: String, d: Vector2) -> void:
	var c := entries[key]["node"] as Control
	_place(key, c.global_position + d)

# --- The nudge panel (right-click a mover) ---------------------------------------------

var _nx: SpinBox
var _ny: SpinBox

func _open_nudge(key: String, m: Control) -> void:
	_close_nudge()
	_nudge_key = key
	_nudge = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.97)
	sb.border_color = MOVER_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	_nudge.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	_nudge.add_child(v)
	var t := Label.new()
	t.text = str(entries[key]["label"])
	v.add_child(t)
	var xy := HBoxContainer.new()
	v.add_child(xy)
	_nx = _spin(xy, "X")
	_ny = _spin(xy, "Y")
	_nx.value_changed.connect(func(val: float): _place(key, Vector2(val, _ny.value)))
	_ny.value_changed.connect(func(val: float): _place(key, Vector2(_nx.value, val)))
	var arrows := HBoxContainer.new()
	v.add_child(arrows)
	for a in [["◀", Vector2.LEFT], ["▲", Vector2.UP], ["▼", Vector2.DOWN], ["▶", Vector2.RIGHT]]:
		var b := Button.new()
		b.text = str(a[0])
		b.tooltip_text = "Nudge 1 px (Ctrl: 10 px). Arrow keys work too."
		var dir: Vector2 = a[1]
		b.pressed.connect(func(): _move_by(key, dir * (NUDGE_BIG if Input.is_key_pressed(KEY_CTRL) else NUDGE)))
		arrows.add_child(b)
	var reset := Button.new()
	reset.text = "Reset"
	reset.pressed.connect(func():
		_store(key, {})
		_restore_defaults()
		_close_nudge())
	v.add_child(reset)
	_overlay.add_child(_nudge)
	_nudge.global_position = (m.get_global_rect().end + Vector2(6, 0)).min(_screen() - Vector2(220, 140))
	_refresh_nudge()

func _spin(parent: Control, label: String) -> SpinBox:
	var l := Label.new()
	l.text = label
	parent.add_child(l)
	var s := SpinBox.new()
	s.min_value = 0
	s.max_value = 10000
	s.step = 1
	s.custom_minimum_size = Vector2(80, 0)
	parent.add_child(s)
	return s

func _refresh_nudge() -> void:
	if _nudge == null or _nudge_key == "" or not entries.has(_nudge_key):
		return
	var c := entries[_nudge_key]["node"] as Control
	_nx.set_value_no_signal(round(c.global_position.x))
	_ny.set_value_no_signal(round(c.global_position.y))

func _close_nudge() -> void:
	if _nudge != null and is_instance_valid(_nudge):
		_nudge.queue_free()
	_nudge = null
	_nudge_key = ""

# --- The darkened grid -----------------------------------------------------------------

class GridShade extends Control:
	var layout: UILayout

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
		var g := float(layout.grid if layout else 32)
		var line := Color(1, 1, 1, 0.08)
		var x := 0.0
		while x <= size.x:
			draw_line(Vector2(x, 0), Vector2(x, size.y), line)
			x += g
		var y := 0.0
		while y <= size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), line)
			y += g
		var centre := Color(1.0, 0.3, 0.3, 0.6)
		draw_line(Vector2(size.x / 2.0, 0), Vector2(size.x / 2.0, size.y), centre, 1.5)
		draw_line(Vector2(0, size.y / 2.0), Vector2(size.x, size.y / 2.0), centre, 1.5)
