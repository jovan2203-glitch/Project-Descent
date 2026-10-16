# Systems

## Books and specs
- Books: Fire, Frost, Lightning, Arcane, Shadow, Nature, Holy, Martial (warrior/rogue/ranger combined; was "Physical"). Martial isn't designed yet; Nature has its caster (docs/design/nature.md). Holy was wiped (all 7 abilities, Heal included) and is being rebuilt from docs/design/holy.md: the healer (Hymns) is built, the rest are drafts.
- Book layout: abilities on the left page, that book's talent tree on the right. Layout symmetrical; spellbooks never change position.
- Specs (visual only): each book's abilities are split by playstyle under named dividers in the main-menu books and the in-game spellbook (P). Names and contents: `Abilities.SPECS`. Every ability sits in exactly one spec of its book (tests/test_books.gd). Specs: Fire - Steady Flame, Slagforged, Forge Heat, Pitch and Cinder. Frost - Hard Winter, Cold Comfort, Frostbitten Steel, Winter Hunt. Lightning - Live Current, Stormdancer, Lightning Rod, Stormstring. Arcane - Clockwork, Hall of Mirrors, Second Act, Aetherstring. Shadow - The Breach, Pack of Two, Strings Attached, Nightstring. Nature - Thornweaver, Shepherd, Colossus, Venomstring (the rest come with their specs). Holy - Choir of One, Line of Light, Lightstring, Censer Bearer (the rest come with their specs). Martial - Warpath, Iron Line, Knife Work, Huntsman.
- Every character (level 1 / after death) gets a basic ability of every element plus a heal (Psalm, from the Holy healer), a tank spell and a taunt.
- Mana: every spec that uses mana runs out eventually, after roughly 5-7 minutes of nonstop combat (not soon). Mana costs are in points (10% of base mana) and may be fractions.
- Interrupts exist for mage, rogue and warrior.

## Abilities, spellbook, action bars
- Level-up draft offers new abilities. Skill Cards are equipped as a loadout in their own main-menu tab.
- No action bar in the main menu: learning just learns; abilities go on bars in game, dragged from the spellbook.
- In-game spellbook on P: swaps already-learned abilities out of combat; never swaps Skill Cards. Talents shown next to abilities, read-only.
- Rune-taught spells: unique tab above the spellbooks in the main menu, normal tab in game.
- Extra action bars (above main and both sides), opacity settings, keybinds. On-use trinkets can go on bars.
- Macros (Esc menu in game and main menu): sequence abilities or several off-GCD things on one button, icon from in-game icons; linking a spell at the top shows its cooldown and tooltip.
- Abilities & Talents search (global and per book, keyword matching, also on runes screen); hovering highlights mentions both ways.
- Mouseover casting (Settings > Interface, off by default), like WoW: pressing an ability with the mouse over a legal target (enemy, ally or you, or your prism) uses it there without changing your target; an illegal one is ignored.

## Runes
- Rarities: Legendary (build-defining, max 1), Epic (max 4, no duplicates), Rare/Common (up to 3 of the same, some unique at 1). Menace threat runes: one per damage type, only one Menace at a time.
- One Rune Management window: list with filter and Rune Shard count, craft unknown runes, engrave onto equipped items (replacing is free), rune transfer.
- Salvage items for Rune Shards, craft any chosen rune. Skill Card chests: 70% chance for a Mysterious Rune - used in the main menu it offers 3 runes of the same rarity; rarity clearly visible.

## Pacts
- Baseline for every character; Pacts menu above the rune abilities menu. One Pact at a time, per dungeon.
- Each Pact: a bonus, a drawback, and a forbidden action. Doing it breaks the Pact and leaves a permanent negative until the dungeon ends. It must be a real risk and not avoidable just by skipping certain abilities. Named "Pact of X".
- Built: Unbowed, Thin Line (breaking removes 10% max HP), Relentless, Sidestep, Purist (20% more damage, one chosen book), Fast, Shepherd, Vanguard, Restless, Reservoir.

## Dungeons
- Queue solo or as a party into one random self-contained dungeon (beginning and end, no checkpoints). Play screen also lets you pick a dungeon for testing.
- Enemy level = party average weighted toward the highest; a max-level player can't carry a level 1 friend. Scale enemies, not players.
- Each dungeon has 3-4 unique bosses. Modifiers shown clearly on load (screen 60% shorter than originally).
- Old crypt out of the random pool; cave removed. Walls look natural with lots of decoration.
- Training Room: daytime castle courtyard, dummy stations (single target, AoE, healing, tank, pack) in a circle around spawn.
- Enemies: zombies, goblins (melee, wizard, archer). Enemies overlap ~85% but never stack exactly, and spread out a little around the player. Leash range doubled, measured from the enemy's current position; an evading enemy first switches to someone else on its threat table.

## Multiplayer and lobby
- Player-hosted, host-authoritative via Steam. Steam friends invites, parties up to 5, queue auto-fills; a full party goes in instantly. Host migration when the leader leaves (brief pause is fine).
- Main menu lobby: party chat with console commands, only on the Lobby tab; podiums under party invite cards with members' character models. Later: equipped gear on models, character customization.

## Items and meters
- Gear has level requirements; higher stats = higher level. Every bank gets basic starter weapons. Shift over an item compares with the equipped one (green/red).
- Off Hand: shields, plus non-weapon spellcasting off hands (Worn Tome, Ashwood Wand) and the Brass Lantern (Armor, Strength, Constitution: the Holy tank's off hand; the tank works with any off hand item). Any one-handed melee weapon also fits it (dual wield). Caster one-handers: Ritual Dagger, Runed Blade (Intellect + Spell Power). These are base templates; stats will be tuned later. Abilities check the off hand with `Abilities.offhand_type()`.
- Damage/healing meter (per-spell breakdown, buff-uptime tab); every added-damage source has its own line.
- Give item works in game and in the main menu.

## Launcher
- Settings pre-launcher that pulls updates from GitHub Releases.
- Open: Windows SmartScreen warning on launcher.exe.

## Code layout and tooling
- The player is split: `scripts/player.gd` is the shared core; each spec (and some rune / talent groups) is a component in `scripts/player/` (`player_kit.gd`: a child node with `player` = the player node). The player keeps one-line forwards for everything other scripts call on it. `tools/split_section.pl` / `split_batch.sh` / `split_tests.pl` did the split and can move further sections.
- Tests run headless (`tools/test.sh`) and on GitHub on every push; `tools/release.sh` tags a release and GitHub builds and publishes it.
- `tools/balance_sim.tscn` estimates every spec's damage / healing at level 50 (no talents, runes or procs) into `docs/BALANCE_REPORT.md`.
