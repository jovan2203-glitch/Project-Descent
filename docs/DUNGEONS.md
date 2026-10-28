# Dungeons

Queue (Play screen) -> a random dungeon from the pool, or pick one under "Join a specific dungeon (testing)".
Enemy level = party average pulled toward the highest level (Balance.DUNGEON_LEVEL_TOP_WEIGHT, 0.5: a 50 + a 1 fight level 38).
Lore: docs/design/lore.md. Reference dungeon: Downgate Fort (docs/design/dungeon_fort.md).

## Files
- `data/dungeons/*.tres` - one RECIPE per dungeon (DungeonRecipe). New file = new dungeon, no code. Set `in_random_pool`.
- `data/biomes/*.tres` - BIOME KITS (look): wall/floor colors and pattern, corner + doorway pieces, lights, fog, props, music tag, mechanic theme.
- `scripts/dungeon/names.gd` - EVERY visible name (dungeons, rooms, enemies, bosses, abilities, modifiers, objectives).
- `scripts/dungeon/roles.gd` - the fixed enemy ROLES: brute, swarmer, caster, archer, defender, support, summoner (+ elite / boss ranks).
- `scripts/dungeon/layouts.gd` - layout styles: linear, hub, descent, cavern, arena, maze, or a hand-made map (`from_scene`).
- `scripts/dungeon/authoring/` - the nodes hand-made maps are built from (DungeonLayout, DungeonRoom, PackMarker, SetPieceMarker).
- `scripts/dungeon/boss_kit.gd` - boss ability types (below).
- `scripts/dungeon/mechanic_look.gd` - how every boss mechanic looks (below).
- `scripts/dungeon/set_pieces.gd` - alarm bells, ballistas, seal lights, platforms.
- `scripts/dungeon/pieces/stairs.gd` + `scenes/dungeon/pieces/stairs.tscn` - every staircase.
- `scripts/dungeon/modifiers.gd` - dungeon modifiers (frost_touched, volatile, bloodthirst, frenzy). Modifiers are gameplay affixes (Mythic+ style), never purely visual.
- `scripts/dungeon/dungeon_run.gd` + `scenes/dungeon_run.tscn` - the generic runner.
- `scenes/dungeon.tscn` - the OLD endless crypt, testing only (never random).

## Recipe
- `roster`: role -> skin `{scene, name (names key), weight, tint, cast, school, color, summons}`. Reskin = change scene / name / tint.
- `rosters`: extra rosters by key, for rooms that name one (a wing with its own enemies). Adds use the roster of the room they appear in.
- `bosses`: 3-4 entries `{name, skin{scene, tint, scale}, role, hp, dmg, abilities[{type, name, cd, first, coef, phase, ...}]}`.
- `objectives`: one per boss section, cycled: reach_exit, clear_pct, key_elites, survive_waves, defend, timed_escape (hub: the final boss needs the wing bosses).
- `modifier_pool` / `modifier_count`: rolled from the run seed (same for the whole party), shown on load and under the header.
- `layout_scene` (optional): a hand-made map; `layout` and `rooms_per_section` are then ignored.
- `art_scene` (optional): finished art for a hand-made map (below).

## Hand-made maps
A `DungeonLayout` scene of nested `DungeonRoom` nodes. A child room is joined to its parent by a passage, or by stairs when their `floor_y` differs. Rooms sit on grid cells (`cell` x `cell_size`), and linked rooms must be neighbouring cells.
- **Room**: kind (start, combat, side, junction, hub, boss), section, boss, room_name, roster, centerpiece ("none" = no centerpiece), big_props, no_random_packs.
- **PackMarker** (in a room): exactly these roles + `elites`; `keybearer` marks its elites for key_elites. Its y can stand on a platform.
- **SetPieceMarker** (in a room): alarm_bell, ballista, seal_light, defend_spot, platform (see set_pieces.gd).
- **Art swap**: set the recipe's `art_scene`. It replaces the generated greybox and must carry its own collision and walkable floors. The navmesh bakes from its meshes, so nothing gameplay-related goes in it. The layout scene stays the source of rooms, packs and set pieces.

## Boss mechanics: one visual language
Each ability type belongs to a family. A family's shape means the same in every dungeon; a dungeon's `MechanicTheme` (on its biome kit) only restyles it: colors within the family, and swap-in scenes for `stack_arrow`, `spread_arrow`, `pool_rim`, `guard_bubble`. Pick a family; never invent a new shape.

| Family | Shape | Types |
|---|---|---|
| Avoid | filling red-orange circle / cone / line | slam, nova, eruption, barrage, cone, charge, donut |
| Go here | green circle | donut's safe spot, ballista plate |
| Stack | circle + arrow pointing down into it | soak |
| Spread | circle on a player + arrows pointing out | spread |
| Stay out | lasting pool with a striped rim | hazard |
| Interrupt | cast bar | big_cast, heal, summon, Ring the Alarm |
| Kill the guards | bubble on the boss + lines to its guards | phase with `guards` |

New types: `soak` (radius, time, share_max: the hit x up to share_max players, split evenly), `spread` (radius, time, count), `hazard` (radius, time, duration, tick, extra), `phase` (below, to, guards {role, count}, summon {role, count}). Any ability with `"phase": n` runs only in that phase.

## Stairs
Every height change uses the stairs piece: one smooth slope collider to walk on, with stepped visuals on top (no collision). Pillars, centerpieces and blockers keep out of every doorway's lane (`biome_builder.in_door_lane`). `tools/walk_check.tscn` walks a player-sized body up and down every staircase and platform with real physics; `tools/test.sh` runs it after the suites.

## Death
Balance.ROGUELIKE_DEATH = false: dying costs nothing. Revive (R / button) at the entrance or the last boss room cleared, or go to the menu.

## Melee tells
Every melee hit (trash, elites, bosses' auto-attacks) shows a short bright tell before it lands (`Balance.MELEE_TELL_TIME`, 0.6 s; Hasted elites and Frenzy shorten it). Same hit rate as before. Stuns and knockdowns stop the hit; interrupts don't (it isn't a cast). The Brawler's Catch works on it. See docs/INTERACTIONS.md.
