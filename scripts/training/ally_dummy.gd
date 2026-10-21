extends CharacterBody3D


# Training room ally dummy: a friendly target to practise healing and shields on.
# Click it to make it your friendly target. It slowly loses health on its own
# (so there's always something to heal) but never drops below 1.
# Works with Heal, Rime Shell (incl. Thawing) and Shattering Wave.

const STATUS_CONTAINER = preload("res://scripts/core/status_container.gd")
const Stats = preload("res://scripts/core/stats.gd")
const DUMMY = preload("res://scripts/training/dummy.gd")
const SHIELDS = preload("res://scripts/core/shields.gd")
const THAWING_FX = preload("res://data/effects/thawing.tres")

var display_name := "Ally Dummy"
var level := 1
var health := 100
var max_health := 100
var status: Node

## Share of max health lost per second (the "incoming damage" to heal through).
@export var drain_pct := 0.03
var _drain_t := 0.0
var _bar: Node3D
var _fill: MeshInstance3D
var _shield: MeshInstance3D
var _ring_mat: StandardMaterial3D

func setup(lvl: int) -> void:
	level = maxi(lvl, 1)
	max_health = int(Stats.player_base_health(level) * 1.5)
	health = int(max_health * 0.6)
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	shape.shape = cap
	add_child(shape)
	var model := Node3D.new()
	model.name = "Model"
	model.position.y = -0.9
	add_child(model)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.24, 0.14)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.35, 0.75, 0.45)
	DUMMY._part(model, DUMMY._cyl(0.07, 1.9), wood, Vector3(0, 0.95, 0))
	DUMMY._part(model, DUMMY._cyl(0.32, 0.9), cloth, Vector3(0, 1.05, 0))
	var head := SphereMesh.new()
	head.radius = 0.22
	head.height = 0.44
	DUMMY._part(model, head, cloth, Vector3(0, 1.72, 0))
	var arms := BoxMesh.new()
	arms.size = Vector3(1.3, 0.1, 0.1)
	DUMMY._part(model, arms, wood, Vector3(0, 1.35, 0))

func _ready() -> void:
	add_to_group("friendly")
	collision_layer = 2   # not the world layer (walk through it), not an enemy
	collision_mask = 1
	status = Node.new()
	status.name = "Status"
	status.set_script(STATUS_CONTAINER)
	add_child(status)
	status.changed.connect(_update_bar)
	status.shield_expired.connect(func(id: String, left: int, source: Node):
		if id == "rime_shell" and source != null and source.get("frost_healer") != null:
			source.frost_healer.shell_runoff(self, left))   # Runoff (Cold Comfort)
	_build_bar()

func is_alive() -> bool:
	return true

func is_dead() -> bool:
	return false

func get_stat(stat: String) -> float:
	return status.stat_mod(stat) if status else 0.0

func combat_level() -> int:
	return level

## Thawing and other lockouts (Rime Shell's targeting check).
func has_lockout(effect_id: String) -> bool:
	return status != null and status.has(effect_id)

func receive_heal(amount: int) -> void:
	health = mini(health + amount, max_health)
	_update_bar()

func take_damage(amount: int) -> void:
	health = maxi(health - amount, 1)
	_update_bar()

## `armor_pct` = the caster's Hardened Frost; `shatters` = false with Everlasting Rime.
func receive_rime_shell(caster: Node, amount: int, armor_pct: float = 0.0, shatters: bool = true) -> void:
	SHIELDS.put_rime_shell(status, caster, amount, false, armor_pct, func():
		if is_instance_valid(caster) and caster.get("frost_healer") != null:
			caster.frost_healer.shell_broke(self, amount)   # Rime Shards (Cold Comfort)
		if shatters and is_instance_valid(caster) and caster.has_method("shatter_at"):
			caster.shatter_at(global_position))
	status.apply(THAWING_FX, caster)

## Frozen Aegis rune shield (adds up to `cap`).
func receive_frozen_aegis(caster: Node, amount: int, cap: int, armor_pct: float = 0.0) -> void:
	SHIELDS.add_aegis(status, caster, amount, cap, armor_pct)

## Snow Ward's shield.
func receive_snow_ward(caster: Node, amount: int, armor_pct: float = 0.0) -> void:
	SHIELDS.set_ward(status, caster, amount, armor_pct)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_drain_t -= delta
	if _drain_t <= 0.0:
		_drain_t = 1.0
		var dmg := _shared_damage(int(max_health * drain_pct))
		var through: int = status.absorb_damage(dmg)
		if through > 0:
			take_damage(through)

## A support effect may send part of what the dummy takes somewhere else (the
## Shadow healer's Crossed Strings): the meta "damage_share" holds a
## Callable(damage) that returns what is left for the dummy.
func _shared_damage(dmg: int) -> int:
	if not has_meta("damage_share"):
		return dmg
	var share: Variant = get_meta("damage_share")
	if share is Callable and (share as Callable).is_valid():
		return maxi(int((share as Callable).call(dmg)), 0)
	remove_meta("damage_share")
	return dmg

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and _bar:
		_bar.global_basis = cam.global_basis

# --- Overhead bar (green health + pale blue shield) -----------------------------------

func _build_bar() -> void:
	_bar = Node3D.new()
	_bar.position = Vector3(0, 1.25, 0)
	add_child(_bar)
	var bg := _quad(Color(0.05, 0.05, 0.05), 1.0, 0.14, 10)
	_bar.add_child(bg)
	_fill = _quad(Color(0.25, 0.85, 0.35), 0.94, 0.08, 11)
	_fill.position.z = 0.001
	_bar.add_child(_fill)
	_shield = _quad(Color(0.7, 0.9, 1.0, 0.85), 0.94, 0.08, 12)
	_shield.position.z = 0.002
	_bar.add_child(_shield)
	var name_l := Label3D.new()
	name_l.text = display_name
	name_l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_l.no_depth_test = true
	name_l.font_size = 32
	name_l.pixel_size = 0.006
	name_l.outline_size = 8
	name_l.modulate = Color(0.55, 1.0, 0.55)
	name_l.position = Vector3(0, 1.45, 0)
	add_child(name_l)
	_update_bar()

static func _quad(c: Color, w: float, h: float, prio: int) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	m.mesh = q
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.render_priority = prio
	if c.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

func _update_bar() -> void:
	if _fill == null:
		return
	var frac := float(health) / float(maxi(max_health, 1))
	_span(_fill, 0.0, frac)
	var sh := float(status.total_absorb()) / float(maxi(max_health, 1)) if status else 0.0
	_span(_shield, frac, frac + sh)

static func _span(m: MeshInstance3D, from: float, to: float) -> void:
	from = clampf(from, 0.0, 1.0)
	to = clampf(to, from, 1.0)
	m.visible = to - from > 0.001
	m.scale.x = maxf(to - from, 0.001)
	m.position.x = -0.47 + 0.94 * (from + to) / 2.0
