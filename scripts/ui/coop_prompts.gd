extends CanvasLayer

# Co-op prompts for the local player (child "CoopPrompts" of the player):
#   - while you're DOWNED: a red screen edge, "You are down", the bleed-out
#     countdown bar and how to give up (only a healer can revive you).

const Balance = preload("res://scripts/balance.gd")

var _player: Node
var _shade: ColorRect
var _down_box: VBoxContainer
var _down_title: Label
var _down_info: Label
var _bar_bg: ColorRect
var _bar_fill: ColorRect
var _max_bleed := Balance.DOWNED_BLEED_OUT

const BAR_W := 360.0

func _ready() -> void:
	layer = 6
	_player = get_parent()
	_shade = ColorRect.new()
	_shade.color = Color(0.35, 0.0, 0.0, 0.3)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.visible = false
	add_child(_shade)

	_down_box = VBoxContainer.new()
	_down_box.anchor_left = 0.5
	_down_box.anchor_right = 0.5
	_down_box.anchor_top = 0.28
	_down_box.anchor_bottom = 0.28
	_down_box.offset_left = -BAR_W / 2.0 - 60
	_down_box.offset_right = BAR_W / 2.0 + 60
	_down_box.add_theme_constant_override("separation", 8)
	_down_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_down_box.visible = false
	add_child(_down_box)
	_down_title = _label(38, Color(1.0, 0.55, 0.3))
	_down_title.text = "You are down!"
	_down_box.add_child(_down_title)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(BAR_W, 14)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_down_box.add_child(bar)
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0, 0, 0, 0.6)
	_bar_bg.size = Vector2(BAR_W, 14)
	bar.add_child(_bar_bg)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.85, 0.2, 0.15)
	_bar_fill.size = Vector2(BAR_W, 14)
	bar.add_child(_bar_fill)
	_down_info = _label(18, Color(1.0, 0.9, 0.85))
	_down_box.add_child(_down_info)

func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _key(action: String) -> String:
	var s := get_node_or_null("/root/Settings")
	return str(s.key_text(action)) if s else action

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var downed: bool = _player.has_method("is_downed") and _player.is_downed()
	if downed and not _down_box.visible:
		_max_bleed = maxf(float(_player.bleed_out_left()), 1.0)
	_shade.visible = downed
	_down_box.visible = downed
	if downed:
		var left := float(_player.bleed_out_left())
		_bar_fill.size.x = BAR_W * clampf(left / _max_bleed, 0.0, 1.0)
		_down_info.text = "Bleeding out in %d s - a healer can revive you\nPress %s to give up" \
			% [int(ceil(left)), _key("restart")]
		_shade.color.a = 0.22 + 0.1 * sin(Time.get_ticks_msec() / 250.0)
