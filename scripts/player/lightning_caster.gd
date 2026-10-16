extends "res://scripts/player/player_kit.gd"
class_name LightningCasterKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "lightning_caster".
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
	return player.status != null and player.status.has(SURGE_FX)

## An Energy cost with Grounding Surge up (`surging`) or not.
static func surge_energy_cost(cost: float, surging: bool) -> float:
	return cost * (1.0 - Balance.GROUNDING_SURGE_COST_PCT / 100.0) if surging else cost

## Energy left in the bar after an ability spent "all" of `energy`.
static func energy_left_after_all(energy: float, surging: bool) -> float:
	return energy * Balance.GROUNDING_SURGE_KEEP_PCT / 100.0 if surging else 0.0

## Spend all my Energy. Returns what the ability counts as spent: all of it,
## even when Grounding Surge leaves part of it in the bar.
func _spend_all_energy() -> float:
	var have := float(player.resources["energy"])
	player.resources["energy"] = energy_left_after_all(have, surge_active())
	player.lightning_melee._redline()   # (spending all of it is spending Energy too)
	player.bottled_kit._storm_cycle_spent(have - float(player.resources["energy"]))   # Storm Cycle counts what really left the bar
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
	Player.FROST_BOLT.spawn(player.get_tree().current_scene, player._muzzle(), tgt, player, false, DISCHARGE_ID, discharge_coef(spent))

## Ground Out: all my Energy becomes a shield on me. It never stacks, and never
## shrinks a bigger one that is still up.
func _ground_out() -> void:
	var spent := _spend_all_energy()
	var amount := int(round(player._combat().heal_amount(player, ground_out_coef(spent), GROUND_OUT_ID) * player.absorb_mult()))
	if amount <= 0:
		return
	var col := Abilities.color_of(GROUND_OUT_ID)
	var fx := StatusContainer.make_buff(GROUND_OUT_FX, Abilities.ability_name(GROUND_OUT_ID), GROUND_OUT_FX, 0.0,
		Balance.GROUND_OUT_TIME, 1, col)
	var armor := player._talent("frost_shield_armor")   # Hardened Frost: my shields add armor
	fx.stat_modifiers = {"armor%": armor} if armor > 0.0 else {}
	fx.tags = PackedStringArray(["Lightning"])
	fx.description = "A shield of grounded current absorbs damage."
	var total := maxi(int(player.status.absorb_left(GROUND_OUT_FX)), amount)
	if player.status.apply(fx, player):
		player.status.set_absorb(GROUND_OUT_FX, total)
	player._ring_effect(1.3, col)

## Ball Lightning: a cast, then the orb sets off toward my target (if I can see
## it and it is in range) or straight ahead.
func _start_ball_lightning() -> void:
	var id := BALL_LIGHTNING_ID
	if player.casting or not player.is_on_floor():
		return
	if player.cooldown_left(id) > 0.0:
		player._error("%s is not ready yet" % Abilities.ability_name(id))
		return
	if not player.can_afford(id, true):
		return
	var res := Abilities.get_resource(id)
	var dir := player._flat_forward()
	if player._has_valid_target() and player.can_see(player.target) \
			and player.global_position.distance_to(player.target.global_position) <= float(res.cast_range):
		var to := player.target.global_position - player.global_position
		to.y = 0.0
		if to.length() > 0.5:
			dir = to.normalized()
	_ball_dir = dir
	player.cast_point = player.global_position + dir * 5.0   # (what I face while casting)
	player._begin_spell(id, str(res.display_name), float(res.cast_time))

func _launch_ball_lightning() -> void:
	var res := Abilities.get_resource(BALL_LIGHTNING_ID)
	player.cooldowns[BALL_LIGHTNING_ID] = Abilities.cooldown_of(res)
	var at := Vector3(player.global_position.x, Combat.feet_y(player) + BALL_LIGHTNING.FLOAT_HEIGHT, player.global_position.z) + _ball_dir
	var tick := maxf(Balance.BALL_LIGHTNING_TICK / player.haste_mult(), 0.1)   # zaps come faster with Haste
	BALL_LIGHTNING.spawn(player.get_tree().current_scene, at, _ball_dir, player, float(res.damage), float(res.radius),
		Balance.BALL_LIGHTNING_TIME, tick, Balance.BALL_LIGHTNING_SPEED)
	# The party sees the orb; its damage and my Energy come from here.
	player._net_fx(BALL_LIGHTNING_ID, at, null, {"dir": _ball_dir, "r": float(res.radius),
		"time": Balance.BALL_LIGHTNING_TIME, "tick": tick, "speed": Balance.BALL_LIGHTNING_SPEED})

## My Ball Lightning zapped `zaps` enemies: each zap gives Energy back.
func ball_lightning_zapped(zaps: int) -> void:
	if not player.is_dead():
		player._gain("energy", ball_zap_energy(player._talent("lightning_tight_coil")) * maxi(zaps, 0))   # + Tight Coil

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
	var back := player._talent("lightning_conductor")
	if back <= 0.0 or not conductor_applies(str(info.damage_type), bool(info.crit), bool(info.is_proc), bool(info.is_dot), int(info.amount)):
		return
	var key := "%s@%d" % [id, Engine.get_process_frames()]
	if key == _conductor_last:
		return
	_conductor_last = key
	player._gain("energy", back)

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
		player.status.remove(SURGE_FX)
		player._ring_effect(0.8, col)
		return
	if float(player.cooldowns.get(SURGE_ID, 0.0)) > 0.0:
		player._error("%s is not ready yet" % Abilities.ability_name(SURGE_ID))
		return
	var res := Abilities.get_resource(SURGE_ID)
	player.cooldowns[SURGE_ID] = Abilities.cooldown_of(res)
	var fx := StatusContainer.make_buff(SURGE_FX, str(res.display_name), SURGE_FX, 0.0,
		Balance.GROUNDING_SURGE_TIME, 1, col)
	fx.stat_modifiers = {}
	fx.root = true
	fx.tags = PackedStringArray(["Lightning"])
	fx.description = "You cannot move. Your abilities cost %s%% less Energy, and an ability that spends all your Energy leaves you %s%% of it. Use %s again to end it." % [
		Stats.num(Balance.GROUNDING_SURGE_COST_PCT), Stats.num(Balance.GROUNDING_SURGE_KEEP_PCT), str(res.display_name)]
	player.status.apply(fx, player)
	player._ring_effect(1.4, col)
	player._bus().cast_finished.emit(SURGE_ID)

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

