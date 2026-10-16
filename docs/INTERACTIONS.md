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
4. x modifiers, crit x2, dodge / parry / block, then Armor's reduction and the school's resistance together (`Stats.mitigation`), random rounding
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
- **Vent Flames** (Fire spell, instant, 10 s cooldown): 2 Frost Bolts of Fire damage, always crits, +(crit chance x 0.5)% damage. A guaranteed Fire spell crit, so it spends Smoldering Focus.
- **Kiln Blast** (Fire spell, 3.5 s cast, 3 s cooldown): 3 Frost Bolts, +20% on a target with your Blaze. The spell to make instant with Concentrated Fire (the cooldown stops it being chained).
- **Slow Fuse** (Fire spell, 2 s cast): a charge on the target that explodes after 5 s for 1.5 Frost Bolts, +0.25 for each of your direct hits on that target that didn't crit (max 20). Volatile Fuse (Fire talent, row 5, 3 ranks): Fire crits grow it 50 / 70 / 100% of the time and non-crits 50 / 70 / 100% less often.
- **Rekindle** (Fire spell, 2 s cast): restarts every Blaze and Burning of yours on the target and enemies within 10 m of it.
- **Wall of Fire** (Fire spell, 1.5 s cast, 20 s cooldown): an 8 m x 2 m wall for 8 s, across your target or 5 m in front of you; 0.25 Fire damage every 0.5 s to enemies in it. Its damage is periodic, so it doesn't build Smoldering Focus / Afterburn / Concentrated Fire.
- **Rune of the Level Head** (Epic): Concentrated Fire (from Cool Head) makes spells of every school instant, not only Fire.
- **Blaze** (Fire spell, 1.5 s cast): 0.2 Fire damage per second for 12 s, nothing up front. Cast on a target that already has your Blaze, it also jumps to 2 other enemies within 8 m (ones without it first). It has a cast time, so Concentrated Fire makes it instant.
- **Rune of the Dull Edge** (Epic): crit chance capped at 10%; every 1% over becomes 0.2 flat units of Spell Power. Makes each Afterburn stack worth at least (100 - 10) x its factor.
- **Rune of the Hair Trigger** (Epic): Vent Flames has 2 charges.
- **Stoke** (Fire spell, instant, 20 s cooldown): needs your Burning on the target; ends it and deals 1 Frost Bolt + everything the Burning had left as one hit that never crits (so it always builds Smoldering Focus and spends Afterburn).
- **Ember Volley** (Fire spell, 3 s channel, 12 s cooldown): 6 embers of 0.35, each with its own crit roll, so it builds Smoldering Focus / Afterburn fast. One Concentrated Fire stack per channel; with Concentrated Fire active it is instant (all 6 embers in a quick burst, one stack). Scattered Embers (Fire talent, row 5, 2 ranks): each ember also hits 1 / 2 extra enemies within 8 m of the target.
- **Banked Coals** (Fire talent, bottom row middle, 2 ranks): spent Smoldering Focus / Afterburn stacks keep 25 / 50% (rounded down).
- **Furnace Breath** (Fire spell, instant, 15 s cooldown, off the GCD): a 6 m, 90-degree cone that deals 1 Frost Bolt of Fire damage and interrupts every enemy in it (3 s lockout). Fire's interrupt.
- **Slag Skin** (Fire spell, instant, 25 s cooldown, 10 s): +3 flat units of Armor; every enemy that attacks you takes 0.3 Fire damage (3x threat, once per 0.5 s each). The burns are Fire spell proc hits, so they feed Smoldering Focus / Afterburn.
- **Cool Head** (Fire spell, instant, 2 min cooldown, 15 s): Fire spells and abilities can't crit; each one that deals damage gives a stack of **Concentrated Fire**. When it ends, the stacks last 5 s and each makes one Fire spell / ability with a cast time instant. No crits = fast Smoldering Focus stacks.
- **Tempered Flame** (Fire talent, top row, 2 ranks): Firebolt gains 40 / 60% less crit chance but deals +(crit chance x 0.1 / 0.2)% damage. Fewer Firebolt crits = more Smoldering Focus stacks.
- **Afterburn** (Fire talent, bottom row right, 5 ranks): its mirror image. Each fire spell crit adds a stack; the next fire spell hit that does NOT crit spends them for +((100 - crit chance) x 0.1 per rank)% per stack. Vent Flames (always crits) is a reliable stack for low-crit builds.
- **Smoldering Focus** (Fire talent, bottom row left, 5 ranks; used to be a Legendary rune): each non-crit fire spell hit adds a stack; the next fire spell crit spends them for +(crit chance x 0.1 per rank, so x 0.5 at rank 5)% per stack (crit chance of that spell, so Spell Critical Strike counts).
- **Rune of Stormfire** (Epic): lightning damage → next fire spell +20% per stack (5 stacks, 10 s).
- **Rune of Frostbound Insight** (Rare, max 1): casting Frost Bolt gives the party +1% Intellect for 15 s, 3 stacks (`status_target = PARTY`).

## Fire: the rest of the caster kit
- **Crucible** (ground-targeted like Whiteout, 1.5 s cast, no cooldown): a circle for `CRUCIBLE_TIME`; enemies in it take `CRUCIBLE_DOT_PCT`% more periodic Fire damage (`is_dot` + fire: Burning, Blaze, Wall of Fire, Cinder Step's line, Clinker). While yours stands, casting it again is instant and free and moves it, keeping the time left (`CRUCIBLE_MOVE_REFRESHES` to restart it instead). Party members see your Crucible (`Net` "crucible" fx), but it only boosts its owner's burns (own only).
- **Cinder Step**: a dash (Phase Step's wall rule) that leaves a strip of fire, and a buff: the next Fire spell with a cast time (not a channel) can be finished while moving. Used up when that cast finishes; a cancelled cast keeps it.
- **Heat Sink**: `HEAT_SINK_PCT`% of damage taken is stored for `HEAT_SINK_TIME`; when the buff ends it bursts for the ability's damage, up to `1 + HEAT_SINK_BONUS` times that at `HEAT_SINK_FULL_AT`% of max health stored. No burst if you die first.
- Talents: **Pressure Valve** (a Fire spell that fails to crit cuts Vent Flames' cooldown, once per use, not procs), **Flashover** (Slow Fuse exploding on a target with your Blaze: chance per nearby enemy to catch it), **Cool Under Fire** (less damage taken during Cool Head).

## Fire tank: Slag
- **Slag Skin** is upkeep: 15 s, 13 s cooldown, free. It still burns attackers. While it is up, each melee hit of yours that does not crit adds a stack of **Slag** (armor per stack, `SLAG_MAX_STACKS`; once per use, however many enemies it hit; not procs). A melee crit shatters every stack: Fire damage per stack around you (a proc hit). Slag always runs out together with Slag Skin.
- **Brand** (builds rage, 3x threat): the branded enemy deals `BRAND_PCT`% less damage to the one who branded it (per caster).
- **Cinder Guard** (spends rage, needs a shield): +`CINDER_GUARD_BLOCK`% block (a `block_chance` buff on top of the Block stat, same cap; Armor does not block). Each block burns the attacker and adds `CINDER_GUARD_EXTEND` s to Slag Skin, never above its full time.
- **Anvil** (needs a shield): Fire damage around you, 4x threat, never crits, so it always adds Slag.
- Talents: **Thick Slag** (armor per stack), **Clinker** (shattered Slag leaves a burning patch: a share of the shatter's damage per second), **Hot Iron** (retaliation for a BLOCKED attack burns harder: Slag Skin and Cinder Guard).

## Rune spells (the "Rune Spells" book)
- A rune can teach a spell: `Runes.TEACHES` (rune id -> ability id). The spell is known while the rune is on equipped gear (`PlayerData.has_ability` / `rune_spells`), is never drafted and has no Skill Card. Its category is `Categories.RUNE` (not in `Categories.ORDER`: no talent tree).
- **Frostfire Bolt** (Rune of Frostfire Bolt, Rare, 1 per character): Frost Bolt's numbers (`Balance.ABILITY_SAME_AS`), dealt as two hits that land together, half Frost and half Fire (`Player.frostfire_halves`). No Chilled or Burning of its own.
  - Each half is a hit of its own school: its own crit roll and its school's talents, runes and procs (Permafrost on the Frost half, Cool Head / Smoldering Focus / Afterburn on the Fire half).
  - Both halves carry the spell's id, which counts as a Frost Bolt AND a Firebolt (`Abilities.COUNTS_AS`, `Abilities.is_a`): Quickened Frost, Frozen Instinct, Tempered Flame and runes that name Frost Bolt (`RuneData.applies_to_ability`) all apply. New code that names one of those spells should use `Abilities.is_a(id, "frostbolt")`, not `==`.
  - It is still ONE hit for things that count hits: the second half has `DamageInfo.part == 2`, sends no `player_hit`, and only feeds runes that ask for a school (`RuneData.is_school_specific`). Slow Fuse counts its Fire half.

## Multiplayer rules (the game is co-op first)
- An enemy's status effects live on the **host** and are mirrored to everyone.
- A hit is rolled on the **caster's machine** (their stats, talents, runes) and reported to the host.
- Damage over time is the same: its ticks and its burst are dealt on the **caster's machine** and reported like hits. The host and other players only show the effect. So anything a talent or rune does to a DoT (crit rules, bonuses, duration) works for every party member, not just the host.
- A party member's on-hit effects show up on their own screen at once; the host is told the duration / slow strength their talents gave it.
- Changing an enemy's effect from a party member goes through `Net`: `remove_effect` (Stoke, Slow Fuse going off), `set_effect_stacks` (Slow Fuse growing). Effects without damage can be put on an enemy with `Player._apply_effect_hit` (Rekindle, Slow Fuse).
- Ground effects (Whiteout, Wall of Fire) run on the caster's machine; others get a visual-only copy through `Net.send_fx`.
- Rune and item effects that put a status on an enemy go through `CombatSystem.apply_effect` (never `Status.apply` on the enemy directly: on a party member's machine that only changes their own copy).
- An enemy's hit on a party member is rolled on that member's machine, with the damage unit the **host** sends along (Frenzy, a dead Volatile elite's blast).
- Shields on enemies (Shielded elites, Rime Shell) live on the host; their total is in the enemy snapshot, so every machine shows the shield bar and "(N absorbed)".
- An enemy running home (Evade) can't be hit or given effects on any machine.

## Arcane tank: Reflections
A dodge tank with a melee weapon in each hand (`AbilityData.requires_dual_wield`, `PlayerData.has_dual_wield()`), on cooldowns alone. Rules in `player.gd` ("Arcane tank"), numbers in `balance.gd` (`REFLECTION_*`).
- Dual wield: a one-handed melee weapon also fits the Off Hand (`PlayerData.fits_slot`, `Items.is_one_handed_melee`). The Off Hand weapon gives its stats. Double Up and Missed Beat strike with both weapons: one hit of (Main Hand damage + Off Hand damage) x the ability's multiplier (`Player.dual_hit`, `Abilities.dual_wield_damage`, `Abilities.offhand_weapon`), so on-hit effects trigger once. Every other ability and auto-attacks use the Main Hand weapon's damage.
- Reflections are a stacking buff (`reflection`, up to `REFLECTION_MAX`): Dodge per stack, and the Dodge cap is higher (`Player.dodge_cap()`, which `CombatSystem.compute_damage` takes like `parry_cap()`).
- A dodge shatters one (`_reflection_kit_hit_taken` -> `_shatter_reflection`): a proc hit named `reflection_shatter` (its own meter line), time off every cooldown in the Arcane book (`Player.shatter_cuts`; never interrupts), and the window for Missed Beat.
- Stand-In: `CombatSystem.deal` asks the target `stand_in_for(info)` for a direct hit that got through. If true the hit is `DamageInfo.stood_in`: it counts as avoided (`avoid_kind()` = "reflection") and a Reflection shatters.
- The picture is `scripts/reflections.gd`: glass copies of the body's `Model` (shader `shaders/reflection.gdshader`) to the left, right, front and back. The count goes to the party as the "reflections" fx and is shown on the puppet.
- Decoy (`scripts/decoy.gd`): a node in the group `decoys`. `enemy.distract(decoy, time, owner)` makes an enemy attack it; blows on it land on nothing (`enemy._hits_decoy`). Enemies live on the host, so a party member's Decoy is made real there (`Net.decoy` / `_sup_decoy`); everyone else has a picture. Its burst is dealt by its owner's machine.
- Talents (`player.gd`, "The Arcane tank's talents"; down both edges of the Arcane tree): Sharp Edges (`_on_damage_modify`, `shatter_radius()`), Clockwork (`shatter_cut`), Spare Copy (`dodge_uses_reflection`), Second Self (`double_up_reflections`), Wide Rings (`Abilities.RADIUS_TALENTS`, `ripple_makes_reflection`), On the Beat (`_on_damage_modify`, `_use_drafted`), Head Count (`_full_set`, heal id `head_count`), Light Feet (`PlayerData._compute_total_stats`), Empty Room and Bent Light (`_reflection_talents_incoming`: Bent Light counts every damage type except `physical`), Understudy (`_reflection_kit_hit_taken`), Loud Exit (`_trade_places` -> `_shatter_burst` once per Reflection), Good Likeness (`decoy_time`, `decoy_needs_reflection()`).
- Rune of the Two-Way Mirror (Rare): `Player.mirror_echoes(..., two_way)` lets Mirror Sigil repeat `reflection_shatter` hits at `mirror_pct()`.
- Tooltip placeholders the talents feed: `{ripple_enemies}`, `{decoy_time}`, and `{radius}` / `{hit}` of Ripple and Missed Beat.

## Arcane melee: Traces
A damage dealer with a melee weapon in each hand, on cooldowns alone. Rules in `player.gd` ("Arcane melee"), numbers in `balance.gd` (`TRACE_*`, `ENCORE_PCT`, `LATE_CUT_DELAY`, `DOUBLE_TIME_*`).
- A Trace is a record of the damage one strike dealt: `Player._traces` (oldest first), shown as the stacking buff `trace` (`_sync_traces`). Traces are only kept while Encore is known.
- What leaves one (`Player.leaves_trace`, called from `_on_damage_dealt_arcane` -> `_trace_hit`): a landed hit tagged Arcane + Melee + Ability that is not a proc and not damage over time. So Swift Cut, Deep Cut, Late Cut, Wide Cut, and also Double Up, Missed Beat and Arcane Strike.
- The hits of one use share a Trace (`traces_after`: same ability within `TRACE_MERGE_WINDOW`), keeping the largest: Wide Cut leaves one Trace. Late Cut's second hit is an exact repeat of the first (`_exact_hit`, a proc) and is added to the Trace the first one left (`traces_added`, by the Trace's key).
- Encore (`_encore`) replays each Trace on the target with `_exact_hit` under the id `encore`: no crit, cannot be avoided, a proc, so it leaves no Trace and Mirror Sigil does not repeat it.
- Encore's picture is `scripts/trace_ghost.gd`: one glass copy of the body's `Model` per Trace runs through the target (`TraceGhost.run`). Each Trace's hit is dealt on a timer at `TraceGhost.hit_time()`, when its ghost gets there. The party sees them through the "ghosts" fx (`Net._fx`).
- Double Time: `trace_cap(extra, double)` and `DOUBLE_TIME_TRACES` copies per strike (the copies share a key).
- Talents: Long Memory (`trace_time`), Standing Ovation (`encore_pct`, `trace_cap`), Clean Lines (`_trace_hit`), Second Showing (`encore_uses_traces`), Practiced Hand (`_on_damage_modify`, `practiced_hand_pct`), Heavy Hand (`trace_amount`), Curtain Call and Time Signature (`_encore`), No Loose Ends (`late_cut_delay`; capstone: `_late_cut` -> `_leave_trace`), Full House (`_wide_cut`), Dress Rehearsal (`_start_double_time`). Tooltip placeholders: `{encore_pct}`, `{late_cut_delay}`, `{double_time}`.
- Traces past the limit: `traces_after` adds nothing and pushes nothing out while more than `cap` are held (Double Time ended with more than `trace_cap(.., false)`), so they stay until replayed or run out.
- Encore has no cooldown: it is limited by the Traces it needs and by the global cooldown. Nothing may shorten or reset its cooldown (a test checks no `_cut_cooldown(ENCORE_ID` is left).
- Curtain Call: `curtain_call_pct` gives each replay a labelled bonus. `_exact_hit` takes `bonuses` ([percent, label] rows): an exact hit skips `damage_modify`, but `add_bonus` still multiplies it and the meter splits it out.
- Full House: `_wide_cut` applies the buff `full_house` (`make_full_house_fx`, `FULL_HOUSE_TIME`) when `full_house_ready`. `_encore` removes it and picks up to the talent's number of enemies with `_enemies_near` (`FULL_HOUSE_RADIUS` from the target); each ghost's hit also deals `full_house_amount` to them under the id `full_house` (`Details.HIT_NAMES`).
- Dress Rehearsal's capstone: `_start_double_time` applies the buff `dress_rehearsal` for as long as Double Time lasts. `_encore` removes it; if `double_time` is still up, `encore_uses_traces(..., free)` keeps the Traces. It has `capstone_requires: encore`.
- Arcane bottom row: Silvered (`_shatter_burst`, heal id `silvered`), Running Clock (`_tick_cooldowns` -> `arcane_cooldown_rate`: every Arcane spell and everything in the Arcane book except interrupts; Lapse and Interval Ward stay spells only), Fine Edge (`_on_damage_modify`: hits tagged Arcane + Ability while dual wielding; exact hits such as Encore's replays skip `damage_modify`, so nothing counts twice).

## Shadow melee: the Hounds
A melee damage dealer with two demon dogs, on Rage. Rules in `player.gd` ("Shadow melee: the Hounds"), numbers in `balance.gd` (`HOUND_*`, `ROUSED_*`, `LAID_OPEN_*`, `RUN_DOWN_*`, `GUARD_DOGS_*`, `OFF_THE_CHAIN_*`), the dogs in `scripts/hound.gd`.
- Calling: `_use_drafted` calls `_hounds_on_ability(id)` once an ability is paid for. An ability in `Player.HOUND_CALLERS` (six of the kit and Leeching Strike; not Bring It Down) calls the pair when none are out (`hounds_out()`). They exist while the buff `hounds` is on the player (`make_hounds_fx`, exactly `hound_time()`, which is `HOUND_TIME` plus Long Night: its time is set with `set_remaining`, so Overtime does not stretch it).
- Prey: `_hounds_on_hit` (from `_on_damage_dealt_shadow`, which sees every hit of mine) always sets them on the enemy of my last direct hit (`sets_prey`: any hit that is no proc and no tick, of any book, on any enemy). Of the enemies one cast hits in the same frame, my target is the one they take (`keeps_prey`). `_set_hound_prey` delays each Hound's next bite by `Hound.travel_time`. A dead prey, or one past `HOUND_LEASH`, sends them to heel.
- Their hits (`_hound_hit`): a `DamageInfo` with the player as source, tags `HOUND_TAGS` (Shadow + Ability + Hound, so it scales like an ability and is no Melee swing), `is_proc` and `no_empower`. So they get the player's crit, power and every damage modifier (buffs like Dusk, `damage_modify` talents), heal through Lifesteal and make the player's threat, but runes without `include_procs`, `player_hit` talents, "your next ..." buffs and the Breach (`decay_feed_pct`) ignore them. Ids: `hound_bite`, `hound_lunge`, `hound_drag` (`Details.HIT_NAMES`).
- Bites: `_tick_hounds` (per frame), one timer per Hound, `hound_bite_interval(haste, unchained, faster_pct)` (Lean and Hungry).
- Roused: `_pay` calls `_rouse_hounds()` whenever Rage is spent (`rouses`), for any book's ability. The buff `roused` carries no modifier of its own: `hound_bite_bonuses` adds `ROUSED_PCT` to bites with `DamageInfo.add_bonus`, so the meter shows it as its own line. Open Up's mark works the same way: the per-caster debuff `laid_open` (its on-hit effect) is read with `has_from(LAID_OPEN_FX, self)`.
- Run Them Down: while the buff `run_them_down` is up, a bite that dealt damage is repeated on nearby enemies with `_exact_hit` under the id `runthemdown` (`run_down_amount`).
- Guard Dogs: a buff with `damage_mod_pct` < 0 and `modifies_incoming` (`make_guard_dogs_fx`). The Hounds keep biting.
- Off the Chain: the buff `off_the_chain` speeds bites up, and `hounds_until_unchained` adds its duration to the pair's time.
- Leaving: `_tick_hounds` sees the `hounds` buff gone. `hounds_time_up`: each deals `HOUND_DRAG` to its prey (`_hounds_gone(true)`); cleared early (death, going down: `status.clear()`) they just go.
- The picture (`scripts/hound.gd`, @tool so tests can build one): `Hound.call_pair` makes two, built from primitives on a rig. The owner's machine calls `set_prey`, `bite`, `lunge` and `leave`; it never decides damage. The party gets the "hounds" fx (`Net._fx` -> `Hound.show_for`: time left, prey, lunge; time 0 = gone), re-sent every `HOUND_RETELL` seconds; those Hounds (`auto`) follow the puppet and bite by themselves.
- Enemies cannot target the Hounds: they are not in any group and have no collision.
- Tooltip placeholders used: `{d:HOUND_BITE}`, `{d:HOUND_LUNGE}`, `{d:HOUND_DRAG}` `{chain_time}` (Off the Chain's time with Slipped Leash), `{fx_time}` (Laid Open's with Still Wet) and the `{b:...}` constants. Keywords: `hounds`, `roused`.
- Bring It Down (`bringitdown`): not in `HOUND_CALLERS`. `_drafted_precheck` asks `bring_down_error` (Hounds out, and a prey or a target within the leash). `_bring_it_down` sets them on the target if they are at heel, removes the `hounds` buff and calls `_hounds_gone(true)`: the same Drag Down as when their time is up (`_drag_down`).
- Dash: a picture rule in `hound.gd`. `Hound.dashes(from, to)`: prey more than `DASH_AFTER` seconds' run away (`RUN_SPEED`). `_move` then runs at `DASH_SPEED` until `DASH_STOP` from its spot; `Hound.travel_time` is shorter for it, so the bite `_set_hound_prey` delays comes sooner. A party member's Hounds dash by the same rule.
- A third Hound (Slipped Leash's capstone): `_hound_bite_at` has one timer per Hound out, so everything that loops over it (bites, `_hounds_lunge`, the Drag Down count in `_hounds_gone`) includes it. `_add_third_hound` adds it in `_start_off_the_chain` and in `_call_hounds` while the buff `off_the_chain` is up; `_tick_hounds` calls `_third_hound_gone` when that buff is gone. The picture: `Hound.call_one(..., 2)` (side 0). The party: the "hounds" fx carries `count`.
- Talents that add to their hits go through `hound_hit_bonuses` in `_hound_hit` (Pack Leader on every hit, Pincer on `hound_lunge`, Take It With You on `hound_drag`), each a labelled `add_bonus`. Run Them Down's shares are exact copies of a bite, so they already contain them.
- Talents that make an effect last longer use `Abilities.effect_time_bonus` (ids `roused`, `laid_open`, `off_the_chain`), which `StatusContainer.apply` asks the caster for. Long Night does not: `_call_hounds` sets the pair's time itself (`hound_time`).
- Worked Up's capstone: `_hound_bite` puts the extra crit chance on the `DamageInfo` as meta `HOUND_CRIT_META`; `adjust_crit` adds it for `hound_bite`.
- Out of the Hole: `_hound_bite` calls `_decay_feed` directly with `hole_feed(dealt, pct)`. `decay_feed_pct` still returns 0 for a Hound's hit, so Baited Steel and the Breach's own rules do not count bites twice.
- Take It With You's capstone: `_drag_down` notes the prey in `_drag_watch` for `DRAG_KILL_WINDOW` seconds. `_on_enemy_died_shadow` sets `_hounds_roused_next` when that enemy dies and `enemy.killed_by_me()` (works for a party member too: the host names the killer). `_call_hounds` then Rouses the new pair.
- Feeding Frenzy (open talent): `_on_enemy_died_shadow`, for an enemy in `_first_hit` (every enemy I damaged) or one I killed. A Haste buff through `add_buff`. Thick Blood (open talent): `rage_decay` in `_tick_resources`.
- Still Wet's capstone: `_shadow_talents_modify`, for my direct hits (no proc, no tick) on an enemy with my own `laid_open`. Share the Kill: `_on_hit_extra` (`leech_heal_mult`). Stand Over: a raw heal per bite in `_hound_bite` while `guard_dogs` is up, id `stand_over`. Again: `_use_drafted` erases Both At Once's cooldown (`again_resets`). Fed and Pincer's capstone read `_hound_crit`, set by `_hound_hit`.

## Shadow healer: the Strings
A healer whose resource is a fixed handful of Strings. Rules in `player.gd` ("Shadow healer: the Strings"), numbers in `balance.gd` (`STRING_*`, `LOOSE_STRING_TIME`, `TUG_*`, `KNOT_TIME`, `CUPPED_HANDS_*`, `STILL_STANDING_*`, ...), the demon and the threads in `scripts/puppeteer.gd`.
- State (the healer's machine decides everything): `_strings` (target instance id -> entry `{node, enemy, n, free, until, born, next, fast, knot, cross, loose}`), `_string_order` (one id per String tied, oldest first: Restring takes the last), `_string_last_ally`, `_string_spent` / `_string_recover_at`.
- Charges are worked out, never stored: `string_charges()` = `strings_in_hand(strings_placed(), _string_spent)` = `STRING_MAX` - tied (not the free ones) - used up. So a String that falls (`_strings_fall`: it ran its time; `_string_gone`: its target is dead, gone or past `STRING_LEASH`) is in the hand again in the same frame. Only `_string_use_up` (a String tied to a full ally or to an enemy that has one, Pull Taut) starts the `STRING_RECHARGE` timer, one String after the other. `charges_text` shows the number on the button; `can_afford` refuses String at 0 and Not Finished With You under `NOT_FINISHED_STRINGS`.
- Using them: the 17 instants are `Player.STRING_INSTANTS`: `_drafted_precheck` -> `_string_precheck(id)`, `_use_drafted` -> `_string_use(id, res)`. Patch Up and Hoist are `SUPPORT_CASTS` (cast like Heal; `_start_support_cast` refuses Hoist on someone who is not `on_my_string`; `_release_support` -> `_string_cast_heal`). Targets: `_string_pick(id, foes)` = my friendly target, else (String, Restring) my enemy target, else me.
- String's short global cooldown: `use_ability` starts the normal one and then scales it with `string_gcd` (`STRING_GCD_MULT`).
- Tying: `_tie_string(who, is_enemy, from_hand)`. Ally: `string_placed(n, doubled)` -> [Strings afterwards, free ones added, used up]; the time of all its Strings starts over. Enemy: one String, `STRING_ENEMY_TIME`, then `_cross_strings`.
- Healing: `_tick_strings` (every frame, from `_process`). Each ally entry heals `string_tick_heal(n, loose)` every `string_tick_interval(haste, tugged)` through `_heal_coef` -> `_heal_exact`. `_heal_exact` heals me and friendly dummies with `CombatSystem.heal(..., raw)`; for a party member it shows the number, emits `heal_done` for the meter and sends `Net.support_ally(tgt, self, "heal", ...)`.
- Shared heals: `_on_heal_done_strings` listens to `SignalBus.heal_done`. A heal of mine whose id is an ability (`Abilities.PATHS`) and not in `STRING_NO_SHARE`, on someone `on_my_string`, gives every other ally on a String `string_share(amount)` under the id `string_share`. That id is no ability, so a share is never shared again.
- Crossed Strings: `_cross_strings(enemy_key)` links the enemy's entry with `_string_last_ally`'s (`cross` on both). The ally's machine is told the share (`cross` in the "string" message, kept in `_strung`). There `_on_damage_modify` -> `_crossed_incoming` adds -`STRING_CROSS_PCT` as a labelled bonus, and `_on_hit_taken` -> `_crossed_taken` works out what was spared (`cross_redirect`, the same maths as Heat Sink). My own: `_crossed_damage` at once. A party member's: summed in `_cross_owed` and reported every 0.3 sec as "cross_dmg". The healer deals it with `_exact_hit` under `crossed_strings` (a proc: it feeds no Breach and triggers no "your hit" effects). A friendly dummy: `ally_dummy.gd` asks its `damage_share` meta (`_dummy_crossed`). `_tick_strings` breaks a crossing past `STRING_CROSS_RANGE`.
- The party channel: `Net.support_ally(target, caster, kind, data)` -> `_sup_do` on the target's machine -> `Player.receive_support(kind, from, data)`. Kinds: "heal", "string" (n, t, cross: `_on_string_state` keeps the per-caster buff `on_a_string` and `_strung`), "shield" (Cupped Hands), "hold" (Still Standing), "yank", and "cross_dmg" (from the ally back to the healer). `_show_strings` tells everyone again every `STRINGS_RETELL` seconds and on every change.
- Loose Strings (Cat's Cradle): `loose` = when it runs out. It heals and counts for `on_my_string`, never for `strings_on`, `strings_out` or the charges.
- Double Thread: the buff `double_thread`. `_tie_string` passes `doubled` and counts the second String in `free`.
- Knot: `knot` on one entry at a time, `until` = now + `KNOT_TIME`. `_restring_source` skips it, and a new String never shortens it.
- Wrench: `deal_damage` like any Shadow spell (so it feeds an open Breach), then `_heal_exact` on the crossed ally for what it dealt.
- Still Standing (on the ally's machine): `_receive_hold` opens a window. `take_damage` -> `_still_standing_limit` turns a killing blow into "1 health left" and starts `_held_until` (buff `held_up`), during which nothing takes the last health. `_tick_still_standing` lets go and kills below `STILL_STANDING_HEALTH_PCT` (`still_standing_lives`).
- Behind Its Back: a buff with `damage_mod_pct` < 0, `modifies_incoming` and `mod_affects_dots` (`make_behind_fx`).
- String Up and Tangle: the status effects `strung_up` (a stun) and `tangled` (a root), applied with `_apply_effect_hit`.
- Not Finished With You: `_fallen_ally` (the nearest downed `remote_player`), `Net.revive_ally`, then its Strings go straight into the entry. `STRING_GRACE` keeps a String on someone who is not on their feet yet.
- The picture (`scripts/puppeteer.gd`, @tool so tests can build one): `Puppeteer.hold(scene, whose, [[node, Strings, is enemy], ...])` keeps one demon and one set of threads per target in the owner's meta; an empty list makes everything leave. It never decides anything. The party gets the "strings" fx (`Net._fx`: member ids and enemy ids -> `hold` for the puppet), "strungup" and "tangle".
- Meter: `puppetstring` (String), `string_share` and `crossed_strings` (`Details.HIT_NAMES`); every other heal under its ability's id.
- Tooltip placeholders used: `{heal}`, `{hit}`, `{h:CUPPED_HANDS_SHIELD}`, `{ds:STRING_HEAL}`, `{ds:CUT_STRINGS_HEAL}`, `{slack_mana}`, `{fx_time}`, `{radius}`, `{range}` and the `{b:...}` constants. Keywords: `strings`, `crossed`.
- Own only: every lookup goes through my own entries or `has_from(..., self)`. Two healers' Strings on one ally are two buffs (`per_caster`) and two rows in `_strung`.
- Talents (`talents.gd`, keys `shadow_*`): what each one changes is a static in `player.gd`. Long Thread `string_time_with` (every `now + string_time()`; tooltip number `{string_time}`), Spare Spool `string_recharge`, Taking the Weight `cross_pct_with` / `cross_range_with` (the share goes out in the "string" message, so the ally's machine needs nothing new), Full Harness `full_harness_pct` (sent as `dr` in the same message; `_crossed_incoming` adds it as a labelled bonus; a dummy: `_dummy_crossed`), First Stitch `first_stitch_coef` in `_tie_string` (meter id `first_stitch`), Steady Hands `steady_heal` (`_steady`: String ticks, Pull Taut, First Stitch), Heave `heave_mult` in `_string_cast_heal` and `heave_cast` in `_begin_spell`, Snap Back `snaps_back` in `_pull_taut`, Give and Take `slack_time` in `_slack` (tooltip number `{slack_time}`), Long Drop `_long_drops` / `_tick_long_drops` (a timer set in `_string_up` for as long as the stun lasts for me; a proc under `long_drop`).
- Open talents from the same batch: Many Hands `_others_heal_mult` (in `_heal_coef`, `_heal_someone` and the Heal spell: every heal of mine that is worked out for someone else), Lean On Me `_lean_on_me` from `_on_heal_done_strings` (buff `lean_on_me`, an incoming modifier), Left Hanging in `Abilities.effect_time_bonus` (every effect with `stun` or `root`, so `{fx_time}` in tooltips follows).
- Tests: `tests/test_strings.gd`, `tests/test_shadow_talents.gd`.

## Pacts
One deal for the dungeon, for every character. What each Pact is and changes: `scripts/pacts.gd` (texts, and static functions of (pact id, broken)); numbers: `balance.gd` (`PACT_*`); the choice: `PlayerData.pact` / `pact_book` (saved) and `pact_broken` (not saved; `GameManager` calls `start_pact_run()` when a run starts from the menu, never on the next floor). The player applies it and watches the vow (`player.gd`, "Pacts"). All of it is the local player's own: nothing is sent to the party.
- Which Pact counts: `Player.pact_id()` (worked out once a frame; a party-only Pact is "" without `Net.with_others()`).
- Stats: `_raw_stat` adds `Pacts.stat_mod` (Haste, crit, movement; `max_health%` and `max_mana%` go through `Stats.resolve` like every percent key).
- Damage: `_on_damage_modify` -> `_pact_outgoing` / `_pact_incoming`, a labelled `add_bonus` with the Pact's name, so the meter splits it out.
- Cooldowns: `_tick_cooldowns` multiplies each step by `Pacts.cooldown_rate`. Costs: `resource_cost` x `_pact_cost_mult(resource)`. Resources: `_gain` multiplies what comes in by `Pacts.resource_gain_mult`.
- Healing received: `CombatSystem.heal` asks whoever is healed for `heal_taken_mult(source, ability_id)` (the Fast, and the Shepherd's own heals on themselves). Healing cast: `_pact_heal_mult()` in `Player.heal`, `_others_heal_mult` and `_heal_coef`.
- The Restless: `_tick_pact` -> `_pact_bleed_tick` drains health out of combat, and `_tick_health_regen` stops.
- Vows: `_go_down` / `_die` -> `_pact_on_down`; `take_damage` -> `_pact_on_damage` (after shields); `use_ability` -> `_pact_purist_blocks` (the first press warns) and `SignalBus.cast_finished` -> `_pact_on_ability`; `heal_done` -> `_pact_on_heal`; my hits -> `_pact_acted`; `_tick_pact` for the timers and mana, and every `PACT_POLL` seconds `_pact_watch_party` (a `remote_player` that is no longer alive; an enemy whose `threat_state_for(me)` was 2 and that is now on another player: `_pact_enemy_on_ally`).
- Breaking: `_break_pact(why)` -> `PlayerData.break_pact()`. Every function above takes `broken`, so the bonus turns round from the next frame.
- Shown in game as the buff `pact` (no modifiers of its own, `show_time` off; a debuff once broken). Death clears buffs: `_pact_show` puts it back.
- Menu: `main_menu.gd`, "Pacts": `_shelf_pact_tab` above `_shelf_rune_tab` (`SHELF_TAB_HEIGHT` x 2 + `SHELF_TAB_GAP` = the 60 px the rune tab had, so the books did not move), `_build_pacts_page`, `_pact_card`, `_take_pact` -> `PlayerData.set_pact` (refused outside the menu: `pact_locked`).
- Tests: `tests/test_pacts.gd`; the books' fixed order: `tests/test_books.gd`.

## Open talents (Arcane)
Talents themed to a book that work with every book's abilities. They key off a mechanic (a cooldown, an avoided attack, a self-buff), never off another school. Code: `player.gd`, "Arcane: the open talents".
- Echo: `_echo_talent` (from `_on_damage_dealt_arcane`, which sees every hit I deal). A non-proc, non-DoT hit of a known spell or ability may be repeated with `_exact_hit` under the id `echo` (a proc: never repeated again, not by Mirror Sigil either).
- Borrowed Time: `_tick_borrowed_time` watches cooldowns of `BORROWED_TIME_COOLDOWN` or more; one leaving `cooldowns` (however it got there) gives the buff `borrowed_time`. `_borrowed_time_hit` (in `_on_damage_modify`) spends it on the first spell or ability hit and keeps the bonus for that ability's hits for `BORROWED_TIME_HITS` seconds.
- Mirror Finish: `_mirror_finish` (from `_on_hit_taken`): a dodged, parried or blocked hit deals a proc hit `mirror_finish` to its source.
- Overtime: `StatusContainer.apply` asks the source `self_buff_time_mult(res)` when it applies a non-debuff to itself. Effects whose time is set afterwards with `set_remaining` are not changed. Traces use the same multiplier.
- Slipstream: `_slipstream(id)` at the end of `_use_drafted` for `SLIPSTREAM_MOVES`.
- Two Minds: `PlayerData._compute_total_stats` (last, after the other conversions). Quick Study is a plain `stats` talent. Light Touch: `_on_damage_modify`, like Controlled Burn and Calm Current.
- `Talents.MAX_PER_ROW` is 5.

## Armor and armor types
- Armor reduces all damage taken (`Stats.armor_reduction(armor, level)` = armor / (armor + `ARMOR_DR_PER_LEVEL` x level), capped at `ARMOR_DR_CAP`). `CombatSystem.deal` folds it into the resist step with `Stats.mitigation`, for every hit that is not exact: all schools, damage over time, players and enemies alike. Armor buffs (Slag, Ice Barrier, Tempered's `armor%`) therefore add damage reduction.
- Armor does not block. Block chance is the Block stat alone (`Stats.total_block`): gear rolls, Strength (`BLOCK_PER_STRENGTH`) and buffs (Cinder Guard).
- Armor types: the six armor base items (`Balance.ARMOR_PIECES`, base id -> slot weight) each have an `armor_type` in their ItemDB record (0 Cloth, 1 Light, 2 Medium, 3 Heavy), rolled in `ItemDB.create` (`ROLL_ARMOR_TYPE`) or given. `Items.get_item` replaces the template's Armor with the type's (`Items.armor_piece_stats`: weight x `ARMOR_TYPE_ARMOR` flat units, plus weight x `ARMOR_TYPE_STAT_AMOUNT` of `ARMOR_TYPE_STAT`), and sets the name (`ARMOR_PIECE_NAMES`) and the description ("Heavy Armor").
- Records saved before types existed get `Balance.ARMOR_LEGACY_TYPE` in `ItemDB.load_records`. A new armor base item must be added to `ARMOR_PIECES`, `ARMOR_PIECE_NAMES` and `ARMOR_LEGACY_TYPE`.
- `/give <item> [cloth|light|medium|heavy] [rarity] [item level]`.

## Open talents (Fire and Lightning)
Code: `player.gd`, "Fire and Lightning: the open talents". Like the Arcane ones, they key off a mechanic, never a school.
- Feed the Flames: `_open_talents_modify` asks the target's `StatusContainer.has_dot_from(self)` (any effect with `tick_damage`, own only).
- Last Ember: `StatusContainer._process` asks the caster `dot_last_tick_pct(res)` when a damage over time effect expires on its own (`expires` > 0: `expire_now` sets 0), and deals one more `deal_dot` on the caster's machine.
- Tempered: `_tempered` (from `_on_hit_taken`) applies a stacking `armor%` buff on a blocked hit. No loop: Armor gives no Block.
- Spillover: `_spillover_talent` (from `_on_damage_dealt_arcane`): a non-proc, non-DoT crit sends an exact proc hit `spillover` to the nearest other enemy.
- Change of Pace: `_change_of_pace` on `SignalBus.cast_finished`; the bonus is read from the buff's stacks in `_open_talents_modify`.
- Dig In: `_tick_dig_in` (per frame) applies the buff `dig_in` after `DIG_IN_TIME` without moving more than `DIG_IN_SLACK`, and removes it on movement.

## Descriptions never carry a typed number
Texts hold placeholders, filled when a tooltip is shown (`scripts/core/text_fill.gd`); `tests/test_tooltips.gd` fails on a typed number.
- Everywhere: `{b:NAME}` = `Balance.NAME` (`{b%:}` x100, `{b2:}` x2, `{bth:}` ordinal, `{bev:}` "every second"), `{e:<effect>.<field>}`, `{a:<ability>.<field>}`, `{h:NAME}` (a share of Heal as a real amount), `{d:NAME}` (a damage coefficient as real damage, scaled like an ability), `{n:<ability>}` / `{ne:<effect>}` (names: a rename reaches every text).
- Abilities (`Abilities.fill`): `{hit} {dot} {heal} {flat1} {burst} {shatter}`, the ability's own data `{radius} {width} {range} {cast} {threat} {lockout}`, its on-hit effect `{fx_time} {fx_slow} {fx_pct} {fx_every}`. Talents that change a quoted number are applied (Stoked Kiln, Piercing Cold, Deep Brand, Long Burn, Endless Winter, Rime Ward...).
- Status effects (`TextFill.effect`): `{time} {slow} {pct} {tick} {every} {stacks} {mod}` of the effect itself.
- Talents (`Talents.description`): `{v}` / `{v2}` = the rank values, `{v+b:NAME}` = values + a Balance constant, `{vdmg:<ability>}` / `{v+dmg:<ability>}` / `{dmg:<ability>}` = real damage.
- Runes and item effects (`TextFill.rune`): `{n} {nth} {chance} {health} {every_s} {cd} {time} {stacks} {radius} {threat} {buff} {amount} {dot} {fx_*}`; `{taught}` = the taught spell's own text.
- In-game text shows real damage numbers. "Frost Bolts" as a unit of damage is only for design talk and code comments.

## Keywords, search and tooltips (`scripts/core/keywords.gd`)
- `Keywords.KEYWORDS`: the status words (Chilled, Frozen, Burning, Heat, Slag...), every form a text uses ("Chills", "Freezing") and what explains them (a status effect, or a text here). A new status word goes in this table.
- Named things = every ability, talent, rune and status effect, found in a text by name (longest name first, so "Frozen Focus" is a talent and not the keyword Frozen).
- `Keywords.paint(bbcode)`: keywords and names in orange. Ability tooltips paint their description; every plain tooltip (`tooltip_text` / meta `tip_text`: talents, runes, buffs) is painted by `ItemTooltip` except its title line.
- Shift: `Keywords.explain(text, own)` lists what the keywords and the named abilities / effects in a text mean. Ability tooltips add it under their details; plain tooltips show it while Shift is held (items keep Shift = compare).
- Search (`Keywords.search` / `matches`): a word matches at the start of a word in the name / description / tags / book, or as a keyword the entry really uses ("chill", "chilled" and "chilling" all mean Chilled). Used by the bar at the top of Abilities & Talents (shelf: a list of results, click = open the book with it framed; open book: matches framed, the rest dimmed) and by the search box on the Runes screen.
- Hover (`Keywords.related`): an ability or talent frames everything that mentions it or that it mentions (by name, or through a talent's `requires`).
- A talent with `"requires": "<ability>"` works with that one ability: its tooltip says "Requires X to be learned" and `PlayerData.can_invest` refuses points until it is.

## Action bars and macros
- `PlayerData.action_bar` has 32 slots: 0-7 the main bar, then 8 each for the top, left and right bars (off by default; Settings > Interface turns each on and sets its opacity). `Settings.slot_action(slot)` is a slot's Input Map action; the extra slots have no key until one is bound (Delete clears a key).
- A slot holds an ability id, `trinket_1` / `trinket_2` (the Use: effect of the trinket worn there; drag a worn or bagged on-use trinket onto a slot), or a macro (`macro:<uid>`).
- Macros (`scripts/core/macros.gd`, window `scripts/ui/macro_window.gd`, Esc > Macros): text lines `/cast X`, `/castsequence [reset=N] A, B, C`. One press runs every line: off-GCD abilities all fire, of the GCD ones the first usable is used (`Player._run_macro`). A linked ability gives the button its cooldown, charges, range check and tooltip. Stored in `PlayerData.macros`, saved in `user://macros.cfg` (kept by Wipe Save).

## Holy healer: the Hymns
Code: `player.gd`, "Holy healer: the Hymns"; numbers `balance.gd` (`VERSE_*`, `MERCY_*`, `CHORUS_*`, `VIGIL_*`, `BULWARK_SONG_*`, ...); design `docs/design/holy.md`.
- State lives on the healer's machine: `Player.hymn`, `Player.verses` (each entry = the Hymn that Verse suits), `_booms` (for Full Choir), `_last_boom` (for Reprise), `_refrains` (Refrain's heal over time).
- Gains: `Balance.VERSE_GAINS` via `_gain_verses` (instants in `_hymn_use`, casts in `_hymn_cast_heal`, High Note when it is released). Swell adds `SWELL_EXTRA`. Talent Verses: `_talent_verse(key, hymn)`, the talent's value = seconds between two.
- Singing: `_sing` -> `sing_outcome(count, from, kept, resting)` -> `_boom` -> `_do_boom(h, matches, full, scale)` (Reprise calls it with `REPRISE_PCT`). Multiplier `boom_mult`, Bulwark of Song's time `bulwark_song_time`, Full Choir `is_full_choir`.
- Casts go through `SUPPORT_CASTS` / `_release_support` (Psalm, Outpour, Canticle, Exultation); High Note is in `ENEMY_BOLTS` and heals in `_on_damage_dealt_holy`; the rest are `HYMN_INSTANTS` (`_hymn_precheck`, `_hymn_use`).
- On every heal of mine (`_on_heal_done_hymns`, ids in `HYMN_HEALS`): Mercy's Ear, Chorus's splash (`_chorus_splash`, meter `chorus_splash`) and Vigil's shield (`vigil_ward`).
- Party members: heals as usual (`support_ally "heal"`); less damage taken `support_ally "hymn_dr"` -> `receive_hymn_dr` (Vigil renewed every `VIGIL_TELL_EVERY` for `VIGIL_BUFF_TIME`, Steady Voice, Bulwark of Song); shields `"hymn_ward"` (Shelter, Vigil's); Watchful: the ally's `_vigil_taken` answers `"vigil_hit"`. Friendly dummies are handled locally.
- Pictures: `scripts/hymn_ring.gd` (`show_on`, `boom`), sent as the `"hymn"` / `"hymn_boom"` fx. HUD: the VS row in `hud.gd` (`_build_verse_row`), colours `Abilities.HYMN_COLORS`.
- Runes: Resounding (`RESOUNDING_*`, meter `resounding`), Overture (`overture_ready` and `_overture_cast` in `_begin_spell`; used up when the cast lands, castable on the move).
- Tests: `tests/test_hymns.gd`.

## Interrupts
Every interrupt (`Balance.INTERRUPT_LOCKOUT`) has a cooldown of at least `INTERRUPT_SHARED_COOLDOWN`, and using one puts all the others on at least that much (`Player.interrupt_cooldowns`).

Debug: `/rune <id> Main Hand`, `/effect <id>`, `/give <item> [rarity] [item level]` (`/give` alone lists the items; in the main menu the item goes to the bank).
