extends RefCounted

# Talent trees: one per category "book" (see categories.gd). Each tree is a grid
# of ROWS rows (top to bottom) x COLUMNS columns; every row holds at least
# MIN_PER_ROW talents placed on some of the columns.
#
# Unlock rules:
#   1. Rows unlock GLOBALLY: once POINTS_TO_UNLOCK_NEXT points are spent in row N
#      of ANY tree (summed across all trees), row N+1 opens in EVERY tree.
#   2. Links: LINKS holds [from, to] pairs of talents (drawn as lines in the book).
#      Maxing out `from` unlocks `to` even if its row is still locked, so the
#      follow-up talents of an ability can be taken before their rows open.
#      Links may cross rows and even books (lines are only drawn inside one book).
#
# Own only: a talent that reacts to an effect (Chilled, Frozen, a Rime Shell, a
# burn...) only ever counts the player's OWN - never a party member's - unless
# its text says it works for allies. The code asks StatusContainer.has_from().
#
# Talent ids are "<category>_r<row>c<column>", 1-based (e.g. "fire_r3c2" = Fire
# book, row 3, column 2), so a talent keeps its id when the others change.
# Usage: const Talents = preload("res://scripts/talents.gd")

const Categories = preload("res://scripts/categories.gd")

const ROWS := 10
const COLUMNS := 7
const MIN_PER_ROW := 2
const MAX_PER_ROW := 5
const POINTS_TO_UNLOCK_NEXT := 3
const POINTS_AT_LEVEL_1 := 5
const POINTS_PER_LEVEL := 1
## Every this many levels (2, 4, 6...) gives one extra point on top.
const BONUS_POINT_EVERY := 2
## Max rank of a talent slot that hasn't been designed yet.
const PLACEHOLDER_RANKS := 2

## Talent points available at a player level: 5 at level 1, then +1 per level
## and +1 more on every second level (2, 4, 6...), plus a bonus point for
## reaching the max level - 80 at level 50.
static func points_for_level(level: int) -> int:
	var lv := maxi(level, 1)
	var pts := POINTS_AT_LEVEL_1 + (lv - 1) * POINTS_PER_LEVEL + lv / BONUS_POINT_EVERY
	if lv >= MAX_LEVEL:
		pts += MAX_LEVEL_BONUS
	return pts

## Level cap (same as PlayerData.MAX_LEVEL) and the extra point for reaching it.
const MAX_LEVEL := 50
const MAX_LEVEL_BONUS := 1

# --- Layout ---------------------------------------------------------------------------
# Which columns (0-based, 0..COLUMNS-1) hold a talent, per row. A diamond-ish
# shape that widens and narrows going down, like a WoW talent tree.
const DEFAULT_LAYOUT := [
	[2, 3, 4],
	[1, 3, 5],
	[0, 2, 4, 6],
	[1, 2, 3, 4, 5],
	[0, 2, 4, 6],
	[1, 3, 5],
	[0, 1, 3, 5, 6],
	[1, 2, 4, 5],
	[2, 3, 4],
	[1, 3, 5],
]
## Per-book layouts (category -> rows of columns, 0..COLUMNS-1). Every row is
## mirror-symmetric around the middle column (3), with 2-5 talents (mostly 2
## or 3), and no two books share a shape. Books not listed use DEFAULT_LAYOUT.
## Every slot of Fire, Frost and Lightning holds a designed talent (a new one
## needs a new slot: keep each row mirror-symmetric).
## In those three books an ability's talents run top to bottom, the most
## important first, joined by LINKS. A link is drawn as a straight line between
## the two slots, so when a talent moves, check its lines still run clear of the
## other talents (tests/test_talent_links.gd does).
##   Fire       melee down the left (columns 0-1), the tank down the right
##              (column 5), the caster in the middle.
##   Frost      the bow talents together on the right of rows 1-5 (columns 4-5),
##              shields down the right edge (column 6), Ice Shards down the
##              middle, Hoarfrost down column 1.
##   Lightning  melee down the left, the parry tank down the right (column 4 and
##              the right edge), the caster and the bow down the middle.
##   Arcane     the caster in the middle (rows 1-4 so far), the dodge tank down
##              both edges of rows 2-9 (columns 0-1 and 5-6): what makes and
##              shatters Reflections on the left, staying alive on the right.
##              Rows 2, 3 and 9 got their two edge slots for it. Melee (Traces
##              and Encore) is in the middle of rows 5-9 (columns 2 and 4; rows
##              5 and 8 got those two slots for it). The bottom row has one
##              5-rank talent each for the tank, any Arcane build and melee.
##              Its open talents (they work with every book's abilities: Quick
##              Study, Two Minds, Echo, Mirror Finish, Overtime, Light Touch,
##              Slipstream, Borrowed Time) took the fifth slots of rows 1, 2,
##              4, 5, 6 and 10. One slot is still empty (row 10, column 4).
##   Shadow     the caster (the Breach) down the middle, melee (the Hounds) down
##              both edges of rows 3-9: what the Hounds themselves do on the
##              left (column 0, and column 1 of row 8), one ability's talents
##              each on the right (column 6). Open talents fill rows 1 and 2
##              and one slot of the bottom row; Pack Leader is the melee build's
##              5-rank talent there. The healer (the Strings) has the middle of
##              row 3 and the slot beside Interest in row 4 for the Strings
##              themselves, three slots of row 8 (columns 2, 4 and 5),
##              columns 2 and 4 of row 9, and Steady Hands, its 5-rank talent,
##              in the bottom row. Its three open talents took the edges of
##              row 1 and the middle of row 2.
##              Small Change sits straight under Interest (row 5), so the middle
##              column below it holds one talent per row: Deep Call (caster),
##              Ill Will (open), Hard Pull (healer), Wide Pack (melee).
##              One slot is still empty (row 10, column 5).
const LAYOUTS := {
	"fire": [[0, 2, 3, 4, 6], [1, 2, 4, 5], [0, 3, 6], [1, 3, 5], [0, 2, 4, 6], [1, 2, 4, 5], [1, 5], [2, 3, 4], [1, 5], [1, 3, 5]],
	"frost": [[0, 2, 4, 6], [1, 2, 4, 5], [1, 3, 5], [0, 2, 4, 6], [1, 2, 4, 5], [2, 3, 4], [1, 3, 5], [0, 3, 6], [1, 3, 5], [2, 3, 4]],
	"lightning": [[1, 2, 3, 4, 5], [0, 2, 4, 6], [0, 2, 3, 4, 6], [2, 3, 4], [1, 3, 5], [0, 3, 6], [2, 3, 4], [1, 2, 4, 5], [1, 3, 5], [2, 3, 4]],
	"arcane": [[0, 2, 3, 4, 6], [0, 1, 3, 5, 6], [0, 2, 4, 6], [0, 1, 3, 5, 6], [1, 2, 3, 4, 5], [1, 2, 3, 4, 5], [0, 2, 4, 6], [1, 2, 4, 5], [0, 2, 4, 6], [1, 2, 3, 4, 5]],
	"shadow": [[0, 1, 3, 5, 6], [0, 2, 3, 4, 6], [0, 2, 3, 4, 6], [0, 2, 3, 4, 6], [0, 1, 3, 5, 6], [0, 2, 3, 4, 6], [0, 2, 3, 4, 6], [1, 2, 3, 4, 5], [0, 2, 3, 4, 6], [1, 2, 3, 4, 5]],
	"nature": [[2, 4], [0, 3, 6], [1, 5], [2, 3, 4], [0, 1, 5, 6], [2, 4], [1, 3, 5], [1, 5], [2, 3, 4], [1, 5]],
	"holy": [[0, 1, 3, 5, 6], [0, 1, 3, 5, 6], [0, 2, 3, 4, 6], [0, 1, 3, 5, 6], [0, 1, 3, 5, 6], [0, 2, 3, 4, 6], [0, 2, 3, 4, 6], [1, 2, 3, 4, 5], [0, 2, 3, 4, 6], [1, 2, 3, 4, 5]],
	# (One book where Warrior, Rogue and Ranger used to be three.)
	"martial": [[1, 3, 5], [0, 2, 4, 6], [1, 5], [2, 3, 4], [0, 3, 6], [1, 2, 4, 5], [2, 4], [1, 3, 5], [0, 2, 4, 6], [2, 3, 4]],
}

# --- Talent definitions ------------------------------------------------------------
# category -> { "r<row>c<col>": [name, max_rank, description, extra] }  (1-based row/col).
# A slot in the layout without an entry here is an empty placeholder.
# `extra` (optional):
#   "key"      stable name code uses to look the talent up (PlayerData.talent_value)
#   "values"   the talent's number at rank 1, 2, 3... (read with talent_value)
#   "stats"    stat bonus PER RANK, added to the player's stats (e.g. {"haste": 1.0})
#   "requires" the ONE ability the talent works with: it must be learned before
#              points can be spent here (the tooltip says "Requires X to be learned")
#   "capstone" text of a bonus that only turns on at max rank (PlayerData.talent_capstone)
#   "capstone_requires" an ability that must be known for the capstone to do anything
const TALENTS := {
	"fire": {
		# Open talents: themed to the book (burns, blocking) but they work with every
		# book's spells and abilities (player.gd, "Fire and Lightning: the open
		# talents"). They took new slots: the middle of row 1 and the edges of row 5.
		# Feed the Flames: Player._open_talents_modify; Last Ember: StatusContainer
		# asks Player.dot_last_tick_pct; Tempered: Player._tempered.
		"r1c4": ["Feed the Flames", 3, "Your direct hits deal {v}% more damage to enemies that carry one of your damage over time effects.",
			{"key": "fire_feed_the_flames", "values": [2.0, 4.0, 6.0]}],
		"r5c1": ["Last Ember", 2, "When one of your damage over time effects runs its full time, it ticks once more for {v}% of a tick's damage.",
			{"key": "fire_last_ember", "values": [50.0, 100.0]}],
		"r5c7": ["Tempered", 3, "Each attack you block increases your Armor by {v}% for {b:TEMPERED_TIME} sec, stacking up to {b:TEMPERED_STACKS} times.",
			{"key": "fire_tempered", "values": [2.0, 4.0, 6.0]}],
		# Firebolt (ability id "fireball") crits less, and turns crit chance into damage.
		# The maths is Player.fire_crit_rules().
		"r1c3": ["Tempered Flame", 2, "Your {n:fireball} gains {v}% less of your critical strike chance, but deals bonus damage equal to {v2}% of your critical strike chance.",
			{"key": "fire_tempered_flame", "values": [40.0, 60.0], "values2": [10.0, 20.0], "requires": "fireball"}],
		# Was the Rune of Smoldering Focus (crit chance x 0.6): now crit chance x 0.5
		# at max rank, split evenly over the 5 ranks. The hook is in player.gd.
		# Vent Flames comes back sooner the less you crit (Player._pressure_valve).
		"r2c2": ["Pressure Valve", 2, "Each of your Fire spells that fails to critically strike takes {v} sec off the cooldown of {n:ventflames}.",
			{"key": "fire_pressure_valve", "values": [0.25, 0.5], "requires": "ventflames"}],
		# Generic Fire talents (no ability needed), on the outside of row 1 and the
		# inside of row 2. Flash Point is a plain stat; Forge-Hardened is worked out in
		# PlayerData._compute_total_stats; the other two in Player._on_damage_modify.
		"r1c1": ["Flash Point", 3, "Increases your Critical Strike chance by {v}%.",
			{"key": "fire_flash_point", "values": [1.0, 2.0, 3.0], "stats": {"crit_chance": 1.0}}],
		"r1c7": ["Forge-Hardened", 3, "Increases your Attack Power by {v}% of your Strength.",
			{"key": "fire_forge_hardened", "values": [2.0, 4.0, 6.0]}],
		"r2c3": ["Lingering Embers", 3, "Your Fire damage over time effects deal {v}% more damage.",
			{"key": "fire_lingering_embers", "values": [3.0, 6.0, 9.0]}],
		"r2c5": ["Controlled Burn", 3, "Your Fire spells and abilities generate {v}% less threat.",
			{"key": "fire_controlled_burn", "values": [5.0, 10.0, 15.0]}],
		# (Moved down from the middle of row 2 to make room: see MOVED.)
		"r3c4": ["Cool Under Fire", 2, "You take {v}% less damage while {n:coolhead} is active.",
			{"key": "fire_cool_under_fire", "values": [10.0, 20.0], "requires": "coolhead"}],
		# The Fire melee talents sit down the left side of the book (Heat: see player.gd),
		# linked top to bottom (see LINKS).
		"r3c1": ["Kindling", 2, "{n:searingstrike} has a {v}% chance to build one extra Heat.",
			{"key": "fire_kindling", "values": [15.0, 30.0], "requires": "searingstrike"}],
		"r4c2": ["Fresh Tinder", 3, "Your abilities have a {v}% chance to add {b:FRESH_TINDER_SECONDS} sec to your {n:immolate} on the target they hit, up to its base duration.",
			{"key": "fire_fresh_tinder", "values": [10.0, 20.0, 30.0], "requires": "immolate",
			"capstone": "Adds {b:FRESH_TINDER_CAPSTONE_SECONDS} sec instead."}],
		"r7c2": ["Forge Heat", 4, "Heat lasts {v} sec longer before it is lost.",
			{"key": "fire_forge_heat", "values": [0.5, 1.0, 1.5, 2.0], "requires": "immolate"}],
		# Rewards holding full Heat (Quench and Flare spend it first, so they never get this).
		"r9c2": ["White Heat", 3, "While you hold the maximum {b:HEAT_MAX_STACKS} Heat, your abilities deal {v}% more Fire damage.",
			{"key": "fire_white_heat", "values": [5.0, 10.0, 15.0], "requires": "immolate"}],
		# The caster's Immolate, Crucible and Kiln Blast talents.
		"r5c3": ["Long Burn", 3, "Your {n:immolate} lasts {v} sec longer.",
			{"key": "fire_long_burn", "values": [1.0, 2.0, 3.0], "requires": "immolate"}],
		"r8c4": ["Deep Crucible", 2, "Your {n:crucible} is {v} m wider and lasts {v2} sec longer.",
			{"key": "fire_deep_crucible", "values": [1.0, 2.0], "values2": [2.0, 4.0], "requires": "crucible"}],
		"r8c5": ["Stoked Kiln", 2, "{n:kilnblast} deals {v+b:KILN_BLAST_IMMOLATE_PCT}% more damage to a target with your {n:immolate}, instead of {b:KILN_BLAST_IMMOLATE_PCT}%.",
			{"key": "fire_stoked_kiln", "values": [10.0, 20.0], "requires": "kilnblast"}],
		# More of the tank's, down the right side.
		"r7c6": ["Slag Mending", 2, "When your Slag shatters, you are healed for {v}% of your maximum health per stack.",
			{"key": "fire_slag_mending", "values": [1.0, 2.0], "requires": "slagskin"}],
		"r9c6": ["Furnace Heart", 2, "{n:cinderguard} costs {v} less Rage.",
			{"key": "fire_furnace_heart", "values": [10.0, 20.0], "requires": "cinderguard"}],
		"r1c5": ["Banked Mana", 2, "Each of your Fire spells that fails to critically strike refunds {v}% of its mana cost.",
			{"key": "fire_banked_mana", "values": [5.0, 10.0]}],
		"r4c4": ["Warm Blood", 3, "You take {v}% less damage from an enemy that has your Burning or {n:immolate} on it.",
			{"key": "fire_warm_blood", "values": [2.0, 4.0, 6.0]}],
		"r3c7": ["Deep Brand", 2, "An enemy you have Branded deals {v+b:BRAND_PCT}% less damage to you, instead of {b:BRAND_PCT}%.",
			{"key": "fire_deep_brand", "values": [3.0, 6.0], "requires": "brand"}],
		# The Fire bow's talent.
		"r8c3": ["Thick Pitch", 2, "The pitch from your {n:pitcharrow} lasts {v} sec longer.",
			{"key": "fire_thick_pitch", "values": [2.0, 4.0], "requires": "pitcharrow"}],
		"r6c2": ["Afterglow", 2, "For {b:AFTERGLOW_TIME} sec after you use {n:quench}, your auto-attacks also deal {v}% of their damage as Fire damage.",
			{"key": "fire_afterglow", "values": [10.0, 20.0], "requires": "quench"}],
		# The Fire tank's talents sit down the right side of the book.
		"r2c6": ["Thick Slag", 3, "Each stack of Slag gives {v}% more Armor.",
			{"key": "fire_thick_slag", "values": [20.0, 40.0, 60.0], "requires": "slagskin"}],
		"r4c6": ["Hot Iron", 4, "Attacks you block burn the attacker for {v}% more ({n:slagskin} and {n:cinderguard}).",
			{"key": "fire_hot_iron", "values": [15.0, 30.0, 45.0, 60.0]}],
		"r6c5": ["Flashover", 3, "When your {n:slowfuse} explodes on a target that has your {n:immolate}, each other enemy within {b:IMMOLATE_SPREAD_RADIUS} m has a {v}% chance to catch your {n:immolate} too.",
			{"key": "fire_flashover", "values": [10.0, 20.0, 30.0], "requires": "slowfuse"}],
		"r6c6": ["Smoldering Debris", 2, "When your Slag shatters it leaves a burning patch {b2:CLINKER_RADIUS} m wide for {b:CLINKER_TIME} sec, dealing {v}% of the shatter's damage {bev:CLINKER_TICK} to enemies standing in it.",
			{"key": "fire_clinker", "values": [10.0, 20.0], "requires": "slagskin"}],
		"r6c3": ["Scattered Embers", 2, "Each ember of your {n:embervolley} also strikes {v} additional enemies within {b:EMBER_VOLLEY_SPLIT_RADIUS} m of your target.",
			{"key": "fire_volley_targets", "values": [1.0, 2.0], "requires": "embervolley"}],
		# Turns Slow Fuse from a no-crit payoff into a crit payoff (Player.fuse_grow_chance).
		"r5c5": ["Volatile Fuse", 3, "Your Fire critical strikes have a {v}% chance to grow your {n:slowfuse}, and your hits that do not critically strike are {v}% less likely to grow it.",
			{"key": "fire_fuse_crit", "values": [50.0, 70.0, 100.0], "requires": "slowfuse"}],
		"r10c2": ["Smoldering Focus", 5, "Every Fire spell hit that does NOT critically strike builds a stack of Smoldering Focus (up to {e:smoldering_focus.stacks}, {e:smoldering_focus.time} sec, refreshed by each stack). Your next Fire spell critical strike spends them all and deals +(critical strike chance x {v})% damage per stack.",
			{"key": "fire_smoldering_focus", "values": [0.1, 0.2, 0.3, 0.4, 0.5]}],
		# Between the two: both keep part of their stacks when spent
		# (Player.stacks_kept_on_use, asked by the StatusContainer).
		"r10c4": ["Banked Coals", 2, "When your Smoldering Focus or Afterburn stacks are spent, you keep {v}% of them (rounded down).",
			{"key": "fire_banked_coals", "values": [25.0, 50.0]}],
		# Smoldering Focus's mirror image: crits build, the next non-crit spends, and
		# a stack is worth more the LESS crit chance you have. The hook is in player.gd.
		"r10c6": ["Afterburn", 5, "Every Fire spell hit that critically strikes builds a stack of Afterburn (up to {e:afterburn.stacks}, {e:afterburn.time} sec, refreshed by each stack). Your next Fire spell hit that does NOT critically strike spends them all and deals +((100 - critical strike chance) x {v})% damage per stack.",
			{"key": "fire_afterburn", "values": [0.1, 0.2, 0.3, 0.4, 0.5]}],
	},
	"frost": {
		"r1c3": ["Frozen Focus", 3, "Increases your Haste by {v}%.",
			{"key": "frost_haste", "values": [0.7, 1.4, 2.1], "stats": {"haste": 0.7}}],
		"r1c7": ["Rime Ward", 3, "Shields you apply absorb {v}% more damage.",
			{"key": "frost_absorb", "values": [5.0, 10.0, 15.0]}],
		"r3c4": ["Splintering Cold", 3, "All of your spells have a {v}% chance to generate an Ice Shard charge.",
			{"key": "frost_shard_proc", "values": [10.0, 15.0, 20.0], "requires": "iceshards"}],
		"r2c3": ["Quickened Frost", 3, "Reduces the cast time of your {n:frostbolt} by {v} sec.",
			{"key": "frost_bolt_cast", "values": [0.1, 0.2, 0.3], "requires": "frostbolt"}],
		"r2c2": ["Cold Discipline", 3, "Reduces the mana cost of your spells by {v}% and the threat generated by your Frost spells by {v2}%.",
			{"key": "frost_discipline", "values": [2.0, 3.0, 4.0], "values2": [5.0, 10.0, 15.0]}],
		"r1c1": ["Bitter Cold", 3, "You deal {v}% increased damage to targets you have Chilled.",
			{"key": "frost_chilled_dmg", "values": [2.0, 4.0, 6.0]}],
		"r4c1": ["Frozen Mind", 3, "Increases your Spell Power by {v}% of your Intellect.",
			{"key": "frost_int_sp", "values": [2.0, 4.0, 6.0]}],
		# (values = what is added to Rime Edge's own damage.)
		"r4c3": ["Honed Rime", 3, "The extra hit of your {n:rimeedge} deals {v+dmg:rimeedge} Frost damage, instead of {dmg:rimeedge}.",
			{"key": "frost_honed_rime", "values": [0.05, 0.1, 0.15], "requires": "rimeedge"}],
		"r3c2": ["Deep Hoarfrost", 3, "Increases the damage of {n:hoarfrost} by {v}% and its duration by {v2} sec.",
			{"key": "frost_hoarfrost", "values": [15.0, 20.0, 25.0], "values2": [2.0, 3.0, 4.0], "requires": "hoarfrost"}],
		"r5c2": ["Brittle Rime", 3, "Your direct damage has a {v}% chance to trigger the burst of your {n:hoarfrost} on the target. {n:hoarfrost} stays on the target and still bursts when it expires.",
			{"key": "frost_hoarfrost_burst", "values": [5.0, 10.0, 15.0], "requires": "hoarfrost"}],
		"r7c2": ["Clean Break", 2, "{n:icebreaker} refunds {v} Rage when it hits a target you have Frozen.",
			{"key": "frost_clean_break", "values": [10.0, 20.0], "requires": "icebreaker"}],
		# (values = what is added to Coldspike's 25%.)
		"r6c3": ["Piercing Cold", 2, "{n:coldspike} deals {v+b:COLDSPIKE_FROZEN_PCT}% more damage to a target you have Frozen, instead of {b:COLDSPIKE_FROZEN_PCT}%.",
			{"key": "frost_piercing_cold", "values": [10.0, 20.0], "requires": "coldspike"}],
		"r8c1": ["Lingering Frost", 3, "Your Frost damage over time effects last {v} sec longer.",
			{"key": "frost_dot_duration", "values": [1.0, 2.0, 3.0]}],
		"r6c5": ["Cold Snap", 3, "Freezing a target reduces your next global cooldown by {v} sec.",
			{"key": "frost_cold_snap", "values": [0.1, 0.2, 0.3]}],
		"r7c4": ["Splintering", 1, "Your Ice Shards that hit a target you have Frozen or Rime Shelled splinter, hitting one random other enemy within {b:SPLINTER_RANGE} m for {vdmg:iceshards} Frost damage.",
			{"key": "frost_splinter", "values": [0.1], "requires": "iceshards"}],
		"r6c4": ["Shardstorm", 2, "Every {b:SHARDSTORM_EVERY} Ice Shards you fire grant you {v}% Haste for {b:SHARDSTORM_TIME} sec.",
			{"key": "frost_shardstorm", "values": [7.0, 10.5], "requires": "iceshards"}],
		"r4c7": ["Hardened Frost", 4, "Your absorb shields increase the armor of whoever they protect (you or an ally) by {v}% for their duration.",
			{"key": "frost_shield_armor", "values": [2.0, 4.0, 6.0, 8.0]}],
		"r9c2": ["Chilling Presence", 3, "You generate {v}% more threat against enemies you slowed in the last {b:SLOW_MEMORY} sec.",
			{"key": "frost_slow_threat", "values": [5.0, 10.0, 15.0]}],
		"r9c6": ["Numbing Cold", 3, "You take {v}% less damage from enemies you slowed in the last {b:SLOW_MEMORY} sec.",
			{"key": "frost_slow_dr", "values": [2.0, 4.0, 6.0]}],
		"r8c7": ["Ice Floe", 2, "When an absorb shield you put on yourself breaks, you gain {v}% move speed for {b:ICE_FLOE_TIME} sec and the enemy that broke it is Chilled.",
			{"key": "frost_ice_floe", "values": [10.0, 20.0]}],
		"r9c4": ["Shatterpoint", 3, "Your shatters (Rime Shell breaking, {n:shatteringwave}, {n:shatteringslam}) deal {v}% more damage.",
			{"key": "frost_shatterpoint", "values": [10.0, 20.0, 30.0],
			"capstone": "Every shatter also gives you an Ice Shard charge.",
			"capstone_requires": "iceshards"}],
		"r7c6": ["Frozen Instinct", 2, "When you Freeze an enemy, you have a {v}% chance to make your next {n:frostbolt} within {b:FROZEN_INSTINCT_TIME} sec instant and free.",
			{"key": "frost_instinct", "values": [25.0, 50.0], "requires": "frostbolt"}],
		"r10c3": ["Glacial Heart", 3, "Slows on you are {v}% weaker.",
			{"key": "frost_glacial_heart", "values": [5.0, 10.0, 15.0],
			"capstone": "You gain {b:GLACIAL_HEART_HASTE}% Haste for every slow you have on an enemy, per target and per slow (Chilled and Frozen count separately)."}],
		# The Frost bow: its talents sit together on the right of rows 1-5 (columns 5-6)
		# (player.gd, "Frost, the bow"). Cold Draw is generic; the others each work
		# with one arrow ability.
		"r1c5": ["Cold Draw", 3, "Your arrow abilities that hit a target you have already Chilled or Frozen give you {v} Energy.",
			{"key": "frost_cold_draw", "values": [2.0, 4.0, 6.0]}],
		"r2c6": ["Black Ice", 2, "The first Chill the ice of your {n:icyretreat} puts on each enemy has a {v}% chance to be a Freeze instead.",
			{"key": "frost_black_ice", "values": [50.0, 100.0], "requires": "icyretreat"}],
		"r3c6": ["Clean Shatter", 2, "When {n:shattershot} breaks your Freeze, it refunds {v} Energy and takes {v2} sec off its own cooldown.",
			{"key": "frost_clean_shatter", "values": [10.0, 20.0], "values2": [2.0, 4.0], "requires": "shattershot"}],
		"r4c5": ["Cold Harvest", 2, "Each shot of your {n:rimefletch} that Freezes its target gives you {v} Energy.",
			{"key": "frost_cold_harvest", "values": [5.0, 10.0], "requires": "rimefletch"}],
		"r5c5": ["Thin Ice", 2, "{n:glacialdraw} casts {v} sec faster on a target you have Chilled.",
			{"key": "frost_thin_ice", "values": [0.5, 1.0], "requires": "glacialdraw"}],
		"r5c6": ["Marked Prey", 2, "Your {n:iceshards} deal {v}% more damage to the target carrying your {n:coldmark}.",
			{"key": "frost_marked_prey", "values": [15.0, 30.0], "requires": "coldmark"}],
		# (Pinning Frost and Third Bite moved off the middle of rows 2 and 5 when those
		# rows were widened; rows 8 and 10 still have their middle talent.)
		"r2c5": ["Pinning Frost", 2, "{n:frostarrow} deals {v}% more damage to a target rooted by your {n:icepin}.",
			{"key": "frost_pinning_frost", "values": [20.0, 40.0], "requires": "icepin"}],
		"r5c3": ["Third Bite", 2, "The {n:froststrike} that Freezes its target deals {v}% more damage.",
			{"key": "frost_third_bite", "values": [40.0, 80.0], "requires": "froststrike"}],
		"r8c4": ["Thick Hide", 2, "Reduces the cooldown of {n:winterhide} by {v} sec.",
			{"key": "frost_thick_hide", "values": [10.0, 20.0], "requires": "winterhide"}],
		"r10c4": ["Hard Freeze", 3, "Your Frozen lasts {v} sec longer.",
			{"key": "frost_hard_freeze", "values": [0.5, 1.0, 1.5]}],
		"r10c5": ["Deep Freeze", 5, "Your Frost spells and abilities have a {v}% chance to Freeze the target.",
			{"key": "frost_deep_freeze", "values": [1.0, 2.0, 3.0, 4.0, 5.0],
			"capstone": "Every {bth:DEEP_FREEZE_BLIZZARD_EVERY} Ice Shard you fire also casts a {n:blizzard} at its target at {b%:DEEP_FREEZE_BLIZZARD_MULT}% effectiveness.",
			"capstone_requires": "blizzard"}],
	},
	"lightning": {
		# Open talents: themed to the book (jumping on, tempo, standing your ground)
		# but they work with every book's spells and abilities (player.gd, "Fire and
		# Lightning: the open talents"). They took new slots in the middle of rows 1,
		# 3 and 4. Change of Pace: Player._change_of_pace; Spillover:
		# Player._spillover_talent; Dig In: Player._tick_dig_in.
		"r1c4": ["Change of Pace", 3, "Using a different spell or ability than the last one you used increases your damage by {v}% for {b:CHANGE_OF_PACE_TIME} sec, stacking up to {b:CHANGE_OF_PACE_STACKS} times. Using the same one twice in a row ends it.",
			{"key": "lightning_change_of_pace", "values": [1.0, 2.0, 3.0]}],
		"r3c4": ["Spillover", 3, "When one of your direct hits critically strikes, {v}% of its damage jumps to another enemy within {b:SPILLOVER_RADIUS} m.",
			{"key": "lightning_spillover", "values": [5.0, 10.0, 15.0]}],
		"r4c4": ["Dig In", 3, "After you stand still for {b:DIG_IN_TIME} sec, you deal {v}% more damage until you move.",
			{"key": "lightning_dig_in", "values": [2.0, 4.0, 6.0]}],
		# Generic Lightning talents (no ability needed) in rows 1 and 2. Quick Charge is
		# in Player._tick_resources, Deep Reserves in Player.resource_max, Conductive in
		# Player.adjust_crit, Running on Empty in Player._on_damage_modify.
		"r1c2": ["Quick Charge", 3, "Your Energy regenerates {v}% faster.",
			{"key": "lightning_quick_charge", "values": [5.0, 10.0, 15.0]}],
		"r1c6": ["Conductive", 3, "Increases the critical strike chance of your Lightning damage by {v}%.",
			{"key": "lightning_conductive", "values": [1.0, 2.0, 3.0]}],
		"r2c3": ["Deep Reserves", 2, "Increases your maximum Energy by {v}.",
			{"key": "lightning_deep_reserves", "values": [10.0, 20.0]}],
		"r2c5": ["Running on Empty", 3, "While you have less than {b:RUNNING_ON_EMPTY_ENERGY} Energy, your Lightning spells and abilities deal {v}% more damage.",
			{"key": "lightning_running_on_empty", "values": [3.0, 6.0, 9.0]}],
		# The Lightning melee talents sit down the left side of the book (player.gd,
		# "Lightning melee").
		"r3c1": ["Honed Edge", 2, "{n:chargededge} gives {v} more Energy.",
			{"key": "lightning_honed_edge", "values": [5.0, 10.0], "requires": "chargededge"}],
		"r4c3": ["Running Start", 2, "{n:staticstep} gives you {v} Energy when it carries you at least {b:RUNNING_START_DISTANCE} m.",
			{"key": "lightning_running_start", "values": [10.0, 20.0], "requires": "staticstep"}],
		"r5c2": ["Third Beat", 3, "The third strike of {n:cadence} deals {v}% more damage.",
			{"key": "lightning_third_beat", "values": [10.0, 20.0, 30.0], "requires": "cadence",
			"capstone": "The third strike also gives you {b:THIRD_BEAT_ENERGY} Energy."}],
		"r6c1": ["Redline", 2, "Every ability that spends Energy while {n:overdrive} is active makes it last {v} sec longer, up to {b:REDLINE_MAX} sec more in total.",
			{"key": "lightning_redline", "values": [0.5, 1.0], "requires": "overdrive"}],
		# More generic ones, filling out rows 1-3. Live Current and Quick Step are plain
		# stats; Storm-Tempered is worked out in PlayerData._compute_total_stats;
		# Charged Strikes in Player._on_auto_landed; Calm Current in Player._on_damage_modify.
		"r1c3": ["Live Current", 3, "Increases your Haste by {v}%.",
			{"key": "lightning_live_current", "values": [1.0, 2.0, 3.0], "stats": {"haste": 1.0}}],
		"r1c5": ["Charged Strikes", 3, "Your auto-attacks give you {v} Energy.",
			{"key": "lightning_charged_strikes", "values": [1.0, 2.0, 3.0]}],
		"r2c1": ["Storm-Tempered", 3, "Increases your Attack Power by {v}% of your Agility.",
			{"key": "lightning_storm_tempered", "values": [2.0, 4.0, 6.0]}],
		"r2c7": ["Quick Step", 3, "Increases your Dodge chance by {v}%.",
			{"key": "lightning_quick_step", "values": [1.0, 2.0, 3.0], "stats": {"dodge": 1.0}}],
		"r3c3": ["Calm Current", 3, "Your Lightning spells and abilities generate {v}% less threat.",
			{"key": "lightning_calm_current", "values": [5.0, 10.0, 15.0]}],
		# More ability talents. Overflow: Player._capacitor; Parting Spark:
		# Player._flicker; Second Stroke: Player._use_drafted; Hot Wire: Player._on_auto_landed.
		"r8c3": ["Overflow", 2, "When you take your Energy back from {n:capacitor}, the Energy that doesn't fit in your bar becomes a shield on you for {b:OVERFLOW_TIME} sec, absorbing {vdmg:capacitor} damage per {b:ENERGY_STEP} Energy.",
			{"key": "lightning_overflow", "values": [0.1, 0.2], "requires": "capacitor"}],
		"r8c6": ["Parting Spark", 2, "{n:flicker} zaps every enemy within {b:PARTING_SPARK_RADIUS} m of the spot you left for {vdmg:flicker} Lightning damage.",
			{"key": "lightning_parting_spark", "values": [0.4, 0.8], "requires": "flicker"}],
		"r6c7": ["Second Stroke", 2, "{n:returnstroke} has a {v}% chance not to close its window, so you can answer the same parry twice.",
			{"key": "lightning_second_stroke", "values": [15.0, 30.0], "requires": "returnstroke"}],
		"r9c2": ["Hot Wire", 2, "Each echo of {n:twincurrent} has a {v}% chance not to use up a charge.",
			{"key": "lightning_hot_wire", "values": [25.0, 50.0], "requires": "twincurrent"}],
		# The Lightning bow: three talents for Storm Arrow (player.gd, "Storm Arrow
		# talents"). Each ties the arrow to a spell: Flicker, Lightning Bolt, Capacitor.
		"r9c4": ["Snap Shot", 2, "{n:flicker} resets the cooldown of {n:stormarrow} and makes your next {n:stormarrow} within {b:SNAP_SHOT_TIME} sec cost {v} less Energy.",
			{"key": "lightning_snap_shot", "values": [15.0, 30.0], "requires": "stormarrow"}],
		"r7c4": ["Lightning Rod", 2, "{n:stormarrow} stays stuck in its target for {e:lightning_rod.time} sec. Your {n:lightningbolt} hitting that target also arcs to every enemy within {b:LIGHTNING_ROD_RADIUS} m of it for {v}% of the damage it dealt.",
			{"key": "lightning_rod", "values": [20.0, 40.0], "requires": "stormarrow"}],
		"r9c6": ["Loaded Quiver", 2, "Taking your Energy back from {n:capacitor} loads {v} {n:stormarrow} for {b:LOADED_QUIVER_TIME} sec: each costs no Energy and ignores its cooldown.",
			{"key": "lightning_loaded_quiver", "values": [1.0, 2.0], "requires": "stormarrow"}],
		# Long Reach is generic (PlayerData._compute_total_stats). The Lightning tank
		# talents sit down the right side of the book (player.gd, "Lightning tank").
		# (Moved down from the middle of row 2 to make room: see MOVED.)
		"r3c5": ["Long Reach", 3, "Increases your Parry chance by {v}% while you wield a two-handed weapon.",
			{"key": "lightning_long_reach", "values": [1.0, 2.0, 3.0]}],
		"r3c7": ["Counter-Charge", 3, "{n:returnstroke} deals {v}% more damage.",
			{"key": "lightning_counter_charge", "values": [10.0, 20.0, 30.0], "requires": "returnstroke",
			"capstone": "It also arcs to up to {b:COUNTER_CHARGE_JUMPS} nearby enemies, dealing {bdmg:COUNTER_CHARGE_ARC} Lightning damage to each."}],
		"r4c5": ["Closed Circuit", 2, "Attacks you parry while {n:thunderaegis} is active give you {v} more Energy.",
			{"key": "lightning_closed_circuit", "values": [3.0, 6.0], "requires": "thunderaegis"}],
		"r5c6": ["Quick Wrists", 2, "Each attack you parry takes {v} sec off the cooldown of {n:crossguard}.",
			{"key": "lightning_quick_wrists", "values": [0.5, 1.0], "requires": "crossguard"}],
		# Caster talents sit down the middle of the book. Quick Fuse: Abilities.base_cast_time
		# and Player._begin_spell; Tight Coil: Player.ball_lightning_zapped.
		"r6c4": ["Quick Fuse", 2, "{n:lightningbolt} casts {v} sec faster.",
			{"key": "lightning_quick_fuse", "values": [0.1, 0.2], "requires": "lightningbolt"}],
		"r5c4": ["Tight Coil", 2, "Each zap of your {n:balllightning} gives you {v} more Energy.",
			{"key": "lightning_tight_coil", "values": [1.0, 2.0], "requires": "balllightning"}],
		# Generic (any parry): Player._parry_kit_hit_taken.
		"r7c5": ["Earth Return", 2, "Each attack you parry heals you for {v}% of your maximum health.",
			{"key": "lightning_earth_return", "values": [0.5, 1.0]}],
		# Player._tick_standing_charge / _on_damage_modify.
		"r7c3": ["Standing Charge", 3, "Each second you stay planted in {n:groundingsurge} increases your Lightning damage by {v}%, stacking up to {b:STANDING_CHARGE_MAX_STACKS} times. The stacks are lost when it ends.",
			{"key": "lightning_standing_charge", "values": [2.0, 4.0, 6.0], "requires": "groundingsurge"}],
		# Player._whiplash / resource_cost.
		"r8c2": ["Whip Crack", 2, "Hitting a target more than {b:WHIP_CRACK_DISTANCE} m away with {n:whiplash} resets the cooldown of {n:staticstep} and makes your next {n:staticstep} within {b:WHIP_CRACK_TIME} sec cost {v} less Energy.",
			{"key": "lightning_whip_crack", "values": [10.0, 20.0], "requires": "whiplash"}],
		# Player._pay / _storm_cycle_spent.
		"r10c4": ["Storm Cycle", 5, "Every {v} Energy you spend makes your next Energy cost free (kept for up to {b:STORM_CYCLE_TIME} sec). Abilities that spend all your Energy are counted, but are never the free one.",
			{"key": "lightning_storm_cycle", "values": [200.0, 180.0, 160.0, 140.0, 120.0]}],
		# The bottom row: for any Lightning build (Player._conductor, Player._on_damage_modify).
		"r10c3": ["Conductor", 5, "Your critical strikes with Lightning spells and abilities give you {v} Energy. Their arcs, zaps and periodic damage do not count, and one that hits several enemies counts once.",
			{"key": "lightning_conductor", "values": [2.0, 4.0, 6.0, 8.0, 10.0]}],
		"r10c5": ["High Voltage", 5, "While you have more than {b:HIGH_VOLTAGE_ENERGY} Energy, your Lightning damage is increased by {v}%.",
			{"key": "lightning_high_voltage", "values": [2.0, 4.0, 6.0, 8.0, 10.0]}],
		# Generic (any parry): Player._parry_kit_hit_taken, Player.auto_interval.
		"r8c5": ["Tempo", 3, "Each attack you parry increases your attack speed by {v}% for {b:TEMPO_TIME} sec, stacking up to {b:TEMPO_MAX_STACKS} times.",
			{"key": "lightning_tempo", "values": [2.0, 4.0, 6.0]}],
	},
	"arcane": {
		# The Arcane caster (player.gd, "Arcane caster: the cooldown kit"). Sigil
		# Darts' two on the left, Countdown's on the right, Collapse's two down the
		# right of the middle; the rest of the book is still empty.
		"r1c3": ["Seventh Sigil", 2, "{n:arcanemissiles} fires {v} more darts over the same channel.",
			{"key": "arcane_seventh_sigil", "values": [1.0, 2.0], "requires": "arcanemissiles"}],
		# Generic: every blink (Phase Step and Flicker), whatever its book.
		"r1c4": ["Long Step", 2, "{n:blink} and {n:flicker} take you {v} m further.",
			{"key": "arcane_long_step", "values": [1.0, 2.0]}],
		"r1c5": ["Frayed", 2, "When {n:unravel} critically strikes, it has a {v}% chance to take its time off the cooldowns of your other Arcane spells a second time.",
			{"key": "arcane_frayed", "values": [50.0, 100.0], "requires": "unravel"}],
		"r2c2": ["Etched Darts", 3, "Each dart of {n:arcanemissiles} that critically strikes has a {v}% chance to take {b:ETCHED_DARTS_SECONDS} sec off the cooldowns of {n:countdown} and {n:collapse}.",
			{"key": "arcane_etched_darts", "values": [10.0, 20.0, 30.0], "requires": "arcanemissiles"}],
		"r2c6": ["Chain Reaction", 3, "When {n:countdown} detonates, every other enemy within {b:CHAIN_REACTION_RADIUS} m of its target takes {v}% of the extra damage it counted. Full damage to up to {b:AOE_TARGET_CAP} enemies; with more, that damage is split evenly between all of them.",
			{"key": "arcane_chain_reaction", "values": [10.0, 20.0, 30.0], "requires": "countdown"}],
		"r3c3": ["Polished Glass", 3, "{n:mirrorsigil} repeats your Arcane spells at {v+b:MIRROR_SIGIL_PCT}% of their damage.",
			{"key": "arcane_polished_glass", "values": [3.0, 6.0, 10.0], "requires": "mirrorsigil"}],
		"r3c5": ["Deep Well", 2, "{n:collapse} pulls enemies up to {v+b:COLLAPSE_PULL} m toward its centre.",
			{"key": "arcane_deep_well", "values": [1.0, 2.0], "requires": "collapse"}],
		"r4c4": ["Aftershock", 2, "Enemies pulled by {n:collapse} are slowed by {v}% for {b:AFTERSHOCK_TIME} sec.",
			{"key": "arcane_aftershock", "values": [20.0, 40.0], "requires": "collapse"}],
		# The Arcane tank (player.gd, "Arcane tank" and "Arcane tank talents"), down
		# both edges of the book. Left: what makes and shatters Reflections.
		# Sharp Edges: Player._on_damage_modify, shatter_radius; Clockwork:
		# _shatter_cooldowns; Spare Copy: _reflection_kit_hit_taken; Second Self and
		# On the Beat: _use_drafted; Wide Rings: Abilities.RADIUS_TALENTS, _ripple;
		# Head Count: _full_set.
		"r2c1": ["Sharp Edges", 3, "Your Reflections deal {v}% more damage when they shatter.",
			{"key": "arcane_sharp_edges", "values": [10.0, 20.0, 30.0],
			"capstone": "A shatter reaches enemies within {b:SHARP_EDGES_RADIUS} m of you instead of {b:REFLECTION_SHATTER_RADIUS} m."}],
		"r3c1": ["Clockwork", 2, "Each of your Reflections that shatters takes {v} sec more off the cooldowns of your Arcane spells and abilities.",
			{"key": "arcane_clockwork", "values": [0.25, 0.5]}],
		"r4c1": ["Spare Copy", 2, "When you dodge an attack, there is a {v}% chance that the Reflection which takes it is not used up. It still shatters.",
			{"key": "arcane_spare_copy", "values": [10.0, 20.0]}],
		"r5c2": ["Second Self", 2, "{n:doubleup} has a {v}% chance to create {b:SECOND_SELF_REFLECTIONS} Reflections.",
			{"key": "arcane_second_self", "values": [15.0, 30.0], "requires": "doubleup"}],
		"r7c1": ["Wide Rings", 2, "{n:ripple} reaches {v} m further.",
			{"key": "arcane_wide_rings", "values": [1.0, 2.0], "requires": "ripple",
			"capstone": "It creates a Reflection when it hits {b:WIDE_RINGS_ENEMIES} or more enemies."}],
		"r8c2": ["On the Beat", 3, "{n:missedbeat} deals {v}% more damage.",
			{"key": "arcane_on_the_beat", "values": [10.0, 20.0, 30.0], "requires": "missedbeat",
			"capstone": "Used while you have no Reflections, it creates one."}],
		"r9c1": ["Head Count", 2, "{n:fullset} heals you for {v}% of your maximum health for each Reflection it creates.",
			{"key": "arcane_head_count", "values": [2.0, 4.0], "requires": "fullset"}],
		# Right: staying alive. Light Feet is generic (PlayerData._compute_total_stats);
		# Empty Room and Bent Light: Player._on_damage_modify; Understudy:
		# _reflection_kit_hit_taken; Loud Exit: _trade_places; Good Likeness: _start_decoy.
		"r2c7": ["Light Feet", 3, "Increases your Dodge chance by {v}% while you wield a melee weapon in each hand.",
			{"key": "arcane_light_feet", "values": [1.0, 2.0, 3.0]}],
		"r3c7": ["Empty Room", 3, "While you wield a melee weapon in each hand and have no Reflections, you take {v}% less damage.",
			{"key": "arcane_empty_room", "values": [4.0, 8.0, 12.0]}],
		"r4c7": ["Bent Light", 2, "You take {v}% less non-Physical damage for each Reflection you have.",
			{"key": "arcane_bent_light", "values": [1.0, 2.0]}],
		"r5c6": ["Understudy", 2, "Each Reflection destroyed by {n:standin} takes {v} sec off its cooldown.",
			{"key": "arcane_understudy", "values": [2.0, 4.0], "requires": "standin"}],
		"r7c7": ["Loud Exit", 1, "The Reflections you give up with {n:tradeplaces} shatter.",
			{"key": "arcane_loud_exit", "values": [1.0], "requires": "tradeplaces"}],
		"r8c6": ["Good Likeness", 2, "{n:decoy} holds enemies for {v} sec longer.",
			{"key": "arcane_good_likeness", "values": [1.0, 2.0], "requires": "decoy",
			"capstone": "{n:decoy} no longer needs or uses up a Reflection."}],
		# Arcane melee (player.gd, "Arcane melee"), in the middle of rows 6-7: Traces
		# and Encore. Long Memory: Player.trace_time; Standing Ovation: encore_pct,
		# trace_cap; Clean Lines: _trace_hit; Second Showing: _encore.
		"r6c5": ["Standing Ovation", 3, "{n:encore} replays each Trace for {v+b:ENCORE_PCT}% of the damage it recorded.",
			{"key": "arcane_standing_ovation", "values": [5.0, 10.0, 15.0], "requires": "encore",
			"capstone": "You can hold {b:STANDING_OVATION_TRACES} more Trace."}],
		"r6c3": ["Long Memory", 2, "Your Traces last {v} sec longer.",
			{"key": "arcane_long_memory", "values": [2.0, 4.0], "requires": "encore"}],
		"r6c4": ["Clean Lines", 2, "When {n:swiftcut} critically strikes, it takes {v} sec off the cooldown of {n:deepcut}.",
			{"key": "arcane_clean_lines", "values": [0.5, 1.0], "requires": "deepcut"}],
		"r7c5": ["Second Showing", 2, "{n:encore} has a {v}% chance not to use up your Traces.",
			{"key": "arcane_second_showing", "values": [10.0, 20.0], "requires": "encore"}],
		# More melee talents, down columns 3 and 5 of rows 5-9. Practiced Hand:
		# Player._on_damage_modify; Heavy Hand: trace_amount; Curtain Call, Time
		# Signature: _encore; No Loose Ends: _late_cut; Full House: _wide_cut; Dress
		# Rehearsal: _start_double_time.
		"r5c3": ["Practiced Hand", 3, "{n:swiftcut} deals {v}% more damage for each Trace you hold.",
			{"key": "arcane_practiced_hand", "values": [3.0, 6.0, 9.0], "requires": "swiftcut"}],
		"r5c5": ["Heavy Hand", 2, "The Trace {n:deepcut} leaves records {v}% more damage than the strike dealt.",
			{"key": "arcane_heavy_hand", "values": [10.0, 20.0], "requires": "deepcut"}],
		"r7c3": ["Curtain Call", 2, "When {n:encore} replays {b:CURTAIN_CALL_TRACES} or more Traces, each replay deals {v}% more damage.",
			{"key": "arcane_curtain_call", "values": [10.0, 20.0], "requires": "encore"}],
		"r8c3": ["No Loose Ends", 2, "The second hit of {n:latecut} lands {v} sec sooner.",
			{"key": "arcane_no_loose_ends", "values": [0.5, 1.0], "requires": "latecut",
			"capstone": "If the Trace of the first hit is gone when the second hit lands, the second hit leaves a Trace of its own."}],
		"r8c5": ["Time Signature", 2, "Each Trace {n:encore} replays takes {v} sec off the cooldowns of your other Arcane spells and abilities. Interrupts are not affected.",
			{"key": "arcane_time_signature", "values": [0.25, 0.5], "requires": "encore"}],
		# (Encore has no cooldown any more: Curtain Call, Full House and Dress
		# Rehearsal's capstone, which used to shorten or reset it, were given new effects.)
		"r9c3": ["Full House", 2, "When {n:widecut} hits {b:FULL_HOUSE_ENEMIES} or more enemies, your next {n:encore} within {b:FULL_HOUSE_TIME} sec also replays each Trace on up to {v} other enemies within {b:FULL_HOUSE_RADIUS} m of its target, for {b:FULL_HOUSE_PCT}% of its damage.",
			{"key": "arcane_full_house", "values": [1.0, 2.0], "requires": "widecut"}],
		"r9c5": ["Dress Rehearsal", 2, "{n:doubletime} lasts {v} sec longer.",
			{"key": "arcane_dress_rehearsal", "values": [2.0, 4.0], "requires": "doubletime",
			"capstone": "The first {n:encore} during {n:doubletime} does not use up your Traces.", "capstone_requires": "encore"}],
		# The bottom row: one for the tank (Player._shatter_burst), one for any Arcane
		# build (Player._tick_cooldowns), one for melee (Player._on_damage_modify).
		"r10c2": ["Silvered", 5, "Each of your Reflections that shatters heals you for {v}% of your maximum health.",
			{"key": "arcane_silvered", "values": [0.3, 0.6, 0.9, 1.2, 1.5]}],
		"r10c4": ["Running Clock", 5, "The cooldowns of your Arcane spells and abilities recover {v}% faster. Interrupts are not affected.",
			{"key": "arcane_running_clock", "values": [2.0, 4.0, 6.0, 8.0, 10.0]}],
		"r10c6": ["Fine Edge", 5, "Your Arcane abilities deal {v}% more damage while you wield a melee weapon in each hand.",
			{"key": "arcane_fine_edge", "values": [2.0, 4.0, 6.0, 8.0, 10.0]}],
		# Open talents: themed to the book (time, copies, mirrors) but they work with
		# every book's spells and abilities, so any build has a reason to come here.
		# Quick Study is a plain stat; Two Minds: PlayerData._compute_total_stats; the
		# rest: player.gd, "Arcane: the open talents".
		"r1c1": ["Quick Study", 3, "Increases your Haste by {v}%.",
			{"key": "arcane_quick_study", "values": [1.0, 2.0, 3.0], "stats": {"haste": 1.0}}],
		"r1c7": ["Two Minds", 3, "The lower of your Spell Power and Attack Power is increased by {v}% of the higher.",
			{"key": "arcane_two_minds", "values": [4.0, 8.0, 12.0]}],
		"r2c4": ["Echo", 3, "Your spells and abilities have a {v}% chance to be repeated for {b:ECHO_PCT}% of the damage they dealt. For an Arcane spell or ability the chance is {b:ECHO_ARCANE_CHANCE_MULT} times as high, and the repeat deals {b:ECHO_ARCANE_PCT}% of the damage.",
			{"key": "arcane_echo", "values": [2.0, 4.0, 6.0]}],
		"r4c2": ["Mirror Finish", 3, "When you dodge, parry or block an attack, the attacker takes {vdmg:ripple} Arcane damage.",
			{"key": "arcane_mirror_finish", "values": [0.1, 0.2, 0.3]}],
		"r4c6": ["Overtime", 3, "Buffs you put on yourself last {v}% longer.",
			{"key": "arcane_overtime", "values": [5.0, 10.0, 15.0]}],
		"r5c4": ["Light Touch", 3, "Your Arcane spells and abilities generate {v}% less threat.",
			{"key": "arcane_light_touch", "values": [5.0, 10.0, 15.0]}],
		"r6c2": ["Slipstream", 2, "After {n:blink}, {n:flicker}, {n:staticstep}, {n:cinderstep} or {n:icyretreat}, you move {v}% faster for {b:SLIPSTREAM_TIME} sec.",
			{"key": "arcane_slipstream", "values": [10.0, 20.0]}],
		"r10c3": ["Borrowed Time", 5, "When one of your spells or abilities with a cooldown of {b:BORROWED_TIME_COOLDOWN} sec or more comes off cooldown, your next spell or ability within {b:BORROWED_TIME_TIME} sec deals {v}% more damage.",
			{"key": "arcane_borrowed_time", "values": [3.0, 6.0, 9.0, 12.0, 15.0]}],
		# Two more for one ability each: Glint (Player._glint) and Crowd of One
		# (Player._start_crowd_of_one).
		"r6c6": ["Keep Moving", 2, "The window {n:glint} opens lasts {v} sec longer.",
			{"key": "arcane_keep_moving", "values": [2.0, 4.0], "requires": "glint",
			"capstone": "It covers {b:KEEP_MOVING_CASTS} casts on the move instead of one."}],
		"r9c7": ["Full Crowd", 2, "{n:crowdofone} creates {v} Reflections when you use it.",
			{"key": "arcane_full_crowd", "values": [1.0, 2.0], "requires": "crowdofone"}],
	},
	"shadow": {
		# Open talents: themed to the book (damage over time, a slow end, paying for
		# it) but they work with every book's spells and abilities. They fill rows
		# 1 and 2, and one sits in the bottom row (player.gd, "Shadow: the open
		# talents"). Slow Death and Wasting also count for the Breach.
		# (The Breach - the hole under an enemy that demons claw through - is
		# "decay" in the code, its first name. So are the talent keys below: Lure is
		# shadow_seep, Wider Still
		# shadow_running_over, Hooked Claws shadow_rot_through, Baited Steel
		# shadow_tainted_steel. The spells: see player.gd, "Shadow caster: Decay".)
		"r1c2": ["Slow Death", 3, "Your damage over time effects deal {v}% more damage.",
			{"key": "shadow_slow_death", "values": [2.0, 4.0, 6.0]}],
		"r1c4": ["Wasting", 3, "Your damage over time effects deal their damage {v}% more often.",
			{"key": "shadow_wasting", "values": [2.0, 4.0, 6.0]}],
		"r1c6": ["Finish It", 3, "You deal {v}% more damage to enemies below {b:FINISH_IT_HEALTH_PCT}% health.",
			{"key": "shadow_finish_it", "values": [3.0, 6.0, 9.0]}],
		"r2c3": ["Spite", 3, "After you take damage, your next spell or ability within {b:SPITE_TIME} sec deals {v}% more damage.",
			{"key": "shadow_spite", "values": [3.0, 6.0, 9.0]}],
		"r2c5": ["Carrion", 2, "When an enemy that carries one of your damage over time effects dies, you regain {v}% of your maximum mana.",
			{"key": "shadow_carrion", "values": [1.0, 2.0]}],
		"r10c5": ["Inevitable", 5, "Enemies you first damaged more than {b:INEVITABLE_TIME} sec ago take {v}% more damage from you.",
			{"key": "shadow_inevitable", "values": [2.0, 4.0, 6.0, 8.0, 10.0]}],
		# The Shadow caster's Decay (player.gd, "Shadow caster: Decay"), down the
		# middle of rows 4-8, with one talent in the bottom row. Seep, Loose Grains:
		# Player._on_damage_dealt_shadow; Interest, Small Change: _call_due; Next of
		# Kin: _decay_jump; Bitter End, Rot Through: _tick_decay; No Floor:
		# _start_bottomless.
		"r4c3": ["Lure", 2, "The periodic damage of {n:corruption} adds {v}% of what it deals to your Breach under the target while it is open.",
			{"key": "shadow_seep", "values": [25.0, 50.0], "requires": "corruption"}],
		"r4c4": ["Interest", 3, "{n:calldue} deals {v+b:CALL_DUE_BONUS_PCT}% more than what it takes out of your Breach, instead of {b:CALL_DUE_BONUS_PCT}%.",
			{"key": "shadow_interest", "values": [5.0, 10.0, 15.0], "requires": "calldue",
			"capstone": "If that Breach was still open, your next {n:blight} within {b:INTEREST_TIME} sec is instant.", "capstone_requires": "blight"}],
		# (r4c5 is empty: Impatience went with Usher In, the spell it was about.)
		# Hush, Spill and Gnaw: one talent each, either side of the middle.
		# Cut Short: Player._hush; Running Over: _spill; Bite Down: _tick_decay, adjust_crit.
		"r5c2": ["Cut Short", 2, "When {n:hush} interrupts a cast, {v} sec is taken off its cooldown. It never goes under the {b:INTERRUPT_SHARED_COOLDOWN} sec all interrupts share.",
			{"key": "shadow_cut_short", "values": [2.0, 4.0], "requires": "hush"}],
		"r5c6": ["Wider Still", 2, "{n:spill} copies {v+b:SPILL_PCT}% of what is left in your Breach, instead of {b:SPILL_PCT}%.",
			{"key": "shadow_running_over", "values": [10.0, 20.0], "requires": "spill",
			"capstone": "Every copy is open for at least {b:RUNNING_OVER_OPEN_TIME} sec."}],
		"r7c5": ["Bite Down", 2, "While {n:gnaw} makes your Breach under a target deal its damage more often, its ticks have {v}% more chance to critically strike.",
			{"key": "shadow_bite_down", "values": [10.0, 20.0], "requires": "gnaw"}],
		"r6c3": ["Next of Kin", 3, "When an enemy standing on your Breach dies, {v}% more than what was left in it moves under the nearest enemy.",
			{"key": "shadow_next_of_kin", "values": [10.0, 20.0, 30.0], "requires": "blight",
			"capstone": "The next nearest enemy gets {b:NEXT_OF_KIN_SECOND_PCT}% of it as well."}],
		"r6c5": ["Bitter End", 2, "The last tick of your Breach, the one that deals all that is left in it, deals {v}% more damage.",
			{"key": "shadow_bitter_end", "values": [50.0, 100.0], "requires": "blight"}],
		"r7c3": ["No Floor", 2, "{n:bottomless} lasts {v} sec longer.",
			{"key": "shadow_no_floor", "values": [2.0, 4.0], "requires": "bottomless",
			"capstone": "Your Breach cannot close while it lasts."}],
		"r5c4": ["Small Change", 2, "{n:calldue} leaves {v}% of what it takes out in your Breach instead of ending it.",
			{"key": "shadow_small_change", "values": [10.0, 20.0], "requires": "calldue"}],
		"r10c3": ["Hooked Claws", 5, "The ticks of your Breach deal {v}% more damage. It does not shrink any faster for it.",
			{"key": "shadow_rot_through", "values": [2.0, 4.0, 6.0, 8.0, 10.0], "requires": "blight"}],
		# For a Shadow melee or bow build that only dips into Decay: its abilities
		# add to an open Decay too. On the left edge of row 3.
		# Player.decay_feed_pct, _on_damage_dealt_shadow.
		# (Its twin for the other books' spells is the Rune of Invitation, rune id "rot".)
		"r3c1": ["Baited Steel", 3, "Your Shadow abilities add {v}% of the direct damage they deal to your Breach under the target while it is open.",
			{"key": "shadow_tainted_steel", "values": [10.0, 20.0, 30.0], "requires": "blight"}],
		# Two more open talents, on the edges of row 2: Rage for every build that
		# runs on it, and Haste when what you damaged dies.
		# Thick Blood: Player._tick_resources; Feeding Frenzy: _on_enemy_died_shadow.
		"r2c1": ["Thick Blood", 3, "Your Rage decays {v}% slower.",
			{"key": "shadow_thick_blood", "values": [15.0, 30.0, 45.0]}],
		"r2c7": ["Feeding Frenzy", 3, "When an enemy you damaged dies, you gain {v}% Haste for {b:FEEDING_FRENZY_TIME} sec.",
			{"key": "shadow_feeding_frenzy", "values": [2.0, 4.0, 6.0]}],
		# Shadow melee: the Hounds (player.gd, "Shadow melee: the Hounds", has the
		# list of where each one is in the code). Down the left edge, what the
		# Hounds themselves do, whichever ability called them (so no "requires";
		# Out of the Hole needs the spell that opens a Breach). Lean and Hungry, Fed
		# and Worked Up are linked, and so are Long Night and Take It With You.
		"r4c1": ["Lean and Hungry", 3, "Your Hounds bite {v}% faster.",
			{"key": "shadow_lean_and_hungry", "values": [4.0, 8.0, 12.0]}],
		"r5c1": ["Fed", 2, "A bite of your Hounds that critically strikes gives you {v} Rage.",
			{"key": "shadow_fed", "values": [2.0, 4.0]}],
		"r6c1": ["Worked Up", 2, "Roused lasts {v} sec longer.",
			{"key": "shadow_worked_up", "values": [2.0, 4.0],
			"capstone": "While your Hounds are Roused, their bites have {b:WORKED_UP_CRIT}% more chance to critically strike."}],
		"r7c1": ["Out of the Hole", 2, "The bites of your Hounds add {v}% of the damage they deal to your Breach under the enemy while it is open.",
			{"key": "shadow_out_of_the_hole", "values": [25.0, 50.0], "requires": "blight"}],
		"r8c2": ["Long Night", 2, "Your Hounds stay {v} sec longer.",
			{"key": "shadow_long_night", "values": [3.0, 6.0]}],
		"r9c1": ["Take It With You", 2, "Drag Down, the damage each of your Hounds deals to its prey as it goes back under the ground, is {v}% larger.",
			{"key": "shadow_take_it_with_you", "values": [25.0, 50.0],
			"capstone": "If Drag Down kills the enemy, your next pair of Hounds arrives already Roused."}],
		"r10c4": ["Pack Leader", 5, "Your Hounds deal {v}% more damage.",
			{"key": "shadow_pack_leader", "values": [3.0, 6.0, 9.0, 12.0, 15.0]}],
		# Down the right edge, one ability's talents each. Pincer and Again (both
		# Both At Once's) are linked.
		"r3c7": ["Still Wet", 2, "Laid Open lasts {v} sec longer.",
			{"key": "shadow_still_wet", "values": [2.0, 4.0], "requires": "openup",
			"capstone": "Your own direct hits also deal {b:STILL_WET_PCT}% more damage to that enemy."}],
		"r4c7": ["Share the Kill", 2, "The heal of {n:shadowstrike} is {v}% larger while your Hounds are out.",
			{"key": "shadow_share_the_kill", "values": [50.0, 100.0], "requires": "shadowstrike"}],
		"r5c7": ["Pincer", 3, "The lunges of {n:bothatonce} deal {v}% more damage.",
			{"key": "shadow_pincer", "values": [10.0, 20.0, 30.0], "requires": "bothatonce",
			"capstone": "A lunge that critically strikes gives you {b:PINCER_RAGE} Rage back."}],
		"r6c7": ["Again", 2, "{n:bothatonce} has a {v}% chance to reset its own cooldown.",
			{"key": "shadow_again", "values": [15.0, 30.0], "requires": "bothatonce"}],
		"r7c7": ["Stand Over", 2, "During {n:guarddogs}, each bite of your Hounds heals you for {v}% of your maximum health.",
			{"key": "shadow_stand_over", "values": [1.0, 2.0], "requires": "guarddogs"}],
		"r9c7": ["Slipped Leash", 2, "{n:offthechain} lasts {v} sec longer.",
			{"key": "shadow_slipped_leash", "values": [2.0, 4.0], "requires": "offthechain",
			"capstone": "A third Hound joins your pair for as long as it lasts."}],
		# Shadow healer: the Strings (player.gd, "Shadow healer: the Strings"; what
		# each talent changes is a static there: string_time_with, string_recharge,
		# cross_pct_with, full_harness_pct, first_stitch_coef, heave_mult, snaps_back,
		# slack_time, steady_heal). The Strings themselves need no one ability:
		# First Stitch, Long Thread (Spare Spool straight under it, linked), Full Harness, Taking
		# the Weight and, in the bottom row, Steady Hands.
		"r3c3": ["First Stitch", 2, "Tying a String to an ally heals it at once, for as much as {v} heals of one String.",
			{"key": "shadow_first_stitch", "values": [2.0, 4.0]}],
		"r3c5": ["Long Thread", 2, "Your Strings on allies last {v} sec longer.",
			{"key": "shadow_long_thread", "values": [2.0, 4.0]}],
		"r4c5": ["Spare Spool", 2, "Your Strings that were used up come back {v} sec sooner.",
			{"key": "shadow_spare_spool", "values": [1.0, 2.0]}],
		"r8c3": ["Full Harness", 2, "An ally that has {b:STRING_STACKS} of your Strings takes {v}% less damage.",
			{"key": "shadow_full_harness", "values": [3.0, 6.0]}],
		"r8c5": ["Taking the Weight", 2, "Crossed Strings moves {v}% of the damage the ally takes to the enemy, instead of {b:STRING_CROSS_PCT}%.",
			{"key": "shadow_taking_the_weight", "values": [5.0, 7.0],
			"capstone": "A crossing holds up to {b:TAKING_THE_WEIGHT_RANGE} m apart, instead of {b:STRING_CROSS_RANGE} m."}],
		"r10c2": ["Steady Hands", 5, "Your Strings heal {v}% more.",
			{"key": "shadow_steady_hands", "values": [3.0, 6.0, 9.0, 12.0, 15.0]}],
		# One ability's talent each. Heave: Player._string_cast_heal, _begin_spell;
		# Long Drop: _string_up, _tick_long_drops; Snap Back: _pull_taut; Give and
		# Take: _slack.
		"r3c4": ["Heave", 2, "{n:hoist} heals {v}% more for each of your Strings on its target.",
			{"key": "shadow_heave", "values": [5.0, 10.0], "requires": "hoist",
			"capstone": "On a target with {b:STRING_STACKS} of your Strings, its cast time is {b:HEAVE_CAST} sec shorter."}],
		"r8c6": ["Long Drop", 2, "When {n:stringup} ends, the enemy drops and takes {vdmg:stringup} Shadow damage.",
			{"key": "shadow_long_drop", "values": [0.5, 1.0], "requires": "stringup"}],
		"r9c3": ["Snap Back", 2, "{n:pulltaut} has a {v}% chance to put its String straight back in your hand instead of using it up.",
			{"key": "shadow_snap_back", "values": [25.0, 50.0], "requires": "pulltaut"}],
		"r9c5": ["Give and Take", 3, "{n:slack} stops your Strings healing for {v} sec less.",
			{"key": "shadow_give_and_take", "values": [1.0, 2.0, 3.0], "requires": "slack"}],
		# Three more open talents, themed to the healer (helping others, holding
		# things in place) but for every book's heals, stuns and roots. Helping Hands (key shadow_many_hands):
		# Player._others_heal_mult; Lean On Me: _lean_on_me (any heal of mine on
		# someone else); Left Hanging: Abilities.effect_time_bonus.
		"r1c1": ["Helping Hands", 3, "Your heals on allies other than yourself are {v}% larger.",
			{"key": "shadow_many_hands", "values": [2.0, 4.0, 6.0]}],
		"r1c7": ["Lean On Me", 3, "After you heal an ally other than yourself, you take {v}% less damage for {b:LEAN_ON_ME_TIME} sec.",
			{"key": "shadow_lean_on_me", "values": [2.0, 4.0, 6.0]}],
		"r2c4": ["Left Hanging", 2, "Your stuns and roots last {v}% longer.",
			{"key": "shadow_left_hanging", "values": [10.0, 20.0]}],
		# Down the middle column under Small Change, one each: the caster, an open
		# one, the healer, melee. Deep Call: Player._begin_spell, deep_call_cast;
		# Ill Will: Player.crit_hit_bonus (CombatSystem.deal asks it); Hard Pull:
		# _tug, tug_time; Wide Pack: _hound_bite, run_down_targets.
		"r6c4": ["Deep Call", 2, "While your Breach under the target is open, {n:erode} takes {v} sec less to cast.",
			{"key": "shadow_deep_call", "values": [0.25, 0.5], "requires": "erode"}],
		"r7c4": ["Ill Will", 3, "Critical strikes of your damage over time effects deal {v}% more damage.",
			{"key": "shadow_ill_will", "values": [5.0, 10.0, 15.0]}],
		"r8c4": ["Hard Pull", 2, "{n:tug} makes the ally's Strings heal faster for {v} sec longer.",
			{"key": "shadow_hard_pull", "values": [1.0, 2.0], "requires": "tug"}],
		"r9c4": ["Wide Pack", 2, "During {n:runthemdown}, each bite of your Hounds hits {v} more enemies.",
			{"key": "shadow_wide_pack", "values": [1.0, 2.0], "requires": "runthemdown"}],
	},
	"holy": {
		# The healer (the Hymns: player.gd, "Holy healer: the Hymns"). Row 1: a way for
		# each Hymn to give Verses (their value: the seconds between two of them).
		# Row 2: Key Change on the left, Shelter's talent on the right.
		"r1c2": ["Mercy's Ear", 2, "Healing an ally below {b:MERCYS_EAR_HEALTH_PCT}% health gives you a Mercy Verse, at most once every {v} sec.",
			{"key": "holy_mercys_ear", "values": [6.0, 3.0]}],
		"r1c4": ["Many Voices", 2, "A heal of yours that lands on {b:MANY_VOICES_ALLIES} or more allies at once gives you a Chorus Verse, at most once every {v} sec. Chorus's extra heals count.",
			{"key": "holy_many_voices", "values": [6.0, 3.0]}],
		"r1c6": ["Watchful", 2, "An ally standing in your Vigil who takes a hit of {b:WATCHFUL_HIT_PCT}% of their maximum health or more gives you a Vigil Verse, at most once every {v} sec.",
			{"key": "holy_watchful", "values": [6.0, 3.0]}],
		"r2c1": ["Key Change", 3, "Singing a Hymn without a boom keeps {v} of your Verses. A boom still spends them all.",
			{"key": "holy_key_change", "values": [1.0, 2.0, 3.0]}],
		"r2c7": ["Open Doors", 4, "{n:shelter}'s shield absorbs {v}% more.",
			{"key": "holy_open_doors", "values": [10.0, 20.0, 30.0, 40.0], "requires": "shelter",
			"capstone": "Its cooldown is {b:OPEN_DOORS_COOLDOWN} sec."}],
		# Open talents (Holy in theme, useful to anyone): the edges of row 1, the
		# middle of row 2, the right of row 3 and the edges of row 9. Long Note
		# (Hymns) sits under Key Change.
		"r1c1": ["Grace", 3, "Your heals on others heal {v}% more.",
			{"key": "holy_grace", "values": [2.0, 4.0, 6.0]}],
		"r1c7": ["Burnished", 3, "Your Holy damage is increased by {v}%.",
			{"key": "holy_burnished", "values": [2.0, 4.0, 6.0]}],
		"r2c4": ["Steadfast", 3, "Increases your Block chance by {v}%.",
			{"key": "holy_steadfast", "values": [2.0, 3.0, 4.0]}],
		"r3c1": ["Long Note", 3, "Bulwark of Song lasts {v} sec longer.",
			{"key": "holy_long_note", "values": [1.0, 2.0, 3.0]}],
		"r3c7": ["Overflowing", 3, "{v}% of your overhealing becomes a shield on that ally for {b:OVERFLOWING_TIME} sec, up to {b:OVERFLOWING_CAP_PCT}% of their maximum health. A bigger one replaces a smaller one.",
			{"key": "holy_overflowing", "values": [10.0, 20.0, 30.0]}],
		"r9c1": ["Penitent", 3, "After you take a hit worth {b:PENITENT_HIT_PCT}% of your maximum health, your next heal on yourself is {v}% stronger.",
			{"key": "holy_penitent", "values": [10.0, 20.0, 30.0]}],
		"r9c7": ["Zeal", 2, "After you use an ability with a cooldown of {b:ZEAL_COOLDOWN} sec or more, you move {v}% faster for {b:ZEAL_TIME} sec.",
			{"key": "holy_zeal", "values": [5.0, 10.0]}],
		# Shared by several specs: Clear Mind, Sheltering Light and Second Breath for both
		# healers; Long Glass for both prism specs (the second healer and the archer).
		"r2c2": ["Clear Mind", 3, "Your Holy heals cost {v}% less mana.",
			{"key": "holy_clear_mind", "values": [3.0, 6.0, 9.0]}],
		"r2c6": ["Sheltering Light", 3, "Your Holy shields absorb {v}% more: Shelter, Vigil's Ward, Prism Ward and Overflowing's shield.",
			{"key": "holy_sheltering_light", "values": [10.0, 20.0, 30.0]}],
		"r5c4": ["Long Glass", 2, "Your prisms of both colours last {v} sec longer.",
			{"key": "holy_long_glass", "values": [15.0, 30.0]}],
		"r10c6": ["Second Breath", 2, "When a heal of yours lifts an ally from below {b:SECOND_BREATH_LOW_PCT}% to above {b:SECOND_BREATH_HIGH_PCT}% health, you get {v}% of your maximum mana back.",
			{"key": "holy_second_breath", "values": [1.0, 2.0]}],
		# More for each spec (the room once kept for a melee and a caster): the tank down
		# the left, the archer down the middle, the Hymns and the Prisms on the right.
		"r4c1": ["Heavy Chain", 2, "{n:censerswing} gives {v} more Incense.",
			{"key": "holy_heavy_chain", "values": [1.0, 2.0], "requires": "censerswing"}],
		"r5c1": ["Absolution", 3, "{n:absolve} heals {v}% more.",
			{"key": "holy_absolution", "values": [10.0, 20.0, 30.0], "requires": "absolve"}],
		"r10c2": ["Unbroken", 2, "{n:unfallen} lasts {v} sec longer.",
			{"key": "holy_unbroken", "values": [1.0, 2.0], "requires": "unfallen"}],
		"r3c4": ["Glimmering", 3, "{n:glimmershot} deals {v}% more damage.",
			{"key": "holy_glimmering", "values": [5.0, 10.0, 15.0], "requires": "glimmershot"}],
		"r7c4": ["Steady Aim", 2, "{n:refractingshot}'s cast is {v} sec shorter.",
			{"key": "holy_steady_aim", "values": [0.25, 0.5], "requires": "refractingshot"}],
		"r4c7": ["Swelling Chorus", 3, "Chorus's extra heals heal {v}% more.",
			{"key": "holy_swelling_chorus", "values": [10.0, 20.0, 30.0], "requires": "singchorus"}],
		"r5c7": ["Quick Lance", 2, "{n:brightlance}'s cast is {v} sec shorter.",
			{"key": "holy_quick_lance", "values": [0.25, 0.5], "requires": "brightlance"}],
		# The last six (the tree is full at 50): the archer's middle column, the tank
		# left, the Hymns and the Prisms right; Watchful Eye for both healers.
		"r8c4": ["Full Quiver", 2, "{n:prismarrow} recharges {v} sec faster.",
			{"key": "holy_full_quiver", "values": [2.0, 4.0], "requires": "prismarrow"}],
		"r9c4": ["Wide Break", 2, "{n:prismbreaker} reaches {v} m further.",
			{"key": "holy_wide_break", "values": [2.0, 4.0], "requires": "prismbreaker"}],
		"r6c1": ["Watchful Eye", 2, "Your heals on an ally who was hit in the last {b:WATCHFUL_EYE_WINDOW} sec heal {v}% more.",
			{"key": "holy_watchful_eye", "values": [10.0, 20.0]}],
		"r6c7": ["Last Rites", 2, "{n:lastverse}'s cooldown is {v} sec shorter.",
			{"key": "holy_last_rites", "values": [30.0, 60.0], "requires": "lastverse"}],
		"r7c3": ["Bright Motes", 2, "Your motes of light heal {v}% more.",
			{"key": "holy_bright_motes", "values": [25.0, 50.0], "requires": "censerswing"}],
		"r7c5": ["Steady Ray", 2, "{n:mendingray} heals {v}% more.",
			{"key": "holy_steady_ray", "values": [10.0, 20.0], "requires": "mendingray"}],
		# The bottom row: one 5-rank talent per side (the tank left, the archer in the
		# middle, both healers right).
		"r10c3": ["Censer's Weight", 5, "Your censer abilities, Incense and Bright Burst deal {v}% more damage.",
			{"key": "holy_censers_weight", "values": [3.0, 6.0, 9.0, 12.0, 15.0]}],
		"r10c4": ["Sunsteel", 5, "Your Lightstring shots, refracted arrows and Spectrum Volley's arrows deal {v}% more damage.",
			{"key": "holy_sunsteel", "values": [3.0, 6.0, 9.0, 12.0, 15.0]}],
		"r10c5": ["Radiance", 5, "Your Holy heals heal {v}% more.",
			{"key": "holy_radiance", "values": [2.0, 4.0, 6.0, 8.0, 10.0]}],
		# The tank (the Censer: player.gd, "Holy tank: the Censer"), down the left side:
		# motes of light and the barrier first, then Hallowed Arc -> Pour Out, Raise the Censer.
		"r3c3": ["Mote Magnet", 2, "You pick up motes of light from {v} m further away.",
			{"key": "holy_mote_magnet", "values": [1.0, 2.0]}],
		"r4c2": ["Bright Barrier", 3, "Each stack of Incense gives {v}% more Block.",
			{"key": "holy_bright_barrier", "values": [0.02, 0.04, 0.06]}],
		"r5c2": ["Lingering Light", 2, "Your motes of light last {v} sec longer.",
			{"key": "holy_lingering_light", "values": [3.0, 6.0]}],
		"r6c3": ["Wide Arc", 2, "{n:hallowedarc} reaches {v} m further.",
			{"key": "holy_wide_arc", "values": [1.0, 2.0], "requires": "hallowedarc"}],
		"r7c1": ["Deep Pour", 3, "{n:pourout} deals {v}% more damage.",
			{"key": "holy_deep_pour", "values": [10.0, 20.0, 30.0], "requires": "pourout",
			"capstone": "It drops motes of light worth {b:DEEP_POUR_MOTE_PCT}% of what it spent."}],
		"r8c2": ["High Censer", 2, "{n:raisethecenser}'s cooldown is {v} sec shorter.",
			{"key": "holy_high_censer", "values": [15.0, 30.0], "requires": "raisethecenser"}],
		# The second healer (the Prisms: player.gd, "Holy healer: the Prisms"), down the right
		# side: the beam and the prisms first, then shattering them (Wide Burst -> Prismatic Burst), Realign.
		"r3c5": ["Clear Glass", 2, "Your beams pass through prisms up to {v} m further from their line.",
			{"key": "holy_clear_glass", "values": [0.5, 1.0]}],
		"r4c6": ["Deep Crystal", 3, "Your prisms hold {v}% more light.",
			{"key": "holy_deep_crystal", "values": [20.0, 40.0, 60.0]}],
		"r5c6": ["Sharp Facets", 2, "A heal is {v}% stronger for each prism it passes through, on top of the usual.",
			{"key": "holy_sharp_facets", "values": [5.0, 10.0]}],
		"r6c5": ["Wide Burst", 2, "Your prisms reach allies and enemies {v} m further when they shatter.",
			{"key": "holy_wide_burst", "values": [2.0, 4.0], "requires": "shatterall"}],
		"r7c7": ["Prismatic Burst", 3, "Your shattering prisms deal {v}% more damage.",
			{"key": "holy_prismatic_burst", "values": [20.0, 40.0, 60.0], "requires": "shatterall"}],
		"r8c6": ["Quick Realign", 2, "{n:realign}'s cooldown is {v} sec shorter.",
			{"key": "holy_quick_realign", "values": [5.0, 10.0], "requires": "realign"}],
		# The archer (Lightstring: player.gd, "Holy archer: Lightstring"), its archery
		# talents grouped down the middle: refraction first, then Sunlit Arrow -> Spectrum Volley.
		"r4c4": ["Wide Fan", 2, "Your refracted arrows find enemies up to {v} m further from the prism.",
			{"key": "holy_wide_fan", "values": [2.0, 4.0]}],
		"r6c4": ["Split Light", 3, "Your refracted arrows deal {v}% more damage.",
			{"key": "holy_split_light", "values": [10.0, 20.0, 30.0]}],
		"r8c3": ["Bright Quiver", 2, "Your auto-shots charge your gold prisms {v}% more.",
			{"key": "holy_bright_quiver", "values": [50.0, 100.0]}],
		"r8c5": ["Deep Burn", 3, "{n:sunlitarrow} deals {v}% more damage from the light it drains.",
			{"key": "holy_deep_burn", "values": [10.0, 20.0, 30.0], "requires": "sunlitarrow",
			"capstone": "It leaves {b:DEEP_BURN_KEEP_PCT}% of the light in each prism."}],
		"r9c3": ["Swift Light", 2, "{n:stepoflight}'s cooldown is {v} sec shorter.",
			{"key": "holy_swift_light", "values": [5.0, 10.0], "requires": "stepoflight"}],
		"r9c5": ["Long Volley", 2, "{n:spectrumvolley} lasts {v} sec longer.",
			{"key": "holy_long_volley", "values": [2.0, 4.0], "requires": "spectrumvolley"}],
	},
}

# --- Links ------------------------------------------------------------------------
## [from, to]: maxing `from` unlocks `to` regardless of its row, so the next
## talent of an ability can be taken before its row opens. Each end is a talent
## "key" (it follows the talent when its slot changes) or a talent id.
## A line must not run behind another talent, and the bottom row has no links.
const LINKS := [
	# --- Fire ---
	# The tank, down the right: Slag Skin's talents, then Cinder Guard's.
	["fire_thick_slag", "fire_hot_iron"],
	["fire_hot_iron", "fire_clinker"],
	["fire_clinker", "fire_slag_mending"],
	["fire_slag_mending", "fire_furnace_heart"],
	# Melee, down the left: the Heat builder, Immolate upkeep, the finisher, then Heat itself.
	["fire_kindling", "fire_fresh_tinder"],
	["fire_fresh_tinder", "fire_afterglow"],
	["fire_afterglow", "fire_forge_heat"],
	["fire_forge_heat", "fire_white_heat"],
	# The caster: burns -> Immolate -> spreading it -> Kiln Blast on it. Slow Fuse's two.
	["fire_lingering_embers", "fire_long_burn"],
	["fire_long_burn", "fire_flashover"],
	["fire_fuse_crit", "fire_flashover"],
	["fire_flashover", "fire_stoked_kiln"],
	# --- Frost ---
	# Shields, down the right edge.
	["frost_absorb", "frost_shield_armor"],
	["frost_shield_armor", "frost_ice_floe"],
	# Ice Shards, down the middle.
	["frost_shard_proc", "frost_shardstorm"],
	["frost_shardstorm", "frost_splinter"],
	# Hoarfrost.
	["frost_hoarfrost", "frost_hoarfrost_burst"],
	# Freezing a target.
	["frost_cold_snap", "frost_instinct"],
	# --- Lightning ---
	# The parry tank: parry talents down column 4, Return Stroke's two down the edge.
	["lightning_long_reach", "lightning_closed_circuit"],
	["lightning_closed_circuit", "lightning_earth_return"],
	["lightning_earth_return", "lightning_tempo"],
	["lightning_counter_charge", "lightning_second_stroke"],
	# Static Step.
	["lightning_running_start", "lightning_whip_crack"],
	# Lightning Bolt -> Storm Arrow's three, down the middle.
	["lightning_quick_fuse", "lightning_rod"],
	["lightning_rod", "lightning_snap_shot"],
	["lightning_snap_shot", "lightning_loaded_quiver"],
	# --- Arcane ---
	# Sigil Darts' two, and Collapse's two.
	["arcane_seventh_sigil", "arcane_etched_darts"],
	["arcane_deep_well", "arcane_aftershock"],
	# The tank: shatters down the left edge, staying alive down the right.
	["arcane_sharp_edges", "arcane_clockwork"],
	["arcane_clockwork", "arcane_spare_copy"],
	["arcane_light_feet", "arcane_empty_room"],
	["arcane_empty_room", "arcane_bent_light"],
	# Melee: Encore's three, down column 5.
	["arcane_standing_ovation", "arcane_second_showing"],
	["arcane_second_showing", "arcane_time_signature"],
	# --- Shadow ---
	# Call Due's two, straight down the middle.
	["shadow_interest", "shadow_small_change"],
	# The Hounds themselves, down the left edge: faster bites, Rage from them, Roused.
	["shadow_lean_and_hungry", "shadow_fed"],
	["shadow_fed", "shadow_worked_up"],
	# How long a pair stays, and what it does as it goes.
	["shadow_long_night", "shadow_take_it_with_you"],
	# Both At Once's two, down the right edge.
	["shadow_pincer", "shadow_again"],
	# The healer: how long a String lasts, then how soon a used-up one is back.
	["shadow_long_thread", "shadow_spare_spool"],
	# --- Holy ---
	# The tank: Hallowed Arc's talent opens Pour Out's.
	["holy_wide_arc", "holy_deep_pour"],
	# The second healer: Wide Burst opens Prismatic Burst.
	["holy_wide_burst", "holy_prismatic_burst"],
	# The archer: Deep Burn opens Long Volley (straight down).
	["holy_deep_burn", "holy_long_volley"],
]

static var _db := {}
static var _keys := {}         # talent "key" -> talent id
static var _rows_cache := {}   # "cat:row" -> Array[String]
static var _links: Array = []  # built from LINKS (tests may replace it)
static var _links_ready := false

static func layout(category: String) -> Array:
	return LAYOUTS.get(category, DEFAULT_LAYOUT)

## Talents that changed slot: old id -> new id, so points saved in the old slot
## follow the talent (SaveSystem._valid_talents). An old id listed here must not
## be given to a new talent.
const MOVED := {
	"fire_r2c4": "fire_r3c4",   # Cool Under Fire: row 2 -> row 3
	"lightning_r2c4": "lightning_r3c5",   # Long Reach: row 2 -> row 3
}

## The Frost book was rearranged to put the bow talents together (save version
## 4 -> 5, SaveSystem._migrate_4_to_5). Three talents were removed and five
## changed slot; several of the old slots now hold a different talent, so this
## is applied once, to saves made before the change (never through MOVED, which
## is applied on every load).
const FROST_BOW_REMOVED := ["frost_r1c4", "frost_r3c2", "frost_r5c6"]   # Deep Chill, Endless Winter, Winter's Clarity
const FROST_BOW_MOVED := {
	"frost_r2c6": "frost_r2c3",   # Quickened Frost: right -> left of row 2
	"frost_r2c4": "frost_r2c5",   # Pinning Frost: middle of row 2 -> its right
	"frost_r3c6": "frost_r1c2",   # Bitter Cold: row 3 -> row 1
	"frost_r4c5": "frost_r3c2",   # Deep Hoarfrost: row 4 -> row 3
	"frost_r5c4": "frost_r5c3",   # Third Bite: middle of row 5 -> its left
}

## Talents changed slot so that an ability's talents line up, the most important
## at the top, and can be linked (save version 5 -> 6, SaveSystem._migrate_5_to_6).
## Old id -> new id; nothing was removed. Like FROST_BOW_MOVED this is applied
## once, to saves made before the change: most old slots now hold another talent.
const LINKS_MOVED := {
	"fire_r8c3": "fire_r5c3",   # Long Burn: row 8 -> row 5
	"fire_r5c3": "fire_r6c3",   # Scattered Embers: row 5 -> row 6
	"fire_r6c3": "fire_r8c3",   # Thick Pitch: row 6 -> row 8
	"frost_r1c2": "frost_r1c1",   # Bitter Cold: to the left edge of row 1
	"frost_r1c6": "frost_r1c5",   # Cold Draw: one column left
	"frost_r1c5": "frost_r1c7",   # Rime Ward: to the right edge of row 1
	"frost_r7c4": "frost_r4c7",   # Hardened Frost: row 7 -> row 4, under Rime Ward
	"frost_r9c2": "frost_r8c7",   # Ice Floe: row 9 -> row 8, under Hardened Frost
	"frost_r4c7": "frost_r5c2",   # Brittle Rime: under Deep Hoarfrost
	"frost_r5c2": "frost_r7c2",   # Clean Break: row 5 -> row 7
	"frost_r7c2": "frost_r6c4",   # Shardstorm: row 7 -> row 6, under Splintering Cold
	"frost_r7c6": "frost_r7c4",   # Splintering: to the middle, under Shardstorm
	"frost_r6c4": "frost_r8c1",   # Lingering Frost: row 6 -> row 8
	"frost_r8c1": "frost_r9c2",   # Chilling Presence: row 8 -> row 9
	"frost_r8c7": "frost_r9c6",   # Numbing Cold: row 8 -> row 9
	"frost_r9c6": "frost_r7c6",   # Frozen Instinct: row 9 -> row 7, under Cold Snap
	"lightning_r5c4": "lightning_r6c4",   # Quick Fuse: row 5 -> row 6
	"lightning_r6c4": "lightning_r5c4",   # Tight Coil: row 6 -> row 5
	"lightning_r9c4": "lightning_r7c4",   # Lightning Rod: row 9 -> row 7
	"lightning_r7c4": "lightning_r9c4",   # Snap Shot: row 7 -> row 9
	"lightning_r8c6": "lightning_r6c7",   # Second Stroke: row 8 -> row 6, under Counter-Charge
	"lightning_r6c7": "lightning_r8c5",   # Tempo: row 6 -> row 8, under Earth Return
	"lightning_r8c5": "lightning_r8c6",   # Parting Spark: one column right
}

## Small Change moved up from row 8 to row 5, straight under Interest, to make
## room down the middle of the Shadow book (save version 6 -> 7,
## SaveSystem._migrate_6_to_7). Its old slot now holds Hard Pull, so like
## LINKS_MOVED this is applied once, to saves made before the change.
const SHADOW_MIDDLE_MOVED := {
	"shadow_r8c4": "shadow_r5c4",   # Small Change: row 8 -> row 5
}

## Saved ranks (talent id -> rank) after a rearrangement: points in `removed`
## talents are dropped (so they are refunded), and `moved` talents keep theirs
## under their new id. Every id is read as an OLD id, so a slot one talent left
## and another took is never mixed up.
static func rearranged(ranks: Dictionary, moved: Dictionary, removed: Array) -> Dictionary:
	var out := {}
	for id in ranks:
		var key := str(id)
		if removed.has(key):
			continue
		out[str(moved.get(key, key))] = ranks[id]
	return out

## The id a saved talent id has today (itself, unless the talent moved).
static func current_id(id: String) -> String:
	return str(MOVED.get(id, id))

static func make_id(category: String, row: int, col: int) -> String:
	return "%s_r%dc%d" % [category, row + 1, col + 1]

## Flat view: id -> {name, category, tier (row index), col, max_rank, desc, stats,
## implemented, placeholder}.
static func db() -> Dictionary:
	if _db.is_empty():
		for cat in Categories.ORDER:
			var rows: Array = layout(cat)
			var defs: Dictionary = TALENTS.get(cat, {})
			for r in mini(rows.size(), ROWS):
				var ids: Array[String] = []
				var cols: Array = rows[r].duplicate()
				cols.sort()
				for c in cols:
					var id := make_id(cat, r, int(c))
					var key := "r%dc%d" % [r + 1, int(c) + 1]
					var entry := {"category": cat, "tier": r, "col": int(c), "stats": {}}
					if defs.has(key):
						var d: Array = defs[key]
						var extra: Dictionary = d[3] if d.size() > 3 and d[3] is Dictionary else {}
						entry["name"] = str(d[0])
						entry["max_rank"] = int(d[1])
						entry["desc"] = str(d[2]) if d.size() > 2 else ""
						entry["implemented"] = not extra.is_empty()
						entry["placeholder"] = false
						entry["stats"] = extra.get("stats", {})
						entry["values"] = extra.get("values", [])
						entry["values2"] = extra.get("values2", [])
						entry["requires"] = str(extra.get("requires", ""))
						entry["capstone"] = str(extra.get("capstone", ""))
						entry["capstone_requires"] = str(extra.get("capstone_requires", ""))
						if extra.has("key"):
							_keys[str(extra["key"])] = id
					else:
						entry["name"] = "Empty Talent"
						entry["max_rank"] = PLACEHOLDER_RANKS
						entry["desc"] = "Not designed yet."
						entry["implemented"] = false
						entry["placeholder"] = true
					_db[id] = entry
					ids.append(id)
				_rows_cache["%s:%d" % [cat, r]] = ids
	return _db

static func get_talent(id: String) -> Dictionary:
	return db().get(id, {})

static func exists(id: String) -> bool:
	return db().has(id)

## Talent id for a talent's "key" (e.g. "frost_haste" -> "frost_r1c3"), "" if none.
static func id_for_key(key: String) -> String:
	db()
	return str(_keys.get(key, ""))

## A talent's number at `rank` (its "values" list, or "values2" for a talent's
## second number), 0 at rank 0.
static func value_at(id: String, rank: int, field: String = "values") -> float:
	var vals: Array = get_talent(id).get(field, [])
	if rank <= 0 or vals.is_empty():
		return 0.0
	return float(vals[mini(rank, vals.size()) - 1])

## Row index (0 = top) of a talent.
static func tier_of(id: String) -> int:
	return int(get_talent(id).get("tier", 0))

## Column index (0 = left) of a talent.
static func col_of(id: String) -> int:
	return int(get_talent(id).get("col", 0))

static func category_of(id: String) -> String:
	return str(get_talent(id).get("category", ""))

static func max_rank(id: String) -> int:
	return int(get_talent(id).get("max_rank", 0))

## Does this talent have a capstone (a bonus that turns on at max rank)?
static func has_capstone(id: String) -> bool:
	return str(get_talent(id).get("capstone", "")) != ""

## Talent ids in one row of one category's tree (left to right).
static func in_row(category: String, row: int) -> Array[String]:
	db()
	var out: Array[String] = []
	out.assign(_rows_cache.get("%s:%d" % [category, row], []))
	return out

## Every talent id in one category's tree.
static func in_tree(category: String) -> Array[String]:
	var out: Array[String] = []
	for r in ROWS:
		out.append_array(in_row(category, r))
	return out

# --- Links ------------------------------------------------------------------------

static func links() -> Array:
	if not _links_ready:
		_links = []
		for l in LINKS:
			var from := _link_end(str(l[0])) if l.size() >= 2 else ""
			var to := _link_end(str(l[1])) if l.size() >= 2 else ""
			if exists(from) and exists(to) and from != to:
				_links.append([from, to])
			else:
				push_warning("Talents: ignoring invalid link %s" % [l])
		_links_ready = true
	return _links

## One end of a LINKS pair as a talent id: a talent "key" becomes its id, an id stays.
static func _link_end(s: String) -> String:
	var id := id_for_key(s)
	return id if id != "" else s

## Replace the links at runtime (tests / debugging). Pass null to go back to LINKS.
static func set_links(new_links) -> void:
	if new_links == null:
		_links_ready = false
		links()
	else:
		_links = new_links
		_links_ready = true

## Talents that unlock `id` when maxed.
static func sources_of(id: String) -> Array[String]:
	var out: Array[String] = []
	for l in links():
		if l[1] == id:
			out.append(l[0])
	return out

## Talents that `id` unlocks when maxed.
static func targets_of(id: String) -> Array[String]:
	var out: Array[String] = []
	for l in links():
		if l[0] == id:
			out.append(l[1])
	return out

## Links with both ends in one book (the ones drawn as lines there).
static func links_in_tree(category: String) -> Array:
	return links().filter(func(l): return category_of(l[0]) == category and category_of(l[1]) == category)

# --- Text -------------------------------------------------------------------------
# Talent texts never carry a typed number. They hold placeholders, filled from
# the talent's own values and from balance.gd whenever a tooltip is shown:
#   {v} {v2}            the talent's values / values2, as "1 / 2 / 3"
#   {v+b:NAME}          each value + Balance.NAME ("35 / 45" for 25 + 10 / 20)
#   {vdmg:<ability>}    each value as real damage (a hit of that coefficient with
#                       the ability's tags, at your level and stats)
#   {v+dmg:<ability>}   the ability's own damage + each value, as real damage
#   {dmg:<ability>}     the ability's own damage, as real damage
#   {bdmg:NAME}         Balance.NAME (a coefficient) as real damage, as a hit of the
#                       ability the talent requires
#   plus everything TextFill.constants() knows ({b:..}, {e:..}, {a:..}, {n:..}).

const TextFill = preload("res://scripts/core/text_fill.gd")
static var _fill_re: RegEx

static func _join(vals: Array, add: float = 0.0) -> String:
	var parts: Array[String] = []
	for v in vals:
		parts.append(TextFill.num(float(v) + add))
	return " / ".join(parts)

## `text` of talent entry `t` with every number filled in.
static func fill(text: String, t: Dictionary) -> String:
	if not text.contains("{"):
		return text
	var vals: Array = t.get("values", [])
	text = text.replace("{v}", _join(vals)).replace("{v2}", _join(t.get("values2", [])))
	if _fill_re == null:
		_fill_re = RegEx.create_from_string("\\{(v\\+b|vdmg|v\\+dmg|dmg|bdmg):([A-Za-z0-9_]+)\\}")
	var out := ""
	var at := 0
	for m in _fill_re.search_all(text):
		out += text.substr(at, m.get_start() - at)
		at = m.get_end()
		var kind := m.get_string(1)
		var key := m.get_string(2)
		if kind == "v+b":
			var b: Variant = TextFill.balance_value(key)
			out += _join(vals, float(b) if (b is float or b is int) else 0.0)
			continue
		var abilities: GDScript = load("res://scripts/abilities.gd")
		if kind == "bdmg":
			# A coefficient of balance.gd as a hit of the ability the talent works with.
			var coef_b: Variant = TextFill.balance_value(key)
			out += str(abilities.fmt_amount(abilities.coef_damage(float(coef_b) if (coef_b is float or coef_b is int) else 0.0,
				abilities.tags_of(str(t.get("requires", ""))))))
			continue
		var r: Resource = abilities.get_resource(key)
		var base := float(r.damage) if r else 0.0
		var tags: PackedStringArray = abilities.tags_of(key)
		if kind == "dmg":
			out += str(abilities.fmt_amount(abilities.coef_damage(base, tags)))
			continue
		var parts: Array[String] = []
		for v in vals:
			var coef := float(v) + (base if kind == "v+dmg" else 0.0)
			parts.append(str(abilities.fmt_amount(abilities.coef_damage(coef, tags))))
		out += " / ".join(parts)
	return TextFill.constants(out + text.substr(at))

## A talent's description, numbers filled in.
static func description(id: String) -> String:
	var t := get_talent(id)
	return fill(str(t.get("desc", "")), t)

## A talent's capstone text, numbers filled in ("" if it has none).
static func capstone_text(id: String) -> String:
	var t := get_talent(id)
	return fill(str(t.get("capstone", "")), t)

# --- Tooltip ------------------------------------------------------------------------

## The line a talent that only works with one ability carries (tooltip, and the
## reason points can't be spent in it yet).
static func requires_line(ability_id: String) -> String:
	return "Requires %s to be learned" % load("res://scripts/abilities.gd").ability_name(ability_id)

## The ability a talent needs before points can go into it ("" = none).
static func required_ability(id: String) -> String:
	return str(get_talent(id).get("requires", ""))

static func tooltip(id: String, rank: int) -> String:
	var t := get_talent(id)
	if t.is_empty():
		return ""
	var lines: Array[String] = [
		"%s  (%s, row %d)" % [t["name"], Categories.cat_name(t["category"]), int(t["tier"]) + 1],
		fill(str(t["desc"]), t),
		"Rank %d / %d" % [rank, int(t["max_rank"])],
	]
	var req := str(t.get("requires", ""))
	if req != "":
		lines.append(requires_line(req))
	var cap := fill(str(t.get("capstone", "")), t)
	if cap != "":
		var maxed := rank >= int(t["max_rank"])
		lines.append("Capstone (%s): %s" % ["active" if maxed else "at rank %d" % int(t["max_rank"]), cap])
		var creq := str(t.get("capstone_requires", ""))
		if creq != "":
			lines.append("Capstone requires %s to be learned" % load("res://scripts/abilities.gd").ability_name(creq))
	for s in sources_of(id):
		lines.append("Also unlocked by maxing %s (%s, row %d)" % [get_talent(s)["name"],
			Categories.cat_name(category_of(s)), tier_of(s) + 1])
	for s in targets_of(id):
		lines.append("Maxing this unlocks %s (%s, row %d)" % [get_talent(s)["name"],
			Categories.cat_name(category_of(s)), tier_of(s) + 1])
	if not t.get("implemented", false) and not t.get("placeholder", false):
		lines.append("(Not implemented yet: has no effect)")
	return "\n".join(lines)
