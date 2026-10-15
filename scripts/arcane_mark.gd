extends Node3D

# The pictures of the Arcane kit, placed on the ground at the caster's feet level.
# They are only pictures: the caster's own machine deals every hit. Each one is
# shown on every machine (Net "arcanemark" fx) so the party can see it.
#   "sigil"    Mirror Sigil: a circle with a floating shard, for `duration` seconds.
#   "collapse" Collapse: a ring that closes in on its centre over `duration`
#              seconds, then flashes.
#   "image"    Rune of the Afterimage: a see-through figure, for `duration` seconds.
# One sigil and one image per owner: a new one replaces the old.

const Combat = preload("res://scripts/combat_utils.gd")

const GROUP := "arcane_marks"
const GLOW := Color(0.75, 0.5, 1.0)
const FADE_TIME := 0.3
## Height of a Mirror Sigil's floating shard over the ground: over a sigil that
## stands, and over the head of whoever carries one (its echoes fly from there).
const SHARD_HEIGHT := 1.1
const CARRIED_HEIGHT := 2.3

var kind := "sigil"
var radius := 1.5
var duration := 4.0
## "me" for my own, a party member's id for theirs.
var owner_key := ""
## Rune of the Carried Sigil: the character this mark moves with (null = it
## stays where it was put). It goes when they do.
var follow: Node3D = null

var _age := 0.0
var _ending := false
var _mats: Array[StandardMaterial3D] = []
var _rim: MeshInstance3D
var _shard: MeshInstance3D

static func spawn(scene: Node, at: Vector3, r: float, time: float, what: String, key: String = "") -> Node3D:
	if what != "collapse" and scene.is_inside_tree():
		clear(scene.get_tree(), what, key)
	var n := Node3D.new()
	n.set_script(load("res://scripts/arcane_mark.gd"))
	n.kind = what
	n.radius = r
	n.duration = time
	n.owner_key = key
	scene.add_child(n)
	n.global_position = at
	return n

## Take away `key`'s mark of this kind (the sigil ran out, the image was used).
static func clear(tree: SceneTree, what: String, key: String) -> void:
	for m in tree.get_nodes_in_group(GROUP):
		if str(m.kind) == what and str(m.owner_key) == key:
			m.vanish()

func _ready() -> void:
	add_to_group(GROUP)
	match kind:
		"image":
			_build_image()
		"collapse":
			_build_circle(0.1, 0.16)
		_:
			_build_circle(0.18, 0.12)
			_build_shard()

func _build_circle(fill: float, rim_width: float) -> void:
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.02
	cyl.radial_segments = 40
	cyl.rings = 1
	disc.mesh = cyl
	disc.position.y = 0.03
	disc.material_override = _flat(Color(GLOW, fill))
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	_rim = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(radius - rim_width, 0.05)
	torus.outer_radius = radius
	torus.rings = 48
	torus.ring_segments = 4
	_rim.mesh = torus
	_rim.position.y = 0.06
	_rim.scale.y = 0.35
	_rim.material_override = _flat(Color(GLOW.lightened(0.3), 0.9))
	_rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rim)

## The shard that floats over a Mirror Sigil (its echoes fly from here).
func _build_shard() -> void:
	_shard = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.35, 0.7, 0.12)
	_shard.mesh = prism
	_shard.position.y = SHARD_HEIGHT
	_shard.material_override = _flat(Color(GLOW.lightened(0.45), 0.85))
	_shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shard)

func _build_image() -> void:
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.7
	body.mesh = cap
	body.position.y = 0.85
	body.material_override = _flat(Color(GLOW.lightened(0.2), 0.35))
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.6
	torus.rings = 24
	torus.ring_segments = 4
	ring.mesh = torus
	ring.position.y = 0.05
	ring.scale.y = 0.35
	ring.material_override = _flat(Color(GLOW.lightened(0.3), 0.8))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats.append(m)
	return m

## How far the closing ring of a Collapse has come in (1 = full size, 0 = shut)
## after `age` of its `time` seconds.
static func closing(age: float, time: float) -> float:
	return clampf(1.0 - age / maxf(time, 0.01), 0.0, 1.0)

func _process(delta: float) -> void:
	if _ending:
		return
	_age += delta
	if follow != null:
		if not is_instance_valid(follow) or not follow.is_inside_tree():
			follow = null
			vanish()
			return
		global_position = Vector3(follow.global_position.x, Combat.feet_y(follow), follow.global_position.z)
		if _shard:
			_shard.position.y = CARRIED_HEIGHT
	if _shard:
		_shard.rotation.y += delta * 1.8
	if kind == "collapse" and _rim:
		var s := maxf(closing(_age, duration), 0.04)
		_rim.scale = Vector3(s, 0.35, s)
	if _age >= duration:
		vanish()

## Fade out and go.
func vanish() -> void:
	if _ending:
		return
	_ending = true
	remove_from_group(GROUP)
	if not is_inside_tree() or _mats.is_empty():
		queue_free()
		return
	var t := create_tween()
	t.set_parallel(true)
	for m in _mats:
		t.tween_property(m, "albedo_color:a", 0.0, FADE_TIME)
	t.chain().tween_callback(queue_free)
