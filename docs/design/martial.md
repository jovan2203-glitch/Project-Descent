# Martial book

No magic, only technique. Physical damage; everything scales like an ability (mostly Attack Power). Values in Frost Bolts (FB) are conversation shorthand; real numbers go in balance.gd.

## The wipe (2026-10-17)
- All 16 old abilities (Heavy Blow, Headsman's Cut, Steady Shot, Stoneguard, Taunt, ...) were removed. The book is rebuilt from this file.

## Specs (planned)
- Warrior - two-handers, Fury: the Wheel (below). FINAL DRAFT 2026-10-19.
- Rogue - dual wield, Energy: Flow and the Kill window (below). BUILT 2026-10-20.
- Brawler - the tank, Fury: pugilist / mixed martial artist (below). DRAFT 2026-10-20. Takes the old Tank and Brawler slots.
- Sharpshooter - the archer, bow, no resource: the Reset Engine (below). BUILT 2026-10-21.
- Utility divider: Pin the Shadow (root), Over the Shoulder, Play Dead (below). Still needs an interrupt.

## Rogue (dual wield, Energy) - spec "Rogue" - BUILT 2026-10-20 (scripts/player/martial_rogue.gd)
Numbers are drafts (balance.gd); balance sim ~2200 geared DPS (like the Wheel). Every ability needs a one-handed melee weapon in each hand. Energy 100/100. Physical, scales like an ability.

### The playstyle
Build up fast, then go in for the kill. Quick hits build **Flow**; weaving in and out of melee builds it faster; you pick the moment to spend it all on a **Kill window**.

### Flow
- A buff, 0-10 stacks, +1% damage each. The party sees it as a glow around you (red in a Kill window).
- Every Rogue ability that **hits** adds Flow (auto attacks don't). Not during a Kill window.
- **Range switch**: a hit from a different range than your last one (melee after a thrown hit, or a throw after a melee hit) gives +1 more.
- 3 s without a hit and it drops by 1 each second.

### Stuck daggers
- A thrown dagger **sticks** in the target: up to 3 per enemy, yours only, visible to the party, 20 s.
- Melee abilities **rip them out** for 0.25 FB each (its own meter line, "Ripped Out").

### Building Flow
| Button | Cost | Effect | Flow |
|---|---|---|---|
| **Cut** | 20 Energy | Melee: 0.55 FB, both blades. From 5-25 m: a thrown dagger, 0.45 FB, which sticks. | +1 |
| **Kick Off** | 15 Energy, 10 s | Kick the target (0.4 FB) and flip back 8 m. Your next throw within 4 s throws two daggers. | +1 |
| **Dart In** | 15 Energy, 10 s | Dash to the target from up to 15 m, 0.5 FB. Rips out one stuck dagger. | +1 |
| **Twin Stab** | 30 Energy, 8 s | 0.5 FB from each hand. Rips out every stuck dagger. | +2 |
| **Whirl** | 35 Energy | 0.35 FB to every enemy within 5 m (split past the cap); rips out the daggers of every enemy hit. With no enemy that close: **Knife Spread**, a dagger into each of up to 3 enemies in front (0.3 FB, they stick). | +1 per enemy, max 3 |

### The Kill
- **Go In** (off the GCD, needs 5+ Flow): spends all Flow and opens a **Kill window** of 1 s per stack. During it the builders take their Kill forms, crits refund 10 Energy and no Flow builds.
  - Cut -> **Gut**: 1.0 FB (thrown 0.8 FB, sticks).
  - Twin Stab -> **Through and Through**: 0.9 FB from each hand, no cooldown, rips daggers.
  - Whirl -> **Red Whirl**: 0.6 FB around you (thrown: Knife Spread at 0.5 FB each).
  - Kick Off -> **Back Flip**: 0.6 FB, flip back 8 m and throw 3 daggers into the target (0.3 FB each, they stick). Shares Kick Off's cooldown.
  - Dart In -> **Drive Through**: dash through the target, 0.8 FB, rips one dagger, resets Kick Off. Shares Dart In's cooldown.
  - **Variety**: each Kill form that is different from the one before it adds 0.5 s to the window (up to +5 s).
- **Close It Out** (20 Energy, Kill window only): ends the window for 0.4 FB per second it had left.
- **Hit Your Stride** (2 min, off the GCD): sets Flow to 10 and opens a Kill window 50% longer (15 s).
- **Roll With It** (25 s, off the GCD): spends 3 Flow: 40% less damage taken for 3 s.

### Snatch (a fun extra, not part of the core)
- 20 s cooldown, 15 Energy, melee. Lifts something off the target's belt and uses it at once, one of four at random. No Flow.
  - **Flash Powder**: enemies in front of you (8 m) are blinded 2 s: they can't attack, move or cast (not bosses).
  - **Whetstone**: your next 3 hits deal 50% more.
  - **Smoke Flask**: drops your threat on every enemy and gives 20% dodge for 4 s.
  - **Oil Jar**: a 4 m burning pool under the target for 6 s (Fire damage each second, split past the cap; a stolen item, not a Fire spell; its own meter line).

### Learning (Skill Cards)
- Level 2: Cut (brings Go In and the Kill forms). 4: Whirl. 6: Dart In. 8: Kick Off. 10: Twin Stab. 12: Close It Out. 14: Roll With It. 16: Hit Your Stride. 18: Snatch.

## Sharpshooter (bow, no resource) - spec "Sharpshooter" - BUILT 2026-10-21 (scripts/player/martial_sharpshooter.gd)
Numbers are drafts (balance.gd); balance sim ~2220 geared DPS. Every ability needs a bow. Physical, scales like an ability. Built gameplay-first: the theme is plain archery on purpose.

### The playstyle
The cooldowns are the resource. Every shot has a real cooldown and every hit brings another shot back sooner. In the right order the engine never runs dry. The twist is **Overcut**: time cut off a shot that is already ready charges that shot instead, so holding a shot can beat firing it. But a held shot feeds nothing, the engine starves, and you end up pressing Loose, which halves your Streak.

### The shots
| Shot | CD | Damage | On hit, brings back sooner |
|---|---|---|---|
| **Quick Shot** | 8 s | 0.45 FB | Pierce 3 s |
| **Pierce** | 12 s | 0.5 FB to every enemy on a line through the target (bow range, 1.5 m wide; split past the cap) | Spread 2 s for the first enemy, +1.5 s per extra one, up to 6 s |
| **Spread** | 15 s | 3 arrows, 0.3 FB each, across up to 3 enemies in front (a lone enemy takes them all) | Heavy Draw 1.5 s per arrow |
| **Heavy Draw** | 20 s, 1.5 s cast | 1.3 FB | Quick Shot ready at once; every other shot 2 s |
| **Follow Up** | 10 s | 2 x 0.22 FB | the shot you used just before it, 2 s per arrow |
| **Loose** | none | 0.25 FB | nothing; halves the Streak |
- Without cuts the cooldowns fill ~64% of your GCDs; good ordering fills the rest.
- **Crits reset**: a crit makes that hit's cuts full resets (a reset on a ready shot gives it its whole cooldown as Overcut).

### Overcut
- A cut past ready becomes Overcut on that shot: +8% damage per second, up to 12.5 s (+100%). Firing the shot spends it. Leaving combat clears it.
- Shown as "+40%" on the button and on the engine strip; the party sees a gold glow on your quiver while a held shot has 6+ s of it.

### Streak
- +1 per engine shot used (Quick Shot, Pierce, Spread, Heavy Draw, Follow Up), up to 10, +2% damage each. Loose halves it; 4 s without a shot loses it.
- At 10, Heavy Draw is instant and always crits, so its cuts are all resets. The Streak stays at 10.
- The party sees it as lit fletchings in the quiver on your back.

### Cooldowns (off the GCD)
- **Breathe** (30 s): for 10 s, the next cut you make is a full reset.
- **Fast Hands** (2 min): every cut is doubled for 10 s.

### HUD
- The engine strip above the bar: the five shots in feeding order, each with its cooldown (or Overcut, gold) under it, and above it what your ready shots would take off it (blue: sooner, gold: Overcut).

### Learning (Skill Cards)
- Level 2: Quick Shot (brings Loose). 4: Pierce. 6: Spread. 8: Heavy Draw. 10: Follow Up. 12: Breathe. 16: Fast Hands.

## Martial Utility (the book's "Utility" divider) - BUILT 2026-10-20 (scripts/player/martial_rogue.gd)
Cooldowns only, no cost (the Warrior and the Brawler spend Fury, the Rogue Energy). Each needs a melee weapon.
- **Pin the Shadow** (Martial's root): 20 s, 30 m. A thrown knife pins the enemy's shadow to the floor: rooted until it has been hit 3 times, by anyone (damage over time doesn't count), or 8 s pass. Card level 14.
- **Over the Shoulder**: 20 s, 10 m. Vault over the target and land behind it; your next hit within 5 s always crits. Card level 18.
- **Play Dead**: 90 s, off the GCD. You drop and every enemy forgets you for 3 s (threat dropped; they turn to someone else, or stand over you if there is nobody). Using anything or attacking ends it. Card level 22.


## Brawler (tank) - BUILT 2026-10-20 (scripts/player/martial_brawler.gd)
Numbers are drafts (balance.gd). Built with: strikes 0.3 FB and +10 Fury each (the Fury scale's minimum gain), Rapid Fists 0.45, Haymaker 1.1, Sweep 0.4, Roundhouse 0.5, Throw 0.6, Reversal 1.0, Come On 8 s cooldown / 3 s taunt; balance sim ~2200 geared DPS (tank range). Fighting Style changes the strike visuals only for now (no unarmed animation set on the placeholder body yet). A pugilist / mixed martial artist: wraps, footwork, clinches, takedowns, haymakers. Not a monk and not a copy of WoW's Brewmaster (legal reasons): no chi, robes, meditation, palms, brews, drunken or animal stances, and the delayed-damage pool has its own name and its own way of clearing it.

### Bruise (takes the hit, pays it later)
- 40% of every hit you take is not dealt now: it goes into **Bruise**, dealt to you evenly over 6 s. New damage adds to it and restarts the 6 s with the total left.
- Readability: a Bruise buff with the amount; the health bar shows Bruise as a darker segment.
- Each Bruise tick gives Fury, so the damage you soak feeds the kit.
- Cleared by Shake Off, Takedown on a boss and talents; paused by Tough It Out.

### Strikes and strings
- Three strikes: **Punch**, **Kick**, **Elbow** (Punch, not Jab: the Halberd's filler is Jab). No cost, generate Fury, **1 s GCD** (the only exception to the 1.5 s GCD).
- **No shield:** every Brawler ability needs an off hand that isn't a shield (two-handers, dual wield, other off hands and an empty hand all work).
- **The chain** holds 3 inputs. When the third lands, a move goes off on top of that strike and the chain clears. 5 s without a strike also clears it.
- The rule: **the last strike picks the move; all three different makes the strong version.** Every chain does something; nothing to memorise. Talents change what moves do, never add orders.

| Ends with | Any repeat (e.g. P-P-P, K-E-E) | All three different (e.g. K-E-P) |
|---|---|---|
| **Punch** (damage) | **Rapid Fists**: extra single-target damage, high threat | **Haymaker**: the biggest hit, spends 30 Fury (without it, Rapid Fists) |
| **Kick** (AoE) | **Sweep**: every enemy within 5 m (split past the cap), threat | **Roundhouse**: bigger sweep, knocks down 1 s (not bosses) |
| **Elbow** (defence) | **Clinch**: 4 s, you take 30% less damage from that target | **Shake Off**: clears 30% of your Bruise |

- **Catch chains** (Catch first, the middle input is free, the last strike decides):
  - Catch-?-Punch: **Turn It Around**: the caught hit's full damage goes back into the target (meter line).
  - Catch-?-Kick: **Throw**: throws the caught enemy up to 6 m; it and enemies where it lands are knocked down 1 s. Boss: **Reversal**, a big hit.
  - Catch-?-Elbow: **Takedown**: the caught enemy is on the floor 3 s. Boss: clears Bruise equal to the caught hit.

### Other abilities
- **One More**: 15 s cooldown, 25 Fury, 1.5 s GCD. Repeats the last chain move you made (a repeated Haymaker also spends its own 30 Fury). Doesn't touch the chain: the orbs you have stay. It repeats Catch moves too, with the same caught hit.
- **Tough It Out**: 30 s cooldown, 40 Fury. For 5 s your Bruise ticks deal no damage and give double Fury. A pause, not a clear (Shake Off clears).
- **Come On**: the taunt.
- **On the Ropes** (idea, not agreed): 90 s, off the GCD. 8 s: 70% of hits go into Bruise (not 40%), spread over 10 s; when it ends, a hit for 30% of the damage that went into Bruise (meter line).

### Catch
- Usable only while **your current target** shows a **melee tell** at **you**. The whole tell is the window (plus a short grace for latency): no tight timing. Only your target, so a pack doesn't make it free.
- **Melee tells** (every enemy, a generic system): every melee hit has a short, bright tell before it lands (0.6 s; elites and Frenzy shorten it like a cast). Same hit rate as before. It is not a cast: interrupts don't stop it, stuns and knockdowns do. The party sees it.
- On the 1 s GCD like the strikes, no cooldown.
- It always costs something, so pressing it whenever it lights up (or macroing it into other buttons) loses:
  - **It clears your chain.** Catch is always the first input, so the 1-2 strikes you had in are lost (a Haymaker you were building is gone).
  - **The caught hit skips Bruise:** all of it lands now. Catching a big hit is a real health spike.
- The payoff is the Catch strings, the strongest ones. So the choice is: catch now (chain is empty or cheap, health can take it) or let it go.
- Bosses are never thrown, knocked down or put on the floor (Reversal / Takedown's boss version instead).

### Tracking the chain
- **Orbs on your back** (the party sees them): each strike adds an orb floating over your back, left to right: Punch red, Kick green, Elbow blue, Catch white. Red-red-red is Punch-Punch-Punch. A string bursts the orbs; a chain that matches nothing or times out fades them.
- Not a buff (a buff can't show order). The **chain strip** above the action bar shows the same 3 orbs.
- The last orb's colour says the move; three different colours burst gold (the strong version).
- With 2 inputs in, each strike button shows the move it would finish.
- Each strike's tooltip states the rule and its two moves; the spec page shows the table.

### Fighting Style (toggle)
- Off the GCD, no cooldown: switches the strike animations between **Armed** (your weapon in hand: pommel jabs, kicks with it drawn) and **Bare Hands** (weapon on your back, wrapped fists). Animations only; the numbers are the same. Remembered, and the party sees it.

### Learning (Skill Cards)
- Level 2: Punch, Kick, Elbow and Fighting Style. Level 4: Catch. Level 6: Come On. Level 8: Tough It Out. Level 10: One More.

## Warrior: the Wheel - spec "The Wheel" - FINAL DRAFT 2026-10-19
Numbers are drafts (balance.gd); names agreed. Spec name "The Wheel" is a working name.

### The Wheel
- Four glowing, floating two-handers ride on your back in a fixed order: **Greataxe -> Greatsword -> Halberd -> Maul** -> back to the Greataxe. Every second weapon sweeps (Greataxe, Halberd), so AoE and single-target weapons alternate.
- The equipped weapon gives only stats; any melee weapon works.
- The front weapon is held in your hands. Each held weapon takes **4 uses**: every ability that goes off counts, from any book, cast or instant, except off-GCD abilities and trinkets. After the 4th use the weapon breaks and the next one flies into your hands. Break (the finisher) breaks it on purpose, early or as the 4th use.
- A broken weapon reforms at the back of the line.
- Leaving combat makes the held weapon whole again (Cracks cleared, 4 uses). Out of combat, clicking the Wheel strip above the action bar turns it to the next weapon, so you choose your opening weapon. In combat the order never changes.
- Visuals: the held weapon at your hands, the other three in an arc behind your shoulders, each with its own bright colour (axe red, greatsword white-blue, halberd green, maul amber); the next one glows brightest. Cracks show as glowing fissures on the held weapon; Break bursts it apart. The party sees it. Swap-ready: each weapon model is built in one place.

### Cracks and Break
- The bar holds 4 buttons that take the held weapon's form (16 forms, each with its own name and icon):
  - **Filler**: no cost, +20 Fury, 1 Crack.
  - **Heavy Filler**: 30 Fury, 2 Cracks.
  - **Weapon Art**: the weapon's own move. Cooldown, no cost, no Fury, no Cracks, no damage of any kind (movement, crowd control, defence), paid for with a use.
  - **Finisher** (each weapon's is its Break). 0.2 FB + 0.6 FB per Crack. Next to useless without Cracks.
- Cracks have no cap; the 4 uses and Fury limit them. They belong to the held weapon and are lost when it breaks without Break.
- The choice: Quick, Full, Quick, Break is a strong Break; spending a use on the Art or another book's ability means a weaker one.

### The weapons
Each weapon has a rider that works while it is held, for every ability (any book). Bosses are never knocked down or dragged and build no Stagger.

| Weapon | Rider | Filler | Heavy Filler | Weapon Art | Finisher (Break) |
|---|---|---|---|---|---|
| Greataxe | Ability hits also hit 1 enemy within 5 m for 25% (meter line "Axe Cleave") | Hack 0.6 FB, cleaves up to 2 more within 5 m for 50% | Chop 0.8 FB, same cleave | Rush: dash up to 12 m through enemies (15 s) | Shrapnel: shards around you, 8 m, split past the cap |
| Greatsword | +10% crit chance | Slash 0.7 FB | Lunge 0.95 FB | Blade Guard: 40% less damage taken for 4 s (45 s) | Shard Lance: every shard into the target (x1.2) |
| Halberd | Ability hits have a 20% chance to hit again (meter line "Second Hit") | Jab 0.6 FB, sweeps up to 3 enemies in front (split), +30 Fury instead of 20 | Hook 0.8 FB, same sweep, costs 20 Fury instead of 30 | Drag In: hook one enemy up to 12 m away and drag it to you, no taunt (20 s) | Flying Head: the head snaps off, hits the target, then bounces to 3 more at 50% |
| Maul | Ability hits build Stagger on the target (own, per enemy); full Stagger knocks it down 1 s, then resets | Thud 0.6 FB, extra Stagger | Crush 0.8 FB, extra Stagger | Earthshake: knocks down enemies within 6 m for 1.5 s (30 s) | Fault Line: a shockwave in an 8 m cone, split, extra Stagger |

### Spellbook and learning
- The spec lists the 4 weapons; each has a dropdown showing its 4 moves. The spec also lists four placeholders, Filler, Heavy Filler, Weapon Art and Finisher: they do nothing themselves; on the bar each becomes the held weapon's move of that kind. Dragging a move from a dropdown places its placeholder.
- Weapons are learned whole (Skill Cards): Greataxe 2, Greatsword 4, Halberd 6, Maul 8. The Wheel holds the learned ones, in order.
- Readability: a Cracks buff (one stack per Crack), the Wheel strip (weapons in order, the held one large with its uses left and Cracks) and the Crack count on the Break button.

## Talents (Martial tree) - BUILT 2026-10-21
Numbers are drafts (talents.gd, balance.gd). Layout: the Wheel down the left edge (columns 1-2), the Rogue in column 3, the open talents down the middle (column 4), the Brawler in column 5, the Sharpshooter down the right edge (columns 6-7). Row 1 holds each spec's 4-rank talent (capstone at 4), the bottom row its 5-rank one. No links. Code: each spec's component; the open talents and the damage bonuses (each its own meter line): scripts/player/martial_talents_open.gd. Save v10 refunds points in the old empty Martial slots.

### The Wheel
- Hard Break (4, needs the Greataxe; r1c1): finishers deal 5/10/15% more. Capstone: a finisher that breaks a weapon with 6+ Cracks gives 20 Fury.
- Well Drilled (2; r2c2): Weapon Arts add 1/2 Cracks.
- Wide Cleave (2, Greataxe; r4c1): Axe Cleave hits 1/2 more enemies.
- Keen Edge (2, Greatsword; r5c2): while it is held, crits deal 10/20% more.
- Twice Over (2, Halberd; r7c1): Second Hit chance 25/30% (from 20%).
- Rattled (2, Maul; r8c2): hits build 25/50% more Stagger.
- Turning Wheel (5; r10c1): each weapon that breaks gives a stack for 15 s (one per weapon, up to 4): 0.5/1/1.5/2/2.5% more damage each (10% with all four).

### Rogue
- Clean Kill (4, Go In; r1c3): Kill forms deal 5/10/15% more. Capstone: Close It Out leaves 3 Flow.
- In and Out (2, Cut; r3c3): a range switch gives 2/3 extra Flow (from 1).
- Barbed (3, Cut; r4c3): Ripped Out deals 20/40/60% more.
- Steady Pace (2, Cut; r6c3): Flow holds 4/5 s before it drops (from 3).
- Mix It Up (2, Go In; r7c3): Variety adds 0.75/1 s per different Kill form (cap stays 5 s).
- Deep Pockets (2, Snatch; r9c3): Snatch's cooldown is 5/10 s shorter.
- In the Zone (5; r10c3): each Flow stack gives 0.1/0.2/0.3/0.4/0.5% crit chance (5% at 10); in a Kill window the Flow spent on it counts.

### Brawler
- Soak It Up (4, Punch; r1c5): Bruise takes 42/44/46% of each hit (from 40%). Capstone: Shake Off clears 40% (from 30%).
- Tight Clinch (2, Elbow; r3c5): Clinch lasts 5/6 s (from 4).
- Soft Catch (2, Catch; r4c5): 25/50% of a caught hit still goes into Bruise. Turn It Around and Takedown still count the whole hit.
- Knockout (3, Punch; r6c5): Haymaker deals 10/20/30% more.
- Wide Stance (2, Kick; r7c5): Sweep and Roundhouse reach 1/2 m further.
- Round Two (2, One More; r9c5): One More's cooldown is 3/6 s shorter.
- Scar Tissue (5; r10c5): Bruise deals 2/4/6/8/10% less damage (its Fury stays the same).

### Sharpshooter
- Full Draw (4, Heavy Draw; r1c7): Heavy Draw deals 5/10/15% more. Capstone: its cuts are 3 s (from 2).
- Broadhead (2, Pierce; r2c6): Pierce's line is 0.75/1.5 m wider.
- Patience (3, Quick Shot; r4c7): Overcut gives 9/10/11% per second (from 8%), still up to 12.5 s.
- Extra Arrows (2, Spread; r5c6): Spread shoots 1/2 more arrows, across as many enemies; each cuts Heavy Draw.
- No Letup (2, Quick Shot; r7c7): the Streak lasts 5/6 s without a shot (from 4).
- Easy Release (2, Loose; r8c6): Loose takes a third / a quarter of the Streak (rounded up) instead of half.
- Keen Eye (5; r10c7): Sharpshooter shots have 1/2/3/4/5% more crit chance.

### Open talents (any spec)
- Conditioning (3; r2c4): 2/4/6% more maximum health.
- Catch Your Breath (2; r5c4): dropping below 35% health heals 10/20% of max health over 6 s (a heal over time, own meter line); once every 60 s.
- Pinned Down (2, Pin the Shadow; r9c4): Pin the Shadow takes 4/5 hits to break and lasts 2/4 s longer. (The extra hits are a per-application count in StatusContainer, sent to the host with the duration.)
