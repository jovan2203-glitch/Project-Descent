extends "res://scripts/menu/menu_part.gd"
class_name TalentTreePage

# The talent tree on the right page of the open book.

const Balance = preload("res://scripts/balance.gd")
const RibbonDrawer = preload("res://scripts/ui/ribbon_drawer.gd")

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
var _unroll := {}               # ribbon layout: group -> rows its ribbon shows (tweened as it grows)
var _unroll_cat := ""

## Is the open book on the ribbon layout (Talents.GROUPS)?
func _ribbons() -> bool:
	return not Talents.groups_of(menu.open_book._book_cat).is_empty()

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
	var ribbon := not Talents.groups_of(Talents.category_of(id)).is_empty()
	b.mouse_entered.connect(func(): b.tooltip_text = _talent_tooltip(id, pd))
	b.pressed.connect(func():
		if choice:
			_show_choice(id)
		else:
			var err: String = pd.invest_talent(id)
			menu._toast_if(err)
			if err != "":   # locked: the talents that would open it pulse with light
				_pulse(pd.talents_to_open(id), RibbonDrawer.HELP)
			if ribbon:   # the seal is pressed: a quick squash
				b.pivot_offset = b.size / 2.0
				b.scale = Vector2(0.84, 0.84)
				b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	b.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			var which := id
			if choice:
				for o in Talents.options_of(id):
					if pd.talent_rank(o) > 0:
						which = o
			var err: String = pd.refund_talent(which)
			menu._toast_if(err)
			if err != "" and pd.talent_rank(which) > 0:   # held up: what depends on it pulses red
				_pulse(pd.talents_blocking_refund(which), RibbonDrawer.BLOCK))
	if ribbon:
		# A wax seal (RibbonDrawer.draw_seal) with the icon pressed in and its rank on top.
		# The button itself draws nothing (set once: theme overrides are slow to redo).
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			b.add_theme_stylebox_override(st, empty)
		var wax := Control.new()
		wax.name = "Wax"
		wax.set_anchors_preset(Control.PRESET_FULL_RECT)
		wax.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wax.draw.connect(func():
			var state: Dictionary = b.get_meta("seal", {})
			RibbonDrawer.draw_seal(wax, Talents.category_of(id), id, state.merged({"hover": b.is_hovered()}, true)))
		b.add_child(wax)
		b.mouse_entered.connect(wax.queue_redraw)
		b.mouse_exited.connect(wax.queue_redraw)
		if TalentIcons.has_icon(id):
			var seal_icon := Control.new()
			seal_icon.name = "Icon"
			seal_icon.anchor_left = 0.13
			seal_icon.anchor_top = 0.13
			seal_icon.anchor_right = 0.87
			seal_icon.anchor_bottom = 0.87
			seal_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			seal_icon.draw.connect(func(): TalentIcons.draw(seal_icon, id, true))
			b.add_child(seal_icon)
		# The rank ("2/3") on top of the icon.
		var rank_tab := Control.new()
		rank_tab.name = "RankTab"
		rank_tab.set_anchors_preset(Control.PRESET_FULL_RECT)
		rank_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rank_tab.draw.connect(func(): RibbonDrawer.draw_rank(rank_tab, b.get_meta("seal", {})))
		b.add_child(rank_tab)
	elif TalentIcons.has_icon(id):
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

## Pulses the open book's buttons for these talents (one of a choice's two: its slot).
func _pulse(ids: Array[String], col: Color) -> void:
	for x in ids:
		var key := Talents.choice_slot_of(x) if Talents.choice_slot_of(x) != "" else x
		if _talent_buttons.has(key):
			RibbonDrawer.pulse(_talent_buttons[key], col)

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
	var grouped := not Talents.groups_of(cat).is_empty()
	var units := Talents.grid_width(cat)   # columns plus the gaps between the ribbons
	var avail := _book_tree.size
	T_LABEL_W = 0.0
	T_TOP = RibbonDrawer.HEAD_H + 4.0 if grouped else 0.0
	var ch := (avail.y - T_TOP) / (rows + (RibbonDrawer.TAIL + 0.1 if grouped else 0.0))
	var cw := minf(avail.x / units, ch * (1.25 if grouped else 1.6))   # don't spread too wide
	T_CELL = Vector2(cw, ch)
	T_BTN = clampf(minf(cw - 6.0, ch - 12.0), 18.0, 46.0) if grouped else clampf(minf(cw, ch) - 8.0, 22.0, 50.0)
	var w := units * cw
	_talent_canvas.position = Vector2((avail.x - w) / 2.0, 0)
	_talent_canvas.size = Vector2(w, avail.y)
	var font := 12 if T_BTN >= 36.0 else (11 if T_BTN >= 28.0 else 9)
	for id in _talent_buttons:
		var b: Button = _talent_buttons[id]
		var side := T_BTN
		if grouped and Talents.group_of(id) == Talents.OPEN_GROUP:
			side = T_BTN * 0.8   # a bead on the spine
		elif grouped and Talents.capstone_gated(id):
			side = minf(T_BTN * 1.15, minf(T_CELL.x, T_CELL.y) - 4.0)
		b.position = _talent_cell_origin(id) + (T_CELL - Vector2(side, side)) / 2.0
		b.size = Vector2(side, side)
		b.pivot_offset = b.size / 2.0
		b.add_theme_font_size_override("font_size", font)
	_talent_canvas.queue_redraw()

## Top-left corner of a talent's grid cell on the canvas.
func _talent_cell_origin(id: String) -> Vector2:
	return Vector2(T_LABEL_W + Talents.column_x(Talents.category_of(id), Talents.col_of(id)) * T_CELL.x, T_TOP + Talents.tier_of(id) * T_CELL.y)

func _talent_center(id: String) -> Vector2:
	return _talent_cell_origin(id) + T_CELL / 2.0

# Row separators, spec groups + link lines between talents of the open book (under the buttons).
func _draw_talent_canvas(canvas: Control) -> void:
	# An old canvas (book just switched, not freed yet) draws nothing.
	var cat: String = menu.open_book._book_cat
	if cat == "" or canvas != _talent_canvas:
		return
	if not Talents.groups_of(cat).is_empty():
		RibbonDrawer.draw_book(canvas, cat, {"x": T_LABEL_W, "top": T_TOP, "cell": T_CELL, "seal": T_BTN},
			menu.get_node("/root/PlayerData"), _unroll)
		return
	var w := T_LABEL_W + Talents.columns_of(cat) * T_CELL.x
	for r in range(1, Talents.rows_of(cat)):
		var y := T_TOP + r * T_CELL.y
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
	if menu.shelf._shelf.visible:   # (hidden behind an open book: _close_book refreshes it)
		_refresh_shelf_info(pd)
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
	if _ribbons():
		_grow_ribbons(pd)
	for id in _talent_buttons:
		_style_talent_button(_talent_buttons[id], id, pd, col)
	for id in _choice_buttons:
		_style_talent_button(_choice_buttons[id], id, pd, col)
	if is_instance_valid(_talent_canvas):
		_talent_canvas.queue_redraw()

## The shelf's line under each book: what's learned in it.
func _refresh_shelf_info(pd: Node) -> void:
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

## Ribbon layout: each ribbon unrolls to its spec's deepest row (tweened when it grows;
## set at once when a book opens).
func _grow_ribbons(pd: Node) -> void:
	var cat: String = menu.open_book._book_cat
	var fresh := _unroll_cat != cat
	_unroll_cat = cat
	if fresh:
		_unroll.clear()
	for g in Talents.groups_of(cat):
		var gname := str(g[0])
		if gname == Talents.OPEN_GROUP:
			continue
		var want := float(RibbonDrawer.depth(pd, cat, gname))
		var have := float(_unroll.get(gname, -1.0))
		if fresh or have < 0.0 or not is_instance_valid(_talent_canvas):
			_unroll[gname] = want
		elif not is_equal_approx(have, want):
			var canvas := _talent_canvas
			canvas.create_tween().tween_method(func(v: float):
				_unroll[gname] = v
				if is_instance_valid(canvas):
					canvas.queue_redraw(), have, want, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

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
	var wax: Control = b.get_node_or_null("Wax")
	var rank_l: Label = b.get_node_or_null("Rank")
	if wax:
		# The ribbon layout: the seal shows it all (RibbonDrawer.draw_seal).
		# Only a seal whose state changed is redrawn (the icon never needs it: dimming is modulate).
		var seal := {"rank": rank, "max": max_rank, "open": unlocked, "linked": linked,
			"bead": Talents.group_of(id) == Talents.OPEN_GROUP, "choice": Talents.is_choice_slot(id) and rank <= 0}
		if seal != b.get_meta("seal", {}):
			b.set_meta("seal", seal)
			wax.queue_redraw()
			b.get_node("RankTab").queue_redraw()
		var seal_icon: Control = b.get_node_or_null("Icon")
		if seal_icon:
			seal_icon.modulate = Color.WHITE if rank > 0 else Color(0.5, 0.5, 0.5, 0.6)   # no points: grayed, even if open
	elif rank_l:
		b.text = ""
		rank_l.text = "%d/%d" % [rank, max_rank]
		rank_l.add_theme_font_size_override("font_size", 10 if T_BTN >= 36.0 else 8)
		var icon: Control = b.get_node("Icon")
		icon.modulate = Color.WHITE if unlocked else Color(0.45, 0.45, 0.45, 0.8)   # grayed while locked
	else:
		b.text = "%d/%d" % [rank, max_rank]
	if not wax:
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
	# Tooltips are slow to build, so only the hovered one is rebuilt here; the
	# rest are built when the mouse enters them (_make_talent_button).
	if b.is_hovered():
		b.tooltip_text = _talent_tooltip(id, pd)

## A talent button's tooltip: the talent at its current rank, plus what still
## keeps it shut.
func _talent_tooltip(id: String, pd: Node) -> String:
	var t := Talents.get_talent(id)
	var need := Talents.required_ability(id)
	var missing: bool = need != "" and not pd.has_ability(need)
	var unlocked: bool = pd.talent_unlocked(id) and not missing
	var req := ""
	if unlocked and not pd.tier_unlocked(int(t["tier"])):
		req = "\nUnlocked by a maxed linked talent"
	elif not pd.talent_unlocked(id):
		req = "\nRequires %d points in row %d (any book)" % [Talents.POINTS_TO_UNLOCK_NEXT, int(t["tier"])]
		if not Talents.sources_of(id).is_empty():
			req += " or a maxed linked talent"
	if missing:
		req += "\nYou have not learned %s: points can't be spent here yet" % Abilities.ability_name(need)
	return Talents.tooltip(id, pd.talent_rank(id)) + req
