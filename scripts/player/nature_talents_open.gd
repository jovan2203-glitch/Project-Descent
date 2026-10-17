extends "res://scripts/player/player_kit.gd"
class_name NatureTalentsOpenKit

# Hooked up from player.gd through its var "nature_open".
# --- Nature: the open talents, and the spec talents that change hits ----------------------
# Talents of the Nature book that work with every book's spells and abilities:
# Rough Bark (more Armor: a "stats" bonus in talents.gd), Green Thumb (my heals
# over time heal more: Abilities.HEAL_OVER_TIME_IDS), Undergrowth (my damage
# over time hits an enemy I rooted, held or slowed harder) and Clinging Vines (a root
# or hold of mine that runs out leaves the enemy slowed: StatusContainer calls
# root_ended). Also the spec talents that work on any hit: Overgrown (the
# Weaver's patches) and Old Growth (the Colossus' Sap). Own only. Numbers:
# balance.gd and talents.gd.

const SNAGGED_FX := preload("res://data/effects/snagged.tres")
const SNAGGED_TAGS := ["Nature"]

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

## A hit of mine, before its damage is worked out (_on_damage_modify): Undergrowth, Overgrown.
func _nature_talents_outgoing(info: RefCounted) -> void:
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
