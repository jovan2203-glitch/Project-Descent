extends Node

# Performance: splits a generated level's CSG rock into one mesh per grid cell.
#
# The CSG rock is ONE mesh covering the whole dungeon, so the renderer can't
# skip the parts you can't see, and every shadow-casting light (the player's
# lantern) redraws all of it. After the navmesh is baked, this copies the
# rock's triangles into per-cell MeshInstance3Ds (a few thousand triangles per
# frame, so there's no hitch), then stops the CSG from rendering. The CSG node
# stays for its collision.
#
#   var c := RockChunker.new(); c.rock = rock; c.cell = 22.0; level.add_child(c)

const TRIS_PER_FRAME := 6000

var rock: CSGShape3D
var cell := 22.0

var _surfaces: Array = []   # [{arrays, mat}]
var _surf := 0
var _tri := 0
var _tools := {}            # "cx|cz|surface" -> SurfaceTool
var _mats := {}             # same key -> Material
var _xf := Transform3D.IDENTITY

func _ready() -> void:
	if rock == null or not is_instance_valid(rock):
		queue_free()
		return
	var meshes: Array = rock.get_meshes()
	if meshes.size() < 2 or meshes[1] == null:
		queue_free()
		return
	_xf = meshes[0]
	var mesh: Mesh = meshes[1]
	for s in mesh.get_surface_count():
		_surfaces.append({"arrays": mesh.surface_get_arrays(s), "mat": mesh.surface_get_material(s)})

func _process(_delta: float) -> void:
	var budget := TRIS_PER_FRAME
	while budget > 0 and _surf < _surfaces.size():
		var s: Dictionary = _surfaces[_surf]
		var arr: Array = s["arrays"]
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := idx.size() if idx.size() > 0 else v.size()
		var has_n := nrm.size() == v.size()
		while budget > 0 and _tri + 2 < count:
			var i0 := idx[_tri] if idx.size() > 0 else _tri
			var i1 := idx[_tri + 1] if idx.size() > 0 else _tri + 1
			var i2 := idx[_tri + 2] if idx.size() > 0 else _tri + 2
			var a := _xf * v[i0]
			var b := _xf * v[i1]
			var c := _xf * v[i2]
			var mid := (a + b + c) / 3.0
			var key := "%d|%d|%d" % [int(floor(mid.x / cell + 0.5)), int(floor(mid.z / cell + 0.5)), _surf]
			var st: SurfaceTool = _tools.get(key)
			if st == null:
				st = SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				_tools[key] = st
				_mats[key] = s["mat"]
			if has_n:
				st.set_normal(_xf.basis * nrm[i0])
			st.add_vertex(a)
			if has_n:
				st.set_normal(_xf.basis * nrm[i1])
			st.add_vertex(b)
			if has_n:
				st.set_normal(_xf.basis * nrm[i2])
			st.add_vertex(c)
			_tri += 3
			budget -= 1
		if _tri + 2 >= count:
			_surf += 1
			_tri = 0
	if _surf < _surfaces.size():
		return
	# Done: swap the CSG's rendering for the chunks.
	var holder := Node3D.new()
	holder.name = "RockChunks"
	rock.get_parent().add_child(holder)
	for key in _tools:
		var mi := MeshInstance3D.new()
		mi.mesh = (_tools[key] as SurfaceTool).commit()
		mi.material_override = _mats[key]
		holder.add_child(mi)
	rock.layers = 0   # invisible (no camera, no shadows); collision is untouched
	queue_free()
