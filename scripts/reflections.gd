extends Node3D

# Reflections (Arcane tank): see-through copies of a character standing around
# it. They are only a picture: the rules are in player.gd ("Arcane tank"). One
# node per character (a child of the body named "Reflections"), made by
# show_on(). The copies are duplicates of the body's "Model", so they wear what
# it wears and move the way it moves. A party member's Reflections are shown on
# that player's puppet (Net "reflections" fx).
# Usage: const Reflections = preload("res://scripts/reflections.gd")

const SHADER: Shader = preload("res://shaders/reflection.gdshader")
const NODE_NAME := "Reflections"

## Width of a character (its hitbox), and how much of it a Reflection overlaps.
const BODY_WIDTH := 0.8
const OVERLAP := 0.2
## How far a Reflection stands from the character's centre: to the side, and in
## front / behind (a little closer there: a body is thinner than it is wide).
const SIDE := BODY_WIDTH * (1.0 - OVERLAP)
const DEPTH := SIDE * 0.8
## Where each Reflection stands, in the order they appear: left, right, front,
## back (characters face -Z).
const SPOTS := [Vector3(-SIDE, 0.0, 0.0), Vector3(SIDE, 0.0, 0.0), Vector3(0.0, 0.0, -DEPTH), Vector3(0.0, 0.0, DEPTH)]

const TINT := Color(0.7, 0.42, 1.0)
const APPEAR_TIME := 0.25
const SHATTER_TIME := 0.3
## Seconds a copy's animation may be off the character's before it is put right.
const DRIFT := 0.1

## One entry per Reflection shown: {"holder": Node3D, "anim": AnimationPlayer, "mat": ShaderMaterial}
var _copies: Array = []
var _src_anim: AnimationPlayer

## Show `count` Reflections around `body` (0 = none). Makes the node on first use.
static func show_on(body: Node3D, count: int) -> void:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return
	var node := body.get_node_or_null(NODE_NAME)
	if node == null:
		if count <= 0:
			return
		node = Node3D.new()
		node.name = NODE_NAME
		node.set_script(load("res://scripts/reflections.gd"))
		body.add_child(node)
	node.set_count(count)

## The spot of Reflection number `index` (0 = the first), relative to the character.
static func spot(index: int) -> Vector3:
	return SPOTS[clampi(index, 0, SPOTS.size() - 1)]

## The purple glass every Reflection (and the Decoy) is made of. Each copy has
## its own, so each can fade by itself.
static func glass_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("tint", TINT)
	return m

## A see-through copy of a character's `model` made of `mat`. It has the
## animations the model has (follow() keeps the two in step).
static func make_copy(model: Node3D, mat: Material) -> Node3D:
	var copy := model.duplicate() as Node3D
	copy.name = "Copy"
	for m in copy.find_children("*", "MeshInstance3D", true, false):
		var mesh := m as MeshInstance3D
		mesh.material_override = mat
		mesh.material_overlay = null
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (A light a model may carry is not copied: an image lights nothing.)
	for extra in copy.find_children("*", "Light3D", true, false):
		extra.get_parent().remove_child(extra)
		extra.free()
	var src := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var dst := copy.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if src != null and dst != null:
		for lib in src.get_animation_library_list():
			if not dst.has_animation_library(lib):
				dst.add_animation_library(lib, src.get_animation_library(lib))
	return copy

## Make `dst` play what `src` plays, at the same point of it.
static func follow(src: AnimationPlayer, dst: AnimationPlayer) -> void:
	var cur := str(src.current_animation)
	if cur == "" or not dst.has_animation(cur):
		return
	if not src.is_playing():
		if dst.is_playing():
			dst.pause()
		return
	if str(dst.current_animation) != cur or not dst.is_playing():
		dst.play(cur, 0.15, src.get_playing_speed())
	var at := src.current_animation_position
	if absf(dst.current_animation_position - at) > DRIFT:
		dst.seek(at, true)

func _ready() -> void:
	set_process(false)

## How many Reflections are shown right now.
func count() -> int:
	return _copies.size()

## Show exactly `n`: new ones step out of the character, the ones too many shatter.
func set_count(n: int) -> void:
	n = clampi(n, 0, SPOTS.size())
	while _copies.size() > n:
		_shatter(_copies.pop_back())
	while _copies.size() < n:
		var made := _add(spot(_copies.size()))
		if made.is_empty():
			break
		_copies.append(made)
	set_process(not _copies.is_empty())

func _model() -> Node3D:
	var body := get_parent()
	return body.get_node_or_null("Model") as Node3D if body else null

func _add(at: Vector3) -> Dictionary:
	var model := _model()
	if model == null:
		return {}
	var holder := Node3D.new()
	add_child(holder)
	var mat := glass_material()
	var copy := make_copy(model, mat)
	holder.add_child(copy)
	# It steps out of the character to its place.
	mat.set_shader_parameter("fade", 0.0)
	var t := holder.create_tween().set_parallel(true)
	t.tween_property(holder, "position", at, APPEAR_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 0.0, 1.0, APPEAR_TIME)
	return {"holder": holder, "anim": copy.find_child("AnimationPlayer", true, false) as AnimationPlayer, "mat": mat}

## A Reflection goes: it swells, whitens and fades.
func _shatter(c: Dictionary) -> void:
	var holder: Node3D = c.get("holder")
	var mat: ShaderMaterial = c.get("mat")
	if holder == null or not is_instance_valid(holder):
		return
	if mat == null or not holder.is_inside_tree():
		holder.queue_free()
		return
	var t := holder.create_tween().set_parallel(true)
	t.tween_property(holder, "scale", Vector3.ONE * 1.25, SHATTER_TIME).set_ease(Tween.EASE_OUT)
	t.tween_method(func(v: float): mat.set_shader_parameter("flash", v), 1.0, 0.0, SHATTER_TIME)
	t.tween_method(func(v: float): mat.set_shader_parameter("fade", v), 1.0, 0.0, SHATTER_TIME)
	t.chain().tween_callback(holder.queue_free)

func _process(_delta: float) -> void:
	if _src_anim == null or not is_instance_valid(_src_anim):
		var model := _model()
		_src_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer if model else null
		if _src_anim == null:
			return
	for c in _copies:
		var a: AnimationPlayer = c.get("anim")
		if a != null and is_instance_valid(a):
			follow(_src_anim, a)
