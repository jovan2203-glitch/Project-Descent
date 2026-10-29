# Fire book

Values in Frost Bolts (FB) are conversation shorthand; real numbers live in balance.gd.

## Identity
Built around critical strikes, specifically around trying to AVOID crits: non-crits are rewarded, low crit can be stronger.

## Caster (Steady Flame): Fury
The game's first Fury caster: one rule where you avoid crits but still want crit chance. Code: scripts/player/fire_fury.gd.
- Steady Flame spells cost no mana: they build or spend Fury (the 100-point bar).
- Building: a Fire spell hit that does NOT crit gives 6 + 0.6 per 1% crit chance, once per cast; each Ember Volley ember is its own, at a third. Ticks, procs and spells that cost Fury build none. The crit chance is the one before the spell's own changes (Tempered Flame, Cool Head, Damped/Wild Embers), so those never shrink the gain.
- Venting: a Fire spell crit Vents 50% of your Fury (the crit still deals full damage). Vent Flames' own sure crit doesn't.
- More crit chance = more Fury per non-crit, but more crits that Vent it: the best spot is somewhere under 50%.
- Fury doesn't decay while casting or channeling; idle, it drops 5 a second.
- Firebolt - free builder, 2.2 s cast.
- Ember Volley - free builder; each ember rolls crit (and Vents) on its own.
- Blaze (Immolate) - free; no damage on landing, so it builds nothing. Cast again on the same target spreads it to 2 others.
- Vent Flames - spends all your Fury (needs 20), +0.5% damage per Fury spent, always crits, 10 s cooldown.
- Kiln Blast - 40 Fury, can't crit, 3.5 s cast, +20% on a Blazed target: the non-crit spender.
- Stoke 20 Fury, Flame Nova 30, Wall of Fire 30 (20 s cooldown), Crucible 20 (moving it stays free).
- Cool Head - instant, 2 min cooldown, 15 s: Fire spells and abilities can't crit (so no Venting); each damaging one gives 1 Concentrated Fire. When it ends, next Fire spells/abilities with a cast time are instant, 1 cast per stack; the buff stays 5 s after Cool Head ends.
- Crucible - 1.5 s cast, ground circle 5.65 m: +15% periodic Fire damage to enemies inside for 12.5 s (Deep Crucible folded in); recast while it stands is instant and moves it. Own-only.
- Removed 2026-10-22: Slow Fuse and Rekindle.
- The Utility Fire spells keep their mana costs; their non-crit hits still build Fury.

## Caster utility
- Furnace Breath - close-range cone AoE spell; the Fire interrupt.
- Cinder Step - short dash leaving a burning line; next cast-time Fire spell castable while moving.
- Heat Sink - 6 s defensive: part of damage taken is stored, then released as a fire burst.
- (Slag Skin is the tank's: Slagforged below.)

## Tank: Slagforged (one-handed weapon + shield, Fury) - REWORKED 2026-10-23
The block tank (Frost absorbs, Lightning parries, Arcane dodges). Code: scripts/player/fire_tank.gd.
- Slag: up to 6 stacks of Armor while Slag Skin is up. +1 per attack you block, +1 per melee hit of yours (once per swing). A crit's stack is brittle: it crumbles after 3 s. Slag never breaks by itself: only Forge Blow shatters it, for Fire damage per stack within 5 m (3x threat). Keep it for armor, or break it for an AoE threat spike.
- Slag Skin - free, 15 s, 13 s cooldown (kept up): burns every attacker; Slag lasts as long as it does.
- Brand - builder (weapon + 1.0 FB, 5x threat); the branded enemy deals 10% less damage to you.
- Anvil - shield slam (half weapon + 0.65 FB, 6x threat) around you; never crits, so its Slag is never brittle.
- Cinder Guard - 20 Fury: 6 s of +25% block; each block burns the attacker, gives 2 Slag and extends Slag Skin.
- Red-Hot Rivet - the taunt: off the GCD, 8 s, 25 m, 0.3 FB; the target attacks you for 3 s; +1 Slag.
- Forge Blow - 30 Fury, 8 s, can't crit: shatters all your Slag (Slag Mending and Smoldering Debris trigger).
- Molten Shell - 2 min, off the GCD, 10 s: Slag holds up to 12, each block adds 2, 1% less damage taken per Slag. When it ends Slag drops back to 6 (or Forge Blow all 12 first).

## Melee DPS: Forge Heat (melee weapon, Fury) - REWORKED 2026-10-23
Code: scripts/player/fire_melee.gd.
- Heat: up to 10, +4% Fire ability damage per stack, lost 3 s after the last stack. Built by melee hits on a target with your Burning or Blaze (Searing Strike Burns, so Blaze isn't needed).
- Sparks: while you hold Heat your melee hits can't crit; a hit that would have is a Spark: normal damage, 1 more Heat. At 0 Heat you crit normally. Crit chance = faster Heat.
- Heat bands: Red (1-4), Orange (5-8), White (9-10). Every ability does more in Orange and White; spending drops you a band.
- Searing Strike - 30 Fury, builder, Burning, 2 Heat on a Burning target. Orange: its Burning also goes on the nearest other enemy. White: 15 Fury back.
- Fold Steel - 25 Fury, 8 s: 3 quick hits (0.5 weapon each), each its own Spark roll and Heat. Orange: 4 hits. White: each hit splashes 50% within 3 m.
- Quench - all Heat, +25% per Heat, can't crit, needs 3. White: 50% of it also hits enemies within 4 m.
- Flare - 3 Heat, AoE sweep, spreads your target's Burning. Orange: +30%. White: costs no Heat.
- Red Edge - 20 Fury, 15 s, off the GCD, 6 s: auto-swings build Heat on any target. Orange: they also deal 0.25 weapon Fire (own meter line). White: every one is a Spark.
- Blast Furnace - 2 min, off the GCD, 12 s: everything counts as White, Heat doesn't fade.

## Archer: Pitch and Cinder (bow, Energy) - REWORKED 2026-10-23
Code: scripts/player/fire_bow.gd.
- Pitch: your own coat on a target, up to 5 layers, 15 s (refreshed by each layer). Each layer: your Burning and Blaze on it tick 8% faster. +1 layer per arrow of yours that doesn't crit (abilities and auto-shots).
- Ignite: an arrow crit on a coated target Ignites it: 0.15 FB per layer to it and every enemy within 6 m (split past the cap), Burning on every enemy hit without it, layers gone; its own meter line. Low crit = single target, high crit = packs.
- Flaming Arrow - 30 Energy, 6 s: hit + Burning.
- Coal Shot - 15 Energy, no cooldown: the filler, 1.3 weapon.
- Pitch Arrow - 20 Energy, 12 s: +2 layers, even when it crits.
- Cinder Rain - 40 Energy, 15 s, placed: its ticks coat each enemy (a layer a second at most), a crit tick Ignites.
- Touch Off - 30 Energy, 10 s: Ignites on purpose at +50%, can't crit, needs Pitch on the target.
- Brushfire - 2 min, 12 s: auto-shots Burn their target and add 2 layers.

## Talents - REBUILT 2026-10-23, on ribbons 2026-10-26
Like Martial (docs/design/systems.md, "Talents", "Ribbon layout"). Numbers are drafts (talents.gd, balance.gd).
- Layout: 10 rows x 13 columns. Steady Flame columns 1-3, Slagforged 4-6, open talents 7 (the spine, rows 1-8), Forge Heat 8-10, Pitch and Cinder 11-13. Row 10: each spec's 5-rank capstone, gated at 15 points in the spec.
- Links: Stoked Breath -> Lean Fuel, Clean Burn -> Stay Lit, Fuel the Forge -> Heavy Hammer, Banked Fire -> Overheat, Spreading Fire -> Fuel Run.
- Size: 19 talents per spec (56-57 ranks), 8 open. 18 of 85 talents need one ability (21%).
- Code: each spec's component, plus scripts/player/fire_talents.gd for the hit bonuses (each its own meter line).
- Removed: Cool Under Fire (a DPS defensive), Deep Crucible (folded into Crucible: 5.65 m, 12.5 s), Kindling (Sparks), Forge Heat (became Slow Cooling); Fresh Tinder now feeds Burning, Long Burn lengthens Burning too.

**Steady Flame**: its seals form a flame.

| Row | Left | Middle | Right |
|---|---|---|---|
| 1 |  | Stoked Breath (4) |  |
| 2 | Tempered Flame (3, Firebolt) |  | Pressure Valve (3, Vent Flames) |
| 3 |  | Lean Fuel (3) |  |
| 4 | Banked Coals (2) |  | Afterburn (3) |
| 5 | Damped / Wild Embers (choice, 3) | Scattered Embers (2) | Blowback (3) |
| 6 | Long Burn (3) | Stoked Kiln (3) | Hold the Heat (3) |
| 7 | Long Focus (3) | Clean Burn (3) | Big Spend (3) |
| 8 | Warm Start (2) |  | Low Flame (3) |
| 9 |  | Stay Lit (3) |  |
| 10 |  | Smoldering Focus (5) |  |

**Slagforged**: its seals form an anvil.

| Row | Left | Middle | Right |
|---|---|---|---|
| 1 | Thick Slag (4) | Hot Iron (3) | Slag Mending (3) |
| 2 | Smoldering Debris (3) | Deep Brand (3, Brand) | Hard Crust (3) |
| 3 |  | Set Hard (2) |  |
| 4 |  | Red Iron (3) |  |
| 5 |  | Marked Iron (3) |  |
| 6 |  | Fuel the Forge (3) |  |
| 7 | Deep Slag (2) |  | Riveted (3, Rivet) |
| 8 | Glowing Seams (3) | Heavy Hammer (3, Forge Blow) | Long Shell (2, Molten Shell) |
| 9 | Spatter (3) | Quick Temper (3) | Heat Shimmer (3) |
| 10 |  | Molten Heart (5) |  |

**Forge Heat**: its seals form a hammer.

| Row | Left | Middle | Right |
|---|---|---|---|
| 1 | White Heat (4) | Bright Sparks (3) | Slow Cooling (3) |
| 2 | Spark Bite (3) | Afterglow (3, Quench) | Fresh Tinder (3) |
| 3 | Hard Quench (3) | Wide Flare (2, Flare) | Banked Fire (3, Quench) |
| 4 |  | Hammer Rhythm (3) |  |
| 5 |  | Fold Again (2, Fold Steel) |  |
| 6 | Deep Sear (3) |  | Overheat (3) |
| 7 | Steady Arm (3) |  | Long Blast (2, Blast Furnace) |
| 8 | Cold Steel (3) |  | Quick Forge (3) |
| 9 |  | Fed Furnace (3) |  |
| 10 |  | Molten Edge (5) |  |

**Pitch and Cinder**: its seals form a rising arrow.

| Row | Left | Middle | Right |
|---|---|---|---|
| 1 |  | Sticky Pitch (4) |  |
| 2 | Easy Draw (3) | Big Flash (3) | Long Coat (3) |
| 3 | Spreading Fire (2) | Double Coat (2, Pitch Arrow) | Dripping (3) |
| 4 |  | Hot Shafts (3) |  |
| 5 |  | Second Light (3, Touch Off) |  |
| 6 |  | Ember Bed (3) |  |
| 7 | Fuel Run (3) |  | Wide Rain (2, Cinder Rain) |
| 8 | Patient Fire (3) | Long Brush (2, Brushfire) | Kindle Pack (3) |
| 9 | Steady Bow (3) | Clean Shot (3) | Fire Line (3) |
| 10 |  | Pitch Black (5) |  |

What the new ones do (ranks in talents.gd):
- Steady Flame: Lean Fuel (Fury costs less), Long Burn (Burning and Blaze last longer), Stoked Kiln (Fury spenders hit Blazed targets harder), Hold the Heat (Fury drops slower out of casting), Long Focus (Concentrated Fire lasts longer), Clean Burn (non-crit Fire spells hit harder), Big Spend (spending 60+ Fury hits harder: Vent Flames), Warm Start (Fury on entering combat), Low Flame (below 20% crit, Fire spells hit harder), Stay Lit (after a Vent, the next non-crit gives more Fury).
- Slagforged: Hard Crust (block per Slag), Set Hard (brittle Slag lasts longer), Red Iron (shield abilities), Marked Iron (shatters vs Branded), Fuel the Forge (Fury per block), Deep Slag (more Slag), Riveted (Rivet cooldown), Heavy Hammer (Fury back per Slag shattered), Glowing Seams (threat at full Slag), Long Shell, Spatter (a shatter may leave a stack), Quick Temper (a shatter shortens Cinder Guard), Heat Shimmer (less spell damage per Slag), Molten Heart (shatters stronger per stack above 3).
- Forge Heat: White Heat (White band), Bright Sparks (a Spark may give 2), Slow Cooling (Heat lasts longer), Spark Bite (Sparks hit harder), Fresh Tinder (melee abilities feed Burning), Hard Quench (Heat spenders per Heat spent), Wide Flare, Banked Fire (Quench leaves Heat), Hammer Rhythm (Fury per auto-swing), Fold Again, Deep Sear (Burning), Overheat (a White Spark burns the enemies around, own line), Steady Arm (melee cooldowns faster in Orange/White), Long Blast, Cold Steel (at 0 Heat crits hit harder and give Heat), Quick Forge (Sparks cut Fire ability cooldowns), Fed Furnace (Fury from Heat spenders), Molten Edge (more per Heat).
- Pitch and Cinder: Sticky Pitch (more speed per layer), Easy Draw (arrows cost less), Big Flash (Ignites), Long Coat (Pitch lasts longer), Spreading Fire (Ignite reach), Dripping (Burning at 3+ layers), Double Coat, Hot Shafts (auto-shots on coated targets, own line), Second Light (Touch Off may skip its cooldown), Ember Bed (an Ignite may leave a layer on each enemy), Wide Rain, Fuel Run (Energy per Ignite), Patient Fire (arrows at 5 layers), Kindle Pack (an Ignite hitting 3+ re-coats the target), Long Brush, Steady Bow (Energy per non-crit arrow), Clean Shot (non-crit arrows vs coated targets), Fire Line (Burning beyond 20 m), Pitch Black (arrows per layer).

## Runes
- Epic Dull Edge: crit chance capped at 10%, the excess becomes Attack Power.
- Epic Dull Mind: the Spell Power version; your Fire spells also gain Fury as if crit weren't capped.
- Epic Hair Trigger: Vent Flames has 2 charges, but each spends only half your Fury.
- Epic Sealed Kiln: your crits no longer Vent Fury, but you gain 30% less of it.
- Epic: Cool Head makes spells from any school instant cast.
- Menace (Fire): +30% threat (one Menace rune at a time).

## Utility (the book's "Utility" divider) - BUILT 2026-10-17
- Cooling Slag (Fire's root) - 1.5 s cast, 20 s cooldown, 2 mana, 30 m. Molten slag within 5 m of the target: enemies in it 30% slower; after 2 s it hardens and roots enemies still inside for 3 s. Code: scripts/player/utility.gd.
- Bellows - instant, 25 s cooldown, 2 mana, card level 16. Enemies within 6 m are thrown 8 m away (bosses too heavy); a stack of Heat per enemy thrown, up to 3 (Forge Heat). The game's only knockback. Moved from Nature (was Overgrowth). Code: scripts/player/utility.gd.
- Also in Utility (coded with their specs): Furnace Breath, Cinder Step, Heat Sink, Cinderwing.
