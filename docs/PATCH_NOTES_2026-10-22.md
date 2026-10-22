# Patch notes — 22 October 2026 (0.0.20)

Steady Flame becomes the game's first Fury caster, the Martial talent tree is rebuilt on a new layout with its specs side by side, the talent trees get their first choice talent, and tanks trade damage for threat. Damage is given at level 50 before gear. Mana costs are in mana points; one point is 10% of your base mana.

## Fire

### Steady Flame (caster): Fury

Steady Flame no longer uses mana. Its spells build Fury or spend it: you want to avoid critical strikes, but crit chance still makes your Fury grow faster.

- New: Fury for Steady Flame. Each of your Fire spells that does not critically strike gives you 6 Fury plus 0.6 for every 1% of your critical strike chance, once per cast however many enemies it hits. Damage over time, procs and spells that cost Fury give none.
- New: Venting. Each Fire spell critical strike of yours Vents 50% of your Fury: it is lost, and the critical strike still deals its full damage.
- New: Your Fury does not drop while you are casting or channeling a spell. Otherwise it drops by 5 a second, as before.
- Changed: Firebolt costs nothing (was 1 mana) and deals 460 Fire damage (was 575). It gives Fury when it does not critically strike.
- Changed: Ember Volley costs nothing (was 3 mana). Each ember rolls its own critical strike: each one that does not crit gives a third as much Fury as a spell, and each one that does Vents your Fury.
- Changed: Blaze costs nothing (was 2 mana). It deals no damage when it lands, so it gives no Fury.
- Changed: Vent Flames now spends all your Fury (was 3 mana) and needs at least 20. It deals 920 Fire damage plus 0.5% more for each Fury spent, and always critically strikes; that critical strike does not Vent your Fury. It no longer deals extra damage from your critical strike chance (was 50% of it).
- Changed: Kiln Blast costs 40 Fury (was 3 mana) and can no longer critically strike. It still deals 1,380 Fire damage, 20% more to a target with your Blaze.
- Changed: Stoke costs 20 Fury (was 2 mana).
- Changed: Flame Nova costs 30 Fury (was 4 mana).
- Changed: Wall of Fire costs 30 Fury (was 4 mana).
- Changed: Crucible costs 20 Fury (was 3 mana). Moving it while it stands is still free.
- Changed: Cool Head also means its 15 sec never Vent your Fury, since nothing can critically strike.
- Removed: Slow Fuse.
- Removed: Rekindle.
- Changed: Fire's Utility spells (Furnace Breath, Cinder Step, Cooling Slag, Bellows, Heat Sink, Cinderwing) keep their mana costs. Those that deal damage give Fury when they do not critically strike.

### Talents

- New talent: Damped Embers or Wild Embers (row 5, 3 ranks, requires Ember Volley). The Fire tree's first choice talent: one slot holds both, and your points go into only one of them.
  - Damped Embers: the embers of your Ember Volley have 10 / 20 / 30% less critical strike chance.
  - Wild Embers: the embers of your Ember Volley have 10 / 20 / 30% more critical strike chance.
- New talent: Blowback (row 6, 3 ranks). When a critical strike of yours Vents your Fury, 20 / 35 / 50% of the Fury it Vents burns the target for 14 Fire damage per point, dealt over 4 sec. It has its own damage-meter line.
- New talent: Stoked Breath (row 1, 2 ranks), in place of Banked Mana. Your Fire spells that do not critically strike give you 10 / 20% more Fury.
- Changed: Smoldering Focus: your Fire spells deal 0.02 / 0.04 / 0.06 / 0.08 / 0.1% more damage for each point of Fury you have (up to 10% at 100 Fury). Before, Fire spells that did not crit built stacks that your next Fire spell crit spent.
- Changed: Banked Coals: your critical strikes Vent 25 / 50% less of your Fury. Before, spent Smoldering Focus and Afterburn stacks kept 25 / 50% of themselves.
- Removed: Banked Mana (row 1). Points refunded.
- Removed: Volatile Fuse (row 5). Points refunded.
- Removed: Flashover (row 6). Points refunded.

### Runes

- New rune: Rune of the Sealed Kiln (Epic, level 10). Your critical strikes no longer Vent your Fury, but your Fire spells give you 30% less of it.
- Changed: Rune of the Dull Mind: your Fire spells also give you Fury as if your critical strike chance were not capped. It still caps crit at 10% and turns the rest into Spell Power.
- Changed: Rune of the Hair Trigger: Vent Flames still has 2 charges, but each one spends only half your Fury and deals its bonus for what it spent.

### Slagforged (tank)

- Changed: Brand deals your weapon damage plus 460 Fire damage (was plus 138), with 5x threat (was 3x).
- Changed: Anvil deals half your weapon damage plus 299 Fire damage (was plus 138), with 6x threat (was 4x).

## Frost

- Changed: Lingering Frost (row 8): your Chilled lasts 1 / 2 / 3 sec longer. Before, all your Frost damage over time lasted 1 / 2 / 3 sec longer.
- Changed: Cold Draw (row 1): your hits on a target you have Chilled or Frozen give you 2 / 4 / 6 Energy, 2 / 4 / 6 Fury and 0.1 / 0.2 / 0.3 mana points, once every 1 sec. Before, only arrow abilities gave Energy, every time they hit.
- Changed: Shattering Slam deals 190% of your weapon damage (was 150%), with 5x threat (was 3x).
- Changed: Rimequake deals 299 Frost damage (was 230).

## Lightning

- Changed: Return Stroke deals 100% of your weapon damage (was 120%).

## Holy

- Changed: Censer Swing deals 230 Holy damage (was 322), with 3x threat (was 4x).
- Changed: Pour Out has 4x threat (was 6x).

## Martial

The Martial talent tree is rebuilt as the first book on the new column-group layout. Each spec has its own two columns: the Wheel on the left, then the Rogue, the open talents in the middle, then the Brawler, and the Sharpshooter on the right. Each spec now has 19 talents (50 to 55 ranks), mostly built on its own resources and mechanics rather than on single abilities. A spec's bottom-row talent needs 25 points spent in that spec. All Martial talent points have been refunded.

### The Wheel

- Changed: Hard Break and Well Drilled no longer require the Greataxe.
- New talent: Iron Grip (row 1, 3 ranks). Your Fillers give you 2 / 4 / 6 more Fury.
- New talent: Heavy Hands (row 2, 3 ranks). Your Heavy Fillers deal 5 / 10 / 15% more damage.
- New talent: Fresh Steel (row 3, 2 ranks). A weapon that flies into your hands already has 1 / 2 Cracks on it.
- New talent: Sharp Fragments (row 3, 3 ranks). Each Crack on the weapon you hold gives you 0.5 / 1 / 1.5% critical strike chance.
- New talent: Weight Behind It (row 4, 3 ranks). Your ability hits deal 1 / 2 / 3% more damage for each use the weapon you hold has already taken.
- New talent: Breaking Point (row 5, 3 ranks). The ability that takes a weapon's last use, or breaks it, deals 10 / 20 / 30% more damage.
- New talent: Ringing Blows (row 6, 3 ranks). Each Axe Cleave and Second Hit gives you 1 / 2 / 3 Fury.
- New talent: Off Balance (row 7, 3 ranks). Your hits deal 5 / 10 / 15% more damage to an enemy you have knocked down.
- New talent: Spare Parts (row 8, 3 ranks). When a weapon of yours breaks, you gain 1 / 2 / 3 Fury for each Crack it had.
- New talent: Big Swing (row 8, 2 ranks). Your Heavy Fillers have a 25 / 50% chance to add one more Crack.
- New talent: Clean Swap (row 9, 3 ranks). For 3 sec after a weapon of yours breaks, your abilities deal 4 / 8 / 12% more damage.
- New talent: Gather Pace (row 9, 2 ranks). The cooldowns of your Weapon Arts are 10 / 20% shorter.
- Moved: Wide Cleave, Keen Edge, Twice Over and Rattled are in rows 4 to 7. Turning Wheel is the Wheel's bottom-row talent.

### Rogue

- Changed: Clean Kill, Barbed and Mix It Up no longer require an ability.
- New talent: Thrift (row 1, 3 ranks). Your abilities that cost Energy cost 1 / 2 / 3 less.
- New talent: Spare Knives (row 2, 2 ranks). Up to 4 / 5 of your daggers can stick in one enemy, instead of 3.
- New talent: Thrown Weight (row 3, 3 ranks). Your thrown hits deal 5 / 10 / 15% more damage.
- New talent: Close Work (row 4, 3 ranks). Your melee ability hits deal 5 / 10 / 15% more damage.
- New talent: Fresh Legs (row 5, 3 ranks). Your critical strikes in a Kill window give you 12 / 14 / 16 Energy back, instead of 10.
- New talent: Deep Flow (row 6, 2 ranks). Your Flow goes up to 11 / 12 stacks, instead of 10.
- New talent: Hot Start (row 6, 3 ranks). Your Kill windows open 0.5 / 1 / 1.5 sec longer.
- New talent: Easy Pickings (row 7, 3 ranks). Your hits deal 5 / 10 / 15% more damage to an enemy with 3 or more of your daggers stuck in it.
- New talent: Footloose (row 7, 3 ranks). A hit from a different range than your last one also gives you 3 / 6 / 9 Energy.
- New talent: Finish Strong (row 8, 3 ranks, requires Close It Out). Close It Out deals 10 / 20 / 30% more damage.
- New talent: Cold Read (row 8, 2 ranks). After a Kill window ends, your next 1 / 2 Rogue ability hits build twice as much Flow.
- New talent: Light Fingers (row 9, 2 ranks, requires Snatch). Snatch has a 25 / 50% chance to lift two things instead of one.
- New talent: Pressure Point (row 9, 3 ranks). Outside a Kill window, your critical strikes have a 10 / 20 / 30% chance to give you one more Flow.
- Moved: In and Out, Steady Pace and Mix It Up are in rows 2, 4 and 5. In the Zone is the Rogue's bottom-row talent.

### Brawler

- Changed: Soak It Up and Wide Stance no longer require an ability.
- New talent: Quick Feet (row 1, 3 ranks). Your strikes give you 1 / 2 / 3 more Fury.
- New talent: Heavy Bag (row 2, 3 ranks). Your strong moves (a chain of three different strikes) deal 5 / 10 / 15% more damage.
- New talent: Calluses (row 3, 3 ranks). Your Bruise ticks give you 10 / 20 / 30% more Fury.
- New talent: Slow Burn (row 5, 2 ranks). Your Bruise is dealt to you over 7.5 / 9 sec, instead of 6.
- New talent: Counter Puncher (row 5, 3 ranks, requires Catch). Your Catch strings (Turn It Around, Throw, Reversal and Takedown) deal 10 / 20 / 30% more damage.
- New talent: Crowd Work (row 6, 3 ranks). Your Sweep and Roundhouse give you 2 / 4 / 6 Fury for each enemy they hit, up to 3 enemies.
- New talent: Get Up (row 6, 2 ranks). Your Shake Off also heals you for 3 / 6% of your maximum health.
- New talent: Bad Intentions (row 7, 3 ranks). Your chain moves make 10 / 20 / 30% more threat.
- New talent: Hardened (row 7, 2 ranks). While your Bruise holds more than 20% of your maximum health, you take 3 / 6% less damage.
- New talent: Iron Chin (row 8, 3 ranks). While you have an enemy in your Clinch, you take 2 / 4 / 6% less damage from every enemy.
- New talent: Last Laugh (row 8, 3 ranks). Your Haymaker clears 5 / 10 / 15% of your Bruise.
- New talent: Back Up (row 9, 3 ranks). Your Shake Off gives you 5 / 10 / 15 Fury.
- New talent: Ground Game (row 9, 2 ranks). Your Throw and Takedown keep enemies down 0.5 / 1 sec longer.
- Moved: Tight Clinch, Soft Catch and Knockout are in rows 2 to 4. Scar Tissue is the Brawler's bottom-row talent.

### Sharpshooter

- Changed: Patience no longer requires Quick Shot.
- New talent: Quick Release (row 1, 3 ranks). The time your shots take off your other shots is 5 / 10 / 15% longer.
- New talent: Deep Hold (row 2, 2 ranks). Your Overcut goes up to 15 / 17.5 sec, instead of 12.5.
- New talent: On a Roll (row 3, 3 ranks). Each stack of your Streak gives 2.2 / 2.4 / 2.6% more damage, instead of 2%.
- New talent: Lucky Shot (row 4, 3 ranks). Your shots that critically strike also take 1 / 2 / 3 sec off each of your other shots.
- New talent: Long Range (row 5, 3 ranks). Your shots deal 1 / 2 / 3% more damage for every 5 m the target is beyond 10 m.
- New talent: Waiting Game (row 6, 3 ranks). A shot of yours gains 1 / 2 / 3 sec of Overcut for every 3 sec it stays ready.
- New talent: Clean Release (row 7, 3 ranks). Firing a shot that holds 6 sec or more of Overcut gives you 1 / 2 / 3 Streak.
- New talent: Long Streak (row 7, 2 ranks). Your Streak goes up to 11 / 12, instead of 10.
- New talent: Second Arrow (row 8, 3 ranks). Your engine shots have a 5 / 10 / 15% chance to loose a second arrow that deals 30% of their damage. It has its own damage-meter line.
- New talent: Hard Target (row 8, 3 ranks). Your shots deal 5 / 10 / 15% more damage to enemies above 80% health.
- New talent: Run It Back (row 9, 3 ranks). When a cut of yours resets a shot fully, it has a 10 / 20 / 30% chance to also take 2 sec off the next shot in the chain.
- New talent: Hold Steady (row 9, 2 ranks). While one of your shots holds 6 sec or more of Overcut, your other shots deal 4 / 8% more damage.
- Moved: Broadhead, Patience, Extra Arrows, No Letup and Easy Release are in rows 2 to 6. Keen Eye is the Sharpshooter's bottom-row talent.

### Open talents

- New talent: Weapon Training (row 1, 3 ranks). Your auto-attacks deal 4 / 8 / 12% more damage. It has its own damage-meter line.
- New talent: Keen Strikes (row 3, 3 ranks). Your ability critical strikes deal 3 / 6 / 9% more damage.
- New talent: Hardy (row 4, 3 ranks). Your natural health regeneration is 10 / 20 / 30% faster.
- New talent: Footing (row 6, 2 ranks). You move 3 / 6% faster.
- New talent: Grit (row 8, 2 ranks). While you are below 50% health, you deal 3 / 6% more damage.
- Moved: Conditioning, Catch Your Breath and Pinned Down are in rows 2, 5 and 9.

## Systems & Interface

- New: The column-group talent layout, for the Martial book first. Each spec has its own columns, with faint lines between the specs and each spec's name and points above its columns. A spec's bottom-row talent needs 25 points spent in that spec; the other rows still open across all books as before.
- Changed: Hits that get several critical strike bonuses at once (for example Keen Edge and Keen Strikes) now get all of them, each on its own damage-meter line.

- New: Tanks deal 35% of their damage, and make 1.4x threat for it. You count as a tank when your action bars make you one. A tank playing well deals about a third of a top damage dealer's damage and makes about 1.3 to 1.7 times its threat, so a big burst, a critical strike spike or an early opener can pull aggro. The damage numbers in these notes are before this.
- New: Choice talents. A talent slot can hold two talents, and your points go into only one of them. Hover the slot to see both and pick one; refunding all its points frees the other. The slot shows both icons split down the middle until you choose.
- Changed: All talent points have been refunded, because the talent trees changed.

## Fixes

- Fixed: The Halberd's icon on the Wheel's buttons no longer fails to draw its hook.
