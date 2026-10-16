extends RefCounted

# A flat (XZ) spatial grid of every living body in a group, built at most once per
# physics frame and shared by everyone asking. Lets crowd separation look only at
# nearby bodies instead of the whole group (O(n) per frame instead of O(n²)).
# Generic: works for any group of Node3Ds; enemy.gd uses it for "enemies".

const Combat = preload("res://scripts/combat_utils.gd")

## Cell size in metres. Bigger bodies are still found: lookups widen by the largest radius.
const CELL := 3.0

## group -> this physics frame's grid (see build()) plus its "frame".
static var _grids := {}

## Bodies of `group` whose hitboxes could overlap a circle of `radius` at `pos`:
## [[node, position, hitbox radius], ...] (positions as of this frame's build).
static func near(tree: SceneTree, group: StringName, pos: Vector3, radius: float) -> Array:
	return query(_grid(tree, group), pos, radius)

## A grid from [[node, position, radius], ...]: {"cells": {Vector2i: [entries]}, "max_radius"}.
static func build(entries: Array) -> Dictionary:
	var cells := {}
	var max_r := 0.0
	for e in entries:
		max_r = maxf(max_r, float(e[2]))
		var k := _cell(e[1])
		if not cells.has(k):
			cells[k] = []
		cells[k].append(e)
	return {"cells": cells, "max_radius": max_r}

## The entries of grid `g` in the cells a circle of `radius` at `pos` could touch.
static func query(g: Dictionary, pos: Vector3, radius: float) -> Array:
	var reach := radius + float(g["max_radius"])
	var lo := _cell(pos - Vector3(reach, 0.0, reach))
	var hi := _cell(pos + Vector3(reach, 0.0, reach))
	var cells: Dictionary = g["cells"]
	var out := []
	for x in range(lo.x, hi.x + 1):
		for z in range(lo.y, hi.y + 1):
			var c: Array = cells.get(Vector2i(x, z), [])
			if not c.is_empty():
				out.append_array(c)
	return out

## Drop every cached grid.
static func clear() -> void:
	_grids.clear()

static func _grid(tree: SceneTree, group: StringName) -> Dictionary:
	var frame := Engine.get_physics_frames()
	var g: Dictionary = _grids.get(group, {})
	if not g.is_empty() and int(g["frame"]) == frame:
		return g
	var entries := []
	for n in tree.get_nodes_in_group(group):
		if not (n is Node3D) or not n.is_inside_tree():
			continue
		if n.has_method("is_alive") and not n.is_alive():
			continue
		entries.append([n, n.global_position, Combat.hitbox_radius(n)])
	g = build(entries)
	g["frame"] = frame
	_grids[group] = g
	return g

static func _cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))
