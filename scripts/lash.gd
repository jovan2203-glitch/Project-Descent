extends RefCounted

# A quick line of lightning between two points that fades at once (Whiplash).
# Only a picture: the hit itself is dealt by whoever lashed.
# Usage: const LASH = preload("res://scripts/lash.gd")

static func spawn(scene: Node, from: Vector3, to: Vector3, color: Color, time: float = 0.25) -> void:
	if scene == null or not scene.is_inside_tree():
		return
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.lightened(0.4), 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = color
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.08, length)
	mesh.material = mat
	var line := MeshInstance3D.new()
	line.mesh = mesh
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(line)
	var dir := (to - from) / length
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT
	line.look_at_from_position((from + to) * 0.5, to, up)
	var t := line.create_tween()
	t.tween_property(mat, "albedo_color:a", 0.0, time)
	t.tween_callback(line.queue_free)
