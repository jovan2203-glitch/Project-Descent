extends "res://scripts/player/player_kit.gd"
class_name FireCooldownsKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "fire_cooldowns".
# --- Cinderwing: the phoenix (Fire healing cooldown) -----------------------------------------
# A phoenix follows me and, every PHOENIX_INTERVAL seconds, casts a heal on the
# ally with the lowest health within PHOENIX_RANGE (me included): PHOENIX_CASTS
# casts, then it leaves. The bird is scripts/phoenix.gd; it calls phoenix_cast().
# The heals are mine (my Spell Power, my threat, my line in the meter).

const PHOENIX_ID := "cinderwing"
const PHOENIX = preload("res://scripts/phoenix.gd")
var _phoenix: Node3D

func _summon_phoenix() -> void:
	if is_instance_valid(_phoenix):
		_phoenix.vanish()
	var time: float = PHOENIX.life_time(Balance.PHOENIX_CASTS, Balance.PHOENIX_INTERVAL)
	_phoenix = PHOENIX.spawn(player.get_tree().current_scene, player, Balance.PHOENIX_CASTS, Balance.PHOENIX_INTERVAL)
	player._net_fx("phoenix", player.global_position, null, {"time": time})   # the party sees the bird; the heals come from here
	var fx := StatusContainer.make_buff(PHOENIX_ID, "Cinderwing", PHOENIX_ID, 0.0, time, 1, Abilities.color_of(PHOENIX_ID))
	fx.stat_modifiers = {}
	fx.description = "A phoenix heals the ally with the lowest health near you every %s sec." % Abilities.secs(Balance.PHOENIX_INTERVAL)
	player.status.apply(fx, player)
	player._ring_effect(1.2, Abilities.color_of(PHOENIX_ID))

## The phoenix casts: one heal on the ally with the lowest health in range.
func phoenix_cast() -> void:
	if player.is_dead():
		return
	var tgt := player.frost_runes._lowest_health_ally(Balance.PHOENIX_RANGE)
	if tgt == null:
		return
	_heal_someone(tgt, float(Abilities.HEALS[PHOENIX_ID]), PHOENIX_ID)
	if tgt is Node3D:
		player._ring_effect(0.8, Abilities.color_of(PHOENIX_ID), (tgt as Node3D).global_position)

## Heal `tgt` - me, a party member or a friendly dummy - for coefficient `coef`,
## as `id` in the log and the meter. A party member is healed on their own machine.
func _heal_someone(tgt: Node, coef: float, id: String) -> void:
	if tgt == null or not is_instance_valid(tgt):
		return
	coef *= player.strings._others_heal_mult(tgt)   # Many Hands
	if tgt == player:
		player.heal(coef, id)
	elif tgt.is_in_group("friendly"):
		player._combat().heal(player, tgt, coef, id)   # a local friendly (training ally dummy)
	else:
		var amount: int = player._combat().heal_amount(player, coef, id)
		player._combat().float_text(tgt, "+%d" % amount, Color(0.45, 1.0, 0.45), false)
		player._bus().heal_done.emit(player, tgt, amount, amount, id, false)   # Details meter
		if player._net():
			player._net().heal_ally(tgt, player, amount)   # their machine heals them (+ threat)

## Me + party members + friendly dummies within `radius` metres of me (alive ones).
func _allies_within(radius: float) -> Array:
	var out: Array = [player] if player.is_alive() else []
	for a in player.get_tree().get_nodes_in_group("remote_player") + player.get_tree().get_nodes_in_group("friendly"):
		if a is Node3D and a.is_alive() and player._flat_dist_to(a.global_position) <= radius:
			out.append(a)
	return out

## Index of the smallest health share in `shares` (the first one wins a tie), -1 if empty.
static func lowest_share(shares: Array) -> int:
	var best := -1
	var best_f := INF
	for i in shares.size():
		if float(shares[i]) < best_f:
			best_f = float(shares[i])
			best = i
	return best

# --- Deep Crucible (Fire talent): a wider Crucible that stands longer ----------------------------

func crucible_radius() -> float:
	# Deep Crucible makes it 1 / 2 m WIDER, so half of that goes on the radius.
	return float(Abilities.get_resource(CRUCIBLE_ID).radius) + Abilities.radius_bonus(CRUCIBLE_ID)

func crucible_duration() -> float:
	return Balance.CRUCIBLE_TIME + player._talent("fire_deep_crucible", "values2")

## Health Slag Mending restores when `stacks` of Slag shatter, at `pct` % of max health per stack.
static func slag_mending_heal(max_hp: int, stacks: int, pct: float) -> int:
	return int(round(float(max_hp) * pct / 100.0 * maxi(stacks, 0)))

## Something hit me (or I blocked it).
func _on_hit_taken(info: RefCounted) -> void:
	if not is_same(info.target, player) or player.status == null or player.is_dead():
		return
	player.strings._crossed_taken(info)   # Crossed Strings: what it spared me goes to the enemy at the other end
	player.hymns._vigil_taken(info)     # Watchful: a big hit while I stand in a healer's Vigil
	player.shepherd._owl_taken(info)       # a Nature healer's Owl watching over me dives
	player.colossus._colossus_hit_taken(info)   # Nature tank: hits on my Giant's Hands give Sap
	player.glacier._glacier_hit_taken(info)   # Frost tank: hits that break my Ice Layers
	# Heat Sink: what it spared me is stored for the burst.
	if _heat_on and player.status.has(HEAT_SINK_ID) and not info.blocked and int(info.amount) > 0:
		_heat_stored += heat_sink_stored(float(info.amount), float(info.bonus_pct), Balance.HEAT_SINK_PCT)
	# Winter Hide: an enemy whose melee attack reaches me (hit or blocked) is Chilled.
	if player.status.has(FrostMoreKit.WINTER_HIDE_ID) and FrostMoreKit.winter_hide_chills(info.tags, info.is_dot):
		player.frost_more._chill(info.source, FrostMoreKit.WINTER_HIDE_ID)
	# Cinder Guard: a blocked attack burns the attacker and keeps Slag Skin going.
	if info.blocked and not info.is_dot and player.status.has(FireTankKit.CINDER_GUARD_ID):
		var foe: Variant = info.source
		if foe != null and is_instance_valid(foe) and foe is Node and foe.is_in_group("enemies") and foe.is_alive():
			player.deal_damage(foe, FireTankKit.block_burn(float(Abilities.get_resource("cinderguard").damage), player._talent("fire_hot_iron")),
				"cinderguard", true)
		if player.status.has(FireTankKit.SLAG_ID):
			player.status.set_remaining(FireTankKit.SLAG_ID, minf(player.status.remaining_of(FireTankKit.SLAG_ID) + Balance.CINDER_GUARD_EXTEND, Balance.SLAG_SKIN_TIME))
			player.fire_tank._sync_slag()
	player.lightning_melee._melee_kit_hit_taken(info)   # Reflex Arc, Faraday Guard, Back-Current
	player.lightning_tank._parry_kit_hit_taken(info)   # Return Stroke, Humming Blade, Quick Wrists, Draw the Storm
	player.arcane_tank._reflection_kit_hit_taken(info)   # a dodge (or Stand-In) shatters a Reflection
	player.censer._censer_hit_taken(info)   # Incense from hits and blocks; Unfallen counts the damage
	player.arcane_open._mirror_finish(info)   # Mirror Finish: what I dodge, parry or block hurts the attacker
	player.fire_lightning_talents._tempered(info)   # Tempered: a block gives Armor for a while
	player.shadow_talents._spite_on_hit_taken(info)   # Spite: taking damage boosts my next spell or ability
	player.holy_talents._penitent_hit(info)   # Penitent: a big hit makes my next heal on myself stronger

# --- Heat Sink ------------------------------------------------------------------------------
# For HEAT_SINK_TIME seconds HEAT_SINK_PCT% of the damage I take is stored instead
# (_on_damage_modify takes it off the hit, _on_hit_taken counts it). When the buff
# runs out the heat bursts around me: the ability's damage, growing with what was
# stored up to (1 + HEAT_SINK_BONUS) times it at HEAT_SINK_FULL_AT% of my health.

const HEAT_SINK_ID := "heat_sink"
var _heat_on := false
var _heat_stored := 0.0

## Damage Heat Sink kept off me on a hit that still dealt `amount`, when all the
## hit's modifiers (Heat Sink's -`pct` included) added up to `bonus_pct`.
static func heat_sink_stored(amount: float, bonus_pct: float, pct: float) -> float:
	var mult := 1.0 + bonus_pct / 100.0
	if mult <= 0.0 or pct <= 0.0:
		return 0.0
	return amount * (pct / 100.0) / mult

## Coefficient of the burst with `stored` damage soaked, at `max_hp` max health.
static func heat_sink_coef(base: float, stored: float, max_hp: float) -> float:
	var full := maxf(max_hp * Balance.HEAT_SINK_FULL_AT / 100.0, 1.0)
	return base * (1.0 + Balance.HEAT_SINK_BONUS * clampf(stored / full, 0.0, 1.0))

func _start_heat_sink() -> void:
	_heat_stored = 0.0
	_heat_on = true
	var fx := StatusContainer.make_buff(HEAT_SINK_ID, "Heat Sink", HEAT_SINK_ID, 0.0,
		Balance.HEAT_SINK_TIME, 1, Abilities.color_of("heatsink"))
	fx.stat_modifiers = {}
	fx.description = "You take %d%% less damage; it is stored and bursts out as Fire damage when this ends." % int(Balance.HEAT_SINK_PCT)
	player.status.apply(fx, player)
	player._ring_effect(1.2, Abilities.color_of("heatsink"))

## Heat Sink just ran out: let the heat go.
func _heat_sink_check() -> void:
	if not _heat_on or player.status.has(HEAT_SINK_ID):
		return
	_heat_on = false
	if player.is_dead():
		return
	var res := Abilities.get_resource("heatsink")
	var hit := player._enemies_within(float(res.radius))
	var coef := heat_sink_coef(float(res.damage), _heat_stored, float(player.max_health)) * Balance.aoe_share(hit.size())
	_heat_stored = 0.0
	for e in hit:
		player.deal_damage(e, coef, "heatsink", true)
	player._ring_effect(float(res.radius), Abilities.color_of("heatsink"))
	player._ring_effect(float(res.radius) * 0.6, Color(1.0, 0.9, 0.4))

# --- Cinder Step ----------------------------------------------------------------------------
# A dash straight ahead (like Blink it stops short of walls) that leaves a line
# of cinders, and lets the next Fire spell with a cast time be cast on the move.

const CINDER_ID := "cinder_step"
var _cinder_cast := false   # the current cast may be finished while moving
var _cinder_fx: Resource

## Can Cinder Step's buff carry this cast? Fire spells with a cast time; not channels.
static func cinder_step_applies(tags: PackedStringArray, cast_time: float, channel: bool) -> bool:
	return not channel and cast_time > 0.0 and tags.has("Fire") and tags.has("Spell")

func cinder_step_ready(id: String) -> bool:
	if player.status == null or not player.status.has(CINDER_ID):
		return false
	var res := Abilities.get_resource(id)
	return res != null and cinder_step_applies(res.tags, float(res.cast_time), int(res.cast_type) == 2)

func _cinder_step(res: Resource) -> void:
	var from := player.global_position
	var dir := player._flat_forward()
	var dist := player._dash_distance(Balance.CINDER_STEP_DISTANCE)
	player.global_position += dir * dist
	player._ring_effect(0.8, Abilities.color_of("cinderstep"), from)
	player._ring_effect(0.8, Abilities.color_of("cinderstep"))
	if dist > 0.5:
		var mid := from + dir * dist * 0.5
		# (A fire strip's length runs across its facing, so it is turned a quarter.)
		player.fire_tank._fire_patch(Vector3(mid.x, Combat.feet_y(player), mid.z), atan2(-dir.x, -dir.z) + PI / 2.0, dist,
			Balance.CINDER_STEP_LINE_DEPTH, Balance.CINDER_STEP_LINE_TIME, Balance.CINDER_STEP_TICK,
			float(res.damage), res.tags, "cinderstep")
	if _cinder_fx == null:
		_cinder_fx = StatusContainer.make_buff(CINDER_ID, "Cinder Step", CINDER_ID, 0.0,
			Balance.CINDER_STEP_BUFF_TIME, 1, Abilities.color_of("cinderstep"))
		_cinder_fx.stat_modifiers = {}
		_cinder_fx.description = "Your next Fire spell with a cast time can be cast while moving."
	player.status.apply(_cinder_fx, player)

# --- Crucible -------------------------------------------------------------------------------
# A circle placed on the ground (like Blizzard) for CRUCIBLE_TIME seconds: enemies
# in it take more periodic Fire damage (_on_damage_modify). While mine stands,
# casting it again is instant and free and moves it (it keeps the time it had
# left, unless Balance.CRUCIBLE_MOVE_REFRESHES).

const CRUCIBLE_ID := "crucible"
const CRUCIBLE = preload("res://scripts/crucible.gd")
var _crucible: Node3D   # my Crucible on the ground (null / gone = none)

func _crucible_standing() -> bool:
	return is_instance_valid(_crucible) and _crucible.time_left() > 0.0

## Seconds a Crucible placed now lasts: a fresh one the full time, a moved one
## what the old one had left (or the full time again if moving refreshes it).
static func crucible_time(moving: bool, left: float, full: float, move_refreshes: bool) -> float:
	return left if moving and not move_refreshes else full

func _start_crucible(point: Vector3) -> void:
	if player.casting or not player.is_on_floor():
		return
	player.cast_point = point
	if _crucible_standing():
		_place_crucible(true)   # moving it: instant and free
		if Player.on_gcd(CRUCIBLE_ID):
			player._start_gcd()
		player._bus().cast_finished.emit(CRUCIBLE_ID)
		return
	if not player.can_afford(CRUCIBLE_ID, true):
		return
	var res := Abilities.get_resource(CRUCIBLE_ID)
	player._begin_spell(CRUCIBLE_ID, str(res.display_name), float(res.cast_time))

func _place_crucible(moving: bool) -> void:
	var res := Abilities.get_resource(CRUCIBLE_ID)
	var standing := _crucible_standing()
	var time := crucible_time(moving and standing, _crucible.time_left() if standing else 0.0,
		crucible_duration(), Balance.CRUCIBLE_MOVE_REFRESHES)
	var radius := crucible_radius()   # Deep Crucible: wider, and it stands longer
	_crucible = CRUCIBLE.spawn(player.get_tree().current_scene, player.cast_point, radius, time, "me")
	player._net_fx("crucible", player.cast_point, null, {"r": radius, "time": time})
	player._ring_effect(radius, Abilities.color_of(CRUCIBLE_ID), player.cast_point)

# --- Cool Head (Fire ability) and Concentrated Fire ---------------------------------------
# Cool Head (Balance.COOL_HEAD_TIME): your Fire spells and abilities can't crit
# (adjust_crit), and each one that deals damage gives a stack of Concentrated
# Fire: once per use, however many enemies it hits; ticks and procs don't count.
# When Cool Head ends the stacks stay for CONCENTRATED_FIRE_WINDOW seconds and
# each one makes a Fire spell / ability with a cast time instant (_begin_spell).

const COOL_HEAD_ID := "cool_head"
const CONC_ID := "concentrated_fire"
var _cool_head_on := false       # Cool Head is running (stacks build; no instant casts yet)
var _conc_cast := false          # the current cast is an instant Concentrated Fire one
var _conc_fx: Resource
var _conc_last := ""             # "<ability>@<frame>" of the last hit that gave a stack

## A Fire spell or ability (by its tags)?
static func is_fire_action(tags: PackedStringArray) -> bool:
	return tags.has("Fire") and (tags.has("Spell") or tags.has("Ability"))

func cool_head_active() -> bool:
	return player.status != null and player.status.has(COOL_HEAD_ID)

func _start_cool_head() -> void:
	player.status.remove(CONC_ID)
	var fx := StatusContainer.make_buff(COOL_HEAD_ID, "Cool Head", COOL_HEAD_ID, 0.0,
		Balance.COOL_HEAD_TIME, 1, Color(0.65, 0.88, 1.0))
	fx.stat_modifiers = {}
	fx.description = "Your Fire spells and abilities cannot critically strike. Each one that deals damage grants a stack of Concentrated Fire."
	_cool_head_on = true
	player.status.apply(fx, player)
	player._ring_effect(1.2, Color(0.65, 0.88, 1.0))

## A hit of mine landed: during Cool Head, a Fire spell / ability gives a stack.
func _cool_head_on_hit(info: RefCounted, tags: PackedStringArray) -> void:
	if not cool_head_active() or info.is_proc or int(info.amount) <= 0 or not is_fire_action(tags):
		return
	var key := "%s@%d" % [str(info.ability_id), Engine.get_process_frames()]
	if str(info.ability_id) == "embervolley":
		key = "embervolley#%d" % player.fire_caster._volley_serial   # one stack per channel, not per ember
	if key == _conc_last:
		return   # the same use hitting another enemy
	_conc_last = key
	if _conc_fx == null:
		_conc_fx = StatusContainer.make_buff(CONC_ID, "Concentrated Fire", CONC_ID, 0.0,
			Balance.COOL_HEAD_TIME + Balance.CONCENTRATED_FIRE_WINDOW, Balance.CONCENTRATED_FIRE_MAX, Color(1.0, 0.6, 0.2))
		_conc_fx.stat_modifiers = {}
		_conc_fx.description = "When Cool Head ends, your next Fire spells and abilities with a cast time are instant: one cast per stack."
	player.status.apply(_conc_fx, player)
	# The stacks always run out CONCENTRATED_FIRE_WINDOW seconds after Cool Head does.
	player.status.set_remaining(CONC_ID, player.status.remaining_of(COOL_HEAD_ID) + Balance.CONCENTRATED_FIRE_WINDOW)

## Cool Head just ran out: the Concentrated Fire window starts.
func _cool_head_check() -> void:
	if _cool_head_on and not cool_head_active():
		_cool_head_on = false
		player.status.set_remaining(CONC_ID, Balance.CONCENTRATED_FIRE_WINDOW)

## Would casting `id` right now be instant from Concentrated Fire?
func concentrated_fire_ready(id: String) -> bool:
	if player.status == null or cool_head_active() or not player.status.has(CONC_ID):
		return false
	var res := Abilities.get_resource(id)
	# (Ember Volley counts too: its whole volley goes out at once, see _start_ember_volley.)
	return res != null and concentrated_applies(res.tags, float(res.cast_time), player.frost_melee._has_rune("level_head"))

## Can Concentrated Fire make this instant? Fire spells and abilities with a
## cast time; with the Rune of the Level Head (`any_school`), spells of any school.
static func concentrated_applies(tags: PackedStringArray, cast_time: float, any_school: bool) -> bool:
	if cast_time <= 0.0:
		return false
	return is_fire_action(tags) or (any_school and tags.has("Spell"))

