extends Node3D

# A mote of light (Holy tank): a small floating orb with a thin column of light
# over it, so it can be found even in a dark dungeon. Only a picture: picking
# it up is checked by its owner (player.gd, "Holy tank: the Censer"). Its owner
# sees it bright; party members see theirs faint (Net "motes" fx).
# Usage: const LightMote = preload("res://scripts/light_mote.gd")

const GROUP := "light_motes"
const COLOR := Color(1.0, 0.94, 0.7)
const HOVER := 0.45
const BOB := 0.08
const FLY_TIME := 0.3

var key := ""
var _until := 0.0
var _orb_mat: StandardMaterial3D
var _orb: MeshInstance3D
var _t := 0.0
var _bright := true

## A mote at `at` (on the ground) for `life` seconds. `key` names it, so it can
## be taken or cleared later. `bright` = it is mine (others' are faint).
static func spawn(parent: Node, at: Vector3, key_: String, bright: bool, life: float) -> Node3D:
	if parent == null or not is_instance_valid(parent):
		return null
	clear(parent.get_tree(), key_)
	var m := Node3D.new()
	m.set_script(load("res://scripts/light_mote.gd"))
	m.key = key_
	m._bright = bright
	m._until = Time.get_ticks_msec() / 1000.0 + life
	parent.add_child(m)
	m.global_position = at
	return m

## The mote named `key_` is picked up: it flies to `to` (if given) and is gone.
static func take(tree: SceneTree, key_: String, to: Node3D = null) -> void:
	for m in _find(tree, key_):
		m._fly_to(to)

## Remove the mote named `key_` at once.
static func clear(tree: SceneTree, key_: String) -> void:
	for m in _find(tree, key_):
		m.queue_free()

static func _find(tree: SceneTree, key_: String) -> Array:
	var out := []
	if tree == null:
		return out
	for m in tree.get_nodes_in_group(GROUP):
		if is_instance_valid(m) and str(m.get("key")) == key_:
			out.append(m)
	return out

func _ready() -> void:
	add_to_group(GROUP)
	var a := 1.0 if _bright else 0.35
	_orb = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.13 if _bright else 0.09
	sm.height = sm.radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	_orb.mesh = sm
	_orb_mat = StandardMaterial3D.new()
	_orb_mat.albedo_color = Color(COLOR, a)
	_orb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_orb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_orb.material_override = _orb_mat
	_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_orb.position = Vector3(0, HOVER, 0)
	add_child(_orb)
	var col := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.035
	cm.height = 1.6 if _bright else 0.8
	cm.radial_segments = 6
	col.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(COLOR, 0.3 * a)
	cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	col.material_override = cmat
	col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	col.position = Vector3(0, HOVER + cm.height * 0.5, 0)
	add_child(col)

func _fly_to(to: Node3D) -> void:
	remove_from_group(GROUP)
	_until = INF
	if to == null or not is_instance_valid(to):
		queue_free()
		return
	var tw := create_tween()
	tw.tween_property(self, "global_position", to.global_position + Vector3(0, 0.6, 0), FLY_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "scale", Vector3.ONE * 0.3, FLY_TIME)
	tw.tween_callback(queue_free)

func _process(delta: float) -> void:
	_t += delta
	_orb.position.y = HOVER + sin(_t * 3.0) * BOB
	var left := _until - Time.get_ticks_msec() / 1000.0
	if left <= 0.0:
		queue_free()
		return
	# It flickers in its last seconds.
	if left < 2.0:
		_orb.visible = fmod(_t, 0.3) < 0.2
