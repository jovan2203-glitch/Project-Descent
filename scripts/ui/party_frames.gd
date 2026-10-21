extends Control
class_name PartyFrames

# Party frames (right side, under the target frame), like WoW's: one frame per
# party member, you first, then the others in party order. Each shows the name,
# a health bar with the shield on it, a role icon (shield = tank, cross = healer,
# sword = damage) and a pip while they carry a Rime Shell / Thawing.
# Click a frame: that ally becomes your friendly target. Hover one and press a
# heal: it goes to that ally (Player._mouseover_begin asks member_at), with or
# without the mouseover casting setting. Greyed when down, dimmed when out of
# range or line of sight. Under the frames: the party's combat rez charges.
# Shown in a party only (Settings > Interface: "Party frames when solo").

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")

const GROUP := "party_frames"
const FRAME_W := 200.0
const FRAME_H := 40.0
const GAP := 4.0
const BAR_H := 16.0
const RANGE := 40.0   # metres: farther than this is dimmed (the heals' usual range)
const MAX_FRAMES := 5
const HP_COLOR := Color(0.2, 0.75, 0.3)
const HP_LOW := Color(0.85, 0.2, 0.15)
const SHIELD_COLOR := Color(0.72, 0.9, 1.0, 0.85)
const DOWN_COLOR := Color(1.0, 0.6, 0.3)
const ROLE_COLORS := {"tank": Color(0.45, 0.7, 1.0), "healer": Color(0.4, 1.0, 0.5), "dps": Color(1.0, 0.5, 0.4)}

var player: Node = null
var _frames: Array = []        # one Dictionary per frame: panel, name, fill, shield, text, role, pip, body
var _rez_label: Label
var _t := 0.0

func _ready() -> void:
	add_to_group(GROUP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(GAP))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	for i in MAX_FRAMES:
		_frames.append(_make_frame(v))
	_rez_label = Label.new()
	_rez_label.add_theme_font_size_override("font_size", 13)
	_rez_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	_rez_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_rez_label.add_theme_constant_override("outline_size", 4)
	_rez_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_rez_label)
	custom_minimum_size = Vector2(FRAME_W, MAX_FRAMES * (FRAME_H + GAP) + 20.0)
	size = custom_minimum_size
	_refresh()

func _make_frame(parent: Control) -> Dictionary:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(FRAME_W, FRAME_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.6)
	sb.set_corner_radius_all(4)
	sb.border_color = Color(0.3, 1.0, 0.45)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(panel)
	var role := RoleIcon.new()
	role.position = Vector2(4, 4)
	role.size = Vector2(14, 14)
	role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(role)
	var name_l := Label.new()
	name_l.position = Vector2(22, 1)
	name_l.size = Vector2(FRAME_W - 44, 18)
	name_l.clip_text = true
	name_l.add_theme_font_size_override("font_size", 13)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(name_l)
	var pip := ColorRect.new()   # Rime Shell (bright) / Thawing (pale)
	pip.position = Vector2(FRAME_W - 16, 6)
	pip.size = Vector2(10, 10)
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(pip)
	var bar := Control.new()
	bar.position = Vector2(4, FRAME_H - BAR_H - 4)
	bar.size = Vector2(FRAME_W - 8, BAR_H)
	bar.clip_contents = true
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bar)
	var bg := ColorRect.new()
	bg.color = Color(0.22, 0.22, 0.22)
	bg.size = bar.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bg)
	var fill := ColorRect.new()
	fill.color = HP_COLOR
	fill.size = bar.size
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(fill)
	var shield := ColorRect.new()
	shield.color = SHIELD_COLOR
	shield.size = Vector2(0, BAR_H)
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(shield)
	var text := Label.new()
	text.size = bar.size
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 11)
	text.add_theme_color_override("font_outline_color", Color.BLACK)
	text.add_theme_constant_override("outline_size", 3)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(text)
	var f := {"panel": panel, "name": name_l, "fill": fill, "shield": shield, "text": text,
		"role": role, "pip": pip, "bar_w": bar.size.x, "body": null, "style": sb}
	panel.gui_input.connect(func(e: InputEvent): _on_frame_input(f, e))
	return f

func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.1
	_refresh()

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

func _in_party() -> bool:
	var net := get_node_or_null("/root/Net")
	return net != null and net.with_others()

func _show_solo() -> bool:
	var s := get_node_or_null("/root/Settings")
	return s != null and bool(s.get("party_frames_solo"))

func _refresh() -> void:
	var list := members() if _in_party() or _show_solo() else []
	visible = not list.is_empty()
	for i in _frames.size():
		var f: Dictionary = _frames[i]
		var body: Node = list[i] if i < list.size() else null
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
	var w: float = f["bar_w"]
	var fill: ColorRect = f["fill"]
	fill.size.x = w * frac
	fill.color = HP_LOW if frac < 0.35 else HP_COLOR
	var shield := shield_of(body)
	var sh: ColorRect = f["shield"]
	sh.position.x = w * frac
	sh.size.x = w * clampf(float(shield) / mhp, 0.0, 1.0 - frac)
	var text: Label = f["text"]
	if down:
		text.text = "DOWNED"
	elif dead:
		text.text = "Dead"
	else:
		text.text = "%d / %d" % [hp, mhp] + ("  +%d" % shield if shield > 0 else "")
	var name_l: Label = f["name"]
	name_l.text = display_name_of(body)
	name_l.add_theme_color_override("font_color", DOWN_COLOR if down else Color.WHITE)
	var role: RoleIcon = f["role"]
	role.role = role_of(body)
	role.queue_redraw()
	var pip: ColorRect = f["pip"]
	pip.visible = has_shell(body) or has_thawing(body)
	pip.color = Color(0.6, 0.9, 1.0) if has_shell(body) else Color(0.75, 0.7, 0.85, 0.8)
	var sb: StyleBoxFlat = f["style"]
	var targeted := player != null and is_instance_valid(player) and is_same(player.get("friendly_target"), body)
	sb.set_border_width_all(2 if targeted else 0)
	var panel: Control = f["panel"]
	panel.modulate = Color(0.55, 0.55, 0.55, 0.9) if down or dead else (Color(1, 1, 1, 0.45) if not reachable(body) else Color.WHITE)

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
