extends Node3D

# The "guards" mechanic look (mechanic_look.gd): a bubble on an immune boss and a
# glowing line to each guard keeping it immune. Child of the boss; frees itself
# once every guard is gone.

var guards: Array = []      # guard nodes
var _lines: Array = []      # MeshInstance3D per guard

func setup(guard_nodes: Array, col: Color, bubble: Node3D) -> void:
	guards = guard_nodes
	add_child(bubble)
	bubble.position.y = 1.1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.0
	for g in guards:
		var line := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.08, 0.08, 1.0)
		line.mesh = bm
		line.material_override = mat
		line.top_level = true
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(line)
		_lines.append(line)

func _process(_delta: float) -> void:
	var boss := get_parent() as Node3D
	if boss == null:
		return
	var any := false
	for i in guards.size():
		var g: Variant = guards[i]
		var line: MeshInstance3D = _lines[i]
		var alive: bool = g != null and is_instance_valid(g) and (g as Node).is_inside_tree() \
			and (not g.has_method("is_alive") or g.is_alive())
		line.visible = alive
		if not alive:
			continue
		any = true
		var a := boss.global_position + Vector3(0, 1.1, 0)
		var b: Vector3 = (g as Node3D).global_position + Vector3(0, 1.0, 0)
		var d := b - a
		if d.length() < 0.05:
			continue
		line.global_transform = Transform3D(Basis.looking_at(d, Vector3.UP) * Basis.from_scale(Vector3(1, 1, d.length())), (a + b) * 0.5)
	if not any:
		queue_free()
