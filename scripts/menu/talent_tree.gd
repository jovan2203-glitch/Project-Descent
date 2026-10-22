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
var T_TOP := 0.0                # strip above the grid for spec group names (Talents.GROUPS)
const GROUP_HEADER_H := 16.0

func _build_talent_tree() -> void:
	for c in _book_tree.get_children():
		c.queue_free()
	_talent_buttons.clear()
	_close_choice()
	_row_status.clear()
	_row_info.clear()
	var pd := menu.get_node("/root/PlayerData")
	# One canvas: talents placed on the book's rows x columns grid, link lines drawn
	# underneath (see _draw_talent_canvas). _layout_talent_canvas sizes it to the page.
	var canvas := Control.new()
	_talent_canvas = canvas
	_talent_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	_talent_canvas.draw.connect(_draw_talent_canvas.bind(canvas))
	_book_tree.add_child(_talent_canvas)
	for r in Talents.rows_of(menu.open_book._book_cat):
		for id in Talents.in_row(menu.open_book._book_cat, r):
			var b := _make_talent_button(id)
			_talent_canvas.add_child(b)
			_talent_buttons[id] = b
			menu.book_search._add_mark(b)
			menu.book_search._wire_hover(b, "t:" + id)
			if Talents.is_choice_slot(id):
				b.mouse_entered.connect(_show_choice.bind(id))
				b.mouse_exited.connect(_hide_choice_soon)
	_layout_talent_canvas()
	_refresh_talents()

## A talent's button: icon (if it has one) and rank. Left click spends a point,
## right click takes one back. A choice slot's own button opens its two talents
## instead (right click takes back a point from the one picked).
func _make_talent_button(id: String) -> Button:
	var pd := menu.get_node("/root/PlayerData")
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	var choice := Talents.is_choice_slot(id)
	b.pressed.connect(func():
		if choice:
			_show_choice(id)
		else:
			menu._toast_if(pd.invest_talent(id)))
	b.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			var which := id
			if choice:
				for o in Talents.options_of(id):
					if pd.talent_rank(o) > 0:
						which = o
			menu._toast_if(pd.refund_talent(which)))
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
	return b

# --- Choice talents: hovering the slot shows its two talents above it ----------------

var _choice_popup: PanelContainer
var _choice_slot := ""
var _choice_buttons := {}   # talent id -> Button (the open choice's two)

func _show_choice(slot: String) -> void:
	if _choice_slot == slot and is_instance_valid(_choice_popup):
		return
	_close_choice()
	if not is_instance_valid(_talent_canvas) or not _talent_buttons.has(slot):
		return
	_choice_slot = slot
	_choice_popup = PanelContainer.new()
	_choice_popup.add_theme_stylebox_override("panel", UI.box(Color(0.1, 0.09, 0.07, 0.97), Categories.color(menu.open_book._book_cat), 2, 6))
	_choice_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_choice_popup.mouse_exited.connect(_hide_choice_soon)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_choice_popup.add_child(row)
	for o in Talents.options_of(slot):
		var b := _make_talent_button(o)
		b.custom_minimum_size = Vector2(T_BTN, T_BTN)
		b.mouse_exited.connect(_hide_choice_soon)
		row.add_child(b)
		_choice_buttons[o] = b
	_talent_canvas.add_child(_choice_popup)
	var sb: Button = _talent_buttons[slot]
	var w := T_BTN * 2.0 + 6.0 + 8.0
	var at := sb.position + Vector2((sb.size.x - w) / 2.0, -T_BTN - 12.0)
	_choice_popup.position = Vector2(clampf(at.x, 0.0, maxf(_talent_canvas.size.x - w, 0.0)), maxf(at.y, 0.0))
	_refresh_talents()

## Close the choice a moment after the mouse leaves it (unless it went back in).
func _hide_choice_soon() -> void:
	await get_tree().create_timer(0.25).timeout
	if _choice_slot == "" or not is_instance_valid(_choice_popup):
		return
	var mouse := _talent_canvas.get_global_mouse_position()
	var sb: Button = _talent_buttons.get(_choice_slot)
	if _choice_popup.get_global_rect().has_point(mouse) or (is_instance_valid(sb) and sb.get_global_rect().has_point(mouse)):
		return
	_close_choice()

func _close_choice() -> void:
	if is_instance_valid(_choice_popup):
		_choice_popup.queue_free()
	_choice_popup = null
	_choice_slot = ""
	_choice_buttons.clear()

## Fit the whole tree into the talent page: cell size comes from the page size,
## buttons scale with it, and the grid is centered. A book on the column-group
## layout (Talents.GROUPS) gets a strip on top for its spec names.
func _layout_talent_canvas() -> void:
	if not is_instance_valid(_talent_canvas) or _book_tree.size.x <= 0.0 or _book_tree.size.y <= 0.0:
		return
	var cat: String = menu.open_book._book_cat
	var rows := Talents.rows_of(cat)
	var cols := Talents.columns_of(cat)
	var avail := _book_tree.size
	T_LABEL_W = 0.0
	T_TOP = GROUP_HEADER_H if not Talents.groups_of(cat).is_empty() else 0.0
	var ch := (avail.y - T_TOP) / rows
	var cw := minf(avail.x / cols, ch * 1.6)   # don't spread too wide
	T_CELL = Vector2(cw, ch)
	T_BTN = clampf(minf(cw, ch) - 8.0, 22.0, 50.0)
	var w := cols * cw
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
	return Vector2(T_LABEL_W + Talents.col_of(id) * T_CELL.x, T_TOP + Talents.tier_of(id) * T_CELL.y)

func _talent_center(id: String) -> Vector2:
	return _talent_cell_origin(id) + T_CELL / 2.0

# Row separators, spec groups + link lines between talents of the open book (under the buttons).
func _draw_talent_canvas(canvas: Control) -> void:
	# An old canvas (book just switched, not freed yet) draws nothing.
	var cat: String = menu.open_book._book_cat
	if cat == "" or canvas != _talent_canvas:
		return
	var w := T_LABEL_W + Talents.columns_of(cat) * T_CELL.x
	for r in range(1, Talents.rows_of(cat)):
		var y := T_TOP + r * T_CELL.y
		canvas.draw_line(Vector2(0, y), Vector2(w, y), Color(MainMenu.PAGE_BORDER, 0.45), 1.0)
	_draw_groups(canvas, cat)
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

## The column-group layout: a faint line between spec groups (a reminder, not a
## barrier) and each group's name and points on top.
func _draw_groups(canvas: Control, cat: String) -> void:
	var groups := Talents.groups_of(cat)
	if groups.is_empty():
		return
	var pd := menu.get_node("/root/PlayerData")
	var font := ThemeDB.fallback_font
	var fsize := 11 if T_CELL.x >= 44.0 else 9
	var bottom := T_TOP + Talents.rows_of(cat) * T_CELL.y
	for i in groups.size():
		var g: Array = groups[i]
		var x0 := T_LABEL_W + int(g[1]) * T_CELL.x
		var x1 := T_LABEL_W + (int(g[2]) + 1) * T_CELL.x
		if i > 0:
			canvas.draw_line(Vector2(x0, 2), Vector2(x0, bottom), Color(MainMenu.INK_DIM, 0.22), 1.0)
		var pts: int = pd.group_points(cat, str(g[0]))
		var text := str(g[0]) if pts <= 0 else "%s  %d" % [g[0], pts]
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		canvas.draw_string(font, Vector2((x0 + x1 - tw) / 2.0, T_TOP - 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, x1 - x0, fsize,
			Color(MainMenu.INK_DIM, 0.85))

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
		_style_talent_button(_talent_buttons[id], id, pd, col)
	for id in _choice_buttons:
		_style_talent_button(_choice_buttons[id], id, pd, col)
	if is_instance_valid(_talent_canvas):
		_talent_canvas.queue_redraw()

## Rank, border, colours and tooltip of one talent's button.
func _style_talent_button(b: Button, id: String, pd: Node, col: Color) -> void:
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
