extends HudElement

# Errors ("Not enough mana") and notes ("Level 12!", "Looted: ...") as outlined
# text that fades after a moment (scripts/ui/message_banner.gd without its box).

const MessageBanner = preload("res://scripts/ui/message_banner.gd")
const W := 420.0
const H := 34.0

var banner: Control

func _init() -> void:
	super()
	key = "messages"
	title = "Messages"
	always = true

func build() -> void:
	banner = MessageBanner.new()
	banner.plain = true
	add_child(banner)

func layout() -> void:
	set_box(Vector2(W, H))
	if banner:
		banner.font_size = UISkin.font(int(cfg("font_size")))
		# Centred in the element's box both ways (the box is what Move UI places).
		banner.anchor_top = 0.5
		banner.anchor_bottom = 0.5
		banner.grow_vertical = Control.GROW_DIRECTION_BOTH
		banner.bottom = 0.0

func show_message(msg: String, color: Color) -> void:
	banner.show_message(msg, color)
