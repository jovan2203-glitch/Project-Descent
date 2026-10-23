# Frost book

Values in Frost Bolts (FB) are conversation shorthand; real numbers live in balance.gd. Older Frost decisions predate these notes; the code is the source of truth.

## Core mechanics
- Chilled: slow applied by Frost spells.
- Frozen: 80% move-speed slow for 3 s. Exploding a Frozen target (shatter) was halved and uses the AoE split past 5 targets.
- Rime Shell: on an enemy, more damage taken from everyone (rime_shell_foe in balance.gd, 5% now); the one exception to own-only. Shatter works the same on enemies and allies. Instant on allies (and you), a 2.2 s cast on enemies (2026-10-21).
- Thawing (was Weakened Soul, shown as Frostworn; renamed 2026-10-21): target can't get Rime Shell or anything else that applies Thawing. A rune removes it; no ability or talent shortens it.
- Winter's Bite: every third one freezes (3-stack buff, 20 s).
- Ray of Frost is removed.

## Caster
- Frost Bolt - the reference unit (1.0 FB).
- Ice Shards - instant, max 5 charges (1 per 20 s, +1 per Frost spell cast, none gained while firing), fires one 0.2 FB shard per charge, 0.4 s apart.
- Frostfire Bolt - taught by a Rare rune: Frost Bolt damage, 50% fire / 50% frost, procs both sides, benefits from anything boosting Frost Bolt or Firebolt.

## Healer: Cold Comfort - BUILT 2026-10-21
Code: scripts/player/frost_healer.gd (FrostHealerKit). Numbers: balance.gd (RIME_SHARDS_*, RUNOFF_*, RIME_VEIL_*, LATTICE_*, RIMEFALL_*, FROST_TIDE_TIME, STILLWATER_*; Meltwater in HEALS). Tests: tests/test_frost_healer.gd.
- Identity: a shield healer whose shells pay off when they end. A little damage through shatters (Break the Ice, Splinterheal).
- Rime Shell's picture (scripts/rime_shell_fx.gd, visual only): a pale bubble of ice on you, party members and the training ally, cracking once a third of its shield is gone and again at two thirds, with a flash each time. Party members see it through the shell state sync (Net._sup_state).
- Rime Shell on an ally: breaks -> Rime Shards heal every ally within 8 m for 30% of the shield (split past 5). Runs out unbroken -> Runoff heals them 50% of what was left over 4 s.
- Meltwater - 1.5 s cast, 2 mana, heals 0.9 (old Heals); +30% on an ally with your Thawing. Filler. Card level 2.
- Rime Veil - instant, 2 mana: a 0.2 shield that forms again every 3 s for 12 s; no Thawing. Level 8.
- Break the Ice - instant, 10 s cooldown, 1 mana: breaks your shell on an ally; 80% of what was left heals allies within 8 m (split past 5) and it shatters on enemies. Level 10.
- Frost Lattice - instant, 30 s cooldown, 3 mana: links your target and the nearest allies with your shell (3 in all) for 20 s. A hit on a linked shell is taken from all the linked shells evenly. How: the hit shell soaks the whole hit at once and loses only 1/n of it (StatusContainer.set_share; it can soak up to n times its shield); the rest is billed to the healer's machine and drained evenly from the other linked shells, which can break from it. A shell that breaks or ends leaves the lattice. Level 14.
- Rimefall - 2.5 s cast, 15 s cooldown, 4 mana: every ally within 20 m gets a 0.3 shield for 8 s, +0.1 per ally carrying your shell (up to 3); no Thawing. Level 12.
- Frost Tide - instant, 2 min cooldown: for 10 s Rime Shell ignores Thawing and is instant on enemies too. Level 18.
- Stillwater - instant, 90 s cooldown, 2 mana: only on an ally below 35% health (the anti-troll gate): 3 s no damage and can't act, moving breaks out; then healed 30% of max health. Level 16.
- Spring Thaw - the out-of-combat rez (RezKit). Level 20.
- Talents: see the Talents section (Cold Comfort's column group).

## Tank: Glacier Wall (one-handed melee weapon + shield, Fury) - BUILT 2026-10-21
The absorb tank (Fire blocks, Lightning parries, Arcane dodges). Code: scripts/player/frost_glacier.gd.
- Ice Layers: one absorb shield on you in layers, up to 5 (7 with the Rune of the Ice Shelf), each 4% of max health (Rime Ward, Deep Strata bigger), 20 s, refreshed by gaining one. A hit that breaks a Layer gives 8 Fury and Chills the attacker. Hardened Frost's armor and Ice Floe count for them. Tension: spending Layers buys threat and damage, keeping them buys defence (and Rimequake damage).
- Rime Slash - builder, cone, 1.0 weapon, 3x threat, +20 Fury; 1 Layer, 2 if it hits 3+. No longer gives a Rime Shell.
- Shattering Slam - shield hit, 1.9 weapon (was 1.5; tank rule pass), 6 s, 5x threat (was 3x), +20 Fury; shatters all Layers into the target (0.2 FB each). The old Rime Shell / Freeze shatter on the target stays.
- Cold Shoulder - taunt, off GCD, 8 s, 25 m: 3 s forced attack, Chills, +1 Layer.
- Rimequake - 25 Fury, 8 s, 0.65 FB within 6 m (was 0.5), 4x threat, Chills; +10% per Layer held.
- Hailcoat - 25 s, fills the Layers.
- Hard Rime - 30 Fury, 20 s: for 6 s a Layer that breaks forms again 2 s later.
- Glacial Bulwark - 90 s, off GCD: +3 Layers; for 10 s each Layer that breaks shatters for 0.3 FB within 5 m (4x threat).

## Melee DPS: Frostbitten Steel (two-handed melee weapon, Fury) - BUILT 2026-10-21
Chill, Freeze, break. Code: scripts/player/frost_steel.gd (+ frost_runes_talents.gd for Winter's Bite, frost_more.gd for Rime Edge / Icebreaker).
- Glaze: buff on you, up to 5, 12 s, refreshed by gaining one. Built by Frost hits on a target you had ALREADY Chilled or Frozen (checked before the hit). Icebreaker and Calving spend all of it.
- Winter's Bite - builder now (+20 Fury, was 30 Fury cost), 1.8 weapon (was 1.5), 6 s; every 3rd Freezes; +1 Glaze on a cold target.
- Hoarcleave - 1.2 weapon to the target and within 3 m, 6 s, +15 Fury, Chills; 1 Glaze per cold enemy hit, up to 2.
- Calving - finisher, 30 Fury, 10 s, 1.0 weapon to the target and within 5 m, Chills; needs 1 Glaze, +15% per Glaze.
- Icebreaker - finisher, 30 Fury, 8 s, 2.0 weapon (2.5 on your Frozen target, ends it; was 3.5); +5% per Glaze. Trimmed so a Frozen Icebreaker at 5 Glaze is ~1000 before crits (was ~1690); the damage moved to Winter's Bite, Hoarcleave and Calving.
- Rime Edge - as before; each extra hit on a target you had Chilled: 25% for 1 Glaze.
- Bitter Edge - off GCD, 15 Fury, 6 s, 0.8 weapon, only on a target you have Frozen: Freezes it again (its on-hit effect, so it works in a party), +1 Glaze.
- Black Frost - 2 min: for 12 s every Winter's Bite Freezes (the 3-count is left alone).

## Archery
- Shatter Shot - finisher on a Frozen target.
- Long Draw (Glacial Draw) - cast shot, instant on a rooted/Frozen target.
- Rimefletch - auto-shot buff.
- Coldmark - arrows on the marked target give Ice Shard charges.
- Icy Retreat - backward leap leaving a chilling ice patch.

## Utility (the book's "Utility" divider) - 2026-10-17
- Rimelock (interrupt), Flash Freeze, Winter Hide, Ice Barrier, Snow Ward. Icepin (Frost's root) and Icy Retreat stay in Winter Hunt: they need a bow. Cold Comfort keeps Rime Shell and became the healer (above).

## Talents (column-group tree, 2026-10-23)
The first book with five specs: 11 columns (`Talents.GROUPS`): Hard Winter 1-2, Cold Comfort 3-4, Open 5, Frostbitten Steel 6-7, Glacier Wall 8-9, Winter Hunt 10-11. Rows 1-9 hold two talents per spec (the open column fills rows 1-9, so every row stays symmetrical); row 10 each spec's 5-rank capstone, which needs 25 points in its spec. 104 talents: 19 per spec (56-58 ranks), 9 open; 25 need one ability (24%). No links. Talents.TREE_VERSION 6 -> 7 refunded every point. Code: scripts/player/frost_talents.gd (hit bonuses, Freeze / thaw events, heals and shields) plus each spec's component. Tests: tests/test_frost_tree.gd.
- Keywords (systems.md has the list): Chilled, Frozen (Freezing, thawing), shatters, Ice Shard charges, Hoarfrost, Rime Shell, Rime Shards, Runoff, Thawing, Frost shields (Rime Shell, Rime Veil, Rimefall, Shard Spray), Glaze, finishers (Calving, Icebreaker), Ice Layers, arrows (arrow abilities and auto-shots), roots.
- Hard Winter: Bitter Cold, Glass Cold (Frost spells +3/6/9% on your Frozen), Quickened Frost (R), Frozen Instinct (now any Frost spell with a cast time), Deep Hoarfrost (R), Brittle Rime (R), Splintering Cold (no longer needs Ice Shards), Shardstorm (R), Piercing Cold (R), Ice Needles (Frost spell crits: 33/66/100% for a charge), Splintering (R, 2 ranks: 1/2 enemies), Cold Snap, Snowdrift (+4/8/12% on a target with 2+ other enemies within 8 m), Cold Front (+1/2/3% per enemy you have Chilled or Frozen, up to 5), Lingering Frost, Hard Freeze, Cold Well (Freezing: 0.1/0.2/0.3 mana points, once per 1 s), Shatterpoint. Capstone: Deep Freeze.
- Cold Comfort: Deep Cracks, Shard Spray, Slow Runoff (no longer need Rime Shell), Thaw Water (heals +4/8/12% on your Thawing), Last Shelter (Frost shields +5/10/15% on an ally below 50%), Cold Hands (Frost spells that heal or shield cost 3/6/9% less), Cold Spread (R), Meltdown (your Rime Shell breaking: 0.1/0.2/0.3 mana points, once per 2 s), Long Frost (Rime Veil, Rimefall, Shard Spray +2/4/6 s), Shard Reach (2 ranks, +2/4 m), Wide Lattice (R, 2 ranks), Snowmelt (Runoff 15/30/45% faster, same total), Layered Veil (R, 2 ranks, re-forms 0.5/1 s sooner), Ice Bath (heals +3/6/9% on an ally with your Frost shield), Deep Snow (R, Rimefall +10/20/30%), Cold Rush (0.1/0.2/0.3 s faster casts on an ally below 50%), Close Weave (R, heals +5/10/15% on linked allies), Splinterheal. Capstone: Frozen Hearth (Frost shields and Rime Shards +2..10%).
- Open: Frozen Focus, Frozen Mind, Rime Ward, Hardened Frost, Ice Floe, Numbing Cold, Glacial Heart, Cold Discipline, Winter Coat (new: 1/2/3% less damage from spells).
- Frostbitten Steel: Sharp Glaze (Frost abilities +1/2/3% per Glaze), Third Bite (now any Frost ability that Freezes: +20/40/60%), Long Glaze, Glaze Hunger (10/20/30% for one more Glaze), Cold Sweep (R), Hard Glaze (2/4/6 Fury per Glaze a finisher spends), Honed Rime (R), Clean Break (now every finisher on your Frozen), Ice Fall (R), Splitting Cold (finishers +4/8/12% on your Frozen), Biting Hold (R), Shiver (crits on your Frozen: a Glaze, once per 2 s), Rime Grip (auto-attacks on your Chilled +1/2/3 Fury), Cold Swing (melee abilities hitting 2+: 3/6/9 Fury), Long Dark (R), Thaw Strike (a Freeze of yours ending: next finisher within 10 s costs 5/10/15 less), Quick Rime (0.3/0.6/0.9% attack speed per Glaze), Frost Heave (a 5-Glaze finisher: 33/66/100% to Freeze). Capstone: Glinting Rime.
- Glacier Wall: Packed Ice (R), Cold Fury, Lasting Ice (Layers +3/6/9 s), Deep Ice (2 ranks, +1/2 Layers), Deep Tremor (R), Spent Ice (2/4/6 Fury per Layer Shattering Slam spends), Hoar Coat (each Layer gained heals 0.3/0.6/1% max health), Cold Retort (a Layer breaking hits the attacker; own meter line), Turned Backs (R), Rime Pressure (+1/2/3% threat per Layer), Regelation (R), Reforming (5/10/15% for a broken Layer to form again), Cracking Ice (each Layer breaking: 0.1/0.2/0.3 s off your Frost abilities' cooldowns), Steady Footing (3+ Layers: 2/4/6% less damage taken), Old Ice (R), Rime Armor (+1/2/3% Armor per Layer), Chilling Presence, Full Strata (all Layers up: abilities +5/10/15%). Capstone: Deep Strata.
- Winter Hunt: Cold Draw, Frozen Quarry (was Marked Prey: arrows +4/8/12% on your Frozen), Pinning Frost (now arrows on any target you rooted: +5/10/15%), Black Ice (R), Clean Shatter (R), Frost Fletching (auto-shots +3/6/9% on your Chilled), Cold Harvest (R), Rime Tips (auto-shots 5/10/15% to Chill), Thin Ice (R), Marked Ice (arrow abilities on your Chilled: 10/20/30% for a charge), Winter Quiver (arrow ability crits: 4/8/12 Energy), Splitting Arrow (arrows on your Frozen: 10/20/30% to one more enemy; own meter line), Deep Pin (roots +1/2/3 s), Numb Prey (auto-shots +3/6/9% on your Frozen), Swift Ice (auto-shots and auto-attacks 2/4/6% faster on your Chilled), Ice Hunger (Freezing: 5/10/15 Energy), Cold Eye (arrow crits on your Frozen +5/10/15%), Sleet Arrows (2 ranks: arrow abilities that Chill also Chill the 1/2 nearest enemies). Capstone: Bitter Hunt (arrows +1..5% per slow of yours on the target).
- Known: Hardened Frost's armor on Ice Layers counts once per Layer held (the Layers are one effect with stacks); Rime Armor works the same way on purpose.

## Runes
- 4 Epic Frost runes (built 2026-09-27).
- Rare Frostfire Bolt (teaches the spell).
- Menace (Frost): +30% threat.
- Epic Rune of the Ice Shelf (tank): up to 7 Ice Layers, but breaking ones no longer Chill.
- Epic Rune of the Hoar Blade (DPS): at 5 Glaze, auto-attacks also deal 0.25 FB Frost (own meter line).
- Rare Rune of the Lone Floe (DPS, unique): Calving hits only its target, +40%.

## To check
- The "Frostbitten Steel" group name over two narrower columns (11-column grid): check it fits.
