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

## Talents (ribbon layout, 2026-10-27; TREE_VERSION 11)
- Specs side by side as ribbons: The Breach (columns 1-3), Pack of Two (4-6), the open talents on the spine (7), Strings Attached (8-10), Nightstring (11-13, empty short ribbon until the bow is built). 19 talents per finished spec, 5 of them needing one ability; capstones need 25 points in the spec.
- Shapes: The Breach "the pit", Pack of Two "paw print", Strings Attached "puppet cross". Links: Interest -> Small Change, Shut Tight -> Bitter End; Long Night -> Take It With You, Pincer -> Again; Long Thread -> Spare Spool, Three Ply -> Full Harness.
- The Breach (56 ranks): Lure (3, any periodic Shadow damage of yours feeds an open Breach 17/33/50%), Interest (3, Call Due), Held Open (2, open 1/2 s longer), Hungry Dark (3, Shadow spells +2/4/6% on a target whose Breach is open), Deep Call (3, Shadow spells with a cast time 0.15/0.35/0.5 s faster while its Breach is open), Wider Still (3, Widen), Bite Down (3, Gnaw), Many Mouths (3, Shadow spells that hit an area feed 10/20/30% more), No Floor (3, Bottomless), Small Change (3, Call Due), Shut Tight (3, closed Breach ticks +5/10/15%), Next of Kin (3), Grasping Hands (3, Breach ticks +1/2/3% crit), Baited Steel (3), Ill Will (3), Carrion (2), Bitter End (3), Paid in Full (2, Call Due or the last tick gives 1/2% max mana). Capstone Hooked Claws (5, ticks +2-10%; at max a tick that crits keeps it open 0.5 s longer, up to 3 s per opening).
- Pack of Two (54 ranks): Long Night (2), Pincer (3, Both At Once), Still Wet (3, Open Up), Take It With You (2), Again (3, Both At Once), Slipped Leash (3, Off the Chain), Lean and Hungry (3), Out of the Hole (3), Snarl (3, Shadow abilities build 5/10/15% more Fury), Fed (2), Worked Up (2), Blood Up (3, while Roused, Shadow abilities that spend Fury +3/6/9%), Stand Over (3, while Roused, each bite heals 0.2/0.4/0.6% max health), Wide Pack (2, Run Them Down), Fetch (3, each Drag Down gives 3/6/10 Fury), Thick Blood (3), Scent of Blood (3, Hound hits +5/10/15% below 35% health), Share the Kill (3, Shadow abilities that heal you heal 33/67/100% more while Hounds are out). Capstone Pack Leader (5, Hounds +3-15%; at max every 10 Fury spent keeps the pair out 1 s longer, up to 10 s per pair).
- Strings Attached (52 ranks): Heave (3, Hoist), Long Thread (2), Quick Hands (3, Strings heal 4/8/12% more often), Three Ply (3, an ally with 3 Strings healed 5/10/15% more by them), First Stitch (2), Spare Spool (2), Hard Pull (3, Tug), Full Harness (2), Pass It On (3, shared heals 10/20/30% larger), Taking the Weight (2), Fair Trade (3, Crossed Strings also heals the ally 10/20/30% of what it moves), Snap Back (3, Pull Taut), Hold Fast (3, Strings heal 7/13/20% more below 35% health), Give and Take (3, Slack), Firm Grip (3, Strings on enemies 1.5/3/4.5 s longer), Loose Weave (2, loose Strings 2/4 s longer), Long Drop (3, String Up), Nothing Wasted (2, Strings on an ally running their full time give 0.3/0.6% max mana). Capstone Steady Hands (5, Strings +3-15%; at max, with no String left in hand, Strings Attached heals are 10% larger).
- Open (9): Slow Death, Wasting, Finish It, Spite, Feeding Frenzy, Helping Hands, Lean On Me, Left Hanging, Inevitable (5). Cut Short was folded into Hush.

## Runes
- Rare: Blight is instant, 15 s cooldown, opens the gate for 8 s.
- Rare Everything Rots (capped at 3).
- Epic: when 50% of the stacked damage would kill the target, it deals its damage instantly as real damage (mitigation or a heal can still save the target; never a forced kill).
- Legendary Dusk till Dawn (the other Legendary is the Wild Page, systems.md): Shadow damage gives Dusk (12 s, +20% Shadow); when it ends, Dawn (12 s, +20% Holy). Never both at once.

## Healer: out-of-combat rez
- Back on Your Feet (Strings Attached) - 8 s cast, 4 mana, 30 m, out of combat only. The demon's Strings lift a dead or downed ally where they fell with 50% health and mana. Code: scripts/player/rez.gd. Not Finished With You stays the combat revive.

## Utility (the book's "Utility" divider) - BUILT 2026-10-17
- Climb the String (Shadow's movement) - instant, 20 s cooldown, 1 mana, 30 m, card level 16. A String hauls you to your friendly target (else your enemy target), 1.5 m short; needs line of sight, blocked during Grounding Surge. On an ally it stays as a loose String for 8 s (Strings Attached heals through it). Only you move. Code: scripts/player/utility.gd.
- Also in Utility (coded with their specs): Tangle (Shadow's root), Hush (interrupt), String Up (stun). Yank, Behind Its Back and Cupped Hands stay in Strings Attached (they need a String); Guard Dogs in Pack of Two (Fury); Take It Back in The Breach (the Breach).
