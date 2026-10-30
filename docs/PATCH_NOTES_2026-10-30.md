# Patch notes — 30 October 2026

The Brawler now chooses when to take hits with Bruise: a new stance turns it on, at the cost of everything that isn't Physical. Capstones are much closer, the damage meter shows threat on your target, and the in-game Spellbook can search, reset talents and manage runes. Also: Sap no longer heals for absurd amounts, Incense has to be fed, and the Trackers editor finally shows your trackers and lets you click one on screen to edit it.

## Nature

- Fixed: Sap healed about 500 times too much. Each Sap now heals 0.4% of your maximum health every second, as intended.
- Fixed: Heartsap healed about 500 times too much. It now heals 5% of your maximum health plus 3% for each Sap it uses.
- Fixed: The first Vine Fist (and the first woven creature of any kind) froze the game for a moment, for you and for party members who saw it.

## Holy

- Changed: Incense now loses 1 stack every 2 sec, except while your censer is raised (was: it only ran out after 30 sec without gaining any). It still runs out completely after 30 sec without a gain.

## Martial

- New ability: Put 'Em Up (no cost, 1 sec cooldown, instant, off the global cooldown; comes with Punch). A Brawler stance you turn on and off. While you are in it, you take hits with Bruise, and all damage you deal that is not Physical is 60% lower. The stance stays on between sessions.
- Changed: Bruise now works only while you are in Put 'Em Up (was: whenever a Brawler ability was on your action bars).

## Systems & Interface

- Changed: A spec's capstone (its row-10 talent) needs 15 points in that spec (was 25).
- Changed: Hovering an ability now also lights up the talents of its spec, and its book's open talents, that work with something it makes or uses, even when they don't name it (for example, Slag Skin lights every Slag talent). Hovering such a talent lights the ability back.
- Changed: A talent opened only by a maxed link no longer unrolls its spec's ribbon down to its row; the ribbon reaches a row once that row is opened by points.
- New: The damage meter shows threat on your current target under the damage or healing bars: everyone's threat, highest first, as a share of the threat of the player it is attacking. Red marks the player it is attacking, orange anyone at 90% of their threat or more.
- New: The Spellbook (P) has a search bar. Matching abilities and talents are framed and everything else is dimmed; talent books without a match dim their tab.
- New: The Spellbook's talents have a Reset button. It works where talents can be changed (the training area).
- New: Tabs at the bottom of the Spellbook: Abilities & Talents, and Runes. Runes holds Rune Management (every rune, crafting, engraving onto your gear, moving runes) and is locked in combat.
- New: The Trackers editor has a "Move on screen" button that opens Move UI to drag your trackers.
- New: The Trackers editor can be resized (drag its bottom-right corner) and minimized to its title bar.
- New: While the Trackers editor is open, hovering a tracker on screen frames it; click it to open it in the editor.
- Changed: Error messages and rune procs ("Target out of range", "Rune of Warding!") show at the top centre of the screen, under the boss timer (were above the middle of the screen). If you moved them in Move UI, they stay where you put them.
- Changed: A spec display tracker (Venom, Chain, Bruise, Heat, Sap...) that has gone missing is given back, unless you deleted it in the Trackers editor.

## Fixes

- Fixed: Messages drifted a little off-centre after a longer one had been shown.
- Fixed: Training dummies could be pushed around by walking into them while they were fighting (for example, while your Incense aura hit them).
- Fixed: The Trackers editor always opened with an empty list ("No trackers yet") while your trackers were showing on screen.
