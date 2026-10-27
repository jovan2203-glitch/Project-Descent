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
const Stats = preload("res://scripts/core/stats.gd")

const ROWS := 10
const COLUMNS := 7
const MIN_PER_ROW := 2
const MAX_PER_ROW := 16   # (a book on the ribbon layout: up to one per column)
const POINTS_TO_UNLOCK_NEXT := 3
## Bump this whenever a talent is added, moved, removed or changed. A profile saved
## with another number gets all its talent points back on its next load
## (SaveSystem), so talent changes never need a save migration.
const TREE_VERSION := 12
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
## mirror-symmetric around the middle column (3), with 2-7 talents (mostly 2
## or 3), and no two books share a shape. Books not listed use DEFAULT_LAYOUT.
## Empty slots are kept for new talents (some were left when a talent was
## folded into its ability); a new slot keeps its row mirror-symmetric.
## In those three books an ability's talents run top to bottom, the most
## important first, joined by LINKS. A link is drawn as a straight line between
## the two slots, so when a talent moves, check its lines still run clear of the
## other talents (tests/test_talent_links.gd does).
##   Fire       on the ribbon layout (GROUPS, SHAPES), like Martial: see LAYOUTS.
##   Frost      on the ribbon layout (GROUPS, SHAPES), like Martial and Fire: see LAYOUTS.
##   Lightning  on the ribbon layout (GROUPS, SHAPES), like Martial, Fire and Frost: see LAYOUTS.
##   Arcane     on the ribbon layout (GROUPS, SHAPES), like Martial, Fire, Frost and Lightning: see LAYOUTS.
##   Shadow     on the ribbon layout (GROUPS, SHAPES), like Martial, Fire, Frost, Lightning and Arcane: see LAYOUTS.
##   Nature     on the ribbon layout (GROUPS, SHAPES), like the books above: see LAYOUTS.
##   Holy       on the ribbon layout (GROUPS, SHAPES), like the books above: see LAYOUTS.
const LAYOUTS := {
	# (Fire, on the ribbon layout (GROUPS, 13 columns): Steady Flame in columns 0-2, Slagforged
	# 3-5, the open talents on the spine (6), Forge Heat 7-9, Pitch and Cinder 10-12. Each spec's
	# rows 1-9 draw its shape (SHAPES); row 10 holds its capstone in its middle column.)
	"fire": [[1, 3, 4, 5, 6, 7, 8, 9, 11], [0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], [1, 4, 6, 7, 8, 9, 10, 11, 12],
		[0, 2, 4, 6, 8, 11], [0, 1, 2, 4, 6, 8, 11], [0, 1, 2, 4, 6, 7, 9, 11],
		[0, 1, 2, 3, 5, 6, 7, 9, 10, 12], [0, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12], [1, 3, 4, 5, 8, 10, 11, 12],
		[1, 4, 8, 11]],
	# (Frost, on the ribbon layout (GROUPS, 16 columns): Hard Winter in columns 0-2, Cold
	# Comfort 3-5, the open talents on the spine (6), Frostbitten Steel 7-9, Glacier Wall 10-12,
	# Winter Hunt 13-15. Each spec's rows 1-9 draw its shape (SHAPES); row 10 its capstone.)
	"frost": [[1, 4, 6, 8, 11, 13, 15], [0, 2, 3, 4, 5, 6, 7, 8, 9, 11, 13, 14, 15], [0, 1, 2, 4, 6, 7, 9, 10, 12, 13, 14, 15],
		[0, 2, 4, 6, 7, 9, 10, 12, 14], [0, 2, 3, 5, 6, 7, 9, 10, 12, 14], [0, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 14],
		[0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15], [0, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], [1, 3, 5, 6, 8, 11, 14],
		[1, 4, 8, 11, 14]],
	# (Lightning, on the ribbon layout (GROUPS, 13 columns): Live Current in columns 0-2, Stormdancer
	# 3-5, the open talents on the spine (6), Lightning Rod 7-9, and Stormstring 10-12: a short ribbon,
	# its Storm Arrow talents in the middle of rows 1-3 until the spec is built.)
	"lightning": [[0, 2, 3, 5, 6, 8, 11], [0, 1, 2, 3, 5, 6, 7, 8, 9, 11], [0, 1, 2, 3, 4, 5, 6, 8, 11],
		[0, 1, 2, 3, 5, 6, 7, 8, 9], [1, 3, 5, 6, 8], [0, 2, 4, 6, 8], [1, 3, 5, 6, 7, 9],
		[0, 2, 3, 5, 6, 7, 8, 9], [1, 3, 5, 6, 7, 8, 9],
		[1, 4, 8]],
	# (Arcane, on the ribbon layout (GROUPS, 13 columns): Clockwork in columns 0-2, Hall of Mirrors
	# 3-5, the open talents on the spine (6), Second Act 7-9, and Aetherstring 10-12: an empty short
	# ribbon until the spec is built.)
	"arcane": [[1, 3, 4, 5, 6, 7, 8, 9], [0, 2, 3, 5, 6, 7, 9], [0, 2, 3, 5, 6, 7, 9],
		[0, 2, 3, 5, 6, 7, 9], [0, 1, 2, 3, 4, 5, 6, 7, 9], [0, 1, 2, 4, 6, 7, 9], [0, 2, 4, 6, 7, 9],
		[0, 2, 4, 6, 7, 9], [1, 3, 4, 5, 6, 8],
		[1, 4, 8]],
	# (Shadow, on the ribbon layout (GROUPS, 13 columns): The Breach in columns 0-2, Pack of Two
	# 3-5, the open talents on the spine (6), Strings Attached 7-9, and Nightstring 10-12: an empty
	# short ribbon until the spec is built.)
	"shadow": [[0, 1, 2, 3, 5, 6, 8], [0, 2, 4, 6, 7, 8, 9], [0, 2, 3, 5, 6, 8], [0, 2, 4, 6, 7, 8, 9],
		[1, 3, 4, 5, 6, 8], [1, 3, 4, 5, 6, 7, 9], [0, 2, 3, 4, 5, 6, 7, 9], [0, 2, 3, 5, 6, 7, 9],
		[0, 1, 2, 4, 6, 7, 8, 9],
		[1, 4, 8]],
	# (Nature, on the ribbon layout (GROUPS, 13 columns): Thornweaver in columns 0-2, Shepherd
	# 3-5, the open talents on the spine (6), Colossus 7-9, Venomstring 10-12. Each spec's rows
	# 1-9 draw its shape (SHAPES); row 10 its capstone.)
	"nature": [[0, 2, 4, 6, 8, 10, 12], [1, 3, 4, 5, 6, 7, 9, 10, 11, 12], [0, 2, 3, 4, 5, 6, 7, 8, 9, 11],
		[1, 4, 6, 7, 8, 9, 10, 12], [0, 1, 2, 4, 6, 7, 8, 9, 11], [1, 3, 5, 6, 8, 10, 12], [0, 2, 3, 4, 5, 6, 8, 11],
		[0, 1, 2, 3, 5, 6, 8, 10, 11, 12], [0, 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12],
		[1, 4, 8, 11]],
	# (Holy, on the ribbon layout (GROUPS, 13 columns): Choir of One in columns 0-2, Censer
	# Bearer 3-5, the open talents on the spine (6), Line of Light 7-9, Lightstring 10-12. Each
	# spec's rows 1-9 draw its shape (SHAPES); row 10 its capstone.)
	"holy": [[1, 4, 6, 8, 10, 11, 12], [0, 2, 4, 6, 7, 9, 10, 12], [1, 3, 4, 5, 6, 7, 8, 9, 11],
		[0, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12], [0, 2, 3, 5, 6, 7, 9, 11], [0, 2, 3, 5, 6, 7, 9, 11],
		[0, 2, 3, 4, 5, 6, 7, 9, 11], [0, 1, 2, 4, 6, 7, 9, 10, 11, 12], [0, 1, 2, 3, 4, 5, 6, 8, 10, 11, 12],
		[1, 4, 8, 11]],
	# (One book where Warrior, Rogue and Ranger used to be three.) The ribbon layout (GROUPS,
	# 13 columns): the Wheel in columns 0-2, the Rogue 3-5, the open talents on the spine (6,
	# skipping row 7), the Brawler 7-9, the Sharpshooter 10-12. Each spec's rows 1-9 draw its
	# shape (SHAPES); row 10 holds its capstone in its middle column.
	"martial": [[1, 3, 5, 6, 7, 8, 9, 10, 11, 12], [0, 2, 3, 5, 6, 7, 8, 9, 11], [0, 2, 3, 5, 6, 7, 8, 9, 10, 12],
		[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], [0, 2, 4, 6, 8, 10, 12], [0, 1, 2, 3, 5, 6, 8, 10, 11, 12],
		[0, 2, 3, 5, 8, 10, 12], [0, 2, 3, 5, 6, 8, 11], [1, 3, 5, 6, 7, 9, 11],
		[1, 4, 8, 11]],
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
		# The ribbon layout (GROUPS): Steady Flame (the caster) in columns 1-3,
		# Slagforged (the tank) in 4-6, the open talents on the spine (column 7),
		# Forge Heat (melee) in 8-10 and Pitch and Cinder (the bow) in 11-13. Rows 1-9
		# hold 18 talents per spec in its shape (SHAPES); row 10 its 5-rank capstone, which needs
		# Balance.CAPSTONE_GATE points in the spec. Most key off the spec's own words
		# (Fury, Venting, Slag, blocks, Heat, Sparks, Pitch, Ignites...); few need one
		# ability. Code: each spec's component (fire_fury.gd, fire_tank.gd,
		# fire_melee.gd, fire_bow.gd) and fire_talents.gd for the hits' bonuses.
		# --- Steady Flame.
		"r1c2": ["Stoked Breath", 4, "Your Fire spells that do not critically strike give you {v}% more Fury.",
			{"key": "fire_stoked_breath", "values": [5.0, 10.0, 15.0, 20.0]}],
		# Firebolt (ability id "fireball") crits less, and turns crit chance into damage
		# (Player.fire_crit_rules).
		"r2c1": ["Tempered Flame", 3, "Your {n:fireball} gains {v}% less of your critical strike chance, but deals bonus damage equal to {v2}% of your critical strike chance.",
			{"key": "fire_tempered_flame", "values": [40.0, 50.0, 60.0], "values2": [7.0, 13.0, 20.0], "requires": "fireball"}],
		"r2c3": ["Pressure Valve", 3, "Each of your Fire spells that fails to critically strike takes {v} sec off the cooldown of {n:ventflames}.",
			{"key": "fire_pressure_valve", "values": [0.15, 0.35, 0.5], "requires": "ventflames"}],
		"r3c2": ["Lean Fuel", 3, "Your spells and abilities that cost Fury cost {v} less.",
			{"key": "fire_lean_fuel", "values": [2.0, 4.0, 6.0]}],
		"r4c1": ["Banked Coals", 2, "Your critical strikes Vent {v}% less of your Fury.",
			{"key": "fire_banked_coals", "values": [25.0, 50.0]}],
		# Crits build, the next non-crit spends, and a stack is worth more the LESS
		# crit chance you have. The hook is in fire_runes.gd.
		"r4c3": ["Afterburn", 3, "Every Fire spell hit that critically strikes builds a stack of Afterburn (up to {e:afterburn.stacks}, {e:afterburn.time} sec, refreshed by each stack). Your next Fire spell hit that does NOT critically strike spends them all and deals +((100 - critical strike chance) x {v})% damage per stack.",
			{"key": "fire_afterburn", "values": [0.17, 0.33, 0.5]}],
		# The first choice talent (Talents.options_of): points go into one of the two.
		# Both move the embers' crit chance, not the Fury they give (FireFuryKit).
		"r5c1": {"choice": [
			["Damped Embers", 3, "The embers of your {n:embervolley} have {v}% less critical strike chance.",
				{"key": "fire_damped_embers", "values": [10.0, 20.0, 30.0], "requires": "embervolley"}],
			["Wild Embers", 3, "The embers of your {n:embervolley} have {v}% more critical strike chance.",
				{"key": "fire_wild_embers", "values": [10.0, 20.0, 30.0], "requires": "embervolley"}],
		]},
		"r5c2": ["Scattered Embers", 2, "Each ember of your {n:embervolley} also strikes {v} additional enemies within {b:EMBER_VOLLEY_SPLIT_RADIUS} m of your target.",
			{"key": "fire_volley_targets", "values": [1.0, 2.0], "requires": "embervolley"}],
		# A crit that Vents your Fury burns its target with part of it (FireFuryKit).
		"r5c3": ["Blowback", 3, "When a critical strike of yours Vents your Fury, {v}% of the Fury it Vents burns the target: {ds:BLOWBACK_PER_FURY} Fire damage per point, dealt over {b:BLOWBACK_TIME} sec.",
			{"key": "fire_blowback", "values": [20.0, 35.0, 50.0]}],
		"r6c1": ["Long Burn", 3, "Your Burning and {n:immolate} last {v} sec longer.",
			{"key": "fire_long_burn", "values": [1.0, 2.0, 3.0]}],
		"r6c2": ["Stoked Kiln", 3, "Your spells and abilities that cost Fury deal {v}% more damage to a target with your {n:immolate}.",
			{"key": "fire_stoked_kiln", "values": [5.0, 10.0, 15.0]}],
		"r6c3": ["Hold the Heat", 3, "While you are not casting, your Fury drops {v}% slower.",
			{"key": "fire_hold_the_heat", "values": [33.0, 66.0, 100.0]}],
		"r7c1": ["Long Focus", 3, "Your Concentrated Fire lasts {v} sec longer.",
			{"key": "fire_long_focus", "values": [2.0, 4.0, 6.0]}],
		"r7c2": ["Clean Burn", 3, "Your Fire spells that do not critically strike deal {v}% more damage.",
			{"key": "fire_clean_burn", "values": [2.0, 4.0, 6.0]}],
		"r7c3": ["Big Spend", 3, "A spell or ability that spends {b:BIG_SPEND_FURY} or more Fury deals {v}% more damage.",
			{"key": "fire_big_spend", "values": [5.0, 10.0, 15.0]}],
		"r8c1": ["Warm Start", 2, "When you enter combat, you gain {v} Fury.",
			{"key": "fire_warm_start", "values": [20.0, 40.0]}],
		"r8c3": ["Low Flame", 3, "While your critical strike chance is below {b:LOW_FLAME_CRIT}%, your Fire spells deal {v}% more damage.",
			{"key": "fire_low_flame", "values": [3.0, 6.0, 9.0]}],
		"r9c2": ["Stay Lit", 3, "After a critical strike Vents your Fury, your next Fire spell that does not critically strike gives {v}% more Fury.",
			{"key": "fire_stay_lit", "values": [30.0, 60.0, 100.0]}],
		# Holding Fury pays (FireFuryKit.smolder_pct).
		"r10c2": ["Smoldering Focus", 5, "Your Fire spells deal {v}% more damage for each point of Fury you have.",
			{"key": "fire_smoldering_focus", "values": [0.02, 0.04, 0.06, 0.08, 0.1]}],
		# --- Slagforged.
		"r1c4": ["Thick Slag", 4, "Each stack of Slag gives {v}% more Armor.",
			{"key": "fire_thick_slag", "values": [15.0, 30.0, 45.0, 60.0]}],
		"r1c5": ["Hot Iron", 3, "Attacks you block burn the attacker for {v}% more ({n:slagskin} and {n:cinderguard}).",
			{"key": "fire_hot_iron", "values": [10.0, 20.0, 30.0]}],
		"r1c6": ["Slag Mending", 3, "When your Slag shatters, you are healed for {v}% of your maximum health per stack.",
			{"key": "fire_slag_mending", "values": [0.7, 1.3, 2.0]}],
		"r2c5": ["Deep Brand", 3, "An enemy you have Branded deals {v+b:BRAND_PCT}% less damage to you, instead of {b:BRAND_PCT}%.",
			{"key": "fire_deep_brand", "values": [2.0, 4.0, 6.0], "requires": "brand"}],
		"r2c4": ["Smoldering Debris", 3, "When your Slag shatters it leaves a burning patch {b2:CLINKER_RADIUS} m wide for {b:CLINKER_TIME} sec, dealing {v}% of the shatter's damage {bev:CLINKER_TICK} to enemies standing in it.",
			{"key": "fire_clinker", "values": [7.0, 13.0, 20.0]}],
		"r2c6": ["Hard Crust", 3, "Each stack of Slag gives you {v}% chance to block.",
			{"key": "fire_hard_crust", "values": [0.5, 1.0, 1.5]}],
		"r3c5": ["Set Hard", 2, "Your brittle Slag lasts {v} sec longer.",
			{"key": "fire_set_hard", "values": [1.5, 3.0]}],
		"r4c5": ["Red Iron", 3, "Your shield abilities deal {v}% more damage.",
			{"key": "fire_red_iron", "values": [5.0, 10.0, 15.0]}],
		"r5c5": ["Marked Iron", 3, "Your Slag shattering deals {v}% more damage to enemies you have Branded.",
			{"key": "fire_marked_iron", "values": [33.0, 66.0, 100.0]}],
		"r6c5": ["Fuel the Forge", 3, "Each attack you block gives you {v} Fury.",
			{"key": "fire_fuel_the_forge", "values": [2.0, 4.0, 6.0]}],
		"r7c4": ["Deep Slag", 2, "You can hold {v} more Slag.",
			{"key": "fire_deep_slag", "values": [1.0, 2.0]}],
		"r7c6": ["Riveted", 3, "{n:redhotrivet}'s cooldown is {v} sec shorter.",
			{"key": "fire_riveted", "values": [1.0, 2.0, 3.0], "requires": "redhotrivet"}],
		"r8c5": ["Heavy Hammer", 3, "{n:forgeblow} gives you {v} Fury back for each stack of Slag it shatters.",
			{"key": "fire_heavy_hammer", "values": [2.0, 4.0, 6.0], "requires": "forgeblow"}],
		"r8c4": ["Glowing Seams", 3, "While you hold all the Slag you can, your spells and abilities generate {v}% more threat.",
			{"key": "fire_glowing_seams", "values": [10.0, 20.0, 30.0]}],
		"r8c6": ["Long Shell", 2, "{n:moltenshell} lasts {v} sec longer.",
			{"key": "fire_long_shell", "values": [2.0, 4.0], "requires": "moltenshell"}],
		"r9c4": ["Spatter", 3, "When your Slag shatters, there is a {v}% chance a stack of it stays on you.",
			{"key": "fire_spatter", "values": [20.0, 40.0, 60.0]}],
		"r9c5": ["Quick Temper", 3, "When your Slag shatters, the cooldown of {n:cinderguard} is {v} sec shorter.",
			{"key": "fire_quick_temper", "values": [1.0, 2.0, 3.0]}],
		"r9c6": ["Heat Shimmer", 3, "Each stack of Slag makes you take {v}% less damage from spells.",
			{"key": "fire_heat_shimmer", "values": [0.5, 1.0, 1.5]}],
		"r10c5": ["Molten Heart", 5, "Your Slag shattering deals {v}% more damage and threat for each stack above {b:MOLTEN_HEART_ABOVE}.",
			{"key": "fire_molten_heart", "values": [2.0, 4.0, 6.0, 8.0, 10.0]}],
		# --- Open talents: themed to the book (burns, blocking) but they work with every
		# book's spells and abilities (open_talents_fire_lightning.gd and player.gd).
		"r1c7": ["Flash Point", 3, "Increases your Critical Strike chance by {v}%.",
			{"key": "fire_flash_point", "values": [1.0, 2.0, 3.0], "stats": {"crit_chance": 1.0}}],
		"r2c7": ["Forge-Hardened", 3, "Increases your Attack Power by {v}% of your Strength.",
			{"key": "fire_forge_hardened", "values": [2.0, 4.0, 6.0]}],
		"r3c7": ["Lingering Embers", 3, "Your Fire damage over time effects deal {v}% more damage.",
			{"key": "fire_lingering_embers", "values": [3.0, 6.0, 9.0]}],
		"r4c7": ["Controlled Burn", 3, "Your Fire spells and abilities generate {v}% less threat.",
			{"key": "fire_controlled_burn", "values": [5.0, 10.0, 15.0]}],
		"r5c7": ["Feed the Flames", 3, "Your direct hits deal {v}% more damage to enemies that carry one of your damage over time effects.",
			{"key": "fire_feed_the_flames", "values": [2.0, 4.0, 6.0]}],
		"r6c7": ["Last Ember", 2, "When one of your damage over time effects runs its full time, it ticks once more for {v}% of a tick's damage.",
			{"key": "fire_last_ember", "values": [50.0, 100.0]}],
		"r8c7": ["Warm Blood", 3, "You take {v}% less damage from an enemy that has your Burning or {n:immolate} on it.",
			{"key": "fire_warm_blood", "values": [2.0, 4.0, 6.0]}],
		"r7c7": ["Tempered", 3, "Each attack you block increases your Armor by {v}% for {b:TEMPERED_TIME} sec, stacking up to {b:TEMPERED_STACKS} times.",
			{"key": "fire_tempered", "values": [2.0, 4.0, 6.0]}],
		# --- Forge Heat.
		"r1c8": ["White Heat", 4, "While your Heat is in the White band, your abilities deal {v}% more Fire damage.",
			{"key": "fire_white_heat", "values": [4.0, 8.0, 12.0, 16.0]}],
		"r1c9": ["Bright Sparks", 3, "Each of your Sparks has a {v}% chance to build one more Heat.",
			{"key": "fire_bright_sparks", "values": [15.0, 30.0, 45.0]}],
		"r1c10": ["Slow Cooling", 3, "Your Heat lasts {v} sec longer before it is lost.",
			{"key": "fire_slow_cooling", "values": [0.5, 1.0, 1.5]}],
		"r2c9": ["Afterglow", 3, "For {b:AFTERGLOW_TIME} sec after you use {n:quench}, your auto-attacks also deal {v}% of their damage as Fire damage.",
			{"key": "fire_afterglow", "values": [7.0, 13.0, 20.0], "requires": "quench"}],
		"r2c8": ["Spark Bite", 3, "Your Sparks deal {v}% more damage.",
			{"key": "fire_spark_bite", "values": [10.0, 20.0, 30.0]}],
		"r2c10": ["Fresh Tinder", 3, "Your melee abilities have a {v}% chance to add {b:FRESH_TINDER_SECONDS} sec to your Burning on the target they hit, up to its full duration.",
			{"key": "fire_fresh_tinder", "values": [10.0, 20.0, 30.0]}],
		"r3c8": ["Hard Quench", 3, "Your abilities that spend Heat deal {v}% more damage for each Heat they spend.",
			{"key": "fire_hard_quench", "values": [1.0, 2.0, 3.0]}],
		"r3c9": ["Wide Flare", 2, "{n:flare} sweeps {v} degrees wider.",
			{"key": "fire_wide_flare", "values": [30.0, 60.0], "requires": "flare"}],
		"r3c10": ["Banked Fire", 3, "{n:quench} leaves you {v} Heat.",
			{"key": "fire_banked_fire", "values": [1.0, 2.0, 3.0], "requires": "quench"}],
		"r4c9": ["Hammer Rhythm", 3, "Your auto-attacks give you {v} more Fury.",
			{"key": "fire_hammer_rhythm", "values": [1.0, 2.0, 3.0]}],
		"r5c9": ["Fold Again", 2, "{n:foldsteel} strikes {v} more times.",
			{"key": "fire_fold_again", "values": [1.0, 2.0], "requires": "foldsteel"}],
		"r6c8": ["Deep Sear", 3, "Your Burning deals {v}% more damage.",
			{"key": "fire_deep_sear", "values": [5.0, 10.0, 15.0]}],
		"r6c10": ["Overheat", 3, "While your Heat is in the White band, each of your Sparks also burns every other enemy within {b:OVERHEAT_RADIUS} m for {v}% of its damage.",
			{"key": "fire_overheat", "values": [20.0, 40.0, 60.0]}],
		"r7c8": ["Steady Arm", 3, "While your Heat is in the Orange or White band, the cooldowns of your melee abilities recover {v}% faster.",
			{"key": "fire_steady_arm", "values": [5.0, 10.0, 15.0]}],
		"r7c10": ["Long Blast", 2, "{n:blastfurnace} lasts {v} sec longer.",
			{"key": "fire_long_blast", "values": [2.0, 4.0], "requires": "blastfurnace"}],
		"r8c8": ["Cold Steel", 3, "While you hold no Heat, your melee critical strikes deal {v}% more damage and build {v2} Heat.",
			{"key": "fire_cold_steel", "values": [10.0, 20.0, 30.0], "values2": [1.0, 2.0, 3.0]}],
		"r8c10": ["Quick Forge", 3, "Each of your Sparks takes {v} sec off the cooldowns of your Fire abilities.",
			{"key": "fire_quick_forge", "values": [0.2, 0.4, 0.6]}],
		"r9c9": ["Fed Furnace", 3, "Your abilities that spend Heat give you {v} Fury.",
			{"key": "fire_fed_furnace", "values": [5.0, 10.0, 15.0]}],
		"r10c9": ["Molten Edge", 5, "Each Heat makes your abilities deal {v}% more Fire damage, instead of {b:HEAT_DAMAGE_PCT}%.",
			{"key": "fire_molten_edge", "values": [0.2, 0.4, 0.6, 0.8, 1.0]}],
		# --- Pitch and Cinder.
		"r1c12": ["Sticky Pitch", 4, "Each layer of your Pitch makes your burns tick {v}% faster on top of the usual {b:PITCH_LAYER_SPEED_PCT}%.",
			{"key": "fire_sticky_pitch", "values": [0.5, 1.0, 1.5, 2.0]}],
		"r2c11": ["Easy Draw", 3, "Your arrows that cost Energy cost {v} less.",
			{"key": "fire_light_string", "values": [2.0, 4.0, 6.0]}],
		"r2c12": ["Big Flash", 3, "Your Ignites deal {v}% more damage.",
			{"key": "fire_big_flash", "values": [10.0, 20.0, 30.0]}],
		"r2c13": ["Long Coat", 3, "Your Pitch lasts {v} sec longer.",
			{"key": "fire_long_coat", "values": [3.0, 6.0, 9.0]}],
		"r3c11": ["Spreading Fire", 2, "Your Ignites reach {v} m further.",
			{"key": "fire_spreading_fire", "values": [2.0, 4.0]}],
		"r3c13": ["Dripping", 3, "Your Burning deals {v}% more damage to a target with {b:DRIPPING_LAYERS} or more layers of your Pitch.",
			{"key": "fire_dripping", "values": [5.0, 10.0, 15.0]}],
		"r3c12": ["Double Coat", 2, "{n:pitcharrow} adds {v} more layers of Pitch.",
			{"key": "fire_double_coat", "values": [1.0, 2.0], "requires": "pitcharrow"}],
		"r4c12": ["Hot Shafts", 3, "Your auto-shots on a target with your Pitch also deal {v}% of their damage as Fire damage.",
			{"key": "fire_hot_shafts", "values": [3.0, 6.0, 9.0]}],
		"r5c12": ["Second Light", 3, "{n:touchoff} has a {v}% chance not to go on cooldown.",
			{"key": "fire_second_light", "values": [10.0, 20.0, 30.0], "requires": "touchoff"}],
		"r6c12": ["Ember Bed", 3, "Each enemy your Ignite hits has a {v}% chance to be left with a layer of your Pitch.",
			{"key": "fire_ember_bed", "values": [33.0, 66.0, 100.0]}],
		"r7c13": ["Wide Rain", 2, "{n:cinderrain} covers an area {v} m wider.",
			{"key": "fire_wide_rain", "values": [1.0, 2.0], "requires": "cinderrain"}],
		"r7c11": ["Fuel Run", 3, "Each of your Ignites gives you {v} Energy.",
			{"key": "fire_fuel_run", "values": [5.0, 10.0, 15.0]}],
		"r8c11": ["Patient Fire", 3, "Your arrows deal {v}% more damage to a target with {b:PITCH_MAX_LAYERS} layers of your Pitch.",
			{"key": "fire_patient_fire", "values": [3.0, 6.0, 9.0]}],
		"r8c13": ["Kindle Pack", 3, "When your Ignite hits {b:KINDLE_PACK_HITS} or more enemies, it coats its target in {v} new layers of Pitch.",
			{"key": "fire_kindle_pack", "values": [1.0, 2.0, 3.0]}],
		"r8c12": ["Long Brush", 2, "{n:brushfire} lasts {v} sec longer.",
			{"key": "fire_long_brush", "values": [3.0, 6.0], "requires": "brushfire"}],
		"r9c11": ["Steady Bow", 3, "Each of your arrows that does not critically strike gives you {v} Energy.",
			{"key": "fire_steady_bow", "values": [1.0, 2.0, 3.0]}],
		"r9c12": ["Clean Shot", 3, "Your arrows that do not critically strike deal {v}% more damage to a target with your Pitch.",
			{"key": "fire_clean_shot", "values": [3.0, 6.0, 9.0]}],
		"r9c13": ["Fire Line", 3, "Your Burning deals {v}% more damage to targets more than {b:FIRE_LINE_RANGE} m away from you.",
			{"key": "fire_fire_line", "values": [4.0, 8.0, 12.0]}],
		"r10c12": ["Pitch Black", 5, "Each layer of your Pitch on a target makes your arrows deal {v}% more damage to it.",
			{"key": "fire_pitch_black", "values": [1.0, 2.0, 3.0, 4.0, 5.0]}],
	},
	"frost": {
		# The ribbon layout (GROUPS, 16 columns): Hard Winter (the caster) in
		# columns 1-3, Cold Comfort (the healer) in 4-6, the open talents on the spine
		# (column 7, rows 1-9), Frostbitten Steel (melee) in 8-10, Glacier Wall (the tank)
		# in 11-13 and Winter Hunt (the bow) in 14-16. Rows 1-9 hold 18 talents per spec
		# in its shape (SHAPES); row 10 its 5-rank
		# capstone, which needs Balance.CAPSTONE_GATE points in the spec. Most key off
		# the book's words (Chilled, Frozen, shatters, Ice Shard charges, Rime Shell,
		# Thawing, Frost shields, Glaze, finishers, Ice Layers, arrows, roots...).
		# Code: frost_talents.gd (the hits' bonuses and the Freeze / thaw events) and
		# each spec's component (frost_healer.gd, frost_steel.gd, frost_glacier.gd,
		# frost_bow.gd, frost_runes_talents.gd).
		# --- Hard Winter.
		"r1c2": ["Bitter Cold", 3, "You deal {v}% increased damage to targets you have Chilled.",
			{"key": "frost_chilled_dmg", "values": [2.0, 4.0, 6.0]}],
		"r2c1": ["Glass Cold", 3, "Your Frost spells deal {v}% more damage to targets you have Frozen.",
			{"key": "frost_glass_cold", "values": [3.0, 6.0, 9.0]}],
		"r2c3": ["Quickened Frost", 3, "Reduces the cast time of your {n:frostbolt} by {v} sec.",
			{"key": "frost_bolt_cast", "values": [0.1, 0.2, 0.3], "requires": "frostbolt"}],
		"r3c2": ["Frozen Instinct", 3, "When you Freeze an enemy, you have a {v}% chance to make your next Frost spell with a cast time, cast within {b:FROZEN_INSTINCT_TIME} sec, instant and free.",
			{"key": "frost_instinct", "values": [17.0, 33.0, 50.0]}],
		"r3c1": ["Deep Hoarfrost", 3, "Increases the damage of {n:hoarfrost} by {v}% and its duration by {v2} sec.",
			{"key": "frost_hoarfrost", "values": [15.0, 20.0, 25.0], "values2": [2.0, 3.0, 4.0], "requires": "hoarfrost"}],
		"r3c3": ["Brittle Rime", 3, "Your direct damage has a {v}% chance to trigger the burst of your {n:hoarfrost} on the target. {n:hoarfrost} stays on the target and still bursts when it expires.",
			{"key": "frost_hoarfrost_burst", "values": [5.0, 10.0, 15.0], "requires": "hoarfrost"}],
		"r4c1": ["Splintering Cold", 3, "All of your spells have a {v}% chance to give you an Ice Shard charge.",
			{"key": "frost_shard_proc", "values": [10.0, 15.0, 20.0]}],
		"r4c3": ["Shardstorm", 3, "Every {b:SHARDSTORM_EVERY} Ice Shards you fire grant you {v}% Haste for {b:SHARDSTORM_TIME} sec.",
			{"key": "frost_shardstorm", "values": [7.0, 9.0, 10.5], "requires": "iceshards"}],
		# (values = what is added to Coldspike's 25%.)
		"r5c1": ["Piercing Cold", 3, "{n:coldspike} deals {v+b:COLDSPIKE_FROZEN_PCT}% more damage to a target you have Frozen, instead of {b:COLDSPIKE_FROZEN_PCT}%.",
			{"key": "frost_piercing_cold", "values": [7.0, 13.0, 20.0], "requires": "coldspike"}],
		"r5c3": ["Ice Needles", 3, "Your Frost spells that critically strike have a {v}% chance to give you an Ice Shard charge.",
			{"key": "frost_ice_needles", "values": [33.0, 66.0, 100.0]}],
		"r6c1": ["Splintering", 2, "Your Ice Shards that hit a target you have Frozen or Rime Shelled splinter, hitting {v} random other enemies within {b:SPLINTER_RANGE} m for {bdmg:SPLINTER_DAMAGE} Frost damage each.",
			{"key": "frost_splinter", "values": [1.0, 2.0], "requires": "iceshards"}],
		"r6c3": ["Cold Snap", 3, "Freezing a target reduces your next global cooldown by {v} sec.",
			{"key": "frost_cold_snap", "values": [0.1, 0.2, 0.3]}],
		"r7c1": ["Snowdrift", 3, "Your Frost spells deal {v}% more damage to a target with {b:SNOWDRIFT_CROWD} or more other enemies within {b:SNOWDRIFT_RADIUS} m of it.",
			{"key": "frost_snowdrift", "values": [4.0, 8.0, 12.0]}],
		"r7c2": ["Cold Front", 3, "Your Frost spells deal {v}% more damage for each enemy you have Chilled or Frozen, up to {b:COLD_FRONT_MAX}.",
			{"key": "frost_cold_front", "values": [1.0, 2.0, 3.0]}],
		"r7c3": ["Lingering Frost", 3, "Your Chilled lasts {v} sec longer.",
			{"key": "frost_long_chill", "values": [1.0, 2.0, 3.0]}],
		"r8c1": ["Hard Freeze", 3, "Your Frozen lasts {v} sec longer.",
			{"key": "frost_hard_freeze", "values": [0.5, 1.0, 1.5]}],
		"r8c3": ["Cold Well", 3, "Freezing an enemy gives you {vmana} mana. This can happen once every {b:COLD_WELL_EVERY} sec.",
			{"key": "frost_cold_well", "values": [0.1, 0.2, 0.3]}],
		"r9c2": ["Shatterpoint", 3, "Your shatters (Rime Shell breaking, {n:shatteringwave}, {n:shatteringslam}) deal {v}% more damage.",
			{"key": "frost_shatterpoint", "values": [10.0, 20.0, 30.0],
			"capstone": "Every shatter also gives you an Ice Shard charge.",
			"capstone_requires": "iceshards"}],
		"r10c2": ["Deep Freeze", 5, "Your Frost spells and abilities have a {v}% chance to Freeze the target.",
			{"key": "frost_deep_freeze", "values": [1.0, 2.0, 3.0, 4.0, 5.0],
			"capstone": "Every {bth:DEEP_FREEZE_BLIZZARD_EVERY} Ice Shard you fire also casts a {n:blizzard} at its target at {b%:DEEP_FREEZE_BLIZZARD_MULT}% effectiveness.",
			"capstone_requires": "blizzard"}],
		# --- Cold Comfort (frost_healer.gd). Frost shields: Rime Shell, Rime Veil,
		# Rimefall and Shard Spray.
		"r1c5": ["Deep Cracks", 3, "When your {n:rimeshell} breaks on an ally, its Rime Shards heal {v}% more.",
			{"key": "frost_deep_cracks", "values": [10.0, 20.0, 30.0]}],
		"r2c4": ["Shard Spray", 3, "Your Rime Shards also leave a shield on each ally they heal, absorbing {v}% of what they healed for {b:SHARD_SPRAY_TIME} sec.",
			{"key": "frost_shard_spray", "values": [20.0, 35.0, 50.0]}],
		"r2c5": ["Slow Runoff", 3, "When your {n:rimeshell} runs out on an ally, its Runoff heals {v}% more.",
			{"key": "frost_slow_runoff", "values": [20.0, 40.0, 60.0],
			"capstone": "Each Runoff also gives you back as much mana as {n:breaktheice} costs."}],
		"r2c6": ["Thaw Water", 3, "Your heals on an ally with your Thawing heal {v}% more.",
			{"key": "frost_thaw_water", "values": [4.0, 8.0, 12.0]}],
		"r3c5": ["Last Shelter", 3, "Your Frost shields absorb {v}% more on an ally below {b:LAST_SHELTER_HEALTH}% health.",
			{"key": "frost_last_shelter", "values": [5.0, 10.0, 15.0]}],
		"r4c5": ["Cold Hands", 3, "Your Frost spells that heal or shield cost {v}% less mana.",
			{"key": "frost_cold_hands", "values": [3.0, 6.0, 9.0]}],
		"r5c4": ["Cold Spread", 3, "{n:breaktheice} heals allies up to {v} m farther away.",
			{"key": "frost_cold_spread", "values": [2.0, 4.0, 6.0], "requires": "breaktheice"}],
		"r5c6": ["Meltdown", 3, "When your {n:rimeshell} breaks, you gain {vmana} mana. This can happen once every {b:MELTDOWN_EVERY} sec.",
			{"key": "frost_meltdown", "values": [0.1, 0.2, 0.3]}],
		"r6c4": ["Long Frost", 3, "Your Rime Veil, Rimefall and Shard Spray shields last {v} sec longer.",
			{"key": "frost_long_frost", "values": [2.0, 4.0, 6.0]}],
		"r6c6": ["Shard Reach", 2, "Your Rime Shards reach allies {v} m farther away.",
			{"key": "frost_shard_reach", "values": [2.0, 4.0]}],
		"r6c5": ["Wide Lattice", 2, "{n:frostlattice} links {v} more allies.",
			{"key": "frost_wide_lattice", "values": [1.0, 2.0], "requires": "frostlattice"}],
		"r7c4": ["Snowmelt", 3, "Your Runoff heals {v}% faster, for the same total.",
			{"key": "frost_snowmelt", "values": [15.0, 30.0, 45.0]}],
		"r7c5": ["Layered Veil", 2, "{n:rimeveil} forms again {v} sec sooner.",
			{"key": "frost_layered_veil", "values": [0.5, 1.0], "requires": "rimeveil"}],
		"r7c6": ["Ice Bath", 3, "Your heals on an ally carrying one of your Frost shields heal {v}% more.",
			{"key": "frost_ice_bath", "values": [3.0, 6.0, 9.0]}],
		"r8c4": ["Deep Snow", 3, "{n:rimefall}'s shields absorb {v}% more.",
			{"key": "frost_deep_snow", "values": [10.0, 20.0, 30.0], "requires": "rimefall"}],
		"r8c6": ["Cold Rush", 3, "Your Frost spells that heal or shield cast {v} sec faster on an ally below {b:LAST_SHELTER_HEALTH}% health.",
			{"key": "frost_cold_rush", "values": [0.1, 0.2, 0.3]}],
		"r9c4": ["Close Weave", 3, "Your heals on an ally linked by your {n:frostlattice} heal {v}% more.",
			{"key": "frost_close_weave", "values": [5.0, 10.0, 15.0], "requires": "frostlattice"}],
		"r9c6": ["Splinterheal", 3, "Your shatters heal the lowest-health ally within {b:SPLINTERHEAL_RADIUS} m of the enemy for {v}% of the damage they deal.",
			{"key": "frost_splinterheal", "values": [20.0, 35.0, 50.0]}],
		"r10c5": ["Frozen Hearth", 5, "Your Frost shields absorb {v}% more and your Rime Shards heal {v}% more.",
			{"key": "frost_frozen_hearth", "values": [2.0, 4.0, 6.0, 8.0, 10.0]}],
		# --- Open talents: themed to the book (cold, shields, slows) but they work with
		# every book's spells and abilities.
		"r1c7": ["Frozen Focus", 3, "Increases your Haste by {v}%.",
			{"key": "frost_haste", "values": [0.7, 1.4, 2.1], "stats": {"haste": 0.7}}],
		"r2c7": ["Frozen Mind", 3, "Increases your Spell Power by {v}% of your Intellect.",
			{"key": "frost_int_sp", "values": [2.0, 4.0, 6.0]}],
		"r3c7": ["Rime Ward", 3, "Shields you apply absorb {v}% more damage.",
			{"key": "frost_absorb", "values": [5.0, 10.0, 15.0]}],
		"r4c7": ["Hardened Frost", 4, "Your absorb shields increase the armor of whoever they protect (you or an ally) by {v}% for their duration.",
			{"key": "frost_shield_armor", "values": [2.0, 4.0, 6.0, 8.0]}],
		"r5c7": ["Ice Floe", 2, "When an absorb shield you put on yourself breaks, you gain {v}% move speed for {b:ICE_FLOE_TIME} sec and the enemy that broke it is Chilled.",
			{"key": "frost_ice_floe", "values": [10.0, 20.0]}],
		"r6c7": ["Numbing Cold", 3, "You take {v}% less damage from enemies you slowed in the last {b:SLOW_MEMORY} sec.",
			{"key": "frost_slow_dr", "values": [2.0, 4.0, 6.0]}],
		"r7c7": ["Glacial Heart", 3, "Slows on you are {v}% weaker.",
			{"key": "frost_glacial_heart", "values": [5.0, 10.0, 15.0],
			"capstone": "You gain {b:GLACIAL_HEART_HASTE}% Haste for every slow you have on an enemy, per target and per slow (Chilled and Frozen count separately)."}],
		"r8c7": ["Cold Discipline", 3, "Reduces the mana cost of your spells by {v}% and the threat generated by your Frost spells by {v2}%.",
			{"key": "frost_discipline", "values": [2.0, 3.0, 4.0], "values2": [5.0, 10.0, 15.0]}],
		"r9c7": ["Winter Coat", 3, "You take {v}% less damage from spells.",
			{"key": "frost_winter_coat", "values": [1.0, 2.0, 3.0]}],
		# --- Frostbitten Steel (frost_steel.gd). Finishers: Calving and Icebreaker.
		"r1c9": ["Sharp Glaze", 3, "Your Frost abilities deal {v}% more damage for each Glaze you hold.",
			{"key": "frost_sharp_glaze", "values": [1.0, 2.0, 3.0]}],
		"r2c8": ["Third Bite", 3, "Your Frost abilities that Freeze their target deal {v}% more damage.",
			{"key": "frost_third_bite", "values": [20.0, 40.0, 60.0]}],
		"r2c9": ["Long Glaze", 3, "Your Glaze lasts {v} sec longer.",
			{"key": "frost_long_glaze", "values": [2.0, 4.0, 6.0]}],
		"r2c10": ["Glaze Hunger", 3, "When you gain Glaze, you have a {v}% chance to gain one more.",
			{"key": "frost_glaze_hunger", "values": [10.0, 20.0, 30.0]}],
		"r3c8": ["Cold Sweep", 3, "When {n:hoarcleave} hits an enemy you had already Chilled, it has a {v}% chance to Freeze it instead of Chilling it.",
			{"key": "frost_cold_sweep", "values": [10.0, 20.0, 30.0], "requires": "hoarcleave"}],
		"r3c10": ["Hard Glaze", 3, "Each Glaze your finishers spend gives you {v} Fury.",
			{"key": "frost_hard_glaze", "values": [2.0, 4.0, 6.0]}],
		# (values = what is added to Rime Edge's own damage.)
		"r4c8": ["Honed Rime", 3, "The extra hit of your {n:rimeedge} deals {v+dmg:rimeedge} Frost damage, instead of {dmg:rimeedge}.",
			{"key": "frost_honed_rime", "values": [0.05, 0.1, 0.15], "requires": "rimeedge"}],
		"r4c10": ["Clean Break", 3, "Your finishers give you {v} Fury back when they hit a target you have Frozen.",
			{"key": "frost_clean_break", "values": [7.0, 13.0, 20.0]}],
		"r5c8": ["Ice Fall", 3, "{n:calving} deals {v}% more damage to its target for each other enemy it hits, up to {b:ICE_FALL_MAX_OTHERS}.",
			{"key": "frost_ice_fall", "values": [4.0, 8.0, 12.0], "requires": "calving"}],
		"r5c10": ["Splitting Cold", 3, "Your finishers deal {v}% more damage to a target you have Frozen.",
			{"key": "frost_splitting_cold", "values": [4.0, 8.0, 12.0]}],
		# (values = Glaze added to Bitter Edge's own.)
		"r6c8": ["Biting Hold", 2, "{n:bitteredge} gives you {v} more Glaze.",
			{"key": "frost_biting_hold", "values": [1.0, 2.0], "requires": "bitteredge"}],
		"r6c10": ["Shiver", 3, "Your critical strikes on a target you have Frozen have a {v}% chance to give you a Glaze. This can happen once every {b:SHIVER_EVERY} sec.",
			{"key": "frost_shiver", "values": [33.0, 66.0, 100.0]}],
		"r7c8": ["Rime Grip", 3, "Your auto-attacks on a target you have Chilled give you {v} more Fury.",
			{"key": "frost_rime_grip", "values": [1.0, 2.0, 3.0]}],
		"r7c10": ["Cold Swing", 3, "Your melee abilities that hit {b:COLD_SWING_HITS} or more enemies give you {v} Fury.",
			{"key": "frost_cold_swing", "values": [3.0, 6.0, 9.0]}],
		"r8c9": ["Long Dark", 3, "{n:blackfrost} lasts {v} sec longer.",
			{"key": "frost_long_dark", "values": [1.5, 2.5, 4.0], "requires": "blackfrost"}],
		"r8c8": ["Thaw Strike", 3, "When a target you have Frozen thaws, your next finisher within {b:THAW_STRIKE_TIME} sec costs {v} less Fury.",
			{"key": "frost_thaw_strike", "values": [5.0, 10.0, 15.0]}],
		"r8c10": ["Quick Rime", 3, "Each Glaze you hold gives you {v}% attack speed.",
			{"key": "frost_quick_rime", "values": [0.3, 0.6, 0.9]}],
		"r9c9": ["Frost Heave", 3, "A finisher that spends {b:GLAZE_MAX} Glaze has a {v}% chance to Freeze its target.",
			{"key": "frost_frost_heave", "values": [33.0, 66.0, 100.0]}],
		"r10c9": ["Glinting Rime", 5, "Each Glaze you hold gives your Frost abilities {v}% more critical strike chance.",
			{"key": "frost_glinting_rime", "values": [0.2, 0.4, 0.6, 0.8, 1.0],
			"capstone": "An {n:icebreaker} that spends {b:GLAZE_MAX} Glaze always critically strikes.",
			"capstone_requires": "icebreaker"}],
		# --- Glacier Wall (frost_glacier.gd).
		"r1c12": ["Packed Ice", 3, "Each Ice Layer {n:shatteringslam} shatters into its target deals {v}% more damage.",
			{"key": "frost_packed_ice", "values": [13.0, 27.0, 40.0], "requires": "shatteringslam"}],
		"r2c12": ["Cold Fury", 3, "Each of your Ice Layers that breaks gives you {v} more Fury.",
			{"key": "frost_cold_fury", "values": [2.0, 4.0, 6.0]}],
		"r3c11": ["Lasting Ice", 3, "Your Ice Layers last {v} sec longer.",
			{"key": "frost_lasting_ice", "values": [3.0, 6.0, 9.0]}],
		"r3c13": ["Deep Ice", 2, "You can hold {v} more Ice Layers.",
			{"key": "frost_deep_ice", "values": [1.0, 2.0]}],
		# (values = what is added to Rimequake's own % per Layer.)
		"r4c11": ["Deep Tremor", 3, "{n:rimequake} deals {v+b:RIMEQUAKE_PCT_PER_LAYER}% more damage for each Ice Layer you have, instead of {b:RIMEQUAKE_PCT_PER_LAYER}%.",
			{"key": "frost_deep_tremor", "values": [3.0, 7.0, 10.0], "requires": "rimequake"}],
		"r4c13": ["Spent Ice", 3, "Each Ice Layer you shatter into a target gives you {v} Fury.",
			{"key": "frost_spent_ice", "values": [2.0, 4.0, 6.0]}],
		"r5c11": ["Hoar Coat", 3, "Each Ice Layer you gain heals you for {v}% of your maximum health.",
			{"key": "frost_hoar_coat", "values": [0.3, 0.6, 1.0]}],
		"r5c13": ["Cold Retort", 3, "Each of your Ice Layers that breaks deals {vdmg:shatteringslam} Frost damage to the attacker.",
			{"key": "frost_cold_retort", "values": [0.05, 0.1, 0.15]}],
		"r6c11": ["Turned Backs", 2, "{n:coldshoulder} also makes the {v} enemies nearest its target attack you and Chills them.",
			{"key": "frost_turned_backs", "values": [1.0, 2.0], "requires": "coldshoulder"}],
		"r6c12": ["Rime Pressure", 3, "Your spells and abilities generate {v}% more threat for each Ice Layer you hold.",
			{"key": "frost_rime_pressure", "values": [1.0, 2.0, 3.0]}],
		"r6c13": ["Regelation", 3, "Each Ice Layer that forms again during {n:hardrime} gives you {v} Fury.",
			{"key": "frost_regelation", "values": [3.0, 7.0, 10.0], "requires": "hardrime"}],
		"r7c11": ["Reforming", 3, "Each of your Ice Layers that breaks has a {v}% chance to form again at once.",
			{"key": "frost_reforming", "values": [5.0, 10.0, 15.0]}],
		"r7c12": ["Cracking Ice", 3, "Each of your Ice Layers that breaks takes {v} sec off the cooldowns of your Frost abilities.",
			{"key": "frost_cracking_ice", "values": [0.1, 0.2, 0.3]}],
		"r7c13": ["Steady Footing", 3, "While you hold {b:STEADY_FOOTING_LAYERS} or more Ice Layers, you take {v}% less damage.",
			{"key": "frost_steady_footing", "values": [2.0, 4.0, 6.0]}],
		"r8c12": ["Old Ice", 3, "{n:glacialbulwark} lasts {v} sec longer.",
			{"key": "frost_old_ice", "values": [1.5, 2.5, 4.0], "requires": "glacialbulwark"}],
		"r8c11": ["Rime Armor", 3, "Each Ice Layer you hold increases your Armor by {v}%.",
			{"key": "frost_rime_armor", "values": [1.0, 2.0, 3.0]}],
		"r8c13": ["Chilling Presence", 3, "You generate {v}% more threat against enemies you slowed in the last {b:SLOW_MEMORY} sec.",
			{"key": "frost_slow_threat", "values": [5.0, 10.0, 15.0]}],
		"r9c12": ["Full Strata", 3, "While you hold all the Ice Layers you can, your abilities deal {v}% more damage.",
			{"key": "frost_full_strata", "values": [5.0, 10.0, 15.0]}],
		"r10c12": ["Deep Strata", 5, "Your Ice Layers absorb {v}% more damage.",
			{"key": "frost_deep_strata", "values": [2.0, 4.0, 6.0, 8.0, 10.0],
			"capstone": "When your last Ice Layer breaks, you gain one back at once. This can happen once every {b:DEEP_STRATA_COOLDOWN} sec."}],
		# --- Winter Hunt (frost_bow.gd). Arrows: arrow abilities and auto-shots.
		"r1c14": ["Cold Draw", 3, "Your hits on a target you have Chilled or Frozen give you {v} Energy, {v} Fury and {v2mana} mana. This can happen once every {b:COLD_DRAW_EVERY} sec.",
			{"key": "frost_cold_draw", "values": [2.0, 4.0, 6.0], "values2": [0.1, 0.2, 0.3]}],
		"r1c16": ["Frozen Quarry", 3, "Your arrows deal {v}% more damage to targets you have Frozen.",
			{"key": "frost_frozen_quarry", "values": [4.0, 8.0, 12.0]}],
		"r2c14": ["Pinning Frost", 3, "Your arrows deal {v}% more damage to targets you have rooted.",
			{"key": "frost_pinning_frost", "values": [5.0, 10.0, 15.0]}],
		"r2c15": ["Black Ice", 3, "The first Chill the ice of your {n:icyretreat} puts on each enemy has a {v}% chance to be a Freeze instead.",
			{"key": "frost_black_ice", "values": [33.0, 67.0, 100.0], "requires": "icyretreat"}],
		"r2c16": ["Clean Shatter", 3, "When {n:shattershot} breaks your Freeze, it refunds {v} Energy and takes {v2} sec off its own cooldown.",
			{"key": "frost_clean_shatter", "values": [7.0, 13.0, 20.0], "values2": [1.5, 2.5, 4.0], "requires": "shattershot"}],
		"r3c14": ["Frost Fletching", 3, "Your auto-shots deal {v}% more damage to targets you have Chilled.",
			{"key": "frost_frost_fletching", "values": [3.0, 6.0, 9.0]}],
		"r3c15": ["Cold Harvest", 3, "Each shot of your {n:rimefletch} that Freezes its target gives you {v} Energy.",
			{"key": "frost_cold_harvest", "values": [3.0, 7.0, 10.0], "requires": "rimefletch"}],
		"r3c16": ["Rime Tips", 3, "Your auto-shots have a {v}% chance to Chill their target.",
			{"key": "frost_rime_tips", "values": [5.0, 10.0, 15.0]}],
		"r4c15": ["Thin Ice", 3, "{n:glacialdraw} casts {v} sec faster on a target you have Chilled.",
			{"key": "frost_thin_ice", "values": [0.3, 0.7, 1.0], "requires": "glacialdraw"}],
		"r5c15": ["Marked Ice", 3, "Your arrow abilities that hit a target you have Chilled have a {v}% chance to give you an Ice Shard charge.",
			{"key": "frost_marked_ice", "values": [10.0, 20.0, 30.0]}],
		"r6c15": ["Winter Quiver", 3, "Your arrow abilities that critically strike give you {v} Energy.",
			{"key": "frost_winter_quiver", "values": [4.0, 8.0, 12.0]}],
		"r7c14": ["Splitting Arrow", 3, "Your arrows that hit a target you have Frozen splinter into one other enemy within {b:SPLITTING_ARROW_RANGE} m, dealing {v}% of their damage as Frost damage.",
			{"key": "frost_splitting_arrow", "values": [10.0, 20.0, 30.0]}],
		"r7c15": ["Deep Pin", 3, "Your roots last {v} sec longer.",
			{"key": "frost_deep_pin", "values": [1.0, 2.0, 3.0]}],
		"r7c16": ["Numb Prey", 3, "Your auto-shots deal {v}% more damage to targets you have Frozen.",
			{"key": "frost_numb_prey", "values": [3.0, 6.0, 9.0]}],
		"r8c14": ["Swift Ice", 3, "Your auto-shots and auto-attacks are {v}% faster against a target you have Chilled.",
			{"key": "frost_swift_ice", "values": [2.0, 4.0, 6.0]}],
		"r8c15": ["Ice Hunger", 3, "Freezing an enemy gives you {v} Energy.",
			{"key": "frost_ice_hunger", "values": [5.0, 10.0, 15.0]}],
		"r8c16": ["Cold Eye", 3, "Your arrows that critically strike a target you have Frozen deal {v}% more damage.",
			{"key": "frost_cold_eye", "values": [5.0, 10.0, 15.0]}],
		"r9c15": ["Sleet Arrows", 2, "Your arrow abilities that Chill their target also Chill the {v} enemies nearest it, within {b:SLEET_ARROWS_RANGE} m.",
			{"key": "frost_sleet_arrows", "values": [1.0, 2.0]}],
		"r10c15": ["Bitter Hunt", 5, "Your arrows deal {v}% more damage for each of your slows on the target (Chilled, Frozen and rooted each count).",
			{"key": "frost_bitter_hunt", "values": [1.0, 2.0, 3.0, 4.0, 5.0]}],
	},
	"lightning": {
		# The ribbon layout (GROUPS, 13 columns): Live Current (the caster) in columns
		# 1-3, Stormdancer (melee) in 4-6, the open talents on the spine (column 7),
		# Lightning Rod (the parry tank) in 8-10 and Stormstring (the bow, unfinished: a
		# short ribbon of its Storm Arrow talents, no shape or capstone yet) in 11-13.
		# Rows 1-9 hold 18 talents per finished spec in its shape (SHAPES); row 10 its
		# 5-rank capstone, which needs Balance.CAPSTONE_GATE points in the spec. Most key
		# off the book's words (Energy gained and spent, spending all of it, leaps, the
		# lingering lightning, auto-attacks, weapon abilities, parries, arcs...).
		# Code: lightning_talents.gd (the hits' bonuses, Energy spent and gained, parries)
		# and each spec's component (lightning_caster.gd, lightning_bottled.gd,
		# lightning_melee.gd, lightning_tank.gd, lightning_bow.gd).
		# --- Live Current.
		"r1c1": ["Long Leap", 3, "Your Lightning spells' leaps and forks (the leaps of {n:chainlightning}, the second prong of {n:forkedbolt}) deal {v}% more damage.",
			{"key": "lightning_long_leap", "values": [6.0, 12.0, 18.0]}],
		"r1c3": ["Charged Air", 2, "Each Lightning spell with a cast time gives you {v} Energy when you finish casting it.",
			{"key": "lightning_charged_air", "values": [1.0, 2.0]}],
		# Quick Fuse: Abilities.base_cast_time and Player._begin_spell; Tight Coil: ball_lightning_zapped.
		"r2c1": ["Quick Fuse", 3, "{n:lightningbolt} casts {v} sec faster.",
			{"key": "lightning_quick_fuse", "values": [0.1, 0.15, 0.2], "requires": "lightningbolt"}],
		"r2c2": ["Deep Reserves", 3, "Increases your maximum Energy by {v}.",
			{"key": "lightning_deep_reserves", "values": [7.0, 13.0, 20.0]}],
		"r2c3": ["Tight Coil", 2, "Each zap of your {n:balllightning} gives you {v} more Energy.",
			{"key": "lightning_tight_coil", "values": [1.0, 2.0], "requires": "balllightning"}],
		"r3c1": ["Feedback", 3, "Your Lightning spells that give you Energy give you {v}% more.",
			{"key": "lightning_feedback", "values": [10.0, 20.0, 30.0]}],
		"r3c2": ["Lingering Storm", 2, "Your {n:balllightning} and {n:thunderhead} last {v} sec longer.",
			{"key": "lightning_lingering_storm", "values": [1.5, 3.0]}],
		"r3c3": ["Crackle", 3, "Your {n:balllightning}, {n:thunderhead} and {n:livewire} deal {v}% more damage.",
			{"key": "lightning_crackle", "values": [4.0, 8.0, 12.0]}],
		# Conductive: Player.adjust_crit. Conductor: lightning_caster._conductor.
		"r4c1": ["Conductive", 3, "Increases the critical strike chance of your Lightning damage by {v}%.",
			{"key": "lightning_conductive", "values": [1.0, 2.0, 3.0]}],
		"r4c2": ["High Voltage", 3, "While you have more than {b:HIGH_VOLTAGE_ENERGY} Energy, your Lightning damage is increased by {v}%.",
			{"key": "lightning_high_voltage", "values": [4.0, 7.0, 10.0]}],
		"r4c3": ["Deep Draw", 3, "Your abilities that spend all your Energy count {v}% more Energy than they spent.",
			{"key": "lightning_deep_draw", "values": [5.0, 10.0, 15.0]}],
		"r5c2": ["Standing Charge", 3, "Each second you stay planted in {n:groundingsurge} increases your Lightning damage by {v}%, stacking up to {b:STANDING_CHARGE_MAX_STACKS} times. The stacks are lost when it ends.",
			{"key": "lightning_standing_charge", "values": [2.0, 4.0, 6.0], "requires": "groundingsurge"}],
		"r6c1": ["Conductor", 3, "Your critical strikes with Lightning spells and abilities give you {v} Energy. Their arcs, zaps and periodic damage do not count, and one that hits several enemies counts once.",
			{"key": "lightning_conductor", "values": [4.0, 7.0, 10.0]}],
		"r6c3": ["Afterflow", 3, "After you spend all your Energy, your Energy regenerates {v}% faster for {b:AFTERFLOW_TIME} sec.",
			{"key": "lightning_afterflow", "values": [20.0, 40.0, 60.0]}],
		"r7c2": ["Overflow", 3, "When you take your Energy back from {n:capacitor}, the Energy that doesn't fit in your bar becomes a shield on you for {b:OVERFLOW_TIME} sec, absorbing {vdmg:capacitor} damage per {b:ENERGY_STEP} Energy.",
			{"key": "lightning_overflow", "values": [0.07, 0.13, 0.2], "requires": "capacitor"}],
		"r8c1": ["Parting Spark", 3, "{n:flicker} zaps every enemy within {b:PARTING_SPARK_RADIUS} m of the spot you left for {vdmg:flicker} Lightning damage.",
			{"key": "lightning_parting_spark", "values": [0.25, 0.55, 0.8], "requires": "flicker"}],
		"r8c3": ["Snap Cast", 2, "Your Lightning spells that critically strike have a {v}% chance to make your next {n:lightningbolt} within {b:SNAP_CAST_TIME} sec instant.",
			{"key": "lightning_snap_cast", "values": [15.0, 30.0]}],
		"r9c2": ["Full Circuit", 3, "When your Energy reaches full, your next Lightning spell within {b:FULL_CIRCUIT_TIME} sec deals {v}% more damage.",
			{"key": "lightning_full_circuit", "values": [8.0, 16.0, 24.0]}],
		# Storm Cycle: lightning_bottled._storm_cycle_spent.
		"r10c2": ["Storm Cycle", 5, "Every {v} Energy you spend makes your next Energy cost free (kept for up to {b:STORM_CYCLE_TIME} sec). Abilities that spend all your Energy are counted, but are never the free one.",
			{"key": "lightning_storm_cycle", "values": [200.0, 180.0, 160.0, 140.0, 120.0]}],
		# --- Stormdancer. "Lightning weapon abilities": Lightning abilities that swing a
		# weapon (LightningTalentsKit.weapon_ability).
		"r1c4": ["Charged Strikes", 3, "Your auto-attacks give you {v} Energy.",
			{"key": "lightning_charged_strikes", "values": [1.0, 2.0, 3.0]}],
		"r1c6": ["Quick Charge", 3, "Your Energy regenerates {v}% faster.",
			{"key": "lightning_quick_charge", "values": [5.0, 10.0, 15.0]}],
		"r2c4": ["Keen Current", 2, "Increases the critical strike chance of your auto-attacks by {v}%.",
			{"key": "lightning_keen_current", "values": [1.5, 3.0]}],
		"r2c6": ["Edge Current", 3, "Your Lightning weapon abilities that give you Energy give you {v} more.",
			{"key": "lightning_edge_current", "values": [2.0, 4.0, 6.0]}],
		"r3c4": ["Whip Crack", 3, "Hitting a target more than {b:WHIP_CRACK_DISTANCE} m away with {n:whiplash} resets the cooldown of {n:staticstep} and makes your next {n:staticstep} within {b:WHIP_CRACK_TIME} sec cost {v} less Energy.",
			{"key": "lightning_whip_crack", "values": [7.0, 13.0, 20.0], "requires": "whiplash"}],
		"r3c5": ["Third Beat", 3, "The third strike of {n:cadence} deals {v}% more damage.",
			{"key": "lightning_third_beat", "values": [10.0, 20.0, 30.0], "requires": "cadence",
			"capstone": "The third strike also gives you {b:THIRD_BEAT_ENERGY} Energy."}],
		"r3c6": ["Running Start", 3, "{n:staticstep} gives you {v} Energy when it carries you at least {b:RUNNING_START_DISTANCE} m.",
			{"key": "lightning_running_start", "values": [7.0, 13.0, 20.0], "requires": "staticstep"}],
		"r4c4": ["Sparking Swings", 3, "Your auto-attacks have a {v}% chance to zap the target for {bdmg:SPARKING_SWINGS_DAMAGE} Lightning damage.",
			{"key": "lightning_sparking_swings", "values": [5.0, 10.0, 15.0]}],
		"r4c6": ["Running on Empty", 3, "While you have less than {b:RUNNING_ON_EMPTY_ENERGY} Energy, your Lightning spells and abilities deal {v}% more damage.",
			{"key": "lightning_running_on_empty", "values": [3.0, 6.0, 9.0]}],
		"r5c4": ["Afterspark", 3, "Each Lightning ability that spends Energy makes your next auto-attack within {b:AFTERSPARK_TIME} sec deal {v}% more damage.",
			{"key": "lightning_afterspark", "values": [10.0, 20.0, 30.0]}],
		"r5c6": ["Built Charge", 3, "Every {b:BUILT_CHARGE_EVERY} Energy you spend makes your next Lightning weapon ability within {b:BUILT_CHARGE_TIME} sec deal {v}% more damage.",
			{"key": "lightning_built_charge", "values": [15.0, 30.0, 45.0]}],
		"r6c5": ["Redline", 3, "Every ability that spends Energy while {n:overdrive} is active makes it last {v} sec longer, up to {b:REDLINE_MAX} sec more in total.",
			{"key": "lightning_redline", "values": [0.3, 0.7, 1.0], "requires": "overdrive"}],
		"r7c4": ["Light Load", 2, "While you have less than {b:LIGHT_LOAD_ENERGY} Energy, your auto-attacks are {v}% faster.",
			{"key": "lightning_light_load", "values": [5.0, 10.0]}],
		"r7c6": ["Spinning Up", 3, "Every {b:SPINNING_UP_EVERY} Energy you spend takes {v} sec off the cooldowns of your Lightning weapon abilities.",
			{"key": "lightning_spinning_up", "values": [0.2, 0.4, 0.6]}],
		"r8c4": ["Hot Wire", 3, "Each echo of {n:twincurrent} has a {v}% chance not to use up a charge.",
			{"key": "lightning_hot_wire", "values": [17.0, 33.0, 50.0], "requires": "twincurrent"}],
		"r8c6": ["Charged Steel", 3, "Critical strikes of your Lightning weapon abilities deal {v}% more damage.",
			{"key": "lightning_charged_steel", "values": [5.0, 10.0, 15.0]}],
		"r9c4": ["Short Fuse", 2, "Your Lightning weapon abilities trigger a global cooldown {v} sec shorter.",
			{"key": "lightning_short_fuse", "values": [0.05, 0.1]}],
		"r9c6": ["Calm Current", 3, "Your Lightning spells and abilities generate {v}% less threat.",
			{"key": "lightning_calm_current", "values": [5.0, 10.0, 15.0]}],
		"r10c5": ["Storm Dance", 5, "Your Lightning weapon abilities deal {v}% more damage.",
			{"key": "lightning_storm_dance", "values": [2.0, 4.0, 6.0, 8.0, 10.0],
			"capstone": "Each zap of your {n:overdrive} also hits one other enemy within {b:STORM_DANCE_REACH} m of the target.",
			"capstone_requires": "overdrive"}],
		# --- Open talents: themed to the book (speed, tempo, standing your ground,
		# moving) but they work with every book's spells and abilities
		# (open_talents_fire_lightning.gd).
		"r1c7": ["Quick Pulse", 3, "Increases your Haste by {v}%.",
			{"key": "lightning_live_current", "values": [1.0, 2.0, 3.0], "stats": {"haste": 1.0}}],
		"r2c7": ["Change of Pace", 3, "Using a different spell or ability than the last one you used increases your damage by {v}% for {b:CHANGE_OF_PACE_TIME} sec, stacking up to {b:CHANGE_OF_PACE_STACKS} times. Using the same one twice in a row ends it.",
			{"key": "lightning_change_of_pace", "values": [1.0, 2.0, 3.0]}],
		"r3c7": ["Storm-Tempered", 3, "Increases your Attack Power by {v}% of your Agility.",
			{"key": "lightning_storm_tempered", "values": [2.0, 4.0, 6.0]}],
		"r4c7": ["Spillover", 3, "When one of your direct hits critically strikes, {v}% of its damage jumps to another enemy within {b:SPILLOVER_RADIUS} m.",
			{"key": "lightning_spillover", "values": [5.0, 10.0, 15.0]}],
		"r5c7": ["Quick Step", 3, "Increases your Dodge chance by {v}%.",
			{"key": "lightning_quick_step", "values": [1.0, 2.0, 3.0], "stats": {"dodge": 1.0}}],
		"r6c7": ["Dig In", 3, "After you stand still for {b:DIG_IN_TIME} sec, you deal {v}% more damage until you move.",
			{"key": "lightning_dig_in", "values": [2.0, 4.0, 6.0]}],
		"r7c7": ["Cut the Line", 3, "Using an interrupt gives you {v}% Haste for {b:CUT_THE_LINE_TIME} sec.",
			{"key": "lightning_cut_the_line", "values": [3.0, 6.0, 9.0]}],
		"r8c7": ["Fresh Charge", 3, "While you are above {b:FRESH_CHARGE_HEALTH}% health, your spells and abilities deal {v}% more damage.",
			{"key": "lightning_fresh_charge", "values": [2.0, 4.0, 6.0]}],
		"r9c7": ["Static Build", 3, "Every {b:STATIC_BUILD_STEP} m you move gives you a stack, up to {b:STATIC_BUILD_STACKS}. Your next spell or ability uses them all and deals {v}% more damage per stack.",
			{"key": "lightning_static_build", "values": [2.0, 4.0, 6.0]}],
		# --- Lightning Rod (the parry tank; lightning_tank.gd).
		"r1c9": ["Long Reach", 3, "Increases your Parry chance by {v}% while you wield a two-handed weapon.",
			{"key": "lightning_long_reach", "values": [1.0, 2.0, 3.0]}],
		"r2c8": ["Spark Guard", 3, "Each attack you parry zaps the attacker for {vdmg:stormshield} Lightning damage with {b:SPARK_GUARD_THREAT}x threat.",
			{"key": "lightning_spark_guard", "values": [0.1, 0.2, 0.3]}],
		"r2c9": ["Closed Circuit", 3, "Attacks you parry while {n:thunderaegis} is active give you {v} more Energy.",
			{"key": "lightning_closed_circuit", "values": [2.0, 4.0, 6.0], "requires": "thunderaegis"}],
		"r2c10": ["Loud Steel", 2, "While you wield a two-handed weapon, your Lightning spells and abilities generate {v}% more threat.",
			{"key": "lightning_loud_steel", "values": [8.0, 16.0]}],
		"r3c9": ["Quick Wrists", 3, "Each attack you parry takes {v} sec off the cooldown of {n:crossguard}.",
			{"key": "lightning_quick_wrists", "values": [0.3, 0.7, 1.0], "requires": "crossguard"}],
		"r4c8": ["Counter-Charge", 3, "{n:returnstroke} deals {v}% more damage.",
			{"key": "lightning_counter_charge", "values": [10.0, 20.0, 30.0], "requires": "returnstroke",
			"capstone": "It also arcs to up to {b:COUNTER_CHARGE_JUMPS} nearby enemies, dealing {bdmg:COUNTER_CHARGE_ARC} Lightning damage to each."}],
		"r4c9": ["Charged Guard", 3, "Each attack you parry makes the next hit you take within {b:CHARGED_GUARD_TIME} sec deal {v}% less damage.",
			{"key": "lightning_charged_guard", "values": [4.0, 8.0, 12.0]}],
		"r4c10": ["Earth Return", 3, "Each attack you parry heals you for {v}% of your maximum health.",
			{"key": "lightning_earth_return", "values": [0.3, 0.7, 1.0]}],
		"r5c9": ["Draw Down", 3, "Every {b:ENERGY_STEP} Energy you spend heals you for {v}% of your maximum health.",
			{"key": "lightning_draw_down", "values": [0.1, 0.2, 0.3]}],
		"r6c9": ["Ring True", 3, "Your Lightning hits on every enemy around you ({n:shockring}, {n:arccleave}, {n:arcflash} and the third strike of {n:cadence}) deal {v}% more damage and threat.",
			{"key": "lightning_ring_true", "values": [5.0, 10.0, 15.0]}],
		"r7c8": ["Second Stroke", 3, "{n:returnstroke} has a {v}% chance not to close its window, so you can answer the same parry twice.",
			{"key": "lightning_second_stroke", "values": [10.0, 20.0, 30.0], "requires": "returnstroke"}],
		"r7c10": ["Tempo", 3, "Each attack you parry increases your attack speed by {v}% for {b:TEMPO_TIME} sec, stacking up to {b:TEMPO_MAX_STACKS} times.",
			{"key": "lightning_tempo", "values": [2.0, 4.0, 6.0]}],
		"r8c8": ["Hard Lessons", 3, "Each hit you take that you don't dodge, parry or block gives you {v} Energy.",
			{"key": "lightning_hard_lessons", "values": [1.0, 2.0, 3.0]}],
		"r8c9": ["Wide Current", 3, "Your Lightning arcs (the arcs of {n:stormshield}, and of Counter-Charge) deal {v}% more damage and threat.",
			{"key": "lightning_wide_current", "values": [10.0, 20.0, 30.0]}],
		"r8c10": ["Charged Shell", 3, "While you have more than {b:CHARGED_SHELL_ENERGY} Energy, you take {v}% less damage.",
			{"key": "lightning_charged_shell", "values": [2.0, 4.0, 6.0]}],
		"r9c8": ["Hard Stare", 2, "Enemies you have forced to attack you deal {v}% less damage to you while they must.",
			{"key": "lightning_hard_stare", "values": [4.0, 8.0]}],
		"r9c9": ["Eye of the Storm", 3, "{n:drawthestorm} lasts {v} sec longer and its zaps deal {v2}% more damage.",
			{"key": "lightning_eye_of_the_storm", "values": [1.0, 2.0, 3.0], "values2": [10.0, 20.0, 30.0], "requires": "drawthestorm"}],
		"r9c10": ["Back to the Wall", 2, "While you are below {b:BACK_TO_THE_WALL_HEALTH}% health, your Parry chance is increased by {v}%.",
			{"key": "lightning_back_to_the_wall", "values": [4.0, 8.0]}],
		"r10c9": ["Storm Anchor", 5, "Increases your Parry chance by {v}%.",
			{"key": "lightning_storm_anchor", "values": [1.0, 2.0, 3.0, 4.0, 5.0], "stats": {"parry": 1.0},
			"capstone": "Every {bth:STORM_ANCHOR_EVERY} attack you parry sets off a {n:shockring} that costs nothing.",
			"capstone_requires": "shockring"}],
		# --- Stormstring (unfinished: a short ribbon of its Storm Arrow talents;
		# lightning_bow.gd). Each ties the arrow to a spell: Lightning Bolt, Flicker, Capacitor.
		"r1c12": ["Grounded Arrow", 3, "{n:stormarrow} stays stuck in its target for {e:lightning_rod.time} sec. Your {n:lightningbolt} hitting that target also arcs to every enemy within {b:LIGHTNING_ROD_RADIUS} m of it for {v}% of the damage it dealt.",
			{"key": "lightning_rod", "values": [13.0, 27.0, 40.0], "requires": "stormarrow"}],
		"r2c12": ["Snap Shot", 3, "{n:flicker} resets the cooldown of {n:stormarrow} and makes your next {n:stormarrow} within {b:SNAP_SHOT_TIME} sec cost {v} less Energy.",
			{"key": "lightning_snap_shot", "values": [10.0, 20.0, 30.0], "requires": "stormarrow"}],
		"r3c12": ["Loaded Quiver", 2, "Taking your Energy back from {n:capacitor} loads {v} {n:stormarrow} for {b:LOADED_QUIVER_TIME} sec: each costs no Energy and ignores its cooldown.",
			{"key": "lightning_loaded_quiver", "values": [1.0, 2.0], "requires": "stormarrow"}],
	},
	"arcane": {
		# The ribbon layout (GROUPS, 13 columns): Clockwork (the caster) in columns 1-3,
		# Hall of Mirrors (the dodge tank) in 4-6, the open talents on the spine (column 7),
		# Second Act (melee) in 8-10 and Aetherstring (the bow, unfinished: an empty short
		# ribbon) in 11-13. Rows 1-9 hold 18 talents per finished spec in its shape
		# (SHAPES); row 10 its 5-rank capstone, which needs Balance.CAPSTONE_GATE points in
		# the spec. Most key off the book's words (Arcane cooldowns, Reflections, shatters,
		# dodges, Traces, replays, cuts...). Code: arcane_talents.gd (the hits' bonuses,
		# cooldowns coming back, Reflections made) and each spec's component
		# (arcane_caster.gd, arcane_tank.gd, arcane_melee.gd, arcane_talents_open.gd).
		# --- Clockwork.
		"r1c2": ["Etched Darts", 3, "Your Arcane spells that critically strike have a {v}% chance to take {b:ETCHED_DARTS_SECONDS} sec off the cooldowns of your other Arcane spells.",
			{"key": "arcane_etched_darts", "values": [5.0, 10.0, 15.0]}],
		"r2c1": ["Seventh Sigil", 2, "{n:arcanemissiles} fires {v} more darts over the same channel.",
			{"key": "arcane_seventh_sigil", "values": [1.0, 2.0], "requires": "arcanemissiles"}],
		"r2c3": ["Frayed", 3, "When {n:unravel} critically strikes, it has a {v}% chance to take its time off the cooldowns of your other Arcane spells a second time.",
			{"key": "arcane_frayed", "values": [33.0, 67.0, 100.0], "requires": "unravel"}],
		"r3c1": ["Pinned in Time", 3, "Your Arcane spells deal {v}% more damage to enemies you have rooted.",
			{"key": "arcane_pinned_in_time", "values": [4.0, 8.0, 12.0]}],
		"r3c3": ["Thrifty Mind", 3, "Your Arcane spells cost {v}% less mana.",
			{"key": "arcane_thrifty_mind", "values": [3.0, 6.0, 9.0]}],
		"r4c1": ["Polished Glass", 3, "{n:mirrorsigil} repeats your Arcane spells at {v+b:MIRROR_SIGIL_PCT}% of their damage.",
			{"key": "arcane_polished_glass", "values": [3.0, 6.0, 10.0], "requires": "mirrorsigil"}],
		"r4c3": ["Chain Reaction", 3, "When {n:countdown} detonates, every other enemy within {b:CHAIN_REACTION_RADIUS} m of its target takes {v}% of the extra damage it counted. Full damage to up to {b:AOE_TARGET_CAP} enemies; with more, that damage is split evenly between all of them.",
			{"key": "arcane_chain_reaction", "values": [10.0, 20.0, 30.0], "requires": "countdown"}],
		"r5c1": ["Wound Up", 3, "Your Arcane spells deal {v}% more damage for each of your other Arcane spells on cooldown, up to {b:WOUND_UP_MAX}.",
			{"key": "arcane_wound_up", "values": [1.0, 2.0, 3.0]}],
		"r5c2": ["Sharp Mind", 3, "Critical strikes of your Arcane spells deal {v}% more damage.",
			{"key": "arcane_sharp_mind", "values": [5.0, 10.0, 15.0]}],
		"r5c3": ["Clock Hands", 3, "While {b:CLOCK_HANDS_COOLDOWNS} or more of your Arcane spells are on cooldown, your Arcane spells cast {v}% faster.",
			{"key": "arcane_clock_hands", "values": [3.0, 6.0, 9.0]}],
		"r6c1": ["Moving Parts", 3, "While you are moving, your Arcane spells deal {v}% more damage.",
			{"key": "arcane_moving_parts", "values": [3.0, 6.0, 9.0]}],
		"r6c2": ["Second Hand", 3, "Each Arcane spell you cast has a {v}% chance to take {b:SECOND_HAND_SECONDS} sec off the cooldown of another of your Arcane spells that is on cooldown.",
			{"key": "arcane_second_hand", "values": [5.0, 10.0, 15.0]}],
		"r6c3": ["Keep Moving", 3, "The window {n:glint} opens lasts {v} sec longer.",
			{"key": "arcane_keep_moving", "values": [1.5, 2.5, 4.0], "requires": "glint",
			"capstone": "It covers {b:KEEP_MOVING_CASTS} casts on the move instead of one."}],
		"r7c1": ["Aftershock", 3, "Enemies pulled by {n:collapse} are slowed by {v}% for {b:AFTERSHOCK_TIME} sec.",
			{"key": "arcane_aftershock", "values": [13.0, 27.0, 40.0], "requires": "collapse"}],
		"r7c3": ["Light Touch", 3, "Your Arcane spells and abilities generate {v}% less threat.",
			{"key": "arcane_light_touch", "values": [5.0, 10.0, 15.0]}],
		"r8c1": ["On the Dot", 3, "An Arcane spell you cast within {b:ON_THE_DOT_TIME} sec of it coming off cooldown deals {v}% more damage.",
			{"key": "arcane_on_the_dot", "values": [6.0, 12.0, 18.0]}],
		"r8c3": ["Turning Gears", 3, "Each time one of your Arcane spells comes off cooldown, you gain {v}% Haste for {b:TURNING_GEARS_TIME} sec, stacking up to {b:TURNING_GEARS_STACKS} times.",
			{"key": "arcane_turning_gears", "values": [1.0, 2.0, 3.0]}],
		"r9c2": ["Unwinding", 3, "When you take time off the cooldowns of your Arcane spells, there is a {v}% chance that your next Arcane spell with a cast time, within {b:UNWINDING_TIME} sec, is instant.",
			{"key": "arcane_unwinding", "values": [5.0, 10.0, 15.0]}],
		# Running Clock: Player._tick_cooldowns.
		"r10c2": ["Running Clock", 5, "The cooldowns of your Arcane spells and abilities recover {v}% faster. Interrupts are not affected.",
			{"key": "arcane_running_clock", "values": [2.0, 4.0, 6.0, 8.0, 10.0]}],
		# --- Hall of Mirrors (arcane_tank.gd).
		"r1c4": ["Light Feet", 3, "Increases your Dodge chance by {v}% while you wield a melee weapon in each hand.",
			{"key": "arcane_light_feet", "values": [1.0, 2.0, 3.0]}],
		"r1c5": ["Sharp Edges", 3, "Your Reflections deal {v}% more damage when they shatter.",
			{"key": "arcane_sharp_edges", "values": [10.0, 20.0, 30.0],
			"capstone": "A shatter reaches enemies within {b:SHARP_EDGES_RADIUS} m of you instead of {b:REFLECTION_SHATTER_RADIUS} m."}],
		"r1c6": ["Spare Seconds", 2, "Each of your Reflections that shatters takes {v} sec more off the cooldowns of your Arcane spells and abilities.",
			{"key": "arcane_clockwork", "values": [0.25, 0.5]}],
		"r2c4": ["Second Self", 3, "When you create a Reflection, there is a {v}% chance to create one more.",
			{"key": "arcane_second_self", "values": [10.0, 20.0, 30.0]}],
		"r2c6": ["Head Count", 3, "Each Reflection you create heals you for {v}% of your maximum health.",
			{"key": "arcane_head_count", "values": [0.5, 1.0, 1.5]}],
		"r3c4": ["Glass Armor", 3, "Your Armor is increased by {v}% for each Reflection you have.",
			{"key": "arcane_glass_armor", "values": [2.0, 4.0, 6.0]}],
		"r3c6": ["Empty Room", 3, "While you wield a melee weapon in each hand and have no Reflections, you take {v}% less damage.",
			{"key": "arcane_empty_room", "values": [4.0, 8.0, 12.0]}],
		"r4c4": ["Wide Rings", 3, "{n:ripple} reaches {v} m further.",
			{"key": "arcane_wide_rings", "values": [0.7, 1.3, 2.0], "requires": "ripple",
			"capstone": "It creates a Reflection when it hits {b:WIDE_RINGS_ENEMIES} or more enemies."}],
		"r4c6": ["Bent Light", 2, "You take {v}% less non-Physical damage for each Reflection you have.",
			{"key": "arcane_bent_light", "values": [1.0, 2.0]}],
		"r5c4": ["Quick Answer", 3, "After you dodge an attack, your next Arcane ability within {b:QUICK_ANSWER_TIME} sec deals {v}% more damage and threat.",
			{"key": "arcane_quick_answer", "values": [10.0, 20.0, 30.0]}],
		"r5c5": ["Glass Dust", 3, "Enemies hit by your shatters deal {v}% less damage to you for {b:GLASS_DUST_TIME} sec.",
			{"key": "arcane_glass_dust", "values": [2.0, 4.0, 6.0]}],
		"r5c6": ["Last Copy", 3, "While you have exactly one Reflection, your Dodge chance is increased by {v}%.",
			{"key": "arcane_last_copy", "values": [2.0, 4.0, 6.0]}],
		"r6c5": ["On the Beat", 3, "{n:missedbeat} deals {v}% more damage.",
			{"key": "arcane_on_the_beat", "values": [10.0, 20.0, 30.0], "requires": "missedbeat",
			"capstone": "Used while you have no Reflections, it creates one."}],
		"r7c5": ["Understudy", 3, "Each Reflection destroyed by {n:standin} takes {v} sec off its cooldown.",
			{"key": "arcane_understudy", "values": [1.5, 2.5, 4.0], "requires": "standin"}],
		"r8c5": ["Good Likeness", 3, "{n:decoy} holds enemies for {v} sec longer.",
			{"key": "arcane_good_likeness", "values": [0.7, 1.3, 2.0], "requires": "decoy",
			"capstone": "{n:decoy} no longer needs or uses up a Reflection."}],
		"r9c4": ["Spare Copy", 2, "When you dodge an attack, there is a {v}% chance that the Reflection which takes it is not used up. It still shatters.",
			{"key": "arcane_spare_copy", "values": [10.0, 20.0]}],
		"r9c5": ["Full Crowd", 2, "{n:crowdofone} creates {v} Reflections when you use it.",
			{"key": "arcane_full_crowd", "values": [1.0, 2.0], "requires": "crowdofone"}],
		"r9c6": ["Crowded Room", 3, "Your Arcane abilities generate {v}% more threat for each Reflection you have.",
			{"key": "arcane_crowded_room", "values": [2.0, 4.0, 6.0]}],
		# Silvered: arcane_tank._shatter_burst.
		"r10c5": ["Silvered", 5, "Each of your Reflections that shatters heals you for {v}% of your maximum health.",
			{"key": "arcane_silvered", "values": [0.3, 0.6, 0.9, 1.2, 1.5]}],
		# --- Open talents: themed to the book (time, copies, mirrors) but they work with
		# every book's spells and abilities (arcane_talents_open.gd).
		"r1c7": ["Quick Study", 3, "Increases your Haste by {v}%.",
			{"key": "arcane_quick_study", "values": [1.0, 2.0, 3.0], "stats": {"haste": 1.0}}],
		"r2c7": ["Two Minds", 3, "The lower of your Spell Power and Attack Power is increased by {v}% of the higher.",
			{"key": "arcane_two_minds", "values": [4.0, 8.0, 12.0]}],
		"r3c7": ["Echo", 3, "Your spells and abilities have a {v}% chance to be repeated for {b:ECHO_PCT}% of the damage they dealt. For an Arcane spell or ability the chance is {b:ECHO_ARCANE_CHANCE_MULT} times as high, and the repeat deals {b:ECHO_ARCANE_PCT}% of the damage.",
			{"key": "arcane_echo", "values": [2.0, 4.0, 6.0]}],
		"r4c7": ["Mirror Finish", 3, "When you dodge, parry or block an attack, the attacker takes {vdmg:ripple} Arcane damage.",
			{"key": "arcane_mirror_finish", "values": [0.1, 0.2, 0.3]}],
		"r5c7": ["Overtime", 3, "Buffs you put on yourself last {v}% longer.",
			{"key": "arcane_overtime", "values": [5.0, 10.0, 15.0]}],
		"r6c7": ["Slipstream", 2, "After you use a movement spell or ability (a blink, a dash or a leap), you move {v}% faster for {b:SLIPSTREAM_TIME} sec.",
			{"key": "arcane_slipstream", "values": [10.0, 20.0]}],
		"r7c7": ["Long Step", 2, "Your blinks take you {v} m further.",
			{"key": "arcane_long_step", "values": [1.0, 2.0]}],
		"r8c7": ["Spare Moment", 3, "Your spells and abilities with a cooldown of {b:SPARE_MOMENT_COOLDOWN} sec or more recover {v}% faster. Interrupts are not affected.",
			{"key": "arcane_spare_moment", "values": [2.0, 4.0, 6.0]}],
		"r9c7": ["Borrowed Time", 3, "When one of your spells or abilities with a cooldown of {b:BORROWED_TIME_COOLDOWN} sec or more comes off cooldown, your next spell or ability within {b:BORROWED_TIME_TIME} sec deals {v}% more damage.",
			{"key": "arcane_borrowed_time", "values": [5.0, 10.0, 15.0]}],
		# --- Second Act (arcane_melee.gd). Cuts: Swift Cut, Deep Cut, Late Cut, Wide Cut.
		"r1c8": ["Long Memory", 3, "Your Traces last {v} sec longer.",
			{"key": "arcane_long_memory", "values": [1.5, 2.5, 4.0]}],
		"r1c9": ["Standing Ovation", 3, "Your replays ({n:encore}) deal {v+b:ENCORE_PCT}% of the damage each Trace recorded.",
			{"key": "arcane_standing_ovation", "values": [5.0, 10.0, 15.0],
			"capstone": "You can hold {b:STANDING_OVATION_TRACES} more Trace."}],
		"r1c10": ["Fresh Trace", 3, "While you hold fewer than {b:FRESH_TRACE_HELD} Traces, the Traces you leave record {v}% more damage.",
			{"key": "arcane_fresh_trace", "values": [4.0, 8.0, 12.0]}],
		"r2c8": ["Practiced Hand", 3, "Your Arcane abilities deal {v}% more damage for each Trace you hold.",
			{"key": "arcane_practiced_hand", "values": [1.0, 2.0, 3.0]}],
		"r2c10": ["Heavy Hand", 3, "The Trace {n:deepcut} leaves records {v}% more damage than the strike dealt.",
			{"key": "arcane_heavy_hand", "values": [7.0, 13.0, 20.0], "requires": "deepcut"}],
		"r3c8": ["Clean Lines", 3, "When {n:swiftcut} critically strikes, it takes {v} sec off the cooldown of {n:deepcut}.",
			{"key": "arcane_clean_lines", "values": [0.3, 0.7, 1.0], "requires": "deepcut"}],
		"r3c10": ["Keen Cuts", 2, "Your cuts ({n:swiftcut}, {n:deepcut}, {n:latecut} and {n:widecut}) have a {v}% higher critical strike chance.",
			{"key": "arcane_keen_cuts", "values": [2.0, 4.0]}],
		"r4c8": ["Quick Cuts", 3, "{n:deepcut}, {n:latecut} and {n:widecut} come back {v} sec sooner.",
			{"key": "arcane_quick_cuts", "values": [0.3, 0.6, 1.0]}],
		"r4c10": ["Twin Blades", 3, "While you wield a melee weapon in each hand, your auto-attacks have a {v}% chance to leave a Trace of the damage they dealt.",
			{"key": "arcane_twin_blades", "values": [5.0, 10.0, 15.0]}],
		"r5c8": ["Curtain Call", 3, "When you replay {b:CURTAIN_CALL_TRACES} or more Traces at once, each replay deals {v}% more damage.",
			{"key": "arcane_curtain_call", "values": [7.0, 13.0, 20.0]}],
		"r5c10": ["Second Showing", 3, "Your replays ({n:encore}) have a {v}% chance not to use up your Traces.",
			{"key": "arcane_second_showing", "values": [7.0, 13.0, 20.0]}],
		"r6c8": ["No Loose Ends", 3, "The second hit of {n:latecut} lands {v} sec sooner.",
			{"key": "arcane_no_loose_ends", "values": [0.3, 0.7, 1.0], "requires": "latecut",
			"capstone": "If the Trace of the first hit is gone when the second hit lands, the second hit leaves a Trace of its own."}],
		"r6c10": ["Full Stage", 3, "While you hold as many Traces as you can, your Arcane abilities deal {v}% more damage.",
			{"key": "arcane_full_stage", "values": [4.0, 8.0, 12.0]}],
		"r7c8": ["Full House", 2, "When {n:widecut} hits {b:FULL_HOUSE_ENEMIES} or more enemies, your next {n:encore} within {b:FULL_HOUSE_TIME} sec also replays each Trace on up to {v} other enemies within {b:FULL_HOUSE_RADIUS} m of its target, for {b:FULL_HOUSE_PCT}% of its damage.",
			{"key": "arcane_full_house", "values": [1.0, 2.0], "requires": "widecut"}],
		"r7c10": ["Final Act", 3, "Your replays deal {v}% more damage to enemies below {b:FINAL_ACT_HEALTH}% health.",
			{"key": "arcane_final_act", "values": [6.0, 12.0, 18.0]}],
		"r8c8": ["Dress Rehearsal", 3, "{n:doubletime} lasts {v} sec longer.",
			{"key": "arcane_dress_rehearsal", "values": [1.5, 2.5, 4.0], "requires": "doubletime",
			"capstone": "The first {n:encore} during {n:doubletime} does not use up your Traces.", "capstone_requires": "encore"}],
		"r8c10": ["Curtain Rise", 3, "After you replay your Traces, your next cut within {b:CURTAIN_RISE_TIME} sec deals {v}% more damage.",
			{"key": "arcane_curtain_rise", "values": [10.0, 20.0, 30.0]}],
		"r9c9": ["Time Signature", 3, "Each Trace you replay takes {v} sec off the cooldowns of your other Arcane spells and abilities. Interrupts are not affected.",
			{"key": "arcane_time_signature", "values": [0.15, 0.35, 0.5]}],
		# Fine Edge: Player._on_damage_modify.
		"r10c9": ["Fine Edge", 5, "Your Arcane abilities deal {v}% more damage while you wield a melee weapon in each hand.",
			{"key": "arcane_fine_edge", "values": [2.0, 4.0, 6.0, 8.0, 10.0]}],
	},
	"shadow": {
		# The ribbon layout (GROUPS, 13 columns): The Breach (the caster) in columns
		# 1-3, Pack of Two (melee, the Hounds) in 4-6, the open talents on the spine
		# (column 7), Strings Attached (the healer) in 8-10 and Nightstring (the bow,
		# unfinished: an empty short ribbon) in 11-13. Rows 1-9 hold 18 talents per
		# finished spec in its shape (SHAPES); row 10 its 5-rank capstone, which needs
		# Balance.CAPSTONE_GATE points in the spec. Most key off the book's words (the
		# Breach open or closed, its ticks, feeding it; the Hounds, bites, Roused, Fury;
		# Strings, their heals, three on one ally, crossing, loose Strings...).
		# (The Breach - the hole under an enemy that demons claw through - is "decay"
		# in the code, its first name. So are some talent keys: Lure is shadow_seep,
		# Wider Still shadow_running_over, Hooked Claws shadow_rot_through, Baited
		# Steel shadow_tainted_steel, Helping Hands shadow_many_hands.)
		# Code: shadow_decay.gd (the Breach), shadow_hounds.gd (the Hounds),
		# shadow_strings.gd (the Strings) and shadow_talents.gd (hit bonuses, the open talents).
		# --- The Breach.
		"r1c1": ["Lure", 3, "Your periodic Shadow damage (other than the Breach's own) adds {v}% of what it deals to your Breach under the target while it is open.",
			{"key": "shadow_seep", "values": [17.0, 33.0, 50.0]}],
		"r1c2": ["Interest", 3, "{n:calldue} deals {v+b:CALL_DUE_BONUS_PCT}% more than what it takes out of your Breach, instead of {b:CALL_DUE_BONUS_PCT}%.",
			{"key": "shadow_interest", "values": [5.0, 10.0, 15.0], "requires": "calldue",
			"capstone": "If that Breach was still open, your next {n:blight} within {b:INTEREST_TIME} sec is instant.", "capstone_requires": "blight"}],
		"r1c3": ["Held Open", 2, "Your Breach stays open {v} sec longer each time it is opened.",
			{"key": "shadow_held_open", "values": [1.0, 2.0]}],
		"r2c1": ["Hungry Dark", 3, "While your Breach under the target is open, your Shadow spells deal {v}% more damage to it.",
			{"key": "shadow_hungry_dark", "values": [2.0, 4.0, 6.0]}],
		# Deep Call: Player._begin_spell, StringsKit.deep_call_cast.
		"r2c3": ["Deep Call", 3, "While your Breach under the target is open, your Shadow spells with a cast time take {v} sec less to cast.",
			{"key": "shadow_deep_call", "values": [0.15, 0.35, 0.5]}],
		"r3c1": ["Wider Still", 3, "{n:spill} copies {v+b:SPILL_PCT}% of what is left in your Breach, instead of {b:SPILL_PCT}%.",
			{"key": "shadow_running_over", "values": [7.0, 13.0, 20.0], "requires": "spill",
			"capstone": "Every copy is open for at least {b:RUNNING_OVER_OPEN_TIME} sec."}],
		"r3c3": ["Bite Down", 3, "While {n:gnaw} makes your Breach under a target deal its damage more often, its ticks have {v}% more chance to critically strike.",
			{"key": "shadow_bite_down", "values": [7.0, 13.0, 20.0], "requires": "gnaw"}],
		"r4c1": ["Many Mouths", 3, "Your Shadow spells that hit an area add {v}% more to each open Breach of yours they hit.",
			{"key": "shadow_many_mouths", "values": [10.0, 20.0, 30.0]}],
		"r4c3": ["No Floor", 3, "{n:bottomless} lasts {v} sec longer.",
			{"key": "shadow_no_floor", "values": [1.5, 2.5, 4.0], "requires": "bottomless",
			"capstone": "Your Breach cannot close while it lasts."}],
		"r5c2": ["Small Change", 3, "{n:calldue} leaves {v}% of what it takes out in your Breach instead of ending it.",
			{"key": "shadow_small_change", "values": [7.0, 13.0, 20.0], "requires": "calldue"}],
		"r6c2": ["Shut Tight", 3, "The ticks of your Breach deal {v}% more damage while it is closed.",
			{"key": "shadow_shut_tight", "values": [5.0, 10.0, 15.0]}],
		"r7c1": ["Next of Kin", 3, "When an enemy standing on your Breach dies, {v}% more than what was left in it moves under the nearest enemy.",
			{"key": "shadow_next_of_kin", "values": [10.0, 20.0, 30.0],
			"capstone": "The next nearest enemy gets {b:NEXT_OF_KIN_SECOND_PCT}% of it as well."}],
		"r7c3": ["Grasping Hands", 3, "The ticks of your Breach have {v}% more chance to critically strike.",
			{"key": "shadow_grasping_hands", "values": [1.0, 2.0, 3.0]}],
		# Baited Steel: for a Shadow melee build that dips into the Breach (its twin for
		# the other books' spells is the Rune of Invitation, rune id "rot").
		"r8c1": ["Baited Steel", 3, "Your Shadow abilities add {v}% of the direct damage they deal to your Breach under the target while it is open.",
			{"key": "shadow_tainted_steel", "values": [10.0, 20.0, 30.0]}],
		"r8c3": ["Ill Will", 3, "Critical strikes of your damage over time effects deal {v}% more damage.",
			{"key": "shadow_ill_will", "values": [5.0, 10.0, 15.0]}],
		"r9c1": ["Carrion", 2, "When an enemy that carries one of your damage over time effects dies, you regain {v}% of your maximum mana.",
			{"key": "shadow_carrion", "values": [1.0, 2.0]}],
		"r9c2": ["Bitter End", 3, "The last tick of your Breach, the one that deals all that is left in it, deals {v}% more damage.",
			{"key": "shadow_bitter_end", "values": [33.0, 67.0, 100.0]}],
		"r9c3": ["Paid in Full", 2, "When your Breach ends with {n:calldue} or its last tick, you regain {v}% of your maximum mana.",
			{"key": "shadow_paid_in_full", "values": [1.0, 2.0]}],
		"r10c2": ["Hooked Claws", 5, "The ticks of your Breach deal {v}% more damage. It does not shrink any faster for it.",
			{"key": "shadow_rot_through", "values": [2.0, 4.0, 6.0, 8.0, 10.0],
			"capstone": "A tick of your Breach that critically strikes keeps it open {b:HOOKED_CLAWS_HOLD} sec longer, up to {b:HOOKED_CLAWS_MAX} sec each time it is opened."}],
		# --- Pack of Two (shadow_hounds.gd has the list of where each one is in the code).
		"r1c4": ["Long Night", 2, "Your Hounds stay {v} sec longer.",
			{"key": "shadow_long_night", "values": [3.0, 6.0]}],
		"r1c6": ["Pincer", 3, "The lunges of {n:bothatonce} deal {v}% more damage.",
			{"key": "shadow_pincer", "values": [10.0, 20.0, 30.0], "requires": "bothatonce",
			"capstone": "A lunge that critically strikes gives you {b:PINCER_FURY} Fury back."}],
		"r2c5": ["Still Wet", 3, "Laid Open lasts {v} sec longer.",
			{"key": "shadow_still_wet", "values": [1.5, 2.5, 4.0], "requires": "openup",
			"capstone": "Your own direct hits also deal {b:STILL_WET_PCT}% more damage to that enemy."}],
		"r3c4": ["Take It With You", 2, "Drag Down, the damage each of your Hounds deals to its prey as it goes back under the ground, is {v}% larger.",
			{"key": "shadow_take_it_with_you", "values": [25.0, 50.0],
			"capstone": "If Drag Down kills the enemy, your next pair of Hounds arrives already Roused."}],
		"r3c6": ["Again", 3, "{n:bothatonce} has a {v}% chance to reset its own cooldown.",
			{"key": "shadow_again", "values": [10.0, 20.0, 30.0], "requires": "bothatonce"}],
		"r4c5": ["Slipped Leash", 3, "{n:offthechain} lasts {v} sec longer.",
			{"key": "shadow_slipped_leash", "values": [1.5, 2.5, 4.0], "requires": "offthechain",
			"capstone": "A third Hound joins your pair for as long as it lasts."}],
		"r5c4": ["Lean and Hungry", 3, "Your Hounds bite {v}% faster.",
			{"key": "shadow_lean_and_hungry", "values": [4.0, 8.0, 12.0]}],
		"r5c5": ["Out of the Hole", 3, "The bites of your Hounds add {v}% of the damage they deal to your Breach under the enemy while it is open.",
			{"key": "shadow_out_of_the_hole", "values": [17.0, 33.0, 50.0]}],
		"r5c6": ["Snarl", 3, "Your Shadow abilities that build Fury build {v}% more.",
			{"key": "shadow_snarl", "values": [5.0, 10.0, 15.0]}],
		"r6c4": ["Fed", 2, "A bite of your Hounds that critically strikes gives you {v} Fury.",
			{"key": "shadow_fed", "values": [2.0, 4.0]}],
		"r6c5": ["Worked Up", 2, "Roused lasts {v} sec longer.",
			{"key": "shadow_worked_up", "values": [2.0, 4.0],
			"capstone": "While your Hounds are Roused, their bites have {b:WORKED_UP_CRIT}% more chance to critically strike."}],
		"r6c6": ["Blood Up", 3, "While your Hounds are Roused, your Shadow abilities that spend Fury deal {v}% more damage.",
			{"key": "shadow_blood_up", "values": [3.0, 6.0, 9.0]}],
		"r7c4": ["Stand Over", 3, "While your Hounds are Roused, each of their bites heals you for {v}% of your maximum health.",
			{"key": "shadow_stand_over", "values": [0.2, 0.4, 0.6]}],
		"r7c5": ["Wide Pack", 2, "During {n:runthemdown}, each bite of your Hounds hits {v} more enemies.",
			{"key": "shadow_wide_pack", "values": [1.0, 2.0], "requires": "runthemdown"}],
		"r7c6": ["Fetch", 3, "Each Drag Down of your Hounds gives you {v} Fury.",
			{"key": "shadow_fetch", "values": [3.0, 6.0, 10.0]}],
		"r8c4": ["Thick Blood", 3, "Your Fury decays {v}% slower.",
			{"key": "shadow_thick_blood", "values": [15.0, 30.0, 45.0]}],
		"r8c6": ["Scent of Blood", 3, "The bites, lunges and Drag Downs of your Hounds deal {v}% more damage to enemies below {b:SCENT_OF_BLOOD_HEALTH_PCT}% health.",
			{"key": "shadow_scent_of_blood", "values": [5.0, 10.0, 15.0]}],
		# Share the Kill: RuneFrostfireKit (the heals of my abilities), HoundsKit.leech_heal_mult.
		"r9c5": ["Share the Kill", 3, "Your Shadow abilities that heal you heal {v}% more while your Hounds are out.",
			{"key": "shadow_share_the_kill", "values": [33.0, 67.0, 100.0]}],
		"r10c5": ["Pack Leader", 5, "Your Hounds deal {v}% more damage.",
			{"key": "shadow_pack_leader", "values": [3.0, 6.0, 9.0, 12.0, 15.0],
			"capstone": "Every {b:PACK_LEADER_EVERY} Fury you spend keeps your Hounds out {b:PACK_LEADER_TIME} sec longer, up to {b:PACK_LEADER_MAX} sec for each pair."}],
		# --- Open talents: themed to the book (damage over time, a slow end, helping
		# others, holding things in place) but they work with every book's spells,
		# abilities, heals, stuns and roots (shadow_talents.gd; Helping Hands and Lean
		# On Me: shadow_strings.gd; Left Hanging: Abilities.effect_time_bonus).
		"r1c7": ["Slow Death", 3, "Your damage over time effects deal {v}% more damage.",
			{"key": "shadow_slow_death", "values": [2.0, 4.0, 6.0]}],
		"r2c7": ["Wasting", 3, "Your damage over time effects deal their damage {v}% more often.",
			{"key": "shadow_wasting", "values": [2.0, 4.0, 6.0]}],
		"r3c7": ["Finish It", 3, "You deal {v}% more damage to enemies below {b:FINISH_IT_HEALTH_PCT}% health.",
			{"key": "shadow_finish_it", "values": [3.0, 6.0, 9.0]}],
		"r4c7": ["Spite", 3, "After you take damage, your next spell or ability within {b:SPITE_TIME} sec deals {v}% more damage.",
			{"key": "shadow_spite", "values": [3.0, 6.0, 9.0]}],
		"r5c7": ["Feeding Frenzy", 3, "When an enemy you damaged dies, you gain {v}% Haste for {b:FEEDING_FRENZY_TIME} sec.",
			{"key": "shadow_feeding_frenzy", "values": [2.0, 4.0, 6.0]}],
		"r6c7": ["Helping Hands", 3, "Your heals on allies other than yourself are {v}% larger.",
			{"key": "shadow_many_hands", "values": [2.0, 4.0, 6.0]}],
		"r7c7": ["Lean On Me", 3, "After you heal an ally other than yourself, you take {v}% less damage for {b:LEAN_ON_ME_TIME} sec.",
			{"key": "shadow_lean_on_me", "values": [2.0, 4.0, 6.0]}],
		"r8c7": ["Left Hanging", 2, "Your stuns and roots last {v}% longer.",
			{"key": "shadow_left_hanging", "values": [10.0, 20.0]}],
		"r9c7": ["Inevitable", 5, "Enemies you first damaged more than {b:INEVITABLE_TIME} sec ago take {v}% more damage from you.",
			{"key": "shadow_inevitable", "values": [2.0, 4.0, 6.0, 8.0, 10.0]}],
		# --- Strings Attached (shadow_strings.gd, "Shadow healer: the Strings").
		"r1c9": ["Heave", 3, "{n:hoist} heals {v}% more for each of your Strings on its target.",
			{"key": "shadow_heave", "values": [3.0, 7.0, 10.0], "requires": "hoist",
			"capstone": "On a target with {b:STRING_STACKS} of your Strings, its cast time is {b:HEAVE_CAST} sec shorter."}],
		"r2c8": ["Long Thread", 2, "Your Strings on allies last {v} sec longer.",
			{"key": "shadow_long_thread", "values": [2.0, 4.0]}],
		"r2c9": ["Quick Hands", 3, "Your Strings heal {v}% more often.",
			{"key": "shadow_quick_hands", "values": [4.0, 8.0, 12.0]}],
		"r2c10": ["Three Ply", 3, "An ally with {b:STRING_STACKS} of your Strings is healed {v}% more by them.",
			{"key": "shadow_three_ply", "values": [5.0, 10.0, 15.0]}],
		"r3c9": ["First Stitch", 2, "Tying a String to an ally heals it at once, for as much as {v} heals of one String.",
			{"key": "shadow_first_stitch", "values": [2.0, 4.0]}],
		"r4c8": ["Spare Spool", 2, "Your Strings that were used up come back {v} sec sooner.",
			{"key": "shadow_spare_spool", "values": [1.0, 2.0]}],
		"r4c9": ["Hard Pull", 3, "{n:tug} makes the ally's Strings heal faster for {v} sec longer.",
			{"key": "shadow_hard_pull", "values": [0.7, 1.3, 2.0], "requires": "tug"}],
		"r4c10": ["Full Harness", 2, "An ally that has {b:STRING_STACKS} of your Strings takes {v}% less damage.",
			{"key": "shadow_full_harness", "values": [3.0, 6.0]}],
		"r5c9": ["Pass It On", 3, "The share of your heals that reaches your other allies on a String is {v}% larger.",
			{"key": "shadow_pass_it_on", "values": [10.0, 20.0, 30.0]}],
		"r6c8": ["Taking the Weight", 2, "Crossed Strings moves {v}% of the damage the ally takes to the enemy, instead of {b:STRING_CROSS_PCT}%.",
			{"key": "shadow_taking_the_weight", "values": [5.0, 7.0],
			"capstone": "A crossing holds up to {b:TAKING_THE_WEIGHT_RANGE} m apart, instead of {b:STRING_CROSS_RANGE} m."}],
		"r6c10": ["Fair Trade", 3, "The damage Crossed Strings moves to the enemy also heals the ally for {v}% of it.",
			{"key": "shadow_fair_trade", "values": [10.0, 20.0, 30.0]}],
		"r7c8": ["Snap Back", 3, "{n:pulltaut} has a {v}% chance to put its String straight back in your hand instead of using it up.",
			{"key": "shadow_snap_back", "values": [17.0, 33.0, 50.0], "requires": "pulltaut"}],
		"r7c10": ["Hold Fast", 3, "Your Strings heal {v}% more on allies below {b:HOLD_FAST_HEALTH_PCT}% health.",
			{"key": "shadow_hold_fast", "values": [7.0, 13.0, 20.0]}],
		"r8c8": ["Give and Take", 3, "{n:slack} stops your Strings healing for {v} sec less.",
			{"key": "shadow_give_and_take", "values": [1.0, 2.0, 3.0], "requires": "slack"}],
		"r8c10": ["Firm Grip", 3, "Your Strings on enemies last {v} sec longer.",
			{"key": "shadow_firm_grip", "values": [1.5, 3.0, 4.5]}],
		"r9c8": ["Loose Weave", 2, "Your loose Strings last {v} sec longer.",
			{"key": "shadow_loose_weave", "values": [2.0, 4.0]}],
		"r9c9": ["Long Drop", 3, "When {n:stringup} ends, the enemy drops and takes {vdmg:stringup} Shadow damage.",
			{"key": "shadow_long_drop", "values": [0.3, 0.7, 1.0], "requires": "stringup"}],
		"r9c10": ["Nothing Wasted", 2, "When your Strings on an ally run their full time, you regain {v}% of your maximum mana.",
			{"key": "shadow_nothing_wasted", "values": [0.3, 0.6]}],
		"r10c9": ["Steady Hands", 5, "Your Strings heal {v}% more.",
			{"key": "shadow_steady_hands", "values": [3.0, 6.0, 9.0, 12.0, 15.0],
			"capstone": "While none of your Strings are left in your hand, your Strings Attached heals are {b:STEADY_HANDS_ALL_OUT_PCT}% larger."}],
	},
	"nature": {
		# The ribbon layout (GROUPS, 13 columns): Thornweaver (the caster) in columns
		# 1-3, Shepherd (the healer) in 4-6, the open talents on the spine (column 7),
		# Colossus (the tank) in 8-10 and Venomstring (the bow) in 11-13. Rows 1-9 hold
		# 18 talents per spec in its shape (SHAPES); row 10 its 5-rank capstone, which
		# needs Balance.CAPSTONE_GATE points in the spec. Most key off the book's words
		# (Mulch patches, woven and rooted creatures, finishers, Thornburst; Blossoms;
		# Sap, Fury, holds, taunts; poisons, Venom, Venom Flow, Steeped...).
		# Code: each spec's component in scripts/player/ (nature_weaver.gd,
		# nature_shepherd.gd, nature_colossus.gd, nature_venomstring.gd); hit, heal and
		# cost bonuses and the open talents: nature_talents_open.gd.
		# --- Thornweaver.
		"r1c1": ["Compost", 1, "{n:thornshot} leaves a Mulch patch once every {b:COMPOST_PATCH_EVERY} hits that land, instead of every {b:THORNSHOT_PATCH_EVERY}.",
			{"key": "nature_compost", "values": [1.0], "requires": "thornshot"}],
		"r1c3": ["Thick Mulch", 2, "Your Mulch patches last {v} sec longer.",
			{"key": "nature_thick_mulch", "values": [5.0, 10.0]}],
		"r2c2": ["Hunting Party", 4, "{n:briartiger} deals {v}% more damage.",
			{"key": "nature_hunting_party", "values": [5.0, 10.0, 15.0, 15.0], "requires": "briartiger",
			"capstone": "Every second {n:briartiger} also strikes {b:HUNTING_PARTY_EXTRA} more enemies within {b:HUNTING_PARTY_RADIUS} m of the target and leaves Mulch under each."}],
		"r3c1": ["Bramble Burst", 3, "Your Thornburst deals {v}% more damage.",
			{"key": "nature_bramble_burst", "values": [10.0, 20.0, 30.0],
			"capstone": "They reach {b:BRAMBLE_BURST_RADIUS} m from each patch instead of {b:THORNBURST_RADIUS} m."}],
		"r3c3": ["Well Rotted", 3, "Mulch patches that lay for at least {b:WELL_ROTTED_AGE} sec add {v}% more to {n:mossback} and {n:chokingvipers}.",
			{"key": "nature_well_rotted", "values": [20.0, 40.0, 60.0]}],
		"r4c2": ["Rich Soil", 3, "The damage each Mulch patch adds to {n:mossback} and {n:chokingvipers} is {v}% higher.",
			{"key": "nature_rich_soil", "values": [10.0, 20.0, 30.0]}],
		"r5c1": ["Second Growth", 3, "{n:mossback} has a {v}% chance to leave a Mulch patch where it strikes.",
			{"key": "nature_second_growth", "values": [10.0, 20.0, 30.0], "requires": "mossback"}],
		"r5c2": ["Circling Hawk", 3, "When {n:mossback} or {n:chokingvipers} uses {b:CIRCLING_HAWK_PATCHES} or more Mulch patches, the cooldown of {n:thornwing} is cut by {v} sec.",
			{"key": "nature_circling_hawk", "values": [2.0, 4.0, 6.0], "requires": "thornwing"}],
		"r5c3": ["Fertile Ground", 3, "An enemy that dies with your {n:chokingvipers} on it has a {v}% chance to leave a Mulch patch where it fell.",
			{"key": "nature_fertile_ground", "values": [33.0, 67.0, 100.0], "requires": "chokingvipers"}],
		"r6c2": ["Long Roots", 3, "{n:mossback} and {n:chokingvipers} use Mulch patches up to {v} m further from where they strike.",
			{"key": "nature_long_roots", "values": [1.0, 2.0, 3.0]}],
		"r7c1": ["Tight Weave", 3, "Your woven creatures deal {v}% more damage.",
			{"key": "nature_tight_weave", "values": [4.0, 8.0, 12.0]}],
		"r7c3": ["Old Roots", 3, "Your rooted creatures deal {v}% more damage.",
			{"key": "nature_old_roots", "values": [4.0, 8.0, 12.0]}],
		"r8c1": ["Steady Weave", 3, "Your Nature spells with a cast time deal {v}% more damage.",
			{"key": "nature_steady_weave", "values": [3.0, 6.0, 9.0]}],
		"r8c2": ["Harvest", 3, "When {n:mossback} or {n:chokingvipers} uses {b:HARVEST_PATCHES} or more Mulch patches, it gives back {v}% of its mana cost.",
			{"key": "nature_harvest", "values": [20.0, 40.0, 60.0]}],
		"r8c3": ["Leaf Litter", 3, "When a Mulch patch of yours runs out unused, you regain {v}% of your maximum mana.",
			{"key": "nature_leaf_litter", "values": [0.3, 0.6, 1.0]}],
		"r9c1": ["Hunted", 3, "Your woven creatures deal {v}% more damage to enemies below {b:HUNTED_HEALTH_PCT}% health.",
			{"key": "nature_hunted", "values": [5.0, 10.0, 15.0]}],
		"r9c2": ["Lush", 3, "Your Nature spells that deal damage cost {v}% less mana.",
			{"key": "nature_lush", "values": [3.0, 6.0, 9.0]}],
		"r9c3": ["Quickening", 2, "Laying a Mulch patch makes your next Nature spell with a cast time within {b:QUICKENING_TIME} sec cast {v}% faster.",
			{"key": "nature_quickening", "values": [10.0, 20.0]}],
		"r10c2": ["Overgrown", 5, "Your Nature spells deal {v}% more damage for each Mulch patch you have.",
			{"key": "nature_overgrown", "values": [0.4, 0.8, 1.2, 1.6, 2.0],
			"capstone": "When {n:mossback} or {n:chokingvipers} uses {b:OVERGROWN_PATCHES} Mulch patches, it leaves one behind where it struck."}],
		# --- Shepherd.
		"r1c5": ["Running Herd", 4, "{n:fawn} heals {v}% more.",
			{"key": "nature_running_herd", "values": [5.0, 10.0, 15.0, 15.0], "requires": "fawn",
			"capstone": "Every second {n:fawn} bounces {b:RUNNING_HERD_EXTRA} more times."}],
		"r2c4": ["Morning Dew", 3, "{n:dewfall} heals {v}% more for each Blossom on its target, instead of {b:DEWFALL_PER_BLOSSOM}%.",
			{"key": "nature_morning_dew", "values": [15.0, 18.0, 20.0], "requires": "dewfall"}],
		"r2c5": ["Old Bark", 3, "{n:rootguard}'s shield absorbs {v}% more.",
			{"key": "nature_old_bark", "values": [10.0, 20.0, 30.0], "requires": "rootguard"}],
		"r2c6": ["Return Flight", 3, "After {n:owl} dives, it keeps watching the ally for the rest of its time and can dive once more, healing and striking for {v}% as much.",
			{"key": "nature_return_flight", "values": [20.0, 40.0, 60.0], "requires": "owl"}],
		"r3c4": ["Second Bud", 3, "Your woven heals have a {v}% chance to leave one more Blossom.",
			{"key": "nature_second_bud", "values": [10.0, 20.0, 30.0]}],
		"r3c5": ["Deep Bloom", 3, "Full Bloom from {n:heartwoodelk} lasts {v} sec longer.",
			{"key": "nature_deep_bloom", "values": [1.5, 2.5, 4.0], "requires": "heartwoodelk"}],
		"r3c6": ["Long Bloom", 2, "Your Blossoms last {v} sec longer.",
			{"key": "nature_long_bloom", "values": [3.0, 6.0]}],
		"r4c5": ["Heavy Petals", 3, "Each Blossom adds {v}% more to the heal or shield of your rooted creatures.",
			{"key": "nature_heavy_petals", "values": [10.0, 20.0, 30.0]}],
		"r5c5": ["Soft Weave", 3, "Your woven creatures heal {v}% more.",
			{"key": "nature_soft_weave", "values": [4.0, 8.0, 12.0]}],
		"r6c4": ["Pollen", 3, "When your rooted creatures use up {b:BLOSSOM_MAX} Blossoms on an ally, there is a {v}% chance a Blossom goes to the lowest-health ally within {b:POLLEN_REACH} m of them.",
			{"key": "nature_pollen", "values": [33.0, 67.0, 100.0]}],
		"r6c6": ["Canopy", 3, "An ally you give a Blossom takes {v}% less damage for {b:CANOPY_TIME} sec.",
			{"key": "nature_canopy", "values": [1.0, 2.0, 3.0]}],
		"r7c4": ["In Full Flower", 3, "Your heals heal {v}% more on an ally with {b:BLOSSOM_MAX} of your Blossoms.",
			{"key": "nature_in_full_flower", "values": [5.0, 10.0, 15.0]}],
		"r7c5": ["Close Herd", 3, "Each bounce of your Fawns heals {v+b:FAWN_KEEP_PCT}% as much as the one before, instead of {b:FAWN_KEEP_PCT}%.",
			{"key": "nature_close_herd", "values": [5.0, 10.0, 15.0]}],
		"r7c6": ["New Shoots", 3, "Your Nature heals heal {v}% more on an ally with none of your Blossoms.",
			{"key": "nature_new_shoots", "values": [4.0, 8.0, 12.0]}],
		"r8c4": ["Nectar", 3, "Each of your Blossoms that is used up gives you back {v}% of your maximum mana.",
			{"key": "nature_nectar", "values": [0.1, 0.2, 0.3]}],
		"r8c6": ["Patient Hands", 3, "Your Nature heals with a cast time heal {v}% more.",
			{"key": "nature_patient_hands", "values": [3.0, 6.0, 9.0]}],
		"r9c4": ["Wide Grove", 2, "Your rooted creatures reach {v} m further.",
			{"key": "nature_wide_grove", "values": [2.0, 4.0]}],
		"r9c6": ["Morning Mist", 3, "Your Nature heals cost {v}% less mana.",
			{"key": "nature_morning_mist", "values": [3.0, 6.0, 9.0]}],
		"r10c5": ["Evergreen", 5, "Each of your Blossoms heals its ally for {v}% of their maximum health every second.",
			{"key": "nature_evergreen", "values": [0.05, 0.1, 0.15, 0.2, 0.25],
			"capstone": "Your Blossoms that run out unused heal their ally for {h:EVERGREEN_FADE_HEAL} each."}],
		# --- Open talents: themed to the book (growth, the wild, the hunt) but they
		# work with every book's spells, abilities and heals (nature_talents_open.gd).
		"r1c7": ["Rough Bark", 3, "Increases your Armor by {v}%.",
			{"key": "nature_rough_bark", "values": [3.0, 6.0, 9.0], "stats": {"armor%": 3.0}}],
		"r2c7": ["Green Thumb", 3, "Your heals over time heal {v}% more.",
			{"key": "nature_green_thumb", "values": [4.0, 8.0, 12.0]}],
		"r3c7": ["Undergrowth", 3, "Your damage over time effects deal {v}% more damage to an enemy you have rooted, held in place or slowed.",
			{"key": "nature_undergrowth", "values": [4.0, 8.0, 12.0]}],
		"r4c7": ["Clinging Vines", 2, "When a root or hold of yours on an enemy ends, it moves {v}% slower for {b:CLINGING_VINES_TIME} sec.",
			{"key": "nature_clinging_vines", "values": [20.0, 40.0]}],
		"r5c7": ["Startle", 3, "Your first spell or ability on an enemy at full health deals {v}% more damage.",
			{"key": "nature_startle", "values": [5.0, 10.0, 15.0]}],
		"r6c7": ["Pack Hunter", 3, "You deal {v}% more damage to an enemy that is attacking someone other than you.",
			{"key": "nature_pack_hunter", "values": [2.0, 4.0, 6.0]}],
		"r7c7": ["Tending", 3, "Your heals heal {v}% more on an ally who carries one of your heals over time.",
			{"key": "nature_tending", "values": [3.0, 6.0, 9.0]}],
		"r8c7": ["Food Chain", 3, "When an enemy you damaged dies, you heal for {v}% of your maximum health.",
			{"key": "nature_food_chain", "values": [1.0, 2.0, 3.0]}],
		"r9c7": ["Hibernate", 2, "Out of combat, your health and mana come back {v}% faster.",
			{"key": "nature_hibernate", "values": [25.0, 50.0]}],
		# --- Colossus.
		"r1c9": ["Groundswell", 3, "Your Nature abilities that build Fury build {v}% more.",
			{"key": "nature_groundswell", "values": [5.0, 10.0, 15.0]}],
		"r2c8": ["Thick Sap", 4, "{n:heartsap} heals {v}% more.",
			{"key": "nature_thick_sap", "values": [5.0, 10.0, 15.0, 15.0], "requires": "heartsap",
			"capstone": "{n:heartsap} leaves you {b:THICK_SAP_KEEP} Sap."}],
		"r2c10": ["Crushing Grip", 3, "When {n:giantshands} bursts, it deals {v}% more damage for each hit it soaked, up to {b:CRUSHING_GRIP_HITS} hits.",
			{"key": "nature_crushing_grip", "values": [5.0, 10.0, 15.0], "requires": "giantshands"}],
		"r3c8": ["Rising Sap", 3, "Each Sap heals you for {v+b:SAP_HEAL_PCT}% of your maximum health every second, instead of {b:SAP_HEAL_PCT}%.",
			{"key": "nature_rising_sap", "values": [0.1, 0.2, 0.3]}],
		"r3c9": ["Heavy Limbs", 3, "Your Nature abilities that spend Fury deal {v}% more damage.",
			{"key": "nature_heavy_limbs", "values": [3.0, 6.0, 9.0]}],
		"r3c10": ["Broad Fist", 2, "{n:vinefist} also hits {v} more enemies near its target.",
			{"key": "nature_broad_fist", "values": [1.0, 2.0], "requires": "vinefist"}],
		"r4c8": ["Spreading Roots", 3, "The roots {n:stomp} leaves last {v} sec longer and reach {v2} m further. Their damage per second stays the same.",
			{"key": "nature_spreading_roots", "values": [1.5, 2.5, 4.0], "values2": [0.7, 1.3, 2.0], "requires": "stomp"}],
		"r4c9": ["Firm Hold", 3, "Your holds on enemies last {v} sec longer, and each one you put on gives you {v2} Fury.",
			{"key": "nature_firm_hold", "values": [0.3, 0.7, 1.0], "values2": [3.0, 7.0, 10.0]}],
		"r4c10": ["Wide Awake", 3, "{n:awaken} lasts {v} sec longer.",
			{"key": "nature_wide_awake", "values": [2.0, 4.0, 6.0], "requires": "awaken"}],
		"r5c8": ["Long Sap", 2, "Your Sap lasts {v} sec longer.",
			{"key": "nature_long_sap", "values": [5.0, 10.0]}],
		"r5c9": ["Sap Run", 3, "Your Nature abilities that give Sap have a {v}% chance to give one more.",
			{"key": "nature_sap_run", "values": [10.0, 20.0, 30.0]}],
		"r5c10": ["Taproot", 3, "Each Sap you use up gives you {v} Fury.",
			{"key": "nature_taproot", "values": [1.0, 2.0, 3.0]}],
		"r6c9": ["Long Limbs", 3, "Your Nature abilities that hit everything around you reach {v} m further.",
			{"key": "nature_long_limbs", "values": [1.0, 2.0, 3.0]}],
		"r7c9": ["Called Out", 3, "Each enemy your taunts hit gives you {v} Fury, up to {b:CALLED_OUT_ENEMIES} enemies at a time.",
			{"key": "nature_called_out", "values": [2.0, 4.0, 6.0]}],
		"r8c9": ["Creaking Bark", 3, "Your Nature abilities make {v}% more threat.",
			{"key": "nature_creaking_bark", "values": [5.0, 10.0, 15.0]}],
		"r9c8": ["Brimming", 3, "While you have {b:SAP_MAX} Sap, your Sap heals {v}% more.",
			{"key": "nature_brimming", "values": [20.0, 40.0, 60.0]}],
		"r9c9": ["Woodgrain", 3, "Your shields on yourself absorb {v}% more.",
			{"key": "nature_woodgrain", "values": [7.0, 13.0, 20.0]}],
		"r9c10": ["Old Oak", 3, "While you are below {b:OLD_OAK_HEALTH_PCT}% health, your Sap heals {v}% more.",
			{"key": "nature_old_oak", "values": [33.0, 67.0, 100.0]}],
		"r10c9": ["Old Growth", 5, "Each Sap you hold makes you take {v}% less damage.",
			{"key": "nature_old_growth", "values": [0.4, 0.8, 1.2, 1.6, 2.0],
			"capstone": "A hit that takes {b:OLD_GROWTH_HIT_PCT}% or more of your maximum health gives you a Sap, at most once every {b:OLD_GROWTH_EVERY} sec."}],
		# --- Venomstring.
		"r1c11": ["Long Fangs", 3, "{n:fangarrow} adds {v+b:FANG_EXTEND} sec to your poisons instead of {b:FANG_EXTEND}.",
			{"key": "nature_long_fangs", "values": [0.7, 1.3, 2.0], "requires": "fangarrow"}],
		"r1c13": ["Lingering Venom", 4, "{n:venomburst} deals {v}% more damage.",
			{"key": "nature_lingering_venom", "values": [5.0, 10.0, 15.0, 15.0], "requires": "venomburst",
			"capstone": "Each poison {n:venomburst} would remove has a {b:LINGERING_VENOM_KEEP}% chance to stay on the target."}],
		"r2c11": ["Slow Acting", 2, "Your poisons last {v} sec longer.",
			{"key": "nature_slow_acting", "values": [2.0, 4.0]}],
		"r2c12": ["Virulent", 3, "Your poisons deal {v}% more damage.",
			{"key": "nature_virulent", "values": [3.0, 6.0, 9.0]}],
		"r2c13": ["Spring Trap", 2, "The thorn trap of {n:coilback} catches up to {v} enemies instead of one.",
			{"key": "nature_spring_trap", "values": [2.0, 3.0], "requires": "coilback"}],
		"r3c12": ["Hungry Venom", 2, "When a poisoned enemy dies, your poisons on it jump to an enemy up to {v} m away instead of {b:POISON_SPREAD}, and deal {v2}% more damage after jumping.",
			{"key": "nature_hungry_venom", "values": [15.0, 20.0], "values2": [10.0, 20.0]}],
		"r4c11": ["Fresh Host", 3, "A poison of yours that jumps to a new enemy lasts {v} sec longer there.",
			{"key": "nature_fresh_host", "values": [2.0, 4.0, 6.0]}],
		"r4c13": ["Double Dose", 3, "Your poisons on an enemy with two different ones of yours deal {v+b:TWO_POISONS_PCT}% more damage instead of {b:TWO_POISONS_PCT}%.",
			{"key": "nature_double_dose", "values": [3.0, 6.0, 9.0]}],
		"r5c12": ["Quick Venom", 3, "Your poisons deal their damage {v}% more often.",
			{"key": "nature_quick_venom", "values": [3.0, 6.0, 9.0]}],
		"r6c11": ["Swollen", 3, "Your poisons that are copied onto other enemies deal {v}% more damage there.",
			{"key": "nature_swollen", "values": [10.0, 20.0, 30.0]}],
		"r6c13": ["Full Brew", 3, "Your direct hits deal {v}% more damage to Steeped enemies.",
			{"key": "nature_full_brew", "values": [3.0, 6.0, 9.0]}],
		"r7c12": ["Full Glands", 3, "While you have Venom Flow, each tick of your poisons gives {v} more Venom.",
			{"key": "nature_full_glands", "values": [0.5, 1.0, 1.5]}],
		"r8c11": ["Spare Venom", 3, "Spending Venom has a {v}% chance to give half of it back.",
			{"key": "nature_spare_venom", "values": [10.0, 20.0, 30.0]}],
		"r8c12": ["Running Venom", 3, "While you have Venom Flow, your bow shots deal {v}% more damage.",
			{"key": "nature_running_venom", "values": [3.0, 6.0, 9.0]}],
		"r8c13": ["Dragging Feet", 3, "Your bow shots deal {v}% more damage to enemies you slowed.",
			{"key": "nature_dragging_feet", "values": [4.0, 8.0, 12.0]}],
		"r9c11": ["Dripping Tips", 3, "Your auto-shots have a {v}% chance to add {b:DRIPPING_TIPS_TIME} sec to your poisons on the target.",
			{"key": "nature_dripping_tips", "values": [10.0, 20.0, 30.0]}],
		"r9c12": ["Final Bite", 3, "Your poisons deal {v}% more damage to enemies below {b:FINAL_BITE_HEALTH_PCT}% health.",
			{"key": "nature_final_bite", "values": [5.0, 10.0, 15.0]}],
		"r9c13": ["First Bite", 2, "Your first poison on an enemy that has none of yours goes on {v}% stronger.",
			{"key": "nature_first_bite", "values": [10.0, 20.0]}],
		"r10c12": ["Soaked Through", 5, "Your poisons on a Steeped enemy deal {v+b:STEEPED_PCT}% more damage instead of {b:STEEPED_PCT}%.",
			{"key": "nature_soaked_through", "values": [2.0, 4.0, 6.0, 8.0, 10.0],
			"capstone": "While you have Venom Flow, each tick of your poisons on a Steeped enemy gives {b:SOAKED_THROUGH_VENOM} more Venom."}],
	},
	"martial": {
		# The ribbon layout (GROUPS): the Wheel (warrior) in columns 1-3, the Rogue in
		# 4-6, the open talents on the spine (column 7), the Brawler (tank) in 8-10 and the
		# Sharpshooter (archer) in 11-13. Rows 1-9 hold 18 talents per spec in its shape
		# (SHAPES); row 10 its
		# 5-rank capstone, which needs Balance.CAPSTONE_GATE points in the spec. Most key
		# off the spec's own words (Cracks, Flow, Bruise, Overcut...); few need one ability.
		# Code: each spec's component in scripts/player/ (martial_wheel.gd, martial_rogue.gd,
		# martial_brawler.gd, martial_sharpshooter.gd); the open talents and the hits'
		# bonuses: martial_talents_open.gd.
		# --- The Wheel.
		"r1c2": ["Hard Break", 4, "Your finishers deal {v}% more damage.",
			{"key": "martial_hard_break", "values": [5.0, 10.0, 15.0, 15.0],
			"capstone": "A finisher that breaks a weapon with {b:HARD_BREAK_CRACKS} or more Cracks gives you {b:HARD_BREAK_FURY} Fury."}],
		"r2c1": ["Iron Grip", 3, "Your Fillers give you {v} more Fury.",
			{"key": "martial_iron_grip", "values": [2.0, 4.0, 6.0]}],
		"r2c3": ["Well Drilled", 2, "Your Weapon Arts add {v} Cracks to the weapon you hold.",
			{"key": "martial_well_drilled", "values": [1.0, 2.0]}],
		"r3c1": ["Heavy Hands", 3, "Your Heavy Fillers deal {v}% more damage.",
			{"key": "martial_heavy_hands", "values": [5.0, 10.0, 15.0]}],
		"r3c3": ["Fresh Steel", 2, "A weapon that flies into your hands already has {v} Cracks on it.",
			{"key": "martial_fresh_steel", "values": [1.0, 2.0]}],
		"r4c1": ["Sharp Fragments", 3, "Each Crack on the weapon you hold gives you {v}% critical strike chance.",
			{"key": "martial_sharp_fragments", "values": [0.5, 1.0, 1.5]}],
		"r4c2": ["Wide Cleave", 2, "Axe Cleave, the rider of the {n:wheelgreataxe}, hits {v} more enemies near the target.",
			{"key": "martial_wide_cleave", "values": [1.0, 2.0], "requires": "wheelgreataxe"}],
		"r4c3": ["Weight Behind It", 3, "Your ability hits deal {v}% more damage for each use the weapon you hold has already taken.",
			{"key": "martial_weight_behind_it", "values": [1.0, 2.0, 3.0]}],
		"r5c1": ["Keen Edge", 3, "While you hold the {n:wheelgreatsword}, your critical strikes deal {v}% more damage.",
			{"key": "martial_keen_edge", "values": [7.0, 13.0, 20.0], "requires": "wheelgreatsword"}],
		"r5c3": ["Breaking Point", 3, "The ability that takes a weapon's last use deals {v}% more damage.",
			{"key": "martial_breaking_point", "values": [10.0, 20.0, 30.0]}],
		"r6c2": ["Twice Over", 3, "While you hold the {n:wheelhalberd}, each of your ability hits has a {v+b:HALBERD_AGAIN_PCT}% chance to hit again instead of {b:HALBERD_AGAIN_PCT}%.",
			{"key": "martial_twice_over", "values": [3.0, 7.0, 10.0], "requires": "wheelhalberd"}],
		"r6c1": ["Ringing Blows", 3, "Your rider hits (Axe Cleave and Second Hit) give you {v} Fury each.",
			{"key": "martial_ringing_blows", "values": [1.0, 2.0, 3.0]}],
		"r6c3": ["Rattled", 3, "While you hold the {n:wheelmaul}, your hits build {v}% more Stagger.",
			{"key": "martial_rattled", "values": [17.0, 33.0, 50.0], "requires": "wheelmaul"}],
		"r7c1": ["Off Balance", 3, "Your hits deal {v}% more damage to an enemy you have knocked down.",
			{"key": "martial_off_balance", "values": [5.0, 10.0, 15.0]}],
		"r7c3": ["Spare Parts", 3, "When a weapon of yours breaks, you gain {v} Fury for each Crack it had.",
			{"key": "martial_spare_parts", "values": [1.0, 2.0, 3.0]}],
		"r8c1": ["Big Swing", 2, "Your Heavy Fillers have a {v}% chance to add one more Crack.",
			{"key": "martial_big_swing", "values": [25.0, 50.0]}],
		"r8c3": ["Clean Swap", 3, "For {b:CLEAN_SWAP_TIME} sec after a weapon of yours breaks, your abilities deal {v}% more damage.",
			{"key": "martial_clean_swap", "values": [4.0, 8.0, 12.0]}],
		"r9c2": ["Gather Pace", 2, "The cooldowns of your Weapon Arts are {v}% shorter.",
			{"key": "martial_gather_pace", "values": [10.0, 20.0]}],
		"r10c2": ["Turning Wheel", 5, "Each weapon of your Wheel that breaks makes you deal {v}% more damage for {b:TURNING_WHEEL_TIME} sec. Each of the four weapons counts once, so all four together give four times as much.",
			{"key": "martial_turning_wheel", "values": [0.5, 1.0, 1.5, 2.0, 2.5]}],
		# --- The Rogue.
		"r1c4": ["Clean Kill", 4, "Your Kill forms deal {v}% more damage.",
			{"key": "martial_clean_kill", "values": [5.0, 10.0, 15.0, 15.0],
			"capstone": "{n:closeitout} leaves you {b:CLEAN_KILL_FLOW} Flow."}],
		"r1c6": ["Thrift", 3, "Your abilities that cost Energy cost {v} less.",
			{"key": "martial_thrift", "values": [1.0, 2.0, 3.0]}],
		"r2c4": ["In and Out", 2, "A hit from a different range than your last one gives {v+b:FLOW_SWITCH} more Flow instead of {b:FLOW_SWITCH}.",
			{"key": "martial_in_and_out", "values": [1.0, 2.0]}],
		"r2c6": ["Spare Knives", 2, "Up to {v+b:DAGGER_MAX} of your daggers can stick in one enemy instead of {b:DAGGER_MAX}.",
			{"key": "martial_spare_knives", "values": [1.0, 2.0]}],
		"r3c4": ["Barbed", 3, "Your stuck daggers deal {v}% more damage when they are ripped out.",
			{"key": "martial_barbed", "values": [20.0, 40.0, 60.0]}],
		"r3c6": ["Thrown Weight", 3, "Your thrown hits deal {v}% more damage.",
			{"key": "martial_thrown_weight", "values": [5.0, 10.0, 15.0]}],
		"r4c4": ["Steady Pace", 3, "Your Flow lasts {v+b:FLOW_HOLD} sec without a hit before it starts to drop, instead of {b:FLOW_HOLD}.",
			{"key": "martial_steady_pace", "values": [0.7, 1.3, 2.0]}],
		"r4c5": ["Close Work", 3, "Your melee ability hits deal {v}% more damage.",
			{"key": "martial_close_work", "values": [5.0, 10.0, 15.0]}],
		"r4c6": ["Mix It Up", 3, "In a Kill window, each Kill form that differs from the one before it adds {v+b:KILL_VARIETY} sec to the window instead of {b:KILL_VARIETY} (still up to {b:KILL_VARIETY_MAX} sec in all).",
			{"key": "martial_mix_it_up", "values": [0.15, 0.35, 0.5]}],
		"r5c5": ["Fresh Legs", 3, "Your critical strikes in a Kill window give you {v+b:KILL_CRIT_ENERGY} Energy back instead of {b:KILL_CRIT_ENERGY}.",
			{"key": "martial_fresh_legs", "values": [2.0, 4.0, 6.0]}],
		"r6c4": ["Deep Flow", 2, "Your Flow goes up to {v+b:FLOW_MAX} stacks instead of {b:FLOW_MAX}.",
			{"key": "martial_deep_flow", "values": [1.0, 2.0]}],
		"r6c6": ["Hot Start", 3, "Your Kill windows open {v} sec longer.",
			{"key": "martial_hot_start", "values": [0.5, 1.0, 1.5]}],
		"r7c4": ["Easy Pickings", 3, "Your hits deal {v}% more damage to an enemy with {b:EASY_PICKINGS_DAGGERS} or more of your daggers stuck in it.",
			{"key": "martial_easy_pickings", "values": [5.0, 10.0, 15.0]}],
		"r7c6": ["Footloose", 3, "A hit from a different range than your last one also gives you {v} Energy.",
			{"key": "martial_footloose", "values": [3.0, 6.0, 9.0]}],
		"r8c4": ["Finish Strong", 3, "{n:closeitout} deals {v}% more damage.",
			{"key": "martial_finish_strong", "values": [10.0, 20.0, 30.0], "requires": "closeitout"}],
		"r8c6": ["Cold Read", 2, "After a Kill window ends, your next {v} Rogue ability hits build twice as much Flow.",
			{"key": "martial_cold_read", "values": [1.0, 2.0]}],
		"r9c4": ["Light Fingers", 2, "{n:snatch} has a {v}% chance to lift two things instead of one.",
			{"key": "martial_light_fingers", "values": [25.0, 50.0], "requires": "snatch"}],
		"r9c6": ["Pressure Point", 3, "Outside a Kill window, your critical strikes have a {v}% chance to give you one more Flow.",
			{"key": "martial_pressure_point", "values": [10.0, 20.0, 30.0]}],
		"r10c5": ["In the Zone", 5, "Each stack of your Flow also gives you {v}% critical strike chance. In a Kill window, the Flow you spent on it counts.",
			{"key": "martial_in_the_zone", "values": [0.1, 0.2, 0.3, 0.4, 0.5]}],
		# --- The open talents (Martial in theme, useful to anyone).
		"r1c7": ["Weapon Training", 3, "Your auto-attacks deal {v}% more damage.",
			{"key": "martial_weapon_training", "values": [4.0, 8.0, 12.0]}],
		"r2c7": ["Conditioning", 3, "Increases your maximum health by {v}%.",
			{"key": "martial_conditioning", "values": [2.0, 4.0, 6.0], "stats": {"max_health%": 2.0}}],
		"r3c7": ["Keen Strikes", 3, "Your ability critical strikes deal {v}% more damage.",
			{"key": "martial_keen_strikes", "values": [3.0, 6.0, 9.0]}],
		"r4c7": ["Hardy", 3, "Your natural health regeneration is {v}% faster.",
			{"key": "martial_hardy", "values": [10.0, 20.0, 30.0]}],
		"r5c7": ["Catch Your Breath", 2, "When you drop below {b:CATCH_BREATH_HEALTH_PCT}% health, you heal over time for {v}% of your maximum health over {b:CATCH_BREATH_TIME} sec. Once every {b:CATCH_BREATH_COOLDOWN} sec.",
			{"key": "martial_catch_your_breath", "values": [10.0, 20.0]}],
		"r6c7": ["Footing", 2, "You move {v}% faster.",
			{"key": "martial_footing", "values": [3.0, 6.0], "stats": {"move_speed": 3.0}}],
		"r8c7": ["Grit", 2, "While you are below {b:GRIT_HEALTH_PCT}% health, you deal {v}% more damage.",
			{"key": "martial_grit", "values": [3.0, 6.0]}],
		"r9c7": ["Pinned Down", 2, "{n:pintheshadow} takes {v+b:PIN_SHADOW_HITS} hits to shake loose instead of {b:PIN_SHADOW_HITS}, and lasts {v2} sec longer.",
			{"key": "martial_pinned_down", "values": [1.0, 2.0], "values2": [2.0, 4.0], "requires": "pintheshadow"}],
		# --- The Brawler.
		"r1c8": ["Soak It Up", 4, "{v+b:BRUISE_PCT}% of each hit you take goes into your Bruise instead of {b:BRUISE_PCT}%.",
			{"key": "martial_soak_it_up", "values": [2.0, 4.0, 6.0, 6.0],
			"capstone": "Shake Off clears {b:SOAK_IT_UP_SHAKE_OFF}% of your Bruise instead of {b:SHAKE_OFF_PCT}%."}],
		"r1c10": ["Quick Feet", 3, "Your strikes give you {v} more Fury.",
			{"key": "martial_quick_feet", "values": [1.0, 2.0, 3.0]}],
		"r1c9": ["Tight Clinch", 3, "Clinch, from {n:elbow}, lasts {v+b:CLINCH_TIME} sec instead of {b:CLINCH_TIME}.",
			{"key": "martial_tight_clinch", "values": [0.7, 1.3, 2.0], "requires": "elbow"}],
		"r2c8": ["Heavy Bag", 3, "Your strong moves (a chain of three different strikes) deal {v}% more damage.",
			{"key": "martial_heavy_bag", "values": [5.0, 10.0, 15.0]}],
		"r2c9": ["Soft Catch", 3, "{v}% of a hit you catch with {n:catch} still goes into your Bruise instead of landing at once.",
			{"key": "martial_soft_catch", "values": [17.0, 33.0, 50.0], "requires": "catch"}],
		"r2c10": ["Calluses", 3, "Your Bruise ticks give you {v}% more Fury.",
			{"key": "martial_calluses", "values": [10.0, 20.0, 30.0]}],
		"r3c9": ["Knockout", 3, "Haymaker, from {n:punch}, deals {v}% more damage.",
			{"key": "martial_knockout", "values": [10.0, 20.0, 30.0], "requires": "punch"}],
		"r3c8": ["Wide Stance", 3, "Your Sweep and Roundhouse reach {v} m further.",
			{"key": "martial_wide_stance", "values": [0.7, 1.3, 2.0]}],
		"r3c10": ["Slow Burn", 2, "Your Bruise is dealt to you over {v+b:BRUISE_TIME} sec instead of {b:BRUISE_TIME}.",
			{"key": "martial_slow_burn", "values": [1.5, 3.0]}],
		"r4c9": ["Counter Puncher", 3, "Your Catch strings (Turn It Around, Throw, Reversal and Takedown) deal {v}% more damage.",
			{"key": "martial_counter_puncher", "values": [10.0, 20.0, 30.0], "requires": "catch"}],
		"r4c8": ["Crowd Work", 3, "Your Sweep and Roundhouse give you {v} Fury for each enemy they hit, up to {b:CROWD_WORK_MAX} enemies.",
			{"key": "martial_crowd_work", "values": [2.0, 4.0, 6.0]}],
		"r4c10": ["Get Up", 2, "Your Shake Off also heals you for {v}% of your maximum health.",
			{"key": "martial_get_up", "values": [3.0, 6.0]}],
		"r5c9": ["Bad Intentions", 3, "Your chain moves make {v}% more threat.",
			{"key": "martial_bad_intentions", "values": [10.0, 20.0, 30.0]}],
		"r6c9": ["Hardened", 2, "While your Bruise holds more than {b:HARDENED_BRUISE_PCT}% of your maximum health, you take {v}% less damage.",
			{"key": "martial_hardened", "values": [3.0, 6.0]}],
		"r7c9": ["Iron Chin", 3, "While you have an enemy in your Clinch, you take {v}% less damage from every enemy.",
			{"key": "martial_iron_chin", "values": [2.0, 4.0, 6.0]}],
		"r8c9": ["Last Laugh", 3, "Your Haymaker clears {v}% of your Bruise.",
			{"key": "martial_last_laugh", "values": [5.0, 10.0, 15.0]}],
		"r9c10": ["Back Up", 3, "Your Shake Off gives you {v} Fury.",
			{"key": "martial_back_up", "values": [5.0, 10.0, 15.0]}],
		"r9c8": ["Ground Game", 2, "Your Throw and Takedown keep enemies down {v} sec longer.",
			{"key": "martial_ground_game", "values": [0.5, 1.0]}],
		"r10c9": ["Scar Tissue", 5, "Your Bruise deals {v}% less damage to you.",
			{"key": "martial_scar_tissue", "values": [2.0, 4.0, 6.0, 8.0, 10.0]}],
		# --- The Sharpshooter.
		"r1c12": ["Full Draw", 4, "{n:heavydraw} deals {v}% more damage.",
			{"key": "martial_full_draw", "values": [5.0, 10.0, 15.0, 15.0], "requires": "heavydraw",
			"capstone": "{n:heavydraw} brings your other shots back {b:FULL_DRAW_CUT} sec sooner instead of {b:SHARP_HEAVY_CUT}."}],
		"r1c11": ["Quick Release", 3, "The time your shots take off your other shots is {v}% longer.",
			{"key": "martial_quick_release", "values": [5.0, 10.0, 15.0]}],
		"r1c13": ["Broadhead", 3, "{n:pierce}'s line is {v} m wider.",
			{"key": "martial_broadhead", "values": [0.5, 1.0, 1.5], "requires": "pierce"}],
		"r2c12": ["Deep Hold", 2, "Your Overcut goes up to {v+b:OVERCUT_MAX} sec instead of {b:OVERCUT_MAX}.",
			{"key": "martial_deep_hold", "values": [2.5, 5.0]}],
		"r3c11": ["Patience", 3, "Overcut gives {v+b:OVERCUT_PCT}% more damage per second instead of {b:OVERCUT_PCT}% (still up to {b:OVERCUT_MAX} sec).",
			{"key": "martial_patience", "values": [1.0, 2.0, 3.0]}],
		"r3c13": ["On a Roll", 3, "Each stack of your Streak gives {v+b:STREAK_PCT}% more damage instead of {b:STREAK_PCT}%.",
			{"key": "martial_on_a_roll", "values": [0.2, 0.4, 0.6]}],
		"r4c12": ["Extra Arrows", 2, "{n:spread} shoots {v} more arrows. Each one brings {n:heavydraw} back sooner too.",
			{"key": "martial_extra_arrows", "values": [1.0, 2.0], "requires": "spread"}],
		"r4c11": ["Lucky Shot", 3, "Your shots that critically strike also take {v} sec off each of your other shots.",
			{"key": "martial_lucky_shot", "values": [1.0, 2.0, 3.0]}],
		"r4c13": ["No Letup", 3, "Your Streak lasts {v+b:STREAK_HOLD} sec without a shot instead of {b:STREAK_HOLD}.",
			{"key": "martial_no_letup", "values": [0.7, 1.3, 2.0]}],
		"r5c11": ["Long Range", 3, "Your shots deal {v}% more damage for every {b:LONG_RANGE_STEP} m the target is beyond {b:LONG_RANGE_FROM} m.",
			{"key": "martial_long_range", "values": [1.0, 2.0, 3.0]}],
		"r5c13": ["Easy Release", 2, "{n:loose} takes away a third / a quarter of your Streak instead of half.",
			{"key": "martial_easy_release", "values": [3.0, 4.0], "requires": "loose"}],
		"r6c11": ["Waiting Game", 3, "A shot of yours gains {v} sec of Overcut for every {b:WAITING_GAME_TIME} sec it stays ready.",
			{"key": "martial_waiting_game", "values": [1.0, 2.0, 3.0]}],
		"r6c12": ["Clean Release", 3, "Firing a shot that holds {b:CLEAN_RELEASE_OVERCUT} sec or more of Overcut gives you {v} Streak.",
			{"key": "martial_clean_release", "values": [1.0, 2.0, 3.0]}],
		"r6c13": ["Long Streak", 2, "Your Streak goes up to {v+b:STREAK_MAX} instead of {b:STREAK_MAX}.",
			{"key": "martial_long_streak", "values": [1.0, 2.0]}],
		"r7c11": ["Second Arrow", 3, "Your engine shots have a {v}% chance to loose a second arrow that deals {b:SECOND_ARROW_PCT}% of their damage.",
			{"key": "martial_second_arrow", "values": [5.0, 10.0, 15.0]}],
		"r7c13": ["Hard Target", 3, "Your shots deal {v}% more damage to enemies above {b:HARD_TARGET_HEALTH}% health.",
			{"key": "martial_hard_target", "values": [5.0, 10.0, 15.0]}],
		"r8c12": ["Run It Back", 3, "When a cut of yours resets a shot fully, it has a {v}% chance to also take {b:RUN_IT_BACK_CUT} sec off the next shot in the chain.",
			{"key": "martial_run_it_back", "values": [10.0, 20.0, 30.0]}],
		"r9c12": ["Hold Steady", 2, "While one of your shots holds {b:HOLD_STEADY_OVERCUT} sec or more of Overcut, your other shots deal {v}% more damage.",
			{"key": "martial_hold_steady", "values": [4.0, 8.0]}],
		"r10c12": ["Keen Eye", 5, "Your Sharpshooter shots have {v}% more critical strike chance.",
			{"key": "martial_keen_eye", "values": [1.0, 2.0, 3.0, 4.0, 5.0]}],
	},
	"holy": {
		# The ribbon layout (GROUPS, 13 columns): Choir of One (the Hymns healer) in
		# columns 1-3, Censer Bearer (the tank) in 4-6, the open talents on the spine
		# (column 7), Line of Light (the Prisms healer) in 8-10 and Lightstring (the bow)
		# in 11-13. Rows 1-9 hold 18 talents per spec in its shape (SHAPES); row 10 its
		# 5-rank capstone, which needs Balance.CAPSTONE_GATE points in the spec. Most key
		# off the book's words (Hymns, Verses, booms, Full Choir; Incense, motes of light,
		# blocks; prisms, beams, shattering; gold prisms, Refraction, bow shots...).
		# Code: each spec's component in scripts/player/ (holy_hymns.gd, holy_censer.gd,
		# holy_prisms.gd, holy_lightstring.gd); hit and heal bonuses and the open
		# talents: holy_talents.gd.
		# --- Choir of One (the Hymns).
		"r1c2": ["Many Voices", 2, "A heal of yours that lands on {b:MANY_VOICES_ALLIES} or more allies at once gives you a Chorus Verse, at most once every {v} sec. Chorus's extra heals count.",
			{"key": "holy_many_voices", "values": [6.0, 3.0]}],
		"r2c1": ["Watchful", 2, "An ally standing in your Vigil who takes a hit of {b:WATCHFUL_HIT_PCT}% of their maximum health or more gives you a Vigil Verse, at most once every {v} sec.",
			{"key": "holy_watchful", "values": [6.0, 3.0]}],
		"r2c3": ["Mercy's Ear", 2, "Healing an ally below {b:MERCYS_EAR_HEALTH_PCT}% health gives you a Mercy Verse, at most once every {v} sec.",
			{"key": "holy_mercys_ear", "values": [6.0, 3.0]}],
		"r3c2": ["Choir Loft", 2, "Chorus's extra heals reach {v} more allies.",
			{"key": "holy_choir_loft", "values": [1.0, 2.0]}],
		"r4c1": ["Night Watch", 3, "Vigil makes allies take {v+b:VIGIL_DR_PCT}% less damage instead of {b:VIGIL_DR_PCT}%.",
			{"key": "holy_night_watch", "values": [1.0, 2.0, 3.0]}],
		"r4c3": ["Key Change", 3, "Singing a Hymn without a boom keeps {v} of your Verses. A boom still spends them all.",
			{"key": "holy_key_change", "values": [1.0, 2.0, 3.0]}],
		"r5c1": ["Open Doors", 4, "{n:shelter}'s shield absorbs {v}% more.",
			{"key": "holy_open_doors", "values": [10.0, 20.0, 30.0, 40.0], "requires": "shelter",
			"capstone": "Its cooldown is {b:OPEN_DOORS_COOLDOWN} sec."}],
		"r5c3": ["Swelling Chorus", 3, "Chorus's extra heals heal {v}% more.",
			{"key": "holy_swelling_chorus", "values": [10.0, 20.0, 30.0], "requires": "singchorus"}],
		"r6c1": ["Warded Song", 3, "The shield Vigil leaves on the allies you heal is {v}% larger.",
			{"key": "holy_warded_song", "values": [33.0, 67.0, 100.0]}],
		"r6c3": ["Rising Voice", 3, "Your booms are {v}% stronger.",
			{"key": "holy_rising_voice", "values": [5.0, 10.0, 15.0]}],
		"r7c1": ["Long Note", 3, "Bulwark of Song lasts {v} sec longer.",
			{"key": "holy_long_note", "values": [1.0, 2.0, 3.0]}],
		"r7c3": ["Long Echo", 3, "{n:reprise} repeats the boom at {v}% instead of {b:REPRISE_PCT}%.",
			{"key": "holy_long_echo", "values": [45.0, 50.0, 55.0], "requires": "reprise"}],
		"r8c1": ["Sheltering Light", 3, "Your Holy shields absorb {v}% more: Shelter, Vigil's Ward, Prism Ward and Overflowing's shield.",
			{"key": "holy_sheltering_light", "values": [10.0, 20.0, 30.0]}],
		"r8c2": ["Tender Mercy", 3, "While you sing Mercy, your heals on a single ally heal {v}% more on top.",
			{"key": "holy_tender_mercy", "values": [4.0, 8.0, 12.0]}],
		"r8c3": ["Full Voice", 2, "A Full Choir gives you back {v} more Verses.",
			{"key": "holy_full_voice", "values": [1.0, 2.0]}],
		"r9c1": ["Held Note", 2, "Out of combat, your Verses fade one every {v} sec instead of every {b:VERSE_DRAIN_EVERY}.",
			{"key": "holy_held_note", "values": [4.0, 6.0]}],
		"r9c2": ["Mercy Seat", 3, "Benediction heals {v}% more on an ally below {b:MERCY_SEAT_HEALTH_PCT}% health.",
			{"key": "holy_mercy_seat", "values": [10.0, 20.0, 30.0]}],
		"r9c3": ["Breath Between", 3, "Each of your booms gives you back {v}% of your maximum mana.",
			{"key": "holy_breath_between", "values": [1.0, 2.0, 3.0]}],
		"r10c2": ["Radiance", 5, "Your Holy heals heal {v}% more.",
			{"key": "holy_radiance", "values": [2.0, 4.0, 6.0, 8.0, 10.0],
			"capstone": "A boom whose {b:VERSE_MAX} spent Verses all suit its Hymn is {b:RADIANCE_MATCH_PCT}% stronger (Bulwark of Song: lasts {b:RADIANCE_MATCH_PCT}% longer)."}],
		# --- Censer Bearer (the Censer).
		"r1c5": ["Heavy Chain", 2, "{n:censerswing} gives {v} more Incense.",
			{"key": "holy_heavy_chain", "values": [1.0, 2.0], "requires": "censerswing"}],
		"r2c5": ["Absolution", 3, "{n:absolve} heals {v}% more.",
			{"key": "holy_absolution", "values": [10.0, 20.0, 30.0], "requires": "absolve"}],
		"r3c4": ["Mote Magnet", 2, "You pick up motes of light from {v} m further away.",
			{"key": "holy_mote_magnet", "values": [1.0, 2.0]}],
		"r3c5": ["Wide Arc", 3, "{n:hallowedarc} reaches {v} m further.",
			{"key": "holy_wide_arc", "values": [0.7, 1.3, 2.0], "requires": "hallowedarc"}],
		"r3c6": ["Bright Barrier", 3, "Each stack of Incense gives {v}% more Block.",
			{"key": "holy_bright_barrier", "values": [0.02, 0.04, 0.06]}],
		"r4c4": ["Lingering Light", 2, "Your motes of light last {v} sec longer.",
			{"key": "holy_lingering_light", "values": [3.0, 6.0]}],
		"r4c6": ["Bright Motes", 3, "Your motes of light heal {v}% more.",
			{"key": "holy_bright_motes", "values": [17.0, 33.0, 50.0]}],
		"r5c4": ["Offering", 3, "Your abilities that spend Incense deal or heal {v}% more.",
			{"key": "holy_offering", "values": [5.0, 10.0, 15.0]}],
		"r5c6": ["Full Censer", 3, "While you have {b:FULL_CENSER_INCENSE} or more Incense, you take {v}% less damage.",
			{"key": "holy_full_censer", "values": [2.0, 4.0, 6.0]}],
		"r6c4": ["Heavy Smoke", 3, "The Holy damage your Incense deals around you is {v}% higher.",
			{"key": "holy_heavy_smoke", "values": [10.0, 20.0, 30.0]}],
		"r6c6": ["Unbroken", 3, "{n:unfallen} lasts {v} sec longer.",
			{"key": "holy_unbroken", "values": [0.7, 1.3, 2.0], "requires": "unfallen"}],
		"r7c4": ["Heavy Motes", 3, "Your motes of light give {v} more Incense.",
			{"key": "holy_heavy_motes", "values": [1.0, 2.0, 3.0]}],
		"r7c5": ["Deep Pour", 3, "{n:pourout} deals {v}% more damage.",
			{"key": "holy_deep_pour", "values": [10.0, 20.0, 30.0], "requires": "pourout",
			"capstone": "It drops motes of light worth {b:DEEP_POUR_MOTE_PCT}% of what it spent."}],
		"r7c6": ["Turned Aside", 3, "Each attack you block heals you for {v}% of your maximum health.",
			{"key": "holy_turned_aside", "values": [0.3, 0.6, 1.0]}],
		"r8c5": ["Cloying Smoke", 3, "Your censer abilities and your Incense make {v}% more threat.",
			{"key": "holy_cloying_smoke", "values": [5.0, 10.0, 15.0]}],
		"r9c4": ["Shaken Loose", 3, "Your censer abilities that knock motes of light loose have a {v}% chance to knock one more loose.",
			{"key": "holy_shaken_loose", "values": [10.0, 20.0, 30.0]}],
		"r9c5": ["Ringing Censer", 2, "Each attack you block gives you {v} more Incense.",
			{"key": "holy_ringing_censer", "values": [1.0, 2.0]}],
		"r9c6": ["Hold the Line", 3, "While you are below {b:HOLD_THE_LINE_HEALTH_PCT}% health, your Incense gives {v}% more Block.",
			{"key": "holy_hold_the_line", "values": [33.0, 67.0, 100.0]}],
		"r10c5": ["Censer's Weight", 5, "Your censer abilities, Incense and Bright Burst deal {v}% more damage.",
			{"key": "holy_censers_weight", "values": [3.0, 6.0, 9.0, 12.0, 15.0],
			"capstone": "While you have {b:INCENSE_MAX} Incense, they deal {b:CENSERS_WEIGHT_FULL_PCT}% more on top."}],
		# --- Open talents: themed to the book (grace, standing firm, light) but they work
		# with every book's spells, abilities, heals and shields (holy_talents.gd).
		"r1c7": ["Grace", 3, "Your heals on others heal {v}% more.",
			{"key": "holy_grace", "values": [2.0, 4.0, 6.0]}],
		"r2c7": ["Steadfast", 3, "Increases your Block chance by {v}%.",
			{"key": "holy_steadfast", "values": [2.0, 3.0, 4.0]}],
		"r3c7": ["Overflowing", 3, "{v}% of your overhealing becomes a shield on that ally for {b:OVERFLOWING_TIME} sec, up to {b:OVERFLOWING_CAP_PCT}% of their maximum health. A bigger one replaces a smaller one.",
			{"key": "holy_overflowing", "values": [10.0, 20.0, 30.0]}],
		"r4c7": ["Watchful Eye", 2, "Your heals on an ally who was hit in the last {b:WATCHFUL_EYE_WINDOW} sec heal {v}% more.",
			{"key": "holy_watchful_eye", "values": [10.0, 20.0]}],
		"r5c7": ["Second Breath", 2, "When a heal of yours lifts an ally from below {b:SECOND_BREATH_LOW_PCT}% to above {b:SECOND_BREATH_HIGH_PCT}% health, you get {v}% of your maximum mana back.",
			{"key": "holy_second_breath", "values": [1.0, 2.0]}],
		"r6c7": ["Penitent", 3, "After you take a hit worth {b:PENITENT_HIT_PCT}% of your maximum health, your next heal on yourself is {v}% stronger.",
			{"key": "holy_penitent", "values": [10.0, 20.0, 30.0]}],
		"r7c7": ["Candlelight", 3, "After you heal an ally other than yourself, your next spell or ability that deals damage within {b:CANDLELIGHT_TIME} sec deals {v}% more.",
			{"key": "holy_candlelight", "values": [4.0, 8.0, 12.0]}],
		"r8c7": ["First Light", 3, "For {b:FIRST_LIGHT_TIME} sec after you enter combat, your spells and abilities deal and heal {v}% more.",
			{"key": "holy_first_light", "values": [4.0, 8.0, 12.0]}],
		"r9c7": ["Zeal", 2, "After you use an ability with a cooldown of {b:ZEAL_COOLDOWN} sec or more, you move {v}% faster for {b:ZEAL_TIME} sec.",
			{"key": "holy_zeal", "values": [5.0, 10.0]}],
		# --- Line of Light (the Prisms).
		"r1c9": ["Wide Burst", 3, "Your prisms reach allies and enemies {v} m further when they shatter.",
			{"key": "holy_wide_burst", "values": [1.5, 2.5, 4.0], "requires": "shatterall"}],
		"r2c8": ["Quick Lance", 3, "{n:brightlance}'s cast is {v} sec shorter.",
			{"key": "holy_quick_lance", "values": [0.15, 0.35, 0.5], "requires": "brightlance"}],
		"r2c10": ["Steady Ray", 3, "{n:mendingray} heals {v}% more.",
			{"key": "holy_steady_ray", "values": [7.0, 13.0, 20.0], "requires": "mendingray"}],
		"r3c8": ["Clear Glass", 2, "Your beams pass through prisms up to {v} m further from their line.",
			{"key": "holy_clear_glass", "values": [0.5, 1.0]}],
		"r3c9": ["Prismatic Burst", 3, "Your shattering prisms deal {v}% more damage.",
			{"key": "holy_prismatic_burst", "values": [20.0, 40.0, 60.0], "requires": "shatterall"}],
		"r3c10": ["Deep Crystal", 3, "Your prisms hold {v}% more light.",
			{"key": "holy_deep_crystal", "values": [20.0, 40.0, 60.0]}],
		"r4c8": ["Quick Realign", 3, "{n:realign}'s cooldown is {v} sec shorter.",
			{"key": "holy_quick_realign", "values": [3.0, 7.0, 10.0], "requires": "realign"}],
		"r4c9": ["Thirsty Glass", 3, "Your beams charge your prisms {v}% more.",
			{"key": "holy_thirsty_glass", "values": [10.0, 20.0, 30.0]}],
		"r4c10": ["Sharp Facets", 2, "A heal is {v}% stronger for each prism it passes through, on top of the usual.",
			{"key": "holy_sharp_facets", "values": [5.0, 10.0]}],
		"r5c8": ["Clear Mind", 3, "Your Holy heals cost {v}% less mana.",
			{"key": "holy_clear_mind", "values": [3.0, 6.0, 9.0]}],
		"r5c10": ["Long Glass", 2, "Your prisms of both colours last {v} sec longer.",
			{"key": "holy_long_glass", "values": [15.0, 30.0]}],
		"r6c8": ["Bright Shards", 3, "Each of your prisms that shatters gives you back {v}% of your maximum mana.",
			{"key": "holy_bright_shards", "values": [0.3, 0.6, 1.0]}],
		"r6c10": ["Polish", 3, "A prism you move with {n:moveprism} or {n:realign} gains {v}% of the light it can hold.",
			{"key": "holy_polish", "values": [10.0, 20.0, 30.0]}],
		"r7c8": ["Aftershine", 3, "For {b:AFTERSHINE_TIME} sec after a shattering prism heals an ally, your heals on them heal {v}% more.",
			{"key": "holy_aftershine", "values": [3.0, 6.0, 9.0]}],
		"r7c10": ["Lifeline", 3, "Heals that reach an ally through your beam heal {v}% more on allies below {b:LIFELINE_HEALTH_PCT}% health.",
			{"key": "holy_lifeline", "values": [7.0, 13.0, 20.0]}],
		"r8c8": ["Focused Light", 3, "A shattering prism with only one ally near it heals them {v}% more.",
			{"key": "holy_focused_light", "values": [10.0, 20.0, 30.0]}],
		"r8c10": ["Last Glint", 2, "Your white prisms that run out shatter on their own with {v}% of their light.",
			{"key": "holy_last_glint", "values": [50.0, 100.0]}],
		"r9c9": ["Full Glass", 3, "A heal whose beam passes through a full prism heals {v}% more.",
			{"key": "holy_full_glass", "values": [5.0, 10.0, 15.0]}],
		"r10c9": ["Brilliance", 5, "Your shattering prisms heal {v}% more.",
			{"key": "holy_brilliance", "values": [4.0, 8.0, 12.0, 16.0, 20.0],
			"capstone": "A heal whose beam passes through {b:BRILLIANCE_PRISMS} of your prisms is {b:BRILLIANCE_PCT}% stronger."}],
		# --- Lightstring (the bow, gold prisms).
		"r1c11": ["Full Quiver", 3, "{n:prismarrow} recharges {v} sec faster.",
			{"key": "holy_full_quiver", "values": [1.5, 2.5, 4.0], "requires": "prismarrow"}],
		"r1c12": ["Glimmering", 3, "Your instant bow shots deal {v}% more damage.",
			{"key": "holy_glimmering", "values": [5.0, 10.0, 15.0]}],
		"r1c13": ["Steady Aim", 3, "{n:refractingshot}'s cast is {v} sec shorter.",
			{"key": "holy_steady_aim", "values": [0.15, 0.35, 0.5], "requires": "refractingshot"}],
		"r2c11": ["Deep Burn", 3, "{n:sunlitarrow} deals {v}% more damage from the light it drains.",
			{"key": "holy_deep_burn", "values": [10.0, 20.0, 30.0], "requires": "sunlitarrow",
			"capstone": "It leaves {b:DEEP_BURN_KEEP_PCT}% of the light in each prism."}],
		"r2c13": ["Wide Fan", 2, "Your refracted arrows find enemies up to {v} m further from the prism.",
			{"key": "holy_wide_fan", "values": [2.0, 4.0]}],
		"r3c12": ["Split Light", 3, "Your refracted arrows deal {v}% more damage.",
			{"key": "holy_split_light", "values": [10.0, 20.0, 30.0]}],
		"r4c11": ["Long Volley", 3, "{n:spectrumvolley} lasts {v} sec longer.",
			{"key": "holy_long_volley", "values": [1.5, 2.5, 4.0], "requires": "spectrumvolley"}],
		"r4c12": ["Wide Break", 3, "{n:prismbreaker} reaches {v} m further.",
			{"key": "holy_wide_break", "values": [1.5, 2.5, 4.0], "requires": "prismbreaker"}],
		"r4c13": ["Gilded", 3, "Your shots charge your gold prisms {v}% more.",
			{"key": "holy_gilded", "values": [10.0, 20.0, 30.0]}],
		"r5c12": ["Pinpoint", 3, "A shot that passes a gold prism with no other enemy near it is {v+b:REFRACT_FOCUS_PCT}% stronger instead of {b:REFRACT_FOCUS_PCT}%.",
			{"key": "holy_pinpoint", "values": [3.0, 6.0, 9.0]}],
		"r6c12": ["Burnished", 3, "Your Holy damage is increased by {v}%.",
			{"key": "holy_burnished", "values": [2.0, 4.0, 6.0]}],
		"r7c12": ["Lined Up", 3, "A shot that passes through {b:LINED_UP_PRISMS} or more of your gold prisms deals {v}% more damage.",
			{"key": "holy_lined_up", "values": [4.0, 8.0, 12.0]}],
		"r8c11": ["Bright Quiver", 2, "Your auto-shots charge your gold prisms {v}% more.",
			{"key": "holy_bright_quiver", "values": [50.0, 100.0]}],
		"r8c12": ["Light Draw", 3, "Your Holy abilities that cost Energy cost {v}% less.",
			{"key": "holy_light_draw", "values": [3.0, 6.0, 9.0]}],
		"r8c13": ["Full Gold", 3, "The refracted arrows of a full gold prism deal {v}% more damage.",
			{"key": "holy_full_gold", "values": [10.0, 20.0, 30.0]}],
		"r9c11": ["Gilt Tips", 3, "Your auto-shots deal {v}% more damage.",
			{"key": "holy_gilt_tips", "values": [4.0, 8.0, 12.0]}],
		"r9c12": ["Dazzle", 3, "Your refracted arrows have {v}% more chance to critically strike.",
			{"key": "holy_dazzle", "values": [3.0, 6.0, 9.0]}],
		"r9c13": ["Sundown", 3, "Your bow shots deal {v}% more damage to enemies below {b:SUNDOWN_HEALTH_PCT}% health.",
			{"key": "holy_sundown", "values": [5.0, 10.0, 15.0]}],
		"r10c12": ["Sunsteel", 5, "Your Lightstring shots, refracted arrows and Spectrum Volley's arrows deal {v}% more damage.",
			{"key": "holy_sunsteel", "values": [3.0, 6.0, 9.0, 12.0, 15.0],
			"capstone": "Your gold prisms start with {b:SUNSTEEL_START_PCT}% of the light they can hold."}],
	},
}

# --- Links ------------------------------------------------------------------------
## [from, to]: maxing `from` unlocks `to` regardless of its row, so the next
## talent of an ability can be taken before its row opens. Each end is a talent
## "key" (it follows the talent when its slot changes) or a talent id.
## A line must not run behind another talent, and the bottom row has no links.
const LINKS := [
	# --- Every book is on the ribbon layout: straight down one column of a
	# spec's ribbon, over the rows its shape leaves empty there.
	["martial_twice_over", "martial_gather_pace"],       # the Wheel: Weapon Arts
	["martial_steady_pace", "martial_deep_flow"],        # Rogue: Flow
	["martial_mix_it_up", "martial_hot_start"],          # Rogue: Kill windows
	["martial_get_up", "martial_back_up"],               # Brawler: Shake Off
	["martial_clean_release", "martial_run_it_back"],    # Sharpshooter: cuts
	["fire_stoked_breath", "fire_lean_fuel"],            # Steady Flame: Fury
	["fire_clean_burn", "fire_stay_lit"],                # Steady Flame: spells that don't crit
	["fire_fuel_the_forge", "fire_heavy_hammer"],        # Slagforged: Fury from the forge
	["fire_banked_fire", "fire_overheat"],               # Forge Heat: Heat
	["fire_spreading_fire", "fire_fuel_run"],            # Pitch and Cinder: Ignites
	["frost_chilled_dmg", "frost_instinct"],             # Hard Winter: Chill, then Freeze
	["frost_instinct", "frost_cold_front"],              # Hard Winter: Frozen enemies
	["frost_thaw_water", "frost_meltdown"],              # Cold Comfort: thaw and melt
	["frost_long_glaze", "frost_long_dark"],             # Frostbitten Steel: lasting longer
	["frost_cold_fury", "frost_rime_pressure"],          # Glacier Wall: Ice Layers
	["frost_frost_fletching", "frost_splitting_arrow"],  # Winter Hunt: arrows on Chilled / Frozen
	["frost_rime_tips", "frost_numb_prey"],              # Winter Hunt: auto-shots
	["lightning_conductive", "lightning_conductor"],     # Live Current: critical strikes
	["lightning_deep_draw", "lightning_afterflow"],      # Live Current: spending all the Energy
	["lightning_afterspark", "lightning_light_load"],    # Stormdancer: auto-attacks
	["lightning_built_charge", "lightning_spinning_up"], # Stormdancer: Energy spent
	["lightning_counter_charge", "lightning_second_stroke"],   # Lightning Rod: Return Stroke
	["lightning_earth_return", "lightning_tempo"],       # Lightning Rod: parries
	["arcane_etched_darts", "arcane_sharp_mind"],        # Clockwork: Arcane spell crits
	["arcane_second_hand", "arcane_unwinding"],          # Clockwork: time off cooldowns
	["arcane_sharp_edges", "arcane_glass_dust"],         # Hall of Mirrors: shatters
	["arcane_quick_answer", "arcane_spare_copy"],        # Hall of Mirrors: dodges
	["arcane_last_copy", "arcane_crowded_room"],         # Hall of Mirrors: Reflections held
	["arcane_standing_ovation", "arcane_time_signature"],   # Second Act: replays
	["shadow_interest", "shadow_small_change"],     # The Breach: Call Due
	["shadow_shut_tight", "shadow_bitter_end"],     # The Breach: a closed Breach and its end
	["shadow_long_night", "shadow_take_it_with_you"],   # Pack of Two: a pair's time and its going
	["shadow_pincer", "shadow_again"],             # Pack of Two: Both At Once
	["shadow_long_thread", "shadow_spare_spool"],  # Strings Attached: Strings coming back
	["shadow_three_ply", "shadow_full_harness"],   # Strings Attached: three on one ally
	["nature_compost", "nature_bramble_burst"],      # Thornweaver: Thornshot's Mulch
	["nature_thick_mulch", "nature_well_rotted"],    # Thornweaver: patches lasting
	["nature_second_bud", "nature_pollen"],          # Shepherd: Blossoms given
	["nature_long_bloom", "nature_canopy"],          # Shepherd: Blossoms held
	["nature_groundswell", "nature_heavy_limbs"],    # Colossus: Fury built, then spent
	["nature_long_sap", "nature_brimming"],          # Colossus: Sap held
	["nature_slow_acting", "nature_fresh_host"],     # Venomstring: poisons lasting
	["nature_double_dose", "nature_full_brew"],      # Venomstring: mixing poisons
	["holy_many_voices", "holy_choir_loft"],        # Choir of One: Chorus
	["holy_watchful", "holy_night_watch"],          # Choir of One: Vigil
	["holy_wide_arc", "holy_deep_pour"],            # Censer Bearer: the censer's swing, then its pour
	["holy_heavy_motes", "holy_shaken_loose"],      # Censer Bearer: motes of light
	["holy_wide_burst", "holy_prismatic_burst"],    # Line of Light: shattering
	["holy_thirsty_glass", "holy_full_glass"],      # Line of Light: light stored
	["holy_deep_burn", "holy_long_volley"],         # Lightstring: the gold prisms' light, spent
	["holy_gilded", "holy_full_gold"],              # Lightstring: gold light
]

static var _db := {}
static var _keys := {}         # talent "key" -> talent id
static var _rows_cache := {}   # "cat:row" -> Array[String]
static var _group_cache := {}  # "cat:group" -> Array[String] (in_group; the talent data never changes)
static var _links: Array = []  # built from LINKS (tests may replace it)
static var _links_ready := false

static func layout(category: String) -> Array:
	return LAYOUTS.get(category, DEFAULT_LAYOUT)

# --- Spec groups (the ribbon layout) ----------------------------------------------------
# A book on the new layout has its specs side by side as column groups (GROUPS), each
# three columns wide and drawn as a bookmark ribbon whose talents (wax seals) form the
# spec's shape (SHAPES); the open talents sit on one column between them, drawn as beads
# on the book's spine thread. Rows still unlock globally; on top of that,
# a spec group's bottom-row talent (its capstone) needs Balance.CAPSTONE_GATE points
# spent in that group. The "Open" group (talents for any spec) has no gate. Books not
# in GROUPS keep the old 10 x COLUMNS grid until their own pass.

## Columns of a book's grid.
const GRID_COLUMNS := {"martial": 13, "fire": 13, "frost": 16, "lightning": 13, "arcane": 13, "shadow": 13, "nature": 13, "holy": 13}

## Book -> its groups: [name, first column, last column] (0-based, left to right).
const GROUPS := {
	"martial": [["The Wheel", 0, 2], ["Rogue", 3, 5], ["Open", 6, 6], ["Brawler", 7, 9], ["Sharpshooter", 10, 12]],
	"fire": [["Steady Flame", 0, 2], ["Slagforged", 3, 5], ["Open", 6, 6], ["Forge Heat", 7, 9], ["Pitch and Cinder", 10, 12]],
	"frost": [["Hard Winter", 0, 2], ["Cold Comfort", 3, 5], ["Open", 6, 6], ["Frostbitten Steel", 7, 9],
		["Glacier Wall", 10, 12], ["Winter Hunt", 13, 15]],
	"lightning": [["Live Current", 0, 2], ["Stormdancer", 3, 5], ["Open", 6, 6], ["Lightning Rod", 7, 9],
		["Stormstring", 10, 12]],
	"arcane": [["Clockwork", 0, 2], ["Hall of Mirrors", 3, 5], ["Open", 6, 6], ["Second Act", 7, 9],
		["Aetherstring", 10, 12]],
	"shadow": [["The Breach", 0, 2], ["Pack of Two", 3, 5], ["Open", 6, 6], ["Strings Attached", 7, 9],
		["Nightstring", 10, 12]],
	"nature": [["Thornweaver", 0, 2], ["Shepherd", 3, 5], ["Open", 6, 6], ["Colossus", 7, 9], ["Venomstring", 10, 12]],
	"holy": [["Choir of One", 0, 2], ["Censer Bearer", 3, 5], ["Open", 6, 6], ["Line of Light", 7, 9], ["Lightstring", 10, 12]],
}
## Specs not built yet (one ability so far): their ribbon holds only the talents they
## have, with no shape and no capstone until the spec is built.
const UNFINISHED_SPECS := ["Stormstring", "Aetherstring", "Nightstring"]
const OPEN_GROUP := "Open"
## Width of a spec's ribbon, in columns.
const RIBBON_COLUMNS := 3

## Spec group -> [its shape's name, rows 1-9 of its ribbon]. Each row holds the middle
## seal ("M"), the outer two ("LR") or all three ("LMR"); together they draw a symbol no
## other spec has. Row 10 is the capstone, alone in the middle. LAYOUTS follows these.
const SHAPES := {
	"Hard Winter": ["ice crystal", ["M", "LR", "LMR", "LR", "LR", "LR", "LMR", "LR", "M"]],
	"Cold Comfort": ["cross over a drop", ["M", "LMR", "M", "M", "LR", "LMR", "LMR", "LR", "LR"]],
	"Frostbitten Steel": ["sword", ["M", "LMR", "LR", "LR", "LR", "LR", "LR", "LMR", "M"]],
	"Glacier Wall": ["glacier", ["M", "M", "LR", "LR", "LR", "LMR", "LMR", "LMR", "M"]],
	"Winter Hunt": ["arrow", ["LR", "LMR", "LMR", "M", "M", "M", "LMR", "LMR", "M"]],
	"Steady Flame": ["flame", ["M", "LR", "M", "LR", "LMR", "LMR", "LMR", "LR", "M"]],
	"Slagforged": ["anvil", ["LMR", "LMR", "M", "M", "M", "M", "LR", "LMR", "LMR"]],
	"Forge Heat": ["hammer", ["LMR", "LMR", "LMR", "M", "M", "LR", "LR", "LR", "M"]],
	"Pitch and Cinder": ["rising arrow", ["M", "LMR", "LMR", "M", "M", "M", "LR", "LMR", "LMR"]],
	"The Wheel": ["wheel", ["M", "LR", "LR", "LMR", "LR", "LMR", "LR", "LR", "M"]],
	"Rogue": ["crossed daggers", ["LR", "LR", "LR", "LMR", "M", "LR", "LR", "LR", "LR"]],
	"Brawler": ["fist", ["LMR", "LMR", "LMR", "LMR", "M", "M", "M", "M", "LR"]],
	"Sharpshooter": ["scope", ["LMR", "M", "LR", "LMR", "LR", "LMR", "LR", "M", "M"]],
	"Live Current": ["storm cloud", ["LR", "LMR", "LMR", "LMR", "M", "LR", "M", "LR", "M"]],
	"Stormdancer": ["twin bolts", ["LR", "LR", "LMR", "LR", "LR", "M", "LR", "LR", "LR"]],
	"Lightning Rod": ["lightning rod", ["M", "LMR", "M", "LMR", "M", "M", "LR", "LMR", "LMR"]],
	"Clockwork": ["clock face", ["M", "LR", "LR", "LR", "LMR", "LMR", "LR", "LR", "M"]],
	"Hall of Mirrors": ["hand mirror", ["LMR", "LR", "LR", "LR", "LMR", "M", "M", "M", "LMR"]],
	"Second Act": ["stage curtains", ["LMR", "LR", "LR", "LR", "LR", "LR", "LR", "LR", "M"]],
	"The Breach": ["the pit", ["LMR", "LR", "LR", "LR", "M", "M", "LR", "LR", "LMR"]],
	"Pack of Two": ["paw print", ["LR", "M", "LR", "M", "LMR", "LMR", "LMR", "LR", "M"]],
	"Strings Attached": ["puppet cross", ["M", "LMR", "M", "LMR", "M", "LR", "LR", "LR", "LMR"]],
	"Thornweaver": ["bramble", ["LR", "M", "LR", "M", "LMR", "M", "LR", "LMR", "LMR"]],
	"Shepherd": ["flower", ["M", "LMR", "LMR", "M", "M", "LR", "LMR", "LR", "LR"]],
	"Colossus": ["oak", ["M", "LR", "LMR", "LMR", "LMR", "M", "M", "M", "LMR"]],
	"Venomstring": ["coiled snake", ["LR", "LMR", "M", "LR", "M", "LR", "M", "LMR", "LMR"]],
	"Choir of One": ["bell", ["M", "LR", "M", "LR", "LR", "LR", "LR", "LMR", "LMR"]],
	"Censer Bearer": ["censer", ["M", "M", "LMR", "LR", "LR", "LR", "LMR", "M", "LMR"]],
	"Line of Light": ["cut gem", ["M", "LR", "LMR", "LMR", "LR", "LR", "LR", "LR", "M"]],
	"Lightstring": ["sun arrow", ["LMR", "LR", "M", "LMR", "M", "M", "M", "LMR", "LMR"]],
}
## Which of a ribbon's three columns (0 left, 1 middle, 2 right) a SHAPES row fills.
const SHAPE_COLUMNS := {"M": [1], "LR": [0, 2], "LMR": [0, 1, 2]}
## Gap between two spec groups on the page, in cells: each group is drawn as its own block.
const GROUP_GAP := 0.45

## A column's left edge in cells, counting the gaps between the groups before it.
static func column_x(category: String, col: int) -> float:
	var x := float(col)
	var groups := groups_of(category)
	for i in range(1, groups.size()):
		if col >= int(groups[i][1]):
			x += GROUP_GAP
	return x

## Width of a book's grid in cells, the gaps between groups included.
static func grid_width(category: String) -> float:
	return column_x(category, columns_of(category) - 1) + 1.0

static func columns_of(category: String) -> int:
	return int(GRID_COLUMNS.get(category, COLUMNS))

static func rows_of(_category: String) -> int:
	return ROWS

static func groups_of(category: String) -> Array:
	return GROUPS.get(category, [])

## The group a talent's column is in ("" in a book without groups).
static func group_of(id: String) -> String:
	var t := get_talent(id)
	if t.is_empty():
		return ""
	for g in groups_of(str(t["category"])):
		if int(t["col"]) >= int(g[1]) and int(t["col"]) <= int(g[2]):
			return str(g[0])
	return ""

## A spec's capstone: the bottom-row talent of a spec group (not the Open one).
static func capstone_gated(id: String) -> bool:
	var g := group_of(id)
	return g != "" and g != OPEN_GROUP and tier_of(id) == rows_of(category_of(id)) - 1

## Every talent id (choice slots' two talents included, not the slots) in a group.
static func in_group(category: String, group: String) -> Array[String]:
	var key := "%s:%s" % [category, group]
	if not _group_cache.has(key):
		var found: Array[String] = []
		for id in db():
			if category_of(str(id)) == category and not is_choice_slot(str(id)) and group_of(str(id)) == group:
				found.append(str(id))
		_group_cache[key] = found
	var out: Array[String] = []
	out.assign(_group_cache[key])
	return out

## Talents that changed slot: old id -> new id, so points saved in the old slot
## follow the talent (SaveSystem._valid_talents). An old id listed here must not
## be given to a new talent.
const MOVED := {
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
## once, to saves made before the change. Its last entries (all Lightning) went with the
## Lightning ribbon tree, which refunded every point (TREE_VERSION).
const LINKS_MOVED := {
}

## Small Change moved up from row 8 to row 5, straight under Interest, to make
## room down the middle of the Shadow book (save version 6 -> 7,
## SaveSystem._migrate_6_to_7). Its entry went with the Shadow ribbon tree, which
## refunded every point (TREE_VERSION).
const SHADOW_MIDDLE_MOVED := {
}

## Frozen Instinct moved one column left in row 7, straight under Cold Snap,
## to make room for the Frost melee talents (save version 11 -> 12,
## SaveSystem._migrate_11_to_12). Its old slot now holds Turned Backs, so like
## LINKS_MOVED this is applied once, to saves made before the change.
const FROST_MELEE_MOVED := {
	"frost_r7c6": "frost_r7c5",   # Frozen Instinct: one column left, under Cold Snap
}

## Talents folded into their abilities (save version 10 -> 11,
## SaveSystem._migrate_10_to_11). Their slots are empty now, so points saved in
## them are refunded instead of staying in an empty slot or going to the next
## talent placed there.
const FOLDED_INTO_ABILITIES := [
	"fire_r9c6", "fire_r8c3",   # Furnace Heart, Thick Pitch
	"frost_r8c4",   # Thick Hide
	"lightning_r3c1",   # Honed Edge
	"arcane_r3c5",   # Deep Well
	"shadow_r5c2",   # Cut Short
	"nature_r8c3", "nature_r8c2",   # Big Herd, Quick Return
	"martial_r9c3", "martial_r9c5",   # Deep Pockets, Round Two
	"holy_r6c7", "holy_r8c2", "holy_r9c3",   # Last Rites, High Censer, Swift Light
]

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
					if defs.has(key) and defs[key] is Dictionary and defs[key].has("choice"):
						_add_choice(entry, id, defs[key]["choice"])
					elif defs.has(key):
						var extra := _entry_from(entry, defs[key])
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

## One talent entry from its definition [name, max_rank, description, extra].
static func _entry_from(entry: Dictionary, d: Array) -> Dictionary:
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
	return extra

# --- Choice talents ------------------------------------------------------------------
# A slot defined as {"choice": [talent A, talent B]} holds two talents and points
# go into only one of them (WoW-style: hover the slot, pick one). The slot itself
# ("fire_r4c1") is what rows, trees and the UI see; it holds no points. The two
# talents are "fire_r4c1a" and "fire_r4c1b": real talents with their own keys,
# ranks and tooltips, in the slot's row and column. PlayerData keeps points out of
# one while the other has any. Choice slots take no LINKS.

## `entry` (the slot's) gets its two talents; both are added to the db.
static func _add_choice(entry: Dictionary, id: String, defs: Array) -> void:
	var opts: Array[String] = []
	var names: Array[String] = []
	var ranks := 0
	var req := ""
	for i in mini(defs.size(), 2):
		var oid: String = id + CHOICE_SUFFIX[i]
		var opt := {"category": entry["category"], "tier": entry["tier"], "col": entry["col"], "stats": {},
			"choice_slot": id}
		var extra := _entry_from(opt, defs[i])
		if extra.has("key"):
			_keys[str(extra["key"])] = oid
		_db[oid] = opt
		opts.append(oid)
		names.append(str(opt["name"]))
		ranks = maxi(ranks, int(opt["max_rank"]))
		req = str(opt["requires"]) if i == 0 or req == str(opt["requires"]) else ""
	entry["name"] = " or ".join(names)
	entry["max_rank"] = ranks
	entry["desc"] = ""
	entry["implemented"] = true
	entry["placeholder"] = false
	entry["requires"] = req   # (only when both talents need the same ability)
	entry["choice_of"] = opts

const CHOICE_SUFFIX := ["a", "b"]

## The two talents of a choice slot ([] for any other id).
static func options_of(id: String) -> Array[String]:
	var out: Array[String] = []
	out.assign(get_talent(id).get("choice_of", []))
	return out

static func is_choice_slot(id: String) -> bool:
	return get_talent(id).has("choice_of")

## The choice slot a talent belongs to ("" if it isn't one of a choice's two).
static func choice_slot_of(id: String) -> String:
	return str(get_talent(id).get("choice_slot", ""))

## The other talent of the same choice ("" if `id` isn't one of a choice's two).
static func sibling_of(id: String) -> String:
	for o in options_of(choice_slot_of(id)):
		if o != id:
			return o
	return ""

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
	for field in ["values", "values2"]:   # {vmana} / {v2mana}: values as mana points, shown as real mana at your level
		var tag := "{vmana}" if field == "values" else "{v2mana}"
		if text.contains(tag):
			var mana: Array[String] = []
			for v in t.get(field, []):
				mana.append(str(int(round(float(v) * Stats.mana_unit(Stats._player_level())))))
			text = text.replace(tag, " / ".join(mana))
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
	if t.has("choice_of"):
		var parts: Array[String] = ["Choose one  (%s, row %d)" % [Categories.cat_name(t["category"]), int(t["tier"]) + 1],
			"Points go into only one of these two. Hover to pick."]
		for o in options_of(id):
			parts.append("%s: %s" % [get_talent(o)["name"], description(o)])
		parts.append("Rank %d / %d" % [rank, int(t["max_rank"])])
		if str(t.get("requires", "")) != "":
			parts.append(requires_line(str(t["requires"])))
		return "\n".join(parts)
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
	if capstone_gated(id):
		lines.append("Needs %d points in %s" % [load("res://scripts/balance.gd").CAPSTONE_GATE, group_of(id)])
	var other := sibling_of(id)
	if other != "":
		lines.append("Choice: points go into this or %s, not both" % get_talent(other)["name"])
	for s in sources_of(id):
		lines.append("Also unlocked by maxing %s (%s, row %d)" % [get_talent(s)["name"],
			Categories.cat_name(category_of(s)), tier_of(s) + 1])
	for s in targets_of(id):
		lines.append("Maxing this unlocks %s (%s, row %d)" % [get_talent(s)["name"],
			Categories.cat_name(category_of(s)), tier_of(s) + 1])
	if not t.get("implemented", false) and not t.get("placeholder", false):
		lines.append("(Not implemented yet: has no effect)")
	return "\n".join(lines)
