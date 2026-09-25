extends CharacterBody3D

const SPEED = 3.6
const BASE_WALK_SPEED = 3.0  # speed the walk animation was tuned for
const JUMP_VELOCITY = 4.5
const TURN_SPEED = 12.0
const BLEND_TIME = 0.2

const CAST_TIME = 1.3
const ENEMY_LAYER_MASK = 4  # physics layer 3 = enemies

const SOURCE_ANIM = "mixamo_com"
const WALK_SCENE: PackedScene = preload("res://assets/player/Walking.fbx")
const CAST_SCENE: PackedScene = preload("res://assets/player/Spell Casting.fbx")
const FROST_BOLT = preload("res://scripts/frost_bolt.gd")
const BLIZZARD = preload("res://scripts/blizzard.gd")
const CIRCLE_SHADER: Shader = preload("res://shaders/aoe_circle.gdshader")
const BLIZZARD_CAST_TIME = 2.0
const BLIZZARD_RADIUS = 2.5

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var model: Node3D = $Model
@onready var anim: AnimationPlayer = $Model/AnimationPlayer

var current_state: String = ""
var target: Node3D = null

var cast_timer := 0.0
var cast_name := "Frost Bolt"
var cast_duration: float = CAST_TIME
var current_spell := ""        # "frostbolt" | "blizzard" | "rayoffrost" while casting
var cast_is_channel := false   # channels drain the cast bar instead of filling it

const RAY_DURATION = 3.0
const RAY_TICK = 1.0
const RAY_DAMAGE = 1
var _ray_next_tick := 1.0
var _ray_tick := RAY_TICK
var _beam: MeshInstance3D
var _beam_light: OmniLight3D

# Ground-targeting (Blizzard placement)
var placement_valid := true
var cast_point := Vector3.ZERO
var aoe_indicator: MeshInstance3D
var target_ring: MeshInstance3D
const Combat = preload("res://scripts/combat_utils.gd")

@export var max_health: int = 10
var health: int = max_health

signal health_changed(current: int, maximum: int)
signal player_died

# FINAL damage only: crit / armor block / resist were already resolved by the
# CombatSystem pipeline. Enemies attack via CombatSystem.deal().
var god_mode := false   # debug: /god

func take_damage(amount: int) -> void:
	if health <= 0 or amount <= 0 or god_mode:
		return
	health = max(health - amount, 0)
	health_changed.emit(health, max_health)
	_bulwark_retaliate()
	_bus().player_damaged.emit(amount)
	_bus().player_health_changed.emit(health, max_health)
	if health == 0:
		_die()

func _bus() -> Node:
	return get_node("/root/SignalBus")

func is_dead() -> bool:
	return health <= 0

func is_alive() -> bool:
	return health > 0

# --- State machine ------------------------------------------------------------
# One authoritative state instead of loose flags. `casting` / `placing` are
# kept as read-only-style properties derived from it so existing code works.
#   IDLE / MOVING : free to act
#   CASTING       : cast bar filling (Frost Bolt, Blizzard, Steady Shot)
#   CHANNELING    : cast bar draining (Ray of Frost)
#   AIMING        : placing a ground-targeted spell (Blizzard circle)
#   DEAD          : terminal until restart
enum PState {IDLE, MOVING, CASTING, CHANNELING, AIMING, DEAD}
const PSTATE_NAMES := ["Idle", "Moving", "Casting", "Channeling", "Aiming", "Dead"]
var pstate: int = PState.IDLE

var casting: bool:
	get:
		return pstate == PState.CASTING or pstate == PState.CHANNELING
	set(v):
		if not v and (pstate == PState.CASTING or pstate == PState.CHANNELING):
			change_state(PState.IDLE)

var placing: bool:
	get:
		return pstate == PState.AIMING
	set(v):
		if v:
			change_state(PState.AIMING)
		elif pstate == PState.AIMING:
			change_state(PState.IDLE)

func state_name() -> String:
	return PSTATE_NAMES[pstate]

func change_state(new_state: int) -> bool:
	if new_state == pstate:
		return true
	if pstate == PState.DEAD:
		return false   # only a restart leaves DEAD
	pstate = new_state
	return true

func _die() -> void:
	casting = false
	cancel_placement()
	change_state(PState.DEAD)
	if status:
		status.clear()
	_set_target(null)
	anim.pause()
	# Topple over backwards.
	var t := create_tween()
	t.tween_property(model, "rotation:x", deg_to_rad(-85.0), 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	player_died.emit()
	_bus().player_died.emit()

func _ready() -> void:
	add_to_group("player")
	# Enemies are only on the enemy layer (not in our mask): you can walk
	# through a pack. They still stop at you (their mask has layer 1).
	collision_mask &= ~ENEMY_LAYER_MASK
	_setup_status()
	_setup_animations()
	_set_state("idle")
	_build_aoe_indicator()
	_build_target_ring()
	# Stats from gear/talents (max health etc.) + the rune listener.
	max_health = int(get_stat("max_health"))
	health = max_health
	get_node("/root/PlayerData").changed.connect(_on_stats_changed)
	_bus().level_up.connect(_on_level_up)
	# Instant abilities announce themselves with cast_finished while use_ability runs.
	_bus().cast_finished.connect(func(_id):
		if _acting:
			_acted = true)
	_bus().player_blocked.connect(_bulwark_retaliate)   # blocked hits trigger Sacred Bulwark too
	var listener := Node.new()
	listener.name = "RuneListener"
	listener.set_script(RUNE_LISTENER)
	add_child(listener)
	_bus().player_health_changed.emit.call_deferred(health, max_health)

# Red ground circle under whatever enemy is targeted, sized to its hitbox.
func _build_target_ring() -> void:
	target_ring = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)   # scaled to the target's hitbox diameter
	quad.orientation = PlaneMesh.FACE_Y
	target_ring.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = CIRCLE_SHADER
	mat.set_shader_parameter("color", Color(1.0, 0.15, 0.1))
	mat.set_shader_parameter("fill_alpha", 0.25)
	mat.set_shader_parameter("rim_width", 0.18)
	target_ring.material_override = mat
	target_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	target_ring.top_level = true
	target_ring.visible = false
	add_child(target_ring)

func _update_target_ring() -> void:
	if not _has_valid_target():
		target_ring.visible = false
		return
	var r := Combat.hitbox_radius(target)
	var p := target.global_position
	target_ring.global_position = Vector3(p.x, Combat.feet_y(target) + 0.05, p.z)
	target_ring.scale = Vector3(r * 2.0, 1.0, r * 2.0)
	target_ring.visible = true

func _build_aoe_indicator() -> void:
	aoe_indicator = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(BLIZZARD_RADIUS * 2.0, BLIZZARD_RADIUS * 2.0)
	quad.orientation = PlaneMesh.FACE_Y
	aoe_indicator.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = CIRCLE_SHADER
	mat.set_shader_parameter("fill_alpha", 0.12)
	aoe_indicator.material_override = mat
	aoe_indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aoe_indicator.top_level = true   # positioned in world space, not with the player
	aoe_indicator.visible = false
	add_child(aoe_indicator)

## Built once per game session: restarts / new floors reuse it instead of
## re-instantiating the walk and cast FBX scenes.
static var _shared_lib: AnimationLibrary

func _setup_animations() -> void:
	if _shared_lib == null:
		_shared_lib = _build_library()
	anim.add_animation_library("player", _shared_lib)

func _build_library() -> AnimationLibrary:
	var lib := AnimationLibrary.new()

	var idle: Animation = anim.get_animation(SOURCE_ANIM).duplicate()
	idle.loop_mode = Animation.LOOP_LINEAR
	lib.add_animation("idle", idle)

	var walk := _extract_anim(WALK_SCENE)
	walk.loop_mode = Animation.LOOP_LINEAR
	_make_in_place(walk)
	lib.add_animation("walk", walk)

	var cast := _extract_anim(CAST_SCENE)
	cast.loop_mode = Animation.LOOP_NONE
	_make_in_place(cast)
	lib.add_animation("cast", cast)
	return lib

func _extract_anim(scene: PackedScene) -> Animation:
	var inst := scene.instantiate()
	var p: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	var a: Animation = p.get_animation(SOURCE_ANIM).duplicate()
	inst.free()
	return a

# Removes horizontal drift from the hips so animations play in place.
func _make_in_place(a: Animation) -> void:
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		if not String(a.track_get_path(t)).ends_with("Hips"):
			continue
		if a.track_get_key_count(t) == 0:
			continue
		var first: Vector3 = a.track_get_key_value(t, 0)
		for k in a.track_get_key_count(t):
			var v: Vector3 = a.track_get_key_value(t, k)
			a.track_set_key_value(t, k, Vector3(first.x, v.y, first.z))

# --- Input: targeting & abilities --------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if is_dead():
		if event.is_action_pressed("restart"):
			get_node("/root/GameManager").restart()
		return
	if placing and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_update_placement(event.position)
			if not placement_valid:
				_error("Not in line of sight")
			elif gcd_left > 0.0:
				pass   # still on the global cooldown: keep aiming, click again
			else:
				cancel_placement()
				_start_blizzard(cast_point)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placement()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_target_at(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		# Keys come from the Input Map (rebindable in Settings > Controls).
		for i in range(1, 9):
			if event.is_action_pressed("ability_%d" % i):
				activate_ability(i)
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed("target_next"):
			_tab_target()
			get_viewport().set_input_as_handled()

## Runs before the GUI: a clicked button / chat log / window keeps keyboard focus
## in Godot, and then W/A/S/D (bound to ui_up/down/...) move that focus around
## instead of the character. Any key press drops focus unless you're typing.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus and not (focus is LineEdit or focus is TextEdit):
		focus.release_focus()

## Movement input (zero while typing in chat or another text box).
func _move_input() -> Vector2:
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")

# Action bar slot N (keys 1-8, or clicking the slot) -> whatever ability the
# saved bar layout has there. Empty slots do nothing.
func activate_ability(slot: int) -> void:
	var pd := get_node_or_null("/root/PlayerData")
	if pd == null or slot < 1 or slot > pd.action_bar.size():
		return
	use_ability(pd.action_bar[slot - 1])

func use_ability(id: String) -> void:
	if is_dead() or id == "":
		return
	var pdata := get_node_or_null("/root/PlayerData")
	if pdata and not pdata.has_ability(id):
		_error("You haven't learned that ability")
		return
	if is_stunned():
		_error("You are stunned")
		return
	var cancelling_placement := id == "blizzard" and placing
	# Global cooldown: quietly ignored (the action bar shows the sweep).
	if not cancelling_placement and not casting and on_gcd(id) and gcd_left > 0.0:
		return
	if not casting and not cancelling_placement and not can_afford(id, true):
		return
	if not cancelling_placement:
		_bus().ability_used.emit(id)
	_acting = true
	_acted = false
	_use_ability_now(id)
	_acting = false
	# An instant ability went off (casts start the GCD in _begin_spell).
	if _acted and on_gcd(id) and gcd_left <= 0.0:
		_start_gcd()

func _use_ability_now(id: String) -> void:
	match id:
		"frostbolt":
			cancel_placement()
			_start_cast()
		"blizzard":
			if placing:
				cancel_placement()
			else:
				_begin_placement()
		"rayoffrost":
			cancel_placement()
			_start_ray()
		"slam":
			cancel_placement()
			_slam()
		"execute":
			cancel_placement()
			_execute()
		"steadyshot":
			cancel_placement()
			_start_steady_shot()
		"trinket_1", "trinket_2":
			_use_trinket(id)
		_:
			if Abilities.DRAFT_POOL.has(id):
				cancel_placement()
				_use_drafted(id)

# --- Stats, buffs and the central damage function ----------------------------------
# Stats = gear + talents (PlayerData) + active buffs. All player damage goes
# through deal_damage(), which adds the Damage stat, rolls crits and announces
# the hit on the SignalBus (the RuneListener reacts to those events).

const Stats = preload("res://scripts/core/stats.gd")
const CRIT_MULTIPLIER := 2
const BLOCK_PER_ARMOR := 5.0       # % block chance per armor point
const MAX_BLOCK := 60.0
const RUNE_LISTENER = preload("res://scripts/rune_listener.gd")

const StatusContainer = preload("res://scripts/core/status_container.gd")
var status: Node   # StatusContainer child "Status": buffs AND debuffs (Chilled etc.)

func _setup_status() -> void:
	status = Node.new()
	status.name = "Status"
	status.set_script(StatusContainer)
	add_child(status)
	status.changed.connect(func():
		_on_stats_changed()
		_bus().buffs_changed.emit())

## Final stat value: base + gear/talents/level/boons + buffs, primary stats
## converted (Intellect -> Spell Power, ...), percent buffs applied. See stats.gd.
func get_stat(stat: String) -> float:
	return Stats.resolve(stat, _raw_stat)

func _raw_stat(key: String) -> float:
	var pd := get_node_or_null("/root/PlayerData")
	var v: float = float(pd.total_stats().get(key, 0.0)) if pd else 0.0
	if status:
		v += status.stat_mod(key)
	return v

## Haste as a speed multiplier (casts, channels, auto-attacks, DoT ticks).
func haste_mult() -> float:
	return Stats.haste_mult(get_stat(Stats.HASTE))

# Kept for the RuneListener: builds a runtime StatusEffect and applies it.
func add_buff(source: String, stat: String, amount: float, duration: float, max_stacks: int = 1,
		display_name: String = "") -> void:
	if status == null:
		return
	var nice: String = preload("res://scripts/runes.gd").short_name(source)
	if nice == "":
		nice = display_name if display_name != "" else source.capitalize()
	status.apply(StatusContainer.make_buff(source, nice, stat, amount, duration, max_stacks,
		Color(1.0, 0.85, 0.35)), self)

func is_stunned() -> bool:
	return status != null and status.has_flag("stun")

func is_rooted() -> bool:
	return status != null and status.has_flag("root")

# Re-derive max health from stats (gear/talents/buffs changed).
func _on_stats_changed() -> void:
	var new_max := int(get_stat("max_health"))
	if new_max != max_health:
		var diff := new_max - max_health
		max_health = new_max
		if not is_dead():
			health = clampi(health + max(diff, 0), 1, max_health)
		_bus().player_health_changed.emit(health, max_health)

# Level up: new stats apply and health refills.
func _on_level_up(new_level: int) -> void:
	if is_dead():
		return
	_on_stats_changed()
	health = max_health
	health_changed.emit(health, max_health)
	_bus().player_health_changed.emit(health, max_health)
	_combat().float_text(self, "Level %d!" % new_level, Color(0.8, 0.6, 1.0), true)

# Heal self through the pipeline (float text + healing threat on enemies).
# With an ability id the heal scales with Spell / Attack Power.
func heal(amount: int, ability_id: String = "") -> void:
	if is_dead():
		return
	_combat().heal(self, self, amount, ability_id)

# Final HP change for a heal (called by CombatSystem.heal).
func receive_heal(amount: int) -> void:
	if is_dead():
		return
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)
	_bus().player_health_changed.emit(health, max_health)

func _combat() -> Node:
	return get_node("/root/CombatSystem")

func _move_speed() -> float:
	return SPEED * maxf(1.0 + get_stat("move_speed") / 100.0, 0.1)

# All player damage goes through the CombatSystem pipeline (damage stat, crit,
# armor, resist, on-hit effects like Chilled, threat, events).
## `damage_type` / `tags` override the ability's (rune and item effect hits).
func deal_damage(enemy: Node, base: int, ability_id: String, is_proc: bool = false,
		damage_type: String = "", tags: PackedStringArray = PackedStringArray()) -> int:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
		return 0
	var at: Vector3 = enemy.global_position
	var info = _combat().ability_hit(self, enemy, base, ability_id, is_proc, damage_type, tags)
	if not is_proc and not info.blocked:
		_on_hit_extra(enemy, at, ability_id)
	return int(info.amount)

## Extra effects some abilities have when they land. Not for procs, so chain /
## splash hits (dealt as procs) never chain again.
func _on_hit_extra(enemy: Node, at: Vector3, id: String) -> void:
	match id:
		"chainlightning", "stormshield":
			var jumps := 0
			for e in _enemies_near(at, float(Abilities.get_resource(id).radius), enemy):
				FROST_BOLT.spawn(get_tree().current_scene, at + Vector3(0, 0.3, 0), e, self, true, id, 1)
				jumps += 1
				if jumps >= 2:
					break
		"stormarrow":
			var r := float(Abilities.get_resource(id).radius)
			for e in _enemies_near(at, r, enemy):
				deal_damage(e, 1, id, true)
			_ring_effect(r, Abilities.color_of(id), at)
		"shadowstrike", "crusaderstrike", "radiantarrow":
			heal(1)

# Instant, free cast triggered by an rune (e.g. Rune of Frost).
func proc_cast(ability_id: String, enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
		return
	match ability_id:
		"frostbolt":
			FROST_BOLT.spawn(get_tree().current_scene,
				global_position + (-global_basis.z) * 0.5 + Vector3(0, 0.45, 0), enemy, self, true)
		_:
			var base := int(Abilities.get_resource(ability_id).damage) if Abilities.get_resource(ability_id) else 1
			deal_damage(enemy, base, ability_id, true)

func _float_text(at: Node3D, text: String, color: Color, big: bool) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 64 if big else 44
	l.pixel_size = 0.006
	l.outline_size = 12
	l.modulate = color
	get_tree().current_scene.add_child(l)
	l.global_position = at.global_position + Vector3(randf_range(-0.3, 0.3), 1.5, 0)
	var t := l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "global_position:y", l.global_position.y + 0.9, 0.8)
	t.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	t.chain().tween_callback(l.queue_free)

# --- Resources: mana / energy / rage (10 points each) ------------------------------

const Abilities = preload("res://scripts/abilities.gd")
const RESOURCE_MAX := 10.0
const MANA_REGEN := 0.5      # points per second (1 per 2 s)
const ENERGY_REGEN := 1.0    # points per second
const RAGE_DECAY := 0.5      # points per second lost

var resources := {"mana": RESOURCE_MAX, "energy": RESOURCE_MAX, "rage": 0.0}

func resource_points(res: String) -> int:
	return int(floor(float(resources.get(res, 0.0)) + 0.0001))

func can_afford(id: String, report: bool = false) -> bool:
	var res := Abilities.resource_of(id)
	var cost := Abilities.cost_of(id)
	if res == "" or cost <= 0:
		return true
	if resource_points(res) >= cost:
		return true
	if report:
		_error("Not enough %s" % res)
	return false

# Spend an ability's cost. Returns false (and reports) if it can't be paid.
func _pay(id: String) -> bool:
	if not can_afford(id, true):
		return false
	var res := Abilities.resource_of(id)
	if res != "":
		resources[res] = float(resources[res]) - Abilities.cost_of(id)
	return true

func _gain(res: String, amount: float) -> void:
	resources[res] = clampf(float(resources[res]) + amount, 0.0, resource_max(res))

## Max of a resource. Mana grows with Max Mana (Intellect); energy / rage stay at 10.
func resource_max(res: String) -> float:
	if res == "mana":
		return maxf(get_stat(Stats.MAX_MANA), 1.0)
	return RESOURCE_MAX

func _tick_resources(delta: float) -> void:
	if is_dead():
		return
	_gain("mana", MANA_REGEN * delta)
	_gain("energy", ENERGY_REGEN * delta)
	_gain("rage", -RAGE_DECAY * delta)

# --- Cooldowns -------------------------------------------------------------------

var cooldowns := {}   # ability id -> seconds remaining

# --- Global cooldown ---------------------------------------------------------------
# Starting a cast or using an instant ability puts every other GCD ability on
# a short shared cooldown. 1.5 s, sped up by 40% of your Haste (20% haste -> 8%
# faster), never below GCD_MIN. Trinket buttons are off the GCD.
const GCD_BASE := 1.5
const GCD_HASTE_SHARE := 0.4
const GCD_MIN := 0.75
var gcd_left := 0.0
var gcd_total := GCD_BASE
var _acting := false   # inside use_ability (to catch instant abilities going off)
var _acted := false

func gcd_duration() -> float:
	var haste := get_stat(Stats.HASTE) * GCD_HASTE_SHARE
	return maxf(GCD_BASE / Stats.haste_mult(haste), GCD_MIN)

static func on_gcd(id: String) -> bool:
	return id != "" and not Abilities.is_trinket_slot(id)

func _start_gcd() -> void:
	gcd_total = gcd_duration()
	gcd_left = gcd_total

func cooldown_left(id: String) -> float:
	if Abilities.is_trinket_slot(id):
		var item := _trinket_item(id)
		var rl := get_node_or_null("RuneListener")
		return rl.use_cooldown_left(item) if rl and item != "" else 0.0
	return maxf(float(cooldowns.get(id, 0.0)), gcd_left)   # the GCD shows on every GCD button

## Full cooldown of an action-bar button (for the cooldown sweep).
func cooldown_total(id: String) -> float:
	if Abilities.is_trinket_slot(id):
		var use := Items.use_effect_of(_trinket_item(id))
		return float(use.internal_cooldown) if use else 1.0
	if gcd_left > float(cooldowns.get(id, 0.0)):
		return gcd_total   # the sweep is the global cooldown right now
	return float(Abilities.info(id).get("cooldown", 1.0))

# --- Trinkets (action-bar buttons fire the equipped trinket's Use: effect) ------------

func _trinket_item(id: String) -> String:
	var pd := get_node_or_null("/root/PlayerData")
	return str(pd.equipment.get(Abilities.TRINKET_SLOTS.get(id, ""), "")) if pd else ""

func trinket_usable(id: String) -> bool:
	return Items.use_effect_of(_trinket_item(id)) != null

func _use_trinket(id: String) -> void:
	var rl := get_node_or_null("RuneListener")
	if rl == null:
		return
	var err: String = rl.use_item_effect(str(Abilities.TRINKET_SLOTS[id]))
	if err != "":
		_error(err)
		return
	_bus().cast_finished.emit(id)

func _tick_cooldowns(delta: float) -> void:
	gcd_left = maxf(gcd_left - delta, 0.0)
	for id in cooldowns.keys():
		cooldowns[id] = float(cooldowns[id]) - delta
		if cooldowns[id] <= 0.0:
			cooldowns.erase(id)

# --- Slam (instant melee, weapon damage) -------------------------------------------

const SLAM_COOLDOWN := 2.0

func _weapon() -> Dictionary:
	var pd := get_node_or_null("/root/PlayerData")
	if pd == null:
		return {}
	return Items.get_item(pd.equipment.get("Main Hand", ""))

func _in_weapon_range(e: Node3D, reach: float) -> bool:
	var d := Vector2(e.global_position.x - global_position.x, e.global_position.z - global_position.z).length()
	return d - Combat.hitbox_radius(e) - Combat.hitbox_radius(self) <= reach

func _slam() -> void:
	if casting:
		return
	if cooldown_left("slam") > 0.0:
		_error("Slam is not ready yet")
		return
	var w := _weapon()
	if w.get("weapon", "") != "melee":
		_error("Requires a melee weapon")
		return
	if not _has_valid_target():
		_error("No target")
		return
	if not _in_weapon_range(target, float(w["attack_range"])):
		_error("Target out of range")
		return
	var sight_err := _target_error(target)
	if sight_err != "":
		_error(sight_err)
		return
	cooldowns["slam"] = SLAM_COOLDOWN
	var dir := target.global_position - global_position
	rotation.y = atan2(-dir.x, -dir.z)
	var hit := target
	_gain("rage", float(Abilities.info("slam").get("generates", 5)))
	deal_damage(hit, int(w["damage"]), "slam")
	_bus().cast_finished.emit("slam")
	_slash_effect()
	_slash_effect()   # doubled for a heavier hit

# --- Execute (instant melee, 3x weapon damage, 5 rage) -------------------------------

func _execute() -> void:
	if casting:
		return
	var w := _weapon()
	if w.get("weapon", "") != "melee":
		_error("Requires a melee weapon")
		return
	if not _has_valid_target():
		_error("No target")
		return
	if not _in_weapon_range(target, float(w["attack_range"])):
		_error("Target out of range")
		return
	var sight_err := _target_error(target)
	if sight_err != "":
		_error(sight_err)
		return
	if not _pay("execute"):
		return
	var dir := target.global_position - global_position
	rotation.y = atan2(-dir.x, -dir.z)
	deal_damage(target, int(w["damage"]) * 3, "execute")
	_bus().cast_finished.emit("execute")
	_slash_effect()
	_slash_effect()
	_slash_effect()

# --- Steady Shot (1 s cast, bow, weapon damage; can move while casting) -------------

const STEADY_CAST := 1.0

func _start_steady_shot() -> void:
	if casting:
		return
	var w := _weapon()
	if w.get("weapon", "") != "ranged":
		_error("Requires a bow")
		return
	if not _has_valid_target():
		_error("No target")
		return
	if not _in_weapon_range(target, float(w["attack_range"])):
		_error("Target out of range")
		return
	var sight_err := _target_error(target)
	if sight_err != "":
		_error(sight_err)
		return
	_begin_spell("steadyshot", "Steady Shot", STEADY_CAST)

func _release_steady_shot() -> void:
	var w := _weapon()
	if w.get("weapon", "") != "ranged":
		_error("Requires a bow")
		return
	if not _has_valid_target():
		return
	var sight_err := _target_error(target)
	if sight_err != "":
		_error(sight_err)
		return
	var dir := target.global_position - global_position
	rotation.y = atan2(-dir.x, -dir.z)
	ARROW.spawn(get_tree().current_scene, global_position + (-global_basis.z) * 0.5 + Vector3(0, 0.45, 0),
		target, self, int(w["damage"]), "steadyshot")

func has_valid_target() -> bool:
	return _has_valid_target()

## Is the current target close enough for ability `id`? (Action bar grays out
## abilities that would fail with "Target out of range".) True when the ability
## needs no target or there is no target (other checks cover that).
func target_in_range(id: String) -> bool:
	var res := Abilities.get_resource(id)
	if res == null or not res.requires_target or not _has_valid_target():
		return true
	if int(res.weapon_requirement) != 0:
		var w := _weapon()
		if not w.has("attack_range"):
			return true   # no weapon: "Requires a melee weapon / bow" instead
		return _in_weapon_range(target, float(w["attack_range"]))
	if float(res.cast_range) > 0.0:
		return global_position.distance_to(target.global_position) <= float(res.cast_range)
	return true

# --- Weapon auto-attack ----------------------------------------------------------
# With a weapon in Main Hand, the player automatically attacks an enemy in range
# every `attack_interval` seconds while standing still and not casting/channeling.

const ARROW = preload("res://scripts/arrow.gd")
const Items = preload("res://scripts/items.gd")
var _auto_timer := 0.0

# Each auto-attack winds up for `attack_interval` seconds (standing still with an
# enemy in range) and then swings. Moving / casting / no enemy resets the wind-up.
var auto_windup := 0.0

func _try_auto_attack(moving: bool) -> void:
	var delta := get_physics_process_delta_time()
	if moving or casting or placing or not is_on_floor():
		auto_windup = 0.0
		return
	var pd := get_node_or_null("/root/PlayerData")
	if pd == null:
		return
	var weapon_id: String = pd.equipment.get("Main Hand", "")
	var w := Items.get_item(weapon_id)
	if not w.has("weapon"):
		auto_windup = 0.0
		return
	var enemy := _auto_attack_target(float(w["attack_range"]))
	if enemy == null:
		auto_windup = 0.0
		return
	auto_windup += delta
	if auto_windup < float(w["attack_interval"]) / haste_mult():
		return
	auto_windup = 0.0
	# Snap to face the enemy we're hitting.
	var dir := enemy.global_position - global_position
	rotation.y = atan2(-dir.x, -dir.z)
	if w["weapon"] == "ranged":
		ARROW.spawn(get_tree().current_scene, global_position + (-global_basis.z) * 0.5 + Vector3(0, 0.45, 0),
			enemy, self, int(w["damage"]), "auto_ranged")
	else:
		deal_damage(enemy, int(w["damage"]), "auto_melee")
		_slash_effect()
	# Auto-attacks and auto-shots build rage when you're playing a rage user.
	if _has_rage_spender():
		_gain("rage", AUTO_ATTACK_RAGE)

## Rage per auto-attack / auto-shot (only with a rage spender on the action bar).
const AUTO_ATTACK_RAGE := 1.0

## A rage-costing ability on your action bar. The base kit (Slam, Execute) is
## always known, so "on the bar" is what says you're actually playing rage.
func _has_rage_spender() -> bool:
	var pd := get_node_or_null("/root/PlayerData")
	if pd == null:
		return false
	for id in pd.action_bar:
		if id != "" and Abilities.resource_of(id) == "rage" and Abilities.cost_of(id) > 0:
			return true
	return false

# Only the current target, and only if it's in range and visible.
# Nothing targeted = no auto-attack.
func _auto_attack_target(reach: float) -> Node3D:
	if not _has_valid_target():
		return null
	if not _in_weapon_range(target, reach) or _target_error(target) != "":
		return null   # auto-attacks need line of sight AND the target in front of you
	return target

func _net_fx(kind: String, at: Vector3, tgt: Node = null, extra: Dictionary = {}) -> void:
	var net := get_node_or_null("/root/Net")
	if net:
		net.send_fx(kind, at, tgt, "", extra)

func _slash_effect(color: Color = Color(0.9, 0.95, 1.0)) -> void:
	_net_fx("slash", global_position, null, {"yaw": rotation.y})
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.lightened(0.3), 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = color
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.65
	torus.rings = 24
	torus.ring_segments = 4
	torus.material = mat
	var slash := MeshInstance3D.new()
	slash.mesh = torus
	slash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(slash)
	slash.position = Vector3(0, 0.3, -0.5)
	slash.rotation = Vector3(0.3, 0, 0.5)
	slash.scale = Vector3(0.6, 0.15, 0.6)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(slash, "scale", Vector3(1.1, 0.15, 1.1), 0.18)
	t.tween_property(slash, "rotation:y", 1.2, 0.18)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.18)
	t.chain().tween_callback(slash.queue_free)

# Tab: target the closest on-screen enemy. If that one is already targeted,
# each further press cycles to the next closest.
func _tab_target() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var screen := get_viewport().get_visible_rect()
	var candidates: Array[Node3D] = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D) or not e.is_alive():
			continue
		var p: Vector3 = e.global_position
		if cam.is_position_behind(p):
			continue
		if not screen.has_point(cam.unproject_position(p)):
			continue
		if not can_see(e):
			continue
		candidates.append(e)
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a, b):
		return global_position.distance_squared_to(a.global_position) \
			< global_position.distance_squared_to(b.global_position))
	var idx := candidates.find(target)
	_set_target(candidates[(idx + 1) % candidates.size()])

func _select_target_at(screen_pos: Vector2) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 200.0
	# Ray hits walls (layer 1) as well as enemies, so an enemy behind rock
	# can't be clicked. The player itself is excluded.
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | ENEMY_LAYER_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider.has_method("set_targeted") and can_see(hit.collider):
		_set_target(hit.collider)
	else:
		_set_target(null)

func can_see(node: Node3D) -> bool:
	return Combat.can_see(get_world_3d(), self, node)

## Like WoW: targeted spells and attacks need the target in your front half.
const FACING_ARC := 180.0

func is_facing(node: Node3D) -> bool:
	return Combat.is_in_front(self, node, FACING_ARC)

## Why `node` can't be cast at / attacked right now ("" = it can).
func _target_error(node: Node3D) -> String:
	if not can_see(node):
		return "Target not in line of sight"
	if not is_facing(node):
		return "You must be facing your target"
	return ""

signal action_error(message: String)

func _error(msg: String) -> void:
	action_error.emit(msg)
	_bus().action_error.emit(msg)

func _set_target(new_target: Node3D) -> void:
	if new_target == target:
		return
	if is_instance_valid(target):
		target.set_targeted(false)
	target = new_target
	if target:
		target.set_targeted(true)
		if not target.died.is_connected(_on_target_died):
			target.died.connect(_on_target_died)

func _on_target_died() -> void:
	target = null
	if casting and current_spell == "rayoffrost":
		cast_timer = 0.0      # killed it with the channel: count as completed
		_release_cast()
	elif casting and current_spell == "frostbolt":
		_cancel_cast()

func _has_valid_target() -> bool:
	return is_instance_valid(target) and target.is_alive()

# --- Frost bolt --------------------------------------------------------------

func _start_cast() -> void:
	if casting or not is_on_floor():
		return
	if not _has_valid_target():
		_error("No target")
		return
	if not target_in_range("frostbolt"):
		_error("Target out of range")
		return
	var sight_err := _target_error(target)
	if sight_err != "":
		_error(sight_err)
		return
	_begin_spell("frostbolt", "Frost Bolt", CAST_TIME)

## Cast times and channel durations are shortened by Haste.
func _begin_spell(spell: String, display_name: String, duration: float, channel: bool = false) -> void:
	if not change_state(PState.CHANNELING if channel else PState.CASTING):
		return
	# The ability's data is the single source of truth (the tooltip reads the
	# same value), so tooltip and game always agree.
	var ab_res := Abilities.get_resource(spell)
	if ab_res and float(ab_res.cast_time) > 0.0:
		duration = float(ab_res.cast_time)
	duration /= haste_mult()
	if on_gcd(spell):
		_start_gcd()   # the GCD starts when the cast starts (like WoW)
	cast_is_channel = channel
	current_spell = spell
	cast_name = display_name
	cast_duration = duration
	cast_timer = duration
	current_state = "cast"
	var length := anim.get_animation("player/cast").length
	# Casts stretch the animation over the cast time; channels play it once
	# quickly and hold the final pose while channeling.
	var anim_time := 0.6 if channel else duration
	anim.play("player/cast", 0.15, length / anim_time)
	_bus().cast_started.emit(spell, duration)

# --- Ray of Frost (channel) ------------------------------------------------------

func _start_ray() -> void:
	if casting or not is_on_floor():
		return
	if not _has_valid_target():
		_error("No target")
		return
	if not target_in_range("rayoffrost"):
		_error("Target out of range")
		return
	var sight_err := _target_error(target)
	if sight_err != "":
		_error(sight_err)
		return
	if not _pay("rayoffrost"):   # channels pay up front
		return
	_ray_tick = RAY_TICK / haste_mult()   # hasted channel: same ticks, faster
	_ray_next_tick = _ray_tick
	_begin_spell("rayoffrost", "Ray of Frost", RAY_DURATION, true)
	_net_fx("ray", global_position, target, {"d": RAY_DURATION})

# Called every physics frame while channeling. Returns false if the channel broke.
func _channel_ray_tick() -> bool:
	if not can_see(target):
		_error("Target not in line of sight")
		return false
	var elapsed := cast_duration - cast_timer
	while elapsed >= _ray_next_tick - 0.0001 and _ray_next_tick <= cast_duration + 0.0001:
		_ray_next_tick += _ray_tick
		deal_damage(target, RAY_DAMAGE, "rayoffrost")   # may kill it -> _on_target_died ends the channel
		if not casting:
			return true
	return true

func _update_beam() -> void:
	var show := casting and current_spell == "rayoffrost" and _has_valid_target()
	if not show:
		if _beam:
			_beam.visible = false
		return
	if _beam == null:
		_beam = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.07
		cyl.bottom_radius = 0.07
		cyl.height = 1.0
		cyl.radial_segments = 8
		cyl.rings = 1
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.7, 0.95, 1.0, 0.85)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.35, 0.85, 1.0)
		mat.emission_energy_multiplier = 4.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cyl.material = mat
		_beam.mesh = cyl
		_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_beam.top_level = true
		_beam_light = OmniLight3D.new()
		_beam_light.light_color = Color(0.4, 0.85, 1.0)
		_beam_light.omni_range = 3.0
		_beam.add_child(_beam_light)
		add_child(_beam)
	var from := global_position + (-global_basis.z) * 0.5 + Vector3(0, 0.45, 0)
	var to := target.global_position + Vector3(0, 0.3, 0)
	var length := from.distance_to(to)
	if length < 0.01:
		return
	var mid := (from + to) * 0.5
	var t := Transform3D(Basis(), mid).looking_at(to, Vector3.UP)
	# Cylinder runs along Y; rotate so it points along the look direction (-Z).
	t.basis = t.basis * Basis(Vector3.RIGHT, deg_to_rad(90))
	var pulse := 1.0 + 0.25 * sin(Time.get_ticks_msec() * 0.02)
	t.basis = t.basis.scaled_local(Vector3(pulse, length, pulse))
	_beam.global_transform = t
	_beam_light.light_energy = 1.5 * pulse
	_beam.visible = true

func _cancel_cast() -> void:
	if casting:
		_bus().cast_interrupted.emit(current_spell)
	casting = false
	current_spell = ""
	current_state = ""

func _release_cast() -> void:
	var spell := current_spell
	casting = false
	current_spell = ""
	current_state = ""
	_bus().cast_finished.emit(spell)
	if spell == "rayoffrost":
		return   # all damage was dealt by the channel ticks (mana paid at start)
	# Casts pay their cost when they complete (a cancelled cast costs nothing).
	if not _pay(spell):
		return
	if spell == "steadyshot":
		_release_steady_shot()
		return
	if spell == "blizzard":
		var bliz := Node3D.new()
		bliz.set_script(BLIZZARD)
		bliz.radius = BLIZZARD_RADIUS
		bliz.source = self
		get_tree().current_scene.add_child(bliz)
		bliz.global_position = cast_point
		var net := get_node_or_null("/root/Net")
		if net:
			net.send_fx("blizzard", cast_point)
		return
	var sight_err := _target_error(target)
	if sight_err != "":
		_error(sight_err)
		return
	var forward := -global_basis.z
	FROST_BOLT.spawn(get_tree().current_scene, global_position + forward * 0.6 + Vector3(0, 0.45, 0), target, self)

# --- Blizzard (ground-targeted) ------------------------------------------------

func _begin_placement() -> void:
	if casting or not is_on_floor():
		return
	if not can_afford("blizzard", true):
		return
	placing = true
	aoe_indicator.visible = true
	_update_placement(get_viewport().get_mouse_position())

# Returns true if a placement was active (so Esc handlers know it was consumed).
func cancel_placement() -> bool:
	if not placing:
		return false
	placing = false
	if aoe_indicator:
		aoe_indicator.visible = false
	return true

# Project the mouse onto the floor plane at the player's feet.
func _update_placement(screen_pos: Vector2) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var floor_y := global_position.y - 0.9
	var plane := Plane(Vector3.UP, floor_y)
	var hit = plane.intersects_ray(cam.project_ray_origin(screen_pos), cam.project_ray_normal(screen_pos))
	if hit == null:
		return
	cast_point = hit
	aoe_indicator.global_position = cast_point + Vector3(0, 0.04, 0)
	# Must be able to see the spot (not behind or inside rock).
	placement_valid = Combat.line_of_sight(get_world_3d(), Combat.sight_point(self), cast_point + Vector3(0, 0.3, 0))
	var mat: ShaderMaterial = aoe_indicator.material_override
	mat.set_shader_parameter("color", Color(0.45, 0.85, 1.0) if placement_valid else Color(1.0, 0.25, 0.2))

func _process(_delta: float) -> void:
	_auto_timer = max(_auto_timer - _delta, 0.0)
	_tick_cooldowns(_delta)
	_tick_resources(_delta)
	_update_target_ring()
	_update_beam()
	if placing:
		_update_placement(get_viewport().get_mouse_position())

func _start_blizzard(point: Vector3) -> void:
	if casting or not is_on_floor():
		return
	cast_point = point
	_begin_spell("blizzard", "Blizzard", BLIZZARD_CAST_TIME)

func _face(point: Vector3, delta: float) -> void:
	var dir := point - global_position
	dir.y = 0
	if dir.length() < 0.01:
		return
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, TURN_SPEED * delta)

# --- Movement ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if is_dead():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var input_dir := _move_input()

	# Crowd control: stun stops everything (and breaks casts); root only stops movement.
	if is_stunned():
		if casting:
			_cancel_cast()
		cancel_placement()
		velocity.x = 0.0
		velocity.z = 0.0
		auto_windup = 0.0
		_set_state("idle")
		move_and_slide()
		return
	if is_rooted():
		input_dir = Vector2.ZERO

	# Steady Shot can be cast on the move: tick it here, then fall through to
	# normal movement below.
	var steady := casting and current_spell == "steadyshot"
	if steady:
		if not _has_valid_target():
			_cancel_cast()
			steady = false
		else:
			cast_timer -= delta
			if cast_timer <= 0.0:
				_release_cast()
				steady = false

	if casting and not steady:
		var targeted := current_spell in ["frostbolt", "rayoffrost"]
		var lost_target := targeted and not _has_valid_target()
		if input_dir.length() > 0.1 or lost_target:
			_cancel_cast()  # moving interrupts the cast / channel
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			_face(target.global_position if targeted else cast_point, delta)
			cast_timer -= delta
			if current_spell == "rayoffrost" and not _channel_ray_tick():
				_cancel_cast()
			if not casting:   # channel ended (broken, or target killed)
				move_and_slide()
				return
			if cast_timer <= 0.0:
				_release_cast()
			move_and_slide()
			return


	var move_dir := Vector3.ZERO

	if input_dir.length() > 0.1:
		var camera := get_viewport().get_camera_3d()
		if camera:
			var cam_basis := camera.global_transform.basis
			var forward: Vector3 = -cam_basis.z
			forward.y = 0.0
			forward = forward.normalized()
			var right: Vector3 = cam_basis.x
			right.y = 0.0
			right = right.normalized()
			move_dir = (right * input_dir.x) + (forward * -input_dir.y)
			if move_dir.length() > 1.0:
				move_dir = move_dir.normalized()
		else:
			move_dir = Vector3(input_dir.x, 0, input_dir.y).normalized()

	_try_auto_attack(move_dir != Vector3.ZERO)

	if move_dir != Vector3.ZERO:
		velocity.x = move_dir.x * _move_speed()
		velocity.z = move_dir.z * _move_speed()
		var target_yaw := atan2(-move_dir.x, -move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, TURN_SPEED * delta)
		if pstate == PState.IDLE:
			change_state(PState.MOVING)
		_set_state("walk")
	else:
		if pstate == PState.MOVING:
			change_state(PState.IDLE)
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		if steady:
			# Standing still while aiming: face the target and hold the cast pose.
			_face(target.global_position, delta)
			if current_state != "cast":
				current_state = "cast"
				var length := anim.get_animation("player/cast").length
				anim.play("player/cast", 0.15, length / 0.6)
		else:
			_set_state("idle")

	move_and_slide()

func _set_state(state: String) -> void:
	if state == current_state:
		return
	current_state = state
	var anim_speed := _move_speed() / BASE_WALK_SPEED if state == "walk" else 1.0
	anim.play("player/" + state, BLEND_TIME, anim_speed)

# --- Drafted abilities (learned from the level-up draft) ------------------------------
# All instant. Costs / cooldowns / radius / damage come from the AbilityData .tres.
# Weapon abilities (weapon_requirement MELEE / RANGED) hit for
# weapon damage x weapon_damage_multiplier + damage. Every id in
# Abilities.DRAFT_POOL is handled in _use_drafted().

const BLINK_DISTANCE := 6.0

func _use_drafted(id: String) -> void:
	if casting:
		return
	if cooldown_left(id) > 0.0:
		_error("%s is not ready yet" % Abilities.ability_name(id))
		return
	var res := Abilities.get_resource(id)
	var w := _weapon()
	if int(res.weapon_requirement) == 1 and w.get("weapon", "") != "melee":
		_error("Requires a melee weapon")
		return
	if int(res.weapon_requirement) == 2 and w.get("weapon", "") != "ranged":
		_error("Requires a bow")
		return
	if bool(res.get("requires_shield")) and not has_shield():
		_error("Requires a shield")
		return
	if res.requires_target:
		if not _has_valid_target():
			_error("No target")
			return
		var sight_err := _target_error(target)
		if sight_err != "":
			_error(sight_err)
			return
		if int(res.weapon_requirement) != 0 and not _in_weapon_range(target, float(w["attack_range"])):
			_error("Target out of range")
			return
		if int(res.weapon_requirement) == 0 and res.cast_range > 0.0 \
				and global_position.distance_to(target.global_position) > res.cast_range:
			_error("Target out of range")
			return
	var err := _drafted_precheck(id, res, w)
	if err != "":
		_error(err)
		return
	if not _pay(id):
		return
	cooldowns[id] = float(res.cooldown)
	if res.resource_generated > 0:
		_gain(Abilities.resource_of(id), float(res.resource_generated))
	if res.requires_target and _has_valid_target():
		var dir := target.global_position - global_position
		rotation.y = atan2(-dir.x, -dir.z)
	var muzzle := global_position + (-global_basis.z) * 0.5 + Vector3(0, 0.45, 0)
	match id:
		"icelance":
			FROST_BOLT.spawn(get_tree().current_scene, muzzle, target, self, false, "icelance", int(res.damage))
		"frostnova":
			for e in _enemies_within(float(res.radius)):
				deal_damage(e, int(res.damage), "frostnova")   # Frozen comes from the ability's on-hit effect
			_ring_effect(float(res.radius), Color(0.6, 0.92, 1.0))
		"icebarrier":
			status.apply(StatusContainer.make_buff("icebarrier", "Ice Barrier", "armor", 3, 8.0, 1, Color(0.6, 0.9, 1.0)), self)
			_ring_effect(1.2, Color(0.6, 0.9, 1.0))
		"blink":
			var from := global_position
			global_position += _flat_forward() * _blink_distance()
			_ring_effect(0.8, Color(0.8, 0.6, 1.0), from)
			_ring_effect(0.8, Color(0.8, 0.6, 1.0))
		"whirlwind":
			for e in _enemies_within(float(res.radius)):
				deal_damage(e, int(w["damage"]), "whirlwind")
			for i in 3:
				rotation.y += TAU / 3.0
				_slash_effect()
		"battleshout":
			status.apply(StatusContainer.make_buff("battleshout", "Battle Shout", Stats.ATTACK_POWER, 2, 10.0, 1, Color(1.0, 0.6, 0.3)), self)
			_ring_effect(2.0, Color(1.0, 0.6, 0.3))
		"multishot":
			for e in _multishot_targets(float(w["attack_range"])):
				ARROW.spawn(get_tree().current_scene, muzzle, e, self, int(w["damage"]), "multishot")
		"poisonarrow":
			ARROW.spawn(get_tree().current_scene, muzzle, target, self, int(w["damage"]), "poisonarrow")
		"secondwind":
			heal(int(Abilities.HEALS[id]), id)
		# Spell projectiles (tinted by book: Fire, Lightning, Shadow, Holy)
		"fireball", "chainlightning", "shadowbolt", "corruption", "smite", \
				"wrath", "insectswarm", "entanglingroots":
			FROST_BOLT.spawn(get_tree().current_scene, muzzle, target, self, false, id, int(res.damage))
		"arcanemissiles":
			var tgt := target
			var dmg := int(res.damage)
			for i in 3:
				get_tree().create_timer(0.18 * i).timeout.connect(func():
					if is_alive() and is_instance_valid(tgt) and tgt.is_alive():
						FROST_BOLT.spawn(get_tree().current_scene,
							global_position + (-global_basis.z) * 0.5 + Vector3(0, 0.45, 0), tgt, self, false, id, dmg))
		# Bow abilities
		"flamingarrow", "stormarrow", "arcaneshot", "shadowarrow", "radiantarrow", "frostarrow":
			ARROW.spawn(get_tree().current_scene, muzzle, target, self, _weapon_hit(w, res), id)
		# Melee abilities
		"searingstrike", "thunderstrike", "arcanestrike", "shadowstrike", "crusaderstrike", "froststrike", \
				"sinisterstrike", "rupture", "eviscerate":
			deal_damage(target, _weapon_hit(w, res), id)
			_slash_effect(Abilities.color_of(id))
			_slash_effect(Abilities.color_of(id))
			if id == "arcanestrike":
				_gain("mana", 2.0)
		# Area bursts around you
		"flamenova", "arcaneexplosion":
			for e in _enemies_within(float(res.radius)):
				deal_damage(e, int(res.damage), id)
			_ring_effect(float(res.radius), Abilities.color_of(id))
		"holylight":
			heal(int(Abilities.HEALS[id]), id)
			_ring_effect(1.2, Abilities.color_of(id))
		"regrowth":
			heal(int(Abilities.HEALS[id]), id)
			_ring_effect(1.2, Abilities.color_of(id))
		"fanofknives":
			for e in _enemies_within(float(res.radius)):
				deal_damage(e, _weapon_hit(w, res), id)
			_ring_effect(float(res.radius), Abilities.color_of(id))
			for i in 3:
				rotation.y += TAU / 3.0
				_slash_effect(Abilities.color_of(id))
		# --- Shield abilities (need a shield in the Off Hand) ---
		"shieldofdawn":
			# Holy shield bash that heals you (twice as much behind Sacred Bulwark).
			deal_damage(target, _weapon_hit(w, res), id)
			var heals := 2 if status.has("sacredbulwark") else 1
			for i in heals:
				heal(int(Abilities.HEALS[id]), id)
			_shield_bash_effect(Abilities.color_of(id))
		"sacredbulwark":
			status.apply(StatusContainer.make_buff("sacredbulwark", "Sacred Bulwark", Stats.ARMOR,
				SACRED_BULWARK_ARMOR, SACRED_BULWARK_TIME, 1, Abilities.color_of(id)), self)
			_ring_effect(1.4, Abilities.color_of(id))
		"stormshield":
			# Chain jumps come from _on_hit_extra (like Chain Lightning).
			deal_damage(target, _weapon_hit(w, res), id)
			_shield_bash_effect(Abilities.color_of(id))
		"thunderaegis":
			# Shield slammed into the ground: lightning burst + stun (ability's on-hit effect).
			var r := float(res.radius)
			for e in _enemies_within(r):
				deal_damage(e, _weapon_hit(w, res), id)
			_ring_effect(r, Abilities.color_of(id))
			_ring_effect(r * 0.6, Color(1, 1, 1))
	# Instant spells / abilities "finish casting" right away (runes, log, audio).
	_bus().cast_finished.emit(id)

## Weapon ability damage: weapon damage x multiplier (at least 1) + flat bonus.
func _weapon_hit(w: Dictionary, res: Resource) -> int:
	var from_weapon := int(round(float(w.get("damage", 1)) * float(res.weapon_damage_multiplier)))
	return maxi(from_weapon, 1) + int(res.damage)

## Enemies around a point (not `exclude`), closest first.
func _enemies_near(point: Vector3, radius: float, exclude: Node = null) -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == exclude or not (e is Node3D) or not e.is_alive():
			continue
		var d := Vector2(e.global_position.x - point.x, e.global_position.z - point.z).length()
		if d - Combat.hitbox_radius(e) <= radius:
			out.append(e)
	out.sort_custom(func(a, b): return point.distance_squared_to(a.global_position) < point.distance_squared_to(b.global_position))
	return out

## Ability-specific "can I use it right now?" checks (before paying).
func _drafted_precheck(id: String, _res: Resource, w: Dictionary) -> String:
	match id:
		"multishot":
			if _multishot_targets(float(w["attack_range"])).is_empty():
				return "No enemies in range"
		"secondwind", "holylight", "regrowth":
			if health >= max_health:
				return "Already at full health"
	return ""

func _flat_forward() -> Vector3:
	var f := -global_basis.z
	f.y = 0.0
	return f.normalized()

# How far Blink can go before hitting a wall (layer 1).
func _blink_distance() -> float:
	var from := global_position + Vector3(0, 0.3, 0)
	var to := from + _flat_forward() * BLINK_DISTANCE
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return BLINK_DISTANCE
	return maxf(from.distance_to(hit.position) - 0.6, 0.0)

## Public versions for the RuneListener (item AoE effects).
func enemies_within(radius: float) -> Array:
	return _enemies_within(radius)

func ring_effect(radius: float, color: Color) -> void:
	_ring_effect(radius, color)

# --- Shields ------------------------------------------------------------------------

const SACRED_BULWARK_ARMOR := 3.0
const SACRED_BULWARK_TIME := 8.0
const BULWARK_RADIUS := 2.5
const BULWARK_ICD := 0.5   # at most one retaliation burst every half second
var _bulwark_ready_at := 0.0

func has_shield() -> bool:
	var pd := get_node_or_null("/root/PlayerData")
	return pd != null and Items.item_type(str(pd.equipment.get("Off Hand", ""))) == "shield"

## Sacred Bulwark: any attack against you (hit or blocked) sears enemies around you.
func _bulwark_retaliate() -> void:
	if status == null or not status.has("sacredbulwark") or is_dead():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _bulwark_ready_at:
		return
	_bulwark_ready_at = now + BULWARK_ICD
	for e in _enemies_within(BULWARK_RADIUS):
		deal_damage(e, 1, "sacredbulwark", true)
	_ring_effect(BULWARK_RADIUS, Abilities.color_of("sacredbulwark"))

## Shield bash visual: a quick flat pulse in front of you.
func _shield_bash_effect(color: Color) -> void:
	_slash_effect(color)
	_ring_effect(0.7, color, global_position + _flat_forward() * 0.8)

func _enemies_within(radius: float) -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D) or not e.is_alive():
			continue
		var d := Vector2(e.global_position.x - global_position.x, e.global_position.z - global_position.z).length()
		if d - Combat.hitbox_radius(e) <= radius and can_see(e):
			out.append(e)
	return out

# Current target first, then the closest visible enemies in bow range (max 3).
func _multishot_targets(reach: float) -> Array:
	var list := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node3D and e.is_alive() and _in_weapon_range(e, reach) and can_see(e):
			list.append(e)
	list.sort_custom(func(a, b):
		if a == target:
			return true
		if b == target:
			return false
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
	return list.slice(0, 3)

# Expanding flat ring (Frost Nova, Blink, shouts).
func _ring_effect(radius: float, color: Color, at: Vector3 = Vector3.INF) -> void:
	_net_fx("ring", global_position if at == Vector3.INF else at, null, {"r": radius, "c": color})
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
	var p := global_position if at == Vector3.INF else at
	ring.global_position = Vector3(p.x, p.y - 0.8, p.z)
	ring.scale = Vector3(0.2, 0.3, 0.2)
	var t := ring.create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector3(radius, 0.3, radius), 0.3).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	t.chain().tween_callback(ring.queue_free)
