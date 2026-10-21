extends "res://scripts/player/player_kit.gd"
class_name RezKit

# Hooked up from player.gd through its var "rez_kit".
# --- Healers: the out-of-combat rez -----------------------------------------------------------
# Every healer spec has one (CLAUDE.md): a long cast, usable only out of combat,
# that brings a dead (or downed) party member back where they fell with part of
# their health and mana (Balance.RAISE_*). One per healer, each with its own
# picture; the rules are the same. The target: your friendly target if they are
# down, else the closest fallen ally in range. Their machine stands them up
# (Net.raise_ally -> GameManager.raise_local).

const HYMN_OF_WAKING_ID := "hymnofwaking"     # Choir of One
const RELIGHT_ID := "relight"                 # Line of Light
const BACK_ON_FEET_ID := "backonyourfeet"     # Strings Attached
const RETURN_TO_BLOOM_ID := "returntobloom"   # Shepherd
const IDS := [HYMN_OF_WAKING_ID, RELIGHT_ID, BACK_ON_FEET_ID, RETURN_TO_BLOOM_ID]
## Each rez's colour (the ring where the ally gets up).
const COLORS := {
	HYMN_OF_WAKING_ID: Color(1.0, 0.85, 0.35),
	RELIGHT_ID: Color(0.95, 0.97, 1.0),
	BACK_ON_FEET_ID: Color(0.7, 0.35, 0.9),
	RETURN_TO_BLOOM_ID: Color(0.45, 0.9, 0.4),
}
const IN_COMBAT_ERROR := "Can't do that in combat"
const NO_TARGET_ERROR := "No fallen ally in range"

const NO_COMBAT_REZ_ERROR := "No combat rez available"

# --- The party's combat rez charges -------------------------------------------------------
# A revive in combat (abilities tagged "Revive": Last Verse, Not Finished With You)
# spends one of the party's charges. One comes every Balance.COMBAT_REZ_INTERVAL
# sec of the run, none at the start, and unused ones stack. The host keeps the
# count (Net: combat_rez_charges / spend_combat_rez). Free in the Training Room.

## Charges the party has `elapsed` sec into a run after spending `used`.
static func charges(elapsed: float, used: int) -> int:
	return maxi(int(floor(maxf(elapsed, 0.0) / Balance.COMBAT_REZ_INTERVAL)) - used, 0)

## Seconds until the next charge, `elapsed` sec into a run.
static func next_charge_in(elapsed: float) -> float:
	return Balance.COMBAT_REZ_INTERVAL - fmod(maxf(elapsed, 0.0), Balance.COMBAT_REZ_INTERVAL)

## Do combat rez charges apply here? (Not in the Training Room, nor offline.)
func charges_apply() -> bool:
	var net := player._net()
	var gm := player.get_node_or_null("/root/GameManager")
	return net != null and bool(net.online) and not (gm != null and gm.in_training())

## Can a revive in combat go off now? ("" = yes.) Checked before it is paid for.
func combat_rez_error() -> String:
	if charges_apply() and int(player._net().combat_rez_charges()) <= 0:
		return NO_COMBAT_REZ_ERROR
	return ""

## A revive in combat went off: it uses one of the party's charges.
func spend_combat_rez() -> void:
	if charges_apply():
		player._net().spend_combat_rez()

## Who the rez being cast will bring back.
var target: Node3D = null

## Can a rez be cast right now? ("" = yes, else why not.)
static func rez_error(in_combat: bool, has_target: bool) -> String:
	if in_combat:
		return IN_COMBAT_ERROR
	if not has_target:
		return NO_TARGET_ERROR
	return ""

## The ally a rez of reach `reach` would bring back (null if none).
func fallen_ally(reach: float) -> Node3D:
	var ft := player.friendly_target
	if _fallen(ft) and player._flat_dist_to(ft.global_position) <= reach:
		return ft
	var best: Node3D = null
	var best_d := reach
	for p in player.get_tree().get_nodes_in_group("remote_player"):
		if not _fallen(p):
			continue
		var d := player._flat_dist_to((p as Node3D).global_position)
		if d <= best_d:
			best_d = d
			best = p
	return best

static func _fallen(p: Variant) -> bool:
	return p is Node3D and is_instance_valid(p) and (p as Node).is_in_group("remote_player") \
		and (p as Node).has_method("is_dead") and bool((p as Node).is_dead())

## Pressed: start the cast (it pays when it lands, like every cast).
func start(id: String) -> void:
	if player.casting or not player.is_on_floor():
		return
	var reach := float(Abilities.get_resource(id).cast_range)
	var ally := fallen_ally(reach)
	var err := rez_error(player.is_in_combat(), ally != null)
	if err != "":
		player._error(err)
		return
	if not player.can_afford(id, true):
		return
	player.cancel_placement()
	target = ally
	player._begin_spell(id, Abilities.ability_name(id), 1.0)

## Still fine to keep casting? (Out of combat, ally still down and in reach.)
func target_ok() -> bool:
	if player.is_in_combat() or not _fallen(target):
		return false
	var reach := float(Abilities.get_resource(player.current_spell).cast_range) if player.current_spell in IDS else 0.0
	return player._flat_dist_to(target.global_position) <= reach + 0.5

## The cast landed (already paid): they get up.
func finish(id: String) -> void:
	var tgt := target
	target = null
	if not _fallen(tgt):
		return
	var net := player._net()
	if net:
		net.raise_ally(tgt, player)
	player._ring_effect(1.6, COLORS.get(id, Color.WHITE), tgt.global_position)
