extends VBoxContainer

# Talent trees in the in-game Spellbook (next to your abilities): pick a book
# with the emblem buttons and hover a talent to read it. Read only, except in the
# training area (`editable`, set by game_ui.gd): there left click spends a point
# and right click takes one back, as in the main menu.
# Usage: var v := TALENT_VIEW.new(); v.tree_height = 340.0; parent.add_child(v)

## A refused click (no points, row locked...): game_ui shows it as an error.
signal message(text: String)

const UI = preload("res://scripts/ui_kit.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const Categories = preload("res://scripts/categories.gd")
const RibbonDrawer = preload("res://scripts/ui/ribbon_drawer.gd")
const Keywords = preload("res://scripts/core/keywords.gd")
const SEARCH_COL := Color(0.4, 1.0, 0.6)   # a talent matching the search (as in the main menu's book)

const CELL_BG := Color(0.16, 0.14, 0.11, 0.95)
const CELL_BG_EMPTY := Color(0.08, 0.07, 0.06, 0.95)
const CELL_BORDER := Color(0.32, 0.26, 0.18)
const READ_ONLY_NOTE := "Talents can be changed in the main menu or the training area."
const EDIT_NOTE := "Left click: spend a point. Right click: take one back."

## Height of the tree; its width follows (square cells).
var tree_height := 340.0
## The book whose tree is showing.
var category := ""
## Points can be spent and taken back here (the training area).
var editable := false
## Show this PlayerData instead of yours (set before adding the view).
var data_source: Node = null

var _tabs := {}       # category -> Button
var _title: Label
var _mode_label: Label   # "view only" / how to spend points
var _canvas: Control
var _cells := {}      # talent id -> Panel (a seal's Control on the ribbon layout)
var _cell := 34.0
var _bc := 34.0       # the open book's cell (smaller in a wider book)
var _ribbon := {}     # the ribbon layout's metrics for RibbonDrawer ({} = the old grid)
var _reset: Button    # Reset all talents (yours only; works where talents can be changed)
var _query := ""      # the Spellbook's search: matching talents framed, the rest dimmed
## Narrowest a ribbon book's column may get, in px.
const MIN_RIBBON_CELL := 34.0

static func cell_size(height: float) -> float:
	return clampf(floorf(height / Talents.ROWS), 28.0, 44.0)

## Width a tree of `height` needs.
static func width_for(height: float) -> float:
	var w := cell_size(height) * Talents.COLUMNS
	for cat in Talents.GROUPS:   # a ribbon book needs its columns readable
		w = maxf(w, Talents.grid_width(cat) * MIN_RIBBON_CELL)
	return w

## The book to open first: the one with the most points in it (the first of
## `order` when there are none). `points` = category -> points spent.
static func default_book(points: Dictionary, order: Array) -> String:
	var best := str(order[0]) if not order.is_empty() else ""
	var most := 0
	for cat in order:
		var n := int(points.get(cat, 0))
		if n > most:
			most = n
			best = str(cat)
	return best

## Whose talents: `data_source` (another player's detached PlayerData, the Inspect
## window) or yours.
func _pd() -> Node:
	return data_source if data_source != null else get_node_or_null("/root/PlayerData")

func _ready() -> void:
	_cell = cell_size(tree_height)
	add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	add_child(head)
	head.add_child(UI.label("Talents", 17, UI.ACCENT))
	var ro := UI.label("view only", 13, UI.TEXT_DIM)
	_mode_label = ro
	ro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ro.tooltip_text = READ_ONLY_NOTE
	ro.mouse_filter = Control.MOUSE_FILTER_STOP
	head.add_child(ro)
	if data_source == null:
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(gap)
		_reset = UI.button("Reset", 11, Vector2(56, 22))
		_reset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_reset.pressed.connect(func():
			if editable and _pd():
				_pd().reset_talents())
		head.add_child(_reset)
		_update_reset()

	var tabs := HFlowContainer.new()
	tabs.custom_minimum_size = Vector2(width_for(tree_height), 0)
	tabs.add_theme_constant_override("h_separation", 2)
	tabs.add_theme_constant_override("v_separation", 2)
	add_child(tabs)
	for cat in Categories.ORDER:
		var c: String = cat
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(30, 30)
		b.pressed.connect(func(): show_book(c))
		var em := Control.new()
		em.set_anchors_preset(Control.PRESET_FULL_RECT)
		em.offset_left = 2
		em.offset_top = 2
		em.offset_right = -2
		em.offset_bottom = -2
		em.mouse_filter = Control.MOUSE_FILTER_IGNORE
		em.draw.connect(func(): Categories.draw_emblem(em, c))
		b.add_child(em)
		tabs.add_child(b)
		_tabs[c] = b

	_title = UI.label("", 16, Color.WHITE)
	add_child(_title)

	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(width_for(tree_height), _cell * Talents.ROWS)
	_canvas.draw.connect(_draw_canvas)
	add_child(_canvas)

	var pd := _pd()
	var points := {}
	if pd:
		if data_source == null:   # (a snapshot never changes)
			pd.changed.connect(_on_pd_changed)
		for cat in Categories.ORDER:
			points[cat] = pd.tree_points(cat)
	show_book(default_book(points, Categories.ORDER))

## Show one book's tree.
func show_book(cat: String) -> void:
	category = cat
	for id in _cells:
		_cells[id].queue_free()
	_cells.clear()
	# A wider book (the column-group layout) gets smaller cells in the same width.
	var width := width_for(tree_height)
	_ribbon = {}
	if not Talents.groups_of(cat).is_empty():
		_build_seals(cat, width)
		refresh()
		_mark_search()
		return
	_canvas.custom_minimum_size = Vector2(width, _cell * Talents.ROWS)
	_bc = _cell * Talents.COLUMNS / maxf(Talents.columns_of(cat), Talents.COLUMNS)
	var size_px := _bc - 6.0
	for r in Talents.rows_of(cat):
		for id in Talents.in_row(cat, r):
			var cell := Panel.new()
			cell.position = Vector2(Talents.col_of(id), Talents.tier_of(id)) * _bc + Vector2(3, 3)
			cell.size = Vector2(size_px, size_px)
			if TalentIcons.has_icon(id):
				var icon := Control.new()
				icon.name = "Icon"
				icon.set_anchors_preset(Control.PRESET_FULL_RECT)
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icon.draw.connect(func(): TalentIcons.draw(icon, id))
				cell.add_child(icon)
			var rank := UI.label("", 9 if _bc >= 34.0 else 8, Color.WHITE)
			rank.name = "Rank"
			rank.set_anchors_preset(Control.PRESET_FULL_RECT)
			rank.offset_right = -3
			rank.offset_bottom = -1
			rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			rank.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(rank)
			_canvas.add_child(cell)
			_cells[id] = cell
			_wire_cell(cell, id)
	refresh()
	_mark_search()

## The ribbon layout: one seal per talent over the ribbons RibbonDrawer draws.
func _build_seals(cat: String, width: float) -> void:
	var cw := width / Talents.grid_width(cat)
	var ch := minf(tree_height / (Talents.ROWS + RibbonDrawer.TAIL + 0.1), cw * 1.4)
	var top := RibbonDrawer.HEAD_H + 2.0
	var seal := clampf(minf(cw - 4.0, ch - 10.0), 12.0, 40.0)
	_ribbon = {"x": 0.0, "top": top, "cell": Vector2(cw, ch), "seal": seal}
	_canvas.custom_minimum_size = Vector2(width, top + (Talents.ROWS + RibbonDrawer.TAIL + 0.1) * ch)
	for r in Talents.rows_of(cat):
		for id in Talents.in_row(cat, r):
			var side := seal
			if Talents.group_of(id) == Talents.OPEN_GROUP:
				side = seal * 0.8
			elif Talents.capstone_gated(id):
				side = minf(seal * 1.15, minf(cw, ch) - 4.0)
			var cell := Control.new()
			cell.size = Vector2(side, side)
			cell.position = RibbonDrawer.center(_ribbon, id) - cell.size / 2.0
			cell.mouse_filter = Control.MOUSE_FILTER_STOP
			cell.draw.connect(func(): RibbonDrawer.draw_seal(cell, cat, id, RibbonDrawer.seal_state(_pd(), id)))
			if TalentIcons.has_icon(id):
				var icon := Control.new()
				icon.name = "Icon"
				icon.anchor_left = 0.13
				icon.anchor_top = 0.13
				icon.anchor_right = 0.87
				icon.anchor_bottom = 0.87
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icon.draw.connect(func(): TalentIcons.draw(icon, id, true))
				cell.add_child(icon)
			# The rank ("2/3") on top of the icon.
			var rank_tab := Control.new()
			rank_tab.name = "RankTab"
			rank_tab.set_anchors_preset(Control.PRESET_FULL_RECT)
			rank_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rank_tab.draw.connect(func(): RibbonDrawer.draw_rank(rank_tab, RibbonDrawer.seal_state(_pd(), id)))
			cell.add_child(rank_tab)
			_canvas.add_child(cell)
			_cells[id] = cell
			_wire_cell(cell, id)

## Only while showing: a hidden view is refreshed by its owner when it opens
## (game_ui.gd _refresh_spellbook), not on every PlayerData change.
func _on_pd_changed() -> void:
	if is_visible_in_tree():
		refresh()

## Ranks, borders and tooltips from PlayerData.
func refresh() -> void:
	var pd := _pd()
	if pd == null or _canvas == null or category == "":
		return
	var col := Categories.color(category)
	var pts: int = pd.tree_points(category)
	_title.text = "%s  •  %d %s" % [Categories.cat_name(category), pts, "point" if pts == 1 else "points"]
	_title.add_theme_color_override("font_color", col.lightened(0.35))
	for c in _tabs:
		var b: Button = _tabs[c]
		var tc := Categories.color(c)
		var on: bool = c == category
		var spent: int = pd.tree_points(c)
		b.tooltip_text = "%s%s" % [Categories.cat_name(c), "  (%d %s)" % [spent, "point" if spent == 1 else "points"] if spent > 0 else ""]
		b.add_theme_stylebox_override("normal", UI.box(tc.darkened(0.7) if on else UI.BG, tc if on else tc.darkened(0.45), 2 if on else 1, 5))
		b.add_theme_stylebox_override("hover", UI.box(tc.darkened(0.6), tc, 2, 5))
		b.add_theme_stylebox_override("pressed", UI.box(tc.darkened(0.6), tc, 2, 5))
	if not _ribbon.is_empty():
		for id in _cells:
			var seal: Control = _cells[id]
			var rank: int = pd.talent_rank(id)
			var icon: Control = seal.get_node_or_null("Icon")
			if icon:
				icon.modulate = Color.WHITE if rank > 0 else Color(0.5, 0.5, 0.5, 0.6)   # no points: grayed, even if open
			if seal.has_meta("hot"):   # (the rest build theirs on hover: _wire_cell)
				seal.tooltip_text = _tip(id)
			seal.queue_redraw()
			seal.get_node("RankTab").queue_redraw()
		_canvas.queue_redraw()
		return
	for id in _cells:
		var cell: Panel = _cells[id]
		var rank: int = pd.talent_rank(id)
		var max_rank := Talents.max_rank(id)
		var border := CELL_BORDER
		if rank >= max_rank and max_rank > 0:
			border = UI.ACCENT
		elif rank > 0:
			border = col
		cell.add_theme_stylebox_override("panel", UI.box(CELL_BG if rank > 0 else CELL_BG_EMPTY, border, 2, 5))
		var icon: Control = cell.get_node_or_null("Icon")
		if icon:
			icon.modulate = Color.WHITE if rank > 0 else Color(0.5, 0.5, 0.5, 0.75)   # dim = no points in it
		var rank_l: Label = cell.get_node("Rank")
		rank_l.text = "%d/%d" % [rank, max_rank]
		rank_l.add_theme_color_override("font_color", Color.WHITE if rank > 0 else Color(0.55, 0.52, 0.48))
		if cell.has_meta("hot"):
			cell.tooltip_text = _tip(id)
	_canvas.queue_redraw()

## Spend / take back points here (the training area) or not; game_ui sets it.
func set_editable(on: bool) -> void:
	if on == editable:
		return
	editable = on
	_update_reset()
	if _mode_label:
		_mode_label.text = "click to change" if on else "view only"
		_mode_label.add_theme_color_override("font_color", UI.ACCENT if on else UI.TEXT_DIM)
		_mode_label.tooltip_text = EDIT_NOTE if on else READ_ONLY_NOTE
	for id in _cells:
		if _cells[id].has_meta("hot"):
			_cells[id].tooltip_text = _tip(id)

func _update_reset() -> void:
	if _reset == null:
		return
	_reset.disabled = not editable
	_reset.tooltip_text = "Reset all talents" if editable else "Reset all talents: in the main menu or the training area"

## The Spellbook's search (Keywords.matches, as the main menu's): frame the talents
## that match, dim the rest. "" = no search.
func set_search(query: String) -> void:
	_query = query.strip_edges()
	_mark_search()

func _mark_search() -> void:
	for id in _cells:
		var cell: Control = _cells[id]
		var hit := _query != "" and (Keywords.matches("t:" + str(id), _query) \
			or Talents.options_of(str(id)).any(func(o): return Keywords.matches("t:" + str(o), _query)))
		cell.modulate = Color(1, 1, 1, 0.3) if _query != "" and not hit else Color.WHITE
		var mark: Panel = cell.get_node_or_null("SearchMark")
		if hit and mark == null:
			mark = Panel.new()
			mark.name = "SearchMark"
			mark.set_anchors_preset(Control.PRESET_FULL_RECT)
			mark.offset_left = -2
			mark.offset_top = -2
			mark.offset_right = 2
			mark.offset_bottom = 2
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mark.add_theme_stylebox_override("panel", UI.box(Color(SEARCH_COL, 0.1), SEARCH_COL, 2, 7))
			cell.add_child(mark)
		elif mark != null:
			mark.visible = hit
	# A book without matches dims its tab.
	for c in _tabs:
		var any := _query == ""
		if not any:
			for id in Talents.in_tree(str(c)):
				if Keywords.matches("t:" + str(id), _query):
					any = true
					break
		(_tabs[c] as Button).modulate = Color.WHITE if any else Color(1, 1, 1, 0.35)

func _tip(id: String) -> String:
	var pd := _pd()
	return "%s\n%s" % [Talents.tooltip(id, pd.talent_rank(id) if pd else 0), EDIT_NOTE if editable else READ_ONLY_NOTE]

## Hover builds the tooltip (slow to build, so not for every cell on each refresh);
## clicks spend (left) or take back (right) a point while `editable`.
func _wire_cell(cell: Control, id: String) -> void:
	cell.mouse_entered.connect(func():
		cell.set_meta("hot", true)
		cell.tooltip_text = _tip(id))
	cell.mouse_exited.connect(func(): cell.remove_meta("hot"))
	cell.gui_input.connect(func(ev: InputEvent):
		if not editable or not (ev is InputEventMouseButton) or not ev.pressed:
			return
		if ev.button_index == MOUSE_BUTTON_LEFT:
			if Talents.is_choice_slot(id):
				_pick_choice(cell, id)
			else:
				var err: String = _pd().invest_talent(id)
				_say(err)
				if err != "":   # locked: the talents that would open it pulse with light
					_pulse(_pd().talents_to_open(id), RibbonDrawer.HELP)
			cell.accept_event()
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			var which := id
			for o in Talents.options_of(id):   # a choice slot: the option you picked
				if _pd().talent_rank(o) > 0:
					which = o
			var err: String = _pd().refund_talent(which)
			_say(err)
			if err != "" and _pd().talent_rank(which) > 0:   # held up: what depends on it pulses red
				_pulse(_pd().talents_blocking_refund(which), RibbonDrawer.BLOCK)
			cell.accept_event())

## Pulses the cells of these talents (one of a choice's two: its slot).
func _pulse(ids: Array[String], col: Color) -> void:
	for x in ids:
		var key := Talents.choice_slot_of(x) if Talents.choice_slot_of(x) != "" else x
		if _cells.has(key):
			RibbonDrawer.pulse(_cells[key], col)

## A choice slot: a small menu of its talents; picking one spends a point in it.
func _pick_choice(cell: Control, slot: String) -> void:
	var pop := PopupMenu.new()
	var opts := Talents.options_of(slot)
	for i in opts.size():
		var o: String = opts[i]
		pop.add_item("%s  (%d/%d)" % [Talents.get_talent(o).get("name", o), _pd().talent_rank(o), Talents.max_rank(o)], i)
	pop.id_pressed.connect(func(i: int): _say(_pd().invest_talent(opts[i])))
	pop.popup_hide.connect(pop.queue_free)
	add_child(pop)
	pop.popup(Rect2i(Vector2i(cell.get_screen_position() + Vector2(0, cell.size.y)), Vector2i.ZERO))

func _say(err: String) -> void:
	if err != "":
		message.emit(err)

# Row lines and the links between talents (under the cells).
func _draw_canvas() -> void:
	if category == "":
		return
	if not _ribbon.is_empty():
		RibbonDrawer.draw_book(_canvas, category, _ribbon, _pd())
		return
	var w := _bc * Talents.columns_of(category)
	for r in range(1, Talents.rows_of(category)):
		_canvas.draw_line(Vector2(0, r * _bc), Vector2(w, r * _bc), Color(CELL_BORDER, 0.45), 1.0)
	var pd := _pd()
	var half := (_bc - 6.0) / 2.0
	for l in Talents.links_in_tree(category):
		var a := (Vector2(Talents.col_of(l[0]), Talents.tier_of(l[0])) + Vector2(0.5, 0.5)) * _bc
		var b := (Vector2(Talents.col_of(l[1]), Talents.tier_of(l[1])) + Vector2(0.5, 0.5)) * _bc
		var dir := (b - a).normalized()
		var k := half / maxf(maxf(absf(dir.x), absf(dir.y)), 0.001)
		var from := a + dir * k
		var to := b - dir * k
		var maxed: bool = pd != null and pd.talent_rank(l[0]) >= Talents.max_rank(l[0])
		var col := UI.ACCENT if maxed else Color(0.62, 0.57, 0.5, 0.7)
		_canvas.draw_line(from, to, Color(0, 0, 0, 0.5), 4.0, true)
		_canvas.draw_line(from, to, col, 2.0, true)
		var side := Vector2(-dir.y, dir.x) * 4.0
		_canvas.draw_colored_polygon(PackedVector2Array([to, to - dir * 7.0 + side, to - dir * 7.0 - side]), col)
