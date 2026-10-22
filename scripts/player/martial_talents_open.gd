extends "res://scripts/player/player_kit.gd"
class_name MartialTalentsKit

# Hooked up from player.gd through its var "martial_talents".
# --- Martial: the open talents, and the spec talents that change hits --------------------
# Talents of the Martial book that work with every book's abilities: Conditioning and
# Footing (stat bonuses in talents.gd), Weapon Training (auto-attacks), Keen Strikes
# (ability crits), Hardy (natural regen: Player._tick_health_regen), Grit (low health)
# and Catch Your Breath (dropping low heals me over time, once a minute). Pinned Down is
# asked for by StatusContainer (Player.effect_extra_hits) and Abilities.effect_time_bonus.
# Also the spec talents that make hits stronger, each with its own bonus (its own
# damage-meter line): the per-move ones (Abilities.martial_hit_talents: Hard Break,
# Heavy Hands, Clean Kill, Finish Strong, Knockout, Heavy Bag, Counter Puncher, Full
# Draw), Barbed (ripped out daggers), the Wheel's (Turning Wheel, Weight Behind It,
# Breaking Point, Clean Swap, Off Balance) and Bad Intentions (chain moves' threat).
# Own only. Numbers: balance.gd and talents.gd.

const BREATH_ID := "catchyourbreath"   # its heal's meter / log id (Details.HIT_NAMES)
const LABELS := {"martial_hard_break": "Hard Break", "martial_heavy_hands": "Heavy Hands",
	"martial_clean_kill": "Clean Kill", "martial_finish_strong": "Finish Strong",
	"martial_knockout": "Knockout", "martial_heavy_bag": "Heavy Bag",
	"martial_counter_puncher": "Counter Puncher", "martial_full_draw": "Full Draw"}
## Effects that mean an enemy is knocked down (Off Balance).
const KNOCKDOWNS := ["knocked_down", "shaken_down", "kicked_down", "taken_down"]

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

## Weight Behind It: % more with `used` uses of the held weapon already taken, `per` % each.
static func weight_pct(used: int, per: float) -> float:
	return float(maxi(used, 0)) * maxf(per, 0.0)

## Grit: does `health` of `max_health` count as low?
static func gritty(health: float, max_health: float) -> bool:
	return max_health > 0.0 and health / max_health * 100.0 < Balance.GRIT_HEALTH_PCT

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## A hit of mine, before its damage is worked out (_on_damage_modify).
func _martial_talents_outgoing(info: RefCounted) -> void:
	var id := str(info.ability_id)
	if not bool(info.is_proc):
		for key in Abilities.martial_hit_talents(id):
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
	if id.begins_with("auto_"):
		var training := player._talent("martial_weapon_training")
		if training > 0.0:
			info.add_bonus(training, "Weapon Training")
	var grit := player._talent("martial_grit")
	if grit > 0.0 and gritty(float(player.health), float(player.max_health)):
		info.add_bonus(grit, "Grit")
	_off_balance(info)
	if not bool(info.is_proc) and not bool(info.is_dot) and info.tags.has("Ability"):
		_wheel_hit(info, id)
	if Abilities.BRAWLER_IDS.has(id) and not Abilities.BRAWLER_STRIKES.has(id):
		var bad := player._talent("martial_bad_intentions")
		if bad > 0.0:
			info.threat_multiplier *= 1.0 + bad / 100.0   # Bad Intentions: the chain moves' threat

## Off Balance: an enemy I knocked down takes more from me.
func _off_balance(info: RefCounted) -> void:
	var pct := player._talent("martial_off_balance")
	if pct <= 0.0 or info.target == null or not is_instance_valid(info.target):
		return
	var st: Node = info.target.get_node_or_null("Status")
	if st == null:
		return
	for fx_id in KNOCKDOWNS:
		if st.has_from(fx_id, player):
			info.add_bonus(pct, "Off Balance")
			return

## The Wheel's talents on an ability hit while my Wheel is out.
func _wheel_hit(info: RefCounted, id: String) -> void:
	var wheel: WheelKit = player.wheel
	if not wheel.is_out():
		return
	var weight := weight_pct(Balance.WHEEL_USES - wheel.uses_left(), player._talent("martial_weight_behind_it"))
	if weight > 0.0:
		info.add_bonus(weight, "Weight Behind It")
	var last := player._talent("martial_breaking_point")
	if last > 0.0 and wheel.takes_last_use(id):
		info.add_bonus(last, "Breaking Point")
	var swap := player._talent("martial_clean_swap")
	if swap > 0.0 and wheel.broke_lately(Balance.CLEAN_SWAP_TIME):
		info.add_bonus(swap, "Clean Swap")

## Keen Strikes: my ability crits hit harder (Player.crit_hit_bonus).
func crit_hit_bonus(info: RefCounted) -> Array:
	var pct := player._talent("martial_keen_strikes")
	if pct <= 0.0 or bool(info.is_dot) or not info.tags.has("Ability"):
		return []
	return [pct, "Keen Strikes"]

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
