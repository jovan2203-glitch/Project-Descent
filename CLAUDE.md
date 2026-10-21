# Project: Descent

Godot 4.7 3D co-op action-RPG (dungeons, ability books, talents, runes, Pacts). Multiplayer is player-hosted (host-authoritative) via Steam, parties of up to 5.

## Where things are
- `scripts/balance.gd` - every damage, cooldown, cost, duration and talent rank value. Never hard-code these elsewhere.
- `scripts/abilities.gd`, `talents.gd`, `runes.gd`, `skill_cards.gd`, `items.gd` - content definitions.
- `scripts/player.gd` - the player's shared core (stats, casting, targeting, damage, resources, co-op). Each spec's code is a component in `scripts/player/` (see `player_kit.gd`): a new spec gets its own component file, hooked from player.gd, never a new section in player.gd.
- `scripts/main_menu.gd` - the main menu's shared core (scene, pages, nav bar, XP bar, input callbacks, toasts). Each tab's code is a part in `scripts/menu/` (see `menu_part.gd`): a new tab or overlay gets its own part, never a new section in main_menu.gd. Tests that check menu code text read `MenuSource.text()`.
- `scripts/net/` - networking. `scripts/dungeon/` - dungeons. `scripts/ui/` - interface.
- `tests/test_*.gd` - test suites. Run them headless with `tools/test.sh [suite] [test]` (no editor, no stale caches), or with the godot-ai `test_run` tool (open `res://scenes/main_menu.tscn` first). Tests that check player code text read `PlayerSource.text()`.
- `tools/balance_sim.tscn` - approximate per-spec DPS / HPS at level 50; writes `docs/BALANCE_REPORT.md` (`godot --headless --path . res://tools/balance_sim.tscn`). Rerun it after balance changes.
- `tools/release.sh X.Y.Z` - publishes a release: tags it; GitHub Actions (`.github/workflows/`) tests, builds, zips and publishes it with the newest patch notes. Every push also runs the tests on GitHub.
- `docs/design/` - one design file per book plus `systems.md`. Read only the file the task needs.
- `docs/INTERACTIONS.md`, `docs/DUNGEONS.md` - interaction and dungeon reference.
- `docs/PATCH_NOTES_YYYY-MM-DD.md` - patch notes (use the descent-patch-notes skill).

The code and balance.gd are the source of truth for numbers. Design docs record intent; update the matching doc when a design changes.

## How we work
- Never run or playtest the game (no project_run, input simulation or game screenshots). The user tests and reports back.
- After a change, run the relevant tests and check the editor log for errors. Prefer `tools/test.sh` (headless) over the editor's test_run. Don't list things to test; only flag something when genuinely unsure it works.
- Replies: short, no filler, but include the specifics.
- "Frost Bolts" (FB) is a conversation-only damage unit (1.0 FB = one Frost Bolt's damage). Everything shown in game uses real numbers.
- Patch notes: clean, proper wording (never the user's rough phrasing), no filler, no missing details. A new talent is written as "New talent", its name, then what it does.
- Use plan mode for anything bigger than a single ability or talent.
- Adding or changing abilities, talents or runes: follow the descent-add-content skill.
- Changing talents (adding, moving, removing or changing one): bump `Talents.TREE_VERSION`. Every player's talent points are then refunded on their next load. Don't write save migrations to keep talent points in place.

## Code structure
- Enemy systems and optimizations are generic, never built for one enemy type.
- Art stays swap-ready: Mixamo-compatible humanoid rigs, real-world scale (~1.8 m human), visuals in separate scenes/child nodes from gameplay logic and hitboxes.
- Dungeons, enemies and environments must be easy to reskin or replace (no story yet).
- Performance matters.
- Art direction: bright and clearly visible even in dark dungeons; a little stylized, toward WoW / Guild Wars / Titan Quest 1.

## Core design rules
- Multiplayer-only game. Singleplayer exists only for testing; everything must work in multiplayer.
- Own-only: no interactions between different players' abilities. Everything is own-only unless specifically stated to work for everyone. Exception: the Rime Shell debuff applies to all damage the enemy takes, from everyone.
- Debuffs are rare, powerful and hard to apply; prefer buffs.
- The game must be unique: no WoW-derived ability names or copied kits.
- Spells (casters) vs abilities (martial): any caster spell dealing an element's damage is that element's spell; martial moves (e.g. Searing Strike) are abilities. Spells scale ~60% Spell Power / 20% Attack Power, abilities the opposite.
- DoTs benefit from crit and haste unless stated otherwise.
- AoE caps never deal 0 damage: total damage stays the same and is split evenly across all targets.
- Anything that adds damage to an auto attack or spell gets its own damage-meter line.
- No two abilities share an icon.
- A spell with no target auto-targets the closest legal option.
- Rune procs (e.g. Swiftness) trigger only on your own kills.
- Every book has its own kind of root, each working differently. A book's crowd control, roots, interrupts, movement, party buffs and self defensives go in its "Utility" divider whenever they work without the rest of a spec's kit; one stays in its spec only if it needs that spec's resource or objects, or a bow. Check the utility audit in docs/design/systems.md before adding utility, so books don't get near-copies.
- Nothing that lets a player force-move or rewind teammates without a gate: too easy to troll with.
- Only healer abilities revive (no F-revive). Every healer spec, now and future, has an out-of-combat rez that brings a dead ally back where they fell. Revive abilities never go in non-healer specs. Healer specs: `Abilities.HEALER_SPECS`.
- Core goal: heavy interaction between abilities, damage types, resources, buffs and debuffs, all easy to reference.

## Writing abilities and talents
- Keywords in orange, with Shift explanations at the bottom of the tooltip (talents, runes, abilities; not item comparison).
- An ability with no scaling math has no scaling section.
- Single-ability talents show "Requires X to be learned" and block point spending.
- A book's important talents sit higher in its tree, linked to their ability; minor ones lower. Archery talents of a book are grouped together. Rows stay symmetrical, 2-4 talents per row.
- Open talents are themed to their book but useful to anyone, and never tell the player what to combine.
- Spellbooks never change position.

## Death and progression
- Roguelike death is PAUSED: dying just revives or returns to menu. Act as if it doesn't exist: don't plan around it, don't patch new features for it, don't remove its code. It is revisited much later.
- XP is permanent; leaving to the menu never loses it. At max level the XP bar is hidden everywhere.
- Max level 50; a new ability every two levels; 1 attribute point per level (respec free in the Character tab).
- Talent points: 5 at start, +1 per level, +1 extra every second level, bonus at max level: 80 total. 3 points in a row unlocks the next row in all trees; maxing a linked talent opens its link without skipping rows.
- Prestige button resets to level 1, keeping only starter abilities.

## Stats and combat math
- Stats: intellect, agility, strength, constitution (replaced stamina), armor, haste, crit rating, spell power, attack power.
- Crit comes from Critical Strike Rating on items: 100 rating = 1%.
- 20% haste = 20% faster casts and 20% faster auto-shots/auto-swings. Keep haste on the low side.
- GCD 1.5 s, benefiting from 40% of your haste.
- Dodge, Parry, Block drop on gear. Dodge slightly boosted by agility; Parry and Block by strength. Dodge and Parry cap at 30% unless an ability raises it.
- Move speed and lifesteal are rare secondaries. Lifesteal returns % of damage/healing done; 5% should be hard to reach.
- Energy and fury are 100/100 bars; every cost is on that scale.
- Natural HP regen. Items have no durability.
- In combat while anything is aggroed on you or a party member (+1 s after kills, +2 s after an evade). WoW-style line of sight; no facing requirement.
- Tanks make more threat baseline; healing makes threat.

## Balance targets
- Level 50, no gear: ~500 damage per ability; a big buffed crit ~1000; max-level geared DPS ~2000 DPS.
- A 5-DPS group should only work at absolute top-end play.
