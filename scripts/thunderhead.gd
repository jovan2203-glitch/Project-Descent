extends Node3D

# Thunderhead: a storm cloud over a circle for `duration` seconds. Every `tick`
# seconds it strikes ONE random enemy standing in the circle: `damage` (a
# coefficient) as periodic Lightning damage from `source`. The first strike
# comes as the cloud forms.
# With damage 0 it is only the picture (a party member's cloud): the damage
# comes from its caster's machine, and the bolts drawn here are this machine's
# own picks.

const Combat = preload("res://scripts/combat_utils.gd")

const CLOUD := Color(0.2, 0.22, 0.32)
const GLOW := Color(0.45, 0.55, 1.0)
const BOLT := Color(0.92, 0.95, 1.0)
## Height of the cloud above the ground.
const CLOUD_HEIGHT := 4.5
const FADE_TIME := 0.4
## Seconds a bolt stays on screen.
const BOLT_TIME := 0.15

var radius := 5.0
var duration := 8.0
var tick := 1.0
var damage := 0.0
var tags := PackedStringArray(["Lightning", "Spell", "AoE"])
var source: Node = null   # the caster; damage is theirs
## Made by my free cast (Rune of the Wild Page): its hits are echoes too.
var echo := false
## Name of its strikes in logs and meters ("dot_<effect_id>").
var effect_id := "thunderhead"

var _age := 0.0
var _tick_t := 0.0
var _ending := false
var _mats: Array[StandardMaterial3D] = []
var _bolt_mat: StandardMaterial3D
var _light: OmniLight3D

static func spawn(scene: Node, at: Vector3, reach: float, time: float, every: float, src: Node, dmg: float) -> Node3D:
	var n := Node3D.new()
	n.set_script(load("res://scripts/thunderhead.gd"))
	n.radius = reach
	n.duration = time
	n.tick = maxf(every, 0.1)
	n.source = src
	n.damage = dmg
	scene.add_child(n)
	n.global_position = at
	return n

## Is `point` under a cloud of radius `reach` centred on `centre`, with `pad`
## (the enemy's hitbox radius) to spare? Height is ignored.
static func inside(centre: Vector3, reach: float, point: Vector3, pad: float = 0.0) -> bool:
	return Vector2(point.x - centre.x, point.z - centre.z).length() <= reach + pad

## Strikes a cloud lasting `time` makes, one every `every` seconds (the first at once).
static func strikes(time: float, every: float) -> int:
	return int(ceil(maxf(time, 0.0) / maxf(every, 0.1)))

func _mat(c: Color, energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = energy
	_mats.append(m)
	return m

func _ready() -> void:
	# The area it covers: a faint disc on the ground.
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = radius
	disc_mesh.bottom_radius = radius
	disc_mesh.height = 0.02
	disc.mesh = disc_mesh
	disc.position.y = 0.04
	disc.material_override = _mat(Color(GLOW, 0.14))
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	# The cloud: a few flattened puffs.
	var cloud_mat := _mat(Color(CLOUD, 0.85))
	var puff := SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	for p in [Vector3(0, 0, 0), Vector3(0.45, 0.15, 0.2), Vector3(-0.45, 0.1, -0.15), Vector3(0.1, -0.1, -0.5), Vector3(-0.15, 0.05, 0.5)]:
		var m := MeshInstance3D.new()
		m.mesh = puff
		m.material_override = cloud_mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = Vector3(p.x * radius, CLOUD_HEIGHT + p.y, p.z * radius)
		m.scale = Vector3(radius * 0.55, 0.7, radius * 0.5)
		add_child(m)
	_bolt_mat = _mat(BOLT, 3.0)
	# One cool light under the cloud, no shadows (cheap).
	_light = OmniLight3D.new()
	_light.light_color = GLOW
	_light.light_energy = 1.2
	_light.omni_range = radius + 3.0
	_light.shadow_enabled = false
	_light.position.y = 2.0
	add_child(_light)
	# The first strike lands as the cloud forms. Deferred: whoever spawned it puts
	# it in place right after adding it to the scene.
	_strike.call_deferred()

func _process(delta: float) -> void:
	if _ending:
		return
	_age += delta
	if _age >= duration:
		vanish()
		return
	_tick_t += delta
	if _tick_t >= tick:
		_tick_t -= tick
		_strike()

## The cloud clears.
func vanish() -> void:
	if _ending:
		return
	_ending = true
	var t := create_tween()
	t.set_parallel(true)
	for m in _mats:
		t.tween_property(m, "albedo_color:a", 0.0, FADE_TIME)
	t.tween_property(_light, "light_energy", 0.0, FADE_TIME)
	t.chain().tween_callback(queue_free)

## Enemies standing under the cloud.
func _targets() -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node3D and e.is_alive() and inside(global_position, radius, e.global_position, Combat.hitbox_radius(e)):
			out.append(e)
	return out

func _strike() -> void:
	if _ending:
		return
	var under := _targets()
	if under.is_empty():
		return
	var e: Node3D = under.pick_random()
	_bolt_to(e.global_position)
	if damage <= 0.0 or source == null or not is_instance_valid(source):
		return
	var cs := get_node_or_null("/root/CombatSystem")
	if cs:
		Combat.run_as(source, echo, func(): cs.deal_dot(source, e, damage, "lightning", effect_id, tags))

## A short-lived bolt from the cloud straight down onto `at`.
func _bolt_to(at: Vector3) -> void:
	if get_parent() == null:
		return
	var top := global_position.y + CLOUD_HEIGHT
	var length := maxf(top - at.y, 0.5)
	var bolt := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.14, length, 0.14)
	bolt.mesh = box
	bolt.material_override = _bolt_mat
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(bolt)
	bolt.global_position = Vector3(at.x, at.y + length * 0.5, at.z)
	get_tree().create_timer(BOLT_TIME).timeout.connect(bolt.queue_free)

func _enter_tree() -> void:
	echo = Combat.echoing(source)   # (asked each time it is made: pooled ones come back)
