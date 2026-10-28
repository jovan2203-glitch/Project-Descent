# In-game UI

One flat look for everything in a dungeon (no name, it's just the UI): sharp
corners, a near-black backdrop with a 1 px black outer line and a dim inner line,
flat bars, outlined text (`scripts/ui/skin.gd`, `scripts/ui/hud_bar.gd`). The
main menu keeps its own look (`ui_kit.gd`); in-game windows built with ui_kit
(Character, Bags, Bank, Spellbook, Esc menu, Settings, map, damage meter and its
breakdown, inspect, macros, level-up panel) are converted with
`UISkin.skin_window()` / `restyle()`: sharp, flat, the accent instead of gold.

Layers: HUD 1, game UI panels 2, training panel / dungeon banners 3, damage
meter 4; windows, the map, the Esc menu and the meter breakdown 20 (always over
the HUD); Move UI and UI Options above those.

## Layout

Sized for the 1152 x 648 UI space (the project's base viewport; wider screens get
more room at the sides, Interface size scales it all).

- Bottom centre: action bars stacked (bar 1, then 2 and 3 above it; bar 4 is a
  column on the right edge), the XP bar under them.
- Above the bars, either side: player frame (left) and target frame (right),
  their cast bars under them. Aura bars (a Tracker group) above the player frame.
- Bottom-left: the chat panel; under it an info strip with the micro menu
  (Char / Book / Bank / Bags / Meter) and up to three info texts (texts that
  don't fit beside the buttons are left out, last first).
- Training room: a small Reset / Leave panel on the left (movable in Move UI).
- Bottom-right: the meter panel with the damage meter docked in it, and an info strip.
- Top-right: the square minimap (dungeon name above, clock under), buffs and
  debuffs left of it.
- Party frames on the left (healer layout: a row above the bars).

## Role layouts and setup

Four layouts (`UIConfig.PRESETS`): Tank, Healer, Physical DPS, Caster DPS. Each
places every element and may change a few values (healer: party frames in a row
above the bars; caster: a wide cast bar above the bars; tank: bigger health and
debuffs). Move UI puts an element the player never moved where the layout says;
Reset in Move UI goes back to the layout's place.

UI setup (`ui_installer.gd`) opens the first time you enter a dungeon: Welcome,
Layout (with a picture of each), Interface size, Chat and meter, Done. Settings >
Interface runs it again.

## Options

UI Options (`ui_options.gd`; Settings > Interface, `/ui`, Move UI's top bar, a
mover's right-click panel) has a page per element, built from `UIConfig.schema()`:
every element has Enabled, Scale, Opacity and Show (always, only in / out of
combat, on mouseover) plus its own options (sizes, texts, auras, grow direction,
sort, info texts...). Values apply at once. Export / Import shares a whole UI
(layout, positions, options) as one line of text.

## Trackers

Player-built UI elements, like WeakAuras (`scripts/ui/trackers/`, `/trackers`):
icon, bar, text or ring displays driven by triggers (effect on you / your target /
the party, cooldown, resource or spec value, event, item equipped, state), with
any/all combining, conditions (colour, glow, opacity, text past a mark) and load
rules (spec, role, combat, party, dungeon). Groups stack their showing trackers.
Templates, duplicate, and Import / Export of a tracker or group.

- Tooltips show the ID of abilities, items and effects ("Show IDs in tooltips");
  the editor has a searchable ID picker.
- Spec values (Venom, Verses, Chain, Wheel uses, Ice Shards...) come from one
  hook: each player component may implement `tracker_values()`, merged by
  `Player.tracker_values()`. A new spec adds its values there, no tracker code.
- Trackers read only what this client knows, so they work the same for the host
  and guests. Own-only: a target effect counts only when it is yours (by default).
- Each role starts with empty "Aura Bars" and "Cooldowns" groups (tanks and
  healers also get a low-health warning).

## Main menu

Its own look (`ui_kit.gd`); code in `scripts/main_menu.gd` plus one part per tab or
overlay in `scripts/menu/`.

- Lobby: your character on a pedestal in a 3D backdrop (`scenes/menu/lobby_backdrop.tscn`:
  a stone clearing, a ruined dungeon gate, a campfire behind the party; placeholder
  art, swapped as one scene). Drag on empty space to turn your character (Lobby and
  Character); it turns back after 2 s.
- Party cards: name, level and main spec (most abilities on the bars), a role icon
  and a strip in the spec's book colour. Members send their info when it changes
  (`Net.update_my_info`).
- Ready check (`ready_check.gd`, `Net` "Ready check"): the leader's button, a
  "Ready?" popup with a 20 s countdown, a tick / cross on every card. With a party,
  Enter Now and Queue always run one first; one "Not ready" or the timeout stops it.
- Play screen (`queue_page.gd`): a card per dungeon (its biome colour, best clear on
  the chosen difficulty) and a side panel with objectives, modifiers, enemy level,
  best clears per difficulty, difficulty, your Pact, Queue / Enter Now. The choice
  is remembered; PLAY's second line names it.
- Loadouts (`loadouts.gd`, `PlayerData` "Loadouts"): up to 6 saved setups (talents,
  action bars, attribute points, Pact), from Abilities & Talents → Loadouts, with a
  quick swap beside your name in the lobby. Menu only. Talents from an older tree
  version, or costing more points than you have, are left out with a note.
- Friends: Join on a friend who is in this game with a party of their own.
- What's new (`whats_new.gd`): the newest patch notes, from a button at the top
  left; a dot until opened. Builds read `data/whats_new.md` (the release workflow
  copies the newest notes there).
- Last run (`last_run.gd`, `GameManager.last_run`): a card at the top right after a
  dungeon: cleared or left early, time (new best), bosses, enemies, XP and levels,
  the loot that went to the bank, and the party's damage and healing for the whole
  run. It stays until dismissed or the next run.
