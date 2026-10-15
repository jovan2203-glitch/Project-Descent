extends NavigationRegion3D

# Bakes a navigation mesh from a level's rock (CSG) at game start so enemies can
# path around pillars and corners. Only floor-level geometry is used (rock
# tops are excluded) so agents can't route over the walls.

@export var source_path: NodePath          # the level's CSG rock (CSGCombiner3D)
@export var agent_radius: float = 0.45
@export var agent_height: float = 1.8

const SOURCE_GROUP := "navmesh_source"
## Half-size (XZ) of the area that gets baked around the origin.
@export var bake_half_extent: float = 40.0
## Height band that gets baked (floor level). Multi-level dungeons widen it.
@export var bake_min_y: float = -1.0
@export var bake_max_y: float = 1.5
## Off for generated levels: the generator calls bake_from() once the rock exists.
@export var auto_bake: bool = true
## Optional: func(world_point: Vector3) -> bool, true where the level really has
## floor. Baked polygons anywhere else (the tops of walls, in levels with more
## than one floor height) are thrown away: enemies never path over walls and the
## map never shows a wall as a room.
var floor_filter := Callable()

func _ready() -> void:
	if not auto_bake:
		return
	var src := get_node_or_null(source_path)
	if src == null:
		push_warning("nav_region: source_path not set; enemies will move in straight lines")
		return
	bake_from(src)

## Bake from `src` (e.g. a CSGCombiner3D). Waits two frames for CSG meshes.
func bake_from(src: Node) -> void:
	src.add_to_group(SOURCE_GROUP)

	# Reuse the NavigationMesh saved on the node (it exists so the editor doesn't
	# warn); its settings are (re)applied here and it is baked at runtime.
	var nm: NavigationMesh = navigation_mesh if navigation_mesh else NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_MESH_INSTANCES
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = SOURCE_GROUP
	nm.cell_size = 0.25            # matches the default navigation map cell size
	nm.cell_height = 0.25
	nm.agent_radius = agent_radius
	nm.agent_height = agent_height
	nm.agent_max_climb = 0.3
	nm.agent_max_slope = 40.0
	# Only bake near floor level: keeps rock tops out of the walkable area.
	var e := bake_half_extent
	nm.filter_baking_aabb = AABB(Vector3(-e, bake_min_y, -e), Vector3(e * 2.0, bake_max_y - bake_min_y, e * 2.0))
	navigation_mesh = nm

	if debug_draw:
		get_tree().debug_navigation_hint = true
	bake_finished.connect(_on_baked)

	# CSG builds its mesh a frame after entering the tree; wait before baking.
	await get_tree().process_frame
	await get_tree().process_frame
	bake_navigation_mesh(true)

@export var debug_draw := false

## Polygon indices of `polys` (arrays of vertex indices into `verts`) whose centre
## `keep` accepts. `xf` = the region's transform.
static func floor_polygons(verts: PackedVector3Array, polys: Array, xf: Transform3D, keep: Callable) -> Array:
	var out: Array = []
	for idx in polys:
		if idx.size() < 3:
			continue
		var c := Vector3.ZERO
		for k in idx:
			c += verts[k]
		c /= float(idx.size())
		if keep.call(xf * c):
			out.append(idx)
	return out

func _drop_non_floor() -> void:
	var nm := navigation_mesh
	var polys: Array = []
	for i in nm.get_polygon_count():
		polys.append(nm.get_polygon(i))
	var kept := floor_polygons(nm.get_vertices(), polys, global_transform, floor_filter)
	if kept.size() == polys.size():
		return
	nm.clear_polygons()
	for idx in kept:
		nm.add_polygon(idx)
	NavigationServer3D.region_set_navigation_mesh(get_rid(), nm)
	print("[nav] dropped %d polygons that are not on a floor (wall tops)" % (polys.size() - kept.size()))

func _on_baked() -> void:
	if floor_filter.is_valid():
		_drop_non_floor()
	var nm := navigation_mesh
	var verts := nm.get_vertices()
	var box := AABB()
	if verts.size() > 0:
		box = AABB(verts[0], Vector3.ZERO)
		for v in verts:
			box = box.expand(v)
	print("[nav] baked: polygons=%d vertices=%d bounds=%s" % [nm.get_polygon_count(), verts.size(), box])
