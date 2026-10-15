extends Node

# Pings (child "Pings" of the local player). Press Ping (G) to mark whatever is
# under the mouse for your party:
#   - an enemy  -> red "Attack" marker that follows it until it dies
#   - anywhere  -> yellow "Go here" marker on the ground
# Everyone in the party sees it (sent through Net) plus a line in chat. Markers
# fade after Balance.PING_TIME; each player has at most PING_MAX_PER_PLAYER up.

const Balance = preload("res://scripts/balance.gd")
const Combat = preload("res://scripts/combat_utils.gd")
const CIRCLE_SHADER: Shader = preload("res://shaders/aoe_circle.gdshader")
const ENEMY_LAYER_MASK := 4

const COLOR_ATTACK := Color(1.0, 0.3, 0.2)
const COLOR_MOVE := Color(1.0, 0.85, 0.25)

var _ready_at := 0.0
## Active markers: {"node": Node3D, "follow": Node3D or null, "until": float, "member": int}
var _markers: Array = []

func _player() -> Node3D:
	return get_parent() as Node3D

func _net() -> Node:
	return get_node_or_null("/root/Net")

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ping") or (event is InputEventKey and event.echo):
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return   # typing in chat
	get_viewport().set_input_as_handled()
	if _now() < _ready_at:
		return
	_ready_at = _now() + Balance.PING_COOLDOWN
	var hit := _under_mouse()
	if hit.is_empty():
		return
	var enemy: Node3D = hit.get("enemy")
	var kind := "attack" if enemy else "move"
	var pos: Vector3 = hit["pos"]
	var net := _net()
	var me := int(net.my_id()) if net and net.online else 0
	show_ping(_my_name(), kind, pos, enemy, me)
	if net and net.has_method("send_ping"):
		net.send_ping(kind, pos, enemy)

func _my_name() -> String:
	var net := _net()
	if net and net.online:
		return str(net.member_name(net.my_id()))
	return "You"

## What's under the mouse: {"enemy": Node3D or null, "pos": Vector3}, or {} for nothing.
func _under_mouse() -> Dictionary:
	var p := _player()
	var cam := get_viewport().get_camera_3d()
	if p == null or cam == null:
		return {}
	var mouse := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0, 1 | ENEMY_LAYER_MASK, [p.get_rid()])
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var c: Object = hit.collider
		if c is Node and (c as Node).is_in_group("enemies") and c.has_method("is_alive") and c.is_alive():
			return {"enemy": c, "pos": (c as Node3D).global_position}
		return {"enemy": null, "pos": hit.position}
	# Nothing hit (open sky): the floor plane at the player's feet.
	var plane := Plane(Vector3.UP, p.global_position.y - 0.9)
	var at = plane.intersects_ray(from, dir)
	return {"enemy": null, "pos": at} if at != null else {}

## Show a ping (mine, or one a party member sent).
func show_ping(sender: String, kind: String, pos: Vector3, enemy: Node3D, member: int) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	# Too many from this player: the oldest goes.
	var mine := _markers.filter(func(m): return int(m["member"]) == member)
	while mine.size() >= Balance.PING_MAX_PER_PLAYER:
		_remove(mine.pop_front())
	var attack := kind == "attack" and enemy != null and is_instance_valid(enemy)
	var col := COLOR_ATTACK if attack else COLOR_MOVE
	var root := Node3D.new()
	root.top_level = true
	scene.add_child(root)
	var radius := Combat.hitbox_radius(enemy) + 0.35 if attack else 0.7
	var ring := _ring(radius, col)
	root.add_child(ring)
	if not attack:
		root.add_child(_beam(col))
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0014
	label.font_size = 30
	label.outline_size = 10
	label.modulate = col
	var what := ""
	if attack:
		var nm = enemy.get("display_name")
		what = str(nm) if nm != null and str(nm) != "" else "enemy"
		label.text = "! Attack !\n%s\n(%s)" % [what, sender]
		label.position.y = float(enemy.get("health_bar_height")) + 0.8 if enemy.get("health_bar_height") != null else 2.2
	else:
		label.text = "Go here\n(%s)" % sender
		label.position.y = 2.6
	root.add_child(label)
	root.global_position = _feet(enemy) if attack else pos
	# Pop in, then pulse.
	root.scale = Vector3.ONE * 0.2
	var t := root.create_tween()
	t.tween_property(root, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var pulse := ring.create_tween().set_loops()
	pulse.tween_property(ring, "scale", Vector3(radius * 2.4, 1, radius * 2.4), 0.5)
	pulse.tween_property(ring, "scale", Vector3(radius * 2.0, 1, radius * 2.0), 0.5)
	_markers.append({"node": root, "follow": enemy if attack else null, "until": _now() + Balance.PING_TIME,
		"member": member})
	var net := _net()
	if net:
		net.system_message.emit("%s: %s" % [sender, ("Attack %s!" % what) if attack else "Go here!"])

func _feet(n: Node3D) -> Vector3:
	return Vector3(n.global_position.x, Combat.feet_y(n) + 0.05, n.global_position.z)

func _ring(radius: float, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.orientation = PlaneMesh.FACE_Y
	m.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = CIRCLE_SHADER
	mat.set_shader_parameter("color", col)
	mat.set_shader_parameter("fill_alpha", 0.15)
	mat.set_shader_parameter("rim_width", 0.2)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position.y = 0.05
	m.scale = Vector3(radius * 2.0, 1, radius * 2.0)
	return m

## Thin light column so a "Go here" ping is easy to spot.
func _beam(col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.1
	cyl.height = 2.4
	m.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(col, 0.45)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position.y = 1.2
	return m

func _process(_delta: float) -> void:
	if _markers.is_empty():
		return
	var now := _now()
	for m in _markers.duplicate():
		var node: Node3D = m["node"]
		if not is_instance_valid(node):
			_markers.erase(m)
			continue
		var f: Variant = m["follow"]
		if f != null:
			if not is_instance_valid(f) or not f.is_alive():
				_remove(m)   # the pinged enemy died
				continue
			node.global_position = _feet(f)
		if now >= float(m["until"]):
			_remove(m)

func _remove(m: Dictionary) -> void:
	_markers.erase(m)
	var node: Node3D = m["node"]
	if not is_instance_valid(node):
		return
	var t := node.create_tween()
	t.tween_property(node, "scale", Vector3.ONE * 0.01, 0.2)
	t.tween_callback(node.queue_free)

func _exit_tree() -> void:
	for m in _markers:
		if is_instance_valid(m["node"]):
			m["node"].queue_free()
	_markers.clear()
