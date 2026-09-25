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
const SPELL_POWER := "spell_power"
const ATTACK_POWER := "attack_power"
const MAX_HEALTH := "max_health"
const MAX_MANA := "max_mana"
const MOVE_SPEED := "move_speed"       # %

## Order shown in stat panels.
const ORDER := [MAX_HEALTH, MAX_MANA, INTELLECT, AGILITY, STRENGTH, CONSTITUTION,
	SPELL_POWER, ATTACK_POWER, CRIT, SPELL_CRIT, HASTE, ARMOR, MOVE_SPEED]
const LABELS := {
	INTELLECT: "Intellect", AGILITY: "Agility", STRENGTH: "Strength", CONSTITUTION: "Constitution",
	ARMOR: "Armor", HASTE: "Haste", CRIT: "Critical Strike", SPELL_CRIT: "Spell Critical Strike",
	SPELL_POWER: "Spell Power", ATTACK_POWER: "Attack Power", MAX_HEALTH: "Max Health",
	MAX_MANA: "Max Mana", MOVE_SPEED: "Move Speed",
}
const PERCENT_STATS := [HASTE, CRIT, SPELL_CRIT, MOVE_SPEED]

## Every character starts with these.
const BASE := {MAX_HEALTH: 10.0, MAX_MANA: 10.0, CRIT: 5.0}

## Primary stat -> what each point gives.
##   Intellect    -> mana and spell crit (spells only)
##   Agility      -> attack power and crit (everything)
##   Strength     -> attack power, 1 to 1
##   Constitution -> health
const DERIVED := {
	INTELLECT: {MAX_MANA: 1.0, SPELL_CRIT: 0.5},
	AGILITY: {ATTACK_POWER: 0.5, CRIT: 0.5},
	STRENGTH: {ATTACK_POWER: 1.0},
	CONSTITUTION: {MAX_HEALTH: 1.0},
}

## How much of each power stat is added to a hit, by action kind.
## Spells lean on Spell Power, abilities (and weapon attacks) on Attack Power.
const POWER := {
	"Spell": {SPELL_POWER: 0.6, ATTACK_POWER: 0.2},
	"Ability": {SPELL_POWER: 0.2, ATTACK_POWER: 0.6},
}
## A DoT tick gets this share of the power bonus of the spell/ability that applied it.
const DOT_POWER_SHARE := 0.25

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

static func label(stat: String) -> String:
	var base := stat.trim_suffix(PCT)
	var l: String = LABELS.get(base, base.capitalize())
	return l

static func is_percent(stat: String) -> bool:
	return stat.ends_with(PCT) or PERCENT_STATS.has(stat)

static func num(v: float) -> String:
	return ("%d" % v) if is_equal_approx(v, round(v)) else ("%.1f" % v)

## "+3 Intellect", "+5% Haste", "+1% Intellect" (for "intellect%").
static func bonus_line(stat: String, value: float) -> String:
	if LEGACY.has(stat):
		return "%s%s Spell & Attack Power" % ["+" if value >= 0 else "", num(value)]
	return "%s%s%s %s" % ["+" if value >= 0 else "", num(value), "%" if is_percent(stat) else "", label(stat)]

## Stat panel row text for a final value.
static func panel_line(stat: String, v: float) -> String:
	match stat:
		ARMOR:
			return "Armor  %d  (%s%% block)" % [int(v), num(minf(v * 5.0, 60.0))]
		MAX_HEALTH:
			return "Max Health  %d" % int(v)
		MOVE_SPEED:
			return "Move Speed  %s%s%%" % ["+" if v >= 0.0 else "", num(v)]   # Chilled shows -40%, not +-40%
	return "%s  %s%s" % [label(stat), num(v), "%" if is_percent(stat) else ""]
