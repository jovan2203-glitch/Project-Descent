extends "res://scripts/enemy.gd"


# Training room dummy (hostile). Never dies (drops back to full health instead),
# gives no XP or loot, only fights when hit (no proximity aggro).
#   - DPS dummies (hits_back = false) stand still and reset 5 s after the last hit.
#   - Hitting dummies (hits_back = true) fight like zombies: chase, swing, leash home.
# The model is built in code (post, straw body, head, cross-bar arms).

## Swings at whoever it's fighting (and walks to them) like a zombie.
@export var hits_back := false
## Model size (the collision shape scales with it).
@export var dummy_scale := 1.0
@export var body_color := Color(0.72, 0.6, 0.38)

## Seconds without being hit before a DPS dummy resets (full health, out of combat).
const RESET_AFTER := 5.0
var _last_hit := 0.0
var _spot := Vector3.INF   # where it was placed: it never leaves it

func _init() -> void:
	display_name = "Training Dummy"
	max_health = 100
	move_speed = 0.0
	aggro_radius = 0.0
	help_radius = 0.0
	xp_reward = 0
	loot = null
	normal_drops_loot = false
	show_name = true
	contact_damage = 1.0
	attack_range = 1.2
	attack_cooldown = 1.0

## Call before adding to the tree (after setting the exports).
func setup(lvl: int) -> void:
	level = maxi(lvl, 1)
	# Every dummy stands still (hitting ones only swing at you when you're in
	# reach) and never leashes: it keeps fighting until you stop hitting it.
	move_speed = 0.0
	leash_radius = 100000.0
	attack_range = 1.2 * dummy_scale + 0.3
	_build_body()

func _build_body() -> void:
	var s := dummy_scale
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4 * s
	cap.height = 1.8 * s
	shape.shape = cap
	add_child(shape)
	var model := Node3D.new()
	model.name = "Model"
	model.position.y = -0.9 * s
	add_child(model)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.24, 0.14)
	var straw := StandardMaterial3D.new()
	straw.albedo_color = body_color
	straw.roughness = 1.0
	_part(model, _cyl(0.07 * s, 1.9 * s), wood, Vector3(0, 0.95 * s, 0))                    # post
	_part(model, _cyl(0.32 * s, 0.9 * s), straw, Vector3(0, 1.05 * s, 0))                   # body
	var head := SphereMesh.new()
	head.radius = 0.22 * s
	head.height = 0.44 * s
	_part(model, head, straw, Vector3(0, 1.72 * s, 0))
	var arms := BoxMesh.new()
	arms.size = Vector3(1.3 * s, 0.1 * s, 0.1 * s)
	_part(model, arms, wood, Vector3(0, 1.35 * s, 0))
	var base := _cyl(0.35 * s, 0.08 * s)
	_part(model, base, wood, Vector3(0, 0.04 * s, 0))
	health_bar_height = 1.25 * s

static func _cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 10
	return c

static func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> void:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	parent.add_child(m)

func _physics_process(delta: float) -> void:
	if _spot == Vector3.INF:
		_spot = global_position
	super._physics_process(delta)
	# Pinned: while it is fighting (an Incense aura keeps it so) the enemy movement
	# runs, and someone standing inside it slid it along; it stays put instead.
	# A pull or drag (busy_until) still moves it, and it stays where it lands.
	if _now_s() < busy_until:
		_spot = global_position
	elif global_position.x != _spot.x or global_position.z != _spot.z:
		global_position = Vector3(_spot.x, global_position.y, _spot.z)
	if state == State.RETURN:
		change_state(State.IDLE)   # stands where it is: "home" instantly (and heals)
	if state != State.CHASE and state != State.ATTACK:
		return
	# Stationary: never walks after you. A hitting dummy turns to face whoever
	# it's fighting and swings when they're in reach.
	velocity.x = 0.0
	velocity.z = 0.0
	var tgt := top_threat()
	if hits_back and tgt:
		_face(tgt.global_position - global_position, delta)
	# Reset (full health, out of combat) a few seconds after the last hit - for a
	# hitting dummy only once you've also stepped out of its reach.
	var quiet := Time.get_ticks_msec() / 1000.0 - _last_hit > RESET_AFTER
	var in_reach := hits_back and tgt != null and _dist_to(tgt) <= attack_range * 1.15
	if quiet and not in_reach:
		change_state(State.RETURN)
		change_state(State.IDLE)

## Stationary: no pathfinding toward the target.
func _path_direction(_goal: Vector3, _delta: float) -> Vector3:
	return Vector3.ZERO

func _attack(tgt: Node3D) -> void:
	if hits_back:
		super._attack(tgt)
	else:
		_attack_timer = attack_cooldown

func take_damage(amount: int) -> void:
	_last_hit = Time.get_ticks_msec() / 1000.0
	if state == State.DEAD:
		return
	if amount >= health:
		# Never dies: back to full.
		health = max_health
		_update_health_bar()
		_bus().enemy_damaged.emit(self, amount)
		return
	super.take_damage(amount)

func add_threat(source: Node, amount: float) -> void:
	_last_hit = Time.get_ticks_msec() / 1000.0
	super.add_threat(source, amount)
