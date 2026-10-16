extends MeshInstance3D

# A beam of light from one point to another (Holy healer #2: a heal's beam). A
# thin glowing line that fades out. Only a picture.
# Usage: const LightBeam = preload("res://scripts/light_beam.gd")

const TIME := 0.3
const WIDTH := 0.05

## A beam from `from` to `to` that fades.
static func flash(parent: Node, from: Vector3, to: Vector3, color: Color) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var b := MeshInstance3D.new()
	b.set_script(load("res://scripts/light_beam.gd"))
	var cm := CylinderMesh.new()
	cm.top_radius = WIDTH
	cm.bottom_radius = WIDTH
	cm.height = length
	cm.radial_segments = 6
	cm.rings = 1
	b.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b.material_override = m
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(b)
	# A cylinder stands along Y: point it from `from` to `to`.
	var mid := (from + to) * 0.5
	var dir := (to - from).normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var x := up.cross(dir).normalized()
	var z := x.cross(dir).normalized()
	b.global_transform = Transform3D(Basis(x, dir, z), mid)
	var tw := b.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, TIME)
	tw.tween_callback(b.queue_free)
