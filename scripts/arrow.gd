extends Node3D

# Bow auto-attack projectile: flies at its target, deals damage on hit,
# breaks on walls.

const Combat = preload("res://scripts/combat_utils.gd")

var target: Node3D
var damage := 1
var source: Node = null      # the player; damage goes through source.deal_damage()
var ability_id := "auto_ranged"
var speed := 24.0
var _done := false

# Pooled (see Pool): visuals are built once in _ready; spawn() resets state.
static func spawn(scene: Node, at: Vector3, tgt: Node3D, src: Node, dmg: int, id: String) -> Node3D:
	var pool := scene.get_node_or_null("/root/Pool")
	var factory := func():
		var n := Node3D.new()
		n.set_script(load("res://scripts/arrow.gd"))
		return n
	var arrow: Node3D = pool.acquire("arrow", factory) if pool else factory.call()
	arrow.target = tgt
	arrow.source = src
	arrow.damage = dmg
	arrow.ability_id = id
	arrow._done = false
	scene.add_child(arrow)
	arrow.global_position = at
	arrow._tint(id)
	# Party members see my arrow too (as a harmless visual).
	if src and is_instance_valid(src) and src.is_in_group("player"):
		var net := scene.get_node_or_null("/root/Net")
		if net:
			net.send_fx("arrow", at, tgt, id)
	return arrow

func _finish() -> void:
	if _done:
		return
	_done = true
	var pool := get_node_or_null("/root/Pool")
	if pool and has_meta("pool_key"):
		pool.release(self)
	else:
		queue_free()

var _tip_mat: StandardMaterial3D
var _glow: OmniLight3D

## Elemental arrows (Flaming Arrow, Frost Arrow...) get a glowing tip in their
## book's color; plain arrows keep a steel tip. Re-applied on every spawn (pooled).
func _tint(id: String) -> void:
	if _tip_mat == null:
		return
	var cat: String = preload("res://scripts/abilities.gd").category_of(id)
	var magic := cat != "" and cat != "ranger" and cat != "warrior"
	if magic:
		var c: Color = preload("res://scripts/categories.gd").color(cat)
		_tip_mat.albedo_color = c.lightened(0.3)
		_tip_mat.emission_enabled = true
		_tip_mat.emission = c
		_tip_mat.emission_energy_multiplier = 3.0
		_glow.light_color = c
	else:
		_tip_mat.albedo_color = Color(0.85, 0.87, 0.9)
		_tip_mat.emission_enabled = false
	_glow.visible = magic

func _ready() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.38, 0.22)
	var steel := StandardMaterial3D.new()
	_tip_mat = steel
	_glow = OmniLight3D.new()
	_glow.light_energy = 1.5
	_glow.omni_range = 2.5
	_glow.position.z = -0.38
	_glow.visible = false
	add_child(_glow)
	steel.albedo_color = Color(0.85, 0.87, 0.9)
	steel.metallic = 0.8
	steel.roughness = 0.3
	var fletch := StandardMaterial3D.new()
	fletch.albedo_color = Color(0.95, 0.95, 0.9)

	# Built along -Z (the direction look_at points).
	var shaft := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.018
	cyl.bottom_radius = 0.018
	cyl.height = 0.65
	cyl.material = wood
	shaft.mesh = cyl
	shaft.rotation.x = PI / 2.0
	add_child(shaft)

	var tip := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.045
	cone.height = 0.12
	cone.material = steel
	tip.mesh = cone
	tip.rotation.x = -PI / 2.0
	tip.position.z = -0.38
	add_child(tip)

	var tail := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.09, 0.09, 0.12)
	box.material = fletch
	tail.mesh = box
	tail.position.z = 0.3
	tail.rotation.z = PI / 4.0
	add_child(tail)

func _physics_process(delta: float) -> void:
	if _done:
		return
	if not is_instance_valid(target) or not target.is_alive():
		_finish()
		return
	var aim := target.global_position + Vector3(0, 0.3, 0)
	var to_target := aim - global_position
	var step := speed * delta
	if to_target.length() <= step + 0.2:
		if is_instance_valid(source) and source.has_method("deal_damage"):
			source.deal_damage(target, damage, ability_id)
		else:
			target.take_damage(damage)
		_finish()
		return
	var next := global_position + to_target.normalized() * step
	if not Combat.line_of_sight(get_world_3d(), global_position, next):
		_finish()
		return
	look_at(aim, Vector3.UP)
	global_position = next
