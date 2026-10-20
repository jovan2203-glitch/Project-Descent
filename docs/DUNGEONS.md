# Dungeons

Queue (Play screen) -> a random dungeon from the pool, or pick one under "Join a specific dungeon (testing)".
Enemy level = party average pulled toward the highest level (Balance.DUNGEON_LEVEL_TOP_WEIGHT, 0.5: a 50 + a 1 fight level 38).

## Files
- `data/dungeons/*.tres` - one RECIPE per dungeon (DungeonRecipe). New file = new dungeon, no code. Set `in_random_pool`.
- `data/biomes/*.tres` - BIOME KITS (look): wall/floor colors and pattern, corner + doorway pieces, lights, fog, props, music tag.
- `scripts/dungeon/names.gd` - EVERY visible name (dungeons, enemies, bosses, abilities, modifiers, objectives). Rewrite this one file when the lore arrives.
- `scripts/dungeon/roles.gd` - the fixed enemy ROLES: brute, swarmer, caster, archer, defender, support, summoner (+ elite / boss ranks).
- `scripts/dungeon/layouts.gd` - layout styles: linear, hub, descent, cavern, arena, maze.
- `scripts/dungeon/boss_kit.gd` - boss ability types: slam, nova, donut, eruption, barrage, cone, charge, summon, big_cast, heal, enrage.
- `scripts/dungeon/modifiers.gd` - dungeon modifiers (frost_touched, volatile, bloodthirst, darkness, frenzy).
- `scripts/dungeon/dungeon_run.gd` + `scenes/dungeon_run.tscn` - the generic runner.
- `scenes/dungeon.tscn` - the OLD endless crypt, testing only (never random).

## Recipe
- `roster`: role -> skin `{scene, name (names key), weight, tint, cast, school, color, summons}`. Reskin = change scene / name / tint.
- `bosses`: 3-4 entries `{name, skin{scene, tint, scale}, role, hp, dmg, abilities[{type, name, cd, first, coef, ...}]}`.
- `objectives`: one per boss section, cycled: reach_exit, clear_pct, key_elites, survive_waves, defend, timed_escape (hub: the final boss needs the wing bosses).
- `modifier_pool` / `modifier_count`: rolled from the run seed (same for the whole party), shown on load and under the header.

## Death
Balance.ROGUELIKE_DEATH = false: dying costs nothing. Revive (R / button) at the entrance or the last boss room cleared, or go to the menu.

## Melee tells
Every melee hit (trash, elites, bosses' auto-attacks) shows a short bright tell before it lands (`Balance.MELEE_TELL_TIME`, 0.6 s; Hasted elites and Frenzy shorten it). Same hit rate as before. Stuns and knockdowns stop the hit; interrupts don't (it isn't a cast). The Brawler's Catch works on it. See docs/INTERACTIONS.md.
