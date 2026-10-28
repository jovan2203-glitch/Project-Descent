extends Node3D


# Training Room (Play > Training Room). A sunny castle courtyard; you spawn in
# the middle with the dummy stations in a ring around you, at your level:
#   - Single Target:  one DPS dummy
#   - AoE:            5 DPS dummies packed together
#   - Healing:        5 ally dummies packed together + 1 on its own (click them)
#   - Tank Dummy:     hits back
#   - Pack:           4 small dummies + 1 large one, all hit back
# DPS dummies stand still and never die; hitting dummies also stand still and
# hit back when you're in reach, but never die either. Dying here costs
# nothing. Numbers come from the Details meter (top right, K): DPS / HPS, a
# per-spell breakdown and buff uptime for every fight.

const DUMMY = preload("res://scripts/training/dummy.gd")
const ALLY_DUMMY = preload("res://scripts/training/ally_dummy.gd")

@onready var player: Node3D = $Player
@onready var level_root: Node3D = $Level
@onready var enemies_root: Node3D = $Enemies

## Courtyard: stations sit on a ring of this radius around the spawn (the centre).
const RING_RADIUS := 14.0
const YARD := 50.0          # courtyard is YARD x YARD metres inside the walls
const WALL_H := 6.0
const STONE := Color(0.62, 0.58, 0.52)
const STONE_DARK := Color(0.45, 0.42, 0.38)
const WOOD := Color(0.42, 0.28, 0.16)

func _ready() -> void:
	var pd := get_node_or_null("/root/PlayerData")
	var lvl: int = int(pd.level) if pd else 1
	_build_room()
	player.global_position = Vector3(0, 1.0, 0)   # spawn in the middle of the ring
	player.rotation.y = 0.0
	# Six stations around you, facing in; damage in front, healing behind.
	var st := func(deg: float) -> Vector3:
		var a := deg_to_rad(deg)
		return Vector3(sin(a), 0, -cos(a)) * RING_RADIUS
	# Single target (straight ahead)
	var single: Vector3 = st.call(0.0)
	_station("Single Target", single)
	_dummy(single, lvl)
	# AoE: 5 packed together
	var aoe: Vector3 = st.call(60.0)
	_station("AoE — 5 Dummies", aoe)
	for p in _ring(aoe, 1.7, 5):
		_dummy(p, lvl)
	# Healing: 5 packed allies + 1 alone
	var heal5: Vector3 = st.call(120.0)
	_station("Healing — 5 Allies", heal5)
	for p in _ring(heal5, 1.7, 5):
		_ally(p, lvl, "Ally Dummy")
	var heal1: Vector3 = st.call(180.0)
	_station("Healing — Single Ally", heal1)
	_ally(heal1, lvl, "Lone Ally Dummy")
	# Pack that hits back: 4 small + 1 large
	var pack: Vector3 = st.call(-120.0)
	_station("Pack — 4 + 1, hit back", pack)
	for p in _ring(pack, 2.2, 4):
		_dummy(p, lvl, true, 0.8, "Small Dummy", Color(0.7, 0.45, 0.35))
	var big := _dummy(pack, lvl, true, 1.4, "Large Dummy", Color(0.6, 0.3, 0.25), 250)
	big.contact_damage = 2.0
	# Tank dummy (hits back)
	var tank_at: Vector3 = st.call(-60.0)
	_station("Tank Dummy — hits back", tank_at)
	var tank := _dummy(tank_at, lvl, true, 1.25, "Tank Dummy", Color(0.75, 0.35, 0.3))
	tank.contact_damage = 1.5
	_build_panel()
	var gl := get_node_or_null("/root/GameLog")
	if gl:
		gl.event("Entered the Training Room", Color(0.95, 0.75, 0.35))

# --- Courtyard (all visuals built here, so they're easy to swap for real art) ---------------

func _build_room() -> void:
	_daylight()
	var h := YARD / 2.0
	# Ground: cobbles, with a paved ring under the stations and a dais at the spawn.
	var ground := _box(Vector3(0, -0.5, 0), Vector3(YARD + 12, 1.0, YARD + 12), _stone_mat(Color(0.5, 0.46, 0.4), 0.35, true), true)
	ground.name = "Ground"
	var ring := CSGTorus3D.new()
	ring.inner_radius = RING_RADIUS - 3.2
	ring.outer_radius = RING_RADIUS + 3.2
	ring.ring_sides = 4
	ring.sides = 64
	ring.scale = Vector3(1, 0.02, 1)
	ring.position = Vector3(0, 0.0, 0)
	ring.material = _stone_mat(Color(0.66, 0.63, 0.58), 0.6, true)
	level_root.add_child(ring)
	var dais := CSGCylinder3D.new()
	dais.radius = 3.2
	dais.height = 0.1
	dais.sides = 32
	dais.position = Vector3(0, 0.0, 0)   # half sunk: no ledge to trip on (visual only)
	dais.material = _stone_mat(Color(0.72, 0.7, 0.66), 0.8, false)
	level_root.add_child(dais)
	var emblem := CSGCylinder3D.new()
	emblem.radius = 1.4
	emblem.height = 0.02
	emblem.sides = 6
	emblem.position = Vector3(0, 0.06, 0)
	emblem.material = _plain_mat(Color(0.25, 0.4, 0.7), 0.6)
	level_root.add_child(emblem)
	# Walls with battlements, corner towers, a gatehouse on the south side.
	var wall_mat := _stone_mat(STONE, 0.45, false)
	for side in [[Vector3(0, WALL_H / 2, -h), Vector3(YARD + 2, WALL_H, 2)],
			[Vector3(-h, WALL_H / 2, 0), Vector3(2, WALL_H, YARD + 2)],
			[Vector3(h, WALL_H / 2, 0), Vector3(2, WALL_H, YARD + 2)]]:
		_box(side[0], side[1], wall_mat, true)
	# South wall in two halves around the gate.
	var gate_w := 6.0
	var half := (YARD + 2 - gate_w) / 2.0
	for sx in [-1.0, 1.0]:
		_box(Vector3(sx * (gate_w / 2 + half / 2), WALL_H / 2, h), Vector3(half, WALL_H, 2), wall_mat, true)
	_gatehouse(Vector3(0, 0, h), gate_w, wall_mat)
	_battlements(h, wall_mat)
	for cx in [-h, h]:
		for cz in [-h, h]:
			_tower(Vector3(cx, 0, cz), wall_mat)
	# Banners on the north wall, behind the Single Target station.
	for x in [-10.0, 10.0]:
		_banner(Vector3(x, 0, -h + 1.05), Color(0.2, 0.35, 0.75))
	_banner(Vector3(0, 0, -h + 1.05), Color(0.7, 0.18, 0.15))
	# Props around the edges (visual only, no collision; they sit outside the ring).
	var props_rng := RandomNumberGenerator.new()
	props_rng.seed = 7
	for p in [Vector3(-19, 0, -19), Vector3(19, 0, 19), Vector3(-20, 0, 12)]:
		_tree(p)
	for p in [Vector3(20, 0, -8), Vector3(20, 0, -5.5), Vector3(-20.5, 0, -6)]:
		_crate(p, props_rng.randf_range(0, 0.6))
	for p in [Vector3(17.5, 0, -20.5), Vector3(-15, 0, 21), Vector3(20.5, 0, 6)]:
		_hay(p)
	for p in [Vector3(-8, 0, -22.6), Vector3(8, 0, -22.6)]:
		_weapon_rack(p)
	_well(Vector3(-17, 0, 18))

## Bright, clear midday: sky, sun with shadows, a little haze.
func _daylight() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.3, 0.52, 0.85)
	sky_mat.sky_horizon_color = Color(0.72, 0.8, 0.9)
	sky_mat.ground_horizon_color = Color(0.6, 0.62, 0.6)
	sky_mat.ground_bottom_color = Color(0.3, 0.3, 0.28)
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.82, 0.92)
	env.fog_density = 0.004
	env.glow_enabled = true
	env.glow_intensity = 0.3
	var we := get_node_or_null("WorldEnvironment")
	if we:
		we.environment = env
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	sun.rotation_degrees = Vector3(-52, 35, 0)
	level_root.add_child(sun)
	# The player's lantern is for dungeons; it's daytime here.
	var lantern := player.get_node_or_null("Lantern")
	if lantern:
		lantern.visible = false

# --- Building blocks -----------------------------------------------------------------------

## Stone material: cellular noise gives cobble / block variation (and bumps).
func _stone_mat(col: Color, scale: float, cobbles: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.08 if cobbles else 0.05
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB if cobbles else FastNoiseLite.RETURN_CELL_VALUE
	var grad := Gradient.new()
	grad.set_color(0, col.darkened(0.25))
	grad.set_color(1, col.lightened(0.08))
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.color_ramp = grad
	tex.seamless = true
	m.albedo_texture = tex
	var ntex := NoiseTexture2D.new()
	ntex.noise = noise
	ntex.seamless = true
	ntex.as_normal_map = true
	ntex.bump_strength = 4.0
	m.normal_enabled = true
	m.normal_texture = ntex
	m.roughness = 0.95
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	return m

func _plain_mat(col: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	return m

func _box(at: Vector3, size: Vector3, mat: Material, solid := false) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.size = size
	b.position = at
	b.material = mat
	b.use_collision = solid
	level_root.add_child(b)
	return b

## Decoration mesh (no collision; cheaper than CSG for many small pieces).
func _mesh(mesh: Mesh, at: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	level_root.add_child(mi)
	return mi

func _cube(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m

func _battlements(h: float, mat: Material) -> void:
	var merlon := _cube(Vector3(1.0, 1.0, 2.0))
	var merlon_x := _cube(Vector3(2.0, 1.0, 1.0))
	var x := -h + 3.0
	while x <= h - 3.0:
		_mesh(merlon_x, Vector3(x, WALL_H + 0.5, -h), mat)
		if absf(x) > 4.5:   # the gatehouse has its own top
			_mesh(merlon_x, Vector3(x, WALL_H + 0.5, h), mat)
		_mesh(merlon, Vector3(-h, WALL_H + 0.5, x), mat)
		_mesh(merlon, Vector3(h, WALL_H + 0.5, x), mat)
		x += 2.0

func _tower(at: Vector3, mat: Material) -> void:
	var t := CSGCylinder3D.new()
	t.radius = 3.0
	t.height = WALL_H + 4.0
	t.sides = 16
	t.position = at + Vector3(0, t.height / 2, 0)
	t.material = mat
	t.use_collision = true
	level_root.add_child(t)
	var roof := CylinderMesh.new()
	roof.top_radius = 0.0
	roof.bottom_radius = 3.6
	roof.height = 4.0
	roof.radial_segments = 16
	_mesh(roof, at + Vector3(0, WALL_H + 6.0, 0), _plain_mat(Color(0.35, 0.18, 0.15), 0.8))
	# Arrow slits facing the yard.
	var slit := _cube(Vector3(0.25, 1.2, 0.25))
	var inward := (-at).normalized() * 3.0
	_mesh(slit, at + inward + Vector3(0, WALL_H + 1.5, 0), _plain_mat(Color(0.05, 0.05, 0.06)))

func _gatehouse(at: Vector3, gate_w: float, mat: Material) -> void:
	for sx in [-1.0, 1.0]:
		_box(at + Vector3(sx * (gate_w / 2 + 1.0), (WALL_H + 2) / 2, 0), Vector3(2.0, WALL_H + 2, 3.0), mat, true)
	_box(at + Vector3(0, WALL_H - 0.5, 0), Vector3(gate_w, 3.0, 3.0), mat, true)
	# Closed portcullis / gate (blocks the way out).
	_box(at + Vector3(0, (WALL_H - 2) / 2, 0.2), Vector3(gate_w, WALL_H - 2, 0.4), _plain_mat(WOOD, 0.85), true)
	var bar := _cube(Vector3(0.15, WALL_H - 2, 0.15))
	var iron := _plain_mat(Color(0.18, 0.18, 0.2), 0.5)
	for i in 7:
		_mesh(bar, at + Vector3(-gate_w / 2 + 0.5 + i * (gate_w - 1) / 6.0, (WALL_H - 2) / 2, -0.1), iron)
	for i in 3:
		_mesh(_cube(Vector3(gate_w, 0.15, 0.15)), at + Vector3(0, 0.8 + i * 1.2, -0.1), iron)

func _banner(at: Vector3, col: Color) -> void:
	_mesh(_cube(Vector3(2.0, 3.6, 0.08)), at + Vector3(0, WALL_H - 2.4, 0), _plain_mat(col, 0.95))
	_mesh(_cube(Vector3(2.4, 0.15, 0.15)), at + Vector3(0, WALL_H - 0.55, 0.05), _plain_mat(WOOD))
	_mesh(_cube(Vector3(0.9, 0.9, 0.1)), at + Vector3(0, WALL_H - 2.2, 0.03), _plain_mat(Color(0.95, 0.8, 0.35), 0.5),
		Vector3(0, 0, PI / 4))

func _tree(at: Vector3) -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.3
	trunk.bottom_radius = 0.45
	trunk.height = 3.0
	_mesh(trunk, at + Vector3(0, 1.5, 0), _plain_mat(Color(0.35, 0.24, 0.15)))
	var leaf := _plain_mat(Color(0.25, 0.48, 0.2))
	for o in [Vector3(0, 4.0, 0), Vector3(0.9, 3.4, 0.4), Vector3(-0.8, 3.5, -0.5)]:
		var s := SphereMesh.new()
		s.radius = 1.8
		s.height = 3.2
		_mesh(s, at + (o as Vector3), leaf)
	# Planter ring
	var ringm := CylinderMesh.new()
	ringm.top_radius = 1.3
	ringm.bottom_radius = 1.4
	ringm.height = 0.4
	_mesh(ringm, at + Vector3(0, 0.2, 0), _plain_mat(STONE_DARK))

func _crate(at: Vector3, turn: float) -> void:
	_mesh(_cube(Vector3(1.1, 1.1, 1.1)), at + Vector3(0, 0.55, 0), _plain_mat(Color(0.55, 0.38, 0.2)), Vector3(0, turn, 0))

func _hay(at: Vector3) -> void:
	var c := CylinderMesh.new()
	c.top_radius = 0.7
	c.bottom_radius = 0.7
	c.height = 1.3
	_mesh(c, at + Vector3(0, 0.7, 0), _plain_mat(Color(0.85, 0.72, 0.35)), Vector3(0, 0, PI / 2))

func _weapon_rack(at: Vector3) -> void:
	var wood := _plain_mat(WOOD)
	_mesh(_cube(Vector3(3.0, 0.15, 0.3)), at + Vector3(0, 1.6, 0), wood)
	_mesh(_cube(Vector3(3.0, 0.15, 0.3)), at + Vector3(0, 0.3, 0), wood)
	for sx in [-1.4, 1.4]:
		_mesh(_cube(Vector3(0.15, 1.8, 0.3)), at + Vector3(sx, 0.9, 0), wood)
	var steel := _plain_mat(Color(0.7, 0.72, 0.75), 0.35)
	for i in 4:
		_mesh(_cube(Vector3(0.08, 1.9, 0.08)), at + Vector3(-1.0 + i * 0.65, 1.0, 0.2), steel, Vector3(0, 0, 0.12))

func _well(at: Vector3) -> void:
	var base := CylinderMesh.new()
	base.top_radius = 1.2
	base.bottom_radius = 1.25
	base.height = 1.0
	_mesh(base, at + Vector3(0, 0.5, 0), _stone_mat(STONE_DARK, 0.8, false))
	var water := CylinderMesh.new()
	water.top_radius = 0.95
	water.bottom_radius = 0.95
	water.height = 0.05
	_mesh(water, at + Vector3(0, 0.9, 0), _plain_mat(Color(0.2, 0.35, 0.5), 0.1))
	var wood := _plain_mat(WOOD)
	for sx in [-1.0, 1.0]:
		_mesh(_cube(Vector3(0.15, 2.0, 0.15)), at + Vector3(sx, 1.5, 0), wood)
	var roofm := PrismMesh.new()
	roofm.size = Vector3(2.8, 0.9, 1.6)
	_mesh(roofm, at + Vector3(0, 2.9, 0), _plain_mat(Color(0.35, 0.18, 0.15), 0.8))

func _ring(center: Vector3, r: float, n: int) -> Array:
	var out := []
	for i in n:
		var a := TAU * i / n
		out.append(center + Vector3(cos(a), 0, sin(a)) * r)
	return out

func _station(text: String, at: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 48
	l.pixel_size = 0.008
	l.outline_size = 10
	l.modulate = Color(1.0, 0.85, 0.5)
	l.position = at + Vector3(0, 3.3, 0)
	level_root.add_child(l)

func _dummy(at: Vector3, lvl: int, hits_back := false, scale := 1.0, nm := "Training Dummy",
		col := Color(0.72, 0.6, 0.38), hp_hits := 100) -> Node:
	var d: CharacterBody3D = DUMMY.new()
	d.max_health = hp_hits   # in standard hits (scaled to its level when it spawns)
	d.hits_back = hits_back
	d.dummy_scale = scale
	d.body_color = col
	d.display_name = nm
	d.setup(lvl)
	d.name = "%s_%d" % [nm.replace(" ", ""), enemies_root.get_child_count()]
	enemies_root.add_child(d)
	d.global_position = at + Vector3(0, d.ground_offset(), 0)
	d.spawn_position = d.global_position
	return d

func _ally(at: Vector3, lvl: int, nm: String) -> Node:
	var a: CharacterBody3D = ALLY_DUMMY.new()
	a.display_name = nm
	a.setup(lvl)
	enemies_root.add_child(a)
	a.global_position = at + Vector3(0, 0.95, 0)
	return a

# --- Panel (left): Reset + Leave ---------------------------------------------------------
# The numbers themselves are in the Details meter (autoload), shown on entry.

func _build_panel() -> void:
	var details := get_node_or_null("/root/Details")
	if details:
		details.meter_enabled = true   # always shown when you walk in
		details.reset()
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	var panel := PanelContainer.new()
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = 16
	panel.offset_top = -40
	panel.add_theme_stylebox_override("panel", UISkin.backdrop(-1.0, 6))
	layer.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	v.add_child(UISkin.label("Training Room", 13, UISkin.accent()))
	var key: String = get_node("/root/Settings").key_text("open_details")
	v.add_child(UISkin.label("Damage meter: %s" % key, 11, UISkin.DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	v.add_child(row)
	var reset := UIWindow.button("Reset", Vector2(64, 24))
	reset.tooltip_text = "Clear the recorded fights"
	reset.pressed.connect(func():
		if details:
			details.reset())
	row.add_child(reset)
	var leave := UIWindow.button("Leave", Vector2(64, 24))
	leave.tooltip_text = "Back to the lobby"
	leave.pressed.connect(func(): get_node("/root/GameManager").go_to_menu())
	row.add_child(leave)
	get_node("/root/Settings").register_hud(panel)
	UILayout.register(get_tree(), panel, "training", "Training Room")
