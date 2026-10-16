extends "res://scripts/player/player_kit.gd"
class_name DuskTillDawnKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "dusk_till_dawn".
# --- Dusk till Dawn (Legendary rune): Dusk, then Dawn ------------------------------------
# With the rune on my gear, dealing Shadow damage of any kind (damage over time
# and procs too) gives me Dusk: more Shadow damage for DUSK_TIME. Nothing
# refreshes Dusk. When it runs out Dawn starts: more Holy damage for DAWN_TIME.
# Shadow damage starts the next Dusk only once Dawn is over, so the two take
# turns and are never up together. Both are my own buffs. The numbers are in
# balance.gd.

const DUSK_RUNE := "dusk_till_dawn"
const DUSK_ID := "dusk"
const DAWN_ID := "dawn"
const DUSK_COLOR := Color(0.55, 0.4, 0.85)
const DAWN_COLOR := Color(1.0, 0.85, 0.45)
var _dusk_fx: Resource
var _dawn_fx: Resource
var _dusk_until := 0.0   # seconds: when the Dusk I have runs out on its own (0 = I have none)

## Does a hit of mine start Dusk? Any Shadow damage that lands, while I have
## neither Dusk nor Dawn.
static func starts_dusk(damage_type: String, amount: int, has_dusk: bool, has_dawn: bool) -> bool:
	return damage_type == "shadow" and amount > 0 and not has_dusk and not has_dawn

## My Dusk is gone: does Dawn follow? Only when it ran its whole time (not when
## dying or leaving cleared it) and the rune is still on my gear.
static func dawn_follows(now: float, dusk_until: float, has_rune: bool) -> bool:
	return has_rune and dusk_until > 0.0 and now >= dusk_until - 0.25

## Dusk: more Shadow damage of every kind. It runs its time; nothing refreshes it.
static func make_dusk_fx() -> Resource:
	var fx := StatusContainer.make_buff(DUSK_ID, "Dusk", DUSK_ID, 0.0, Balance.DUSK_TIME, 1, DUSK_COLOR)
	fx.stat_modifiers = {}
	fx.stack_mode = 2   # IGNORE
	fx.tags = PackedStringArray(["Shadow"])
	fx.damage_mod_pct = Balance.DUSK_DAMAGE_PCT
	fx.mod_damage_types = PackedStringArray(["shadow"])
	fx.mod_affects_dots = true
	fx.description = "You deal %s%% more Shadow damage. When Dusk ends you gain Dawn." % Stats.num(Balance.DUSK_DAMAGE_PCT)
	return fx

## Dawn: more Holy damage of every kind. No Dusk can start while it lasts.
static func make_dawn_fx() -> Resource:
	var fx := StatusContainer.make_buff(DAWN_ID, "Dawn", DAWN_ID, 0.0, Balance.DAWN_TIME, 1, DAWN_COLOR)
	fx.stat_modifiers = {}
	fx.stack_mode = 2   # IGNORE
	fx.tags = PackedStringArray(["Holy"])
	fx.damage_mod_pct = Balance.DAWN_DAMAGE_PCT
	fx.mod_damage_types = PackedStringArray(["holy"])
	fx.mod_affects_dots = true
	fx.description = "You deal %s%% more Holy damage. Dusk cannot start until Dawn ends." % Stats.num(Balance.DAWN_DAMAGE_PCT)
	return fx

## A hit of mine landed (called for every one, from _on_damage_dealt_shadow).
func _dusk_on_hit(info: RefCounted) -> void:
	if player.status == null or not player.frost_melee._has_rune(DUSK_RUNE):
		return
	var has_dusk: bool = _dusk_until > 0.0 or player.status.has(DUSK_ID)
	if not starts_dusk(str(info.damage_type), int(info.amount), has_dusk, player.status.has(DAWN_ID)):
		return
	if _dusk_fx == null:
		_dusk_fx = make_dusk_fx()
	if player.status.apply(_dusk_fx, player):
		_dusk_until = Time.get_ticks_msec() / 1000.0 + float(player.status.remaining_of(DUSK_ID))

## Every frame: the moment my Dusk runs out, Dawn starts.
func _tick_dusk() -> void:
	if _dusk_until <= 0.0 or player.status == null or player.status.has(DUSK_ID):
		return
	var until := _dusk_until
	_dusk_until = 0.0
	if not dawn_follows(Time.get_ticks_msec() / 1000.0, until, player.frost_melee._has_rune(DUSK_RUNE)):
		return
	if _dawn_fx == null:
		_dawn_fx = make_dawn_fx()
	player.status.apply(_dawn_fx, player)

