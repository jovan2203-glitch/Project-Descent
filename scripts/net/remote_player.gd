extends CharacterBody3D

# Another party member's character as seen on this machine (created by Net).
# A pure puppet: it follows the position / facing / animation / health its
# owner streams and never simulates anything itself. On the host, enemies
# target it like the local player; hits on it are forwarded to its owner.

const SOURCE_ANIM = "mixamo_com"
const MODEL_SCENE: PackedScene = preload("res://assets/player/Idle.fbx")
const WALK_SCENE: PackedScene = preload("res://assets/player/Walking.fbx")
const CAST_SCENE: PackedScene = preload("res://assets/player/Spell Casting.fbx")
const FOLLOW := 14.0          # interpolation speed toward the streamed state
const SNAP_DISTANCE := 5.0    # further than this: teleport (blink, respawn)

var member_id := 0
var display_name := ""
var health := 10
var max_health := 10
## Mirrored from the owner (Net.send_support_state): a Rime Shell is up, and
## lockout effects (Weakened Soul...) -> time they end.
var has_rime_shell := false
## Member id of whoever cast that Rime Shell (0 = unknown / none).
var rime_shell_by := 0
var lockouts := {}
## Knocked down (0 health, not dead yet): stand next to them and press F to revive.
var downed := false

func has_lockout(effect_id: String) -> bool:
	return float(lockouts.get(effect_id, 0.0)) > Time.get_ticks_msec() / 1000.0

var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _has_state := false
var _anim_state := ""
var _model: Node3D
var _anim: AnimationPlayer
var _name_label: Label3D
var _hp_label: Label3D
var _dead_shown := false

func _ready() -> void:
	add_to_group("remote_player")
	# No collision with anything: other players walk through, rays ignore it.
	# The shape is still used for hitbox size (Combat.hitbox_radius).
	collision_layer = 0
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	add_child(cs)

	_model = MODEL_SCENE.instantiate()
	_model.name = "Model"
	add_child(_model)
	_model.position = Vector3(0, -0.9, 0)
	_model.rotation.y = PI
	_anim = _model.find_child("AnimationPlayer", true, false)
	_setup_animations()

	var lantern := OmniLight3D.new()
	lantern.light_color = Color(1, 0.76, 0.48)
	lantern.light_energy = 1.5
	lantern.omni_range = 8.0
	lantern.position = Vector3(0, 2.3, 0)
	add_child(lantern)

	_name_label = _make_label(34, Color(0.55, 0.85, 1.0))
	_name_label.position = Vector3(0, 1.45, 0)
	_name_label.text = display_name
	_hp_label = _make_label(28, Color(1.0, 0.4, 0.35))
	_hp_label.position = Vector3(0, 1.25, 0)
	_update_labels()
	_play("idle")

func _make_label(size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = size
	l.pixel_size = 0.006
	l.outline_size = 8
	l.modulate = color
	add_child(l)
	return l

# --- Net ----------------------------------------------------------------------------

func apply_state(pos: Vector3, yaw: float, anim_state: String, hp: int, mhp: int) -> void:
	_net_pos = pos
	_net_yaw = yaw
	if not _has_state:
		_has_state = true
		global_position = pos
		rotation.y = yaw
	var now_downed := hp <= 0 and anim_state == "downed"
	var changed := hp != health or mhp != max_health or now_downed != downed
	health = hp
	max_health = mhp
	downed = now_downed
	if changed:
		_update_labels()
	_update_downed_ring()
	if health <= 0:
		_show_dead()
	else:
		if _dead_shown:
			_show_alive()   # revived (or respawned): stand back up
		_play(anim_state if anim_state in ["idle", "walk", "cast"] else "idle")

func _physics_process(delta: float) -> void:
	if not _has_state:
		return
	if global_position.distance_to(_net_pos) > SNAP_DISTANCE:
		global_position = _net_pos
	else:
		global_position = global_position.lerp(_net_pos, clampf(delta * FOLLOW, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, _net_yaw, clampf(delta * FOLLOW, 0.0, 1.0))

func _update_labels() -> void:
	if _hp_label == null:
		return
	if downed:
		_hp_label.text = "DOWNED - revive (%s)" % get_node("/root/Settings").key_text("interact")
		_hp_label.modulate = Color(1.0, 0.6, 0.3)
	else:
		_hp_label.text = "Dead" if health <= 0 else "%d / %d" % [health, max_health]
		_hp_label.modulate = Color(1.0, 0.4, 0.35)

## Pulsing orange circle under a downed ally so they're easy to find.
var _downed_ring: MeshInstance3D

func _update_downed_ring() -> void:
	if downed and _downed_ring == null:
		_downed_ring = MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(1, 1)
		quad.orientation = PlaneMesh.FACE_Y
		_downed_ring.mesh = quad
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/aoe_circle.gdshader")
		mat.set_shader_parameter("color", Color(1.0, 0.6, 0.25))
		mat.set_shader_parameter("fill_alpha", 0.15)
		mat.set_shader_parameter("rim_width", 0.15)
		_downed_ring.material_override = mat
		_downed_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_downed_ring.position.y = -0.85
		add_child(_downed_ring)
		var r: float = preload("res://scripts/balance.gd").REVIVE_RANGE * 2.0   # stand inside to revive
		_downed_ring.scale = Vector3(r, 1, r)
		var t := _downed_ring.create_tween().set_loops()
		t.tween_property(_downed_ring, "transparency", 0.5, 0.6)
		t.tween_property(_downed_ring, "transparency", 0.0, 0.6)
	elif not downed and _downed_ring != null:
		_downed_ring.queue_free()
		_downed_ring = null

var _death_tween: Tween

func _show_dead() -> void:
	if _dead_shown:
		return
	_dead_shown = true
	if _anim:
		_anim.pause()
	if _death_tween:
		_death_tween.kill()
	_death_tween = create_tween()
	_death_tween.tween_property(_model, "rotation:x", deg_to_rad(-85.0), 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## Back on their feet after a revive: undo the fall and restart the animation.
func _show_alive() -> void:
	_dead_shown = false
	if _death_tween:
		_death_tween.kill()
		_death_tween = null
	if _model:
		_model.rotation.x = 0.0
	_anim_state = ""   # force _play to start the animation again
	if _anim:
		_anim.play()

# --- Visual effects this player triggers (sent by their machine through Net) --------

## Melee swing arc in front of the character, facing `yaw`.
func play_slash(yaw: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.95, 1.0)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.65
	torus.rings = 24
	torus.ring_segments = 4
	torus.material = mat
	# Pivot at the character, turned to the swing direction (whirlwind spins).
	var pivot := Node3D.new()
	add_child(pivot)
	pivot.rotation.y = yaw - rotation.y
	var slash := MeshInstance3D.new()
	slash.mesh = torus
	slash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(slash)
	slash.position = Vector3(0, 0.3, -0.5)
	slash.rotation = Vector3(0.3, 0, 0.5)
	slash.scale = Vector3(0.6, 0.15, 0.6)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(slash, "scale", Vector3(1.1, 0.15, 1.1), 0.18)
	t.tween_property(slash, "rotation:y", 1.2, 0.18)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.18)
	t.chain().tween_callback(pivot.queue_free)

## Expanding ground ring (Frost Nova, Blink, Ice Barrier, Battle Shout).
func play_ring(radius: float, color: Color, at: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 4
	torus.material = mat
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.top_level = true
	add_child(ring)
	ring.global_position = Vector3(at.x, at.y - 0.8, at.z)
	ring.scale = Vector3(0.2, 0.3, 0.2)
	var t := ring.create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector3(radius, 0.3, radius), 0.3).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	t.chain().tween_callback(ring.queue_free)

# --- Combatant interface (so enemies / CombatSystem can treat it as a player) ------

func is_alive() -> bool:
	return health > 0

func is_dead() -> bool:
	return health <= 0

func get_stat(_stat: String) -> float:
	return 0.0

## Their level (from the party roster): sizes the DoTs they put on enemies here.
func combat_level() -> int:
	var net := get_node_or_null("/root/Net")
	var m: Variant = net.members.get(member_id) if net else null
	return int(m.get("level", 1)) if m is Dictionary else 1

func damage_unit() -> float:
	return preload("res://scripts/core/stats.gd").level_hit(combat_level())

## Projectiles / Blizzards spawned for this puppet are visuals only: the real
## damage is dealt on its owner's machine and reported to the host from there.
func deal_damage(_enemy: Node, _base: float, _ability_id: String, _is_proc: bool = false,
		_damage_type: String = "", _tags: PackedStringArray = PackedStringArray()) -> int:
	return 0

func take_damage(_amount: int) -> void:
	pass

func receive_heal(_amount: int) -> void:
	pass

# --- Animation (same clips as the player) ------------------------------------------

func _setup_animations() -> void:
	if _anim == null or not _anim.has_animation(SOURCE_ANIM):
		return
	var lib := AnimationLibrary.new()
	var idle: Animation = _anim.get_animation(SOURCE_ANIM).duplicate()
	idle.loop_mode = Animation.LOOP_LINEAR
	lib.add_animation("idle", idle)
	var walk := _extract(WALK_SCENE)
	if walk:
		walk.loop_mode = Animation.LOOP_LINEAR
		_make_in_place(walk)
		lib.add_animation("walk", walk)
	var cast := _extract(CAST_SCENE)
	if cast:
		cast.loop_mode = Animation.LOOP_NONE
		_make_in_place(cast)
		lib.add_animation("cast", cast)
	_anim.add_animation_library("player", lib)

func _extract(scene: PackedScene) -> Animation:
	var inst := scene.instantiate()
	var p: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	var a: Animation = p.get_animation(SOURCE_ANIM).duplicate() if p and p.has_animation(SOURCE_ANIM) else null
	inst.free()
	return a

func _make_in_place(a: Animation) -> void:
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		if not String(a.track_get_path(t)).ends_with("Hips") or a.track_get_key_count(t) == 0:
			continue
		var first: Vector3 = a.track_get_key_value(t, 0)
		for k in a.track_get_key_count(t):
			var v: Vector3 = a.track_get_key_value(t, k)
			a.track_set_key_value(t, k, Vector3(first.x, v.y, first.z))

func _play(state: String) -> void:
	if _anim == null or state == _anim_state or not _anim.has_animation("player/" + state):
		return
	_anim_state = state
	var speed := 1.0
	if state == "cast":
		speed = _anim.get_animation("player/cast").length / 0.8
	_anim.play("player/" + state, 0.2, speed)
