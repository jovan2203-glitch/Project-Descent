# Lightning book

Values in Frost Bolts (FB) are conversation shorthand; real numbers live in balance.gd.

## Caster (energy, 100/100)
- Lightning Bolt - spends 15 energy.
- Chain Lightning - 1.5 s cast, 6 s cooldown, 1.6 FB, jumps to 3 enemies; with one target the jumps return to it at 40%; regains 60 energy.
- Discharge - 2 s cast, 6 s cooldown, spends all energy, 0.3 FB per 10 energy.
- Ball Lightning - 2 s cast, slow orb zapping nearby enemies every 0.5 s; each zap regains 2 energy.
- Ground Out - defensive, instant, 6 s cooldown, spends all energy for a shield.
- Grounding Surge - instant, off GCD, can't move for 15 s, recast to cancel; energy costs -50%; a spend-all spell counts as spending all but removes 50% less. No scaling section.
- Arc Flash - instant AoE spender, 8 s cooldown, 40 energy, 0.8 FB within 6 m.
- Live Wire - 1.5 s cast, 20 energy, 10 s tether, 0.2 FB per second, 3 energy per tick, breaks past 25 m, only one up.
- Thunderhead - 2 s cast, 20 s cooldown, 50 energy, 5 m storm cloud for 8 s striking one random enemy per second for 0.5 FB.
- Forked Bolt - 2 s cast, 25 energy, 0.9 FB to the target and nearest other enemy (1.3 with one target).
- Jolt - instant off-GCD interrupt, 3 s lockout, shared interrupt cooldown, 30 energy back if it interrupts.
- Flicker - instant, 15 s cooldown, 30 energy, 10 m blink; next Lightning Bolt within 5 s is instant; blocked during Grounding Surge.
- Capacitor - instant off GCD, 30 s cooldown, stores all energy up to 100; reuse within 20 s to take it back or it is lost.

## Parry tank (two-handed weapon, energy)
- Stormbreak - builder, 6 s cooldown, +25 energy, 1.0 weapon damage, arcs to 3 enemies for 0.2 FB, high threat.
- Humming Blade - 15 s stance on a 12 s cooldown: +10% Parry, Parry cap 45% instead of 30%, each parry gives 10 energy.
- Return Stroke - within 4 s of a parry, off GCD, 15 energy, 1.2 weapon damage, high threat.
- Shock Ring - 8 s cooldown, 30 energy, 0.5 FB within 6 m, high threat.
- Crossguard - 25 s cooldown, 40 energy, 3 s of parrying every parryable attack.
- Draw the Storm - 90 s cooldown, 8 s: enemies within 8 m forced to attack you for 3 s; each parry zaps enemies within 6 m for 0.3 FB.
- Reflex Arc - counts as both a parry and a block.
- Two-handed weapon: Iron Greatsword (drops from zombie/elite/boss tables, granted to every character).

## Melee
- Lightning melee kit exists (tests: test_lightning_melee). Not recorded in detail here; check the code.

## Talents
- Tank: Counter-Charge (3): Return Stroke +10/20/30%, capstone arcs to 2 enemies for 0.3 FB. Closed Circuit (2): parries during Humming Blade give 3/6 more energy. Quick Wrists (2): each parry takes 0.5/1 s off Crossguard. Long Reach (3, generic): +1/2/3% Parry with a two-handed weapon.

## Runes
- Epic Static/Overload: Lightning builds Static, up to 15 stacks at 2.5% damage each; reaching the cap Overloads. Not casting Lightning for 3 s makes you immune to overloading for the next 10 s (Lightning 10 s, something else 3 s, Lightning again, keeping stacks).
- Rare Afterimage (shared with Arcane): Phase Step or Lightning's blink leaves an image for 4 s; next spell also cast by it at 50%.
- Menace (Lightning): +30% threat.

## Not built yet (picked open talents)
- Spillover (3): a direct crit sends 5/10/15% of its damage to another enemy within 6 m.
- Change of Pace (3): using a different spell/ability than the last gives 1/2/3% damage for 6 s, stacking 3 times; repeating resets it.
- Dig In (3): after standing still 2 s, +2/4/6% damage until you move.
