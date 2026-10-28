extends RefCounted

# Dungeon modifiers (Mythic+ style affixes): each changes how fights play,
# never just the look. A run gets a few, rolled from the
# dungeon recipe's `modifier_pool` with the run's seed, so every machine in a
# party gets the same ones. GameManager.has_modifier(id) answers "is it on?".
# Names and descriptions live in names.gd ("mod_<id>", "mod_<id>_desc").
#
# Where each one is applied:
#   frost_touched  CombatSystem.deal -> GameManager.dungeon_damage_pct
#   volatile       dungeon_run.gd: elites get enemy.death_explode
#   bloodthirst    CombatSystem.heal -> GameManager.heal_mult, lifesteal.gd
#   frenzy         enemy.gd _check_frenzy

const Names = preload("res://scripts/dungeon/names.gd")

const ALL := ["frost_touched", "volatile", "bloodthirst", "frenzy"]

## Off for now: the modifiers get reworked later. Runs roll none while this is false.
const ENABLED := false

const COLORS := {
	"frost_touched": Color(0.55, 0.85, 1.0),
	"volatile": Color(1.0, 0.55, 0.15),
	"bloodthirst": Color(0.95, 0.3, 0.35),
	"frenzy": Color(1.0, 0.35, 0.25),
}

const FROST_BONUS := 50.0
const FIRE_PENALTY := -50.0
const HEAL_MULT := 0.6
const LIFESTEAL_MULT := 2.0

static func title(id: String) -> String:
	return Names.t("mod_" + id)

static func desc(id: String) -> String:
	return Names.t("mod_%s_desc" % id)

static func color(id: String) -> Color:
	return COLORS.get(id, Color(0.9, 0.9, 0.9))

## Pick `count` modifiers from `pool` (seeded: same on every machine).
static func roll(pool: Array, count: int, seed_value: int) -> Array[String]:
	var out: Array[String] = []
	var opts: Array = []
	for m in pool:
		if ALL.has(str(m)) and not opts.has(str(m)):
			opts.append(str(m))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 7331
	while out.size() < count and not opts.is_empty():
		var i := rng.randi_range(0, opts.size() - 1)
		out.append(str(opts[i]))
		opts.remove_at(i)
	return out

## % damage change for a hit, given the active modifiers.
static func damage_pct(active: Array, info: RefCounted) -> float:
	if active.has("frost_touched") and info.target != null and is_instance_valid(info.target) \
			and info.target.is_in_group("enemies"):
		if str(info.damage_type) == "frost":
			return FROST_BONUS
		if str(info.damage_type) == "fire":
			return FIRE_PENALTY
	return 0.0

static func heal_mult(active: Array) -> float:
	return HEAL_MULT if active.has("bloodthirst") else 1.0

static func lifesteal_mult(active: Array) -> float:
	return LIFESTEAL_MULT if active.has("bloodthirst") else 1.0
