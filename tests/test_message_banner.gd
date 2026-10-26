@tool
extends McpTestSuite

# Every error message (main menu toasts, the HUD's action errors) shows in one
# framed banner, low on the screen: scripts/ui/message_banner.gd.

const MessageBanner = preload("res://scripts/ui/message_banner.gd")

func suite_name() -> String:
	return "message_banner"

func test_shows_framed_text() -> void:
	var b: Control = track(MessageBanner.new())
	assert_false(b.visible, "hidden until a message comes")
	b.show_message("Not enough mana")
	assert_true(b.visible)
	assert_eq(b.text(), "Not enough mana")
	var sb := b.get_theme_stylebox("panel") as StyleBoxFlat
	assert_true(sb != null and sb.bg_color.a > 0.8 and sb.border_width_top > 0, "a solid background with a frame")
	b.show_message("")
	assert_eq(b.text(), "Not enough mana", "an empty message changes nothing")

func test_used_for_every_error() -> void:
	var menu := FileAccess.get_file_as_string("res://scripts/main_menu.gd")
	assert_contains(menu, "_banner().show_message(msg, MessageBanner.ERROR)")
	assert_contains(menu, "action_error.connect(_toast_if)", "errors raised elsewhere show in the menu too")
	assert_contains(FileAccess.get_file_as_string("res://scripts/hud.gd"), "_error_label.show_message(msg, color)")
