extends "res://scripts/player/player_kit.gd"
class_name FireRunesKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "fire_runes".
# --- Smoldering Focus and Afterburn (Fire talents) ---------------------------------------
# Smoldering Focus (was a Legendary rune): every Fire spell hit that does NOT
# crit builds a stack of the buff (data/effects/smoldering_focus.tres: stacks,
# duration, "next Fire spell crit spends them"). The talent's rank sets what a
# stack is worth: crit chance x 0.1 per rank.
# Afterburn is its mirror image (data/effects/afterburn.tres): every Fire spell
# hit that DOES crit builds a stack, the next Fire spell hit that doesn't crit
# spends them, and a stack is worth (100 - crit chance) x 0.1 per rank.
# For both, proc hits count and damage-over-time ticks don't.

var _smolder_fx: Resource   # my own copy of each buff (its factor follows the talent rank)
var _afterburn_fx: Resource

func _on_damage_dealt_fire(info: RefCounted) -> void:
	if not is_same(info.source, player) or info.avoided() or info.is_dot or player.status == null:
		return
	var tags: PackedStringArray = info.tags if not info.tags.is_empty() else Abilities.tags_of(str(info.ability_id))
	player.fire_cooldowns._cool_head_on_hit(info, tags)
	player.fire_caster._fuse_on_hit(info)
	player.fire_tank._slag_on_hit(info, tags)
	player.fire_melee._heat_on_hit(info, tags)
	player.fire_melee._afterglow_on_hit(info)
	player.overload_kit._static_on_hit(info, tags)
	if str(info.damage_type) != "fire" or not tags.has("Spell") or int(info.amount) <= 0:
		return   # (effect-only hits like Immolate landing build nothing)
	if info.no_empower:
		return   # passive damage (the Slag kit) builds nothing either
	if not info.crit:
		player.fire_caster._pressure_valve(info)
		player.fire_caster._banked_mana(info)
	if info.crit:
		var burn := player._talent("fire_afterburn")
		if burn > 0.0:
			_afterburn_fx = _stack_scaled_fx(_afterburn_fx, "afterburn", burn,
				"Your next Fire spell hit that does not critically strike deals ((100 - critical strike chance) x %s)%% more damage per stack.")
	else:
		var factor := player._talent("fire_smoldering_focus")
		if factor > 0.0:
			_smolder_fx = _stack_scaled_fx(_smolder_fx, "smoldering_focus", factor,
				"Your next Fire spell critical strike deals (critical strike chance x %s)%% more damage per stack.")

## Add a stack of a talent buff whose scale factor follows the talent's rank.
## `mine` = my own copy of data/effects/<id>.tres (made on first use); returns it.
func _stack_scaled_fx(mine: Resource, id: String, factor: float, text: String) -> Resource:
	if mine == null:
		var base: Resource = preload("res://scripts/core/effects.gd").get_effect(id)
		if base == null:
			return null
		mine = base.duplicate()
		mine.mod_scale_factor = -1.0   # so the first use fills in the text
	if not is_equal_approx(float(mine.mod_scale_factor), factor):
		mine.mod_scale_factor = factor
		mine.description = text % str(snappedf(factor, 0.01))
	player.status.apply(mine, player)
	return mine

