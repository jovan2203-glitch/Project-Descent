# Martial book

No magic, only technique. Physical damage; everything scales like an ability (mostly Attack Power). Values in Frost Bolts (FB) are conversation shorthand; real numbers go in balance.gd.

## The wipe (2026-10-17)
- All 16 old abilities (Heavy Blow, Headsman's Cut, Steady Shot, Stoneguard, Taunt, ...) were removed. The book is rebuilt from this file.

## Specs (planned)
- Warrior - two-handers, Fury: the Wheel (below). FINAL DRAFT 2026-10-19.
- Rogue - dual wield, Energy: Flow and the Kill window (below). BUILT 2026-10-20.
- Brawler - the tank, Fury: pugilist / mixed martial artist (below). DRAFT 2026-10-20. Takes the old Tank and Brawler slots.
- Sharpshooter - the archer, bow, no resource: the Reset Engine (below). BUILT 2026-10-21.
- Utility divider: Pin the Shadow (root), Over the Shoulder, Play Dead, Stone Throw (interrupt) (below).

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
- **Stone Throw** (Martial's interrupt, 2026-10-28): 15 s (the shared interrupt cooldown), off the GCD, 25 m. A cast is interrupted (3 s lockout). With no cast, the stone knocks aside the melee hit the enemy is winding up (its tell): that hit never lands. The only interrupt that works on melee tells. Card level 16. Code: martial_rogue.gd `_stone_throw`, enemy.gd `interrupt(..., tells)`.


## Brawler (tank) - BUILT 2026-10-20 (scripts/player/martial_brawler.gd)
Numbers are drafts (balance.gd). Built with: strikes 0.27 FB and +10 Fury each (the Fury scale's minimum gain), Rapid Fists 0.45, Haymaker 1.1, Sweep 0.4, Roundhouse 0.5, Throw 0.6, Reversal 1.0, Come On 8 s cooldown / 3 s taunt; balance sim ~2200 geared DPS (tank range). Fighting Style changes the strike visuals only for now (no unarmed animation set on the placeholder body yet). A pugilist / mixed martial artist: wraps, footwork, clinches, takedowns, haymakers. Not a monk and not a copy of WoW's Brewmaster (legal reasons): no chi, robes, meditation, palms, brews, drunken or animal stances, and the delayed-damage pool has its own name and its own way of clearing it.

### Bruise (takes the hit, pays it later)
- Needs the stance **Put 'Em Up** (2026-10-29; comes with Punch, off the GCD, 1 s cooldown, a toggle, saved). In it, Bruise works and all your damage that is not Physical is 60% lower (a straight multiplier on the hit, so mixing in other books' spells costs a lot). Out of it, no Bruise. Brawler only.
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
- Leaving combat makes the held weapon whole again (Cracks cleared, 4 uses). Out of combat, clicking the held weapon in the Wheel tracker above the action bar turns it to the next weapon, so you choose your opening weapon. In combat the order never changes.
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
- Readability: a Cracks buff (one stack per Crack), the Wheel tracker group (weapons in order, the held one large, its uses left and Cracks) and the Crack count on the Break button.

## Talents (Martial tree) - REBUILT 2026-10-22, on ribbons 2026-10-26
The first book rebuilt for spec groups (docs/design/systems.md, "Talents", "Ribbon layout"). Numbers are drafts (talents.gd, balance.gd).
- **Layout:** 10 rows × 13 columns. The Wheel takes columns 1-3, the Rogue 4-6, the open talents 7 (the spine), the Brawler 8-10 and the Sharpshooter 11-13.
- **Ribbons:** each spec's 18 talents in rows 1-9 form its shape. Row 10 holds each spec's 5-rank capstone, which needs 15 points in that spec.
- **Size:** 84 talents. Each spec has 19 (50-55 ranks); the open column has 8. Only 15 need one ability (18%).
- **Links:** Twice Over -> Gather Pace, Steady Pace -> Deep Flow, Mix It Up -> Hot Start, Get Up -> Back Up, Clean Release -> Run It Back.
- **Code:** each spec's component, plus scripts/player/martial_talents_open.gd for the open talents and the damage-line bonuses. Every damage bonus has its own meter line.

### The Wheel (keywords: Fury, Cracks, finishers, weapons breaking, riders, Stagger, Weapon Arts)
Its seals form a wheel.

| Row | Left | Middle | Right |
|---|---|---|---|
| 1 |  | Hard Break (4): finishers +5/10/15%; capstone: a 6+ Crack finisher gives 20 Fury |  |
| 2 | Iron Grip (3): Fillers give 2/4/6 more Fury |  | Well Drilled (2): Weapon Arts add 1/2 Cracks |
| 3 | Heavy Hands (3): Heavy Fillers +5/10/15% |  | Fresh Steel (2): a weapon flies in with 1/2 Cracks |
| 4 | Sharp Fragments (3): +0.5/1/1.5% crit per Crack on the held weapon | Wide Cleave (2, Greataxe): Axe Cleave hits 1/2 more | Weight Behind It (3): ability hits +1/2/3% per use the held weapon has taken |
| 5 | Keen Edge (3, Greatsword): crits +7/13/20% while held |  | Breaking Point (3): the ability taking a weapon's last use (or Break) +10/20/30% |
| 6 | Ringing Blows (3): each Axe Cleave / Second Hit gives 1/2/3 Fury | Twice Over (3, Halberd): Second Hit 23/27/30% | Rattled (3, Maul): +17/33/50% Stagger |
| 7 | Off Balance (3): +5/10/15% to an enemy you knocked down |  | Spare Parts (3): a breaking weapon gives 1/2/3 Fury per Crack |
| 8 | Big Swing (2): Heavy Fillers 25/50% chance of one more Crack |  | Clean Swap (3): 3 s after a weapon breaks, abilities +4/8/12% |
| 9 |  | Gather Pace (2): Weapon Art cooldowns 10/20% shorter |  |
| 10 |  | Turning Wheel (5): each weapon broken in the last 15 s gives 0.5-2.5% more damage |  |

### Rogue (keywords: Energy, Flow, Kill window and Kill forms, stuck daggers, range switch, thrown and melee hits)
Its seals form crossed daggers.

| Row | Left | Middle | Right |
|---|---|---|---|
| 1 | Clean Kill (4): Kill forms +5/10/15%; capstone: Close It Out leaves 3 Flow |  | Thrift (3): Energy costs 1/2/3 less (any ability that costs Energy) |
| 2 | In and Out (2): a range switch gives 2/3 Flow |  | Spare Knives (2): 4/5 daggers stick in one enemy |
| 3 | Barbed (3): Ripped Out +20/40/60% |  | Thrown Weight (3): thrown hits +5/10/15% |
| 4 | Steady Pace (3): Flow holds 3.7/4.3/5 s | Close Work (3): melee ability hits +5/10/15% | Mix It Up (3): Variety +0.65/0.85/1 s |
| 5 |  | Fresh Legs (3): Kill-window crits refund 12/14/16 Energy |  |
| 6 | Deep Flow (2): Flow up to 11/12 |  | Hot Start (3): Kill windows 0.5/1/1.5 s longer |
| 7 | Easy Pickings (3): +5/10/15% to an enemy with 3+ of your daggers |  | Footloose (3): a range switch gives 3/6/9 Energy |
| 8 | Finish Strong (3, Close It Out): +10/20/30% |  | Cold Read (2): after a Kill window, the next 1/2 Rogue hits build double Flow |
| 9 | Light Fingers (2, Snatch): 25/50% chance to lift two things |  | Pressure Point (3): outside a Kill window, crits 10/20/30% chance of one more Flow |
| 10 |  | In the Zone (5): each Flow gives 0.1-0.5% crit |  |

### Brawler (keywords: Fury, Bruise, strikes, chain moves and strong moves, Catch, knockdowns, threat)
Its seals form a fist.

| Row | Left | Middle | Right |
|---|---|---|---|
| 1 | Soak It Up (4): Bruise takes 42/44/46%; capstone: Shake Off clears 40% | Tight Clinch (3, Elbow): Clinch 4.7/5.3/6 s | Quick Feet (3): strikes give 1/2/3 more Fury |
| 2 | Heavy Bag (3): strong moves +5/10/15% | Soft Catch (3, Catch): 17/33/50% of a caught hit still goes into Bruise | Calluses (3): Bruise ticks give 10/20/30% more Fury |
| 3 | Wide Stance (3): Sweep / Roundhouse reach 0.7/1.3/2 m further | Knockout (3, Punch): Haymaker +10/20/30% | Slow Burn (2): Bruise over 7.5/9 s |
| 4 | Crowd Work (3): Sweep / Roundhouse 2/4/6 Fury per enemy hit (up to 3) | Counter Puncher (3, Catch): Catch strings +10/20/30% | Get Up (2): Shake Off heals 3/6% max health (its own meter line) |
| 5 |  | Bad Intentions (3): chain moves +10/20/30% threat |  |
| 6 |  | Hardened (2): with Bruise above 20% of max health, take 3/6% less |  |
| 7 |  | Iron Chin (3): while clinching, take 2/4/6% less from every enemy |  |
| 8 |  | Last Laugh (3): Haymaker clears 5/10/15% of Bruise |  |
| 9 | Ground Game (2): Throw / Takedown knock down 0.5/1 s longer |  | Back Up (3): Shake Off gives 5/10/15 Fury |
| 10 |  | Scar Tissue (5): Bruise deals 2-10% less |  |

### Sharpshooter (keywords: cuts, resets, Overcut, Streak, engine shots, Loose)
Its seals form a scope.

| Row | Left | Middle | Right |
|---|---|---|---|
| 1 | Quick Release (3): cuts 5/10/15% longer | Full Draw (4, Heavy Draw): +5/10/15%; capstone: its cuts are 3 s | Broadhead (3, Pierce): line 0.5/1/1.5 m wider |
| 2 |  | Deep Hold (2): Overcut up to 15/17.5 s |  |
| 3 | Patience (3): Overcut 9/10/11% per second |  | On a Roll (3): each Streak 2.2/2.4/2.6% |
| 4 | Lucky Shot (3): a crit also cuts every other shot 1/2/3 s | Extra Arrows (2, Spread): 1/2 more arrows | No Letup (3): Streak holds 4.7/5.3/6 s |
| 5 | Long Range (3): +1/2/3% per 5 m beyond 10 m |  | Easy Release (2, Loose): Loose takes a third / a quarter |
| 6 | Waiting Game (3): a shot gains 1/2/3 s of Overcut every 3 s it stays ready | Clean Release (3): firing a shot with 6+ s of Overcut gives 1/2/3 Streak | Long Streak (2): Streak up to 11/12 |
| 7 | Second Arrow (3): engine shots 5/10/15% chance of a second arrow at 30% (its own meter line) |  | Hard Target (3): +5/10/15% to enemies above 80% health |
| 8 |  | Run It Back (3): a full reset 10/20/30% chance to cut the next shot in the chain 2 s |  |
| 9 |  | Hold Steady (2): while a shot holds 6+ s of Overcut, the other shots +4/8% |  |
| 10 |  | Keen Eye (5): shots +1-5% crit |  |

### Open talents (any spec; column 7, the spine)
- Weapon Training (3): auto-attacks +4/8/12% (its own meter line).
- Conditioning (3): +2/4/6% max health.
- Keen Strikes (3): ability crits +3/6/9%.
- Hardy (3): natural health regen 10/20/30% faster.
- Catch Your Breath (2): below 35% health, heal 10/20% of max health over 6 s, once a minute.
- Footing (2): 3/6% movement speed.
- Grit (2): below 50% health, 3/6% more damage. (Not a crowd-control duration talent: that would copy Shadow's Left Hanging.)
- Pinned Down (2, Pin the Shadow): 4/5 hits to break, 2/4 s longer.
