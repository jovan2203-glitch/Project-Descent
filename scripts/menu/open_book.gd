extends "res://scripts/menu/menu_part.gd"
class_name OpenBook

# Moved out of scripts/main_menu.gd as it was (menu = the menu node). Hooked up from
# main_menu.gd through its var "open_book".
# --- Part: The open book: abilities (left page) + rune page --------
var _book: PanelContainer
var _book_cat := ""            # open book's category ("" = shelf showing)
var _book_emblem: Control
var _book_title: Label
var _book_sub: Label
var _book_abilities: VBoxContainer
var _book_tabs: HFlowContainer
var _book_tab_buttons := {}   # category -> its quick-switch button

var _ability_cells := {}        # ability id -> its cell in the open book
func _build_book() -> PanelContainer:
	var book := PanelContainer.new()
	book.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	book.add_child(v)

	# Top frame: [Books] Abilities + hint  |  emblem + book name (centered)  |  Talents + hint
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var left_head := HBoxContainer.new()
	left_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_head.add_theme_constant_override("separation", 10)
	head.add_child(left_head)
	var back := UI.button("◀  Books", 13, Vector2(88, 28))
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_close_book)
	left_head.add_child(back)
	_head_section(left_head, "Abilities", "Grayed out = not learned. Put learned abilities on your bar in game (Spellbook, P).")

	var mid := VBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.custom_minimum_size = Vector2(460, 0)   # fixed: changing text never reflows the header
	mid.add_theme_constant_override("separation", 0)
	head.add_child(mid)
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 8)
	mid.add_child(title_row)
	_book_emblem = Control.new()
	_book_emblem.custom_minimum_size = Vector2(26, 26)
	_book_emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_book_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_emblem.draw.connect(func(): Categories.draw_emblem(_book_emblem, _book_cat))
	title_row.add_child(_book_emblem)
	_book_title = menu._label("", 22, Color.WHITE)
	title_row.add_child(_book_title)
	_book_sub = menu._label("", 11, MainMenu.C_TEXT_DIM)
	_book_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_book_sub.clip_text = true
	_book_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mid.add_child(_book_sub)

	var right_head := HBoxContainer.new()
	right_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_head.add_theme_constant_override("separation", 10)
	head.add_child(right_head)
	_book_right_head = _head_section(right_head, "Talents", TALENT_HINT)

	var spread := HBoxContainer.new()   # the open book's two pages
	spread.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spread.add_theme_constant_override("separation", 0)
	v.add_child(spread)
	var left := _book_page(0.7)
	spread.add_child(left)
	var spine := ColorRect.new()
	spine.color = Color(0.05, 0.035, 0.02)
	spine.custom_minimum_size = Vector2(8, 0)
	spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spread.add_child(spine)
	var right := _book_page(1.0)
	spread.add_child(right)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_book_abilities = VBoxContainer.new()   # one divider + 2-column grid per spec
	_book_abilities.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_book_abilities.add_theme_constant_override("separation", 6)
	scroll.add_child(_book_abilities)
	# The talent grid scales itself to fill this page (no scrolling).
	menu.talent_tree._book_tree = Control.new()
	menu.talent_tree._book_tree.clip_contents = true
	menu.talent_tree._book_tree.mouse_filter = Control.MOUSE_FILTER_PASS
	menu.talent_tree._book_tree.resized.connect(menu.talent_tree._layout_talent_canvas)
	right.add_child(menu.talent_tree._book_tree)
	# Rune Spells have no talents: this page lists the runes that teach them instead.
	_rune_page = VBoxContainer.new()
	_rune_page.add_theme_constant_override("separation", 8)
	_rune_page.visible = false
	right.add_child(_rune_page)
	return book

const TALENT_HINT := "Left-click: invest  •  Right-click: refund  •  3 points in a row (any book) open the next row in every book  •  Maxing a talent opens the talents its lines point to"
const RUNE_HINT := "A rune spell is known while its rune is on your gear. Engrave runes in the Runes screen (Character page)."
var _book_right_head: Array = []   # [title Label, hint Label] over the right page
var _rune_page: VBoxContainer

## "Title  hint" for the book's top frame. Returns [title Label, hint Label].
func _head_section(parent: HBoxContainer, title: String, hint_text: String) -> Array:
	var t := menu._label(title, 18, MainMenu.INK)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(t)
	var hint := menu._label(hint_text, 11, MainMenu.INK_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(hint)
	return [t, hint]

## The Rune Spells book's right page: every rune that teaches a spell, and
## whether you have it on, know it, or haven't found it.
func _refresh_rune_page() -> void:
	for c in _rune_page.get_children():
		c.queue_free()
	var pd := menu.get_node("/root/PlayerData")
	var intro := menu._label("Rune spells are never drafted and have no talents of their own. You know one while its rune is on your gear, and it follows the talents, runes and procs of every school it belongs to.", 13, MainMenu.INK_DIM)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rune_page.add_child(intro)
	var worn: Array = pd.rune_spells()
	for rid in Runes.TEACHES:
		var rune_id: String = rid
		var spell := Runes.spell_of(rune_id)
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", menu._padded(UI.box(Color(0, 0, 0, 0.25), MainMenu.PAGE_BORDER, 1, 5), 8))
		row.tooltip_text = Runes.tooltip(rune_id)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(h)
		var glyph := Control.new()
		glyph.custom_minimum_size = Vector2(34, 34)
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.draw.connect(func(): Runes.draw_glyph(glyph, glyph.size / 2.0, 14.0, rune_id))
		h.add_child(glyph)
		var names := VBoxContainer.new()
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.add_theme_constant_override("separation", 0)
		names.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(names)
		names.add_child(menu._label("%s  (%s)" % [Runes.rune_name(rune_id), Runes.rarity_name(rune_id)], 15, Runes.rarity_color(rune_id)))
		names.add_child(menu._label("Teaches %s" % Abilities.ability_name(spell), 12, MainMenu.INK))
		var state := menu._label("Not found yet", 12, Color(0.8, 0.5, 0.45))
		if worn.has(spell):
			state.text = "On your gear"
			state.add_theme_color_override("font_color", Color(0.55, 0.9, 0.55))
		elif pd.known_runes.has(rune_id):
			state.text = "Known: not on your gear"
			state.add_theme_color_override("font_color", MainMenu.C_ACCENT)
		state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(state)
		_rune_page.add_child(row)

func _book_page(ratio: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = ratio
	p.add_theme_stylebox_override("panel", menu._padded(UI.box(MainMenu.PAGE_BG, MainMenu.PAGE_BORDER, 1, 4), 8))
	return p

func _open_book(cat: String) -> void:
	_book_cat = cat
	var col := Categories.color(cat)
	_book.add_theme_stylebox_override("panel", menu._padded(UI.box(col.darkened(0.8), col.darkened(0.2), 3, 12), 10))
	_book_title.text = Categories.cat_name(cat)
	_book_title.add_theme_color_override("font_color", col.lightened(0.35))
	_book_emblem.queue_redraw()
	var runes: bool = cat == Categories.RUNE
	menu.talent_tree._book_tree.visible = not runes
	_rune_page.visible = runes
	if _book_right_head.size() == 2:
		(_book_right_head[0] as Label).text = "Runes" if runes else "Talents"
		(_book_right_head[1] as Label).text = RUNE_HINT if runes else TALENT_HINT
	menu.talent_tree._build_talent_tree()
	menu._shelf.visible = false
	_book.visible = true
	_book_tabs.visible = true
	menu._refresh_book_tabs()
	menu._refresh_abilities()
	menu.book_search._update_marks()

func _close_book() -> void:
	_book_cat = ""
	menu.talent_tree._talent_buttons.clear()
	_ability_cells.clear()
	menu.book_search._hover_key = ""
	menu.book_search._search_focus = ""
	menu.talent_tree._row_status.clear()
	_book.visible = false
	_book_tabs.visible = false
	menu._shelf.visible = true
	menu.book_search._refresh_search()

func _refresh_book_abilities() -> void:
	for c in _book_abilities.get_children():
		c.queue_free()
	_ability_cells.clear()
	var specs := Abilities.specs_in(_book_cat)
	if specs.is_empty():
		_book_abilities.add_child(menu._label("No abilities in this book yet.", 14, MainMenu.INK_DIM))
		return
	var pd := menu.get_node("/root/PlayerData")
	var col := Categories.color(_book_cat).lightened(0.35)
	for spec in specs:
		if spec[0] != "":
			_book_abilities.add_child(UI.spec_divider(spec[0], col, 14))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		_book_abilities.add_child(grid)
		for id in spec[1]:
			var cell := _book_ability_cell(pd, id)
			grid.add_child(cell)
			_ability_cells[id] = cell
			menu.book_search._add_mark(cell)
			menu.book_search._wire_hover(cell, "a:" + id)
	menu.book_search._update_marks()

## One ability on the book's left page: icon + name (+ learned state). Learned
## ones are bright, unlearned ones dimmed with a red name. Hover for the tooltip.
## (No dragging here: the action bar is set up in game, Spellbook on P.)
func _book_ability_cell(pd: Node, id: String) -> Button:
	var learned: bool = pd.has_ability(id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 36)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("normal", UI.box(Color(0, 0, 0, 0.25), MainMenu.PAGE_BORDER, 1, 5))
	b.add_theme_stylebox_override("hover", UI.box(Color(1, 1, 1, 0.06), MainMenu.C_ACCENT, 1, 5))
	b.add_theme_stylebox_override("pressed", UI.box(Color(1, 1, 1, 0.06), MainMenu.C_ACCENT, 1, 5))
	b.set_meta("tip_ability", id)   # full ability tooltip on hover
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 5
	row.offset_right = -5
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func(): Abilities.draw_icon(icon, id))
	if not learned:
		icon.modulate = Color(0.5, 0.5, 0.5, 0.6)   # grayed out
	row.add_child(icon)
	var n := menu._label(Abilities.ability_name(id), 14, Color.WHITE if learned else Color(1.0, 0.45, 0.4))
	n.clip_text = true
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(n)
	return b
