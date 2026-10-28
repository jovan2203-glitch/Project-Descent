extends Node3D

# Homing spell bolt (Frost Bolt, Fireball, enemy firebolts...). Spawned by the
# caster; flies to the target and deals damage on hit.
# Feel (WoW-style): a small flash where it leaves the hand, a spinning, gently
# wobbling core with a soft fading trail, and an impact burst when it lands
# (CombatSystem plays that one on the same frame as the damage number). If the
# target dies on the way, the bolt still flies to where it was and bursts there.

const Combat = preload("res://scripts/combat_utils.gd")
const Balance = preload("res://scripts/balance.gd")
const ImpactFX = preload("res://scripts/core/impact_fx.gd")

@export var speed: float = Balance.BOLT_SPEED
@export var damage: float = 1.0   # coefficient (1.0 = a standard hit)

var target: Node3D
var source: Node = null      # the caster; damage goes through source.deal_damage()
## Made by my free cast (Rune of the Wild Page): its hits are echoes too.
var echo := false
var is_proc := false         # fired by a rune
var ability_id := "frostbolt"
## A note for the caster about THIS bolt, set after spawn() (a Scattered Sigil
## Dart is "scatter"): the caster is told with bolt_tag() around the hit.
var tag := ""
var _trail: CPUParticles3D
var _done := false
var _last_aim := Vector3.ZERO   # where the target was last seen (it may die mid-flight)
var _age := 0.0
var _color := Color(0.35, 0.85, 1.0)

# Pooled (see Pool): visuals are built once in _ready; spawn() resets state.
static func spawn(scene: Node, at: Vector3, tgt: Node3D, src: Node, proc: bool = false,
		id: String = "frostbolt", dmg: float = 1.0) -> Node3D:
	var pool := scene.get_node_or_null("/root/Pool")
	var factory := func():
		var n := Node3D.new()
		n.set_script(load("res://scripts/frost_bolt.gd"))
		return n
	var bolt: Node3D = pool.acquire("frost_bolt", factory) if pool else factory.call()
	bolt.target = tgt
	bolt.source = src
	bolt.is_proc = proc
	bolt.ability_id = id
	bolt.damage = dmg
	bolt.tag = ""
	bolt.speed = Balance.BOLT_SPEED
	bolt._done = false
	bolt._age = 0.0
	scene.add_child(bolt)
	bolt.global_position = at
	bolt._last_aim = tgt.global_position + Vector3(0, 0.3, 0) if is_instance_valid(tgt) else at
	bolt._tint(id)
	if bolt._trail:
		bolt._trail.restart()
	# Launch flash where it leaves the hand (rune procs launch quietly). Deferred,
	# so an enemy caster's recolor (enemy._tint_bolt) is already applied.
	if not proc:
		bolt._launch_flash.call_deferred(scene, at)
	# Party members see my bolt too (as a harmless visual).
	if src and is_instance_valid(src) and src.is_in_group("player"):
		var net := scene.get_node_or_null("/root/Net")
		if net:
			net.send_fx("bolt", at, tgt, id)
	return bolt

func _launch_flash(scene: Node, at: Vector3) -> void:
	if is_instance_valid(scene):
		ImpactFX.flash(scene, at, _color, 0.6)

func _finish() -> void:
	if _done:
		return
	_done = true
	var pool := get_node_or_null("/root/Pool")
	if pool and has_meta("pool_key"):
		pool.release(self)
	else:
		queue_free()

const FROST_COLOR := Color(0.35, 0.85, 1.0)
var _mat: StandardMaterial3D
var _light: OmniLight3D
var _core: MeshInstance3D
var _trail_mat: StandardMaterial3D

## Spell bolts take their book's color (Fire orange, Shadow purple...); Frost
## and unknown ids keep the icy blue. Re-applied on every spawn (pooled).
## Enemy casters recolor it afterwards (enemy._tint_bolt), which set_color() handles.
func _tint(id: String) -> void:
	if id == "frostfirebolt":
		# Icy core, burning trail.
		var fire: Color = preload("res://scripts/categories.gd").color("fire")
		set_color(FROST_COLOR)
		if _trail:
			_trail.color_ramp = _trail_ramp(fire)
		if _light:
			_light.light_color = FROST_COLOR.lerp(fire, 0.5)
		return
	var c := FROST_COLOR
	var cat: String = preload("res://scripts/abilities.gd").category_of(id)
	if cat != "" and cat != "frost":
		c = preload("res://scripts/categories.gd").color(cat)
	set_color(c)

func set_color(c: Color) -> void:
	_color = c
	if _mat == null:
		return
	_mat.albedo_color = c.lightened(0.4)
	_mat.emission = c
	_light.light_color = c
	if _trail:
		_trail.color_ramp = _trail_ramp(c)

static func _trail_ramp(c: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(c.lightened(0.5), 0.9))
	g.set_color(1, Color(c, 0.0))
	return g

func _ready() -> void:
	var core_mat := StandardMaterial3D.new()
	_mat = core_mat
	core_mat.albedo_color = Color(0.7, 0.95, 1.0)
	core_mat.emission_enabled = true
	core_mat.emission = FROST_COLOR
	core_mat.emission_energy_multiplier = 4.0

	# Core: a slightly stretched gem that spins.
	_core = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.14
	sphere.height = 0.36
	sphere.radial_segments = 8
	sphere.rings = 4
	sphere.material = core_mat
	_core.mesh = sphere
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)

	var light := OmniLight3D.new()
	light.light_color = FROST_COLOR
	light.light_energy = 2.2
	light.omni_range = 3.5
	add_child(light)
	_light = light

	# Soft trail: additive puffs that fade and shrink.
	_trail_mat = StandardMaterial3D.new()
	_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_trail_mat.vertex_color_use_as_albedo = true
	_trail_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var trail := CPUParticles3D.new()
	trail.amount = 60
	trail.lifetime = 0.45
	trail.local_coords = false
	trail.gravity = Vector3.ZERO
	trail.direction = Vector3.ZERO
	trail.spread = 180.0
	trail.initial_velocity_min = 0.05
	trail.initial_velocity_max = 0.3
	trail.scale_amount_min = 0.8
	trail.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	trail.scale_amount_curve = curve
	var quad := QuadMesh.new()
	quad.size = Vector2(0.2, 0.2)
	trail.mesh = quad
	trail.material_override = _trail_mat
	trail.color_ramp = _trail_ramp(FROST_COLOR)
	add_child(trail)
	_trail = trail
	set_color(_color)

func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	var alive: bool = is_instance_valid(target) and target.is_alive()
	if alive:
		_last_aim = target.global_position + Vector3(0, 0.3, 0)
	var to_target := _last_aim - global_position
	var step := speed * delta
	if to_target.length() <= step + 0.2:
		if alive and is_instance_valid(source) and source.has_method("deal_damage"):
			var tagged := tag != "" and source.has_method("bolt_tag")
			if tagged:
				source.bolt_tag(tag)
			Combat.run_as(source, echo, func(): source.deal_damage(target, damage, ability_id, is_proc))   # impact comes with the hit
			if tagged and is_instance_valid(source):
				source.bolt_tag("")
		else:
			# Visual-only bolt (a party member's), or the target died on the way.
			ImpactFX.spawn_color(get_tree().current_scene, _last_aim, _color, false, ability_id == "frostbolt")
		_finish()
		return
	var next := global_position + to_target.normalized() * step
	# Walls and rock stop the bolt.
	if not Combat.line_of_sight(get_world_3d(), global_position, next):
		ImpactFX.spawn_color(get_tree().current_scene, global_position, _color)
		_finish()
		return
	if (next - global_position).length() > 0.001:
		look_at(next, Vector3.UP)
	global_position = next
	# Spin + a gentle wobble on the core only (the bolt itself flies straight).
	_core.rotation.z = _age * 14.0
	_core.position = Vector3(sin(_age * 23.0) * 0.035, cos(_age * 19.0) * 0.035, 0)
	_core.rotation.x = PI / 2.0   # the gem points along the flight

func _enter_tree() -> void:
	echo = Combat.echoing(source)   # (asked each time it is made: pooled ones come back)
