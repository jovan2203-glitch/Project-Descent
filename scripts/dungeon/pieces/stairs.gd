@tool
extends Node3D

# Stairs between two floors (every dungeon's height changes use this piece).
#
#   - You WALK on one clean slope collider: a single convex wedge, no seams, so
#     bodies never snag on it. Its low edge sits exactly on the lower floor, its
#     high edge exactly on the upper one.
#   - You SEE stepped stairs (visual only, no collision). Each step's top is at
#     most half a riser off the slope, so feet stay on the steps.
#
# Local space: the origin is the low end's floor edge (middle of the width) and
# the stairs climb `rise` metres over `run` metres towards -Z.
# Swap-ready: an artist's scene can replace scenes/dungeon/pieces/stairs.tscn as
# long as it keeps the exports below (run, rise, width, materials) and keeps a
# smooth collider under the steps.

const STEP_RISE := 0.25    # visual riser height (under the navmesh's 0.3 m climb)
const DEPTH := 0.3         # the wedge's and the steps' solid depth under the low floor

@export var run := 6.0:
	set(v):
		run = v
		_queue_build()
@export var rise := 3.0:
	set(v):
		rise = v
		_queue_build()
@export var width := 3.6:
	set(v):
		width = v
		_queue_build()
@export var step_material: Material:
	set(v):
		step_material = v
		_queue_build()

var _built := false

func _ready() -> void:
	build()

func _queue_build() -> void:
	if is_inside_tree() and _built:
		build.call_deferred()

## (Re)build the collider and the steps from run / rise / width.
func build() -> void:
	for c in get_children():
		if c.has_meta("stairs_part"):
			remove_child(c)
			c.queue_free()
	_built = true
	if run <= 0.01 or width <= 0.01:
		return
	add_child(_collider())
	add_child(_steps())

func _collider() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Slope"
	body.set_meta("stairs_part", true)
	var shape := ConvexPolygonShape3D.new()
	shape.points = slope_points(run, rise, width)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	return body

## The walkable wedge's corners: the top face is the slope from (0, 0, 0) to
## (0, rise, -run); the bottom is DEPTH under the low floor.
static func slope_points(r: float, h: float, w: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for x in [-w * 0.5, w * 0.5]:
		out.append(Vector3(x, 0.0, 0.0))
		out.append(Vector3(x, -DEPTH, 0.0))
		out.append(Vector3(x, h, -r))
		out.append(Vector3(x, -DEPTH, -r))
	return out

## Number of visual steps for a rise.
static func step_count(h: float) -> int:
	return maxi(int(ceil(absf(h) / STEP_RISE)), 1)

## Step i's [top height, front z, back z]. The tops sit half a riser off the
## slope at most; the last step ends flush with the upper floor.
static func step_box(i: int, r: float, h: float) -> Array:
	var n := step_count(h)
	var riser := h / n
	var depth := r / n
	var front := -(float(i) + 0.5) * depth
	var back := maxf(-(float(i) + 1.5) * depth, -r)
	return [float(i + 1) * riser, front, back]

func _steps() -> MeshInstance3D:
	var st := SurfaceTool.new()
	var n := step_count(rise)
	for i in n:
		var b := step_box(i, run, rise)
		var top: float = b[0]
		var front: float = b[1]
		var back: float = b[2]
		var box := BoxMesh.new()
		box.size = Vector3(width, top + DEPTH, front - back)
		var xf := Transform3D(Basis(), Vector3(0, (top - DEPTH) * 0.5, (front + back) * 0.5))
		st.append_from(box, 0, xf)
	var mi := MeshInstance3D.new()
	mi.name = "Steps"
	mi.set_meta("stairs_part", true)
	mi.mesh = st.commit()
	mi.material_override = step_material
	return mi
