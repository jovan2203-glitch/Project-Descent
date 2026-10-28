extends "res://scripts/player/player_kit.gd"
class_name FireLightningTalentsKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "fire_lightning_talents".
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
	return player._talent("fire_last_ember")

## A hit of mine, before its damage is worked out (_on_damage_modify): Feed the
## Flames, Change of Pace, Dig In.
func _open_talents_modify(info: RefCounted) -> void:
	# Feed the Flames: my direct hits on something carrying one of my damage over time effects.
	if not bool(info.is_dot) and info.target != null and is_instance_valid(info.target) and info.target is Node:
		var feed := player._talent("fire_feed_the_flames")
		if feed > 0.0:
			var st: Node = info.target.get_node_or_null("Status")
			if st != null and st.has_method("has_dot_from") and st.has_dot_from(player):
				info.add_bonus(feed, "Feed the Flames")
	if player.status == null:
		return
	# Change of Pace: for each stack.
	var pace_stacks: int = player.status.stacks_of(PACE_FX)
	if pace_stacks > 0:
		var pace := change_of_pace_pct(player._talent("lightning_change_of_pace"), pace_stacks)
		if pace > 0.0:
			info.add_bonus(pace, "Change of Pace")
	# Dig In: while I stand where I stopped.
	if player.status.has(DIG_IN_FX):
		var dig := player._talent("lightning_dig_in")
		if dig > 0.0:
			info.add_bonus(dig, "Dig In")

## Every hit I deal (_on_damage_dealt_arcane). Spillover: part of a critical
## strike jumps to the nearest other enemy (exact: the crit and every modifier
## are already in it; a proc with its own line on the meter, so it never spills on).
func _spillover_talent(info: RefCounted, id: String, amount: int) -> void:
	if not spills_over(bool(info.crit), bool(info.is_proc), bool(info.is_dot), amount) or not (info.target is Node3D):
		return
	var pct := player._talent("lightning_spillover")
	if pct <= 0.0:
		return
	var from: Vector3 = (info.target as Node3D).global_position
	var near := player._enemies_near(from, Balance.SPILLOVER_RADIUS, info.target)
	if near.is_empty():
		return
	var foe: Node3D = near[0]
	var spill := spillover_amount(amount, pct)
	if spill <= 0:
		return
	# A spark flies from the one that was hit to the one it jumps to.
	var look := id if Abilities.PATHS.has(id) else "lightningbolt"
	Player.FROST_BOLT.spawn(player.get_tree().current_scene, from + Vector3(0, 0.3, 0), foe, null, true, look, 0.0)
	var net := player._net()
	if net:
		net.send_fx("bolt", from + Vector3(0, 0.3, 0), foe, look)
	var damage_type := str(info.damage_type)
	var tags: PackedStringArray = info.tags
	var wait := from.distance_to(foe.global_position) / maxf(Balance.BOLT_SPEED, 1.0)
	player.echo_timer(maxf(wait, 0.02)).timeout.connect(func():
		if player.is_alive():
			player.arcane_caster._exact_hit(foe, spill, SPILLOVER_ID, damage_type, tags))

## Something hit me (_on_hit_taken). Tempered: an attack I blocked gives me Armor for a while.
func _tempered(info: RefCounted) -> void:
	if not bool(info.blocked) or bool(info.is_dot) or player.status == null:
		return
	var pct := player._talent("fire_tempered")
	if pct <= 0.0:
		return
	if _tempered_fx == null or not is_equal_approx(float(_tempered_fx.stat_modifiers.get(Stats.ARMOR + Stats.PCT, 0.0)), pct):
		_tempered_fx = StatusContainer.make_buff(TEMPERED_FX, "Tempered", Stats.ARMOR + Stats.PCT, pct,
			Balance.TEMPERED_TIME, Balance.TEMPERED_STACKS, Color(1.0, 0.6, 0.3))
		_tempered_fx.description = "More Armor from each attack you blocked."
	player.status.apply(_tempered_fx, player)

## I finished casting / using `id` (SignalBus.cast_finished). Change of Pace: a
## different spell or ability than the last one adds a stack; the same one again
## ends it.
func _change_of_pace(id: String) -> void:
	if not Abilities.PATHS.has(id):
		return
	var last := _pace_last
	_pace_last = id
	if player.status == null:
		return
	var per := player._talent("lightning_change_of_pace")
	if per <= 0.0:
		return
	if change_of_pace_after(player.status.stacks_of(PACE_FX), last, id) <= 0:
		player.status.remove(PACE_FX)
		return
	if _pace_fx == null:
		_pace_fx = StatusContainer.make_buff(PACE_FX, "Change of Pace", PACE_FX, 0.0, Balance.CHANGE_OF_PACE_TIME,
			Balance.CHANGE_OF_PACE_STACKS, Color(0.6, 0.8, 1.0))
		_pace_fx.stat_modifiers = {}
		_pace_fx.description = "You deal more damage. Using the same spell or ability twice in a row ends it."
	player.status.apply(_pace_fx, player)   # (one more stack; every stack lasts its full time again)

## Dig In (_process): standing still for a moment digs me in until I move.
func _tick_dig_in(delta: float) -> void:
	if dig_in_moved(_dig_pos, player.global_position):
		_dig_pos = player.global_position
		_dig_still = 0.0
		_dig_asked = false
		if player.status != null and player.status.has(DIG_IN_FX):
			player.status.remove(DIG_IN_FX)
		return
	_dig_still += delta
	if _dig_asked or not dug_in(_dig_still) or player.status == null or not player.is_alive():
		return
	_dig_asked = true   # (the talent is looked up once for each time I stop)
	if player._talent("lightning_dig_in") <= 0.0:
		return
	var fx := StatusContainer.make_buff(DIG_IN_FX, "Dig In", DIG_IN_FX, 0.0, 3600.0, 1, Color(0.6, 0.8, 1.0))
	fx.stat_modifiers = {}
	fx.description = "You deal more damage until you move."
	player.status.apply(fx, player)

