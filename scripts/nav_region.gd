extends NavigationRegion3D

# Bakes a navigation mesh from the cave rock at game start so enemies can
# path around pillars and corners. Only floor-level geometry is used (rock
# tops are excluded) so agents can't route over the walls.

@export var source_path: NodePath          # the cave's CSG rock (CSGCombiner3D)
@export var agent_radius: float = 0.45
@export var agent_height: float = 1.8

const SOURCE_GROUP := "navmesh_source"
## Half-size (XZ) of the area that gets baked around the origin.
@export var bake_half_extent: float = 40.0
## Off for generated levels: the generator calls bake_from() once the rock exists.
@export var auto_bake: bool = true

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
	nm.filter_baking_aabb = AABB(Vector3(-e, -1, -e), Vector3(e * 2.0, 2.5, e * 2.0))
	navigation_mesh = nm

	if debug_draw:
		get_tree().debug_navigation_hint = true
	bake_finished.connect(_on_baked)

	# CSG builds its mesh a frame after entering the tree; wait before baking.
	await get_tree().process_frame
	await get_tree().process_frame
	bake_navigation_mesh(true)

@export var debug_draw := false

func _on_baked() -> void:
	var nm := navigation_mesh
	var verts := nm.get_vertices()
	var box := AABB()
	if verts.size() > 0:
		box = AABB(verts[0], Vector3.ZERO)
		for v in verts:
			box = box.expand(v)
	print("[nav] baked: polygons=%d vertices=%d bounds=%s" % [nm.get_polygon_count(), verts.size(), box])
