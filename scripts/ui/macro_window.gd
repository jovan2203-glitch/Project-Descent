extends Control

# Macros window (Esc menu > Macros, in game and in the main menu).
#   Left:  your macros. In game, drag one onto an action-bar slot.
#   Right: the selected macro: icon, name, the ability it is linked to (the
#          button then shows that ability's cooldown and tooltip) and its text.
# What a macro can say is described in scripts/core/macros.gd.
# Usage: const MacroWindow = preload("res://scripts/ui/macro_window.gd")
#        MacroWindow.open(host, in_game)

const UI = preload("res://scripts/ui_kit.gd")
const Macros = preload("res://scripts/core/macros.gd")
const Abilities = preload("res://scripts/abilities.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")

const RED := Color(1.0, 0.45, 0.4)
const GREEN := Color(0.55, 1.0, 0.55)
const HELP := "One command per line. Every line runs each time you press the button.\n" \
	+ "/cast Ability Name   uses that ability (\"Trinket 1\" and \"Trinket 2\" use your trinkets)\n" \
	+ "/castsequence A, B, C   each press uses the next one   (reset=6 starts over after 6 sec)\n" \
	+ "Abilities that skip the global cooldown (trinkets, interrupts) all go off together. Of the rest, the first one that can be used is."
const EXAMPLE := "/cast Trinket 1\n/cast Vent Flames"

## True in a dungeon: no dark backdrop, so the action bars stay reachable for
## dragging a macro onto them.
var in_game := false

var _selected := -1          # uid of the macro being edited (-1 = none)
var _dirty := false          # the editor holds changes that are not saved yet
var _list: VBoxContainer
var _editor: VBoxContainer
var _empty_note: Label
var _name_edit: LineEdit
var _icon_btn: Button
var _icon_key := ""
var _link_opt: OptionButton
var _link_ids: Array[String] = []
var _text_edit: TextEdit
var _problems: Label
var _picker: PanelContainer
var _count_l: Label

## In game the window gets a layer of its own, above the HUD, the chat and the
## damage meter (they would cover parts of it otherwise).
const GAME_LAYER := 60
var _own_layer: CanvasLayer

static func open(host: Node, game: bool = false) -> Control:
	var w: Control = load("res://scripts/ui/macro_window.gd").new()
	w.in_game = game
	if game:
		var layer := CanvasLayer.new()
		layer.layer = GAME_LAYER
		host.add_child(layer)
		layer.add_child(w)
		w._own_layer = layer
	else:
		host.add_child(w)
	return w

func _pd() -> Node:
	return get_node("/root/PlayerData")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE if in_game else Control.MOUSE_FILTER_STOP
	if not in_game:
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, 0.6)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(shade)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -390
	panel.offset_right = 390
	if in_game:
		# At the top of the screen, clear of the action bars you drag macros onto.
		panel.offset_top = 16
		panel.offset_bottom = 16 + 462
	else:
		panel.anchor_top = 0.5
		panel.anchor_bottom = 0.5
		panel.offset_top = -250
		panel.offset_bottom = 250
	var sb := UI.box(UI.PANEL_BG, UI.BORDER, 2, 10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	var title := UI.label("Macros", 22, UI.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := UI.button("X", 16, Vector2(34, 34))
	close.pressed.connect(close_window)
	head.add_child(close)
	v.add_child(head)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	v.add_child(body)
	body.add_child(_build_left())
	body.add_child(_build_right())
	_refresh_list()
	_show_editor()

func close_window() -> void:
	_save()
	if _own_layer:
		_own_layer.queue_free()
	else:
		queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _picker and _picker.visible:
			_picker.visible = false
		else:
			close_window()

# --- Left: the list -------------------------------------------------------------------------

func _build_left() -> Control:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(220, 0)
	v.add_theme_constant_override("separation", 6)
	var add := UI.button("+ New macro", 15, Vector2(0, 34))
	add.pressed.connect(_new_macro)
	v.add_child(add)
	_count_l = UI.label("", 12, UI.TEXT_DIM)
	v.add_child(_count_l)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	var hint := UI.label("Drag a macro onto an action-bar slot to use it." if in_game \
		else "Macros go on your action bar in a dungeon: open Esc > Macros there and drag one onto a slot.", 12, UI.TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(210, 0)
	v.add_child(hint)
	return v

func _refresh_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var pd := _pd()
	_count_l.text = "%d of %d macros" % [pd.macros.size(), Macros.MAX_MACROS]
	for m in pd.macros:
		_list.add_child(_macro_row(m))

func _macro_row(m: Dictionary) -> Button:
	var uid := int(m["uid"])
	var id := Macros.bar_id(uid)
	var on := uid == _selected
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_stylebox_override("normal", UI.box(Color(1, 0.82, 0.3, 0.1) if on else Color(0, 0, 0, 0.3),
		UI.ACCENT if on else UI.BORDER, 2 if on else 1, 6))
	b.add_theme_stylebox_override("hover", UI.box(Color(1, 1, 1, 0.06), UI.ACCENT, 1, 6))
	b.add_theme_stylebox_override("pressed", UI.box(Color(1, 1, 1, 0.1), UI.ACCENT, 2, 6))
	b.pressed.connect(func(): _select(uid))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 5
	row.offset_right = -5
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func(): Macros.draw_icon(icon, id))
	row.add_child(icon)
	var n := UI.label(str(m.get("name", "")), 14, Color.WHITE)
	n.clip_text = true
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(n)
	b.set_meta("tip_ability", id)
	# In game: drag it onto an action-bar slot (the bar takes "ability" drops).
	b.set_drag_forwarding(
		func(_pos):
			if not in_game:
				return null
			_save()
			var preview := Control.new()
			var pic := Control.new()
			pic.size = Vector2(44, 44)
			pic.position = -pic.size / 2.0
			pic.modulate.a = 0.85
			pic.draw.connect(func(): Macros.draw_icon(pic, id))
			preview.add_child(pic)
			b.set_drag_preview(preview)
			return {"type": "ability", "id": id, "from": -1},
		func(_pos, _data): return false,
		func(_pos, _data): pass)
	return b

func _new_macro() -> void:
	_save()
	var uid: int = _pd().add_macro()
	if uid < 0:
		_problems_text("You already have %d macros (the most there can be)." % Macros.MAX_MACROS, RED)
		return
	_selected = uid
	_refresh_list()
	_show_editor()
	_name_edit.grab_focus()
	_name_edit.select_all()

func _select(uid: int) -> void:
	_save()
	_selected = uid
	_refresh_list()
	_show_editor()

# --- Right: the editor ---------------------------------------------------------------------

func _build_right() -> Control:
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_empty_note = UI.label("Pick a macro on the left, or make a new one.\n\nA macro is a button you write yourself: it can use several things with one press (a trinket and a spell), or step through a list of abilities.", 14, UI.TEXT_DIM)
	_empty_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	holder.add_child(_empty_note)
	_editor = VBoxContainer.new()
	_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor.add_theme_constant_override("separation", 8)
	holder.add_child(_editor)

	# Icon + name.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	_editor.add_child(top)
	_icon_btn = Button.new()
	_icon_btn.focus_mode = Control.FOCUS_NONE
	_icon_btn.custom_minimum_size = Vector2(52, 52)
	_icon_btn.tooltip_text = "Click to choose an icon"
	_icon_btn.add_theme_stylebox_override("normal", UI.box(Color(0.06, 0.065, 0.085, 0.9), UI.BORDER, 2, 6))
	_icon_btn.add_theme_stylebox_override("hover", UI.box(Color(0.1, 0.1, 0.13, 0.95), UI.ACCENT, 2, 6))
	_icon_btn.pressed.connect(_toggle_picker)
	var pic := Control.new()
	pic.name = "Pic"
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.draw.connect(func(): Macros.draw_icon_key(pic, _shown_icon()))
	_icon_btn.add_child(pic)
	top.add_child(_icon_btn)
	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_theme_constant_override("separation", 2)
	top.add_child(name_col)
	name_col.add_child(UI.label("Name", 12, UI.TEXT_DIM))
	_name_edit = LineEdit.new()
	_name_edit.max_length = Macros.MAX_NAME
	_name_edit.custom_minimum_size = Vector2(0, 30)
	_name_edit.text_changed.connect(func(_t): _dirty = true)
	_name_edit.text_submitted.connect(func(_t): _save())
	name_col.add_child(_name_edit)

	# Linked ability (first, above the text: it decides what the button shows).
	var link_row := HBoxContainer.new()
	link_row.add_theme_constant_override("separation", 8)
	_editor.add_child(link_row)
	var link_l := UI.label("Linked ability", 14, Color.WHITE)
	link_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	link_row.add_child(link_l)
	_link_opt = OptionButton.new()
	_link_opt.focus_mode = Control.FOCUS_NONE
	_link_opt.custom_minimum_size = Vector2(220, 30)
	_link_opt.fit_to_longest_item = false
	_link_opt.add_item("None")
	_link_ids = [""]
	var ids: Array = Abilities.ALL.duplicate()
	ids.sort_custom(func(a, b): return Abilities.ability_name(str(a)) < Abilities.ability_name(str(b)))
	for id in ids:
		_link_opt.add_item(Abilities.ability_name(str(id)))
		_link_ids.append(str(id))
	_link_opt.get_popup().max_size = Vector2i(320, 420)
	_link_opt.item_selected.connect(func(_i):
		_dirty = true
		_icon_btn.get_node("Pic").queue_redraw())
	link_row.add_child(_link_opt)
	var link_hint := UI.label("The button shows this ability's cooldown, charges and tooltip.", 12, UI.TEXT_DIM)
	link_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	link_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	link_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	link_row.add_child(link_hint)

	# The text.
	_text_edit = TextEdit.new()
	_text_edit.custom_minimum_size = Vector2(0, 110 if in_game else 150)
	_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_edit.placeholder_text = EXAMPLE
	_text_edit.add_theme_font_size_override("font_size", 15)
	_text_edit.text_changed.connect(func():
		_dirty = true
		_check_text())
	_editor.add_child(_text_edit)
	_problems = UI.label("", 13, GREEN)
	_problems.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_editor.add_child(_problems)
	var help := UI.label(HELP, 12, UI.TEXT_DIM)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_editor.add_child(help)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	_editor.add_child(btns)
	var save := UI.button("Save", 15, Vector2(110, 34))
	save.pressed.connect(func():
		_dirty = true
		_save()
		if (Macros.parse(_text_edit.text)["problems"] as Array).is_empty():
			_problems_text("Saved.", GREEN)
		else:
			_check_text())
	btns.add_child(save)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns.add_child(gap)
	var del := UI.button("Delete", 15, Vector2(110, 34))
	del.add_theme_color_override("font_color", RED)
	del.pressed.connect(_delete)
	btns.add_child(del)

	# Icon picker (over the editor while open).
	_picker = _build_picker()
	_picker.visible = false
	add_child(_picker)
	return holder

func _shown_icon() -> String:
	if _icon_key != "":
		return _icon_key
	var link: String = _link_ids[_link_opt.selected] if _link_opt and _link_opt.selected >= 0 else ""
	return ("a:" + link) if link != "" else ""

func _show_editor() -> void:
	var m: Dictionary = _pd().macro_by_uid(_selected) if _selected >= 0 else {}
	_editor.visible = not m.is_empty()
	_empty_note.visible = m.is_empty()
	if _picker:
		_picker.visible = false
	if m.is_empty():
		return
	_name_edit.text = str(m.get("name", ""))
	_icon_key = str(m.get("icon", ""))
	_link_opt.select(maxi(_link_ids.find(str(m.get("link", ""))), 0))
	_text_edit.text = str(m.get("text", ""))
	_icon_btn.get_node("Pic").queue_redraw()
	_dirty = false
	_check_text()

## Say what the text can't do (unknown ability names...), or that it is fine.
func _check_text() -> void:
	var parsed := Macros.parse(_text_edit.text)
	var problems: Array = parsed["problems"]
	if not problems.is_empty():
		_problems_text("\n".join(problems), RED)
	elif (parsed["steps"] as Array).is_empty():
		_problems_text("Empty: write a command, for example  /cast Frost Bolt", UI.TEXT_DIM)
	else:
		_problems_text("Looks good.", GREEN)

func _problems_text(text: String, col: Color) -> void:
	_problems.text = text
	_problems.add_theme_color_override("font_color", col)

## Write the editor's fields into the macro (if something changed).
func _save() -> void:
	if not _dirty or _selected < 0 or _pd().macro_by_uid(_selected).is_empty():
		return
	_dirty = false
	_pd().update_macro(_selected, {"name": _name_edit.text, "icon": _icon_key,
		"link": _link_ids[maxi(_link_opt.selected, 0)], "text": _text_edit.text})
	_refresh_list()

func _delete() -> void:
	if _selected < 0:
		return
	var uid := _selected
	_selected = -1
	_dirty = false
	_pd().delete_macro(uid)
	_refresh_list()
	_show_editor()

# --- Icon picker: every ability and talent icon in the game ------------------------------------

func _toggle_picker() -> void:
	_picker.visible = not _picker.visible
	if _picker.visible:
		_picker.move_to_front()

func _build_picker() -> PanelContainer:
	var p := PanelContainer.new()
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -150
	p.offset_right = 380
	if in_game:
		p.anchor_top = 0.0
		p.anchor_bottom = 0.0
		p.offset_top = 126
		p.offset_bottom = 470
	else:
		p.offset_top = -140
		p.offset_bottom = 240
	var sb := UI.box(Color(0.03, 0.035, 0.05, 0.98), UI.ACCENT, 2, 8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var head := HBoxContainer.new()
	var t := UI.label("Choose an icon", 16, UI.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var auto := UI.button("Use the linked ability's", 12, Vector2(0, 26))
	auto.tooltip_text = "No icon of its own: the macro shows the icon of the ability it is linked to."
	auto.pressed.connect(func(): _pick_icon(""))
	head.add_child(auto)
	v.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 11
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	var keys: Array[String] = []
	for id in Abilities.ALL:
		keys.append("a:" + str(id))
	for id in Talents.db():
		if TalentIcons.has_icon(str(id)):
			keys.append("t:" + str(id))
	for key in keys:
		var k: String = key
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(42, 42)
		b.add_theme_stylebox_override("normal", UI.box(Color(0.06, 0.065, 0.085, 0.9), UI.BORDER, 1, 5))
		b.add_theme_stylebox_override("hover", UI.box(Color(0.1, 0.1, 0.13, 0.95), UI.ACCENT, 2, 5))
		b.tooltip_text = Abilities.ability_name(k.substr(2)) if k.begins_with("a:") else str(Talents.get_talent(k.substr(2)).get("name", ""))
		b.pressed.connect(func(): _pick_icon(k))
		var pic := Control.new()
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pic.draw.connect(func(): Macros.draw_icon_key(pic, k))
		b.add_child(pic)
		grid.add_child(b)
	return p

func _pick_icon(key: String) -> void:
	_icon_key = key
	_dirty = true
	_picker.visible = false
	_icon_btn.get_node("Pic").queue_redraw()
	_save()
