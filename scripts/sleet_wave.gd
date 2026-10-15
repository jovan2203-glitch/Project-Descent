extends Node3D

# Sleetwave: a wall of sleet that travels `length` metres in a straight line from
# where it was cast. Every enemy it passes is hit once by `source` (damage and
# Chilled come from the Sleetwave ability; `damage` is the coefficient per enemy,
# already shared out for the AoE cap). With no source it is only the picture
# (what the rest of the party sees: the caster's machine deals the damage).

const Combat = preload("res://scripts/combat_utils.gd")

var length := 12.0     # metres it travels
var width := 3.0       # metres across
var speed := 24.0      # metres per second
var damage := 0.0
var ability_id := "sleetwave"
var source: Node = null
var dir := Vector3.FORWARD

const SLEET := Color(0.72, 0.9, 1.0)
const FADE_TIME := 0.35

var _origin := Vector3.ZERO
var _travelled := 0.0
var _hit := {}          # enemy instance id -> true (each enemy once)
var _ending := false
var _wall: MeshInstance3D
var _trail: MeshInstance3D
var _wall_mat: StandardMaterial3D
var _trail_mat: StandardMaterial3D

## Where `point` is relative to a line from `origin` along `direction` (height
## ignored): x = metres along it, y = metres off to its side.
static func along_side(origin: Vector3, direction: Vector3, point: Vector3) -> Vector2:
	var d := Vector2(direction.x, direction.z).normalized()
	var p := Vector2(point.x - origin.x, point.z - origin.z)
	return Vector2(p.dot(d), absf(p.dot(d.orthogonal())))

## Is `point` (a body `hitbox` metres wide) inside the strip the wave covers?
static func in_path(origin: Vector3, direction: Vector3, point: Vector3, strip_length: float, strip_width: float,
		hitbox: float = 0.0) -> bool:
	var a := along_side(origin, direction, point)
	return a.x + hitbox >= 0.0 and a.x - hitbox <= strip_length and a.y - hitbox <= strip_width * 0.5

## Has a wave that has travelled `travelled` metres reached `point` yet?
static func reached(origin: Vector3, direction: Vector3, point: Vector3, travelled: float, hitbox: float = 0.0) -> bool:
	return along_side(origin, direction, point).x - hitbox <= travelled

## Seconds the wave takes to cross its whole length.
static func travel_time(strip_length: float, metres_per_second: float) -> float:
	return strip_length / maxf(metres_per_second, 0.1)

## Start a wave at `origin` (ground level) heading along `direction`.
static func spawn(scene: Node, origin: Vector3, direction: Vector3, who: Node, coef: float,
		strip_length: float, strip_width: float, metres_per_second: float) -> Node3D:
	var w := Node3D.new()
	w.set_script(load("res://scripts/sleet_wave.gd"))
	w.length = strip_length
	w.width = strip_width
	w.speed = metres_per_second
	w.damage = coef
	w.source = who
	var flat := Vector3(direction.x, 0.0, direction.z)
	w.dir = flat.normalized() if flat.length() > 0.001 else Vector3.FORWARD
	scene.add_child(w)
	w.global_position = origin
	w._origin = origin
	w.rotation.y = atan2(-w.dir.x, -w.dir.z)   # local -Z = the way it travels
	return w

func _ready() -> void:
	_wall_mat = _material(0.55)
	_wall = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, 1.1, 0.45)
	_wall.mesh = box
	_wall.material_override = _wall_mat
	_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wall.position.y = 0.55
	add_child(_wall)
	# The frosted strip it leaves on the ground.
	_trail_mat = _material(0.3)
	_trail = MeshInstance3D.new()
	var strip := BoxMesh.new()
	strip.size = Vector3(width, 0.03, 1.0)
	_trail.mesh = strip
	_trail.material_override = _trail_mat
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.position.y = 0.04
	_trail.scale.z = 0.01
	add_child(_trail)

static func _material(alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(SLEET, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _process(delta: float) -> void:
	if _ending:
		return
	_travelled = minf(_travelled + speed * delta, length)
	_wall.position.z = -_travelled
	_trail.scale.z = maxf(_travelled, 0.01)
	_trail.position.z = -_travelled * 0.5
	_strike()
	if _travelled >= length:
		_ending = true
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(_wall_mat, "albedo_color:a", 0.0, FADE_TIME)
		t.tween_property(_trail_mat, "albedo_color:a", 0.0, FADE_TIME)
		t.chain().tween_callback(queue_free)

## Hit every enemy the wave has reached and not hit yet.
func _strike() -> void:
	if damage <= 0.0 or source == null or not is_instance_valid(source) or not source.has_method("deal_damage"):
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D) or not e.is_alive() or _hit.has(e.get_instance_id()):
			continue
		var pad: float = Combat.hitbox_radius(e)
		var at: Vector3 = e.global_position
		if not in_path(_origin, dir, at, length, width, pad) or not reached(_origin, dir, at, _travelled, pad):
			continue
		_hit[e.get_instance_id()] = true
		if source.has_method("can_see") and not source.can_see(e):
			continue   # behind a wall
		source.deal_damage(e, damage, ability_id)
