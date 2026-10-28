extends "res://scripts/player/player_kit.gd"
class_name FireCasterKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "fire_caster".
# --- Shared: a status effect put on an enemy as a hit -------------------------------

## Put status effect `res` on an enemy as a hit with no damage. It goes through
## the combat pipeline, so in a party it reaches the host (who owns enemy
## effects) exactly like an effect from a real hit. It can't be blocked or crit.
func _apply_effect_hit(e: Node, res: Resource, ability_id: String, tags: PackedStringArray,
		damage_type: String = "fire") -> void:
	if res == null or e == null or not is_instance_valid(e) or not e.is_alive():
		return
	var info := DamageInfo.make(player, e, 0.0, ability_id)
	info.damage_type = damage_type
	info.tags = tags if not tags.is_empty() else PackedStringArray(["Fire", "Spell"])
	info.is_proc = true
	info.can_crit = false
	info.can_block = false
	info.effects.append(res)
	player._combat().deal(info)

# --- Wall of Fire -----------------------------------------------------------------------
# A cast: the wall goes across your target (if you have one in range and in
# sight) or FIRE_WALL_DISTANCE in front of you, side-on to you. Where it goes is
# fixed when the cast starts. The wall itself is scripts/fire_wall.gd.

const FIRE_WALL = preload("res://scripts/fire_wall.gd")
var _wall_yaw := 0.0

func _start_fire_wall() -> void:
	var id := "walloffire"
	if player.casting or not player.is_on_floor():
		return
	if player.cooldown_left(id) > 0.0:
		player._error("%s is not ready yet" % Abilities.ability_name(id))
		return
	if not player.can_afford(id, true):
		return
	var res := Abilities.get_resource(id)
	var fwd := player._flat_forward()
	var centre := player.global_position + fwd * Balance.FIRE_WALL_DISTANCE
	var floor_y := Combat.feet_y(player)
	if player._has_valid_target() and player.can_see(player.target) \
			and player.global_position.distance_to(player.target.global_position) <= float(res.cast_range):
		centre = player.target.global_position
		floor_y = Combat.feet_y(player.target)
	var dir := centre - player.global_position
	dir.y = 0.0
	if dir.length() < 0.5:
		dir = fwd
	_wall_yaw = atan2(-dir.x, -dir.z)   # the wall's length runs across this direction
	player.cast_point = Vector3(centre.x, floor_y, centre.z)
	player._begin_spell(id, str(res.display_name), float(res.cast_time))

func _raise_fire_wall() -> void:
	var res := Abilities.get_resource("walloffire")
	player.cooldowns["walloffire"] = float(res.cooldown)
	var wall := Node3D.new()
	wall.set_script(FIRE_WALL)
	wall.length = float(res.radius) * 2.0
	wall.depth = Balance.FIRE_WALL_DEPTH
	wall.duration = Balance.FIRE_WALL_TIME
	wall.tick = maxf(Balance.FIRE_WALL_TICK / player.haste_mult(), 0.1)
	wall.damage = float(res.damage)
	wall.tags = res.tags
	wall.source = player
	player.get_tree().current_scene.add_child(wall)
	wall.global_position = player.cast_point
	wall.rotation.y = _wall_yaw
	player._net_fx("firewall", player.cast_point, null, {"yaw": _wall_yaw, "len": wall.length, "depth": wall.depth, "time": wall.duration})

# --- Immolate: recasting it on a target that has yours spreads it ---------------------

func _immolate_spread(tgt: Node3D) -> void:
	var st: Node = tgt.get_node_or_null("Status") if is_instance_valid(tgt) else null
	if st == null or not st.has_from("immolate", player):
		return
	# The closest enemies around the target; ones without my Immolate first.
	var fresh: Array = []
	var burning: Array = []
	for e in player._enemies_near(tgt.global_position, Balance.IMMOLATE_SPREAD_RADIUS, tgt):
		var est: Node = e.get_node_or_null("Status")
		if est and est.has_from("immolate", player):
			burning.append(e)
		else:
			fresh.append(e)
	for e in (fresh + burning).slice(0, Balance.IMMOLATE_SPREAD_TARGETS):
		player.deal_damage(e, 0.0, "immolate", true)   # no damage: just its on-hit effect
		player._ring_effect(0.7, Abilities.color_of("immolate"), e.global_position)

# --- Hair Trigger rune: Vent Flames has charges ---------------------------------------
# Without the rune Vent Flames uses its plain cooldown. With it there are
# HAIR_TRIGGER_CHARGES charges, recharging one after the other; the button's
# cooldown only shows while no charge is left.

const VENT_ID := "ventflames"
var _vent_charges := Balance.HAIR_TRIGGER_CHARGES
var _vent_recharge := 0.0   # seconds until the next charge (0 = all charges ready)
var _vent_cd := 10.0

func _vent_max() -> int:
	return Balance.HAIR_TRIGGER_CHARGES if player.frost_melee._has_rune("hair_trigger") else 1

func _vent_charge_used(cd: float) -> void:
	if _vent_max() <= 1:
		return
	_vent_cd = cd
	_vent_charges = maxi(mini(_vent_charges, _vent_max()) - 1, 0)
	if _vent_recharge <= 0.0:
		_vent_recharge = cd
	if _vent_charges > 0:
		player.cooldowns.erase(VENT_ID)
	else:
		player.cooldowns[VENT_ID] = _vent_recharge

func _tick_vent_charges(delta: float) -> void:
	if _vent_recharge <= 0.0:
		return
	_vent_recharge -= delta
	if _vent_recharge <= 0.0:
		_vent_charges = mini(_vent_charges + 1, maxi(_vent_max(), 1))
		_vent_recharge = _vent_cd if _vent_charges < _vent_max() else 0.0

## Take `seconds` off Vent Flames' cooldown (with Hair Trigger: off the charge
## that is recharging).
func _vent_reduce(seconds: float) -> void:
	if seconds <= 0.0:
		return
	if _vent_max() > 1:
		if _vent_recharge > 0.0:
			_vent_recharge = maxf(_vent_recharge - seconds, 0.01)
			if player.cooldowns.has(VENT_ID):
				player.cooldowns[VENT_ID] = _vent_recharge
	elif player.cooldowns.has(VENT_ID):
		player.cooldowns[VENT_ID] = vent_after_cut(float(player.cooldowns[VENT_ID]), seconds)

## Cooldown left after Pressure Valve takes `cut` seconds off `left`.
static func vent_after_cut(left: float, cut: float) -> float:
	return maxf(left - cut, 0.0)

var _valve_last := ""   # "<ability>@<frame>" of the last spell that fed Pressure Valve

## Pressure Valve talent: a Fire spell of mine just failed to crit. Once per
## use, however many enemies it hit (an Ember Volley counts once); not procs.
func _pressure_valve(info: RefCounted) -> void:
	var cut := player._talent("fire_pressure_valve")
	if cut <= 0.0 or info.is_proc:
		return
	var key := "%s@%d" % [str(info.ability_id), Engine.get_process_frames()]
	if str(info.ability_id) == "embervolley":
		key = "embervolley#%d" % _volley_serial
	if key == _valve_last:
		return
	_valve_last = key
	_vent_reduce(cut)

## Is one of my burns (Balance.FIRE_BURNS: Immolate, Burning) on `enemy`? (Warm Blood)
## Does `enemy` carry my Blaze (Immolate)?
func _my_blaze_on(enemy: Variant) -> bool:   # untyped: may be a freed enemy
	if enemy == null or not is_instance_valid(enemy) or not (enemy is Node):
		return false
	var st: Node = enemy.get_node_or_null("Status")
	return st != null and st.has_from("immolate", player)

func _my_burn_on(enemy: Variant) -> bool:   # untyped: may be a freed enemy
	if enemy == null or not is_instance_valid(enemy) or not (enemy is Node):
		return false
	var st: Node = enemy.get_node_or_null("Status")
	if st == null:
		return false
	for fx_id in Balance.FIRE_BURNS:
		if st.has_from(str(fx_id), player):
			return true
	return false

## Number shown on an action-bar button with charges ("" = none).
func charges_text(id: String) -> String:
	if id == WeaverKit.MOSSBACK_ID or id == WeaverKit.VIPERS_ID:
		return str(player.weaver._mulch.size())   # Nature caster: my patches of mulch
	if id == LightstringKit.PRISM_ARROW_ID:
		return str(player.lightstring._prism_arrows)   # Holy archer: Prism Arrow's charges
	if id == "iceshards":
		return str(int(player.ice_shards_kit.ice_shard_charges))
	if id == VENT_ID and _vent_max() > 1:
		return str(clampi(_vent_charges, 0, _vent_max()))
	if FireMeleeKit.heat_needed(id) > 0:
		return str(player.fire_melee.heat_stacks())   # Quench / Flare: the Heat you hold
	if id == ArcaneTankKit.FULL_SET_ID or id == ArcaneTankKit.TRADE_PLACES_ID or (id == ArcaneTankKit.DECOY_ID and player.arcane_tank.decoy_needs_reflection()):
		return str(player.arcane_tank.reflections())   # the Reflections you have (to fill up, or to spend)
	if id == ArcaneMeleeKit.ENCORE_ID:
		return str(player.arcane_melee.traces())   # the Traces it would replay
	if id == StringsKit.STRING_ID:
		return str(player.strings.string_charges())   # the Strings in your hand
	if player.hymns.verses_text(id) != "":
		return player.hymns.verses_text(id)   # Holy healer: the Verses you hold
	if id == ArcaneCasterKit.CONVERGENCE_ID:
		# Convergence: the Arcane spells on cooldown that would count right now.
		var running := mini(player.arcane_caster.arcane_cooldowns(ArcaneCasterKit.CONVERGENCE_ID), Balance.CONVERGENCE_MAX)
		return str(running) if running > 0 else ""
	return ""

# --- Ember Volley (Fire channel) ------------------------------------------------------
# A channel that launches EMBER_VOLLEY_HITS embers, spread evenly over it (so
# Haste makes them come faster). Each ember is its own hit with its own crit
# roll. Paid for, and put on cooldown, when the channel starts.

var _volley_left := 0      # embers still to launch this channel
var _volley_dmg := 0.0
var _volley_serial := 0    # counts channels (Cool Head gives one stack per channel)

func _start_ember_volley() -> void:
	var id := "embervolley"
	if player.casting or not player.is_on_floor():
		return
	if player.cooldown_left(id) > 0.0:
		player._error("%s is not ready yet" % Abilities.ability_name(id))
		return
	if not player._has_valid_target():
		player._error("No target")
		return
	var res := Abilities.get_resource(id)
	if res.cast_range > 0.0 and player.global_position.distance_to(player.target.global_position) > res.cast_range:
		player._error("Target out of range")
		return
	var sight_err := player._target_error(player.target)
	if sight_err != "":
		player._error(sight_err)
		return
	var echo := player.echoing()   # a free cast (Rune of the Wild Page) never channels: a burst
	var instant := echo or player.fire_cooldowns.concentrated_fire_ready(id)
	if not player._pay(id):
		return
	player.cooldowns[id] = float(res.cooldown)
	_volley_dmg = float(res.damage)
	_volley_serial += 1
	if instant:
		# Concentrated Fire: no channel, the whole volley goes out in a quick burst.
		player.status.spend_stacks(FireCooldownsKit.CONC_ID)
		var tgt := player.target
		for i in Balance.EMBER_VOLLEY_HITS:
			player.echo_timer(Balance.EMBER_VOLLEY_BURST_GAP * i).timeout.connect(func():
				if player.is_alive() and is_instance_valid(tgt) and tgt.is_alive():
					_launch_ember(tgt))   # (a free cast's burst: its timers keep it an echo)
		player._bus().cast_finished.emit(id)   # an instant: starts the global cooldown like one
		return
	player._begin_spell(id, str(res.display_name), float(res.cast_time), true)
	_volley_left = Balance.EMBER_VOLLEY_HITS if player.casting and player.current_spell == id else 0

## One ember at `tgt`, plus one at each extra enemy near it (Scattered Embers talent).
func _launch_ember(tgt: Node3D) -> void:
	var scene := player.get_tree().current_scene
	Player.FROST_BOLT.spawn(scene, player._muzzle(), tgt, player, false, "embervolley", _volley_dmg)
	var extra := int(player._talent("fire_volley_targets"))
	if extra <= 0:
		return
	var others := player._enemies_near(tgt.global_position, Balance.EMBER_VOLLEY_SPLIT_RADIUS, tgt).filter(
		func(e): return player.can_see(e))
	for e in others.slice(0, extra):
		Player.FROST_BOLT.spawn(scene, player._muzzle(), e, player, false, "embervolley", _volley_dmg)

## Launch every ember that is due by now (`final` = all that are left).
func _ember_volley_tick(final: bool = false) -> void:
	if _volley_left <= 0:
		return
	var hits := Balance.EMBER_VOLLEY_HITS
	var due := hits
	if not final:
		var every := maxf(player.cast_duration / hits, 0.01)
		due = mini(int(floor((player.cast_duration - maxf(player.cast_timer, 0.0)) / every + 0.0001)), hits)
	while hits - _volley_left < due:
		_volley_left -= 1
		if player._has_valid_target():
			_launch_ember(player.target)

