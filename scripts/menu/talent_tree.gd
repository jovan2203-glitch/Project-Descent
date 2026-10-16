extends "res://scripts/menu/menu_part.gd"
class_name TalentTreePage

# The talent tree on the right page of the open book.

var _book_tree: Control         # the talent page (the grid scales to fit it)
var _talent_buttons := {}      # talent id -> Button (open book only)
var _row_status: Array[Label] = []
var _row_info: Array[Control] = []   # row label boxes, positioned by _layout_talent_canvas
var _talent_canvas: Control     # the open book's talent grid (lines are drawn on it)
# Grid metrics, recomputed from the page size so a whole tree fits without scrolling.
var T_LABEL_W := 74.0           # row labels on the left of the grid
var T_CELL := Vector2(56, 54)   # one grid cell (column x row)
var T_BTN := 42.0               # talent button size

func _build_talent_tree() -> void:
	for c in _book_tree.get_children():
		c.queue_free()
	_talent_buttons.clear()
	_row_status.clear()
	_row_info.clear()
	var pd := menu.get_node("/root/PlayerData")
	# One canvas: talents placed on a ROWS x COLUMNS grid, link lines drawn
	# underneath (see _draw_talent_canvas). _layout_talent_canvas sizes it to the page.
	var canvas := Control.new()
	_talent_canvas = canvas
	_talent_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	_talent_canvas.draw.connect(_draw_talent_canvas.bind(canvas))
	_book_tree.add_child(_talent_canvas)
	for r in Talents.ROWS:
		for id in Talents.in_row(menu.open_book._book_cat, r):
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(func(): menu._toast_if(pd.invest_talent(id)))
			b.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
					menu._toast_if(pd.refund_talent(id)))
			if TalentIcons.has_icon(id):
				# Icon fills the button; the rank sits small in the bottom-right corner.
				var icon := Control.new()
				icon.name = "Icon"
				icon.set_anchors_preset(Control.PRESET_FULL_RECT)
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icon.draw.connect(func(): TalentIcons.draw(icon, id))
				b.add_child(icon)
				var rank_l := menu._label("", 10, Color.WHITE)
				rank_l.name = "Rank"
				rank_l.set_anchors_preset(Control.PRESET_FULL_RECT)
				rank_l.offset_right = -3
				rank_l.offset_bottom = -1
				rank_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				rank_l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
				b.add_child(rank_l)
			_talent_canvas.add_child(b)
			_talent_buttons[id] = b
			menu.book_search._add_mark(b)
			menu.book_search._wire_hover(b, "t:" + id)
	_layout_talent_canvas()
	_refresh_talents()

## Fit the whole tree into the talent page: cell size comes from the page size,
## buttons scale with it, and the grid is centered.
func _layout_talent_canvas() -> void:
	if not is_instance_valid(_talent_canvas) or _book_tree.size.x <= 0.0 or _book_tree.size.y <= 0.0:
		return
	var avail := _book_tree.size
	T_LABEL_W = 0.0
	var ch := avail.y / Talents.ROWS
	var cw := minf(avail.x / Talents.COLUMNS, ch * 1.6)   # don't spread too wide
	T_CELL = Vector2(cw, ch)
	T_BTN = clampf(minf(cw, ch) - 8.0, 22.0, 50.0)
	var w := Talents.COLUMNS * cw
	_talent_canvas.position = Vector2((avail.x - w) / 2.0, 0)
	_talent_canvas.size = Vector2(w, avail.y)
	var font := 12 if T_BTN >= 36.0 else (11 if T_BTN >= 28.0 else 9)
	for id in _talent_buttons:
		var b: Button = _talent_buttons[id]
		b.position = _talent_cell_origin(id) + (T_CELL - Vector2(T_BTN, T_BTN)) / 2.0
		b.size = Vector2(T_BTN, T_BTN)
		b.add_theme_font_size_override("font_size", font)
	_talent_canvas.queue_redraw()

## Top-left corner of a talent's grid cell on the canvas.
func _talent_cell_origin(id: String) -> Vector2:
	return Vector2(T_LABEL_W + Talents.col_of(id) * T_CELL.x, Talents.tier_of(id) * T_CELL.y)

func _talent_center(id: String) -> Vector2:
	return _talent_cell_origin(id) + T_CELL / 2.0

# Row separators + link lines between talents of the open book (under the buttons).
func _draw_talent_canvas(canvas: Control) -> void:
	# An old canvas (book just switched, not freed yet) draws nothing.
	if menu.open_book._book_cat == "" or canvas != _talent_canvas:
		return
	var w := T_LABEL_W + Talents.COLUMNS * T_CELL.x
	for r in range(1, Talents.ROWS):
		var y := r * T_CELL.y
		canvas.draw_line(Vector2(0, y), Vector2(w, y), Color(MainMenu.PAGE_BORDER, 0.45), 1.0)
	var pd := menu.get_node("/root/PlayerData")
	var half := T_BTN / 2.0
	for l in Talents.links_in_tree(menu.open_book._book_cat):
		var a: Vector2 = _talent_center(l[0])
		var b: Vector2 = _talent_center(l[1])
		var dir := (b - a).normalized()
		# Start/end at the button edges (square buttons: clip to the box).
		var k := half / maxf(absf(dir.x), absf(dir.y))
		var from := a + dir * k
		var to := b - dir * k
		var maxed: bool = pd.talent_rank(l[0]) >= Talents.max_rank(l[0])
		var col := MainMenu.C_ACCENT if maxed else Color(MainMenu.INK_DIM, 0.7)
		canvas.draw_line(from, to, Color(0, 0, 0, 0.5), 6.0, true)
		canvas.draw_line(from, to, col, 3.0, true)
		# Arrowhead at the unlocked talent.
		var side := Vector2(-dir.y, dir.x) * 5.0
		canvas.draw_colored_polygon(PackedVector2Array([to, to - dir * 9.0 + side, to - dir * 9.0 - side]), col)

func _refresh_talents() -> void:
	var pd := menu.get_node("/root/PlayerData")
	menu._talent_points_label.text = "Level %d  •  Talent points: %d / %d" % [pd.level, pd.talent_points_left(), pd.talent_points_total()]
	for cat in menu.shelf._shelf_info:
		var ids := Abilities.in_category(cat)
		var have := 0
		for id in ids:
			if pd.has_ability(id):
				have += 1
		var talents := 0
		for tid in Talents.in_tree(cat):
			if pd.talent_rank(tid) > 0:
				talents += 1
		# Only what's learned: "6 abilities  •  3 talents"; nothing if empty.
		var parts: Array[String] = []
		if have > 0:
			parts.append("%d %s" % [have, "ability" if have == 1 else "abilities"])
		if talents > 0:
			parts.append("%d %s" % [talents, "talent" if talents == 1 else "talents"])
		menu.shelf._shelf_info[cat].text = "  •  ".join(parts)
		if cat == Categories.RUNE:
			menu.shelf._shelf_info[cat].text = "%d of %d known" % [have, ids.size()] if have > 0 else "None on your gear"
	if menu.open_book._book_cat == "":
		return
	var pts: int = pd.tree_points(menu.open_book._book_cat)
	menu.open_book._book_sub.text = Categories.desc(menu.open_book._book_cat) + ("   •   %d talent %s in this book" % [pts, "point" if pts == 1 else "points"] if pts > 0 else "")
	var col := Categories.color(menu.open_book._book_cat)
	for r in _row_status.size():
		var status: Label = _row_status[r]
		if pd.tier_unlocked(r):
			status.text = "Open • %d spent" % pd.tier_points(r)
			status.add_theme_color_override("font_color", Color(0.55, 0.9, 0.55))
		else:
			status.text = "Locked • %d/%d in row %d" % [pd.tier_points(r - 1), Talents.POINTS_TO_UNLOCK_NEXT, r]
			status.add_theme_color_override("font_color", Color(0.9, 0.45, 0.4))
	for id in _talent_buttons:
		var b: Button = _talent_buttons[id]
		var t := Talents.get_talent(id)
		var rank: int = pd.talent_rank(id)
		var max_rank := int(t["max_rank"])
		# A talent that only works with one ability stays shut until it is learned.
		var need := Talents.required_ability(id)
		var missing: bool = need != "" and not pd.has_ability(need)
		var unlocked: bool = pd.talent_unlocked(id) and not missing
		var linked: bool = unlocked and not pd.tier_unlocked(int(t["tier"]))   # opened by a link only
		var rank_l: Label = b.get_node_or_null("Rank")
		if rank_l:
			b.text = ""
			rank_l.text = "%d/%d" % [rank, max_rank]
			rank_l.add_theme_font_size_override("font_size", 10 if T_BTN >= 36.0 else 8)
			var icon: Control = b.get_node("Icon")
			icon.modulate = Color.WHITE if unlocked else Color(0.45, 0.45, 0.45, 0.8)   # grayed while locked
			icon.queue_redraw()
		else:
			b.text = "%d/%d" % [rank, max_rank]
		var border := MainMenu.PAGE_BORDER
		if rank >= max_rank:
			border = MainMenu.C_ACCENT
		elif rank > 0:
			border = col
		elif linked:
			border = MainMenu.C_ACCENT.darkened(0.35)
		var bg := Color(0.16, 0.14, 0.11, 0.95) if unlocked else Color(0.08, 0.07, 0.06, 0.95)
		b.add_theme_stylebox_override("normal", UI.box(bg, border, 2, 6))
		b.add_theme_stylebox_override("hover", UI.box(bg.lightened(0.08), col, 2, 6))
		b.add_theme_stylebox_override("pressed", UI.box(bg.lightened(0.08), col, 2, 6))
		b.add_theme_color_override("font_color", Color.WHITE if unlocked else Color(0.45, 0.42, 0.38))
		var req := ""
		if linked:
			req = "\nUnlocked by a maxed linked talent"
		elif not pd.talent_unlocked(id):
			req = "\nRequires %d points in row %d (any book)" % [Talents.POINTS_TO_UNLOCK_NEXT, int(t["tier"])]
			if not Talents.sources_of(id).is_empty():
				req += " or a maxed linked talent"
		if missing:
			req += "\nYou have not learned %s: points can't be spent here yet" % Abilities.ability_name(need)
		b.tooltip_text = Talents.tooltip(id, rank) + req
	if is_instance_valid(_talent_canvas):
		_talent_canvas.queue_redraw()
