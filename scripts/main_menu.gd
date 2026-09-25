extends Node3D

# Main menu: 3D player on a pedestal with UI layered on top.
# Tabs: Lobby (party slots + Play), Character (gear slots), Abilities & Talents
# (category books), Skill Cards, Bank, Queue.

const UI = preload("res://scripts/ui_kit.gd")
const Items = preload("res://scripts/items.gd")
const Runes = preload("res://scripts/runes.gd")
const Talents = preload("res://scripts/talents.gd")
const GAME_SCENE = "res://node_3d.tscn"
const PARTY_SLOTS = 4
const SOCIAL_PANEL = preload("res://scripts/ui/social_panel.gd")

const LEFT_GEAR = ["Head", "Neck", "Shoulder", "Back", "Chest", "Gloves"]
const RIGHT_GEAR = ["Legs", "Boots", "Finger 1", "Finger 2", "Trinket 1", "Trinket 2"]
const WEAPON_SLOTS = ["Main Hand", "Off Hand"]
const COSMETIC_SLOTS = ["Back"]

const C_BG := Color(0.07, 0.075, 0.1, 0.85)
const C_BORDER := Color(0.35, 0.33, 0.3)
const C_ACCENT := Color(0.95, 0.75, 0.35)
const C_TEXT_DIM := Color(0.65, 0.65, 0.7)

@onready var camera: Camera3D = $Camera3D
@onready var model: Node3D = $PlayerModel

var ui: CanvasLayer
var pages := {}
var nav_buttons := {}
var play_button: Button
var friends_button: Button
var esc_menu: PanelContainer
var settings_panel: PanelContainer
var esc_shade: ColorRect

func _ready() -> void:
	camera.look_at(Vector3(0, 0.95, 0))
	$KeyLight.look_at(Vector3(0, 0.9, 0))
	_play_idle()
	_build_ui()
	_show_page("Lobby")
	_refresh_gear()
	get_node("/root/PlayerData").changed.connect(_refresh_gear)
	_wire_bank()
	_wire_gear()
	# Party / online
	var online := get_node("/root/Online")
	var net := get_node("/root/Net")
	online.changed.connect(_refresh_party)
	net.members_changed.connect(_refresh_party)
	online.toast.connect(_toast_ok)
	net.system_message.connect(_toast_ok)
	_refresh_party()

# --- Party (lobby slots, friends panel, queue status) ------------------------------

var social: PanelContainer
var _party_slots: Array[Button] = []
var _you_label: Label
var _queue_banner: Label

func _toggle_social() -> void:
	social.visible = not social.visible
	if social.visible:
		social.move_to_front()

func _refresh_party() -> void:
	var online := get_node("/root/Online")
	var net := get_node("/root/Net")
	var me := int(online.my_id)
	var others: Array = []
	for id in net.order:
		if int(id) != me:
			others.append(id)
	for i in _party_slots.size():
		var slot := _party_slots[i]
		if i < others.size():
			var info: Dictionary = net.members.get(others[i], {})
			var lead := "★ Leader\n" if int(others[i]) == int(net.host_member) else ""
			slot.text = "%s%s\nLv %d" % [lead, str(info.get("name", "?")), int(info.get("level", 1))]
			slot.add_theme_color_override("font_color", Color.WHITE)
			slot.tooltip_text = str(info.get("name", "?"))
		else:
			slot.text = "+\nInvite"
			slot.add_theme_color_override("font_color", C_TEXT_DIM)
			slot.tooltip_text = "Invite a friend"
	if _you_label:
		var lead := "★ " if net.online and int(net.host_member) == me else ""
		_you_label.text = lead + str(online.my_name)
	if play_button:
		# Everyone can open the Play screen; only the leader can queue / start there.
		play_button.tooltip_text = "Choose a dungeon" if not (net.online and not net.is_host()) \
			else "See where your party is going (only the leader can queue or start)."
	if _queue_cards.size() > 0:
		_refresh_queue()

func _instance_name(key: String) -> String:
	var parts: Array = get_node("/root/GameManager").split_key(key)
	var path: String = parts[0]
	var floor_text := "  (Floor %d)" % int(parts[1]) if int(parts[1]) > 1 else ""
	for inst in INSTANCES:
		if inst["scene"] == path:
			return inst["name"] + floor_text
	return path.get_file().get_basename().capitalize() + floor_text

func _update_queue_banner() -> void:
	if _queue_banner == null:
		return
	var online := get_node("/root/Online")
	if online.queue_instance == "":
		_queue_banner.visible = false
		return
	_queue_banner.visible = true
	var s: int = online.queue_seconds()
	_queue_banner.text = "In queue: %s   •   %d / %d players   •   %d:%02d" % [
		_instance_name(online.queue_instance), online.party_size(), online.max_party(), s / 60, s % 60]

# --- Gear: right-click -> bank, Alt+hover -> pick from bank -----------------------

var _hovered_slot := ""
var _hovered_btn: Button
var _alt_popup: PanelContainer
var _toast_label: Label
var _toast_tween: Tween

var _runes_col: VBoxContainer
var _runes_panel: PanelContainer
var _known_runes_shown: Array = []
var _menu_stat_panel: PanelContainer

# Rebuild the Runes dropdown when the set of learned runes changes.
func _rebuild_runes_panel() -> void:
	var pd := get_node("/root/PlayerData")
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
	var totals: Dictionary = get_node("/root/PlayerData").total_stats()
	var values := {}
	for stat in Stats.ORDER:
		values[stat] = Stats.from_totals(stat, totals)
	UI.update_stat_panel(_menu_stat_panel, values)

# --- Attributes (1 point per level; freely movable here, add-only in game) -----------

var _attr_points_label: Label
var _attr_rows := {}   # stat -> {"value": Label, "minus": Button, "plus": Button}

func _build_attribute_panel() -> PanelContainer:
	var Stats = preload("res://scripts/core/stats.gd")
	var pd := get_node("/root/PlayerData")
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
		name_l.tooltip_text = "%s per point" % Stats.bonus_line(stat, float(pd.ATTRIBUTE_VALUES[stat]))
		name_l.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(name_l)
		var minus := UI.button("-", 13, Vector2(24, 22))
		minus.pressed.connect(func(): _toast_if(pd.remove_attribute_point(stat)))
		row.add_child(minus)
		var value := UI.label("0", 13, Color.WHITE)
		value.custom_minimum_size = Vector2(26, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(value)
		var plus := UI.button("+", 13, Vector2(24, 22))
		plus.pressed.connect(func(): _toast_if(pd.add_attribute_point(stat)))
		row.add_child(plus)
		v.add_child(row)
		_attr_rows[stat] = {"value": value, "minus": minus, "plus": plus}
	return p

func _refresh_attributes() -> void:
	var pd := get_node("/root/PlayerData")
	var left: int = pd.attribute_points_left()
	_attr_points_label.text = "Points: %d / %d unspent" % [left, pd.attribute_points_total()]
	_attr_points_label.add_theme_color_override("font_color", UI.ACCENT if left > 0 else UI.TEXT_DIM)
	for s in _attr_rows:
		var r: Dictionary = _attr_rows[s]
		(r["value"] as Label).text = str(pd.attribute_rank(s))
		(r["minus"] as Button).disabled = pd.attribute_rank(s) <= 0
		(r["plus"] as Button).disabled = left <= 0

# --- Rune Transfer ------------------------------------------------------------------
# Source Item (must be runed) -> Target Item. Transfer: the rune moves to
# the target, is learned permanently, and the source is destroyed.
# Extract: learn the rune and destroy the source (no target needed).

var _et_panel: PanelContainer
var _et_shade: ColorRect
var _et_src := {}
var _et_tgt := {}
var _et_pick := ""          # "src" / "tgt" while choosing from the list
var _et_src_btn: Button
var _et_tgt_btn: Button
var _et_list: VBoxContainer
var _et_list_title: Label

func _open_rune_transfer() -> void:
	if _et_panel == null:
		_build_rune_transfer()
	_et_src = {}
	_et_tgt = {}
	_et_pick = "src"
	_et_shade.visible = true
	_et_panel.visible = true
	_refresh_rune_transfer()

func _close_rune_transfer() -> void:
	_et_panel.visible = false
	_et_shade.visible = false

func _build_rune_transfer() -> void:
	_et_shade = ColorRect.new()
	_et_shade.color = Color(0, 0, 0, 0.5)
	_et_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(_et_shade)

	_et_panel = PanelContainer.new()
	_et_panel.anchor_left = 0.5
	_et_panel.anchor_right = 0.5
	_et_panel.anchor_top = 0.5
	_et_panel.anchor_bottom = 0.5
	_et_panel.offset_left = -260
	_et_panel.offset_right = 260
	_et_panel.offset_top = -230
	_et_panel.offset_bottom = 230
	var sb := UI.box(UI.PANEL_BG, UI.ACCENT.darkened(0.3), 2, 10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 14
	_et_panel.add_theme_stylebox_override("panel", sb)
	ui.add_child(_et_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_et_panel.add_child(v)
	v.add_child(UI.label("Rune Transfer", 22, C_ACCENT))
	var info := UI.label("The rune is learned permanently and the source item is destroyed.", 13, C_TEXT_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)

	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 24)
	v.add_child(slots)
	_et_src_btn = _et_slot_column(slots, "Source Item", "src")
	var arrow := UI.label("→", 30, C_ACCENT)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slots.add_child(arrow)
	_et_tgt_btn = _et_slot_column(slots, "Target Item", "tgt")

	_et_list_title = UI.label("", 14, Color.WHITE)
	v.add_child(_et_list_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 170)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_et_list = VBoxContainer.new()
	_et_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_et_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_et_list)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	v.add_child(buttons)
	var transfer := UI.button("Transfer", 16, Vector2(130, 38))
	transfer.pressed.connect(_do_transfer)
	buttons.add_child(transfer)
	var extract := UI.button("Extract (learn only)", 16, Vector2(170, 38))
	extract.pressed.connect(_do_extract)
	buttons.add_child(extract)
	var close := UI.button("Close", 16, Vector2(90, 38))
	close.pressed.connect(_close_rune_transfer)
	buttons.add_child(close)
	_et_panel.visible = false
	_et_shade.visible = false

func _et_slot_column(parent: Control, title: String, mode: String) -> Button:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var l := UI.label(title, 14, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	var b := UI.slot(66, "Click to choose")
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		_et_pick = mode
		_refresh_rune_transfer())
	col.add_child(b)
	parent.add_child(col)
	return b

func _et_where(ref: Dictionary) -> String:
	if ref.get("where") == "equip":
		return "Equipped (%s)" % ref["slot"]
	return "Bank"

func _refresh_rune_transfer() -> void:
	var pd := get_node("/root/PlayerData")
	# Drop stale selections (item moved/destroyed).
	if not _et_src.is_empty() and Items.rune_of(pd.get_item_at(_et_src)) == "":
		_et_src = {}
	if not _et_tgt.is_empty() and pd.get_item_at(_et_tgt) == "":
		_et_tgt = {}
	UI.set_slot_item(_et_src_btn, pd.get_item_at(_et_src) if not _et_src.is_empty() else "")
	UI.set_slot_item(_et_tgt_btn, pd.get_item_at(_et_tgt) if not _et_tgt.is_empty() else "")
	_et_src_btn.add_theme_stylebox_override("normal", UI.box(UI.BG, C_ACCENT if _et_pick == "src" else UI.BORDER, 2, 5))
	_et_tgt_btn.add_theme_stylebox_override("normal", UI.box(UI.BG, C_ACCENT if _et_pick == "tgt" else UI.BORDER, 2, 5))

	for c in _et_list.get_children():
		c.queue_free()
	var refs: Array[Dictionary] = []
	if _et_pick == "src":
		_et_list_title.text = "Choose a Source Item (with a rune):"
		refs = pd.list_items(1)
	elif _et_pick == "tgt":
		_et_list_title.text = "Choose a Target Item (no rune):"
		refs = pd.list_items(0)
	else:
		_et_list_title.text = "Click a slot to choose an item."
	if _et_pick != "" and refs.is_empty():
		_et_list.add_child(UI.label("No suitable items in your gear or bank.", 13, C_TEXT_DIM))
	for ref in refs:
		var item: String = pd.get_item_at(ref)
		var row := UI.button("", 14, Vector2(0, 40))
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = "          %s   —   %s" % [Items.item_name(item), _et_where(ref)]
		row.set_meta("tip_item", item)
		row.set_meta("tip_equipped", ref.get("where") == "equip")
		var icon := UI.slot(32, "")
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2(4, 4)
		UI.set_slot_item(icon, item)
		row.add_child(icon)
		var mode := _et_pick
		row.pressed.connect(func():
			if mode == "src":
				_et_src = ref
				_et_pick = "tgt" if _et_tgt.is_empty() else ""
			else:
				_et_tgt = ref
				_et_pick = ""
			_refresh_rune_transfer())
		_et_list.add_child(row)

func _do_transfer() -> void:
	var pd := get_node("/root/PlayerData")
	if _et_src.is_empty() or _et_tgt.is_empty():
		_toast_if("Choose a source and a target item")
		return
	var e := Items.rune_of(pd.get_item_at(_et_src))
	var err: String = pd.transfer_rune(_et_src, _et_tgt)
	if err != "":
		_toast_if(err)
		return
	_toast_ok("Learned %s and applied it to %s" % [Runes.rune_name(e), Items.item_name(pd.get_item_at(_et_tgt))])
	_et_src = {}
	_et_pick = "src"
	_refresh_rune_transfer()

func _do_extract() -> void:
	var pd := get_node("/root/PlayerData")
	if _et_src.is_empty():
		_toast_if("Choose a source item")
		return
	var e := Items.rune_of(pd.get_item_at(_et_src))
	var err: String = pd.extract_rune(_et_src)
	if err != "":
		_toast_if(err)
		return
	_toast_ok("Learned %s" % Runes.rune_name(e))
	_et_src = {}
	_et_pick = "src"
	_refresh_rune_transfer()

func _toast_ok(msg: String) -> void:
	_toast_if(msg)
	_toast_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
	_toast_label.move_to_front()

func _wire_gear() -> void:
	# Runes dropdown at the right edge of the Character tab.
	var pd := get_node("/root/PlayerData")
	# Right-hand column: Runes dropdown, Rune Transfer button, Stats.
	var col := VBoxContainer.new()
	col.anchor_left = 1.0
	col.anchor_right = 1.0
	col.offset_left = -196
	col.offset_right = -16
	col.offset_top = 72
	col.add_theme_constant_override("separation", 8)
	pages["Character"].add_child(col)
	_runes_col = col
	_rebuild_runes_panel()
	var et := UI.button("Rune Transfer", 15, Vector2(0, 34))
	et.tooltip_text = "Move a rune from one item to another (the source item is destroyed),\nor extract it to learn the rune permanently."
	et.pressed.connect(_open_rune_transfer)
	col.add_child(et)
	col.add_child(_build_attribute_panel())
	pd.changed.connect(_refresh_attributes)
	_refresh_attributes()
	_menu_stat_panel = UI.stat_panel()
	col.add_child(_menu_stat_panel)
	pd.changed.connect(_refresh_menu_stats)
	pd.changed.connect(_rebuild_runes_panel)
	_refresh_menu_stats()

	for b in pages["Character"].find_children("*", "Button", true, false):
		if not b.has_meta("slot_name"):
			continue
		var slot := str(b.get_meta("slot_name"))
		b.set_drag_forwarding(
			func(_pos): return null,
			func(_pos, data): return data is Dictionary and data.get("type") == "rune",
			func(_pos, data): _toast_if(pd.apply_rune(slot, data["id"])))
		b.button_mask = MOUSE_BUTTON_MASK_RIGHT
		b.pressed.connect(func(): _toast_if(get_node("/root/PlayerData").unequip_to_bank(slot)))
		b.mouse_entered.connect(func():
			_hovered_slot = slot
			_hovered_btn = b
			if Input.is_key_pressed(KEY_ALT):
				_open_alt_popup())
		b.mouse_exited.connect(func():
			if _hovered_slot == slot:
				_hovered_slot = ""
				_hovered_btn = null)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ALT:
		if _hovered_slot != "" and pages["Character"].visible:
			_open_alt_popup()

func _open_alt_popup() -> void:
	if _hovered_btn == null:
		return
	var pd := get_node("/root/PlayerData")
	if _alt_popup == null:
		_alt_popup = PanelContainer.new()
		var sb := UI.box(UI.PANEL_BG, UI.ACCENT.darkened(0.3), 2, 8)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		sb.content_margin_top = 6
		sb.content_margin_bottom = 8
		_alt_popup.add_theme_stylebox_override("panel", sb)
		ui.add_child(_alt_popup)
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
				_toast_if(pd.equip_from_bank(idx, slot))   # into the hovered slot (rings / trinkets)
				_alt_popup.hide())
			v.add_child(row)

	var r := _hovered_btn.get_global_rect()
	_alt_popup.visible = true
	_alt_popup.move_to_front()
	_alt_popup.reset_size()
	var sz := _alt_popup.get_combined_minimum_size()
	var vp := get_viewport().get_visible_rect().size
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

func _process(delta: float) -> void:
	_update_queue_banner()
	_check_bar_drag_end()
	if _alt_popup == null or not _alt_popup.visible:
		return
	var mouse := get_viewport().get_mouse_position()
	var over := _alt_popup.get_global_rect().has_point(mouse)
	if is_instance_valid(_alt_popup_btn) and _alt_popup_btn.is_visible_in_tree():
		over = over or _alt_popup_btn.get_global_rect().has_point(mouse)
	if over:
		_alt_grace = ALT_GRACE
		return
	_alt_grace -= delta
	if _alt_grace <= 0.0:
		_alt_popup.visible = false

func _toast_if(msg: String) -> void:
	if msg == "":
		return
	if _toast_label == null:
		_toast_label = UI.label("", 18, Color(1, 0.35, 0.3))
		_toast_label.anchor_left = 0.5
		_toast_label.anchor_right = 0.5
		_toast_label.anchor_top = 1.0
		_toast_label.anchor_bottom = 1.0
		_toast_label.offset_left = -300
		_toast_label.offset_right = 300
		_toast_label.offset_top = -140
		_toast_label.offset_bottom = -110
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ui.add_child(_toast_label)
	_toast_label.text = msg
	_toast_label.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
	_toast_label.move_to_front()
	_toast_label.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.2)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.5)

# --- Bank: show items, Ctrl+click multi-select, drag to trash --------------------

var _bank_buttons: Array[Button] = []
var _bank_selected := {}     # bank index -> true

func _wire_bank() -> void:
	var pd := get_node("/root/PlayerData")
	for b in pages["Bank"].find_children("*", "Button", true, false):
		if b.has_meta("bank_index"):
			var idx := int(b.get_meta("bank_index"))
			_bank_buttons.append(b)
			b.pressed.connect(_on_bank_clicked.bind(idx))
			# Right-click a bank item: Equip / Delete menu.
			b.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
					_bank_context_menu(idx))
			b.set_drag_forwarding(
				func(_pos): return _bank_drag_data(b, idx),
				func(_pos, data): return data is Dictionary and data.get("type") == "bank",
				func(_pos, data): _move_bank(data["indices"], idx))
		elif b.has_meta("trash"):
			b.set_drag_forwarding(
				func(_pos): return null,
				func(_pos, data): return data is Dictionary and data.get("type") == "bank",
				func(_pos, data): _trash(data["indices"]))
	pd.changed.connect(_refresh_bank)
	_refresh_bank()

func _on_bank_clicked(idx: int) -> void:
	var pd := get_node("/root/PlayerData")
	if Input.is_key_pressed(KEY_CTRL):
		if _bank_selected.has(idx):
			_bank_selected.erase(idx)
		elif pd.bank[idx] != "":
			_bank_selected[idx] = true
	else:
		_bank_selected.clear()
		if pd.bank[idx] != "":
			_bank_selected[idx] = true
	_refresh_bank()

func _bank_drag_data(btn: Button, idx: int) -> Variant:
	var pd := get_node("/root/PlayerData")
	if pd.bank[idx] == "":
		return null
	var indices: Array = []
	if _bank_selected.has(idx):
		indices = _bank_selected.keys()
	else:
		indices = [idx]
	btn.set_drag_preview(UI.drag_preview(pd.bank[idx], indices.size()))
	return {"type": "bank", "indices": indices}

func _move_bank(indices: Array, to: int) -> void:
	var moved: Array[int] = get_node("/root/PlayerData").move_bank_items(indices, to)
	# Keep a multi-selection on the items that moved.
	_bank_selected.clear()
	if moved.size() > 1:
		for i in moved:
			_bank_selected[i] = true
	_refresh_bank()

func _bank_context_menu(idx: int) -> void:
	var pd := get_node("/root/PlayerData")
	var id: String = pd.bank[idx]
	if id == "":
		return
	# Right-clicking part of a multi-selection offers to delete the whole selection.
	var targets: Array = [idx]
	if _bank_selected.has(idx) and _bank_selected.size() > 1:
		targets = _bank_selected.keys()
	else:
		_bank_selected.clear()
		_bank_selected[idx] = true
		_refresh_bank()
	var n := targets.size()
	UI.item_menu(ui, id,
		func():
			_bank_selected.clear()
			_toast_if(pd.equip_from_bank(idx))
			_refresh_bank(),
		func(): _trash(targets),
		"Delete" if n == 1 else "Delete %d selected items" % n,
		"" if n == 1 else "Delete %d selected items?" % n)

func _trash(indices: Array) -> void:
	get_node("/root/PlayerData").delete_bank_items(indices)
	_bank_selected.clear()
	_refresh_bank()

func _refresh_bank() -> void:
	var pd := get_node("/root/PlayerData")
	var used := 0
	for b in _bank_buttons:
		var idx := int(b.get_meta("bank_index"))
		var id: String = pd.bank[idx]
		if id == "":
			_bank_selected.erase(idx)
		else:
			used += 1
		UI.set_slot_item(b, id, false, _bank_selected.has(idx))
	for l in pages["Bank"].find_children("*", "Label", true, false):
		if l.has_meta("bank_counter"):
			l.text = "Slots used: %d / %d" % [used, pd.BANK_SIZE]

# Show equipped items in the Character tab's gear squares.
func _refresh_gear() -> void:
	var pd := get_node("/root/PlayerData")
	for b in pages["Character"].find_children("*", "Button", true, false):
		if b.has_meta("slot_name"):
			var slot := str(b.get_meta("slot_name"))
			UI.set_slot_item(b, pd.equipment.get(slot, ""), pd.is_slot_locked(slot), false, pd.gear_runes.get(slot, ""))

func _play_idle() -> void:
	var anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if anim and anim.has_animation("mixamo_com"):
		anim.get_animation("mixamo_com").loop_mode = Animation.LOOP_LINEAR
		anim.play("mixamo_com")

# --- UI construction ---------------------------------------------------------

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	pages["Lobby"] = _build_lobby()
	pages["Character"] = _build_character()
	pages["Abilities & Talents"] = _build_abilities_page()
	pages["Skill Cards"] = _build_cards_page()
	pages["Bank"] = _build_bank_page()
	pages["Queue"] = _build_queue_page()
	for p in pages.values():
		ui.add_child(p)

	_build_nav_bar()

	play_button = Button.new()
	play_button.text = "PLAY"
	play_button.anchor_left = 1.0
	play_button.anchor_right = 1.0
	play_button.anchor_top = 1.0
	play_button.anchor_bottom = 1.0
	play_button.offset_left = -250
	play_button.offset_right = -30
	play_button.offset_top = -100
	play_button.offset_bottom = -30
	play_button.add_theme_font_size_override("font_size", 30)
	play_button.add_theme_color_override("font_color", Color(0.1, 0.07, 0.03))
	play_button.add_theme_color_override("font_hover_color", Color(0.1, 0.07, 0.03))
	play_button.add_theme_color_override("font_pressed_color", Color(0.1, 0.07, 0.03))
	play_button.add_theme_stylebox_override("normal", _box(C_ACCENT, Color(1, 0.9, 0.6), 2, 8))
	play_button.add_theme_stylebox_override("hover", _box(C_ACCENT.lightened(0.15), Color(1, 0.95, 0.75), 2, 8))
	play_button.add_theme_stylebox_override("pressed", _box(C_ACCENT.darkened(0.15), Color(1, 0.9, 0.6), 2, 8))
	play_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	play_button.pressed.connect(_on_play)
	ui.add_child(play_button)

	# Friends & party panel sits left of Play.
	friends_button = UI.button("Friends", 20, Vector2(0, 0))
	friends_button.pressed.connect(_toggle_social)
	friends_button.anchor_left = 1.0
	friends_button.anchor_right = 1.0
	friends_button.anchor_top = 1.0
	friends_button.anchor_bottom = 1.0
	friends_button.offset_left = -410
	friends_button.offset_right = -265
	friends_button.offset_top = -100
	friends_button.offset_bottom = -30
	friends_button.tooltip_text = "Friends & party"
	ui.add_child(friends_button)

	social = SOCIAL_PANEL.new()
	social.visible = false
	ui.add_child(social)

	_queue_banner = _label("", 17, Color(0.55, 0.9, 1.0))
	_queue_banner.anchor_left = 0.5
	_queue_banner.anchor_right = 0.5
	_queue_banner.offset_left = -400
	_queue_banner.offset_right = 400
	_queue_banner.offset_top = 64
	_queue_banner.offset_bottom = 90
	_queue_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_queue_banner.visible = false
	ui.add_child(_queue_banner)

	_build_xp_bar()
	_build_esc_menu()

# --- XP bar (bottom center, every tab) -----------------------------------------

const XP_BAR_W := 640.0
var _xp_fill: ColorRect
var _xp_label: Label

func _build_xp_bar() -> void:
	var root := Control.new()
	root.anchor_left = 0.5
	root.anchor_right = 0.5
	root.anchor_top = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = -XP_BAR_W / 2.0
	root.offset_right = XP_BAR_W / 2.0
	root.offset_top = -20
	root.offset_bottom = -6
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	_xp_fill = ColorRect.new()
	_xp_fill.color = Color(0.6, 0.35, 0.95)
	_xp_fill.position = Vector2(1, 1)
	_xp_fill.size = Vector2(0, 12)
	_xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_xp_fill)
	_xp_label = UI.label("", 12, Color.WHITE)
	_xp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(_xp_label)
	get_node("/root/PlayerData").changed.connect(_update_xp_bar)
	get_node("/root/SignalBus").xp_changed.connect(func(_l, _x, _n): _update_xp_bar())
	_update_xp_bar()

func _update_xp_bar() -> void:
	var pd := get_node("/root/PlayerData")
	var need: int = pd.xp_to_next(pd.level)
	var frac := 1.0 if need <= 0 else clampf(float(pd.xp) / need, 0.0, 1.0)
	_xp_fill.size.x = (XP_BAR_W - 2.0) * frac
	_xp_label.text = "Level %d  •  %s" % [pd.level, "Max level" if need <= 0 else "%d / %d XP" % [pd.xp, need]]

# --- Esc menu (Resume / Settings / Quit) --------------------------------------

func _build_esc_menu() -> void:
	esc_menu = UI.small_panel("Menu")
	var content: VBoxContainer = esc_menu.get_meta("content")
	var resume := UI.button("Resume", 18, Vector2(0, 42))
	resume.pressed.connect(_hide_esc)
	content.add_child(resume)
	var settings := UI.button("Settings", 18, Vector2(0, 42))
	settings.pressed.connect(_open_settings)
	content.add_child(settings)
	var quit := UI.button("Quit", 18, Vector2(0, 42))
	quit.pressed.connect(func(): get_node("/root/GameManager").quit_game())
	content.add_child(quit)
	esc_menu.visible = false
	ui.add_child(esc_menu)

	settings_panel = UI.small_panel("Settings")
	settings_panel.offset_left = -250
	settings_panel.offset_right = 250
	settings_panel.offset_top = -250
	settings_panel.offset_bottom = 250
	var s_content: VBoxContainer = settings_panel.get_meta("content")
	s_content.add_child(get_node("/root/Settings").build_settings_ui())
	var back := UI.button("Back", 18, Vector2(0, 42))
	back.pressed.connect(_back_from_settings)
	s_content.add_child(back)
	settings_panel.visible = false
	ui.add_child(settings_panel)

	# Dim backdrop behind the menu that also blocks clicks on the UI below.
	esc_shade = ColorRect.new()
	esc_shade.color = Color(0, 0, 0, 0.45)
	esc_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	esc_shade.visible = false
	ui.add_child(esc_shade)
	ui.move_child(esc_shade, esc_menu.get_index())

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if settings_panel.visible:
			_back_from_settings()
		elif esc_menu.visible:
			_hide_esc()
		elif _book and _book.visible and pages["Abilities & Talents"].visible:
			_close_book()   # Esc closes an open book first
		elif pages["Queue"].visible:
			_show_page("Lobby")   # Esc backs out of the Play screen
		else:
			esc_menu.visible = true
			esc_shade.visible = true

func _hide_esc() -> void:
	esc_menu.visible = false
	settings_panel.visible = false
	esc_shade.visible = false

func _open_settings() -> void:
	esc_menu.visible = false
	settings_panel.visible = true

func _back_from_settings() -> void:
	settings_panel.visible = false
	esc_menu.visible = true

func _build_nav_bar() -> void:
	var bar := PanelContainer.new()
	bar.anchor_right = 1.0
	bar.offset_bottom = 58
	bar.add_theme_stylebox_override("panel", _box(Color(0.04, 0.045, 0.06, 0.95), C_BORDER, 0, 0, [0, 0, 0, 2]))
	ui.add_child(bar)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)

	var group := ButtonGroup.new()
	# The Queue screen has no tab: it opens from the PLAY button.
	for name in ["Lobby", "Character", "Abilities & Talents", "Skill Cards", "Bank"]:
		var b := Button.new()
		b.text = name
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(170, 44)
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_color_override("font_color", C_TEXT_DIM)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", C_ACCENT)
		b.add_theme_color_override("font_hover_pressed_color", C_ACCENT)
		b.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4))
		b.add_theme_stylebox_override("hover", _box(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 0, 4))
		b.add_theme_stylebox_override("pressed", _box(Color(1, 1, 1, 0.04), C_ACCENT, 0, 0, [0, 0, 0, 3]))
		b.add_theme_stylebox_override("hover_pressed", _box(Color(1, 1, 1, 0.07), C_ACCENT, 0, 0, [0, 0, 0, 3]))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(_show_page.bind(name))
		row.add_child(b)
		nav_buttons[name] = b

func _full_rect_page() -> Control:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return page

# Lobby: two empty party slots on each side of the player.
func _build_lobby() -> Control:
	var page := _full_rect_page()

	var row := HBoxContainer.new()
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.anchor_top = 0.5
	row.anchor_bottom = 0.5
	row.offset_top = -110
	row.offset_bottom = 150
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(row)

	for i in PARTY_SLOTS:
		if i == PARTY_SLOTS / 2:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(300, 0)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(gap)
		var ps := _party_slot()
		_party_slots.append(ps)
		row.add_child(ps)

	var name_label := _label("You", 22, Color.WHITE)
	_you_label = name_label
	name_label.anchor_left = 0.5
	name_label.anchor_right = 0.5
	name_label.anchor_top = 1.0
	name_label.anchor_bottom = 1.0
	name_label.offset_left = -100
	name_label.offset_right = 100
	name_label.offset_top = -80
	name_label.offset_bottom = -50
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(name_label)
	return page

func _party_slot() -> Control:
	var slot := Button.new()
	slot.custom_minimum_size = Vector2(150, 240)
	slot.text = "+\nEmpty slot"
	slot.add_theme_font_size_override("font_size", 18)
	slot.add_theme_color_override("font_color", C_TEXT_DIM)
	slot.add_theme_color_override("font_hover_color", Color.WHITE)
	slot.add_theme_stylebox_override("normal", _box(Color(0.07, 0.075, 0.1, 0.55), Color(0.3, 0.3, 0.33), 2, 10))
	slot.add_theme_stylebox_override("hover", _box(Color(0.1, 0.1, 0.13, 0.7), C_ACCENT, 2, 10))
	slot.add_theme_stylebox_override("pressed", _box(Color(0.1, 0.1, 0.13, 0.7), C_ACCENT, 2, 10))
	slot.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	slot.tooltip_text = "Invite a friend"
	slot.pressed.connect(func():
		social.visible = true
		social.move_to_front())
	return slot

# Character: player in the middle, gear slots down each side.
func _build_character() -> Control:
	var page := _full_rect_page()
	page.add_child(_gear_column(LEFT_GEAR, true))
	page.add_child(_gear_column(RIGHT_GEAR, false))
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
	var pd := get_node("/root/PlayerData")
	_lock_level_label = _label("", 17, Color.WHITE)
	_lock_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_lock_level_label)
	var tip := "Level lock: when you die you drop back to this level instead of level 1, and keep equipped gear you can still wear at it. Unlocked every %d levels." % pd.LEVEL_LOCK_STEP
	var title := _label("   Level lock:", 15, C_TEXT_DIM)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.tooltip_text = tip
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(title)
	var lv := 0
	while lv <= pd.MAX_LEVEL:
		var value := lv
		var b := UI.button("Off" if lv == 0 else str(lv), 14, Vector2(46, 30))
		b.tooltip_text = tip
		b.pressed.connect(func(): _toast_if(pd.set_level_lock(value)))
		row.add_child(b)
		_lock_buttons[lv] = b
		lv += pd.LEVEL_LOCK_STEP
	pd.changed.connect(_refresh_level_lock)
	_refresh_level_lock.call_deferred()
	return row

func _refresh_level_lock() -> void:
	var pd := get_node("/root/PlayerData")
	_lock_level_label.text = "Level %d" % pd.level
	for lv in _lock_buttons:
		var b: Button = _lock_buttons[lv]
		var on: bool = int(pd.level_lock) == int(lv)
		b.disabled = int(lv) > int(pd.level)
		b.add_theme_stylebox_override("normal", _box(C_ACCENT.darkened(0.45) if on else C_BG, C_ACCENT if on else C_BORDER, 2, 6))

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

	var main_l := _label(WEAPON_SLOTS[0], 17, Color.WHITE)
	main_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(main_l)
	row.add_child(_gear_square(WEAPON_SLOTS[0]))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(8, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	row.add_child(_gear_square(WEAPON_SLOTS[1]))
	var off_l := _label(WEAPON_SLOTS[1], 17, Color.WHITE)
	off_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(off_l)
	return row

func _gear_square(slot_name: String) -> Button:
	var square := Button.new()
	square.custom_minimum_size = Vector2(66, 66)
	square.tooltip_text = "%s (empty)" % slot_name
	square.set_meta("slot_name", slot_name)
	square.focus_mode = Control.FOCUS_NONE
	var border := C_ACCENT.darkened(0.3) if slot_name in COSMETIC_SLOTS else C_BORDER
	square.add_theme_stylebox_override("normal", _box(C_BG, border, 2, 6))
	square.add_theme_stylebox_override("hover", _box(Color(0.12, 0.12, 0.15, 0.9), C_ACCENT, 2, 6))
	square.add_theme_stylebox_override("pressed", _box(Color(0.12, 0.12, 0.15, 0.9), C_ACCENT, 2, 6))
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
		var name_l := _label(text, 17, Color.WHITE)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if left_side else HORIZONTAL_ALIGNMENT_LEFT
		labels.add_child(name_l)
		if slot_name in COSMETIC_SLOTS:
			var tag := _label("Cosmetic", 13, C_ACCENT)
			tag.horizontal_alignment = name_l.horizontal_alignment
			labels.add_child(tag)

		var square := Button.new()
		square.custom_minimum_size = Vector2(66, 66)
		square.tooltip_text = "%s (empty)" % slot_name
		square.set_meta("slot_name", slot_name)
		square.focus_mode = Control.FOCUS_NONE
		var border := C_ACCENT.darkened(0.3) if slot_name in COSMETIC_SLOTS else C_BORDER
		square.add_theme_stylebox_override("normal", _box(C_BG, border, 2, 6))
		square.add_theme_stylebox_override("hover", _box(Color(0.12, 0.12, 0.15, 0.9), C_ACCENT, 2, 6))
		square.add_theme_stylebox_override("pressed", _box(Color(0.12, 0.12, 0.15, 0.9), C_ACCENT, 2, 6))
		square.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

		if left_side:
			row.add_child(labels)
			row.add_child(square)
		else:
			row.add_child(square)
			row.add_child(labels)
		col.add_child(row)
	return col

# --- Abilities & Talents -----------------------------------------------------------
# Top: the action bar (drag abilities onto it, drag them off to remove).
# Below: a shelf of books, one per category. Opening a book shows that
# category's abilities on the left page and its talent tree on the right page.
# Talent rows unlock globally: 3 points in a row of ANY tree opens the next row
# in EVERY tree, so trees can be mixed freely.

const Abilities = preload("res://scripts/abilities.gd")
const Categories = preload("res://scripts/categories.gd")
const PAGE_BG := Color(0.12, 0.105, 0.085, 0.98)
const PAGE_BORDER := Color(0.32, 0.26, 0.18)
const INK := Color(0.93, 0.88, 0.78)
const INK_DIM := Color(0.62, 0.57, 0.5)

var _ab_bar_slots: Array[Button] = []
var _talent_points_label: Label
var _shelf: PanelContainer
var _shelf_info := {}          # category -> Label (abilities / points summary)
var _book: PanelContainer
var _book_cat := ""            # open book's category ("" = shelf showing)
var _book_emblem: Control
var _book_title: Label
var _book_sub: Label
var _book_abilities: VBoxContainer
var _book_tree: VBoxContainer
var _talent_buttons := {}      # talent id -> Button (open book only)
var _row_status: Array[Label] = []

func _build_abilities_page() -> Control:
	var page := _full_rect_page()
	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 40
	outer.offset_right = -40
	outer.offset_top = 72
	outer.offset_bottom = -20
	outer.add_theme_constant_override("separation", 10)
	page.add_child(outer)

	# Action bar strip
	var ab := PanelContainer.new()
	ab.add_theme_stylebox_override("panel", _padded(UI.box(Color(0.05, 0.055, 0.075, 0.96), C_BORDER, 2, 10)))
	outer.add_child(ab)
	var abv := VBoxContainer.new()
	abv.add_theme_constant_override("separation", 6)
	ab.add_child(abv)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(UI.label("Action Bar", 20, C_ACCENT))
	var hint := UI.label("Drag learned abilities from a book onto the bar  •  drag them off the bar to remove", 13, C_TEXT_DIM)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hint)
	_talent_points_label = UI.label("", 15, Color.WHITE)
	_talent_points_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_talent_points_label)
	var reset := UI.button("Reset Talents", 13, Vector2(120, 28))
	reset.pressed.connect(func(): get_node("/root/PlayerData").reset_talents())
	head.add_child(reset)
	abv.add_child(head)

	var bar_row := HBoxContainer.new()
	bar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_row.add_theme_constant_override("separation", 6)
	abv.add_child(bar_row)
	for i in 8:
		var b := Abilities.make_slot(50)
		var key := UI.label(str(i + 1), 13, Color.WHITE)
		key.position = Vector2(4, 1)
		b.add_child(key)
		b.set_drag_forwarding(
			func(_pos): return _ability_drag_from_bar(b, i),
			func(_pos, data): return data is Dictionary and data.get("type") == "ability",
			func(_pos, data): get_node("/root/PlayerData").set_action_slot(i, data["id"], int(data["from"])))
		bar_row.add_child(b)
		_ab_bar_slots.append(b)

	# Shelf (category books) / open book
	var area := Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(area)
	_shelf = _build_shelf()
	area.add_child(_shelf)
	_book = _build_book()
	_book.visible = false
	area.add_child(_book)

	var pd := get_node("/root/PlayerData")
	pd.changed.connect(_refresh_abilities)
	_refresh_abilities.call_deferred()
	return page

## Dropping an ability dragged from the bar onto `c` removes it from the bar.
func _accept_bar_drop(c: Control) -> void:
	c.set_drag_forwarding(
		func(_pos): return null,
		func(_pos, data): return data is Dictionary and data.get("type") == "ability" and int(data["from"]) >= 0,
		func(_pos, data): get_node("/root/PlayerData").clear_action_slot(int(data["from"])))

# --- The shelf: one book per category --------------------------------------------------

func _build_shelf() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _padded(UI.box(Color(0.05, 0.055, 0.075, 0.96), C_BORDER, 2, 10), 16))
	_accept_bar_drop(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.add_child(UI.label("Spellbooks", 22, C_ACCENT))
	var hint := UI.label("Open a book to see its abilities and talents  •  3 talent points in a row of any book unlock the next row in every book", 13, C_TEXT_DIM)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hint)
	v.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	v.add_child(grid)
	for cat in Categories.ORDER:
		grid.add_child(_shelf_book(cat))
	return panel

func _shelf_book(cat: String) -> Button:
	var col := Categories.color(cat)
	var cover := col.darkened(0.78)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 130)
	b.tooltip_text = "%s\n%s" % [Categories.cat_name(cat), Categories.desc(cat)]
	b.add_theme_stylebox_override("normal", _box(cover, col.darkened(0.25), 0, 8, [12, 2, 2, 2]))
	b.add_theme_stylebox_override("hover", _box(cover.lightened(0.06), col, 0, 8, [12, 3, 3, 3]))
	b.add_theme_stylebox_override("pressed", _box(cover.lightened(0.1), col.lightened(0.2), 0, 8, [12, 3, 3, 3]))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(_open_book.bind(cat))
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
	var name_l := _label(Categories.cat_name(cat), 20, col.lightened(0.35))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	var info := _label("", 12, C_TEXT_DIM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	_shelf_info[cat] = info
	return b

# --- The open book: abilities (left page) + talent tree (right page) -------------------

func _build_book() -> PanelContainer:
	var book := PanelContainer.new()
	book.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	book.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var back := UI.button("◀  Books", 14, Vector2(110, 34))
	back.pressed.connect(_close_book)
	head.add_child(back)
	_book_emblem = Control.new()
	_book_emblem.custom_minimum_size = Vector2(38, 38)
	_book_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_emblem.draw.connect(func(): Categories.draw_emblem(_book_emblem, _book_cat))
	head.add_child(_book_emblem)
	_book_title = _label("", 24, Color.WHITE)
	_book_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_book_title)
	_book_sub = _label("", 13, C_TEXT_DIM)
	_book_sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_book_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_book_sub)

	var pages := HBoxContainer.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages.add_theme_constant_override("separation", 0)
	v.add_child(pages)
	var left := _book_page(1.0)
	_accept_bar_drop(left)
	pages.add_child(left)
	var spine := ColorRect.new()
	spine.color = Color(0.05, 0.035, 0.02)
	spine.custom_minimum_size = Vector2(10, 0)
	spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages.add_child(spine)
	var right := _book_page(1.35)
	pages.add_child(right)

	_book_abilities = _page_content(left, "Abilities", "Drag a learned ability onto the action bar.")
	_book_tree = _page_content(right, "Talents",
		"Left-click: invest  •  Right-click: refund  •  3 points in a row (in any book) open the next row in every book")
	return book

func _book_page(ratio: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = ratio
	p.add_theme_stylebox_override("panel", _padded(UI.box(PAGE_BG, PAGE_BORDER, 1, 4), 16))
	return p

# Heading + hint + scrolling list on a book page; returns the list.
func _page_content(page: PanelContainer, title: String, hint_text: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	page.add_child(v)
	v.add_child(_label(title, 20, INK))
	var hint := _label(hint_text, 12, INK_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	var line := ColorRect.new()
	line.color = PAGE_BORDER
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(line)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS   # let bar drops reach the page
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	return list

func _open_book(cat: String) -> void:
	_book_cat = cat
	var col := Categories.color(cat)
	_book.add_theme_stylebox_override("panel", _padded(UI.box(col.darkened(0.8), col.darkened(0.2), 3, 12), 14))
	_book_title.text = Categories.cat_name(cat)
	_book_title.add_theme_color_override("font_color", col.lightened(0.35))
	_book_emblem.queue_redraw()
	_build_talent_tree()
	_shelf.visible = false
	_book.visible = true
	_refresh_abilities()

func _close_book() -> void:
	_book_cat = ""
	_talent_buttons.clear()
	_row_status.clear()
	_book.visible = false
	_shelf.visible = true

func _refresh_book_abilities() -> void:
	for c in _book_abilities.get_children():
		c.queue_free()
	var ids := Abilities.in_category(_book_cat)
	if ids.is_empty():
		_book_abilities.add_child(_label("No abilities in this book yet.", 14, INK_DIM))
		return
	var pd := get_node("/root/PlayerData")
	for id in ids:
		var learned: bool = pd.has_ability(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var s := Abilities.make_slot(48)
		Abilities.set_slot_ability(s, id)
		var can_drop := func(_pos, data): return data is Dictionary and data.get("type") == "ability" and int(data["from"]) >= 0
		var on_drop := func(_pos, data): pd.clear_action_slot(int(data["from"]))
		if learned:
			s.set_drag_forwarding(
				func(_pos):
					s.set_drag_preview(_ability_preview(id))
					return {"type": "ability", "id": id, "from": -1},
				can_drop, on_drop)
		else:
			s.get_node("AbilityIcon").modulate.a = 0.3
			s.set_drag_forwarding(func(_pos): return null, can_drop, on_drop)
		row.add_child(s)
		var info := VBoxContainer.new()
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(_label(Abilities.ability_name(id), 16, INK if learned else INK_DIM))
		var status := "Learned  •  drag to the bar"
		var scol := INK_DIM
		if not learned:
			status = "Not learned  •  offered in level-up drafts"
			scol = Color(0.8, 0.5, 0.4)
		elif pd.action_bar.has(id):
			status = "On your bar (slot %d)" % (pd.action_bar.find(id) + 1)
			scol = Color(0.55, 0.9, 0.55)
		info.add_child(_label(status, 12, scol))
		row.add_child(info)
		_book_abilities.add_child(row)

# --- Talent tree of the open book ------------------------------------------------------

func _build_talent_tree() -> void:
	for c in _book_tree.get_children():
		c.queue_free()
	_talent_buttons.clear()
	_row_status.clear()
	var pd := get_node("/root/PlayerData")
	for r in Talents.ROWS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_book_tree.add_child(row)
		var info := VBoxContainer.new()
		info.custom_minimum_size = Vector2(130, 0)
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		info.add_child(_label("Row %d" % (r + 1), 15, INK))
		var status := _label("", 11, INK_DIM)
		info.add_child(status)
		_row_status.append(status)
		row.add_child(info)
		var nodes := HBoxContainer.new()
		nodes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nodes.alignment = BoxContainer.ALIGNMENT_CENTER
		nodes.add_theme_constant_override("separation", 14)
		row.add_child(nodes)
		for id in Talents.in_row(_book_cat, r):
			var t := Talents.get_talent(id)
			var node := VBoxContainer.new()
			node.add_theme_constant_override("separation", 2)
			node.custom_minimum_size = Vector2(112, 0)
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(64, 44)
			b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			b.add_theme_font_size_override("font_size", 15)
			b.pressed.connect(func(): _toast_if(pd.invest_talent(id)))
			b.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
					_toast_if(pd.refund_talent(id)))
			node.add_child(b)
			var n := _label(str(t["name"]), 12, INK)
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			n.custom_minimum_size = Vector2(112, 0)
			node.add_child(n)
			nodes.add_child(node)
			_talent_buttons[id] = b
		if r < Talents.ROWS - 1:
			var sep := ColorRect.new()
			sep.color = Color(PAGE_BORDER, 0.5)
			sep.custom_minimum_size = Vector2(0, 1)
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_book_tree.add_child(sep)
	_refresh_talents()

func _refresh_talents() -> void:
	var pd := get_node("/root/PlayerData")
	_talent_points_label.text = "Level %d  •  Talent points: %d / %d" % [pd.level, pd.talent_points_left(), pd.talent_points_total()]
	for cat in _shelf_info:
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
		_shelf_info[cat].text = "  •  ".join(parts)
	if _book_cat == "":
		return
	var pts: int = pd.tree_points(_book_cat)
	_book_sub.text = Categories.desc(_book_cat) + ("   •   %d talent points in this book" % pts if pts > 0 else "")
	var col := Categories.color(_book_cat)
	for r in _row_status.size():
		var status: Label = _row_status[r]
		if pd.tier_unlocked(r):
			status.text = "Open  •  %d spent (all books)" % pd.tier_points(r)
			status.add_theme_color_override("font_color", Color(0.55, 0.9, 0.55))
		else:
			status.text = "Locked: %d / %d in row %d" % [pd.tier_points(r - 1), Talents.POINTS_TO_UNLOCK_NEXT, r]
			status.add_theme_color_override("font_color", Color(0.9, 0.45, 0.4))
	for id in _talent_buttons:
		var b: Button = _talent_buttons[id]
		var t := Talents.get_talent(id)
		var rank: int = pd.talent_rank(id)
		var max_rank := int(t["max_rank"])
		var unlocked: bool = pd.tier_unlocked(int(t["tier"]))
		b.text = "%d / %d" % [rank, max_rank]
		var border := PAGE_BORDER
		if rank >= max_rank:
			border = C_ACCENT
		elif rank > 0:
			border = col
		var bg := Color(0.16, 0.14, 0.11, 0.95) if unlocked else Color(0.08, 0.07, 0.06, 0.95)
		b.add_theme_stylebox_override("normal", UI.box(bg, border, 2, 6))
		b.add_theme_stylebox_override("hover", UI.box(bg.lightened(0.08), col, 2, 6))
		b.add_theme_stylebox_override("pressed", UI.box(bg.lightened(0.08), col, 2, 6))
		b.add_theme_color_override("font_color", Color.WHITE if unlocked else Color(0.45, 0.42, 0.38))
		var req := "" if unlocked else "\nRequires %d points in row %d (any book)" % [Talents.POINTS_TO_UNLOCK_NEXT, int(t["tier"])]
		b.tooltip_text = Talents.tooltip(id, rank) + req

func _padded(sb: StyleBoxFlat, m: int = 12) -> StyleBoxFlat:
	sb.content_margin_left = m
	sb.content_margin_right = m
	sb.content_margin_top = m - 2
	sb.content_margin_bottom = m - 2
	return sb

# --- Skill Cards: a loadout that guarantees abilities in level-up drafts ------------

const SkillCards = preload("res://scripts/skill_cards.gd")
var _cards_row: VBoxContainer
var _cards_tabs: HFlowContainer
var _cards_count_label: Label
var _cards_filter := ""   # "" = all books, else a category id

func _build_cards_page() -> Control:
	var page := _full_rect_page()
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 40
	panel.offset_right = -40
	panel.offset_top = 72
	panel.offset_bottom = -20
	panel.add_theme_stylebox_override("panel", _padded(UI.box(Color(0.05, 0.055, 0.075, 0.96), C_BORDER, 2, 10), 16))
	page.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.add_child(UI.label("Skill Cards", 22, C_ACCENT))
	_cards_count_label = UI.label("", 15, Color.WHITE)
	_cards_count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_cards_count_label)
	v.add_child(head)
	var hint := UI.label("Skill Cards are found in dungeon chests and are kept forever. Click a card you own to equip or unequip it. Once you reach an equipped card's level, your next ability draft (every %d levels) is guaranteed to offer its ability — so after dying, your cards bring your abilities back." % get_node("/root/PlayerData").DRAFT_EVERY, 13, C_TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	# Book filter: All + one tab per category (same books as Abilities & Talents).
	_cards_tabs = HFlowContainer.new()
	_cards_tabs.add_theme_constant_override("h_separation", 6)
	_cards_tabs.add_theme_constant_override("v_separation", 6)
	v.add_child(_cards_tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_cards_row = VBoxContainer.new()
	_cards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_row.add_theme_constant_override("separation", 10)
	scroll.add_child(_cards_row)
	get_node("/root/PlayerData").changed.connect(_refresh_cards)
	_refresh_cards.call_deferred()
	return page

func _refresh_cards() -> void:
	if _cards_row == null:
		return
	var pd := get_node("/root/PlayerData")
	_cards_count_label.text = "%d / %d collected  •  %d / %d equipped" % [pd.owned_cards.size(), SkillCards.ALL.size(),
		pd.equipped_cards.size(), SkillCards.MAX_EQUIPPED]
	for c in _cards_row.get_children():
		c.queue_free()
	_refresh_card_tabs(pd)
	# Grouped by book (same order as the spellbook shelf); within a book owned
	# cards first, then by card level.
	var by_cat := {}
	for cid in SkillCards.ALL:
		var cat := Abilities.category_of(SkillCards.ability_of(cid))
		if _cards_filter != "" and cat != _cards_filter:
			continue
		if not by_cat.has(cat):
			by_cat[cat] = []
		by_cat[cat].append(cid)
	var cats: Array = Categories.ORDER.filter(func(c): return by_cat.has(c))
	for c in by_cat:
		if not cats.has(c):
			cats.append(c)   # cards whose ability has no book
	for cat in cats:
		var list: Array = by_cat[cat]
		list.sort_custom(func(a, b):
			var oa: bool = pd.owned_cards.has(a)
			var ob: bool = pd.owned_cards.has(b)
			if oa != ob:
				return oa
			if SkillCards.level_of(a) != SkillCards.level_of(b):
				return SkillCards.level_of(a) < SkillCards.level_of(b)
			return Abilities.ability_name(SkillCards.ability_of(a)) < Abilities.ability_name(SkillCards.ability_of(b)))
		var owned_n := list.filter(func(c): return pd.owned_cards.has(c)).size()
		var title := _label("%s   %d / %d" % [Categories.cat_name(cat) if cat != "" else "Other", owned_n, list.size()],
			17, Categories.color(cat).lightened(0.3) if cat != "" else Color.WHITE)
		_cards_row.add_child(title)
		var flow := HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", 12)
		flow.add_theme_constant_override("v_separation", 12)
		_cards_row.add_child(flow)
		for cid in list:
			flow.add_child(_card_button(pd, cid))

## Filter tabs: All + every book, each with owned / total.
func _refresh_card_tabs(pd: Node) -> void:
	for c in _cards_tabs.get_children():
		c.queue_free()
	var counts := {}   # cat -> [owned, total]
	for cid in SkillCards.ALL:
		var cat := Abilities.category_of(SkillCards.ability_of(cid))
		if not counts.has(cat):
			counts[cat] = [0, 0]
		counts[cat][1] += 1
		if pd.owned_cards.has(cid):
			counts[cat][0] += 1
	var tabs: Array = [""]
	for cat in Categories.ORDER:
		if counts.has(cat):
			tabs.append(cat)
	for cat in tabs:
		var c: String = cat
		var on := c == _cards_filter
		var col := Categories.color(c) if c != "" else C_ACCENT
		var text := "All  %d / %d" % [pd.owned_cards.size(), SkillCards.ALL.size()] if c == "" \
			else "%s  %d / %d" % [Categories.cat_name(c), counts[c][0], counts[c][1]]
		var b := UI.button(text, 14, Vector2(0, 32))
		b.add_theme_color_override("font_color", col.lightened(0.35) if on else col.lightened(0.1))
		b.add_theme_stylebox_override("normal", UI.box(col.darkened(0.7) if on else UI.BG, col if on else col.darkened(0.4), 2 if on else 1, 6))
		b.pressed.connect(func():
			_cards_filter = c
			_refresh_cards())
		_cards_tabs.add_child(b)

func _card_button(pd: Node, cid: String) -> Button:
		var aid := SkillCards.ability_of(cid)
		var cat := Abilities.category_of(aid)
		var equipped: bool = pd.equipped_cards.has(cid)
		var learned: bool = pd.has_ability(aid)
		var owned: bool = pd.owned_cards.has(cid)
		var b := Button.new()
		if not owned:
			b.modulate = Color(1, 1, 1, 0.35)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(240, 76)
		var border := C_ACCENT if equipped else UI.BORDER
		b.add_theme_stylebox_override("normal", UI.box(Color(0.08, 0.085, 0.11, 0.95), border, 2 if equipped else 1, 8))
		b.add_theme_stylebox_override("hover", UI.box(Color(0.11, 0.11, 0.15, 0.95), C_ACCENT, 2, 8))
		b.add_theme_stylebox_override("pressed", UI.box(Color(0.11, 0.11, 0.15, 0.95), C_ACCENT, 2, 8))
		b.tooltip_text = SkillCards.tooltip(cid)
		b.pressed.connect(func(): _toast_if(pd.toggle_card(cid)))
		var icon := Control.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2(10, 12)
		icon.size = Vector2(52, 52)
		icon.draw.connect(func(): Abilities.draw_icon(icon, aid))
		b.add_child(icon)
		var info := VBoxContainer.new()
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.position = Vector2(72, 10)
		info.size = Vector2(160, 56)
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		info.add_theme_constant_override("separation", 1)
		b.add_child(info)
		info.add_child(_label(Abilities.ability_name(aid), 16, Color.WHITE if equipped else Color(0.85, 0.85, 0.9)))
		info.add_child(_label("%s  •  Level %d" % [Categories.cat_name(cat), SkillCards.level_of(cid)], 12, Categories.color(cat)))
		var state := "Equipped" if equipped else ("Not equipped" if owned else "Not found — open chests")
		if learned:
			state += "  •  learned"
		info.add_child(_label(state, 11, C_ACCENT if equipped else C_TEXT_DIM))
		return b

func _ability_drag_from_bar(b: Button, i: int) -> Variant:
	var id: String = get_node("/root/PlayerData").action_bar[i]
	if id == "":
		return null
	b.set_drag_preview(_ability_preview(id))
	_bar_drag_from = i
	return {"type": "ability", "id": id, "from": i}

# Bar slot being dragged (-1 = none). Letting go anywhere that doesn't take the
# ability (empty space, the nav bar, other panels...) removes it from the bar.
var _bar_drag_from := -1

func _check_bar_drag_end() -> void:
	if _bar_drag_from == -1 or get_viewport().gui_is_dragging():
		return
	var from := _bar_drag_from
	_bar_drag_from = -1
	if not get_viewport().gui_is_drag_successful():
		get_node("/root/PlayerData").clear_action_slot(from)

func _ability_preview(id: String) -> Control:
	var root := Control.new()
	var s := Abilities.make_slot(44)
	s.modulate.a = 0.85
	s.position = Vector2(-22, -22)
	Abilities.set_slot_ability(s, id)
	root.add_child(s)
	return root

func _refresh_abilities() -> void:
	var pd := get_node("/root/PlayerData")
	for i in _ab_bar_slots.size():
		Abilities.set_slot_ability(_ab_bar_slots[i], pd.action_bar[i])
	_refresh_talents()
	if _book_cat != "":
		_refresh_book_abilities()

# --- Queue: pick a dungeon / raid and launch into it -------------------------------

const INSTANCES := [
	{"name": "The Cave", "kind": "Dungeon", "players": "1-5 players", "available": true,
		"scene": "res://node_3d.tscn", "desc": "A winding cavern where the restless dead shamble in the dark."},
	{"name": "The Crypt", "kind": "Dungeon", "players": "1-5 players", "available": true,
		"scene": "res://scenes/dungeon.tscn", "floors": true, "desc": "A new crypt every run: fight through the rooms, beat the elites, defeat the Zombie Lord and escape through the gate. Each descent goes one floor deeper."},
	{"name": "Frozen Depths", "kind": "Dungeon", "players": "1-5 players", "available": false,
		"scene": "", "desc": "Ice-choked tunnels beneath the glacier. Coming soon."},
	{"name": "Crypt of Bones", "kind": "Raid", "players": "10 players", "available": false,
		"scene": "", "desc": "An ancient tomb and its undying king. Coming soon."},
]

var _queue_selected := -1
var _queue_cards: Array[Button] = []
var _queue_enter: Button
var _queue_info: Label

func _build_queue_page() -> Control:
	var page := _full_rect_page()
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 40
	panel.offset_right = -40
	panel.offset_top = 72
	panel.offset_bottom = -20
	panel.add_theme_stylebox_override("panel", _padded(UI.box(Color(0.05, 0.055, 0.075, 0.96), C_BORDER, 2, 10), 16))
	page.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var head := HBoxContainer.new()
	var back := UI.button("←  Back", 16, Vector2(110, 36))
	back.tooltip_text = "Back to the lobby (Esc)"
	back.pressed.connect(_show_page.bind("Lobby"))
	head.add_child(back)
	var title := UI.label("   Play", 22, C_ACCENT)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	v.add_child(head)

	for kind in ["Dungeon", "Raid"]:
		v.add_child(UI.label(kind + "s", 16, Color.WHITE))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		v.add_child(row)
		for i in INSTANCES.size():
			if INSTANCES[i]["kind"] == kind:
				row.add_child(_instance_card(i))

	# Starting floor (floor-based dungeons): 1 + every checkpoint you've unlocked.
	_floor_box = VBoxContainer.new()
	_floor_box.add_theme_constant_override("separation", 6)
	_floor_box.visible = false
	v.add_child(_floor_box)
	_floor_box.add_child(UI.label("Starting floor", 16, Color.WHITE))
	_floor_row = HBoxContainer.new()
	_floor_row.add_theme_constant_override("separation", 8)
	_floor_box.add_child(_floor_row)
	_floor_hint = UI.label("", 13, C_TEXT_DIM)
	_floor_box.add_child(_floor_hint)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	v.add_child(bottom)
	_queue_info = UI.label("Select a dungeon or raid.", 15, C_TEXT_DIM)
	_queue_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_queue_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_queue_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(_queue_info)
	# Queue: fill the group up to 5 with random players (a full party goes straight in).
	_queue_btn = UI.button("Queue", 22, Vector2(200, 56))
	_queue_btn.disabled = true
	_queue_btn.tooltip_text = "Find a group: you're matched with other players queueing for the same dungeon.\nA full party of 5 goes straight in."
	_queue_btn.pressed.connect(_toggle_queue)
	bottom.add_child(_queue_btn)
	_queue_enter = UI.button("Enter Now", 22, Vector2(200, 56))
	_queue_enter.add_theme_stylebox_override("normal", UI.box(C_ACCENT, Color(1, 0.9, 0.6), 2, 8))
	_queue_enter.add_theme_stylebox_override("hover", UI.box(C_ACCENT.lightened(0.15), Color(1, 0.95, 0.75), 2, 8))
	_queue_enter.add_theme_stylebox_override("disabled", UI.box(Color(0.2, 0.2, 0.22), C_BORDER, 2, 8))
	_queue_enter.add_theme_color_override("font_color", Color(0.1, 0.07, 0.03))
	_queue_enter.add_theme_color_override("font_hover_color", Color(0.1, 0.07, 0.03))
	_queue_enter.disabled = true
	_queue_enter.tooltip_text = "Go in right now with your current party (or solo)."
	_queue_enter.pressed.connect(_enter_instance)
	bottom.add_child(_queue_enter)
	return page

var _queue_btn: Button
var _floor_box: VBoxContainer
var _floor_row: HBoxContainer
var _floor_hint: Label
var _start_floor := 1
var _floor_for := -1   # instance index the floor buttons were built for

## Scene path + chosen starting floor, as GameManager / the queue expect it.
func _selected_key() -> String:
	var inst: Dictionary = INSTANCES[_queue_selected]
	var f := _start_floor if inst.get("floors", false) else 1
	return get_node("/root/GameManager").instance_key(inst["scene"], f)

func _refresh_floors() -> void:
	var inst: Dictionary = INSTANCES[_queue_selected] if _queue_selected >= 0 else {}
	var show: bool = inst.get("floors", false) and inst.get("available", false)
	_floor_box.visible = show
	if not show:
		return
	var pd := get_node("/root/PlayerData")
	var floors: Array[int] = pd.start_floors(inst["scene"])
	if _floor_for != _queue_selected or not floors.has(_start_floor):
		_start_floor = floors.back()   # default: your furthest checkpoint
	_floor_for = _queue_selected
	for c in _floor_row.get_children():
		c.queue_free()
	for f in floors:
		var fl: int = f
		var b := UI.button("Floor %d" % fl, 16, Vector2(100, 40))
		var on := fl == _start_floor
		b.add_theme_stylebox_override("normal", UI.box(C_ACCENT.darkened(0.45) if on else UI.BG, C_ACCENT if on else UI.BORDER, 2, 6))
		b.pressed.connect(func():
			_start_floor = fl
			_refresh_queue())
		_floor_row.add_child(b)
	var next: int = (int(floors.back()) / pd.CHECKPOINT_EVERY + 1) * pd.CHECKPOINT_EVERY
	_floor_hint.text = "Clear floor %d to unlock the next checkpoint (every %d floors)." % [next, pd.CHECKPOINT_EVERY]

func _toggle_queue() -> void:
	var online := get_node("/root/Online")
	if online.queue_instance != "":
		online.cancel_queue()
		return
	if _queue_selected < 0 or not INSTANCES[_queue_selected]["available"]:
		return
	online.queue_for(_selected_key())

func _instance_card(i: int) -> Button:
	var inst: Dictionary = INSTANCES[i]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(250, 110)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.text = "%s\n%s  •  %s\n%s" % [inst["name"], inst["kind"], inst["players"], "" if inst["available"] else "Locked"]
	b.tooltip_text = inst["desc"]
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color.WHITE if inst["available"] else Color(0.5, 0.5, 0.55))
	b.pressed.connect(func():
		_queue_selected = i
		_refresh_queue())
	_queue_cards.append(b)
	_style_card(b, false, inst["available"])
	return b

func _style_card(b: Button, selected: bool, available: bool) -> void:
	var bg := Color(0.08, 0.09, 0.12, 0.95) if available else Color(0.05, 0.05, 0.06, 0.95)
	var border := C_ACCENT if selected else UI.BORDER
	b.add_theme_stylebox_override("normal", _padded(UI.box(bg, border, 3 if selected else 2, 8), 12))
	b.add_theme_stylebox_override("hover", _padded(UI.box(bg.lightened(0.06), C_ACCENT, 2, 8), 12))
	b.add_theme_stylebox_override("pressed", _padded(UI.box(bg.lightened(0.06), C_ACCENT, 3, 8), 12))

func _refresh_queue() -> void:
	for i in _queue_cards.size():
		_style_card(_queue_cards[i], i == _queue_selected, INSTANCES[i]["available"])
	var online := get_node("/root/Online")
	var queued: bool = online.queue_instance != ""
	var leader: bool = online.is_leader()
	if _queue_btn:
		_queue_btn.text = "Leave Queue" if queued else "Queue"
		_queue_btn.disabled = not leader or (not queued and (_queue_selected < 0 or not INSTANCES[_queue_selected]["available"]))
	_refresh_floors()
	if _queue_selected < 0:
		_queue_enter.disabled = true
		return
	var inst: Dictionary = INSTANCES[_queue_selected]
	var who := "" if leader else "\nOnly the party leader can queue or start."
	_queue_info.text = "%s — %s%s" % [inst["name"], inst["desc"], who]
	_queue_enter.disabled = not inst["available"] or not leader
	_queue_enter.text = "Enter Now" if inst["available"] else "Locked"

func _enter_instance() -> void:
	if _queue_selected < 0 or not INSTANCES[_queue_selected]["available"]:
		return
	get_node("/root/Online").start_now(_selected_key())

func _build_bank_page() -> Control:
	var page := _build_empty_page("Bank")
	var v: VBoxContainer = page.get_child(0).get_child(0)
	v.get_child(1).queue_free()  # drop the "Nothing here yet." line
	# Sort buttons: by type, by quality (rarity), by rune (legendary > epic > rare > common).
	var sort_row := HBoxContainer.new()
	sort_row.alignment = BoxContainer.ALIGNMENT_END
	sort_row.add_theme_constant_override("separation", 6)
	var sort_l := UI.label("Sort:", 14, C_TEXT_DIM)
	sort_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sort_row.add_child(sort_l)
	for opt in [["Type", "type", "Group by item type (weapons, then armor by slot), best first"],
			["Quality", "quality", "Epic → Rare → Uncommon → Common"],
			["Rune", "rune", "Runed items first: Legendary → Epic → Rare → Common runes"]]:
		var mode: String = opt[1]
		var b := UI.button(opt[0], 14, Vector2(84, 30))
		b.tooltip_text = opt[2]
		b.pressed.connect(func():
			_bank_selected.clear()
			get_node("/root/PlayerData").sort_bank(mode))
		sort_row.add_child(b)
	v.add_child(sort_row)
	v.add_child(UI.bank_grid(15, 42, 346))
	return page

func _build_empty_page(title: String) -> Control:
	var page := _full_rect_page()
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -380
	panel.offset_right = 380
	panel.offset_top = -230
	panel.offset_bottom = 260
	panel.add_theme_stylebox_override("panel", _box(Color(0.05, 0.055, 0.075, 0.96), C_BORDER, 2, 10))
	page.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var t := _label(title, 28, C_ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := _label("Nothing here yet.", 16, C_TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	return page

# --- Behaviour ---------------------------------------------------------------

func _show_page(page_name: String) -> void:
	for k in pages:
		pages[k].visible = (k == page_name)
	if nav_buttons.has(page_name):
		nav_buttons[page_name].button_pressed = true
	else:
		for b in nav_buttons.values():
			b.set_pressed_no_signal(false)
	if page_name == "Queue":
		_refresh_queue()
	play_button.visible = (page_name == "Lobby")
	friends_button.visible = (page_name == "Lobby")
	if social and page_name != "Lobby" and page_name != "Queue":
		social.visible = false
	# Hide the 3D character behind full-panel pages.
	var shows_player := page_name in ["Lobby", "Character"]
	model.visible = shows_player
	$Pedestal.visible = shows_player

## PLAY opens the dungeon / queue screen.
func _on_play() -> void:
	_show_page("Queue")

# --- Helpers -----------------------------------------------------------------

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# borders: [left, top, right, bottom] widths; overrides `border` when given.
func _box(bg: Color, border_color: Color, border: int, radius: int, borders: Array = []) -> StyleBoxFlat:
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
