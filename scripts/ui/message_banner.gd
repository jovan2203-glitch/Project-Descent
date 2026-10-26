extends PanelContainer

# A short message (errors in red, other notes in their colour) in a framed dark
# box, centered low on the screen, fading out after a moment. Used for every
# error: the main menu's toasts and the HUD's action errors (SignalBus.action_error).
# Usage: var b := MessageBanner.new(); b.bottom = -40.0; parent.add_child(b)
#        b.show_message("Not enough mana", MessageBanner.ERROR)

const ERROR := Color(1.0, 0.38, 0.32)
const SHOW_TIME := 1.6   # seconds fully shown before it fades
const FADE_TIME := 0.5

## Distance of its bottom edge from the bottom of the screen (negative = up).
var bottom := -40.0:
	set(v):
		bottom = v
		offset_bottom = v
		offset_top = v

var _label: Label
var _tween: Tween

func _init() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN   # grows up from its bottom edge
	custom_minimum_size = Vector2(300, 0)   # (a steady box for Move UI)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	modulate.a = 0.0
	visible = false
	_style(ERROR)

func _style(col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.045, 0.06, 0.94)
	sb.border_color = col.darkened(0.15)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	add_theme_stylebox_override("panel", sb)

## Shows `text` in `col` (frame and text), replacing any message still showing.
func show_message(text: String, col: Color = ERROR) -> void:
	if text == "":
		return
	_label.text = text
	_label.add_theme_color_override("font_color", col)
	_style(col)
	reset_size()   # shrink to the new text (it stays centered: grows both ways)
	visible = true
	modulate.a = 1.0
	move_to_front()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(SHOW_TIME)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	_tween.tween_callback(hide)

func text() -> String:
	return _label.text
