extends CanvasLayer


# Player HUD: segmented health bar (top-left), cast bar and action bar
# (bottom-center), error/loot messages, death screen.

@export var player_path: NodePath

const UI = preload("res://scripts/ui_kit.gd")
const Items = preload("res://scripts/items.gd")
const Abilities = preload("res://scripts/abilities.gd")
const Runes = preload("res://scripts/runes.gd")
const Balance = preload("res://scripts/balance.gd")

# --- Your buffs / debuffs: icons at the top right, left of the minimap --------------
const STATUS_ICONS = preload("res://scripts/ui/status_icons.gd")
const MINIMAP_W := 180.0 + 16.0   # game_ui.gd MINIMAP_SIZE + margin
var _buff_icons: HFlowContainer
var _buff_t := 0.0

func _update_buffs() -> void:
	if _buff_icons == null:
		_buff_icons = STATUS_ICONS.new()
		_buff_icons.right_aligned = true
		_buff_icons.anchor_left = 1.0
		_buff_icons.anchor_right = 1.0
		_buff_icons.offset_right = -MINIMAP_W - 10.0
		_buff_icons.offset_left = -MINIMAP_W - 10.0 - 220.0
		_buff_icons.offset_top = 16.0
		add_child(_buff_icons)
	var status: Node = player.get("status")
	_buff_icons.show_effects(status.list() if status else [])

# --- Target frame (right side, under the minimap) -----------------------------------
# Name, health bar (+ shield), resource bar when the target has one, and its
# buffs / debuffs with tooltips. Shows your enemy target, or your friendly target.
var _tf: PanelContainer
var _tf_name: Label
var _tf_hp_fill: ColorRect
var _tf_hp_shield: ColorRect
var _tf_hp_text: Label
var _tf_res_row: Control
var _tf_res_fill: ColorRect
var _tf_res_text: Label
var _tf_icons: HFlowContainer
var _tf_cast_row: Control
var _tf_cast_fill: ColorRect
var _tf_cast_text: Label
var _tf_cast_spark: ColorRect
var _tf_last_cp := -1.0        # the target's cast progress last frame (-1 = not casting)
var _tf_end_until := 0.0       # showing the end flash until this time
var _tf_end_ok := true
var _tf_last_target: Variant = null
const TF_W := 260.0

func _build_target_frame() -> void:
	_tf = PanelContainer.new()
	_tf.anchor_left = 1.0
	_tf.anchor_right = 1.0
	_tf.offset_right = -16.0
	_tf.offset_left = -16.0 - TF_W - 20.0
	_tf.offset_top = 16.0 + 180.0 + 14.0
	_tf.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.55), 6))
	_tf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tf)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tf.add_child(v)
	_tf_name = Label.new()
	_tf_name.add_theme_font_size_override("font_size", 16)
	_tf_name.add_theme_color_override("font_outline_color", Color.BLACK)
	_tf_name.add_theme_constant_override("outline_size", 4)
	v.add_child(_tf_name)
	var hp := _tf_bar(v, 16, SEG_FULL)
	_tf_hp_fill = hp[0]
	_tf_hp_text = hp[1]
	_tf_hp_shield = ColorRect.new()
	_tf_hp_shield.color = Color(0.72, 0.9, 1.0, 0.85)
	_tf_hp_shield.size = Vector2(0, 16)
	_tf_hp_shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tf_hp_fill.get_parent().add_child(_tf_hp_shield)
	_tf_hp_fill.get_parent().move_child(_tf_hp_shield, 2)
	var res := _tf_bar(v, 10, Color(0.25, 0.5, 1.0))
	_tf_res_fill = res[0]
	_tf_res_text = res[1]
	_tf_res_row = _tf_res_fill.get_parent()
	# Enemy cast bar (so you know when and what to interrupt).
	var cb := _tf_bar(v, 14, Color(1.0, 0.72, 0.15))
	_tf_cast_fill = cb[0]
	_tf_cast_text = cb[1]
	_tf_cast_row = _tf_cast_fill.get_parent()
	_tf_cast_row.visible = false
	_tf_cast_spark = ColorRect.new()
	_tf_cast_spark.size = Vector2(3, 18)
	_tf_cast_spark.position.y = -2
	_tf_cast_spark.color = Color(1, 1, 0.95, 0.95)
	_tf_cast_spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tf_cast_row.add_child(_tf_cast_spark)
	_tf_cast_row.move_child(_tf_cast_spark, 2)   # under the text
	_tf_icons = STATUS_ICONS.new()
	_tf_icons.icon_size = 24.0
	_tf_icons.custom_minimum_size = Vector2(TF_W, 0)
	v.add_child(_tf_icons)
	_tf.visible = false

## A bar [fill ColorRect, value Label] added to `parent`.
func _tf_bar(parent: Control, h: float, col: Color) -> Array:
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(TF_W, h)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	var bg := ColorRect.new()
	bg.color = SEG_EMPTY
	bg.size = Vector2(TF_W, h)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bg)
	var fill := ColorRect.new()
	fill.color = col
	fill.size = Vector2(TF_W, h)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(fill)
	var text := Label.new()
	text.size = Vector2(TF_W, h)
	text.position.y = -2 if h >= 14 else -4
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 13 if h >= 14 else 10)
	text.add_theme_color_override("font_outline_color", Color.BLACK)
	text.add_theme_constant_override("outline_size", 4)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(text)
	return [fill, text]

func _current_target() -> Node:
	if player == null:
		return null
	var t = player.displayed_target() if player.has_method("displayed_target") else player.get("target")   # (not a mouseover cast's)
	if t != null and is_instance_valid(t) and t.is_alive():
		return t
	var f = player.get("friendly_target")
	if f != null and is_instance_valid(f) and f.is_alive():
		return f
	return null

func _update_target_frame(icons_too: bool) -> void:
	if _tf == null:
		_build_target_frame()
	var tgt := _current_target()
	_tf.visible = tgt != null
	if tgt != _tf_last_target:
		_tf_last_target = tgt
		_tf_last_cp = -1.0      # a new target: no leftover end flash from the old one
		_tf_end_until = 0.0
	if tgt == null:
		return
	var nm := str(tgt.get("display_name")) if tgt.get("display_name") != null else str(tgt.name)
	var lvl = tgt.get("level")
	var rank := str(tgt.get("rank")) if tgt.get("rank") != null else ""
	var friendly: bool = tgt.is_in_group("remote_player") or tgt.is_in_group("friendly")
	_tf_name.text = "%s%s%s" % [nm, ("  •  Lv %d" % int(lvl)) if lvl != null else "",
		("  •  " + rank.capitalize()) if rank == "elite" or rank == "boss" else ""]
	var trait_id := str(tgt.get("elite_trait")) if tgt.get("elite_trait") != null else ""
	if trait_id != "":
		_tf_name.text += "\n" + preload("res://scripts/core/elite_traits.gd").desc(trait_id)
	var name_col := Color(0.55, 1.0, 0.55) if friendly else Color(1.0, 0.85, 0.8)
	if rank == "boss":
		name_col = Color(1.0, 0.45, 0.4)
	elif rank == "elite":
		name_col = Color(1.0, 0.75, 0.3)
	_tf_name.add_theme_color_override("font_color", name_col)
	var hp := int(tgt.get("health")) if tgt.get("health") != null else 0
	var mhp := maxi(int(tgt.get("max_health")) if tgt.get("max_health") != null else 1, 1)
	var frac := clampf(float(hp) / mhp, 0.0, 1.0)
	_tf_hp_fill.size.x = TF_W * frac
	_tf_hp_fill.color = Color(0.25, 0.8, 0.3) if friendly else SEG_FULL
	var st: Node = tgt.get_node_or_null("Status")
	var shield := 0
	if st and st.has_method("total_absorb"):
		shield = st.total_absorb()
	_tf_hp_shield.position.x = TF_W * frac
	_tf_hp_shield.size.x = TF_W * clampf(float(shield) / mhp, 0.0, 1.0 - frac)
	_tf_hp_text.text = "%d / %d  (%d%%)%s" % [hp, mhp, int(round(frac * 100.0)), ("  +%d" % shield) if shield > 0 else ""]
	# Resource bar: any target that has one (e.g. a caster enemy's mana).
	var mres = tgt.get("max_resource")
	var has_res: bool = mres != null and float(mres) > 0.0
	_tf_res_row.visible = has_res
	if has_res:
		var cur := float(tgt.get("resource")) if tgt.get("resource") != null else 0.0
		_tf_res_fill.size.x = TF_W * clampf(cur / float(mres), 0.0, 1.0)
		var rc = tgt.get("resource_color")
		_tf_res_fill.color = rc if rc is Color else Color(0.25, 0.5, 1.0)
		_tf_res_text.text = "%d / %d" % [int(cur), int(mres)]
	var cp := float(tgt.cast_progress()) if tgt.has_method("cast_progress") else -1.0
	var now := Time.get_ticks_msec() / 1000.0
	if cp >= 0.0:
		_tf_cast_row.visible = true
		_tf_cast_fill.color = Color(1.0, 0.72, 0.15)
		_tf_cast_fill.size.x = TF_W * cp
		_tf_cast_spark.visible = true
		_tf_cast_spark.position.x = TF_W * cp - 1.5
		_tf_cast_text.text = "%s  %.1f s" % [str(tgt.cast_display_name()), float(tgt.cast_time_left())]
		_tf_end_until = 0.0
	elif _tf_last_cp >= 0.0:
		# The cast just ended: white flash if it went off, red if it was interrupted.
		_tf_end_ok = _tf_last_cp >= 0.9
		_tf_end_until = now + (0.25 if _tf_end_ok else 0.6)
		_tf_cast_fill.size.x = TF_W
		_tf_cast_fill.color = Color(1, 1, 1) if _tf_end_ok else Color(0.9, 0.25, 0.2)
		_tf_cast_spark.visible = false
		if not _tf_end_ok:
			_tf_cast_text.text = "Interrupted"
	_tf_cast_row.visible = cp >= 0.0 or now < _tf_end_until
	_tf_last_cp = cp
	if icons_too:
		_tf_icons.show_effects(st.list() if st else [])

const SEG_FULL := Color(0.85, 0.15, 0.15)
const SEG_EMPTY := Color(0.22, 0.22, 0.22)
const CAST_FILL := Color(0.45, 0.85, 1.0)
const CAST_FAIL := Color(0.9, 0.25, 0.2)

var player: Node
var _hp_label: Label

var _cast_root: Control
var _cast_fill: ColorRect
var _cast_spark: ColorRect
var _cast_spark_glow: ColorRect
var _cast_flash: ColorRect
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
	bus.player_revived.connect(func():
		_clear_death_screen()
		_cast_root.visible = true)
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
		_apply_bar_settings()   # (the top action bar pushes messages up)
	_error_label.text = msg
	_error_label.add_theme_color_override("font_color", color)
	_error_label.modulate.a = 1.0
	if _error_tween:
		_error_tween.kill()
	_error_tween = create_tween()
	_error_tween.tween_interval(1.0)
	_error_tween.tween_property(_error_label, "modulate:a", 0.0, 0.5)

var _death_nodes: Array = []

func _clear_death_screen() -> void:
	for n in _death_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_death_nodes.clear()

func _on_player_died() -> void:
	_cast_root.visible = false
	_clear_death_screen()
	var shade := ColorRect.new()
	shade.color = Color(0.25, 0, 0, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_death_nodes.append(shade)
	var label := Label.new()
	_death_nodes.append(label)
	var key: String = get_node("/root/Settings").key_text("restart")
	label.text = "You died\nPress %s to restart" % key
	var net := get_node_or_null("/root/Net")
	if net and net.with_others():
		label.text = "You died\nYour party fights on - the floor restarts if everyone falls"
	if not Balance.ROGUELIKE_DEATH:
		# No drawbacks for now: get back up, or leave.
		label.text = "You died\nPress %s to revive" % key
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		row.anchor_left = 0.5
		row.anchor_right = 0.5
		row.anchor_top = 0.5
		row.anchor_bottom = 0.5
		row.offset_left = -220
		row.offset_right = 220
		row.offset_top = 20
		row.offset_bottom = 70
		var revive := UI.button("Revive", 20, Vector2(200, 48))
		revive.tooltip_text = "Get back up at the dungeon entrance (or the last boss room you cleared), with full health."
		revive.pressed.connect(func(): get_node("/root/GameManager").revive_local())
		row.add_child(revive)
		var menu := UI.button("Main Menu", 20, Vector2(200, 48))
		menu.pressed.connect(func(): get_node("/root/GameManager").go_to_menu())
		row.add_child(menu)
		add_child(row)
		_death_nodes.append(row)
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
	_death_nodes.append(info)

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

	# One continuous bar: red health, pale blue shield (absorbs) after it.
	_hp_bar = Control.new()
	_hp_bar.custom_minimum_size = Vector2(HP_W, 16)
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_hp_bar)
	var bg := ColorRect.new()
	bg.color = SEG_EMPTY
	bg.size = Vector2(HP_W, 16)
	_hp_bar.add_child(bg)
	_hp_fill = ColorRect.new()
	_hp_fill.color = SEG_FULL
	_hp_fill.size = Vector2(HP_W, 16)
	_hp_bar.add_child(_hp_fill)
	_hp_shield = ColorRect.new()
	_hp_shield.color = Color(0.72, 0.9, 1.0, 0.85)
	_hp_shield.size = Vector2(0, 16)
	_hp_bar.add_child(_hp_shield)
	# Bruise (Martial tank): the health it will still take, darker at the end of the red.
	_hp_bruise = ColorRect.new()
	_hp_bruise.color = Color(0.32, 0.12, 0.38, 0.9)
	_hp_bruise.size = Vector2(0, 16)
	_hp_bar.add_child(_hp_bruise)

	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 16)
	row.add_child(_hp_label)

	# "In Combat" tag next to the bar.
	_combat_label = Label.new()
	_combat_label.text = "In Combat"
	_combat_label.add_theme_font_size_override("font_size", 14)
	_combat_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	_combat_label.visible = false
	row.add_child(_combat_label)
	get_node("/root/SignalBus").combat_state_changed.connect(func(on): _combat_label.visible = on)
	get_node("/root/SignalBus").buffs_changed.connect(func():
		if player:
			_on_health_changed(player.health, player.max_health))

const HP_W := 178.0
var _hp_bar: Control
var _hp_fill: ColorRect
var _hp_shield: ColorRect
var _hp_bruise: ColorRect
var _combat_label: Label

## Bruise: the end of the red health that is still to come, darker.
func _update_bruise_segment() -> void:
	if _hp_bruise == null or player == null or player.get("brawler") == null:
		return
	var m := float(maxi(player.max_health, 1))
	var frac := clampf(float(player.health) / m, 0.0, 1.0)
	var w := HP_W * clampf(float(player.brawler.bruise()) / m, 0.0, frac)
	if absf(_hp_bruise.size.x - w) > 0.25:
		_hp_bruise.size.x = w
	_hp_bruise.position.x = HP_W * frac - _hp_bruise.size.x

func _on_health_changed(current: int, maximum: int) -> void:
	if _hp_fill == null:
		return
	var m := float(maxi(maximum, 1))
	var frac := clampf(float(current) / m, 0.0, 1.0)
	_hp_fill.size.x = HP_W * frac
	var shield := 0
	var st: Node = player.get_node_or_null("Status") if player else null
	if st and st.has_method("total_absorb"):
		shield = st.total_absorb()
	_hp_shield.position.x = HP_W * frac
	_hp_shield.size.x = HP_W * clampf(float(shield) / m, 0.0, 1.0 - frac)
	_hp_label.text = "%d / %d" % [current, maximum] + ("  (+%d)" % shield if shield > 0 else "")

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

	# Spark riding the fill's edge: a bright core with a soft glow around it.
	_cast_spark_glow = ColorRect.new()
	_cast_spark_glow.size = Vector2(14, CAST_H + 8)
	_cast_spark_glow.color = Color(1, 1, 1, 0.25)
	_cast_spark_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cast_root.add_child(_cast_spark_glow)
	_cast_spark = ColorRect.new()
	_cast_spark.size = Vector2(3, CAST_H + 4)
	_cast_spark.color = Color(1, 1, 0.95, 0.95)
	_cast_spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cast_root.add_child(_cast_spark)
	# White flash over the whole bar the moment a cast goes off.
	_cast_flash = ColorRect.new()
	_cast_flash.size = Vector2(CAST_W, CAST_H)
	_cast_flash.color = Color(1, 1, 1, 0)
	_cast_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cast_root.add_child(_cast_flash)

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

# --- Action bars (layout comes from PlayerData.action_bar) -------------------------
# Bar 0 is the main bar (bottom centre, slots 1-8). Bars 1-3 are the optional
# ones from Settings > Interface: above the main bar (slots 9-16), on the left
# (17-24) and on the right of the screen (25-32). A slot holds an ability or a
# macro; an on-use trinket shows as its "Use Trinket" button.

const ACTION_SLOTS := 8
const SLOT_SIZE := 52.0
const EXTRA_SLOT_SIZE := 44.0
const BAR_COUNT := 4
const Macros = preload("res://scripts/core/macros.gd")

var _slot_buttons := {}     # slot (1..32) -> Button
var _slot_cd := {}          # slot -> cooldown overlay Control
var _bar_roots := {}        # bar (1..3) -> its root Control (hidden when the bar is off)
var _bar_panels := {}       # bar (1..3) -> the panel that takes the bar's own opacity
var _bar_grids := {}        # bar (1..3) -> its GridContainer of slots
var _style_idle: StyleBoxFlat
var _style_active: StyleBoxFlat
var _style_queued: StyleBoxFlat

func _slot_id(i: int) -> String:
	var pd := get_node_or_null("/root/PlayerData")
	return pd.action_bar[i - 1] if pd and i >= 1 and i <= pd.action_bar.size() else ""

static func bar_of(slot: int) -> int:
	return (slot - 1) / ACTION_SLOTS

## Height the top bar takes above the main bar (0 while it is off): the cast
## bar and the messages move up by this much.
func _top_bar_lift() -> float:
	return EXTRA_SLOT_SIZE + 12.0 + 8.0 if get_node("/root/Settings").is_bar_on(1) else 0.0

func _build_action_bar() -> void:
	_style_idle = UI.box(Color(0.06, 0.065, 0.085, 0.9), UI.BORDER, 2, 6)
	_style_active = UI.box(Color(0.1, 0.14, 0.2, 0.95), UI.ACCENT, 3, 6)
	_style_queued = UI.box(Color(0.1, 0.18, 0.24, 0.95), Color(0.55, 0.9, 1.0), 3, 6)

	# Main bar.
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
		row.add_child(_make_slot(i, SLOT_SIZE))

	# Extra bars (built once, shown when turned on in Settings > Interface).
	for b in range(1, BAR_COUNT):
		_build_extra_bar(b)

	var pd := get_node_or_null("/root/PlayerData")
	if pd:
		pd.changed_late.connect(_refresh_action_bar)
	var settings := get_node("/root/Settings")
	settings.keybinds_changed.connect(_refresh_action_bar)
	settings.interface_changed.connect(_apply_bar_settings)
	get_viewport().size_changed.connect(_layout_side_bars)
	_apply_bar_settings()
	_refresh_action_bar()

## One of the optional bars: bar 1 lies above the main bar, 2 stands on the
## left edge of the screen, 3 on the right edge (placed by _layout_side_bars).
func _build_extra_bar(b: int) -> void:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if b == 1:
		var long := ACTION_SLOTS * EXTRA_SLOT_SIZE + (ACTION_SLOTS - 1) * 4 + 14
		root.anchor_left = 0.5
		root.anchor_right = 0.5
		root.anchor_top = 1.0
		root.anchor_bottom = 1.0
		root.offset_left = -long / 2.0
		root.offset_right = long / 2.0
		root.offset_bottom = -SLOT_SIZE - 26 - 16 - 6      # just above the XP bar
		root.offset_top = root.offset_bottom - (EXTRA_SLOT_SIZE + 12)
	elif b == 3:
		root.anchor_left = 1.0
		root.anchor_right = 1.0
	add_child(root)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0.55), UI.BORDER, 1, 8))
	root.add_child(panel)
	# A grid: one row for the top bar; one column (tall screens) or two (short
	# ones) for the side bars.
	var grid := GridContainer.new()
	grid.columns = ACTION_SLOTS if b == 1 else 1
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_child(grid)
	for n in range(1, ACTION_SLOTS + 1):
		grid.add_child(_make_slot(b * ACTION_SLOTS + n, EXTRA_SLOT_SIZE))
	_bar_roots[b] = root
	_bar_panels[b] = panel
	_bar_grids[b] = grid

## Screens shorter than this get side bars two slots wide (a single column
## would run into the chat and the target frame).
const SIDE_BAR_TALL_SCREEN := 850.0
## The left bar stays below the health / resource bars and above the chat; the
## right one below the minimap and the target frame.
const LEFT_BAR_MIN_TOP := 170.0
const LEFT_BAR_BOTTOM_GAP := 380.0   # the chat, and the Training Room panel above it
const RIGHT_BAR_MIN_TOP := 400.0
const RIGHT_BAR_BOTTOM_GAP := 30.0

## Size and place the two side bars for the current screen size.
func _layout_side_bars() -> void:
	if not _bar_roots.has(2):
		return
	var screen := get_viewport().get_visible_rect().size
	var cols := 1 if screen.y >= SIDE_BAR_TALL_SCREEN else 2
	var rows := ceili(float(ACTION_SLOTS) / cols)
	var w := cols * EXTRA_SLOT_SIZE + (cols - 1) * 4 + 12
	var h := rows * EXTRA_SLOT_SIZE + (rows - 1) * 4 + 14
	for b in [2, 3]:
		(_bar_grids[b] as GridContainer).columns = cols
		var root: Control = _bar_roots[b]
		# Centred a little low, but kept inside its free stretch of the screen edge.
		var min_top := LEFT_BAR_MIN_TOP if b == 2 else RIGHT_BAR_MIN_TOP
		var gap := LEFT_BAR_BOTTOM_GAP if b == 2 else RIGHT_BAR_BOTTOM_GAP
		var top := clampf((screen.y - h) / 2.0 + 30.0, min_top, maxf(min_top, screen.y - gap - h))
		root.offset_top = top
		root.offset_bottom = top + h
		if b == 2:
			root.offset_left = 8
			root.offset_right = 8 + w
		else:
			root.offset_right = -8
			root.offset_left = -8 - w

## Show / hide the extra bars and set their opacity; make room above the main
## bar for the top one.
func _apply_bar_settings() -> void:
	_refresh_venom_bar.call_deferred()   # (it sits above the top bar when that is on)
	var settings := get_node("/root/Settings")
	for b in _bar_roots:
		_bar_roots[b].visible = settings.is_bar_on(b)
		_bar_panels[b].modulate.a = settings.bar_opacity(b)
	_layout_side_bars()   # (the interface size changes how much room there is)
	var lift := _top_bar_lift()
	if _cast_root:
		_cast_root.offset_top = -120.0 - lift
		_cast_root.offset_bottom = -120.0 + CAST_H - lift
	if _error_label:
		_error_label.offset_top = -160 - lift
		_error_label.offset_bottom = -132 - lift

## One action-bar slot: the button, its cooldown sweep, key and charge labels,
## and drag and drop (move / swap between any two slots of any bar).
func _make_slot(i: int, size: float) -> Button:
	var b := Abilities.make_slot(size)
	b.pressed.connect(func(): if player: player.activate_ability(i))
	_slot_buttons[i] = b

	# Cooldown overlay: dark fill that shrinks as the cooldown runs + seconds left.
	var cd := Control.new()
	cd.set_anchors_preset(Control.PRESET_FULL_RECT)
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := 16 if size >= 50.0 else 14
	cd.draw.connect(func():
		var frac: float = cd.get_meta("frac", 0.0)
		if frac <= 0.0:
			return
		var h := cd.size.y * frac
		cd.draw_rect(Rect2(Vector2(0, cd.size.y - h), Vector2(cd.size.x, h)), Color(0, 0, 0, 0.65), true)
		var f := ThemeDB.fallback_font
		var txt := "%.1f" % float(cd.get_meta("left", 0.0))
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font).x
		var p := Vector2((cd.size.x - tw) / 2.0, cd.size.y / 2.0 + 6)
		cd.draw_string_outline(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font, 4, Color.BLACK)
		cd.draw_string(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font, Color.WHITE))
	b.add_child(cd)
	_slot_cd[i] = cd

	# Drag a button onto another slot to move it there (the two swap). An
	# ability from the spellbook, a macro, or an on-use trinket can be dropped in.
	b.set_drag_forwarding(
		func(_pos): return _bar_drag(b, i),
		func(_pos, data): return _can_drop_on_slot(data),
		func(_pos, data): _drop_on_slot(i, data))

	var key := UI.label("", 13 if size >= 50.0 else 11, Color.WHITE)
	key.name = "Key"
	key.position = Vector2(4, 1)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(key)

	# Charge count (Ice Shards) in the bottom-right corner.
	var charges := UI.label("", 15 if size >= 50.0 else 13, Color(0.75, 0.95, 1.0))
	charges.name = "Charges"
	charges.add_theme_color_override("font_outline_color", Color.BLACK)
	charges.add_theme_constant_override("outline_size", 4)
	charges.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	charges.position = Vector2(0, size - 22)
	charges.size = Vector2(size - 4, 20)
	charges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(charges)

	# The move a Brawler strike would finish its Chain with (Martial tank), along the top.
	var finish := UI.label("", 9 if size < 50.0 else 10, Color(1.0, 0.83, 0.3))
	finish.name = "Finish"
	finish.add_theme_color_override("font_outline_color", Color.BLACK)
	finish.add_theme_constant_override("outline_size", 4)
	finish.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	finish.position = Vector2(0, size * 0.5 - 8)
	finish.size = Vector2(size, 16)
	finish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(finish)
	return b

func _player_in_combat() -> bool:
	return player != null and player.has_method("is_in_combat") and player.is_in_combat()

## The trinket button ("trinket_1" / "trinket_2") for the on-use trinket being
## dragged from the bag ("inv" drag), or "" if it isn't one.
func _dragged_trinket_item(data: Dictionary) -> String:
	var pd := get_node_or_null("/root/PlayerData")
	if pd == null or data.get("type") != "inv":
		return ""
	var item := str(pd.inventory[int(data["index"])])
	if item == "" or Items.use_effect_of(item) == null or not str(Items.get_item(item).get("slot", "")).begins_with("Trinket"):
		return ""
	return item

func _can_drop_on_slot(data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	match str(data.get("type", "")):
		"hud_bar":
			return true
		"ability":
			return not _player_in_combat()
		"inv":
			return _dragged_trinket_item(data) != "" and not _player_in_combat()
	return false

func _drop_on_slot(slot: int, data: Dictionary) -> void:
	var pd := get_node_or_null("/root/PlayerData")
	if pd == null:
		return
	match str(data.get("type", "")):
		"ability":   # from the spellbook (P), the macro window, or an equipped trinket
			pd.set_action_slot(slot - 1, str(data["id"]), -1)
		"inv":
			# An on-use trinket from the bag: put it on, then its button on the bar.
			var item := _dragged_trinket_item(data)
			var err: String = pd.equip_from_inventory(int(data["index"]))
			if err != "":
				_show_error(err)
				return
			for button_id in Abilities.TRINKET_SLOTS:
				if str(pd.equipment.get(Abilities.TRINKET_SLOTS[button_id], "")) == item:
					pd.set_action_slot(slot - 1, str(button_id), -1)
		"hud_bar":
			var from := int(data["slot"])
			pd.set_action_slot(slot - 1, str(pd.action_bar[from - 1]), from - 1)

## Start dragging the button in bar slot `i`. Dropping it anywhere that isn't a
## slot leaves the bar as it was.
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
	# At max level there is nothing left to earn: the whole bar is hidden.
	(_xp_fill.get_parent() as Control).visible = need > 0
	if need <= 0:
		return
	_xp_fill.size.x = (XP_BAR_W - 2) * clampf(float(pd.xp) / need, 0.0, 1.0)
	_xp_label.text = "Level %d  •  %d / %d XP" % [pd.level, pd.xp, need]

# --- Resource bars (under HP): only the resources used by the abilities on the bar ---

const RES_ORDER := ["mana", "energy", "fury"]
const RES_COLORS := {
	"mana": Color(0.25, 0.5, 1.0),
	"energy": Color(1.0, 0.85, 0.2),
	"fury": Color(0.9, 0.25, 0.1),
}
const RES_LABELS := {"mana": "MP", "energy": "EN", "fury": "FY"}
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
		for slot_id in pd.action_bar:
			# (A macro counts for every ability in it.)
			var ids: Array[String] = [slot_id]
			if Macros.is_macro(slot_id):
				ids = Macros.abilities_of(slot_id)
			for id in ids:
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
	_build_verse_row(pd)

# --- Verses (Holy healer) ----------------------------------------------------------
# A row of VERSE_MAX pips under the resource bars, each in the colour of the Hymn
# its Verse suits, and the Hymn being sung. Shown while a Sing ability is on a bar.
const SING_IDS := ["singmercy", "singchorus", "singvigil"]
var _verse_row := {}   # {"segs": Array[ColorRect], "label": Label, "last": String}

func _build_verse_row(pd: Node) -> void:
	_verse_row = {}
	if pd == null:
		return
	var wanted := false
	for slot_id in pd.action_bar:
		var ids: Array[String] = [slot_id]
		if Macros.is_macro(slot_id):
			ids = Macros.abilities_of(slot_id)
		for id in ids:
			if SING_IDS.has(id):
				wanted = true
	if not wanted:
		return
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.55), 6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var title := Label.new()
	title.text = "VS"
	title.custom_minimum_size = Vector2(26, 0)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	row.add_child(title)
	var segs_box := HBoxContainer.new()
	segs_box.add_theme_constant_override("separation", 4)
	row.add_child(segs_box)
	var segs: Array[ColorRect] = []
	for i in Balance.VERSE_MAX:
		var s := ColorRect.new()
		s.custom_minimum_size = Vector2(22, 12)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		segs_box.add_child(s)
		segs.append(s)
	var val := Label.new()
	val.add_theme_font_size_override("font_size", 14)
	row.add_child(val)
	_res_box.add_child(panel)
	_verse_row = {"segs": segs, "label": val, "last": "?"}

func _update_verse_row() -> void:
	if _verse_row.is_empty() or player == null or not ("verses" in player):
		return
	var key := "%s|%s" % [player.hymn, ",".join(PackedStringArray(player.verses))]
	if key == _verse_row["last"]:
		return
	_verse_row["last"] = key
	var segs: Array = _verse_row["segs"]
	for i in segs.size():
		segs[i].color = Abilities.HYMN_COLORS.get(str(player.verses[i]), SEG_EMPTY) if i < player.verses.size() else SEG_EMPTY
	_verse_row["label"].text = str(player.HYMN_NAMES.get(player.hymn, "No Hymn"))
	_verse_row["label"].add_theme_color_override("font_color", Abilities.HYMN_COLORS.get(player.hymn, Color(0.7, 0.7, 0.75)))

func _update_resource_bars() -> void:
	_update_verse_row()
	_update_venom_bar()
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
	_refresh_venom_bar()
	_refresh_wheel_strip()
	_refresh_chain_strip()
	var settings := get_node_or_null("/root/Settings")
	for i in _slot_buttons:
		var id := _slot_id(i)
		Abilities.set_slot_ability(_slot_buttons[i], id)
		var key: Label = _slot_buttons[i].get_node("Key")
		if settings:
			var text: String = settings.key_text(settings.slot_action(i))
			key.text = "" if text == "—" else text   # extra-bar slots have no key until you bind one
		key.add_theme_color_override("font_color", Color.WHITE if id != "" else UI.TEXT_DIM)

func _update_action_bar() -> void:
	for i in _slot_buttons:
		var bar := bar_of(i)
		if bar > 0 and not _bar_roots[bar].visible:
			continue
		var slot_id := _slot_id(i)
		# A macro's button behaves like the ability it is linked to (none: always lit).
		var id := Macros.link_of(slot_id) if Macros.is_macro(slot_id) else slot_id
		var b: Button = _slot_buttons[i]
		if Abilities.WHEEL_SLOTS.has(id):
			id = player.wheel.form_of(id)   # Martial warrior: the held weapon's move
			if slot_id != id and Abilities.WHEEL_SLOTS.has(slot_id) \
					and str(b.get_node("AbilityIcon").get_meta("ability_id", "")) != id:
				Abilities.set_slot_ability(b, id)   # its icon and tooltip change with the weapon
		elif Abilities.ROGUE_KILL_FORMS.has(id):
			id = player.rogue.form_of(id)   # Martial DPS: a builder is its Kill form in a Kill window
			if Abilities.ROGUE_KILL_FORMS.has(slot_id) \
					and str(b.get_node("AbilityIcon").get_meta("ability_id", "")) != id:
				Abilities.set_slot_ability(b, id)   # its icon and tooltip change with the window
		var active := false
		var left := 0.0
		var total := 1.0
		if id != "":
			active = (player.casting and player.current_spell == id) \
				or (player.placing and id == player.placing_id)
			var usable := true
			if Abilities.info(id).get("needs_target", false):
				usable = player.has_valid_target()
			usable = usable and player.can_afford(id) and player.target_in_range(id)
			if Abilities.is_trinket_slot(id):
				usable = player.trinket_usable(id)   # an item with a Use: effect is equipped there
			b.get_node("AbilityIcon").modulate.a = 1.0 if usable else 0.4
			left = player.cooldown_left(id)
			total = max(player.cooldown_total(id), 0.01)
			if id == "iceshards" and player.has_method("shard_recharge_left"):
				# No charges: the overlay counts down to the next one.
				if int(player.ice_shard_charges) <= 0 and not player.shards_firing():
					left = player.shard_recharge_left()
					total = Balance.ICE_SHARDS_RECHARGE
		elif slot_id != "":
			b.get_node("AbilityIcon").modulate.a = 1.0   # a macro that isn't linked
		var ch: Label = b.get_node("Charges")
		var ch_text: String = player.charges_text(id) if id != "" and player.has_method("charges_text") else ""
		if ch.text != ch_text:
			ch.text = ch_text
		var fin: Label = b.get_node_or_null("Finish")
		if fin:
			var fin_text: String = player.brawler.finish_label(id) if Abilities.BRAWLER_STRIKES.has(id) else ""
			if fin.text != fin_text:
				fin.text = fin_text
		var cd: Control = _slot_cd[i]
		var frac := clampf(left / total, 0.0, 1.0)
		if frac != float(cd.get_meta("frac", 0.0)) or left != float(cd.get_meta("left", 0.0)):
			cd.set_meta("frac", frac)
			cd.set_meta("left", left)
			cd.queue_redraw()
		var style := _style_active if active else _style_idle
		if id != "" and player.has_method("queued_ability") and player.queued_ability() == id:
			style = _style_queued   # waiting in the spell queue: fires the moment it can
		if b.get_theme_stylebox("normal") != style:
			b.add_theme_stylebox_override("normal", style)

# --- Per-frame -----------------------------------------------------------------

func _process(delta: float) -> void:
	if player == null:
		return
	_update_action_bar()
	_update_wheel_strip()
	_update_chain_strip()
	_update_bruise_segment()
	_update_resource_bars()
	_buff_t -= delta
	var slow_tick := _buff_t <= 0.0
	if slow_tick:
		_buff_t = 0.1
		_update_buffs()
	_update_target_frame(slow_tick)
	var total: float = player.cast_duration

	if player.casting:
		var remaining: float = max(player.cast_timer, 0.0)
		var progress := 1.0 - remaining / total
		if player.cast_is_channel:
			progress = remaining / total   # channels drain from full to empty
		progress = clampf(progress, 0.0, 1.0)
		_cast_root.visible = true
		_cast_root.modulate.a = 1.0
		_cast_fill.color = _school_color(str(player.current_spell))
		_cast_fill.size.x = CAST_W * progress
		_cast_spark.visible = true
		_cast_spark_glow.visible = true
		_cast_spark.position = Vector2(CAST_W * progress - 1.5, -2)
		_cast_spark_glow.position = Vector2(CAST_W * progress - 7.0, -4)
		_cast_flash.color.a = 0.0
		_cast_label.text = player.cast_name
		_cast_time_label.text = "%.1f" % remaining
		_was_casting = true
		_hide_timer = 0.0
		return

	if _was_casting:
		_was_casting = false
		_cast_spark.visible = false
		_cast_spark_glow.visible = false
		if player.cast_timer <= 0.0:
			# Went off: full bar + a white flash that fades with it (channels end empty).
			_cast_fill.size.x = 0.0 if player.cast_is_channel else CAST_W
			_cast_time_label.text = ""
			_cast_ok = true
			_hide_timer = 0.3
		else:
			# Interrupted
			_cast_fill.color = CAST_FAIL
			_cast_fill.size.x = CAST_W
			_cast_label.text = "Interrupted"
			_cast_time_label.text = ""
			_cast_ok = false
			_hide_timer = 0.6

	if _hide_timer > 0.0:
		_hide_timer -= delta
		_cast_root.modulate.a = clampf(_hide_timer / 0.25, 0.0, 1.0)
		_cast_flash.color.a = clampf(_hide_timer / 0.3, 0.0, 1.0) * 0.65 if _cast_ok else 0.0
		if _hide_timer <= 0.0:
			_cast_root.visible = false

var _cast_ok := true

## Cast bar color: the spell's school (Frost blue, Fire orange...).
func _school_color(spell: String) -> Color:
	var cat := Abilities.category_of(spell)
	if cat == "":
		return CAST_FILL
	return preload("res://scripts/categories.gd").color(cat).lightened(0.15)

func _box(c: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

# --- Venom (Nature archer: Venomstring) --------------------------------------------
# A thin bar just above the main action bar, shown only while Adder, Asp and
# Krait Arrow are all on the bars (macros count). It fills from the player's
# Venom (player.gd, "Nature archer: Venomstring") and glows while Venom Flows.
const VENOM_ARROWS := ["adderarrow", "asparrow", "kraitarrow"]
const VENOM_COLOR := Color(0.4, 0.95, 0.3)
const VENOM_BAR_H := 12.0
var _venom_root: Control
var _venom_fill: ColorRect
var _venom_label: Label
var _venom_last := -1.0

func _refresh_venom_bar() -> void:
	var pd := get_node_or_null("/root/PlayerData")
	var found := []
	if pd:
		for slot_id in pd.action_bar:
			var ids: Array[String] = [slot_id]
			if Macros.is_macro(slot_id):
				ids = Macros.abilities_of(slot_id)
			for id in ids:
				if VENOM_ARROWS.has(id) and not found.has(id):
					found.append(id)
	var wanted := found.size() == VENOM_ARROWS.size()
	if not wanted:
		if _venom_root:
			_venom_root.visible = false
		return
	if _venom_root == null:
		var width := ACTION_SLOTS * SLOT_SIZE + (ACTION_SLOTS - 1) * 6 + 16
		_venom_root = Panel.new()
		_venom_root.anchor_left = 0.5
		_venom_root.anchor_right = 0.5
		_venom_root.anchor_top = 1.0
		_venom_root.anchor_bottom = 1.0
		_venom_root.offset_left = -width / 2.0
		_venom_root.offset_right = width / 2.0
		_venom_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_venom_root.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.6), 4))
		add_child(_venom_root)
		_venom_fill = ColorRect.new()
		_venom_fill.color = VENOM_COLOR
		_venom_fill.position = Vector2(2, 2)
		_venom_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_venom_root.add_child(_venom_fill)
		_venom_label = Label.new()
		_venom_label.add_theme_font_size_override("font_size", 11)
		_venom_label.anchor_right = 1.0
		_venom_label.anchor_bottom = 1.0
		_venom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_venom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_venom_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_venom_root.add_child(_venom_label)
	var top := -SLOT_SIZE - 26 - 4 - VENOM_BAR_H - _top_bar_lift()
	_venom_root.offset_top = top
	_venom_root.offset_bottom = top + VENOM_BAR_H
	_venom_root.visible = true
	_venom_last = -1.0

func _update_venom_bar() -> void:
	if _venom_root == null or not _venom_root.visible or player == null or not player.has_method("venom"):
		return
	var v: float = player.venom()
	var flowing: bool = player.venom_flow()
	var key := v + (1000.0 if flowing else 0.0)
	if is_equal_approx(key, _venom_last):
		return
	_venom_last = key
	var inner := _venom_root.size.x - 4.0
	_venom_fill.size = Vector2(maxf(inner * clampf(v / Balance.VENOM_MAX, 0.0, 1.0), 0.0), VENOM_BAR_H - 4.0)
	_venom_fill.color = VENOM_COLOR.lightened(0.25) if flowing else VENOM_COLOR.darkened(0.25)
	_venom_label.text = "Venom %d" % int(v)

# --- The Wheel (Martial warrior) ---------------------------------------------------------
# A strip above the main action bar while the Wheel is out (one of its buttons is on
# the bars): its weapons in the order they turn, the held one large with its uses
# left and Cracks. Out of combat, clicking it turns the Wheel to the next weapon.
const WHEEL_CELL := 30.0
const WHEEL_HELD := 42.0
var _wheel_root: PanelContainer
var _wheel_row: HBoxContainer
var _wheel_label: Label
var _wheel_last := ""

func _refresh_wheel_strip() -> void:
	var wanted: bool = player != null and player.get("wheel") != null and player.wheel.is_out()
	if not wanted:
		if _wheel_root:
			_wheel_root.visible = false
		return
	if _wheel_root == null:
		_wheel_root = PanelContainer.new()
		_wheel_root.anchor_left = 0.5
		_wheel_root.anchor_right = 0.5
		_wheel_root.anchor_top = 1.0
		_wheel_root.anchor_bottom = 1.0
		_wheel_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_wheel_root.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_wheel_root.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.55), 6))
		_wheel_root.tooltip_text = "Your Wheel. Out of combat, click it to turn it to the next weapon."
		_wheel_root.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_turn_wheel())
		add_child(_wheel_root)
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_wheel_root.add_child(box)
		_wheel_row = HBoxContainer.new()
		_wheel_row.add_theme_constant_override("separation", 4)
		_wheel_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_wheel_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(_wheel_row)
		_wheel_label = Label.new()
		_wheel_label.add_theme_font_size_override("font_size", 12)
		_wheel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_wheel_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(_wheel_label)
	var bottom := -SLOT_SIZE - 26 - 8 - _top_bar_lift()
	_wheel_root.offset_bottom = bottom
	_wheel_root.offset_top = bottom - WHEEL_HELD - 8
	_wheel_root.visible = true
	_wheel_last = ""

# --- The Chain (Martial tank: the Brawler) ------------------------------------------------
# A strip above the main action bar while the Brawler is out: the Chain's inputs so far
# (the same as the orbs on your back), empty cells for the ones still to come.
const CHAIN_CELL := 34.0
var _chain_root: PanelContainer
var _chain_row: HBoxContainer
var _chain_last := "-"

func _refresh_chain_strip() -> void:
	var wanted: bool = player != null and player.get("brawler") != null and player.brawler.is_out()
	if not wanted:
		if _chain_root:
			_chain_root.visible = false
		return
	if _chain_root == null:
		_chain_root = PanelContainer.new()
		_chain_root.anchor_left = 0.5
		_chain_root.anchor_right = 0.5
		_chain_root.anchor_top = 1.0
		_chain_root.anchor_bottom = 1.0
		_chain_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_chain_root.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_chain_root.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.55), 6))
		_chain_root.tooltip_text = "Your Chain. The strike that ends it picks the move; three different strikes make the strong one."
		add_child(_chain_root)
		_chain_row = HBoxContainer.new()
		_chain_row.add_theme_constant_override("separation", 4)
		_chain_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_chain_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_chain_root.add_child(_chain_row)
	var bottom := -SLOT_SIZE - 26 - 8 - _top_bar_lift()
	_chain_root.offset_bottom = bottom
	_chain_root.offset_top = bottom - CHAIN_CELL - 8
	_chain_root.visible = true
	_chain_last = "-"

func _update_chain_strip() -> void:
	if _chain_root == null or not _chain_root.visible or player == null:
		return
	var inputs: Array = player.brawler.chain()
	var key := ",".join(PackedStringArray(inputs))
	if key == _chain_last:
		return
	_chain_last = key
	for c in _chain_row.get_children():
		c.queue_free()
	for i in Balance.CHAIN_LENGTH:
		var cell := Abilities.make_slot(CHAIN_CELL)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i < inputs.size():
			Abilities.set_slot_ability(cell, str(inputs[i]))
		else:
			cell.modulate.a = 0.35
		_chain_row.add_child(cell)

func _turn_wheel() -> void:
	if player == null or player.get("wheel") == null:
		return
	if not player.wheel.turn_out_of_combat():
		player._error("The Wheel only turns out of combat")

func _update_wheel_strip() -> void:
	if _wheel_root == null or not _wheel_root.visible or player == null:
		return
	var ws: Array = player.wheel.weapons()
	var held: String = player.wheel.held_weapon()
	var key := "%s|%s|%d|%d" % [",".join(PackedStringArray(ws)), held, player.wheel.uses_left(), player.wheel.cracks()]
	if key == _wheel_last:
		return
	_wheel_last = key
	for c in _wheel_row.get_children():
		c.queue_free()
	# The held weapon first, then the rest in the order they will come.
	var start := maxi(ws.find(held), 0)
	for i in ws.size():
		var w := str(ws[(start + i) % ws.size()])
		var cell := Abilities.make_slot(WHEEL_HELD if i == 0 else WHEEL_CELL)
		Abilities.set_slot_ability(cell, w)
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.pressed.connect(_turn_wheel)
		if i > 0:
			cell.modulate.a = 0.85 if i == 1 else 0.55
		_wheel_row.add_child(cell)
	_wheel_label.text = "%d / %d uses\n%d Cracks" % [player.wheel.uses_left(), Balance.WHEEL_USES, player.wheel.cracks()]
