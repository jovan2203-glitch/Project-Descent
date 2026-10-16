extends "res://scripts/menu/menu_part.gd"
class_name CharacterPage

# Moved out of scripts/main_menu.gd as it was (menu = the menu node). Hooked up from
# main_menu.gd through its var "character_page".
# --- Part: Character page: gear, runes panel, stats, attributes, level lock, prestige, Alt popup --------
var _hovered_slot := ""
var _hovered_btn: Button
var _alt_popup: PanelContainer
var _runes_col: VBoxContainer
var _runes_panel: PanelContainer
var _known_runes_shown: Array = []
var _menu_stat_panel: PanelContainer
# Rebuild the Runes dropdown when the set of learned runes changes.
func _rebuild_runes_panel() -> void:
	var pd := menu.get_node("/root/PlayerData")
	if _runes_panel and Array(pd.known_runes) == _known_runes_shown:
		return
	_known_runes_shown = Array(pd.known_runes)
	var idx := 0
	if _runes_panel:
		idx = _runes_panel.get_index()
		_runes_panel.queue_free()
	_runes_panel = UI.runes_panel(180, 130, pd.known_runes)
	_runes_col.add_child(_runes_panel)
	_runes_col.move_child(_runes_panel, idx)

# Base stats + gear + talents + level (no buffs), resolved like in game.
func _refresh_menu_stats() -> void:
	var Stats = preload("res://scripts/core/stats.gd")
	var totals: Dictionary = menu.get_node("/root/PlayerData").total_stats()
	var values := {}
	for stat in Stats.ORDER:
		values[stat] = Stats.from_totals(stat, totals)
	UI.update_stat_panel(_menu_stat_panel, values)

var _attr_points_label: Label
var _attr_rows := {}   # stat -> {"value": Label, "minus": Button, "plus": Button}

func _build_attribute_panel() -> PanelContainer:
	var Stats = preload("res://scripts/core/stats.gd")
	var pd := menu.get_node("/root/PlayerData")
	var p := PanelContainer.new()
	var sb := UI.box(UI.PANEL_BG, UI.BORDER, 2, 8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	var head := HBoxContainer.new()
	var title := UI.label("Attributes", 15, UI.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var reset := UI.button("Reset", 12, Vector2(0, 22))
	reset.tooltip_text = "Refund all attribute points"
	reset.pressed.connect(func(): pd.reset_attributes())
	head.add_child(reset)
	v.add_child(head)
	_attr_points_label = UI.label("", 12, UI.TEXT_DIM)
	v.add_child(_attr_points_label)
	for s in pd.ATTRIBUTE_ORDER:
		var stat: String = s
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var name_l := UI.label(Stats.label(stat).replace("Max ", ""), 13, Color(0.9, 0.9, 0.92))
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.set_meta("tip_text", "%s\n%s per point" % [Stats.describe(stat), Stats.bonus_line(stat, pd.attribute_value(stat))])
		name_l.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(name_l)
		var minus := UI.button("-", 13, Vector2(24, 22))
		minus.pressed.connect(func(): menu._toast_if(pd.remove_attribute_point(stat)))
		row.add_child(minus)
		var value := UI.label("0", 13, Color.WHITE)
		value.custom_minimum_size = Vector2(26, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(value)
		var plus := UI.button("+", 13, Vector2(24, 22))
		plus.pressed.connect(func(): menu._toast_if(pd.add_attribute_point(stat)))
		row.add_child(plus)
		v.add_child(row)
		_attr_rows[stat] = {"value": value, "minus": minus, "plus": plus}
	return p

func _refresh_attributes() -> void:
	var pd := menu.get_node("/root/PlayerData")
	var left: int = pd.attribute_points_left()
	_attr_points_label.text = "Points: %d / %d unspent" % [left, pd.attribute_points_total()]
	_attr_points_label.add_theme_color_override("font_color", UI.ACCENT if left > 0 else UI.TEXT_DIM)
	for s in _attr_rows:
		var r: Dictionary = _attr_rows[s]
		(r["value"] as Label).text = str(pd.attribute_rank(s))
		(r["minus"] as Button).disabled = pd.attribute_rank(s) <= 0
		(r["plus"] as Button).disabled = left <= 0

func _wire_gear() -> void:
	# Runes dropdown at the right edge of the Character tab.
	var pd := menu.get_node("/root/PlayerData")
	# Right-hand column: Runes dropdown, Rune Transfer button, Attributes. It
	# scrolls instead of running into the XP bar / other panels on short screens.
	var right := ScrollContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_bottom = 1.0
	right.offset_left = -216
	right.offset_right = -12
	right.offset_top = 52
	right.offset_bottom = -34
	right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.pages["Character"].add_child(right)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.custom_minimum_size = Vector2(188, 0)
	col.add_theme_constant_override("separation", 8)
	right.add_child(col)
	_runes_col = col
	_rebuild_runes_panel()
	# Rune Management: every rune (craft unknown ones with Rune Shards), engrave
	# runes onto equipped items, and Rune Transfer - all in one window.
	var rm := UI.button("Rune Management", 15, Vector2(0, 34))
	rm.tooltip_text = "See every rune, craft new ones with Rune Shards,\nengrave runes onto your gear and transfer runes between items."
	rm.pressed.connect(func(): RuneManager.open(menu.ui))
	col.add_child(rm)
	menu._shards_label = UI.label("", 13, Color(0.8, 0.6, 1.0))
	menu._shards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(menu._shards_label)
	# Connect a method (not a lambda) so Godot drops the connection when the menu is
	# freed — a lambda on the PlayerData autoload outlives the menu and crashed on death.
	pd.changed_late.connect(menu._refresh_shards)
	menu._refresh_shards()
	col.add_child(_build_attribute_panel())
	pd.changed_late.connect(_refresh_attributes)
	_refresh_attributes()
	# Stats get their own column on the left edge (it used to sit under the
	# attributes and ran off the screen / over the other panels).
	var left := ScrollContainer.new()
	left.anchor_bottom = 1.0
	left.offset_left = 12
	left.offset_right = 244
	left.offset_top = 52
	left.offset_bottom = -34
	left.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.pages["Character"].add_child(left)
	_menu_stat_panel = UI.stat_panel(220)
	_menu_stat_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_menu_stat_panel)
	pd.changed_late.connect(_refresh_menu_stats)
	pd.changed_late.connect(_rebuild_runes_panel)
	_refresh_menu_stats()

	for b in menu.pages["Character"].find_children("*", "Button", true, false):
		if not b.has_meta("slot_name"):
			continue
		var slot := str(b.get_meta("slot_name"))
		b.set_drag_forwarding(
			func(_pos): return null,
			func(_pos, data): return data is Dictionary and data.get("type") == "rune",
			func(_pos, data): menu._toast_if(pd.apply_rune(slot, data["id"])))
		b.button_mask = MOUSE_BUTTON_MASK_RIGHT
		b.pressed.connect(func(): menu._toast_if(menu.get_node("/root/PlayerData").unequip_to_bank(slot)))
		b.mouse_entered.connect(func():
			_hovered_slot = slot
			_hovered_btn = b
			if Input.is_key_pressed(KEY_ALT):
				_open_alt_popup())
		b.mouse_exited.connect(func():
			if _hovered_slot == slot:
				_hovered_slot = ""
				_hovered_btn = null)

## Character tab: gear slots glow while a rune (or item) that fits them is dragged.
var _gear_glow_on := false
var _gear_slot_buttons: Array = []

func _update_gear_highlights() -> void:
	var active: bool = menu.pages.has("Character") and menu.pages["Character"].visible and menu.get_viewport().gui_is_dragging()
	if not active and not _gear_glow_on:
		return
	_gear_glow_on = active
	if _gear_slot_buttons.is_empty():
		for b in menu.pages["Character"].find_children("*", "Button", true, false):
			if b.has_meta("slot_name"):
				_gear_slot_buttons.append(b)
	if active:
		UI.highlight_drag_targets(menu.get_viewport(), _gear_slot_buttons, menu.get_node("/root/PlayerData"))
	else:
		for b in _gear_slot_buttons:
			UI.set_slot_highlight(b, false)

func _open_alt_popup() -> void:
	if _hovered_btn == null:
		return
	var pd := menu.get_node("/root/PlayerData")
	if _alt_popup == null:
		_alt_popup = PanelContainer.new()
		var sb := UI.box(UI.PANEL_BG, UI.ACCENT.darkened(0.3), 2, 8)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 6
		sb.content_margin_bottom = 8
		_alt_popup.add_theme_stylebox_override("panel", sb)
		menu.ui.add_child(_alt_popup)
	_alt_popup_btn = _hovered_btn
	_alt_grace = ALT_GRACE
	for c in _alt_popup.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_alt_popup.add_child(v)
	v.add_child(UI.label("Bank: %s" % _hovered_slot, 15, UI.ACCENT))

	var slot := _hovered_slot
	var indices: Array[int] = pd.bank_items_for_slot(slot)
	if pd.is_slot_locked(slot):
		v.add_child(UI.label("Locked by a two-handed weapon", 13, UI.TEXT_DIM))
	elif indices.is_empty():
		v.add_child(UI.label("No matching items in your bank", 13, UI.TEXT_DIM))
	else:
		for idx in indices:
			var id: String = pd.bank[idx]
			var row := UI.button("", 14, Vector2(220, 40))
			row.alignment = HORIZONTAL_ALIGNMENT_LEFT
			row.text = "          " + Items.item_name(id)
			row.set_meta("tip_item", id)   # ItemTooltip (Shift compares with equipped)
			var icon_slot := UI.slot(32, "")
			icon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_slot.position = Vector2(4, 4)
			UI.set_slot_item(icon_slot, id)
			row.add_child(icon_slot)
			row.pressed.connect(func():
				menu._toast_if(pd.equip_from_bank(idx, slot))   # into the hovered slot (rings / trinkets)
				_alt_popup.hide())
			v.add_child(row)

	var r := _hovered_btn.get_global_rect()
	_alt_popup.visible = true
	_alt_popup.move_to_front()
	_alt_popup.reset_size()
	var sz := _alt_popup.get_combined_minimum_size()
	var vp := menu.get_viewport().get_visible_rect().size
	var pos := Vector2(r.end.x + 2, r.position.y)
	if pos.x + sz.x > vp.x:
		pos.x = r.position.x - sz.x - 2
	pos.y = clampf(pos.y, 0.0, vp.y - sz.y)
	_alt_popup.position = pos

# The Alt popup only stays open while the mouse is over its gear slot or the
# popup itself (short grace period to cross the gap between them).
const ALT_GRACE := 0.15
var _alt_popup_btn: Button
var _alt_grace := 0.0

# Show equipped items in the Character tab's gear squares.
func _refresh_gear() -> void:
	var pd := menu.get_node("/root/PlayerData")
	for b in menu.pages["Character"].find_children("*", "Button", true, false):
		if b.has_meta("slot_name"):
			var slot := str(b.get_meta("slot_name"))
			UI.set_slot_item(b, pd.equipment.get(slot, ""), pd.is_slot_locked(slot), false, pd.gear_runes.get(slot, ""))

# Character: player in the middle, gear slots down each side.
func _build_character() -> Control:
	var page := menu._full_rect_page()
	page.add_child(_gear_column(MainMenu.LEFT_GEAR, true))
	page.add_child(_gear_column(MainMenu.RIGHT_GEAR, false))
	page.add_child(_weapon_row())
	page.add_child(_level_lock_row())
	return page

# Level lock: [Level N  •  Level lock: Off 10 20 30 40 50]. Dying drops you to the
# locked level instead of 1 and keeps gear you can still wear there.
var _lock_buttons := {}   # lock level (0 = off) -> Button
var _lock_level_label: Label

func _level_lock_row() -> Control:
	var row := HBoxContainer.new()
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.offset_left = -330
	row.offset_right = 330
	row.offset_top = 76
	row.offset_bottom = 110
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	var pd := menu.get_node("/root/PlayerData")
	_lock_level_label = menu._label("", 17, Color.WHITE)
	_lock_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_lock_level_label)
	var tip := "Level lock: when you die you drop back to this level instead of level 1, and keep equipped gear you can still wear at it. Unlocked every %d levels." % pd.LEVEL_LOCK_STEP
	var title := menu._label("   Level lock:", 15, MainMenu.C_TEXT_DIM)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.tooltip_text = tip
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(title)
	var lv := 0
	while lv <= pd.MAX_LEVEL:
		var value := lv
		var b := UI.button("Off" if lv == 0 else str(lv), 14, Vector2(46, 30))
		b.tooltip_text = tip
		b.pressed.connect(func(): menu._toast_if(pd.set_level_lock(value)))
		row.add_child(b)
		_lock_buttons[lv] = b
		lv += pd.LEVEL_LOCK_STEP
	# Prestige: back to level 1 with only the starter abilities.
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(14, 0)
	row.add_child(gap)
	var prestige := UI.button("Prestige", 14, Vector2(90, 30))
	prestige.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	prestige.tooltip_text = "Start over at level 1: forget every learned ability except the starter ones everyone has.\nYour bank, runes and Skill Cards are kept."
	prestige.pressed.connect(_open_prestige)
	row.add_child(prestige)
	pd.changed_late.connect(_refresh_level_lock)
	_refresh_level_lock.call_deferred()
	row.offset_left -= 60
	row.offset_right += 60
	return row

var _prestige_panel: PanelContainer
var _prestige_shade: ColorRect

func _open_prestige() -> void:
	if _prestige_panel == null:
		_prestige_shade = ColorRect.new()
		_prestige_shade.color = Color(0, 0, 0, 0.5)
		_prestige_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		menu.ui.add_child(_prestige_shade)
		_prestige_panel = UI.small_panel("Prestige?")
		_prestige_panel.offset_left = -240
		_prestige_panel.offset_right = 240
		_prestige_panel.offset_top = -150
		_prestige_panel.offset_bottom = 150
		var c: VBoxContainer = _prestige_panel.get_meta("content")
		var warn := UI.label("You go back to level 1 and forget every ability you've learned, except the starter ones everyone begins with.\n\nTalent and attribute points are refunded, the level lock is cleared, and gear you can't wear at level 1 goes to your bank.\n\nYour bank, runes, Rune Shards and Skill Cards are kept.", 14, Color(0.9, 0.9, 0.92))
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn.custom_minimum_size = Vector2(400, 0)
		c.add_child(warn)
		var r := HBoxContainer.new()
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		r.add_theme_constant_override("separation", 10)
		c.add_child(r)
		var yes := UI.button("Prestige", 18, Vector2(160, 42))
		yes.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
		yes.pressed.connect(func():
			var d: Dictionary = menu.get_node("/root/PlayerData").prestige()
			_close_prestige()
			var msg := "Prestiged: level %d -> 1, %d abilities forgotten." % [int(d["old_level"]), int(d["forgotten"])]
			if not d["moved"].is_empty():
				msg += " Moved to bank: %s." % ", ".join(d["moved"])
			if not d["stuck"].is_empty():
				msg += " Bank and bag full - still equipped: %s." % ", ".join(d["stuck"])
			menu._toast_if(msg))
		r.add_child(yes)
		var no := UI.button("Cancel", 18, Vector2(120, 42))
		no.pressed.connect(_close_prestige)
		r.add_child(no)
		menu.ui.add_child(_prestige_panel)
	_prestige_shade.visible = true
	_prestige_panel.visible = true
	_prestige_shade.move_to_front()
	_prestige_panel.move_to_front()

func _close_prestige() -> void:
	if _prestige_panel:
		_prestige_panel.visible = false
		_prestige_shade.visible = false

func _refresh_level_lock() -> void:
	var pd := menu.get_node("/root/PlayerData")
	_lock_level_label.text = "Level %d" % pd.level
	for lv in _lock_buttons:
		var b: Button = _lock_buttons[lv]
		var on: bool = int(pd.level_lock) == int(lv)
		b.disabled = int(lv) > int(pd.level)
		b.add_theme_stylebox_override("normal", menu._box(MainMenu.C_ACCENT.darkened(0.45) if on else MainMenu.C_BG, MainMenu.C_ACCENT if on else MainMenu.C_BORDER, 2, 6))

# Weapon slots centered under the character: [Main Hand label][sq]  [sq][Off Hand label]
func _weapon_row() -> Control:
	var row := HBoxContainer.new()
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = -300
	row.offset_right = 300
	row.offset_top = -96
	row.offset_bottom = -26
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var main_l := menu._label(MainMenu.WEAPON_SLOTS[0], 17, Color.WHITE)
	main_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(main_l)
	row.add_child(_gear_square(MainMenu.WEAPON_SLOTS[0]))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(8, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	row.add_child(_gear_square(MainMenu.WEAPON_SLOTS[1]))
	var off_l := menu._label(MainMenu.WEAPON_SLOTS[1], 17, Color.WHITE)
	off_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(off_l)
	return row

func _gear_square(slot_name: String) -> Button:
	var square := Button.new()
	square.custom_minimum_size = Vector2(66, 66)
	square.tooltip_text = "%s (empty)" % slot_name
	square.set_meta("slot_name", slot_name)
	square.focus_mode = Control.FOCUS_NONE
	var border := MainMenu.C_ACCENT.darkened(0.3) if slot_name in MainMenu.COSMETIC_SLOTS else MainMenu.C_BORDER
	square.add_theme_stylebox_override("normal", menu._box(MainMenu.C_BG, border, 2, 6))
	square.add_theme_stylebox_override("hover", menu._box(Color(0.12, 0.12, 0.15, 0.9), MainMenu.C_ACCENT, 2, 6))
	square.add_theme_stylebox_override("pressed", menu._box(Color(0.12, 0.12, 0.15, 0.9), MainMenu.C_ACCENT, 2, 6))
	square.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return square

func _gear_column(slots: Array, left_side: bool) -> Control:
	var col := VBoxContainer.new()
	col.anchor_left = 0.5
	col.anchor_right = 0.5
	col.anchor_top = 0.5
	col.anchor_bottom = 0.5
	col.offset_top = -250
	col.offset_bottom = 290
	if left_side:
		col.offset_left = -170 - 240
		col.offset_right = -170
	else:
		col.offset_left = 170
		col.offset_right = 170 + 240
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for slot_name in slots:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END if left_side else BoxContainer.ALIGNMENT_BEGIN
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var text: String = slot_name
		var labels := VBoxContainer.new()
		labels.alignment = BoxContainer.ALIGNMENT_CENTER
		labels.add_theme_constant_override("separation", 0)
		var name_l := menu._label(text, 17, Color.WHITE)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if left_side else HORIZONTAL_ALIGNMENT_LEFT
		labels.add_child(name_l)
		if slot_name in MainMenu.COSMETIC_SLOTS:
			var tag := menu._label("Cosmetic", 13, MainMenu.C_ACCENT)
			tag.horizontal_alignment = name_l.horizontal_alignment
			labels.add_child(tag)

		var square := Button.new()
		square.custom_minimum_size = Vector2(66, 66)
		square.tooltip_text = "%s (empty)" % slot_name
		square.set_meta("slot_name", slot_name)
		square.focus_mode = Control.FOCUS_NONE
		var border := MainMenu.C_ACCENT.darkened(0.3) if slot_name in MainMenu.COSMETIC_SLOTS else MainMenu.C_BORDER
		square.add_theme_stylebox_override("normal", menu._box(MainMenu.C_BG, border, 2, 6))
		square.add_theme_stylebox_override("hover", menu._box(Color(0.12, 0.12, 0.15, 0.9), MainMenu.C_ACCENT, 2, 6))
		square.add_theme_stylebox_override("pressed", menu._box(Color(0.12, 0.12, 0.15, 0.9), MainMenu.C_ACCENT, 2, 6))
		square.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

		if left_side:
			row.add_child(labels)
			row.add_child(square)
		else:
			row.add_child(square)
			row.add_child(labels)
		col.add_child(row)
	return col

