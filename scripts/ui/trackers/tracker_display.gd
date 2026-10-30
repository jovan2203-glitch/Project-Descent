extends Control
class_name TrackerDisplay

# One tracker on screen (scripts/ui/trackers/trackers.gd): an icon with a
# cooldown sweep, stacks and time; a bar filling by time left or value; a text;
# a ring; or pips (one per point up to the max, each in its own colour when the
# value gives them). Two texts each (icon: bottom right and top; bar: left and
# centre, time on the right; the others: centre and right). "Show while missing"
# keeps it there, dim, while its triggers are off; "On click" runs a spec action
# (Player.tracker_action). A group's display holds its trackers' displays and
# stacks the showing ones (grow direction, alignment, spacing, sort). The engine
# (tracker_engine.gd) hands each its state ten times a second; timers run down
# smoothly between.

const AbilitiesScript = preload("res://scripts/abilities.gd")
const EffectsScript = preload("res://scripts/core/effects.gd")
const MISSING_ALPHA := 0.35

var data: Dictionary = {}
var is_group := false
var st: Dictionary = {"active": false, "unloaded": true}
var mods: Dictionary = {}           # what the conditions changed right now
var preview := false                # the editor's preview: always shown, made-up values
var _bar: HudBar
var _glow_t := 0.0
var _was_active := false
## The Trackers editor is open: hovering frames this one, a click opens it there.
var picking := false
var _pick_mark: Panel
const PICK_COL := Color(0.4, 0.8, 1.0)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	gui_input.connect(_on_pick)
	mouse_entered.connect(func(): _show_pick_mark(true))
	mouse_exited.connect(func(): _show_pick_mark(false))

func setup(t: Dictionary) -> void:
	data = t
	is_group = str(t.get("kind")) == "group"
	name = str(t["id"])
	if _bar:
		_bar.queue_free()
		_bar = null
	if is_group:
		size = Vector2(40, 40)
		return
	var d: Dictionary = t["display"]
	size = Vector2(float(d["width"]), float(d["height"]))
	custom_minimum_size = size
	if str(d["type"]) == "bar":
		_bar = HudBar.new()
		var icon_w := size.y if str(d.get("icon", "auto")) != "none" else 0.0
		_bar.position = Vector2(icon_w + (1 if icon_w > 0 else 0), 0)
		_bar.size = Vector2(size.x - _bar.position.x, size.y)
		_bar.font_size = UISkin.font(clampi(int(size.y * 0.62), 9, 16))
		_bar.spark = true
		add_child(_bar)
	var click := str(d.get("click", ""))
	if click != "" and not gui_input.is_connected(_on_click):
		gui_input.connect(_on_click)
	_update_mouse()
	_make_layers()
	queue_redraw()

## Takes clicks while it has an "On click" action, or while the editor is open.
func _update_mouse() -> void:
	var click := str(data.get("display", {}).get("click", "")) if not is_group else ""
	mouse_filter = Control.MOUSE_FILTER_STOP if (picking or click != "") else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if picking else Control.CURSOR_ARROW

## Editor open or closed (TrackerEngine.set_picking).
func set_picking(on: bool) -> void:
	picking = on
	_update_mouse()
	if not on:
		_show_pick_mark(false)
		tooltip_text = ""   # (an "On click" tracker builds its own again)

func _show_pick_mark(on: bool) -> void:
	if on and not picking:
		return
	if _pick_mark == null:
		if not on:
			return
		_pick_mark = Panel.new()
		_pick_mark.set_anchors_preset(Control.PRESET_FULL_RECT)
		_pick_mark.offset_left = -3
		_pick_mark.offset_top = -3
		_pick_mark.offset_right = 3
		_pick_mark.offset_bottom = 3
		_pick_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(PICK_COL, 0.12)
		sb.border_color = PICK_COL
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		_pick_mark.add_theme_stylebox_override("panel", sb)
		add_child(_pick_mark)
	_pick_mark.visible = on
	if on:
		_pick_mark.move_to_front()
		tooltip_text = "Click to edit %s" % str(data.get("name", ""))

## Editor open: a click opens this tracker (or group) in it.
func _on_pick(ev: InputEvent) -> void:
	if not picking or not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	TrackerEditor.open(get_tree(), str(data.get("id", "")))
	accept_event()

func _on_click(ev: InputEvent) -> void:
	if picking:
		return   # (the editor is open: a click picks it instead)
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	var engine := TrackerEngine.of(get_tree())
	var player: Node = engine.hud.player if engine != null and engine.hud != null else null
	var action := str(data.get("display", {}).get("click", ""))
	if player != null and action != "" and player.has_method("tracker_action"):
		player.tracker_action(action)
		accept_event()

## The state from the engine, and the conditions' changes.
func show_state(state: Dictionary, changes: Dictionary) -> void:
	st = state
	mods = changes
	var on := bool(st.get("active", false)) or preview
	if on and not _was_active and bool(data.get("display", {}).get("sound", false)) and not preview:
		var audio := get_node_or_null("/root/Audio")
		if audio:
			audio.play_sfx("crit")
	_was_active = on
	visible = active() and not is_group
	var a := float(mods.get("alpha", 1.0)) if mods.get("alpha") is float else 1.0
	modulate.a = a if on else MISSING_ALPHA
	if visible and tooltip_text == "" and str(data.get("display", {}).get("click", "")) != "":
		var engine := TrackerEngine.of(get_tree())
		var player: Node = engine.hud.player if engine != null and engine.hud != null else null
		if player != null and player.has_method("tracker_actions"):
			tooltip_text = str(player.tracker_actions().get(data["display"]["click"], ""))
	_refresh_bar()
	queue_redraw()

## Showing: its triggers are on, or it's loaded and kept while missing.
func active() -> bool:
	if bool(st.get("active", false)) or preview:
		return true
	return not is_group and bool(data.get("display", {}).get("show_missing", false)) and not bool(st.get("unloaded", false))

func _color() -> Color:
	var c: Variant = mods.get("color")
	return c if c is Color else data["display"]["color"]

func _text_color(which: String) -> Color:
	var c: Variant = mods.get(which + "_color")
	return c if c is Color else data["display"].get(which + "_color", Color.WHITE)

func _text(which := "text") -> String:
	if mods.get(which) is String and str(mods[which]) != "":
		return Trackers.format_text(str(mods[which]), st)
	return Trackers.format_text(str(data["display"].get(which, "")), st)

func _frac() -> float:
	var dur := float(st.get("duration", 0.0))
	if dur > 0.0:
		return clampf(float(st.get("time", 0.0)) / dur, 0.0, 1.0)
	var mx := float(st.get("max", 0.0))
	if mx > 0.0:
		return clampf(float(st.get("value", 0.0)) / mx, 0.0, 1.0)
	return 1.0

func _refresh_bar() -> void:
	if _bar == null:
		return
	_bar.fill_color = _color()
	_bar.set_fracs(_frac())
	var right := UISkin.time_text(float(st.get("time", 0.0))) if bool(data["display"].get("time_text", true)) else ""
	_bar.set_texts(_text(), _text("text2"), right)

func _process(delta: float) -> void:
	if not visible or is_group:
		return
	# Timers run down between the engine's sweeps.
	if float(st.get("time", 0.0)) > 0.0:
		st["time"] = maxf(float(st["time"]) - delta, 0.0)
		_refresh_bar()
		queue_redraw()
	var glow: bool = bool(mods.get("glow")) if mods.get("glow") is bool else bool(data["display"].get("glow", false))
	if glow:
		_glow_t += delta
		if _over:
			_over.queue_redraw()

func _icon_id() -> String:
	var ic := str(data["display"].get("icon", "auto"))
	return str(st.get("icon", "")) if ic == "auto" else ic

## The icon (a child, so an ability's icon draws at its own size) and, over it,
## the sweep, texts and glow.
var _icon: Control
var _over: Control

func _make_layers() -> void:
	if _icon == null:
		_icon = Control.new()
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon.draw.connect(func(): _draw_icon(_icon))
		add_child(_icon)
		_over = Control.new()
		_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_over.draw.connect(func(): _draw_over(_over))
		add_child(_over)
	var type := str(data["display"]["type"])
	var has_icon := type == "icon" or (type == "bar" and str(data["display"].get("icon", "auto")) != "none")
	_icon.visible = has_icon
	_icon.position = Vector2.ZERO
	_icon.size = size if type == "icon" else Vector2(size.y, size.y)
	_over.position = Vector2.ZERO
	_over.size = size
	move_child(_over, get_child_count() - 1)

func _draw() -> void:
	if _icon:
		_icon.queue_redraw()
		_over.queue_redraw()

func _draw_icon(c: Control) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(r, Color.BLACK)
	var id := _icon_id()
	if id == "" and not bool(st.get("active", false)) and not preview:
		c.draw_rect(r.grow(-1), UISkin.BAR_BG)   # an empty cell (shown while missing)
		return
	if AbilitiesScript.PATHS.has(id):
		AbilitiesScript.draw_icon(c, id)
		return
	var inner := r.grow(-1)
	var fx: Resource = EffectsScript.get_effect(id) if id != "" else null
	var tex: Texture2D = fx.get("icon") if fx != null else null
	if tex:
		c.draw_texture_rect(tex, inner, false)
		return
	var col: Color = fx.color if fx != null else _color()
	c.draw_rect(inner, col.darkened(0.55))
	var fs := UISkin.font(clampi(int(r.size.y * 0.4), 9, 20))
	var nm := str(st.get("name", "?"))
	_outlined(c, Vector2(0, r.size.y * 0.5 + fs * 0.36), nm.substr(0, 2), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, col.lightened(0.45))

func _draw_over(c: Control) -> void:
	if data.is_empty():
		return
	var d: Dictionary = data["display"]
	var type := str(d["type"])
	var small := UISkin.font(clampi(int(size.y * 0.32), 9, 18))
	match type:
		"icon":
			var left := float(st.get("time", 0.0))
			var dur := float(st.get("duration", 0.0))
			if left > 0.0 and dur > 0.0:
				var h := size.y * clampf(left / dur, 0.0, 1.0)
				c.draw_rect(Rect2(1, size.y - h, size.x - 2, maxf(h - 1, 0.0)), Color(0, 0, 0, 0.6))
			_outlined(c, Vector2(2, size.y - 3), _text(), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 4, small, _text_color("text"))
			_outlined(c, Vector2(0, small + 1), _text("text2"), HORIZONTAL_ALIGNMENT_CENTER, size.x, small, _text_color("text2"))
			if bool(d.get("time_text", true)) and left > 0.0:
				_outlined(c, Vector2(0, size.y * 0.5 + small * 0.36), UISkin.time_text(left), HORIZONTAL_ALIGNMENT_CENTER, size.x, small, Color(1, 0.95, 0.6))
		"text":
			var fs := UISkin.font(clampi(int(size.y * 0.72), 9, 48))
			_outlined(c, Vector2(0, size.y * 0.5 + fs * 0.36), _text(), HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, _color())
			_outlined(c, Vector2(0, size.y * 0.5 + fs * 0.36), _text("text2"), HORIZONTAL_ALIGNMENT_RIGHT, size.x, fs, _text_color("text2"))
		"ring":
			var mid := size / 2.0
			var r := minf(size.x, size.y) / 2.0 - 3.0
			c.draw_arc(mid, r, 0, TAU, 48, Color(0, 0, 0, 0.7), 5.0)
			c.draw_arc(mid, r, -PI / 2.0, -PI / 2.0 + TAU * _frac(), 48, _color(), 4.0)
			_outlined(c, Vector2(0, mid.y + small * 0.36), _text(), HORIZONTAL_ALIGNMENT_CENTER, size.x, small, _text_color("text"))
			_outlined(c, Vector2(0, size.y - 1), _text("text2"), HORIZONTAL_ALIGNMENT_CENTER, size.x, small, _text_color("text2"))
		"pips":
			_draw_pips(c)
	var glow: bool = bool(mods.get("glow")) if mods.get("glow") is bool else bool(d.get("glow", false))
	if glow and type != "text":
		var a := 0.55 + 0.45 * sin(_glow_t * 6.0)
		c.draw_rect(Rect2(Vector2(-2, -2), size + Vector2(4, 4)), Color(1.0, 0.85, 0.3, a), false, 2.0)

## Pips: one per point up to the max (the value's own colours when it has them).
## With a second text, the pips take the left 60% and the text the rest.
func _draw_pips(c: Control) -> void:
	var n := clampi(int(round(float(st.get("max", 0.0)))), 1, 30)
	var filled := int(floor(float(st.get("value", 0.0)) + 0.001))
	var colors: Array = st.get("colors", [])
	var t2 := _text("text2")
	var w := size.x * (0.6 if t2 != "" else 1.0)
	var gap := 2.0
	var cell := maxf((w - gap * (n - 1)) / n, 1.0)
	for i in n:
		var r := Rect2(i * (cell + gap), 0, cell, size.y)
		c.draw_rect(r, Color.BLACK)
		var col: Color = UISkin.BAR_BG
		if i < filled:
			col = colors[i] if i < colors.size() and colors[i] is Color else _color()
		c.draw_rect(r.grow(-1), col)
	var fs := UISkin.font(clampi(int(size.y * 0.9), 9, 16))
	_outlined(c, Vector2(0, size.y * 0.5 + fs * 0.36), _text(), HORIZONTAL_ALIGNMENT_CENTER, w, fs, _text_color("text"))
	if t2 != "":
		_outlined(c, Vector2(w + 4, size.y * 0.5 + fs * 0.36), t2, HORIZONTAL_ALIGNMENT_LEFT, size.x - w - 4, fs, _text_color("text2"))

func _outlined(c: Control, at: Vector2, t: String, align: HorizontalAlignment, w: float, fs: int, col: Color) -> void:
	if t == "":
		return
	var f := c.get_theme_default_font()
	c.draw_string_outline(f, at, t, align, w, fs, 3, Color.BLACK)
	c.draw_string(f, at, t, align, w, fs, col)

## A group: place its showing trackers' displays one after another.
func layout_group(children: Array) -> void:
	var grow := str(data.get("grow", "up"))
	var align := str(data.get("align", "start"))
	var gap := float(data.get("spacing", 2))
	var shown := children.filter(func(c): return c.active())
	match str(data.get("sort", "time")):
		"time":
			shown.sort_custom(func(a, b):
				var ta := float(a.st.get("time", 0.0)) if float(a.st.get("time", 0.0)) > 0.0 else 1e9
				var tb := float(b.st.get("time", 0.0)) if float(b.st.get("time", 0.0)) > 0.0 else 1e9
				return ta < tb)
		"name":
			shown.sort_custom(func(a, b): return str(a.data["name"]) < str(b.data["name"]))
	var at := 0.0
	var box := Vector2.ZERO
	for c in children:
		box = box.max(c.size)
	var across := 0 if grow == "down" or grow == "up" else 1   # the axis it doesn't grow along
	for c in shown:
		var pos := Vector2.ZERO
		match grow:
			"down": pos = Vector2(0, at)
			"up": pos = Vector2(0, -at - c.size.y + box.y)
			"right": pos = Vector2(at, 0)
			"left": pos = Vector2(-at - c.size.x + box.x, 0)
		# Alignment across: a smaller display sits at the start, the middle or the end of the row.
		var slack: float = box.x - c.size.x if across == 0 else box.y - c.size.y
		var off := slack * (0.5 if align == "center" else (1.0 if align == "end" else 0.0))
		if across == 0:
			pos.x += off
		else:
			pos.y += off
		c.position = pos
		at += (c.size.y if grow == "down" or grow == "up" else c.size.x) + gap
	# The group's own box (for Move UI): room for one display.
	var s := box.max(Vector2(40, 20))
	if size != s:
		size = s
