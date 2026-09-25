extends RefCounted

# ONE place for every name the combat systems match on.
# Usage anywhere:  const CK = preload("res://scripts/core/combat_keys.gd")
#                  if info.damage_type == CK.FIRE and info.has_tag(CK.TAG_SPELL): ...
# Data files (.tres) store these same strings, so an ability, status effect,
# rune or talent that says "fire" / "Spell" matches everything else that does.
#
# Conventions
#   damage types : lowercase   ("fire")      -> AbilityData.damage_type, StatusEffectData.damage_type
#   tags         : Capitalized ("Fire")      -> AbilityData.tags, StatusEffectData.tags
#   stats        : snake_case  ("crit_chance") -> get_stat(), stat_modifiers, gear, talents
#   resources    : lowercase   ("mana")

# --- Damage types ----------------------------------------------------------------
const PHYSICAL := "physical"
const FIRE := "fire"
const FROST := "frost"
const LIGHTNING := "lightning"
const ARCANE := "arcane"
const SHADOW := "shadow"
const NATURE := "nature"
const HOLY := "holy"
const DAMAGE_TYPES := [PHYSICAL, FIRE, FROST, LIGHTNING, ARCANE, SHADOW, NATURE, HOLY]

# --- Ability / effect tags --------------------------------------------------------
# School tags (match the damage types)
const TAG_FIRE := "Fire"
const TAG_FROST := "Frost"
const TAG_LIGHTNING := "Lightning"
const TAG_ARCANE := "Arcane"
const TAG_SHADOW := "Shadow"
const TAG_NATURE := "Nature"
const TAG_HOLY := "Holy"
# Kind: every player action is exactly one of these.
#   Spell   = cast by mages (scales 60% Spell Power / 20% Attack Power)
#   Ability = used by warriors, rangers, rogues (20% SP / 60% AP)
#   AutoAttack = weapon swings/shots (scale like abilities)
# "Fire spell" = Spell tag + fire damage. Searing Strike is a fire ABILITY.
const TAG_SPELL := "Spell"
const TAG_ABILITY := "Ability"
const TAG_AUTO_ATTACK := "AutoAttack"
# Delivery tags
const TAG_MELEE := "Melee"
const TAG_RANGED := "Ranged"
const TAG_PROJECTILE := "Projectile"
const TAG_AOE := "AoE"
const TAG_DOT := "DoT"
const TAG_CHANNEL := "Channel"
const TAG_HEAL := "Heal"

# --- Stats --------------------------------------------------------------------------
# Full list, conversions and Spell/Attack Power scaling: res://scripts/core/stats.gd
const STAT_INTELLECT := "intellect"
const STAT_AGILITY := "agility"
const STAT_STRENGTH := "strength"
const STAT_CONSTITUTION := "constitution"
const STAT_ARMOR := "armor"
const STAT_HASTE := "haste"
const STAT_CRIT := "crit_chance"
const STAT_SPELL_POWER := "spell_power"
const STAT_ATTACK_POWER := "attack_power"
const STAT_MAX_HEALTH := "max_health"
const STAT_MOVE_SPEED := "move_speed"
## Resistance stat for a damage type: resist_stat(FIRE) -> "resist_fire" (percent).
static func resist_stat(damage_type: String) -> String:
	return "resist_" + damage_type

# --- Resources ------------------------------------------------------------------------
const MANA := "mana"
const ENERGY := "energy"
const RAGE := "rage"

# --- Helpers ------------------------------------------------------------------------
## "fire" -> "Fire" (the school tag for a damage type).
static func tag_for_type(damage_type: String) -> String:
	return damage_type.capitalize()

## "Fire" -> "fire"; "" if the tag isn't a school.
static func type_for_tag(tag: String) -> String:
	var t := tag.to_lower()
	return t if DAMAGE_TYPES.has(t) else ""

## Display color for a damage type (floating text, tooltips).
static func type_color(damage_type: String) -> Color:
	match damage_type:
		FIRE: return Color(1.0, 0.5, 0.15)
		FROST: return Color(0.55, 0.88, 1.0)
		LIGHTNING: return Color(0.75, 0.8, 1.0)
		ARCANE: return Color(0.8, 0.55, 1.0)
		SHADOW: return Color(0.6, 0.4, 0.85)
		NATURE: return Color(0.5, 0.95, 0.35)
		HOLY: return Color(1.0, 0.92, 0.55)
	return Color.WHITE
