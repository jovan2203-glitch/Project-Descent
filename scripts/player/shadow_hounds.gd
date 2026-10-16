extends "res://scripts/player/player_kit.gd"
class_name HoundsKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "hounds".
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
	return _hounds_until > 0.0 and player.status != null and player.status.has(HOUNDS_FX)

## Can my Hounds be on `foe`? Alive, and within their leash of me.
func _prey_ok(foe: Variant) -> bool:   # untyped: may be a freed enemy
	return foe != null and is_instance_valid(foe) and foe is Node3D and foe.is_alive() \
		and player._flat_dist_to((foe as Node3D).global_position) <= Balance.HOUND_LEASH

## An ability of mine went off (_use_drafted, once it was paid for). A Shadow
## melee ability calls the Hounds if none are out; one that cost Rage Rouses
## them (the pair it just called too).
func _hounds_on_ability(id: String) -> void:
	if player.status == null:
		return
	# (A pair whose time ran out since the last frame goes first, so it still
	# drags at its prey before the next one is called.)
	if _hounds_until > 0.0 and not player.status.has(HOUNDS_FX):
		_hounds_gone(hounds_time_up(_hound_now(), _hounds_until))
	if calls_hounds(id) and not hounds_out():
		var res := Abilities.get_resource(id)
		# (They come up at what I am about to strike; with nothing to strike, at heel.)
		_call_hounds(player.target if res != null and res.requires_target and player._has_valid_target() else null)
	if rouses(Abilities.resource_of(id), float(Abilities.cost_of(id))):
		_rouse_hounds()

func _call_hounds(at_prey: Node3D) -> void:
	var time := hound_time(player._talent("shadow_long_night"))   # Long Night
	player.status.apply(make_hounds_fx(), player)
	player.status.set_remaining(HOUNDS_FX, time)   # exactly that long (Overtime does not stretch it)
	var now := _hound_now()
	_hounds_until = now + time
	_hound_prey = at_prey if _prey_ok(at_prey) else null
	# Their first bites come once they are out of the ground, and never both at once.
	var every := _hound_bite_every()
	_hound_bite_at = []
	for i in Balance.HOUND_COUNT:
		_hound_bite_at.append(now + HOUND.RISE_TIME + every * (0.15 + float(i) / Balance.HOUND_COUNT))
	_drop_hound_nodes(false)
	_hound_nodes = HOUND.call_pair(player.get_tree().current_scene, player, _hound_prey, time, false)
	# Take It With You's capstone: the last Drag Down killed, so this pair arrives Roused.
	if _hounds_roused_next:
		_hounds_roused_next = false
		_rouse_hounds()
	# Slipped Leash's capstone: called while Off the Chain is still up, the third comes with them.
	if player.status.has(OFF_THE_CHAIN_FX) and player._capstone("shadow_slipped_leash"):
		_add_third_hound()
	_tell_hounds()

## Seconds between one Hound's bites right now (Haste, Off the Chain, Lean and Hungry).
func _hound_bite_every() -> float:
	return hound_bite_interval(player.haste_mult(), player.status != null and player.status.has(OFF_THE_CHAIN_FX), player._talent("shadow_lean_and_hungry"))

## I spent Rage (_pay, _hounds_on_ability): my Hounds are Roused.
func _rouse_hounds() -> void:
	if not hounds_out():
		return
	if _roused_fx == null:
		_roused_fx = make_roused_fx()
	player.status.apply(_roused_fx, player)

## A hit of mine landed (_on_damage_dealt_shadow, which sees every one): my
## Hounds always go for the last enemy I damaged directly (sets_prey). Of the
## enemies one cast hits at once, my target is the one they take (keeps_prey).
func _hounds_on_hit(info: RefCounted) -> void:
	if _hounds_until <= 0.0:
		return
	var foe: Variant = info.target
	if is_same(foe, player) or not _prey_ok(foe):
		return
	if not sets_prey(bool(info.is_proc), bool(info.is_dot), int(info.amount)):
		return
	var frame := Engine.get_process_frames()
	if not is_same(foe, player.target) and keeps_prey(frame == _hound_prey_frame, _prey_ok(_hound_prey) and is_same(_hound_prey, player.target)):
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
		var from := player.global_position
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
	if player.status == null or not player.status.has(HOUNDS_FX):
		_hounds_gone(hounds_time_up(now, _hounds_until))
		return
	if _hound_prey != null and not _prey_ok(_hound_prey):
		_set_hound_prey(null)   # it died, or is out of their reach: back to heel
	# Slipped Leash's third Hound goes when Off the Chain is over.
	if _hound_bite_at.size() > Balance.HOUND_COUNT and not player.status.has(OFF_THE_CHAIN_FX):
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
	var roused: bool = player.status.has(ROUSED_FX)
	var dealt := _hound_hit(foe, Balance.HOUND_BITE, HOUND_BITE_ID,
		hound_bite_bonuses(roused, st != null and st.has_from(LAID_OPEN_FX, player)),
		worked_up_crit(roused, player._capstone("shadow_worked_up")))
	if i < _hound_nodes.size() and is_instance_valid(_hound_nodes[i]):
		_hound_nodes[i].bite()
	if dealt <= 0:
		return
	# Fed: a bite that critically strikes gives me Rage.
	if _hound_crit:
		player._gain("rage", player._talent("shadow_fed"))
	# Out of the Hole: part of the bite is added to my open Breach under the enemy.
	var hole := player._talent("shadow_out_of_the_hole")
	if hole > 0.0:
		player.decay._decay_feed(foe, hole_feed(dealt, hole))
	# Stand Over: during Guard Dogs every bite gives me health back.
	var stand := player._talent("shadow_stand_over")
	if stand > 0.0 and player.status.has(GUARD_DOGS_FX):
		player._combat().heal(player, player, float(stand_over_heal(player.max_health, stand)), STAND_OVER_ID, true)
	if not player.status.has(RUN_DOWN_FX):
		return
	# An exact share of the bite (its crit and every bonus are already in it),
	# under Run Them Down's own name.
	var share := run_down_amount(dealt)
	var others := 0
	var most := run_down_targets(player._talent("shadow_wide_pack"))   # Wide Pack: more of them
	for e in player._enemies_near(foe.global_position, Balance.RUN_DOWN_REACH, foe):
		if others >= most:
			break
		player._exact_hit(e, share, RUN_DOWN_ID, "shadow", PackedStringArray(HOUND_TAGS))
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
	var info := DamageInfo.make(player, foe, coef, id)
	info.damage_type = "shadow"
	info.tags = PackedStringArray(HOUND_TAGS)
	info.is_proc = true       # runes and "on hit" talents do not fire off it, and Baited Steel does not count it
	info.no_empower = true    # it neither builds nor spends a "your next ..." buff
	if crit_more > 0.0:
		info.set_meta(HOUND_CRIT_META, crit_more)
	for b in bonuses + hound_hit_bonuses(id, player._talent("shadow_pack_leader"), player._talent("shadow_pincer"),
			player._talent("shadow_take_it_with_you")):
		info.add_bonus(float(b[0]), str(b[1]))
	player._combat().deal(info)
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
	var refund := Balance.PINCER_RAGE if player._capstone("shadow_pincer") else 0.0
	for i in _hound_bite_at.size():
		_hound_hit(foe, Balance.HOUND_LUNGE, HOUND_LUNGE_ID)
		if _hound_crit:
			player._gain("rage", refund)
		if i < _hound_nodes.size() and is_instance_valid(_hound_nodes[i]):
			_hound_nodes[i].lunge()
	_tell_hounds(true)

## Run Them Down: everything around me is struck - more than AOE_TARGET_CAP
## enemies share that many hits' damage - and for a while my Hounds' bites reach
## other enemies too (_hound_bite).
func _run_them_down(w: Dictionary, res: Resource) -> void:
	var reach := float(res.radius)
	var hit := player._enemies_within(reach)
	var coef := player._weapon_hit(w, res) * Balance.aoe_share(hit.size())
	for e in hit:
		if is_instance_valid(e) and e.is_alive():
			player.deal_damage(e, coef, RUN_DOWN_ID)
	player.status.apply(make_run_down_fx(run_down_targets(player._talent("shadow_wide_pack"))), player)
	for i in 3:
		player.rotation.y += TAU / 3.0
		player._slash_effect(HOUND_COLOR)
	player._ring_effect(reach, HOUND_COLOR)

func _start_guard_dogs() -> void:
	player.status.apply(make_guard_dogs_fx(), player)
	player._ring_effect(1.4, HOUND_COLOR)
	player._ring_effect(0.9, Abilities.color_of(GUARD_DOGS_ID))

## Off the Chain: my Hounds bite faster, and their time stands still while it
## lasts (they stay that much longer).
func _start_off_the_chain() -> void:
	# (Slipped Leash makes the buff last longer: Abilities.effect_time_bonus.)
	player.status.apply(make_off_the_chain_fx(), player)
	if hounds_out():
		var now := _hound_now()
		_hounds_until = hounds_until_unchained(_hounds_until, now, off_the_chain_time(player._talent("shadow_slipped_leash")))
		player.status.set_remaining(HOUNDS_FX, _hounds_until - now)
		if player._capstone("shadow_slipped_leash"):
			_add_third_hound()
		_tell_hounds()
	player._ring_effect(1.6, HOUND_COLOR)
	player._ring_effect(1.0, Abilities.color_of(OFF_THE_CHAIN_ID))

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
	_hound_nodes.append(HOUND.call_one(player.get_tree().current_scene, player, _hound_prey if _prey_ok(_hound_prey) else null,
		maxf(player.status.remaining_of(OFF_THE_CHAIN_FX), 0.1), false, at))

## Off the Chain is over: the third Hound goes back under, dragging at its prey
## like any Hound whose time is up. The pair stays.
func _third_hound_gone() -> void:
	while _hound_bite_at.size() > Balance.HOUND_COUNT:
		var at := _hound_bite_at.size() - 1
		_hound_bite_at.remove_at(at)
		var drag := player.is_alive() and _prey_ok(_hound_prey)
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
	if not _prey_ok(_hound_prey) and player._has_valid_target() and _prey_ok(player.target):
		_set_hound_prey(player.target)
	var prey: Variant = _hound_prey
	player.status.remove(HOUNDS_FX)
	_hounds_gone(true)
	player._ring_effect(1.2, HOUND_COLOR)
	if _prey_ok(prey):
		player._ring_effect(0.9, HOUND_COLOR, (prey as Node3D).global_position)

## My Hounds are gone. `time_up`: each drags at its prey on the way down.
func _hounds_gone(time_up: bool) -> void:
	var prey: Variant = _hound_prey
	var out := maxi(_hound_bite_at.size(), Balance.HOUND_COUNT)   # (three while Slipped Leash's third is out)
	_hounds_until = 0.0
	_hound_prey = null
	_hound_bite_at = []
	if player.status != null and player.status.has(ROUSED_FX):
		player.status.remove(ROUSED_FX)   # there is nobody left to be Roused
	var drag := time_up and player.is_alive() and _prey_ok(prey)
	if drag:
		_drag_down(prey, out)
	_drop_hound_nodes(drag)
	_hounds_told = _hound_now()
	player._net_fx("hounds", player.global_position, prey if drag else null, {"time": 0.0})

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
	player._net_fx("hounds", player.global_position, _hound_prey if _prey_ok(_hound_prey) else null,
		{"time": maxf(_hounds_until - _hounds_told, 0.1), "lunge": lunge, "count": maxi(_hound_bite_at.size(), Balance.HOUND_COUNT)})

