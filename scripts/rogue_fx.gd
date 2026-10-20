extends RefCounted

# Pictures of the Martial DPS, the Rogue (scripts/player/martial_rogue.gd). Only
# pictures: the rules run on the Rogue's machine, and the party is shown the same
# through Net fx ("rogue", "rogue_daggers", "rogue_throw").
#   show_flow()   a ring of light around the Rogue's waist: brighter with each Flow
#                 stack, red during a Kill window
#   throw()       a dagger flying from a hand to an enemy
#   set_daggers() the daggers stuck in an enemy (one set per Rogue)
#   play_dead()   the Rogue lies down (Play Dead, Martial Utility)
# Swap-ready: each model is built in one function (_ring_mesh, _dagger_mesh).
# Usage: const RogueFx = preload("res://scripts/rogue_fx.gd")

const FLOW_COL := Color(0.35, 0.95, 0.85)
const KILL_COL := Color(1.0, 0.26, 0.24)
const STEEL := Color(0.86, 0.9, 0.96)
const RING_NAME := "RogueFlow"
const DAGGERS_PREFIX := "RogueDaggers_"
const THROW_TIME := 0.14
const DEAD_META := "rogue_dead_tween"
## Where stuck daggers sit on an enemy (around its middle, then up and down).
const STUCK_SPOTS := [Vector3(0.0, 1.0, 0.32), Vector3(-0.22, 1.25, 0.25), Vector3(0.22, 0.8, 0.27),
	Vector3(0.0, 1.45, 0.2), Vector3(-0.25, 0.7, 0.2), Vector3(0.25, 1.15, 0.25)]

## The Flow ring on `who` (`flow` stacks of `max_flow`; `kill`: a Kill window is open).
static func show_flow(who: Node3D, flow: int, max_flow: int, kill: bool) -> void:
	if who == null or not is_instance_valid(who):
		return
	var ring := who.get_node_or_null(RING_NAME) as MeshInstance3D
	if flow <= 0 and not kill:
		if ring:
			ring.queue_free()
		return
	if ring == null:
		ring = MeshInstance3D.new()
		ring.name = RING_NAME
		ring.mesh = _ring_mesh()
		ring.position = Vector3(0, 0.95, 0)
		who.add_child(ring)
	var col := KILL_COL if kill else FLOW_COL
	var strength := 1.0 if kill else clampf(float(flow) / float(maxi(max_flow, 1)), 0.15, 1.0)
	var mat := ring.mesh.surface_get_material(0) as StandardMaterial3D
	mat.albedo_color = Color(col, 0.25 + 0.6 * strength)
	mat.emission = col
	mat.emission_energy_multiplier = 0.6 + 2.4 * strength
	ring.scale = Vector3.ONE * (0.9 + 0.25 * strength)

## A dagger flying from `from` to `to` (no damage: a picture).
static func throw(scene: Node, from: Vector3, to: Vector3) -> void:
	if scene == null or not scene.is_inside_tree():
		return
	var d := _dagger_mesh()
	scene.add_child(d)
	d.global_position = from
	if from.distance_to(to) > 0.01:
		d.look_at(to, Vector3.UP)
	var tw := d.create_tween()
	tw.tween_property(d, "global_position", to, THROW_TIME)
	tw.tween_callback(d.queue_free)

## Show `n` of `key`'s daggers stuck in `enemy` (0 takes them out).
static func set_daggers(enemy: Node3D, key: String, n: int) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var holder := enemy.get_node_or_null(DAGGERS_PREFIX + key) as Node3D
	if n <= 0:
		if holder:
			holder.queue_free()
		return
	if holder == null:
		holder = Node3D.new()
		holder.name = DAGGERS_PREFIX + key
		enemy.add_child(holder)
	while holder.get_child_count() > n:
		var last := holder.get_child(holder.get_child_count() - 1)
		holder.remove_child(last)
		last.queue_free()
	while holder.get_child_count() < n:
		var i := holder.get_child_count()
		var d := _dagger_mesh()
		holder.add_child(d)
		d.position = STUCK_SPOTS[i % STUCK_SPOTS.size()]
		d.rotation = Vector3(-0.5, 0.3 * float(i - 1), 0.0)   # handle out, blade in

## `who` lies down (on) or gets up (off).
static func play_dead(who: Node3D, on: bool) -> void:
	if who == null or not is_instance_valid(who):
		return
	var model := who.get("model") as Node3D
	if model == null:
		return
	var old: Variant = model.get_meta(DEAD_META, null)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw := model.create_tween()
	tw.tween_property(model, "rotation:x", -PI * 0.5 if on else 0.0, 0.2)
	model.set_meta(DEAD_META, tw)

static func _ring_mesh() -> Mesh:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	var torus := TorusMesh.new()
	torus.inner_radius = 0.48
	torus.outer_radius = 0.53
	torus.rings = 32
	torus.ring_segments = 4
	torus.material = mat
	return torus

static func _dagger_mesh() -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = STEEL
	mat.emission_enabled = true
	mat.emission = STEEL
	mat.emission_energy_multiplier = 0.8
	mat.metallic = 0.6
	var blade := PrismMesh.new()
	blade.size = Vector3(0.05, 0.28, 0.02)
	blade.material = mat
	var m := MeshInstance3D.new()
	m.mesh = blade
	m.rotation = Vector3(-PI * 0.5, 0.0, 0.0)   # point along -Z (look_at's forward)
	var holder := MeshInstance3D.new()
	holder.add_child(m)
	return holder
