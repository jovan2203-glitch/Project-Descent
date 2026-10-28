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
- Flicker - instant, 15 s cooldown, 30 energy, 10 m blink; next Lightning Bolt within 5 s is instant; blocked during Grounding Surge. Pressed again within 4 s (FLICKER_RETURN_TIME) it snaps you back to where you started, free (the bolt there and back: what sets it apart from Phase Step). Sits in Utility.
- Capacitor - instant off GCD, 30 s cooldown, stores all energy up to 100; reuse within 20 s to take it back or it is lost.

## Parry tank (two-handed weapon, energy)
- Stormbreak - builder and filler, no cooldown, +15 energy, 1.0 weapon damage, arcs to 3 enemies for 0.2 FB, high threat.
- Humming Blade - 15 s stance on a 12 s cooldown: +10% Parry, Parry cap 45% instead of 30%, each parry gives 10 energy.
- Return Stroke - within 4 s of a parry, off GCD, 15 energy, 1.0 weapon damage (was 1.2; tank rule pass), high threat.
- Shock Ring - 8 s cooldown, 30 energy, 0.5 FB within 6 m, high threat.
- Crossguard - 25 s cooldown, 40 energy, 3 s of parrying every parryable attack.
- Draw the Storm - 90 s cooldown, 8 s: enemies within 8 m forced to attack you for 3 s; each parry zaps enemies within 6 m for 0.3 FB.
- Reflex Arc - counts as both a parry and a block.
- Two-handed weapon: Iron Greatsword (drops from zombie/elite/boss tables, granted to every character).

## Melee
- Lightning melee kit exists (tests: test_lightning_melee). Not recorded in detail here; check the code.

## Talents (ribbon tree, 2026-10-26)
Layout: 13 columns. Live Current 0-2 (storm cloud), Stormdancer 3-5 (twin bolts), the open talents on the spine (6), Lightning Rod 7-9 (lightning rod), Stormstring 10-12 (short ribbon: its three Storm Arrow talents in rows 1-3, no shape or capstone until the bow is built; Talents.UNFINISHED_SPECS). Each finished spec: 18 talents in rows 1-9 and a 5-rank capstone gated at 25 points. Numbers: talents.gd and balance.gd; code: scripts/player/lightning_talents.gd and each spec's component.
- Keywords: Energy gained and spent, spending all of it (Discharge, Ground Out, Recharge), leaps and forks, lingering lightning (Ball Lightning, Thunderhead, Live Wire), Grounding Surge, cast spells, full Energy; auto-attacks, Energy builders, low Energy, Lightning weapon abilities (Lightning abilities that swing a weapon); parries, two-handed weapon, arcs, hits on everything around you, enemies forced to attack you, low health.
- Live Current: Long Leap, Charged Air, Quick Fuse (Lightning Bolt), Deep Reserves, Tight Coil (Ball Lightning), Feedback, Lingering Storm, Crackle, Conductive -> Conductor (link), High Voltage, Deep Draw -> Afterflow (link), Standing Charge (Grounding Surge), Overflow (Capacitor), Parting Spark (Flicker), Snap Cast, Full Circuit. Capstone: Storm Cycle.
- Stormdancer: Charged Strikes, Quick Charge, Keen Current, Edge Current, Whip Crack (Whiplash), Third Beat (Cadence), Running Start (Static Step), Sparking Swings, Running on Empty, Afterspark -> Light Load (link), Built Charge -> Spinning Up (link), Redline (Overdrive), Hot Wire (Twin Current), Charged Steel, Short Fuse, Calm Current. Capstone: Storm Dance (Lightning weapon abilities +2-10%; maxed, Overdrive's zaps hit a second enemy).
- Lightning Rod: Long Reach, Spark Guard, Closed Circuit (Humming Blade), Loud Steel, Quick Wrists (Crossguard), Counter-Charge -> Second Stroke (link, both Return Stroke), Charged Guard, Earth Return -> Tempo (link), Draw Down, Ring True, Hard Lessons, Wide Current, Charged Shell, Hard Stare, Eye of the Storm (Draw the Storm), Back to the Wall. Capstone: Storm Anchor (+1-5% Parry; maxed, every 5th parry sets off a free Shock Ring).
- Open (spine): Quick Pulse, Change of Pace, Storm-Tempered, Spillover, Quick Step, Dig In, Cut the Line (an interrupt gives Haste), Fresh Charge (above 90% health), Static Build (moving builds damage for the next spell or ability: the opposite of Dig In).

## Runes
- Epic Static/Overload: Lightning builds Static, up to 15 stacks at 2.5% damage each; reaching the cap Overloads. Not casting Lightning for 3 s makes you immune to overloading for the next 10 s (Lightning 10 s, something else 3 s, Lightning again, keeping stacks).
- Rare Afterimage (shared with Arcane): Phase Step or Lightning's blink leaves an image for 4 s; next spell also cast by it at 50%.
- Menace (Lightning): +30% threat.

## Utility (the book's "Utility" divider) - BUILT 2026-10-17
- Static Snare (Lightning's root) - instant, 20 s cooldown, 20 Energy, 30 m. Roots the target 2 s; when it ends, the charge leaps once to the nearest other enemy within 8 m and roots it 2 s. Code: scripts/player/utility.gd.
- Storm Front - instant, 60 s cooldown, 20 Energy, card level 22. You and allies within 15 m move 30% faster for 6 s; you gain 5 Energy per ally it reaches. Moved from Nature (was Wild Run). Code: scripts/player/utility.gd.
- Also in Utility (coded with their specs): Jolt, Flicker, Static Step, Thunder Strike, Faraday Guard, Ground Out, Recharge.
