extends CanvasLayer

# Item tooltips (autoload "ItemTooltip"). Any Control with meta "tip_item"
# (an item id) shows this tooltip instead of Godot's built-in one
# (UI.set_slot_item sets it up for item slots).
#
# Hold Shift while hovering an item that isn't equipped to compare it with what
# you're wearing in that slot: the equipped item is shown next to it, and the
# hovered item lists what changes if you equip it (gains green, losses red).
# Controls with meta "tip_equipped" = true (gear slots) never compare.

const Items = preload("res://scripts/items.gd")
const Stats = preload("res://scripts/core/stats.gd")
const UI = preload("res://scripts/ui_kit.gd")
const Runes = preload("res://scripts/runes.gd")

const DELAY := 0.25
const WIDTH := 270.0
const MOUSE_OFFSET := Vector2(18, 18)
const GREEN := Color(0.4, 1.0, 0.45)
const RED := Color(1.0, 0.38, 0.33)
const DIM := Color(0.62, 0.62, 0.68)
## "Equip:" / "Use:" item effect lines.
const EFFECT_COLOR := Color(0.3, 0.95, 0.55)

var _root: HBoxContainer
var _hover: Control
var _item := ""
var _wait := 0.0
var _shown_key := ""

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = HBoxContainer.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_theme_constant_override("separation", 6)
	_root.visible = false
	add_child(_root)

const Abilities = preload("res://scripts/abilities.gd")

func _process(delta: float) -> void:
	var vp := get_viewport()
	var c := _tip_owner(vp.gui_get_hovered_control())
	if c and c.has_meta("tip_ability"):
		_process_ability(c, delta)
		return
	var item := str(c.get_meta("tip_item", "")) if c else ""
	if item == "" or vp.gui_is_dragging() or not Items.exists(item) or not c.is_visible_in_tree():
		_hide()
		return
	if c != _hover or item != _item:
		_hover = c
		_item = item
		_wait = DELAY
		_shown_key = ""
		_root.visible = false
	if _wait > 0.0:
		_wait -= delta
		if _wait > 0.0:
			return

	var pd := get_node_or_null("/root/PlayerData")
	var compare: bool = pd != null and Input.is_key_pressed(KEY_SHIFT) and not c.get_meta("tip_equipped", false)
	var slot: String = Items.get_item(item).get("slot", "")
	if pd != null and slot != "":
		slot = pd.target_slot_for(item)   # rings / trinkets: the slot it would go into
	var replaced: Array = []   # what equipping this would take off
	if compare and slot != "":
		replaced = _replaced_items(pd, item, slot)
	var key := "%s|%s|%s|%d" % [item, compare, ",".join(replaced), int(pd.level) if pd else 0]
	if key != _shown_key:
		_shown_key = key
		_rebuild(item, compare and slot != "", slot, replaced)
	_root.visible = true
	_place()

const ABILITY_WIDTH := 330.0

# Ability tooltips (meta "tip_ability"): live numbers; Shift = detailed breakdown.
# Meta "tip_detail_only" = only show while Shift is held (draft cards, which
# already print the short version).
func _process_ability(c: Control, delta: float) -> void:
	var id := str(c.get_meta("tip_ability", ""))
	var detailed := Input.is_key_pressed(KEY_SHIFT)
	if id == "" or get_viewport().gui_is_dragging() or not c.is_visible_in_tree() \
			or (c.get_meta("tip_detail_only", false) and not detailed):
		_hide()
		return
	var key_item := "ability:" + id
	if c != _hover or key_item != _item:
		_hover = c
		_item = key_item
		_wait = DELAY
		_shown_key = ""
		_root.visible = false
	if _wait > 0.0:
		_wait -= delta
		if _wait > 0.0:
			return
	# Rebuilt a few times a second so numbers follow buffs / gear changes.
	var key := "%s|%s|%d" % [id, detailed, int(Time.get_ticks_msec() / 400.0)]
	if key != _shown_key:
		_shown_key = key
		for ch in _root.get_children():
			_root.remove_child(ch)
			ch.queue_free()
		var p := _panel(Abilities.tooltip_bbcode(id, detailed))
		(p.get_child(0) as Control).custom_minimum_size.x = ABILITY_WIDTH if detailed else WIDTH
		_root.add_child(p)
		_root.reset_size()
	_root.visible = true
	_place()

## The hovered control, or the nearest parent carrying an item / ability tooltip.
func _tip_owner(c: Control) -> Control:
	var n: Node = c
	for i in 3:
		if n == null or not (n is Control):
			return null
		if n.has_meta("tip_item") or n.has_meta("tip_ability"):
			return n
		n = n.get_parent()
	return null

func _hide() -> void:
	_hover = null
	_item = ""
	_shown_key = ""
	_root.visible = false

## Equipped items that equipping `item` into `slot` would replace.
func _replaced_items(pd: Node, item: String, slot: String) -> Array:
	var out: Array = []
	var cur := str(pd.equipment.get(slot, ""))
	if cur != "" and cur != item:
		out.append(cur)
	if Items.get_item(item).get("locks_offhand", false) and slot != pd.OFF_HAND:
		var off := str(pd.equipment.get(pd.OFF_HAND, ""))
		if off != "" and off != item:
			out.append(off)
	return out

func _rebuild(item: String, compare: bool, slot: String, replaced: Array) -> void:
	for ch in _root.get_children():
		_root.remove_child(ch)
		ch.queue_free()
	if compare:
		# Equipped item(s) on the left, the hovered item (with changes) on the right.
		if replaced.is_empty():
			_root.add_child(_panel("[color=#%s]Currently equipped[/color]\n[color=#%s]Nothing in %s[/color]" % [
				UI.ACCENT.to_html(false), DIM.to_html(false), slot]))
		else:
			for old in replaced:
				_root.add_child(_panel("[color=#%s]Currently equipped[/color]\n%s" % [UI.ACCENT.to_html(false), item_bbcode(old)]))
		_root.add_child(_panel(item_bbcode(item) + "\n" + changes_bbcode(item, replaced)))
	else:
		var text := item_bbcode(item)
		if slot != "" and _hover and not _hover.get_meta("tip_equipped", false):
			text += "\n[color=#%s][font_size=11]Hold Shift to compare[/font_size][/color]" % DIM.to_html(false)
		_root.add_child(_panel(text))
	_root.reset_size()

# Keep the tooltip beside the mouse and on screen.
func _place() -> void:
	var vp := get_viewport().get_visible_rect().size
	var mouse := get_viewport().get_mouse_position()
	var sz := _root.get_combined_minimum_size()
	var pos := mouse + MOUSE_OFFSET
	if pos.x + sz.x > vp.x:
		pos.x = mouse.x - sz.x - 8.0
	if pos.y + sz.y > vp.y:
		pos.y = vp.y - sz.y
	_root.position = pos.max(Vector2.ZERO)

func _panel(bbcode: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UI.box(Color(0.04, 0.045, 0.06, 0.97), UI.BORDER, 2, 6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(WIDTH, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", 13)
	r.add_theme_color_override("default_color", Color(0.92, 0.92, 0.94))
	r.text = bbcode
	p.add_child(r)
	return p

# --- Text -----------------------------------------------------------------------

static func _c(col: Color, text: String) -> String:
	return "[color=#%s]%s[/color]" % [col.to_html(false), text]

## Rich-text version of Items.tooltip (name in its rarity color).
static func item_bbcode(item: String) -> String:
	var d := Items.get_item(item)
	if d.is_empty():
		return ""
	var lines: Array[String] = []
	lines.append("[font_size=16]%s[/font_size]" % _c(d["rarity_color"], Items.item_name(item)))
	var rune := Items.rune_of(item)
	if rune != "":
		lines.append(_c(Runes.rarity_color(rune), Runes.rune_name(rune)))
	lines.append(_c(DIM, "%s  •  Item Level %d" % [d["rarity_name"], d["ilvl"]]))
	var req := Items.required_level(item)
	if req > 1:
		var tree := Engine.get_main_loop() as SceneTree
		var pd: Node = tree.root.get_node_or_null("PlayerData") if tree else null
		var ok: bool = pd == null or int(pd.level) >= req
		lines.append(_c(Color.WHITE if ok else RED, "Requires Level %d" % req))
	lines.append(_c(DIM, Items.slot_line(item)))
	if d.has("weapon"):
		lines.append("%d damage  •  %.1f s  •  %s m range" % [d["damage"], d["attack_interval"], str(d["attack_range"])])
	for stat in d["stats"]:
		lines.append(Stats.bonus_line(str(stat), float(d["stats"][stat])))
	for l in Items.effect_lines(item):
		lines.append(_c(EFFECT_COLOR, l))
	if d.has("durability"):
		lines.append(_c(DIM, "Durability %d / %d" % [d["durability"], d["max_durability"]]))
	var e := Items.rune_of(item)
	if e != "":
		lines.append("%s — %s" % [_c(Runes.rarity_color(e), "%s rune" % Runes.rarity_name(e)), Runes.description(e)])
	return "\n".join(lines)

## "If you equip this:" + one green/red line per stat that changes.
static func changes_bbcode(item: String, replaced: Array) -> String:
	var ch := Items.stat_changes(item, replaced)
	var lines: Array[String] = ["", _c(UI.ACCENT, "If you equip this:")]
	if ch.is_empty():
		lines.append(_c(DIM, "No stat changes"))
		return "\n".join(lines)
	# Weapon numbers first, then stats in stat-panel order, then anything else.
	var order: Array = ["weapon_damage", "attack_interval"]
	for s in Stats.ORDER:
		order.append(s)
	for s in ch:
		if not order.has(s):
			order.append(s)
	for s in order:
		if not ch.has(s):
			continue
		var v := float(ch[s])
		var pre := "+" if v > 0.0 else "-"
		match s:
			"weapon_damage":
				lines.append(_c(GREEN if v > 0.0 else RED, "%s%s Weapon Damage" % [pre, Stats.num(absf(v))]))
			"attack_interval":
				# Lower interval = faster attacks = better.
				lines.append(_c(GREEN if v < 0.0 else RED, "%s%s s Attack Time (%s)" % [pre, "%.2f" % absf(v), "faster" if v < 0.0 else "slower"]))
			_:
				var text := Stats.bonus_line(str(s), v)
				lines.append(_c(GREEN if v > 0.0 else RED, text))
	return "\n".join(lines)
