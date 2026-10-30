extends CanvasLayer

# In-game UI: the chat and meter panels (with the micro menu: Character /
# Spellbook / Bank / Bags), small movable windows, the minimap and map, and an
# Esc menu (Resume / Settings / Quit).
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
## Windows, the map and the Esc menu sit on a layer of their own, above the HUD,
## the damage meter and the training panel (under Move UI and UI Options).
const WINDOW_LAYER := 20
var win_layer: CanvasLayer

const DEBUG_OVERLAY = preload("res://scripts/ui/debug_overlay.gd")
const COMBAT_VIGNETTE = preload("res://scripts/ui/combat_vignette.gd")
var chat_box: PanelContainer

func _ready() -> void:
	win_layer = CanvasLayer.new()
	win_layer.name = "Windows"
	win_layer.layer = WINDOW_LAYER
	add_child(win_layer)
	_build_panels()
	add_child(DEBUG_OVERLAY.new())
	add_child(COMBAT_VIGNETTE.new())   # red screen edges while in combat
	_build_maps()
	_build_windows()
	get_node("/root/Net").inspect_received.connect(_on_inspect)   # (right-click a party frame)
	_build_esc_menu()
	_build_settings()
	_wire_items()
	# Settings > Interface > HUD opacity: everything here except the Esc menu,
	# Settings and the map (those stay solid so they're always readable).
	var settings := get_node("/root/Settings")
	var fade := func(c: Node):
		if c is CanvasItem and c != esc_menu and c != settings_panel and c != map_panel and not (c is Node and c.get_script() == MAP_DATA):
			settings.register_hud(c)
	for c in get_children() + win_layer.get_children():
		fade.call(c)
	child_entered_tree.connect(fade)
	win_layer.child_entered_tree.connect(fade)
	# Settings > Interface > Move UI: these can be dragged too.
	settings.move_ui_requested.connect(_start_move_ui)
	minimap.set_meta("ui_options", "minimap")
	UIInstaller.open_if_new.call_deferred(get_tree())   # first time in a dungeon: pick a layout
	UILayout.register.call_deferred(get_tree(), minimap, "minimap", "Minimap")

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
		UISkin.skin_window(_runes_panel)
		win_layer.add_child(_runes_panel)
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
	_follow_minimap()
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
	for p in [chat_panel, meter_panel]:
		if p and p.visible and p.get_global_rect().has_point(mouse):
			return true
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

# --- Panels and micro menu -------------------------------------------------------
# Bottom-left: the chat panel (chat + an info strip whose left end is the micro
# menu: Character / Spellbook / Bank / Bags / Meter). Bottom-right: the meter
# panel (the damage meter docked in it). Both are HUD elements (scripts/ui/hud/).

const CHAT_PANEL = preload("res://scripts/ui/hud/chat_panel.gd")
const METER_PANEL = preload("res://scripts/ui/hud/meter_panel.gd")
var chat_panel: HudElement
var meter_panel: HudElement

func _build_panels() -> void:
	chat_panel = CHAT_PANEL.new()
	add_child(chat_panel)
	chat_box = chat_panel.chat_box
	meter_panel = METER_PANEL.new()
	add_child(meter_panel)
	# [window, button text, hotkey action]
	var entries := [
		["Character", "Char", "open_character"],
		["Talents", "Book", "open_talents"],
		["Bank", "Bank", "open_bank"],
		["Inventory", "Bags", "open_inventory"],
	]
	var settings := get_node("/root/Settings")
	var names := {"Character": "Character", "Talents": "Spellbook", "Bank": "Bank", "Inventory": "Inventory"}
	for e in entries:
		var b: Button = chat_panel.add_button(e[1], "%s (%s)" % [names[e[0]], settings.key_text(e[2])])
		b.toggle_mode = true
		b.pressed.connect(_toggle_window.bind(e[0]))
		bar_buttons[e[0]] = b
	# Details meter (damage / healing / buff uptime) - lives in the Details autoload.
	var details: Button = chat_panel.add_button("Meter", "Details: damage / healing meter (%s)" % settings.key_text("open_details"))
	details.pressed.connect(func():
		var d := get_node_or_null("/root/Details")
		if d:
			d.toggle_meter())

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

	windows["Talents"] = _build_spellbook(maxf(w, 440.0), vp.y * 0.66)   # (large: easy to read)

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
		UISkin.skin_window(windows[n])
		win_layer.add_child(windows[n])

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
# Next to the abilities: your talents (TALENT_VIEW; Reset and changes in the training
# area only). A search bar frames matching abilities and talents. Tabs at the bottom:
# Abilities & Talents, Runes (see below). Skill Cards
# and talents are changed in the main menu.

const Abilities = preload("res://scripts/abilities.gd")
const Categories = preload("res://scripts/categories.gd")
const TALENT_VIEW = preload("res://scripts/ui/talent_tree_view.gd")
var _book_list: VBoxContainer
var _book_status: Label
var _book_dirty := true
var _talent_view: VBoxContainer
var _book_note: Label   # where Skill Cards / talents are changed
var _book_query := ""   # the search bar: matching abilities and talents framed, the rest dimmed
const Keywords = preload("res://scripts/core/keywords.gd")
const BOOK_SEARCH_COL := Color(0.4, 1.0, 0.6)   # (the main menu book's search colour)
const SPELLBOOK_SLOT := 48.0   # ability buttons in the Spellbook
const InspectWindow = preload("res://scripts/ui/inspect_window.gd")

## A party member's snapshot arrived (right-clicked their frame): show it.
func _on_inspect(member: int, data: Dictionary) -> void:
	UISkin.skin_window(InspectWindow.open(win_layer, member, data))

## `width` = the abilities column; the talents column is added to its right.
func _build_spellbook(width: float, list_height: float) -> PanelContainer:
	var tree_height := maxf(list_height - 20.0, 280.0)
	var win := UI.window("Spellbook", Vector2(width + TALENT_VIEW.width_for(tree_height) + 36.0, 0),
		_close_window.bind("Talents"), true)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	win.get_meta("content").add_child(columns)
	_book_pages["book"] = columns
	var content := VBoxContainer.new()   # left: abilities
	content.add_theme_constant_override("separation", 10)
	columns.add_child(content)
	columns.add_child(VSeparator.new())
	_talent_view = TALENT_VIEW.new()     # right: talents (read only)
	_talent_view.tree_height = tree_height
	_talent_view.message.connect(_report)
	columns.add_child(_talent_view)
	# Search (as in the main menu's book): name or keyword, e.g. "chill".
	var search := LineEdit.new()
	search.placeholder_text = "Search abilities and talents  (name or keyword, e.g. chill)"
	search.clear_button_enabled = true
	search.custom_minimum_size = Vector2(width - 24.0, 28)
	search.text_changed.connect(func(t: String):
		_book_query = t.strip_edges()
		_talent_view.set_search(_book_query)
		_book_dirty = true)
	content.add_child(search)
	_book_status = UI.label("", 14, UI.TEXT_DIM)
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
	_book_note = UI.label("", 13, UI.TEXT_DIM)
	var note := _book_note
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(width - 24.0, 0)
	content.add_child(note)
	# Dropping a button dragged off the action bar here takes it off the bar.
	for c in [win, scroll, _book_list]:
		(c as Control).set_drag_forwarding(func(_p): return null,
			func(_p, data): return data is Dictionary and data.get("type") == "hud_bar" and not _in_combat(),
			func(_p, data): _pd().clear_action_slot(int(data["slot"]) - 1))
	_pd().changed_late.connect(func(): _book_dirty = true)
	get_node("/root/SignalBus").combat_state_changed.connect(func(_c):
		_book_dirty = true
		_update_rune_lock())
	_build_book_tabs(win.get_meta("content"), width + TALENT_VIEW.width_for(tree_height) + 10.0, tree_height + 90.0)
	return win

# --- Spellbook tabs (bottom): Abilities & Talents, Runes ----------------------------
# Runes: the main menu's Rune Management in the window (RuneManager.embed): every
# rune, crafting, engraving onto your gear and moving runes. Locked in combat.

const RuneManager = preload("res://scripts/ui/rune_manager.gd")
var _book_pages := {}      # "book" / "runes" -> page
var _book_tab_buttons := {}
var _rune_lock: Control    # covers the Runes page in combat

func _build_book_tabs(content: Control, width: float, height: float) -> void:
	var runes := Control.new()
	runes.custom_minimum_size = Vector2(width, height)
	runes.visible = false
	content.add_child(runes)
	_book_pages["runes"] = runes
	RuneManager.embed(runes, func(msg: String, ok: bool):
		if ok:
			_report_ok(msg)
		else:
			_report(msg))
	_rune_lock = ColorRect.new()
	(_rune_lock as ColorRect).color = Color(0, 0, 0, 0.6)
	_rune_lock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rune_lock.mouse_filter = Control.MOUSE_FILTER_STOP
	var why := UI.label("In combat: runes can't be changed until the fight ends.", 16, Color(1.0, 0.5, 0.4))
	why.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	why.grow_horizontal = Control.GROW_DIRECTION_BOTH
	why.grow_vertical = Control.GROW_DIRECTION_BOTH
	_rune_lock.add_child(why)
	runes.add_child(_rune_lock)
	_update_rune_lock()
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	content.add_child(tabs)
	for t in [["book", "Abilities & Talents"], ["runes", "Runes"]]:
		var b := UI.button(str(t[1]), 13, Vector2(170, 28))
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_show_book_page.bind(str(t[0])))
		tabs.add_child(b)
		_book_tab_buttons[t[0]] = b
	_show_book_page("book")

func _show_book_page(page: String) -> void:
	for k in _book_pages:
		(_book_pages[k] as Control).visible = k == page
	for k in _book_tab_buttons:
		(_book_tab_buttons[k] as Button).set_pressed_no_signal(k == page)

func _update_rune_lock() -> void:
	if _rune_lock:
		_rune_lock.visible = _in_combat()

func _in_combat() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	return p != null and p.has_method("is_in_combat") and p.is_in_combat()

func _refresh_spellbook() -> void:
	_book_dirty = false
	# The training area is for trying builds: talents can be changed there.
	var gm := get_node_or_null("/root/GameManager")
	var training: bool = gm != null and gm.in_training()
	_book_note.text = "Talents: click to change them (training area only). Skill Cards are changed in the main menu." if training \
		else "Skill Cards and talents are changed in the main menu (talents also in the training area)."
	if _talent_view:
		_talent_view.set_editable(training)
		_talent_view.refresh()
	for c in _book_list.get_children():
		c.queue_free()
	var pd := _pd()
	var locked := _in_combat()
	_book_status.text = "In combat: abilities can't be changed until the fight ends." if locked \
		else "Drag an ability onto your action bar. Drag a bar button here to take it off."
	_book_status.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4) if locked else UISkin.DIM)
	var cats: Array = Categories.ORDER.duplicate()
	cats.append(Categories.RUNE)   # spells taught by runes on your gear
	cats.append("")   # abilities without a book
	# (Wheel moves sit under their weapon's dropdown, not in the list.)
	var learned := func(id: String) -> bool: return pd.has_ability(id) and not Abilities.is_trinket_slot(id) and Abilities.listed_in_book(id)
	for cat in cats:
		var specs: Array = Abilities.specs_in(cat, learned)   # only specs you know something from
		if specs.is_empty():
			continue
		var col := Categories.color(cat) if cat != "" else Color.WHITE
		_book_list.add_child(UI.label(Categories.cat_name(cat) if cat != "" else "Other", 17, col.lightened(0.3)))
		for spec in specs:
			if spec[0] != "":
				_book_list.add_child(UI.spec_divider(spec[0], col.lightened(0.15), 13))
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 6)
			flow.add_theme_constant_override("v_separation", 6)
			_book_list.add_child(flow)
			for id in spec[1]:
				var s := _spellbook_slot(id, locked, pd.action_bar.has(id))
				flow.add_child(s)
				if Abilities.WHEEL_FORMS.has(id):
					s.pressed.connect(_toggle_wheel_weapon.bind(id))   # click a Wheel weapon to show its moves
			# The Wheel's weapons drop down to show their moves; drag one onto the bar.
			for id in spec[1]:
				if Abilities.WHEEL_FORMS.has(id) and _wheel_open.get(id, false):
					_book_list.add_child(UI.label("%s's moves" % Abilities.ability_name(id), 13, UI.TEXT_DIM))
					var moves := HFlowContainer.new()
					moves.add_theme_constant_override("h_separation", 6)
					moves.add_theme_constant_override("v_separation", 6)
					_book_list.add_child(moves)
					for move in Abilities.WHEEL_FORMS[id]:
						moves.add_child(_spellbook_slot(str(move), locked, pd.action_bar.has(Abilities.bar_id(str(move)))))
			# The Brawler's Chain: what each ending makes (shown, not dragged: no buttons).
			if spec[1].has("punch"):
				for part in Abilities.brawler_move_table():
					_book_list.add_child(UI.label(str(part[0]), 13, UI.TEXT_DIM))
					var row := HFlowContainer.new()
					row.add_theme_constant_override("h_separation", 6)
					row.add_theme_constant_override("v_separation", 6)
					_book_list.add_child(row)
					for move in part[1]:
						row.add_child(_spellbook_slot(str(move), locked, false))
			# The Rogue's Kill forms: what each builder becomes in a Kill window (shown, not dragged: no buttons).
			if spec[1].has("cut"):
				for part in Abilities.rogue_kill_table():
					_book_list.add_child(UI.label(str(part[0]), 13, UI.TEXT_DIM))
					var krow := HFlowContainer.new()
					krow.add_theme_constant_override("h_separation", 6)
					krow.add_theme_constant_override("v_separation", 6)
					_book_list.add_child(krow)
					for form in part[1]:
						krow.add_child(_spellbook_slot(str(form), locked, false))
	UISkin.restyle(_book_list)

## Weapon id -> its dropdown is open (the Wheel, Martial warrior).
var _wheel_open := {}

func _toggle_wheel_weapon(weapon: String) -> void:
	_wheel_open[weapon] = not bool(_wheel_open.get(weapon, false))
	_book_dirty = true

func _spellbook_slot(id: String, locked: bool, on_bar: bool) -> Button:
	var s := Abilities.make_slot(SPELLBOOK_SLOT)
	Abilities.set_slot_ability(s, id)
	if on_bar:
		s.add_theme_stylebox_override("normal", UI.box(Color(0.06, 0.065, 0.085, 0.9), UI.ACCENT.darkened(0.2), 2, 6))
	if locked:
		s.get_node("AbilityIcon").modulate.a = 0.45
	if _book_query != "":
		if Keywords.matches("a:" + id, _book_query):
			s.add_theme_stylebox_override("normal", UI.box(Color(BOOK_SEARCH_COL, 0.1), BOOK_SEARCH_COL, 2, 6))
		else:
			s.modulate.a = 0.3
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

var _map_hint: Label           # the clock under the minimap
var _map_name: Label           # the dungeon's name above it
var _clock_t := 0.0

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
	# A 1 px frame, the dungeon's name above it and a clock under it (UI Options > Minimap).
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", UISkin.backdrop(0.0))
	minimap.add_child(frame)
	_map_name = UISkin.label("", 12, Color(1.0, 0.85, 0.5))
	_map_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_map_name)
	var hint := UISkin.label("", 11, UISkin.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	_map_hint = hint
	var set_hint := func(): minimap.tooltip_text = "Map (%s)" % get_node("/root/Settings").key_text("open_map")
	set_hint.call()
	get_node("/root/Settings").keybinds_changed.connect(set_hint)
	get_node("/root/Settings").ui_config_changed.connect(func(elem: String):
		if elem == "minimap" or elem == "" or elem == "general":
			_apply_minimap())
	_apply_minimap()

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
	UISkin.skin_window(map_panel)
	win_layer.add_child(map_panel)

## Size from UI Options > Minimap.
func _apply_minimap() -> void:
	var s := float(UIConfig.value("minimap", "size"))
	minimap.custom_minimum_size = Vector2(s, s)
	minimap.size = Vector2(s, s)
	minimap.visible = bool(UIConfig.value("minimap", "enabled"))
	_map_name.visible = minimap.visible and bool(UIConfig.value("minimap", "show_name"))
	_map_hint.visible = minimap.visible and bool(UIConfig.value("minimap", "show_clock"))
	_clock_t = 0.0

## The name and clock stay with the minimap when Move UI moves it.
func _follow_minimap() -> void:
	if minimap == null or _map_hint == null:
		return
	var r := minimap.get_global_rect()
	_map_name.size = Vector2(r.size.x, 16)
	_map_name.global_position = r.position - Vector2(0, 17) if r.position.y > 20.0 else r.position + Vector2(0, 2)
	_map_hint.size = Vector2(r.size.x, 16)
	_map_hint.global_position = Vector2(r.position.x, r.end.y + 1)
	_clock_t -= get_process_delta_time()
	if _clock_t > 0.0:
		return
	_clock_t = 1.0
	var t := Time.get_time_dict_from_system()
	_map_hint.text = "%02d:%02d" % [int(t["hour"]), int(t["minute"])]
	var scene := get_tree().current_scene
	var title: Variant = scene.get("map_title") if scene else null
	var depth: Variant = scene.get("depth") if scene else null
	_map_name.text = str(title) if title != null and str(title) != "" else ("Floor %d" % int(depth) if depth != null else "")

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
# Windows open in the free area between the HUD (chat bottom-left, meter
# bottom-right, frames and action bars bottom-center): from the right edge leftwards,
# next to windows that are already open, instead of piling on each other.

const SCREEN_MARGIN := 12.0
const TOP_RESERVED := 44.0       # dungeon header
const BOTTOM_RESERVED := 150.0   # action bars, unit frames and cast bars

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
	# HUD you should never have covered: the minimap, the chat and meter panels.
	var hud: Array[Rect2] = []
	if meter_panel and meter_panel.visible:
		hud.append(meter_panel.get_global_rect().grow(4.0))
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
	esc_menu.offset_left = -110
	esc_menu.offset_right = 110
	esc_menu.offset_top = -105
	esc_menu.offset_bottom = 105
	var content: VBoxContainer = esc_menu.get_meta("content")
	for e in [["Resume", _hide_esc], ["Settings", _open_settings], ["Macros", _open_macros], ["Quit", _quit_to_menu]]:
		var b := UIWindow.button(e[0], Vector2(0, 32))
		b.pressed.connect(e[1])
		content.add_child(b)
	win_layer.add_child(esc_menu)
	esc_menu.visible = false

func _build_settings() -> void:
	settings_panel = _small_panel("Settings")
	settings_panel.offset_left = -250
	settings_panel.offset_right = 250
	settings_panel.offset_top = -250
	settings_panel.offset_bottom = 250
	var content: VBoxContainer = settings_panel.get_meta("content")
	content.add_child(get_node("/root/Settings").build_settings_ui())
	var back := UIWindow.button("Back", Vector2(0, 32))
	back.pressed.connect(_back_from_settings)
	content.add_child(back)
	UISkin.skin_window(settings_panel)
	win_layer.add_child(settings_panel)
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
	p.add_theme_stylebox_override("panel", UISkin.backdrop(0.97, 12))
	p.theme = UISkin.theme()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var t := UISkin.label(title, 16, UISkin.accent())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var line := ColorRect.new()
	line.color = UISkin.INNER
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(line)
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
		if InspectWindow.is_open(win_layer):
			InspectWindow.close(win_layer)
		elif settings_panel.visible:
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

## Settings > Interface > Move UI: close the menus and let the HUD be dragged around.
func _start_move_ui() -> void:
	if _in_combat():
		get_node("/root/SignalBus").action_error.emit("Can't move the interface in combat")
		return
	_hide_esc()
	UILayout.of(get_tree()).start_edit()

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
	UISkin.skin_window(MacroWindow.open(self, true))

func _back_from_settings() -> void:
	settings_panel.visible = false
	esc_menu.visible = true
	esc_menu.move_to_front()

func _quit_to_menu() -> void:
	# GameManager handles it: equipped gear stays on, the bag goes to the bank.
	get_node("/root/GameManager").go_to_menu()
