# Patch notes — 10 October 2026

## Armor
- Armor now reduces all the damage you take: hits of every school, and damage over time. It no longer gives a chance to block.
- The reduction depends on your Armor and your level, so the same share of level-appropriate gear is worth the same at every level. It is capped at 60%.
- A full set of Heavy armor gives about 36% less damage taken, and about 40% with a shield. Medium gives about 28%, Light about 18% and Cloth about 10%.
- Each point of Armor is worth a little less than the one before it.
- Armor buffs now add damage reduction instead of block chance: Slag, Ice Barrier, Sacred Bulwark, Hardened Frost and Tempered.
- Enemies' Armor works the same way: it reduces the damage they take, and they no longer block through it.
- The character sheet shows the reduction next to your Armor.

## Block
- Block chance now comes only from Block on gear, from Strength (6% per 1,000 Strength) and from buffs such as Cinder Guard. It is still capped at 60%.
- The Block row of the character sheet no longer counts Armor.

## Armor types
- Every piece of armor for the Head, Shoulder, Chest, Gloves, Legs and Boots slots is now one of four types: Cloth, Light, Medium or Heavy.
- The type is rolled when the item drops; all four are equally likely. Anyone can wear any type.
- The heavier a piece, the more Armor it has. A Medium piece has 70% of a Heavy piece's Armor, Light 40% and Cloth 20%.
- Each type carries a stat of its own, and the lighter the piece, the more of it: Cloth gives Intellect, Light gives Agility, Medium gives Strength and Heavy gives Constitution.
- Chest and Legs pieces have the most Armor and type stat, Head and Shoulder pieces two thirds of that, Gloves and Boots one third.
- A Chest piece at item level 50:
  - Cloth: 53 Armor, 197 Intellect.
  - Light: 105 Armor, 158 Agility.
  - Medium: 184 Armor, 118 Strength.
  - Heavy: 263 Armor, 79 Constitution.
- Pieces are named after their type:
  - Head: Silk Hood, Leather Cap, Chain Coif, Plate Helm.
  - Shoulder: Silk Mantle, Leather Shoulderpads, Chain Shoulders, Plate Pauldrons.
  - Chest: Silk Robe, Leather Jerkin, Chain Hauberk, Plate Cuirass.
  - Gloves: Silk Gloves, Leather Grips, Chain Gauntlets, Plate Gauntlets.
  - Legs: Silk Trousers, Leather Breeches, Chain Leggings, Plate Greaves.
  - Boots: Silk Slippers, Leather Boots, Chain Boots, Plate Sabatons.
- Item tooltips show the type next to the slot, for example "Chest • Heavy Armor".
- Armor you already own keeps the type it was named after: Iron Helm, Iron Pauldrons and Iron Chestplate are Heavy, Chain Leggings are Medium, Leather Grips and Swift Boots are Light. Their Armor now comes from their type; their other stats are unchanged.
- Shields keep their Armor and have no type. Cloaks, jewelry, trinkets and weapons have no type.
- The /give command takes an armor type: /give chestplate heavy epic 50.

## New talents
Six talents that are themed to their book but work with every book's spells and abilities. None of them needs an ability from its book.

### Fire
- New talent: Feed the Flames (row 1, 3 ranks). Your direct hits deal 2/4/6% more damage to enemies that carry one of your damage over time effects.
- New talent: Last Ember (row 5, 2 ranks). When one of your damage over time effects runs its full time, it ticks once more for 50/100% of a tick's damage. An effect that is ended early or refreshed does not.
- New talent: Tempered (row 5, 3 ranks). Each attack you block increases your Armor by 2/4/6% for 8 sec, stacking up to 3 times. A new block renews all stacks.

### Lightning
- New talent: Change of Pace (row 1, 3 ranks). Using a different spell or ability than the last one you used increases your damage by 1/2/3% for 6 sec, stacking up to 3 times. Using the same one twice in a row ends it.
- New talent: Spillover (row 3, 3 ranks). When one of your direct hits critically strikes, 5/10/15% of its damage jumps to the nearest other enemy within 6 m. The jump cannot critically strike or be avoided, does not jump again, and has its own line on the meter: Spillover.
- New talent: Dig In (row 4, 3 ranks). After you stand still for 2 sec, you deal 2/4/6% more damage until you move. A buff shows while it is active.

Talent trees:
- Row 1 of the Fire tree gained a middle slot and row 5 two edge slots. Rows 1, 3 and 4 of the Lightning tree each gained a middle slot. No existing talent moved.
