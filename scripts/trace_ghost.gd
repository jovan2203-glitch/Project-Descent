extends Node3D

# A Trace's ghost (Arcane melee, Encore): a see-through copy of the character
# that steps out of them, runs straight through their target and fades out
# behind it. One ghost per Trace replayed, a moment apart, each on a lane of its
# own so their paths cross in the target.
# Only a picture: the replayed damage is dealt by player.gd (_encore), timed to
# the moment each ghost reaches the target (hit_time()). A party member's
# ghosts are shown from that player's puppet (Net "ghosts" fx).
# Usage: const TraceGhost = preload("res://scripts/trace_ghost.gd")

const Reflections = preload("res://scripts/reflections.gd")

## Lighter than a Reflection: it is moving, and gone in a blink.
const TINT := Color(0.84, 0.64, 1.0)
const SPEED := 16.0          # metres per second
const OVERSHOOT := 3.0       # metres it keeps running past the target
const STAGGER := 0.1         # seconds between one ghost setting off and the next
const LANE := 0.7            # metres between two ghosts' starting spots, side by side
const APPEAR_TIME := 0.06
const FADE_TIME := 0.18
const FLASH_TIME := 0.16
const RUN_ANIM := "player/walk"
const RUN_ANIM_SPEED := 2.4
const LEAN := 0.22           # radians it leans into its run
## The most ghosts one Encore shows (it never holds more Traces than this).
const MAX_GHOSTS := 8

var _mat: ShaderMaterial

## Seconds after Encore that ghost number `index` (0 = the first) sets off.
static func delay_of(index: int) -> float:
	return maxi(index, 0) * STAGGER

## Where ghost `index` of `count` starts: beside the character at `from`, on its
## own lane across the line to `to` (the middle one starts where they stand).
static func start_of(from: Vector3, to: Vector3, index: int, count: int) -> Vector3:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	if flat.length() < 0.05:
		return from
	var dir := flat.normalized()
	var side := Vector3(-dir.z, 0.0, dir.x)
	return from + side * ((index - (maxi(count, 1) - 1) / 2.0) * LANE)

## Seconds after Encore that ghost `index` of `count` reaches the target at
## `to`: when its hit lands.
static func hit_time(from: Vector3, to: Vector3, index: int, count: int) -> float:
	var start := start_of(from, to, index, count)
	return delay_of(index) + Vector2(to.x - start.x, to.z - start.z).length() / SPEED

## Send `count` ghosts of `whose` from `from` through `to` (both at the height
## of a character's centre).
static func run(scene: Node, whose: Node3D, from: Vector3, to: Vector3, count: int) -> void:
	if scene == null or not scene.is_inside_tree() or whose == null or not is_instance_valid(whose):
		return
	var n := clampi(count, 0, MAX_GHOSTS)
	for i in n:
		var g := Node3D.new()
		g.set_script(load("res://scripts/trace_ghost.gd"))
		scene.add_child(g)
		g.go(whose, start_of(from, to, i, n), to, delay_of(i), -whose.global_transform.basis.z)

## Run from `start` through `through` after `delay` seconds, then go.
## `facing` = which way to run if the two are the same spot.
func go(whose: Node3D, start: Vector3, through: Vector3, delay: float, facing: Vector3) -> void:
	var flat := Vector3(through.x - start.x, 0.0, through.z - start.z)
	var dist := flat.length()
	var dir := flat / dist if dist > 0.05 else Vector3(facing.x, 0.0, facing.z).normalized()
	if dir.length() < 0.5:
		dir = Vector3.FORWARD
	var end := through + dir * OVERSHOOT
	global_position = start
	rotation = Vector3(-LEAN, atan2(-dir.x, -dir.z), 0.0)
	_build(whose)
	visible = false
	var wait := maxf(delay, 0.001)
	var run_time := (dist + OVERSHOOT) / SPEED
	var move := create_tween()
	move.tween_interval(wait)
	move.tween_callback(func(): visible = true)
	move.tween_property(self, "global_position", end, run_time)
	move.tween_callback(queue_free)
	# It steps out of the character, and thins out again once it is through.
	var fade := create_tween()
	fade.tween_interval(wait)
	fade.tween_method(_set_fade, 0.0, 1.0, APPEAR_TIME)
	fade.tween_interval(maxf(run_time - APPEAR_TIME - FADE_TIME, 0.001))
	fade.tween_method(_set_fade, 1.0, 0.0, FADE_TIME)
	# It flares white as it passes through the target: that is when its hit lands.
	var flare := create_tween()
	flare.tween_interval(wait + dist / SPEED)
	flare.tween_method(_set_flash, 1.0, 0.0, FLASH_TIME)

func _build(whose: Node3D) -> void:
	_mat = Reflections.glass_material()
	_mat.set_shader_parameter("tint", TINT)
	_mat.set_shader_parameter("glass", 0.6)
	_mat.set_shader_parameter("blur", 2.0)
	_mat.set_shader_parameter("fade", 0.0)
	var model := whose.get_node_or_null("Model") as Node3D
	if model != null:
		var copy := Reflections.make_copy(model, _mat)
		add_child(copy)
		copy.rotation.x = 0.0   # (upright, whatever its owner is doing)
		var anim := copy.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim != null and anim.has_animation(RUN_ANIM):
			anim.play(RUN_ANIM, 0.0, RUN_ANIM_SPEED)
		return
	# No model to copy (a character that is still loading): a plain figure.
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.7
	body.mesh = cap
	body.material_override = _mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)

func _set_fade(v: float) -> void:
	if _mat:
		_mat.set_shader_parameter("fade", v)

func _set_flash(v: float) -> void:
	if _mat:
		_mat.set_shader_parameter("flash", v)
