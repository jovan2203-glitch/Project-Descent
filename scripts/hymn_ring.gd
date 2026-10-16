extends Node3D

# The Holy healer's Hymn, as a picture only (no gameplay here: player.gd, "Holy
# healer: the Hymns"). A ring of glowing glyphs turns slowly around the healer's
# waist, in the colour of the Hymn they sing; a boom is a column of light with a
# ring of light spreading on the ground. Party members see it through the "hymn"
# and "hymn_boom" fx (net.gd). Swap-ready: replace this script's meshes freely.
#
# Usage: HYMN_RING.show_on(player, "vigil")   ("" takes the ring away)
#        HYMN_RING.boom(scene, position, colour)

const NAME := "HymnRing"
const GLYPHS := 10           # glyphs around the ring
const RADIUS := 0.85         # metres from the healer's centre
const HEIGHT := 1.0          # metres above their feet
const SPIN := 0.6            # radians per second
const GLYPH_SIZE := 0.16
const BOOM_TIME := 0.9       # seconds a boom's light takes to fade
const BOOM_HEIGHT := 7.0
const COLORS := {"mercy": Color(1.0, 0.8, 0.3), "chorus": Color(0.95, 0.95, 1.0), "vigil": Color(0.45, 0.7, 1.0)}

var _mat: StandardMaterial3D
var _bob := 0.0

## Show `hymn`'s ring around `whose` ("" or an unknown Hymn: none).
static func show_on(whose: Node3D, hymn: String) -> void:
	if whose == null or not is_instance_valid(whose):
		return
	var ring: Node = whose.get_node_or_null(NAME)
	if not COLORS.has(hymn):
		if ring:
			ring.queue_free()
		return
	if ring == null:
		ring = load("res://scripts/hymn_ring.gd").new()
		ring.name = NAME
		whose.add_child(ring)
	ring.set_color(COLORS[hymn])

## A boom of light at `at` (ground level) in `color`.
static func boom(scene: Node, at: Vector3, color: Color) -> void:
	if scene == null:
		return
	var root := Node3D.new()
	scene.add_child(root)
	root.global_position = at
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(color, 0.55)
	var pillar := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.7
	cyl.height = BOOM_HEIGHT
	pillar.mesh = cyl
	pillar.material_override = mat
	pillar.position = Vector3(0, BOOM_HEIGHT / 2.0, 0)
	root.add_child(pillar)
	var disc := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	disc.mesh = torus
	disc.material_override = mat
	disc.position = Vector3(0, 0.1, 0)
	root.add_child(disc)
	var tw := root.create_tween().set_parallel(true)
	tw.tween_property(mat, "albedo_color:a", 0.0, BOOM_TIME)
	tw.tween_property(disc, "scale", Vector3(5, 1, 5), BOOM_TIME)
	tw.tween_property(pillar, "scale", Vector3(0.3, 1.2, 0.3), BOOM_TIME)
	tw.chain().tween_callback(root.queue_free)

func _init() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

func _ready() -> void:
	position = Vector3(0, HEIGHT, 0)
	for i in GLYPHS:
		var g := MeshInstance3D.new()
		var q := QuadMesh.new()
		# Alternate tall and wide glyphs so the ring reads as script, not dots.
		q.size = Vector2(GLYPH_SIZE * 0.55, GLYPH_SIZE) if i % 2 == 0 else Vector2(GLYPH_SIZE, GLYPH_SIZE * 0.45)
		g.mesh = q
		g.material_override = _mat
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * i / GLYPHS
		g.position = Vector3(cos(a) * RADIUS, 0.0, sin(a) * RADIUS)
		add_child(g)

func set_color(c: Color) -> void:
	_mat.albedo_color = Color(c, 0.85)

func _process(delta: float) -> void:
	rotation.y += SPIN * delta
	_bob += delta
	position.y = HEIGHT + sin(_bob * 1.6) * 0.05
