# Downgate Fort

The test experience's reference dungeon. A hand-made map (`scenes/dungeons/fort/fort_layout.tscn`), recipe `data/dungeons/fort.tres`, names in `scripts/dungeon/names.gd`. Numbers live in the recipe and `balance.gd`; this file records intent.

## Lore
The old Binders built Downgate Fort over the first way down into the Deep. Pages that drifted up were gathered and copied here. A goblin warband took it and is stripping it of pages; its old garrison, fallen Binders, still walks the Scriptorium.

- **Entering**: from the Bindery you take the Long Stair down. It ends at the fort's broken outer gate.
- **The Keep's seals**: the old Binders' page-ward holds the Keep door. Skrag rebound it with three stolen pages, and each lieutenant carries one. Kill a lieutenant and their seal lights up on the Keep Gate; all three open the Keep.

## Map
Every room tells a small story with hand-placed props (PropMarker) and staged packs; the rooms differ in shape (wall blocks) so no two feel alike.

| Room | Size, height | What happens |
|---|---|---|
| The Long Stair (start) | 10×10, +4 m | Safe. Dropped pages and a sack: the goblins carry their loot this way. Stairs down into the fort. |
| Gatehouse | 10×18 (a narrow gate passage), 0 | The smashed outer gate lies on the floor; rubble and a crate barricade narrow the way. Gate guards stand in a line facing the stairs. An **alarm bell** behind them. |
| Courtyard (hub) | 20×20, 0 | The warband's camp: one pack sits around a campfire by a tent, another sorts loot sacks and page piles. Two **archer towers** (raised platforms with stairs), a second **alarm bell**. |
| Barracks → Armory → Drill Yard | 16×12 bunk hall, 10×10, 20×16, 0 | Goblin soldiers between rows of bunks: a line drills in front of a Sergeant. The Armory is cramped and half looted. Target dummies in the Drill Yard. **Objective: kill the two Sergeants** (keybearers). Boss: Captain Brask. |
| Scriptorium → Archive → Reading Hall | 14×16, 18×12, 18×20, 0 | Fallen Scribes still gather at their desks; Fallen Binders at a lectern. The Archive is three aisles between shelf walls: Goblin Looters wander the middle one, a pack browses a side aisle. The Reading Hall has two shelf islands (cover) and Nib's lectern among page heaps and spilt ink. **Objective: slay 75%.** An **alarm bell** in the Archive. Boss: Nib the Page Thief. |
| Keep Gate | 10×12, 0 | The three seal lights; loot waiting to go in; the doors to the Keep and up to the walls. |
| Siege Yard → Workshop → North Wall | 18×18, 12×10, 20×13 (a wall-walk with merlons), +3 m (stairs up) | Sappers around a cart of fire pots, Fire Potters, Haulers, workbenches. An **alarm bell** in the yard. **Objective: hold the yard** (defend circle, 45 s; attackers every 9 s). Boss: Siegemaster Gorrik, with the **ballista**. |
| The Keep | 20×20, 0 | Four pillars, Skrag's throne, the crude book on a lectern, his hoard of pages. Final boss: Skrag the False Binder. Needs all three seals. |

## Set pieces
- **Alarm bell** (Gatehouse, Courtyard, Archive, Siege Yard): a Bell Ringer stands beside each bell. When a fight starts near it, it casts Ring the Alarm (4 s). Interrupt it, stun it or kill it, or a reinforcement pack arrives. Each bell rings once.
- **Archer towers**: raised platforms with archers on top; stairs lead up.
- **Ballista** (North Wall): stand on its plate for 2 s during the Gorrik fight. It Knocks him Down for 3 s, then he takes 25% more damage (Weak Spot) for 8 s. Cooldown 30 s.

## Bosses
All mechanics use the shared look (`scripts/dungeon/mechanic_look.gd`): the same shape means the same thing in every dungeon.

1. **Captain Brask** (Barracks, goblin shieldbearer): teaches **kill the guards**.
   - Shield Bash (frontal cone) and Charge (line).
   - At 66% (3 guards) and 33% (4 guards), **Close Ranks**: he is immune until his shieldbearers die.
   - Enrages at 20%.
2. **Nib the Page Thief** (Scriptorium, goblin wizard): reads stolen pages; teaches **spread** and **interrupts**.
   - Phase 1: Loose Pages (spread marks on 2 players), Ink Blast (interrupt it).
   - At 50% he switches to **Fire Pages**: Burning Ink (pools), Flash Fire (eruptions), and faster Loose Pages on 3 players.
3. **Siegemaster Gorrik** (Siege Yard, big goblin): teaches **stack** and the **ballista**.
   - Ground Pound (slam), Artillery (barrage), Fire Pots (pools), Boulder (stack: on 5 Player it needs 4 players in it, or everyone alive), Call the Crew (interrupt).
   - Enrages at 30%.
4. **Skrag the False Binder** (Keep): a goblin who bound stolen pages into a crude book. The exam: everything above.
   - Phase 1, martial pages: Cleave, Charge, Ring of Steel (get close).
   - At 66%, **Call the Warband**: a warband wave, Ember Rain (pools), Scorch Marks (spread on 3 players).
   - At 33%, **The Book Tears**: Torn Pages (stack: on 5 Player it needs 4 players in it, or everyone alive), Paper Storm (barrage).
   - Enrages at 20%. Cleave runs in every phase.

## 5 Player
Tuned so the Fort needs a full group: a tank, a healer and 3 DPS, at level 50 in full Epic gear (/testkit, ~7,500 party DPS). Singleplayer stays for testing.
- **Health**: placed trash x48, adds that join a fight (boss summons, alarm reinforcements, defend waves) x16, bosses x80 (`Balance.PARTY_*`). A big trash pack ~30 s (a full rotation: build and spend resources, use cooldowns), keybearer and elite packs ~1 min; bosses ~2-3 min (Brask ~900k, Gorrik ~880k, Nib ~1.1M, Skrag ~1.3M).
- **Damage**: trash x3, bosses x4. A boss's melee needs a tank and a healer.
- **Berserk** (hard timer, `Balance.BERSERK_*`): Brask 2:40, Gorrik 2:40, Nib 3:15, Skrag 3:50. A warning 10 s before; then 3x damage and 50% faster attacks. One DPS short runs into it.
- **Stacks need 4**: Boulder and Torn Pages deal 4 players' worth (everyone alive's, once fewer than 4 are), split between everyone inside. With fewer in it, they're lethal; after a death the rest can still soak it together.

## Swapping it out later
- **Map**: edit the layout scene in the editor (DungeonRoom, PackMarker, SetPieceMarker nodes).
- **Art**: set the recipe's `art_scene` (see docs/DUNGEONS.md).
- **Markers**: give the biome kit a `mechanic_theme`.
- **Names and fiction**: `names.gd`.
