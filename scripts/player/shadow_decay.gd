extends "res://scripts/player/player_kit.gd"
class_name DecayKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "decay".
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
	var speed := maxf(haste, 0.1) * (Balance.GNAW_SPEED_MULT if fast else 1.0) * ShadowTalentsKit.dot_speed_with(1.0, wasting_pct)   # Wasting
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
	return player.status != null and player.status.has(INTEREST_FX)

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
	var rl := player.get_node_or_null("RuneListener")
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
	player._net_fx("claws", at, null, {"r": radius, "n": count, "h": height})
	BREACH_FX.burst(player.get_tree().current_scene, at, radius, count, height)

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
	return player.damage_unit() + Stats.power_bonus(PackedStringArray(SHADOW_TAGS), player.get_stat)

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
			"next": _decay_now() + decay_interval(player.haste_mult(), false, player._talent("shadow_wasting")),
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
	if not is_same(info.source, player) or info.avoided() or int(info.amount) <= 0:
		return
	player._pact_acted(info)    # Pact of the Relentless: I hit something
	player._dusk_on_hit(info)   # Dusk till Dawn: any Shadow damage of mine starts Dusk
	player.hounds._hounds_on_hit(info)   # Shadow melee: my Hounds go for the enemy I last struck
	var foe: Variant = info.target
	if not _decay_usable(foe):
		return
	player.shadow_talents._note_first_hit(foe)   # Inevitable counts from my first damage to it
	var id := str(info.ability_id)
	if id == BLIGHT_ID and not bool(info.is_proc):
		_open_decay(foe, blight_open_time(player._has_rune(OPEN_WOUND_RUNE)))
	if CLAW_HITS.has(id) and not bool(info.is_proc) and not bool(info.is_dot):
		_claws_at(foe, int(CLAW_HITS[id][0]), float(CLAW_HITS[id][1]))   # what the spell looks like as it lands
	if _decay.is_empty():
		return
	var pct := decay_feed_pct(id, info.tags, bool(info.is_proc), bool(info.is_dot),
		player._talent("shadow_tainted_steel"), rot_rune_pct(_rune_count(ROT_RUNE)))
	if pct <= 0.0:
		pct = seep_feed_pct(id, player._talent("shadow_seep"))   # Seep: Wither's ticks add to it too
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
		player._apply_effect_hit(foe, preload("res://scripts/core/effects.gd").get_effect(want), DECAY_HIT_ID,
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
	var net := player._net()
	if net:
		net.remove_effect(foe, player, fx_id)
	else:
		var st: Node = (foe as Node).get_node_or_null("Status")
		if st:
			st.remove_from(fx_id, player)

## Make my debuff `fx_id` on `foe` show `seconds` left (the open time).
func _decay_effect_time(foe: Variant, fx_id: String, seconds: float) -> void:
	var net := player._net()
	if net:
		net.set_effect_remaining(foe, player, fx_id, seconds)
	else:
		var st: Node = (foe as Node).get_node_or_null("Status")
		if st:
			st.set_remaining_from(fx_id, player, seconds)

## Make my debuff `fx_id` on `foe` show `stacks` (the amount).
func _decay_effect_stacks(foe: Variant, fx_id: String, stacks: int) -> void:
	var net := player._net()
	if net:
		net.set_effect_stacks(foe, player, fx_id, stacks)
	else:
		var st: Node = (foe as Node).get_node_or_null("Status")
		if st:
			st.set_stacks_from(fx_id, player, stacks)

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
	var hit := DamageInfo.make(player, foe, 1.0, id)
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
	player._combat().deal(hit)

## Every frame: my Decays tick, close, and move on when their enemy dies.
func _tick_decay() -> void:
	if _decay.is_empty() or player.is_dead():
		return
	var now := _decay_now()
	var haste := player.haste_mult()
	var endless: bool = player.status != null and player.status.has(BOTTOMLESS_FX)   # Bottomless: ticks take nothing out
	var hold := _bottomless_until if endless and player._capstone("shadow_no_floor") else 0.0   # No Floor: it can't close either
	var wasting := player._talent("shadow_wasting")
	var slow_death := player._talent("shadow_slow_death")
	var rot_through := player._talent("shadow_rot_through")
	var long_fall := player._has_rune(LONG_FALL_RUNE)
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
				player._ring_effect(1.5, Abilities.color_of(CALL_DUE_ID), (foe as Node3D).global_position)
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
			var bite := bite_down_crit(fast, player._talent("shadow_bite_down"))   # Bite Down: more crits during Gnaw
			var amount := float(d["amount"])
			if decay_last_drop(amount, now < float(d["open"]), unit):
				_end_decay(int(key))
				# The last drop: all that is left (Bitter End: and more).
				_decay_hit(foe, amount, DECAY_HIT_ID, true,
					decay_tick_bonuses(slow_death, rot_through, player._talent("shadow_bitter_end"), true), bite)
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
	var kin := player._talent("shadow_next_of_kin")   # Next of Kin: more than what was left moves on
	var heirs := 2 if player._capstone("shadow_next_of_kin") else 1   # ... and a second enemy gets part of it
	var given := 0
	for e in player._enemies_near(at, Balance.DECAY_JUMP_RADIUS):   # (nearest first)
		if not _decay_usable(e):
			continue
		_decay_add(e, kin_amount(left, kin, given > 0), float(d["open"]))
		player._ring_effect(0.7, Abilities.color_of(BLIGHT_ID), (e as Node3D).global_position)
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
	if player.casting:
		return
	var free := interest_ready()
	if not free and float(player.cooldowns.get(BLIGHT_ID, 0.0)) > 0.0:
		player._error("%s is not ready yet" % Abilities.ability_name(BLIGHT_ID))
		return
	if not player._has_valid_target():
		player._error("No target")
		return
	if not player.target_in_range(BLIGHT_ID):
		player._error("Target out of range")
		return
	var sight_err := player._target_error(player.target)
	if sight_err != "":
		player._error(sight_err)
		return
	if not player._pay(BLIGHT_ID):
		return
	if free:
		player.status.remove(INTEREST_FX)
	else:
		player.cooldowns[BLIGHT_ID] = Balance.OPEN_WOUND_COOLDOWN
	var dir := player.target.global_position - player.global_position
	player.rotation.y = atan2(-dir.x, -dir.z)
	Player.FROST_BOLT.spawn(player.get_tree().current_scene, player._muzzle(), player.target, player, false, BLIGHT_ID,
		float(Abilities.get_resource(BLIGHT_ID).damage))
	player._bus().cast_finished.emit(BLIGHT_ID)

## Call Due: all of my Decay on the target at once, and a little more. It ends it.
func _call_due() -> void:
	var foe := player.target
	var amount := decay_on(foe)
	var was_open := decay_open_on(foe)
	# Small Change: part of it stays on the target (open for as long as it still was).
	var left := call_due_left(amount, player._talent("shadow_small_change"))
	if left > 0.0 and _decay.has(foe.get_instance_id()):
		var d: Dictionary = _decay[foe.get_instance_id()]
		d["amount"] = left
		d["dirty"] = true
		d["sync"] = 0.0
	else:
		_end_decay(foe.get_instance_id())
	player._ring_effect(1.3, Abilities.color_of(CALL_DUE_ID), foe.global_position)
	_claws_at(foe, 8, 1.15)   # every hand at once, over its head
	_decay_hit(foe, call_due_damage(amount, player._talent("shadow_interest")), CALL_DUE_ID, false)   # Interest: more on top
	# Interest's capstone: taking out an open Decay makes my next Blight instant.
	if was_open and player._capstone("shadow_interest"):
		var fx := StatusContainer.make_buff(INTEREST_FX, "Interest", INTEREST_FX, 0.0, Balance.INTEREST_TIME, 1,
			Abilities.color_of(BLIGHT_ID))
		fx.stat_modifiers = {}
		fx.tags = PackedStringArray(["Shadow"])
		fx.description = "Your next %s is instant." % Abilities.ability_name(BLIGHT_ID)
		player.status.apply(fx, player)

## Gnaw: a small hit, and my Decay on the target ticks faster for a while.
func _gnaw(res: Resource) -> void:
	var foe := player.target
	player.deal_damage(foe, float(res.damage), GNAW_ID)   # (the hands at its feet: CLAW_HITS)
	if not is_instance_valid(foe) or not _decay.has(foe.get_instance_id()):
		return
	var d: Dictionary = _decay[foe.get_instance_id()]
	var now := _decay_now()
	d["fast"] = now + Balance.GNAW_TIME
	d["next"] = minf(float(d["next"]), now + decay_interval(player.haste_mult(), true, player._talent("shadow_wasting")))   # the faster ticks start now

## Spill: the enemies around `foe` a copy of its Decay goes to.
func _spill_targets(foe: Node3D) -> Array:
	var out: Array = []
	for e in player._enemies_near(foe.global_position, Balance.SPILL_RADIUS, foe):
		if out.size() >= Balance.SPILL_TARGETS:
			break
		if _decay_usable(e):
			out.append(e)
	return out

## Spill: part of my Decay on the target is copied onto the enemies around it.
func _spill() -> void:
	var foe := player.target
	var d: Dictionary = _decay.get(foe.get_instance_id(), {})
	if d.is_empty():
		return
	var share := spill_amount(float(d["amount"]), player._talent("shadow_running_over"))   # Running Over: bigger copies
	var open_until := spill_open_until(float(d["open"]), _decay_now(), player._capstone("shadow_running_over"))
	var col := Abilities.color_of(SPILL_ID)
	player._ring_effect(1.2, col, foe.global_position)
	_claws_at(foe, 4, 0.5)
	for e in _spill_targets(foe):
		_decay_add(e, share, open_until)
		_claws_at(e, 3, 0.4)   # the ground gives way under each of them

## Take It Back: part of my Decay on the target comes off it and shields me.
func _take_it_back() -> void:
	var foe := player.target
	var d: Dictionary = _decay.get(foe.get_instance_id(), {})
	if d.is_empty():
		return
	var taken := take_back_amount(float(d["amount"]))
	d["amount"] = float(d["amount"]) - taken
	d["dirty"] = true
	var col := Abilities.color_of(TAKE_IT_BACK_ID)
	_claws_at(foe, 3, 0.5)
	player._ring_effect(1.3, col)
	var amount := int(round(taken * player.absorb_mult()))   # (Rime Ward: like every shield I put up)
	if amount <= 0:
		return
	var fx := StatusContainer.make_buff(TAKE_IT_BACK_FX, Abilities.ability_name(TAKE_IT_BACK_ID), TAKE_IT_BACK_FX, 0.0,
		Balance.TAKE_IT_BACK_TIME, 1, col)
	var armor := player._talent("frost_shield_armor")   # Hardened Frost: my shields add armor
	fx.stat_modifiers = {"armor%": armor} if armor > 0.0 else {}
	fx.tags = PackedStringArray(["Shadow"])
	fx.description = "A shield absorbs damage."
	if player.status.apply(fx, player):
		player.status.set_absorb(TAKE_IT_BACK_FX, amount)

## Bottomless: for a while my Decay does not shrink when it ticks (see _tick_decay).
## No Floor makes it last longer, and (its capstone) keeps my open Decays open.
func _start_bottomless() -> void:
	var col := Abilities.color_of(BOTTOMLESS_ID)
	var seconds := bottomless_time(player._talent("shadow_no_floor"))
	var fx := StatusContainer.make_buff(BOTTOMLESS_FX, Abilities.ability_name(BOTTOMLESS_ID), BOTTOMLESS_FX, 0.0,
		seconds, 1, col)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Shadow"])
	fx.description = "Your Breach does not shrink when it deals its damage."
	if player._capstone("shadow_no_floor"):
		fx.description += " It cannot close."
	player.status.apply(fx, player)
	_bottomless_until = _decay_now() + seconds
	player._ring_effect(1.4, col)
	player._ring_effect(0.7, Color(0.1, 0.04, 0.15))

## Hush's own hit, and what it adds to an open Decay when there was a cast to stop.
func _hush(foe: Node3D, coef: float, stopped: bool) -> void:
	# Cut Short: stopping a cast takes time off its cooldown (which was just set).
	if stopped and player.cooldowns.has(HUSH_ID):
		player.cooldowns[HUSH_ID] = cut_short_cooldown(float(player.cooldowns[HUSH_ID]), player._talent("shadow_cut_short"))
	if not is_instance_valid(foe) or not foe.is_alive():
		return
	player.deal_damage(foe, coef, HUSH_ID)
	if stopped and is_instance_valid(foe) and foe.is_alive():
		_decay_feed(foe, hush_decay(_decay_unit()))

# Smother (ability id "pall": the name it was first given): ground-targeted,
# like Collapse. When the cast finishes, every enemy in
# the circle is hit (and each one's open Decay gets its share of that hit).

func _start_pall(point: Vector3) -> void:
	if player.casting or not player.is_on_floor():
		return
	player.cast_point = point
	if not player.can_afford(PALL_ID, true):
		return
	var res := Abilities.get_resource(PALL_ID)
	player._begin_spell(PALL_ID, str(res.display_name), float(res.cast_time))

func _cast_pall() -> void:
	var res := Abilities.get_resource(PALL_ID)
	player.cooldowns[PALL_ID] = Abilities.cooldown_of(res)
	var at := player.cast_point
	var r := float(res.radius)
	var col := Abilities.color_of(PALL_ID)
	player._ring_effect(r, col, at + Vector3(0, 0.9, 0))
	_claws(at, r, 18, 1.3)   # a field of hands
	var hit := player._enemies_near(at, r)
	var share := float(res.damage) * Balance.aoe_share(hit.size())
	for e in hit:
		if is_instance_valid(e) and e.is_alive():
			player.deal_damage(e, share, PALL_ID)

