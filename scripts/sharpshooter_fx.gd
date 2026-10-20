extends RefCounted

# Pictures of the Martial archer, Sharpshooter (scripts/player/martial_sharpshooter.gd).
# Only pictures: the rules run on the archer's machine, and the party is shown the same
# through Net fx ("sharpshooter").
#   show_streak()  a quiver on the archer's back: one glowing fletching per Streak stack,
#                  all of them gold (and a gold glow) while a held shot has a lot of Overcut
# Swap-ready: the model is built in one function (_quiver).
# Usage: const SharpFx = preload("res://scripts/sharpshooter_fx.gd")

const QUIVER_NAME := "SharpQuiver"
const LIT := Color(0.55, 0.8, 1.0)
const GOLD := Color(1.0, 0.83, 0.3)
const OFF := Color(0.85, 0.85, 0.8)

## The quiver on `who` (`streak` of `max_streak` lit; `gold`: a charged shot is held).
static func show_streak(who: Node3D, streak: int, max_streak: int, gold: bool) -> void:
	if who == null or not is_instance_valid(who):
		return
	var q := who.get_node_or_null(QUIVER_NAME) as Node3D
	if streak <= 0 and not gold:
		if q:
			q.queue_free()
		return
	if q == null:
		q = _quiver(max_streak)
		q.name = QUIVER_NAME
		who.add_child(q)
	var tips: Node3D = q.get_node("Tips")
	for i in tips.get_child_count():
		var m := (tips.get_child(i) as MeshInstance3D).material_override as StandardMaterial3D
		var on := i < streak
		var col := GOLD if gold else (LIT if on else OFF)
		m.albedo_color = col
		m.emission_enabled = on or gold
		m.emission = col
		m.emission_energy_multiplier = 2.5 if gold else 1.6
	var light := q.get_node("Glow") as OmniLight3D
	light.visible = gold
	light.light_color = GOLD

## The quiver: a leather tube slung across the back, `n` fletchings sticking out of it.
static func _quiver(n: int) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(0.12, 1.25, 0.18)
	root.rotation = Vector3(0.0, 0.0, -0.35)
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.42, 0.27, 0.16)
	var tube := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.06
	cyl.height = 0.5
	cyl.material = leather
	tube.mesh = cyl
	root.add_child(tube)
	var tips := Node3D.new()
	tips.name = "Tips"
	root.add_child(tips)
	for i in n:
		var t := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.025, 0.08, 0.012)
		t.mesh = box
		var m := StandardMaterial3D.new()
		m.albedo_color = OFF
		t.material_override = m
		var a := TAU * float(i) / float(maxi(n, 1))
		t.position = Vector3(cos(a) * 0.04, 0.29 + 0.02 * float(i % 2), sin(a) * 0.04)
		tips.add_child(t)
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.omni_range = 1.6
	glow.light_energy = 1.2
	glow.position = Vector3(0, 0.3, 0)
	glow.visible = false
	root.add_child(glow)
	return root
