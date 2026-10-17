# Fire book

Values in Frost Bolts (FB) are conversation shorthand; real numbers live in balance.gd.

## Identity
Built around critical strikes, specifically around trying to AVOID crits: non-crits are rewarded, low crit can be stronger.

## Caster
- Fireball - stays in the game.
- Vent Flames - instant, 10 s cooldown, 2 FB, guaranteed crit, extra damage equal to 50% of your crit chance.
- Cool Head - instant, 2 min cooldown, 15 s: Fire spells and abilities can't crit; each damaging one gives 1 Concentrated Fire. When it ends, next Fire spells/abilities with a cast time are instant, 1 cast per stack; the buff stays 5 s after Cool Head ends.
- Furnace Breath - close-range cone AoE spell; the Fire interrupt.
- Stoke, Ember Volley (Cool Head can make it instant).
- Immolate - Fire DoT with a cast time; cast again on the same target spreads it to 2 others.
- Wall of Fire - 20 s cooldown.
- Crucible - 1.5 s cast, ground circle: +15% periodic Fire damage to enemies inside for 10 s; recast within 10 s is instant and moves it. Own-only.
- Cinder Step - short dash leaving a burning line; next cast-time Fire spell castable while moving.
- Heat Sink - 6 s defensive: part of damage taken is stored, then released as a fire burst.
- Slag Skin - defensive: more armor, damages attackers.

## Tank (Slag, shield)
- Slag Skin (tank version) - instant, 15 s duration, 13 s cooldown (must be maintained). Melee hits that don't crit add armor stacks; a crit shatters them for Fire damage around you.
- Brand - rage-building high-threat strike; branded enemy deals less damage to you.
- Cinder Guard - rage spender: 6 s more block; each block burns the attacker and extends Slag Skin.
- Anvil - shield slam, AoE Fire threat, never crits (always adds Slag).

## Melee DPS (Heat)
- Immolate the target, then weapon hits build Heat: +4% Fire damage to abilities (not spells) per stack. Crit has no interaction with Heat. Heat falls off after 3 s without a new stack.
- Searing Strike - builder, 2 Heat on a burning target.
- Quench - finisher: removes all Heat, +25% per Heat, can't crit, needs 3 Heat.
- Flare - AoE, costs 3 Heat, spreads Immolate.

## Talents
- Fireball talent (row 1, 2 ranks): Fireball gains 40/60% less of your crit chance but deals bonus damage equal to 10/20% of your crit chance.
- Generic rows 1-2: Flash Point, Forge-Hardened, Lingering Embers, Controlled Burn.
- Cool Under Fire (row 3, 2): 10/20% less damage during Cool Head.
- Pressure Valve (2): non-crit Fire spells take 0.25/0.5 s off Vent Flames' cooldown.
- Flashover (3): Slow Fuse explosion spreads Immolate, 10/20/30% per enemy.
- Ember Volley talent: hits 1/2 more targets.
- Smoldering Focus (bottom row, 5 ranks; was a rune, damage bonus lowered 10% and split across ranks).
- Opposite of Smoldering Focus (to its right): crits give bonus damage on your next non-critical spell, scaling from 100 minus your crit chance.
- Banked Coals (bottom row, middle slot).
- Tank: Thick Slag (3), Smoldering Debris (2, was Clinker): shattered Slag leaves a burning patch, 10/20%, uses normal crit chance; Hot Iron (4): blocks deal more retaliation damage.
- Melee: Kindling (2): Searing Strike 15/30% chance for 1 extra Heat. Afterglow (2): for 4 s after Quench auto-swings deal 10/20% more Fire damage. A 3-rank talent: abilities 10/20/30% chance to add 1 s to your active Immolate, capstone 2 s, up to its base duration.

## Runes
- Epic Dull Edge: crit chance capped at 10%, the excess becomes Attack Power.
- Epic Dull Mind: the Spell Power version.
- Epic Hair Trigger: Vent Flames has 2 charges.
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
