extends RefCounted

# Pacts: a deal every character can make for a dungeon, whatever its build.
# You hold ONE (PlayerData.pact), taken in the main menu (Abilities & Talents,
# the tab above Rune Spells) and locked while you are in a dungeon. Each has
#   a bonus      always on while the Pact is kept
#   a drawback   always on, kept or broken
#   a vow        something that must never happen. It is about what happens in
#                a fight, so no build can simply avoid it.
# Break the vow and the Pact turns against you until the dungeon ends: the bonus
# becomes the same amount as a penalty and the drawback stays (PlayerData
# .pact_broken; it is cleared when a run starts from the menu).
# This script only says what each Pact IS: its texts and what it changes, as
# static functions of (pact id, broken). The player applies them and watches the
# vows (player.gd, "Pacts"). Numbers: balance.gd (PACT_*).
# Usage: const Pacts = preload("res://scripts/pacts.gd")

const Balance = preload("res://scripts/balance.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")
const Stats = preload("res://scripts/core/stats.gd")
const Categories = preload("res://scripts/categories.gd")

const UNBOWED := "unbowed"
const THIN_LINE := "thin_line"
const RELENTLESS := "relentless"
const SIDESTEP := "sidestep"
const PURIST := "purist"
const FAST := "fast"
const SHEPHERD := "shepherd"
const VANGUARD := "vanguard"
const RESTLESS := "restless"
const RESERVOIR := "reservoir"

## The order they are listed in (it never changes: a new one goes at the end).
const ORDER := [UNBOWED, THIN_LINE, RELENTLESS, SIDESTEP, PURIST, FAST, SHEPHERD, VANGUARD, RESTLESS, RESERVOIR]

const COLOR := Color(0.86, 0.3, 0.42)
const BROKEN_COLOR := Color(0.55, 0.5, 0.55)

## name, and four texts (numbers are placeholders: TextFill.constants).
## `party`: it only does anything with at least one other player in the run.
const INFO := {
	UNBOWED: {"name": "Pact of the Unbowed",
		"bonus": "You deal {b:PACT_UNBOWED_DAMAGE}% more damage.",
		"drawback": "You take {b:PACT_UNBOWED_TAKEN}% more damage.",
		"vow": "Never go down or die.",
		"broken": "You deal {b:PACT_UNBOWED_DAMAGE}% less damage, and still take {b:PACT_UNBOWED_TAKEN}% more."},
	THIN_LINE: {"name": "Pact of the Thin Line",
		"bonus": "{b:PACT_THIN_LINE_CRIT}% more chance to critically strike.",
		"drawback": "{b:PACT_THIN_LINE_HEALTH}% less maximum health.",
		"vow": "Never drop below {b:PACT_THIN_LINE_FLOOR}% health.",
		"broken": "{b:PACT_THIN_LINE_CRIT}% less chance to critically strike, and still {b:PACT_THIN_LINE_HEALTH}% less maximum health."},
	RELENTLESS: {"name": "Pact of the Relentless",
		"bonus": "{b:PACT_RELENTLESS_HASTE}% Haste.",
		"drawback": "You move {b:PACT_RELENTLESS_SLOW}% slower.",
		"vow": "Never go {b:PACT_RELENTLESS_IDLE} sec in combat without hitting an enemy or healing an ally.",
		"broken": "{b:PACT_RELENTLESS_HASTE}% less Haste, and you still move {b:PACT_RELENTLESS_SLOW}% slower."},
	SIDESTEP: {"name": "Pact of the Sidestep",
		"bonus": "All your cooldowns recover {b:PACT_SIDESTEP_COOLDOWN}% faster.",
		"drawback": "Your abilities cost {b:PACT_SIDESTEP_COST}% more.",
		"vow": "Never take a single hit for more than {b:PACT_SIDESTEP_HIT}% of your maximum health.",
		"broken": "Your cooldowns recover {b:PACT_SIDESTEP_COOLDOWN}% slower, and your abilities still cost {b:PACT_SIDESTEP_COST}% more."},
	PURIST: {"name": "Pact of the Purist",
		"bonus": "You deal {b:PACT_PURIST_DAMAGE}% more damage.",
		"drawback": "You take {b:PACT_PURIST_TAKEN}% more damage.",
		"vow": "Never use an ability from any book but the one you chose. The basic abilities every character knows count too. Auto attacks and on-use items do not.",
		"broken": "You deal {b:PACT_PURIST_DAMAGE}% less damage, and still take {b:PACT_PURIST_TAKEN}% more."},
	FAST: {"name": "Pact of the Fast",
		"bonus": "You take {b:PACT_FAST_TAKEN}% less damage.",
		"drawback": "Healing you receive is {b:PACT_FAST_HEALING}% smaller.",
		"vow": "Never heal yourself with a spell or ability. Lifesteal and heals from allies are fine.",
		"broken": "You take {b:PACT_FAST_TAKEN}% more damage, and healing you receive is {b:PACT_FAST_HEALING_BROKEN}% smaller."},
	SHEPHERD: {"name": "Pact of the Shepherd", "party": true,
		"bonus": "Your heals are {b:PACT_SHEPHERD_HEALS}% larger.",
		"drawback": "Your heals on yourself are {b:PACT_SHEPHERD_SELF}% smaller.",
		"vow": "Never let a party member go down within {b:PACT_SHEPHERD_RANGE} m of you.",
		"broken": "Your heals are {b:PACT_SHEPHERD_HEALS}% smaller, and on yourself still {b:PACT_SHEPHERD_SELF}% smaller."},
	VANGUARD: {"name": "Pact of the Vanguard", "party": true,
		"bonus": "You take {b:PACT_VANGUARD_TAKEN}% less damage.",
		"drawback": "You deal {b:PACT_VANGUARD_DAMAGE}% less damage.",
		"vow": "Never let an enemy that is attacking you turn on a party member while you are alive.",
		"broken": "You take {b:PACT_VANGUARD_TAKEN}% more damage, and still deal {b:PACT_VANGUARD_DAMAGE}% less."},
	RESTLESS: {"name": "Pact of the Restless",
		"bonus": "Mana, Fury and Energy come in {b:PACT_RESTLESS_RESOURCE}% faster.",
		"drawback": "Out of combat you lose {b:PACT_RESTLESS_BLEED}% of your maximum health every second and do not regenerate health. It starts with your first fight and never takes your last health.",
		"vow": "Never stay out of combat for more than {b:PACT_RESTLESS_IDLE} sec once your first fight has started.",
		"broken": "Mana, Fury and Energy come in {b:PACT_RESTLESS_RESOURCE}% slower, and you still lose health out of combat."},
	RESERVOIR: {"name": "Pact of the Reservoir",
		"bonus": "Your mana costs are {b:PACT_RESERVOIR_COST}% lower.",
		"drawback": "{b:PACT_RESERVOIR_MANA}% less maximum mana.",
		"vow": "Never drop below {b:PACT_RESERVOIR_FLOOR}% mana.",
		"broken": "Your mana costs are {b:PACT_RESERVOIR_COST}% higher, and you still have {b:PACT_RESERVOIR_MANA}% less maximum mana."},
}

static func exists(id: String) -> bool:
	return INFO.has(id)

static func pact_name(id: String) -> String:
	return str(INFO.get(id, {}).get("name", ""))

## Does it only work with someone else in the run?
static func party_only(id: String) -> bool:
	return bool(INFO.get(id, {}).get("party", false))

## Does it need a book chosen with it (Pact of the Purist)?
static func needs_book(id: String) -> bool:
	return id == PURIST

## Can `book` be a Purist's book?
static func valid_book(book: String) -> bool:
	return Categories.ORDER.has(book)

## One of its texts ("bonus", "drawback", "vow", "broken") with the numbers filled in.
static func text(id: String, part: String) -> String:
	return TextFill.constants(str(INFO.get(id, {}).get(part, "")))

## Its name as it is shown once taken: "Pact of the Purist (Fire)".
static func title(id: String, book: String = "") -> String:
	var n := pact_name(id)
	if needs_book(id) and valid_book(book):
		n += " (%s)" % Categories.cat_name(book)
	return n

## What its buff says in the game: what it does right now, and what must not happen.
static func status_text(id: String, broken: bool) -> String:
	if not exists(id):
		return ""
	if broken:
		return "Broken until the dungeon ends. %s" % text(id, "broken")
	return "%s %s Vow: %s" % [text(id, "bonus"), text(id, "drawback"), text(id, "vow")]

# --- What a Pact changes (id "" or an unknown one: nothing) -----------------------------

## +1 kept, -1 broken: the bonus turns into the same amount as a penalty.
static func _sign(broken: bool) -> float:
	return -1.0 if broken else 1.0

## % on the damage I deal.
static func damage_dealt_pct(id: String, broken: bool) -> float:
	match id:
		UNBOWED:
			return Balance.PACT_UNBOWED_DAMAGE * _sign(broken)
		PURIST:
			return Balance.PACT_PURIST_DAMAGE * _sign(broken)
		VANGUARD:
			return -Balance.PACT_VANGUARD_DAMAGE
	return 0.0

## % on the damage I take.
static func damage_taken_pct(id: String, broken: bool) -> float:
	match id:
		UNBOWED:
			return Balance.PACT_UNBOWED_TAKEN
		PURIST:
			return Balance.PACT_PURIST_TAKEN
		FAST:
			return -Balance.PACT_FAST_TAKEN * _sign(broken)
		VANGUARD:
			return -Balance.PACT_VANGUARD_TAKEN * _sign(broken)
	return 0.0

## What it adds to my stats: stat key -> amount ("<stat>%" = percent of that stat).
static func stat_mods(id: String, broken: bool) -> Dictionary:
	match id:
		THIN_LINE:
			return {Stats.CRIT: Balance.PACT_THIN_LINE_CRIT * _sign(broken), Stats.MAX_HEALTH + Stats.PCT: -Balance.PACT_THIN_LINE_HEALTH}
		RELENTLESS:
			return {Stats.HASTE: Balance.PACT_RELENTLESS_HASTE * _sign(broken), Stats.MOVE_SPEED: -Balance.PACT_RELENTLESS_SLOW}
		RESERVOIR:
			return {Stats.MAX_MANA + Stats.PCT: -Balance.PACT_RESERVOIR_MANA}
	return {}

static func stat_mod(id: String, broken: bool, stat: String) -> float:
	return float(stat_mods(id, broken).get(stat, 0.0))

## How fast my cooldowns recover (1 = as usual).
static func cooldown_rate(id: String, broken: bool) -> float:
	if id == SIDESTEP:
		return 1.0 + Balance.PACT_SIDESTEP_COOLDOWN / 100.0 * _sign(broken)
	return 1.0

## What an ability's cost in `resource` ("mana", "fury", "energy") is multiplied by.
static func cost_mult(id: String, broken: bool, resource: String) -> float:
	match id:
		SIDESTEP:
			return 1.0 + Balance.PACT_SIDESTEP_COST / 100.0
		RESERVOIR:
			if resource == "mana":
				return 1.0 - Balance.PACT_RESERVOIR_COST / 100.0 * _sign(broken)
	return 1.0

## What a heal landing on me is multiplied by (`from_self`: I cast it).
static func heal_taken_mult(id: String, broken: bool, from_self: bool) -> float:
	match id:
		FAST:
			return 1.0 - (Balance.PACT_FAST_HEALING_BROKEN if broken else Balance.PACT_FAST_HEALING) / 100.0
		SHEPHERD:
			if from_self:
				return 1.0 - Balance.PACT_SHEPHERD_SELF / 100.0
	return 1.0

## What the heals I cast are multiplied by.
static func heal_done_mult(id: String, broken: bool) -> float:
	if id == SHEPHERD:
		return 1.0 + Balance.PACT_SHEPHERD_HEALS / 100.0 * _sign(broken)
	return 1.0

## What Mana, Fury and Energy I gain are multiplied by.
static func resource_gain_mult(id: String, broken: bool) -> float:
	if id == RESTLESS:
		return 1.0 + Balance.PACT_RESTLESS_RESOURCE / 100.0 * _sign(broken)
	return 1.0

## % of max health lost every second out of combat (kept or broken); with it there is no health regeneration.
static func bleed_pct(id: String) -> float:
	return Balance.PACT_RESTLESS_BLEED if id == RESTLESS else 0.0

# --- The vows (each answers: is the Pact broken by this?) ---------------------------------

## Going down, or dying.
static func breaks_on_down(id: String) -> bool:
	return id == UNBOWED

## A hit of `amount` that left me at `health` of `max_health`.
static func breaks_on_hit(id: String, amount: int, health: int, max_health: int) -> bool:
	if max_health <= 0:
		return false
	match id:
		THIN_LINE:
			return float(health) * 100.0 / float(max_health) < Balance.PACT_THIN_LINE_FLOOR
		SIDESTEP:
			return float(amount) * 100.0 / float(max_health) > Balance.PACT_SIDESTEP_HIT
	return false

## `seconds` in combat without hitting an enemy or healing an ally.
static func breaks_on_idle(id: String, seconds: float) -> bool:
	return id == RELENTLESS and seconds > Balance.PACT_RELENTLESS_IDLE

## `seconds` out of combat, once the first fight has started.
static func breaks_on_rest(id: String, seconds: float) -> bool:
	return id == RESTLESS and seconds > Balance.PACT_RESTLESS_IDLE

## Using an ability of book `category` with the Purist's `book` (`is_item`: an on-use item).
static func breaks_on_ability(id: String, category: String, book: String, is_item: bool) -> bool:
	return id == PURIST and not is_item and valid_book(book) and category != book

## A heal of mine landing on me (`is_ability`: a spell's or an ability's own heal, so no Lifesteal, talent or rune heal).
static func breaks_on_self_heal(id: String, is_ability: bool) -> bool:
	return id == FAST and is_ability

## A party member going down `dist` metres from me.
static func breaks_on_ally_down(id: String, dist: float) -> bool:
	return id == SHEPHERD and dist <= Balance.PACT_SHEPHERD_RANGE

## An enemy that was attacking me turning on a party member.
static func breaks_on_lost_enemy(id: String) -> bool:
	return id == VANGUARD

## Being at `mana` of `max_mana`.
static func breaks_on_mana(id: String, mana: float, max_mana: float) -> bool:
	return id == RESERVOIR and max_mana > 0.0 and mana * 100.0 / max_mana < Balance.PACT_RESERVOIR_FLOOR
