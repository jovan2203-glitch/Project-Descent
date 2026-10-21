# Arcane book

Values in Frost Bolts (FB) are conversation shorthand; real numbers live in balance.gd.

## Caster (built around cooldowns) - done
- Sigil Darts - channeled filler.
- Unravel - 2 s cast, no cooldown, 1.1 FB; each cast takes 1 s off other Arcane cooldowns.
- Countdown - 1.5 s cast, 12 s cooldown, own-only mark detonating after 5 s for 1.0 FB + 25% of the Arcane damage dealt to it.
- Convergence - 2.5 s cast, 20 s cooldown, 2.0 FB, +15% per Arcane spell on cooldown, up to 5.
- Rewind - instant off GCD, 45 s cooldown, resets the last Arcane spell cast with a cooldown under 15 s.
- Lapse - instant off GCD, 90 s cooldown, 8 s of Arcane cooldowns recovering twice as fast.
- Mirror Sigil - 1.5 s cast, 30 s cooldown, 12 s ground sigil repeating Arcane spells at 35%, own meter line.
- Collapse - 2 s cast, 10 s cooldown, 6 m, implodes after 1.5 s for 1.4 FB, pulls 3 m to the centre.
- Scatter - instant, 8 s cooldown, next Sigil Darts splits across up to 3 enemies, +30% per dart.
- Interval Ward - instant, 20 s cooldown, 8 s shield ~1.5 FB; Arcane cooldowns 15% faster while it holds; if broken early, remaining duration comes off its cooldown.
- Glint - instant, 6 s cooldown, 30 m, 0.7 FB, usable on the move; for 4 s the next Unravel or Sigil Darts can be cast while moving.
- Phase Step - blink.

## Dodge tank (Reflections, requires dual wield)
- Up to 4 Reflections, 30 s each, each +5% Dodge and +5% Dodge cap (30% to 50% at four). They stand left/right/front/back, close (~20% clipping), purplish and glassy-blurry.
- A dodge makes one take the hit and shatter: 0.3 FB within 5 m, high threat, own meter line; each shatter takes 0.5 s off all Arcane cooldowns.
- Double Up - 5 s cooldown, 1.0 weapon damage as Arcane with both weapons, high threat, creates 1.
- Ripple - 8 s cooldown, 0.5 FB within 6 m, high threat, creates 1 if it hits 3+ enemies.
- Full Set - 30 s cooldown, fills to 4.
- Missed Beat - within 4 s of a shatter, off GCD, 3 s cooldown, 1.0 weapon damage with both weapons, high threat.
- Stand-In - 25 s cooldown, 4 s: a hit that gets through destroys a Reflection instead.
- Trade Places - off GCD, 30 s cooldown, sacrifices all; heals 20% of damage taken in the last 3 s per Reflection.
- Crowd of One - 90 s cooldown, 8 s: dodges don't consume Reflections.
- Decoy - 90 s cooldown, sends 1 Reflection to a spot as a real attackable image; enemies within 8 m forced to attack it for 3 s, then it bursts for 0.5 FB.

## Melee DPS (Traces, dual wield)
- Strikes leave Traces; the finisher Encore replays them (no cooldown). Replays are shown as ghosts of the player running through the enemy.
- Strikes: Deep Cut, Late Cut (second hit), Wide Cut, Swift Cut. Double Time raises the Trace limit; when it ends with extra Traces held, they are kept and usable but no new ones are gained.

## Talents
- Caster: Seventh Sigil (2): 1/2 more darts. Etched Darts (3): dart crit 10/20/30% chance to take 0.5 s off Countdown and Collapse. Frayed (3): an Unravel crit takes its time off twice, 33/67/100%. Chain Reaction (3): Countdown's detonation deals 10/20/30% of its bonus within 5 m. Polished Glass (3): Mirror Sigil 38/41/45%. Deep Well was folded into Collapse (it pulls 5 m); its slot is empty. Aftershock (3): pulled enemies slowed 13/27/40% for 3 s. Long Step (2): blinks go 1/2 m further. Keep Moving (3, Glint): window +1.5/2.5/4 s, capstone two casts on the move.
- Tank: Light Feet (3, generic): +1/2/3% Dodge while dual wielding. Sharp Edges (3): shatters +10/20/30%, capstone radius 7 m. Clockwork (2): shatters take 0.25/0.5 s more off cooldowns. Spare Copy (2): 10/20% chance a dodge keeps the Reflection. Empty Room (3): 4/8/12% less damage with no Reflections. Bent Light (2): 1/2% less magic damage per Reflection. Second Self (3): Double Up 10/20/30% chance for 2. On the Beat (3): Missed Beat +10/20/30%, capstone creates a Reflection when used with none. Wide Rings (3): Ripple +0.7/1.3/2 m, capstone Reflection from 2 enemies. Head Count (3): Full Set heals 1.5/2.5/4% max health per Reflection created. Understudy (3): each Reflection destroyed in Stand-In takes 1.5/2.5/4 s off its cooldown. Loud Exit (1): Reflections given up by Trade Places shatter. Good Likeness (3): Decoy holds 0.7/1.3/2 s longer, capstone costs no Reflection. Full Crowd (2): Crowd of One creates 1/2 Reflections.
- Melee: Heavy Hand (3): Deep Cut's Trace records 7/13/20% more. No Loose Ends (3): Late Cut's second hit 0.3/0.7/1 s sooner; capstone it can leave its own Trace if Encore used the first. Full House (2): Wide Cut hitting 3+ enemies: next Encore also replays on 1/2 nearby enemies for half damage. Curtain Call (3): replaying 3+ Traces, each replay +7/13/20%. Dress Rehearsal (3): Double Time +1.5/2.5/4 s; capstone the first Encore during Double Time doesn't use up Traces. Practiced Hand (3): Swift Cut +3/6/9% per Trace held. Time Signature (3): each Trace replayed takes 0.15/0.35/0.5 s off other Arcane cooldowns.
- Bottom row (5 ranks): Running Clock (Arcane cooldowns 2-10% faster), Silvered (each shatter heals 0.3-1.5% max health), Fine Edge (Arcane abilities +2-10% while dual wielding), Borrowed Time.
- Open: Quick Study (3): +1/2/3% Haste. Two Minds (3): lower of SP/AP +4/8/12% of the higher. Light Touch (3): Arcane threat -5/10/15%. Overtime (3): self-buffs 5/10/15% longer. Echo (3): 2/4/6% chance to repeat at 30% (Arcane: double chance, 15% damage), own meter line. Mirror Finish (3): dodge/parry/block deals 0.1/0.2/0.3 FB Arcane to the attacker. Slipstream (2): 10/20% faster for 3 s after a blink or dash.

## Runes
- Epic Carried Sigil: Mirror Sigil follows you, at 20% instead of 35%.
- Rare: after Glint, any spell can be cast or channelled on the move once.
- Rare Two-Way Mirror: Mirror Sigil also repeats shatters at 35%.
- Rare Afterimage (see Lightning).

## Utility (the book's "Utility" divider) - BUILT 2026-10-17
- Fixed Point (Arcane's root) - instant, 20 s cooldown, 2 mana, 30 m. Roots the target 3 s, +0.5 s per other Arcane spell of yours on cooldown, up to 6 s. Code: scripts/player/utility.gd.
- Also in Utility (coded with their specs): Unweave (Counterspell), Phase Step, Interval Ward.
- No party tool yet. A rewind of allies' positions (Undo) was turned down: easy to troll teammates with.
