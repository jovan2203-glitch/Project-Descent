extends Node
class_name UIInstaller

# UI setup: opens the first time you enter a dungeon (Settings.ui_installed) and
# again from Settings > Interface > "Run UI setup". Steps: Welcome, Layout (Tank /
# Healer / Physical DPS / Caster DPS, each with a small picture of where things
# go), Interface size, Chat & meter, Done (with Move UI). Skip keeps what you have.

const NODE := "UIInstaller"
const STEPS := ["Welcome", "Layout", "Interface size", "Chat and meter", "Done"]
const ROLE_TIPS := {
	"tank": "Party frames on the left, a bigger health bar and debuffs: you watch yourself.",
	"healer": "Party frames in the middle above your bars, where your eyes already are.",
	"physical": "Unit frames beside the bars, cast bar under your frame.",
	"caster": "A wide cast bar right above your bars: you'll be watching it a lot.",
}
## Rough sizes for the layout pictures.
const PREVIEW_SIZES := {
	"action_bar": Vector2(274, 36), "extra_bar_1": Vector2(274, 36), "player_frame": Vector2(220, 40),
	"target_frame": Vector2(220, 52), "cast_bar": Vector2(220, 20), "party_frames": Vector2(160, 192),
	"buffs": Vector2(232, 60), "chat": Vector2(270, 174), "meter": Vector2(250, 228), "minimap": Vector2(150, 150),
	"xp_bar": Vector2(274, 8),
}

var win: UIWindow
var _step := 0
var _role := UIConfig.DEFAULT_ROLE
var _content: VBoxContainer
var _back: Button
var _next: Button
var _step_label: Label

static func open(tree: SceneTree) -> void:
	var w := UIWindow.make(tree, NODE, "UI Setup", Vector2(720, 470))
	if not w.is_new:
		return
	var inst := UIInstaller.new()
	inst.name = "Installer"
	inst.win = w
	inst._role = UIConfig.role()
	w.add_child(inst)
	inst._build()

## First time in a dungeon: open once.
static func open_if_new(tree: SceneTree) -> void:
	var s := UIConfig.settings()
	if s != null and not bool(s.ui_installed):
		open(tree)

func _build() -> void:
	_step_label = UISkin.label("", 12, UISkin.DIM)
	win.body.add_child(_step_label)
	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	win.body.add_child(_content)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	win.body.add_child(row)
	var skip := UIWindow.button("Skip")
	skip.tooltip_text = "Close setup and keep the UI as it is. Run it again from Settings > Interface."
	skip.pressed.connect(_finish)
	row.add_child(skip)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_back = UIWindow.button("Back", Vector2(90, 30))
	_back.pressed.connect(func(): _show(_step - 1))
	row.add_child(_back)
	_next = UIWindow.button("Next", Vector2(90, 30))
	_next.pressed.connect(func():
		if _step == STEPS.size() - 1:
			_finish()
		else:
			_show(_step + 1))
	row.add_child(_next)
	_show(0)

func _show(step: int) -> void:
	_step = clampi(step, 0, STEPS.size() - 1)
	_step_label.text = "Step %d of %d: %s" % [_step + 1, STEPS.size(), STEPS[_step]]
	_back.disabled = _step == 0
	_next.text = "Finish" if _step == STEPS.size() - 1 else "Next"
	for c in _content.get_children():
		c.queue_free()
	match _step:
		0: _welcome()
		1: _layout()
		2: _scale()
		3: _panels()
		4: _done()

func _text(t: String, size := 14, col := UISkin.TEXT) -> Label:
	var l := UISkin.label(t, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(640, 0)
	_content.add_child(l)
	return l

func _welcome() -> void:
	_text("Set up your interface", 22, UISkin.accent())
	_text("A few quick choices: a layout for what you play, how big the interface is, and where the chat and damage meter go.")
	_text("Everything can be changed later: UI Options (Settings > Interface, or /ui in chat) has a page for every part, and Move UI lets you drag any of them.", 13, UISkin.DIM)

func _layout() -> void:
	_text("Pick a layout", 18, UISkin.accent())
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	_content.add_child(grid)
	var tip := _text(ROLE_TIPS[_role], 13, UISkin.DIM)
	var cards: Array = []
	for r in UIConfig.ROLES:
		var card := Button.new()
		card.toggle_mode = true
		card.focus_mode = Control.FOCUS_NONE
		card.custom_minimum_size = Vector2(158, 150)
		card.add_theme_stylebox_override("normal", UISkin.button_box())
		card.add_theme_stylebox_override("hover", UISkin.button_box("hover"))
		card.add_theme_stylebox_override("pressed", UISkin.button_box("active"))
		card.add_theme_stylebox_override("hover_pressed", UISkin.button_box("active"))
		card.button_pressed = r == _role
		var pic := LayoutPicture.new()
		pic.role = r
		pic.position = Vector2(6, 6)
		pic.size = Vector2(146, 100)
		card.add_child(pic)
		var name_l := UISkin.label(UIConfig.ROLE_NAMES[r], 14)
		name_l.position = Vector2(0, 114)
		name_l.size = Vector2(158, 24)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(name_l)
		var role_id: String = r
		card.pressed.connect(func():
			_role = role_id
			tip.text = ROLE_TIPS[role_id]
			for c in cards:
				c.set_pressed_no_signal(c == card))
		grid.add_child(card)
		cards.append(card)
	_text("Picking a layout puts every element in its place for it (anything you moved goes back).", 12, UISkin.DIM)

func _scale() -> void:
	_text("Interface size", 18, UISkin.accent())
	var s := UIConfig.settings()
	if s == null:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_content.add_child(row)
	var sl := HSlider.new()
	sl.focus_mode = Control.FOCUS_NONE
	sl.min_value = s.UI_SCALE_MIN
	sl.max_value = s.UI_SCALE_MAX
	sl.step = 0.05
	sl.value = s.ui_scale
	sl.custom_minimum_size = Vector2(320, 24)
	row.add_child(sl)
	var val := UISkin.label("%d%%" % int(round(s.ui_scale * 100)), 14)
	row.add_child(val)
	sl.value_changed.connect(func(x: float): val.text = "%d%%" % int(round(x * 100)))
	sl.drag_ended.connect(func(_c):
		s.ui_scale = sl.value
		s.apply_interface()
		s.save())
	_text("Scales every menu and the HUD. 100% suits 1080p; try 85-90% at 720p and 110-125% at 1440p or higher.", 13, UISkin.DIM)

func _panels() -> void:
	_text("Chat and damage meter", 18, UISkin.accent())
	var dock := CheckBox.new()
	dock.text = "Dock the damage meter in the bottom-right panel"
	dock.focus_mode = Control.FOCUS_NONE
	dock.button_pressed = bool(UIConfig.value("meter_panel", "docked"))
	dock.toggled.connect(func(on: bool): UIConfig.set_value("meter_panel", "docked", on))
	_content.add_child(dock)
	var strips := CheckBox.new()
	strips.text = "Info strips under the panels (time, bag space, FPS, DPS...)"
	strips.focus_mode = Control.FOCUS_NONE
	strips.button_pressed = bool(UIConfig.value("chat_panel", "info_strip"))
	strips.toggled.connect(func(on: bool):
		UIConfig.set_value("chat_panel", "info_strip", on)
		UIConfig.set_value("meter_panel", "info_strip", on))
	_content.add_child(strips)
	_text("The chat sits in the bottom-left panel with the menu buttons under it. Which info texts show is set in UI Options > Panels.", 13, UISkin.DIM)

func _done() -> void:
	_text("All set", 22, UISkin.accent())
	_text("Your layout: %s." % UIConfig.ROLE_NAMES[_role])
	var move := UIWindow.button("Move UI now")
	move.tooltip_text = "Finish and drag things where you want them."
	move.pressed.connect(func():
		_finish()
		var s := UIConfig.settings()
		if s:
			s.move_ui_requested.emit())
	_content.add_child(move)
	_text("Build your own aura bars, cooldown icons and alerts in Trackers (/trackers).", 13, UISkin.DIM)

func _finish() -> void:
	var s := UIConfig.settings()
	if s:
		if _role != UIConfig.role() or not bool(s.ui_installed):
			var keep_dock: Variant = UIConfig.profile().get("meter_panel", {}).duplicate()
			var keep_chat: Variant = UIConfig.profile().get("chat_panel", {}).duplicate()
			if _role != UIConfig.role():
				UIConfig.apply_role(_role)
				for k in keep_dock:
					UIConfig.set_value("meter_panel", k, keep_dock[k])
				for k in keep_chat:
					UIConfig.set_value("chat_panel", k, keep_chat[k])
		s.ui_installed = true
		s.save()
		var engine := TrackerEngine.of(get_tree())
		if engine:
			engine.ensure_defaults()
	win.queue_free()

## A small picture of a role layout: where the frames, bars and panels go.
class LayoutPicture extends Control:
	var role := "physical"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var screen := Vector2(1152, 648)
		var k := size.x / screen.x
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.03))
		draw_rect(Rect2(Vector2.ZERO, size), UISkin.INNER, false, 1.0)
		var colors := {"action_bar": Color(0.5, 0.5, 0.55), "extra_bar_1": Color(0.5, 0.5, 0.55),
			"player_frame": UISkin.HEALTH, "target_frame": UISkin.HOSTILE, "cast_bar": UISkin.CAST,
			"party_frames": Color(0.4, 0.85, 0.5), "chat": Color(0.3, 0.3, 0.35), "meter": Color(0.35, 0.3, 0.3),
			"minimap": Color(0.3, 0.35, 0.3), "buffs": Color(0.75, 0.75, 0.3), "xp_bar": Color(0.6, 0.35, 0.95)}
		for key in UIInstaller.PREVIEW_SIZES:
			if key == "extra_bar_1" and not bool(UIConfig.default_of("action_bar_2", "enabled", role)):
				continue
			var spot := UIConfig.preset_spot(key, role)
			if spot.is_empty():
				continue
			var sz: Vector2 = UIInstaller.PREVIEW_SIZES[key]
			if key == "party_frames" and str(UIConfig.default_of("party_frames", "grow", role)) == "right":
				var w := float(UIConfig.default_of("party_frames", "width", role))
				sz = Vector2(5 * (w + 4), float(UIConfig.default_of("party_frames", "height", role)))
			if key == "cast_bar":
				sz.x = float(UIConfig.default_of("cast_bar", "width", role))
			var pos := UILayout.position_for(spot, sz, screen)
			draw_rect(Rect2(pos * k, (sz * k).max(Vector2(2, 2))), colors.get(key, Color.GRAY))
