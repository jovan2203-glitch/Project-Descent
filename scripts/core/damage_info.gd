extends RefCounted

# One damage event flowing through CombatSystem.deal().
# Build with DamageInfo.make(...), tweak fields, pass to CombatSystem.deal().
# After deal() returns, amount/crit/blocked hold the final result.
# Names for damage_type / tags live in res://scripts/core/combat_keys.gd.

var source: Node = null          # who dealt it (player, enemy, or null for environment)
var target: Node = null          # who receives it
## Coefficient (1.0 = one standard hit, see Stats.level_hit): CombatSystem turns
## it into real damage with the source's level and Spell / Attack Power.
var base: float = 0.0
var amount: int = 0              # final damage applied
var damage_type: String = "physical"   # physical, fire, frost, lightning, ...
var tags: PackedStringArray = PackedStringArray()
var ability_id: String = ""      # e.g. "frostbolt", "auto_melee", "zombie_melee"
var is_proc := false             # caused by an rune (runes ignore these)
var is_dot := false              # damage-over-time tick
## Part of a free cast (Rune of the Wild Page): its meter line is "<name> (Wild Page)".
var echo := false
## A hit split over two schools (Frostfire Bolt): 1 = its first half, 2 = its
## second. Things that count "a hit" (procs, talents) skip the second half;
## things that react to a school see whichever half is theirs. 0 = a whole hit.
var part := 0
var can_crit := true
var can_block := true            # can be dodged, parried or blocked (never damage over time)
var add_power := true            # add the attacker's Spell / Attack Power (see stats.gd)
var power_share := 1.0           # fraction of that power bonus (DoT ticks get less)
var crit := false
var blocked := false
var dodged := false              # the target dodged it: no damage, none of its effects
var parried := false             # the target parried it: no damage, none of its effects
## Set by a damage_modify listener to make the target avoid this hit outright,
## whatever the rolls say: it then counts as parried AND blocked (Reflex Arc).
var force_parry_block := false
## The hit got through, and something else took it for the target (Stand-In: a
## Reflection): no damage, none of its effects.
var stood_in := false
var effects: Array = []          # StatusEffectData applied on hit
var threat_multiplier := 1.0
## Real damage of a 1.0 coefficient; -1 = from the source (CombatSystem.unit_of).
var unit := -1.0
## The amount is already final (e.g. Permafrost's damage, worked out from hits
## that were already modified): no % modifiers and no resistance again.
var exact := false
## This hit neither builds nor uses up "your next ..." buffs (Smoldering Focus,
## Afterburn, Stormfire): passive damage like the Slag kit's, which you never cast.
var no_empower := false
## Damage soaked by absorb shields (already part of `amount`).
var absorbed := 0
## Summed percent damage modifiers (+20 = 20% more). Filled by CombatSystem from
## status effects on attacker and target, and by any SignalBus.damage_modify
## listener (talents, set bonuses, scripted interactions).
var bonus_pct := 0.0
## Human-readable list of what modified this hit, e.g. ["Stormfire x3 +60%"] (log/debug).
var modifiers: Array[String] = []
## The same modifiers as [name, percent] rows (the damage meter splits a hit's
## damage by them: what a talent / buff / rune ADDED gets its own line).
var bonus_parts: Array = []

static func make(src: Node, tgt: Node, dmg: float, id: String = "") -> RefCounted:
	var d = load("res://scripts/core/damage_info.gd").new()
	d.source = src
	d.target = tgt
	d.base = dmg
	d.ability_id = id
	# Dealt during my free cast (Rune of the Wild Page), or by something it left behind.
	d.echo = src != null and is_instance_valid(src) and src.has_method("echoing") and src.echoing()
	return d

## Did the hit do nothing because its target dodged, parried or blocked it (or a
## Reflection stood in for it)?
## (Ask this for "did it land?"; ask `blocked` only for what a block itself does.)
func avoided() -> bool:
	return blocked or dodged or parried or stood_in

## "dodge", "parry", "block" or "reflection" for an avoided hit, "" for one that landed.
func avoid_kind() -> String:
	if dodged:
		return "dodge"
	if parried:
		return "parry"
	if blocked:
		return "block"
	return "reflection" if stood_in else ""

func has_tag(tag: String) -> bool:
	return tags.has(tag)

## Add a percent modifier with a label (shows up in the combat log).
func add_bonus(pct: float, label: String = "") -> void:
	bonus_pct += pct
	if label != "":
		modifiers.append("%s %+d%%" % [label, int(round(pct))])
		bonus_parts.append([label, pct])
