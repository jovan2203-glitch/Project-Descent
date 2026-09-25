extends PanelContainer

# Main menu "Friends" panel: who you are, your party (leader marked), party
# invites you've received, and your friends list with Invite buttons.
# Steam: friends = Steam friends. LAN test mode: host a party / join by IP.

const UI = preload("res://scripts/ui_kit.gd")
const REFRESH := 5.0

var _body: VBoxContainer
var _refresh_t := 0.0
var _ip_edit: LineEdit

func _online() -> Node:
	return get_node("/root/Online")

func _net() -> Node:
	return get_node("/root/Net")

func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -380
	offset_right = -20
	offset_top = 72
	offset_bottom = -120
	var sb := UI.box(UI.PANEL_BG, UI.BORDER, 2, 10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var head := HBoxContainer.new()
	var t := UI.label("Friends & Party", 20, UI.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := UI.button("X", 14, Vector2(28, 28))
	close.pressed.connect(func(): visible = false)
	head.add_child(close)
	v.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 6)
	scroll.add_child(_body)

	_online().changed.connect(refresh)
	_online().friends_changed.connect(refresh)
	_net().members_changed.connect(refresh)
	visibility_changed.connect(func(): if visible: refresh())
	refresh()

func _process(delta: float) -> void:
	# Periodic refresh only for the Steam friends list (online status changes).
	if not visible or not _online().is_steam():
		return
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = REFRESH
		refresh()

func refresh() -> void:
	if _body == null or not is_inside_tree():
		return
	# Keep a half-typed IP address across refreshes.
	var typed_ip := _ip_edit.text if is_instance_valid(_ip_edit) else ""
	for c in _body.get_children():
		c.queue_free()
	var online := _online()
	var net := _net()

	# --- You
	_body.add_child(UI.label("You: %s" % online.my_name, 15, Color.WHITE))
	var mode := UI.label(online.backend_name(), 12, UI.TEXT_DIM)
	_body.add_child(mode)
	if online.status_text != "":
		var st := UI.label(online.status_text, 12, Color(1.0, 0.7, 0.4))
		st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(st)

	# --- Party
	_section("Party (%d / %d)" % [online.party_size(), online.max_party()])
	if not net.online:
		_body.add_child(UI.label("You're not in a party. Invite a friend to start one.", 13, UI.TEXT_DIM))
	else:
		for id in net.order:
			var info: Dictionary = net.members.get(id, {})
			var star := "★ " if int(id) == int(net.host_member) else "   "
			var you := "  (you)" if int(id) == int(online.my_id) else ""
			var line := "%s%s   Lv %d%s" % [star, str(info.get("name", "?")), int(info.get("level", 1)), you]
			_body.add_child(UI.label(line, 14, UI.ACCENT if int(id) == int(net.host_member) else Color.WHITE))
		if online.queue_instance != "":
			_body.add_child(UI.label("In queue…", 13, Color(0.55, 0.9, 1.0)))
		var leave := UI.button("Leave Party", 14, Vector2(0, 32))
		leave.pressed.connect(func(): online.leave_party())
		_body.add_child(leave)

	# --- Invites
	if not online.invites.is_empty():
		_section("Invites")
		for i in online.invites.size():
			var inv: Dictionary = online.invites[i]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			var l := UI.label("%s invited you" % inv["name"], 14, Color.WHITE)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			var join := UI.button("Join", 13, Vector2(56, 28))
			join.pressed.connect(online.accept_invite.bind(i))
			row.add_child(join)
			var no := UI.button("No", 13, Vector2(40, 28))
			no.pressed.connect(online.decline_invite.bind(i))
			row.add_child(no)
			_body.add_child(row)

	# --- Friends (Steam) or LAN controls
	if online.is_steam():
		_section("Friends")
		var add := UI.button("Add Friend (Steam overlay)", 13, Vector2(0, 30))
		add.tooltip_text = "Steam doesn't allow searching players by name from inside a game,\nso friends are added through the Steam overlay (Shift+Tab)."
		add.pressed.connect(online.open_add_friend)
		_body.add_child(add)
		var friends: Array = online.get_friends()
		if friends.is_empty():
			_body.add_child(UI.label("No Steam friends yet.", 13, UI.TEXT_DIM))
		for f in friends:
			_body.add_child(_friend_row(f))
	else:
		_section("LAN test mode")
		var host := UI.button("Host Party on this PC", 14, Vector2(0, 32))
		host.disabled = net.online
		host.pressed.connect(online.host_lan)
		_body.add_child(host)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_ip_edit = LineEdit.new()
		_ip_edit.placeholder_text = "Host IP (127.0.0.1 = this PC)"
		_ip_edit.text = typed_ip
		_ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ip_edit.add_theme_font_size_override("font_size", 13)
		row.add_child(_ip_edit)
		var join := UI.button("Join", 14, Vector2(60, 32))
		join.pressed.connect(func(): online.join_lan(_ip_edit.text))
		row.add_child(join)
		_body.add_child(row)
		var hint := UI.label("Friends list and matchmaking need Steam (install GodotSteam + run Steam).", 12, UI.TEXT_DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(hint)

func _section(title: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	_body.add_child(gap)
	_body.add_child(UI.label(title, 16, UI.ACCENT))

func _friend_row(f: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var col := Color(0.55, 1.0, 0.55) if f["playing"] else (Color(0.6, 0.8, 1.0) if f["online"] else Color(0.5, 0.5, 0.55))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	var n := UI.label(str(f["name"]), 14, col)
	n.clip_text = true
	info.add_child(n)
	info.add_child(UI.label(str(f["status"]), 11, UI.TEXT_DIM))
	row.add_child(info)
	if f["in_party"]:
		row.add_child(UI.label("In party", 12, UI.ACCENT))
	elif f["online"]:
		var b := UI.button("Invite", 13, Vector2(64, 28))
		b.disabled = not _online().is_leader()
		if b.disabled:
			b.tooltip_text = "Only the party leader can invite."
		b.pressed.connect(_online().invite.bind(int(f["id"])))
		row.add_child(b)
	return row
