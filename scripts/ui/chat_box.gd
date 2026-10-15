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
var _grip: Control
var _collapse_btn: Button
## Collapsed = only the tab header shows (shared by the game and the main menu,
## kept while the game runs). New chat lines mark the Chat tab with a dot.
static var collapsed := false
var _unread := false
const COLLAPSED_HEIGHT := 30.0

func _ready() -> void:
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 16
	_fit_width()
	get_viewport().size_changed.connect(_fit_width)
	if is_instance_valid(avoid_above):
		avoid_above.item_rect_changed.connect(_fit_width)
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
	_collapse_btn = UI.button("–", 12, Vector2(22, 22))
	_collapse_btn.tooltip_text = "Hide / show the chat"
	_collapse_btn.focus_mode = Control.FOCUS_NONE
	_collapse_btn.pressed.connect(func(): _set_collapsed(not collapsed))
	header.add_child(_collapse_btn)
	_grip = _make_grip()
	header.add_child(_grip)

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

	_current = "Chat"
	_tabs["Chat"].set_pressed_no_signal(true)
	var was_collapsed := collapsed
	collapsed = false
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
	_set_collapsed(was_collapsed)   # keep it hidden if it was hidden in the last scene

## Size comes from Settings.chat_size (dragged with the grip in the top-right
## corner), limited so it never reaches under the centered action bar or the
## health / resource bars at the top.
const ACTION_BAR_HALF := 237.0 + 8.0
const MIN_SIZE := Vector2(220, 90)
const BOTTOM_GAP := 70.0
## Where the box sits: gap under it, and an optional height cap (the main menu
## sets these before adding the box so it fits under the party cards).
var bottom_gap := BOTTOM_GAP
var max_height := -1.0
## Main menu: never reach above this control's bottom edge (the party cards),
## and always use all the height between it and the bottom gap.
var avoid_above: Control
var fill_height := false

func _max_size() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	var h := maxf(vp.y - bottom_gap - 190.0, MIN_SIZE.y)
	if max_height > 0.0:
		h = maxf(minf(h, max_height), MIN_SIZE.y)
	if is_instance_valid(avoid_above) and avoid_above.is_inside_tree():
		h = maxf(minf(h, vp.y - bottom_gap - avoid_above.get_global_rect().end.y - 10.0), MIN_SIZE.y)
	return Vector2(maxf(vp.x * 0.5 - ACTION_BAR_HALF - 16.0, MIN_SIZE.x), h)

func _fit_width() -> void:
	var s: Vector2 = get_node("/root/Settings").chat_size
	s = s.clamp(MIN_SIZE, _max_size())
	if fill_height:
		s.y = _max_size().y
	offset_right = 16 + s.x
	offset_top = -bottom_gap - (COLLAPSED_HEIGHT if collapsed else s.y)
	offset_bottom = -bottom_gap

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
		_views[t].visible = t == tab and not collapsed
	_tabs[tab].set_pressed_no_signal(true)
	if collapsed:
		_set_collapsed(false)   # clicking a tab opens the chat back up

func _set_collapsed(c: bool) -> void:
	collapsed = c
	for t in _views:
		_views[t].visible = t == _current and not c
	_entry.visible = not c
	_grip.visible = not c
	_collapse_btn.text = "+" if c else "–"
	if not c:
		_unread = false
	_tabs["Chat"].text = "Chat •" if _unread else "Chat"
	_fit_width()

func _append(tab: String, bbcode: String) -> void:
	var rt: RichTextLabel = _views[tab]
	rt.append_text(bbcode + "\n")
	while rt.get_paragraph_count() > MAX_LINES:
		rt.remove_paragraph(0)
	if collapsed and tab == "Chat" and not _unread:
		_unread = true
		_tabs["Chat"].text = "Chat •"

func _system(text: String) -> void:
	_append("Chat", "[color=#e6c068]%s[/color]" % _esc(text))

func _esc(t: String) -> String:
	return t.replace("[", "[lb]")

# --- Input -------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("chat") and not _entry.has_focus() and is_visible_in_tree():
		get_viewport().set_input_as_handled()
		if collapsed:
			_set_collapsed(false)
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
