extends "res://scripts/player/player_kit.gd"
class_name OverloadKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "overload_kit".
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
	player.status.apply(_grounded_fx, player)

## A spell or ability of mine started or went off. A Lightning one ends the
## break; coming back after a long enough one, Grounded runs its full time from here.
func _on_cast_for_static(id: String, _duration: float = 0.0) -> void:
	if not Abilities.tags_of(id).has("Lightning"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if player.status and player._has_rune(OVERLOAD_RUNE) and grounds(now - _lightning_cast_at):
		_ground()
	_lightning_cast_at = now

## Twice a second: Grounded is kept up for as long as I stay off Lightning.
func _tick_grounded() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _ground_check_at:
		return
	_ground_check_at = now + 0.5
	if player.status == null or not player._has_rune(OVERLOAD_RUNE):
		return
	if player.casting and Abilities.tags_of(player.current_spell).has("Lightning"):
		_lightning_cast_at = now   # a long Lightning cast or channel is not a break
		return
	if grounds(now - _lightning_cast_at):
		_ground()

func static_stacks() -> int:
	return int(player.status.stacks_of(STATIC_ID)) if player.status else 0

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
	if not player._has_rune(OVERLOAD_RUNE) or player.status.has(OVERLOADED_ID):
		return
	if not builds_static(str(info.damage_type), tags, bool(info.is_proc), bool(info.is_dot), int(info.amount)):
		return
	var key := "%s@%d" % [str(info.ability_id), Engine.get_process_frames()]
	if key == _static_last:
		return   # the same cast hitting another enemy
	_static_last = key
	if _static_fx == null:
		_static_fx = make_static_fx()
	player.status.apply(_static_fx, player)
	if overloads(static_stacks(), player.status.has(GROUNDED_ID)):
		_overload()

## Every stack of Static discharges around me, then the lockout starts.
func _overload() -> void:
	var stacks := static_stacks()
	if stacks <= 0:
		return
	player.status.remove(STATIC_ID)
	if _overloaded_fx == null:
		_overloaded_fx = make_overloaded_fx()
	player.status.apply(_overloaded_fx, player)
	var rune := Runes.get_resource(OVERLOAD_RUNE)
	if rune == null:
		return
	var radius := float(rune.radius)
	var hit := player._enemies_within(radius)
	var coef := overload_coef(stacks, float(rune.effect_amount)) * Balance.aoe_share(hit.size())
	for e in hit:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		# (A proc with its own line on the meter: it builds and spends nothing.)
		var info := DamageInfo.make(player, e, coef, OVERLOAD_RUNE)
		info.tags = rune.effect_tags
		info.damage_type = str(rune.damage_type)
		info.is_proc = true
		info.no_empower = true
		player._combat().deal(info)
	player._ring_effect(radius, OVERLOAD_COLOR)

