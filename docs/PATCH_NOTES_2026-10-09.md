# Patch notes — 9 October 2026

## Arcane melee
A new way to play the Arcane book: a melee damage dealer that fights with a weapon in each hand and replays its own hits. It has no resource bar; every ability runs on its cooldown alone. All six abilities require a one-handed melee weapon in the Main Hand and another in the Off Hand. Their weapon damage counts both weapons as a single hit.

### Traces
- Every strike you land with an Arcane melee ability leaves a Trace on you: a record of the damage that strike dealt. A critical strike leaves a bigger Trace.
- You hold up to 3 Traces. Each lasts 10 sec, and a new one pushes out the oldest.
- Strikes that leave a Trace: Swift Cut, Deep Cut, Late Cut and Wide Cut, and also Double Up, Missed Beat and Arcane Strike.
- Auto attacks, spells, damage over time and Encore's own hits leave no Trace.
- Traces are only kept once you have learned Encore.
- Your Traces are shown as a buff with a stack count. Its timer is the time until the oldest Trace runs out.
- "Trace" is a keyword: it is shown in orange and explained when you hold Shift.

### New abilities
- New ability: Swift Cut (Skill Card level 6, no cooldown). Strikes the target with both weapons, dealing 100% of the Main Hand and Off Hand weapons' combined damage as Arcane damage, and leaves a Trace.
- New ability: Deep Cut (Skill Card level 14, 6 sec cooldown). A heavy strike with both weapons, dealing 180% of the two weapons' combined damage as Arcane damage. Leaves a Trace.
- New ability: Encore (Skill Card level 18, 10 sec cooldown). Replays every Trace you hold on the target: each deals 60% of the damage it recorded. The Traces are used up. Replayed hits cannot critically strike, cannot be avoided and leave no Traces. Requires at least one Trace. Its damage has its own line on the damage meter.
- New ability: Late Cut (Skill Card level 24, 10 sec cooldown). Strikes the target with both weapons, dealing 80% of the two weapons' combined damage as Arcane damage, then hits it again for the same damage 3 sec later. Leaves one Trace, and the second hit is added to it when it lands. The second hit is lost if the target dies first.
- New ability: Wide Cut (Skill Card level 30, 8 sec cooldown). Strikes all enemies within 5 m with both weapons, dealing 70% of the two weapons' combined damage as Arcane damage to each. Leaves a single Trace, of its largest hit. Up to 5 enemies take full damage; with more, that damage is split evenly between all of them.
- New ability: Double Time (Skill Card level 40, 90 sec cooldown, off the global cooldown). For 10 sec, each of your strikes leaves 2 Traces and you can hold twice as many (6). Traces above the normal limit stay after it ends, until they run out or a new strike pushes them out.

### New talents
The melee talents run down the middle of rows 5 to 9 of the Arcane tree. Rows 5 and 8 each gained two slots for them.
- New talent: Practiced Hand (row 5, 3 ranks, requires Swift Cut). Swift Cut deals 3/6/9% more damage for each Trace you hold.
- New talent: Heavy Hand (row 5, 2 ranks, requires Deep Cut). The Trace Deep Cut leaves records 10/20% more damage than the strike dealt.
- New talent: Long Memory (row 6, 2 ranks, requires Encore). Your Traces last 2/4 sec longer.
- New talent: Clean Lines (row 6, 2 ranks, requires Deep Cut). When Swift Cut critically strikes, it takes 0.5/1 sec off the cooldown of Deep Cut.
- New talent: Standing Ovation (row 6, 3 ranks, requires Encore). Encore replays each Trace for 65/70/75% of the damage it recorded. Capstone: you can hold 1 more Trace.
- New talent: Curtain Call (row 7, 2 ranks, requires Encore). When Encore replays 3 or more Traces, it takes 1/2 sec off its own cooldown.
- New talent: Second Showing (row 7, 2 ranks, requires Encore). Encore has a 10/20% chance not to use up your Traces.
- New talent: No Loose Ends (row 8, 2 ranks, requires Late Cut). The second hit of Late Cut lands 0.5/1 sec sooner. Capstone: if the Trace of the first hit is gone when the second hit lands, the second hit leaves a Trace of its own.
- New talent: Time Signature (row 8, 2 ranks, requires Encore). Each Trace Encore replays takes 0.25/0.5 sec off the cooldowns of your other Arcane spells and abilities. Interrupts are not affected.
- New talent: Full House (row 9, 2 ranks, requires Wide Cut). When Wide Cut hits 3 or more enemies, it takes 1/2 sec off the cooldown of Encore.
- New talent: Dress Rehearsal (row 9, 2 ranks, requires Double Time). Double Time lasts 2/4 sec longer. Capstone: using Double Time resets the cooldown of Encore.

Links:
- Maxing Standing Ovation unlocks Second Showing, and maxing Second Showing unlocks Time Signature.

Tooltips:
- Late Cut's tooltip shows the delay of its second hit with No Loose Ends.
- Double Time's tooltip shows its duration with Dress Rehearsal.

### Encore's ghosts
- Encore now shows a ghost of your character for each Trace it replays: a see-through copy that steps out of you, runs straight through the target and fades out behind it.
- The ghosts set off one after the other, 0.1 sec apart, side by side, so their paths cross in the target.
- Each Trace's hit lands as its ghost reaches the target, so the hits arrive one by one instead of all at once. Six Traces are all replayed within a second.
- A hit whose ghost arrives after the target has died is lost.
- Your party sees the ghosts too.

### Action bar
- Encore shows how many Traces you hold on its button.
- Encore is dimmed while you have no Traces.

## Arcane tree: bottom row
The bottom row of the Arcane tree now holds three talents with 5 ranks each.
- New talent: Silvered (5 ranks). Each of your Reflections that shatters heals you for 0.3/0.6/0.9/1.2/1.5% of your maximum health. This includes the Reflections Trade Places gives up with Loud Exit. The healing has its own line on the meter: Silvered.
- New talent: Running Clock (5 ranks). The cooldowns of your Arcane spells and abilities recover 2/4/6/8/10% faster. Interrupts are not affected. It adds to Lapse and Interval Ward, which only speed up Arcane spells.
- New talent: Fine Edge (5 ranks). Your Arcane abilities deal 2/4/6/8/10% more damage while you wield a melee weapon in each hand. This covers the tank's and the melee's abilities, including Reflection shatters and Decoy's burst. Arcane spells are not affected.

## Arcane tree: open talents
These talents are themed to the Arcane book but work with every book's spells and abilities, so any build has a reason to spend points here. None of them needs an Arcane ability.
- New talent: Quick Study (row 1, 3 ranks). Increases your Haste by 1/2/3%.
- New talent: Two Minds (row 1, 3 ranks). The lower of your Spell Power and Attack Power is increased by 4/8/12% of the higher.
- New talent: Echo (row 2, 3 ranks). Your spells and abilities have a 2/4/6% chance to be repeated for 30% of the damage they dealt. For an Arcane spell or ability the chance is twice as high (4/8/12%) and the repeat deals 15% of the damage. Every hit rolls on its own; damage over time, auto attacks and other repeats are never repeated. The repeat lands 0.2 sec later, cannot critically strike or be avoided, and has its own line on the meter: Echo.
- New talent: Mirror Finish (row 4, 3 ranks). When you dodge, parry or block an attack, the attacker takes Arcane damage (46/92/138 at level 50 before gear). It has its own line on the meter: Mirror Finish.
- New talent: Overtime (row 4, 3 ranks). Buffs you put on yourself last 5/10/15% longer. Traces last longer too.
- New talent: Light Touch (row 5, 3 ranks). Your Arcane spells and abilities generate 5/10/15% less threat.
- New talent: Slipstream (row 6, 2 ranks). After Phase Step, Flicker, Static Step, Cinder Step or Icy Retreat, you move 10/20% faster for 3 sec.
- New talent: Borrowed Time (row 10, 5 ranks). When one of your spells or abilities with a cooldown of 20 sec or more comes off cooldown, your next spell or ability within 15 sec deals 3/6/9/12/15% more damage. If that spell or ability hits several enemies, all of them take the extra damage.

Two more talents for one ability each:
- New talent: Keep Moving (row 6, 2 ranks, requires Glint). The window Glint opens lasts 2/4 sec longer. Capstone: it covers 2 casts on the move instead of one.
- New talent: Full Crowd (row 9, 2 ranks, requires Crowd of One). Crowd of One creates 1/2 Reflections when you use it.

Talent trees:
- A row of a talent tree can now hold 5 talents (was 4). Rows 1, 2, 4, 5, 6 and 10 of the Arcane tree gained slots for the talents above. No existing talent moved.
- Glint's tooltip shows its window with Keep Moving.
