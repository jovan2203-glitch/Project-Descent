extends RefCounted

# Shared helpers for any enemy/character, based on its CollisionShape3D.
# Usage: const Combat = preload("res://scripts/combat_utils.gd")

static func _shape_node(body: Node) -> CollisionShape3D:
	if body == null:
		return null
	for c in body.get_children():
		if c is CollisionShape3D and c.shape:
			return c
	return null

# Horizontal hitbox radius (how "wide" the body is on the ground).
static func hitbox_radius(body: Node, fallback: float = 0.4) -> float:
	var cs := _shape_node(body)
	if cs == null:
		return fallback
	var s := cs.shape
	var scale_xz: float = max(cs.global_basis.get_scale().x, cs.global_basis.get_scale().z)
	if s is CapsuleShape3D or s is CylinderShape3D or s is SphereShape3D:
		return s.radius * scale_xz
	if s is BoxShape3D:
		return max(s.size.x, s.size.z) * 0.5 * scale_xz
	return fallback

# True if nothing solid (walls, rock, static geometry) is between `from` and
# `to`. Characters (player, enemies) never block sight.
static func line_of_sight(world: World3D, from: Vector3, to: Vector3) -> bool:
	var exclude: Array[RID] = []
	for i in 8:
		var q := PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
		var hit := world.direct_space_state.intersect_ray(q)
		if hit.is_empty():
			return true
		if hit.collider is CharacterBody3D:
			exclude.append(hit.rid)
			continue
		return false
	return true

# Eye / chest point used for sight checks on a character.
static func sight_point(body: Node3D) -> Vector3:
	return body.global_position + Vector3(0, 0.6, 0)

## Height of a body's hitbox (world units), 1.8 if it has none.
static func body_height(body: Node3D) -> float:
	var cs := _shape_node(body)
	if cs == null:
		return 1.8
	var s := cs.shape
	var h := 1.8
	if s is CapsuleShape3D or s is CylinderShape3D:
		h = s.height
	elif s is SphereShape3D:
		h = s.radius * 2.0
	elif s is BoxShape3D:
		h = s.size.y
	return h * cs.global_basis.get_scale().y

## Eye point: near the top of the hitbox (so low walls / pillars you can see
## over don't block, like in WoW).
static func eye_point(body: Node3D) -> Vector3:
	var feet := feet_y(body)
	return Vector3(body.global_position.x, feet + body_height(body) * 0.9, body.global_position.z)

## WoW-style line of sight between two characters: from the viewer's eyes to
## the target's head OR chest. Walls, rock and closed gates block it;
## characters never do.
static func can_see(world: World3D, viewer: Node3D, target: Node3D) -> bool:
	var eye := eye_point(viewer)
	var feet := feet_y(target)
	var h := body_height(target)
	var p := target.global_position
	for frac in [0.9, 0.55]:
		if line_of_sight(world, eye, Vector3(p.x, feet + h * frac, p.z)):
			return true
	return false

## Is `target` inside the frontal arc of `viewer` (degrees, total width)?
## Characters face -Z. Targets overlapping the viewer always count as in front.
static func is_in_front(viewer: Node3D, target: Node3D, arc_deg: float = 180.0) -> bool:
	var to := target.global_position - viewer.global_position
	to.y = 0.0
	if to.length() <= hitbox_radius(viewer) + hitbox_radius(target) * 0.5:
		return true
	var fwd := -viewer.global_basis.z
	fwd.y = 0.0
	if fwd.length() < 0.001:
		return true
	return fwd.normalized().dot(to.normalized()) >= cos(deg_to_rad(arc_deg * 0.5)) - 0.001

# World-space Y of the bottom of the body's hitbox (its feet).
static func feet_y(body: Node3D) -> float:
	var cs := _shape_node(body)
	if cs == null:
		return body.global_position.y
	var s := cs.shape
	var half := 0.0
	if s is CapsuleShape3D or s is CylinderShape3D:
		half = s.height * 0.5
	elif s is SphereShape3D:
		half = s.radius
	elif s is BoxShape3D:
		half = s.size.y * 0.5
	return cs.global_position.y - half * cs.global_basis.get_scale().y
