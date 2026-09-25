extends RefCounted

# Skill Card registry (SkillCardData resources in res://data/skill_cards/).
# Usage: const SkillCards = preload("res://scripts/skill_cards.gd")
#
# A card id is the ability id it grants. Equip up to MAX_EQUIPPED cards in the
# main menu's Abilities & Talents tab: when you reach a card's unlock level, the
# level-up draft is guaranteed to offer that card's ability.

const DIR := "res://data/skill_cards/"
const MAX_EQUIPPED := 5
const ALL := ["icelance", "battleshout", "frostnova", "whirlwind", "poisonarrow",
	"icebarrier", "multishot", "blink", "secondwind",
	"fireball", "searingstrike", "flamingarrow", "flamenova",
	"chainlightning", "thunderstrike", "stormarrow",
	"arcanemissiles", "arcanestrike", "arcaneshot", "arcaneexplosion",
	"shadowbolt", "corruption", "shadowstrike", "shadowarrow",
	"holylight", "smite", "crusaderstrike", "radiantarrow",
	"froststrike", "frostarrow",
	"wrath", "insectswarm", "entanglingroots", "regrowth",
	"sinisterstrike", "rupture", "fanofknives", "eviscerate",
	"shieldofdawn", "stormshield", "sacredbulwark", "thunderaegis"]

static var _cache := {}

static func exists(id: String) -> bool:
	return ALL.has(id)

static func get_resource(id: String) -> Resource:
	if not ALL.has(id):
		return null
	if not _cache.has(id):
		_cache[id] = load(DIR + id + ".tres")
	return _cache[id]

## Ability id the card grants ("" if unknown).
static func ability_of(id: String) -> String:
	var c := get_resource(id)
	return str(c.ability.id) if c and c.ability else ""

## Level at which the card guarantees its ability in the draft (0 = never).
static func level_of(id: String) -> int:
	var c := get_resource(id)
	if c == null or int(c.unlock_trigger) != 1:   # 1 = PLAYER_LEVEL
		return 0
	return int(c.unlock_level)

static func tooltip(id: String) -> String:
	var Abilities = load("res://scripts/abilities.gd")
	var aid := ability_of(id)
	return "%s — Skill Card\nWhile equipped: from level %d, every ability draft offers %s until you learn it.\n\n%s" % [
		Abilities.ability_name(aid), level_of(id), Abilities.ability_name(aid), Abilities.tooltip(aid)]
