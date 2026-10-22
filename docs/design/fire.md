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
- Crucible - 1.5 s cast, ground circle: +15% periodic Fire damage to enemies inside for 10 s; recast within 10 s is instant and moves it. Own-only.
- Removed 2026-10-22: Slow Fuse and Rekindle.
- The Utility Fire spells keep their mana costs; their non-crit hits still build Fury.

## Caster utility
- Furnace Breath - close-range cone AoE spell; the Fire interrupt.
- Cinder Step - short dash leaving a burning line; next cast-time Fire spell castable while moving.
- Heat Sink - 6 s defensive: part of damage taken is stored, then released as a fire burst.
- Slag Skin - defensive: more armor, damages attackers.

## Tank (Slag, shield)
- Slag Skin (tank version) - instant, 15 s duration, 13 s cooldown (must be maintained). Melee hits that don't crit add armor stacks; a crit shatters them for Fire damage around you.
- Brand - fury-building high-threat strike (weapon + 1.0 FB, was 0.3: tank rule pass; 5x threat, was 3x); branded enemy deals less damage to you.
- Cinder Guard - fury spender: 6 s more block; each block burns the attacker and extends Slag Skin.
- Anvil - shield slam (half weapon + 0.65 FB, was 0.3; 6x threat, was 4x), AoE Fire threat, never crits (always adds Slag).

## Melee DPS (Heat)
- Immolate the target, then weapon hits build Heat: +4% Fire damage to abilities (not spells) per stack. Crit has no interaction with Heat. Heat falls off after 3 s without a new stack.
- Searing Strike - builder, 2 Heat on a burning target.
- Quench - finisher: removes all Heat, +25% per Heat, can't crit, needs 3 Heat.
- Flare - AoE, costs 3 Heat, spreads Immolate.

## Talents
- Fireball talent (row 1, 2 ranks): Fireball gains 40/60% less of your crit chance but deals bonus damage equal to 10/20% of your crit chance.
- Generic rows 1-2: Flash Point, Forge-Hardened, Lingering Embers, Controlled Burn.
- Cool Under Fire (row 3, 3): 7/13/20% less damage during Cool Head.
- Stoked Breath (row 1, 2; was Banked Mana): non-crit Fire spells give 10/20% more Fury.
- Pressure Valve (3): non-crit Fire spells take 0.15/0.35/0.5 s off Vent Flames' cooldown.
- Damped Embers or Wild Embers (r5c5, the game's first choice talent: points go into only one): Ember Volley's embers have 10/20/30 less or more crit chance.
- Blowback (r6c5, 3): when a crit Vents your Fury, 20/35/50% of the Fury Vented burns the target (0.03 FB per point over 4 s; its own meter line).
- Ember Volley talent (Scattered Embers): hits 1/2 more targets.
- Smoldering Focus (bottom row, 5 ranks): Fire spells deal 0.02/0.04/0.06/0.08/0.1% more damage per Fury you hold (+10% at 100 Fury).
- Afterburn (to its right): crits give bonus damage on your next non-critical spell, scaling from 100 minus your crit chance.
- Banked Coals (bottom row, middle slot, 2): crits Vent 25/50% less of your Fury.
- Removed 2026-10-22: Volatile Fuse and Flashover (with Slow Fuse).
- Tank: Thick Slag (3), Smoldering Debris (3, was Clinker): shattered Slag leaves a burning patch, 7/13/20%, uses normal crit chance; Hot Iron (4): blocks deal more retaliation damage.
- Melee: Kindling (3): Searing Strike 10/20/30% chance for 1 extra Heat. Afterglow (3): for 4 s after Quench auto-swings deal 7/13/20% more Fire damage. A 3-rank talent: abilities 10/20/30% chance to add 1 s to your active Immolate, capstone 2 s, up to its base duration.

## Runes
- Epic Dull Edge: crit chance capped at 10%, the excess becomes Attack Power.
- Epic Dull Mind: the Spell Power version; your Fire spells also gain Fury as if crit weren't capped.
- Epic Hair Trigger: Vent Flames has 2 charges, but each spends only half your Fury.
- Epic Sealed Kiln: your crits no longer Vent Fury, but you gain 30% less of it.
- Epic: Cool Head makes spells from any school instant cast.
- Menace (Fire): +30% threat (one Menace rune at a time).

## Not built yet (picked open talents)
- Feed the Flames (3): direct hits +2/4/6% damage to enemies carrying one of your DoTs.
- Last Ember (2): a DoT that runs its full time deals a final tick at 50/100%.
- Tempered (3): each block gives 2/4/6% Armor for 8 s, stacking 3 times.
- Still open: whether existing talents should be removed to make room.

## Utility (the book's "Utility" divider) - BUILT 2026-10-17
- Cooling Slag (Fire's root) - 1.5 s cast, 20 s cooldown, 2 mana, 30 m. Molten slag within 5 m of the target: enemies in it 30% slower; after 2 s it hardens and roots enemies still inside for 3 s. Code: scripts/player/utility.gd.
- Bellows - instant, 25 s cooldown, 2 mana, card level 16. Enemies within 6 m are thrown 8 m away (bosses too heavy); a stack of Heat per enemy thrown, up to 3 (Forge Heat). The game's only knockback. Moved from Nature (was Overgrowth). Code: scripts/player/utility.gd.
- Also in Utility (coded with their specs): Furnace Breath, Cinder Step, Heat Sink, Cinderwing.
