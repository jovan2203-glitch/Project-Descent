# Shadow book

Values in Frost Bolts (FB) are conversation shorthand; real numbers live in balance.gd. Wants at least 3 playstyles (caster, melee, healer built).

## Caster (Breach)
- Theme: a portal opens under the enemy and demons claw at it from below; hands reach higher over the body as more damage gathers. Code ids keep the old "Decay"/"Blight" names; players see "Breach".
- Breach: no duration; your Shadow spells grow it; a % of it deals damage every second; haste makes it tick faster and ticks can crit. It must never trail off into tiny ticks, so it has finishers.
- Break Ground (code id blight) applies Breach and opens its gate; it must be used to sustain it. All other spells only add to it. Other playstyles don't get Breach for free but can dip in through talents/runes.
- Beckon (code id erode) - the builder, adds 100% of its damage to Breach.
- Also in the kit: Wither (corruption), Widen (spill), Gnaw, Many Hands (pall), Call Due, Take It Back, Bottomless. Hush (interrupt, 15 s) is in Utility.
- Removed: Usher In (was Sink In), Gloom Bolt. Pall was renamed.

## Melee (Hounds, Fury)
- Two demon dogs in the world, red/purple and evil, 30 s duration; if they aren't up your rotation spawns them. They share your stats; the kit builds and spends Fury (no Frenzy stacks).
- They always hit the last thing you damaged (direct damage only) and dash to the target when it is more than 1 second's walk away. They keep biting during Guard Dogs.
- Abilities include Open Up (Laid Open), Both At Once (lunges), Guard Dogs, Off the Chain, Leeching Strike, Roused, Drag Down; a 10 s cooldown ability with no Fury cost or gain dismisses the Hounds early so they Drag Down.

## Healer (Strings)
- A demon floats behind you while you have Strings; strings leave his hands only toward allies and vanish quickly. On allies they come down from just above the target, and must not look stiff when the player rotates.
- 6 Strings, shown as charges; one recharges every 10 s; an expired String returns its charge instantly. Up to 3 on one ally; each heals every second. 15 s on allies, 10 s on enemies.
- String - halved GCD; on an ally that already has one it refreshes and adds a stack. Stringed allies get 30% of heals cast on other stringed allies.
- Crossed Strings: tag an ally then an enemy; 3% of that ally's damage taken is dealt to the enemy as Shadow damage (always the last ally tagged); breaks past 30 m or when the enemy dies; counts against the max.
- AoE heal (20 s cooldown) - one temporary String per ally, not counting toward the max.
- Hoist - 2 s cast, big heal on a stringed ally, others on Strings get a share.
- A weaker cast heal needing no String.
- Tug - instant, 6 s cooldown, small heal; that ally's Strings heal twice as fast for 4 s.
- Pull Taut - instant, 15 s cooldown.
- Knot - 30 s cooldown, Strings on one ally don't run out for 30 s and can't be moved by Restring.
- Double Thread - 30 s cooldown, off GCD: next String placed as two for one charge.
- Wrench - instant, 8 s cooldown: damage to a stringed enemy, the crossed ally healed for the same.
- Cupped Hands - 25 s cooldown, 5 s absorb, larger per String.
- Behind Its Back - 60 s cooldown, self 40% less damage for 6 s, needs 1+ String placed.
- Slack - 60 s cooldown, Strings stop healing 4 s, mana back per String.
- Not Finished With You - long cooldown, costs 3 Strings: lifts a dead ally at 30% health with those 3 Strings.
- String Up (stun, enemy hangs), Tangle (area root), Still Standing (a stringed ally who would die is held at a sliver; lives if healed above a threshold), Cut the Strings (all snap: burst heal / damage), Restring (off GCD, 20 s cooldown, moves your last String), Yank (pull a stringed ally to you).

## Talents
- Caster: Bitter End (3, Break Ground): last tick +33/67/100%. Next of Kin (3, Break Ground; capstone the next nearest enemy gets some too). Lure (3, Wither): its ticks add 17/33/50% of their damage to your open Breach. Interest (3, Call Due; capstone instant Break Ground within 5 s). Small Change (3, Call Due). No Floor (3, Bottomless; capstone Breach can't close). Hooked Claws (5, bottom row, Break Ground): Breach ticks +2-10%. Wider Still (3, Widen: copies more of the Breach, capstone every copy open at least 5 s). Baited Steel (3, Break Ground, row 3 edge): your Shadow abilities add 10/20/30% of their direct damage to an open Breach. Bite Down (3, Gnaw: ticks +7/13/20% crit chance). Cut Short was folded into Hush (interrupting takes 4 s off, never below 15 s); its slot is empty.
- Hounds: Lean and Hungry (3): bites 4/8/12% faster. Fed (2): bite crit gives 2/4 Fury. Worked Up (2): Roused +2/4 s, capstone bites +10% crit during Roused. Take It With You (2): Drag Down +25/50%, capstone a kill makes the next pair arrive Roused. Long Night (2): +3/6 s. Out of the Hole (3): bites add 17/33/50% of damage to your open Breach. Pack Leader (5, bottom): Hounds +3-15%. Still Wet (3, Open Up: Laid Open +1.5/2.5/4 s, capstone your strikes +10% to that enemy). Pincer (3, Both At Once: lunges +10/20/30%, capstone lunge crit refunds 10 Fury). Again (3): Both At Once 10/20/30% reset. Stand Over (3, Guard Dogs: bites heal 0.7/1.3/2% max health). Slipped Leash (3, Off the Chain +1.5/2.5/4 s, capstone a third Hound). Share the Kill (3, Leeching Strike heal +33/67/100% while Hounds are out).
- Strings: Steady Hands (5, bottom): +3-15%. Long Thread (2): +2/4 s on allies. Spare Spool (2): Strings back 1/2 s sooner. Taking the Weight (2): Crossed Strings 5/7%, capstone breaks at 40 m. Full Harness (2): ally with 3 Strings takes 3/6% less damage. First Stitch (2): tying heals at once for 2/4 String heals. Heave (3, Hoist: +3/7/10% per String, capstone 0.5 s shorter cast on an ally with 3). Snap Back (3, Pull Taut: 17/33/50% String returns). Long Drop (3, String Up: 0.3/0.7/1 FB when it ends). Give and Take (3, Slack: 1/2/3 s shorter).
- Open: Inevitable (5): 2-10%. Slow Death (3). Wasting (3). Finish It (3). Spite (3). Carrion (2): an enemy dying with your DoT gives back 1/2% max mana. Thick Blood (3): Fury decays 15/30/45% slower. Feeding Frenzy (3): an enemy you damaged dies: 2/4/6% Haste for 8 s. Lean On Me (3): after healing another ally, 2/4/6% less damage for 4 s. Left Hanging (2): stuns and roots +10/20%. Helping Hands (3): heals on other allies +2/4/6%.

## Runes
- Rare: Blight is instant, 15 s cooldown, opens the gate for 8 s.
- Rare Everything Rots (capped at 3).
- Epic: when 50% of the stacked damage would kill the target, it deals its damage instantly as real damage (mitigation or a heal can still save the target; never a forced kill).
- Legendary Dusk till Dawn (the only Legendary): Shadow damage gives Dusk (12 s, +20% Shadow); when it ends, Dawn (12 s, +20% Holy). Never both at once.

## Healer: out-of-combat rez
- Back on Your Feet (Strings Attached) - 8 s cast, 4 mana, 30 m, out of combat only. The demon's Strings lift a dead or downed ally where they fell with 50% health and mana. Code: scripts/player/rez.gd. Not Finished With You stays the combat revive.

## Utility (the book's "Utility" divider) - BUILT 2026-10-17
- Climb the String (Shadow's movement) - instant, 20 s cooldown, 1 mana, 30 m, card level 16. A String hauls you to your friendly target (else your enemy target), 1.5 m short; needs line of sight, blocked during Grounding Surge. On an ally it stays as a loose String for 8 s (Strings Attached heals through it). Only you move. Code: scripts/player/utility.gd.
- Also in Utility (coded with their specs): Tangle (Shadow's root), Hush (interrupt), String Up (stun). Yank, Behind Its Back and Cupped Hands stay in Strings Attached (they need a String); Guard Dogs in Pack of Two (Fury); Take It Back in The Breach (the Breach).
