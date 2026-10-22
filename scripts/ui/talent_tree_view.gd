extends VBoxContainer

# Read-only talent trees (the in-game Spellbook shows this next to your
# abilities): pick a book with the emblem buttons and hover a talent to read it.
# Nothing here invests or refunds a point - talents are only changed in the
# main menu.
# Usage: var v := TALENT_VIEW.new(); v.tree_height = 340.0; parent.add_child(v)

const UI = preload("res://scripts/ui_kit.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const Categories = preload("res://scripts/categories.gd")

const CELL_BG := Color(0.16, 0.14, 0.11, 0.95)
const CELL_BG_EMPTY := Color(0.08, 0.07, 0.06, 0.95)
const CELL_BORDER := Color(0.32, 0.26, 0.18)
const READ_ONLY_NOTE := "Talents can only be changed in the main menu."

## Height of the tree; its width follows (square cells).
var tree_height := 340.0
## The book whose tree is showing.
var category := ""

var _tabs := {}       # category -> Button
var _title: Label
var _canvas: Control
var _cells := {}      # talent id -> Panel
var _cell := 34.0
var _bc := 34.0       # the open book's cell (smaller in a wider book)

static func cell_size(height: float) -> float:
	return clampf(floorf(height / Talents.ROWS), 28.0, 44.0)

## Width a tree of `height` needs.
static func width_for(height: float) -> float:
	return cell_size(height) * Talents.COLUMNS

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

func _pd() -> Node:
	return get_node_or_null("/root/PlayerData")

func _ready() -> void:
	_cell = cell_size(tree_height)
	add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	add_child(head)
	head.add_child(UI.label("Talents", 14, UI.ACCENT))
	var ro := UI.label("view only", 11, UI.TEXT_DIM)
	ro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ro.tooltip_text = READ_ONLY_NOTE
	ro.mouse_filter = Control.MOUSE_FILTER_STOP
	head.add_child(ro)

	var tabs := HFlowContainer.new()
	tabs.custom_minimum_size = Vector2(_cell * Talents.COLUMNS, 0)
	tabs.add_theme_constant_override("h_separation", 2)
	tabs.add_theme_constant_override("v_separation", 2)
	add_child(tabs)
	for cat in Categories.ORDER:
		var c: String = cat
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(22, 22)
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

	_title = UI.label("", 13, Color.WHITE)
	add_child(_title)

	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(_cell * Talents.COLUMNS, _cell * Talents.ROWS)
	_canvas.draw.connect(_draw_canvas)
	add_child(_canvas)

	var pd := _pd()
	var points := {}
	if pd:
		pd.changed.connect(refresh)
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
		cell.tooltip_text = "%s\n%s" % [Talents.tooltip(id, rank), READ_ONLY_NOTE]
	_canvas.queue_redraw()

# Row lines and the links between talents (under the cells).
func _draw_canvas() -> void:
	if category == "":
		return
	var w := _bc * Talents.columns_of(category)
	for r in range(1, Talents.rows_of(category)):
		_canvas.draw_line(Vector2(0, r * _bc), Vector2(w, r * _bc), Color(CELL_BORDER, 0.45), 1.0)
	# The column-group layout: a faint line between spec groups.
	var groups := Talents.groups_of(category)
	for i in range(1, groups.size()):
		var x := int(groups[i][1]) * _bc
		_canvas.draw_line(Vector2(x, 0), Vector2(x, Talents.rows_of(category) * _bc), Color(CELL_BORDER, 0.3), 1.0)
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
