extends "res://scripts/player/player_kit.gd"
class_name NatureTalentsOpenKit

# Hooked up from player.gd through its var "nature_open".
# --- Nature: the open talents, and the spec talents that change hits ----------------------
# Talents of the Nature book that work with every book's spells and abilities:
# Rough Bark (more Armor: a "stats" bonus in talents.gd), Green Thumb (my heals
# over time heal more: Abilities.HEAL_OVER_TIME_IDS), Undergrowth (my damage
# over time hits an enemy I rooted, held or slowed harder), Clinging Vines (a root
# or hold of mine that runs out leaves the enemy slowed: StatusContainer calls
# root_ended), Startle (my first hit on an enemy at full health), Pack Hunter (an
# enemy that is attacking someone else), Tending (my heals on an ally with one of
# my heals over time), Food Chain (a kill heals me) and Hibernate (faster regen out
# of combat: Player._tick_health_regen, _tick_resources). Also the spec talents
# that change hits, heals and costs (each spec's own rules are in its component):
#   Thornweaver  Overgrown, Tight Weave, Old Roots, Steady Weave, Hunted, Lush
#   Shepherd     In Full Flower, New Shoots, Soft Weave, Patient Hands, Morning Mist
#   Colossus     Old Growth, Heavy Limbs, Creaking Bark, Called Out (taunts)
#   Venomstring  Virulent, Final Bite, Running Venom, Dragging Feet, Full Brew
# Own only. Numbers: balance.gd and talents.gd.

const SNAGGED_FX := preload("res://data/effects/snagged.tres")
const SNAGGED_TAGS := ["Nature"]
## The woven creatures' hits and heals, and the rooted creatures' hits (no ability tags them).
const WOVEN_HIT_IDS := ["briartiger", "thornwing", "owlstrike"]
const WOVEN_HEAL_IDS := ["fawn", "wildherd", "owl"]
const ROOTED_HIT_IDS := ["mossback", "chokingvipers", "greenwoodstag"]
## Venomstring's poisons (each is its arrow's id on the meter).
const POISON_IDS := ["adderarrow", "asparrow", "kraitarrow"]
## Nature's holds (Firm Hold): held in place, not a root of another book.
const HOLD_EFFECTS := ["grasped", "choked", "coiled"]
const FOOD_CHAIN_ID := "food_chain"
var _called_out_frame := -1   # Called Out: the frame of the last taunt that counted ...
var _called_out_n := 0        # ... and how many enemies it has counted in that frame

## Green Thumb: how much more a heal of `id` heals with `pct` % (only heals over time).
static func green_thumb_mult(id: String, pct: float) -> float:
	return 1.0 + maxf(pct, 0.0) / 100.0 if Abilities.HEAL_OVER_TIME_IDS.has(id) else 1.0

## Undergrowth: does a hit get it? Damage over time on an enemy carrying my own
## root, hold or slow.
static func undergrowth_applies(is_dot: bool, my_cc_on_it: bool) -> bool:
	return is_dot and my_cc_on_it

## Overgrown: does a hit with `tags` count? My Nature spells.
static func overgrown_applies(tags: PackedStringArray) -> bool:
	return tags.has("Nature") and tags.has("Spell")

## Stacks of Clinging Vines' slow at `pct` % slower (one per CLINGING_VINES_SLOW_STEP).
static func snagged_stacks(pct: float) -> int:
	return clampi(int(round(maxf(pct, 0.0) / Balance.CLINGING_VINES_SLOW_STEP)), 0, 2)

## Is `id` a heal of the Nature book (a heal or a shield of one of its spells)?
static func nature_heal(id: String) -> bool:
	return Abilities.category_of(id) == "nature" and Abilities.HEALS.has(id)

## Lush: the mana cost of `id` with `pct` % off (my Nature spells that deal damage).
static func lush_mult(id: String, pct: float) -> float:
	var r := Abilities.get_resource(id)
	if pct <= 0.0 or r == null or Abilities.category_of(id) != "nature" or not r.tags.has("Spell") or float(r.damage) <= 0.0:
		return 1.0
	return 1.0 - pct / 100.0

## Morning Mist: the mana cost of `id` with `pct` % off (my Nature heals).
static func mist_mult(id: String, pct: float) -> float:
	return 1.0 - maxf(pct, 0.0) / 100.0 if nature_heal(id) else 1.0

## Steady Weave: does a hit of `id` count? A Nature spell's own hit, one with a cast time.
static func steady_weave_applies(id: String, tags: PackedStringArray, is_proc: bool, is_dot: bool) -> bool:
	var r := Abilities.get_resource(id)
	return r != null and tags.has("Nature") and tags.has("Spell") and not is_proc and not is_dot and float(r.cast_time) > 0.0

## Heavy Limbs: does a hit of `id` count? The own hit of a Nature ability that costs Fury.
static func heavy_limbs_applies(id: String, tags: PackedStringArray, is_proc: bool) -> bool:
	return tags.has("Nature") and tags.has("Ability") and not is_proc and Abilities.resource_of(id) == "fury" and float(Abilities.cost_of(id)) > 0.0

## Is a share of `health` out of `max_health` below `pct` % (Hunted, Final Bite)?
static func below(health: float, max_health: float, pct: float) -> bool:
	return max_health > 0.0 and health / max_health * 100.0 < pct

## A bow shot: an arrow of an ability or an auto-shot (not a poison's tick).
static func bow_shot(id: String, tags: PackedStringArray, is_dot: bool) -> bool:
	return not is_dot and (tags.has("Ranged") or id == "auto_ranged")

## Startle: does a hit count? A spell's or an ability's own hit on an enemy at full health.
static func startle_applies(id: String, is_proc: bool, is_dot: bool, health: float, max_health: float) -> bool:
	return Abilities.PATHS.has(id) and not is_proc and not is_dot and max_health > 0.0 and health >= max_health

## Groundswell: Fury a Nature ability `id` builds, `amount` with `pct` % more.
static func groundswell_fury(id: String, amount: float, pct: float) -> float:
	var tags := Abilities.tags_of(id)
	if pct <= 0.0 or Abilities.resource_of(id) != "fury" or not (tags.has("Nature") and tags.has("Ability")):
		return amount
	return amount * (1.0 + pct / 100.0)

## Called Out: Fury for the `n`-th enemy one taunt hits (none past CALLED_OUT_ENEMIES).
static func called_out_fury(n: int, per: float) -> float:
	return maxf(per, 0.0) if n >= 1 and n <= Balance.CALLED_OUT_ENEMIES else 0.0

## A hit of mine, before its damage is worked out (_on_damage_modify): Undergrowth,
## Overgrown and the other Nature talents that change hits.
func _nature_talents_outgoing(info: RefCounted) -> void:
	var id := str(info.ability_id)
	var proc := bool(info.is_proc)
	var dot := bool(info.is_dot)
	_nature_spec_hits(info, id, proc, dot)
	if info.target != null and is_instance_valid(info.target) and info.target is Node:
		_nature_target_hits(info, info.target as Node, id, proc, dot)
	var under := player._talent("nature_undergrowth")
	if under > 0.0 and bool(info.is_dot) and info.target != null and is_instance_valid(info.target) and info.target is Node:
		var st: Node = (info.target as Node).get_node_or_null("Status")
		if undergrowth_applies(true, st != null and st.has_method("has_cc_from") and st.has_cc_from(player)):
			info.add_bonus(under, "Undergrowth")
	var over := player._talent("nature_overgrown")
	if over > 0.0 and overgrown_applies(info.tags):
		var pct := WeaverKit.overgrown_pct(over, player.weaver.mulch().size())
		if pct > 0.0:
			info.add_bonus(pct, "Overgrown")

## The spec talents that look only at the hit: Tight Weave, Old Roots, Steady Weave,
## Heavy Limbs and Creaking Bark (threat), Virulent, Running Venom.
func _nature_spec_hits(info: RefCounted, id: String, proc: bool, dot: bool) -> void:
	var tight := player._talent("nature_tight_weave")
	if tight > 0.0 and WOVEN_HIT_IDS.has(id):
		info.add_bonus(tight, "Tight Weave")
	var roots := player._talent("nature_old_roots")
	if roots > 0.0 and ROOTED_HIT_IDS.has(id):
		info.add_bonus(roots, "Old Roots")
	var steady := player._talent("nature_steady_weave")
	if steady > 0.0 and steady_weave_applies(id, info.tags, proc, dot):
		info.add_bonus(steady, "Steady Weave")
	var limbs := player._talent("nature_heavy_limbs")
	if limbs > 0.0 and heavy_limbs_applies(id, info.tags, proc):
		info.add_bonus(limbs, "Heavy Limbs")
	var bark := player._talent("nature_creaking_bark")
	if bark > 0.0 and info.tags.has("Nature") and info.tags.has("Ability"):
		info.threat_multiplier *= 1.0 + bark / 100.0
	var virulent := player._talent("nature_virulent")
	if virulent > 0.0 and dot and POISON_IDS.has(id):
		info.add_bonus(virulent, "Virulent")
	var running := player._talent("nature_running_venom")
	if running > 0.0 and bow_shot(id, info.tags, dot) and player.venomstring.venom_flowing_now():
		info.add_bonus(running, "Running Venom")

## The talents that look at the enemy hit: Hunted, Final Bite, Dragging Feet, Full
## Brew, Startle, Pack Hunter.
func _nature_target_hits(info: RefCounted, foe: Node, id: String, proc: bool, dot: bool) -> void:
	var hp: Variant = foe.get("health")
	var max_hp: Variant = foe.get("max_health")
	var h := float(hp) if hp != null else 0.0
	var mh := float(max_hp) if max_hp != null else 0.0
	var hunted := player._talent("nature_hunted")
	if hunted > 0.0 and WOVEN_HIT_IDS.has(id) and below(h, mh, Balance.HUNTED_HEALTH_PCT):
		info.add_bonus(hunted, "Hunted")
	var bite := player._talent("nature_final_bite")
	if bite > 0.0 and dot and POISON_IDS.has(id) and below(h, mh, Balance.FINAL_BITE_HEALTH_PCT):
		info.add_bonus(bite, "Final Bite")
	var feet := player._talent("nature_dragging_feet")
	if feet > 0.0 and bow_shot(id, info.tags, dot):
		var st: Node = foe.get_node_or_null("Status")
		if st != null and st.has_method("has_slow_from") and st.has_slow_from(player):
			info.add_bonus(feet, "Dragging Feet")
	var brew := player._talent("nature_full_brew")
	if brew > 0.0 and not dot and not proc and player.venomstring.poisons_on(foe).size() >= 3:
		info.add_bonus(brew, "Full Brew")
	var startle := player._talent("nature_startle")
	if startle > 0.0 and startle_applies(id, proc, dot, h, mh):
		info.add_bonus(startle, "Startle")
	var pack := player._talent("nature_pack_hunter")
	if pack > 0.0 and foe.has_method("top_threat"):
		var on: Variant = foe.top_threat()
		if on != null and is_instance_valid(on) and not is_same(on, player):
			info.add_bonus(pack, "Pack Hunter")

## What a heal of mine (`id`, on `tgt`) is multiplied by: In Full Flower, New
## Shoots, Soft Weave, Patient Hands, Tending (StringsKit._heal_coef asks).
func heal_mult(tgt: Variant, id: String) -> float:
	var m := 1.0
	if tgt == null or not is_instance_valid(tgt):
		return m
	var n: int = player.shepherd.blossoms_on(tgt)
	if n >= Balance.BLOSSOM_MAX:
		m *= 1.0 + player._talent("nature_in_full_flower") / 100.0
	if n <= 0 and nature_heal(id):
		m *= 1.0 + player._talent("nature_new_shoots") / 100.0
	if WOVEN_HEAL_IDS.has(id):
		m *= 1.0 + player._talent("nature_soft_weave") / 100.0
	var r := Abilities.get_resource(id)
	if nature_heal(id) and r != null and float(r.cast_time) > 0.0:
		m *= 1.0 + player._talent("nature_patient_hands") / 100.0
	var tend := player._talent("nature_tending")
	if tend > 0.0 and carries_my_hot(tgt):
		m *= 1.0 + tend / 100.0
	return m

## Tending: does `who` carry one of my heals over time? (Refrain, a String, my
## Blossoms while Evergreen heals with them; on me: my Sap.)
func carries_my_hot(who: Variant) -> bool:
	if who == null or not is_instance_valid(who) or not (who is Node):
		return false
	if player.hymns._refrains.has((who as Node).get_instance_id()) or player.strings.on_my_string(who):
		return true
	if player._talent("nature_evergreen") > 0.0 and player.shepherd.blossoms_on(who) > 0:
		return true
	return is_same(who, player) and player.colossus.sap() > 0

## I taunted an enemy (Player._net_taunt). Called Out: Fury for the first few enemies of each taunt.
func called_out() -> void:
	var per := player._talent("nature_called_out")
	if per <= 0.0:
		return
	var frame := Engine.get_physics_frames()
	if frame != _called_out_frame:
		_called_out_frame = frame
		_called_out_n = 0
	_called_out_n += 1
	var fury := called_out_fury(_called_out_n, per)
	if fury > 0.0:
		player._gain("fury", fury)

## Firm Hold: a hold of mine went on an enemy, so I get Fury.
func firm_hold_fury() -> void:
	var back := player._talent("nature_firm_hold", "values2")
	if back > 0.0:
		player._gain("fury", back)

## Food Chain: what an enemy I damaged dying heals me for (`pct` % of `max_hp`).
static func food_chain_heal(max_hp: int, pct: float) -> int:
	return int(round(float(maxi(max_hp, 0)) * maxf(pct, 0.0) / 100.0))

## An enemy died (SignalBus.enemy_died; connected before Carrion, which forgets whom I hit).
func _on_enemy_died_nature(enemy: Node) -> void:
	var pct := player._talent("nature_food_chain")
	if pct <= 0.0 or enemy == null or not is_instance_valid(enemy) or player.is_dead() or player.health >= player.max_health:
		return
	var by_me: bool = enemy.has_method("killed_by_me") and bool(enemy.killed_by_me())
	if not by_me and not player.shadow_talents._first_hit.has(enemy.get_instance_id()):
		return
	var amount := food_chain_heal(player.max_health, pct)
	if amount > 0:
		player._combat().heal(player, player, float(amount), FOOD_CHAIN_ID, true)

## Hibernate: how many times as fast health and mana come back out of combat.
func hibernate_mult() -> float:
	return 1.0 + player._talent("nature_hibernate") / 100.0

## A hit on me, before its damage is worked out: Old Growth (less per Sap).
func _nature_talents_incoming(info: RefCounted) -> void:
	var per := player._talent("nature_old_growth")
	if per > 0.0:
		var pct := ColossusKit.old_growth_pct(player.colossus.sap(), per)
		if pct > 0.0:
			info.add_bonus(-pct, "Old Growth")

## A root or hold of mine on `foe` ran out (StatusContainer): Clinging Vines slows it.
func root_ended(foe: Node, _res: Resource) -> void:
	var n := snagged_stacks(player._talent("nature_clinging_vines"))
	if n <= 0 or foe == null or not is_instance_valid(foe) or not foe.is_in_group("enemies"):
		return
	if foe.has_method("is_alive") and not foe.is_alive():
		return
	# (Each application adds a stack: at rank 1 one already on it stays as it is,
	# so it never reaches the rank-2 slow.)
	var st: Node = foe.get_node_or_null("Status")
	if n < 2 and st != null and st.has_from(str(SNAGGED_FX.id), player):
		return
	for i in n:
		player._combat().apply_effect(player, foe, SNAGGED_FX, "", PackedStringArray(SNAGGED_TAGS))
