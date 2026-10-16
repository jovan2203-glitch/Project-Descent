extends "res://scripts/player/player_kit.gd"
class_name FireMeleeKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "fire_melee".
# --- Heat (Fire melee) ------------------------------------------------------------------------
# Every melee hit of mine (auto-attacks and abilities; not procs, not ticks) on a
# target carrying MY Immolate builds a stack of Heat: once per swing, however
# many enemies it hit. Searing Strike builds SEARING_STRIKE_HEAT (Kindling may add
# one more). Each stack makes my Fire ABILITIES (not spells) hit harder. A new
# stack restarts the HEAT_TIME timer; when that runs out all of it is lost. Crits
# play no part. Flare spends some, Quench removes it all for bonus damage.
# Only my own Immolate counts: another player's never builds my Heat.

const HEAT_ID := "heat"
const AFTERGLOW_ID := "afterglow"
var _heat_fx: Resource
var _heat_last := ""   # "<ability>@<frame>" of the last swing that built Heat

func heat_stacks() -> int:
	return int(player.status.stacks_of(HEAT_ID)) if player.status else 0

## Heat an ability needs to be used (Quench, Flare); 0 for everything else.
static func heat_needed(id: String) -> int:
	match id:
		"quench":
			return Balance.QUENCH_MIN_HEAT
		"flare":
			return Balance.FLARE_HEAT_COST
	return 0

## Heat one swing of `ability_id` builds on a target with my Immolate (before Kindling).
static func heat_from(ability_id: String) -> int:
	if heat_needed(ability_id) > 0:
		return 0   # the Heat spenders build none
	return Balance.SEARING_STRIKE_HEAT if ability_id == "searingstrike" else 1

## White Heat (Fire talent): % more Fire damage my abilities deal while I hold
## `stacks` Heat, at `pct` per its rank. Only at the very top: one stack short is nothing.
static func white_heat_bonus(stacks: int, pct: float) -> float:
	return pct if stacks >= Balance.HEAT_MAX_STACKS else 0.0

## Quench's damage coefficient with `heat` stacks removed.
static func quench_coef(base: float, heat: int) -> float:
	return base * (1.0 + Balance.QUENCH_PCT_PER_HEAT / 100.0 * maxi(heat, 0))

## An Immolate with `left` seconds to go, fed `add` more: never above its base duration.
static func tinder_time(left: float, add: float, base: float) -> float:
	return minf(left + add, maxf(base, left))

## Fire damage Afterglow adds to an auto-attack that dealt `amount`.
static func afterglow_damage(amount: int, pct: float) -> float:
	return maxf(float(amount) * pct / 100.0, 0.0)

## Colour of a weapon swing at `stacks` Heat: steel, then orange, white-hot at the cap.
static func heat_tint(stacks: int) -> Color:
	var cold := Color(0.9, 0.95, 1.0)
	if stacks <= 0:
		return cold
	var t := clampf(float(stacks) / float(maxi(Balance.HEAT_MAX_STACKS, 1)), 0.0, 1.0)
	if t < 0.7:
		return cold.lerp(Color(1.0, 0.5, 0.12), t / 0.7)
	return Color(1.0, 0.5, 0.12).lerp(Color(1.0, 0.95, 0.7), (t - 0.7) / 0.3)

## The Heat buff: a stacking % bonus to Fire damage dealt by abilities.
## `time` = seconds without a new stack before it is lost (Forge Heat makes it longer).
static func make_heat_fx(time: float = Balance.HEAT_TIME) -> Resource:
	var fx := StatusContainer.make_buff(HEAT_ID, "Heat", HEAT_ID, 0.0,
		time, Balance.HEAT_MAX_STACKS, Color(1.0, 0.55, 0.15))
	fx.stat_modifiers = {}
	fx.damage_mod_pct = Balance.HEAT_DAMAGE_PCT
	fx.mod_damage_types = PackedStringArray(["fire"])
	fx.mod_required_tags = PackedStringArray(["Ability"])
	fx.mod_affects_dots = true   # an ability's burn (Searing Strike's Burning) counts too
	fx.description = "Your abilities deal %s%% more Fire damage per stack. All Heat is lost after %s sec without gaining a stack." % [
		Stats.num(Balance.HEAT_DAMAGE_PCT), Stats.num(time)]
	return fx

func _heat_stack_fx() -> Resource:
	var time := Balance.HEAT_TIME + player._talent("fire_forge_heat")   # Forge Heat
	if _heat_fx == null or not is_equal_approx(float(_heat_fx.duration), time):
		_heat_fx = make_heat_fx(time)
	return _heat_fx

## Add `n` stacks of Heat (every stack restarts its timer, also at the cap).
func gain_heat(n: int) -> void:
	for i in maxi(n, 0):
		player.status.apply(_heat_stack_fx(), player)

## A hit of mine landed: melee swings on a target with my Immolate build Heat.
func _heat_on_hit(info: RefCounted, tags: PackedStringArray) -> void:
	if info.is_proc or int(info.amount) <= 0 or not tags.has("Melee"):
		return
	var id := str(info.ability_id)
	var gain := heat_from(id)
	if gain <= 0 or info.target == null or not is_instance_valid(info.target):
		return
	var st: Node = info.target.get_node_or_null("Status")
	if st == null or not st.has_from("immolate", player):
		return
	var key := "%s@%d" % [id, Engine.get_process_frames()]
	if key == _heat_last:
		return   # the same swing hitting another enemy
	_heat_last = key
	if id == "searingstrike" and randf() * 100.0 < player._talent("fire_kindling"):
		gain += 1   # Kindling
	gain_heat(gain)

## Flare: a sweep in front of me. Its Heat is spent first (what is left still
## boosts it). Everything in the arc is hit - more than AOE_TARGET_CAP enemies
## share that many hits' damage - and my target's Immolate goes onto every enemy
## hit that doesn't carry mine yet (it never refreshes one that does).
func _flare(w: Dictionary, res: Resource) -> void:
	player.status.spend_stacks(HEAT_ID, Balance.FLARE_HEAT_COST)
	var has_target := player._has_valid_target()
	var tst: Node = player.target.get_node_or_null("Status") if has_target else null
	var spread: bool = tst != null and tst.has_from("immolate", player)
	var hit := player.fire_tank._enemies_in_cone(float(res.radius), Balance.FLARE_ARC)
	if has_target and not hit.has(player.target):
		hit.append(player.target)   # in weapon reach, but outside the sweep's
	var coef := player._weapon_hit(w, res) * Balance.aoe_share(hit.size())
	for e in hit:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var est: Node = e.get_node_or_null("Status")
		var had: bool = est != null and est.has_from("immolate", player)
		player.deal_damage(e, coef, "flare")
		if spread and not had and is_instance_valid(e) and e.is_alive():
			player.deal_damage(e, 0.0, "immolate", true)   # no damage: just its on-hit effect
	for i in 2:
		player._slash_effect(Abilities.color_of("flare"))
	player._cone_effect(float(res.radius), Balance.FLARE_ARC * 0.5, Abilities.color_of("flare"))

## Fresh Tinder: my Immolate on `tgt` lasts longer, up to its base duration.
## The tick timer is left alone, so it simply gets more ticks.
func _feed_immolate(tgt: Node) -> void:
	var st: Node = tgt.get_node_or_null("Status") if tgt != null and is_instance_valid(tgt) else null
	if st == null or not st.has_from("immolate", player):
		return
	var fx: Resource = Abilities.get_resource("immolate").on_hit_effect
	if fx == null:
		return
	var add := Balance.FRESH_TINDER_CAPSTONE_SECONDS if player.frost_melee._capstone("fire_fresh_tinder") else Balance.FRESH_TINDER_SECONDS
	var left: float = st.remaining_from("immolate", player)
	var fed := tinder_time(left, add, float(fx.duration) + player.effect_duration_bonus(fx))   # base duration incl. Long Burn
	if fed <= left + 0.001:
		return   # already at its base duration
	var net := player._net()
	if net:
		net.set_effect_remaining(tgt, player, "immolate", fed)   # the host owns enemy effects in a party
	else:
		st.set_remaining_from("immolate", player, fed)

## Afterglow talent: Quench leaves the weapon glowing for a few seconds.
func _start_afterglow() -> void:
	var fx := StatusContainer.make_buff(AFTERGLOW_ID, "Afterglow", AFTERGLOW_ID, 0.0,
		Balance.AFTERGLOW_TIME, 1, Color(1.0, 0.75, 0.3))
	fx.stat_modifiers = {}
	fx.description = "Your auto-attacks also deal %s%% of their damage as Fire damage." % Stats.num(player._talent("fire_afterglow"))
	player.status.apply(fx, player)

## An auto-attack of mine landed during Afterglow: part of it again, as Fire
## damage. An exact share of the swing (its crit is already in it), dealt as a
## proc: it builds no Heat and feeds nothing else.
func _afterglow_on_hit(info: RefCounted) -> void:
	if str(info.ability_id) != "auto_melee" or int(info.amount) <= 0 or not player.status.has(AFTERGLOW_ID):
		return
	var extra_dmg := afterglow_damage(int(info.amount), player._talent("fire_afterglow"))
	if extra_dmg <= 0.0 or info.target == null or not is_instance_valid(info.target) or not info.target.is_alive():
		return
	var extra := DamageInfo.make(player, info.target, 1.0, AFTERGLOW_ID)
	extra.unit = extra_dmg
	extra.exact = true
	extra.add_power = false
	extra.can_crit = false
	extra.can_block = false
	extra.is_proc = true
	extra.damage_type = "fire"
	extra.tags = PackedStringArray(["Fire", "Melee"])
	player._combat().deal(extra)

