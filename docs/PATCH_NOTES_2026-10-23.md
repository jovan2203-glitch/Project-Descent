# Patch notes — 23 October 2026 (0.0.21)

Fire's other three specs are rebuilt, each around its own twist on the book's rule of avoiding critical strikes, and the Fire talent tree moves to the column-group layout with its four specs side by side. Damage is given at level 50 before gear.

## Fire

### Slagforged (tank)

Slagforged is the block tank. Slag now comes from blocking as well as hitting, never breaks on its own, and is shattered only when you choose to.

- Changed: Slag. While Slag Skin is up, each attack you block now gives a stack of Slag, and so does each of your melee hits, critical or not (once per swing). A stack from a critical strike is brittle and crumbles after 3 sec.
- Changed: Slag no longer shatters when you critically strike. Only Forge Blow shatters it.
- Changed: Cinder Guard: each attack you block during it gives 2 Slag instead of one.
- Changed: Anvil never critically strikes, so its Slag is never brittle.
- New ability: Red-Hot Rivet (8 sec cooldown, instant, 25 m, off the global cooldown, card level 6). Slagforged's taunt. Deals 138 Fire damage; the target must attack you for 3 sec, and you gain 1 Slag. Needs a shield.
- New ability: Forge Blow (30 Fury, 8 sec cooldown, instant, card level 14). Shatters all your Slag at once: each stack deals 115 Fire damage to every enemy within 5 m with 3x threat (split evenly past 5 enemies). It cannot critically strike and needs Slag.
- New ability: Molten Shell (2 min cooldown, instant, off the global cooldown, card level 24). For 10 sec your Slag holds up to 12 stacks, each attack you block gives 2 Slag, and you take 1% less damage for each Slag you hold. When it ends, Slag above 6 is lost. Needs a shield.

### Forge Heat (melee)

Heat now builds on your Burning, critical strikes turn into extra Heat, and every ability does more as your weapon gets hotter.

- Changed: Heat is built by your melee hits on a target with your Burning or your Blaze (was Blaze only), so Searing Strike's Burning is enough.
- New: Sparks. While you hold Heat, your melee hits cannot critically strike. A hit that would have is a Spark: it deals normal damage and builds one more Heat. With no Heat you critically strike as usual.
- New: Heat bands. Red is 1 to 4 Heat, Orange 5 to 8, White 9 and 10. Forge Heat's abilities do more in the Orange and White bands.
- Changed: Searing Strike. Orange band: its Burning also goes on the nearest other enemy within 8 m. White band: it gives you 15 Fury back.
- Changed: Quench. White band: 50% of its damage also hits every enemy within 4 m of the target.
- Changed: Flare spreads your Burning (was Blaze). Orange band: 30% more damage. White band: it costs no Heat.
- New ability: Fold Steel (25 Fury, 8 sec cooldown, instant, card level 10). Strikes 3 times in quick succession for 50% of your weapon damage as Fire damage each. Each hit builds its own Heat and can be its own Spark. Orange band: 4 hits. White band: each hit also deals 50% of its damage to every enemy within 3 m of the target.
- New ability: Red Edge (20 Fury, 15 sec cooldown, instant, off the global cooldown, card level 20). For 6 sec each of your auto-attacks builds a Heat on any target. Orange band: each also deals 25% of your weapon damage as Fire damage, with its own damage-meter line. White band: each is a Spark.
- New ability: Blast Furnace (2 min cooldown, instant, off the global cooldown, card level 26). For 12 sec your abilities count as the White band whatever your Heat, and your Heat does not fade.

### Pitch and Cinder (bow)

Arrows that don't crit coat the target in layers of Pitch; a critical strike sets it alight. Less crit chance suits single targets, more suits packs.

- Changed: Pitch now comes in layers, up to 5, for 15 sec (was 12; each new layer starts the time over). Each layer makes your Burning and Blaze on the target tick 8% faster (was a flat 25%). Each of your arrows that does not critically strike adds a layer, auto-shots included.
- New: Ignite. An arrow critical strike on a target with your Pitch Ignites it: each layer deals 69 Fire damage to the target and every enemy within 6 m of it (split evenly past 5 enemies), every enemy hit without your Burning starts Burning, and the layers are gone. It has its own damage-meter line.
- Changed: Pitch Arrow adds 2 layers of Pitch, even when it critically strikes.
- Changed: Cinder Rain: its ticks that do not critically strike coat each enemy in a layer of Pitch, at most once a second; a tick that does Ignites it.
- New ability: Coal Shot (15 Energy, no cooldown, instant, card level 12). Deals 70% of your weapon damage as Fire damage.
- New ability: Touch Off (30 Energy, 10 sec cooldown, instant, card level 18). Ignites your Pitch on the target for 50% more damage: 104 Fire damage per layer. It cannot critically strike and needs your Pitch on the target.
- New ability: Brushfire (2 min cooldown, instant, card level 30). For 12 sec your auto-shots set their target Burning and add 2 layers of Pitch instead of one.

### Steady Flame (caster)

- Changed: Crucible is 11.3 m wide (was 10 m) and lasts 12.5 sec (was 10): Deep Crucible's middle rank is now part of it.

### Talents

The Fire tree is rebuilt on the column-group layout, like Martial: Steady Flame, Slagforged, the open talents, Forge Heat and Pitch and Cinder side by side, 19 talents per spec. Each spec's row 10 talent needs 25 points spent in that spec. Every player's talent points are refunded.

Steady Flame:
- Moved: Stoked Breath to row 1, now 4 ranks: 5 / 10 / 15 / 20% more Fury (was 2 ranks: 10 / 20%).
- Moved: Tempered Flame to row 1, Pressure Valve to row 2, Banked Coals to row 3, Damped Embers / Wild Embers and Scattered Embers to row 4, Blowback to row 5, Smoldering Focus to row 10.
- Changed: Afterburn (row 3) has 3 ranks: (100 - crit chance) x 0.17 / 0.33 / 0.5% per stack (was 5 ranks of 0.1 each).
- Changed: Long Burn (row 5, 3 ranks): your Burning and Blaze last 1 / 2 / 3 sec longer (was Blaze only). It no longer requires Blaze.
- Changed: Stoked Kiln (row 6, 3 ranks): your spells and abilities that cost Fury deal 5 / 10 / 15% more damage to a target with your Blaze (was Kiln Blast only, 27 / 33 / 40% instead of 20%).
- New talent: Lean Fuel (row 2, 3 ranks). Your spells and abilities that cost Fury cost 2 / 4 / 6 less.
- New talent: Hold the Heat (row 6, 3 ranks). While you are not casting, your Fury drops 33 / 66 / 100% slower.
- New talent: Long Focus (row 7, 3 ranks). Your Concentrated Fire lasts 2 / 4 / 6 sec longer.
- New talent: Clean Burn (row 7, 3 ranks). Your Fire spells that do not critically strike deal 2 / 4 / 6% more damage.
- New talent: Big Spend (row 8, 3 ranks). A spell or ability that spends 60 or more Fury deals 5 / 10 / 15% more damage.
- New talent: Warm Start (row 8, 2 ranks). When you enter combat, you gain 20 / 40 Fury.
- New talent: Low Flame (row 9, 3 ranks). While your critical strike chance is below 20%, your Fire spells deal 3 / 6 / 9% more damage.
- New talent: Stay Lit (row 9, 3 ranks). After a critical strike Vents your Fury, your next Fire spell that does not critically strike gives 30 / 60 / 100% more Fury.

Slagforged:
- Moved: Thick Slag to row 1, now 4 ranks: 15 / 30 / 45 / 60% more Armor per stack (was 3 ranks: 20 / 40 / 60%).
- Moved: Hot Iron to row 1, now 3 ranks: blocked attackers burn 10 / 20 / 30% more (was 4 ranks: 15 / 30 / 45 / 60%).
- Moved: Slag Mending and Deep Brand to row 2, Smoldering Debris to row 3. Slag Mending and Smoldering Debris no longer require Slag Skin.
- New talent: Hard Crust (row 3, 3 ranks). Each stack of Slag gives you 0.5 / 1 / 1.5% chance to block.
- New talent: Set Hard (row 4, 2 ranks). Your brittle Slag lasts 1.5 / 3 sec longer.
- New talent: Red Iron (row 4, 3 ranks). Your shield abilities deal 5 / 10 / 15% more damage.
- New talent: Marked Iron (row 5, 3 ranks). Your Slag shattering deals 33 / 66 / 100% more damage to enemies you have Branded.
- New talent: Fuel the Forge (row 5, 3 ranks). Each attack you block gives you 2 / 4 / 6 Fury.
- New talent: Deep Slag (row 6, 2 ranks). You can hold 1 / 2 more Slag.
- New talent: Riveted (row 6, 3 ranks, requires Red-Hot Rivet). Red-Hot Rivet's cooldown is 1 / 2 / 3 sec shorter.
- New talent: Heavy Hammer (row 7, 3 ranks, requires Forge Blow). Forge Blow gives you 2 / 4 / 6 Fury back for each stack of Slag it shatters.
- New talent: Glowing Seams (row 7, 3 ranks). While you hold all the Slag you can, your spells and abilities generate 10 / 20 / 30% more threat.
- New talent: Long Shell (row 8, 2 ranks, requires Molten Shell). Molten Shell lasts 2 / 4 sec longer.
- New talent: Spatter (row 8, 3 ranks). When your Slag shatters, there is a 20 / 40 / 60% chance a stack of it stays on you.
- New talent: Quick Temper (row 9, 3 ranks). When your Slag shatters, Cinder Guard's cooldown is 1 / 2 / 3 sec shorter.
- New talent: Heat Shimmer (row 9, 3 ranks). Each stack of Slag makes you take 0.5 / 1 / 1.5% less damage from spells.
- New talent: Molten Heart (row 10, 5 ranks). Your Slag shattering deals 2 / 4 / 6 / 8 / 10% more damage and threat for each stack above 3.

Forge Heat:
- Changed: White Heat (row 1, now 4 ranks): while your Heat is in the White band, your abilities deal 4 / 8 / 12 / 16% more Fire damage (was 5 / 10 / 15% at 10 Heat only). It no longer requires Blaze.
- Changed: Fresh Tinder (row 3, 3 ranks): your melee abilities have a 10 / 20 / 30% chance to add 1 sec to your Burning on the target they hit (was any ability, Blaze, with a 2 sec capstone). It no longer requires Blaze.
- Moved: Afterglow to row 2.
- New talent: Slow Cooling (row 2, 3 ranks), in place of the Forge Heat talent. Your Heat lasts 0.5 / 1 / 1.5 sec longer before it is lost.
- New talent: Bright Sparks (row 1, 3 ranks). Each of your Sparks has a 15 / 30 / 45% chance to build one more Heat.
- New talent: Spark Bite (row 3, 3 ranks). Your Sparks deal 10 / 20 / 30% more damage.
- New talent: Hard Quench (row 4, 3 ranks). Your abilities that spend Heat deal 1 / 2 / 3% more damage for each Heat they spend.
- New talent: Wide Flare (row 4, 2 ranks, requires Flare). Flare sweeps 30 / 60 degrees wider.
- New talent: Banked Fire (row 5, 3 ranks, requires Quench). Quench leaves you 1 / 2 / 3 Heat.
- New talent: Hammer Rhythm (row 5, 3 ranks). Your auto-attacks give you 1 / 2 / 3 more Fury.
- New talent: Fold Again (row 6, 2 ranks, requires Fold Steel). Fold Steel strikes 1 / 2 more times.
- New talent: Deep Sear (row 6, 3 ranks). Your Burning deals 5 / 10 / 15% more damage.
- New talent: Overheat (row 7, 3 ranks). While your Heat is in the White band, each of your Sparks also burns every other enemy within 4 m for 20 / 40 / 60% of its damage, with its own damage-meter line.
- New talent: Steady Arm (row 7, 3 ranks). While your Heat is in the Orange or White band, the cooldowns of your melee abilities recover 5 / 10 / 15% faster.
- New talent: Long Blast (row 8, 2 ranks, requires Blast Furnace). Blast Furnace lasts 2 / 4 sec longer.
- New talent: Cold Steel (row 8, 3 ranks). While you hold no Heat, your melee critical strikes deal 10 / 20 / 30% more damage and build 1 / 2 / 3 Heat.
- New talent: Quick Forge (row 9, 3 ranks). Each of your Sparks takes 0.2 / 0.4 / 0.6 sec off the cooldowns of your Fire abilities.
- New talent: Fed Furnace (row 9, 3 ranks). Your abilities that spend Heat give you 5 / 10 / 15 Fury.
- New talent: Molten Edge (row 10, 5 ranks). Each Heat makes your abilities deal 4.2 / 4.4 / 4.6 / 4.8 / 5% more Fire damage, instead of 4%.

Pitch and Cinder:
- New talent: Sticky Pitch (row 1, 4 ranks). Each layer of your Pitch makes your burns tick 0.5 / 1 / 1.5 / 2% faster on top of the usual 8%.
- New talent: Light String (row 1, 3 ranks). Your arrows that cost Energy cost 2 / 4 / 6 less.
- New talent: Big Flash (row 2, 3 ranks). Your Ignites deal 10 / 20 / 30% more damage.
- New talent: Long Coat (row 2, 3 ranks). Your Pitch lasts 3 / 6 / 9 sec longer.
- New talent: Spreading Fire (row 3, 2 ranks). Your Ignites reach 2 / 4 m further.
- New talent: Dripping (row 3, 3 ranks). Your Burning deals 5 / 10 / 15% more damage to a target with 3 or more layers of your Pitch.
- New talent: Double Coat (row 4, 2 ranks, requires Pitch Arrow). Pitch Arrow adds 1 / 2 more layers of Pitch.
- New talent: Hot Shafts (row 4, 3 ranks). Your auto-shots on a target with your Pitch also deal 3 / 6 / 9% of their damage as Fire damage, with its own damage-meter line.
- New talent: Second Light (row 5, 3 ranks, requires Touch Off). Touch Off has a 10 / 20 / 30% chance not to go on cooldown.
- New talent: Ember Bed (row 5, 3 ranks). Each enemy your Ignite hits has a 33 / 66 / 100% chance to be left with a layer of your Pitch.
- New talent: Wide Rain (row 6, 2 ranks, requires Cinder Rain). Cinder Rain covers an area 1 / 2 m wider.
- New talent: Fuel Run (row 6, 3 ranks). Each of your Ignites gives you 5 / 10 / 15 Energy.
- New talent: Patient Fire (row 7, 3 ranks). Your arrows deal 3 / 6 / 9% more damage to a target with 5 layers of your Pitch.
- New talent: Kindle Pack (row 7, 3 ranks). When your Ignite hits 3 or more enemies, it coats its target in 1 / 2 / 3 new layers of Pitch.
- New talent: Long Brush (row 8, 2 ranks, requires Brushfire). Brushfire lasts 3 / 6 sec longer.
- New talent: Steady Bow (row 8, 3 ranks). Each of your arrows that does not critically strike gives you 1 / 2 / 3 Energy.
- New talent: Clean Shot (row 9, 3 ranks). Your arrows that do not critically strike deal 3 / 6 / 9% more damage to a target with your Pitch.
- New talent: Fire Line (row 9, 3 ranks). Your Burning deals 4 / 8 / 12% more damage to targets more than 20 m away from you.
- New talent: Pitch Black (row 10, 5 ranks). Each layer of your Pitch on a target makes your arrows deal 1 / 2 / 3 / 4 / 5% more damage to it.

Open talents:
- Moved: Flash Point, Forge-Hardened, Lingering Embers, Controlled Burn, Feed the Flames, Last Ember, Tempered and Warm Blood to the open column in the middle of the tree (rows 1 to 8).

Removed:
- Removed: Cool Under Fire. Points refunded.
- Removed: Deep Crucible; its middle rank is now part of Crucible. Points refunded.
- Removed: Kindling; Sparks now give the extra Heat. Points refunded.
- Removed: the Forge Heat talent; it became Slow Cooling. Points refunded.
