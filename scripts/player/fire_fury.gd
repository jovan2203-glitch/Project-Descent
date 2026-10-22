extends "res://scripts/player/player_kit.gd"
class_name FireFuryKit

# --- Steady Flame's Fury ----------------------------------------------------------------
# The Fire caster runs on Fury (the 100-point bar). A Fire spell hit of mine that
# does NOT crit builds it: FIRE_FURY_BASE + crit chance x FIRE_FURY_PER_CRIT, once
# per cast however many enemies it hits (each Ember Volley ember is its own, at
# FIRE_FURY_EMBER_MULT). A Fire spell crit Vents FIRE_FURY_VENT_PCT% of it. So
# more crit chance means more Fury per non-crit, and more crits that throw it away.
# Ticks and procs count for neither, and spells that cost Fury build none. The
# crit chance used is the one before the spell's own changes (Player.adjust_crit
# stores it on the hit), so Tempered Flame, Cool Head and the Ember Volley choice
# never shrink the Fury gained. Fury doesn't decay while casting (Player._tick_resources).

const CRIT_META := "fury_crit"   # the hit's crit chance before the spell's own changes
const SEALED_RUNE := "sealed_kiln"

## Fury a Fire spell that didn't crit gives at a crit chance of `crit_pct`.
## `ember` = one Ember Volley ember; `stoked_pct` = Stoked Breath; `sealed` = Rune of the Sealed Kiln.
static func fury_gain(crit_pct: float, ember: bool, stoked_pct: float, sealed: bool) -> float:
	var g := Balance.FIRE_FURY_BASE + clampf(crit_pct, 0.0, 100.0) * Balance.FIRE_FURY_PER_CRIT
	if ember:
		g *= Balance.FIRE_FURY_EMBER_MULT
	g *= 1.0 + maxf(stoked_pct, 0.0) / 100.0
	if sealed:
		g *= 1.0 - Balance.SEALED_KILN_PCT / 100.0
	return g

## Fury a Fire spell crit Vents from `fury`, with Banked Coals at `banked_pct`.
static func vented(fury: float, banked_pct: float, sealed: bool) -> float:
	if sealed:
		return 0.0
	return maxf(fury, 0.0) * Balance.FIRE_FURY_VENT_PCT / 100.0 * (1.0 - clampf(banked_pct, 0.0, 100.0) / 100.0)

## Smoldering Focus: % more Fire spell damage while holding `fury` (`per` = the talent's value).
static func smolder_pct(fury: float, per: float) -> float:
	return maxf(fury, 0.0) * maxf(per, 0.0)

## Fury one Vent Flames spends out of `fury` (Rune of the Hair Trigger: half).
static func vent_spend(fury: float, hair_trigger: bool) -> float:
	return maxf(fury, 0.0) * (0.5 if hair_trigger else 1.0)

## Vent Flames' coefficient after spending `spent` Fury.
static func vent_coef(base: float, spent: float) -> float:
	return base * (1.0 + maxf(spent, 0.0) * Balance.VENT_FURY_PCT / 100.0)

## Blowback: the burn's whole coefficient when `vented` Fury is Vented at `pct`%.
static func blowback_coef(vented_fury: float, pct: float) -> float:
	return maxf(vented_fury, 0.0) * maxf(pct, 0.0) / 100.0 * Balance.BLOWBACK_PER_FURY

## Does `id` build Fury when it lands? (Not spells that cost it or spend it all.)
static func builds_fury(id: String) -> bool:
	if Abilities.SPENDS_ALL.has(id):
		return false
	return not (Abilities.resource_of(id) == "fury" and Abilities.cost_of(id) > 0.0)

func fury() -> float:
	return float(player.resources.get("fury", 0.0))

func _sealed() -> bool:
	return player.frost_melee._has_rune(SEALED_RUNE)

var _gain_last := ""   # "<ability>@<frame>" of the last cast that built Fury
var _vent_last := ""   # ... and of the last that Vented it
var _stay_lit := false   # a crit Vented: the next non-crit gives more (Stay Lit)
var last_spent := 0.0   # Fury the Vent Flames being dealt right now spent (Big Spend)

## A Fire spell hit of mine with damage landed (FireRunesKit._on_damage_dealt_fire).
func _fury_on_hit(info: RefCounted) -> void:
	var id := str(info.ability_id)
	# (Only Fire hits get here: of a split Frostfire Bolt, its Fire half.)
	if info.is_proc or info.is_dot or id == FireCasterKit.VENT_ID:
		return   # (Vent Flames' sure crit spends everything anyway)
	var ember := id == "embervolley"
	# Once per cast; every ember of a volley is its own.
	var key := "%s@%d" % [id, Engine.get_process_frames()]
	if ember:
		key = "embervolley#%d" % info.get_instance_id()
	if info.crit:
		if key == _vent_last:
			return
		_vent_last = key
		var v := vented(fury(), player._talent("fire_banked_coals"), _sealed())
		if v <= 0.0:
			return
		player._gain("fury", -v)
		_stay_lit = player._talent("fire_stay_lit") > 0.0
		_blowback(info.target, v)
		return
	if not builds_fury(id) or key == _gain_last:
		return
	_gain_last = key
	var chance := float(info.get_meta(CRIT_META, 0.0))
	var gain := fury_gain(chance, ember, player._talent("fire_stoked_breath"), _sealed())
	if _stay_lit:
		_stay_lit = false
		gain *= 1.0 + player._talent("fire_stay_lit") / 100.0   # Stay Lit
	player._gain("fury", gain)

## The crit chance a hit's Fury is worked out from (Player.adjust_crit, before the
## spell's own changes). Rune of the Dull Mind: as if crit weren't capped.
func store_crit(info: RefCounted, chance: float) -> void:
	if info.is_dot or str(info.damage_type) != "fire" or not info.tags.has("Spell"):
		return
	if player.frost_melee._has_rune("dull_mind"):
		chance = Stats.crit_chance(info.tags, func(s): return Stats.resolve(s, player._raw_stat))
	info.set_meta(CRIT_META, chance)

## Rune of the Hair Trigger is on (Vent Flames spends half).
func hair_trigger() -> bool:
	return player.frost_melee._has_rune("hair_trigger")

## Vent Flames: spend the Fury (all of it, or half with Hair Trigger) and hit.
func vent_flames(tgt: Node3D, base: float) -> void:
	var spent := vent_spend(fury(), hair_trigger())
	player._gain("fury", -spent)
	last_spent = spent   # (Big Spend)
	player.deal_damage(tgt, vent_coef(base, spent), FireCasterKit.VENT_ID)
	last_spent = 0.0

# --- Blowback (talent): a Vent burns the target with part of the Fury ----------------

var _burns: Array = []   # {"target", "per_tick", "ticks", "next"}

func _blowback(tgt: Variant, v: float) -> void:   # untyped: may be a freed enemy
	var pct := player._talent("fire_blowback")
	if pct <= 0.0 or tgt == null or not is_instance_valid(tgt) or not (tgt is Node) or not tgt.is_alive():
		return
	var ticks := maxi(int(round(Balance.BLOWBACK_TIME / Balance.BLOWBACK_TICK)), 1)
	_burns.append({"target": tgt, "per_tick": blowback_coef(v, pct) / ticks, "ticks": ticks,
		"next": Time.get_ticks_msec() / 1000.0 + Balance.BLOWBACK_TICK / player.haste_mult()})

func _tick_blowback() -> void:
	if _burns.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	for b in _burns.duplicate():
		var tgt: Variant = b["target"]
		if not is_instance_valid(tgt) or not tgt.is_alive() or int(b["ticks"]) <= 0:
			_burns.erase(b)
			continue
		if now < float(b["next"]):
			continue
		b["ticks"] = int(b["ticks"]) - 1
		b["next"] = float(b["next"]) + Balance.BLOWBACK_TICK / player.haste_mult()
		player._combat().deal_dot(player, tgt, float(b["per_tick"]), "fire", "blowback",
			PackedStringArray(["Fire", "Spell"]))

func clear() -> void:
	_burns.clear()
