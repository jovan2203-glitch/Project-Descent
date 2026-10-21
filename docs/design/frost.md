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
Code: scripts/player/frost_healer.gd (FrostHealerKit). Numbers: balance.gd (RIME_SHARDS_*, RUNOFF_*, GLAZE_*, LATTICE_*, RIMEFALL_*, FROST_TIDE_TIME, STILLWATER_*; Meltwater in HEALS). Tests: tests/test_frost_healer.gd.
- Identity: a shield healer whose shells pay off when they end. A little damage through shatters (Break the Ice, Splinterheal).
- Rime Shell's picture (scripts/rime_shell_fx.gd, visual only): a pale bubble of ice on you, party members and the training ally, cracking once a third of its shield is gone and again at two thirds, with a flash each time. Party members see it through the shell state sync (Net._sup_state).
- Rime Shell on an ally: breaks -> Rime Shards heal every ally within 8 m for 30% of the shield (split past 5). Runs out unbroken -> Runoff heals them 50% of what was left over 4 s.
- Meltwater - 1.5 s cast, 2 mana, heals 0.9 (old Heals); +30% on an ally with your Thawing. Filler. Card level 2.
- Glaze - instant, 2 mana: a 0.2 shield that forms again every 3 s for 12 s; no Thawing. Level 8.
- Break the Ice - instant, 10 s cooldown, 1 mana: breaks your shell on an ally; 80% of what was left heals allies within 8 m (split past 5) and it shatters on enemies. Level 10.
- Frost Lattice - instant, 30 s cooldown, 3 mana: links your target and the nearest allies with your shell (3 in all) for 20 s. A hit on a linked shell is taken from all the linked shells evenly. How: the hit shell soaks the whole hit at once and loses only 1/n of it (StatusContainer.set_share; it can soak up to n times its shield); the rest is billed to the healer's machine and drained evenly from the other linked shells, which can break from it. A shell that breaks or ends leaves the lattice. Level 14.
- Rimefall - 2.5 s cast, 15 s cooldown, 4 mana: every ally within 20 m gets a 0.3 shield for 8 s, +0.1 per ally carrying your shell (up to 3); no Thawing. Level 12.
- Frost Tide - instant, 2 min cooldown: for 10 s Rime Shell ignores Thawing and is instant on enemies too. Level 18.
- Stillwater - instant, 90 s cooldown, 2 mana: only on an ally below 35% health (the anti-troll gate): 3 s no damage and can't act, moving breaks out; then healed 30% of max health. Level 16.
- Spring Thaw - the out-of-combat rez (RezKit). Level 20.
- Talents: Deep Cracks (r1c4, Rime Shards +10/20/30%) -> Shard Spray (r2c4, Rime Shards leave a 3 s shield of 20/35/50% of their heal); Slow Runoff (r9c1, Runoff +20/40/60%, capstone: a mana point back per Runoff); Cold Spread (r9c7, Break the Ice reaches 2/4/6 m farther); Splinterheal (r10c1, your shatters heal the lowest ally within 10 m of the enemy for 20/35/50% of the damage); Wide Lattice (r10c7, 1 rank: one more ally linked).

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

## Runes
- 4 Epic Frost runes (built 2026-09-27).
- Rare Frostfire Bolt (teaches the spell).
- Menace (Frost): +30% threat.

## To check
- Frost has not yet had the open-talent review the other books got.
