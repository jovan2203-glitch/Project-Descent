class_name RuneData
extends Resource

## Data template for a rune that sits on a gear item.
## The RuneListener watches combat events; when `trigger` happens for an
## ability carrying ALL `required_tags` (and the other filters below), the
## condition in `threshold_mode`/`threshold` is checked, then `effect` fires.
## Names (damage types, tags, stats) are listed in res://scripts/core/combat_keys.gd.
##
## Rarity (how build-defining it is) and equip limits per character:
##   LEGENDARY  build-defining, big.            Max 1 legendary rune in total.
##   EPIC       strong, adds build diversity.   Max 4 epic runes, each a different one.
##   RARE       fine-tunes / slightly alters.   Same rune up to 3 times (or max_equipped).
##   COMMON     small tweaks.                   Same rune up to 3 times (or max_equipped).

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

enum Trigger {
	ON_HIT,            ## the player deals damage to an enemy
	ON_CAST,           ## a player spell / ability goes off (instant or finished cast)
	ON_KILL,           ## the player kills an enemy
	ON_DAMAGE_TAKEN,   ## the player takes damage
	ON_LOW_HEALTH,     ## player health falls to/below threshold (fraction 0-1)
	PERIODIC,          ## every `threshold` seconds
}
enum ThresholdMode {
	CHANCE,            ## threshold = probability 0-1 per trigger
	COUNT,             ## threshold = matching triggers needed (fires every Nth)
	CONSECUTIVE,       ## threshold = matching triggers needed IN A ROW (a miss resets)
	HEALTH_FRACTION,   ## threshold = health fraction (for ON_LOW_HEALTH)
	SECONDS,           ## threshold = interval (for PERIODIC)
}
enum Effect {
	STAT_BUFF,         ## temporary stat buff on the player
	INSTANT_CAST,      ## cast `cast_ability` instantly and for free at the target
	BONUS_DAMAGE,      ## extra damage to the enemy that was hit
	HEAL,              ## restore `effect_amount` health
	APPLY_STATUS,      ## apply `status_effect` to `status_target`
	AOE_DAMAGE,        ## `effect_amount` damage to every enemy within `radius` of you
	                   ## (plus `status_effect` on each one hit, if set)
}
enum StatusTarget {
	SELF,              ## the player wearing the rune
	TARGET,            ## the enemy that was hit (debuffs help the whole party: keep them rare)
	PARTY,             ## the player and every party member
}

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var color: Color = Color.WHITE
@export var icon: Texture2D
@export var rarity: Rarity = Rarity.COMMON
## How many copies one character may have equipped. 0 = the rarity's default
## (legendary 1, epic 1, rare/common 3). E.g. 1 for a unique rare.
@export var max_equipped: int = 0
## Player level at which this rune joins the loot "unlocked pool"
## (runes the player already knows are always in the pool).
@export_range(1, 100) var unlock_level: int = 1

@export_group("Conditions")
## Ability must have every one of these tags (empty = any ability).
@export var required_tags: PackedStringArray = PackedStringArray()
## Only these ability ids count, e.g. ["frostbolt"] (empty = any).
@export var required_abilities: PackedStringArray = PackedStringArray()
@export var trigger: Trigger = Trigger.ON_HIT
## ON_HIT only: the hit's damage type must be one of these, e.g. ["lightning"] (empty = any).
@export var required_damage_types: PackedStringArray = PackedStringArray()
## ON_HIT only: damage-over-time ticks count as hits too.
@export var include_dots: bool = false
## ON_HIT only: proc hits count too (chain-lightning jumps, splash, other runes).
## Leave off for runes that deal damage or cast, so they can't loop forever.
@export var include_procs: bool = false
## Only count critical strikes.
@export var require_crit: bool = false
## Only count NON-critical hits (a crit breaks a CONSECUTIVE streak).
@export var require_non_crit: bool = false
@export var threshold_mode: ThresholdMode = ThresholdMode.CHANCE
@export var threshold: float = 1.0
## Minimum seconds between activations.
@export_range(0.0, 120.0, 0.1, "suffix:s") var internal_cooldown: float = 0.0

@export_group("Effect")
@export var effect: Effect = Effect.STAT_BUFF
## Stat the buff modifies (see stats.gd), e.g. "attack_power", "haste", or a
## percent key like "intellect%".
@export var buff_stat: StringName = &""
@export var buff_amount: float = 0.0
@export var buff_is_percent: bool = false
@export_range(0.0, 600.0, 0.1, "suffix:s") var buff_duration: float = 5.0
@export var max_stacks: int = 1
## For INSTANT_CAST.
@export var cast_ability: AbilityData
## For BONUS_DAMAGE / HEAL / AOE_DAMAGE.
@export var effect_amount: int = 1
## For BONUS_DAMAGE / AOE_DAMAGE: damage type of the hit (\"\" = physical).
@export var damage_type: StringName = &""
## For BONUS_DAMAGE / AOE_DAMAGE: tags the hit carries (lets runes / talents react,
## e.g. [\"Lightning\"]). Spell/Ability scaling follows these like any hit.
@export var effect_tags: PackedStringArray = PackedStringArray()
## For AOE_DAMAGE.
@export_range(0.0, 20.0, 0.1, "suffix:m") var radius: float = 3.0
## For APPLY_STATUS: the StatusEffectData to apply (its own duration/stacking rules apply).
@export var status_effect: Resource
@export var status_target: StatusTarget = StatusTarget.SELF

func applies_to_tags(tags: PackedStringArray) -> bool:
	for t in required_tags:
		if not tags.has(t):
			return false
	return true

func applies_to_ability(ability_id: String) -> bool:
	return required_abilities.is_empty() or required_abilities.has(ability_id)

func applies_to_damage_type(damage_type: String) -> bool:
	return required_damage_types.is_empty() or required_damage_types.has(damage_type)
