class_name AbilityData
extends Resource

## Data template for one ability. Create instances via
## FileSystem > right-click > New Resource > AbilityData and save as .tres.

enum ResourceType { NONE, MANA, ENERGY, FURY }
enum CastType { INSTANT, CAST, CHANNEL, GROUND_TARGET }
enum WeaponRequirement { NONE, MELEE, RANGED }

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Free-form tags used by runes/talents, e.g. Fire, Frost, Spell, Projectile, Melee, AoE.
@export var tags: PackedStringArray = PackedStringArray()
@export var icon: Texture2D

@export_group("Casting")
@export var cast_type: CastType = CastType.CAST
## Seconds. Cast time for CAST / GROUND_TARGET, duration for CHANNEL. Ignored for INSTANT.
@export_range(0.0, 30.0, 0.05, "suffix:s") var cast_time: float = 1.0
@export_range(0.0, 300.0, 0.1, "suffix:s") var cooldown: float = 0.0
@export var can_move_while_casting: bool = false
@export var requires_target: bool = true
@export var weapon_requirement: WeaponRequirement = WeaponRequirement.NONE
## Needs a shield equipped in the Off Hand.
@export var requires_shield: bool = false
## Can't be used with a shield in the Off Hand (the Brawler, Martial tank).
@export var forbids_shield: bool = false
## Needs an off hand item (tome, wand, lantern...; not a weapon or shield) in the Off Hand.
@export var requires_off_hand: bool = false
## Needs a two-handed weapon in the Main Hand (with weapon_requirement MELEE: a
## two-handed melee weapon).
@export var requires_two_hand: bool = false
## Needs a one-handed melee weapon in the Main Hand and another in the Off Hand
## (dual wield): the Arcane tank's abilities.
@export var requires_dual_wield: bool = false

@export_group("Cost")
@export var resource_type: ResourceType = ResourceType.NONE
## Mana costs are in points (10% of base mana each) and may be fractions; Energy and Fury are whole.
@export var resource_cost: float = 0.0
## Resource gained on use (e.g. Slam generates fury).
@export var resource_generated: int = 0

@export_group("Base stats")
## Damage as a coefficient: 1.0 = one standard hit (a Frost Bolt), see
## Stats.level_hit. The real number also adds Spell / Attack Power.
@export var damage: float = 1.0
## Threat per point of damage (tank abilities make much more).
@export var threat_multiplier: float = 1.0
## Multiplier applied to equipped weapon damage (0 = not weapon based).
@export var weapon_damage_multiplier: float = 0.0
@export_range(0.0, 100.0, 0.1, "suffix:m") var cast_range: float = 30.0
## For AoE abilities.
@export_range(0.0, 20.0, 0.1, "suffix:m") var radius: float = 0.0
## For channels / DoTs: seconds between damage ticks.
@export_range(0.0, 10.0, 0.05, "suffix:s") var tick_interval: float = 0.0

@export_group("Effects")
## Status effect (StatusEffectData) applied to whatever this ability hits.
@export var on_hit_effect: Resource
## Applied to ALLY targets (e.g. Thawing). While an ally carries it, no
## ability that applies the same effect can target them.
@export var ally_lockout_effect: Resource
## Damage type used for resistances, e.g. "physical", "frost".
@export var damage_type: StringName = &"physical"

@export_group("Visuals")
## Projectile / effect scene spawned by the ability (optional).
@export var visual_scene: PackedScene

func has_tag(tag: String) -> bool:
	return tags.has(tag)
