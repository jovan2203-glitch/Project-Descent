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

## Tank (the Colossus) - spec "Colossus" - BUILT 2026-10-16
Code: player.gd, "Nature tank: the Colossus". Numbers: balance.gd (SAP_*, VINE_FIST_*, GRASP_*, STOMP_*, GIANTS_HANDS_*, HEARTSAP_*, AWAKEN_*). Pictures: scripts/nature_creature.gd (fist, hand, foot, hands, chest, giant). Hold effect: data/effects/grasped.tres. Tests: tests/test_nature.gd.
- Melee, Rage. A huge vine giant (about three times your height, same bark and glowing veins) fights through you one limb at a time: each ability weaves one limb behind you for one strike or block, then it unravels. Martial abilities: Nature damage, scaling like abilities.
- Names: "Sheltering Hands" became Giant's Hands (Sheltering Light / Shelter exist); "Heartwood" became Heartsap (Heartwood Elk exists).

### Sap
- A buff on you: up to 5, 20 s, a gain starts the time over. Heals you 0.4% of max health per second per Sap (own meter line "Sap"). Gained from Vine Fist (1), Stomp (1, or 2 at 3+ enemies) and each hit Giant's Hands soaks (1). Heartsap uses it all.

### Kit (FB; Rage 0-100)
- Unlock levels: Vine Fist 2, Grasp 4, Stomp 6, Giant's Hands 8, Heartsap 10, Awaken 12.
- Vine Fist - builder, 3 s cooldown, generates 20 Rage. A giant fist punches over your shoulder: 1.0 FB to the target, 0.3 FB to up to 2 more enemies within 4 m of it, threat x4. +1 Sap.
- Grasp - 10 s cooldown, 15 Rage, 25 m. A hand rises under the enemy and drops it at your feet: taunts 3 s, held in place 1 s (Grasped; can still attack).
- Stomp - 8 s cooldown, 25 Rage. A foot comes down: 0.8 FB to every enemy within 8 m (split past the AoE cap), taunts them 3 s, double to a Grasped enemy. Leaves Stomp Roots for 6 s: 0.6 FB over the 6 s to enemies inside (DoT: crit and haste; split; own meter line).
- Giant's Hands - 20 s cooldown, 30 Rage. Hands close around you: shield of 30% max health for 8 s (Rime Ward applies). Each hit it soaks: +1 Sap. When it breaks or runs out: the hands burst, 0.8 FB to enemies within 6 m (split), threat x6.
- Heartsap - 12 s cooldown, 20 Rage, needs Sap. The chest opens behind you: heals 5% max health + 3% per Sap used (20% at 5).
- Awaken - 2 min cooldown. The whole giant stands behind you for 12 s: 15% less damage taken, Sap gains doubled, Vine Fist hits twice and slams the ground (0.4 FB to enemies within 6 m, split, own meter line "Giant's Slam"), Stomp reaches 12 m, Giant's Hands absorbs 50% more.

### Talents
- Thick Sap (4, requires Heartsap; row 2, column 4): Heartsap heals 5/10/15% more; capstone: Heartsap leaves you 2 Sap.

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
