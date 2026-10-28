extends "res://scripts/player/player_kit.gd"
class_name IceShardsKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "ice_shards_kit".
# --- Ice Shards: charges, and firing one shard per charge ---------------------------
# Up to ICE_SHARDS_MAX_CHARGES charges: one every ICE_SHARDS_RECHARGE seconds, one
# for every Frost spell you cast, and (Splintering Cold talent) a chance on any
# spell. While shards are firing no charges are gained (the recharge waits too).

var ice_shard_charges: int = Balance.ICE_SHARDS_MAX_CHARGES
var _shard_recharge := 0.0
var _shards_left := 0   # shards still to fire from the current volley

func shards_firing() -> bool:
	return _shards_left > 0

## Seconds until the next natural charge (0 when full).
func shard_recharge_left() -> float:
	if ice_shard_charges >= Balance.ICE_SHARDS_MAX_CHARGES:
		return 0.0
	return maxf(Balance.ICE_SHARDS_RECHARGE - _shard_recharge, 0.0)

func _tick_ice_shards(delta: float) -> void:
	if ice_shard_charges >= Balance.ICE_SHARDS_MAX_CHARGES:
		_shard_recharge = 0.0
		return
	if shards_firing():
		return
	_shard_recharge += delta
	if _shard_recharge >= Balance.ICE_SHARDS_RECHARGE:
		_shard_recharge = 0.0
		gain_ice_shard()

## +1 charge (no-op while firing or full).
func gain_ice_shard() -> void:
	if shards_firing() or ice_shard_charges >= Balance.ICE_SHARDS_MAX_CHARGES:
		return
	ice_shard_charges += 1

func _on_spell_cast_for_shards(id: String) -> void:
	if id == "iceshards" or player.is_dead():
		return
	var pd := player.get_node_or_null("/root/PlayerData")
	if pd == null or not pd.has_ability("iceshards"):
		return
	var tags := Abilities.tags_of(id)
	if not tags.has("Spell"):
		return
	if tags.has("Frost"):
		gain_ice_shard()
	var chance: float = pd.talent_value("frost_shard_proc")
	if chance > 0.0 and randf() * 100.0 < chance:
		gain_ice_shard()

## Fire every charge at the target, one shard per ICE_SHARDS_INTERVAL. If the
## target dies mid-volley the rest go to your current target (or fizzle).
func _fire_ice_shards(dmg: float) -> void:
	var n := ice_shard_charges
	ice_shard_charges = 0
	_shards_left = n
	var tgt := player.target
	for i in n:
		player.get_tree().create_timer(Balance.ICE_SHARDS_INTERVAL * i).timeout.connect(func():
			_shards_left = maxi(_shards_left - 1, 0)
			if not player.is_alive():
				return
			var aim: Node3D = tgt
			if aim == null or not is_instance_valid(aim) or not aim.is_alive():
				aim = player.target if player._has_valid_target() else null
			if aim:
				Player.FROST_BOLT.spawn(player.get_tree().current_scene, player._muzzle(), aim, player, false, "iceshards", dmg)
				player.frost_runes._on_shard_fired(aim))


func tracker_values() -> Dictionary:
	return {"ice_shards": {"value": ice_shard_charges, "max": Balance.ICE_SHARDS_MAX_CHARGES}}
