extends CharacterBody3D
class_name Player


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

# --- Components ----------------------------------------------------------------------------
# Each spec's own code lives in a component (scripts/player/*.gd, see player_kit.gd),
# made here as a child node; tools/split_section.pl adds the line for each one.
var lightning_caster: LightningCasterKit = _kit(LightningCasterKit) as LightningCasterKit
var storm_arrow_kit: StormArrowKit = _kit(StormArrowKit) as StormArrowKit
var bottled_kit: BottledLightningKit = _kit(BottledLightningKit) as BottledLightningKit
var fire_lightning_talents: FireLightningTalentsKit = _kit(FireLightningTalentsKit) as FireLightningTalentsKit
var lightning_melee: LightningMeleeKit = _kit(LightningMeleeKit) as LightningMeleeKit
var lightning_tank: LightningTankKit = _kit(LightningTankKit) as LightningTankKit
var overload_kit: OverloadKit = _kit(OverloadKit) as OverloadKit
var arcane_caster: ArcaneCasterKit = _kit(ArcaneCasterKit) as ArcaneCasterKit
var arcane_tank: ArcaneTankKit = _kit(ArcaneTankKit) as ArcaneTankKit
var arcane_open: ArcaneOpenTalentsKit = _kit(ArcaneOpenTalentsKit) as ArcaneOpenTalentsKit
var arcane_melee: ArcaneMeleeKit = _kit(ArcaneMeleeKit) as ArcaneMeleeKit
var decay: DecayKit = _kit(DecayKit) as DecayKit
var shadow_talents: ShadowTalentsKit = _kit(ShadowTalentsKit) as ShadowTalentsKit
var hounds: HoundsKit = _kit(HoundsKit) as HoundsKit
var strings: StringsKit = _kit(StringsKit) as StringsKit
var hymns: HymnsKit = _kit(HymnsKit) as HymnsKit
var censer: CenserKit = _kit(CenserKit) as CenserKit
var prism_kit: PrismsKit = _kit(PrismsKit) as PrismsKit
var lightstring: LightstringKit = _kit(LightstringKit) as LightstringKit
var holy_talents: HolyTalentsKit = _kit(HolyTalentsKit) as HolyTalentsKit
var weaver: WeaverKit = _kit(WeaverKit) as WeaverKit
var shepherd: ShepherdKit = _kit(ShepherdKit) as ShepherdKit
var colossus: ColossusKit = _kit(ColossusKit) as ColossusKit
var venomstring: VenomstringKit = _kit(VenomstringKit) as VenomstringKit

## A component of `script` working for me (a child node, made before _ready).
func _kit(script: Script) -> Node:
	var k: Node = script.new()
	k.name = str(script.get_global_name())
	k.set("player", self)
	add_child(k)
	return k


# Forwards to VenomstringKit (called from other scripts).
func venom() -> float:
	return venomstring.venom()

func venom_flow() -> bool:
	return venomstring.venom_flow()

func poisons_on(e: Node) -> Array:
	return venomstring.poisons_on(e)

func venom_cost(id: String) -> float:
	return venomstring.venom_cost(id)


# Forwards to ColossusKit (called from other scripts).
func sap() -> int:
	return colossus.sap()

func awakened() -> bool:
	return colossus.awakened()

func grasped(e: Node) -> bool:
	return colossus.grasped(e)


# Forwards to ShepherdKit (called from other scripts).
func blossoms_on(who: Variant) -> int:
	return shepherd.blossoms_on(who)


# Forwards to WeaverKit (called from other scripts).
func mulch() -> Array:
	return weaver.mulch()


# Forwards to HolyTalentsKit (called from other scripts).
func hit_recently(who: Variant, window: float) -> bool:
	return holy_talents.hit_recently(who, window)


# Forwards to PrismsKit (called from other scripts).
func prisms() -> Array:
	return prism_kit.prisms()

func prisms_of(kind: String) -> int:
	return prism_kit.prisms_of(kind)


# Forwards to CenserKit (called from other scripts).
func incense() -> int:
	return censer.incense()

func censer_raised() -> bool:
	return censer.censer_raised()

func censer_out() -> bool:
	return censer.censer_out()

func motes() -> Array:
	return censer.motes()

func mote_reach() -> float:
	return censer.mote_reach()

func mote_time() -> float:
	return censer.mote_time()


# Forwards to HymnsKit (called from other scripts).
const HYMN_NAMES = HymnsKit.HYMN_NAMES

var hymn: String:
	get:
		return hymns.hymn
	set(v):
		hymns.hymn = v

var verses: Array:
	get:
		return hymns.verses
	set(v):
		hymns.verses = v

func receive_hymn_dr(from: Node, fx_id: String, pct: float, time: float) -> void:
	hymns.receive_hymn_dr(from, fx_id, pct, time)

func overture_ready(spell: String) -> bool:
	return hymns.overture_ready(spell)

func verses_text(id: String) -> String:
	return hymns.verses_text(id)


# Forwards to StringsKit (called from other scripts).
func string_time() -> float:
	return strings.string_time()

func strings_placed() -> int:
	return strings.strings_placed()

func strings_out() -> int:
	return strings.strings_out()

func string_charges() -> int:
	return strings.string_charges()

func strings_on(who: Variant) -> int:
	return strings.strings_on(who)

func on_my_string(who: Variant) -> bool:
	return strings.on_my_string(who)

func receive_support(kind: String, from: Node, data: Dictionary) -> void:
	strings.receive_support(kind, from, data)


# Forwards to HoundsKit (called from other scripts).
func hounds_out() -> bool:
	return hounds.hounds_out()


# Forwards to ShadowTalentsKit (called from other scripts).
func crit_hit_bonus(info: RefCounted) -> Array:
	return shadow_talents.crit_hit_bonus(info)


# Forwards to DecayKit (called from other scripts).
func interest_ready() -> bool:
	return decay.interest_ready()

func decay_on(foe: Variant) -> float:
	return decay.decay_on(foe)

func decay_open_on(foe: Variant) -> bool:
	return decay.decay_open_on(foe)


# Forwards to ArcaneMeleeKit (called from other scripts).
func traces() -> int:
	return arcane_melee.traces()


# Forwards to ArcaneOpenTalentsKit (called from other scripts).
func self_buff_time_mult(_res: Resource = null) -> float:
	return arcane_open.self_buff_time_mult(_res)


# Forwards to ArcaneTankKit (called from other scripts).
func has_dual_wield() -> bool:
	return arcane_tank.has_dual_wield()

func reflections() -> int:
	return arcane_tank.reflections()

func dodge_cap() -> float:
	return arcane_tank.dodge_cap()

func shatter_radius() -> float:
	return arcane_tank.shatter_radius()

func decoy_needs_reflection() -> bool:
	return arcane_tank.decoy_needs_reflection()

func damage_taken_recently(window: float) -> int:
	return arcane_tank.damage_taken_recently(window)

func stand_in_for(_info: RefCounted) -> bool:
	return arcane_tank.stand_in_for(_info)


# Forwards to ArcaneCasterKit (called from other scripts).
func arcane_cooldowns(except: String = "") -> int:
	return arcane_caster.arcane_cooldowns(except)

func sigil_dart_count() -> int:
	return arcane_caster.sigil_dart_count()

func bolt_tag(t: String) -> void:
	arcane_caster.bolt_tag(t)

func glint_ready(id: String) -> bool:
	return arcane_caster.glint_ready(id)


# Forwards to OverloadKit (called from other scripts).
func static_stacks() -> int:
	return overload_kit.static_stacks()


# Forwards to LightningTankKit (called from other scripts).
func has_two_hander() -> bool:
	return lightning_tank.has_two_hander()

func parry_cap() -> float:
	return lightning_tank.parry_cap()

func attack_speed_bonus() -> float:
	return lightning_tank.attack_speed_bonus()


# Forwards to LightningMeleeKit (called from other scripts).
func overdrive_active() -> bool:
	return lightning_melee.overdrive_active()


# Forwards to FireLightningTalentsKit (called from other scripts).
func dot_last_tick_pct(_res: Resource = null) -> float:
	return fire_lightning_talents.dot_last_tick_pct(_res)


# Forwards to BottledLightningKit (called from other scripts).
func bottled_ready(spell: String) -> bool:
	return bottled_kit.bottled_ready(spell)

func standing_charge_bonus() -> float:
	return bottled_kit.standing_charge_bonus()

func storm_cycle_ready() -> bool:
	return bottled_kit.storm_cycle_ready()

func flicker_ready(spell: String) -> bool:
	return bottled_kit.flicker_ready(spell)


# Forwards to StormArrowKit (called from other scripts).
func quiver_loaded() -> bool:
	return storm_arrow_kit.quiver_loaded()


# Forwards to LightningCasterKit (called from other scripts).
func surge_active() -> bool:
	return lightning_caster.surge_active()

func ball_lightning_zapped(zaps: int) -> void:
	lightning_caster.ball_lightning_zapped(zaps)

# --- End of components ---

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
	amount = strings._still_standing_limit(amount)   # Still Standing: the Strings hold off a killing blow
	amount = censer._unfallen_cap(amount)           # Unfallen: nothing can kill me
	if amount <= 0:
		return
	health = max(health - amount, 0)
	_pact_on_damage(amount)      # my Pact: one big hit (Sidestep), too little health left (Thin Line)
	arcane_tank._note_damage_taken(amount)   # Trade Places looks back on it
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
	arcane_caster._clear_arcane()
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
	arcane_caster._clear_arcane()  # (so do Countdown marks; the Mirror Sigil and the Afterimage go)
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
	_bus().cast_finished.connect(holy_talents._zeal_on_cast)   # Zeal (an open Holy talent)
	_bus().ability_used.connect(_cold_precision_on_use)
	_bus().damage_dealt.connect(_on_damage_dealt_frost)
	_bus().damage_dealt.connect(_on_damage_dealt_fire)
	_bus().damage_dealt.connect(bottled_kit._on_damage_dealt_lightning)
	_bus().damage_dealt.connect(arcane_caster._on_damage_dealt_arcane)
	_bus().damage_dealt.connect(decay._on_damage_dealt_shadow)
	_bus().enemy_died.connect(shadow_talents._on_enemy_died_shadow)   # Carrion
	_bus().heal_done.connect(strings._on_heal_done_strings)    # the Strings share my heals
	_bus().heal_done.connect(hymns._on_heal_done_hymns)      # the Hymns: Chorus, Vigil, Mercy's Ear
	_bus().damage_dealt.connect(hymns._on_damage_dealt_holy)  # High Note's heal
	_bus().cast_finished.connect(_pact_on_ability)     # Pact of the Purist: an ability of mine went off
	_bus().dungeon_cleared.connect(func(_summary): _pact_cleared = true)   # Pact of the Restless: nothing left to fight
	_bus().cast_finished.connect(arcane_caster._on_cast_for_arcane)
	_bus().cast_finished.connect(fire_lightning_talents._change_of_pace)
	_bus().cast_started.connect(overload_kit._on_cast_for_static)
	_bus().cast_finished.connect(overload_kit._on_cast_for_static)
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
	var shown := displayed_target()   # (not a mouseover cast's)
	if shown == null or not shown.is_alive():
		target_ring.visible = false
		return
	var r := Combat.hitbox_radius(shown)
	var p := shown.global_position
	target_ring.global_position = Vector3(p.x, Combat.feet_y(shown) + 0.05, p.z)
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
			elif gcd_left > 0.0 and on_gcd(placing_id):
				pass   # still on the global cooldown: keep aiming, click again
			elif (placing_id == PrismsKit.SET_PRISM_ID or placing_id == PrismsKit.REALIGN_ID or placing_id == LightstringKit.PRISM_ARROW_ID) and prism_kit._prism_place_error(placing_id, cast_point) != "":
				_error(prism_kit._prism_place_error(placing_id, cast_point))   # (out of range: keep aiming)
			elif placing_id == CINDER_RAIN_ID and _cinder_rain_error(cast_point) != "":
				_error(_cinder_rain_error(cast_point))   # out of range: keep aiming
			elif placing_id == ArcaneTankKit.DECOY_ID and arcane_tank._decoy_error(cast_point) != "":
				_error(arcane_tank._decoy_error(cast_point))         # (the same for Decoy)
			elif (placing_id == WeaverKit.MOSSBACK_ID or placing_id == WeaverKit.VIPERS_ID) and weaver._finisher_place_error(placing_id, cast_point) != "":
				_error(weaver._finisher_place_error(placing_id, cast_point))   # (Nature finishers: keep aiming)
			else:
				cancel_placement()
				if placing_id == CRUCIBLE_ID:
					_start_crucible(cast_point)
				elif placing_id == ArcaneTankKit.DECOY_ID:
					arcane_tank._start_decoy(cast_point)
				elif placing_id == PrismsKit.SET_PRISM_ID or placing_id == PrismsKit.REALIGN_ID or placing_id == LightstringKit.PRISM_ARROW_ID:
					prism_kit._start_prism_place(placing_id, cast_point)
				elif placing_id == CINDER_RAIN_ID:
					_start_cinder_rain(cast_point)
				elif placing_id == LightningCasterKit.THUNDERHEAD_ID:
					bottled_kit._start_thunderhead(cast_point)
				elif placing_id == ArcaneCasterKit.COLLAPSE_ID:
					arcane_caster._start_collapse(cast_point)
				elif placing_id == DecayKit.PALL_ID:
					decay._start_pall(cast_point)
				elif placing_id == WeaverKit.MOSSBACK_ID or placing_id == WeaverKit.VIPERS_ID:
					weaver._start_finisher(placing_id, cast_point)
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
	_mouseover_begin(id)   # Mouseover casting: a legal target under the mouse goes first
	_auto_target(id)   # no target: the closest enemy this could be used on
	_acting = true
	_acted = false
	_use_ability_now(id)
	_acting = false
	_mouseover_end()
	_use_result = _acted
	# An instant ability went off (casts start the GCD in _begin_spell).
	if _acted and on_gcd(id) and gcd_left <= 0.0:
		_start_gcd()
		if id == StringsKit.STRING_ID:   # String: a short global cooldown, so several can be tied quickly
			gcd_total = StringsKit.string_gcd(gcd_total)
			gcd_left = gcd_total

## Enemy-targeted bolt spells with a cast time (same flow as Frost Bolt).
const ENEMY_BOLTS := ["frostbolt", "fireball", "lightningbolt", "immolate",
	"kilnblast", "slowfuse", "rekindle", "frostfirebolt", "coldspike", "chainlightning", "discharge",
	"livewire", "forkedbolt", "unravel", "countdown", "convergence",
	"blight", "erode", "highnote", "piercinglight", "thornshot", "briartiger"]

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
const SUPPORT_CASTS := ["rimeshell", "flashfreeze", "hoist", "patchup", "psalm", "outpour", "canticle", "exultation", "brightlance", "dewfall", "fawn"]
## Instant abilities every character has (handled like drafted ones).
const BASE_INSTANTS := ["stoneguard", "taunt"]

func _use_ability_now(id: String) -> void:
	if id == DecayKit.BLIGHT_ID and (_has_rune(DecayKit.OPEN_WOUND_RUNE) or decay.interest_ready()):
		cancel_placement()
		decay._blight_now()   # Rune of the Open Wound: instant, on a cooldown. Interest's capstone: instant, once
		return
	if id in ENEMY_BOLTS:
		cancel_placement()
		_start_bolt(id)
		return
	if id in SUPPORT_CASTS:
		cancel_placement()
		_start_support_cast(id)
		return
	if id == WeaverKit.MOSSBACK_ID or id == WeaverKit.VIPERS_ID:
		weaver._use_finisher(id)   # Nature caster: the enemy under the mouse, else a circle on the mulch to use
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
			lightning_caster._start_ball_lightning()
		"groundingsurge":
			lightning_caster._grounding_surge()   # (instant and off the global cooldown: it interrupts nothing)
		"capacitor":
			bottled_kit._capacitor()         # (the same)
		"arcanemissiles":
			cancel_placement()
			arcane_caster._start_sigil_darts()
		"mirrorsigil":
			cancel_placement()
			arcane_caster._start_mirror_sigil()
		"rewind":
			arcane_caster._rewind()            # (instant and off the global cooldown: these three interrupt nothing)
		"lapse":
			arcane_caster._lapse()
		"scatter":
			arcane_caster._scatter()
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
				var decoy_err := arcane_tank._decoy_error()
				if decoy_err != "":
					_error(decoy_err)
				else:
					_begin_placement(id)
		"setprism", "realign", "prismarrow":
			# Holy healer #2: ground-targeted and instant, like Decoy.
			if placing and placing_id == id:
				cancel_placement()
			else:
				cancel_placement()
				var prism_err := prism_kit._prism_place_error(id)
				if prism_err != "":
					_error(prism_err)
				else:
					_begin_placement(id)
		"refractingshot":
			cancel_placement()
			lightstring._start_refracting_shot()
		"adderarrow":
			cancel_placement()
			venomstring._start_adder_arrow()   # Nature archer (a bow cast; instant after Fang Arrow)
		"mendingray":
			cancel_placement()
			prism_kit._start_mending_ray()
		"trinket_1", "trinket_2":
			_use_trinket(id)
		_:
			if Abilities.DRAFT_POOL.has(id) or BASE_INSTANTS.has(id) or LightningMeleeKit.RUNE_INSTANTS.has(id):
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
		arcane_tank._sync_reflections()
		censer._sync_censer()
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
	amount *= holy_talents._holy_heal_mult(ability_id)   # Radiance
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
	if VenomstringKit.POISON_ARROWS.has(ability_id):
		venomstring._poison_landed(enemy, ability_id, base)   # Nature archer: the arrow carries a poison, not a hit
		return 0
	if ability_id == FROSTFIRE and damage_type == "":
		return _frostfire_hit(enemy, base, is_proc)
	if ability_id == LightstringKit.REFRACTION_ID or ability_id == LightstringKit.VOLLEY_ARROW_ID:
		# Holy archer: arrows from a gold prism (not abilities of their own) are Holy procs.
		damage_type = "holy"
		tags = PackedStringArray(LightstringKit.LIGHTSTRING_TAGS)
		is_proc = true
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
		VenomstringKit.FANG_ARROW_ID:
			venomstring._fang_landed(enemy)   # Nature archer: my poisons on it last longer
		WeaverKit.THORNSHOT_ID:
			weaver._thornshot_landed(enemy, at)   # Nature caster: Thornburst, and every few a patch of mulch
		"chainlightning":
			# Leaping Arc: it leaps to the nearest other enemies. A leap with no new
			# enemy to reach comes back to the target instead, weaker.
			var others := _enemies_near(at, float(Abilities.get_resource(id).radius), enemy)
			var leaps := mini(others.size(), Balance.LEAPING_ARC_JUMPS)
			var jump := float(Abilities.EXTRA_HITS[id])
			for i in leaps:
				FROST_BOLT.spawn(get_tree().current_scene, at + Vector3(0, 0.3, 0), others[i], self, true, id, jump)
			for i in LightningCasterKit.arc_returns(others.size()):
				deal_damage(enemy, LightningCasterKit.arc_return_coef(jump), id, true)
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
				_apply_effect_hit(enemy, preload("res://scripts/core/effects.gd").get_effect(LightningCasterKit.ROD_FX), LightningCasterKit.ROD_FX,
					PackedStringArray(["Lightning"]), "lightning")
			var r := float(Abilities.get_resource(id).radius)
			for e in _enemies_near(at, r, enemy):
				deal_damage(e, float(Abilities.EXTRA_HITS[id]), id, true)
			_ring_effect(r, Abilities.color_of(id), at)
		"shattershot":
			_shatter_shot_landed(enemy, at)   # on a target I had Frozen: it thaws and the ice bursts
		"shadowstrike":
			# Share the Kill: Leeching Strike heals for more while my Hounds are out.
			heal(float(Abilities.HEALS[id]) * HoundsKit.leech_heal_mult(hounds.hounds_out(), _talent("shadow_share_the_kill")), id)

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
	if ((id == ArcaneTankKit.DECOY_ID and arcane_tank.decoy_needs_reflection()) or id == ArcaneTankKit.TRADE_PLACES_ID) and arcane_tank.reflections() <= 0:
		if report:
			_error("You have no Reflections")
		return false
	# Encore replays Traces.
	if id == ArcaneMeleeKit.ENCORE_ID and arcane_melee.traces() <= 0:
		if report:
			_error("You have no Traces")
		return false
	if id == ArcaneTankKit.MISSED_BEAT_ID and (status == null or not status.has(ArcaneTankKit.MISSED_BEAT_FX)):
		if report:
			_error("None of your Reflections has shattered")
		return false
	# String ties one from my hand; Not Finished With You takes several.
	if id == StringsKit.STRING_ID and strings.string_charges() < 1:
		if report:
			_error("No Strings left in your hand")
		return false
	if id == StringsKit.NOT_FINISHED_ID and strings.string_charges() < Balance.NOT_FINISHED_STRINGS:
		if report:
			_error("Requires %d Strings in your hand" % Balance.NOT_FINISHED_STRINGS)
		return false
	# Discharge and Ground Out spend ALL my Energy: they need some to spend.
	if Abilities.SPENDS_ALL.has(id) and float(resources["energy"]) + 0.0001 < Balance.SPEND_ALL_MIN_ENERGY:
		if report:
			_error("Not enough energy")
		return false
	# Overdrive only starts with little Energy (it would end at once with more).
	if id == LightningMeleeKit.OVERDRIVE_ID and not LightningMeleeKit.overdrive_holds(float(resources["energy"]), resource_max("energy")):
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
	if id == LightningTankKit.RETURN_STROKE_ID:   # Rune of Resonance: dearer without a parry behind it
		cost = LightningTankKit.return_stroke_cost(cost, status != null and status.has(LightningTankKit.RETURN_STROKE_FX), _has_rune(LightningTankKit.RESONANCE_RUNE))
	if id == LightningMeleeKit.STATIC_STEP_ID and status != null and status.has(BottledLightningKit.WHIP_CRACK_FX):
		cost = BottledLightningKit.whip_crack_cost(cost, _talent("lightning_whip_crack"))    # Whip Crack
	if id == LightningCasterKit.STORM_ARROW_ID and status != null:                         # Loaded Quiver, Snap Shot
		cost = StormArrowKit.storm_arrow_cost(cost, status.has(LightningCasterKit.LOADED_QUIVER_FX),
			_talent("lightning_snap_shot") if status.has(LightningCasterKit.SNAP_SHOT_FX) else 0.0)
	if cost > 0.0 and Abilities.resource_of(id) == "energy":
		cost = LightningCasterKit.surge_energy_cost(cost, lightning_caster.surge_active())                   # Grounding Surge
		if with_storm_cycle and bottled_kit.storm_cycle_ready():
			cost = 0.0                                                   # Storm Cycle: this one is free
	if cost <= 0.0 or Abilities.resource_of(id) != "mana":
		return cost * _pact_cost_mult(Abilities.resource_of(id))   # (my Pact: Sidestep)
	cost *= mana_unit() * _pact_cost_mult("mana")                  # (my Pact: Sidestep, Reservoir)
	var tags := Abilities.tags_of(id)
	if tags.has("Spell"):
		var pd := get_node_or_null("/root/PlayerData")
		if pd:
			cost *= 1.0 - float(pd.talent_value("frost_discipline")) / 100.0   # Cold Discipline
	if HolyTalentsKit.is_holy_heal(id):
		cost *= 1.0 - _talent("holy_clear_mind") / 100.0   # Clear Mind (both Holy healers)
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
		var free_cycle: bool = res == "energy" and bottled_kit.storm_cycle_ready() and resource_cost(id, false) > 0.0
		var cost := resource_cost(id)
		resources[res] = float(resources[res]) - cost
		if free_cycle:
			status.remove(BottledLightningKit.STORM_CYCLE_FX)
		if res == "energy" and cost > 0.0:
			lightning_melee._redline()   # Redline: Energy spent during Overdrive makes it last longer
			bottled_kit._storm_cycle_spent(cost)   # Storm Cycle counts what I spend
		if HoundsKit.rouses(res, cost):
			hounds._rouse_hounds()   # Shadow melee: spending Rage Rouses my Hounds
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
	_gain("energy", LightningMeleeKit.energy_regen(ENERGY_REGEN, _talent("lightning_quick_charge")) * delta)   # Quick Charge
	_gain("rage", -HoundsKit.rage_decay(RAGE_DECAY, _talent("shadow_thick_blood")) * delta)   # Thick Blood

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
	if status != null and status.has(LightningMeleeKit.SPLIT_SECOND_FX):   # Split Second: every GCD is shorter
		gcd_total = LightningMeleeKit.split_second_gcd(gcd_total)
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
	if id == LightningCasterKit.STORM_ARROW_ID and storm_arrow_kit.quiver_loaded():
		left = 0.0   # Loaded Quiver: its arrows ignore the cooldown
	if id == DecayKit.BLIGHT_ID and decay.interest_ready():
		left = 0.0   # Interest: the instant Blight ignores the rune's cooldown
	return maxf(left, gcd_left if on_gcd(id) else 0.0)

## Full cooldown of an action-bar button (for the cooldown sweep).
func cooldown_total(id: String) -> float:
	if Abilities.is_trinket_slot(id):
		var use := Items.use_effect_of(_trinket_item(id))
		return float(use.internal_cooldown) if use else 1.0
	var own := 0.0 if (id == LightningCasterKit.STORM_ARROW_ID and storm_arrow_kit.quiver_loaded()) else float(cooldowns.get(id, 0.0))   # (Loaded Quiver)
	if on_gcd(id) and gcd_left > own:
		return gcd_total   # the sweep is the global cooldown right now
	if id == DecayKit.BLIGHT_ID and own > 0.0 and not decay.interest_ready():
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
	var arcane_rate := arcane_caster._arcane_rate()   # Lapse, Interval Ward: my Arcane spells recover faster
	var clock := _talent("arcane_running_clock") if not cooldowns.is_empty() else 0.0   # Running Clock: so does everything Arcane
	var plain := arcane_rate == 1.0 and clock <= 0.0
	var pact_rate := PACTS.cooldown_rate(pact_id(), pact_broken())   # Pact of the Sidestep: every cooldown
	for id in cooldowns.keys():
		var step := delta if plain else delta * ArcaneCasterKit.arcane_cooldown_rate(arcane_rate, arcane_caster._is_arcane_spell(str(id)),
			arcane_caster._in_arcane_book(str(id)), clock)
		cooldowns[id] = float(cooldowns[id]) - step * pact_rate
		if cooldowns[id] <= 0.0:
			cooldowns.erase(id)
	arcane_open._tick_borrowed_time()   # Borrowed Time: a long cooldown just came back?
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
	return arcane_caster._slow_mult_now   # (1 unless Aftershock is being applied: its rank sets the strength)

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
		arcane_tank._reflection_talents_incoming(info)   # Empty Room, Bent Light
		lightning_melee._guard_incoming(info)   # Reflex Arc, Faraday Guard
		strings._crossed_incoming(info) # Crossed Strings: part of it goes to an enemy
		_pact_incoming(info)    # my Pact: more or less damage taken
		return
	if info.source != self:
		return
	_pact_outgoing(info)        # my Pact: more or less damage dealt
	holy_talents._holy_talents_outgoing(info)   # Burnished, Censer's Weight, Sunsteel
	# Scatter: the darts of the Sigil Darts it split hit harder.
	if arcane_caster._bolt_tag == ArcaneCasterKit.SCATTER_FX and str(info.ability_id) == ArcaneCasterKit.SIGIL_DARTS_ID:
		info.add_bonus(Balance.SCATTER_PCT, ArcaneCasterKit.SCATTER_LABEL)
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
	arcane_open._borrowed_time_hit(info, id)   # Borrowed Time: the next spell or ability after a long cooldown comes back
	fire_lightning_talents._open_talents_modify(info)   # Feed the Flames, Change of Pace, Dig In
	shadow_talents._shadow_talents_modify(info, id)   # Slow Death, Finish It, Inevitable, Spite
	lightning_melee._empower_weapon_ability(info, id)   # Static Step, Polar Strike's charge
	# Running on Empty: with little Energy left, my Lightning spells and abilities hit harder.
	var empty := _talent("lightning_running_on_empty")
	if empty > 0.0 and LightningMeleeKit.running_on_empty(str(info.damage_type), info.tags, float(resources["energy"])):
		info.add_bonus(empty, "Running on Empty")
	# Standing Charge: planted in Grounding Surge, my Lightning damage keeps growing.
	if str(info.damage_type) == "lightning":
		var standing := bottled_kit.standing_charge_bonus()
		if standing > 0.0:
			info.add_bonus(standing, "Standing Charge")
	# High Voltage: with a nearly full bar, all my Lightning damage is higher.
	var high := _talent("lightning_high_voltage")
	if high > 0.0 and LightningCasterKit.high_voltage(str(info.damage_type), float(resources["energy"])):
		info.add_bonus(high, "High Voltage")
	# Counter-Charge: Return Stroke's own hit (not the arcs of its capstone) hits harder.
	if id == LightningTankKit.RETURN_STROKE_ID and not info.is_proc:
		var counter := _talent("lightning_counter_charge")
		if counter > 0.0:
			info.add_bonus(counter, LightningTankKit.COUNTER_CHARGE_LABEL)
	# Practiced Hand: Swift Cut hits harder for each Trace I hold.
	if id == ArcaneMeleeKit.SWIFT_CUT_ID and not info.is_proc:
		var practiced := ArcaneMeleeKit.practiced_hand_pct(_talent("arcane_practiced_hand"), arcane_melee.traces())
		if practiced > 0.0:
			info.add_bonus(practiced, "Practiced Hand")
	# Fine Edge: with a weapon in each hand, my Arcane abilities hit harder.
	if info.tags.has("Arcane") and info.tags.has("Ability"):
		var edge := _talent("arcane_fine_edge")
		if edge > 0.0 and arcane_tank.has_dual_wield():
			info.add_bonus(edge, "Fine Edge")
	# Sharp Edges: my Reflections hit harder when they shatter.
	if id == ArcaneTankKit.REFLECTION_SHATTER_ID:
		var sharp := _talent("arcane_sharp_edges")
		if sharp > 0.0:
			info.add_bonus(sharp, ArcaneTankKit.SHARP_EDGES_LABEL)
	# On the Beat: Missed Beat hits harder.
	if id == ArcaneTankKit.MISSED_BEAT_ID and not info.is_proc:
		var on_beat := _talent("arcane_on_the_beat")
		if on_beat > 0.0:
			info.add_bonus(on_beat, ArcaneTankKit.ON_THE_BEAT_LABEL)
	# Third Beat: Cadence's third strike hits harder.
	if id == LightningMeleeKit.CADENCE_ID and lightning_melee._cadence_third:
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
	if auto_windup < LightningMeleeKit.auto_interval(float(w["attack_interval"]), haste_mult(), lightning_melee.overdrive_active(), lightning_tank.attack_speed_bonus()):   # (Overdrive, Tempo: faster swings)
		return
	auto_windup = 0.0
	# Snap to face the enemy we're hitting.
	var dir := enemy.global_position - global_position
	rotation.y = atan2(-dir.x, -dir.z)
	if w["weapon"] == "ranged":
		var shot := float(w["damage"]) * Balance.AUTO_ATTACK_MULT
		shot *= lightstring._auto_shot_line(enemy, shot)   # Holy archer: through my gold prisms
		ARROW.spawn(get_tree().current_scene, _muzzle(),
			enemy, self, shot, "auto_ranged")
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
	# My prisms (Holy healer #2): a click makes one my prism target.
	if prism_kit._click_prism(screen_pos, cam):
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
	elif spell == LightstringKit.REFRACTING_SHOT_ID:
		duration = maxf(duration - _talent("holy_steady_aim"), 0.2)   # Steady Aim
	elif spell == PrismsKit.BRIGHT_LANCE_ID:
		duration = maxf(duration - _talent("holy_quick_lance"), 0.2)   # Quick Lance
	elif spell == GLACIAL_DRAW_ID:
		duration = thin_ice_cast(duration, _talent("frost_thin_ice"), _chilled_by_me(target))   # Thin Ice
	elif spell == StringsKit.HOIST_ID:
		duration = StringsKit.heave_cast(duration, strings.strings_on(_cast_target), _capstone("shadow_heave"))   # Heave's capstone
	elif spell == DecayKit.ERODE_ID:
		duration = StringsKit.deep_call_cast(duration, _talent("shadow_deep_call"), decay.decay_open_on(target))   # Deep Call
	duration /= haste_mult()
	if Abilities.is_a(spell, "frostbolt") and frozen_instinct_ready():
		duration = 0.05   # Frozen Instinct: instant (released next frame)
		_instinct_cast = true
	_conc_cast = not _instinct_cast and concentrated_fire_ready(spell)
	if _conc_cast:
		duration = 0.05   # Concentrated Fire: instant (released next frame)
	storm_arrow_kit._flicker_cast = not _instinct_cast and not _conc_cast and bottled_kit.flicker_ready(spell)
	if storm_arrow_kit._flicker_cast:
		duration = 0.05   # Flicker: this Lightning Bolt is instant (released next frame)
	bottled_kit._bottled_cast = not _instinct_cast and not _conc_cast and not storm_arrow_kit._flicker_cast and bottled_kit.bottled_ready(spell)
	if bottled_kit._bottled_cast:
		duration = 0.05   # Rune of Bottled Lightning: this Discharge is instant (released next frame)
	storm_arrow_kit._overture_cast = not channel and not _instinct_cast and not _conc_cast and not storm_arrow_kit._flicker_cast and not bottled_kit._bottled_cast and hymns.overture_ready(spell)
	if storm_arrow_kit._overture_cast:
		duration = 0.05   # Rune of the Overture: the first cast after a boom is instant (used up when it lands)
	# Cinder Step: this cast can be finished on the move (instant ones don't need it).
	_cinder_cast = not channel and not _conc_cast and not _instinct_cast and cinder_step_ready(spell)
	# Glint: this cast or channel can go on while I move (instant ones don't need it).
	arcane_caster._glint_cast = not _conc_cast and not _instinct_cast and not storm_arrow_kit._flicker_cast and not bottled_kit._bottled_cast \
		and not _cinder_cast and not storm_arrow_kit._overture_cast and arcane_caster.glint_ready(spell)
	if arcane_caster._glint_cast and channel and status:
		status.spend_stacks(ArcaneCasterKit.GLINT_FX, 1)   # a channel is paid for when it starts, and uses Glint up then too (Keep Moving: one of its casts)
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
	storm_arrow_kit._flicker_cast = false    # and Flicker's instant Lightning Bolt
	storm_arrow_kit._overture_cast = false   # and the Overture's instant cast
	bottled_kit._bottled_cast = false    # and Bottled Lightning's instant Discharge
	arcane_caster._glint_cast = false      # and Glint's cast on the move
	_volley_left = 0         # a broken Ember Volley launches no more embers
	arcane_caster._darts_left = 0          # nor does a broken Sigil Darts launch more darts
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
	var glint := arcane_caster._glint_cast
	arcane_caster._glint_cast = false
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
	if spell == PrismsKit.MENDING_RAY_ID:
		prism_kit._mending_ray_tick(true)   # the last ticks (the channel was paid for when it started)
		_bus().cast_finished.emit(spell)
		return
	if spell == ArcaneCasterKit.SIGIL_DARTS_ID:
		arcane_caster._sigil_darts_tick(true)    # the last dart (the same)
		_bus().cast_finished.emit(spell)
		return
	_bus().cast_finished.emit(spell)
	# Casts pay their cost when they complete (a cancelled cast costs nothing).
	var conc := _conc_cast
	_conc_cast = false
	var flick := storm_arrow_kit._flicker_cast
	storm_arrow_kit._flicker_cast = false
	var overture := storm_arrow_kit._overture_cast
	storm_arrow_kit._overture_cast = false
	var bottled := bottled_kit._bottled_cast
	bottled_kit._bottled_cast = false
	if not _pay(spell):
		_instinct_cast = false
		return
	if flick and status:
		status.remove(LightningCasterKit.FLICKER_FX)      # Flicker: that was its instant Lightning Bolt
	if overture and status:
		status.remove(HymnsKit.OVERTURE_FX)     # Rune of the Overture: that was its instant cast
	if bottled and status:
		status.remove(BottledLightningKit.BOTTLED_FX)      # Rune of Bottled Lightning: that was its instant Discharge
	if conc and status:
		status.spend_stacks(CONC_ID)   # Concentrated Fire: one stack per instant cast
	if cinder and status:
		status.remove(CINDER_ID)       # Cinder Step: that was the cast on the move
	if glint and status:
		status.spend_stacks(ArcaneCasterKit.GLINT_FX, 1)   # Glint: so was this (Keep Moving: one of its casts)
	if Abilities.is_a(spell, "frostbolt") and (_instinct_cast or frozen_instinct_ready()):
		status.remove(INSTINCT_ID)   # Frozen Instinct used up (this bolt was free)
	_instinct_cast = false
	if spell == "steadyshot":
		_release_steady_shot()
		return
	if spell == LightstringKit.REFRACTING_SHOT_ID:
		lightstring._loose_refracting_shot()   # Holy archer
		return
	if spell == VenomstringKit.ADDER_ARROW_ID:
		venomstring._loose_adder_arrow()   # Nature archer
		return
	if spell == GLACIAL_DRAW_ID:
		_loose_glacial_draw()
		return
	if spell == "walloffire":
		_raise_fire_wall()
		return
	if spell == LightningCasterKit.BALL_LIGHTNING_ID:
		lightning_caster._launch_ball_lightning()
		return
	if spell == LightningCasterKit.THUNDERHEAD_ID:
		bottled_kit._raise_thunderhead()
		return
	if spell == ArcaneCasterKit.MIRROR_ID:
		arcane_caster._place_mirror_sigil()
		return
	if spell == ArcaneCasterKit.COLLAPSE_ID:
		arcane_caster._cast_collapse()
		return
	if spell == DecayKit.PALL_ID:
		decay._cast_pall()
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
	if spell == LightningCasterKit.DISCHARGE_ID:
		lightning_caster._discharge(target)
		return
	if spell == LightningCasterKit.FORKED_BOLT_ID:
		bottled_kit._forked_bolt(target)
		return
	if spell == "slowfuse":
		_plant_fuse(target)
		return
	if spell == "rekindle":
		_rekindle(target)
		return
	if spell == ArcaneCasterKit.COUNTDOWN_ID:
		arcane_caster._plant_countdown(target)
		return
	if spell == ArcaneCasterKit.UNRAVEL_ID:
		arcane_caster._unravel_cooldowns()   # (then its bolt, like any other)
	if spell == ArcaneCasterKit.CONVERGENCE_ID:
		# Stronger for each other Arcane spell on cooldown right now.
		FROST_BOLT.spawn(get_tree().current_scene, _muzzle(), target, self, false, spell,
			ArcaneCasterKit.convergence_coef(float(bolt_res.damage), arcane_caster.arcane_cooldowns(ArcaneCasterKit.CONVERGENCE_ID)))
		return
	if spell == "immolate":
		_immolate_spread(target)   # recast on a target that already has mine: it jumps to others
	if spell == PrismsKit.PIERCING_LIGHT_ID:
		prism_kit._piercing_light(target)   # Holy healer #2: a beam, not a bolt
		return
	if spell == WeaverKit.BRIAR_TIGER_ID:
		weaver._briar_tiger(target)   # Nature caster: the tiger strikes when its picture does
		return
	if spell == HymnsKit.HIGH_NOTE_ID:
		hymns._gain_verses(spell)   # Holy healer: its Verse (its heal comes when it lands: _on_damage_dealt_holy)
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
	elif id == PrismsKit.SET_PRISM_ID or id == PrismsKit.REALIGN_ID or id == LightstringKit.PRISM_ARROW_ID:
		r = 1.0   # (where the prism / the middle of the group lands)
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
	arcane_caster._tick_countdowns()
	decay._tick_decay()
	overload_kit._tick_grounded()
	_tick_dusk()
	hounds._tick_hounds()
	strings._tick_strings()
	hymns._tick_hymns()
	_tick_pact(_delta)
	bottled_kit._tick_live_wire()
	lightning_melee._tick_overdrive()
	bottled_kit._tick_standing_charge(_delta)
	arcane_tank._tick_reflections()
	censer._tick_censer()
	prism_kit._tick_prisms()
	weaver._tick_weaver()
	shepherd._tick_shepherd()
	colossus._tick_colossus()
	venomstring._tick_venom(_delta)
	lightstring._tick_lightstring(_delta)
	_mouseover_tick()
	arcane_melee._tick_traces()
	fire_lightning_talents._tick_dig_in(_delta)
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
	var steady := casting and (current_spell == "steadyshot" or _conc_cast or _cinder_cast or storm_arrow_kit._flicker_cast or bottled_kit._bottled_cast
		or arcane_caster._glint_cast or storm_arrow_kit._overture_cast)
	if steady:
		var aimed: bool = current_spell == "steadyshot" or current_spell in ENEMY_BOLTS or current_spell == "embervolley" \
			or current_spell == GLACIAL_DRAW_ID or current_spell == ArcaneCasterKit.SIGIL_DARTS_ID or current_spell == LightstringKit.REFRACTING_SHOT_ID \
			or current_spell == VenomstringKit.ADDER_ARROW_ID
		if (aimed and not _has_valid_target()) or (current_spell in SUPPORT_CASTS and not _support_target_ok()):
			_cancel_cast()
			steady = false
		else:
			cast_timer -= delta
			if current_spell == "embervolley":
				_ember_volley_tick()     # a channel on the move launches as it goes, like one standing still
			elif current_spell == ArcaneCasterKit.SIGIL_DARTS_ID:
				arcane_caster._sigil_darts_tick()
			elif current_spell == PrismsKit.MENDING_RAY_ID:
				prism_kit._mending_ray_tick()
			if not casting:
				steady = false
			elif cast_timer <= 0.0:
				_release_cast()
				steady = false

	if casting and not steady:
		var targeted: bool = current_spell in ENEMY_BOLTS or current_spell == "embervolley" or current_spell == GLACIAL_DRAW_ID \
			or current_spell == LightstringKit.REFRACTING_SHOT_ID or current_spell == VenomstringKit.ADDER_ARROW_ID \
			or current_spell == ArcaneCasterKit.SIGIL_DARTS_ID
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
			elif current_spell == ArcaneCasterKit.SIGIL_DARTS_ID:
				arcane_caster._sigil_darts_tick()
			elif current_spell == PrismsKit.MENDING_RAY_ID:
				prism_kit._mending_ray_tick()
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
	if bool(res.get("requires_off_hand")) and not has_off_hand_item():
		_error("Requires an off hand")
		return
	if bool(res.get("requires_two_hand")) and not lightning_tank.has_two_hander():
		_error("Requires a two-handed weapon")
		return
	if bool(res.get("requires_dual_wield")) and not arcane_tank.has_dual_wield():
		_error(ArcaneTankKit.DUAL_WIELD_ERROR)
		return
	if res.requires_target:
		if not _has_valid_target():
			_error("No target")
			return
		var sight_err := _target_error(target)
		if sight_err != "" and id != WeaverKit.THORNWING_ID:   # (Thornwing dives from above: no line of sight needed)
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
	hounds._hounds_on_ability(id)   # Shadow melee: with no Hounds out, its abilities call them
	var cd_before := float(cooldowns.get(id, 0.0))
	cooldowns[id] = Abilities.cooldown_of(res)   # (with talents: Thick Hide)
	if id == LightningCasterKit.STORM_ARROW_ID:
		storm_arrow_kit._storm_arrow_fired(cd_before)   # Loaded Quiver, Snap Shot
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
		StringsKit.STRING_ID, StringsKit.TUG_ID, StringsKit.CRADLE_ID, StringsKit.WRENCH_ID, StringsKit.PULL_TAUT_ID, StringsKit.CUPPED_HANDS_ID, StringsKit.STRING_UP_ID, StringsKit.RESTRING_ID, StringsKit.KNOT_ID, StringsKit.TANGLE_ID, \
				StringsKit.YANK_ID, StringsKit.DOUBLE_THREAD_ID, StringsKit.BEHIND_ID, StringsKit.SLACK_ID, StringsKit.STILL_STANDING_ID, StringsKit.CUT_STRINGS_ID, StringsKit.NOT_FINISHED_ID:
			strings._string_use(id, res)   # Shadow healer: the Strings
		"lift", "refrain", "antiphon", "shelter", "steadyvoice", "reprise", "swell", "rest", "lastverse", "singmercy", "singchorus", "singvigil":
			hymns._hymn_use(id, res)   # Holy healer: the Hymns
		CenserKit.CENSER_SWING_ID, CenserKit.HALLOWED_ARC_ID, CenserKit.BECKON_ID, CenserKit.POUR_OUT_ID, CenserKit.ABSOLVE_ID, CenserKit.AUREOLE_ID, CenserKit.GATHER_ID, CenserKit.RAISE_CENSER_ID, CenserKit.UNFALLEN_ID:
			censer._censer_use(id, res)   # Holy tank: the Censer
		PrismsKit.MOVE_PRISM_ID, PrismsKit.GLEAM_ID, PrismsKit.PRISM_WARD_ID, PrismsKit.SHATTER_PRISM_ID, PrismsKit.SHATTER_ALL_ID, PrismsKit.INFUSE_ID, PrismsKit.KALEIDOSCOPE_ID:
			prism_kit._prism_use(id, res)   # Holy healer #2: the Prisms
		LightstringKit.GLIMMER_SHOT_ID, LightstringKit.SUNLIT_ARROW_ID, LightstringKit.PRISM_BREAKER_ID, LightstringKit.STEP_OF_LIGHT_ID, LightstringKit.SPECTRUM_VOLLEY_ID:
			lightstring._lightstring_use(id, res)   # Holy archer: Lightstring
		WeaverKit.MOSSBACK_ID, WeaverKit.THORNWING_ID, WeaverKit.VIPERS_ID, WeaverKit.STAG_ID:
			weaver._weaver_use(id, res)   # Nature caster: the Weaver
		ShepherdKit.ROOTGUARD_ID, ShepherdKit.OWL_ID, ShepherdKit.ELK_ID, ShepherdKit.WILD_HERD_ID:
			shepherd._shepherd_use(id, res)   # Nature healer: the Shepherd
		ColossusKit.VINE_FIST_ID, ColossusKit.GRASP_ID, ColossusKit.STOMP_ID, ColossusKit.GIANTS_HANDS_ID, ColossusKit.HEARTSAP_ID, ColossusKit.AWAKEN_ID:
			colossus._colossus_use(id, res)   # Nature tank: the Colossus
		VenomstringKit.FANG_ARROW_ID, VenomstringKit.ADDER_ARROW_ID, VenomstringKit.ASP_ARROW_ID, VenomstringKit.KRAIT_ARROW_ID, VenomstringKit.VENOM_BURST_ID, VenomstringKit.SPITTING_VOLLEY_ID, VenomstringKit.BLOAT_ARROW_ID, VenomstringKit.COIL_BACK_ID, VenomstringKit.VENOM_SURGE_ID:
			venomstring._venom_use(id, res, w)   # Nature archer: Venomstring
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
			arcane_caster._leave_afterimage(from)   # Rune of the Afterimage
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
			lightning_caster._ground_out()
		"corruption":
			FROST_BOLT.spawn(get_tree().current_scene, muzzle, target, self, false, id, float(res.damage))
		"intervalward":
			arcane_caster._interval_ward()
		"glint":
			arcane_caster._glint(res)
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
			bottled_kit._flicker()
		# --- Lightning melee ---
		"arccleave":
			lightning_melee._arc_cleave(w, res)
		"overdrive":
			lightning_melee._start_overdrive()
		"twincurrent":
			lightning_melee._start_twin_current()
		"staticstep":
			lightning_melee._static_step(w)
		"backcurrent":
			lightning_melee._start_back_current()
		"cadence":
			lightning_melee._cadence(w, res)
		"splitsecond":
			lightning_melee._start_split_second()
		"whiplash":
			lightning_melee._whiplash(w, res)
		"faradayguard":
			lightning_melee._start_faraday_guard()
		"reflexarc":
			lightning_melee._start_reflex_arc()
		"polarstrike":
			lightning_melee._polar_strike(w, res)
		"arcaneexplosion", "arcflash":
			# Every enemy in range is hit. Up to AOE_TARGET_CAP take full damage;
			# with more, what that many would take is split evenly between all.
			var hit := _enemies_within(float(res.radius))
			var share := Balance.aoe_share(hit.size())
			for e in hit:
				deal_damage(e, float(res.damage) * share, id)
			_ring_effect(float(res.radius), Abilities.color_of(id))
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
			lightning_tank._start_humming_blade()
		"returnstroke":
			# One answer per parry. Without a parry behind it (Rune of Resonance) it
			# cost more (resource_cost) and goes on a short cooldown.
			if status.has(LightningTankKit.RETURN_STROKE_FX):
				# Second Stroke: a chance the window stays open for one more answer.
				if randf() * 100.0 >= _talent("lightning_second_stroke"):
					status.remove(LightningTankKit.RETURN_STROKE_FX)
			else:
				cooldowns[id] = Balance.RESONANCE_COOLDOWN
			deal_damage(target, _weapon_hit(w, res), id)   # (Counter-Charge: _on_damage_modify, _on_hit_extra)
			for i in 2:
				_slash_effect(Abilities.color_of(id))
		"reelin":
			lightning_tank._reel_in()
		"recharge":
			lightning_tank._recharge()
		"shockring":
			lightning_tank._shock_ring(res)
		"crossguard":
			lightning_tank._start_crossguard()
		"drawthestorm":
			lightning_tank._draw_the_storm(res)
		# --- Arcane tank (a melee weapon in each hand; see "Arcane tank" below) ---
		"doubleup":
			deal_damage(target, arcane_tank._dual_weapon_hit(w, res), id)   # both weapons
			for i in 2:
				_slash_effect(Abilities.color_of(id))
			arcane_tank._gain_reflections(ArcaneTankKit.double_up_reflections(_talent("arcane_second_self"), randf() * 100.0))   # Second Self
		"ripple":
			arcane_tank._ripple(res)
		"fullset":
			arcane_tank._full_set()
		"missedbeat":
			# The answer to a Reflection shattering (the window is checked in _drafted_precheck).
			deal_damage(target, arcane_tank._dual_weapon_hit(w, res), id)   # both weapons
			for i in 2:
				_slash_effect(Abilities.color_of(id))
			_ring_effect(0.6, Color(0.95, 0.9, 1.0), target.global_position)
			# On the Beat's capstone: with none left, it makes one.
			if arcane_tank.reflections() <= 0 and _capstone("arcane_on_the_beat"):
				arcane_tank._gain_reflections(1)
		"standin":
			arcane_tank._start_stand_in()
		"tradeplaces":
			arcane_tank._trade_places()
		"crowdofone":
			arcane_tank._start_crowd_of_one()
		# --- Arcane melee (a melee weapon in each hand; see "Arcane melee" below) ---
		"swiftcut", "deepcut":
			deal_damage(target, arcane_tank._dual_weapon_hit(w, res), id)   # both weapons; the Trace: _trace_hit
			for i in (2 if id == ArcaneMeleeKit.DEEP_CUT_ID else 1):
				_slash_effect(Abilities.color_of(id))
		"latecut":
			arcane_melee._late_cut(w, res)
		"widecut":
			arcane_melee._wide_cut(w, res)
		"encore":
			arcane_melee._encore()
		"doubletime":
			arcane_melee._start_double_time()
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
			var hush_stops: bool = id == DecayKit.HUSH_ID and target.has_method("cast_progress") and float(target.cast_progress()) >= 0.0
			if id == "counterspell" or id == "rimelock" or id == LightningCasterKit.JOLT_ID or id == DecayKit.HUSH_ID:
				_ring_effect(0.9, Abilities.color_of(id), target.global_position)
			else:
				deal_damage(target, _weapon_hit(w, res), id)
				_slash_effect(Abilities.color_of(id))
			# Jolt gives Energy when there was a cast to stop (the cast bar is shown
			# on every machine, so this works for party members too).
			if id == LightningCasterKit.JOLT_ID and target.has_method("cast_progress") and float(target.cast_progress()) >= 0.0:
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
			if id == DecayKit.HUSH_ID:
				decay._hush(hush_foe, float(res.damage), hush_stops)   # its own hit, and what it adds to an open Decay
		# --- Shadow melee (see "Shadow melee: the Hounds" below) ---
		"sic", "openup":
			# (My Hounds go for what I strike: _hounds_on_hit. Open Up's mark is its on-hit effect.)
			deal_damage(target, _weapon_hit(w, res), id)
			for i in (2 if id == HoundsKit.OPEN_UP_ID else 1):
				_slash_effect(HoundsKit.HOUND_COLOR)
		"bothatonce":
			var both_foe: Node3D = target
			deal_damage(both_foe, _weapon_hit(w, res), id)
			for i in 2:
				_slash_effect(HoundsKit.HOUND_COLOR)
			hounds._hounds_lunge(both_foe)
			# Again: a chance that it is ready again at once.
			if HoundsKit.again_resets(randf() * 100.0, _talent("shadow_again")):
				cooldowns.erase(HoundsKit.BOTH_AT_ONCE_ID)
				_combat().float_text(self, "Again", HoundsKit.HOUND_COLOR.lightened(0.3), false)
		"runthemdown":
			hounds._run_them_down(w, res)
		"guarddogs":
			hounds._start_guard_dogs()
		"offthechain":
			hounds._start_off_the_chain()
		"bringitdown":
			hounds._bring_it_down()   # (that there are Hounds with something to drag down: _drafted_precheck)
		# --- Shadow caster (see "Shadow caster: Decay" below) ---
		"calldue":
			decay._call_due()   # (my Decay on the target is checked in _drafted_precheck)
		"gnaw":
			decay._gnaw(res)
		"spill":
			decay._spill()
		"takeitback":
			decay._take_it_back()
		"bottomless":
			decay._start_bottomless()
		# --- Frost: Rime Shell kit ---
		"shatteringwave":
			_shattering_wave(float(res.radius))
	arcane_open._slipstream(id)   # Slipstream: faster after a blink or dash
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
	if StringsKit.STRING_INSTANTS.has(id):
		return strings._string_precheck(id)   # Shadow healer
	if HymnsKit.HYMN_INSTANTS.has(id):
		return hymns._hymn_precheck(id)    # Holy healer
	if CenserKit.CENSER_IDS.has(id):
		return censer._censer_precheck(id)  # Holy tank
	if PrismsKit.PRISM_INSTANTS.has(id):
		return prism_kit._prism_precheck(id)   # Holy healer #2
	if LightstringKit.LIGHTSTRING_INSTANTS.has(id):
		return lightstring._lightstring_precheck(id)   # Holy archer
	if ShepherdKit.SHEPHERD_INSTANTS.has(id):
		return shepherd._shepherd_precheck(id)   # Nature healer
	if ColossusKit.COLOSSUS_IDS.has(id):
		return colossus._colossus_precheck(id)   # Nature tank
	if VenomstringKit.VENOM_INSTANTS.has(id) or id == VenomstringKit.ADDER_ARROW_ID:
		return venomstring._venom_precheck(id)   # Nature archer
	match id:
		"blink", "cinderstep", "flicker", "staticstep", "icyretreat":
			if lightning_caster.surge_active():
				return "You can't move during %s" % Abilities.ability_name(LightningCasterKit.SURGE_ID)
		"returnstroke":
			if not LightningTankKit.return_stroke_usable(status.has(LightningTankKit.RETURN_STROKE_FX), _has_rune(LightningTankKit.RESONANCE_RUNE)):
				return "You have not parried an attack"
		"recharge":
			if health >= max_health:
				return "Already at full health"
		"missedbeat":
			if not status.has(ArcaneTankKit.MISSED_BEAT_FX):
				return "None of your Reflections has shattered"
		"tradeplaces":
			return ArcaneTankKit.trade_places_error(arcane_tank.reflections(), arcane_tank.damage_taken_recently(Balance.TRADE_PLACES_WINDOW), health >= max_health)
		"encore":
			if arcane_melee.traces() <= 0:
				return "You have no Traces"
		"calldue", "takeitback":
			if decay.decay_on(target) <= 0.0:
				return DecayKit.DECAY_ERROR
		"bringitdown":
			return HoundsKit.bring_down_error(hounds.hounds_out(), hounds._prey_ok(hounds._hound_prey) or (_has_valid_target() and hounds._prey_ok(target)))
		"spill":
			return DecayKit.spill_error(decay.decay_on(target), decay._spill_targets(target).size() if _has_valid_target() else 0)
		"multishot":
			if _multishot_targets(float(w["attack_range"])).is_empty():
				return "No enemies in range"
		"secondwind":
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

## An off hand item (tome, wand, lantern...) in the Off Hand: not a weapon or shield.
func has_off_hand_item() -> bool:
	var pd := get_node_or_null("/root/PlayerData")
	return pd != null and Items.is_off_hand_item(str(pd.equipment.get("Off Hand", "")))

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
	if id == "flashfreeze" or id == "canticle" or id == "exultation":
		return [null, ""]   # (around me: whoever my friendly target is does not matter)
	# Everlasting Rime: Rime Shell can't go on enemies (it goes on your friendly target / you).
	if id == "rimeshell" and _has_valid_target() and not _has_rune("everlasting_rime"):
		if global_position.distance_to(target.global_position) > float(res.cast_range):
			return [null, "Target out of range"]
		var err := _target_error(target)
		if err != "":
			return [null, err]
		return [target, "enemy"]
	# Mouseover casting: the ally (or me) under the mouse, if it is a legal target.
	if _mo_ally != null and is_instance_valid(_mo_ally) and _mo_ally.is_alive():
		if is_same(_mo_ally, self):
			return [self, "self"]
		if global_position.distance_to(_mo_ally.global_position) <= float(res.cast_range) and can_see(_mo_ally) \
				and not (lock_id != "" and _mo_ally.has_method("has_lockout") and _mo_ally.has_lockout(lock_id)):
			return [_mo_ally, "ally"]
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
	if (id == "psalm" or id == "outpour") and not has_friendly_target() and health >= max_health:
		_error("Already at full health")
		return
	var pick := _pick_support_target(id)
	if pick[0] == null and str(pick[1]) != "":
		_error(str(pick[1]))
		return
	if id == StringsKit.HOIST_ID and not strings.on_my_string(pick[0]):   # Hoist: only someone on one of my Strings
		_error(StringsKit.NOT_ON_STRING)
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
			strings._string_cast_heal(spell, tgt, kind)   # Shadow healer
		"psalm", "outpour", "canticle", "exultation":
			hymns._hymn_cast_heal(spell, tgt, kind)   # Holy healer
		"brightlance":
			prism_kit._prism_cast_heal(spell, tgt, kind)   # Holy healer #2 (the Prisms)
		"dewfall", "fawn":
			shepherd._shepherd_cast_heal(spell, tgt, kind)   # Nature healer: the Shepherd

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
	var mult := PACTS.heal_taken_mult(id, _pact_now_broken, is_same(source, self)) if id != "" else 1.0
	# Penitent (an open Holy talent): my next heal on myself after a big hit is stronger (and that uses it up).
	if is_same(source, self) and status != null and status.has(HolyTalentsKit.PENITENT_FX):
		status.remove(HolyTalentsKit.PENITENT_FX)
		mult *= 1.0 + _talent("holy_penitent") / 100.0
	return mult

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
	overload_kit._static_on_hit(info, tags)
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
		if (id == DecayKit.CALL_DUE_ID or id == DecayKit.SPILL_ID or id == DecayKit.TAKE_IT_BACK_ID) and decay.decay_on(e) <= 0.0:
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
	if id == WeaverKit.MOSSBACK_ID or id == WeaverKit.VIPERS_ID:
		return str(weaver._mulch.size())   # Nature caster: my patches of mulch
	if id == LightstringKit.PRISM_ARROW_ID:
		return str(lightstring._prism_arrows)   # Holy archer: Prism Arrow's charges
	if id == "iceshards":
		return str(int(ice_shard_charges))
	if id == VENT_ID and _vent_max() > 1:
		return str(clampi(_vent_charges, 0, _vent_max()))
	if heat_needed(id) > 0:
		return str(heat_stacks())   # Quench / Flare: the Heat you hold
	if id == ArcaneTankKit.FULL_SET_ID or id == ArcaneTankKit.TRADE_PLACES_ID or (id == ArcaneTankKit.DECOY_ID and arcane_tank.decoy_needs_reflection()):
		return str(arcane_tank.reflections())   # the Reflections you have (to fill up, or to spend)
	if id == ArcaneMeleeKit.ENCORE_ID:
		return str(arcane_melee.traces())   # the Traces it would replay
	if id == StringsKit.STRING_ID:
		return str(strings.string_charges())   # the Strings in your hand
	if hymns.verses_text(id) != "":
		return hymns.verses_text(id)   # Holy healer: the Verses you hold
	if id == ArcaneCasterKit.CONVERGENCE_ID:
		# Convergence: the Arcane spells on cooldown that would count right now.
		var running := mini(arcane_caster.arcane_cooldowns(ArcaneCasterKit.CONVERGENCE_ID), Balance.CONVERGENCE_MAX)
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
	var wasting := ShadowTalentsKit.dot_speed_with(1.0, _talent("shadow_wasting"))   # Wasting: all of my damage over time
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
	coef *= strings._others_heal_mult(tgt)   # Many Hands
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
	strings._crossed_taken(info)   # Crossed Strings: what it spared me goes to the enemy at the other end
	hymns._vigil_taken(info)     # Watchful: a big hit while I stand in a healer's Vigil
	shepherd._owl_taken(info)       # a Nature healer's Owl watching over me dives
	colossus._colossus_hit_taken(info)   # Nature tank: hits on my Giant's Hands give Sap
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
	lightning_melee._melee_kit_hit_taken(info)   # Reflex Arc, Faraday Guard, Back-Current
	lightning_tank._parry_kit_hit_taken(info)   # Return Stroke, Humming Blade, Quick Wrists, Draw the Storm
	arcane_tank._reflection_kit_hit_taken(info)   # a dodge (or Stand-In) shatters a Reflection
	censer._censer_hit_taken(info)   # Incense from hits and blocks; Unfallen counts the damage
	arcane_open._mirror_finish(info)   # Mirror Finish: what I dodge, parry or block hurts the attacker
	fire_lightning_talents._tempered(info)   # Tempered: a block gives Armor for a while
	shadow_talents._spite_on_hit_taken(info)   # Spite: taking damage boosts my next spell or ability
	holy_talents._penitent_hit(info)   # Penitent: a big hit makes my next heal on myself stronger

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
	if id == DecayKit.DECAY_HIT_ID:
		chance += float(info.get_meta(DecayKit.DECAY_CRIT_META, 0.0))
	# Worked Up's capstone: my Hounds' bites crit more often while they are Roused (_hound_bite marks them).
	if id == HoundsKit.HOUND_BITE_ID:
		chance += float(info.get_meta(HoundsKit.HOUND_CRIT_META, 0.0))
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
	if id == ArcaneCasterKit.WARD_FX and is_same(status.last_shield_source, self):
		arcane_caster._ward_broke()   # Interval Ward: the time it had left comes off its cooldown
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


# --- Mouseover casting ------------------------------------------------------------------------
# A setting (Settings > Interface), like WoW's: pressing an ability while the
# mouse is over a legal target for it uses it on that target, without changing
# my target. Enemy abilities: the enemy under the mouse (target is swapped for
# that one use, or until that cast lands / is cancelled; the ring and the target
# frame keep showing my real one: displayed_target). Ally spells: the ally (or
# me) under the mouse (_pick_support_target asks first). Prism abilities: my
# prism under the mouse. A mouseover that isn't legal is ignored.

var _mo_swapped := false          # is `target` a mouseover's right now?
var _mo_prev_target: Node3D = null
var _mo_ally: Node3D = null       # the ally under the mouse for this press
var _mo_prism := ""               # the key of my prism under the mouse for this press

## The enemy target to show (ring, target frame): never a mouseover cast's.
func displayed_target() -> Node3D:
	if _mo_swapped:
		return _mo_prev_target if is_instance_valid(_mo_prev_target) else null
	return target

func mouseover_on() -> bool:
	var s := get_node_or_null("/root/Settings")
	return s != null and bool(s.get("mouseover_casting"))

## Before an ability is used: look under the mouse for a legal target for it.
func _mouseover_begin(id: String) -> void:
	_mo_ally = null
	_mo_prism = ""
	if not mouseover_on() or not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var at := get_viewport().get_mouse_position()
	if PrismsKit.PRISM_TARGET_IDS.has(id):
		_mo_prism = prism_kit._prism_at(at, cam)
	elif _needs_enemy_target(id):
		var e: Node3D = _enemy_at(at, cam)
		if e != null and e != target and _target_error(e) == "" and _in_ability_range(id, e):
			if not _mo_swapped:
				_mo_prev_target = target
			_mo_swapped = true
			target = e
	else:
		_mo_ally = _mouseover_ally_at(at, cam)

## After the ability was used: forget the mouseover (a swapped enemy target is
## kept while the cast it started is still going: _mouseover_tick puts it back).
func _mouseover_end() -> void:
	_mo_ally = null
	_mo_prism = ""
	if _mo_swapped and not casting:
		_mouseover_restore()

func _mouseover_restore() -> void:
	target = _mo_prev_target if is_instance_valid(_mo_prev_target) and _mo_prev_target.is_alive() else null
	_mo_prev_target = null
	_mo_swapped = false

## Every frame: a mouseover cast that ended gives my real target back.
func _mouseover_tick() -> void:
	if _mo_swapped and not casting:
		_mouseover_restore()

## The enemy under the mouse (the same ray as clicking one), or null.
func _enemy_at(screen_pos: Vector2, cam: Camera3D) -> Node3D:
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 200.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | ENEMY_LAYER_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit and hit.collider is Node3D and hit.collider.has_method("set_targeted") and hit.collider.is_alive() and can_see(hit.collider):
		return hit.collider
	return null

## The ally under the mouse: a party member, or me.
func _mouseover_ally_at(screen_pos: Vector2, cam: Camera3D) -> Node3D:
	var ally := _ally_at(screen_pos, cam)
	if ally != null:
		return ally
	for h in [0.3, 0.9, 1.5]:
		var p: Vector3 = global_position + Vector3(0, h - 0.9, 0)
		if not cam.is_position_behind(p) and cam.unproject_position(p).distance_to(screen_pos) < ALLY_PICK_PX:
			return self
	return null

