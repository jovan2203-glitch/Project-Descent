extends "res://scripts/player/player_kit.gd"
class_name FireBowKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "fire_bow".
# --- Fire bow: Pitch Arrow and Cinder Rain ------------------------------------------------
# Pitch Arrow leaves my own "pitched" debuff on its target (one per archer).
# While it is there MY Burning and Immolate on that target tick faster: the
# StatusContainer asks dot_speed_mult() before every tick. Own only.
# Cinder Rain is aimed on the ground like Blizzard but is instant: the volley
# lands where you click (scripts/cinder_rain.gd).

const PITCH_FX_ID := "pitched"
const CINDER_RAIN_ID := "cinderrain"
const CINDER_RAIN = preload("res://scripts/cinder_rain.gd")

## How much faster effect `effect_id` ticks on a target that has my pitch on it (or not).
static func pitch_speed(effect_id: String, pitched: bool) -> float:
	if pitched and Balance.PITCH_EFFECTS.has(effect_id):
		return 1.0 + Balance.PITCH_TICK_SPEED_PCT / 100.0
	return 1.0

## The StatusContainer asks before every tick of one of MY damage-over-time effects.
func dot_speed_mult(tgt: Node, res: Resource) -> float:
	var id := str(res.id)
	var wasting := ShadowTalentsKit.dot_speed_with(1.0, player._talent("shadow_wasting"))   # Wasting: all of my damage over time
	if not Balance.PITCH_EFFECTS.has(id) or tgt == null or not is_instance_valid(tgt):
		return wasting
	var st: Node = tgt.get_node_or_null("Status")
	return pitch_speed(id, st != null and st.has_from(PITCH_FX_ID, player)) * wasting

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
	rain.radius = float(res.radius)
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

