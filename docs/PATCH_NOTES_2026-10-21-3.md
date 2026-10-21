# Patch notes — 21 October 2026 (0.0.19)

Cold Comfort becomes Frost's healer, built around Rime Shell. Healing and shield amounts are given at level 50 before gear. Mana costs are in mana points; one point is 10% of your base mana.

## Frost

- Changed: Cold Comfort is now a healer spec.
- Changed: Rime Shell is instant when cast on an ally or yourself. It is still a 2.2 sec cast on enemies.
- Changed: When your Rime Shell breaks on an ally, Rime Shards heal every ally within 8 m for 30% of its shield (split evenly past 5 allies). When it runs out without breaking, Runoff heals that ally for 50% of the shield it had left over 4 sec.
- Changed: With an enemy targeted, Rime Shell now goes to the ally under your mouse first (in the world or on a party frame). With no ally under the mouse, an enemy under it is used.
- Changed: Frostworn is now called Thawing.
- Changed: Rime Shell now shows as a bubble of ice around the character it protects, visible to the whole party. It cracks once a third of its shield is gone and cracks further at two thirds.
- New ability: Meltwater (2 mana, 1.5 sec cast, 40 m, card level 2). Heals an ally for 910. Heals 30% more on an ally with your Thawing.
- New ability: Glaze (2 mana, instant, 40 m, card level 8). Puts a shield of thin ice on an ally that absorbs 202 damage. Every 3 sec for 12 sec the ice forms again, back to its full size. Does not give Thawing.
- New ability: Break the Ice (1 mana, 10 sec cooldown, instant, 40 m, card level 10). Breaks your Rime Shell on an ally. 80% of the shield it had left heals every ally within 8 m of them (split evenly past 5 allies), and the shell shatters on nearby enemies as if it had broken.
- New ability: Rimefall (4 mana, 15 sec cooldown, 2.5 sec cast, card level 12). Every ally within 20 m, you included, gains a shield that absorbs 304 damage for 8 sec, plus 101 for each ally carrying your Rime Shell, up to 3 allies. Does not give Thawing.
- New ability: Frost Lattice (3 mana, 30 sec cooldown, instant, 40 m, card level 14). Links your target and the allies nearest to them that carry your Rime Shell, 3 allies in all, for 20 sec. Damage that hits a linked shell is taken from all of the linked shells evenly.
- New ability: Stillwater (2 mana, 90 sec cooldown, instant, 40 m, card level 16). Only on an ally below 35% health. Encases them in ice for 3 sec: they take no damage and can't act. Moving breaks the ice early. When it melts, they are healed for 30% of their maximum health.
- New ability: Frost Tide (2 min cooldown, instant, card level 18). For 10 sec your Rime Shell ignores Thawing and is instant on enemies too.
- New ability: Spring Thaw (4 mana, 8 sec cast, 30 m, card level 20). Out of combat only. Brings back your fallen friendly target, or else the closest fallen ally, where they fell, with 50% health and 50% mana.
- New talent: Deep Cracks (row 1, 3 ranks, requires Rime Shell). When your Rime Shell breaks on an ally, its Rime Shards heal 10 / 20 / 30% more. Maxing it unlocks Shard Spray.
- New talent: Shard Spray (row 2, 3 ranks, requires Rime Shell). Rime Shards also leave a shield on each ally they heal for 3 sec, absorbing 20 / 35 / 50% of what they healed.
- New talent: Slow Runoff (row 9, 3 ranks, requires Rime Shell). Runoff heals 20 / 40 / 60% more. At max rank, each Runoff also gives you back 1 mana.
- New talent: Cold Spread (row 9, 3 ranks, requires Break the Ice). Break the Ice heals allies up to 2 / 4 / 6 m farther away.
- New talent: Splinterheal (row 10, 3 ranks). Your shatters heal the lowest-health ally within 10 m of the enemy for 20 / 35 / 50% of the damage they deal.
- New talent: Wide Lattice (row 10, 1 rank, requires Frost Lattice). Frost Lattice links one more ally.

## Shadow

- Changed: Not Finished With You needs one of the party's combat rez charges and uses it up. Without one, it can't be used and costs nothing.

## Holy

- Changed: Last Verse needs one of the party's combat rez charges and uses it up. Without one, it can't be used and costs nothing.

## Systems & Interface

- Changed: Combat revives are limited. A party starts each run with no combat rez charges and gains one every 5 minutes. Unused charges stack, and the timer carries over between floors. Out-of-combat rezzes and the Training Room are not limited.
- Changed: Party frames now appear on the right side of the screen in a party, with each member's name, health, shields, role icon and a Rime Shell / Thawing marker. Click a frame to target that ally. Point at a frame and press a heal to cast it on them, with or without mouseover casting. Allies out of range or out of sight are dimmed; downed ones are greyed out. The party's combat rez charges and the time until the next one are shown underneath.
- Changed: Each player's role on the party frames (tank, healer or damage) is worked out from the abilities on their action bars.
- Changed: New setting in Settings > Interface: "Party frames when solo".
- Changed: New Move UI button in Settings > Interface (in a dungeon, out of combat). It shows a grid with a labelled box over every part of the in-game interface: health, resources, cast bar, target frame, party frames, buffs, action bars, XP bar, messages, chat, minimap and the menu bar. Drag a box to move that part. Boxes snap to the grid, to other boxes' edges and to the screen centre; hold Shift to place freely. Right-click a box to type exact coordinates, nudge it with the arrows (Ctrl for 10 px), or reset it. The top bar sets the grid size, turns snapping on or off, resets everything, and locks the layout (Esc also locks). Moved parts keep their place when the window or interface size changes.
