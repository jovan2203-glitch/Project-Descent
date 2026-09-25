# Combat interactions: where everything lives

Goal: spells, abilities, damage types, resources, buffs, debuffs and runes all
talk to each other through a few shared hooks, and every name comes from one place.

## 1. Names
| What | File | Examples |
|---|---|---|
| Damage types, tags | `scripts/core/combat_keys.gd` (`CK`) | `CK.FIRE`, `CK.TAG_SPELL`, `CK.TAG_ABILITY` |
| Stats, conversions, SP/AP scaling | `scripts/core/stats.gd` (`Stats`) | `Stats.INTELLECT`, `Stats.HASTE`, `Stats.resolve()` |

Styles: damage types lowercase (`fire`), tags Capitalized (`Spell`), stats snake_case (`spell_power`),
percent stat modifiers use a `%` suffix (`{"intellect%": 1}` = +1% Intellect).

## 2. Spells vs abilities
Every player action carries exactly one kind tag:
- **Spell** – cast by mages. "Fire spell" = Spell tag + fire damage (Fireball, Flame Nova).
- **Ability** – warriors, rangers, rogues (Searing Strike is a fire *ability*, not a fire spell).
- **AutoAttack** – weapon swings/shots, scale like abilities.

## 3. Stats (`stats.gd`)
Intellect, Agility, Strength, Constitution, Armor, Haste, Critical Strike, Spell Critical Strike,
Spell Power, Attack Power (+ Max Health, Max Mana, Move Speed).
- Primary stats (`DERIVED`):
  - Intellect → +1 Max Mana and +0.5% Spell Critical Strike (spells only) per point
  - Agility → +0.5 Attack Power and +0.5% Critical Strike (everything) per point
  - Strength → +1 Attack Power per point
  - Constitution → +1 Max Health per point
- Spell Power comes from gear, levels and buffs (not from a primary stat).
- Spells add 60% SP + 20% AP to their damage/healing, abilities 20% SP + 60% AP (`POWER`).
- Spells crit with Critical Strike + Spell Critical Strike; everything else with Critical Strike.
- Haste: faster casts, channels, auto-attacks and DoT ticks.
- DoTs crit and are hasted unless the effect says otherwise (`dot_can_crit`, `dot_hasted`), and get `DOT_POWER_SHARE` of the power bonus of the spell/ability that applied them.
- Old `damage` stat (old saves/gear) counts as that much SP and AP.

## 4. Registries
| What | Script | Data |
|---|---|---|
| Abilities | `scripts/abilities.gd` | `data/abilities/` |
| Status effects | `scripts/core/effects.gd` (`Effects.apply(target, id, source)`) | `data/effects/` (auto-found by file name) |
| Runes | `scripts/runes.gd` (`Runes.get_resource(id)`, limits, rarity) | `data/runes/` (add id to `PATHS` + `ALL`) |

## 5. Damage pipeline (`CombatSystem.deal`)
1. Crit roll (first, so crit-only modifiers can see it)
2. + Spell / Attack Power bonus
3. % modifiers: attacker's buffs, target's debuffs, `SignalBus.damage_modify` listeners
4. x modifiers, crit x2, armor block, resistance, random rounding
5. HP, on-hit effects, threat, `SignalBus.damage_dealt`

## 6. Runes
Rarity decides how build-defining a rune is, and the equip limits per character:
| Rarity | Role | Limit |
|---|---|---|
| Legendary | build-defining | 1 legendary in total |
| Epic | strong, build diversity | 4 epics, each a different one |
| Rare | fine-tune / slightly alter abilities | 3 of the same (or `max_equipped`) |
| Common | small tweaks | 3 of the same (or `max_equipped`) |

RuneData: triggers (hit / cast / kill / damage taken / low health / periodic), filters
(`required_tags`, `required_abilities`, `required_damage_types`, `require_crit`, `require_non_crit`,
`include_dots`, `include_procs`), effects (stat buff, free cast, bonus damage, heal,
**apply status** to self / target / whole party).

## 7. Buffs vs debuffs
A debuff that changes damage taken (`modifies_incoming`) helps **every** ally hitting that target,
so keep them rare and hard to apply. Prefer buffs on the attacker.

## Examples
- **Rune of Smoldering Focus** (Legendary): each non-crit fire spell hit adds a stack; the next fire spell crit spends them for +(crit chance x 0.6)% per stack (crit chance of that spell, so Spell Critical Strike counts).
- **Rune of Stormfire** (Epic): lightning damage → next fire spell +20% per stack (5 stacks, 10 s).
- **Rune of Frostbound Insight** (Rare, max 1): casting Frost Bolt gives the party +1% Intellect for 15 s, 3 stacks (`status_target = PARTY`).

Debug: `/rune <id> Main Hand`, `/effect <id>`.
