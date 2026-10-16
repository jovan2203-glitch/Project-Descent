extends Node3D

# A prism (Holy healer #2): a floating crystal of light that slowly turns. Its
# inner glow follows how much light it holds. Only a picture: the rules are in
# player.gd ("Holy healer: the Prisms"). Moving one makes it flicker out where it
# was and flicker in at its new spot; shattering one bursts it into shards. A
# party member's prisms are shown faint (Net "prisms" fx).
# Swap-ready: the crystal is built from simple meshes in _build(); a real model
# can replace it without touching the gameplay code.
# Usage: const Prism = preload("res://scripts/prism.gd")

const GROUP := "prisms"
const COLOR := Color(0.92, 0.96, 1.0)
const FULL_COLOR := Color(1.0, 0.95, 0.75)
## Gold prisms (the archer's): only arrows use them.
const GOLD := Color(1.0, 0.8, 0.35)
const GOLD_FULL := Color(1.0, 0.92, 0.55)
const SPIN := 0.8               # radians per second
const BOB := 0.06
const FLICKER := 0.25           # seconds out, then in
const MOVED_FAR := 0.3          # metres: further than this is a move (it flickers)

var key := ""
var _mine := true
var _gold := false
var _fill := 0.0
var _marked := false
var _t := 0.0
var _body: Node3D
var _core_mat: StandardMaterial3D
var _shell_mat: StandardMaterial3D
var _mark: MeshInstance3D
var _home := Vector3.ZERO       # where it hovers (the bob is added on top)
var _moving := false

## Show (or update) the prism named `key_` hovering at `at`, `fill` 0..1.
## `mine` = bright (a party member's are faint); `marked` = my prism target;
## `gold` = an archer's prism (white = a healer's).
static func place(parent: Node, key_: String, at: Vector3, fill: float, mine: bool, marked: bool = false, gold: bool = false) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var p: Node3D = null
	for n in _find(parent.get_tree(), key_):
		p = n
	if p == null:
		p = Node3D.new()
		p.set_script(load("res://scripts/prism.gd"))
		p.set("key", key_)
		p.set("_mine", mine)
		p.set("_gold", gold)
		p.set("_home", at)
		parent.add_child(p)
		p.global_position = at
		p.call("_appear")
	elif (p.get("_home") as Vector3).distance_to(at) > MOVED_FAR:
		p.call("_flicker_to", at)
	p.call("_set_fill", fill, marked)

## Remove the prism named `key_` (it fades).
static func remove(tree: SceneTree, key_: String) -> void:
	for p in _find(tree, key_):
		p.call("_fade")

## The prism named `key_` shatters.
static func shatter(tree: SceneTree, key_: String) -> void:
	for p in _find(tree, key_):
		p.call("_shatter")

## Remove every prism whose key starts with `prefix` and isn't in `keys`.
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
		if is_instance_valid(p) and str(p.get("key")) == key_:
			out.append(p)
	return out

func _ready() -> void:
	add_to_group(GROUP)
	_build()

func _build() -> void:
	_body = Node3D.new()
	add_child(_body)
	var a := 0.85 if _mine else 0.3
	_shell_mat = StandardMaterial3D.new()
	_shell_mat.albedo_color = Color(GOLD if _gold else COLOR, 0.45 * a)
	_shell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shell_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shell_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for up in [true, false]:
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0 if up else 0.22
		cm.bottom_radius = 0.22 if up else 0.0
		cm.height = 0.38 if up else 0.28
		cm.radial_segments = 6
		cm.rings = 1
		cone.mesh = cm
		cone.material_override = _shell_mat
		cone.position = Vector3(0, cm.height * 0.5 if up else -cm.height * 0.5, 0)
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_body.add_child(cone)
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	core.mesh = sm
	_core_mat = StandardMaterial3D.new()
	_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.material_override = _core_mat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(core)
	# My prism target: a thin ring under it.
	_mark = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.32
	tm.outer_radius = 0.36
	_mark.mesh = tm
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.45, 1.0, 0.6, 0.8)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mark.material_override = mm
	_mark.position = Vector3(0, -0.3, 0)
	_mark.visible = false
	add_child(_mark)
	_set_fill(_fill, _marked)

func _set_fill(fill: float, marked: bool) -> void:
	_fill = clampf(fill, 0.0, 1.0)
	_marked = marked
	if _core_mat:
		var a := 1.0 if _mine else 0.35
		var base := GOLD if _gold else COLOR
		_core_mat.albedo_color = Color(base.lerp(GOLD_FULL if _gold else FULL_COLOR, _fill), (0.2 + 0.8 * _fill) * a)
	if _mark:
		_mark.visible = marked and _mine

func _appear() -> void:
	scale = Vector3.ONE * 0.01
	create_tween().tween_property(self, "scale", Vector3.ONE, FLICKER)

## Flicker out here, flicker in at `to`.
func _flicker_to(to: Vector3) -> void:
	_home = to
	_moving = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.05, 1.6, 0.05), FLICKER * 0.5)
	tw.tween_callback(func():
		global_position = to)
	tw.tween_property(self, "scale", Vector3.ONE, FLICKER * 0.5)
	tw.tween_callback(func(): _moving = false)

func _fade() -> void:
	remove_from_group(GROUP)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, FLICKER)
	tw.tween_callback(queue_free)

func _shatter() -> void:
	remove_from_group(GROUP)
	# Shards fly out and fade.
	for i in 8:
		var shard := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.12, 0.05)
		shard.mesh = bm
		shard.material_override = _shell_mat
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shard)
		var a := TAU * i / 8.0
		var out := Vector3(cos(a), randf_range(-0.3, 0.6), sin(a)) * randf_range(0.8, 1.4)
		create_tween().tween_property(shard, "position", out, 0.4).set_ease(Tween.EASE_OUT)
	_body.visible = false
	_mark.visible = false
	var tw := create_tween()
	tw.tween_interval(0.45)
	tw.tween_callback(queue_free)

func _process(delta: float) -> void:
	_t += delta
	if _body:
		_body.rotation.y += SPIN * delta * (1.0 + _fill)
	if not _moving and is_in_group(GROUP):
		global_position = _home + Vector3(0, sin(_t * 2.0) * BOB, 0)
