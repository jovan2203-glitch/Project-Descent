extends HudElement
class_name PartyFrames

# Party frames, like WoW's: one frame per party member, you first, then the
# others in party order (or tank, healer, damage). Each shows the name, a health
# bar with the shield on it, a role icon (shield = tank, cross = healer, sword =
# damage) and a pip while they carry a Rime Shell / Thawing.
# Click a frame: that ally becomes your friendly target. Hover one and press a
# heal: it goes to that ally (Player._mouseover_begin asks member_at), with or
# without the mouseover casting setting. Greyed when down, dimmed when out of
# range or line of sight. Under the frames: the party's combat rez charges.
# Shown in a party only, unless UI Options > Party > "Show when solo".

const GROUP := "party_frames"
const RANGE := 40.0   # metres: farther than this is dimmed (the heals' usual range)
const MAX_FRAMES := 5
const HP_COLOR := Color(0.2, 0.72, 0.3)
const HP_LOW := Color(0.85, 0.2, 0.15)
const DOWN_COLOR := Color(1.0, 0.6, 0.3)
const ROLE_COLORS := {"tank": Color(0.45, 0.7, 1.0), "healer": Color(0.4, 1.0, 0.5), "dps": Color(1.0, 0.5, 0.4)}
const ROLE_ORDER := {"tank": 0, "healer": 1, "dps": 2}

var _frames: Array = []        # one Dictionary per frame: panel, name, bar, role, pip, edge, body
var _rez_label: Label
var _list: Array = []
var _t := 0.0

func _init() -> void:
	super()
	key = "party_frames"
	title = "Party Frames"
	always = true

func build() -> void:
	add_to_group(GROUP)
	for i in MAX_FRAMES:
		_frames.append(_make_frame())
	_rez_label = UISkin.label("", 12, Color(1.0, 0.85, 0.5))
	add_child(_rez_label)
	_refresh()

func _make_frame() -> Dictionary:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UISkin.backdrop())
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_child(panel)
	var bar := HudBar.new()
	panel.add_child(bar)
	var role := RoleIcon.new()
	role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(role)
	var name_l := UISkin.label("", 12)
	name_l.clip_text = true
	panel.add_child(name_l)
	var pip := ColorRect.new()   # Rime Shell (bright) / Thawing (pale)
	pip.size = Vector2(8, 8)
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(pip)
	var edge := Panel.new()      # your friendly target
	edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(1, 1, 1, 0.9)
	sb.set_border_width_all(1)
	edge.add_theme_stylebox_override("panel", sb)
	edge.visible = false
	panel.add_child(edge)
	var f := {"panel": panel, "name": name_l, "bar": bar, "role": role, "pip": pip, "edge": edge, "body": null}
	panel.gui_input.connect(func(e: InputEvent): _on_frame_input(f, e))
	return f

func layout() -> void:
	if _frames.is_empty():
		return
	var w := float(cfg("width"))
	var h := float(cfg("height"))
	var gap := float(cfg("spacing"))
	var grow := str(cfg("grow"))
	for i in _frames.size():
		var f: Dictionary = _frames[i]
		var panel: Panel = f["panel"]
		panel.size = Vector2(w, h)
		panel.add_theme_stylebox_override("panel", UISkin.backdrop())
		match grow:
			"right":
				panel.position = Vector2(i * (w + gap), 0)
			"up":
				panel.position = Vector2(0, (MAX_FRAMES - 1 - i) * (h + gap))
			_:
				panel.position = Vector2(0, i * (h + gap))
		var bar: HudBar = f["bar"]
		bar.position = Vector2(1, 1)
		bar.size = Vector2(w - 2, h - 2)
		bar.font_size = UISkin.font(11)
		var role: Control = f["role"]
		role.position = Vector2(4, 4)
		role.size = Vector2(12, 12)
		var name_l: Label = f["name"]
		name_l.position = Vector2(19, 1)
		name_l.size = Vector2(w - 38, 16)
		(f["pip"] as Control).position = Vector2(w - 13, 5)
	var box := Vector2(MAX_FRAMES * (w + gap) - gap, h) if grow == "right" else Vector2(w, MAX_FRAMES * (h + gap) - gap)
	_rez_label.position = Vector2(0, box.y + 2) if grow != "up" else Vector2(0, -18)
	set_box(box)

func update(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.1
	_refresh()

func slow_update() -> void:
	if not visible:
		_refresh()   # (shows itself when a party forms)

## Everyone to show, you first: [body, ...].
func members() -> Array:
	var net := get_node_or_null("/root/Net")
	var out: Array = []
	if player != null and is_instance_valid(player):
		out.append(player)
	if net != null and bool(net.online):
		for id in net.order:
			var b: Node = net.body_of(int(id))
			if b != null and b != player and not out.has(b):
				out.append(b)
	return out.slice(0, MAX_FRAMES)

## The members in the order the options ask for (yourself left out if hidden).
func shown_members() -> Array:
	var list := members()
	if not bool(cfg("show_self")) and _in_party():
		list.erase(player)
	if str(cfg("sort")) == "role":
		var order := list.duplicate()
		order.sort_custom(func(a, b):
			var ra := int(ROLE_ORDER.get(role_of(a), 2))
			var rb := int(ROLE_ORDER.get(role_of(b), 2))
			return ra < rb if ra != rb else list.find(a) < list.find(b))
		list = order
	return list

func _in_party() -> bool:
	var net := get_node_or_null("/root/Net")
	return net != null and net.with_others()

func _show_solo() -> bool:
	return bool(cfg("show_solo"))

func wanted() -> bool:
	return not _list.is_empty()

func _refresh() -> void:
	_list = shown_members() if _in_party() or _show_solo() else []
	refresh_visible()
	for i in _frames.size():
		var f: Dictionary = _frames[i]
		var body: Node = _list[i] if i < _list.size() else null
		f["body"] = body
		(f["panel"] as Control).visible = body != null
		if body != null:
			_fill_frame(f, body)
	_refresh_rez()

func _fill_frame(f: Dictionary, body: Node) -> void:
	var hp := int(body.get("health"))
	var mhp := maxi(int(body.get("max_health")), 1)
	var down: bool = bool(body.get("downed")) if body.get("downed") != null else (body.has_method("is_downed") and body.is_downed())
	var dead: bool = hp <= 0 and not down
	var frac := clampf(float(hp) / mhp, 0.0, 1.0)
	var shield := shield_of(body)
	var bar: HudBar = f["bar"]
	bar.fill_color = HP_LOW if frac < 0.35 else UISkin.health_color(frac, HP_COLOR)
	bar.set_fracs(frac, float(shield) / mhp)
	var text := "DOWNED" if down else ("Dead" if dead else UISkin.short(hp) + ("  +%s" % UISkin.short(shield) if shield > 0 else ""))
	if bar.size.y >= 30:
		bar.set_texts("", text)   # tall frames: under the name, centred
	else:
		bar.set_texts("", "", text)
	var name_l: Label = f["name"]
	var nm := display_name_of(body)
	if name_l.text != nm:
		name_l.text = nm
	name_l.add_theme_color_override("font_color", DOWN_COLOR if down else Color.WHITE)
	var role: RoleIcon = f["role"]
	var r := role_of(body)
	if role.role != r:
		role.role = r
		role.queue_redraw()
	var pip: ColorRect = f["pip"]
	pip.visible = has_shell(body) or has_thawing(body)
	pip.color = Color(0.6, 0.9, 1.0) if has_shell(body) else Color(0.75, 0.7, 0.85, 0.8)
	var targeted := player != null and is_instance_valid(player) and is_same(player.get("friendly_target"), body)
	(f["edge"] as Control).visible = targeted
	var panel: Control = f["panel"]
	panel.modulate = Color(0.55, 0.55, 0.55, 0.9) if down or dead else (Color(1, 1, 1, float(cfg("range_alpha"))) if not reachable(body) else Color.WHITE)

func _refresh_rez() -> void:
	var net := get_node_or_null("/root/Net")
	var kit: Variant = player.get("rez_kit") if player != null and is_instance_valid(player) else null
	if net == null or kit == null or not kit.charges_apply() or not _in_party():
		_rez_label.visible = false
		return
	_rez_label.visible = true
	var left := int(ceil(float(net.combat_rez_next_in())))
	_rez_label.text = "Combat rez %d  ·  next %d:%02d" % [int(net.combat_rez_charges()), left / 60, left % 60]

# --- What a frame shows --------------------------------------------------------------

static func display_name_of(body: Node) -> String:
	if body.is_in_group("player"):
		var online := body.get_node_or_null("/root/Online")
		var n := str(online.get("my_name")) if online != null and online.get("my_name") != null else ""
		return n if n != "" else "You"
	return str(body.get("display_name"))

static func shield_of(body: Node) -> int:
	if body.get("shield") != null:
		return int(body.get("shield"))
	var st := body.get_node_or_null("Status")
	return int(st.total_absorb()) if st != null and st.has_method("total_absorb") else 0

static func role_of(body: Node) -> String:
	if body.get("role") != null and str(body.get("role")) != "":
		return str(body.get("role"))
	var pd := body.get_node_or_null("/root/PlayerData")
	return Abilities.role_of_bar(pd.action_bar) if pd != null else "dps"

static func has_shell(body: Node) -> bool:
	if body.get("has_rime_shell") != null:
		return bool(body.get("has_rime_shell"))
	var status := body.get_node_or_null("Status")   # (anyone's shell: the frame just shows it)
	return status != null and status.has_method("has") and status.has("rime_shell")

static func has_thawing(body: Node) -> bool:
	if body.has_method("has_lockout"):
		return body.has_lockout("thawing")
	var status := body.get_node_or_null("Status")
	return status != null and status.has_method("has") and status.has("thawing")

## In range and in sight of my character (else the frame is dimmed).
func reachable(body: Node) -> bool:
	if player == null or not is_instance_valid(player) or body == player:
		return true
	var b := body as Node3D
	return b != null and (player as Node3D).global_position.distance_to(b.global_position) <= RANGE \
		and (not player.has_method("can_see") or player.can_see(b))

# --- Mouse ----------------------------------------------------------------------------

func _on_frame_input(f: Dictionary, e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var body: Node = f["body"]
		if body != null and player != null and player.has_method("select_friendly"):
			player.select_friendly(body)
			accept_event()
	# Right click: inspect them (gear, stats, abilities, talents).
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
		var body: Node = f["body"]
		var net := get_node_or_null("/root/Net")
		if body != null and net != null:
			net.request_inspect(net.member_of(body))
			accept_event()

## The party member whose frame is under `screen_pos` (null if none).
func member_at(screen_pos: Vector2) -> Node:
	if not is_visible_in_tree():
		return null
	for f in _frames:
		var panel: Control = f["panel"]
		if f["body"] != null and panel.visible and panel.get_global_rect().has_point(screen_pos):
			return f["body"]
	return null

## The frames of the scene (null when there is no HUD).
static func of(tree: SceneTree) -> Node:
	return tree.get_first_node_in_group(GROUP) if tree != null else null

# --- Role icon ------------------------------------------------------------------------

class RoleIcon extends Control:
	var role := "dps"

	func _draw() -> void:
		var c: Color = ROLE_COLORS.get(role, Color.WHITE)
		var s := size
		match role:
			"tank":   # a shield
				var pts := PackedVector2Array([Vector2(1, 1), Vector2(s.x - 1, 1), Vector2(s.x - 1, s.y * 0.5),
					Vector2(s.x * 0.5, s.y - 1), Vector2(1, s.y * 0.5)])
				draw_colored_polygon(pts, c)
				draw_polyline(pts + PackedVector2Array([pts[0]]), Color.BLACK, 1.0)
			"healer":   # a cross
				draw_rect(Rect2(s.x * 0.36, 1, s.x * 0.28, s.y - 2), c)
				draw_rect(Rect2(1, s.y * 0.36, s.x - 2, s.y * 0.28), c)
			_:   # a sword
				draw_line(Vector2(2, s.y - 2), Vector2(s.x - 2, 2), c, 2.5)
				draw_line(Vector2(2, s.y * 0.55), Vector2(s.x * 0.45, s.y - 2), c, 2.0)
