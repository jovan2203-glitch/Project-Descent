extends RefCounted

# Shared UI builders so the main menu and in-game UI look the same.
# Usage: const UI = preload("res://scripts/ui_kit.gd")  ->  UI.label(...)

const ACCENT := Color(0.95, 0.75, 0.35)
const BG := Color(0.07, 0.075, 0.1, 0.85)
const PANEL_BG := Color(0.05, 0.055, 0.075, 0.96)
const BORDER := Color(0.35, 0.33, 0.3)
const TEXT_DIM := Color(0.65, 0.65, 0.7)
## Frame around item slots holding a runed item.
const RUNE_FRAME := Color(0.78, 0.42, 1.0)

const BANK_SLOTS := 300

const LEFT_GEAR := ["Head", "Neck", "Shoulder", "Back", "Chest", "Gloves"]
const RIGHT_GEAR := ["Legs", "Boots", "Finger 1", "Finger 2", "Trinket 1", "Trinket 2"]
const WEAPON_SLOTS := ["Main Hand", "Off Hand"]
const COSMETIC_SLOTS := ["Back"]

# borders: [left, top, right, bottom] widths; overrides `border` when given.
static func box(bg: Color, border_color: Color, border: int, radius: int, borders: Array = []) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border_color
	if borders.size() == 4:
		sb.border_width_left = borders[0]
		sb.border_width_top = borders[1]
		sb.border_width_right = borders[2]
		sb.border_width_bottom = borders[3]
	else:
		sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

static func label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# Standard menu button. focus_mode NONE so Space/Enter never "clicks" it
# while you're playing (Space is jump).
static func button(text: String, font_size: int = 17, min_size: Vector2 = Vector2(0, 38)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	b.add_theme_color_override("font_hover_pressed_color", ACCENT)
	b.add_theme_stylebox_override("normal", box(BG, BORDER, 1, 6))
	b.add_theme_stylebox_override("hover", box(Color(0.12, 0.12, 0.15, 0.95), ACCENT, 1, 6))
	b.add_theme_stylebox_override("pressed", box(Color(0.12, 0.12, 0.15, 0.95), ACCENT, 2, 6))
	b.add_theme_stylebox_override("hover_pressed", box(Color(0.14, 0.14, 0.17, 0.95), ACCENT, 2, 6))
	return b

static func slot(size: float, tooltip: String, cosmetic: bool = false) -> Button:
	var s := Button.new()
	s.focus_mode = Control.FOCUS_NONE
	s.custom_minimum_size = Vector2(size, size)
	s.tooltip_text = tooltip
	var border := ACCENT.darkened(0.3) if cosmetic else BORDER
	s.add_theme_stylebox_override("normal", box(BG, border, 2, 5))
	s.add_theme_stylebox_override("hover", box(Color(0.12, 0.12, 0.15, 0.9), ACCENT, 2, 5))
	s.add_theme_stylebox_override("pressed", box(Color(0.12, 0.12, 0.15, 0.9), ACCENT, 2, 5))
	s.add_theme_stylebox_override("disabled", box(Color(0.06, 0.065, 0.085, 0.7), border.darkened(0.3), 2, 5))
	return s

# Simple fixed-size grid of item slots (e.g. inventory).
static func item_grid(count: int, columns: int, slot_size: float, name: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(label("Slots used: 0 / %d" % count, 13, TEXT_DIM))
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	for i in count:
		var s := slot(slot_size, "%s slot %d (empty)" % [name, i + 1])
		s.set_meta("inv_index", i)
		s.set_meta("empty_tip", s.tooltip_text)
		grid.add_child(s)
	return v

# --- Item display in slots ------------------------------------------------------

const Items = preload("res://scripts/items.gd")

# Show `id` (or nothing if "") in a slot button: icon + tooltip.
const Runes = preload("res://scripts/runes.gd")

static func set_slot_item(btn: Button, id: String, locked: bool = false, selected: bool = false, rune: String = "") -> void:
	var icon: Control = btn.get_node_or_null("ItemIcon")
	if icon == null:
		icon = Control.new()
		icon.name = "ItemIcon"
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.draw.connect(func():
			var iid := str(icon.get_meta("item_id", ""))
			draw_item_icon(icon, iid, bool(icon.get_meta("locked", false)))
			# Rarity border (Uncommon and better).
			if iid != "" and Items.rarity_of(iid) > 0:
				icon.draw_rect(Rect2(Vector2(3, 3), icon.size - Vector2(6, 6)), Items.rarity_color(iid), false, 2.0)
			# Runed items: a purple outer frame (no corner glyph).
			if str(icon.get_meta("rune", "")) != "":
				icon.draw_rect(Rect2(Vector2(0.5, 0.5), icon.size - Vector2(1, 1)), RUNE_FRAME, false, 2.0)
				icon.draw_rect(Rect2(Vector2(-1.5, -1.5), icon.size + Vector2(3, 3)), Color(RUNE_FRAME, 0.35), false, 2.0)
			if icon.get_meta("selected", false):
				icon.draw_rect(Rect2(Vector2(1, 1), icon.size - Vector2(2, 2)), ACCENT, false, 3.0))
		btn.add_child(icon)
	icon.set_meta("item_id", id)
	icon.set_meta("locked", locked)
	icon.set_meta("selected", selected)
	# Items with a rune ("sword|frost") show their rune glyph automatically.
	if rune == "":
		rune = Items.rune_of(id)
	icon.set_meta("rune", rune if id != "" else "")
	icon.queue_redraw()
	var empty_tip: String = btn.get_meta("empty_tip", btn.tooltip_text)
	if not btn.has_meta("empty_tip"):
		btn.set_meta("empty_tip", empty_tip)
	# Items use the ItemTooltip autoload (rich text, Shift to compare with equipped).
	btn.set_meta("tip_equipped", btn.has_meta("slot_name"))
	if locked:
		btn.tooltip_text = "Off Hand\nLocked by a two-handed weapon"
		btn.remove_meta("tip_item")
	elif id != "":
		btn.tooltip_text = ""
		btn.set_meta("tip_item", id)
	else:
		btn.tooltip_text = empty_tip
		btn.remove_meta("tip_item")

# --- Stat panel ------------------------------------------------------------------------
# Shows final stat values. `values` = {stat: total}. Base values (10 HP, 5% crit)
# should already be included by the caller.

const Stats = preload("res://scripts/core/stats.gd")
const STAT_ORDER := Stats.ORDER

static func stat_panel(width: float = 0.0) -> PanelContainer:
	var p := PanelContainer.new()
	if width > 0.0:
		p.custom_minimum_size = Vector2(width, 0)
	var sb := box(PANEL_BG, BORDER, 2, 8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	v.add_child(label("Stats", 15, ACCENT))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 1)
	v.add_child(rows)
	p.set_meta("rows", rows)
	return p

static func update_stat_panel(p: PanelContainer, values: Dictionary, bonus: Dictionary = {}) -> void:
	var rows: VBoxContainer = p.get_meta("rows")
	for c in rows.get_children():
		c.queue_free()
	for stat in STAT_ORDER:
		var v := float(values.get(stat, 0.0))
		var text := Stats.panel_line(stat, v)
		var extra := float(bonus.get(stat, 0.0))
		var col := Color(0.55, 1.0, 0.55) if extra > 0.0 else Color(0.9, 0.9, 0.92)
		var l := label(text, 13, col)
		if extra > 0.0:
			l.tooltip_text = "Includes +%s from buffs" % _num(extra)
			l.mouse_filter = Control.MOUSE_FILTER_PASS
		rows.add_child(l)

static func _num(v: float) -> String:
	return ("%d" % v) if is_equal_approx(v, round(v)) else ("%.1f" % v)

# Collapsible "Runes" dropdown with a scrollable list of known runes. Each row
# can be dragged ({"type": "rune", "id": ...}) onto a gear slot.
static func runes_panel(width: float, list_height: float, known: Array) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 0)
	var sb := box(PANEL_BG, BORDER, 2, 8)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)

	var header := button("Runes  ▾", 15, Vector2(0, 30))
	v.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, list_height)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	header.pressed.connect(func():
		scroll.visible = not scroll.visible
		header.text = "Runes  ▾" if scroll.visible else "Runes  ▸"
		p.reset_size())

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	if known.is_empty():
		list.add_child(label("No runes known.", 13, TEXT_DIM))
	for rid in known:
		var row := button("", 13, Vector2(0, 34))
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = "       " + Runes.rune_name(rid)
		row.add_theme_color_override("font_color", Runes.rarity_color(rid))
		row.clip_text = true
		row.tooltip_text = Runes.tooltip(rid)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var glyph := Control.new()
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
		glyph.draw.connect(func(): Runes.draw_glyph(glyph, Vector2(17, glyph.size.y / 2.0), 11.0, rid))
		row.add_child(glyph)
		row.set_drag_forwarding(
			func(_pos):
				var prev := Control.new()
				var g := Control.new()
				g.draw.connect(func(): Runes.draw_glyph(g, Vector2.ZERO, 14.0, rid))
				prev.add_child(g)
				row.set_drag_preview(prev)
				return {"type": "rune", "id": rid},
			func(_pos, _data): return false,
			func(_pos, _data): pass)
		list.add_child(row)
	return p

static func draw_item_icon(c: Control, id: String, locked: bool) -> void:
	var s := c.size
	var m := s / 2.0
	var k: float = min(s.x, s.y) / 52.0   # scale drawings to slot size
	if locked:
		c.draw_rect(Rect2(Vector2(3, 3), s - Vector2(6, 6)), Color(0, 0, 0, 0.55), true)
		# padlock
		var body := Rect2(m + Vector2(-9, -2) * k, Vector2(18, 14) * k)
		c.draw_arc(m + Vector2(0, -3) * k, 6.0 * k, PI, TAU, 16, Color(0.6, 0.6, 0.65), 2.5 * k, true)
		c.draw_rect(body, Color(0.6, 0.6, 0.65), true)
		c.draw_circle(m + Vector2(0, 4) * k, 2.0 * k, Color(0.15, 0.15, 0.18))
		return
	if id == "":
		return
	var col: Color = Items.get_item(id).get("color", Color.WHITE)
	var dark := col.darkened(0.45)
	match Items.base_id(id):
		"helmet":
			var pts := PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				pts.append(m + Vector2(cos(a) * 15, sin(a) * 15 + 4) * k)
			pts.append(m + Vector2(15, 10) * k)
			pts.append(m + Vector2(-15, 10) * k)
			c.draw_colored_polygon(pts, col)
			c.draw_line(m + Vector2(-10, 2) * k, m + Vector2(10, 2) * k, dark, 3.0 * k)
			c.draw_line(m + Vector2(0, 2) * k, m + Vector2(0, 9) * k, dark, 2.0 * k)
		"chestplate":
			var pts := PackedVector2Array([
				m + Vector2(-16, -12) * k, m + Vector2(-7, -14) * k, m + Vector2(0, -9) * k,
				m + Vector2(7, -14) * k, m + Vector2(16, -12) * k, m + Vector2(12, 2) * k,
				m + Vector2(10, 15) * k, m + Vector2(-10, 15) * k, m + Vector2(-12, 2) * k])
			c.draw_colored_polygon(pts, col)
			c.draw_line(m + Vector2(0, -8) * k, m + Vector2(0, 14) * k, dark, 2.0 * k)
			c.draw_line(m + Vector2(-9, 3) * k, m + Vector2(9, 3) * k, dark, 1.5 * k)
		"sword":
			var tip := m + Vector2(14, -14) * k
			var guard := m + Vector2(-6, 6) * k
			c.draw_line(guard, tip, col, 4.0 * k, true)
			c.draw_line(m + Vector2(-11, 1) * k, m + Vector2(-1, 11) * k, Color(0.85, 0.7, 0.3), 3.5 * k, true)
			c.draw_line(guard, m + Vector2(-12, 12) * k, Color(0.4, 0.25, 0.15), 3.5 * k, true)
			c.draw_circle(m + Vector2(-13, 13) * k, 2.5 * k, Color(0.85, 0.7, 0.3))
		"bow":
			c.draw_arc(m + Vector2(-8, 0) * k, 17.0 * k, -1.25, 1.25, 20, col, 3.5 * k, true)
			var top := m + Vector2(-8, 0) * k + Vector2(cos(-1.25), sin(-1.25)) * 17.0 * k
			var bot := m + Vector2(-8, 0) * k + Vector2(cos(1.25), sin(1.25)) * 17.0 * k
			c.draw_line(top, bot, Color(0.9, 0.9, 0.85), 1.2 * k, true)
		_:
			c.draw_circle(m, 10.0 * k, col)

# 300-slot bank: counter + scrollable grid. interactable=false shows the bank
# as view-only (slots can be scrolled and hovered but not clicked).
static func bank_grid(columns: int, slot_size: float, visible_height: float, interactable: bool = true) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var text := "Slots used: 0 / %d" % BANK_SLOTS
	if not interactable:
		text += "   (view only)"
	var count := label(text, 13 if not interactable else 14, TEXT_DIM)
	count.set_meta("bank_counter", true)
	count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var header := HBoxContainer.new()
	header.add_child(count)
	if interactable:
		header.add_child(label("Drag here to delete  ", 12, TEXT_DIM))
		header.add_child(trash_can())
	v.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, visible_height)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	for i in BANK_SLOTS:
		var s := slot(slot_size, "Bank slot %d (empty)" % (i + 1))
		s.disabled = not interactable
		s.set_meta("bank_index", i)
		s.set_meta("empty_tip", s.tooltip_text)
		grid.add_child(s)
	return v

# Trash can drop target (the owner wires up set_drag_forwarding).
static func trash_can() -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(40, 40)
	b.tooltip_text = "Trash\nDrag items here to delete them.\nCtrl+click to select several."
	b.set_meta("trash", true)
	b.add_theme_stylebox_override("normal", box(Color(0.18, 0.06, 0.06, 0.9), Color(0.55, 0.2, 0.2), 2, 6))
	b.add_theme_stylebox_override("hover", box(Color(0.3, 0.08, 0.08, 0.95), Color(0.95, 0.35, 0.3), 2, 6))
	b.add_theme_stylebox_override("pressed", box(Color(0.3, 0.08, 0.08, 0.95), Color(0.95, 0.35, 0.3), 2, 6))
	var icon := Control.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func():
		var m := icon.size / 2.0
		var col := Color(0.9, 0.55, 0.5)
		icon.draw_rect(Rect2(m + Vector2(-8, -6), Vector2(16, 17)), col, false, 2.0)
		icon.draw_line(m + Vector2(-11, -8), m + Vector2(11, -8), col, 2.0)
		icon.draw_line(m + Vector2(-3, -11), m + Vector2(3, -11), col, 2.0)
		for x in [-4.0, 0.0, 4.0]:
			icon.draw_line(m + Vector2(x, -3), m + Vector2(x, 8), col, 1.5))
	b.add_child(icon)
	return b

# --- Right-click item menu + delete confirmation ---------------------------------

## Right-click menu at the mouse: [Equip] [Delete]. `delete_label` lets the
## caller say e.g. "Delete 3 selected items". Delete always asks to confirm.
static func item_menu(host: Node, item: String, on_equip: Callable, on_delete: Callable,
		delete_label: String = "Delete", confirm_text: String = "") -> void:
	var pm := PopupMenu.new()
	pm.add_theme_font_size_override("font_size", 15)
	pm.add_theme_stylebox_override("panel", box(PANEL_BG, BORDER, 2, 6))
	pm.add_theme_color_override("font_hover_color", ACCENT)
	pm.add_item("Equip", 0)
	if str(Items.get_item(item).get("slot", "")) == "":
		pm.set_item_disabled(0, true)
	pm.add_separator()
	pm.add_item(delete_label, 1)
	pm.id_pressed.connect(func(id: int):
		if id == 0:
			on_equip.call()
		elif id == 1:
			var text := confirm_text
			if text == "":
				text = "Delete %s?" % Items.item_name(item)
			confirm(host, text + "\nThis can't be undone.", "Delete", on_delete))
	pm.popup_hide.connect(pm.queue_free)
	host.add_child(pm)
	var mouse := Vector2i(host.get_viewport().get_mouse_position())
	pm.popup(Rect2i(mouse, Vector2i(140, 0)))

## Yes/No confirmation dialog centered on screen.
static func confirm(host: Node, text: String, ok_text: String, on_ok: Callable) -> void:
	var d := ConfirmationDialog.new()
	d.title = "Confirm"
	d.dialog_text = text
	d.ok_button_text = ok_text
	d.cancel_button_text = "Cancel"
	d.confirmed.connect(on_ok)
	d.visibility_changed.connect(func():
		if not d.visible:
			d.queue_free())
	host.add_child(d)
	d.popup_centered(Vector2i(320, 0))

# Small floating preview shown while dragging items.
static func drag_preview(id: String, count: int) -> Control:
	var root := Control.new()
	var s := slot(42, "")
	s.modulate.a = 0.85
	root.add_child(s)
	s.position = Vector2(-21, -21)
	set_slot_item(s, id)
	if count > 1:
		var l := label("x%d" % count, 14, ACCENT)
		l.position = Vector2(12, 8)
		root.add_child(l)
	return root

# Small centered menu panel (Esc menu, Settings). Content via get_meta("content").
static func small_panel(title: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -130
	p.offset_right = 130
	p.offset_top = -130
	p.offset_bottom = 110
	var sb := box(PANEL_BG, BORDER, 2, 10)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var t := label(title, 22, ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	p.set_meta("content", v)
	return p

# Live 3D preview of the player model (idle animation) for UI windows.
static func character_preview(size: Vector2) -> Control:
	var c := SubViewportContainer.new()
	c.stretch = true
	c.custom_minimum_size = size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	c.add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.7)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var model: Node3D = load("res://assets/player/Idle.fbx").instantiate()
	vp.add_child(model)
	var anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if anim and anim.has_animation("mixamo_com"):
		anim.get_animation("mixamo_com").loop_mode = Animation.LOOP_LINEAR
		anim.play("mixamo_com")

	var cam := Camera3D.new()
	cam.fov = 38.0
	cam.transform = Transform3D(Basis(), Vector3(0, 1.0, 3.5)).looking_at(Vector3(0, 0.9, 0))
	vp.add_child(cam)
	cam.current = true

	var key := DirectionalLight3D.new()
	key.light_color = Color(1, 0.9, 0.78)
	key.light_energy = 1.3
	key.transform = Transform3D(Basis(), Vector3(1.5, 2.5, 2.5)).looking_at(Vector3(0, 0.9, 0))
	vp.add_child(key)

	var rim := OmniLight3D.new()
	rim.light_color = Color(0.45, 0.75, 1)
	rim.light_energy = 1.5
	rim.omni_range = 4.0
	rim.position = Vector3(-1.2, 2.0, -1.5)
	vp.add_child(rim)
	return c

# Compact equipment layout (no 3D model) for the in-game Character window.
static func gear_layout(slot_size: float = 52, font: int = 15, col_sep: int = 90, center: Control = null) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)

	var cols := HBoxContainer.new()
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	cols.add_theme_constant_override("separation", col_sep)
	cols.add_child(_gear_column(LEFT_GEAR, true, slot_size, font))
	if center:
		cols.add_child(center)
	cols.add_child(_gear_column(RIGHT_GEAR, false, slot_size, font))
	v.add_child(cols)

	var weapons := HBoxContainer.new()
	weapons.alignment = BoxContainer.ALIGNMENT_CENTER
	weapons.add_theme_constant_override("separation", 8)
	weapons.add_child(label(WEAPON_SLOTS[0], font))
	var mh := slot(slot_size, "Main Hand (empty)")
	mh.set_meta("slot_name", "Main Hand")
	weapons.add_child(mh)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(4, 0)
	weapons.add_child(gap)
	var oh := slot(slot_size, "Off Hand (empty)")
	oh.set_meta("slot_name", "Off Hand")
	weapons.add_child(oh)
	weapons.add_child(label(WEAPON_SLOTS[1], font))
	v.add_child(weapons)
	return v

static func _gear_column(slots: Array, left_side: bool, slot_size: float, font: int) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	for slot_name in slots:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END if left_side else BoxContainer.ALIGNMENT_BEGIN
		row.add_theme_constant_override("separation", 8)
		var cosmetic: bool = slot_name in COSMETIC_SLOTS
		var l := label(slot_name, font, ACCENT if cosmetic else Color.WHITE)
		var tip: String = "%s (cosmetic, empty)" % slot_name if cosmetic else "%s (empty)" % slot_name
		var s := slot(slot_size, tip, cosmetic)
		s.set_meta("slot_name", slot_name)
		if left_side:
			row.add_child(l)
			row.add_child(s)
		else:
			row.add_child(s)
			row.add_child(l)
		col.add_child(row)
	return col

# A titled window panel with a close (X) button. Content goes in the node
# returned by window.get_meta("content").
# draggable=true: top-left anchored, width = size.x, height fits content,
# drag by the title bar, click anywhere to bring to front.
static func window(title: String, size: Vector2, on_close: Callable, draggable: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	if draggable:
		panel.custom_minimum_size = Vector2(size.x, 0)
		panel.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed:
				panel.move_to_front())
	else:
		panel.anchor_left = 0.5
		panel.anchor_right = 0.5
		panel.anchor_top = 0.5
		panel.anchor_bottom = 0.5
		panel.offset_left = -size.x / 2.0
		panel.offset_right = size.x / 2.0
		panel.offset_top = -size.y / 2.0
		panel.offset_bottom = size.y / 2.0
	var sb := box(PANEL_BG, BORDER, 2, 8)
	var m := 10 if draggable else 16
	sb.content_margin_left = m
	sb.content_margin_right = m
	sb.content_margin_top = 8 if draggable else 12
	sb.content_margin_bottom = m
	panel.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8 if draggable else 12)
	panel.add_child(v)

	var header := HBoxContainer.new()
	var t := label(title, 17 if draggable else 22, ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(t)
	var close_size := 26 if draggable else 34
	var close := button("X", 14 if draggable else 16, Vector2(close_size, close_size))
	close.pressed.connect(on_close)
	header.add_child(close)
	v.add_child(header)

	if draggable:
		header.mouse_filter = Control.MOUSE_FILTER_STOP
		header.mouse_default_cursor_shape = Control.CURSOR_MOVE
		header.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
				panel.set_meta("dragging", ev.pressed)
				if ev.pressed:
					panel.move_to_front()
			elif ev is InputEventMouseMotion and panel.get_meta("dragging", false):
				var vp := panel.get_viewport_rect().size
				panel.position = (panel.position + ev.relative).clamp(
					Vector2.ZERO, (vp - panel.size).max(Vector2.ZERO)))

	var content := VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	v.add_child(content)
	panel.set_meta("content", content)
	return panel
