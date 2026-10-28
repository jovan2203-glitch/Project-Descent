# Patch notes — 28 October 2026

A new in-game interface with role layouts, UI Options and player-built Trackers; Downgate Fort rebuilt as a hand-made dungeon with new bosses, set pieces and one shared look for every boss mechanic; and a reworked main menu with a ready check, a new Play screen, loadouts, patch notes and a last-run summary.

## Systems & Interface

### Downgate Fort
- Changed: The Fort is now Downgate Fort, a hand-made map. The old Binders' fort over the first way down into the Deep, taken by a goblin warband that strips it for pages. You enter down the Long Stair, fight through the Gatehouse and the Courtyard, then clear three wings. Each wing's boss holds one seal of the Keep, and all three open it.
  - Barracks, Armory and Drill Yard: goblin soldiers. Objective: slay the two Sergeants. Boss: Captain Brask.
  - Scriptorium, Archive and Reading Hall: Fallen Scribes, Fallen Binders and Page Thieves. Objective: slay 75% of the enemies. Boss: Nib the Page Thief.
  - Siege Yard, Workshop and North Wall (up a flight of stairs): Goblin Sappers, Fire Potters and Siege Haulers. Objective: hold the circle. Boss: Siegemaster Gorrik.
  - The Keep: Skrag the False Binder, guarded by Keep Guards.
- Changed: renamed enemies: Shieldbearer is now Goblin Shieldbearer, Field Medic is now Goblin Patcher, Siege Brute is now Goblin Bruiser, Rampart Archer is now Wall Archer and Fort Scrapper is now Goblin Scrapper. New enemies: Barracks Grunt, Fallen Scribe, Fallen Binder, Page Thief, Goblin Sapper, Fire Potter, Siege Hauler, Keep Guard and Bell Ringer.
- New: alarm bells in the Gatehouse and the Courtyard. When a fight starts within 16 m of a bell, its Bell Ringer casts Ring the Alarm (4 sec). Interrupt it, stun it or kill it, or 4 more goblins arrive. Each bell rings once.
- New: archer towers in the Courtyard: raised platforms with archers on top, reached by stairs.
- New: the ballista on the North Wall. Stand on its plate for 2 sec during the Siegemaster Gorrik fight: the bolt deals 3% of his maximum health and knocks him down (stunned) for 3 sec, then he takes 25% more damage for 8 sec (Weak Spot). 30 sec cooldown.

### Bosses
- Changed: Captain Brask. Shield Bash (frontal cone) and Charge (line). At 66% and 33% health he uses Close Ranks: he is immune until his 2, then 3, shieldbearers die (a bubble on him with lines to each guard). Enrages at 20%.
- New boss: Nib the Page Thief (replaces Sister Mercy). Loose Pages marks 2 players to spread out, and Ink Blast must be interrupted. At 50% he switches to Fire Pages: Burning Ink (lasting pools), Page Flare (eruptions) and faster Loose Pages on 3 players.
- New boss: Siegemaster Gorrik (replaces Old Rampart). Ground Pound, Artillery, Fire Pots (pools), Boulder (stand together: the hit is split between up to 3 players) and Call the Crew (interrupt it). Enrages at 30%.
- New boss: Skrag the False Binder (replaces Warden Kael). Phase 1: Cleave, Charge and Ring of Steel (get close). At 66%, Fire Pages: Call the Warband, Ember Rain (pools) and Scorch Marks (spread). At 33%, The Book Tears: Torn Pages (stack) and Page Storm (barrage). Enrages at 20%. Cleave is used in every phase.
- Changed: every boss mechanic now has one look, the same in every dungeon: a filling red-orange circle, cone or line to avoid; a green circle to stand in; a circle with an arrow pointing in to stack on; a circle on a player with arrows pointing out to spread from; a lasting pool with a striped rim to stay out of; a cast bar to interrupt; a bubble with lines to the guards to kill.
- New: boss mechanics Stack (soak, split between the players inside), Spread, lasting pools, and phases at a health threshold (with guards to kill or adds to fight).
- New: an immune boss shows "Immune" and takes no damage.

### Modifiers
- Removed: the Darkness modifier. Modifiers change how fights play (enemy behaviour, damage, healing) and are never just a visual effect.

### In-game interface
- Changed: a new in-game interface with one flat, sharp look: near-black backdrops, flat bars, outlined text. Windows (Character, Bags, Bank, Spellbook, Esc menu, Settings, map, damage meter, inspect, macros, the Training Room panel) use it too.
- New: role layouts: Tank, Healer, Physical DPS and Caster DPS. Each places every element its own way (healer: party frames in a row above the bars; caster: a wide cast bar; tank: bigger health and debuffs).
- New: UI setup opens the first time you enter a dungeon: welcome, layout (with a picture of each), interface size, chat and damage meter. Settings > Interface runs it again.
- New: UI Options (Settings > Interface, /ui, or Move UI): a page for every element with Enabled, Scale, Opacity and Show (always, only in or out of combat, on mouseover), plus its own options: sizes, texts, auras, grow direction, sorting, info texts. Changes apply at once. Export / Import shares a whole interface as one line of text.
- New: Trackers (/trackers): build your own aura bars, cooldown icons, alerts and resource displays. Icons, bars, texts or rings driven by triggers (an effect on you, your target or the party; a cooldown; a resource or spec value such as Venom, Verses or Ice Shards; an event; an item equipped), with conditions (colour, glow, opacity) and load rules (spec, role, combat, party, dungeon). Groups, templates, duplicate, and Import / Export. Every role starts with empty Aura Bars and Cooldowns groups; tanks and healers also get a low-health warning.
- New: "Show IDs in tooltips" (UI Options > General) adds the ID of abilities, items and effects to tooltips, as Trackers know them.
- Changed: layout: action bars stacked in the bottom centre with the XP bar under them; player and target frames above them with their cast bars; the chat panel bottom left, with a micro menu (Character, Spellbook, Bank, Bags, Meter) and info texts; the damage meter docked bottom right; the square minimap top right with buffs and debuffs beside it.
- Changed: buff and debuff icons can be sorted by type or by time left, and show the time left under each icon.

### Main menu
- New: the lobby has a 3D backdrop: a stone clearing in front of a ruined dungeon gate, with a campfire behind the party.
- New: drag on empty space in the Lobby or Character tab to turn your character. It turns back 2 sec after you let go.
- New: party cards show each member's level, main spec, a role icon and a strip in their book's colour. Your own level and spec show under your name.
- New: ready check. The party leader has a Ready Check button; everyone gets a "Ready?" prompt with a 20 sec countdown, and each card shows who is ready. With a party, Enter Now and Queue always run a ready check first: one "Not ready" or the timeout stops it.
- Changed: the Play screen shows every dungeon as a card in its own colour with your best clear time, and a side panel with the chosen dungeon's objectives, possible modifiers, enemy level for your group, best clear time per difficulty, the difficulty, your Pact, and Queue / Enter Now. Your choice is remembered, and the PLAY button shows it under its name.
- New: best clear times per dungeon and difficulty. The clear screen says when you set a new best.
- New: loadouts. Save up to 6 setups (talents, action bars, attribute points and Pact) from Abilities & Talents > Loadouts, and switch between them there or from the dropdown beside your name in the lobby. Only in the main menu. Talents saved before a talent tree change, or costing more points than you have, and abilities you no longer know are left out, with a note.
- New: Join on a friend who is in this game with a party of their own.
- New: What's new: the latest patch notes, from a button at the top left of the lobby. A dot shows until you open new notes.
- New: a last-run card after a dungeon: cleared or left early, difficulty, time, bosses, enemies, XP and levels gained, the loot that went to your bank, and the party's damage and healing for the whole run. It stays until you dismiss it or start another run.

## Fixes

- Fixed: the camera stayed off-centre for a whole run when you spawned on a raised or lowered floor.
- Fixed: stairs are one smooth slope to walk on, and pillars, centrepieces and other blockers no longer stand in doorways.
