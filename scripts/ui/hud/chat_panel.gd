extends HudElement

# The bottom-left panel: the chat (Chat / Logs tabs, scripts/ui/chat_box.gd) on
# top, an info strip under it with the micro menu (Character, Spellbook, Bank,
# Bags, Meter) and up to three info texts. Size and texts: UI Options > Panels.

const CHAT_BOX = preload("res://scripts/ui/chat_box.gd")

var chat_box: PanelContainer
var strip: InfoStrip

func _init() -> void:
	super()
	key = "chat_panel"
	mover_key = "chat"
	title = "Chat"

func build() -> void:
	chat_box = CHAT_BOX.new()
	chat_box.docked = true
	add_child(chat_box)
	strip = InfoStrip.new()
	strip.elem = key
	add_child(strip)

## A small micro menu button in the strip (game_ui.gd adds them).
func add_button(text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, InfoStrip.H - 2)
	b.add_theme_font_size_override("font_size", UISkin.font(10))
	b.add_theme_constant_override("h_separation", 0)
	for s in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb := UISkin.button_box("hover" if s == "hover" else ("active" if s.contains("pressed") else "normal"))
		sb.content_margin_left = 5
		sb.content_margin_right = 5
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		b.add_theme_stylebox_override(s, sb)
	strip.buttons.add_child(b)
	layout.call_deferred()
	return b

func layout() -> void:
	if chat_box == null:
		return
	var w := float(cfg("width"))
	var h := float(cfg("height"))
	var show_strip := bool(cfg("info_strip"))
	var ch: float = chat_box.COLLAPSED_HEIGHT if chat_box.collapsed else h
	chat_box.position = Vector2.ZERO
	chat_box.size = Vector2(w, ch)
	strip.visible = show_strip
	strip.position = Vector2(0, ch + 2)
	strip.size = Vector2(w, InfoStrip.H)
	strip.layout()
	set_box(Vector2(w, ch + (InfoStrip.H + 2 if show_strip else 0.0)))

func slow_update() -> void:
	# (Collapsing the chat shrinks the panel.)
	var ch: float = chat_box.COLLAPSED_HEIGHT if chat_box.collapsed else float(cfg("height"))
	if not is_equal_approx(chat_box.size.y, ch):
		layout()
