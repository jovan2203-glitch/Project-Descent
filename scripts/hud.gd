extends CanvasLayer

# Player HUD: segmented health bar (top-left), cast bar and action bar
# (bottom-center), error/loot messages, death screen.

@export var player_path: NodePath

const UI = preload("res://scripts/ui_kit.gd")
const Items = preload("res://scripts/items.gd")
const Abilities = preload("res://scripts/abilities.gd")
const Runes = preload("res://scripts/runes.gd")

# --- Active buffs (listed under the resource bars) ---------------------------------
var _buff_box: VBoxContainer

func _update_buffs() -> void:
	if _buff_box == null:
		_buff_box = VBoxContainer.new()
		_buff_box.add_theme_constant_override("separation", 2)
		add_child(_buff_box)
	var y := 66.0
	if _res_box:
		y = _res_box.position.y + _res_box.size.y + 6
	_buff_box.position = Vector2(22, y)
	# Buffs (green) first, then debuffs (red), straight from the StatusContainer.
	var lines: Array = []   # [text, color]
	var status: Node = player.get("status")
	if status:
		var all: Array = status.list()
		all.sort_custom(func(a, b): return int(a["debuff"]) < int(b["debuff"]))
		for e in all:
			var parts: Array[String] = []
			var mods: Dictionary = e["mods"]
			for stat in mods:
				var amount := float(mods[stat]) * int(e["stacks"])
				parts.append(Items.stat_line(str(stat), amount))
			var stacks := " x%d" % int(e["stacks"]) if int(e["stacks"]) > 1 else ""
			# Effects without stat changes (Stormfire, Sacred Bulwark's sear...) show their description.
			var what := ", ".join(parts) if not parts.is_empty() else str(e.get("desc", ""))
			var txt := "%s%s: %s  (%.0fs)" % [e["name"], stacks, what, ceil(float(e["remaining"]))]
			if what == "":
				txt = "%s%s  (%.0fs)" % [e["name"], stacks, ceil(float(e["remaining"]))]
			lines.append([txt, Color(1.0, 0.5, 0.45) if e["debuff"] else Color(0.6, 1.0, 0.6)])
	while _buff_box.get_child_count() < lines.size():
		var l := UI.label("", 13, Color(0.6, 1.0, 0.6))
		_buff_box.add_child(l)
	for i in _buff_box.get_child_count():
		var l: Label = _buff_box.get_child(i)
		l.visible = i < lines.size()
		if i < lines.size():
			l.text = lines[i][0]
			# Theme overrides trigger a relayout, so only set on change.
			if l.get_meta("col", Color.TRANSPARENT) != lines[i][1]:
				l.set_meta("col", lines[i][1])
				l.add_theme_color_override("font_color", lines[i][1])

const SEG_FULL := Color(0.85, 0.15, 0.15)
const SEG_EMPTY := Color(0.22, 0.22, 0.22)
const CAST_FILL := Color(0.45, 0.85, 1.0)
const CAST_FAIL := Color(0.9, 0.25, 0.2)

var player: Node
var _segments: Array[ColorRect] = []
var _hp_label: Label

var _cast_root: Control
var _cast_fill: ColorRect
var _cast_label: Label
var _cast_time_label: Label
var _was_casting := false
var _hide_timer := 0.0

const CAST_W := 320.0
const CAST_H := 22.0

func _ready() -> void:
	player = get_node_or_null(player_path)
	_build_health_bar()
	_build_cast_bar()
	_build_action_bar()
	_build_xp_bar()
	# Everything the HUD reacts to arrives through the SignalBus.
	var bus := get_node("/root/SignalBus")
	bus.xp_changed.connect(func(_l, _x, _n): _update_xp_bar())
	bus.level_up.connect(func(lv): _show_message("Level %d!" % lv, Color(0.8, 0.6, 1.0)))
	bus.player_health_changed.connect(_on_health_changed)
	bus.player_died.connect(_on_player_died)
	bus.action_error.connect(_show_error)
	bus.item_looted.connect(func(id): _show_message("Looted: " + Items.item_name(id), Color(1.0, 0.82, 0.35)))
	bus.skill_card_unlocked.connect(func(cid): _show_message("New Skill Card: %s" % Abilities.ability_name(
		preload("res://scripts/skill_cards.gd").ability_of(cid)), Color(0.8, 0.6, 1.0)))
	bus.rune_triggered.connect(func(eid: String):
		if eid.begins_with("item:"):   # item Equip: / Use: effects
			_show_message(eid.trim_prefix("item:") + "!", Color(0.3, 0.95, 0.55))
		else:
			_show_message(Runes.rune_name(eid) + "!", Runes.color(eid).lightened(0.2)))
	if player:
		_on_health_changed(player.health, player.max_health)
	# Settings > Interface > HUD opacity (the death screen stays solid).
	var settings := get_node("/root/Settings")
	for c in get_children():
		if c is CanvasItem:
			settings.register_hud(c)
	child_entered_tree.connect(func(c):
		if c is CanvasItem and not (player and player.has_method("is_dead") and player.is_dead()):
			settings.register_hud(c))

# --- Messages ----------------------------------------------------------------

var _error_label: Label
var _error_tween: Tween

# Red "can't do that" message above the cast bar, fades after ~1.5 s.
func _show_error(msg: String) -> void:
	_show_message(msg, Color(1, 0.3, 0.25))

func _show_message(msg: String, color: Color) -> void:
	if _error_label == null:
		_error_label = Label.new()
		_error_label.anchor_left = 0.5
		_error_label.anchor_right = 0.5
		_error_label.anchor_top = 1.0
		_error_label.anchor_bottom = 1.0
		_error_label.offset_left = -250
		_error_label.offset_right = 250
		_error_label.offset_top = -160
		_error_label.offset_bottom = -132
		_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_error_label.add_theme_font_size_override("font_size", 18)
		_error_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_error_label.add_theme_constant_override("outline_size", 5)
		_error_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_error_label)
	_error_label.text = msg
	_error_label.add_theme_color_override("font_color", color)
	_error_label.modulate.a = 1.0
	if _error_tween:
		_error_tween.kill()
	_error_tween = create_tween()
	_error_tween.tween_interval(1.0)
	_error_tween.tween_property(_error_label, "modulate:a", 0.0, 0.5)

func _on_player_died() -> void:
	_cast_root.visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.25, 0, 0, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var label := Label.new()
	label.text = "You died\nPress %s to restart" % get_node("/root/Settings").key_text("restart")
	var net := get_node_or_null("/root/Net")
	if net and net.with_others():
		label.text = "You died\nYour party fights on - the floor restarts if everyone falls"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_bottom = -120
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	add_child(label)
	# What the death cost (PlayerData.apply_death already ran).
	var pd := get_node_or_null("/root/PlayerData")
	var d: Dictionary = pd.last_death if pd else {}
	if d.is_empty():
		return
	var lines: Array[String] = []
	var lock := int(d["lock"])
	lines.append("Level %d  →  %d%s" % [int(d["old_level"]), int(d["new_level"]),
		"  (level lock)" if lock > 0 else ""])
	lines.append("Items lost (gear + bag): %s" % (", ".join(d["lost"]) if not d["lost"].is_empty() else "none"))
	if not d["kept"].is_empty():
		lines.append("Kept (wearable at level %d): %s" % [int(d["new_level"]), ", ".join(d["kept"])])
	if not d["runes_learned"].is_empty():
		lines.append("Runes recovered from lost gear: %s" % ", ".join(d["runes_learned"].map(func(r): return Runes.rune_name(str(r)))))
	if int(d["abilities_lost"]) > 0:
		lines.append("Abilities lost: %d — equip Skill Cards to get them back" % int(d["abilities_lost"]))
	lines.append("Your bank, runes and Skill Cards are safe.")
	var info := UI.label("\n".join(lines), 17, Color(1.0, 0.85, 0.8))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.anchor_left = 0.5
	info.anchor_right = 0.5
	info.anchor_top = 0.5
	info.anchor_bottom = 0.5
	info.offset_left = -380
	info.offset_right = 380
	info.offset_top = 10
	info.offset_bottom = 200
	info.add_theme_color_override("font_outline_color", Color.BLACK)
	info.add_theme_constant_override("outline_size", 5)
	add_child(info)

# --- Health ------------------------------------------------------------------

func _build_health_bar() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.55), 6))
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var title := Label.new()
	title.text = "HP"
	title.add_theme_font_size_override("font_size", 18)
	row.add_child(title)

	_hp_segs_box = HBoxContainer.new()
	_hp_segs_box.add_theme_constant_override("separation", 2)
	_hp_segs_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_hp_segs_box)
	_build_hp_segments(player.max_health if player else 10)

	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 16)
	row.add_child(_hp_label)

var _hp_segs_box: HBoxContainer

# Segments keep the bar ~178 px wide whatever the max health is.
func _build_hp_segments(count: int) -> void:
	for c in _hp_segs_box.get_children():
		c.queue_free()
	_segments.clear()
	count = max(count, 1)
	var seg_w: float = max(4.0, (178.0 - (count - 1) * 2.0) / count)
	for i in count:
		var s := ColorRect.new()
		s.custom_minimum_size = Vector2(seg_w, 16)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.color = SEG_FULL
		_hp_segs_box.add_child(s)
		_segments.append(s)

func _on_health_changed(current: int, maximum: int) -> void:
	if maximum != _segments.size():
		_build_hp_segments(maximum)
	for i in _segments.size():
		_segments[i].color = SEG_FULL if i < current else SEG_EMPTY
	_hp_label.text = "%d / %d" % [current, maximum]

# --- Cast bar ----------------------------------------------------------------

func _build_cast_bar() -> void:
	_cast_root = Control.new()
	_cast_root.anchor_left = 0.5
	_cast_root.anchor_right = 0.5
	_cast_root.anchor_top = 1.0
	_cast_root.anchor_bottom = 1.0
	_cast_root.offset_left = -CAST_W / 2.0
	_cast_root.offset_right = CAST_W / 2.0
	_cast_root.offset_top = -120.0
	_cast_root.offset_bottom = -120.0 + CAST_H
	_cast_root.visible = false
	add_child(_cast_root)

	var border := Panel.new()
	border.position = Vector2(-3, -3)
	border.size = Vector2(CAST_W + 6, CAST_H + 6)
	border.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.75), 4))
	_cast_root.add_child(border)

	_cast_fill = ColorRect.new()
	_cast_fill.size = Vector2(0, CAST_H)
	_cast_fill.color = CAST_FILL
	_cast_root.add_child(_cast_fill)

	_cast_label = Label.new()
	_cast_label.size = Vector2(CAST_W, CAST_H)
	_cast_label.position = Vector2(8, 0)
	_cast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cast_label.add_theme_font_size_override("font_size", 14)
	_cast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_cast_label.add_theme_constant_override("outline_size", 4)
	_cast_root.add_child(_cast_label)

	_cast_time_label = Label.new()
	_cast_time_label.size = Vector2(CAST_W - 8, CAST_H)
	_cast_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cast_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cast_time_label.add_theme_font_size_override("font_size", 14)
	_cast_time_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_cast_time_label.add_theme_constant_override("outline_size", 4)
	_cast_root.add_child(_cast_time_label)

# --- Action bar (layout comes from PlayerData.action_bar) --------------------------

const ACTION_SLOTS := 8
const SLOT_SIZE := 52.0

var _slot_buttons := {}     # slot -> Button
var _slot_cd := {}          # slot -> cooldown overlay Control
var _style_idle: StyleBoxFlat
var _style_active: StyleBoxFlat

func _slot_id(i: int) -> String:
	var pd := get_node_or_null("/root/PlayerData")
	return pd.action_bar[i - 1] if pd else ""

func _build_action_bar() -> void:
	_style_idle = UI.box(Color(0.06, 0.065, 0.085, 0.9), UI.BORDER, 2, 6)
	_style_active = UI.box(Color(0.1, 0.14, 0.2, 0.95), UI.ACCENT, 3, 6)

	var bar := PanelContainer.new()
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	var width := ACTION_SLOTS * SLOT_SIZE + (ACTION_SLOTS - 1) * 6 + 16
	bar.offset_left = -width / 2.0
	bar.offset_right = width / 2.0
	bar.offset_top = -SLOT_SIZE - 26
	bar.offset_bottom = -14
	bar.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0.55), UI.BORDER, 1, 8))
	add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)

	for i in range(1, ACTION_SLOTS + 1):
		var b := Abilities.make_slot(SLOT_SIZE)
		b.pressed.connect(func(): if player: player.activate_ability(i))
		row.add_child(b)
		_slot_buttons[i] = b

		# Cooldown overlay: dark fill that shrinks as the cooldown runs + seconds left.
		var cd := Control.new()
		cd.set_anchors_preset(Control.PRESET_FULL_RECT)
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cd.draw.connect(func():
			var frac: float = cd.get_meta("frac", 0.0)
			if frac <= 0.0:
				return
			var h := cd.size.y * frac
			cd.draw_rect(Rect2(Vector2(0, cd.size.y - h), Vector2(cd.size.x, h)), Color(0, 0, 0, 0.65), true)
			var f := ThemeDB.fallback_font
			var txt := "%.1f" % float(cd.get_meta("left", 0.0))
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			var p := Vector2((cd.size.x - tw) / 2.0, cd.size.y / 2.0 + 6)
			cd.draw_string_outline(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
			cd.draw_string(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE))
		b.add_child(cd)
		_slot_cd[i] = cd

		# Drag an ability onto another slot to move it there (the two swap).
		var slot_i: int = i
		b.set_drag_forwarding(
			func(_pos): return _bar_drag(b, slot_i),
			func(_pos, data): return data is Dictionary and data.get("type") == "hud_bar",
			func(_pos, data):
				var pd := get_node_or_null("/root/PlayerData")
				if pd:
					var from := int(data["slot"])
					pd.set_action_slot(slot_i - 1, str(pd.action_bar[from - 1]), from - 1))

		var key := UI.label(str(i), 13, Color.WHITE)
		key.name = "Key"
		key.position = Vector2(4, 1)
		b.add_child(key)

	var pd := get_node_or_null("/root/PlayerData")
	if pd:
		pd.changed.connect(_refresh_action_bar)
	get_node("/root/Settings").keybinds_changed.connect(_refresh_action_bar)
	_refresh_action_bar()

## Start dragging the ability in bar slot `i` (1-8). Dropping it anywhere
## that isn't a slot leaves the bar as it was.
func _bar_drag(b: Button, i: int) -> Variant:
	var id := _slot_id(i)
	if id == "":
		return null
	var preview := Control.new()
	var icon := Control.new()
	icon.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	icon.position = -icon.size / 2.0
	icon.modulate.a = 0.85
	icon.draw.connect(func(): Abilities.draw_icon(icon, id))
	preview.add_child(icon)
	b.set_drag_preview(preview)
	return {"type": "hud_bar", "slot": i}

# --- XP bar (thin bar right above the action bar) -----------------------------------

var _xp_fill: ColorRect
var _xp_label: Label
const XP_BAR_W := ACTION_SLOTS * SLOT_SIZE + (ACTION_SLOTS - 1) * 6 + 16

func _build_xp_bar() -> void:
	var root := Control.new()
	root.anchor_left = 0.5
	root.anchor_right = 0.5
	root.anchor_top = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = -XP_BAR_W / 2.0
	root.offset_right = XP_BAR_W / 2.0
	root.offset_top = -SLOT_SIZE - 26 - 16
	root.offset_bottom = -SLOT_SIZE - 26 - 6
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	_xp_fill = ColorRect.new()
	_xp_fill.color = Color(0.6, 0.35, 0.95)
	_xp_fill.position = Vector2(1, 1)
	_xp_fill.size = Vector2(0, 8)
	_xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_xp_fill)
	_xp_label = UI.label("", 11, Color.WHITE)
	_xp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_xp_label.offset_top = -4
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(_xp_label)
	_update_xp_bar()

func _update_xp_bar() -> void:
	var pd := get_node_or_null("/root/PlayerData")
	if pd == null or _xp_fill == null:
		return
	var need: int = pd.xp_to_next(pd.level)
	var frac := 1.0 if need <= 0 else clampf(float(pd.xp) / need, 0.0, 1.0)
	_xp_fill.size.x = (XP_BAR_W - 2) * frac
	_xp_label.text = "Level %d  •  %s" % [pd.level, "Max level" if need <= 0 else "%d / %d XP" % [pd.xp, need]]

# --- Resource bars (under HP): only the resources used by the abilities on the bar ---

const RES_ORDER := ["mana", "energy", "rage"]
const RES_COLORS := {
	"mana": Color(0.25, 0.5, 1.0),
	"energy": Color(1.0, 0.85, 0.2),
	"rage": Color(0.9, 0.25, 0.1),
}
const RES_LABELS := {"mana": "MP", "energy": "EN", "rage": "RG"}
var _res_box: VBoxContainer
var _res_rows := {}   # res -> {"segs": Array[ColorRect], "label": Label}

func _refresh_resource_bars() -> void:
	if _res_box == null:
		_res_box = VBoxContainer.new()
		_res_box.position = Vector2(20, 66)
		_res_box.add_theme_constant_override("separation", 6)
		add_child(_res_box)
	var needed: Array[String] = []
	var pd := get_node_or_null("/root/PlayerData")
	if pd:
		for id in pd.action_bar:
			var r := Abilities.resource_of(id)
			if r != "" and not needed.has(r):
				needed.append(r)
	for c in _res_box.get_children():
		c.queue_free()
	_res_rows.clear()
	for res in RES_ORDER:
		if not needed.has(res):
			continue
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.55), 6))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		panel.add_child(row)
		var title := Label.new()
		title.text = RES_LABELS[res]
		title.custom_minimum_size = Vector2(26, 0)
		title.add_theme_font_size_override("font_size", 15)
		title.add_theme_color_override("font_color", RES_COLORS[res].lightened(0.3))
		row.add_child(title)
		var segs_box := HBoxContainer.new()
		segs_box.add_theme_constant_override("separation", 2)
		row.add_child(segs_box)
		var segs: Array[ColorRect] = []
		for i in 10:
			var s := ColorRect.new()
			s.custom_minimum_size = Vector2(15, 12)
			s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			segs_box.add_child(s)
			segs.append(s)
		var val := Label.new()
		val.add_theme_font_size_override("font_size", 14)
		row.add_child(val)
		_res_box.add_child(panel)
		_res_rows[res] = {"segs": segs, "label": val, "last": -1}

func _update_resource_bars() -> void:
	for res in _res_rows:
		var pts: int = player.resource_points(res)
		var mx: int = int(player.resource_max(res))
		var row: Dictionary = _res_rows[res]
		if pts == row["last"] and mx == int(row.get("max", -1)):
			continue
		row["last"] = pts
		row["max"] = mx
		# 10 segments show the fraction (max mana can grow past 10).
		var segs: Array = row["segs"]
		var filled := int(round(float(pts) / maxf(mx, 1) * segs.size()))
		for i in segs.size():
			segs[i].color = RES_COLORS[res] if i < filled else SEG_EMPTY
		row["label"].text = "%d / %d" % [pts, mx]

func _refresh_action_bar() -> void:
	_refresh_resource_bars()
	for i in _slot_buttons:
		var id := _slot_id(i)
		Abilities.set_slot_ability(_slot_buttons[i], id)
		var key: Label = _slot_buttons[i].get_node("Key")
		var settings := get_node_or_null("/root/Settings")
		if settings:
			key.text = settings.key_text("ability_%d" % i)
		key.add_theme_color_override("font_color", Color.WHITE if id != "" else UI.TEXT_DIM)

func _update_action_bar() -> void:
	for i in _slot_buttons:
		var id := _slot_id(i)
		var b: Button = _slot_buttons[i]
		var active := false
		var left := 0.0
		var total := 1.0
		if id != "":
			active = (player.casting and player.current_spell == id) \
				or (id == "blizzard" and player.placing)
			var usable := true
			if Abilities.info(id).get("needs_target", false):
				usable = player.has_valid_target()
			usable = usable and player.can_afford(id) and player.target_in_range(id)
			if Abilities.is_trinket_slot(id):
				usable = player.trinket_usable(id)   # an item with a Use: effect is equipped there
			b.get_node("AbilityIcon").modulate.a = 1.0 if usable else 0.4
			left = player.cooldown_left(id)
			total = max(player.cooldown_total(id), 0.01)
		var cd: Control = _slot_cd[i]
		var frac := clampf(left / total, 0.0, 1.0)
		if frac != float(cd.get_meta("frac", 0.0)) or left != float(cd.get_meta("left", 0.0)):
			cd.set_meta("frac", frac)
			cd.set_meta("left", left)
			cd.queue_redraw()
		var style := _style_active if active else _style_idle
		if b.get_theme_stylebox("normal") != style:
			b.add_theme_stylebox_override("normal", style)

# --- Per-frame -----------------------------------------------------------------

func _process(delta: float) -> void:
	if player == null:
		return
	_update_action_bar()
	_update_resource_bars()
	_update_buffs()
	var total: float = player.cast_duration

	if player.casting:
		var remaining: float = max(player.cast_timer, 0.0)
		var progress := 1.0 - remaining / total
		if player.cast_is_channel:
			progress = remaining / total   # channels drain from full to empty
		_cast_root.visible = true
		_cast_root.modulate.a = 1.0
		_cast_fill.color = CAST_FILL
		_cast_fill.size.x = CAST_W * clampf(progress, 0.0, 1.0)
		_cast_label.text = player.cast_name
		_cast_time_label.text = "%.1f" % remaining
		_was_casting = true
		_hide_timer = 0.0
		return

	if _was_casting:
		_was_casting = false
		if player.cast_timer <= 0.0:
			# Finished: show a full bar briefly (channels just end empty).
			_cast_fill.size.x = 0.0 if player.cast_is_channel else CAST_W
			_cast_time_label.text = ""
			_hide_timer = 0.25
		else:
			# Interrupted
			_cast_fill.color = CAST_FAIL
			_cast_fill.size.x = CAST_W
			_cast_label.text = "Interrupted"
			_cast_time_label.text = ""
			_hide_timer = 0.6

	if _hide_timer > 0.0:
		_hide_timer -= delta
		_cast_root.modulate.a = clampf(_hide_timer / 0.25, 0.0, 1.0)
		if _hide_timer <= 0.0:
			_cast_root.visible = false

func _box(c: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb
