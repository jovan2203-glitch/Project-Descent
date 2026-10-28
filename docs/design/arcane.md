# Arcane book

Values in Frost Bolts (FB) are conversation shorthand; real numbers live in balance.gd.

## Caster (built around cooldowns) - done
- Sigil Darts - channeled filler.
- Unravel - 2 s cast, no cooldown, 1.3 FB; each cast takes 1 s off other Arcane cooldowns.
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
- Double Up - the filler: no cooldown, 0.45 weapon damage as Arcane with both weapons, high threat, creates 1.
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

## Talents (ribbon tree, 2026-10-26)
Layout: 13 columns. Clockwork 0-2 (clock face), Hall of Mirrors 3-5 (hand mirror), the open talents on the spine (6), Second Act 7-9 (stage curtains), Aetherstring 10-12 (an empty short ribbon until the bow is built; Talents.UNFINISHED_SPECS). Each finished spec: 18 talents in rows 1-9 and a 5-rank capstone gated at 25 points. 16 of the 66 need one ability. Numbers: talents.gd and balance.gd; code: scripts/player/arcane_talents.gd and each spec's component.
- Keywords: Arcane cooldowns (time taken off, spells on cooldown, coming off cooldown), Arcane spell crits, mana, moving, roots; Reflections (created, held, shattered), dodges, dual wield, threat; Traces (left, held, replayed), replays, cuts, low health.
- Clockwork: Etched Darts (any Arcane spell crit takes time off the others) -> Sharp Mind (link), Seventh Sigil (Sigil Darts), Frayed (Unravel), Pinned in Time, Thrifty Mind, Polished Glass (Mirror Sigil), Chain Reaction (Countdown), Wound Up, Clock Hands, Moving Parts, Second Hand -> Unwinding (link), Keep Moving (Glint), Aftershock (Collapse), Light Touch, On the Dot, Turning Gears. Capstone: Running Clock.
- Hall of Mirrors: Light Feet, Sharp Edges -> Glass Dust (link), Spare Seconds, Second Self (any Reflection created may make one more), Head Count (every Reflection created heals), Glass Armor, Empty Room, Wide Rings (Ripple), Bent Light, Quick Answer -> Spare Copy (link), Last Copy -> Crowded Room (link), On the Beat (Missed Beat), Understudy (Stand-In), Good Likeness (Decoy), Full Crowd (Crowd of One). Capstone: Silvered. Loud Exit was folded into Trade Places (its Reflections always shatter).
- Second Act: Long Memory, Standing Ovation -> Time Signature (link), Fresh Trace, Practiced Hand (any Arcane ability, per Trace held), Heavy Hand (Deep Cut), Clean Lines (Deep Cut), Keen Cuts, Quick Cuts, Twin Blades, Curtain Call, Second Showing, No Loose Ends (Late Cut), Full Stage, Full House (Wide Cut), Final Act, Dress Rehearsal (Double Time), Curtain Rise. Capstone: Fine Edge.
- Open (spine): Quick Study, Two Minds, Echo, Mirror Finish, Overtime, Slipstream (any movement spell or ability), Long Step (blinks), Spare Moment (cooldowns of 20 s or more recover faster), Borrowed Time (3 ranks).

## Runes
- Epic Carried Sigil: Mirror Sigil follows you, at 20% instead of 35%.
- Rare: after Glint, any spell can be cast or channelled on the move once.
- Rare Two-Way Mirror: Mirror Sigil also repeats shatters at 35%.
- Rare Afterimage (see Lightning).

## Utility (the book's "Utility" divider) - BUILT 2026-10-17
- Fixed Point (Arcane's root) - instant, 20 s cooldown, 2 mana, 30 m. Roots the target 3 s, +0.5 s per other Arcane spell of yours on cooldown, up to 6 s. Code: scripts/player/utility.gd.
- Also in Utility (coded with their specs): Unweave (Counterspell), Phase Step, Interval Ward.
- No party tool yet. A rewind of allies' positions (Undo) was turned down: easy to troll teammates with.
