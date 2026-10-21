# Frost book

Values in Frost Bolts (FB) are conversation shorthand; real numbers live in balance.gd. Older Frost decisions predate these notes; the code is the source of truth.

## Core mechanics
- Chilled: slow applied by Frost spells.
- Frozen: 80% move-speed slow for 3 s. Exploding a Frozen target (shatter) was halved and uses the AoE split past 5 targets.
- Rime Shell: +30% damage on a single enemy; its debuff applies to damage from everyone (the one exception to own-only). Shatter works the same on enemies and allies.
- Weakened Soul: target is immune to Rime Shell and any future ability that applies Weakened Soul.
- Winter's Bite: every third one freezes (3-stack buff, 20 s).
- Ray of Frost is removed.

## Caster
- Frost Bolt - the reference unit (1.0 FB).
- Ice Shards - instant, max 5 charges (1 per 20 s, +1 per Frost spell cast, none gained while firing), fires one 0.2 FB shard per charge, 0.4 s apart.
- Frostfire Bolt - taught by a Rare rune: Frost Bolt damage, 50% fire / 50% frost, procs both sides, benefits from anything boosting Frost Bolt or Firebolt.

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
- Winter's Bite - builder now (+20 Fury, was 30 Fury cost), 1.5 weapon, 6 s; every 3rd Freezes; +1 Glaze on a cold target.
- Hoarcleave - 1.0 weapon to the target and within 3 m, 6 s, +15 Fury, Chills; 1 Glaze per cold enemy hit, up to 2.
- Calving - finisher, 30 Fury, 10 s, 1.0 weapon to the target and within 5 m, Chills; needs 1 Glaze, +12% per Glaze.
- Icebreaker - finisher, 30 Fury, 8 s, 2.0 weapon (3.5 on your Frozen target, ends it); +10% per Glaze.
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
- Rimelock (interrupt), Flash Freeze, Winter Hide, Ice Barrier, Snow Ward. Icepin (Frost's root) and Icy Retreat stay in Winter Hunt: they need a bow. Cold Comfort is left with Rime Shell alone.

## Talents
- First talents: haste 1/2/3%; Frost spell slows +5/10/15%; shield absorbs +5/10/15%; spells 10/15/20% chance to generate an Ice Shard (requires Ice Shards).
- Bow talents, grouped together on the right of rows 1-5: Black Ice, Thin Ice (3, requires Glacial Draw: 0.3/0.7/1 s faster on a Chilled target), Clean Shatter, Cold Harvest, Marked Prey (3, requires Coldmark: Ice Shards +10/20/30% to your Coldmark target), Cold Draw.
- Also in the tree: Quickened Frost, Pinning Frost, Bitter Cold, Deep Hoarfrost, Third Bite.
- Removed: Winter's Clarity, Endless Winter, Deep Chill (points refunded via save migration).
- Melee (2026-10-21; new slots, nothing moved, no migration). DPS left of the middle: Cold Sweep (r3, Hoarcleave: 10/20/30% to Freeze an already Chilled enemy instead), Ice Fall (r8, Calving: +4/8/12% on its target per other enemy hit, up to 4), Long Dark (r9, Black Frost +1.5/2.5/4 s), Glinting Rime (r10, 5 ranks: +0.2..1% crit per Glaze for Frost abilities; capstone: an Icebreaker spending 5 Glaze always crits). Tank right of it: Cold Fury (r1 middle, +2/4/6 Fury per Layer broken), Turned Backs (r2 middle, 2 ranks, Cold Shoulder: the 1/2 nearest enemies too), Packed Ice (r3, Shattering Slam: +13/27/40% per Layer), Regelation (r8, Hard Rime: +3/7/10 Fury per Layer re-formed), Old Ice (r9, Glacial Bulwark +1.5/2.5/4 s), Deep Strata (r10, 5 ranks: Layers +2..10%; capstone: the last Layer breaking gives one back, once per 20 s). Still DPS: Honed Rime, Third Bite, Clean Break.
- Rows 6 and 7 can't grow (Cold Snap -> Frozen Instinct and the shield line down the right edge run through their free slots); r8c4 stays empty (Thick Hide's folded slot).

## Runes
- 4 Epic Frost runes (built 2026-09-27).
- Rare Frostfire Bolt (teaches the spell).
- Menace (Frost): +30% threat.
- Epic Rune of the Ice Shelf (tank): up to 7 Ice Layers, but breaking ones no longer Chill.
- Epic Rune of the Hoar Blade (DPS): at 5 Glaze, auto-attacks also deal 0.25 FB Frost (own meter line).
- Rare Rune of the Lone Floe (DPS, unique): Calving hits only its target, +40%.

## To check
- Frost has not yet had the open-talent review the other books got.
