class_name UISkin

# The in-game UI's one look (HUD, panels, info texts, trackers): flat, sharp
# corners, a near-black backdrop with a 1 px black outer line and a dim inner
# line, flat bars, outlined text. The main menu keeps ui_kit.gd.
#   panel.add_theme_stylebox_override("panel", UISkin.backdrop())
#   var bar := UISkin.make_bar(Vector2(240, 20), UISkin.HEALTH)

const BG := Color(0.055, 0.058, 0.066)
const INNER := Color(0.2, 0.2, 0.22)
const EDGE := Color(0, 0, 0)
const BAR_BG := Color(0.11, 0.11, 0.12)
const TEXT := Color(0.94, 0.94, 0.94)
const DIM := Color(0.6, 0.6, 0.64)
const HEALTH := Color(0.2, 0.72, 0.3)
const HEALTH_LOW := Color(0.85, 0.2, 0.15)
const HOSTILE := Color(0.78, 0.16, 0.14)
const SHIELD := Color(0.72, 0.9, 1.0, 0.85)
const CAST := Color(0.45, 0.85, 1.0)
const CAST_FAIL := Color(0.9, 0.25, 0.2)
const ENEMY_CAST := Color(1.0, 0.72, 0.15)
const POWER := {
	"mana": Color(0.25, 0.5, 1.0),
	"energy": Color(1.0, 0.85, 0.2),
	"fury": Color(0.9, 0.25, 0.1),
}


## The panel look: backdrop at the General page's alpha (or `alpha`), dim inner
## line, black outer line (drawn as a 1 px shadow so it sits outside the box).
static func backdrop(alpha := -1.0, pad := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var a := alpha if alpha >= 0.0 else float(UIConfig.value("general", "backdrop_alpha"))
	sb.bg_color = Color(BG, a)
	sb.border_color = Color(INNER, maxf(a, 0.6))
	sb.set_border_width_all(1)
	sb.shadow_color = EDGE
	sb.shadow_size = 1
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(pad)
	sb.anti_aliasing = false
	return sb

## An action button's look: "normal", "hover", "active" (being cast) or "queued".
static func button_box(state := "normal") -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.035, 0.95)
	sb.set_border_width_all(1)
	sb.border_color = Color(0, 0, 0)
	match state:
		"hover":
			sb.border_color = Color(0.9, 0.9, 0.9)
		"active":
			sb.border_color = accent()
			sb.set_border_width_all(2)
		"queued":
			sb.border_color = Color(0.55, 0.9, 1.0)
			sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	return sb

static func accent() -> Color:
	var c: Variant = UIConfig.value("general", "accent")
	return c if c is Color else Color(0.3, 0.75, 1.0)

## Font size scaled by the General page's base font size (12 = as given).
static func font(base: int) -> int:
	return maxi(8, int(round(base * float(UIConfig.value("general", "font_size")) / 12.0)))

static func label(text := "", size := 12, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font(size))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func make_bar(size: Vector2, color: Color) -> HudBar:
	var b := HudBar.new()
	b.custom_minimum_size = size
	b.size = size
	b.fill_color = color
	return b

## A health colour: "class" (the spec's book colour), "gradient" (green to red)
## or "custom", per the General page.
static func health_color(frac: float, book_color: Color = HEALTH) -> Color:
	match str(UIConfig.value("general", "health_color")):
		"class":
			return book_color
		"gradient":
			return HEALTH_LOW.lerp(HEALTH, clampf(frac * 1.4 - 0.2, 0.0, 1.0))
		"custom":
			var c: Variant = UIConfig.value("general", "health_custom")
			return c if c is Color else HEALTH
	return HEALTH

## "1234 / 2000", "62%", "1234 - 62%" or "-766", per a frame's text option.
static func value_text(fmt: String, cur: float, mx: float) -> String:
	var pct := int(round(clampf(cur / maxf(mx, 1.0), 0.0, 1.0) * 100.0))
	match fmt:
		"percent":
			return "%d%%" % pct
		"both":
			return "%s - %d%%" % [short(int(cur)), pct]
		"deficit":
			return "" if cur >= mx else "-%s" % short(int(mx - cur))
		"none":
			return ""
	return "%s / %s" % [short(int(cur)), short(int(mx))]

## 950, 12.3k, 1.2m.
static func short(n: int) -> String:
	if absi(n) < 10000:
		return str(n)
	if absi(n) < 1000000:
		return "%.1fk" % (n / 1000.0)
	return "%.1fm" % (n / 1000000.0)

## Seconds as a short clock: "8", "1.4" under 3 s, "2m", "1h".
static func time_text(left: float) -> String:
	if left <= 0.0:
		return ""
	if left < 3.0:
		return "%.1f" % left
	if left < 60.0:
		return "%d" % ceili(left)
	if left < 3600.0:
		return "%dm" % ceili(left / 60.0)
	return "%dh" % ceili(left / 3600.0)

# --- Windows built with ui_kit (Character, Bags, Bank, Spellbook, Esc menu...) ----------

const Kit = preload("res://scripts/ui_kit.gd")
const _BOXES := ["panel", "normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]
const _FONT_COLORS := ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]
static var _theme: Theme

## Puts ui_kit-built controls under `root` in this look: sharp corners, flat
## fills, the accent instead of the menu's gold. Safe to run again (on rows a
## window builds later). Give the window theme() too, for the stock controls
## (tabs, drop-downs, sliders, scroll bars, text boxes).
static func restyle(root: Node) -> void:
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	for n in nodes:
		if not (n is Control):
			continue
		var c := n as Control
		for box_name in _BOXES:
			if c.has_theme_stylebox_override(box_name):
				var sb := c.get_theme_stylebox(box_name)
				if sb is StyleBoxFlat and (sb as StyleBoxFlat).corner_radius_top_left > 0:
					c.add_theme_stylebox_override(box_name, _flat(sb, box_name))
		for col_name in _FONT_COLORS:
			if c.has_theme_color_override(col_name):
				c.add_theme_color_override(col_name, _col(c.get_theme_color(col_name)))
		if c is Label and c.has_theme_constant_override("outline_size"):
			c.add_theme_color_override("font_outline_color", Color.BLACK)
			c.add_theme_constant_override("outline_size", 3)

static func _flat(src: StyleBoxFlat, box_name: String) -> StyleBoxFlat:
	if box_name == "panel" and src.bg_color.a >= 0.5:
		var p := backdrop(maxf(src.bg_color.a, 0.9) if src.bg_color.a >= 0.9 else src.bg_color.a)
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			p.set_content_margin(side, src.get_content_margin(side))
		return p
	var sb := src.duplicate() as StyleBoxFlat
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	if sb.bg_color.is_equal_approx(Kit.BG):
		sb.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	elif sb.bg_color.is_equal_approx(Kit.PANEL_BG):
		sb.bg_color = Color(BG, 0.97)
	if sb.border_color.is_equal_approx(Kit.BORDER):
		sb.border_color = Color(0.26, 0.26, 0.28)
	elif box_name == "hover" and _is_gold(sb.border_color):
		sb.border_color = Color(0.9, 0.9, 0.9)
	else:
		sb.border_color = _col(sb.border_color)
	return sb

## The menu gold (and its darker shades) becomes the accent; other colours stay.
static func _col(c: Color) -> Color:
	if not _is_gold(c):
		return c
	var a := accent().darkened(clampf(1.0 - c.v / Kit.ACCENT.v, 0.0, 1.0))
	a.a = c.a
	return a

static func _is_gold(c: Color) -> bool:
	return absf(c.h - Kit.ACCENT.h) < 0.01 and absf(c.s - Kit.ACCENT.s) < 0.04

## Stock controls in this look (made once).
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	var btn := {}
	for s in ["normal", "hover", "pressed", "disabled"]:
		var sb := button_box("hover" if s == "hover" else ("active" if s == "pressed" else "normal"))
		sb.bg_color = Color(0.1, 0.1, 0.12, 0.95) if s != "disabled" else Color(0.06, 0.06, 0.07, 0.8)
		sb.border_color = Color(0.26, 0.26, 0.28) if s in ["normal", "disabled"] else sb.border_color
		sb.set_content_margin_all(4)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		btn[s] = sb
	for type in ["Button", "OptionButton", "MenuButton"]:
		for s in btn:
			t.set_stylebox(s, type, btn[s])
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
	var field := backdrop(0.95, 4)
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", StyleBoxEmpty.new())
	t.set_stylebox("normal", "TextEdit", field)
	t.set_stylebox("focus", "TextEdit", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", backdrop(0.97, 6))
	t.set_stylebox("panel", "PopupMenu", backdrop(0.98, 4))
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(accent(), 0.25)
	t.set_stylebox("hover", "PopupMenu", hover)
	t.set_stylebox("panel", "TabContainer", backdrop(0.6, 8))
	var tab_on := StyleBoxFlat.new()
	tab_on.bg_color = Color(0.12, 0.12, 0.14)
	tab_on.border_color = accent()
	tab_on.border_width_bottom = 2
	tab_on.set_content_margin_all(6)
	var tab_off := tab_on.duplicate() as StyleBoxFlat
	tab_off.bg_color = Color(0.06, 0.06, 0.07)
	tab_off.border_color = Color(0, 0, 0)
	var tab_hover := tab_off.duplicate() as StyleBoxFlat
	tab_hover.bg_color = Color(0.1, 0.1, 0.12)
	t.set_stylebox("tab_selected", "TabContainer", tab_on)
	t.set_stylebox("tab_unselected", "TabContainer", tab_off)
	t.set_stylebox("tab_hovered", "TabContainer", tab_hover)
	t.set_color("font_selected_color", "TabContainer", accent())
	var track := StyleBoxFlat.new()
	track.bg_color = BAR_BG
	track.set_content_margin_all(3)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.32, 0.32, 0.35)
	var grab_hi := grab.duplicate() as StyleBoxFlat
	grab_hi.bg_color = Color(0.5, 0.5, 0.54)
	for type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", type, track)
		t.set_stylebox("grabber", type, grab)
		t.set_stylebox("grabber_highlight", type, grab_hi)
		t.set_stylebox("grabber_pressed", type, grab_hi)
	var slider := StyleBoxFlat.new()
	slider.bg_color = BAR_BG
	slider.content_margin_top = 2
	slider.content_margin_bottom = 2
	var fill := slider.duplicate() as StyleBoxFlat
	fill.bg_color = accent()
	t.set_stylebox("slider", "HSlider", slider)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	_theme = t
	return t

## restyle() plus theme() on a window (or any control) in one call.
static func skin_window(c: Control) -> void:
	restyle(c)
	c.theme = theme()
