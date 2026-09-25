extends CharacterBody3D

# Base class for ALL enemies.
#   - State machine: IDLE -> CHASE -> ATTACK, RETURN (leash/evade), DEAD
#   - Threat table: every damage/heal source builds threat; the enemy fights
#     whoever has the most (party-ready). Taunt via force_target().
#   - Status effects (child "Status"): slows, roots, stuns, DoTs, stat mods.
#   - All damage goes through CombatSystem (armor/crit/effects/threat/events).
#   - Navmesh pathfinding, faces the direction it moves, health bar, loot.
#   - Animations (shared per enemy type), elite/boss ranks, multiplayer replica.
#   - Performance: idle enemies scan for players 5x/s (staggered) and skip
#     physics while standing still; materials and animation libraries are
#     shared across all instances of a type.
#
# To make a new enemy (no code needed):
#   1. New scene: CharacterBody3D root (collision layer 5 = layers 1+3, mask 1)
#      with this script (or a small script that extends it and sets defaults
#      in _init, like zombie.gd), a CollisionShape3D and a "Model" child (the
#      imported model; its own clip becomes "idle").
#   2. Inspector: stats (health, speed, damage...), display_name, loot, and
#      Animation > animation_files, e.g. {"walk": "res://assets/x/Walking.fbx"}.
#      Optional: Elite / Boss names, scales, loot, glow.
#   3. Add the scene to the Dungeon's enemy_pool (or set it as boss_scene).
# Behaviour changes: override _setup_animations() / _play(state) / _attack(tgt).

signal died

enum State { IDLE, CHASE, ATTACK, RETURN, DEAD }
const STATE_NAMES := ["Idle", "Chase", "Attack", "Return", "Dead"]

const OUTLINE_SHADER: Shader = preload("res://shaders/outline.gdshader")
const Combat = preload("res://scripts/combat_utils.gd")
const STATUS_CONTAINER = preload("res://scripts/core/status_container.gd")
const DamageInfo = preload("res://scripts/core/damage_info.gd")
const Items = preload("res://scripts/items.gd")
const Runes = preload("res://scripts/runes.gd")
const LOOT_DROP = preload("res://scripts/loot_drop.gd")
const ItemDB = preload("res://scripts/core/item_db.gd")

@export var max_health: int = 3
@export var move_speed: float = 2.2
@export var aggro_radius: float = 5.0
## Max distance from the spawn point before the enemy gives up and returns.
@export var leash_radius: float = 14.0
@export var contact_damage: int = 1
@export var attack_range: float = 1.0
@export var attack_cooldown: float = 1.0
@export var armor: float = 0.0
@export var turn_speed: float = 10.0
@export var health_bar_height: float = 1.25
## Name shown in logs / UI ("Zombie").
@export var display_name: String = ""
## Enemy level: scales dropped item level.
@export_range(1, 100) var level: int = 1
## Experience given to the player on death.
@export var xp_reward: int = 10
## Data-driven drop table (LootTableData .tres). Falls back to `loot_table`.
@export var loot: Resource
## "normal", "elite" or "boss" (wider health bar, name plate).
@export var rank: String = "normal"
## Show `display_name` above the health bar.
@export var show_name: bool = false
## Legacy fallback only: chance for each dropped item to come with a random rune.
@export var loot_rune_chance: float = 0.3

@export_group("Animation")
## Clip name inside imported model files (Mixamo exports use "mixamo_com").
## Empty or missing = the file's first clip.
@export var source_anim: String = "mixamo_com"
## Animations per state, taken from model files: {"walk": "res://.../Walking.fbx"}.
## A value can also be an Array of paths (the first that exists is used).
## The Model's own clip is "idle". Known states: idle, walk, attack, death.
@export var animation_files: Dictionary = {}
## Speed (m/s) the walk clip was made for; playback is scaled to move_speed.
@export var walk_anim_base_speed: float = 3.0
## Strip hip translation from clips loaded from files so they play in place.
@export var in_place: bool = true
@export var anim_blend_time: float = 0.25

@export_group("Elite / Boss")
## Shown for the elite / boss version. Empty = "Elite <name>" / "<name> Lord".
@export var elite_name: String = ""
@export var boss_name: String = ""
@export var elite_scale: float = 1.3
@export var boss_scale: float = 1.8
## Health = base max_health x this x level multiplier.
@export var elite_health_mult: float = 2.5
@export var boss_health_mult: float = 6.6667
## Own drop tables for the elite / boss version (empty = the shared ones).
@export var elite_loot: Resource
@export var boss_loot: Resource
## Normal-rank enemies drop nothing by default (loot comes from elites / bosses).
@export var normal_drops_loot: bool = false
@export var elite_glow: Color = Color(1.0, 0.55, 0.2)
@export var boss_glow: Color = Color(1.0, 0.2, 0.15)

@export_group("Look")
## Multiplies the model's colors, so one model can serve several enemy types
## until each gets its own art. White = unchanged.
@export var model_tint: Color = Color.WHITE
@export_group("")

var health: int
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var state: State = State.IDLE
var spawn_position: Vector3
var status: Node

# Threat: instance_id -> {"node": Node, "value": float}
var threat := {}
var _taunt_target: Node = null
var _taunt_until := 0.0

var _attack_timer := 0.0
const AGGRO_SCAN_INTERVAL := 0.2
var _aggro_scan_timer := randf() * AGGRO_SCAN_INTERVAL   # staggered so packs don't all scan on one frame
var _meshes: Array[MeshInstance3D] = []
var _outline_mat: ShaderMaterial
static var _shared_outline: ShaderMaterial
static var _shared_bar_mats: Array[StandardMaterial3D] = []   # [background, full, empty]
var _health_bar: Node3D
var _segments: Array[MeshInstance3D] = []
var _seg_full: StandardMaterial3D
var _seg_empty: StandardMaterial3D
var _status_label: Label3D

# Each entry rolls independently: [{"id": "sword", "chance": 0.15}, ...]
var loot_table: Array = []

@onready var model: Node3D = get_node_or_null("Model")

# Multiplayer: on a party member's machine (not the host) this enemy is a
# replica that just follows the host's snapshots (see Net).
var _net: Node
var _net_has := false
var _net_pos := Vector3.ZERO
var _net_yaw := 0.0
var _net_moving := false
var _net_threat := 0          # member id of the player it's fighting (for host migration)

func _replica() -> bool:
	return _net != null and _net.is_client()

func _ready() -> void:
	_net = get_node_or_null("/root/Net")
	add_to_group("enemies")
	# Enemies don't physically block each other (they're only on the enemy
	# layer, not the world layer 1); crowding is handled softly by _crowd_velocity().
	collision_layer &= ~1
	collision_layer |= 4
	health = max_health
	spawn_position = global_position

	var mesh_root: Node = model if model else self
	for m in mesh_root.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(m)
	_apply_tint()
	# Identical for every enemy, so one shared material instead of one each.
	if _shared_outline == null:
		_shared_outline = ShaderMaterial.new()
		_shared_outline.shader = OUTLINE_SHADER
	_outline_mat = _shared_outline

	status = Node.new()
	status.name = "Status"
	status.set_script(STATUS_CONTAINER)
	add_child(status)
	status.changed.connect(_update_status_label)

	_bus().player_died.connect(_on_player_died)
	_setup_animations()
	_play("idle")
	_build_health_bar()

func _bus() -> Node:
	return get_node("/root/SignalBus")

# Tinted copies of the model's materials, shared per (material, tint): every
# goblin uses the same green materials instead of each making its own.
static var _tinted_mats := {}

func _apply_tint() -> void:
	if model_tint == Color.WHITE:
		return
	for m in _meshes:
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var mat := m.get_active_material(i) as BaseMaterial3D
			if mat == null:
				continue
			var key := "%d|%s" % [mat.get_instance_id(), model_tint.to_html()]
			if not _tinted_mats.has(key):
				var t: BaseMaterial3D = mat.duplicate()
				t.albedo_color = mat.albedo_color * model_tint
				_tinted_mats[key] = t
			m.set_surface_override_material(i, _tinted_mats[key])

func _cs() -> Node:
	return get_node("/root/CombatSystem")

## Scale up an enemy (elites / bosses). Call BEFORE adding it to the tree:
## scales the model, the hitbox (shape is duplicated), bar height and reach.
func make_bigger(s: float) -> void:
	var m := get_node_or_null("Model") as Node3D
	if m:
		m.scale *= s
		m.position *= s
	for c in get_children():
		if c is CollisionShape3D and c.shape:
			var sh: Shape3D = c.shape.duplicate()
			if sh is CapsuleShape3D:
				sh.radius *= s
				sh.height *= s
			elif sh is CylinderShape3D:
				sh.radius *= s
				sh.height *= s
			elif sh is BoxShape3D:
				sh.size *= s
			c.shape = sh
	health_bar_height *= s
	attack_range *= s

# --- Animation (shared by every enemy type) ---------------------------------------
# Clips come from the Model's own AnimationPlayer ("idle") plus `animation_files`.
# The library is built ONCE per enemy type and shared by every instance, so
# spawning a pack never re-imports/instantiates model files. An enemy type
# with special needs can override _build_animation_library() or _play().

const ANIM_LIB := "enemy"
const ONE_SHOT_STATES := ["attack", "death", "hit"]
static var _anim_libs := {}   # enemy type key -> AnimationLibrary

var _anim: AnimationPlayer
var _anim_state := ""
var _oneshot_until_ms := 0

## Play a one-shot clip ("attack", "death", "hit") if this enemy has it.
## Returns its length in seconds (0 if the enemy has no such clip).
func play_once(state: String) -> float:
	var full := ANIM_LIB + "/" + state
	if _anim == null or not _anim.has_animation(full):
		return 0.0
	var length := _anim.get_animation(full).length
	_anim.play(full, 0.1)
	_anim_state = state
	_oneshot_until_ms = Time.get_ticks_msec() + int(length * 1000.0)
	return length

func _setup_animations() -> void:
	_anim = model.find_child("AnimationPlayer", true, false) if model else null
	if _anim == null:
		return
	var key := _anim_key()
	if not _anim_libs.has(key):
		_anim_libs[key] = _build_animation_library(_anim)
	if not _anim.has_animation_library(ANIM_LIB):
		_anim.add_animation_library(ANIM_LIB, _anim_libs[key])

## One library per enemy type (its scene), not per instance.
func _anim_key() -> String:
	if scene_file_path != "":
		return scene_file_path
	return "%s|%s" % [get_script().resource_path, str(animation_files)]

func _build_animation_library(player: AnimationPlayer) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	var idle := _clip_of(player)
	if idle:
		idle = idle.duplicate()
		idle.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation("idle", idle)
	for state in animation_files:
		var clip := _clip_from_files(animation_files[state])
		if clip == null:
			push_warning("%s: no animation found for '%s'" % [display_name, state])
			continue
		clip.loop_mode = Animation.LOOP_NONE if ONE_SHOT_STATES.has(state) else Animation.LOOP_LINEAR
		if in_place:
			_strip_hips_position(clip)
		lib.add_animation(str(state), clip)
	return lib

## The clip named `source_anim` in an AnimationPlayer, else its first real clip.
func _clip_of(player: AnimationPlayer) -> Animation:
	if player == null:
		return null
	if source_anim != "" and player.has_animation(source_anim):
		return player.get_animation(source_anim)
	for n in player.get_animation_list():
		if n != "RESET":
			return player.get_animation(n)
	return null

func _clip_from_files(value: Variant) -> Animation:
	var paths: Array = value if value is Array else [value]
	for path in paths:
		if not ResourceLoader.exists(str(path)):
			continue
		var scene := load(str(path)) as PackedScene
		if scene == null:
			continue
		var inst := scene.instantiate()
		var clip := _clip_of(inst.find_child("AnimationPlayer", true, false))
		var out: Animation = clip.duplicate() if clip else null
		inst.free()
		if out:
			return out
	return null

# Drops the hips translation track so a clip plays in place and keeps this
# model's own hip height (important when borrowing another character's anim).
static func _strip_hips_position(a: Animation) -> void:
	for t in range(a.get_track_count() - 1, -1, -1):
		if a.track_get_type(t) == Animation.TYPE_POSITION_3D \
				and String(a.track_get_path(t)).ends_with("Hips"):
			a.remove_track(t)

## Play a state's clip ("idle", "walk", ...). Missing states are ignored.
func _play(state: String) -> void:
	if _anim == null or state == _anim_state:
		return
	# Let a one-shot (attack / hit) finish before going back to idle / walk.
	if Time.get_ticks_msec() < _oneshot_until_ms and not ONE_SHOT_STATES.has(state):
		return
	var full := ANIM_LIB + "/" + state
	if not _anim.has_animation(full):
		return
	var first := _anim_state == ""
	_anim_state = state
	var speed := move_speed / walk_anim_base_speed if state == "walk" and walk_anim_base_speed > 0.0 else 1.0
	_anim.play(full, anim_blend_time, speed)
	if first:
		# Offset each enemy's idle so a group doesn't sway in sync.
		_anim.seek(randf() * _anim.current_animation_length, true)

# --- Rank (normal / elite / boss) ------------------------------------------------------
# Works for every enemy type: scales from that type's own base stats.

const ELITE_LOOT := "res://data/loot/elite.tres"
const BOSS_LOOT := "res://data/loot/boss.tres"

## Scale for rank and level. Call BEFORE adding the enemy to the tree.
func apply_rank(new_rank: String, lvl: int) -> void:
	var mult := 1.0 + 0.25 * (maxi(lvl, 1) - 1)
	var base_hp := max_health
	var base_dmg := contact_damage
	var base_xp := float(xp_reward)
	var base_name := display_name
	level = lvl
	rank = new_rank
	match new_rank:
		"elite":
			make_bigger(elite_scale)
			max_health = maxi(int(round(base_hp * elite_health_mult * mult)), 1)
			contact_damage = base_dmg + 1 + (lvl - 1) / 3
			armor += 1.0
			move_speed *= 1.1
			xp_reward = int(round(base_xp * (3.0 + 0.5 * lvl)))
			display_name = elite_name if elite_name != "" else "Elite " + base_name
			show_name = true
			loot = elite_loot if elite_loot else load(ELITE_LOOT)
			_add_glow(elite_glow, 1.2)
		"boss":
			make_bigger(boss_scale)
			max_health = maxi(int(round(base_hp * boss_health_mult * mult)), 1)
			contact_damage = base_dmg + 2 + (lvl - 1) / 2
			attack_cooldown *= 1.4
			armor += 2.0
			aggro_radius *= 1.8
			leash_radius = maxf(leash_radius, 40.0)
			xp_reward = int(round(base_xp * (10.0 + 2.0 * lvl)))
			display_name = boss_name if boss_name != "" else base_name + " Lord"
			show_name = true
			loot = boss_loot if boss_loot else load(BOSS_LOOT)
			_add_glow(boss_glow, 2.5)
		_:
			max_health = maxi(int(round(base_hp * mult)), 1)
			contact_damage = base_dmg + (lvl - 1) / 3
			xp_reward = int(round(base_xp * (0.8 + 0.2 * lvl)))
			if not normal_drops_loot:
				loot = null
				loot_table = []

## How much bigger this enemy is for `r` (spawners use it to place it on the floor).
func rank_scale(r: String) -> float:
	match r:
		"elite": return elite_scale
		"boss": return boss_scale
	return 1.0

## Height of this enemy's origin above the floor it stands on, from its own
## hitbox (after any rank scaling). Spawners place enemies with this.
func ground_offset() -> float:
	for c in get_children():
		if c is CollisionShape3D and c.shape:
			var sh: Shape3D = c.shape
			var half := 0.5
			if sh is CapsuleShape3D or sh is CylinderShape3D:
				half = sh.height * 0.5
			elif sh is SphereShape3D:
				half = sh.radius
			elif sh is BoxShape3D:
				half = sh.size.y * 0.5
			return half - c.position.y + 0.05
	return 0.95

func _add_glow(color: Color, energy: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = 3.5
	l.position = Vector3(0, 0.5, 0)
	add_child(l)

# --- Stats (used by CombatSystem) -----------------------------------------------

func get_stat(stat: String) -> float:
	var v := 0.0
	match stat:
		"armor": v = armor
		"max_health": v = max_health
	if status:
		v += status.stat_mod(stat)
	return v

func _current_speed() -> float:
	return max(move_speed * (1.0 + get_stat("move_speed") / 100.0), 0.0)

# --- State machine ------------------------------------------------------------------

const ALLOWED := {
	State.IDLE: [State.CHASE, State.DEAD],
	State.CHASE: [State.ATTACK, State.RETURN, State.DEAD],
	State.ATTACK: [State.CHASE, State.RETURN, State.DEAD],
	State.RETURN: [State.IDLE, State.CHASE, State.DEAD],
	State.DEAD: [],
}

func change_state(new_state: State) -> bool:
	if new_state == state:
		return true
	if not ALLOWED[state].has(new_state):
		push_warning("%s: illegal state change %s -> %s" % [name, STATE_NAMES[state], STATE_NAMES[new_state]])
		return false
	_exit_state(state)
	state = new_state
	_enter_state(new_state)
	_bus().enemy_state_changed.emit(self, STATE_NAMES[new_state])
	return true

func _enter_state(s: State) -> void:
	match s:
		State.CHASE:
			_repath_timer = 0.0
		State.ATTACK:
			pass
		State.RETURN:
			threat.clear()
			_repath_timer = 0.0
			status.clear()
		State.IDLE:
			velocity.x = 0.0
			velocity.z = 0.0

func _exit_state(s: State) -> void:
	match s:
		State.RETURN:
			# Arrived home: fully healed.
			health = max_health
			_update_health_bar()

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if _replica():
		_net_follow(delta)
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	_attack_timer = max(_attack_timer - delta, 0.0)

	var stunned: bool = status.has_flag("stun")
	var rooted: bool = status.has_flag("root")
	var moving := false

	match state:
		State.IDLE:
			# Scanning for players costs a group lookup + sight raycasts, so
			# idle enemies only look a few times per second (staggered).
			_aggro_scan_timer -= delta
			if _aggro_scan_timer <= 0.0:
				_aggro_scan_timer = AGGRO_SCAN_INTERVAL
				_look_for_players()
			# Standing still on the ground: nothing to simulate this frame.
			if state == State.IDLE and is_on_floor():
				velocity = Vector3.ZERO
				_play("idle")
				return
		State.CHASE:
			var tgt := top_threat()
			if tgt == null or _flat_dist(spawn_position) > leash_radius:
				change_state(State.RETURN)
			elif _dist_to(tgt) <= attack_range:
				change_state(State.ATTACK)
			elif not stunned and not rooted:
				var dir := _path_direction(tgt.global_position, delta)
				velocity.x = dir.x * _current_speed()
				velocity.z = dir.z * _current_speed()
				moving = true
		State.ATTACK:
			var tgt2 := top_threat()
			if tgt2 == null:
				change_state(State.RETURN)
			elif _dist_to(tgt2) > attack_range * 1.15:
				change_state(State.CHASE)
			elif not stunned:
				_face(tgt2.global_position - global_position, delta)
				if _attack_timer <= 0.0:
					_attack(tgt2)
		State.RETURN:
			if _flat_dist(spawn_position) < 0.5:
				change_state(State.IDLE)
			elif not stunned and not rooted:
				var dir2 := _path_direction(spawn_position, delta)
				velocity.x = dir2.x * _current_speed() * 1.5
				velocity.z = dir2.z * _current_speed() * 1.5
				moving = true

	if not moving:
		velocity.x = 0.0
		velocity.z = 0.0
	if not rooted and not stunned and (state == State.CHASE or state == State.ATTACK):
		var crowd := _crowd_velocity(top_threat() if state == State.ATTACK else null)
		velocity.x += crowd.x
		velocity.z += crowd.z
	_play("walk" if moving else "idle")
	move_and_slide()

	# Face the direction we actually moved (includes sliding along walls).
	if moving:
		var moved := get_real_velocity()
		moved.y = 0.0
		if moved.length() > 0.3:
			_face(moved, delta)

func _look_for_players() -> void:
	# "remote_player" = other party members' characters (on the host).
	for p in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("remote_player"):
		if not (p is Node3D) or _is_dead(p):
			continue
		if _dist_to(p) <= aggro_radius and _can_see(p):
			add_threat(p, 1.0)   # proximity aggro
			return

func _attack(tgt: Node3D) -> void:
	_attack_timer = attack_cooldown
	play_once("attack")
	if tgt.is_in_group("remote_player"):
		# Another player's character: they take the hit on their own machine.
		if _net:
			_net.send_enemy_hit(self, tgt, contact_damage, PackedStringArray(["Physical", "Melee"]), "physical")
		return
	var info := DamageInfo.make(self, tgt, contact_damage, "enemy_melee")
	info.tags = PackedStringArray(["Physical", "Melee"])
	_cs().deal(info)

# --- Threat ----------------------------------------------------------------------------

func add_threat(source: Node, amount: float) -> void:
	if _replica():
		return   # threat lives on the host (clients report their hits there)
	if state == State.DEAD or state == State.RETURN:
		return
	if source == null or not is_instance_valid(source) \
			or not (source.is_in_group("player") or source.is_in_group("remote_player")):
		return
	var key := source.get_instance_id()
	if not threat.has(key):
		threat[key] = {"node": source, "value": 0.0}
	threat[key]["value"] += amount
	if state == State.IDLE:
		change_state(State.CHASE)
		_bus().enemy_aggroed.emit(self)
		_call_for_help(source)

## Pack aggro: idle allies within HELP_RADIUS that can see this enemy join the
## fight against the same target. One hop only (they don't call their own
## friends), so pulling a pack doesn't drag the whole dungeon along.
@export var help_radius: float = 7.0
var _helping := false

func _call_for_help(source: Node) -> void:
	if _helping or help_radius <= 0.0:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not (e is Node3D) or not e.is_alive() or e.get("state") != State.IDLE:
			continue
		if _dist_to(e) > help_radius or not _can_see(e):
			continue
		e._helping = true
		e.add_threat(source, 0.5)
		e._helping = false

## Taunt: attack `source` for `duration` seconds regardless of threat.
func force_target(source: Node, duration: float) -> void:
	add_threat(source, 0.0)
	_taunt_target = source
	_taunt_until = Time.get_ticks_msec() / 1000.0 + duration

func is_fighting(node: Node) -> bool:
	return node != null and threat.has(node.get_instance_id())

## The living target with the highest threat (taunts win while active).
func top_threat() -> Node3D:
	if _taunt_target and is_instance_valid(_taunt_target) and not _is_dead(_taunt_target) \
			and Time.get_ticks_msec() / 1000.0 < _taunt_until:
		return _taunt_target
	var best: Node3D = null
	var best_v := -1.0
	for key in threat.keys():
		var n = threat[key]["node"]
		if not is_instance_valid(n) or _is_dead(n):
			threat.erase(key)
			continue
		if float(threat[key]["value"]) > best_v:
			best_v = float(threat[key]["value"])
			best = n
	return best

func get_threat_list() -> Array:
	var out := []
	for key in threat:
		out.append({"node": threat[key]["node"], "value": threat[key]["value"]})
	out.sort_custom(func(a, b): return a["value"] > b["value"])
	return out

func _on_player_died() -> void:
	if _replica():
		return
	# In a party the fight goes on while anyone is still standing.
	if _net and _net.with_others() and _net.any_party_alive():
		return
	if state != State.DEAD and state != State.IDLE:
		change_state(State.RETURN)

func _is_dead(n: Node) -> bool:
	return n.has_method("is_alive") and not n.is_alive()

# --- Pathfinding ---------------------------------------------------------------

var _path := PackedVector3Array()
var _path_idx := 0
var _repath_timer := 0.0
var _path_goal := Vector3.INF
const REPATH_INTERVAL := 0.25
const WAYPOINT_REACHED := 0.35

# Direction toward `goal`, following the navmesh around obstacles. Waypoints
# advance by flat distance; falls back to straight-line if no path exists.
func _path_direction(goal: Vector3, delta: float) -> Vector3:
	var straight := goal - global_position
	straight.y = 0.0
	straight = straight.normalized()
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return straight
	_repath_timer -= delta
	if _repath_timer <= 0.0 or _path_idx >= _path.size() or goal.distance_to(_path_goal) > 0.75:
		_repath_timer = REPATH_INTERVAL
		_path_goal = goal
		_path = NavigationServer3D.map_get_path(map, global_position, goal, true)
		_path_idx = 1
	while _path_idx < _path.size() and _flat_dist(_path[_path_idx]) < WAYPOINT_REACHED:
		_path_idx += 1
	if _path_idx >= _path.size():
		return straight
	var to_next := _path[_path_idx] - global_position
	to_next.y = 0.0
	return to_next.normalized()

# --- Crowding ------------------------------------------------------------------
# Enemies may overlap each other a lot (up to CROWD_MAX_OVERLAP of their
# combined width) but never stack on the same spot. Once they're attacking,
# they also drift gently AROUND their target, away from each other, so a pack
# ends up hitting you from a few more sides.

## How much two enemies may overlap (0.85 = 85% of their combined radii).
const CROWD_MAX_OVERLAP := 0.85
## Push strength when closer than that (m/s per metre of violation).
const CROWD_HARD_PUSH := 8.0
## Gentle spreading speed while attacking (m/s at full overlap).
const CROWD_SPREAD_SPEED := 0.6

func _crowd_velocity(around: Node3D) -> Vector3:
	var push := Vector3.ZERO
	var spread := Vector3.ZERO
	var r := Combat.hitbox_radius(self)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not (e is Node3D) or not e.is_alive():
			continue
		var d: Vector3 = global_position - e.global_position
		d.y = 0.0
		var sum := r + Combat.hitbox_radius(e)
		var dist := d.length()
		if dist >= sum:
			continue
		if dist < 0.001:   # exactly on top of each other: split in a stable direction
			var a := float(get_instance_id() % 628) / 100.0
			d = Vector3(cos(a), 0.0, sin(a))
			dist = 0.001
		var away := d / dist
		var min_dist := sum * (1.0 - CROWD_MAX_OVERLAP)
		if dist < min_dist:
			push += away * (min_dist - dist) * CROWD_HARD_PUSH
		if around:
			spread += away * (1.0 - dist / sum)
	if around and spread.length() > 0.001:
		# Only sideways around the target, so spreading never pulls it out of range.
		var radial := global_position - around.global_position
		radial.y = 0.0
		if radial.length() > 0.001:
			radial = radial.normalized()
			spread -= radial * spread.dot(radial)
		push += spread.limit_length(1.0) * CROWD_SPREAD_SPEED
	return push.limit_length(_current_speed() + 1.0)

func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()

func _dist_to(n: Node3D) -> float:
	return _flat_dist(n.global_position)

func _can_see(n: Node3D) -> bool:
	return Combat.line_of_sight(get_world_3d(), Combat.sight_point(self), Combat.sight_point(n))

# Turn toward a horizontal direction. Enemies face -Z (models are rotated to match).
func _face(dir: Vector3, delta: float) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	var yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, yaw, turn_speed * delta)

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and _health_bar:
		_health_bar.global_basis = cam.global_basis

# --- Targeting -------------------------------------------------------------------

func set_targeted(on: bool) -> void:
	for m in _meshes:
		m.material_overlay = _outline_mat if on else null

func is_alive() -> bool:
	return state != State.DEAD

# --- Health ---------------------------------------------------------------------
# Called by CombatSystem with FINAL damage (after crit/armor/etc.).

func take_damage(amount: int) -> void:
	if state == State.DEAD or _replica():
		return
	if state == State.RETURN:
		get_node("/root/CombatSystem").float_text(self, "Evade", Color(0.8, 0.8, 0.8), false)
		return
	health = max(health - amount, 0)
	_update_health_bar()
	_bus().enemy_damaged.emit(self, amount)
	if health == 0:
		_die()

func receive_heal(amount: int) -> void:
	if state != State.DEAD and not _replica():
		health = mini(health + amount, max_health)
		_update_health_bar()

func _die() -> void:
	if _net and _net.is_host():
		_net.enemy_died(self)   # everyone plays the death (and rolls their own loot)
	change_state(State.DEAD)
	remove_from_group("enemies")
	set_targeted(false)
	status.clear()
	threat.clear()
	for c in get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", true)
	died.emit()
	_bus().enemy_died.emit(self)
	_drop_loot()
	var t := create_tween()
	var death_len := play_once("death")
	if death_len > 0.0:
		# Has a death animation: play it, then sink away.
		if _health_bar:
			_health_bar.visible = false
		if _status_label:
			_status_label.visible = false
		t.tween_interval(death_len + 1.0)
		t.tween_property(self, "position:y", position.y - 1.5, 1.0)
	else:
		t.tween_property(self, "scale", Vector3(1, 0.01, 1), 0.5).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)

# --- Multiplayer replica (client side) ----------------------------------------------

## Host snapshot for this enemy.
func net_apply(pos: Vector3, yaw: float, hp: int, _mhp: int, st: int, moving: bool, threat_member: int) -> void:
	if state == State.DEAD:
		return
	_net_has = true
	_net_pos = pos
	_net_yaw = yaw
	_net_moving = moving
	_net_threat = threat_member
	if hp != health:
		health = hp
		_update_health_bar()
	if st != int(state) and st != int(State.DEAD):
		state = st as State

func _net_follow(delta: float) -> void:
	if not _net_has:
		return
	if global_position.distance_to(_net_pos) > 4.0:
		global_position = _net_pos
	else:
		global_position = global_position.lerp(_net_pos, clampf(delta * 10.0, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, _net_yaw, clampf(delta * 10.0, 0.0, 1.0))
	_play("walk" if _net_moving else "idle")

## Host's status effects on this enemy (Chilled, Frozen, Poisoned...). Mirrored
## so the status label shows them - but they never tick here (the host deals
## the DoT damage) until this machine becomes the host.
func net_apply_status(rows: Array) -> void:
	if status == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var keep := {}
	var changed := false
	for r in rows:
		var res: Resource = _effect_res(str(r[0]))
		if res == null:
			continue
		var src: Node = _net.body_of(int(r[3])) if _net and int(r[3]) != 0 else null
		var id := STATUS_CONTAINER.key_for(res, src)   # per caster for DoTs, like on the host
		keep[id] = true
		if not status.effects.has(id):
			status.effects[id] = {"res": res, "stacks": int(r[1]), "expires": now + float(r[2]),
				"next_tick": INF, "source": src}
			changed = true
		else:
			var fx: Dictionary = status.effects[id]
			changed = changed or int(fx["stacks"]) != int(r[1])
			fx["stacks"] = int(r[1])
			fx["expires"] = now + float(r[2])
			fx["next_tick"] = INF
			fx["source"] = src
	for id in status.effects.keys():
		if not keep.has(id):
			status.effects.erase(id)
			changed = true
	if changed:
		status.changed.emit()
	if not status.effects.is_empty():
		status.set_process(true)   # mirrored effects still need to expire here

# Effect resources named in host snapshots (10x/s), looked up once per path.
static var _effect_cache := {}

static func _effect_res(path: String) -> Resource:
	if not _effect_cache.has(path):
		_effect_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _effect_cache[path]

## This machine just became the host: mirrored effects start ticking for real.
func net_take_over() -> void:
	if status == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for fx in status.effects.values():
		fx["next_tick"] = now + maxf(float(fx["res"].tick_interval), 0.05)

## Host says it died.
func net_die() -> void:
	if state != State.DEAD:
		_die()

## Host doesn't have this enemy (killed before we arrived): remove, no loot.
func net_remove() -> void:
	remove_from_group("enemies")
	queue_free()

# --- Loot ------------------------------------------------------------------------

func _drop_loot() -> void:
	var drops: Array[String] = []
	if loot and loot.has_method("roll"):
		var pool: Array = []
		var pd := get_node_or_null("/root/PlayerData")
		if loot.use_unlocked_pool and pd:
			pool = Runes.unlocked_pool(pd.level, Array(pd.known_runes))
		drops = loot.roll(level, null, pool)
	else:
		# Legacy inline table: [{"id": "sword", "chance": 0.15}, ...]
		for entry in loot_table:
			if randf() < float(entry.get("chance", 0.0)):
				var item: String = entry["id"]
				if randf() < loot_rune_chance:
					item = Items.with_rune(item, Runes.ALL.pick_random())
				drops.append(ItemDB.from_legacy(item))
	var feet := Vector3(global_position.x, Combat.feet_y(self), global_position.z)
	for i in drops.size():
		var drop := Node3D.new()
		drop.set_script(LOOT_DROP)
		drop.item_id = drops[i]
		get_tree().current_scene.add_child(drop)
		var offset := Vector3.ZERO
		if drops.size() > 1:
			var a := TAU * i / drops.size()
			offset = Vector3(cos(a), 0, sin(a)) * 0.7
		drop.global_position = feet + offset
		_bus().loot_dropped.emit(drops[i], drop.global_position)

# --- Health bar + status label -----------------------------------------------------

func _build_health_bar() -> void:
	_health_bar = Node3D.new()
	_health_bar.name = "HealthBar"
	_health_bar.position = Vector3(0, health_bar_height, 0)
	add_child(_health_bar)

	if _shared_bar_mats.is_empty():
		_shared_bar_mats = [_flat_mat(Color(0.05, 0.05, 0.05), 10),
			_flat_mat(Color(0.85, 0.12, 0.12), 11), _flat_mat(Color(0.25, 0.25, 0.25), 11)]
	var bg_mat := _shared_bar_mats[0]
	_seg_full = _shared_bar_mats[1]
	_seg_empty = _shared_bar_mats[2]

	# Fixed overall width; segments (and gaps) get narrower as max health grows.
	var total_w := 1.0 if rank == "normal" else 1.6
	var gap := minf(0.04, total_w * 0.25 / (max_health + 1))
	var seg_w := (total_w - (max_health + 1) * gap) / max_health

	var bg := MeshInstance3D.new()
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(total_w, 0.14)
	bg.mesh = bg_mesh
	bg.material_override = bg_mat
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_health_bar.add_child(bg)

	for i in max_health:
		var seg := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(seg_w, 0.08)
		seg.mesh = q
		seg.position = Vector3(-total_w / 2.0 + gap + seg_w / 2.0 + i * (seg_w + gap), 0, 0.001)
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_health_bar.add_child(seg)
		_segments.append(seg)
	_update_health_bar()

	_status_label = Label3D.new()
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.no_depth_test = true
	_status_label.font_size = 32
	_status_label.pixel_size = 0.006
	_status_label.outline_size = 8
	_status_label.position = Vector3(0, health_bar_height + 0.17, 0)
	add_child(_status_label)

	if show_name and display_name != "":
		var n := Label3D.new()
		n.text = display_name
		n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		n.no_depth_test = true
		n.font_size = 40 if rank == "boss" else 32
		n.pixel_size = 0.006
		n.outline_size = 8
		n.modulate = Color(1.0, 0.35, 0.3) if rank == "boss" else Color(1.0, 0.75, 0.3)
		n.position = Vector3(0, health_bar_height + 0.36, 0)
		add_child(n)
		_status_label.position.y += 0.02   # status text sits between bar and name

func _update_health_bar() -> void:
	for i in _segments.size():
		_segments[i].material_override = _seg_full if i < health else _seg_empty

func _update_status_label() -> void:
	if _status_label == null:
		return
	var names: Array[String] = []
	var counts := {}   # the same DoT from several players shows once, with a count
	var col := Color.WHITE
	for e in status.list():
		var n := str(e["name"])
		if not counts.has(n):
			names.append(n)
		counts[n] = int(counts.get(n, 0)) + 1
		col = e["color"]
	for i in names.size():
		if int(counts[names[i]]) > 1:
			names[i] = "%s (%d)" % [names[i], int(counts[names[i]])]
	_status_label.text = ", ".join(names)
	_status_label.modulate = col

func _flat_mat(c: Color, priority: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = true
	m.render_priority = priority
	return m
