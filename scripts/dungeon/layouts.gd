extends RefCounted

# Layout styles. Each builds the dungeon's room graph on a grid (seeded, so every
# machine in a party builds the same one). Same output for every style, so the
# geometry / spawning / objective code never cares which style it was:
#
#   {"cell": grid spacing, "corridor": corridor width, "roam": bool,
#    "rooms": [{cell, center (Vector3, y = floor height), size (Vector2), kind,
#               section, boss (index or -1)}],
#    "links": [[parent, child], ...]    # a tree rooted at room 0 (the start)
#   }
#
# Kinds: start, combat, side, junction (empty), hub, boss.
# Every section ends in its boss room (section k -> boss k). The runner turns
# combat rooms into arenas / defend circles for those objectives.
#
#   linear   corridor of rooms with side rooms
#   hub      hub room with wings; the final boss opens when the wing bosses die
#   descent  like linear but every section is a level further down (ramps)
#   cavern   big open caves, wide passages, roaming packs
#   arena    one big arena per section
#   maze     tight catacombs: a random maze, bosses along the longest path

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DROP := 3.0          # descent: metres per level

static func build(style: String, rng: RandomNumberGenerator, boss_count: int, per_section: int) -> Dictionary:
	boss_count = clampi(boss_count, 1, 4)
	per_section = clampi(per_section, 1, 5)
	match style:
		"hub":
			return _hub(rng, boss_count, per_section)
		"maze":
			return _maze(rng, boss_count)
		"arena":
			return _chain(rng, boss_count, 1, {"arena": true})
		"descent":
			return _chain(rng, boss_count, per_section, {"descent": true})
		"cavern":
			return _chain(rng, boss_count, per_section, {"cavern": true})
	return _chain(rng, boss_count, per_section, {})

static func _room(out: Dictionary, cell: Vector2i, y: float, size: Vector2, kind: String, section: int, boss := -1) -> int:
	var c: float = out["cell"]
	out["rooms"].append({"cell": cell, "center": Vector3(cell.x * c, y, cell.y * c), "size": size,
		"kind": kind, "section": section, "boss": boss})
	return out["rooms"].size() - 1

## A self-avoiding random walk of `length` cells from (0,0).
static func _walk(rng: RandomNumberGenerator, length: int) -> Array:
	for attempt in 400:
		var cells: Array = [Vector2i.ZERO]
		var ok := true
		# Prefer to keep going roughly one way so long dungeons don't coil up.
		var bias: Vector2i = DIRS[rng.randi_range(0, 3)]
		while cells.size() < length:
			var options: Array = []
			for d in DIRS:
				var n: Vector2i = cells.back() + d
				if not cells.has(n):
					options.append(n)
					if d == bias:
						options.append(n)   # weighted twice
			if options.is_empty():
				ok = false
				break
			cells.append(options[rng.randi_range(0, options.size() - 1)])
		if ok:
			return cells
	# Fallback: a snake that can't fail.
	var snake: Array = []
	for i in length:
		var row := i / 4
		var col := i % 4 if row % 2 == 0 else 3 - i % 4
		snake.append(Vector2i(col, row))
	return snake

# --- Chain styles: linear / descent / cavern / arena ------------------------------------

static func _chain(rng: RandomNumberGenerator, bosses: int, per: int, opt: Dictionary) -> Dictionary:
	var cavern: bool = opt.get("cavern", false)
	var arena: bool = opt.get("arena", false)
	var descent: bool = opt.get("descent", false)
	var out := {"cell": 26.0 if cavern or arena else 22.0, "corridor": 6.0 if cavern else 3.6,
		"roam": cavern, "rooms": [], "links": []}
	var length := 1 + bosses * (per + 1)
	var cells := _walk(rng, length)
	var prev := -1
	var i := 0
	var start := _room(out, cells[0], 0.0, Vector2(10, 10), "start", 0)
	prev = start
	i = 1
	var occupied: Array = cells.duplicate()
	for s in bosses:
		var y := -DROP * s if descent else 0.0
		var section_rooms: Array = []
		for r in per:
			var size := Vector2(rng.randi_range(10, 14), rng.randi_range(10, 14))
			if cavern:
				size = Vector2(rng.randi_range(15, 20), rng.randi_range(15, 20))
			if arena:
				size = Vector2(20, 20)
			var idx := _room(out, cells[i], y, size, "combat", s)
			out["links"].append([prev, idx])
			section_rooms.append(idx)
			prev = idx
			i += 1
		var b := _room(out, cells[i], y, Vector2(21, 21) if not (cavern or arena) else Vector2(23, 23), "boss", s, s)
		out["links"].append([prev, b])
		prev = b
		i += 1
		# Side rooms off this section's combat rooms (not in arena mode).
		if arena:
			continue
		var sides := 2 if cavern else 1
		for n in sides:
			for attempt in 30:
				var host: int = section_rooms[rng.randi_range(0, section_rooms.size() - 1)]
				var c: Vector2i = out["rooms"][host]["cell"] + DIRS[rng.randi_range(0, 3)]
				if occupied.has(c):
					continue
				occupied.append(c)
				var ss := Vector2(rng.randi_range(9, 11), rng.randi_range(9, 11))
				if cavern:
					ss = Vector2(rng.randi_range(12, 16), rng.randi_range(12, 16))
				var sr := _room(out, c, y, ss, "side", s)
				out["links"].append([host, sr])
				break
	return out

# --- Hand-made (a DungeonLayout scene) ------------------------------------------------------
# Same output as the styles above, plus per room: name, roster, centerpiece,
# big_props, no_random, packs [{roles, elites, keybearer, at}] and pieces
# [{kind, at, yaw, params}] (positions in world space).

static func from_scene(scene: PackedScene) -> Dictionary:
	var out := {"cell": 22.0, "corridor": 3.6, "roam": false, "rooms": [], "links": [], "authored": true}
	if scene == null:
		return out
	var root := scene.instantiate()
	out["cell"] = float(root.get("cell_size")) if root.get("cell_size") != null else 22.0
	out["corridor"] = float(root.get("corridor")) if root.get("corridor") != null else 3.6
	out["final_needs_wings"] = bool(root.get("final_needs_wings")) if root.get("final_needs_wings") != null else false
	for child in root.get_children():
		if child is DungeonRoom:
			_read_room(out, child, -1)
	root.free()
	return out

static func _read_room(out: Dictionary, n: DungeonRoom, parent: int) -> void:
	var idx := _room(out, n.cell, n.floor_y, n.size, n.kind, n.section, n.boss)
	var room: Dictionary = out["rooms"][idx]
	var center: Vector3 = room["center"]
	room["name"] = n.room_name
	room["roster"] = n.roster
	room["centerpiece"] = n.centerpiece
	room["big_props"] = Array(n.big_props)
	room["no_random"] = n.no_random_packs
	room["packs"] = []
	room["pieces"] = []
	if parent >= 0:
		out["links"].append([parent, idx])
	for child in n.get_children():
		if child is PackMarker:
			room["packs"].append({"roles": Array(child.roles), "elites": child.elites,
				"keybearer": child.keybearer, "at": center + child.position})
		elif child is SetPieceMarker:
			room["pieces"].append({"kind": child.kind, "at": center + child.position,
				"yaw": child.rotation.y, "params": child.params.duplicate()})
	for child in n.get_children():
		if child is DungeonRoom:
			_read_room(out, child, idx)

# --- Hub and spokes ---------------------------------------------------------------------

static func _hub(rng: RandomNumberGenerator, bosses: int, per: int) -> Dictionary:
	var out := {"cell": 22.0, "corridor": 4.0, "roam": false, "rooms": [], "links": []}
	var wings := clampi(bosses - 1, 1, 3)
	var final_section := wings
	var start := _room(out, Vector2i(0, 1), 0.0, Vector2(10, 10), "start", final_section)
	var hub := _room(out, Vector2i(0, 0), 0.0, Vector2(18, 18), "hub", final_section)
	out["links"].append([start, hub])
	var wing_dirs := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]
	var junction := -1
	for w in wings:
		var d: Vector2i = wing_dirs[w]
		var prev := hub
		for r in per:
			var size := Vector2(rng.randi_range(10, 14), rng.randi_range(10, 14))
			var idx := _room(out, d * (r + 1), 0.0, size, "combat", w)
			out["links"].append([prev, idx])
			if w == 2 and r == 0:
				junction = idx
			prev = idx
		var b := _room(out, d * (per + 1), 0.0, Vector2(20, 20), "boss", w, w)
		out["links"].append([prev, b])
	# Final boss: off the north wing's first room when there are 3 wings,
	# otherwise straight north of the hub.
	var fb: int
	if wings == 3 and junction >= 0:
		fb = _room(out, Vector2i(1, -1), 0.0, Vector2(20, 20), "boss", final_section, final_section)
		out["links"].append([junction, fb])
	else:
		fb = _room(out, Vector2i(0, -1), 0.0, Vector2(20, 20), "boss", final_section, final_section)
		out["links"].append([hub, fb])
	out["final_needs_wings"] = true
	return out

# --- Maze / catacombs ------------------------------------------------------------------

static func _maze(rng: RandomNumberGenerator, bosses: int) -> Dictionary:
	var W := 6
	var H := 5
	var out := {"cell": 18.0, "corridor": 3.0, "roam": false, "rooms": [], "links": []}
	var start_cell := Vector2i(0, H - 1)
	# Random depth-first spanning tree over the grid.
	var parent := {start_cell: start_cell}
	var order: Array = [start_cell]
	var stack: Array = [start_cell]
	while not stack.is_empty():
		var cur: Vector2i = stack.back()
		var options: Array = []
		for d in DIRS:
			var n: Vector2i = cur + d
			if n.x >= 0 and n.y >= 0 and n.x < W and n.y < H and not parent.has(n):
				options.append(n)
		if options.is_empty():
			stack.pop_back()
			continue
		var nxt: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		parent[nxt] = cur
		order.append(nxt)
		stack.append(nxt)
	# Longest path from the start: bosses go along it, the final one at its end.
	var depth := {start_cell: 0}
	for c in order:
		if c != start_cell:
			depth[c] = int(depth[parent[c]]) + 1
	var far: Vector2i = start_cell
	for c in order:
		if int(depth[c]) > int(depth[far]):
			far = c
	var path: Array = [far]
	while path.back() != start_cell:
		path.append(parent[path.back()])
	path.reverse()
	var boss_cells := {}
	for k in bosses:
		var at := int(round(float(path.size() - 1) * float(k + 1) / float(bosses)))
		at = clampi(at, 2, path.size() - 1)
		while boss_cells.has(path[at]) and at < path.size() - 1:
			at += 1
		boss_cells[path[at]] = k
	# Rooms in tree order (parents before children).
	var index := {}
	for c in order:
		var is_boss := boss_cells.has(c)
		var kind := "start" if c == start_cell else ("boss" if is_boss else ("combat" if rng.randf() < 0.6 else "junction"))
		var size := Vector2(rng.randi_range(7, 9), rng.randi_range(7, 9))
		if c == start_cell:
			size = Vector2(9, 9)
		elif is_boss:
			size = Vector2(16, 16)
		index[c] = _room(out, c, 0.0, size, kind, 0, int(boss_cells[c]) if is_boss else -1)
		if c != start_cell:
			out["links"].append([index[parent[c]], index[c]])
	# Section = bosses passed on the way from the start (a boss room is its own section).
	for c in order:
		var passed := 0
		var p: Vector2i = c
		while p != start_cell:
			p = parent[p]
			if boss_cells.has(p):
				passed += 1
		out["rooms"][index[c]]["section"] = int(boss_cells[c]) if boss_cells.has(c) else passed
	return out
