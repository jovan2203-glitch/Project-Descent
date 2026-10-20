extends "res://scripts/player/player_kit.gd"
class_name FrostMoreKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "frost_more".
# --- Frost, second batch ------------------------------------------------------------------
# Coldspike, Sleetwave, Deepwinter, Rimelock, Snow Ward, Winter Hide, Rime Edge,
# Icebreaker and Icepin. Everything that asks about a Freeze asks about MINE
# (has_from); Snow Ward is the one that works for the whole party, by design.

const DEEPWINTER_ID := "deepwinter"
const WINTER_HIDE_ID := "winterhide"
const RIME_EDGE_ID := "rimeedge"
const SLEET_WAVE = preload("res://scripts/sleet_wave.gd")

## Chill `foe` without damage: a 0-damage hit carrying Chilled, so it works in a
## party too (and Deepwinter turns it into a Freeze like any other Chill).
func _chill(foe: Variant, id: String, tags: PackedStringArray = PackedStringArray(["Frost", "Spell"]),
		freeze: bool = false) -> void:
	if foe == null or not is_instance_valid(foe) or not (foe is Node) or not foe.is_in_group("enemies") or not foe.is_alive():
		return
	var info := DamageInfo.make(player, foe, 0.0, id)
	info.tags = tags
	info.damage_type = "frost"
	info.can_block = false
	info.can_crit = false
	info.add_power = false
	info.is_proc = true
	info.effects.append(FrostMeleeKit.FROZEN_FX if freeze else FrostRunesKit.CHILLED_FX)   # (freeze: Black Ice)
	player._combat().deal(info)

## Deepwinter: the effect one of my hits really applies. While it is up a Chill
## is a Freeze instead; everything else is left alone.
static func winter_swap(eff: Resource, deepwinter: bool) -> Resource:
	if deepwinter and eff != null and str(eff.id) == "chilled":
		return FrostMeleeKit.FROZEN_FX
	return eff

## CombatSystem asks this for every effect my hits (and my hit-less applications) carry.
func effect_override(eff: Resource) -> Resource:
	return winter_swap(eff, player.status != null and player.status.has(DEEPWINTER_ID))

func _start_deepwinter() -> void:
	var fx := StatusContainer.make_buff(DEEPWINTER_ID, "Deepwinter", DEEPWINTER_ID, 0.0,
		Balance.DEEPWINTER_TIME, 1, Abilities.color_of(DEEPWINTER_ID))
	fx.stat_modifiers = {}
	fx.description = "Every Chill you apply is a Freeze instead."
	player.status.apply(fx, player)
	player._ring_effect(2.2, Abilities.color_of(DEEPWINTER_ID))
	player._ring_effect(1.2, Color(0.95, 0.97, 1.0))

## Sleetwave: a wave that crosses a strip in front of me (turned to my target if I
## have one). The enemies standing in the strip now set the AoE cap's share; the
## wave (scripts/sleet_wave.gd) hits each enemy as it reaches it.
func _sleet_wave(res: Resource) -> void:
	if player._has_valid_target():
		var to_target := player.target.global_position - player.global_position
		player.rotation.y = atan2(-to_target.x, -to_target.z)
	var dir := player._flat_forward()
	var origin := Vector3(player.global_position.x, Combat.feet_y(player), player.global_position.z)
	var reach := float(res.radius)
	var count := 0
	for e in player.get_tree().get_nodes_in_group("enemies"):
		if e is Node3D and e.is_alive() and SLEET_WAVE.in_path(origin, dir, e.global_position, reach,
				Balance.SLEETWAVE_WIDTH, Combat.hitbox_radius(e)):
			count += 1
	SLEET_WAVE.spawn(player.get_tree().current_scene, origin, dir, player, float(res.damage) * Balance.aoe_share(count),
		reach, Balance.SLEETWAVE_WIDTH, Balance.SLEETWAVE_SPEED)
	player._net_fx("sleetwave", origin, null, {"yaw": player.rotation.y, "len": reach, "w": Balance.SLEETWAVE_WIDTH})   # the party sees it; the hits come from here

## Snow Ward: a shield on every ally within the ability's radius, me included
## (this one is for the whole party by design). Each is SNOW_WARD_SHARE x a Heal
## spell, with Rime Ward and Hardened Frost like my other shields.
func _snow_ward(res: Resource) -> void:
	var amount := player.frost_runes._aegis_amount(Balance.SNOW_WARD_SHARE)
	var armor := player._talent("frost_shield_armor")
	for who in player.fire_cooldowns._allies_within(float(res.radius)):
		if who == player:
			receive_snow_ward(player, amount, armor)
		elif who.is_in_group("remote_player"):
			if player._net():
				player._net().ward_ally(who, player, amount, armor)   # their machine puts it on them
		elif who.has_method("receive_snow_ward"):
			who.receive_snow_ward(player, amount, armor)
	player._ring_effect(float(res.radius), Color(0.85, 0.95, 1.0))
	player._ring_effect(2.0, Color(0.95, 0.97, 1.0))

## A Snow Ward lands on me (mine or a party member's).
func receive_snow_ward(caster: Node, amount: int, armor_pct: float = 0.0) -> void:
	if player.is_dead():
		return
	SHIELDS.set_ward(player.status, caster, amount, armor_pct)
	player._ring_effect(1.0, Color(0.85, 0.95, 1.0))
	player._combat().float_text(player, "Snow Ward (%d)" % amount, Color(0.7, 0.92, 1.0), false)

## Winter Hide's buff: less damage taken, of every kind.
static func make_winter_hide_fx() -> Resource:
	var fx := StatusContainer.make_buff(WINTER_HIDE_ID, "Winter Hide", WINTER_HIDE_ID, 0.0,
		Balance.WINTER_HIDE_TIME, 1, Color(0.6, 0.9, 1.0))
	fx.stat_modifiers = {}
	fx.damage_mod_pct = -Balance.WINTER_HIDE_PCT
	fx.modifies_incoming = true
	fx.mod_affects_dots = true
	fx.description = "You take %s%% less damage. Enemies that hit you in melee are Chilled." % Stats.num(Balance.WINTER_HIDE_PCT)
	return fx

## Winter Hide: does a hit on me Chill whoever dealt it? A melee attack that
## reached me (hit or blocked), never damage over time.
static func winter_hide_chills(tags: PackedStringArray, is_dot: bool) -> bool:
	return not is_dot and tags.has("Melee")

func _start_winter_hide() -> void:
	player.status.apply(make_winter_hide_fx(), player)
	player._ring_effect(1.4, Abilities.color_of(WINTER_HIDE_ID))
	player._ring_effect(0.9, Color(0.95, 0.97, 1.0))

func _start_rime_edge() -> void:
	var fx := StatusContainer.make_buff(RIME_EDGE_ID, "Rime Edge", RIME_EDGE_ID, 0.0,
		Balance.RIME_EDGE_TIME, 1, Abilities.color_of(RIME_EDGE_ID))
	fx.stat_modifiers = {}
	fx.description = "Your melee hits Chill the target and deal extra Frost damage."
	player.status.apply(fx, player)
	player._slash_effect(Abilities.color_of(RIME_EDGE_ID))
	player._ring_effect(1.0, Abilities.color_of(RIME_EDGE_ID))

## Rime Edge: does this hit of mine carry the extra Frost hit? Melee hits that
## landed - not procs (so never its own hit) and not damage over time.
static func rime_edge_applies(tags: PackedStringArray, is_proc: bool, is_dot: bool, amount: int) -> bool:
	return not is_proc and not is_dot and amount > 0 and tags.has("Melee")

## One of my melee hits landed with Rime Edge up: the extra Frost hit. It is the
## Rime Edge ability's own hit (its damage, its Chilled), dealt as a proc.
func _rime_edge_on_hit(info: RefCounted) -> void:
	if player.status == null or not player.status.has(RIME_EDGE_ID):
		return
	var tags: PackedStringArray = info.tags if not info.tags.is_empty() else Abilities.tags_of(str(info.ability_id))
	if not rime_edge_applies(tags, info.is_proc, info.is_dot, int(info.amount)):
		return
	if info.target == null or not is_instance_valid(info.target) or not info.target.is_alive():
		return
	player.deal_damage(info.target, float(Abilities.get_resource(RIME_EDGE_ID).damage) + player._talent("frost_honed_rime"),
		RIME_EDGE_ID, true)   # + Honed Rime

## Icebreaker's coefficient: weapon damage x the ability's multiplier, or x
## ICEBREAKER_FROZEN_MULT on a target I have Frozen (+ the ability's flat part).
static func icebreaker_coef(weapon_damage: float, mult: float, flat: float, frozen: bool) -> float:
	return weapon_damage * (Balance.ICEBREAKER_FROZEN_MULT if frozen else mult) + flat

## Icebreaker: a heavy blow. If MY Freeze is on the target it is ended first (the
## blow breaks it) and the hit is the big one.
func _icebreaker(w: Dictionary, res: Resource) -> void:
	var st: Node = player.target.get_node_or_null("Status")
	var frozen: bool = st != null and st.has_from("frozen", player)
	var at: Vector3 = player.target.global_position
	if frozen:
		_end_freeze(player.target)
	player.deal_damage(player.target, icebreaker_coef(float(w.get("damage", 0.0)), float(res.weapon_damage_multiplier),
		float(res.damage), frozen), "icebreaker")
	player._slash_effect(Abilities.color_of("icebreaker"))
	player._slash_effect(Color(0.95, 0.97, 1.0))
	if frozen:
		var back := player._talent("frost_clean_break")
		if back > 0.0:
			player._gain("fury", back)   # Clean Break: part of its Fury comes back
		player._ring_effect(1.1, Color(0.85, 0.95, 1.0), at)
		player._ring_effect(0.6, Color(0.95, 0.97, 1.0), at)

## End the Freeze on `tgt`. The host owns enemy effects in a party; my copy of it
## goes at once so nothing here still sees it.
func _end_freeze(tgt: Node) -> void:
	var net := player._net()
	if net:
		net.remove_status(tgt, "frozen")
	var st: Node = tgt.get_node_or_null("Status")
	if st:
		st.remove("frozen")
		st.suppress("frozen")

