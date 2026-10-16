extends Node3D

# A patch of mulch (Nature caster, the Weaver): a low mound of dark earth with
# glowing green-gold flecks, left where a woven creature struck. Only a picture:
# the rules are in player.gd ("Nature caster: the Weaver"). A party member's
# patches are shown faint (Net "mulch" fx).
# Swap-ready: the mound is built from simple meshes in _build(); a real model
# can replace it without touching the gameplay code.
# Usage: const MulchPatch = preload("res://scripts/mulch_patch.gd")

const GROUP := "mulch_patches"
const EARTH := Color(0.32, 0.22, 0.12)
const GLOW := Color(0.6, 0.95, 0.35)
const SIZE := 0.9               # metres across
const APPEAR := 0.25
const FADE := 0.4
const MOVED_FAR := 0.3          # metres: further than this is a move (it sinks, then rises there)

var key := ""
var _mine := true
var _home := Vector3.ZERO
var _t := 0.0
var _flecks: Array[MeshInstance3D] = []
var _glow_mat: StandardMaterial3D
var _going := false

## Show (or update) the patch named `key_` on the ground at `at`.
## `mine` = bright (a party member's are faint).
static func place(parent: Node, key_: String, at: Vector3, mine: bool) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var p: Node3D = null
	for n in _find(parent.get_tree(), key_):
		p = n
	if p == null:
		p = Node3D.new()
		p.set_script(load("res://scripts/mulch_patch.gd"))
		p.set("key", key_)
		p.set("_mine", mine)
		p.set("_home", at)
		parent.add_child(p)
		p.global_position = at
		p.call("_appear")
	elif (p.get("_home") as Vector3).distance_to(at) > MOVED_FAR:
		p.call("_move_to", at)

## Remove the patch named `key_` (it sinks into the ground).
static func remove(tree: SceneTree, key_: String) -> void:
	for p in _find(tree, key_):
		p.call("_fade")

## Remove every patch whose key starts with `prefix` and isn't in `keys`.
static func keep_only(tree: SceneTree, prefix: String, keys: Array) -> void:
	if tree == null:
		return
	for p in tree.get_nodes_in_group(GROUP):
		var k := str(p.get("key"))
		if k.begins_with(prefix) and not keys.has(k):
			p.call("_fade")

static func _find(tree: SceneTree, key_: String) -> Array:
	var out := []
	if tree == null:
		return out
	for p in tree.get_nodes_in_group(GROUP):
		if str(p.get("key")) == key_ and not bool(p.get("_going")):
			out.append(p)
	return out

func _ready() -> void:
	add_to_group(GROUP)
	_build()

func _build() -> void:
	var alpha := 1.0 if _mine else 0.35
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color(EARTH, 0.9 * alpha)
	earth.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	earth.roughness = 1.0
	var mound := MeshInstance3D.new()
	var disc := SphereMesh.new()
	disc.radius = SIZE * 0.5
	disc.height = SIZE * 0.25
	disc.radial_segments = 16
	disc.rings = 4
	disc.material = earth
	mound.mesh = disc
	mound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mound)
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.albedo_color = Color(GLOW, alpha)
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.emission_enabled = true
	_glow_mat.emission = GLOW
	var fleck := SphereMesh.new()
	fleck.radius = 0.05
	fleck.height = 0.1
	fleck.radial_segments = 6
	fleck.rings = 3
	fleck.material = _glow_mat
	for i in 7:
		var a := TAU * i / 7.0 + 0.4 * (i % 2)
		var r := SIZE * (0.15 + 0.25 * ((i * 37) % 10) / 10.0)
		var f := MeshInstance3D.new()
		f.mesh = fleck
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.position = Vector3(cos(a) * r, 0.1, sin(a) * r)
		add_child(f)
		_flecks.append(f)

func _appear() -> void:
	scale = Vector3(0.1, 0.1, 0.1)
	create_tween().tween_property(self, "scale", Vector3.ONE, APPEAR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Carried somewhere else (Greenwood Stag): it sinks here and rises there.
func _move_to(to: Vector3) -> void:
	_home = to
	var t := create_tween()
	t.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), APPEAR)
	t.tween_callback(func(): global_position = to)
	t.tween_property(self, "scale", Vector3.ONE, APPEAR).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _fade() -> void:
	if _going:
		return
	_going = true
	var t := create_tween()
	t.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), FADE)
	t.tween_callback(queue_free)

func _process(delta: float) -> void:
	_t += delta
	# The flecks pulse softly, so the patch reads as alive even in a dark room.
	var e := 1.4 + 0.6 * sin(_t * 3.0)
	_glow_mat.emission_energy_multiplier = e if _mine else e * 0.4
