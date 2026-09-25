class_name GearItemData
extends Resource

## Data template for an equippable item.

enum Slot {
	HEAD, NECK, SHOULDER, BACK, CHEST, GLOVES, LEGS, BOOTS,
	FINGER_1, FINGER_2, TRINKET_1, TRINKET_2, MAIN_HAND, OFF_HAND,
}
## Display names matching the Character window slot labels.
const SLOT_NAMES := ["Head", "Neck", "Shoulder", "Back", "Chest", "Gloves", "Legs", "Boots",
	"Finger 1", "Finger 2", "Trinket 1", "Trinket 2", "Main Hand", "Off Hand"]

enum WeaponType { NONE, MELEE, RANGED }

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var color: Color = Color.WHITE
## Model shown when equipped / dropped (optional).
@export var model_scene: PackedScene

@export_group("Slot")
@export var slot: Slot = Slot.HEAD
## Two-handed weapons: occupies Main Hand and blocks Off Hand.
@export var locks_offhand: bool = false
@export var cosmetic: bool = false

@export_group("Base stats")
## Numerical stats (keys from stats.gd), e.g. {"armor": 2, "intellect": 1, "haste": 3}.
@export var stats: Dictionary = {}

@export_group("Weapon")
@export var weapon_type: WeaponType = WeaponType.NONE
@export var weapon_damage: int = 0
@export_range(0.0, 50.0, 0.1, "suffix:m") var attack_range: float = 1.0
## Auto-attack wind-up.
@export_range(0.1, 10.0, 0.05, "suffix:s") var attack_interval: float = 1.0

## What kind of item it is (\"sword\", \"staff\", \"dagger\", \"bow\", \"shield\", \"ring\",
## \"trinket\"...). Abilities check this, e.g. shield abilities need item_type \"shield\".
@export var item_type: StringName = &""

@export_group("Rune")
@export var rune: RuneData

@export_group("Item effects")
## Built-in passive effect while equipped (\"Equip:\"). Uses the rune machinery
## (trigger, condition, effect) but never counts toward rune limits.
## Amounts scale with item level. {amount} in the description = scaled amount.
@export var equip_effect: RuneData
## Active effect (\"Use:\") fired from the action bar (Trigger 1 / Trigger 2 slots
## for trinkets). Trigger/condition are ignored; internal_cooldown = cooldown.
@export var use_effect: RuneData

func slot_name() -> String:
	return SLOT_NAMES[slot]

func get_stat(stat: String, default_value: float = 0.0) -> float:
	return float(stats.get(stat, default_value))
