extends CanvasLayer

# Attribute points panel (autoload "AttributeScreen").
# Every level gives PlayerData.ATTRIBUTE_POINTS_PER_LEVEL point(s). In game a
# small panel on the right side shows your unspent points: +/- to plan, Apply to
# commit (points can only be ADDED in game - "-" only removes points planned in
# this panel). It never pauses and never blocks your keys, so you can keep
# fighting. "Later" shrinks it to a small button; the panel pops open again on
# your next level-up. Points can also be moved freely in the main menu
# (Character tab).

const UI = preload("res://scripts/ui_kit.gd")
const Stats = preload("res://scripts/core/stats.gd")
const PD_SCRIPT = preload("res://scripts/player_data.gd")
const WIDTH := 240.0

var is_open := false        # full panel showing (vs. the small button)
var _pending := {}          # stat -> points planned here (not applied yet)

var _panel: PanelContainer
var _pill: Button
var _points_label: Label
var _rows := {}             # stat -> {"value", "minus", "plus", "gain"}
var _apply: Button

func _ready() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	var bus := get_node_or_null("/root/SignalBus")
	if bus:
		bus.level_up.connect(func(_lv): _expand.call_deferred())
	var pd := _pd()
	if pd:
		pd.changed.connect(_refresh)
	_refresh.call_deferred()

func _pd() -> Node:
	return get_node_or_null("/root/PlayerData")

func _in_game() -> bool:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null or int(gm.state) != 1:   # 1 = PLAYING
		return false
	return get_tree().get_first_node_in_group("player") != null

func _process(_delta: float) -> void:
	# Only in a dungeon, and only while there are points to spend.
	var pd := _pd()
	var has_points: bool = pd != null and pd.attribute_points_left() > 0
	var show := has_points and _in_game()
	_panel.visible = show and is_open
	_pill.visible = show and not is_open
	if not show:
		_pending.clear()

func _expand() -> void:
	is_open = true
	_refresh()

func _collapse() -> void:
	is_open = false
	_pending.clear()
	_refresh()

func _left() -> int:
	var n := 0
	for s in _pending:
		n += int(_pending[s])
	return _pd().attribute_points_left() - n

func _change(stat: String, d: int) -> void:
	if d > 0 and _left() <= 0:
		return
	var v := int(_pending.get(stat, 0)) + d
	if v < 0:
		return
	_pending[stat] = v
	_refresh()

func _commit() -> void:
	var pd := _pd()
	var parts := []
	var planned := _pending.duplicate()
	_pending.clear()
	for s in planned:
		if int(planned[s]) > 0:
			pd.add_attribute_point(s, int(planned[s]))
			parts.append("+%d %s" % [int(planned[s]), Stats.label(s)])
	var gl := get_node_or_null("/root/GameLog")
	if gl and not parts.is_empty():
		gl.event("Attributes: %s" % ", ".join(parts), Color(0.8, 0.6, 1.0))
	if pd.attribute_points_left() <= 0:
		is_open = false   # all spent: the panel goes away
	_refresh()

# --- UI ------------------------------------------------------------------------------

func _refresh() -> void:
	var pd := _pd()
	if pd == null or _points_label == null:
		return
	var left := _left()
	_points_label.text = "Points to spend: %d" % left
	_pill.text = "+%d attribute point%s" % [pd.attribute_points_left(), "" if pd.attribute_points_left() == 1 else "s"]
	var any := false
	for s in _rows:
		var r: Dictionary = _rows[s]
		var add := int(_pending.get(s, 0))
		any = any or add > 0
		(r["value"] as Label).text = str(pd.attribute_rank(s)) + ("  +%d" % add if add > 0 else "")
		(r["value"] as Label).add_theme_color_override("font_color", Color(0.5, 1.0, 0.5) if add > 0 else Color.WHITE)
		(r["minus"] as Button).disabled = add <= 0
		(r["plus"] as Button).disabled = left <= 0
		(r["gain"] as Label).text = "%s per point" % Stats.bonus_line(s, float(pd.ATTRIBUTE_VALUES[s]))
	_apply.disabled = not any

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE   # never blocks clicks on the game
	add_child(root)
	var settings := get_node_or_null("/root/Settings")
	if settings:
		settings.register_hud(root)   # follows Settings > Interface > HUD opacity

	# Right edge, below the minimap.
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -WIDTH - 16
	_panel.offset_right = -16
	_panel.offset_top = 224
	var sb := UI.box(UI.PANEL_BG, UI.ACCENT.darkened(0.2), 2, 8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	_panel.add_child(v)
	var head := HBoxContainer.new()
	var title := UI.label("Level Up!", 16, UI.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var later := UI.button("Later", 12, Vector2(54, 24))
	later.tooltip_text = "Keep the points for later"
	later.pressed.connect(_collapse)
	head.add_child(later)
	v.add_child(head)
	_points_label = UI.label("", 13, Color.WHITE)
	v.add_child(_points_label)

	for s in PD_SCRIPT.ATTRIBUTE_ORDER:
		v.add_child(_make_row(s))

	_apply = UI.button("Apply", 14, Vector2(0, 30))
	_apply.pressed.connect(_commit)
	v.add_child(_apply)
	var hint := UI.label("Change them freely in the main menu (Character).", 10, UI.TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(WIDTH - 24, 0)
	v.add_child(hint)

	# Collapsed: a small button that reopens the panel.
	_pill = UI.button("", 13, Vector2(0, 30))
	_pill.anchor_left = 1.0
	_pill.anchor_right = 1.0
	_pill.offset_left = -WIDTH - 16
	_pill.offset_right = -16
	_pill.offset_top = 224
	_pill.offset_bottom = 254
	_pill.add_theme_color_override("font_color", UI.ACCENT)
	_pill.pressed.connect(_expand)
	root.add_child(_pill)
	_panel.visible = false
	_pill.visible = false

func _make_row(stat: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", -2)
	names.add_child(UI.label(Stats.label(stat).replace("Max ", ""), 14, Color.WHITE))
	var gain := UI.label("", 10, UI.TEXT_DIM)
	names.add_child(gain)
	row.add_child(names)
	var minus := UI.button("-", 14, Vector2(26, 26))
	minus.pressed.connect(_change.bind(stat, -1))
	row.add_child(minus)
	var value := UI.label("0", 14, Color.WHITE)
	value.custom_minimum_size = Vector2(44, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)
	var plus := UI.button("+", 14, Vector2(26, 26))
	plus.pressed.connect(_change.bind(stat, 1))
	row.add_child(plus)
	_rows[stat] = {"value": value, "minus": minus, "plus": plus, "gain": gain}
	return row
