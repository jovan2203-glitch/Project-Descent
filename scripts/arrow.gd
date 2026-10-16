extends Node3D

# Bow auto-attack projectile: flies at its target, deals damage on hit,
# breaks on walls.

const Combat = preload("res://scripts/combat_utils.gd")
const Balance = preload("res://scripts/balance.gd")
const ImpactFX = preload("res://scripts/core/impact_fx.gd")

var target: Node3D
var damage := 1.0   # coefficient (1.0 = a standard hit)
var source: Node = null      # the player; damage goes through source.deal_damage()
var ability_id := "auto_ranged"
var speed := Balance.ARROW_SPEED
var _done := false

# Pooled (see Pool): visuals are built once in _ready; spawn() resets state.
static func spawn(scene: Node, at: Vector3, tgt: Node3D, src: Node, dmg: float, id: String) -> Node3D:
	var pool := scene.get_node_or_null("/root/Pool")
	var factory := func():
		var n := Node3D.new()
		n.set_script(load("res://scripts/arrow.gd"))
		return n
	var arrow: Node3D = pool.acquire("arrow", factory) if pool else factory.call()
	arrow.target = tgt
	arrow.source = src
	arrow.damage = dmg
	arrow.ability_id = id
	arrow._done = false
	arrow._last_aim = tgt.global_position + Vector3(0, 0.3, 0) if is_instance_valid(tgt) else at
	scene.add_child(arrow)
	arrow.global_position = at
	arrow._tint(id)
	if arrow._streak:
		arrow._streak.restart()
	# Party members see my arrow too (as a harmless visual).
	if src and is_instance_valid(src) and src.is_in_group("player"):
		var net := scene.get_node_or_null("/root/Net")
		if net:
			net.send_fx("arrow", at, tgt, id)
	return arrow

func _finish() -> void:
	if _done:
		return
	_done = true
	var pool := get_node_or_null("/root/Pool")
	if pool and has_meta("pool_key"):
		pool.release(self)
	else:
		queue_free()

var _tip_mat: StandardMaterial3D
var _glow: OmniLight3D

## Elemental arrows (Flaming Arrow, Frost Arrow...) get a glowing tip in their
## book's color; plain arrows keep a steel tip. Re-applied on every spawn (pooled).
func _tint(id: String) -> void:
	if _tip_mat == null:
		return
	_snake_tint(id)
	var cat: String = preload("res://scripts/abilities.gd").category_of(id)
	var magic := cat != "" and cat != "martial"
	if magic:
		var c: Color = preload("res://scripts/categories.gd").color(cat)
		_tip_mat.albedo_color = c.lightened(0.3)
		_tip_mat.emission_enabled = true
		_tip_mat.emission = c
		_tip_mat.emission_energy_multiplier = 3.0
		_glow.light_color = c
		_streak_color(c.lightened(0.3), 0.8)
	else:
		_tip_mat.albedo_color = Color(0.85, 0.87, 0.9)
		_tip_mat.emission_enabled = false
		_streak_color(Color(0.9, 0.92, 1.0), 0.35)
	_glow.visible = magic

func _ready() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.38, 0.22)
	var steel := StandardMaterial3D.new()
	_tip_mat = steel
	_glow = OmniLight3D.new()
	_glow.light_energy = 1.5
	_glow.omni_range = 2.5
	_glow.position.z = -0.38
	_glow.visible = false
	add_child(_glow)
	steel.albedo_color = Color(0.85, 0.87, 0.9)
	steel.metallic = 0.8
	steel.roughness = 0.3
	var fletch := StandardMaterial3D.new()
	fletch.albedo_color = Color(0.95, 0.95, 0.9)

	# Built along -Z (the direction look_at points).
	var shaft := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.018
	cyl.bottom_radius = 0.018
	cyl.height = 0.65
	cyl.material = wood
	shaft.mesh = cyl
	shaft.rotation.x = PI / 2.0
	add_child(shaft)

	var tip := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.045
	cone.height = 0.12
	cone.material = steel
	tip.mesh = cone
	tip.rotation.x = -PI / 2.0
	tip.position.z = -0.38
	add_child(tip)

	var tail := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.09, 0.09, 0.12)
	box.material = fletch
	tail.mesh = box
	tail.position.z = 0.3
	tail.rotation.z = PI / 4.0
	add_child(tail)
	# A faint air streak behind it (tinted for magic arrows in _tint).
	_streak_mat = StandardMaterial3D.new()
	_streak_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_streak_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_streak_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_streak_mat.vertex_color_use_as_albedo = true
	_streak_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_streak = CPUParticles3D.new()
	_streak.amount = 24
	_streak.lifetime = 0.16
	_streak.local_coords = false
	_streak.gravity = Vector3.ZERO
	_streak.initial_velocity_min = 0.0
	_streak.initial_velocity_max = 0.05
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	_streak.mesh = q
	_streak.material_override = _streak_mat
	_streak.position.z = 0.25
	add_child(_streak)
	_build_snake()
	_tint(ability_id)

var _streak: CPUParticles3D
var _streak_mat: StandardMaterial3D

func _streak_color(c: Color, a: float) -> void:
	if _streak == null:
		return
	var g := Gradient.new()
	g.set_color(0, Color(c, a))
	g.set_color(1, Color(c, 0.0))
	_streak.color_ramp = g

func _physics_process(delta: float) -> void:
	if _done:
		return
	var alive: bool = is_instance_valid(target) and target.is_alive()
	if alive:
		_last_aim = target.global_position + Vector3(0, 0.3, 0)
	var aim := _last_aim
	var to_target := aim - global_position
	var step := speed * delta
	if to_target.length() <= step + 0.2:
		if alive and is_instance_valid(source) and source.has_method("deal_damage"):
			source.deal_damage(target, damage, ability_id)   # impact comes with the hit
		else:
			# Visual-only arrow (a party member's), or the target died on the way.
			ImpactFX.spawn_color(get_tree().current_scene, aim, _impact_color(), false, false, true)
		_finish()
		return
	var next := global_position + to_target.normalized() * step
	if not Combat.line_of_sight(get_world_3d(), global_position, next):
		ImpactFX.spawn_color(get_tree().current_scene, global_position, _impact_color(), false, false, true)
		_finish()
		return
	look_at(aim, Vector3.UP)
	global_position = next
	if _snake and _snake.visible:
		_snake.rotation.z += delta * 14.0   # the snake winds around the shaft

var _last_aim := Vector3.ZERO

func _impact_color() -> Color:
	return _glow.light_color if _glow and _glow.visible else Color(1.0, 0.9, 0.75)

# Nature archer (Venomstring): a woven snake coiled around the shaft, in its
# venom's colour. Only a look: nothing of it reaches the enemy.
const SNAKE_COLORS := {"fangarrow": Color(0.62, 1.0, 0.38), "adderarrow": Color(0.4, 0.95, 0.3),
	"asparrow": Color(1.0, 0.85, 0.25), "kraitarrow": Color(0.92, 0.95, 1.0), "bloatarrow": Color(0.4, 0.95, 0.3)}
const SNAKE_BEADS := 12
var _snake: Node3D
var _snake_mat: StandardMaterial3D

func _build_snake() -> void:
	_snake = Node3D.new()
	add_child(_snake)
	_snake_mat = StandardMaterial3D.new()
	_snake_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_snake_mat.emission_enabled = true
	_snake_mat.emission_energy_multiplier = 2.0
	var bead := SphereMesh.new()
	bead.radius = 0.022
	bead.height = 0.044
	bead.radial_segments = 6
	bead.rings = 3
	bead.material = _snake_mat
	for i in SNAKE_BEADS:
		var t := float(i) / float(SNAKE_BEADS - 1)
		var a := t * TAU * 2.0
		var m := MeshInstance3D.new()
		m.mesh = bead
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = Vector3(cos(a) * 0.055, sin(a) * 0.055, lerpf(0.3, -0.32, t))
		if i == SNAKE_BEADS - 1:
			m.scale = Vector3.ONE * 1.6   # its head, by the tip
		_snake.add_child(m)
	_snake_tint(ability_id)

func _snake_tint(id: String) -> void:
	if _snake == null:
		return
	_snake.visible = SNAKE_COLORS.has(id)
	if _snake.visible:
		var c: Color = SNAKE_COLORS[id]
		_snake_mat.albedo_color = c
		_snake_mat.emission = c
