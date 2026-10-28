extends "res://scripts/player/player_kit.gd"
class_name ArcaneOpenTalentsKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "arcane_open".
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
	return overtime_mult(player._talent("arcane_overtime"))

## Every hit I deal (_on_damage_dealt_arcane). Echo: it may be repeated a moment
## later (exact: its crit and every modifier are already in it; a proc with its
## own line on the meter, so it feeds nothing and is never repeated itself).
func _echo_talent(info: RefCounted, id: String, amount: int) -> void:
	var pct := player._talent("arcane_echo")
	if pct <= 0.0 or not echoes(info.tags, bool(info.is_proc), bool(info.is_dot), Abilities.PATHS.has(id)):
		return
	var arcane: bool = info.tags.has("Arcane")
	if randf() * 100.0 >= echo_chance(pct, arcane):
		return
	var foe: Node = info.target
	var again := ArcaneCasterKit.echo_amount(amount, echo_share(arcane))
	var damage_type := str(info.damage_type)
	var tags: PackedStringArray = info.tags
	player.echo_timer(Balance.ECHO_DELAY).timeout.connect(func():
		if not player.is_alive() or not is_instance_valid(foe) or not foe.is_alive():
			return
		player.arcane_caster._exact_hit(foe, again, ECHO_ID, damage_type, tags)
		if foe is Node3D:
			player._ring_effect(0.4, Color(0.8, 0.6, 1.0), (foe as Node3D).global_position))

func _counts_for_borrowed_time(id: String) -> bool:
	if not _long_cooldowns.has(id):
		var res := Abilities.get_resource(id)
		_long_cooldowns[id] = res != null and borrowed_time_counts(float(res.cooldown))
	return bool(_long_cooldowns[id])

## Cooldowns have just ticked (_tick_cooldowns). Borrowed Time: one of my long
## cooldowns coming back makes my next spell or ability hit harder.
func _tick_borrowed_time() -> void:
	if player.cooldowns.is_empty() and _borrowed_watch.is_empty():
		return
	var pct := player._talent("arcane_borrowed_time")
	if pct <= 0.0:
		_borrowed_watch.clear()
		return
	for id in player.cooldowns:
		if not _borrowed_watch.has(id) and _counts_for_borrowed_time(str(id)):
			_borrowed_watch[id] = true
	var back := false
	for id in _borrowed_watch.keys():
		if not player.cooldowns.has(id):
			_borrowed_watch.erase(id)
			back = true
	if back and player.status != null and player.is_alive():
		var fx := StatusContainer.make_buff(BORROWED_FX, "Borrowed Time", BORROWED_FX, 0.0, Balance.BORROWED_TIME_TIME, 1,
			Color(0.8, 0.6, 1.0))
		fx.stat_modifiers = {}
		fx.description = "Your next spell or ability deals more damage."
		player.status.apply(fx, player)

## A hit of mine, before its damage is worked out (_on_damage_modify). Borrowed
## Time: the first spell or ability I hit with uses the boost, and every hit of
## that one use gets it (BORROWED_TIME_HITS seconds: it may hit several enemies).
func _borrowed_time_hit(info: RefCounted, id: String) -> void:
	if bool(info.is_proc) or bool(info.is_dot) or not Abilities.PATHS.has(id):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if player.status != null and player.status.has(BORROWED_FX):
		player.status.remove(BORROWED_FX)
		_borrowed_id = id
		_borrowed_until = now + Balance.BORROWED_TIME_HITS
	elif id != _borrowed_id or now > _borrowed_until:
		return
	var pct := player._talent("arcane_borrowed_time")
	if pct > 0.0:
		info.add_bonus(pct, "Borrowed Time")

## Something hit me (_on_hit_taken). Mirror Finish: an attack I dodged, parried
## or blocked hurts whoever made it (a proc with its own line on the meter).
func _mirror_finish(info: RefCounted) -> void:
	if bool(info.is_dot) or not (bool(info.dodged) or bool(info.parried) or bool(info.blocked)):
		return
	var coef := player._talent("arcane_mirror_finish")
	if coef <= 0.0:
		return
	var foe: Variant = info.source
	if foe == null or not is_instance_valid(foe) or not (foe is Node) or not foe.is_in_group("enemies") or not foe.is_alive():
		return
	var back := DamageInfo.make(player, foe, coef, MIRROR_FINISH_ID)
	back.tags = PackedStringArray(MIRROR_FINISH_TAGS)
	back.damage_type = "arcane"
	back.is_proc = true
	back.no_empower = true
	player._combat().deal(back)

## I used ability `id` (_use_drafted). Slipstream: after a blink or dash I move faster.
func _slipstream(id: String) -> void:
	if not (SLIPSTREAM_MOVES.has(id) or Abilities.tags_of(id).has("Movement")) or player.status == null:
		return
	var faster := player._talent("arcane_slipstream")
	if faster <= 0.0:
		return
	var fx := StatusContainer.make_buff(SLIPSTREAM_FX, "Slipstream", "move_speed", faster, Balance.SLIPSTREAM_TIME, 1,
		Color(0.8, 0.6, 1.0))
	fx.description = "You move faster."
	player.status.apply(fx, player)

