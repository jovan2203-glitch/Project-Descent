extends "res://scripts/player/player_kit.gd"
class_name ArcaneTalentsKit

# The Arcane book's talents of the ribbon tree (talents.gd) that change a hit, a
# cast or a cooldown, or answer a dodge, a shatter or a replay: damage and threat
# bonuses on my hits (each its own line: info.add_bonus with the talent's name),
# less damage taken, cooldowns coming back (On the Dot, Turning Gears), time taken
# off them (Unwinding, Second Hand), Armor and Dodge from Reflections, Traces and
# replays (Fresh Trace, Twin Blades, Final Act, Curtain Rise) and the open Spare
# Moment. The rest of the Arcane talents live with the rules they change
# (arcane_caster.gd, arcane_tank.gd, arcane_melee.gd, arcane_talents_open.gd).
# Hooked up from player.gd through its var "arcane_talents". Own only.

## Buffs on me.
const UNWINDING_FX := "unwinding"
const TURNING_GEARS_FX := "turning_gears"
const QUICK_ANSWER_FX := "quick_answer"
const CURTAIN_RISE_FX := "curtain_rise"
## The Second Act's cuts (Keen Cuts, Curtain Rise).
const CUTS := ["swiftcut", "deepcut", "latecut", "widecut"]

var _unwind_cast := false   # the current cast is Unwinding's instant one
var _watch := {}            # Arcane spells on cooldown I'm watching come back
var _ready_at := {}         # Arcane spell -> when it last came off cooldown
var _dotted := {}           # Arcane spells cast On the Dot whose hits get it
var _dust := {}             # enemy instance id -> until when Glass Dust holds (my shatters hit it)
var _unwind_frame := -1     # (Unwinding rolls once per frame of time taken off)

# Rules as static functions (tests/test_arcane_tree.gd).

## Wound Up: % more for `on_cooldown` other Arcane spells (`pct` each, up to WOUND_UP_MAX).
static func wound_up_pct(on_cooldown: int, pct: float) -> float:
	return maxf(pct, 0.0) * clampi(on_cooldown, 0, Balance.WOUND_UP_MAX)

## Clock Hands: a cast time multiplier with `on_cooldown` Arcane spells waiting.
static func clock_hands_mult(on_cooldown: int, pct: float) -> float:
	return 1.0 - maxf(pct, 0.0) / 100.0 if on_cooldown >= Balance.CLOCK_HANDS_COOLDOWNS else 1.0

## On the Dot: was a cast `since` seconds after the spell came back in time?
static func on_the_dot(since: float) -> bool:
	return since >= 0.0 and since <= Balance.ON_THE_DOT_TIME

## Fresh Trace: what a Trace of `amount` records while holding `held` Traces.
static func fresh_trace_amount(amount: int, held: int, pct: float) -> int:
	if pct <= 0.0 or held >= Balance.FRESH_TRACE_HELD:
		return amount
	return int(round(float(amount) * (1.0 + pct / 100.0)))

## Spare Moment: how much faster a cooldown of `base` seconds recovers.
static func spare_moment_rate(base: float, pct: float, is_interrupt: bool) -> float:
	return 1.0 + maxf(pct, 0.0) / 100.0 if base >= Balance.SPARE_MOMENT_COOLDOWN and not is_interrupt else 1.0

## Is this one of my Arcane spells' own hits (not a proc or a tick)?
static func arcane_spell_hit(tags: PackedStringArray, is_proc: bool, is_dot: bool) -> bool:
	return tags.has("Arcane") and tags.has("Spell") and not is_proc and not is_dot

## Is this one of my Arcane abilities' own hits?
static func arcane_ability_hit(tags: PackedStringArray, is_proc: bool, is_dot: bool) -> bool:
	return tags.has("Arcane") and tags.has("Ability") and not is_proc and not is_dot

func _has(fx_id: String) -> bool:
	return player.status != null and player.status.has(fx_id)

func _buff(fx_id: String, label: String, time: float, text: String, stat: String = "", pct: float = 0.0, stacks: int = 1) -> Resource:
	var fx := StatusContainer.make_buff(fx_id, label, stat if stat != "" else fx_id, pct, time, stacks,
		Abilities.color_of("arcanemissiles"))
	if stat == "":
		fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Arcane"])
	fx.description = text
	return fx

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

# --- Casts and cooldowns -------------------------------------------------------------------

## Cast time multiplier for `spell` (Clock Hands).
func cast_mult(spell: String) -> float:
	var pct := player._talent("arcane_clock_hands")
	if pct <= 0.0 or not player.arcane_caster._is_arcane_spell(spell):
		return 1.0
	return clock_hands_mult(player.arcane_caster.arcane_cooldowns(), pct)

## Mana cost multiplier for `id` (Thrifty Mind).
func mana_mult(id: String) -> float:
	var pct := player._talent("arcane_thrifty_mind")
	return 1.0 - pct / 100.0 if pct > 0.0 and player.arcane_caster._is_arcane_spell(id) else 1.0

## How much faster cooldown `id` recovers (Spare Moment).
func cooldown_rate(id: String) -> float:
	var pct := player._talent("arcane_spare_moment")
	if pct <= 0.0:
		return 1.0
	var res := Abilities.get_resource(id)
	return spare_moment_rate(float(res.cooldown) if res else 0.0, pct, Player.INTERRUPT_LOCKOUT.has(id))

## Is `spell` the Arcane spell Unwinding makes instant?
func unwinding_ready(spell: String) -> bool:
	if not _has(UNWINDING_FX) or not player.arcane_caster._is_arcane_spell(spell):
		return false
	var res := Abilities.get_resource(spell)
	return res != null and float(res.cast_time) > 0.0

## Time was just taken off one of my Arcane spells' cooldowns: Unwinding (once a frame).
func time_taken_off() -> void:
	var pct := player._talent("arcane_unwinding")
	var frame := Engine.get_process_frames()
	if pct <= 0.0 or frame == _unwind_frame or player.status == null:
		return
	_unwind_frame = frame
	if randf() * 100.0 < pct:
		player.status.apply(_buff(UNWINDING_FX, "Unwinding", Balance.UNWINDING_TIME,
			"Your next Arcane spell with a cast time is instant."), player)

## Every frame after the cooldowns tick (Player._tick_cooldowns): which of my Arcane
## spells just came back (On the Dot, Turning Gears).
func _tick_cooldowns() -> void:
	if player.cooldowns.is_empty() and _watch.is_empty():
		return
	for id in player.cooldowns:
		if not _watch.has(id) and player.arcane_caster._is_arcane_spell(str(id)):
			_watch[id] = true
	var gears := player._talent("arcane_turning_gears")
	for id in _watch.keys():
		if player.cooldowns.has(id):
			continue
		_watch.erase(id)
		_ready_at[id] = _now()
		if gears > 0.0 and player.status != null and player.is_alive():
			var had: int = player.status.stacks_of(TURNING_GEARS_FX) if player.status.has(TURNING_GEARS_FX) else 0
			player.status.apply(_buff(TURNING_GEARS_FX, "Turning Gears", Balance.TURNING_GEARS_TIME,
				"%s%% Haste per stack." % Stats.num(gears), Stats.HASTE, gears, Balance.TURNING_GEARS_STACKS), player)
			player.status.set_stacks(TURNING_GEARS_FX, mini(had + 1, Balance.TURNING_GEARS_STACKS))

## I used `id` (SignalBus.ability_used): On the Dot.
func _on_ability_used(id: String) -> void:
	if player._talent("arcane_on_the_dot") <= 0.0 or not player.arcane_caster._is_arcane_spell(id):
		return
	if on_the_dot(_now() - float(_ready_at.get(id, -1000.0))):
		_dotted[id] = true
	else:
		_dotted.erase(id)

## I finished casting `id` (SignalBus.cast_finished): Second Hand.
func _on_cast_finished(id: String) -> void:
	var pct := player._talent("arcane_second_hand")
	if pct <= 0.0 or not player.arcane_caster._is_arcane_spell(id) or randf() * 100.0 >= pct:
		return
	var waiting: Array = []
	for cd in player.cooldowns:
		if str(cd) != id and player.arcane_caster._is_arcane_spell(str(cd)):
			waiting.append(str(cd))
	if not waiting.is_empty():
		player.arcane_caster._cut_cooldown(str(waiting[randi() % waiting.size()]), Balance.SECOND_HAND_SECONDS)

# --- Hits I deal ---------------------------------------------------------------------------

## A hit of mine, before its damage is worked out (_on_damage_modify).
func _arcane_talents_outgoing(info: RefCounted) -> void:
	var id := str(info.ability_id)
	var tags: PackedStringArray = info.tags
	var proc := bool(info.is_proc)
	var dot := bool(info.is_dot)
	if arcane_spell_hit(tags, proc, dot):
		var pinned := player._talent("arcane_pinned_in_time")
		if pinned > 0.0 and player.frost_talents.rooted_by_me(info.target):
			info.add_bonus(pinned, "Pinned in Time")
		var wound := wound_up_pct(player.arcane_caster.arcane_cooldowns(id), player._talent("arcane_wound_up"))
		if wound > 0.0:
			info.add_bonus(wound, "Wound Up")
		var moving := player._talent("arcane_moving_parts")
		if moving > 0.0 and Vector2(player.velocity.x, player.velocity.z).length() > 0.5:
			info.add_bonus(moving, "Moving Parts")
		if _dotted.has(id):
			info.add_bonus(player._talent("arcane_on_the_dot"), "On the Dot")
			_drop_dotted.call_deferred(id)
	if tags.has("Arcane") and tags.has("Ability"):
		var crowd := player._talent("arcane_crowded_room")
		if crowd > 0.0:
			info.threat_multiplier *= 1.0 + crowd * player.arcane_tank.reflections() / 100.0
	if arcane_ability_hit(tags, proc, dot):
		if _has(QUICK_ANSWER_FX):
			var answer := player._talent("arcane_quick_answer")
			info.add_bonus(answer, "Quick Answer")
			info.threat_multiplier *= 1.0 + answer / 100.0
			player.lightning_melee._use_charge(QUICK_ANSWER_FX)
		var stage := player._talent("arcane_full_stage")
		if stage > 0.0 and player.arcane_melee.traces() >= ArcaneMeleeKit.trace_cap(player.frost_melee._capstone("arcane_standing_ovation"),
				_has(ArcaneMeleeKit.DOUBLE_TIME_FX)):
			info.add_bonus(stage, "Full Stage")
		if CUTS.has(id) and _has(CURTAIN_RISE_FX):
			info.add_bonus(player._talent("arcane_curtain_rise"), "Curtain Rise")
			player.lightning_melee._use_charge(CURTAIN_RISE_FX)

func _drop_dotted(id: String) -> void:
	_dotted.erase(id)

## Crit bonuses (Player.crit_hit_bonus): Sharp Mind.
func crit_hit_bonus(info: RefCounted) -> Array:
	var sharp := player._talent("arcane_sharp_mind")
	if sharp > 0.0 and arcane_spell_hit(info.tags, bool(info.is_proc), bool(info.is_dot)):
		return [sharp, "Sharp Mind"]
	return []

## Crit chance (Player.adjust_crit): Keen Cuts.
func adjust_crit(info: RefCounted, chance: float) -> float:
	if CUTS.has(str(info.ability_id)) and not info.is_proc:
		chance += player._talent("arcane_keen_cuts")
	return chance

## A hit of mine landed (SignalBus.damage_dealt): Glass Dust remembers who my
## shatters hit; Twin Blades: an auto-attack may leave a Trace.
func _on_damage_dealt(info: RefCounted) -> void:
	if not is_same(info.source, player) or info.avoided() or not is_instance_valid(info.target):
		return
	var id := str(info.ability_id)
	if id == ArcaneTankKit.REFLECTION_SHATTER_ID and player._talent("arcane_glass_dust") > 0.0:
		_dust[info.target.get_instance_id()] = _now() + Balance.GLASS_DUST_TIME
	elif id == "auto_melee" and int(info.amount) > 0:
		var twin := player._talent("arcane_twin_blades")
		if twin > 0.0 and player.arcane_tank.has_dual_wield() and randf() * 100.0 < twin:
			player.arcane_melee._leave_trace(id, fresh_trace(int(info.amount)))

## What a Trace of `amount` records (Fresh Trace).
func fresh_trace(amount: int) -> int:
	return fresh_trace_amount(amount, player.arcane_melee.traces(), player._talent("arcane_fresh_trace"))

## Extra bonuses one replay on `foe` gets ([[pct, label]]; replays skip the usual
## modifiers): Final Act.
func replay_bonuses(foe: Variant) -> Array:
	var final := player._talent("arcane_final_act")
	if final <= 0.0 or foe == null or not is_instance_valid(foe):
		return []
	var hp := float(foe.get("health")) if foe.get("health") != null else 0.0
	var top := float(foe.get("max_health")) if foe.get("max_health") != null else 0.0
	return [[final, "Final Act"]] if top > 0.0 and hp / top * 100.0 < Balance.FINAL_ACT_HEALTH else []

## I replayed `count` Traces: Curtain Rise.
func replayed(count: int) -> void:
	var rise := player._talent("arcane_curtain_rise")
	if rise > 0.0 and count > 0 and player.status != null:
		player.status.apply(_buff(CURTAIN_RISE_FX, "Curtain Rise", Balance.CURTAIN_RISE_TIME,
			"Your next cut deals %s%% more damage." % Stats.num(rise)), player)

# --- Hits I take ---------------------------------------------------------------------------

## Armor multiplier from my Reflections (Glass Armor; Player.get_stat).
func armor_mult() -> float:
	var pct := player._talent("arcane_glass_armor")
	return 1.0 + pct * player.arcane_tank.reflections() / 100.0 if pct > 0.0 else 1.0

## Dodge Last Copy adds right now (Player.get_stat).
func dodge_bonus() -> float:
	var pct := player._talent("arcane_last_copy")
	return pct if pct > 0.0 and player.arcane_tank.reflections() == 1 else 0.0

## A hit on me, before its damage is worked out: Glass Dust.
func _arcane_talents_incoming(info: RefCounted) -> void:
	var dust := player._talent("arcane_glass_dust")
	if dust <= 0.0 or info.source == null or not is_instance_valid(info.source):
		return
	var key: int = (info.source as Object).get_instance_id()
	if float(_dust.get(key, 0.0)) > _now():
		info.add_bonus(-dust, "Glass Dust")
	elif _dust.has(key):
		_dust.erase(key)

## Something hit me (fire_cooldowns._on_hit_taken): Quick Answer after a dodge.
func _hit_taken(info: RefCounted) -> void:
	var answer := player._talent("arcane_quick_answer")
	if answer > 0.0 and info.dodged and player.status != null:
		player.status.apply(_buff(QUICK_ANSWER_FX, "Quick Answer", Balance.QUICK_ANSWER_TIME,
			"Your next Arcane ability deals %s%% more damage and threat." % Stats.num(answer)), player)
