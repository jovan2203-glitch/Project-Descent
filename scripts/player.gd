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
var current_spell := ""        # "frostbolt" | "blizzard" | "hoist" ... while casting
var cast_is_channel := false   # channels drain the cast bar instead of filling it


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
	amount = _still_standing_limit(amount)   # Still Standing: the Strings hold off a killing blow
	if amount <= 0:
		return
	health = max(health - amount, 0)
	_pact_on_damage(amount)      # my Pact: one big hit (Sidestep), too little health left (Thin Line)
	_note_damage_taken(amount)   # Trade Places looks back on it
	health_changed.emit(health, max_health)
	_bus().player_damaged.emit(amount)
	_bus().player_health_changed.emit(health, max_health)
	if health == 0:
		if _can_go_down():
			_go_down()
		else:
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
#   CHANNELING    : cast bar draining (channeled spells)
#   AIMING        : placing a ground-targeted spell (Blizzard circle)
#   DEAD          : terminal until restart
#   DOWNED        : co-op only - at 0 health but revivable by an ally (bleeds out)
enum PState {IDLE, MOVING, CASTING, CHANNELING, AIMING, DEAD, DOWNED}
const PSTATE_NAMES := ["Idle", "Moving", "Casting", "Channeling", "Aiming", "Dead", "Downed"]
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
	_pact_on_down()   # Pact of the Unbowed
	casting = false
	cancel_placement()
	change_state(PState.DEAD)
	current_state = "dead"   # the party's puppet of me stops showing "Downed"
	_fuses.clear()
	_clear_arcane()
	_heat_on = false
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

# --- Downed & revive (co-op) ----------------------------------------------------------
# In a party, reaching 0 health while someone else is still standing knocks you
# down instead of killing you. Enemies ignore you (you're not alive), you can't
# act, and you bleed out after a while. An ally standing next to you presses
# Interact (F) to revive you: a short channel, moving cancels it. If everyone
# is down (or you press Restart to give up) you die for real - only then does
# the roguelike death penalty apply. Solo and in the Training Room you just die.

var _downed_until := 0.0
var _times_downed := 0          # this floor (the player is rebuilt on every floor load)

func is_downed() -> bool:
	return pstate == PState.DOWNED

## Seconds left before bleeding out (0 when not downed).
func bleed_out_left() -> float:
	return maxf(_downed_until - Time.get_ticks_msec() / 1000.0, 0.0) if is_downed() else 0.0

func _can_go_down() -> bool:
	if pstate == PState.DOWNED or pstate == PState.DEAD:
		return false
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_method("in_training") and gm.in_training():
		return false
	var net := _net()
	return net != null and net.with_others() and net.any_party_alive()

func _go_down() -> void:
	_pact_on_down()   # Pact of the Unbowed
	casting = false
	cancel_placement()
	clear_queue()
	change_state(PState.DOWNED)
	_fuses.clear()   # Slow Fuse charges fizzle with me
	_clear_arcane()  # (so do Countdown marks; the Mirror Sigil and the Afterimage go)
	_heat_on = false
	if status:
		status.clear()
	_set_target(null)
	var t := Balance.DOWNED_BLEED_OUT - Balance.DOWNED_REPEAT_PENALTY * _times_downed
	_times_downed += 1
	_downed_until = Time.get_ticks_msec() / 1000.0 + maxf(t, Balance.DOWNED_MIN_BLEED_OUT)
	current_state = "downed"   # streamed to the party: their puppet of me shows "Downed"
	anim.pause()
	var tw := create_tween()
	tw.tween_property(model, "rotation:x", deg_to_rad(-80.0), 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_combat().float_text(self, "Downed!", Color(1.0, 0.55, 0.3), true)
	var gl := get_node_or_null("/root/GameLog")
	if gl:
		gl.event("You are down! An ally can revive you (%s)." % get_node("/root/Settings").key_text("interact"),
			Color(1.0, 0.55, 0.3))

func _tick_downed() -> void:
	if not is_downed():
		return
	var net := _net()
	# Bled out, or nobody left standing to revive me.
	if bleed_out_left() <= 0.0 or net == null or not net.any_party_alive():
		_die()

## Revived by an ally (their machine asked mine through Net).
func revive(by: Node = null) -> void:
	if not is_downed():
		return
	pstate = PState.IDLE
	health = maxi(int(round(max_health * Balance.REVIVE_HEALTH_PCT / 100.0)), 1)
	health_changed.emit(health, max_health)
	_bus().player_health_changed.emit(health, max_health)
	var tw := create_tween()
	tw.tween_property(model, "rotation:x", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	current_state = ""
	anim.play()
	_set_state("idle")
	_ring_effect(1.4, Color(1.0, 0.9, 0.5))
	_combat().float_text(self, "Revived!", Color(1.0, 0.9, 0.5), true)
	var who := ""
	var net := _net()
	if by != null and is_instance_valid(by) and net:
		who = net.member_name(net.member_of(by))
	var gl := get_node_or_null("/root/GameLog")
	if gl:
		gl.event("%s revived you." % who if who != "" and who != "?" else "You were revived.", Color(1.0, 0.9, 0.5))

## Where this character entered the level (fallback revive point).
var start_position := Vector3.ZERO

func _remember_start() -> void:
	start_position = global_position

## No-drawback death (Balance.ROGUELIKE_DEATH off): get back up at `at` with
## full health and resources. GameManager.revive_local() calls this.
func respawn(at: Vector3) -> void:
	if pstate != PState.DEAD and pstate != PState.DOWNED and health > 0:
		return
	pstate = PState.IDLE
	casting = false
	if status:
		status.clear()
	health = max_health
	resources["mana"] = resource_max("mana")
	_times_downed = 0
	global_position = at
	velocity = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(model, "rotation:x", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	current_state = ""
	anim.play()
	_set_state("idle")
	health_changed.emit(health, max_health)
	_bus().player_health_changed.emit(health, max_health)
	_bus().player_revived.emit()
	_ring_effect(1.4, Color(1.0, 0.9, 0.5))
	_combat().float_text(self, "Revived!", Color(1.0, 0.9, 0.5), true)

# Reviving an ally: a channel through the normal cast bar ("revive" is off the GCD).
var _revive_target: Node3D = null

## The nearest downed party member within revive range (null if none).
func downed_ally_nearby() -> Node3D:
	var best: Node3D = null
	var best_d := Balance.REVIVE_RANGE
	for p in get_tree().get_nodes_in_group("remote_player"):
		if not (p is Node3D) or not bool(p.get("downed")):
			continue
		var d := _flat_dist_to(p.global_position)
		if d <= best_d:
			best_d = d
			best = p
	return best

func _try_revive() -> void:
	if is_dead() or casting or is_stunned():
		return
	var ally := downed_ally_nearby()
	if ally == null:
		return
	_revive_target = ally
	cancel_placement()
	var net := _net()
	var nm: String = str(net.member_name(net.member_of(ally))) if net else "ally"
	_begin_spell("revive", "Reviving %s" % nm, Balance.REVIVE_TIME)

func _revive_target_ok() -> bool:
	return is_instance_valid(_revive_target) and bool(_revive_target.get("downed")) \
		and _flat_dist_to(_revive_target.global_position) <= Balance.REVIVE_RANGE + 0.5

func _finish_revive() -> void:
	var tgt := _revive_target
	_revive_target = null
	if tgt == null or not is_instance_valid(tgt):
		return
	var net := _net()
	if net:
		net.revive_ally(tgt, self)
	_ring_effect(1.4, Color(1.0, 0.9, 0.5), tgt.global_position)

func _ready() -> void:
	add_to_group("player")
	Combat.setup_walker(self)   # sticks to ramps, same speed up and down them
	# Enemies are only on the enemy layer (not in our mask): you can walk
	# through a pack. They still stop at you (their mask has layer 1).
	collision_mask &= ~ENEMY_LAYER_MASK
	_setup_status()
	_setup_animations()
	_set_state("idle")
	_build_aoe_indicator()
	_build_target_ring()
	_build_friendly_ring()
	# Stats from gear/talents (max health etc.) + the rune listener.
	max_health = int(get_stat("max_health"))
	health = max_health
	resources["mana"] = resource_max("mana")   # mana is on the health scale: start full
	resources["energy"] = resource_max("energy")   # (a bigger bar with Deep Reserves starts full too)
	get_node("/root/PlayerData").changed.connect(_on_stats_changed)
	_bus().level_up.connect(_on_level_up)
	# Instant abilities announce themselves with cast_finished while use_ability runs.
	_bus().cast_finished.connect(func(_id):
		if _acting:
			_acted = true)
	_bus().cast_finished.connect(_on_spell_cast_for_shards)
	_bus().cast_finished.connect(_cold_precision_on_cast)
	_bus().ability_used.connect(_cold_precision_on_use)
	_bus().damage_dealt.connect(_on_damage_dealt_frost)
	_bus().damage_dealt.connect(_on_damage_dealt_fire)
	_bus().damage_dealt.connect(_on_damage_dealt_lightning)
	_bus().damage_dealt.connect(_on_damage_dealt_arcane)
	_bus().damage_dealt.connect(_on_damage_dealt_shadow)
	_bus().enemy_died.connect(_on_enemy_died_shadow)   # Carrion
	_bus().heal_done.connect(_on_heal_done_strings)    # the Strings share my heals
	_bus().heal_done.connect(_on_heal_done_hymns)      # the Hymns: Chorus, Vigil, Mercy's Ear
	_bus().damage_dealt.connect(_on_damage_dealt_holy)  # High Note's heal
	_bus().cast_finished.connect(_pact_on_ability)     # Pact of the Purist: an ability of mine went off
	_bus().dungeon_cleared.connect(func(_summary): _pact_cleared = true)   # Pact of the Restless: nothing left to fight
	_bus().cast_finished.connect(_on_cast_for_arcane)
	_bus().cast_finished.connect(_change_of_pace)
	_bus().cast_started.connect(_on_cast_for_static)
	_bus().cast_finished.connect(_on_cast_for_static)
	_bus().damage_dealt.connect(_slag_skin_retaliate)
	_bus().damage_dealt.connect(_on_hit_taken)
	_bus().damage_modify.connect(_on_damage_modify)
	_bus().player_hit.connect(_on_hit_talents)
	var listener := Node.new()
	listener.name = "RuneListener"
	listener.set_script(RUNE_LISTENER)
	add_child(listener)
	var lifesteal := Node.new()
	lifesteal.name = "Lifesteal"
	lifesteal.set_script(preload("res://scripts/core/lifesteal.gd"))
	add_child(lifesteal)
	# Co-op: pings (G) and the downed / revive prompts.
	var pings := Node.new()
	pings.name = "Pings"
	pings.set_script(preload("res://scripts/core/pings.gd"))
	add_child(pings)
	var coop_ui := CanvasLayer.new()
	coop_ui.name = "CoopPrompts"
	coop_ui.set_script(preload("res://scripts/ui/coop_prompts.gd"))
	add_child(coop_ui)
	_bus().player_health_changed.emit.call_deferred(health, max_health)
	_remember_start.call_deferred()   # after the level placed us
	# Performance: the lantern's shadow in 2 passes instead of 6 (cube map).
	var lantern := get_node_or_null("Lantern") as OmniLight3D
	if lantern:
		lantern.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID

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
	var bliz_r := float(Abilities.get_resource("blizzard").radius)
	quad.size = Vector2(bliz_r * 2.0, bliz_r * 2.0)
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
			if is_downed():
				_die()   # give up: bleed out now
			else:
				get_node("/root/GameManager").restart()
		return
	if event.is_action_pressed("interact"):
		_try_revive()
		get_viewport().set_input_as_handled()
		return
	if placing and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_update_placement(event.position)
			if not placement_valid:
				_error("Not in line of sight")
			elif gcd_left > 0.0:
				pass   # still on the global cooldown: keep aiming, click again
			elif placing_id == CINDER_RAIN_ID and _cinder_rain_error(cast_point) != "":
				_error(_cinder_rain_error(cast_point))   # out of range: keep aiming
			elif placing_id == DECOY_ID and _decoy_error(cast_point) != "":
				_error(_decoy_error(cast_point))         # (the same for Decoy)
			else:
				cancel_placement()
				if placing_id == CRUCIBLE_ID:
					_start_crucible(cast_point)
				elif placing_id == DECOY_ID:
					_start_decoy(cast_point)
				elif placing_id == CINDER_RAIN_ID:
					_start_cinder_rain(cast_point)
				elif placing_id == THUNDERHEAD_ID:
					_start_thunderhead(cast_point)
				elif placing_id == COLLAPSE_ID:
					_start_collapse(cast_point)
				elif placing_id == PALL_ID:
					_start_pall(cast_point)
				else:
					_start_blizzard(cast_point)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placement()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_target_at(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		# Keys come from the Input Map (rebindable in Settings > Controls).
		# (Every bar's slots: the main bar and the extra ones, shown or not.)
		var settings := get_node("/root/Settings")
		for i in range(1, PlayerDataScript.ACTION_SLOTS_TOTAL + 1):
			if event.is_action_pressed(settings.slot_action(i)):
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
	if Macros.is_macro(id):
		_run_macro(id)
		return
	var pdata := get_node_or_null("/root/PlayerData")
	if pdata and not pdata.has_ability(id):
		var teacher: String = Runes.rune_for_spell(id)
		_error("%s needs the %s on your gear" % [Abilities.ability_name(id), Runes.rune_name(teacher)] if teacher != "" \
			else "You haven't learned that ability")
		return
	if is_stunned():
		_error("You are stunned")
		return
	if _pact_purist_blocks(id):   # Pact of the Purist: the first press only warns
		return
	var cancelling_placement := placing and id == placing_id
	# Busy (casting, or on the global cooldown): pressed within the last
	# SPELL_QUEUE_WINDOW seconds it's queued and fires the moment it can (like
	# WoW's spell queue); pressed earlier it's ignored. Off-GCD buttons
	# (trinkets, interrupts) aren't held up.
	if not cancelling_placement and on_gcd(id):
		var wait := _busy_time()
		if wait > 0.0:
			if wait <= Balance.SPELL_QUEUE_WINDOW:
				_queued = id
				_queued_at = Time.get_ticks_msec() / 1000.0
			return
	if not casting and not cancelling_placement and not can_afford(id, true):
		return
	if not cancelling_placement:
		_bus().ability_used.emit(id)
	_auto_target(id)   # no target: the closest enemy this could be used on
	_acting = true
	_acted = false
	_use_ability_now(id)
	_acting = false
	_use_result = _acted
	# An instant ability went off (casts start the GCD in _begin_spell).
	if _acted and on_gcd(id) and gcd_left <= 0.0:
		_start_gcd()
		if id == STRING_ID:   # String: a short global cooldown, so several can be tied quickly
			gcd_total = string_gcd(gcd_total)
			gcd_left = gcd_total

## Enemy-targeted bolt spells with a cast time (same flow as Frost Bolt).
const ENEMY_BOLTS := ["frostbolt", "fireball", "lightningbolt", "immolate",
	"kilnblast", "slowfuse", "rekindle", "frostfirebolt", "coldspike", "chainlightning", "discharge",
	"livewire", "forkedbolt", "unravel", "countdown", "convergence",
	"blight", "erode", "highnote"]

# --- Where projectiles leave from: the right hand ------------------------------------
var _skel: Skeleton3D
var _hand_bone := -2   # -2 = not looked up yet, -1 = no hand bone (use a point in front)

## World position of the casting hand (falls back to in front of the chest).
func _muzzle() -> Vector3:
	var fallback := global_position + _flat_forward() * 0.5 + Vector3(0, 0.45, 0)
	if _hand_bone == -2:
		_hand_bone = -1
		var skels := model.find_children("*", "Skeleton3D", true, false)
		if not skels.is_empty():
			_skel = skels[0]
			for i in _skel.get_bone_count():
				if _skel.get_bone_name(i).ends_with("RightHand"):
					_hand_bone = i
					break
	if _hand_bone < 0 or not is_instance_valid(_skel):
		return fallback
	var p := _skel.global_transform * _skel.get_bone_global_pose(_hand_bone).origin
	# A strange pose (or a model swap) must never fire from somewhere silly.
	return p if p.distance_to(global_position) < 1.6 else fallback
## Cast-time spells aimed at an ally / you / (Rime Shell) an enemy, or nothing.
const SUPPORT_CASTS := ["rimeshell", "flashfreeze", "hoist", "patchup", "psalm", "outpour", "canticle", "exultation"]
## Instant abilities every character has (handled like drafted ones).
const BASE_INSTANTS := ["stoneguard", "taunt"]

func _use_ability_now(id: String) -> void:
	if id == BLIGHT_ID and (_has_rune(OPEN_WOUND_RUNE) or interest_ready()):
		cancel_placement()
		_blight_now()   # Rune of the Open Wound: instant, on a cooldown. Interest's capstone: instant, once
		return
	if id in ENEMY_BOLTS:
		cancel_placement()
		_start_bolt(id)
		return
	if id in SUPPORT_CASTS:
		cancel_placement()
		_start_support_cast(id)
		return
	match id:
		"blizzard", "crucible":
			# Ground-targeted: pressing it again while aiming it puts the circle away.
			if placing and placing_id == id:
				cancel_placement()
			else:
				cancel_placement()
				_begin_placement(id)
		"cinderrain":
			# Ground-targeted too, but instant: it lands the moment you click.
			if placing and placing_id == id:
				cancel_placement()
			else:
				cancel_placement()
				var rain_err := _cinder_rain_error()
				if rain_err != "":
					_error(rain_err)
				else:
					_begin_placement(id)
		"slam":
			cancel_placement()
			_slam()
		"execute":
			cancel_placement()
			_execute()
		"steadyshot":
			cancel_placement()
			_start_steady_shot()
		"glacialdraw":
			cancel_placement()
			_start_glacial_draw()
		"embervolley":
			cancel_placement()
			_start_ember_volley()
		"walloffire":
			cancel_placement()
			_start_fire_wall()
		"balllightning":
			cancel_placement()
			_start_ball_lightning()
		"groundingsurge":
			_grounding_surge()   # (instant and off the global cooldown: it interrupts nothing)
		"capacitor":
			_capacitor()         # (the same)
		"arcanemissiles":
			cancel_placement()
			_start_sigil_darts()
		"mirrorsigil":
			cancel_placement()
			_start_mirror_sigil()
		"rewind":
			_rewind()            # (instant and off the global cooldown: these three interrupt nothing)
		"lapse":
			_lapse()
		"scatter":
			_scatter()
		"thunderhead", "collapse", "pall":
			# Ground-targeted, like Blizzard: pressing it again puts the circle away.
			if placing and placing_id == id:
				cancel_placement()
			else:
				cancel_placement()
				if float(cooldowns.get(id, 0.0)) > 0.0:
					_error("%s is not ready yet" % Abilities.ability_name(id))
				else:
					_begin_placement(id)
		"decoy":
			# Ground-targeted and instant, like Cinder Rain: it stands where you click.
			if placing and placing_id == id:
				cancel_placement()
			else:
				cancel_placement()
				var decoy_err := _decoy_error()
				if decoy_err != "":
					_error(decoy_err)
				else:
					_begin_placement(id)
		"trinket_1", "trinket_2":
			_use_trinket(id)
		_:
			if Abilities.DRAFT_POOL.has(id) or BASE_INSTANTS.has(id) or RUNE_INSTANTS.has(id):
				cancel_placement()
				_use_drafted(id)

# --- Stats, buffs and the central damage function ----------------------------------
# Stats = gear + talents (PlayerData) + active buffs. All player damage goes
# through deal_damage(), which adds the Damage stat, rolls crits and announces
# the hit on the SignalBus (the RuneListener reacts to those events).

const Stats = preload("res://scripts/core/stats.gd")
const CRIT_MULTIPLIER := 2
const RUNE_LISTENER = preload("res://scripts/rune_listener.gd")

const StatusContainer = preload("res://scripts/core/status_container.gd")
var status: Node   # StatusContainer child "Status": buffs AND debuffs (Chilled etc.)

func _setup_status() -> void:
	status = Node.new()
	status.name = "Status"
	status.set_script(StatusContainer)
	add_child(status)
	status.shield_broken.connect(_on_my_shield_broken)
	status.changed.connect(func():
		_cool_head_check()
		_heat_sink_check()
		_on_stats_changed()
		_sync_support_state()
		_sync_reflections()
		_bus().buffs_changed.emit())

## Final stat value: base + gear/talents/level/boons + buffs, primary stats
## converted (Intellect -> Spell Power, ...), percent buffs applied. See stats.gd.
func get_stat(stat: String) -> float:
	var v := Stats.resolve(stat, _raw_stat)
	# Rune of the Dull Edge / Dull Mind: crit is capped and the rest becomes
	# Attack Power (Dull Edge) or Spell Power (Dull Mind).
	var dull := dull_rune_power()
	if dull != "" and (stat == Stats.CRIT or stat == Stats.SPELL_CRIT or stat == dull):
		var d := dull_edge_split(Stats.resolve(Stats.CRIT, _raw_stat), Stats.resolve(Stats.SPELL_CRIT, _raw_stat),
			Balance.DULL_EDGE_CRIT_CAP)
		if stat == Stats.CRIT:
			return float(d[0])
		if stat == Stats.SPELL_CRIT:
			return float(d[1])
		return v + float(d[2]) * Balance.DULL_EDGE_POWER_PER_PCT * _flat_unit()
	return v

## Which power stat my excess crit becomes: Attack Power with the Rune of the
## Dull Edge, Spell Power with the Rune of the Dull Mind, "" with neither.
## (Only one of the two can be equipped at a time: Runes.FAMILIES.)
func dull_rune_power() -> String:
	return dull_power_stat(_has_rune("dull_edge"), _has_rune("dull_mind"))

static func dull_power_stat(has_edge: bool, has_mind: bool) -> String:
	if has_edge:
		return Stats.ATTACK_POWER
	return Stats.SPELL_POWER if has_mind else ""

## Rune of the Dull Edge as pure maths: [Critical Strike, Spell Critical Strike,
## excess %] once the two together are capped at `cap` (Critical Strike first).
static func dull_edge_split(crit: float, spell_crit: float, cap: float) -> Array:
	var c := minf(crit, cap)
	var sc := clampf(spell_crit, 0.0, maxf(cap - c, 0.0))
	return [c, sc, maxf(crit - c, 0.0) + maxf(spell_crit - sc, 0.0)]

func _raw_stat(key: String) -> float:
	var pd := get_node_or_null("/root/PlayerData")
	var v: float = float(pd.total_stats().get(key, 0.0)) if pd else 0.0
	if status:
		v += status.stat_mod(key)
	v += _pact_stat(key)                         # my Pact (Haste, crit, movement, max health and mana)
	if key == Stats.HASTE:
		v += _glacial_haste                      # Glacial Heart capstone
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
## `amount` is a coefficient (1.0 = a standard hit's worth of health).
func heal(amount: float, ability_id: String = "") -> void:
	if is_dead():
		return
	_combat().heal(self, self, amount * _pact_heal_mult(), ability_id)   # (my Pact: Shepherd)

## Real damage of a 1.0 coefficient for me: my level's standard hit (CombatSystem).
func damage_unit() -> float:
	return Stats.level_hit(combat_level())

func combat_level() -> int:
	var pd := get_node_or_null("/root/PlayerData")
	return int(pd.level) if pd else 1

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
func deal_damage(enemy: Node, base: float, ability_id: String, is_proc: bool = false,
		damage_type: String = "", tags: PackedStringArray = PackedStringArray()) -> int:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
		return 0
	if ability_id == FROSTFIRE and damage_type == "":
		return _frostfire_hit(enemy, base, is_proc)
	var at: Vector3 = enemy.global_position
	var info = _combat().ability_hit(self, enemy, base, ability_id, is_proc, damage_type, tags)
	if not is_proc and not info.avoided():
		_on_hit_extra(enemy, at, ability_id)
	return int(info.amount)

# --- Frostfire Bolt (taught by the Rune of Frostfire Bolt) ----------------------------
# A Frost Bolt's damage as two hits that land together: half Frost, half Fire.
# Each half is a hit of its own school (its own crit roll, its school's talents,
# runes and procs), and both carry the spell's id, which counts as a Frost Bolt
# AND a Firebolt (Abilities.is_a) for anything that names either.

const FROSTFIRE := "frostfirebolt"

## The two hits of a Frostfire Bolt of coefficient `base`: [[coefficient, damage type, tags], ...].
static func frostfire_halves(base: float) -> Array:
	var frost := base * Balance.FROSTFIRE_FROST_SHARE
	return [[frost, "frost", PackedStringArray(["Frost", "Spell", "Projectile"])],
		[base - frost, "fire", PackedStringArray(["Fire", "Spell", "Projectile"])]]

func _frostfire_hit(enemy: Node, base: float, is_proc: bool) -> int:
	var total := 0
	var halves := frostfire_halves(base)
	for i in halves.size():
		if not is_instance_valid(enemy) or not enemy.is_alive():
			break
		var info := DamageInfo.make(self, enemy, float(halves[i][0]), FROSTFIRE)
		info.damage_type = str(halves[i][1])
		info.tags = halves[i][2]
		info.is_proc = is_proc
		info.part = i + 1
		_combat().deal(info)
		total += int(info.amount)
	return total

## Extra effects some abilities have when they land. Not for procs, so chain /
## splash hits (dealt as procs) never chain again.
func _on_hit_extra(enemy: Node, at: Vector3, id: String) -> void:
	match id:
		"chainlightning":
			# Leaping Arc: it leaps to the nearest other enemies. A leap with no new
			# enemy to reach comes back to the target instead, weaker.
			var others := _enemies_near(at, float(Abilities.get_resource(id).radius), enemy)
			var leaps := mini(others.size(), Balance.LEAPING_ARC_JUMPS)
			var jump := float(Abilities.EXTRA_HITS[id])
			for i in leaps:
				FROST_BOLT.spawn(get_tree().current_scene, at + Vector3(0, 0.3, 0), others[i], self, true, id, jump)
			for i in arc_returns(others.size()):
				deal_damage(enemy, arc_return_coef(jump), id, true)
		"stormshield":
			var jumps := 0
			for e in _enemies_near(at, float(Abilities.get_resource(id).radius), enemy):
				FROST_BOLT.spawn(get_tree().current_scene, at + Vector3(0, 0.3, 0), e, self, true, id,
					float(Abilities.EXTRA_HITS[id]))
				jumps += 1
				if jumps >= Balance.CHAIN_JUMPS:
					break
		"returnstroke":
			# Counter-Charge's capstone: the answer arcs on to nearby enemies.
			if _capstone("lightning_counter_charge"):
				var arcs := 0
				for e in _enemies_near(at, Balance.COUNTER_CHARGE_REACH, enemy):
					if arcs >= Balance.COUNTER_CHARGE_JUMPS:
						break
					FROST_BOLT.spawn(get_tree().current_scene, at + Vector3(0, 0.3, 0), e, self, true, id,
						Balance.COUNTER_CHARGE_ARC)
					arcs += 1
		"stormarrow":
			# Lightning Rod: the arrow stays stuck in the target (the effect goes
			# through the combat pipeline, so in a party it reaches the host).
			if _talent("lightning_rod") > 0.0:
				_apply_effect_hit(enemy, preload("res://scripts/core/effects.gd").get_effect(ROD_FX), ROD_FX,
					PackedStringArray(["Lightning"]), "lightning")
			var r := float(Abilities.get_resource(id).radius)
			for e in _enemies_near(at, r, enemy):
				deal_damage(e, float(Abilities.EXTRA_HITS[id]), id, true)
			_ring_effect(r, Abilities.color_of(id), at)
		"shattershot":
			_shatter_shot_landed(enemy, at)   # on a target I had Frozen: it thaws and the ice bursts
		"shadowstrike":
			# Share the Kill: Leeching Strike heals for more while my Hounds are out.
			heal(float(Abilities.HEALS[id]) * leech_heal_mult(hounds_out(), _talent("shadow_share_the_kill")), id)

# Instant, free cast triggered by an rune (e.g. Rune of Frost).
func proc_cast(ability_id: String, enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
		return
	match ability_id:
		"frostbolt":
			FROST_BOLT.spawn(get_tree().current_scene, _muzzle(), enemy, self, true)
		_:
			var base := float(Abilities.get_resource(ability_id).damage) if Abilities.get_resource(ability_id) else 1.0
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

# --- Resources: mana, Energy and Rage (Energy / Rage are bars of RESOURCE_MAX = 100) ----

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const RESOURCE_MAX := Balance.RESOURCE_MAX
const MANA_REGEN := Balance.MANA_REGEN      # points per second
const ENERGY_REGEN := Balance.ENERGY_REGEN  # points per second
const RAGE_DECAY := Balance.RAGE_DECAY      # points per second lost

var resources := {"mana": RESOURCE_MAX, "energy": RESOURCE_MAX, "rage": 0.0}

func resource_points(res: String) -> int:
	return int(floor(float(resources.get(res, 0.0)) + 0.0001))

func can_afford(id: String, report: bool = false) -> bool:
	if id == "iceshards" and ice_shard_charges <= 0:
		if report:
			_error("No Ice Shard charges")
		return false
	# Quench and Flare run on Heat.
	var heat_need := heat_needed(id)
	if heat_need > 0 and heat_stacks() < heat_need:
		if report:
			_error("Requires %d Heat" % heat_need)
		return false
	# Decoy and Trade Places spend Reflections; Missed Beat answers one shattering.
	# (Good Likeness' capstone: Decoy needs none.)
	if ((id == DECOY_ID and decoy_needs_reflection()) or id == TRADE_PLACES_ID) and reflections() <= 0:
		if report:
			_error("You have no Reflections")
		return false
	# Encore replays Traces.
	if id == ENCORE_ID and traces() <= 0:
		if report:
			_error("You have no Traces")
		return false
	if id == MISSED_BEAT_ID and (status == null or not status.has(MISSED_BEAT_FX)):
		if report:
			_error("None of your Reflections has shattered")
		return false
	# String ties one from my hand; Not Finished With You takes several.
	if id == STRING_ID and string_charges() < 1:
		if report:
			_error("No Strings left in your hand")
		return false
	if id == NOT_FINISHED_ID and string_charges() < Balance.NOT_FINISHED_STRINGS:
		if report:
			_error("Requires %d Strings in your hand" % Balance.NOT_FINISHED_STRINGS)
		return false
	# Discharge and Ground Out spend ALL my Energy: they need some to spend.
	if Abilities.SPENDS_ALL.has(id) and float(resources["energy"]) + 0.0001 < Balance.SPEND_ALL_MIN_ENERGY:
		if report:
			_error("Not enough energy")
		return false
	# Overdrive only starts with little Energy (it would end at once with more).
	if id == OVERDRIVE_ID and not overdrive_holds(float(resources["energy"]), resource_max("energy")):
		if report:
			_error("Too much Energy")
		return false
	var res := Abilities.resource_of(id)
	var cost := resource_cost(id)
	if res == "" or cost <= 0.0:
		return true
	if float(resources.get(res, 0.0)) + 0.0001 >= cost:
		return true
	if report:
		_error("Not enough %s" % res)
	return false

## What using `id` costs right now. Mana costs in the data are points (10% of
## base mana each) and get Cold Discipline's discount for spells; Energy / Rage
## costs are that many Energy / Rage of their 100 (Grounding Surge halves Energy costs).
func resource_cost(id: String, with_storm_cycle: bool = true) -> float:
	if Abilities.is_a(id, "frostbolt") and (_instinct_cast or (not casting and frozen_instinct_ready())):
		return 0.0   # Frozen Instinct: free
	if id == CRUCIBLE_ID and _crucible_standing():
		return 0.0   # moving a Crucible that still stands is free
	var cost := float(Abilities.cost_of(id))
	if id == "cinderguard":
		cost = furnace_heart_cost(cost, _talent("fire_furnace_heart"))   # Furnace Heart
	if id == RETURN_STROKE_ID:   # Rune of Resonance: dearer without a parry behind it
		cost = return_stroke_cost(cost, status != null and status.has(RETURN_STROKE_FX), _has_rune(RESONANCE_RUNE))
	if id == STATIC_STEP_ID and status != null and status.has(WHIP_CRACK_FX):
		cost = whip_crack_cost(cost, _talent("lightning_whip_crack"))    # Whip Crack
	if id == STORM_ARROW_ID and status != null:                         # Loaded Quiver, Snap Shot
		cost = storm_arrow_cost(cost, status.has(LOADED_QUIVER_FX),
			_talent("lightning_snap_shot") if status.has(SNAP_SHOT_FX) else 0.0)
	if cost > 0.0 and Abilities.resource_of(id) == "energy":
		cost = surge_energy_cost(cost, surge_active())                   # Grounding Surge
		if with_storm_cycle and storm_cycle_ready():
			cost = 0.0                                                   # Storm Cycle: this one is free
	if cost <= 0.0 or Abilities.resource_of(id) != "mana":
		return cost * _pact_cost_mult(Abilities.resource_of(id))   # (my Pact: Sidestep)
	cost *= mana_unit() * _pact_cost_mult("mana")                  # (my Pact: Sidestep, Reservoir)
	var tags := Abilities.tags_of(id)
	if tags.has("Spell"):
		var pd := get_node_or_null("/root/PlayerData")
		if pd:
			cost *= 1.0 - float(pd.talent_value("frost_discipline")) / 100.0   # Cold Discipline
	return cost

## One mana "point" at your level (10% of your base mana).
func mana_unit() -> float:
	return Stats.mana_unit(combat_level())

# Spend an ability's cost. Returns false (and reports) if it can't be paid.
func _pay(id: String) -> bool:
	if not can_afford(id, true):
		return false
	var res := Abilities.resource_of(id)
	if res != "":
		# Storm Cycle: an Energy cost that would have been more than nothing is free
		# once (not one Whip Crack, Loaded Quiver or Snap Shot already made free).
		var free_cycle: bool = res == "energy" and storm_cycle_ready() and resource_cost(id, false) > 0.0
		var cost := resource_cost(id)
		resources[res] = float(resources[res]) - cost
		if free_cycle:
			status.remove(STORM_CYCLE_FX)
		if res == "energy" and cost > 0.0:
			_redline()   # Redline: Energy spent during Overdrive makes it last longer
			_storm_cycle_spent(cost)   # Storm Cycle counts what I spend
		if rouses(res, cost):
			_rouse_hounds()   # Shadow melee: spending Rage Rouses my Hounds
	return true

func _gain(res: String, amount: float) -> void:
	if amount > 0.0:
		amount *= PACTS.resource_gain_mult(pact_id(), pact_broken())   # Pact of the Restless
	resources[res] = clampf(float(resources[res]) + amount, 0.0, resource_max(res))

## Max of a resource. Mana grows with Max Mana (Intellect); Energy / Rage stay at 100.
func resource_max(res: String) -> float:
	if res == "mana":
		return maxf(get_stat(Stats.MAX_MANA), 1.0)
	if res == "energy":
		return RESOURCE_MAX + _talent("lightning_deep_reserves")   # Deep Reserves
	return RESOURCE_MAX

func _tick_resources(delta: float) -> void:
	if is_dead():
		return
	_gain("mana", MANA_REGEN * mana_unit() * delta)
	_gain("energy", energy_regen(ENERGY_REGEN, _talent("lightning_quick_charge")) * delta)   # Quick Charge
	_gain("rage", -rage_decay(RAGE_DECAY, _talent("shadow_thick_blood")) * delta)   # Thick Blood

# --- Natural health regeneration (WoW-style) ------------------------------------------
# A trickle in combat, fast once the fight is over (after a short delay).
# Rates are % of max health per second, in balance.gd.

var _regen_carry := 0.0          # fractional health not applied yet
var _out_of_combat_since := 0.0  # when combat last ended

func _tick_health_regen(delta: float) -> void:
	if is_dead() or health >= max_health or PACTS.bleed_pct(pact_id()) > 0.0:   # (Pact of the Restless: none at all)
		_regen_carry = 0.0
		return
	var now := Time.get_ticks_msec() / 1000.0
	var pct := Balance.HP_REGEN_IN_COMBAT_PCT
	if not in_combat:
		pct = Balance.HP_REGEN_OUT_OF_COMBAT_PCT if now - _out_of_combat_since >= Balance.HP_REGEN_OOC_DELAY \
			else Balance.HP_REGEN_IN_COMBAT_PCT
	_regen_carry += float(max_health) * pct / 100.0 * delta
	if _regen_carry < 1.0:
		return
	var amount := int(_regen_carry)
	_regen_carry -= amount
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)
	_bus().player_health_changed.emit(health, max_health)

# --- Cooldowns -------------------------------------------------------------------

var cooldowns := {}   # ability id -> seconds remaining

# --- Global cooldown ---------------------------------------------------------------
# Starting a cast or using an instant ability puts every other GCD ability on
# a short shared cooldown. 1.5 s, sped up by 40% of your Haste (20% haste -> 8%
# faster), never below GCD_MIN. Trinket buttons are off the GCD.
const GCD_BASE := Balance.GCD_BASE
const GCD_HASTE_SHARE := Balance.GCD_HASTE_SHARE
const GCD_MIN := Balance.GCD_MIN
var gcd_left := 0.0
var gcd_total := GCD_BASE
var _acting := false   # inside use_ability (to catch instant abilities going off)
var _acted := false

func gcd_duration() -> float:
	var haste := get_stat(Stats.HASTE) * GCD_HASTE_SHARE
	return maxf(GCD_BASE / Stats.haste_mult(haste), GCD_MIN)

static func on_gcd(id: String) -> bool:
	return id != "" and id != "revive" and not Abilities.is_trinket_slot(id) and not INTERRUPT_LOCKOUT.has(id) \
		and not Abilities.OFF_GCD.has(id)

## Interrupts (off the global cooldown, like in WoW): seconds the target can't cast afterwards.
const INTERRUPT_LOCKOUT := Balance.INTERRUPT_LOCKOUT

func _start_gcd() -> void:
	gcd_total = gcd_duration()
	if _cold_snap > 0.0:   # Cold Snap: a freeze shortened this GCD
		gcd_total = maxf(gcd_total - _cold_snap, Balance.COLD_SNAP_MIN_GCD)
		_cold_snap = 0.0
	if status != null and status.has(SPLIT_SECOND_FX):   # Split Second: every GCD is shorter
		gcd_total = split_second_gcd(gcd_total)
	gcd_left = gcd_total

# --- Spell queue (WoW-style) ------------------------------------------------------------
# A GCD ability pressed in the last SPELL_QUEUE_WINDOW seconds of a cast or of
# the global cooldown is remembered and fires the instant it's allowed, so
# chained spells flow without dead gaps. A newer press replaces the queued one;
# moving (cancelling the cast) or dying clears it. Channels aren't queued through.

var _queued := ""        # queued ability id ("" = none)
var _queued_at := 0.0

## Seconds until a GCD ability could go off (0 = now). Channels count as "long".
func _busy_time() -> float:
	var wait := gcd_left
	if casting:
		wait = maxf(wait, INF if cast_is_channel else maxf(cast_timer, 0.0))
	return wait

## The ability waiting in the queue ("" = none). The action bar highlights it.
func queued_ability() -> String:
	return _queued

func clear_queue() -> void:
	_queued = ""

## Fire the queued ability as soon as nothing blocks it.
func _fire_queued() -> void:
	if _queued == "":
		return
	if is_dead() or Time.get_ticks_msec() / 1000.0 - _queued_at > Balance.SPELL_QUEUE_WINDOW + 0.3:
		_queued = ""   # too old (something else held it up)
		return
	if _busy_time() > 0.0:
		return
	var id := _queued
	_queued = ""
	use_ability(id)

func cooldown_left(id: String) -> float:
	if Abilities.is_trinket_slot(id):
		var item := _trinket_item(id)
		var rl := get_node_or_null("RuneListener")
		return rl.use_cooldown_left(item) if rl and item != "" else 0.0
	# The GCD shows on every GCD button. Interrupts and Grounding Surge are off
	# it, so it never holds them up.
	var left := float(cooldowns.get(id, 0.0))
	if id == STORM_ARROW_ID and quiver_loaded():
		left = 0.0   # Loaded Quiver: its arrows ignore the cooldown
	if id == BLIGHT_ID and interest_ready():
		left = 0.0   # Interest: the instant Blight ignores the rune's cooldown
	return maxf(left, gcd_left if on_gcd(id) else 0.0)

## Full cooldown of an action-bar button (for the cooldown sweep).
func cooldown_total(id: String) -> float:
	if Abilities.is_trinket_slot(id):
		var use := Items.use_effect_of(_trinket_item(id))
		return float(use.internal_cooldown) if use else 1.0
	var own := 0.0 if (id == STORM_ARROW_ID and quiver_loaded()) else float(cooldowns.get(id, 0.0))   # (Loaded Quiver)
	if on_gcd(id) and gcd_left > own:
		return gcd_total   # the sweep is the global cooldown right now
	if id == BLIGHT_ID and own > 0.0 and not interest_ready():
		return Balance.OPEN_WOUND_COOLDOWN   # Rune of the Open Wound: Blight has a cooldown
	var res := Abilities.get_resource(id)
	return Abilities.cooldown_of(res) if res else 1.0

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
	var arcane_rate := _arcane_rate()   # Lapse, Interval Ward: my Arcane spells recover faster
	var clock := _talent("arcane_running_clock") if not cooldowns.is_empty() else 0.0   # Running Clock: so does everything Arcane
	var plain := arcane_rate == 1.0 and clock <= 0.0
	var pact_rate := PACTS.cooldown_rate(pact_id(), pact_broken())   # Pact of the Sidestep: every cooldown
	for id in cooldowns.keys():
		var step := delta if plain else delta * arcane_cooldown_rate(arcane_rate, _is_arcane_spell(str(id)),
			_in_arcane_book(str(id)), clock)
		cooldowns[id] = float(cooldowns[id]) - step * pact_rate
		if cooldowns[id] <= 0.0:
			cooldowns.erase(id)
	_tick_borrowed_time()   # Borrowed Time: a long cooldown just came back?
	_tick_ice_shards(delta)
	_tick_vent_charges(delta)

# --- Ice Shards: charges, and firing one shard per charge ---------------------------
# Up to ICE_SHARDS_MAX_CHARGES charges: one every ICE_SHARDS_RECHARGE seconds, one
# for every Frost spell you cast, and (Splintering Cold talent) a chance on any
# spell. While shards are firing no charges are gained (the recharge waits too).

var ice_shard_charges: int = Balance.ICE_SHARDS_MAX_CHARGES
var _shard_recharge := 0.0
var _shards_left := 0   # shards still to fire from the current volley

func shards_firing() -> bool:
	return _shards_left > 0

## Seconds until the next natural charge (0 when full).
func shard_recharge_left() -> float:
	if ice_shard_charges >= Balance.ICE_SHARDS_MAX_CHARGES:
		return 0.0
	return maxf(Balance.ICE_SHARDS_RECHARGE - _shard_recharge, 0.0)

func _tick_ice_shards(delta: float) -> void:
	if ice_shard_charges >= Balance.ICE_SHARDS_MAX_CHARGES:
		_shard_recharge = 0.0
		return
	if shards_firing():
		return
	_shard_recharge += delta
	if _shard_recharge >= Balance.ICE_SHARDS_RECHARGE:
		_shard_recharge = 0.0
		gain_ice_shard()

## +1 charge (no-op while firing or full).
func gain_ice_shard() -> void:
	if shards_firing() or ice_shard_charges >= Balance.ICE_SHARDS_MAX_CHARGES:
		return
	ice_shard_charges += 1

func _on_spell_cast_for_shards(id: String) -> void:
	if id == "iceshards" or is_dead():
		return
	var pd := get_node_or_null("/root/PlayerData")
	if pd == null or not pd.has_ability("iceshards"):
		return
	var tags := Abilities.tags_of(id)
	if not tags.has("Spell"):
		return
	if tags.has("Frost"):
		gain_ice_shard()
	var chance: float = pd.talent_value("frost_shard_proc")
	if chance > 0.0 and randf() * 100.0 < chance:
		gain_ice_shard()

## Fire every charge at the target, one shard per ICE_SHARDS_INTERVAL. If the
## target dies mid-volley the rest go to your current target (or fizzle).
func _fire_ice_shards(dmg: float) -> void:
	var n := ice_shard_charges
	ice_shard_charges = 0
	_shards_left = n
	var tgt := target
	for i in n:
		get_tree().create_timer(Balance.ICE_SHARDS_INTERVAL * i).timeout.connect(func():
			_shards_left = maxi(_shards_left - 1, 0)
			if not is_alive():
				return
			var aim: Node3D = tgt
			if aim == null or not is_instance_valid(aim) or not aim.is_alive():
				aim = target if _has_valid_target() else null
			if aim:
				FROST_BOLT.spawn(get_tree().current_scene, _muzzle(), aim, self, false, "iceshards", dmg)
				_on_shard_fired(aim))

# --- Talent hooks ---------------------------------------------------------------------

## Multiplier for slows you apply with these tags (StatusContainer asks). No
## talent strengthens slows right now (Deep Chill was removed).
func slow_mult(_tags: PackedStringArray) -> float:
	return _slow_mult_now   # (1 unless Aftershock is being applied: its rank sets the strength)

## Multiplier for shields (absorbs) you apply (Rime Ward).
func absorb_mult() -> float:
	var pd := get_node_or_null("/root/PlayerData")
	return 1.0 + (float(pd.talent_value("frost_absorb")) / 100.0 if pd else 0.0)

func _talent(key: String, field: String = "values") -> float:
	var pd := get_node_or_null("/root/PlayerData")
	return float(pd.talent_value(key, field)) if pd else 0.0

## Blizzard's radius (plus whatever a talent adds: Abilities.RADIUS_TALENTS; none right now).
func blizzard_radius() -> float:
	return float(Abilities.get_resource("blizzard").radius) + Abilities.radius_bonus("blizzard")

## Extra seconds on effects you apply (StatusContainer asks). Deep Hoarfrost.
func effect_duration_bonus(res: Resource) -> float:
	# (Deep Hoarfrost, Long Burn, Thick Pitch, Lingering Frost: one list, shared
	# with the tooltips, so what they say is what happens.)
	return Abilities.effect_time_bonus(res, _talent)

## Every hit you deal, before its damage is worked out (CombatSystem ->
## SignalBus.damage_modify): talent damage bonuses and threat changes.
func _on_damage_modify(info: RefCounted) -> void:
	if is_same(info.target, self):
		_last_hit_by = info.source   # Ice Floe: who broke my shield
		# Numbing Cold: less damage from enemies I slowed recently.
		var dr := _talent("frost_slow_dr")
		if dr > 0.0 and _slowed_recently(info.source):
			info.add_bonus(-dr, "Numbing Cold")
		# Cool Under Fire: tougher while Cool Head is up.
		var cuf := _talent("fire_cool_under_fire")
		if cuf > 0.0 and cool_head_active():
			info.add_bonus(-cuf, "Cool Under Fire")
		# Heat Sink: part of every hit is stored instead (see _on_hit_taken).
		if status and status.has(HEAT_SINK_ID):
			info.add_bonus(-Balance.HEAT_SINK_PCT, "Heat Sink")
		# Warm Blood: less damage from an enemy that carries one of my burns.
		var warm := _talent("fire_warm_blood")
		if warm > 0.0 and _my_burn_on(info.source):
			info.add_bonus(-warm, "Warm Blood")
		# Brand: an enemy carrying my brand hits me for less.
		if info.source != null and is_instance_valid(info.source) and info.source is Node:
			var brand_st: Node = info.source.get_node_or_null("Status")
			if brand_st and brand_st.has_from(BRAND_FX_ID, self):
				info.add_bonus(-(Balance.BRAND_PCT + _talent("fire_deep_brand")), "Brand")   # + Deep Brand
		_reflection_talents_incoming(info)   # Empty Room, Bent Light
		_guard_incoming(info)   # Reflex Arc, Faraday Guard
		_crossed_incoming(info) # Crossed Strings: part of it goes to an enemy
		_pact_incoming(info)    # my Pact: more or less damage taken
		return
	if info.source != self:
		return
	_pact_outgoing(info)        # my Pact: more or less damage dealt
	# Scatter: the darts of the Sigil Darts it split hit harder.
	if _bolt_tag == SCATTER_FX and str(info.ability_id) == SIGIL_DARTS_ID:
		info.add_bonus(Balance.SCATTER_PCT, SCATTER_LABEL)
	# Crucible: enemies standing in MINE take more periodic Fire damage from me
	# (own only: a party member's Crucible does nothing for my burns).
	if info.is_dot and str(info.damage_type) == "fire" and info.target is Node3D \
			and CRUCIBLE.covers(get_tree(), info.target, "me"):
		info.add_bonus(Balance.CRUCIBLE_DOT_PCT, "Crucible")
	# Lingering Embers: my periodic Fire damage (burns and burning ground) hits harder.
	if info.is_dot and str(info.damage_type) == "fire":
		var embers := _talent("fire_lingering_embers")
		if embers > 0.0:
			info.add_bonus(embers, "Lingering Embers")
	# Controlled Burn: my Fire spells and abilities make less threat.
	if info.tags.has("Fire"):
		var calm := _talent("fire_controlled_burn")
		if calm > 0.0:
			info.threat_multiplier *= 1.0 - calm / 100.0
	# Calm Current: the same for my Lightning spells and abilities.
	if info.tags.has("Lightning"):
		var calm_current := _talent("lightning_calm_current")
		if calm_current > 0.0:
			info.threat_multiplier *= 1.0 - calm_current / 100.0
	# Light Touch: and for my Arcane spells and abilities.
	if info.tags.has("Arcane"):
		var light_touch := _talent("arcane_light_touch")
		if light_touch > 0.0:
			info.threat_multiplier *= 1.0 - light_touch / 100.0
	var id := str(info.ability_id)
	_borrowed_time_hit(info, id)   # Borrowed Time: the next spell or ability after a long cooldown comes back
	_open_talents_modify(info)   # Feed the Flames, Change of Pace, Dig In
	_shadow_talents_modify(info, id)   # Slow Death, Finish It, Inevitable, Spite
	_empower_weapon_ability(info, id)   # Static Step, Polar Strike's charge
	# Running on Empty: with little Energy left, my Lightning spells and abilities hit harder.
	var empty := _talent("lightning_running_on_empty")
	if empty > 0.0 and running_on_empty(str(info.damage_type), info.tags, float(resources["energy"])):
		info.add_bonus(empty, "Running on Empty")
	# Standing Charge: planted in Grounding Surge, my Lightning damage keeps growing.
	if str(info.damage_type) == "lightning":
		var standing := standing_charge_bonus()
		if standing > 0.0:
			info.add_bonus(standing, "Standing Charge")
	# High Voltage: with a nearly full bar, all my Lightning damage is higher.
	var high := _talent("lightning_high_voltage")
	if high > 0.0 and high_voltage(str(info.damage_type), float(resources["energy"])):
		info.add_bonus(high, "High Voltage")
	# Counter-Charge: Return Stroke's own hit (not the arcs of its capstone) hits harder.
	if id == RETURN_STROKE_ID and not info.is_proc:
		var counter := _talent("lightning_counter_charge")
		if counter > 0.0:
			info.add_bonus(counter, COUNTER_CHARGE_LABEL)
	# Practiced Hand: Swift Cut hits harder for each Trace I hold.
	if id == SWIFT_CUT_ID and not info.is_proc:
		var practiced := practiced_hand_pct(_talent("arcane_practiced_hand"), traces())
		if practiced > 0.0:
			info.add_bonus(practiced, "Practiced Hand")
	# Fine Edge: with a weapon in each hand, my Arcane abilities hit harder.
	if info.tags.has("Arcane") and info.tags.has("Ability"):
		var edge := _talent("arcane_fine_edge")
		if edge > 0.0 and has_dual_wield():
			info.add_bonus(edge, "Fine Edge")
	# Sharp Edges: my Reflections hit harder when they shatter.
	if id == REFLECTION_SHATTER_ID:
		var sharp := _talent("arcane_sharp_edges")
		if sharp > 0.0:
			info.add_bonus(sharp, SHARP_EDGES_LABEL)
	# On the Beat: Missed Beat hits harder.
	if id == MISSED_BEAT_ID and not info.is_proc:
		var on_beat := _talent("arcane_on_the_beat")
		if on_beat > 0.0:
			info.add_bonus(on_beat, ON_THE_BEAT_LABEL)
	# Third Beat: Cadence's third strike hits harder.
	if id == CADENCE_ID and _cadence_third:
		var beat := _talent("lightning_third_beat")
		if beat > 0.0:
			info.add_bonus(beat, "Third Beat")
	# White Heat: while I hold full Heat, the Fire damage of my abilities is higher
	# (the same hits Heat itself boosts: abilities and their burns, never spells).
	if str(info.damage_type) == "fire" and info.tags.has("Ability"):
		var white := white_heat_bonus(heat_stacks(), _talent("fire_white_heat"))
		if white > 0.0:
			info.add_bonus(white, "White Heat")
	# Shatterpoint: every shatter hit (tagged "Shatter", whatever its name) hits harder.
	if info.tags.has("Shatter"):
		var sp := _talent("frost_shatterpoint")
		if sp > 0.0:
			info.add_bonus(sp, "Shatterpoint")
	# Chilling Presence: more threat on enemies I slowed recently.
	var tp := _talent("frost_slow_threat")
	if tp > 0.0 and _slowed_recently(info.target):
		info.threat_multiplier *= 1.0 + tp / 100.0
	# Menace runes: more threat from damage of their type.
	var rl := get_node_or_null("RuneListener")
	if rl:
		var menace: float = rl.passive_threat_pct(str(info.damage_type))
		if menace > 0.0:
			info.threat_multiplier *= 1.0 + menace / 100.0
	# Splintering: an Ice Shard hitting a Frozen / Rime Shelled enemy splinters
	# (checked before the hit, since the hit may break the shell).
	if id == "iceshards" and not info.is_proc and _talent("frost_splinter") > 0.0 \
			and info.target and is_instance_valid(info.target):
		var sst: Node = info.target.get_node_or_null("Status")
		if sst and (sst.has_from("frozen", self) or sst.has_from("rime_shell_foe", self)):   # mine only (a shell counts for its whole time)
			_splinter.call_deferred((info.target as Node3D).global_position, info.target.get_instance_id())
	# Kiln Blast: more damage to a target carrying my Immolate.
	if id == "kilnblast" and info.target and is_instance_valid(info.target):
		var kst: Node = info.target.get_node_or_null("Status")
		if kst and kst.has_from("immolate", self):
			info.add_bonus(Balance.KILN_BLAST_IMMOLATE_PCT + _talent("fire_stoked_kiln"), "Kiln Blast")   # + Stoked Kiln
	# Third Bite: the Winter's Bite that Freezes hits harder.
	if id == "froststrike" and _bite_freezing:
		var third := _talent("frost_third_bite")
		if third > 0.0:
			info.add_bonus(third, "Third Bite")
	# Pinning Frost: Frost Arrow hits a target rooted by my Icepin harder (own only).
	if id == "frostarrow" and info.target and is_instance_valid(info.target):
		var pin := _talent("frost_pinning_frost")
		if pin > 0.0 and _icepin_root_on(info.target):
			info.add_bonus(pin, "Pinning Frost")
	# Shatter Shot: more damage to a target I have Frozen (own only).
	if id == SHATTER_SHOT_ID:
		_shatter_shot_modify(info)
	_cold_draw_mark(info, id)   # Cold Draw: arrows into a target I already Chilled or Froze
	# Marked Prey: my Ice Shards hit the target carrying MY Coldmark harder.
	if id == "iceshards" and info.target and is_instance_valid(info.target):
		var prey := _talent("frost_marked_prey")
		if prey > 0.0:
			var mark_st: Node = info.target.get_node_or_null("Status")
			if mark_st and mark_st.has_from(COLDMARK_FX, self):
				info.add_bonus(prey, "Marked Prey")
	# Coldspike: more damage to a target I have Frozen (own only).
	if id == "coldspike" and info.target and is_instance_valid(info.target):
		var cst: Node = info.target.get_node_or_null("Status")
		if cst and cst.has_from("frozen", self):
			info.add_bonus(Balance.COLDSPIKE_FROZEN_PCT + _talent("frost_piercing_cold"), "Coldspike")   # + Piercing Cold
	# Bitter Cold: more damage to targets I Chilled (own only).
	var bonus := _talent("frost_chilled_dmg")
	if bonus > 0.0 and info.target and is_instance_valid(info.target):
		var st: Node = info.target.get_node_or_null("Status")
		if st and st.has_from("chilled", self):
			info.add_bonus(bonus, "Bitter Cold")
	# Deep Hoarfrost: Hoarfrost's periodic ticks and its burst hit harder.
	if id == "dot_hoarfrost" or id == "burst_hoarfrost":
		var hb := _talent("frost_hoarfrost")
		if hb > 0.0:
			info.add_bonus(hb, "Deep Hoarfrost")
	# Cold Discipline: Frost spells make less threat.
	if info.tags.has("Frost") and info.tags.has("Spell"):
		var less := _talent("frost_discipline", "values2")
		if less > 0.0:
			info.threat_multiplier *= 1.0 - less / 100.0

## After every hit you land (SignalBus.player_hit).
func _on_hit_talents(ability_id: String, tgt: Node, amount: int, _crit: bool, is_proc: bool) -> void:
	if tgt == null or not is_instance_valid(tgt) or not tgt.is_alive():
		return
	var periodic := ability_id.begins_with("dot_") or ability_id.begins_with("burst_")
	# Fresh Tinder: abilities (not procs, not ticks) may feed my Immolate on the target.
	var tinder := _talent("fire_fresh_tinder")
	if tinder > 0.0 and not is_proc and not periodic and Abilities.tags_of(ability_id).has("Ability") \
			and randf() * 100.0 < tinder:
		_feed_immolate(tgt)
	# Brittle Rime: direct damage may make your Hoarfrost on the target burst early.
	var burst := _talent("frost_hoarfrost_burst")
	if burst > 0.0 and not periodic and ability_id != "hoarfrost" and amount > 0:
		var st: Node = tgt.get_node_or_null("Status")
		if st and st.has_method("has_from") and st.has_from("hoarfrost", self) and randf() * 100.0 < burst:
			st.burst_now("hoarfrost", self)   # Brittle Rime: burst now, Hoarfrost stays on
	# Deep Freeze: Frost spells and abilities (not ticks or procs) may Freeze the target.
	var df := _talent("frost_deep_freeze")
	if df > 0.0 and not is_proc and not periodic and randf() * 100.0 < df and tgt.is_alive():
		var ftags := Abilities.tags_of(ability_id)
		if ftags.has("Frost") and (ftags.has("Spell") or ftags.has("Ability")):
			_apply_freeze(tgt, ftags)

# --- Slam (instant melee, weapon damage) -------------------------------------------


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
		_error("%s is not ready yet" % Abilities.ability_name("slam"))
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
	cooldowns["slam"] = float(Abilities.get_resource("slam").cooldown)
	var dir := target.global_position - global_position
	rotation.y = atan2(-dir.x, -dir.z)
	var hit := target
	_gain("rage", float(Abilities.info("slam").get("generates", 50)))
	deal_damage(hit, _weapon_hit(w, Abilities.get_resource("slam")), "slam")
	_bus().cast_finished.emit("slam")
	_slash_effect()
	_slash_effect()   # doubled for a heavier hit

# --- Execute (instant melee, 3x weapon damage, 50 Rage) ------------------------------

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
	deal_damage(target, _weapon_hit(w, Abilities.get_resource("execute")), "execute")
	_bus().cast_finished.emit("execute")
	_slash_effect()
	_slash_effect()
	_slash_effect()

# --- Steady Shot (1 s cast, bow, weapon damage; can move while casting) -------------


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
	_begin_spell("steadyshot", Abilities.ability_name("steadyshot"), float(Abilities.get_resource("steadyshot").cast_time))

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
	ARROW.spawn(get_tree().current_scene, _muzzle(),
		target, self, _weapon_hit(w, Abilities.get_resource("steadyshot")), "steadyshot")

func has_valid_target() -> bool:
	return _has_valid_target()

## Is the current target close enough for ability `id`? (Action bar grays out
## abilities that would fail with "Target out of range".) True when the ability
## needs no target or there is no target (other checks cover that).
func target_in_range(id: String) -> bool:
	var res := Abilities.get_resource(id)
	if res == null or not res.requires_target or not _has_valid_target():
		return true
	if Abilities.uses_weapon_reach(id):
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
const Runes = preload("res://scripts/runes.gd")
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
	if auto_windup < auto_interval(float(w["attack_interval"]), haste_mult(), overdrive_active(), attack_speed_bonus()):   # (Overdrive, Tempo: faster swings)
		return
	auto_windup = 0.0
	# Snap to face the enemy we're hitting.
	var dir := enemy.global_position - global_position
	rotation.y = atan2(-dir.x, -dir.z)
	if w["weapon"] == "ranged":
		ARROW.spawn(get_tree().current_scene, _muzzle(),
			enemy, self, float(w["damage"]) * Balance.AUTO_ATTACK_MULT, "auto_ranged")
	else:
		deal_damage(enemy, float(w["damage"]) * Balance.AUTO_ATTACK_MULT, "auto_melee")
		_slash_effect(heat_tint(heat_stacks()))   # the swing glows hotter with Heat
	# Auto-attacks and auto-shots build rage when you're playing a rage user.
	if _has_rage_spender():
		_gain("rage", AUTO_ATTACK_RAGE)

## Rage per auto-attack / auto-shot (only with a rage spender on the action bar).
const AUTO_ATTACK_RAGE := Balance.AUTO_ATTACK_RAGE

## A rage-costing ability on your action bar. The base kit (Slam, Execute) is
## always known, so "on the bar" is what says you're actually playing rage.
func _has_rage_spender() -> bool:
	var pd := get_node_or_null("/root/PlayerData")
	if pd == null:
		return false
	for slot_id in pd.action_bar:
		for id in bar_abilities(slot_id):
			if id != "" and Abilities.resource_of(id) == "rage" and Abilities.cost_of(id) > 0:
				return true
	return false

# Only the current target, and only if it's in range and visible.
# Nothing targeted = no auto-attack.
func _auto_attack_target(reach: float) -> Node3D:
	if not _has_valid_target():
		return null
	if not _in_weapon_range(target, reach) or _target_error(target) != "":
		return null   # auto-attacks need line of sight (and facing, if REQUIRE_FACING)
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
		return
	# Party members: picked on screen (they have no clickable collision).
	var ally := _ally_at(screen_pos, cam)
	if ally:
		_set_target(null)
		friendly_target = ally
	# Clicking empty ground keeps your target (Esc clears it).

## Esc: drop the current enemy / friendly target. True if there was one.
func clear_target() -> bool:
	var had := _has_valid_target() or has_friendly_target()
	_set_target(null)
	friendly_target = null
	return had

func can_see(node: Node3D) -> bool:
	return Combat.can_see(get_world_3d(), self, node)

## Like WoW: targeted spells and attacks need the target in your front half.
const FACING_ARC := 180.0

func is_facing(node: Node3D) -> bool:
	return Combat.is_in_front(self, node, FACING_ARC)

## Facing requirement (WoW-style "you must be facing your target"): off for now,
## line of sight still applies. Flip to true to bring it back.
const REQUIRE_FACING := false

## Why `node` can't be cast at / attacked right now ("" = it can).
func _target_error(node: Node3D) -> String:
	if not can_see(node):
		return "Target not in line of sight"
	if REQUIRE_FACING and not is_facing(node):
		return "You must be facing your target"
	return ""

signal action_error(message: String)

func _error(msg: String) -> void:
	if _macro_quiet:
		_macro_errors.append(msg)   # a macro reports one error at most, when nothing in it worked
		return
	action_error.emit(msg)
	_bus().action_error.emit(msg)

# --- Macros (scripts/core/macros.gd) ----------------------------------------------------
# One press runs every line of the macro from the top. Abilities that are off
# the global cooldown (trinkets, interrupts) all go off; of those on it, the
# first one that can be used is, and the rest are skipped for this press.

const Macros = preload("res://scripts/core/macros.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")
var _macro_quiet := false
var _macro_errors: Array[String] = []
var _macro_seq := {}        # "<macro id>:<step>" -> {"at": next index, "t": time of the last press}
var _use_result := false    # did the last use_ability() make something go off?

func _run_macro(id: String) -> void:
	var m := Macros.find(id)
	if m.is_empty():
		_error("That macro no longer exists")
		return
	var steps: Array = Macros.parse(str(m.get("text", "")))["steps"]
	if steps.is_empty():
		_error("%s does nothing yet (Esc > Macros)" % str(m.get("name", "This macro")))
		return
	_macro_quiet = true
	_macro_errors.clear()
	var did := false
	var gcd_taken := false
	var now := Time.get_ticks_msec() / 1000.0
	for i in steps.size():
		var st: Dictionary = steps[i]
		var ability := ""
		var seq_key := "%s:%d" % [id, i]
		var seq: Dictionary = {}
		if st["kind"] == "sequence":
			seq = _macro_seq.get(seq_key, {"at": 0, "t": now})
			if float(st["reset"]) > 0.0 and now - float(seq["t"]) > float(st["reset"]):
				seq["at"] = 0
			var list: Array = st["abilities"]
			seq["at"] = int(seq["at"]) % list.size()
			ability = str(list[int(seq["at"])])
		else:
			ability = str(st["ability"])
		if on_gcd(ability) and gcd_taken:
			continue
		if _macro_use(ability):
			did = true
			gcd_taken = gcd_taken or on_gcd(ability)
			if st["kind"] == "sequence":
				seq["at"] = int(seq["at"]) + 1
		if st["kind"] == "sequence":
			seq["t"] = now
			_macro_seq[seq_key] = seq
	_macro_quiet = false
	if not did and not _macro_errors.is_empty():
		_error(_macro_errors[0])

## Use `id` for a macro. True if it went off, started casting / aiming, or was queued.
func _macro_use(id: String) -> bool:
	if Macros.is_macro(id):
		return false   # a macro can't run another macro
	var cast_before := current_spell if casting else ""
	var place_before := placing_id if placing else ""
	var queue_before := _queued
	var cd_before := float(cooldowns.get(id, 0.0))
	_use_result = false
	use_ability(id)
	if _use_result:
		return true
	if casting and current_spell == id and cast_before != id:
		return true
	if placing and placing_id == id and place_before != id:
		return true
	if _queued == id:
		return true   # waiting in the spell queue (also when an earlier press put it there)
	return float(cooldowns.get(id, 0.0)) > cd_before + 0.01

## Abilities an action-bar id stands for: itself, or everything a macro can use.
static func bar_abilities(id: String) -> Array[String]:
	if Macros.is_macro(id):
		return Macros.abilities_of(id)
	var one: Array[String] = [id]
	return one

func _set_target(new_target: Node3D) -> void:
	if new_target == target:
		return
	if is_instance_valid(target):
		target.set_targeted(false)
	target = new_target
	if target:
		friendly_target = null   # one target at a time
		target.set_targeted(true)
		if not target.died.is_connected(_on_target_died):
			target.died.connect(_on_target_died)

func _on_target_died() -> void:
	target = null
	if casting and current_spell in ENEMY_BOLTS:
		_cancel_cast()

func _has_valid_target() -> bool:
	return is_instance_valid(target) and target.is_alive()

# --- Frost bolt --------------------------------------------------------------

func _start_cast() -> void:
	_start_bolt("frostbolt")

## Frost Bolt, Firebolt, Lightning Bolt, Shadow Bolt: cast at the enemy target.
func _start_bolt(id: String) -> void:
	if casting or not is_on_floor():
		return
	if float(cooldowns.get(id, 0.0)) > 0.0:
		_error("%s is not ready yet" % Abilities.ability_name(id))
		return
	if not _has_valid_target():
		_error("No target")
		return
	if id == "rekindle" and _rekindle_targets(target).is_empty():
		_error("You have nothing burning there")
		return
	if not target_in_range(id):
		_error("Target out of range")
		return
	var sight_err := _target_error(target)
	if sight_err != "":
		_error(sight_err)
		return
	if not can_afford(id, true):
		return
	_begin_spell(id, Abilities.ability_name(id), CAST_TIME)

## Cast times and channel durations are shortened by Haste.
func _begin_spell(spell: String, display_name: String, duration: float, channel: bool = false) -> void:
	if not change_state(PState.CHANNELING if channel else PState.CASTING):
		return
	# The ability's data is the single source of truth (the tooltip reads the
	# same value), so tooltip and game always agree.
	var ab_res := Abilities.get_resource(spell)
	if ab_res and float(ab_res.cast_time) > 0.0:
		duration = float(ab_res.cast_time)
	if Abilities.is_a(spell, "frostbolt"):
		duration = maxf(duration - _talent("frost_bolt_cast"), 0.2)   # Quickened Frost
	elif spell == "lightningbolt":
		duration = maxf(duration - _talent("lightning_quick_fuse"), 0.2)   # Quick Fuse
	elif spell == GLACIAL_DRAW_ID:
		duration = thin_ice_cast(duration, _talent("frost_thin_ice"), _chilled_by_me(target))   # Thin Ice
	elif spell == HOIST_ID:
		duration = heave_cast(duration, strings_on(_cast_target), _capstone("shadow_heave"))   # Heave's capstone
	elif spell == ERODE_ID:
		duration = deep_call_cast(duration, _talent("shadow_deep_call"), decay_open_on(target))   # Deep Call
	duration /= haste_mult()
	if Abilities.is_a(spell, "frostbolt") and frozen_instinct_ready():
		duration = 0.05   # Frozen Instinct: instant (released next frame)
		_instinct_cast = true
	_conc_cast = not _instinct_cast and concentrated_fire_ready(spell)
	if _conc_cast:
		duration = 0.05   # Concentrated Fire: instant (released next frame)
	_flicker_cast = not _instinct_cast and not _conc_cast and flicker_ready(spell)
	if _flicker_cast:
		duration = 0.05   # Flicker: this Lightning Bolt is instant (released next frame)
	_bottled_cast = not _instinct_cast and not _conc_cast and not _flicker_cast and bottled_ready(spell)
	if _bottled_cast:
		duration = 0.05   # Rune of Bottled Lightning: this Discharge is instant (released next frame)
	if not channel and not _instinct_cast and not _conc_cast and not _flicker_cast and not _bottled_cast and overture_ready(spell):
		duration = 0.05   # Rune of the Overture: the first cast after a boom is instant
		status.remove(OVERTURE_FX)
	# Cinder Step: this cast can be finished on the move (instant ones don't need it).
	_cinder_cast = not channel and not _conc_cast and not _instinct_cast and cinder_step_ready(spell)
	# Glint: this cast or channel can go on while I move (instant ones don't need it).
	_glint_cast = not _conc_cast and not _instinct_cast and not _flicker_cast and not _bottled_cast \
		and not _cinder_cast and glint_ready(spell)
	if _glint_cast and channel and status:
		status.spend_stacks(GLINT_FX, 1)   # a channel is paid for when it starts, and uses Glint up then too (Keep Moving: one of its casts)
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

func _cancel_cast() -> void:
	_instinct_cast = false   # Frozen Instinct stays for the next Frost Bolt
	_conc_cast = false       # so does the Concentrated Fire stack
	_cinder_cast = false     # and Cinder Step's cast on the move
	_flicker_cast = false    # and Flicker's instant Lightning Bolt
	_bottled_cast = false    # and Bottled Lightning's instant Discharge
	_glint_cast = false      # and Glint's cast on the move
	_volley_left = 0         # a broken Ember Volley launches no more embers
	_darts_left = 0          # nor does a broken Sigil Darts launch more darts
	_queued = ""             # a cancelled cast drops whatever was queued behind it
	if casting:
		_bus().cast_interrupted.emit(current_spell)
	casting = false
	current_spell = ""
	current_state = ""

func _release_cast() -> void:
	var spell := current_spell
	var cinder := _cinder_cast
	_cinder_cast = false
	var glint := _glint_cast
	_glint_cast = false
	casting = false
	current_spell = ""
	current_state = ""
	if spell == "revive":
		_finish_revive()   # not a spell: no cost, no cast events
		return
	if spell == "embervolley":
		_ember_volley_tick(true)   # the last ember (the channel was paid for when it started)
		_bus().cast_finished.emit(spell)
		return
	if spell == SIGIL_DARTS_ID:
		_sigil_darts_tick(true)    # the last dart (the same)
		_bus().cast_finished.emit(spell)
		return
	_bus().cast_finished.emit(spell)
	# Casts pay their cost when they complete (a cancelled cast costs nothing).
	var conc := _conc_cast
	_conc_cast = false
	var flick := _flicker_cast
	_flicker_cast = false
	var bottled := _bottled_cast
	_bottled_cast = false
	if not _pay(spell):
		_instinct_cast = false
		return
	if flick and status:
		status.remove(FLICKER_FX)      # Flicker: that was its instant Lightning Bolt
	if bottled and status:
		status.remove(BOTTLED_FX)      # Rune of Bottled Lightning: that was its instant Discharge
	if conc and status:
		status.spend_stacks(CONC_ID)   # Concentrated Fire: one stack per instant cast
	if cinder and status:
		status.remove(CINDER_ID)       # Cinder Step: that was the cast on the move
	if glint and status:
		status.spend_stacks(GLINT_FX, 1)   # Glint: so was this (Keep Moving: one of its casts)
	if Abilities.is_a(spell, "frostbolt") and (_instinct_cast or frozen_instinct_ready()):
		status.remove(INSTINCT_ID)   # Frozen Instinct used up (this bolt was free)
	_instinct_cast = false
	if spell == "steadyshot":
		_release_steady_shot()
		return
	if spell == GLACIAL_DRAW_ID:
		_loose_glacial_draw()
		return
	if spell == "walloffire":
		_raise_fire_wall()
		return
	if spell == BALL_LIGHTNING_ID:
		_launch_ball_lightning()
		return
	if spell == THUNDERHEAD_ID:
		_raise_thunderhead()
		return
	if spell == MIRROR_ID:
		_place_mirror_sigil()
		return
	if spell == COLLAPSE_ID:
		_cast_collapse()
		return
	if spell == PALL_ID:
		_cast_pall()
		return
	if spell == CRUCIBLE_ID:
		_place_crucible(false)
		return
	if spell == "blizzard":
		var bliz := Node3D.new()
		bliz.set_script(BLIZZARD)
		bliz.radius = blizzard_radius()
		bliz.source = self
		bliz.damage = float(Abilities.get_resource("blizzard").damage)
		get_tree().current_scene.add_child(bliz)
		bliz.global_position = cast_point
		var net := get_node_or_null("/root/Net")
		if net:
			net.send_fx("blizzard", cast_point, null, "", {"r": bliz.radius})   # its real size (Endless Winter)
		return
	if spell in SUPPORT_CASTS:
		_release_support(spell)
		return
	var sight_err := _target_error(target)
	if sight_err != "":
		_error(sight_err)
		return
	var bolt_res := Abilities.get_resource(spell)
	var bolt_cd := float(bolt_res.cooldown)
	if bolt_cd > 0.0:
		cooldowns[spell] = bolt_cd   # (Kiln Blast, Leaping Arc)
	if int(bolt_res.resource_generated) > 0:
		_gain(Abilities.resource_of(spell), float(bolt_res.resource_generated))   # (Leaping Arc's Energy)
	if spell == DISCHARGE_ID:
		_discharge(target)
		return
	if spell == FORKED_BOLT_ID:
		_forked_bolt(target)
		return
	if spell == "slowfuse":
		_plant_fuse(target)
		return
	if spell == "rekindle":
		_rekindle(target)
		return
	if spell == COUNTDOWN_ID:
		_plant_countdown(target)
		return
	if spell == UNRAVEL_ID:
		_unravel_cooldowns()   # (then its bolt, like any other)
	if spell == CONVERGENCE_ID:
		# Stronger for each other Arcane spell on cooldown right now.
		FROST_BOLT.spawn(get_tree().current_scene, _muzzle(), target, self, false, spell,
			convergence_coef(float(bolt_res.damage), arcane_cooldowns(CONVERGENCE_ID)))
		return
	if spell == "immolate":
		_immolate_spread(target)   # recast on a target that already has mine: it jumps to others
	if spell == HIGH_NOTE_ID:
		_gain_verses(spell)   # Holy healer: its Verse (its heal comes when it lands: _on_damage_dealt_holy)
	FROST_BOLT.spawn(get_tree().current_scene, _muzzle(), target, self,
		false, spell, float(Abilities.get_resource(spell).damage))

# --- Blizzard (ground-targeted) ------------------------------------------------

## Which ground-targeted spell the circle is for ("blizzard" or "crucible").
var placing_id := "blizzard"

func _begin_placement(id: String = "blizzard") -> void:
	if casting or not is_on_floor():
		return
	if not can_afford(id, true):
		return
	placing = true
	placing_id = id
	# The circle matches the spell's current size (Blizzard's grows with talents).
	var r := float(Abilities.get_resource(id).radius)
	if id == "blizzard":
		r = blizzard_radius()
	elif id == CRUCIBLE_ID:
		r = crucible_radius()   # Deep Crucible
	(aoe_indicator.mesh as QuadMesh).size = Vector2(r * 2.0, r * 2.0)
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
	_tick_downed()
	_tick_cooldowns(_delta)
	_fire_queued()
	_tick_resources(_delta)
	_tick_health_regen(_delta)
	_scan_my_slows()
	_tick_permafrost()
	_tick_fuses()
	_tick_countdowns()
	_tick_decay()
	_tick_grounded()
	_tick_dusk()
	_tick_hounds()
	_tick_strings()
	_tick_hymns()
	_tick_pact(_delta)
	_tick_live_wire()
	_tick_overdrive()
	_tick_standing_charge(_delta)
	_tick_reflections()
	_tick_traces()
	_tick_dig_in(_delta)
	_update_target_ring()
	_update_friendly_ring()
	_update_combat_state()
	if placing:
		_update_placement(get_viewport().get_mouse_position())

func _start_blizzard(point: Vector3) -> void:
	if casting or not is_on_floor():
		return
	cast_point = point
	_begin_spell("blizzard", Abilities.ability_name("blizzard"), BLIZZARD_CAST_TIME)

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
	# (So can the instant casts from Concentrated Fire.)
	# (And the one cast Cinder Step lets you finish while moving.)
	# (And whatever Glint lets you cast or channel on the move.)
	var steady := casting and (current_spell == "steadyshot" or _conc_cast or _cinder_cast or _flicker_cast or _bottled_cast
		or _glint_cast)
	if steady:
		var aimed: bool = current_spell == "steadyshot" or current_spell in ENEMY_BOLTS or current_spell == "embervolley" \
			or current_spell == GLACIAL_DRAW_ID or current_spell == SIGIL_DARTS_ID
		if (aimed and not _has_valid_target()) or (current_spell in SUPPORT_CASTS and not _support_target_ok()):
			_cancel_cast()
			steady = false
		else:
			cast_timer -= delta
			if current_spell == "embervolley":
				_ember_volley_tick()     # a channel on the move launches as it goes, like one standing still
			elif current_spell == SIGIL_DARTS_ID:
				_sigil_darts_tick()
			if not casting:
				steady = false
			elif cast_timer <= 0.0:
				_release_cast()
				steady = false

	if casting and not steady:
		var targeted: bool = current_spell in ENEMY_BOLTS or current_spell == "embervolley" or current_spell == GLACIAL_DRAW_ID \
			or current_spell == SIGIL_DARTS_ID
		var lost_target := targeted and not _has_valid_target()
		if current_spell in SUPPORT_CASTS and not _support_target_ok():
			lost_target = true
		if current_spell == "revive" and not _revive_target_ok():
			lost_target = true
		if input_dir.length() > 0.1 or lost_target:
			_cancel_cast()  # moving interrupts the cast / channel
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			var face_at: Vector3 = target.global_position if targeted else cast_point
			if current_spell in SUPPORT_CASTS:
				face_at = _support_face_point()
			elif current_spell == "revive":
				face_at = _revive_target.global_position
			_face(face_at, delta)
			cast_timer -= delta
			if current_spell == "embervolley":
				_ember_volley_tick()
			elif current_spell == SIGIL_DARTS_ID:
				_sigil_darts_tick()
			if not casting:   # channel ended (broken, or target killed)
				move_and_slide()
				return
			if cast_timer <= 0.0:
				_release_cast()
				_fire_queued()   # the queued spell starts on this same frame
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
			# Standing still while aiming: face the target (or the spot) and hold the cast pose.
			_face(target.global_position if _has_valid_target() else cast_point, delta)
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

const BLINK_DISTANCE := Balance.BLINK_DISTANCE

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
	if bool(res.get("requires_two_hand")) and not has_two_hander():
		_error("Requires a two-handed weapon")
		return
	if bool(res.get("requires_dual_wield")) and not has_dual_wield():
		_error(DUAL_WIELD_ERROR)
		return
	if res.requires_target:
		if not _has_valid_target():
			_error("No target")
			return
		var sight_err := _target_error(target)
		if sight_err != "":
			_error(sight_err)
			return
		# (Static Step and Whiplash need a weapon but reach as far as their own range.)
		var weapon_reach := Abilities.uses_weapon_reach(id)
		if weapon_reach and not _in_weapon_range(target, float(w["attack_range"])):
			_error("Target out of range")
			return
		if not weapon_reach and res.cast_range > 0.0 \
				and global_position.distance_to(target.global_position) > res.cast_range:
			_error("Target out of range")
			return
	var err := _drafted_precheck(id, res, w)
	if err != "":
		_error(err)
		return
	if not _pay(id):
		return
	_hounds_on_ability(id)   # Shadow melee: with no Hounds out, its abilities call them
	var cd_before := float(cooldowns.get(id, 0.0))
	cooldowns[id] = Abilities.cooldown_of(res)   # (with talents: Thick Hide)
	if id == STORM_ARROW_ID:
		_storm_arrow_fired(cd_before)   # Loaded Quiver, Snap Shot
	if INTERRUPT_LOCKOUT.has(id):
		# Interrupts share a cooldown: this one never has less than the shared
		# one, and every other interrupt now waits at least that long too.
		cooldowns.merge(interrupt_cooldowns(id, float(res.cooldown), cooldowns), true)
	if id == VENT_ID:
		_vent_charge_used(float(res.cooldown))   # Hair Trigger: charges instead of one cooldown
	if res.resource_generated > 0:
		_gain(Abilities.resource_of(id), float(Abilities.generated_of(id)))   # (with talents: Honed Edge)
	if res.requires_target and _has_valid_target():
		var dir := target.global_position - global_position
		rotation.y = atan2(-dir.x, -dir.z)
	var muzzle := _muzzle()
	match id:
		STRING_ID, TUG_ID, CRADLE_ID, WRENCH_ID, PULL_TAUT_ID, CUPPED_HANDS_ID, STRING_UP_ID, RESTRING_ID, KNOT_ID, TANGLE_ID, \
				YANK_ID, DOUBLE_THREAD_ID, BEHIND_ID, SLACK_ID, STILL_STANDING_ID, CUT_STRINGS_ID, NOT_FINISHED_ID:
			_string_use(id, res)   # Shadow healer: the Strings
		"lift", "refrain", "antiphon", "shelter", "steadyvoice", "reprise", "swell", "rest", "lastverse", "singmercy", "singchorus", "singvigil":
			_hymn_use(id, res)   # Holy healer: the Hymns
		"hoarfrost":
			FROST_BOLT.spawn(get_tree().current_scene, muzzle, target, self, false, id, 0.0)   # Hoarfrost is its on-hit effect
		"iceshards":
			_fire_ice_shards(float(res.damage))
		"shatteringslam":
			_shattering_slam(target, w, res)
		"rimeslash":
			_rime_slash(w, res)
		"frostnova":
			for e in _enemies_within(float(res.radius)):
				deal_damage(e, float(res.damage), "frostnova")   # Frozen comes from the ability's on-hit effect
			_ring_effect(float(res.radius), Color(0.6, 0.92, 1.0))
		"icebarrier":
			status.apply(StatusContainer.make_buff("icebarrier", Abilities.ability_name(id), "armor", Balance.ICE_BARRIER_ARMOR * _flat_unit(),
				Balance.ICE_BARRIER_TIME, 1, Color(0.6, 0.9, 1.0)), self)
			_ring_effect(1.2, Color(0.6, 0.9, 1.0))
		"blink":
			var from := global_position
			global_position += _flat_forward() * _blink_distance()
			_ring_effect(0.8, Color(0.8, 0.6, 1.0), from)
			_ring_effect(0.8, Color(0.8, 0.6, 1.0))
			_leave_afterimage(from)   # Rune of the Afterimage
		"whirlwind":
			for e in _enemies_within(float(res.radius)):
				deal_damage(e, _weapon_hit(w, res), "whirlwind")
			for i in 3:
				rotation.y += TAU / 3.0
				_slash_effect()
		"battleshout":
			status.apply(StatusContainer.make_buff("battleshout", Abilities.ability_name(id), Stats.ATTACK_POWER, Balance.BATTLE_SHOUT_AP * _flat_unit(),
				Balance.BATTLE_SHOUT_TIME, 1, Color(1.0, 0.6, 0.3)), self)
			_ring_effect(2.0, Color(1.0, 0.6, 0.3))
		"multishot":
			for e in _multishot_targets(float(w["attack_range"])):
				ARROW.spawn(get_tree().current_scene, muzzle, e, self, _weapon_hit(w, res), "multishot")
		"poisonarrow":
			ARROW.spawn(get_tree().current_scene, muzzle, target, self, _weapon_hit(w, res), "poisonarrow")
		"secondwind":
			heal(float(Abilities.HEALS[id]), id)
		# Spell projectiles (tinted by book: Fire, Lightning, Shadow, Holy)
		"groundout":
			_ground_out()
		"corruption", \
				"wrath", "insectswarm", "entanglingroots":
			FROST_BOLT.spawn(get_tree().current_scene, muzzle, target, self, false, id, float(res.damage))
		"intervalward":
			_interval_ward()
		"glint":
			_glint(res)
		# Bow abilities
		"rimefletch":
			_start_rimefletch()
		"coldmark":
			_coldmark(target)
		"icyretreat":
			_icy_retreat(res)
		"flamingarrow", "stormarrow", "arcaneshot", "shadowarrow", "frostarrow", "pitcharrow", "icepin", "shattershot":
			ARROW.spawn(get_tree().current_scene, muzzle, target, self, _weapon_hit(w, res), id)   # (Pitch / Icepin's root are the ability's on-hit effect)
		# --- Frost, second batch ---
		"sleetwave":
			_sleet_wave(res)
		"deepwinter":
			_start_deepwinter()
		"snowward":
			_snow_ward(res)
		"winterhide":
			_start_winter_hide()
		"rimeedge":
			_start_rime_edge()
		"icebreaker":
			_icebreaker(w, res)
		"cinderwing":
			_summon_phoenix()
		# Melee abilities
		"froststrike":
			_winters_bite(target, _weapon_hit(w, res))
			_slash_effect(Abilities.color_of(id))
			_slash_effect(Abilities.color_of(id))
		"searingstrike", "thunderstrike", "arcanestrike", "shadowstrike", \
				"sinisterstrike", "rupture", "eviscerate", "chargededge":
			deal_damage(target, _weapon_hit(w, res), id)
			_slash_effect(Abilities.color_of(id))
			_slash_effect(Abilities.color_of(id))
			if id == "arcanestrike":
				_gain("mana", Balance.ARCANE_STRIKE_MANA * mana_unit())
		# Area bursts around you
		"flamenova":
			for e in _enemies_within(float(res.radius)):
				deal_damage(e, float(res.damage), id)
			_ring_effect(float(res.radius), Abilities.color_of(id))
		"coolhead":
			_start_cool_head()
		"stoke":
			# Eat my Burning on the target: its remaining damage lands now, on top
			# of Stoke's own. It never crits (adjust_crit).
			var burn_st: Node = target.get_node_or_null("Status")
			var burn_left: float = burn_st.dot_left("burning", self) if burn_st else 0.0
			var stoke_net := _net()
			if stoke_net:
				stoke_net.remove_effect(target, self, "burning")   # the host owns enemy effects in a party
			elif burn_st:
				burn_st.remove_from("burning", self)
			deal_damage(target, float(res.damage) + burn_left, id)
			_ring_effect(0.9, Abilities.color_of(id), target.global_position)
		"furnacebreath":
			# Cone of fire in front of you (turned to your target if you have one):
			# damages and interrupts everything in it.
			if _has_valid_target():
				var to_target := target.global_position - global_position
				rotation.y = atan2(-to_target.x, -to_target.z)
			var breath_lock := float(INTERRUPT_LOCKOUT[id])
			var breath_net := _net()
			for e in _enemies_in_cone(float(res.radius), Balance.FURNACE_BREATH_ARC):
				deal_damage(e, float(res.damage), id)
				if breath_net:
					breath_net.interrupt(e, self, breath_lock)   # the host owns enemy casts in a party
				elif is_instance_valid(e) and e.has_method("interrupt"):
					e.interrupt(self, breath_lock)
			_cone_effect(float(res.radius), Balance.FURNACE_BREATH_ARC * 0.5, Abilities.color_of(id))
			_cone_effect(float(res.radius) * 0.6, Balance.FURNACE_BREATH_ARC * 0.5, Color(1.0, 0.9, 0.4))
		"slagskin":
			# The armor comes from Slag stacks (melee hits that don't crit, see _slag_on_hit).
			var slag := StatusContainer.make_buff(SLAG_ID, "Slag Skin", SLAG_ID, 0.0,
				Balance.SLAG_SKIN_TIME, 1, Abilities.color_of(id))
			slag.stat_modifiers = {}
			slag.description = "Enemies that attack you are burned. Your melee hits that do not critically strike add Slag; a melee critical strike shatters it."
			status.apply(slag, self)
			_sync_slag()   # Slag you already carry lasts as long as the fresh Slag Skin
			_ring_effect(1.3, Abilities.color_of(id))
			_ring_effect(0.8, Color(0.25, 0.2, 0.18))
		"brand":
			deal_damage(target, _weapon_hit(w, res), id)   # Branded is the ability's on-hit effect
			_slash_effect(Abilities.color_of(id))
			_ring_effect(0.6, Color(1.0, 0.9, 0.4), target.global_position)
		"anvil":
			# Never crits (adjust_crit), so with Slag Skin up it always adds a stack.
			for e in _enemies_within(float(res.radius)):
				deal_damage(e, _weapon_hit(w, res), id)
			_shield_bash_effect(Abilities.color_of(id))
			_ring_effect(float(res.radius), Abilities.color_of(id))
			_ring_effect(float(res.radius) * 0.55, Color(1.0, 0.9, 0.4))
		"quench":
			# Every stack of Heat goes into this one hit. The Heat is gone before it
			# lands, so the hit gets no Heat bonus of its own; it never crits (adjust_crit).
			var heat := heat_stacks()
			status.remove(HEAT_ID)
			deal_damage(target, quench_coef(_weapon_hit(w, res), heat), id)
			_slash_effect(Color(1.0, 0.9, 0.4))
			_slash_effect(Abilities.color_of(id))
			_ring_effect(0.8, Color(0.85, 0.93, 1.0), target.global_position)   # steam
			if _talent("fire_afterglow") > 0.0:
				_start_afterglow()
		"flare":
			_flare(w, res)
		"cinderguard":
			var guard := StatusContainer.make_buff(CINDER_GUARD_ID, "Cinder Guard", "block_chance", Balance.CINDER_GUARD_BLOCK,
				Balance.CINDER_GUARD_TIME, 1, Abilities.color_of(id))
			guard.description = "+%d%% chance to block. Attacks you block burn the attacker and extend Slag Skin." % int(Balance.CINDER_GUARD_BLOCK)
			status.apply(guard, self)
			_ring_effect(1.3, Abilities.color_of(id))
		"cinderstep":
			_cinder_step(res)
		"heatsink":
			_start_heat_sink()
		"ventflames":
			# One instant hit; "always crits" and its crit-chance bonus are in adjust_crit.
			deal_damage(target, float(res.damage), id)
			_ring_effect(0.9, Abilities.color_of(id), target.global_position)
			_ring_effect(0.5, Color(1.0, 0.9, 0.4), target.global_position)
		"flicker":
			_flicker()
		# --- Lightning melee ---
		"arccleave":
			_arc_cleave(w, res)
		"overdrive":
			_start_overdrive()
		"twincurrent":
			_start_twin_current()
		"staticstep":
			_static_step(w)
		"backcurrent":
			_start_back_current()
		"cadence":
			_cadence(w, res)
		"splitsecond":
			_start_split_second()
		"whiplash":
			_whiplash(w, res)
		"faradayguard":
			_start_faraday_guard()
		"reflexarc":
			_start_reflex_arc()
		"polarstrike":
			_polar_strike(w, res)
		"arcaneexplosion", "arcflash":
			# Every enemy in range is hit. Up to AOE_TARGET_CAP take full damage;
			# with more, what that many would take is split evenly between all.
			var hit := _enemies_within(float(res.radius))
			var share := Balance.aoe_share(hit.size())
			for e in hit:
				deal_damage(e, float(res.damage) * share, id)
			_ring_effect(float(res.radius), Abilities.color_of(id))
		"regrowth":
			heal(float(Abilities.HEALS[id]), id)
			_ring_effect(1.2, Abilities.color_of(id))
		"fanofknives":
			for e in _enemies_within(float(res.radius)):
				deal_damage(e, _weapon_hit(w, res), id)
			_ring_effect(float(res.radius), Abilities.color_of(id))
			for i in 3:
				rotation.y += TAU / 3.0
				_slash_effect(Abilities.color_of(id))
		# --- Lightning tank (a two-handed weapon; see "Lightning tank" below) ---
		"stormshield":
			# Stormbreak. Its arcs come from _on_hit_extra (like Leaping Arc's).
			deal_damage(target, _weapon_hit(w, res), id)
			for i in 2:
				_slash_effect(Abilities.color_of(id))
			_ring_effect(0.7, Color(0.95, 0.95, 1.0), target.global_position)
		"thunderaegis":
			_start_humming_blade()
		"returnstroke":
			# One answer per parry. Without a parry behind it (Rune of Resonance) it
			# cost more (resource_cost) and goes on a short cooldown.
			if status.has(RETURN_STROKE_FX):
				# Second Stroke: a chance the window stays open for one more answer.
				if randf() * 100.0 >= _talent("lightning_second_stroke"):
					status.remove(RETURN_STROKE_FX)
			else:
				cooldowns[id] = Balance.RESONANCE_COOLDOWN
			deal_damage(target, _weapon_hit(w, res), id)   # (Counter-Charge: _on_damage_modify, _on_hit_extra)
			for i in 2:
				_slash_effect(Abilities.color_of(id))
		"reelin":
			_reel_in()
		"recharge":
			_recharge()
		"shockring":
			_shock_ring(res)
		"crossguard":
			_start_crossguard()
		"drawthestorm":
			_draw_the_storm(res)
		# --- Arcane tank (a melee weapon in each hand; see "Arcane tank" below) ---
		"doubleup":
			deal_damage(target, _dual_weapon_hit(w, res), id)   # both weapons
			for i in 2:
				_slash_effect(Abilities.color_of(id))
			_gain_reflections(double_up_reflections(_talent("arcane_second_self"), randf() * 100.0))   # Second Self
		"ripple":
			_ripple(res)
		"fullset":
			_full_set()
		"missedbeat":
			# The answer to a Reflection shattering (the window is checked in _drafted_precheck).
			deal_damage(target, _dual_weapon_hit(w, res), id)   # both weapons
			for i in 2:
				_slash_effect(Abilities.color_of(id))
			_ring_effect(0.6, Color(0.95, 0.9, 1.0), target.global_position)
			# On the Beat's capstone: with none left, it makes one.
			if reflections() <= 0 and _capstone("arcane_on_the_beat"):
				_gain_reflections(1)
		"standin":
			_start_stand_in()
		"tradeplaces":
			_trade_places()
		"crowdofone":
			_start_crowd_of_one()
		# --- Arcane melee (a melee weapon in each hand; see "Arcane melee" below) ---
		"swiftcut", "deepcut":
			deal_damage(target, _dual_weapon_hit(w, res), id)   # both weapons; the Trace: _trace_hit
			for i in (2 if id == DEEP_CUT_ID else 1):
				_slash_effect(Abilities.color_of(id))
		"latecut":
			_late_cut(w, res)
		"widecut":
			_wide_cut(w, res)
		"encore":
			_encore()
		"doubletime":
			_start_double_time()
		# --- Baseline tank tools ---
		"stoneguard":
			var sr := float(res.radius)
			for e in _enemies_within(sr):
				deal_damage(e, float(res.damage), id)   # 5x threat (threat_multiplier in its data)
			status.apply(STONEGUARD_FX, self)
			_ring_effect(sr, Color(0.8, 0.72, 0.55))
			_ring_effect(1.2, Color(0.95, 0.9, 0.8))
		"taunt":
			_net_taunt(target, TAUNT_TIME)
			_ring_effect(1.0, Color(1.0, 0.35, 0.25), target.global_position)
		# --- Interrupts: stop the target's cast, lock it out of casting ---
		"counterspell", "kick", "pummel", "rimelock", "jolt", "hush":
			# (Hush: was there a cast to stop? Asked before anything lands.)
			var hush_foe: Node3D = target
			var hush_stops: bool = id == HUSH_ID and target.has_method("cast_progress") and float(target.cast_progress()) >= 0.0
			if id == "counterspell" or id == "rimelock" or id == JOLT_ID or id == HUSH_ID:
				_ring_effect(0.9, Abilities.color_of(id), target.global_position)
			else:
				deal_damage(target, _weapon_hit(w, res), id)
				_slash_effect(Abilities.color_of(id))
			# Jolt gives Energy when there was a cast to stop (the cast bar is shown
			# on every machine, so this works for party members too).
			if id == JOLT_ID and target.has_method("cast_progress") and float(target.cast_progress()) >= 0.0:
				_gain("energy", Balance.JOLT_ENERGY)
			var lockout := float(INTERRUPT_LOCKOUT[id])
			var net := _net()
			if net:
				net.interrupt(target, self, lockout)   # the host owns enemy casts in a party
			elif target.has_method("interrupt"):
				target.interrupt(self, lockout)
			if id == "rimelock":
				_chill(target, id)   # Rimelock also Chills
				_ring_effect(0.5, Color(0.95, 0.97, 1.0), target.global_position)
			if id == HUSH_ID:
				_hush(hush_foe, float(res.damage), hush_stops)   # its own hit, and what it adds to an open Decay
		# --- Shadow melee (see "Shadow melee: the Hounds" below) ---
		"sic", "openup":
			# (My Hounds go for what I strike: _hounds_on_hit. Open Up's mark is its on-hit effect.)
			deal_damage(target, _weapon_hit(w, res), id)
			for i in (2 if id == OPEN_UP_ID else 1):
				_slash_effect(HOUND_COLOR)
		"bothatonce":
			var both_foe: Node3D = target
			deal_damage(both_foe, _weapon_hit(w, res), id)
			for i in 2:
				_slash_effect(HOUND_COLOR)
			_hounds_lunge(both_foe)
			# Again: a chance that it is ready again at once.
			if again_resets(randf() * 100.0, _talent("shadow_again")):
				cooldowns.erase(BOTH_AT_ONCE_ID)
				_combat().float_text(self, "Again", HOUND_COLOR.lightened(0.3), false)
		"runthemdown":
			_run_them_down(w, res)
		"guarddogs":
			_start_guard_dogs()
		"offthechain":
			_start_off_the_chain()
		"bringitdown":
			_bring_it_down()   # (that there are Hounds with something to drag down: _drafted_precheck)
		# --- Shadow caster (see "Shadow caster: Decay" below) ---
		"calldue":
			_call_due()   # (my Decay on the target is checked in _drafted_precheck)
		"gnaw":
			_gnaw(res)
		"spill":
			_spill()
		"takeitback":
			_take_it_back()
		"bottomless":
			_start_bottomless()
		# --- Frost: Rime Shell kit ---
		"shatteringwave":
			_shattering_wave(float(res.radius))
	_slipstream(id)   # Slipstream: faster after a blink or dash
	# Instant spells / abilities "finish casting" right away (runes, log, audio).
	_bus().cast_finished.emit(id)

## Weapon ability damage coefficient: weapon damage x multiplier + the ability's own.
func _weapon_hit(w: Dictionary, res: Resource) -> float:
	return float(w.get("damage", 0.0)) * float(res.weapon_damage_multiplier) + float(res.damage)

## Size of one flat buff unit at my level (Stats.flat_unit).
func _flat_unit() -> float:
	return Stats.flat_unit(combat_level())

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
	if STRING_INSTANTS.has(id):
		return _string_precheck(id)   # Shadow healer
	if HYMN_INSTANTS.has(id):
		return _hymn_precheck(id)    # Holy healer
	match id:
		"blink", "cinderstep", "flicker", "staticstep", "icyretreat":
			if surge_active():
				return "You can't move during %s" % Abilities.ability_name(SURGE_ID)
		"returnstroke":
			if not return_stroke_usable(status.has(RETURN_STROKE_FX), _has_rune(RESONANCE_RUNE)):
				return "You have not parried an attack"
		"recharge":
			if health >= max_health:
				return "Already at full health"
		"missedbeat":
			if not status.has(MISSED_BEAT_FX):
				return "None of your Reflections has shattered"
		"tradeplaces":
			return trade_places_error(reflections(), damage_taken_recently(Balance.TRADE_PLACES_WINDOW), health >= max_health)
		"encore":
			if traces() <= 0:
				return "You have no Traces"
		"calldue", "takeitback":
			if decay_on(target) <= 0.0:
				return DECAY_ERROR
		"bringitdown":
			return bring_down_error(hounds_out(), _prey_ok(_hound_prey) or (_has_valid_target() and _prey_ok(target)))
		"spill":
			return spill_error(decay_on(target), _spill_targets(target).size() if _has_valid_target() else 0)
		"multishot":
			if _multishot_targets(float(w["attack_range"])).is_empty():
				return "No enemies in range"
		"secondwind", "regrowth":
			if health >= max_health:
				return "Already at full health"
		"iceshards":
			if shards_firing():
				return "Ice Shards are already firing"
		"stoke":
			var burn_st: Node = target.get_node_or_null("Status") if _has_valid_target() else null
			if burn_st == null or not burn_st.has_from("burning", self):
				return "Your Burning isn't on that target"
	return ""

func _flat_forward() -> Vector3:
	var f := -global_basis.z
	f.y = 0.0
	return f.normalized()

# How far Blink can go before hitting a wall (layer 1).
func _blink_distance() -> float:
	return _dash_distance(BLINK_DISTANCE + _talent("arcane_long_step"))   # Long Step

## How far I can move straight ahead (or along `dir`), up to `reach` metres,
## before a wall.
func _dash_distance(reach: float, dir: Vector3 = Vector3.ZERO) -> float:
	var from := global_position + Vector3(0, 0.3, 0)
	var to := from + (dir if dir != Vector3.ZERO else _flat_forward()) * reach
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return reach
	return maxf(from.distance_to(hit.position) - 0.6, 0.0)

## Public versions for the RuneListener (item AoE effects).
func enemies_within(radius: float) -> Array:
	return _enemies_within(radius)

func ring_effect(radius: float, color: Color) -> void:
	_ring_effect(radius, color)

# --- Shields ------------------------------------------------------------------------

func has_shield() -> bool:
	var pd := get_node_or_null("/root/PlayerData")
	return pd != null and Items.item_type(str(pd.equipment.get("Off Hand", ""))) == "shield"

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
	return list.slice(0, Balance.MULTISHOT_TARGETS)

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


# --- In combat ---------------------------------------------------------------------
# You're in combat while any enemy is fighting you or a party member (chasing or
# attacking). It lasts COMBAT_AFTER_KILL after the last such enemy dies and
# COMBAT_AFTER_EVADE after one gives up and runs home (evades).

const COMBAT_AFTER_KILL := 1.0
const COMBAT_AFTER_EVADE := 2.0
const _ENEMY_CHASE := 1    # enemy.gd State.CHASE
const _ENEMY_ATTACK := 2   # enemy.gd State.ATTACK
const _ENEMY_RETURN := 3   # enemy.gd State.RETURN
var in_combat := false
var _combat_hold_until := 0.0
var _engaged := {}   # enemy instance id -> enemy (was fighting us last frame)

func is_in_combat() -> bool:
	return in_combat

func _update_combat_state() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var engaged_now := {}
	for e in get_tree().get_nodes_in_group("enemies"):
		var st = e.get("state")
		if st != null and (int(st) == _ENEMY_CHASE or int(st) == _ENEMY_ATTACK):
			engaged_now[e.get_instance_id()] = e
	for id in _engaged:
		if engaged_now.has(id):
			continue
		var e = _engaged[id]
		if not is_instance_valid(e) or not e.is_alive():
			_combat_hold_until = maxf(_combat_hold_until, now + COMBAT_AFTER_KILL)
		elif int(e.get("state")) == _ENEMY_RETURN:
			_combat_hold_until = maxf(_combat_hold_until, now + COMBAT_AFTER_EVADE)
	_engaged = engaged_now
	var fighting := not engaged_now.is_empty() or now < _combat_hold_until
	if is_dead():
		fighting = false
	if fighting != in_combat:
		in_combat = fighting
		if not in_combat:
			_out_of_combat_since = now   # fast regen kicks in a moment later
		_bus().combat_state_changed.emit(in_combat)

# --- Friendly target (party members) --------------------------------------------------
# Click a party member to target them (it clears your enemy target, and
# targeting an enemy clears it). Heals / Rime Shell go to the friendly target,
# or to you when there is none.

var friendly_target: Node3D = null
var friendly_ring: MeshInstance3D
const ALLY_PICK_PX := 45.0

func _ally_at(screen_pos: Vector2, cam: Camera3D) -> Node3D:
	var best: Node3D = null
	var best_d := ALLY_PICK_PX
	for p in get_tree().get_nodes_in_group("remote_player") + get_tree().get_nodes_in_group("friendly"):
		if not (p is Node3D) or not p.is_alive():
			continue
		for h in [0.3, 0.9, 1.5]:
			var at: Vector3 = p.global_position + Vector3(0, h - 0.9, 0)
			if cam.is_position_behind(at):
				continue
			var d := cam.unproject_position(at).distance_to(screen_pos)
			if d < best_d:
				best_d = d
				best = p
	return best

func has_friendly_target() -> bool:
	return is_instance_valid(friendly_target) and friendly_target.is_alive()

func _build_friendly_ring() -> void:
	friendly_ring = target_ring.duplicate()
	var mat: ShaderMaterial = (target_ring.material_override as ShaderMaterial).duplicate()
	mat.set_shader_parameter("color", Color(0.3, 1.0, 0.45))
	friendly_ring.material_override = mat
	friendly_ring.visible = false
	add_child(friendly_ring)

func _update_friendly_ring() -> void:
	if friendly_ring == null:
		return
	if not has_friendly_target():
		friendly_target = null
		friendly_ring.visible = false
		return
	var p := friendly_target.global_position
	friendly_ring.global_position = Vector3(p.x, Combat.feet_y(friendly_target) + 0.05, p.z)
	friendly_ring.scale = Vector3(1.0, 1.0, 1.0)
	friendly_ring.visible = true

# --- Support casts: Heal, Rime Shell, Flash Freeze ---------------------------------

const STONEGUARD_FX = preload("res://data/effects/stoneguard.tres")
const RIME_SHELL_FX = preload("res://data/effects/rime_shell.tres")
const WEAKENED_SOUL_FX = preload("res://data/effects/weakened_soul.tres")
const TAUNT_TIME := Balance.TAUNT_TIME
## Flash Freeze cone: half of its opening angle.
const FLASH_FREEZE_HALF_ANGLE := 45.0
## "Shatter" marks every shatter hit (Shatterpoint looks for it); the hit's
## NAME is whatever caused it: "rimeshell" (a Rime Shell breaking),
## "frozen_shatter" (a Frozen enemy shattering), "shatteringslam".
const SHATTER_TAGS := ["Frost", "Spell", "AoE", "Shatter"]
const SHATTER_FROZEN := "frozen_shatter"

var _cast_target: Node3D = null
var _cast_kind := ""   # "self" / "ally" / "enemy" / "" (no target)

func _net() -> Node:
	return get_node_or_null("/root/Net")

## Who a support spell goes to right now: [node, kind], or [null, error].
func _pick_support_target(id: String) -> Array:
	var res := Abilities.get_resource(id)
	var lockout: Resource = res.get("ally_lockout_effect") if res else null
	var lock_id := str(lockout.id) if lockout else ""
	if id == "flashfreeze":
		return [null, ""]
	# Everlasting Rime: Rime Shell can't go on enemies (it goes on your friendly target / you).
	if id == "rimeshell" and _has_valid_target() and not _has_rune("everlasting_rime"):
		if global_position.distance_to(target.global_position) > float(res.cast_range):
			return [null, "Target out of range"]
		var err := _target_error(target)
		if err != "":
			return [null, err]
		return [target, "enemy"]
	if has_friendly_target():
		if global_position.distance_to(friendly_target.global_position) > float(res.cast_range):
			return [null, "Target out of range"]
		if not can_see(friendly_target):
			return [null, "Target not in line of sight"]
		if lock_id != "" and friendly_target.has_method("has_lockout") and friendly_target.has_lockout(lock_id):
			return [null, "Target has %s" % str(lockout.display_name)]
		return [friendly_target, "ally"]
	if lock_id != "" and status.has(lock_id):
		return [null, "You have %s" % str(lockout.display_name)]
	return [self, "self"]

func _start_support_cast(id: String) -> void:
	if casting or not is_on_floor():
		return
	if cooldown_left(id) > 0.0 and float(cooldowns.get(id, 0.0)) > 0.0:
		_error("%s is not ready yet" % Abilities.ability_name(id))
		return
	var pick := _pick_support_target(id)
	if pick[0] == null and str(pick[1]) != "":
		_error(str(pick[1]))
		return
	if id == HOIST_ID and not on_my_string(pick[0]):   # Hoist: only someone on one of my Strings
		_error(NOT_ON_STRING)
		return
	if not can_afford(id, true):
		return
	_cast_target = pick[0]
	_cast_kind = str(pick[1])
	_begin_spell(id, Abilities.ability_name(id), 1.0)

func _support_target_ok() -> bool:
	match _cast_kind:
		"self":
			return is_alive()
		"ally", "enemy":
			return is_instance_valid(_cast_target) and _cast_target.is_alive()
	return true

func _support_face_point() -> Vector3:
	if _cast_kind in ["ally", "enemy"] and is_instance_valid(_cast_target):
		return _cast_target.global_position
	return global_position + _flat_forward()

func _release_support(spell: String) -> void:
	var res := Abilities.get_resource(spell)
	var tgt := _cast_target
	var kind := _cast_kind
	_cast_target = null
	_cast_kind = ""
	var everlasting := spell == "rimeshell" and _has_rune("everlasting_rime")
	if res and float(res.cooldown) > 0.0 and not everlasting:   # Everlasting Rime: no cooldown
		cooldowns[spell] = float(res.cooldown)
	match spell:
		"rimeshell":
			var absorb: int = int(round(_combat().heal_amount(self, float(Abilities.HEALS["rimeshell"]), "rimeshell") \
				* absorb_mult() * (Balance.EVERLASTING_RIME_MULT if everlasting else 1.0)))
			var armor := _talent("frost_shield_armor")   # Hardened Frost
			match kind:
				"enemy":
					if is_instance_valid(tgt) and tgt.is_alive():
						if _net():
							_net().shell_enemy(tgt, self, absorb)
						_ring_effect(1.0, Color(0.6, 0.9, 1.0), tgt.global_position)
				"ally":
					if is_instance_valid(tgt) and tgt.is_in_group("friendly") and tgt.has_method("receive_rime_shell"):
						tgt.receive_rime_shell(self, absorb, armor, not everlasting)
						_ring_effect(1.0, Color(0.6, 0.9, 1.0), tgt.global_position)
					elif is_instance_valid(tgt) and tgt.is_alive() and _net():
						_net().shell_ally(tgt, self, absorb, armor, not everlasting)
						tgt.set("has_rime_shell", true)
						tgt.set("rime_shell_by", int(_net().my_id()))   # mine: my Shattering Wave may shatter it
						var locks: Dictionary = tgt.get("lockouts") if tgt.get("lockouts") is Dictionary else {}
						locks["weakened_soul"] = Time.get_ticks_msec() / 1000.0 + float(WEAKENED_SOUL_FX.duration)
						tgt.set("lockouts", locks)
						_ring_effect(1.0, Color(0.6, 0.9, 1.0), tgt.global_position)
				_:
					receive_rime_shell(self, absorb, armor, not everlasting)
		"flashfreeze":
			_flash_freeze(float(res.radius))
		"hoist", "patchup":
			_string_cast_heal(spell, tgt, kind)   # Shadow healer
		"psalm", "outpour", "canticle", "exultation":
			_hymn_cast_heal(spell, tgt, kind)   # Holy healer

## A Rime Shell lands on me (from me or a party member): 20% less damage taken,
## a shield of `amount`, and Weakened Soul. When the shield breaks it shatters
## (the caster deals the damage).
## `armor_pct` = the caster's Hardened Frost; `shatters` = false with the
## caster's Everlasting Rime (the shell breaks without damage).
func receive_rime_shell(caster: Node, amount: int, armor_pct: float = 0.0, shatters: bool = true) -> void:
	if is_dead():
		return
	SHIELDS.put_rime_shell(status, caster, amount, false, armor_pct, func():
		if not shatters:
			return
		if _net():
			_net().request_shatter(caster, global_position)
		elif caster == self:
			shatter_at(global_position))
	status.apply(WEAKENED_SOUL_FX, caster)
	_ring_effect(1.0, Color(0.6, 0.9, 1.0))
	_combat().float_text(self, "Rime Shell (%d)" % amount, Color(0.7, 0.92, 1.0), false)

## Ice shatters at `pos`: my frost damage (a Frost Bolt's worth) to every enemy
## within 5 m. Allies are never hurt. EVERY shatter goes through here, whatever
## the ice was on (an enemy's Rime Shell, an ally's, mine, a Frozen enemy) and
## whatever broke it (damage, Shattering Wave, Shattering Slam).
## `id` names the hit: "rimeshell" for a Rime Shell breaking, SHATTER_FROZEN for
## a Frozen enemy, "shatteringslam" for the slam's.
## `mult` scales the damage (Frozen shatters are weaker and share out, see _shattering_wave).
## `only` = that one enemy alone takes it (Shattering Slam: no splash).
## `threat` = threat multiplier of the hits.
func shatter_at(pos: Vector3, id: String = "rimeshell", mult: float = 1.0, only: Node = null,
		threat: float = 1.0) -> void:
	if is_dead():
		return
	var res := Abilities.get_resource("rimeshell")
	var r := float(res.radius) if res else 5.0
	var hit: Array = [only] if only != null else _enemies_near(pos, r)
	var coef := shatter_coef(id, hit.size(), mult)
	for e in hit:
		_hit_with_threat(e, coef, id, threat, "frost", PackedStringArray(SHATTER_TAGS))
	_ring_effect(1.2 if only != null else r, Color(0.7, 0.95, 1.0), pos)
	_ring_effect(0.6 if only != null else r * 0.5, Color(1, 1, 1), pos)
	_shatterpoint_charge()

## Coefficient each enemy takes from one shatter that damages `targets` enemies.
## Beyond 5 enemies the damage is shared out; a Rime Shell ("rimeshell") that
## damages only one enemy hits it harder (Balance.RIME_SHELL_SOLO_PCT) - a
## Frozen shatter and Shattering Slam's do not.
static func shatter_coef(id: String, targets: int, mult: float = 1.0) -> float:
	var coef := float(Abilities.SHATTER_COEF) * mult * Balance.aoe_share(targets)
	if targets == 1 and id == "rimeshell":
		coef *= 1.0 + Balance.RIME_SHELL_SOLO_PCT / 100.0
	return coef

## Is my Rime Shell on `enemy` still whole (its shield not used up yet)? Only a
## whole shell can shatter; after that it just stays on the enemy.
func _my_shell_whole(enemy: Node) -> bool:
	var st: Node = enemy.get_node_or_null("Status") if enemy and is_instance_valid(enemy) else null
	return st != null and st.shield_from("rime_shell_foe", self) > 0

## Take the ice off `enemy` so I can shatter it myself: a whole Rime Shell of mine
## loses its shield (the shell stays on the enemy), a Freeze of mine thaws.
## Returns what was shattered: any of "rime_shell_foe", "frozen".
func _strip_ice(enemy: Node) -> Array[String]:
	var out: Array[String] = []
	var st: Node = enemy.get_node_or_null("Status")
	if st == null:
		return out
	var net := _net()
	if _my_shell_whole(enemy):
		if net:
			net.drop_enemy_shield(enemy)
		else:
			SHIELDS.drop_rime_shield(st, true)
		out.append("rime_shell_foe")
	if st.has_from("frozen", self):   # own only
		if net:
			net.remove_status(enemy, "frozen")
		else:
			st.remove("frozen")
		out.append("frozen")
	return out

## Shattering Wave: every Rime Shell and Frozen enemy within `radius` shatters.
## Shells lose their remaining shield first (no double shatter); Frozen thaws.
func _shattering_wave(radius: float) -> void:
	var net := _net()
	var shatters: Array[Vector3] = []   # Rime Shells breaking
	var frozen_shatters: Array[Vector3] = []   # Frozen enemies shattering
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D) or not e.is_alive():
			continue
		if _flat_dist_to(e.global_position) > radius:
			continue
		for fx in _strip_ice(e):   # own only: my shells (still whole), my freezes
			if fx == "frozen":
				frozen_shatters.append(e.global_position)
			else:
				shatters.append(e.global_position)
	if status.has_from("rime_shell", self):   # a party member's shell on me is theirs to shatter
		SHIELDS.drop_rime_shield(status, false)
		shatters.append(global_position)
	var my_member: int = int(net.my_id()) if net else 0
	for p in get_tree().get_nodes_in_group("remote_player"):
		if p is Node3D and p.is_alive() and bool(p.get("has_rime_shell")) \
				and my_member != 0 and int(p.get("rime_shell_by")) == my_member \
				and _flat_dist_to(p.global_position) <= radius:
			p.set("has_rime_shell", false)
			p.set("rime_shell_by", 0)
			if net:
				net.remove_status(p, "rime_shell")
			shatters.append(p.global_position)
	for f in get_tree().get_nodes_in_group("friendly"):
		var fst: Node = f.get_node_or_null("Status")
		if fst and fst.has_from("rime_shell", self) and _flat_dist_to(f.global_position) <= radius:
			SHIELDS.drop_rime_shield(fst, false)
			shatters.append(f.global_position)
	for pos in shatters:
		shatter_at(pos, "rimeshell")
	# Frozen shatters: half damage, and beyond 5 Frozen enemies the explosions
	# share the damage out (like a capped AoE) instead of stacking up.
	var frozen_mult := Balance.FROZEN_SHATTER_MULT * Balance.aoe_share(frozen_shatters.size())
	for pos in frozen_shatters:
		shatter_at(pos, SHATTER_FROZEN, frozen_mult)
	_ring_effect(radius, Color(0.6, 0.9, 1.0))

func _flat_dist_to(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()

## Flash Freeze: Frozen on every visible enemy in a cone in front of you.
func _flash_freeze(reach: float) -> void:
	var res := Abilities.get_resource("flashfreeze")
	var fwd := _flat_forward()
	var cos_limit := cos(deg_to_rad(FLASH_FREEZE_HALF_ANGLE))
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D) or not e.is_alive():
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d - Combat.hitbox_radius(e) > reach:
			continue
		if d > 0.5 and fwd.dot(to / d) < cos_limit:
			continue
		if not can_see(e):
			continue
		var info := DamageInfo.make(self, e, 0.0, "flashfreeze")
		info.tags = res.tags
		info.damage_type = "frost"
		info.can_block = false
		info.can_crit = false
		info.effects.append(res.on_hit_effect)
		_combat().deal(info)
	_cone_effect(reach, FLASH_FREEZE_HALF_ANGLE, Color(0.65, 0.92, 1.0))

const DamageInfo = preload("res://scripts/core/damage_info.gd")

## Flat fading fan on the ground in front of you (Flash Freeze).
func _cone_effect(reach: float, half_angle: float, color: Color) -> void:
	_net_fx("ring", global_position + _flat_forward() * reach * 0.5, null, {"r": reach * 0.5, "c": color})
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 12
	for i in steps:
		var a0 := deg_to_rad(-half_angle + 2.0 * half_angle * i / steps)
		var a1 := deg_to_rad(-half_angle + 2.0 * half_angle * (i + 1) / steps)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(sin(a1), 0, -cos(a1)) * reach)
		st.add_vertex(Vector3(sin(a0), 0, -cos(a0)) * reach)
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var fan := MeshInstance3D.new()
	fan.mesh = mesh
	fan.material_override = mat
	fan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fan.top_level = true
	add_child(fan)
	fan.global_position = Vector3(global_position.x, global_position.y - 0.8, global_position.z)
	fan.rotation.y = rotation.y
	var tw := fan.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tw.tween_callback(fan.queue_free)

func _net_taunt(tgt: Node, duration: float) -> void:
	if tgt == null or not is_instance_valid(tgt):
		return
	var net := _net()
	if net:
		net.taunt(tgt, self, duration)
	elif tgt.has_method("taunt"):
		tgt.taunt(self, duration)

# Party members can't see my status effects: tell them when my Rime Shell /
# Weakened Soul changes (their Rime Shell and Shattering Wave need it).
var _sent_support := ""

func _sync_support_state() -> void:
	var net := _net()
	if net == null or not net.with_others():
		return
	var shell: bool = status.has("rime_shell")
	# Who cast it: only that player's Shattering Wave shatters it.
	var shell_by := 0
	if shell:
		var shell_src: Variant = status.effects["rime_shell"].get("source") if status.effects.has("rime_shell") else null
		if shell_src != null and is_instance_valid(shell_src):
			shell_by = int(net.member_of(shell_src))
	var locks := {}
	for fx in status.list():
		if str(fx["id"]) == "weakened_soul":
			locks["weakened_soul"] = float(fx["remaining"])
	var key := "%s|%s|%d" % [shell, locks.has("weakened_soul"), shell_by]
	if key == _sent_support:
		return
	_sent_support = key
	net.send_support_state(shell, locks, shell_by)


# --- Frost weapon abilities ----------------------------------------------------------

## Shattering Slam: weapon hit. On a Rime Shelled or Frozen target the ice
## shatters on it alone (no splash): bonus damage + the shatter's damage, 3x threat.
const SHATTER_SLAM_THREAT := Balance.SHATTER_SLAM_THREAT

func _shattering_slam(tgt: Node3D, w: Dictionary, res: Resource) -> void:
	if tgt == null or not is_instance_valid(tgt) or not tgt.is_alive():
		return
	# Taken off first, so the hits below don't break the shell again.
	var iced := _strip_ice(tgt)   # own only: my whole shell, my freeze
	var at := tgt.global_position
	_hit_with_threat(tgt, _weapon_hit(w, res), "shatteringslam", SHATTER_SLAM_THREAT if not iced.is_empty() else 1.0)
	_slash_effect(Abilities.color_of("shatteringslam"))
	if iced.is_empty():
		return
	_hit_with_threat(tgt, float(Abilities.EXTRA_HITS["shatteringslam"]), "shatteringslam", SHATTER_SLAM_THREAT,
		"frost", PackedStringArray(["Ability", "Frost", "Melee"]))
	# The shatter itself, on the target alone: the same routine as every other
	# shatter (under the slam's name, with the slam's threat).
	for i in iced.size():
		shatter_at(at, "shatteringslam", 1.0, tgt, SHATTER_SLAM_THREAT)

## A hit with its own threat multiplier (for bonus threat on top of the ability's data).
func _hit_with_threat(enemy: Node, coef: float, id: String, threat_mult: float,
		damage_type: String = "", tags: PackedStringArray = PackedStringArray()) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
		return
	var info := DamageInfo.make(self, enemy, coef, id)
	var r := Abilities.get_resource(id)
	info.tags = tags if not tags.is_empty() else (r.tags if r else PackedStringArray())
	info.damage_type = damage_type if damage_type != "" else (str(r.damage_type) if r else "physical")
	info.threat_multiplier = threat_mult
	_combat().deal(info)

## Rime Slash: weapon frost damage in a small cone (3x threat). Rime Shell goes
## on you; if Weakened Soul stops that, on one enemy it hit.
func _rime_slash(w: Dictionary, res: Resource) -> void:
	var reach := float(res.radius) + float(w.get("attack_range", 1.0)) * 0.5
	var fwd := _flat_forward()
	var cos_limit := cos(deg_to_rad(RIME_SLASH_HALF_ANGLE))
	var hit: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D) or not e.is_alive():
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d - Combat.hitbox_radius(e) > reach:
			continue
		if d > 0.6 and fwd.dot(to / d) < cos_limit:
			continue
		if not can_see(e):
			continue
		hit.append(e)
	var coef := _weapon_hit(w, res)
	for e in hit:
		deal_damage(e, coef, "rimeslash")
	for i in 2:
		_slash_effect(Abilities.color_of("rimeslash"))
	_cone_effect(reach, RIME_SLASH_HALF_ANGLE, Color(0.6, 0.9, 1.0))
	var everlasting := _has_rune("everlasting_rime")
	var absorb: int = int(round(_combat().heal_amount(self, float(Abilities.HEALS["rimeslash"]), "rimeslash") \
		* absorb_mult() * (Balance.EVERLASTING_RIME_MULT if everlasting else 1.0)))   # Rime Ward counts here too
	if not status.has("weakened_soul"):
		receive_rime_shell(self, absorb, _talent("frost_shield_armor"), not everlasting)
		return
	if everlasting:
		return   # Everlasting Rime: shells never go on enemies
	# Weakened Soul: the shell goes on an enemy we hit (the target if it was hit).
	var pick: Node = null
	for e in hit:
		if e.is_alive():
			pick = e
			if e == target:
				break
	if pick and _net():
		_net().shell_enemy(pick, self, absorb)
		_ring_effect(1.0, Color(0.6, 0.9, 1.0), pick.global_position)

const RIME_SLASH_HALF_ANGLE := 50.0

# --- Frost talents & runes: slows / freezes I apply ------------------------------------
# Scanned once per frame from the enemies' status effects whose source is me.
# Works the same solo, as the host and as a party member (whose enemies mirror
# the host's effects with me as the source). A slow counts as (re)applied when
# it's new or its time left jumped up (a refresh).

const SHIELDS = preload("res://scripts/core/shields.gd")
const FROZEN_FX = preload("res://data/effects/frozen.tres")

var _my_slows := {}         # "enemy id|effect key" -> expires
var _slowed_at := {}        # enemy instance id -> when I last slowed it
var _glacial_haste := 0.0   # Glacial Heart capstone: Haste from my slows on enemies
var _cold_snap := 0.0       # Cold Snap: seconds off the next GCD

func _scan_my_slows() -> void:
	# Nothing reacts to my slows: skip the scan.
	if _talent("frost_cold_snap") <= 0.0 and _talent("frost_slow_threat") <= 0.0 \
			and _talent("frost_slow_dr") <= 0.0 and not _capstone("frost_glacial_heart") \
			and _talent("frost_instinct") <= 0.0 and not _has_rune("frozen_aegis"):
		_my_slows.clear()
		_slowed_at.clear()
		_glacial_haste = 0.0
		return
	var now := Time.get_ticks_msec() / 1000.0
	var seen := {}
	var count := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var st: Node = e.get_node_or_null("Status")
		if st == null or st.effects.is_empty():
			continue
		var eid: int = e.get_instance_id()
		for k in st.effects:
			var fx: Dictionary = st.effects[k]
			# My own application's clock: an ally refreshing the same slow neither
			# takes it from me nor counts as me slowing the enemy again.
			var expires: float = st.own_expires(fx, self)
			if expires <= 0.0:
				continue
			var res: Resource = fx["res"]
			if float(res.stat_modifiers.get("move_speed", 0.0)) >= 0.0:
				continue
			count += 1
			var key := "%d|%s" % [eid, str(k)]
			seen[key] = expires
			var before: Variant = _my_slows.get(key)
			if before == null or expires > float(before) + 0.25:
				_on_slow_applied(e, str(res.id))
	_my_slows = seen
	_glacial_haste = count * Balance.GLACIAL_HEART_HASTE if _capstone("frost_glacial_heart") else 0.0
	for id in _slowed_at.keys():
		if now - float(_slowed_at[id]) > Balance.SLOW_MEMORY:
			_slowed_at.erase(id)

func _on_slow_applied(enemy: Node, effect_id: String) -> void:
	_slowed_at[enemy.get_instance_id()] = Time.get_ticks_msec() / 1000.0
	if effect_id != "frozen":
		return
	var cs := _talent("frost_cold_snap")
	if cs > 0.0:
		_cold_snap = maxf(_cold_snap, cs)
	var fi := _talent("frost_instinct")
	if fi > 0.0 and randf() * 100.0 < fi:
		_grant_frozen_instinct()
	if _has_rune("frozen_aegis"):
		var amount := _aegis_amount(Balance.FROZEN_AEGIS_ON_FREEZE)
		for a in _aegis_allies():
			_give_aegis(a, amount)

## Did I slow `enemy` in the last SLOW_MEMORY seconds? (Chilling Presence, Numbing Cold)
func _slowed_recently(enemy: Variant) -> bool:   # untyped: may be a freed enemy
	if enemy == null or not is_instance_valid(enemy):
		return false
	var at: Variant = _slowed_at.get(enemy.get_instance_id())
	return at != null and Time.get_ticks_msec() / 1000.0 - float(at) <= Balance.SLOW_MEMORY

## Glacial Heart: slows on me are this much as strong (StatusContainer asks).
func slow_taken_mult() -> float:
	return maxf(1.0 - _talent("frost_glacial_heart") / 100.0, 0.0)

func _capstone(key: String) -> bool:
	var pd := get_node_or_null("/root/PlayerData")
	return pd != null and pd.talent_capstone(key)

func _has_rune(id: String) -> bool:
	var rl := get_node_or_null("RuneListener")
	return rl != null and rl.has_rune(id)

# --- Lightning caster: the Energy kit ------------------------------------------------------
# Leaping Arc gives Energy and Ball Lightning's zaps give some back; Lightning
# Bolt spends a little; Discharge and Ground Out spend ALL of it and are worth
# more the more they spend. Grounding Surge roots me and makes Energy go twice
# as far. The numbers are in balance.gd.

const DISCHARGE_ID := "discharge"
const BALL_LIGHTNING_ID := "balllightning"
const GROUND_OUT_ID := "groundout"
const GROUND_OUT_FX := "ground_out"
const SURGE_ID := "groundingsurge"
const SURGE_FX := "grounding_surge"
const BALL_LIGHTNING = preload("res://scripts/ball_lightning.gd")
var _ball_dir := Vector3.FORWARD   # where the Ball Lightning being cast will drift

## Leaps of a Leaping Arc that find no new enemy (they return to its target),
## with `others` other enemies in reach.
static func arc_returns(others: int) -> int:
	return maxi(Balance.LEAPING_ARC_JUMPS - maxi(others, 0), 0)

## Damage coefficient of a returning leap: a share of a normal leap's (`jump`).
static func arc_return_coef(jump: float) -> float:
	return jump * Balance.LEAPING_ARC_RETURN_PCT / 100.0

func surge_active() -> bool:
	return status != null and status.has(SURGE_FX)

## An Energy cost with Grounding Surge up (`surging`) or not.
static func surge_energy_cost(cost: float, surging: bool) -> float:
	return cost * (1.0 - Balance.GROUNDING_SURGE_COST_PCT / 100.0) if surging else cost

## Energy left in the bar after an ability spent "all" of `energy`.
static func energy_left_after_all(energy: float, surging: bool) -> float:
	return energy * Balance.GROUNDING_SURGE_KEEP_PCT / 100.0 if surging else 0.0

## Spend all my Energy. Returns what the ability counts as spent: all of it,
## even when Grounding Surge leaves part of it in the bar.
func _spend_all_energy() -> float:
	var have := float(resources["energy"])
	resources["energy"] = energy_left_after_all(have, surge_active())
	_redline()   # (spending all of it is spending Energy too)
	_storm_cycle_spent(have - float(resources["energy"]))   # Storm Cycle counts what really left the bar
	return have

## Damage coefficient of a Discharge that spent `energy`.
static func discharge_coef(energy: float) -> float:
	return Balance.DISCHARGE_PER_STEP * maxf(energy, 0.0) / Balance.ENERGY_STEP

## Shield coefficient of a Ground Out that spent `energy` (1.0 = a standard hit's worth of health).
static func ground_out_coef(energy: float) -> float:
	return Balance.GROUND_OUT_PER_STEP * maxf(energy, 0.0) / Balance.ENERGY_STEP

## Discharge's cast finished: all my Energy goes into one bolt.
func _discharge(tgt: Node3D) -> void:
	var spent := _spend_all_energy()
	FROST_BOLT.spawn(get_tree().current_scene, _muzzle(), tgt, self, false, DISCHARGE_ID, discharge_coef(spent))

## Ground Out: all my Energy becomes a shield on me. It never stacks, and never
## shrinks a bigger one that is still up.
func _ground_out() -> void:
	var spent := _spend_all_energy()
	var amount := int(round(_combat().heal_amount(self, ground_out_coef(spent), GROUND_OUT_ID) * absorb_mult()))
	if amount <= 0:
		return
	var col := Abilities.color_of(GROUND_OUT_ID)
	var fx := StatusContainer.make_buff(GROUND_OUT_FX, Abilities.ability_name(GROUND_OUT_ID), GROUND_OUT_FX, 0.0,
		Balance.GROUND_OUT_TIME, 1, col)
	var armor := _talent("frost_shield_armor")   # Hardened Frost: my shields add armor
	fx.stat_modifiers = {"armor%": armor} if armor > 0.0 else {}
	fx.tags = PackedStringArray(["Lightning"])
	fx.description = "A shield of grounded current absorbs damage."
	var total := maxi(int(status.absorb_left(GROUND_OUT_FX)), amount)
	if status.apply(fx, self):
		status.set_absorb(GROUND_OUT_FX, total)
	_ring_effect(1.3, col)

## Ball Lightning: a cast, then the orb sets off toward my target (if I can see
## it and it is in range) or straight ahead.
func _start_ball_lightning() -> void:
	var id := BALL_LIGHTNING_ID
	if casting or not is_on_floor():
		return
	if cooldown_left(id) > 0.0:
		_error("%s is not ready yet" % Abilities.ability_name(id))
		return
	if not can_afford(id, true):
		return
	var res := Abilities.get_resource(id)
	var dir := _flat_forward()
	if _has_valid_target() and can_see(target) \
			and global_position.distance_to(target.global_position) <= float(res.cast_range):
		var to := target.global_position - global_position
		to.y = 0.0
		if to.length() > 0.5:
			dir = to.normalized()
	_ball_dir = dir
	cast_point = global_position + dir * 5.0   # (what I face while casting)
	_begin_spell(id, str(res.display_name), float(res.cast_time))

func _launch_ball_lightning() -> void:
	var res := Abilities.get_resource(BALL_LIGHTNING_ID)
	cooldowns[BALL_LIGHTNING_ID] = Abilities.cooldown_of(res)
	var at := Vector3(global_position.x, Combat.feet_y(self) + BALL_LIGHTNING.FLOAT_HEIGHT, global_position.z) + _ball_dir
	var tick := maxf(Balance.BALL_LIGHTNING_TICK / haste_mult(), 0.1)   # zaps come faster with Haste
	BALL_LIGHTNING.spawn(get_tree().current_scene, at, _ball_dir, self, float(res.damage), float(res.radius),
		Balance.BALL_LIGHTNING_TIME, tick, Balance.BALL_LIGHTNING_SPEED)
	# The party sees the orb; its damage and my Energy come from here.
	_net_fx(BALL_LIGHTNING_ID, at, null, {"dir": _ball_dir, "r": float(res.radius),
		"time": Balance.BALL_LIGHTNING_TIME, "tick": tick, "speed": Balance.BALL_LIGHTNING_SPEED})

## My Ball Lightning zapped `zaps` enemies: each zap gives Energy back.
func ball_lightning_zapped(zaps: int) -> void:
	if not is_dead():
		_gain("energy", ball_zap_energy(_talent("lightning_tight_coil")) * maxi(zaps, 0))   # + Tight Coil

## Energy one zap of Ball Lightning gives, with Tight Coil adding `more`.
static func ball_zap_energy(more: float) -> float:
	return Balance.BALL_LIGHTNING_ENERGY + maxf(more, 0.0)

## Conductor: does this hit of mine give Energy back? A critical strike of
## Lightning damage by a spell or ability itself: not its arcs, zaps or other
## procs, and not periodic damage.
static func conductor_applies(damage_type: String, crit: bool, is_proc: bool, is_dot: bool, amount: int) -> bool:
	return crit and amount > 0 and damage_type == "lightning" and not is_proc and not is_dot

var _conductor_last := ""   # "<ability>@<frame>" of the last use Conductor paid for

## Conductor: a Lightning critical strike of mine gives Energy back. An ability
## that hits several enemies at once counts once.
func _conductor(info: RefCounted, id: String) -> void:
	var back := _talent("lightning_conductor")
	if back <= 0.0 or not conductor_applies(str(info.damage_type), bool(info.crit), bool(info.is_proc), bool(info.is_dot), int(info.amount)):
		return
	var key := "%s@%d" % [id, Engine.get_process_frames()]
	if key == _conductor_last:
		return
	_conductor_last = key
	_gain("energy", back)

## High Voltage: does this hit of mine get it? Lightning damage while I hold
## more than HIGH_VOLTAGE_ENERGY Energy.
static func high_voltage(damage_type: String, energy: float) -> bool:
	return damage_type == "lightning" and energy > Balance.HIGH_VOLTAGE_ENERGY

## Health Earth Return restores for one parry: `pct` % of `max_hp`.
static func earth_return_heal(max_hp: int, pct: float) -> int:
	return int(round(float(max_hp) * maxf(pct, 0.0) / 100.0))

## Grounding Surge: instant and off the global cooldown. I can't move while it
## lasts; using it again ends it early (its cooldown keeps running).
func _grounding_surge() -> void:
	var col := Abilities.color_of(SURGE_ID)
	if surge_active():
		status.remove(SURGE_FX)
		_ring_effect(0.8, col)
		return
	if float(cooldowns.get(SURGE_ID, 0.0)) > 0.0:
		_error("%s is not ready yet" % Abilities.ability_name(SURGE_ID))
		return
	var res := Abilities.get_resource(SURGE_ID)
	cooldowns[SURGE_ID] = Abilities.cooldown_of(res)
	var fx := StatusContainer.make_buff(SURGE_FX, str(res.display_name), SURGE_FX, 0.0,
		Balance.GROUNDING_SURGE_TIME, 1, col)
	fx.stat_modifiers = {}
	fx.root = true
	fx.tags = PackedStringArray(["Lightning"])
	fx.description = "You cannot move. Your abilities cost %s%% less Energy, and an ability that spends all your Energy leaves you %s%% of it. Use %s again to end it." % [
		Stats.num(Balance.GROUNDING_SURGE_COST_PCT), Stats.num(Balance.GROUNDING_SURGE_KEEP_PCT), str(res.display_name)]
	status.apply(fx, self)
	_ring_effect(1.4, col)
	_bus().cast_finished.emit(SURGE_ID)

# --- Lightning caster, second batch -------------------------------------------------------
# Arc Flash (AoE spender), Live Wire (a tether that feeds Energy), Thunderhead (a
# storm cloud), Forked Bolt, Jolt (the interrupt), Flicker (a blink with an
# instant Lightning Bolt) and Capacitor (Energy put aside). Numbers are in balance.gd.

const LIVE_WIRE_ID := "livewire"
const LIVE_WIRE_FX := "live_wire"
const THUNDERHEAD_ID := "thunderhead"
const FORKED_BOLT_ID := "forkedbolt"
const JOLT_ID := "jolt"
const FLICKER_ID := "flicker"
const FLICKER_FX := "flicker"
const CAPACITOR_ID := "capacitor"
const CAPACITOR_FX := "capacitor"
const OVERFLOW_FX := "overflow"
const PARTING_SPARK_ID := "parting_spark"
const STORM_ARROW_ID := "stormarrow"
const LOADED_QUIVER_FX := "loaded_quiver"
const SNAP_SHOT_FX := "snap_shot"
## Lightning Rod: the effect a Storm Arrow leaves on its target (data/effects),
## and the name its arcs carry on the damage meter.
const ROD_FX := "lightning_rod"

# --- Storm Arrow talents (the Lightning bow) -----------------------------------------------

## Energy a Storm Arrow costs: nothing out of a Loaded Quiver, `less` off after Snap Shot.
static func storm_arrow_cost(cost: float, loaded: bool, less: float) -> float:
	if loaded:
		return 0.0
	return maxf(cost - maxf(less, 0.0), 0.0)

## Is my next Storm Arrow one of Loaded Quiver's (free, and it ignores the cooldown)?
func quiver_loaded() -> bool:
	return status != null and status.has(LOADED_QUIVER_FX)

## Loaded Quiver: I took my Energy back out of the Capacitor. My next Storm
## Arrows cost nothing and ignore the cooldown, one stack each.
func _load_quiver() -> void:
	var arrows := int(round(_talent("lightning_loaded_quiver")))
	if arrows <= 0:
		return
	var arrow_name := Abilities.ability_name(STORM_ARROW_ID)
	var fx := StatusContainer.make_buff(LOADED_QUIVER_FX, "Loaded Quiver", LOADED_QUIVER_FX, 0.0,
		Balance.LOADED_QUIVER_TIME, arrows, Abilities.color_of(STORM_ARROW_ID))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Lightning"])
	fx.description = "Your next %s costs no Energy and ignores its cooldown, one stack each." % arrow_name
	status.remove(LOADED_QUIVER_FX)
	if status.apply(fx, self):
		status.set_stacks(LOADED_QUIVER_FX, arrows)

## Snap Shot: I Flickered. Storm Arrow is ready again, and the next one costs less.
func _snap_shot() -> void:
	var less := _talent("lightning_snap_shot")
	if less <= 0.0:
		return
	cooldowns.erase(STORM_ARROW_ID)
	var fx := StatusContainer.make_buff(SNAP_SHOT_FX, "Snap Shot", SNAP_SHOT_FX, 0.0,
		Balance.SNAP_SHOT_TIME, 1, Abilities.color_of(STORM_ARROW_ID))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Lightning"])
	fx.description = "Your next %s costs %s less Energy." % [Abilities.ability_name(STORM_ARROW_ID), Stats.num(less)]
	status.apply(fx, self)

## A Storm Arrow left the bow; it had `cd_before` seconds of cooldown left when
## I let go (only a Loaded Quiver arrow can have any). A Loaded Quiver arrow
## uses a stack and leaves the cooldown as it was; otherwise Snap Shot's
## cheaper arrow is used up.
func _storm_arrow_fired(cd_before: float) -> void:
	if status.has(LOADED_QUIVER_FX):
		status.spend_stacks(LOADED_QUIVER_FX, 1)
		if cd_before > 0.0:
			cooldowns[STORM_ARROW_ID] = cd_before
		else:
			cooldowns.erase(STORM_ARROW_ID)
	elif status.has(SNAP_SHOT_FX):
		status.remove(SNAP_SHOT_FX)

## Lightning Rod: damage each arc deals when a Lightning Bolt hit for `amount`,
## at `pct` % of it, with `count` enemies around (more than AOE_TARGET_CAP share
## that many arcs).
static func lightning_rod_damage(amount: int, pct: float, count: int = 1) -> float:
	return maxf(float(amount) * maxf(pct, 0.0) / 100.0, 0.0) * Balance.aoe_share(count)

## Lightning Rod: my Lightning Bolt hit a target with MY Storm Arrow stuck in it
## (own only). An exact share of the hit arcs to the enemies around it: dealt as
## procs, so the arcs feed nothing else and their crit is already in the hit.
func _lightning_rod_arc(info: RefCounted) -> void:
	var pct := _talent("lightning_rod")
	if pct <= 0.0 or bool(info.is_proc) or bool(info.is_dot) or int(info.amount) <= 0:
		return
	var foe: Node = info.target
	var st: Node = foe.get_node_or_null("Status")
	if st == null or not st.has_from(ROD_FX, self):
		return
	var near := _enemies_near(foe.global_position, Balance.LIGHTNING_ROD_RADIUS, foe)
	var each := lightning_rod_damage(int(info.amount), pct, near.size())
	for e in near:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var arc := DamageInfo.make(self, e, 1.0, ROD_FX)
		arc.unit = each
		arc.exact = true
		arc.add_power = false
		arc.can_crit = false
		arc.can_block = false
		arc.is_proc = true
		arc.damage_type = "lightning"
		arc.tags = PackedStringArray(["Lightning", "Spell"])
		_combat().deal(arc)
		_ring_effect(0.6, Abilities.color_of(STORM_ARROW_ID), e.global_position)
const LIVE_WIRE = preload("res://scripts/live_wire.gd")
const THUNDERHEAD = preload("res://scripts/thunderhead.gd")
## Seconds after Live Wire lands before a missing effect counts as "it ran out"
## (in a party the effect comes back from the host a moment later).
const WIRE_GRACE := 1.0
var _wire_target: Node3D        # the enemy my Live Wire is on
var _wire_line: Node3D          # its picture
var _wire_since := 0.0          # when it landed (seconds)
var _flicker_cast := false      # the current Lightning Bolt cast is Flicker's instant one
var _capacitor_stored := 0.0    # Energy put aside in the Capacitor

# --- Rune of Bottled Lightning, and the talents Standing Charge, Whip Crack and Storm Cycle ---
const BOTTLED_RUNE := "bottled_lightning"
const BOTTLED_FX := "bottled_lightning"
const STANDING_FX := "standing_charge"
const WHIP_CRACK_FX := "whip_crack"
const STORM_CYCLE_FX := "storm_cycle"
var _bottled_cast := false      # the current Discharge cast is the instant one (Rune of Bottled Lightning)
var _standing_fx: Resource
var _standing_t := 0.0          # seconds planted since the last Standing Charge stack
var _cycle_spent := 0.0         # Energy spent toward the next Storm Cycle

## Is `spell` the Discharge that the Rune of Bottled Lightning makes instant?
func bottled_ready(spell: String) -> bool:
	return spell == DISCHARGE_ID and status != null and status.has(BOTTLED_FX)

## I took my Energy back out of the Capacitor: with the rune, my next Discharge is instant.
func _bottle_lightning() -> void:
	if not _has_rune(BOTTLED_RUNE):
		return
	var fx := StatusContainer.make_buff(BOTTLED_FX, "Bottled Lightning", BOTTLED_FX, 0.0,
		Balance.BOTTLED_LIGHTNING_TIME, 1, Abilities.color_of(DISCHARGE_ID))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Lightning"])
	fx.description = "Your next %s is instant." % Abilities.ability_name(DISCHARGE_ID)
	status.apply(fx, self)

## Standing Charge's buff at `pct` % Lightning damage per stack (rebuilt when the rank changes).
func _standing_buff(pct: float) -> Resource:
	if _standing_fx == null or not is_equal_approx(float(_standing_fx.stat_modifiers.get(STANDING_FX, 0.0)), pct):
		_standing_fx = StatusContainer.make_buff(STANDING_FX, "Standing Charge", STANDING_FX, pct,
			Balance.GROUNDING_SURGE_TIME + 1.0, Balance.STANDING_CHARGE_MAX_STACKS, Abilities.color_of(SURGE_ID))
		_standing_fx.tags = PackedStringArray(["Lightning"])
		_standing_fx.description = "Your Lightning damage is increased by %s%% per stack. Lost when %s ends." % [
			Stats.num(pct), Abilities.ability_name(SURGE_ID)]
	return _standing_fx

## Every frame: planted in Grounding Surge, Standing Charge adds a stack each
## STANDING_CHARGE_EVERY seconds; the moment the Surge ends they are all gone.
func _tick_standing_charge(delta: float) -> void:
	if status == null:
		return
	if not surge_active():
		_standing_t = 0.0
		if status.has(STANDING_FX):
			status.remove(STANDING_FX)
		return
	var pct := _talent("lightning_standing_charge")
	if pct <= 0.0:
		return
	_standing_t += delta
	if _standing_t >= Balance.STANDING_CHARGE_EVERY:
		_standing_t -= Balance.STANDING_CHARGE_EVERY
		status.apply(_standing_buff(pct), self)

## % more Lightning damage Standing Charge gives me right now.
func standing_charge_bonus() -> float:
	return status.stat_mod(STANDING_FX) if status != null else 0.0

## Whip Crack: did a Whiplash from `distance` metres away earn it?
static func whip_crack_applies(distance: float) -> bool:
	return distance > Balance.WHIP_CRACK_DISTANCE

## Energy Static Step costs with Whip Crack taking `less` off it (never below 0).
static func whip_crack_cost(cost: float, less: float) -> float:
	return maxf(cost - maxf(less, 0.0), 0.0)

## Whip Crack: my Whiplash landed from far away. Static Step is ready again,
## and the next one costs less.
func _whip_crack() -> void:
	var less := _talent("lightning_whip_crack")
	if less <= 0.0:
		return
	cooldowns.erase(STATIC_STEP_ID)
	var fx := _melee_buff(WHIP_CRACK_FX, WHIPLASH_ID, Balance.WHIP_CRACK_TIME,
		"Your next %s costs %s less Energy." % [Abilities.ability_name(STATIC_STEP_ID), Stats.num(less)])
	fx.display_name = "Whip Crack"
	status.apply(fx, self)

## Storm Cycle: `spent` Energy counted so far plus `amount` more, against a cycle
## of `need`: [Energy carried into the next cycle, did a cycle complete].
static func storm_cycle_step(spent: float, amount: float, need: float) -> Array:
	if need <= 0.0:
		return [0.0, false]
	var total := spent + maxf(amount, 0.0)
	if total + 0.0001 >= need:
		return [minf(total - need, need), true]
	return [total, false]

## Is my next Energy cost free (Storm Cycle)?
func storm_cycle_ready() -> bool:
	return status != null and status.has(STORM_CYCLE_FX)

## I spent `amount` Energy: Storm Cycle counts it, and a full cycle makes my next Energy cost free.
func _storm_cycle_spent(amount: float) -> void:
	var need := _talent("lightning_storm_cycle")
	if need <= 0.0 or amount <= 0.0 or status == null:
		return
	var step := storm_cycle_step(_cycle_spent, amount, need)
	_cycle_spent = float(step[0])
	if bool(step[1]):
		var fx := StatusContainer.make_buff(STORM_CYCLE_FX, "Storm Cycle", STORM_CYCLE_FX, 0.0,
			Balance.STORM_CYCLE_TIME, 1, Abilities.color_of(DISCHARGE_ID))
		fx.stat_modifiers = {}
		fx.tags = PackedStringArray(["Lightning"])
		fx.description = "Your next Energy cost is free."
		status.apply(fx, self)

## My hits and ticks, for the Lightning kit (SignalBus.damage_dealt).
func _on_damage_dealt_lightning(info: RefCounted) -> void:
	if not is_same(info.source, self) or info.avoided() or not is_instance_valid(info.target):
		return
	var id := str(info.ability_id)
	_conductor(info, id)   # Conductor: Lightning crits give Energy back
	if id == "auto_melee" or id == "auto_ranged":
		_on_auto_landed(info)   # Twin Current, Overdrive
	elif id == "lightningbolt":
		_lightning_rod_arc(info)   # Lightning Rod: it arcs off a target with my Storm Arrow in it
	elif id == LIVE_WIRE_ID:
		_wire_landed(info.target)
	elif id == "dot_" + LIVE_WIRE_FX:
		_gain("energy", Balance.LIVE_WIRE_ENERGY)   # every tick of the tether gives Energy back

## My Live Wire landed on `foe`: the tether is on it now, and off anyone else.
func _wire_landed(foe: Node) -> void:
	if not (foe is Node3D):
		return
	if is_instance_valid(_wire_target) and _wire_target != foe:
		_drop_wire_effect(_wire_target)   # only one tether at a time
	_wire_target = foe
	_wire_since = Time.get_ticks_msec() / 1000.0
	var fx: Resource = Abilities.get_resource(LIVE_WIRE_ID).on_hit_effect
	var time := float(fx.duration) if fx else 10.0
	_wire_line = LIVE_WIRE.spawn(get_tree().current_scene, self, foe, time + WIRE_GRACE, "me")
	_net_fx(LIVE_WIRE_ID, global_position, foe, {"time": time})   # the party sees the line

## Take my Live Wire off `foe` (in a party the host owns enemy effects).
func _drop_wire_effect(foe: Node) -> void:
	var net := _net()
	if net:
		net.remove_effect(foe, self, LIVE_WIRE_FX)
	else:
		var st: Node = foe.get_node_or_null("Status")
		if st:
			st.remove_from(LIVE_WIRE_FX, self)

## Is a tether to an enemy `distance` metres away broken?
static func wire_breaks(distance: float) -> bool:
	return distance > Balance.LIVE_WIRE_RANGE

## Every frame: the tether ends when its target dies, when the effect has run its
## time, or when I move too far away (that takes the effect off too).
func _tick_live_wire() -> void:
	if _wire_target == null:
		return
	var gone: bool = not is_instance_valid(_wire_target) or not _wire_target.is_alive() or is_dead()
	if not gone:
		var st: Node = _wire_target.get_node_or_null("Status")
		var since := Time.get_ticks_msec() / 1000.0 - _wire_since
		if since > WIRE_GRACE and (st == null or not st.has_from(LIVE_WIRE_FX, self)):
			gone = true
		elif wire_breaks(global_position.distance_to(_wire_target.global_position)):
			_drop_wire_effect(_wire_target)
			gone = true
	if gone:
		_wire_target = null
		if is_instance_valid(_wire_line):
			_wire_line.vanish()
		_wire_line = null

## Thunderhead: the circle was clicked, the cast starts.
func _start_thunderhead(point: Vector3) -> void:
	if casting or not is_on_floor():
		return
	if not can_afford(THUNDERHEAD_ID, true):
		return
	cast_point = point
	var res := Abilities.get_resource(THUNDERHEAD_ID)
	_begin_spell(THUNDERHEAD_ID, str(res.display_name), float(res.cast_time))

func _raise_thunderhead() -> void:
	var res := Abilities.get_resource(THUNDERHEAD_ID)
	cooldowns[THUNDERHEAD_ID] = Abilities.cooldown_of(res)
	var tick := maxf(Balance.THUNDERHEAD_TICK / haste_mult(), 0.1)   # strikes come faster with Haste
	THUNDERHEAD.spawn(get_tree().current_scene, cast_point, float(res.radius), Balance.THUNDERHEAD_TIME, tick,
		self, float(res.damage))
	# The party sees the cloud; its damage comes from here.
	_net_fx(THUNDERHEAD_ID, cast_point, null, {"r": float(res.radius), "time": Balance.THUNDERHEAD_TIME, "tick": tick})

## Damage coefficients of a Forked Bolt's hits: two prongs of `damage` when there
## is a second enemy to fork to, one bigger hit when there isn't.
static func forked_bolt_hits(damage: float, has_other: bool) -> Array[float]:
	var out: Array[float] = []
	if has_other:
		out.append(damage)
		out.append(damage)
	else:
		out.append(Balance.FORKED_BOLT_SOLO)
	return out

## Forked Bolt's cast finished: the target, and the nearest other enemy in reach of it.
func _forked_bolt(tgt: Node3D) -> void:
	var res := Abilities.get_resource(FORKED_BOLT_ID)
	var near := _enemies_near(tgt.global_position, float(res.radius), tgt)
	var hits := forked_bolt_hits(float(res.damage), not near.is_empty())
	var scene := get_tree().current_scene
	FROST_BOLT.spawn(scene, _muzzle(), tgt, self, false, FORKED_BOLT_ID, hits[0])
	if hits.size() > 1:
		# (The second prong is dealt as a proc, so one cast counts once for
		# anything that counts casts: Static, runes that count hits.)
		FROST_BOLT.spawn(scene, _muzzle(), near[0], self, true, FORKED_BOLT_ID, hits[1])

## Flicker: a blink (it stops short of walls) that makes my next Lightning Bolt instant.
func _flicker() -> void:
	var col := Abilities.color_of(FLICKER_ID)
	var from := global_position
	global_position += _flat_forward() * _dash_distance(Balance.FLICKER_DISTANCE + _talent("arcane_long_step"))   # Long Step
	_ring_effect(0.8, col, from)
	_ring_effect(0.8, col)
	_parting_spark(from)   # Parting Spark: a zap around the spot I left
	_snap_shot()           # Snap Shot: Storm Arrow is ready again, and cheaper
	_leave_afterimage(from)   # Rune of the Afterimage
	var fx := StatusContainer.make_buff(FLICKER_FX, Abilities.ability_name(FLICKER_ID), FLICKER_FX, 0.0,
		Balance.FLICKER_TIME, 1, col)
	fx.stat_modifiers = {}
	fx.description = "Your next %s is instant." % Abilities.ability_name("lightningbolt")
	status.apply(fx, self)

## Parting Spark: Flicker zaps the enemies around the spot it left (a proc: it
## feeds nothing else). More than AOE_TARGET_CAP enemies share that many hits.
func _parting_spark(from: Vector3) -> void:
	var coef := _talent("lightning_parting_spark")
	if coef <= 0.0:
		return
	var hit := _enemies_near(from, Balance.PARTING_SPARK_RADIUS)
	if hit.is_empty():
		return
	coef *= Balance.aoe_share(hit.size())
	for e in hit:
		if is_instance_valid(e) and e.is_alive():
			deal_damage(e, coef, PARTING_SPARK_ID, true, "lightning", PackedStringArray(["Lightning", "Spell"]))
	_ring_effect(Balance.PARTING_SPARK_RADIUS, Abilities.color_of(FLICKER_ID), from)

## Energy that doesn't fit when the Capacitor gives `stored` back to a bar with
## `room` left in it.
static func capacitor_overflow(stored: float, room: float) -> float:
	return maxf(stored - maxf(room, 0.0), 0.0)

## Overflow: the shield (as a coefficient: 1.0 = a standard hit's worth of
## health) that `energy` turns into at `per` per ENERGY_STEP Energy.
static func overflow_coef(energy: float, per: float) -> float:
	return maxf(per, 0.0) * maxf(energy, 0.0) / Balance.ENERGY_STEP

## Overflow: Energy the Capacitor couldn't give back becomes a shield on me. It
## never stacks, and never shrinks a bigger one that is still up.
func _overflow(energy: float) -> void:
	var coef := overflow_coef(energy, _talent("lightning_overflow"))
	if coef <= 0.0:
		return
	var amount := int(round(_combat().heal_amount(self, coef, CAPACITOR_ID) * absorb_mult()))
	if amount <= 0:
		return
	var fx := StatusContainer.make_buff(OVERFLOW_FX, "Overflow", CAPACITOR_FX, 0.0,
		Balance.OVERFLOW_TIME, 1, Abilities.color_of(CAPACITOR_ID))
	var armor := _talent("frost_shield_armor")   # Hardened Frost: my shields add armor
	fx.stat_modifiers = {"armor%": armor} if armor > 0.0 else {}
	fx.tags = PackedStringArray(["Lightning"])
	fx.description = "A shield of Energy that didn't fit absorbs damage."
	var total := maxi(int(status.absorb_left(OVERFLOW_FX)), amount)
	if status.apply(fx, self):
		status.set_absorb(OVERFLOW_FX, total)

## Is `spell` the Lightning Bolt that Flicker makes instant?
func flicker_ready(spell: String) -> bool:
	return spell == "lightningbolt" and status != null and status.has(FLICKER_FX)

## Energy the Capacitor takes out of a bar holding `energy`.
static func capacitor_takes(energy: float) -> float:
	return clampf(energy, 0.0, Balance.CAPACITOR_MAX)

## Capacitor: instant and off the global cooldown. The first use puts my Energy
## aside; using it again while it holds gives the Energy back (what doesn't fit
## in the bar is lost). Left alone, what it holds is lost when it runs out.
func _capacitor() -> void:
	var col := Abilities.color_of(CAPACITOR_ID)
	if status.has(CAPACITOR_FX):
		var room := resource_max("energy") - float(resources["energy"])
		_gain("energy", _capacitor_stored)
		_overflow(capacitor_overflow(_capacitor_stored, room))   # Overflow: what didn't fit becomes a shield
		_capacitor_stored = 0.0
		status.remove(CAPACITOR_FX)
		_bottle_lightning()   # Rune of Bottled Lightning: my next Discharge is instant
		_load_quiver()        # Loaded Quiver: my next Storm Arrows are free
		_ring_effect(0.8, col)
		return
	if float(cooldowns.get(CAPACITOR_ID, 0.0)) > 0.0:
		_error("%s is not ready yet" % Abilities.ability_name(CAPACITOR_ID))
		return
	var take := capacitor_takes(float(resources["energy"]))
	if take < 1.0:
		_error("No Energy to store")
		return
	var res := Abilities.get_resource(CAPACITOR_ID)
	cooldowns[CAPACITOR_ID] = Abilities.cooldown_of(res)
	resources["energy"] = float(resources["energy"]) - take
	_capacitor_stored = take
	var fx := StatusContainer.make_buff(CAPACITOR_FX, str(res.display_name), CAPACITOR_FX, 0.0,
		Balance.CAPACITOR_TIME, 1, col)
	fx.stat_modifiers = {}
	fx.description = "Holds %d Energy. Use %s again to take it back." % [int(round(take)), str(res.display_name)]
	status.apply(fx, self)
	_ring_effect(1.0, col)
	_bus().cast_finished.emit(CAPACITOR_ID)

# --- Arcane caster: the cooldown kit -------------------------------------------------------
# Sigil Darts is the filler: a channel of darts with no cooldown. Unravel takes
# time off my other Arcane cooldowns, Lapse and Interval Ward make them recover
# faster, Rewind resets one, and Convergence hits harder for each one that is
# running. Countdown, Collapse and Mirror Sigil are the cooldowns worth juggling.
# "Arcane spell" = tagged Arcane + Spell. Interrupts are left out of every
# cooldown change (they share a cooldown of their own). Numbers are in balance.gd.

const ARCANE_MARK = preload("res://scripts/arcane_mark.gd")
const SIGIL_DARTS_ID := "arcanemissiles"
const UNRAVEL_ID := "unravel"
const COUNTDOWN_ID := "countdown"
const COUNTDOWN_FX := "countdown"
const CONVERGENCE_ID := "convergence"
const REWIND_ID := "rewind"
const LAPSE_ID := "lapse"
const LAPSE_FX := "lapse"
const MIRROR_ID := "mirrorsigil"
const MIRROR_FX := "mirror_sigil"
const COLLAPSE_ID := "collapse"
const SCATTER_ID := "scatter"
const SCATTER_FX := "scatter"
const SCATTER_LABEL := "Scatter"
const WARD_ID := "intervalward"
const WARD_FX := "interval_ward"
const AFTERIMAGE_RUNE := "afterimage"
const AFTERIMAGE_FX := "afterimage"
const ARCANE_TAGS := ["Arcane", "Spell"]
const GLINT_ID := "glint"
const GLINT_FX := "glint"
const MOMENTUM_RUNE := "momentum"
const CARRIED_RUNE := "carried_sigil"
## Rune of the Two-Way Mirror: Mirror Sigil also repeats my Reflections shattering.
const TWO_WAY_MIRROR_RUNE := "two_way_mirror"
const CHAIN_REACTION_ID := "chain_reaction"
const AFTERSHOCK_FX := "aftershock"

var _darts_total := 0            # darts this Sigil Darts launches in all (Seventh Sigil adds to it)
var _glint_cast := false         # the current cast / channel may go on while I move (Glint)
var _sigil_carried := false      # my Mirror Sigil moves with me (Rune of the Carried Sigil)
var _slow_mult_now := 1.0        # strength of the slow being applied right now (Aftershock's rank)

var _arcane_ids := {}            # ability id -> is it an Arcane spell (looked up once)
var _rewind_spell := ""          # the last Arcane spell I cast that Rewind can reset
var _darts_left := 0             # darts still to launch this channel
var _darts_dmg := 0.0
var _darts_fired := 0
var _darts_scattered := false    # this Sigil Darts used up Scatter
var _darts_targets: Array = []   # ... and deals its darts out between these
var _bolt_tag := ""              # the tag of the bolt whose hit is being dealt right now
var _countdowns := {}            # enemy instance id -> {"target": Node3D, "dealt": int, "base": float, "at": detonation time}
var _sigil_at := Vector3.ZERO    # where my Mirror Sigil stands
var _ward_until := 0.0           # when my Interval Ward would run out by itself
var _image_at := Vector3.ZERO    # where my Afterimage stands
var _image_spell := ""           # the spell the image is casting along with me
var _image_until := 0.0          # ... until this time

## Does the kit count something with these tags as an Arcane spell?
static func arcane_spell(tags: PackedStringArray, is_interrupt: bool = false) -> bool:
	return tags.has("Arcane") and tags.has("Spell") and not is_interrupt

func _is_arcane_spell(id: String) -> bool:
	if not _arcane_ids.has(id):
		_arcane_ids[id] = Abilities.PATHS.has(id) and arcane_spell(Abilities.tags_of(id), INTERRUPT_LOCKOUT.has(id))
	return bool(_arcane_ids[id])

## How fast my Arcane cooldowns recover (1 = normal) with Lapse and / or Interval Ward up.
static func arcane_recovery_rate(lapse: bool, ward: bool) -> float:
	return 1.0 + (Balance.LAPSE_RATE_PCT if lapse else 0.0) / 100.0 \
		+ (Balance.INTERVAL_WARD_RATE_PCT if ward else 0.0) / 100.0

## How fast one cooldown recovers (1 = normal). `spell_rate` (Lapse, Interval
## Ward) is for my Arcane spells alone; Running Clock's `clock_pct` % is for
## everything Arcane: those spells and whatever else is in the Arcane book
## (never an interrupt).
static func arcane_cooldown_rate(spell_rate: float, is_spell: bool, in_book: bool, clock_pct: float) -> float:
	var rate := spell_rate if is_spell else 1.0
	if is_spell or in_book:
		rate += maxf(clock_pct, 0.0) / 100.0
	return rate

var _arcane_book_ids := {}      # ability id -> is it in the Arcane book and no interrupt (looked up once)

func _in_arcane_book(id: String) -> bool:
	if not _arcane_book_ids.has(id):
		_arcane_book_ids[id] = shatter_cuts(Abilities.category_of(id), INTERRUPT_LOCKOUT.has(id))
	return bool(_arcane_book_ids[id])

func _arcane_rate() -> float:
	if status == null:
		return 1.0
	return arcane_recovery_rate(status.has(LAPSE_FX), status.has(WARD_FX))

## Arcane spells I have on cooldown (not counting `except`).
func arcane_cooldowns(except: String = "") -> int:
	var n := 0
	for id in cooldowns:
		if str(id) != except and float(cooldowns[id]) > 0.0 and _is_arcane_spell(str(id)):
			n += 1
	return n

## Convergence: % more damage with `count` other Arcane spells on cooldown.
static func convergence_bonus(count: int) -> float:
	return Balance.CONVERGENCE_PCT * clampi(count, 0, Balance.CONVERGENCE_MAX)

static func convergence_coef(base: float, count: int) -> float:
	return base * (1.0 + convergence_bonus(count) / 100.0)

## Unravel: what is left of a cooldown of `left` seconds after one cast.
static func unravel_cooldown(left: float) -> float:
	return maxf(left - Balance.UNRAVEL_SECONDS, 0.0)

func _unravel_cooldowns() -> void:
	for id in cooldowns.keys():
		if str(id) == UNRAVEL_ID or not _is_arcane_spell(str(id)):
			continue
		var left := unravel_cooldown(float(cooldowns[id]))
		if left <= 0.0:
			cooldowns.erase(id)
		else:
			cooldowns[id] = left

## Can Rewind reset a spell with these tags and this cooldown?
static func rewind_allows(tags: PackedStringArray, cooldown: float, is_interrupt: bool = false) -> bool:
	return arcane_spell(tags, is_interrupt) and cooldown > 0.0 and cooldown < Balance.REWIND_MAX_COOLDOWN

## Every spell I finish casting: Rewind remembers the last one it could reset.
func _on_cast_for_arcane(id: String) -> void:
	if id == REWIND_ID or not Abilities.PATHS.has(id):
		return
	var res := Abilities.get_resource(id)
	if res and rewind_allows(res.tags, Abilities.cooldown_of(res), INTERRUPT_LOCKOUT.has(id)):
		_rewind_spell = id

## An instant Arcane button that is off the global cooldown: ready and paid for?
func _arcane_instant_ok(id: String) -> bool:
	if float(cooldowns.get(id, 0.0)) > 0.0:
		_error("%s is not ready yet" % Abilities.ability_name(id))
		return false
	return true

func _arcane_buff(fx_id: String, id: String, time: float, text: String) -> void:
	var fx := StatusContainer.make_buff(fx_id, Abilities.ability_name(id), fx_id, 0.0, time, 1, Abilities.color_of(id))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Arcane"])
	fx.description = text
	status.apply(fx, self)

## Rewind: the last Arcane spell I cast with a short cooldown is ready again.
func _rewind() -> void:
	if not _arcane_instant_ok(REWIND_ID):
		return
	if _rewind_spell == "" or float(cooldowns.get(_rewind_spell, 0.0)) <= 0.0:
		_error("Nothing to rewind")
		return
	if not _pay(REWIND_ID):
		return
	cooldowns.erase(_rewind_spell)
	cooldowns[REWIND_ID] = Abilities.cooldown_of(Abilities.get_resource(REWIND_ID))
	_ring_effect(1.0, Abilities.color_of(REWIND_ID))
	_ring_effect(0.6, Color(0.95, 0.9, 1.0))
	_bus().cast_finished.emit(REWIND_ID)

## Lapse: my Arcane cooldowns recover faster for a while (see _tick_cooldowns).
func _lapse() -> void:
	if not _arcane_instant_ok(LAPSE_ID) or not _pay(LAPSE_ID):
		return
	cooldowns[LAPSE_ID] = Abilities.cooldown_of(Abilities.get_resource(LAPSE_ID))
	_arcane_buff(LAPSE_FX, LAPSE_ID, Balance.LAPSE_TIME, "Your Arcane spells recover their cooldowns faster.")
	_ring_effect(1.4, Abilities.color_of(LAPSE_ID))
	_bus().cast_finished.emit(LAPSE_ID)

## Scatter: my next Sigil Darts is dealt out between the enemies around its target.
func _scatter() -> void:
	if not _arcane_instant_ok(SCATTER_ID) or not _pay(SCATTER_ID):
		return
	cooldowns[SCATTER_ID] = Abilities.cooldown_of(Abilities.get_resource(SCATTER_ID))
	_arcane_buff(SCATTER_FX, SCATTER_ID, Balance.SCATTER_TIME,
		"Your next %s splits its darts between nearby enemies, and each dart deals more damage." % Abilities.ability_name(SIGIL_DARTS_ID))
	_ring_effect(0.9, Abilities.color_of(SCATTER_ID))
	_bus().cast_finished.emit(SCATTER_ID)

# Sigil Darts: a channel that launches ARCANE_MISSILES_COUNT darts, spread evenly
# over it (so Haste makes them come faster). Each dart is its own hit with its
# own crit roll. Paid for when the channel starts.

## Darts one Sigil Darts launches with `extra` more from Seventh Sigil.
static func dart_count(extra: float) -> int:
	return Balance.ARCANE_MISSILES_COUNT + maxi(int(round(extra)), 0)

func sigil_dart_count() -> int:
	return dart_count(_talent("arcane_seventh_sigil"))

## Which of `targets` enemies dart number `fired` (0 = the first) goes to.
static func dart_target(fired: int, targets: int) -> int:
	return fired % targets if targets > 0 else 0

## Scatter: my target and the closest other enemies around it that I can see.
func _scatter_targets(tgt: Node3D) -> Array:
	var out: Array = [tgt]
	for e in _enemies_near(tgt.global_position, Balance.SCATTER_RADIUS, tgt):
		if out.size() >= Balance.SCATTER_TARGETS:
			break
		if can_see(e):
			out.append(e)
	return out

func _start_sigil_darts() -> void:
	var id := SIGIL_DARTS_ID
	if casting or not is_on_floor():
		return
	if cooldown_left(id) > 0.0:
		_error("%s is not ready yet" % Abilities.ability_name(id))
		return
	if not _has_valid_target():
		_error("No target")
		return
	var res := Abilities.get_resource(id)
	if res.cast_range > 0.0 and global_position.distance_to(target.global_position) > res.cast_range:
		_error("Target out of range")
		return
	var sight_err := _target_error(target)
	if sight_err != "":
		_error(sight_err)
		return
	var instant := concentrated_fire_ready(id)
	if not _pay(id):
		return
	if float(res.cooldown) > 0.0:
		cooldowns[id] = Abilities.cooldown_of(res)
	_darts_dmg = float(res.damage)
	_darts_total = sigil_dart_count()
	_darts_fired = 0
	_darts_scattered = status.has(SCATTER_FX)
	_darts_targets = _scatter_targets(target) if _darts_scattered else []
	if _darts_scattered:
		status.remove(SCATTER_FX)   # this is the Sigil Darts it was waiting for
	if instant:
		# Concentrated Fire (Rune of the Level Head): no channel, the darts go out in a quick burst.
		status.spend_stacks(CONC_ID)
		var tgt := target
		for i in _darts_total:
			get_tree().create_timer(Balance.SIGIL_DARTS_BURST_GAP * i).timeout.connect(func():
				if is_alive() and is_instance_valid(tgt) and tgt.is_alive():
					_launch_dart(tgt))
		_bus().cast_finished.emit(id)   # an instant: starts the global cooldown like one
		return
	_begin_spell(id, str(res.display_name), float(res.cast_time), true)
	_darts_left = _darts_total if casting and current_spell == id else 0

## One dart: at `main`, or (Scatter) at whichever enemy's turn it is.
func _launch_dart(main: Node3D) -> void:
	var tgt := main
	if _darts_scattered:
		var live := _darts_targets.filter(func(e): return is_instance_valid(e) and e.is_alive())
		if not live.is_empty():
			tgt = live[dart_target(_darts_fired, live.size())]
	_darts_fired += 1
	if not is_instance_valid(tgt) or not tgt.is_alive():
		return
	var bolt := FROST_BOLT.spawn(get_tree().current_scene, _muzzle(), tgt, self, false, SIGIL_DARTS_ID, _darts_dmg)
	if _darts_scattered:
		bolt.set("tag", SCATTER_FX)   # (its hit gets Scatter's bonus: bolt_tag, _on_damage_modify)

## A bolt of mine tells me its tag right before its hit is dealt ("" right after).
func bolt_tag(t: String) -> void:
	_bolt_tag = t

## Launch every dart that is due by now (`final` = all that are left).
func _sigil_darts_tick(final: bool = false) -> void:
	if _darts_left <= 0:
		return
	var hits := maxi(_darts_total, 1)
	var due := hits
	if not final:
		var every := maxf(cast_duration / hits, 0.01)
		due = mini(int(floor((cast_duration - maxf(cast_timer, 0.0)) / every + 0.0001)), hits)
	while hits - _darts_left < due:
		_darts_left -= 1
		if _has_valid_target():
			_launch_dart(target)

# Countdown: a mark on one enemy (own only). It counts the Arcane damage I deal
# to that enemy, and after COUNTDOWN_TIME seconds it detonates for the ability's
# damage plus COUNTDOWN_SHARE_PCT % of what it counted. Casting it again on the
# same enemy sets the old mark off first.

## Countdown: the extra damage for `dealt` Arcane damage counted, at `pct` % of it.
static func countdown_bonus(dealt: int, pct: float) -> int:
	return int(round(maxf(float(dealt), 0.0) * maxf(pct, 0.0) / 100.0))

func _plant_countdown(tgt: Node3D) -> void:
	if tgt == null or not is_instance_valid(tgt) or not tgt.is_alive():
		return
	var key := tgt.get_instance_id()
	if _countdowns.has(key):
		_detonate_countdown(key)   # the old mark goes off now
		if not is_instance_valid(tgt) or not tgt.is_alive():
			return
	_countdowns[key] = {"target": tgt, "dealt": 0, "base": float(Abilities.get_resource(COUNTDOWN_ID).damage),
		"at": Time.get_ticks_msec() / 1000.0 + Balance.COUNTDOWN_TIME}
	# The debuff shows the mark to the whole party (it only ever counts MY damage).
	_apply_effect_hit(tgt, preload("res://scripts/core/effects.gd").get_effect(COUNTDOWN_FX), COUNTDOWN_ID,
		PackedStringArray(ARCANE_TAGS), "arcane")
	_ring_effect(0.8, Abilities.color_of(COUNTDOWN_ID), tgt.global_position)

## A hit of mine landed: Arcane damage on a marked enemy is counted.
func _countdown_tally(foe: Node, id: String, damage_type: String, amount: int) -> void:
	if _countdowns.is_empty() or amount <= 0 or id == COUNTDOWN_ID or damage_type != "arcane":
		return
	var key := foe.get_instance_id()
	if _countdowns.has(key):
		_countdowns[key]["dealt"] = int(_countdowns[key]["dealt"]) + amount

func _tick_countdowns() -> void:
	if _countdowns.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	for key in _countdowns.keys():
		var c: Dictionary = _countdowns[key]
		if not is_instance_valid(c["target"]) or not c["target"].is_alive():
			_countdowns.erase(key)
		elif now >= float(c["at"]):
			_detonate_countdown(key)

func _detonate_countdown(key: int) -> void:
	var c: Dictionary = _countdowns[key]
	_countdowns.erase(key)
	var tgt: Variant = c["target"]
	if not is_instance_valid(tgt) or not tgt.is_alive():
		return
	var net := _net()
	if net:
		net.remove_effect(tgt, self, COUNTDOWN_FX)   # the host owns enemy effects in a party
	else:
		var st: Node = tgt.get_node_or_null("Status")
		if st:
			st.remove_from(COUNTDOWN_FX, self)
	_ring_effect(1.5, Abilities.color_of(COUNTDOWN_ID), tgt.global_position)
	_ring_effect(0.8, Color(0.95, 0.9, 1.0), tgt.global_position)
	var at: Vector3 = tgt.global_position   # (kept: the target may not survive it)
	deal_damage(tgt, float(c["base"]), COUNTDOWN_ID, true)
	# What it counted was already worked out hit by hit: its share is dealt as it is.
	var extra := countdown_bonus(int(c["dealt"]), Balance.COUNTDOWN_SHARE_PCT)
	_exact_hit(tgt, extra, COUNTDOWN_ID, "arcane", PackedStringArray(ARCANE_TAGS))
	_chain_reaction(at, tgt, extra)   # Chain Reaction: part of it hits the enemies around

## Deal exactly `amount` damage to `foe` under ability `id`: a proc that can't
## crit or be avoided, with nothing added (its source was already worked out)
## but `bonuses`: [percent, label] rows that come on top, each a line of its own
## on the damage meter.
func _exact_hit(foe: Variant, amount: int, id: String, damage_type: String, tags: PackedStringArray, bonuses: Array = []) -> void:
	if amount <= 0 or foe == null or not is_instance_valid(foe) or not foe.is_alive():
		return
	var hit := DamageInfo.make(self, foe, 1.0, id)
	for b in bonuses:
		hit.add_bonus(float(b[0]), str(b[1]))
	hit.unit = float(amount)
	hit.exact = true
	hit.add_power = false
	hit.can_crit = false
	hit.can_block = false
	hit.is_proc = true
	hit.damage_type = damage_type
	hit.tags = tags
	_combat().deal(hit)

# Echoes: Mirror Sigil and the Rune of the Afterimage repeat my spells. Each
# echo is an exact share of the hit it repeats (its crit and every modifier are
# already in it), flown from where the sigil / image stands, and dealt as a proc
# under its own name, so it has its own line on the damage meter and feeds nothing.

## Damage of an echo of a hit of `amount` at `pct` % of it.
static func echo_amount(amount: int, pct: float) -> int:
	return int(round(maxf(float(amount), 0.0) * maxf(pct, 0.0) / 100.0))

## Does Mirror Sigil repeat this hit? My Arcane spells' own hits (and Countdown
## going off), not damage over time, procs or another echo.
## `two_way` = the Rune of the Two-Way Mirror: a Reflection shattering is repeated too.
static func mirror_echoes(tags: PackedStringArray, is_proc: bool, id: String, two_way: bool = false) -> bool:
	if id == REFLECTION_SHATTER_ID:
		return two_way
	if id == MIRROR_ID or id == AFTERIMAGE_RUNE or not arcane_spell(tags):
		return false
	return not is_proc or id == COUNTDOWN_ID

func _echo_hit(info: RefCounted, pct: float, id: String, from: Vector3) -> void:
	var foe: Node = info.target
	var amount := echo_amount(int(info.amount), pct)
	if amount <= 0 or not (foe is Node3D):
		return
	# The picture of the spell flies from the sigil / image; the hit lands with it.
	# (What it repeats is not always an ability, e.g. a Reflection shattering: then it looks like the echo itself.)
	var look := str(info.ability_id) if Abilities.PATHS.has(str(info.ability_id)) or not Abilities.PATHS.has(id) else id
	FROST_BOLT.spawn(get_tree().current_scene, from, foe, null, true, look, 0.0)
	var net := _net()
	if net:
		net.send_fx("bolt", from, foe, look)
	var damage_type := str(info.damage_type)
	var tags: PackedStringArray = info.tags
	var wait := from.distance_to(foe.global_position) / maxf(Balance.BOLT_SPEED, 1.0)
	get_tree().create_timer(maxf(wait, 0.02)).timeout.connect(func():
		if is_alive():
			_exact_hit(foe, amount, id, damage_type, tags))

## Mirror Sigil: a cast, then the sigil stands where I stood.
func _start_mirror_sigil() -> void:
	if casting or not is_on_floor():
		return
	if cooldown_left(MIRROR_ID) > 0.0:
		_error("%s is not ready yet" % Abilities.ability_name(MIRROR_ID))
		return
	if not can_afford(MIRROR_ID, true):
		return
	var res := Abilities.get_resource(MIRROR_ID)
	cast_point = global_position + _flat_forward() * 5.0   # (what I face while casting)
	_begin_spell(MIRROR_ID, str(res.display_name), float(res.cast_time))

func _place_mirror_sigil() -> void:
	var res := Abilities.get_resource(MIRROR_ID)
	cooldowns[MIRROR_ID] = Abilities.cooldown_of(res)
	_sigil_at = Vector3(global_position.x, Combat.feet_y(self), global_position.z)
	_sigil_carried = _has_rune(CARRIED_RUNE)   # Rune of the Carried Sigil: it moves with me
	_arcane_buff(MIRROR_FX, MIRROR_ID, Balance.MIRROR_SIGIL_TIME,
		"Your sigil follows you and repeats the Arcane spells you cast." if _sigil_carried \
		else "Your sigil repeats the Arcane spells you cast.")
	_arcane_mark("sigil", _sigil_at, Balance.MIRROR_SIGIL_RADIUS, Balance.MIRROR_SIGIL_TIME, _sigil_carried)
	_ring_effect(Balance.MIRROR_SIGIL_RADIUS, Abilities.color_of(MIRROR_ID))

## Show one of the kit's ground pictures, here and to the party (time 0 = take it away).
## `carried` = it moves with me (Rune of the Carried Sigil).
func _arcane_mark(kind: String, at: Vector3, r: float, time: float, carried: bool = false) -> void:
	if not is_inside_tree():
		return
	if time > 0.0:
		var mark := ARCANE_MARK.spawn(get_tree().current_scene, at, r, time, kind, "me")
		if carried:
			mark.set("follow", self)
	else:
		ARCANE_MARK.clear(get_tree(), kind, "me")
	_net_fx("arcanemark", at, null, {"kind": kind, "r": r, "time": time, "follow": carried})

# Collapse: ground-targeted. COLLAPSE_DELAY seconds after the cast the circle
# falls in on its centre: it damages every enemy in it and drags them toward the
# middle (bosses are too heavy, and nobody is dragged through a wall).

## Where an enemy at `pos` ends up when a Collapse at `centre` drags it `pull`
## metres (never closer to the centre than `core`). Height is kept.
static func collapse_point(pos: Vector3, centre: Vector3, pull: float, core: float) -> Vector3:
	var to := Vector3(centre.x - pos.x, 0.0, centre.z - pos.z)
	var dist := to.length()
	var step := minf(maxf(pull, 0.0), maxf(dist - core, 0.0))
	if step <= 0.0 or dist <= 0.001:
		return pos
	return pos + to / dist * step

func _start_collapse(point: Vector3) -> void:
	if casting or not is_on_floor():
		return
	cast_point = point
	if not can_afford(COLLAPSE_ID, true):
		return
	var res := Abilities.get_resource(COLLAPSE_ID)
	_begin_spell(COLLAPSE_ID, str(res.display_name), float(res.cast_time))

func _cast_collapse() -> void:
	var res := Abilities.get_resource(COLLAPSE_ID)
	cooldowns[COLLAPSE_ID] = Abilities.cooldown_of(res)
	var at := cast_point
	var r := float(res.radius)
	var coef := float(res.damage)
	_arcane_mark("collapse", at, r, Balance.COLLAPSE_DELAY)
	get_tree().create_timer(Balance.COLLAPSE_DELAY).timeout.connect(func(): _collapse_implode(at, r, coef))

func _collapse_implode(at: Vector3, r: float, coef: float) -> void:
	if is_dead():
		return
	var col := Abilities.color_of(COLLAPSE_ID)
	_ring_effect(r * 0.4, col, at + Vector3(0, 0.9, 0))
	_ring_effect(r * 0.15, Color(0.95, 0.9, 1.0), at + Vector3(0, 0.9, 0))
	var hit := _enemies_near(at, r)
	var share := coef * Balance.aoe_share(hit.size())
	var net := _net()
	for e in hit:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		deal_damage(e, share, COLLAPSE_ID)
		if not is_instance_valid(e) or not e.is_alive() or str(e.get("rank")) == "boss":
			continue   # (bosses are too heavy to pull)
		var from: Vector3 = e.global_position
		var to := collapse_point(from, at, Balance.COLLAPSE_PULL + _talent("arcane_deep_well"), Balance.COLLAPSE_CORE)   # Deep Well
		if to.is_equal_approx(from) \
				or not Combat.line_of_sight(get_world_3d(), from + Vector3(0, 0.3, 0), to + Vector3(0, 0.3, 0)):
			continue
		if net:
			net.drag(e, to, Balance.COLLAPSE_DRAG_TIME)   # the host owns enemies in a party
		elif e.has_method("drag_to"):
			e.drag_to(to, Balance.COLLAPSE_DRAG_TIME)
		_aftershock(e)   # Aftershock: the ones it pulled are slowed

# Interval Ward: a shield on me. While it holds, my Arcane cooldowns recover
# faster (_arcane_rate). Broken early by damage, the time it had left comes off
# its own cooldown.

## Interval Ward's cooldown after the shield broke with `left` seconds to go.
static func ward_cooldown_after_break(cooldown: float, left: float) -> float:
	return maxf(cooldown - maxf(left, 0.0), 0.0)

func _interval_ward() -> void:
	var amount := int(round(_combat().heal_amount(self, float(Abilities.HEALS[WARD_ID]), WARD_ID) * absorb_mult()))
	if amount <= 0:
		return
	var col := Abilities.color_of(WARD_ID)
	var fx := StatusContainer.make_buff(WARD_FX, Abilities.ability_name(WARD_ID), WARD_FX, 0.0,
		Balance.INTERVAL_WARD_TIME, 1, col)
	var armor := _talent("frost_shield_armor")   # Hardened Frost: my shields add armor
	fx.stat_modifiers = {"armor%": armor} if armor > 0.0 else {}
	fx.tags = PackedStringArray(["Arcane"])
	fx.description = "A shield absorbs damage. While it holds, your Arcane spells recover their cooldowns faster."
	if status.apply(fx, self):
		status.set_absorb(WARD_FX, amount)
		_ward_until = Time.get_ticks_msec() / 1000.0 + Balance.INTERVAL_WARD_TIME
	_ring_effect(1.3, col)

## My Interval Ward was used up by damage: what it had left comes off its cooldown.
func _ward_broke() -> void:
	var left := _ward_until - Time.get_ticks_msec() / 1000.0
	_ward_until = 0.0
	if left <= 0.0 or not cooldowns.has(WARD_ID):
		return
	var cd := ward_cooldown_after_break(float(cooldowns[WARD_ID]), left)
	if cd <= 0.0:
		cooldowns.erase(WARD_ID)
	else:
		cooldowns[WARD_ID] = cd

# Rune of the Afterimage: Phase Step and Flicker leave an image where I stood
# for AFTERIMAGE_TIME seconds. The first spell I deal damage with in that time is
# cast by the image too: every hit of that spell is echoed at AFTERIMAGE_PCT %.

## Seconds the image keeps casting once a spell has woken it: a channel for
## what is left of it, Ice Shards while shards are still to fire, anything else
## for a moment (so every enemy an area spell hits is echoed).
static func afterimage_window(channel_left: float, shards_left: int) -> float:
	if channel_left > 0.0:
		return channel_left + Balance.AFTERIMAGE_TRAVEL
	if shards_left > 0:
		return shards_left * Balance.ICE_SHARDS_INTERVAL + Balance.AFTERIMAGE_TRAVEL
	return Balance.AFTERIMAGE_BURST

func _leave_afterimage(from: Vector3) -> void:
	if status == null or not _has_rune(AFTERIMAGE_RUNE):
		return
	_image_at = Vector3(from.x, from.y - (global_position.y - Combat.feet_y(self)), from.z)
	_image_spell = ""
	_image_until = 0.0
	var fx := StatusContainer.make_buff(AFTERIMAGE_FX, "Afterimage", AFTERIMAGE_FX, 0.0,
		Balance.AFTERIMAGE_TIME, 1, Color(0.75, 0.5, 1.0))
	fx.stat_modifiers = {}
	fx.description = "The next spell you deal damage with is also cast by your image."
	status.apply(fx, self)
	_arcane_mark("image", _image_at, 0.6, Balance.AFTERIMAGE_TIME)

## Every hit I deal: Countdown counts it, Mirror Sigil and the Afterimage repeat it.
func _on_damage_dealt_arcane(info: RefCounted) -> void:
	if not is_same(info.source, self) or info.avoided() or not is_instance_valid(info.target):
		return
	var amount := int(info.amount)
	if amount <= 0:
		return
	var id := str(info.ability_id)
	_countdown_tally(info.target, id, str(info.damage_type), amount)
	_trace_hit(info, id, amount)   # Arcane melee: a strike leaves a Trace
	_echo_talent(info, id, amount)   # Echo: any spell or ability may be repeated
	_spillover_talent(info, id, amount)   # Spillover: part of a critical strike jumps on
	if bool(info.is_dot) or status == null or not (info.target is Node3D):
		return
	if status.has(MIRROR_FX) and mirror_echoes(info.tags, bool(info.is_proc), id,
			id == REFLECTION_SHATTER_ID and _has_rune(TWO_WAY_MIRROR_RUNE)):
		_echo_hit(info, mirror_pct(_talent("arcane_polished_glass"), _sigil_carried), MIRROR_ID, _sigil_origin())
	if bool(info.is_proc) or not info.tags.has("Spell") or not Abilities.PATHS.has(id):
		return
	if bool(info.crit):
		_arcane_crit_talents(id)   # Etched Darts, Frayed
	var now := Time.get_ticks_msec() / 1000.0
	if status.has(AFTERIMAGE_FX):
		# This is the spell the image casts along with me.
		status.remove(AFTERIMAGE_FX)
		_image_spell = id
		var channel_left := cast_timer if casting and cast_is_channel and current_spell == id else 0.0
		var window := afterimage_window(channel_left, _shards_left if id == "iceshards" else 0)
		_image_until = now + window
		_arcane_mark("image", _image_at, 0.6, window + 0.3)   # it stays for as long as it is casting
	if id == _image_spell and now <= _image_until:
		_echo_hit(info, Balance.AFTERIMAGE_PCT, AFTERIMAGE_RUNE, _image_at + Vector3(0, 1.0, 0))

# Glint: an instant bolt. For GLINT_TIME seconds afterwards my next Unravel or
# Sigil Darts (with the Rune of Momentum: any spell with a cast time) can be cast
# or channelled while moving. A cast uses the buff up when it finishes, a
# channel when it starts.

## Can Glint let this be cast on the move? `any_spell` = the Rune of Momentum.
static func glint_applies(id: String, tags: PackedStringArray, cast_time: float, any_spell: bool) -> bool:
	if cast_time <= 0.0:
		return false
	return id == UNRAVEL_ID or id == SIGIL_DARTS_ID or (any_spell and tags.has("Spell"))

## Would casting `id` right now be a cast on the move from Glint?
func glint_ready(id: String) -> bool:
	if status == null or not status.has(GLINT_FX):
		return false
	var res := Abilities.get_resource(id)
	return res != null and glint_applies(id, res.tags, float(res.cast_time), _has_rune(MOMENTUM_RUNE))

func _glint(res: Resource) -> void:
	FROST_BOLT.spawn(get_tree().current_scene, _muzzle(), target, self, false, GLINT_ID, float(res.damage))
	var text := "Your next spell with a cast time can be cast while moving."
	if not _has_rune(MOMENTUM_RUNE):
		text = "Your next %s or %s can be cast while moving." % [Abilities.ability_name(UNRAVEL_ID),
			Abilities.ability_name(SIGIL_DARTS_ID)]
	# Keep Moving: the window lasts longer; its capstone: it covers more than one cast.
	var casts := Balance.KEEP_MOVING_CASTS if _capstone("arcane_keep_moving") else 1
	var fx := StatusContainer.make_buff(GLINT_FX, Abilities.ability_name(GLINT_ID), GLINT_FX, 0.0,
		glint_time(_talent("arcane_keep_moving")), casts, Abilities.color_of(GLINT_ID))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Arcane"])
	fx.description = text
	status.remove(GLINT_FX)   # (a fresh one: every cast it covers is there again)
	status.apply(fx, self)
	if casts > 1:
		status.set_stacks(GLINT_FX, casts)

# --- Arcane talents ----------------------------------------------------------------------

## Take `seconds` off the cooldown of `id` (nothing happens if it is ready).
func _cut_cooldown(id: String, seconds: float) -> void:
	if not cooldowns.has(id):
		return
	var left := float(cooldowns[id]) - seconds
	if left <= 0.0:
		cooldowns.erase(id)
	else:
		cooldowns[id] = left

## One of my spells' own hits critically struck. Etched Darts: a dart may take
## time off Countdown and Collapse. Frayed: Unravel may take its time off again.
func _arcane_crit_talents(id: String) -> void:
	if id == SIGIL_DARTS_ID:
		var etched := _talent("arcane_etched_darts")
		if etched > 0.0 and randf() * 100.0 < etched:
			_cut_cooldown(COUNTDOWN_ID, Balance.ETCHED_DARTS_SECONDS)
			_cut_cooldown(COLLAPSE_ID, Balance.ETCHED_DARTS_SECONDS)
	elif id == UNRAVEL_ID:
		var frayed := _talent("arcane_frayed")
		if frayed > 0.0 and randf() * 100.0 < frayed:
			_unravel_cooldowns()

## Chain Reaction: damage each of `count` enemies around a Countdown takes when
## it counted `bonus` extra damage, at `pct` % of it (more than AOE_TARGET_CAP
## enemies share that many hits).
static func chain_reaction_damage(bonus: int, pct: float, count: int) -> int:
	if count <= 0:
		return 0
	return int(round(maxf(float(bonus), 0.0) * maxf(pct, 0.0) / 100.0 * Balance.aoe_share(count)))

## Chain Reaction: my Countdown went off at `at` on `main`. A share of what it
## counted hits the enemies around it, as its own line on the damage meter.
func _chain_reaction(at: Vector3, main: Variant, bonus: int) -> void:
	var pct := _talent("arcane_chain_reaction")
	if pct <= 0.0 or bonus <= 0:
		return
	var skip: Node = main if (main != null and is_instance_valid(main)) else null
	var near := _enemies_near(at, Balance.CHAIN_REACTION_RADIUS, skip)
	var each := chain_reaction_damage(bonus, pct, near.size())
	for e in near:
		_exact_hit(e, each, CHAIN_REACTION_ID, "arcane", PackedStringArray(ARCANE_TAGS))
		if is_instance_valid(e):
			_ring_effect(0.6, Abilities.color_of(COUNTDOWN_ID), e.global_position)

## % of a hit my Mirror Sigil repeats: Polished Glass adds `talent_bonus`; the
## Rune of the Carried Sigil (`carried`) starts it lower.
static func mirror_pct(talent_bonus: float, carried: bool) -> float:
	return (Balance.CARRIED_SIGIL_PCT if carried else Balance.MIRROR_SIGIL_PCT) + maxf(talent_bonus, 0.0)

## Where my Mirror Sigil's echoes fly from: the shard over the sigil, or over
## my head when I carry it.
func _sigil_origin() -> Vector3:
	if _sigil_carried:
		return Vector3(global_position.x, Combat.feet_y(self) + ARCANE_MARK.CARRIED_HEIGHT, global_position.z)
	return _sigil_at + Vector3(0, ARCANE_MARK.SHARD_HEIGHT, 0)

## Aftershock: how many times the effect's own slow a talent value of `slow_pct` % is.
static func aftershock_mult(slow_pct: float) -> float:
	return maxf(slow_pct, 0.0) / Balance.AFTERSHOCK_SLOW_STEP

## Aftershock: an enemy my Collapse pulled is slowed (as strongly as the rank says).
func _aftershock(e: Node) -> void:
	var slow := _talent("arcane_aftershock")
	if slow <= 0.0:
		return
	_slow_mult_now = aftershock_mult(slow)   # (slow_mult() answers with this while the effect is applied)
	_apply_effect_hit(e, preload("res://scripts/core/effects.gd").get_effect(AFTERSHOCK_FX), COLLAPSE_ID,
		PackedStringArray(ARCANE_TAGS), "arcane")
	_slow_mult_now = 1.0

## Dead or downed: marks fizzle, the sigil and the image go.
func _clear_arcane() -> void:
	_countdowns.clear()
	_darts_left = 0
	_image_spell = ""
	_image_until = 0.0
	_arcane_mark("sigil", _sigil_at, 0.0, 0.0)
	_arcane_mark("image", _image_at, 0.0, 0.0)
	_clear_traces()
	_clear_decay()   # Shadow: my Decays go with me, and their debuffs

# --- Shadow caster: Decay ------------------------------------------------------------------
# NAMES. In the game this is the BREACH: a hole the caster opens in the ground
# under an enemy, with demons clawing at its feet through it (which is why it
# is open or closed). The code and the data keep the first names: Decay = the
# Breach, Blight = Break Ground, Erode = Beckon, Spill = Widen, Pall = Many
# Hands, Rune of the Open Wound = Rune of the Trapdoor, Rune of Rot = Rune of
# Invitation, and the talents Seep = Lure, Running Over = Wider Still, Rot
# Through = Hooked Claws, Tainted Steel = Baited Steel. Call Due, Gnaw, Hush,
# Take It Back and Bottomless kept their names. Read "Decay" below as "what is
# left in the Breach". (Sink In / Usher In and its talent Loose Grains were
# removed, and so was the book's starting spell, Gloom Bolt.)
# What it LOOKS like - the hole under the enemy and the hands clawing out of
# it - is scripts/breach_fx.gd: the enemy shows it from its own debuffs, so
# everyone in the party sees it.
# Decay is my own damage over time on an enemy, kept here as an amount of real
# damage (like Permafrost's pool). Every DECAY_TICK seconds (faster with Haste)
# it deals DECAY_TICK_PCT % of that amount and shrinks by as much. A tick can
# crit: what the crit adds comes on top, the amount shrinks no faster.
# Blight puts it on a target and OPENS it for DECAY_OPEN_TIME seconds. While it
# is open, my other Shadow spells add DECAY_FEED_PCT % of the direct damage they
# deal to it (Blight and Erode: all of theirs). When that time is up it is
# CLOSED: it keeps ticking but can't grow, and once less than DECAY_LAST_DROP is
# left, its next tick deals all of it and it ends. Blight opens a closed one
# again and keeps its amount. Call Due deals all of it at once and ends it. When
# the enemy dies, what is left moves to the nearest enemy.
# Own only: the amount lives here and every tick is dealt on my machine, with my
# stats. The enemy carries a debuff that shows it to the party (decay.tres while
# it is open, decay_closed.tres after): its stack count is the amount
# (StatusEffectData.stacks_are_amount), its time the open time left.
# Tainted Steel (a talent) lets my Shadow abilities add to an open Decay too,
# and the Rune of Rot my other books' spells. Numbers are in balance.gd.

const DECAY_FX := "decay"                  # the debuff that shows an open Decay
const DECAY_CLOSED_FX := "decay_closed"    # ... and a closed one
const DECAY_HIT_ID := "dot_decay"          # its ticks on the damage meter and in the log ("Decay (Periodic)")
const BLIGHT_ID := "blight"
const CALL_DUE_ID := "calldue"
const GNAW_ID := "gnaw"
const SPILL_ID := "spill"
const PALL_ID := "pall"
const HUSH_ID := "hush"
const TAKE_IT_BACK_ID := "takeitback"
const TAKE_IT_BACK_FX := "take_it_back"
const BOTTOMLESS_ID := "bottomless"
const BOTTOMLESS_FX := "bottomless"
const ERODE_ID := "erode"
const WITHER_TICK_ID := "dot_corrupted"    # a tick of Wither's damage over time (Seep)
const INTEREST_FX := "interest"            # Interest's capstone: my next Blight is instant
const DECAY_CRIT_META := "decay_crit"      # on a tick's DamageInfo: % crit chance it gets on top (Bite Down)
## Rune of the Open Wound: Blight is instant, on a cooldown, and opens Decay for less time.
const OPEN_WOUND_RUNE := "open_wound"
## Rune of Rot (up to 3 equipped): my other books' spells add to an open Decay, for each copy.
const ROT_RUNE := "rot"
## Rune of the Long Fall (Epic): when part of what is left in my Decay would be
## enough to kill its enemy, all of it is dealt at once (see _tick_decay).
const LONG_FALL_RUNE := "long_fall"
const LONG_FALL_HIT_ID := "rune_long_fall"   # that hit on the damage meter and in the log (the rune's name)
const SHADOW_TAGS := ["Shadow", "Spell"]
const DECAY_TAGS := ["Shadow", "Spell", "DoT"]
const DECAY_ERROR := "Your Breach isn't under that target"

## enemy instance id -> {"target": Node3D, "amount": damage it has left, "open":
## time it closes, "next": time of its next tick, "fast": time Gnaw runs out,
## "pos": where the enemy was last seen, "shown": the debuff that shows it,
## "dirty": that debuff's number is out of date, "sync": when it may be sent next}
var _decay := {}
var _bottomless_until := 0.0   # when the Bottomless I last used runs out (No Floor holds Decay open until then)

## Does something with these tags count as one of my Shadow spells?
static func shadow_spell(tags: PackedStringArray) -> bool:
	return tags.has("Shadow") and tags.has("Spell")

## % of the damage of a hit of mine that goes into my open Decay on its target
## (0 = none of it). Only direct hits feed it: never a tick, a proc, or Decay's
## own damage. `ability_pct` = Tainted Steel (my Shadow abilities), `other_pct`
## = the Rune of Rot (my spells of the other books: rot_rune_pct).
static func decay_feed_pct(id: String, tags: PackedStringArray, is_proc: bool, is_dot: bool,
		ability_pct: float = 0.0, other_pct: float = 0.0) -> float:
	if is_proc or is_dot or id == DECAY_HIT_ID or id == CALL_DUE_ID:
		return 0.0
	if shadow_spell(tags):
		if id == BLIGHT_ID:
			return Balance.BLIGHT_FEED_PCT
		return Balance.ERODE_FEED_PCT if id == ERODE_ID else Balance.DECAY_FEED_PCT   # Erode (Beckon) builds it
	if tags.has("Shadow"):
		return maxf(ability_pct, 0.0)
	return maxf(other_pct, 0.0) if tags.has("Spell") else 0.0

## Damage one tick of a Decay of `amount` deals (and the Decay shrinks by).
static func decay_tick(amount: float) -> float:
	return maxf(amount, 0.0) * Balance.DECAY_TICK_PCT / 100.0

## Seconds between a Decay's ticks. `haste` = my Haste as a speed multiplier,
## `fast` = Gnaw is on it.
static func decay_interval(haste: float, fast: bool = false, wasting_pct: float = 0.0) -> float:
	var speed := maxf(haste, 0.1) * (Balance.GNAW_SPEED_MULT if fast else 1.0) * dot_speed_with(1.0, wasting_pct)   # Wasting
	return maxf(Balance.DECAY_TICK / speed, 0.05)

## Rune of the Long Fall: is a Decay of `amount` big enough for an enemy with
## `health` left? LONG_FALL_PCT % of it has to cover that health. (All of it is
## then dealt, so there is room for whatever the enemy has to protect itself.)
static func long_fall_applies(amount: float, health: float) -> bool:
	return health > 0.0 and maxf(amount, 0.0) * Balance.LONG_FALL_PCT / 100.0 >= health

## No Floor: must a Decay that closes at `open_until` be kept open? `hold_until`
## = when Bottomless ends (0 = it is not running, or no capstone). Only one that
## is still open is held: a closed one stays closed.
static func decay_held_open(open_until: float, now: float, hold_until: float) -> bool:
	return hold_until > now and open_until > now and open_until < hold_until

## Is a Decay of `amount` down to its last drop (its next tick deals all of it
## and ends it)? Only a closed one ends that way. `unit` = the real damage of a
## standard spell hit of mine.
static func decay_last_drop(amount: float, open: bool, unit: float) -> bool:
	return not open and amount < Balance.DECAY_LAST_DROP * maxf(unit, 0.0)

## Call Due: the damage of taking out a Decay of `amount` (`extra_pct` = Interest).
static func call_due_damage(amount: float, extra_pct: float = 0.0) -> float:
	return maxf(amount, 0.0) * (1.0 + (Balance.CALL_DUE_BONUS_PCT + maxf(extra_pct, 0.0)) / 100.0)

## Small Change: what Call Due leaves on the target of a Decay of `amount`.
static func call_due_left(amount: float, pct: float) -> float:
	return maxf(amount, 0.0) * clampf(pct, 0.0, 100.0) / 100.0

## Next of Kin: what moves on of a Decay with `left` in it when its enemy dies
## (`pct` = the talent). `second` = what the next nearest enemy gets (its capstone).
static func kin_amount(left: float, pct: float, second: bool = false) -> float:
	var moved := maxf(left, 0.0) * (1.0 + maxf(pct, 0.0) / 100.0)
	return moved * Balance.NEXT_OF_KIN_SECOND_PCT / 100.0 if second else moved

## Seep: % of a hit's damage that goes into my open Decay because it is a tick
## of Wither (`pct` = the talent; 0 = it is not, or no talent).
static func seep_feed_pct(id: String, pct: float) -> float:
	return maxf(pct, 0.0) if id == WITHER_TICK_ID else 0.0

## Seconds Bottomless lasts (`extra` = No Floor).
static func bottomless_time(extra: float = 0.0) -> float:
	return Balance.BOTTOMLESS_TIME + maxf(extra, 0.0)

## % more a tick of my Decay deals: Slow Death (all my damage over time), Rot
## Through (Decay's ticks) and, on the last drop, Bitter End. As [pct, label]
## pairs, one for each that adds something (each gets its own line on the meter).
static func decay_tick_bonuses(slow_death: float, rot_through: float, bitter_end: float, last_drop: bool) -> Array:
	var out: Array = []
	if slow_death > 0.0:
		out.append([slow_death, "Slow Death"])
	if rot_through > 0.0:
		out.append([rot_through, "Hooked Claws"])
	if last_drop and bitter_end > 0.0:
		out.append([bitter_end, "Bitter End"])
	return out

## Interest's capstone: is my next Blight instant?
func interest_ready() -> bool:
	return status != null and status.has(INTEREST_FX)

## Spill: what each copy of a Decay of `amount` gets.
## (`extra_pct` = Running Over.)
static func spill_amount(amount: float, extra_pct: float = 0.0) -> float:
	return maxf(amount, 0.0) * (Balance.SPILL_PCT + maxf(extra_pct, 0.0)) / 100.0

## Until when a copy Spill makes is open: as long as the Decay it came from
## (`open_until`), and with Running Over's capstone (`at_least`) never less than
## RUNNING_OVER_OPEN_TIME from `now`.
static func spill_open_until(open_until: float, now: float, at_least: bool) -> float:
	return maxf(open_until, now + Balance.RUNNING_OVER_OPEN_TIME) if at_least else open_until

## Bite Down: % crit chance a tick of my Decay gets on top (`fast` = Gnaw is on
## it, `pct` = the talent).
static func bite_down_crit(fast: bool, pct: float) -> float:
	return maxf(pct, 0.0) if fast else 0.0

## Cut Short: what Hush's cooldown is after it interrupted a cast, when it had
## `left` to go and the talent takes `cut` seconds off. Never under what all
## interrupts share (or what it already was, if that is less).
static func cut_short_cooldown(left: float, cut: float) -> float:
	return maxf(left - maxf(cut, 0.0), minf(left, Balance.INTERRUPT_SHARED_COOLDOWN))

## Why Spill can't be used on a target with `amount` of my Decay and `others`
## enemies in reach of it ("" = it can).
static func spill_error(amount: float, others: int) -> String:
	if amount <= 0.0:
		return DECAY_ERROR
	return "" if others > 0 else "No other enemy in reach"

## Take It Back: what it takes off a Decay of `amount` (the shield, before Rime Ward).
static func take_back_amount(amount: float) -> float:
	return maxf(amount, 0.0) * Balance.TAKE_IT_BACK_PCT / 100.0

## % of the direct damage of my other books' spells that goes into an open
## Decay with `copies` Runes of Rot equipped (each copy adds as much; never more
## than the rune allows to be equipped).
static func rot_rune_pct(copies: int) -> float:
	return Balance.ROT_RUNE_PCT * clampi(copies, 0, Runes.max_copies(ROT_RUNE))

## How many copies of rune `id` I have equipped and active.
func _rune_count(id: String) -> int:
	var rl := get_node_or_null("RuneListener")
	return int(rl.rune_count(id)) if rl != null and rl.has_method("rune_count") else 0

## Seconds Blight opens Decay for (`quick` = the Rune of the Open Wound).
static func blight_open_time(quick: bool) -> float:
	return Balance.OPEN_WOUND_OPEN_TIME if quick else Balance.DECAY_OPEN_TIME

## Hush: what it adds to an open Decay when it interrupts a cast (`unit` = the
## real damage of a standard spell hit of mine).
static func hush_decay(unit: float) -> float:
	return Balance.HUSH_DECAY * maxf(unit, 0.0)

## A Decay that gets another one's amount and open time (a copy from Spill, or
## what a dead enemy left behind): [amount, time it closes]. The amounts add up,
## and it stays open for as long as either of the two would have.
static func decay_merge(amount: float, open_until: float, add: float, add_open_until: float) -> Array:
	return [maxf(amount, 0.0) + maxf(add, 0.0), maxf(open_until, add_open_until)]

const BREACH_FX = preload("res://scripts/breach_fx.gd")
## Hands that claw up under an enemy when one of these spells of mine hits it:
## [how many, how far up its body they reach (a share of its height)].
const CLAW_HITS := {"blight": [5, 0.6], "erode": [2, 0.4], "gnaw": [4, 0.3], "hush": [1, 0.95]}

## Hands claw up out of the ground at `at` (a point on the ground), `count` of
## them within `radius`, `height` metres tall. Only a picture (breach_fx.gd);
## the party sees it too.
func _claws(at: Vector3, radius: float, count: int, height: float) -> void:
	_net_fx("claws", at, null, {"r": radius, "n": count, "h": height})
	BREACH_FX.burst(get_tree().current_scene, at, radius, count, height)

## ... under `foe`, reaching `share` of its height.
func _claws_at(foe: Variant, count: int, share: float) -> void:
	if foe == null or not is_instance_valid(foe) or not (foe is Node3D):
		return
	var body: Dictionary = BREACH_FX.body_of(foe)
	_claws(BREACH_FX.ground_of(foe), BREACH_FX.hole_radius(float(body["radius"])) * 0.9, count, float(body["height"]) * share)

func _decay_now() -> float:
	return Time.get_ticks_msec() / 1000.0

## Real damage of a standard hit (a 1.0 coefficient) of a Shadow spell of mine.
func _decay_unit() -> float:
	return damage_unit() + Stats.power_bonus(PackedStringArray(SHADOW_TAGS), get_stat)

## Can `foe` carry (and be hit by) my Decay right now?
func _decay_usable(foe: Variant) -> bool:
	if foe == null or not is_instance_valid(foe) or not (foe is Node3D) or not foe.is_alive():
		return false
	return not (foe.has_method("is_evading") and foe.is_evading())

## My Decay on `foe` (0 = none).
func decay_on(foe: Variant) -> float:
	if foe == null or not is_instance_valid(foe):
		return 0.0
	var d: Dictionary = _decay.get((foe as Node).get_instance_id(), {})
	return float(d.get("amount", 0.0))

## Is my Decay on `foe` open (can it grow)?
func decay_open_on(foe: Variant) -> bool:
	if foe == null or not is_instance_valid(foe):
		return false
	var d: Dictionary = _decay.get((foe as Node).get_instance_id(), {})
	return not d.is_empty() and _decay_now() < float(d["open"])

## My Decay on `foe`, made (empty and closed) if there is none yet.
func _decay_entry(foe: Node3D) -> Dictionary:
	var key := foe.get_instance_id()
	if not _decay.has(key):
		_decay[key] = {"target": foe, "amount": 0.0, "open": 0.0,
			"next": _decay_now() + decay_interval(haste_mult(), false, _talent("shadow_wasting")),
			"fast": 0.0, "pos": foe.global_position, "shown": "", "dirty": true, "sync": 0.0}
	return _decay[key]

## Blight landed on `foe`: my Decay there is open for the next `seconds`.
func _open_decay(foe: Node3D, seconds: float) -> void:
	var d := _decay_entry(foe)
	var now := _decay_now()
	d["open"] = maxf(float(d["open"]), now + seconds)
	_decay_show(d, now, true)

## Add `amount` damage to my Decay on `foe`, if it is open. Returns true if it grew.
func _decay_feed(foe: Variant, amount: float) -> bool:
	if amount <= 0.0 or not decay_open_on(foe):
		return false
	var d: Dictionary = _decay[(foe as Node).get_instance_id()]
	d["amount"] = float(d["amount"]) + amount
	d["dirty"] = true
	return true

## Every hit I deal (SignalBus.damage_dealt). Blight opens my Decay on its
## target; a direct hit on a target whose Decay is open adds its share to it.
func _on_damage_dealt_shadow(info: RefCounted) -> void:
	if not is_same(info.source, self) or info.avoided() or int(info.amount) <= 0:
		return
	_pact_acted(info)    # Pact of the Relentless: I hit something
	_dusk_on_hit(info)   # Dusk till Dawn: any Shadow damage of mine starts Dusk
	_hounds_on_hit(info)   # Shadow melee: my Hounds go for the enemy I last struck
	var foe: Variant = info.target
	if not _decay_usable(foe):
		return
	_note_first_hit(foe)   # Inevitable counts from my first damage to it
	var id := str(info.ability_id)
	if id == BLIGHT_ID and not bool(info.is_proc):
		_open_decay(foe, blight_open_time(_has_rune(OPEN_WOUND_RUNE)))
	if CLAW_HITS.has(id) and not bool(info.is_proc) and not bool(info.is_dot):
		_claws_at(foe, int(CLAW_HITS[id][0]), float(CLAW_HITS[id][1]))   # what the spell looks like as it lands
	if _decay.is_empty():
		return
	var pct := decay_feed_pct(id, info.tags, bool(info.is_proc), bool(info.is_dot),
		_talent("shadow_tainted_steel"), rot_rune_pct(_rune_count(ROT_RUNE)))
	if pct <= 0.0:
		pct = seep_feed_pct(id, _talent("shadow_seep"))   # Seep: Wither's ticks add to it too
	if pct > 0.0:
		_decay_feed(foe, float(info.amount) * pct / 100.0)

## Keep the debuff that shows a Decay in step with it: which one it is (open or
## closed), the open time it has left, and its amount (the debuff's stack count,
## sent at most every DECAY_SYNC_EVERY seconds). `fresh` = put the debuff on
## again now (Blight reopened it, or it was given more open time).
func _decay_show(d: Dictionary, now: float, fresh: bool = false) -> void:
	var foe: Variant = d["target"]
	if not _decay_usable(foe):
		return
	var open := now < float(d["open"])
	var want := DECAY_FX if open else DECAY_CLOSED_FX
	var shown := str(d["shown"])
	if shown != want or fresh:
		if shown != "" and shown != want:
			_decay_unshow(foe, shown)
		# (A hit with no damage, so in a party it reaches the host like any other effect.)
		_apply_effect_hit(foe, preload("res://scripts/core/effects.gd").get_effect(want), DECAY_HIT_ID,
			PackedStringArray(DECAY_TAGS), "shadow")
		d["shown"] = want
		if open:
			_decay_effect_time(foe, want, float(d["open"]) - now)
		d["dirty"] = true
		d["sync"] = 0.0
	if bool(d["dirty"]) and now >= float(d["sync"]):
		d["dirty"] = false
		d["sync"] = now + Balance.DECAY_SYNC_EVERY
		_decay_effect_stacks(foe, want, maxi(int(round(float(d["amount"]))), 1))

## Take my debuff `fx_id` off `foe` (the host owns enemy effects in a party).
func _decay_unshow(foe: Variant, fx_id: String) -> void:
	if fx_id == "" or foe == null or not is_instance_valid(foe):
		return
	var net := _net()
	if net:
		net.remove_effect(foe, self, fx_id)
	else:
		var st: Node = (foe as Node).get_node_or_null("Status")
		if st:
			st.remove_from(fx_id, self)

## Make my debuff `fx_id` on `foe` show `seconds` left (the open time).
func _decay_effect_time(foe: Variant, fx_id: String, seconds: float) -> void:
	var net := _net()
	if net:
		net.set_effect_remaining(foe, self, fx_id, seconds)
	else:
		var st: Node = (foe as Node).get_node_or_null("Status")
		if st:
			st.set_remaining_from(fx_id, self, seconds)

## Make my debuff `fx_id` on `foe` show `stacks` (the amount).
func _decay_effect_stacks(foe: Variant, fx_id: String, stacks: int) -> void:
	var net := _net()
	if net:
		net.set_effect_stacks(foe, self, fx_id, stacks)
	else:
		var st: Node = (foe as Node).get_node_or_null("Status")
		if st:
			st.set_stacks_from(fx_id, self, stacks)

## My Decay on the enemy with instance id `key` is over: its debuff goes.
func _end_decay(key: int) -> void:
	if not _decay.has(key):
		return
	var d: Dictionary = _decay[key]
	_decay.erase(key)
	_decay_unshow(d["target"], str(d["shown"]))

## Deal `amount` of my Decay's damage to `foe`: exact (what went into it was
## already worked out hit by hit) and never avoided. A tick (`tick`) is damage
## over time and can crit; what a crit adds comes on top of `amount`. Taken out
## at once (Call Due) it is a direct hit that can't crit.
## `bonuses` = [pct, label] pairs of what my talents add to it (decay_tick_bonuses).
## `crit_bonus` = % crit chance it gets on top (Bite Down; adjust_crit adds it).
## `proc` = a rune caused it (the Rune of the Long Fall): nothing triggers off it.
func _decay_hit(foe: Variant, amount: float, id: String, tick: bool, bonuses: Array = [], crit_bonus: float = 0.0,
		proc: bool = false) -> void:
	if amount <= 0.0 or not _decay_usable(foe):
		return
	var hit := DamageInfo.make(self, foe, 1.0, id)
	hit.is_proc = proc
	if crit_bonus > 0.0:
		hit.set_meta(DECAY_CRIT_META, crit_bonus)
	for b in bonuses:
		hit.add_bonus(float(b[0]), str(b[1]))
	hit.unit = amount
	hit.exact = true
	hit.add_power = false
	hit.can_crit = tick
	hit.can_block = false
	hit.is_dot = tick
	hit.damage_type = "shadow"
	hit.tags = PackedStringArray(DECAY_TAGS if tick else SHADOW_TAGS)
	_combat().deal(hit)

## Every frame: my Decays tick, close, and move on when their enemy dies.
func _tick_decay() -> void:
	if _decay.is_empty() or is_dead():
		return
	var now := _decay_now()
	var haste := haste_mult()
	var endless: bool = status != null and status.has(BOTTOMLESS_FX)   # Bottomless: ticks take nothing out
	var hold := _bottomless_until if endless and _capstone("shadow_no_floor") else 0.0   # No Floor: it can't close either
	var wasting := _talent("shadow_wasting")
	var slow_death := _talent("shadow_slow_death")
	var rot_through := _talent("shadow_rot_through")
	var long_fall := _has_rune(LONG_FALL_RUNE)
	var unit := -1.0
	for key in _decay.keys():
		if not _decay.has(key):
			continue
		var d: Dictionary = _decay[key]
		var foe: Variant = d["target"]
		if foe == null or not is_instance_valid(foe) or not foe.is_alive():
			_decay.erase(key)
			_decay_jump(d)   # what is left moves to the nearest enemy
			continue
		if foe.has_method("is_evading") and foe.is_evading():
			_decay.erase(key)   # it ran home and shook everything off (its debuffs went with it)
			continue
		d["pos"] = (foe as Node3D).global_position
		# Rune of the Long Fall: part of it would be enough to kill the enemy, so
		# all of it is dealt now and it is gone. A real hit like any other: the
		# enemy TAKES the damage (a shield on it, or a heal that reached it first,
		# can still leave it standing); it is never simply killed.
		if long_fall:
			var foe_health: Variant = foe.get("health")
			if foe_health != null and long_fall_applies(float(d["amount"]), float(foe_health)):
				var all := float(d["amount"])
				_end_decay(int(key))
				_ring_effect(1.5, Abilities.color_of(CALL_DUE_ID), (foe as Node3D).global_position)
				_claws_at(foe, 9, 1.3)   # they pull it down
				_decay_hit(foe, all, LONG_FALL_HIT_ID, false, [], 0.0, true)
				continue
		# No Floor: an open Decay stays open until Bottomless is over.
		if decay_held_open(float(d["open"]), now, hold):
			d["open"] = hold
			if str(d["shown"]) == DECAY_FX:
				_decay_effect_time(foe, DECAY_FX, hold - now)
		if now >= float(d["next"]):
			var fast := now < float(d["fast"])   # Gnaw is on it
			d["next"] = now + decay_interval(haste, fast, wasting)
			if unit < 0.0:
				unit = _decay_unit()
			var bite := bite_down_crit(fast, _talent("shadow_bite_down"))   # Bite Down: more crits during Gnaw
			var amount := float(d["amount"])
			if decay_last_drop(amount, now < float(d["open"]), unit):
				_end_decay(int(key))
				# The last drop: all that is left (Bitter End: and more).
				_decay_hit(foe, amount, DECAY_HIT_ID, true,
					decay_tick_bonuses(slow_death, rot_through, _talent("shadow_bitter_end"), true), bite)
				continue
			var tick := decay_tick(amount)
			if not endless:
				d["amount"] = amount - tick
				d["dirty"] = true
			_decay_hit(foe, tick, DECAY_HIT_ID, true, decay_tick_bonuses(slow_death, rot_through, 0.0, false), bite)
		_decay_show(d, now)

## Put `amount` more Decay of mine on `foe`, open until `open_until` (a time):
## a copy from Spill, or what a dead enemy left behind.
func _decay_add(foe: Node3D, amount: float, open_until: float) -> void:
	var d := _decay_entry(foe)
	var merged := decay_merge(float(d["amount"]), float(d["open"]), amount, open_until)
	d["amount"] = float(merged[0])
	d["open"] = float(merged[1])
	_decay_show(d, _decay_now(), true)

## The enemy that carried Decay `d` died: what is left moves to the nearest
## enemy within DECAY_JUMP_RADIUS of where it fell, on top of my Decay there,
## and stays open for as long as it still had.
func _decay_jump(d: Dictionary) -> void:
	var left := float(d["amount"])
	if left <= 0.0:
		return
	var at: Vector3 = d["pos"]
	var kin := _talent("shadow_next_of_kin")   # Next of Kin: more than what was left moves on
	var heirs := 2 if _capstone("shadow_next_of_kin") else 1   # ... and a second enemy gets part of it
	var given := 0
	for e in _enemies_near(at, Balance.DECAY_JUMP_RADIUS):   # (nearest first)
		if not _decay_usable(e):
			continue
		_decay_add(e, kin_amount(left, kin, given > 0), float(d["open"]))
		_ring_effect(0.7, Abilities.color_of(BLIGHT_ID), (e as Node3D).global_position)
		given += 1
		if given >= heirs:
			return

## Dead or downed: my Decays go, and their debuffs with them.
func _clear_decay() -> void:
	for key in _decay.keys():
		_end_decay(int(key))

## Blight with the Rune of the Open Wound: instant, on a cooldown.
## Interest's capstone makes one Blight instant too: that one has no cooldown,
## and ignores the rune's.
func _blight_now() -> void:
	if casting:
		return
	var free := interest_ready()
	if not free and float(cooldowns.get(BLIGHT_ID, 0.0)) > 0.0:
		_error("%s is not ready yet" % Abilities.ability_name(BLIGHT_ID))
		return
	if not _has_valid_target():
		_error("No target")
		return
	if not target_in_range(BLIGHT_ID):
		_error("Target out of range")
		return
	var sight_err := _target_error(target)
	if sight_err != "":
		_error(sight_err)
		return
	if not _pay(BLIGHT_ID):
		return
	if free:
		status.remove(INTEREST_FX)
	else:
		cooldowns[BLIGHT_ID] = Balance.OPEN_WOUND_COOLDOWN
	var dir := target.global_position - global_position
	rotation.y = atan2(-dir.x, -dir.z)
	FROST_BOLT.spawn(get_tree().current_scene, _muzzle(), target, self, false, BLIGHT_ID,
		float(Abilities.get_resource(BLIGHT_ID).damage))
	_bus().cast_finished.emit(BLIGHT_ID)

## Call Due: all of my Decay on the target at once, and a little more. It ends it.
func _call_due() -> void:
	var foe := target
	var amount := decay_on(foe)
	var was_open := decay_open_on(foe)
	# Small Change: part of it stays on the target (open for as long as it still was).
	var left := call_due_left(amount, _talent("shadow_small_change"))
	if left > 0.0 and _decay.has(foe.get_instance_id()):
		var d: Dictionary = _decay[foe.get_instance_id()]
		d["amount"] = left
		d["dirty"] = true
		d["sync"] = 0.0
	else:
		_end_decay(foe.get_instance_id())
	_ring_effect(1.3, Abilities.color_of(CALL_DUE_ID), foe.global_position)
	_claws_at(foe, 8, 1.15)   # every hand at once, over its head
	_decay_hit(foe, call_due_damage(amount, _talent("shadow_interest")), CALL_DUE_ID, false)   # Interest: more on top
	# Interest's capstone: taking out an open Decay makes my next Blight instant.
	if was_open and _capstone("shadow_interest"):
		var fx := StatusContainer.make_buff(INTEREST_FX, "Interest", INTEREST_FX, 0.0, Balance.INTEREST_TIME, 1,
			Abilities.color_of(BLIGHT_ID))
		fx.stat_modifiers = {}
		fx.tags = PackedStringArray(["Shadow"])
		fx.description = "Your next %s is instant." % Abilities.ability_name(BLIGHT_ID)
		status.apply(fx, self)

## Gnaw: a small hit, and my Decay on the target ticks faster for a while.
func _gnaw(res: Resource) -> void:
	var foe := target
	deal_damage(foe, float(res.damage), GNAW_ID)   # (the hands at its feet: CLAW_HITS)
	if not is_instance_valid(foe) or not _decay.has(foe.get_instance_id()):
		return
	var d: Dictionary = _decay[foe.get_instance_id()]
	var now := _decay_now()
	d["fast"] = now + Balance.GNAW_TIME
	d["next"] = minf(float(d["next"]), now + decay_interval(haste_mult(), true, _talent("shadow_wasting")))   # the faster ticks start now

## Spill: the enemies around `foe` a copy of its Decay goes to.
func _spill_targets(foe: Node3D) -> Array:
	var out: Array = []
	for e in _enemies_near(foe.global_position, Balance.SPILL_RADIUS, foe):
		if out.size() >= Balance.SPILL_TARGETS:
			break
		if _decay_usable(e):
			out.append(e)
	return out

## Spill: part of my Decay on the target is copied onto the enemies around it.
func _spill() -> void:
	var foe := target
	var d: Dictionary = _decay.get(foe.get_instance_id(), {})
	if d.is_empty():
		return
	var share := spill_amount(float(d["amount"]), _talent("shadow_running_over"))   # Running Over: bigger copies
	var open_until := spill_open_until(float(d["open"]), _decay_now(), _capstone("shadow_running_over"))
	var col := Abilities.color_of(SPILL_ID)
	_ring_effect(1.2, col, foe.global_position)
	_claws_at(foe, 4, 0.5)
	for e in _spill_targets(foe):
		_decay_add(e, share, open_until)
		_claws_at(e, 3, 0.4)   # the ground gives way under each of them

## Take It Back: part of my Decay on the target comes off it and shields me.
func _take_it_back() -> void:
	var foe := target
	var d: Dictionary = _decay.get(foe.get_instance_id(), {})
	if d.is_empty():
		return
	var taken := take_back_amount(float(d["amount"]))
	d["amount"] = float(d["amount"]) - taken
	d["dirty"] = true
	var col := Abilities.color_of(TAKE_IT_BACK_ID)
	_claws_at(foe, 3, 0.5)
	_ring_effect(1.3, col)
	var amount := int(round(taken * absorb_mult()))   # (Rime Ward: like every shield I put up)
	if amount <= 0:
		return
	var fx := StatusContainer.make_buff(TAKE_IT_BACK_FX, Abilities.ability_name(TAKE_IT_BACK_ID), TAKE_IT_BACK_FX, 0.0,
		Balance.TAKE_IT_BACK_TIME, 1, col)
	var armor := _talent("frost_shield_armor")   # Hardened Frost: my shields add armor
	fx.stat_modifiers = {"armor%": armor} if armor > 0.0 else {}
	fx.tags = PackedStringArray(["Shadow"])
	fx.description = "A shield absorbs damage."
	if status.apply(fx, self):
		status.set_absorb(TAKE_IT_BACK_FX, amount)

## Bottomless: for a while my Decay does not shrink when it ticks (see _tick_decay).
## No Floor makes it last longer, and (its capstone) keeps my open Decays open.
func _start_bottomless() -> void:
	var col := Abilities.color_of(BOTTOMLESS_ID)
	var seconds := bottomless_time(_talent("shadow_no_floor"))
	var fx := StatusContainer.make_buff(BOTTOMLESS_FX, Abilities.ability_name(BOTTOMLESS_ID), BOTTOMLESS_FX, 0.0,
		seconds, 1, col)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Shadow"])
	fx.description = "Your Breach does not shrink when it deals its damage."
	if _capstone("shadow_no_floor"):
		fx.description += " It cannot close."
	status.apply(fx, self)
	_bottomless_until = _decay_now() + seconds
	_ring_effect(1.4, col)
	_ring_effect(0.7, Color(0.1, 0.04, 0.15))

## Hush's own hit, and what it adds to an open Decay when there was a cast to stop.
func _hush(foe: Node3D, coef: float, stopped: bool) -> void:
	# Cut Short: stopping a cast takes time off its cooldown (which was just set).
	if stopped and cooldowns.has(HUSH_ID):
		cooldowns[HUSH_ID] = cut_short_cooldown(float(cooldowns[HUSH_ID]), _talent("shadow_cut_short"))
	if not is_instance_valid(foe) or not foe.is_alive():
		return
	deal_damage(foe, coef, HUSH_ID)
	if stopped and is_instance_valid(foe) and foe.is_alive():
		_decay_feed(foe, hush_decay(_decay_unit()))

# Smother (ability id "pall": the name it was first given): ground-targeted,
# like Collapse. When the cast finishes, every enemy in
# the circle is hit (and each one's open Decay gets its share of that hit).

func _start_pall(point: Vector3) -> void:
	if casting or not is_on_floor():
		return
	cast_point = point
	if not can_afford(PALL_ID, true):
		return
	var res := Abilities.get_resource(PALL_ID)
	_begin_spell(PALL_ID, str(res.display_name), float(res.cast_time))

func _cast_pall() -> void:
	var res := Abilities.get_resource(PALL_ID)
	cooldowns[PALL_ID] = Abilities.cooldown_of(res)
	var at := cast_point
	var r := float(res.radius)
	var col := Abilities.color_of(PALL_ID)
	_ring_effect(r, col, at + Vector3(0, 0.9, 0))
	_claws(at, r, 18, 1.3)   # a field of hands
	var hit := _enemies_near(at, r)
	var share := float(res.damage) * Balance.aoe_share(hit.size())
	for e in hit:
		if is_instance_valid(e) and e.is_alive():
			deal_damage(e, share, PALL_ID)

# --- Shadow: the open talents ---------------------------------------------------------------
# Talents of the Shadow book that work with every book's spells and abilities:
# Slow Death (my damage over time hits harder), Wasting (it ticks more often:
# the StatusContainer asks dot_speed_mult, Decay asks decay_interval), Finish It
# (more damage to enemies low on health), Spite (taking damage boosts my next
# spell or ability), Carrion (an enemy dying with my damage over time on it
# gives mana back) and Inevitable (more damage to enemies I have been on for a
# while). Finish It, Spite and Inevitable are % modifiers, so they never touch
# Decay's own damage (that is exact); Slow Death and Wasting do count for it.
# Numbers: balance.gd and talents.gd.

const SPITE_FX := "spite"
var _spite_id := ""            # the spell / ability that is using Spite's boost up
var _spite_until := 0.0        # ... and until when its hits still get it
var _first_hit := {}           # enemy instance id -> time of my first damage to it (Inevitable)

## How many times as often my damage over time ticks with `wasting_pct` % from
## Wasting on top of `base` (what something else already does for it).
static func dot_speed_with(base: float, wasting_pct: float) -> float:
	return base * (1.0 + maxf(wasting_pct, 0.0) / 100.0)

## Finish It: is an enemy with this health low enough?
static func finish_it_applies(health: float, max_health: float) -> bool:
	return max_health > 0.0 and health / max_health * 100.0 < Balance.FINISH_IT_HEALTH_PCT

## Inevitable: have I been on an enemy I first damaged at `first_hit` (a time; 0 =
## never) for long enough at `now`?
static func inevitable_applies(first_hit: float, now: float) -> bool:
	return first_hit > 0.0 and now - first_hit > Balance.INEVITABLE_TIME

## Carrion: the mana `pct` % of a mana pool of `max_mana` is.
static func carrion_mana(max_mana: float, pct: float) -> float:
	return maxf(max_mana, 0.0) * maxf(pct, 0.0) / 100.0

const ILL_WILL_LABEL := "Ill Will"

## A hit of mine that just rolled a critical strike (CombatSystem.deal asks,
## for every hit, exact ones like my Breach's ticks too): [percent, label] it
## gets on top, or [] for none. Ill Will: crits of my damage over time.
func crit_hit_bonus(info: RefCounted) -> Array:
	return ill_will_bonus(bool(info.is_dot), _talent("shadow_ill_will"))

static func ill_will_bonus(is_dot: bool, pct: float) -> Array:
	return [pct, ILL_WILL_LABEL] if is_dot and pct > 0.0 else []

## A hit of mine, before its damage is worked out (_on_damage_modify): Slow
## Death, Finish It, Inevitable, Spite.
func _shadow_talents_modify(info: RefCounted, id: String) -> void:
	# Slow Death: my damage over time hits harder.
	if bool(info.is_dot):
		var slow := _talent("shadow_slow_death")
		if slow > 0.0:
			info.add_bonus(slow, "Slow Death")
	var foe: Variant = info.target
	if foe != null and is_instance_valid(foe) and foe is Node:
		var hp: Variant = foe.get("health")
		var max_hp: Variant = foe.get("max_health")
		if hp != null and max_hp != null:
			# Finish It: enemies low on health.
			var finish := _talent("shadow_finish_it")
			if finish > 0.0 and finish_it_applies(float(hp), float(max_hp)):
				info.add_bonus(finish, "Finish It")
			# (An enemy back at full health starts over for Inevitable: it ran home and healed.)
			if float(hp) >= float(max_hp):
				_first_hit.erase((foe as Node).get_instance_id())
		# Inevitable: enemies I have been on for a while.
		var inevitable := _talent("shadow_inevitable")
		if inevitable > 0.0 and inevitable_applies(float(_first_hit.get((foe as Node).get_instance_id(), 0.0)), _decay_now()):
			info.add_bonus(inevitable, "Inevitable")
		# Still Wet's capstone: my own direct hits also hit an enemy I Laid Open
		# harder (the Hounds' bites have Open Up's own bonus).
		if not bool(info.is_proc) and not bool(info.is_dot) and _capstone("shadow_still_wet"):
			var wet: Node = (foe as Node).get_node_or_null("Status")
			if still_wet_applies(true, wet != null and wet.has_from(LAID_OPEN_FX, self), false, false):
				info.add_bonus(Balance.STILL_WET_PCT, STILL_WET_LABEL)
	_spite_hit(info, id)

## Remember when I first damaged `foe` (Inevitable counts from then).
func _note_first_hit(foe: Node) -> void:
	var key := foe.get_instance_id()
	if _first_hit.has(key):
		return
	if _first_hit.size() >= 64:
		_first_hit.clear()   # (a long run: forget the old ones rather than keep every enemy ever hit)
	_first_hit[key] = _decay_now()

## Something damaged me (_on_hit_taken). Spite: my next spell or ability hits harder.
func _spite_on_hit_taken(info: RefCounted) -> void:
	if int(info.amount) <= 0 or info.avoided() or _talent("shadow_spite") <= 0.0:
		return
	if status.has(SPITE_FX) and status.remaining_of(SPITE_FX) > Balance.SPITE_TIME - 0.5:
		return   # (it was just renewed: a pack hitting me doesn't rebuild it on every blow)
	var fx := StatusContainer.make_buff(SPITE_FX, "Spite", SPITE_FX, 0.0, Balance.SPITE_TIME, 1, Abilities.color_of(BLIGHT_ID))
	fx.stat_modifiers = {}
	fx.description = "Your next spell or ability deals more damage."
	status.apply(fx, self)

## A hit of mine, before its damage is worked out. Spite: the first spell or
## ability I hit with uses the boost, and every hit of that one use gets it
## (SPITE_HITS seconds: it may hit several enemies). Never an auto-attack, a
## proc or damage over time.
func _spite_hit(info: RefCounted, id: String) -> void:
	if not echoes(info.tags, bool(info.is_proc), bool(info.is_dot), Abilities.PATHS.has(id)):
		return
	var now := _decay_now()
	if status != null and status.has(SPITE_FX):
		status.remove(SPITE_FX)
		_spite_id = id
		_spite_until = now + Balance.SPITE_HITS
	elif id != _spite_id or now > _spite_until:
		return
	var pct := _talent("shadow_spite")
	if pct > 0.0:
		info.add_bonus(pct, "Spite")

## An enemy died (SignalBus.enemy_died). Carrion: if it carried one of my damage
## over time effects (it noted who had one as it died), I get some mana back.
func _on_enemy_died_shadow(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var key := enemy.get_instance_id()
	var by_me: bool = enemy.has_method("killed_by_me") and bool(enemy.killed_by_me())
	var damaged := _first_hit.has(key) or by_me
	var dragged := float(_drag_watch.get(key, 0.0))
	_first_hit.erase(key)
	_drag_watch.erase(key)
	if is_dead():
		return
	# Take It With You's capstone: Drag Down killed it, so my next pair arrives Roused.
	if drag_kill_counts(_hound_now(), dragged, by_me) and _capstone("shadow_take_it_with_you"):
		_hounds_roused_next = true
	# Feeding Frenzy: an enemy I damaged died.
	var frenzy := _talent("shadow_feeding_frenzy")
	if frenzy > 0.0 and damaged:
		add_buff(FEEDING_FRENZY_FX, Stats.HASTE, frenzy, Balance.FEEDING_FRENZY_TIME, 1, "Feeding Frenzy")
	var pct := _talent("shadow_carrion")
	if pct <= 0.0:
		return
	var owners: Variant = enemy.get("dot_owners_at_death")
	if owners is Dictionary and (owners as Dictionary).has(get_instance_id()):
		_gain("mana", carrion_mana(resource_max("mana"), pct))

# --- Arcane tank (a dodge tank with a melee weapon in each hand) --------------------------
# No resource: cooldowns alone. It lives on Reflections, images of me that stand
# around me (a stacking buff; the picture is scripts/reflections.gd). Each one
# adds Dodge and raises my Dodge cap. An attack I dodge uses one up, and that
# Reflection shatters: damage around me, time off the cooldown of everything in
# the Arcane book, and a window for Missed Beat. Double Up, Ripple and Full Set
# make Reflections. Stand-In lets them take the attacks that get through, Trade
# Places turns them into health, Crowd of One stops dodges using them up, and
# Decoy sends one off for the enemies to attack. Numbers are in balance.gd.

const REFLECTIONS = preload("res://scripts/reflections.gd")
const DECOY = preload("res://scripts/decoy.gd")
const TRACE_GHOST = preload("res://scripts/trace_ghost.gd")
const REFLECTION_FX := "reflection"
## Meter / log id of a Reflection shattering (its own line: Details.HIT_NAMES).
const REFLECTION_SHATTER_ID := "reflection_shatter"
const REFLECTION_TAGS := ["Arcane", "Ability", "AoE"]
const DOUBLE_UP_ID := "doubleup"
const RIPPLE_ID := "ripple"
const FULL_SET_ID := "fullset"
const MISSED_BEAT_ID := "missedbeat"
const MISSED_BEAT_FX := "missed_beat"
const STAND_IN_ID := "standin"
const STAND_IN_FX := "stand_in"
const TRADE_PLACES_ID := "tradeplaces"
const CROWD_ID := "crowdofone"
const CROWD_FX := "crowd_of_one"
const DECOY_ID := "decoy"
const DUAL_WIELD_ERROR := "Requires a melee weapon in each hand"
## Seconds between telling the party again how many Reflections I have (someone
## who joined or reloaded since then sees them too).
const REFLECTION_RETELL := 3.0

var _reflection_fx: Resource
var _reflections_shown := 0      # how many the picture around me shows (and the party was told)
var _reflections_told := 0.0     # when the party was last told
var _hits_taken: Array = []      # [time, damage] of what I took lately (Trade Places)

## Dual wield: is a one-handed melee weapon in my Main Hand and another in my Off Hand?
func has_dual_wield() -> bool:
	var pd := get_node_or_null("/root/PlayerData")
	return pd != null and bool(pd.has_dual_wield())

## Damage coefficient of a strike with both weapons (Double Up, Missed Beat): the
## two weapons' damage together x the ability's multiplier + the ability's own.
## One hit, so what triggers on a hit triggers once.
static func dual_hit(main: float, off: float, mult: float, flat: float) -> float:
	return (maxf(main, 0.0) + maxf(off, 0.0)) * mult + flat

func _dual_weapon_hit(w: Dictionary, res: Resource) -> float:
	return dual_hit(float(w.get("damage", 0.0)), float(Abilities.offhand_weapon().get("damage", 0.0)),
		float(res.weapon_damage_multiplier), float(res.damage))

## How many Reflections I have.
func reflections() -> int:
	return status.stacks_of(REFLECTION_FX) if status != null else 0

## Reflections after gaining `more` on top of `have` (never more than REFLECTION_MAX).
static func reflections_after(have: int, more: int) -> int:
	return clampi(have + maxi(more, 0), 0, Balance.REFLECTION_MAX)

## The most Dodge chance (%) that counts with `stacks` Reflections.
static func dodge_cap_for(stacks: int) -> float:
	return Stats.MAX_DODGE + Balance.REFLECTION_DODGE_CAP * clampi(stacks, 0, Balance.REFLECTION_MAX)

## My Dodge cap right now (CombatSystem and the stat panel ask).
func dodge_cap() -> float:
	return dodge_cap_for(reflections())

## Does a Reflection shattering take time off the cooldown of an ability in the
## book `category`? Everything in the Arcane book, spells and abilities alike;
## never an interrupt (they share a cooldown of their own).
static func shatter_cuts(category: String, is_interrupt: bool) -> bool:
	return category == "arcane" and not is_interrupt

## Does a Ripple that hit `enemies` enemies make a Reflection? (`wide` = Wide
## Rings' capstone: fewer enemies are enough.)
static func ripple_makes_reflection(enemies: int, wide: bool = false) -> bool:
	return enemies >= (Balance.WIDE_RINGS_ENEMIES if wide else Balance.RIPPLE_REFLECTION_ENEMIES)

# The Arcane tank's talents. Down the left edge of the book, what makes and
# shatters Reflections: Sharp Edges (shatters hit harder; capstone: further),
# Clockwork (a shatter takes more off cooldowns), Spare Copy (a dodge may not
# use the Reflection up), Second Self (Double Up may make two), Wide Rings
# (Ripple reaches further; capstone: fewer enemies make a Reflection), On the
# Beat (Missed Beat hits harder; capstone: it makes a Reflection when I have
# none), Head Count (Full Set heals for each Reflection it makes). Down the right
# edge, staying alive: Light Feet (Dodge with two weapons: PlayerData), Empty
# Room (less damage taken with no Reflections), Bent Light (less non-Physical
# damage for each Reflection), Understudy (Stand-In comes back sooner), Loud Exit
# (Trade Places shatters what it gives up), Good Likeness (Decoy holds longer;
# capstone: it needs no Reflection).

const SHARP_EDGES_LABEL := "Sharp Edges"
const ON_THE_BEAT_LABEL := "On the Beat"
## Meter / log id of Head Count's healing (its own line: Details.HIT_NAMES).
const HEAD_COUNT_ID := "head_count"
## ... and of Silvered's.
const SILVERED_ID := "silvered"

## Health Silvered restores when a Reflection shatters (`pct` % of maximum health).
static func silvered_heal(max_hp: int, pct: float) -> int:
	return int(round(maxf(float(max_hp), 0.0) * maxf(pct, 0.0) / 100.0))

## Metres a shatter reaches (Sharp Edges' capstone: further).
static func shatter_radius_for(sharp_capstone: bool) -> float:
	return Balance.SHARP_EDGES_RADIUS if sharp_capstone else Balance.REFLECTION_SHATTER_RADIUS

## Seconds one shatter takes off each Arcane cooldown (`clockwork` = that talent's seconds).
static func shatter_cut(clockwork: float) -> float:
	return Balance.REFLECTION_SHATTER_COOLDOWN + maxf(clockwork, 0.0)

## Is the Reflection that took a dodged attack used up? Not during Crowd of One,
## and not when Spare Copy's chance comes up (`spare_pct` %, `roll` 0-100).
static func dodge_uses_reflection(crowd: bool, spare_pct: float, roll: float) -> bool:
	return not crowd and not (spare_pct > 0.0 and roll < spare_pct)

## Reflections one Double Up makes (Second Self: a `pct` % chance of more; `roll` 0-100).
static func double_up_reflections(pct: float, roll: float) -> int:
	return Balance.SECOND_SELF_REFLECTIONS if pct > 0.0 and roll < pct else 1

## Health Head Count restores when Full Set makes `made` Reflections (`pct` % of
## maximum health for each).
static func head_count_heal(max_hp: int, pct: float, made: int) -> int:
	return int(round(maxf(float(max_hp), 0.0) * maxf(pct, 0.0) / 100.0 * maxi(made, 0)))

## % less damage Empty Room spares me (`pct` = the talent): only with a weapon in
## each hand and no Reflections left.
static func empty_room_pct(pct: float, stacks: int, dual: bool) -> float:
	return pct if pct > 0.0 and stacks <= 0 and dual else 0.0

## % less damage Bent Light spares me from a hit of `damage_type`: `per` % for
## each Reflection, never from Physical damage.
static func bent_light_pct(per: float, stacks: int, damage_type: String) -> float:
	if per <= 0.0 or damage_type == "physical":
		return 0.0
	return per * clampi(stacks, 0, Balance.REFLECTION_MAX)

## Seconds a Decoy holds the enemies around it (`longer` = Good Likeness).
static func decoy_time(longer: float) -> float:
	return Balance.DECOY_TIME + maxf(longer, 0.0)

func shatter_radius() -> float:
	return shatter_radius_for(_capstone("arcane_sharp_edges"))

## Does Decoy need (and use up) one of my Reflections? Not with Good Likeness' capstone.
func decoy_needs_reflection() -> bool:
	return not _capstone("arcane_good_likeness")

## What I take (_on_damage_modify): Empty Room and Bent Light.
func _reflection_talents_incoming(info: RefCounted) -> void:
	var empty := _talent("arcane_empty_room")
	if empty > 0.0:
		var spared := empty_room_pct(empty, reflections(), has_dual_wield())
		if spared > 0.0:
			info.add_bonus(-spared, "Empty Room")
	var bent := bent_light_pct(_talent("arcane_bent_light"), reflections(), str(info.damage_type))
	if bent > 0.0:
		info.add_bonus(-bent, "Bent Light")

## Damage taken in the `window` seconds before `now`, from rows of [time, damage].
static func damage_in_window(rows: Array, now: float, window: float) -> int:
	var total := 0
	for r in rows:
		if r is Array and r.size() >= 2 and now - float(r[0]) <= window:
			total += int(r[1])
	return total

## Health Trade Places restores for `taken` damage with `stacks` Reflections given up.
static func trade_places_heal(taken: int, stacks: int) -> int:
	return int(round(maxf(float(taken), 0.0) * Balance.TRADE_PLACES_PCT / 100.0 * maxi(stacks, 0)))

## Why Trade Places can't be used ("" = it can).
static func trade_places_error(stacks: int, taken: int, full_health: bool) -> String:
	if stacks <= 0:
		return "You have no Reflections"
	if full_health:
		return "Already at full health"
	if taken <= 0:
		return "You have taken no damage to trade"
	return ""

func _reflection_buff() -> Resource:
	if _reflection_fx == null:
		_reflection_fx = StatusContainer.make_buff(REFLECTION_FX, "Reflection", Stats.DODGE, Balance.REFLECTION_DODGE,
			Balance.REFLECTION_TIME, Balance.REFLECTION_MAX, Abilities.color_of(DOUBLE_UP_ID))
		_reflection_fx.tags = PackedStringArray(["Arcane"])
		_reflection_fx.description = "An image of you. Each one adds {b:REFLECTION_DODGE}% Dodge and raises your Dodge cap by {b:REFLECTION_DODGE_CAP}%. An attack you dodge shatters one."
	return _reflection_fx

## Gain `more` Reflections (never more than REFLECTION_MAX). All of them last
## their full time again.
func _gain_reflections(more: int = 1) -> void:
	if status == null or more <= 0 or is_dead():
		return
	var want := reflections_after(reflections(), more)
	if not status.apply(_reflection_buff(), self):
		return
	if status.stacks_of(REFLECTION_FX) != want:
		status.set_stacks(REFLECTION_FX, want)

## Remember what I just took (Trade Places looks back TRADE_PLACES_WINDOW seconds).
func _note_damage_taken(amount: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_hits_taken.append([now, amount])
	while not _hits_taken.is_empty() and now - float(_hits_taken[0][0]) > Balance.TRADE_PLACES_WINDOW:
		_hits_taken.pop_front()

## Damage I took in the last `window` seconds.
func damage_taken_recently(window: float) -> int:
	return damage_in_window(_hits_taken, Time.get_ticks_msec() / 1000.0, window)

## One of my Reflections shatters: damage around me (a proc with its own line on
## the meter; it feeds nothing), time off my Arcane cooldowns, and Missed Beat
## may answer. `used_up` = false during Crowd of One: the Reflection stays.
func _shatter_reflection(used_up: bool = true) -> void:
	if reflections() <= 0:
		return
	if used_up:
		status.spend_stacks(REFLECTION_FX, 1)
	_shatter_burst()

## What a shattering Reflection does (also each one Trade Places gives up with
## Loud Exit): the damage around me, the time off my cooldowns, Missed Beat's window.
func _shatter_burst() -> void:
	var reach := shatter_radius()   # Sharp Edges' capstone: further
	var hit := _enemies_within(reach)
	var coef := Balance.REFLECTION_SHATTER * Balance.aoe_share(hit.size())
	for e in hit:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var burst := DamageInfo.make(self, e, coef, REFLECTION_SHATTER_ID)
		burst.tags = PackedStringArray(REFLECTION_TAGS)
		burst.damage_type = "arcane"
		burst.threat_multiplier = Balance.REFLECTION_SHATTER_THREAT
		burst.is_proc = true
		burst.no_empower = true
		_combat().deal(burst)
	_ring_effect(reach, Abilities.color_of(DOUBLE_UP_ID))
	_ring_effect(reach * 0.5, Color(0.95, 0.9, 1.0))
	_shatter_cooldowns()
	# Silvered: every shatter heals me a little.
	var silver := silvered_heal(max_health, _talent("arcane_silvered"))
	if silver > 0 and health < max_health:
		_combat().heal(self, self, float(silver), SILVERED_ID, true)
	var pd := get_node_or_null("/root/PlayerData")
	if pd and pd.has_ability(MISSED_BEAT_ID):
		_arcane_buff(MISSED_BEAT_FX, MISSED_BEAT_ID, Balance.MISSED_BEAT_WINDOW,
			"One of your Reflections shattered: %s can be used." % Abilities.ability_name(MISSED_BEAT_ID))

## A Reflection shattered: everything in the Arcane book that is on cooldown
## comes back a little sooner (spells and abilities alike; never an interrupt).
func _shatter_cooldowns() -> void:
	var cut := shatter_cut(_talent("arcane_clockwork"))   # + Clockwork
	for id in cooldowns.keys():
		if shatter_cuts(Abilities.category_of(str(id)), INTERRUPT_LOCKOUT.has(str(id))):
			_cut_cooldown(str(id), cut)

## Something hit me (_on_hit_taken): an attack I dodged shatters a Reflection,
## and so does one a Reflection stood in for (Stand-In).
func _reflection_kit_hit_taken(info: RefCounted) -> void:
	if reflections() <= 0:
		return
	if bool(info.stood_in):
		_shatter_reflection(true)
		var understudy := _talent("arcane_understudy")   # Understudy: Stand-In comes back sooner
		if understudy > 0.0:
			_cut_cooldown(STAND_IN_ID, understudy)
	elif bool(info.dodged):
		# Crowd of One: it is not used up. Spare Copy: it may not be.
		_shatter_reflection(dodge_uses_reflection(status.has(CROWD_FX), _talent("arcane_spare_copy"), randf() * 100.0))

## CombatSystem asks, for a direct hit that got through to me: does something
## else take it? During Stand-In a Reflection does (and shatters: see above).
func stand_in_for(_info: RefCounted) -> bool:
	return status != null and status.has(STAND_IN_FX) and reflections() > 0

## Ripple: everything around me is hit; more than AOE_TARGET_CAP enemies share
## that many hits' damage. Hitting enough of them makes a Reflection.
func _ripple(res: Resource) -> void:
	var col := Abilities.color_of(RIPPLE_ID)
	var reach := float(res.radius) + Abilities.radius_bonus(RIPPLE_ID)   # + Wide Rings
	var hit := _enemies_within(reach)
	var coef := float(res.damage) * Balance.aoe_share(hit.size())
	for e in hit:
		if is_instance_valid(e) and e.is_alive():
			deal_damage(e, coef, RIPPLE_ID)
	if ripple_makes_reflection(hit.size(), _capstone("arcane_wide_rings")):
		_gain_reflections(1)
	_ring_effect(reach, col)
	_ring_effect(reach * 0.7, Color(0.95, 0.9, 1.0))
	_ring_effect(reach * 0.4, col)

## Full Set: Reflections until I have them all. Head Count heals me for each one
## it makes.
func _full_set() -> void:
	var made := Balance.REFLECTION_MAX - reflections()
	_gain_reflections(Balance.REFLECTION_MAX)
	var mend := head_count_heal(max_health, _talent("arcane_head_count"), made)
	if mend > 0 and health < max_health:
		_combat().heal(self, self, float(mend), HEAD_COUNT_ID, true)
	_ring_effect(1.4, Abilities.color_of(FULL_SET_ID))
	_ring_effect(0.9, Color(0.95, 0.9, 1.0))

func _start_stand_in() -> void:
	_arcane_buff(STAND_IN_FX, STAND_IN_ID, Balance.STAND_IN_TIME,
		"Each attack that gets through to you destroys one of your Reflections instead of hitting you.")
	_ring_effect(1.2, Abilities.color_of(STAND_IN_ID))
	_ring_effect(0.8, Color(0.95, 0.9, 1.0))

func _start_crowd_of_one() -> void:
	_arcane_buff(CROWD_FX, CROWD_ID, Balance.CROWD_OF_ONE_TIME,
		"A Reflection that takes an attack you dodge shatters, but is not used up.")
	var crowd := int(round(_talent("arcane_full_crowd")))   # Full Crowd: it brings some with it
	if crowd > 0:
		_gain_reflections(crowd)
	_ring_effect(1.6, Abilities.color_of(CROWD_ID))
	_ring_effect(1.0, Color(0.95, 0.9, 1.0))

## Trade Places: every Reflection I have is given up (they do not shatter,
## unless I have Loud Exit), and each one heals me for a share of what I took in
## the last moments.
func _trade_places() -> void:
	var stacks := reflections()
	var amount := trade_places_heal(damage_taken_recently(Balance.TRADE_PLACES_WINDOW), stacks)
	# Loud Exit: each one I give up shatters on its way out.
	if _talent("arcane_loud_exit") > 0.0:
		for i in stacks:
			_shatter_burst()
	status.remove(REFLECTION_FX)
	if amount > 0:
		_combat().heal(self, self, float(amount), TRADE_PLACES_ID, true)
	_ring_effect(1.2, Color(0.45, 1.0, 0.5))
	_ring_effect(0.8, Abilities.color_of(TRADE_PLACES_ID))

## My buffs changed: the picture around me shows as many Reflections as I have,
## and the party is told when that number changes.
func _sync_reflections() -> void:
	var n := reflections()
	if n == _reflections_shown:
		return
	_reflections_shown = n
	REFLECTIONS.show_on(self, n)
	_tell_reflections()

func _tell_reflections() -> void:
	_reflections_told = Time.get_ticks_msec() / 1000.0
	_net_fx("reflections", global_position, null, {"n": _reflections_shown})

func _tick_reflections() -> void:
	if _reflections_shown > 0 and Time.get_ticks_msec() / 1000.0 - _reflections_told >= REFLECTION_RETELL:
		_tell_reflections()

# Decoy: ground-targeted and instant. One of my Reflections goes to stand at the
# spot (scripts/decoy.gd): for DECOY_TIME seconds the enemies around it attack
# it. Enemies live on the host, so in a party the host makes the real one
# (Net.decoy). When its time is up it bursts: that damage is mine, dealt here.

## Why Decoy can't be used right now ("" = it can). `point` = where it would stand.
func _decoy_error(point: Variant = null) -> String:
	if cooldown_left(DECOY_ID) > 0.0:
		return "%s is not ready yet" % Abilities.ability_name(DECOY_ID)
	if not has_dual_wield():
		return DUAL_WIELD_ERROR
	if decoy_needs_reflection() and reflections() <= 0:
		return "You have no Reflections"
	if point is Vector3:
		var reach := float(Abilities.get_resource(DECOY_ID).cast_range)
		if reach > 0.0 and Vector2(point.x - global_position.x, point.z - global_position.z).length() > reach:
			return "Out of range"
	return ""

func _start_decoy(point: Vector3) -> void:
	if casting or not is_on_floor():
		return
	var err := _decoy_error(point)
	if err != "":
		_error(err)
		return
	if not _pay(DECOY_ID):
		return
	var res := Abilities.get_resource(DECOY_ID)
	cooldowns[DECOY_ID] = Abilities.cooldown_of(res)
	if decoy_needs_reflection():
		status.spend_stacks(REFLECTION_FX, 1)   # the Reflection that goes (Good Likeness' capstone: none does)
	var dir := point - global_position
	if Vector2(dir.x, dir.z).length() > 0.3:
		rotation.y = atan2(-dir.x, -dir.z)
	# It stands on the ground there, its centre as high over it as mine is.
	var at := Vector3(point.x, point.y + (global_position.y - Combat.feet_y(self)), point.z)
	var time := decoy_time(_talent("arcane_good_likeness"))   # + Good Likeness
	var net := _net()
	if net:
		net.decoy(self, at, rotation.y, float(res.radius), time)
	else:
		DECOY.spawn(get_tree().current_scene, self, at, rotation.y, time, float(res.radius))
	_ring_effect(float(res.radius), Abilities.color_of(DECOY_ID), at)
	get_tree().create_timer(time).timeout.connect(func(): _decoy_burst(at))
	if on_gcd(DECOY_ID):
		_start_gcd()
	_bus().cast_finished.emit(DECOY_ID)

## My Decoy's time is up: it bursts where it stood (a proc; more than
## AOE_TARGET_CAP enemies share that many hits' damage).
func _decoy_burst(at: Vector3) -> void:
	if is_dead():
		return
	var res := Abilities.get_resource(DECOY_ID)
	var hit := _enemies_near(at, Balance.DECOY_BURST_RADIUS)
	var coef := float(res.damage) * Balance.aoe_share(hit.size())
	for e in hit:
		if is_instance_valid(e) and e.is_alive():
			deal_damage(e, coef, DECOY_ID, true)
	_ring_effect(Balance.DECOY_BURST_RADIUS, Abilities.color_of(DECOY_ID), at)
	_ring_effect(Balance.DECOY_BURST_RADIUS * 0.5, Color(0.95, 0.9, 1.0), at)

# --- Arcane: the open talents -------------------------------------------------------------
# Talents of the Arcane book that work with every book's spells and abilities:
# Echo (a hit may be repeated), Borrowed Time (a long cooldown coming back
# boosts my next spell or ability), Mirror Finish (an attack I dodge, parry or
# block hurts the attacker), Overtime (buffs I put on myself last longer),
# Slipstream (faster after a blink or dash), Light Touch (less threat from
# Arcane). Quick Study and Two Minds are in PlayerData. Numbers: balance.gd and
# talents.gd.

const ECHO_ID := "echo"
const MIRROR_FINISH_ID := "mirror_finish"
const MIRROR_FINISH_TAGS := ["Arcane", "Ability"]
const BORROWED_FX := "borrowed_time"
const SLIPSTREAM_FX := "slipstream"
## The blinks and dashes Slipstream follows.
const SLIPSTREAM_MOVES := ["blink", "flicker", "staticstep", "cinderstep", "icyretreat"]

var _borrowed_watch := {}      # ability id -> true: the long cooldowns that are running
var _long_cooldowns := {}      # ability id -> does its cooldown count for Borrowed Time (looked up once)
var _borrowed_id := ""         # the spell / ability that is using the boost up
var _borrowed_until := 0.0     # ... and until when its hits still get it

## Can Echo repeat this hit? A hit of a spell or ability I know by name: never a
## proc (another echo, a replay), damage over time or an auto-attack.
static func echoes(tags: PackedStringArray, is_proc: bool, is_dot: bool, known: bool) -> bool:
	return known and not is_proc and not is_dot and (tags.has("Spell") or tags.has("Ability"))

## % chance Echo repeats a hit (`pct` = the talent; Arcane hits: more often).
static func echo_chance(pct: float, arcane: bool) -> float:
	return maxf(pct, 0.0) * (Balance.ECHO_ARCANE_CHANCE_MULT if arcane else 1)

## % of a hit's damage Echo's repeat deals (Arcane hits: less of it).
static func echo_share(arcane: bool) -> float:
	return Balance.ECHO_ARCANE_PCT if arcane else Balance.ECHO_PCT

## Does a cooldown of `seconds` coming back count for Borrowed Time?
static func borrowed_time_counts(seconds: float) -> bool:
	return seconds >= Balance.BORROWED_TIME_COOLDOWN

## How many times as long the buffs I put on myself last (`pct` = Overtime).
static func overtime_mult(pct: float) -> float:
	return 1.0 + maxf(pct, 0.0) / 100.0

## Seconds Glint's window lasts (`longer` = Keep Moving).
static func glint_time(longer: float) -> float:
	return Balance.GLINT_TIME + maxf(longer, 0.0)

## Buffs I put on myself last this many times as long (StatusContainer asks). Overtime.
func self_buff_time_mult(_res: Resource = null) -> float:
	return overtime_mult(_talent("arcane_overtime"))

## Every hit I deal (_on_damage_dealt_arcane). Echo: it may be repeated a moment
## later (exact: its crit and every modifier are already in it; a proc with its
## own line on the meter, so it feeds nothing and is never repeated itself).
func _echo_talent(info: RefCounted, id: String, amount: int) -> void:
	var pct := _talent("arcane_echo")
	if pct <= 0.0 or not echoes(info.tags, bool(info.is_proc), bool(info.is_dot), Abilities.PATHS.has(id)):
		return
	var arcane: bool = info.tags.has("Arcane")
	if randf() * 100.0 >= echo_chance(pct, arcane):
		return
	var foe: Node = info.target
	var again := echo_amount(amount, echo_share(arcane))
	var damage_type := str(info.damage_type)
	var tags: PackedStringArray = info.tags
	get_tree().create_timer(Balance.ECHO_DELAY).timeout.connect(func():
		if not is_alive() or not is_instance_valid(foe) or not foe.is_alive():
			return
		_exact_hit(foe, again, ECHO_ID, damage_type, tags)
		if foe is Node3D:
			_ring_effect(0.4, Color(0.8, 0.6, 1.0), (foe as Node3D).global_position))

func _counts_for_borrowed_time(id: String) -> bool:
	if not _long_cooldowns.has(id):
		var res := Abilities.get_resource(id)
		_long_cooldowns[id] = res != null and borrowed_time_counts(float(res.cooldown))
	return bool(_long_cooldowns[id])

## Cooldowns have just ticked (_tick_cooldowns). Borrowed Time: one of my long
## cooldowns coming back makes my next spell or ability hit harder.
func _tick_borrowed_time() -> void:
	if cooldowns.is_empty() and _borrowed_watch.is_empty():
		return
	var pct := _talent("arcane_borrowed_time")
	if pct <= 0.0:
		_borrowed_watch.clear()
		return
	for id in cooldowns:
		if not _borrowed_watch.has(id) and _counts_for_borrowed_time(str(id)):
			_borrowed_watch[id] = true
	var back := false
	for id in _borrowed_watch.keys():
		if not cooldowns.has(id):
			_borrowed_watch.erase(id)
			back = true
	if back and status != null and is_alive():
		var fx := StatusContainer.make_buff(BORROWED_FX, "Borrowed Time", BORROWED_FX, 0.0, Balance.BORROWED_TIME_TIME, 1,
			Color(0.8, 0.6, 1.0))
		fx.stat_modifiers = {}
		fx.description = "Your next spell or ability deals more damage."
		status.apply(fx, self)

## A hit of mine, before its damage is worked out (_on_damage_modify). Borrowed
## Time: the first spell or ability I hit with uses the boost, and every hit of
## that one use gets it (BORROWED_TIME_HITS seconds: it may hit several enemies).
func _borrowed_time_hit(info: RefCounted, id: String) -> void:
	if bool(info.is_proc) or bool(info.is_dot) or not Abilities.PATHS.has(id):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if status != null and status.has(BORROWED_FX):
		status.remove(BORROWED_FX)
		_borrowed_id = id
		_borrowed_until = now + Balance.BORROWED_TIME_HITS
	elif id != _borrowed_id or now > _borrowed_until:
		return
	var pct := _talent("arcane_borrowed_time")
	if pct > 0.0:
		info.add_bonus(pct, "Borrowed Time")

## Something hit me (_on_hit_taken). Mirror Finish: an attack I dodged, parried
## or blocked hurts whoever made it (a proc with its own line on the meter).
func _mirror_finish(info: RefCounted) -> void:
	if bool(info.is_dot) or not (bool(info.dodged) or bool(info.parried) or bool(info.blocked)):
		return
	var coef := _talent("arcane_mirror_finish")
	if coef <= 0.0:
		return
	var foe: Variant = info.source
	if foe == null or not is_instance_valid(foe) or not (foe is Node) or not foe.is_in_group("enemies") or not foe.is_alive():
		return
	var back := DamageInfo.make(self, foe, coef, MIRROR_FINISH_ID)
	back.tags = PackedStringArray(MIRROR_FINISH_TAGS)
	back.damage_type = "arcane"
	back.is_proc = true
	back.no_empower = true
	_combat().deal(back)

## I used ability `id` (_use_drafted). Slipstream: after a blink or dash I move faster.
func _slipstream(id: String) -> void:
	if not SLIPSTREAM_MOVES.has(id) or status == null:
		return
	var faster := _talent("arcane_slipstream")
	if faster <= 0.0:
		return
	var fx := StatusContainer.make_buff(SLIPSTREAM_FX, "Slipstream", "move_speed", faster, Balance.SLIPSTREAM_TIME, 1,
		Color(0.8, 0.6, 1.0))
	fx.description = "You move faster."
	status.apply(fx, self)

# --- Fire and Lightning: the open talents ---------------------------------------------------
# Talents of those two books that work with every book's spells and abilities.
# Fire: Feed the Flames (direct hits hurt more what carries one of my damage
# over time effects), Last Ember (such an effect that runs its full time ticks
# once more: StatusContainer asks dot_last_tick_pct), Tempered (a block gives
# Armor for a while). Lightning: Spillover (part of a critical strike jumps to
# another enemy), Change of Pace (using a different spell or ability than the
# last one builds damage), Dig In (standing still for a moment gives damage
# until I move). Numbers: balance.gd and talents.gd.

const SPILLOVER_ID := "spillover"
const TEMPERED_FX := "tempered"
const PACE_FX := "change_of_pace"
const DIG_IN_FX := "dig_in"

var _tempered_fx: Resource
var _pace_fx: Resource
var _pace_last := ""           # the spell / ability I used last (Change of Pace)
var _dig_pos := Vector3.INF    # where I stopped (Dig In)
var _dig_still := 0.0          # ... and for how long I have stood there
var _dig_asked := false        # ... and whether the talent was looked up for this stop

## Can part of this hit spill over to another enemy? A critical strike that is
## a direct hit: never damage over time, a proc or a hit that did nothing.
static func spills_over(crit: bool, is_proc: bool, is_dot: bool, amount: int) -> bool:
	return crit and not is_proc and not is_dot and amount > 0

## Damage of the share of a hit of `amount` that spills over (`pct` % of it).
static func spillover_amount(amount: int, pct: float) -> int:
	return int(round(maxf(float(amount), 0.0) * maxf(pct, 0.0) / 100.0))

## % more damage Change of Pace gives: `per` % for each of its `stacks`.
static func change_of_pace_pct(per: float, stacks: int) -> float:
	return maxf(per, 0.0) * clampi(stacks, 0, Balance.CHANGE_OF_PACE_STACKS)

## Change of Pace's stacks after using `used` when the last one used was `last`
## and I had `stacks`: one more (up to the most) for a different one, none for
## the same one again.
static func change_of_pace_after(stacks: int, last: String, used: String) -> int:
	if used == last:
		return 0
	return mini(maxi(stacks, 0) + 1, Balance.CHANGE_OF_PACE_STACKS)

## Has standing still for `still` seconds dug me in?
static func dug_in(still: float) -> bool:
	return still >= Balance.DIG_IN_TIME

## Have I moved from `anchor` (where I stopped) to `now`? A shift within
## DIG_IN_SLACK does not count.
static func dig_in_moved(anchor: Vector3, now: Vector3) -> bool:
	return anchor == Vector3.INF or anchor.distance_to(now) > Balance.DIG_IN_SLACK

## % of a tick a damage over time effect of mine deals once more when it runs
## its full time (StatusContainer asks). Last Ember.
func dot_last_tick_pct(_res: Resource = null) -> float:
	return _talent("fire_last_ember")

## A hit of mine, before its damage is worked out (_on_damage_modify): Feed the
## Flames, Change of Pace, Dig In.
func _open_talents_modify(info: RefCounted) -> void:
	# Feed the Flames: my direct hits on something carrying one of my damage over time effects.
	if not bool(info.is_dot) and info.target != null and is_instance_valid(info.target) and info.target is Node:
		var feed := _talent("fire_feed_the_flames")
		if feed > 0.0:
			var st: Node = info.target.get_node_or_null("Status")
			if st != null and st.has_method("has_dot_from") and st.has_dot_from(self):
				info.add_bonus(feed, "Feed the Flames")
	if status == null:
		return
	# Change of Pace: for each stack.
	var pace_stacks: int = status.stacks_of(PACE_FX)
	if pace_stacks > 0:
		var pace := change_of_pace_pct(_talent("lightning_change_of_pace"), pace_stacks)
		if pace > 0.0:
			info.add_bonus(pace, "Change of Pace")
	# Dig In: while I stand where I stopped.
	if status.has(DIG_IN_FX):
		var dig := _talent("lightning_dig_in")
		if dig > 0.0:
			info.add_bonus(dig, "Dig In")

## Every hit I deal (_on_damage_dealt_arcane). Spillover: part of a critical
## strike jumps to the nearest other enemy (exact: the crit and every modifier
## are already in it; a proc with its own line on the meter, so it never spills on).
func _spillover_talent(info: RefCounted, id: String, amount: int) -> void:
	if not spills_over(bool(info.crit), bool(info.is_proc), bool(info.is_dot), amount) or not (info.target is Node3D):
		return
	var pct := _talent("lightning_spillover")
	if pct <= 0.0:
		return
	var from: Vector3 = (info.target as Node3D).global_position
	var near := _enemies_near(from, Balance.SPILLOVER_RADIUS, info.target)
	if near.is_empty():
		return
	var foe: Node3D = near[0]
	var spill := spillover_amount(amount, pct)
	if spill <= 0:
		return
	# A spark flies from the one that was hit to the one it jumps to.
	var look := id if Abilities.PATHS.has(id) else "lightningbolt"
	FROST_BOLT.spawn(get_tree().current_scene, from + Vector3(0, 0.3, 0), foe, null, true, look, 0.0)
	var net := _net()
	if net:
		net.send_fx("bolt", from + Vector3(0, 0.3, 0), foe, look)
	var damage_type := str(info.damage_type)
	var tags: PackedStringArray = info.tags
	var wait := from.distance_to(foe.global_position) / maxf(Balance.BOLT_SPEED, 1.0)
	get_tree().create_timer(maxf(wait, 0.02)).timeout.connect(func():
		if is_alive():
			_exact_hit(foe, spill, SPILLOVER_ID, damage_type, tags))

## Something hit me (_on_hit_taken). Tempered: an attack I blocked gives me Armor for a while.
func _tempered(info: RefCounted) -> void:
	if not bool(info.blocked) or bool(info.is_dot) or status == null:
		return
	var pct := _talent("fire_tempered")
	if pct <= 0.0:
		return
	if _tempered_fx == null or not is_equal_approx(float(_tempered_fx.stat_modifiers.get(Stats.ARMOR + Stats.PCT, 0.0)), pct):
		_tempered_fx = StatusContainer.make_buff(TEMPERED_FX, "Tempered", Stats.ARMOR + Stats.PCT, pct,
			Balance.TEMPERED_TIME, Balance.TEMPERED_STACKS, Color(1.0, 0.6, 0.3))
		_tempered_fx.description = "More Armor from each attack you blocked."
	status.apply(_tempered_fx, self)

## I finished casting / using `id` (SignalBus.cast_finished). Change of Pace: a
## different spell or ability than the last one adds a stack; the same one again
## ends it.
func _change_of_pace(id: String) -> void:
	if not Abilities.PATHS.has(id):
		return
	var last := _pace_last
	_pace_last = id
	if status == null:
		return
	var per := _talent("lightning_change_of_pace")
	if per <= 0.0:
		return
	if change_of_pace_after(status.stacks_of(PACE_FX), last, id) <= 0:
		status.remove(PACE_FX)
		return
	if _pace_fx == null:
		_pace_fx = StatusContainer.make_buff(PACE_FX, "Change of Pace", PACE_FX, 0.0, Balance.CHANGE_OF_PACE_TIME,
			Balance.CHANGE_OF_PACE_STACKS, Color(0.6, 0.8, 1.0))
		_pace_fx.stat_modifiers = {}
		_pace_fx.description = "You deal more damage. Using the same spell or ability twice in a row ends it."
	status.apply(_pace_fx, self)   # (one more stack; every stack lasts its full time again)

## Dig In (_process): standing still for a moment digs me in until I move.
func _tick_dig_in(delta: float) -> void:
	if dig_in_moved(_dig_pos, global_position):
		_dig_pos = global_position
		_dig_still = 0.0
		_dig_asked = false
		if status != null and status.has(DIG_IN_FX):
			status.remove(DIG_IN_FX)
		return
	_dig_still += delta
	if _dig_asked or not dug_in(_dig_still) or status == null or not is_alive():
		return
	_dig_asked = true   # (the talent is looked up once for each time I stop)
	if _talent("lightning_dig_in") <= 0.0:
		return
	var fx := StatusContainer.make_buff(DIG_IN_FX, "Dig In", DIG_IN_FX, 0.0, 3600.0, 1, Color(0.6, 0.8, 1.0))
	fx.stat_modifiers = {}
	fx.description = "You deal more damage until you move."
	status.apply(fx, self)

# --- Arcane melee (a damage dealer with a melee weapon in each hand) --------------------
# No resource: cooldowns alone. Every strike I land with an Arcane melee ability
# leaves a Trace on me: a record of the damage it dealt. I hold up to TRACE_MAX
# (the newest pushes out the oldest), each for TRACE_TIME seconds. Encore replays
# every Trace on my target for ENCORE_PCT % of what it recorded, and uses them up.
# Swift Cut, Deep Cut, Late Cut and Wide Cut are its strikes (the tank's strikes
# and Arcane Strike leave Traces too); Double Time makes each strike leave more
# Traces and lets me hold more. Traces are only kept while I know Encore.
# Talents: Long Memory (Traces last longer), Standing Ovation (Encore replays
# more; capstone: one more Trace), Clean Lines (a Swift Cut crit brings Deep Cut
# back sooner), Second Showing (Encore may keep the Traces). Numbers: balance.gd.

const TRACE_FX := "trace"
const SWIFT_CUT_ID := "swiftcut"
const DEEP_CUT_ID := "deepcut"
const LATE_CUT_ID := "latecut"
const WIDE_CUT_ID := "widecut"
const ENCORE_ID := "encore"
const DOUBLE_TIME_ID := "doubletime"
const DOUBLE_TIME_FX := "double_time"
const FULL_HOUSE_FX := "full_house"            # Full House: my next Encore reaches other enemies too
## The replays Full House adds on other enemies: their own line on the meter (Details.HIT_NAMES).
const FULL_HOUSE_HIT_ID := "full_house"
const DRESS_REHEARSAL_FX := "dress_rehearsal"  # Dress Rehearsal's capstone: my next Encore keeps the Traces
const CURTAIN_CALL_LABEL := "Curtain Call"
const TRACE_TAGS := ["Arcane", "Ability", "Melee"]

var _traces: Array = []       # oldest first: {"id": ability, "key": int, "amount": int, "born": float, "until": float}
var _trace_serial := 0        # the key of the next new Trace (copies of one strike share it)
var _trace_fx: Resource

## Does this hit leave a Trace? A hit of an Arcane melee ability that landed:
## never a proc (Encore's replays, Late Cut's second hit, echoes), damage over
## time or a spell.
static func leaves_trace(tags: PackedStringArray, is_proc: bool, is_dot: bool, amount: int) -> bool:
	return amount > 0 and not is_proc and not is_dot \
		and tags.has("Arcane") and tags.has("Melee") and tags.has("Ability")

## How many Traces I can hold (`extra` = Standing Ovation's capstone, `double` = Double Time).
static func trace_cap(extra: bool, double: bool) -> int:
	return (Balance.TRACE_MAX + (Balance.STANDING_OVATION_TRACES if extra else 0)) \
		* (Balance.DOUBLE_TIME_TRACES if double else 1)

## Seconds a Trace lasts (`longer` = Long Memory).
static func trace_time(longer: float) -> float:
	return Balance.TRACE_TIME + maxf(longer, 0.0)

## The Traces of `traces` that have not run out at `now`.
static func traces_alive(traces: Array, now: float) -> Array:
	var out := []
	for t in traces:
		if float(t["until"]) > now:
			out.append(t)
	return out

## `traces` (oldest first) after a hit of ability `id` dealt `amount` at `now`.
## The hits of one use of an ability share a Trace (a Trace of the same ability
## born within TRACE_MERGE_WINDOW): it keeps the largest of them, so Wide Cut
## leaves one Trace however many enemies it hits. Otherwise `copies` new Traces
## with the key `key` are added, and the oldest are pushed out past `cap`.
## Holding more than `cap` already (Double Time ended with more than the usual
## limit), nothing is added and nothing is pushed out: those Traces stay to be
## replayed or to run out, and new ones come once I am back within the limit.
static func traces_after(traces: Array, id: String, amount: int, now: float, until: float,
		copies: int, cap: int, key: int) -> Array:
	var out := traces.duplicate(true)
	var merged := false
	for t in out:
		if str(t["id"]) == id and now - float(t["born"]) <= Balance.TRACE_MERGE_WINDOW:
			t["amount"] = maxi(int(t["amount"]), amount)
			merged = true
	if out.size() > maxi(cap, 0):
		return out
	if not merged:
		for i in maxi(copies, 1):
			out.append({"id": id, "key": key, "amount": amount, "born": now, "until": until})
	while out.size() > maxi(cap, 0):
		out.pop_front()
	return out

## `traces` with `amount` added to every Trace with the key `key` (Late Cut's
## second hit joins the Trace its first one left).
static func traces_added(traces: Array, key: int, amount: int) -> Array:
	var out := traces.duplicate(true)
	for t in out:
		if int(t["key"]) == key:
			t["amount"] = int(t["amount"]) + maxi(amount, 0)
	return out

## The key of the newest Trace of ability `id` (-1 = none).
static func newest_trace_key(traces: Array, id: String) -> int:
	for i in range(traces.size() - 1, -1, -1):
		if str(traces[i]["id"]) == id:
			return int(traces[i]["key"])
	return -1

## % of a Trace's recorded damage Encore replays (`more` = Standing Ovation).
static func encore_pct(more: float) -> float:
	return Balance.ENCORE_PCT + maxf(more, 0.0)

## Damage of Encore's replay of a Trace that recorded `amount`.
static func encore_amount(amount: int, pct: float) -> int:
	return int(round(maxf(float(amount), 0.0) * maxf(pct, 0.0) / 100.0))

## Does Encore use my Traces up? (Second Showing: a `pct` % chance it does not;
## `roll` 0-100. `free` = Dress Rehearsal's capstone: the first Encore during
## Double Time never does.)
static func encore_uses_traces(pct: float, roll: float, free: bool = false) -> bool:
	return not free and not (pct > 0.0 and roll < pct)

## Damage the Trace of a hit of `amount` by ability `id` records (Heavy Hand:
## Deep Cut's records `heavy_pct` % more than the strike dealt).
static func trace_amount(id: String, amount: int, heavy_pct: float) -> int:
	if id == DEEP_CUT_ID and heavy_pct > 0.0:
		return int(round(float(amount) * (1.0 + heavy_pct / 100.0)))
	return amount

## Is a Trace with the key `key` among `traces`?
static func has_trace_key(traces: Array, key: int) -> bool:
	for t in traces:
		if int(t["key"]) == key:
			return true
	return false

## Seconds until Late Cut's second hit (`sooner` = No Loose Ends).
static func late_cut_delay(sooner: float) -> float:
	return maxf(Balance.LATE_CUT_DELAY - maxf(sooner, 0.0), 0.1)

## % more damage Practiced Hand gives Swift Cut: `per` % for each Trace I hold.
static func practiced_hand_pct(per: float, held: int) -> float:
	return maxf(per, 0.0) * maxi(held, 0)

## % more damage Curtain Call gives each replay when Encore replays `replayed` Traces.
static func curtain_call_pct(pct: float, replayed: int) -> float:
	return pct if pct > 0.0 and replayed >= Balance.CURTAIN_CALL_TRACES else 0.0

## Seconds Time Signature takes off my other Arcane cooldowns when Encore
## replays `replayed` Traces (`per` seconds for each).
static func time_signature_cut(per: float, replayed: int) -> float:
	return maxf(per, 0.0) * maxi(replayed, 0)

## Full House: does a Wide Cut that hit `enemies` enemies set up my next Encore?
## (`others` = the talent's number: the other enemies that Encore will reach.)
static func full_house_ready(others: float, enemies: int) -> bool:
	return others > 0.0 and enemies >= Balance.FULL_HOUSE_ENEMIES

## Full House: damage each other enemy takes from a replay of `amount`.
static func full_house_amount(amount: int) -> int:
	return int(round(maxf(float(amount), 0.0) * Balance.FULL_HOUSE_PCT / 100.0))

## Full House: the buff that says my next Encore reaches the enemies around its target.
static func make_full_house_fx() -> Resource:
	var fx := StatusContainer.make_buff(FULL_HOUSE_FX, "Full House", FULL_HOUSE_FX, 0.0, Balance.FULL_HOUSE_TIME, 1,
		Abilities.color_of(ENCORE_ID))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Arcane"])
	fx.description = "Your next %s also replays each Trace on other enemies near its target, for %s%% of its damage." % [
		Abilities.ability_name(ENCORE_ID), Stats.num(Balance.FULL_HOUSE_PCT)]
	return fx

## Dress Rehearsal's capstone: the buff that says my next Encore keeps the Traces
## (`time` = seconds Double Time lasts).
static func make_dress_rehearsal_fx(time: float) -> Resource:
	var fx := StatusContainer.make_buff(DRESS_REHEARSAL_FX, "Dress Rehearsal", DRESS_REHEARSAL_FX, 0.0, time, 1,
		Abilities.color_of(DOUBLE_TIME_ID))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Arcane"])
	fx.description = "Your next %s does not use up your Traces." % Abilities.ability_name(ENCORE_ID)
	return fx

## Seconds Double Time lasts (`longer` = Dress Rehearsal).
static func double_time_time(longer: float) -> float:
	return Balance.DOUBLE_TIME_TIME + maxf(longer, 0.0)

func _trace_now() -> float:
	return Time.get_ticks_msec() / 1000.0

## How many Traces I hold.
func traces() -> int:
	return _traces.size()

func _trace_buff() -> Resource:
	if _trace_fx == null:
		_trace_fx = StatusContainer.make_buff(TRACE_FX, "Trace", TRACE_FX, 0.0, Balance.TRACE_TIME,
			trace_cap(true, true), Abilities.color_of(ENCORE_ID))
		_trace_fx.stat_modifiers = {}
		_trace_fx.tags = PackedStringArray(["Arcane"])
		_trace_fx.description = "A record of the damage one of your strikes dealt. %s replays it." % Abilities.ability_name(ENCORE_ID)
	return _trace_fx

## The buff shows how many Traces I hold, and when the oldest of them runs out.
func _sync_traces() -> void:
	if status == null:
		return
	if _traces.is_empty():
		if status.has(TRACE_FX):
			status.remove(TRACE_FX)
		return
	if not status.has(TRACE_FX):
		status.apply(_trace_buff(), self)
	status.set_stacks(TRACE_FX, _traces.size())
	# (A moment longer than the Trace itself, so _tick_traces is what ends it.)
	status.set_remaining(TRACE_FX, maxf(float(_traces[0]["until"]) - _trace_now(), 0.0) + 0.1)

## Traces run out one by one (_process).
func _tick_traces() -> void:
	if _traces.is_empty():
		return
	var alive := traces_alive(_traces, _trace_now())
	if alive.size() != _traces.size():
		_traces = alive
		_sync_traces()

func _clear_traces() -> void:
	if _traces.is_empty():
		return
	_traces = []
	_sync_traces()

## Every hit I deal (_on_damage_dealt_arcane): a strike with an Arcane melee
## ability leaves a Trace of the damage it dealt. Clean Lines: a Swift Cut that
## critically strikes brings Deep Cut back sooner.
func _trace_hit(info: RefCounted, id: String, amount: int) -> void:
	if id == SWIFT_CUT_ID and bool(info.crit) and not bool(info.is_proc):
		var clean := _talent("arcane_clean_lines")
		if clean > 0.0:
			_cut_cooldown(DEEP_CUT_ID, clean)
	if not Abilities.PATHS.has(id) or not leaves_trace(info.tags, bool(info.is_proc), bool(info.is_dot), amount):
		return
	_leave_trace(id, trace_amount(id, amount, _talent("arcane_heavy_hand")))   # Heavy Hand: Deep Cut's records more

## A strike of ability `id` leaves a Trace that records `amount` (or joins the
## Trace the same use already left: traces_after).
func _leave_trace(id: String, amount: int) -> void:
	var pd := get_node_or_null("/root/PlayerData")
	if pd == null or not pd.has_ability(ENCORE_ID):
		return   # nothing to replay them with
	var now := _trace_now()
	var double: bool = status != null and status.has(DOUBLE_TIME_FX)
	_trace_serial += 1
	# (Long Memory makes them last longer; so does Overtime, like the buff they are shown as.)
	_traces = traces_after(traces_alive(_traces, now), id, amount, now,
		now + trace_time(_talent("arcane_long_memory")) * self_buff_time_mult(),
		Balance.DOUBLE_TIME_TRACES if double else 1, trace_cap(_capstone("arcane_standing_ovation"), double), _trace_serial)
	_sync_traces()

## Late Cut: the cut lands, and lands again LATE_CUT_DELAY seconds later for the
## same damage (a proc: it can't crit or be avoided, the first hit already was
## rolled). The second hit joins the Trace the first one left.
func _late_cut(w: Dictionary, res: Resource) -> void:
	var foe: Node = target
	var first := deal_damage(foe, _dual_weapon_hit(w, res), LATE_CUT_ID)
	_slash_effect(Abilities.color_of(LATE_CUT_ID))
	if first <= 0:
		return
	var key := newest_trace_key(_traces, LATE_CUT_ID)
	get_tree().create_timer(late_cut_delay(_talent("arcane_no_loose_ends"))).timeout.connect(func():   # No Loose Ends: sooner
		if is_dead() or not is_instance_valid(foe) or not foe.is_alive():
			return
		_exact_hit(foe, first, LATE_CUT_ID, "arcane", PackedStringArray(TRACE_TAGS))
		if foe is Node3D:
			_ring_effect(0.5, Abilities.color_of(LATE_CUT_ID), (foe as Node3D).global_position)
		if key >= 0 and has_trace_key(_traces, key):
			_traces = traces_added(_traces, key, first)
			_sync_traces()
		elif _capstone("arcane_no_loose_ends"):
			_leave_trace(LATE_CUT_ID, first))   # its Trace is gone: this hit leaves one of its own

## Wide Cut: everything around me is hit with both weapons; more than
## AOE_TARGET_CAP enemies share that many hits' damage. Its hits leave one
## Trace between them (the largest: _trace_hit).
func _wide_cut(w: Dictionary, res: Resource) -> void:
	var col := Abilities.color_of(WIDE_CUT_ID)
	var reach := float(res.radius) + Abilities.radius_bonus(WIDE_CUT_ID)
	var hit := _enemies_within(reach)
	var coef := _dual_weapon_hit(w, res) * Balance.aoe_share(hit.size())
	for e in hit:
		if is_instance_valid(e) and e.is_alive():
			deal_damage(e, coef, WIDE_CUT_ID)
	# Full House: a Wide Cut into a crowd, and my next Encore reaches the enemies around its target too.
	if full_house_ready(_talent("arcane_full_house"), hit.size()):
		status.apply(make_full_house_fx(), self)
	for i in 2:
		_slash_effect(col)
	_ring_effect(reach, col)
	_ring_effect(reach * 0.6, Color(0.95, 0.9, 1.0))

## Encore: every Trace I hold is replayed on my target, each for a share of the
## damage it recorded (exact: its crit and every modifier are already in it; a
## proc, so it leaves no Trace and feeds nothing). Then they are gone, unless
## Second Showing keeps them.
func _encore() -> void:
	var foe: Node = target
	var held := traces_alive(_traces, _trace_now())
	var pct := encore_pct(_talent("arcane_standing_ovation"))   # + Standing Ovation
	# A ghost of me runs through the target for each Trace (scripts/trace_ghost.gd),
	# one after the other; each Trace's hit lands as its ghost gets there.
	var from := global_position
	var through := from
	if is_instance_valid(foe) and foe is Node3D:
		var there: Vector3 = (foe as Node3D).global_position
		through = Vector3(there.x, from.y + (Combat.feet_y(foe) - Combat.feet_y(self)), there.z)
	var count := held.size()
	# Curtain Call: a full replay hits harder (what it adds is its own line on the meter).
	var curtain := curtain_call_pct(_talent("arcane_curtain_call"), count)
	var bonuses: Array = [[curtain, CURTAIN_CALL_LABEL]] if curtain > 0.0 else []
	# Full House: after a Wide Cut into a crowd, each Trace is replayed on the
	# enemies nearest the target too, for a share of its damage. This Encore uses it up.
	var others: Array = []
	if status.has(FULL_HOUSE_FX):
		status.remove(FULL_HOUSE_FX)
		var reach := int(round(_talent("arcane_full_house")))
		if foe is Node3D:
			for e in _enemies_near((foe as Node3D).global_position, Balance.FULL_HOUSE_RADIUS, foe):
				if others.size() >= reach:
					break
				others.append(e)
	TRACE_GHOST.run(get_tree().current_scene, self, from, through, count)
	_net_fx("ghosts", from, null, {"to": through, "n": count})
	for i in count:
		var amount := encore_amount(int(held[i]["amount"]), pct)
		var share := full_house_amount(amount)
		get_tree().create_timer(maxf(TRACE_GHOST.hit_time(from, through, i, count), 0.02)).timeout.connect(func():
			if not is_alive():
				return
			if is_instance_valid(foe) and foe.is_alive():
				_exact_hit(foe, amount, ENCORE_ID, "arcane", PackedStringArray(TRACE_TAGS), bonuses)
				if foe is Node3D:
					_ring_effect(0.5, Color(0.95, 0.9, 1.0), (foe as Node3D).global_position)
			for e in others:
				if is_instance_valid(e) and e.is_alive():
					_exact_hit(e, share, FULL_HOUSE_HIT_ID, "arcane", PackedStringArray(TRACE_TAGS), bonuses)
					if e is Node3D:
						_ring_effect(0.4, Abilities.color_of(ENCORE_ID), (e as Node3D).global_position))
	# Dress Rehearsal's capstone: the first Encore during Double Time keeps the Traces.
	var free: bool = status.has(DRESS_REHEARSAL_FX) and status.has(DOUBLE_TIME_FX)
	if status.has(DRESS_REHEARSAL_FX):
		status.remove(DRESS_REHEARSAL_FX)
	_traces = [] if encore_uses_traces(_talent("arcane_second_showing"), randf() * 100.0, free) else held
	_sync_traces()
	# Time Signature: each Trace replayed takes time off everything else Arcane
	# (spells and abilities alike; never an interrupt).
	var signature := time_signature_cut(_talent("arcane_time_signature"), held.size())
	if signature > 0.0:
		for cd in cooldowns.keys():
			if str(cd) != ENCORE_ID and (_in_arcane_book(str(cd)) or _is_arcane_spell(str(cd))):
				_cut_cooldown(str(cd), signature)
	_slash_effect(Abilities.color_of(ENCORE_ID))

func _start_double_time() -> void:
	var time := double_time_time(_talent("arcane_dress_rehearsal"))   # + Dress Rehearsal
	_arcane_buff(DOUBLE_TIME_FX, DOUBLE_TIME_ID, time,
		"Each of your strikes leaves more Traces, and you can hold more of them.")
	if _capstone("arcane_dress_rehearsal"):
		status.apply(make_dress_rehearsal_fx(time), self)   # its capstone: the first Encore while it lasts keeps the Traces
	_ring_effect(1.5, Abilities.color_of(DOUBLE_TIME_ID))
	_ring_effect(0.9, Color(0.95, 0.9, 1.0))

# --- Lightning melee ------------------------------------------------------------------------
# The Energy bar with a weapon. Charged Edge and Whiplash give Energy; Arc
# Cleave, Cadence, Twin Current, Static Step and Reflex Arc spend it; Overdrive
# only lasts while the bar is kept low; Faraday Guard takes hits out of it.
# Polar Strike is taught by the Rune of Polarity. Numbers are in balance.gd.

const OVERDRIVE_ID := "overdrive"
const OVERDRIVE_FX := "overdrive"
const TWIN_CURRENT_ID := "twincurrent"
const TWIN_CURRENT_FX := "twin_current"
const STATIC_STEP_ID := "staticstep"
const STATIC_STEP_FX := "static_step"
const BACK_CURRENT_ID := "backcurrent"
const BACK_CURRENT_FX := "back_current"
const CADENCE_ID := "cadence"
const CADENCE_FX := "cadence"
const SPLIT_SECOND_ID := "splitsecond"
const SPLIT_SECOND_FX := "split_second"
const WHIPLASH_ID := "whiplash"
const FARADAY_ID := "faradayguard"
const FARADAY_FX := "faraday_guard"
const REFLEX_ID := "reflexarc"
const REFLEX_FX := "reflex_arc"
const POLAR_ID := "polarstrike"
const POLARITY_FX := "polarity"
## Names of the modifiers these put on a hit (the damage meter's lines, and how
## _on_hit_taken knows a hit on me was changed by them).
const STATIC_STEP_LABEL := "Static Step"
const POLARITY_LABEL := "Polarity"
const FARADAY_LABEL := "Faraday Guard"
const REFLEX_LABEL := "Reflex Arc"
## A modifier this size takes a hit down to nothing.
const AVOID_PCT := 1000.0
## Instant abilities taught by runes (used like the drafted ones).
const RUNE_INSTANTS := [POLAR_ID]
const LASH = preload("res://scripts/lash.gd")
var _polar_positive := false   # the charge my last Polar Strike left
var _charges_used := {}        # "your next weapon ability" buffs used this frame (gone at its end)

## A buff of this kit: no stats of its own, a marker with a text.
func _melee_buff(fx_id: String, ability_id: String, time: float, text: String, stacks: int = 1) -> Resource:
	var fx := StatusContainer.make_buff(fx_id, Abilities.ability_name(ability_id), fx_id, 0.0, time, stacks,
		Abilities.color_of(ability_id))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Lightning"])
	fx.description = text
	return fx

## Is this a melee attack (what Reflex Arc avoids and Back-Current answers)?
## Never damage over time.
static func is_melee_attack(tags: PackedStringArray, is_dot: bool) -> bool:
	return not is_dot and tags.has("Melee")

## The percent a modifier named `label` put on a hit (0 if it carries none).
static func bonus_named(parts: Array, label: String) -> float:
	var total := 0.0
	for p in parts:
		if p is Array and p.size() >= 2 and str(p[0]) == label:
			total += float(p[1])
	return total

## Arc Cleave: everything around me is hit; more than AOE_TARGET_CAP enemies
## share that many hits' damage.
func _arc_cleave(w: Dictionary, res: Resource) -> void:
	var col := Abilities.color_of(str(res.id))
	var hit := _enemies_within(float(res.radius))
	var coef := _weapon_hit(w, res) * Balance.aoe_share(hit.size())
	for e in hit:
		if is_instance_valid(e) and e.is_alive():
			deal_damage(e, coef, str(res.id))
	for i in 2:
		_slash_effect(col)
	_ring_effect(float(res.radius), col)

# Overdrive: faster auto-attacks that zap and give Energy, for as long as the
# Energy is spent again. It cannot start above the limit and ends above it.

## Energy above which Overdrive cannot be used and ends: a share of the bar
## (`max_energy`: bigger with Deep Reserves).
static func overdrive_limit(max_energy: float = Balance.RESOURCE_MAX) -> float:
	return max_energy * Balance.OVERDRIVE_ENERGY_LIMIT_PCT / 100.0

## Does Overdrive allow this much Energy? (Exactly the limit is fine.)
static func overdrive_holds(energy: float, max_energy: float = Balance.RESOURCE_MAX) -> bool:
	return energy <= overdrive_limit(max_energy) + 0.0001

# Lightning talents (the numbers per rank are in talents.gd).

## Energy per second at `base`, regenerating `pct`% faster (Quick Charge).
static func energy_regen(base: float, pct: float) -> float:
	return base * (1.0 + maxf(pct, 0.0) / 100.0)

## Running on Empty: does this hit of mine get it? Lightning damage of a spell or
## an ability, while I hold less than RUNNING_ON_EMPTY_ENERGY Energy.
static func running_on_empty(damage_type: String, tags: PackedStringArray, energy: float) -> bool:
	return damage_type == "lightning" and (tags.has("Spell") or tags.has("Ability")) \
		and energy < Balance.RUNNING_ON_EMPTY_ENERGY

## Running Start: did a Static Step of `metres` carry me far enough?
static func running_start_applies(metres: float) -> bool:
	return metres >= Balance.RUNNING_START_DISTANCE - 0.001

## Seconds Redline adds to an Overdrive it already made `added` seconds longer,
## at `per` seconds a spender: never past REDLINE_MAX in total.
static func redline_add(per: float, added: float) -> float:
	return clampf(per, 0.0, maxf(Balance.REDLINE_MAX - added, 0.0))

var _overdrive_added := 0.0    # seconds Redline has added to the running Overdrive
var _cadence_third := false    # the hits being dealt are Cadence's third strike (Third Beat)

## Redline: an ability of mine just spent Energy. With Overdrive up it lasts longer.
func _redline() -> void:
	var per := _talent("lightning_redline")
	if per <= 0.0 or status == null or not status.has(OVERDRIVE_FX):
		return
	var add := redline_add(per, _overdrive_added)
	if add <= 0.0:
		return
	_overdrive_added += add
	status.set_remaining(OVERDRIVE_FX, status.remaining_of(OVERDRIVE_FX) + add)

## Seconds between the auto-attacks of a weapon with `interval`, at `haste`
## (haste_mult), with Overdrive up or not.
## `attack_speed_pct` = % faster from attack speed buffs (Tempo), on top of both.
static func auto_interval(interval: float, haste: float, overdriven: bool, attack_speed_pct: float = 0.0) -> float:
	var speed := maxf(haste, 0.01)
	if overdriven:
		speed *= 1.0 + Balance.OVERDRIVE_SPEED_PCT / 100.0
	speed *= 1.0 + maxf(attack_speed_pct, 0.0) / 100.0
	return interval / speed

func overdrive_active() -> bool:
	return status != null and status.has(OVERDRIVE_FX)

func _start_overdrive() -> void:
	var col := Abilities.color_of(OVERDRIVE_ID)
	_overdrive_added = 0.0
	status.apply(_melee_buff(OVERDRIVE_FX, OVERDRIVE_ID, Balance.OVERDRIVE_TIME,
		"Your auto-attacks are %s%% faster; each one that lands zaps the target and gives you %s Energy. Ends the moment you have more than %s Energy." % [
			Stats.num(Balance.OVERDRIVE_SPEED_PCT), Stats.num(Balance.OVERDRIVE_ENERGY), Stats.num(overdrive_limit(resource_max("energy")))]), self)
	_slash_effect(col)
	_ring_effect(1.2, col)

## Every frame: Overdrive ends the moment I hold more Energy than it allows.
func _tick_overdrive() -> void:
	if status != null and status.has(OVERDRIVE_FX) \
			and not overdrive_holds(float(resources["energy"]), resource_max("energy")):
		status.remove(OVERDRIVE_FX)

## Lightning damage Twin Current adds to an auto-attack that dealt `amount`.
static func twin_current_damage(amount: int) -> float:
	return maxf(float(amount) * Balance.TWIN_CURRENT_PCT / 100.0, 0.0)

## Twin Current: a fresh set of charges (never more than TWIN_CURRENT_HITS).
func _start_twin_current() -> void:
	var col := Abilities.color_of(TWIN_CURRENT_ID)
	status.remove(TWIN_CURRENT_FX)
	status.apply(_melee_buff(TWIN_CURRENT_FX, TWIN_CURRENT_ID, Balance.TWIN_CURRENT_TIME,
		"Your next auto-attacks hit a second time for %s%% of their damage as Lightning damage, one stack each." % Stats.num(Balance.TWIN_CURRENT_PCT),
		Balance.TWIN_CURRENT_HITS), self)
	status.set_stacks(TWIN_CURRENT_FX, Balance.TWIN_CURRENT_HITS)
	for i in 2:
		_slash_effect(col)

## An auto-attack of mine landed (SignalBus.damage_dealt). Twin Current repeats
## part of it: an exact share of the swing (its crit is already in it), dealt
## as a proc so it feeds nothing else. Overdrive zaps the target and gives Energy.
func _on_auto_landed(info: RefCounted) -> void:
	if status == null or int(info.amount) <= 0:
		return
	var foe: Node = info.target
	var charged := _talent("lightning_charged_strikes")   # Charged Strikes: every auto-attack gives Energy
	if charged > 0.0:
		_gain("energy", charged)
	if status.has(TWIN_CURRENT_FX):
		# Hot Wire: a chance the echo doesn't use up a charge.
		if randf() * 100.0 >= _talent("lightning_hot_wire"):
			status.spend_stacks(TWIN_CURRENT_FX, 1)
		if foe.is_alive():
			var extra := DamageInfo.make(self, foe, 1.0, TWIN_CURRENT_ID)
			extra.unit = twin_current_damage(int(info.amount))
			extra.exact = true
			extra.add_power = false
			extra.can_crit = false
			extra.can_block = false
			extra.is_proc = true
			extra.damage_type = "lightning"
			extra.tags = PackedStringArray(["Lightning", "Melee"])
			_combat().deal(extra)
	if status.has(OVERDRIVE_FX):
		if is_instance_valid(foe) and foe.is_alive():
			deal_damage(foe, float(Abilities.get_resource(OVERDRIVE_ID).damage), OVERDRIVE_ID, true)
		_gain("energy", Balance.OVERDRIVE_ENERGY)

## Metres Static Step travels toward a target `gap` metres away (edge to edge):
## it stops well inside the weapon's `reach`, and never goes backwards.
static func static_step_travel(gap: float, reach: float) -> float:
	return maxf(gap - reach * 0.5, 0.0)

## Static Step: a dash to my target (it stops short of walls, like Blink), and
## my next weapon ability hits harder.
func _static_step(w: Dictionary) -> void:
	var col := Abilities.color_of(STATIC_STEP_ID)
	if status.has(WHIP_CRACK_FX):
		status.remove(WHIP_CRACK_FX)   # Whip Crack: that was the cheaper one (it was paid for already)
	var from := global_position
	if _has_valid_target():
		var gap := Vector2(target.global_position.x - from.x, target.global_position.z - from.z).length() \
			- Combat.hitbox_radius(target) - Combat.hitbox_radius(self)
		var want := static_step_travel(gap, float(w.get("attack_range", 1.5)))
		var dist := minf(_dash_distance(want), want) if want > 0.0 else 0.0
		if dist > 0.0:
			var to := from + _flat_forward() * dist
			# Up or down a slope with the target: as far along the climb as along the dash.
			to.y = from.y + (Combat.feet_y(target) - Combat.feet_y(self)) * dist / want + 0.05
			global_position = to
			if running_start_applies(dist):
				_gain("energy", _talent("lightning_running_start"))   # Running Start: a long dash gives Energy
	_ring_effect(0.8, col, from)
	_ring_effect(0.8, col)
	LASH.spawn(get_tree().current_scene, from + Vector3(0, 0.3, 0), global_position + Vector3(0, 0.3, 0), col)
	status.apply(_melee_buff(STATIC_STEP_FX, STATIC_STEP_ID, Balance.STATIC_STEP_TIME,
		"Your next weapon ability deals %s%% more damage." % Stats.num(Balance.STATIC_STEP_PCT)), self)

## Is this hit of mine a weapon ability's own hit? (What Static Step and Polar
## Strike empower: not auto-attacks, not procs, not damage over time.)
static func is_weapon_ability_hit(id: String, is_proc: bool, is_dot: bool) -> bool:
	return not is_proc and not is_dot and not id.begins_with("auto_") and Abilities.uses_weapon(id)

## Does Polar Strike's charge empower ability `id`? Any weapon ability but Polar Strike itself.
static func polarity_applies(id: String) -> bool:
	return id != POLAR_ID

## A hit of mine is being worked out (_on_damage_modify): Static Step and the
## charge of Polar Strike make my next weapon ability hit harder. Every hit of
## that ability landing this frame gets it (an AoE uses it once).
func _empower_weapon_ability(info: RefCounted, id: String) -> void:
	if status == null or not is_weapon_ability_hit(id, bool(info.is_proc), bool(info.is_dot)):
		return
	if status.has(STATIC_STEP_FX):
		info.add_bonus(Balance.STATIC_STEP_PCT, STATIC_STEP_LABEL)
		_use_charge(STATIC_STEP_FX)
	if polarity_applies(id) and status.has(POLARITY_FX):
		info.add_bonus(Balance.POLARITY_PCT, POLARITY_LABEL)
		_use_charge(POLARITY_FX)

## A "your next weapon ability" buff was used: it is gone at the end of the frame.
func _use_charge(fx_id: String) -> void:
	if _charges_used.has(fx_id):
		return
	if _charges_used.is_empty():
		_drop_used_charges.call_deferred()
	_charges_used[fx_id] = true

func _drop_used_charges() -> void:
	for fx_id in _charges_used:
		if status != null:
			status.remove(str(fx_id))
	_charges_used.clear()

func _start_back_current() -> void:
	var col := Abilities.color_of(BACK_CURRENT_ID)
	status.apply(_melee_buff(BACK_CURRENT_FX, BACK_CURRENT_ID, Balance.BACK_CURRENT_TIME,
		"Every melee hit you take zaps the attacker and gives you %s Energy." % Stats.num(Balance.BACK_CURRENT_ENERGY)), self)
	_ring_effect(1.3, col)

## Which press of Cadence comes next (0 = the first) after `stacks` presses.
static func cadence_step(stacks: int) -> int:
	return clampi(stacks, 0, Balance.CADENCE_MULTS.size() - 1)

## Weapon damage multiplier of that press.
static func cadence_mult(step: int) -> float:
	return float(Balance.CADENCE_MULTS[clampi(step, 0, Balance.CADENCE_MULTS.size() - 1)])

## Cadence: each press in time hits harder; the last also hits everything
## around me (more than AOE_TARGET_CAP enemies share that many hits' damage),
## then the count starts over.
func _cadence(w: Dictionary, res: Resource) -> void:
	var col := Abilities.color_of(CADENCE_ID)
	var last := Balance.CADENCE_MULTS.size() - 1
	var step := cadence_step(int(status.stacks_of(CADENCE_FX)))
	var coef := float(w.get("damage", 0.0)) * cadence_mult(step) + float(res.damage)
	if step < last:
		status.apply(_melee_buff(CADENCE_FX, CADENCE_ID, Balance.CADENCE_WINDOW,
			"Your next Cadence hits harder. The count is lost after %s sec." % Stats.num(Balance.CADENCE_WINDOW), last), self)
		deal_damage(target, coef, CADENCE_ID)
		_slash_effect(col)
		return
	status.remove(CADENCE_FX)
	var hit := _enemies_within(float(res.radius))
	if not hit.has(target):
		hit.append(target)   # in weapon reach, but outside the burst's
	var share := Balance.aoe_share(hit.size())
	_cadence_third = true   # Third Beat: these hits are the third strike (_on_damage_modify)
	for e in hit:
		if is_instance_valid(e) and e.is_alive():
			deal_damage(e, coef * share, CADENCE_ID)
	_cadence_third = false
	if _capstone("lightning_third_beat"):
		_gain("energy", Balance.THIRD_BEAT_ENERGY)
	for i in 2:
		_slash_effect(col)
	_ring_effect(float(res.radius), col)

## A global cooldown of `gcd` seconds with Split Second up: shorter, but never
## below SPLIT_SECOND_MIN_GCD (and never longer than it already was).
static func split_second_gcd(gcd: float) -> float:
	return maxf(gcd - Balance.SPLIT_SECOND_GCD, minf(gcd, Balance.SPLIT_SECOND_MIN_GCD))

func _start_split_second() -> void:
	var col := Abilities.color_of(SPLIT_SECOND_ID)
	status.apply(_melee_buff(SPLIT_SECOND_FX, SPLIT_SECOND_ID, Balance.SPLIT_SECOND_TIME,
		"Your global cooldown is %s sec shorter." % Stats.num(Balance.SPLIT_SECOND_GCD)), self)
	_ring_effect(1.0, col)
	_ring_effect(0.6, Color(0.95, 0.95, 1.0))

## Whiplash: an instant hit from afar, drawn as a line of lightning.
func _whiplash(w: Dictionary, res: Resource) -> void:
	var col := Abilities.color_of(WHIPLASH_ID)
	var from := _muzzle()
	LASH.spawn(get_tree().current_scene, from, target.global_position + Vector3(0, 0.3, 0), col)
	_net_fx("lash", from, target, {"c": col})
	_slash_effect(col)
	var away := Vector2(target.global_position.x - global_position.x, target.global_position.z - global_position.z).length()
	if deal_damage(target, _weapon_hit(w, res), WHIPLASH_ID) > 0 and whip_crack_applies(away):
		_whip_crack()   # Whip Crack: a long lash readies a cheaper Static Step

## Energy Faraday Guard pays for `spared` damage at `max_hp` max health.
static func faraday_energy(spared: float, max_hp: float) -> float:
	if max_hp <= 0.0 or Balance.FARADAY_GUARD_HEALTH_PCT <= 0.0:
		return 0.0
	return maxf(spared, 0.0) / max_hp * 100.0 / Balance.FARADAY_GUARD_HEALTH_PCT * Balance.FARADAY_GUARD_ENERGY

func _start_faraday_guard() -> void:
	var col := Abilities.color_of(FARADAY_ID)
	status.apply(_melee_buff(FARADAY_FX, FARADAY_ID, Balance.FARADAY_GUARD_TIME,
		"You take %s%% less damage; your Energy pays for it instead. Ends if you run out of Energy." % Stats.num(Balance.FARADAY_GUARD_PCT)), self)
	_ring_effect(1.4, col)
	_ring_effect(0.9, Color(0.95, 0.95, 1.0))

func _start_reflex_arc() -> void:
	var col := Abilities.color_of(REFLEX_ID)
	status.apply(_melee_buff(REFLEX_FX, REFLEX_ID, Balance.REFLEX_ARC_TIME,
		"The next melee attack against you is avoided, counting as both a parry and a block, and you strike back."), self)
	_slash_effect(col)
	_ring_effect(1.0, col)

## A hit on me is being worked out (_on_damage_modify). Reflex Arc turns the next
## melee attack into nothing (its effects too); Faraday Guard takes a share off
## every hit while I have Energy to pay for it (_melee_kit_hit_taken does the rest).
func _guard_incoming(info: RefCounted) -> void:
	if status == null:
		return
	if status.has(REFLEX_FX) and is_melee_attack(info.tags, bool(info.is_dot)):
		info.add_bonus(-AVOID_PCT, REFLEX_LABEL)
		info.effects = []
		info.force_parry_block = true   # it counts as a parry AND a block (CombatSystem.force_avoid)
		return
	if status.has(FARADAY_FX) and float(resources["energy"]) > 0.0:
		info.add_bonus(-Balance.FARADAY_GUARD_PCT, FARADAY_LABEL)

## Something hit me (_on_hit_taken): Reflex Arc's strike back, Faraday Guard's
## bill, Back-Current's zap.
func _melee_kit_hit_taken(info: RefCounted) -> void:
	var foe: Variant = info.source
	var foe_ok: bool = foe != null and is_instance_valid(foe) and foe is Node3D and foe.is_in_group("enemies") and foe.is_alive()
	# Reflex Arc: that attack did nothing. The strike back is the ability's own hit.
	if bonus_named(info.bonus_parts, REFLEX_LABEL) != 0.0:
		status.remove(REFLEX_FX)
		var col := Abilities.color_of(REFLEX_ID)   # (CombatSystem already showed "Parry")
		var w := _weapon()
		if foe_ok and w.get("weapon", "") == "melee":
			var at: Vector3 = foe.global_position
			deal_damage(foe, _weapon_hit(w, Abilities.get_resource(REFLEX_ID)), REFLEX_ID)
			_slash_effect(col)
			_ring_effect(0.7, col, at)
		return
	# Faraday Guard: what it spared me comes out of my Energy; at none it ends.
	var spared_pct := -bonus_named(info.bonus_parts, FARADAY_LABEL)
	if spared_pct > 0.0 and not info.blocked and int(info.amount) > 0:
		var spared := heat_sink_stored(float(info.amount), float(info.bonus_pct), spared_pct)
		resources["energy"] = maxf(float(resources["energy"]) - faraday_energy(spared, float(max_health)), 0.0)
		if float(resources["energy"]) <= 0.0:
			status.remove(FARADAY_FX)
	# Back-Current: a melee hit that landed gives Energy and zaps whoever dealt it.
	if status.has(BACK_CURRENT_FX) and not info.blocked and int(info.amount) > 0 \
			and is_melee_attack(info.tags, bool(info.is_dot)):
		_gain("energy", Balance.BACK_CURRENT_ENERGY)
		if foe_ok:
			deal_damage(foe, float(Abilities.get_resource(BACK_CURRENT_ID).damage), BACK_CURRENT_ID, true)

## Polar Strike (Rune of Polarity): the hit, then my charge flips. The charge
## empowers my next OTHER weapon ability; another Polar Strike only flips it.
func _polar_strike(w: Dictionary, res: Resource) -> void:
	deal_damage(target, _weapon_hit(w, res), POLAR_ID)
	_polar_positive = not _polar_positive
	var fx := _melee_buff(POLARITY_FX, POLAR_ID, Balance.POLARITY_TIME,
		"Your next weapon ability other than %s deals %s%% more damage." % [Abilities.ability_name(POLAR_ID), Stats.num(Balance.POLARITY_PCT)])
	fx.display_name = "Positive Charge" if _polar_positive else "Negative Charge"
	fx.color = Color(0.6, 0.9, 1.0) if _polar_positive else Color(1.0, 0.5, 0.4)
	status.remove(POLARITY_FX)   # (a fresh buff: its name and colour follow the charge)
	status.apply(fx, self)
	for i in 2:
		_slash_effect(fx.color)

# --- Lightning tank (a parry tank with a two-handed weapon) ---------------------------------
# Stormbreak gives Energy. Humming Blade raises my Parry and its cap, and makes
# every parry give Energy. A parry opens Return Stroke (one answer per parry).
# Shock Ring spends Energy for threat around me, Crossguard parries everything
# for a moment, and Draw the Storm pulls enemies onto me and makes my parries
# zap them. Numbers are in balance.gd.

const STORMBREAK_ID := "stormshield"   # (the id it had as Stormshield Slam)
const HUMMING_ID := "thunderaegis"     # (the id it had as Aegis of Thunder)
const HUMMING_FX := "humming_blade"
const RETURN_STROKE_ID := "returnstroke"
const RETURN_STROKE_FX := "return_stroke"
const SHOCK_RING_ID := "shockring"
const CROSSGUARD_ID := "crossguard"
const CROSSGUARD_FX := "crossguard"
const STORM_ID := "drawthestorm"
const STORM_FX := "draw_the_storm"
const COUNTER_CHARGE_LABEL := "Counter-Charge"

## Is a two-handed weapon in my Main Hand?
func has_two_hander() -> bool:
	return bool(_weapon().get("locks_offhand", false))

## The most Parry chance (%) that counts with these up: all of it during
## Crossguard, HUMMING_BLADE_PARRY_CAP with Humming Blade, the usual cap otherwise.
static func parry_cap_for(humming: bool, crossguard: bool) -> float:
	if crossguard:
		return 100.0
	return Balance.HUMMING_BLADE_PARRY_CAP if humming else Stats.MAX_PARRY

## My Parry cap right now (CombatSystem and the stat panel ask).
func parry_cap() -> float:
	return parry_cap_for(status != null and status.has(HUMMING_FX), status != null and status.has(CROSSGUARD_FX))

## Energy an attack I parry gives during Humming Blade, with Closed Circuit adding `more`.
static func parry_energy(more: float) -> float:
	return Balance.HUMMING_BLADE_ENERGY + maxf(more, 0.0)

## Seconds left of a cooldown of `left` once Quick Wrists takes `off` away for a parry.
static func quick_wrists_cooldown(left: float, off: float) -> float:
	return maxf(left - maxf(off, 0.0), 0.0)

func _start_humming_blade() -> void:
	var col := Abilities.color_of(HUMMING_ID)
	var fx := _melee_buff(HUMMING_FX, HUMMING_ID, Balance.HUMMING_BLADE_TIME,
		"+%s%% Parry, and your Parry cap is %s%%. Each attack you parry gives you Energy." % [
			Stats.num(Balance.HUMMING_BLADE_PARRY), Stats.num(Balance.HUMMING_BLADE_PARRY_CAP)])
	fx.stat_modifiers = {Stats.PARRY: Balance.HUMMING_BLADE_PARRY}
	status.apply(fx, self)
	_slash_effect(col)
	_ring_effect(1.2, col)

func _start_crossguard() -> void:
	var col := Abilities.color_of(CROSSGUARD_ID)
	var fx := _melee_buff(CROSSGUARD_FX, CROSSGUARD_ID, Balance.CROSSGUARD_TIME,
		"You parry every attack that can be parried.")
	fx.stat_modifiers = {Stats.PARRY: 100.0}   # (and parry_cap() lets all of it count)
	status.apply(fx, self)
	for i in 2:
		_slash_effect(col)
	_ring_effect(0.9, Color(0.95, 0.95, 1.0))

## Shock Ring: everything around me is hit; more than AOE_TARGET_CAP enemies
## share that many hits' damage.
func _shock_ring(res: Resource) -> void:
	var col := Abilities.color_of(SHOCK_RING_ID)
	var hit := _enemies_within(float(res.radius))
	var coef := float(res.damage) * Balance.aoe_share(hit.size())
	for e in hit:
		if is_instance_valid(e) and e.is_alive():
			deal_damage(e, coef, SHOCK_RING_ID)
	_ring_effect(float(res.radius), col)
	_ring_effect(float(res.radius) * 0.6, Color(0.95, 0.95, 1.0))

## Draw the Storm: every enemy around me has to attack me for a moment, and
## for as long as it lasts my parries zap the enemies around me (_storm_zap).
func _draw_the_storm(res: Resource) -> void:
	var col := Abilities.color_of(STORM_ID)
	status.apply(_melee_buff(STORM_FX, STORM_ID, Balance.DRAW_THE_STORM_TIME,
		"Each attack you parry zaps the enemies around you."), self)
	for e in _enemies_within(float(res.radius)):
		_net_taunt(e, Balance.DRAW_THE_STORM_TAUNT)
		_ring_effect(0.8, Color(1.0, 0.35, 0.25), e.global_position)
	_ring_effect(float(res.radius), col)
	_ring_effect(1.0, Color(0.95, 0.95, 1.0))

## The zap a parry sends out during Draw the Storm (a proc: it feeds nothing else).
func _storm_zap() -> void:
	var hit := _enemies_within(Balance.DRAW_THE_STORM_ZAP_RADIUS)
	var coef := float(Abilities.EXTRA_HITS[STORM_ID]) * Balance.aoe_share(hit.size())
	for e in hit:
		if is_instance_valid(e) and e.is_alive():
			deal_damage(e, coef, STORM_ID, true)
	_ring_effect(Balance.DRAW_THE_STORM_ZAP_RADIUS, Abilities.color_of(STORM_ID))

## Something hit me (_on_hit_taken): an attack I parried opens Return Stroke,
## gives Energy during Humming Blade, brings Crossguard back sooner (Quick
## Wrists) and zaps the enemies around me during Draw the Storm.
func _parry_kit_hit_taken(info: RefCounted) -> void:
	if not info.parried:
		return
	var pd := get_node_or_null("/root/PlayerData")
	if pd and pd.has_ability(RETURN_STROKE_ID):
		status.apply(_melee_buff(RETURN_STROKE_FX, RETURN_STROKE_ID, Balance.RETURN_STROKE_WINDOW,
			"You parried an attack: %s can be used once." % Abilities.ability_name(RETURN_STROKE_ID)), self)
	if status.has(HUMMING_FX):
		_gain("energy", parry_energy(_talent("lightning_closed_circuit")))   # + Closed Circuit
	var wrists := _talent("lightning_quick_wrists")
	if wrists > 0.0 and cooldowns.has(CROSSGUARD_ID):
		cooldowns[CROSSGUARD_ID] = quick_wrists_cooldown(float(cooldowns[CROSSGUARD_ID]), wrists)
	if status.has(STORM_FX):
		_storm_zap()
	# Earth Return: every parry heals me a little.
	var mend := earth_return_heal(max_health, _talent("lightning_earth_return"))
	if mend > 0 and health < max_health:
		_combat().heal(self, self, float(mend), "earth_return", true)
	# Tempo: every parry makes my auto-attacks faster for a while (it stacks).
	var tempo := _talent("lightning_tempo")
	if tempo > 0.0:
		status.apply(_tempo_buff(tempo), self)

const REEL_IN_ID := "reelin"
const RECHARGE_ID := "recharge"
const RESONANCE_RUNE := "resonance"
const TEMPO_FX := "tempo"
## Stat key of attack speed buffs: % faster auto-attacks (Tempo). Not Haste: casts
## and the global cooldown are untouched.
const ATTACK_SPEED := "attack_speed"
var _tempo_fx: Resource

## Where Reel In drags an enemy at `foe` to: `gap` metres from `me` on the line
## between us (it stays where it is if it is already that close). Flat: the
## caller sets the height.
static func reel_in_point(me: Vector3, foe: Vector3, gap: float) -> Vector3:
	var flat := Vector3(foe.x - me.x, 0.0, foe.z - me.z)
	var dist := flat.length()
	if dist <= gap or dist < 0.001:
		return foe
	var p := me + flat / dist * gap
	p.y = foe.y
	return p

## Reel In: a lash drags my target to me (the host moves it) and it has to
## attack me for a moment. Bosses are only made to attack.
func _reel_in() -> void:
	var col := Abilities.color_of(REEL_IN_ID)
	var from := _muzzle()
	LASH.spawn(get_tree().current_scene, from, target.global_position + Vector3(0, 0.3, 0), col, 0.4)
	_net_fx("lash", from, target, {"c": col})
	var gap := Combat.hitbox_radius(target) + Combat.hitbox_radius(self) + Balance.REEL_IN_GAP
	var to := reel_in_point(global_position, target.global_position, gap)
	to.y = target.global_position.y + (Combat.feet_y(self) - Combat.feet_y(target))   # onto my level
	var net := _net()
	if net:
		net.pull(target, self, to, Balance.REEL_IN_TAUNT)
	elif target.has_method("pull_to"):
		target.pull_to(self, to, Balance.REEL_IN_TAUNT, Balance.REEL_IN_DRAG_TIME)
	else:
		_net_taunt(target, Balance.REEL_IN_TAUNT)
	_slash_effect(col)
	_ring_effect(0.8, Color(1.0, 0.35, 0.25), target.global_position)

## Health a Recharge that spent `energy` restores to a character with `max_hp`.
static func recharge_heal(max_hp: int, energy: float) -> int:
	return int(round(float(max_hp) * Balance.RECHARGE_PCT_PER_STEP / 100.0 * maxf(energy, 0.0) / Balance.ENERGY_STEP))

## Recharge: all my Energy becomes health.
func _recharge() -> void:
	var spent := _spend_all_energy()
	var amount := recharge_heal(max_health, spent)
	if amount > 0:
		_combat().heal(self, self, float(amount), RECHARGE_ID, true)
	_ring_effect(1.2, Color(0.45, 1.0, 0.5))
	_ring_effect(0.8, Abilities.color_of(RECHARGE_ID))

## Energy Return Stroke costs: `base` after a parry (`answered`), RESONANCE_COST
## when the Rune of Resonance lets it be used without one.
static func return_stroke_cost(base: float, answered: bool, resonance: bool) -> float:
	return Balance.RESONANCE_COST if (resonance and not answered) else base

## Can Return Stroke be used: after a parry, or any time with the Rune of Resonance.
static func return_stroke_usable(answered: bool, resonance: bool) -> bool:
	return answered or resonance

## % faster my auto-attacks are from attack speed buffs (Tempo).
func attack_speed_bonus() -> float:
	return status.stat_mod(ATTACK_SPEED) if status != null else 0.0

## Tempo's buff at `pct` % attack speed per stack (rebuilt when the talent's rank changes).
func _tempo_buff(pct: float) -> Resource:
	if _tempo_fx == null or not is_equal_approx(float(_tempo_fx.stat_modifiers.get(ATTACK_SPEED, 0.0)), pct):
		_tempo_fx = StatusContainer.make_buff(TEMPO_FX, "Tempo", ATTACK_SPEED, pct,
			Balance.TEMPO_TIME, Balance.TEMPO_MAX_STACKS, Abilities.color_of(HUMMING_ID))
		_tempo_fx.tags = PackedStringArray(["Lightning"])
		_tempo_fx.description = "Your auto-attacks are %s%% faster per stack." % Stats.num(pct)
	return _tempo_fx

# --- Rune of Overload (Epic): Static, Overload and Grounded -------------------------------
# With the rune on my gear, my Lightning spells and abilities build Static (own
# only): more Lightning damage per stack. Building it at the cap is an Overload:
# every stack discharges as a weak burst around me, and no Static can be built
# for a few seconds. A short break from Lightning makes me Grounded: no Overload
# for the next stretch of Lightning casts. So the rhythm is Lightning for
# OVERLOAD_GROUND_TIME, something else for OVERLOAD_GROUND_AFTER, and the stacks
# are kept. The numbers are in balance.gd and the rune's own data.

const OVERLOAD_RUNE := "overload"
const STATIC_ID := "static"
const OVERLOADED_ID := "overloaded"
const GROUNDED_ID := "grounded"
const OVERLOAD_COLOR := Color(0.45, 0.55, 1.0)
var _static_fx: Resource
var _overloaded_fx: Resource
var _grounded_fx: Resource
var _static_last := ""   # "<ability>@<frame>" of the last cast that built Static
var _lightning_cast_at := -1000.0   # seconds: when I last started or finished a Lightning spell / ability
var _ground_check_at := 0.0

## Has a break from Lightning been long enough to be Grounded?
static func grounds(idle_seconds: float) -> bool:
	return idle_seconds >= Balance.OVERLOAD_GROUND_AFTER

## Does building Static and ending up at `stacks` Overload me?
static func overloads(stacks: int, grounded: bool) -> bool:
	return stacks >= Balance.STATIC_MAX_STACKS and not grounded

## Grounded: no Overload while it lasts.
static func make_grounded_fx() -> Resource:
	var fx := StatusContainer.make_buff(GROUNDED_ID, "Grounded", GROUNDED_ID, 0.0,
		Balance.OVERLOAD_GROUND_TIME, 1, Color(0.7, 0.8, 1.0))
	fx.stat_modifiers = {}
	fx.description = "You cannot Overload."
	return fx

func _ground() -> void:
	if _grounded_fx == null:
		_grounded_fx = make_grounded_fx()
	status.apply(_grounded_fx, self)

## A spell or ability of mine started or went off. A Lightning one ends the
## break; coming back after a long enough one, Grounded runs its full time from here.
func _on_cast_for_static(id: String, _duration: float = 0.0) -> void:
	if not Abilities.tags_of(id).has("Lightning"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if status and _has_rune(OVERLOAD_RUNE) and grounds(now - _lightning_cast_at):
		_ground()
	_lightning_cast_at = now

## Twice a second: Grounded is kept up for as long as I stay off Lightning.
func _tick_grounded() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _ground_check_at:
		return
	_ground_check_at = now + 0.5
	if status == null or not _has_rune(OVERLOAD_RUNE):
		return
	if casting and Abilities.tags_of(current_spell).has("Lightning"):
		_lightning_cast_at = now   # a long Lightning cast or channel is not a break
		return
	if grounds(now - _lightning_cast_at):
		_ground()

func static_stacks() -> int:
	return int(status.stacks_of(STATIC_ID)) if status else 0

## Does a hit of mine build Static? Lightning spells and abilities that do damage;
## never procs (chain jumps, runes) or damage-over-time ticks.
static func builds_static(damage_type: String, tags: PackedStringArray, is_proc: bool, is_dot: bool, amount: int) -> bool:
	if is_proc or is_dot or amount <= 0:
		return false
	if damage_type != "lightning" and not tags.has("Lightning"):
		return false
	return tags.has("Spell") or tags.has("Ability")

## Damage coefficient of an Overload discharging `stacks` Static.
static func overload_coef(stacks: int, per_stack: float) -> float:
	return per_stack * maxi(stacks, 0)

## The Static buff: a stacking % bonus to all Lightning damage I deal.
static func make_static_fx() -> Resource:
	var fx := StatusContainer.make_buff(STATIC_ID, "Static", STATIC_ID, 0.0,
		Balance.STATIC_TIME, Balance.STATIC_MAX_STACKS, OVERLOAD_COLOR)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Lightning"])
	fx.damage_mod_pct = Balance.STATIC_DAMAGE_PCT
	fx.mod_damage_types = PackedStringArray(["lightning"])
	fx.mod_affects_dots = true
	fx.description = "You deal %s%% more Lightning damage per stack. Building it at %d stacks makes you Overload unless you are Grounded. All Static is lost after %s sec without gaining a stack." % [
		Stats.num(Balance.STATIC_DAMAGE_PCT), Balance.STATIC_MAX_STACKS, Stats.num(Balance.STATIC_TIME)]
	return fx

## The lockout after an Overload.
static func make_overloaded_fx() -> Resource:
	var fx := StatusContainer.make_buff(OVERLOADED_ID, "Overloaded", OVERLOADED_ID, 0.0,
		Balance.OVERLOAD_LOCKOUT, 1, OVERLOAD_COLOR.darkened(0.35))
	fx.stat_modifiers = {}
	fx.is_debuff = true
	fx.description = "You cannot build Static."
	return fx

## A hit of mine landed: a Lightning spell or ability builds one Static per cast
## (an AoE hitting five enemies is still one). Ending up at the cap Overloads,
## unless I am Grounded (then the stacks just stay at the cap).
func _static_on_hit(info: RefCounted, tags: PackedStringArray) -> void:
	if not _has_rune(OVERLOAD_RUNE) or status.has(OVERLOADED_ID):
		return
	if not builds_static(str(info.damage_type), tags, bool(info.is_proc), bool(info.is_dot), int(info.amount)):
		return
	var key := "%s@%d" % [str(info.ability_id), Engine.get_process_frames()]
	if key == _static_last:
		return   # the same cast hitting another enemy
	_static_last = key
	if _static_fx == null:
		_static_fx = make_static_fx()
	status.apply(_static_fx, self)
	if overloads(static_stacks(), status.has(GROUNDED_ID)):
		_overload()

## Every stack of Static discharges around me, then the lockout starts.
func _overload() -> void:
	var stacks := static_stacks()
	if stacks <= 0:
		return
	status.remove(STATIC_ID)
	if _overloaded_fx == null:
		_overloaded_fx = make_overloaded_fx()
	status.apply(_overloaded_fx, self)
	var rune := Runes.get_resource(OVERLOAD_RUNE)
	if rune == null:
		return
	var radius := float(rune.radius)
	var hit := _enemies_within(radius)
	var coef := overload_coef(stacks, float(rune.effect_amount)) * Balance.aoe_share(hit.size())
	for e in hit:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		# (A proc with its own line on the meter: it builds and spends nothing.)
		var info := DamageInfo.make(self, e, coef, OVERLOAD_RUNE)
		info.tags = rune.effect_tags
		info.damage_type = str(rune.damage_type)
		info.is_proc = true
		info.no_empower = true
		_combat().deal(info)
	_ring_effect(radius, OVERLOAD_COLOR)

# --- Shadow melee: the Hounds ---------------------------------------------------------------
# Two demon dogs that fight beside me, on Rage. With none out, my next Shadow
# melee ability (HOUND_CALLERS) calls them up through the ground for HOUND_TIME
# seconds. They always bite the last enemy I damaged directly: every hit of a
# spell, an ability or an auto attack sends them to its enemy (no tick, no proc).
# They have no stats: each of their hits is mine (my level, Attack / Spell
# Power, crit, damage bonuses, Lifesteal and threat), dealt as a proc under its
# own name (Hound Bite, Hound Lunge, Drag Down). So runes and "on hit" talents
# do not fire off them, they spend no "your next ..." buff and feed no Breach
# (but for the talent Out of the Hole). Haste makes them bite faster. Enemies
# cannot target them. Sent at prey more than a second's run away, they dash.
# Sic and Open Up build Rage; whatever spends Rage Rouses them (their bites hit
# harder for ROUSED_TIME; it does not stack). Open Up marks its target (the Laid
# Open debuff, own only): bites on it hit harder. Both At Once makes each of
# them lunge. Run Them Down lets their bites reach other enemies. Guard Dogs: I
# take less damage. Off the Chain: faster bites, and the pair stays that much
# longer.
# When their time is up each drags at its prey once (Drag Down), and my next
# Shadow melee ability calls a new pair. Bring It Down sends them under early,
# with the same Drag Down. Dying or going down sends them away without it.
# The dogs themselves are scripts/hound.gd (only a picture); the party sees
# them through the "hounds" fx. Numbers: balance.gd (HOUND_*, ROUSED_*, ...).
# Talents (talents.gd, the two edges of the Shadow book):
#   Lean and Hungry   faster bites                  hound_bite_interval
#   Fed               a bite that crits gives Rage  _hound_bite
#   Worked Up         Roused lasts longer           Abilities.effect_time_bonus;
#                     capstone: bites crit more while Roused (adjust_crit)
#   Out of the Hole   bites add to my open Breach   _hound_bite
#   Long Night        the pair stays longer         hound_time
#   Take It With You  Drag Down hits harder         hound_hit_bonuses; capstone:
#                     its kill makes the next pair arrive Roused (_on_enemy_died_shadow)
#   Pack Leader       every Hound hit is bigger     hound_hit_bonuses
#   Still Wet         Open Up's mark lasts longer   Abilities.effect_time_bonus;
#                     capstone: my own direct hits on it too (_shadow_talents_modify)
#   Pincer            lunges hit harder             hound_hit_bonuses; capstone:
#                     a lunge that crits gives Rage back (_hounds_lunge)
#   Again             Both At Once may reset        _use_drafted
#   Stand Over        bites heal me in Guard Dogs   _hound_bite
#   Slipped Leash     Off the Chain lasts longer    Abilities.effect_time_bonus;
#                     capstone: a third Hound for as long (_add_third_hound)
#   Share the Kill    Leeching Strike heals more    _on_hit_extra
# (Thick Blood and Feeding Frenzy are open talents: _tick_resources,
# _on_enemy_died_shadow.)

const HOUND = preload("res://scripts/hound.gd")
const SIC_ID := "sic"
const OPEN_UP_ID := "openup"
const BOTH_AT_ONCE_ID := "bothatonce"
const RUN_DOWN_ID := "runthemdown"
const GUARD_DOGS_ID := "guarddogs"
const OFF_THE_CHAIN_ID := "offthechain"
const LEECHING_STRIKE_ID := "shadowstrike"
const BRING_DOWN_ID := "bringitdown"
const BRING_DOWN_NO_HOUNDS := "You have no Hounds out"
const BRING_DOWN_NO_PREY := "Your Hounds have nothing to drag down"
## The Shadow melee abilities: using one with no Hounds out calls them.
const HOUND_CALLERS := [SIC_ID, OPEN_UP_ID, BOTH_AT_ONCE_ID, RUN_DOWN_ID, GUARD_DOGS_ID, OFF_THE_CHAIN_ID, LEECHING_STRIKE_ID]
const HOUNDS_FX := "hounds"
const ROUSED_FX := "roused"
const RUN_DOWN_FX := "run_them_down"
const GUARD_DOGS_FX := "guard_dogs"
const OFF_THE_CHAIN_FX := "off_the_chain"
const LAID_OPEN_FX := "laid_open"            # Open Up's mark on an enemy (data/effects/laid_open.tres)
## Their hits in the log and on the damage meter (Details.HIT_NAMES).
const HOUND_BITE_ID := "hound_bite"
const HOUND_LUNGE_ID := "hound_lunge"
const HOUND_DRAG_ID := "hound_drag"
## Stand Over's heal on the healing meter.
const STAND_OVER_ID := "stand_over"
## What Roused and Open Up's mark add to a bite: each is a line of its own on the meter.
const ROUSED_LABEL := "Roused"
const LAID_OPEN_LABEL := "Laid Open"
## ... and what the talents add to the Hounds' hits and to mine.
const PACK_LEADER_LABEL := "Pack Leader"
const PINCER_LABEL := "Pincer"
const TAKE_IT_LABEL := "Take It With You"
const STILL_WET_LABEL := "Still Wet"
## Worked Up's capstone: the extra crit chance a bite carries (adjust_crit reads it).
const HOUND_CRIT_META := "hound_crit"
const FEEDING_FRENZY_FX := "feeding_frenzy"
## A Hound's hit scales like an ability of mine.
const HOUND_TAGS := ["Shadow", "Ability", "Hound"]
const HOUND_COLOR := Color(0.8, 0.16, 0.3)
## Seconds between reminders to the party of where my Hounds are.
const HOUND_RETELL := 5.0

var _hounds_until := 0.0        # seconds: when my Hounds' time is up (0 = none out)
var _hound_prey: Node3D         # the enemy they are on (null = at heel)
var _hound_prey_frame := -1     # the frame a hit of mine last sent them somewhere
var _hound_bite_at: Array = []  # for each Hound: when its next bite lands
var _hound_nodes: Array = []    # their pictures (scripts/hound.gd)
var _hounds_told := 0.0
var _roused_fx: Resource
var _hound_crit := false        # did the Hound hit dealt last critically strike?
var _hounds_roused_next := false   # Take It With You's capstone: the next pair arrives Roused
var _drag_watch := {}           # enemy instance id -> time until which its death is Drag Down's kill

## Does using ability `id` call the Hounds when none are out?
static func calls_hounds(id: String) -> bool:
	return HOUND_CALLERS.has(id)

## Does spending `cost` of resource `res` Rouse my Hounds? Anything that costs Rage.
static func rouses(res: String, cost: float) -> bool:
	return res == "rage" and cost > 0.0

## Seconds between one Hound's bites (`haste` = my haste multiplier, `unchained`
## = Off the Chain, `faster_pct` = Lean and Hungry). The three multiply.
static func hound_bite_interval(haste: float, unchained: bool, faster_pct: float = 0.0) -> float:
	var speed := maxf(haste, 0.1) * ((1.0 + Balance.OFF_THE_CHAIN_SPEED_PCT / 100.0) if unchained else 1.0) \
		* (1.0 + maxf(faster_pct, 0.0) / 100.0)
	return maxf(Balance.HOUND_BITE_EVERY / speed, 0.2)

## Seconds a pair stays (`longer` = Long Night).
static func hound_time(longer: float = 0.0) -> float:
	return Balance.HOUND_TIME + maxf(longer, 0.0)

## Seconds Off the Chain lasts, and how much longer the Hounds stay for it (`longer` = Slipped Leash).
static func off_the_chain_time(longer: float = 0.0) -> float:
	return Balance.OFF_THE_CHAIN_TIME + maxf(longer, 0.0)

## What the talents add to a Hound's hit `id`, as [percent, label] rows: Pack
## Leader to every one, Pincer to a lunge, Take It With You to Drag Down.
static func hound_hit_bonuses(id: String, pack_pct: float, pincer_pct: float, drag_pct: float) -> Array:
	var out: Array = []
	if pack_pct > 0.0:
		out.append([pack_pct, PACK_LEADER_LABEL])
	if id == HOUND_LUNGE_ID and pincer_pct > 0.0:
		out.append([pincer_pct, PINCER_LABEL])
	if id == HOUND_DRAG_ID and drag_pct > 0.0:
		out.append([drag_pct, TAKE_IT_LABEL])
	return out

## Worked Up's capstone: the crit chance a bite gets on top while my Hounds are Roused.
static func worked_up_crit(roused: bool, capstone: bool) -> float:
	return Balance.WORKED_UP_CRIT if roused and capstone else 0.0

## Out of the Hole: what a bite of `dealt` adds to my open Breach under the enemy bitten.
static func hole_feed(dealt: int, pct: float) -> float:
	return maxf(float(dealt), 0.0) * maxf(pct, 0.0) / 100.0

## Stand Over: health a bite gives me back during Guard Dogs (`pct` % of my maximum).
static func stand_over_heal(max_hp: int, pct: float) -> int:
	return int(round(maxf(float(max_hp), 0.0) * maxf(pct, 0.0) / 100.0))

## Share the Kill: how many times as big Leeching Strike's heal is.
static func leech_heal_mult(hounds_are_out: bool, pct: float) -> float:
	return 1.0 + maxf(pct, 0.0) / 100.0 if hounds_are_out else 1.0

## Thick Blood: Rage lost per second, `slower_pct` % slower than `base`.
static func rage_decay(base: float, slower_pct: float) -> float:
	return base * clampf(1.0 - slower_pct / 100.0, 0.0, 1.0)

## Again: does Both At Once come off cooldown? `roll` = 0-100.
static func again_resets(roll: float, chance: float) -> bool:
	return chance > 0.0 and roll < chance

## Still Wet's capstone: does a hit of mine get its bonus? A direct hit of my
## own (no tick, no proc: never a Hound's) on an enemy carrying my Laid Open.
static func still_wet_applies(capstone: bool, mark_is_mine: bool, is_proc: bool, is_dot: bool) -> bool:
	return capstone and mark_is_mine and not is_proc and not is_dot

## Take It With You's capstone: was an enemy's death Drag Down's kill? It died
## by my hand while `watched_until` (set as Drag Down hit it) had not passed.
static func drag_kill_counts(now: float, watched_until: float, killed_by_me: bool) -> bool:
	return killed_by_me and watched_until > 0.0 and now <= watched_until

## Why Bring It Down cannot be used ("" = it can).
static func bring_down_error(hounds_are_out: bool, has_prey: bool) -> String:
	if not hounds_are_out:
		return BRING_DOWN_NO_HOUNDS
	return "" if has_prey else BRING_DOWN_NO_PREY

## What a bite gets on top, as [percent, label] rows: Roused, and Open Up's mark on the enemy bitten.
static func hound_bite_bonuses(roused: bool, laid_open: bool) -> Array:
	var out: Array = []
	if roused:
		out.append([Balance.ROUSED_PCT, ROUSED_LABEL])
	if laid_open:
		out.append([Balance.LAID_OPEN_PCT, LAID_OPEN_LABEL])
	return out

## Does a hit of mine set my Hounds on its enemy? Every direct hit that landed
## does (a spell, an ability, an auto attack): never a damage over time tick,
## and never a proc (their own bites, chain jumps, rune hits).
static func sets_prey(is_proc: bool, is_dot: bool, amount: int) -> bool:
	return not is_proc and not is_dot and amount > 0

## One spell or ability of mine hits several enemies at the same moment
## (`same_cast`), so none of them is the last: do my Hounds stay on the one they
## were just sent to? Only if that one is my target.
static func keeps_prey(same_cast: bool, prey_is_my_target: bool) -> bool:
	return same_cast and prey_is_my_target

## Damage each other enemy takes from a bite of `amount` during Run Them Down.
static func run_down_amount(amount: int) -> int:
	return int(round(maxf(float(amount), 0.0) * Balance.RUN_DOWN_PCT / 100.0))

## How many other enemies each bite hits during Run Them Down (`extra` = Wide Pack's).
static func run_down_targets(extra: float = 0.0) -> int:
	return Balance.RUN_DOWN_TARGETS + int(round(maxf(extra, 0.0)))

## When my Hounds' time is up once Off the Chain is used at `now`: they stay as
## long again as it lasts (their time stands still meanwhile). `time` = seconds
## it lasts (off_the_chain_time).
static func hounds_until_unchained(until: float, now: float, time: float = Balance.OFF_THE_CHAIN_TIME) -> float:
	return maxf(until, now) + time

## My Hounds are gone: was their time up (so each drags at its prey), or were
## they sent away early (I died, or went down)?
static func hounds_time_up(now: float, until: float) -> bool:
	return until > 0.0 and now >= until - 0.25

## The buff that shows my Hounds and the time they have left.
static func make_hounds_fx() -> Resource:
	var fx := StatusContainer.make_buff(HOUNDS_FX, "Hounds", HOUNDS_FX, 0.0, Balance.HOUND_TIME, 1, HOUND_COLOR)
	fx.stat_modifiers = {}
	fx.stack_mode = 2   # IGNORE: nothing renews them
	fx.tags = PackedStringArray(["Shadow"])
	fx.description = "Two Hounds fight beside you and bite the last enemy you damaged directly. When their time is up, each drags at its prey."
	return fx

## Roused: my Hounds' bites hit harder (the bonus itself is added in _hound_bite).
static func make_roused_fx() -> Resource:
	var fx := StatusContainer.make_buff(ROUSED_FX, ROUSED_LABEL, ROUSED_FX, 0.0, Balance.ROUSED_TIME, 1, HOUND_COLOR.lightened(0.25))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Shadow"])
	fx.description = "The bites of your Hounds deal %s%% more damage." % Stats.num(Balance.ROUSED_PCT)
	return fx

static func make_run_down_fx(targets: int = Balance.RUN_DOWN_TARGETS) -> Resource:
	var fx := StatusContainer.make_buff(RUN_DOWN_FX, Abilities.ability_name(RUN_DOWN_ID), RUN_DOWN_FX, 0.0,
		Balance.RUN_DOWN_TIME, 1, HOUND_COLOR)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Shadow"])
	fx.description = "Each bite of your Hounds also hits up to %d other enemies near the one bitten, for %s%% of its damage." % [
		targets, Stats.num(Balance.RUN_DOWN_PCT)]
	return fx

## Guard Dogs: less damage taken, of every kind (hits and damage over time).
static func make_guard_dogs_fx() -> Resource:
	var fx := StatusContainer.make_buff(GUARD_DOGS_FX, Abilities.ability_name(GUARD_DOGS_ID), GUARD_DOGS_FX, 0.0,
		Balance.GUARD_DOGS_TIME, 1, HOUND_COLOR.darkened(0.15))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Shadow", "Defensive"])
	fx.damage_mod_pct = -Balance.GUARD_DOGS_PCT
	fx.modifies_incoming = true
	fx.mod_affects_dots = true
	fx.description = "You take %s%% less damage." % Stats.num(Balance.GUARD_DOGS_PCT)
	return fx

static func make_off_the_chain_fx() -> Resource:
	var fx := StatusContainer.make_buff(OFF_THE_CHAIN_FX, Abilities.ability_name(OFF_THE_CHAIN_ID), OFF_THE_CHAIN_FX, 0.0,
		Balance.OFF_THE_CHAIN_TIME, 1, HOUND_COLOR.lightened(0.1))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Shadow"])
	fx.description = "Your Hounds bite %s%% faster." % Stats.num(Balance.OFF_THE_CHAIN_SPEED_PCT)
	return fx

func _hound_now() -> float:
	return Time.get_ticks_msec() / 1000.0

## Are my Hounds out?
func hounds_out() -> bool:
	return _hounds_until > 0.0 and status != null and status.has(HOUNDS_FX)

## Can my Hounds be on `foe`? Alive, and within their leash of me.
func _prey_ok(foe: Variant) -> bool:   # untyped: may be a freed enemy
	return foe != null and is_instance_valid(foe) and foe is Node3D and foe.is_alive() \
		and _flat_dist_to((foe as Node3D).global_position) <= Balance.HOUND_LEASH

## An ability of mine went off (_use_drafted, once it was paid for). A Shadow
## melee ability calls the Hounds if none are out; one that cost Rage Rouses
## them (the pair it just called too).
func _hounds_on_ability(id: String) -> void:
	if status == null:
		return
	# (A pair whose time ran out since the last frame goes first, so it still
	# drags at its prey before the next one is called.)
	if _hounds_until > 0.0 and not status.has(HOUNDS_FX):
		_hounds_gone(hounds_time_up(_hound_now(), _hounds_until))
	if calls_hounds(id) and not hounds_out():
		var res := Abilities.get_resource(id)
		# (They come up at what I am about to strike; with nothing to strike, at heel.)
		_call_hounds(target if res != null and res.requires_target and _has_valid_target() else null)
	if rouses(Abilities.resource_of(id), float(Abilities.cost_of(id))):
		_rouse_hounds()

func _call_hounds(at_prey: Node3D) -> void:
	var time := hound_time(_talent("shadow_long_night"))   # Long Night
	status.apply(make_hounds_fx(), self)
	status.set_remaining(HOUNDS_FX, time)   # exactly that long (Overtime does not stretch it)
	var now := _hound_now()
	_hounds_until = now + time
	_hound_prey = at_prey if _prey_ok(at_prey) else null
	# Their first bites come once they are out of the ground, and never both at once.
	var every := _hound_bite_every()
	_hound_bite_at = []
	for i in Balance.HOUND_COUNT:
		_hound_bite_at.append(now + HOUND.RISE_TIME + every * (0.15 + float(i) / Balance.HOUND_COUNT))
	_drop_hound_nodes(false)
	_hound_nodes = HOUND.call_pair(get_tree().current_scene, self, _hound_prey, time, false)
	# Take It With You's capstone: the last Drag Down killed, so this pair arrives Roused.
	if _hounds_roused_next:
		_hounds_roused_next = false
		_rouse_hounds()
	# Slipped Leash's capstone: called while Off the Chain is still up, the third comes with them.
	if status.has(OFF_THE_CHAIN_FX) and _capstone("shadow_slipped_leash"):
		_add_third_hound()
	_tell_hounds()

## Seconds between one Hound's bites right now (Haste, Off the Chain, Lean and Hungry).
func _hound_bite_every() -> float:
	return hound_bite_interval(haste_mult(), status != null and status.has(OFF_THE_CHAIN_FX), _talent("shadow_lean_and_hungry"))

## I spent Rage (_pay, _hounds_on_ability): my Hounds are Roused.
func _rouse_hounds() -> void:
	if not hounds_out():
		return
	if _roused_fx == null:
		_roused_fx = make_roused_fx()
	status.apply(_roused_fx, self)

## A hit of mine landed (_on_damage_dealt_shadow, which sees every one): my
## Hounds always go for the last enemy I damaged directly (sets_prey). Of the
## enemies one cast hits at once, my target is the one they take (keeps_prey).
func _hounds_on_hit(info: RefCounted) -> void:
	if _hounds_until <= 0.0:
		return
	var foe: Variant = info.target
	if is_same(foe, self) or not _prey_ok(foe):
		return
	if not sets_prey(bool(info.is_proc), bool(info.is_dot), int(info.amount)):
		return
	var frame := Engine.get_process_frames()
	if not is_same(foe, target) and keeps_prey(frame == _hound_prey_frame, _prey_ok(_hound_prey) and is_same(_hound_prey, target)):
		return
	_hound_prey_frame = frame
	_set_hound_prey(foe)

## Send my Hounds at `foe` (null = back to heel). A bite waits until they are there.
func _set_hound_prey(foe: Variant) -> void:
	var to: Node3D = foe as Node3D if _prey_ok(foe) else null
	if is_same(to, _hound_prey):
		return   # they are on it already (or at heel already)
	_hound_prey = to
	var now := _hound_now()
	for i in _hound_bite_at.size():
		var from := global_position
		if i < _hound_nodes.size() and is_instance_valid(_hound_nodes[i]):
			var node := _hound_nodes[i] as Node3D
			from = node.global_position
			node.set_prey(to)
		if to != null:
			_hound_bite_at[i] = maxf(float(_hound_bite_at[i]), now + HOUND.travel_time(from, to.global_position))
	_tell_hounds()

## Every frame: my Hounds bite, and leave when their time is up.
func _tick_hounds() -> void:
	if _hounds_until <= 0.0:
		return
	var now := _hound_now()
	if status == null or not status.has(HOUNDS_FX):
		_hounds_gone(hounds_time_up(now, _hounds_until))
		return
	if _hound_prey != null and not _prey_ok(_hound_prey):
		_set_hound_prey(null)   # it died, or is out of their reach: back to heel
	# Slipped Leash's third Hound goes when Off the Chain is over.
	if _hound_bite_at.size() > Balance.HOUND_COUNT and not status.has(OFF_THE_CHAIN_FX):
		_third_hound_gone()
	if _hound_prey != null:
		var every := _hound_bite_every()
		for i in _hound_bite_at.size():
			# (More Haste, or Off the Chain, since this bite was set: it comes sooner.)
			_hound_bite_at[i] = minf(float(_hound_bite_at[i]), now + every)
			if now < float(_hound_bite_at[i]):
				continue
			_hound_bite_at[i] = now + every
			_hound_bite(i)
			if not _prey_ok(_hound_prey):
				break
	if now - _hounds_told >= HOUND_RETELL:
		_tell_hounds()

## Hound number `i` bites their prey. Run Them Down: the bite reaches other enemies too.
func _hound_bite(i: int) -> void:
	var foe: Node3D = _hound_prey
	var st: Node = foe.get_node_or_null("Status")
	var roused: bool = status.has(ROUSED_FX)
	var dealt := _hound_hit(foe, Balance.HOUND_BITE, HOUND_BITE_ID,
		hound_bite_bonuses(roused, st != null and st.has_from(LAID_OPEN_FX, self)),
		worked_up_crit(roused, _capstone("shadow_worked_up")))
	if i < _hound_nodes.size() and is_instance_valid(_hound_nodes[i]):
		_hound_nodes[i].bite()
	if dealt <= 0:
		return
	# Fed: a bite that critically strikes gives me Rage.
	if _hound_crit:
		_gain("rage", _talent("shadow_fed"))
	# Out of the Hole: part of the bite is added to my open Breach under the enemy.
	var hole := _talent("shadow_out_of_the_hole")
	if hole > 0.0:
		_decay_feed(foe, hole_feed(dealt, hole))
	# Stand Over: during Guard Dogs every bite gives me health back.
	var stand := _talent("shadow_stand_over")
	if stand > 0.0 and status.has(GUARD_DOGS_FX):
		_combat().heal(self, self, float(stand_over_heal(max_health, stand)), STAND_OVER_ID, true)
	if not status.has(RUN_DOWN_FX):
		return
	# An exact share of the bite (its crit and every bonus are already in it),
	# under Run Them Down's own name.
	var share := run_down_amount(dealt)
	var others := 0
	var most := run_down_targets(_talent("shadow_wide_pack"))   # Wide Pack: more of them
	for e in _enemies_near(foe.global_position, Balance.RUN_DOWN_REACH, foe):
		if others >= most:
			break
		_exact_hit(e, share, RUN_DOWN_ID, "shadow", PackedStringArray(HOUND_TAGS))
		others += 1

## One hit of a Hound's on `foe`: mine in everything (my level, power, crit,
## damage bonuses, threat), a proc under its own name. `bonuses` = [percent,
## label] rows added to it (what my talents add to it comes on top:
## hound_hit_bonuses), `crit_more` = extra crit chance (Worked Up's capstone).
## Returns the damage it dealt; _hound_crit says whether it critically struck.
func _hound_hit(foe: Variant, coef: float, id: String, bonuses: Array = [], crit_more: float = 0.0) -> int:
	_hound_crit = false
	if foe == null or not is_instance_valid(foe) or not foe.is_alive():
		return 0
	var info := DamageInfo.make(self, foe, coef, id)
	info.damage_type = "shadow"
	info.tags = PackedStringArray(HOUND_TAGS)
	info.is_proc = true       # runes and "on hit" talents do not fire off it, and Baited Steel does not count it
	info.no_empower = true    # it neither builds nor spends a "your next ..." buff
	if crit_more > 0.0:
		info.set_meta(HOUND_CRIT_META, crit_more)
	for b in bonuses + hound_hit_bonuses(id, _talent("shadow_pack_leader"), _talent("shadow_pincer"),
			_talent("shadow_take_it_with_you")):
		info.add_bonus(float(b[0]), str(b[1]))
	_combat().deal(info)
	var dealt := 0 if info.avoided() else int(info.amount)
	_hound_crit = dealt > 0 and bool(info.crit)
	return dealt

## Both At Once: each of my Hounds leaps at `foe` and hits it (a third one too,
## while it is out). Pincer's capstone: a lunge that critically strikes gives
## Rage back.
func _hounds_lunge(foe: Variant) -> void:
	if not hounds_out() or not _prey_ok(foe):
		return
	_set_hound_prey(foe)
	var refund := Balance.PINCER_RAGE if _capstone("shadow_pincer") else 0.0
	for i in _hound_bite_at.size():
		_hound_hit(foe, Balance.HOUND_LUNGE, HOUND_LUNGE_ID)
		if _hound_crit:
			_gain("rage", refund)
		if i < _hound_nodes.size() and is_instance_valid(_hound_nodes[i]):
			_hound_nodes[i].lunge()
	_tell_hounds(true)

## Run Them Down: everything around me is struck - more than AOE_TARGET_CAP
## enemies share that many hits' damage - and for a while my Hounds' bites reach
## other enemies too (_hound_bite).
func _run_them_down(w: Dictionary, res: Resource) -> void:
	var reach := float(res.radius)
	var hit := _enemies_within(reach)
	var coef := _weapon_hit(w, res) * Balance.aoe_share(hit.size())
	for e in hit:
		if is_instance_valid(e) and e.is_alive():
			deal_damage(e, coef, RUN_DOWN_ID)
	status.apply(make_run_down_fx(run_down_targets(_talent("shadow_wide_pack"))), self)
	for i in 3:
		rotation.y += TAU / 3.0
		_slash_effect(HOUND_COLOR)
	_ring_effect(reach, HOUND_COLOR)

func _start_guard_dogs() -> void:
	status.apply(make_guard_dogs_fx(), self)
	_ring_effect(1.4, HOUND_COLOR)
	_ring_effect(0.9, Abilities.color_of(GUARD_DOGS_ID))

## Off the Chain: my Hounds bite faster, and their time stands still while it
## lasts (they stay that much longer).
func _start_off_the_chain() -> void:
	# (Slipped Leash makes the buff last longer: Abilities.effect_time_bonus.)
	status.apply(make_off_the_chain_fx(), self)
	if hounds_out():
		var now := _hound_now()
		_hounds_until = hounds_until_unchained(_hounds_until, now, off_the_chain_time(_talent("shadow_slipped_leash")))
		status.set_remaining(HOUNDS_FX, _hounds_until - now)
		if _capstone("shadow_slipped_leash"):
			_add_third_hound()
		_tell_hounds()
	_ring_effect(1.6, HOUND_COLOR)
	_ring_effect(1.0, Abilities.color_of(OFF_THE_CHAIN_ID))

## Slipped Leash's capstone: a third Hound comes up beside the pair. It stays
## for as long as Off the Chain lasts (_tick_hounds sends it away).
func _add_third_hound() -> void:
	if not hounds_out() or _hound_bite_at.size() >= Balance.HOUND_COUNT + Balance.SLIPPED_LEASH_HOUNDS:
		return   # (it is out already)
	var at := _hound_bite_at.size()
	_hound_bite_at.append(_hound_now() + HOUND.RISE_TIME + _hound_bite_every() * 0.5)
	# (Its picture keeps its own place in the list, whatever became of the pair's.)
	while _hound_nodes.size() < at:
		_hound_nodes.append(null)
	_hound_nodes.append(HOUND.call_one(get_tree().current_scene, self, _hound_prey if _prey_ok(_hound_prey) else null,
		maxf(status.remaining_of(OFF_THE_CHAIN_FX), 0.1), false, at))

## Off the Chain is over: the third Hound goes back under, dragging at its prey
## like any Hound whose time is up. The pair stays.
func _third_hound_gone() -> void:
	while _hound_bite_at.size() > Balance.HOUND_COUNT:
		var at := _hound_bite_at.size() - 1
		_hound_bite_at.remove_at(at)
		var drag := is_alive() and _prey_ok(_hound_prey)
		if drag:
			_drag_down(_hound_prey, 1)
		if at < _hound_nodes.size():
			var node: Variant = _hound_nodes[at]
			_hound_nodes.remove_at(at)
			if node != null and is_instance_valid(node):
				node.leave(drag)
	_tell_hounds()

## `hounds` Hounds drag at `prey` on their way down (Drag Down). Take It With
## You's capstone watches whether it dies of it (_on_enemy_died_shadow).
func _drag_down(prey: Node3D, hounds: int) -> void:
	if _drag_watch.size() >= 16:
		_drag_watch.clear()
	_drag_watch[prey.get_instance_id()] = _hound_now() + Balance.DRAG_KILL_WINDOW
	for i in hounds:
		_hound_hit(prey, Balance.HOUND_DRAG, HOUND_DRAG_ID)

## Bring It Down: my Hounds go back under now, each dragging at its prey as if
## their time was up. At heel, they take my target. My next Shadow melee
## ability calls a new pair.
func _bring_it_down() -> void:
	if not hounds_out():
		return
	if not _prey_ok(_hound_prey) and _has_valid_target() and _prey_ok(target):
		_set_hound_prey(target)
	var prey: Variant = _hound_prey
	status.remove(HOUNDS_FX)
	_hounds_gone(true)
	_ring_effect(1.2, HOUND_COLOR)
	if _prey_ok(prey):
		_ring_effect(0.9, HOUND_COLOR, (prey as Node3D).global_position)

## My Hounds are gone. `time_up`: each drags at its prey on the way down.
func _hounds_gone(time_up: bool) -> void:
	var prey: Variant = _hound_prey
	var out := maxi(_hound_bite_at.size(), Balance.HOUND_COUNT)   # (three while Slipped Leash's third is out)
	_hounds_until = 0.0
	_hound_prey = null
	_hound_bite_at = []
	if status != null and status.has(ROUSED_FX):
		status.remove(ROUSED_FX)   # there is nobody left to be Roused
	var drag := time_up and is_alive() and _prey_ok(prey)
	if drag:
		_drag_down(prey, out)
	_drop_hound_nodes(drag)
	_hounds_told = _hound_now()
	_net_fx("hounds", global_position, prey if drag else null, {"time": 0.0})

## Their pictures sink back into the ground.
func _drop_hound_nodes(drag: bool) -> void:
	for n in _hound_nodes:
		if n != null and is_instance_valid(n):
			n.leave(drag)
	_hound_nodes = []

## Tell the party about my Hounds: how long they have left, what they are on,
## and (`lunge`) that they leap at it now.
func _tell_hounds(lunge: bool = false) -> void:
	_hounds_told = _hound_now()
	_net_fx("hounds", global_position, _hound_prey if _prey_ok(_hound_prey) else null,
		{"time": maxf(_hounds_until - _hounds_told, 0.1), "lunge": lunge, "count": maxi(_hound_bite_at.size(), Balance.HOUND_COUNT)})

# --- Shadow healer: the Strings ---------------------------------------------------------------
# A demon floats behind me and holds my allies up on puppet Strings. It has
# STRING_MAX of them, for allies and enemies together. Each one is in my hand
# (a charge of the String ability), tied to someone, or used up and recovering.
#   On an ally   it heals every second (faster with Haste) for STRING_TIME
#                seconds. Up to STRING_STACKS go on one ally; tying another
#                starts the time of all of them over.
#   On an enemy  it lasts STRING_ENEMY_TIME seconds and is crossed with the ally
#                I tied last: part of the damage that ally takes is dealt to the
#                enemy instead (Crossed Strings), while the two are close enough.
#   Shared       a spell or ability of mine that heals an ally on a String also
#                heals every other ally on one for a share (heal_done).
#   Coming back  a String that runs its time, or whose target dies or gets out
#                of reach, is back in my hand at once. One I use up (tied to an
#                ally who is full, pulled taut) recovers STRING_RECHARGE seconds
#                later, one after the other. So letting them run out is free and
#                keeping everyone covered without a gap is not.
# Everything is decided here, on the healer's machine: who holds how many, when
# they end, every heal. A party member is told through Net.support_ally (their
# Player.receive_support): heals, the buff that shows their Strings, the share
# of damage that is crossed away (they report it back as "cross_dmg" and I deal
# it), shields, Still Standing and Yank. A friendly dummy is handled right here.
# Cat's Cradle ties loose Strings: they heal and count as "on a String" but are
# none of my STRING_MAX. Double Thread's second String is free in the same way.
# The demon and the threads are scripts/puppeteer.gd (only a picture); the
# party sees them through the "strings" fx. Numbers: balance.gd (STRING_*, ...).

const PUPPETEER = preload("res://scripts/puppeteer.gd")
const STRING_ID := "puppetstring"
const PATCH_UP_ID := "patchup"
const HOIST_ID := "hoist"
const TUG_ID := "tug"
const CRADLE_ID := "catscradle"
const WRENCH_ID := "wrench"
const PULL_TAUT_ID := "pulltaut"
const CUPPED_HANDS_ID := "cuppedhands"
const STRING_UP_ID := "stringup"
const RESTRING_ID := "restring"
const KNOT_ID := "knot"
const TANGLE_ID := "tangle"
const YANK_ID := "yank"
const DOUBLE_THREAD_ID := "doublethread"
const BEHIND_ID := "behinditsback"
const SLACK_ID := "slack"
const STILL_STANDING_ID := "stillstanding"
const CUT_STRINGS_ID := "cutthestrings"
const NOT_FINISHED_ID := "notfinished"
## The kit's instant abilities (Patch Up and Hoist are cast like Heal: SUPPORT_CASTS).
const STRING_INSTANTS := [STRING_ID, TUG_ID, CRADLE_ID, WRENCH_ID, PULL_TAUT_ID, CUPPED_HANDS_ID, STRING_UP_ID, RESTRING_ID,
	KNOT_ID, TANGLE_ID, YANK_ID, DOUBLE_THREAD_ID, BEHIND_ID, SLACK_ID, STILL_STANDING_ID, CUT_STRINGS_ID, NOT_FINISHED_ID]
## Heals of mine that are never shared along the Strings: the Strings' own, and
## the ones that already reach everybody.
const STRING_NO_SHARE := [STRING_ID, CRADLE_ID, PULL_TAUT_ID, CUT_STRINGS_ID]
## Meter / log ids (Details.HIT_NAMES): the shared heal, and the damage Crossed Strings moves to an enemy.
const STRING_SHARE_ID := "string_share"
const CROSSED_ID := "crossed_strings"
const CROSSED_LABEL := "Crossed Strings"
## Talents: First Stitch's heal and Long Drop's hit (meter ids), Full Harness (the name of what it takes off a hit), Lean On Me (its buff).
const FIRST_STITCH_ID := "first_stitch"
const LONG_DROP_ID := "long_drop"
const FULL_HARNESS_LABEL := "Full Harness"
const LEAN_ON_ME_FX := "lean_on_me"
const STRING_BUFF := "on_a_string"          # what someone on a String carries: it shows how many, and for how long
const DOUBLE_THREAD_FX := "double_thread"
const BEHIND_FX := "behind_its_back"
const SLACK_FX := "slack"
const CUPPED_HANDS_FX := "cupped_hands"
const STILL_STANDING_FX := "still_standing"
const HELD_UP_FX := "held_up"
const STRUNG_UP_FX := "strung_up"           # data/effects/strung_up.tres
const TANGLED_FX := "tangled"               # data/effects/tangled.tres
const STRING_TAGS := ["Shadow", "Spell"]
const STRING_COLOR := Color(0.93, 0.86, 1.0)
const NOT_ON_STRING := "That ally is not on one of your Strings"
const NO_STRING_THERE := "That ally has none of your Strings"
const NO_STRINGS_OUT := "You have no Strings placed"
## Seconds between reminders to the party (and to everyone on a String) of where my Strings are.
const STRINGS_RETELL := 3.0
## Seconds a new String waits for its ally to be on its feet (Not Finished With You: the revive is on its way).
const STRING_GRACE := 2.5

var _strings := {}              # target instance id -> entry (see _string_entry)
var _string_order: Array = []   # target instance ids, one for each String tied, oldest first (Restring takes the last)
var _string_last_ally := 0      # instance id of the ally I tied last: an enemy's String is crossed with it
var _string_spent := 0          # Strings used up and recovering
var _string_recover_at := 0.0   # when the next of them is back
var _slack_until := 0.0         # Slack: no String heals before this
var _strings_dirty := false
var _strings_shown := false
var _strings_told := 0.0
var _string_fx: Resource
# The other end: Strings somebody (I myself, or a party member) has on me.
var _strung := {}               # caster instance id -> {"from": Node, "cross": percent, "until": time}
var _cross_owed := {}           # caster instance id -> damage crossed away from me that they still have to hear of
var _cross_told := 0.0
var _stand_until := 0.0         # Still Standing on me: a killing blow before this is held off
var _stand_hold := 0.0          # ... for this long
var _stand_pct := 0.0           # ... and I need this share of health at the end of it
var _held_until := 0.0          # the Strings are holding me up until then (I cannot die)

## Strings in my hand with `placed` of my own tied somewhere and `spent` recovering.
static func strings_in_hand(placed: int, spent: int) -> int:
	return maxi(Balance.STRING_MAX - maxi(placed, 0) - maxi(spent, 0), 0)

## The String ability's global cooldown: a share of a normal one.
static func string_gcd(gcd: float) -> float:
	return gcd * Balance.STRING_GCD_MULT

# What the healer's talents change (talents.gd, Shadow: "the Strings").

## Seconds a String on an ally lasts (`longer`: Long Thread).
static func string_time_with(longer: float) -> float:
	return Balance.STRING_TIME + maxf(longer, 0.0)

## Seconds a used-up String takes to come back (`sooner`: Spare Spool).
static func string_recharge(sooner: float) -> float:
	return maxf(Balance.STRING_RECHARGE - maxf(sooner, 0.0), 1.0)

## The share (%) of an ally's damage Crossed Strings moves (`talent`: Taking the Weight's, which replaces it).
static func cross_pct_with(talent: float) -> float:
	return talent if talent > 0.0 else Balance.STRING_CROSS_PCT

## Metres apart a crossing holds (`far`: Taking the Weight's capstone).
static func cross_range_with(far: bool) -> float:
	return Balance.TAKING_THE_WEIGHT_RANGE if far else Balance.STRING_CROSS_RANGE

## Full Harness: the share (%) of its damage an ally with `strings` of my Strings is spared.
static func full_harness_pct(strings: int, pct: float) -> float:
	return pct if strings >= Balance.STRING_STACKS and pct > 0.0 else 0.0

## First Stitch: the heal of tying a String, a coefficient (`heals` heals of one String).
static func first_stitch_coef(heals: float) -> float:
	return Balance.STRING_HEAL * maxf(heals, 0.0)

## Heave: Hoist's heal on someone with `strings` of my Strings, a multiplier (`pct` % more for each).
static func heave_mult(strings: int, pct: float) -> float:
	return 1.0 + maxf(pct, 0.0) * clampi(strings, 0, Balance.STRING_STACKS) / 100.0

## Heave's capstone: Hoist's cast time on someone with `strings` of my Strings.
## Deep Call: Beckon's cast `cast` is `cut` sec shorter on a target whose Breach of mine is open.
static func deep_call_cast(cast: float, cut: float, open: bool) -> float:
	return maxf(cast - cut, 0.2) if open and cut > 0.0 else cast

## Hard Pull: how long Tug makes an ally's Strings heal faster (`extra` = the talent's seconds).
static func tug_time(extra: float = 0.0) -> float:
	return Balance.TUG_TIME + maxf(extra, 0.0)

static func heave_cast(cast: float, strings: int, capstone: bool) -> float:
	return maxf(cast - Balance.HEAVE_CAST, 0.2) if capstone and strings >= Balance.STRING_STACKS else cast

## Snap Back: does Pull Taut's String go straight back into my hand? (`roll`: 0-100.)
static func snaps_back(pct: float, roll: float) -> bool:
	return pct > 0.0 and roll < pct

## Seconds Slack stops the Strings healing (`less`: Give and Take).
static func slack_time(less: float) -> float:
	return maxf(Balance.SLACK_TIME - maxf(less, 0.0), 0.0)

## Steady Hands: a String's heal `coef` with `pct` % more.
static func steady_heal(coef: float, pct: float) -> float:
	return coef * (1.0 + maxf(pct, 0.0) / 100.0)

## Many Hands: the multiplier on a heal of mine (`on_other`: it is not on myself).
static func many_hands_mult(on_other: bool, pct: float) -> float:
	return 1.0 + maxf(pct, 0.0) / 100.0 if on_other else 1.0

## Lean On Me: less damage taken for a while after healing someone else.
static func make_lean_on_me_fx(pct: float) -> Resource:
	var fx := StatusContainer.make_buff(LEAN_ON_ME_FX, "Lean On Me", LEAN_ON_ME_FX, 0.0, Balance.LEAN_ON_ME_TIME, 1, STRING_COLOR.darkened(0.15))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Shadow", "Defensive"])
	fx.damage_mod_pct = -absf(pct)
	fx.modifies_incoming = true
	fx.mod_affects_dots = true
	fx.description = "You take %s%% less damage." % Stats.num(absf(pct))
	return fx

func string_time() -> float:
	return string_time_with(_talent("shadow_long_thread"))

func _cross_pct() -> float:
	return cross_pct_with(_talent("shadow_taking_the_weight"))

## Many Hands: what a heal of mine on `tgt` is multiplied by (more on anyone but me).
## (And my Pact's: the Shepherd. A heal on myself gets that one in heal().)
func _others_heal_mult(tgt: Variant) -> float:
	var other: bool = tgt != null and is_instance_valid(tgt) and not is_same(tgt, self)
	return many_hands_mult(other, _talent("shadow_many_hands")) * (_pact_heal_mult() if other else 1.0)

func _steady(coef: float) -> float:
	return steady_heal(coef, _talent("shadow_steady_hands"))

## Lean On Me: I healed someone else (_on_heal_done_strings).
func _lean_on_me() -> void:
	var pct := _talent("shadow_lean_on_me")
	if pct <= 0.0 or status == null or is_dead():
		return
	if status.has(LEAN_ON_ME_FX):
		status.set_remaining(LEAN_ON_ME_FX, Balance.LEAN_ON_ME_TIME)   # (many small heals: only its time starts over)
	else:
		status.apply(make_lean_on_me_fx(pct), self)

## Long Drop: enemies String Up is holding, and when each is let go.
var _long_drops: Array = []   # [{"foe": Node, "at": time}]

func _tick_long_drops() -> void:
	if _long_drops.is_empty():
		return
	var now := _str_now()
	for i in range(_long_drops.size() - 1, -1, -1):
		var d: Dictionary = _long_drops[i]
		if now < float(d["at"]):
			continue
		_long_drops.remove_at(i)
		var foe: Variant = d["foe"]
		var coef := _talent("shadow_long_drop")
		if coef > 0.0 and foe != null and is_instance_valid(foe) and foe is Node3D and foe.is_alive():
			deal_damage(foe, coef, LONG_DROP_ID, true, "shadow", PackedStringArray(STRING_TAGS))
			_ring_effect(0.8, HOUND_COLOR, (foe as Node3D).global_position)

## Tying a String to an ally who has `n`: [Strings it has afterwards, how many of
## those added are free (Double Thread's second), is the String used up].
## An ally who is full gets none: the String only starts their time over, and
## is used up doing it.
static func string_placed(n: int, doubled: bool = false) -> Array:
	var room := Balance.STRING_STACKS - maxi(n, 0)
	if room <= 0:
		return [maxi(n, 0), 0, true]
	var add := mini(2 if doubled else 1, room)
	return [maxi(n, 0) + add, add - 1, false]

## Heal of one tick on an ally with `stacks` Strings (`loose`: one of Cat's Cradle's as well), a coefficient.
static func string_tick_heal(stacks: int, loose: bool = false) -> float:
	return Balance.STRING_HEAL * (maxi(stacks, 0) + (1 if loose else 0))

## Seconds between the heals of an ally's Strings (`haste` = my haste multiplier, `tugged` = Tug).
static func string_tick_interval(haste: float, tugged: bool = false) -> float:
	return maxf(Balance.STRING_TICK / (maxf(haste, 0.1) * (Balance.TUG_SPEED_MULT if tugged else 1.0)), 0.1)

## What every other ally on a String gets of a heal of `amount`.
static func string_share(amount: int) -> int:
	return int(round(maxf(float(amount), 0.0) * Balance.STRING_SHARE_PCT / 100.0))

## Is a heal `id` of mine shared along the Strings? A spell's or an ability's
## own heal (`is_ability`: it is in Abilities.PATHS): no Lifesteal, no talent or
## rune heal, and none of STRING_NO_SHARE.
static func shares_heal(id: String, is_ability: bool) -> bool:
	return is_ability and not STRING_NO_SHARE.has(id)

## Crossed Strings: the damage that was taken away from a hit of `amount` (what
## got through, with `bonus_pct` in it) by a `pct` % share. The enemy takes it.
static func cross_redirect(amount: float, bonus_pct: float, pct: float) -> float:
	var mult := 1.0 + bonus_pct / 100.0
	if mult <= 0.0 or pct <= 0.0 or amount <= 0.0:
		return 0.0
	return amount * (pct / 100.0) / mult

## Pull Taut: the healing a String with `seconds_left` still had to give, a coefficient.
## (`full`: how long a String lasts for me, with Long Thread.)
static func pull_taut_coef(seconds_left: float, full: float = Balance.STRING_TIME) -> float:
	return Balance.STRING_HEAL * clampf(seconds_left, 0.0, maxf(full, 0.0)) / Balance.STRING_TICK

## Cupped Hands: its shield on an ally with `strings` Strings, as a Heal coefficient.
static func cupped_hands_coef(strings: int) -> float:
	return Balance.REFERENCE_HEAL * (Balance.CUPPED_HANDS_SHIELD + Balance.CUPPED_HANDS_PER_STRING * maxi(strings, 0))

## Slack: mana points back with `strings` Strings out.
static func slack_mana(strings: int) -> float:
	return Balance.SLACK_MANA * maxi(strings, 0)

## Still Standing: is someone at `hp` of `max_hp` health well enough to stay up when the Strings let go?
static func still_standing_lives(hp: int, max_hp: int, pct: float) -> bool:
	return max_hp > 0 and float(hp) * 100.0 / float(max_hp) >= pct

## The buff someone on a String carries (its stacks = how many Strings).
static func make_string_fx() -> Resource:
	var fx := StatusContainer.make_buff(STRING_BUFF, "String", STRING_BUFF, 0.0, Balance.STRING_TIME, Balance.STRING_STACKS + 1, STRING_COLOR)
	fx.stat_modifiers = {}
	fx.stack_mode = 0   # (its stacks and time are set by whoever holds the Strings)
	fx.per_caster = true
	fx.tags = PackedStringArray(["Shadow"])
	fx.description = "Held up by a demon's Strings: each one heals you every second."
	return fx

static func make_double_thread_fx() -> Resource:
	var fx := StatusContainer.make_buff(DOUBLE_THREAD_FX, Abilities.ability_name(DOUBLE_THREAD_ID), DOUBLE_THREAD_FX, 0.0,
		Balance.DOUBLE_THREAD_TIME, 1, STRING_COLOR)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Shadow"])
	fx.description = "Your next String on an ally is placed as two."
	return fx

## Behind Its Back: less damage taken, of every kind.
static func make_behind_fx() -> Resource:
	var fx := StatusContainer.make_buff(BEHIND_FX, Abilities.ability_name(BEHIND_ID), BEHIND_FX, 0.0,
		Balance.BEHIND_ITS_BACK_TIME, 1, HOUND_COLOR.darkened(0.1))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Shadow", "Defensive"])
	fx.damage_mod_pct = -Balance.BEHIND_ITS_BACK_PCT
	fx.modifies_incoming = true
	fx.mod_affects_dots = true
	fx.description = "You take %s%% less damage." % Stats.num(Balance.BEHIND_ITS_BACK_PCT)
	return fx

static func make_slack_fx() -> Resource:
	var fx := StatusContainer.make_buff(SLACK_FX, Abilities.ability_name(SLACK_ID), SLACK_FX, 0.0, Balance.SLACK_TIME, 1, STRING_COLOR.darkened(0.3))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Shadow"])
	fx.description = "Your Strings are slack: they do not heal."
	return fx

## Cupped Hands: the buff its shield rides on (`time` seconds).
static func make_cupped_hands_fx(time: float) -> Resource:
	var fx := StatusContainer.make_buff(CUPPED_HANDS_FX, Abilities.ability_name(CUPPED_HANDS_ID), CUPPED_HANDS_FX, 0.0, time, 1, HOUND_COLOR)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Shadow", "Defensive"])
	fx.description = "A demon's hand is closed over you: a shield that absorbs damage."
	return fx

static func make_still_standing_fx(time: float) -> Resource:
	var fx := StatusContainer.make_buff(STILL_STANDING_FX, Abilities.ability_name(STILL_STANDING_ID), STILL_STANDING_FX, 0.0, time, 1, STRING_COLOR)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Shadow", "Defensive"])
	fx.description = "A killing blow leaves you at a sliver of health, held up by the Strings."
	return fx

static func make_held_up_fx(time: float) -> Resource:
	var fx := StatusContainer.make_buff(HELD_UP_FX, "Held Up", HELD_UP_FX, 0.0, time, 1, HOUND_COLOR.lightened(0.2))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Shadow", "Defensive"])
	fx.description = "The Strings are holding you up: nothing can kill you. When they let go you fall, unless you have been healed enough."
	return fx

func _str_now() -> float:
	return Time.get_ticks_msec() / 1000.0

## My entry for `who`, made empty if there is none: {node, enemy, n (Strings on
## it), free (how many of those are none of my STRING_MAX), until (when they run
## out), born, next (its next heal), fast (Tug: heals faster until then), knot,
## cross (instance id at the other end of a crossing, 0 = none), loose (when
## Cat's Cradle's String on it runs out, 0 = none)}.
func _string_entry(who: Node3D, is_enemy: bool) -> Dictionary:
	var key := who.get_instance_id()
	if not _strings.has(key):
		var now := _str_now()
		_strings[key] = {"node": who, "enemy": is_enemy, "n": 0, "free": 0, "until": 0.0, "born": now,
			"next": now + string_tick_interval(haste_mult()), "fast": 0.0, "knot": false, "cross": 0, "loose": 0.0}
	return _strings[key]

## How many of my STRING_MAX are tied somewhere.
func strings_placed() -> int:
	var n := 0
	for e in _strings.values():
		n += int(e["n"]) - int(e["free"])
	return n

## Every String I have out, the free ones too (not Cat's Cradle's loose ones).
func strings_out() -> int:
	var n := 0
	for e in _strings.values():
		n += int(e["n"])
	return n

## Strings in my hand: the charges of the String ability.
func string_charges() -> int:
	return strings_in_hand(strings_placed(), _string_spent)

## My Strings on `who` (not a loose one).
func strings_on(who: Variant) -> int:   # untyped: may be a freed node
	if who == null or not is_instance_valid(who) or not (who is Node):
		return 0
	var e: Variant = _strings.get((who as Node).get_instance_id())
	return int(e["n"]) if e != null else 0

## Is `who` on one of my Strings (a loose one counts)?
func on_my_string(who: Variant) -> bool:
	if who == null or not is_instance_valid(who) or not (who is Node):
		return false
	var e: Variant = _strings.get((who as Node).get_instance_id())
	return e != null and (int(e["n"]) > 0 or float(e["loose"]) > _str_now())

## Can entry `e` still hold? Its target is there, on its feet (a new one gets a
## moment for that) and within the leash.
func _string_holds(e: Dictionary, now: float) -> bool:
	var who: Variant = e["node"]
	if who == null or not is_instance_valid(who) or not (who is Node3D):
		return false
	if not who.is_alive() and (bool(e["enemy"]) or now - float(e["born"]) > STRING_GRACE):
		return false
	return is_same(who, self) or _flat_dist_to((who as Node3D).global_position) <= Balance.STRING_LEASH

## Who a String ability goes to: [node, is it an enemy, error]. My friendly
## target; else (`foes`) my enemy target; else me.
func _string_pick(id: String, foes: bool) -> Array:
	var res := Abilities.get_resource(id)
	var reach := float(res.cast_range) if res else 40.0
	var who: Node3D = self
	var is_enemy := false
	if has_friendly_target():
		who = friendly_target
	elif foes and _has_valid_target():
		who = target
		is_enemy = true
	if not is_same(who, self):
		if reach > 0.0 and global_position.distance_to(who.global_position) > reach:
			return [null, false, "Target out of range"]
		if not can_see(who):
			return [null, false, "Target not in line of sight"]
	return [who, is_enemy, ""]

## Can a String ability be used right now? ("" = yes.) _drafted_precheck asks.
func _string_precheck(id: String) -> String:
	match id:
		STRING_ID:
			return str(_string_pick(id, true)[2])
		TUG_ID, CUPPED_HANDS_ID, STILL_STANDING_ID:
			var pick := _string_pick(id, false)
			if str(pick[2]) != "":
				return str(pick[2])
			return "" if on_my_string(pick[0]) else NOT_ON_STRING
		PULL_TAUT_ID, KNOT_ID:
			var pick := _string_pick(id, false)
			if str(pick[2]) != "":
				return str(pick[2])
			return "" if strings_on(pick[0]) > 0 else NO_STRING_THERE
		YANK_ID:
			if not has_friendly_target():
				return "No friendly target"
			var pick := _string_pick(id, false)
			if str(pick[2]) != "":
				return str(pick[2])
			return "" if on_my_string(pick[0]) else NOT_ON_STRING
		WRENCH_ID:
			return "" if strings_on(target) > 0 else "That enemy has none of your Strings"
		BEHIND_ID, SLACK_ID, CUT_STRINGS_ID:
			return "" if strings_out() > 0 else NO_STRINGS_OUT
		NOT_FINISHED_ID:
			var res := Abilities.get_resource(id)
			return "" if _fallen_ally(float(res.cast_range)) != null else "No downed ally in range"
		RESTRING_ID:
			return _restring_error()
	return ""

## A String ability went off (_use_drafted, once it was paid for).
func _string_use(id: String, res: Resource) -> void:
	match id:
		STRING_ID:
			_use_string()
		TUG_ID:
			_tug()
		CRADLE_ID:
			_cats_cradle(res)
		WRENCH_ID:
			_wrench(res)
		PULL_TAUT_ID:
			_pull_taut()
		CUPPED_HANDS_ID:
			_cupped_hands()
		STRING_UP_ID:
			_string_up()
		RESTRING_ID:
			_restring()
		KNOT_ID:
			_knot()
		TANGLE_ID:
			_tangle(res)
		YANK_ID:
			_yank()
		DOUBLE_THREAD_ID:
			status.apply(make_double_thread_fx(), self)
			_ring_effect(0.8, STRING_COLOR)
		BEHIND_ID:
			status.apply(make_behind_fx(), self)
			_ring_effect(1.3, HOUND_COLOR)
		SLACK_ID:
			_slack()
		STILL_STANDING_ID:
			_still_standing()
		CUT_STRINGS_ID:
			_cut_the_strings()
		NOT_FINISHED_ID:
			_not_finished(res)

# The Strings themselves.

## String: one from my hand to whoever I have targeted (an ally, an enemy, or me).
func _use_string() -> void:
	var pick := _string_pick(STRING_ID, true)
	var who: Variant = pick[0]
	if who == null:
		return
	_tie_string(who, bool(pick[1]))
	_ring_effect(0.6, HOUND_COLOR if bool(pick[1]) else STRING_COLOR, (who as Node3D).global_position)

## Tie a String to `who`. `from_hand`: it comes out of my hand (false: Restring
## moves one that is out already, so nothing is used up and nothing is doubled).
func _tie_string(who: Node3D, is_enemy: bool, from_hand: bool = true) -> void:
	var now := _str_now()
	var key := who.get_instance_id()
	var e := _string_entry(who, is_enemy)
	if is_enemy:
		if int(e["n"]) >= 1:
			if from_hand:
				_string_use_up()   # it takes the place of the one that was there
		else:
			e["n"] = 1
			_string_order.append(key)
		e["until"] = now + Balance.STRING_ENEMY_TIME
		_cross_strings(key)
	else:
		var doubled: bool = from_hand and status != null and status.has(DOUBLE_THREAD_FX)
		var placed := string_placed(int(e["n"]), doubled)
		for i in int(placed[0]) - int(e["n"]):
			_string_order.append(key)
		e["n"] = int(placed[0])
		e["free"] = int(e["free"]) + int(placed[1])
		if bool(placed[2]) and from_hand:
			_string_use_up()
		if doubled:
			status.remove(DOUBLE_THREAD_FX)
		# (A knotted ally's Strings never lose time to a new one.)
		e["until"] = maxf(float(e["until"]), now + string_time()) if bool(e["knot"]) else now + string_time()
		_string_last_ally = key
		# First Stitch: the String heals the moment it is tied.
		var stitch := _talent("shadow_first_stitch")
		if stitch > 0.0:
			_heal_coef(who, _steady(first_stitch_coef(stitch)), FIRST_STITCH_ID)
	_tell_string(key, who)
	_strings_dirty = true

## A String of mine was used up: it is back in my hand STRING_RECHARGE seconds
## after the one recovering before it.
func _string_use_up() -> void:
	_string_spent += 1
	if _string_spent == 1:
		_string_recover_at = _str_now() + string_recharge(_talent("shadow_spare_spool"))   # Spare Spool

## One String comes off `key` (its entry goes with the last one).
func _string_take(key: int) -> void:
	if not _strings.has(key):
		return
	var e: Dictionary = _strings[key]
	if int(e["n"]) <= 1:
		_strings_fall(key)
		return
	e["n"] = int(e["n"]) - 1
	e["free"] = mini(int(e["free"]), int(e["n"]))
	var at := _string_order.rfind(key)
	if at >= 0:
		_string_order.remove_at(at)
	_tell_string(key, e["node"])
	_strings_dirty = true

## The Strings on `key` are gone (they ran their time, or were taken off). A
## loose one of Cat's Cradle stays until it runs out.
func _strings_fall(key: int) -> void:
	if not _strings.has(key):
		return
	var e: Dictionary = _strings[key]
	var who: Variant = e["node"]
	_uncross(key)
	e["n"] = 0
	e["free"] = 0
	e["knot"] = false
	while _string_order.has(key):
		_string_order.erase(key)
	if bool(e["enemy"]) or float(e["loose"]) <= _str_now():
		_strings.erase(key)
	_tell_string(key, who)
	_strings_dirty = true

## Everything of mine on `key` is gone, a loose String too.
func _string_gone(key: int) -> void:
	if not _strings.has(key):
		return
	_strings[key]["loose"] = 0.0
	_strings_fall(key)

## Dead, or downed: the demon lets everything go.
func _clear_strings() -> void:
	for key in _strings.keys():
		_string_gone(int(key))
	_slack_until = 0.0
	_show_strings()

## The String on enemy `enemy_key` is crossed with the ally I tied last (if that
## ally still has a String). One crossing for each ally and for each enemy: an
## older one lets go.
func _cross_strings(enemy_key: int) -> void:
	_uncross(enemy_key)
	var ally_key := _string_last_ally
	if not _strings.has(ally_key) or not _strings.has(enemy_key):
		return
	var a: Dictionary = _strings[ally_key]
	if bool(a["enemy"]) or int(a["n"]) <= 0:
		return
	_uncross(ally_key)
	a["cross"] = enemy_key
	_strings[enemy_key]["cross"] = ally_key
	_tell_string(ally_key, a["node"])

func _uncross(key: int) -> void:
	if not _strings.has(key):
		return
	var other := int(_strings[key]["cross"])
	if other == 0:
		return
	_strings[key]["cross"] = 0
	if _strings.has(other):
		_strings[other]["cross"] = 0
	for k in [key, other]:
		if _strings.has(k) and not bool(_strings[k]["enemy"]):
			_tell_string(int(k), _strings[k]["node"])

## Let whoever is at the other end know where their Strings stand: how many (a
## loose one counts), for how long, and what share of their damage is crossed
## away. Me: straight into my own buffs. A dummy: its Status. A party member:
## their machine (Net.support_ally "string").
func _tell_string(key: int, who: Variant) -> void:   # untyped: may be a freed node
	if who == null or not is_instance_valid(who) or not (who is Node) or (who as Node).is_in_group("enemies"):
		return
	var data := {"n": 0, "t": 0.0, "cross": 0.0, "dr": 0.0}
	var e: Variant = _strings.get(key)
	if e != null:
		var now := _str_now()
		var loose := maxf(float(e["loose"]) - now, 0.0)
		var held := maxf(float(e["until"]) - now, 0.0) if int(e["n"]) > 0 else 0.0
		data["n"] = int(e["n"]) + (1 if loose > 0.0 else 0)
		data["t"] = maxf(held, loose)
		data["cross"] = _cross_pct() if int(e["cross"]) != 0 else 0.0   # (Taking the Weight)
		data["dr"] = full_harness_pct(int(e["n"]), _talent("shadow_full_harness"))   # Full Harness: % less damage taken
	if is_same(who, self):
		_on_string_state(self, data)
	elif (who as Node).is_in_group("friendly"):
		_string_on_dummy(who, key, data)
	elif _net():
		_net().support_ally(who, self, "string", data)

## A friendly dummy on a String: the buff that shows it, and the share of what
## it takes that is crossed away (ally_dummy.gd asks its "damage_share" meta).
func _string_on_dummy(who: Node, key: int, data: Dictionary) -> void:
	var st: Node = who.get_node_or_null("Status")
	if st != null:
		if int(data["n"]) > 0 and float(data["t"]) > 0.0:
			if _string_fx == null:
				_string_fx = make_string_fx()
			if not st.has_from(STRING_BUFF, self):   # (told again every few seconds: only the numbers change)
				st.apply(_string_fx, self)
			st.set_stacks_from(STRING_BUFF, self, int(data["n"]))
			st.set_remaining_from(STRING_BUFF, self, float(data["t"]))
		else:
			st.remove_from(STRING_BUFF, self)
	if float(data["cross"]) > 0.0 or float(data.get("dr", 0.0)) > 0.0:
		who.set_meta("damage_share", Callable(self, "_dummy_crossed").bind(key))
	elif who.has_meta("damage_share"):
		who.remove_meta("damage_share")

## A dummy on a crossed String is about to take `dmg`: its share goes to the enemy. Returns what is left.
func _dummy_crossed(dmg: int, key: int) -> int:
	var e: Variant = _strings.get(key)
	if e == null or dmg <= 0:
		return dmg
	# Full Harness: with every String it can hold, it is spared a share.
	var left := dmg - int(round(dmg * full_harness_pct(int(e["n"]), _talent("shadow_full_harness")) / 100.0))
	if int(e["cross"]) == 0:
		return left
	var moved := int(round(dmg * _cross_pct() / 100.0))
	_crossed_damage(e["node"], moved)
	return maxi(left - moved, 0)

## An ally on a crossed String took less: `amount` of it is dealt to the enemy
## at the other end, as my own Shadow damage under its own name.
func _crossed_damage(ally: Variant, amount: int) -> void:
	if amount <= 0 or ally == null or not is_instance_valid(ally) or not (ally is Node):
		return
	var a: Variant = _strings.get((ally as Node).get_instance_id())
	if a == null or int(a["cross"]) == 0 or not _strings.has(int(a["cross"])):
		return
	_exact_hit(_strings[int(a["cross"])]["node"], amount, CROSSED_ID, "shadow", PackedStringArray(STRING_TAGS))

## Every frame: Strings heal, run out and come back; the demon and the party are kept up to date.
func _tick_strings() -> void:
	_tick_strung()            # (the other end: Strings somebody has on me)
	_tick_still_standing()
	_tick_long_drops()        # Long Drop: enemies String Up lets go of
	var now := _str_now()
	if _string_spent > 0 and now >= _string_recover_at:
		_string_spent -= 1
		_string_recover_at = now + string_recharge(_talent("shadow_spare_spool")) if _string_spent > 0 else 0.0
	if _strings.is_empty():
		if _strings_shown or _strings_dirty:
			_show_strings()
		return
	if is_dead():
		_clear_strings()
		return
	var slack := now < _slack_until
	for key in _strings.keys():
		if not _strings.has(key):
			continue
		var e: Dictionary = _strings[key]
		if not _string_holds(e, now):
			_string_gone(int(key))   # dead, gone or too far away: back in my hand
			continue
		if int(e["n"]) > 0 and now >= float(e["until"]):
			_strings_fall(int(key))  # ran their time: back in my hand
			if not _strings.has(key):
				continue
		var loose := float(e["loose"]) > now
		if int(e["n"]) <= 0 and not loose:
			_string_gone(int(key))
			continue
		if bool(e["enemy"]):
			# Crossed: it breaks when the two are too far apart.
			var other := int(e["cross"])
			if other != 0:
				var a: Variant = _strings.get(other)
				if a == null or not is_instance_valid(a["node"]) or (e["node"] as Node3D).global_position.distance_to(
						(a["node"] as Node3D).global_position) > cross_range_with(_capstone("shadow_taking_the_weight")):
					_string_gone(int(key))
			continue
		if now >= float(e["next"]):
			e["next"] = now + string_tick_interval(haste_mult(), now < float(e["fast"]))
			if not slack and (e["node"] as Node).is_alive():
				_heal_coef(e["node"], _steady(string_tick_heal(int(e["n"]), loose)), STRING_ID)   # (Steady Hands)
	if _strings_dirty or now - _strings_told >= STRINGS_RETELL:
		_show_strings()

## Show my demon and the threads on everyone I hold, tell the party, and remind
## everyone on a String where theirs stand.
func _show_strings() -> void:
	_strings_dirty = false
	_strings_told = _str_now()
	var now := _strings_told
	var net := _net()
	var held: Array = []
	var members := {}
	var foes := {}
	for key in _strings:
		var e: Dictionary = _strings[key]
		var who: Variant = e["node"]
		if who == null or not is_instance_valid(who):
			continue
		var n := int(e["n"]) + (1 if float(e["loose"]) > now else 0)
		if n <= 0:
			continue
		held.append([who, n, bool(e["enemy"])])
		if bool(e["enemy"]):
			if net:
				foes[str(net.enemy_id(who))] = 1
			continue
		if net and not (who as Node).is_in_group("friendly"):
			var member := int(net.member_of(who))
			if member != 0:
				members[member] = n
		_tell_string(int(key), who)
	_strings_shown = not held.is_empty()
	if is_inside_tree():
		PUPPETEER.hold(get_tree().current_scene, self, held)
	_net_fx("strings", global_position, null, {"m": members, "e": foes})

# Heals.

## Heal `tgt` (me, a party member or a friendly dummy) for exactly `amount`, as
## `id` in the log and on the meter. A party member is healed on their own machine.
func _heal_exact(tgt: Variant, amount: int, id: String) -> void:   # untyped: may be a freed node
	if amount <= 0 or tgt == null or not is_instance_valid(tgt) or not (tgt is Node):
		return
	if is_same(tgt, self) or (tgt as Node).is_in_group("friendly"):
		_combat().heal(self, tgt, float(amount), id, true)
		return
	_combat().float_text(tgt, "+%d" % amount, Color(0.45, 1.0, 0.45), false)
	_bus().heal_done.emit(self, tgt, amount, amount, id, false)   # Details meter
	if _net():
		_net().support_ally(tgt, self, "heal", {"amount": amount, "id": id})   # their machine heals them (+ threat)

## The same for a coefficient `coef` (it scales with my power like spell `id`). Returns the amount.
func _heal_coef(tgt: Variant, coef: float, id: String) -> int:
	# (Many Hands and my Pact on someone else; my Pact alone on myself, since this heal does not go through heal().)
	var amount: int = _combat().heal_amount(self, coef * (_pact_heal_mult() if is_same(tgt, self) else _others_heal_mult(tgt)), id)
	_heal_exact(tgt, amount, id)
	return amount

## A heal of mine landed (SignalBus.heal_done, which hears every one). A spell's
## or an ability's heal on an ally on a String is shared: every other ally on
## one of my Strings is healed for a share of it, under its own name.
func _on_heal_done_strings(source: Node, healed: Node, amount: int, _effective: int, id: String, _crit: bool) -> void:
	if amount <= 0 or not is_same(source, self):
		return
	_pact_on_heal(healed, id)   # my Pact: the Fast (a heal on myself), the Relentless (one on an ally)
	if healed != null and not is_same(healed, self):
		_lean_on_me()   # Lean On Me (an open talent: any heal of mine on someone else)
	if _strings.is_empty():
		return
	if not shares_heal(id, Abilities.PATHS.has(id)) or not on_my_string(healed):
		return
	var share := string_share(amount)
	for key in _strings.keys():
		var e: Variant = _strings.get(key)
		if e == null or bool(e["enemy"]) or is_same(e["node"], healed) or not on_my_string(e["node"]):
			continue
		_heal_exact(e["node"], share, STRING_SHARE_ID)

## Hoist and Patch Up finished casting (_release_support): the heal lands on
## whoever they were cast at. (Hoist's share for the others: _on_heal_done_strings.)
func _string_cast_heal(spell: String, tgt: Variant, kind: String) -> void:
	var who: Variant = tgt if kind == "ally" and tgt != null and is_instance_valid(tgt) else self
	var coef := float(Abilities.HEALS[spell])
	if spell == HOIST_ID:
		coef *= heave_mult(strings_on(who), _talent("shadow_heave"))   # Heave: more for each String on them
	_heal_coef(who, coef, spell)
	if who is Node3D:
		_ring_effect(1.2, STRING_COLOR, (who as Node3D).global_position)

## Tug: a small heal, and that ally's Strings heal faster for a while.
func _tug() -> void:
	var who: Variant = _string_pick(TUG_ID, false)[0]
	if who == null:
		return
	_heal_coef(who, float(Abilities.HEALS[TUG_ID]), TUG_ID)
	var e: Variant = _strings.get((who as Node).get_instance_id())
	if e != null:
		var now := _str_now()
		e["fast"] = now + tug_time(_talent("shadow_hard_pull"))   # Hard Pull: longer
		e["next"] = minf(float(e["next"]), now + string_tick_interval(haste_mult(), true))
	_ring_effect(0.7, STRING_COLOR, (who as Node3D).global_position)

## Cat's Cradle: every ally near me is healed and gets a loose String (none of
## my STRING_MAX) for a while.
func _cats_cradle(res: Resource) -> void:
	var now := _str_now()
	for a in _allies_within(float(res.radius)):
		_heal_coef(a, float(Abilities.HEALS[CRADLE_ID]), CRADLE_ID)
		var e := _string_entry(a, false)
		e["loose"] = now + Balance.LOOSE_STRING_TIME
		_tell_string((a as Node).get_instance_id(), a)
		_ring_effect(0.7, STRING_COLOR, (a as Node3D).global_position)
	_strings_dirty = true
	_ring_effect(2.5, STRING_COLOR)

## Pull Taut: one String on the ally gives all the healing it had left, and is used up.
func _pull_taut() -> void:
	var who: Variant = _string_pick(PULL_TAUT_ID, false)[0]
	if who == null:
		return
	var key: int = (who as Node).get_instance_id()
	var e: Variant = _strings.get(key)
	if e == null or int(e["n"]) <= 0:
		return
	_heal_coef(who, _steady(pull_taut_coef(float(e["until"]) - _str_now(), string_time())), PULL_TAUT_ID)
	_string_take(key)
	if snaps_back(_talent("shadow_snap_back"), randf() * 100.0):
		_combat().float_text(self, "Snap Back", STRING_COLOR, false)   # straight back into my hand
	else:
		_string_use_up()
	_ring_effect(0.9, STRING_COLOR, (who as Node3D).global_position)

## Knot: the ally's Strings do not run out for a while. One ally at a time.
func _knot() -> void:
	var who: Variant = _string_pick(KNOT_ID, false)[0]
	if who == null:
		return
	var key: int = (who as Node).get_instance_id()
	var now := _str_now()
	for k in _strings:
		var other: Dictionary = _strings[k]
		if bool(other["knot"]) and int(k) != key:
			other["knot"] = false
			other["until"] = minf(float(other["until"]), now + string_time())
			_tell_string(int(k), other["node"])
	var e: Variant = _strings.get(key)
	if e == null or int(e["n"]) <= 0:
		return
	e["knot"] = true
	e["until"] = now + Balance.KNOT_TIME
	_tell_string(key, who)
	_ring_effect(0.8, STRING_COLOR, (who as Node3D).global_position)

## Wrench: the enemy on a String is hurt, and the ally it is crossed with is healed for as much.
func _wrench(res: Resource) -> void:
	var foe: Node3D = target
	var e: Variant = _strings.get(foe.get_instance_id())
	var crossed: Variant = _strings.get(int(e["cross"])) if e != null and int(e["cross"]) != 0 else null
	var dealt := deal_damage(foe, float(res.damage), WRENCH_ID)
	if crossed != null and dealt > 0:
		_heal_exact(crossed["node"], dealt, WRENCH_ID)
	_ring_effect(0.7, HOUND_COLOR, foe.global_position)

## Cupped Hands: a shield on an ally on a String, bigger for each String on them.
func _cupped_hands() -> void:
	var who: Variant = _string_pick(CUPPED_HANDS_ID, false)[0]
	if who == null:
		return
	var e: Variant = _strings.get((who as Node).get_instance_id())
	var n := (int(e["n"]) + (1 if float(e["loose"]) > _str_now() else 0)) if e != null else 0
	var amount := int(round(_combat().heal_amount(self, cupped_hands_coef(n), CUPPED_HANDS_ID) * absorb_mult()))   # (Rime Ward: bigger shields)
	if is_same(who, self):
		_shield_on(status, self, amount, Balance.CUPPED_HANDS_TIME)
	elif (who as Node).is_in_group("friendly"):
		_shield_on((who as Node).get_node_or_null("Status"), self, amount, Balance.CUPPED_HANDS_TIME)
	elif _net():
		_net().support_ally(who, self, "shield", {"amount": amount, "time": Balance.CUPPED_HANDS_TIME})
	_combat().float_text(who, "%s (%d)" % [Abilities.ability_name(CUPPED_HANDS_ID), amount], STRING_COLOR, false)
	_ring_effect(1.0, HOUND_COLOR, (who as Node3D).global_position)

## Put Cupped Hands' shield of `amount` on whoever owns Status `st`.
func _shield_on(st: Node, from: Node, amount: int, time: float) -> void:
	if st == null or amount <= 0:
		return
	st.apply(make_cupped_hands_fx(time), from)
	st.set_absorb(CUPPED_HANDS_FX, amount)

## Slack: my Strings stop healing for a while, and I get mana back for each one out.
func _slack() -> void:
	var slack_for := slack_time(_talent("shadow_give_and_take"))   # Give and Take: for less long
	_slack_until = _str_now() + slack_for
	_gain("mana", slack_mana(strings_out()) * mana_unit())
	if slack_for > 0.0:
		status.apply(make_slack_fx(), self)
		status.set_remaining(SLACK_FX, slack_for)
	_ring_effect(1.2, Color(0.35, 0.55, 1.0))

## Still Standing: for a while a killing blow on that ally is held off by the Strings.
func _still_standing() -> void:
	var who: Variant = _string_pick(STILL_STANDING_ID, false)[0]
	if who == null:
		return
	var data := {"window": Balance.STILL_STANDING_TIME, "hold": Balance.STILL_STANDING_HOLD, "pct": Balance.STILL_STANDING_HEALTH_PCT}
	if is_same(who, self):
		_receive_hold(self, data)
	elif (who as Node).is_in_group("friendly"):
		var st: Node = (who as Node).get_node_or_null("Status")
		if st:
			st.apply(make_still_standing_fx(Balance.STILL_STANDING_TIME), self)   # (a dummy never dies: only shown)
	elif _net():
		_net().support_ally(who, self, "hold", data)
	_ring_effect(1.1, STRING_COLOR, (who as Node3D).global_position)

## Cut the Strings: every String out bursts (a heal on an ally for each one on
## them, damage on an enemy), and all of them are back in my hand.
func _cut_the_strings() -> void:
	for key in _strings.keys():
		var e: Variant = _strings.get(key)
		if e == null or int(e["n"]) <= 0:
			continue
		var who: Variant = e["node"]
		if who == null or not is_instance_valid(who):
			continue
		if bool(e["enemy"]):
			deal_damage(who, Balance.CUT_STRINGS_DAMAGE, CUT_STRINGS_ID)
		else:
			_heal_coef(who, Balance.CUT_STRINGS_HEAL * int(e["n"]), CUT_STRINGS_ID)
		if is_instance_valid(who) and who is Node3D:
			_ring_effect(0.9, HOUND_COLOR if bool(e["enemy"]) else STRING_COLOR, (who as Node3D).global_position)
	for key in _strings.keys():
		_strings_fall(int(key))
	_ring_effect(1.6, STRING_COLOR)

## The String I tied last that can be moved (0 = none): the newest one that is
## still out and not knotted.
func _restring_source() -> int:
	for i in range(_string_order.size() - 1, -1, -1):
		var key := int(_string_order[i])
		var e: Variant = _strings.get(key)
		if e != null and int(e["n"]) > 0 and not bool(e["knot"]):
			return key
	return 0

func _restring_error() -> String:
	var from := _restring_source()
	if from == 0:
		return "You have no String to move"
	var pick := _string_pick(RESTRING_ID, true)
	if str(pick[2]) != "":
		return str(pick[2])
	var key: int = (pick[0] as Node).get_instance_id()
	if key == from:
		return "That String is already there"
	var e: Variant = _strings.get(key)
	if e != null and int(e["n"]) >= (1 if bool(pick[1]) else Balance.STRING_STACKS):
		return "That target cannot hold another String"
	return ""

## Restring: the String I tied last moves to my current target.
func _restring() -> void:
	var from := _restring_source()
	var pick := _string_pick(RESTRING_ID, true)
	if from == 0 or pick[0] == null:
		return
	_string_take(from)
	_tie_string(pick[0], bool(pick[1]), false)
	_ring_effect(0.6, STRING_COLOR, (pick[0] as Node3D).global_position)

## Yank: my friendly target is pulled to just in front of me.
func _yank() -> void:
	var who: Node3D = friendly_target
	if who == null or not is_instance_valid(who):
		return
	var dir := who.global_position - global_position
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.1 else _flat_forward()
	var to := global_position + dir * Balance.YANK_STOP
	_ring_effect(0.8, STRING_COLOR, who.global_position)
	if who.is_in_group("friendly"):
		who.global_position = to
	elif _net():
		_net().support_ally(who, self, "yank", {"to": to})
	_ring_effect(0.8, STRING_COLOR)

## The nearest downed party member within `reach` metres (null if none).
func _fallen_ally(reach: float) -> Node3D:
	var best: Node3D = null
	var best_d := reach
	for p in get_tree().get_nodes_in_group("remote_player"):
		if not (p is Node3D) or not bool(p.get("downed")):
			continue
		var d := _flat_dist_to(p.global_position)
		if d <= best_d:
			best_d = d
			best = p
	return best

## Not Finished With You: the nearest downed ally is lifted back onto their
## feet (their machine stands them up: Net.revive_ally) with Strings on them.
func _not_finished(res: Resource) -> void:
	var ally := _fallen_ally(float(res.cast_range))
	if ally == null:
		return
	if _net():
		_net().revive_ally(ally, self)
	var now := _str_now()
	var key := ally.get_instance_id()
	var e := _string_entry(ally, false)
	while _string_order.has(key):
		_string_order.erase(key)
	e["n"] = mini(Balance.NOT_FINISHED_STRINGS, Balance.STRING_STACKS)
	e["free"] = 0
	e["born"] = now
	e["until"] = now + string_time()
	for i in int(e["n"]):
		_string_order.append(key)
	_string_last_ally = key
	_tell_string(key, ally)
	_strings_dirty = true
	_ring_effect(1.4, STRING_COLOR, ally.global_position)

## String Up: the enemy hangs off the ground, unable to do anything.
func _string_up() -> void:
	var foe: Node3D = target
	var fx: Resource = preload("res://scripts/core/effects.gd").get_effect(STRUNG_UP_FX)
	var hangs := Balance.STRING_UP_TIME + effect_duration_bonus(fx)   # (Left Hanging: my stuns last longer)
	_apply_effect_hit(foe, fx, STRING_UP_ID, PackedStringArray(STRING_TAGS), "shadow")
	PUPPETEER.string_up(get_tree().current_scene, foe, hangs)
	_net_fx("strungup", foe.global_position, foe, {"time": hangs})   # the party sees it hang
	if _talent("shadow_long_drop") > 0.0:
		_long_drops.append({"foe": foe, "at": _str_now() + hangs})   # Long Drop: it is hurt when it is let go

## Tangle: every enemy near my target is held in place by Strings across the floor.
func _tangle(res: Resource) -> void:
	var foe: Node3D = target
	var at := foe.global_position
	var r := float(res.radius)
	var fx: Resource = preload("res://scripts/core/effects.gd").get_effect(TANGLED_FX)
	for e in _enemies_near(at, r):
		_apply_effect_hit(e, fx, TANGLE_ID, PackedStringArray(STRING_TAGS), "shadow")
	var ground := Vector3(at.x, Combat.feet_y(foe), at.z)
	var held := Balance.TANGLE_TIME + effect_duration_bonus(fx)   # (Left Hanging: my roots last longer)
	PUPPETEER.tangle(get_tree().current_scene, ground, r, held)
	_net_fx("tangle", ground, null, {"r": r, "time": held})
	_ring_effect(r, STRING_COLOR, at)

# The other end: what a healer's Strings do on the one they are tied to. This
# runs on the machine of whoever is held (me, when I tie one to myself).

## Something a party member's ability does to me, or tells me (Net._sup_do).
## `from` = their character on this machine.
func receive_support(kind: String, from: Node, data: Dictionary) -> void:
	match kind:
		"heal":
			if is_alive():
				_combat().heal(from, self, float(int(data.get("amount", 0))), str(data.get("id", "")), true)
		"string":
			_on_string_state(from, data)
		"shield":
			if is_alive():
				_shield_on(status, from, int(data.get("amount", 0)), float(data.get("time", 0.0)))
				_combat().float_text(self, "%s (%d)" % [Abilities.ability_name(CUPPED_HANDS_ID), int(data.get("amount", 0))], STRING_COLOR, false)
		"hold":
			if is_alive():
				_receive_hold(from, data)
		"yank":
			_yanked_to(data.get("to"))
		"cross_dmg":
			_crossed_damage(from, int(data.get("amount", 0)))   # (I am the healer: my ally's share for the enemy)
		# The Holy healer's Hymns (player.gd, "Holy healer: the Hymns").
		"hymn_dr":
			receive_hymn_dr(from, str(data.get("id", "")), float(data.get("pct", 0.0)), float(data.get("time", 0.0)))
		"hymn_ward":
			if is_alive() and HYMN_WARD_NAMES.has(str(data.get("id", ""))):
				var ward_id := str(data.get("id", ""))
				_hymn_ward_on(status, from, ward_id, int(data.get("amount", 0)), float(data.get("time", 0.0)))
				if ward_id == SHELTER_FX:
					_combat().float_text(self, "%s (%d)" % [HYMN_WARD_NAMES[ward_id], int(data.get("amount", 0))], HOLY_LIGHT, false)
		"vigil_hit":
			_talent_verse("holy_watchful", "vigil")   # (I am the healer: a big hit landed on an ally in my Vigil)

## Where the Strings `from` has on me stand: n = how many (0 = none any more),
## t = seconds they have left, cross = % of my damage that is crossed away.
func _on_string_state(from: Node, data: Dictionary) -> void:
	if from == null or not is_instance_valid(from) or status == null:
		return
	var key := from.get_instance_id()
	var n := int(data.get("n", 0))
	var t := float(data.get("t", 0.0))
	if n <= 0 or t <= 0.0 or is_dead():
		_strung.erase(key)
		status.remove_from(STRING_BUFF, from)
		return
	_strung[key] = {"from": from, "cross": float(data.get("cross", 0.0)), "dr": float(data.get("dr", 0.0)), "until": _str_now() + t}
	if _string_fx == null:
		_string_fx = make_string_fx()
	if not status.has_from(STRING_BUFF, from):   # (told again every few seconds: only the numbers change)
		status.apply(_string_fx, from)
	status.set_stacks_from(STRING_BUFF, from, n)
	status.set_remaining_from(STRING_BUFF, from, t)

## A hit on me, before its damage is worked out (_on_damage_modify): the share
## of it a crossed String takes away.
func _crossed_incoming(info: RefCounted) -> void:
	if _strung.is_empty():
		return
	var now := _str_now()
	for key in _strung.keys():
		var s: Dictionary = _strung[key]
		if now >= float(s["until"]) or not is_instance_valid(s["from"]):
			_strung.erase(key)
		else:
			if float(s["cross"]) > 0.0:
				info.add_bonus(-float(s["cross"]), CROSSED_LABEL)
			if float(s.get("dr", 0.0)) > 0.0:
				info.add_bonus(-float(s["dr"]), FULL_HARNESS_LABEL)   # Full Harness: all the Strings I can hold

## The hit landed (_on_hit_taken): what was taken away goes to the enemy at the
## other end. My own healer deals it at once; a party member's is told a few
## times a second (_tick_strung).
func _crossed_taken(info: RefCounted) -> void:
	if _strung.is_empty() or int(info.amount) <= 0 or info.avoided():
		return
	for key in _strung:
		var s: Dictionary = _strung[key]
		var moved := cross_redirect(float(info.amount), float(info.bonus_pct), float(s["cross"]))
		if moved <= 0.0:
			continue
		if is_same(s["from"], self):
			_crossed_damage(self, int(round(moved)))
		else:
			_cross_owed[key] = float(_cross_owed.get(key, 0.0)) + moved

func _tick_strung() -> void:
	if _cross_owed.is_empty():
		return
	var now := _str_now()
	if now - _cross_told < 0.3:
		return
	_cross_told = now
	for key in _cross_owed.keys():
		var amount := int(round(float(_cross_owed[key])))
		var s: Variant = _strung.get(key)
		if amount >= 1 and s != null and is_instance_valid(s["from"]) and _net():
			_net().support_ally(s["from"], self, "cross_dmg", {"amount": amount})
	_cross_owed.clear()

## Still Standing was put on me: for `window` seconds a killing blow is held off.
func _receive_hold(from: Node, data: Dictionary) -> void:
	_stand_until = _str_now() + float(data.get("window", 0.0))
	_stand_hold = float(data.get("hold", 0.0))
	_stand_pct = float(data.get("pct", 0.0))
	if status:
		status.apply(make_still_standing_fx(float(data.get("window", 0.0))), from)

## Damage of `amount` is about to land on me (take_damage). While the Strings
## hold me up nothing takes my last health; and a blow that would kill me while
## Still Standing is on me starts that instead.
func _still_standing_limit(amount: int) -> int:
	if _held_until <= 0.0 and _stand_until <= 0.0:
		return amount
	var now := _str_now()
	if _held_until > now:
		return mini(amount, health - 1)
	if amount >= health and _stand_until > now:
		_stand_until = 0.0
		_held_until = now + _stand_hold
		if status:
			status.remove(STILL_STANDING_FX)
			status.apply(make_held_up_fx(_stand_hold), self)
		_combat().float_text(self, "Held up!", STRING_COLOR, true)
		return health - 1
	return amount

## The Strings let go: I stay up only if I was healed enough meanwhile.
func _tick_still_standing() -> void:
	if _held_until <= 0.0 or _str_now() < _held_until:
		return
	_held_until = 0.0
	_stand_until = 0.0
	if is_alive() and not still_standing_lives(health, max_health, _stand_pct):
		_combat().float_text(self, "The Strings let go", HOUND_COLOR, true)
		take_damage(health)

## Yank: a party member's Strings pull me to `to`.
func _yanked_to(to: Variant) -> void:
	if not (to is Vector3) or is_dead():
		return
	if casting:
		_cancel_cast()
	velocity = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(self, "global_position", to as Vector3, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_combat().float_text(self, "Yanked!", STRING_COLOR, false)

# --- Pacts -----------------------------------------------------------------------------------
# One Pact for the dungeon (scripts/pacts.gd says what each is and changes; the
# choice is PlayerData.pact). Here its bonus and drawback are applied and its
# vow is watched. All of it is this machine's own player: nothing is sent.
#   stats           _raw_stat adds Pacts.stat_mod (Haste, crit, movement, max health and mana)
#   damage          _on_damage_modify -> _pact_outgoing / _pact_incoming (labelled: the meter shows it)
#   cooldowns       _tick_cooldowns x Pacts.cooldown_rate
#   costs           resource_cost x _pact_cost_mult
#   resources       _gain x Pacts.resource_gain_mult
#   healing         heal_taken_mult (CombatSystem.heal asks whoever is healed), _pact_heal_mult on what I cast
#   out of combat   _tick_pact drains the Restless; _tick_health_regen stops for them
# The vows: _go_down and _die (Unbowed), take_damage -> _pact_on_damage (Thin
# Line, Sidestep), use_ability -> _pact_purist_blocks and cast_finished ->
# _pact_on_ability (Purist), heal_done -> _pact_on_heal (Fast), my hits and heals
# -> _pact_acted (Relentless), _tick_pact (Relentless, Restless, Reservoir, and
# every PACT_POLL seconds the party: Shepherd, Vanguard).
# _break_pact ends it for the run (PlayerData.pact_broken): the bonus turns round.

const PACTS = preload("res://scripts/pacts.gd")
const PACT_FX := "pact"       # the buff that shows it (it changes nothing itself)
const PACT_POLL := 0.25       # seconds between looks at the party and at who the enemies are on

var _pact_now := ""           # the Pact that counts right now ("" = none), worked out once a frame
var _pact_now_broken := false
var _pact_frame := -1
var _pact_idle := 0.0         # Relentless: seconds in combat since I last hit an enemy or healed an ally
var _pact_rest := 0.0         # Restless: seconds out of combat
var _pact_fought := false     # ... which only count once I have been in a fight
var _pact_cleared := false    # ... and stop when the dungeon is cleared
var _pact_bleed := 0.0        # ... health lost out of combat that is not a whole point yet
var _pact_poll_at := 0.0
var _pact_downed := {}        # Shepherd: party member instance id -> were they down at the last look
var _pact_on_me := {}         # Vanguard: enemy instance id -> it was attacking me at the last look
var _pact_warned := ""        # Purist: the ability I was warned about ...
var _pact_warned_at := 0.0    # ... and when
var _pact_shown := ""         # what the buff shows ("" = nothing)

func _pact_sync() -> void:
	var frame := Engine.get_process_frames()
	if frame == _pact_frame:
		return
	_pact_frame = frame
	var pd := get_node_or_null("/root/PlayerData")
	var id := str(pd.pact) if pd else ""
	if id != "" and PACTS.party_only(id):
		var net := _net()
		if net == null or not net.with_others():
			id = ""   # a party Pact does nothing alone: no bonus, no drawback, no vow
	_pact_now = id if PACTS.exists(id) else ""
	_pact_now_broken = _pact_now != "" and bool(pd.pact_broken)

## The Pact I hold that counts right now ("" = none).
func pact_id() -> String:
	_pact_sync()
	return _pact_now

func pact_broken() -> bool:
	_pact_sync()
	return _pact_now_broken

func _pact_book() -> String:
	var pd := get_node_or_null("/root/PlayerData")
	return str(pd.pact_book) if pd else ""

func _pact_stat(key: String) -> float:
	var id := pact_id()
	return PACTS.stat_mod(id, _pact_now_broken, key) if id != "" else 0.0

## A hit I deal (_on_damage_modify).
func _pact_outgoing(info: RefCounted) -> void:
	var id := pact_id()
	if id == "":
		return
	var pct := PACTS.damage_dealt_pct(id, _pact_now_broken)
	if pct != 0.0:
		info.add_bonus(pct, PACTS.pact_name(id))

## A hit I take (_on_damage_modify).
func _pact_incoming(info: RefCounted) -> void:
	var id := pact_id()
	if id == "":
		return
	var pct := PACTS.damage_taken_pct(id, _pact_now_broken)
	if pct != 0.0:
		info.add_bonus(pct, PACTS.pact_name(id))

func _pact_cost_mult(res: String) -> float:
	var id := pact_id()
	return PACTS.cost_mult(id, _pact_now_broken, res) if id != "" else 1.0

## What the heals I cast are multiplied by.
func _pact_heal_mult() -> float:
	var id := pact_id()
	return PACTS.heal_done_mult(id, _pact_now_broken) if id != "" else 1.0

## What a heal landing on me is multiplied by (CombatSystem.heal asks).
func heal_taken_mult(source: Node, _ability_id: String = "") -> float:
	var id := pact_id()
	return PACTS.heal_taken_mult(id, _pact_now_broken, is_same(source, self)) if id != "" else 1.0

## The vow was broken: the Pact works against me until the dungeon ends.
func _break_pact(why: String) -> void:
	var id := pact_id()
	if id == "" or _pact_now_broken:
		return
	_pact_frame = -1
	_pact_shown = ""   # (the buff is drawn again, as broken)
	get_node("/root/PlayerData").break_pact()   # (its `changed` re-derives my stats: _on_stats_changed)
	_combat().float_text(self, "%s is broken!" % PACTS.pact_name(id), PACTS.COLOR, true)
	_error("%s is broken" % PACTS.pact_name(id))
	var gl := get_node_or_null("/root/GameLog")
	if gl:
		gl.event("%s is broken: %s. Until the dungeon ends: %s" % [PACTS.pact_name(id), why, PACTS.text(id, "broken")],
			Color(1.0, 0.45, 0.5))

## Unbowed: I went down, or died.
func _pact_on_down() -> void:
	if PACTS.breaks_on_down(pact_id()):
		_break_pact("you went down")

## A hit of `amount` just landed on me (take_damage; my health is already lower).
func _pact_on_damage(amount: int) -> void:
	var id := pact_id()
	if id == "" or _pact_now_broken or not PACTS.breaks_on_hit(id, amount, health, max_health):
		return
	_break_pact("you dropped below %s%% health" % Stats.num(Balance.PACT_THIN_LINE_FLOOR) if id == PACTS.THIN_LINE
		else "one hit took more than %s%% of your health" % Stats.num(Balance.PACT_SIDESTEP_HIT))

## Purist: would using ability `id` break the Pact? The first press only warns;
## pressing it again within PACT_PURIST_CONFIRM seconds goes through.
func _pact_purist_blocks(id: String) -> bool:
	var pact := pact_id()
	if pact == "" or _pact_now_broken or not Abilities.PATHS.has(id):
		return false
	if not PACTS.breaks_on_ability(pact, Abilities.category_of(id), _pact_book(), Abilities.is_trinket_slot(id)):
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if _pact_warned == id and now - _pact_warned_at <= Balance.PACT_PURIST_CONFIRM:
		return false
	_pact_warned = id
	_pact_warned_at = now
	_error("%s would break %s. Use it again to do it anyway." % [Abilities.ability_name(id), PACTS.pact_name(pact)])
	return true

## Purist: an ability of mine went off (SignalBus.cast_finished: instants, and casts as they finish).
func _pact_on_ability(id: String) -> void:
	var pact := pact_id()
	if pact == "" or _pact_now_broken or not Abilities.PATHS.has(id):
		return
	if PACTS.breaks_on_ability(pact, Abilities.category_of(id), _pact_book(), Abilities.is_trinket_slot(id)):
		_break_pact("you used %s" % Abilities.ability_name(id))

## A heal of mine landed (_on_heal_done_strings). Fast: on me, from a spell or an
## ability. Relentless: on someone else counts as doing something.
func _pact_on_heal(healed: Node, id: String) -> void:
	if healed != null and not is_same(healed, self):
		_pact_idle = 0.0
		return
	var pact := pact_id()
	if pact != "" and not _pact_now_broken and PACTS.breaks_on_self_heal(pact, Abilities.PATHS.has(id)):
		_break_pact("you healed yourself with %s" % Abilities.ability_name(id))

## Relentless: a hit of mine landed on an enemy (_on_damage_dealt_shadow, which
## sees every one; damage over time does not count).
func _pact_acted(info: RefCounted) -> void:
	if not bool(info.is_dot):
		_pact_idle = 0.0

## Every frame: the buff that shows the Pact, the vows that are about time, the
## Restless losing health out of combat, and a look at the party now and then.
func _tick_pact(delta: float) -> void:
	var id := pact_id()
	if id == "":
		_pact_show("")
		return
	_pact_show(id + ("!" if _pact_now_broken else ""))
	if is_dead():
		_pact_on_me.clear()   # (dead or down: nothing is counted, and enemies may go where they like)
		return
	if in_combat:
		_pact_fought = true
		_pact_rest = 0.0
		_pact_idle += delta
	else:
		_pact_idle = 0.0
		if _pact_fought and not _pact_cleared:
			_pact_rest += delta
			_pact_bleed_tick(id, delta)
	if _pact_now_broken:
		return
	if PACTS.breaks_on_idle(id, _pact_idle):
		_break_pact("%s sec in combat without hitting an enemy or healing an ally" % Stats.num(Balance.PACT_RELENTLESS_IDLE))
	elif PACTS.breaks_on_rest(id, _pact_rest):
		_break_pact("%s sec out of combat" % Stats.num(Balance.PACT_RESTLESS_IDLE))
	elif PACTS.breaks_on_mana(id, float(resources.get("mana", 0.0)), resource_max("mana")):
		_break_pact("you dropped below %s%% mana" % Stats.num(Balance.PACT_RESERVOIR_FLOOR))
	var now := Time.get_ticks_msec() / 1000.0
	if now >= _pact_poll_at:
		_pact_poll_at = now + PACT_POLL
		_pact_watch_party(id)

## The Restless: health drains out of combat (never the last point), kept or broken.
func _pact_bleed_tick(id: String, delta: float) -> void:
	var pct := PACTS.bleed_pct(id)
	if pct <= 0.0 or health <= 1:
		_pact_bleed = 0.0
		return
	_pact_bleed += float(max_health) * pct / 100.0 * delta
	if _pact_bleed < 1.0:
		return
	var lost := mini(int(_pact_bleed), health - 1)
	_pact_bleed -= int(_pact_bleed)
	if lost > 0:
		health -= lost
		health_changed.emit(health, max_health)
		_bus().player_health_changed.emit(health, max_health)

## Shepherd: did a party member just go down near me? Vanguard: did an enemy
## that was on me turn on one of them?
func _pact_watch_party(id: String) -> void:
	if id == PACTS.SHEPHERD:
		for p in get_tree().get_nodes_in_group("remote_player"):
			if not (p is Node3D):
				continue
			var key: int = p.get_instance_id()
			var down: bool = not p.is_alive()
			var was: Variant = _pact_downed.get(key)
			_pact_downed[key] = down
			if was != null and down and not bool(was) and PACTS.breaks_on_ally_down(id, _flat_dist_to(p.global_position)):
				_break_pact("a party member went down near you")
				return
	elif id == PACTS.VANGUARD:
		var mine := {}
		for e in get_tree().get_nodes_in_group("enemies"):
			if not e.has_method("threat_state_for") or not e.is_alive():
				continue
			var key: int = e.get_instance_id()
			if int(e.threat_state_for(self)) == 2:
				mine[key] = true
			elif _pact_on_me.has(key) and _pact_enemy_on_ally(e) and PACTS.breaks_on_lost_enemy(id):
				_break_pact("an enemy left you for a party member")
				return
		_pact_on_me = mine

## Is enemy `e` attacking another player of my party right now? (On a party
## member's machine the host says who it is on; a decoy or a dummy is nobody.)
func _pact_enemy_on_ally(e: Node) -> bool:
	var net := _net()
	if net == null:
		return false
	if net.is_client():
		var on: Variant = e.get("_net_threat")
		var member := int(on) if on != null else 0
		return member != 0 and member != int(net.my_id()) and net.members.has(member)
	var top: Variant = e.top_threat() if e.has_method("top_threat") else null
	return top != null and is_instance_valid(top) and (top as Node).is_in_group("remote_player")

## Keep the buff that shows the Pact (`key`: the Pact id, with "!" once broken;
## "" = none). Death clears every buff: it is put back when I am up again.
func _pact_show(key: String) -> void:
	if status == null:
		return
	if key == "":
		if _pact_shown != "":
			status.remove(PACT_FX)
			_pact_shown = ""
		return
	if (key == _pact_shown and status.has(PACT_FX)) or is_dead():
		return
	var id := pact_id()
	status.remove(PACT_FX)
	var fx := StatusContainer.make_buff(PACT_FX, PACTS.title(id, _pact_book()) + (" (broken)" if _pact_now_broken else ""), PACT_FX,
		0.0, 1.0e7, 1, PACTS.BROKEN_COLOR if _pact_now_broken else PACTS.COLOR)
	fx.stat_modifiers = {}
	fx.is_debuff = _pact_now_broken
	fx.show_time = false   # (it lasts for the whole dungeon)
	fx.description = PACTS.status_text(id, _pact_now_broken)
	status.apply(fx, self)
	_pact_shown = key

# --- Dusk till Dawn (Legendary rune): Dusk, then Dawn ------------------------------------
# With the rune on my gear, dealing Shadow damage of any kind (damage over time
# and procs too) gives me Dusk: more Shadow damage for DUSK_TIME. Nothing
# refreshes Dusk. When it runs out Dawn starts: more Holy damage for DAWN_TIME.
# Shadow damage starts the next Dusk only once Dawn is over, so the two take
# turns and are never up together. Both are my own buffs. The numbers are in
# balance.gd.

const DUSK_RUNE := "dusk_till_dawn"
const DUSK_ID := "dusk"
const DAWN_ID := "dawn"
const DUSK_COLOR := Color(0.55, 0.4, 0.85)
const DAWN_COLOR := Color(1.0, 0.85, 0.45)
var _dusk_fx: Resource
var _dawn_fx: Resource
var _dusk_until := 0.0   # seconds: when the Dusk I have runs out on its own (0 = I have none)

## Does a hit of mine start Dusk? Any Shadow damage that lands, while I have
## neither Dusk nor Dawn.
static func starts_dusk(damage_type: String, amount: int, has_dusk: bool, has_dawn: bool) -> bool:
	return damage_type == "shadow" and amount > 0 and not has_dusk and not has_dawn

## My Dusk is gone: does Dawn follow? Only when it ran its whole time (not when
## dying or leaving cleared it) and the rune is still on my gear.
static func dawn_follows(now: float, dusk_until: float, has_rune: bool) -> bool:
	return has_rune and dusk_until > 0.0 and now >= dusk_until - 0.25

## Dusk: more Shadow damage of every kind. It runs its time; nothing refreshes it.
static func make_dusk_fx() -> Resource:
	var fx := StatusContainer.make_buff(DUSK_ID, "Dusk", DUSK_ID, 0.0, Balance.DUSK_TIME, 1, DUSK_COLOR)
	fx.stat_modifiers = {}
	fx.stack_mode = 2   # IGNORE
	fx.tags = PackedStringArray(["Shadow"])
	fx.damage_mod_pct = Balance.DUSK_DAMAGE_PCT
	fx.mod_damage_types = PackedStringArray(["shadow"])
	fx.mod_affects_dots = true
	fx.description = "You deal %s%% more Shadow damage. When Dusk ends you gain Dawn." % Stats.num(Balance.DUSK_DAMAGE_PCT)
	return fx

## Dawn: more Holy damage of every kind. No Dusk can start while it lasts.
static func make_dawn_fx() -> Resource:
	var fx := StatusContainer.make_buff(DAWN_ID, "Dawn", DAWN_ID, 0.0, Balance.DAWN_TIME, 1, DAWN_COLOR)
	fx.stat_modifiers = {}
	fx.stack_mode = 2   # IGNORE
	fx.tags = PackedStringArray(["Holy"])
	fx.damage_mod_pct = Balance.DAWN_DAMAGE_PCT
	fx.mod_damage_types = PackedStringArray(["holy"])
	fx.mod_affects_dots = true
	fx.description = "You deal %s%% more Holy damage. Dusk cannot start until Dawn ends." % Stats.num(Balance.DAWN_DAMAGE_PCT)
	return fx

## A hit of mine landed (called for every one, from _on_damage_dealt_shadow).
func _dusk_on_hit(info: RefCounted) -> void:
	if status == null or not _has_rune(DUSK_RUNE):
		return
	var has_dusk: bool = _dusk_until > 0.0 or status.has(DUSK_ID)
	if not starts_dusk(str(info.damage_type), int(info.amount), has_dusk, status.has(DAWN_ID)):
		return
	if _dusk_fx == null:
		_dusk_fx = make_dusk_fx()
	if status.apply(_dusk_fx, self):
		_dusk_until = Time.get_ticks_msec() / 1000.0 + float(status.remaining_of(DUSK_ID))

## Every frame: the moment my Dusk runs out, Dawn starts.
func _tick_dusk() -> void:
	if _dusk_until <= 0.0 or status == null or status.has(DUSK_ID):
		return
	var until := _dusk_until
	_dusk_until = 0.0
	if not dawn_follows(Time.get_ticks_msec() / 1000.0, until, _has_rune(DUSK_RUNE)):
		return
	if _dawn_fx == null:
		_dawn_fx = make_dawn_fx()
	status.apply(_dawn_fx, self)

# --- Smoldering Focus and Afterburn (Fire talents) ---------------------------------------
# Smoldering Focus (was a Legendary rune): every Fire spell hit that does NOT
# crit builds a stack of the buff (data/effects/smoldering_focus.tres: stacks,
# duration, "next Fire spell crit spends them"). The talent's rank sets what a
# stack is worth: crit chance x 0.1 per rank.
# Afterburn is its mirror image (data/effects/afterburn.tres): every Fire spell
# hit that DOES crit builds a stack, the next Fire spell hit that doesn't crit
# spends them, and a stack is worth (100 - crit chance) x 0.1 per rank.
# For both, proc hits count and damage-over-time ticks don't.

var _smolder_fx: Resource   # my own copy of each buff (its factor follows the talent rank)
var _afterburn_fx: Resource

func _on_damage_dealt_fire(info: RefCounted) -> void:
	if not is_same(info.source, self) or info.avoided() or info.is_dot or status == null:
		return
	var tags: PackedStringArray = info.tags if not info.tags.is_empty() else Abilities.tags_of(str(info.ability_id))
	_cool_head_on_hit(info, tags)
	_fuse_on_hit(info)
	_slag_on_hit(info, tags)
	_heat_on_hit(info, tags)
	_afterglow_on_hit(info)
	_static_on_hit(info, tags)
	if str(info.damage_type) != "fire" or not tags.has("Spell") or int(info.amount) <= 0:
		return   # (effect-only hits like Immolate landing build nothing)
	if info.no_empower:
		return   # passive damage (the Slag kit) builds nothing either
	if not info.crit:
		_pressure_valve(info)
		_banked_mana(info)
	if info.crit:
		var burn := _talent("fire_afterburn")
		if burn > 0.0:
			_afterburn_fx = _stack_scaled_fx(_afterburn_fx, "afterburn", burn,
				"Your next Fire spell hit that does not critically strike deals ((100 - critical strike chance) x %s)%% more damage per stack.")
	else:
		var factor := _talent("fire_smoldering_focus")
		if factor > 0.0:
			_smolder_fx = _stack_scaled_fx(_smolder_fx, "smoldering_focus", factor,
				"Your next Fire spell critical strike deals (critical strike chance x %s)%% more damage per stack.")

## Add a stack of a talent buff whose scale factor follows the talent's rank.
## `mine` = my own copy of data/effects/<id>.tres (made on first use); returns it.
func _stack_scaled_fx(mine: Resource, id: String, factor: float, text: String) -> Resource:
	if mine == null:
		var base: Resource = preload("res://scripts/core/effects.gd").get_effect(id)
		if base == null:
			return null
		mine = base.duplicate()
		mine.mod_scale_factor = -1.0   # so the first use fills in the text
	if not is_equal_approx(float(mine.mod_scale_factor), factor):
		mine.mod_scale_factor = factor
		mine.description = text % str(snappedf(factor, 0.01))
	status.apply(mine, self)
	return mine

# --- Auto-target -----------------------------------------------------------------------
# Using something that needs an enemy target while you have none picks the
# closest enemy it could legally be used on: alive, in range and in line of sight
# (and, for Stoke and Rekindle, with one of your burns to work on).

func _needs_enemy_target(id: String) -> bool:
	if id in SUPPORT_CASTS or Abilities.is_trinket_slot(id):
		return false
	var res := Abilities.get_resource(id)
	return res != null and bool(res.requires_target)

## Could ability `id` reach enemy `e` from here? (target_in_range, for any enemy.)
func _in_ability_range(id: String, e: Node3D) -> bool:
	var res := Abilities.get_resource(id)
	if Abilities.uses_weapon_reach(id):
		var w := _weapon()
		return w.has("attack_range") and _in_weapon_range(e, float(w["attack_range"]))
	if float(res.cast_range) > 0.0:
		return global_position.distance_to(e.global_position) <= float(res.cast_range)
	return true

func _auto_target(id: String) -> void:
	if _has_valid_target() or not _needs_enemy_target(id):
		return
	var best: Node3D = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D) or not e.is_alive():
			continue
		if not _in_ability_range(id, e) or _target_error(e) != "":
			continue
		if id == "stoke":
			var est: Node = e.get_node_or_null("Status")
			if est == null or not est.has_from("burning", self):
				continue
		if id == "rekindle" and _rekindle_targets(e).is_empty():
			continue
		if (id == CALL_DUE_ID or id == SPILL_ID or id == TAKE_IT_BACK_ID) and decay_on(e) <= 0.0:
			continue   # (these work on my Decay: an enemy without it is no use)
		var d := global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best:
		_set_target(best)

# --- Slow Fuse: a charge that grows with your hits, then explodes ---------------------
# One charge per enemy. It explodes SLOW_FUSE_TIME seconds after it was planted
# for the ability's damage + SLOW_FUSE_GROW per growth. Your direct hits on
# that enemy grow it (not damage over time, not the explosion itself): without
# the Volatile Fuse talent every hit that doesn't crit does; the talent moves
# that over to Fire crits (fuse_grow_chance). Planting again on the same enemy
# sets the old charge off first.

const FUSE_FX_ID := "slow_fuse"
var _fuses := {}   # enemy instance id -> {"target": Node3D, "grows": int, "at": explode time, "base": float}

## Chance (%) that a direct hit grows your Slow Fuse. `talent_pct` = Volatile Fuse (0 = not taken).
static func fuse_grow_chance(crit: bool, is_fire: bool, talent_pct: float) -> float:
	if crit:
		return talent_pct if is_fire else 0.0
	return clampf(100.0 - talent_pct, 0.0, 100.0)

## The explosion (as a coefficient) of a charge that grew `grows` times.
static func fuse_size(base: float, grows: int) -> float:
	return base + Balance.SLOW_FUSE_GROW * clampi(grows, 0, Balance.SLOW_FUSE_MAX_GROWS)

func _plant_fuse(tgt: Node3D) -> void:
	if tgt == null or not is_instance_valid(tgt) or not tgt.is_alive():
		return
	var key := tgt.get_instance_id()
	if _fuses.has(key):
		_explode_fuse(key)   # the old charge goes off now
		if not is_instance_valid(tgt) or not tgt.is_alive():
			return
	_fuses[key] = {"target": tgt, "grows": 0, "base": float(Abilities.get_resource("slowfuse").damage),
		"at": Time.get_ticks_msec() / 1000.0 + Balance.SLOW_FUSE_TIME}
	# The debuff shows the charge and its size to the whole party.
	_apply_effect_hit(tgt, preload("res://scripts/core/effects.gd").get_effect(FUSE_FX_ID), "slowfuse",
		PackedStringArray(["Fire", "Spell"]))
	_ring_effect(0.8, Abilities.color_of("slowfuse"), tgt.global_position)

## A direct hit of mine landed (called for every one): it may grow the charge on that enemy.
func _fuse_on_hit(info: RefCounted) -> void:
	if _fuses.is_empty() or int(info.amount) <= 0 or str(info.ability_id) == "slowfuse":
		return
	if int(info.part) == 1:
		return   # a split hit (Frostfire Bolt) is one hit: its Fire half is the one that counts here
	if info.target == null or not is_instance_valid(info.target):
		return
	var key: int = info.target.get_instance_id()
	if not _fuses.has(key):
		return
	var f: Dictionary = _fuses[key]
	if int(f["grows"]) >= Balance.SLOW_FUSE_MAX_GROWS:
		return
	var chance := fuse_grow_chance(bool(info.crit), str(info.damage_type) == "fire", _talent("fire_fuse_crit"))
	if chance <= 0.0 or randf() * 100.0 >= chance:
		return
	f["grows"] = int(f["grows"]) + 1
	var net := _net()
	if net:
		net.set_effect_stacks(info.target, self, FUSE_FX_ID, int(f["grows"]) + 1)   # enemy effects live on the host
	else:
		var st: Node = info.target.get_node_or_null("Status")
		if st:
			st.set_stacks_from(FUSE_FX_ID, self, int(f["grows"]) + 1)

func _tick_fuses() -> void:
	if _fuses.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	for key in _fuses.keys():
		var f: Dictionary = _fuses[key]
		if not is_instance_valid(f["target"]) or not f["target"].is_alive():
			_fuses.erase(key)
		elif now >= float(f["at"]):
			_explode_fuse(key)

func _explode_fuse(key: int) -> void:
	var f: Dictionary = _fuses[key]
	_fuses.erase(key)
	var tgt: Variant = f["target"]
	if not is_instance_valid(tgt) or not tgt.is_alive():
		return
	var net := _net()
	if net:
		net.remove_effect(tgt, self, FUSE_FX_ID)
	else:
		var st: Node = tgt.get_node_or_null("Status")
		if st:
			st.remove_from(FUSE_FX_ID, self)
	_ring_effect(1.6, Abilities.color_of("slowfuse"), tgt.global_position)
	_ring_effect(0.9, Color(1.0, 0.9, 0.4), tgt.global_position)
	_flashover(tgt)   # (before the blast: the target may not survive it)
	deal_damage(tgt, fuse_size(float(f["base"]), int(f["grows"])), "slowfuse", true)

## Flashover talent: Slow Fuse going off on a target with my Immolate may set
## each other enemy near it alight too.
func _flashover(tgt: Node3D) -> void:
	var chance := _talent("fire_flashover")
	if chance <= 0.0:
		return
	var st: Node = tgt.get_node_or_null("Status")
	if st == null or not st.has_from("immolate", self):
		return
	for e in _enemies_near(tgt.global_position, Balance.IMMOLATE_SPREAD_RADIUS, tgt):
		if randf() * 100.0 < chance:
			deal_damage(e, 0.0, "immolate", true)   # no damage: just its on-hit effect
			_ring_effect(0.7, Abilities.color_of("immolate"), e.global_position)

## Put status effect `res` on an enemy as a hit with no damage. It goes through
## the combat pipeline, so in a party it reaches the host (who owns enemy
## effects) exactly like an effect from a real hit. It can't be blocked or crit.
func _apply_effect_hit(e: Node, res: Resource, ability_id: String, tags: PackedStringArray,
		damage_type: String = "fire") -> void:
	if res == null or e == null or not is_instance_valid(e) or not e.is_alive():
		return
	var info := DamageInfo.make(self, e, 0.0, ability_id)
	info.damage_type = damage_type
	info.tags = tags if not tags.is_empty() else PackedStringArray(["Fire", "Spell"])
	info.is_proc = true
	info.can_crit = false
	info.can_block = false
	info.effects.append(res)
	_combat().deal(info)

# --- Rekindle: refresh my burns around the target ------------------------------------

## Enemies within REKINDLE_RADIUS of `tgt` (and `tgt` itself) that carry one of my burns.
func _rekindle_targets(tgt: Node3D) -> Array:
	var out: Array = []
	if tgt == null or not is_instance_valid(tgt):
		return out
	var around: Array = [tgt]
	around.append_array(_enemies_near(tgt.global_position, Balance.REKINDLE_RADIUS, tgt))
	for e in around:
		var st: Node = e.get_node_or_null("Status")
		if st == null:
			continue
		for fx_id in Balance.REKINDLE_EFFECTS:
			if st.has_from(str(fx_id), self):
				out.append(e)
				break
	return out

func _rekindle(tgt: Node3D) -> void:
	var Effects = preload("res://scripts/core/effects.gd")
	for e in _rekindle_targets(tgt):
		var st: Node = e.get_node_or_null("Status")
		for fx_id in Balance.REKINDLE_EFFECTS:
			var res: Resource = Effects.get_effect(str(fx_id))
			if res == null or not st.has_from(str(fx_id), self):
				continue
			# Applying my own burn again starts it over at full duration.
			var entry: Dictionary = st.effects.get(StatusContainer.key_for(res, self), {})
			_apply_effect_hit(e, res, "rekindle", entry.get("tags", PackedStringArray()))
		_ring_effect(0.7, Abilities.color_of("rekindle"), e.global_position)
	if is_instance_valid(tgt):
		_ring_effect(Balance.REKINDLE_RADIUS, Abilities.color_of("rekindle"), tgt.global_position)

# --- Wall of Fire -----------------------------------------------------------------------
# A cast: the wall goes across your target (if you have one in range and in
# sight) or FIRE_WALL_DISTANCE in front of you, side-on to you. Where it goes is
# fixed when the cast starts. The wall itself is scripts/fire_wall.gd.

const FIRE_WALL = preload("res://scripts/fire_wall.gd")
var _wall_yaw := 0.0

func _start_fire_wall() -> void:
	var id := "walloffire"
	if casting or not is_on_floor():
		return
	if cooldown_left(id) > 0.0:
		_error("%s is not ready yet" % Abilities.ability_name(id))
		return
	if not can_afford(id, true):
		return
	var res := Abilities.get_resource(id)
	var fwd := _flat_forward()
	var centre := global_position + fwd * Balance.FIRE_WALL_DISTANCE
	var floor_y := Combat.feet_y(self)
	if _has_valid_target() and can_see(target) \
			and global_position.distance_to(target.global_position) <= float(res.cast_range):
		centre = target.global_position
		floor_y = Combat.feet_y(target)
	var dir := centre - global_position
	dir.y = 0.0
	if dir.length() < 0.5:
		dir = fwd
	_wall_yaw = atan2(-dir.x, -dir.z)   # the wall's length runs across this direction
	cast_point = Vector3(centre.x, floor_y, centre.z)
	_begin_spell(id, str(res.display_name), float(res.cast_time))

func _raise_fire_wall() -> void:
	var res := Abilities.get_resource("walloffire")
	cooldowns["walloffire"] = float(res.cooldown)
	var wall := Node3D.new()
	wall.set_script(FIRE_WALL)
	wall.length = float(res.radius) * 2.0
	wall.depth = Balance.FIRE_WALL_DEPTH
	wall.duration = Balance.FIRE_WALL_TIME
	wall.tick = maxf(Balance.FIRE_WALL_TICK / haste_mult(), 0.1)
	wall.damage = float(res.damage)
	wall.tags = res.tags
	wall.source = self
	get_tree().current_scene.add_child(wall)
	wall.global_position = cast_point
	wall.rotation.y = _wall_yaw
	_net_fx("firewall", cast_point, null, {"yaw": _wall_yaw, "len": wall.length, "depth": wall.depth, "time": wall.duration})

# --- Immolate: recasting it on a target that has yours spreads it ---------------------

func _immolate_spread(tgt: Node3D) -> void:
	var st: Node = tgt.get_node_or_null("Status") if is_instance_valid(tgt) else null
	if st == null or not st.has_from("immolate", self):
		return
	# The closest enemies around the target; ones without my Immolate first.
	var fresh: Array = []
	var burning: Array = []
	for e in _enemies_near(tgt.global_position, Balance.IMMOLATE_SPREAD_RADIUS, tgt):
		var est: Node = e.get_node_or_null("Status")
		if est and est.has_from("immolate", self):
			burning.append(e)
		else:
			fresh.append(e)
	for e in (fresh + burning).slice(0, Balance.IMMOLATE_SPREAD_TARGETS):
		deal_damage(e, 0.0, "immolate", true)   # no damage: just its on-hit effect
		_ring_effect(0.7, Abilities.color_of("immolate"), e.global_position)

# --- Hair Trigger rune: Vent Flames has charges ---------------------------------------
# Without the rune Vent Flames uses its plain cooldown. With it there are
# HAIR_TRIGGER_CHARGES charges, recharging one after the other; the button's
# cooldown only shows while no charge is left.

const VENT_ID := "ventflames"
var _vent_charges := Balance.HAIR_TRIGGER_CHARGES
var _vent_recharge := 0.0   # seconds until the next charge (0 = all charges ready)
var _vent_cd := 10.0

func _vent_max() -> int:
	return Balance.HAIR_TRIGGER_CHARGES if _has_rune("hair_trigger") else 1

func _vent_charge_used(cd: float) -> void:
	if _vent_max() <= 1:
		return
	_vent_cd = cd
	_vent_charges = maxi(mini(_vent_charges, _vent_max()) - 1, 0)
	if _vent_recharge <= 0.0:
		_vent_recharge = cd
	if _vent_charges > 0:
		cooldowns.erase(VENT_ID)
	else:
		cooldowns[VENT_ID] = _vent_recharge

func _tick_vent_charges(delta: float) -> void:
	if _vent_recharge <= 0.0:
		return
	_vent_recharge -= delta
	if _vent_recharge <= 0.0:
		_vent_charges = mini(_vent_charges + 1, maxi(_vent_max(), 1))
		_vent_recharge = _vent_cd if _vent_charges < _vent_max() else 0.0

## Take `seconds` off Vent Flames' cooldown (with Hair Trigger: off the charge
## that is recharging).
func _vent_reduce(seconds: float) -> void:
	if seconds <= 0.0:
		return
	if _vent_max() > 1:
		if _vent_recharge > 0.0:
			_vent_recharge = maxf(_vent_recharge - seconds, 0.01)
			if cooldowns.has(VENT_ID):
				cooldowns[VENT_ID] = _vent_recharge
	elif cooldowns.has(VENT_ID):
		cooldowns[VENT_ID] = vent_after_cut(float(cooldowns[VENT_ID]), seconds)

## Cooldown left after Pressure Valve takes `cut` seconds off `left`.
static func vent_after_cut(left: float, cut: float) -> float:
	return maxf(left - cut, 0.0)

var _valve_last := ""   # "<ability>@<frame>" of the last spell that fed Pressure Valve

## Pressure Valve talent: a Fire spell of mine just failed to crit. Once per
## use, however many enemies it hit (an Ember Volley counts once); not procs.
func _pressure_valve(info: RefCounted) -> void:
	var cut := _talent("fire_pressure_valve")
	if cut <= 0.0 or info.is_proc:
		return
	var key := "%s@%d" % [str(info.ability_id), Engine.get_process_frames()]
	if str(info.ability_id) == "embervolley":
		key = "embervolley#%d" % _volley_serial
	if key == _valve_last:
		return
	_valve_last = key
	_vent_reduce(cut)

var _banked_mana_last := ""   # "<ability>@<frame>" of the last spell that fed Banked Mana

## Mana a spell that cost `cost` gives back with Banked Mana at `pct` percent.
static func banked_mana_refund(cost: float, pct: float) -> float:
	return maxf(cost, 0.0) * maxf(pct, 0.0) / 100.0

## Banked Mana talent: a Fire spell of mine just failed to crit, so part of its
## mana cost comes back. Once per use, however many enemies it hit (an Ember
## Volley counts once); not procs, not ticks, not spells that cost no mana.
func _banked_mana(info: RefCounted) -> void:
	var pct := _talent("fire_banked_mana")
	if pct <= 0.0 or info.is_proc:
		return
	var id := str(info.ability_id)
	if Abilities.resource_of(id) != "mana":
		return
	var key := "%s@%d" % [id, Engine.get_process_frames()]
	if id == "embervolley":
		key = "embervolley#%d" % _volley_serial
	if key == _banked_mana_last:
		return
	_banked_mana_last = key
	var back := banked_mana_refund(resource_cost(id), pct)
	if back > 0.0:
		_gain("mana", back)

## Is one of my burns (Balance.REKINDLE_EFFECTS: Immolate, Burning) on `enemy`? (Warm Blood)
func _my_burn_on(enemy: Variant) -> bool:   # untyped: may be a freed enemy
	if enemy == null or not is_instance_valid(enemy) or not (enemy is Node):
		return false
	var st: Node = enemy.get_node_or_null("Status")
	if st == null:
		return false
	for fx_id in Balance.REKINDLE_EFFECTS:
		if st.has_from(str(fx_id), self):
			return true
	return false

## Number shown on an action-bar button with charges ("" = none).
func charges_text(id: String) -> String:
	if id == "iceshards":
		return str(int(ice_shard_charges))
	if id == VENT_ID and _vent_max() > 1:
		return str(clampi(_vent_charges, 0, _vent_max()))
	if heat_needed(id) > 0:
		return str(heat_stacks())   # Quench / Flare: the Heat you hold
	if id == FULL_SET_ID or id == TRADE_PLACES_ID or (id == DECOY_ID and decoy_needs_reflection()):
		return str(reflections())   # the Reflections you have (to fill up, or to spend)
	if id == ENCORE_ID:
		return str(traces())   # the Traces it would replay
	if id == STRING_ID:
		return str(string_charges())   # the Strings in your hand
	if verses_text(id) != "":
		return verses_text(id)   # Holy healer: the Verses you hold
	if id == CONVERGENCE_ID:
		# Convergence: the Arcane spells on cooldown that would count right now.
		var running := mini(arcane_cooldowns(CONVERGENCE_ID), Balance.CONVERGENCE_MAX)
		return str(running) if running > 0 else ""
	return ""

# --- Banked Coals (Fire talent) ----------------------------------------------------------

## Stacks left after `stacks` are spent with Banked Coals at `pct` percent (rounded down).
static func banked_stacks(stacks: int, pct: float) -> int:
	return int(floor(stacks * pct / 100.0 + 0.0001))

## The StatusContainer asks when a "consume on use" buff of mine is used up:
## Banked Coals keeps part of the Smoldering Focus / Afterburn stacks.
func stacks_kept_on_use(res: Resource, stacks: int) -> int:
	var id := str(res.id)
	if id != "smoldering_focus" and id != "afterburn":
		return 0
	return banked_stacks(stacks, _talent("fire_banked_coals"))

# --- Ember Volley (Fire channel) ------------------------------------------------------
# A channel that launches EMBER_VOLLEY_HITS embers, spread evenly over it (so
# Haste makes them come faster). Each ember is its own hit with its own crit
# roll. Paid for, and put on cooldown, when the channel starts.

var _volley_left := 0      # embers still to launch this channel
var _volley_dmg := 0.0
var _volley_serial := 0    # counts channels (Cool Head gives one stack per channel)

func _start_ember_volley() -> void:
	var id := "embervolley"
	if casting or not is_on_floor():
		return
	if cooldown_left(id) > 0.0:
		_error("%s is not ready yet" % Abilities.ability_name(id))
		return
	if not _has_valid_target():
		_error("No target")
		return
	var res := Abilities.get_resource(id)
	if res.cast_range > 0.0 and global_position.distance_to(target.global_position) > res.cast_range:
		_error("Target out of range")
		return
	var sight_err := _target_error(target)
	if sight_err != "":
		_error(sight_err)
		return
	var instant := concentrated_fire_ready(id)
	if not _pay(id):
		return
	cooldowns[id] = float(res.cooldown)
	_volley_dmg = float(res.damage)
	_volley_serial += 1
	if instant:
		# Concentrated Fire: no channel, the whole volley goes out in a quick burst.
		status.spend_stacks(CONC_ID)
		var tgt := target
		for i in Balance.EMBER_VOLLEY_HITS:
			get_tree().create_timer(Balance.EMBER_VOLLEY_BURST_GAP * i).timeout.connect(func():
				if is_alive() and is_instance_valid(tgt) and tgt.is_alive():
					_launch_ember(tgt))
		_bus().cast_finished.emit(id)   # an instant: starts the global cooldown like one
		return
	_begin_spell(id, str(res.display_name), float(res.cast_time), true)
	_volley_left = Balance.EMBER_VOLLEY_HITS if casting and current_spell == id else 0

## One ember at `tgt`, plus one at each extra enemy near it (Scattered Embers talent).
func _launch_ember(tgt: Node3D) -> void:
	var scene := get_tree().current_scene
	FROST_BOLT.spawn(scene, _muzzle(), tgt, self, false, "embervolley", _volley_dmg)
	var extra := int(_talent("fire_volley_targets"))
	if extra <= 0:
		return
	var others := _enemies_near(tgt.global_position, Balance.EMBER_VOLLEY_SPLIT_RADIUS, tgt).filter(
		func(e): return can_see(e))
	for e in others.slice(0, extra):
		FROST_BOLT.spawn(scene, _muzzle(), e, self, false, "embervolley", _volley_dmg)

## Launch every ember that is due by now (`final` = all that are left).
func _ember_volley_tick(final: bool = false) -> void:
	if _volley_left <= 0:
		return
	var hits := Balance.EMBER_VOLLEY_HITS
	var due := hits
	if not final:
		var every := maxf(cast_duration / hits, 0.01)
		due = mini(int(floor((cast_duration - maxf(cast_timer, 0.0)) / every + 0.0001)), hits)
	while hits - _volley_left < due:
		_volley_left -= 1
		if _has_valid_target():
			_launch_ember(target)

# --- Furnace Breath (cone) and Slag Skin (armor + burns attackers) ---------------------

## Is the point `to` (relative to you) inside a cone `arc_deg` wide around `forward`?
## Flat (height ignored). Something right on top of you always counts.
static func in_cone(forward: Vector3, to: Vector3, arc_deg: float) -> bool:
	var f := Vector2(forward.x, forward.z)
	var d := Vector2(to.x, to.z)
	if d.length() < 0.5 or f.length() < 0.001:
		return true
	return absf(rad_to_deg(f.angle_to(d))) <= arc_deg * 0.5 + 0.001

## Visible enemies within `radius` and inside a cone `arc_deg` wide in front of you.
func _enemies_in_cone(radius: float, arc_deg: float) -> Array:
	var fwd := _flat_forward()
	return _enemies_within(radius).filter(func(e): return in_cone(fwd, e.global_position - global_position, arc_deg))

const SLAG_ID := "slagskin"
var _slag_hit_at := {}   # attacker instance id -> last time Slag Skin burned it

## Slag Skin: an enemy whose attack reaches you (hit or blocked; not damage over
## time) is burned, at most once per SLAG_SKIN_ICD seconds each.
func _slag_skin_retaliate(info: RefCounted) -> void:
	if not is_same(info.target, self) or info.is_dot or status == null or not status.has(SLAG_ID) or is_dead():
		return
	var foe: Variant = info.source
	if foe == null or not is_instance_valid(foe) or not (foe is Node) or not foe.is_in_group("enemies") or not foe.is_alive():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var key: int = foe.get_instance_id()
	if now - float(_slag_hit_at.get(key, -100.0)) < Balance.SLAG_SKIN_ICD:
		return
	_slag_hit_at[key] = now
	var burn := float(Abilities.get_resource(SLAG_ID).damage)
	if info.blocked:
		burn = block_burn(burn, _talent("fire_hot_iron"))   # Hot Iron
	# Passive damage: it never builds or spends Smoldering Focus / Afterburn.
	var back = _combat().ability_hit_info(self, foe, burn, SLAG_ID, true)
	back.no_empower = true
	_combat().deal(back)

# --- Slag (the Fire tank's armor) ---------------------------------------------------------
# While Slag Skin is up, each melee hit of mine that doesn't crit adds a stack of
# Slag (armor per stack; once per use, however many enemies it hit). A melee crit
# shatters every stack as Fire damage around me. Slag lasts exactly as long as
# Slag Skin does, so letting Slag Skin drop loses it.

const SLAG_STACK_ID := "slag"
var _slag_fx: Resource
var _slag_last := ""   # "<ability>@<frame>" of the last hit that added a stack

## Armor one Slag stack gives, in flat units, with Thick Slag at `talent_pct`.
static func slag_armor(talent_pct: float) -> float:
	return Balance.SLAG_ARMOR * (1.0 + talent_pct / 100.0)

## Damage coefficient of `stacks` Slag shattering.
static func slag_shatter_coef(stacks: int) -> float:
	return float(Balance.EXTRA_HITS["slagskin"]) * maxi(stacks, 0)

## Retaliation damage for an attack that was blocked, with Hot Iron at `hot_iron_pct`.
static func block_burn(base: float, hot_iron_pct: float) -> float:
	return base * (1.0 + hot_iron_pct / 100.0)

## Slag stacks run out together with Slag Skin.
func _sync_slag() -> void:
	if status and status.has(SLAG_STACK_ID):
		status.set_remaining(SLAG_STACK_ID, status.remaining_of(SLAG_ID))

func _slag_stack_fx() -> Resource:
	var per := slag_armor(_talent("fire_thick_slag")) * _flat_unit()
	if _slag_fx == null or not is_equal_approx(float(_slag_fx.stat_modifiers.get(Stats.ARMOR, 0.0)), per):
		_slag_fx = StatusContainer.make_buff(SLAG_STACK_ID, "Slag", Stats.ARMOR, per,
			Balance.SLAG_SKIN_TIME, Balance.SLAG_MAX_STACKS, Color(0.75, 0.45, 0.3))
		_slag_fx.description = "Hardened slag: Armor per stack. A melee critical strike of yours shatters it."
	return _slag_fx

## A hit of mine landed: melee hits (not procs) build or shatter Slag.
func _slag_on_hit(info: RefCounted, tags: PackedStringArray) -> void:
	if info.is_proc or int(info.amount) <= 0 or not tags.has("Melee") or not status.has(SLAG_ID):
		return
	if info.crit:
		_slag_shatter()
		return
	var key := "%s@%d" % [str(info.ability_id), Engine.get_process_frames()]
	if key == _slag_last:
		return   # the same swing hitting another enemy
	_slag_last = key
	status.apply(_slag_stack_fx(), self)
	_sync_slag()

func _slag_shatter() -> void:
	var stacks: int = status.stacks_of(SLAG_STACK_ID)
	if stacks <= 0:
		return
	status.remove(SLAG_STACK_ID)
	# Slag Mending: the breaking slag heals me, per stack.
	var mend := slag_mending_heal(max_health, stacks, _talent("fire_slag_mending"))
	if mend > 0:
		_combat().heal(self, self, float(mend), "slag_mending", true)
	var coef := slag_shatter_coef(stacks)
	var tags := PackedStringArray(["Fire", "Spell", "AoE"])
	var hit := _enemies_within(Balance.SLAG_SHATTER_RADIUS)
	var share := Balance.aoe_share(hit.size())
	for e in hit:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		# (A proc: it never feeds Cool Head, Pressure Valve or hit-counting runes.)
		var info := DamageInfo.make(self, e, coef * share, "slag_shatter")
		info.tags = tags
		info.damage_type = "fire"
		info.threat_multiplier = Balance.SLAG_SHATTER_THREAT
		info.is_proc = true
		# Passive damage: a shatter must not spend a full stack of Smoldering Focus
		# (one crit did 15x a normal shatter that way) or build it / Afterburn.
		info.no_empower = true
		_combat().deal(info)
	_ring_effect(Balance.SLAG_SHATTER_RADIUS, Abilities.color_of(SLAG_ID))
	_ring_effect(Balance.SLAG_SHATTER_RADIUS * 0.6, Color(0.25, 0.2, 0.18))
	# Smoldering Debris talent: the broken slag keeps burning where I stand. Each
	# tick is that share of what the shatter did to each enemy (before its crit;
	# ticks roll their own crit like any periodic damage).
	var debris := _talent("fire_clinker")
	if debris > 0.0:
		var side := Balance.CLINKER_RADIUS * 2.0
		_fire_patch(Vector3(global_position.x, Combat.feet_y(self), global_position.z), rotation.y, side, side,
			Balance.CLINKER_TIME, Balance.CLINKER_TICK, debris_tick_coef(coef * share, debris), tags, DEBRIS_ID, true)

## Meter / log id of the Smoldering Debris patch (its ticks are "dot_" + this).
const DEBRIS_ID := "smoldering_debris"

## Coefficient of one Smoldering Debris tick: `pct` percent of the shatter's hit.
static func debris_tick_coef(shatter_coef_per_enemy: float, pct: float) -> float:
	return shatter_coef_per_enemy * pct / 100.0

## A strip (or square) of fire on the ground: `damage` to enemies standing in it
## every `tick` seconds, as periodic Fire damage of mine. Its length runs along
## its local X axis. Party members get the picture; the damage is dealt here.
func _fire_patch(at: Vector3, yaw: float, length: float, depth: float, time: float, tick: float,
		damage: float, tags: PackedStringArray, effect_id: String, passive: bool = false) -> void:
	var patch := Node3D.new()
	patch.set_script(FIRE_WALL)
	patch.length = length
	patch.depth = depth
	patch.duration = time
	patch.tick = maxf(tick / haste_mult(), 0.1)
	patch.damage = damage
	patch.tags = tags
	patch.effect_id = effect_id
	patch.passive = passive
	patch.source = self
	get_tree().current_scene.add_child(patch)
	patch.global_position = at
	patch.rotation.y = yaw
	_net_fx("firewall", at, null, {"yaw": yaw, "len": length, "depth": depth, "time": time})

# --- Cinder Guard and Brand (Fire tank) ------------------------------------------------------

const CINDER_GUARD_ID := "cinder_guard"
const BRAND_FX_ID := "branded"

# --- Heat (Fire melee) ------------------------------------------------------------------------
# Every melee hit of mine (auto-attacks and abilities; not procs, not ticks) on a
# target carrying MY Immolate builds a stack of Heat: once per swing, however
# many enemies it hit. Searing Strike builds SEARING_STRIKE_HEAT (Kindling may add
# one more). Each stack makes my Fire ABILITIES (not spells) hit harder. A new
# stack restarts the HEAT_TIME timer; when that runs out all of it is lost. Crits
# play no part. Flare spends some, Quench removes it all for bonus damage.
# Only my own Immolate counts: another player's never builds my Heat.

const HEAT_ID := "heat"
const AFTERGLOW_ID := "afterglow"
var _heat_fx: Resource
var _heat_last := ""   # "<ability>@<frame>" of the last swing that built Heat

func heat_stacks() -> int:
	return int(status.stacks_of(HEAT_ID)) if status else 0

## Heat an ability needs to be used (Quench, Flare); 0 for everything else.
static func heat_needed(id: String) -> int:
	match id:
		"quench":
			return Balance.QUENCH_MIN_HEAT
		"flare":
			return Balance.FLARE_HEAT_COST
	return 0

## Heat one swing of `ability_id` builds on a target with my Immolate (before Kindling).
static func heat_from(ability_id: String) -> int:
	if heat_needed(ability_id) > 0:
		return 0   # the Heat spenders build none
	return Balance.SEARING_STRIKE_HEAT if ability_id == "searingstrike" else 1

## White Heat (Fire talent): % more Fire damage my abilities deal while I hold
## `stacks` Heat, at `pct` per its rank. Only at the very top: one stack short is nothing.
static func white_heat_bonus(stacks: int, pct: float) -> float:
	return pct if stacks >= Balance.HEAT_MAX_STACKS else 0.0

## Quench's damage coefficient with `heat` stacks removed.
static func quench_coef(base: float, heat: int) -> float:
	return base * (1.0 + Balance.QUENCH_PCT_PER_HEAT / 100.0 * maxi(heat, 0))

## An Immolate with `left` seconds to go, fed `add` more: never above its base duration.
static func tinder_time(left: float, add: float, base: float) -> float:
	return minf(left + add, maxf(base, left))

## Fire damage Afterglow adds to an auto-attack that dealt `amount`.
static func afterglow_damage(amount: int, pct: float) -> float:
	return maxf(float(amount) * pct / 100.0, 0.0)

## Colour of a weapon swing at `stacks` Heat: steel, then orange, white-hot at the cap.
static func heat_tint(stacks: int) -> Color:
	var cold := Color(0.9, 0.95, 1.0)
	if stacks <= 0:
		return cold
	var t := clampf(float(stacks) / float(maxi(Balance.HEAT_MAX_STACKS, 1)), 0.0, 1.0)
	if t < 0.7:
		return cold.lerp(Color(1.0, 0.5, 0.12), t / 0.7)
	return Color(1.0, 0.5, 0.12).lerp(Color(1.0, 0.95, 0.7), (t - 0.7) / 0.3)

## The Heat buff: a stacking % bonus to Fire damage dealt by abilities.
## `time` = seconds without a new stack before it is lost (Forge Heat makes it longer).
static func make_heat_fx(time: float = Balance.HEAT_TIME) -> Resource:
	var fx := StatusContainer.make_buff(HEAT_ID, "Heat", HEAT_ID, 0.0,
		time, Balance.HEAT_MAX_STACKS, Color(1.0, 0.55, 0.15))
	fx.stat_modifiers = {}
	fx.damage_mod_pct = Balance.HEAT_DAMAGE_PCT
	fx.mod_damage_types = PackedStringArray(["fire"])
	fx.mod_required_tags = PackedStringArray(["Ability"])
	fx.mod_affects_dots = true   # an ability's burn (Searing Strike's Burning) counts too
	fx.description = "Your abilities deal %s%% more Fire damage per stack. All Heat is lost after %s sec without gaining a stack." % [
		Stats.num(Balance.HEAT_DAMAGE_PCT), Stats.num(time)]
	return fx

func _heat_stack_fx() -> Resource:
	var time := Balance.HEAT_TIME + _talent("fire_forge_heat")   # Forge Heat
	if _heat_fx == null or not is_equal_approx(float(_heat_fx.duration), time):
		_heat_fx = make_heat_fx(time)
	return _heat_fx

## Add `n` stacks of Heat (every stack restarts its timer, also at the cap).
func gain_heat(n: int) -> void:
	for i in maxi(n, 0):
		status.apply(_heat_stack_fx(), self)

## A hit of mine landed: melee swings on a target with my Immolate build Heat.
func _heat_on_hit(info: RefCounted, tags: PackedStringArray) -> void:
	if info.is_proc or int(info.amount) <= 0 or not tags.has("Melee"):
		return
	var id := str(info.ability_id)
	var gain := heat_from(id)
	if gain <= 0 or info.target == null or not is_instance_valid(info.target):
		return
	var st: Node = info.target.get_node_or_null("Status")
	if st == null or not st.has_from("immolate", self):
		return
	var key := "%s@%d" % [id, Engine.get_process_frames()]
	if key == _heat_last:
		return   # the same swing hitting another enemy
	_heat_last = key
	if id == "searingstrike" and randf() * 100.0 < _talent("fire_kindling"):
		gain += 1   # Kindling
	gain_heat(gain)

## Flare: a sweep in front of me. Its Heat is spent first (what is left still
## boosts it). Everything in the arc is hit - more than AOE_TARGET_CAP enemies
## share that many hits' damage - and my target's Immolate goes onto every enemy
## hit that doesn't carry mine yet (it never refreshes one that does).
func _flare(w: Dictionary, res: Resource) -> void:
	status.spend_stacks(HEAT_ID, Balance.FLARE_HEAT_COST)
	var has_target := _has_valid_target()
	var tst: Node = target.get_node_or_null("Status") if has_target else null
	var spread: bool = tst != null and tst.has_from("immolate", self)
	var hit := _enemies_in_cone(float(res.radius), Balance.FLARE_ARC)
	if has_target and not hit.has(target):
		hit.append(target)   # in weapon reach, but outside the sweep's
	var coef := _weapon_hit(w, res) * Balance.aoe_share(hit.size())
	for e in hit:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var est: Node = e.get_node_or_null("Status")
		var had: bool = est != null and est.has_from("immolate", self)
		deal_damage(e, coef, "flare")
		if spread and not had and is_instance_valid(e) and e.is_alive():
			deal_damage(e, 0.0, "immolate", true)   # no damage: just its on-hit effect
	for i in 2:
		_slash_effect(Abilities.color_of("flare"))
	_cone_effect(float(res.radius), Balance.FLARE_ARC * 0.5, Abilities.color_of("flare"))

## Fresh Tinder: my Immolate on `tgt` lasts longer, up to its base duration.
## The tick timer is left alone, so it simply gets more ticks.
func _feed_immolate(tgt: Node) -> void:
	var st: Node = tgt.get_node_or_null("Status") if tgt != null and is_instance_valid(tgt) else null
	if st == null or not st.has_from("immolate", self):
		return
	var fx: Resource = Abilities.get_resource("immolate").on_hit_effect
	if fx == null:
		return
	var add := Balance.FRESH_TINDER_CAPSTONE_SECONDS if _capstone("fire_fresh_tinder") else Balance.FRESH_TINDER_SECONDS
	var left: float = st.remaining_from("immolate", self)
	var fed := tinder_time(left, add, float(fx.duration) + effect_duration_bonus(fx))   # base duration incl. Long Burn
	if fed <= left + 0.001:
		return   # already at its base duration
	var net := _net()
	if net:
		net.set_effect_remaining(tgt, self, "immolate", fed)   # the host owns enemy effects in a party
	else:
		st.set_remaining_from("immolate", self, fed)

## Afterglow talent: Quench leaves the weapon glowing for a few seconds.
func _start_afterglow() -> void:
	var fx := StatusContainer.make_buff(AFTERGLOW_ID, "Afterglow", AFTERGLOW_ID, 0.0,
		Balance.AFTERGLOW_TIME, 1, Color(1.0, 0.75, 0.3))
	fx.stat_modifiers = {}
	fx.description = "Your auto-attacks also deal %s%% of their damage as Fire damage." % Stats.num(_talent("fire_afterglow"))
	status.apply(fx, self)

## An auto-attack of mine landed during Afterglow: part of it again, as Fire
## damage. An exact share of the swing (its crit is already in it), dealt as a
## proc: it builds no Heat and feeds nothing else.
func _afterglow_on_hit(info: RefCounted) -> void:
	if str(info.ability_id) != "auto_melee" or int(info.amount) <= 0 or not status.has(AFTERGLOW_ID):
		return
	var extra_dmg := afterglow_damage(int(info.amount), _talent("fire_afterglow"))
	if extra_dmg <= 0.0 or info.target == null or not is_instance_valid(info.target) or not info.target.is_alive():
		return
	var extra := DamageInfo.make(self, info.target, 1.0, AFTERGLOW_ID)
	extra.unit = extra_dmg
	extra.exact = true
	extra.add_power = false
	extra.can_crit = false
	extra.can_block = false
	extra.is_proc = true
	extra.damage_type = "fire"
	extra.tags = PackedStringArray(["Fire", "Melee"])
	_combat().deal(extra)

# --- Fire bow: Pitch Arrow and Cinder Rain ------------------------------------------------
# Pitch Arrow leaves my own "pitched" debuff on its target (one per archer).
# While it is there MY Burning and Immolate on that target tick faster: the
# StatusContainer asks dot_speed_mult() before every tick. Own only.
# Cinder Rain is aimed on the ground like Blizzard but is instant: the volley
# lands where you click (scripts/cinder_rain.gd).

const PITCH_FX_ID := "pitched"
const CINDER_RAIN_ID := "cinderrain"
const CINDER_RAIN = preload("res://scripts/cinder_rain.gd")

## How much faster effect `effect_id` ticks on a target that has my pitch on it (or not).
static func pitch_speed(effect_id: String, pitched: bool) -> float:
	if pitched and Balance.PITCH_EFFECTS.has(effect_id):
		return 1.0 + Balance.PITCH_TICK_SPEED_PCT / 100.0
	return 1.0

## The StatusContainer asks before every tick of one of MY damage-over-time effects.
func dot_speed_mult(tgt: Node, res: Resource) -> float:
	var id := str(res.id)
	var wasting := dot_speed_with(1.0, _talent("shadow_wasting"))   # Wasting: all of my damage over time
	if not Balance.PITCH_EFFECTS.has(id) or tgt == null or not is_instance_valid(tgt):
		return wasting
	var st: Node = tgt.get_node_or_null("Status")
	return pitch_speed(id, st != null and st.has_from(PITCH_FX_ID, self)) * wasting

## Why Cinder Rain can't be used right now ("" = it can). `point` = where it would land.
func _cinder_rain_error(point: Variant = null) -> String:
	if cooldown_left(CINDER_RAIN_ID) > 0.0:
		return "%s is not ready yet" % Abilities.ability_name(CINDER_RAIN_ID)
	if _weapon().get("weapon", "") != "ranged":
		return "Requires a bow"
	if point is Vector3:
		var reach := float(Abilities.get_resource(CINDER_RAIN_ID).cast_range)
		if reach > 0.0 and Vector2(point.x - global_position.x, point.z - global_position.z).length() > reach:
			return "Out of range"
	return ""

func _start_cinder_rain(point: Vector3) -> void:
	if casting or not is_on_floor():
		return
	var err := _cinder_rain_error(point)
	if err != "":
		_error(err)
		return
	if not _pay(CINDER_RAIN_ID):
		return
	var res := Abilities.get_resource(CINDER_RAIN_ID)
	cooldowns[CINDER_RAIN_ID] = float(res.cooldown)
	var dir := point - global_position
	if Vector2(dir.x, dir.z).length() > 0.3:
		rotation.y = atan2(-dir.x, -dir.z)
	var rain := Node3D.new()
	rain.set_script(CINDER_RAIN)
	rain.radius = float(res.radius)
	rain.duration = Balance.CINDER_RAIN_TIME
	rain.tick = maxf(Balance.CINDER_RAIN_TICK / haste_mult(), 0.1)
	rain.damage = _weapon_hit(_weapon(), res)   # per tick
	rain.tags = res.tags
	rain.source = self
	get_tree().current_scene.add_child(rain)
	rain.global_position = point
	_net_fx(CINDER_RAIN_ID, point, null, {"r": float(res.radius), "time": Balance.CINDER_RAIN_TIME})
	if on_gcd(CINDER_RAIN_ID):
		_start_gcd()
	_bus().cast_finished.emit(CINDER_RAIN_ID)

# --- Cinderwing: the phoenix (Fire healing cooldown) -----------------------------------------
# A phoenix follows me and, every PHOENIX_INTERVAL seconds, casts a heal on the
# ally with the lowest health within PHOENIX_RANGE (me included): PHOENIX_CASTS
# casts, then it leaves. The bird is scripts/phoenix.gd; it calls phoenix_cast().
# The heals are mine (my Spell Power, my threat, my line in the meter).

const PHOENIX_ID := "cinderwing"
const PHOENIX = preload("res://scripts/phoenix.gd")
var _phoenix: Node3D

func _summon_phoenix() -> void:
	if is_instance_valid(_phoenix):
		_phoenix.vanish()
	var time: float = PHOENIX.life_time(Balance.PHOENIX_CASTS, Balance.PHOENIX_INTERVAL)
	_phoenix = PHOENIX.spawn(get_tree().current_scene, self, Balance.PHOENIX_CASTS, Balance.PHOENIX_INTERVAL)
	_net_fx("phoenix", global_position, null, {"time": time})   # the party sees the bird; the heals come from here
	var fx := StatusContainer.make_buff(PHOENIX_ID, "Cinderwing", PHOENIX_ID, 0.0, time, 1, Abilities.color_of(PHOENIX_ID))
	fx.stat_modifiers = {}
	fx.description = "A phoenix heals the ally with the lowest health near you every %s sec." % Abilities.secs(Balance.PHOENIX_INTERVAL)
	status.apply(fx, self)
	_ring_effect(1.2, Abilities.color_of(PHOENIX_ID))

## The phoenix casts: one heal on the ally with the lowest health in range.
func phoenix_cast() -> void:
	if is_dead():
		return
	var tgt := _lowest_health_ally(Balance.PHOENIX_RANGE)
	if tgt == null:
		return
	_heal_someone(tgt, float(Abilities.HEALS[PHOENIX_ID]), PHOENIX_ID)
	if tgt is Node3D:
		_ring_effect(0.8, Abilities.color_of(PHOENIX_ID), (tgt as Node3D).global_position)

## Heal `tgt` - me, a party member or a friendly dummy - for coefficient `coef`,
## as `id` in the log and the meter. A party member is healed on their own machine.
func _heal_someone(tgt: Node, coef: float, id: String) -> void:
	if tgt == null or not is_instance_valid(tgt):
		return
	coef *= _others_heal_mult(tgt)   # Many Hands
	if tgt == self:
		heal(coef, id)
	elif tgt.is_in_group("friendly"):
		_combat().heal(self, tgt, coef, id)   # a local friendly (training ally dummy)
	else:
		var amount: int = _combat().heal_amount(self, coef, id)
		_combat().float_text(tgt, "+%d" % amount, Color(0.45, 1.0, 0.45), false)
		_bus().heal_done.emit(self, tgt, amount, amount, id, false)   # Details meter
		if _net():
			_net().heal_ally(tgt, self, amount)   # their machine heals them (+ threat)

## Me + party members + friendly dummies within `radius` metres of me (alive ones).
func _allies_within(radius: float) -> Array:
	var out: Array = [self] if is_alive() else []
	for a in get_tree().get_nodes_in_group("remote_player") + get_tree().get_nodes_in_group("friendly"):
		if a is Node3D and a.is_alive() and _flat_dist_to(a.global_position) <= radius:
			out.append(a)
	return out

## Index of the smallest health share in `shares` (the first one wins a tie), -1 if empty.
static func lowest_share(shares: Array) -> int:
	var best := -1
	var best_f := INF
	for i in shares.size():
		if float(shares[i]) < best_f:
			best_f = float(shares[i])
			best = i
	return best

# --- Deep Crucible (Fire talent): a wider Crucible that stands longer ----------------------------

func crucible_radius() -> float:
	# Deep Crucible makes it 1 / 2 m WIDER, so half of that goes on the radius.
	return float(Abilities.get_resource(CRUCIBLE_ID).radius) + Abilities.radius_bonus(CRUCIBLE_ID)

func crucible_duration() -> float:
	return Balance.CRUCIBLE_TIME + _talent("fire_deep_crucible", "values2")

## Health Slag Mending restores when `stacks` of Slag shatter, at `pct` % of max health per stack.
static func slag_mending_heal(max_hp: int, stacks: int, pct: float) -> int:
	return int(round(float(max_hp) * pct / 100.0 * maxi(stacks, 0)))

## Rage Cinder Guard costs with Furnace Heart taking `less` off it (never below 0).
static func furnace_heart_cost(cost: float, less: float) -> float:
	return maxf(cost - less, 0.0)

## Something hit me (or I blocked it).
func _on_hit_taken(info: RefCounted) -> void:
	if not is_same(info.target, self) or status == null or is_dead():
		return
	_crossed_taken(info)   # Crossed Strings: what it spared me goes to the enemy at the other end
	_vigil_taken(info)     # Watchful: a big hit while I stand in a healer's Vigil
	# Heat Sink: what it spared me is stored for the burst.
	if _heat_on and status.has(HEAT_SINK_ID) and not info.blocked and int(info.amount) > 0:
		_heat_stored += heat_sink_stored(float(info.amount), float(info.bonus_pct), Balance.HEAT_SINK_PCT)
	# Winter Hide: an enemy whose melee attack reaches me (hit or blocked) is Chilled.
	if status.has(WINTER_HIDE_ID) and winter_hide_chills(info.tags, info.is_dot):
		_chill(info.source, WINTER_HIDE_ID)
	# Cinder Guard: a blocked attack burns the attacker and keeps Slag Skin going.
	if info.blocked and not info.is_dot and status.has(CINDER_GUARD_ID):
		var foe: Variant = info.source
		if foe != null and is_instance_valid(foe) and foe is Node and foe.is_in_group("enemies") and foe.is_alive():
			deal_damage(foe, block_burn(float(Abilities.get_resource("cinderguard").damage), _talent("fire_hot_iron")),
				"cinderguard", true)
		if status.has(SLAG_ID):
			status.set_remaining(SLAG_ID, minf(status.remaining_of(SLAG_ID) + Balance.CINDER_GUARD_EXTEND, Balance.SLAG_SKIN_TIME))
			_sync_slag()
	_melee_kit_hit_taken(info)   # Reflex Arc, Faraday Guard, Back-Current
	_parry_kit_hit_taken(info)   # Return Stroke, Humming Blade, Quick Wrists, Draw the Storm
	_reflection_kit_hit_taken(info)   # a dodge (or Stand-In) shatters a Reflection
	_mirror_finish(info)   # Mirror Finish: what I dodge, parry or block hurts the attacker
	_tempered(info)   # Tempered: a block gives Armor for a while
	_spite_on_hit_taken(info)   # Spite: taking damage boosts my next spell or ability

# --- Heat Sink ------------------------------------------------------------------------------
# For HEAT_SINK_TIME seconds HEAT_SINK_PCT% of the damage I take is stored instead
# (_on_damage_modify takes it off the hit, _on_hit_taken counts it). When the buff
# runs out the heat bursts around me: the ability's damage, growing with what was
# stored up to (1 + HEAT_SINK_BONUS) times it at HEAT_SINK_FULL_AT% of my health.

const HEAT_SINK_ID := "heat_sink"
var _heat_on := false
var _heat_stored := 0.0

## Damage Heat Sink kept off me on a hit that still dealt `amount`, when all the
## hit's modifiers (Heat Sink's -`pct` included) added up to `bonus_pct`.
static func heat_sink_stored(amount: float, bonus_pct: float, pct: float) -> float:
	var mult := 1.0 + bonus_pct / 100.0
	if mult <= 0.0 or pct <= 0.0:
		return 0.0
	return amount * (pct / 100.0) / mult

## Coefficient of the burst with `stored` damage soaked, at `max_hp` max health.
static func heat_sink_coef(base: float, stored: float, max_hp: float) -> float:
	var full := maxf(max_hp * Balance.HEAT_SINK_FULL_AT / 100.0, 1.0)
	return base * (1.0 + Balance.HEAT_SINK_BONUS * clampf(stored / full, 0.0, 1.0))

func _start_heat_sink() -> void:
	_heat_stored = 0.0
	_heat_on = true
	var fx := StatusContainer.make_buff(HEAT_SINK_ID, "Heat Sink", HEAT_SINK_ID, 0.0,
		Balance.HEAT_SINK_TIME, 1, Abilities.color_of("heatsink"))
	fx.stat_modifiers = {}
	fx.description = "You take %d%% less damage; it is stored and bursts out as Fire damage when this ends." % int(Balance.HEAT_SINK_PCT)
	status.apply(fx, self)
	_ring_effect(1.2, Abilities.color_of("heatsink"))

## Heat Sink just ran out: let the heat go.
func _heat_sink_check() -> void:
	if not _heat_on or status.has(HEAT_SINK_ID):
		return
	_heat_on = false
	if is_dead():
		return
	var res := Abilities.get_resource("heatsink")
	var hit := _enemies_within(float(res.radius))
	var coef := heat_sink_coef(float(res.damage), _heat_stored, float(max_health)) * Balance.aoe_share(hit.size())
	_heat_stored = 0.0
	for e in hit:
		deal_damage(e, coef, "heatsink", true)
	_ring_effect(float(res.radius), Abilities.color_of("heatsink"))
	_ring_effect(float(res.radius) * 0.6, Color(1.0, 0.9, 0.4))

# --- Cinder Step ----------------------------------------------------------------------------
# A dash straight ahead (like Blink it stops short of walls) that leaves a line
# of cinders, and lets the next Fire spell with a cast time be cast on the move.

const CINDER_ID := "cinder_step"
var _cinder_cast := false   # the current cast may be finished while moving
var _cinder_fx: Resource

## Can Cinder Step's buff carry this cast? Fire spells with a cast time; not channels.
static func cinder_step_applies(tags: PackedStringArray, cast_time: float, channel: bool) -> bool:
	return not channel and cast_time > 0.0 and tags.has("Fire") and tags.has("Spell")

func cinder_step_ready(id: String) -> bool:
	if status == null or not status.has(CINDER_ID):
		return false
	var res := Abilities.get_resource(id)
	return res != null and cinder_step_applies(res.tags, float(res.cast_time), int(res.cast_type) == 2)

func _cinder_step(res: Resource) -> void:
	var from := global_position
	var dir := _flat_forward()
	var dist := _dash_distance(Balance.CINDER_STEP_DISTANCE)
	global_position += dir * dist
	_ring_effect(0.8, Abilities.color_of("cinderstep"), from)
	_ring_effect(0.8, Abilities.color_of("cinderstep"))
	if dist > 0.5:
		var mid := from + dir * dist * 0.5
		# (A fire strip's length runs across its facing, so it is turned a quarter.)
		_fire_patch(Vector3(mid.x, Combat.feet_y(self), mid.z), atan2(-dir.x, -dir.z) + PI / 2.0, dist,
			Balance.CINDER_STEP_LINE_DEPTH, Balance.CINDER_STEP_LINE_TIME, Balance.CINDER_STEP_TICK,
			float(res.damage), res.tags, "cinderstep")
	if _cinder_fx == null:
		_cinder_fx = StatusContainer.make_buff(CINDER_ID, "Cinder Step", CINDER_ID, 0.0,
			Balance.CINDER_STEP_BUFF_TIME, 1, Abilities.color_of("cinderstep"))
		_cinder_fx.stat_modifiers = {}
		_cinder_fx.description = "Your next Fire spell with a cast time can be cast while moving."
	status.apply(_cinder_fx, self)

# --- Crucible -------------------------------------------------------------------------------
# A circle placed on the ground (like Blizzard) for CRUCIBLE_TIME seconds: enemies
# in it take more periodic Fire damage (_on_damage_modify). While mine stands,
# casting it again is instant and free and moves it (it keeps the time it had
# left, unless Balance.CRUCIBLE_MOVE_REFRESHES).

const CRUCIBLE_ID := "crucible"
const CRUCIBLE = preload("res://scripts/crucible.gd")
var _crucible: Node3D   # my Crucible on the ground (null / gone = none)

func _crucible_standing() -> bool:
	return is_instance_valid(_crucible) and _crucible.time_left() > 0.0

## Seconds a Crucible placed now lasts: a fresh one the full time, a moved one
## what the old one had left (or the full time again if moving refreshes it).
static func crucible_time(moving: bool, left: float, full: float, move_refreshes: bool) -> float:
	return left if moving and not move_refreshes else full

func _start_crucible(point: Vector3) -> void:
	if casting or not is_on_floor():
		return
	cast_point = point
	if _crucible_standing():
		_place_crucible(true)   # moving it: instant and free
		if on_gcd(CRUCIBLE_ID):
			_start_gcd()
		_bus().cast_finished.emit(CRUCIBLE_ID)
		return
	if not can_afford(CRUCIBLE_ID, true):
		return
	var res := Abilities.get_resource(CRUCIBLE_ID)
	_begin_spell(CRUCIBLE_ID, str(res.display_name), float(res.cast_time))

func _place_crucible(moving: bool) -> void:
	var res := Abilities.get_resource(CRUCIBLE_ID)
	var standing := _crucible_standing()
	var time := crucible_time(moving and standing, _crucible.time_left() if standing else 0.0,
		crucible_duration(), Balance.CRUCIBLE_MOVE_REFRESHES)
	var radius := crucible_radius()   # Deep Crucible: wider, and it stands longer
	_crucible = CRUCIBLE.spawn(get_tree().current_scene, cast_point, radius, time, "me")
	_net_fx("crucible", cast_point, null, {"r": radius, "time": time})
	_ring_effect(radius, Abilities.color_of(CRUCIBLE_ID), cast_point)

# --- Cool Head (Fire ability) and Concentrated Fire ---------------------------------------
# Cool Head (Balance.COOL_HEAD_TIME): your Fire spells and abilities can't crit
# (adjust_crit), and each one that deals damage gives a stack of Concentrated
# Fire: once per use, however many enemies it hits; ticks and procs don't count.
# When Cool Head ends the stacks stay for CONCENTRATED_FIRE_WINDOW seconds and
# each one makes a Fire spell / ability with a cast time instant (_begin_spell).

const COOL_HEAD_ID := "cool_head"
const CONC_ID := "concentrated_fire"
var _cool_head_on := false       # Cool Head is running (stacks build; no instant casts yet)
var _conc_cast := false          # the current cast is an instant Concentrated Fire one
var _conc_fx: Resource
var _conc_last := ""             # "<ability>@<frame>" of the last hit that gave a stack

## A Fire spell or ability (by its tags)?
static func is_fire_action(tags: PackedStringArray) -> bool:
	return tags.has("Fire") and (tags.has("Spell") or tags.has("Ability"))

func cool_head_active() -> bool:
	return status != null and status.has(COOL_HEAD_ID)

func _start_cool_head() -> void:
	status.remove(CONC_ID)
	var fx := StatusContainer.make_buff(COOL_HEAD_ID, "Cool Head", COOL_HEAD_ID, 0.0,
		Balance.COOL_HEAD_TIME, 1, Color(0.65, 0.88, 1.0))
	fx.stat_modifiers = {}
	fx.description = "Your Fire spells and abilities cannot critically strike. Each one that deals damage grants a stack of Concentrated Fire."
	_cool_head_on = true
	status.apply(fx, self)
	_ring_effect(1.2, Color(0.65, 0.88, 1.0))

## A hit of mine landed: during Cool Head, a Fire spell / ability gives a stack.
func _cool_head_on_hit(info: RefCounted, tags: PackedStringArray) -> void:
	if not cool_head_active() or info.is_proc or int(info.amount) <= 0 or not is_fire_action(tags):
		return
	var key := "%s@%d" % [str(info.ability_id), Engine.get_process_frames()]
	if str(info.ability_id) == "embervolley":
		key = "embervolley#%d" % _volley_serial   # one stack per channel, not per ember
	if key == _conc_last:
		return   # the same use hitting another enemy
	_conc_last = key
	if _conc_fx == null:
		_conc_fx = StatusContainer.make_buff(CONC_ID, "Concentrated Fire", CONC_ID, 0.0,
			Balance.COOL_HEAD_TIME + Balance.CONCENTRATED_FIRE_WINDOW, Balance.CONCENTRATED_FIRE_MAX, Color(1.0, 0.6, 0.2))
		_conc_fx.stat_modifiers = {}
		_conc_fx.description = "When Cool Head ends, your next Fire spells and abilities with a cast time are instant: one cast per stack."
	status.apply(_conc_fx, self)
	# The stacks always run out CONCENTRATED_FIRE_WINDOW seconds after Cool Head does.
	status.set_remaining(CONC_ID, status.remaining_of(COOL_HEAD_ID) + Balance.CONCENTRATED_FIRE_WINDOW)

## Cool Head just ran out: the Concentrated Fire window starts.
func _cool_head_check() -> void:
	if _cool_head_on and not cool_head_active():
		_cool_head_on = false
		status.set_remaining(CONC_ID, Balance.CONCENTRATED_FIRE_WINDOW)

## Would casting `id` right now be instant from Concentrated Fire?
func concentrated_fire_ready(id: String) -> bool:
	if status == null or cool_head_active() or not status.has(CONC_ID):
		return false
	var res := Abilities.get_resource(id)
	# (Ember Volley counts too: its whole volley goes out at once, see _start_ember_volley.)
	return res != null and concentrated_applies(res.tags, float(res.cast_time), _has_rune("level_head"))

## Can Concentrated Fire make this instant? Fire spells and abilities with a
## cast time; with the Rune of the Level Head (`any_school`), spells of any school.
static func concentrated_applies(tags: PackedStringArray, cast_time: float, any_school: bool) -> bool:
	if cast_time <= 0.0:
		return false
	return is_fire_action(tags) or (any_school and tags.has("Spell"))

# --- Crit changes (CombatSystem asks for every hit I deal) ------------------------------

var _empowered := {}   # Cold Precision: ability id -> time its hits stop being empowered

## Fire's crit rules as pure maths (adjust_crit and the tests use this).
## Returns [crit chance, bonus damage %] for a direct hit of ability `id` at a
## crit chance of `chance`, with the Tempered Flame talent's two numbers.
##   Vent Flames: always crits, +(crit chance x VENT_FLAMES_CRIT_DAMAGE)% damage.
##   Firebolt + Tempered Flame: `temper_less`% less crit chance, +(crit chance x
##   `temper_bonus`%)% damage. Both bonuses use the full crit chance.
static func fire_crit_rules(id: String, chance: float, temper_less: float = 0.0, temper_bonus: float = 0.0) -> Array:
	var full := clampf(chance, 0.0, 100.0)
	if id == "ventflames":
		return [100.0, full * Balance.VENT_FLAMES_CRIT_DAMAGE]
	if Abilities.is_a(id, "fireball") and temper_less > 0.0:
		return [chance * (1.0 - temper_less / 100.0), full * temper_bonus / 100.0]
	return [chance, 0.0]

func adjust_crit(info: RefCounted, chance: float) -> float:
	var id := str(info.ability_id)
	if id == "permafrost" or id == "stoke" or id == "anvil" or id == "quench":
		return 0.0                               # (Stoke, Anvil and Quench never crit)
	if not info.is_dot and (id == "ventflames" or Abilities.is_a(id, "fireball")):
		var fire := fire_crit_rules(id, chance, _talent("fire_tempered_flame"), _talent("fire_tempered_flame", "values2"))
		if float(fire[1]) > 0.0:
			info.add_bonus(float(fire[1]), "Vent Flames" if id == "ventflames" else "Tempered Flame")
		chance = float(fire[0])
	var tags: PackedStringArray = info.tags
	if cool_head_active() and is_fire_action(tags):
		return 0.0                               # Cool Head: no Fire crits at all (ticks and Vent Flames included)
	var frost_spell := tags.has("Frost") and tags.has("Spell")
	if not info.is_dot and float(_empowered.get(id, 0.0)) > Time.get_ticks_msec() / 1000.0:
		chance += 100.0                          # Cold Precision
	if frost_spell and _has_rune("permafrost"):
		# Permafrost: no crits; the crit chance becomes extra damage over time.
		info.set_meta("permafrost_pct", clampf(chance, 0.0, 100.0) * Balance.PERMAFROST_CRIT_FACTOR)
		return 0.0
	# Conductive: my Lightning damage crits more often.
	if str(info.damage_type) == "lightning":
		chance += _talent("lightning_conductive")
	# Bite Down: the ticks of my Decay crit more often while Gnaw is on it (_tick_decay marks them).
	if id == DECAY_HIT_ID:
		chance += float(info.get_meta(DECAY_CRIT_META, 0.0))
	# Worked Up's capstone: my Hounds' bites crit more often while they are Roused (_hound_bite marks them).
	if id == HOUND_BITE_ID:
		chance += float(info.get_meta(HOUND_CRIT_META, 0.0))
	# Dull Edge / Dull Mind: talents can't lift crit over the cap either (sure crits still crit).
	if chance < 100.0 and chance > Balance.DULL_EDGE_CRIT_CAP and dull_rune_power() != "":
		chance = Balance.DULL_EDGE_CRIT_CAP
	return chance

# --- Cold Precision rune: every 6th Frost spell / ability crits ------------------------
# Counted when a cast finishes. After 5, the next one is empowered: an instant
# one as it's used (its hits land before it "finishes"), a cast one when it
# finishes (its projectile lands after). Its hits for a few seconds crit.

var _cp_count := 0
var _cp_armed := false
var _cp_pending := ""   # instant empowered on use, confirmed when it actually goes off

static func _is_frost_action(id: String) -> bool:
	var t := Abilities.tags_of(id)
	return t.has("Frost") and (t.has("Spell") or t.has("Ability"))

func _cold_precision_on_use(id: String) -> void:
	if not _cp_armed or not _has_rune("cold_precision") or not _is_frost_action(id):
		return
	var res := Abilities.get_resource(id)
	if res == null or float(res.cast_time) > 0.0 or id == "blizzard":
		return   # cast-time spells are empowered when the cast finishes
	# Empower now (its hits land right away); if it fails (cooldown, range...)
	# it never "finishes" and the empowerment is taken back.
	_empowered[id] = Time.get_ticks_msec() / 1000.0 + Balance.COLD_PRECISION_WINDOW
	_cp_pending = id
	_cold_precision_undo.call_deferred(id)

func _cold_precision_undo(id: String) -> void:
	if _cp_pending == id:
		_cp_pending = ""
		_empowered.erase(id)

func _cold_precision_on_cast(id: String) -> void:
	if id != "" and id == _cp_pending:
		_cp_pending = ""
		_cold_precision_fire(id)   # the empowered instant went off
		return
	if not _has_rune("cold_precision") or not _is_frost_action(id):
		return
	_empowered.erase(id)   # a new cast of this ability: the old empowerment is over
	if _cp_armed:
		_cold_precision_fire(id)
		return
	_cp_count += 1
	if _cp_count >= Balance.COLD_PRECISION_EVERY - 1:
		_cp_armed = true

func _cold_precision_fire(id: String) -> void:
	_cp_armed = false
	_cp_count = 0
	_empowered[id] = Time.get_ticks_msec() / 1000.0 + Balance.COLD_PRECISION_WINDOW
	_combat().float_text(self, "Cold Precision", Color(0.7, 0.92, 1.0), false)

# --- Permafrost rune: rolling Frost damage from crit chance -----------------------------

var _perma := {}   # enemy instance id -> {"target", "left" (damage), "ticks", "next"}

func _on_damage_dealt_frost(info: RefCounted) -> void:
	if not is_same(info.source, self) or info.avoided() or int(info.amount) <= 0:
		return
	if not is_instance_valid(info.target):
		return
	var tgt: Node = info.target
	if str(info.ability_id) == "icepin":
		_note_icepin(tgt)   # Pinning Frost
	_coldmark_arrow(info)     # Coldmark: my arrows on the marked target give Ice Shard charges
	if info.has_meta("cold_draw"):
		_gain("energy", _talent("frost_cold_draw"))   # Cold Draw: the target was already Chilled or Frozen
	_rimefletch_shot(info)    # Rimefletch: my auto-shots carry an extra Frost hit
	_rime_edge_on_hit(info)   # Rime Edge: my melee hits carry an extra Frost hit
	if not is_instance_valid(tgt) or not tgt.is_alive():
		return   # (that extra hit can be the killing blow)
	if info.has_meta("permafrost_pct"):
		var pct := float(info.get_meta("permafrost_pct"))
		if pct > 0.0:
			_add_permafrost(tgt, float(info.amount) * pct / 100.0)
	# Frozen Aegis: damaging an enemy I Froze shields the lowest-health ally near me.
	if tgt.is_in_group("enemies") and _has_rune("frozen_aegis"):
		var st: Node = tgt.get_node_or_null("Status")
		if st and st.has_from("frozen", self):
			var pick := _lowest_health_ally()
			if pick:
				_give_aegis(pick, _aegis_amount(Balance.FROZEN_AEGIS_ON_HIT))

func _add_permafrost(tgt: Node, dmg: float) -> void:
	var key := tgt.get_instance_id()
	var now := Time.get_ticks_msec() / 1000.0
	var e: Dictionary = _perma.get(key, {"target": tgt, "left": 0.0, "next": now + 1.0})
	e["left"] = float(e["left"]) + dmg
	e["ticks"] = int(round(Balance.PERMAFROST_TIME))   # rolling: the pool restarts its 6 s
	_perma[key] = e

func _tick_permafrost() -> void:
	if _perma.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	for key in _perma.keys():
		var e: Dictionary = _perma[key]
		if not is_instance_valid(e["target"]) or not e["target"].is_alive() or int(e["ticks"]) <= 0:
			_perma.erase(key)
			continue
		var tgt: Node = e["target"]
		if now < float(e["next"]):
			continue
		var amt := float(e["left"]) / int(e["ticks"])
		e["left"] = float(e["left"]) - amt
		e["ticks"] = int(e["ticks"]) - 1
		e["next"] = float(e["next"]) + 1.0
		if amt > 0.0:
			var info := DamageInfo.make(self, tgt, 1.0, "permafrost")
			info.unit = amt
			info.exact = true
			info.add_power = false
			info.can_crit = false
			info.can_block = false
			info.is_dot = true
			info.damage_type = "frost"
			info.tags = PackedStringArray(["Frost", "Spell", "DoT"])
			_combat().deal(info)

# --- Frozen Aegis rune: shields for you and allies ------------------------------------

## Shield size: `share` x a Heal spell, with Rime Ward.
func _aegis_amount(share: float) -> int:
	return int(round(_combat().heal_amount(self, Balance.REFERENCE_HEAL * share) * absorb_mult()))

## Me + party members + friendly dummies within FROZEN_AEGIS_RADIUS.
func _aegis_allies() -> Array:
	return _allies_within(Balance.FROZEN_AEGIS_RADIUS)

## The ally (me included) within `radius` with the smallest share of their health left.
func _lowest_health_ally(radius: float = Balance.FROZEN_AEGIS_RADIUS) -> Node:
	var allies := _allies_within(radius)
	var shares: Array = []
	for a in allies:
		var h: Variant = a.get("health")
		var mh: Variant = a.get("max_health")
		shares.append(float(h) / maxf(float(mh), 1.0) if h != null and mh != null else 1.0)
	var i := lowest_share(shares)
	return allies[i] if i >= 0 else null

func _give_aegis(who: Node, amount: int) -> void:
	if who == null or not is_instance_valid(who) or amount <= 0:
		return
	var cap := _aegis_amount(Balance.FROZEN_AEGIS_CAP)
	var armor := _talent("frost_shield_armor")
	if who == self:
		receive_frozen_aegis(self, amount, cap, armor)
	elif who.is_in_group("remote_player"):
		if _net():
			_net().aegis_ally(who, self, amount, cap, armor)
	elif who.has_method("receive_frozen_aegis"):
		who.receive_frozen_aegis(self, amount, cap, armor)

## A Frozen Aegis shield lands on me (adds up to `cap`).
func receive_frozen_aegis(caster: Node, amount: int, cap: int, armor_pct: float = 0.0) -> void:
	if is_dead():
		return
	SHIELDS.add_aegis(status, caster, amount, cap, armor_pct)

# --- Ice Shards talents: Splintering, Shardstorm, Deep Freeze capstone ------------------

var _shardstorm_count := 0
var _blizzard_shards := 0

## Every Ice Shard fired at `aim`.
func _on_shard_fired(aim: Node3D) -> void:
	var ss := _talent("frost_shardstorm")
	if ss > 0.0:
		_shardstorm_count += 1
		if _shardstorm_count >= Balance.SHARDSTORM_EVERY:
			_shardstorm_count = 0
			add_buff("shardstorm", Stats.HASTE, ss, Balance.SHARDSTORM_TIME, 1, "Shardstorm")
	if _capstone("frost_deep_freeze"):
		_blizzard_shards += 1
		if _blizzard_shards >= Balance.DEEP_FREEZE_BLIZZARD_EVERY:
			_blizzard_shards = 0
			_free_blizzard(aim)

## Deep Freeze capstone: a Blizzard at the target at reduced strength.
func _free_blizzard(aim: Node3D) -> void:
	if aim == null or not is_instance_valid(aim):
		return
	var p := aim.global_position
	var at := Vector3(p.x, Combat.feet_y(aim), p.z)
	var bliz := Node3D.new()
	bliz.set_script(BLIZZARD)
	bliz.radius = blizzard_radius()
	bliz.source = self
	bliz.damage = float(Abilities.get_resource("blizzard").damage) * Balance.DEEP_FREEZE_BLIZZARD_MULT
	get_tree().current_scene.add_child(bliz)
	bliz.global_position = at
	var net := _net()
	if net:
		net.send_fx("blizzard", at, null, "", {"r": bliz.radius})

## Splintering: a shard that hit a Frozen / Rime Shelled enemy hits another one nearby.
func _splinter(at: Vector3, from_id: int) -> void:
	var others := _enemies_near(at, Balance.SPLINTER_RANGE).filter(func(e): return e.get_instance_id() != from_id)
	if others.is_empty():
		return
	deal_damage(others.pick_random(), _talent("frost_splinter"), "splintering", true, "frost",
		PackedStringArray(["Frost", "Spell"]))

## Deep Freeze: Freeze the target (a 0-damage hit carrying Frozen, so it works in a party too).
func _apply_freeze(tgt: Node, tags: PackedStringArray) -> void:
	var info := DamageInfo.make(self, tgt, 0.0, "deepfreeze")
	info.tags = tags
	info.damage_type = "frost"
	info.can_block = false
	info.can_crit = false
	info.add_power = false
	info.is_proc = true
	info.effects.append(FROZEN_FX)
	_combat().deal(info)

# --- Winter's Bite: every third one Freezes ---------------------------------------------
# Each cast adds a stack of a counter buff on me (WINTERS_BITE_TIME seconds,
# restarted by each stack). The cast that would bring it to WINTERS_BITE_STACKS
# uses the stacks up and Freezes the target instead of Chilling it.

const WINTERS_BITE_ID := "winters_bite"
var _bite_fx: Resource
var _bite_freezing := false   # the Winter's Bite being dealt right now is the one that Freezes

# --- Pinning Frost: which enemies my Icepin has rooted ------------------------------------
# Rooted is one effect for everything that roots, so the Icepin that caused it
# is remembered here: enemy instance id -> when that root runs out.
var _icepin_roots := {}

func _note_icepin(tgt: Node) -> void:
	var res := Abilities.get_resource("icepin")
	var fx: Resource = res.on_hit_effect if res else null
	if fx == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for key in _icepin_roots.keys():
		if float(_icepin_roots[key]) <= now:
			_icepin_roots.erase(key)
	_icepin_roots[tgt.get_instance_id()] = now + float(fx.duration) + effect_duration_bonus(fx)

## Is `tgt` rooted by my Icepin right now?
func _icepin_root_on(tgt: Node) -> bool:
	var until := float(_icepin_roots.get(tgt.get_instance_id(), 0.0))
	if until <= Time.get_ticks_msec() / 1000.0:
		return false
	var st: Node = tgt.get_node_or_null("Status")
	return st != null and st.has_from(str(Abilities.get_resource("icepin").on_hit_effect.id), self)

func _winters_bite_fx() -> Resource:
	if _bite_fx == null:
		_bite_fx = StatusContainer.make_buff(WINTERS_BITE_ID, Abilities.ability_name("froststrike"), WINTERS_BITE_ID, 0.0,
			Balance.WINTERS_BITE_TIME, Balance.WINTERS_BITE_STACKS, Abilities.color_of("froststrike"))
		_bite_fx.stat_modifiers = {}
		_bite_fx.description = "At %d stacks your %s Freezes its target instead of Chilling it, and the stacks are used up." % [
			Balance.WINTERS_BITE_STACKS, Abilities.ability_name("froststrike")]
	return _bite_fx

## Does the cast that follows `stacks` earlier ones Freeze?
static func winters_bite_freezes(stacks: int) -> bool:
	return stacks + 1 >= Balance.WINTERS_BITE_STACKS

func _winters_bite(tgt: Node, coef: float) -> void:
	if tgt == null or not is_instance_valid(tgt) or not tgt.is_alive():
		return
	var freeze := winters_bite_freezes(int(status.stacks_of(WINTERS_BITE_ID)))
	if freeze:
		status.remove(WINTERS_BITE_ID)
	else:
		status.apply(_winters_bite_fx(), self)
	var at: Vector3 = tgt.global_position
	var info = _combat().ability_hit_info(self, tgt, coef, "froststrike")
	if freeze:
		info.effects = [FROZEN_FX]   # instead of its Chill
	_bite_freezing = freeze   # Third Bite reads this while the hit is worked out
	_combat().deal(info)
	_bite_freezing = false
	if not info.avoided():
		_on_hit_extra(tgt, at, "froststrike")

# --- Ice Floe & Shatterpoint -----------------------------------------------------------

const CHILLED_FX = preload("res://data/effects/chilled.tres")
var _last_hit_by: Variant = null   # whoever hit me last (the shield breaker)

## Ice Floe: an absorb shield I put on myself was used up by damage (own only:
## a party member's shield on me breaking does nothing for my talents).
func _on_my_shield_broken(id: String) -> void:
	if id == WARD_FX and is_same(status.last_shield_source, self):
		_ward_broke()   # Interval Ward: the time it had left comes off its cooldown
	var v := _talent("frost_ice_floe")
	if v <= 0.0 or is_dead() or not is_same(status.last_shield_source, self):
		return
	add_buff("icefloe", Stats.MOVE_SPEED, v, Balance.ICE_FLOE_TIME, 1, "Ice Floe")
	var foe: Variant = _last_hit_by
	if foe != null and is_instance_valid(foe) and foe.is_in_group("enemies") and foe.is_alive():
		# A 0-damage hit carrying Chilled (works in a party too, like Deep Freeze).
		var info := DamageInfo.make(self, foe, 0.0, "icefloe")
		info.tags = PackedStringArray(["Frost", "Spell"])
		info.damage_type = "frost"
		info.can_block = false
		info.can_crit = false
		info.add_power = false
		info.is_proc = true
		info.effects.append(CHILLED_FX)
		_combat().deal(info)

## Shatterpoint capstone: every shatter gives an Ice Shard charge.
func _shatterpoint_charge() -> void:
	if _capstone("frost_shatterpoint"):
		gain_ice_shard()

# --- Interrupts: one shared cooldown ----------------------------------------------------
# Every interrupt (Balance.INTERRUPT_LOCKOUT lists them, whatever their book) has a
# cooldown of at least INTERRUPT_SHARED_COOLDOWN, and using any of them puts all
# the others on at least that much too: one interrupt per 15 seconds.

## Cooldowns the interrupts are on right after `used` (own cooldown `own_cd`) went
## off, given what they were on (`current`: ability id -> seconds left).
static func interrupt_cooldowns(used: String, own_cd: float, current: Dictionary) -> Dictionary:
	var out := {}
	for other in Balance.INTERRUPT_LOCKOUT:
		var left := own_cd if other == used else float(current.get(other, 0.0))
		out[other] = maxf(left, Balance.INTERRUPT_SHARED_COOLDOWN)
	return out

# --- Frost, second batch ------------------------------------------------------------------
# Coldspike, Sleetwave, Deepwinter, Rimelock, Snow Ward, Winter Hide, Rime Edge,
# Icebreaker and Icepin. Everything that asks about a Freeze asks about MINE
# (has_from); Snow Ward is the one that works for the whole party, by design.

const DEEPWINTER_ID := "deepwinter"
const WINTER_HIDE_ID := "winterhide"
const RIME_EDGE_ID := "rimeedge"
const SLEET_WAVE = preload("res://scripts/sleet_wave.gd")

## Chill `foe` without damage: a 0-damage hit carrying Chilled, so it works in a
## party too (and Deepwinter turns it into a Freeze like any other Chill).
func _chill(foe: Variant, id: String, tags: PackedStringArray = PackedStringArray(["Frost", "Spell"]),
		freeze: bool = false) -> void:
	if foe == null or not is_instance_valid(foe) or not (foe is Node) or not foe.is_in_group("enemies") or not foe.is_alive():
		return
	var info := DamageInfo.make(self, foe, 0.0, id)
	info.tags = tags
	info.damage_type = "frost"
	info.can_block = false
	info.can_crit = false
	info.add_power = false
	info.is_proc = true
	info.effects.append(FROZEN_FX if freeze else CHILLED_FX)   # (freeze: Black Ice)
	_combat().deal(info)

## Deepwinter: the effect one of my hits really applies. While it is up a Chill
## is a Freeze instead; everything else is left alone.
static func winter_swap(eff: Resource, deepwinter: bool) -> Resource:
	if deepwinter and eff != null and str(eff.id) == "chilled":
		return FROZEN_FX
	return eff

## CombatSystem asks this for every effect my hits (and my hit-less applications) carry.
func effect_override(eff: Resource) -> Resource:
	return winter_swap(eff, status != null and status.has(DEEPWINTER_ID))

func _start_deepwinter() -> void:
	var fx := StatusContainer.make_buff(DEEPWINTER_ID, "Deepwinter", DEEPWINTER_ID, 0.0,
		Balance.DEEPWINTER_TIME, 1, Abilities.color_of(DEEPWINTER_ID))
	fx.stat_modifiers = {}
	fx.description = "Every Chill you apply is a Freeze instead."
	status.apply(fx, self)
	_ring_effect(2.2, Abilities.color_of(DEEPWINTER_ID))
	_ring_effect(1.2, Color(0.95, 0.97, 1.0))

## Sleetwave: a wave that crosses a strip in front of me (turned to my target if I
## have one). The enemies standing in the strip now set the AoE cap's share; the
## wave (scripts/sleet_wave.gd) hits each enemy as it reaches it.
func _sleet_wave(res: Resource) -> void:
	if _has_valid_target():
		var to_target := target.global_position - global_position
		rotation.y = atan2(-to_target.x, -to_target.z)
	var dir := _flat_forward()
	var origin := Vector3(global_position.x, Combat.feet_y(self), global_position.z)
	var reach := float(res.radius)
	var count := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node3D and e.is_alive() and SLEET_WAVE.in_path(origin, dir, e.global_position, reach,
				Balance.SLEETWAVE_WIDTH, Combat.hitbox_radius(e)):
			count += 1
	SLEET_WAVE.spawn(get_tree().current_scene, origin, dir, self, float(res.damage) * Balance.aoe_share(count),
		reach, Balance.SLEETWAVE_WIDTH, Balance.SLEETWAVE_SPEED)
	_net_fx("sleetwave", origin, null, {"yaw": rotation.y, "len": reach, "w": Balance.SLEETWAVE_WIDTH})   # the party sees it; the hits come from here

## Snow Ward: a shield on every ally within the ability's radius, me included
## (this one is for the whole party by design). Each is SNOW_WARD_SHARE x a Heal
## spell, with Rime Ward and Hardened Frost like my other shields.
func _snow_ward(res: Resource) -> void:
	var amount := _aegis_amount(Balance.SNOW_WARD_SHARE)
	var armor := _talent("frost_shield_armor")
	for who in _allies_within(float(res.radius)):
		if who == self:
			receive_snow_ward(self, amount, armor)
		elif who.is_in_group("remote_player"):
			if _net():
				_net().ward_ally(who, self, amount, armor)   # their machine puts it on them
		elif who.has_method("receive_snow_ward"):
			who.receive_snow_ward(self, amount, armor)
	_ring_effect(float(res.radius), Color(0.85, 0.95, 1.0))
	_ring_effect(2.0, Color(0.95, 0.97, 1.0))

## A Snow Ward lands on me (mine or a party member's).
func receive_snow_ward(caster: Node, amount: int, armor_pct: float = 0.0) -> void:
	if is_dead():
		return
	SHIELDS.set_ward(status, caster, amount, armor_pct)
	_ring_effect(1.0, Color(0.85, 0.95, 1.0))
	_combat().float_text(self, "Snow Ward (%d)" % amount, Color(0.7, 0.92, 1.0), false)

## Winter Hide's buff: less damage taken, of every kind.
static func make_winter_hide_fx() -> Resource:
	var fx := StatusContainer.make_buff(WINTER_HIDE_ID, "Winter Hide", WINTER_HIDE_ID, 0.0,
		Balance.WINTER_HIDE_TIME, 1, Color(0.6, 0.9, 1.0))
	fx.stat_modifiers = {}
	fx.damage_mod_pct = -Balance.WINTER_HIDE_PCT
	fx.modifies_incoming = true
	fx.mod_affects_dots = true
	fx.description = "You take %s%% less damage. Enemies that hit you in melee are Chilled." % Stats.num(Balance.WINTER_HIDE_PCT)
	return fx

## Winter Hide: does a hit on me Chill whoever dealt it? A melee attack that
## reached me (hit or blocked), never damage over time.
static func winter_hide_chills(tags: PackedStringArray, is_dot: bool) -> bool:
	return not is_dot and tags.has("Melee")

func _start_winter_hide() -> void:
	status.apply(make_winter_hide_fx(), self)
	_ring_effect(1.4, Abilities.color_of(WINTER_HIDE_ID))
	_ring_effect(0.9, Color(0.95, 0.97, 1.0))

func _start_rime_edge() -> void:
	var fx := StatusContainer.make_buff(RIME_EDGE_ID, "Rime Edge", RIME_EDGE_ID, 0.0,
		Balance.RIME_EDGE_TIME, 1, Abilities.color_of(RIME_EDGE_ID))
	fx.stat_modifiers = {}
	fx.description = "Your melee hits Chill the target and deal extra Frost damage."
	status.apply(fx, self)
	_slash_effect(Abilities.color_of(RIME_EDGE_ID))
	_ring_effect(1.0, Abilities.color_of(RIME_EDGE_ID))

## Rime Edge: does this hit of mine carry the extra Frost hit? Melee hits that
## landed - not procs (so never its own hit) and not damage over time.
static func rime_edge_applies(tags: PackedStringArray, is_proc: bool, is_dot: bool, amount: int) -> bool:
	return not is_proc and not is_dot and amount > 0 and tags.has("Melee")

## One of my melee hits landed with Rime Edge up: the extra Frost hit. It is the
## Rime Edge ability's own hit (its damage, its Chilled), dealt as a proc.
func _rime_edge_on_hit(info: RefCounted) -> void:
	if status == null or not status.has(RIME_EDGE_ID):
		return
	var tags: PackedStringArray = info.tags if not info.tags.is_empty() else Abilities.tags_of(str(info.ability_id))
	if not rime_edge_applies(tags, info.is_proc, info.is_dot, int(info.amount)):
		return
	if info.target == null or not is_instance_valid(info.target) or not info.target.is_alive():
		return
	deal_damage(info.target, float(Abilities.get_resource(RIME_EDGE_ID).damage) + _talent("frost_honed_rime"),
		RIME_EDGE_ID, true)   # + Honed Rime

## Icebreaker's coefficient: weapon damage x the ability's multiplier, or x
## ICEBREAKER_FROZEN_MULT on a target I have Frozen (+ the ability's flat part).
static func icebreaker_coef(weapon_damage: float, mult: float, flat: float, frozen: bool) -> float:
	return weapon_damage * (Balance.ICEBREAKER_FROZEN_MULT if frozen else mult) + flat

## Icebreaker: a heavy blow. If MY Freeze is on the target it is ended first (the
## blow breaks it) and the hit is the big one.
func _icebreaker(w: Dictionary, res: Resource) -> void:
	var st: Node = target.get_node_or_null("Status")
	var frozen: bool = st != null and st.has_from("frozen", self)
	var at: Vector3 = target.global_position
	if frozen:
		_end_freeze(target)
	deal_damage(target, icebreaker_coef(float(w.get("damage", 0.0)), float(res.weapon_damage_multiplier),
		float(res.damage), frozen), "icebreaker")
	_slash_effect(Abilities.color_of("icebreaker"))
	_slash_effect(Color(0.95, 0.97, 1.0))
	if frozen:
		var back := _talent("frost_clean_break")
		if back > 0.0:
			_gain("rage", back)   # Clean Break: part of its Rage comes back
		_ring_effect(1.1, Color(0.85, 0.95, 1.0), at)
		_ring_effect(0.6, Color(0.95, 0.97, 1.0), at)

## End the Freeze on `tgt`. The host owns enemy effects in a party; my copy of it
## goes at once so nothing here still sees it.
func _end_freeze(tgt: Node) -> void:
	var net := _net()
	if net:
		net.remove_status(tgt, "frozen")
	var st: Node = tgt.get_node_or_null("Status")
	if st:
		st.remove("frozen")
		st.suppress("frozen")

# --- Frost, the bow ---------------------------------------------------------------------
# Shatter Shot, Glacial Draw, Rimefletch, Coldmark and Icy Retreat. Everything
# that asks about a Freeze, a Chill, a root or a mark asks about MINE (has_from).

const SHATTER_SHOT_ID := "shattershot"
const GLACIAL_DRAW_ID := "glacialdraw"
const RIMEFLETCH_ID := "rimefletch"
const COLDMARK_ID := "coldmark"
## The mark Coldmark leaves on its target (data/effects).
const COLDMARK_FX := "coldmarked"
const ICY_RETREAT_ID := "icyretreat"
const ICE_PATCH = preload("res://scripts/ice_patch.gd")
var _shatter_shot_frozen := false   # the Shatter Shot being worked out hit a target I had Frozen
var _ice_patch_seen := {}           # enemies (instance ids) my current ice has Chilled already (Black Ice rolls once each)

## Have I Frozen `tgt` (own only: a party member's Freeze is not mine)?
func _frozen_by_me(tgt: Variant) -> bool:
	if tgt == null or not is_instance_valid(tgt) or not (tgt is Node):
		return false
	var st: Node = tgt.get_node_or_null("Status")
	return st != null and st.has_from("frozen", self)

## Shatter Shot's hit is being worked out (_on_damage_modify): it hits a target I
## have Frozen harder, and remembers that for when it lands (_shatter_shot_landed).
func _shatter_shot_modify(info: RefCounted) -> void:
	_shatter_shot_frozen = not bool(info.is_proc) and _frozen_by_me(info.target)
	if _shatter_shot_frozen:
		info.add_bonus(Balance.SHATTER_SHOT_FROZEN_PCT, "Shatter Shot")

## Damage (coefficient) the burst deals to each of `count` other enemies: more
## than AOE_TARGET_CAP of them share that many hits.
static func shatter_shot_burst(count: int) -> float:
	return float(Abilities.EXTRA_HITS[SHATTER_SHOT_ID]) * Balance.aoe_share(count)

## Shatter Shot landed on `enemy` (which stood at `at`). If it broke my Freeze,
## the target thaws and the ice bursts over the other enemies around it (procs:
## the burst feeds nothing else).
func _shatter_shot_landed(enemy: Node, at: Vector3) -> void:
	if not _shatter_shot_frozen:
		return
	_shatter_shot_frozen = false
	if is_instance_valid(enemy):
		_end_freeze(enemy)
	# Clean Shatter: breaking my Freeze gives Energy back and shortens the cooldown.
	var refund := _talent("frost_clean_shatter")
	if refund > 0.0:
		_gain("energy", refund)
		cooldowns[SHATTER_SHOT_ID] = clean_shatter_cooldown(float(cooldowns.get(SHATTER_SHOT_ID, 0.0)),
			_talent("frost_clean_shatter", "values2"))
	var r := float(Abilities.get_resource(SHATTER_SHOT_ID).radius)
	var others := _enemies_near(at, r, enemy)
	var coef := shatter_shot_burst(others.size())
	for e in others:
		deal_damage(e, coef, SHATTER_SHOT_ID, true)
	_ring_effect(r, Abilities.color_of(SHATTER_SHOT_ID), at)
	_ring_effect(r * 0.5, Color(0.95, 0.97, 1.0), at)

## Is Glacial Draw instant on `tgt`: rooted by MY Icepin, or Frozen by me?
func glacial_draw_instant(tgt: Variant) -> bool:
	if tgt == null or not is_instance_valid(tgt) or not (tgt is Node):
		return false
	return _icepin_root_on(tgt) or _frozen_by_me(tgt)

## Glacial Draw: a cast with the bow, or no cast at all on a target that can't
## get away (glacial_draw_instant). Paid for, and on cooldown, when the arrow leaves.
func _start_glacial_draw() -> void:
	var id := GLACIAL_DRAW_ID
	if casting:
		return
	if cooldown_left(id) > 0.0:
		_error("%s is not ready yet" % Abilities.ability_name(id))
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
	if glacial_draw_instant(target):
		if not _pay(id):
			return
		_loose_glacial_draw()
		_bus().cast_finished.emit(id)   # an instant: starts the global cooldown like one
		return
	_begin_spell(id, Abilities.ability_name(id), float(Abilities.get_resource(id).cast_time))

## Glacial Draw's arrow leaves the bow (its cast finished, or it was instant).
func _loose_glacial_draw() -> void:
	var id := GLACIAL_DRAW_ID
	var res := Abilities.get_resource(id)
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
	cooldowns[id] = Abilities.cooldown_of(res)
	var dir := target.global_position - global_position
	rotation.y = atan2(-dir.x, -dir.z)
	ARROW.spawn(get_tree().current_scene, _muzzle(), target, self, _weapon_hit(w, res), id)

## Rimefletch: a fresh set of charges (never more than RIMEFLETCH_SHOTS).
func _start_rimefletch() -> void:
	var col := Abilities.color_of(RIMEFLETCH_ID)
	var fx := StatusContainer.make_buff(RIMEFLETCH_ID, Abilities.ability_name(RIMEFLETCH_ID), RIMEFLETCH_ID, 0.0,
		Balance.RIMEFLETCH_TIME, Balance.RIMEFLETCH_SHOTS, col)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Frost"])
	fx.description = "Your next auto-shots deal %s%% more damage, as Frost damage, and Chill the target, one stack each." % Stats.num(Balance.RIMEFLETCH_PCT)
	status.remove(RIMEFLETCH_ID)
	if status.apply(fx, self):
		status.set_stacks(RIMEFLETCH_ID, Balance.RIMEFLETCH_SHOTS)
	_ring_effect(1.0, col)

## Frost damage Rimefletch adds to an auto-shot that dealt `amount`.
static func rimefletch_damage(amount: int) -> float:
	return maxf(float(amount) * Balance.RIMEFLETCH_PCT / 100.0, 0.0)

## Does a Rimefletch shot Freeze (true) or Chill (false) its target? It Freezes
## a target that already carries MY Chill (or my Freeze, which is a Chill and more).
static func rimefletch_freezes(chilled_by_me: bool, frozen_by_me: bool) -> bool:
	return chilled_by_me or frozen_by_me

## One of my hits landed (_on_damage_dealt_frost). An auto-shot with Rimefletch
## up uses a charge: an exact share of the shot again as Frost damage (its crit is
## already in it), dealt as a proc so it feeds nothing else, carrying the Chill
## or the Freeze.
func _rimefletch_shot(info: RefCounted) -> void:
	if status == null or str(info.ability_id) != "auto_ranged" or not status.has(RIMEFLETCH_ID):
		return
	status.spend_stacks(RIMEFLETCH_ID, 1)
	var foe: Node = info.target
	if not is_instance_valid(foe) or not foe.is_alive():
		return
	var st: Node = foe.get_node_or_null("Status")
	var freeze: bool = st != null and rimefletch_freezes(st.has_from("chilled", self), st.has_from("frozen", self))
	var extra := DamageInfo.make(self, foe, 1.0, RIMEFLETCH_ID)
	extra.unit = rimefletch_damage(int(info.amount))
	extra.exact = true
	extra.add_power = false
	extra.can_crit = false
	extra.can_block = false
	extra.is_proc = true
	extra.damage_type = "frost"
	extra.tags = PackedStringArray(["Ability", "Frost", "Ranged"])
	var fx: Resource = FROZEN_FX if freeze else CHILLED_FX
	extra.effects.append(fx)
	_combat().deal(extra)
	# Cold Harvest: a shot that Freezes (also a Chill that Deepwinter turns into one) gives Energy.
	if str(effect_override(fx).id) == "frozen":
		var harvest := _talent("frost_cold_harvest")
		if harvest > 0.0:
			_gain("energy", harvest)

## Coldmark: my mark goes on the target (a hit with no damage carrying the mark,
## its on-hit effect, so in a party it reaches the host).
func _coldmark(tgt: Node) -> void:
	if tgt == null or not is_instance_valid(tgt):
		return
	deal_damage(tgt, 0.0, COLDMARK_ID, true)
	if tgt is Node3D:
		_ring_effect(0.9, Abilities.color_of(COLDMARK_ID), (tgt as Node3D).global_position)

## Is `id` an arrow ability: a bow ability that looses an arrow (not an auto-shot)?
static func is_arrow_ability(id: String) -> bool:
	if id.begins_with("auto_"):
		return false   # auto-shots are arrows, but not abilities
	var r := Abilities.get_resource(id)
	return r != null and int(r.weapon_requirement) == 2 and r.tags.has("Projectile")

## One of my hits landed (_on_damage_dealt_frost). An arrow ability hitting a
## target that carries MY Coldmark gives an Ice Shard charge. Procs and periodic
## damage are not arrows.
func _coldmark_arrow(info: RefCounted) -> void:
	if bool(info.is_proc) or bool(info.is_dot) or not is_arrow_ability(str(info.ability_id)):
		return
	var st: Node = info.target.get_node_or_null("Status")
	if st != null and st.has_from(COLDMARK_FX, self):
		gain_ice_shard()

## Icy Retreat: a leap backward (it stops short of walls). The ground I left is
## ice for a while, and Frost Arrow is ready again.
func _icy_retreat(res: Resource) -> void:
	var col := Abilities.color_of(ICY_RETREAT_ID)
	var from := global_position
	var back := -_flat_forward()
	global_position += back * _dash_distance(Balance.ICY_RETREAT_DISTANCE, back)
	var r := float(res.radius)
	_ice_patch_seen.clear()   # a new sheet of ice: Black Ice rolls again for everyone
	ICE_PATCH.spawn(get_tree().current_scene, from, r, Balance.ICY_RETREAT_TIME, Balance.ICY_RETREAT_TICK, _ice_patch_chill)
	_net_fx("icepatch", from, null, {"r": r, "time": Balance.ICY_RETREAT_TIME})   # the party sees the ice
	cooldowns.erase("frostarrow")
	_ring_effect(0.8, col, from)
	_ring_effect(0.8, col)

## An enemy is standing on my ice: it is Chilled (a Freeze during Deepwinter).
## Black Ice: the first Chill the ice puts on each enemy may be a Freeze instead.
func _ice_patch_chill(e: Node) -> void:
	var key := e.get_instance_id()
	var first := not _ice_patch_seen.has(key)
	_ice_patch_seen[key] = true
	var freeze := first and randf() * 100.0 < _talent("frost_black_ice")
	_chill(e, ICY_RETREAT_ID, PackedStringArray(["Ability", "Frost"]), freeze)

## Have I Chilled `tgt` (own only)?
func _chilled_by_me(tgt: Variant) -> bool:
	if tgt == null or not is_instance_valid(tgt) or not (tgt is Node):
		return false
	var st: Node = tgt.get_node_or_null("Status")
	return st != null and st.has_from("chilled", self)

## Thin Ice: Glacial Draw's cast time on a target I have Chilled, `less` seconds
## shorter (never under 0.2 s). Unchanged on anything else.
static func thin_ice_cast(cast: float, less: float, chilled: bool) -> float:
	return maxf(cast - maxf(less, 0.0), 0.2) if chilled else cast

## Clean Shatter: what is left of Shatter Shot's cooldown with `off` seconds taken away.
static func clean_shatter_cooldown(left: float, off: float) -> float:
	return maxf(left - maxf(off, 0.0), 0.0)

## Cold Draw: one of my arrow abilities is about to hit (_on_damage_modify). If
## the target already carries MY Chill or Freeze - before this arrow adds its
## own - the hit is marked, and gives Energy back when it lands.
func _cold_draw_mark(info: RefCounted, id: String) -> void:
	if bool(info.is_proc) or bool(info.is_dot) or not is_arrow_ability(id) or _talent("frost_cold_draw") <= 0.0:
		return
	if _chilled_by_me(info.target) or _frozen_by_me(info.target):
		info.set_meta("cold_draw", true)

# --- Frozen Instinct: freezes can make the next Frost Bolt instant and free ------------

const INSTINCT_ID := "frozen_instinct"
var _instinct_cast := false   # the current Frost Bolt cast is the instant Frozen Instinct one

func _grant_frozen_instinct() -> void:
	if status == null or is_dead():
		return
	var fx := StatusContainer.make_buff(INSTINCT_ID, "Frozen Instinct", INSTINCT_ID, 0.0,
		Balance.FROZEN_INSTINCT_TIME, 1, Color(0.6, 0.9, 1.0))
	fx.stat_modifiers = {}
	fx.description = "Your next %s is instant and free." % Abilities.ability_name("frostbolt")
	status.apply(fx, self)

## Is the next Frost Bolt instant and free?
func frozen_instinct_ready() -> bool:
	return status != null and status.has(INSTINCT_ID)


# --- Holy healer: the Hymns ----------------------------------------------------------------------
# I sing one of three Hymns (none until I first sing one):
#   Mercy   my heals on a single ally heal MERCY_HEAL_PCT % more.
#   Chorus  those heals (not Refrain's ticks) also heal up to CHORUS_SPLASH_TARGETS
#           allies near their target, for a share (its own meter line).
#   Vigil   allies near me take less damage (a buff renewed every VIGIL_TELL_EVERY),
#           and my heals leave a small shield on whoever they heal.
# My Holy healer abilities give Verses (VERSE_GAINS; VERSE_MAX at most, more are
# wasted). Each Verse remembers the Hymn it suits: single-target heals Mercy, heals
# on many Chorus, shields and less damage taken Vigil. Singing another Hymn:
#   with VERSE_MAX Verses  the Hymn I enter booms (Benediction, Chorale, Bulwark of
#                          Song), stronger for each spent Verse that suits it, and
#                          every Verse is spent. When my last three booms were the
#                          three Hymns, the third is a Full Choir: stronger, and
#                          FULL_CHOIR_REFUND Verses come back.
#   with fewer             they are lost (Key Change keeps some, Rest keeps all).
#   from no Hymn yet       nothing is lost (but VERSE_MAX still booms).
# Out of combat the Verses fade, one every VERSE_DRAIN_EVERY seconds.
# Everything is decided here, on the healer's machine. A party member hears of it
# through Net.support_ally: "heal" (like every heal), "hymn_dr" (less damage taken:
# Vigil, Steady Voice, Bulwark of Song) and "hymn_ward" (a shield: Shelter, Vigil's);
# standing in my Vigil they answer "vigil_hit" when a big hit lands (Watchful). The
# ring around me is scripts/hymn_ring.gd (only a picture); the party sees it through
# the "hymn" and "hymn_boom" fx. Numbers: balance.gd (VERSE_*, MERCY_*, ...).

const HYMN_RING = preload("res://scripts/hymn_ring.gd")
const HIGH_NOTE_ID := "highnote"
const SING_IDS := {"singmercy": "mercy", "singchorus": "chorus", "singvigil": "vigil"}
const HYMN_NAMES := {"mercy": "Mercy", "chorus": "Chorus", "vigil": "Vigil"}
const BOOM_NAMES := {"mercy": "Benediction", "chorus": "Chorale", "vigil": "Bulwark of Song"}
## Meter / log ids (Details.HIT_NAMES) of the booms' heals, Chorus's splash and the rune's hit.
const BOOM_IDS := {"mercy": "benediction", "chorus": "chorale", "vigil": "bulwark_of_song"}
const CHORUS_SPLASH_ID := "chorus_splash"
const RESOUNDING_ID := "resounding"
const RESOUNDING_RUNE := "resounding"
const OVERTURE_RUNE := "overture"
## What each ability gives (balance.gd).
const VERSE_GAINS := Balance.VERSE_GAINS
## Heals on a single ally: Mercy makes them stronger, Chorus splashes them (not Refrain's ticks).
const HYMN_SINGLE_HEALS := ["psalm", "outpour", "lift", "refrain", "antiphon"]
const CHORUS_SPLASHES := ["psalm", "outpour", "lift", "antiphon"]
## My heals that leave Vigil's shield, and that Mercy's Ear listens to.
const HYMN_HEALS := ["psalm", "outpour", "lift", "refrain", "antiphon", "canticle", "exultation", "highnote",
	"benediction", "chorale"]
## The kit's instant abilities (Psalm, Outpour, Canticle and Exultation are cast: SUPPORT_CASTS; High Note is a bolt).
const HYMN_INSTANTS := ["lift", "refrain", "antiphon", "shelter", "steadyvoice", "reprise", "swell", "rest", "lastverse",
	"singmercy", "singchorus", "singvigil"]
## Buffs (StatusEffect ids). The ones that take damage off are sent to party members as "hymn_dr".
const VIGIL_FX := "vigil"
const STEADY_VOICE_FX := "steady_voice"
const BULWARK_SONG_FX := "bulwark_of_song"
const REST_FX := "rest"
const SWELL_FX := "swell"
const OVERTURE_FX := "overture"
const SHELTER_FX := "shelter"
const VIGIL_WARD_FX := "vigil_ward"
const HYMN_DR_NAMES := {VIGIL_FX: "Vigil", STEADY_VOICE_FX: "Steady Voice", BULWARK_SONG_FX: "Bulwark of Song", REST_FX: "Rest"}
const HYMN_WARD_NAMES := {SHELTER_FX: "Shelter", VIGIL_WARD_FX: "Vigil's Ward"}
const HOLY_LIGHT := Color(1.0, 0.88, 0.45)

var hymn := ""              # the Hymn I sing ("" = none yet)
var verses: Array = []      # my Verses, oldest first: each is the Hymn it suits
var _booms: Array = []      # the Hymns of my booms since the last Full Choir
var _last_boom := {}        # {"hymn", "matches", "full", "at"}: what Reprise repeats
var _verse_drain_at := 0.0
var _vigil_told := 0.0
var _refrains := {}         # target instance id -> {"node", "until", "next", "per"}
var _talent_verse_at := {}  # talent key -> when it last gave me a Verse
var _vigil_from := {}       # caster instance id -> {"from": Node, "until": time}: whose Vigil I stand in

# The rules, as plain functions (tests/test_hymns.gd).

## `have` Verses plus `n` that suit `kind`: none past VERSE_MAX.
static func verses_after_gain(have: Array, kind: String, n: int) -> Array:
	var out := have.duplicate()
	for i in maxi(n, 0):
		if out.size() >= Balance.VERSE_MAX:
			break
		out.append(kind)
	return out

## Singing a Hymn with `count` Verses: [does the Hymn I enter boom, how many Verses I keep].
## `from` = the Hymn I sang until now ("" = none); `kept` = Key Change's; `resting` = Rest.
static func sing_outcome(count: int, from: String, kept: int, resting: bool) -> Array:
	if count >= Balance.VERSE_MAX:
		return [true, 0]
	if from == "" or resting:
		return [false, maxi(count, 0)]
	return [false, clampi(kept, 0, maxi(count, 0))]

## How many of the `spent` Verses suit the Hymn `boom` (each makes the boom stronger).
static func matching_verses(spent: Array, boom: String) -> int:
	var n := 0
	for v in spent:
		if str(v) == boom:
			n += 1
	return n

## A boom's strength with `matches` Verses that suit it (`full`: a Full Choir).
static func boom_mult(matches: int, full: bool) -> float:
	var m := 1.0 + Balance.BOOM_MATCH_PCT * clampi(matches, 0, Balance.VERSE_MAX) / 100.0
	return m * (1.0 + Balance.FULL_CHOIR_PCT / 100.0 if full else 1.0)

## Bulwark of Song's seconds: longer for each Verse that suits it instead of stronger.
static func bulwark_song_time(matches: int, full: bool) -> float:
	var t := Balance.BULWARK_SONG_TIME + Balance.BULWARK_SONG_MATCH_TIME * clampi(matches, 0, Balance.VERSE_MAX)
	return t * (1.0 + Balance.FULL_CHOIR_PCT / 100.0 if full else 1.0)

## Is the newest of these booms (oldest first) a Full Choir: the last three were the three Hymns?
static func is_full_choir(booms: Array) -> bool:
	if booms.size() < 3:
		return false
	var last := booms.slice(booms.size() - 3)
	return last.has("mercy") and last.has("chorus") and last.has("vigil")

## Can Reprise be used `since` seconds after the last boom, with `count` Verses?
static func reprise_ready(since: float, count: int) -> bool:
	return since >= 0.0 and since <= Balance.REPRISE_WINDOW and count >= Balance.REPRISE_COST

## The share (0-1) of health someone at `hp` of `max_hp` has.
static func health_share(hp: float, max_hp: float) -> float:
	return clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 1.0

# Gaining and spending Verses.

func _add_verses(kind: String, n: int) -> void:
	verses = verses_after_gain(verses, kind if kind != "" else "mercy", n)

## Ability `id` was used: its Verses (Swell: more).
func _gain_verses(id: String) -> void:
	var g: Array = VERSE_GAINS.get(id, [])
	if g.is_empty():
		return
	var kind := str(g[1]) if str(g[1]) != "" else hymn
	var extra: int = Balance.SWELL_EXTRA if status != null and status.has(SWELL_FX) else 0
	_add_verses(kind, int(g[0]) + extra)

## The healer talents that give a Verse now and then (Mercy's Ear, Many Voices,
## Watchful): their value is the seconds between two of them.
func _talent_verse(key: String, kind: String) -> void:
	var every := _talent(key)
	if every <= 0.0:
		return
	var now := _str_now()
	if now - float(_talent_verse_at.get(key, -INF)) < every:
		return
	_talent_verse_at[key] = now
	_add_verses(kind, 1)

func _tick_hymns() -> void:
	var now := _str_now()
	if is_dead():
		verses.clear()
		_refrains.clear()
		return
	# Out of combat the Verses fade.
	if verses.is_empty() or is_in_combat():
		_verse_drain_at = now + Balance.VERSE_DRAIN_EVERY
	elif now >= _verse_drain_at:
		verses.pop_front()
		_verse_drain_at = now + Balance.VERSE_DRAIN_EVERY
	# Vigil: allies near me take less damage (renewed while they stay near).
	if hymn == "vigil" and now >= _vigil_told:
		_vigil_told = now + Balance.VIGIL_TELL_EVERY
		for a in _allies_within(Balance.VIGIL_RADIUS):
			_hymn_dr(a, VIGIL_FX, Balance.VIGIL_DR_PCT, Balance.VIGIL_BUFF_TIME)
	_tick_refrains(now)
	for key in _vigil_from.keys():
		if now > float(_vigil_from[key]["until"]):
			_vigil_from.erase(key)

# Singing, and the booms.

## Sing Mercy / Chorus / Vigil: enter that Hymn (booming with a full set of Verses).
func _sing(to: String) -> void:
	var resting: bool = status != null and status.has(REST_FX)
	var outcome := sing_outcome(verses.size(), hymn, int(round(_talent("holy_key_change"))), resting)
	var spent := verses.duplicate()
	hymn = to
	if bool(outcome[0]):
		verses.clear()
		_boom(to, spent)
	else:
		var kept := int(outcome[1])
		verses = verses.slice(verses.size() - kept) if kept > 0 else []
	_vigil_told = 0.0   # (Vigil: at once)
	_show_hymn()

func _boom(h: String, spent: Array) -> void:
	_booms.append(h)
	var full := is_full_choir(_booms)
	if full:
		_booms.clear()   # (the next Full Choir needs three new booms)
	var matches := matching_verses(spent, h)
	_last_boom = {"hymn": h, "matches": matches, "full": full, "at": _str_now()}
	_do_boom(h, matches, full, 1.0)
	if full:
		_add_verses(h, Balance.FULL_CHOIR_REFUND)
		_combat().float_text(self, "Full Choir", Abilities.HYMN_COLORS[h], false)
	if _has_rune(OVERTURE_RUNE) and status != null:
		status.apply(make_overture_fx(), self)

## A boom of Hymn `h` (`scale` < 1: Reprise's repeat of it).
func _do_boom(h: String, matches: int, full: bool, scale: float) -> void:
	var mult := boom_mult(matches, full) * scale
	var at := global_position
	match h:
		"mercy":
			var who: Node3D = friendly_target if has_friendly_target() else self
			_heal_coef(who, Balance.BENEDICTION_HEAL * mult, BOOM_IDS[h])
			at = who.global_position
		"chorus":
			for a in _allies_within(Balance.CHORALE_RADIUS):
				_heal_coef(a, Balance.CHORALE_HEAL * mult, BOOM_IDS[h])
		"vigil":
			var t := bulwark_song_time(matches, full)
			for a in _allies_within(Balance.BULWARK_SONG_RADIUS):
				_hymn_dr(a, BULWARK_SONG_FX, Balance.BULWARK_SONG_PCT * scale, t)
	# Rune of Resounding: the boom strikes the enemies around it as well.
	if _has_rune(RESOUNDING_RUNE):
		var foes := _enemies_near(at, Balance.RESOUNDING_RADIUS)
		var share := Balance.aoe_share(foes.size())
		for e in foes:
			deal_damage(e, Balance.RESOUNDING_DAMAGE * scale * share, RESOUNDING_ID, true, "holy", PackedStringArray(["Holy", "Spell"]))
	if is_inside_tree():
		HYMN_RING.boom(get_tree().current_scene, at, Abilities.HYMN_COLORS[h])
	_net_fx("hymn_boom", at, null, {"h": h})
	_combat().float_text(self, BOOM_NAMES[h], Abilities.HYMN_COLORS[h], false)

## The ring around me shows my Hymn (and the party sees it).
func _show_hymn() -> void:
	if is_inside_tree():
		HYMN_RING.show_on(self, hymn)
	_net_fx("hymn", global_position, null, {"h": hymn})

# The abilities.

## "Can I use it right now?" for the kit's instants (before paying).
func _hymn_precheck(id: String) -> String:
	if SING_IDS.has(id):
		return "You are already singing %s" % HYMN_NAMES[SING_IDS[id]] if hymn == SING_IDS[id] else ""
	match id:
		"lift", "refrain", "antiphon", "shelter":
			var pick := _pick_support_target(id)
			if pick[0] == null:
				return str(pick[1])
		"reprise":
			if _last_boom.is_empty() or not reprise_ready(_str_now() - float(_last_boom["at"]), Balance.REPRISE_COST):
				return "You have not boomed in the last %s sec" % Stats.num(Balance.REPRISE_WINDOW)
			if verses.size() < Balance.REPRISE_COST:
				return "Not enough Verses"
		"lastverse":
			if verses.size() < Balance.VERSE_MAX:
				return "Not enough Verses"
			if _fallen_ally(float(Abilities.get_resource(id).cast_range)) == null:
				return "No downed ally in range"
	return ""

func _hymn_use(id: String, res: Resource) -> void:
	if SING_IDS.has(id):
		_sing(SING_IDS[id])
		return
	match id:
		"lift":
			var who: Node3D = _pick_support_target(id)[0]
			if who:
				_heal_coef(who, _hymn_heal_coef(id), id)
				_ring_effect(0.8, HOLY_LIGHT, who.global_position)
		"refrain":
			var who: Node3D = _pick_support_target(id)[0]
			if who:
				_start_refrain(who)
		"antiphon":
			var who: Node3D = _pick_support_target(id)[0]
			if who:
				var amount := _heal_coef(who, _hymn_heal_coef(id), id)
				if not is_same(who, self):
					_heal_exact(self, int(round(amount * Balance.ANTIPHON_SELF_PCT / 100.0)), id)
				_ring_effect(0.8, HOLY_LIGHT, who.global_position)
		"shelter":
			var who: Node3D = _pick_support_target(id)[0]
			if who:
				var coef := float(Abilities.HEALS[id]) * (1.0 + _talent("holy_open_doors") / 100.0)   # Open Doors
				_hymn_ward(who, SHELTER_FX, _combat().heal_amount(self, coef, id), Balance.SHELTER_TIME)
				_ring_effect(1.0, HOLY_LIGHT, who.global_position)
		"steadyvoice":
			for a in _allies_within(float(res.radius)):
				_hymn_dr(a, STEADY_VOICE_FX, Balance.STEADY_VOICE_PCT, Balance.STEADY_VOICE_TIME)
			_ring_effect(float(res.radius), Abilities.HYMN_COLORS["vigil"])
		"reprise":
			verses = verses.slice(0, verses.size() - Balance.REPRISE_COST)
			_do_boom(str(_last_boom["hymn"]), int(_last_boom["matches"]), bool(_last_boom["full"]), Balance.REPRISE_PCT / 100.0)
		"swell":
			status.apply(make_swell_fx(), self)
		"rest":
			status.apply(make_hymn_dr_fx(REST_FX, Balance.REST_PCT, Balance.REST_TIME), self)
			status.set_remaining(REST_FX, Balance.REST_TIME)
		"lastverse":
			var ally := _fallen_ally(float(res.cast_range))
			if ally and _net():
				_net().revive_ally(ally, self)
				_ring_effect(1.4, HOLY_LIGHT, ally.global_position)
			verses.clear()
	_gain_verses(id)

## A heal of the kit, as a coefficient: Mercy makes the ones on a single ally stronger.
func _hymn_heal_coef(id: String) -> float:
	var coef := float(Abilities.HEALS.get(id, 0.0))
	if hymn == "mercy" and HYMN_SINGLE_HEALS.has(id):
		coef *= 1.0 + Balance.MERCY_HEAL_PCT / 100.0
	return coef

## Psalm, Outpour, Canticle and Exultation finished casting (_release_support).
func _hymn_cast_heal(spell: String, tgt: Variant, kind: String) -> void:
	match spell:
		"psalm", "outpour":
			var who: Variant = tgt if kind == "ally" and tgt != null and is_instance_valid(tgt) else self
			_heal_coef(who, _hymn_heal_coef(spell), spell)
			_ring_effect(1.2, HOLY_LIGHT, (who as Node3D).global_position)
		"canticle":
			# The injured allies near me, lowest health first.
			var hurt: Array = _allies_within(float(Abilities.get_resource(spell).radius)).filter(func(a):
				return _health_share_of(a) < 1.0)
			hurt.sort_custom(func(a, b): return _health_share_of(a) < _health_share_of(b))
			hurt = hurt.slice(0, Balance.CANTICLE_TARGETS)
			for a in hurt:
				_heal_coef(a, _hymn_heal_coef(spell), spell)
				_ring_effect(0.7, HOLY_LIGHT, (a as Node3D).global_position)
			if hurt.size() >= Balance.MANY_VOICES_ALLIES:
				_talent_verse("holy_many_voices", "chorus")   # Many Voices
		"exultation":
			var all := _allies_within(float(Abilities.get_resource(spell).radius))
			for a in all:
				_heal_coef(a, _hymn_heal_coef(spell), spell)
			_ring_effect(float(Abilities.get_resource(spell).radius), HOLY_LIGHT)
			if all.size() >= Balance.MANY_VOICES_ALLIES:
				_talent_verse("holy_many_voices", "chorus")   # Many Voices
	_gain_verses(spell)

func _health_share_of(a: Variant) -> float:
	if a == null or not is_instance_valid(a):
		return 1.0
	return health_share(float(a.get("health")), float(a.get("max_health")))

# Refrain: a heal over time I keep track of (it heals through _heal_coef, so a
# party member is healed on their own machine like any other heal of mine).

func _start_refrain(who: Node3D) -> void:
	var now := _str_now()
	var per := _hymn_heal_coef("refrain") * Balance.REFRAIN_TICK / Balance.REFRAIN_TIME
	_refrains[who.get_instance_id()] = {"node": who, "until": now + Balance.REFRAIN_TIME,
		"next": now + Balance.REFRAIN_TICK / maxf(haste_mult(), 0.1), "per": per}
	_ring_effect(0.8, HOLY_LIGHT, who.global_position)

func _tick_refrains(now: float) -> void:
	for key in _refrains.keys():
		var e: Dictionary = _refrains[key]
		var who: Variant = e["node"]
		if who == null or not is_instance_valid(who) or not who.is_alive() or now > float(e["until"]):
			_refrains.erase(key)
			continue
		if now >= float(e["next"]):
			e["next"] = float(e["next"]) + Balance.REFRAIN_TICK / maxf(haste_mult(), 0.1)
			_heal_coef(who, float(e["per"]), "refrain")

# What my heals do on top (SignalBus.heal_done hears every heal).

func _on_heal_done_hymns(source: Node, healed: Node, amount: int, effective: int, id: String, _crit: bool) -> void:
	if amount <= 0 or not is_same(source, self) or healed == null or not is_instance_valid(healed):
		return
	if not HYMN_HEALS.has(id):
		return
	# Mercy's Ear: healing an ally who is low gives a Mercy Verse now and then.
	var before := _health_share_of(healed)
	if is_same(healed, self) or healed.is_in_group("friendly"):
		before = health_share(float(healed.get("health")) - effective, float(healed.get("max_health")))   # (already healed here)
	if before * 100.0 < Balance.MERCYS_EAR_HEALTH_PCT:
		_talent_verse("holy_mercys_ear", "mercy")
	match hymn:
		"chorus":
			if CHORUS_SPLASHES.has(id):
				_chorus_splash(healed as Node3D, amount)
		"vigil":
			_hymn_ward(healed as Node3D, VIGIL_WARD_FX, int(round(amount * Balance.VIGIL_WARD_PCT / 100.0)), Balance.VIGIL_WARD_TIME)

## Chorus: up to CHORUS_SPLASH_TARGETS other allies near the one I healed get a share.
func _chorus_splash(healed: Node3D, amount: int) -> void:
	if healed == null:
		return
	var near: Array = []
	for a in _allies_within(INF):
		if not is_same(a, healed) and (a as Node3D).global_position.distance_to(healed.global_position) <= Balance.CHORUS_SPLASH_RADIUS:
			near.append(a)
	near.sort_custom(func(a, b): return healed.global_position.distance_squared_to(a.global_position) \
		< healed.global_position.distance_squared_to(b.global_position))
	near = near.slice(0, Balance.CHORUS_SPLASH_TARGETS)
	var share := int(round(amount * Balance.CHORUS_SPLASH_PCT / 100.0))
	for a in near:
		_heal_exact(a, share, CHORUS_SPLASH_ID)
	if near.size() + 1 >= Balance.MANY_VOICES_ALLIES:
		_talent_verse("holy_many_voices", "chorus")   # Many Voices (the splash counts)

## High Note landed: my lowest-health ally near me is healed for a share of its damage.
func _on_damage_dealt_holy(info: RefCounted) -> void:
	if info.source != self or info.ability_id != HIGH_NOTE_ID or int(info.amount) <= 0 or info.is_proc:
		return
	var allies := _allies_within(Balance.HIGH_NOTE_REACH)
	if allies.is_empty():
		return
	var shares: Array = allies.map(func(a): return _health_share_of(a))
	var who: Node3D = allies[lowest_share(shares)]
	_heal_exact(who, int(round(float(info.amount) * Balance.HIGH_NOTE_HEAL_PCT / 100.0)), HIGH_NOTE_ID)

# Effects on allies: less damage taken, and shields.

## `who` takes `pct` % less damage for `time` sec (buff `fx_id`), on whichever machine they live.
func _hymn_dr(who: Variant, fx_id: String, pct: float, time: float) -> void:
	if who == null or not is_instance_valid(who) or pct <= 0.0 or time <= 0.0:
		return
	if is_same(who, self):
		receive_hymn_dr(self, fx_id, pct, time)
	elif (who as Node).is_in_group("friendly"):
		var st: Node = (who as Node).get_node_or_null("Status")
		if st:
			st.apply(make_hymn_dr_fx(fx_id, pct, time), self)
			st.set_remaining(fx_id, time)
	elif _net():
		_net().support_ally(who, self, "hymn_dr", {"id": fx_id, "pct": pct, "time": time})

## A shield of `amount` (buff `fx_id`) on `who`, for `time` sec.
func _hymn_ward(who: Variant, fx_id: String, amount: int, time: float) -> void:
	if who == null or not is_instance_valid(who) or amount <= 0:
		return
	if is_same(who, self):
		_hymn_ward_on(status, self, fx_id, amount, time)
	elif (who as Node).is_in_group("friendly"):
		_hymn_ward_on((who as Node).get_node_or_null("Status"), self, fx_id, amount, time)
	elif _net():
		_net().support_ally(who, self, "hymn_ward", {"id": fx_id, "amount": amount, "time": time})
	if fx_id == SHELTER_FX:
		_combat().float_text(who, "%s (%d)" % [HYMN_WARD_NAMES[fx_id], amount], HOLY_LIGHT, false)

func _hymn_ward_on(st: Node, from: Node, fx_id: String, amount: int, time: float) -> void:
	if st == null or amount <= 0:
		return
	st.apply(make_hymn_ward_fx(fx_id, time), from)
	st.set_remaining(fx_id, time)
	st.set_absorb(fx_id, amount)

## Less damage taken from a healer's Hymns lands on me (`from`: whose).
func receive_hymn_dr(from: Node, fx_id: String, pct: float, time: float) -> void:
	if status == null or is_dead() or not HYMN_DR_NAMES.has(fx_id):
		return
	status.apply(make_hymn_dr_fx(fx_id, pct, time), from)
	status.set_remaining(fx_id, time)
	if fx_id == VIGIL_FX and from != null and is_instance_valid(from):
		_vigil_from[from.get_instance_id()] = {"from": from, "until": _str_now() + time}

## Watchful: a big hit on me while I stand in a healer's Vigil gives them a Vigil Verse.
func _vigil_taken(info: RefCounted) -> void:
	if _vigil_from.is_empty() or int(info.amount) <= 0 or info.avoided():
		return
	if float(info.amount) * 100.0 < float(max_health) * Balance.WATCHFUL_HIT_PCT:
		return
	for key in _vigil_from:
		var from: Variant = _vigil_from[key]["from"]
		if from == null or not is_instance_valid(from):
			continue
		if is_same(from, self):
			_talent_verse("holy_watchful", "vigil")
		elif _net():
			_net().support_ally(from, self, "vigil_hit", {})

# The buffs.

static func make_hymn_dr_fx(fx_id: String, pct: float, time: float) -> Resource:
	var color: Color = Abilities.HYMN_COLORS["vigil"] if fx_id != REST_FX else HOLY_LIGHT
	var fx := StatusContainer.make_buff(fx_id, str(HYMN_DR_NAMES.get(fx_id, fx_id)), fx_id, 0.0, time, 1, color)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Holy", "Defensive"])
	fx.damage_mod_pct = -absf(pct)
	fx.modifies_incoming = true
	fx.mod_affects_dots = true
	fx.description = "You take %s%% less damage." % Stats.num(absf(pct))
	return fx

static func make_hymn_ward_fx(fx_id: String, time: float) -> Resource:
	var fx := StatusContainer.make_buff(fx_id, str(HYMN_WARD_NAMES.get(fx_id, fx_id)), fx_id, 0.0, time, 1, HOLY_LIGHT)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Holy", "Defensive"])
	fx.description = "A shield of holy light absorbs damage."
	return fx

static func make_swell_fx() -> Resource:
	var fx := StatusContainer.make_buff(SWELL_FX, "Swell", SWELL_FX, 0.0, Balance.SWELL_TIME, 1, HOLY_LIGHT)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Holy"])
	fx.description = "Everything that gives you Verses gives %d more." % Balance.SWELL_EXTRA
	return fx

static func make_overture_fx() -> Resource:
	var fx := StatusContainer.make_buff(OVERTURE_FX, "Overture", OVERTURE_FX, 0.0, Balance.OVERTURE_TIME, 1, HOLY_LIGHT)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Holy"])
	fx.description = "Your next spell with a cast time is instant."
	return fx

## Rune of the Overture: is my next cast of `spell` instant?
func overture_ready(spell: String) -> bool:
	if status == null or not status.has(OVERTURE_FX):
		return false
	var r := Abilities.get_resource(spell)
	return r != null and int(r.cast_type) == 1 and float(r.cast_time) > 0.0

## The Verses shown on a button (Sing, Reprise, Last Verse).
func verses_text(id: String) -> String:
	if SING_IDS.has(id) or id == "reprise" or id == "lastverse":
		return str(verses.size())
	return ""
