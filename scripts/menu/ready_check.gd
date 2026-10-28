extends "res://scripts/menu/menu_part.gd"
class_name ReadyCheckPart

# The ready check in the lobby (rules: Net "Ready check"): the leader's Ready Check
# button, the "Ready?" popup with its countdown, and the tick / cross / "…" badge on
# every party card and next to your name while a check runs and a few seconds after.

const READY_COL := Color(0.45, 0.95, 0.5)
const NOT_READY_COL := Color(1.0, 0.4, 0.35)
const WAITING_COL := Color(0.9, 0.85, 0.6)

var check_button: Button
var _popup: PanelContainer
var _popup_title: Label
var _popup_bar: ProgressBar
var _popup_buttons: HBoxContainer
var _you_badge: Label

func _net() -> Node:
	return menu.get_node("/root/Net")

func build() -> void:
	check_button = UI.button("Ready Check", 18, Vector2(0, 0))
	check_button.tooltip_text = "Ask your party if everyone is ready.\nEntering or queueing with a party always asks first."
	check_button.anchor_left = 1.0
	check_button.anchor_right = 1.0
	check_button.anchor_top = 1.0
	check_button.anchor_bottom = 1.0
	check_button.offset_left = -580
	check_button.offset_right = -425
	check_button.offset_top = -100
	check_button.offset_bottom = -30
	check_button.pressed.connect(func(): _net().start_ready_check())
	menu.ui.add_child(check_button)

	_popup = PanelContainer.new()
	_popup.anchor_left = 0.5
	_popup.anchor_right = 0.5
	_popup.offset_left = -190
	_popup.offset_right = 190
	_popup.offset_top = 100
	_popup.add_theme_stylebox_override("panel", menu._padded(UI.box(Color(0.06, 0.065, 0.09, 0.97), MainMenu.C_ACCENT, 2, 10), 14))
	_popup.visible = false
	menu.ui.add_child(_popup)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_popup.add_child(v)
	_popup_title = UI.label("Ready check", 20, MainMenu.C_ACCENT)
	_popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_popup_title)
	_popup_bar = ProgressBar.new()
	_popup_bar.show_percentage = false
	_popup_bar.custom_minimum_size = Vector2(0, 8)
	_popup_bar.max_value = 1.0
	v.add_child(_popup_bar)
	_popup_buttons = HBoxContainer.new()
	_popup_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_popup_buttons.add_theme_constant_override("separation", 12)
	v.add_child(_popup_buttons)
	var yes := UI.button("Ready", 18, Vector2(140, 42))
	yes.add_theme_color_override("font_color", READY_COL)
	yes.pressed.connect(func(): _net().answer_ready_check(true))
	_popup_buttons.add_child(yes)
	var no := UI.button("Not ready", 18, Vector2(140, 42))
	no.add_theme_color_override("font_color", NOT_READY_COL)
	no.pressed.connect(func(): _net().answer_ready_check(false))
	_popup_buttons.add_child(no)

	_net().ready_check_changed.connect(refresh)
	refresh()

## A badge label for a party card / your name (top right of `parent`).
func make_badge(parent: Control) -> Label:
	var b := UI.label("", 22, READY_COL)
	b.name = "Ready"
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.offset_left = -30
	b.offset_right = -6
	b.offset_top = 4
	b.offset_bottom = 32
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.visible = false
	parent.add_child(b)
	return b

func set_you_badge(b: Label) -> void:
	_you_badge = b

## The answers to show: the running check's, else the last result's ({} = none).
func _answers() -> Dictionary:
	var net := _net()
	if not net.ready_check.is_empty():
		return net.ready_check["answers"]
	if not net.ready_result.is_empty():
		return net.ready_result["answers"]
	return {}

func _style_badge(b: Label, member: Variant) -> void:
	if b == null:
		return
	var net := _net()
	var answers := _answers()
	var active: bool = not net.ready_check.is_empty() or not net.ready_result.is_empty()
	b.visible = active and member != null
	if not b.visible:
		return
	if answers.has(member):
		var ok := bool(answers[member])
		b.text = "✔" if ok else "✖"
		b.add_theme_color_override("font_color", READY_COL if ok else NOT_READY_COL)
	else:
		b.text = "…" if not net.ready_check.is_empty() else "✖"
		b.add_theme_color_override("font_color", WAITING_COL if not net.ready_check.is_empty() else NOT_READY_COL)

func refresh() -> void:
	var net := _net()
	var me: int = net.my_id()
	for slot in menu.lobby_page._party_slots:
		_style_badge(slot.get_node_or_null("Ready"), slot.get_meta("member") if slot.has_meta("member") else null)
	_style_badge(_you_badge, me)
	if check_button:
		check_button.visible = menu.pages["Lobby"].visible and net.with_others() and net.is_host()
		check_button.disabled = not net.ready_check.is_empty()
	if _popup:
		_popup.visible = not net.ready_check.is_empty()
		if _popup.visible:
			var answered: bool = net.ready_check["answers"].has(me)
			_popup_buttons.visible = not answered
			_popup_title.text = "Waiting for your party…" if answered else "%s asks: are you ready?" % net.leader_name()
			_popup.move_to_front()
	if menu.queue_page._queue_enter:
		menu.queue_page._refresh_queue()

## Per frame: the countdown bar.
func update() -> void:
	if _popup == null or not _popup.visible:
		return
	var net := _net()
	if net.ready_check.is_empty():
		return
	_popup_bar.value = clampf(float(net.ready_check["left"]) / net.READY_CHECK_TIME, 0.0, 1.0)
