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
var frostfire_kit: FrostfireKit = _kit(FrostfireKit) as FrostfireKit
var ice_shards_kit: IceShardsKit = _kit(IceShardsKit) as IceShardsKit
var frost_melee: FrostMeleeKit = _kit(FrostMeleeKit) as FrostMeleeKit
var glacier: GlacierKit = _kit(GlacierKit) as GlacierKit
var frost_steel: FrostSteelKit = _kit(FrostSteelKit) as FrostSteelKit
var pacts_kit: PactsKit = _kit(PactsKit) as PactsKit
var dusk_till_dawn: DuskTillDawnKit = _kit(DuskTillDawnKit) as DuskTillDawnKit
var frost_runes: FrostRunesKit = _kit(FrostRunesKit) as FrostRunesKit
var frost_more: FrostMoreKit = _kit(FrostMoreKit) as FrostMoreKit
var frost_bow: FrostBowKit = _kit(FrostBowKit) as FrostBowKit
var fire_runes: FireRunesKit = _kit(FireRunesKit) as FireRunesKit
var fire_caster: FireCasterKit = _kit(FireCasterKit) as FireCasterKit
var fire_fury: FireFuryKit = _kit(FireFuryKit) as FireFuryKit
var fire_talents: FireTalentsKit = _kit(FireTalentsKit) as FireTalentsKit
var frost_talents: FrostTalentsKit = _kit(FrostTalentsKit) as FrostTalentsKit
var lightning_talents: LightningTalentsKit = _kit(LightningTalentsKit) as LightningTalentsKit
var arcane_talents: ArcaneTalentsKit = _kit(ArcaneTalentsKit) as ArcaneTalentsKit
var fire_tank: FireTankKit = _kit(FireTankKit) as FireTankKit
var fire_melee: FireMeleeKit = _kit(FireMeleeKit) as FireMeleeKit
var fire_bow: FireBowKit = _kit(FireBowKit) as FireBowKit
var fire_cooldowns: FireCooldownsKit = _kit(FireCooldownsKit) as FireCooldownsKit
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
var frost_healer: FrostHealerKit = _kit(FrostHealerKit) as FrostHealerKit
var colossus: ColossusKit = _kit(ColossusKit) as ColossusKit
var venomstring: VenomstringKit = _kit(VenomstringKit) as VenomstringKit
var nature_open: NatureTalentsOpenKit = _kit(NatureTalentsOpenKit) as NatureTalentsOpenKit
var rez_kit: RezKit = _kit(RezKit) as RezKit
var utility: UtilityKit = _kit(UtilityKit) as UtilityKit
var wheel: WheelKit = _kit(WheelKit) as WheelKit
var brawler: BrawlerKit = _kit(BrawlerKit) as BrawlerKit
var rogue: RogueKit = _kit(RogueKit) as RogueKit
var sharp: SharpshooterKit = _kit(SharpshooterKit) as SharpshooterKit
var martial_talents: MartialTalentsKit = _kit(MartialTalentsKit) as MartialTalentsKit

## A component of `script` working for me (a child node, made before _ready).
func _kit(script: Script) -> Node:
	var k: Node = script.new()
	k.name = str(script.get_global_name())
	k.set("player", self)
	add_child(k)
	return k

## Every component's values for Trackers (PlayerKit.tracker_values), in one dictionary.
func tracker_values() -> Dictionary:
	var out := {}
	for c in get_children():
		if c is PlayerKit:
			out.merge(c.tracker_values(), true)
	return out

# Forwards to VenomstringKit (called from other scripts).
func venom() -> float:
	return venomstring.venom()

func venom_flow() -> bool:
	return venomstring.venom_flow()

# Forwards to ColossusKit (called from other scripts).
func sap() -> int:
	return colossus.sap()

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

# Forwards to CenserKit (called from other scripts).
func incense() -> int:
	return censer.incense()

func motes() -> Array:
	return censer.motes()

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

func overture_ready(spell: String) -> bool:
	return hymns.overture_ready(spell)

# Forwards to StringsKit (called from other scripts).
func string_time() -> float:
	return strings.string_time()

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
	# [pct, label, pct, label, ...]: each its own damage-meter line.
	var out: Array = shadow_talents.crit_hit_bonus(info)   # Ill Will (damage over time)
	out.append_array(wheel.crit_hit_bonus(info))           # Keen Edge (the Greatsword)
	out.append_array(martial_talents.crit_hit_bonus(info))   # Keen Strikes
	out.append_array(fire_talents.crit_hit_bonus(info))   # Cold Steel
	out.append_array(frost_talents.crit_hit_bonus(info))   # Cold Eye
	out.append_array(lightning_talents.crit_hit_bonus(info))   # Charged Steel
	out.append_array(arcane_talents.crit_hit_bonus(info))   # Sharp Mind
	return out

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

# Forwards to BrawlerKit (CombatSystem asks while a hit on me is worked out).
func incoming_bonus(info: RefCounted) -> Array:
	return brawler.incoming_bonus(info)   # Clinch

func before_hit_lands(info: RefCounted) -> void:
	brawler.before_hit_lands(info)   # Catch: is this the caught hit?

# Forwards to ArcaneCasterKit (called from other scripts).
func arcane_cooldowns(except: String = "") -> int:
	return arcane_caster.arcane_cooldowns(except)

func bolt_tag(t: String) -> void:
	arcane_caster.bolt_tag(t)

func glint_ready(id: String) -> bool:
	return arcane_caster.glint_ready(id)
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

# Forwards to NatureTalentsOpenKit (StatusContainer: a root or hold of mine ran out: Clinging Vines).
func root_ended(foe: Node, res: Resource) -> void:
	nature_open.root_ended(foe, res)

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

# Forwards to FireCooldownsKit (called from other scripts).
func phoenix_cast() -> void:
	fire_cooldowns.phoenix_cast()

func crucible_radius() -> float:
	return fire_cooldowns.crucible_radius()

func cinder_step_ready(id: String) -> bool:
	return fire_cooldowns.cinder_step_ready(id)

func cool_head_active() -> bool:
	return fire_cooldowns.cool_head_active()

func concentrated_fire_ready(id: String) -> bool:
	return fire_cooldowns.concentrated_fire_ready(id)

# Forwards to FireBowKit (called from other scripts).
func dot_speed_mult(tgt: Node, res: Resource) -> float:
	return fire_bow.dot_speed_mult(tgt, res)

# Forwards to FireMeleeKit (called from other scripts).
func heat_stacks() -> int:
	return fire_melee.heat_stacks()

# Forwards to FireCasterKit (called from other scripts).
func charges_text(id: String) -> String:
	var cracks := wheel.charges_text(id)   # Martial warrior: the Cracks on a Break button
	if cracks != "":
		return cracks
	var over := sharp.charges_text(id)   # Martial archer: the Overcut on a shot
	return over if over != "" else fire_caster.charges_text(id)

# Forwards to FrostBowKit (called from other scripts).
func frozen_instinct_ready() -> bool:
	return frost_bow.frozen_instinct_ready()

# Forwards to FrostMoreKit (called from other scripts).
func effect_override(eff: Resource) -> Resource:
	return frost_more.effect_override(eff)

func receive_snow_ward(caster: Node, amount: int, armor_pct: float = 0.0) -> void:
	frost_more.receive_snow_ward(caster, amount, armor_pct)

# Forwards to FrostRunesKit (called from other scripts).
func receive_frozen_aegis(caster: Node, amount: int, cap: int, armor_pct: float = 0.0) -> void:
	frost_runes.receive_frozen_aegis(caster, amount, cap, armor_pct)

# Forwards to PactsKit (called from other scripts).
func pact_id() -> String:
	return pacts_kit.pact_id()

func pact_broken() -> bool:
	return pacts_kit.pact_broken()

func heal_taken_mult(source: Node, _ability_id: String = "") -> float:
	return pacts_kit.heal_taken_mult(source, _ability_id)

# Forwards to FrostMeleeKit (called from other scripts).
func slow_taken_mult() -> float:
	return frost_melee.slow_taken_mult()

# Forwards to IceShardsKit (called from other scripts).
var ice_shard_charges: int:
	get:
		return ice_shards_kit.ice_shard_charges
	set(v):
		ice_shards_kit.ice_shard_charges = v

func shards_firing() -> bool:
	return ice_shards_kit.shards_firing()

func shard_recharge_left() -> float:
	return ice_shards_kit.shard_recharge_left()

# Forwards to FrostfireKit (called from other scripts).
func proc_cast(ability_id: String, enemy: Node) -> void:
	frostfire_kit.proc_cast(ability_id, enemy)

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
const CastFX = preload("res://scripts/core/cast_fx.gd")

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
	amount = brawler.bruise_take(amount)   # Martial tank: part of the hit goes into Bruise
	amount = strings._still_standing_limit(amount)   # Still Standing: the Strings hold off a killing blow
	amount = censer._unfallen_cap(amount)           # Unfallen: nothing can kill me
	if amount <= 0:
		return
	health = max(health - amount, 0)
	pacts_kit._pact_on_damage(amount)      # my Pact: one big hit (Sidestep), too little health left (Thin Line)
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
#   CASTING       : cast bar filling (Frost Bolt, Blizzard)
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
	pacts_kit._pact_on_down()   # Pact of the Unbowed
	casting = false
	cancel_placement()
	change_state(PState.DEAD)
	current_state = "dead"   # the party's puppet of me stops showing "Downed"
	fire_fury.clear()
	arcane_caster._clear_arcane()
	fire_cooldowns._heat_on = false
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
# act, and you bleed out after a while. Only a healer's revive brings you back
# (Last Verse, Not Finished With You); once dead, a healer's out-of-combat rez
# (RezKit) raises you where you fell. If everyone is down (or you press Restart
# to give up) you die for real. Solo and in the Training Room you just die.

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
	pacts_kit._pact_on_down()   # Pact of the Unbowed
	casting = false
	cancel_placement()
	clear_queue()
	change_state(PState.DOWNED)
	fire_fury.clear()   # my Blowback burns go out with me
	arcane_caster._clear_arcane()  # (so do Countdown marks; the Mirror Sigil and the Afterimage go)
	fire_cooldowns._heat_on = false
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
		gl.event("You are down! A healer can revive you.",
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
## full health and resources (or `health_pct` / `mana_pct` of them: a healer's
## out-of-combat rez). GameManager.revive_local() / raise_local() call this.
func respawn(at: Vector3, health_pct: float = 100.0, mana_pct: float = 100.0) -> void:
	if pstate != PState.DEAD and pstate != PState.DOWNED and health > 0:
		return
	pstate = PState.IDLE
	casting = false
	if status:
		status.clear()
	health = maxi(int(round(max_health * health_pct / 100.0)), 1)
	resources["mana"] = resource_max("mana") * mana_pct / 100.0
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
	_bus().cast_finished.connect(ice_shards_kit._on_spell_cast_for_shards)
	_bus().cast_finished.connect(frost_runes._cold_precision_on_cast)
	_bus().cast_finished.connect(holy_talents._zeal_on_cast)   # Zeal (an open Holy talent)
	_bus().cast_finished.connect(wheel._on_cast_finished)   # Martial warrior: each use wears the held weapon
	_bus().damage_dealt.connect(wheel._on_damage_dealt_wheel)   # ... and its rider
	_bus().damage_dealt.connect(rogue._on_damage_dealt_rogue)   # Martial DPS: Kill window crits give Energy, attacks end Play Dead
	_bus().damage_modify.connect(rogue._on_damage_modify)   # ... Flow and Whetstone
	_bus().ability_used.connect(rogue._on_ability_used)   # ... acting ends Play Dead
	_bus().damage_dealt.connect(sharp._on_damage_dealt_sharp)   # Martial archer: hits bring other shots back sooner
	# Cast / release / heal flair for every ability (only pictures: CastFX).
	_bus().cast_started.connect(_cast_fx_start)
	_bus().cast_finished.connect(_cast_fx_release)
	_bus().cast_interrupted.connect(func(_id): _cast_fx_end())
	_bus().heal_done.connect(_heal_fx)
	_bus().damage_modify.connect(sharp._on_damage_modify)   # ... and the Streak
	_bus().ability_used.connect(frost_runes._cold_precision_on_use)
	_bus().damage_dealt.connect(frost_runes._on_damage_dealt_frost)
	_bus().damage_dealt.connect(fire_runes._on_damage_dealt_fire)
	_bus().damage_dealt.connect(bottled_kit._on_damage_dealt_lightning)
	_bus().damage_dealt.connect(arcane_caster._on_damage_dealt_arcane)
	_bus().damage_dealt.connect(decay._on_damage_dealt_shadow)
	_bus().enemy_died.connect(nature_open._on_enemy_died_nature)   # Food Chain (before Carrion forgets whom I hit)
	_bus().enemy_died.connect(shadow_talents._on_enemy_died_shadow)   # Carrion
	_bus().heal_done.connect(strings._on_heal_done_strings)    # the Strings share my heals
	_bus().heal_done.connect(hymns._on_heal_done_hymns)      # the Hymns: Chorus, Vigil, Mercy's Ear
	_bus().heal_done.connect(holy_talents._on_heal_done_holy)   # Candlelight
	_bus().damage_dealt.connect(hymns._on_damage_dealt_holy)  # High Note's heal
	_bus().cast_finished.connect(pacts_kit._pact_on_ability)     # Pact of the Purist: an ability of mine went off
	_bus().dungeon_cleared.connect(func(_summary): pacts_kit._pact_cleared = true)   # Pact of the Restless: nothing left to fight
	_bus().cast_finished.connect(arcane_caster._on_cast_for_arcane)
	_bus().cast_finished.connect(fire_lightning_talents._change_of_pace)
	_bus().cast_finished.connect(lightning_talents._on_cast_finished)   # Charged Air
	_bus().ability_used.connect(lightning_talents._on_ability_used)   # Cut the Line
	_bus().damage_dealt.connect(lightning_talents._on_damage_dealt)   # Snap Cast
	_bus().cast_finished.connect(arcane_talents._on_cast_finished)   # Second Hand
	_bus().ability_used.connect(arcane_talents._on_ability_used)   # On the Dot
	_bus().damage_dealt.connect(arcane_talents._on_damage_dealt)   # Glass Dust, Twin Blades
	_bus().cast_started.connect(overload_kit._on_cast_for_static)
	_bus().cast_finished.connect(overload_kit._on_cast_for_static)
	_bus().damage_dealt.connect(fire_tank._slag_skin_retaliate)
	_bus().damage_dealt.connect(fire_bow._pitch_on_hit)   # Fire archer: Pitch and its Ignites
	_bus().damage_dealt.connect(fire_cooldowns._on_hit_taken)
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
	if placing and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_update_placement(event.position)
			if not placement_valid:
				_error("Not in line of sight")
			elif gcd_left > 0.0 and on_gcd(placing_id):
				pass   # still on the global cooldown: keep aiming, click again
			elif (placing_id == PrismsKit.SET_PRISM_ID or placing_id == PrismsKit.REALIGN_ID or placing_id == LightstringKit.PRISM_ARROW_ID) and prism_kit._prism_place_error(placing_id, cast_point) != "":
				_error(prism_kit._prism_place_error(placing_id, cast_point))   # (out of range: keep aiming)
			elif placing_id == FireBowKit.CINDER_RAIN_ID and fire_bow._cinder_rain_error(cast_point) != "":
				_error(fire_bow._cinder_rain_error(cast_point))   # out of range: keep aiming
			elif placing_id == ArcaneTankKit.DECOY_ID and arcane_tank._decoy_error(cast_point) != "":
				_error(arcane_tank._decoy_error(cast_point))         # (the same for Decoy)
			elif (placing_id == WeaverKit.MOSSBACK_ID or placing_id == WeaverKit.VIPERS_ID) and weaver._finisher_place_error(placing_id, cast_point) != "":
				_error(weaver._finisher_place_error(placing_id, cast_point))   # (Nature finishers: keep aiming)
			else:
				cancel_placement()
				if placing_id == FireCooldownsKit.CRUCIBLE_ID:
					fire_cooldowns._start_crucible(cast_point)
				elif placing_id == ArcaneTankKit.DECOY_ID:
					arcane_tank._start_decoy(cast_point)
				elif placing_id == PrismsKit.SET_PRISM_ID or placing_id == PrismsKit.REALIGN_ID or placing_id == LightstringKit.PRISM_ARROW_ID:
					prism_kit._start_prism_place(placing_id, cast_point)
				elif placing_id == FireBowKit.CINDER_RAIN_ID:
					fire_bow._start_cinder_rain(cast_point)
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
	if pacts_kit._pact_purist_blocks(id):   # Pact of the Purist: the first press only warns
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
	id = wheel.form_of(id)   # Martial warrior: a Wheel button is the held weapon's move (now, not when queued)
	id = rogue.form_of(id)   # Martial DPS: in a Kill window a builder is its Kill form
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
		gcd_total = lightning_talents.gcd_for(id, gcd_total)   # Short Fuse: Lightning weapon abilities
		gcd_left = gcd_total
		if id == StringsKit.STRING_ID:   # String: a short global cooldown, so several can be tied quickly
			gcd_total = StringsKit.string_gcd(gcd_total)
			gcd_left = gcd_total
		elif BrawlerKit.short_gcd(id):   # the Brawler's strikes and Catch: a shorter global cooldown
			gcd_total = BrawlerKit.strike_gcd(gcd_total)
			gcd_left = gcd_total

## Enemy-targeted bolt spells with a cast time (same flow as Frost Bolt).
const ENEMY_BOLTS := ["frostbolt", "fireball", "lightningbolt", "immolate",
	"kilnblast", "frostfirebolt", "coldspike", "chainlightning", "discharge",
	"livewire", "forkedbolt", "unravel", "countdown", "convergence",
	"blight", "erode", "highnote", "piercinglight", "thornshot", "briartiger",
	"sporesleep", "coolingslag"]

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
const SUPPORT_CASTS := ["rimeshell", "flashfreeze", "hoist", "patchup", "psalm", "outpour", "canticle", "exultation", "brightlance", "dewfall", "fawn", "meltwater", "rimefall"]
## Instant abilities every character has (handled like drafted ones).
const BASE_INSTANTS: Array[String] = []   # (none since the Martial book was wiped)

func _use_ability_now(id: String) -> void:
	if id == DecayKit.BLIGHT_ID and (frost_melee._has_rune(DecayKit.OPEN_WOUND_RUNE) or decay.interest_ready()):
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
	if id in RezKit.IDS:
		rez_kit.start(id)   # a healer's out-of-combat rez
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
				var rain_err := fire_bow._cinder_rain_error()
				if rain_err != "":
					_error(rain_err)
				else:
					_begin_placement(id)
		"glacialdraw":
			cancel_placement()
			frost_bow._start_glacial_draw()
		"embervolley":
			cancel_placement()
			fire_caster._start_ember_volley()
		"walloffire":
			cancel_placement()
			fire_caster._start_fire_wall()
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
		"heavydraw":
			cancel_placement()
			sharp._start_heavy_draw()   # Martial archer (a bow cast; instant at full Streak)
		"mendingray":
			cancel_placement()
			prism_kit._start_mending_ray()
		"trinket_1", "trinket_2":
			_use_trinket(id)
		_:
			if Abilities.DRAFT_POOL.has(id) or BASE_INSTANTS.has(id) or LightningMeleeKit.RUNE_INSTANTS.has(id) \
					or Abilities.wheel_weapon_of(id) != "" or Abilities.is_kill_form(id) \
					or Abilities.BROUGHT_BUTTONS.has(id):   # (the Wheel's moves come with their weapon; the Rogue's Kill forms with a Kill window; Go In, Kick, Elbow, Fighting Style and Loose with another card)
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
	status.shield_broken.connect(frost_runes._on_my_shield_broken)
	status.shield_expired.connect(_on_my_shield_expired)
	status.shield_shared.connect(_on_my_shield_shared)
	status.changed.connect(func():
		RimeShellFx.show_on(self, status.has("rime_shell"), RimeShellFx.cracks_for(status.absorb_fraction("rime_shell")))   # (its cracks)
		fire_cooldowns._cool_head_check()
		fire_cooldowns._heat_sink_check()
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
	if stat == Stats.PARRY:
		v += lightning_talents.back_to_the_wall()   # Back to the Wall: more Parry at low health
	if stat == Stats.DODGE:
		v += arcane_talents.dodge_bonus()   # Last Copy
	if stat == Stats.ARMOR:
		v *= arcane_talents.armor_mult()   # Glass Armor
	return v

## Which power stat my excess crit becomes: Attack Power with the Rune of the
## Dull Edge, Spell Power with the Rune of the Dull Mind, "" with neither.
## (Only one of the two can be equipped at a time: Runes.FAMILIES.)
func dull_rune_power() -> String:
	return dull_power_stat(frost_melee._has_rune("dull_edge"), frost_melee._has_rune("dull_mind"))

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
	v += pacts_kit._pact_stat(key)                         # my Pact (Haste, crit, movement, max health and mana)
	if key == Stats.HASTE:
		v += frost_melee._glacial_haste                      # Glacial Heart capstone
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
	_combat().heal(self, self, amount * pacts_kit._pact_heal_mult(), ability_id)   # (my Pact: Shepherd)

var _bar_role := "dps"      # my role from my bars (Abilities.role_of_bar), worked out again when they change
var _bar_role_hash := 0

func _my_role() -> String:
	var pd := get_node_or_null("/root/PlayerData")
	if pd == null:
		return "dps"
	var h: int = pd.action_bar.hash()
	if h != _bar_role_hash:
		_bar_role_hash = h
		_bar_role = Abilities.role_of_bar(pd.action_bar)
	return _bar_role

## The share of their damage my hits deal, and the threat it makes (CombatSystem):
## a tank deals Balance.TANK_DAMAGE_PCT of it for TANK_THREAT_MULT the threat.
func outgoing_damage_mult() -> float:
	return Abilities.role_damage_mult(_my_role())

func outgoing_threat_mult() -> float:
	return Abilities.role_threat_mult(_my_role())

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
	if ability_id == FrostfireKit.FROSTFIRE and damage_type == "":
		return frostfire_kit._frostfire_hit(enemy, base, is_proc)
	if ability_id == LightstringKit.REFRACTION_ID or ability_id == LightstringKit.VOLLEY_ARROW_ID:
		# Holy archer: arrows from a gold prism (not abilities of their own) are Holy procs.
		damage_type = "holy"
		tags = PackedStringArray(LightstringKit.LIGHTSTRING_TAGS)
		is_proc = true
	var at: Vector3 = enemy.global_position
	var info = _combat().ability_hit(self, enemy, base, ability_id, is_proc, damage_type, tags)
	if not is_proc and not info.avoided():
		frostfire_kit._on_hit_extra(enemy, at, ability_id)
	return int(info.amount)

# --- Resources: mana, Energy and Fury (Energy / Fury are bars of RESOURCE_MAX = 100) ----

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const RESOURCE_MAX := Balance.RESOURCE_MAX
const MANA_REGEN := Balance.MANA_REGEN      # points per second
const ENERGY_REGEN := Balance.ENERGY_REGEN  # points per second
const FURY_DECAY := Balance.FURY_DECAY      # points per second lost

var resources := {"mana": RESOURCE_MAX, "energy": RESOURCE_MAX, "fury": 0.0}

func resource_points(res: String) -> int:
	return int(floor(float(resources.get(res, 0.0)) + 0.0001))

func can_afford(id: String, report: bool = false) -> bool:
	# The Rogue (Martial DPS): Go In needs Flow, Kill forms and Close It Out a Kill window.
	if not rogue.usable_now(id):
		if report:
			_error(rogue._rogue_precheck(id))
		return false
	# The Brawler (Martial tank): Catch only on a melee tell, One More only after a move, no shield.
	if Abilities.BRAWLER_IDS.has(id):
		if has_shield():
			if report:
				_error("Can't be used with a shield")
			return false
		if not brawler.usable_now(id):
			if report:
				_error(brawler._brawler_precheck(id))
			return false
	if id == "iceshards" and ice_shards_kit.ice_shard_charges <= 0:
		if report:
			_error("No Ice Shard charges")
		return false
	# Quench and Flare run on Heat.
	var heat_need := fire_melee.heat_needed_now(id)   # (Flare is free in the White band)
	if heat_need > 0 and fire_melee.heat_stacks() < heat_need:
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
	# Discharge and Ground Out spend ALL my Energy, Vent Flames all my Fury: they need some to spend.
	if Abilities.SPENDS_ALL.has(id):
		var all_res := Abilities.resource_of(id)
		var need := Balance.VENT_FURY_MIN if all_res == "fury" else Balance.SPEND_ALL_MIN_ENERGY
		if float(resources.get(all_res, 0.0)) + 0.0001 < need:
			if report:
				_error("Not enough %s" % all_res)
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
## base mana each) and get Cold Discipline's discount for spells; Energy / Fury
## costs are that many Energy / Fury of their 100 (Grounding Surge halves Energy costs).
func resource_cost(id: String, with_storm_cycle: bool = true) -> float:
	if FrostBowKit.instinct_applies(id) and (frost_bow._instinct_cast or (not casting and frost_bow.frozen_instinct_ready())):
		return 0.0   # Frozen Instinct: free
	if id == FireCooldownsKit.CRUCIBLE_ID and fire_cooldowns._crucible_standing():
		return 0.0   # moving a Crucible that still stands is free
	var cost := float(Abilities.cost_of(id))
	if id == LightningTankKit.RETURN_STROKE_ID:   # Rune of Resonance: dearer without a parry behind it
		cost = LightningTankKit.return_stroke_cost(cost, status != null and status.has(LightningTankKit.RETURN_STROKE_FX), frost_melee._has_rune(LightningTankKit.RESONANCE_RUNE))
	if id == LightningMeleeKit.STATIC_STEP_ID and status != null and status.has(BottledLightningKit.WHIP_CRACK_FX):
		cost = BottledLightningKit.whip_crack_cost(cost, _talent("lightning_whip_crack"))    # Whip Crack
	if id == LightningCasterKit.STORM_ARROW_ID and status != null:                         # Loaded Quiver, Snap Shot
		cost = StormArrowKit.storm_arrow_cost(cost, status.has(LightningCasterKit.LOADED_QUIVER_FX),
			_talent("lightning_snap_shot") if status.has(LightningCasterKit.SNAP_SHOT_FX) else 0.0)
	if cost > 0.0 and Abilities.resource_of(id) == "energy":
		cost = maxf(cost - _talent("martial_thrift"), 0.0)                                                  # Thrift
		if Abilities.tags_of(id).has("Ranged"):
			cost = maxf(cost - _talent("fire_light_string"), 0.0)                                         # Easy Draw: arrows
		cost = LightningCasterKit.surge_energy_cost(cost, lightning_caster.surge_active())                   # Grounding Surge
		if Abilities.category_of(id) == "holy":
			cost *= 1.0 - _talent("holy_light_draw") / 100.0                                                 # Light Draw
		if with_storm_cycle and bottled_kit.storm_cycle_ready():
			cost = 0.0                                                   # Storm Cycle: this one is free
	if cost > 0.0 and Abilities.resource_of(id) == "fury":
		cost = maxf(cost - _talent("fire_lean_fuel"), 0.0)                                                 # Lean Fuel
		cost = frost_talents.finisher_cost(id, cost)                                                         # Thaw Strike
	if cost <= 0.0 or Abilities.resource_of(id) != "mana":
		return cost * pacts_kit._pact_cost_mult(Abilities.resource_of(id))   # (my Pact: Sidestep)
	cost *= mana_unit() * pacts_kit._pact_cost_mult("mana")                  # (my Pact: Sidestep, Reservoir)
	var tags := Abilities.tags_of(id)
	if tags.has("Spell"):
		var pd := get_node_or_null("/root/PlayerData")
		if pd:
			cost *= 1.0 - float(pd.talent_value("frost_discipline")) / 100.0   # Cold Discipline
	if HolyTalentsKit.is_holy_heal(id):
		cost *= 1.0 - _talent("holy_clear_mind") / 100.0   # Clear Mind (both Holy healers)
	cost *= NatureTalentsOpenKit.lush_mult(id, _talent("nature_lush"))   # Lush
	cost *= NatureTalentsOpenKit.mist_mult(id, _talent("nature_morning_mist"))   # Morning Mist
	if FrostTalentsKit.is_frost_care(id):
		cost *= 1.0 - _talent("frost_cold_hands") / 100.0   # Cold Hands
	cost *= arcane_talents.mana_mult(id)   # Thrifty Mind
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
			lightning_talents.energy_spent(cost, id)   # Afterspark, Built Charge, Spinning Up, Draw Down
		if HoundsKit.rouses(res, cost):
			hounds._rouse_hounds()   # Shadow melee: spending Fury Rouses my Hounds
			hounds.fury_spent(cost)   # Pack Leader's capstone: and keeps them out longer
	return true

func _gain(res: String, amount: float) -> void:
	if amount > 0.0:
		amount *= PactsKit.PACTS.resource_gain_mult(pacts_kit.pact_id(), pacts_kit.pact_broken())   # Pact of the Restless
	resources[res] = clampf(float(resources[res]) + amount, 0.0, resource_max(res))

## Max of a resource. Mana grows with Max Mana (Intellect); Energy / Fury stay at 100.
func resource_max(res: String) -> float:
	if res == "mana":
		return maxf(get_stat(Stats.MAX_MANA), 1.0)
	if res == "energy":
		return RESOURCE_MAX + _talent("lightning_deep_reserves")   # Deep Reserves
	return RESOURCE_MAX

func _tick_resources(delta: float) -> void:
	if is_dead():
		return
	_gain("mana", MANA_REGEN * mana_unit() * delta * (1.0 if in_combat else nature_open.hibernate_mult()))   # (Hibernate)
	_gain("energy", LightningMeleeKit.energy_regen(ENERGY_REGEN, lightning_talents.regen_pct()) * delta)   # Quick Charge, Afterflow
	if not casting:   # (no Fury is lost while casting or channeling: the Fire caster's)
		_gain("fury", -HoundsKit.fury_decay(FURY_DECAY, _talent("shadow_thick_blood")) * delta
			* maxf(1.0 - _talent("fire_hold_the_heat") / 100.0, 0.0))   # Thick Blood, Hold the Heat

# --- Natural health regeneration (WoW-style) ------------------------------------------
# A trickle in combat, fast once the fight is over (after a short delay).
# Rates are % of max health per second, in balance.gd.

var _regen_carry := 0.0          # fractional health not applied yet
var _out_of_combat_since := 0.0  # when combat last ended

func _tick_health_regen(delta: float) -> void:
	if is_dead() or health >= max_health or PactsKit.PACTS.bleed_pct(pacts_kit.pact_id()) > 0.0:   # (Pact of the Restless: none at all)
		_regen_carry = 0.0
		return
	var now := Time.get_ticks_msec() / 1000.0
	var pct := Balance.HP_REGEN_IN_COMBAT_PCT
	if not in_combat:
		pct = Balance.HP_REGEN_OUT_OF_COMBAT_PCT if now - _out_of_combat_since >= Balance.HP_REGEN_OOC_DELAY \
			else Balance.HP_REGEN_IN_COMBAT_PCT
	pct *= 1.0 + _talent("martial_hardy") / 100.0   # Hardy
	if not in_combat:
		pct *= nature_open.hibernate_mult()   # Hibernate
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
	return id != "" and not Abilities.is_trinket_slot(id) and not INTERRUPT_LOCKOUT.has(id) \
		and not Abilities.OFF_GCD.has(id)

## Interrupts (off the global cooldown, like in WoW): seconds the target can't cast afterwards.
const INTERRUPT_LOCKOUT := Balance.INTERRUPT_LOCKOUT

func _start_gcd() -> void:
	gcd_total = gcd_duration()
	if frost_melee._cold_snap > 0.0:   # Cold Snap: a freeze shortened this GCD
		gcd_total = maxf(gcd_total - frost_melee._cold_snap, Balance.COLD_SNAP_MIN_GCD)
		frost_melee._cold_snap = 0.0
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
	var pact_rate := PactsKit.PACTS.cooldown_rate(pacts_kit.pact_id(), pacts_kit.pact_broken())   # Pact of the Sidestep: every cooldown
	for id in cooldowns.keys():
		var step := delta if plain else delta * ArcaneCasterKit.arcane_cooldown_rate(arcane_rate, arcane_caster._is_arcane_spell(str(id)),
			arcane_caster._in_arcane_book(str(id)), clock)
		cooldowns[id] = float(cooldowns[id]) - step * pact_rate * arcane_talents.cooldown_rate(str(id)) * fire_melee.cooldown_rate(str(id))   # (Steady Arm) and Spare Moment
		if cooldowns[id] <= 0.0:
			cooldowns.erase(id)
	arcane_open._tick_borrowed_time()   # Borrowed Time: a long cooldown just came back?
	arcane_talents._tick_cooldowns()   # On the Dot, Turning Gears: an Arcane spell just came back?
	ice_shards_kit._tick_ice_shards(delta)
	fire_caster._tick_vent_charges(delta)

# --- Talent hooks ---------------------------------------------------------------------

## Multiplier for slows you apply with these tags (StatusContainer asks). No
## talent strengthens slows right now (Deep Chill was removed).
func slow_mult(_tags: PackedStringArray) -> float:
	return arcane_caster._slow_mult_now   # (1 unless Aftershock is being applied: its rank sets the strength)

## Multiplier for shields (absorbs) you apply (Rime Ward).
func absorb_mult() -> float:
	var pd := get_node_or_null("/root/PlayerData")
	return 1.0 + (float(pd.talent_value("frost_absorb")) / 100.0 if pd else 0.0)

## Multiplier for shields I put on myself (StatusContainer.set_absorb asks): Woodgrain.
func self_absorb_mult() -> float:
	return 1.0 + _talent("nature_woodgrain") / 100.0

func _talent(key: String, field: String = "values") -> float:
	var pd := get_node_or_null("/root/PlayerData")
	return float(pd.talent_value(key, field)) if pd else 0.0

## Blizzard's radius (plus whatever a talent adds: Abilities.RADIUS_TALENTS; none right now).
func blizzard_radius() -> float:
	return float(Abilities.get_resource("blizzard").radius) + Abilities.radius_bonus("blizzard")

## Extra seconds on effects you apply (StatusContainer asks). Deep Hoarfrost.
func effect_duration_bonus(res: Resource) -> float:
	# (Deep Hoarfrost, Long Burn, Lingering Frost, Hard Freeze: one list, shared
	# with the tooltips, so what they say is what happens.)
	return Abilities.effect_time_bonus(res, _talent) + utility.duration_bonus(res) \
		+ brawler.duration_bonus(res)   # (Fixed Point: per Arcane cooldown; Ground Game: Throw and Takedown)

## Extra hits effects you apply take to shake (StatusContainer asks). Pinned Down.
func effect_extra_hits(res: Resource) -> int:
	return int(round(_talent("martial_pinned_down"))) if res != null and str(res.get("id")) == "pinned_shadow" else 0

## Every hit you deal, before its damage is worked out (CombatSystem ->
## SignalBus.damage_modify): talent damage bonuses and threat changes.
func _on_damage_modify(info: RefCounted) -> void:
	if is_same(info.target, self):
		frost_runes._last_hit_by = info.source   # Ice Floe: who broke my shield
		# Numbing Cold: less damage from enemies I slowed recently.
		var dr := _talent("frost_slow_dr")
		if dr > 0.0 and frost_melee._slowed_recently(info.source):
			info.add_bonus(-dr, "Numbing Cold")
		fire_talents._fire_talents_incoming(info)   # Heat Shimmer
		frost_talents._frost_talents_incoming(info)   # Steady Footing
		lightning_talents._lightning_talents_incoming(info)   # Charged Guard, Charged Shell, Hard Stare
		arcane_talents._arcane_talents_incoming(info)   # Glass Dust
		# Heat Sink: part of every hit is stored instead (see _on_hit_taken).
		if status and status.has(FireCooldownsKit.HEAT_SINK_ID):
			info.add_bonus(-Balance.HEAT_SINK_PCT, "Heat Sink")
		# Warm Blood: less damage from an enemy that carries one of my burns.
		var warm := _talent("fire_warm_blood")
		if warm > 0.0 and fire_caster._my_burn_on(info.source):
			info.add_bonus(-warm, "Warm Blood")
		# Brand: an enemy carrying my brand hits me for less.
		if info.source != null and is_instance_valid(info.source) and info.source is Node:
			var brand_st: Node = info.source.get_node_or_null("Status")
			if brand_st and brand_st.has_from(FireTankKit.BRAND_FX_ID, self):
				info.add_bonus(-(Balance.BRAND_PCT + _talent("fire_deep_brand")), "Brand")   # + Deep Brand
		fire_tank._slag_incoming(info)   # Molten Shell
		arcane_tank._reflection_talents_incoming(info)   # Empty Room, Bent Light
		lightning_melee._guard_incoming(info)   # Reflex Arc, Faraday Guard
		strings._crossed_incoming(info) # Crossed Strings: part of it goes to an enemy
		pacts_kit._pact_incoming(info)    # my Pact: more or less damage taken
		nature_open._nature_talents_incoming(info)   # Old Growth
		holy_talents._holy_talents_incoming(info)   # Full Censer
		return
	if info.source != self:
		return
	pacts_kit._pact_outgoing(info)        # my Pact: more or less damage dealt
	holy_talents._holy_talents_outgoing(info)   # Burnished, Censer's Weight, Sunsteel
	# Scatter: the darts of the Sigil Darts it split hit harder.
	if arcane_caster._bolt_tag == ArcaneCasterKit.SCATTER_FX and str(info.ability_id) == ArcaneCasterKit.SIGIL_DARTS_ID:
		info.add_bonus(Balance.SCATTER_PCT, ArcaneCasterKit.SCATTER_LABEL)
	# Crucible: enemies standing in MINE take more periodic Fire damage from me
	# (own only: a party member's Crucible does nothing for my burns).
	if info.is_dot and str(info.damage_type) == "fire" and info.target is Node3D \
			and FireCooldownsKit.CRUCIBLE.covers(get_tree(), info.target, "me"):
		info.add_bonus(Balance.CRUCIBLE_DOT_PCT, "Crucible")
	# Lingering Embers: my periodic Fire damage (burns and burning ground) hits harder.
	if info.is_dot and str(info.damage_type) == "fire":
		var embers := _talent("fire_lingering_embers")
		if embers > 0.0:
			info.add_bonus(embers, "Lingering Embers")
	# Smoldering Focus: my Fire spells hit harder the more Fury I hold.
	if str(info.damage_type) == "fire" and info.tags.has("Spell"):
		var smolder := FireFuryKit.smolder_pct(fire_fury.fury(), _talent("fire_smoldering_focus"))
		if smolder > 0.0:
			info.add_bonus(smolder, "Smoldering Focus")
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
	nature_open._nature_talents_outgoing(info)   # Undergrowth, Overgrown
	martial_talents._martial_talents_outgoing(info)   # Hard Break, Clean Kill, Knockout, Full Draw, Barbed, Turning Wheel
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
	# Practiced Hand: my Arcane abilities hit harder for each Trace I hold.
	if info.tags.has("Arcane") and info.tags.has("Ability") and not info.is_proc and not info.is_dot:
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
	# White Heat: in the White band, the Fire damage of my abilities is higher
	# (the same hits Heat itself boosts: abilities and their burns, never spells).
	if str(info.damage_type) == "fire" and info.tags.has("Ability"):
		var white := FireMeleeKit.white_heat_bonus(fire_melee.band(), _talent("fire_white_heat"))
		if white > 0.0:
			info.add_bonus(white, "White Heat")
	fire_talents._fire_talents_outgoing(info)   # the Fire talents' bonuses (column-group tree)
	frost_talents._frost_talents_outgoing(info)   # the Frost talents' bonuses (column-group tree)
	lightning_talents._lightning_talents_outgoing(info)   # the Lightning talents' bonuses (ribbon tree)
	arcane_talents._arcane_talents_outgoing(info)   # the Arcane talents' bonuses (ribbon tree)
	# Shatterpoint: every shatter hit (tagged "Shatter", whatever its name) hits harder.
	if info.tags.has("Shatter"):
		var sp := _talent("frost_shatterpoint")
		if sp > 0.0:
			info.add_bonus(sp, "Shatterpoint")
	# Chilling Presence: more threat on enemies I slowed recently.
	var tp := _talent("frost_slow_threat")
	if tp > 0.0 and frost_melee._slowed_recently(info.target):
		info.threat_multiplier *= 1.0 + tp / 100.0
	# Menace runes: more threat from damage of their type.
	var rl := get_node_or_null("RuneListener")
	if rl:
		var menace: float = rl.passive_threat_pct(str(info.damage_type))
		if menace > 0.0:
			info.threat_multiplier *= 1.0 + menace / 100.0
	# Leaf Cloak: for a while after it, my damage makes no threat.
	if utility.no_threat():
		info.threat_multiplier = 0.0
	# Splintering: an Ice Shard hitting a Frozen / Rime Shelled enemy splinters
	# (checked before the hit, since the hit may break the shell).
	if id == "iceshards" and not info.is_proc and _talent("frost_splinter") > 0.0 \
			and info.target and is_instance_valid(info.target):
		var sst: Node = info.target.get_node_or_null("Status")
		if sst and (sst.has_from("frozen", self) or sst.has_from("rime_shell_foe", self)):   # mine only (a shell counts for its whole time)
			frost_runes._splinter.call_deferred((info.target as Node3D).global_position, info.target.get_instance_id())
	# Kiln Blast: more damage to a target carrying my Immolate.
	if id == "kilnblast" and info.target and is_instance_valid(info.target):
		var kst: Node = info.target.get_node_or_null("Status")
		if kst and kst.has_from("immolate", self):
			info.add_bonus(Balance.KILN_BLAST_IMMOLATE_PCT, "Kiln Blast")
	# Shatter Shot: more damage to a target I have Frozen (own only).
	if id == FrostBowKit.SHATTER_SHOT_ID:
		frost_bow._shatter_shot_modify(info)
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
	if ability_id == "auto_ranged":
		venomstring.dripping_tips(tgt)   # Dripping Tips
	# Fresh Tinder: melee abilities (not procs, not ticks) may feed my Burning on the target.
	var tinder := _talent("fire_fresh_tinder")
	if tinder > 0.0 and not is_proc and not periodic and Abilities.tags_of(ability_id).has("Ability") \
			and Abilities.tags_of(ability_id).has("Melee") and randf() * 100.0 < tinder:
		fire_melee._feed_burning(tgt)
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
			frost_runes._apply_freeze(tgt, ftags)

# --- Weapon helpers ---------------------------------------------------------------

func _weapon() -> Dictionary:
	var pd := get_node_or_null("/root/PlayerData")
	if pd == null:
		return {}
	return Items.get_item(pd.equipment.get("Main Hand", ""))

func _in_weapon_range(e: Node3D, reach: float) -> bool:
	var d := Vector2(e.global_position.x - global_position.x, e.global_position.z - global_position.z).length()
	return d - Combat.hitbox_radius(e) - Combat.hitbox_radius(self) <= reach

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
	if moving or casting or placing or not is_on_floor() or rogue.playing_dead():   # (Play Dead: no swings)
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
	if auto_windup < LightningMeleeKit.auto_interval(float(w["attack_interval"]), haste_mult(), lightning_melee.overdrive_active(),
			lightning_tank.attack_speed_bonus() + frost_talents.attack_speed_vs(enemy) + lightning_talents.light_load_speed()):   # (Overdrive, Tempo, Quick Rime, Swift Ice, Light Load: faster swings)
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
		_slash_effect(FireMeleeKit.heat_tint(fire_melee.heat_stacks()))   # the swing glows hotter with Heat
	# Auto-attacks and auto-shots build fury when you're playing a fury user.
	if _has_fury_spender():
		_gain("fury", AUTO_ATTACK_FURY + (_talent("fire_hammer_rhythm") if w["weapon"] != "ranged" else 0.0)   # + Hammer Rhythm (auto-swings)
			+ frost_talents.auto_fury(enemy, w["weapon"] == "ranged"))   # + Rime Grip

## Fury per auto-attack / auto-shot (only with a fury spender on the action bar).
const AUTO_ATTACK_FURY := Balance.AUTO_ATTACK_FURY

## A fury-costing ability on your action bar: "on the bar" (not just learned) is
## what says you're actually playing fury.
func _has_fury_spender() -> bool:
	var pd := get_node_or_null("/root/PlayerData")
	if pd == null:
		return false
	for slot_id in pd.action_bar:
		for id in bar_abilities(slot_id):
			if id != "" and Abilities.resource_of(id) == "fury" and Abilities.cost_of(id) > 0:
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
	CastFX.swing_sparks(get_parent(), global_position + _flat_forward() * 0.6 + Vector3(0, 0.3, 0), _flat_forward(), color)

# --- Cast flair (CastFX; pictures only, mirrored to the party via Net) ----------
var _cast_fx: Node3D

## The ability's book color, and whether it is a martial (physical) one.
func _fx_style(id: String) -> Array:
	var cat := Abilities.category_of(id)
	return [Abilities.color_of(id), cat == "martial"] if cat != "" else []

func _cast_fx_start(id: String, duration: float) -> void:
	_cast_fx_end()
	var style := _fx_style(id)
	if style.is_empty():
		return
	_cast_fx = CastFX.start_cast(self, _muzzle, Combat.feet_y(self), style[0])
	_net_fx("castfx", global_position, null, {"c": style[0], "d": duration})

func _cast_fx_end(tell := true) -> void:
	if _cast_fx:
		CastFX.end_cast(_cast_fx)
		_cast_fx = null
		if tell:
			_net_fx("castend", global_position)

func _cast_fx_release(id: String) -> void:
	_cast_fx_end(false)   # (the release ends it on their screens too)
	var style := _fx_style(id)
	if style.is_empty():
		return
	var feet := Vector3(global_position.x, Combat.feet_y(self), global_position.z)
	CastFX.release(get_parent(), _muzzle(), feet, style[0], style[1])
	_net_fx("release", global_position, null, {"c": style[0], "p": style[1]})

func _heal_fx(source: Node, tgt: Node, _amount: int, _effective: int, ability_id: String, _crit: bool) -> void:
	if source != self or not (tgt is Node3D):
		return
	var style := _fx_style(ability_id)
	CastFX.heal_glow(tgt, Combat.feet_y(tgt), style[0] if not style.is_empty() else Color(0.6, 1.0, 0.6))

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

## A party member (or me) becomes my friendly target (a party frame was clicked).
func select_friendly(ally: Node3D) -> void:
	if ally == null or not is_instance_valid(ally):
		return
	_set_target(null)
	friendly_target = null if is_same(ally, self) else ally

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
	var util_err := utility.cast_error(id, target)
	if util_err != "":
		_error(util_err)
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
	elif spell == FrostBowKit.GLACIAL_DRAW_ID:
		duration = FrostBowKit.thin_ice_cast(duration, _talent("frost_thin_ice"), frost_bow._chilled_by_me(target))   # Thin Ice
	elif spell == StringsKit.HOIST_ID:
		duration = StringsKit.heave_cast(duration, strings.strings_on(_cast_target), frost_melee._capstone("shadow_heave"))   # Heave's capstone
	duration = maxf(duration - frost_talents.cold_rush(spell, _cast_target if _cast_kind in ["self", "ally"] else null), 0.2)   # Cold Rush
	if ShadowTalentsKit.deep_call_spell(Abilities.tags_of(spell)):
		duration = StringsKit.deep_call_cast(duration, _talent("shadow_deep_call"), decay.decay_open_on(target))   # Deep Call
	duration = weaver.quickening(spell, duration)   # Quickening
	duration *= arcane_talents.cast_mult(spell)   # Clock Hands
	duration /= haste_mult()
	if Abilities.INSTANT_ON_ALLIES.has(spell) and (_cast_kind in ["self", "ally"] or (spell == "rimeshell" and frost_healer.frost_tide_on())):
		duration = 0.05   # Rime Shell: instant on an ally or me (Frost Tide: on enemies too; released next frame)
	if FrostBowKit.instinct_applies(spell) and frost_bow.frozen_instinct_ready():
		duration = 0.05   # Frozen Instinct: instant (released next frame)
		frost_bow._instinct_cast = true
	fire_cooldowns._conc_cast = not frost_bow._instinct_cast and fire_cooldowns.concentrated_fire_ready(spell)
	if fire_cooldowns._conc_cast:
		duration = 0.05   # Concentrated Fire: instant (released next frame)
	storm_arrow_kit._flicker_cast = not frost_bow._instinct_cast and not fire_cooldowns._conc_cast and bottled_kit.flicker_ready(spell)
	if storm_arrow_kit._flicker_cast:
		duration = 0.05   # Flicker: this Lightning Bolt is instant (released next frame)
	bottled_kit._bottled_cast = not frost_bow._instinct_cast and not fire_cooldowns._conc_cast and not storm_arrow_kit._flicker_cast and bottled_kit.bottled_ready(spell)
	if bottled_kit._bottled_cast:
		duration = 0.05   # Rune of Bottled Lightning: this Discharge is instant (released next frame)
	arcane_talents._unwind_cast = not channel and not frost_bow._instinct_cast and not fire_cooldowns._conc_cast and not storm_arrow_kit._flicker_cast and not bottled_kit._bottled_cast and arcane_talents.unwinding_ready(spell)
	if arcane_talents._unwind_cast:
		duration = 0.05   # Unwinding: this Arcane spell is instant (released next frame)
	storm_arrow_kit._overture_cast = not channel and not frost_bow._instinct_cast and not fire_cooldowns._conc_cast and not storm_arrow_kit._flicker_cast and not bottled_kit._bottled_cast and not arcane_talents._unwind_cast and hymns.overture_ready(spell)
	if storm_arrow_kit._overture_cast:
		duration = 0.05   # Rune of the Overture: the first cast after a boom is instant (used up when it lands)
	# Cinder Step: this cast can be finished on the move (instant ones don't need it).
	fire_cooldowns._cinder_cast = not channel and not fire_cooldowns._conc_cast and not frost_bow._instinct_cast and fire_cooldowns.cinder_step_ready(spell)
	# Glint: this cast or channel can go on while I move (instant ones don't need it).
	arcane_caster._glint_cast = not fire_cooldowns._conc_cast and not frost_bow._instinct_cast and not storm_arrow_kit._flicker_cast and not bottled_kit._bottled_cast and not arcane_talents._unwind_cast \
		and not fire_cooldowns._cinder_cast and not storm_arrow_kit._overture_cast and arcane_caster.glint_ready(spell)
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
	frost_bow._instinct_cast = false   # Frozen Instinct stays for the next Frost spell
	fire_cooldowns._conc_cast = false       # so does the Concentrated Fire stack
	fire_cooldowns._cinder_cast = false     # and Cinder Step's cast on the move
	storm_arrow_kit._flicker_cast = false    # and Flicker's instant Lightning Bolt
	storm_arrow_kit._overture_cast = false   # and the Overture's instant cast
	bottled_kit._bottled_cast = false    # and Bottled Lightning's instant Discharge
	arcane_talents._unwind_cast = false    # and Unwinding's instant cast
	arcane_caster._glint_cast = false      # and Glint's cast on the move
	fire_caster._volley_left = 0         # a broken Ember Volley launches no more embers
	arcane_caster._darts_left = 0          # nor does a broken Sigil Darts launch more darts
	_queued = ""             # a cancelled cast drops whatever was queued behind it
	if casting:
		_bus().cast_interrupted.emit(current_spell)
	casting = false
	current_spell = ""
	current_state = ""

func _release_cast() -> void:
	var spell := current_spell
	var cinder := fire_cooldowns._cinder_cast
	fire_cooldowns._cinder_cast = false
	var glint := arcane_caster._glint_cast
	arcane_caster._glint_cast = false
	casting = false
	current_spell = ""
	current_state = ""
	if spell == "embervolley":
		fire_caster._ember_volley_tick(true)   # the last ember (the channel was paid for when it started)
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
	var conc := fire_cooldowns._conc_cast
	fire_cooldowns._conc_cast = false
	var flick := storm_arrow_kit._flicker_cast
	storm_arrow_kit._flicker_cast = false
	var overture := storm_arrow_kit._overture_cast
	storm_arrow_kit._overture_cast = false
	var bottled := bottled_kit._bottled_cast
	var unwind := arcane_talents._unwind_cast
	arcane_talents._unwind_cast = false
	bottled_kit._bottled_cast = false
	if not _pay(spell):
		frost_bow._instinct_cast = false
		return
	if flick and status:   # Flicker (or Snap Cast): that was its instant Lightning Bolt
		status.remove(LightningCasterKit.FLICKER_FX if status.has(LightningCasterKit.FLICKER_FX) else LightningTalentsKit.SNAP_CAST_FX)
	if overture and status:
		status.remove(HymnsKit.OVERTURE_FX)     # Rune of the Overture: that was its instant cast
	if bottled and status:
		status.remove(BottledLightningKit.BOTTLED_FX)      # Rune of Bottled Lightning: that was its instant Discharge
	if unwind and status:
		status.remove(ArcaneTalentsKit.UNWINDING_FX)      # Unwinding: that was its instant cast
	if conc and status:
		status.spend_stacks(FireCooldownsKit.CONC_ID)   # Concentrated Fire: one stack per instant cast
	if cinder and status:
		status.remove(FireCooldownsKit.CINDER_ID)       # Cinder Step: that was the cast on the move
	if glint and status:
		status.spend_stacks(ArcaneCasterKit.GLINT_FX, 1)   # Glint: so was this (Keep Moving: one of its casts)
	if FrostBowKit.instinct_applies(spell) and (frost_bow._instinct_cast or frost_bow.frozen_instinct_ready()):
		status.remove(FrostBowKit.INSTINCT_ID)   # Frozen Instinct used up (this spell was free)
	frost_bow._instinct_cast = false
	if spell in RezKit.IDS:
		rez_kit.finish(spell)
		return
	if spell == LightstringKit.REFRACTING_SHOT_ID:
		lightstring._loose_refracting_shot()   # Holy archer
		return
	if spell == VenomstringKit.ADDER_ARROW_ID:
		venomstring._loose_adder_arrow()   # Nature archer
		return
	if spell == SharpshooterKit.HEAVY_DRAW_ID:
		sharp._loose_heavy_draw()   # Martial archer
		return
	if spell == FrostBowKit.GLACIAL_DRAW_ID:
		frost_bow._loose_glacial_draw()
		return
	if spell == "walloffire":
		fire_caster._raise_fire_wall()
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
	if spell == FireCooldownsKit.CRUCIBLE_ID:
		fire_cooldowns._place_crucible(false)
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
		_gain(Abilities.resource_of(spell), lightning_talents.spell_energy(float(bolt_res.resource_generated))
			if Abilities.tags_of(spell).has("Lightning") else float(bolt_res.resource_generated))   # (Leaping Arc's Energy, + Feedback)
	if spell == LightningCasterKit.DISCHARGE_ID:
		lightning_caster._discharge(target)
		return
	if spell == LightningCasterKit.FORKED_BOLT_ID:
		bottled_kit._forked_bolt(target)
		return
	if spell in UtilityKit.CASTS:
		utility.finish_cast(spell, target)   # each book's Utility
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
		fire_caster._immolate_spread(target)   # recast on a target that already has mine: it jumps to others
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
	elif id == FireCooldownsKit.CRUCIBLE_ID:
		r = fire_cooldowns.crucible_radius()   # Deep Crucible
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
	frost_melee._scan_my_slows()
	frost_runes._tick_permafrost()
	fire_fury._tick_blowback()
	arcane_caster._tick_countdowns()
	decay._tick_decay()
	overload_kit._tick_grounded()
	dusk_till_dawn._tick_dusk()
	hounds._tick_hounds()
	strings._tick_strings()
	hymns._tick_hymns()
	pacts_kit._tick_pact(_delta)
	bottled_kit._tick_live_wire()
	lightning_melee._tick_overdrive()
	bottled_kit._tick_standing_charge(_delta)
	arcane_tank._tick_reflections()
	censer._tick_censer()
	prism_kit._tick_prisms()
	weaver._tick_weaver()
	shepherd._tick_shepherd()
	frost_healer._tick_frost_healer()
	colossus._tick_colossus()
	glacier._tick_glacier()
	fire_tank._tick_slag()   # Fire tank: brittle Slag, Molten Shell ending
	fire_melee._tick_heat()   # Fire DPS: Blast Furnace keeps Heat
	wheel._tick_wheel()
	brawler._tick_brawler(_delta)
	rogue._tick_rogue(_delta)
	sharp._tick_sharp(_delta)
	martial_talents._tick_martial_talents(_delta)   # Catch Your Breath
	venomstring._tick_venom(_delta)
	utility._tick_utility()
	lightstring._tick_lightstring(_delta)
	_mouseover_tick()
	arcane_melee._tick_traces()
	fire_lightning_talents._tick_dig_in(_delta)
	lightning_talents._tick(_delta)   # Full Circuit, Static Build
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

	# Some casts can be made on the move: tick them here, then fall through to
	# normal movement below. (The instant casts from Concentrated Fire, the one
	# cast Cinder Step lets you finish while moving, whatever Glint lets you cast
	# or channel on the move.)
	var steady := casting and (fire_cooldowns._conc_cast or fire_cooldowns._cinder_cast or storm_arrow_kit._flicker_cast or bottled_kit._bottled_cast
		or arcane_caster._glint_cast or storm_arrow_kit._overture_cast or arcane_talents._unwind_cast)
	if steady:
		var aimed: bool = current_spell in ENEMY_BOLTS or current_spell == "embervolley" \
			or current_spell == FrostBowKit.GLACIAL_DRAW_ID or current_spell == ArcaneCasterKit.SIGIL_DARTS_ID or current_spell == LightstringKit.REFRACTING_SHOT_ID \
			or current_spell == VenomstringKit.ADDER_ARROW_ID or current_spell == SharpshooterKit.HEAVY_DRAW_ID
		if (aimed and not _has_valid_target()) or (current_spell in SUPPORT_CASTS and not _support_target_ok()):
			_cancel_cast()
			steady = false
		else:
			cast_timer -= delta
			if current_spell == "embervolley":
				fire_caster._ember_volley_tick()     # a channel on the move launches as it goes, like one standing still
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
		var targeted: bool = current_spell in ENEMY_BOLTS or current_spell == "embervolley" or current_spell == FrostBowKit.GLACIAL_DRAW_ID \
			or current_spell == LightstringKit.REFRACTING_SHOT_ID or current_spell == VenomstringKit.ADDER_ARROW_ID \
			or current_spell == SharpshooterKit.HEAVY_DRAW_ID or current_spell == ArcaneCasterKit.SIGIL_DARTS_ID
		var lost_target := targeted and not _has_valid_target()
		if current_spell in SUPPORT_CASTS and not _support_target_ok():
			lost_target = true
		if current_spell in RezKit.IDS and not rez_kit.target_ok():
			lost_target = true
		if input_dir.length() > 0.1 or lost_target:
			_cancel_cast()  # moving interrupts the cast / channel
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			var face_at: Vector3 = target.global_position if targeted else cast_point
			if current_spell in SUPPORT_CASTS:
				face_at = _support_face_point()
			elif current_spell in RezKit.IDS:
				face_at = rez_kit.target.global_position
			_face(face_at, delta)
			cast_timer -= delta
			if current_spell == "embervolley":
				fire_caster._ember_volley_tick()
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
	if id == LightningCasterKit.FLICKER_ID and bottled_kit.flicker_back_ready():
		# Flicker pressed again in time: snap back (free, while its cooldown runs).
		var back_err := _drafted_precheck(id, Abilities.get_resource(id), {})
		if back_err != "":
			_error(back_err)
			return
		bottled_kit._flicker_back()
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
	if bool(res.get("forbids_shield")) and has_shield():
		_error("Can't be used with a shield")
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
	cooldowns[id] = Abilities.cooldown_of(res)   # (with talents: Quick Realign)
	if id == LightningCasterKit.STORM_ARROW_ID:
		storm_arrow_kit._storm_arrow_fired(cd_before)   # Loaded Quiver, Snap Shot
	if INTERRUPT_LOCKOUT.has(id):
		# Interrupts share a cooldown: this one never has less than the shared
		# one, and every other interrupt now waits at least that long too.
		cooldowns.merge(interrupt_cooldowns(id, float(res.cooldown), cooldowns), true)
	if id == FireCasterKit.VENT_ID:
		fire_caster._vent_charge_used(float(res.cooldown))   # Hair Trigger: charges instead of one cooldown
	if res.resource_generated > 0:
		_gain(Abilities.resource_of(id), NatureTalentsOpenKit.groundswell_fury(id, ShadowTalentsKit.snarl_fury(id,
			lightning_talents.generated(id, float(Abilities.generated_of(id))), _talent("shadow_snarl")),
			_talent("nature_groundswell")))   # (+ Edge Current, Snarl, Groundswell)
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
		FrostHealerKit.RIME_VEIL_ID, FrostHealerKit.BREAK_ICE_ID, FrostHealerKit.LATTICE_ID, FrostHealerKit.FROST_TIDE_ID, FrostHealerKit.STILLWATER_ID:
			frost_healer._frost_healer_use(id, res)   # Frost healer: Cold Comfort
		ColossusKit.VINE_FIST_ID, ColossusKit.GRASP_ID, ColossusKit.STOMP_ID, ColossusKit.GIANTS_HANDS_ID, ColossusKit.HEARTSAP_ID, ColossusKit.AWAKEN_ID:
			colossus._colossus_use(id, res)   # Nature tank: the Colossus
		GlacierKit.RIME_SLASH_ID, GlacierKit.SHATTER_SLAM_ID, GlacierKit.COLD_SHOULDER_ID, GlacierKit.RIMEQUAKE_ID, \
				GlacierKit.HAILCOAT_ID, GlacierKit.HARD_RIME_ID, GlacierKit.BULWARK_ID:
			glacier._glacier_use(id, res, w)   # Frost tank: Glacier Wall
		FireTankKit.FORGE_BLOW_ID, FireTankKit.RIVET_ID, FireTankKit.MOLTEN_SHELL_ID:
			fire_tank._tank_use(id, res)   # Fire tank: Slagforged
		"searingstrike", "quench", "flare", FireMeleeKit.FOLD_STEEL_ID, FireMeleeKit.RED_EDGE_ID, FireMeleeKit.BLAST_FURNACE_ID:
			fire_melee._melee_use(id, res, w)   # Fire DPS: Forge Heat
		FireBowKit.TOUCH_OFF_ID, FireBowKit.BRUSHFIRE_ID:
			fire_bow._bow_use(id)   # Fire archer: Pitch and Cinder
		FrostSteelKit.HOARCLEAVE_ID, FrostSteelKit.CALVING_ID, FrostSteelKit.BITTER_EDGE_ID, FrostSteelKit.BLACK_FROST_ID:
			frost_steel._steel_use(id, res, w)   # Frost DPS: Frostbitten Steel
		"hack", "chop", "rush", "shrapnel", "slash", "lunge", "bladeguard", "shardlance", \
				"jab", "hook", "dragin", "flyinghead", "thud", "crush", "earthshake", "faultline":
			wheel._wheel_use(id, res)   # Martial warrior: the Wheel
		"punch", "brawlkick", "elbow", "catch", "onemore", "toughitout", "comeon", "fightingstyle":
			brawler._brawler_use(id, res)   # Martial tank: the Brawler
		"cut", "whirl", "dartin", "kickoff", "twinstab", "goin", "closeitout", "hityourstride", "rollwithit", "snatch", \
				"gut", "throughandthrough", "redwhirl", "backflip", "drivethrough", "pintheshadow", "overtheshoulder", "playdead":
			rogue._rogue_use(id, res)   # Martial DPS: the Rogue, and Martial Utility
		"quickshot", "pierce", "spread", "heavydraw", "followup", "loose", "breathe", "fasthands":
			sharp._sharp_use(id, res)   # Martial archer: Sharpshooter
		VenomstringKit.FANG_ARROW_ID, VenomstringKit.ADDER_ARROW_ID, VenomstringKit.ASP_ARROW_ID, VenomstringKit.KRAIT_ARROW_ID, VenomstringKit.VENOM_BURST_ID, VenomstringKit.SPITTING_VOLLEY_ID, VenomstringKit.BLOAT_ARROW_ID, VenomstringKit.COIL_BACK_ID, VenomstringKit.VENOM_SURGE_ID:
			venomstring._venom_use(id, res, w)   # Nature archer: Venomstring
		UtilityKit.ROOTSNARE_ID, UtilityKit.BELLOWS_ID, UtilityKit.DEEP_ROOTS_ID, UtilityKit.STORM_FRONT_ID, UtilityKit.LEAF_CLOAK_ID, \
				UtilityKit.STATIC_SNARE_ID, UtilityKit.FIXED_POINT_ID, UtilityKit.BINDING_RING_ID, UtilityKit.CIRCLE_OF_SILENCE_ID, \
				UtilityKit.CLIMB_STRING_ID:
			utility.use(id, res)   # each book's Utility
		"hoarfrost":
			FROST_BOLT.spawn(get_tree().current_scene, muzzle, target, self, false, id, 0.0)   # Hoarfrost is its on-hit effect
		"iceshards":
			ice_shards_kit._fire_ice_shards(float(res.damage))
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
			frost_bow._start_rimefletch()
		"coldmark":
			frost_bow._coldmark(target)
		"icyretreat":
			frost_bow._icy_retreat(res)
		"flamingarrow", "stormarrow", "arcaneshot", "shadowarrow", "frostarrow", "pitcharrow", "coalshot", "icepin", "shattershot":
			ARROW.spawn(get_tree().current_scene, muzzle, target, self, _weapon_hit(w, res), id)   # (Pitch / Icepin's root are the ability's on-hit effect)
		# --- Frost, second batch ---
		"sleetwave":
			frost_more._sleet_wave(res)
		"deepwinter":
			frost_more._start_deepwinter()
		"snowward":
			frost_more._snow_ward(res)
		"winterhide":
			frost_more._start_winter_hide()
		"rimeedge":
			frost_more._start_rime_edge()
		"icebreaker":
			frost_more._icebreaker(w, res)
		"cinderwing":
			fire_cooldowns._summon_phoenix()
		# Melee abilities
		"froststrike":
			frost_runes._winters_bite(target, _weapon_hit(w, res))
			_slash_effect(Abilities.color_of(id))
			_slash_effect(Abilities.color_of(id))
		"thunderstrike", "arcanestrike", "shadowstrike", \
				"chargededge":
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
			fire_cooldowns._start_cool_head()
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
			for e in fire_tank._enemies_in_cone(float(res.radius), Balance.FURNACE_BREATH_ARC):
				deal_damage(e, float(res.damage), id)
				if breath_net:
					breath_net.interrupt(e, self, breath_lock)   # the host owns enemy casts in a party
				elif is_instance_valid(e) and e.has_method("interrupt"):
					e.interrupt(self, breath_lock)
			_cone_effect(float(res.radius), Balance.FURNACE_BREATH_ARC * 0.5, Abilities.color_of(id))
			_cone_effect(float(res.radius) * 0.6, Balance.FURNACE_BREATH_ARC * 0.5, Color(1.0, 0.9, 0.4))
		"slagskin":
			# The armor comes from Slag stacks (blocks and melee hits, see FireTankKit).
			var slag := StatusContainer.make_buff(FireTankKit.SLAG_ID, "Slag Skin", FireTankKit.SLAG_ID, 0.0,
				Balance.SLAG_SKIN_TIME, 1, Abilities.color_of(id))
			slag.stat_modifiers = {}
			slag.description = "Enemies that attack you are burned. Your blocks and melee hits add Slag."
			status.apply(slag, self)
			fire_tank._sync_slag()   # Slag you already carry lasts as long as the fresh Slag Skin
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
		"cinderguard":
			var guard := StatusContainer.make_buff(FireTankKit.CINDER_GUARD_ID, "Cinder Guard", "block_chance", Balance.CINDER_GUARD_BLOCK,
				Balance.CINDER_GUARD_TIME, 1, Abilities.color_of(id))
			guard.description = "+%d%% chance to block. Attacks you block burn the attacker and extend Slag Skin." % int(Balance.CINDER_GUARD_BLOCK)
			status.apply(guard, self)
			_ring_effect(1.3, Abilities.color_of(id))
		"cinderstep":
			fire_cooldowns._cinder_step(res)
		"heatsink":
			fire_cooldowns._start_heat_sink()
		"ventflames":
			# One instant hit spending my Fury (FireFuryKit); "always crits" is in adjust_crit.
			fire_fury.vent_flames(target, float(res.damage))
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
			arcane_tank._gain_reflections(1)   # (Second Self: _gain_reflections may make one more)
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
			if arcane_tank.reflections() <= 0 and frost_melee._capstone("arcane_on_the_beat"):
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
		# --- Interrupts: stop the target's cast, lock it out of casting ---
		"counterspell", "rimelock", "jolt", "hush":
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
				frost_more._chill(target, id)   # Rimelock also Chills
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
	if FrostHealerKit.INSTANTS.has(id):
		return frost_healer._frost_healer_precheck(id)   # Frost healer
	if ColossusKit.COLOSSUS_IDS.has(id):
		return colossus._colossus_precheck(id)   # Nature tank
	if FireBowKit.BOW_IDS.has(id):
		return fire_bow._bow_precheck(id)   # Fire archer
	if FireTankKit.TANK_IDS.has(id):
		return fire_tank._tank_precheck(id)   # Fire tank
	if GlacierKit.GLACIER_IDS.has(id):
		return glacier._glacier_precheck(id)   # Frost tank
	if FrostSteelKit.STEEL_PRECHECKS.has(id):
		return frost_steel._steel_precheck(id)   # Frost DPS
	if Abilities.CATEGORY_OF.get(id, "") == "martial" and (Abilities.wheel_weapon_of(id) != "" \
			or Abilities.WHEEL_SLOTS.has(id) or Abilities.WHEEL_ORDER.has(id)):
		return wheel._wheel_precheck(id)   # Martial warrior: the Wheel
	if Abilities.ROGUE_IDS.has(id) or Abilities.MARTIAL_UTILITY.has(id):
		return rogue._rogue_precheck(id)   # Martial DPS: the Rogue, and Martial Utility
	if Abilities.BRAWLER_IDS.has(id):
		return brawler._brawler_precheck(id)   # Martial tank: the Brawler
	if Abilities.SHARP_IDS.has(id):
		return sharp._sharp_precheck(id)   # Martial archer: Sharpshooter
	if VenomstringKit.VENOM_INSTANTS.has(id) or id == VenomstringKit.ADDER_ARROW_ID:
		return venomstring._venom_precheck(id)   # Nature archer
	if UtilityKit.INSTANTS.has(id):
		return utility.precheck(id)   # each book's Utility
	match id:
		"blink", "cinderstep", "flicker", "staticstep", "icyretreat":
			if lightning_caster.surge_active():
				return "You can't move during %s" % Abilities.ability_name(LightningCasterKit.SURGE_ID)
		"returnstroke":
			if not LightningTankKit.return_stroke_usable(status.has(LightningTankKit.RETURN_STROKE_FX), frost_melee._has_rune(LightningTankKit.RESONANCE_RUNE)):
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
		"iceshards":
			if ice_shards_kit.shards_firing():
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
		if in_combat:
			fire_talents._on_combat_start()   # Warm Start
			holy_talents._on_combat_start()   # First Light
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

const RIME_SHELL_FX = preload("res://data/effects/rime_shell.tres")
const THAWING_FX = preload("res://data/effects/thawing.tres")
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
	if id == "rimeshell" and frost_healer.frost_tide_on():
		lock_id = ""   # Frost Tide: Rime Shell ignores Thawing
	if id == "flashfreeze" or id == "canticle" or id == "exultation" or id == FrostHealerKit.RIMEFALL_ID:
		return [null, ""]   # (around me: whoever my friendly target is does not matter)
	# Mouseover casting: the ally (or me) under the mouse, if it is a legal target.
	# It comes first, even for Rime Shell with an enemy targeted: allies are preferred.
	if _mo_ally != null and is_instance_valid(_mo_ally) and _mo_ally.is_alive():
		if is_same(_mo_ally, self):
			return [self, "self"]
		if global_position.distance_to(_mo_ally.global_position) <= float(res.cast_range) and can_see(_mo_ally) \
				and not (lock_id != "" and _mo_ally.has_method("has_lockout") and _mo_ally.has_lockout(lock_id)):
			return [_mo_ally, "ally"]
	# Everlasting Rime: Rime Shell can't go on enemies (it goes on your friendly target / you).
	# (A mouseover enemy was swapped into `target` by _mouseover_begin.)
	if id == "rimeshell" and _has_valid_target() and not frost_melee._has_rune("everlasting_rime"):
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
	var everlasting := spell == "rimeshell" and frost_melee._has_rune("everlasting_rime")
	if res and float(res.cooldown) > 0.0 and not everlasting:   # Everlasting Rime: no cooldown
		cooldowns[spell] = float(res.cooldown)
	match spell:
		"rimeshell":
			var absorb: int = int(round(_combat().heal_amount(self, float(Abilities.HEALS["rimeshell"]), "rimeshell") \
				* absorb_mult() * (Balance.EVERLASTING_RIME_MULT if everlasting else 1.0)))
			if kind != "enemy":
				absorb = int(round(absorb * frost_talents.shield_mult(tgt if kind == "ally" else self)))   # Frozen Hearth, Last Shelter
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
						frost_healer.note_shell(tgt, absorb)
						_ring_effect(1.0, Color(0.6, 0.9, 1.0), tgt.global_position)
					elif is_instance_valid(tgt) and tgt.is_alive() and _net():
						_net().shell_ally(tgt, self, absorb, armor, not everlasting)
						tgt.set("has_rime_shell", true)
						tgt.set("rime_shell_by", int(_net().my_id()))   # mine: my Shattering Wave may shatter it
						var locks: Dictionary = tgt.get("lockouts") if tgt.get("lockouts") is Dictionary else {}
						locks["thawing"] = Time.get_ticks_msec() / 1000.0 + float(THAWING_FX.duration)
						tgt.set("lockouts", locks)
						frost_healer.note_shell(tgt, absorb)
						_ring_effect(1.0, Color(0.6, 0.9, 1.0), tgt.global_position)
				_:
					receive_rime_shell(self, absorb, armor, not everlasting)
					frost_healer.note_shell(self, absorb)
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
		"meltwater", "rimefall":
			frost_healer._frost_healer_cast(spell, tgt, kind)   # Frost healer: Cold Comfort

## A shield on me ran out of time: a Rime Shell's caster turns what was left into Runoff.
func _on_my_shield_expired(id: String, left: int, source: Node) -> void:
	if id != "rime_shell" or source == null:
		return
	if source == self:
		frost_healer.shell_runoff(self, left)
	elif _net():
		_net().support_ally(source, self, "rime_runoff", {"left": left})

## Frost Lattice: a hit on my linked Rime Shell cost it only its share; its
## caster takes the rest (`billed`) from the other linked shells.
func _on_my_shield_shared(id: String, billed: int, source: Node) -> void:
	if id != "rime_shell" or source == null:
		return
	if source == self:
		frost_healer.lattice_billed(self, billed)
	elif _net():
		_net().support_ally(source, self, "lattice_bill", {"amount": billed})

## A Rime Shell lands on me (from me or a party member): 20% less damage taken,
## a shield of `amount`, and Thawing. When the shield breaks it shatters
## (the caster deals the damage).
## `armor_pct` = the caster's Hardened Frost; `shatters` = false with the
## caster's Everlasting Rime (the shell breaks without damage).
func receive_rime_shell(caster: Node, amount: int, armor_pct: float = 0.0, shatters: bool = true) -> void:
	if is_dead():
		return
	PlayerKit.SHIELDS.put_rime_shell(status, caster, amount, false, armor_pct, func():
		# Rime Shards: the caster heals the allies near me (Cold Comfort), with or without a shatter.
		if caster == self:
			frost_healer.shell_broke(self, amount)
		elif _net() and is_instance_valid(caster):
			_net().support_ally(caster, self, "rime_broke", {"amount": amount})
		if not shatters:
			return
		if _net():
			_net().request_shatter(caster, global_position)
		elif caster == self:
			shatter_at(global_position))
	status.apply(THAWING_FX, caster)
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
		frost_melee._hit_with_threat(e, coef, id, threat, "frost", PackedStringArray(SHATTER_TAGS))
	_ring_effect(1.2 if only != null else r, Color(0.7, 0.95, 1.0), pos)
	_ring_effect(0.6 if only != null else r * 0.5, Color(1, 1, 1), pos)
	frost_runes._shatterpoint_charge()

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
			PlayerKit.SHIELDS.drop_rime_shield(st, true)
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
		PlayerKit.SHIELDS.drop_rime_shield(status, false)
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
			PlayerKit.SHIELDS.drop_rime_shield(fst, false)
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
	lightning_talents.note_forced(tgt, duration)   # Hard Stare
	nature_open.called_out()   # Called Out
	var net := _net()
	if net:
		net.taunt(tgt, self, duration)
	elif tgt.has_method("taunt"):
		tgt.taunt(self, duration)

# Party members can't see my status effects: tell them when my Rime Shell /
# Thawing changes (their Rime Shell and Shattering Wave need it).
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
		if str(fx["id"]) == "thawing":
			locks["thawing"] = float(fx["remaining"])
	var cracks := RimeShellFx.cracks_for(status.absorb_fraction("rime_shell")) if shell else 0
	var key := "%s|%s|%d|%d" % [shell, locks.has("thawing"), shell_by, cracks]
	if key == _sent_support:
		return
	_sent_support = key
	net.send_support_state(shell, locks, shell_by, cracks)

# --- Auto-target -----------------------------------------------------------------------
# Using something that needs an enemy target while you have none picks the
# closest enemy it could legally be used on: alive, in range and in line of sight
# (and, for Stoke, with your Burning to work on).

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
		if (id == DecayKit.CALL_DUE_ID or id == DecayKit.SPILL_ID or id == DecayKit.TAKE_IT_BACK_ID) and decay.decay_on(e) <= 0.0:
			continue   # (these work on my Decay: an enemy without it is no use)
		var d := global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best:
		_set_target(best)

# --- Crit changes (CombatSystem asks for every hit I deal) ------------------------------

var _empowered := {}   # Cold Precision: ability id -> time its hits stop being empowered

## Fire's crit rules as pure maths (adjust_crit and the tests use this).
## Returns [crit chance, bonus damage %] for a direct hit of ability `id` at a
## crit chance of `chance`, with the Tempered Flame talent's two numbers.
##   Vent Flames: always crits (its Fury bonus is FireFuryKit's).
##   Firebolt + Tempered Flame: `temper_less`% less crit chance, +(crit chance x
##   `temper_bonus`%)% damage. The bonus uses the full crit chance.
##   Ember Volley's embers: `ember_pct` more crit chance (Wild Embers) or less (Damped Embers, negative).
static func fire_crit_rules(id: String, chance: float, temper_less: float = 0.0, temper_bonus: float = 0.0,
		ember_pct: float = 0.0) -> Array:
	var full := clampf(chance, 0.0, 100.0)
	if id == "ventflames":
		return [100.0, 0.0]
	if Abilities.is_a(id, "fireball") and temper_less > 0.0:
		return [chance * (1.0 - temper_less / 100.0), full * temper_bonus / 100.0]
	if id == "embervolley" and ember_pct != 0.0:
		return [maxf(chance + ember_pct, 0.0), 0.0]
	return [chance, 0.0]

func adjust_crit(info: RefCounted, chance: float) -> float:
	var id := str(info.ability_id)
	fire_fury.store_crit(info, chance)   # Fury is worked out from the chance before the changes below
	if id == "permafrost" or id == "stoke" or id == "anvil" or id == "quench" or id == "kilnblast" or id == "forgeblow":
		return 0.0                               # (Stoke, Anvil, Quench, Kiln Blast and Forge Blow never crit)
	if not info.is_dot and (id == "ventflames" or id == "embervolley" or Abilities.is_a(id, "fireball")):
		var ember_pct := _talent("fire_wild_embers") - _talent("fire_damped_embers")
		var fire := fire_crit_rules(id, chance, _talent("fire_tempered_flame"), _talent("fire_tempered_flame", "values2"), ember_pct)
		if float(fire[1]) > 0.0:
			info.add_bonus(float(fire[1]), "Tempered Flame")
		chance = float(fire[0])
	chance = rogue.adjust_crit(info, chance)   # Over the Shoulder (Martial Utility): a sure crit
	chance = sharp.adjust_crit(info, chance)   # Sharpshooter: Heavy Draw at full Streak, a sure crit
	chance = frost_steel.adjust_crit(info, chance)   # Frost DPS: Glinting Rime
	chance = fire_melee.adjust_crit(info, chance)   # Fire DPS: Sparks (no melee crits while holding Heat)
	chance = wheel.adjust_crit(info, chance)   # Sharp Fragments (the Wheel's Cracks)
	if id == LightstringKit.REFRACTION_ID:
		chance += _talent("holy_dazzle")   # Dazzle: my refracted arrows
	var tags: PackedStringArray = info.tags
	if fire_cooldowns.cool_head_active() and FireCooldownsKit.is_fire_action(tags):
		return 0.0                               # Cool Head: no Fire crits at all (ticks and Vent Flames included)
	var frost_spell := tags.has("Frost") and tags.has("Spell")
	if not info.is_dot and float(_empowered.get(id, 0.0)) > Time.get_ticks_msec() / 1000.0:
		chance += 100.0                          # Cold Precision
	if frost_spell and frost_melee._has_rune("permafrost"):
		# Permafrost: no crits; the crit chance becomes extra damage over time.
		info.set_meta("permafrost_pct", clampf(chance, 0.0, 100.0) * Balance.PERMAFROST_CRIT_FACTOR)
		return 0.0
	# Conductive: my Lightning damage crits more often.
	if str(info.damage_type) == "lightning":
		chance += _talent("lightning_conductive")
	chance = lightning_talents.adjust_crit(info, chance)   # Keen Current: auto-attacks
	chance = arcane_talents.adjust_crit(info, chance)   # Keen Cuts
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
	if not is_inside_tree():
		return
	var at := get_viewport().get_mouse_position()
	# A party frame under the mouse: that ally, setting or not (pointing at a
	# frame says who the spell is for).
	var frames := PartyFrames.of(get_tree())
	var framed: Node = frames.member_at(at) if frames != null else null
	if framed != null and not _needs_enemy_target(id) and not PrismsKit.PRISM_TARGET_IDS.has(id):
		_mo_ally = framed
		return
	if not mouseover_on():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
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
		# Spells that go on allies or enemies (Rime Shell): with no ally under the
		# mouse, an enemy under it is used.
		if _mo_ally == null and id == "rimeshell":
			var e: Node3D = _enemy_at(at, cam)
			if e != null and e != target and _target_error(e) == "":
				if not _mo_swapped:
					_mo_prev_target = target
				_mo_swapped = true
				target = e

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

