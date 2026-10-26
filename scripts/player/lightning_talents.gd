extends "res://scripts/player/player_kit.gd"
class_name LightningTalentsKit

# The Lightning book's talents of the ribbon tree (talents.gd) that change a hit,
# answer Energy spent or gained, or a parry: damage and threat bonuses on my hits
# (each its own line: info.add_bonus with the talent's name), less damage taken,
# the zaps they add (Sparking Swings, Spark Guard), and the open talents Cut the
# Line, Fresh Charge and Static Build. The rest of the Lightning talents live with
# the rules they change (lightning_caster.gd, lightning_bottled.gd,
# lightning_melee.gd, lightning_tank.gd, lightning_bow.gd). Hooked up from
# player.gd through its var "lightning_talents". Own only.

## Meter / log ids of the zaps these talents add (Details.HIT_NAMES).
const SPARKING_SWINGS_ID := "sparkingswings"
const SPARK_GUARD_ID := "sparkguard"
## Buffs on me.
const FULL_CIRCUIT_FX := "full_circuit"
const SNAP_CAST_FX := "snap_cast"
const AFTERFLOW_FX := "afterflow"
const AFTERSPARK_FX := "afterspark"
const BUILT_CHARGE_FX := "built_charge"
const CHARGED_GUARD_FX := "charged_guard"
const CUT_THE_LINE_FX := "cut_the_line"
const STATIC_BUILD_FX := "static_build"
## Live Current's lingering lightning: what Lingering Storm keeps up longer, and
## (with Live Wire's ticks) what Crackle makes hit harder.
const LINGERING_IDS := ["balllightning", "thunderhead"]
const CRACKLE_IDS := ["balllightning", "thunderhead", "livewire", "dot_live_wire"]
## Leaps and forks (their hits are procs of the spell): Long Leap.
const LEAP_IDS := ["chainlightning", "forkedbolt"]
## Arcs to other enemies (procs of these): Wide Current.
const ARC_IDS := ["stormshield", "returnstroke"]
## Hits on every enemy around me (and Cadence's third strike): Ring True.
const RING_IDS := ["shockring", "arccleave", "arcflash"]

var _built := 0.0     # Energy spent toward the next Built Charge
var _spun := 0.0      # ... toward the next Spinning Up step
var _drawn := 0.0     # ... toward the next Draw Down heal
var _parries := 0     # parries toward Storm Anchor's free Shock Ring
var _was_full := false
var _last_pos := Vector3.INF
var _moved := 0.0     # metres toward the next Static Build stack
var _forced := {}     # enemy instance id -> when it stops having to attack me (Hard Stare)

# Rules as static functions (tests/test_lightning_tree.gd).

## A Lightning ability that swings a weapon ("Lightning weapon abilities").
static func weapon_ability(id: String) -> bool:
	return Abilities.tags_of(id).has("Lightning") and Abilities.uses_weapon(id)

## Is this hit a Lightning spell's own hit (not a proc, a tick or a lingering zap)?
static func lightning_spell_hit(id: String, tags: PackedStringArray, is_proc: bool, is_dot: bool) -> bool:
	return tags.has("Lightning") and tags.has("Spell") and not is_proc and not is_dot and not LINGERING_IDS.has(id)

## Energy a spend-all ability counts with Deep Draw adding `pct` %.
static func deep_draw(spent: float, pct: float) -> float:
	return maxf(spent, 0.0) * (1.0 + maxf(pct, 0.0) / 100.0)

## Energy a Lightning spell gives with Feedback adding `pct` %.
static func feedback(amount: float, pct: float) -> float:
	return amount * (1.0 + maxf(pct, 0.0) / 100.0)

## Spent Energy counted toward a step of `every`: [left over, steps made].
static func steps(counted: float, amount: float, every: float) -> Array:
	var total := counted + maxf(amount, 0.0)
	var n := int(floor(total / every)) if every > 0.0 else 0
	return [total - n * every, n]

## Static Build: stacks after moving `metres` more with `stacks` already.
static func static_build_stacks(stacks: int, metres: float) -> int:
	return clampi(stacks + int(floor(metres / Balance.STATIC_BUILD_STEP)), 0, Balance.STATIC_BUILD_STACKS)

## Global cooldown of a Lightning weapon ability with Short Fuse taking `less` off.
static func short_fuse_gcd(gcd: float, less: float) -> float:
	return maxf(gcd - maxf(less, 0.0), Balance.GCD_MIN)

func _has(fx_id: String) -> bool:
	return player.status != null and player.status.has(fx_id)

func _buff(fx_id: String, label: String, time: float, text: String, stat: String = "", pct: float = 0.0, stacks: int = 1) -> Resource:
	var fx := StatusContainer.make_buff(fx_id, label, stat if stat != "" else fx_id, pct, time, stacks,
		Abilities.color_of("lightningbolt"))
	if stat == "":
		fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Lightning"])
	fx.description = text
	return fx

# --- Energy -----------------------------------------------------------------------------

## % faster Energy regeneration from talents right now (Quick Charge, Afterflow).
func regen_pct() -> float:
	var pct := player._talent("lightning_quick_charge")
	if _has(AFTERFLOW_FX):
		pct += player._talent("lightning_afterflow")
	return pct

## I spent `amount` Energy on `id` ("" for a spend-all ability): Afterspark, Built
## Charge, Spinning Up, Draw Down.
func energy_spent(amount: float, id: String = "") -> void:
	if amount <= 0.0 or player.status == null:
		return
	var tags := Abilities.tags_of(id)
	var spark := player._talent("lightning_afterspark")
	if spark > 0.0 and tags.has("Lightning") and tags.has("Ability"):
		player.status.apply(_buff(AFTERSPARK_FX, "Afterspark", Balance.AFTERSPARK_TIME,
			"Your next auto-attack deals %s%% more damage." % Stats.num(spark)), player)
	var built := player._talent("lightning_built_charge")
	if built > 0.0:
		var s := steps(_built, amount, Balance.BUILT_CHARGE_EVERY)
		_built = float(s[0])
		if int(s[1]) > 0:
			player.status.apply(_buff(BUILT_CHARGE_FX, "Built Charge", Balance.BUILT_CHARGE_TIME,
				"Your next Lightning weapon ability deals %s%% more damage." % Stats.num(built)), player)
	var spin := player._talent("lightning_spinning_up")
	if spin > 0.0:
		var s := steps(_spun, amount, Balance.SPINNING_UP_EVERY)
		_spun = float(s[0])
		if int(s[1]) > 0:
			for cd_id in player.cooldowns.keys():
				if weapon_ability(str(cd_id)):
					player.cooldowns[cd_id] = maxf(float(player.cooldowns[cd_id]) - spin * int(s[1]), 0.0)
	var draw := player._talent("lightning_draw_down")
	if draw > 0.0:
		var s := steps(_drawn, amount, Balance.ENERGY_STEP)
		_drawn = float(s[0])
		var heal := int(round(float(player.max_health) * draw / 100.0 * int(s[1])))
		if heal > 0 and player.health < player.max_health:
			player._combat().heal(player, player, float(heal), "draw_down", true)

## I spent all my Energy (Discharge, Ground Out, Recharge): Afterflow.
func spent_all() -> void:
	var flow := player._talent("lightning_afterflow")
	if flow > 0.0 and player.status != null:
		player.status.apply(_buff(AFTERFLOW_FX, "Afterflow", Balance.AFTERFLOW_TIME,
			"Your Energy regenerates %s%% faster." % Stats.num(flow)), player)

## Energy `id` gives when it is used, with Edge Current (Lightning weapon abilities).
func generated(id: String, amount: float) -> float:
	if amount > 0.0 and weapon_ability(id):
		amount += player._talent("lightning_edge_current")
	return amount

## Energy a Lightning spell gives (Leaping Arc, Ball Lightning's zaps, Live Wire's ticks), with Feedback.
func spell_energy(amount: float) -> float:
	return feedback(amount, player._talent("lightning_feedback"))

## I finished casting `id` (SignalBus.cast_finished): Charged Air.
func _on_cast_finished(id: String) -> void:
	var air := player._talent("lightning_charged_air")
	if air <= 0.0 or not Abilities.tags_of(id).has("Lightning") or not Abilities.tags_of(id).has("Spell"):
		return
	var res := Abilities.get_resource(id)
	if res != null and float(res.cast_time) > 0.0:
		player._gain("energy", air)

## I used `id` (SignalBus.ability_used): Cut the Line.
func _on_ability_used(id: String) -> void:
	var pct := player._talent("lightning_cut_the_line")
	if pct > 0.0 and Abilities.is_interrupt(id) and player.status != null:
		player.status.apply(_buff(CUT_THE_LINE_FX, "Cut the Line", Balance.CUT_THE_LINE_TIME,
			"%s%% Haste." % Stats.num(pct), Stats.HASTE, pct), player)

## Seconds Lingering Storm adds to Ball Lightning and Thunderhead.
func lingering() -> float:
	return player._talent("lightning_lingering_storm")

## Is `spell` the Lightning Bolt Snap Cast makes instant?
func snap_cast_ready(spell: String) -> bool:
	return spell == "lightningbolt" and _has(SNAP_CAST_FX)

## % faster auto-attacks from Light Load right now.
func light_load_speed() -> float:
	var pct := player._talent("lightning_light_load")
	return pct if pct > 0.0 and float(player.resources.get("energy", 0.0)) < Balance.LIGHT_LOAD_ENERGY else 0.0

## Parry chance Back to the Wall adds right now (Player.get_stat).
func back_to_the_wall() -> float:
	var pct := player._talent("lightning_back_to_the_wall")
	if pct <= 0.0 or player.max_health <= 0:
		return 0.0
	return pct if float(player.health) / float(player.max_health) * 100.0 < Balance.BACK_TO_THE_WALL_HEALTH else 0.0

## Global cooldown after using `id` (Short Fuse: Lightning weapon abilities).
func gcd_for(id: String, gcd: float) -> float:
	var less := player._talent("lightning_short_fuse")
	return short_fuse_gcd(gcd, less) if less > 0.0 and weapon_ability(id) else gcd

## Every frame: Full Circuit (the bar just filled up) and Static Build (moving).
func _tick(_delta: float) -> void:
	if player.status == null or player.is_dead():
		return
	var full := float(player.resources.get("energy", 0.0)) >= player.resource_max("energy") - 0.01
	var circuit := player._talent("lightning_full_circuit")
	if full and not _was_full and circuit > 0.0:
		player.status.apply(_buff(FULL_CIRCUIT_FX, "Full Circuit", Balance.FULL_CIRCUIT_TIME,
			"Your next Lightning spell deals %s%% more damage." % Stats.num(circuit)), player)
	_was_full = full
	var build := player._talent("lightning_static_build")
	if build <= 0.0:
		_last_pos = Vector3.INF
		return
	var at: Vector3 = player.global_position
	if _last_pos != Vector3.INF:
		_moved += Vector2(at.x - _last_pos.x, at.z - _last_pos.z).length()
	_last_pos = at
	if _moved >= Balance.STATIC_BUILD_STEP:
		var have: int = player.status.stacks_of(STATIC_BUILD_FX) if player.status.has(STATIC_BUILD_FX) else 0
		var now := static_build_stacks(have, _moved)
		_moved = fmod(_moved, Balance.STATIC_BUILD_STEP)
		if now > have:
			player.status.apply(_buff(STATIC_BUILD_FX, "Static Build", 3600.0,
				"Your next spell or ability deals %s%% more damage per stack." % Stats.num(build), "", 0.0, Balance.STATIC_BUILD_STACKS), player)
			player.status.set_stacks(STATIC_BUILD_FX, now)

# --- Hits I deal ---------------------------------------------------------------------------

## A hit of mine, before its damage is worked out (_on_damage_modify).
func _lightning_talents_outgoing(info: RefCounted) -> void:
	var id := str(info.ability_id)
	var tags: PackedStringArray = info.tags
	var lightning := str(info.damage_type) == "lightning"
	var proc := bool(info.is_proc)
	var dot := bool(info.is_dot)
	if proc and LEAP_IDS.has(id):
		_bonus(info, "lightning_long_leap", "Long Leap")
	if CRACKLE_IDS.has(id):
		_bonus(info, "lightning_crackle", "Crackle")
	if lightning_spell_hit(id, tags, proc, dot) and _has(FULL_CIRCUIT_FX):
		info.add_bonus(player._talent("lightning_full_circuit"), "Full Circuit")
		player.lightning_melee._use_charge(FULL_CIRCUIT_FX)
	if id == "auto_melee" and _has(AFTERSPARK_FX):
		info.add_bonus(player._talent("lightning_afterspark"), "Afterspark")
		player.lightning_melee._use_charge(AFTERSPARK_FX)
	if weapon_ability(id) and LightningMeleeKit.is_weapon_ability_hit(id, proc, dot):
		_bonus(info, "lightning_storm_dance", "Storm Dance")
		if _has(BUILT_CHARGE_FX):
			info.add_bonus(player._talent("lightning_built_charge"), "Built Charge")
			player.lightning_melee._use_charge(BUILT_CHARGE_FX)
	if not proc and lightning and (RING_IDS.has(id) or (id == LightningMeleeKit.CADENCE_ID and player.lightning_melee._cadence_third)):
		var ring := _bonus(info, "lightning_ring_true", "Ring True")
		info.threat_multiplier *= 1.0 + ring / 100.0
	if proc and ARC_IDS.has(id):
		var wide := _bonus(info, "lightning_wide_current", "Wide Current")
		info.threat_multiplier *= 1.0 + wide / 100.0
	if id == SPARK_GUARD_ID:
		info.threat_multiplier *= Balance.SPARK_GUARD_THREAT
	if info.tags.has("Lightning") and player.lightning_tank.has_two_hander():
		info.threat_multiplier *= 1.0 + player._talent("lightning_loud_steel") / 100.0
	# Open: any spell or ability (not auto-attacks, procs or ticks).
	if not proc and not dot and not id.begins_with("auto_") and (tags.has("Spell") or tags.has("Ability")):
		var fresh := player._talent("lightning_fresh_charge")
		if fresh > 0.0 and player.max_health > 0 and float(player.health) / float(player.max_health) * 100.0 > Balance.FRESH_CHARGE_HEALTH:
			info.add_bonus(fresh, "Fresh Charge")
		if _has(STATIC_BUILD_FX):
			info.add_bonus(player._talent("lightning_static_build") * player.status.stacks_of(STATIC_BUILD_FX), "Static Build")
			player.lightning_melee._use_charge(STATIC_BUILD_FX)

## Adds talent `key`'s % to the hit as its own line; returns it (0 without the talent).
func _bonus(info: RefCounted, key: String, label: String) -> float:
	var pct := player._talent(key)
	if pct > 0.0:
		info.add_bonus(pct, label)
	return pct

## Crit bonuses (Player.crit_hit_bonus): Charged Steel.
func crit_hit_bonus(info: RefCounted) -> Array:
	var steel := player._talent("lightning_charged_steel")
	if steel > 0.0 and weapon_ability(str(info.ability_id)) and not info.is_proc and not info.is_dot:
		return [steel, "Charged Steel"]
	return []

## Crit chance (Player.adjust_crit): Keen Current on auto-attacks.
func adjust_crit(info: RefCounted, chance: float) -> float:
	if str(info.ability_id).begins_with("auto_"):
		chance += player._talent("lightning_keen_current")
	return chance

## A hit of mine landed (SignalBus.damage_dealt): Snap Cast.
func _on_damage_dealt(info: RefCounted) -> void:
	if not is_same(info.source, player) or info.avoided() or not bool(info.crit):
		return
	var snap := player._talent("lightning_snap_cast")
	if snap > 0.0 and lightning_spell_hit(str(info.ability_id), info.tags, bool(info.is_proc), bool(info.is_dot)):
		if randf() * 100.0 < snap and player.status != null:
			player.status.apply(_buff(SNAP_CAST_FX, "Snap Cast", Balance.SNAP_CAST_TIME,
				"Your next %s is instant." % Abilities.ability_name("lightningbolt")), player)

## An auto-attack of mine landed on `foe` (lightning_melee._on_auto_landed): Sparking Swings.
func auto_landed(foe: Node) -> void:
	var chance := player._talent("lightning_sparking_swings")
	if chance > 0.0 and is_instance_valid(foe) and foe.is_alive() and randf() * 100.0 < chance:
		player.deal_damage(foe, Balance.SPARKING_SWINGS_DAMAGE, SPARKING_SWINGS_ID, true, "lightning", PackedStringArray(["Lightning", "Melee"]))

## Overdrive zapped `foe`: Storm Dance's capstone zaps one more enemy near it.
func overdrive_zapped(foe: Node, coef: float) -> void:
	if not player.frost_melee._capstone("lightning_storm_dance") or not is_instance_valid(foe):
		return
	var near := player._enemies_near(foe.global_position, Balance.STORM_DANCE_REACH, foe)
	if not near.is_empty():
		player.deal_damage(near[0], coef, LightningMeleeKit.OVERDRIVE_ID, true)

# --- Hits I take ---------------------------------------------------------------------------

## I forced `foe` to attack me for `time` seconds (Hard Stare remembers it).
func note_forced(foe: Node, time: float) -> void:
	if foe != null and is_instance_valid(foe):
		_forced[foe.get_instance_id()] = Time.get_ticks_msec() / 1000.0 + time

func _forced_now(foe: Variant) -> bool:
	if foe == null or not is_instance_valid(foe) or not (foe is Object):
		return false
	return float(_forced.get((foe as Object).get_instance_id(), 0.0)) > Time.get_ticks_msec() / 1000.0

## A hit on me, before its damage is worked out: Charged Guard, Charged Shell, Hard Stare.
func _lightning_talents_incoming(info: RefCounted) -> void:
	if _has(CHARGED_GUARD_FX):
		info.add_bonus(-player._talent("lightning_charged_guard"), "Charged Guard")
		player.status.remove(CHARGED_GUARD_FX)
	var shell := player._talent("lightning_charged_shell")
	if shell > 0.0 and float(player.resources.get("energy", 0.0)) > Balance.CHARGED_SHELL_ENERGY:
		info.add_bonus(-shell, "Charged Shell")
	var stare := player._talent("lightning_hard_stare")
	if stare > 0.0 and _forced_now(info.source):
		info.add_bonus(-stare, "Hard Stare")

## Something hit me (fire_cooldowns._on_hit_taken): parries (Spark Guard, Charged
## Guard, Storm Anchor) and hits I didn't avoid (Hard Lessons).
func _hit_taken(info: RefCounted) -> void:
	if info.parried:
		var foe: Variant = info.source
		var spark := player._talent("lightning_spark_guard")
		if spark > 0.0 and foe != null and is_instance_valid(foe) and foe is Node and foe.is_in_group("enemies") and foe.is_alive():
			player.deal_damage(foe, spark, SPARK_GUARD_ID, true, "lightning", PackedStringArray(["Lightning", "Melee"]))
		var guard := player._talent("lightning_charged_guard")
		if guard > 0.0:
			player.status.apply(_buff(CHARGED_GUARD_FX, "Charged Guard", Balance.CHARGED_GUARD_TIME,
				"The next hit you take deals %s%% less damage." % Stats.num(guard)), player)
		if player.frost_melee._capstone("lightning_storm_anchor"):
			_parries += 1
			if _parries >= Balance.STORM_ANCHOR_EVERY:
				_parries = 0
				var pd := player.get_node_or_null("/root/PlayerData")
				if pd and pd.has_ability(LightningTankKit.SHOCK_RING_ID):
					player.lightning_tank._shock_ring(Abilities.get_resource(LightningTankKit.SHOCK_RING_ID))
		return
	if info.avoided() or info.blocked or info.is_dot or int(info.amount) <= 0:
		return
	var lessons := player._talent("lightning_hard_lessons")
	if lessons > 0.0:
		player._gain("energy", lessons)
