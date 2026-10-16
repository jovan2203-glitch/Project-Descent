extends CanvasLayer

# In-game UI: bottom-left menu bar (Character / Talents / Bank / Inventory)
# with small, movable windows, and an Esc menu (Resume / Settings / Quit).
# Nothing here pauses the game.

const UI = preload("res://scripts/ui_kit.gd")
const MAIN_MENU = "res://scenes/main_menu.tscn"
const WINDOW_WIDTH_FRACTION = 0.30

var windows := {}          # name -> PanelContainer
var bar_buttons := {}      # name -> Button
var open_order: Array[String] = []   # most recently opened last
var _positioned := {}      # name -> true once given an initial position

var esc_menu: PanelContainer
var settings_panel: PanelContainer

const CHAT_BOX = preload("res://scripts/ui/chat_box.gd")
const DEBUG_OVERLAY = preload("res://scripts/ui/debug_overlay.gd")
const COMBAT_VIGNETTE = preload("res://scripts/ui/combat_vignette.gd")
var chat_box: PanelContainer

func _ready() -> void:
	_build_bar()
	# Local chat (Chat / Logs tabs) above the bottom-left bar.
	chat_box = CHAT_BOX.new()
	add_child(chat_box)
	add_child(DEBUG_OVERLAY.new())
	add_child(COMBAT_VIGNETTE.new())   # red screen edges while in combat
	_build_maps()
	_build_windows()
	_build_esc_menu()
	_build_settings()
	_wire_items()
	# Settings > Interface > HUD opacity: everything here except the Esc menu,
	# Settings and the map (those stay solid so they're always readable).
	var settings := get_node("/root/Settings")
	var fade := func(c: Node):
		if c is CanvasItem and c != esc_menu and c != settings_panel and c != map_panel and not (c is Node and c.get_script() == MAP_DATA):
			settings.register_hud(c)
	for c in get_children():
		fade.call(c)
	child_entered_tree.connect(fade)

# --- Items: inventory <-> equipment ---------------------------------------------

var _inv_buttons: Array[Button] = []
var _gear_buttons: Array[Button] = []

func _pd() -> Node:
	return get_node("/root/PlayerData")

func _wire_items() -> void:
	for b in windows["Inventory"].find_children("*", "Button", true, false):
		if b.has_meta("inv_index"):
			var idx := int(b.get_meta("inv_index"))
			_inv_buttons.append(b)
			# Right-click: Equip / Delete menu; left-click does nothing (hold left to drag).
			b.button_mask = MOUSE_BUTTON_MASK_RIGHT
			b.pressed.connect(_inventory_context_menu.bind(idx))
			b.set_drag_forwarding(
				func(_pos): return _inv_drag_data(b, idx),
				func(_pos, data): return data is Dictionary and data.get("type") == "inv",
				func(_pos, data): _pd().swap_inventory(int(data["index"]), idx))
	for b in windows["Character"].find_children("*", "Button", true, false):
		if b.has_meta("slot_name"):
			var slot := str(b.get_meta("slot_name"))
			_gear_buttons.append(b)
			b.pressed.connect(_on_gear_clicked.bind(slot))
			b.set_drag_forwarding(
				func(_pos): return _gear_drag_data(b, slot),
				func(_pos, data): return _can_equip_drop(data, slot) or _is_rune(data),
				func(_pos, data):
					if _is_rune(data):
						var err: String = _pd().apply_rune(slot, data["id"])
						if err != "":
							_report(err)
					else:
						_on_inventory_clicked(int(data["index"]), slot))
	for b in windows["Bank"].find_children("*", "Button", true, false):
		if b.has_meta("bank_index"):
			_bank_buttons.append(b)
	_pd().changed_late.connect(_refresh_items)
	_refresh_items()
	var bus := get_node("/root/SignalBus")
	bus.buffs_changed.connect(_refresh_stats)
	_refresh_stats.call_deferred()

var _stat_panel: PanelContainer
const Stats = preload("res://scripts/core/stats.gd")

# Stats = what the player actually has right now (gear + talents + buffs).
func _refresh_stats() -> void:
	if _stat_panel == null:
		return
	var player := get_tree().get_first_node_in_group("player")
	var values := {}
	var bonus := {}
	var base_totals: Dictionary = _pd().total_stats()
	for stat in UI.STAT_ORDER:
		if player and player.has_method("get_stat"):
			values[stat] = player.get_stat(stat)
			var without_buffs := Stats.from_totals(stat, base_totals)
			bonus[stat] = float(values[stat]) - without_buffs
		else:
			values[stat] = Stats.from_totals(stat, base_totals)
	# The Parry row shows what counts: my cap is higher with Humming Blade / Crossguard up.
	if player and player.has_method("parry_cap"):
		values["parry_cap"] = player.parry_cap()
	# ... and so does the Dodge row: each Reflection raises my Dodge cap.
	if player and player.has_method("dodge_cap"):
		values["dodge_cap"] = player.dodge_cap()
	UI.update_stat_panel(_stat_panel, values, bonus)

func _refresh_items() -> void:
	_refresh_stats()
	var pd := _pd()
	for b in _inv_buttons:
		UI.set_slot_item(b, pd.inventory[int(b.get_meta("inv_index"))])
	for b in _gear_buttons:
		var slot := str(b.get_meta("slot_name"))
		UI.set_slot_item(b, pd.equipment.get(slot, ""), pd.is_slot_locked(slot), false, pd.gear_runes.get(slot, ""))
	# Bank (view only in game)
	var bank_used := 0
	for b in _bank_buttons:
		var bid: String = pd.bank[int(b.get_meta("bank_index"))]
		if bid != "":
			bank_used += 1
		UI.set_slot_item(b, bid)
	for l in windows["Bank"].find_children("*", "Label", true, false):
		if l.has_meta("bank_counter"):
			l.text = "Slots used: %d / %d   (view only)" % [bank_used, pd.BANK_SIZE]
	# Inventory counter
	var used := 0
	for id in pd.inventory:
		if id != "":
			used += 1
	for l in windows["Inventory"].find_children("*", "Label", true, false):
		if l.text.begins_with("Slots used:"):
			l.text = "Slots used: %d / %d" % [used, pd.INVENTORY_SIZE]

var _bank_buttons: Array[Button] = []
const LOOT_DROP = preload("res://scripts/loot_drop.gd")
const Items = preload("res://scripts/items.gd")
var _drag_inv_index := -1     # inventory slot currently being dragged, if any

func _inv_drag_data(btn: Button, idx: int) -> Variant:
	var id: String = _pd().inventory[idx]
	if id == "":
		return null
	btn.set_drag_preview(UI.drag_preview(id, 1))
	_drag_inv_index = idx
	return {"type": "inv", "index": idx}

## Dragging an equipped on-use trinket gives its action-bar button ("Use
## Trinket 1 / 2"): drop it on a bar slot to use the trinket from there.
func _gear_drag_data(btn: Button, slot: String) -> Variant:
	for button_id in Abilities.TRINKET_SLOTS:
		if str(Abilities.TRINKET_SLOTS[button_id]) != slot:
			continue
		var item := str(_pd().equipment.get(slot, ""))
		if item == "" or Items.use_effect_of(item) == null:
			return null
		if _in_combat():
			_report("Can't change your action bar in combat")
			return null
		btn.set_drag_preview(UI.drag_preview(item, 1))
		return {"type": "ability", "id": str(button_id), "from": -1}
	return null

func _can_equip_drop(data: Variant, slot: String) -> bool:
	if not (data is Dictionary) or data.get("type") != "inv":
		return false
	var id: String = _pd().inventory[int(data["index"])]
	return _pd().fits_slot(id, slot) and not _pd().is_slot_locked(slot)

func _is_rune(data: Variant) -> bool:
	return data is Dictionary and data.get("type") == "rune"

# --- Runes panel: sits to the right of the Character window while it's open ------

var _runes_panel: PanelContainer

func _update_runes_panel() -> void:
	var cw: PanelContainer = windows["Character"]
	if _runes_panel == null:
		_runes_panel = UI.runes_panel(190, 220, _pd().known_runes)
		add_child(_runes_panel)
	_runes_panel.visible = cw.visible
	if not cw.visible:
		return
	var vp := get_viewport().get_visible_rect().size
	var pos := cw.position + Vector2(cw.size.x + 6, 0)
	if pos.x + _runes_panel.size.x > vp.x:   # no room on the right: put it on the left
		pos.x = cw.position.x - _runes_panel.size.x - 6
	_runes_panel.position = pos

# Detect an inventory drag that was released over nothing (the game world):
# that drops the item on the floor in front of the player.
func _process(_delta: float) -> void:
	_fit_menu_bar()
	_update_runes_panel()
	if _book_dirty and windows.has("Talents") and windows["Talents"].visible:
		_refresh_spellbook()
	_update_slot_highlights()
	if _drag_inv_index == -1:
		return
	var vp := get_viewport()
	if vp.gui_is_dragging():
		return
	var idx := _drag_inv_index
	_drag_inv_index = -1
	if vp.gui_is_drag_successful():
		return
	if _mouse_over_ui():
		return
	_drop_on_floor(idx)

func _mouse_over_ui() -> bool:
	var mouse := get_viewport().get_mouse_position()
	var panels: Array = windows.values() + [esc_menu, settings_panel, map_panel, minimap]
	if _runes_panel:
		panels.append(_runes_panel)
	if chat_box:
		panels.append(chat_box)
	for p in panels:
		if p.visible and p.get_global_rect().has_point(mouse):
			return true
	if _menu_bar and (_menu_bar.get_global_transform() * Rect2(Vector2.ZERO, _menu_bar.size)).has_point(mouse):
		return true   # (uses the transform: the bar may be scaled down to fit)
	return false

func _drop_on_floor(idx: int) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or ("health" in player and player.health <= 0):
		return
	var id: String = _pd().take_inventory_item(idx)
	if id == "":
		return
	var drop := Node3D.new()
	drop.set_script(LOOT_DROP)
	drop.item_id = id
	drop.require_exit = true   # don't instantly pick it back up
	get_tree().current_scene.add_child(drop)
	var forward := -player.global_basis.z
	forward.y = 0.0
	drop.global_position = player.global_position + forward.normalized() * 1.3 + Vector3(0, -0.9, 0)

func _inventory_context_menu(index: int) -> void:
	var id: String = _pd().inventory[index]
	if id == "":
		return
	var extras: Array = []
	if Items.is_mystery_rune(id):
		extras.append(["Reveal (in the main menu)", Callable(), true])
	extras.append(["Salvage (+%d Rune Shards)" % _pd().salvage_value(id), func():
		if _pd().inventory[index] == id:
			var got: int = _pd().salvage_inventory_item(index)
			_report_ok("+%d Rune Shards" % got)])
	UI.item_menu(self, id,
		func(): _on_inventory_clicked(index),
		func():
			if _pd().inventory[index] == id:   # still the same item after confirming
				_pd().delete_inventory_item(index),
		"Delete", "", extras)

func _report_ok(msg: String) -> void:
	var gl := get_node_or_null("/root/GameLog")
	if gl:
		gl.event(msg, Color(0.75, 0.55, 1.0))

func _on_inventory_clicked(index: int, to_slot: String = "") -> void:
	var err: String = _pd().equip_from_inventory(index, to_slot)
	if err != "" and _pd().inventory[index] != "":
		_report(err)

func _on_gear_clicked(slot: String) -> void:
	var err: String = _pd().unequip(slot)
	if err != "":
		_report(err)

func _report(msg: String) -> void:
	get_node("/root/SignalBus").action_error.emit(msg)

# --- Bottom-left bar ---------------------------------------------------------

func _build_bar() -> void:
	var bar := PanelContainer.new()
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 16
	bar.offset_top = -62
	bar.offset_bottom = -14
	bar.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0.55), UI.BORDER, 1, 8))
	add_child(bar)
	_menu_bar = bar

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)

	# [window, button text, hotkey action]
	var entries := [
		["Character", "Character", "open_character"],
		["Talents", "Spellbook", "open_talents"],
		["Bank", "Bank", "open_bank"],
		["Inventory", "Inventory", "open_inventory"],
	]
	var settings := get_node("/root/Settings")
	for e in entries:
		# Two lines for the long name so the bar stays clear of the action bar.
		var two_lines: bool = str(e[1]).length() > 12
		var b := UI.button(str(e[1]).replace(" & ", " &\n") if two_lines else e[1], 11 if two_lines else 13, Vector2(70, 32))
		if two_lines:
			for s in ["normal", "hover", "pressed", "hover_pressed"]:
				var sb: StyleBoxFlat = b.get_theme_stylebox(s).duplicate()
				sb.content_margin_top = 0
				sb.content_margin_bottom = 0
				b.add_theme_stylebox_override(s, sb)
			b.add_theme_constant_override("line_spacing", -3)
		b.toggle_mode = true
		b.tooltip_text = "%s (%s)" % [e[1], settings.key_text(e[2])]
		b.pressed.connect(_toggle_window.bind(e[0]))
		row.add_child(b)
		bar_buttons[e[0]] = b
	# Details meter (damage / healing / buff uptime) - lives in the Details autoload.
	var details := UI.button("Details", 13, Vector2(70, 32))
	details.tooltip_text = "Details: damage / healing meter (%s)" % settings.key_text("open_details")
	details.pressed.connect(func():
		var d := get_node_or_null("/root/Details")
		if d:
			d.toggle_meter())
	row.add_child(details)

# The bar must never run into the action bar (hud.gd: 8 slots of 52 px, centered).
# When it doesn't fit next to it, it shrinks (anchored at its bottom-left corner).
const ACTION_BAR_HALF_W := (8 * 52.0 + 7 * 6.0 + 16.0) / 2.0
const MENU_BAR_GAP := 10.0
var _menu_bar: PanelContainer

func _fit_menu_bar() -> void:
	if _menu_bar == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var avail := vp.x * 0.5 - ACTION_BAR_HALF_W - MENU_BAR_GAP - _menu_bar.offset_left
	var w := _menu_bar.get_combined_minimum_size().x
	var s := clampf(avail / maxf(w, 1.0), 0.55, 1.0)
	if _menu_bar.pivot_offset.y != _menu_bar.size.y:
		_menu_bar.pivot_offset = Vector2(0, _menu_bar.size.y)
	if not is_equal_approx(_menu_bar.scale.x, s):
		_menu_bar.scale = Vector2(s, s)

# --- Windows -----------------------------------------------------------------

func _build_windows() -> void:
	var vp := get_viewport().get_visible_rect().size
	var w := vp.x * WINDOW_WIDTH_FRACTION

	# Gear and stats side by side, so the window fits on small screens.
	var character := UI.window("Character", Vector2(maxf(w, 600.0), 0), _close_window.bind("Character"), true)
	var preview := UI.character_preview(Vector2(100, 220))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(UI.gear_layout(34, 12, 6, preview))
	_stat_panel = UI.stat_panel(205)
	_stat_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_stat_panel)
	character.get_meta("content").add_child(row)
	windows["Character"] = character

	windows["Talents"] = _build_spellbook(maxf(w, 380.0), vp.y * 0.5)

	var bank := UI.window("Bank", Vector2(w, 0), _close_window.bind("Bank"), true)
	var slot_size := 30.0
	var usable := w - 20.0 - 14.0   # window margins + scrollbar
	var cols := maxi(4, int(usable / (slot_size + 4.0)))
	bank.get_meta("content").add_child(UI.bank_grid(cols, slot_size, vp.y * 0.40, false))
	windows["Bank"] = bank

	var inventory := UI.window("Inventory", Vector2(w, 0), _close_window.bind("Inventory"), true)
	inventory.get_meta("content").add_child(UI.item_grid(20, 5, 44, "Inventory"))
	windows["Inventory"] = inventory

	for n in windows:
		windows[n].visible = false
		add_child(windows[n])

func _toggle_window(name: String) -> void:
	if windows[name].visible:
		_close_window(name)
	else:
		_open_window(name)

func _open_window(name: String) -> void:
	var win: PanelContainer = windows[name]
	win.visible = true
	win.reset_size()
	if not _positioned.has(name):
		win.position = _free_spot(win)
		_positioned[name] = true
	win.position = _clamp_to_screen(win, win.position)
	win.move_to_front()
	bar_buttons[name].set_pressed_no_signal(true)
	open_order.erase(name)
	open_order.append(name)

# --- Spellbook (P): swap learned abilities on the action bar, out of combat -------------
# Every ability you know, grouped by book (spells taught by runes have their own
# "Rune Spells" section). Drag one onto the action bar to put it there; drag a
# bar button onto the spellbook to take it off. Locked in combat.
# Next to the abilities: your talents, to read only (TALENT_VIEW). Skill Cards
# and talents are changed in the main menu.

const Abilities = preload("res://scripts/abilities.gd")
const Categories = preload("res://scripts/categories.gd")
const TALENT_VIEW = preload("res://scripts/ui/talent_tree_view.gd")
var _book_list: VBoxContainer
var _book_status: Label
var _book_dirty := true
var _talent_view: VBoxContainer

## `width` = the abilities column; the talents column is added to its right.
func _build_spellbook(width: float, list_height: float) -> PanelContainer:
	var tree_height := maxf(list_height - 20.0, 280.0)
	var win := UI.window("Spellbook", Vector2(width + TALENT_VIEW.width_for(tree_height) + 36.0, 0),
		_close_window.bind("Talents"), true)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	win.get_meta("content").add_child(columns)
	var content := VBoxContainer.new()   # left: abilities
	content.add_theme_constant_override("separation", 10)
	columns.add_child(content)
	columns.add_child(VSeparator.new())
	_talent_view = TALENT_VIEW.new()     # right: talents (read only)
	_talent_view.tree_height = tree_height
	columns.add_child(_talent_view)
	_book_status = UI.label("", 12, UI.TEXT_DIM)
	_book_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_book_status.custom_minimum_size = Vector2(width - 24.0, 0)
	content.add_child(_book_status)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(width - 20.0, list_height)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_book_list = VBoxContainer.new()
	_book_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_book_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_book_list)
	var note := UI.label("Skill Cards and talents are changed in the main menu.", 11, UI.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(width - 24.0, 0)
	content.add_child(note)
	# Dropping a button dragged off the action bar here takes it off the bar.
	for c in [win, scroll, _book_list]:
		(c as Control).set_drag_forwarding(func(_p): return null,
			func(_p, data): return data is Dictionary and data.get("type") == "hud_bar" and not _in_combat(),
			func(_p, data): _pd().clear_action_slot(int(data["slot"]) - 1))
	_pd().changed_late.connect(func(): _book_dirty = true)
	get_node("/root/SignalBus").combat_state_changed.connect(func(_c): _book_dirty = true)
	return win

func _in_combat() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	return p != null and p.has_method("is_in_combat") and p.is_in_combat()

func _refresh_spellbook() -> void:
	_book_dirty = false
	if _talent_view:
		_talent_view.refresh()
	for c in _book_list.get_children():
		c.queue_free()
	var pd := _pd()
	var locked := _in_combat()
	_book_status.text = "In combat: abilities can't be changed until the fight ends." if locked \
		else "Drag an ability onto your action bar. Drag a bar button here to take it off."
	_book_status.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4) if locked else UI.TEXT_DIM)
	var cats: Array = Categories.ORDER.duplicate()
	cats.append(Categories.RUNE)   # spells taught by runes on your gear
	cats.append("")   # abilities without a book
	var learned := func(id: String) -> bool: return pd.has_ability(id) and not Abilities.is_trinket_slot(id)
	for cat in cats:
		var specs: Array = Abilities.specs_in(cat, learned)   # only specs you know something from
		if specs.is_empty():
			continue
		var col := Categories.color(cat) if cat != "" else Color.WHITE
		_book_list.add_child(UI.label(Categories.cat_name(cat) if cat != "" else "Other", 14, col.lightened(0.3)))
		for spec in specs:
			if spec[0] != "":
				_book_list.add_child(UI.spec_divider(spec[0], col.lightened(0.15), 11))
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 6)
			flow.add_theme_constant_override("v_separation", 6)
			_book_list.add_child(flow)
			for id in spec[1]:
				flow.add_child(_spellbook_slot(id, locked, pd.action_bar.has(id)))

func _spellbook_slot(id: String, locked: bool, on_bar: bool) -> Button:
	var s := Abilities.make_slot(40)
	Abilities.set_slot_ability(s, id)
	if on_bar:
		s.add_theme_stylebox_override("normal", UI.box(Color(0.06, 0.065, 0.085, 0.9), UI.ACCENT.darkened(0.2), 2, 6))
	if locked:
		s.get_node("AbilityIcon").modulate.a = 0.45
	s.set_drag_forwarding(
		func(_p):
			if _in_combat():
				_report("Can't change abilities in combat")
				return null
			var preview := Control.new()
			var icon := Control.new()
			icon.size = Vector2(40, 40)
			icon.position = -icon.size / 2.0
			icon.modulate.a = 0.85
			icon.draw.connect(func(): Abilities.draw_icon(icon, id))
			preview.add_child(icon)
			s.set_drag_preview(preview)
			return {"type": "ability", "id": id, "from": -1},
		func(_p, data): return data is Dictionary and data.get("type") == "hud_bar" and not _in_combat(),
		func(_p, data): _pd().clear_action_slot(int(data["slot"]) - 1))
	return s

## While an item (or rune) is being dragged and the Character window is open,
## the gear slots it fits into glow.
var _highlight_on := false

func _update_slot_highlights() -> void:
	var active: bool = windows.has("Character") and windows["Character"].visible and get_viewport().gui_is_dragging()
	if not active and not _highlight_on:
		return
	_highlight_on = active
	if active:
		UI.highlight_drag_targets(get_viewport(), _gear_buttons, _pd())
	else:
		for b in _gear_buttons:
			UI.set_slot_highlight(b, false)

# --- Minimap (top-right) + local map (M) --------------------------------------------

const MAP_DATA = preload("res://scripts/ui/map_data.gd")
const MAP_VIEW = preload("res://scripts/ui/map_view.gd")
const MINIMAP_SIZE := 180.0

var map_data: Node
var minimap: Control
var map_panel: PanelContainer
var _map_title: Label

func _build_maps() -> void:
	map_data = MAP_DATA.new()
	add_child(map_data)

	minimap = MAP_VIEW.new()
	minimap.data = map_data
	minimap.mini = true
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.offset_left = -MINIMAP_SIZE - 16
	minimap.offset_right = -16
	minimap.offset_top = 16
	minimap.offset_bottom = 16 + MINIMAP_SIZE
	add_child(minimap)
	var hint := UI.label("", 11, UI.TEXT_DIM)
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.offset_left = -MINIMAP_SIZE - 16
	hint.offset_right = -16
	hint.offset_top = 16 + MINIMAP_SIZE + 2
	hint.offset_bottom = 16 + MINIMAP_SIZE + 18
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(hint)
	var set_hint := func(): hint.text = "Map (%s)" % get_node("/root/Settings").key_text("open_map")
	set_hint.call()
	get_node("/root/Settings").keybinds_changed.connect(set_hint)

	map_panel = PanelContainer.new()
	map_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_panel.anchor_left = 0.12
	map_panel.anchor_right = 0.88
	map_panel.anchor_top = 0.08
	map_panel.anchor_bottom = 0.84
	var sb := UI.box(UI.PANEL_BG, UI.BORDER, 2, 10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 12
	map_panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	map_panel.add_child(v)
	var head := HBoxContainer.new()
	_map_title = UI.label("Map", 20, UI.ACCENT)
	_map_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_map_title)
	var close := UI.button("X", 16, Vector2(34, 34))
	close.pressed.connect(func(): map_panel.visible = false)
	head.add_child(close)
	v.add_child(head)
	var full := MAP_VIEW.new()
	full.data = map_data
	full.mini = false
	full.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(full)
	v.add_child(UI.label("You · enemies · elites · chests · exit.  Dark areas are unexplored.", 12, UI.TEXT_DIM))
	map_panel.visible = false
	add_child(map_panel)

func toggle_map() -> void:
	map_panel.visible = not map_panel.visible
	if map_panel.visible:
		var scene := get_tree().current_scene
		var title: Variant = scene.get("map_title") if scene else null
		var depth: Variant = scene.get("depth") if scene else null
		if title != null and str(title) != "":
			_map_title.text = "Map — %s" % str(title)
		elif depth != null:
			_map_title.text = "Map — The Crypt, Floor %d" % int(depth)
		else:
			_map_title.text = "Map"
		map_panel.move_to_front()

# --- Window placement ----------------------------------------------------------
# Windows open in the free area between the HUD (health/resources top-left,
# chat bottom-left, action bar bottom-center): from the right edge leftwards,
# next to windows that are already open, instead of piling on each other.

const SCREEN_MARGIN := 12.0
const TOP_RESERVED := 44.0       # dungeon header
const BOTTOM_RESERVED := 112.0   # action bar + XP bar

func _usable_rect() -> Rect2:
	var vp := get_viewport().get_visible_rect().size
	return Rect2(Vector2(SCREEN_MARGIN, TOP_RESERVED),
		Vector2(vp.x - SCREEN_MARGIN * 2.0, vp.y - TOP_RESERVED - BOTTOM_RESERVED))

func _clamp_to_screen(win: Control, pos: Vector2) -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	var r := _usable_rect()
	var max_y := maxf(r.end.y - win.size.y, TOP_RESERVED)
	if win.size.y > r.size.y:   # taller than the free area: use the full height
		max_y = maxf(vp.y - win.size.y - SCREEN_MARGIN, 0.0)
	return Vector2(clampf(pos.x, SCREEN_MARGIN, maxf(vp.x - win.size.x - SCREEN_MARGIN, SCREEN_MARGIN)),
		clampf(pos.y, TOP_RESERVED, max_y))

## First free spot for `win`: right edge first, then left of other open windows.
func _free_spot(win: Control) -> Vector2:
	var r := _usable_rect()
	var taken: Array[Rect2] = []
	for n in windows:
		var o: Control = windows[n]
		if o != win and o.visible:
			taken.append(Rect2(o.position, o.size).grow(4.0))
	if _runes_panel and _runes_panel.visible:
		taken.append(Rect2(_runes_panel.position, _runes_panel.size).grow(4.0))
	# HUD you should never have covered: health / resources / buffs, the chat.
	var hud: Array[Rect2] = [Rect2(0, 0, 350, 170)]
	if minimap:
		hud.append(minimap.get_global_rect().grow_individual(4, 4, 4, 20))
	var attr := get_node_or_null("/root/AttributeScreen")
	if attr:
		for c in [attr.get("_panel"), attr.get("_pill")]:
			if c is Control and c.visible:
				hud.append(c.get_global_rect().grow(4.0))
	if chat_box:
		hud.append(chat_box.get_global_rect().grow(4.0))
	# The Character window keeps room on its right for the Runes panel.
	var need := win.size + (Vector2(196, 0) if win == windows.get("Character") else Vector2.ZERO)
	# Scan the free area (right -> left, top -> bottom) for the spot that
	# covers the least; the first spot covering nothing wins right away.
	var best := Vector2(r.end.x - need.x, r.position.y)
	var best_score := INF
	var x := r.end.x - need.x
	while x >= r.position.x - 0.5:
		var y := r.position.y
		var y_max := maxf(r.end.y - need.y, r.position.y)
		while y <= y_max + 0.5:
			var cand := Rect2(Vector2(x, y), need)
			var score := 0.0
			for t in taken:
				score += cand.intersection(t).get_area()
			for h in hud:
				score += cand.intersection(h).get_area() * 3.0   # covering the HUD is worse
			if score < best_score:
				best_score = score
				best = cand.position
				if score <= 0.0:
					return best
			y += 20.0
		x -= 20.0
	return best

func _close_window(name: String) -> void:
	windows[name].visible = false
	bar_buttons[name].set_pressed_no_signal(false)
	open_order.erase(name)

# --- Esc menu ----------------------------------------------------------------

func _build_esc_menu() -> void:
	esc_menu = _small_panel("Menu")
	esc_menu.offset_top = -150
	esc_menu.offset_bottom = 130
	var content: VBoxContainer = esc_menu.get_meta("content")
	var resume := UI.button("Resume", 18, Vector2(0, 42))
	resume.pressed.connect(_hide_esc)
	content.add_child(resume)
	var settings := UI.button("Settings", 18, Vector2(0, 42))
	settings.pressed.connect(_open_settings)
	content.add_child(settings)
	var macros := UI.button("Macros", 18, Vector2(0, 42))
	macros.pressed.connect(_open_macros)
	content.add_child(macros)
	var quit := UI.button("Quit", 18, Vector2(0, 42))
	quit.pressed.connect(_quit_to_menu)
	content.add_child(quit)
	add_child(esc_menu)
	esc_menu.visible = false

func _build_settings() -> void:
	settings_panel = _small_panel("Settings")
	settings_panel.offset_left = -250
	settings_panel.offset_right = 250
	settings_panel.offset_top = -250
	settings_panel.offset_bottom = 250
	var content: VBoxContainer = settings_panel.get_meta("content")
	content.add_child(get_node("/root/Settings").build_settings_ui())
	var back := UI.button("Back", 18, Vector2(0, 42))
	back.pressed.connect(_back_from_settings)
	content.add_child(back)
	add_child(settings_panel)
	settings_panel.visible = false

func _small_panel(title: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -130
	p.offset_right = 130
	p.offset_top = -130
	p.offset_bottom = 110
	var sb := UI.box(UI.PANEL_BG, UI.BORDER, 2, 10)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var t := UI.label(title, 22, UI.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	p.set_meta("content", v)
	return p

const HOTKEYS := {"open_character": "Character", "open_inventory": "Inventory",
	"open_bank": "Bank", "open_talents": "Talents"}

func _unhandled_input(event: InputEvent) -> void:
	# C / I / B / P (rebindable) toggle the windows. Typing in chat never gets here.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("open_map"):
			get_viewport().set_input_as_handled()
			toggle_map()
			return
		if event.keycode == KEY_ESCAPE and map_panel and map_panel.visible:
			get_viewport().set_input_as_handled()
			map_panel.visible = false   # Esc closes the map first
			return
		for action in HOTKEYS:
			if event.is_action_pressed(action):
				get_viewport().set_input_as_handled()
				_toggle_window(HOTKEYS[action])
				return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		var player := get_tree().get_first_node_in_group("player")
		if player and player.has_method("cancel_placement") and player.cancel_placement():
			return   # Esc cancels spell placement first
		if settings_panel.visible:
			_back_from_settings()
		elif esc_menu.visible:
			_hide_esc()
		elif not open_order.is_empty():
			_close_window(open_order.back())   # Esc closes the latest window first
		elif player and player.has_method("clear_target") and player.clear_target():
			pass   # then clears your target (like WoW)
		else:
			esc_menu.visible = true
			esc_menu.move_to_front()

func _hide_esc() -> void:
	esc_menu.visible = false
	settings_panel.visible = false

func _open_settings() -> void:
	esc_menu.visible = false
	settings_panel.visible = true
	settings_panel.move_to_front()

const MacroWindow = preload("res://scripts/ui/macro_window.gd")

## Macros: write them here, then drag one onto an action-bar slot.
func _open_macros() -> void:
	_hide_esc()
	MacroWindow.open(self, true)

func _back_from_settings() -> void:
	settings_panel.visible = false
	esc_menu.visible = true
	esc_menu.move_to_front()

func _quit_to_menu() -> void:
	# GameManager handles it: equipped gear stays on, the bag goes to the bank.
	get_node("/root/GameManager").go_to_menu()
