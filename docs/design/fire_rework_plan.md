# Steady Flame rework: the Fury caster, plus the first choice talent

## Context
Steady Flame's "avoid crits" identity is spread over seven unrelated rules (Vent Flames, Tempered Flame, Cool Head, Slow Fuse, Smoldering Focus, Afterburn, Volatile Fuse), and Firebolt is 56% of its damage. The user wants one clear rule where you avoid crits but still want crit chance, built on **Fury**: the game's first Fury caster. They also asked for the game's first **choice talent** (two options in one slot, WoW-style), used for Ember Volley, and for Dull Mind to keep its Spell Power while also working well with Fire. Slow Fuse and Rekindle go.

## Design (numbers are first guesses; balance.gd holds them, and the balance sim tunes them)

### Fury for Steady Flame
- Steady Flame spells cost **no mana**. They build or spend Fury, the existing 100-point bar (the HUD shows it on its own once a Fury ability is on the bar).
- **Building:** a Fire spell hit of yours that does NOT crit gives `FIRE_FURY_BASE (8) + your crit chance x FIRE_FURY_PER_CRIT (1.0)` Fury. Once per cast, however many enemies it hits. Ticks and procs don't count, and nor do spells that cost Fury. The crit chance used is your sheet chance before the spell's own changes (Tempered Flame, Cool Head, the Ember Volley choice), so those never shrink the Fury you gain.
- **Venting:** a Fire spell crit of yours vents `FIRE_FURY_VENT_PCT (50%)` of your Fury. The crit still deals full damage. Vent Flames' own sure crit doesn't vent, since it spends everything anyway.
- So more crit chance means more Fury per non-crit, but more crits that vent it. The best spot sits somewhere under 50%.
- **The caster twist:** Fury doesn't decay while you are casting or channeling a spell. Standing idle in combat loses it at the normal 5 a second.
- Every ability: real numbers and Fury costs in the tooltip, plus an orange **Fury** keyword with a Shift note explaining building and venting.

### Abilities (12 → 10)
| Ability | Change |
|---|---|
| Firebolt | Free. The main builder (2.2 s cast). |
| Ember Volley | Free builder. Each ember rolls crit on its own; each non-crit ember gives a third as much Fury (`FIRE_FURY_EMBER_MULT`), and each crit ember vents. |
| Blaze (immolate) | Free (it no longer costs mana: the Forge Heat melee casts it too). It deals no damage when it lands, so it builds nothing. |
| Vent Flames | **Spends all Fury** (needs at least 20) and deals +1% damage per Fury spent (`VENT_FURY_PCT`). Always crits. Its old bonus from crit chance goes. Cooldown stays 10 s. |
| Kiln Blast | Costs 40 Fury, can't crit, 3.5 s cast. Keeps its bonus on a Blazed target. The non-crit spender, opposite Vent Flames. |
| Stoke | 20 Fury (was 2 mana). |
| Flame Nova | 30 Fury (was 4 mana). |
| Wall of Fire | 30 Fury (was 4 mana). |
| Crucible | 20 Fury (was 3 mana); moving it stays free. |
| Cool Head | Unchanged. It now also means 15 s of Fury with no venting, then Concentrated Fire makes the Kiln Blasts instant. |
| **Removed** | Slow Fuse and Rekindle: ability data, skill cards, Abilities.ALL / SPECS / CATEGORY_OF / icon entries, balance entries, fire_caster.gd code (fuses, `_rekindle`, `_flashover`), docs and tests. |

The Utility Fire spells (Furnace Breath, Cinder Step, Cooling Slag, Bellows, Heat Sink, Cinderwing) keep their mana costs. Their non-crit hits still build Fury (they are Fire spells).

### Talents (bump `Talents.TREE_VERSION` 1 → 2; every player's talent points are refunded)
- **Removed:** Volatile Fuse (r5c5) and Flashover (r6c5), along with their links (`fire_fuse_crit→fire_flashover`, `fire_long_burn→fire_flashover`, `fire_flashover→fire_stoked_kiln`).
- **New choice talent, r5c5 (Ember Volley):** one slot holding two talents, and points go into only one of them. Both require Ember Volley.
  - **Damped Embers** (3): your Ember Volley's embers have 10 / 20 / 30% less critical strike chance.
  - **Wild Embers** (3): your Ember Volley's embers have 10 / 20 / 30% more critical strike chance.
- **New, r6c5: Blowback** (3): when a crit vents your Fury, 20 / 35 / 50% of the Fury vented burns that target as Fire damage over time (`BLOWBACK_*`; its own damage-meter line, its own icon).
- **Smoldering Focus** (r10c2, 5 ranks) reworked: your Fire spells deal 0.02 / 0.04 / 0.06 / 0.08 / 0.1% more damage per Fury you hold (+10% at 100 Fury at max rank). Name and icon kept.
- **Banked Coals** (r10c4, 2 ranks) reworked: a crit vents 25 / 50% less of your Fury (vents 37.5% / 25% instead of 50%).
- **Banked Mana** (r1c5, 2 ranks) becomes **Stoked Breath**: your Fire spells that fail to crit give 10 / 20% more Fury. It gets a new icon.
- **Unchanged:** Tempered Flame (it now pairs well: Firebolt crits less but still builds Fury from your full crit chance), Pressure Valve, Cool Under Fire, Scattered Embers, Long Burn, Deep Crucible, Stoked Kiln, Afterburn, and every non-caster Fire talent.

### Runes
- **Dull Mind:** keeps its crit cap and the Spell Power. Adds: "Your Fire spells gain Fury as if your critical strike chance weren't capped."
- **Hair Trigger:** still 2 charges, but each Vent Flames spends only half your Fury (and scales on what it spent).
- **New Epic rune, Rune of the Sealed Kiln:** your crits no longer vent Fury, but you gain 30% less of it.
- Level Head, Stormfire, Frostfire Bolt and Fire Menace are unchanged. Frostfire Bolt counts as Firebolt, so it builds Fury.
- Delete the stale `data/runes/smoldering_focus.tres` (not registered in runes.gd).

## Implementation

### Fury caster: new component `scripts/player/fire_fury.gd` (FireFuryKit, added to `scripts/player/kits.txt`)
- `fury_gain(crit_pct, ember, stoked_pct, sealed) -> float` and `vented(fury, banked_pct, sealed) -> float`: pure static maths, so the tests can check them.
- `_fury_on_hit(info, tags)`: called from `FireRunesKit._on_damage_dealt_fire` (scripts/player/fire_runes.gd), the hook that already sees every Fire hit. It uses the same once-per-cast key as `_pressure_valve` (`"<id>@<frame>"`; per ember for Ember Volley through `_volley_serial`). It gains or vents through `player._gain("fury", ...)` and calls Blowback's burn on a vent.
- The base crit chance: at the top of `Player.adjust_crit` (scripts/player.gd ~3776), store the incoming `chance` on the hit (`info.set_meta("fury_crit", ...)`). With Dull Mind, use the uncapped value: `Stats.crit_chance(tags, _raw_stat)` resolved without the cap.
- Vent Flames spending all: in `_pay` / `can_afford` (player.gd ~1232, ~1335), add a Fire-specific "spends all Fury" case modelled on `Abilities.SPENDS_ALL` (energy). The amount spent is stored for the hit's damage bonus (`info.add_bonus(..., "Vent Flames")`, as `fire_crit_rules` does now). Hair Trigger halves it.
- No decay while casting: `_tick_resources` (player.gd ~1373) skips the Fury decay while `casting` (channels included).
- Kiln Blast never crits: add it to the `adjust_crit` never-crit list next to Stoke.
- Smoldering Focus: a damage modifier in the existing Fire talent hook (`Player._on_damage_modify`), with the old stack code in fire_runes.gd removed. Banked Coals' `stacks_kept_on_use` (fire_caster.gd ~368) changes to Afterburn only, or goes if it no longer applies.
- Ember Volley choice: in `adjust_crit`, add or subtract `player._talent("fire_damped_embers")` / `("fire_wild_embers")` for `embervolley` hits (not ticks).
- Data: change `resource_type`/`resource_cost` in `data/abilities/*.tres` and in `balance.gd`'s ability table (~1334-1354); tooltips through the `{...}` fill (`{fury_cost}`, `{b:...}`).

### Choice talents (new, generic)
- Data (`scripts/talents.gd`): a slot entry can be `"r5c5": {"choice": [[name, ranks, desc, extra], [name, ranks, desc, extra]]}`. `db()` makes one entry per option, with ids `fire_r5c5a` / `fire_r5c5b`, the same tier and col, and `"choice_slot": "fire_r5c5"`. It also makes the slot entry itself (`"choice_of": [a, b]`, no points). `in_row`/`in_tree` return the slot id (so trees, layouts, tests and links keep working per slot); a new `Talents.options_of(slot)` returns the two. Add `is_choice(id)` and `sibling_of(id)`.
- Rules (`scripts/player_data.gd`): `can_invest(option)` refuses while the sibling has points ("Remove your points from X first"). Investing in the slot id itself is refused. `talent_rank(slot)` returns the rank of whichever option is taken (the row status, links and `talents_valid` count per option id; tier comes from the entry). `validate_talents` drops a profile holding both options.
- UI (`scripts/menu/talent_tree.gd`): the slot button draws both icons split down the middle (or only the chosen one once it has points) and shows `x/3`. Hovering it opens a small popup above the slot with the two option buttons: icon, tooltip, left click invests, right click refunds. The popup closes when the mouse leaves both. `scripts/ui/talent_tree_view.gd` (the other tree view), `book_search` hover keys and `macro_window` (it iterates `Talents.db()`) get checked so slot/option ids don't break them.
- Icons (`scripts/talent_icons.gd`): new icons for Damped Embers, Wild Embers, Blowback and Stoked Breath, each unique.

### Other files
- `scripts/balance.gd`: new constants `FIRE_FURY_BASE`, `FIRE_FURY_PER_CRIT`, `FIRE_FURY_VENT_PCT`, `FIRE_FURY_EMBER_MULT`, `VENT_FURY_MIN`, `VENT_FURY_PCT`, `BLOWBACK_TIME`/`TICK`, `SEALED_KILN_PCT`. Remove the Slow Fuse and Rekindle constants. Remove `VENT_FLAMES_CRIT_DAMAGE`, or keep it if Vent Flames still uses it.
- `scripts/runes.gd` + `data/runes/sealed_kiln.tres`; update the descriptions of `dull_mind.tres` and `hair_trigger.tres`.
- `tools/balance_sim.gd` / `balance_sim_specs.gd`: model Steady Flame's Fury (gain on a non-crit by the crit chance, expected venting, spenders); then rerun the sim to regenerate `docs/BALANCE_REPORT.md`.
- Docs: rewrite the Caster, Talents and Runes sections of `docs/design/fire.md`; add the choice-talent rule to `docs/design/systems.md`; update `docs/INTERACTIONS.md` if it lists Slow Fuse or Rekindle. Write patch notes with the descent-patch-notes skill.

## Tests
- Update `tests/test_fire_kit.gd`, `test_fire_talents.gd`, `test_fire_additions.gd`, `test_tooltips.gd` (Slow Fuse, Rekindle, Volatile Fuse, Flashover and Smoldering Focus references; row counts).
- New `tests/test_fire_fury.gd`:
  - The gain and vent maths, Banked Coals, Sealed Kiln and Stoked Breath.
  - Once-per-cast gain; per ember for Ember Volley.
  - A Vent Flames sure crit doesn't vent.
  - The Vent Flames spend-all bonus, and the half spend with Hair Trigger.
  - No decay while casting.
  - Dull Mind gains Fury from the uncapped crit chance and keeps its Spell Power.
  - Kiln Blast never crits.
  - The Damped/Wild Embers crit change applies to embers only.
- New choice-talent tests (in `tests/test_talent_choice.gd`):
  - Both options can't hold points at once.
  - Refunding one frees the other.
  - The slot counts toward row unlocks.
  - `validate_talents` clears a profile holding both.
  - Tooltips fill for both options.
- Run `tools/test.sh` (the full suite) and check for parse errors. Rerun the balance sim.

## Order
1. Choice-talent system and its tests.
2. Fury maths in FireFuryKit, the hooks, the ability cost changes, and removing Slow Fuse and Rekindle.
3. The talent changes, `TREE_VERSION` bump, and runes.
4. Balance sim, tuning, docs and patch notes.
5. Tests green, then commit and push to `ccr-5ea18bda-0iu204`.
