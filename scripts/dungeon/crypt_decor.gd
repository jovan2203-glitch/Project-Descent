extends RefCounted

# Crypt dressing: makes the procedural Crypt look like a crypt instead of grey
# boxes, without changing the layout, spawns or balance.
#   Shape (part of the rock, so it has collision and is in the navmesh):
#     - chamfered room corners, half-columns along the walls, a wall alcove
#       now and then, stone sarcophagi against some walls, boss-room braziers.
#   Look (visual only, no collision):
#     - procedural stone textures: rough walls, flagstone floors
#     - wall torches with flickering light and flames, dust motes
#     - floor clutter: skulls, bones, rubble, candles, urns
#     - a glowing summoning circle in the boss room
# Deterministic: its own RNG from the floor seed, so every machine in a party
# builds the same Crypt.
#
# Usage (from dungeon.gd, while building the rock and before baking the navmesh):
#   var decor := CryptDecor.new(seed, rooms, links, corridor_width)
#   decor.shape(rock)           # CSG additions
#   decor.dress(level_root)     # visuals

const FLICKER = preload("res://scripts/dungeon/flicker_light.gd")

var rng := RandomNumberGenerator.new()
var rooms: Array
var links: Array
var corridor_w: float

## Height of the rock mass top (walls are this tall above the floor).
const WALL_TOP := 2.0
const TORCH_Y := 1.45

static var _mats := {}

func _init(seed_value: int, room_list: Array, link_list: Array, corridor_width: float) -> void:
	rng.seed = seed_value + 424242
	rooms = room_list
	links = link_list
	corridor_w = corridor_width

# --- Materials (built once, shared) ------------------------------------------------------

static func wall_material() -> StandardMaterial3D:
	if not _mats.has("wall"):
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.02
		noise.fractal_octaves = 5
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.13, 0.13, 0.15))
		ramp.set_color(1, Color(0.36, 0.35, 0.37))
		var tex := NoiseTexture2D.new()
		tex.width = 256
		tex.height = 256
		tex.seamless = true
		tex.noise = noise
		tex.color_ramp = ramp
		var nrm := NoiseTexture2D.new()
		nrm.width = 256
		nrm.height = 256
		nrm.seamless = true
		nrm.noise = noise
		nrm.as_normal_map = true
		nrm.bump_strength = 6.0
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.normal_enabled = true
		m.normal_texture = nrm
		m.normal_scale = 1.2
		m.roughness = 0.95
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.35, 0.35, 0.35)
		_mats["wall"] = m
	return _mats["wall"]

static func top_material() -> StandardMaterial3D:
	if not _mats.has("top"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.05, 0.05, 0.06)
		m.roughness = 1.0
		_mats["top"] = m
	return _mats["top"]

static func floor_material() -> StandardMaterial3D:
	if not _mats.has("floor"):
		# Cellular noise = irregular flagstones with dark grout lines.
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		noise.frequency = 0.035
		noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
		noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.2, 1.0])
		ramp.colors = PackedColorArray([Color(0.05, 0.05, 0.05), Color(0.12, 0.115, 0.11),
			Color(0.24, 0.23, 0.22), Color(0.31, 0.3, 0.29)])
		var tex := NoiseTexture2D.new()
		tex.width = 512
		tex.height = 512
		tex.seamless = true
		tex.noise = noise
		tex.color_ramp = ramp
		var nrm := NoiseTexture2D.new()
		nrm.width = 512
		nrm.height = 512
		nrm.seamless = true
		nrm.noise = noise
		nrm.as_normal_map = true
		nrm.bump_strength = 4.0
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.normal_enabled = true
		m.normal_texture = nrm
		m.roughness = 0.85
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.12, 0.12, 0.12)
		_mats["floor"] = m
	return _mats["floor"]

static func _flat(key: String, col: Color, rough := 0.9, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = rough
		if energy > 0.0:
			m.emission_enabled = true
			m.emission = emission
			m.emission_energy_multiplier = energy
		_mats[key] = m
	return _mats[key]

# --- Room geometry helpers --------------------------------------------------------------

## Sides of room `i` that have a doorway, as unit directions (Vector2i).
func _door_sides(i: int) -> Array:
	var out := []
	for l in links:
		if int(l[0]) != i and int(l[1]) != i:
			continue
		var other: int = int(l[1]) if int(l[0]) == i else int(l[0])
		var d: Vector3 = rooms[other]["center"] - rooms[i]["center"]
		out.append(Vector2i(signi(int(d.x)), 0) if absf(d.x) > absf(d.z) else Vector2i(0, signi(int(d.z))))
	return out

## Points along each wall of a room: [{pos, inward, side, t}] where t = offset
## along the wall from its midpoint. Skips doorways.
func _wall_points(i: int, step: float, margin: float, door_clear: float) -> Array:
	var r: Dictionary = rooms[i]
	var c: Vector3 = r["center"]
	var h: Vector2 = r["size"] * 0.5
	var doors := _door_sides(i)
	var out := []
	for side in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var along_x: bool = side.y != 0            # wall runs along X
		var half: float = h.x if along_x else h.y
		var wall_pos: Vector3 = c + Vector3(side.x * h.x, 0, side.y * h.y)
		var t := -half + margin
		while t <= half - margin + 0.01:
			if not (doors.has(side) and absf(t) < door_clear):
				var p := wall_pos + (Vector3(t, 0, 0) if along_x else Vector3(0, 0, t))
				out.append({"pos": p, "inward": Vector3(-side.x, 0, -side.y), "side": side, "t": t})
			t += step
	return out

# --- Shape: CSG additions to the rock -------------------------------------------------------

func shape(rock: CSGCombiner3D) -> void:
	var wall := wall_material()
	var door_clear := corridor_w * 0.5 + 1.2
	for i in rooms.size():
		var r: Dictionary = rooms[i]
		var c: Vector3 = r["center"]
		var h: Vector2 = r["size"] * 0.5
		# Chamfered corners: rooms read as octagons instead of boxes.
		var cham := 1.6 if r["kind"] != "boss" else 2.6
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var b := CSGBox3D.new()
				b.size = Vector3(cham * 1.414, 3.0, cham * 1.414)
				b.rotation.y = PI / 4.0
				b.position = c + Vector3(sx * h.x, 0.5, sz * h.y)
				b.material = wall
				rock.add_child(b)
		# Half-columns along the walls.
		for wp in _wall_points(i, 3.3, cham + 1.2, door_clear):
			var col := CSGCylinder3D.new()
			col.radius = 0.42
			col.height = 3.0
			col.sides = 8
			col.material = wall
			col.position = wp["pos"] + Vector3(0, 0.5, 0)
			rock.add_child(col)
		# An alcove in a wall now and then (a candle / skull gets put in it).
		if r["kind"] != "boss" and rng.randf() < 0.55:
			var sides := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			var doors := _door_sides(i)
			var free := sides.filter(func(s): return not doors.has(s))
			if not free.is_empty():
				var s: Vector2i = free[rng.randi_range(0, free.size() - 1)]
				var along_x := s.y != 0
				var off := rng.randf_range(-1.0, 1.0) * ((h.x if along_x else h.y) - cham - 2.5)
				var at := c + Vector3(s.x * h.x, 0, s.y * h.y) + (Vector3(off, 0, 0) if along_x else Vector3(0, 0, off))
				var a := CSGBox3D.new()
				a.operation = CSGShape3D.OPERATION_SUBTRACTION
				a.size = Vector3(1.9, 3.2, 1.3) if along_x else Vector3(1.3, 3.2, 1.9)
				a.position = at + Vector3(s.x * 0.55, 1.6, s.y * 0.55)
				a.material = wall
				rock.add_child(a)
				r["alcove"] = at + Vector3(s.x * 0.45, 0, s.y * 0.45)
		# Sarcophagi against a wall in some combat / side rooms.
		if (r["kind"] == "combat" or r["kind"] == "side") and rng.randf() < 0.45:
			_sarcophagus(rock, i, door_clear)
		# Boss room braziers (stone bowls on plinths) in the corners.
		if r["kind"] == "boss":
			var ins := 3.3
			r["braziers"] = []
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var p := c + Vector3(sx * (h.x - ins), 0, sz * (h.y - ins))
					var plinth := CSGCylinder3D.new()
					plinth.radius = 0.45
					plinth.height = 1.1
					plinth.sides = 8
					plinth.material = wall
					plinth.position = p + Vector3(0, 0.55, 0)
					rock.add_child(plinth)
					var bowl := CSGCylinder3D.new()
					bowl.radius = 0.7
					bowl.height = 0.25
					bowl.sides = 10
					bowl.material = _flat("iron", Color(0.16, 0.14, 0.13), 0.6)
					bowl.position = p + Vector3(0, 1.22, 0)
					rock.add_child(bowl)
					r["braziers"].append(p + Vector3(0, 1.35, 0))

func _sarcophagus(rock: CSGCombiner3D, i: int, door_clear: float) -> void:
	var r: Dictionary = rooms[i]
	var pts := _wall_points(i, 1.0, 3.2, door_clear + 1.5)
	if pts.is_empty():
		return
	var wp: Dictionary = pts[rng.randi_range(0, pts.size() - 1)]
	var inward: Vector3 = wp["inward"]
	var along_x: bool = (wp["side"] as Vector2i).y != 0
	var center: Vector3 = wp["pos"] + inward * 1.0
	var box := CSGBox3D.new()
	box.size = Vector3(2.2, 0.8, 1.0) if along_x else Vector3(1.0, 0.8, 2.2)
	box.position = center + Vector3(0, 0.4, 0)
	box.material = wall_material()
	rock.add_child(box)
	var lid := CSGBox3D.new()
	lid.size = box.size + Vector3(0.14, -0.62, 0.14)
	lid.position = center + Vector3(0, 0.88, 0)
	lid.material = _flat("lid", Color(0.3, 0.29, 0.3), 0.8)
	rock.add_child(lid)
	r["sarcophagus"] = center

# --- Dress: visuals only -------------------------------------------------------------------

func dress(root: Node3D) -> void:
	var door_clear := corridor_w * 0.5 + 1.2
	_floors(root)
	for i in rooms.size():
		var r: Dictionary = rooms[i]
		var is_boss: bool = r["kind"] == "boss"
		# Wall torches: a few per room, spread out, never in a doorway.
		var pts := _wall_points(i, 3.3, 3.0, door_clear)
		var torches := 4 if is_boss else (3 if r["kind"] == "combat" else 2)
		var picks := _spread(pts, torches)
		for wp in picks:
			_torch(root, wp["pos"] + wp["inward"] * 0.22 + Vector3(0, TORCH_Y, 0), wp["inward"], is_boss)
		# Clutter along the walls.
		var clutter := rng.randi_range(4, 8) if not is_boss else 10
		var spots := _wall_points(i, 0.9, 2.0, door_clear + 0.5)
		for n in clutter:
			if spots.is_empty():
				break
			var wp: Dictionary = spots.pop_at(rng.randi_range(0, spots.size() - 1))
			var at: Vector3 = wp["pos"] + wp["inward"] * rng.randf_range(0.7, 1.3)
			_clutter(root, at, rng.randi_range(0, 5))
		if r.has("alcove"):
			_candles(root, r["alcove"] + Vector3(0, 0.02, 0))
			_skull(root, r["alcove"] + Vector3(0.25, 0.02, 0.1))
		if r.has("sarcophagus"):
			_candles(root, r["sarcophagus"] + Vector3(0, 0.95, 0))
		_dust(root, r)
		if is_boss:
			_summoning_circle(root, r["center"])
			for bp in r.get("braziers", []):
				_brazier_fire(root, bp)

## Evenly spread `count` points from a list (deterministic).
func _spread(pts: Array, count: int) -> Array:
	if pts.size() <= count:
		return pts
	var out := []
	var step := float(pts.size()) / count
	var start := rng.randf() * step
	for k in count:
		out.append(pts[int(start + k * step) % pts.size()])
	return out

## Flagstone floor quads over every room and corridor (just above the rock floor).
func _floors(root: Node3D) -> void:
	var mat := floor_material()
	for r in rooms:
		_floor_quad(root, r["center"], r["size"], mat)
	for l in links:
		var a: Vector3 = rooms[l[0]]["center"]
		var b: Vector3 = rooms[l[1]]["center"]
		var size := Vector2(absf(b.x - a.x), corridor_w) if absf(b.x - a.x) > absf(b.z - a.z) \
			else Vector2(corridor_w, absf(b.z - a.z))
		_floor_quad(root, (a + b) * 0.5, size, mat)

func _floor_quad(root: Node3D, center: Vector3, size: Vector2, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = size
	m.mesh = p
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = center + Vector3(0, 0.015, 0)
	root.add_child(m)

func _torch(root: Node3D, at: Vector3, inward: Vector3, boss: bool) -> void:
	var t := Node3D.new()
	root.add_child(t)
	t.global_position = at
	t.rotation.y = atan2(inward.x, inward.z)
	var iron := _flat("iron", Color(0.16, 0.14, 0.13), 0.6)
	var bracket := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.3, 0.12)
	bracket.mesh = bm
	bracket.material_override = iron
	bracket.position = Vector3(0, -0.2, -0.05)
	t.add_child(bracket)
	var stick := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.05
	sm.bottom_radius = 0.035
	sm.height = 0.45
	stick.mesh = sm
	stick.material_override = _flat("wood", Color(0.3, 0.2, 0.12))
	stick.rotation.x = deg_to_rad(20)
	stick.position = Vector3(0, 0, 0.08)
	t.add_child(stick)
	var col := Color(1.0, 0.35, 0.2) if boss else Color(1.0, 0.62, 0.3)
	_flame(t, Vector3(0, 0.27, 0.15), col, 0.6)
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.5
	light.omni_range = 7.5
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	light.position = Vector3(0, 0.35, 0.35)
	light.set_script(FLICKER)
	t.add_child(light)

## Small flickering flame: particles + a glowing core.
func _flame(parent: Node3D, at: Vector3, col: Color, scale: float) -> void:
	var core := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.07 * scale / 0.6
	s.height = 0.18 * scale / 0.6
	core.mesh = s
	core.material_override = _flat("flame_%s" % col.to_html(false), col.lightened(0.4), 1.0, col, 6.0)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.position = at
	parent.add_child(core)
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 0.55
	p.local_coords = false
	p.position = at
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 1.2, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.7
	p.scale_amount_min = 0.6 * scale
	p.scale_amount_max = 1.1 * scale
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var pm := SphereMesh.new()
	pm.radius = 0.06
	pm.height = 0.12
	pm.radial_segments = 6
	pm.rings = 3
	pm.material = _flat("flame_p_%s" % col.to_html(false), col, 1.0, col, 4.0)
	p.mesh = pm
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.9, 0.6))
	grad.set_color(1, Color(col, 0.0))
	p.color_ramp = grad
	parent.add_child(p)

func _clutter(root: Node3D, at: Vector3, kind: int) -> void:
	match kind:
		0, 1:
			_skull(root, at)
			if rng.randf() < 0.6:
				_bones(root, at + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4)))
		2:
			_bones(root, at)
		3:
			_rubble(root, at)
		4:
			_candles(root, at)
		_:
			_urn(root, at)

func _skull(root: Node3D, at: Vector3) -> void:
	var bone := _flat("bone", Color(0.78, 0.74, 0.62), 0.7)
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.13
	sm.height = 0.24
	sm.radial_segments = 10
	sm.rings = 6
	s.mesh = sm
	s.material_override = bone
	s.position = at + Vector3(0, 0.1, 0)
	s.rotation.y = rng.randf() * TAU
	root.add_child(s)
	var jaw := MeshInstance3D.new()
	var jm := BoxMesh.new()
	jm.size = Vector3(0.14, 0.06, 0.1)
	jaw.mesh = jm
	jaw.material_override = bone
	jaw.position = Vector3(0, -0.08, 0.06)
	s.add_child(jaw)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.035
		em.height = 0.07
		eye.mesh = em
		eye.material_override = _flat("socket", Color(0.03, 0.03, 0.03))
		eye.position = Vector3(side * 0.05, 0.01, 0.11)
		s.add_child(eye)

func _bones(root: Node3D, at: Vector3) -> void:
	var bone := _flat("bone", Color(0.78, 0.74, 0.62), 0.7)
	for n in rng.randi_range(2, 4):
		var b := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.03
		cm.height = rng.randf_range(0.3, 0.5)
		b.mesh = cm
		b.material_override = bone
		b.position = at + Vector3(rng.randf_range(-0.25, 0.25), 0.03, rng.randf_range(-0.25, 0.25))
		b.rotation = Vector3(PI / 2.0, rng.randf() * TAU, 0)
		root.add_child(b)

func _rubble(root: Node3D, at: Vector3) -> void:
	var stone := _flat("rubble", Color(0.27, 0.26, 0.27), 1.0)
	for n in rng.randi_range(3, 6):
		var r := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var s := rng.randf_range(0.12, 0.35)
		bm.size = Vector3(s, s * rng.randf_range(0.5, 0.9), s * rng.randf_range(0.7, 1.2))
		r.mesh = bm
		r.material_override = stone
		r.position = at + Vector3(rng.randf_range(-0.5, 0.5), bm.size.y * 0.4, rng.randf_range(-0.5, 0.5))
		r.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
		root.add_child(r)

func _candles(root: Node3D, at: Vector3) -> void:
	var wax := _flat("wax", Color(0.85, 0.8, 0.65), 0.6)
	var n := rng.randi_range(2, 4)
	for k in n:
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.035
		cm.bottom_radius = 0.04
		cm.height = rng.randf_range(0.12, 0.3)
		cm.radial_segments = 8
		c.mesh = cm
		c.material_override = wax
		var off := Vector3(rng.randf_range(-0.2, 0.2), cm.height * 0.5, rng.randf_range(-0.2, 0.2))
		c.position = at + off
		root.add_child(c)
		var f := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = 0.025
		fm.height = 0.07
		f.mesh = fm
		f.material_override = _flat("candle_flame", Color(1.0, 0.85, 0.5), 1.0, Color(1.0, 0.7, 0.3), 5.0)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.position = at + off + Vector3(0, cm.height * 0.5 + 0.04, 0)
		root.add_child(f)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.7, 0.35)
	glow.light_energy = 0.5
	glow.omni_range = 2.5
	glow.shadow_enabled = false
	glow.position = at + Vector3(0, 0.4, 0)
	glow.set_script(FLICKER)
	root.add_child(glow)

func _urn(root: Node3D, at: Vector3) -> void:
	var clay := _flat("urn", Color(0.35, 0.22, 0.15), 0.8)
	var u := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.5
	sm.radial_segments = 12
	sm.rings = 6
	u.mesh = sm
	u.material_override = clay
	var broken := rng.randf() < 0.4
	u.position = at + Vector3(0, 0.22 if not broken else 0.15, 0)
	if broken:
		u.rotation.z = PI / 2.0
	root.add_child(u)
	var neck := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.1
	nm.bottom_radius = 0.08
	nm.height = 0.12
	neck.mesh = nm
	neck.material_override = clay
	neck.position = Vector3(0, 0.26, 0)
	u.add_child(neck)

## Slowly drifting dust in the torchlight.
func _dust(root: Node3D, r: Dictionary) -> void:
	var p := CPUParticles3D.new()
	p.amount = 24
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var s: Vector2 = r["size"]
	p.emission_box_extents = Vector3(s.x * 0.45, 1.2, s.y * 0.45)
	p.position = r["center"] + Vector3(0, 1.4, 0)
	p.direction = Vector3(0.3, 0.2, 0.1)
	p.spread = 180.0
	p.gravity = Vector3(0, -0.02, 0)
	p.initial_velocity_min = 0.02
	p.initial_velocity_max = 0.1
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.03)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(1.0, 0.85, 0.65, 0.35)
	q.material = dm
	p.mesh = q
	root.add_child(p)

## Glowing summoning circle on the boss room floor: two rings and rune marks.
func _summoning_circle(root: Node3D, c: Vector3) -> void:
	var glow := _flat("circle", Color(0.6, 0.08, 0.05), 1.0, Color(1.0, 0.15, 0.08), 2.2)
	for rr in [[4.2, 0.08], [3.4, 0.05]]:
		var ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = float(rr[0]) - float(rr[1])
		t.outer_radius = float(rr[0])
		t.rings = 48
		t.ring_segments = 4
		ring.mesh = t
		ring.material_override = glow
		ring.scale = Vector3(1, 0.1, 1)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.position = c + Vector3(0, 0.03, 0)
		root.add_child(ring)
	for k in 8:
		var a := TAU * k / 8.0
		var mark := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 0.01, 0.5)
		mark.mesh = bm
		mark.material_override = glow
		mark.position = c + Vector3(cos(a), 0, sin(a)) * 3.8 + Vector3(0, 0.03, 0)
		mark.rotation.y = -a
		root.add_child(mark)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.2, 0.1)
	l.light_energy = 1.2
	l.omni_range = 6.0
	l.position = c + Vector3(0, 0.6, 0)
	l.set_script(FLICKER)
	root.add_child(l)

func _brazier_fire(root: Node3D, at: Vector3) -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	holder.global_position = at
	for k in 3:
		_flame(holder, Vector3(rng.randf_range(-0.2, 0.2), 0.05, rng.randf_range(-0.2, 0.2)), Color(1.0, 0.4, 0.15), 1.3)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.45, 0.2)
	l.light_energy = 2.2
	l.omni_range = 9.0
	l.shadow_enabled = false
	l.position = Vector3(0, 0.6, 0)
	l.set_script(FLICKER)
	holder.add_child(l)
