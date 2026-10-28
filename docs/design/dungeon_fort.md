# Downgate Fort

The test experience's reference dungeon. A hand-made map (`scenes/dungeons/fort/fort_layout.tscn`), recipe `data/dungeons/fort.tres`, names in `scripts/dungeon/names.gd`. Numbers live in the recipe and `balance.gd`; this file records intent.

## Lore
The old Binders built Downgate Fort over the first way down into the Deep. Pages that drifted up were gathered and copied here. A goblin warband took it and is stripping it of pages; its old garrison, fallen Binders, still walks the Scriptorium.

- **Entering**: from the Bindery you take the Long Stair down. It ends at the fort's broken outer gate.
- **The Keep's seals**: the old Binders' page-ward holds the Keep door. Skrag rebound it with three stolen pages, and each lieutenant carries one. Kill a lieutenant and their seal lights up on the Keep Gate; all three open the Keep.

## Map
| Room | Height | What happens |
|---|---|---|
| The Long Stair (start) | +4 m | Safe. Stairs down into the fort. |
| Gatehouse | 0 | One pack and an **alarm bell** behind it. |
| Courtyard (hub) | 0 | Two packs, two **archer towers** (raised platforms with stairs), a second **alarm bell**. |
| Barracks, Armory → Drill Yard | 0 | Goblin soldiers. **Objective: kill the two Sergeants** (keybearers). Boss: Captain Brask. |
| Scriptorium, Archive → Reading Hall | 0 | Fallen Scribes and Fallen Binders (zombies), Page Thieves (shadow casters). **Objective: slay 75%.** Boss: Nib the Page Thief. |
| Keep Gate | 0 | The three seal lights; the doors to the Keep and up to the walls. |
| Siege Yard, Workshop → North Wall | +3 m (stairs up) | Sappers, Fire Potters, Haulers. **Objective: hold the yard** (defend circle). Boss: Siegemaster Gorrik, with the **ballista**. |
| The Keep | 0 | Final boss: Skrag the False Binder. Needs all three seals. |

## Set pieces
- **Alarm bell**: a Bell Ringer stands beside each bell. When a fight starts near it, it casts Ring the Alarm (4 s). Interrupt it, stun it or kill it, or a reinforcement pack arrives. Each bell rings once.
- **Archer towers**: raised platforms with archers on top; stairs lead up.
- **Ballista** (North Wall): stand on its plate for 2 s during the Gorrik fight. It Knocks him Down for 3 s, then he takes 25% more damage (Weak Spot) for 8 s. Cooldown 30 s.

## Bosses
All mechanics use the shared look (`scripts/dungeon/mechanic_look.gd`): the same shape means the same thing in every dungeon.

1. **Captain Brask** (Barracks, goblin shieldbearer): teaches **kill the guards**.
   - Shield Bash (frontal cone) and Charge (line).
   - At 66% (2 guards) and 33% (3 guards), **Close Ranks**: he is immune until his shieldbearers die.
   - Enrages at 20%.
2. **Nib the Page Thief** (Scriptorium, goblin wizard): reads stolen pages; teaches **spread** and **interrupts**.
   - Phase 1: Loose Pages (spread marks on 2 players), Ink Blast (interrupt it).
   - At 50% he switches to **Fire Pages**: Burning Ink (pools), Page Flare (eruptions), and faster Loose Pages on 3 players.
3. **Siegemaster Gorrik** (Siege Yard, big goblin): teaches **stack** and the **ballista**.
   - Ground Pound (slam), Artillery (barrage), Fire Pots (pools), Boulder (stack: shared by up to 3 players), Call the Crew (interrupt).
   - Enrages at 30%.
4. **Skrag the False Binder** (Keep): a goblin who bound stolen pages into a crude book. The exam: everything above.
   - Phase 1, martial pages: Cleave, Charge, Ring of Steel (get close).
   - At 66%, **Fire Pages**: a warband wave, Ember Rain (pools), Scorch Marks (spread).
   - At 33%, **The Book Tears**: Torn Pages (stack), Page Storm (barrage).
   - Enrages at 20%. Cleave runs in every phase.

## Swapping it out later
- **Map**: edit the layout scene in the editor (DungeonRoom, PackMarker, SetPieceMarker nodes).
- **Art**: set the recipe's `art_scene` (see docs/DUNGEONS.md).
- **Markers**: give the biome kit a `mechanic_theme`.
- **Names and fiction**: `names.gd`.
