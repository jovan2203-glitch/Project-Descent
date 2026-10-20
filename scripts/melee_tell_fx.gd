extends Node3D

# A melee tell: what an enemy's coming melee hit looks like. Only a picture - the
# rules are in enemy.gd ("Melee tells"). A bright spark that swells at the
# enemy's chest over the tell and pops when the hit lands, readable in dark
# dungeons. Swap-ready: replace this node to change the look.
# Usage: const MeleeTellFx = preload("res://scripts/melee_tell_fx.gd")

const NODE_NAME := "MeleeTellFx"
const COLOR := Color(1.0, 0.72, 0.25)
const START_SIZE := 0.15
const END_SIZE := 0.55
const POP_TIME := 0.12

static var _mesh: SphereMesh = null
static var _mat: StandardMaterial3D = null

var _spark: MeshInstance3D
var _left := 0.0
var _total := 0.0

static func _shared() -> void:
	if _mesh != null:
		return
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.albedo_color = COLOR
	_mat.no_depth_test = true   # seen through the crowd around it
	_mesh = SphereMesh.new()
	_mesh.radius = 0.5
	_mesh.height = 1.0
	_mesh.radial_segments = 12
	_mesh.rings = 6
	_mesh.material = _mat

func _ready() -> void:
	_shared()
	_spark = MeshInstance3D.new()
	_spark.mesh = _mesh
	_spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_spark)
	_spark.visible = false
	set_process(false)

## Show the tell for `d` seconds.
func play(d: float) -> void:
	if _spark == null:
		return
	_total = maxf(d, 0.05)
	_left = _total + POP_TIME
	_spark.visible = true
	set_process(true)

func stop() -> void:
	_left = 0.0
	if _spark:
		_spark.visible = false
	set_process(false)

func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		stop()
		return
	var t := clampf(1.0 - (_left - POP_TIME) / _total, 0.0, 1.0)
	var s := lerpf(START_SIZE, END_SIZE, t)
	if _left < POP_TIME:   # the hit lands: a quick pop
		s = END_SIZE * (1.0 + 0.8 * (1.0 - _left / POP_TIME))
	_spark.scale = Vector3.ONE * s
