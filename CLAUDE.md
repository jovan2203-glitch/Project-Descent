# Project: Descent

Godot 4.7 3D co-op action-RPG (dungeons, ability books, talents, runes, Pacts). Multiplayer is player-hosted (host-authoritative) via Steam, parties of up to 5.

## Where things are
- `scripts/balance.gd` - every damage, cooldown, cost, duration and talent rank value. Never hard-code these elsewhere.
- `scripts/abilities.gd`, `talents.gd`, `runes.gd`, `skill_cards.gd`, `items.gd` - content definitions.
- `scripts/net/` - networking. `scripts/dungeon/` - dungeons. `scripts/ui/` - interface.
- `tests/test_*.gd` - test suites, run with the godot-ai `test_run` tool (open `res://scenes/main_menu.tscn` first).
- `docs/design/` - one design file per book plus `systems.md`. Read only the file the task needs.
- `docs/INTERACTIONS.md`, `docs/DUNGEONS.md` - interaction and dungeon reference.
- `docs/PATCH_NOTES_YYYY-MM-DD.md` - patch notes (use the descent-patch-notes skill).

The code and balance.gd are the source of truth for numbers. Design docs record intent; update the matching doc when a design changes.

## How we work
- Never run or playtest the game (no project_run, input simulation or game screenshots). The user tests and reports back.
- After a change, run the relevant tests and check the editor log for errors. Don't list things to test; only flag something when genuinely unsure it works.
- Replies: short, no filler, but include the specifics.
- "Frost Bolts" (FB) is a conversation-only damage unit (1.0 FB = one Frost Bolt's damage). Everything shown in game uses real numbers.
- Patch notes: clean, proper wording (never the user's rough phrasing), no filler, no missing details. A new talent is written as "New talent", its name, then what it does.
- Use plan mode for anything bigger than a single ability or talent.
- Adding or changing abilities, talents or runes: follow the descent-add-content skill.

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
- Core goal: heavy interaction between abilities, damage types, resources, buffs and debuffs, all easy to reference.

## Writing abilities and talents
- Keywords in orange, with Shift explanations at the bottom of the tooltip (talents, runes, abilities; not item comparison).
- An ability with no scaling math has no scaling section.
- Single-ability talents show "Requires X to be learned" and block point spending.
- A book's important talents sit higher in its tree, linked to their ability; minor ones lower. Archery talents of a book are grouped together. Rows stay symmetrical, 2-4 talents per row.
- Open talents are themed to their book but useful to anyone, and never tell the player what to combine.
- Spellbooks never change position.

## Death and progression
- Roguelike death is PAUSED: dying just revives or returns to menu. Don't remove the system; keep new features compatible with it.
- When active: dying resets to level 1, losing equipped gear and abilities. Bank items stay. A rune on a lost item becomes a known rune. Abilities return via Skill Cards from chests.
- Level lock every 10 levels: on death you drop to the lock level and keep gear you can still equip.
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
- Energy and rage are 100/100 bars; every cost is on that scale.
- Natural HP regen. Items have no durability.
- In combat while anything is aggroed on you or a party member (+1 s after kills, +2 s after an evade). WoW-style line of sight; no facing requirement.
- Tanks make more threat baseline; healing makes threat.

## Balance targets
- Level 50, no gear: ~500 damage per ability; a big buffed crit ~1000; max-level geared DPS ~2000 DPS.
- A 5-DPS group should only work at absolute top-end play.
