extends Node

# Player settings (autoload "Settings"). Saved to user://settings.cfg and applied
# at startup:
#   - Display: window mode, resolution, vsync, max FPS
#   - Audio:   Master / Music / SFX volume (audio buses)
#   - Controls: every game key is an Input Map action registered here with its
#     default keys; the Controls tab rebinds the primary key of each action.
# build_settings_ui() makes the tabbed controls used by both Settings panels.

const UI = preload("res://scripts/ui_kit.gd")
const PATH := "user://settings.cfg"

const WINDOW_MODES := ["Windowed", "Borderless Fullscreen", "Exclusive Fullscreen"]
const RESOLUTIONS := [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440)]
const FPS_OPTIONS := [30, 60, 120, 144, 0]   # 0 = unlimited

## Graphics quality presets (see apply_graphics()).
##   Low:    no dynamic shadows, no glow, no anti-aliasing, small shadow atlas
##   Medium: shadows (soft, low), glow, FXAA
##   High:   shadows (soft, medium), glow, MSAA 2x
const QUALITY_LEVELS := ["Low", "Medium", "High"]
## 3D render resolution relative to the window (UI always stays sharp).
const RENDER_SCALES := [0.5, 0.67, 0.77, 0.85, 1.0]

## Rebindable actions: [action, label, default keys (first = primary)].
const ACTIONS := [
	["move_forward", "Move Forward", [KEY_W, KEY_UP]],
	["move_back", "Move Back", [KEY_S, KEY_DOWN]],
	["move_left", "Move Left", [KEY_A, KEY_LEFT]],
	["move_right", "Move Right", [KEY_D, KEY_RIGHT]],
	["ability_1", "Action Bar 1", [KEY_1]],
	["ability_2", "Action Bar 2", [KEY_2]],
	["ability_3", "Action Bar 3", [KEY_3]],
	["ability_4", "Action Bar 4", [KEY_4]],
	["ability_5", "Action Bar 5", [KEY_5]],
	["ability_6", "Action Bar 6", [KEY_6]],
	["ability_7", "Action Bar 7", [KEY_7]],
	["ability_8", "Action Bar 8", [KEY_8]],
	["target_next", "Target Nearest Enemy", [KEY_TAB]],
	["zoom_in", "Zoom In", [KEY_EQUAL, KEY_KP_ADD]],
	["zoom_out", "Zoom Out", [KEY_MINUS, KEY_KP_SUBTRACT]],
	["restart", "Restart (when dead)", [KEY_R]],
	["chat", "Open Chat", [KEY_ENTER]],
	["open_character", "Character", [KEY_C]],
	["open_inventory", "Inventory", [KEY_I]],
	["open_bank", "Bank", [KEY_B]],
	["open_talents", "Talents & Abilities", [KEY_P]],
	["open_map", "Map", [KEY_M]],
	["debug_overlay", "FPS / Stats Overlay", [KEY_F3]],
]
const AUDIO_BUSES := ["Master", "Music", "SFX"]

var window_mode := 0
var resolution := 0
var vsync := true
var max_fps := 1   # index into FPS_OPTIONS (60)
var quality := 1        # index into QUALITY_LEVELS (Medium)
var render_scale := 4   # index into RENDER_SCALES (100%)
var volumes := {"Master": 0.8, "Music": 0.6, "SFX": 0.8}
var keybinds := {}   # action -> primary keycode (only changed ones)
var chat_size := Vector2(400, 200)   # in-game chat box size (resize grip)

# --- Interface -----------------------------------------------------------------------
const UI_SCALE_MIN := 0.75
const UI_SCALE_MAX := 1.5
const UI_OPACITY_MIN := 0.3
const HUD_GROUP := "hud_fade"
var ui_scale := 1.0     # whole UI (menus, HUD, windows)
var ui_opacity := 1.0   # in-game HUD only (Esc menu / Settings / map stay solid)
signal interface_changed

func apply_interface() -> void:
	get_tree().root.content_scale_factor = ui_scale
	for n in get_tree().get_nodes_in_group(HUD_GROUP):
		if n is CanvasItem:
			n.modulate.a = ui_opacity
	interface_changed.emit()

## HUD pieces call this so the Opacity slider fades them.
func register_hud(item: CanvasItem) -> void:
	if not item.is_in_group(HUD_GROUP):
		item.add_to_group(HUD_GROUP)
	item.modulate.a = ui_opacity

func build_interface_ui() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	# Size: applied when you let go (the slider would jump away under the mouse otherwise).
	var size_s := _slider(UI_SCALE_MIN, UI_SCALE_MAX, 0.05, ui_scale)
	var size_l := UI.label("%d%%" % int(round(ui_scale * 100)), 14, Color.WHITE)
	size_s.value_changed.connect(func(val): size_l.text = "%d%%" % int(round(val * 100)))
	size_s.drag_ended.connect(func(_changed):
		ui_scale = size_s.value
		apply_interface()
		save())
	_row(grid, "Interface size", size_s)
	grid.add_child(size_l)
	var op_s := _slider(UI_OPACITY_MIN, 1.0, 0.05, ui_opacity)
	var op_l := UI.label("%d%%" % int(round(ui_opacity * 100)), 14, Color.WHITE)
	op_s.value_changed.connect(func(val):
		ui_opacity = val
		op_l.text = "%d%%" % int(round(val * 100))
		apply_interface())
	op_s.drag_ended.connect(func(_changed): save())
	_row(grid, "HUD opacity", op_s)
	grid.add_child(op_l)
	var reset := UI.button("Reset interface", 14, Vector2(0, 30))
	reset.pressed.connect(func():
		ui_scale = 1.0
		ui_opacity = 1.0
		size_s.set_value_no_signal(1.0)
		size_l.text = "100%"
		op_s.set_value_no_signal(1.0)
		op_l.text = "100%"
		apply_interface()
		save())
	v.add_child(reset)
	var note := UI.label("Size scales every menu and the HUD. Opacity fades the in-game HUD: bars, action bar, chat, minimap and windows.", 12, UI.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	return v

func _slider(mn: float, mx: float, step: float, value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = value
	s.focus_mode = Control.FOCUS_NONE
	s.custom_minimum_size = Vector2(200, 24)
	return s

signal keybinds_changed
signal graphics_changed

func _ready() -> void:
	_register_actions()
	_load()
	apply()
	apply_audio()
	_apply_keybinds()
	apply_interface.call_deferred()
	# Lights / environments in every scene loaded later follow the quality preset.
	get_tree().node_added.connect(_on_node_added)
	apply_graphics()

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		_detect_defaults()
		return
	window_mode = clampi(int(cfg.get_value("display", "window_mode", window_mode)), 0, WINDOW_MODES.size() - 1)
	resolution = clampi(int(cfg.get_value("display", "resolution", resolution)), 0, RESOLUTIONS.size() - 1)
	vsync = bool(cfg.get_value("display", "vsync", vsync))
	max_fps = clampi(int(cfg.get_value("display", "max_fps", max_fps)), 0, FPS_OPTIONS.size() - 1)
	if cfg.has_section_key("graphics", "quality"):
		quality = clampi(int(cfg.get_value("graphics", "quality")), 0, QUALITY_LEVELS.size() - 1)
		render_scale = clampi(int(cfg.get_value("graphics", "render_scale", render_scale)), 0, RENDER_SCALES.size() - 1)
	else:
		_detect_defaults()   # settings file from before graphics options existed
	for bus in AUDIO_BUSES:
		volumes[bus] = clampf(float(cfg.get_value("audio", bus, volumes[bus])), 0.0, 1.0)
	ui_scale = clampf(float(cfg.get_value("ui", "scale", ui_scale)), UI_SCALE_MIN, UI_SCALE_MAX)
	ui_opacity = clampf(float(cfg.get_value("ui", "opacity", ui_opacity)), UI_OPACITY_MIN, 1.0)
	var cs: Variant = cfg.get_value("ui", "chat_size", chat_size)
	if cs is Vector2:
		chat_size = cs
	if cfg.has_section("keybinds"):
		for action in cfg.get_section_keys("keybinds"):
			if InputMap.has_action(action):
				keybinds[action] = int(cfg.get_value("keybinds", action))

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "window_mode", window_mode)
	cfg.set_value("display", "resolution", resolution)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("display", "max_fps", max_fps)
	cfg.set_value("graphics", "quality", quality)
	cfg.set_value("graphics", "render_scale", render_scale)
	for bus in AUDIO_BUSES:
		cfg.set_value("audio", bus, volumes[bus])
	for action in keybinds:
		cfg.set_value("keybinds", action, keybinds[action])
	cfg.set_value("ui", "chat_size", chat_size)
	cfg.set_value("ui", "scale", ui_scale)
	cfg.set_value("ui", "opacity", ui_opacity)
	cfg.save(PATH)

func apply() -> void:
	var win := get_window()
	# Running inside the editor's Game tab: the editor owns that window and
	# ignores mode / size requests (works normally in its own window or a build).
	if window_controls_available():
		match window_mode:
			0:
				win.mode = Window.MODE_WINDOWED
				win.borderless = false
				_apply_window_size()
			1:
				win.borderless = false
				win.mode = Window.MODE_FULLSCREEN            # borderless fullscreen
			2:
				win.borderless = false
				win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = FPS_OPTIONS[max_fps]

## False while the game runs embedded in the editor, where the window can't be
## resized or made fullscreen from code.
func window_controls_available() -> bool:
	return not Engine.is_embedded_in_editor()

var _resize_serial := 0

# Leaving fullscreen takes the OS a frame or two; a resize sent in the same
# frame is dropped (that's why changing resolution after fullscreen did nothing).
func _apply_window_size() -> void:
	_resize_serial += 1
	var serial := _resize_serial
	for i in 2:
		await get_tree().process_frame
	if serial != _resize_serial or window_mode != 0:
		return   # a newer change superseded this one
	var win := get_window()
	if win.mode != Window.MODE_WINDOWED:
		win.mode = Window.MODE_WINDOWED
	var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
	var size: Vector2i = RESOLUTIONS[resolution]
	size = size.min(usable.size)   # never bigger than the screen
	win.size = size
	# Keep the window centered on its screen.
	win.position = usable.position + (usable.size - size) / 2

func _changed() -> void:
	apply()
	save()

# --- Graphics ------------------------------------------------------------------------

## First launch: pick a preset that suits this machine. Integrated GPUs and
## the OpenGL fallback renderer (old / unsupported GPUs) start on Low.
func _detect_defaults() -> void:
	var weak := RenderingServer.get_current_rendering_method() == "gl_compatibility" \
		or RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU
	quality = 0 if weak else 1
	render_scale = RENDER_SCALES.size() - 1

func _supports_fsr() -> bool:
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"

## Viewport-wide settings, then every light / environment already in the tree.
func apply_graphics() -> void:
	var vp := get_tree().root
	var s: float = RENDER_SCALES[render_scale]
	vp.scaling_3d_scale = s
	# FSR 1 upscaling looks much better than bilinear below 100%.
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if (s < 1.0 and _supports_fsr()) \
		else Viewport.SCALING_3D_MODE_BILINEAR
	match quality:
		0:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.positional_shadow_atlas_size = 1024
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		1:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.positional_shadow_atlas_size = 2048
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		_:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.positional_shadow_atlas_size = 4096
			RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	_apply_graphics_tree(vp)
	graphics_changed.emit()

func _apply_graphics_tree(n: Node) -> void:
	_apply_graphics_node(n)
	for c in n.get_children():
		_apply_graphics_tree(c)

func _on_node_added(n: Node) -> void:
	if n is Light3D or n is WorldEnvironment:
		_apply_graphics_node(n)

## Low turns off light shadows and glow. The scene's own values are
## remembered (as metadata) so Medium / High restore exactly what was designed.
func _apply_graphics_node(n: Node) -> void:
	if n is Light3D:
		if not n.has_meta("gfx_shadow"):
			n.set_meta("gfx_shadow", n.shadow_enabled)
		n.shadow_enabled = bool(n.get_meta("gfx_shadow")) and quality > 0
	elif n is WorldEnvironment and n.environment:
		var env: Environment = n.environment
		if not env.has_meta("gfx_glow"):
			env.set_meta("gfx_glow", env.glow_enabled)
		env.glow_enabled = bool(env.get_meta("gfx_glow")) and quality > 0

func _graphics_changed() -> void:
	apply_graphics()
	save()

# --- Audio -------------------------------------------------------------------------

## Make sure the Music / SFX buses exist (routed into Master).
static func ensure_buses() -> void:
	for bus in AUDIO_BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")

func apply_audio() -> void:
	ensure_buses()
	for bus in AUDIO_BUSES:
		var idx := AudioServer.get_bus_index(bus)
		var v := float(volumes[bus])
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(idx, v <= 0.001)

# --- Controls (Input Map) ------------------------------------------------------------

func _register_actions() -> void:
	for a in ACTIONS:
		var action: String = a[0]
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		for key in a[2]:
			InputMap.action_add_event(action, _key_event(key))

func _key_event(keycode: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	return ev

func _apply_keybinds() -> void:
	for action in keybinds:
		_set_primary(action, int(keybinds[action]))

func _set_primary(action: String, keycode: int) -> void:
	var events := InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, _key_event(keycode))
	for i in range(1, events.size()):
		if not (events[i] is InputEventKey and events[i].keycode == keycode):
			InputMap.action_add_event(action, events[i])

func primary_key(action: String) -> int:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return ev.keycode
	return 0

## Short text for the key bound to `action` ("1", "Tab", "F3").
func key_text(action: String) -> String:
	var k := primary_key(action)
	return OS.get_keycode_string(k) if k != 0 else "—"

## Bind `keycode` as the primary key of `action`. If another action already uses
## it as its primary key, the two swap keys.
func rebind(action: String, keycode: int) -> void:
	var old := primary_key(action)
	for a in ACTIONS:
		var other: String = a[0]
		if other != action and primary_key(other) == keycode:
			_set_primary(other, old)
			keybinds[other] = old
	_set_primary(action, keycode)
	keybinds[action] = keycode
	save()
	keybinds_changed.emit()

func reset_keybinds() -> void:
	keybinds.clear()
	_register_actions()
	save()
	keybinds_changed.emit()

var _capture_action := ""
var _capture_button: Button

func _input(event: InputEvent) -> void:
	if _capture_action == "" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var action := _capture_action
	_capture_action = ""
	if event.keycode != KEY_ESCAPE:
		rebind(action, event.keycode)
	if is_instance_valid(_capture_button):
		_capture_button.text = key_text(action)

# --- UI --------------------------------------------------------------------------

## Tabbed settings (Display / Audio / Controls) for the Esc-menu Settings panels.
func build_settings_ui() -> Control:
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(440, 340)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var d := build_display_ui()
	d.name = "Display"
	tabs.add_child(d)
	var a := build_audio_ui()
	a.name = "Audio"
	tabs.add_child(a)
	var c := build_controls_ui()
	c.name = "Controls"
	tabs.add_child(c)
	var ui_tab := build_interface_ui()
	ui_tab.name = "Interface"
	tabs.add_child(ui_tab)
	return tabs

func build_audio_ui() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	v.add_child(grid)
	for bus in AUDIO_BUSES:
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = volumes[bus]
		s.focus_mode = Control.FOCUS_NONE
		s.custom_minimum_size = Vector2(200, 24)
		var pct := UI.label("%d%%" % int(volumes[bus] * 100), 14, Color.WHITE)
		s.value_changed.connect(func(val):
			volumes[bus] = val
			pct.text = "%d%%" % int(val * 100)
			apply_audio()
			save())
		_row(grid, bus if bus != "SFX" else "Sound Effects", s)
		grid.add_child(pct)
	var note := UI.label("Sounds play from res://audio/ once files are added.", 12, UI.TEXT_DIM)
	v.add_child(note)
	return v

func build_controls_ui() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(UI.label("Click a key, then press the new key (Esc cancels).", 12, UI.TEXT_DIM))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 230)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	var buttons := {}
	for a in ACTIONS:
		var action: String = a[0]
		var b := UI.button(key_text(action), 14, Vector2(120, 28))
		b.pressed.connect(func():
			_capture_action = action
			_capture_button = b
			b.text = "Press a key…")
		buttons[action] = b
		var l := UI.label(a[1], 14, Color.WHITE)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
		grid.add_child(b)
	var refresh := func():
		for action in buttons:
			if is_instance_valid(buttons[action]):
				buttons[action].text = key_text(action)
	keybinds_changed.connect(refresh)
	v.tree_exiting.connect(func():
		if keybinds_changed.is_connected(refresh):
			keybinds_changed.disconnect(refresh))
	var reset := UI.button("Reset to defaults", 14, Vector2(0, 30))
	reset.pressed.connect(reset_keybinds)
	v.add_child(reset)
	return v

# Controls for a Settings panel. Changes apply immediately and are saved.
func build_display_ui() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)

	var mode_opt := _option(WINDOW_MODES, window_mode)
	var res_labels: Array = []
	for r in RESOLUTIONS:
		res_labels.append("%d x %d" % [r.x, r.y])
	var res_opt := _option(res_labels, resolution)
	res_opt.disabled = window_mode != 0
	mode_opt.item_selected.connect(func(i):
		window_mode = i
		res_opt.disabled = i != 0
		_changed())
	res_opt.item_selected.connect(func(i):
		resolution = i
		_changed())
	_row(grid, "Window mode", mode_opt)
	_row(grid, "Resolution", res_opt)

	var vs := CheckButton.new()
	vs.focus_mode = Control.FOCUS_NONE
	vs.button_pressed = vsync
	vs.toggled.connect(func(on):
		vsync = on
		_changed())
	_row(grid, "VSync", vs)

	var fps_labels: Array = []
	for f in FPS_OPTIONS:
		fps_labels.append("Unlimited" if f == 0 else str(f))
	var fps_opt := _option(fps_labels, max_fps)
	fps_opt.item_selected.connect(func(i):
		max_fps = i
		_changed())
	_row(grid, "Max FPS", fps_opt)

	var q_opt := _option(QUALITY_LEVELS, quality)
	q_opt.item_selected.connect(func(i):
		quality = i
		_graphics_changed())
	_row(grid, "Graphics quality", q_opt)

	var scale_labels: Array = []
	for rs in RENDER_SCALES:
		scale_labels.append("%d%%" % int(round(rs * 100.0)))
	var scale_opt := _option(scale_labels, render_scale)
	scale_opt.item_selected.connect(func(i):
		render_scale = i
		_graphics_changed())
	_row(grid, "Render scale", scale_opt)

	var note := UI.label("Resolution applies in Windowed mode. Lower quality or render scale for more FPS.", 12, UI.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	if not window_controls_available():
		mode_opt.disabled = true
		res_opt.disabled = true
		var warn := UI.label("Window mode and resolution can't change while the game runs inside the editor's Game tab. Turn off \"Embed Game on Next Play\" there, or run an exported build.", 12, Color(1.0, 0.75, 0.35))
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(warn)
	return v

func _option(labels: Array, selected: int) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.custom_minimum_size = Vector2(190, 32)
	for l in labels:
		o.add_item(str(l))
	o.select(selected)
	return o

func _row(grid: GridContainer, text: String, control: Control) -> void:
	var l := UI.label(text, 14, Color.WHITE)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(l)
	grid.add_child(control)
