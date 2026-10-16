extends "res://scripts/menu/menu_part.gd"
class_name PactsPage

# Pacts: the tab above Rune Spells, and the page it opens. One Pact at a time
# (scripts/pacts.gd; PlayerData.pact). It can only be changed here, so once a
# dungeon starts it is locked in.

## The two tabs above the books (Pacts, Rune Spells) and the gap between them:
## 28 + 4 + 28 = the 60 px the Rune Spells tab had alone.
const SHELF_TAB_HEIGHT := 28
const SHELF_TAB_GAP := 4
const PACT_HINT := "You hold one Pact. It is locked in when you enter a dungeon. Break its vow and the bonus turns against you until that dungeon ends; the drawback stays."
const PACT_LINES := [["Bonus", "bonus", Color(0.55, 0.9, 0.55)], ["Drawback", "drawback", Color(1.0, 0.7, 0.4)],
	["Never", "vow", Color(1.0, 0.88, 0.5)], ["If broken", "broken", Color(1.0, 0.5, 0.5)]]
var _pact_tab_info: Label
var _pacts_page: PanelContainer
var _pact_list: GridContainer

## Two linked rings: a deal.
func _draw_pact_emblem(c: Control) -> void:
	var mid := c.size / 2.0
	var k: float = minf(c.size.x, c.size.y) / 64.0
	var col := Pacts.COLOR
	c.draw_arc(mid + Vector2(-9, 0) * k, 15.0 * k, 0, TAU, 24, col.lightened(0.45), 5.0 * k, true)
	c.draw_arc(mid + Vector2(9, 0) * k, 15.0 * k, 0, TAU, 24, col, 5.0 * k, true)

func _shelf_pact_tab() -> Button:
	var col := Pacts.COLOR
	var cover := col.darkened(0.8)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, SHELF_TAB_HEIGHT)
	b.tooltip_text = "Pacts\nA deal for one dungeon: a bonus, a drawback and a vow you must not break."
	b.add_theme_stylebox_override("normal", menu._box(cover, col.darkened(0.25), 0, 8, [2, 2, 2, 3]))
	b.add_theme_stylebox_override("hover", menu._box(cover.lightened(0.06), col, 0, 8, [3, 3, 3, 3]))
	b.add_theme_stylebox_override("pressed", menu._box(cover.lightened(0.1), col.lightened(0.2), 0, 8, [3, 3, 3, 3]))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(_open_pacts)
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
	emblem.draw.connect(func(): _draw_pact_emblem(emblem))
	row.add_child(emblem)
	var name_l := menu._label("Pacts", 15, col.lightened(0.35))
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_l)
	var desc := menu._label("A deal for one dungeon: a bonus, a drawback and a vow you must not break.", 12, MainMenu.C_TEXT_DIM)
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	desc.clip_text = true
	row.add_child(desc)
	_pact_tab_info = menu._label("", 12, MainMenu.C_TEXT_DIM)
	_pact_tab_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_pact_tab_info)
	return b

func _build_pacts_page() -> PanelContainer:
	var page := PanelContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_theme_stylebox_override("panel", menu._padded(UI.box(Pacts.COLOR.darkened(0.85), Pacts.COLOR.darkened(0.25), 3, 12), 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	page.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var back := UI.button("◀  Books", 13, Vector2(88, 28))
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_close_pacts)
	head.add_child(back)
	var title := menu._label("Pacts", 22, Pacts.COLOR.lightened(0.35))
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	var hint := menu._label(PACT_HINT, 12, MainMenu.INK_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_pact_list = GridContainer.new()
	_pact_list.columns = 2
	_pact_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pact_list.add_theme_constant_override("h_separation", 10)
	_pact_list.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_pact_list)
	return page

func _open_pacts() -> void:
	menu.shelf._shelf.visible = false
	_pacts_page.visible = true
	_refresh_pacts()

func _close_pacts() -> void:
	_pacts_page.visible = false
	menu.shelf._shelf.visible = true

## The tab's summary, and (while the page is open) one card for each Pact.
func _refresh_pacts() -> void:
	var pd := menu.get_node("/root/PlayerData")
	var held: bool = Pacts.exists(str(pd.pact))
	if _pact_tab_info:
		_pact_tab_info.text = Pacts.title(str(pd.pact), str(pd.pact_book)) if held else "None taken"
		_pact_tab_info.add_theme_color_override("font_color", Pacts.COLOR.lightened(0.4) if held else MainMenu.C_TEXT_DIM)
	if _pacts_page == null or not _pacts_page.visible:
		return
	for c in _pact_list.get_children():
		c.queue_free()
	for id in Pacts.ORDER:
		_pact_list.add_child(_pact_card(pd, str(id)))

func _pact_card(pd: Node, id: String) -> PanelContainer:
	var held: bool = str(pd.pact) == id
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", menu._padded(UI.box(MainMenu.PAGE_BG, Pacts.COLOR if held else MainMenu.PAGE_BORDER, 2 if held else 1, 6), 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	var name_l := menu._label(Pacts.title(id, str(pd.pact_book)) if held else Pacts.pact_name(id), 17, Pacts.COLOR.lightened(0.4) if held else MainMenu.INK)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(name_l)
	if Pacts.party_only(id):
		var tag := menu._label("Party only", 11, MainMenu.INK_DIM)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_STOP
		tag.tooltip_text = "It does nothing while you are alone in a dungeon: no bonus, no drawback, no vow."
		top.add_child(tag)
	if held:
		var drop := UI.button("Give up", 12, Vector2(74, 24))
		drop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		drop.pressed.connect(func(): _take_pact("", ""))
		top.add_child(drop)
	elif not Pacts.needs_book(id):
		var take := UI.button("Take", 12, Vector2(74, 24))
		take.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		take.pressed.connect(func(): _take_pact(id, ""))
		top.add_child(take)
	for line in PACT_LINES:
		v.add_child(_pact_line(str(line[0]), Pacts.text(id, str(line[1])), line[2]))
	if Pacts.needs_book(id):
		# The Purist is taken by choosing its book.
		var books := HBoxContainer.new()
		books.add_theme_constant_override("separation", 4)
		v.add_child(books)
		var ask := menu._label("Its book", 12, MainMenu.INK_DIM)
		ask.custom_minimum_size = Vector2(66, 0)
		ask.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		books.add_child(ask)
		for cat in Categories.ORDER:
			var c: String = cat
			var col := Categories.color(c)
			var on: bool = held and str(pd.pact_book) == c
			var bb := Button.new()
			bb.focus_mode = Control.FOCUS_NONE
			bb.custom_minimum_size = Vector2(28, 28)
			bb.tooltip_text = "Take this Pact for the %s book" % Categories.cat_name(c)
			bb.add_theme_stylebox_override("normal", UI.box(col.darkened(0.7) if on else Color(0, 0, 0, 0.35), col if on else col.darkened(0.45), 2 if on else 1, 5))
			bb.add_theme_stylebox_override("hover", UI.box(col.darkened(0.6), col, 2, 5))
			bb.add_theme_stylebox_override("pressed", UI.box(col.darkened(0.6), col, 2, 5))
			bb.pressed.connect(func(): _take_pact(id, c))
			var em := Control.new()
			em.set_anchors_preset(Control.PRESET_FULL_RECT)
			em.offset_left = 3
			em.offset_top = 3
			em.offset_right = -3
			em.offset_bottom = -3
			em.mouse_filter = Control.MOUSE_FILTER_IGNORE
			em.draw.connect(func(): Categories.draw_emblem(em, c))
			bb.add_child(em)
			books.add_child(bb)
	return card

## One line of a Pact's card: what it is ("Bonus") and what it says.
func _pact_line(what: String, text: String, col: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var k := menu._label(what, 12, col)
	k.custom_minimum_size = Vector2(66, 0)
	row.add_child(k)
	var t := menu._label(text, 12, MainMenu.INK)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	return row

func _take_pact(id: String, book: String) -> void:
	menu._toast_if(menu.get_node("/root/PlayerData").set_pact(id, book))   # (its `changed` redraws the page)

