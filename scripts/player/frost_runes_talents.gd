extends "res://scripts/player/player_kit.gd"
class_name FrostRunesKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "frost_runes".
# --- Cold Precision rune: every 6th Frost spell / ability crits ------------------------
# Counted when a cast finishes. After 5, the next one is empowered: an instant
# one as it's used (its hits land before it "finishes"), a cast one when it
# finishes (its projectile lands after). Its hits for a few seconds crit.

var _cp_count := 0
var _cp_armed := false
var _cp_pending := ""   # instant empowered on use, confirmed when it actually goes off

static func _is_frost_action(id: String) -> bool:
	var t := Abilities.tags_of(id)
	return t.has("Frost") and (t.has("Spell") or t.has("Ability"))

func _cold_precision_on_use(id: String) -> void:
	if not _cp_armed or not player.frost_melee._has_rune("cold_precision") or not _is_frost_action(id):
		return
	var res := Abilities.get_resource(id)
	if res == null or float(res.cast_time) > 0.0 or id == "blizzard":
		return   # cast-time spells are empowered when the cast finishes
	# Empower now (its hits land right away); if it fails (cooldown, range...)
	# it never "finishes" and the empowerment is taken back.
	player._empowered[id] = Time.get_ticks_msec() / 1000.0 + Balance.COLD_PRECISION_WINDOW
	_cp_pending = id
	_cold_precision_undo.call_deferred(id)

func _cold_precision_undo(id: String) -> void:
	if _cp_pending == id:
		_cp_pending = ""
		player._empowered.erase(id)

func _cold_precision_on_cast(id: String) -> void:
	if id != "" and id == _cp_pending:
		_cp_pending = ""
		_cold_precision_fire(id)   # the empowered instant went off
		return
	if not player.frost_melee._has_rune("cold_precision") or not _is_frost_action(id):
		return
	player._empowered.erase(id)   # a new cast of this ability: the old empowerment is over
	if _cp_armed:
		_cold_precision_fire(id)
		return
	_cp_count += 1
	if _cp_count >= Balance.COLD_PRECISION_EVERY - 1:
		_cp_armed = true

func _cold_precision_fire(id: String) -> void:
	_cp_armed = false
	_cp_count = 0
	player._empowered[id] = Time.get_ticks_msec() / 1000.0 + Balance.COLD_PRECISION_WINDOW
	player._combat().float_text(player, "Cold Precision", Color(0.7, 0.92, 1.0), false)

# --- Permafrost rune: rolling Frost damage from crit chance -----------------------------

var _perma := {}   # enemy instance id -> {"target", "left" (damage), "ticks", "next"}

func _on_damage_dealt_frost(info: RefCounted) -> void:
	if not is_same(info.source, player) or info.avoided() or int(info.amount) <= 0:
		return
	if not is_instance_valid(info.target):
		return
	var tgt: Node = info.target
	if str(info.ability_id) == "icepin":
		_note_icepin(tgt)   # Pinning Frost
	player.frost_bow._coldmark_arrow(info)     # Coldmark: my arrows on the marked target give Ice Shard charges
	if info.has_meta("cold_draw"):
		player._gain("energy", player._talent("frost_cold_draw"))   # Cold Draw: the target was already Chilled or Frozen
	player.frost_bow._rimefletch_shot(info)    # Rimefletch: my auto-shots carry an extra Frost hit
	player.frost_more._rime_edge_on_hit(info)   # Rime Edge: my melee hits carry an extra Frost hit
	player.frost_steel._hoar_blade_on_hit(info)   # Rune of the Hoar Blade: auto-attacks at full Glaze
	if not is_instance_valid(tgt) or not tgt.is_alive():
		return   # (that extra hit can be the killing blow)
	if info.has_meta("permafrost_pct"):
		var pct := float(info.get_meta("permafrost_pct"))
		if pct > 0.0:
			_add_permafrost(tgt, float(info.amount) * pct / 100.0)
	# Frozen Aegis: damaging an enemy I Froze shields the lowest-health ally near me.
	if tgt.is_in_group("enemies") and player.frost_melee._has_rune("frozen_aegis"):
		var st: Node = tgt.get_node_or_null("Status")
		if st and st.has_from("frozen", player):
			var pick := _lowest_health_ally()
			if pick:
				_give_aegis(pick, _aegis_amount(Balance.FROZEN_AEGIS_ON_HIT))

func _add_permafrost(tgt: Node, dmg: float) -> void:
	var key := tgt.get_instance_id()
	var now := Time.get_ticks_msec() / 1000.0
	var e: Dictionary = _perma.get(key, {"target": tgt, "left": 0.0, "next": now + 1.0})
	e["left"] = float(e["left"]) + dmg
	e["ticks"] = int(round(Balance.PERMAFROST_TIME))   # rolling: the pool restarts its 6 s
	_perma[key] = e

func _tick_permafrost() -> void:
	if _perma.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	for key in _perma.keys():
		var e: Dictionary = _perma[key]
		if not is_instance_valid(e["target"]) or not e["target"].is_alive() or int(e["ticks"]) <= 0:
			_perma.erase(key)
			continue
		var tgt: Node = e["target"]
		if now < float(e["next"]):
			continue
		var amt := float(e["left"]) / int(e["ticks"])
		e["left"] = float(e["left"]) - amt
		e["ticks"] = int(e["ticks"]) - 1
		e["next"] = float(e["next"]) + 1.0
		if amt > 0.0:
			var info := DamageInfo.make(player, tgt, 1.0, "permafrost")
			info.unit = amt
			info.exact = true
			info.add_power = false
			info.can_crit = false
			info.can_block = false
			info.is_dot = true
			info.damage_type = "frost"
			info.tags = PackedStringArray(["Frost", "Spell", "DoT"])
			player._combat().deal(info)

# --- Frozen Aegis rune: shields for you and allies ------------------------------------

## Shield size: `share` x a Heal spell, with Rime Ward.
func _aegis_amount(share: float) -> int:
	return int(round(player._combat().heal_amount(player, Balance.REFERENCE_HEAL * share) * player.absorb_mult()))

## Me + party members + friendly dummies within FROZEN_AEGIS_RADIUS.
func _aegis_allies() -> Array:
	return player.fire_cooldowns._allies_within(Balance.FROZEN_AEGIS_RADIUS)

## The ally (me included) within `radius` with the smallest share of their health left.
func _lowest_health_ally(radius: float = Balance.FROZEN_AEGIS_RADIUS) -> Node:
	var allies := player.fire_cooldowns._allies_within(radius)
	var shares: Array = []
	for a in allies:
		var h: Variant = a.get("health")
		var mh: Variant = a.get("max_health")
		shares.append(float(h) / maxf(float(mh), 1.0) if h != null and mh != null else 1.0)
	var i := FireCooldownsKit.lowest_share(shares)
	return allies[i] if i >= 0 else null

func _give_aegis(who: Node, amount: int) -> void:
	if who == null or not is_instance_valid(who) or amount <= 0:
		return
	var cap := _aegis_amount(Balance.FROZEN_AEGIS_CAP)
	var armor := player._talent("frost_shield_armor")
	if who == player:
		receive_frozen_aegis(player, amount, cap, armor)
	elif who.is_in_group("remote_player"):
		if player._net():
			player._net().aegis_ally(who, player, amount, cap, armor)
	elif who.has_method("receive_frozen_aegis"):
		who.receive_frozen_aegis(player, amount, cap, armor)

## A Frozen Aegis shield lands on me (adds up to `cap`).
func receive_frozen_aegis(caster: Node, amount: int, cap: int, armor_pct: float = 0.0) -> void:
	if player.is_dead():
		return
	SHIELDS.add_aegis(player.status, caster, amount, cap, armor_pct)

# --- Ice Shards talents: Splintering, Shardstorm, Deep Freeze capstone ------------------

var _shardstorm_count := 0
var _blizzard_shards := 0

## Every Ice Shard fired at `aim`.
func _on_shard_fired(aim: Node3D) -> void:
	var ss := player._talent("frost_shardstorm")
	if ss > 0.0:
		_shardstorm_count += 1
		if _shardstorm_count >= Balance.SHARDSTORM_EVERY:
			_shardstorm_count = 0
			player.add_buff("shardstorm", Stats.HASTE, ss, Balance.SHARDSTORM_TIME, 1, "Shardstorm")
	if player.frost_melee._capstone("frost_deep_freeze"):
		_blizzard_shards += 1
		if _blizzard_shards >= Balance.DEEP_FREEZE_BLIZZARD_EVERY:
			_blizzard_shards = 0
			_free_blizzard(aim)

## Deep Freeze capstone: a Blizzard at the target at reduced strength.
func _free_blizzard(aim: Node3D) -> void:
	if aim == null or not is_instance_valid(aim):
		return
	var p := aim.global_position
	var at := Vector3(p.x, Combat.feet_y(aim), p.z)
	var bliz := Node3D.new()
	bliz.set_script(Player.BLIZZARD)
	bliz.radius = player.blizzard_radius()
	bliz.source = player
	bliz.damage = float(Abilities.get_resource("blizzard").damage) * Balance.DEEP_FREEZE_BLIZZARD_MULT
	player.get_tree().current_scene.add_child(bliz)
	bliz.global_position = at
	var net := player._net()
	if net:
		net.send_fx("blizzard", at, null, "", {"r": bliz.radius})

## Splintering: a shard that hit a Frozen / Rime Shelled enemy hits another one nearby.
func _splinter(at: Vector3, from_id: int) -> void:
	var others := player._enemies_near(at, Balance.SPLINTER_RANGE).filter(func(e): return e.get_instance_id() != from_id)
	if others.is_empty():
		return
	player.deal_damage(others.pick_random(), player._talent("frost_splinter"), "splintering", true, "frost",
		PackedStringArray(["Frost", "Spell"]))

## Deep Freeze: Freeze the target (a 0-damage hit carrying Frozen, so it works in a party too).
func _apply_freeze(tgt: Node, tags: PackedStringArray) -> void:
	var info := DamageInfo.make(player, tgt, 0.0, "deepfreeze")
	info.tags = tags
	info.damage_type = "frost"
	info.can_block = false
	info.can_crit = false
	info.add_power = false
	info.is_proc = true
	info.effects.append(FrostMeleeKit.FROZEN_FX)
	player._combat().deal(info)

# --- Winter's Bite: every third one Freezes ---------------------------------------------
# Each cast adds a stack of a counter buff on me (WINTERS_BITE_TIME seconds,
# restarted by each stack). The cast that would bring it to WINTERS_BITE_STACKS
# uses the stacks up and Freezes the target instead of Chilling it.

const WINTERS_BITE_ID := "winters_bite"
var _bite_fx: Resource
var _bite_freezing := false   # the Winter's Bite being dealt right now is the one that Freezes

# --- Pinning Frost: which enemies my Icepin has rooted ------------------------------------
# Rooted is one effect for everything that roots, so the Icepin that caused it
# is remembered here: enemy instance id -> when that root runs out.
var _icepin_roots := {}

func _note_icepin(tgt: Node) -> void:
	var res := Abilities.get_resource("icepin")
	var fx: Resource = res.on_hit_effect if res else null
	if fx == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for key in _icepin_roots.keys():
		if float(_icepin_roots[key]) <= now:
			_icepin_roots.erase(key)
	_icepin_roots[tgt.get_instance_id()] = now + float(fx.duration) + player.effect_duration_bonus(fx)

## Is `tgt` rooted by my Icepin right now?
func _icepin_root_on(tgt: Node) -> bool:
	var until := float(_icepin_roots.get(tgt.get_instance_id(), 0.0))
	if until <= Time.get_ticks_msec() / 1000.0:
		return false
	var st: Node = tgt.get_node_or_null("Status")
	return st != null and st.has_from(str(Abilities.get_resource("icepin").on_hit_effect.id), player)

func _winters_bite_fx() -> Resource:
	if _bite_fx == null:
		_bite_fx = StatusContainer.make_buff(WINTERS_BITE_ID, Abilities.ability_name("froststrike"), WINTERS_BITE_ID, 0.0,
			Balance.WINTERS_BITE_TIME, Balance.WINTERS_BITE_STACKS, Abilities.color_of("froststrike"))
		_bite_fx.stat_modifiers = {}
		_bite_fx.description = "At %d stacks your %s Freezes its target instead of Chilling it, and the stacks are used up." % [
			Balance.WINTERS_BITE_STACKS, Abilities.ability_name("froststrike")]
	return _bite_fx

## Does the cast that follows `stacks` earlier ones Freeze?
static func winters_bite_freezes(stacks: int) -> bool:
	return stacks + 1 >= Balance.WINTERS_BITE_STACKS

func _winters_bite(tgt: Node, coef: float) -> void:
	if tgt == null or not is_instance_valid(tgt) or not tgt.is_alive():
		return
	# Black Frost: every one Freezes (the counter is left as it is).
	var black := player.frost_steel.black_frost_on()
	var freeze := black or winters_bite_freezes(int(player.status.stacks_of(WINTERS_BITE_ID)))
	if freeze and not black:
		player.status.remove(WINTERS_BITE_ID)
	elif not freeze:
		player.status.apply(_winters_bite_fx(), player)
	var was_cold := player.frost_steel.cold_on(tgt)   # (before its own Chill)
	var at: Vector3 = tgt.global_position
	var info = player._combat().ability_hit_info(player, tgt, coef, "froststrike")
	if freeze:
		info.effects = [FrostMeleeKit.FROZEN_FX]   # instead of its Chill
	_bite_freezing = freeze   # Third Bite reads this while the hit is worked out
	player._combat().deal(info)
	_bite_freezing = false
	if not info.avoided():
		player.frostfire_kit._on_hit_extra(tgt, at, "froststrike")
		player.frost_steel._bite_landed(was_cold)   # Frost DPS: Glaze

# --- Ice Floe & Shatterpoint -----------------------------------------------------------

const CHILLED_FX = preload("res://data/effects/chilled.tres")
var _last_hit_by: Variant = null   # whoever hit me last (the shield breaker)

## Ice Floe: an absorb shield I put on myself was used up by damage (own only:
## a party member's shield on me breaking does nothing for my talents).
func _on_my_shield_broken(id: String) -> void:
	if id == ArcaneCasterKit.WARD_FX and is_same(player.status.last_shield_source, player):
		player.arcane_caster._ward_broke()   # Interval Ward: the time it had left comes off its cooldown
	var v := player._talent("frost_ice_floe")
	if v <= 0.0 or player.is_dead() or not is_same(player.status.last_shield_source, player):
		return
	player.add_buff("icefloe", Stats.MOVE_SPEED, v, Balance.ICE_FLOE_TIME, 1, "Ice Floe")
	var foe: Variant = _last_hit_by
	if foe != null and is_instance_valid(foe) and foe.is_in_group("enemies") and foe.is_alive():
		# A 0-damage hit carrying Chilled (works in a party too, like Deep Freeze).
		var info := DamageInfo.make(player, foe, 0.0, "icefloe")
		info.tags = PackedStringArray(["Frost", "Spell"])
		info.damage_type = "frost"
		info.can_block = false
		info.can_crit = false
		info.add_power = false
		info.is_proc = true
		info.effects.append(CHILLED_FX)
		player._combat().deal(info)

## Shatterpoint capstone: every shatter gives an Ice Shard charge.
func _shatterpoint_charge() -> void:
	if player.frost_melee._capstone("frost_shatterpoint"):
		player.ice_shards_kit.gain_ice_shard()

