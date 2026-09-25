@tool
extends Node3D

# Procedural low-poly goblin, built on a standard Mixamo humanoid skeleton.
#
# The scene (goblin_model.tscn) instances a rigged Mixamo model only for its
# skeleton + animations; this script removes that model's meshes and generates
# the goblin as ONE skinned mesh bound to the same skeleton (each part rigidly
# follows its bone). So it plays every Mixamo animation (idle, walk, ...),
# costs two draw calls (body + glowing eyes), and is built once then shared by
# every goblin. Sizes are proportional to the skeleton, so it works at any scale.
#
# Placeholder art: to use a real goblin later, make goblin_model.tscn an
# instance of the real model file instead (and remove this script).

const SKIN := Color(0.40, 0.58, 0.22)
const SKIN_DARK := Color(0.29, 0.44, 0.16)
const LEATHER := Color(0.33, 0.21, 0.11)
const LEATHER_DARK := Color(0.2, 0.13, 0.07)
const CLOTH := Color(0.47, 0.37, 0.22)
const METAL := Color(0.58, 0.6, 0.63)
const TOOTH := Color(0.92, 0.88, 0.7)
const MOUTH := Color(0.14, 0.04, 0.04)
const PUPIL := Color(0.05, 0.03, 0.02)
const EYE := Color(1.0, 0.82, 0.2)

const REQUIRED := ["Hips", "Spine", "Spine2", "Neck", "Head",
	"LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand",
	"LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
	"RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]

static var _cache := {}   # rig key -> {"mesh": ArrayMesh, "skin": Skin}

func _ready() -> void:
	var found := find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		push_warning("goblin_model: no Skeleton3D in the rig")
		return
	var sk: Skeleton3D = found[0]
	if sk.has_node("GoblinBody"):
		return
	var key := "%s|%d" % [scene_file_path, sk.get_bone_count()]
	if Engine.is_editor_hint() or not _cache.has(key):
		var built := _Builder.new().build(sk)
		if built.is_empty():
			return   # unexpected rig: keep the original model visible
		_cache[key] = built
	# Remove the rig's own meshes (hidden in the editor so the scene isn't changed).
	for c in sk.get_children():
		if c is MeshInstance3D:
			if Engine.is_editor_hint():
				c.visible = false
			else:
				sk.remove_child(c)
				c.queue_free()
	var mi := MeshInstance3D.new()
	mi.name = "GoblinBody"
	mi.mesh = _cache[key]["mesh"]
	mi.skin = _cache[key]["skin"]
	sk.add_child(mi)
	mi.skeleton = mi.get_path_to(sk)


class _Builder:
	var sk: Skeleton3D
	var s := 1.0                       # unit: hips -> head distance
	var up := Vector3.UP
	var right := Vector3.RIGHT
	var fwd := Vector3.BACK
	# Current surface being filled.
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var b := PackedInt32Array()
	var w := PackedFloat32Array()
	var idx := PackedInt32Array()
	var mesh := ArrayMesh.new()

	func bi(bone: String) -> int:
		for i in sk.get_bone_count():
			var nm := sk.get_bone_name(i)
			if nm == bone or nm.ends_with(":" + bone) or nm.ends_with("_" + bone):
				return i
		return -1

	func p(bone: String) -> Vector3:
		return sk.get_bone_global_rest(bi(bone)).origin

	func build(skeleton: Skeleton3D) -> Dictionary:
		sk = skeleton
		for r in REQUIRED:
			if bi(r) == -1:
				push_warning("goblin_model: rig has no '%s' bone" % r)
				return {}
		var hips := p("Hips")
		var head := p("Head")
		s = hips.distance_to(head)
		up = (head - hips).normalized()
		var r := p("RightArm") - p("LeftArm")
		right = (r - up * r.dot(up)).normalized()
		fwd = up.cross(right)

		_body(hips, head)
		_commit(_body_material())
		_eyes(head)
		_commit(_eye_material())
		return {"mesh": mesh, "skin": sk.create_skin_from_rest_transforms()}

	# --- The goblin ----------------------------------------------------------------

	func _body(hips: Vector3, head: Vector3) -> void:
		# Torso: pelvis, pot belly, narrow hunched chest.
		sphere("Hips", hips + up * 0.02 * s, 0.17 * s, LEATHER, Vector3(1.15, 0.8, 0.95))
		sphere("Spine", p("Spine") + up * 0.08 * s + fwd * 0.04 * s, 0.19 * s, SKIN, Vector3(1.05, 1.0, 1.0))
		sphere("Spine2", p("Spine2") + up * 0.04 * s, 0.155 * s, SKIN, Vector3(1.3, 0.85, 0.85))
		capsule("Neck", p("Neck") - up * 0.03 * s, head, 0.05 * s, SKIN)

		# Belt + loincloth flaps.
		cylinder("Hips", hips + up * 0.09 * s, 0.195 * s, 0.05 * s, LEATHER_DARK, Vector3(1.1, 1.0, 0.95))
		box("Hips", hips + fwd * 0.15 * s - up * 0.13 * s, Vector3(0.22, 0.28, 0.025) * s, CLOTH, up - fwd * 0.15)
		box("Hips", hips - fwd * 0.15 * s - up * 0.13 * s, Vector3(0.24, 0.26, 0.025) * s, CLOTH, up + fwd * 0.15)

		# Head: big and wide, heavy brow, long nose, jaw with tusks, huge ears.
		var hc := head + up * 0.17 * s + fwd * 0.02 * s
		sphere("Head", hc, 0.2 * s, SKIN, Vector3(1.1, 0.95, 1.0))
		sphere("Head", hc - up * 0.1 * s + fwd * 0.06 * s, 0.13 * s, SKIN, Vector3(1.1, 0.7, 1.0))
		box("Head", hc + up * 0.065 * s + fwd * 0.165 * s, Vector3(0.3, 0.05, 0.08) * s, SKIN_DARK, up + fwd * 0.3)
		cone("Head", hc + fwd * 0.18 * s, (fwd - up * 0.35).normalized(), 0.17 * s, 0.045 * s, SKIN)
		box("Head", hc - up * 0.075 * s + fwd * 0.17 * s, Vector3(0.14, 0.02, 0.03) * s, MOUTH, up)
		for side: float in [-1.0, 1.0]:
			cone("Head", hc - up * 0.1 * s + fwd * 0.15 * s + right * side * 0.06 * s, up, 0.07 * s, 0.02 * s, TOOTH)
			var ear_base := hc + right * side * 0.19 * s + up * 0.03 * s
			var ear_dir := (right * side + up * 0.45 - fwd * 0.25).normalized()
			cone("Head", ear_base, ear_dir, 0.42 * s, 0.08 * s, SKIN, 0.35)
			cone("Head", ear_base + fwd * 0.012 * s, ear_dir, 0.3 * s, 0.05 * s, SKIN_DARK, 0.3)
			# Pupils (the glowing eyes themselves are their own surface).
			sphere("Head", hc + fwd * 0.2 * s + right * side * 0.085 * s + up * 0.02 * s, 0.018 * s, PUPIL)

		# Arms: skinny, knobbly shoulders, leather wrist wraps, one shoulder pad.
		for lr in ["Left", "Right"]:
			var arm := p(lr + "Arm")
			var fore := p(lr + "ForeArm")
			var hand := p(lr + "Hand")
			sphere(lr + "Arm", arm, 0.07 * s, SKIN)
			capsule(lr + "Arm", arm, fore, 0.05 * s, SKIN)
			capsule(lr + "ForeArm", fore, hand, 0.045 * s, SKIN)
			capsule(lr + "ForeArm", fore.lerp(hand, 0.6), fore.lerp(hand, 0.95), 0.053 * s, LEATHER)
			var hdir := (hand - fore).normalized()
			sphere(lr + "Hand", hand + hdir * 0.06 * s, 0.06 * s, SKIN_DARK, Vector3(1.0, 1.2, 0.8))
			# Legs: short, bony, with oversized feet.
			var thigh := p(lr + "UpLeg")
			var knee := p(lr + "Leg")
			var ankle := p(lr + "Foot")
			var toe := p(lr + "ToeBase")
			capsule(lr + "UpLeg", thigh, knee, 0.075 * s, SKIN)
			capsule(lr + "Leg", knee, ankle, 0.058 * s, SKIN)
			capsule(lr + "Foot", ankle, toe + (toe - ankle) * 0.6, 0.065 * s, SKIN_DARK)
		sphere("LeftArm", p("LeftArm") + up * 0.035 * s, 0.085 * s, LEATHER, Vector3(1.2, 0.6, 1.1))

		# Crude dagger in the right fist, pointing forward.
		var rh := p("RightHand") + (p("RightHand") - p("RightForeArm")).normalized() * 0.06 * s
		cylinder("RightHand", rh, 0.018 * s, 0.11 * s, LEATHER_DARK, Vector3.ONE, fwd)
		box("RightHand", rh + fwd * 0.065 * s, Vector3(0.1, 0.02, 0.025) * s, LEATHER_DARK, fwd)
		box("RightHand", rh + fwd * 0.22 * s, Vector3(0.05, 0.28, 0.012) * s, METAL, fwd)
		cone("RightHand", rh + fwd * 0.36 * s, fwd, 0.06 * s, 0.025 * s, METAL, 0.3)

	func _eyes(head: Vector3) -> void:
		var hc := head + up * 0.17 * s + fwd * 0.02 * s
		for side: float in [-1.0, 1.0]:
			sphere("Head", hc + fwd * 0.17 * s + right * side * 0.085 * s + up * 0.02 * s, 0.04 * s, EYE)

	# --- Shape helpers (all positions in skeleton space) -----------------------------

	## Orthonormal basis with Y along `y` and Z as close to forward as possible.
	func frame(y: Vector3) -> Basis:
		var yy := y.normalized()
		var z := fwd - yy * fwd.dot(yy)
		if z.length() < 0.01:
			z = up - yy * up.dot(yy)
		z = z.normalized()
		return Basis(yy.cross(z), yy, z)

	func sphere(bone: String, at: Vector3, radius: float, col: Color, stretch := Vector3.ONE) -> void:
		var m := SphereMesh.new()
		m.radius = 1.0
		m.height = 2.0
		m.radial_segments = 12
		m.rings = 6
		add(m, Transform3D(frame(up).scaled_local(stretch * radius), at), bone, col)

	func capsule(bone: String, a: Vector3, z: Vector3, radius: float, col: Color) -> void:
		var m := CapsuleMesh.new()
		m.radius = radius
		m.height = a.distance_to(z) + radius * 2.0
		m.radial_segments = 10
		m.rings = 2
		add(m, Transform3D(frame(z - a), (a + z) * 0.5), bone, col)

	func cone(bone: String, base: Vector3, dir: Vector3, length: float, radius: float, col: Color, flatten := 1.0) -> void:
		var m := CylinderMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = radius
		m.height = length
		m.radial_segments = 8
		m.rings = 1
		var basis := frame(dir).scaled_local(Vector3(1.0, 1.0, flatten))
		add(m, Transform3D(basis, base + dir.normalized() * length * 0.5), bone, col)

	func cylinder(bone: String, at: Vector3, radius: float, height: float, col: Color, stretch := Vector3.ONE, axis := Vector3.ZERO) -> void:
		var m := CylinderMesh.new()
		m.top_radius = radius
		m.bottom_radius = radius
		m.height = height
		m.radial_segments = 10
		m.rings = 1
		var basis := frame(up if axis == Vector3.ZERO else axis).scaled_local(stretch)
		add(m, Transform3D(basis, at), bone, col)

	func box(bone: String, at: Vector3, size: Vector3, col: Color, y_dir: Vector3) -> void:
		var m := BoxMesh.new()
		m.size = size
		add(m, Transform3D(frame(y_dir), at), bone, col)

	## Append a primitive, transformed into skeleton space and rigidly bound to `bone`.
	func add(prim: PrimitiveMesh, xf: Transform3D, bone: String, col: Color) -> void:
		var arr := prim.get_mesh_arrays()
		var pv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var pn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var pi: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var nb := xf.basis.inverse().transposed()
		var bone_i := bi(bone)
		var base := v.size()
		for i in pv.size():
			v.append(xf * pv[i])
			n.append((nb * pn[i]).normalized())
			c.append(col)
			b.append_array(PackedInt32Array([bone_i, 0, 0, 0]))
			w.append_array(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
		for i in pi:
			idx.append(base + i)

	func _commit(mat: Material) -> void:
		if v.is_empty():
			return
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = v
		a[Mesh.ARRAY_NORMAL] = n
		a[Mesh.ARRAY_COLOR] = c
		a[Mesh.ARRAY_BONES] = b
		a[Mesh.ARRAY_WEIGHTS] = w
		a[Mesh.ARRAY_INDEX] = idx
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
		v = PackedVector3Array()
		n = PackedVector3Array()
		c = PackedColorArray()
		b = PackedInt32Array()
		w = PackedFloat32Array()
		idx = PackedInt32Array()

	func _body_material() -> Material:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.85
		return m

	func _eye_material() -> Material:
		var m := StandardMaterial3D.new()
		m.albedo_color = EYE
		m.emission_enabled = true
		m.emission = EYE
		m.emission_energy_multiplier = 2.5
		return m
