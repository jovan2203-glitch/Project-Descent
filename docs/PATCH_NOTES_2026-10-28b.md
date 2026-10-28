# Patch notes — 28 October 2026 (2)

Downgate Fort gets a hand-made pass: rooms with their own shapes and stories, staged enemy packs, tougher 5 Player trash and boss Berserk timers. Also: a new Legendary rune, the Rune of the Wild Page; every spec display is now an editable Tracker; and a round of filler and damage tuning across the books. Dungeon modifiers are switched off until their rework.

## Items

- New rune: Rune of the Wild Page (Legendary, unlocks at level 20). Your spells and abilities have a 30% chance to tear a random page from their book: you also cast a random damaging spell or ability of that book at your target, learned or not, with everything it does. It costs nothing, uses up nothing, is cast instantly (a channel goes out at once) and puts nothing on cooldown. Cannot happen more than once every 3 sec. Its damage shows on the meter as, for example, "Fireball (Wild Page)".

## Fire

- Changed: Fireball deals 25% less damage.
- Changed: Vent Flames deals 10% less damage.
- Changed: Flaming Arrow deals 180% weapon damage (was 100%).
- Changed: Coal Shot deals 130% weapon damage (was 70%).

## Frost

- Changed: Frost Arrow is now Winter Hunt's filler: no cooldown (was 5 sec), costs 10 Energy (was 20) and deals 130% weapon damage (was 100%).
- Changed: Icy Retreat no longer resets Frost Arrow's cooldown. Instead it grants Icy Footing: your next Frost Arrow within 8 sec costs no Energy.
- Changed: Shatter Shot deals 280% weapon damage (was 140%).
- Changed: Rime Slash is now Glacier Wall's filler: no cooldown (was 5 sec), 60% weapon damage (was 100%), generates 10 Fury (was 20).
- Changed: Meltwater costs 1 mana (was 2).

## Lightning

- Changed: Charged Edge deals 270% weapon damage (was 120%).
- Changed: Stormbreak is now Lightning Rod's builder and filler: no cooldown (was 6 sec), generates 15 Energy (was 25).

## Arcane

- Changed: Unravel deals 18% more damage.
- Changed: Arcane Strike deals 20% less damage.
- Changed: Double Up is now the filler: no cooldown (was 5 sec), 45% weapon damage with both weapons (was 100%).
- Changed: Swift Cut deals 80% weapon damage (was 100%).

## Shadow

- Changed: Sic deals 140% weapon damage (was 100%).
- Changed: Hoist, Patch Up and Tug heal 25% more.
- Changed: Patch Up costs 1 mana (was 2).

## Nature

- Changed: Thornshot deals 15% less damage.
- Changed: Mossback deals about 17% less damage: its base damage and the damage added for each mulch patch are both lower.
- Changed: Adder Arrow's poison deals 46% less damage, Asp Arrow's 46% less and Krait Arrow's 44% less.
- Changed: during Venom Flow each poison tick gives 2.5 Venom (was 3).
- Changed: Venom Burst deals 5% more for each different poison on the target (was 20%).
- Changed: Dewfall, Fawn and Owl heal 27% less; Rootguard's shield and Heartwood Elk's heal are 23% weaker.
- Changed: Dewfall costs 1 mana (was 2).

## Holy

- Changed: Glimmer Shot deals 180% weapon damage (was 100%).
- Changed: Refrain costs 1 mana (was 2).

## Systems & Interface

### Downgate Fort
- Changed: every room now has its own shape and tells its own story:
  - The Gatehouse is a narrow passage past the smashed outer gate.
  - The Courtyard holds the warband's camp around a campfire.
  - The Barracks is a long bunk hall.
  - The Archive is three aisles between shelf walls.
  - The Reading Hall has two shelf islands to take cover behind.
  - The North Wall is a wall-walk lined with battlements.
  - The Keep stands on four pillars around Skrag's throne and his crude book.
- Changed: enemy packs are staged: goblins sit around the campfire, a line drills in front of the Barracks Sergeant, the gate guards face the stairs, Fallen Scribes gather at their desks and Goblin Looters wander the Archive aisles.
- New: alarm bells in the Archive and the Siege Yard (four in total).
- Changed: holding the Siege Yard takes 45 sec (was 25 sec).
- Changed: the Scriptorium's Page Thieves are now Goblin Looters.

### 5 Player difficulty
- Changed: trash packs have 48x health (was 3x), so a big pack lasts about 30 sec: long enough to build and spend your resource and use your cooldowns. Enemies that join a fight have 16x health: boss summons, alarm reinforcements and defend waves.
- Changed: bosses have 80x health (was 3x) and deal 4x damage (was 3x). A boss fight lasts about 2-3 minutes.
- New: Berserk. Every Fort boss has a hard timer: Captain Brask and Siegemaster Gorrik 2:40, Nib the Page Thief 3:15, Skrag the False Binder 3:50. A warning comes 10 sec before; then the boss deals 3x damage and attacks 50% faster. Leaving combat resets the timer.
- New: the Boss Timer at the top of the screen during a 5 Player boss fight. It shows the boss's name and the time left before Berserk, turns red for the last 10 sec, then reads "BERSERK".

### Bosses
- Changed: Captain Brask calls 3 shieldbearers at 66% (was 2) and 4 at 33% (was 3).
- Changed: Boulder and Torn Pages now need 4 players in them on 5 Player (everyone alive, once fewer than 4 are). Their damage is split between everyone inside; with fewer in it they are lethal.
- Changed: Scorch Marks marks 3 players (was 2).
- Changed: Nib's Page Flare is now Flash Fire, and Skrag's Page Storm is now Paper Storm. Skrag's 66% phase is now Call the Warband.

### Enemies
- New: Defenders channel Shield Up in combat while their shield blocks from the front. An interrupt or a stun knocks the shield down for 5 sec.

### Modifiers
- Changed: dungeon modifiers are switched off for now. They will return after a rework.

### Combat
- Changed: damage over time effects read your power, critical strike chance, buffs and Haste on every tick, so a buff gained mid-effect counts from its next tick.
- Changed: damage meter lines name their source in brackets: a talent ("Splitting Arrow (Talent)"), a rune, an item or the Wild Page.
- Changed: /testkit gives a spec without an interrupt or a stun one borrowed from another book's Utility.

### Trackers
- Changed: every spec display is now a Tracker, given once and then yours to edit, move, delete or export: Venom, the Wheel, the Chain, the Sharpshooter's shots, Verses, Ice Shards, Bruise, Incense, Heat, Flow, Glaze, Ice Layers, Sap, Reflections, Traces and Slag. To add one again, pick "Spec: ..." from the editor's New list. Each one shows while its abilities are on your bars.
- Removed: the Spec Bars section in UI Options (the displays are Trackers now).
- New: ring and pip displays. A pip display has one pip per point.
- New: each tracker has two texts, each with its own colour, and they can show another trigger's value.
- New: "Show while missing" keeps a tracker on screen, dimmed, while its triggers are off.
- New: "On click" runs a spec action. Clicking the held weapon on the Wheel tracker turns the Wheel out of combat.
- New: conditions can check any one trigger, and set either text or its colour.
- New: "On my bars" shows a tracker only while chosen abilities are on your action bars.
- New: groups have a grow direction, alignment, spacing and sort order; copying a group copies its trackers.
