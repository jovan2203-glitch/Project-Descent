extends Control

# Rune Management (main menu, Character tab): one window, ~80% of the screen.
#   Left (70%): every rune in the game, known or not, with a filter and your
#     Rune Shards. Unknown runes show whether you can craft them; craft them
#     right on their card.
#   Right (30%): Rune Transfer (move a rune between items / extract it), and a
#     small character sheet with your equipped items. Click a known rune on the
#     left, click an item slot, then Engrave. Replacing a rune is free.
# Usage: const RuneManager = preload("res://scripts/ui/rune_manager.gd")
#        RuneManager.open(host)   # host = a CanvasLayer / Control to add it to

const UI = preload("res://scripts/ui_kit.gd")
const Runes = preload("res://scripts/runes.gd")
const Items = preload("res://scripts/items.gd")
const Keywords = preload("res://scripts/core/keywords.gd")

const GREEN := Color(0.55, 1.0, 0.55)
const RED := Color(1.0, 0.45, 0.4)
## Rune rows: at least this wide, stretched to fill (2 columns at 1080p), so
## every name and status line fits on one line.
const ROW_MIN_W := 340.0
## The window spans from (1 - this) to this of the screen each way (0.96 = 92%).
const SCREEN_SHARE := 0.96
## Equipped-item slots shown on the right, in character-sheet order.
const SLOTS := ["Head", "Neck", "Shoulder", "Back", "Chest", "Gloves", "Legs", "Boots",
	"Finger 1", "Finger 2", "Trinket 1", "Trinket 2", "Main Hand", "Off Hand"]

# Filter: which runes the list shows.
enum Show { ALL, KNOWN, UNKNOWN, CRAFTABLE }
var _show := Show.ALL
var _rarities := [true, true, true, true]   # Common, Rare, Epic, Legendary
var _query := ""   # search text: a rune's name, or a word / keyword in its description

var _selected_rune := ""
var _selected_slot := ""
var _src := {}   # Rune Transfer source ({"where": "bank"/"equip", ...})
var _tgt := {}

var _list: GridContainer
var _shards_l: Label
var _filter_btn: MenuButton
var _slot_rows := {}   # slot -> {"btn": Button, "rune": Label}
var _src_btn: Button
var _tgt_btn: Button
var _engrave_btn: Button
var _engrave_info: Label

static func open(host: Node) -> Control:
	var w: Control = load("res://scripts/ui/rune_manager.gd").new()
	host.add_child(w)
	return w

func _pd() -> Node:
	return get_node("/root/PlayerData")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 1.0 - SCREEN_SHARE
	panel.anchor_right = SCREEN_SHARE
	panel.anchor_top = 1.0 - SCREEN_SHARE
	panel.anchor_bottom = SCREEN_SHARE
	panel.offset_left = 0
	panel.offset_right = 0
	panel.offset_top = 0
	panel.offset_bottom = 0
	var sb := UI.box(UI.PANEL_BG, UI.BORDER, 2, 10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	var title := UI.label("Rune Management", 22, UI.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := UI.button("X", 16, Vector2(34, 34))
	close.pressed.connect(queue_free)
	head.add_child(close)
	v.add_child(head)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	v.add_child(body)
	var left := _build_left()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 7.0
	body.add_child(left)
	var right := _build_right()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 3.0
	body.add_child(right)
	_pd().changed_late.connect(_refresh)
	_refresh()

func _exit_tree() -> void:
	var pd := get_node_or_null("/root/PlayerData")
	if pd and pd.changed_late.is_connected(_refresh):
		pd.changed_late.disconnect(_refresh)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		queue_free()

func _toast(msg: String, ok := false) -> void:
	var s := get_tree().current_scene
	if msg == "" or s == null:
		return
	if ok and s.has_method("_toast_ok"):
		s._toast_ok(msg)
	elif s.has_method("_toast_if"):
		s._toast_if(msg)   # the menu's toast moves itself above this window

# --- Left: every rune ----------------------------------------------------------------

func _build_left() -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.box(Color(0.04, 0.045, 0.06, 0.9), UI.BORDER, 1, 8))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	frame.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	v.add_child(top)
	_filter_btn = MenuButton.new()
	_filter_btn.text = "Filter  ▾"
	_filter_btn.flat = false
	_filter_btn.focus_mode = Control.FOCUS_NONE
	_filter_btn.custom_minimum_size = Vector2(130, 36)
	_filter_btn.add_theme_font_size_override("font_size", 16)
	_filter_btn.add_theme_stylebox_override("normal", UI.box(UI.BG, UI.BORDER, 1, 6))
	_filter_btn.add_theme_stylebox_override("hover", UI.box(Color(0.12, 0.12, 0.15, 0.95), UI.ACCENT, 1, 6))
	_filter_btn.add_theme_stylebox_override("pressed", UI.box(Color(0.12, 0.12, 0.15, 0.95), UI.ACCENT, 2, 6))
	var pm := _filter_btn.get_popup()
	pm.add_theme_font_size_override("font_size", 14)
	pm.add_radio_check_item("All runes", 0)
	pm.add_radio_check_item("Known", 1)
	pm.add_radio_check_item("Unknown", 2)
	pm.add_radio_check_item("Can be crafted", 3)
	pm.add_separator("Rarity")
	for r in 4:
		pm.add_check_item(Runes.RARITY_NAMES[r], 10 + r)
	pm.hide_on_checkable_item_selection = false
	pm.id_pressed.connect(_on_filter)
	top.add_child(_filter_btn)
	# Search: by name or by keyword ("chill" finds every rune that works with Chilled).
	var search := LineEdit.new()
	search.placeholder_text = "Search runes  (name or keyword, e.g. freeze)"
	search.clear_button_enabled = true
	search.custom_minimum_size = Vector2(340, 36)
	search.add_theme_font_size_override("font_size", 14)
	search.add_theme_stylebox_override("normal", _pad(UI.box(Color(0, 0, 0, 0.4), UI.BORDER, 1, 6)))
	search.add_theme_stylebox_override("focus", _pad(UI.box(Color(0, 0, 0, 0.5), UI.ACCENT, 1, 6)))
	search.text_changed.connect(func(t: String):
		_query = t.strip_edges()
		_refresh_list())
	search.text_submitted.connect(func(_t): search.release_focus())
	top.add_child(search)
	_shards_l = UI.label("", 18, Color(0.8, 0.6, 1.0))
	_shards_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_shards_l)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = GridContainer.new()
	_list.columns = 2
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("h_separation", 12)
	_list.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_list)
	# As many columns as fit (each at least ROW_MIN_W wide); rows stretch to fill.
	scroll.resized.connect(func():
		_list.columns = maxi(1, int((scroll.size.x - 16.0) / ROW_MIN_W)))
	_sync_filter_checks()
	return frame

func _pad(sb: StyleBoxFlat) -> StyleBoxFlat:
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	return sb

func _on_filter(id: int) -> void:
	if id < 10:
		_show = id as Show
	else:
		_rarities[id - 10] = not _rarities[id - 10]
	_sync_filter_checks()
	_refresh_list()

func _sync_filter_checks() -> void:
	var pm := _filter_btn.get_popup()
	for i in pm.item_count:
		var id := pm.get_item_id(i)
		if id < 0:
			continue
		if id < 10:
			pm.set_item_checked(i, id == int(_show))
		else:
			pm.set_item_checked(i, _rarities[id - 10])
	var filtered := _show != Show.ALL or _rarities.has(false)
	_filter_btn.text = "Filter  ▾" if not filtered else "Filter (on)  ▾"

func _passes(id: String) -> bool:
	var pd := _pd()
	if not _rarities[Runes.rarity(id)]:
		return false
	if _query != "" and not Keywords.matches("r:" + id, _query):
		return false
	var known: bool = pd.known_runes.has(id)
	match _show:
		Show.KNOWN:
			return known
		Show.UNKNOWN:
			return not known
		Show.CRAFTABLE:
			return not known and int(pd.rune_shards) >= int(pd.craft_cost(id))
	return true

func _refresh_list() -> void:
	var pd := _pd()
	_shards_l.text = "Rune Shards: %d" % int(pd.rune_shards)
	for c in _list.get_children():
		c.queue_free()
	var ids: Array = Runes.ALL.filter(func(x): return _passes(str(x)))
	ids.sort_custom(func(a, b):
		if Runes.rarity(a) != Runes.rarity(b):
			return Runes.rarity(a) > Runes.rarity(b)   # Legendary first
		return Runes.rune_name(a) < Runes.rune_name(b))
	if ids.is_empty():
		_list.add_child(UI.label("No runes match the search and filter." if _query != "" else "No runes match the filter.", 14, UI.TEXT_DIM))
	for id in ids:
		_list.add_child(_rune_card(str(id)))

## Slots whose item carries rune `id`.
func _engraved_on(id: String) -> Array:
	var out := []
	var pd := _pd()
	for s in SLOTS:
		if Items.rune_of(str(pd.equipment.get(s, ""))) == id:
			out.append(s)
	return out

## A rune's icon, like a spell icon in a WoW list: a round medallion with a
## rarity-colored ring and the rune's glyph inside (darkened if unknown).
func _rune_icon(id: String, size: float, known: bool) -> Control:
	var col := Runes.rarity_color(id)
	var g := Control.new()
	g.custom_minimum_size = Vector2(size, size)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.draw.connect(func():
		var c := g.size / 2.0
		var r := minf(g.size.x, g.size.y) / 2.0
		g.draw_circle(c, r, Color(0, 0, 0, 0.85))                      # dark rim
		g.draw_circle(c, r - 1.5, col.darkened(0.15))                   # rarity ring
		g.draw_circle(c, r - 4.5, Color(0.05, 0.04, 0.03))              # inner edge
		g.draw_circle(c, r - 6.0, col.darkened(0.72))                   # face
		g.draw_circle(c + Vector2(0, -r * 0.25), r * 0.45, Color(col.lightened(0.3), 0.12))   # soft sheen
		Runes.draw_glyph(g, c, r * 0.62, id)
		g.draw_arc(c, r - 1.5, PI * 1.1, PI * 1.6, 10, Color(1, 1, 1, 0.35), 1.5, true)   # ring highlight
		if not known:
			g.draw_circle(c, r - 4.5, Color(0, 0, 0, 0.5)))
	return g

const NAME_GOLD := Color(1.0, 0.82, 0.3)
const INFO_CYAN := Color(0.35, 0.8, 1.0)

## One rune as a name plate (icon + gold name + one small line underneath),
## no box around it - like a WoW spell list. The full description is in its
## tooltip. Click to select it for engraving.
func _rune_card(id: String) -> Control:
	var pd := _pd()
	var known: bool = pd.known_runes.has(id)
	var selected := id == _selected_rune
	var cost: int = pd.craft_cost(id)
	var craftable: bool = not known and int(pd.rune_shards) >= cost
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(ROW_MIN_W - 40.0, 40)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := UI.box(Color(1, 0.82, 0.3, 0.1) if selected else Color(0, 0, 0, 0),
		Color(1, 0.82, 0.3, 0.7) if selected else Color(0, 0, 0, 0), 1 if selected else 0, 30)
	sb.content_margin_left = 4
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_entered.connect(func():
		if not selected:
			card.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 0, 30)))
	card.mouse_exited.connect(func(): card.add_theme_stylebox_override("panel", sb))
	card.tooltip_text = Runes.tooltip(id)
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_selected_rune = "" if _selected_rune == id else id
			_refresh())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(h)
	h.add_child(_rune_icon(id, 36, known))
	var t := VBoxContainer.new()
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.add_theme_constant_override("separation", -2)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(t)
	var name_l := UI.label(Runes.rune_name(id).trim_prefix("Rune of the ").trim_prefix("Rune of "), 15,
		NAME_GOLD if known else NAME_GOLD.darkened(0.4))
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # never cut off
	t.add_child(name_l)
	var status: Label
	if known:
		var on := _engraved_on(id)
		status = UI.label("On " + ", ".join(on) if not on.is_empty() else Runes.rarity_name(id), 12,
			INFO_CYAN if not on.is_empty() else Runes.rarity_color(id))
	elif craftable:
		status = UI.label("Can be crafted (%d)" % cost, 12, GREEN)
	else:
		status = UI.label("Not enough Rune Shards to craft (%d)" % cost, 12, RED)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # the red line may need two
	t.add_child(status)
	if craftable:
		var craft := UI.button("Craft", 13, Vector2(52, 24))
		craft.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		craft.tooltip_text = "Learn %s for %d Rune Shards" % [Runes.rune_name(id), cost]
		craft.pressed.connect(func():
			var err: String = pd.craft_rune(id)
			if err != "":
				_toast(err)
			else:
				_selected_rune = id
				_toast("Learned %s" % Runes.rune_name(id), true))
		h.add_child(craft)
	return card

# --- Right: Rune Transfer + equipped items + Engrave -----------------------------------

func _section(parent: Control, title: String) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color(0.04, 0.045, 0.06, 0.9), UI.BORDER, 1, 8))
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(UI.label(title, 19, UI.ACCENT))
	return v

func _build_right() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	scroll.add_child(col)

	# Engrave: equipped items (click one) + the Engrave button.
	var eng := _section(col, "Engrave")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	eng.add_child(grid)
	for s in SLOTS:
		var slot_name: String = s
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 5)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b := UI.slot(44, "%s (empty)" % slot_name, slot_name == "Back")
		b.set_meta("slot_name", slot_name)
		b.pressed.connect(func():
			_selected_slot = "" if _selected_slot == slot_name else slot_name
			_refresh_right())
		cell.add_child(b)
		var txt := VBoxContainer.new()
		txt.add_theme_constant_override("separation", 0)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var n := UI.label(slot_name, 13, Color(0.85, 0.85, 0.88))
		n.clip_text = true
		txt.add_child(n)
		var r := UI.label("", 12, UI.TEXT_DIM)
		r.clip_text = true
		r.custom_minimum_size = Vector2(60, 0)
		txt.add_child(r)
		cell.add_child(txt)
		grid.add_child(cell)
		_slot_rows[slot_name] = {"btn": b, "rune": r}
	_engrave_info = UI.label("", 14, UI.TEXT_DIM)
	_engrave_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eng.add_child(_engrave_info)
	_engrave_btn = UI.button("Engrave", 18, Vector2(0, 42))
	_engrave_btn.pressed.connect(_engrave)
	eng.add_child(_engrave_btn)

	# Rune Transfer: move a rune from one item to another, or extract it.
	var tr := _section(col, "Rune Transfer")
	var note := UI.label("The rune is learned and the source item is destroyed.", 13, UI.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tr.add_child(note)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	tr.add_child(row)
	_src_btn = UI.slot(60, "Source item (with a rune): click to choose")
	_src_btn.pressed.connect(_pick_item.bind(true))
	row.add_child(_src_btn)
	row.add_child(UI.label("→", 26, UI.ACCENT))
	_tgt_btn = UI.slot(60, "Target item (no rune): click to choose")
	_tgt_btn.pressed.connect(_pick_item.bind(false))
	row.add_child(_tgt_btn)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	tr.add_child(btns)
	var transfer := UI.button("Transfer", 15, Vector2(0, 36))
	transfer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transfer.pressed.connect(_do_transfer)
	btns.add_child(transfer)
	var extract := UI.button("Extract", 15, Vector2(0, 36))
	extract.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	extract.tooltip_text = "Learn the source item's rune and destroy the item (no target needed)."
	extract.pressed.connect(_do_extract)
	btns.add_child(extract)
	return scroll

func _refresh() -> void:
	_refresh_list()
	_refresh_right()

func _refresh_right() -> void:
	var pd := _pd()
	for s in _slot_rows:
		var row: Dictionary = _slot_rows[s]
		var item := str(pd.equipment.get(s, ""))
		UI.set_slot_item(row["btn"], item, pd.is_slot_locked(s), s == _selected_slot)
		var rune := Items.rune_of(item)
		var rl: Label = row["rune"]
		if item == "":
			rl.text = "empty"
			rl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
		elif rune == "":
			rl.text = "no rune"
			rl.add_theme_color_override("font_color", UI.TEXT_DIM)
		else:
			rl.text = Runes.short_name(rune) if Runes.short_name(rune) != "" else Runes.rune_name(rune)
			rl.add_theme_color_override("font_color", Runes.rarity_color(rune))
	# Engrave state.
	var item := str(pd.equipment.get(_selected_slot, "")) if _selected_slot != "" else ""
	var known: bool = _selected_rune != "" and pd.known_runes.has(_selected_rune)
	if _selected_rune == "":
		_engrave_info.text = "Pick a rune on the left."
	elif not known:
		_engrave_info.text = "You don't know %s yet - craft it first." % Runes.rune_name(_selected_rune)
	elif _selected_slot == "":
		_engrave_info.text = "Pick an equipped item for %s." % Runes.rune_name(_selected_rune)
	elif item == "":
		_engrave_info.text = "Nothing equipped in %s." % _selected_slot
	else:
		var old := Items.rune_of(item)
		_engrave_info.text = "%s  →  %s%s" % [Runes.rune_name(_selected_rune), Items.item_name(item),
			"\n(replaces %s, free)" % Runes.rune_name(old) if old != "" and old != _selected_rune else ""]
	_engrave_btn.disabled = not known or item == "" or Items.rune_of(item) == _selected_rune
	# Rune Transfer slots (drop stale picks).
	if not _src.is_empty() and Items.rune_of(pd.get_item_at(_src)) == "":
		_src = {}
	if not _tgt.is_empty() and pd.get_item_at(_tgt) == "":
		_tgt = {}
	UI.set_slot_item(_src_btn, pd.get_item_at(_src) if not _src.is_empty() else "")
	UI.set_slot_item(_tgt_btn, pd.get_item_at(_tgt) if not _tgt.is_empty() else "")

func _engrave() -> void:
	var err: String = _pd().apply_rune(_selected_slot, _selected_rune)
	if err != "":
		_toast(err)
	else:
		_toast("Engraved %s" % Runes.rune_name(_selected_rune), true)

## Pick a Rune Transfer item from a list (source: runed items, target: items without one).
func _pick_item(source: bool) -> void:
	var pd := _pd()
	var refs: Array[Dictionary] = pd.list_items(1 if source else 0)
	var pm := PopupMenu.new()
	pm.add_theme_font_size_override("font_size", 14)
	pm.add_theme_stylebox_override("panel", UI.box(UI.PANEL_BG, UI.BORDER, 2, 6))
	if refs.is_empty():
		pm.add_item("No items with a rune" if source else "No items without a rune", -1)
		pm.set_item_disabled(0, true)
	for i in refs.size():
		var ref: Dictionary = refs[i]
		var item: String = pd.get_item_at(ref)
		var where := "Equipped (%s)" % ref["slot"] if ref.get("where") == "equip" else "Bank"
		var text := "%s  -  %s" % [Items.item_name(item), where]
		if source:
			text += "  [%s]" % Runes.rune_name(Items.rune_of(item))
		pm.add_item(text, i)
	pm.id_pressed.connect(func(i: int):
		if i < 0:
			return
		if source:
			_src = refs[i]
		else:
			_tgt = refs[i]
		_refresh_right())
	pm.popup_hide.connect(pm.queue_free)
	add_child(pm)
	pm.popup(Rect2i(Vector2i(get_viewport().get_mouse_position()), Vector2i(260, 0)))

func _do_transfer() -> void:
	var pd := _pd()
	if _src.is_empty() or _tgt.is_empty():
		_toast("Choose a source and a target item")
		return
	var rune := Items.rune_of(pd.get_item_at(_src))
	var err: String = pd.transfer_rune(_src, _tgt)
	if err != "":
		_toast(err)
		return
	_toast("Moved %s to %s" % [Runes.rune_name(rune), Items.item_name(pd.get_item_at(_tgt))], true)
	_src = {}
	_refresh_right()

func _do_extract() -> void:
	var pd := _pd()
	if _src.is_empty():
		_toast("Choose a source item")
		return
	var rune := Items.rune_of(pd.get_item_at(_src))
	var err: String = pd.extract_rune(_src)
	if err != "":
		_toast(err)
		return
	_toast("Learned %s" % Runes.rune_name(rune), true)
	_src = {}
	_refresh_right()
