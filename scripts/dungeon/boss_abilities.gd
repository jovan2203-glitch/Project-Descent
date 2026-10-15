extends Node

# Boss moveset (child of the floor boss). Works for any enemy type that is the
# boss; the host (or solo player) runs it, party members see the telegraphs.
#
#   Grave Slam   - a red circle grows around the boss (1.6 s, boss stands
#                  still); everyone still inside when it fills takes a big hit.
#   Bone Eruption - circles appear under every player (+ one random spot);
#                  1.5 s later bone spikes erupt from them. Keep moving.
#   Raise Dead   - a 2.5 s cast ("Casting Raise Dead") that summons 3 servants
#                  at the edges of the room. INTERRUPT it (Counterspell, Kick,
#                  Pummel) or stun the boss to stop it.
#   Enrage       - at 30% health: attacks 35% faster, moves faster, abilities
#                  come more often, and he glows red.
# Between abilities the boss fights normally.

const Stats = preload("res://scripts/core/stats.gd")

const SLAM_RADIUS := 5.0
const SLAM_TIME := 1.6
const SLAM_COEF := 1.3          # x the boss's contact damage
const ERUPT_RADIUS := 2.2
const ERUPT_TIME := 1.5
const ERUPT_COEF := 0.9
const SUMMON_TIME := 2.5
const SUMMON_COUNT := 3
const ENRAGE_AT := 0.3

var boss: Node3D
var dungeon: Node
var _cd := {"slam": 7.0, "erupt": 11.0, "summon": 14.0}
const COOLDOWNS := {"slam": 12.0, "erupt": 15.0, "summon": 30.0}
var _next_think := 3.0
var _enraged := false

func _net() -> Node:
	return get_node_or_null("/root/Net")

func _authority() -> bool:
	var n := _net()
	return n == null or not n.is_client()

func _ready() -> void:
	boss = get_parent() as Node3D

func _process(delta: float) -> void:
	if boss == null or not is_instance_valid(boss) or not boss.is_alive() or not _authority():
		return
	for k in _cd:
		_cd[k] = maxf(float(_cd[k]) - delta, 0.0)
	if not _enraged and float(boss.health) <= float(boss.max_health) * ENRAGE_AT:
		_enrage()
	if not boss.is_in_combat():
		return
	_next_think -= delta
	if _next_think > 0.0 or _busy():
		return
	_next_think = 1.0
	var tgt: Node3D = boss.top_threat()
	if tgt == null:
		return
	# Pick an ability that's ready (random order so fights vary).
	var order := ["slam", "erupt", "summon"]
	order.shuffle()
	for a in order:
		if float(_cd[a]) > 0.0:
			continue
		match a:
			"slam":
				if boss._dist_to(tgt) > SLAM_RADIUS + 2.0:
					continue
				_slam()
			"erupt":
				_erupt()
			"summon":
				if boss.is_silenced():
					continue
				_summon()
		_cd[a] = float(COOLDOWNS[a]) * (0.7 if _enraged else 1.0)
		_next_think = 2.5 if not _enraged else 1.8
		return

func _busy() -> bool:
	return boss.is_casting() or Time.get_ticks_msec() / 1000.0 < float(boss.busy_until)

func _hold(seconds: float) -> void:
	boss.busy_until = Time.get_ticks_msec() / 1000.0 + seconds

# --- Grave Slam ---------------------------------------------------------------------

func _slam() -> void:
	var at := boss.global_position
	_hold(SLAM_TIME + 0.3)
	_announce("%s raises his fists!" % boss.display_name)
	_telegraph_all(at, SLAM_RADIUS, SLAM_TIME, Color(1.0, 0.2, 0.1))
	get_tree().create_timer(SLAM_TIME).timeout.connect(func():
		if not is_instance_valid(boss) or not boss.is_alive():
			return
		boss.play_once("attack")
		_hit_area(at, SLAM_RADIUS, SLAM_COEF, "boss_slam")
		_burst_all(at, SLAM_RADIUS, Color(1.0, 0.35, 0.2)))

# --- Bone Eruption ------------------------------------------------------------------

func _erupt() -> void:
	var spots: Array = []
	for b in _party():
		if b.is_alive():
			spots.append(b.global_position)
	var c: Vector3 = dungeon.rooms[dungeon._boss_index]["center"] if dungeon else boss.global_position
	spots.append(c + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)))
	_announce("The ground trembles...")
	for p in spots:
		var at := Vector3(p.x, c.y, p.z)
		_telegraph_all(at, ERUPT_RADIUS, ERUPT_TIME, Color(0.9, 0.85, 0.6))
		get_tree().create_timer(ERUPT_TIME).timeout.connect(func():
			if not is_instance_valid(boss) or not boss.is_alive():
				return
			_hit_area(at, ERUPT_RADIUS, ERUPT_COEF, "boss_eruption")
			_burst_all(at, ERUPT_RADIUS, Color(0.95, 0.9, 0.75)))

# --- Raise Dead (interruptible) -----------------------------------------------------------

func _summon() -> void:
	boss.cast_name = "Raise Dead"
	_announce("%s begins to Raise Dead - interrupt him!" % boss.display_name, Color(0.8, 0.6, 1.0))
	_hold(SUMMON_TIME)
	boss._show_cast(true, SUMMON_TIME)
	var n := _net()
	if n and n.is_host():
		n.enemy_fx(boss, "cast", null, {"d": SUMMON_TIME, "n": "Raise Dead"})
	# The cast is the boss's cast tween, so interrupts (enemy.interrupt) cancel it.
	var t := boss.create_tween()
	boss._cast_tween = t
	t.tween_interval(SUMMON_TIME)
	t.tween_callback(func():
		boss._cast_tween = null
		boss._show_cast(false)
		if boss.is_alive() and dungeon and dungeon.has_method("summon_boss_adds"):
			dungeon.summon_boss_adds(SUMMON_COUNT))

# --- Enrage -------------------------------------------------------------------------------

func _enrage() -> void:
	_enraged = true
	boss.attack_cooldown *= 0.65
	boss.move_speed *= 1.2
	apply_enrage_look(boss)
	_announce("%s becomes enraged!" % boss.display_name, Color(1.0, 0.3, 0.2))
	var n := _net()
	if n and n.is_host():
		n.enemy_fx(boss, "enrage", null, {})

## Red glow + light (also played on party members' machines).
static func apply_enrage_look(e: Node3D) -> void:
	if e.has_node("EnrageLight"):
		return
	var l := OmniLight3D.new()
	l.name = "EnrageLight"
	l.light_color = Color(1.0, 0.1, 0.05)
	l.light_energy = 3.0
	l.omni_range = 5.0
	l.position = Vector3(0, 1.0, 0)
	e.add_child(l)
	var p := CPUParticles3D.new()
	p.amount = 30
	p.lifetime = 0.8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.8
	p.direction = Vector3.UP
	p.gravity = Vector3(0, 2.0, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.0
	var m := SphereMesh.new()
	m.radius = 0.05
	m.height = 0.1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.15, 0.05)
	mat.emission_energy_multiplier = 4.0
	m.material = mat
	p.mesh = m
	p.position = Vector3(0, 1.0, 0)
	e.add_child(p)

# --- Helpers ------------------------------------------------------------------------------

func _party() -> Array:
	var n := _net()
	if n:
		return n.party_bodies()
	return get_tree().get_nodes_in_group("player")

## Damage every player within `radius` of `at` (flat distance).
func _hit_area(at: Vector3, radius: float, coef: float, id: String) -> void:
	for b in _party():
		if not is_instance_valid(b) or not b.is_alive():
			continue
		var d := Vector2(b.global_position.x - at.x, b.global_position.z - at.z).length()
		if d <= radius:
			boss.deal_melee_hit(b, float(boss.contact_damage) * coef, id)

func _telegraph_all(at: Vector3, radius: float, time: float, col: Color) -> void:
	telegraph(get_tree().current_scene, at, radius, time, col)
	var n := _net()
	if n and n.is_host():
		n.enemy_fx(boss, "telegraph", null, {"at": at, "r": radius, "d": time, "c": col})

func _burst_all(at: Vector3, radius: float, col: Color) -> void:
	burst(get_tree().current_scene, at, radius, col)
	var n := _net()
	if n and n.is_host():
		n.enemy_fx(boss, "burst", null, {"at": at, "r": radius, "c": col})

func _announce(text: String, col: Color = Color(1.0, 0.45, 0.35)) -> void:
	if dungeon and dungeon.has_method("_announce"):
		dungeon._announce(text, col)
	var n := _net()
	if n and n.is_host():
		n.enemy_fx(boss, "announce", null, {"t": text, "c": col})

## Danger circle on the floor: a faint disc whose bright fill grows until it
## covers the circle - that's when it hits.
static func telegraph(scene: Node, at: Vector3, radius: float, time: float, col: Color) -> void:
	if scene == null:
		return
	var root := Node3D.new()
	scene.add_child(root)
	root.global_position = at + Vector3(0, 0.05, 0)
	var edge_mat := StandardMaterial3D.new()
	edge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	edge_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	edge_mat.albedo_color = Color(col, 0.22)
	edge_mat.no_depth_test = false
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = radius
	dm.bottom_radius = radius
	dm.height = 0.02
	dm.radial_segments = 40
	disc.mesh = dm
	disc.material_override = edge_mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(disc)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius - 0.12
	tm.outer_radius = radius
	tm.rings = 48
	tm.ring_segments = 4
	ring.mesh = tm
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = col
	ring.material_override = ring_mat
	ring.scale = Vector3(1, 0.15, 1)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var fill := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = radius
	fm.bottom_radius = radius
	fm.height = 0.03
	fm.radial_segments = 40
	fill.mesh = fm
	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_mat.albedo_color = Color(col, 0.4)
	fill.material_override = fill_mat
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fill.scale = Vector3(0.01, 1, 0.01)
	root.add_child(fill)
	var t := root.create_tween()
	t.tween_property(fill, "scale", Vector3.ONE, time)
	t.tween_callback(root.queue_free)

## The hit itself: a quick bright shockwave.
static func burst(scene: Node, at: Vector3, radius: float, col: Color) -> void:
	if scene == null:
		return
	var m := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.8
	tm.outer_radius = 1.0
	tm.rings = 32
	m.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(col, 0.9)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(m)
	m.global_position = at + Vector3(0, 0.15, 0)
	m.scale = Vector3(0.3, 0.4, 0.3)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 4.0
	l.omni_range = radius * 1.6
	l.position = Vector3(0, 0.8, 0)
	m.add_child(l)
	var t := m.create_tween()
	t.set_parallel(true)
	t.tween_property(m, "scale", Vector3(radius, 1.0, radius), 0.3).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	t.tween_property(l, "light_energy", 0.0, 0.35)
	t.chain().tween_callback(m.queue_free)
