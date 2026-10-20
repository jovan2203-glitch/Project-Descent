extends Node3D

# The Brawler's Chain (Martial tank): up to three glowing orbs floating over a
# character's back, left to right in the order the strikes went in: Punch red,
# Kick green, Elbow blue, Catch white. When the Chain makes its move the orbs
# burst (gold when its three strikes were all different); a Chain that runs out
# fades. Fighting Style shows as wrapped glowing fists (Bare Hands) or not at all.
# Only a picture: the rules are in scripts/player/martial_brawler.gd. One node per
# character (a child of the body named "BrawlerOrbs"), made by show_on(). A party
# member's orbs show on that player's puppet (Net "brawler" fx).
# Swap-ready: the orbs and wraps are built in _orb() / _wrap() from simple meshes.
# Usage: const BrawlerOrbs = preload("res://scripts/brawler_orbs.gd")

const BrawlerIcons = preload("res://scripts/ui/brawler_icons.gd")
const NODE_NAME := "BrawlerOrbs"
## The row over the back (characters face -Z; +Z is behind them).
const ROW_CENTRE := Vector3(0, 1.75, 0.35)
const ROW_GAP := 0.32
const ORB_RADIUS := 0.09
const BOB := 0.03
## Where the wrapped fists glow (Bare Hands).
const HANDS := [Vector3(-0.38, 1.0, -0.15), Vector3(0.38, 1.0, -0.15)]

var _inputs: Array[String] = []
var _orbs: Array[MeshInstance3D] = []
var _wraps: Array[MeshInstance3D] = []
var _t := 0.0

## Show the Chain on `body`: `inputs` in order ("punch", "brawlkick", "elbow", "catch"),
## `bare` = Bare Hands, `out` = false takes it all away.
static func show_on(body: Node3D, inputs: Array, bare: bool, out: bool = true) -> void:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return
	var node := body.get_node_or_null(NODE_NAME)
	if not out:
		if node:
			node.queue_free()
		return
	if node == null:
		node = Node3D.new()
		node.name = NODE_NAME
		node.set_script(load("res://scripts/brawler_orbs.gd"))
		body.add_child(node)
	node.set_state(inputs, bare)

## The Chain made its move: the orbs burst (gold for the strong move).
static func burst(body: Node3D, inputs: Array, gold: bool) -> void:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return
	var scene := body.get_tree().current_scene
	for i in inputs.size():
		var col: Color = BrawlerIcons.GOLD if gold else color_of(str(inputs[i]))
		var at := body.global_position + body.global_basis * _slot(i, inputs.size())
		var spark := MeshInstance3D.new()
		spark.mesh = _sphere(ORB_RADIUS)
		spark.material_override = _glow_mat(col, 3.0)
		spark.top_level = true
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		scene.add_child(spark)
		spark.global_position = at
		var t := spark.create_tween()
		t.set_parallel(true)
		t.tween_property(spark, "scale", Vector3.ONE * 3.5, 0.3).set_ease(Tween.EASE_OUT)
		t.tween_property(spark, "transparency", 1.0, 0.3)
		t.chain().tween_callback(spark.queue_free)

## A strike's colour (the same as its icon).
static func color_of(input: String) -> Color:
	return BrawlerIcons.COLORS.get(input, Color(0.85, 0.85, 0.9))

static func _slot(i: int, n: int) -> Vector3:
	return ROW_CENTRE + Vector3((float(i) - float(maxi(n, 1) - 1) * 0.5) * ROW_GAP, 0, 0)

func set_state(inputs: Array, bare: bool) -> void:
	var ids: Array[String] = []
	for x in inputs:
		ids.append(str(x))
	_inputs = ids
	while _orbs.size() < _inputs.size():
		var o := _orb()
		add_child(o)
		_orbs.append(o)
	while _orbs.size() > _inputs.size():
		_orbs.pop_back().queue_free()
	for i in _orbs.size():
		_orbs[i].material_override = _glow_mat(color_of(_inputs[i]), 2.2)
	if bare and _wraps.is_empty():
		for at in HANDS:
			var w := _wrap()
			w.position = at
			add_child(w)
			_wraps.append(w)
	elif not bare:
		for w in _wraps:
			w.queue_free()
		_wraps.clear()
	set_process(not _orbs.is_empty())

func _process(delta: float) -> void:
	_t += delta
	for i in _orbs.size():
		_orbs[i].position = _slot(i, _orbs.size()) + Vector3(0, sin(_t * 3.0 + i) * BOB, 0)

func _orb() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = _sphere(ORB_RADIUS)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

func _wrap() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = _sphere(0.07)
	m.material_override = _glow_mat(BrawlerIcons.WRAP, 1.2)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s

static func _glow_mat(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m
