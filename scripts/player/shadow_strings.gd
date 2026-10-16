extends "res://scripts/player/player_kit.gd"
class_name StringsKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "strings".
# --- Shadow healer: the Strings ---------------------------------------------------------------
# A demon floats behind me and holds my allies up on puppet Strings. It has
# STRING_MAX of them, for allies and enemies together. Each one is in my hand
# (a charge of the String ability), tied to someone, or used up and recovering.
#   On an ally   it heals every second (faster with Haste) for STRING_TIME
#                seconds. Up to STRING_STACKS go on one ally; tying another
#                starts the time of all of them over.
#   On an enemy  it lasts STRING_ENEMY_TIME seconds and is crossed with the ally
#                I tied last: part of the damage that ally takes is dealt to the
#                enemy instead (Crossed Strings), while the two are close enough.
#   Shared       a spell or ability of mine that heals an ally on a String also
#                heals every other ally on one for a share (heal_done).
#   Coming back  a String that runs its time, or whose target dies or gets out
#                of reach, is back in my hand at once. One I use up (tied to an
#                ally who is full, pulled taut) recovers STRING_RECHARGE seconds
#                later, one after the other. So letting them run out is free and
#                keeping everyone covered without a gap is not.
# Everything is decided here, on the healer's machine: who holds how many, when
# they end, every heal. A party member is told through Net.support_ally (their
# Player.receive_support): heals, the buff that shows their Strings, the share
# of damage that is crossed away (they report it back as "cross_dmg" and I deal
# it), shields, Still Standing and Yank. A friendly dummy is handled right here.
# Cat's Cradle ties loose Strings: they heal and count as "on a String" but are
# none of my STRING_MAX. Double Thread's second String is free in the same way.
# The demon and the threads are scripts/puppeteer.gd (only a picture); the
# party sees them through the "strings" fx. Numbers: balance.gd (STRING_*, ...).

const PUPPETEER = preload("res://scripts/puppeteer.gd")
const STRING_ID := "puppetstring"
const PATCH_UP_ID := "patchup"
const HOIST_ID := "hoist"
const TUG_ID := "tug"
const CRADLE_ID := "catscradle"
const WRENCH_ID := "wrench"
const PULL_TAUT_ID := "pulltaut"
const CUPPED_HANDS_ID := "cuppedhands"
const STRING_UP_ID := "stringup"
const RESTRING_ID := "restring"
const KNOT_ID := "knot"
const TANGLE_ID := "tangle"
const YANK_ID := "yank"
const DOUBLE_THREAD_ID := "doublethread"
const BEHIND_ID := "behinditsback"
const SLACK_ID := "slack"
const STILL_STANDING_ID := "stillstanding"
const CUT_STRINGS_ID := "cutthestrings"
const NOT_FINISHED_ID := "notfinished"
## The kit's instant abilities (Patch Up and Hoist are cast like Heal: SUPPORT_CASTS).
const STRING_INSTANTS := [STRING_ID, TUG_ID, CRADLE_ID, WRENCH_ID, PULL_TAUT_ID, CUPPED_HANDS_ID, STRING_UP_ID, RESTRING_ID,
	KNOT_ID, TANGLE_ID, YANK_ID, DOUBLE_THREAD_ID, BEHIND_ID, SLACK_ID, STILL_STANDING_ID, CUT_STRINGS_ID, NOT_FINISHED_ID]
## Heals of mine that are never shared along the Strings: the Strings' own, and
## the ones that already reach everybody.
const STRING_NO_SHARE := [STRING_ID, CRADLE_ID, PULL_TAUT_ID, CUT_STRINGS_ID]
## Meter / log ids (Details.HIT_NAMES): the shared heal, and the damage Crossed Strings moves to an enemy.
const STRING_SHARE_ID := "string_share"
const CROSSED_ID := "crossed_strings"
const CROSSED_LABEL := "Crossed Strings"
## Talents: First Stitch's heal and Long Drop's hit (meter ids), Full Harness (the name of what it takes off a hit), Lean On Me (its buff).
const FIRST_STITCH_ID := "first_stitch"
const LONG_DROP_ID := "long_drop"
const FULL_HARNESS_LABEL := "Full Harness"
const LEAN_ON_ME_FX := "lean_on_me"
const STRING_BUFF := "on_a_string"          # what someone on a String carries: it shows how many, and for how long
const DOUBLE_THREAD_FX := "double_thread"
const BEHIND_FX := "behind_its_back"
const SLACK_FX := "slack"
const CUPPED_HANDS_FX := "cupped_hands"
const STILL_STANDING_FX := "still_standing"
const HELD_UP_FX := "held_up"
const STRUNG_UP_FX := "strung_up"           # data/effects/strung_up.tres
const TANGLED_FX := "tangled"               # data/effects/tangled.tres
const STRING_TAGS := ["Shadow", "Spell"]
const STRING_COLOR := Color(0.93, 0.86, 1.0)
const NOT_ON_STRING := "That ally is not on one of your Strings"
const NO_STRING_THERE := "That ally has none of your Strings"
const NO_STRINGS_OUT := "You have no Strings placed"
## Seconds between reminders to the party (and to everyone on a String) of where my Strings are.
const STRINGS_RETELL := 3.0
## Seconds a new String waits for its ally to be on its feet (Not Finished With You: the revive is on its way).
const STRING_GRACE := 2.5

var _strings := {}              # target instance id -> entry (see _string_entry)
var _string_order: Array = []   # target instance ids, one for each String tied, oldest first (Restring takes the last)
var _string_last_ally := 0      # instance id of the ally I tied last: an enemy's String is crossed with it
var _string_spent := 0          # Strings used up and recovering
var _string_recover_at := 0.0   # when the next of them is back
var _slack_until := 0.0         # Slack: no String heals before this
var _strings_dirty := false
var _strings_shown := false
var _strings_told := 0.0
var _string_fx: Resource
# The other end: Strings somebody (I myself, or a party member) has on me.
var _strung := {}               # caster instance id -> {"from": Node, "cross": percent, "until": time}
var _cross_owed := {}           # caster instance id -> damage crossed away from me that they still have to hear of
var _cross_told := 0.0
var _stand_until := 0.0         # Still Standing on me: a killing blow before this is held off
var _stand_hold := 0.0          # ... for this long
var _stand_pct := 0.0           # ... and I need this share of health at the end of it
var _held_until := 0.0          # the Strings are holding me up until then (I cannot die)

## Strings in my hand with `placed` of my own tied somewhere and `spent` recovering.
static func strings_in_hand(placed: int, spent: int) -> int:
	return maxi(Balance.STRING_MAX - maxi(placed, 0) - maxi(spent, 0), 0)

## The String ability's global cooldown: a share of a normal one.
static func string_gcd(gcd: float) -> float:
	return gcd * Balance.STRING_GCD_MULT

# What the healer's talents change (talents.gd, Shadow: "the Strings").

## Seconds a String on an ally lasts (`longer`: Long Thread).
static func string_time_with(longer: float) -> float:
	return Balance.STRING_TIME + maxf(longer, 0.0)

## Seconds a used-up String takes to come back (`sooner`: Spare Spool).
static func string_recharge(sooner: float) -> float:
	return maxf(Balance.STRING_RECHARGE - maxf(sooner, 0.0), 1.0)

## The share (%) of an ally's damage Crossed Strings moves (`talent`: Taking the Weight's, which replaces it).
static func cross_pct_with(talent: float) -> float:
	return talent if talent > 0.0 else Balance.STRING_CROSS_PCT

## Metres apart a crossing holds (`far`: Taking the Weight's capstone).
static func cross_range_with(far: bool) -> float:
	return Balance.TAKING_THE_WEIGHT_RANGE if far else Balance.STRING_CROSS_RANGE

## Full Harness: the share (%) of its damage an ally with `strings` of my Strings is spared.
static func full_harness_pct(strings: int, pct: float) -> float:
	return pct if strings >= Balance.STRING_STACKS and pct > 0.0 else 0.0

## First Stitch: the heal of tying a String, a coefficient (`heals` heals of one String).
static func first_stitch_coef(heals: float) -> float:
	return Balance.STRING_HEAL * maxf(heals, 0.0)

## Heave: Hoist's heal on someone with `strings` of my Strings, a multiplier (`pct` % more for each).
static func heave_mult(strings: int, pct: float) -> float:
	return 1.0 + maxf(pct, 0.0) * clampi(strings, 0, Balance.STRING_STACKS) / 100.0

## Heave's capstone: Hoist's cast time on someone with `strings` of my Strings.
## Deep Call: Beckon's cast `cast` is `cut` sec shorter on a target whose Breach of mine is open.
static func deep_call_cast(cast: float, cut: float, open: bool) -> float:
	return maxf(cast - cut, 0.2) if open and cut > 0.0 else cast

## Hard Pull: how long Tug makes an ally's Strings heal faster (`extra` = the talent's seconds).
static func tug_time(extra: float = 0.0) -> float:
	return Balance.TUG_TIME + maxf(extra, 0.0)

static func heave_cast(cast: float, strings: int, capstone: bool) -> float:
	return maxf(cast - Balance.HEAVE_CAST, 0.2) if capstone and strings >= Balance.STRING_STACKS else cast

## Snap Back: does Pull Taut's String go straight back into my hand? (`roll`: 0-100.)
static func snaps_back(pct: float, roll: float) -> bool:
	return pct > 0.0 and roll < pct

## Seconds Slack stops the Strings healing (`less`: Give and Take).
static func slack_time(less: float) -> float:
	return maxf(Balance.SLACK_TIME - maxf(less, 0.0), 0.0)

## Steady Hands: a String's heal `coef` with `pct` % more.
static func steady_heal(coef: float, pct: float) -> float:
	return coef * (1.0 + maxf(pct, 0.0) / 100.0)

## Many Hands: the multiplier on a heal of mine (`on_other`: it is not on myself).
static func many_hands_mult(on_other: bool, pct: float) -> float:
	return 1.0 + maxf(pct, 0.0) / 100.0 if on_other else 1.0

## Lean On Me: less damage taken for a while after healing someone else.
static func make_lean_on_me_fx(pct: float) -> Resource:
	var fx := StatusContainer.make_buff(LEAN_ON_ME_FX, "Lean On Me", LEAN_ON_ME_FX, 0.0, Balance.LEAN_ON_ME_TIME, 1, STRING_COLOR.darkened(0.15))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Shadow", "Defensive"])
	fx.damage_mod_pct = -absf(pct)
	fx.modifies_incoming = true
	fx.mod_affects_dots = true
	fx.description = "You take %s%% less damage." % Stats.num(absf(pct))
	return fx

func string_time() -> float:
	return string_time_with(player._talent("shadow_long_thread"))

func _cross_pct() -> float:
	return cross_pct_with(player._talent("shadow_taking_the_weight"))

## Many Hands: what a heal of mine on `tgt` is multiplied by (more on anyone but me).
## (And my Pact's: the Shepherd. A heal on myself gets that one in heal().)
func _others_heal_mult(tgt: Variant) -> float:
	var other: bool = tgt != null and is_instance_valid(tgt) and not is_same(tgt, player)
	var grace := 1.0 + player._talent("holy_grace") / 100.0 if other else 1.0   # Grace (an open Holy talent)
	return many_hands_mult(other, player._talent("shadow_many_hands")) * (player._pact_heal_mult() if other else 1.0) * grace

func _steady(coef: float) -> float:
	return steady_heal(coef, player._talent("shadow_steady_hands"))

## Lean On Me: I healed someone else (_on_heal_done_strings).
func _lean_on_me() -> void:
	var pct := player._talent("shadow_lean_on_me")
	if pct <= 0.0 or player.status == null or player.is_dead():
		return
	if player.status.has(LEAN_ON_ME_FX):
		player.status.set_remaining(LEAN_ON_ME_FX, Balance.LEAN_ON_ME_TIME)   # (many small heals: only its time starts over)
	else:
		player.status.apply(make_lean_on_me_fx(pct), player)

## Long Drop: enemies String Up is holding, and when each is let go.
var _long_drops: Array = []   # [{"foe": Node, "at": time}]

func _tick_long_drops() -> void:
	if _long_drops.is_empty():
		return
	var now := _str_now()
	for i in range(_long_drops.size() - 1, -1, -1):
		var d: Dictionary = _long_drops[i]
		if now < float(d["at"]):
			continue
		_long_drops.remove_at(i)
		var foe: Variant = d["foe"]
		var coef := player._talent("shadow_long_drop")
		if coef > 0.0 and foe != null and is_instance_valid(foe) and foe is Node3D and foe.is_alive():
			player.deal_damage(foe, coef, LONG_DROP_ID, true, "shadow", PackedStringArray(STRING_TAGS))
			player._ring_effect(0.8, HoundsKit.HOUND_COLOR, (foe as Node3D).global_position)

## Tying a String to an ally who has `n`: [Strings it has afterwards, how many of
## those added are free (Double Thread's second), is the String used up].
## An ally who is full gets none: the String only starts their time over, and
## is used up doing it.
static func string_placed(n: int, doubled: bool = false) -> Array:
	var room := Balance.STRING_STACKS - maxi(n, 0)
	if room <= 0:
		return [maxi(n, 0), 0, true]
	var add := mini(2 if doubled else 1, room)
	return [maxi(n, 0) + add, add - 1, false]

## Heal of one tick on an ally with `stacks` Strings (`loose`: one of Cat's Cradle's as well), a coefficient.
static func string_tick_heal(stacks: int, loose: bool = false) -> float:
	return Balance.STRING_HEAL * (maxi(stacks, 0) + (1 if loose else 0))

## Seconds between the heals of an ally's Strings (`haste` = my haste multiplier, `tugged` = Tug).
static func string_tick_interval(haste: float, tugged: bool = false) -> float:
	return maxf(Balance.STRING_TICK / (maxf(haste, 0.1) * (Balance.TUG_SPEED_MULT if tugged else 1.0)), 0.1)

## What every other ally on a String gets of a heal of `amount`.
static func string_share(amount: int) -> int:
	return int(round(maxf(float(amount), 0.0) * Balance.STRING_SHARE_PCT / 100.0))

## Is a heal `id` of mine shared along the Strings? A spell's or an ability's
## own heal (`is_ability`: it is in Abilities.PATHS): no Lifesteal, no talent or
## rune heal, and none of STRING_NO_SHARE.
static func shares_heal(id: String, is_ability: bool) -> bool:
	return is_ability and not STRING_NO_SHARE.has(id)

## Crossed Strings: the damage that was taken away from a hit of `amount` (what
## got through, with `bonus_pct` in it) by a `pct` % share. The enemy takes it.
static func cross_redirect(amount: float, bonus_pct: float, pct: float) -> float:
	var mult := 1.0 + bonus_pct / 100.0
	if mult <= 0.0 or pct <= 0.0 or amount <= 0.0:
		return 0.0
	return amount * (pct / 100.0) / mult

## Pull Taut: the healing a String with `seconds_left` still had to give, a coefficient.
## (`full`: how long a String lasts for me, with Long Thread.)
static func pull_taut_coef(seconds_left: float, full: float = Balance.STRING_TIME) -> float:
	return Balance.STRING_HEAL * clampf(seconds_left, 0.0, maxf(full, 0.0)) / Balance.STRING_TICK

## Cupped Hands: its shield on an ally with `strings` Strings, as a Heal coefficient.
static func cupped_hands_coef(strings: int) -> float:
	return Balance.REFERENCE_HEAL * (Balance.CUPPED_HANDS_SHIELD + Balance.CUPPED_HANDS_PER_STRING * maxi(strings, 0))

## Slack: mana points back with `strings` Strings out.
static func slack_mana(strings: int) -> float:
	return Balance.SLACK_MANA * maxi(strings, 0)

## Still Standing: is someone at `hp` of `max_hp` health well enough to stay up when the Strings let go?
static func still_standing_lives(hp: int, max_hp: int, pct: float) -> bool:
	return max_hp > 0 and float(hp) * 100.0 / float(max_hp) >= pct

## The buff someone on a String carries (its stacks = how many Strings).
static func make_string_fx() -> Resource:
	var fx := StatusContainer.make_buff(STRING_BUFF, "String", STRING_BUFF, 0.0, Balance.STRING_TIME, Balance.STRING_STACKS + 1, STRING_COLOR)
	fx.stat_modifiers = {}
	fx.stack_mode = 0   # (its stacks and time are set by whoever holds the Strings)
	fx.per_caster = true
	fx.tags = PackedStringArray(["Shadow"])
	fx.description = "Held up by a demon's Strings: each one heals you every second."
	return fx

static func make_double_thread_fx() -> Resource:
	var fx := StatusContainer.make_buff(DOUBLE_THREAD_FX, Abilities.ability_name(DOUBLE_THREAD_ID), DOUBLE_THREAD_FX, 0.0,
		Balance.DOUBLE_THREAD_TIME, 1, STRING_COLOR)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Shadow"])
	fx.description = "Your next String on an ally is placed as two."
	return fx

## Behind Its Back: less damage taken, of every kind.
static func make_behind_fx() -> Resource:
	var fx := StatusContainer.make_buff(BEHIND_FX, Abilities.ability_name(BEHIND_ID), BEHIND_FX, 0.0,
		Balance.BEHIND_ITS_BACK_TIME, 1, HoundsKit.HOUND_COLOR.darkened(0.1))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Shadow", "Defensive"])
	fx.damage_mod_pct = -Balance.BEHIND_ITS_BACK_PCT
	fx.modifies_incoming = true
	fx.mod_affects_dots = true
	fx.description = "You take %s%% less damage." % Stats.num(Balance.BEHIND_ITS_BACK_PCT)
	return fx

static func make_slack_fx() -> Resource:
	var fx := StatusContainer.make_buff(SLACK_FX, Abilities.ability_name(SLACK_ID), SLACK_FX, 0.0, Balance.SLACK_TIME, 1, STRING_COLOR.darkened(0.3))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Shadow"])
	fx.description = "Your Strings are slack: they do not heal."
	return fx

## Cupped Hands: the buff its shield rides on (`time` seconds).
static func make_cupped_hands_fx(time: float) -> Resource:
	var fx := StatusContainer.make_buff(CUPPED_HANDS_FX, Abilities.ability_name(CUPPED_HANDS_ID), CUPPED_HANDS_FX, 0.0, time, 1, HoundsKit.HOUND_COLOR)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Shadow", "Defensive"])
	fx.description = "A demon's hand is closed over you: a shield that absorbs damage."
	return fx

static func make_still_standing_fx(time: float) -> Resource:
	var fx := StatusContainer.make_buff(STILL_STANDING_FX, Abilities.ability_name(STILL_STANDING_ID), STILL_STANDING_FX, 0.0, time, 1, STRING_COLOR)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Shadow", "Defensive"])
	fx.description = "A killing blow leaves you at a sliver of health, held up by the Strings."
	return fx

static func make_held_up_fx(time: float) -> Resource:
	var fx := StatusContainer.make_buff(HELD_UP_FX, "Held Up", HELD_UP_FX, 0.0, time, 1, HoundsKit.HOUND_COLOR.lightened(0.2))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Shadow", "Defensive"])
	fx.description = "The Strings are holding you up: nothing can kill you. When they let go you fall, unless you have been healed enough."
	return fx

func _str_now() -> float:
	return Time.get_ticks_msec() / 1000.0

## My entry for `who`, made empty if there is none: {node, enemy, n (Strings on
## it), free (how many of those are none of my STRING_MAX), until (when they run
## out), born, next (its next heal), fast (Tug: heals faster until then), knot,
## cross (instance id at the other end of a crossing, 0 = none), loose (when
## Cat's Cradle's String on it runs out, 0 = none)}.
func _string_entry(who: Node3D, is_enemy: bool) -> Dictionary:
	var key := who.get_instance_id()
	if not _strings.has(key):
		var now := _str_now()
		_strings[key] = {"node": who, "enemy": is_enemy, "n": 0, "free": 0, "until": 0.0, "born": now,
			"next": now + string_tick_interval(player.haste_mult()), "fast": 0.0, "knot": false, "cross": 0, "loose": 0.0}
	return _strings[key]

## How many of my STRING_MAX are tied somewhere.
func strings_placed() -> int:
	var n := 0
	for e in _strings.values():
		n += int(e["n"]) - int(e["free"])
	return n

## Every String I have out, the free ones too (not Cat's Cradle's loose ones).
func strings_out() -> int:
	var n := 0
	for e in _strings.values():
		n += int(e["n"])
	return n

## Strings in my hand: the charges of the String ability.
func string_charges() -> int:
	return strings_in_hand(strings_placed(), _string_spent)

## My Strings on `who` (not a loose one).
func strings_on(who: Variant) -> int:   # untyped: may be a freed node
	if who == null or not is_instance_valid(who) or not (who is Node):
		return 0
	var e: Variant = _strings.get((who as Node).get_instance_id())
	return int(e["n"]) if e != null else 0

## Is `who` on one of my Strings (a loose one counts)?
func on_my_string(who: Variant) -> bool:
	if who == null or not is_instance_valid(who) or not (who is Node):
		return false
	var e: Variant = _strings.get((who as Node).get_instance_id())
	return e != null and (int(e["n"]) > 0 or float(e["loose"]) > _str_now())

## Can entry `e` still hold? Its target is there, on its feet (a new one gets a
## moment for that) and within the leash.
func _string_holds(e: Dictionary, now: float) -> bool:
	var who: Variant = e["node"]
	if who == null or not is_instance_valid(who) or not (who is Node3D):
		return false
	if not who.is_alive() and (bool(e["enemy"]) or now - float(e["born"]) > STRING_GRACE):
		return false
	return is_same(who, player) or player._flat_dist_to((who as Node3D).global_position) <= Balance.STRING_LEASH

## Who a String ability goes to: [node, is it an enemy, error]. My friendly
## target; else (`foes`) my enemy target; else me.
func _string_pick(id: String, foes: bool) -> Array:
	var res := Abilities.get_resource(id)
	var reach := float(res.cast_range) if res else 40.0
	var who: Node3D = player
	var is_enemy := false
	if player.has_friendly_target():
		who = player.friendly_target
	elif foes and player._has_valid_target():
		who = player.target
		is_enemy = true
	if not is_same(who, player):
		if reach > 0.0 and player.global_position.distance_to(who.global_position) > reach:
			return [null, false, "Target out of range"]
		if not player.can_see(who):
			return [null, false, "Target not in line of sight"]
	return [who, is_enemy, ""]

## Can a String ability be used right now? ("" = yes.) _drafted_precheck asks.
func _string_precheck(id: String) -> String:
	match id:
		STRING_ID:
			return str(_string_pick(id, true)[2])
		TUG_ID, CUPPED_HANDS_ID, STILL_STANDING_ID:
			var pick := _string_pick(id, false)
			if str(pick[2]) != "":
				return str(pick[2])
			return "" if on_my_string(pick[0]) else NOT_ON_STRING
		PULL_TAUT_ID, KNOT_ID:
			var pick := _string_pick(id, false)
			if str(pick[2]) != "":
				return str(pick[2])
			return "" if strings_on(pick[0]) > 0 else NO_STRING_THERE
		YANK_ID:
			if not player.has_friendly_target():
				return "No friendly target"
			var pick := _string_pick(id, false)
			if str(pick[2]) != "":
				return str(pick[2])
			return "" if on_my_string(pick[0]) else NOT_ON_STRING
		WRENCH_ID:
			return "" if strings_on(player.target) > 0 else "That enemy has none of your Strings"
		BEHIND_ID, SLACK_ID, CUT_STRINGS_ID:
			return "" if strings_out() > 0 else NO_STRINGS_OUT
		NOT_FINISHED_ID:
			var res := Abilities.get_resource(id)
			return "" if _fallen_ally(float(res.cast_range)) != null else "No downed ally in range"
		RESTRING_ID:
			return _restring_error()
	return ""

## A String ability went off (_use_drafted, once it was paid for).
func _string_use(id: String, res: Resource) -> void:
	match id:
		STRING_ID:
			_use_string()
		TUG_ID:
			_tug()
		CRADLE_ID:
			_cats_cradle(res)
		WRENCH_ID:
			_wrench(res)
		PULL_TAUT_ID:
			_pull_taut()
		CUPPED_HANDS_ID:
			_cupped_hands()
		STRING_UP_ID:
			_string_up()
		RESTRING_ID:
			_restring()
		KNOT_ID:
			_knot()
		TANGLE_ID:
			_tangle(res)
		YANK_ID:
			_yank()
		DOUBLE_THREAD_ID:
			player.status.apply(make_double_thread_fx(), player)
			player._ring_effect(0.8, STRING_COLOR)
		BEHIND_ID:
			player.status.apply(make_behind_fx(), player)
			player._ring_effect(1.3, HoundsKit.HOUND_COLOR)
		SLACK_ID:
			_slack()
		STILL_STANDING_ID:
			_still_standing()
		CUT_STRINGS_ID:
			_cut_the_strings()
		NOT_FINISHED_ID:
			_not_finished(res)

# The Strings themselves.

## String: one from my hand to whoever I have targeted (an ally, an enemy, or me).
func _use_string() -> void:
	var pick := _string_pick(STRING_ID, true)
	var who: Variant = pick[0]
	if who == null:
		return
	_tie_string(who, bool(pick[1]))
	player._ring_effect(0.6, HoundsKit.HOUND_COLOR if bool(pick[1]) else STRING_COLOR, (who as Node3D).global_position)

## Tie a String to `who`. `from_hand`: it comes out of my hand (false: Restring
## moves one that is out already, so nothing is used up and nothing is doubled).
func _tie_string(who: Node3D, is_enemy: bool, from_hand: bool = true) -> void:
	var now := _str_now()
	var key := who.get_instance_id()
	var e := _string_entry(who, is_enemy)
	if is_enemy:
		if int(e["n"]) >= 1:
			if from_hand:
				_string_use_up()   # it takes the place of the one that was there
		else:
			e["n"] = 1
			_string_order.append(key)
		e["until"] = now + Balance.STRING_ENEMY_TIME
		_cross_strings(key)
	else:
		var doubled: bool = from_hand and player.status != null and player.status.has(DOUBLE_THREAD_FX)
		var placed := string_placed(int(e["n"]), doubled)
		for i in int(placed[0]) - int(e["n"]):
			_string_order.append(key)
		e["n"] = int(placed[0])
		e["free"] = int(e["free"]) + int(placed[1])
		if bool(placed[2]) and from_hand:
			_string_use_up()
		if doubled:
			player.status.remove(DOUBLE_THREAD_FX)
		# (A knotted ally's Strings never lose time to a new one.)
		e["until"] = maxf(float(e["until"]), now + string_time()) if bool(e["knot"]) else now + string_time()
		_string_last_ally = key
		# First Stitch: the String heals the moment it is tied.
		var stitch := player._talent("shadow_first_stitch")
		if stitch > 0.0:
			_heal_coef(who, _steady(first_stitch_coef(stitch)), FIRST_STITCH_ID)
	_tell_string(key, who)
	_strings_dirty = true

## A String of mine was used up: it is back in my hand STRING_RECHARGE seconds
## after the one recovering before it.
func _string_use_up() -> void:
	_string_spent += 1
	if _string_spent == 1:
		_string_recover_at = _str_now() + string_recharge(player._talent("shadow_spare_spool"))   # Spare Spool

## One String comes off `key` (its entry goes with the last one).
func _string_take(key: int) -> void:
	if not _strings.has(key):
		return
	var e: Dictionary = _strings[key]
	if int(e["n"]) <= 1:
		_strings_fall(key)
		return
	e["n"] = int(e["n"]) - 1
	e["free"] = mini(int(e["free"]), int(e["n"]))
	var at := _string_order.rfind(key)
	if at >= 0:
		_string_order.remove_at(at)
	_tell_string(key, e["node"])
	_strings_dirty = true

## The Strings on `key` are gone (they ran their time, or were taken off). A
## loose one of Cat's Cradle stays until it runs out.
func _strings_fall(key: int) -> void:
	if not _strings.has(key):
		return
	var e: Dictionary = _strings[key]
	var who: Variant = e["node"]
	_uncross(key)
	e["n"] = 0
	e["free"] = 0
	e["knot"] = false
	while _string_order.has(key):
		_string_order.erase(key)
	if bool(e["enemy"]) or float(e["loose"]) <= _str_now():
		_strings.erase(key)
	_tell_string(key, who)
	_strings_dirty = true

## Everything of mine on `key` is gone, a loose String too.
func _string_gone(key: int) -> void:
	if not _strings.has(key):
		return
	_strings[key]["loose"] = 0.0
	_strings_fall(key)

## Dead, or downed: the demon lets everything go.
func _clear_strings() -> void:
	for key in _strings.keys():
		_string_gone(int(key))
	_slack_until = 0.0
	_show_strings()

## The String on enemy `enemy_key` is crossed with the ally I tied last (if that
## ally still has a String). One crossing for each ally and for each enemy: an
## older one lets go.
func _cross_strings(enemy_key: int) -> void:
	_uncross(enemy_key)
	var ally_key := _string_last_ally
	if not _strings.has(ally_key) or not _strings.has(enemy_key):
		return
	var a: Dictionary = _strings[ally_key]
	if bool(a["enemy"]) or int(a["n"]) <= 0:
		return
	_uncross(ally_key)
	a["cross"] = enemy_key
	_strings[enemy_key]["cross"] = ally_key
	_tell_string(ally_key, a["node"])

func _uncross(key: int) -> void:
	if not _strings.has(key):
		return
	var other := int(_strings[key]["cross"])
	if other == 0:
		return
	_strings[key]["cross"] = 0
	if _strings.has(other):
		_strings[other]["cross"] = 0
	for k in [key, other]:
		if _strings.has(k) and not bool(_strings[k]["enemy"]):
			_tell_string(int(k), _strings[k]["node"])

## Let whoever is at the other end know where their Strings stand: how many (a
## loose one counts), for how long, and what share of their damage is crossed
## away. Me: straight into my own buffs. A dummy: its Status. A party member:
## their machine (Net.support_ally "string").
func _tell_string(key: int, who: Variant) -> void:   # untyped: may be a freed node
	if who == null or not is_instance_valid(who) or not (who is Node) or (who as Node).is_in_group("enemies"):
		return
	var data := {"n": 0, "t": 0.0, "cross": 0.0, "dr": 0.0}
	var e: Variant = _strings.get(key)
	if e != null:
		var now := _str_now()
		var loose := maxf(float(e["loose"]) - now, 0.0)
		var held := maxf(float(e["until"]) - now, 0.0) if int(e["n"]) > 0 else 0.0
		data["n"] = int(e["n"]) + (1 if loose > 0.0 else 0)
		data["t"] = maxf(held, loose)
		data["cross"] = _cross_pct() if int(e["cross"]) != 0 else 0.0   # (Taking the Weight)
		data["dr"] = full_harness_pct(int(e["n"]), player._talent("shadow_full_harness"))   # Full Harness: % less damage taken
	if is_same(who, player):
		_on_string_state(player, data)
	elif (who as Node).is_in_group("friendly"):
		_string_on_dummy(who, key, data)
	elif player._net():
		player._net().support_ally(who, player, "string", data)

## A friendly dummy on a String: the buff that shows it, and the share of what
## it takes that is crossed away (ally_dummy.gd asks its "damage_share" meta).
func _string_on_dummy(who: Node, key: int, data: Dictionary) -> void:
	var st: Node = who.get_node_or_null("Status")
	if st != null:
		if int(data["n"]) > 0 and float(data["t"]) > 0.0:
			if _string_fx == null:
				_string_fx = make_string_fx()
			if not st.has_from(STRING_BUFF, player):   # (told again every few seconds: only the numbers change)
				st.apply(_string_fx, player)
			st.set_stacks_from(STRING_BUFF, player, int(data["n"]))
			st.set_remaining_from(STRING_BUFF, player, float(data["t"]))
		else:
			st.remove_from(STRING_BUFF, player)
	if float(data["cross"]) > 0.0 or float(data.get("dr", 0.0)) > 0.0:
		who.set_meta("damage_share", Callable(player, "_dummy_crossed").bind(key))
	elif who.has_meta("damage_share"):
		who.remove_meta("damage_share")

## A dummy on a crossed String is about to take `dmg`: its share goes to the enemy. Returns what is left.
func _dummy_crossed(dmg: int, key: int) -> int:
	var e: Variant = _strings.get(key)
	if e == null or dmg <= 0:
		return dmg
	# Full Harness: with every String it can hold, it is spared a share.
	var left := dmg - int(round(dmg * full_harness_pct(int(e["n"]), player._talent("shadow_full_harness")) / 100.0))
	if int(e["cross"]) == 0:
		return left
	var moved := int(round(dmg * _cross_pct() / 100.0))
	_crossed_damage(e["node"], moved)
	return maxi(left - moved, 0)

## An ally on a crossed String took less: `amount` of it is dealt to the enemy
## at the other end, as my own Shadow damage under its own name.
func _crossed_damage(ally: Variant, amount: int) -> void:
	if amount <= 0 or ally == null or not is_instance_valid(ally) or not (ally is Node):
		return
	var a: Variant = _strings.get((ally as Node).get_instance_id())
	if a == null or int(a["cross"]) == 0 or not _strings.has(int(a["cross"])):
		return
	player.arcane_caster._exact_hit(_strings[int(a["cross"])]["node"], amount, CROSSED_ID, "shadow", PackedStringArray(STRING_TAGS))

## Every frame: Strings heal, run out and come back; the demon and the party are kept up to date.
func _tick_strings() -> void:
	_tick_strung()            # (the other end: Strings somebody has on me)
	_tick_still_standing()
	_tick_long_drops()        # Long Drop: enemies String Up lets go of
	var now := _str_now()
	if _string_spent > 0 and now >= _string_recover_at:
		_string_spent -= 1
		_string_recover_at = now + string_recharge(player._talent("shadow_spare_spool")) if _string_spent > 0 else 0.0
	if _strings.is_empty():
		if _strings_shown or _strings_dirty:
			_show_strings()
		return
	if player.is_dead():
		_clear_strings()
		return
	var slack := now < _slack_until
	for key in _strings.keys():
		if not _strings.has(key):
			continue
		var e: Dictionary = _strings[key]
		if not _string_holds(e, now):
			_string_gone(int(key))   # dead, gone or too far away: back in my hand
			continue
		if int(e["n"]) > 0 and now >= float(e["until"]):
			_strings_fall(int(key))  # ran their time: back in my hand
			if not _strings.has(key):
				continue
		var loose := float(e["loose"]) > now
		if int(e["n"]) <= 0 and not loose:
			_string_gone(int(key))
			continue
		if bool(e["enemy"]):
			# Crossed: it breaks when the two are too far apart.
			var other := int(e["cross"])
			if other != 0:
				var a: Variant = _strings.get(other)
				if a == null or not is_instance_valid(a["node"]) or (e["node"] as Node3D).global_position.distance_to(
						(a["node"] as Node3D).global_position) > cross_range_with(player._capstone("shadow_taking_the_weight")):
					_string_gone(int(key))
			continue
		if now >= float(e["next"]):
			e["next"] = now + string_tick_interval(player.haste_mult(), now < float(e["fast"]))
			if not slack and (e["node"] as Node).is_alive():
				_heal_coef(e["node"], _steady(string_tick_heal(int(e["n"]), loose)), STRING_ID)   # (Steady Hands)
	if _strings_dirty or now - _strings_told >= STRINGS_RETELL:
		_show_strings()

## Show my demon and the threads on everyone I hold, tell the party, and remind
## everyone on a String where theirs stand.
func _show_strings() -> void:
	_strings_dirty = false
	_strings_told = _str_now()
	var now := _strings_told
	var net := player._net()
	var held: Array = []
	var members := {}
	var foes := {}
	for key in _strings:
		var e: Dictionary = _strings[key]
		var who: Variant = e["node"]
		if who == null or not is_instance_valid(who):
			continue
		var n := int(e["n"]) + (1 if float(e["loose"]) > now else 0)
		if n <= 0:
			continue
		held.append([who, n, bool(e["enemy"])])
		if bool(e["enemy"]):
			if net:
				foes[str(net.enemy_id(who))] = 1
			continue
		if net and not (who as Node).is_in_group("friendly"):
			var member := int(net.member_of(who))
			if member != 0:
				members[member] = n
		_tell_string(int(key), who)
	_strings_shown = not held.is_empty()
	if player.is_inside_tree():
		PUPPETEER.hold(player.get_tree().current_scene, player, held)
	player._net_fx("strings", player.global_position, null, {"m": members, "e": foes})

# Heals.

## Heal `tgt` (me, a party member or a friendly dummy) for exactly `amount`, as
## `id` in the log and on the meter. A party member is healed on their own machine.
func _heal_exact(tgt: Variant, amount: int, id: String) -> void:   # untyped: may be a freed node
	if amount <= 0 or tgt == null or not is_instance_valid(tgt) or not (tgt is Node):
		return
	player.holy_talents._overflowing(tgt, amount, id)   # Overflowing: the overhealing becomes a shield
	player.holy_talents._second_breath(tgt, amount, id)   # Second Breath: a big save gives mana back
	if is_same(tgt, player) or (tgt as Node).is_in_group("friendly"):
		player._combat().heal(player, tgt, float(amount), id, true)
		return
	player._combat().float_text(tgt, "+%d" % amount, Color(0.45, 1.0, 0.45), false)
	player._bus().heal_done.emit(player, tgt, amount, amount, id, false)   # Details meter
	if player._net():
		player._net().support_ally(tgt, player, "heal", {"amount": amount, "id": id})   # their machine heals them (+ threat)

## The same for a coefficient `coef` (it scales with my power like spell `id`). Returns the amount.
func _heal_coef(tgt: Variant, coef: float, id: String) -> int:
	# (Many Hands and my Pact on someone else; my Pact alone on myself, since this heal does not go through heal().)
	coef *= player.holy_talents._holy_heal_mult(id)   # Radiance
	if not is_same(tgt, player) and player.holy_talents.hit_recently(tgt, Balance.WATCHFUL_EYE_WINDOW):
		coef *= 1.0 + player._talent("holy_watchful_eye") / 100.0   # Watchful Eye (both Holy healers)
	var amount: int = player._combat().heal_amount(player, coef * (player._pact_heal_mult() if is_same(tgt, player) else _others_heal_mult(tgt)), id)
	_heal_exact(tgt, amount, id)
	return amount

## A heal of mine landed (SignalBus.heal_done, which hears every one). A spell's
## or an ability's heal on an ally on a String is shared: every other ally on
## one of my Strings is healed for a share of it, under its own name.
func _on_heal_done_strings(source: Node, healed: Node, amount: int, _effective: int, id: String, _crit: bool) -> void:
	if amount <= 0 or not is_same(source, player):
		return
	player._pact_on_heal(healed, id)   # my Pact: the Fast (a heal on myself), the Relentless (one on an ally)
	if healed != null and not is_same(healed, player):
		_lean_on_me()   # Lean On Me (an open talent: any heal of mine on someone else)
	if _strings.is_empty():
		return
	if not shares_heal(id, Abilities.PATHS.has(id)) or not on_my_string(healed):
		return
	var share := string_share(amount)
	for key in _strings.keys():
		var e: Variant = _strings.get(key)
		if e == null or bool(e["enemy"]) or is_same(e["node"], healed) or not on_my_string(e["node"]):
			continue
		_heal_exact(e["node"], share, STRING_SHARE_ID)

## Hoist and Patch Up finished casting (_release_support): the heal lands on
## whoever they were cast at. (Hoist's share for the others: _on_heal_done_strings.)
func _string_cast_heal(spell: String, tgt: Variant, kind: String) -> void:
	var who: Variant = tgt if kind == "ally" and tgt != null and is_instance_valid(tgt) else player
	var coef := float(Abilities.HEALS[spell])
	if spell == HOIST_ID:
		coef *= heave_mult(strings_on(who), player._talent("shadow_heave"))   # Heave: more for each String on them
	_heal_coef(who, coef, spell)
	if who is Node3D:
		player._ring_effect(1.2, STRING_COLOR, (who as Node3D).global_position)

## Tug: a small heal, and that ally's Strings heal faster for a while.
func _tug() -> void:
	var who: Variant = _string_pick(TUG_ID, false)[0]
	if who == null:
		return
	_heal_coef(who, float(Abilities.HEALS[TUG_ID]), TUG_ID)
	var e: Variant = _strings.get((who as Node).get_instance_id())
	if e != null:
		var now := _str_now()
		e["fast"] = now + tug_time(player._talent("shadow_hard_pull"))   # Hard Pull: longer
		e["next"] = minf(float(e["next"]), now + string_tick_interval(player.haste_mult(), true))
	player._ring_effect(0.7, STRING_COLOR, (who as Node3D).global_position)

## Cat's Cradle: every ally near me is healed and gets a loose String (none of
## my STRING_MAX) for a while.
func _cats_cradle(res: Resource) -> void:
	var now := _str_now()
	for a in player.fire_cooldowns._allies_within(float(res.radius)):
		_heal_coef(a, float(Abilities.HEALS[CRADLE_ID]), CRADLE_ID)
		var e := _string_entry(a, false)
		e["loose"] = now + Balance.LOOSE_STRING_TIME
		_tell_string((a as Node).get_instance_id(), a)
		player._ring_effect(0.7, STRING_COLOR, (a as Node3D).global_position)
	_strings_dirty = true
	player._ring_effect(2.5, STRING_COLOR)

## Pull Taut: one String on the ally gives all the healing it had left, and is used up.
func _pull_taut() -> void:
	var who: Variant = _string_pick(PULL_TAUT_ID, false)[0]
	if who == null:
		return
	var key: int = (who as Node).get_instance_id()
	var e: Variant = _strings.get(key)
	if e == null or int(e["n"]) <= 0:
		return
	_heal_coef(who, _steady(pull_taut_coef(float(e["until"]) - _str_now(), string_time())), PULL_TAUT_ID)
	_string_take(key)
	if snaps_back(player._talent("shadow_snap_back"), randf() * 100.0):
		player._combat().float_text(player, "Snap Back", STRING_COLOR, false)   # straight back into my hand
	else:
		_string_use_up()
	player._ring_effect(0.9, STRING_COLOR, (who as Node3D).global_position)

## Knot: the ally's Strings do not run out for a while. One ally at a time.
func _knot() -> void:
	var who: Variant = _string_pick(KNOT_ID, false)[0]
	if who == null:
		return
	var key: int = (who as Node).get_instance_id()
	var now := _str_now()
	for k in _strings:
		var other: Dictionary = _strings[k]
		if bool(other["knot"]) and int(k) != key:
			other["knot"] = false
			other["until"] = minf(float(other["until"]), now + string_time())
			_tell_string(int(k), other["node"])
	var e: Variant = _strings.get(key)
	if e == null or int(e["n"]) <= 0:
		return
	e["knot"] = true
	e["until"] = now + Balance.KNOT_TIME
	_tell_string(key, who)
	player._ring_effect(0.8, STRING_COLOR, (who as Node3D).global_position)

## Wrench: the enemy on a String is hurt, and the ally it is crossed with is healed for as much.
func _wrench(res: Resource) -> void:
	var foe: Node3D = player.target
	var e: Variant = _strings.get(foe.get_instance_id())
	var crossed: Variant = _strings.get(int(e["cross"])) if e != null and int(e["cross"]) != 0 else null
	var dealt := player.deal_damage(foe, float(res.damage), WRENCH_ID)
	if crossed != null and dealt > 0:
		_heal_exact(crossed["node"], dealt, WRENCH_ID)
	player._ring_effect(0.7, HoundsKit.HOUND_COLOR, foe.global_position)

## Cupped Hands: a shield on an ally on a String, bigger for each String on them.
func _cupped_hands() -> void:
	var who: Variant = _string_pick(CUPPED_HANDS_ID, false)[0]
	if who == null:
		return
	var e: Variant = _strings.get((who as Node).get_instance_id())
	var n := (int(e["n"]) + (1 if float(e["loose"]) > _str_now() else 0)) if e != null else 0
	var amount := int(round(player._combat().heal_amount(player, cupped_hands_coef(n), CUPPED_HANDS_ID) * player.absorb_mult()))   # (Rime Ward: bigger shields)
	if is_same(who, player):
		_shield_on(player.status, player, amount, Balance.CUPPED_HANDS_TIME)
	elif (who as Node).is_in_group("friendly"):
		_shield_on((who as Node).get_node_or_null("Status"), player, amount, Balance.CUPPED_HANDS_TIME)
	elif player._net():
		player._net().support_ally(who, player, "shield", {"amount": amount, "time": Balance.CUPPED_HANDS_TIME})
	player._combat().float_text(who, "%s (%d)" % [Abilities.ability_name(CUPPED_HANDS_ID), amount], STRING_COLOR, false)
	player._ring_effect(1.0, HoundsKit.HOUND_COLOR, (who as Node3D).global_position)

## Put Cupped Hands' shield of `amount` on whoever owns Status `st`.
func _shield_on(st: Node, from: Node, amount: int, time: float) -> void:
	if st == null or amount <= 0:
		return
	st.apply(make_cupped_hands_fx(time), from)
	st.set_absorb(CUPPED_HANDS_FX, amount)

## Slack: my Strings stop healing for a while, and I get mana back for each one out.
func _slack() -> void:
	var slack_for := slack_time(player._talent("shadow_give_and_take"))   # Give and Take: for less long
	_slack_until = _str_now() + slack_for
	player._gain("mana", slack_mana(strings_out()) * player.mana_unit())
	if slack_for > 0.0:
		player.status.apply(make_slack_fx(), player)
		player.status.set_remaining(SLACK_FX, slack_for)
	player._ring_effect(1.2, Color(0.35, 0.55, 1.0))

## Still Standing: for a while a killing blow on that ally is held off by the Strings.
func _still_standing() -> void:
	var who: Variant = _string_pick(STILL_STANDING_ID, false)[0]
	if who == null:
		return
	var data := {"window": Balance.STILL_STANDING_TIME, "hold": Balance.STILL_STANDING_HOLD, "pct": Balance.STILL_STANDING_HEALTH_PCT}
	if is_same(who, player):
		_receive_hold(player, data)
	elif (who as Node).is_in_group("friendly"):
		var st: Node = (who as Node).get_node_or_null("Status")
		if st:
			st.apply(make_still_standing_fx(Balance.STILL_STANDING_TIME), player)   # (a dummy never dies: only shown)
	elif player._net():
		player._net().support_ally(who, player, "hold", data)
	player._ring_effect(1.1, STRING_COLOR, (who as Node3D).global_position)

## Cut the Strings: every String out bursts (a heal on an ally for each one on
## them, damage on an enemy), and all of them are back in my hand.
func _cut_the_strings() -> void:
	for key in _strings.keys():
		var e: Variant = _strings.get(key)
		if e == null or int(e["n"]) <= 0:
			continue
		var who: Variant = e["node"]
		if who == null or not is_instance_valid(who):
			continue
		if bool(e["enemy"]):
			player.deal_damage(who, Balance.CUT_STRINGS_DAMAGE, CUT_STRINGS_ID)
		else:
			_heal_coef(who, Balance.CUT_STRINGS_HEAL * int(e["n"]), CUT_STRINGS_ID)
		if is_instance_valid(who) and who is Node3D:
			player._ring_effect(0.9, HoundsKit.HOUND_COLOR if bool(e["enemy"]) else STRING_COLOR, (who as Node3D).global_position)
	for key in _strings.keys():
		_strings_fall(int(key))
	player._ring_effect(1.6, STRING_COLOR)

## The String I tied last that can be moved (0 = none): the newest one that is
## still out and not knotted.
func _restring_source() -> int:
	for i in range(_string_order.size() - 1, -1, -1):
		var key := int(_string_order[i])
		var e: Variant = _strings.get(key)
		if e != null and int(e["n"]) > 0 and not bool(e["knot"]):
			return key
	return 0

func _restring_error() -> String:
	var from := _restring_source()
	if from == 0:
		return "You have no String to move"
	var pick := _string_pick(RESTRING_ID, true)
	if str(pick[2]) != "":
		return str(pick[2])
	var key: int = (pick[0] as Node).get_instance_id()
	if key == from:
		return "That String is already there"
	var e: Variant = _strings.get(key)
	if e != null and int(e["n"]) >= (1 if bool(pick[1]) else Balance.STRING_STACKS):
		return "That target cannot hold another String"
	return ""

## Restring: the String I tied last moves to my current target.
func _restring() -> void:
	var from := _restring_source()
	var pick := _string_pick(RESTRING_ID, true)
	if from == 0 or pick[0] == null:
		return
	_string_take(from)
	_tie_string(pick[0], bool(pick[1]), false)
	player._ring_effect(0.6, STRING_COLOR, (pick[0] as Node3D).global_position)

## Yank: my friendly target is pulled to just in front of me.
func _yank() -> void:
	var who: Node3D = player.friendly_target
	if who == null or not is_instance_valid(who):
		return
	var dir := who.global_position - player.global_position
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.1 else player._flat_forward()
	var to := player.global_position + dir * Balance.YANK_STOP
	player._ring_effect(0.8, STRING_COLOR, who.global_position)
	if who.is_in_group("friendly"):
		who.global_position = to
	elif player._net():
		player._net().support_ally(who, player, "yank", {"to": to})
	player._ring_effect(0.8, STRING_COLOR)

## The nearest downed party member within `reach` metres (null if none).
func _fallen_ally(reach: float) -> Node3D:
	var best: Node3D = null
	var best_d := reach
	for p in player.get_tree().get_nodes_in_group("remote_player"):
		if not (p is Node3D) or not bool(p.get("downed")):
			continue
		var d := player._flat_dist_to(p.global_position)
		if d <= best_d:
			best_d = d
			best = p
	return best

## Not Finished With You: the nearest downed ally is lifted back onto their
## feet (their machine stands them up: Net.revive_ally) with Strings on them.
func _not_finished(res: Resource) -> void:
	var ally := _fallen_ally(float(res.cast_range))
	if ally == null:
		return
	if player._net():
		player._net().revive_ally(ally, player)
	var now := _str_now()
	var key := ally.get_instance_id()
	var e := _string_entry(ally, false)
	while _string_order.has(key):
		_string_order.erase(key)
	e["n"] = mini(Balance.NOT_FINISHED_STRINGS, Balance.STRING_STACKS)
	e["free"] = 0
	e["born"] = now
	e["until"] = now + string_time()
	for i in int(e["n"]):
		_string_order.append(key)
	_string_last_ally = key
	_tell_string(key, ally)
	_strings_dirty = true
	player._ring_effect(1.4, STRING_COLOR, ally.global_position)

## String Up: the enemy hangs off the ground, unable to do anything.
func _string_up() -> void:
	var foe: Node3D = player.target
	var fx: Resource = preload("res://scripts/core/effects.gd").get_effect(STRUNG_UP_FX)
	var hangs := Balance.STRING_UP_TIME + player.effect_duration_bonus(fx)   # (Left Hanging: my stuns last longer)
	player.fire_caster._apply_effect_hit(foe, fx, STRING_UP_ID, PackedStringArray(STRING_TAGS), "shadow")
	PUPPETEER.string_up(player.get_tree().current_scene, foe, hangs)
	player._net_fx("strungup", foe.global_position, foe, {"time": hangs})   # the party sees it hang
	if player._talent("shadow_long_drop") > 0.0:
		_long_drops.append({"foe": foe, "at": _str_now() + hangs})   # Long Drop: it is hurt when it is let go

## Tangle: every enemy near my target is held in place by Strings across the floor.
func _tangle(res: Resource) -> void:
	var foe: Node3D = player.target
	var at := foe.global_position
	var r := float(res.radius)
	var fx: Resource = preload("res://scripts/core/effects.gd").get_effect(TANGLED_FX)
	for e in player._enemies_near(at, r):
		player.fire_caster._apply_effect_hit(e, fx, TANGLE_ID, PackedStringArray(STRING_TAGS), "shadow")
	var ground := Vector3(at.x, Combat.feet_y(foe), at.z)
	var held := Balance.TANGLE_TIME + player.effect_duration_bonus(fx)   # (Left Hanging: my roots last longer)
	PUPPETEER.tangle(player.get_tree().current_scene, ground, r, held)
	player._net_fx("tangle", ground, null, {"r": r, "time": held})
	player._ring_effect(r, STRING_COLOR, at)

# The other end: what a healer's Strings do on the one they are tied to. This
# runs on the machine of whoever is held (me, when I tie one to myself).

## Something a party member's ability does to me, or tells me (Net._sup_do).
## `from` = their character on this machine.
func receive_support(kind: String, from: Node, data: Dictionary) -> void:
	match kind:
		"heal":
			if player.is_alive():
				player._combat().heal(from, player, float(int(data.get("amount", 0))), str(data.get("id", "")), true)
		"string":
			_on_string_state(from, data)
		"shield":
			if player.is_alive():
				_shield_on(player.status, from, int(data.get("amount", 0)), float(data.get("time", 0.0)))
				player._combat().float_text(player, "%s (%d)" % [Abilities.ability_name(CUPPED_HANDS_ID), int(data.get("amount", 0))], STRING_COLOR, false)
		"hold":
			if player.is_alive():
				_receive_hold(from, data)
		"yank":
			_yanked_to(data.get("to"))
		"cross_dmg":
			_crossed_damage(from, int(data.get("amount", 0)))   # (I am the healer: my ally's share for the enemy)
		# The Holy healer's Hymns (player.gd, "Holy healer: the Hymns").
		"hymn_dr":
			player.hymns.receive_hymn_dr(from, str(data.get("id", "")), float(data.get("pct", 0.0)), float(data.get("time", 0.0)))
		"hymn_ward":
			if player.is_alive() and HymnsKit.HYMN_WARD_NAMES.has(str(data.get("id", ""))):
				var ward_id := str(data.get("id", ""))
				player.hymns._hymn_ward_on(player.status, from, ward_id, int(data.get("amount", 0)), float(data.get("time", 0.0)))
				if ward_id == HymnsKit.SHELTER_FX:
					player._combat().float_text(player, "%s (%d)" % [HymnsKit.HYMN_WARD_NAMES[ward_id], int(data.get("amount", 0))], HymnsKit.HOLY_LIGHT, false)
		"vigil_hit":
			player.hymns._talent_verse("holy_watchful", "vigil")   # (I am the healer: a big hit landed on an ally in my Vigil)
		# The Nature healer's Shepherd (player.gd, "Nature healer: the Shepherd").
		"blossom":
			player.shepherd._blossoms_shown(player.status, from, int(data.get("n", 0)), float(data.get("t", 0.0)))
		"owl":
			player.shepherd._owl_watched(from, float(data.get("t", 0.0)))
		"owl_hit":
			player.shepherd._owl_dive(from)   # (I am the healer: my owl's ally was hit)
		"rootguard":
			if player.is_alive():
				var healer := from
				player.shepherd._rootguard_on(player.status, from, int(data.get("amount", 0)), float(data.get("time", 0.0)), func():
					if player._net() and is_instance_valid(healer):
						player._net().support_ally(healer, player, "rootguard_broke", {}))
				player._combat().float_text(player, "%s (%d)" % [Abilities.ability_name(ShepherdKit.ROOTGUARD_ID), int(data.get("amount", 0))], ShepherdKit.BLOSSOM_COLOR, false)
		"rootguard_broke":
			player.shepherd._rootguard_broke(from)   # (I am the healer: my shield on that ally was used up)

## Where the Strings `from` has on me stand: n = how many (0 = none any more),
## t = seconds they have left, cross = % of my damage that is crossed away.
func _on_string_state(from: Node, data: Dictionary) -> void:
	if from == null or not is_instance_valid(from) or player.status == null:
		return
	var key := from.get_instance_id()
	var n := int(data.get("n", 0))
	var t := float(data.get("t", 0.0))
	if n <= 0 or t <= 0.0 or player.is_dead():
		_strung.erase(key)
		player.status.remove_from(STRING_BUFF, from)
		return
	_strung[key] = {"from": from, "cross": float(data.get("cross", 0.0)), "dr": float(data.get("dr", 0.0)), "until": _str_now() + t}
	if _string_fx == null:
		_string_fx = make_string_fx()
	if not player.status.has_from(STRING_BUFF, from):   # (told again every few seconds: only the numbers change)
		player.status.apply(_string_fx, from)
	player.status.set_stacks_from(STRING_BUFF, from, n)
	player.status.set_remaining_from(STRING_BUFF, from, t)

## A hit on me, before its damage is worked out (_on_damage_modify): the share
## of it a crossed String takes away.
func _crossed_incoming(info: RefCounted) -> void:
	if _strung.is_empty():
		return
	var now := _str_now()
	for key in _strung.keys():
		var s: Dictionary = _strung[key]
		if now >= float(s["until"]) or not is_instance_valid(s["from"]):
			_strung.erase(key)
		else:
			if float(s["cross"]) > 0.0:
				info.add_bonus(-float(s["cross"]), CROSSED_LABEL)
			if float(s.get("dr", 0.0)) > 0.0:
				info.add_bonus(-float(s["dr"]), FULL_HARNESS_LABEL)   # Full Harness: all the Strings I can hold

## The hit landed (_on_hit_taken): what was taken away goes to the enemy at the
## other end. My own healer deals it at once; a party member's is told a few
## times a second (_tick_strung).
func _crossed_taken(info: RefCounted) -> void:
	if _strung.is_empty() or int(info.amount) <= 0 or info.avoided():
		return
	for key in _strung:
		var s: Dictionary = _strung[key]
		var moved := cross_redirect(float(info.amount), float(info.bonus_pct), float(s["cross"]))
		if moved <= 0.0:
			continue
		if is_same(s["from"], player):
			_crossed_damage(player, int(round(moved)))
		else:
			_cross_owed[key] = float(_cross_owed.get(key, 0.0)) + moved

func _tick_strung() -> void:
	if _cross_owed.is_empty():
		return
	var now := _str_now()
	if now - _cross_told < 0.3:
		return
	_cross_told = now
	for key in _cross_owed.keys():
		var amount := int(round(float(_cross_owed[key])))
		var s: Variant = _strung.get(key)
		if amount >= 1 and s != null and is_instance_valid(s["from"]) and player._net():
			player._net().support_ally(s["from"], player, "cross_dmg", {"amount": amount})
	_cross_owed.clear()

## Still Standing was put on me: for `window` seconds a killing blow is held off.
func _receive_hold(from: Node, data: Dictionary) -> void:
	_stand_until = _str_now() + float(data.get("window", 0.0))
	_stand_hold = float(data.get("hold", 0.0))
	_stand_pct = float(data.get("pct", 0.0))
	if player.status:
		player.status.apply(make_still_standing_fx(float(data.get("window", 0.0))), from)

## Damage of `amount` is about to land on me (take_damage). While the Strings
## hold me up nothing takes my last health; and a blow that would kill me while
## Still Standing is on me starts that instead.
func _still_standing_limit(amount: int) -> int:
	if _held_until <= 0.0 and _stand_until <= 0.0:
		return amount
	var now := _str_now()
	if _held_until > now:
		return mini(amount, player.health - 1)
	if amount >= player.health and _stand_until > now:
		_stand_until = 0.0
		_held_until = now + _stand_hold
		if player.status:
			player.status.remove(STILL_STANDING_FX)
			player.status.apply(make_held_up_fx(_stand_hold), player)
		player._combat().float_text(player, "Held up!", STRING_COLOR, true)
		return player.health - 1
	return amount

## The Strings let go: I stay up only if I was healed enough meanwhile.
func _tick_still_standing() -> void:
	if _held_until <= 0.0 or _str_now() < _held_until:
		return
	_held_until = 0.0
	_stand_until = 0.0
	if player.is_alive() and not still_standing_lives(player.health, player.max_health, _stand_pct):
		player._combat().float_text(player, "The Strings let go", HoundsKit.HOUND_COLOR, true)
		player.take_damage(player.health)

## Yank: a party member's Strings pull me to `to`.
func _yanked_to(to: Variant) -> void:
	if not (to is Vector3) or player.is_dead():
		return
	if player.casting:
		player._cancel_cast()
	player.velocity = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(player, "global_position", to as Vector3, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	player._combat().float_text(player, "Yanked!", STRING_COLOR, false)

