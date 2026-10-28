extends Node
class_name PlayerKit

# A component of the player: one spec's own code, moved out of scripts/player.gd
# so that file stays the shared core (stats, casting, targeting, damage, net).
# The player makes one of each in its "Components" section (_kit), as a child
# node, and calls into it from its hooks (_use_drafted, _process, ...). Inside a
# component, `player` is the player: player.deal_damage(...), player.status, player.target; the
# player's consts and static functions are Player.NAME. Other systems still talk
# to the player only (it forwards what they call).
# tools/split_section.pl moves a section into a component.

const Combat = preload("res://scripts/combat_utils.gd")
const Stats = preload("res://scripts/core/stats.gd")
const StatusContainer = preload("res://scripts/core/status_container.gd")
const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const ARROW = preload("res://scripts/arrow.gd")
const Items = preload("res://scripts/items.gd")
const Runes = preload("res://scripts/runes.gd")
const Macros = preload("res://scripts/core/macros.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")
const DamageInfo = preload("res://scripts/core/damage_info.gd")
const SHIELDS = preload("res://scripts/core/shields.gd")

## The player this component works for.
var player: Player

## Values Trackers can show or test (scripts/ui/trackers/): name -> number, or
## {"value", "max"} for something with a cap (it may also carry "icon", "name" and
## "colors", one per pip). Player.tracker_values() merges every component's, so a
## new spec's values reach Trackers without tracker code.
func tracker_values() -> Dictionary:
	return {}

## What clicking a tracker can do (a tracker's "On click"): id -> label.
## Player.tracker_action(id) runs one through tracker_action() here.
func tracker_actions() -> Dictionary:
	return {}

## Do action `id` (one of tracker_actions()); true if it was this component's.
func tracker_action(_id: String) -> bool:
	return false
