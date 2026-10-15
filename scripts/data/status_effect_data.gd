class_name StatusEffectData
extends Resource

## Data template for a status effect (buff or debuff) that any character with a
## StatusContainer can carry: stat modifiers, damage modifiers, damage over
## time, crowd control. Names used here (damage types, tags, stats) are listed
## in res://scripts/core/combat_keys.gd.

enum StackMode {
	REFRESH,     ## re-applying resets the duration (stacks stay at 1)
	ADD_STACK,   ## re-applying adds a stack (up to max_stacks) and refreshes duration
	IGNORE,      ## re-applying does nothing while active
}

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var color: Color = Color.WHITE
@export var icon: Texture2D
@export var is_debuff: bool = false
@export var tags: PackedStringArray = PackedStringArray()

@export_group("Duration & stacking")
@export_range(0.0, 600.0, 0.1, "suffix:s") var duration: float = 5.0
@export var stack_mode: StackMode = StackMode.REFRESH
@export var max_stacks: int = 1
## Every caster has their own copy on the target (damage over time always
## does). For effects that belong to one player, like a Slow Fuse charge.
@export var per_caster: bool = false
## The stack count is an amount of damage, not a number of stacks (Decay: what
## it still has to deal). Icons show it as a number ("1.2k") and their tooltips
## as damage left. Give such an effect a very large max_stacks.
@export var stacks_are_amount: bool = false
## Show the time the effect has left. Off for one that lasts until something
## ends it (a closed Decay): its duration is only a safety net.
@export var show_time: bool = true

@export_group("Stat modifiers (per stack)")
## e.g. {"move_speed": -40} (percent), {"damage": 1}, {"armor": 3}, {"crit_chance": 5}
@export var stat_modifiers: Dictionary = {}

@export_group("Damage over time")
## Damage per tick as a coefficient (1.0 = a standard hit, see Stats.level_hit).
@export var tick_damage: float = 0.0
@export_range(0.0, 10.0, 0.05, "suffix:s") var tick_interval: float = 1.0
@export var damage_type: StringName = &"physical"
## Ticks can critically strike (attacker's crit chance). On unless stated otherwise.
@export var dot_can_crit: bool = true
## Attacker's Haste makes it tick faster (same duration, more ticks).
@export var dot_hasted: bool = true
## Burst when the effect runs out on its own (not when removed): a coefficient
## like tick_damage (e.g. Hoarfrost's 2.5 Frost Bolts). 0 = none.
@export var expire_damage: float = 0.0
## Share of the applying spell/ability's Spell/Attack Power bonus each tick gets.
## -1 = the default in stats.gd (DOT_POWER_SHARE).
@export var dot_power_share: float = -1.0

@export_group("Damage modifier (per stack)")
## Percent change to damage, per stack. +20 = 20% more, -30 = 30% less.
## On the ATTACKER this changes damage it deals (a buff like "Stormfire");
## with `modifies_incoming` it changes damage the carrier TAKES (a debuff like
## "Scorched: takes 10% more fire damage", or a damage-reduction buff).
@export var damage_mod_pct: float = 0.0
## Damage the carrier takes instead of deals.
@export var modifies_incoming: bool = false
## Only hits of these damage types (lowercase, e.g. "fire"). Empty = any type.
@export var mod_damage_types: PackedStringArray = PackedStringArray()
## Only hits from abilities carrying ALL these tags (e.g. "Spell"). Empty = any.
@export var mod_required_tags: PackedStringArray = PackedStringArray()
## Also apply to damage-over-time ticks.
@export var mod_affects_dots: bool = false
## Removed once it boosts a hit ("your NEXT fire spell"). Every hit landing in
## the same frame still gets it, so one AoE cast consumes it only once.
@export var consume_on_use: bool = false
## Only critical strikes get it (and only they consume it).
@export var mod_crit_only: bool = false
## Only hits that do NOT critically strike get it (and only they consume it).
@export var mod_non_crit_only: bool = false
## Adds (carrier's `mod_scale_stat` x `mod_scale_factor`) percent per stack,
## e.g. crit_chance x 0.6: with 20% crit each stack is +12%.
@export var mod_scale_stat: StringName = &""
@export var mod_scale_factor: float = 0.0
## Scale from (100 - the stat) instead, for percent stats: with crit_chance x 0.5
## and 20% crit each stack is +40% (the less of the stat, the more damage).
@export var mod_scale_inverse: bool = false

## Percent per stack for a carrier (`stat_of` returns its final stats).
func mod_pct_per_stack(stat_of: Callable) -> float:
	var pct := damage_mod_pct
	if mod_scale_stat != &"" and mod_scale_factor != 0.0:
		var v := float(stat_of.call(str(mod_scale_stat)))
		if mod_scale_inverse:
			v = 100.0 - clampf(v, 0.0, 100.0)
		pct += v * mod_scale_factor
	return pct

@export_group("Crowd control")
## Can't move.
@export var root: bool = false
## Can't move, attack or cast.
@export var stun: bool = false

## Does this effect's damage modifier apply to a hit?
## Pass the hit's damage type, ability tags and whether it is a DoT tick.
func modifies(hit_type: String, hit_tags: PackedStringArray, hit_is_dot: bool, hit_crit: bool = false) -> bool:
	if damage_mod_pct == 0.0 and (mod_scale_stat == &"" or mod_scale_factor == 0.0):
		return false
	if mod_crit_only and not hit_crit:
		return false
	if mod_non_crit_only and hit_crit:
		return false
	if hit_is_dot and not mod_affects_dots:
		return false
	if not mod_damage_types.is_empty() and not mod_damage_types.has(hit_type):
		return false
	for t in mod_required_tags:
		if not hit_tags.has(t):
			return false
	return true
