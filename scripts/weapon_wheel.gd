extends Node3D

# The Wheel (Martial warrior): glowing two-handers floating on a character. The
# held one hangs ready at the right hand; the rest ride in an arc behind the
# shoulders in the order they will come, the next one glowing brightest. Cracks
# show as glowing fissures on the held weapon; Break bursts it into shards.
# Only a picture: the rules are in scripts/player/martial_wheel.gd. One node per
# character (a child of the body named "WeaponWheel"), made by show_on(). A party
# member's Wheel is shown on that player's puppet (Net "wheel" fx).
# Swap-ready: each weapon is built by its own function (_build_axe, ...) from
# simple meshes; a real model can replace one without touching the gameplay code.
# Usage: const WeaponWheel = preload("res://scripts/weapon_wheel.gd")

const WheelIcons = preload("res://scripts/ui/wheel_icons.gd")
const NODE_NAME := "WeaponWheel"
## Where the held weapon floats (characters face -Z; right hand side is +X).
const HELD_AT := Vector3(0.5, 1.05, -0.25)
## The arc on the back: its centre, radius and spread.
const BACK_CENTRE := Vector3(0, 1.45, 0.42)
const BACK_RADIUS := 0.55
const BACK_SPREAD := 1.3        # radians from the first to the last weapon on the back
const BOB := 0.04               # metres the weapons drift up and down
const MOVE_SPEED := 8.0         # how fast a weapon flies to its new place
const MAX_CRACKS_SHOWN := 8

var _weapons: Array[String] = []
var _held := 0
var _cracks := 0
var _models := {}               # weapon id -> Node3D
var _crack_root: Node3D = null  # the fissures on the held weapon
var _t := 0.0

## Show the Wheel on `body`: `weapons` in order (empty: it goes), `held` = index in hand, `cracks`.
static func show_on(body: Node3D, weapons: Array, held: int, cracks: int) -> void:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return
	var node := body.get_node_or_null(NODE_NAME)
	if weapons.is_empty():
		if node:
			node.queue_free()
		return
	if node == null:
		node = Node3D.new()
		node.name = NODE_NAME
		node.set_script(load("res://scripts/weapon_wheel.gd"))
		body.add_child(node)
	node.set_state(weapons, held, cracks)

## Break / a weapon's last use: the held weapon bursts into shards.
static func burst(body: Node3D, weapon: String) -> void:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return
	var col := color_of(weapon)
	var at := body.global_position + body.global_basis * HELD_AT
	for i in 10:
		var shard := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.12, 0.02)
		shard.mesh = bm
		shard.material_override = _glow_mat(col, 2.5)
		shard.top_level = true
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.get_tree().current_scene.add_child(shard)
		shard.global_position = at
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.2, 1), randf_range(-1, 1)).normalized()
		var t := shard.create_tween()
		t.set_parallel(true)
		t.tween_property(shard, "global_position", at + dir * randf_range(0.8, 1.6), 0.45).set_ease(Tween.EASE_OUT)
		t.tween_property(shard, "rotation", Vector3(randf() * TAU, randf() * TAU, 0), 0.45)
		t.tween_property(shard, "scale", Vector3.ONE * 0.05, 0.45)
		t.chain().tween_callback(shard.queue_free)

## A weapon's colour (the same as its icons).
static func color_of(weapon: String) -> Color:
	return WheelIcons.COLORS.get(weapon, Color(0.85, 0.85, 0.9))

func set_state(weapons: Array, held: int, cracks: int) -> void:
	var ids: Array[String] = []
	for w in weapons:
		ids.append(str(w))
	_weapons = ids
	_held = clampi(held, 0, maxi(ids.size() - 1, 0))
	_cracks = maxi(cracks, 0)
	for w in _models.keys():
		if not _weapons.has(w):
			(_models[w] as Node3D).queue_free()
			_models.erase(w)
	for w in _weapons:
		if not _models.has(w):
			var m := _build(w)
			m.position = BACK_CENTRE
			add_child(m)
			_models[w] = m
	_show_cracks()

func _process(delta: float) -> void:
	_t += delta
	var n := _weapons.size()
	for i in n:
		var w := _weapons[i]
		var m: Node3D = _models.get(w)
		if m == null:
			continue
		var place := (i - _held + n) % n   # 0 = held, 1 = next, ...
		var want_pos: Vector3
		var want_rot: Vector3
		var glow := 1.0
		if place == 0:
			want_pos = HELD_AT
			want_rot = Vector3(-0.35, 0.0, -0.2)
			glow = 2.2
		else:
			var back := n - 1
			var a := 0.0 if back <= 1 else (float(place - 1) / float(back - 1) - 0.5) * BACK_SPREAD
			want_pos = BACK_CENTRE + Vector3(sin(a) * BACK_RADIUS, cos(a) * BACK_RADIUS * 0.4, 0)
			want_rot = Vector3(0, 0, -a * 0.9)
			glow = 1.8 if place == 1 else 0.7
		want_pos.y += sin(_t * 2.0 + i) * BOB
		m.position = m.position.lerp(want_pos, clampf(delta * MOVE_SPEED, 0.0, 1.0))
		m.rotation = m.rotation.lerp(want_rot, clampf(delta * MOVE_SPEED, 0.0, 1.0))
		var mat: StandardMaterial3D = m.get_meta("glow_mat")
		if mat:
			mat.emission_energy_multiplier = lerpf(mat.emission_energy_multiplier, glow, clampf(delta * 6.0, 0.0, 1.0))

## The held weapon's fissures: one glowing line per Crack (up to MAX_CRACKS_SHOWN).
func _show_cracks() -> void:
	if _crack_root != null:
		_crack_root.queue_free()
		_crack_root = null
	if _weapons.is_empty() or _cracks <= 0:
		return
	var held: Node3D = _models.get(_weapons[_held])
	if held == null:
		return
	_crack_root = Node3D.new()
	held.add_child(_crack_root)
	var mat := _glow_mat(Color(1.0, 0.95, 0.75), 4.0)
	for i in mini(_cracks, MAX_CRACKS_SHOWN):
		var line := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.012, 0.16, 0.05)
		line.mesh = bm
		line.material_override = mat
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		line.position = Vector3(0.0, 0.55 + i * 0.06, 0.0)
		line.rotation = Vector3(0, 0, (0.6 if i % 2 == 0 else -0.6))
		_crack_root.add_child(line)

# --- The weapons (each about 1.4 m: real two-handers; heads up, along +Y) -----------------

func _build(weapon: String) -> Node3D:
	var col := color_of(weapon)
	match weapon:
		"wheelgreataxe":
			return _build_axe(col)
		"wheelgreatsword":
			return _build_sword(col)
		"wheelhalberd":
			return _build_halberd(col)
		_:
			return _build_maul(col)

func _build_axe(col: Color) -> Node3D:
	var root := _root(col)
	_part(root, _haft_mesh(1.2), Vector3(0, 0, 0), _wood())
	_part(root, _box(Vector3(0.36, 0.3, 0.04)), Vector3(0.16, 0.5, 0), root.get_meta("glow_mat"))
	return root

func _build_sword(col: Color) -> Node3D:
	var root := _root(col)
	_part(root, _box(Vector3(0.09, 1.0, 0.025)), Vector3(0, 0.3, 0), root.get_meta("glow_mat"))   # blade
	_part(root, _box(Vector3(0.3, 0.05, 0.06)), Vector3(0, -0.22, 0), _wood())                    # guard
	_part(root, _haft_mesh(0.32), Vector3(0, -0.4, 0), _wood())                                   # grip
	return root

func _build_halberd(col: Color) -> Node3D:
	var root := _root(col)
	_part(root, _haft_mesh(1.5), Vector3(0, -0.05, 0), _wood())
	_part(root, _box(Vector3(0.26, 0.22, 0.03)), Vector3(0.13, 0.55, 0), root.get_meta("glow_mat"))   # blade
	_part(root, _box(Vector3(0.12, 0.06, 0.03)), Vector3(-0.08, 0.6, 0), root.get_meta("glow_mat"))   # hook
	_part(root, _box(Vector3(0.04, 0.24, 0.04)), Vector3(0, 0.8, 0), root.get_meta("glow_mat"))       # spike
	return root

func _build_maul(col: Color) -> Node3D:
	var root := _root(col)
	_part(root, _haft_mesh(1.15), Vector3(0, -0.05, 0), _wood())
	_part(root, _box(Vector3(0.42, 0.24, 0.24)), Vector3(0, 0.55, 0), root.get_meta("glow_mat"))
	return root

func _root(col: Color) -> Node3D:
	var root := Node3D.new()
	root.set_meta("glow_mat", _glow_mat(col, 1.0))
	return root

func _part(root: Node3D, mesh: Mesh, at: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

func _haft_mesh(length: float) -> Mesh:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.022
	cm.bottom_radius = 0.022
	cm.height = length
	cm.radial_segments = 6
	return cm

func _box(size: Vector3) -> Mesh:
	var bm := BoxMesh.new()
	bm.size = size
	return bm

func _wood() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.32, 0.22)
	m.roughness = 0.8
	return m

static func _glow_mat(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = 0.6
	m.roughness = 0.35
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m
