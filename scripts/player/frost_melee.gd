extends "res://scripts/player/player_kit.gd"
class_name FrostMeleeKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "frost_melee".
# --- Frost weapon abilities ----------------------------------------------------------
# (Rime Slash and Shattering Slam are Glacier Wall's now: scripts/player/frost_glacier.gd.)

## A hit with its own threat multiplier (for bonus threat on top of the ability's data).
func _hit_with_threat(enemy: Node, coef: float, id: String, threat_mult: float,
		damage_type: String = "", tags: PackedStringArray = PackedStringArray()) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
		return
	var info := DamageInfo.make(player, enemy, coef, id)
	var r := Abilities.get_resource(id)
	info.tags = tags if not tags.is_empty() else (r.tags if r else PackedStringArray())
	info.damage_type = damage_type if damage_type != "" else (str(r.damage_type) if r else "physical")
	info.threat_multiplier = threat_mult
	player._combat().deal(info)


# --- Frost talents & runes: slows / freezes I apply ------------------------------------
# Scanned once per frame from the enemies' status effects whose source is me.
# Works the same solo, as the host and as a party member (whose enemies mirror
# the host's effects with me as the source). A slow counts as (re)applied when
# it's new or its time left jumped up (a refresh).

const FROZEN_FX = preload("res://data/effects/frozen.tres")

var _my_slows := {}         # "enemy id|effect key" -> expires
var _slowed_at := {}        # enemy instance id -> when I last slowed it
var _glacial_haste := 0.0   # Glacial Heart capstone: Haste from my slows on enemies
var _cold_snap := 0.0       # Cold Snap: seconds off the next GCD

func _scan_my_slows() -> void:
	# Nothing reacts to my slows: skip the scan.
	if player._talent("frost_cold_snap") <= 0.0 and player._talent("frost_slow_threat") <= 0.0 \
			and player._talent("frost_slow_dr") <= 0.0 and not _capstone("frost_glacial_heart") \
			and player._talent("frost_instinct") <= 0.0 and not _has_rune("frozen_aegis"):
		_my_slows.clear()
		_slowed_at.clear()
		_glacial_haste = 0.0
		return
	var now := Time.get_ticks_msec() / 1000.0
	var seen := {}
	var count := 0
	for e in player.get_tree().get_nodes_in_group("enemies"):
		if not e.is_alive():
			continue
		var st: Node = e.get_node_or_null("Status")
		if st == null or st.effects.is_empty():
			continue
		var eid: int = e.get_instance_id()
		for k in st.effects:
			var fx: Dictionary = st.effects[k]
			# My own application's clock: an ally refreshing the same slow neither
			# takes it from me nor counts as me slowing the enemy again.
			var expires: float = st.own_expires(fx, player)
			if expires <= 0.0:
				continue
			var res: Resource = fx["res"]
			if float(res.stat_modifiers.get("move_speed", 0.0)) >= 0.0:
				continue
			count += 1
			var key := "%d|%s" % [eid, str(k)]
			seen[key] = expires
			var before: Variant = _my_slows.get(key)
			if before == null or expires > float(before) + 0.25:
				_on_slow_applied(e, str(res.id))
	_my_slows = seen
	_glacial_haste = count * Balance.GLACIAL_HEART_HASTE if _capstone("frost_glacial_heart") else 0.0
	for id in _slowed_at.keys():
		if now - float(_slowed_at[id]) > Balance.SLOW_MEMORY:
			_slowed_at.erase(id)

func _on_slow_applied(enemy: Node, effect_id: String) -> void:
	_slowed_at[enemy.get_instance_id()] = Time.get_ticks_msec() / 1000.0
	if effect_id != "frozen":
		return
	var cs := player._talent("frost_cold_snap")
	if cs > 0.0:
		_cold_snap = maxf(_cold_snap, cs)
	var fi := player._talent("frost_instinct")
	if fi > 0.0 and randf() * 100.0 < fi:
		player.frost_bow._grant_frozen_instinct()
	if _has_rune("frozen_aegis"):
		var amount := player.frost_runes._aegis_amount(Balance.FROZEN_AEGIS_ON_FREEZE)
		for a in player.frost_runes._aegis_allies():
			player.frost_runes._give_aegis(a, amount)

## Did I slow `enemy` in the last SLOW_MEMORY seconds? (Chilling Presence, Numbing Cold)
func _slowed_recently(enemy: Variant) -> bool:   # untyped: may be a freed enemy
	if enemy == null or not is_instance_valid(enemy):
		return false
	var at: Variant = _slowed_at.get(enemy.get_instance_id())
	return at != null and Time.get_ticks_msec() / 1000.0 - float(at) <= Balance.SLOW_MEMORY

## Glacial Heart: slows on me are this much as strong (StatusContainer asks).
func slow_taken_mult() -> float:
	return maxf(1.0 - player._talent("frost_glacial_heart") / 100.0, 0.0)

func _capstone(key: String) -> bool:
	var pd := player.get_node_or_null("/root/PlayerData")
	return pd != null and pd.talent_capstone(key)

func _has_rune(id: String) -> bool:
	var rl := player.get_node_or_null("RuneListener")
	return rl != null and rl.has_rune(id)

