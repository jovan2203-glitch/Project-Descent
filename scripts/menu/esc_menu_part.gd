extends "res://scripts/menu/menu_part.gd"
class_name EscMenuPart

# Moved out of scripts/main_menu.gd as it was (menu = the menu node). Hooked up from
# main_menu.gd through its var "esc".
# --- Part: Esc menu (Resume / Settings / Wipe / Quit) --------
func _build_esc_menu() -> void:
	menu.esc_menu = UI.small_panel("Menu")
	menu.esc_menu.offset_top = -175
	menu.esc_menu.offset_bottom = 160
	var content: VBoxContainer = menu.esc_menu.get_meta("content")
	var resume := UI.button("Resume", 18, Vector2(0, 42))
	resume.pressed.connect(_hide_esc)
	content.add_child(resume)
	var settings := UI.button("Settings", 18, Vector2(0, 42))
	settings.pressed.connect(_open_settings)
	content.add_child(settings)
	var macros := UI.button("Macros", 18, Vector2(0, 42))
	macros.pressed.connect(func():
		_hide_esc()
		MacroWindow.open(menu.ui, false))
	content.add_child(macros)
	var wipe := UI.button("Wipe Save", 18, Vector2(0, 42))
	wipe.add_theme_color_override("font_color", Color(1, 0.45, 0.4))
	wipe.add_theme_color_override("font_hover_color", Color(1, 0.6, 0.55))
	wipe.tooltip_text = "Delete your character and progress. Settings and keybinds are kept."
	wipe.pressed.connect(_open_wipe)
	content.add_child(wipe)
	var quit := UI.button("Quit", 18, Vector2(0, 42))
	quit.pressed.connect(func(): menu.get_node("/root/GameManager").quit_game())
	content.add_child(quit)
	menu.esc_menu.visible = false
	menu.ui.add_child(menu.esc_menu)

	menu.settings_panel = UI.small_panel("Settings")
	menu.settings_panel.offset_left = -250
	menu.settings_panel.offset_right = 250
	menu.settings_panel.offset_top = -250
	menu.settings_panel.offset_bottom = 250
	var s_content: VBoxContainer = menu.settings_panel.get_meta("content")
	s_content.add_child(menu.get_node("/root/Settings").build_settings_ui())
	var back := UI.button("Back", 18, Vector2(0, 42))
	back.pressed.connect(_back_from_settings)
	s_content.add_child(back)
	menu.settings_panel.visible = false
	menu.ui.add_child(menu.settings_panel)

	# "Wipe Save" confirmation.
	menu.wipe_panel = UI.small_panel("Wipe Save?")
	menu.wipe_panel.offset_left = -230
	menu.wipe_panel.offset_right = 230
	menu.wipe_panel.offset_top = -140
	menu.wipe_panel.offset_bottom = 140
	var w_content: VBoxContainer = menu.wipe_panel.get_meta("content")
	var warn := UI.label("This permanently deletes your character: level, XP, gear, bank, runes, talents, Skill Cards, checkpoints and stats.\n\nYour settings and keybinds are kept. The game restarts afterwards.", 14, Color(0.9, 0.9, 0.92))
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warn.custom_minimum_size = Vector2(380, 0)
	w_content.add_child(warn)
	var w_row := HBoxContainer.new()
	w_row.alignment = BoxContainer.ALIGNMENT_CENTER
	w_row.add_theme_constant_override("separation", 10)
	w_content.add_child(w_row)
	var confirm := UI.button("Wipe everything", 18, Vector2(180, 42))
	confirm.add_theme_color_override("font_color", Color(1, 0.45, 0.4))
	confirm.add_theme_color_override("font_hover_color", Color(1, 0.6, 0.55))
	confirm.pressed.connect(func(): menu.get_node("/root/SaveSystem").wipe_and_restart())
	w_row.add_child(confirm)
	var cancel := UI.button("Cancel", 18, Vector2(120, 42))
	cancel.pressed.connect(_back_from_wipe)
	w_row.add_child(cancel)
	menu.wipe_panel.visible = false
	menu.ui.add_child(menu.wipe_panel)

	# Dim backdrop behind the menu that also blocks clicks on the UI below.
	menu.esc_shade = ColorRect.new()
	menu.esc_shade.color = Color(0, 0, 0, 0.45)
	menu.esc_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.esc_shade.visible = false
	menu.ui.add_child(menu.esc_shade)
	menu.ui.move_child(menu.esc_shade, menu.esc_menu.get_index())

## Shows one of the Esc-menu panels (Menu / Settings / Wipe Save) on top of the
## dim backdrop. The backdrop is always raised first, so the open panel can never
## end up underneath it (that left Settings grayed out and unclickable).
func _show_overlay(panel: Control) -> void:
	for p in [menu.esc_menu, menu.settings_panel, menu.wipe_panel]:
		p.visible = p == panel
	menu.esc_shade.visible = true
	menu.esc_shade.move_to_front()
	panel.move_to_front()

func _hide_esc() -> void:
	menu.esc_menu.visible = false
	menu.settings_panel.visible = false
	menu.wipe_panel.visible = false
	menu.esc_shade.visible = false

func _open_wipe() -> void:
	_show_overlay(menu.wipe_panel)

func _back_from_wipe() -> void:
	_show_overlay(menu.esc_menu)

func _open_settings() -> void:
	_show_overlay(menu.settings_panel)

func _back_from_settings() -> void:
	_show_overlay(menu.esc_menu)

func _toggle_esc_menu() -> void:
	if menu.esc_menu.visible or menu.settings_panel.visible or menu.wipe_panel.visible:
		_hide_esc()
	else:
		_show_overlay(menu.esc_menu)

