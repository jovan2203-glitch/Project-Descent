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
const CrowdGrid = preload("res://scripts/core/crowd_grid.gd")
const STATUS_CONTAINER = preload("res://scripts/core/status_container.gd")
const BREACH_FX = preload("res://scripts/breach_fx.gd")
const DamageInfo = preload("res://scripts/core/damage_info.gd")
const Items = preload("res://scripts/items.gd")
const Runes = preload("res://scripts/runes.gd")
const LOOT_DROP = preload("res://scripts/loot_drop.gd")
const ItemDB = preload("res://scripts/core/item_db.gd")

## Health in "hits" (x Stats.enemy_health_unit(level) when the enemy spawns).
@export var max_health: int = 3
@export var move_speed: float = 2.2
@export var aggro_radius: float = 5.0
## How far its target may get from the enemy (measured from where the enemy IS,
## not from its spawn) before it drops that target. It then turns on the next
## player on its threat table, or evades home if there's nobody left.
@export var leash_radius: float = 28.0
## Damage per swing as a coefficient (x Stats.enemy_hit(level) = 10% of a
## same-level player's base health per 1.0).
@export var contact_damage: float = 1.0
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

@export_group("Ranged")
## "" = melee (swings in reach). "arrow" or "bolt" = shoots that projectile
## from up to attack_range away (needs line of sight), e.g. goblin archers and
## wizards. Damage is still contact_damage (as a coefficient).
@export var projectile: String = ""
## Seconds of casting before a ranged attack fires (0 = instant). The shot is
## lost if its target runs out of range or line of sight meanwhile.
@export var attack_windup: float = 0.0
@export var projectile_color: Color = Color(1.0, 0.45, 0.15)
@export var projectile_damage_type: String = "physical"
@export var projectile_tags: PackedStringArray = PackedStringArray(["Physical", "Ranged"])

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

# --- Dungeon role (scripts/dungeon/roles.gd sets these) ---------------------------
var role := ""
## Placed when the dungeon is built (a trash pack), not an add that joins a fight later.
## 5 Player: placed trash is tougher than adds (balance.gd PARTY_HEALTH_MULT).
var placed_pack := false
## Defender: share of damage blocked from hits coming from the front (0..1).
var frontal_block := 0.0
## Archer: backs away when a target gets this close (0 = never).
var kite_distance := 0.0
## Name of this enemy's own spell (a Support's Mend / Summoner's Summon
## borrow cast_name for their cast; the normal bolts switch back to this).
var base_cast_name := ""
## Explodes when it dies like a Volatile elite (dungeon modifier "Volatile").
var death_explode := false
var _kite_until := 0.0
var _kite_ready_at := 0.0
var _frenzied := false
const KITE_TIME := 1.1
const KITE_COOLDOWN := 4.0
const FRENZY_AT := 0.3          # "Frenzy" modifier: enrage below this share of health
const FRENZY_DAMAGE := 1.3
const FRENZY_ATTACK := 1.3

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
	Combat.setup_walker(self)   # sticks to ramps, same speed up and down them
	# Enemies don't physically block each other (they're only on the enemy
	# layer, not the world layer 1); crowding is handled softly by _crowd_velocity().
	collision_layer &= ~1
	collision_layer |= 4
	if not _stats_scaled:
		# Placed straight into a scene (no spawner): scale for its level now.
		_stats_scaled = true
		max_health = maxi(int(round(max_health * Stats.enemy_health_unit(level))), 1)
	# 5 Player difficulty: tougher enemies (training dummies always run on Singleplayer).
	max_health = maxi(int(round(max_health * _gm_mult("enemy_health_mult", [rank == "boss", placed_pack]))), 1)
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
	status.changed.connect(_update_health_bar)
	status.changed.connect(_sync_breach_fx)

	_bus().player_died.connect(_on_player_died)
	_setup_animations()
	_play("idle")
	_build_health_bar()

func _bus() -> Node:
	return get_node("/root/SignalBus")

## My debuffs changed. A Breach (the Shadow caster's) shows itself as a hole
## under me with hands clawing out of it: scripts/breach_fx.gd makes that from
## the debuffs, on every machine. It removes itself when the Breach is gone.
func _sync_breach_fx() -> void:
	BREACH_FX.sync(self)

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

const ELITE_DAMAGE_MULT := 2.0
const BOSS_DAMAGE_MULT := 3.0
const Stats = preload("res://scripts/core/stats.gd")
const ELITE_LOOT := "res://data/loot/elite.tres"
const BOSS_LOOT := "res://data/loot/boss.tres"

## Scale for rank and level. Call BEFORE adding the enemy to the tree.
## Health and damage become real numbers here: max_health (hits) x
## Stats.enemy_health_unit(level), contact damage x rank (the level part is
## applied per swing through damage_unit()).
var _stats_scaled := false

func apply_rank(new_rank: String, lvl: int) -> void:
	var mult := Stats.enemy_health_unit(lvl)
	_stats_scaled = true
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
			contact_damage = base_dmg * ELITE_DAMAGE_MULT
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
			contact_damage = base_dmg * BOSS_DAMAGE_MULT
			attack_cooldown *= 1.4
			armor += 2.0
			aggro_radius *= 1.8
			leash_radius = maxf(leash_radius, 80.0)
			xp_reward = int(round(base_xp * (10.0 + 2.0 * lvl)))
			display_name = boss_name if boss_name != "" else base_name + " Lord"
			show_name = true
			loot = boss_loot if boss_loot else load(BOSS_LOOT)
			_add_glow(boss_glow, 2.5)
		_:
			max_health = maxi(int(round(base_hp * mult)), 1)
			xp_reward = int(round(base_xp * (0.8 + 0.2 * lvl)))
			if not normal_drops_loot:
				loot = null
				loot_table = []

## Elite trait (elite_traits.gd): "" for none. Rolled by the spawner for elites.
var elite_trait := ""
const ELITE_TRAITS = preload("res://scripts/core/elite_traits.gd")
const EB = preload("res://scripts/balance.gd")

## Give this elite a trait. Call AFTER apply_rank and BEFORE adding it to the tree.
func apply_elite_trait(t: String) -> void:
	if not ELITE_TRAITS.TRAITS.has(t):
		return
	elite_trait = t
	display_name = "%s %s" % [ELITE_TRAITS.title(t), display_name]
	match t:
		"hasted":
			move_speed *= 1.0 + EB.ELITE_HASTE_MOVE / 100.0
			attack_cooldown /= 1.0 + EB.ELITE_HASTE_ATTACK / 100.0
			attack_windup /= 1.0 + EB.ELITE_HASTE_ATTACK / 100.0
			melee_tell /= 1.0 + EB.ELITE_HASTE_ATTACK / 100.0
		"shielded", "berserker":
			var comp := Node.new()
			comp.name = "EliteTrait"
			comp.set_script(ELITE_TRAITS)
			comp.trait_id = t
			add_child(comp)

## StatusContainer asks before applying an effect (Unstoppable ignores CC).
var _immune_text_at := 0.0
## Boss mechanics (host / solo): immune while its guards live.
var mechanic_immune := false

func resists_effect(res: Resource) -> bool:
	if elite_trait == "" or not ELITE_TRAITS.resists(elite_trait, res):
		return false
	if _now_s() >= _immune_text_at:
		_immune_text_at = _now_s() + 1.0
		_cs().float_text(self, "Immune", ELITE_TRAITS.color(elite_trait), false)
	return true

## Vampiric: heal for part of an attack's damage (host / solo only).
func _vampiric_heal(dmg: float) -> void:
	if elite_trait != "vampiric" or _replica() or dmg <= 0.0 or state == State.DEAD:
		return
	var amount := int(round(dmg * EB.ELITE_VAMPIRIC_PCT / 100.0))
	if amount > 0 and health < max_health:
		receive_heal(amount)
		_cs().float_text(self, "+%d" % amount, Color(0.85, 0.25, 0.4), false)

## Rough size of a hit of `coef` from this enemy (for Vampiric when the hit
## lands on another machine and we never see the real number).
func _hit_estimate(coef: float) -> float:
	return coef * damage_unit()

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

## Real damage of a 1.0 coefficient for this enemy (CombatSystem).
func damage_unit() -> float:
	return Stats.enemy_hit(level) * _gm_mult("enemy_damage_mult", [rank == "boss"]) * (FRENZY_DAMAGE if _frenzied else 1.0)

## Difficulty multiplier from GameManager (1.0 in Singleplayer / without it).
func _gm_mult(fn: String, args: Array = []) -> float:
	var gm := get_node_or_null("/root/GameManager")
	return float(gm.callv(fn, args)) if gm and gm.has_method(fn) else 1.0

func combat_level() -> int:
	return level

func get_stat(stat: String) -> float:
	var v := 0.0
	match stat:
		"armor": v = armor * Stats.flat_unit(level)   # armor is in flat units
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
	if state == State.DEAD or (_dormant and state == State.IDLE):
		return
	if _replica():
		_net_follow(delta)
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	_attack_timer = max(_attack_timer - delta, 0.0)

	# busy_until: boss abilities hold the boss in place while they wind up.
	var stunned: bool = status.has_flag("stun") or _now_s() < busy_until
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
			# Roaming packs (open caverns) wander around their spot until they see you.
			if state == State.IDLE and roam_radius > 0.0 and not stunned and not rooted:
				var rdir := _roam(delta)
				if rdir != Vector3.ZERO:
					velocity.x = rdir.x * _current_speed() * 0.45
					velocity.z = rdir.z * _current_speed() * 0.45
					moving = true
			# Standing still on the ground: nothing to simulate this frame.
			if state == State.IDLE and is_on_floor() and not moving:
				velocity = Vector3.ZERO
				_play("idle")
				return
		State.CHASE:
			var tgt := _leashed_target()
			if tgt == null:
				if not _waiting_on_forgotten():
					change_state(State.RETURN)   # (Play Dead: nobody else to fight, so it waits)
			elif _in_reach(tgt):
				change_state(State.ATTACK)
			elif not stunned and not rooted:
				var dir := _path_direction(tgt.global_position, delta)
				velocity.x = dir.x * _current_speed()
				velocity.z = dir.z * _current_speed()
				moving = true
		State.ATTACK:
			var tgt2 := _leashed_target()
			if tgt2 == null:
				if not _waiting_on_forgotten():
					change_state(State.RETURN)
			elif not _still_in_reach(tgt2):
				change_state(State.CHASE)
			elif _kiting(tgt2, stunned, rooted):
				var away := global_position - tgt2.global_position
				away.y = 0.0
				var kdir := _path_direction(global_position + away.normalized() * 3.0, delta)
				velocity.x = kdir.x * _current_speed()
				velocity.z = kdir.z * _current_speed()
				moving = true
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
	if _swing_at > 0.0:
		_tick_swing(stunned)

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

## Roaming (dungeon layouts with roaming packs): wander near the spawn point.
var roam_radius := 0.0
var _roam_goal := Vector3.INF
var _roam_wait := 0.0

func _roam(delta: float) -> Vector3:
	if _roam_goal == Vector3.INF:
		_roam_wait -= delta
		if _roam_wait > 0.0:
			return Vector3.ZERO
		var a := randf() * TAU
		_roam_goal = spawn_position + Vector3(cos(a), 0, sin(a)) * randf_range(1.5, roam_radius)
	if _flat_dist(_roam_goal) < 0.6:
		_roam_goal = Vector3.INF
		_roam_wait = randf_range(2.0, 5.0)
		return Vector3.ZERO
	return _path_direction(_roam_goal, delta)

## Archers step back when you close in (a short burst, then they shoot again).
func _kiting(tgt: Node3D, stunned: bool, rooted: bool) -> bool:
	if kite_distance <= 0.0 or stunned or rooted or is_casting():
		return false
	var now := _now_s()
	if now < _kite_until:
		return true
	if now >= _kite_ready_at and _dist_to(tgt) < kite_distance:
		_kite_until = now + KITE_TIME
		_kite_ready_at = now + KITE_COOLDOWN
		return true
	return false

## CombatSystem: % damage change for a hit on this enemy (Defender's shield
## blocks most of a hit that comes from the front; flank it).
## Boss mechanics: immune while its guards live (no damage at all, whatever else
## boosts the hit).
func incoming_damage_pct(info: RefCounted) -> float:
	if mechanic_immune:
		if _now_s() >= _immune_text_at:
			_immune_text_at = _now_s() + 1.0
			_cs().float_text(self, "Immune", Color(0.95, 0.95, 1.0), false)
		return -100000.0
	if frontal_block <= 0.0 or info.is_dot or info.source == null or not is_instance_valid(info.source) \
			or not (info.source is Node3D):
		return 0.0
	var to_src: Vector3 = (info.source as Node3D).global_position - global_position
	to_src.y = 0.0
	if to_src.length() < 0.01:
		return 0.0
	var fwd := -global_basis.z   # enemies face -Z
	fwd.y = 0.0
	if fwd.normalized().dot(to_src.normalized()) > 0.35:
		return -frontal_block * 100.0
	return 0.0

## "Frenzy" dungeon modifier: enrage once below 30% health (host / solo).
func _check_frenzy() -> void:
	if _frenzied or health <= 0 or float(health) > float(max_health) * FRENZY_AT:
		return
	var gm := get_node_or_null("/root/GameManager")
	if gm == null or not gm.has_method("has_modifier") or not gm.has_modifier("frenzy"):
		return
	_frenzied = true
	attack_cooldown /= FRENZY_ATTACK
	attack_windup /= FRENZY_ATTACK
	melee_tell /= FRENZY_ATTACK
	move_speed *= 1.15
	BOSS_ABILITIES.apply_enrage_look(self)
	_cs().float_text(self, "Frenzy!", Color(1.0, 0.3, 0.2), false)
	if _net and _net.is_host():
		_net.enemy_fx(self, "enrage", null, {})

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
	if projectile != "":
		_ranged_attack(_pick_ranged_target(tgt))
		return
	if melee_tell > 0.0:
		if _swing_at <= 0.0:
			_start_swing(tgt)
		return
	_land_melee(tgt)

# --- Melee tells ------------------------------------------------------------------------
# A melee hit shows a short, bright tell (MeleeTellFx) before it lands, melee_tell
# seconds later: same hit rate (the attack timer starts with the tell). Not a cast, so
# interrupts don't see it; a stun or knockdown cancels it, and so does the target
# getting away. The host tells the party ("swing"), so the target's machine knows
# a hit is coming (the Brawler's Catch: melee_tell_at()).

const MELEE_TELL_FX = preload("res://scripts/melee_tell_fx.gd")
var melee_tell := EB.MELEE_TELL_TIME
var _swing_tgt: Node3D = null
var _swing_at := 0.0       # host / solo: when the hit lands (0 = no swing)
var _tell_tgt: Node3D = null
var _tell_until := 0.0     # every machine: the tell shows until then

## Is this enemy showing a melee tell at `body` right now?
func melee_tell_at(body: Node) -> bool:
	return body != null and _tell_tgt == body and _now_s() < _tell_until

## When the tell aimed at `body` ends (0 if there is none).
func melee_tell_end(body: Node) -> float:
	return _tell_until if melee_tell_at(body) else 0.0

func _start_swing(tgt: Node3D) -> void:
	_swing_tgt = tgt
	_swing_at = _now_s() + melee_tell
	_show_tell(tgt, melee_tell)
	if _net and _net.is_host():
		_net.enemy_fx(self, "swing", tgt, {"d": melee_tell})

func _tick_swing(stunned: bool) -> void:
	var tgt := _swing_tgt
	if stunned or state != State.ATTACK or not is_instance_valid(tgt) or _is_dead(tgt):
		_cancel_swing()
		return
	if _now_s() < _swing_at:
		return
	_swing_tgt = null
	_swing_at = 0.0
	if _dist_to(tgt) <= attack_range * 1.25:
		_land_melee(tgt)

func _cancel_swing() -> void:
	_swing_tgt = null
	_swing_at = 0.0
	_tell_until = 0.0
	var fx := get_node_or_null(MELEE_TELL_FX.NODE_NAME)
	if fx:
		fx.stop()

func _show_tell(tgt: Node3D, d: float) -> void:
	_tell_tgt = tgt
	_tell_until = _now_s() + d
	var fx := get_node_or_null(MELEE_TELL_FX.NODE_NAME)
	if fx == null:
		fx = MELEE_TELL_FX.new()
		fx.name = MELEE_TELL_FX.NODE_NAME
		fx.position = Vector3(0, health_bar_height * 0.6, 0)
		add_child(fx)
	fx.play(d)

func _land_melee(tgt: Node3D) -> void:
	play_once("attack")
	if _hits_decoy(tgt):
		return
	if tgt.is_in_group("remote_player"):
		# Another player's character: they take the hit on their own machine.
		if _net:
			_net.send_enemy_hit(self, tgt, contact_damage, PackedStringArray(["Physical", "Melee"]), "physical")
		_vampiric_heal(_hit_estimate(contact_damage))
		return
	var info := DamageInfo.make(self, tgt, contact_damage, "enemy_melee")
	info.tags = PackedStringArray(["Physical", "Melee"])
	_cs().deal(info)
	_vampiric_heal(float(info.amount) if not info.blocked else 0.0)

# --- Ranged attacks (archers, casters) ---------------------------------------------------
# Melee enemies attack in reach; ranged ones (projectile != "") from up to
# attack_range away while they can see their target, and chase otherwise.

const ARROW = preload("res://scripts/arrow.gd")
const BOLT = preload("res://scripts/frost_bolt.gd")
const RANGED_LOS_INTERVAL := 0.25
var _los_timer := 0.0
var _los_ok := true

func _in_reach(tgt: Node3D) -> bool:
	if _dist_to(tgt) > attack_range:
		return false
	return projectile == "" or _sees_target(tgt)

func _still_in_reach(tgt: Node3D) -> bool:
	if _dist_to(tgt) > attack_range * 1.15:
		return false
	return projectile == "" or _sees_target(tgt)

## Line of sight to the target, re-checked a few times per second (raycast).
func _sees_target(tgt: Node3D) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now >= _los_timer:
		_los_timer = now + RANGED_LOS_INTERVAL
		_los_ok = _can_see(tgt)
	return _los_ok

var _cast_light: OmniLight3D
var _cast_tween: Tween
var _cast_label: Label3D
## Seconds of casting lockout left after an interrupt (Counterspell, Kick, Pummel).
var _silenced_until := 0.0
var busy_until := 0.0        # boss abilities: stands still, no auto-attacks until then
## Berserk (5 Player boss timer, boss_kit.gd): when it hits (_now_s() time, 0 = no
## timer running), its full length, and whether it has hit. Set on every machine,
## for the Boss Timer (scripts/ui/hud/boss_timer.gd).
var berserk_at := 0.0
var berserk_total := 0.0
var berserk_on := false

## Starts (`left` > 0), stops (`left` <= 0 and not `on`) or sets off the Berserk timer.
func set_berserk(left: float, total: float, on: bool) -> void:
	berserk_on = on
	berserk_total = total
	berserk_at = _now_s() + left if left > 0.0 or on else 0.0
## Name shown above the enemy while it casts (so players know what to interrupt).
@export var cast_name: String = ""

func _now_s() -> float:
	return Time.get_ticks_msec() / 1000.0

## Mid-cast right now (can be interrupted)?
func is_casting() -> bool:
	return _cast_tween != null and _cast_tween.is_valid() and _cast_tween.is_running()

func is_silenced() -> bool:
	return _now_s() < _silenced_until

## 5 Player difficulty: archers and casters sometimes ignore the tank and shoot
## someone else in range they can see (no threat change), so the healer has
## work beyond the tank. Solo there is nobody else, so nothing changes.
func _pick_ranged_target(tgt: Node3D) -> Node3D:
	if randf() >= _gm_mult("off_target_chance"):
		return tgt
	var bodies: Array = _net.party_bodies() if _net else get_tree().get_nodes_in_group("player")
	var options: Array = []
	for b in bodies:
		if b != tgt and is_instance_valid(b) and b.is_alive() and _dist_to(b) <= attack_range and _can_see(b):
			options.append(b)
	return options.pick_random() if not options.is_empty() else tgt

func _ranged_attack(tgt: Node3D) -> void:
	if attack_windup <= 0.0:
		play_once("attack")
		_shoot(tgt)
		return
	if is_silenced():
		_attack_timer = maxf(_silenced_until - _now_s(), 0.1)   # locked out: try again when it ends
		return
	if base_cast_name != "":
		cast_name = base_cast_name
	# Cast: a glow in the hands and the spell name overhead, then the bolt -
	# unless the target got away or someone interrupted it.
	_show_cast(true, attack_windup)
	if _net and _net.is_host():
		_net.enemy_fx(self, "cast", tgt, {"d": attack_windup})
	_cast_tween = create_tween()
	_cast_tween.tween_interval(attack_windup)
	_cast_tween.tween_callback(func():
		_cast_tween = null
		_show_cast(false)
		if state != State.ATTACK or status.has_flag("stun") or not is_instance_valid(tgt) or _is_dead(tgt):
			return
		if _dist_to(tgt) > attack_range * 1.25 or not _can_see(tgt):
			return
		play_once("attack")
		_shoot(tgt))

## Interrupt the current cast (host / solo). Casting is locked out for
## `lockout` seconds. Returns true if a cast was actually stopped. `tells`: with
## no cast, knock aside the melee hit it is winding up instead (Stone Throw).
func interrupt(_source: Node, lockout: float, tells := false) -> bool:
	if _replica() or state == State.DEAD:
		return false
	if not is_casting():
		if tells and _swing_at > 0.0:
			_cancel_swing()
			show_knocked_aside()
			if _net and _net.is_host():
				_net.enemy_fx(self, "knocked_aside", null, {})
			return true
		return false
	_cast_tween.kill()
	_cast_tween = null
	busy_until = 0.0
	_silenced_until = _now_s() + lockout
	_attack_timer = maxf(_attack_timer, lockout)
	show_interrupted()
	if _net and _net.is_host():
		_net.enemy_fx(self, "interrupted", null, {})
	return true

## "Interrupted" feedback (also played on party members' machines).
func show_interrupted() -> void:
	_show_cast(false)
	_cs().float_text(self, "Interrupted!", Color(0.7, 0.85, 1.0), true)

## A melee hit knocked aside before it landed (also on party members' machines).
func show_knocked_aside() -> void:
	_tell_until = 0.0
	var fx := get_node_or_null(MELEE_TELL_FX.NODE_NAME)
	if fx:
		fx.stop()
	_cs().float_text(self, "Knocked aside!", Color(0.7, 0.85, 1.0), true)

## Cast bar: when the current cast started and how long it takes.
var _cast_start := 0.0
var _cast_len := 0.0
var _cast_bar: Node3D
var _cast_bar_fill: MeshInstance3D
static var _cast_bar_mat: StandardMaterial3D

## 0..1 through the current cast, or -1 when not casting (HUD target frame).
func cast_progress() -> float:
	if _cast_label == null or not _cast_label.visible or _cast_len <= 0.0:
		return -1.0
	return clampf((_now_s() - _cast_start) / _cast_len, 0.0, 1.0)

func cast_display_name() -> String:
	return cast_name if cast_name != "" else "a spell"

## Seconds left on the current cast (0 when not casting).
func cast_time_left() -> float:
	return maxf(_cast_start + _cast_len - _now_s(), 0.0) if cast_progress() >= 0.0 else 0.0

## A thin bar above the health bar that fills while the enemy casts.
func _build_cast_bar() -> void:
	if _health_bar == null:
		return
	if _cast_bar_mat == null:
		_cast_bar_mat = _flat_mat(Color(1.0, 0.72, 0.15), 12)
	_cast_bar = Node3D.new()
	_cast_bar.name = "CastBar"
	_cast_bar.position = Vector3(0, 0.18, 0)
	_health_bar.add_child(_cast_bar)
	var bg := MeshInstance3D.new()
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(_bar_w, 0.12)
	bg.mesh = bg_mesh
	bg.material_override = _shared_bar_mats[0] if not _shared_bar_mats.is_empty() else _flat_mat(Color(0.05, 0.05, 0.05), 10)
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cast_bar.add_child(bg)
	_cast_bar_fill = MeshInstance3D.new()
	var fill_mesh := QuadMesh.new()
	fill_mesh.size = Vector2(_bar_w - BAR_PAD * 2.0, 0.08)
	_cast_bar_fill.mesh = fill_mesh
	_cast_bar_fill.material_override = _cast_bar_mat
	_cast_bar_fill.position.z = 0.001
	_cast_bar_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cast_bar.add_child(_cast_bar_fill)
	# Bright spark riding the fill's leading edge (WoW cast bar).
	if _cast_spark_mat == null:
		_cast_spark_mat = _flat_mat(Color(1.0, 0.97, 0.85), 13)
		_cast_ok_mat = _flat_mat(Color(1.0, 1.0, 1.0), 12)
		_cast_fail_mat = _flat_mat(Color(0.95, 0.2, 0.15), 12)
	_cast_spark = MeshInstance3D.new()
	var spark_mesh := QuadMesh.new()
	spark_mesh.size = Vector2(0.035, 0.13)
	_cast_spark.mesh = spark_mesh
	_cast_spark.material_override = _cast_spark_mat
	_cast_spark.position.z = 0.002
	_cast_spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cast_bar.add_child(_cast_spark)
	_cast_bar.visible = false

var _cast_spark: MeshInstance3D
static var _cast_spark_mat: StandardMaterial3D
static var _cast_ok_mat: StandardMaterial3D
static var _cast_fail_mat: StandardMaterial3D
var _cast_ending := false   # showing the end flash (white = cast went off, red = interrupted)

## The cast ended: flash the bar white (it went off) or red (interrupted) for a moment.
func _end_cast_bar(ok: bool) -> void:
	if _cast_bar == null or not _cast_bar.visible:
		return
	_cast_ending = true
	_cast_bar_fill.scale.x = 1.0
	_cast_bar_fill.position.x = 0.0
	_cast_bar_fill.material_override = _cast_ok_mat if ok else _cast_fail_mat
	_cast_spark.visible = false
	var hold := 0.25 if ok else 0.5
	get_tree().create_timer(hold).timeout.connect(func():
		if not is_instance_valid(self) or not _cast_ending:
			return
		_cast_ending = false
		_cast_bar.visible = false
		_cast_bar_fill.material_override = _cast_bar_mat)

func _update_cast_bar() -> void:
	if _cast_bar == null or not _cast_bar.visible or _cast_ending:
		return
	var p := cast_progress()
	if p < 0.0:
		_cast_bar.visible = false
		return
	var inner := _bar_w - BAR_PAD * 2.0
	_cast_bar_fill.scale.x = maxf(p, 0.001)
	_cast_bar_fill.position.x = -inner / 2.0 + inner * p / 2.0
	if _cast_spark:
		_cast_spark.visible = true
		_cast_spark.position.x = -inner / 2.0 + inner * p

func _show_cast(on: bool, duration: float = 0.0) -> void:
	_show_cast_glow(on)
	if _cast_bar == null:
		_build_cast_bar()
	if on:
		_cast_start = _now_s()
		_cast_len = duration
	if _cast_bar:
		if on:
			_cast_ending = false
			_cast_bar_fill.material_override = _cast_bar_mat
			_cast_bar.visible = true
			_health_bar.visible = true   # its parent: shown while casting even out of a fight
			_update_cast_bar()
		elif state == State.DEAD:
			_cast_ending = false
			_cast_bar.visible = false
		elif _cast_bar.visible and not _cast_ending:
			# Went off (reached the end) = white flash; stopped early = red.
			_end_cast_bar(_cast_len > 0.0 and _now_s() >= _cast_start + _cast_len - 0.1)
	if _cast_label == null:
		_cast_label = Label3D.new()
		_cast_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_cast_label.no_depth_test = true
		_cast_label.font_size = 30
		_cast_label.pixel_size = 0.006
		_cast_label.outline_size = 8
		_cast_label.modulate = projectile_color.lightened(0.35)
		_cast_label.position = Vector3(0, health_bar_height + 0.5, 0)
		add_child(_cast_label)
	_cast_label.visible = on
	if on:
		_cast_label.text = "Casting %s" % (cast_name if cast_name != "" else "a spell")
		_cast_label.set_meta("until", _now_s() + duration)

## Party member's machine: the host says this enemy did something visible.
func net_fx(kind: String, tgt: Node3D, extra: Dictionary) -> void:
	var scene := get_tree().current_scene
	match kind:
		"telegraph":
			MECHANIC_LOOK.area(scene, extra.get("at", global_position), float(extra.get("r", 3.0)), float(extra.get("d", 1.5)),
				str(extra.get("f", "avoid")), extra.get("c", Color.RED))
		"burst":
			BOSS_ABILITIES.burst(scene, extra.get("at", global_position), float(extra.get("r", 3.0)), extra.get("c", Color.RED))
		"cone":
			BOSS_KIT.cone_telegraph(scene, extra.get("at", global_position), extra.get("dir", Vector3.FORWARD),
				float(extra.get("r", 8.0)), float(extra.get("a", 70.0)), float(extra.get("d", 1.3)), extra.get("c", Color.RED))
		"line":
			BOSS_KIT.line_telegraph(scene, extra.get("at", global_position), extra.get("to", global_position),
				float(extra.get("w", 2.0)), float(extra.get("d", 1.4)), extra.get("c", Color.RED))
		"stack":
			MECHANIC_LOOK.stack(scene, extra.get("at", global_position), float(extra.get("r", 3.0)), float(extra.get("d", 3.0)), tgt)
		"spread":
			MECHANIC_LOOK.spread(scene, tgt, float(extra.get("r", 3.0)), float(extra.get("d", 3.0)))
		"pool":
			MECHANIC_LOOK.pool(scene, extra.get("at", global_position), float(extra.get("r", 2.5)), float(extra.get("d", 8.0)), extra.get("c"))
		"guards":
			var n := get_node_or_null("/root/Net")
			var guard_nodes: Array = []
			for id in extra.get("ids", []):
				var g: Node = n._enemy(scene, str(id)) if n else null
				if g:
					guard_nodes.append(g)
			MECHANIC_LOOK.guards(self, guard_nodes)
		"guards_end":
			MECHANIC_LOOK.guards_end(self)
		"announce":
			if scene and scene.has_method("_announce"):
				scene._announce(str(extra.get("t", "")), extra.get("c", Color(1.0, 0.45, 0.35)))
		"enrage":
			BOSS_ABILITIES.apply_enrage_look(self)
		"berserk":
			set_berserk(float(extra.get("left", 0.0)), float(extra.get("total", 0.0)), bool(extra.get("on", false)))
		"elite_shield":
			var comp := get_node_or_null("EliteTrait")
			if comp:
				comp.set_bubble(bool(extra.get("on", false)))
		"cast":
			if extra.has("n"):
				cast_name = str(extra["n"])
			var d := float(extra.get("d", attack_windup))
			_show_cast(true, d)
			get_tree().create_timer(d + 0.1).timeout.connect(func():
				if is_instance_valid(self) and _cast_label and _now_s() >= float(_cast_label.get_meta("until", 0.0)):
					_show_cast(false))
		"interrupted":
			show_interrupted()
		"knocked_aside":
			show_knocked_aside()
		"shield":
			var guard := get_node_or_null("ShieldGuard")
			if guard:
				guard.set_up(bool(extra.get("on", true)))
		"swing":
			if tgt != null:
				_show_tell(tgt, float(extra.get("d", melee_tell)))
		"arrow", "bolt":
			if tgt == null or scene == null:
				return
			_show_cast(false)
			var at: Vector3 = extra.get("at", global_position + Vector3(0, health_bar_height * 0.55, 0))
			# Visual only (no source): the host already deals the damage.
			if kind == "arrow":
				ARROW.spawn(scene, at, tgt, null, 0.0, "enemy_arrow")
			else:
				_tint_bolt(BOLT.spawn(scene, at, tgt, null, false, "enemy_bolt", 0.0))

func _show_cast_glow(on: bool) -> void:
	if _cast_light == null:
		_cast_light = OmniLight3D.new()
		_cast_light.light_color = projectile_color
		_cast_light.omni_range = 2.5
		_cast_light.position = Vector3(0, health_bar_height * 0.6, -0.35)
		add_child(_cast_light)
	_cast_light.visible = on
	if on:
		_cast_light.light_energy = 0.4
		create_tween().tween_property(_cast_light, "light_energy", 3.0, attack_windup)

func _shoot(tgt: Node3D) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var fwd := -global_basis.z
	fwd.y = 0.0
	var from := global_position + Vector3(0, health_bar_height * 0.55, 0) + fwd.normalized() * 0.4
	var id := "enemy_" + projectile
	if _net and _net.is_host():
		_net.enemy_fx(self, projectile, tgt, {"at": from})   # party members see the shot too
	match projectile:
		"arrow":
			ARROW.spawn(scene, from, tgt, self, contact_damage, id)
		_:
			_tint_bolt(BOLT.spawn(scene, from, tgt, self, false, id, contact_damage))

## Recolor a (pooled) bolt to this caster's color (Firebolt orange for goblin wizards).
func _tint_bolt(b: Node3D) -> void:
	if b.has_method("set_color"):
		b.set_color(projectile_color)   # core, light, trail and impact all match
		return
	var mat: StandardMaterial3D = b.get("_mat")
	if mat:
		mat.albedo_color = projectile_color.lightened(0.4)
		mat.emission = projectile_color
	var light: OmniLight3D = b.get("_light")
	if light:
		light.light_color = projectile_color

const BOSS_ABILITIES = preload("res://scripts/dungeon/boss_abilities.gd")
const BOSS_KIT = preload("res://scripts/dungeon/boss_kit.gd")
const MECHANIC_LOOK = preload("res://scripts/dungeon/mechanic_look.gd")

## Physical area hit (boss slams / eruptions). `amount` is the raw damage.
func deal_melee_hit(tgt: Node, amount: float, ability_id: String) -> void:
	if tgt == null or not is_instance_valid(tgt):
		return
	if _hits_decoy(tgt):
		return
	if tgt.is_in_group("remote_player"):
		if _net:
			_net.send_enemy_hit(self, tgt, amount, PackedStringArray(["Physical", "Melee"]), "physical", ability_id)
		return
	var info := DamageInfo.make(self, tgt, amount, ability_id)
	info.tags = PackedStringArray(["Physical", "Melee"])
	_cs().deal(info)

## Projectiles (arrow.gd / frost_bolt.gd) call this on their source when they land.
func deal_damage(tgt: Node, coef: float, ability_id: String, _is_proc: bool = false) -> void:
	if tgt == null or not is_instance_valid(tgt):
		return
	if _hits_decoy(tgt):
		return
	if tgt.is_in_group("remote_player"):
		if _net:
			_net.send_enemy_hit(self, tgt, coef, projectile_tags, projectile_damage_type, ability_id)
		_vampiric_heal(_hit_estimate(coef))
		return
	var info := DamageInfo.make(self, tgt, coef, ability_id)
	info.tags = projectile_tags
	info.damage_type = projectile_damage_type
	_cs().deal(info)
	_vampiric_heal(float(info.amount) if not info.blocked else 0.0)

# --- Threat ----------------------------------------------------------------------------

func add_threat(source: Node, amount: float) -> void:
	_wake()
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

## Decoys (scripts/decoy.gd) are in this group.
const DECOY_GROUP := "decoys"

## Decoy: attack `decoy` for `duration` seconds, whoever has threat. `whose` =
## the player it belongs to: an enemy that was not fighting yet joins the fight
## against them, so it has someone to turn on once the decoy is gone. An enemy
## with nobody to fight afterwards stays where it is. Host / solo only.
func distract(decoy: Node3D, duration: float, whose: Node = null) -> void:
	if _replica() or state == State.DEAD or state == State.RETURN or decoy == null or not is_instance_valid(decoy):
		return
	if whose != null and is_instance_valid(whose):
		add_threat(whose, 0.0)
	if state == State.IDLE:
		return
	_taunt_target = decoy
	_taunt_until = Time.get_ticks_msec() / 1000.0 + duration

## A blow aimed at a Decoy lands on nothing: it has no health, so nothing is
## dealt, healed or reported. True if `tgt` was one.
func _hits_decoy(tgt: Node) -> bool:
	if tgt == null or not is_instance_valid(tgt) or not tgt.is_in_group(DECOY_GROUP):
		return false
	if tgt.has_method("struck"):
		tgt.struck(self)
	return true

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
		if _is_forgotten(n):
			continue   # (Play Dead)
		if float(threat[key]["value"]) > best_v:
			best_v = float(threat[key]["value"])
			best = n
	return best

## Top threat, dropping anyone who got more than leash_radius away from the
## enemy (from its CURRENT position): it turns on the next player on its threat
## table, and only evades (null) when nobody that hit it is left in reach.
func _leashed_target() -> Node3D:
	var tgt := top_threat()
	while tgt != null and _dist_to(tgt) > leash_radius:
		threat.erase(tgt.get_instance_id())
		if _taunt_target == tgt:
			_taunt_target = null
		tgt = top_threat()
	return tgt

## Taunt: `source` jumps to the top of the threat table and is attacked for
## `duration` seconds no matter what.
func taunt(source: Node, duration: float) -> void:
	if _replica() or state == State.DEAD or state == State.RETURN:
		return
	add_threat(source, 0.0)
	var key := source.get_instance_id()
	if not threat.has(key):
		return
	var top := 0.0
	for k in threat:
		top = maxf(top, float(threat[k]["value"]))
	threat[key]["value"] = top * 1.1 + 1.0
	force_target(source, duration)

## Reel In: dragged to `to` (next to whoever lashed it) and made to attack them
## for `taunt_time` seconds. Bosses are too heavy to drag: they are only made to
## attack. Returns true if it was dragged. Host / solo only (party members see
## it move through the usual snapshots).
func pull_to(source: Node, to: Vector3, taunt_time: float, drag_time: float = 0.18) -> bool:
	if _replica() or state == State.DEAD or state == State.RETURN or source == null or not is_instance_valid(source):
		return false
	taunt(source, taunt_time)
	if rank == "boss":
		return false
	velocity = Vector3.ZERO
	busy_until = maxf(busy_until, _now_s() + drag_time)   # (it does not walk while it is dragged)
	var drag := create_tween()
	drag.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	drag.tween_property(self, "global_position", to, maxf(drag_time, 0.01))
	return true

## Collapse: slide this enemy to `to` over `drag_time` seconds, without changing
## who it attacks. Bosses are too heavy to drag. Returns true if it was dragged.
## Host / solo only (party members see it move through the usual snapshots).
func drag_to(to: Vector3, drag_time: float = 0.25) -> bool:
	if _replica() or state == State.DEAD or state == State.RETURN or rank == "boss":
		return false
	velocity = Vector3.ZERO
	busy_until = maxf(busy_until, _now_s() + drag_time)   # (it does not walk while it is dragged)
	var drag := create_tween()
	drag.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	drag.tween_property(self, "global_position", to, maxf(drag_time, 0.01))
	return true


## Play Dead (Martial Utility): players this enemy has forgotten, until when
## ({instance id: seconds}). It doesn't turn on them while it lasts; with nobody
## else to fight it stands where it is instead of going home.
var _forgotten := {}

## Play Dead: `source`'s threat on me drops to nothing and I forget them for `time`
## seconds (0: I remember them again). Host / solo only.
func forget(source: Node, time: float) -> void:
	if _replica() or source == null or not is_instance_valid(source):
		return
	var key := source.get_instance_id()
	if time <= 0.0:
		_forgotten.erase(key)
		return
	drop_threat(source)
	_forgotten[key] = Time.get_ticks_msec() / 1000.0 + time

func _is_forgotten(n: Node) -> bool:
	var key := n.get_instance_id()
	if not _forgotten.has(key):
		return false
	if Time.get_ticks_msec() / 1000.0 >= float(_forgotten[key]):
		_forgotten.erase(key)
		return false
	return true

## Is the only one left to fight someone I have forgotten (Play Dead)? Then I wait.
func _waiting_on_forgotten() -> bool:
	for key in threat:
		var n = threat[key]["node"]
		if is_instance_valid(n) and not _is_dead(n) and _is_forgotten(n):
			return true
	return false

## A direct hit (not over time) landed on me, from anyone: effects that end after a
## number of hits count it (Pin the Shadow). Host / solo (CombatSystem, Net).
func count_hit(tags: PackedStringArray) -> void:
	if _replica() or tags.has("DoT") or status == null:
		return
	status.count_hit()

## Leaf Cloak: `source`'s threat on me drops to nothing (a taunt of theirs ends too).
## Host / solo only.
func drop_threat(source: Node) -> void:
	if _replica() or source == null or not is_instance_valid(source):
		return
	var key := source.get_instance_id()
	if threat.has(key):
		threat[key]["value"] = 0.0
	if _taunt_target == source:
		_taunt_target = null

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
	for entry in CrowdGrid.near(get_tree(), &"enemies", global_position, r):
		if entry[0] == self:
			continue
		var d: Vector3 = global_position - entry[1]
		d.y = 0.0
		var sum: float = r + float(entry[2])
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

func _process(delta: float) -> void:
	_update_dormant(delta)
	if _dormant:
		return
	if _health_bar and _health_bar.visible:
		var cam := get_viewport().get_camera_3d()
		if cam:
			_health_bar.global_basis = cam.global_basis
	_update_cast_bar()
	_bar_check -= delta
	if _bar_check <= 0.0 and _health_bar and state != State.DEAD:
		_bar_check = 0.1
		_update_bar_state()

var _bar_check := randf() * 0.1

# --- Dormant (performance) -------------------------------------------------------
# An idle enemy far from every player (a room you haven't reached yet) stops
# animating, thinking and drawing. It wakes as soon as a player comes near or
# it's pulled into a fight.
const DORMANT_DIST := 45.0
var _dormant := false
var _dormant_check := randf() * 0.5

func _update_dormant(delta: float) -> void:
	_dormant_check -= delta
	if _dormant_check > 0.0:
		return
	_dormant_check = 0.5
	var want := false
	if state == State.IDLE:
		want = true
		for p in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("remote_player"):
			if p is Node3D and _flat_dist((p as Node3D).global_position) < DORMANT_DIST:
				want = false
				break
	if want != _dormant:
		_set_dormant(want)

func _set_dormant(on: bool) -> void:
	_dormant = on
	if _anim:
		_anim.active = not on
	var m := get_node_or_null("Model") as Node3D
	if m:
		m.visible = not on
	if on:
		velocity = Vector3.ZERO

## Something happened to it (threat, damage): wake right away.
func _wake() -> void:
	if _dormant:
		_set_dormant(false)
	_dormant_check = 0.5
var _is_targeted := false
var _name_label: Label3D

## Health bar only while fighting, targeted or hurt; glow red if the local
## player has aggro, yellow if they're within 90% of taking it.
func _update_bar_state() -> void:
	var fighting := is_in_combat()
	var show := fighting or _is_targeted or health < max_health or cast_progress() >= 0.0   # (a cast bar needs its health bar)
	_health_bar.visible = show
	if _name_label:
		_name_label.visible = show or rank == "boss"
	if _bar_glow == null:
		return
	var ts := threat_state_for(get_tree().get_first_node_in_group("player")) if fighting else 0
	_bar_glow.visible = ts > 0
	if ts > 0:
		_bar_glow.material_override = _shared_bar_mats[4] if ts == 2 else _shared_bar_mats[5]

func is_in_combat() -> bool:
	return state == State.CHASE or state == State.ATTACK

## Share of the top threat at which the aggro warning turns on.
const THREAT_WARN := 0.9

## For the local player's bar glow: 2 = `p` has aggro, 1 = within 90% of
## taking it, 0 = neither.
func threat_state_for(p: Node) -> int:
	if p == null or not is_instance_valid(p):
		return 0
	if _replica():
		var me := int(_net.my_id()) if _net else 0
		if _net_threat == me and me != 0:
			return 2
		var top := 0.0
		for m in _net_threat_vals:
			top = maxf(top, float(_net_threat_vals[m]))
		var mine := float(_net_threat_vals.get(me, 0.0))
		return 1 if top > 0.0 and mine >= top * THREAT_WARN else 0
	var top_node := top_threat()
	if top_node == p:
		return 2
	if top_node == null:
		return 0
	var top_v := float(threat.get(top_node.get_instance_id(), {"value": 0.0})["value"])
	var mine_v := float(threat.get(p.get_instance_id(), {"value": 0.0})["value"])
	return 1 if top_v > 0.0 and mine_v >= top_v * THREAT_WARN else 0

## Everyone's threat on me, biggest first (the meter's threat bars, host and clients):
## [{"member": member id (0 offline), "me": the local player, "value": threat,
##   "aggro": the one I'm attacking}].
func threat_rows() -> Array:
	var out: Array = []
	if _replica():
		var me := int(_net.my_id())
		for m in _net_threat_vals:
			out.append({"member": int(m), "me": int(m) == me, "value": float(_net_threat_vals[m]),
				"aggro": int(m) == _net_threat})
	else:
		var top: Node = top_threat()
		for row in get_threat_list():
			var n: Node = row["node"]
			if not is_instance_valid(n) or _is_dead(n):
				continue
			out.append({"member": int(_net.member_of(n)) if _net and _net.online else 0,
				"me": n.is_in_group("player"), "value": float(row["value"]), "aggro": n == top})
	out.sort_custom(func(a, b): return float(a["value"]) > float(b["value"]))
	return out

## Host snapshot: [[member, threat], ...] (so party members see the yellow warning).
var _net_threat_vals := {}

func net_apply_threat(rows: Array) -> void:
	_net_threat_vals.clear()
	for r in rows:
		_net_threat_vals[int(r[0])] = float(r[1])

# --- Targeting -------------------------------------------------------------------

func set_targeted(on: bool) -> void:
	_is_targeted = on
	for m in _meshes:
		m.material_overlay = _outline_mat if on else null

func is_alive() -> bool:
	return state != State.DEAD

## Running back to its spot: nothing can hit it (it heals to full when it gets there).
func is_evading() -> bool:
	return state == State.RETURN

# --- Health ---------------------------------------------------------------------
# Called by CombatSystem with FINAL damage (after crit/armor/etc.).

## Who landed the last hit (for "your killing blow" effects like Rune of Swiftness).
var last_attacker: Node = null
## Party member who got the killing blow (set by the host; -1 = unknown).
var killer_member := -1
## Instance ids of everyone who had a damage-over-time effect on this enemy as
## it died ({instance id: true}; StatusContainer.dot_owner_ids). Carrion reads it.
var dot_owners_at_death := {}

## CombatSystem / Net: `src` is about to hit this enemy.
func note_attacker(src: Node) -> void:
	if src != null and is_instance_valid(src) and state != State.DEAD:
		last_attacker = src

## Did the local player land the killing blow?
func killed_by_me() -> bool:
	if _net and _net.online:
		return killer_member == int(_net.my_id())
	return is_instance_valid(last_attacker) and last_attacker.is_in_group("player")

func take_damage(amount: int) -> void:
	if state == State.DEAD or _replica():
		return
	if state == State.RETURN:
		return   # (CombatSystem shows "Evade")
	health = max(health - amount, 0)
	_update_health_bar()
	if amount > 0 and status:
		status.break_on_damage()   # (Spore Sleep: any damage wakes it)
	_bus().enemy_damaged.emit(self, amount)
	if health == 0:
		_die()
	else:
		_check_frenzy()

func receive_heal(amount: int) -> void:
	if state != State.DEAD and not _replica():
		health = mini(health + amount, max_health)
		_update_health_bar()

func _die() -> void:
	if _net and _net.is_host():
		killer_member = _net.member_of(last_attacker) if is_instance_valid(last_attacker) else -1
		_net.enemy_died(self, killer_member)   # everyone plays the death (and rolls their own loot)
	change_state(State.DEAD)
	remove_from_group("enemies")
	set_targeted(false)
	if _cast_tween:
		_cast_tween.kill()
		_cast_tween = null
	if _cast_label or _cast_light:
		_show_cast(false)
	# (Who had damage over time on it as it died: asked after its effects are gone. Carrion.)
	dot_owners_at_death = status.dot_owner_ids() if status.has_method("dot_owner_ids") else {}
	status.clear()
	threat.clear()
	for c in get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", true)
	died.emit()
	_bus().enemy_died.emit(self)
	_drop_loot()
	var t := create_tween()
	if elite_trait == "volatile" or death_explode:
		# Blows up where it fell (warning circle first). Stays around until then.
		ELITE_TRAITS.explode(self, not _replica())
		t.tween_interval(EB.ELITE_VOLATILE_DELAY + 0.3)
	var death_len := play_once("death")
	if death_len > 0.0:
		# Has a death animation: play it, then sink away.
		if _health_bar:
			_health_bar.visible = false
		t.tween_interval(death_len + 1.0)
		t.tween_property(self, "position:y", position.y - 1.5, 1.0)
	else:
		t.tween_property(self, "scale", Vector3(1, 0.01, 1), 0.5).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)

# --- Multiplayer replica (client side) ----------------------------------------------

## Host snapshot for this enemy.
func net_apply(pos: Vector3, yaw: float, hp: int, mhp: int, st: int, moving: bool, threat_member: int) -> void:
	if state == State.DEAD:
		return
	if mhp > 0 and mhp != max_health:
		max_health = mhp
		_update_health_bar()
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

## Shield health the host has on this enemy (replicas only; the real shield -
## Shielded elites, a Rime Shell - lives on the host).
var _net_absorb := 0

func net_apply_absorb(amount: int) -> void:
	if amount != _net_absorb:
		_net_absorb = maxi(amount, 0)
		_update_health_bar()

## Replica: how much of my `dmg` the host's shield on this enemy will soak. Taken
## off the shown shield right away; the next snapshot has the real number.
func net_soak(dmg: int) -> int:
	if not _replica() or _net_absorb <= 0 or dmg <= 0:
		return 0
	var soaked := mini(dmg, _net_absorb)
	_net_absorb -= soaked
	_update_health_bar()
	return soaked

## Seconds my own copy of an effect may differ from the host's before the
## host's time is taken (it reaches the host one trip later than it started here).
const NET_OWN_EXPIRY_SLACK := 0.75

static func keeps_own_clock(local_expires: float, host_expires: float) -> bool:
	return absf(host_expires - local_expires) < NET_OWN_EXPIRY_SLACK

## Host's status effects on this enemy (Chilled, Frozen, Poisoned...). Mirrored
## so the status label shows them - but they never tick here (the host deals
## the DoT damage) until this machine becomes the host.
func net_apply_status(rows: Array) -> void:
	if status == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var keep := {}
	var changed := false
	var me: Node = _net.body_of(_net.my_id()) if _net else null   # my own character
	for r in rows:
		var res: Resource = _effect_res(str(r[0]))
		if res == null:
			continue
		var src: Node = _net.body_of(int(r[3])) if _net and int(r[3]) != 0 else null
		var id := STATUS_CONTAINER.key_for(res, src)   # per caster for DoTs, like on the host
		keep[id] = true
		# My own damage over time is dealt HERE (my stats, talents, runes): my copy
		# keeps a real tick timer. Everything else is only shown (never ticks).
		var mine: bool = me != null and src == me and float(res.tick_damage) > 0.0
		if not status.effects.has(id):
			if status.is_suppressed(id):
				continue   # I just ended it; the host hasn't caught up yet
			if mine and float(r[2]) < NET_DOT_MIN_LEFT:
				continue   # about to run out on the host: not worth starting again
			var fresh := {"res": res, "stacks": int(r[1]), "expires": now + float(r[2]),
				"next_tick": INF, "source": src}
			if r.size() > 4 and int(r[4]) > 0:
				fresh["net_absorb"] = int(r[4])   # the host's shield on this effect (a Rime Shell)
			if mine:
				_net_start_ticking(fresh, res, src, now)
			status.effects[id] = fresh
			changed = true
		else:
			var fx: Dictionary = status.effects[id]
			changed = changed or int(fx["stacks"]) != int(r[1])
			fx["stacks"] = int(r[1])
			if r.size() > 4 and int(r[4]) > 0:
				fx["net_absorb"] = int(r[4])
			else:
				fx.erase("net_absorb")
			# An effect I applied started here first: keep my clock unless the host's
			# really differs (else every snapshot would look like a fresh application
			# to talents that react to my slows).
			var host_expires := now + float(r[2])
			# (clock_hold: I just changed how long it lasts and told the host -
			# StatusContainer.set_remaining_from - so its older number waits.)
			if now < float(fx.get("clock_hold", 0.0)) and is_same(fx.get("source"), me):
				pass
			elif not (me != null and src == me and is_same(fx.get("source"), me)
					and keeps_own_clock(float(fx["expires"]), host_expires)):
				fx["expires"] = host_expires
			fx["source"] = src
			if not mine:
				fx["next_tick"] = INF
			elif float(fx.get("next_tick", INF)) == INF:
				_net_start_ticking(fx, res, src, now)
	for id in status.effects.keys():
		if keep.has(id):
			continue
		var gone: Dictionary = status.effects[id]
		if now - float(gone.get("predicted", -100.0)) < NET_PREDICT_GRACE:
			continue   # my hit applied it a moment ago: the host will list it shortly
		var burst: Variant = gone["res"].get("expire_damage")
		if me != null and gone.get("source") == me and float(gone.get("next_tick", INF)) != INF \
				and burst != null and float(burst) > 0.0 and float(gone["expires"]) - now <= NET_DOT_MIN_LEFT:
			gone["expires"] = 0.0   # ran out on the host a moment before here: let it end (and burst) here
			continue
		status.effects.erase(id)
		changed = true
	if changed:
		status.changed.emit()
	if not status.effects.is_empty():
		status.set_process(true)   # mirrored effects still need to expire here

## Seconds a predicted effect is kept while the host hasn't listed it yet.
const NET_PREDICT_GRACE := 1.0
## My own DoT with less than this left on the host is not (re)started here.
const NET_DOT_MIN_LEFT := 0.6

## Give a mirrored copy of MY damage over time its tick timer (it is dealt here).
func _net_start_ticking(fx: Dictionary, res: Resource, src: Node, now: float) -> void:
	var tick: float = STATUS_CONTAINER.tick_for(res, src)
	fx["tick"] = tick
	fx["next_tick"] = now + tick
	if not fx.has("tags"):
		fx["tags"] = STATUS_CONTAINER.tag_hint(str(res.id))

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
		if float(fx.get("next_tick", INF)) == INF:   # (my own DoTs already tick here)
			fx["next_tick"] = now + maxf(float(fx["res"].tick_interval), 0.05)
	if _net_absorb > 0 and _net and _net.has_method("restore_enemy_shell"):
		_net.restore_enemy_shell(self, _net_absorb)
	_net_absorb = 0
	_update_health_bar()

## Host says it died (`killer` = member with the killing blow).
func net_die(killer: int = -1) -> void:
	if state != State.DEAD:
		killer_member = killer
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
			_flat_mat(Color(0.85, 0.12, 0.12), 11), _flat_mat(Color(0.25, 0.25, 0.25), 11),
			_flat_mat(Color(0.7, 0.9, 1.0, 0.85), 12),
			_flat_mat(Color(1.0, 0.1, 0.05, 0.75), 9), _flat_mat(Color(1.0, 0.85, 0.1, 0.75), 9)]
	var bg_mat := _shared_bar_mats[0]
	_bar_w = 1.0 if rank == "normal" else 1.6

	# Aggro glow: a bigger quad behind the bar (red = you have aggro, yellow = close).
	_bar_glow = MeshInstance3D.new()
	var glow_mesh := QuadMesh.new()
	glow_mesh.size = Vector2(_bar_w + 0.1, 0.24)
	_bar_glow.mesh = glow_mesh
	_bar_glow.position.z = -0.001
	_bar_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar_glow.visible = false
	_health_bar.add_child(_bar_glow)

	var bg := MeshInstance3D.new()
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(_bar_w, 0.14)
	bg.mesh = bg_mesh
	bg.material_override = bg_mat
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_health_bar.add_child(bg)

	# One fill quad scaled to the health fraction (+ a pale shield quad for absorbs).
	_bar_fill = _bar_quad(_shared_bar_mats[1], 0.001)
	_bar_shield = _bar_quad(_shared_bar_mats[3], 0.002)
	_update_health_bar()
	_health_bar.visible = false   # shown while fighting / targeted / hurt (_update_bar_state)

	if show_name and display_name != "":
		var n := Label3D.new()
		n.text = display_name
		n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		n.no_depth_test = true
		n.font_size = 40 if rank == "boss" else 32
		n.pixel_size = 0.006
		n.outline_size = 8
		n.modulate = Color(1.0, 0.35, 0.3) if rank == "boss" else Color(1.0, 0.75, 0.3)
		_name_label = n
		n.position = Vector3(0, health_bar_height + 0.2, 0)
		add_child(n)

var _bar_w := 1.0
var _bar_glow: MeshInstance3D
var _bar_fill: MeshInstance3D
var _bar_shield: MeshInstance3D
const BAR_PAD := 0.03

func _bar_quad(mat: Material, z: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(_bar_w - BAR_PAD * 2.0, 0.08)
	m.mesh = q
	m.material_override = mat
	m.position.z = z
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_health_bar.add_child(m)
	return m

## Fill [from, to] (fractions 0..1) of the bar with quad `m`.
func _bar_span(m: MeshInstance3D, from: float, to: float) -> void:
	var inner := _bar_w - BAR_PAD * 2.0
	from = clampf(from, 0.0, 1.0)
	to = clampf(to, from, 1.0)
	m.visible = to - from > 0.001
	m.scale.x = maxf(to - from, 0.001)
	m.position.x = -inner / 2.0 + inner * (from + to) / 2.0

func _update_health_bar() -> void:
	if _bar_fill == null:
		return
	var frac := float(health) / float(maxi(max_health, 1))
	_bar_span(_bar_fill, 0.0, frac)
	var shield := 0
	if _replica():
		shield = _net_absorb   # the host's shield (mirrored)
	elif status and status.has_method("total_absorb"):
		shield = status.total_absorb()
	_bar_span(_bar_shield, frac, frac + float(shield) / float(maxi(max_health, 1)))

func _flat_mat(c: Color, priority: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = true
	m.render_priority = priority
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m
