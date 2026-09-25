extends PanelContainer

# Local chat box (bottom-left, above the menu bar) with two tabs:
#   Chat — your own messages (local only for now) + system replies
#   Logs — everything that happens in the game, from GameLog's event feed
#          ("Player cast Frost Bolt", "Zombie took 1 damage", ...)
# Enter (rebindable "chat" action) opens the input; Enter sends, Esc closes.
# Lines starting with "/" are debug commands (see debug_commands.gd, /help).

const UI = preload("res://scripts/ui_kit.gd")
const DebugCommands = preload("res://scripts/core/debug_commands.gd")
const MAX_LINES := 200
const WIDTH := 400.0
const HEIGHT := 200.0

var _tabs := {}          # "Chat"/"Logs" -> Button
var _views := {}         # "Chat"/"Logs" -> RichTextLabel
var _entry: LineEdit
var _current := "Chat"

func _ready() -> void:
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 16
	_fit_width()
	get_viewport().size_changed.connect(_fit_width)
	var sb := UI.box(Color(0, 0, 0, 0.45), Color(0.3, 0.3, 0.32, 0.6), 1, 6)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6
	add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	v.add_child(header)
	var group := ButtonGroup.new()
	for tab in ["Chat", "Logs"]:
		var b := UI.button(tab, 12, Vector2(56, 22))
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(_show_tab.bind(tab))
		header.add_child(b)
		_tabs[tab] = b
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(_make_grip())

	for tab in ["Chat", "Logs"]:
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.scroll_following = true
		rt.selection_enabled = true
		# Never keyboard focus: a focused chat log turned S (ui_down) into
		# "move focus to the chat input" and blocked walking backwards.
		rt.focus_mode = Control.FOCUS_NONE
		rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
		rt.add_theme_font_size_override("normal_font_size", 12)
		rt.add_theme_color_override("default_color", Color(0.9, 0.9, 0.92))
		rt.add_theme_constant_override("outline_size", 3)
		rt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		v.add_child(rt)
		_views[tab] = rt

	_entry = LineEdit.new()
	_entry.placeholder_text = "Press Enter to chat  •  /help for commands"
	_entry.add_theme_font_size_override("font_size", 12)
	_entry.custom_minimum_size = Vector2(0, 24)
	_entry.add_theme_stylebox_override("normal", UI.box(Color(0, 0, 0, 0.35), Color(0.3, 0.3, 0.32, 0.5), 1, 4))
	_entry.add_theme_stylebox_override("focus", UI.box(Color(0, 0, 0, 0.6), UI.ACCENT.darkened(0.2), 1, 4))
	_entry.text_submitted.connect(_on_submit)
	v.add_child(_entry)

	_show_tab("Chat")
	_system("Welcome! Type /help for debug commands.")

	# Party chat + party/leader messages.
	var net := get_node_or_null("/root/Net")
	if net:
		net.chat_received.connect(func(sender, msg):
			_append("Chat", "[color=#8fd18f][%s]:[/color] %s" % [_esc(sender), _esc(msg)]))
		net.system_message.connect(_system)
		if net.with_others():
			_system("Party: %s" % ", ".join(net.order.map(func(id): return net.member_name(id))))
	var online := get_node_or_null("/root/Online")
	if online:
		online.toast.connect(_system)

	# Logs tab: history so far + live feed.
	var gl := get_node_or_null("/root/GameLog")
	if gl:
		for e in gl.events:
			_append("Logs", "[color=#%s]%s[/color]" % [Color(e["color"]).to_html(false), _esc(e["text"])])
		gl.event_logged.connect(func(text, color):
			_append("Logs", "[color=#%s]%s[/color]" % [color.to_html(false), _esc(text)]))

## Size comes from Settings.chat_size (dragged with the grip in the top-right
## corner), limited so it never reaches under the centered action bar or the
## health / resource bars at the top.
const ACTION_BAR_HALF := 237.0 + 8.0
const MIN_SIZE := Vector2(220, 90)
const BOTTOM_GAP := 70.0

func _max_size() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return Vector2(maxf(vp.x * 0.5 - ACTION_BAR_HALF - 16.0, MIN_SIZE.x),
		maxf(vp.y - BOTTOM_GAP - 190.0, MIN_SIZE.y))

func _fit_width() -> void:
	var s: Vector2 = get_node("/root/Settings").chat_size
	s = s.clamp(MIN_SIZE, _max_size())
	offset_right = 16 + s.x
	offset_top = -BOTTOM_GAP - s.y
	offset_bottom = -BOTTOM_GAP

# --- Resize grip ---------------------------------------------------------------------

var _dragging := false

func _make_grip() -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(18, 18)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	g.mouse_default_cursor_shape = Control.CURSOR_BDIAGSIZE
	g.tooltip_text = "Drag to resize the chat"
	g.draw.connect(func():
		var c := Color(0.7, 0.7, 0.75, 0.7)
		for i in 3:
			var o := 4.0 + i * 4.0
			g.draw_line(Vector2(g.size.x - o, 2), Vector2(g.size.x - 2, o), c, 1.5, true))
	g.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			_dragging = ev.pressed
			if not ev.pressed:
				get_node("/root/Settings").save()
			g.accept_event()
		elif ev is InputEventMouseMotion and _dragging:
			var st := get_node("/root/Settings")
			var s: Vector2 = st.chat_size.clamp(MIN_SIZE, _max_size())
			st.chat_size = (s + Vector2(ev.relative.x, -ev.relative.y)).clamp(MIN_SIZE, _max_size())
			_fit_width()
			g.accept_event())
	return g

func _show_tab(tab: String) -> void:
	_current = tab
	for t in _views:
		_views[t].visible = t == tab
	_tabs[tab].set_pressed_no_signal(true)

func _append(tab: String, bbcode: String) -> void:
	var rt: RichTextLabel = _views[tab]
	rt.append_text(bbcode + "\n")
	while rt.get_paragraph_count() > MAX_LINES:
		rt.remove_paragraph(0)

func _system(text: String) -> void:
	_append("Chat", "[color=#e6c068]%s[/color]" % _esc(text))

func _esc(t: String) -> String:
	return t.replace("[", "[lb]")

# --- Input -------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("chat") and not _entry.has_focus():
		get_viewport().set_input_as_handled()
		_entry.grab_focus()

## Runs before any GUI: Esc always leaves the chat (without opening the Esc
## menu), and clicking anywhere outside the chat box gives the keyboard back
## to the game.
func _input(event: InputEvent) -> void:
	if not _chat_has_focus():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_leave_chat()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed \
			and not get_global_rect().has_point(event.position):
		_leave_chat()

func _chat_has_focus() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f != null and (f == self or is_ancestor_of(f))

func _leave_chat() -> void:
	_entry.clear()
	var f := get_viewport().gui_get_focus_owner()
	if f:
		f.release_focus()

func _on_submit(text: String) -> void:
	text = text.strip_edges()
	_entry.clear()
	_entry.release_focus()
	if text == "":
		return
	if text.begins_with("/"):
		_show_tab("Chat")
		_append("Chat", "[color=#8fa8c8]> %s[/color]" % _esc(text))
		for line in DebugCommands.run(get_tree(), text):
			_system(str(line))
		return
	_show_tab("Chat")
	_append("Chat", "[color=#9fd3ff][You]:[/color] %s" % _esc(text))
	var bus := get_node_or_null("/root/SignalBus")
	if bus:
		bus.chat_message.emit("You", text)
