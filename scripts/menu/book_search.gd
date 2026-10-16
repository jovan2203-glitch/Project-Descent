extends "res://scripts/menu/menu_part.gd"
class_name BookSearch

# Moved out of scripts/main_menu.gd as it was (menu = the menu node). Hooked up from
# main_menu.gd through its var "book_search".
# --- Part: Search --------
const SEARCH_COL := Color(0.4, 1.0, 0.6)      # matches the search
const FOCUS_COL := Color(1.0, 1.0, 1.0)       # the result you clicked
const SEARCH_MAX_RESULTS := 60
var _search_edit: LineEdit
var _search_query := ""
var _search_focus := ""         # entity key ("a:frostbolt", "t:frost_r1c3") picked from the results
var _search_results: ScrollContainer
var _search_list: GridContainer
var _hover_key := ""            # entity key under the mouse
func _on_search_changed(text: String) -> void:
	_search_query = text.strip_edges()
	_search_focus = ""
	_refresh_search()

func _clear_search() -> void:
	_search_edit.text = ""
	_on_search_changed("")

## Shelf: list what matches. Open book: highlight what matches.
func _refresh_search() -> void:
	if menu._book_cat != "":
		_update_marks()
		return
	var searching := _search_query != ""
	for c in menu._shelf_browse:
		c.visible = not searching
	_search_results.visible = searching
	for c in _search_list.get_children():
		c.queue_free()
	if not searching:
		menu._shelf_hint.text = MainMenu.SHELF_HINT
		return
	var keys: Array = Keywords.search(_search_query, "at")
	menu._shelf_hint.text = "%d %s for \"%s\"  •  click one to open its book with it highlighted" % [
		keys.size(), "result" if keys.size() == 1 else "results", _search_query]
	if keys.is_empty():
		_search_list.add_child(menu._label("Nothing matches \"%s\"." % _search_query, 14, MainMenu.C_TEXT_DIM))
		return
	var pd := menu.get_node("/root/PlayerData")
	for i in mini(keys.size(), SEARCH_MAX_RESULTS):
		_search_list.add_child(_search_result(pd, str(keys[i])))
	if keys.size() > SEARCH_MAX_RESULTS:
		_search_list.add_child(menu._label("…and %d more: type more to narrow it down." % (keys.size() - SEARCH_MAX_RESULTS), 12, MainMenu.C_TEXT_DIM))

## Book (category) an ability / talent key lives in.
func _key_category(key: String) -> String:
	return Abilities.category_of(key.substr(2)) if key.begins_with("a:") else Talents.category_of(key.substr(2))

## One search result: icon, name, what and where it is. Click = open its book
## with it highlighted.
func _search_result(pd: Node, key: String) -> Button:
	var id := key.substr(2)
	var is_ability := key.begins_with("a:")
	var cat := _key_category(key)
	var col := Categories.color(cat)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("normal", UI.box(Color(0, 0, 0, 0.3), col.darkened(0.4), 1, 6))
	b.add_theme_stylebox_override("hover", UI.box(Color(1, 1, 1, 0.06), col, 2, 6))
	b.add_theme_stylebox_override("pressed", UI.box(Color(1, 1, 1, 0.1), col, 2, 6))
	if is_ability:
		b.set_meta("tip_ability", id)
	else:
		b.tooltip_text = Talents.tooltip(id, pd.talent_rank(id))
	b.pressed.connect(func():
		_search_focus = key
		menu._open_book(cat))
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6
	row.offset_right = -6
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(34, 34)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_ability:
		icon.draw.connect(func(): Abilities.draw_icon(icon, id))
	elif TalentIcons.has_icon(id):
		icon.draw.connect(func(): TalentIcons.draw(icon, id))
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", -2)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var name_l := menu._label(Keywords.title(key), 14, Color.WHITE)
	name_l.clip_text = true
	text.add_child(name_l)
	var where := ""
	if is_ability:
		where = "Ability  •  %s%s" % [Categories.cat_name(cat), "" if pd.has_ability(id) else "  •  not learned"]
	else:
		where = "Talent  •  %s, row %d  •  %d/%d" % [Categories.cat_name(cat), Talents.tier_of(id) + 1,
			pd.talent_rank(id), Talents.max_rank(id)]
	var where_l := menu._label(where, 11, col.lightened(0.3))
	where_l.clip_text = true
	text.add_child(where_l)
	return b

## The highlight frame of an ability cell / talent button (hidden until needed).
func _add_mark(b: Control) -> void:
	var m := Panel.new()
	m.name = "Mark"
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.offset_left = -2
	m.offset_top = -2
	m.offset_right = 2
	m.offset_bottom = 2
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.visible = false
	b.add_child(m)

## Hovering `b` (the cell / button of entity `key`) highlights what is related to it.
func _wire_hover(b: Control, key: String) -> void:
	b.mouse_entered.connect(func():
		_hover_key = key
		_update_marks())
	b.mouse_exited.connect(func():
		if _hover_key == key:
			_hover_key = ""
			_update_marks())

## Frames and dimming in the open book: the clicked search result (white), what
## the hovered ability / talent is related to (orange), search matches (green).
## While a search is on, everything else is dimmed.
func _update_marks() -> void:
	var related: Array = Keywords.related(_hover_key) if _hover_key != "" else []
	var controls := {}
	for id in menu._ability_cells:
		controls["a:" + str(id)] = menu._ability_cells[id]
	for id in menu.talent_tree._talent_buttons:
		controls["t:" + str(id)] = menu.talent_tree._talent_buttons[id]
	for key in controls:
		var b: Control = controls[key]
		if not is_instance_valid(b):
			continue
		var m: Panel = b.get_node_or_null("Mark")
		if m == null:
			continue
		var matched: bool = _search_query != "" and Keywords.matches(str(key), _search_query)
		var col := Color.TRANSPARENT
		var width := 0
		if related.has(key):
			col = Keywords.COLOR
			width = 3
		elif str(key) == _search_focus:
			col = FOCUS_COL
			width = 3
		elif matched:
			col = SEARCH_COL
			width = 2
		m.visible = width > 0
		if width > 0:
			m.add_theme_stylebox_override("panel", UI.box(Color(col, 0.12), col, width, 7))
		var dim: bool = _search_query != "" and not matched and width == 0 and str(key) != _hover_key
		b.modulate = Color(1, 1, 1, 0.3) if dim else Color.WHITE

