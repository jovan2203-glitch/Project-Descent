extends "res://scripts/menu/menu_part.gd"
class_name BankPage

# The Bank page: shows your items; Ctrl+click multi-selects, drag to the trash.

var _bank_buttons: Array[Button] = []
var _bank_selected := {}     # bank index -> true

func _wire_bank() -> void:
	var pd := menu.get_node("/root/PlayerData")
	for b in menu.pages["Bank"].find_children("*", "Button", true, false):
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
	pd.changed_late.connect(_refresh_if_shown.bind(menu.pages["Bank"], _refresh_bank))
	_refresh_bank()

func _on_bank_clicked(idx: int) -> void:
	var pd := menu.get_node("/root/PlayerData")
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
	var pd := menu.get_node("/root/PlayerData")
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
	var moved: Array[int] = menu.get_node("/root/PlayerData").move_bank_items(indices, to)
	# Keep a multi-selection on the items that moved.
	_bank_selected.clear()
	if moved.size() > 1:
		for i in moved:
			_bank_selected[i] = true
	_refresh_bank()

func _bank_context_menu(idx: int) -> void:
	var pd := menu.get_node("/root/PlayerData")
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
	var extras: Array = []
	if n == 1 and Items.is_mystery_rune(id):
		extras.append(["Reveal Rune", func():
			_bank_selected.clear()
			_refresh_bank()
			RuneScreens.open_reveal(menu.ui, {"where": "bank", "index": idx}, func(msg: String):
				menu._toast_ok(msg)
				_refresh_bank())])
	var shard_total := 0
	for t in targets:
		shard_total += pd.salvage_value(pd.bank[int(t)])
	extras.append(["Salvage (+%d Rune Shards)" % shard_total if n == 1 else "Salvage %d items (+%d Rune Shards)" % [n, shard_total],
		func():
			UI.confirm(menu.ui, "Salvage %s for %d Rune Shards?\nThis can't be undone." % [
				Items.item_name(id) if n == 1 else "%d items" % n, shard_total], "Salvage", func():
				var got: int = pd.salvage_bank_items(targets)
				_bank_selected.clear()
				_refresh_bank()
				menu._toast_ok("+%d Rune Shards" % got))])
	UI.item_menu(menu.ui, id,
		func():
			_bank_selected.clear()
			menu._toast_if(pd.equip_from_bank(idx))
			_refresh_bank(),
		func(): _trash(targets),
		"Delete" if n == 1 else "Delete %d selected items" % n,
		"" if n == 1 else "Delete %d selected items?" % n, extras)

func _trash(indices: Array) -> void:
	menu.get_node("/root/PlayerData").delete_bank_items(indices)
	_bank_selected.clear()
	_refresh_bank()

func _refresh_bank() -> void:
	var pd := menu.get_node("/root/PlayerData")
	var used := 0
	for b in _bank_buttons:
		var idx := int(b.get_meta("bank_index"))
		var id: String = pd.bank[idx]
		if id == "":
			_bank_selected.erase(idx)
		else:
			used += 1
		UI.set_slot_item(b, id, false, _bank_selected.has(idx))
	for l in menu.pages["Bank"].find_children("*", "Label", true, false):
		if l.has_meta("bank_counter"):
			l.text = "Slots used: %d / %d" % [used, pd.BANK_SIZE]

func _build_bank_page() -> Control:
	var page := menu._build_empty_page("Bank")
	var v: VBoxContainer = page.get_child(0).get_child(0)
	v.get_child(1).queue_free()  # drop the "Nothing here yet." line
	# Sort buttons: by type, by quality (rarity), by rune (legendary > epic > rare > common).
	var sort_row := HBoxContainer.new()
	sort_row.alignment = BoxContainer.ALIGNMENT_END
	sort_row.add_theme_constant_override("separation", 6)
	var sort_l := UI.label("Sort:", 14, MainMenu.C_TEXT_DIM)
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
			menu.get_node("/root/PlayerData").sort_bank(mode))
		sort_row.add_child(b)
	v.add_child(sort_row)
	v.add_child(UI.bank_grid(15, 42, 346))
	return page

