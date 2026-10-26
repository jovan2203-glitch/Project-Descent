extends RefCounted

# Generic flair every ability gets, in its book's color (Abilities.color_of):
# - while casting: a glow in the casting hand, motes drawn into it and a slowly
#   turning rune circle at the caster's feet;
# - on release (casts and instants): a hand flash, a ground pulse and a few
#   rising motes (martial abilities: a kick of sparks instead of the rune pulse);
# - melee swings: a spray of sparks along the arc;
# - heals: a short shower of rising motes on whoever was healed.
# Only pictures: nothing here touches gameplay. Kept light (one-shot CPU
# particles, shared materials, a per-frame cap) since it runs on every press.
# Usage: const CastFX = preload("res://scripts/core/cast_fx.gd")

## At most this many new effects per frame.
const MAX_PER_FRAME := 6
static var _frame := -1
static var _count := 0
static var _mote_mat: StandardMaterial3D   # shared: mote color comes from the ramp
static var _mote_mesh: Mesh

## A node that keeps itself at `follow.call()` every frame (the casting hand).
class Follow extends Node3D:
	var follow: Callable
	func _process(_d: float) -> void:
		if follow.is_valid():
			global_position = follow.call()

static func _budget() -> bool:
	var f := Engine.get_process_frames()
	if f != _frame:
		_frame = f
		_count = 0
	_count += 1
	return _count <= MAX_PER_FRAME

## Cast in progress on `caster` (feet at `feet_y`). `hand` returns the hand's
## world position each frame. Returns the effect; pass it to end_cast.
static func start_cast(caster: Node3D, hand: Callable, feet_y: float, col: Color) -> Node3D:
	if caster == null or not caster.is_inside_tree():
		return null
	var root := Node3D.new()
	caster.add_child(root)
	# Hand glow: a soft orb with a light, pulsing gently.
	var glow := Follow.new()
	glow.follow = hand
	glow.top_level = true
	root.add_child(glow)
	glow.global_position = hand.call()
	var orb_mat := _add_mat(Color(col.lightened(0.45), 0.75))
	var orb := _sphere(0.12, orb_mat)
	glow.add_child(orb)
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.4
	light.omni_range = 2.2
	glow.add_child(light)
	var pulse := orb.create_tween().set_loops()
	pulse.tween_property(orb, "scale", Vector3.ONE * 1.35, 0.3).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(orb, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_SINE)
	# Motes drawn in toward the hand.
	var motes := _motes(col, 14, 0.7)
	motes.one_shot = false
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	motes.emission_sphere_radius = 0.6
	motes.initial_velocity_min = 0.0
	motes.initial_velocity_max = 0.0
	motes.radial_accel_min = -3.0
	motes.radial_accel_max = -2.0
	motes.local_coords = true
	glow.add_child(motes)
	# Rune circle at the feet: an outer ring and an inner one, turning opposite ways.
	var rune := Node3D.new()
	rune.top_level = true
	root.add_child(rune)
	rune.global_position = Vector3(caster.global_position.x, feet_y + 0.04, caster.global_position.z)
	var ring_mat := _add_mat(Color(col, 0.55))
	var outer := _ring(0.95, 1.0, ring_mat, 40)
	var inner := _ring(0.62, 0.66, ring_mat, 6)   # (6 segments: a hexagon)
	rune.add_child(outer)
	rune.add_child(inner)
	rune.scale = Vector3(0.3, 1, 0.3)
	var grow := rune.create_tween()
	grow.tween_property(rune, "scale", Vector3.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	var spin := rune.create_tween().set_loops()
	spin.set_parallel(true)
	spin.tween_property(outer, "rotation:y", TAU, 4.0).from(0.0)
	spin.tween_property(inner, "rotation:y", -TAU, 3.0).from(0.0)
	root.set_meta("rune", rune)
	root.set_meta("mat", ring_mat)
	root.set_meta("orb_mat", orb_mat)
	root.set_meta("light", light)
	return root

## The cast ended (finished or broken): fade it out.
static func end_cast(fx: Node3D) -> void:
	if fx == null or not is_instance_valid(fx) or fx.has_meta("ending"):
		return
	fx.set_meta("ending", true)
	var t := fx.create_tween().set_parallel(true)
	t.tween_property(fx.get_meta("mat"), "albedo_color:a", 0.0, 0.2)
	t.tween_property(fx.get_meta("orb_mat"), "albedo_color:a", 0.0, 0.15)
	t.tween_property(fx.get_meta("light"), "light_energy", 0.0, 0.15)
	t.chain().tween_callback(fx.queue_free)

## An ability went off: flash at the hand, then a ground pulse (spells) or a
## kick of sparks (martial abilities, `physical`).
static func release(scene: Node, hand: Vector3, feet: Vector3, col: Color, physical: bool) -> void:
	if scene == null or not scene.is_inside_tree() or not _budget():
		return
	var root := Node3D.new()
	scene.add_child(root)
	root.global_position = hand
	var flash_mat := _add_mat(Color(col.lightened(0.55), 0.9))
	var flash := _sphere(0.18, flash_mat)
	flash.scale = Vector3.ONE * 0.5
	root.add_child(flash)
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 3.0
	light.omni_range = 3.0
	root.add_child(light)
	var burst := _motes(col, 10, 0.55)
	burst.explosiveness = 1.0
	burst.spread = 180.0
	burst.initial_velocity_min = 1.2 if not physical else 2.5
	burst.initial_velocity_max = 2.4 if not physical else 4.0
	burst.damping_min = 2.0
	burst.damping_max = 3.0
	burst.gravity = Vector3(0, -6.0, 0) if physical else Vector3(0, 1.5, 0)
	root.add_child(burst)
	var t := root.create_tween().set_parallel(true)
	t.tween_property(flash, "scale", Vector3.ONE * 1.4, 0.14).set_ease(Tween.EASE_OUT)
	t.tween_property(flash_mat, "albedo_color:a", 0.0, 0.16)
	t.tween_property(light, "light_energy", 0.0, 0.25)
	if not physical:
		var ring_mat := _add_mat(Color(col.lightened(0.2), 0.7))
		var ring := _ring(0.9, 1.0, ring_mat, 40)
		ring.top_level = true
		root.add_child(ring)
		ring.global_position = Vector3(feet.x, feet.y + 0.05, feet.z)
		ring.scale = Vector3(0.5, 1, 0.5)
		t.tween_property(ring, "scale", Vector3(1.7, 1, 1.7), 0.35).set_ease(Tween.EASE_OUT)
		t.tween_property(ring_mat, "albedo_color:a", 0.0, 0.35)
	t.chain().tween_interval(0.5)
	t.chain().tween_callback(root.queue_free)

## Sparks thrown along a melee swing (at `at`, toward `forward`).
static func swing_sparks(scene: Node, at: Vector3, forward: Vector3, col: Color) -> void:
	if scene == null or not scene.is_inside_tree() or not _budget():
		return
	var p := _motes(col, 8, 0.3)
	p.explosiveness = 1.0
	p.direction = forward.normalized() + Vector3(0, 0.3, 0)
	p.spread = 50.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 5.5
	p.damping_min = 4.0
	p.damping_max = 6.0
	p.gravity = Vector3(0, -5.0, 0)
	scene.add_child(p)
	p.global_position = at
	_free_after(p, 0.6)

## A heal landed on `target`: motes rising around it.
static func heal_glow(target: Node3D, feet_y: float, col: Color) -> void:
	if target == null or not target.is_inside_tree() or not _budget():
		return
	# One shower per target at a time (HoT ticks don't stack them up).
	var now := Time.get_ticks_msec()
	if now - int(target.get_meta("_heal_fx_at", -10000)) < 600:
		return
	target.set_meta("_heal_fx_at", now)
	var p := _motes(col, 12, 0.9)
	p.explosiveness = 0.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.5
	p.emission_ring_inner_radius = 0.3
	p.emission_ring_height = 0.1
	p.direction = Vector3.UP
	p.spread = 10.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 1.8
	p.gravity = Vector3.ZERO
	target.get_tree().current_scene.add_child(p)
	p.global_position = Vector3(target.global_position.x, feet_y + 0.1, target.global_position.z)
	_free_after(p, 1.2)

# --- Building blocks -----------------------------------------------------------

static func _add_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = col
	return m

static func _sphere(r: float, mat: Material) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 5
	var m := MeshInstance3D.new()
	m.mesh = s
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

static func _ring(inner: float, outer: float, mat: Material, segments: int) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = outer
	torus.rings = segments
	torus.ring_segments = 3
	var m := MeshInstance3D.new()
	m.mesh = torus
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.scale = Vector3(1, 0.05, 1)   # flat on the ground
	return m

static func _motes(col: Color, amount: int, lifetime: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.direction = Vector3.UP
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0.1))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, Color(col.lightened(0.6), 1.0))
	g.set_color(1, Color(col, 0.0))
	p.color_ramp = g
	if _mote_mesh == null:
		var q := QuadMesh.new()
		q.size = Vector2(0.08, 0.08)
		_mote_mesh = q
	p.mesh = _mote_mesh
	if _mote_mat == null:
		_mote_mat = _add_mat(Color.WHITE)
		_mote_mat.vertex_color_use_as_albedo = true
		_mote_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	p.material_override = _mote_mat
	p.emitting = true
	return p

static func _free_after(n: Node, secs: float) -> void:
	var t := n.create_tween()
	t.tween_interval(secs)
	t.tween_callback(n.queue_free)
