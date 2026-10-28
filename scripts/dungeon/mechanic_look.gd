extends RefCounted

# The ONE visual language of boss mechanics. Every boss ability belongs to a
# family; a family's SHAPE (and its rim color family) means the same thing in
# every dungeon, so players learn it once. A dungeon's MechanicTheme (on its biome
# kit) only restyles the markers. Nothing else draws mechanic shapes.
#
#   avoid      filling red-orange area (circle / cone / line)    get out
#   safe       green circle                                      go here
#   stack      circle + a big arrow pointing DOWN into it       stand in it together
#   spread     circle following a player + arrows pointing OUT  get away from others
#   stay_out   lasting pool with a striped rim                   don't stand in it
#   interrupt  cast bar (enemy.gd)                               interrupt it
#   guards     bubble on the boss + a line to each guard        kill the guards
#
# Every draw call here is local; boss_kit.gd sends the same call to party members
# through Net.enemy_fx and enemy.gd net_fx() replays it.

const FX = preload("res://scripts/dungeon/boss_abilities.gd")
const GUARD_LINKS = preload("res://scripts/dungeon/guard_links.gd")

## Boss ability type -> family.
const FAMILY := {
	"slam": "avoid", "nova": "avoid", "eruption": "avoid", "barrage": "avoid",
	"cone": "avoid", "charge": "avoid", "donut": "avoid",
	"soak": "stack", "spread": "spread", "hazard": "stay_out",
	"big_cast": "interrupt", "heal": "interrupt", "summon": "interrupt",
	"phase": "guards", "enrage": "none",
}

## Default rim color per family.
const COLORS := {
	"avoid": Color(1.0, 0.28, 0.12),
	"safe": Color(0.35, 1.0, 0.45),
	"stack": Color(1.0, 0.82, 0.2),
	"spread": Color(0.35, 0.75, 1.0),
	"stay_out": Color(1.0, 0.5, 0.1),
	"interrupt": Color(0.85, 0.45, 1.0),
	"guards": Color(0.95, 0.95, 1.0),
}

const ARROW_HEIGHT := 2.6   # m above the floor (stack arrow tip)
const POOL_FADE := 0.4

## The theme of the dungeon being played (set by dungeon_run on every machine).
static var theme: Resource = null

static func family(type: String) -> String:
	return str(FAMILY.get(type, "avoid"))

static func color(fam: String) -> Color:
	if theme and theme.colors.has(fam):
		return theme.colors[fam]
	return COLORS.get(fam, COLORS["avoid"])

## A themed replacement for a default marker mesh, or null.
static func _themed(marker: String) -> Node3D:
	if theme and theme.scenes.has(marker) and theme.scenes[marker] is PackedScene:
		return (theme.scenes[marker] as PackedScene).instantiate() as Node3D
	return null

static func _mat(col: Color, alpha := 1.0, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(col, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	return m

static func _no_shadow(mi: GeometryInstance3D) -> void:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# --- Families ---------------------------------------------------------------------------------

## Avoid / safe: the filling circle (`tint` = the ability's own color for the fill).
static func area(scene: Node, at: Vector3, r: float, time: float, fam := "avoid", tint: Variant = null) -> void:
	var rim := color(fam)
	FX.telegraph(scene, at, r, time, rim if tint == null else (tint as Color).lerp(rim, 0.5))

## Stack: a circle + a big arrow pointing down into it. Follows `who` if given.
static func stack(scene: Node, at: Vector3, r: float, time: float, who: Node3D = null) -> void:
	if scene == null:
		return
	var col := color("stack")
	FX.telegraph(scene, at, r, time, col)
	var root := Node3D.new()
	scene.add_child(root)
	root.global_position = at
	var arrow := _themed("stack_arrow")
	if arrow == null:
		arrow = _arrow(col, 1.2)
		arrow.rotation.x = PI   # tip down
	root.add_child(arrow)
	arrow.position.y = ARROW_HEIGHT
	var bob := arrow.create_tween().set_loops()
	bob.tween_property(arrow, "position:y", ARROW_HEIGHT - 0.5, 0.35).set_trans(Tween.TRANS_SINE)
	bob.tween_property(arrow, "position:y", ARROW_HEIGHT, 0.35).set_trans(Tween.TRANS_SINE)
	_follow_then_free(root, who, time, at.y)

## Spread: a circle on a player that moves with them + arrows pointing outward.
static func spread(scene: Node, who: Node3D, r: float, time: float) -> void:
	if scene == null or who == null or not is_instance_valid(who):
		return
	var col := color("spread")
	var floor_y := who.global_position.y
	var root := Node3D.new()
	scene.add_child(root)
	root.global_position = who.global_position
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - 0.14
	tm.outer_radius = r
	tm.rings = 48
	tm.ring_segments = 4
	ring.mesh = tm
	ring.material_override = _mat(col, 1.0, 1.5)
	ring.scale = Vector3(1, 0.15, 1)
	ring.position.y = 0.06
	_no_shadow(ring)
	root.add_child(ring)
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = r
	dm.bottom_radius = r
	dm.height = 0.02
	dm.radial_segments = 40
	disc.mesh = dm
	disc.material_override = _mat(col, 0.18)
	disc.position.y = 0.05
	_no_shadow(disc)
	root.add_child(disc)
	var spin := Node3D.new()
	root.add_child(spin)
	for k in 4:
		var a := TAU * float(k) / 4.0
		var arrow := _themed("spread_arrow")
		if arrow == null:
			arrow = _arrow(col, 0.9)
			arrow.rotation.z = -PI / 2.0   # lying flat, tip outward along +X
		var holder := Node3D.new()
		holder.rotation.y = a
		spin.add_child(holder)
		holder.add_child(arrow)
		arrow.position = Vector3(r + 0.55, 0.25, 0)
	var t := spin.create_tween().set_loops()
	t.tween_property(spin, "rotation:y", TAU, 3.0).from(0.0)
	# The bright fill grows like every other telegraph: full = it bursts.
	var fill := MeshInstance3D.new()
	fill.mesh = dm
	fill.material_override = _mat(col, 0.38)
	fill.position.y = 0.07
	fill.scale = Vector3(0.01, 1, 0.01)
	_no_shadow(fill)
	root.add_child(fill)
	fill.create_tween().tween_property(fill, "scale", Vector3.ONE, time)
	_follow_then_free(root, who, time, floor_y)

## Stay out: a pool that lasts `duration`, with a striped rim.
static func pool(scene: Node, at: Vector3, r: float, duration: float, tint: Variant = null) -> void:
	if scene == null:
		return
	var col := color("stay_out")
	var fill_col: Color = col if tint == null else (tint as Color)
	var root := Node3D.new()
	scene.add_child(root)
	root.global_position = at + Vector3(0, 0.04, 0)
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = r
	dm.bottom_radius = r
	dm.height = 0.02
	dm.radial_segments = 40
	disc.mesh = dm
	var disc_mat := _mat(fill_col, 0.45, 1.2)
	disc.material_override = disc_mat
	_no_shadow(disc)
	root.add_child(disc)
	var rim := _themed("pool_rim")
	if rim == null:
		rim = _stripes(col, r)
	root.add_child(rim)
	var l := OmniLight3D.new()
	l.light_color = fill_col
	l.light_energy = 1.2
	l.omni_range = r * 1.8
	l.position.y = 0.6
	root.add_child(l)
	# Grows in, stays, fades.
	root.scale = Vector3(0.2, 1, 0.2)
	var t := root.create_tween()
	t.tween_property(root, "scale", Vector3.ONE, 0.25).set_ease(Tween.EASE_OUT)
	t.tween_interval(maxf(duration - 0.25 - POOL_FADE, 0.0))
	t.tween_property(root, "scale", Vector3(0.05, 1, 0.05), POOL_FADE)
	t.tween_callback(root.queue_free)

## Guards: a bubble on the boss and a line to each guard; ends when the boss
## stops being immune (call guards_end) or every guard is gone.
static func guards(boss: Node3D, guard_nodes: Array) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	guards_end(boss)
	var col := color("guards")
	var bubble := _themed("guard_bubble")
	if bubble == null:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var rad := 1.3 * maxf(float(boss.get("boss_scale") if boss.get("boss_scale") != null else 1.0), 1.0)
		sm.radius = rad
		sm.height = rad * 2.0
		mi.mesh = sm
		mi.material_override = _mat(col, 0.22, 1.0)
		_no_shadow(mi)
		bubble = mi
	var links := Node3D.new()
	links.set_script(GUARD_LINKS)
	links.name = "GuardLinks"
	boss.add_child(links)
	links.setup(guard_nodes, col, bubble)

static func guards_end(boss: Node3D) -> void:
	if boss and is_instance_valid(boss):
		var old := boss.get_node_or_null("GuardLinks")
		if old:
			old.name = "GuardLinksOld"
			old.queue_free()

# --- Default meshes -----------------------------------------------------------------------------

## An arrow pointing up (+Y), `length` long, glowing.
static func _arrow(col: Color, length: float) -> Node3D:
	var root := Node3D.new()
	var mat := _mat(col, 1.0, 2.5)
	var shaft := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = length * 0.09
	sm.bottom_radius = length * 0.09
	sm.height = length * 0.55
	shaft.mesh = sm
	shaft.material_override = mat
	shaft.position.y = -length * 0.5 + sm.height * 0.5
	_no_shadow(shaft)
	root.add_child(shaft)
	var head := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.0
	hm.bottom_radius = length * 0.26
	hm.height = length * 0.45
	head.mesh = hm
	head.material_override = mat
	head.position.y = length * 0.5 - hm.height * 0.5
	_no_shadow(head)
	root.add_child(head)
	return root

## A striped (hazard-tape) rim around a pool.
static func _stripes(col: Color, r: float) -> Node3D:
	var root := Node3D.new()
	var bright := _mat(col, 1.0, 1.5)
	var dark := _mat(col.darkened(0.7), 1.0)
	var n := maxi(int(TAU * r / 0.45), 12)
	for k in n:
		var a := TAU * float(k) / float(n)
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(TAU * r / float(n) + 0.02, 0.05, 0.22)
		seg.mesh = bm
		seg.material_override = bright if k % 2 == 0 else dark
		seg.position = Vector3(sin(a), 0, cos(a)) * r + Vector3(0, 0.03, 0)
		seg.rotation.y = a + PI / 2.0
		_no_shadow(seg)
		root.add_child(seg)
	return root

## Keep `root` on `who`'s feet for `time` (if given), then free it.
static func _follow_then_free(root: Node3D, who: Node3D, time: float, floor_y: float) -> void:
	var t := root.create_tween()
	if who != null:
		t.tween_method(func(_v: float) -> void:
			if is_instance_valid(who) and is_instance_valid(root):
				root.global_position = Vector3(who.global_position.x, floor_y, who.global_position.z), 0.0, 1.0, time)
	else:
		t.tween_interval(time)
	t.tween_callback(root.queue_free)
