extends "res://scripts/player/player_kit.gd"
class_name GlacierKit

# Hooked up from player.gd through its var "glacier".
# --- Frost tank: Glacier Wall (a one-handed melee weapon and a shield, Fury) -------------
# Ice Layers: one absorb shield on me, cut into layers (ICE_LAYERS_MAX, each
# ICE_LAYER_PCT % of my maximum health; Rime Ward and Deep Strata make each
# bigger). A hit that breaks a Layer gives me Fury and Chills the attacker
# (_glacier_hit_taken counts the Layers left after every hit). Rime Slash, Cold
# Shoulder, Hailcoat and Glacial Bulwark give Layers; Shattering Slam spends them
# all on its target; Rimequake hits harder the more I hold; Hard Rime makes broken
# Layers form again, Glacial Bulwark makes them shatter around me.
# Everything is on my own machine: the shield is mine, the hits I take are dealt
# here (Net.send_enemy_hit), my Chills and taunts go through combat / Net.
# Numbers: balance.gd (ICE_LAYER_*, RIME_SLASH_*, SHATTER_SLAM_*, RIMEQUAKE_*,
# COLD_SHOULDER_*, HARD_RIME_*, GLACIAL_BULWARK_*, DEEP_STRATA_*). Talents: Packed
# Ice (Shattering Slam), Turned Backs (Cold Shoulder),
# Regelation (Hard Rime), Old Ice (Glacial Bulwark), Cold Fury and Deep Strata
# (the Layers themselves). Rune of the Ice Shelf: more Layers, no Chill.

const RIME_SLASH_ID := "rimeslash"
const SHATTER_SLAM_ID := "shatteringslam"
const COLD_SHOULDER_ID := "coldshoulder"
const RIMEQUAKE_ID := "rimequake"
const HAILCOAT_ID := "hailcoat"
const HARD_RIME_ID := "hardrime"
const BULWARK_ID := "glacialbulwark"
const GLACIER_IDS := [RIME_SLASH_ID, SHATTER_SLAM_ID, COLD_SHOULDER_ID, RIMEQUAKE_ID, HAILCOAT_ID, HARD_RIME_ID, BULWARK_ID]
const LAYERS_FX := "ice_layers"
const HARD_RIME_FX := "hard_rime"
const BULWARK_FX := "glacial_bulwark"
const ICE_SHELF_RUNE := "ice_shelf"
const LAYER_COLOR := Color(0.7, 0.92, 1.0)
const RIME_SLASH_HALF_ANGLE := 50.0
## How far from Cold Shoulder's target the enemies Turned Backs also taunts can be.
const TURNED_BACKS_RANGE := 8.0
const SHATTER_SLAM_THREAT := Balance.SHATTER_SLAM_THREAT

var _layer_size := 1         # shield health of one Layer when they were last given
var _layers := 0             # Layers I had after the last hit (to count the ones that broke)
var _reform_at: Array = []   # Hard Rime: when each broken Layer forms again
var _strata_ready := 0.0     # Deep Strata capstone: when it can give a Layer back again
var _layers_fx: Resource

# Rules as static functions (tests/test_frost_melee.gd).

## Most Ice Layers I can hold (`ice_shelf`: the Rune of the Ice Shelf).
static func max_layers(ice_shelf: bool) -> int:
	return Balance.ICE_SHELF_LAYERS if ice_shelf else Balance.ICE_LAYERS_MAX

## Shield health of one Layer on a character with `max_hp` (`absorb_pct`: Rime Ward, `strata_pct`: Deep Strata).
static func layer_amount(max_hp: int, absorb_pct: float, strata_pct: float) -> int:
	return maxi(int(round(float(max_hp) * Abilities.ice_layer_pct(absorb_pct, strata_pct) / 100.0)), 1)

## Layers a shield of `absorb` is, at `size` each: a Layer that is only partly
## used up still counts.
static func layers_in(absorb: int, size: int) -> int:
	if absorb <= 0 or size <= 0:
		return 0
	return ceili(float(absorb) / float(size) - 0.0001)

## Shield after gaining `more` Layers of `size` on top of `absorb`, up to `cap` Layers.
static func absorb_after(absorb: int, size: int, more: int, cap: int) -> int:
	return mini(maxi(absorb, 0) + maxi(more, 0) * size, cap * size)

## Layers Rime Slash gives when it hits `hits` enemies.
static func rime_slash_layers(hits: int) -> int:
	return Balance.RIME_SLASH_LAYERS_MANY if hits >= Balance.RIME_SLASH_MANY_HITS else Balance.RIME_SLASH_LAYERS

## Rimequake's damage multiplier with `layers` held (`pct` % each).
static func quake_mult(layers: int, pct: float) -> float:
	return 1.0 + maxf(pct, 0.0) / 100.0 * maxi(layers, 0)

## Shattering Slam's extra Frost damage (coefficient) for `layers` shattered (`more_pct`: Packed Ice).
static func slam_layers_coef(layers: int, more_pct: float) -> float:
	return Balance.SHATTER_SLAM_PER_LAYER * maxi(layers, 0) * (1.0 + maxf(more_pct, 0.0) / 100.0)

## Fury each Layer that breaks gives (`more`: Cold Fury).
static func layer_fury(more: float) -> float:
	return Balance.ICE_LAYER_FURY + maxf(more, 0.0)

## How many Ice Layers I have.
func layers() -> int:
	if player.status == null or not player.status.has(LAYERS_FX):
		return 0
	return layers_in(player.status.absorb_left(LAYERS_FX), _layer_size)

func _cap() -> int:
	return max_layers(player.frost_melee._has_rune(ICE_SHELF_RUNE))

## The Layers' effect (Hardened Frost's armor while they last).
func _fx() -> Resource:
	var armor := player._talent("frost_shield_armor")
	var cap := _cap()
	if _layers_fx == null or int(_layers_fx.max_stacks) != cap \
			or not is_equal_approx(float(_layers_fx.stat_modifiers.get("armor%", 0.0)), armor):
		_layers_fx = StatusContainer.make_buff(LAYERS_FX, "Ice Layers", "armor%", armor, Balance.ICE_LAYERS_TIME, cap, LAYER_COLOR)
		if armor <= 0.0:
			_layers_fx.stat_modifiers = {}
		_layers_fx.tags = PackedStringArray(["Frost"])
		_layers_fx.description = "Layers of ice absorb damage. Each one that breaks gives you Fury and Chills the attacker."
	return _layers_fx

## Gain `more` Ice Layers (never past the cap); their time starts over.
func _gain_layers(more: int) -> void:
	if player.status == null or more <= 0 or player.is_dead():
		return
	var left := int(player.status.absorb_left(LAYERS_FX)) if player.status.has(LAYERS_FX) else 0
	if left <= 0:
		_layer_size = layer_amount(player.max_health, player._talent("frost_absorb"), player._talent("frost_deep_strata"))
	var total := absorb_after(left, _layer_size, more, _cap())
	if total <= 0 or not player.status.apply(_fx(), player):
		return
	player.status.set_absorb(LAYERS_FX, total)
	_layers = layers_in(total, _layer_size)
	player.status.set_stacks(LAYERS_FX, _layers)
	player.status.set_remaining(LAYERS_FX, Balance.ICE_LAYERS_TIME)
	player._ring_effect(0.9, LAYER_COLOR)

## Take every Layer off without them "breaking" (Shattering Slam spends them).
## Returns how many there were.
func _spend_layers() -> int:
	var n := layers()
	if player.status != null and player.status.has(LAYERS_FX):
		player.status.break_absorb(LAYERS_FX, true)
		player.status.remove(LAYERS_FX)
	_layers = 0
	return n

func _tick_glacier() -> void:
	if _layers > 0 and (player.status == null or not player.status.has(LAYERS_FX)):
		_layers = 0   # they ran out
	if _reform_at.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var due := 0
	for i in range(_reform_at.size() - 1, -1, -1):
		if float(_reform_at[i]) <= now:
			_reform_at.remove_at(i)
			due += 1
	if due > 0 and not player.is_dead():
		_gain_layers(due)
		var back := player._talent("frost_regelation")
		if back > 0.0:
			player._gain("fury", back * due)   # Regelation

## Something hit me (fire_cooldowns._on_hit_taken): count the Layers it broke.
func _glacier_hit_taken(info: RefCounted) -> void:
	if int(info.absorbed) <= 0 and _layers <= 0:
		return
	var now_have := layers()
	var lost := _layers - now_have
	_layers = now_have
	if player.status != null and player.status.has(LAYERS_FX) and now_have > 0:
		player.status.set_stacks(LAYERS_FX, now_have)
	if lost <= 0:
		return
	var foe: Variant = info.source
	var t := Time.get_ticks_msec() / 1000.0
	player._gain("fury", layer_fury(player._talent("frost_cold_fury")) * lost)   # + Cold Fury
	if not player.frost_melee._has_rune(ICE_SHELF_RUNE):
		player.frost_more._chill(foe, LAYERS_FX, PackedStringArray(["Ability", "Frost"]))
	if player.status.has(HARD_RIME_FX):
		for i in lost:
			_reform_at.append(t + Balance.HARD_RIME_REFORM)
	if player.status.has(BULWARK_FX):
		for i in lost:
			_bulwark_shatter()
	# Deep Strata (full rank): the last Layer breaking gives one straight back, now and then.
	if now_have == 0 and t >= _strata_ready and player.frost_melee._capstone("frost_deep_strata"):
		_strata_ready = t + Balance.DEEP_STRATA_COOLDOWN
		_gain_layers(1)

## Glacial Bulwark: a Layer that breaks shatters around me.
func _bulwark_shatter() -> void:
	var hit := player._enemies_within(Balance.GLACIAL_BULWARK_RADIUS)
	var coef := Balance.GLACIAL_BULWARK_SHATTER * Balance.aoe_share(hit.size())
	for e in hit:
		player.frost_melee._hit_with_threat(e, coef, BULWARK_ID, Balance.GLACIAL_BULWARK_THREAT, "frost",
			PackedStringArray(["Ability", "Frost", "AoE"]))
	player._ring_effect(Balance.GLACIAL_BULWARK_RADIUS, LAYER_COLOR)
	player._ring_effect(1.0, Color(1, 1, 1))

## Why a Glacier Wall ability can't be used right now ("" = it can).
func _glacier_precheck(id: String) -> String:
	if id == HAILCOAT_ID and layers() >= _cap():
		return "Your Ice Layers are full"
	return ""

## One of Glacier Wall's abilities (paid for and put on cooldown by _use_drafted).
func _glacier_use(id: String, res: Resource, w: Dictionary) -> void:
	match id:
		RIME_SLASH_ID:
			_rime_slash(w, res)
		SHATTER_SLAM_ID:
			_shattering_slam(player.target, w, res)
		COLD_SHOULDER_ID:
			_cold_shoulder()
		RIMEQUAKE_ID:
			_rimequake(res)
		HAILCOAT_ID:
			_gain_layers(_cap())
			player._ring_effect(1.3, Color(0.95, 0.97, 1.0))
		HARD_RIME_ID:
			var fx := StatusContainer.make_buff(HARD_RIME_FX, Abilities.ability_name(HARD_RIME_ID), HARD_RIME_FX, 0.0,
				Balance.HARD_RIME_TIME, 1, Abilities.color_of(HARD_RIME_ID))
			fx.stat_modifiers = {}
			fx.description = "Each Ice Layer that breaks forms again %s sec later." % Stats.num(Balance.HARD_RIME_REFORM)
			player.status.apply(fx, player)
			player._ring_effect(1.1, Abilities.color_of(HARD_RIME_ID))
		BULWARK_ID:
			var fx := StatusContainer.make_buff(BULWARK_FX, Abilities.ability_name(BULWARK_ID), BULWARK_FX, 0.0,
				Balance.GLACIAL_BULWARK_TIME + player._talent("frost_old_ice"), 1, Abilities.color_of(BULWARK_ID))   # + Old Ice
			fx.stat_modifiers = {}
			fx.description = "Each Ice Layer that breaks shatters around you."
			player.status.apply(fx, player)
			_gain_layers(Balance.GLACIAL_BULWARK_LAYERS)
			player._ring_effect(1.6, Abilities.color_of(BULWARK_ID))

## Rime Slash: weapon Frost damage in a cone in front of me (3x threat); Layers for me.
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
	var coef := player._weapon_hit(w, res) * Balance.aoe_share(hit.size())
	for e in hit:
		player.deal_damage(e, coef, RIME_SLASH_ID)
	for i in 2:
		player._slash_effect(Abilities.color_of(RIME_SLASH_ID))
	player._cone_effect(reach, RIME_SLASH_HALF_ANGLE, LAYER_COLOR)
	_gain_layers(rime_slash_layers(hit.size()))

## Shattering Slam: a shield hit. All my Layers shatter into the target (it
## alone takes them), and so does my Rime Shell or Freeze on it.
func _shattering_slam(tgt: Node3D, w: Dictionary, res: Resource) -> void:
	if tgt == null or not is_instance_valid(tgt) or not tgt.is_alive():
		return
	# Taken off first, so the hits below don't break the shell again.
	var iced := player._strip_ice(tgt)   # own only: my whole shell, my freeze
	var at := tgt.global_position
	var spent := _spend_layers()
	player.frost_melee._hit_with_threat(tgt, player._weapon_hit(w, res), SHATTER_SLAM_ID, SHATTER_SLAM_THREAT)
	player._slash_effect(Abilities.color_of(SHATTER_SLAM_ID))
	if spent > 0:
		player.frost_melee._hit_with_threat(tgt, slam_layers_coef(spent, player._talent("frost_packed_ice")), SHATTER_SLAM_ID,
			SHATTER_SLAM_THREAT, "frost", PackedStringArray(["Ability", "Frost", "Melee"]))   # + Packed Ice
		player._ring_effect(0.6 + 0.15 * spent, LAYER_COLOR, at)
	if iced.is_empty():
		return
	player.frost_melee._hit_with_threat(tgt, float(Abilities.EXTRA_HITS[SHATTER_SLAM_ID]), SHATTER_SLAM_ID, SHATTER_SLAM_THREAT,
		"frost", PackedStringArray(["Ability", "Frost", "Melee"]))
	# The shatter itself, on the target alone: the same routine as every other
	# shatter (under the slam's name, with the slam's threat).
	for i in iced.size():
		player.shatter_at(at, SHATTER_SLAM_ID, 1.0, tgt, SHATTER_SLAM_THREAT)

## Cold Shoulder: my target has to attack me and is Chilled; I gain a Layer.
## Turned Backs: the enemies nearest it have to attack me too.
func _cold_shoulder() -> void:
	if not player._has_valid_target():
		return
	var foe: Node3D = player.target
	var col := Abilities.color_of(COLD_SHOULDER_ID)
	var also: Array = player._enemies_near(foe.global_position, TURNED_BACKS_RANGE, foe).slice(0,
		int(round(player._talent("frost_turned_backs"))))
	for e in [foe] + also:
		player._net_taunt(e, Balance.COLD_SHOULDER_TAUNT)
		player.frost_more._chill(e, COLD_SHOULDER_ID, PackedStringArray(["Ability", "Frost"]))
		player._ring_effect(0.8, Color(1.0, 0.35, 0.25), (e as Node3D).global_position)
	_gain_layers(Balance.COLD_SHOULDER_LAYERS)
	player._slash_effect(col)

## Rimequake: everything around me is hit, harder for each Layer I hold; its Chill
## is the ability's on-hit effect.
func _rimequake(res: Resource) -> void:
	var hit := player._enemies_within(float(res.radius))
	var coef := float(res.damage) * Balance.aoe_share(hit.size()) \
		* quake_mult(layers(), Balance.RIMEQUAKE_PCT_PER_LAYER)
	for e in hit:
		if is_instance_valid(e) and e.is_alive():
			player.deal_damage(e, coef, RIMEQUAKE_ID)
	player._ring_effect(float(res.radius), Abilities.color_of(RIMEQUAKE_ID))
	player._ring_effect(float(res.radius) * 0.5, Color(0.95, 0.97, 1.0))
