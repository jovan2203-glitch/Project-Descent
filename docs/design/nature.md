# Nature book

Values in Frost Bolts (FB) are conversation shorthand; real numbers go in balance.gd. Mana in points, as in Holy.

## The wipe (2026-10-16)
- The old placeholder abilities Wrath, Insect Swarm, Entangling Roots and Regrowth (WoW names) are removed. The book is rebuilt from this file, caster DPS first.

## Caster (the Weaver) - spec "Thornweaver" - BUILT 2026-10-16
Code: player.gd, "Nature caster: the Weaver". Numbers: balance.gd (MULCH_*, THORNBURST_*, MOSSBACK_*, VIPERS_*, ...). Pictures: scripts/mulch_patch.gd, scripts/nature_creature.gd (placeholder bodies from simple meshes). Hold effect: data/effects/choked.tres. Tests: tests/test_nature.gd.
- Theme: you weave creatures out of vines and grow them out of the ground. Each creature appears for one strike, then is gone. No pets.
- Woven (fast creatures): vines shoot from your hand, braid together halfway and become the creature, which lunges and hits, then unravels into falling vines and leaves.
- Rooted (heavy creatures): roots burst from the ground at the mulch, grow into the creature, it strikes, then it sinks back into mud.
- Art: one shared bark material with glowing green-gold veins (bright in dark dungeons). Every creature grows in (scale 0 to 1) and out the same way. Vines are thin stretched cylinders. Bodies are placeholders built in nature_creature.gd, swap-ready for real models with one ~0.5 s strike animation each. The hit lands on a timer matching the picture (WOVEN_STRIKE_DELAY 0.45 s, ROOTED_STRIKE_DELAY 0.35 s).

### Mulch
- Woven creatures leave 1 patch of mulch on the ground where they hit. Every 3rd Thornshot that lands also leaves a patch.
- Up to 5 patches (a 6th replaces the oldest), 20 s each. Own-only: the party sees them faint. Greenwood Stag sets them down in a ring around the target; each keeps its time.
- Finishers use every patch within 8 m of their target and scale with how many they use.

### Kit (FB; mana in points)
- Unlock levels (Skill Cards): Thornshot 2, Briar Tiger 4, Mossback 6, Thornwing 8, Choking Vipers 10, Greenwood Stag 12. Ranges 30 m.
- Thornshot - 1.5 s cast, 1.0 FB, 1 mana. A spray of thorns from your hand; every 3rd that lands leaves a patch. Thornburst: when it lands, thorns also burst from every patch within 8 m of the target, dealing 0.4 FB to each enemy within 4 m of a patch (each enemy hit at most once per cast, split past the AoE cap, its own meter line "Thornburst").
- Briar Tiger - 1.5 s cast, 6 s cooldown, 1.5 FB, 2 mana, 1 patch. Woven.
- Thornwing - instant, 10 s cooldown, 1.0 FB, 2 mana, 1 patch. Woven hawk, dives from above (ignores line of sight), usable while moving.
- Mossback - instant, 2 mana, uses nearby mulch: 0.6 FB + 0.6 FB per patch (3.6 FB at 5). Rooted bear, single target.
- Choking Vipers - instant, 3 mana, uses nearby mulch: vipers coil around every enemy within 8 m for 0.4 FB + 0.4 FB per patch over 3 s (2.4 FB at 5), split past the AoE cap, and hold each in place for 0.5 s (they can still cast and attack; never interrupts). A DoT: benefits from crit and haste.
- Greenwood Stag - instant, 15 s cooldown, 0.5 FB, 1 mana. Grows from your mulch, bounds to your target and carries every patch there. Uses up nothing.
- Finisher targeting: pressing Mossback or Choking Vipers with the mouse over a legal enemy (mouseover casting) uses the patches within 8 m of that enemy. Otherwise an 8 m circle appears; click to place it on the patches to use (Mossback still strikes your target; Choking Vipers hits the enemies inside the circle; no enemies inside = keep aiming). Pressing it again puts the circle away.
- Readability: a Mulch buff on you (one stack per patch, no timer) and the patch count on the Mossback and Choking Vipers buttons. Their tooltips show the damage with your current patches and with 5.

### Talents (Nature tree)
- Hunting Party (4, requires Briar Tiger; row 1, column 5): Briar Tiger deals 5/10/15% more damage; capstone: every second Briar Tiger also strikes 2 more enemies within 8 m of the target and leaves a patch under each.
- Rich Soil (3; r3c5): each patch adds 10/20/30% more to Mossback and Choking Vipers (only the per-patch part).
- Compost (1, Thornshot; r5c5): every 2nd Thornshot that lands leaves a patch, instead of every 3rd. Maxing it opens Bramble Burst.
- Bramble Burst (3, Thornshot; r6c5): Thornburst deals 10/20/30% more; capstone: it reaches 5 m from each patch instead of 4.
- Fertile Ground (2, Choking Vipers; r7c6): an enemy that dies with my Vipers on it leaves a patch where it fell: 50/100% chance.
- Second Growth (2, Mossback; r8c5): 15/30% chance Mossback leaves a patch where it strikes.
- Circling Hawk (2, Thornwing; r8c6): a finisher that uses 4+ patches cuts Thornwing's cooldown by 3/6 s.
- Overgrown (5; r10c5): my Nature spells deal 0.4/0.8/1.2/1.6/2% more per patch I have (10% at 5).

## Healer (the Shepherd) - spec "Shepherd" - BUILT 2026-10-16
Code: player.gd, "Nature healer: the Shepherd". Numbers: balance.gd (BLOSSOM_*, FAWN_*, ROOTGUARD_*, OWL_*, ELK_*, FULL_BLOOM_*, WILD_HERD_*; heals in HEALS). Pictures: scripts/nature_creature.gd (fawn, owl, roots, elk). Tests: tests/test_nature.gd.
- The Weaver's healing twin: woven creatures (vines from the hand) heal and leave Blossoms; rooted creatures (grown from the ground) use them up. Pure healer: its only damage is the Owl's strike.
- Note: "Shepherd" is also a Pact's name (Pact of the Shepherd); kept for now.

### Blossom
- A buff on an ally: up to 3, 20 s; a new one starts the time of all of them over. Woven heals leave 1, or 2 when the heal is more than the ally was missing. Own-only: only my rooted creatures use mine.

### Kit (heals in old Heals: 1.0 = one Psalm; mana in points)
- Unlock levels: Dewfall 2, Fawn 4, Rootguard 6, Owl 8, Heartwood Elk 10, Wild Herd 12. Range 40 m.
- Dewfall - 1.5 s cast, 2 mana. Heals 1.0, +10% per Blossom on the target (uses none). Filler, not a creature.
- Fawn - 1.5 s cast, 8 s cooldown, 3 mana. Woven chain heal: 1.0 on the target, then bounces 3 times, each to the lowest-health ally within 12 m not yet healed, each bounce x0.8. A Blossom on each.
- Rootguard - instant, 15 s cooldown, 2 mana. Rooted: roots wrap the ally in a shield of 0.8 + 0.4 per Blossom (uses them) for 8 s. Fully used up: a Blossom on every ally within 8 m of them.
- Owl - instant, 12 s cooldown, 2 mana. Woven: watches an ally for 15 s; the first hit they take, it dives: heals 1.0 (+ Blossoms) and strikes the attacker, or the nearest enemy within 10 m, for 0.5 FB (own meter line "Owl's Strike"). No hit: it lands and leaves a Blossom.
- Heartwood Elk - instant, 15 s cooldown, 3 mana. Rooted: every ally within 10 m of you is healed 0.5 + 0.3 per Blossom (uses them), split past the AoE cap. Allies who had 3: Full Bloom (10% less damage taken, 6 s).
- Wild Herd - instant, 120 s cooldown, 3 mana. A Fawn at each of the 5 lowest-health allies within 40 m, each a full Fawn (bounces, Blossoms, Running Herd).

### Talents
- Running Herd (4, requires Fawn; row 1, column 3): Fawn heals 5/10/15% more; capstone: every second Fawn bounces 2 more times.
- Old Bark (3, Rootguard; r3c3): Rootguard's shield absorbs 10/20/30% more.
- Morning Dew (2, Dewfall; r5c3): Dewfall heals 15/20% more per Blossom instead of 10%.
- Return Flight (2, Owl; r6c3): after its dive the Owl keeps watching for the time it had left and can dive once more at 30/60% strength (heal and strike); the second watch leaves no Blossom when it lands.
- Deep Bloom (2, Heartwood Elk; r7c2): Full Bloom lasts 2/4 s longer.
- Quick Return (2, Return to Bloom; r8c2): its cast is 2/4 s shorter.
- Big Herd (2, Wild Herd; r8c3): its cooldown is 15/30 s shorter.
- Evergreen (5; r10c3): each of my Blossoms heals its ally 0.05/0.1/0.15/0.2/0.25% of their max health every second (own meter line "Evergreen"; a heal over time).

## Tank (the Colossus) - spec "Colossus" - BUILT 2026-10-16
Code: player.gd, "Nature tank: the Colossus". Numbers: balance.gd (SAP_*, VINE_FIST_*, GRASP_*, STOMP_*, GIANTS_HANDS_*, HEARTSAP_*, AWAKEN_*). Pictures: scripts/nature_creature.gd (fist, hand, foot, hands, chest, giant). Hold effect: data/effects/grasped.tres. Tests: tests/test_nature.gd.
- Melee, Fury. A huge vine giant (about three times your height, same bark and glowing veins) fights through you one limb at a time: each ability weaves one limb behind you for one strike or block, then it unravels. Martial abilities: Nature damage, scaling like abilities.
- Names: "Sheltering Hands" became Giant's Hands (Sheltering Light / Shelter exist); "Heartwood" became Heartsap (Heartwood Elk exists).

### Sap
- A buff on you: up to 5, 20 s, a gain starts the time over. Heals you 0.4% of max health per second per Sap (own meter line "Sap"). Gained from Vine Fist (1), Stomp (1, or 2 at 3+ enemies) and each hit Giant's Hands soaks (1). Heartsap uses it all.

### Kit (FB; Fury 0-100)
- Unlock levels: Vine Fist 2, Grasp 4, Stomp 6, Giant's Hands 8, Heartsap 10, Awaken 12.
- Vine Fist - builder, 3 s cooldown, generates 20 Fury. A giant fist punches over your shoulder: 1.0 FB to the target, 0.3 FB to up to 2 more enemies within 4 m of it, threat x4. +1 Sap.
- Grasp - 10 s cooldown, 15 Fury, 25 m. A hand rises under the enemy and drops it at your feet: taunts 3 s, held in place 1 s (Grasped; can still attack).
- Stomp - 8 s cooldown, 25 Fury. A foot comes down: 0.8 FB to every enemy within 8 m (split past the AoE cap), taunts them 3 s, double to a Grasped enemy. Leaves Stomp Roots for 6 s: 0.6 FB over the 6 s to enemies inside (DoT: crit and haste; split; own meter line).
- Giant's Hands - 20 s cooldown, 30 Fury. Hands close around you: shield of 30% max health for 8 s (Rime Ward applies). Each hit it soaks: +1 Sap. When it breaks or runs out: the hands burst, 0.8 FB to enemies within 6 m (split), threat x6.
- Heartsap - 12 s cooldown, 20 Fury, needs Sap. The chest opens behind you: heals 5% max health + 3% per Sap used (20% at 5).
- Awaken - 2 min cooldown. The whole giant stands behind you for 12 s: 15% less damage taken, Sap gains doubled, Vine Fist hits twice and slams the ground (0.4 FB to enemies within 6 m, split, own meter line "Giant's Slam"), Stomp reaches 12 m, Giant's Hands absorbs 50% more.

### Talents
- Thick Sap (4, requires Heartsap; row 2, column 4): Heartsap heals 5/10/15% more; capstone: Heartsap leaves you 2 Sap.
- Rising Sap (3; r4c4): each Sap heals 0.5/0.6/0.7% of max health per second instead of 0.4% (Deep Roots' Sap too).
- Crushing Grip (3, Giant's Hands; r5c4): the burst deals 5/10/15% more per hit the Hands soaked, up to 5 hits.
- Broad Fist (2, Vine Fist; r6c4): the splash hits 1/2 more enemies.
- Spreading Roots (2, Stomp; r7c4): Stomp Roots last 2/4 s longer and reach 1/2 m further; same damage per second.
- Firm Hold (2, Grasp; r9c4): Grasp holds 0.5/1 s longer and gives 5/10 Fury back.
- Wide Awake (2, Awaken; r9c1): Awaken lasts 3/6 s longer.
- Old Growth (5; r10c4): each Sap cuts damage taken by 0.4/0.8/1.2/1.6/2% (10% at 5).

## Archer (Venomstring) - spec "Venomstring" - BUILT 2026-10-16
Code: player.gd, "Nature archer: Venomstring". Numbers: balance.gd (VENOM_*, POISON_*, ADDER_*, ASP_*, KRAIT_*, BURST_*, BLOAT_*, COIL_*, SURGE_*). Snakes on the arrows: scripts/arrow.gd. Venom bar: scripts/hud.gd. Effects: data/effects/asp_venom.tres (slow), coiled.tres (hold). Tests: tests/test_nature.gd.
- Bow, Nature damage, scales like abilities. No mana or energy: Venom (0-100) is the only cost. A woven snake coils around each arrow in flight (green Adder, yellow Asp, white Krait); nothing of it sits on enemies. Poisoned enemies show coloured drips on each tick.
- Name: "Brood" is an enemy ability, so the big cooldown is Venom Surge.

### Venom
- Venom Flow (a buff on you) while your Adder, Asp and Krait Venom are all on enemies somewhere: each poison tick gives 3 Venom. Otherwise no gain; out of combat it drains 5 per second.
- The bar sits just above the action bar and shows only while all three poison arrows are on your bars (macros count).

### Poisons (own tick lists: crit and haste, 12 s, no cooldowns)
- Adder Arrow (1.5 s cast; instant after Fang Arrow): 2.4 FB over 12 s.
- Asp Arrow (instant): 1.2 FB over 12 s, 20% slower movement.
- Krait Arrow (instant): 0.8 FB over 12 s; your other poisons on that enemy tick 25% faster.
- Two different poisons of yours on an enemy: all of them deal 15% more; all three (Steeped): 30% more.
- A poisoned enemy dies: each poison jumps to the nearest enemy within 10 m with its time left (unless that enemy has a longer one of yours).

### Kit (FB; unlock levels 2-18 in this order)
- Fang Arrow - filler, 1.0 weapon hit. +2 s to every poison of yours on the target; your next Adder Arrow is instant.
- Adder Arrow, Asp Arrow, Krait Arrow - above.
- Venom Burst - 50 Venom. The target explodes: the damage left in your poisons on it, +20% per different poison, then they're removed; 50% of it to enemies within 6 m (split past the AoE cap; own meter line). Steeped target: 20 Venom back.
- Spitting Volley - 30 Venom. Adder Venom on every enemy within 8 m of the target (split past the AoE cap).
- Bloat Arrow - 40 Venom, 15 s cooldown. After 3 s the target bursts and your poisons on it are copied to every enemy within 8 m.
- Coil Back - 20 s cooldown. Leap 10 m back; a thorn trap stays 8 s where you stood: the first enemy within 2 m is held 1 s and gets Asp Venom.
- Venom Surge - 2 min cooldown, 15 s: poisons go on at double strength, Venom Flow stays on with a poison missing, Spitting Volley is free.

### Talents
- Lingering Venom (4, requires Venom Burst; row 2, column 7): Venom Burst deals 5/10/15% more; capstone: each poison Venom Burst would remove has a 40% chance to stay (rolled separately).
- Long Fangs (2, Fang Arrow; r1c7): Fang Arrow adds 3/4 s to my poisons instead of 2.
- Hungry Venom (2; r3c7): poisons jump up to 15/20 m on a death (instead of 10) and deal 10/20% more after jumping (once, however often they jump).
- Spring Trap (2, Coil Back; r4c7): the trap catches up to 2/3 enemies at once.
- Soaked Through (5; r9c7): Steeped gives 32/34/36/38/40% instead of 30%.

## Open talents (any spec) - BUILT 2026-10-17
Code: scripts/player/nature_talents_open.gd. Left edge of rows 1-4.
- Rough Bark (3): 3/6/9% more Armor.
- Green Thumb (3): my heals over time heal 4/8/12% more. Heals over time: Sap, Evergreen, the Strings, Refrain (Abilities.HEAL_OVER_TIME_IDS; keyword "heals over time").
- Undergrowth (3): my damage over time deals 4/8/12% more to an enemy carrying my own root, hold or slow.
- Clinging Vines (2): when a root or hold of mine ends, the enemy is Snagged: 20/40% slower for 3 s (one stack of data/effects/snagged.tres per rank). Was pitched as "Tangled", a name the Shadow Strings' root already uses.

## Talent layout
Shepherd left of the middle, Colossus down the middle (Wide Awake on the left edge of row 9: rows hold at most 4), Weaver right of the middle, Venomstring down the right edge, open talents down the left edge of rows 1-4. 5-rank talents in the bottom row (Venomstring's in row 9). One link: Compost -> Bramble Burst. Save version 9 refunded points left in the old empty slots.

## Utility (the book's "Utility" divider) - BUILT 2026-10-17
Code: scripts/player/utility.gd. Numbers: balance.gd (Utility section). Tests: tests/test_utility.gd. Useful to any spec (a fire mage takes one for the job it does); each has a rider only its Nature spec cashes in. See the utility table in systems.md. Overgrowth (knockback) moved to Fire as Bellows and Wild Run (party speed) to Lightning as Storm Front (2026-10-17), so Nature no longer carries most of the game's utility.
- Unlock levels (Skill Cards): Rootsnare 14, Deep Roots 18, Spore Sleep 20, Leaf Cloak 24.
- Rootsnare - instant, 20 s cooldown, 2 mana, 30 m. Roots the target and enemies within 3 m of it for 3 s. Leaves a Mulch patch under the target (Weaver). Nature's root.
- Deep Roots - instant, 60 s cooldown, 1 mana, 8 s: 15% less damage taken and 1 Sap per second (its heal works for anyone; Colossus feeds Heartsap). Moving ends it.
- Spore Sleep - 2 s cast, 30 s cooldown, 2 mana, 30 m. A non-boss, non-elite enemy sleeps 20 s (can't move, attack or cast); any damage wakes it (status flag break_on_damage). When it wakes it gets your Asp Venom (counts for Venom Flow).
- Leaf Cloak - instant, 2 min cooldown. Your threat on every enemy within 30 m drops to nothing; for 4 s your damage makes no threat (DoTs keep ticking quietly).

## Healer: out-of-combat rez
- Return to Bloom (Shepherd) - 8 s cast, 4 mana, 30 m, out of combat only. Vines raise a dead or downed ally where they fell with 50% health and mana. Code: scripts/player/rez.gd (shared by every healer's rez).
