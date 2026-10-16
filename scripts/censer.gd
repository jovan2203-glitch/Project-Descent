extends Node3D

# The Censer (Holy tank): a censer of light hanging at a character's off hand
# side on a chain of light, with a faint barrier of light around the character.
# Only a picture: the rules are in player.gd ("Holy tank: the Censer"). One node
# per character (a child of the body named "Censer"), made by show_on(). It
# glows brighter the more Incense there is, flashes when a hit is blocked, and
# can rise over a spot for a while (Raise the Censer). A party member's censer
# is shown on that player's puppet (Net "censer" fx).
# Swap-ready: everything here is built from simple meshes in this one script;
# a real model can replace _build_censer() without touching the gameplay code.
# Usage: const Censer = preload("res://scripts/censer.gd")

const NODE_NAME := "Censer"
const GOLD := Color(0.95, 0.8, 0.45)
const LIGHT := Color(1.0, 0.95, 0.78)
## Where the chain hangs from, relative to the character (its left side; characters face -Z).
const HANG := Vector3(-0.42, 1.05, 0.05)
const CHAIN_LENGTH := 0.45
const SWING := 0.35            # radians the censer swings to each side
const SWING_SPEED := 2.2
const BARRIER_RADIUS := 1.05
const BARRIER_ALPHA := 0.12    # at a full censer
const FADE_TIME := 0.4
const MAX_STACKS := 100.0

var _pivot: Node3D            # the chain's top; it swings
var _chain: MeshInstance3D
var _vessel: Node3D           # the censer itself (leaves the pivot while raised)
var _glow_mat: StandardMaterial3D
var _light: OmniLight3D
var _barrier_mat: StandardMaterial3D
var _barrier: MeshInstance3D
var _beam: MeshInstance3D     # rays falling from a raised censer
var _stacks := 0
var _shown := 0.0             # 0..1, fades in and out
var _on := false
var _flash := 0.0
var _t := 0.0
var _raised_until := 0.0

## Show the censer on `body` (`on` = false: it fades away) with `stacks` Incense.
static func show_on(body: Node3D, stacks: int, on: bool) -> void:
	var node := _node_of(body, on)
	if node:
		node.set_state(stacks, on)

## A blocked hit: the barrier flashes.
static func flash(body: Node3D) -> void:
	var node := _node_of(body, false)
	if node:
		node._flash = 1.0

## Raise the Censer: the censer rises over `point` for `time` seconds, then comes back.
static func raise(body: Node3D, point: Vector3, height: float, time: float, radius: float) -> void:
	var node := _node_of(body, true)
	if node:
		node._raise(point, height, time, radius)

static func _node_of(body: Node3D, make: bool) -> Node:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return null
	var node := body.get_node_or_null(NODE_NAME)
	if node == null and make:
		node = Node3D.new()
		node.name = NODE_NAME
		node.set_script(load("res://scripts/censer.gd"))
		body.add_child(node)
	return node

func _ready() -> void:
	_pivot = Node3D.new()
	_pivot.position = HANG
	add_child(_pivot)
	_chain = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.012
	cm.height = CHAIN_LENGTH
	cm.radial_segments = 6
	_chain.mesh = cm
	_chain.material_override = _unshaded(Color(LIGHT, 0.85))
	_chain.position = Vector3(0, -CHAIN_LENGTH * 0.5, 0)
	_chain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.add_child(_chain)
	_vessel = _build_censer()
	_vessel.position = Vector3(0, -CHAIN_LENGTH - 0.1, 0)
	_pivot.add_child(_vessel)
	# The barrier of light around the character.
	_barrier = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = BARRIER_RADIUS
	sm.height = BARRIER_RADIUS * 2.0
	sm.radial_segments = 24
	sm.rings = 12
	_barrier.mesh = sm
	_barrier_mat = _unshaded(Color(LIGHT, 0.0))
	_barrier_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_barrier.material_override = _barrier_mat
	_barrier.position = Vector3(0, 0.95, 0)
	_barrier.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_barrier)
	scale = Vector3.ONE * 0.001

## The censer: a round gold body under a domed lid, with light inside.
func _build_censer() -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.11
	bm.height = 0.16
	body.mesh = bm
	var metal := StandardMaterial3D.new()
	metal.albedo_color = GOLD
	metal.metallic = 0.8
	metal.roughness = 0.35
	metal.emission_enabled = true
	metal.emission = GOLD * 0.35
	body.material_override = metal
	root.add_child(body)
	var lid := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.02
	lm.bottom_radius = 0.1
	lm.height = 0.1
	lid.mesh = lm
	lid.material_override = metal
	lid.position = Vector3(0, 0.1, 0)
	root.add_child(lid)
	var glow := MeshInstance3D.new()
	var gm := SphereMesh.new()
	gm.radius = 0.07
	gm.height = 0.14
	glow.mesh = gm
	_glow_mat = _unshaded(LIGHT)
	glow.material_override = _glow_mat
	glow.position = Vector3(0, 0.02, 0)
	root.add_child(glow)
	_light = OmniLight3D.new()
	_light.light_color = LIGHT
	_light.omni_range = 3.0
	_light.shadow_enabled = false
	root.add_child(_light)
	return root

static func _unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func set_state(stacks: int, on: bool) -> void:
	_stacks = clampi(stacks, 0, int(MAX_STACKS))
	_on = on

func _raise(point: Vector3, height: float, time: float, radius: float) -> void:
	_raised_until = Time.get_ticks_msec() / 1000.0 + time
	_vessel.top_level = true
	var from := _vessel.global_position
	_vessel.global_position = from
	var tw := create_tween()
	tw.tween_property(_vessel, "global_position", point + Vector3(0, height, 0), 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_chain.visible = false
	if _beam == null:
		_beam = MeshInstance3D.new()
		_beam.material_override = _unshaded(Color(LIGHT, 0.18))
		_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_beam.top_level = true
		add_child(_beam)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.15
	cone.bottom_radius = radius * 0.5
	cone.height = height
	_beam.mesh = cone
	_beam.global_position = point + Vector3(0, height * 0.5, 0)
	_beam.visible = true

func _end_raise() -> void:
	_raised_until = 0.0
	if _beam:
		_beam.visible = false
	var tw := create_tween()
	tw.tween_property(_vessel, "global_position", _pivot.global_position + Vector3(0, -CHAIN_LENGTH - 0.1, 0), 0.35)
	tw.tween_callback(func():
		_vessel.top_level = false
		_vessel.position = Vector3(0, -CHAIN_LENGTH - 0.1, 0)
		_chain.visible = true)

func _process(delta: float) -> void:
	_t += delta
	var now := Time.get_ticks_msec() / 1000.0
	if _raised_until > 0.0 and now >= _raised_until:
		_end_raise()
	var want := 1.0 if _on else 0.0
	_shown = move_toward(_shown, want, delta / FADE_TIME)
	if _shown <= 0.0 and not _on:
		queue_free()
		return
	scale = Vector3.ONE * maxf(_shown, 0.001)
	var full := float(_stacks) / MAX_STACKS
	var raised := _raised_until > 0.0
	_pivot.rotation.z = sin(_t * SWING_SPEED) * SWING
	_pivot.rotation.x = sin(_t * SWING_SPEED * 0.5) * SWING * 0.3
	# Dim and silent when empty, bright white-gold when full.
	_glow_mat.albedo_color = Color(LIGHT, 0.25 + 0.75 * full)
	_light.light_energy = 0.15 + 1.6 * full + (0.8 if raised else 0.0)
	_vessel.scale = Vector3.ONE * (1.0 + 0.08 * sin(_t * 3.0) * full)
	_flash = move_toward(_flash, 0.0, delta * 3.0)
	var barrier := 0.0 if raised else BARRIER_ALPHA * full
	_barrier_mat.albedo_color = Color(LIGHT, clampf(barrier + _flash * 0.35, 0.0, 0.6))
	_barrier.visible = _barrier_mat.albedo_color.a > 0.005
