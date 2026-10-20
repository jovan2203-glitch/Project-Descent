extends "res://scripts/player/player_kit.gd"
class_name MartialTalentsKit

# Hooked up from player.gd through its var "martial_talents".
# --- Martial: the open talents, and the spec talents that change hits --------------------
# Talents of the Martial book that work with every book's abilities: Conditioning (more
# maximum health: a "stats" bonus in talents.gd) and Catch Your Breath (dropping low
# heals me over time, once a minute). Pinned Down is asked for by StatusContainer
# (Player.effect_extra_hits) and Abilities.effect_time_bonus. Also the spec talents
# that make hits stronger, each with its own bonus (its own damage-meter line): Hard
# Break, Clean Kill, Knockout and Full Draw (Abilities.martial_hit_pct), Barbed (ripped
# out daggers) and Turning Wheel (every hit, per weapon broken lately). Own only.
# Numbers: balance.gd and talents.gd.

const BREATH_ID := "catchyourbreath"   # its heal's meter / log id (Details.HIT_NAMES)
const LABELS := {"martial_hard_break": "Hard Break", "martial_clean_kill": "Clean Kill",
	"martial_knockout": "Knockout", "martial_full_draw": "Full Draw"}

var _breath_ready := 0.0      # when Catch Your Breath can go off again
var _breath_ticks := 0        # its ticks still to come ...
var _breath_per := 0.0        # ... each healing this much
var _breath_next := 0.0

## Catch Your Breath: does dropping to `health` of `max_health` set it off?
static func breath_triggers(health: float, max_health: float, now: float, ready_at: float) -> bool:
	return max_health > 0.0 and health > 0.0 and health / max_health * 100.0 < Balance.CATCH_BREATH_HEALTH_PCT and now >= ready_at

## Catch Your Breath: what each tick heals, `pct` % of `max_health` over its ticks.
static func breath_tick_heal(max_health: float, pct: float) -> float:
	return max_health * maxf(pct, 0.0) / 100.0 / breath_ticks()

static func breath_ticks() -> int:
	return maxi(int(round(Balance.CATCH_BREATH_TIME / Balance.CATCH_BREATH_TICK)), 1)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## A hit of mine, before its damage is worked out (_on_damage_modify).
func _martial_talents_outgoing(info: RefCounted) -> void:
	var id := str(info.ability_id)
	if not bool(info.is_proc):
		var key := Abilities.martial_hit_talent(id)
		if key != "":
			var pct := player._talent(key)
			if pct > 0.0:
				info.add_bonus(pct, str(LABELS[key]))
	if id == RogueKit.RIP_ID:
		var barbed := player._talent("martial_barbed")
		if barbed > 0.0:
			info.add_bonus(barbed, "Barbed")
	var per := player._talent("martial_turning_wheel")
	if per > 0.0:
		var turning := WheelKit.turning_wheel_pct(per, player.wheel.broken_count())
		if turning > 0.0:
			info.add_bonus(turning, "Turning Wheel")

## Every frame: Catch Your Breath starts when I drop low, then heals a tick a second.
func _tick_martial_talents(_delta: float) -> void:
	var now := _now()
	if player.is_dead():
		_breath_ticks = 0
		return
	var pct := player._talent("martial_catch_your_breath")
	if pct > 0.0 and _breath_ticks <= 0 and breath_triggers(float(player.health), float(player.max_health), now, _breath_ready):
		_breath_ready = now + Balance.CATCH_BREATH_COOLDOWN
		_breath_ticks = breath_ticks()
		_breath_per = breath_tick_heal(float(player.max_health), pct) \
			* NatureTalentsOpenKit.green_thumb_mult(BREATH_ID, player._talent("nature_green_thumb"))
		_breath_next = now + Balance.CATCH_BREATH_TICK
		player._ring_effect(1.0, Color(0.55, 1.0, 0.6))
	if _breath_ticks > 0 and now >= _breath_next:
		_breath_ticks -= 1
		_breath_next = now + Balance.CATCH_BREATH_TICK
		player.strings._heal_exact(player, int(round(_breath_per)), BREATH_ID)
