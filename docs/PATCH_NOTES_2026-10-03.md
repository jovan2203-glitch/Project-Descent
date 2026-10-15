# Patch notes — 3 October 2026

## Fixes
- Settings: opening Settings from the main menu no longer leaves the whole screen grayed out and unclickable.
- Rime Shell on an enemy now stays for its full duration after its shield breaks, instead of disappearing on the first hit.
- Rime Shell shatters use one routine for enemies and allies, so both behave the same.
- Smoldering Debris: each tick now deals the stated 20% of the Slag shatter's damage (it was dealing about 12%). Its ticks use your normal critical strike chance.
- Slag shatter: a critical strike no longer spends your Smoldering Focus stacks, which caused single hits of over 40,000.
- Ramps: ramps in every dungeon now sit flush with the floor at both ends, so players and enemies no longer get stuck on a lip.
- Camera: the camera keeps the angle you set while you walk up and down ramps.
- Map and minimap: impassable terrain is drawn as solid wall instead of an outline.
- Entering a dungeon directly (without passing through the main menu first) no longer freezes the game.

## Search
- Abilities & Talents has a search bar at the top.
  - On the shelf it lists every ability and talent that matches. Clicking a result opens its book with that entry framed.
  - Inside a book it frames the matches and dims everything else.
  - It searches names, descriptions and keywords: "chill" or "chilled" finds everything that works with Chilled.
- The Runes screen has the same search.
- Hovering an ability or a talent frames everything that mentions it, and everything it mentions.

## Tooltips
- Keywords and names (Chilled, Frozen, ability names) are shown in orange in every tooltip.
- Holding Shift explains the keywords in a tooltip. On abilities the explanations are added below the existing details. Talent, rune and buff tooltips have it too.
- A talent that only works with one ability shows "Requires <ability> to be learned", and points cannot be spent in it until that ability is learned.

## Action bars
- Three extra action bars: one above the main bar and one on each side of the screen. Turn each on in Settings > Interface, where each also has its own opacity.
- Every new slot can be bound in Settings > Controls. Pressing Delete while binding clears a key.
- On-use trinkets can be dragged onto an action bar, from the bag or from the Character window, and used from there. The button shows the trinket's own icon.

## Macros
- New "Macros" entry in the Esc menu, in a dungeon and in the main menu.
- A macro has a name, an icon chosen from the game's ability and talent icons, and a text with one command per line:
  - `/cast Ability Name` uses that ability. `Trinket 1` and `Trinket 2` use your trinkets.
  - `/castsequence A, B, C` uses the next ability in the list on each press. `reset=6` starts over after 6 seconds without a press.
- One press runs every line. Abilities that skip the global cooldown all go off together; of the others, the first one that can be used is.
- A macro can be linked to an ability. Its button then shows that ability's cooldown, charges and tooltip.
- In a dungeon, drag a macro from the window onto an action-bar slot.
- Macros are kept when you wipe your save.

## Damage meter
- Afterglow has its own line.
- Damage that a talent, buff or rune adds to another hit is shown on its own line instead of inside that hit.

## Give item
- `/give` works in the main menu, where the item goes into your bank. In a dungeon it goes into your bag.
- Items can be given by name or part of a name, with the rarity as a word: `/give storm idol epic 30`.
- `/give` on its own lists every item.

## Abilities, talents and runes
- The Clinker talent is renamed to Smoldering Debris.
- Auto attacks (melee swings and ranged shots) deal 50% less damage.
- Rime Shell: a shatter that damages only one enemy deals 30% more damage.
- Winter's Bite: each cast adds a stack of a buff on you (up to 3, 20 seconds). The third cast uses the stacks and Freezes the target instead of Chilling it.
- Rune of the Dull Edge: critical strike chance above 10% now becomes Attack Power instead of Spell Power.
- New rune: Rune of the Dull Mind (Epic). Your critical strike chance cannot go above 10%; everything beyond that becomes Spell Power. It cannot be equipped together with the Rune of the Dull Edge.

## New Frost talents
The Frost tree gains a middle slot in rows 2, 5, 8 and 10.
- New talent: Pinning Frost (row 2, 2 ranks, requires Icepin). Frost Arrow deals 20 / 40% more damage to a target rooted by your Icepin.
- New talent: Third Bite (row 5, 2 ranks, requires Winter's Bite). The Winter's Bite that Freezes its target deals 40 / 80% more damage.
- New talent: Thick Hide (row 8, 2 ranks, requires Winter Hide). Reduces the cooldown of Winter Hide by 10 / 20 sec.
- New talent: Hard Freeze (row 10, 3 ranks). Your Frozen lasts 0.5 / 1 / 1.5 sec longer.

## Stats
- Constitution gives 20% less Max Health.
- Level-up attribute points: Health and Mana are removed, Constitution is added. Points spent in Health or Mana are refunded.
- Stat squish: Intellect, Agility, Strength, Constitution, Armor, Spell Power, Attack Power and Critical Strike Rating are 30% smaller, and each point is worth more, so damage, health, mana, crit and block are unchanged. Critical Strike Rating is now 70 per 1%.
- Haste from every source (gear, talents, buffs) is reduced by 30%.
