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
- Talents: Deep Cracks (r1c4, Rime Shards +10/20/30%) -> Shard Spray (r2c4, Rime Shards leave a 3 s shield of 20/35/50% of their heal); Slow Runoff (r9c1, Runoff +20/40/60%, capstone: a mana point back per Runoff); Cold Spread (r9c7, Break the Ice reaches 2/4/6 m farther); Splinterheal (r10c1, your shatters heal the lowest ally within 10 m of the enemy for 20/35/50% of the damage); Wide Lattice (r10c7, 1 rank: one more ally linked).

## Tank: Glacier Wall (one-handed melee weapon + shield, Fury) - BUILT 2026-10-21
The absorb tank (Fire blocks, Lightning parries, Arcane dodges). Code: scripts/player/frost_glacier.gd.
- Ice Layers: one absorb shield on you in layers, up to 5 (7 with the Rune of the Ice Shelf), each 4% of max health (Rime Ward, Deep Strata bigger), 20 s, refreshed by gaining one. A hit that breaks a Layer gives 8 Fury and Chills the attacker. Hardened Frost's armor and Ice Floe count for them. Tension: spending Layers buys threat and damage, keeping them buys defence (and Rimequake damage).
- Rime Slash - builder, cone, 1.0 weapon, 3x threat, +20 Fury; 1 Layer, 2 if it hits 3+. No longer gives a Rime Shell.
- Shattering Slam - shield hit, 1.5 weapon, 6 s, 3x threat, +20 Fury; shatters all Layers into the target (0.2 FB each). The old Rime Shell / Freeze shatter on the target stays.
- Cold Shoulder - taunt, off GCD, 8 s, 25 m: 3 s forced attack, Chills, +1 Layer.
- Rimequake - 25 Fury, 8 s, 0.5 FB within 6 m, 4x threat, Chills; +10% per Layer held.
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

## Talents
- First talents: haste 1/2/3%; Frost spell slows +5/10/15%; shield absorbs +5/10/15%; spells 10/15/20% chance to generate an Ice Shard (requires Ice Shards).
- Bow talents, grouped together on the right of rows 1-5: Black Ice, Thin Ice (3, requires Glacial Draw: 0.3/0.7/1 s faster on a Chilled target), Clean Shatter, Cold Harvest, Marked Prey (3, requires Coldmark: Ice Shards +10/20/30% to your Coldmark target), Cold Draw.
- Also in the tree: Quickened Frost, Pinning Frost, Bitter Cold, Deep Hoarfrost, Third Bite.
- Cold Comfort's six (see the healer section) took new mirror-symmetric slots: the middle of rows 1-2, both edges of rows 9-10. New slots only: no save migration.
- Removed: Winter's Clarity, Endless Winter, Deep Chill (points refunded via save migration).
- Melee (2026-10-21). DPS left of the middle: Cold Sweep (r3c3, Hoarcleave: 10/20/30% to Freeze an already Chilled enemy instead), Biting Hold (r6c2, 2 ranks, Bitter Edge: +1/2 Glaze), Long Glaze (r7c3, Glaze +2/4/6 s), Ice Fall (r8c3, Calving: +4/8/12% on its target per other enemy hit, up to 4), Long Dark (r9c3, Black Frost +1.5/2.5/4 s), Glinting Rime (r10c2, 5 ranks: +0.2..1% crit per Glaze for Frost abilities; capstone: an Icebreaker spending 5 Glaze always crits). Tank right of it: Cold Fury (r8c4 middle, +2/4/6 Fury per Layer broken), Packed Ice (r3c5, Shattering Slam: +13/27/40% per Layer), Deep Tremor (r6c6, Rimequake: 13/17/20% per Layer instead of 10%), Turned Backs (r7c6, 2 ranks, Cold Shoulder: the 1/2 nearest enemies too), Regelation (r8c5, Hard Rime: +3/7/10 Fury per Layer re-formed), Old Ice (r9c5, Glacial Bulwark +1.5/2.5/4 s), Deep Strata (r10c6, 5 ranks: Layers +2..10%; capstone: the last Layer breaking gives one back, once per 20 s). Still DPS: Honed Rime, Third Bite, Clean Break.
- To make room, Frozen Instinct moved from r7c6 to r7c5, straight under Cold Snap: their diagonal link ran through the free slots of rows 6 and 7. Save version 11 -> 12 (Talents.FROST_MELEE_MOVED) carries its points.
- Merging the healer and the melee rework: both had taken r1c4, so Cold Fury moved to r8c4 (Thick Hide's folded slot; its old points were refunded in save version 10 -> 11, so none carry over) and Deep Cracks kept r1c4. Rows 9 and 10 hold all 7 columns, so Talents.MAX_PER_ROW is 7.

## Runes
- 4 Epic Frost runes (built 2026-09-27).
- Rare Frostfire Bolt (teaches the spell).
- Menace (Frost): +30% threat.
- Epic Rune of the Ice Shelf (tank): up to 7 Ice Layers, but breaking ones no longer Chill.
- Epic Rune of the Hoar Blade (DPS): at 5 Glaze, auto-attacks also deal 0.25 FB Frost (own meter line).
- Rare Rune of the Lone Floe (DPS, unique): Calving hits only its target, +40%.

## To check
- Frost has not yet had the open-talent review the other books got.
