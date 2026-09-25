extends Node

# Shared data for the minimap and the local map (M):
#   - Layout: the level's walkable floor, read from its NavigationRegion3D
#     navmesh (works for every level: the Cave, generated Crypt floors, ...).
#   - Fog of war: a grid of explored cells. Everything within REVEAL_RADIUS of
#     the player is uncovered and stays uncovered for this floor. Stored in an
#     image (1 px per cell) so the maps can draw it as a single texture.

const CELL := 1.0            # metres per fog cell
const REVEAL_RADIUS := 9.0   # metres around the player that get uncovered
const REVEAL_INTERVAL := 0.15

signal layout_changed

var polygons: Array[PackedVector2Array] = []   # world XZ floor polygons
var bounds := Rect2()                          # world XZ bounds of the floor
var fog_image: Image
var fog_texture: ImageTexture

var _region: NavigationRegion3D
var _vertex_count := -1
var _explored := {}          # Vector2i cell -> true
var _timer := 0.0
var _poll := 0.0

func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.5
		_refresh_layout()
	_timer -= delta
	if _timer <= 0.0 and fog_image:
		_timer = REVEAL_INTERVAL
		var p := player()
		if p:
			_reveal(Vector2(p.global_position.x, p.global_position.z))

func player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D

# --- Layout ------------------------------------------------------------------------

func _refresh_layout() -> void:
	if _region == null or not is_instance_valid(_region):
		var scene := get_tree().current_scene
		_region = null
		if scene:
			for n in scene.find_children("*", "NavigationRegion3D", true, false):
				_region = n
				break
	if _region == null or _region.navigation_mesh == null:
		return
	var nm := _region.navigation_mesh
	var verts := nm.get_vertices()
	if verts.size() == _vertex_count:
		return
	_vertex_count = verts.size()
	polygons.clear()
	if verts.is_empty():
		return
	var xf := _region.global_transform
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for i in nm.get_polygon_count():
		var idx := nm.get_polygon(i)
		var poly := PackedVector2Array()
		for k in idx:
			var w := xf * verts[k]
			var p := Vector2(w.x, w.z)
			poly.append(p)
			mn = mn.min(p)
			mx = mx.max(p)
		if poly.size() >= 3:
			polygons.append(poly)
	bounds = Rect2(mn, mx - mn).grow(REVEAL_RADIUS)
	_build_fog()
	layout_changed.emit()

func _build_fog() -> void:
	var w := maxi(int(ceil(bounds.size.x / CELL)), 1)
	var h := maxi(int(ceil(bounds.size.y / CELL)), 1)
	fog_image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	fog_image.fill(Color(0, 0, 0, 1))
	for c in _explored:
		_clear_cell(c)
	fog_texture = ImageTexture.create_from_image(fog_image)

# --- Fog of war ------------------------------------------------------------------------

func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - bounds.position.x) / CELL), floori((p.y - bounds.position.y) / CELL))

func is_explored(world_xz: Vector2) -> bool:
	return _explored.has(_cell_of(world_xz))

func _clear_cell(c: Vector2i) -> void:
	if c.x >= 0 and c.y >= 0 and c.x < fog_image.get_width() and c.y < fog_image.get_height():
		fog_image.set_pixelv(c, Color(0, 0, 0, 0))

func _reveal(center: Vector2) -> void:
	var r := int(ceil(REVEAL_RADIUS / CELL))
	var c0 := _cell_of(center)
	var changed := false
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy > r * r:
				continue
			var c := c0 + Vector2i(dx, dy)
			if _explored.has(c):
				continue
			_explored[c] = true
			_clear_cell(c)
			changed = true
	if changed:
		fog_texture.update(fog_image)

# --- Projection shared by both maps ------------------------------------------------------

## World XZ -> map transform. "Up" on the map is the camera's forward, so the
## map is turned the same way as the screen.
func map_transform(world_center: Vector2, screen_center: Vector2, px_per_m: float) -> Transform2D:
	var fwd := Vector2(0, -1)
	var cam := get_viewport().get_camera_3d()
	if cam:
		var f := -cam.global_basis.z
		if Vector2(f.x, f.z).length() > 0.01:
			fwd = Vector2(f.x, f.z).normalized()
	var right := Vector2(-fwd.y, fwd.x)
	var x_axis := Vector2(right.x, -fwd.x) * px_per_m
	var y_axis := Vector2(right.y, -fwd.y) * px_per_m
	var t := Transform2D(x_axis, y_axis, Vector2.ZERO)
	t.origin = screen_center - t.basis_xform(world_center)
	return t

## Size in metres of the layout when turned like the map (for fitting it).
func rotated_extent() -> Vector2:
	var t := map_transform(Vector2.ZERO, Vector2.ZERO, 1.0)
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for corner in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end,
			Vector2(bounds.position.x, bounds.end.y)]:
		var p: Vector2 = t * corner
		mn = mn.min(p)
		mx = mx.max(p)
	return mx - mn

## Things worth marking: [{"pos": Vector2 world XZ, "kind": String}], where kind
## is "enemy", "elite", "boss", "party", "chest", "exit".
func markers() -> Array:
	var out := []
	var p := player()
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D) or not e.is_alive():
			continue
		var ep := Vector2(e.global_position.x, e.global_position.z)
		# Only enemies you could actually spot: near you, in explored ground.
		if p == null or ep.distance_to(Vector2(p.global_position.x, p.global_position.z)) > REVEAL_RADIUS * 2.0:
			continue
		if not is_explored(ep):
			continue
		var r := str(e.get("rank"))
		out.append({"pos": ep, "kind": r if r == "elite" or r == "boss" else "enemy"})
	for m in get_tree().get_nodes_in_group("remote_player"):
		if m is Node3D:
			out.append({"pos": Vector2(m.global_position.x, m.global_position.z), "kind": "party"})
	var scene := get_tree().current_scene
	if scene:
		var chests: Variant = scene.get("_chests")
		if chests is Dictionary:
			for c in chests.values():
				if is_instance_valid(c) and c is Node3D:
					var cp := Vector2(c.global_position.x, c.global_position.z)
					if is_explored(cp):
						out.append({"pos": cp, "kind": "chest"})
		var exit_pos: Variant = scene.get("_exit_pos")
		if exit_pos is Vector3 and exit_pos != Vector3.ZERO:
			var xp := Vector2(exit_pos.x, exit_pos.z)
			if is_explored(xp):
				out.append({"pos": xp, "kind": "exit"})
	return out
