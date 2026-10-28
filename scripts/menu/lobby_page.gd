extends "res://scripts/menu/menu_part.gd"
class_name LobbyPage

# The Lobby page: party slots, the friends (social) panel and the queue banner.
# Every party card has a 3D podium standing in it (behind the UI, lined up with the
# card each frame), and a party member's character stands on theirs. Cards are
# mostly see-through so the podium / character shows. Party members use the same
# base model as you for now; gear and character customization plug in at
# _make_party_model later.

const PARTY_MODEL = preload("res://assets/player/Idle.fbx")
var social: PanelContainer
var _party_slots: Array[Button] = []
var _you_label: Label
var _you_sub: Label   # "Lv 12  •  Spec" under your name
var _queue_banner: Label
var _party_row: HBoxContainer

const PARTY_Z := -1.2            # the party stands a little behind you
const PARTY_MODEL_HEIGHT := 1.8  # the model's real height (m), for scaling it into a card
var _party_podiums: Array[MeshInstance3D] = []
var _party_lights: Array[OmniLight3D] = []
var _party_models: Array = []    # per card: Node3D or null
var _party_member_ids: Array = []   # per card: member id or null

func _build_party_podiums() -> void:
	var mesh: Mesh = menu.get_node("Pedestal").mesh   # same look as your pedestal, scaled per card
	for i in MainMenu.PARTY_SLOTS:
		var p := MeshInstance3D.new()
		p.mesh = mesh
		p.visible = false
		menu.add_child(p)
		_party_podiums.append(p)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.9, 0.78)
		l.light_energy = 1.4
		l.omni_range = 3.0
		l.visible = false
		menu.add_child(l)
		_party_lights.append(l)
		_party_models.append(null)
		_party_member_ids.append(null)

## A party member's character. Same base model as yours for now (later: their
## gear and customization, from `info`).
func _make_party_model(_info: Dictionary) -> Node3D:
	var m: Node3D = PARTY_MODEL.instantiate()
	menu.add_child(m)
	var anim: AnimationPlayer = m.find_child("AnimationPlayer", true, false)
	if anim and anim.has_animation("mixamo_com"):
		anim.get_animation("mixamo_com").loop_mode = Animation.LOOP_LINEAR
		anim.play("mixamo_com")
		anim.seek(randf() * 2.0, true)   # not all in step
	return m

## Put member `id` (null = nobody) on card `i`'s podium.
func _set_party_member(i: int, id: Variant, info: Dictionary) -> void:
	if _party_member_ids[i] == id:
		return
	_party_member_ids[i] = id
	if _party_models[i] != null and is_instance_valid(_party_models[i]):
		_party_models[i].queue_free()
	_party_models[i] = _make_party_model(info) if id != null else null

## Where a screen point of the UI lands on the party's plane (z = PARTY_Z).
func _screen_to_party_plane(p: Vector2) -> Vector3:
	var o := menu.camera.project_ray_origin(p)
	var d := menu.camera.project_ray_normal(p)
	if absf(d.z) < 0.0001:
		return o
	return o + d * ((PARTY_Z - o.z) / d.z)

## Line the podiums (and characters) up with their cards; called every frame
## so they follow window resizes and layout changes.
func _layout_party_3d() -> void:
	if _party_podiums.is_empty():
		return
	var lobby: bool = menu.pages.has("Lobby") and menu.pages["Lobby"].visible
	for i in _party_slots.size():
		var slot := _party_slots[i]
		var show := lobby and slot.is_visible_in_tree() and slot.size.y > 0.0
		var podium := _party_podiums[i]
		var model_i: Node3D = _party_models[i] if _party_models[i] != null and is_instance_valid(_party_models[i]) else null
		podium.visible = show
		_party_lights[i].visible = show
		if model_i:
			model_i.visible = show
		if not show:
			continue
		var xf := slot.get_global_transform_with_canvas()
		var bottom := _screen_to_party_plane(xf * Vector2(slot.size.x * 0.5, slot.size.y))
		var top := _screen_to_party_plane(xf * Vector2(slot.size.x * 0.5, 0.0))
		var h := top.y - bottom.y   # the card's height in the world
		var feet := Vector3(bottom.x, bottom.y + 0.1 * h, PARTY_Z)
		# Pedestal mesh: radius 1, height 0.2, centred on its origin.
		podium.scale = Vector3(0.28 * h, 0.5 * h, 0.28 * h)
		podium.position = feet - Vector3(0, 0.05 * h, 0)
		_party_lights[i].position = feet + Vector3(0, 0.9 * h, 0.8)
		_party_lights[i].omni_range = 1.4 * h
		if model_i:
			model_i.scale = Vector3.ONE * (0.76 * h / PARTY_MODEL_HEIGHT)
			model_i.position = feet
			model_i.rotation.y = 0.3 if feet.x < 0.0 else -0.3   # turned a little toward you

## Card look: see-through (the podium stands in it); a member's name sits at the top.
func _style_party_slot(slot: Button, occupied: bool) -> void:
	var a := 0.12 if occupied else 0.3
	slot.add_theme_stylebox_override("normal", menu._box(Color(0.07, 0.075, 0.1, a), Color(0.3, 0.3, 0.33), 2, 10))
	slot.add_theme_stylebox_override("hover", menu._box(Color(0.1, 0.1, 0.13, a + 0.1), MainMenu.C_ACCENT, 2, 10))
	slot.add_theme_stylebox_override("pressed", menu._box(Color(0.1, 0.1, 0.13, a + 0.1), MainMenu.C_ACCENT, 2, 10))

func _toggle_social() -> void:
	social.visible = not social.visible
	if social.visible:
		social.move_to_front()

func _refresh_party() -> void:
	var online := menu.get_node("/root/Online")
	var net := menu.get_node("/root/Net")
	var me := int(online.my_id)
	var others: Array = []
	for id in net.order:
		if int(id) != me:
			others.append(id)
	for i in _party_slots.size():
		var slot := _party_slots[i]
		var who: Label = slot.get_node("Who")
		if i < others.size():
			var info: Dictionary = net.members.get(others[i], {})
			var lead := "★ " if int(others[i]) == int(net.host_member) else ""
			slot.text = ""
			who.text = "%s%s\n%s" % [lead, str(info.get("name", "?")), _level_spec_line(info)]
			who.visible = true
			_show_spec(slot, info)
			slot.tooltip_text = str(info.get("name", "?")) + (" (party leader)" if lead != "" else "") + ": click to inspect"
			slot.set_meta("member", int(others[i]))
			_style_party_slot(slot, true)
			_set_party_member(i, others[i], info)
		else:
			slot.text = "+\nInvite"
			slot.add_theme_color_override("font_color", MainMenu.C_TEXT_DIM)
			who.visible = false
			_show_spec(slot, {})
			slot.tooltip_text = "Invite a friend"
			slot.remove_meta("member")
			_style_party_slot(slot, false)
			_set_party_member(i, null, {})
	if _you_label:
		var lead := "★ " if net.online and int(net.host_member) == me else ""
		_you_label.text = lead + str(online.my_name)
		_you_sub.text = _level_spec_line(net._my_info())
	menu.ready_check.refresh()
	# Everyone can open the Play screen; only the leader can queue / start there.
	menu.refresh_play_button()
	if menu.queue_page._queue_cards.size() > 0:
		menu.queue_page._refresh_queue()

## "Lv 12  •  Hard Winter" (no spec yet: just the level).
func _level_spec_line(info: Dictionary) -> String:
	var spec := str(info.get("spec", ""))
	return "Lv %d" % int(info.get("level", 1)) + ("  •  " + spec if spec != "" else "")

## A card's role icon and book-coloured bottom edge ({} = empty card: hidden).
func _show_spec(slot: Button, info: Dictionary) -> void:
	var role = slot.get_node("Role")   # PartyFrames.RoleIcon
	var strip: ColorRect = slot.get_node("Strip")
	role.visible = info.has("role")
	strip.visible = str(info.get("book", "")) != ""
	if role.visible:
		role.role = str(info["role"])
		role.queue_redraw()
	if strip.visible:
		strip.color = Categories.color(str(info["book"]))

# Your level / role / spec changed: tell the party, at most once a second.
var _info_wait := -1.0

func _my_info_changed() -> void:
	if _info_wait < 0.0:
		_info_wait = 1.0

func _tick_my_info(delta: float) -> void:
	if _info_wait < 0.0:
		return
	_info_wait -= delta
	if _info_wait < 0.0:
		var net := menu.get_node("/root/Net")
		net.update_my_info()
		if _you_sub:
			_you_sub.text = _level_spec_line(net._my_info())

func _instance_name(key: String) -> String:
	return DB.title(key) if DB.is_dungeon_key(key) else key.get_file().get_basename().capitalize()

func _update_queue_banner() -> void:
	if _queue_banner == null:
		return
	var online := menu.get_node("/root/Online")
	if online.queue_instance == "":
		_queue_banner.visible = false
		return
	_queue_banner.visible = true
	var s: int = online.queue_seconds()
	_queue_banner.text = "In queue: %s   •   %d / %d players   •   %d:%02d" % [
		_instance_name(online.queue_instance), online.party_size(), online.max_party(), floori(s / 60.0), s % 60]

# Lobby: two empty party slots on each side of the player.
func _build_lobby() -> Control:
	var page := menu._full_rect_page()

	var row := HBoxContainer.new()
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.anchor_top = 0.5
	row.anchor_bottom = 0.5
	row.offset_top = -110
	row.offset_bottom = 150
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(row)
	_party_row = row

	for i in MainMenu.PARTY_SLOTS:
		if i == MainMenu.PARTY_SLOTS / 2:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(300, 0)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(gap)
		var ps := _party_slot()
		_party_slots.append(ps)
		row.add_child(ps)

	var name_label := menu._label("You", 22, Color.WHITE)
	_you_label = name_label
	name_label.anchor_left = 0.5
	name_label.anchor_right = 0.5
	name_label.anchor_top = 1.0
	name_label.anchor_bottom = 1.0
	name_label.offset_left = -100
	name_label.offset_right = 100
	name_label.offset_top = -80
	name_label.offset_bottom = -50
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(name_label)
	_you_sub = menu._label("", 14, MainMenu.C_TEXT_DIM)
	_you_sub.anchor_left = 0.5
	_you_sub.anchor_right = 0.5
	_you_sub.anchor_top = 1.0
	_you_sub.anchor_bottom = 1.0
	_you_sub.offset_left = -150
	_you_sub.offset_right = 150
	_you_sub.offset_top = -52
	_you_sub.offset_bottom = -32
	_you_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(_you_sub)
	menu.ready_check.set_you_badge(menu.ready_check.make_badge(name_label))
	# Loadout quick swap, to the right of your name.
	var picker := menu.loadouts.lobby_picker()
	picker.anchor_left = 0.5
	picker.anchor_right = 0.5
	picker.anchor_top = 1.0
	picker.anchor_bottom = 1.0
	picker.offset_left = 120
	picker.offset_right = 290
	picker.offset_top = -80
	picker.offset_bottom = -50
	page.add_child(picker)
	return page

func _party_slot() -> Control:
	var slot := Button.new()
	slot.custom_minimum_size = Vector2(150, 240)
	slot.text = "+\nEmpty slot"
	slot.add_theme_font_size_override("font_size", 18)
	slot.add_theme_color_override("font_color", MainMenu.C_TEXT_DIM)
	slot.add_theme_color_override("font_hover_color", Color.WHITE)
	_style_party_slot(slot, false)
	slot.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# A member's name + level, at the top of the card (above their character).
	var who := menu._label("", 15, Color.WHITE)
	who.name = "Who"
	who.set_anchors_preset(Control.PRESET_TOP_WIDE)
	who.offset_top = 8
	who.offset_bottom = 70
	who.offset_left = 22   # clear of the role icon
	who.offset_right = -22   # and the ready badge
	who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.visible = false
	slot.add_child(who)
	var role := PartyFrames.RoleIcon.new()
	role.name = "Role"
	role.position = Vector2(8, 8)
	role.size = Vector2(16, 16)
	role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	role.visible = false
	slot.add_child(role)
	var strip := ColorRect.new()
	strip.name = "Strip"
	strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_left = 6
	strip.offset_right = -6
	strip.offset_top = -6
	strip.offset_bottom = -2
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.visible = false
	slot.add_child(strip)
	menu.ready_check.make_badge(slot)
	slot.tooltip_text = "Invite a friend"
	# A member's card inspects them (gear, stats, abilities, talents); an empty one invites.
	slot.pressed.connect(func():
		if slot.has_meta("member"):
			menu.get_node("/root/Net").request_inspect(int(slot.get_meta("member")))
			return
		social.visible = true
		social.move_to_front())
	return slot

