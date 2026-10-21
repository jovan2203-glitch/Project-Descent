# Patch notes — 21 October 2026 (0.0.19)

Cold Comfort becomes Frost's healer, and Frost's melee splits into a tank and a damage spec. Damage, healing and shield amounts are given at level 50 before gear. Mana costs are in mana points; one point is 10% of your base mana.

## Frost

### Cold Comfort (healer)

- Changed: Cold Comfort is now a healer spec.
- Changed: Rime Shell is instant when cast on an ally or yourself. It is still a 2.2 sec cast on enemies.
- Changed: When your Rime Shell breaks on an ally, Rime Shards heal every ally within 8 m for 30% of its shield (split evenly past 5 allies). When it runs out without breaking, Runoff heals that ally for 50% of the shield it had left over 4 sec.
- Changed: With an enemy targeted, Rime Shell now goes to the ally under your mouse first (in the world or on a party frame). With no ally under the mouse, an enemy under it is used.
- Changed: Frostworn is now called Thawing.
- Changed: Rime Shell now shows as a bubble of ice around the character it protects, visible to the whole party. It cracks once a third of its shield is gone and cracks further at two thirds.
- New ability: Meltwater (2 mana, 1.5 sec cast, 40 m, card level 2). Heals an ally for 910. Heals 30% more on an ally with your Thawing.
- New ability: Rime Veil (2 mana, instant, 40 m, card level 8). Puts a shield of thin ice on an ally that absorbs 202 damage. Every 3 sec for 12 sec the ice forms again, back to its full size. Does not give Thawing.
- New ability: Break the Ice (1 mana, 10 sec cooldown, instant, 40 m, card level 10). Breaks your Rime Shell on an ally. 80% of the shield it had left heals every ally within 8 m of them (split evenly past 5 allies), and the shell shatters on nearby enemies as if it had broken.
- New ability: Rimefall (4 mana, 15 sec cooldown, 2.5 sec cast, card level 12). Every ally within 20 m, you included, gains a shield that absorbs 304 damage for 8 sec, plus 101 for each ally carrying your Rime Shell, up to 3 allies. Does not give Thawing.
- New ability: Frost Lattice (3 mana, 30 sec cooldown, instant, 40 m, card level 14). Links your target and the allies nearest to them that carry your Rime Shell, 3 allies in all, for 20 sec. Damage that hits a linked shell is taken from all of the linked shells evenly.
- New ability: Stillwater (2 mana, 90 sec cooldown, instant, 40 m, card level 16). Only on an ally below 35% health. Encases them in ice for 3 sec: they take no damage and can't act. Moving breaks the ice early. When it melts, they are healed for 30% of their maximum health.
- New ability: Frost Tide (2 min cooldown, instant, card level 18). For 10 sec your Rime Shell ignores Thawing and is instant on enemies too.
- New ability: Spring Thaw (4 mana, 8 sec cast, 30 m, card level 20). Out of combat only. Brings back your fallen friendly target, or else the closest fallen ally, where they fell, with 50% health and 50% mana.

### Cold Comfort talents

- New talent: Deep Cracks (row 1, 3 ranks, requires Rime Shell). When your Rime Shell breaks on an ally, its Rime Shards heal 10 / 20 / 30% more. Maxing it unlocks Shard Spray.
- New talent: Shard Spray (row 2, 3 ranks, requires Rime Shell). Rime Shards also leave a shield on each ally they heal for 3 sec, absorbing 20 / 35 / 50% of what they healed.
- New talent: Slow Runoff (row 9, 3 ranks, requires Rime Shell). Runoff heals 20 / 40 / 60% more. At max rank, each Runoff also gives you back 1 mana.
- New talent: Cold Spread (row 9, 3 ranks, requires Break the Ice). Break the Ice heals allies up to 2 / 4 / 6 m farther away.
- New talent: Splinterheal (row 10, 3 ranks). Your shatters heal the lowest-health ally within 10 m of the enemy for 20 / 35 / 50% of the damage they deal.
- New talent: Wide Lattice (row 10, 1 rank, requires Frost Lattice). Frost Lattice links one more ally.

### Frost melee

Frost's melee is now two specs: Glacier Wall, an absorb tank with a one-handed weapon and a shield, and Frostbitten Steel, a damage dealer with a two-handed weapon. Both use Fury.

### Glacier Wall (tank: one-handed melee weapon and a shield)

Every Glacier Wall ability requires a melee weapon and a shield.

- New: Ice Layers. One shield of ice on you, in layers: up to 5, each absorbing 4% of your maximum health. They last 20 sec, and gaining one starts the time over. Each Layer a hit breaks gives you 8 Fury and Chills the attacker. Rime Ward makes each Layer bigger, Hardened Frost's armor applies while you have them, and Ice Floe triggers when the last one breaks.
- Changed: Rime Slash is a Glacier Wall ability and requires a shield. It gives you 1 Ice Layer, or 2 if it hits 3 or more enemies, instead of a Rime Shell. Its damage is now split evenly beyond 5 enemies.
- Changed: Shattering Slam is a Glacier Wall ability and requires a shield. It always has 3x threat (before, only when it shattered ice). It now also shatters all your Ice Layers into its target for 92 Frost damage each. Its cooldown is 6 sec (was 5).
- Changed: Rime Slash is now Skill Card level 2 (was 4), and Shattering Slam is level 4 (was 6).
- New ability: Cold Shoulder (8 sec cooldown, instant, off the global cooldown, 25 m, card level 6). The target must attack you for 3 sec and is Chilled, and you gain 1 Ice Layer.
- New ability: Rimequake (25 Fury, 8 sec cooldown, instant, card level 8). Deals 230 Frost damage to every enemy within 6 m with 4x threat and Chills them, plus 10% more damage for each Ice Layer you have. Full damage to up to 5 enemies; with more, it is split evenly between all of them.
- New ability: Hailcoat (25 sec cooldown, instant, card level 10). Fills your Ice Layers.
- New ability: Hard Rime (30 Fury, 20 sec cooldown, instant, card level 12). For 6 sec, each Ice Layer that breaks forms again 2 sec later.
- New ability: Glacial Bulwark (1.5 min cooldown, instant, off the global cooldown, card level 16). You gain 3 Ice Layers. For 10 sec, each Ice Layer that breaks shatters, dealing 138 Frost damage to every enemy within 5 m with 4x threat. Full damage to up to 5 enemies; with more, it is split evenly between all of them.

### Frostbitten Steel (damage: two-handed melee weapon)

Every Frostbitten Steel ability requires a two-handed melee weapon.

- New: Glaze. Rime on your blade, up to 5; it lasts 12 sec, and gaining more starts the time over. Your Frost abilities build it when they hit a target you had already Chilled or Frozen. Icebreaker and Calving spend all of it for more damage.
- Changed: Winter's Bite now generates 20 Fury (it cost 30) and deals 180% of your weapon's damage (was 150%). It gives you 1 Glaze if you had already Chilled or Frozen the target. It is now Skill Card level 2 (was 8).
- Changed: Icebreaker spends all your Glaze for 5% more damage per Glaze. On a target you have Frozen it deals 250% of your weapon's damage (was 350%). It is now Skill Card level 8 (was 18).
- Changed: Rime Edge's extra hit on a target you had already Chilled has a 25% chance to give you 1 Glaze. It is now Skill Card level 10 (was 12).
- Changed: Winter's Bite, Icebreaker and Rime Edge require a two-handed melee weapon (they worked with any melee weapon).
- New ability: Hoarcleave (generates 15 Fury, 6 sec cooldown, instant, card level 4). Cleaves through the target, dealing 120% of your weapon's damage as Frost damage to it and every enemy within 3 m of it, and Chills them. Each enemy hit that you had already Chilled or Frozen gives you 1 Glaze, up to 2. Full damage to up to 5 enemies; with more, it is split evenly between all of them.
- New ability: Calving (30 Fury, 10 sec cooldown, instant, card level 6). Requires Glaze. Deals 100% of your weapon's damage as Frost damage to the target and every enemy within 5 m of it, and Chills them. Spends all your Glaze for 15% more damage per Glaze. Full damage to up to 5 enemies; with more, it is split evenly between all of them.
- New ability: Bitter Edge (15 Fury, 6 sec cooldown, instant, off the global cooldown, card level 12). Usable only on a target you have Frozen. Deals 80% of your weapon's damage as Frost damage, Freezes the target again and gives you 1 Glaze.
- New ability: Black Frost (2 min cooldown, instant, card level 16). For 12 sec, every Winter's Bite Freezes its target.

### Melee talents

The Frost tree has room for the new specs. For melee, rows 3, 6, 7, 8, 9 and 10 each have two new slots; Frostbitten Steel's talents sit left of the middle, Glacier Wall's right of it. Cold Comfort's talents take the middle of rows 1 and 2 and both edges of rows 9 and 10, so those two rows now hold 7 talents each.

- Moved: Frozen Instinct (row 7) moved one column left, straight under Cold Snap.

- New talent: Cold Fury (row 8, 3 ranks). Each of your Ice Layers that breaks gives you 2 / 4 / 6 more Fury.
- New talent: Cold Sweep (row 3, 3 ranks, requires Hoarcleave). When Hoarcleave hits an enemy you had already Chilled, it has a 10 / 20 / 30% chance to Freeze it instead of Chilling it.
- New talent: Packed Ice (row 3, 3 ranks, requires Shattering Slam). Each Ice Layer Shattering Slam shatters into its target deals 13 / 27 / 40% more damage.
- New talent: Biting Hold (row 6, 2 ranks, requires Bitter Edge). Bitter Edge gives you 1 / 2 more Glaze.
- New talent: Deep Tremor (row 6, 3 ranks, requires Rimequake). Rimequake deals 13 / 17 / 20% more damage for each Ice Layer you have, instead of 10%.
- New talent: Long Glaze (row 7, 3 ranks). Your Glaze lasts 2 / 4 / 6 sec longer.
- New talent: Turned Backs (row 7, 2 ranks, requires Cold Shoulder). Cold Shoulder also makes the 1 / 2 enemies nearest its target attack you, and Chills them.
- New talent: Ice Fall (row 8, 3 ranks, requires Calving). Calving deals 4 / 8 / 12% more damage to its target for each other enemy it hits, up to 4.
- New talent: Regelation (row 8, 3 ranks, requires Hard Rime). Each Ice Layer that forms again during Hard Rime gives you 3 / 7 / 10 Fury.
- New talent: Long Dark (row 9, 3 ranks, requires Black Frost). Black Frost lasts 1.5 / 2.5 / 4 sec longer.
- New talent: Old Ice (row 9, 3 ranks, requires Glacial Bulwark). Glacial Bulwark lasts 1.5 / 2.5 / 4 sec longer.
- New talent: Glinting Rime (row 10, 5 ranks). Each Glaze you hold gives your Frost abilities 0.2 / 0.4 / 0.6 / 0.8 / 1% more critical strike chance. At full rank, an Icebreaker that spends 5 Glaze always critically strikes.
- New talent: Deep Strata (row 10, 5 ranks). Your Ice Layers absorb 2 / 4 / 6 / 8 / 10% more damage. At full rank, when your last Ice Layer breaks you gain one back at once, once every 20 sec.

### Runes

- New rune: Rune of the Ice Shelf (Epic). You can hold up to 7 Ice Layers, but the Layers that break no longer Chill the attacker.
- New rune: Rune of the Hoar Blade (Epic). While you hold 5 Glaze, each of your auto-attacks also deals 115 Frost damage. It has its own line on the damage meter.
- New rune: Rune of the Lone Floe (Rare, one per character). Calving hits only its target, but deals 40% more damage.

## Shadow

- Changed: Not Finished With You needs one of the party's combat rez charges and uses it up. Without one, it can't be used and costs nothing.

## Holy

- Changed: Last Verse needs one of the party's combat rez charges and uses it up. Without one, it can't be used and costs nothing.

## Systems & Interface

- Changed: All talent points have been refunded, because the talent trees changed. From now on, every change to the talent trees refunds all talent points.
- Changed: Combat revives are limited. A party starts each run with no combat rez charges and gains one every 5 minutes. Unused charges stack, and the timer carries over between floors. Out-of-combat rezzes and the Training Room are not limited.
- Changed: Party frames now appear on the right side of the screen in a party, with each member's name, health, shields, role icon and a Rime Shell / Thawing marker. Click a frame to target that ally. Point at a frame and press a heal to cast it on them, with or without mouseover casting. Allies out of range or out of sight are dimmed; downed ones are greyed out. The party's combat rez charges and the time until the next one are shown underneath.
- Changed: Each player's role on the party frames (tank, healer or damage) is worked out from the abilities on their action bars.
- Changed: New setting in Settings > Interface: "Party frames when solo".
- Changed: New Move UI button in Settings > Interface (in a dungeon, out of combat). It shows a grid with a labelled box over every part of the in-game interface: health, resources, cast bar, target frame, party frames, buffs, action bars, XP bar, messages, chat, minimap and the menu bar. Drag a box to move that part. Boxes snap to the grid, to other boxes' edges and to the screen centre; hold Shift to place freely. Right-click a box to type exact coordinates, nudge it with the arrows (Ctrl for 10 px), or reset it. The top bar sets the grid size, turns snapping on or off, resets everything, and locks the layout (Esc also locks). Moved parts keep their place when the window or interface size changes.
