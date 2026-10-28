extends Control
class_name TrackerDisplay

# One tracker on screen (scripts/ui/trackers/trackers.gd): an icon with a
# cooldown sweep, stacks and time; a bar filling by time left or value; a text;
# or a ring. A group's display holds its trackers' displays and stacks the
# active ones (grow direction, spacing, sort). The engine (tracker_engine.gd)
# hands each its state ten times a second; timers run down smoothly between.

const AbilitiesScript = preload("res://scripts/abilities.gd")
const EffectsScript = preload("res://scripts/core/effects.gd")

var data: Dictionary = {}
var is_group := false
var st: Dictionary = {"active": false}
var mods: Dictionary = {}           # what the conditions changed right now
var preview := false                # the editor's preview: always shown, made-up values
var _bar: HudBar
var _glow_t := 0.0
var _was_active := false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

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
	_make_layers()
	queue_redraw()

## The state from the engine, and the conditions' changes.
func show_state(state: Dictionary, changes: Dictionary) -> void:
	st = state
	mods = changes
	var active := bool(st.get("active", false)) or preview
	if active and not _was_active and bool(data.get("display", {}).get("sound", false)) and not preview:
		var audio := get_node_or_null("/root/Audio")
		if audio:
			audio.play_sfx("crit")
	_was_active = active
	visible = active and not is_group
	modulate.a = float(mods.get("alpha", 1.0)) if mods.get("alpha") is float else 1.0
	_refresh_bar()
	queue_redraw()

func active() -> bool:
	return bool(st.get("active", false)) or preview

func _color() -> Color:
	var c: Variant = mods.get("color")
	if c is Color:
		return c
	var d: Color = data["display"]["color"]
	var sc: Color = st.get("color", Color(0, 0, 0, 0))
	return d if sc.a <= 0.0 or str(data["display"]["type"]) != "icon" else d

func _text() -> String:
	if mods.get("text") is String and str(mods["text"]) != "":
		return Trackers.format_text(str(mods["text"]), st)
	return Trackers.format_text(str(data["display"]["text"]), st)

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
	var t := _text()
	var right := UISkin.time_text(float(st.get("time", 0.0))) if bool(data["display"].get("time_text", true)) else ""
	_bar.set_texts(t, "", right)

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
	match type:
		"icon":
			var left := float(st.get("time", 0.0))
			var dur := float(st.get("duration", 0.0))
			if left > 0.0 and dur > 0.0:
				var h := size.y * clampf(left / dur, 0.0, 1.0)
				c.draw_rect(Rect2(1, size.y - h, size.x - 2, maxf(h - 1, 0.0)), Color(0, 0, 0, 0.6))
			var fs := UISkin.font(clampi(int(size.y * 0.32), 9, 18))
			var t := _text()
			if t != "":
				_outlined(c, Vector2(2, size.y - 3), t, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 4, fs, Color.WHITE)
			if bool(d.get("time_text", true)) and left > 0.0:
				_outlined(c, Vector2(0, size.y * 0.5 + fs * 0.36), UISkin.time_text(left), HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color(1, 0.95, 0.6))
		"text":
			var fs := UISkin.font(clampi(int(size.y * 0.72), 9, 48))
			_outlined(c, Vector2(0, size.y * 0.5 + fs * 0.36), _text(), HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, _color())
		"ring":
			var mid := size / 2.0
			var r := minf(size.x, size.y) / 2.0 - 3.0
			c.draw_arc(mid, r, 0, TAU, 48, Color(0, 0, 0, 0.7), 5.0)
			c.draw_arc(mid, r, -PI / 2.0, -PI / 2.0 + TAU * _frac(), 48, _color(), 4.0)
			var fs := UISkin.font(clampi(int(size.y * 0.3), 9, 18))
			_outlined(c, Vector2(0, mid.y + fs * 0.36), _text(), HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color.WHITE)
	var glow: bool = bool(mods.get("glow")) if mods.get("glow") is bool else bool(d.get("glow", false))
	if glow and type != "text":
		var a := 0.55 + 0.45 * sin(_glow_t * 6.0)
		c.draw_rect(Rect2(Vector2(-2, -2), size + Vector2(4, 4)), Color(1.0, 0.85, 0.3, a), false, 2.0)

func _outlined(c: Control, at: Vector2, t: String, align: HorizontalAlignment, w: float, fs: int, col: Color) -> void:
	var f := c.get_theme_default_font()
	c.draw_string_outline(f, at, t, align, w, fs, 3, Color.BLACK)
	c.draw_string(f, at, t, align, w, fs, col)

## A group: place its active trackers' displays one after another.
func layout_group(children: Array) -> void:
	var grow := str(data.get("grow", "up"))
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
	for c in shown:
		match grow:
			"down": c.position = Vector2(0, at)
			"up": c.position = Vector2(0, -at - c.size.y + box.y)
			"right": c.position = Vector2(at, 0)
			"left": c.position = Vector2(-at - c.size.x + box.x, 0)
		at += (c.size.y if grow == "down" or grow == "up" else c.size.x) + gap
	# The group's own box (for Move UI): room for one display.
	var s := box.max(Vector2(40, 20))
	if size != s:
		size = s
