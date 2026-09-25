class_name SkillCardData
extends Resource

## Data template for a skill card: unlocks an ability (AbilityData) for the player.

enum UnlockTrigger {
	START_UNLOCKED,   ## available from the beginning
	PLAYER_LEVEL,     ## unlocks when the player reaches `unlock_level`
	TALENT,           ## unlocked by picking a talent
	ITEM,             ## unlocked by equipping/using an item
	QUEST,            ## unlocked by completing a quest (`unlock_key`)
}

## The ability this card grants (an AbilityData resource).
@export var ability: AbilityData
@export var unlocked: bool = false

@export_group("Unlock")
@export var unlock_trigger: UnlockTrigger = UnlockTrigger.PLAYER_LEVEL
@export_range(1, 100) var unlock_level: int = 1
## Talent / item / quest id for the non-level triggers.
@export var unlock_key: StringName = &""

@export_group("Presentation")
## Order in the Abilities list.
@export var sort_order: int = 0
@export var card_art: Texture2D

## True if the card should become unlocked at `player_level`.
func check_level_unlock(player_level: int) -> bool:
	return unlock_trigger == UnlockTrigger.PLAYER_LEVEL and player_level >= unlock_level
