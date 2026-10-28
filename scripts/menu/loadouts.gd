extends "res://scripts/menu/menu_part.gd"
class_name LoadoutsPart

# Loadouts (rules: PlayerData "Loadouts"): the "Loadouts" button on the Abilities &
# Talents page opens a panel to save, rename, overwrite, delete and apply them;
# the lobby has a quick-swap dropdown under your name. Only in the main menu.

var _panel: PanelContainer
var _rows: VBoxContainer
var _picker: OptionButton

func _pd() -> Node:
	return menu.get_node("/root/PlayerData")

## The button for the Abilities & Talents header.
func header_button() -> Button:
	var b := UI.button("Loadouts", 11, Vector2(76, 22))
	b.tooltip_text = "Save and switch talents, action bars, attribute points and Pact"
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(toggle)
	return b

## The lobby's quick swap.
func lobby_picker() -> OptionButton:
	_picker = OptionButton.new()
	_picker.focus_mode = Control.FOCUS_NONE
	_picker.add_theme_font_size_override("font_size", 13)
	_picker.tooltip_text = "Switch loadout (save them in Abilities & Talents → Loadouts)"
	_picker.item_selected.connect(func(i: int):
		var index := _picker.get_item_id(i)
		if index >= 0:
			apply(index)
		_refresh_picker())
	_pd().changed_late.connect(_refresh_picker)
	_refresh_picker.call_deferred()
	return _picker

func _refresh_picker() -> void:
	if _picker == null:
		return
	_picker.clear()
	var louts: Array = _pd().loadouts
	_picker.visible = not louts.is_empty()
	_picker.add_item("Loadout…", -1)
	for i in louts.size():
		_picker.add_item(str(louts[i].get("name", "?")), i)
	_picker.select(0)

func toggle() -> void:
	if _panel == null:
		_build_panel()
	_panel.visible = not _panel.visible
	if _panel.visible:
		_rebuild()
		_panel.move_to_front()

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -470
	_panel.offset_right = -24
	_panel.offset_top = 76
	_panel.add_theme_stylebox_override("panel", menu._padded(UI.box(Color(0.06, 0.065, 0.09, 0.98), MainMenu.C_BORDER, 2, 10), 12))
	_panel.visible = false
	menu.ui.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := UI.label("Loadouts", 17, MainMenu.C_ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := UI.button("✕", 13, Vector2(28, 26))
	close.pressed.connect(toggle)
	head.add_child(close)
	var hint := UI.label("Talents, action bars, attribute points and Pact. Click a name to rename it.", 12, MainMenu.C_TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	v.add_child(_rows)
	_pd().changed_late.connect(_refresh_if_shown.bind(_panel, _rebuild))

func _rebuild() -> void:
	for c in _rows.get_children():
		c.queue_free()
	var pd := _pd()
	for i in pd.loadouts.size():
		_rows.add_child(_row(i, pd.loadouts[i]))
	if pd.loadouts.is_empty():
		_rows.add_child(UI.label("No loadouts yet.", 13, MainMenu.C_TEXT_DIM))
	var save := UI.button("Save current as new", 13, Vector2(0, 30))
	save.disabled = pd.loadouts.size() >= pd.MAX_LOADOUTS
	save.tooltip_text = "Up to %d loadouts" % pd.MAX_LOADOUTS
	save.pressed.connect(func():
		menu._toast_if(_pd().save_loadout("")))
	_rows.add_child(save)

func _row(i: int, l: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var name_edit := LineEdit.new()
	name_edit.text = str(l.get("name", "?"))
	name_edit.max_length = 24
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.add_theme_font_size_override("font_size", 13)
	name_edit.text_submitted.connect(func(t: String):
		_pd().rename_loadout(i, t)
		name_edit.release_focus())
	name_edit.focus_exited.connect(func(): _pd().rename_loadout(i, name_edit.text))
	row.add_child(name_edit)
	var spent := 0
	for id in l.get("talents", {}):
		spent += int(l["talents"][id])
	var pts := UI.label("%d pts" % spent, 12, MainMenu.C_TEXT_DIM)
	pts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pts)
	var use := UI.button("Use", 13, Vector2(52, 28))
	use.pressed.connect(apply.bind(i))
	row.add_child(use)
	var over := UI.button("Save", 13, Vector2(52, 28))
	over.tooltip_text = "Save your current setup over this loadout"
	over.pressed.connect(func():
		menu._toast_if(_pd().save_loadout(str(_pd().loadouts[i]["name"]), i))
		menu._toast_ok("Saved over %s." % str(_pd().loadouts[i]["name"])))
	row.add_child(over)
	var del := UI.button("✕", 13, Vector2(30, 28))
	del.tooltip_text = "Delete this loadout"
	del.pressed.connect(_pd().delete_loadout.bind(i))
	row.add_child(del)
	return row

## Switch to loadout `index`, with a note about anything left out.
func apply(index: int) -> void:
	var pd := _pd()
	var res: Dictionary = pd.apply_loadout(index)
	if res.has("error"):
		menu._toast_if(str(res["error"]))
		return
	var lname := str(pd.loadouts[index].get("name", "?"))
	var notes: Array = res.get("notes", [])
	if notes.is_empty():
		menu._toast_ok("Switched to %s." % lname)
	else:
		menu._toast_if("Switched to %s, without: %s." % [lname, ", ".join(notes)])
