extends RefCounted

# Builds a dungeon layout (layouts.gd) out of a BIOME KIT (data/biomes/*.tres).
# The layout says where rooms and passages are; the kit says what they look
# like. Nothing here knows which dungeon it is.
#
#   Rock (CSG, has collision, the navmesh is baked from it):
#     solid blocks -> rooms, passages, cave bulges and wall niches carved out ->
#     ramps, corner pieces, pillars, wall chunks (boulders / buttresses / posts /
#     ice slabs) and the collision of big props added back.
#   Look (visual only): floors + floor stains, doorways, torches, fill lights,
#     big props, wall decorations, clutter, corridor dressing, boss centerpieces.
#
# Everything is PLANNED first (_plan: which wall spot gets a torch, a big prop,
# a wall decoration or a rock chunk) so the rock and the dressing never overlap
# and door lanes stay clear. Deterministic (its own RNG from the run seed) so
# every machine in a party builds the same dungeon.

const FLICKER = preload("res://scripts/dungeon/flicker_light.gd")

const WALL_H := 6.0        # carve height (the rock top is WALL_TOP above the floor)
const WALL_TOP := 2.0
const TORCH_Y := 1.45
const SLOT_SPACING := 1.9  # metres between wall spots
const MAX_INTRUDE := 1.3   # rock chunks never reach further into a room than this

## Big props: footprint along the wall (w) x depth into the room (d), and
## whether they get collision (a hidden block in the rock).
const BIG := {
	"sarcophagus": {"w": 2.0, "d": 1.0, "block": true},
	"coffin": {"w": 1.8, "d": 0.7, "block": true},
	"bookshelf": {"w": 1.6, "d": 0.5, "block": true},
	"weapon_rack": {"w": 1.3, "d": 0.45, "block": true},
	"crate_stack": {"w": 1.5, "d": 1.0, "block": true},
	"barrels": {"w": 1.5, "d": 0.8, "block": true},
	"statue": {"w": 1.0, "d": 1.0, "block": true},
	"hay": {"w": 1.5, "d": 0.9, "block": true},
	"table": {"w": 1.7, "d": 0.9, "block": true},
	"altar": {"w": 1.5, "d": 0.8, "block": true},
	"boulder": {"w": 1.4, "d": 1.1, "block": true},
	"ice_block": {"w": 1.3, "d": 1.0, "block": true},
	"bone_pile": {"w": 1.3, "d": 1.0, "block": false},
	"urn_group": {"w": 1.2, "d": 0.6, "block": false},
	# Story props, mostly hand-placed (PropMarker), any dungeon may use them.
	"page_pile": {"w": 1.2, "d": 0.9, "block": false},
	"loot_sacks": {"w": 1.4, "d": 0.9, "block": true},
	"broken_gate": {"w": 3.2, "d": 1.6, "block": false},
	"campfire": {"w": 1.4, "d": 1.4, "block": true},
	"bunk": {"w": 2.0, "d": 0.9, "block": true},
	"lectern": {"w": 0.7, "d": 0.6, "block": true},
	"target_dummy": {"w": 0.7, "d": 0.7, "block": true},
	"siege_cart": {"w": 2.4, "d": 1.4, "block": true},
	"tent": {"w": 2.4, "d": 2.0, "block": true},
	"ink_spill": {"w": 1.6, "d": 1.2, "block": false},
}

var kit: Resource
var rooms: Array
var links: Array
var cell := 22.0
var corridor := 3.6
var rng := RandomNumberGenerator.new()

## Per room: {"torches": [slot], "big": [[kind, slot]], "decor": [[kind, slot]],
## "chunks": [slot], "niches": [slot]}. A slot is {at (on the wall line), inward, along, side}.
var _plans: Array = []

static var _mats := {}

func _init(kit_res: Resource, layout: Dictionary, seed_value: int) -> void:
	kit = kit_res
	rooms = layout["rooms"]
	links = layout["links"]
	cell = float(layout.get("cell", 22.0))
	corridor = float(layout.get("corridor", 3.6))
	rng.seed = seed_value + 90210

func _style() -> String:
	var s: Variant = kit.get("wall_style")
	return str(s) if s != null and str(s) != "" else "masonry"

func _list(field: String) -> Array:
	var v: Variant = kit.get(field)
	return Array(v) if v != null else []

func _pick(arr: Array) -> Variant:
	return arr[rng.randi_range(0, arr.size() - 1)]

# --- Materials (per kit, shared) ------------------------------------------------------------

func _key(k: String) -> String:
	return "%s|%s" % [kit.resource_path if kit else "none", k]

func wall_mat() -> StandardMaterial3D:
	var k := _key("wall")
	if not _mats.has(k):
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.02
		noise.fractal_octaves = 5
		var ramp := Gradient.new()
		ramp.set_color(0, kit.wall_dark)
		ramp.set_color(1, kit.wall_light)
		var m := _noise_mat(noise, ramp, 256, 6.0, 0.95)
		m.uv1_scale = Vector3(0.35, 0.35, 0.35)
		_mats[k] = m
	return _mats[k]

func top_mat() -> StandardMaterial3D:
	return _flat(_key("top"), kit.top_color, 1.0)

func piece_mat() -> StandardMaterial3D:
	return _flat(_key("piece"), kit.piece_color, 0.8)

func ice_mat() -> StandardMaterial3D:
	var k := "ice_slab"
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.72, 0.88, 1.0, 0.85)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.08
		m.metallic = 0.2
		m.emission_enabled = true
		m.emission = Color(0.35, 0.6, 0.9)
		m.emission_energy_multiplier = 0.35
		_mats[k] = m
	return _mats[k]

func wood_mat() -> StandardMaterial3D:
	return _flat("wood", Color(0.36, 0.24, 0.13), 0.9)

func dark_wood_mat() -> StandardMaterial3D:
	return _flat("wood_dark", Color(0.2, 0.13, 0.07), 0.9)

func iron_mat() -> StandardMaterial3D:
	return _flat("iron", Color(0.16, 0.14, 0.13), 0.6)

func bone_mat() -> StandardMaterial3D:
	return _flat("bone", Color(0.85, 0.82, 0.72))

func floor_mat() -> StandardMaterial3D:
	var k := _key("floor")
	if _mats.has(k):
		return _mats[k]
	var noise := FastNoiseLite.new()
	var ramp := Gradient.new()
	var m: StandardMaterial3D
	match str(kit.floor_pattern):
		"rough":
			noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			noise.frequency = 0.05
			noise.fractal_octaves = 4
			ramp.set_color(0, kit.floor_dark)
			ramp.set_color(1, kit.floor_light)
			m = _noise_mat(noise, ramp, 256, 5.0, 0.95)
			m.uv1_scale = Vector3(0.2, 0.2, 0.2)
		"ice":
			noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
			noise.frequency = 0.015
			noise.fractal_octaves = 3
			ramp.set_color(0, kit.floor_dark)
			ramp.set_color(1, kit.floor_light)
			m = _noise_mat(noise, ramp, 256, 1.5, 0.15)
			m.metallic = 0.15
			m.uv1_scale = Vector3(0.1, 0.1, 0.1)
		"planks":
			noise.noise_type = FastNoiseLite.TYPE_CELLULAR
			noise.frequency = 0.04
			noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
			ramp.offsets = PackedFloat32Array([0.0, 0.1, 1.0])
			ramp.colors = PackedColorArray([Color(0.05, 0.035, 0.02), kit.floor_dark, kit.floor_light])
			m = _noise_mat(noise, ramp, 256, 3.0, 0.8)
			m.uv1_scale = Vector3(0.6, 0.6, 0.08)   # long boards
		_:
			noise.noise_type = FastNoiseLite.TYPE_CELLULAR
			noise.frequency = 0.035
			noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
			noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
			ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.2, 1.0])
			ramp.colors = PackedColorArray([Color(0.05, 0.05, 0.05), kit.floor_dark, kit.floor_dark.lerp(kit.floor_light, 0.6), kit.floor_light])
			m = _noise_mat(noise, ramp, 512, 4.0, 0.85)
			m.uv1_scale = Vector3(0.12, 0.12, 0.12)
	_mats[k] = m
	return m

static func _noise_mat(noise: FastNoiseLite, ramp: Gradient, res: int, bump: float, rough: float) -> StandardMaterial3D:
	var tex := NoiseTexture2D.new()
	tex.width = res
	tex.height = res
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = ramp
	var nrm := NoiseTexture2D.new()
	nrm.width = res
	nrm.height = res
	nrm.seamless = true
	nrm.noise = noise
	nrm.as_normal_map = true
	nrm.bump_strength = bump
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.normal_enabled = true
	m.normal_texture = nrm
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	return m

static func _flat(key: String, col: Color, rough := 0.9, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = rough
		if col.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if energy > 0.0:
			m.emission_enabled = true
			m.emission = emission
			m.emission_energy_multiplier = energy
		_mats[key] = m
	return _mats[key]

static func _decal_mat(col: Color) -> StandardMaterial3D:
	var key := "decal_%s" % col.to_html(true)
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.6
		m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_mats[key] = m
	return _mats[key]

# --- Planning ------------------------------------------------------------------------------

## Sides of room i that have a passage, as unit Vector2i directions.
func door_sides(i: int) -> Array:
	var out: Array = []
	for l in links:
		var other := -1
		if int(l[0]) == i:
			other = int(l[1])
		elif int(l[1]) == i:
			other = int(l[0])
		if other < 0:
			continue
		var d: Vector3 = rooms[other]["center"] - rooms[i]["center"]
		out.append(Vector2i(int(signf(d.x)), 0) if absf(d.x) > absf(d.z) else Vector2i(0, int(signf(d.z))))
	return out

## Is `p` (with `radius`) in the walking lane of one of room i's doorways: the
## strip from the room's middle out to that door, as wide as the passage plus room
## to step around? Pillars, centerpieces and other blockers stay out of it.
func in_door_lane(i: int, p: Vector3, radius: float) -> bool:
	if i < 0:
		return false
	var c: Vector3 = rooms[i]["center"]
	for s: Vector2i in door_sides(i):
		var d := Vector2(s.x, s.y)
		var rel := Vector2(p.x - c.x, p.z - c.z)
		if rel.dot(d) > -radius and absf(rel.dot(Vector2(-d.y, d.x))) < corridor * 0.5 + radius + 0.6:
			return true
	return false

## Evenly spaced spots along room i's walls (jittered), away from corners and doorways.
func _wall_slots(i: int) -> Array:
	var r: Dictionary = rooms[i]
	var doors := door_sides(i)
	var out: Array = []
	for s in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var d := Vector3(s.x, 0, s.y)
		var half: float = (r["size"].x if s.x != 0 else r["size"].y) * 0.5
		var span: float = (r["size"].y if s.x != 0 else r["size"].x) * 0.5 - 1.3
		var across := Vector3(d.z, 0, d.x)
		var off := -span
		while off <= span:
			var o := off + rng.randf_range(-0.3, 0.3)
			off += SLOT_SPACING
			if doors.has(s) and absf(o) < corridor * 0.5 + 1.0:
				continue
			if blocked_in_room(i, r["center"] + d * (half - 0.8) + across * o, 0.3):
				continue   # a wall block or placed prop stands here
			out.append({"at": r["center"] + d * half + across * o, "inward": -d, "along": across, "side": s})
	return out

## Rock between room i's wall at `slot` and the edge of its grid cell.
func _wall_thickness(i: int, slot: Dictionary) -> float:
	var r: Dictionary = rooms[i]
	var inward: Vector3 = slot["inward"]
	var half: float = (r["size"].x if absf(inward.x) > 0.5 else r["size"].y) * 0.5
	return cell * 0.5 - half

func _plan() -> void:
	_plans.clear()
	var big_kinds: Array = _list("big_props").filter(func(k): return BIG.has(str(k)))
	var decor_kinds: Array = _list("wall_decor").filter(func(k): return str(k) != "cobweb")
	var density := float(kit.prop_density) / 4.0
	var chunk_share := clampf(float(kit.get("chunk_density") if kit.get("chunk_density") != null else 0.6), 0.0, 1.0)
	for i in rooms.size():
		var r: Dictionary = rooms[i]
		var slots := _wall_slots(i)
		var kinds: Array = big_kinds
		if not r.get("big_props", []).is_empty():
			kinds = Array(r["big_props"]).filter(func(k): return BIG.has(str(k)))
		# Shuffle with our own RNG (deterministic for the party).
		for k in range(slots.size() - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var tmp: Variant = slots[k]
			slots[k] = slots[j]
			slots[j] = tmp
		var perimeter: float = 2.0 * (r["size"].x + r["size"].y)
		var plan := {"torches": [], "big": [], "decor": [], "chunks": [], "niches": []}
		var n_torch := 4 if r["kind"] == "boss" else (1 if r["kind"] == "junction" else 2)
		if perimeter > 60.0 and r["kind"] != "boss":
			n_torch += 1
		var n_big := int(round(perimeter / 16.0 * density)) if not kinds.is_empty() else 0
		if r["kind"] == "boss":
			n_big = mini(n_big, 2)
		var n_decor := int(round(perimeter / 11.0 * density)) if not decor_kinds.is_empty() else 0
		var used := 0
		for n in n_torch:
			if used < slots.size():
				plan["torches"].append(slots[used])
				used += 1
		for n in n_big:
			if used < slots.size():
				plan["big"].append([str(_pick(kinds)), slots[used]])
				used += 1
		for n in n_decor:
			if used < slots.size():
				plan["decor"].append([str(_pick(decor_kinds)), slots[used]])
				used += 1
		# What's left: break the wall up.
		while used < slots.size():
			if rng.randf() < chunk_share:
				if _style() == "masonry" and rng.randf() < 0.3 and _wall_thickness(i, slots[used]) >= 1.4:
					plan["niches"].append(slots[used])
				else:
					plan["chunks"].append(slots[used])
			used += 1
		_plans.append(plan)

# --- Rock --------------------------------------------------------------------------------

func build_rock(level_root: Node3D) -> CSGCombiner3D:
	_plan()
	var rock := CSGCombiner3D.new()
	rock.name = "Rock"
	rock.use_collision = true
	level_root.add_child(rock)
	var wall := wall_mat()
	# 1. Solid blocks: one per room cell, plus one around every ramp.
	for r in rooms:
		var c: Vector3 = r["center"]
		_box(rock, Vector3(cell + 0.02, WALL_TOP + 1.0, cell + 0.02), c + Vector3(0, (WALL_TOP - 1.0) * 0.5, 0), top_mat())
	for l in links:
		var a: Dictionary = rooms[l[0]]
		var b: Dictionary = rooms[l[1]]
		var ya: float = a["center"].y
		var yb: float = b["center"].y
		if is_equal_approx(ya, yb):
			continue
		var lo := minf(ya, yb)
		var hi := maxf(ya, yb)
		var mid: Vector3 = (a["center"] + b["center"]) * 0.5
		var along_x := absf(b["center"].x - a["center"].x) > absf(b["center"].z - a["center"].z)
		var size := Vector3(cell, hi - lo + WALL_TOP + 1.0, corridor + 4.0) if along_x \
			else Vector3(corridor + 4.0, hi - lo + WALL_TOP + 1.0, cell)
		_box(rock, size, Vector3(mid.x, lo - 1.0 + size.y * 0.5, mid.z), top_mat())
	# 2. Carve rooms, cave bulges, passages, ramps, niches.
	for r in rooms:
		_carve(rock, r["center"], Vector3(r["size"].x, WALL_H, r["size"].y), wall)
	if _style() == "rough":
		for i in rooms.size():
			_bulges(rock, i, wall)
	var ramps: Array = []
	for l in links:
		var a: Dictionary = rooms[l[0]]
		var b: Dictionary = rooms[l[1]]
		if is_equal_approx(float(a["center"].y), float(b["center"].y)):
			var ac: Vector3 = a["center"]
			var bc: Vector3 = b["center"]
			var size := Vector3(absf(bc.x - ac.x), WALL_H, corridor) if absf(bc.x - ac.x) > absf(bc.z - ac.z) \
				else Vector3(corridor, WALL_H, absf(bc.z - ac.z))
			_carve(rock, (ac + bc) * 0.5, size, wall)
		else:
			ramps.append(_ramp_ends(a, b))
	for rp in ramps:
		_carve_ramp(rock, rp[0], rp[1], wall)
	for i in rooms.size():
		for slot in _plans[i]["niches"]:
			_niche(rock, slot, wall)
	# 3. Add back: stairs, corners, pillars, wall chunks, corridor chunks, prop collision.
	for rp in ramps:
		_stairs(rock, rp[0], rp[1])
	_corner_pieces(rock)
	_pillars(rock)
	for i in rooms.size():
		for slot in _plans[i]["chunks"]:
			_chunk(rock, slot)
		for bp in _plans[i]["big"]:
			_prop_blocker(rock, str(bp[0]), bp[1])
	_corridor_chunks(rock)
	_centerpiece_blockers(rock)
	# Hand-made maps: wall blocks and the collision of hand-placed props.
	for i in rooms.size():
		for pc in rooms[i].get("pieces", []):
			if str(pc["kind"]) != "wall":
				continue
			var s: Vector2 = pc["params"].get("size", Vector2(2, 2))
			var h := float(pc["params"].get("height", WALL_TOP))
			_box(rock, Vector3(s.x, h + 1.0, s.y), pc["at"] + Vector3(0, (h - 1.0) * 0.5, 0), wall)
		for pp in rooms[i].get("props", []):
			_prop_blocker(rock, str(pp["kind"]), _prop_slot(pp))
	return rock

# --- Hand-made rooms: wall blocks and placed props (layouts.gd from_scene) ------------------------

## Room i's wall blocks (SetPieceMarker kind "wall") as rects on the floor (world x/z).
func wall_blocks(i: int) -> Array:
	var out: Array = []
	for pc in rooms[i].get("pieces", []):
		if str(pc["kind"]) == "wall":
			var s: Vector2 = pc["params"].get("size", Vector2(2, 2))
			var at: Vector3 = pc["at"]
			out.append(Rect2(at.x - s.x * 0.5, at.z - s.y * 0.5, s.x, s.y))
	return out

## Is `p` inside (or within `margin` of) one of room i's wall blocks or blocking placed props?
func blocked_in_room(i: int, p: Vector3, margin: float) -> bool:
	var q := Vector2(p.x, p.z)
	for rc: Rect2 in wall_blocks(i):
		if rc.grow(margin).has_point(q):
			return true
	for pp in rooms[i].get("props", []):
		var info: Dictionary = BIG.get(str(pp["kind"]), {"w": 1.0, "d": 1.0})
		var r := maxf(float(info["w"]), float(info["d"])) * 0.5
		if q.distance_to(Vector2(pp["at"].x, pp["at"].z)) < r + margin:
			return true
	return false

## A placed prop as a wall-style slot, so _big_prop and _prop_blocker build it
## centred on its marker. Its front faces the marker's yaw (0 = +Z).
func _prop_slot(pp: Dictionary) -> Dictionary:
	var yaw := float(pp["yaw"])
	var inward := Vector3(sin(yaw), 0, cos(yaw))
	var d := float(BIG.get(str(pp["kind"]), {"d": 1.0})["d"])
	return {"at": pp["at"] - inward * (d * 0.5 + 0.1), "inward": inward, "along": Vector3(inward.z, 0, -inward.x), "side": Vector2i.ZERO}

func _box(rock: CSGCombiner3D, size: Vector3, center: Vector3, mat: Material) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.size = size
	box.position = center
	box.material = mat
	rock.add_child(box)
	return box

func _carve(rock: CSGCombiner3D, center: Vector3, size: Vector3, mat: Material) -> void:
	var box := _box(rock, size, center + Vector3(0, size.y * 0.5, 0), mat)
	box.operation = CSGShape3D.OPERATION_SUBTRACTION

## Cave rooms: round bites out of the walls so they aren't rectangles.
func _bulges(rock: CSGCombiner3D, i: int, mat: Material) -> void:
	var r: Dictionary = rooms[i]
	var spare: float = (cell - maxf(r["size"].x, r["size"].y)) * 0.5 - 0.6   # rock left around the room
	if spare < 0.4:
		return
	for s in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var d := Vector3(s.x, 0, s.y)
		var half: float = (r["size"].x if s.x != 0 else r["size"].y) * 0.5
		var span: float = (r["size"].y if s.x != 0 else r["size"].x) * 0.5 - 2.0
		if span <= 0.5:
			continue
		for n in rng.randi_range(1, 2):
			var rad := rng.randf_range(2.0, 3.4)
			var out := rng.randf_range(0.4, minf(spare, 1.2))
			var at: Vector3 = r["center"] + d * (half + out - rad) + Vector3(d.z, 0, d.x) * rng.randf_range(-span, span)
			var cyl := CSGCylinder3D.new()
			cyl.operation = CSGShape3D.OPERATION_SUBTRACTION
			cyl.radius = rad
			cyl.height = WALL_H
			cyl.sides = 14
			cyl.material = mat
			cyl.position = at + Vector3(0, WALL_H * 0.5, 0)
			rock.add_child(cyl)

## Masonry: a burial niche cut into the wall (candles / a skull go in it).
func _niche(rock: CSGCombiner3D, slot: Dictionary, mat: Material) -> void:
	var inward: Vector3 = slot["inward"]
	var b := CSGBox3D.new()
	b.operation = CSGShape3D.OPERATION_SUBTRACTION
	b.size = Vector3(1.1, 1.3, 1.1)
	b.material = mat
	b.position = slot["at"] - inward * 0.45 + Vector3(0, 0.35 + 0.65, 0)
	rock.add_child(b)

## A piece of wall sticking out, by wall style. Never deeper than MAX_INTRUDE.
func _chunk(rock: CSGCombiner3D, slot: Dictionary) -> void:
	var at: Vector3 = slot["at"]
	var inward: Vector3 = slot["inward"]
	var along: Vector3 = slot["along"]
	match _style():
		"rough":
			var rad := rng.randf_range(0.55, 1.05)
			var sph := CSGSphere3D.new()
			sph.radius = rad
			sph.radial_segments = 10
			sph.rings = 6
			sph.material = wall_mat()
			var depth := minf(rad * 0.9, MAX_INTRUDE)
			sph.position = at + inward * (depth - rad) + along * rng.randf_range(-0.3, 0.3) + Vector3(0, rng.randf_range(0.1, 0.8), 0)
			sph.scale = Vector3(1.0, rng.randf_range(0.7, 1.3), 1.0)
			rock.add_child(sph)
			if rng.randf() < 0.5:   # a second, smaller rock at its foot
				var s2 := CSGSphere3D.new()
				s2.radius = rad * 0.55
				s2.radial_segments = 8
				s2.rings = 5
				s2.material = wall_mat()
				s2.position = at + inward * (rad * 0.4) + along * rng.randf_range(-0.8, 0.8) + Vector3(0, 0.1, 0)
				rock.add_child(s2)
		"timber":
			var post := CSGBox3D.new()
			post.size = Vector3(0.32, WALL_TOP + 0.4, 0.32)
			post.material = dark_wood_mat()
			post.position = at + inward * 0.12 + Vector3(0, (WALL_TOP + 0.4) * 0.5, 0)
			rock.add_child(post)
			if rng.randf() < 0.4:   # fallen stones at its foot
				var st := CSGBox3D.new()
				st.size = Vector3(0.7, 0.45, 0.6)
				st.material = wall_mat()
				st.position = at + inward * 0.35 + along * 0.6 + Vector3(0, 0.22, 0)
				st.rotation.y = rng.randf_range(-0.4, 0.4)
				rock.add_child(st)
		"ice":
			for n in rng.randi_range(1, 2):
				var slab := CSGBox3D.new()
				var h := rng.randf_range(1.0, WALL_TOP + 0.3)
				slab.size = Vector3(rng.randf_range(0.5, 0.9), h, rng.randf_range(0.4, 0.8))
				slab.material = ice_mat()
				slab.position = at + inward * rng.randf_range(0.1, 0.4) + along * rng.randf_range(-0.5, 0.5) + Vector3(0, h * 0.5, 0)
				slab.rotation = Vector3(rng.randf_range(-0.25, 0.25), rng.randf() * TAU, rng.randf_range(-0.25, 0.25))
				rock.add_child(slab)
		_:   # masonry: a buttress
			var bt := CSGBox3D.new()
			var deep := rng.randf_range(0.35, 0.6)
			bt.size = Vector3(0.8, WALL_TOP + 1.0, deep * 2.0) if absf(inward.x) < 0.5 else Vector3(deep * 2.0, WALL_TOP + 1.0, 0.8)
			bt.material = wall_mat()
			bt.position = at + Vector3(0, (WALL_TOP - 1.0) * 0.5, 0)
			rock.add_child(bt)

## Hidden low block under a big prop, so it has collision and the navmesh goes around it.
func _prop_blocker(rock: CSGCombiner3D, kind: String, slot: Dictionary) -> void:
	var info: Dictionary = BIG.get(kind, {})
	if not info.get("block", false):
		return
	var w := float(info["w"]) - 0.15
	var d := float(info["d"]) - 0.15
	var inward: Vector3 = slot["inward"]
	var size := Vector3(w, 0.55, d) if absf(inward.x) < 0.5 else Vector3(d, 0.55, w)
	_box(rock, size, slot["at"] + inward * (float(info["d"]) * 0.5 + 0.1) + Vector3(0, 0.27, 0), top_mat())

## Passages: rocks / posts / slabs along their walls too.
func _corridor_chunks(rock: CSGCombiner3D) -> void:
	for seg in _corridor_segments():
		var a: Vector3 = seg["a"]
		var b: Vector3 = seg["b"]
		var along: Vector3 = seg["along"]
		var side: Vector3 = seg["side"]
		var length := a.distance_to(b)
		var t := rng.randf_range(0.8, 2.0)
		while t < length - 0.8:
			for s: float in [-1.0, 1.0]:
				if rng.randf() > 0.55:
					continue
				var wall_at := a + along * t + side * s * corridor * 0.5
				var inward: Vector3 = -side * s
				match _style():
					"rough":
						var sph := CSGSphere3D.new()
						sph.radius = rng.randf_range(0.35, 0.6)
						sph.radial_segments = 8
						sph.rings = 5
						sph.material = wall_mat()
						sph.position = wall_at - inward * (sph.radius - 0.35) + Vector3(0, rng.randf_range(0.1, 0.6), 0)
						rock.add_child(sph)
					"timber":
						var post := CSGBox3D.new()
						post.size = Vector3(0.25, WALL_TOP + 0.4, 0.25)
						post.material = dark_wood_mat()
						post.position = wall_at + inward * 0.1 + Vector3(0, (WALL_TOP + 0.4) * 0.5, 0)
						rock.add_child(post)
					"ice":
						var slab := CSGBox3D.new()
						var h := rng.randf_range(0.6, 1.8)
						slab.size = Vector3(0.4, h, 0.4)
						slab.material = ice_mat()
						slab.position = wall_at + inward * 0.12 + Vector3(0, h * 0.5, 0)
						slab.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, 0)
						rock.add_child(slab)
					_:
						var pil := CSGBox3D.new()
						pil.size = Vector3(0.5, WALL_TOP + 1.0, 0.5)
						pil.material = wall_mat()
						pil.position = wall_at + Vector3(0, (WALL_TOP - 1.0) * 0.5, 0)
						rock.add_child(pil)
			t += rng.randf_range(2.2, 3.4)

## Straight passage pieces between two rooms' walls (same floor height only).
func _corridor_segments() -> Array:
	var out: Array = []
	for l in links:
		var ra: Dictionary = rooms[l[0]]
		var rb: Dictionary = rooms[l[1]]
		var ac: Vector3 = ra["center"]
		var bc: Vector3 = rb["center"]
		if not is_equal_approx(ac.y, bc.y):
			continue
		var d := bc - ac
		var along_x := absf(d.x) > absf(d.z)
		var along := Vector3(signf(d.x), 0, 0) if along_x else Vector3(0, 0, signf(d.z))
		var ha: float = (ra["size"].x if along_x else ra["size"].y) * 0.5
		var hb: float = (rb["size"].x if along_x else rb["size"].y) * 0.5
		var a := ac + along * ha
		var b := bc - along * hb
		if a.distance_to(b) < 2.5:
			continue
		out.append({"a": a, "b": b, "along": along, "side": Vector3(along.z, 0, along.x)})
	return out

## The two ends of a ramp: on the wall of room a and the wall of room b (1 m inside each).
func _ramp_ends(a: Dictionary, b: Dictionary) -> Array:
	var ac: Vector3 = a["center"]
	var bc: Vector3 = b["center"]
	var d := bc - ac
	d.y = 0.0
	var along_x := absf(d.x) > absf(d.z)
	var dir := Vector3(signf(d.x), 0, 0) if along_x else Vector3(0, 0, signf(d.z))
	var ha: float = (a["size"].x if along_x else a["size"].y) * 0.5
	var hb: float = (b["size"].x if along_x else b["size"].y) * 0.5
	var p0 := Vector3(ac.x, ac.y, ac.z) + dir * (ha - 1.0)
	var p1 := Vector3(bc.x, bc.y, bc.z) - dir * (hb - 1.0)
	return [p0, p1]

# Ramps (every height change between two linked rooms). A ramp runs from p0 (on
# the floor of one room, 1 m inside its wall) to p1 (the same in the other room).
#   carve   the passage, from the lower floor up to the ceiling (CSG)
#   stairs  scenes/dungeon/pieces/stairs.tscn on the lower floor: one clean slope
#           collider to walk on + stepped visuals. (It used to be a CSG wedge cut
#           out of the rock.)
const STAIRS = preload("res://scenes/dungeon/pieces/stairs.tscn")

## Unit vector along the ramp on the ground (p0 -> p1).
func _ramp_dir(p0: Vector3, p1: Vector3) -> Vector3:
	var d := p1 - p0
	d.y = 0.0
	return d.normalized()

## An upright box along the ramp: from `from` to `to` metres past p0 (measured on
## the ground), `width` wide, between heights y_lo and y_hi.
func _ramp_box(p0: Vector3, p1: Vector3, from: float, to: float, width: float, y_lo: float, y_hi: float) -> CSGBox3D:
	var dir := _ramp_dir(p0, p1)
	var box := CSGBox3D.new()
	var along_x := absf(dir.x) > absf(dir.z)
	var length := to - from
	box.size = Vector3(length, y_hi - y_lo, width) if along_x else Vector3(width, y_hi - y_lo, length)
	var mid := p0 + dir * ((from + to) * 0.5)
	box.position = Vector3(mid.x, (y_lo + y_hi) * 0.5, mid.z)
	return box

## Horizontal length of the ramp.
func _ramp_run(p0: Vector3, p1: Vector3) -> float:
	return Vector2(p1.x - p0.x, p1.z - p0.z).length()

func _carve_ramp(rock: CSGCombiner3D, p0: Vector3, p1: Vector3, mat: Material) -> void:
	var body := _ramp_box(p0, p1, 0.0, _ramp_run(p0, p1), corridor, minf(p0.y, p1.y), maxf(p0.y, p1.y) + WALL_H)
	body.operation = CSGShape3D.OPERATION_SUBTRACTION
	body.material = mat
	rock.add_child(body)

## The stairs piece for a ramp: a child of the rock, so the navmesh bakes it.
func _stairs(rock: CSGCombiner3D, p0: Vector3, p1: Vector3) -> Node3D:
	var low := p0 if p0.y <= p1.y else p1
	var high := p1 if p0.y <= p1.y else p0
	var s: Node3D = STAIRS.instantiate()
	s.name = "Stairs"
	s.run = _ramp_run(low, high)
	s.rise = high.y - low.y
	s.width = corridor
	s.step_material = floor_mat()
	s.transform = Transform3D(Basis.looking_at(_ramp_dir(low, high), Vector3.UP), low)
	rock.add_child(s)
	return s

## Height of the ramp's surface `s` metres past p0 (on the ground), floors included:
## the floor of the p0 room before the ramp, the slope on it, the other floor after.
static func ramp_height(p0: Vector3, p1: Vector3, s: float) -> float:
	var run := Vector2(p1.x - p0.x, p1.z - p0.z).length()
	if run <= 0.001:
		return p0.y
	return lerpf(p0.y, p1.y, clampf(s / run, 0.0, 1.0))

## Is world point `p` on a floor of this dungeon: in a room or passage at that
## room's height, or on a ramp? The tops of the rock are not. (A baked nav mesh
## sits up to a cell above the ground, hence the tolerance.)
func is_floor(p: Vector3) -> bool:
	return floor_at(rooms, ramps(), cell, corridor, p)

const FLOOR_TOLERANCE := 0.8

static func floor_at(all_rooms: Array, all_ramps: Array, cell_size: float, corridor_width: float, p: Vector3) -> bool:
	# On a ramp (its height changes along it, so it is checked against the slope).
	for rp in all_ramps:
		var p0: Vector3 = rp[0]
		var p1: Vector3 = rp[1]
		var run := Vector2(p1.x - p0.x, p1.z - p0.z)
		var length := run.length()
		if length <= 0.001:
			continue
		var dir := run / length
		var rel := Vector2(p.x - p0.x, p.z - p0.z)
		var s := rel.dot(dir)
		var off := absf(rel.dot(Vector2(-dir.y, dir.x)))
		if s >= -0.5 and s <= length + 0.5 and off <= corridor_width * 0.5 + 0.5 \
				and absf(p.y - ramp_height(p0, p1, s)) <= FLOOR_TOLERANCE:
			return true
	# In the grid cell of a room (rooms, their bulges and their passages), at its height.
	var cx := int(floor(p.x / cell_size + 0.5))
	var cz := int(floor(p.z / cell_size + 0.5))
	for r in all_rooms:
		var rc: Vector2i = r["cell"]
		if rc.x == cx and rc.y == cz:
			return absf(p.y - float(r["center"].y)) <= FLOOR_TOLERANCE
	return false

## Every ramp of this dungeon as [p0, p1] (floor points at its two ends).
func ramps() -> Array:
	var out: Array = []
	for l in links:
		var a: Dictionary = rooms[l[0]]
		var b: Dictionary = rooms[l[1]]
		if not is_equal_approx(float(a["center"].y), float(b["center"].y)):
			out.append(_ramp_ends(a, b))
	return out

func _corner_pieces(rock: CSGCombiner3D) -> void:
	var style := str(kit.corner_piece)
	if style == "none" and _style() != "rough":
		return
	for r in rooms:
		var c: Vector3 = r["center"]
		var h: Vector2 = r["size"] * 0.5
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var at := c + Vector3(sx * h.x, 0, sz * h.y)
				if _style() == "rough":
					# Round the corner off with a big rock.
					var sph := CSGSphere3D.new()
					sph.radius = rng.randf_range(1.2, 1.7)
					sph.radial_segments = 10
					sph.rings = 6
					sph.material = wall_mat()
					sph.position = at + Vector3(0, rng.randf_range(0.0, 0.6), 0)
					rock.add_child(sph)
				elif style == "column":
					var p := CSGCylinder3D.new()
					p.radius = 0.75
					p.height = WALL_TOP + 1.0
					p.sides = 8
					p.material = wall_mat()
					p.position = at + Vector3(0, (WALL_TOP - 1.0) * 0.5, 0)
					rock.add_child(p)
				else:   # chamfer
					var b := CSGBox3D.new()
					b.size = Vector3(1.6, WALL_TOP + 1.0, 1.6)
					b.material = wall_mat()
					b.position = at + Vector3(0, (WALL_TOP - 1.0) * 0.5, 0)
					b.rotation.y = PI / 4.0
					rock.add_child(b)

## Pillars in some big combat rooms: cover and line-of-sight breakers.
func _pillars(rock: CSGCombiner3D) -> void:
	if not kit.props.has("pillar") and _style() != "rough":
		return
	for r in rooms:
		var s: Vector2 = r["size"]
		if (r["kind"] == "combat" or r["kind"] == "hub") and minf(s.x, s.y) >= 12 and rng.randf() < 0.6:
			var along_x := rng.randf() < 0.5
			# Never in a doorway's lane (a pillar at the foot of the stairs blocked them).
			var spots := func(ax: bool) -> Array:
				return [Vector3(-s.x * 0.25, 0, 0), Vector3(s.x * 0.25, 0, 0)] if ax \
					else [Vector3(0, 0, -s.y * 0.25), Vector3(0, 0, s.y * 0.25)]
			var clear := func(ax: bool) -> bool:
				for o in spots.call(ax):
					if in_door_lane(rooms.find(r), r["center"] + o, 0.9):
						return false
				return true
			if not clear.call(along_x):
				along_x = not along_x
				if not clear.call(along_x):
					continue
			for side: float in [-1.0, 1.0]:
				var off := Vector3(side * s.x * 0.25, 0, 0) if along_x else Vector3(0, 0, side * s.y * 0.25)
				if _style() == "rough":
					# A rock column: stacked, slightly offset boulders.
					for k in 3:
						var sph := CSGSphere3D.new()
						sph.radius = 0.85 - k * 0.15
						sph.radial_segments = 10
						sph.rings = 6
						sph.material = wall_mat()
						sph.position = r["center"] + off + Vector3(rng.randf_range(-0.15, 0.15), 0.4 + k * 0.7, rng.randf_range(-0.15, 0.15))
						rock.add_child(sph)
				else:
					var p := CSGCylinder3D.new()
					p.radius = 0.8
					p.height = WALL_TOP + 1.0
					p.sides = 8
					p.material = wall_mat()
					p.position = r["center"] + off + Vector3(0, (WALL_TOP - 1.0) * 0.5, 0)
					rock.add_child(p)

# --- Boss room centerpieces ---------------------------------------------------------------------

## Where a boss room's entrance is (unit direction from its center), for the throne etc.
func _entry_dir(i: int) -> Vector3:
	for l in links:
		if int(l[1]) == i:
			var d: Vector3 = rooms[int(l[0])]["center"] - rooms[i]["center"]
			d.y = 0.0
			return Vector3(signf(d.x), 0, 0) if absf(d.x) > absf(d.z) else Vector3(0, 0, signf(d.z))
	return Vector3.BACK

func _ring_points(r: Dictionary, count: int, frac: float, start := PI / 4.0) -> Array:
	var out: Array = []
	var rad: float = minf(r["size"].x, r["size"].y) * 0.5 * frac
	for k in count:
		var a := start + TAU * float(k) / float(count)
		out.append(r["center"] + Vector3(cos(a), 0, sin(a)) * rad)
	return out

## Room i's centerpiece: its own (hand-made maps), else the kit's in boss rooms.
func _room_cp(i: int) -> String:
	var own := str(rooms[i].get("centerpiece", ""))
	if own != "":
		return own
	if rooms[i]["kind"] != "boss" or kit.get("centerpiece") == null:
		return ""
	return str(kit.get("centerpiece"))

func _centerpiece_blockers(rock: CSGCombiner3D) -> void:
	for i in rooms.size():
		var r: Dictionary = rooms[i]
		var cp := _room_cp(i)
		if cp == "":
			continue
		match cp:
			"crystal_cluster", "ice_statues":
				for p in _ring_points(r, 4, 0.62):
					if in_door_lane(i, p, 0.6):
						continue
					var cyl := CSGCylinder3D.new()
					cyl.radius = 0.55
					cyl.height = 0.6
					cyl.sides = 8
					cyl.material = top_mat()
					cyl.position = p + Vector3(0, 0.3, 0)
					rock.add_child(cyl)
			"throne":
				var back := -_entry_dir(i)
				var half: float = (r["size"].x if absf(back.x) > 0.5 else r["size"].y) * 0.5
				var at: Vector3 = r["center"] + back * (half - 1.2)
				if not in_door_lane(i, at, 0.8):
					_box(rock, Vector3(1.4, 0.55, 1.4), at + Vector3(0, 0.27, 0), top_mat())

# --- Look (no collision) -------------------------------------------------------------------

func dress(root: Node3D, _unused: Callable = Callable()) -> void:
	_floors(root)
	_floor_decals(root)
	_doorways(root)
	for i in rooms.size():
		var r: Dictionary = rooms[i]
		var plan: Dictionary = _plans[i] if i < _plans.size() else {"torches": [], "big": [], "decor": [], "chunks": [], "niches": []}
		if kit.torches:
			for slot in plan["torches"]:
				_torch(root, slot["at"] + slot["inward"] * 0.12 + Vector3(0, TORCH_Y, 0), slot["inward"], r["kind"] == "boss")
		_fill_light(root, r)
		for bp in plan["big"]:
			_big_prop(root, str(bp[0]), bp[1])
		for dp in plan["decor"]:
			_wall_decor(root, str(dp[0]), dp[1])
		for slot in plan["niches"]:
			_niche_filling(root, slot)
		for slot in plan["chunks"]:
			if _style() == "timber" and rng.randf() < 0.6:
				_beam(root, slot)
		_cobwebs(root, i)
		_clutter(root, i)
		if _room_cp(i) != "":
			_centerpiece(root, i)
		for pp in r.get("props", []):
			_big_prop(root, str(pp["kind"]), _prop_slot(pp))
	_corridor_dressing(root)
	_optimize(root)

# --- Performance -------------------------------------------------------------------------------
# Decorations are hundreds of tiny meshes; drawn one by one that's thousands of
# draw calls. Here they're merged into one mesh per material per grid cell
# (still culled per area), and lights far from the camera fade out.

const LIGHT_FADE_BEGIN := 24.0
const LIGHT_FADE_LENGTH := 6.0

func _optimize(root: Node3D) -> void:
	var groups := {}   # "material id|cell x|cell z" -> {mat, st}
	var to_free: Array = []
	_collect(root, root, Transform3D.IDENTITY, groups, to_free, true)
	for n in to_free:
		n.get_parent().remove_child(n)
		n.free()
	for key in groups:
		var g: Dictionary = groups[key]
		var mesh: ArrayMesh = (g["st"] as SurfaceTool).commit()
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = g["mat"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	# Far lights fade out instead of costing every frame.
	for l in root.find_children("*", "OmniLight3D", true, false):
		var ol := l as OmniLight3D
		ol.distance_fade_enabled = true
		ol.distance_fade_begin = LIGHT_FADE_BEGIN
		ol.distance_fade_length = LIGHT_FADE_LENGTH

## Walk the dressing (not the rock): every MeshInstance3D is appended into its
## group's SurfaceTool (with its transform relative to `root`) and freed.
func _collect(node: Node, root: Node3D, xf: Transform3D, groups: Dictionary, to_free: Array, is_root := false) -> void:
	for c in node.get_children():
		if c is CSGShape3D or c is Light3D:
			continue
		if not (c is Node3D):
			continue
		var cxf: Transform3D = xf * (c as Node3D).transform
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			var mat: Material = mi.material_override
			if mi.mesh != null and mat != null and mi.get_child_count() == 0:
				var cx := int(floor(cxf.origin.x / cell + 0.5))
				var cz := int(floor(cxf.origin.z / cell + 0.5))
				var key := "%d|%d|%d|%d" % [mat.get_instance_id(), cx, cz, mi.mesh.get_surface_count()]
				if not groups.has(key):
					var st := SurfaceTool.new()
					groups[key] = {"mat": mat, "st": st, "empty": true}
				var g: Dictionary = groups[key]
				for sidx in mi.mesh.get_surface_count():
					(g["st"] as SurfaceTool).append_from(mi.mesh, sidx, cxf)
				to_free.append(mi)
				continue
		_collect(c, root, cxf, groups, to_free)

func _floors(root: Node3D) -> void:
	var mat := floor_mat()
	var all_ramps := ramps()
	for r in rooms:
		# A little bigger than the room so cave bulges have a floor too.
		var size: Vector2 = (r["size"] + Vector2(2.4, 2.4)).min(Vector2(cell - 0.2, cell - 0.2))
		var c: Vector3 = r["center"]
		var rects: Array = [Rect2(Vector2(c.x, c.z) - size * 0.5, size)]
		# A ramp going DOWN from this room is cut into its floor: leave that strip
		# out, or the floor would be drawn across the cut (and over your feet).
		for rp in all_ramps:
			var hole := floor_hole(rp[0], rp[1], c.y, corridor, cell * 0.5)
			if hole.size != Vector2.ZERO:
				rects = rects_minus(rects, hole)
		for q: Rect2 in rects:
			_quad(root, Vector3(q.get_center().x, c.y, q.get_center().y), q.size, mat)
	for l in links:
		var a: Vector3 = rooms[l[0]]["center"]
		var b: Vector3 = rooms[l[1]]["center"]
		if not is_equal_approx(a.y, b.y):
			continue   # ramps have their own floor
		var size := Vector2(absf(b.x - a.x), corridor) if absf(b.x - a.x) > absf(b.z - a.z) \
			else Vector2(corridor, absf(b.z - a.z))
		_quad(root, (a + b) * 0.5, size, mat)

## The strip of a floor at height `floor_y` that a ramp between p0 and p1 cuts
## away (on the ground plane, x/z): from the ramp's upper end outwards, as wide
## as the passage. Zero-sized when the ramp doesn't go down from that floor.
static func floor_hole(p0: Vector3, p1: Vector3, floor_y: float, width: float, reach: float) -> Rect2:
	var top := p0 if p0.y > p1.y else p1
	var bottom := p1 if p0.y > p1.y else p0
	if not is_equal_approx(top.y, floor_y) or is_equal_approx(top.y, bottom.y):
		return Rect2()
	var d := Vector2(bottom.x - top.x, bottom.z - top.z).normalized()
	var a := Vector2(top.x, top.z)
	var b := a + d * reach
	var side := Vector2(-d.y, d.x) * (width * 0.5)
	var lo := Vector2(minf(minf(a.x, b.x) , minf((a + side).x, (a - side).x)), minf(minf(a.y, b.y), minf((a + side).y, (a - side).y)))
	var hi := Vector2(maxf(maxf(a.x, b.x) , maxf((a + side).x, (a - side).x)), maxf(maxf(a.y, b.y), maxf((a + side).y, (a - side).y)))
	return Rect2(lo, hi - lo)

## `rects` with `hole` cut out of them (each rect becomes up to four).
static func rects_minus(rects: Array, hole: Rect2) -> Array:
	var out: Array = []
	for r: Rect2 in rects:
		var cut := r.intersection(hole)
		if cut.size.x <= 0.001 or cut.size.y <= 0.001:
			out.append(r)
			continue
		var pieces: Array = [
			Rect2(r.position, Vector2(cut.position.x - r.position.x, r.size.y)),                       # left of the hole
			Rect2(Vector2(cut.end.x, r.position.y), Vector2(r.end.x - cut.end.x, r.size.y)),           # right of it
			Rect2(Vector2(cut.position.x, r.position.y), Vector2(cut.size.x, cut.position.y - r.position.y)),   # before it
			Rect2(Vector2(cut.position.x, cut.end.y), Vector2(cut.size.x, r.end.y - cut.end.y)),       # after it
		]
		for piece: Rect2 in pieces:
			if piece.size.x > 0.001 and piece.size.y > 0.001:
				out.append(piece)
	return out

func _quad(root: Node3D, center: Vector3, size: Vector2, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = size
	m.mesh = p
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = center + Vector3(0, 0.015, 0)
	root.add_child(m)

## Stains, puddles, moss and snow patches on the floor.
func _floor_decals(root: Node3D) -> void:
	var cols: Array = _list("decal_colors")
	if cols.is_empty():
		return
	var layer := 0
	for r in rooms:
		var area: float = r["size"].x * r["size"].y
		var n := 3 + int(area / 45.0)
		var h: Vector2 = r["size"] * 0.5 - Vector2(0.8, 0.8)
		for k in n:
			var col: Color = _pick(cols)
			var d := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			var rad := rng.randf_range(0.5, 1.9)
			cm.top_radius = rad
			cm.bottom_radius = rad
			cm.height = 0.004
			cm.radial_segments = 18
			cm.rings = 1
			d.mesh = cm
			d.material_override = _decal_mat(col)
			d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			layer += 1
			d.position = r["center"] + Vector3(rng.randf_range(-h.x, h.x), 0.022 + float(layer % 6) * 0.002, rng.randf_range(-h.y, h.y))
			d.scale = Vector3(1.0, 1.0, rng.randf_range(0.5, 1.0))
			d.rotation.y = rng.randf() * TAU
			root.add_child(d)

## Posts (+ a lintel for arches) where each passage meets a room.
func _doorways(root: Node3D) -> void:
	var style := str(kit.doorway_piece)
	if style == "none":
		return
	var mat := piece_mat()
	for i in rooms.size():
		var r: Dictionary = rooms[i]
		for side in door_sides(i):
			var d := Vector3(side.x, 0, side.y)
			var half: float = (r["size"].x if side.x != 0 else r["size"].y) * 0.5
			var at: Vector3 = r["center"] + d * (half - 0.15)
			var across := Vector3(d.z, 0, d.x)
			for s: float in [-1.0, 1.0]:
				_mesh_box(root, Vector3(0.35, WALL_TOP + 0.4, 0.35), at + across * s * (corridor * 0.5 + 0.1) + Vector3(0, (WALL_TOP + 0.4) * 0.5, 0), mat)
			if style == "arch":
				var lintel := Vector3(corridor + 0.9, 0.3, 0.4) if side.x == 0 else Vector3(0.4, 0.3, corridor + 0.9)
				_mesh_box(root, lintel, at + Vector3(0, WALL_TOP + 0.35, 0), mat)

func _mesh_box(root: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = mat
	m.position = at
	root.add_child(m)
	return m

func _mesh_cyl(root: Node3D, r_top: float, r_bot: float, h: float, at: Vector3, mat: Material, sides := 10) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = sides
	cm.rings = 1
	m.mesh = cm
	m.material_override = mat
	m.position = at
	root.add_child(m)
	return m

func _mesh_sphere(root: Node3D, rad: float, at: Vector3, mat: Material, squash := 1.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = rad
	sm.height = rad * 2.0 * squash
	sm.radial_segments = 10
	sm.rings = 6
	m.mesh = sm
	m.material_override = mat
	m.position = at
	root.add_child(m)
	return m

## A node standing at a wall slot, facing into the room (+Z = inward).
func _anchor(root: Node3D, slot: Dictionary, depth: float) -> Node3D:
	var n := Node3D.new()
	root.add_child(n)
	var inward: Vector3 = slot["inward"]
	n.position = slot["at"] + inward * depth
	n.rotation.y = atan2(inward.x, inward.z)
	return n

func _torch(root: Node3D, at: Vector3, inward: Vector3, boss: bool) -> void:
	var t := Node3D.new()
	root.add_child(t)
	t.position = at
	t.rotation.y = atan2(inward.x, inward.z)
	_mesh_box(t, Vector3(0.12, 0.3, 0.12), Vector3(0, -0.2, 0.05), iron_mat())
	var _m1 := _mesh_cyl(t, 0.05, 0.035, 0.4, Vector3(0, -0.02, 0.1), wood_mat(), 6)
	_m1.rotation.x = deg_to_rad(20)
	var col: Color = kit.boss_fill_color if boss else kit.torch_color
	var core := _mesh_sphere(t, 0.08, Vector3(0, 0.2, 0.16), _flat("flame_%s" % col.to_html(false), col.lightened(0.4), 1.0, col, 6.0), 1.3)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.5
	light.omni_range = 7.5
	light.omni_attenuation = 1.4
	light.position = Vector3(0, 0.3, 0.4)
	light.set_script(FLICKER)
	t.add_child(light)

func _fill_light(root: Node3D, r: Dictionary) -> void:
	var light := OmniLight3D.new()
	var is_boss: bool = r["kind"] == "boss"
	light.light_color = kit.boss_fill_color if is_boss else kit.fill_color
	light.light_energy = (0.8 if is_boss else float(kit.fill_energy))
	light.omni_range = maxf(r["size"].x, r["size"].y) * 0.85
	light.position = r["center"] + Vector3(0, 4.2, 0)
	root.add_child(light)

func _candle(root: Node3D, at: Vector3, lit_light := false) -> void:
	var h := rng.randf_range(0.12, 0.3)
	_mesh_cyl(root, 0.04, 0.045, h, at + Vector3(0, h * 0.5, 0), _flat("wax", Color(0.92, 0.88, 0.75)), 6)
	var col: Color = kit.torch_color
	var f := _mesh_sphere(root, 0.035, at + Vector3(0, h + 0.04, 0), _flat("flame_%s" % col.to_html(false), col.lightened(0.4), 1.0, col, 6.0), 1.6)
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (candles are glow only - no light of their own, for performance)

# --- Big props (their collision is in the rock) -------------------------------------------------

func _big_prop(root: Node3D, kind: String, slot: Dictionary) -> void:
	var info: Dictionary = BIG.get(kind, {"w": 1.0, "d": 1.0})
	var n := _anchor(root, slot, float(info["d"]) * 0.5 + 0.1)
	var w := float(info["w"])
	var d := float(info["d"])
	match kind:
		"sarcophagus":
			_mesh_box(n, Vector3(w, 0.7, d), Vector3(0, 0.35, 0), wall_mat())
			_mesh_box(n, Vector3(w + 0.1, 0.14, d + 0.1), Vector3(0, 0.77, 0), piece_mat())
			_mesh_box(n, Vector3(w * 0.6, 0.1, d * 0.45), Vector3(0, 0.88, 0), piece_mat())
			if rng.randf() < 0.5:
				_candle(n, Vector3(w * 0.45, 0.84, 0), true)
		"coffin":
			var c := _mesh_box(n, Vector3(w, 0.45, d), Vector3(0, 0.23, 0), dark_wood_mat())
			c.rotation.y = rng.randf_range(-0.15, 0.15)
			if rng.randf() < 0.5:   # lid pushed aside
				var lid := _mesh_box(n, Vector3(w, 0.07, d), Vector3(0.25, 0.5, 0.2), wood_mat())
				lid.rotation.y = 0.35
		"bookshelf":
			_mesh_box(n, Vector3(w, 2.0, d), Vector3(0, 1.0, 0), dark_wood_mat())
			for row in 4:
				var x := -w * 0.4
				while x < w * 0.4:
					var bw := rng.randf_range(0.06, 0.12)
					var bh := rng.randf_range(0.22, 0.36)
					var bi := rng.randi_range(0, 3)
					var bcol: Color = [Color(0.45, 0.1, 0.08), Color(0.12, 0.2, 0.35), Color(0.2, 0.3, 0.12), Color(0.45, 0.35, 0.15)][bi]
					_mesh_box(n, Vector3(bw, bh, d * 0.7), Vector3(x, 0.2 + row * 0.45 + bh * 0.5, 0.05), _flat("book%d" % bi, bcol))
					x += bw + 0.01
		"weapon_rack":
			_mesh_box(n, Vector3(w, 0.1, 0.2), Vector3(0, 1.1, -0.1), wood_mat())
			_mesh_box(n, Vector3(w, 0.1, 0.25), Vector3(0, 0.25, 0.0), wood_mat())
			for k in 4:
				var x := -w * 0.38 + k * w * 0.25
				var _m2 := _mesh_box(n, Vector3(0.05, 1.3, 0.05), Vector3(x, 0.75, -0.05), iron_mat())
				_m2.rotation.z = rng.randf_range(-0.08, 0.08)
			if rng.randf() < 0.6:   # a shield leaning on it
				var sh := _mesh_cyl(n, 0.35, 0.35, 0.06, Vector3(w * 0.3, 0.45, 0.2), _flat("shield", kit.boss_fill_color.darkened(0.4), 0.7), 12)
				sh.rotation = Vector3(deg_to_rad(75), 0, 0)
		"crate_stack":
			_mesh_box(n, Vector3(0.8, 0.8, 0.8), Vector3(-0.35, 0.4, 0), wood_mat())
			var _m3 := _mesh_box(n, Vector3(0.7, 0.7, 0.7), Vector3(0.4, 0.35, 0.05), wood_mat())
			_m3.rotation.y = 0.3
			if rng.randf() < 0.7:
				var _m4 := _mesh_box(n, Vector3(0.55, 0.55, 0.55), Vector3(-0.3, 1.07, 0.05), wood_mat())
				_m4.rotation.y = -0.4
		"barrels":
			for k in 3:
				var bx := -0.45 + k * 0.45
				_mesh_cyl(n, 0.28, 0.3, 0.85, Vector3(bx, 0.43, rng.randf_range(-0.1, 0.1)), _flat("barrel", Color(0.4, 0.26, 0.14), 0.85), 10)
				_mesh_cyl(n, 0.305, 0.305, 0.06, Vector3(bx, 0.6, 0), iron_mat(), 10)
			if rng.randf() < 0.5:
				var lying := _mesh_cyl(n, 0.28, 0.28, 0.8, Vector3(0.1, 0.28, 0.45), _flat("barrel", Color(0.4, 0.26, 0.14), 0.85), 10)
				lying.rotation = Vector3(0, 0, PI / 2.0)
		"statue":
			_mesh_box(n, Vector3(0.9, 0.5, 0.9), Vector3(0, 0.25, 0), piece_mat())
			var body_mat: Material = ice_mat() if _style() == "ice" else wall_mat()
			_mesh_cyl(n, 0.22, 0.32, 1.2, Vector3(0, 1.1, 0), body_mat, 8)
			_mesh_sphere(n, 0.2, Vector3(0, 1.9, 0), body_mat)
			var arm := _mesh_box(n, Vector3(0.12, 0.8, 0.12), Vector3(0.3, 1.25, 0.1), body_mat)
			arm.rotation.z = 0.4
		"hay":
			var _m5 := _mesh_box(n, Vector3(w, 0.6, d), Vector3(0, 0.3, 0), _flat("hay", Color(0.75, 0.62, 0.3), 1.0))
			_m5.rotation.y = 0.05
			var _m6 := _mesh_box(n, Vector3(w * 0.6, 0.5, d * 0.8), Vector3(0.2, 0.85, 0), _flat("hay", Color(0.75, 0.62, 0.3), 1.0))
			_m6.rotation.y = -0.3
		"table":
			_mesh_box(n, Vector3(w, 0.08, d), Vector3(0, 0.78, 0), wood_mat())
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					_mesh_box(n, Vector3(0.08, 0.78, 0.08), Vector3(sx * (w * 0.5 - 0.1), 0.39, sz * (d * 0.5 - 0.1)), wood_mat())
			_mesh_cyl(n, 0.06, 0.05, 0.14, Vector3(-0.3, 0.89, 0.1), iron_mat(), 8)
			_mesh_cyl(n, 0.16, 0.16, 0.03, Vector3(0.25, 0.83, -0.05), _flat("plate", Color(0.6, 0.58, 0.55)), 12)
			_candle(n, Vector3(0.55, 0.82, 0.2), rng.randf() < 0.4)
			_mesh_box(n, Vector3(0.4, 0.45, 0.4), Vector3(-0.2, 0.22, d * 0.5 + 0.35), wood_mat())   # a stool
		"altar":
			_mesh_box(n, Vector3(w, 0.9, d), Vector3(0, 0.45, 0), piece_mat())
			_mesh_box(n, Vector3(w + 0.15, 0.1, d + 0.15), Vector3(0, 0.95, 0), wall_mat())
			for k in 3:
				_candle(n, Vector3(-0.5 + k * 0.5, 1.0, rng.randf_range(-0.15, 0.15)), k == 1)
			_mesh_sphere(n, 0.12, Vector3(0.2, 1.1, 0.1), bone_mat())
		"boulder":
			var bm := wall_mat()
			var _m7 := _mesh_sphere(n, 0.75, Vector3(0, 0.45, 0), bm, 0.8)
			_m7.scale = Vector3(1.1, 1.0, 0.9)
			_mesh_sphere(n, 0.4, Vector3(0.6, 0.25, 0.25), bm, 0.8)
			if _list("props").has("mushroom"):
				_mushrooms(n, Vector3(-0.5, 0.0, 0.5))
		"ice_block":
			for k in rng.randi_range(2, 3):
				var h := rng.randf_range(0.8, 1.8)
				var b := _mesh_box(n, Vector3(rng.randf_range(0.5, 0.8), h, rng.randf_range(0.5, 0.7)),
					Vector3(rng.randf_range(-0.4, 0.4), h * 0.5, rng.randf_range(-0.2, 0.2)), ice_mat())
				b.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))
		"bone_pile":
			_mesh_sphere(n, 0.55, Vector3(0, 0.0, 0), _flat("bonedust", Color(0.55, 0.52, 0.45)), 0.6)
			for k in 10:
				var b := _mesh_box(n, Vector3(0.06, 0.06, rng.randf_range(0.3, 0.5)),
					Vector3(rng.randf_range(-0.55, 0.55), rng.randf_range(0.05, 0.3), rng.randf_range(-0.45, 0.45)), bone_mat())
				b.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)
			for k in 3:
				_mesh_sphere(n, 0.11, Vector3(rng.randf_range(-0.4, 0.4), 0.3, rng.randf_range(-0.3, 0.3)), bone_mat())
		"urn_group":
			for k in rng.randi_range(2, 4):
				var h := rng.randf_range(0.35, 0.6)
				_mesh_cyl(n, 0.12, 0.18, h, Vector3(-0.45 + k * 0.3, h * 0.5, rng.randf_range(-0.1, 0.1)), _flat("urn", Color(0.45, 0.3, 0.2), 0.7), 10)
		"page_pile":
			for k in rng.randi_range(3, 5):
				var h := rng.randf_range(0.08, 0.3)
				var p := _mesh_box(n, Vector3(0.42, h, 0.32), Vector3(rng.randf_range(-0.4, 0.4), h * 0.5, rng.randf_range(-0.3, 0.3)), _paper())
				p.rotation.y = rng.randf() * TAU
			_loose_pages(n, 7, 0.8)
		"loot_sacks":
			for k in 3:
				var s := _mesh_sphere(n, 0.34, Vector3(-0.45 + k * 0.45, 0.3, rng.randf_range(-0.1, 0.1)), _flat("sack", Color(0.55, 0.45, 0.3), 1.0), 1.1)
				s.scale = Vector3(1.0, 1.2, 0.9)
			_loose_pages(n, 5, 0.7)
		"broken_gate":
			# Two smashed door leaves on the floor, iron bands still on.
			for side: float in [-1.0, 1.0]:
				var leaf := Node3D.new()
				n.add_child(leaf)
				leaf.position = Vector3(side * 0.8, 0.08, rng.randf_range(-0.2, 0.2))
				leaf.rotation = Vector3(0, side * 0.25 + rng.randf_range(-0.1, 0.1), side * 0.06)
				_mesh_box(leaf, Vector3(1.5, 0.14, 1.3), Vector3.ZERO, dark_wood_mat())
				for b: float in [-0.4, 0.4]:
					_mesh_box(leaf, Vector3(1.52, 0.16, 0.1), Vector3(0, 0.01, b), iron_mat())
			for k in 4:
				var plank := _mesh_box(n, Vector3(0.18, 0.08, rng.randf_range(0.6, 1.1)),
					Vector3(rng.randf_range(-1.4, 1.4), 0.04, rng.randf_range(-0.7, 0.7)), wood_mat())
				plank.rotation.y = rng.randf() * TAU
		"campfire":
			for k in 8:
				var a := TAU * k / 8.0
				_mesh_sphere(n, 0.16, Vector3(cos(a) * 0.55, 0.08, sin(a) * 0.55), wall_mat(), 0.7)
			for k in 3:
				var lg := _mesh_cyl(n, 0.07, 0.07, 0.8, Vector3(0, 0.12, 0), wood_mat(), 6)
				lg.rotation = Vector3(PI / 2.0, TAU * k / 3.0, 0)
			var fire: Color = kit.torch_color
			var e := _mesh_sphere(n, 0.28, Vector3(0, 0.22, 0), _flat("embers_%s" % fire.to_html(false), fire, 1.0, fire, 4.0), 0.6)
			e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# (glow only, no light: performance)
		"bunk":
			for lvl in 2:
				var y := 0.35 + lvl * 0.9
				_mesh_box(n, Vector3(w, 0.1, d), Vector3(0, y, 0), wood_mat())
				_mesh_box(n, Vector3(w * 0.9, 0.12, d * 0.8), Vector3(0, y + 0.1, 0), _flat("bedroll", Color(0.5, 0.3, 0.22), 1.0))
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					_mesh_box(n, Vector3(0.08, 1.4, 0.08), Vector3(sx * (w * 0.5 - 0.05), 0.7, sz * (d * 0.5 - 0.05)), wood_mat())
		"lectern":
			_mesh_box(n, Vector3(0.35, 0.9, 0.3), Vector3(0, 0.45, 0), dark_wood_mat())
			var top := _mesh_box(n, Vector3(0.65, 0.06, 0.5), Vector3(0, 0.95, 0.02), dark_wood_mat())
			top.rotation.x = -0.35
			var book := _mesh_box(n, Vector3(0.5, 0.05, 0.36), Vector3(0, 1.0, 0.04), _paper())
			book.rotation.x = -0.35
			_candle(n, Vector3(0.28, 0.98, -0.15), true)
		"target_dummy":
			_mesh_cyl(n, 0.05, 0.05, 1.5, Vector3(0, 0.75, 0), wood_mat(), 6)
			_mesh_box(n, Vector3(0.7, 0.08, 0.08), Vector3(0, 1.2, 0), wood_mat())
			_mesh_sphere(n, 0.3, Vector3(0, 1.05, 0), _flat("hay", Color(0.75, 0.62, 0.3), 1.0), 1.3)
			_mesh_sphere(n, 0.17, Vector3(0, 1.5, 0), _flat("hay", Color(0.75, 0.62, 0.3), 1.0))
			var tgt := _mesh_cyl(n, 0.2, 0.2, 0.03, Vector3(0, 1.05, 0.29), _flat("target", kit.boss_fill_color, 0.8), 12)
			tgt.rotation.x = PI / 2.0
		"siege_cart":
			_mesh_box(n, Vector3(w, 0.12, d), Vector3(0, 0.6, 0), wood_mat())
			for sx: float in [-1.0, 1.0]:
				_mesh_box(n, Vector3(w, 0.35, 0.08), Vector3(0, 0.82, sx * (d * 0.5 - 0.04)), wood_mat())
				for wx: float in [-0.75, 0.75]:
					var wh := _mesh_cyl(n, 0.4, 0.4, 0.1, Vector3(wx, 0.4, sx * (d * 0.5 + 0.05)), dark_wood_mat(), 12)
					wh.rotation.x = PI / 2.0
			for k in 4:   # fire pots
				var pot: Color = kit.torch_color
				_mesh_cyl(n, 0.14, 0.2, 0.32, Vector3(-0.7 + k * 0.45, 0.83, rng.randf_range(-0.2, 0.2)), _flat("firepot", Color(0.5, 0.25, 0.12), 0.7), 8)
				_mesh_sphere(n, 0.08, Vector3(-0.7 + k * 0.45, 1.02, 0), _flat("potglow_%s" % pot.to_html(false), pot, 1.0, pot, 3.0))
			var shaft := _mesh_box(n, Vector3(0.08, 0.08, 1.4), Vector3(w * 0.5 + 0.5, 0.45, 0), wood_mat())
			shaft.rotation.y = PI / 2.0
		"tent":
			for side: float in [-1.0, 1.0]:
				var cloth := _mesh_box(n, Vector3(w, 0.05, d * 0.62), Vector3(0, 0.62, side * d * 0.25), _flat("tent", Color(0.45, 0.38, 0.28), 1.0))
				cloth.rotation.x = side * 0.9
			_mesh_box(n, Vector3(0.08, 1.3, 0.08), Vector3(-w * 0.5, 0.65, 0), wood_mat())
			_mesh_box(n, Vector3(0.08, 1.3, 0.08), Vector3(w * 0.5, 0.65, 0), wood_mat())
			_mesh_box(n, Vector3(w + 0.1, 0.08, 0.08), Vector3(0, 1.28, 0), wood_mat())
		"ink_spill":
			var ink := _mesh_cyl(n, 0.6, 0.6, 0.015, Vector3(0, 0.01, 0), _flat("ink", Color(0.12, 0.08, 0.22), 0.2), 14)
			ink.scale = Vector3(1.3, 1.0, 0.9)
			_mesh_cyl(n, 0.08, 0.1, 0.16, Vector3(0.55, 0.08, -0.3), _flat("inkpot", Color(0.2, 0.18, 0.25), 0.4), 8)
			_loose_pages(n, 3, 0.7)

func _paper() -> StandardMaterial3D:
	return _flat("paper", Color(0.93, 0.88, 0.74), 0.9, Color(1.0, 0.9, 0.7), 0.15)

## Single pages strewn on the floor around a prop.
func _loose_pages(root: Node3D, count: int, reach: float) -> void:
	for k in count:
		var p := _mesh_box(root, Vector3(0.22, 0.01, 0.3), Vector3(rng.randf_range(-reach, reach), 0.01, rng.randf_range(-reach, reach)), _paper())
		p.rotation = Vector3(rng.randf_range(-0.05, 0.05), rng.randf() * TAU, 0)

func _mushrooms(root: Node3D, at: Vector3) -> void:
	var glow: Color = kit.glow_color
	for k in rng.randi_range(2, 4):
		var p := at + Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
		var h := rng.randf_range(0.2, 0.4)
		_mesh_cyl(root, 0.035, 0.045, h, p + Vector3(0, h * 0.5, 0), _flat("stem", Color(0.8, 0.85, 0.75)), 6)
		_mesh_sphere(root, rng.randf_range(0.12, 0.2), p + Vector3(0, h, 0), _flat("glow_%s" % glow.to_html(false), glow, 0.5, glow, 1.8), 0.45)

# --- Wall decorations ----------------------------------------------------------------------------

func _wall_decor(root: Node3D, kind: String, slot: Dictionary) -> void:
	var n := _anchor(root, slot, 0.06)
	match kind:
		"banner":
			var col: Color = kit.boss_fill_color.darkened(0.35)
			_mesh_box(n, Vector3(1.0, 0.06, 0.06), Vector3(0, 1.95, 0.05), iron_mat())
			_mesh_box(n, Vector3(0.8, 1.3, 0.03), Vector3(0, 1.25, 0.06), _flat("banner_%s" % col.to_html(false), col, 0.9))
			_mesh_box(n, Vector3(0.3, 0.3, 0.035), Vector3(0, 1.35, 0.075), _flat("banner_sigil", Color(0.85, 0.7, 0.3), 0.6))
		"chains":
			for k in rng.randi_range(2, 3):
				var x := rng.randf_range(-0.5, 0.5)
				var links_n := rng.randi_range(5, 9)
				for j in links_n:
					var link := _mesh_cyl(n, 0.035, 0.035, 0.12, Vector3(x, 1.95 - j * 0.11, 0.07), iron_mat(), 6)
					link.rotation.z = 0.3 if j % 2 == 0 else -0.3
			_mesh_box(n, Vector3(0.2, 0.2, 0.15), Vector3(0, 0.3, 0.1), iron_mat())   # a shackle block
		"shield":
			var col: Color = kit.boss_fill_color.darkened(0.3)
			var sh := _mesh_cyl(n, 0.38, 0.38, 0.06, Vector3(0, 1.3, 0.05), _flat("shield_%s" % col.to_html(false), col, 0.6), 14)
			sh.rotation.x = PI / 2.0
			var _m8 := _mesh_cyl(n, 0.1, 0.1, 0.08, Vector3(0, 1.3, 0.09), iron_mat(), 10)
			_m8.rotation.x = PI / 2.0
			for s: float in [-1.0, 1.0]:
				var _m9 := _mesh_box(n, Vector3(0.05, 1.1, 0.05), Vector3(0, 1.3, 0.12), iron_mat())
				_m9.rotation.z = s * 0.7
		"moss":
			var col: Color = Color(0.15, 0.3, 0.1, 0.9)
			for k in rng.randi_range(2, 4):
				var m := _mesh_sphere(n, rng.randf_range(0.25, 0.5), Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.2, 1.6), 0.0), _flat("moss", col, 1.0), 0.4)
				m.scale = Vector3(1.0, 1.0, 0.35)
			if _list("props").has("mushroom") and rng.randf() < 0.5:
				_mushrooms(n, Vector3(0, 0, 0.25))
		"icicles":
			for k in rng.randi_range(3, 6):
				var h := rng.randf_range(0.3, 0.9)
				var ic := _mesh_cyl(n, 0.07, 0.005, h, Vector3(rng.randf_range(-0.7, 0.7), WALL_TOP - h * 0.5, 0.05), ice_mat(), 6)
				ic.rotation.x = PI
		"candles_ledge":
			_mesh_box(n, Vector3(0.9, 0.08, 0.3), Vector3(0, 1.0, 0.12), piece_mat())
			for k in rng.randi_range(2, 4):
				_candle(n, Vector3(rng.randf_range(-0.35, 0.35), 1.04, 0.14), k == 0 and rng.randf() < 0.5)
		"planks":
			for k in rng.randi_range(2, 4):
				var pl := _mesh_box(n, Vector3(0.22, rng.randf_range(1.2, 1.9), 0.04), Vector3(-0.35 + k * 0.24, 0.9, 0.03), wood_mat())
				pl.rotation.z = rng.randf_range(-0.06, 0.06)
			_mesh_box(n, Vector3(1.1, 0.14, 0.05), Vector3(0, 1.4, 0.06), dark_wood_mat())

## Masonry niches: candles, a skull or an urn inside.
func _niche_filling(root: Node3D, slot: Dictionary) -> void:
	var n := _anchor(root, slot, -0.45)
	match rng.randi_range(0, 2):
		0:
			_mesh_sphere(n, 0.13, Vector3(0, 0.45, 0), bone_mat())
			_candle(n, Vector3(0.3, 0.35, 0.1))
		1:
			for k in 3:
				_candle(n, Vector3(-0.3 + k * 0.3, 0.35, rng.randf_range(-0.1, 0.1)), k == 1 and rng.randf() < 0.4)
		_:
			_mesh_cyl(n, 0.12, 0.18, 0.45, Vector3(0, 0.57, 0), _flat("urn", Color(0.45, 0.3, 0.2), 0.7), 10)

## Timber walls: a beam across the top between posts.
func _beam(root: Node3D, slot: Dictionary) -> void:
	var n := _anchor(root, slot, 0.12)
	_mesh_box(n, Vector3(SLOT_SPACING + 0.4, 0.22, 0.24), Vector3(0, WALL_TOP + 0.25, 0), dark_wood_mat())

## Cobwebs in a couple of corners (if the kit has them).
func _cobwebs(root: Node3D, i: int) -> void:
	if not _list("wall_decor").has("cobweb"):
		return
	var r: Dictionary = rooms[i]
	var h: Vector2 = r["size"] * 0.5
	for k in rng.randi_range(0, 2):
		var sx := 1.0 if rng.randf() < 0.5 else -1.0
		var sz := 1.0 if rng.randf() < 0.5 else -1.0
		var corner: Vector3 = r["center"] + Vector3(sx * (h.x - 0.1), 0, sz * (h.y - 0.1))
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var a := corner + Vector3(0, WALL_TOP - 0.05, 0)
		var b := corner + Vector3(-sx * 1.3, WALL_TOP - 0.05, 0)
		var c := corner + Vector3(0, WALL_TOP - 0.05, -sz * 1.3)
		var d := corner + Vector3(0, WALL_TOP - 1.2, 0)
		for tri in [[a, b, c], [a, b, d], [a, c, d]]:
			for v in tri:
				st.add_vertex(v)
		var m := MeshInstance3D.new()
		m.mesh = st.commit()
		var mat := _flat("cobweb", Color(0.85, 0.85, 0.85, 0.22), 1.0)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(m)

# --- Clutter (small, no collision) ------------------------------------------------------------------

func _clutter(root: Node3D, i: int) -> void:
	var r: Dictionary = rooms[i]
	var library: Array = _list("props").filter(func(p): return str(p) != "pillar")
	if library.is_empty():
		return
	var density := float(kit.prop_density) / 4.0
	var area: float = r["size"].x * r["size"].y
	var count := int(round(area / 22.0 * density))
	if r["kind"] == "boss":
		count = int(count * 0.5)
	var h: Vector2 = r["size"] * 0.5
	for k in count:
		var kind: String = _pick(library)
		# Mostly along the walls, sometimes out in the room (never the very middle).
		var at: Vector3
		if rng.randf() < 0.7:
			var side := rng.randi_range(0, 3)
			var inset := rng.randf_range(1.4, 2.2)
			match side:
				0: at = Vector3(h.x - inset, 0, rng.randf_range(-h.y + 1.5, h.y - 1.5))
				1: at = Vector3(-h.x + inset, 0, rng.randf_range(-h.y + 1.5, h.y - 1.5))
				2: at = Vector3(rng.randf_range(-h.x + 1.5, h.x - 1.5), 0, h.y - inset)
				_: at = Vector3(rng.randf_range(-h.x + 1.5, h.x - 1.5), 0, -h.y + inset)
		else:
			at = Vector3(rng.randf_range(-h.x + 2.0, h.x - 2.0), 0, rng.randf_range(-h.y + 2.0, h.y - 2.0))
			if Vector2(at.x, at.z).length() < minf(h.x, h.y) * 0.35:
				continue
		if blocked_in_room(i, r["center"] + at, 0.4):
			continue
		_small_prop(root, kind, r["center"] + at)

func _small_prop(root: Node3D, kind: String, at: Vector3) -> void:
	var n := Node3D.new()
	root.add_child(n)
	n.position = at
	n.rotation.y = rng.randf() * TAU
	var glow: Color = kit.glow_color
	match kind:
		"rubble":
			for k in rng.randi_range(3, 6):
				var s := rng.randf_range(0.12, 0.35)
				var b := _mesh_box(n, Vector3(s, s * 0.7, s * 1.1), Vector3(rng.randf_range(-0.6, 0.6), s * 0.3, rng.randf_range(-0.6, 0.6)), wall_mat())
				b.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		"bones":
			for k in rng.randi_range(3, 5):
				var b := _mesh_box(n, Vector3(0.06, 0.06, rng.randf_range(0.3, 0.5)), Vector3(rng.randf_range(-0.4, 0.4), 0.04, rng.randf_range(-0.4, 0.4)), bone_mat())
				b.rotation.y = rng.randf() * TAU
		"skull":
			_mesh_sphere(n, 0.12, Vector3(0, 0.1, 0), bone_mat())
			_mesh_box(n, Vector3(0.1, 0.05, 0.08), Vector3(0, 0.03, 0.08), bone_mat())
		"candles":
			for k in rng.randi_range(2, 5):
				_candle(n, Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25)), k == 0 and rng.randf() < 0.25)
		"urn":
			var h := rng.randf_range(0.35, 0.6)
			_mesh_cyl(n, 0.12, 0.18, h, Vector3(0, h * 0.5, 0), _flat("urn", Color(0.45, 0.3, 0.2), 0.7), 10)
		"bucket":
			_mesh_cyl(n, 0.2, 0.16, 0.3, Vector3(0, 0.15, 0), wood_mat(), 10)
		"crystal", "ice_spike":
			var col := glow if kind == "crystal" else Color(0.7, 0.9, 1.0)
			for k in rng.randi_range(2, 4):
				var c := MeshInstance3D.new()
				var pm := PrismMesh.new()
				var h := rng.randf_range(0.5, 1.3)
				pm.size = Vector3(0.28, h, 0.28)
				c.mesh = pm
				c.material_override = _flat("glow_%s" % col.to_html(false), col, 0.2, col, 2.0 if kind == "crystal" else 0.6)
				c.position = Vector3(rng.randf_range(-0.4, 0.4), h * 0.5, rng.randf_range(-0.4, 0.4))
				c.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
				n.add_child(c)
		"mushroom":
			_mushrooms(n, Vector3.ZERO)
		"stalagmite":
			for k in rng.randi_range(1, 3):
				var h := rng.randf_range(0.6, 1.8)
				_mesh_cyl(n, 0.02, rng.randf_range(0.2, 0.45), h, Vector3(rng.randf_range(-0.4, 0.4), h * 0.5, rng.randf_range(-0.4, 0.4)), wall_mat(), 8)
		"crate":
			_mesh_box(n, Vector3(0.7, 0.7, 0.7), Vector3(0, 0.35, 0), wood_mat())
		"barrel":
			_mesh_cyl(n, 0.28, 0.3, 0.85, Vector3(0, 0.43, 0), _flat("barrel", Color(0.4, 0.26, 0.14), 0.85), 10)
		"brazier":
			_mesh_cyl(n, 0.3, 0.18, 0.25, Vector3(0, 0.75, 0), iron_mat(), 10)
			_mesh_cyl(n, 0.05, 0.05, 0.65, Vector3(0, 0.33, 0), iron_mat(), 6)
			var col: Color = kit.torch_color
			_mesh_sphere(n, 0.2, Vector3(0, 0.95, 0), _flat("flame_%s" % col.to_html(false), col.lightened(0.4), 1.0, col, 6.0), 1.4)
			if rng.randf() < 0.3:   # only some braziers light the room (performance)
				var l := OmniLight3D.new()
				l.light_color = col
				l.light_energy = 1.3
				l.omni_range = 6.0
				l.position = Vector3(0, 1.2, 0)
				n.add_child(l)

# --- Passages ------------------------------------------------------------------------------------

## Torches, clutter and cobwebs along the passages too.
func _corridor_dressing(root: Node3D) -> void:
	var library: Array = _list("props").filter(func(p): return not (str(p) in ["pillar", "brazier", "crate", "barrel", "stalagmite"]))
	var decals: Array = _list("decal_colors")
	for seg in _corridor_segments():
		var a: Vector3 = seg["a"]
		var b: Vector3 = seg["b"]
		var along: Vector3 = seg["along"]
		var side: Vector3 = seg["side"]
		var length := a.distance_to(b)
		# A torch every ~9 m, alternating sides.
		if kit.torches and length > 6.0:
			var t := 4.0
			var s := 1.0
			while t < length - 2.0:
				var wall_at := a + along * t + side * s * corridor * 0.5
				_torch(root, wall_at - side * s * 0.12 + Vector3(0, TORCH_Y, 0), -side * s, false)
				s = -s
				t += 13.0
		# Clutter hugging the walls.
		if not library.is_empty():
			var t2 := rng.randf_range(1.0, 3.0)
			while t2 < length - 1.0:
				var s2 := 1.0 if rng.randf() < 0.5 else -1.0
				_small_prop(root, str(_pick(library)), a + along * t2 + side * s2 * (corridor * 0.5 - 0.45))
				t2 += rng.randf_range(2.5, 5.0)
		# A stain or two.
		if not decals.is_empty() and length > 4.0:
			for k in rng.randi_range(0, 2):
				var d := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				var rad := rng.randf_range(0.4, minf(1.2, corridor * 0.4))
				cm.top_radius = rad
				cm.bottom_radius = rad
				cm.height = 0.004
				cm.radial_segments = 16
				cm.rings = 1
				d.mesh = cm
				d.material_override = _decal_mat(_pick(decals))
				d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				d.position = a + along * rng.randf_range(1.0, length - 1.0) + Vector3(0, 0.024, 0)
				root.add_child(d)

# --- Boss room centerpieces ------------------------------------------------------------------------

func _centerpiece(root: Node3D, i: int) -> void:
	var r: Dictionary = rooms[i]
	var cp := _room_cp(i)
	var c: Vector3 = r["center"]
	match cp:
		"summoning_circle":
			var col := Color(0.75, 0.35, 1.0)
			for rad: float in [4.5, 3.6]:
				var ring := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = rad - 0.08
				tm.outer_radius = rad
				tm.rings = 48
				tm.ring_segments = 4
				ring.mesh = tm
				ring.material_override = _flat("rune_ring", col, 0.5, col, 2.5)
				ring.scale = Vector3(1, 0.1, 1)
				ring.position = c + Vector3(0, 0.03, 0)
				ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(ring)
			for k in 8:
				var a := TAU * float(k) / 8.0
				var g := _mesh_box(root, Vector3(0.35, 0.02, 0.12), c + Vector3(cos(a), 0, sin(a)) * 4.05 + Vector3(0, 0.035, 0), _flat("rune_ring", col, 0.5, col, 2.5))
				g.rotation.y = -a
			for p in _ring_points(r, 4, 0.62):
				_candle(root, p + Vector3(0.2, 0, 0))
				_candle(root, p + Vector3(-0.15, 0, 0.15))
				_candle(root, p + Vector3(0, 0, -0.2), true)
		"crystal_cluster":
			var glow: Color = kit.glow_color
			for p in _ring_points(r, 4, 0.62):
				if in_door_lane(i, p, 0.6):
					continue
				for k in rng.randi_range(4, 6):
					var cr := MeshInstance3D.new()
					var pm := PrismMesh.new()
					var h := rng.randf_range(1.0, 2.6)
					pm.size = Vector3(0.45, h, 0.45)
					cr.mesh = pm
					cr.material_override = _flat("glow_%s" % glow.to_html(false), glow, 0.2, glow, 2.0)
					cr.position = p + Vector3(rng.randf_range(-0.35, 0.35), h * 0.5, rng.randf_range(-0.35, 0.35))
					cr.rotation = Vector3(rng.randf_range(-0.35, 0.35), rng.randf() * TAU, rng.randf_range(-0.35, 0.35))
					root.add_child(cr)
				var l := OmniLight3D.new()
				l.light_color = glow
				l.light_energy = 1.2
				l.omni_range = 5.0
				l.position = p + Vector3(0, 1.2, 0)
				root.add_child(l)
		"ice_statues":
			for p in _ring_points(r, 4, 0.62):
				if in_door_lane(i, p, 0.6):
					continue
				var n := Node3D.new()
				root.add_child(n)
				n.position = p
				n.rotation.y = atan2(c.x - p.x, c.z - p.z)
				_mesh_box(n, Vector3(1.0, 0.4, 1.0), Vector3(0, 0.2, 0), piece_mat())
				_mesh_cyl(n, 0.25, 0.4, 1.6, Vector3(0, 1.2, 0), ice_mat(), 8)
				_mesh_sphere(n, 0.28, Vector3(0, 2.2, 0), ice_mat())
				var arm := _mesh_box(n, Vector3(0.14, 1.1, 0.14), Vector3(0.35, 1.5, 0.1), ice_mat())
				arm.rotation.z = -0.5
		"throne":
			var back := -_entry_dir(i)
			var half: float = (r["size"].x if absf(back.x) > 0.5 else r["size"].y) * 0.5
			if in_door_lane(i, c + back * (half - 1.2), 0.8):
				return
			var n := Node3D.new()
			root.add_child(n)
			n.position = c + back * (half - 1.2)
			n.rotation.y = atan2(-back.x, -back.z)   # faces the room
			_mesh_box(n, Vector3(1.6, 0.3, 1.6), Vector3(0, 0.15, 0), piece_mat())
			_mesh_box(n, Vector3(1.0, 0.5, 0.9), Vector3(0, 0.55, 0), dark_wood_mat())
			_mesh_box(n, Vector3(1.1, 1.8, 0.2), Vector3(0, 1.3, -0.45), dark_wood_mat())
			for s: float in [-1.0, 1.0]:
				_mesh_box(n, Vector3(0.15, 0.4, 0.9), Vector3(s * 0.55, 0.95, 0), dark_wood_mat())
			var col: Color = kit.boss_fill_color.darkened(0.35)
			_mesh_box(n, Vector3(0.9, 1.2, 0.03), Vector3(0, 1.4, -0.33), _flat("banner_%s" % col.to_html(false), col, 0.9))
			# A long rug up to it.
			var rug := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(1.8, half * 1.4)
			rug.mesh = pm
			rug.material_override = _flat("rug_%s" % col.to_html(false), col.darkened(0.1), 1.0)
			rug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			rug.position = Vector3(0, 0.03, half * 0.7 + 0.6)
			n.add_child(rug)
			for s: float in [-1.0, 1.0]:
				_small_prop(root, "brazier", n.position + Vector3(back.z, 0, back.x) * s * 1.8)

# --- Environment ---------------------------------------------------------------------------

func apply_environment(env: Environment) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = kit.background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = kit.ambient
	env.ambient_light_energy = float(kit.ambient_energy)
	env.fog_enabled = bool(kit.fog)
	env.fog_light_color = kit.fog_color
	env.fog_density = float(kit.fog_density)
