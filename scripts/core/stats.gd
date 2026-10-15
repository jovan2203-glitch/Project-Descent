extends RefCounted

# Character stats: the ONE place that defines every stat, how primary stats
# convert into secondary ones, and how Spell Power / Attack Power scale spells
# and abilities. Balance numbers live here.
# Usage: const Stats = preload("res://scripts/core/stats.gd")
#
# Stat keys (use these everywhere: gear, talents, buffs, runes, UI):
const INTELLECT := "intellect"
const AGILITY := "agility"
const STRENGTH := "strength"
const CONSTITUTION := "constitution"
const ARMOR := "armor"
const HASTE := "haste"                 # % faster attacks, casts, channels and DoT ticks
const CRIT := "crit_chance"            # % - every hit (spells, abilities, attacks, DoTs)
const SPELL_CRIT := "spell_crit"       # % - extra crit chance for spells only
## Flat Critical Strike Rating (what gear gives): CRIT_RATING_PER_PCT rating = +1% Critical Strike.
const CRIT_RATING := "crit_rating"

## STAT SQUISH. Every stat NUMBER (Intellect, Agility, Strength, Constitution,
## Armor, Spell Power, Attack Power, Critical Strike Rating) is this share of
## what it used to be, and every point is worth 1 / SQUISH (about 43% more), so
## the results (damage, health, mana, crit, block) are exactly the same.
## Health and mana themselves are not squished.
const SQUISH := 0.7
const POINT_VALUE := 1.0 / SQUISH
const CRIT_RATING_PER_PCT := 100.0 * SQUISH   # 70 rating = 1%
const SPELL_POWER := "spell_power"
const ATTACK_POWER := "attack_power"
const MAX_HEALTH := "max_health"
const MAX_MANA := "max_mana"
const MOVE_SPEED := "move_speed"       # % (secondary, rare)
## % of your damage AND of your healing on others returned to you as health
## (secondary, rare, tiny numbers - 5% is a lot).
const LIFESTEAL := "lifesteal"
## Avoidance (%): a hit that is dodged, parried or blocked deals no damage and
## applies none of its effects. All three drop on gear. The numbers (caps, what
## Agility / Strength add, gear rolls) are in balance.gd.
const DODGE := "dodge"                 # chance to dodge an incoming hit; Agility adds a little
const PARRY := "parry"                 # chance to parry an incoming hit; Strength adds a little
## Chance to block an incoming hit; Strength adds a little. (Armor does not
## block: it reduces damage, see armor_reduction().)
const BLOCK := "block_chance"
const Balance = preload("res://scripts/balance.gd")

## Order shown in stat panels.
const ORDER := [MAX_HEALTH, MAX_MANA, INTELLECT, AGILITY, STRENGTH, CONSTITUTION,
	SPELL_POWER, ATTACK_POWER, CRIT_RATING, CRIT, SPELL_CRIT, HASTE, ARMOR, DODGE, PARRY, BLOCK,
	MOVE_SPEED, LIFESTEAL]
## Secondary stats: rare on gear (low roll weight in ItemDB.ROLL_WEIGHTS).
const SECONDARY := [MOVE_SPEED, LIFESTEAL]
const LABELS := {
	INTELLECT: "Intellect", AGILITY: "Agility", STRENGTH: "Strength", CONSTITUTION: "Constitution",
	ARMOR: "Armor", HASTE: "Haste", CRIT: "Critical Strike", SPELL_CRIT: "Spell Critical Strike",
	CRIT_RATING: "Critical Strike Rating",
	SPELL_POWER: "Spell Power", ATTACK_POWER: "Attack Power", MAX_HEALTH: "Max Health",
	MAX_MANA: "Max Mana", MOVE_SPEED: "Move Speed", LIFESTEAL: "Lifesteal",
	DODGE: "Dodge", PARRY: "Parry", BLOCK: "Block",
}
const PERCENT_STATS := [HASTE, CRIT, SPELL_CRIT, MOVE_SPEED, LIFESTEAL, DODGE, PARRY, BLOCK]

## Every character starts with these. (Base health AND base mana come from the
## level, see player_base_health() / player_base_mana().)
const BASE := {MAX_HEALTH: 0.0, CRIT: 5.0}

## Health per point of Constitution before the squish (was 5: 20% less now).
const CONSTITUTION_HEALTH := 4.0

## Primary stat -> what each point gives. Gear stats are in the hundreds at
## level 50 (see flat_unit), so percent conversions are small.
##   Intellect    -> spell power (0.5), mana and a little spell crit (spells only)
##   Agility      -> attack power (0.5), a little crit (everything) and a little Dodge
##   Strength     -> attack power, 1 to 1, a little Parry and a little Block
##   Constitution -> health
## Stat -> stat conversions are unchanged by the squish (both sides shrank);
## conversions into health, mana and crit % are worth POINT_VALUE more.
## (Dodge / Parry / Block per point are plain numbers in balance.gd.)
const DERIVED := {
	INTELLECT: {SPELL_POWER: 0.5, MAX_MANA: 4.0 * POINT_VALUE, SPELL_CRIT: 0.02 * POINT_VALUE},
	AGILITY: {ATTACK_POWER: 0.5, CRIT: 0.02 * POINT_VALUE, DODGE: Balance.DODGE_PER_AGILITY},
	STRENGTH: {ATTACK_POWER: 1.0, PARRY: Balance.PARRY_PER_STRENGTH, BLOCK: Balance.BLOCK_PER_STRENGTH},
	CONSTITUTION: {MAX_HEALTH: CONSTITUTION_HEALTH * POINT_VALUE},
	CRIT_RATING: {CRIT: 1.0 / CRIT_RATING_PER_PCT},
}

## How much of each power stat is added to a hit, by action kind.
## Spells lean on Spell Power, abilities (and weapon attacks) on Attack Power.
## (60% / 20% of the power before the squish.)
const POWER_MAIN := 0.6 * POINT_VALUE
const POWER_OFF := 0.2 * POINT_VALUE
const POWER := {
	"Spell": {SPELL_POWER: POWER_MAIN, ATTACK_POWER: POWER_OFF},
	"Ability": {SPELL_POWER: POWER_OFF, ATTACK_POWER: POWER_MAIN},
}
## A DoT tick gets this share of the power bonus of the spell/ability that applied it.
## (Tick sizes are already small coefficients, so ticks scale like hits by default.)
const DOT_POWER_SHARE := 1.0

# --- Balance: how big numbers are ------------------------------------------------
# Two kinds of damage: DIRECT (a hit: Frost Bolt, Ice Shards, weapon swings) and
# PERIODIC (ticks over time: Corruption, Burning, Hoarfrost). In code a periodic
# tick is DamageInfo.is_dot (ability id "dot_<effect>"); everything else is direct.
#
# Every damage / heal number in the data (ability `damage`, DoT `tick_damage`,
# weapon damage, rune `effect_amount`, enemy `contact_damage`...) is a
# COEFFICIENT: 1.0 = one "standard hit" = a Frost Bolt. The real number is
#     coefficient x (level_hit(level) + Spell/Attack Power bonus)
# so a level 50 character with no gear hits for ~500 per standard hit, a crit
# doubles that, and full level 50 gear (~1500 Spell Power) roughly triples it.
# Tune the game's overall numbers HERE.

## Damage of one standard hit (coefficient 1.0) at `level`, before power.
static func level_hit(level: int) -> float:
	return 9.0 * maxi(level, 1) + 10.0          # L1 19  •  L10 100  •  L50 460

## A player's base max health at `level` (before Constitution / gear).
static func player_base_health(level: int) -> float:
	return 50.0 * (maxi(level, 1) + 1)          # L1 100  •  L50 2550

## A player's base max mana at `level` (before Intellect / gear): 20% less than
## base health (balance.gd MANA_OF_BASE_HEALTH).  L1 80  •  L50 2040
static func player_base_mana(level: int) -> float:
	return player_base_health(level) * preload("res://scripts/balance.gd").MANA_OF_BASE_HEALTH

## One "mana point" of an ability's cost / regen at `level`: costs in the data
## are points of the old 10-point bar, so a cost of 1 = 10% of base mana.
static func mana_unit(level: int) -> float:
	return player_base_mana(level) / 10.0

## One enemy damage point (contact_damage 1.0) at the enemy's level:
## 10% of a same-level player's base health.
static func enemy_hit(level: int) -> float:
	return player_base_health(level) * 0.1

## One enemy health point (max_health 1.0) at the enemy's level.
## Tuned in balance.gd (0.8 = enemies have 20% less health).
const ENEMY_HEALTH_PER_HIT := preload("res://scripts/balance.gd").ENEMY_HEALTH_MULT
static func enemy_health_unit(level: int) -> float:
	return level_hit(level) * ENEMY_HEALTH_PER_HIT

## Flat gear stats: a base value of 1 on an item is worth this at its item level
## (Intellect, Spell Power, Armor, Constitution...). 1.75 at ilvl 1, 87.5 at ilvl 50.
## Also the size of flat buffs (Battle Shout, Ice Barrier...) and draft boons.
const FLAT_PER_LEVEL := 2.5 * SQUISH
static func flat_unit(level: int) -> float:
	return FLAT_PER_LEVEL * maxi(level, 1)

## Flat Max Health / Max Mana on gear: pools are not squished (2.5 per level).
static func pool_unit(level: int) -> float:
	return 2.5 * maxi(level, 1)

## Size of one flat unit of `stat` at `level` (flat_unit, or pool_unit for pools).
static func unit_for(stat: String, level: int) -> float:
	return pool_unit(level) if stat == MAX_HEALTH or stat == MAX_MANA else flat_unit(level)

## Percent gear stats (Haste, Crit, Move Speed) grow much slower: x1 at ilvl 1, ~x3 at 50.
static func pct_scale(level: int) -> float:
	return 1.0 + (maxi(level, 1) - 1) * 0.04

## Armor -> % less damage taken (every school, and damage over time), relative
## to the defender's level, so the same share of your gear's Armor takes off as
## much at level 5 as at level 50. Armor does not block: Block is a stat of its
## own (gear, a little from Strength, buffs).
const ARMOR_PER_LEVEL := Balance.ARMOR_DR_PER_LEVEL
const MAX_ARMOR_REDUCTION := Balance.ARMOR_DR_CAP
const MAX_BLOCK := Balance.BLOCK_CAP
static func armor_reduction(armor: float, level: int) -> float:
	if armor <= 0.0:
		return 0.0
	return minf(100.0 * armor / (armor + ARMOR_PER_LEVEL * maxi(level, 1)), MAX_ARMOR_REDUCTION)

## % less damage from Armor's reduction and a resistance together: one after
## the other (40% and 50% leave 30% of the hit: 70% less).
static func mitigation(armor_pct: float, resist: float) -> float:
	return 100.0 * (1.0 - (1.0 - armor_pct / 100.0) * (1.0 - resist / 100.0))

## Dodge and Parry never count for more than this (%).
const MAX_DODGE := Balance.DODGE_CAP
const MAX_PARRY := Balance.PARRY_CAP

## Chance (%) to block that counts: the Block stat (`block`: gear, Strength,
## buffs), capped at MAX_BLOCK. Armor adds nothing to it.
static func total_block(block: float) -> float:
	return clampf(block, 0.0, MAX_BLOCK)

## Chance (%) that counts of a Dodge / Parry stat of `value`. `cap` < 0 = the
## usual cap (an ability can raise a character's cap: Humming Blade for Parry,
## Reflections for Dodge).
static func capped_avoid(stat: String, value: float, cap: float = -1.0) -> float:
	if cap < 0.0:
		cap = MAX_PARRY if stat == PARRY else MAX_DODGE
	return clampf(value, 0.0, cap)

## Threat: damage x this for everyone, x the ability's own threat_multiplier on
## top (tank abilities ~4x). Healing makes this much threat per point healed.
const HEAL_THREAT := 1.0

## Old saves / data used a flat "damage" stat: it now counts as this.
const LEGACY := {"damage": {SPELL_POWER: 1.0, ATTACK_POWER: 1.0}}

## Suffix for percent modifiers of a stat: {"intellect%": 1} = +1% Intellect.
const PCT := "%"

# --- Resolving -------------------------------------------------------------------

## Final value of `stat`. `raw` returns the flat sum for a key from gear,
## talents, buffs... (including "<stat>%" keys for percent modifiers).
## final = (base + flat + from primaries) x (1 + percent / 100)
static func resolve(stat: String, raw: Callable) -> float:
	var v: float = float(BASE.get(stat, 0.0)) + float(raw.call(stat))
	for legacy in LEGACY:
		if LEGACY[legacy].has(stat):
			v += float(raw.call(legacy)) * float(LEGACY[legacy][stat])
	for primary in DERIVED:
		if DERIVED[primary].has(stat):
			v += resolve(primary, raw) * float(DERIVED[primary][stat])
	var pct := float(raw.call(stat + PCT))
	if pct != 0.0:
		v *= 1.0 + pct / 100.0
	return v

## Final value of `stat` from a plain totals dictionary (e.g. PlayerData.total_stats(),
## i.e. without buffs). Used by menus.
static func from_totals(stat: String, totals: Dictionary) -> float:
	return resolve(stat, func(k): return float(totals.get(k, 0.0)))

## "Spell", "Ability" or "" from an action's tags.
static func kind_of(tags: PackedStringArray) -> String:
	if tags.has("Spell"):
		return "Spell"
	if tags.has("Ability") or tags.has("AutoAttack"):
		return "Ability"
	return ""

## Crit chance (%) of a hit: Critical Strike, plus Spell Critical Strike for spells.
static func crit_chance(tags: PackedStringArray, stat_of: Callable) -> float:
	var c := float(stat_of.call(CRIT))
	if kind_of(tags) == "Spell":
		c += float(stat_of.call(SPELL_CRIT))
	return c

## Flat bonus a hit (or heal) gets from Spell Power / Attack Power.
## `stat_of` returns a final stat value (e.g. node.get_stat).
static func power_bonus(tags: PackedStringArray, stat_of: Callable) -> float:
	var coef: Dictionary = POWER.get(kind_of(tags), {})
	var out := 0.0
	for s in coef:
		out += float(stat_of.call(s)) * float(coef[s])
	return out

## Haste -> speed multiplier (20% haste = 1.2: cast times / intervals / 1.2).
static func haste_mult(haste: float) -> float:
	return maxf(1.0 + haste / 100.0, 0.1)

# --- Display ------------------------------------------------------------------------

## What a stat does, for stat tooltips (level-up panel, character sheets).
const DESCRIPTIONS := {
	INTELLECT: "Each point gives 0.5 Spell Power, 5.7 Max Mana and a little Spell Critical Strike.",
	AGILITY: "Each point gives 0.5 Attack Power, a little Critical Strike and a little Dodge.",
	STRENGTH: "Each point gives 1 Attack Power, a little Parry and a little Block.",
	DODGE: "Chance to dodge an incoming hit completely: no damage and none of its effects. Agility adds a little. Capped at {dodge_cap}%.",
	PARRY: "Chance to parry an incoming hit completely: no damage and none of its effects. Strength adds a little. Capped at {parry_cap}%.",
	BLOCK: "Chance to block an incoming hit completely: no damage and none of its effects. From Block on gear and a little from Strength. Capped at {block_cap}%.",
	CONSTITUTION: "Each point gives 5.7 Max Health.",
	ARMOR: "Reduces all the damage you take, from every school and from damage over time. The same Armor takes off less at a higher level. Capped at {armor_cap}%.",
	HASTE: "Faster casts, channels, auto-attacks and DoT ticks. 20% Haste = everything 20% faster. The global cooldown gets 40% of your Haste.",
	CRIT: "Chance for any hit (spells, abilities, attacks and DoTs) to deal double damage.",
	CRIT_RATING: "Gear's critical strike stat. Every 70 rating = +1% Critical Strike.",
	SPELL_CRIT: "Extra critical strike chance for spells only, on top of Critical Strike.",
	SPELL_POWER: "Makes everything hit harder. Spells get 60% of it and abilities 20%. Heals scale with it too.",
	ATTACK_POWER: "Makes everything hit harder. Abilities and weapon attacks get 60% of it and spells 20%.",
	MAX_HEALTH: "How much damage you can take. Out of combat you regenerate health quickly, in combat slowly.",
	MAX_MANA: "Mana pool for spells. Mana regenerates over time.",
	MOVE_SPEED: "How fast you run. A rare stat.",
	LIFESTEAL: "Returns this % of your damage and of your healing on others to you as health. Rare, and small numbers are strong.",
}

## Tooltip text for `stat` (name + what it does).
static func describe(stat: String) -> String:
	var base := stat.trim_suffix(PCT)
	var text := str(DESCRIPTIONS.get(base, ""))
	# (The caps are quoted from balance.gd, so the text can't go stale.)
	text = text.replace("{dodge_cap}", num(MAX_DODGE)).replace("{parry_cap}", num(MAX_PARRY)).replace("{block_cap}", num(MAX_BLOCK)).replace("{armor_cap}", num(MAX_ARMOR_REDUCTION))
	return "%s\n%s" % [label(base), text]

static func label(stat: String) -> String:
	var base := stat.trim_suffix(PCT)
	var l: String = LABELS.get(base, base.capitalize())
	return l

static func is_percent(stat: String) -> bool:
	return stat.ends_with(PCT) or PERCENT_STATS.has(stat)

## Gear stats that grow with item level on the gentle percent curve (pct_scale)
## instead of flat_unit: percent stats, plus Critical Strike Rating (a flat
## number, but it is worth a percentage).
static func scales_like_percent(stat: String) -> bool:
	return is_percent(stat) or stat == CRIT_RATING

## Item stats saved or authored before Critical Strike Rating existed:
## crit_chance -> crit_rating (x100, +20% on top), haste -20%. (Format 1 -> 2;
## squish_item_stats then takes them to the current format.)
const OLD_CRIT_TO_RATING := 120.0
const OLD_HASTE_MULT := 0.8
static func migrate_item_stats(stats: Dictionary) -> Dictionary:
	var out := {}
	for s in stats:
		var v := float(stats[s])
		match str(s):
			CRIT:
				out[CRIT_RATING] = float(out.get(CRIT_RATING, 0.0)) + roundf(v * OLD_CRIT_TO_RATING)
			HASTE:
				out[HASTE] = float(out.get(HASTE, 0.0)) + roundf(v * OLD_HASTE_MULT * 10.0) / 10.0
			_:
				out[s] = float(out.get(s, 0.0)) + v
	return out

## Haste from every source is this share of what it was (there was too much).
const HASTE_CUT := 0.7

## Rolled item stats saved before the stat squish (format 2 -> 3): flat stats and
## Critical Strike Rating x SQUISH (worth the same as before), Haste x HASTE_CUT.
static func squish_item_stats(stats: Dictionary) -> Dictionary:
	var out := {}
	for s in stats:
		var v := float(stats[s])
		var key := str(s)
		if key == HASTE:
			out[s] = roundf(v * HASTE_CUT * 10.0) / 10.0
		elif key == CRIT_RATING or not (is_percent(key) or key == MAX_HEALTH or key == MAX_MANA):
			out[s] = maxf(roundf(v * SQUISH), 1.0) if v > 0.0 else roundf(v * SQUISH)
		else:
			out[s] = v
	return out

static func num(v: float) -> String:
	return ("%d" % v) if is_equal_approx(v, round(v)) else ("%.1f" % v)

## "+3 Intellect", "+5% Haste", "+1% Intellect" (for "intellect%").
static func bonus_line(stat: String, value: float) -> String:
	if LEGACY.has(stat):
		return "%s%s Spell & Attack Power" % ["+" if value >= 0 else "", num(value)]
	return "%s%s%s %s" % ["+" if value >= 0 else "", num(value), "%" if is_percent(stat) else "", label(stat)]

## Stat panel row text for a final value. `values` = every stat of the panel
## (the Block row is a total: it needs the Armor next to it).
static func panel_line(stat: String, v: float, values: Dictionary = {}) -> String:
	match stat:
		DODGE:   # (`values` may carry the character's own cap right now: "dodge_cap", higher with Reflections)
			return "Dodge  %s%%" % num(capped_avoid(stat, v, float(values.get("dodge_cap", -1.0))))
		PARRY:   # (... and "parry_cap", higher with Humming Blade / Crossguard)
			return "Parry  %s%%" % num(capped_avoid(stat, v, float(values.get("parry_cap", -1.0))))
		BLOCK:
			return "Block  %s%%" % num(total_block(v))
		ARMOR:
			return "Armor  %d  (%s%% less damage)" % [int(v), num(armor_reduction(v, _player_level()))]
		MAX_HEALTH:
			return "Max Health  %d" % int(v)
		MOVE_SPEED:
			return "Move Speed  %s%s%%" % ["+" if v >= 0.0 else "", num(v)]   # Chilled shows -40%, not +-40%
		CRIT_RATING:
			return "Critical Strike Rating  %d  (+%s%%)" % [int(v), num(v / CRIT_RATING_PER_PCT)]
	return "%s  %s%s" % [label(stat), num(v), "%" if is_percent(stat) else ""]

static func _player_level() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	var pd: Node = tree.root.get_node_or_null("PlayerData") if tree and tree.root else null
	return int(pd.level) if pd else 1
