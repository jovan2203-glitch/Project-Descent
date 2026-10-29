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
- Thornshot - 1.5 s cast, 0.85 FB, 1 mana. A spray of thorns from your hand; every 3rd that lands leaves a patch. Thornburst: when it lands, thorns also burst from every patch within 8 m of the target, dealing 0.4 FB to each enemy within 4 m of a patch (each enemy hit at most once per cast, split past the AoE cap, its own meter line "Thornburst").
- Briar Tiger - 1.5 s cast, 6 s cooldown, 1.5 FB, 2 mana, 1 patch. Woven.
- Thornwing - instant, 10 s cooldown, 1.0 FB, 2 mana, 1 patch. Woven hawk, dives from above (ignores line of sight), usable while moving.
- Mossback - instant, 2 mana, uses nearby mulch: 0.5 FB + 0.5 FB per patch (3.0 FB at 5). Rooted bear, single target.
- Choking Vipers - instant, 3 mana, uses nearby mulch: vipers coil around every enemy within 8 m for 0.4 FB + 0.4 FB per patch over 3 s (2.4 FB at 5), split past the AoE cap, and hold each in place for 0.5 s (they can still cast and attack; never interrupts). A DoT: benefits from crit and haste.
- Greenwood Stag - instant, 15 s cooldown, 0.5 FB, 1 mana. Grows from your mulch, bounds to your target and carries every patch there. Uses up nothing.
- Finisher targeting: pressing Mossback or Choking Vipers with the mouse over a legal enemy (mouseover casting) uses the patches within 8 m of that enemy. Otherwise an 8 m circle appears; click to place it on the patches to use (Mossback still strikes your target; Choking Vipers hits the enemies inside the circle; no enemies inside = keep aiming). Pressing it again puts the circle away.
- Readability: a Mulch buff on you (one stack per patch, no timer) and the patch count on the Mossback and Choking Vipers buttons. Their tooltips show the damage with your current patches and with 5.

## Healer (the Shepherd) - spec "Shepherd" - BUILT 2026-10-16
Code: player.gd, "Nature healer: the Shepherd". Numbers: balance.gd (BLOSSOM_*, FAWN_*, ROOTGUARD_*, OWL_*, ELK_*, FULL_BLOOM_*, WILD_HERD_*; heals in HEALS). Pictures: scripts/nature_creature.gd (fawn, owl, roots, elk). Tests: tests/test_nature.gd.
- The Weaver's healing twin: woven creatures (vines from the hand) heal and leave Blossoms; rooted creatures (grown from the ground) use them up. Pure healer: its only damage is the Owl's strike.
- Note: "Shepherd" is also a Pact's name (Pact of the Shepherd); kept for now.

### Blossom
- A buff on an ally: up to 3, 20 s; a new one starts the time of all of them over. Woven heals leave 1, or 2 when the heal is more than the ally was missing. Own-only: only my rooted creatures use mine.

### Kit (heals in old Heals: 1.0 = one Psalm; mana in points)
- Unlock levels: Dewfall 2, Fawn 4, Rootguard 6, Owl 8, Heartwood Elk 10, Wild Herd 12. Range 40 m.
- Dewfall - 1.5 s cast, 1 mana. Heals 0.73, +10% per Blossom on the target (uses none). Filler, not a creature.
- Fawn - 1.5 s cast, 8 s cooldown, 3 mana. Woven chain heal: 0.73 on the target, then bounces 3 times, each to the lowest-health ally within 12 m not yet healed, each bounce x0.8. A Blossom on each.
- Rootguard - instant, 15 s cooldown, 2 mana. Rooted: roots wrap the ally in a shield of 0.61 + 0.4 per Blossom (uses them) for 8 s. Fully used up: a Blossom on every ally within 8 m of them.
- Owl - instant, 12 s cooldown, 2 mana. Woven: watches an ally for 15 s; the first hit they take, it dives: heals 0.73 (+ Blossoms) and strikes the attacker, or the nearest enemy within 10 m, for 0.5 FB (own meter line "Owl's Strike"). No hit: it lands and leaves a Blossom.
- Heartwood Elk - instant, 15 s cooldown, 3 mana. Rooted: every ally within 10 m of you is healed 0.39 + 0.3 per Blossom (uses them), split past the AoE cap. Allies who had 3: Full Bloom (10% less damage taken, 6 s).
- Wild Herd - instant, 120 s cooldown, 3 mana. A Fawn at each of the 5 lowest-health allies within 40 m, each a full Fawn (bounces, Blossoms, Running Herd).

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

## Archer (Venomstring) - spec "Venomstring" - BUILT 2026-10-16
Code: player.gd, "Nature archer: Venomstring". Numbers: balance.gd (VENOM_*, POISON_*, ADDER_*, ASP_*, KRAIT_*, BURST_*, BLOAT_*, COIL_*, SURGE_*). Snakes on the arrows: scripts/arrow.gd. Venom bar: a tracker (scripts/ui/trackers/trackers.gd, spec_sets()). Effects: data/effects/asp_venom.tres (slow), coiled.tres (hold). Tests: tests/test_nature.gd.
- Bow, Nature damage, scales like abilities. No mana or energy: Venom (0-100) is the only cost. A woven snake coils around each arrow in flight (green Adder, yellow Asp, white Krait); nothing of it sits on enemies. Poisoned enemies show coloured drips on each tick.
- Name: "Brood" is an enemy ability, so the big cooldown is Venom Surge.

### Venom
- Venom Flow (a buff on you) while your Adder, Asp and Krait Venom are all on enemies somewhere: each poison tick gives 2.5 Venom. Otherwise no gain; out of combat it drains 5 per second.
- The bar sits just above the action bar and shows only while all three poison arrows are on your bars (macros count).

### Poisons (own tick lists: crit and haste, 12 s, no cooldowns)
- Adder Arrow (1.5 s cast; instant after Fang Arrow): 1.3 FB over 12 s.
- Asp Arrow (instant): 0.65 FB over 12 s, 20% slower movement.
- Krait Arrow (instant): 0.45 FB over 12 s; your other poisons on that enemy tick 25% faster.
- Two different poisons of yours on an enemy: all of them deal 15% more; all three (Steeped): 30% more.
- A poisoned enemy dies: each poison jumps to the nearest enemy within 10 m with its time left (unless that enemy has a longer one of yours).

### Kit (FB; unlock levels 2-18 in this order)
- Fang Arrow - filler, 1.0 weapon hit. +2 s to every poison of yours on the target; your next Adder Arrow is instant.
- Adder Arrow, Asp Arrow, Krait Arrow - above.
- Venom Burst - 50 Venom. The target explodes: the damage left in your poisons on it, +5% per different poison, then they're removed; 50% of it to enemies within 6 m (split past the AoE cap; own meter line). Steeped target: 20 Venom back.
- Spitting Volley - 30 Venom. Adder Venom on every enemy within 8 m of the target (split past the AoE cap).
- Bloat Arrow - 40 Venom, 15 s cooldown. After 3 s the target bursts and your poisons on it are copied to every enemy within 8 m.
- Coil Back - 20 s cooldown. Leap 10 m back; a thorn trap stays 8 s where you stood: the first enemy within 2 m is held 1 s and gets Asp Venom.
- Venom Surge - 2 min cooldown, 15 s: poisons go on at double strength, Venom Flow stays on with a poison missing, Spitting Volley is free.

## Talents (ribbon layout, 2026-10-27; TREE_VERSION 12)
- Specs side by side as ribbons: Thornweaver (columns 1-3), Shepherd (4-6), the open talents on the spine (7), Colossus (8-10), Venomstring (11-13). 19 talents per spec, at most 5 needing one ability; capstones need 15 points in the spec. Code: each spec's component (nature_weaver.gd, nature_shepherd.gd, nature_colossus.gd, nature_venomstring.gd); hit, heal and cost bonuses and the open talents: nature_talents_open.gd.
- Shapes: Thornweaver "bramble", Shepherd "flower", Colossus "oak", Venomstring "coiled snake". Links: Compost -> Bramble Burst, Thick Mulch -> Well Rotted; Second Bud -> Pollen, Long Bloom -> Canopy; Groundswell -> Heavy Limbs, Long Sap -> Brimming; Slow Acting -> Fresh Host, Double Dose -> Full Brew.
- Keywords with their own Shift text: woven creatures (Briar Tiger, Thornwing, Fawn, the Owl), rooted creatures (Mossback, Choking Vipers, Greenwood Stag, Rootguard, Heartwood Elk) and Thornburst.
- Thornweaver (56 ranks): Compost (1, Thornshot), Thick Mulch (2, patches +5/10 s), Hunting Party (4, Briar Tiger), Bramble Burst (3, Thornburst +10/20/30%, capstone 5 m; no longer needs Thornshot), Well Rotted (3, patches that lay 10 s add 20/40/60% more to Mossback and Choking Vipers), Rich Soil (3), Second Growth (3, Mossback), Circling Hawk (3, Thornwing), Fertile Ground (3, Choking Vipers), Long Roots (3, the finishers use patches 1/2/3 m further away), Tight Weave (3, woven creatures +4/8/12%), Old Roots (3, rooted creatures +4/8/12%), Steady Weave (3, Nature spells with a cast time +3/6/9%), Harvest (3, a finisher using 3+ patches refunds 20/40/60% of its mana), Leaf Litter (3, a patch running out unused gives 0.3/0.6/1% max mana), Hunted (3, woven creatures +5/10/15% below 35% health), Lush (3, Nature damage spells cost 3/6/9% less), Quickening (2, laying a patch makes the next Nature cast within 6 s 10/20% faster). Capstone Overgrown (5, Nature spells +0.4-2% per patch; at max a finisher that uses 5 patches leaves one behind).
- Shepherd (58 ranks): Running Herd (4, Fawn), Morning Dew (3, Dewfall), Old Bark (3, Rootguard), Return Flight (3, Owl), Second Bud (3, woven heals have a 10/20/30% chance of one more Blossom), Deep Bloom (3, Heartwood Elk), Long Bloom (2, Blossoms +3/6 s), Heavy Petals (3, each Blossom adds 10/20/30% more to the rooted creatures), Soft Weave (3, woven creatures heal 4/8/12% more), Pollen (3, using up 3 Blossoms on an ally: a 33/67/100% chance a Blossom goes to the lowest-health ally within 12 m), Canopy (3, an ally you give a Blossom takes 1/2/3% less damage for 6 s; it travels the Full Bloom path), In Full Flower (3, heals +5/10/15% on an ally with 3 Blossoms), Close Herd (3, Fawn's bounces keep 85/90/95% of the heal before instead of 80%), New Shoots (3, Nature heals +4/8/12% on an ally with no Blossoms), Nectar (3, each Blossom used up gives 0.1/0.2/0.3% max mana), Patient Hands (3, Nature heals with a cast time +3/6/9%), Wide Grove (2, rooted creatures reach 2/4 m further), Morning Mist (3, Nature heals cost 3/6/9% less). Capstone Evergreen (5; at max Blossoms that run out unused heal their ally for 0.3 heals each).
- Colossus (58 ranks): Groundswell (3, Nature abilities build 5/10/15% more Fury), Thick Sap (4, Heartsap), Crushing Grip (3, Giant's Hands), Rising Sap (3), Heavy Limbs (3, Nature abilities that spend Fury +3/6/9%), Broad Fist (2, Vine Fist), Spreading Roots (3, Stomp), Firm Hold (3, every Nature hold - Grasped, Choked, Coiled - lasts 0.3/0.7/1 s longer and each gives 3/7/10 Fury; no longer needs Grasp), Wide Awake (3, Awaken), Long Sap (2, Sap +5/10 s), Sap Run (3, a 10/20/30% chance of one more Sap), Taproot (3, each Sap used up gives 1/2/3 Fury), Long Limbs (3, hits on everything around you reach 1/2/3 m further), Called Out (3, each enemy a taunt hits gives 2/4/6 Fury, up to 3), Creaking Bark (3, Nature abilities +5/10/15% threat), Brimming (3, Sap heals 20/40/60% more at 5 Sap), Woodgrain (3, shields you put on yourself absorb 7/13/20% more: StatusContainer.set_absorb), Old Oak (3, Sap heals 33/67/100% more below 35% health). Capstone Old Growth (5; at max a hit of 15%+ max health gives a Sap, at most once every 3 s).
- Venomstring (56 ranks): Long Fangs (3, Fang Arrow), Lingering Venom (4, Venom Burst), Slow Acting (2, poisons +2/4 s), Virulent (3, poisons +3/6/9%), Spring Trap (2, Coil Back), Hungry Venom (2), Fresh Host (3, a jumping poison +2/4/6 s), Double Dose (3, two poisons give 18/21/24% instead of 15%), Quick Venom (3, poisons tick 3/6/9% more often), Swollen (3, copied poisons +10/20/30%), Full Brew (3, direct hits +3/6/9% on Steeped enemies), Full Glands (3, Venom Flow ticks +0.5/1/1.5 Venom), Spare Venom (3, a 10/20/30% chance that spending Venom gives half back), Running Venom (3, bow shots +3/6/9% during Venom Flow), Dragging Feet (3, bow shots +4/8/12% on enemies you slowed), Dripping Tips (3, auto-shots have a 10/20/30% chance to add 1 s to your poisons), Final Bite (3, poisons +5/10/15% below 35% health), First Bite (2, the first poison on an enemy with none goes on 10/20% stronger). Capstone Soaked Through (5; at max each poison tick on a Steeped enemy gives 1 more Venom during Venom Flow).
- Open (9): Rough Bark (3), Green Thumb (3), Undergrowth (3), Clinging Vines (2), Startle (3, the first spell or ability on an enemy at full health +5/10/15%), Pack Hunter (3, +2/4/6% on an enemy attacking someone else), Tending (3, heals +3/6/9% on an ally carrying one of your heals over time), Food Chain (3, an enemy you damaged dying heals you 1/2/3% max health; own meter line), Hibernate (2, out of combat health and mana come back 25/50% faster).
- Folded earlier: Big Herd (Wild Herd 90 s), Quick Return (Return to Bloom 4 s cast).

## Utility (the book's "Utility" divider) - BUILT 2026-10-17
Code: scripts/player/utility.gd. Numbers: balance.gd (Utility section). Tests: tests/test_utility.gd. Useful to any spec (a fire mage takes one for the job it does); each has a rider only its Nature spec cashes in. See the utility table in systems.md. Overgrowth (knockback) moved to Fire as Bellows and Wild Run (party speed) to Lightning as Storm Front (2026-10-17), so Nature no longer carries most of the game's utility.
- Unlock levels (Skill Cards): Rootsnare 14, Deep Roots 18, Spore Sleep 20, Leaf Cloak 24.
- Rootsnare - instant, 20 s cooldown, 2 mana, 30 m. Roots the target and enemies within 3 m of it for 3 s. Leaves a Mulch patch under the target (Weaver). Nature's root.
- Deep Roots - instant, 60 s cooldown, 1 mana, 8 s: 15% less damage taken and 1 Sap per second (its heal works for anyone; Colossus feeds Heartsap). Moving ends it.
- Spore Sleep - 2 s cast, 30 s cooldown, 2 mana, 30 m. A non-boss, non-elite enemy sleeps 20 s (can't move, attack or cast); any damage wakes it (status flag break_on_damage). When it wakes it gets your Asp Venom (counts for Venom Flow).
- Leaf Cloak - instant, 2 min cooldown. Your threat on every enemy within 30 m drops to nothing; for 4 s your damage makes no threat (DoTs keep ticking quietly).

## Healer: out-of-combat rez
- Return to Bloom (Shepherd) - 8 s cast, 4 mana, 30 m, out of combat only. Vines raise a dead or downed ally where they fell with 50% health and mana. Code: scripts/player/rez.gd (shared by every healer's rez).
