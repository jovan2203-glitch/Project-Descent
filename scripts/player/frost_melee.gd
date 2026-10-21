extends "res://scripts/player/player_kit.gd"
class_name FrostMeleeKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "frost_melee".
# --- Frost weapon abilities ----------------------------------------------------------

## Shattering Slam: weapon hit. On a Rime Shelled or Frozen target the ice
## shatters on it alone (no splash): bonus damage + the shatter's damage, 3x threat.
const SHATTER_SLAM_THREAT := Balance.SHATTER_SLAM_THREAT

func _shattering_slam(tgt: Node3D, w: Dictionary, res: Resource) -> void:
	if tgt == null or not is_instance_valid(tgt) or not tgt.is_alive():
		return
	# Taken off first, so the hits below don't break the shell again.
	var iced := player._strip_ice(tgt)   # own only: my whole shell, my freeze
	var at := tgt.global_position
	_hit_with_threat(tgt, player._weapon_hit(w, res), "shatteringslam", SHATTER_SLAM_THREAT if not iced.is_empty() else 1.0)
	player._slash_effect(Abilities.color_of("shatteringslam"))
	if iced.is_empty():
		return
	_hit_with_threat(tgt, float(Abilities.EXTRA_HITS["shatteringslam"]), "shatteringslam", SHATTER_SLAM_THREAT,
		"frost", PackedStringArray(["Ability", "Frost", "Melee"]))
	# The shatter itself, on the target alone: the same routine as every other
	# shatter (under the slam's name, with the slam's threat).
	for i in iced.size():
		player.shatter_at(at, "shatteringslam", 1.0, tgt, SHATTER_SLAM_THREAT)

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

## Rime Slash: weapon frost damage in a small cone (3x threat). Rime Shell goes
## on you; if Thawing stops that, on one enemy it hit.
func _rime_slash(w: Dictionary, res: Resource) -> void:
	var reach := float(res.radius) + float(w.get("attack_range", 1.0)) * 0.5
	var fwd := player._flat_forward()
	var cos_limit := cos(deg_to_rad(RIME_SLASH_HALF_ANGLE))
	var hit: Array = []
	for e in player.get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D) or not e.is_alive():
			continue
		var to: Vector3 = e.global_position - player.global_position
		to.y = 0.0
		var d := to.length()
		if d - Combat.hitbox_radius(e) > reach:
			continue
		if d > 0.6 and fwd.dot(to / d) < cos_limit:
			continue
		if not player.can_see(e):
			continue
		hit.append(e)
	var coef := player._weapon_hit(w, res)
	for e in hit:
		player.deal_damage(e, coef, "rimeslash")
	for i in 2:
		player._slash_effect(Abilities.color_of("rimeslash"))
	player._cone_effect(reach, RIME_SLASH_HALF_ANGLE, Color(0.6, 0.9, 1.0))
	var everlasting := _has_rune("everlasting_rime")
	var absorb: int = int(round(player._combat().heal_amount(player, float(Abilities.HEALS["rimeslash"]), "rimeslash") \
		* player.absorb_mult() * (Balance.EVERLASTING_RIME_MULT if everlasting else 1.0)))   # Rime Ward counts here too
	if not player.status.has("thawing"):
		player.receive_rime_shell(player, absorb, player._talent("frost_shield_armor"), not everlasting)
		return
	if everlasting:
		return   # Everlasting Rime: shells never go on enemies
	# Thawing: the shell goes on an enemy we hit (the target if it was hit).
	var pick: Node = null
	for e in hit:
		if e.is_alive():
			pick = e
			if e == player.target:
				break
	if pick and player._net():
		player._net().shell_enemy(pick, player, absorb)
		player._ring_effect(1.0, Color(0.6, 0.9, 1.0), pick.global_position)

const RIME_SLASH_HALF_ANGLE := 50.0

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

