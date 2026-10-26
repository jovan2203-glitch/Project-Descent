extends "res://scripts/player/player_kit.gd"
class_name LightningTankKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "lightning_tank".
# --- Lightning tank (a parry tank with a two-handed weapon) ---------------------------------
# Stormbreak gives Energy. Humming Blade raises my Parry and its cap, and makes
# every parry give Energy. A parry opens Return Stroke (one answer per parry).
# Shock Ring spends Energy for threat around me, Crossguard parries everything
# for a moment, and Draw the Storm pulls enemies onto me and makes my parries
# zap them. Numbers are in balance.gd.

const STORMBREAK_ID := "stormshield"   # (the id it had as Stormshield Slam)
const HUMMING_ID := "thunderaegis"     # (the id it had as Aegis of Thunder)
const HUMMING_FX := "humming_blade"
const RETURN_STROKE_ID := "returnstroke"
const RETURN_STROKE_FX := "return_stroke"
const SHOCK_RING_ID := "shockring"
const CROSSGUARD_ID := "crossguard"
const CROSSGUARD_FX := "crossguard"
const STORM_ID := "drawthestorm"
const STORM_FX := "draw_the_storm"
const COUNTER_CHARGE_LABEL := "Counter-Charge"

## Is a two-handed weapon in my Main Hand?
func has_two_hander() -> bool:
	return bool(player._weapon().get("locks_offhand", false))

## The most Parry chance (%) that counts with these up: all of it during
## Crossguard, HUMMING_BLADE_PARRY_CAP with Humming Blade, the usual cap otherwise.
static func parry_cap_for(humming: bool, crossguard: bool) -> float:
	if crossguard:
		return 100.0
	return Balance.HUMMING_BLADE_PARRY_CAP if humming else Stats.MAX_PARRY

## My Parry cap right now (CombatSystem and the stat panel ask).
func parry_cap() -> float:
	return parry_cap_for(player.status != null and player.status.has(HUMMING_FX), player.status != null and player.status.has(CROSSGUARD_FX))

## Energy an attack I parry gives during Humming Blade, with Closed Circuit adding `more`.
static func parry_energy(more: float) -> float:
	return Balance.HUMMING_BLADE_ENERGY + maxf(more, 0.0)

## Seconds left of a cooldown of `left` once Quick Wrists takes `off` away for a parry.
static func quick_wrists_cooldown(left: float, off: float) -> float:
	return maxf(left - maxf(off, 0.0), 0.0)

func _start_humming_blade() -> void:
	var col := Abilities.color_of(HUMMING_ID)
	var fx := player.lightning_melee._melee_buff(HUMMING_FX, HUMMING_ID, Balance.HUMMING_BLADE_TIME,
		"+%s%% Parry, and your Parry cap is %s%%. Each attack you parry gives you Energy." % [
			Stats.num(Balance.HUMMING_BLADE_PARRY), Stats.num(Balance.HUMMING_BLADE_PARRY_CAP)])
	fx.stat_modifiers = {Stats.PARRY: Balance.HUMMING_BLADE_PARRY}
	player.status.apply(fx, player)
	player._slash_effect(col)
	player._ring_effect(1.2, col)

func _start_crossguard() -> void:
	var col := Abilities.color_of(CROSSGUARD_ID)
	var fx := player.lightning_melee._melee_buff(CROSSGUARD_FX, CROSSGUARD_ID, Balance.CROSSGUARD_TIME,
		"You parry every attack that can be parried.")
	fx.stat_modifiers = {Stats.PARRY: 100.0}   # (and parry_cap() lets all of it count)
	player.status.apply(fx, player)
	for i in 2:
		player._slash_effect(col)
	player._ring_effect(0.9, Color(0.95, 0.95, 1.0))

## Shock Ring: everything around me is hit; more than AOE_TARGET_CAP enemies
## share that many hits' damage.
func _shock_ring(res: Resource) -> void:
	var col := Abilities.color_of(SHOCK_RING_ID)
	var hit := player._enemies_within(float(res.radius))
	var coef := float(res.damage) * Balance.aoe_share(hit.size())
	for e in hit:
		if is_instance_valid(e) and e.is_alive():
			player.deal_damage(e, coef, SHOCK_RING_ID)
	player._ring_effect(float(res.radius), col)
	player._ring_effect(float(res.radius) * 0.6, Color(0.95, 0.95, 1.0))

## Draw the Storm: every enemy around me has to attack me for a moment, and
## for as long as it lasts my parries zap the enemies around me (_storm_zap).
func _draw_the_storm(res: Resource) -> void:
	var col := Abilities.color_of(STORM_ID)
	player.status.apply(player.lightning_melee._melee_buff(STORM_FX, STORM_ID, Balance.DRAW_THE_STORM_TIME + player._talent("lightning_eye_of_the_storm"),   # + Eye of the Storm
		"Each attack you parry zaps the enemies around you."), player)
	for e in player._enemies_within(float(res.radius)):
		player._net_taunt(e, Balance.DRAW_THE_STORM_TAUNT)
		player._ring_effect(0.8, Color(1.0, 0.35, 0.25), e.global_position)
	player._ring_effect(float(res.radius), col)
	player._ring_effect(1.0, Color(0.95, 0.95, 1.0))

## The zap a parry sends out during Draw the Storm (a proc: it feeds nothing else).
func _storm_zap() -> void:
	var hit := player._enemies_within(Balance.DRAW_THE_STORM_ZAP_RADIUS)
	var coef := float(Abilities.EXTRA_HITS[STORM_ID]) * Balance.aoe_share(hit.size()) \
		* (1.0 + player._talent("lightning_eye_of_the_storm", "values2") / 100.0)   # Eye of the Storm
	for e in hit:
		if is_instance_valid(e) and e.is_alive():
			player.deal_damage(e, coef, STORM_ID, true)
	player._ring_effect(Balance.DRAW_THE_STORM_ZAP_RADIUS, Abilities.color_of(STORM_ID))

## Something hit me (_on_hit_taken): an attack I parried opens Return Stroke,
## gives Energy during Humming Blade, brings Crossguard back sooner (Quick
## Wrists) and zaps the enemies around me during Draw the Storm.
func _parry_kit_hit_taken(info: RefCounted) -> void:
	if not info.parried:
		return
	var pd := player.get_node_or_null("/root/PlayerData")
	if pd and pd.has_ability(RETURN_STROKE_ID):
		player.status.apply(player.lightning_melee._melee_buff(RETURN_STROKE_FX, RETURN_STROKE_ID, Balance.RETURN_STROKE_WINDOW,
			"You parried an attack: %s can be used once." % Abilities.ability_name(RETURN_STROKE_ID)), player)
	if player.status.has(HUMMING_FX):
		player._gain("energy", parry_energy(player._talent("lightning_closed_circuit")))   # + Closed Circuit
	var wrists := player._talent("lightning_quick_wrists")
	if wrists > 0.0 and player.cooldowns.has(CROSSGUARD_ID):
		player.cooldowns[CROSSGUARD_ID] = quick_wrists_cooldown(float(player.cooldowns[CROSSGUARD_ID]), wrists)
	if player.status.has(STORM_FX):
		_storm_zap()
	# Earth Return: every parry heals me a little.
	var mend := LightningCasterKit.earth_return_heal(player.max_health, player._talent("lightning_earth_return"))
	if mend > 0 and player.health < player.max_health:
		player._combat().heal(player, player, float(mend), "earth_return", true)
	# Tempo: every parry makes my auto-attacks faster for a while (it stacks).
	var tempo := player._talent("lightning_tempo")
	if tempo > 0.0:
		player.status.apply(_tempo_buff(tempo), player)

const REEL_IN_ID := "reelin"
const RECHARGE_ID := "recharge"
const RESONANCE_RUNE := "resonance"
const TEMPO_FX := "tempo"
## Stat key of attack speed buffs: % faster auto-attacks (Tempo). Not Haste: casts
## and the global cooldown are untouched.
const ATTACK_SPEED := "attack_speed"
var _tempo_fx: Resource

## Where Reel In drags an enemy at `foe` to: `gap` metres from `me` on the line
## between us (it stays where it is if it is already that close). Flat: the
## caller sets the height.
static func reel_in_point(me: Vector3, foe: Vector3, gap: float) -> Vector3:
	var flat := Vector3(foe.x - me.x, 0.0, foe.z - me.z)
	var dist := flat.length()
	if dist <= gap or dist < 0.001:
		return foe
	var p := me + flat / dist * gap
	p.y = foe.y
	return p

## Reel In: a lash drags my target to me (the host moves it) and it has to
## attack me for a moment. Bosses are only made to attack.
func _reel_in() -> void:
	var col := Abilities.color_of(REEL_IN_ID)
	var from := player._muzzle()
	LightningMeleeKit.LASH.spawn(player.get_tree().current_scene, from, player.target.global_position + Vector3(0, 0.3, 0), col, 0.4)
	player._net_fx("lash", from, player.target, {"c": col})
	var gap := Combat.hitbox_radius(player.target) + Combat.hitbox_radius(player) + Balance.REEL_IN_GAP
	var to := reel_in_point(player.global_position, player.target.global_position, gap)
	to.y = player.target.global_position.y + (Combat.feet_y(player) - Combat.feet_y(player.target))   # onto my level
	player.lightning_talents.note_forced(player.target, Balance.REEL_IN_TAUNT)   # Hard Stare
	var net := player._net()
	if net:
		net.pull(player.target, player, to, Balance.REEL_IN_TAUNT)
	elif player.target.has_method("pull_to"):
		player.target.pull_to(player, to, Balance.REEL_IN_TAUNT, Balance.REEL_IN_DRAG_TIME)
	else:
		player._net_taunt(player.target, Balance.REEL_IN_TAUNT)
	player._slash_effect(col)
	player._ring_effect(0.8, Color(1.0, 0.35, 0.25), player.target.global_position)

## Health a Recharge that spent `energy` restores to a character with `max_hp`.
static func recharge_heal(max_hp: int, energy: float) -> int:
	return int(round(float(max_hp) * Balance.RECHARGE_PCT_PER_STEP / 100.0 * maxf(energy, 0.0) / Balance.ENERGY_STEP))

## Recharge: all my Energy becomes health.
func _recharge() -> void:
	var spent := player.lightning_caster._spend_all_energy()
	var amount := recharge_heal(player.max_health, spent)
	if amount > 0:
		player._combat().heal(player, player, float(amount), RECHARGE_ID, true)
	player._ring_effect(1.2, Color(0.45, 1.0, 0.5))
	player._ring_effect(0.8, Abilities.color_of(RECHARGE_ID))

## Energy Return Stroke costs: `base` after a parry (`answered`), RESONANCE_COST
## when the Rune of Resonance lets it be used without one.
static func return_stroke_cost(base: float, answered: bool, resonance: bool) -> float:
	return Balance.RESONANCE_COST if (resonance and not answered) else base

## Can Return Stroke be used: after a parry, or any time with the Rune of Resonance.
static func return_stroke_usable(answered: bool, resonance: bool) -> bool:
	return answered or resonance

## % faster my auto-attacks are from attack speed buffs (Tempo).
func attack_speed_bonus() -> float:
	return player.status.stat_mod(ATTACK_SPEED) if player.status != null else 0.0

## Tempo's buff at `pct` % attack speed per stack (rebuilt when the talent's rank changes).
func _tempo_buff(pct: float) -> Resource:
	if _tempo_fx == null or not is_equal_approx(float(_tempo_fx.stat_modifiers.get(ATTACK_SPEED, 0.0)), pct):
		_tempo_fx = StatusContainer.make_buff(TEMPO_FX, "Tempo", ATTACK_SPEED, pct,
			Balance.TEMPO_TIME, Balance.TEMPO_MAX_STACKS, Abilities.color_of(HUMMING_ID))
		_tempo_fx.tags = PackedStringArray(["Lightning"])
		_tempo_fx.description = "Your auto-attacks are %s%% faster per stack." % Stats.num(pct)
	return _tempo_fx

