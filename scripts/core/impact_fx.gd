extends RefCounted

# Hit effects (WoW-style "the spell landed"): a quick flash, a light pop and a
# burst of sparks / shards in the hit's school color, bigger on crits. Frost
# hits also leave a short icy shimmer on the target.
# Played for every direct hit by CombatSystem.deal() - on the same frame as the
# damage number - and by visual-only projectiles when they land on a party
# member's screen. DoT ticks don't get one.
# Usage: const ImpactFX = preload("res://scripts/core/impact_fx.gd")
#        ImpactFX.spawn(scene, position, "frost", crit)

const CombatKeys = preload("res://scripts/core/combat_keys.gd")

## At most this many new impacts per frame (a big AoE on 20 enemies stays cheap).
const MAX_PER_FRAME := 10
static var _frame := -1
static var _count := 0
static var _spark_mats := {}   # color html -> material (shared; particle color comes from the ramp)
static var _spark_mesh: Mesh
static var _shard_mesh: Mesh

static func color_for(dtype: String) -> Color:
	if dtype == "" or dtype == "physical":
		return Color(1.0, 0.9, 0.75)
	return CombatKeys.type_color(dtype)

static func spawn(scene: Node, at: Vector3, dtype: String, crit: bool = false) -> void:
	spawn_color(scene, at, color_for(dtype), crit, dtype == "frost", dtype in ["frost", "physical", ""])

## Launch flash where a projectile leaves the hand (small, quick).
static func flash(scene: Node, at: Vector3, col: Color, size: float = 0.6) -> void:
	if scene == null or not scene.is_inside_tree():
		return
	var root := Node3D.new()
	scene.add_child(root)
	root.global_position = at
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(col.lightened(0.5), 0.9)
	var m := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	sphere.radial_segments = 10
	sphere.rings = 5
	m.mesh = sphere
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.scale = Vector3.ONE * 0.5 * size
	root.add_child(m)
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 2.5 * size
	light.omni_range = 2.5
	root.add_child(light)
	var t := root.create_tween()
	t.set_parallel(true)
	t.tween_property(m, "scale", Vector3.ONE * 1.3 * size, 0.12).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.14)
	t.tween_property(light, "light_energy", 0.0, 0.16)
	t.chain().tween_callback(root.queue_free)

## Impact by color (visual-only projectiles, which know their color, not a school).
static func spawn_color(scene: Node, at: Vector3, col: Color, crit: bool = false, frosty: bool = false,
		shards: bool = false) -> void:
	if scene == null or not scene.is_inside_tree():
		return
	var f := Engine.get_process_frames()
	if f != _frame:
		_frame = f
		_count = 0
	_count += 1
	if _count > MAX_PER_FRAME:
		return
	var size := 1.6 if crit else 1.0
	var root := Node3D.new()
	scene.add_child(root)
	root.global_position = at
	# Flash: a bright sphere that swells and fades in a blink.
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flash_mat.albedo_color = Color(col.lightened(0.5), 0.9)
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	sphere.radial_segments = 12
	sphere.rings = 6
	flash.mesh = sphere
	flash.material_override = flash_mat
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.scale = Vector3.ONE * 0.4 * size
	root.add_child(flash)
	# Light pop.
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 4.0 * size
	light.omni_range = 3.0 * size
	root.add_child(light)
	# Sparks / shards flying out.
	root.add_child(_burst(col, shards, size))
	if frosty:
		root.add_child(_shimmer(col))
	var t := root.create_tween()
	t.set_parallel(true)
	t.tween_property(flash, "scale", Vector3.ONE * 1.5 * size, 0.16).set_ease(Tween.EASE_OUT)
	t.tween_property(flash_mat, "albedo_color:a", 0.0, 0.18)
	t.tween_property(light, "light_energy", 0.0, 0.22)
	t.chain().tween_interval(0.6)
	t.chain().tween_callback(root.queue_free)

static func _mat_for(col: Color) -> StandardMaterial3D:
	var key := col.to_html()
	if not _spark_mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.vertex_color_use_as_albedo = true
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_spark_mats[key] = m
	return _spark_mats[key]

static func _ramp(col: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(col.lightened(0.6), 1.0))
	g.set_color(1, Color(col, 0.0))
	return g

static func _burst(col: Color, shards: bool, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = int(16 * size)
	p.lifetime = 0.45
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.0 * size
	p.initial_velocity_max = 4.5 * size
	p.damping_min = 3.0
	p.damping_max = 5.0
	p.gravity = Vector3(0, -7.0, 0) if shards else Vector3(0, 1.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0.1))
	p.scale_amount_curve = curve
	p.color_ramp = _ramp(col)
	if shards:
		if _shard_mesh == null:
			var prism := PrismMesh.new()
			prism.size = Vector3(0.06, 0.14, 0.03)
			_shard_mesh = prism
		p.mesh = _shard_mesh
		p.particle_flag_align_y = true
	else:
		if _spark_mesh == null:
			var q := QuadMesh.new()
			q.size = Vector2(0.09, 0.09)
			_spark_mesh = q
		p.mesh = _spark_mesh
	p.material_override = _mat_for(col)
	p.emitting = true
	return p

## Frost: a little icy glitter hanging on the target for a moment.
static func _shimmer(col: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.6
	p.amount = 10
	p.lifetime = 0.7
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.4
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.6
	p.color_ramp = _ramp(Color(0.85, 0.97, 1.0))
	if _spark_mesh == null:
		var q := QuadMesh.new()
		q.size = Vector2(0.09, 0.09)
		_spark_mesh = q
	p.mesh = _spark_mesh
	p.material_override = _mat_for(col.lightened(0.4))
	p.emitting = true
	return p
