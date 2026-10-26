extends "res://scripts/player/player_kit.gd"
class_name FireBowKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "fire_bow".
# --- Fire bow: Pitch and its Ignites ------------------------------------------------------
# Pitch is my own layered coat on a target (data/effects/pitched.tres, one per
# archer, up to PITCH_MAX_LAYERS). While it is there MY Burning and Blaze on that
# target tick faster, more for each layer: the StatusContainer asks
# dot_speed_mult() before every tick. Own only.
# Each arrow of mine that does not crit (abilities and auto-shots) adds a layer;
# Pitch Arrow adds more. An arrow crit on a coated target Ignites the Pitch: Fire
# damage per layer to it and everything around it, my Burning on every enemy hit
# that has none, and the layers are gone. Touch Off Ignites on purpose.
# Cinder Rain is aimed on the ground like Blizzard but is instant: the volley
# lands where you click (scripts/cinder_rain.gd); its ticks coat (at most a layer
# a second per enemy) and its crits Ignite.

const PITCH_FX_ID := "pitched"
const CINDER_RAIN_ID := "cinderrain"
const COAL_SHOT_ID := "coalshot"
const TOUCH_OFF_ID := "touchoff"
const BRUSHFIRE_ID := "brushfire"
const IGNITE_ID := "pitch_ignite"   # meter / log id of an Ignite
const HOT_SHAFTS_ID := "hot_shafts"   # meter / log id of the Hot Shafts talent's Fire damage
const BOW_IDS := [TOUCH_OFF_ID, BRUSHFIRE_ID]
const CINDER_RAIN = preload("res://scripts/cinder_rain.gd")
const PITCH_FX = preload("res://data/effects/pitched.tres")

var _rain_coat_at := {}   # enemy instance id -> when Cinder Rain last coated it

## How much faster effect `effect_id` ticks on a target with `layers` of my Pitch
## (`extra_pct` per layer on top: Sticky Pitch).
static func pitch_speed(effect_id: String, layers: int, extra_pct: float = 0.0) -> float:
	if layers > 0 and Balance.PITCH_EFFECTS.has(effect_id):
		return 1.0 + (Balance.PITCH_LAYER_SPEED_PCT + extra_pct) / 100.0 * mini(layers, Balance.PITCH_MAX_LAYERS)
	return 1.0

## Damage coefficient of an Ignite of `layers` layers, before it is split; `bonus_pct` = Touch Off.
static func ignite_coef(layers: int, bonus_pct: float = 0.0) -> float:
	return Balance.PITCH_IGNITE_PER_LAYER * maxi(layers, 0) * (1.0 + bonus_pct / 100.0)

## Layers an arrow of `id` adds when it doesn't crit (Brushfire: auto-shots add
## more; `double` = Double Coat's for Pitch Arrow).
static func layers_from(id: String, brushfire: bool, double: int = 0) -> int:
	match id:
		"pitcharrow":
			return Balance.PITCH_ARROW_LAYERS + double
		"auto_ranged":
			return Balance.BRUSHFIRE_LAYERS if brushfire else 1
		TOUCH_OFF_ID:
			return 0
	return 1

## My layers of Pitch on `tgt`.
func layers_on(tgt: Node) -> int:
	var st: Node = tgt.get_node_or_null("Status") if tgt != null and is_instance_valid(tgt) else null
	return int(st.stacks_from(PITCH_FX_ID, player)) if st != null else 0

## The StatusContainer asks before every tick of one of MY damage-over-time effects.
func dot_speed_mult(tgt: Node, res: Resource) -> float:
	var id := str(res.id)
	var wasting := ShadowTalentsKit.dot_speed_with(1.0, player._talent("shadow_wasting"))   # Wasting: all of my damage over time
	if not Balance.PITCH_EFFECTS.has(id) or tgt == null or not is_instance_valid(tgt):
		return wasting
	return pitch_speed(id, layers_on(tgt), player._talent("fire_sticky_pitch")) * wasting   # + Sticky Pitch

## Coat `foe` in `n` more layers of my Pitch (through the combat system, so the
## host applies it in a party).
func coat(foe: Node, n: int) -> void:
	if n <= 0 or foe == null or not is_instance_valid(foe) or not foe.is_in_group("enemies") or not foe.is_alive():
		return
	for i in n:
		var info := DamageInfo.make(player, foe, 0.0, PITCH_FX_ID)
		info.tags = PackedStringArray(["Fire", "Ranged"])
		info.damage_type = "fire"
		info.can_block = false
		info.can_crit = false
		info.add_power = false
		info.is_proc = true
		info.effects.append(PITCH_FX)
		player._combat().deal(info)

## Put my Burning on `e` (no damage: Flaming Arrow's on-hit effect).
func _burn(e: Node) -> void:
	if is_instance_valid(e) and e.is_alive():
		player.deal_damage(e, 0.0, "flamingarrow", true)

## Ignite my Pitch on `tgt`: Fire damage per layer to it and every enemy around
## it (split past AOE_TARGET_CAP), my Burning on every enemy hit that has none,
## and the layers are gone. Returns the layers it used.
## Spreading Fire: it reaches further. Ember Bed: it may leave a layer on each
## enemy hit. Kindle Pack: hitting enough coats the target again. Fuel Run: Energy.
func ignite(tgt: Node, bonus_pct: float = 0.0) -> int:
	var layers := layers_on(tgt)
	if layers <= 0:
		return 0
	var net := player._net()
	if net:
		net.remove_effect(tgt, player, PITCH_FX_ID)   # the host owns enemy effects in a party
	else:
		tgt.get_node("Status").remove_from(PITCH_FX_ID, player)
	var at: Vector3 = (tgt as Node3D).global_position
	var reach := Balance.PITCH_IGNITE_RADIUS + player._talent("fire_spreading_fire")   # + Spreading Fire
	var hit: Array = [tgt] + player._enemies_near(at, reach, tgt)
	var coef := ignite_coef(layers, bonus_pct) * Balance.aoe_share(hit.size())
	var bed := player._talent("fire_ember_bed")
	for e in hit:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var est: Node = e.get_node_or_null("Status")
		var burning: bool = est != null and est.has_from("burning", player)
		# (A proc: it never coats, Ignites again or feeds hit-counting runes.)
		var info := DamageInfo.make(player, e, coef, IGNITE_ID)
		info.tags = PackedStringArray(["Ability", "Fire", "Ranged", "AoE"])
		info.damage_type = "fire"
		info.is_proc = true
		player._combat().deal(info)
		if not burning:
			_burn(e)
		if bed > 0.0 and randf() * 100.0 < bed:
			coat(e, 1)   # Ember Bed
	if hit.size() >= Balance.KINDLE_PACK_HITS:
		coat(tgt, int(round(player._talent("fire_kindle_pack"))))   # Kindle Pack
	var fuel := player._talent("fire_fuel_run")
	if fuel > 0.0:
		player._gain("energy", fuel)   # Fuel Run
	player._ring_effect(reach, Abilities.color_of("pitcharrow"), at)
	player._ring_effect(reach * 0.5, Color(1.0, 0.85, 0.4), at)
	return layers

## Hot Shafts: an auto-shot on a coated target also deals Fire damage, a share of
## the shot (its own line). A proc: it coats nothing and feeds nothing else.
func _hot_shaft(info: RefCounted) -> void:
	var pct := player._talent("fire_hot_shafts")
	if pct <= 0.0 or not info.target.is_alive():
		return
	var extra := DamageInfo.make(player, info.target, 1.0, HOT_SHAFTS_ID)
	extra.unit = float(info.amount) * pct / 100.0
	extra.exact = true
	extra.add_power = false
	extra.can_crit = false
	extra.can_block = false
	extra.is_proc = true
	extra.damage_type = "fire"
	extra.tags = PackedStringArray(["Fire", "Ranged"])
	player._combat().deal(extra)

## A Pitch and Cinder ability on my action bar: only then do my arrows coat and
## Ignite (other archers' arrows and auto-shots never do).
func _plays_pitch() -> bool:
	var pd := player.get_node_or_null("/root/PlayerData")
	if pd == null:
		return false
	for slot_id in pd.action_bar:
		for id in player.bar_abilities(slot_id):
			if Abilities.spec_of(id) == "Pitch and Cinder":
				return true
	return false

## A hit of mine landed: my arrows coat (or, on a crit, Ignite); Cinder Rain's
## ticks too, at most a layer a second per enemy. Brushfire: auto-shots Burn.
func _pitch_on_hit(info: RefCounted) -> void:
	if not is_same(info.source, player) or info.avoided() or info.is_proc or int(info.amount) <= 0:
		return
	var tgt: Variant = info.target
	if tgt == null or not is_instance_valid(tgt) or not (tgt is Node) or not tgt.is_in_group("enemies"):
		return
	if not _plays_pitch():
		return
	var id := str(info.ability_id)
	var rain := id == "dot_" + CINDER_RAIN_ID
	if info.is_dot and not rain:
		return
	if not rain and not Abilities.tags_of(id).has("Ranged") and id != "auto_ranged":
		return
	if id == "auto_ranged" and layers_on(tgt) > 0:
		_hot_shaft(info)
	var double := int(round(player._talent("fire_double_coat")))   # Double Coat
	if info.crit:
		ignite(tgt)
		if id == "pitcharrow":
			coat(tgt, Balance.PITCH_ARROW_LAYERS + double)   # (it coats even when it crits: fresh pitch after the flash)
		return
	var n := layers_from(id, player.status.has(BRUSHFIRE_ID), double)
	if rain:
		var now := Time.get_ticks_msec() / 1000.0
		var key: int = tgt.get_instance_id()
		if now - float(_rain_coat_at.get(key, -100.0)) < Balance.PITCH_RAIN_COAT_EVERY:
			return
		_rain_coat_at[key] = now
		n = 1
	else:
		var steady := player._talent("fire_steady_bow")
		if steady > 0.0:
			player._gain("energy", steady)   # Steady Bow
	coat(tgt, n)
	if id == "auto_ranged" and player.status.has(BRUSHFIRE_ID) and tgt.is_alive():
		_burn(tgt)

## Why Touch Off can't be used right now ("" = it can).
func _bow_precheck(id: String) -> String:
	if id == TOUCH_OFF_ID and (not player._has_valid_target() or layers_on(player.target) <= 0):
		return "Your Pitch isn't on that target"
	return ""

## Touch Off and Brushfire (paid for and put on cooldown by _use_drafted).
func _bow_use(id: String) -> void:
	match id:
		TOUCH_OFF_ID:
			if player._has_valid_target():
				ignite(player.target, Balance.TOUCH_OFF_PCT)
			if randf() * 100.0 < player._talent("fire_second_light"):
				player.cooldowns.erase(id)   # Second Light: no cooldown this time
		BRUSHFIRE_ID:
			var fx := StatusContainer.make_buff(BRUSHFIRE_ID, Abilities.ability_name(id), BRUSHFIRE_ID, 0.0,
				Balance.BRUSHFIRE_TIME + player._talent("fire_long_brush"), 1, Abilities.color_of(id))   # + Long Brush
			fx.stat_modifiers = {}
			fx.description = "Your auto-shots Burn their target and add %d layers of Pitch." % Balance.BRUSHFIRE_LAYERS
			player.status.apply(fx, player)
			player._ring_effect(1.3, Abilities.color_of(id))

## Why Cinder Rain can't be used right now ("" = it can). `point` = where it would land.
func _cinder_rain_error(point: Variant = null) -> String:
	if player.cooldown_left(CINDER_RAIN_ID) > 0.0:
		return "%s is not ready yet" % Abilities.ability_name(CINDER_RAIN_ID)
	if player._weapon().get("weapon", "") != "ranged":
		return "Requires a bow"
	if point is Vector3:
		var reach := float(Abilities.get_resource(CINDER_RAIN_ID).cast_range)
		if reach > 0.0 and Vector2(point.x - player.global_position.x, point.z - player.global_position.z).length() > reach:
			return "Out of range"
	return ""

func _start_cinder_rain(point: Vector3) -> void:
	if player.casting or not player.is_on_floor():
		return
	var err := _cinder_rain_error(point)
	if err != "":
		player._error(err)
		return
	if not player._pay(CINDER_RAIN_ID):
		return
	var res := Abilities.get_resource(CINDER_RAIN_ID)
	player.cooldowns[CINDER_RAIN_ID] = float(res.cooldown)
	var dir := point - player.global_position
	if Vector2(dir.x, dir.z).length() > 0.3:
		player.rotation.y = atan2(-dir.x, -dir.z)
	var rain := Node3D.new()
	rain.set_script(CINDER_RAIN)
	rain.radius = float(res.radius) + Abilities.radius_bonus(CINDER_RAIN_ID)   # + Wide Rain
	rain.duration = Balance.CINDER_RAIN_TIME
	rain.tick = maxf(Balance.CINDER_RAIN_TICK / player.haste_mult(), 0.1)
	rain.damage = player._weapon_hit(player._weapon(), res)   # per tick
	rain.tags = res.tags
	rain.source = player
	player.get_tree().current_scene.add_child(rain)
	rain.global_position = point
	player._net_fx(CINDER_RAIN_ID, point, null, {"r": float(res.radius), "time": Balance.CINDER_RAIN_TIME})
	if Player.on_gcd(CINDER_RAIN_ID):
		player._start_gcd()
	player._bus().cast_finished.emit(CINDER_RAIN_ID)
