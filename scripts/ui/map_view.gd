extends Control

# Draws MapData: floor layout, fog of war, markers and the player arrow.
#   mini = true:  follows the player at a fixed zoom (the minimap)
#   mini = false: fits the whole floor (the local map, M)

const FLOOR_COL := Color(0.46, 0.44, 0.40)
## Everything you have seen that can't be walked on (rock, walls, pillars) is
## filled with this: solid wall, clearly neither a room nor unexplored ground.
const WALL_COL := Color(0.17, 0.16, 0.15)
const BG_COL := Color(0.03, 0.035, 0.05, 1.0)
const FOG_TINT := BG_COL   # unexplored = same as the background (no visible edge)
const MARKER_COLORS := {
	"enemy": Color(0.95, 0.25, 0.2), "elite": Color(1.0, 0.6, 0.15), "boss": Color(1.0, 0.1, 0.1),
	"party": Color(0.35, 0.95, 0.45), "chest": Color(1.0, 0.85, 0.3), "exit": Color(0.35, 0.85, 1.0),
}

var data: Node
var mini := true
var px_per_m := 4.5   # minimap zoom (180 px ≈ 40 m across)

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

var _redraw_t := 0.0

func _process(delta: float) -> void:
	# ~20 redraws a second (plenty for a map; it used to redraw every frame).
	_redraw_t -= delta
	if _redraw_t <= 0.0 and is_visible_in_tree():
		_redraw_t = 0.05
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG_COL, true)
	if data == null or data.polygons.is_empty():
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(8, size.y / 2.0), "No map", HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 13, Color(0.6, 0.6, 0.65))
		return
	var p: Node3D = data.player()
	var ppos: Vector2 = Vector2(p.global_position.x, p.global_position.z) if p else data.bounds.get_center()
	var t: Transform2D
	if mini:
		t = data.map_transform(ppos, size / 2.0, px_per_m)
	else:
		var ext: Vector2 = data.rotated_extent()
		var s := minf(size.x / maxf(ext.x, 1.0), size.y / maxf(ext.y, 1.0)) * 0.95
		t = data.map_transform(data.bounds.get_center(), size / 2.0, s)

	# Solid wall everywhere, the floor on top of it, then the fog texture over
	# both (all in world coordinates): explored rock shows as wall, unexplored
	# ground stays black.
	draw_set_transform_matrix(t)
	draw_rect(data.bounds, WALL_COL, true)
	# The whole floor is one cached mesh (one draw call instead of hundreds of polygons).
	if data.floor_mesh:
		draw_mesh(data.floor_mesh, null, Transform2D.IDENTITY, FLOOR_COL)
	else:
		for poly in data.polygons:
			draw_colored_polygon(poly, FLOOR_COL)
	if data.fog_texture:
		draw_texture_rect(data.fog_texture, data.bounds, false, FOG_TINT)
	draw_set_transform_matrix(Transform2D.IDENTITY)

	# Markers (screen space so they keep their size).
	var scale_px := t.x.length()
	var dot := clampf(scale_px * 0.5, 2.5, 5.0)
	for m in data.markers():
		var sp: Vector2 = t * m["pos"]
		if not Rect2(Vector2.ZERO, size).grow(6).has_point(sp):
			continue
		var col: Color = MARKER_COLORS.get(m["kind"], Color.WHITE)
		match m["kind"]:
			"chest":
				draw_rect(Rect2(sp - Vector2(dot, dot), Vector2(dot, dot) * 2.0), col, true)
			"exit":
				draw_arc(sp, dot * 1.6, 0.0, TAU, 20, col, 2.0, true)
			"boss":
				draw_circle(sp, dot * 1.8, col)
			"elite":
				draw_circle(sp, dot * 1.35, col)
			_:
				draw_circle(sp, dot, col)

	# Player arrow, pointing where the character faces.
	if p:
		var sp: Vector2 = t * ppos
		var f3 := -p.global_basis.z
		var dir: Vector2 = t.basis_xform(Vector2(f3.x, f3.z)).normalized()
		var side := Vector2(-dir.y, dir.x)
		var k := 7.0 if mini else 8.0
		var tri := PackedVector2Array([sp + dir * k, sp - dir * k * 0.6 + side * k * 0.65,
			sp - dir * k * 0.25, sp - dir * k * 0.6 - side * k * 0.65])
		draw_colored_polygon(tri, Color(1.0, 0.9, 0.4))
		draw_polyline(tri + PackedVector2Array([tri[0]]), Color(0, 0, 0, 0.8), 1.5, true)

	# Frame
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.35, 0.33, 0.3), false, 2.0)
