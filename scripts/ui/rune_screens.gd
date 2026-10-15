extends RefCounted

# Main-menu rune screens (overlays):
#   - Mysterious Rune reveal: pick 1 of 3 runes of the Mysterious Rune's rarity.
#   (Runecrafting moved into Rune Management, rune_manager.gd.)
# Usage: const RuneScreens = preload("res://scripts/ui/rune_screens.gd")
#        RuneScreens.open_reveal(host, {"where": "bank", "index": i}, on_done)

const UI = preload("res://scripts/ui_kit.gd")
const Runes = preload("res://scripts/runes.gd")
const Items = preload("res://scripts/items.gd")
const ItemDB = preload("res://scripts/core/item_db.gd")

static func _pd(host: Node) -> Node:
	return host.get_node("/root/PlayerData")

## Dimmed full-screen overlay with a centered panel. Returns {"root", "content"}.
static func _overlay(host: Node, title: String, width: float) -> Dictionary:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var panel := PanelContainer.new()
	var sb := UI.box(UI.PANEL_BG, UI.BORDER, 2, 10)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	var t := UI.label(title, 22, UI.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := UI.button("X", 16, Vector2(34, 34))
	close.pressed.connect(shade.queue_free)
	head.add_child(close)
	v.add_child(head)
	return {"root": shade, "content": v}

static func _glyph(id: String, size: float) -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(size, size)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.draw.connect(func(): Runes.draw_glyph(g, g.size / 2.0, size * 0.42, id))
	return g

# --- Runecrafting (removed) -------------------------------------------------------------
# Crafting now lives in Rune Management (rune_manager.gd): every rune is listed
# there and unknown ones are crafted on their card. Old callers land there.

static func open_runecrafting(host: Node) -> void:
	preload("res://scripts/ui/rune_manager.gd").open(host)

## Error / info line via the main menu's toast (if the current scene has one).
static func _toast(host: Node, msg: String) -> void:
	var s := host.get_tree().current_scene
	if s and s.has_method("_toast_if"):
		s._toast_if(msg)

# --- Mysterious Rune reveal ---------------------------------------------------------

## The 3 choices of a Mysterious Rune, fixed on first reveal (stored on the item,
## so closing and reopening can't re-roll them).
static func choices_for(pd: Node, item: String) -> Array:
	var rec := ItemDB.get_record(item)
	if rec.is_empty():
		return []
	var saved: Variant = rec.get("choices")
	if saved is Array and not (saved as Array).is_empty():
		return (saved as Array).filter(func(x): return Runes.PATHS.has(str(x)))
	var picks: Array = pd.mystery_choices(Items.mystery_rarity(item), Array(pd.known_runes))
	ItemDB.records[item]["choices"] = picks
	return picks

static func open_reveal(host: Node, ref: Dictionary, on_done: Callable = Callable()) -> void:
	var pd := _pd(host)
	var item: String = pd.get_item_at(ref)
	var r := Items.mystery_rarity(item)
	if r < 0:
		return
	var o := _overlay(host, "Mysterious %s Rune" % Runes.RARITY_NAMES[r], 760.0)
	var v: VBoxContainer = o["content"]
	v.add_child(UI.label("Choose a rune to learn it permanently.", 15, Color(0.9, 0.9, 0.92)))
	var picks := choices_for(pd, item)
	if picks.is_empty():
		v.add_child(UI.label("There are no %s runes yet." % Runes.RARITY_NAMES[r], 14, UI.TEXT_DIM))
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	for id in picks:
		row.add_child(_reveal_card(host, ref, str(id), o["root"], on_done))
	var note := UI.label("A rune you already know gives %d Rune Shards instead. Close this to keep the Mysterious Rune for later - the choices won't change." % pd.MYSTERY_SHARDS[r], 12, UI.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)

static func _reveal_card(host: Node, ref: Dictionary, id: String, overlay: Control, on_done: Callable) -> Control:
	var pd := _pd(host)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(230, 250)
	card.add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.085, 0.11, 0.95), Runes.rarity_color(id), 2, 8))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var g := _glyph(id, 64)
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(g)
	var n := UI.label(Runes.rune_name(id), 16, Runes.rarity_color(id))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(n)
	var d := UI.label(Runes.description(id), 12, Color(0.85, 0.85, 0.88))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(d)
	var known: bool = pd.known_runes.has(id)
	var r := Runes.rarity(id)
	var status := UI.label("Already known - gives %d Rune Shards" % pd.MYSTERY_SHARDS[r] if known else "New rune", 12,
		UI.TEXT_DIM if known else Color(0.55, 1.0, 0.55))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(status)
	var b := UI.button("Take Shards" if known else "Learn", 15, Vector2(0, 36))
	b.pressed.connect(func():
		var err: String = pd.reveal_mystery(ref, id)
		if err != "":
			_toast(host, err)
			return
		overlay.queue_free()
		if on_done.is_valid():
			on_done.call("+%d Rune Shards" % pd.MYSTERY_SHARDS[r] if known else "Learned %s" % Runes.rune_name(id)))
	v.add_child(b)
	return card
