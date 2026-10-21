# Systems

## Books and specs
- Books: Fire, Frost, Lightning, Arcane, Shadow, Nature, Holy, Martial (warrior/rogue/ranger combined; was "Physical"). Martial was wiped (all 16 abilities, the starter kit's Heavy Blow, Headsman's Cut, Stoneguard and Taunt included) and is being rebuilt from docs/design/martial.md: the Wheel (warrior), the Brawler (tank), the Rogue and the Sharpshooter (archer) are built, and so is its talent tree. Nature has its caster (docs/design/nature.md). Holy was wiped (all 7 abilities, Heal included) and is being rebuilt from docs/design/holy.md: the healer (Hymns) is built, the rest are drafts.
- Book layout: abilities on the left page, that book's talent tree on the right. Layout symmetrical; spellbooks never change position.
- Specs (visual only): each book's abilities are split by playstyle under named dividers in the main-menu books and the in-game spellbook (P). Names and contents: `Abilities.SPECS`. Every ability sits in exactly one spec of its book (tests/test_books.gd). Specs: Fire - Steady Flame, Slagforged, Forge Heat, Pitch and Cinder. Frost - Hard Winter, Cold Comfort, Frostbitten Steel, Winter Hunt. Lightning - Live Current, Stormdancer, Lightning Rod, Stormstring. Arcane - Clockwork, Hall of Mirrors, Second Act, Aetherstring. Shadow - The Breach, Pack of Two, Strings Attached, Nightstring. Nature - Thornweaver, Shepherd, Colossus, Venomstring (the rest come with their specs). Holy - Choir of One, Line of Light, Lightstring, Censer Bearer (the rest come with their specs). Martial - The Wheel, Brawler, Rogue (fourth slot open).
- Every character (level 1 / after death) gets a basic spell of every element (Frost Bolt, Whiteout, Firebolt, Lightning Bolt) plus a heal (Psalm, from the Holy healer). No starter tank spell or taunt since the Martial wipe: tanks taunt with their own book's abilities (Cold Shoulder, Decoy, Draw the Storm, Raise the Censer, Reel In, Grasp, Stomp).
- Mana: every spec that uses mana runs out eventually, after roughly 5-7 minutes of nonstop combat (not soon). Mana costs are in points (10% of base mana) and may be fractions.
- Interrupts: Unweave (Counterspell, Arcane), Rimelock (Frost), Jolt (Lightning), Hush (Shadow), Furnace Breath (Fire), Circle of Silence (Holy). They share one cooldown. Nature has none on purpose: it has the most crowd control.

## Utility, roots and reviving (2026-10-17)
- Each book's "Utility" divider (`Abilities.SPECS`) holds its crowd control, roots, interrupts, movement, party buffs and self defensives that work without the rest of a spec's kit. One stays in its spec only if it can't be used without it: it needs the spec's resource or objects (Strings, Reflections, prisms, Incense, Fury, Sap, the Breach) or a bow. A melee weapon doesn't count (anyone can hold one). Damage spells with a control rider (Frost Nova, Collapse) and tank taunts / active mitigation (Crossguard, Reflex Arc, Reel In, Grasp, Decoy) stay in their specs. The balance sim adds a book's Utility to every spec of that book.
- Utility-only code: scripts/player/utility.gd (the roots plus Bellows, Storm Front, Climb the String, Circle of Silence and Nature's tools); the rest is coded with its book (Martial's with the Rogue, scripts/player/martial_rogue.gd). Check this table before adding utility, so no book gets a near-copy of another's, and keep it current.
- Nothing that can force-move or rewind teammates without a gate (Yank needs the ally on your String): too easy to troll with.
- Every book has its own kind of root, each working differently (tests/test_books.gd checks one exists): Frost Icepin (arrow), Shadow Tangle (Strings across the floor), Nature Rootsnare (target and enemies around it, leaves Mulch), Fire Cooling Slag (pool slows, then hardens), Lightning Static Snare (leaps on once when it ends), Arcane Fixed Point (longer per Arcane spell on cooldown), Holy Binding Ring (ring around an ally roots the first 3 enemies that come close), Martial Pin the Shadow (lasts until the enemy has taken 3 direct hits, from anyone).
- Reviving: no F-revive. Only healer abilities bring anyone back (tags "Revive" / "Resurrect"; only in `Abilities.HEALER_SPECS`). Combat revives: Last Verse (Choir of One), Not Finished With You (Strings Attached). They spend the party's combat rez charges (2026-10-21): none at the start of a run, one more every 5 min (Balance.COMBAT_REZ_INTERVAL), unused ones stack; the timer runs across floors and starts over on a new run. The host keeps the count (Net.combat_rez_charges / spend_combat_rez, sent with the party info); rules in RezKit. With none: "No combat rez available", nothing spent. Out-of-combat rezzes and the Training Room are free. Any new combat revive must check rez_kit.combat_rez_error() and call rez_kit.spend_combat_rez() (tests/test_combat_rez.gd). Every healer spec, now and future, has an out-of-combat rez (8 s cast, 4 mana, 30 m; a dead or downed ally gets up where they fell with 50% health and mana): Hymn of Waking (Choir of One), Relight (Line of Light), Back on Your Feet (Strings Attached), Return to Bloom (Shepherd), Spring Thaw (Cold Comfort). Code: scripts/player/rez.gd; their machine stands them up (Net.raise_ally -> GameManager.raise_local).

Bold = in the book's Utility divider; the rest sits in a spec (it needs that spec's kit, a bow, or is a damage spell / tank button).

| Utility | Fire | Frost | Lightning | Arcane | Shadow | Nature | Holy | Martial |
|---|---|---|---|---|---|---|---|---|
| Interrupt (shared cooldown) | **Furnace Breath** (cone) | **Rimelock** (+Chill) | **Jolt** (+Energy) | **Unweave** (longest lockout) | **Hush** (+Breach) | - | **Circle of Silence** (area, 4 s) | - |
| Root | **Cooling Slag** (pool slows, then hardens) | Icepin (arrow; needs a bow) | **Static Snare** (leaps on once) | **Fixed Point** (longer per Arcane cooldown) | **Tangle** (area) | **Rootsnare** (target + around it) | **Binding Ring** (ring around an ally) | **Pin the Shadow** (until hit 3 times) |
| Other crowd control | **Bellows** (knockback) | **Flash Freeze** (cone Freeze); Frost Nova, Deep Winter (Freeze) | **Thunder Strike** (stun) | Collapse (pull) | **String Up** (stun) | **Spore Sleep** (sleep until hit); Grasp, Choking Vipers, Coil Back's trap, Stomp's roots (hold); Asp Arrow (slow) | - | Rogue: Snatch's Flash Powder (blind) |
| Mobility | **Cinder Step** (dash, burning line) | Icy Retreat (leap back; needs a bow) | **Flicker** (blink, press again to snap back), **Static Step** (dash to target) | **Phase Step** (blink) | **Climb the String** (haul to ally or enemy) | Coil Back (leap back; needs a bow) | Step of Light (to a prism) | **Over the Shoulder** (vault behind, sure crit); Rogue: Dart In, Kick Off; Wheel: Rush, Drag In |
| Self defensive | **Heat Sink**; Slag Skin, Cinderguard (tank) | **Winter Hide**, **Ice Barrier**; Hailcoat, Hard Rime, Glacial Bulwark (Ice Layers) | **Faraday Guard**, **Ground Out**, **Recharge**; Crossguard, Reflex Arc (tank) | **Interval Ward**; Stand-in, Crowd of One, Trade Places (Reflections) | Behind Its Back (String), Guard Dogs (Fury), Take It Back (Breach) | **Deep Roots**; Giant's Hands (Fury), Heartsap (Sap), Awaken | **Rest**, **Unfallen**; Aureole, Absolve (Incense) | **Play Dead**; Rogue: Roll With It (Flow); Wheel: Blade Guard; Brawler: Tough It Out, Clinch |
| Ally shield | - | Rime Shell, Rime Veil, Rimefall (Cold Comfort) | - | - | Cupped Hands | Rootguard | Shelter, Prism Ward | - |
| Party tools | **Cinderwing** (phoenix heals) | **Snow Ward** (party shield) | **Storm Front** (speed) | - | Yank (String) | - | **Steady Voice** (party damage reduction) | - |
| Threat | - | - | - | - | - | **Leaf Cloak** (drop) | - | **Play Dead** (enemies forget you) |
| Revive | - | Spring Thaw | - | - | Not Finished With You, Back on Your Feet | Return to Bloom | Last Verse, Hymn of Waking, Relight | - |

Open gaps: Arcane has no party tool; Holy's only crowd control is Binding Ring and Circle of Silence; Nature has no interrupt (on purpose); Martial has no interrupt or party tool yet.

## Interface: party frames, Move UI, roles (2026-10-21)
- Roles: `Abilities.SPEC_ROLES` (spec -> dps / tank / healer / utility; the balance sim reads it too). A player's role = the role with the most abilities on their bars (`Abilities.role_of_bar`; Utility doesn't count; ties: healer, tank, dps). Sent with each player's state (Net._pstate) for the others' party frames.
- Party frames (scripts/ui/party_frames.gd), WoW-style, on the right under the target frame: one per member, you first; name, health with shields on it, a role icon (shield / cross / sword), a Rime Shell / Thawing pip. Click = friendly target; hovering a frame sends heals there whether mouseover casting is on or not. Out of 40 m or sight: dimmed; downed or dead: greyed. The party's combat rez charges and the next one's countdown under them. Shown in a party (Settings > Interface: "Party frames when solo").
- Targeting allies: Rime Shell goes to the ally under the mouse (world or frame) before your enemy target; with no ally there, an enemy under the mouse; then your target; then you.
- Move UI (scripts/ui/ui_layout.gd), ElvUI-style: Settings > Interface > Move UI (in a dungeon, out of combat). The screen darkens under a grid; each HUD element gets a labelled box to drag, snapping to the grid, other boxes' edges and the screen centre (Shift: free). Right-click: exact X / Y, arrow nudges (Ctrl 10 px), Reset. Top bar: grid size, snapping, Reset All, Lock (or Esc). Saved as the nearest of 9 screen anchors plus an offset (Settings.ui_layout, [ui_layout] in settings.cfg). A new HUD element registers with UILayout.register(get_tree(), node, key, label).

## Tanks deal less, for more threat (2026-10-21)
- While your bars make you a tank (`Abilities.role_of_bar`), every hit you deal (auto-attacks, abilities, DoTs, retaliation, shatters, runes) is `Balance.TANK_DAMAGE_PCT` (35%) of what it would be and makes `TANK_THREAT_MULT` (x1.4) the threat, on top of each ability's own multiplier. Heals and shields are not affected; tooltips show the real damage and threat.
- Losing aggro is meant to happen: enemies attack whoever has the most threat, a tank makes about 1.3-1.7x a top DPS's threat, so steady damage stays under it, but a big burst, a crit spike or an opener before the tank has built a lead can pull. Taunts and the threat warning (enemy.THREAT_WARN, the bar glow) are the tank's tools. Tank threat before this pass was 4100-8150 TPS (nobody could pull); now 2850-3315.
- Code: CombatSystem.deal asks the attacker (Player / RemotePlayer `outgoing_damage_mult`, `outgoing_threat_mult`); exact hits (shares of hits that already had it) are left alone, except Turn It Around, which applies it itself. Tooltips: `Abilities.damage_mult` (your own bars).
- Targets: 30-40% of a top DPS (600-800 geared) and 1.3-1.7x its threat (2600-3400 TPS); tools/balance_sim.gd reports TPS and flags both, tests/test_tank_rule.gd checks every tank. Threat tuned: Brand 5x (was 3x), Anvil 6x (was 4x), Shattering Slam 5x (was 3x), Censer Swing 3x (was 4x), Pour Out 4x (was 6x). Tuned on top of the rule: Brand 1.0 (was 0.3) + weapon, Anvil 0.65 (was 0.3) + half weapon, Shattering Slam 1.9 weapon (was 1.5), Rimequake 0.65 (was 0.5), Return Stroke 1.0 weapon (was 1.2), Censer Swing 0.5 (was 0.7).

## Talents (2026-10-21)
- Goal: about 65 of the 80 points fully build one spec; hybrids give up a little in one spec to gain a little in another. Taking talents from other books is normal. Most talents should key off a resource, keyword or damage type (they reach every build using it); at most about a quarter are "Requires X" talents, and those change how the ability works. Runes connect specs; talents never reference another book's content.
- Pass 1 (done): 2-rank "Requires X" talents became 3 ranks with the same max (rank 3 = the old rank 2), except the ones whose steps are whole numbers (extra targets, darts, Reflections, Cracks, Flow, arrows, Incense, Energy per zap, Pin hits, Easy Release). In and Out, Steady Pace, No Letup and Long Memory no longer require one ability (they work off Flow, Streak and Traces).
- Folded into their abilities (slots left empty for new keyword talents; their icons are kept in TalentIcons.SPARE): Furnace Heart (Cinder Guard costs 20 Fury), Thick Pitch (pitch lasts 12 s), Thick Hide (Winter Hide 40 s cooldown), Honed Edge (Charged Edge gives 30 Energy), Deep Well (Collapse pulls 5 m), Cut Short (Hush: 4 s off when it interrupts), Quick Return (Return to Bloom 4 s cast), Big Herd (Wild Herd 90 s), Deep Pockets (Snatch 10 s), Round Two (One More 9 s), Last Rites (Last Verse 2 min), Swift Light (Step of Light 10 s), High Censer (Raise the Censer 1 min, cost 1.3 mana points).
- Next: new keyword talents per spec, and the layout (each book on one screen, specs as column groups with faint lines between them, capstones need 25 points in their spec).

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
