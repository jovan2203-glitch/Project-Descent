extends RefCounted

# Level-up draft rules (pure logic, unit-tested). Usage:
#   const DraftRules = preload("res://scripts/core/draft_rules.gd")
#   var choices = DraftRules.make_choices(level, learned, equipped_cards, rng)
#
# A choice is a Dictionary:
#   {"type": "ability", "id": "icelance", "guaranteed": bool, "card": card_id}
#   {"type": "boon", "id": "vitality", "stat": "max_health", "amount": 1.0, ...}
#
# Drafts are offered every PlayerData.DRAFT_EVERY levels (2, 4, 6...).
# 1. Equipped Skill Cards whose unlock level has been reached guarantee their
#    ability (if not learned yet).
# 2. The rest are random unlearned abilities from the global draft pool
#    (Abilities.DRAFT_POOL: every book's draftable abilities, incl. shield abilities).
# 3. If the pool runs dry, permanent stat boons fill the remaining slots.

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")

const CHOICES := 3
const BOONS := [
	{"id": "vitality", "name": "Vitality", "stat": "constitution", "amount": 1.0, "desc": "+1 Constitution"},
	{"id": "might", "name": "Might", "stat": "strength", "amount": 1.0, "desc": "+1 Strength"},
	{"id": "insight", "name": "Insight", "stat": "intellect", "amount": 1.0, "desc": "+1 Intellect"},
	{"id": "finesse", "name": "Finesse", "stat": "agility", "amount": 1.0, "desc": "+1 Agility"},
	{"id": "precision", "name": "Precision", "stat": "crit_chance", "amount": 2.0, "desc": "+2% Critical Strike"},
	{"id": "fortitude", "name": "Fortitude", "stat": "armor", "amount": 1.0, "desc": "+1 Armor"},
	{"id": "haste", "name": "Haste", "stat": "haste", "amount": 3.0, "desc": "+3% Haste"},
	{"id": "fleetness", "name": "Fleetness", "stat": "move_speed", "amount": 3.0, "desc": "+3% Move Speed"},
]

## `card_levels`: card id -> unlock level (lets tests avoid loading resources);
## defaults to SkillCards.level_of for each equipped card.
## `cards_only`: a Skill Card re-offer between normal drafts (you skipped a
## guaranteed card): the card abilities, then boons - no random abilities.
static func make_choices(level: int, learned: Array, equipped_cards: Array,
		rng: RandomNumberGenerator = null, card_levels: Dictionary = {}, cards_only: bool = false) -> Array:
	var r := rng if rng else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var choices: Array = []
	var taken := {}
	# 1. Skill Card guarantees
	for card in equipped_cards:
		var cid := str(card)
		var lv := int(card_levels[cid]) if card_levels.has(cid) else SkillCards.level_of(cid)
		var aid := cid if card_levels.has(cid) else SkillCards.ability_of(cid)
		# Drafts only happen every few levels, so a card whose level falls between
		# drafts is guaranteed at the first draft at or after its level.
		if lv > 0 and lv <= level and aid != "" and not learned.has(aid) and not taken.has(aid):
			choices.append({"type": "ability", "id": aid, "guaranteed": true, "card": cid})
			taken[aid] = true
			if choices.size() >= CHOICES:
				return choices
	# 2. Random unlearned abilities from the pool
	var pool: Array = []
	for aid in Abilities.DRAFT_POOL:
		if not cards_only and not learned.has(aid) and not taken.has(aid):
			pool.append(aid)
	_shuffle(pool, r)
	for aid in pool:
		if choices.size() >= CHOICES:
			break
		choices.append({"type": "ability", "id": aid, "guaranteed": false, "card": ""})
	# 3. Boons when out of abilities
	var boons := BOONS.duplicate()
	_shuffle(boons, r)
	for b in boons:
		if choices.size() >= CHOICES:
			break
		var c: Dictionary = b.duplicate()
		c["type"] = "boon"
		c["guaranteed"] = false
		choices.append(c)
	return choices

static func _shuffle(arr: Array, r: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

## Did the player skip a guaranteed Skill Card ability in these choices?
static func skipped_card(choices: Array, picked: Dictionary) -> bool:
	for c in choices:
		if c.get("guaranteed", false) and c.get("id") != picked.get("id"):
			return true
	return false

## Apply a picked choice to PlayerData.
static func apply_choice(pd: Node, choice: Dictionary) -> void:
	if choice.get("type") == "ability":
		pd.learn_ability(str(choice["id"]))
	else:
		pd.add_boon(str(choice["stat"]), float(choice["amount"]))
