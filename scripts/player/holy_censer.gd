extends "res://scripts/player/player_kit.gd"
class_name CenserKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "censer".
# --- Holy tank: the Censer --------------------------------------------------------------------
# An off hand item (tome, wand, lantern; not a shield) and heavy armor. The censer
# is not an item: my first censer ability makes it appear at my side, hanging on
# a chain of light (the picture is scripts/censer.gd), and it fades CENSER_LINGER
# seconds after combat ends. Its fullness is Incense, a stacking buff (up to
# INCENSE_MAX): each stack gives Block, and enemies around me take a little Holy
# damage with high threat. Hits I take and block give a little Incense, my
# abilities a little more, but most of it lies on the ground as motes of light
# (scripts/light_mote.gd): my builders knock them loose from enemies, and spending
# Incense drops part of it as motes again. I pick one up by walking over it: it
# gives Incense and heals me. Only I can pick up mine; the party sees them faint.
# Raise the Censer sends it over the enemies for a while (a mass grab that sheds
# motes); while it is away my Incense gives no Block and no aura. Numbers are in
# balance.gd; the talents (Mote Magnet, Bright Barrier, Lingering Light, Wide Arc,
# Deep Pour, High Censer) in talents.gd.

const CENSER = preload("res://scripts/censer.gd")
const LIGHT_MOTE = preload("res://scripts/light_mote.gd")
const INCENSE_FX := "incense"
const AUREOLE_FX := "aureole"
const UNFALLEN_FX := "unfallen"
const CENSER_SWING_ID := "censerswing"
const HALLOWED_ARC_ID := "hallowedarc"
const BECKON_ID := "beckon"
const POUR_OUT_ID := "pourout"
const ABSOLVE_ID := "absolve"
const AUREOLE_ID := "aureole"
const GATHER_ID := "gatherthelight"
const RAISE_CENSER_ID := "raisethecenser"
const UNFALLEN_ID := "unfallen"
const CENSER_IDS := [CENSER_SWING_ID, HALLOWED_ARC_ID, BECKON_ID, POUR_OUT_ID, ABSOLVE_ID, AUREOLE_ID,
	GATHER_ID, RAISE_CENSER_ID, UNFALLEN_ID]
## Meter / log ids of the aura, a mote's heal and the Rune of the Bright Burst (own lines: Details.HIT_NAMES).
const INCENSE_AURA_ID := "incense_aura"
const LIGHT_MOTE_ID := "light_mote"
const BRIGHT_BURST_ID := "bright_burst"
const BRIGHT_BURST_RUNE := "bright_burst"
const CENSER_TAGS := ["Holy", "Ability", "AoE"]
## Seconds between telling the party again how bright my censer is.
const CENSER_RETELL := 3.0

var _censer_on := false           # is my censer out?
var _censer_off_at := 0.0         # when it fades (out of combat)
var _censer_shown := -1           # Incense the picture shows (and the party was told)
var _censer_shown_on := false
var _censer_told := 0.0
var _incense_fx: Resource
var _incense_stash := 0           # Incense kept while the censer is raised (it gives nothing then)
var _raised_until := 0.0
var _raise_at := Vector3.ZERO
var _raise_next_shed := 0.0
var _aura_next := 0.0
var _motes: Array = []            # my motes: {"key": String, "pos": Vector3, "until": float, "value": int}
var _mote_seq := 0
var _unfallen_taken := 0          # damage taken during Unfallen
var _unfallen_was := false

## How much Incense I have (while the censer is raised: what it will give back).
func incense() -> int:
	if censer_raised():
		return _incense_stash
	return player.status.stacks_of(INCENSE_FX) if player.status != null else 0

func censer_raised() -> bool:
	return _raised_until > 0.0

func censer_out() -> bool:
	return _censer_on

## My motes of light on the ground: [{"key", "pos", "until", "value"}].
func motes() -> Array:
	return _motes

## Incense after gaining `more` on top of `have` (never more than INCENSE_MAX).
static func incense_after(have: int, more: int) -> int:
	return clampi(have + maxi(more, 0), 0, Balance.INCENSE_MAX)

## Block each stack of Incense gives (`bright` = Bright Barrier's value).
static func incense_block_per_stack(bright: float) -> float:
	return Balance.INCENSE_BLOCK + maxf(bright, 0.0)

## Aura damage (coefficient) of one tick with `stacks` Incense.
static func incense_aura_coef(stacks: int) -> float:
	return Balance.INCENSE_AURA_FULL * float(clampi(stacks, 0, Balance.INCENSE_MAX)) / float(Balance.INCENSE_MAX)

## The motes spending `spent` Incense drops at `pct` %: the Incense each holds.
## Each holds MOTE_VALUE; what is left over makes one smaller mote; at most MOTE_SPEND_MAX.
static func motes_for_spend(spent: int, pct: float) -> Array:
	var worth := int(floor(float(maxi(spent, 0)) * maxf(pct, 0.0) / 100.0))
	var out := []
	while worth > 0 and out.size() < Balance.MOTE_SPEND_MAX:
		var v := mini(worth, Balance.MOTE_VALUE)
		out.append(v)
		worth -= v
	return out

## Incense a hit I take gives (`blocked`; during Unfallen: more).
static func incense_for_hit(blocked: bool, unfallen: bool) -> int:
	var n := Balance.INCENSE_PER_BLOCK if blocked else Balance.INCENSE_PER_HIT
	return n * (Balance.UNFALLEN_INCENSE_MULT if unfallen else 1)

## What Unfallen lets through of a hit of `amount` with `health_left`: never the last point.
static func unfallen_limit(amount: int, health_left: int) -> int:
	return clampi(amount, 0, maxi(health_left - 1, 0))

## Health Unfallen gives back when it ends, for `taken` damage taken during it.
static func unfallen_heal(taken: int) -> int:
	return int(round(maxf(float(taken), 0.0) * Balance.UNFALLEN_HEAL_PCT / 100.0))

## Mote pickup reach (+ Mote Magnet).
func mote_reach() -> float:
	return Balance.MOTE_PICKUP + player._talent("holy_mote_magnet")

## Seconds a mote lies on the ground (+ Lingering Light).
func mote_time() -> float:
	return Balance.MOTE_TIME + player._talent("holy_lingering_light")

func _incense_buff() -> Resource:
	var per := incense_block_per_stack(player._talent("holy_bright_barrier"))   # + Bright Barrier
	if _incense_fx == null or not is_equal_approx(float(_incense_fx.stat_modifiers.get(Stats.BLOCK, 0.0)), per):
		_incense_fx = StatusContainer.make_buff(INCENSE_FX, "Incense", Stats.BLOCK, per,
			Balance.INCENSE_TIME, Balance.INCENSE_MAX, CENSER.LIGHT)
		_incense_fx.tags = PackedStringArray(["Holy"])
		_incense_fx.description = "The light in your censer. Each stack gives Block, and enemies around you take Holy damage."
	return _incense_fx

## My censer appears (my first censer ability) and stays while I fight.
func _censer_appear() -> void:
	if not _censer_on:
		_censer_on = true
		player._ring_effect(0.9, CENSER.LIGHT)
	_censer_off_at = 0.0
	_sync_censer()

## Gain `more` Incense (never more than INCENSE_MAX). Any gain makes it last its
## full time again. While the censer is raised it is kept for when it comes back.
func _gain_incense(more: int) -> void:
	if player.status == null or more <= 0 or player.is_dead():
		return
	if censer_raised():
		_incense_stash = incense_after(_incense_stash, more)
		_sync_censer()
		return
	var want := incense_after(incense(), more)
	if not player.status.apply(_incense_buff(), player):
		return
	if player.status.stacks_of(INCENSE_FX) != want:
		player.status.set_stacks(INCENSE_FX, want)

## Spend up to `n` Incense: returns how much was spent. Part of it drops as
## motes of light around `near` (`pct` % of it).
func _spend_incense(n: int, near: Vector3, pct: float = Balance.MOTE_SPEND_PCT) -> int:
	var spent := mini(maxi(n, 0), incense())
	if spent <= 0:
		return 0
	if censer_raised():
		_incense_stash -= spent
	else:
		player.status.spend_stacks(INCENSE_FX, spent)
	for v in motes_for_spend(spent, pct):
		_drop_mote(near, int(v))
	_sync_censer()
	return spent

## Drop a mote of light holding `value` Incense somewhere around `near`.
func _drop_mote(near: Vector3, value: int = Balance.MOTE_VALUE) -> void:
	if value <= 0 or not player.is_inside_tree():
		return
	var a := randf() * TAU
	var d := randf_range(Balance.MOTE_SCATTER_MIN, Balance.MOTE_SCATTER_MAX)
	var at := Vector3(near.x + cos(a) * d, Combat.feet_y(player), near.z + sin(a) * d)
	_mote_seq += 1
	var key := "m%d" % _mote_seq
	var life := mote_time()
	_motes.append({"key": key, "pos": at, "until": Time.get_ticks_msec() / 1000.0 + life, "value": value})
	LIGHT_MOTE.spawn(player.get_tree().current_scene, at, key, true, life)
	player._net_fx("motes", at, null, {"k": key, "t": life})
	# Too many: the oldest fades.
	while _motes.size() > Balance.MOTE_MAX:
		var old: Dictionary = _motes.pop_front()
		LIGHT_MOTE.clear(player.get_tree(), str(old["key"]))
		player._net_fx("motes", player.global_position, null, {"k": str(old["key"])})

## Where an enemy stands (or I do, with none).
func _mote_spot(e: Variant) -> Vector3:
	if e != null and is_instance_valid(e) and e is Node3D:
		return e.global_position
	return player.global_position

## Pick up the mote at index `i`: its Incense, a little healing, the Bright Burst.
func _pick_up_mote(i: int) -> void:
	var m: Dictionary = _motes[i]
	_motes.remove_at(i)
	LIGHT_MOTE.take(player.get_tree(), str(m["key"]), player)
	player._net_fx("motes", player.global_position, null, {"k": str(m["key"])})
	_gain_incense(int(m.get("value", Balance.MOTE_VALUE)))
	if player.health < player.max_health:
		player.heal(Balance.MOTE_HEAL_SHARE * Balance.REFERENCE_HEAL * (1.0 + player._talent("holy_bright_motes") / 100.0), LIGHT_MOTE_ID)   # + Bright Motes
	if player._has_rune(BRIGHT_BURST_RUNE):
		_bright_burst()

## Rune of the Bright Burst: a burst of light around me (a proc with its own line).
func _bright_burst() -> void:
	var hit := player._enemies_within(Balance.BRIGHT_BURST_RADIUS)
	var coef := Balance.BRIGHT_BURST_DAMAGE * Balance.aoe_share(hit.size())
	for e in hit:
		_censer_proc_hit(e, coef, BRIGHT_BURST_ID, Balance.BRIGHT_BURST_THREAT)
	player._ring_effect(Balance.BRIGHT_BURST_RADIUS, CENSER.LIGHT)

## A Holy proc hit of the censer (aura, Bright Burst): high threat, feeds nothing.
func _censer_proc_hit(e: Node, coef: float, id: String, threat: float) -> void:
	if not is_instance_valid(e) or not e.is_alive() or coef <= 0.0:
		return
	var hit := DamageInfo.make(player, e, coef, id)
	hit.tags = PackedStringArray(CENSER_TAGS)
	hit.damage_type = "holy"
	hit.threat_multiplier = threat
	hit.is_proc = true
	hit.no_empower = true
	player._combat().deal(hit)

## Every frame: motes picked up or faded, Unfallen ending, the aura, the raised
## censer, the censer fading out of combat, the party told again now and then.
func _tick_censer() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# Motes: walk over one to pick it up (my own only).
	if not _motes.is_empty():
		var reach := mote_reach()
		var i := _motes.size() - 1
		while i >= 0:
			var m: Dictionary = _motes[i]
			var p: Vector3 = m["pos"]
			if now >= float(m["until"]):
				_motes.remove_at(i)
			elif not player.is_dead() and Vector2(player.global_position.x - p.x, player.global_position.z - p.z).length() <= reach:
				_pick_up_mote(i)
			i = mini(i - 1, _motes.size() - 1)
	# Unfallen ran out: heal for part of what I took.
	var unfallen_now: bool = player.status != null and player.status.has(UNFALLEN_FX)
	if _unfallen_was and not unfallen_now:
		var back := unfallen_heal(_unfallen_taken)
		_unfallen_taken = 0
		if back > 0 and not player.is_dead():
			player._combat().heal(player, player, float(back), UNFALLEN_ID, true)
	_unfallen_was = unfallen_now
	if not _censer_on:
		return
	# Raised: it sheds motes, then comes back with what it kept.
	if censer_raised():
		if now >= _raise_next_shed:
			_raise_next_shed = now + Balance.RAISE_CENSER_SHED_EVERY
			_drop_mote(_raise_at)
		if now >= _raised_until:
			_end_raise()
	elif incense() > 0 and player.in_combat and now >= _aura_next:
		_aura_next = now + Balance.INCENSE_AURA_EVERY
		var hit := player._enemies_within(Balance.INCENSE_AURA_RADIUS)
		var coef := incense_aura_coef(incense()) * Balance.aoe_share(hit.size())
		for e in hit:
			_censer_proc_hit(e, coef, INCENSE_AURA_ID, Balance.INCENSE_AURA_THREAT)
	# Out of combat it fades a little later.
	if player.in_combat or censer_raised():
		_censer_off_at = 0.0
	elif _censer_off_at <= 0.0:
		_censer_off_at = now + Balance.CENSER_LINGER
	elif now >= _censer_off_at:
		_censer_on = false
		_censer_off_at = 0.0
		_sync_censer()
		return
	if now - _censer_told >= CENSER_RETELL:
		_tell_censer()

## My buffs changed (or the censer did): the picture shows it, and the party is told.
func _sync_censer() -> void:
	var n := incense()
	if n == _censer_shown and _censer_on == _censer_shown_on:
		return
	_censer_shown = n
	_censer_shown_on = _censer_on
	if _censer_on or player.get_node_or_null(CENSER.NODE_NAME) != null:
		CENSER.show_on(player, n, _censer_on)
	_tell_censer()

func _tell_censer() -> void:
	_censer_told = Time.get_ticks_msec() / 1000.0
	player._net_fx("censer", player.global_position, null, {"n": maxi(_censer_shown, 0), "on": _censer_on})

## Something hit me (_on_hit_taken): a little Incense, more for a block; the
## barrier flashes on a block; Unfallen counts what I took.
func _censer_hit_taken(info: RefCounted) -> void:
	if player.status != null and player.status.has(UNFALLEN_FX) and not info.blocked:
		_unfallen_taken += maxi(int(info.amount), 0)
	if not _censer_on or bool(info.is_dot) or bool(info.dodged) or bool(info.parried):
		return
	_gain_incense(incense_for_hit(bool(info.blocked), player.status.has(UNFALLEN_FX)))
	if info.blocked:
		CENSER.flash(player)
		player._net_fx("censer_flash", player.global_position)

## take_damage: during Unfallen nothing can kill me.
func _unfallen_cap(amount: int) -> int:
	if player.status == null or not player.status.has(UNFALLEN_FX):
		return amount
	return unfallen_limit(amount, player.health)

## Why a censer ability can't be used right now ("" = it can).
func _censer_precheck(id: String) -> String:
	match id:
		POUR_OUT_ID, AUREOLE_ID:
			if censer_raised():
				return "Your censer is raised"
			var need := Balance.POUR_OUT_MIN if id == POUR_OUT_ID else Balance.AUREOLE_COST
			if incense() < need:
				return "Your censer holds too little light"
		ABSOLVE_ID:
			if censer_raised():
				return "Your censer is raised"
			if incense() <= 0:
				return "Your censer is empty"
			if player.health >= player.max_health:
				return "Already at full health"
		GATHER_ID:
			if _motes.is_empty():
				return "You have no motes of light"
		RAISE_CENSER_ID:
			if censer_raised():
				return "Your censer is already raised"
	return ""

## One of the censer's abilities (paid for and put on cooldown by _use_drafted).
func _censer_use(id: String, res: Resource) -> void:
	_censer_appear()
	var col := CENSER.LIGHT
	var near := _mote_spot(player.target if player._has_valid_target() else null)
	match id:
		CENSER_SWING_ID:
			player.deal_damage(player.target, float(res.damage), id)
			player._slash_effect(col)
			_gain_incense(Balance.CENSER_SWING_INCENSE + int(round(player._talent("holy_heavy_chain"))))   # + Heavy Chain
			_drop_mote(near)
		HALLOWED_ARC_ID:
			var reach := float(res.radius) + Abilities.radius_bonus(id)   # + Wide Arc
			var hit := player._enemies_within(reach)
			var coef := float(res.damage) * Balance.aoe_share(hit.size())
			var loose := 0
			for e in hit:
				if not is_instance_valid(e) or not e.is_alive():
					continue
				player.deal_damage(e, coef, id)
				if loose < Balance.HALLOWED_ARC_MOTES:
					_drop_mote(e.global_position)
					loose += 1
			_gain_incense(Balance.HALLOWED_ARC_INCENSE * hit.size())
			player._ring_effect(reach, col)
			player._ring_effect(reach * 0.6, CENSER.GOLD)
		BECKON_ID:
			player.deal_damage(player.target, float(res.damage), id)
			_gain_incense(Balance.BECKON_INCENSE)
			_drop_mote(near)
			player._ring_effect(0.8, col, near)
		POUR_OUT_ID:
			_pour_out(res)
		ABSOLVE_ID:
			var spent := _spend_incense(Balance.ABSOLVE_MAX, near)
			if spent > 0:
				player.heal(Balance.ABSOLVE_PER_STACK * Balance.REFERENCE_HEAL * float(spent) * (1.0 + player._talent("holy_absolution") / 100.0), id)   # + Absolution
			player._ring_effect(1.2, Color(0.45, 1.0, 0.5))
			player._ring_effect(0.8, col)
		AUREOLE_ID:
			_spend_incense(Balance.AUREOLE_COST, near)
			var blaze := StatusContainer.make_buff(AUREOLE_FX, Abilities.ability_name(id), Stats.BLOCK, Balance.AUREOLE_BLOCK,
				Balance.AUREOLE_TIME, 1, col)
			blaze.tags = PackedStringArray(["Holy"])
			blaze.description = "Your barrier of light blazes: more Block."
			player.status.apply(blaze, player)
			CENSER.flash(player)
			player._ring_effect(1.3, col)
		GATHER_ID:
			while not _motes.is_empty():
				_pick_up_mote(_motes.size() - 1)
			player._ring_effect(1.5, col)
		RAISE_CENSER_ID:
			_raise_censer(res)
		UNFALLEN_ID:
			var fx := StatusContainer.make_buff(UNFALLEN_FX, Abilities.ability_name(id), Stats.BLOCK, 0.0, Balance.UNFALLEN_TIME + player._talent("holy_unbroken"), 1, col)   # + Unbroken
			fx.stat_modifiers = {}
			fx.tags = PackedStringArray(["Holy"])
			fx.description = "Nothing can kill you. Hits give more Incense. When it ends, you heal for part of the damage you took."
			_unfallen_taken = 0
			player.status.apply(fx, player)
			player._ring_effect(1.6, col)
			player._ring_effect(1.0, Color(1, 1, 1))

## Pour Out: every bit of Incense in one wave of light around me. More than
## AOE_TARGET_CAP enemies share that many hits' damage.
func _pour_out(res: Resource) -> void:
	var have := incense()
	var pct := Balance.DEEP_POUR_MOTE_PCT if player._capstone("holy_deep_pour") else Balance.MOTE_SPEND_PCT   # Deep Pour's capstone
	var reach := float(res.radius)
	var hit := player._enemies_within(reach)
	var per := Balance.POUR_OUT_PER_STACK * (1.0 + player._talent("holy_deep_pour") / 100.0)   # Deep Pour
	var coef := per * float(have) * Balance.aoe_share(hit.size())
	for e in hit:
		if is_instance_valid(e) and e.is_alive():
			player.deal_damage(e, coef, POUR_OUT_ID)
	_spend_incense(have, _mote_spot(hit[0] if not hit.is_empty() else null), pct)
	player._ring_effect(reach, CENSER.LIGHT)
	player._ring_effect(reach * 0.66, Color(1, 1, 1))
	player._ring_effect(reach * 0.33, CENSER.GOLD)

## Raise the Censer: it rises over my target and hangs there. Enemies around it
## must attack me for a while, and it sheds motes; my Incense is kept for later
## and gives no Block or aura meanwhile.
func _raise_censer(res: Resource) -> void:
	var spot: Node3D = player.target if player._has_valid_target() else player
	_raise_at = Vector3(spot.global_position.x, Combat.feet_y(spot), spot.global_position.z)
	var now := Time.get_ticks_msec() / 1000.0
	var kept: int = player.status.stacks_of(INCENSE_FX)
	_raised_until = now + Balance.RAISE_CENSER_TIME   # (first: incense() reads the stash from here on)
	_incense_stash = kept
	player.status.remove(INCENSE_FX)
	_raise_next_shed = now + Balance.RAISE_CENSER_SHED_EVERY
	for e in player._enemies_near(_raise_at, float(res.radius)):
		player._net_taunt(e, Balance.RAISE_CENSER_TAUNT)
	CENSER.raise(player, _raise_at, Balance.RAISE_CENSER_HEIGHT, Balance.RAISE_CENSER_TIME, float(res.radius))
	_censer_told = now
	player._net_fx("censer", _raise_at, null, {"n": _incense_stash, "on": true, "up": Balance.RAISE_CENSER_TIME,
		"h": Balance.RAISE_CENSER_HEIGHT, "r": float(res.radius)})
	player._ring_effect(float(res.radius), CENSER.LIGHT, _raise_at)

## The raised censer comes back: what it kept is Incense again.
func _end_raise() -> void:
	_raised_until = 0.0
	var back := _incense_stash
	_incense_stash = 0
	if back > 0:
		_gain_incense(back)
	_sync_censer()

