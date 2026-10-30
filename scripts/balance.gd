extends RefCounted

# ============================================================================
#  BALANCE — every tunable number in one place.
#  Usage: const Balance = preload("res://scripts/balance.gd")
#
#  Damage / heal numbers are COEFFICIENTS: 1.0 = one "standard hit" (a Frost
#  Bolt with no gear). The real number is
#      coefficient x (Stats.level_hit(level) + Spell/Attack Power bonus)
#  so 1.0 is ~19 at level 1 and ~460 at level 50 before gear.
#
#  ABILITIES / EFFECTS below override the values in res://data/abilities and
#  res://data/effects when the game loads them, so THIS file is the one to edit.
#  (The .tres files still hold names, descriptions, tags, icons and links.)
#  Leave a key out to keep the .tres value.
#
#  Ability keys:
#    damage       coefficient of one hit (spells), or a flat bonus on top of
#                 weapon damage (weapon abilities)
#    weapon_mult  weapon damage x this (melee / bow abilities)
#    cooldown     seconds
#    cost         mana (points: 10% of base mana each) / Energy / Fury spent
#                 (see the .tres for which one)
#    generates    Energy / Fury gained on use
#    cast_time    seconds (casts and channels; 0 = instant)
#    radius       metres (AoE size, chain / splash reach)
#    range        metres (targeted spells)
#    threat       threat multiplier (tank abilities 3-5x)
#
#  Effect keys:
#    duration     seconds
#    tick_damage  DoT coefficient per tick
#    tick_every   seconds between ticks
#    burst        coefficient when it runs out (Hoarfrost)
#    damage_pct   % damage taken (incoming) / dealt (outgoing); negative = less
#    slow         % move speed (negative = slower)
# ============================================================================

# --- Global ------------------------------------------------------------------

## Enemy health x this (0.8 = 20% less than the original numbers).
const ENEMY_HEALTH_MULT := 0.8

## AoE target cap: up to this many enemies take full damage. With more, the
## damage that many would take is split evenly between ALL of them (nobody
## ever takes 0). Used by Aether Burst and shatters.
const AOE_TARGET_CAP := 5

## Global cooldown: seconds, the share of Haste it gets, and its floor.
const GCD_BASE := 1.5
const GCD_HASTE_SHARE := 0.4
const GCD_MIN := 0.75

## Avoidance: Dodge, Parry and Block. A hit that is dodged, parried or blocked
## deals no damage and applies none of its effects. Each is rolled on its own,
## in that order, and each has a cap. All three are percent stats that drop on
## gear. Agility adds a little Dodge; Strength adds a little Parry and a little
## Block. (Armor does not block: it reduces damage, see ARMOR_DR_PER_LEVEL.)
const DODGE_CAP := 30.0             # most Dodge chance (%) that counts
const PARRY_CAP := 30.0             # most Parry chance (%) that counts
const BLOCK_CAP := 60.0             # most Block chance (%) that counts (Block on gear, Strength and buffs)
const DODGE_PER_AGILITY := 0.006    # % Dodge per point of Agility (1,000 Agility = 6%)
const PARRY_PER_STRENGTH := 0.006   # % Parry per point of Strength
const BLOCK_PER_STRENGTH := 0.006   # % Block per point of Strength
const AVOIDANCE_ROLL := 0.8         # % one gear roll of Dodge / Parry / Block gives at item level 1 (about 2.4% at item level 50)
const AVOIDANCE_ROLL_WEIGHT := 0.5  # how often each of the three is rolled, next to an ordinary stat's 1.0

## Armor reduces ALL the damage its wearer takes (hits of every school and
## damage over time), by a flat share: armor / (armor + ARMOR_DR_PER_LEVEL x
## level), so the same share of your gear's Armor is worth the same at every
## level. A full set of Heavy armor is about 36% (40% with a shield), Medium
## 28%, Light 18%, Cloth 10%. Enemies' Armor works the same way.
const ARMOR_DR_PER_LEVEL := 37.0    # Armor per level that takes half of all damage off (1 flat unit = 1.75 per level)
const ARMOR_DR_CAP := 60.0          # most damage (%) Armor can take off

## Armor types. Every piece of armor (Head, Shoulder, Chest, Gloves, Legs,
## Boots) is one of four types, rolled when it drops. Anyone can wear any of
## them: the heavier a piece, the more Armor it has; the lighter, the more of
## its type's stat. The index is what an item's record stores (ItemDB "armor_type").
const ARMOR_TYPE_NAMES := ["Cloth", "Light", "Medium", "Heavy"]
const ARMOR_TYPE_ARMOR := [0.2, 0.4, 0.7, 1.0]            # Armor, as a share of a Heavy piece's
const ARMOR_TYPE_STAT := ["intellect", "agility", "strength", "constitution"]   # the stat a piece of that type carries
const ARMOR_TYPE_STAT_AMOUNT := [0.75, 0.6, 0.45, 0.3]    # ... flat units of it per unit of the slot's weight
## The armor pieces (base item id -> the slot's weight: flat units of Armor a
## Heavy piece has). A new armor base item goes here, in ARMOR_PIECE_NAMES and
## in ARMOR_LEGACY_TYPE.
const ARMOR_PIECES := {"helmet": 2.0, "pauldrons": 2.0, "chestplate": 3.0, "gloves": 1.0, "leggings": 3.0, "boots": 1.0}
## What each piece is called, by type (Cloth, Light, Medium, Heavy).
const ARMOR_PIECE_NAMES := {
	"helmet": ["Silk Hood", "Leather Cap", "Chain Coif", "Plate Helm"],
	"pauldrons": ["Silk Mantle", "Leather Shoulderpads", "Chain Shoulders", "Plate Pauldrons"],
	"chestplate": ["Silk Robe", "Leather Jerkin", "Chain Hauberk", "Plate Cuirass"],
	"gloves": ["Silk Gloves", "Leather Grips", "Chain Gauntlets", "Plate Gauntlets"],
	"leggings": ["Silk Trousers", "Leather Breeches", "Chain Leggings", "Plate Greaves"],
	"boots": ["Silk Slippers", "Leather Boots", "Chain Boots", "Plate Sabatons"],
}
## The type of a piece saved before armor types existed: what it was called
## then (Iron Helm, Leather Grips, Chain Leggings...).
const ARMOR_LEGACY_TYPE := {"helmet": 3, "pauldrons": 3, "chestplate": 3, "gloves": 1, "leggings": 2, "boots": 1}

## Resources. Energy and Fury are bars of RESOURCE_MAX (100): their costs and
## gains in ABILITIES below are that many Energy / Fury. Mana is on the same
## scale as health: base mana = MANA_OF_BASE_HEALTH x base health (Intellect
## adds 4 per point). Mana costs and MANA_REGEN are in "points" = 10% of base mana.
const RESOURCE_MAX := 100.0
const MANA_OF_BASE_HEALTH := 0.8
const MANA_REGEN := 0.5        # points per second (= 5% of base mana)
const ENERGY_REGEN := 10.0     # Energy per second
const FURY_DECAY := 5.0        # Fury per second lost
## Tanks: every hit of a tank spec's kit (Abilities.hit_damage_mult: its abilities and
## Abilities.TANK_HITS) is TANK_DAMAGE_PCT of what it would be and makes TANK_THREAT_MULT
## times the threat. Auto attacks and everything else deal their full damage for anyone.
## Targets: a tank at optimal play does 30-40% of a top DPS, and makes about 1.3-1.7x
## that DPS's threat: steady damage stays under it, but a big burst, a crit spike or
## an early opener can take aggro, and the tank has to taunt or work to win it back.
const TANK_DAMAGE_PCT := 35.0
const TANK_THREAT_MULT := 1.4

## Talents on the column-group layout (Talents.GROUPS): a spec's bottom-row talent (its
## capstone) needs this many points spent in that spec's group.
const CAPSTONE_GATE := 15
const AUTO_ATTACK_FURY := 10.0 # Fury per auto-attack (with a fury spender on the bar)
## Auto-attacks and auto-shots deal this share of the weapon's damage (weapon
## abilities still use all of it).
const AUTO_ATTACK_MULT := 0.2

## Natural health regeneration, % of max health per second (like WoW:
## a trickle in combat, fast once the fight is over).
const HP_REGEN_IN_COMBAT_PCT := 0.3
const HP_REGEN_OUT_OF_COMBAT_PCT := 5.0
## Out-of-combat regen starts this many seconds after leaving combat.
const HP_REGEN_OOC_DELAY := 1.5

## Interrupts: seconds the target can't cast afterwards.
const INTERRUPT_LOCKOUT := {"counterspell": 4.0, "furnacebreath": 3.0, "rimelock": 3.0, "jolt": 3.0, "hush": 3.0, "circleofsilence": 3.0, "stonethrow": 3.0}
## Interrupts share a cooldown: using one puts every other interrupt (of any
## book) on at least this many seconds of cooldown, and no interrupt's own
## cooldown may be shorter than this (a test checks it; longer is fine).
const INTERRUPT_SHARED_COOLDOWN := 15.0
const HUSH_INTERRUPT_REFUND := 4.0        # Hush: seconds taken off its cooldown when it stops a cast (never under the shared cooldown)

## Buffs from abilities: amount in flat units (Stats.flat_unit) and seconds.
const ICE_BARRIER_ARMOR := 3.0
const ICE_BARRIER_TIME := 8.0
const BLINK_DISTANCE := 6.0
## Counts and times the abilities' descriptions quote (the code reads the same ones).
const ARCANE_MISSILES_COUNT := 6   # Sigil Darts: darts per channel (spread evenly over it)
const CHAIN_JUMPS := 3             # Stormbreak: more enemies the charge arcs to (Leaping Arc: LEAPING_ARC_JUMPS)
const BLIZZARD_TIME := 3.0         # Whiteout: seconds it lasts
const BLIZZARD_TICK := 0.5         # ... seconds between its waves of ice
const ARCANE_STRIKE_MANA := 2.0    # Arcane Strike: mana points it restores

## Ice Shards: charges (max, seconds per natural charge) and seconds between shards.
const ICE_SHARDS_MAX_CHARGES := 5
const ICE_SHARDS_RECHARGE := 20.0
const ICE_SHARDS_INTERVAL := 0.4

## Frost talents (rank numbers live in talents.gd; these are the fixed parts).
const SPLINTER_RANGE := 8.0              # Splintering: metres to the random second target
const SHARDSTORM_EVERY := 5              # Shardstorm: shards fired per buff
const SHARDSTORM_TIME := 5.0
const SLOW_MEMORY := 5.0                 # Chilling Presence / Numbing Cold: seconds after you slow an enemy
const GLACIAL_HEART_HASTE := 0.21        # Glacial Heart capstone: Haste % per slow you have on an enemy
const DEEP_FREEZE_BLIZZARD_EVERY := 20   # Deep Freeze capstone: shards per free Whiteout
const DEEP_FREEZE_BLIZZARD_MULT := 0.5   # ... at this share of Whiteout's damage
const COLD_SNAP_MIN_GCD := 0.25          # Cold Snap never shortens a GCD below this
const ICE_FLOE_TIME := 3.0               # Ice Floe: move speed buff after a shield on you breaks
const COLD_DRAW_EVERY := 1.0            # Cold Draw: seconds between its resource gains
const FROZEN_INSTINCT_TIME := 8.0        # Frozen Instinct: seconds to use the instant Frost spell
## Frost talents of the column-group tree (2026-10-23).
const SPLINTER_DAMAGE := 0.1             # Splintering: Frost damage (coefficient) of each splinter
const SNOWDRIFT_CROWD := 2               # Snowdrift: other enemies near the target it needs ...
const SNOWDRIFT_RADIUS := 8.0            # ... within this many metres
const COLD_FRONT_MAX := 5                # Cold Front: enemies you have Chilled or Frozen that count, at most
const COLD_WELL_EVERY := 1.0             # Cold Well: seconds between its mana gains
const LAST_SHELTER_HEALTH := 50.0        # Last Shelter / Cold Rush: an ally below this % health
const MELTDOWN_EVERY := 2.0              # Meltdown: seconds between its mana gains
const SHIVER_EVERY := 2.0                # Shiver: seconds between its Glaze
const COLD_SWING_HITS := 2               # Cold Swing: enemies a melee ability has to hit
const THAW_STRIKE_TIME := 10.0           # Thaw Strike: seconds the cheaper finisher waits
const STEADY_FOOTING_LAYERS := 3         # Steady Footing: Ice Layers you need to hold
const SPLITTING_ARROW_RANGE := 8.0       # Splitting Arrow: metres to the second enemy
const SLEET_ARROWS_RANGE := 8.0          # Sleet Arrows: metres from the target to the enemies also Chilled

## Frost, second batch.
const COLDSPIKE_FROZEN_PCT := 25.0       # Coldspike: % more damage to a target YOU have Frozen
const SLEETWAVE_WIDTH := 3.0             # Sleetwave: the wave's width in metres (its length is the ability's radius)
const SLEETWAVE_SPEED := 24.0            # ... metres per second it travels
const DEEPWINTER_TIME := 15.0            # Deepwinter: seconds every Chill you apply is a Freeze instead
const SNOW_WARD_SHARE := 0.6             # Snow Ward: each shield = this x a Heal spell
const SNOW_WARD_TIME := 10.0             # ... seconds the shields last
const WINTER_HIDE_TIME := 8.0            # Winter Hide: seconds
const WINTER_HIDE_PCT := 30.0            # ... % less damage taken
const RIME_EDGE_TIME := 12.0             # Rime Edge: seconds your melee hits Chill and deal extra Frost damage
const ICEBREAKER_FROZEN_MULT := 3.35     # Icebreaker: weapon damage x this on a target YOU have Frozen (it ends the Freeze)

## Frost tank: Glacier Wall (one-handed melee weapon and a shield, Fury). Ice Layers
## are one absorb shield on you, cut into layers.
const ICE_LAYERS_MAX := 5                # Ice Layers you can hold
const ICE_LAYER_PCT := 4.0               # ... each absorbs this % of your maximum health
const ICE_LAYERS_TIME := 20.0            # ... seconds they last (gaining one starts the time over)
const ICE_LAYER_FURY := 8.0              # ... Fury each Layer gives you when a hit breaks it (it also Chills the attacker)
const RIME_SLASH_LAYERS := 1             # Rime Slash: Layers it gives ...
const RIME_SLASH_LAYERS_MANY := 2        # ... or this many when it hits ...
const RIME_SLASH_MANY_HITS := 3          # ... at least this many enemies
const SHATTER_SLAM_PER_LAYER := 0.2      # Shattering Slam: Frost damage (coefficient) for each Layer it shatters into the target
const RIMEQUAKE_PCT_PER_LAYER := 10.0    # Rimequake: % more damage for each Ice Layer you have
const COLD_SHOULDER_TAUNT := 3.0         # Cold Shoulder: seconds the target must attack you
const COLD_SHOULDER_LAYERS := 1          # ... Ice Layers it gives you
const HARD_RIME_TIME := 6.0              # Hard Rime: seconds it lasts ...
const HARD_RIME_REFORM := 2.0            # ... a Layer that breaks forms again this many seconds later
const GLACIAL_BULWARK_TIME := 10.0       # Glacial Bulwark: seconds it lasts
const GLACIAL_BULWARK_LAYERS := 3        # ... Ice Layers it gives you at once
const GLACIAL_BULWARK_SHATTER := 0.3     # ... each Layer that breaks shatters for this much Frost damage (coefficient) ...
const GLACIAL_BULWARK_RADIUS := 5.0      # ... to enemies within this many metres
const GLACIAL_BULWARK_THREAT := 4.0      # ... with this much threat
const DEEP_STRATA_COOLDOWN := 20.0       # Deep Strata capstone: your last Layer breaking gives one back, once every this many seconds

## Frost DPS: Frostbitten Steel (two-handed melee weapon, Fury). Glaze is a buff on you.
const GLAZE_MAX := 5                     # Glaze you can hold
const GLAZE_TIME := 12.0                 # ... seconds it lasts (gaining one starts the time over)
const WINTERS_BITE_GLAZE := 1            # Winter's Bite: Glaze on a target you have Chilled or Frozen
const HOARCLEAVE_RADIUS := 3.0           # Hoarcleave: metres around the target it also hits
const HOARCLEAVE_GLAZE := 1              # ... Glaze for each enemy hit that you had already Chilled or Frozen ...
const HOARCLEAVE_MAX_GLAZE := 2          # ... up to this many in all
const RIME_EDGE_GLAZE_CHANCE := 25.0     # Rime Edge: % chance its extra hit on a target you have Chilled gives ...
const RIME_EDGE_GLAZE := 1               # ... this much Glaze
const ICEBREAKER_PCT_PER_GLAZE := 5.0    # Icebreaker: % more damage for each Glaze it spends
const BITTER_EDGE_GLAZE := 1             # Bitter Edge: Glaze it gives
const CALVING_RADIUS := 5.0              # Calving: metres around the target it also hits
const CALVING_PCT_PER_GLAZE := 15.0      # ... % more damage for each Glaze it spends
const BLACK_FROST_TIME := 12.0           # Black Frost: seconds every Winter's Bite Freezes
const ICE_FALL_MAX_OTHERS := 4           # Ice Fall talent: other enemies hit that count, up to this many
const HOAR_BLADE_DAMAGE := 0.25          # Rune of the Hoar Blade: Frost damage (coefficient) on each auto-attack while you hold all your Glaze
const ICE_SHELF_LAYERS := 7              # Rune of the Ice Shelf: Ice Layers you can hold
const LONE_FLOE_PCT := 40.0              # Rune of the Lone Floe: Calving hits only its target, for this % more

## Frost, the bow.
const SHATTER_SHOT_FROZEN_PCT := 50.0    # Shatter Shot: % more damage to a target YOU have Frozen (it ends the Freeze; the burst is EXTRA_HITS)
const RIMEFLETCH_SHOTS := 4              # Rimefletch: auto-shots that carry it
const RIMEFLETCH_TIME := 15.0            # ... seconds you have to use them
const RIMEFLETCH_PCT := 30.0             # ... % of the auto-shot's damage dealt again as Frost damage
const ICY_RETREAT_DISTANCE := 8.0        # Icy Retreat: metres it carries you backward
const ICY_RETREAT_TIME := 4.0            # ... seconds the ice stays on the ground (its size is the ability's radius)
const ICY_RETREAT_TICK := 1.0            # ... seconds between its Chills
const ICY_FOOTING_TIME := 8.0           # ... Icy Footing: seconds your next Frost Arrow stays free after it

## Fire.
# Steady Flame runs on Fury (FireFuryKit): Fire spell hits that don't crit build
# it, Fire spell crits Vent part of it.
const FIRE_FURY_BASE := 6.0               # Fury from a Fire spell that doesn't crit ...
const FIRE_FURY_PER_CRIT := 0.6           # ... + this x your crit chance (%)
const FIRE_FURY_VENT_PCT := 50.0          # % of your Fury a Fire spell crit Vents
const FIRE_FURY_EMBER_MULT := 1.0 / 3.0   # an Ember Volley ember gives this share of a spell's Fury
const VENT_FURY_MIN := 20.0               # Vent Flames: Fury needed (it spends all of it) ...
const VENT_FURY_PCT := 0.5                # ... % more damage per Fury spent
const BLOWBACK_PER_FURY := 0.03           # Blowback: Frost Bolts of Fire damage per Fury point that burns ...
const BLOWBACK_TIME := 4.0                # ... dealt over this many seconds ...
const BLOWBACK_TICK := 1.0                # ... one tick every this many (faster with Haste)
const SEALED_KILN_PCT := 30.0             # Rune of the Sealed Kiln: % less Fury gained (crits Vent none)
const KILN_BLAST_IMMOLATE_PCT := 20.0     # Kiln Blast: % more damage to a target with your Blaze
const FIRE_BURNS := ["immolate", "burning"]   # my burns (data/effects/<id>.tres): Warm Blood counts them
const FIRE_WALL_TIME := 8.0               # Wall of Fire: seconds it stands
const FIRE_WALL_TICK := 0.5               # ... seconds between ticks (faster with Haste)
const FIRE_WALL_DEPTH := 2.0              # ... thickness in metres (its length is 2 x the ability's radius)
const FIRE_WALL_DISTANCE := 5.0           # ... metres in front of you when you have no target
const IMMOLATE_SPREAD_TARGETS := 2        # Blaze cast on a target that already has yours: spreads to this many others
const IMMOLATE_SPREAD_RADIUS := 8.0      # ... within this many metres of that target
const DULL_EDGE_CRIT_CAP := 10.0         # Rune of the Dull Edge / Dull Mind: crit chance can't go above this (%)
const DULL_EDGE_POWER_PER_PCT := 0.2     # ... each 1% over it = this many flat units (Stats.flat_unit) of Attack Power (Dull Edge) / Spell Power (Dull Mind)
const WINTERS_BITE_STACKS := 3           # Winter's Bite: every this-many-th cast Freezes instead of Chilling
const WINTERS_BITE_TIME := 20.0          # ... seconds its counter (a buff) lasts
const HAIR_TRIGGER_CHARGES := 2          # Rune of the Hair Trigger: Vent Flames charges
const EMBER_VOLLEY_HITS := 6              # Ember Volley: embers per channel (spread evenly over it)
const EMBER_VOLLEY_BURST_GAP := 0.07     # ... seconds between embers when Concentrated Fire makes it instant
const EMBER_VOLLEY_SPLIT_RADIUS := 8.0   # Scattered Embers talent: extra targets within this of your target
const FURNACE_BREATH_ARC := 90.0          # Furnace Breath: the cone's full width in degrees
const SLAG_SKIN_TIME := 15.0             # Slag Skin: seconds it lasts (its cooldown is shorter: keep it up)
const SLAG_SKIN_ICD := 0.5               # ... each attacker is burned at most once per this many seconds
const SLAG_MAX_STACKS := 6               # Slag: stacks from your blocks and melee hits, while Slag Skin is up
const SLAG_ARMOR := 0.5                  # ... armor per stack, in flat units (Stats.flat_unit)
const SLAG_BRITTLE_TIME := 3.0           # ... a stack from a melee crit is brittle: it lasts only this many seconds
const SLAG_SHATTER_RADIUS := 5.0         # ... Forge Blow shatters every stack: Fire damage within this many metres
const SLAG_SHATTER_THREAT := 3.0         # ... (damage per stack is EXTRA_HITS["slagskin"])
const BRAND_PCT := 10.0                  # Brand: % less damage the branded enemy deals to you
const CINDER_GUARD_TIME := 6.0           # Cinder Guard: seconds
const CINDER_GUARD_BLOCK := 25.0         # ... added chance to block (%), still capped at Stats.MAX_BLOCK
const CINDER_GUARD_EXTEND := 1.0         # ... seconds each block adds to Slag Skin (never above SLAG_SKIN_TIME)
const CINDER_GUARD_SLAG := 2             # ... Slag each block gives during it (instead of 1)
const RIVET_TAUNT := 3.0                 # Red-Hot Rivet: seconds the target must attack you
const RIVET_SLAG := 1                    # ... Slag it gives you
const MOLTEN_SHELL_TIME := 10.0          # Molten Shell: seconds it lasts
const MOLTEN_SHELL_MAX := 12             # ... Slag you can hold during it (back to the normal cap when it ends)
const MOLTEN_SHELL_BLOCK_SLAG := 2       # ... Slag each block gives during it
const MOLTEN_SHELL_DR := 1.0             # ... % less damage taken per Slag you hold during it
const CLINKER_TIME := 6.0                # Smoldering Debris talent (was "Clinker"): seconds the patch burns
const CLINKER_TICK := 1.0                # ... seconds between its ticks
const CLINKER_RADIUS := 3.0              # ... half the side of the (square) patch
const CRUCIBLE_TIME := 12.5              # Crucible: seconds it stands (Deep Crucible was folded in: was 10)
const CRUCIBLE_DOT_PCT := 15.0           # ... % more periodic Fire damage enemies inside take
const CRUCIBLE_MOVE_REFRESHES := false   # ... true = moving it also restarts its 10 seconds
const CINDER_STEP_DISTANCE := 6.0        # Cinder Step: metres dashed (stops short of walls)
const CINDER_STEP_LINE_TIME := 4.0       # ... seconds the line of cinders burns
const CINDER_STEP_LINE_DEPTH := 1.5      # ... its width in metres
const CINDER_STEP_TICK := 0.5            # ... seconds between its ticks
const CINDER_STEP_BUFF_TIME := 8.0       # ... seconds to use the cast-while-moving spell
const HEAT_SINK_TIME := 6.0              # Heat Sink: seconds
const HEAT_SINK_PCT := 40.0              # ... % of damage taken that is stored instead
const HEAT_SINK_BONUS := 2.0             # ... the burst grows by up to this many times its base
const HEAT_SINK_FULL_AT := 50.0          # ... reached when this % of your max health is stored
const COOL_HEAD_TIME := 15.0             # Cool Head: seconds your Fire spells / abilities can't crit
const CONCENTRATED_FIRE_WINDOW := 5.0    # ... then this many seconds of instant Fire casts (1 per stack)
const CONCENTRATED_FIRE_MAX := 20        # stack cap (more than fits in one Cool Head)
## Fire melee: Heat. Built by your melee hits on a target that has YOUR Burning or Blaze.
## While you hold Heat your melee hits can't crit: one that would have is a Spark (+1 Heat).
const HEAT_MAX_STACKS := 10              # Heat: most stacks you can hold
const HEAT_DAMAGE_PCT := 4.0             # ... % more Fire damage from your ABILITIES (not spells), per stack
const HEAT_TIME := 3.0                   # ... seconds without gaining a stack before all of it is lost
const HEAT_BAND_ORANGE := 5              # Heat bands: Red below this, Orange from it ...
const HEAT_BAND_WHITE := 9               # ... White from this
const SEARING_STRIKE_HEAT := 2           # Searing Strike: Heat it builds (every other melee hit builds 1)
const SEARING_SPREAD_RADIUS := 8.0       # ... Orange: its Burning also goes on the nearest enemy within this many metres
const SEARING_WHITE_FURY := 15.0         # ... White: Fury it gives back
const QUENCH_MIN_HEAT := 3               # Quench: Heat needed to use it (it removes all of it)
const QUENCH_PCT_PER_HEAT := 25.0        # ... % more damage per Heat removed
const QUENCH_WHITE_SPLASH_PCT := 50.0    # ... White: this % of its damage also hits ...
const QUENCH_WHITE_RADIUS := 4.0         # ... the enemies within this many metres of the target (split past AOE_TARGET_CAP)
const FLARE_HEAT_COST := 3               # Flare: Heat it costs (none in the White band)
const FLARE_ARC := 120.0                 # ... the sweep's full width in degrees (its reach is the ability's radius)
const FLARE_ORANGE_PCT := 30.0           # ... Orange and White: % more damage
const FOLD_STEEL_HITS := 3               # Fold Steel: quick hits (each its own crit roll and Heat) ...
const FOLD_STEEL_HITS_ORANGE := 4        # ... in the Orange band and up
const FOLD_STEEL_GAP := 0.2              # ... seconds between them
const FOLD_STEEL_SPLASH_PCT := 50.0      # ... White: each hit also deals this % ...
const FOLD_STEEL_SPLASH_RADIUS := 3.0    # ... to the enemies within this many metres of the target
const RED_EDGE_TIME := 6.0               # Red Edge: seconds (its extra Fire damage is the ability's weapon_mult)
const BLAST_FURNACE_TIME := 12.0         # Blast Furnace: seconds everything counts as the White band
const AFTERGLOW_TIME := 4.0              # Afterglow talent: seconds after Quench
const FRESH_TINDER_SECONDS := 1.0        # Fresh Tinder talent: seconds added to your Burning
## Fire talents (their rank values are in talents.gd).
const BIG_SPEND_FURY := 60.0             # Big Spend: Fury a spell or ability must spend
const LOW_FLAME_CRIT := 20.0             # Low Flame: below this % critical strike chance (on your sheet)
const MOLTEN_HEART_ABOVE := 3            # Molten Heart: each Slag shattered above this many counts
const OVERHEAT_RADIUS := 4.0             # Overheat: metres around the target a White-band Spark burns
const DRIPPING_LAYERS := 3               # Dripping: layers of Pitch the target needs
const KINDLE_PACK_HITS := 3              # Kindle Pack: enemies an Ignite must hit
const FIRE_LINE_RANGE := 20.0            # Fire Line: metres beyond which your Burning hits harder
## Fire bow.
const PITCH_MAX_LAYERS := 5              # Pitch: most layers of yours on one target (data/effects/pitched.tres)
const PITCH_TIME := 15.0                 # ... seconds they last, refreshed by each new layer
const PITCH_LAYER_SPEED_PCT := 8.0       # ... % faster your burns tick on it, per layer
const PITCH_ARROW_LAYERS := 2            # ... layers Pitch Arrow adds (every other arrow that does not crit adds 1)
const PITCH_IGNITE_PER_LAYER := 0.15     # ... an arrow crit Ignites it: Fire damage (coefficient) per layer ...
const PITCH_IGNITE_RADIUS := 6.0         # ... to the target and every enemy within this many metres of it
const PITCH_RAIN_COAT_EVERY := 1.0       # ... Cinder Rain coats each enemy at most once per this many seconds
const TOUCH_OFF_PCT := 50.0              # Touch Off: % more Ignite damage
const BRUSHFIRE_TIME := 12.0             # Brushfire: seconds your auto-shots Burn ...
const BRUSHFIRE_LAYERS := 2              # ... and add this many layers of Pitch
const PITCH_EFFECTS := ["burning", "immolate"]   # Pitch: the burns it speeds up (data/effects/<id>.tres)
const CINDER_RAIN_TIME := 4.0            # Cinder Rain: seconds it falls
const CINDER_RAIN_TICK := 0.5            # ... seconds between ticks (faster with Haste)
## Fire healing: Cinderwing (the phoenix).
const PHOENIX_CASTS := 15                # heals it casts before it leaves
const PHOENIX_INTERVAL := 1.1            # ... seconds between them (Haste does not change this)
const PHOENIX_RANGE := 30.0              # ... metres from you an ally can be (each heal is HEALS["cinderwing"])

## Casting feel (WoW-style).
const SPELL_QUEUE_WINDOW := 0.4          # press this long before a cast / GCD ends and it fires right after
const BOLT_SPEED := 20.0                 # spell bolts (m/s), player and enemy
const ARROW_SPEED := 30.0                # arrows (m/s), player and enemy

## Rune of Overload (Epic): Static and Overload. (The burst's damage per
## stack and its radius are the rune's own effect_amount / radius.)
const STATIC_MAX_STACKS := 15            # Static: building it at this many stacks makes you Overload
const STATIC_DAMAGE_PCT := 2.5           # ... % more Lightning damage per stack
const STATIC_TIME := 10.0                # ... seconds without gaining a stack before all of it is lost
const OVERLOAD_LOCKOUT := 4.0            # Overload: seconds you can't build Static afterwards
const OVERLOAD_GROUND_AFTER := 3.0       # Grounded: seconds without casting Lightning that give it
const OVERLOAD_GROUND_TIME := 10.0       # ... seconds of casting Lightning it then lasts (no Overload)

## Dusk till Dawn (Legendary rune): dealing Shadow damage starts Dusk, Dawn follows
## it, and the next Dusk can only start once Dawn is over.
const DUSK_TIME := 12.0                  # Dusk: seconds it lasts (nothing refreshes it)
const DUSK_DAMAGE_PCT := 20.0            # ... % more Shadow damage while it lasts
const DAWN_TIME := 12.0                  # Dawn: seconds it lasts, from the moment Dusk runs out
const DAWN_DAMAGE_PCT := 20.0            # ... % more Holy damage while it lasts

## Rune of the Wild Page (Legendary): a spell or ability of mine can echo a random
## damaging ability of its book on my target, for that ability's direct hit only.
const WILD_PAGE_CHANCE := 30.0           # % chance per spell or ability used
const WILD_PAGE_COOLDOWN := 3.0          # ... seconds before it can echo again

## Lightning caster: an Energy kit. Leaping Arc and Ball Lightning give Energy,
## Lightning Bolt spends some, Discharge and Ground Out spend all of it.
## (Energy costs and gains are in ABILITIES.)
const LEAPING_ARC_JUMPS := 3             # Leaping Arc: enemies the arc jumps to after its target
const LEAPING_ARC_RETURN_PCT := 40.0     # ... a jump with no new enemy returns to the target for this % of a jump's damage
const ENERGY_STEP := 10.0                # Discharge / Ground Out: their numbers below are per this much Energy spent
const SPEND_ALL_MIN_ENERGY := 10.0       # ... Energy needed to use them
const DISCHARGE_PER_STEP := 0.3          # Discharge: damage (coefficient) per ENERGY_STEP Energy spent
const BALL_LIGHTNING_TIME := 8.0         # Ball Lightning: seconds the orb lasts
const BALL_LIGHTNING_SPEED := 2.5        # ... metres per second it drifts
const BALL_LIGHTNING_TICK := 0.5         # ... seconds between zaps (faster with Haste)
const BALL_LIGHTNING_ENERGY := 2.0       # ... Energy each zap gives back (one zap per enemy hit)
const GROUND_OUT_PER_STEP := 0.15        # Ground Out: shield per ENERGY_STEP Energy spent (1.0 = a standard hit's worth of health)
const GROUND_OUT_TIME := 8.0             # ... seconds the shield lasts
const GROUNDING_SURGE_TIME := 15.0       # Grounding Surge: seconds you can't move (recast to end it early)
const GROUNDING_SURGE_COST_PCT := 50.0   # ... % less Energy your abilities cost
const GROUNDING_SURGE_KEEP_PCT := 50.0   # ... % of your Energy left after an ability that spends all of it
const LIVE_WIRE_RANGE := 25.0            # Live Wire: the tether breaks beyond this many metres
const LIVE_WIRE_ENERGY := 3.0            # ... Energy each tick gives back
const THUNDERHEAD_TIME := 8.0            # Thunderhead: seconds the cloud stays
const THUNDERHEAD_TICK := 1.0            # ... seconds between strikes (faster with Haste)
const FORKED_BOLT_SOLO := 1.3            # Forked Bolt: damage (coefficient) of its single hit when no second enemy is in reach
const JOLT_ENERGY := 30.0                # Jolt: Energy it gives when it interrupts a cast
const FLICKER_DISTANCE := 10.0           # Flicker: metres it moves you
const FLICKER_TIME := 5.0                # ... seconds its instant Lightning Bolt waits for you
const FLICKER_RETURN_TIME := 4.0         # ... seconds during which pressing it again snaps you back to where you left
const CAPACITOR_MAX := 100.0             # Capacitor: most Energy it stores
const CAPACITOR_TIME := 20.0             # ... seconds you have to take it back

## Lightning melee: the same Energy bar with a weapon. Charged Edge and Whiplash
## give Energy; the rest spends it. (Costs, gains, cooldowns and weapon damage
## are in ABILITIES.)
const OVERDRIVE_TIME := 20.0             # Overdrive: seconds it lasts
const OVERDRIVE_SPEED_PCT := 40.0        # ... % faster your auto-attacks are
const OVERDRIVE_ENERGY := 5.0            # ... Energy each auto-attack that lands gives
const OVERDRIVE_ENERGY_LIMIT_PCT := 50.0 # ... % of max Energy: usable at or below it, and it ends the moment you have more
const TWIN_CURRENT_HITS := 4             # Twin Current: auto-attacks that hit a second time
const TWIN_CURRENT_PCT := 50.0           # ... % of the auto-attack's damage the second hit deals
const TWIN_CURRENT_TIME := 20.0          # ... seconds you have to use them
const STATIC_STEP_TIME := 4.0            # Static Step: seconds its bonus waits for your next weapon ability
const STATIC_STEP_PCT := 30.0            # ... % more damage that ability deals
const BACK_CURRENT_TIME := 5.0           # Back-Current: seconds it lasts
const BACK_CURRENT_ENERGY := 10.0        # ... Energy each melee hit you take gives
const CADENCE_WINDOW := 3.0              # Cadence: seconds you have for the next press
const CADENCE_MULTS := [0.8, 1.2, 2.0]   # ... weapon damage multiplier of each press (the last one also hits around you)
const SPLIT_SECOND_TIME := 8.0           # Split Second: seconds it lasts
const SPLIT_SECOND_GCD := 0.5            # ... seconds shorter your global cooldown is
const SPLIT_SECOND_MIN_GCD := 0.5        # ... but never shorter than this
const FARADAY_GUARD_TIME := 8.0          # Faraday Guard: seconds it lasts
const FARADAY_GUARD_PCT := 30.0          # ... % less damage you take (your Energy pays for it)
const FARADAY_GUARD_ENERGY := 1.0        # ... Energy it costs
const FARADAY_GUARD_HEALTH_PCT := 1.0    # ... for every this % of your max health it spares you
const REFLEX_ARC_TIME := 3.0             # Reflex Arc: seconds it waits for a melee attack to avoid
const POLARITY_TIME := 6.0               # Polar Strike (Rune of Polarity): seconds the charge waits for another weapon ability
const POLARITY_PCT := 25.0               # ... % more damage that ability deals

## Lightning tank: a parry tank with a two-handed weapon. Stormbreak gives
## Energy; a parry gives more while Humming Blade is up, and opens Return Stroke;
## Shock Ring and Crossguard spend it. (Costs, gains, cooldowns and damage are in
## ABILITIES; Stormbreak's arcs are CHAIN_JUMPS and EXTRA_HITS.)
const HUMMING_BLADE_TIME := 15.0         # Humming Blade: seconds it lasts
const HUMMING_BLADE_PARRY := 10.0        # ... % Parry it adds
const HUMMING_BLADE_PARRY_CAP := 45.0    # ... your Parry cap (%) while it is up (PARRY_CAP otherwise)
const HUMMING_BLADE_ENERGY := 10.0       # ... Energy each attack you parry gives
const RETURN_STROKE_WINDOW := 4.0        # Return Stroke: seconds after a parry it can be used (once per parry)
const CROSSGUARD_TIME := 3.0             # Crossguard: seconds you parry every attack that can be parried
const DRAW_THE_STORM_TIME := 8.0         # Draw the Storm: seconds each attack you parry zaps the enemies around you
const DRAW_THE_STORM_TAUNT := 3.0        # ... seconds the enemies around you are forced to attack you
const DRAW_THE_STORM_ZAP_RADIUS := 6.0   # ... metres the zap reaches (its damage is EXTRA_HITS)
const REEL_IN_TAUNT := 3.0               # Reel In: seconds the dragged enemy is forced to attack you
const REEL_IN_GAP := 0.6                 # ... metres between you and it once it arrives
const REEL_IN_DRAG_TIME := 0.18          # ... seconds the drag takes
const RECHARGE_PCT_PER_STEP := 1.5       # Recharge: % of your max health healed per ENERGY_STEP Energy spent

## Rune of Resonance (Rare): Return Stroke without a parry behind it.
const RESONANCE_COST := 40.0             # Energy Return Stroke costs when used without a parry
const RESONANCE_COOLDOWN := 3.0          # ... and the seconds of cooldown that use puts it on

## Lightning talents (their per-rank numbers are in talents.gd).
const COUNTER_CHARGE_JUMPS := 2          # Counter-Charge's capstone: enemies Return Stroke arcs to
const COUNTER_CHARGE_ARC := 0.3          # ... damage (coefficient) of each arc
const COUNTER_CHARGE_REACH := 4.0        # ... metres from the target an enemy may be
const TEMPO_TIME := 5.0                  # Tempo: seconds the attack speed lasts (every parry refreshes it)
const TEMPO_MAX_STACKS := 3              # ... most stacks
const STANDING_CHARGE_EVERY := 1.0       # Standing Charge: seconds planted in Grounding Surge per stack
const STANDING_CHARGE_MAX_STACKS := 5    # ... most stacks
const WHIP_CRACK_DISTANCE := 10.0        # Whip Crack: Whiplash has to hit a target farther away than this (metres)
const WHIP_CRACK_TIME := 8.0             # ... seconds the cheaper Static Step waits for you
const STORM_CYCLE_TIME := 60.0           # Storm Cycle: seconds the free Energy cost is kept for
const OVERFLOW_TIME := 8.0               # Overflow: seconds the shield made of Energy that didn't fit lasts
const PARTING_SPARK_RADIUS := 4.0        # Parting Spark: metres around the spot Flicker left that get zapped
const LOADED_QUIVER_TIME := 10.0         # Loaded Quiver: seconds its free Storm Arrows wait for you
const SNAP_SHOT_TIME := 5.0              # Snap Shot: seconds the cheaper Storm Arrow waits for you
const LIGHTNING_ROD_RADIUS := 4.0        # Grounded Arrow: metres around the target its arcs reach (how long the arrow stays in: EFFECTS)

## Rune of Bottled Lightning (Rare): Capacitor makes the next Discharge instant.
const BOTTLED_LIGHTNING_TIME := 8.0      # seconds the instant Discharge waits for you
const RUNNING_ON_EMPTY_ENERGY := 30.0    # Running on Empty: works while you have less Energy than this
const HIGH_VOLTAGE_ENERGY := 80.0        # High Voltage: works while you have more Energy than this
const RUNNING_START_DISTANCE := 8.0      # Running Start: metres Static Step has to carry you
const THIRD_BEAT_ENERGY := 15.0          # Third Beat's capstone: Energy Cadence's third strike gives back
const REDLINE_MAX := 10.0                # Redline: most seconds it can add to one Overdrive
# Lightning talents of the ribbon tree (ranks: talents.gd; code: lightning_talents.gd).
const AFTERFLOW_TIME := 4.0              # Afterflow: seconds the faster Energy regeneration lasts after spending all of it
const SNAP_CAST_TIME := 8.0              # Snap Cast: seconds its instant Lightning Bolt waits for you
const FULL_CIRCUIT_TIME := 10.0          # Full Circuit: seconds its stronger Lightning spell waits for you
const SPARKING_SWINGS_DAMAGE := 0.4      # Sparking Swings: damage (coefficient) of the zap on an auto-attack
const AFTERSPARK_TIME := 4.0             # Afterspark: seconds the stronger auto-attack waits for you
const BUILT_CHARGE_EVERY := 50.0         # Built Charge: Energy spent per stronger weapon ability
const BUILT_CHARGE_TIME := 15.0          # ... seconds it waits for you
const LIGHT_LOAD_ENERGY := 30.0          # Light Load: works while you have less Energy than this
const SPINNING_UP_EVERY := 20.0          # Spinning Up: Energy spent per step of cooldown taken off
const STORM_DANCE_REACH := 5.0           # Storm Dance's capstone: metres from the target Overdrive's second zap may go
const SPARK_GUARD_THREAT := 4.0          # Spark Guard: threat multiplier of the zap a parry sends back
const CHARGED_GUARD_TIME := 4.0          # Charged Guard: seconds the smaller next hit waits after a parry
const CHARGED_SHELL_ENERGY := 60.0       # Charged Shell: works while you have more Energy than this
const BACK_TO_THE_WALL_HEALTH := 35.0    # Back to the Wall: works below this % of your health
const STORM_ANCHOR_EVERY := 5            # Storm Anchor's capstone: parries per free Shock Ring
const CUT_THE_LINE_TIME := 6.0           # Cut the Line: seconds the Haste lasts after an interrupt
const FRESH_CHARGE_HEALTH := 90.0        # Fresh Charge: works above this % of your health
const STATIC_BUILD_STEP := 10.0          # Static Build: metres moved per stack
const STATIC_BUILD_STACKS := 3           # ... most stacks

## Arcane caster: a cooldown kit. Sigil Darts (a channel) and Unravel are the
## fillers; everything else has a cooldown, and the kit is stronger the more of
## it is on cooldown (Convergence) while Unravel, Rewind, Lapse and Interval Ward
## bring those cooldowns back sooner. "Arcane spells" below = every ability
## tagged Arcane + Spell; interrupts are left out of every cooldown change, so
## the shared interrupt cooldown stays what it is.
## (Damage, costs, cast times and cooldowns are in ABILITIES; ARCANE_MISSILES_COUNT is above.)
const SIGIL_DARTS_BURST_GAP := 0.07      # Sigil Darts: seconds between darts when something makes the channel instant
const UNRAVEL_SECONDS := 1.0             # Unravel: seconds each cast takes off your other Arcane spells' cooldowns
const COUNTDOWN_TIME := 5.0              # Countdown: seconds until the mark detonates
const COUNTDOWN_SHARE_PCT := 25.0        # ... % of the Arcane damage you dealt to the target meanwhile, added to it
const CONVERGENCE_PCT := 15.0            # Convergence: % more damage per other Arcane spell you have on cooldown
const CONVERGENCE_MAX := 5               # ... spells that count at most
const REWIND_MAX_COOLDOWN := 15.0        # Rewind: only resets spells whose cooldown is shorter than this
const LAPSE_TIME := 8.0                  # Lapse: seconds it lasts
const LAPSE_RATE_PCT := 100.0            # ... % faster your Arcane spells' cooldowns recover
const MIRROR_SIGIL_TIME := 12.0          # Mirror Sigil: seconds it stays on the ground
const MIRROR_SIGIL_PCT := 35.0           # ... % of each Arcane spell hit it repeats
const COLLAPSE_DELAY := 1.5              # Collapse: seconds between the cast and the implosion
const COLLAPSE_PULL := 5.0               # ... metres it pulls enemies toward its centre
const COLLAPSE_DRAG_TIME := 0.25         # ... seconds the pull takes
const COLLAPSE_CORE := 0.6               # ... nobody is pulled closer to the centre than this (metres)
const MIRROR_SIGIL_RADIUS := 1.5         # Mirror Sigil: size of the circle on the ground (a picture; it has no area)
const SCATTER_TARGETS := 3               # Scatter: enemies the darts are dealt out between (the target included)
const SCATTER_RADIUS := 8.0              # ... the others have to be within this many metres of the target
const SCATTER_PCT := 30.0                # ... % more damage each dart deals
const SCATTER_TIME := 15.0               # ... seconds it waits for your next Sigil Darts
const INTERVAL_WARD_TIME := 8.0          # Interval Ward: seconds the shield lasts (its size is HEALS)
const INTERVAL_WARD_RATE_PCT := 15.0     # ... % faster your Arcane spells' cooldowns recover while it holds
const GLINT_TIME := 4.0                  # Glint: seconds you have to start the cast it lets you make on the move

## Arcane talents (rank numbers live in talents.gd; these are the fixed parts).
const ETCHED_DARTS_SECONDS := 0.5        # Etched Darts: seconds an Arcane spell crit takes off your other Arcane spells
const CHAIN_REACTION_RADIUS := 5.0       # Chain Reaction: metres around the target Countdown detonated on
const AFTERSHOCK_TIME := 3.0             # Aftershock: seconds the slow lasts
const AFTERSHOCK_SLOW_STEP := 20.0       # ... the slow of the effect itself (%); the talent's rank scales it

## Arcane tank: a dodge tank with a melee weapon in each hand, on cooldowns alone
## (no Mana, Energy or Fury). It keeps Reflections up: images of itself. Each one
## adds Dodge and raises the Dodge cap. An attack it dodges uses one up, and that
## Reflection shatters: damage around the tank, and time off the cooldown of
## everything in the Arcane book (spells and abilities alike; interrupts keep
## their shared cooldown). Double Up, Ripple and Full Set make Reflections; the
## rest of the kit spends them or keeps them.
## (Damage, cooldowns, radius, range and threat are in ABILITIES.)
const REFLECTION_MAX := 4                 # Reflections: the most you can have
const REFLECTION_DODGE := 5.0             # ... % Dodge each one adds
const REFLECTION_DODGE_CAP := 5.0         # ... % each one adds to your Dodge cap (DODGE_CAP with none)
const REFLECTION_TIME := 30.0             # ... seconds they last; gaining one makes all of them last this long again
const REFLECTION_SHATTER := 0.3           # ... damage (coefficient) a Reflection deals when it shatters
const REFLECTION_SHATTER_RADIUS := 5.0    # ... to the enemies within this many metres of you
const REFLECTION_SHATTER_THREAT := 4.0    # ... with this threat multiplier
const REFLECTION_SHATTER_COOLDOWN := 0.5  # ... seconds it takes off every Arcane spell and ability you have on cooldown
const RIPPLE_REFLECTION_ENEMIES := 3      # Ripple: enemies it has to hit to make a Reflection
const MISSED_BEAT_WINDOW := 4.0           # Missed Beat: seconds after a Reflection shatters it can be used
const STAND_IN_TIME := 4.0                # Stand-In: seconds a Reflection takes each attack that gets through to you
const TRADE_PLACES_WINDOW := 3.0          # Trade Places: seconds of damage taken it looks back on
const TRADE_PLACES_PCT := 20.0            # ... % of that damage healed for each Reflection given up
const CROWD_OF_ONE_TIME := 8.0            # Crowd of One: seconds your dodges don't use Reflections up
const DECOY_TIME := 3.0                   # Decoy: seconds enemies are forced to attack it; then it bursts
const DECOY_BURST_RADIUS := 5.0           # ... metres around it the burst reaches (who it draws in is the ability's radius)
## The Arcane tank's talents (their ranks' numbers are in talents.gd).
const SHARP_EDGES_RADIUS := 7.0           # Sharp Edges' capstone: metres a shatter reaches (instead of REFLECTION_SHATTER_RADIUS)
const SECOND_SELF_REFLECTIONS := 2        # Second Self: Reflections Double Up makes when it triggers
const WIDE_RINGS_ENEMIES := 2             # Wide Rings' capstone: enemies Ripple has to hit to make a Reflection (instead of RIPPLE_REFLECTION_ENEMIES)

## Arcane melee: a damage dealer with a melee weapon in each hand, on cooldowns
## alone. Every strike it lands with an Arcane melee ability leaves a Trace on
## it: a record of the damage that strike dealt. Encore replays every Trace on
## the target and uses them up. Swift Cut, Deep Cut, Late Cut and Wide Cut are
## its strikes; Double Time makes each strike leave more Traces.
## (Damage, cooldowns and radius are in ABILITIES.)
const TRACE_MAX := 3                      # Traces: the most you can hold (a new one pushes out the oldest)
const TRACE_TIME := 10.0                  # ... seconds each one lasts
const TRACE_MERGE_WINDOW := 0.25          # ... seconds in which the hits of one use of an ability share a Trace (Wide Cut: its largest hit)
const ENCORE_PCT := 60.0                  # Encore: % of a Trace's recorded damage each replay deals
const LATE_CUT_DELAY := 3.0               # Late Cut: seconds until it hits again for the same damage (added to its Trace)
const DOUBLE_TIME_TIME := 10.0            # Double Time: seconds it lasts
const DOUBLE_TIME_TRACES := 2             # ... Traces each strike leaves, and how many times as many you can hold
const STANDING_OVATION_TRACES := 1        # Standing Ovation's capstone: more Traces you can hold
const FULL_HOUSE_ENEMIES := 3             # Full House: enemies Wide Cut has to hit for your next Encore to reach other enemies too
const FULL_HOUSE_TIME := 6.0              # ... seconds you have to use that Encore
const FULL_HOUSE_PCT := 50.0              # ... % of a replay's damage each other enemy takes
const FULL_HOUSE_RADIUS := 5.0            # ... metres from Encore's target the other enemies can be
const CURTAIN_CALL_TRACES := 3            # Curtain Call: Traces Encore has to replay for each replay to deal more damage

## The Arcane book's open talents: they work with every book's spells and
## abilities (their ranks' numbers are in talents.gd).
const ECHO_PCT := 30.0                    # Echo: % of a hit's damage its repeat deals
const ECHO_ARCANE_PCT := 15.0             # ... when it repeats an Arcane spell or ability
const ECHO_ARCANE_CHANCE_MULT := 2        # ... whose chance to be repeated is this many times as high
const ECHO_DELAY := 0.2                   # ... seconds after the hit its repeat lands
const BORROWED_TIME_COOLDOWN := 20.0      # Borrowed Time: a spell or ability with at least this cooldown coming off it boosts your next one
const BORROWED_TIME_TIME := 15.0          # ... seconds that boost waits to be used
const BORROWED_TIME_HITS := 0.4           # ... seconds in which every hit of the spell or ability that uses it gets it (one that hits several enemies)
const SLIPSTREAM_TIME := 3.0              # Slipstream: seconds you move faster after a blink or dash
# Arcane talents of the ribbon tree (ranks: talents.gd; code: arcane_talents.gd).
const WOUND_UP_MAX := 5                   # Wound Up: most other Arcane spells on cooldown that count
const CLOCK_HANDS_COOLDOWNS := 3          # Clock Hands: Arcane spells on cooldown it needs
const SECOND_HAND_SECONDS := 1.0          # Second Hand: seconds it takes off another Arcane spell
const ON_THE_DOT_TIME := 2.0              # On the Dot: seconds after coming off cooldown a cast still counts
const TURNING_GEARS_TIME := 6.0           # Turning Gears: seconds the Haste lasts
const TURNING_GEARS_STACKS := 3           # ... most stacks
const UNWINDING_TIME := 10.0              # Unwinding: seconds the instant cast waits for you
const QUICK_ANSWER_TIME := 3.0            # Quick Answer: seconds after a dodge the stronger ability waits
const GLASS_DUST_TIME := 4.0              # Glass Dust: seconds an enemy hit by a shatter deals less damage to you
const FRESH_TRACE_HELD := 2               # Fresh Trace: works while you hold fewer Traces than this
const FINAL_ACT_HEALTH := 35.0            # Final Act: works on enemies below this % of their health
const CURTAIN_RISE_TIME := 4.0            # Curtain Rise: seconds after a replay the stronger cut waits
const SPARE_MOMENT_COOLDOWN := 20.0       # Spare Moment: cooldowns at least this long recover faster
const KEEP_MOVING_CASTS := 2              # Keep Moving's capstone: casts on the move one Glint covers

## The Fire and Lightning books' open talents (they work with every book's
## spells and abilities; their ranks' numbers are in talents.gd).
const TEMPERED_TIME := 8.0                # Tempered: seconds each block's Armor lasts (a new block renews all of it)
const TEMPERED_STACKS := 3                # ... and how many times it stacks
const SPILLOVER_RADIUS := 6.0             # Spillover: metres from the target a critical strike's share may jump
const CHANGE_OF_PACE_TIME := 6.0          # Change of Pace: seconds its damage lasts (a new stack renews all of it)
const CHANGE_OF_PACE_STACKS := 3          # ... and how many times it stacks
const DIG_IN_TIME := 2.0                  # Dig In: seconds of standing still before it starts
const DIG_IN_SLACK := 0.05                # ... metres you may shift from where you stopped without it counting as moving

## (In the game Decay is called the Breach, a hole under an enemy that demons
## claw through, and several of these spells have new names: see player.gd,
## "Shadow caster: Decay". The constants keep the first names.)
## Shadow caster: Decay. Decay is the caster's own damage over time on an enemy,
## kept as an amount of damage. Every DECAY_TICK seconds (faster with Haste) it
## deals DECAY_TICK_PCT % of that amount and shrinks by as much; a tick can
## critically strike, and what the crit adds comes on top (the amount shrinks no
## faster). Blight puts it on a target and OPENS it for DECAY_OPEN_TIME seconds:
## while it is open, the caster's other Shadow spells add DECAY_FEED_PCT % of the
## direct damage they deal to it. After that it is closed: it keeps dealing
## damage but can't grow, and once less than DECAY_LAST_DROP is left its next
## tick deals all of it. Blight opens a closed one again and keeps its amount.
## (Damage, costs, cast times and cooldowns are in ABILITIES.)
const DECAY_TICK := 1.0                   # Decay: seconds between its ticks (faster with Haste)
const DECAY_TICK_PCT := 8.0               # ... % of its amount each tick deals, and it shrinks by
const DECAY_OPEN_TIME := 15.0             # ... seconds Blight opens it for
const DECAY_FEED_PCT := 50.0              # ... % of a Shadow spell's direct damage added to it while it is open
const BLIGHT_FEED_PCT := 100.0            # ... % of Blight's own damage added to it
const ERODE_FEED_PCT := 100.0             # ... % of Erode's (Beckon): the spell that builds it
const DECAY_LAST_DROP := 1.0              # ... a closed Decay with less than this left (a coefficient: a standard spell hit) ends with its next tick, which deals all of it
const DECAY_JUMP_RADIUS := 10.0           # ... metres: when the enemy dies, what is left moves to the nearest enemy within this
const DECAY_SYNC_EVERY := 0.25            # ... seconds between updates of the amount its debuff shows (the party sees it too)
const CALL_DUE_BONUS_PCT := 25.0          # Call Due: % more than the Decay it takes out (it deals all of it at once; this hit can't crit)
const GNAW_TIME := 4.0                    # Gnaw: seconds the Decay on the target ticks faster
const GNAW_SPEED_MULT := 2.0              # ... how many times as often it ticks
const SPILL_PCT := 50.0                   # Spill: % of the target's Decay each copy gets
const SPILL_TARGETS := 4                  # ... enemies it is copied onto at most
const SPILL_RADIUS := 8.0                 # ... within this many metres of the target
const HUSH_DECAY := 1.0                   # Hush: added to an open Decay when it interrupts a cast (a coefficient: a standard spell hit)
const TAKE_IT_BACK_PCT := 30.0            # Take It Back: % of the target's Decay it removes and turns into a shield
const TAKE_IT_BACK_TIME := 8.0            # ... seconds the shield lasts
const BOTTOMLESS_TIME := 8.0              # Bottomless: seconds Decay does not shrink when it ticks

## Shadow melee: the Hounds. With no Hounds out, the next Shadow melee ability
## (HOUND_CALLERS in player.gd) calls two demon dogs up through the ground. They
## stay HOUND_TIME seconds and bite the enemy their owner last struck. They have
## no stats of their own: every hit of theirs is the player's (level, Attack /
## Spell Power, crit, Haste, damage bonuses, Lifesteal, threat), dealt as a proc.
## Enemies cannot target them. The kit runs on Fury: Sic and Open Up build it,
## and any ability that spends Fury Rouses the Hounds. When their time is up each
## drags at its prey once, and the next Shadow melee ability calls a new pair.
## (Fury costs and gains, cooldowns, weapon damage and radius are in ABILITIES.)
const HOUND_COUNT := 2                    # Hounds: how many are called
const HOUND_TIME := 30.0                  # ... seconds they stay
const HOUND_BITE := 0.15                  # ... damage of one bite (a coefficient; it scales like an ability)
const HOUND_BITE_EVERY := 1.5             # ... seconds between one Hound's bites (faster with Haste)
const HOUND_LEASH := 30.0                 # ... metres from you their prey can be before they come back to heel
const HOUND_DRAG := 0.75                  # ... damage each deals to its prey when their time is up (Drag Down)
const ROUSED_TIME := 8.0                  # Roused: seconds it lasts (spending Fury again starts it over; it does not stack)
const ROUSED_PCT := 25.0                  # ... % more damage the Hounds' bites deal
const LAID_OPEN_TIME := 8.0               # Open Up: seconds its mark stays on the target
const LAID_OPEN_PCT := 30.0               # ... % more damage the Hounds' bites deal to the marked enemy
const HOUND_LUNGE := 0.6                  # Both At Once: damage of each Hound's lunge
const RUN_DOWN_TIME := 6.0                # Run Them Down: seconds the Hounds' bites reach other enemies too
const RUN_DOWN_TARGETS := 2               # ... other enemies each bite hits
const RUN_DOWN_PCT := 50.0                # ... % of the bite's damage each of them takes
const RUN_DOWN_REACH := 5.0               # ... metres from the bitten enemy they can be
const GUARD_DOGS_TIME := 5.0              # Guard Dogs: seconds it lasts (the Hounds keep biting)
const GUARD_DOGS_PCT := 30.0              # ... % less damage you take
const OFF_THE_CHAIN_TIME := 10.0          # Off the Chain: seconds it lasts, and how much longer the Hounds stay
const OFF_THE_CHAIN_SPEED_PCT := 50.0     # ... % faster the Hounds bite
## Bring It Down (its cooldown is in ABILITIES) sends the Hounds back under
## early: each drags at its prey as if their time was up.
## The Hounds' talents (their per-rank numbers are in talents.gd):
const WORKED_UP_CRIT := 10.0              # Worked Up's capstone: % more critical strike chance of bites while Roused
const STILL_WET_PCT := 10.0               # Still Wet's capstone: % more damage your own direct hits deal to an enemy you Laid Open
const PINCER_FURY := 10.0                 # Pincer's capstone: Fury back for each lunge that critically strikes
const SLIPPED_LEASH_HOUNDS := 1           # Slipped Leash's capstone: Hounds that join for as long as Off the Chain lasts
const DRAG_KILL_WINDOW := 1.5             # Take It With You's capstone: seconds after Drag Down in which the enemy's death is its kill
const FEEDING_FRENZY_TIME := 8.0          # Feeding Frenzy: seconds its Haste lasts (another death starts the time over)
const SCENT_OF_BLOOD_HEALTH_PCT := 35.0   # Scent of Blood: works on enemies below this % of their health
const PACK_LEADER_EVERY := 10.0           # Pack Leader's capstone: Fury spent for each step
const PACK_LEADER_TIME := 1.0             # ... seconds each step keeps the Hounds out longer
const PACK_LEADER_MAX := 10.0             # ... seconds at most for each pair

## Shadow healer: the Strings. A demon floats behind the healer and holds allies
## up on Strings. There are STRING_MAX of them, on allies and enemies together:
## each is in hand (a charge of the String ability), tied to someone, or
## recovering. A String on an ally heals every second and up to STRING_STACKS go
## on one ally. A String on an enemy is crossed with the ally tied last: part of
## the damage that ally takes is dealt to the enemy instead. A String that runs
## its full time (or whose target dies or gets out of reach) is back in hand at
## once; one that is used up (replaced on an ally who is full, pulled taut) comes
## back STRING_RECHARGE seconds later, one after the other.
## (Mana costs, cooldowns, cast times and ranges are in ABILITIES, heal sizes in HEALS.)
const STRING_MAX := 6                     # Strings: how many the demon has
const STRING_RECHARGE := 10.0             # ... seconds until a used-up String is back in hand
const STRING_TIME := 15.0                 # ... seconds one stays on an ally
const STRING_ENEMY_TIME := 10.0           # ... and on an enemy
const STRING_STACKS := 3                  # ... how many one ally can have
const STRING_HEAL := 0.07                 # ... heal of each String on an ally, per tick (a coefficient)
const STRING_TICK := 1.0                  # ... seconds between its heals (faster with Haste)
const STRING_GCD_MULT := 0.5              # ... the String ability's share of a global cooldown
const STRING_SHARE_PCT := 30.0            # ... % of a heal on an ally on a String that every other ally on one gets
const TAKING_THE_WEIGHT_RANGE := 40.0     # Taking the Weight's capstone: metres apart a crossing holds (instead of STRING_CROSS_RANGE)
const HEAVE_CAST := 0.5                  # Heave's capstone: seconds off Hoist's cast on an ally with every String it can hold
const LEAN_ON_ME_TIME := 4.0             # Lean On Me: seconds you take less damage after healing someone else
const STRING_CROSS_PCT := 3.0            # Crossed Strings: % of the damage the ally takes that the enemy takes instead
const STRING_CROSS_RANGE := 30.0          # ... metres apart the two can be before the enemy's String breaks
const STRING_LEASH := 60.0                # Strings: metres from you a target can be before its Strings break
const LOOSE_STRING_TIME := 8.0            # Cat's Cradle: seconds its extra Strings last (they count as none of yours)
const TUG_TIME := 4.0                     # Tug: seconds the ally's Strings heal faster
const TUG_SPEED_MULT := 2.0               # ... how many times as often
const KNOT_TIME := 30.0                   # Knot: seconds the ally's Strings do not run out
## The Strings' newer talents (per-rank numbers in talents.gd).
const HOLD_FAST_HEALTH_PCT := 35.0        # Hold Fast: works on allies below this % of their health
const STEADY_HANDS_ALL_OUT_PCT := 10.0    # Steady Hands' capstone: % larger heals while no String is left in hand
const DOUBLE_THREAD_TIME := 10.0          # Double Thread: seconds you have to place the doubled String
const CUPPED_HANDS_TIME := 5.0            # Cupped Hands: seconds the shield lasts
const CUPPED_HANDS_SHIELD := 0.45         # ... its size, as a share of your Heal spell (like every shield; Rime Ward makes it bigger)
const CUPPED_HANDS_PER_STRING := 0.2      # ... more for each String on the ally (a share of Heal too)
const BEHIND_ITS_BACK_TIME := 6.0         # Behind Its Back: seconds it lasts
const BEHIND_ITS_BACK_PCT := 40.0         # ... % less damage you take
const SLACK_TIME := 4.0                   # Slack: seconds your Strings stop healing
const SLACK_MANA := 1.0                   # ... mana back for each String out (points: 10% of base mana each)
const NOT_FINISHED_STRINGS := 3           # Not Finished With You: Strings in hand it takes, and puts on the ally
const STRING_UP_TIME := 3.0               # String Up: seconds the enemy hangs (stunned)
const TANGLE_TIME := 4.0                  # Tangle: seconds enemies are rooted
const STILL_STANDING_TIME := 8.0          # Still Standing: seconds in which a killing blow is held off
const STILL_STANDING_HOLD := 4.0          # ... seconds the Strings then hold the ally up (it cannot die)
const STILL_STANDING_HEALTH_PCT := 25.0   # ... % of health it needs by the end of that to stay up
const CUT_STRINGS_HEAL := 1.2             # Cut the Strings: heal for each String on an ally (a coefficient)
const CUT_STRINGS_DAMAGE := 1.2           # ... Shadow damage to an enemy with a String
const YANK_STOP := 1.5                    # Yank: metres in front of you the ally ends up

## Holy healer: the Hymns (player.gd, "Holy healer: the Hymns"). Heals are in HEALS
## (coefficients; REFERENCE_HEAL = one old Heal spell). You sing one of three
## Hymns; your heals give Verses; singing another Hymn with VERSE_MAX of them makes
## the Hymn you enter boom.
const VERSE_MAX := 6                      # Verses you can hold (more are wasted)
## What each ability gives: [Verses, the Hymn they suit] ("" = the Hymn you sing; Mercy with none).
const VERSE_GAINS := {"psalm": [1, "mercy"], "outpour": [2, "mercy"], "lift": [1, "mercy"], "refrain": [1, "mercy"],
	"canticle": [2, "chorus"], "exultation": [1, "chorus"], "antiphon": [1, "chorus"],
	"shelter": [1, "vigil"], "steadyvoice": [2, "vigil"], "highnote": [1, ""]}
const VERSE_DRAIN_EVERY := 2.0            # out of combat, one Verse fades every this many seconds
const MERCY_HEAL_PCT := 20.0              # Mercy: your single-target heals heal this % more
const CHORUS_SPLASH_PCT := 30.0           # Chorus: your direct heals also heal allies near the target for this %
const CHORUS_SPLASH_TARGETS := 2          # ... this many of them
const CHORUS_SPLASH_RADIUS := 8.0         # ... within this many metres of the target
const VIGIL_RADIUS := 15.0                # Vigil: allies within this many metres of you ...
const VIGIL_DR_PCT := 5.0                 # ... take this % less damage
const VIGIL_WARD_PCT := 10.0              # ... and your heals leave a shield worth this % of the heal
const VIGIL_WARD_TIME := 3.0              # ... for this many seconds
const VIGIL_TELL_EVERY := 1.0             # the aura is renewed on allies every this many seconds ...
const VIGIL_BUFF_TIME := 1.5              # ... for this long (so it fades soon after they leave it)
const BENEDICTION_HEAL := 6.6             # boom of Mercy: a heal (3 old Heals) on your friendly target
const CHORALE_HEAL := 2.2                 # boom of Chorus: a heal on every ally ...
const CHORALE_RADIUS := 30.0              # ... within this many metres
const BULWARK_SONG_PCT := 30.0            # boom of Vigil: allies take this % less damage ...
const BULWARK_SONG_TIME := 5.0            # ... for this many seconds ...
const BULWARK_SONG_RADIUS := 15.0         # ... within this many metres of you
const BOOM_MATCH_PCT := 10.0              # a boom is this % stronger for each spent Verse of its colour
const BULWARK_SONG_MATCH_TIME := 0.5      # ... Bulwark of Song lasts this much longer instead
const FULL_CHOIR_PCT := 50.0              # Full Choir: the third of three different booms is this % stronger
const FULL_CHOIR_REFUND := 2              # ... and gives back this many Verses of its colour
const REFRAIN_TIME := 12.0                # Refrain: seconds its heal over time lasts ...
const REFRAIN_TICK := 1.0                 # ... healing every this many seconds (faster with Haste)
const CANTICLE_TARGETS := 5               # Canticle: injured allies it heals (lowest health first)
const ANTIPHON_SELF_PCT := 50.0           # Antiphon: you are healed for this % of its heal on the target
const SHELTER_TIME := 8.0                 # Shelter: seconds its shield lasts
const STEADY_VOICE_PCT := 10.0            # Steady Voice: allies take this % less damage ...
const STEADY_VOICE_TIME := 6.0            # ... for this many seconds
const HIGH_NOTE_HEAL_PCT := 50.0          # High Note: your lowest-health ally is healed for this % of its damage ...
const HIGH_NOTE_REACH := 30.0             # ... if within this many metres of you
const REPRISE_PCT := 40.0                 # Reprise: repeats your last boom at this % ...
const REPRISE_WINDOW := 6.0               # ... within this many seconds of it ...
const REPRISE_COST := 3                   # ... for this many Verses
const SWELL_TIME := 10.0                  # Swell: seconds every ability gives ...
const SWELL_EXTRA := 1                    # ... this many more Verses
const REST_PCT := 40.0                    # Rest: you take this % less damage ...
const REST_TIME := 6.0                    # ... for this many seconds (and singing without a boom keeps your Verses)
const MERCYS_EAR_HEALTH_PCT := 35.0       # Mercy's Ear (talent): healing an ally below this % health gives a Verse
const MANY_VOICES_ALLIES := 3             # Many Voices (talent): a heal that lands on this many allies gives a Verse
const WATCHFUL_HIT_PCT := 10.0            # Watchful (talent): a hit of this % of max health on an ally in your Vigil gives a Verse
const OPEN_DOORS_COOLDOWN := 4.0          # Open Doors (talent) capstone: Shelter's cooldown
const RESOUNDING_DAMAGE := 0.6            # Rune of Resounding (Epic): Holy damage of a boom around it ...
const RESOUNDING_RADIUS := 8.0            # ... within this many metres (split evenly past the AoE cap)
const OVERTURE_TIME := 3.0                # Rune of the Overture (Epic): after a boom, your next cast within this many seconds is instant

## Holy tank: the Censer (player.gd, "Holy tank: the Censer"). Not an item: your
## first censer ability makes it appear at your side; it fades out of combat. Its
## fullness is Incense, a buff of up to INCENSE_MAX stacks. Abilities give little;
## most of it lies on the ground as motes of light that you walk over to collect.
## Spending Incense drops part of it as motes again. (Mana costs, cooldowns,
## ranges and radii are in ABILITIES; heal sizes are coefficients like HEALS.)
const INCENSE_MAX := 100                  # Incense: the most stacks (a full censer)
const INCENSE_TIME := 30.0                # ... seconds it lasts; any gain makes it last this long again (spending doesn't)
const INCENSE_DECAY_EVERY := 2.0          # ... and it loses a stack every this many seconds (not while the censer is raised)
const INCENSE_BLOCK := 0.15               # ... % Block each stack gives (the barrier of light)
const INCENSE_AURA_FULL := 0.06          # ... damage (coefficient) at a full censer (less with fewer stacks), every tick, to enemies around you ...
const INCENSE_AURA_RADIUS := 5.0          # ... within this many metres ...
const INCENSE_AURA_EVERY := 1.0           # ... every this many seconds ...
const INCENSE_AURA_THREAT := 4.0          # ... with this threat multiplier (split evenly past the AoE cap)
const INCENSE_PER_HIT := 1                # Incense for each hit you take ...
const INCENSE_PER_BLOCK := 2              # ... or block
const CENSER_LINGER := 3.0                # the censer fades this many seconds after you leave combat
const MOTE_VALUE := 10                    # a mote of light: the Incense it holds ...
const MOTE_HEAL_SHARE := 0.1             # ... the heal it gives when you pick it up, in old Heals (REFERENCE_HEAL)
const MOTE_TIME := 10.0                   # ... seconds it lies on the ground
const MOTE_PICKUP := 1.2                  # ... metres you have to come within to pick it up
const MOTE_SCATTER_MIN := 2.0             # ... it lands this many metres ...
const MOTE_SCATTER_MAX := 5.0             # ... to this many metres from the enemy (from you with none)
const MOTE_MAX := 12                      # the most motes you can have on the ground (the oldest fades first)
const MOTE_SPEND_PCT := 60.0              # spending Incense drops motes worth this % of what was spent ...
const MOTE_SPEND_MAX := 5                 # ... at most this many per spend
const CENSER_SWING_INCENSE := 3           # Censer Swing: Incense it gives (and it knocks 1 mote loose from the target)
const HALLOWED_ARC_INCENSE := 1           # Hallowed Arc: Incense for each enemy hit ...
const HALLOWED_ARC_MOTES := 3             # ... and a mote knocked loose from each, at most this many
const BECKON_INCENSE := 3                 # Beckon: Incense it gives (and it drops 1 mote at the target)
const POUR_OUT_MIN := 30                  # Pour Out: needs this much Incense; spends all of it ...
const POUR_OUT_PER_STACK := 0.03          # ... damage (coefficient) per stack spent, to enemies within its radius
const ABSOLVE_MAX := 40                   # Absolve: spends up to this much Incense ...
const ABSOLVE_PER_STACK := 0.05           # ... heals you for this many old Heals (REFERENCE_HEAL) per stack spent
const AUREOLE_COST := 30                  # Aureole: spends this much Incense ...
const AUREOLE_BLOCK := 25.0               # ... for this much more Block ...
const AUREOLE_TIME := 5.0                 # ... for this many seconds
const RAISE_CENSER_TIME := 8.0            # Raise the Censer: seconds it hangs over the enemies ...
const RAISE_CENSER_HEIGHT := 4.0          # ... this many metres up
const RAISE_CENSER_TAUNT := 4.0           # ... enemies within its radius of it must attack you for this many seconds
const RAISE_CENSER_SHED_EVERY := 1.0      # ... it sheds a mote around itself every this many seconds
const UNFALLEN_TIME := 8.0                # Unfallen: seconds you can't drop below 1 health ...
const UNFALLEN_INCENSE_MULT := 2          # ... hits give this many times the Incense ...
const UNFALLEN_HEAL_PCT := 30.0           # ... and when it ends you heal for this % of the damage taken during it
const DEEP_POUR_MOTE_PCT := 80.0          # Deep Pour (talent) capstone: Pour Out drops motes worth this % instead
const BRIGHT_BURST_DAMAGE := 0.15         # Rune of the Bright Burst (Epic): picking up a mote deals this Holy damage ...
const BRIGHT_BURST_RADIUS := 5.0          # ... to enemies within this many metres (split evenly past the AoE cap)
const BRIGHT_BURST_THREAT := 4.0          # ... with this threat multiplier

## Holy healer #2: the Prisms (player.gd, "Holy healer: the Prisms"). Nothing to do
## with the Hymns. You place floating prisms; your direct heals fire a beam from
## you to the ally, and every prism the beam passes through stores some of the
## heal as light (and makes the heal stronger). Shattering a prism heals the
## allies around it with its light and hurts the enemies there. Light is in heal
## coefficients (like HEALS; REFERENCE_HEAL = one old Heal). (Mana costs,
## cooldowns, cast times and ranges are in ABILITIES, heal sizes in HEALS.)
const PRISM_MAX := 3                      # prisms you can have (a new one replaces the oldest)
const PRISM_TIME := 60.0                  # seconds a prism lasts
const PRISM_HOVER := 1.6                  # metres it floats over the ground
const PRISM_BEAM_WIDTH := 1.0             # a prism is on a beam within this many metres of its line
const PRISM_CHARGE_PCT := 25.0            # each prism on the beam stores this % of the heal as light ...
const PRISM_CAP_HEALS := 3.0             # ... up to this much light, in old Heals (REFERENCE_HEAL)
const PRISM_AMPLIFY_PCT := 10.0           # a heal is this % stronger for each prism it passed through
const PRISM_SHATTER_RADIUS := 8.0         # a shattering prism heals the allies (its light, split between them) ...
const PRISM_SHATTER_DAMAGE := 1.0         # ... and hurts the enemies within this many metres: this damage (coefficient) at full light
const PRISM_FLICKER_TIME := 0.25          # moving a prism: seconds it flickers out, then in
const MENDING_RAY_TICKS := 6              # Mending Ray: its heal comes in this many ticks over the channel
const PRISM_WARD_TIME := 8.0              # Prism Ward: seconds its shield lasts
const KALEIDOSCOPE_TIME := 10.0           # Kaleidoscope: seconds your beams pass through every prism

## Holy archer: Lightstring (player.gd, "Holy archer: Lightstring"). Prisms come in
## two colours: the healer's white ones work only with heals, the archer's gold
## ones only with arrows (light never turns from one into the other); the
## PRISM_MAX limit counts both. Every shot is a line from you to the enemy: each
## gold prism it passes through fires a refracted arrow at another enemy near it
## (none: the shot is stronger instead) and stores part of the damage as light.
const REFRACT_PCT := 40.0                 # a refracted arrow hits for this % of the shot ...
const REFRACT_RADIUS := 8.0               # ... at another enemy within this many metres of the prism
const REFRACT_FOCUS_PCT := 10.0           # no other enemy there: the shot is this % stronger for that prism
const GOLD_CHARGE_PCT := 25.0             # a gold prism on the line stores this % of the shot's damage as light (same cap as white)
const AUTO_SHOT_CHARGE_PCT := 10.0        # auto-shots: charge this % instead ...
const AUTO_SHOT_REFRACT_PCT := 20.0       # ... and refract for this % instead
const PRISM_ARROW_CHARGES := 2            # Prism Arrow: charges (its cooldown is the recharge)
const REFRACTING_SHOT_PCT := 60.0         # Refracting Shot: its refracted arrows hit for this % instead
const SUNLIT_DRAIN := 0.03                # Sunlit Arrow: bonus damage (coefficient) per point of light it drains (three full prisms: about +0.6)
const DEEP_BURN_KEEP_PCT := 25.0          # Deep Burn (talent) capstone: Sunlit Arrow leaves this % of the light
const BREAKER_DAMAGE := 0.6               # Prism Breaker: damage (coefficient) of the shattering prism ...
const BREAKER_LIGHT := 0.06               # ... plus this much per point of its light (a full prism: about +0.4) ...
const BREAKER_RADIUS := 8.0               # ... to enemies within this many metres (split past the AoE cap)
const STEP_OF_LIGHT_OFFSET := 1.2         # Step of Light: you appear this many metres from the prism
const VOLLEY_TIME := 8.0                  # Spectrum Volley: seconds ...
const VOLLEY_EVERY := 1.0                 # ... each gold prism fires every this many seconds ...
const VOLLEY_DAMAGE := 0.4                # ... an arrow of this damage (coefficient) ...
const VOLLEY_LIGHT := 0.02                # ... plus this much per point of its light
const VOLLEY_RADIUS := 8.0                # ... at the nearest enemy within this many metres

## Holy open talents (their per-rank numbers are in talents.gd; these are the fixed parts).
const OVERFLOWING_TIME := 6.0             # Overflowing: seconds the shield from overhealing lasts ...
const OVERFLOWING_CAP_PCT := 10.0         # ... at most this % of the ally's maximum health
const PENITENT_HIT_PCT := 15.0            # Penitent: a hit worth this % of your maximum health ...
const PENITENT_TIME := 10.0               # ... makes your next heal on yourself stronger, for up to this many seconds
const ZEAL_COOLDOWN := 30.0               # Zeal: using an ability with at least this cooldown ...
const ZEAL_TIME := 4.0                    # ... makes you faster for this many seconds
const SECOND_BREATH_LOW_PCT := 30.0       # Second Breath: a heal of yours that lifts an ally from below this % health ...
const SECOND_BREATH_HIGH_PCT := 50.0      # ... to above this % gives you mana back
const WATCHFUL_EYE_WINDOW := 2.0          # Watchful Eye: your heals on an ally hit within this many seconds heal more
## The Holy ribbon tree's newer talents (per-rank numbers in talents.gd).
const CANDLELIGHT_TIME := 6.0             # Candlelight: seconds a heal on an ally keeps your next damaging spell or ability stronger
const CANDLELIGHT_HITS := 0.4             # ... seconds in which every hit of that spell or ability gets it (one that hits several enemies)
const FIRST_LIGHT_TIME := 6.0             # First Light: seconds after you enter combat that you deal and heal more
const MERCY_SEAT_HEALTH_PCT := 35.0       # Mercy Seat: Benediction heals more on an ally below this % of their health
const RADIANCE_MATCH_PCT := 20.0          # Radiance's capstone: % stronger (or longer) a boom whose Verses all suit it is
const FULL_CENSER_INCENSE := 75           # Full Censer: Incense you need for less damage taken
const CENSERS_WEIGHT_FULL_PCT := 10.0     # Censer's Weight's capstone: % more on top with a full censer
const HOLD_THE_LINE_HEALTH_PCT := 35.0    # Hold the Line: works while you are below this % of your health
const AFTERSHINE_TIME := 6.0              # Aftershine: seconds an ally a shattering prism healed is healed more by you
const LIFELINE_HEALTH_PCT := 35.0         # Lifeline: works on allies below this % of their health
const BRILLIANCE_PRISMS := 3              # Brilliance's capstone: prisms a heal's beam has to pass through ...
const BRILLIANCE_PCT := 20.0              # ... to be this % stronger
const LINED_UP_PRISMS := 2                # Lined Up: gold prisms a shot has to pass through
const SUNDOWN_HEALTH_PCT := 35.0          # Sundown: works on enemies below this % of their health
const SUNSTEEL_START_PCT := 33.0          # Sunsteel's capstone: % of their light cap a new gold prism starts with

## Rune of the Open Wound (Rare): Blight is instant, with a cooldown, and opens Decay for less time.
const OPEN_WOUND_COOLDOWN := 15.0         # seconds of cooldown Blight then has
const OPEN_WOUND_OPEN_TIME := 8.0         # seconds it opens Decay for (instead of DECAY_OPEN_TIME)

## What the Breach looks like (scripts/breach_fx.gd): the hands clawing out of
## the hole under the enemy reach higher up its body the more damage is in it,
## and over its head with this many standard hits of the enemy's level in it
## (or with as much as the enemy's whole health, if that is less).
const BREACH_FX_FULL_HITS := 10.0

## Rune of the Long Fall (Epic): when this much of what is left in a Decay (the
## Breach) would be enough to kill its enemy, all of it is dealt at once. It is
## a real hit: the enemy takes the damage, it is not simply killed.
const LONG_FALL_PCT := 50.0               # % of the Decay that has to cover the enemy's health

## Rune of Rot (Rare, up to 3 equipped): the other books' spells add a share of
## their direct damage to an open Decay. (It was the talent Everything Rots.)
const ROT_RUNE_PCT := 5.0                 # % of that damage, for each copy of the rune equipped

## The Shadow book's talents (their ranks' numbers are in talents.gd; these are
## the fixed parts). Decay's: Baited Steel, Lure, Interest, Small Change,
## Next of Kin, Bitter End, No Floor, Hooked Claws, Wider Still. Open ones (they work
## with every book's spells and abilities): Slow Death, Wasting, Finish It,
## Spite, Carrion, Inevitable.
const INTEREST_TIME := 5.0                # Interest's capstone: seconds the instant Blight waits for you
const NEXT_OF_KIN_SECOND_PCT := 50.0      # Next of Kin's capstone: % of what moved on that the next nearest enemy gets as well
const RUNNING_OVER_OPEN_TIME := 5.0       # Wider Still's capstone: seconds every copy Widen makes is open for at least
const FINISH_IT_HEALTH_PCT := 25.0        # Finish It: works on enemies below this % of their health
const SPITE_TIME := 4.0                   # Spite: seconds the boost waits for your next spell or ability
const SPITE_HITS := 0.4                   # ... seconds in which every hit of the spell or ability that uses it gets it (one that hits several enemies)
const INEVITABLE_TIME := 8.0              # Inevitable: seconds after your first damage to an enemy before it works on that enemy
const HOOKED_CLAWS_HOLD := 0.5             # Hooked Claws' capstone: seconds a tick that critically strikes keeps the Breach open
const HOOKED_CLAWS_MAX := 3.0              # ... seconds at most each time it is opened

## Rune of the Two-Way Mirror (Rare): Mirror Sigil also repeats Reflection
## shatters, at the share it repeats spells at (no number of its own).

## Rune of the Carried Sigil (Epic): Mirror Sigil follows you, and repeats less.
const CARRIED_SIGIL_PCT := 20.0          # % of each Arcane spell hit it repeats (instead of MIRROR_SIGIL_PCT)

## Rune of the Afterimage (Rare): Phase Step and Flicker leave an image behind.
const AFTERIMAGE_TIME := 4.0             # seconds the image waits for your next spell
const AFTERIMAGE_PCT := 50.0             # % of that spell's damage the image repeats
const AFTERIMAGE_BURST := 0.5            # seconds after the spell's first hit its other hits still count (an AoE, a volley)
const AFTERIMAGE_TRAVEL := 1.0           # ... for a channel: this long after the channel ends (darts still in the air)

## Frost runes.
const PERMAFROST_CRIT_FACTOR := 0.3      # Permafrost: extra damage % = crit chance x this
const PERMAFROST_TIME := 6.0             # ... dealt over this many seconds (1 tick / s)
const COLD_PRECISION_EVERY := 6          # Cold Precision: every Nth Frost spell / ability crits
const COLD_PRECISION_WINDOW := 3.0       # seconds that cast's hits (projectiles, volleys) stay empowered
const FROZEN_AEGIS_RADIUS := 10.0        # Frozen Aegis: allies within this many metres
const FROZEN_AEGIS_ON_FREEZE := 0.5      # shield = this x a Heal spell, when you freeze an enemy
const FROZEN_AEGIS_ON_HIT := 0.2         # shield = this x a Heal spell, when you hit a Frozen enemy
const FROZEN_AEGIS_CAP := 1.0            # shields stack up to this x a Heal spell
const FROZEN_AEGIS_TIME := 10.0
const EVERLASTING_RIME_MULT := 2.0       # Everlasting Rime: Rime Shell absorbs x this
# Frost healer: Cold Comfort (scripts/player/frost_healer.gd). Shields as a share of
# the reference heal ({h:..} in tooltips); Rime Shell's own size is HEALS["rimeshell"].
const RIME_SHARDS_PCT := 30.0            # a Rime Shell of yours that breaks on an ally heals allies near it for this % of its shield
const RIME_SHARDS_RADIUS := 8.0          # ... within this many metres (split past the AoE cap)
const RUNOFF_PCT := 50.0                 # a Rime Shell of yours that runs out on an ally heals them for this % of what was left ...
const RUNOFF_TIME := 4.0                 # ... over this many seconds (one tick a second)
const MELTWATER_THAWING_PCT := 30.0      # Meltwater heals this % more on an ally with your Thawing
const BREAK_ICE_PCT := 80.0              # Break the Ice: this % of the shell's remaining shield heals allies near them
const RIME_VEIL_SHARE := 0.2             # Rime Veil: a shield this share of a heal ...
const RIME_VEIL_EVERY := 3.0                 # ... refilled every this many seconds ...
const RIME_VEIL_TIME := 12.0             # ... for this long
const LATTICE_LINKS := 3                 # Frost Lattice: your target and the nearest allies with your Rime Shell, this many in all ...
const LATTICE_TIME := 20.0               # ... for this long: a hit on one linked shell is taken from all of them evenly
const RIMEFALL_SHARE := 0.3              # Rimefall: a shield this share of a heal on every ally near you ...
const RIMEFALL_PER_SHELL := 0.1          # ... plus this much per Rime Shell of yours on an ally ...
const RIMEFALL_MAX_SHELLS := 3           # ... counting up to this many
const RIMEFALL_TIME := 8.0
const FROST_TIDE_TIME := 10.0            # Frost Tide: for this long Rime Shell ignores Thawing and is instant on enemies too
const STILLWATER_HEALTH_PCT := 35.0      # Stillwater: only on an ally below this % health
const STILLWATER_TIME := 3.0             # ... encased (no damage, can't act; moving breaks out) this long ...
const STILLWATER_HEAL_PCT := 30.0        # ... then healed for this % of their max health
const SPLINTERHEAL_RADIUS := 10.0        # Splinterheal (talent): the lowest-health ally within this many metres of the shattered enemy
const SHARD_SPRAY_TIME := 3.0            # Shard Spray (talent): the little shield Rime Shards leave lasts this long

## The reference heal (what the old Heal spell healed): shields and heals sized as
## "a share of a heal" (Snow Ward, Cupped Hands, Frozen Aegis, {h:...} in tooltips) use it.
const REFERENCE_HEAL := 2.2

## Heal / absorb coefficients (1.0 = a standard hit's worth of health).
const HEALS := {"rimeshell": 1.1,
	"cinderwing": 1.1,   # each of the phoenix's heals (half a Heal spell)
	"intervalward": 1.5, # Interval Ward's shield
	# Holy healer (the Hymns), in old Heals (REFERENCE_HEAL 2.2): Psalm 1, Outpour 2.2, Lift 0.5,
	# Refrain 1.2 (its whole heal over time), Canticle 0.6 each, Exultation 0.45 each,
	# Antiphon 0.8 (and half that on you), Shelter's shield 1.2.
	"psalm": 2.2, "outpour": 4.84, "lift": 1.1, "refrain": 2.64, "canticle": 1.32, "exultation": 0.99,
	"antiphon": 1.76, "shelter": 2.64,
	"shadowstrike": 0.15,
	# Shadow healer (the Strings): its direct heals. (A String's own heal: STRING_HEAL.)
	"hoist": 3.5, "patchup": 2.25, "tug": 0.75, "catscradle": 1.0,
	# Holy healer #2 (the Prisms), in old Heals: Mending Ray 1.5 (all ticks), Bright Lance 1.8, Gleam 0.5, Prism Ward 1.2 (shield).
	"mendingray": 3.3, "brightlance": 3.96, "gleam": 1.1, "prismward": 2.64,
	# Nature healer (the Shepherd), in old Heals: Dewfall 1, Fawn 1 (the first ally; each bounce less),
	# Owl 1, Rootguard 0.8 (shield, + ROOTGUARD_PER_BLOSSOM), Heartwood Elk 0.5 each (+ ELK_PER_BLOSSOM).
	"dewfall": 1.6, "fawn": 1.6, "owl": 1.6, "rootguard": 1.35, "heartwoodelk": 0.85,
	# Frost healer (Cold Comfort), in old Heals: Meltwater 0.9.
	"meltwater": 1.98}
## Pacts (scripts/pacts.gd; every character can hold one for a dungeon). Each has
## a bonus, a drawback and a vow. Break the vow and the bonus turns into the same
## amount as a penalty until the dungeon ends; the drawback stays.
const PACT_UNBOWED_DAMAGE := 15.0        # Pact of the Unbowed: % more damage (broken: % less) ...
const PACT_UNBOWED_TAKEN := 10.0         # ... % more damage taken. Vow: never go down or die
const PACT_THIN_LINE_CRIT := 12.0        # Pact of the Thin Line: % critical strike chance (broken: that much less) ...
const PACT_THIN_LINE_HEALTH := 10.0      # ... % less max health
const PACT_THIN_LINE_FLOOR := 25.0       # ... vow: never drop below this % of your health
const PACT_RELENTLESS_HASTE := 10.0      # Pact of the Relentless: % Haste (broken: that much less) ...
const PACT_RELENTLESS_SLOW := 15.0       # ... % slower movement
const PACT_RELENTLESS_IDLE := 5.0        # ... vow: never this many seconds in combat without hitting an enemy or healing an ally
const PACT_SIDESTEP_COOLDOWN := 20.0     # Pact of the Sidestep: % faster cooldown recovery (broken: % slower) ...
const PACT_SIDESTEP_COST := 10.0         # ... % higher ability costs
const PACT_SIDESTEP_HIT := 25.0          # ... vow: never take one hit for more than this % of your max health
const PACT_PURIST_DAMAGE := 20.0         # Pact of the Purist: % more damage (broken: % less) ...
const PACT_PURIST_TAKEN := 5.0           # ... % more damage taken. Vow: never use an ability of another book
const PACT_PURIST_CONFIRM := 3.0         # ... seconds you have to press an ability again after its warning
const PACT_FAST_TAKEN := 10.0            # Pact of the Fast: % less damage taken (broken: % more) ...
const PACT_FAST_HEALING := 15.0          # ... % smaller healing received
const PACT_FAST_HEALING_BROKEN := 30.0   # ... and once it is broken. Vow: never heal yourself with a spell or ability
const PACT_SHEPHERD_HEALS := 15.0        # Pact of the Shepherd: % larger heals (broken: % smaller) ...
const PACT_SHEPHERD_SELF := 30.0         # ... % smaller heals of yours on yourself
const PACT_SHEPHERD_RANGE := 40.0        # ... vow: no party member goes down within this many metres of you
const PACT_VANGUARD_TAKEN := 12.0        # Pact of the Vanguard: % less damage taken (broken: % more) ...
const PACT_VANGUARD_DAMAGE := 10.0       # ... % less damage dealt. Vow: no enemy attacking you turns on a party member
const PACT_RESTLESS_RESOURCE := 25.0     # Pact of the Restless: % faster Mana, Fury and Energy gains (broken: % slower) ...
const PACT_RESTLESS_BLEED := 1.0         # ... % of max health lost every second out of combat (and no regeneration)
const PACT_RESTLESS_IDLE := 30.0         # ... vow: never this many seconds out of combat once the first fight has started
const PACT_RESERVOIR_COST := 20.0        # Pact of the Reservoir: % lower mana costs (broken: % higher) ...
const PACT_RESERVOIR_MANA := 15.0        # ... % less max mana
const PACT_RESERVOIR_FLOOR := 15.0       # ... vow: never drop below this % of your mana

## Secondary hits: chain jumps, splash, retaliation, bonus hits.
const EXTRA_HITS := {"chainlightning": 0.6, "stormshield": 0.2, "stormarrow": 0.4, "shattershot": 0.5,
	"shatteringslam": 0.75, "slagskin": 0.25,   # slagskin = shatter damage per Slag stack
	"drawthestorm": 0.3}                        # the zap each parry sends out
## Shatter damage (Rime Shell breaking, Frozen shattering): a Frost Bolt's worth.
const SHATTER_COEF := 1.0
## A Rime Shell's shatter that damages only ONE enemy deals this much more (%).
const RIME_SHELL_SOLO_PCT := 30.0
## A Frozen enemy shattering (Shattering Wave) deals this share of SHATTER_COEF.
const FROZEN_SHATTER_MULT := 0.5
const SHATTER_SLAM_THREAT := 3.0

# --- Dungeons ---------------------------------------------------------------------
## Enemy level in a group = party average pulled toward the highest player's
## level by this much (0 = plain average, 1 = highest level). 0.5: a level 50
## with a level 1 friend fights level 38 enemies, so nobody gets carried.
const DUNGEON_LEVEL_TOP_WEIGHT := 0.5
## 5 Player difficulty, tuned for a level 50 party in full Epic gear (/testkit:
## ~7,500 party DPS): a big trash pack ~30 s (a full rotation with cooldowns),
## bosses 2-3 min. Singleplayer = x1.
const PARTY_HEALTH_MULT := 48.0        # placed trash health x this (normals and elites)
const PARTY_ADD_HEALTH_MULT := 16.0    # adds that join a fight (boss summons, alarm reinforcements, defend waves) x this
const PARTY_BOSS_HEALTH_MULT := 80.0   # boss health x this (instead of the above)
const PARTY_DAMAGE_MULT := 3.0         # enemy damage x this (normals and elites)
const PARTY_BOSS_DAMAGE_MULT := 4.0    # boss damage x this: a tank and a healer are needed
const PARTY_OFF_TARGET_CHANCE := 0.3   # ranged enemies: share of shots at a random other player
## Berserk (boss ability "berserk", 5 Player only): after its "after" seconds the
## boss hits this much harder and attacks this much faster; warned this long before.
const BERSERK_DAMAGE := 3.0
const BERSERK_ATTACK_SPEED := 50.0     # % faster attacks
const BERSERK_WARNING := 10.0
## Roguelike death (level reset, gear loss). OFF for now: dying costs nothing -
## you revive (at the dungeon entrance / last boss room) or go to the main menu.
const ROGUELIKE_DEATH := false

# --- Defender role (scripts/dungeon/defender_shield.gd) ----------------------------
## In combat a Defender channels "Shield Up" without end (its cast bar loops this
## long) while its shield blocks from the front. An interrupt or a stun knocks
## the shield down for DEFENDER_SHIELD_DOWN s (counted from the stun's end).
const DEFENDER_CHANNEL := 4.0
const DEFENDER_SHIELD_DOWN := 5.0

# --- Dungeon set pieces (scripts/dungeon/set_pieces.gd) ----------------------------
## Alarm bell: when a fight starts near it, its Bell Ringer casts this long
## (interrupt it, stun it or kill it); finished = a reinforcement pack arrives.
const ALARM_RING_TIME := 4.0
const ALARM_RADIUS := 16.0         # metres: a fight this close to the bell starts the ringing
const ALARM_REINFORCEMENTS := 4    # enemies that come when it rings
## Ballista: stand on its plate to load it, then it fires at the boss of its room.
const BALLISTA_LOAD_TIME := 2.0    # seconds on the plate
const BALLISTA_PLATE_RADIUS := 1.6
const BALLISTA_COOLDOWN := 30.0
const BALLISTA_STUN := 3.0         # the boss is pinned (stunned) this long
const BALLISTA_EXPOSED_PCT := 25.0 # ...then takes this % more damage...
const BALLISTA_EXPOSED_TIME := 8.0 # ...for this long
const BALLISTA_DAMAGE_PCT := 3.0   # the bolt itself: % of the boss's max health

# --- Co-op: downed & revive ------------------------------------------------------
## In a party, reaching 0 health knocks you DOWN instead of killing you (while
## someone else is still standing). Only a healer's revive brings you back; otherwise you bleed out.
const DOWNED_BLEED_OUT := 30.0     # seconds until a downed player dies
const DOWNED_REPEAT_PENALTY := 10.0 # each extra time you go down on the same floor: this much less (min below)
const DOWNED_MIN_BLEED_OUT := 10.0
const DOWNED_RING_RADIUS := 6.0    # metres: the pulsing circle under a downed ally (easy to find)
const REVIVE_HEALTH_PCT := 30.0    # revived with this % of max health
## Combat rez charges: the party gets one every this many seconds of a run (none at
## the start; unused ones stack). A revive in combat (Last Verse, Not Finished With
## You) spends one. Out-of-combat rezzes and the Training Room are free.
const COMBAT_REZ_INTERVAL := 300.0
const RAISE_HEALTH_PCT := 50.0     # healers' out-of-combat rez (Hymn of Waking, Relight, Back on Your Feet, Return to Bloom, Spring Thaw): health back
const RAISE_MANA_PCT := 50.0       # ... and mana back

# --- Co-op: pings ------------------------------------------------------------------
const PING_TIME := 6.0             # seconds a ping stays up
const PING_COOLDOWN := 0.5         # seconds between your pings
const PING_MAX_PER_PLAYER := 3     # older pings disappear beyond this

# --- Enemies: melee tells ----------------------------------------------------------------
# Every melee hit shows a short, bright tell before it lands (same hit rate; not a cast:
# interrupts don't stop it, stuns and knockdowns do). The Brawler's Catch works on it.
const MELEE_TELL_TIME := 0.6       # seconds from the tell to the hit (Hasted elites and Frenzy shorten it)

# --- Elite traits (every elite gets one at random) ------------------------------------
const ELITE_SHIELD_PCT := 20.0          # Shielded: shield = % of max health...
const ELITE_SHIELD_EVERY := 12.0        # ...regained this many seconds after it breaks / at the start
const ELITE_HASTE_MOVE := 30.0          # Hasted: % more move speed
const ELITE_HASTE_ATTACK := 30.0        # Hasted: % faster attacks
const ELITE_VAMPIRIC_PCT := 50.0        # Vampiric: heals for % of its attack damage
const ELITE_VOLATILE_RADIUS := 3.5      # Volatile: explodes on death after a warning circle
const ELITE_VOLATILE_DELAY := 1.8
const ELITE_VOLATILE_COEF := 1.5        # x its contact damage
const ELITE_BERSERK_AT := 35.0          # Berserker: below this % health...
const ELITE_BERSERK_DAMAGE := 50.0      # ...% more damage
const ELITE_BERSERK_ATTACK := 40.0      # ...% faster attacks

## Nature caster: the Weaver (player.gd, "Nature caster: the Weaver"). Woven
## creatures (Briar Tiger, Thornwing) leave a patch of mulch where they strike;
## rooted finishers (Mossback, Choking Vipers) use up every patch near their
## target and grow with each; Greenwood Stag carries the patches to the target.
const MULCH_MAX := 5                      # patches you can have (a new one replaces the oldest)
const MULCH_TIME := 20.0                  # seconds a patch lasts
const MULCH_REACH := 8.0                  # finishers, the stag and Thornburst use patches within this many metres of the target
const MULCH_RING := 0.9                   # metres between patches the stag sets down around the target
const THORNSHOT_PATCH_EVERY := 3          # every this-many-th Thornshot that lands leaves a patch
const THORNBURST_DAMAGE := 0.4            # Thornburst: damage (coefficient) to each enemy near a patch of yours ...
const THORNBURST_RADIUS := 4.0            # ... within this many metres of one (each enemy once per Thornshot)
const MOSSBACK_PER_PATCH := 0.5           # Mossback: damage (coefficient) added for each patch it uses (its own damage is the base)
const VIPERS_PER_PATCH := 0.4             # Choking Vipers: damage over time added for each patch it uses (its own damage is the base)
const VIPERS_TIME := 3.0                  # ... over this many seconds
const VIPERS_TICK := 1.0                  # ... a tick this often (faster with Haste)
const VIPERS_HOLD := 0.5                  # ... and each enemy is held in place this long (never an interrupt)
const WOVEN_STRIKE_DELAY := 0.45          # seconds from the cast to a woven creature's strike (vines, braid, lunge)
const ROOTED_STRIKE_DELAY := 0.35         # seconds from the press to a rooted creature's strike
const HUNTING_PARTY_EXTRA := 2            # Hunting Party (talent) capstone: every second Briar Tiger strikes this many more enemies ...
const HUNTING_PARTY_RADIUS := 8.0         # ... within this many metres of the target
const COMPOST_PATCH_EVERY := 2            # Compost (talent): every this-many-th Thornshot that lands leaves a patch instead
const CIRCLING_HAWK_PATCHES := 4          # Circling Hawk (talent): a finisher that uses this many patches or more cuts Thornwing's cooldown
const BRAMBLE_BURST_RADIUS := 5.0         # Bramble Burst (talent) capstone: Thornburst reaches this many metres from a patch
# Nature healer: the Shepherd (player.gd, "Nature healer: the Shepherd"). Heals: HEALS.
const BLOSSOM_MAX := 3                    # Blossoms one ally can hold
const BLOSSOM_TIME := 20.0                # seconds they last (a new one starts the time of all of them over)
const DEWFALL_PER_BLOSSOM := 10.0         # Dewfall heals this % more for each Blossom on its target
const FAWN_BOUNCES := 3                   # Fawn: allies it bounces on to after the first
const FAWN_REACH := 12.0                  # ... each within this many metres of the last
const FAWN_FALLOFF := 0.8                 # ... each bounce heals this times the one before
const ROOTGUARD_PER_BLOSSOM := 0.88       # Rootguard: shield (old Heal x REFERENCE_HEAL) added per Blossom used
const ROOTGUARD_TIME := 8.0               # seconds its shield lasts
const ROOTGUARD_SPREAD := 8.0             # used up: a Blossom on every ally within this many metres
const OWL_TIME := 15.0                    # Owl: seconds it watches an ally
const OWL_REACH := 10.0                   # its strike: the nearest enemy within this many metres of the ally
const ELK_PER_BLOSSOM := 0.66             # Heartwood Elk: heal added per Blossom used (each ally)
const FULL_BLOOM_PCT := 10.0              # Full Bloom: % less damage taken
const FULL_BLOOM_TIME := 6.0              # ... for this many seconds
const WILD_HERD_FAWNS := 5                # Wild Herd: Fawns sent (one each at the lowest-health allies)
const RUNNING_HERD_EXTRA := 2             # Running Herd capstone: every second Fawn bounces this many more times
const EVERGREEN_TICK := 1.0               # Evergreen (talent): seconds between its heals (each Blossom of mine heals its ally)
# Nature tank: the Colossus (player.gd, "Nature tank: the Colossus")
const SAP_MAX := 5                        # Sap stacks you can hold
const SAP_TIME := 20.0                    # seconds they last (a gain starts the time over)
const SAP_HEAL_PCT := 0.4                 # each Sap heals you this % of your maximum health every second
const VINE_FIST_EXTRA := 2                # Vine Fist: also hits this many more enemies ...
const VINE_FIST_REACH := 4.0              # ... within this many metres of the target ...
const VINE_FIST_SPLASH := 0.3             # ... for this damage (coefficient) each
const GRASP_HOLD := 1.0                   # Grasp: seconds the enemy is held in place at your feet
const GRASP_GAP := 0.6                    # ... metres between you and where it is dropped
const GRASP_TAUNT := 3.0                  # ... seconds it must attack you
const STOMP_TAUNT := 3.0                  # Stomp: seconds every enemy hit must attack you
const STOMP_HELD_MULT := 2.0              # ... damage times this to an enemy held by Grasp
const STOMP_SAP_HITS := 3                 # ... hitting this many enemies or more gives 2 Sap instead of 1
const VINE_FIST_SAP := 1                 # Sap each Vine Fist gives
const STOMP_SAP := 1                      # Sap a Stomp gives ...
const STOMP_SAP_MANY := 2                 # ... or this many when it hits STOMP_SAP_HITS enemies or more
const HANDS_SAP := 1                      # Sap each hit Giant's Hands absorbs gives
const STOMP_ROOTS_DAMAGE := 0.6           # Stomp Roots: damage over time (coefficient) to each enemy inside ...
const STOMP_ROOTS_TIME := 6.0             # ... over this many seconds ...
const STOMP_ROOTS_TICK := 1.0             # ... a tick this often (faster with Haste)
const GIANTS_HANDS_PCT := 30.0            # Giant's Hands: shield of this % of your maximum health ...
const GIANTS_HANDS_TIME := 8.0            # ... for this many seconds
const GIANTS_HANDS_BURST := 0.8           # ... when it breaks or runs out: damage (coefficient) to enemies within ...
const GIANTS_HANDS_RADIUS := 6.0          # ... this many metres
const HEARTSAP_BASE_PCT := 5.0            # Heartsap: heals this % of your maximum health ...
const HEARTSAP_PER_SAP := 3.0             # ... plus this % for each Sap it uses
const AWAKEN_TIME := 12.0                 # Awaken: seconds the full giant stands
const AWAKEN_DR_PCT := 15.0               # ... % less damage taken
const AWAKEN_SLAM := 0.4                  # ... each Vine Fist also slams the ground: damage (coefficient) to enemies within ...
const AWAKEN_SLAM_RADIUS := 6.0           # ... this many metres
const AWAKEN_STOMP_RADIUS := 12.0         # ... Stomp reaches this far
const AWAKEN_HANDS_PCT := 50.0            # ... Giant's Hands absorbs this % more
const AWAKEN_SAP_MULT := 2                # ... Sap gains times this
const THICK_SAP_KEEP := 2                 # Thick Sap (talent) capstone: Sap Heartsap leaves you
const CRUSHING_GRIP_HITS := 5             # Crushing Grip (talent): hits Giant's Hands soaked that count toward its burst bonus
# Nature archer: Venomstring (player.gd, "Nature archer: Venomstring")
const VENOM_MAX := 100.0                  # the Venom bar
const VENOM_PER_TICK := 2.5               # Venom each tick of my poisons gives during Venom Flow (all three up somewhere)
const VENOM_DRAIN := 5.0                  # Venom lost per second out of combat
const POISON_TIME := 12.0                 # seconds each poison lasts
const POISON_TICK := 1.0                  # ... a tick this often (faster with Haste)
const ADDER_DAMAGE := 1.46                # Adder Venom: damage (coefficient) over its time
const ASP_DAMAGE := 0.73                   # Asp Venom: damage over its time ...
const ASP_SLOW := 20.0                    # ... and the enemy moves this % slower
const KRAIT_DAMAGE := 0.5                  # Krait Venom: damage over its time ...
const KRAIT_HASTE := 25.0                 # ... and my other poisons on that enemy tick this % faster
const TWO_POISONS_PCT := 15.0             # two different poisons of mine on an enemy: all of them deal this % more
const STEEPED_PCT := 30.0                 # all three (Steeped): this % more instead
const FANG_EXTEND := 2.0                  # Fang Arrow: seconds added to every poison of mine on the target
const VENOM_BURST_COST := 50.0            # Venom Burst: Venom it costs
const BURST_PER_POISON := 5.0             # ... % more for each different poison on the target
const BURST_RADIUS := 6.0                 # ... enemies within this many metres ...
const BURST_SPLASH_PCT := 50.0            # ... take this % of it (split past the AoE cap)
const BURST_STEEPED_REFUND := 20.0        # ... Venom back on a Steeped target
const VOLLEY_VENOM_COST := 30.0           # Spitting Volley: Venom it costs ...
const SPIT_RADIUS := 8.0                  # ... Adder Venom on every enemy within this many metres of the target
const BLOAT_COST := 40.0                  # Bloat Arrow: Venom it costs ...
const BLOAT_DELAY := 3.0                  # ... seconds until the target bursts ...
const BLOAT_RADIUS := 8.0                 # ... copying my poisons to every enemy within this many metres
const POISON_SPREAD := 10.0               # a poisoned enemy dies: each poison jumps to the nearest enemy within this many metres
const COIL_BACK_DISTANCE := 10.0          # Coil Back: metres it carries you backward ...
const COIL_TRAP_TIME := 8.0               # ... seconds the thorn trap waits ...
const COIL_TRAP_RADIUS := 2.0             # ... how close an enemy must come ...
const COIL_HOLD := 1.0                    # ... and how long it is held in place
const SURGE_TIME := 15.0                  # Venom Surge: seconds it lasts ...
const SURGE_MULT := 2.0                   # ... poisons go on this many times as strong
const LINGERING_VENOM_KEEP := 40.0        # Lingering Venom (talent) capstone: % chance each poison stays through Venom Burst
# Nature open talents (scripts/player/nature_talents_open.gd)
const CLINGING_VINES_TIME := 3.0          # Clinging Vines: seconds an enemy stays slowed after a root or hold of mine on it ends
const CLINGING_VINES_SLOW_STEP := 20.0    # ... it moves this % slower per rank of the talent (one stack of the slow per rank)
## The Nature ribbon tree's newer talents (per-rank numbers in talents.gd).
const WELL_ROTTED_AGE := 10.0             # Well Rotted: seconds a Mulch patch has to lie before it adds more to a finisher
const HARVEST_PATCHES := 3                # Harvest: Mulch patches a finisher has to use to give mana back
const HUNTED_HEALTH_PCT := 35.0           # Hunted: works on enemies below this % of their health
const QUICKENING_TIME := 6.0              # Quickening: seconds laying a patch keeps the next Nature cast faster
const OVERGROWN_PATCHES := 5              # Overgrown's capstone: patches a finisher has to use to leave one behind
const POLLEN_REACH := 12.0                # Pollen: m from the ally to the one that gets the Blossom
const CANOPY_TIME := 6.0                  # Canopy: seconds an ally takes less damage after I give them a Blossom
const FAWN_KEEP_PCT := FAWN_FALLOFF * 100.0   # (Close Herd's text: Fawn's falloff as a %)
const EVERGREEN_FADE_HEAL := 0.3          # Evergreen's capstone: heal (in heals) of each Blossom that runs out unused
const CALLED_OUT_ENEMIES := 3             # Called Out: enemies of one taunt that give Fury
const OLD_OAK_HEALTH_PCT := 35.0          # Old Oak: works while you are below this % of your health
const OLD_GROWTH_HIT_PCT := 15.0          # Old Growth's capstone: a hit of this % of your maximum health gives a Sap ...
const OLD_GROWTH_EVERY := 3.0             # ... at most once every this many seconds
const DRIPPING_TIPS_TIME := 1.0           # Dripping Tips: seconds an auto-shot adds to your poisons on the target
const FINAL_BITE_HEALTH_PCT := 35.0       # Final Bite: works on enemies below this % of their health
const SOAKED_THROUGH_VENOM := 1.0         # Soaked Through's capstone: Venom more per poison tick on a Steeped enemy
# Martial warrior: the Wheel (scripts/player/martial_wheel.gd)
const WHEEL_USES := 4                     # uses each held weapon takes before it breaks (off-GCD abilities and trinkets don't count)
const CRACKS_QUICK := 1                   # Cracks a Filler adds to the held weapon
const CRACKS_FULL := 2                    # Cracks a Heavy Filler adds
const BREAK_BASE := 0.2                   # Break: damage (coefficient) with no Cracks ...
const BREAK_PER_CRACK := 0.6              # ... plus this per Crack (no cap)
const AXE_CLEAVE_PCT := 25.0              # Greataxe rider: your ability hits also hit 1 other enemy for this % ...
const AXE_CLEAVE_REACH := 5.0             # ... within this many metres of the target
const HACK_CLEAVE_TARGETS := 2            # Hack / Chop: also hit this many more enemies ...
const HACK_CLEAVE_REACH := 5.0            # ... within this many metres of the target ...
const HACK_CLEAVE_PCT := 50.0             # ... for this % of the hit
const SWORD_CRIT_PCT := 10.0              # Greatsword rider: % more crit chance
const SHARD_LANCE_MULT := 1.2             # Shard Lance: its Break damage times this (all into one target) ...
const SHARD_LANCE_PER_CRACK := BREAK_PER_CRACK * SHARD_LANCE_MULT   # ... so this per Crack
const HALBERD_AGAIN_PCT := 20.0           # Halberd rider: % chance an ability hit hits again (as much again)
const HALBERD_SWEEP_TARGETS := 3          # Jab / Hook: hit up to this many enemies in front of you ...
const HALBERD_SWEEP_REACH := 5.0          # ... this far ...
const HALBERD_SWEEP_ARC := 120.0          # ... in this wide an arc (degrees); split past the AoE cap
const FLYING_HEAD_BOUNCES := 3            # Flying Head: after the target, the head bounces to this many more enemies ...
const FLYING_HEAD_BOUNCE_PCT := 50.0      # ... for this % each ...
const FLYING_HEAD_REACH := 8.0            # ... each within this many metres of the last
const STAGGER_MAX := 100.0                # Maul rider: Stagger an enemy can hold; full = knocked down (never bosses)
const STAGGER_PER_HIT := 20.0             # ... Stagger each of your ability hits adds
const STAGGER_MAUL_EXTRA := 20.0          # ... Thud, Crush and Fault Line add this much more
const STAGGER_FADE := 8.0                 # ... an enemy you haven't hit for this many seconds loses its Stagger
const STAGGER_KNOCKDOWN := 1.0            # ... seconds a full Stagger knocks it down
const SHRAPNEL_RADIUS := 8.0              # Shrapnel: hits every enemy within this many metres (split past the AoE cap)
const FAULT_LINE_REACH := 8.0             # Fault Line: a cone this long ...
const FAULT_LINE_ARC := 90.0              # ... and this wide (degrees); split past the AoE cap
const RUSH_DISTANCE := 12.0               # Rush: metres you dash forward, through enemies
const BLADE_GUARD_PCT := 40.0             # Blade Guard: % less damage taken ...
const BLADE_GUARD_TIME := 4.0             # ... for this many seconds
const DRAG_IN_GAP := 0.6                  # Drag In: metres between you and where the enemy lands
const DRAG_IN_TIME := 0.25                # ... seconds the drag takes
const EARTHSHAKE_TIME := 1.5              # Earthshake: seconds enemies are knocked down (never bosses)

# Martial tank: the Brawler (scripts/player/martial_brawler.gd). Strikes go into a chain of
# CHAIN_LENGTH; the last one picks the move, all different makes the strong one.
const BRUISE_PCT := 40.0                  # Bruise: % of every hit you take that is not dealt now ...
const BRUISE_TIME := 6.0                  # ... but over this many seconds (new damage starts it over with the total left)
const BRUISE_TICK := 0.5                  # ... in a tick every this many seconds
const BRUISE_FURY := 1.0                  # ... each tick gives this much Fury per 1% of your max health it deals
const STRIKE_GCD := 1.0                   # Punch / Kick / Elbow / Catch: their global cooldown (Haste shortens it like the GCD)
const CHAIN_LENGTH := 3                   # inputs in a chain
const CHAIN_TIMEOUT := 5.0                # seconds without a strike that clear the chain
const HAYMAKER_FURY := 30.0               # Haymaker: Fury it spends (without it: Rapid Fists)
const KICKED_DOWN_TIME := 1.0             # Roundhouse / Throw: seconds enemies are knocked down (never bosses)
const CLINCH_PCT := 30.0                  # Clinch: % less damage you take from the clinched enemy ...
const CLINCH_TIME := 4.0                  # ... for this long
const SHAKE_OFF_PCT := 30.0               # Shake Off: % of your Bruise it clears
const TURN_IT_AROUND_PCT := 100.0         # Turn It Around: % of the caught hit it deals back
const THROW_DISTANCE := 6.0               # Throw: metres the caught enemy is thrown (away from you) ...
const THROW_SPLASH := 3.0                 # ... it and enemies within this many metres of where it lands are knocked down
const THROW_TIME := 0.3                   # ... seconds the throw takes
const REVERSAL_COEF := 1.0                # Throw on a boss (Reversal): damage (coefficient) instead
const TAKEDOWN_TIME := 3.0                # Takedown: seconds the caught enemy is on the floor (bosses: Bruise cleared instead)
const CATCH_GRACE := 0.3                  # Catch: seconds after the tell ends that the hit still counts as caught (latency)
const TOUGH_IT_OUT_TIME := 5.0            # Tough It Out: seconds your Bruise ticks deal nothing ...
const TOUGH_IT_OUT_FURY := 2.0            # ... and give this many times the Fury
const COME_ON_TAUNT := 3.0                # Come On: seconds the target must attack you
const PUT_EM_UP_PCT := 60.0               # Put 'Em Up (the stance Bruise needs): % less non-Physical damage you deal

# Martial DPS: the Rogue (scripts/player/martial_rogue.gd). Rogue hits build Flow; a range
# switch builds more; Go In spends it on a Kill window where the builders take their Kill forms.
const FLOW_MAX := 10                      # Flow: most stacks ...
const FLOW_PCT := 1.0                     # ... % more damage per stack
const FLOW_SWITCH := 1                    # ... extra Flow for a hit from a different range than your last
const FLOW_HOLD := 3.0                    # ... seconds without a Rogue hit before it starts to drop ...
const FLOW_DECAY_EVERY := 1.0             # ... then one stack every this many seconds
const TWIN_STAB_FLOW := 2                 # Twin Stab: Flow it gives (the others give 1)
const WHIRL_FLOW_MAX := 3                 # Whirl / Knife Spread: 1 Flow per enemy hit, up to this many
const KILL_MIN_FLOW := 5                  # Go In: Flow needed
const KILL_PER_FLOW := 1.0                # ... seconds of Kill window per Flow spent
const KILL_CRIT_ENERGY := 10.0            # ... Energy back for each crit of yours in it
const KILL_VARIETY := 0.5                 # ... seconds a Kill form adds when it differs from the one before it ...
const KILL_VARIETY_MAX := 5.0             # ... up to this many in all
const HIT_YOUR_STRIDE_MULT := 1.5         # Hit Your Stride: its Kill window (at FLOW_MAX) is this many times as long
const CLOSE_IT_OUT_PER_SEC := 0.4         # Close It Out: damage (coefficient) per second the window had left
const ROLL_WITH_IT_FLOW := 3              # Roll With It: Flow it spends ...
const ROLL_WITH_IT_PCT := 40.0            # ... % less damage taken ...
const ROLL_WITH_IT_TIME := 3.0            # ... for this long
const DAGGER_MAX := 3                     # Stuck daggers: most of yours in one enemy ...
const DAGGER_TIME := 20.0                 # ... seconds they stay (a new one starts it over)
const DAGGER_RIP := 0.25                  # ... damage (coefficient) each one does when ripped out ("Ripped Out")
const THROW_RANGE := 25.0                 # Cut / Gut / Knife Spread: how far you throw
const CUT_THROWN := 0.45                  # Cut thrown: damage (coefficient)
const GUT_THROWN := 0.8                   # Gut thrown: damage (coefficient)
const KICK_OFF_DISTANCE := 8.0            # Kick Off / Back Flip: metres you flip back
const KICK_OFF_WINDOW := 4.0              # Kick Off: seconds your next throw throws two daggers
const KNIFE_SPREAD_TARGETS := 3           # Knife Spread: enemies in front it throws at ...
const KNIFE_SPREAD_ARC := 90.0            # ... in this wide a cone (degrees)
const KNIFE_SPREAD_COEF := 0.3            # ... damage (coefficient) per dagger
const RED_SPREAD_COEF := 0.5              # ... in a Kill window (Red Whirl thrown)
const BACK_FLIP_DAGGERS := 3              # Back Flip: daggers thrown into the target ...
const BACK_FLIP_DAGGER_COEF := 0.3        # ... damage (coefficient) each
const FLASH_POWDER_REACH := 8.0           # Snatch - Flash Powder: enemies this close in front ...
const FLASH_POWDER_ARC := 90.0            # ... in this wide a cone (degrees) are Blinded (not bosses)
const FLASH_POWDER_TIME := 2.0            # ... for this long
const WHETSTONE_HITS := 3                 # Snatch - Whetstone: your next this many hits ...
const WHETSTONE_PCT := 50.0               # ... deal this % more
const SMOKE_FLASK_DODGE := 20.0           # Snatch - Smoke Flask: threat dropped, % dodge ...
const SMOKE_FLASK_TIME := 4.0             # ... for this long
const OIL_JAR_RADIUS := 4.0               # Snatch - Oil Jar: a burning pool this wide (radius) ...
const OIL_JAR_TIME := 6.0                 # ... for this long ...
const OIL_JAR_TICK := 1.0                 # ... burning every this many seconds ...
const OIL_JAR_COEF := 0.15                # ... for this damage (coefficient, Fire; split past the AoE cap)
const PIN_SHADOW_HITS := 3                # Pin the Shadow (Martial's root): hits (by anyone, not over time) that free it ...
const PIN_SHADOW_TIME := 8.0              # ... or this many seconds
const OVER_SHOULDER_TIME := 5.0           # Over the Shoulder: seconds your next hit is sure to crit
const OVER_SHOULDER_GAP := 1.2            # ... metres behind the target you land
const PLAY_DEAD_TIME := 3.0               # Play Dead: seconds enemies forget you

# Martial archer: Sharpshooter (scripts/player/martial_sharpshooter.gd). No resource: every
# shot is on a cooldown and each hit cuts another shot's (Abilities.SHARP_LINKS). A cut on
# a shot that is already ready becomes Overcut on it (more damage when it's fired).
const SHARP_QUICK_CUT := 3.0              # Quick Shot: seconds it takes off Pierce
const SHARP_PIERCE_CUT_FIRST := 2.0       # Pierce: seconds off Spread for the first enemy hit ...
const SHARP_PIERCE_CUT_PER := 1.5         # ... and for each enemy after it ...
const SHARP_PIERCE_CUT_MAX := 6.0         # ... up to this many in all
const SHARP_PIERCE_WIDTH := 1.5           # ... how wide its line is (metres; enemies on it are hit)
const SHARP_SPREAD_ARROWS := 3            # Spread: arrows, across up to this many enemies in front ...
const SHARP_SPREAD_ARC := 90.0            # ... in this wide a cone (degrees); a lone enemy takes them all
const SHARP_SPREAD_CUT := 1.5             # ... seconds each arrow takes off Heavy Draw
const SHARP_HEAVY_CUT := 2.0              # Heavy Draw: seconds off every other shot (Quick Shot is reset)
const SHARP_FOLLOW_HITS := 2              # Follow Up: arrows ...
const SHARP_FOLLOW_CUT := 2.0             # ... seconds each takes off the shot you used just before it
const SHARP_FOLLOW_GAP := 0.15            # ... seconds between its two arrows
const OVERCUT_PCT := 8.0                  # Overcut: % more damage per second of it ...
const OVERCUT_MAX := 12.5                 # ... up to this many seconds (+100%)
const STREAK_MAX := 10                    # Streak: most stacks ...
const STREAK_PCT := 2.0                   # ... % more damage per stack
const STREAK_HOLD := 4.0                  # ... lost after this many seconds without a Sharpshooter shot
const BREATHE_TIME := 10.0                # Breathe: seconds your next cut is a full reset
const FAST_HANDS_TIME := 10.0             # Fast Hands: seconds ...
const FAST_HANDS_MULT := 2.0              # ... every cut is this many times as long

# Martial talents (talents.gd holds each rank's number; these are the fixed parts).
const HARD_BREAK_CRACKS := 6              # Hard Break's capstone: a finisher with this many Cracks or more ...
const HARD_BREAK_FURY := 20.0             # ... gives this much Fury
const TURNING_WHEEL_TIME := 15.0          # Turning Wheel: seconds each broken weapon's stack lasts
const CLEAN_KILL_FLOW := 3                # Clean Kill's capstone: Flow Close It Out leaves you
const SOAK_IT_UP_SHAKE_OFF := 40.0        # Soak It Up's capstone: % of your Bruise Shake Off clears
const FULL_DRAW_CUT := 3.0                # Full Draw's capstone: seconds Heavy Draw takes off the other shots
const CLEAN_SWAP_TIME := 3.0              # Clean Swap: seconds after a weapon breaks that your abilities hit harder
const EASY_PICKINGS_DAGGERS := 3          # Easy Pickings: your stuck daggers an enemy needs
const CROWD_WORK_MAX := 3                 # Crowd Work: most enemies that give Fury per Sweep / Roundhouse
const HARDENED_BRUISE_PCT := 20.0         # Hardened: % of your max health your Bruise must hold
const LONG_RANGE_FROM := 10.0             # Long Range: metres past which your shots hit harder ...
const LONG_RANGE_STEP := 5.0              # ... by its % for every this many metres more
const WAITING_GAME_TIME := 3.0            # Waiting Game: a shot gains Overcut for every this many seconds it stays ready
const CLEAN_RELEASE_OVERCUT := 6.0        # Clean Release: seconds of Overcut a shot must spend
const HOLD_STEADY_OVERCUT := 6.0          # Hold Steady: seconds of Overcut one shot must hold
const SECOND_ARROW_PCT := 30.0            # Second Arrow: % of the shot's damage the second arrow deals
const HARD_TARGET_HEALTH := 80.0          # Hard Target: % health an enemy must be above
const RUN_IT_BACK_CUT := 2.0              # Run It Back: seconds it takes off the next shot in the chain
const GRIT_HEALTH_PCT := 50.0             # Grit: below this % health you hit harder
const CATCH_BREATH_HEALTH_PCT := 35.0     # Catch Your Breath: dropping below this % health ...
const CATCH_BREATH_TIME := 6.0            # ... heals over this many seconds ...
const CATCH_BREATH_TICK := 1.0            # ... a tick every this many seconds ...
const CATCH_BREATH_COOLDOWN := 60.0       # ... at most once every this many seconds

# --- Utility (each book's "Utility" divider; scripts/player/utility.gd) ---------------------
# Roots: every book has its own kind (CLAUDE.md). The other tools: useful to anyone
# in the book, each with a rider only one of that book's specs cashes in.
const ROOTSNARE_TIME := 3.0               # Rootsnare (Nature): seconds the target and enemies near it are rooted
const DEEP_ROOTS_TIME := 8.0              # Deep Roots (Nature): seconds it lasts (moving ends it)
const DEEP_ROOTS_PCT := 15.0              # ... % less damage taken
const DEEP_ROOTS_SAP := 1                 # ... Sap gained each second
const SPORE_SLEEP_TIME := 20.0            # Spore Sleep (Nature): seconds a non-boss, non-elite enemy sleeps (any damage wakes it)
const LEAF_CLOAK_TIME := 4.0              # Leaf Cloak (Nature): seconds after it during which your damage makes no threat
const BELLOWS_PUSH := 8.0                 # Bellows (Fire): metres enemies are thrown away from you (bosses: not at all)
const BELLOWS_DRAG_TIME := 0.3            # ... over this many seconds
const BELLOWS_HEAT_MAX := 3               # ... 1 Heat per enemy thrown, up to this many
const STORM_FRONT_PCT := 30.0             # Storm Front (Lightning): % faster movement for you and allies near you
const STORM_FRONT_TIME := 6.0             # ... for this long
const STORM_FRONT_ENERGY := 5.0           # ... Energy you gain for each ally it reaches
const CLIMB_STRING_STOP := 1.5            # Climb the String (Shadow): metres short of the target it sets you down
const CIRCLE_OF_SILENCE_TIME := 4.0       # Circle of Silence (Holy): seconds the circle stays (lockout: INTERRUPT_LOCKOUT)
const HOLY_GROUND_TIME := 6.0            # Holy Ground (Holy): seconds no enemy can step inside it (radius: ABILITIES)
const HOLY_GROUND_CHECK := 0.15          # ... how often it pushes out enemies that got in (seconds)
const HOLY_GROUND_PUSH_TIME := 0.12      # ... how long each push takes
const COOLING_SLAG_SLOW := 30.0          # Cooling Slag (Fire): % slower while standing in the molten pool
const COOLING_SLAG_HARDEN := 2.0          # ... seconds until it hardens
const COOLING_SLAG_ROOT := 3.0            # ... then enemies still inside are rooted this long
const STATIC_SNARE_TIME := 2.0            # Static Snare (Lightning): seconds each enemy is rooted
const STATIC_SNARE_LEAP := 8.0            # ... when it ends, it leaps once to the nearest other enemy within this many metres
const FIXED_POINT_TIME := 3.0             # Fixed Point (Arcane): base seconds rooted
const FIXED_POINT_PER_COOLDOWN := 0.5     # ... + this per other Arcane spell of yours on cooldown
const FIXED_POINT_MAX := 6.0              # ... up to this many seconds in all
const BINDING_RING_TIME := 8.0            # Binding Ring (Holy): seconds the ring stays around the ally
const BINDING_RING_ROOTS := 3             # ... the first this many enemies to come close are rooted
const BINDING_RING_ROOT := 3.0            # ... for this long each

# --- Abilities -----------------------------------------------------------------

const ABILITIES := {
	# Frost
	"frostbolt": {"damage": 1.0, "cost": 1, "cast_time": 1.7, "range": 20.0},
	"blizzard": {"damage": 0.3, "cost": 4, "cast_time": 2.2, "radius": 2.5},
	"frostnova": {"damage": 0.8, "cooldown": 10.0, "cost": 3, "radius": 3.5},
	"icebarrier": {"cooldown": 20.0, "cost": 3},
	"froststrike": {"weapon_mult": 2.41, "cooldown": 6.0, "generates": 20},
	"frostarrow": {"weapon_mult": 1.76, "cooldown": 0.0, "cost": 10},   # the filler
	"rimeshell": {"damage": 1.0, "cost": 2, "cast_time": 2.2, "radius": 5.0, "range": 40.0},
	"shatteringwave": {"damage": 1.0, "cooldown": 8.0, "cost": 2, "radius": 20.0},
	"flashfreeze": {"cooldown": 12.0, "cost": 2, "cast_time": 1.2, "radius": 12.0},
	"hoarfrost": {"cost": 3, "range": 30.0},
	"shatteringslam": {"weapon_mult": 1.9, "cooldown": 6.0, "generates": 20, "threat": 5.0},   # + SHATTER_SLAM_PER_LAYER per Ice Layer
	"rimeslash": {"weapon_mult": 0.6, "cooldown": 0.0, "generates": 10, "radius": 4.0, "threat": 3.0},
	"iceshards": {"damage": 0.2, "range": 30.0},
	"coldspike": {"damage": 3.0, "cooldown": 3.0, "cost": 3, "cast_time": 3.0, "range": 30.0},
	"sleetwave": {"damage": 0.8, "cooldown": 10.0, "cost": 3, "radius": 12.0},      # radius = metres the wave travels
	"deepwinter": {"cooldown": 120.0},                    # lasts DEEPWINTER_TIME
	"rimelock": {"cooldown": 20.0, "cost": 2, "range": 25.0},                        # interrupt: see INTERRUPT_LOCKOUT
	"snowward": {"cooldown": 60.0, "radius": 20.0},       # radius = allies within this many metres
	"winterhide": {"cooldown": 40.0},                     # lasts WINTER_HIDE_TIME
	"rimeedge": {"damage": 0.15, "cooldown": 20.0},       # damage = the extra Frost hit on each melee hit
	"icebreaker": {"weapon_mult": 2.68, "cooldown": 8.0, "cost": 30},                  # ICEBREAKER_FROZEN_MULT on a target you have Frozen
	"icepin": {"weapon_mult": 1.0, "cooldown": 15.0, "cost": 30},
	"shattershot": {"weapon_mult": 3.78, "cooldown": 10.0, "cost": 30, "radius": 4.0},   # SHATTER_SHOT_FROZEN_PCT more on a target you have Frozen; radius = the burst
	"glacialdraw": {"weapon_mult": 2.97, "cooldown": 12.0, "cost": 40, "cast_time": 2.0},   # instant on a target your Icepin roots or you have Frozen
	"rimefletch": {"cooldown": 30.0, "cost": 20},                                       # RIMEFLETCH_SHOTS / _TIME / _PCT
	"coldmark": {"cooldown": 20.0, "cost": 0},                                          # lasts as long as its effect (EFFECTS)
	"icyretreat": {"cooldown": 15.0, "cost": 15, "radius": 4.0},                        # radius = the ice it leaves; ICY_RETREAT_DISTANCE / _TIME
	# Frost healer: Cold Comfort (RIME_SHARDS_*, RIME_VEIL_* and the rest below; heals in HEALS)
	"meltwater": {"cost": 1, "cast_time": 1.5, "range": 40.0},
	"rimeveil": {"cost": 2, "range": 40.0},                                              # RIME_VEIL_SHARE every RIME_VEIL_EVERY sec for RIME_VEIL_TIME
	"breaktheice": {"cooldown": 10.0, "cost": 1, "radius": 8.0, "range": 40.0},          # radius = who its heal reaches (+ Cold Spread)
	"frostlattice": {"cooldown": 30.0, "cost": 3, "range": 40.0},                        # LATTICE_LINKS allies for LATTICE_TIME
	"rimefall": {"cooldown": 15.0, "cost": 4, "cast_time": 2.5, "radius": 20.0},
	"frosttide": {"cooldown": 120.0},                                                    # lasts FROST_TIDE_TIME
	"stillwater": {"cooldown": 90.0, "cost": 2, "range": 40.0},
	# Frost tank: Glacier Wall (Fury; ICE_LAYER_* and the rest above)
	"coldshoulder": {"cooldown": 8.0, "range": 25.0, "threat": 3.0},
	"rimequake": {"damage": 0.65, "cooldown": 8.0, "cost": 25, "radius": 6.0, "threat": 4.0},   # + RIMEQUAKE_PCT_PER_LAYER per Ice Layer
	"hailcoat": {"cooldown": 25.0},
	"hardrime": {"cooldown": 20.0, "cost": 30},
	"glacialbulwark": {"cooldown": 90.0},
	# Frost DPS: Frostbitten Steel (Fury; GLAZE_* and the rest above)
	"hoarcleave": {"weapon_mult": 1.61, "cooldown": 6.0, "generates": 15},
	"bitteredge": {"weapon_mult": 1.07, "cooldown": 6.0, "cost": 15},
	"calving": {"weapon_mult": 1.34, "cooldown": 10.0, "cost": 30},
	"blackfrost": {"cooldown": 120.0},
	# Fire
	# Steady Flame's spells build Fury for free or spend it (FireFuryKit).
	"fireball": {"damage": 0.75, "cost": 0, "cast_time": 2.2, "range": 20.0},
	"searingstrike": {"weapon_mult": 1.92, "cooldown": 6.0, "cost": 30},
	"flamingarrow": {"weapon_mult": 2.34, "cooldown": 6.0, "cost": 30},
	"flamenova": {"damage": 1.5, "cooldown": 10.0, "cost": 30, "radius": 3.0},
	"ventflames": {"damage": 1.8, "cooldown": 10.0, "cost": 0, "range": 30.0},          # spends all your Fury: VENT_FURY_*
	"coolhead": {"cooldown": 120.0},
	"furnacebreath": {"damage": 1.0, "cooldown": 15.0, "cost": 3, "radius": 6.0},   # radius = the cone's reach
	"slagskin": {"damage": 0.3, "cooldown": 13.0, "cost": 0, "threat": 3.0},         # damage = per hit back at an attacker; lasts SLAG_SKIN_TIME, so it can be kept up
	"crucible": {"cost": 20, "cast_time": 1.5, "radius": 5.65, "range": 30.0},         # moving it is free and instant (radius was 5, Deep Crucible folded in)
	"cinderstep": {"damage": 0.15, "cooldown": 15.0, "cost": 2},                       # damage = per tick of the line
	"heatsink": {"damage": 1.0, "cooldown": 60.0, "cost": 0, "radius": 6.0},           # damage = the burst with nothing stored
	"brand": {"damage": 0.85, "weapon_mult": 0.85, "cooldown": 6.0, "generates": 20, "threat": 5.0},
	"cinderguard": {"damage": 0.3, "cooldown": 12.0, "cost": 20, "threat": 3.0},        # damage = the burn on an attacker you block
	"anvil": {"damage": 0.65, "weapon_mult": 0.5, "cooldown": 8.0, "generates": 10, "radius": 4.0, "threat": 6.0},
	"redhotrivet": {"damage": 0.3, "cooldown": 8.0, "range": 25.0, "threat": 3.0},
	"forgeblow": {"cooldown": 8.0, "cost": 30},            # shatters all your Slag: EXTRA_HITS["slagskin"] per stack
	"moltenshell": {"cooldown": 120.0},
	"stoke": {"damage": 1.0, "cooldown": 20.0, "cost": 20, "range": 30.0},             # damage = on top of the Burning it eats
	"immolate": {"damage": 0.0, "cost": 0, "cast_time": 1.5, "range": 30.0},          # its damage is the Blaze effect below
	"walloffire": {"damage": 0.25, "cooldown": 20.0, "cost": 30, "cast_time": 1.5, "radius": 4.0, "range": 30.0},   # damage = per tick, radius = half its length
	"kilnblast": {"damage": 3.0, "cooldown": 3.0, "cost": 40, "cast_time": 3.5, "range": 30.0},   # never crits
	"embervolley": {"damage": 0.35, "cooldown": 12.0, "cost": 0, "cast_time": 3.0, "range": 30.0},   # damage = per ember
	"quench": {"weapon_mult": 1.28},                    # before Heat: + QUENCH_PCT_PER_HEAT % per Heat removed
	"flare": {"weapon_mult": 1.28, "radius": 4.0},      # radius = the sweep's reach
	"foldsteel": {"weapon_mult": 0.64, "cooldown": 8.0, "cost": 25},   # per hit (FOLD_STEEL_HITS)
	"rededge": {"weapon_mult": 0.32, "cooldown": 15.0, "cost": 20},    # weapon_mult = its extra Fire damage per auto-swing (Orange and up)
	"blastfurnace": {"cooldown": 120.0},
	"pitcharrow": {"weapon_mult": 1.04, "cooldown": 12.0, "cost": 20},
	"cinderrain": {"weapon_mult": 0.33, "cooldown": 15.0, "cost": 40, "radius": 4.0, "range": 30.0},   # weapon_mult = per tick (8 ticks)
	"coalshot": {"weapon_mult": 1.69, "cost": 15},
	"touchoff": {"cooldown": 10.0, "cost": 30, "range": 30.0},   # Ignites your Pitch: PITCH_IGNITE_* + TOUCH_OFF_PCT
	"brushfire": {"cooldown": 120.0},
	"cinderwing": {"cooldown": 60.0},                   # the phoenix: see PHOENIX_* and HEALS
	# Lightning
	"lightningbolt": {"damage": 1.05, "cost": 15, "cast_time": 1.7, "range": 20.0},                      # cost = Energy
	"chainlightning": {"damage": 1.6, "cooldown": 6.0, "cost": 0, "generates": 60, "cast_time": 1.5, "radius": 4.0, "range": 30.0},   # Leaping Arc; a jump = EXTRA_HITS
	"discharge": {"cooldown": 6.0, "cast_time": 2.0, "range": 30.0},                                                      # damage = DISCHARGE_PER_STEP per ENERGY_STEP Energy spent
	"balllightning": {"damage": 0.12, "cooldown": 15.0, "cast_time": 2.0, "radius": 5.0, "range": 30.0},   # damage = per zap, radius = the orb's reach, range = how far away it may be aimed
	"groundout": {"cooldown": 6.0},                                                                      # shield = GROUND_OUT_PER_STEP per ENERGY_STEP Energy spent
	"groundingsurge": {"cooldown": 60.0},
	"arcflash": {"damage": 0.8, "cooldown": 8.0, "cost": 40, "radius": 6.0},
	"livewire": {"cost": 20, "cast_time": 1.5, "range": 25.0},                                             # its damage is the Live Wire effect below; range = LIVE_WIRE_RANGE
	"thunderhead": {"damage": 0.5, "cooldown": 20.0, "cost": 50, "cast_time": 2.0, "radius": 5.0},         # damage = per strike
	"forkedbolt": {"damage": 0.9, "cost": 25, "cast_time": 2.0, "radius": 8.0, "range": 30.0},             # radius = how far from the target the second enemy may be
	"jolt": {"cooldown": 20.0, "range": 25.0},                                                             # interrupt: see INTERRUPT_LOCKOUT
	"flicker": {"cooldown": 15.0, "cost": 30},
	"capacitor": {"cooldown": 30.0},
	"thunderstrike": {"weapon_mult": 1.0, "cooldown": 10.0, "cost": 30},                                   # cost = Energy
	# Lightning melee (Energy)
	"chargededge": {"weapon_mult": 3.59, "cooldown": 4.0, "generates": 30},
	"arccleave": {"weapon_mult": 1.06, "cooldown": 6.0, "cost": 35, "radius": 4.0},
	"overdrive": {"damage": 0.1, "cooldown": 45.0},                                                        # damage = the zap on each auto-attack
	"twincurrent": {"cooldown": 20.0, "cost": 20},
	"staticstep": {"cooldown": 12.0, "cost": 20, "range": 15.0},                                           # range = how far away the target may be
	"backcurrent": {"damage": 0.3, "cooldown": 30.0},                                                      # damage = the zap back at an attacker
	"cadence": {"weapon_mult": 0.8, "cost": 15, "radius": 4.0},                                            # weapon_mult = the first press (keep it the same as CADENCE_MULTS[0]); radius = the third strike's reach
	"splitsecond": {"cooldown": 60.0},
	"whiplash": {"weapon_mult": 0.93, "cooldown": 6.0, "generates": 15, "range": 20.0},
	"faradayguard": {"cooldown": 45.0},
	"reflexarc": {"weapon_mult": 1.5, "cooldown": 20.0, "cost": 20},                                       # weapon_mult = the strike back
	"polarstrike": {"weapon_mult": 1.0, "cooldown": 3.0, "cost": 20},                                      # taught by the Rune of Polarity
	"stormarrow": {"weapon_mult": 1.0, "cooldown": 7.0, "cost": 30, "radius": 2.0},
	# Lightning tank (Energy, a two-handed weapon). "stormshield" is Stormbreak and
	# "thunderaegis" is Humming Blade: they keep the ids they had as shield abilities.
	"stormshield": {"damage": 0.0, "weapon_mult": 0.88, "cooldown": 0.0, "cost": 0, "generates": 15, "radius": 4.0, "threat": 5.0},   # radius = how far the charge arcs
	"thunderaegis": {"damage": 0.0, "weapon_mult": 0.0, "cooldown": 12.0, "cost": 0, "radius": 0.0, "threat": 1.0},
	"returnstroke": {"weapon_mult": 0.88, "cost": 15, "threat": 5.0},
	"shockring": {"damage": 0.5, "cooldown": 8.0, "cost": 30, "radius": 6.0, "threat": 4.0},
	"crossguard": {"cooldown": 25.0, "cost": 40},
	"drawthestorm": {"cooldown": 90.0, "radius": 8.0},                                                     # radius = how far it pulls enemies onto you
	"reelin": {"cooldown": 12.0, "cost": 20, "range": 25.0},                                               # range = how far away the target may be
	"recharge": {"cooldown": 30.0},                                                                        # heal = RECHARGE_PCT_PER_STEP per ENERGY_STEP Energy spent
	# Arcane
	"blink": {"cooldown": 12.0, "cost": 2},
	"arcanemissiles": {"damage": 0.2, "cost": 1, "cast_time": 2.0, "range": 30.0},                        # Sigil Darts: damage = per dart (ARCANE_MISSILES_COUNT of them), cast_time = the channel
	"unravel": {"damage": 1.3, "cost": 1, "cast_time": 2.0, "range": 30.0},
	"glint": {"damage": 1.1, "cooldown": 6.0, "cost": 1, "range": 30.0},
	"countdown": {"damage": 1.0, "cooldown": 12.0, "cost": 2, "cast_time": 1.5, "range": 30.0},           # damage = the detonation before what you dealt meanwhile is added
	"convergence": {"damage": 2.0, "cooldown": 20.0, "cost": 3, "cast_time": 2.5, "range": 30.0},
	"rewind": {"cooldown": 45.0},
	"lapse": {"cooldown": 90.0},
	"mirrorsigil": {"cooldown": 30.0, "cost": 3, "cast_time": 1.5},
	"collapse": {"damage": 1.8, "cooldown": 10.0, "cost": 3, "cast_time": 2.0, "radius": 6.0, "range": 30.0},
	"scatter": {"cooldown": 8.0},
	"intervalward": {"cooldown": 20.0, "cost": 2},                                                       # shield = HEALS
	"arcanestrike": {"damage": 0.84, "weapon_mult": 0.84, "cooldown": 6.0, "generates": 20},
	"arcaneshot": {"damage": 1.0, "weapon_mult": 1.0, "cooldown": 4.0, "cost": 20},
	"arcaneexplosion": {"damage": 1.2, "cooldown": 5.0, "cost": 3, "radius": 2.5},
	"counterspell": {"cooldown": 24.0, "cost": 2, "range": 25.0},
	# Arcane tank (a melee weapon in each hand; no resource: cooldowns alone)
	"doubleup": {"damage": 0.0, "weapon_mult": 0.45, "cooldown": 0.0, "threat": 4.0},
	"ripple": {"damage": 0.5, "cooldown": 8.0, "radius": 6.0, "threat": 4.0},
	"fullset": {"cooldown": 30.0},
	"missedbeat": {"damage": 0.0, "weapon_mult": 1.0, "cooldown": 3.0, "threat": 4.0},
	"standin": {"cooldown": 25.0},
	"tradeplaces": {"cooldown": 30.0},                                                                  # heal = TRADE_PLACES_PCT of recent damage per Reflection
	"crowdofone": {"cooldown": 90.0},
	"decoy": {"damage": 0.5, "cooldown": 90.0, "radius": 8.0, "range": 20.0, "threat": 4.0},            # damage = its burst, radius = how far it draws enemies in, range = how far away it may be sent
	# Arcane melee (a melee weapon in each hand; no resource: cooldowns alone). weapon_mult counts both weapons.
	"swiftcut": {"damage": 0.0, "weapon_mult": 0.84, "cooldown": 0.0},
	"deepcut": {"damage": 0.0, "weapon_mult": 1.89, "cooldown": 6.0},
	"latecut": {"damage": 0.0, "weapon_mult": 0.84, "cooldown": 10.0},                                   # hits again for the same damage after LATE_CUT_DELAY
	"encore": {"cooldown": 0.0},                                                                        # damage = ENCORE_PCT of each Trace
	"widecut": {"damage": 0.0, "weapon_mult": 0.74, "cooldown": 8.0, "radius": 5.0},
	"doubletime": {"cooldown": 90.0},
	# Shadow
	"corruption": {"damage": 0.4, "cooldown": 8.0, "cost": 2, "range": 30.0},
	"shadowstrike": {"weapon_mult": 1.34, "cooldown": 6.0, "cost": 30},
	"shadowarrow": {"weapon_mult": 1.0, "cooldown": 8.0, "cost": 30},
	# Shadow caster: Decay (see DECAY_* above). Blight opens it, the rest feed or use it.
	"blight": {"damage": 0.5, "cost": 2, "cast_time": 1.5, "range": 30.0},
	"erode": {"damage": 1.0, "cost": 1, "cast_time": 2.0, "range": 30.0},                                 # the filler
	"calldue": {"cooldown": 15.0, "cost": 2, "range": 30.0},                                              # damage = the Decay on the target + CALL_DUE_BONUS_PCT %
	"gnaw": {"damage": 0.4, "cooldown": 10.0, "cost": 1, "range": 30.0},
	"spill": {"cooldown": 10.0, "cost": 2, "range": 30.0},
	"pall": {"damage": 0.5, "cooldown": 12.0, "cost": 3, "cast_time": 2.0, "radius": 6.0, "range": 30.0},       # Smother (it keeps the id of its first name)
	"hush": {"damage": 0.3, "cooldown": 20.0, "cost": 2, "range": 25.0},                                  # interrupt: see INTERRUPT_LOCKOUT
	"takeitback": {"cooldown": 45.0, "cost": 2, "range": 30.0},                                           # shield = TAKE_IT_BACK_PCT % of the Decay on the target
	"bottomless": {"cooldown": 90.0},
	# Shadow melee: the Hounds (see HOUND_* above). Sic and Open Up build Fury, the rest spend it.
	"sic": {"damage": 0.0, "weapon_mult": 1.56, "cooldown": 0.0, "generates": 15},
	"openup": {"damage": 0.0, "weapon_mult": 1.56, "cooldown": 6.0, "generates": 25},                       # its mark: LAID_OPEN_*
	"bothatonce": {"damage": 0.0, "weapon_mult": 1.34, "cooldown": 4.0, "cost": 40},                       # each Hound's lunge = HOUND_LUNGE
	"runthemdown": {"damage": 0.0, "weapon_mult": 0.67, "cooldown": 8.0, "cost": 30, "radius": 5.0},       # then RUN_DOWN_*
	"guarddogs": {"cooldown": 30.0, "cost": 20},                                                          # GUARD_DOGS_*
	"offthechain": {"cooldown": 90.0},                                                                    # OFF_THE_CHAIN_*
	"bringitdown": {"cooldown": 10.0},                                                                    # each Hound's Drag Down = HOUND_DRAG
	# Shadow healer: the Strings (see STRING_* above). Heals are in HEALS.
	"puppetstring": {"range": 40.0},                                                                      # its charges: STRING_MAX, STRING_RECHARGE
	"patchup": {"cost": 1, "cast_time": 2.0, "range": 40.0},
	"hoist": {"cost": 3, "cast_time": 2.0, "range": 40.0},
	"tug": {"cooldown": 6.0, "cost": 1, "range": 40.0},
	"catscradle": {"cooldown": 20.0, "cost": 4, "radius": 30.0},                                          # radius = allies within this many metres
	"pulltaut": {"cooldown": 15.0, "range": 40.0},
	"knot": {"cooldown": 30.0, "range": 40.0},
	"doublethread": {"cooldown": 30.0},
	"wrench": {"damage": 1.0, "cooldown": 8.0, "cost": 1, "range": 40.0},
	"cuppedhands": {"cooldown": 25.0, "cost": 2, "range": 40.0},
	# Holy healer: the Hymns (see VERSE_* and the rest above). Heals are in HEALS.
	"psalm": {"cost": 2, "cast_time": 2.0, "range": 40.0},
	"outpour": {"cost": 4, "cast_time": 3.0, "range": 40.0},
	"lift": {"cooldown": 8.0, "cost": 1, "range": 40.0},
	"refrain": {"cost": 1, "range": 40.0},
	"canticle": {"cooldown": 12.0, "cost": 3, "cast_time": 2.5, "radius": 30.0},                         # heals CANTICLE_TARGETS of them
	"exultation": {"cost": 4, "cast_time": 2.0, "radius": 20.0},                                          # every ally within radius
	"antiphon": {"cooldown": 15.0, "cost": 2, "range": 40.0},
	"shelter": {"cooldown": 12.0, "cost": 2, "range": 40.0},
	"steadyvoice": {"cooldown": 30.0, "cost": 2, "radius": 15.0},
	"highnote": {"damage": 1.0, "cost": 2, "cast_time": 1.5, "range": 30.0},
	"reprise": {},
	"swell": {"cooldown": 60.0},
	"rest": {"cooldown": 60.0},
	"lastverse": {"cooldown": 120.0, "range": 30.0},
	"singmercy": {}, "singchorus": {}, "singvigil": {},
	# Holy tank: the Censer (Mana in points; INCENSE_* and the rest above)
	"censerswing": {"damage": 0.45, "cost": 0.4, "threat": 3.0},
	"hallowedarc": {"damage": 0.5, "cooldown": 8.0, "cost": 1, "radius": 8.0, "threat": 4.0},
	"beckon": {"damage": 0.4, "cooldown": 10.0, "cost": 1, "range": 25.0, "threat": 6.0},
	"pourout": {"cooldown": 12.0, "cost": 2, "radius": 8.0, "threat": 4.0},                              # damage = POUR_OUT_PER_STACK per stack
	"absolve": {"cooldown": 10.0, "cost": 1.5},                                                           # heal = ABSOLVE_PER_STACK per stack
	"aureole": {"cooldown": 20.0},
	"gatherthelight": {"cooldown": 30.0},
	"raisethecenser": {"cooldown": 60.0, "cost": 1.3, "radius": 10.0, "range": 30.0},                        # radius = how far from it enemies are grabbed
	"unfallen": {"cooldown": 120.0},
	# Holy healer #2: the Prisms (PRISM_* above; heals in HEALS)
	"setprism": {"cooldown": 8.0, "cost": 0.5, "range": 30.0},
	"moveprism": {"cooldown": 5.0, "cost": 1, "range": 30.0},
	"mendingray": {"cost": 3, "cast_time": 3.0, "range": 40.0},
	"brightlance": {"cost": 3.5, "cast_time": 2.5, "range": 40.0},
	"gleam": {"cost": 1, "range": 40.0},
	"prismward": {"cooldown": 15.0, "cost": 2, "range": 40.0},
	"piercinglight": {"damage": 1.0, "cost": 1.5, "cast_time": 1.5, "range": 30.0},
	"realign": {"cooldown": 20.0, "range": 30.0},
	"shatterprism": {"range": 40.0},
	"shatterall": {"cooldown": 20.0},
	"infuse": {"cooldown": 45.0, "cost": 1, "range": 40.0},
	"kaleidoscope": {"cooldown": 120.0},
	# Holy archer: Lightstring (Energy, a bow; REFRACT_* and the rest above)
	"prismarrow": {"cooldown": 12.0, "cost": 15, "range": 30.0},                                         # cooldown = one charge's recharge
	"glimmershot": {"weapon_mult": 2.5, "cost": 20},
	"refractingshot": {"weapon_mult": 3.6, "cooldown": 8.0, "cost": 30, "cast_time": 2.0},
	"sunlitarrow": {"weapon_mult": 1.67, "cooldown": 12.0, "cost": 30},
	"prismbreaker": {"cooldown": 15.0, "cost": 25, "range": 40.0},
	"stepoflight": {"cooldown": 10.0, "range": 40.0},
	"spectrumvolley": {"cooldown": 120.0},
	"behinditsback": {"cooldown": 60.0},
	"slack": {"cooldown": 60.0},
	"notfinished": {"cooldown": 300.0, "range": 40.0},
	"stringup": {"cooldown": 30.0, "cost": 2, "range": 30.0},
	"tangle": {"cooldown": 25.0, "cost": 2, "radius": 5.0, "range": 30.0},
	"stillstanding": {"cooldown": 120.0, "range": 40.0},
	"cutthestrings": {"cooldown": 120.0},
	"restring": {"cooldown": 20.0, "range": 40.0},
	"yank": {"cooldown": 45.0, "range": 40.0},
	# Nature caster: the Weaver (MULCH_* and the rest above)
	"thornshot": {"damage": 0.85, "cost": 1, "cast_time": 1.5, "range": 30.0},
	"briartiger": {"damage": 1.5, "cooldown": 6.0, "cost": 2, "cast_time": 1.5, "range": 30.0},
	"thornwing": {"damage": 1.0, "cooldown": 10.0, "cost": 2, "range": 30.0},
	"mossback": {"damage": 0.5, "cost": 2, "radius": 8.0, "range": 30.0},               # + MOSSBACK_PER_PATCH per patch
	"chokingvipers": {"damage": 0.4, "cost": 3, "radius": 8.0, "range": 30.0},   # its damage over time; + VIPERS_PER_PATCH per patch
	"greenwoodstag": {"damage": 0.5, "cooldown": 15.0, "cost": 1, "range": 30.0},
	# Nature healer: the Shepherd (BLOSSOM_* and the rest above; heals in HEALS)
	"dewfall": {"cost": 1, "cast_time": 1.5, "range": 40.0},
	"fawn": {"cooldown": 8.0, "cost": 3, "cast_time": 1.5, "range": 40.0},
	"rootguard": {"cooldown": 15.0, "cost": 2, "range": 40.0},
	"owl": {"damage": 0.5, "cooldown": 12.0, "cost": 2, "range": 40.0},
	"heartwoodelk": {"cooldown": 15.0, "cost": 3, "radius": 10.0},
	"wildherd": {"cooldown": 90.0, "cost": 3, "radius": 40.0},
	# Nature tank: the Colossus (Fury; SAP_* and the rest above)
	"vinefist": {"damage": 1.0, "cooldown": 3.0, "generates": 20, "threat": 4.0},
	"grasp": {"cooldown": 10.0, "cost": 15, "range": 25.0, "threat": 6.0},
	"stomp": {"damage": 0.8, "cooldown": 8.0, "cost": 25, "radius": 8.0, "threat": 4.0},
	"giantshands": {"damage": 0.8, "cooldown": 20.0, "cost": 30, "radius": 6.0, "threat": 6.0},   # damage = the burst when the shield goes
	"heartsap": {"cooldown": 12.0, "cost": 20},
	"awaken": {"cooldown": 120.0},
	# Nature archer: Venomstring (no resource: Venom, VENOM_* and the rest above)
	"fangarrow": {"weapon_mult": 1.0},
	"adderarrow": {"cast_time": 1.5},
	"asparrow": {},
	"kraitarrow": {},
	"venomburst": {},
	"spittingvolley": {},
	"bloatarrow": {"cooldown": 15.0},
	"coilback": {"cooldown": 20.0},
	"venomsurge": {"cooldown": 120.0},
	# Martial warrior: the Wheel (Fury; WHEEL_* and the rest above). Fillers
	# give Fury, Heavy Fillers cost it, Weapon Arts are free, Finishers deal BREAK_BASE
	# + BREAK_PER_CRACK per Crack.
	"hack": {"damage": 0.74, "generates": 20},
	"chop": {"damage": 0.99, "cost": 30},
	"rush": {"cooldown": 15.0},
	"shrapnel": {"damage": BREAK_BASE, "radius": SHRAPNEL_RADIUS},
	"slash": {"damage": 0.87, "generates": 20},
	"lunge": {"damage": 1.18, "cost": 30},
	"bladeguard": {"cooldown": 45.0},
	"shardlance": {"damage": BREAK_BASE * SHARD_LANCE_MULT},
	"jab": {"damage": 0.74, "generates": 30},
	"hook": {"damage": 0.99, "cost": 20},
	"dragin": {"cooldown": 20.0, "range": 12.0},
	"flyinghead": {"damage": BREAK_BASE},
	"thud": {"damage": 0.74, "generates": 20},
	"crush": {"damage": 0.99, "cost": 30},
	"earthshake": {"cooldown": 30.0, "radius": 6.0},
	"faultline": {"damage": BREAK_BASE, "radius": FAULT_LINE_REACH},
	# Martial tank: the Brawler (BRUISE_*, the chain and the rest above). Strikes give Fury;
	# the chain's moves go off with the third strike and are paid for by it (Haymaker:
	# HAYMAKER_FURY).
	"punch": {"damage": 0.27, "generates": 10, "threat": 4.0},
	"brawlkick": {"damage": 0.27, "generates": 10, "threat": 4.0},
	"elbow": {"damage": 0.27, "generates": 10, "threat": 4.0},
	"rapidfists": {"damage": 0.45, "threat": 5.0},
	"haymaker": {"damage": 1.1, "threat": 4.0},
	"sweep": {"damage": 0.4, "radius": 5.0, "threat": 5.0},
	"roundhouse": {"damage": 0.5, "radius": 6.0, "threat": 5.0},
	"throw": {"damage": 0.6, "threat": 4.0},
	"turnitaround": {"threat": 4.0},
	"onemore": {"cooldown": 9.0, "cost": 25},
	"toughitout": {"cooldown": 30.0, "cost": 40},
	"comeon": {"cooldown": 8.0, "range": 25.0, "threat": 6.0},
	"putemup": {"cooldown": 1.0},
	# Martial DPS: the Rogue (FLOW_*, KILL_*, DAGGER_* and the rest above). Kill forms
	# (gut ... drivethrough) are what the builders become in a Kill window.
	"cut": {"damage": 0.62, "cost": 20, "range": THROW_RANGE},
	"whirl": {"damage": 0.39, "cost": 35, "radius": 5.0, "range": THROW_RANGE},
	"dartin": {"damage": 0.56, "cost": 15, "cooldown": 10.0, "range": 15.0},
	"kickoff": {"damage": 0.45, "cost": 15, "cooldown": 10.0},
	"twinstab": {"damage": 0.56, "cost": 30, "cooldown": 8.0},
	"goin": {},
	"closeitout": {"cost": 20},
	"hityourstride": {"cooldown": 120.0},
	"rollwithit": {"cooldown": 25.0},
	"snatch": {"cost": 15, "cooldown": 10.0},
	"gut": {"damage": 1.0, "cost": 20, "range": THROW_RANGE},
	"throughandthrough": {"damage": 0.9, "cost": 30},
	"redwhirl": {"damage": 0.6, "cost": 35, "radius": 5.0, "range": THROW_RANGE},
	"backflip": {"damage": 0.6, "cost": 15, "cooldown": 10.0},
	"drivethrough": {"damage": 0.8, "cost": 15, "cooldown": 10.0, "range": 15.0},
	# Martial Utility (cooldowns only: the book's specs spend different resources)
	"pintheshadow": {"cooldown": 20.0, "range": 30.0},
	"overtheshoulder": {"cooldown": 20.0, "range": 10.0},
	"playdead": {"cooldown": 90.0},
	"stonethrow": {"cooldown": 15.0, "range": 25.0},   # interrupt: see INTERRUPT_LOCKOUT
	# Martial archer: Sharpshooter (SHARP_*, OVERCUT_*, STREAK_* above). No costs.
	"quickshot": {"damage": 0.56, "cooldown": 8.0},
	"pierce": {"damage": 0.62, "cooldown": 12.0},
	"spread": {"damage": 0.38, "cooldown": 15.0},
	"heavydraw": {"damage": 1.62, "cooldown": 20.0, "cast_time": 1.5},
	"followup": {"damage": 0.28, "cooldown": 10.0},
	"loose": {"damage": 0.31},
	"breathe": {"cooldown": 30.0},
	"fasthands": {"cooldown": 120.0},
	# Utility (each book's "Utility" divider; the numbers above)
	"rootsnare": {"cooldown": 20.0, "cost": 2, "radius": 3.0, "range": 30.0},
	"deeproots": {"cooldown": 60.0, "cost": 1},
	"sporesleep": {"cooldown": 30.0, "cost": 2, "cast_time": 2.0, "range": 30.0},
	"leafcloak": {"cooldown": 120.0, "radius": 30.0},
	"coolingslag": {"cooldown": 20.0, "cost": 2, "cast_time": 1.5, "radius": 5.0, "range": 30.0},
	"staticsnare": {"cooldown": 20.0, "cost": 20, "range": 30.0},
	"stormfront": {"cooldown": 60.0, "cost": 20, "radius": 15.0},
	"bellows": {"cooldown": 25.0, "cost": 2, "radius": 6.0},
	"climbthestring": {"cooldown": 20.0, "cost": 1, "range": 30.0},
	"circleofsilence": {"cooldown": 25.0, "cost": 2, "radius": 5.0, "range": 30.0},   # interrupt: see INTERRUPT_LOCKOUT
	"holyground": {"cooldown": 45.0, "cost": 2, "radius": 5.0, "range": 30.0},
	"fixedpoint": {"cooldown": 20.0, "cost": 2, "range": 30.0},
	"bindingring": {"cooldown": 30.0, "cost": 2, "radius": 3.0, "range": 40.0},
	# Healers' out-of-combat rez (RAISE_*; RezKit)
	"hymnofwaking": {"cost": 4, "cast_time": 8.0, "range": 30.0},
	"relight": {"cost": 4, "cast_time": 8.0, "range": 30.0},
	"backonyourfeet": {"cost": 4, "cast_time": 8.0, "range": 30.0},
	"returntobloom": {"cost": 4, "cast_time": 4.0, "range": 30.0},
}

# --- Status effects ----------------------------------------------------------------

const EFFECTS := {
	"res://data/effects/grasped.tres": {"duration": GRASP_HOLD},   # Grasp (Nature tank)
	"res://data/effects/knocked_down.tres": {"duration": STAGGER_KNOCKDOWN},   # a full Stagger (Martial warrior: the Maul)
	"res://data/effects/shaken_down.tres": {"duration": EARTHSHAKE_TIME},   # Earthshake (Martial warrior: the Maul)
	"res://data/effects/kicked_down.tres": {"duration": KICKED_DOWN_TIME},   # Roundhouse / Throw (Martial tank: the Brawler)
	"res://data/effects/taken_down.tres": {"duration": TAKEDOWN_TIME},   # Takedown (Martial tank: the Brawler)
	"res://data/effects/pinned_shadow.tres": {"duration": PIN_SHADOW_TIME, "break_hits": PIN_SHADOW_HITS},   # Pin the Shadow (Martial Utility)
	"res://data/effects/blinded.tres": {"duration": FLASH_POWDER_TIME},   # Snatch - Flash Powder (Martial DPS: the Rogue)
	"res://data/effects/asp_venom.tres": {"duration": POISON_TIME, "slow": -ASP_SLOW},   # Asp Arrow (Nature archer)
	"res://data/effects/coiled.tres": {"duration": COIL_HOLD},   # Coil Back
	"res://data/effects/snagged.tres": {"duration": CLINGING_VINES_TIME, "slow": -CLINGING_VINES_SLOW_STEP},   # Clinging Vines (Nature open talent; one stack per rank)
	"res://data/effects/pitched.tres": {"duration": PITCH_TIME},   # Pitch (Fire archer)
	"res://data/effects/burning.tres": {"duration": 4.0, "tick_damage": 0.1, "tick_every": 1.0},
	"res://data/effects/immolate.tres": {"duration": 12.0, "tick_damage": 0.2, "tick_every": 1.0},
	"res://data/effects/live_wire.tres": {"duration": 10.0, "tick_damage": 0.2, "tick_every": 1.0},
	"res://data/effects/poisoned.tres": {"duration": 5.0, "tick_damage": 0.15, "tick_every": 1.0},
	"res://data/effects/corrupted.tres": {"duration": 8.0, "tick_damage": 0.2, "tick_every": 1.0},
	"res://data/effects/hoarfrost.tres": {"duration": 10.0, "tick_damage": 0.1, "tick_every": 1.0, "burst": 1.25},
	"res://data/effects/chilled.tres": {"duration": 3.0, "slow": -40.0},
	"res://data/effects/frozen.tres": {"duration": 3.0, "slow": -80.0},
	"res://data/effects/rooted.tres": {"duration": 3.0},
	"res://data/effects/stunned.tres": {"duration": 1.0},
	"res://data/effects/weakened.tres": {"duration": 6.0, "damage_pct": -25.0},
	"res://data/effects/stoneguard.tres": {"duration": 6.0, "damage_pct": -25.0},
	"res://data/effects/rime_shell.tres": {"duration": 15.0, "damage_pct": -20.0},
	"res://data/effects/rime_shell_foe.tres": {"duration": 15.0, "damage_pct": 5.0},
	"res://data/effects/thawing.tres": {"duration": 15.0},
	"res://data/effects/lightning_rod.tres": {"duration": 8.0},   # Grounded Arrow: how long a Storm Arrow stays stuck in its target
	"res://data/effects/coldmarked.tres": {"duration": 12.0},     # Coldmark: how long the mark stays on the target
	"res://data/effects/countdown.tres": {"duration": COUNTDOWN_TIME},   # Countdown: the mark lasts until it detonates
	"res://data/effects/aftershock.tres": {"duration": AFTERSHOCK_TIME, "slow": -AFTERSHOCK_SLOW_STEP},   # Aftershock (talent): rank 1's slow; higher ranks scale it
	"res://data/effects/decay.tres": {"duration": DECAY_OPEN_TIME},   # Decay: the debuff of an open one lasts as long as it is open
	"res://data/effects/laid_open.tres": {"duration": LAID_OPEN_TIME},   # Open Up: the mark the Hounds bite harder
	"res://data/effects/strung_up.tres": {"duration": STRING_UP_TIME},   # String Up: the enemy hangs, stunned
	"res://data/effects/tangled.tres": {"duration": TANGLE_TIME},        # Tangle: rooted
	"res://data/effects/rootsnared.tres": {"duration": ROOTSNARE_TIME},          # Rootsnare: rooted
	"res://data/effects/asleep.tres": {"duration": SPORE_SLEEP_TIME},           # Spore Sleep: asleep until hit
	"res://data/effects/molten_slag.tres": {"duration": 0.6, "slow": -COOLING_SLAG_SLOW},   # Cooling Slag: in the pool (renewed while inside)
	"res://data/effects/slagbound.tres": {"duration": COOLING_SLAG_ROOT},       # Cooling Slag: rooted when it hardens
	"res://data/effects/static_snared.tres": {"duration": STATIC_SNARE_TIME},   # Static Snare: rooted
	"res://data/effects/fixed.tres": {"duration": FIXED_POINT_TIME},            # Fixed Point: rooted (+ per Arcane cooldown)
	"res://data/effects/ringbound.tres": {"duration": BINDING_RING_ROOT},       # Binding Ring: rooted
}

# --- Applying (nothing to tune below) ---------------------------------------------------

const _ABILITY_FIELDS := {"damage": "damage", "weapon_mult": "weapon_damage_multiplier",
	"cooldown": "cooldown", "cost": "resource_cost", "generates": "resource_generated",
	"cast_time": "cast_time", "radius": "radius", "range": "cast_range", "threat": "threat_multiplier"}
const _EFFECT_FIELDS := {"duration": "duration", "tick_damage": "tick_damage",
	"tick_every": "tick_interval", "burst": "expire_damage", "damage_pct": "damage_mod_pct",
	"break_hits": "break_after_hits"}

## Effects stay loaded (and so keep their tuned values) while the game runs.
static var _effects_kept: Array[Resource] = []
static var _effects_done := false

## Abilities that use another ability's numbers (damage, cost, cast time, range):
## Frostfire Bolt is a Frost Bolt whose damage is split over two schools, so
## tuning Frost Bolt tunes it too.
const ABILITY_SAME_AS := {"frostfirebolt": "frostbolt"}
## Share of a Frostfire Bolt's damage that is Frost (the rest is Fire).
const FROSTFIRE_FROST_SHARE := 0.5

## Write ABILITIES[id] into a freshly loaded AbilityData.
static func apply_ability(id: String, r: Resource) -> void:
	if r == null:
		return
	apply_effects()
	var t: Dictionary = ABILITIES.get(str(ABILITY_SAME_AS.get(id, id)), {})
	for k in t:
		var field: String = _ABILITY_FIELDS.get(k, "")
		if field != "" and field in r:
			var cur: Variant = r.get(field)
			r.set(field, int(t[k]) if cur is int else float(t[k]))

## Write EFFECTS into the status effect resources (once per run).
static func apply_effects() -> void:
	if _effects_done:
		return
	_effects_done = true
	for path in EFFECTS:
		if not ResourceLoader.exists(path):
			continue
		var fx: Resource = load(path)
		if fx == null:
			continue
		var t: Dictionary = EFFECTS[path]
		for k in t:
			if k == "slow":
				var mods: Dictionary = fx.get("stat_modifiers") if fx.get("stat_modifiers") is Dictionary else {}
				mods = mods.duplicate()
				mods["move_speed"] = float(t[k])
				fx.set("stat_modifiers", mods)
				continue
			var field: String = _EFFECT_FIELDS.get(k, "")
			if field != "" and field in fx:
				fx.set(field, int(t[k]) if fx.get(field) is int else float(t[k]))
		_effects_kept.append(fx)

## Share of full damage each target takes when `count` enemies are hit by a
## capped AoE: 1.0 up to AOE_TARGET_CAP targets, cap / count beyond that.
static func aoe_share(count: int, cap: int = AOE_TARGET_CAP) -> float:
	if count <= cap or count <= 0:
		return 1.0
	return float(cap) / float(count)
