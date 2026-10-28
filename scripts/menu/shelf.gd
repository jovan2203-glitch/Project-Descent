extends "res://scripts/menu/menu_part.gd"
class_name ShelfPage

# The Abilities & Talents page. Top: the action bar (drag abilities onto it, drag
# them off to remove). Below: a shelf of books, one per category, plus the Pacts and
# Rune Spells tabs. Opening a book shows its abilities and talent tree (open_book.gd,
# talent_tree.gd). Talent rows unlock globally: 3 points in a row of ANY tree opens
# the next row in EVERY tree, so trees can be mixed freely.

var _shelf: PanelContainer
var _shelf_info := {}          # category -> Label (abilities / points summary)
## Highlight the open book's button in the quick switcher.
func _refresh_book_tabs() -> void:
	for c in menu.open_book._book_tab_buttons:
		var b: Button = menu.open_book._book_tab_buttons[c]
		var col := Categories.color(c)
		var on: bool = c == menu.open_book._book_cat
		b.add_theme_stylebox_override("normal", UI.box(col.darkened(0.7) if on else UI.BG, col if on else col.darkened(0.45), 2 if on else 1, 6))
		b.add_theme_stylebox_override("hover", UI.box(col.darkened(0.6), col, 2, 6))
var _shelf_browse: Array[Control] = []   # the shelf's books (hidden while results show)
var _shelf_hint: Label
const SHELF_HINT := "Open a book to see its abilities and talents  •  3 talent points in a row of any book unlock the next row in every book"
func _build_abilities_page() -> Control:
	var page := menu._full_rect_page()
	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 24
	outer.offset_right = -24
	outer.offset_top = 46
	outer.offset_bottom = -8
	outer.add_theme_constant_override("separation", 4)
	page.add_child(outer)

	# Header: talent points + reset, and (while a book is open) the book switcher.
	# No action bar here: learned abilities go on the bar in game (Spellbook, P).
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	outer.add_child(head)
	# A spacer as wide as the points/reset group on the right, so the book icons
	# sit in the true middle of the screen.
	# (It also holds the search bar: wide on the shelf, compact beside the book icons.)
	var mirror := HBoxContainer.new()
	mirror.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(mirror)
	menu.book_search._search_edit = LineEdit.new()
	menu.book_search._search_edit.placeholder_text = "Search abilities and talents  (name or keyword, e.g. chill)"
	menu.book_search._search_edit.clear_button_enabled = true
	menu.book_search._search_edit.custom_minimum_size = Vector2(460, 26)
	menu.book_search._search_edit.add_theme_font_size_override("font_size", 13)
	menu.book_search._search_edit.add_theme_stylebox_override("normal", menu._padded(UI.box(Color(0, 0, 0, 0.4), MainMenu.C_BORDER, 1, 6), 8))
	menu.book_search._search_edit.add_theme_stylebox_override("focus", menu._padded(UI.box(Color(0, 0, 0, 0.5), MainMenu.C_ACCENT, 1, 6), 8))
	menu.book_search._search_edit.text_changed.connect(menu.book_search._on_search_changed)
	menu.book_search._search_edit.text_submitted.connect(func(_t): menu.book_search._search_edit.release_focus())
	mirror.add_child(menu.book_search._search_edit)
	menu.open_book._book_tabs = HFlowContainer.new()
	menu.open_book._book_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.open_book._book_tabs.alignment = FlowContainer.ALIGNMENT_CENTER
	menu.open_book._book_tabs.add_theme_constant_override("h_separation", 3)
	menu.open_book._book_tabs.add_theme_constant_override("v_separation", 3)
	menu.open_book._book_tabs.visible = false
	head.add_child(menu.open_book._book_tabs)
	for cat in [Categories.RUNE] + Categories.ORDER:   # Rune Spells first, then the books
		var c: String = cat
		var tb := Button.new()   # the book's element emblem; name in the tooltip
		tb.focus_mode = Control.FOCUS_NONE
		tb.custom_minimum_size = Vector2(28, 28)
		tb.tooltip_text = Categories.cat_name(c)
		tb.pressed.connect(func(): menu.open_book._open_book(c))
		var em := Control.new()
		em.set_anchors_preset(Control.PRESET_FULL_RECT)
		em.offset_left = 3
		em.offset_top = 3
		em.offset_right = -3
		em.offset_bottom = -3
		em.mouse_filter = Control.MOUSE_FILTER_IGNORE
		em.draw.connect(func(): Categories.draw_emblem(em, c))
		tb.add_child(em)
		menu.open_book._book_tabs.add_child(tb)
		menu.open_book._book_tab_buttons[c] = tb
	var right_grp := HBoxContainer.new()
	right_grp.add_theme_constant_override("separation", 8)
	head.add_child(right_grp)
	# Shelf: the search bar takes the free space. Book open: it shrinks to the
	# width of the group on the right, so the book icons stay centred.
	var fit_search := func():
		var open: bool = menu.open_book._book_tabs.visible
		mirror.size_flags_horizontal = Control.SIZE_FILL if open else Control.SIZE_EXPAND_FILL
		mirror.custom_minimum_size.x = right_grp.size.x if open else 0.0
		menu.book_search._search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL if open else Control.SIZE_SHRINK_BEGIN
		menu.book_search._search_edit.custom_minimum_size.x = 0.0 if open else 460.0
		menu.book_search._search_edit.placeholder_text = "Search this book" if open \
			else "Search abilities and talents  (name or keyword, e.g. chill)"
	menu.open_book._book_tabs.visibility_changed.connect(fit_search)
	right_grp.resized.connect(fit_search)
	right_grp.add_child(menu.loadouts.header_button())
	menu._talent_points_label = UI.label("", 12, Color.WHITE)
	menu._talent_points_label.custom_minimum_size = Vector2(250, 0)   # fixed width: the icons never shift
	menu._talent_points_label.clip_text = true                         # (a Label grows with its text otherwise, and they would)
	menu._talent_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	menu._talent_points_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right_grp.add_child(menu._talent_points_label)
	var reset := UI.button("Reset", 11, Vector2(56, 22))
	reset.tooltip_text = "Reset all talents"
	reset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reset.pressed.connect(func(): menu.get_node("/root/PlayerData").reset_talents())
	right_grp.add_child(reset)

	# Shelf (category books) / open book
	var area := Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(area)
	_shelf = _build_shelf()
	area.add_child(_shelf)
	menu.open_book._book = menu.open_book._build_book()
	menu.open_book._book.visible = false
	area.add_child(menu.open_book._book)
	menu.pacts_page._pacts_page = menu.pacts_page._build_pacts_page()   # opened by the Pacts tab on the shelf
	menu.pacts_page._pacts_page.visible = false
	area.add_child(menu.pacts_page._pacts_page)

	var pd := menu.get_node("/root/PlayerData")
	pd.changed_late.connect(menu._refresh_abilities)
	menu._refresh_abilities.call_deferred()
	return page

## Dropping an ability dragged from the bar onto `c` removes it from the bar.
func _accept_bar_drop(c: Control) -> void:
	c.set_drag_forwarding(
		func(_pos): return null,
		func(_pos, data): return data is Dictionary and data.get("type") == "ability" and int(data["from"]) >= 0,
		func(_pos, data): menu.get_node("/root/PlayerData").clear_action_slot(int(data["from"])))

func _build_shelf() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", menu._padded(UI.box(Color(0.05, 0.055, 0.075, 0.96), MainMenu.C_BORDER, 2, 10), 12))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.add_child(UI.label("Spellbooks", 20, MainMenu.C_ACCENT))
	var hint := UI.label(SHELF_HINT, 12, MainMenu.C_TEXT_DIM)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hint)
	_shelf_hint = hint
	v.add_child(head)
	# Search results (shown instead of the books while something is typed).
	menu.book_search._search_results = ScrollContainer.new()
	menu.book_search._search_results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu.book_search._search_results.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.book_search._search_results.visible = false
	v.add_child(menu.book_search._search_results)
	menu.book_search._search_list = GridContainer.new()
	menu.book_search._search_list.columns = 3
	menu.book_search._search_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.book_search._search_list.add_theme_constant_override("h_separation", 8)
	menu.book_search._search_list.add_theme_constant_override("v_separation", 6)
	menu.book_search._search_results.add_child(menu.book_search._search_list)
	# Two slim tabs above the books: Pacts, then the spells taught by runes. Together
	# they are exactly as tall as the one Rune Spells tab used to be, so the books
	# did not move when Pacts were added.
	var rune_tab := VBoxContainer.new()
	rune_tab.add_theme_constant_override("separation", PactsPage.SHELF_TAB_GAP)
	rune_tab.add_child(menu.pacts_page._shelf_pact_tab())
	rune_tab.add_child(_shelf_rune_tab())
	v.add_child(rune_tab)
	var grid := GridContainer.new()
	grid.columns = Categories.shelf_columns(Categories.ORDER.size())   # two even rows of books
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for cat in Categories.ORDER:
		grid.add_child(_shelf_book(cat))
	_shelf_browse = [rune_tab, grid]
	return panel

## The unique tab above the books: spells taught by runes (Frostfire Bolt).
## It opens like a book, but with the runes that teach them instead of talents.
func _shelf_rune_tab() -> Button:
	var cat: String = Categories.RUNE
	var col := Categories.color(cat)
	var cover := col.darkened(0.8)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, PactsPage.SHELF_TAB_HEIGHT)   # (it shares the height it had with the Pacts tab: the books stay where they were)
	b.tooltip_text = "%s\n%s" % [Categories.cat_name(cat), Categories.desc(cat)]
	b.add_theme_stylebox_override("normal", menu._box(cover, col.darkened(0.25), 0, 8, [2, 2, 2, 3]))
	b.add_theme_stylebox_override("hover", menu._box(cover.lightened(0.06), col, 0, 8, [3, 3, 3, 3]))
	b.add_theme_stylebox_override("pressed", menu._box(cover.lightened(0.1), col.lightened(0.2), 0, 8, [3, 3, 3, 3]))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(menu.open_book._open_book.bind(cat))
	_accept_bar_drop(b)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.offset_top = 2
	row.offset_bottom = -3
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var emblem := Control.new()
	emblem.custom_minimum_size = Vector2(20, 20)
	emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.draw.connect(func(): Categories.draw_emblem(emblem, cat))
	row.add_child(emblem)
	var name_l := menu._label(Categories.cat_name(cat), 15, col.lightened(0.35))
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_l)
	var desc := menu._label(Categories.desc(cat), 12, MainMenu.C_TEXT_DIM)
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	desc.clip_text = true
	row.add_child(desc)
	var info := menu._label("", 12, MainMenu.C_TEXT_DIM)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)
	_shelf_info[cat] = info
	return b

func _shelf_book(cat: String) -> Button:
	var col := Categories.color(cat)
	var cover := col.darkened(0.78)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 130)
	b.tooltip_text = "%s\n%s" % [Categories.cat_name(cat), Categories.desc(cat)]
	b.add_theme_stylebox_override("normal", menu._box(cover, col.darkened(0.25), 0, 8, [12, 2, 2, 2]))
	b.add_theme_stylebox_override("hover", menu._box(cover.lightened(0.06), col, 0, 8, [12, 3, 3, 3]))
	b.add_theme_stylebox_override("pressed", menu._box(cover.lightened(0.1), col.lightened(0.2), 0, 8, [12, 3, 3, 3]))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(menu.open_book._open_book.bind(cat))
	_accept_bar_drop(b)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_right = -8
	v.offset_top = 8
	v.offset_bottom = -8
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var emblem := Control.new()
	emblem.custom_minimum_size = Vector2(56, 56)
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.draw.connect(func(): Categories.draw_emblem(emblem, cat))
	v.add_child(emblem)
	var name_l := menu._label(Categories.cat_name(cat), 20, col.lightened(0.35))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	var info := menu._label("", 12, MainMenu.C_TEXT_DIM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	_shelf_info[cat] = info
	return b
