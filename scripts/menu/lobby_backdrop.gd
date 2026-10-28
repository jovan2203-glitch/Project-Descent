extends Node3D

# The lobby's 3D backdrop: a stone clearing in front of a ruined dungeon gate, a
# campfire behind the party and two torches on the gate. Placeholder art built
# from primitives; real art replaces this whole scene (scenes/menu/lobby_backdrop.tscn)
# without touching the menu. The party stands at z = 0 (you) and z = -1.2 (the rest).

const FLICKER = preload("res://scripts/dungeon/flicker_light.gd")

const STONE := Color(0.42, 0.4, 0.38)
const STONE_DARK := Color(0.3, 0.29, 0.28)
const GROUND := Color(0.26, 0.24, 0.21)
const FIRE := Color(1.0, 0.55, 0.2)
const PORTAL := Color(0.35, 0.7, 1.0)

var _mats := {}

func _ready() -> void:
	_ground()
	_gate(Vector3(0, 0, -6.5))
	_ruins()
	_campfire(Vector3(0, -0.1, -3.2))

func _mat(key: String, col: Color, emit := 0.0, emit_col := Color.BLACK) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = emit_col
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m

func _mesh(mesh: Mesh, pos: Vector3, mat: Material, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mesh(b, pos, mat)

func _ground() -> void:
	var c := CylinderMesh.new()
	c.top_radius = 14.0
	c.bottom_radius = 14.0
	c.height = 0.2
	c.radial_segments = 32
	_mesh(c, Vector3(0, -0.3, -3.0), _mat("ground", GROUND), false)
	# Worn flagstones around the party.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 26:
		var a := rng.randf() * TAU
		var r := rng.randf_range(1.6, 5.5)
		var s := rng.randf_range(0.5, 0.9)
		var stone := _box(Vector3(s, 0.06, s * rng.randf_range(0.6, 1.0)),
			Vector3(cos(a) * r, -0.18, -2.5 + sin(a) * r * 0.7), _mat("flag", STONE_DARK))
		stone.rotation.y = rng.randf() * PI
		stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## A dungeon gate: two pillars, a lintel and a faint glow in the doorway.
func _gate(at: Vector3) -> void:
	var stone := _mat("stone", STONE)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.9, 4.2, 0.9), at + Vector3(2.0 * side, 1.9, 0), stone)
		_box(Vector3(1.2, 0.4, 1.2), at + Vector3(2.0 * side, -0.05, 0), stone)
		_torch(at + Vector3(1.45 * side, 2.3, 0.55))
	var lintel := _box(Vector3(5.4, 0.8, 1.1), at + Vector3(0, 4.3, 0), stone)
	lintel.rotation.z = 0.03   # settled a little
	var q := QuadMesh.new()
	q.size = Vector2(3.1, 4.0)
	var glow := _mesh(q, at + Vector3(0, 1.85, -0.1), _mat("portal", Color(0.05, 0.1, 0.18), 1.2, PORTAL), false)
	glow.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var deep := OmniLight3D.new()
	deep.light_color = PORTAL
	deep.light_energy = 1.2
	deep.omni_range = 4.0
	deep.position = at + Vector3(0, 1.5, 0.8)
	add_child(deep)

## Broken columns and boulders to the sides.
func _ruins() -> void:
	var stone := _mat("stone", STONE)
	var dark := _mat("stone_dark", STONE_DARK)
	for p in [[-5.2, -4.0, 2.6], [5.0, -4.5, 1.6], [-7.0, -6.5, 3.4], [7.2, -6.0, 2.2]]:
		var c := CylinderMesh.new()
		c.top_radius = 0.4
		c.bottom_radius = 0.45
		c.height = p[2]
		c.radial_segments = 10
		_mesh(c, Vector3(p[0], p[2] * 0.5 - 0.2, p[1]), stone)
	var fallen := CylinderMesh.new()
	fallen.top_radius = 0.38
	fallen.bottom_radius = 0.42
	fallen.height = 2.2
	fallen.radial_segments = 10
	var f := _mesh(fallen, Vector3(4.0, 0.15, -3.0), stone)
	f.rotation = Vector3(0, 0.6, PI / 2)
	for b in [[-3.6, -2.8, 0.5], [3.3, -5.4, 0.7], [-4.4, -5.6, 0.8], [6.0, -2.4, 0.45]]:
		var s := SphereMesh.new()
		s.radius = b[2]
		s.height = b[2] * 1.3
		s.radial_segments = 8
		s.rings = 4
		_mesh(s, Vector3(b[0], b[2] * 0.3 - 0.2, b[1]), dark)

func _torch(at: Vector3) -> void:
	_box(Vector3(0.1, 0.35, 0.1), at, _mat("iron", Color(0.15, 0.14, 0.13)))
	var s := SphereMesh.new()
	s.radius = 0.1
	s.height = 0.22
	_mesh(s, at + Vector3(0, 0.25, 0), _mat("flame", FIRE.lightened(0.4), 6.0, FIRE), false)
	var l := OmniLight3D.new()
	l.light_color = FIRE
	l.light_energy = 1.4
	l.omni_range = 4.5
	l.position = at + Vector3(0, 0.3, 0.3)
	l.set_script(FLICKER)
	add_child(l)

## A ring of stones, crossed logs, a flame and rising embers.
func _campfire(at: Vector3) -> void:
	var dark := _mat("stone_dark", STONE_DARK)
	for i in 9:
		var a := TAU * i / 9.0
		var s := SphereMesh.new()
		s.radius = 0.16
		s.height = 0.2
		s.radial_segments = 6
		s.rings = 3
		_mesh(s, at + Vector3(cos(a) * 0.55, 0.05, sin(a) * 0.55), dark)
	var wood := _mat("wood", Color(0.3, 0.2, 0.12))
	for r in [0.4, -0.4, 1.57]:
		var lg := CylinderMesh.new()
		lg.top_radius = 0.07
		lg.bottom_radius = 0.08
		lg.height = 0.8
		lg.radial_segments = 6
		var m := _mesh(lg, at + Vector3(0, 0.12, 0), wood)
		m.rotation = Vector3(PI / 2, r, 0)
	add_child(_flames(at + Vector3(0, 0.15, 0)))
	add_child(_embers(at + Vector3(0, 0.4, 0)))
	var l := OmniLight3D.new()
	l.light_color = FIRE
	l.light_energy = 2.6
	l.omni_range = 6.5
	l.position = at + Vector3(0, 0.8, 0)
	l.set_script(FLICKER)
	add_child(l)

func _fire_material(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col * energy
	return m

func _fade_ramp(start: Color, end: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, start)
	g.set_color(1, Color(end, 0.0))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

func _flames(pos: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.position = pos
	p.amount = 24
	p.lifetime = 0.7
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.18
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.gravity = Vector3(0, 1.2, 0)
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 0.8
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	pm.color_ramp = _fade_ramp(Color(1.0, 0.85, 0.4), Color(0.9, 0.25, 0.05))
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.38, 0.38)
	q.material = _fire_material(Color(1, 1, 1), 1.6)
	p.draw_pass_1 = q
	return p

func _embers(pos: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.position = pos
	p.amount = 14
	p.lifetime = 2.6
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.25
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.gravity = Vector3(0, 0.25, 0)
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.7
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.color_ramp = _fade_ramp(Color(1.0, 0.7, 0.3), Color(1.0, 0.3, 0.1))
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.04, 0.04)
	q.material = _fire_material(Color(1, 1, 1), 2.5)
	p.draw_pass_1 = q
	return p
