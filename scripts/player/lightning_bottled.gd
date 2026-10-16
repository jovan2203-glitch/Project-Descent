extends "res://scripts/player/player_kit.gd"
class_name BottledLightningKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "bottled_kit".
# --- Rune of Bottled Lightning, and the talents Standing Charge, Whip Crack and Storm Cycle ---
const BOTTLED_RUNE := "bottled_lightning"
const BOTTLED_FX := "bottled_lightning"
const STANDING_FX := "standing_charge"
const WHIP_CRACK_FX := "whip_crack"
const STORM_CYCLE_FX := "storm_cycle"
var _bottled_cast := false      # the current Discharge cast is the instant one (Rune of Bottled Lightning)
var _standing_fx: Resource
var _standing_t := 0.0          # seconds planted since the last Standing Charge stack
var _cycle_spent := 0.0         # Energy spent toward the next Storm Cycle

## Is `spell` the Discharge that the Rune of Bottled Lightning makes instant?
func bottled_ready(spell: String) -> bool:
	return spell == LightningCasterKit.DISCHARGE_ID and player.status != null and player.status.has(BOTTLED_FX)

## I took my Energy back out of the Capacitor: with the rune, my next Discharge is instant.
func _bottle_lightning() -> void:
	if not player._has_rune(BOTTLED_RUNE):
		return
	var fx := StatusContainer.make_buff(BOTTLED_FX, "Bottled Lightning", BOTTLED_FX, 0.0,
		Balance.BOTTLED_LIGHTNING_TIME, 1, Abilities.color_of(LightningCasterKit.DISCHARGE_ID))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Lightning"])
	fx.description = "Your next %s is instant." % Abilities.ability_name(LightningCasterKit.DISCHARGE_ID)
	player.status.apply(fx, player)

## Standing Charge's buff at `pct` % Lightning damage per stack (rebuilt when the rank changes).
func _standing_buff(pct: float) -> Resource:
	if _standing_fx == null or not is_equal_approx(float(_standing_fx.stat_modifiers.get(STANDING_FX, 0.0)), pct):
		_standing_fx = StatusContainer.make_buff(STANDING_FX, "Standing Charge", STANDING_FX, pct,
			Balance.GROUNDING_SURGE_TIME + 1.0, Balance.STANDING_CHARGE_MAX_STACKS, Abilities.color_of(LightningCasterKit.SURGE_ID))
		_standing_fx.tags = PackedStringArray(["Lightning"])
		_standing_fx.description = "Your Lightning damage is increased by %s%% per stack. Lost when %s ends." % [
			Stats.num(pct), Abilities.ability_name(LightningCasterKit.SURGE_ID)]
	return _standing_fx

## Every frame: planted in Grounding Surge, Standing Charge adds a stack each
## STANDING_CHARGE_EVERY seconds; the moment the Surge ends they are all gone.
func _tick_standing_charge(delta: float) -> void:
	if player.status == null:
		return
	if not player.lightning_caster.surge_active():
		_standing_t = 0.0
		if player.status.has(STANDING_FX):
			player.status.remove(STANDING_FX)
		return
	var pct := player._talent("lightning_standing_charge")
	if pct <= 0.0:
		return
	_standing_t += delta
	if _standing_t >= Balance.STANDING_CHARGE_EVERY:
		_standing_t -= Balance.STANDING_CHARGE_EVERY
		player.status.apply(_standing_buff(pct), player)

## % more Lightning damage Standing Charge gives me right now.
func standing_charge_bonus() -> float:
	return player.status.stat_mod(STANDING_FX) if player.status != null else 0.0

## Whip Crack: did a Whiplash from `distance` metres away earn it?
static func whip_crack_applies(distance: float) -> bool:
	return distance > Balance.WHIP_CRACK_DISTANCE

## Energy Static Step costs with Whip Crack taking `less` off it (never below 0).
static func whip_crack_cost(cost: float, less: float) -> float:
	return maxf(cost - maxf(less, 0.0), 0.0)

## Whip Crack: my Whiplash landed from far away. Static Step is ready again,
## and the next one costs less.
func _whip_crack() -> void:
	var less := player._talent("lightning_whip_crack")
	if less <= 0.0:
		return
	player.cooldowns.erase(LightningMeleeKit.STATIC_STEP_ID)
	var fx := player.lightning_melee._melee_buff(WHIP_CRACK_FX, LightningMeleeKit.WHIPLASH_ID, Balance.WHIP_CRACK_TIME,
		"Your next %s costs %s less Energy." % [Abilities.ability_name(LightningMeleeKit.STATIC_STEP_ID), Stats.num(less)])
	fx.display_name = "Whip Crack"
	player.status.apply(fx, player)

## Storm Cycle: `spent` Energy counted so far plus `amount` more, against a cycle
## of `need`: [Energy carried into the next cycle, did a cycle complete].
static func storm_cycle_step(spent: float, amount: float, need: float) -> Array:
	if need <= 0.0:
		return [0.0, false]
	var total := spent + maxf(amount, 0.0)
	if total + 0.0001 >= need:
		return [minf(total - need, need), true]
	return [total, false]

## Is my next Energy cost free (Storm Cycle)?
func storm_cycle_ready() -> bool:
	return player.status != null and player.status.has(STORM_CYCLE_FX)

## I spent `amount` Energy: Storm Cycle counts it, and a full cycle makes my next Energy cost free.
func _storm_cycle_spent(amount: float) -> void:
	var need := player._talent("lightning_storm_cycle")
	if need <= 0.0 or amount <= 0.0 or player.status == null:
		return
	var step := storm_cycle_step(_cycle_spent, amount, need)
	_cycle_spent = float(step[0])
	if bool(step[1]):
		var fx := StatusContainer.make_buff(STORM_CYCLE_FX, "Storm Cycle", STORM_CYCLE_FX, 0.0,
			Balance.STORM_CYCLE_TIME, 1, Abilities.color_of(LightningCasterKit.DISCHARGE_ID))
		fx.stat_modifiers = {}
		fx.tags = PackedStringArray(["Lightning"])
		fx.description = "Your next Energy cost is free."
		player.status.apply(fx, player)

## My hits and ticks, for the Lightning kit (SignalBus.damage_dealt).
func _on_damage_dealt_lightning(info: RefCounted) -> void:
	if not is_same(info.source, player) or info.avoided() or not is_instance_valid(info.target):
		return
	var id := str(info.ability_id)
	player.lightning_caster._conductor(info, id)   # Conductor: Lightning crits give Energy back
	if id == "auto_melee" or id == "auto_ranged":
		player.lightning_melee._on_auto_landed(info)   # Twin Current, Overdrive
	elif id == "lightningbolt":
		player.storm_arrow_kit._lightning_rod_arc(info)   # Lightning Rod: it arcs off a target with my Storm Arrow in it
	elif id == LightningCasterKit.LIVE_WIRE_ID:
		_wire_landed(info.target)
	elif id == "dot_" + LightningCasterKit.LIVE_WIRE_FX:
		player._gain("energy", Balance.LIVE_WIRE_ENERGY)   # every tick of the tether gives Energy back

## My Live Wire landed on `foe`: the tether is on it now, and off anyone else.
func _wire_landed(foe: Node) -> void:
	if not (foe is Node3D):
		return
	if is_instance_valid(player.storm_arrow_kit._wire_target) and player.storm_arrow_kit._wire_target != foe:
		_drop_wire_effect(player.storm_arrow_kit._wire_target)   # only one tether at a time
	player.storm_arrow_kit._wire_target = foe
	player.storm_arrow_kit._wire_since = Time.get_ticks_msec() / 1000.0
	var fx: Resource = Abilities.get_resource(LightningCasterKit.LIVE_WIRE_ID).on_hit_effect
	var time := float(fx.duration) if fx else 10.0
	player.storm_arrow_kit._wire_line = StormArrowKit.LIVE_WIRE.spawn(player.get_tree().current_scene, player, foe, time + StormArrowKit.WIRE_GRACE, "me")
	player._net_fx(LightningCasterKit.LIVE_WIRE_ID, player.global_position, foe, {"time": time})   # the party sees the line

## Take my Live Wire off `foe` (in a party the host owns enemy effects).
func _drop_wire_effect(foe: Node) -> void:
	var net := player._net()
	if net:
		net.remove_effect(foe, player, LightningCasterKit.LIVE_WIRE_FX)
	else:
		var st: Node = foe.get_node_or_null("Status")
		if st:
			st.remove_from(LightningCasterKit.LIVE_WIRE_FX, player)

## Is a tether to an enemy `distance` metres away broken?
static func wire_breaks(distance: float) -> bool:
	return distance > Balance.LIVE_WIRE_RANGE

## Every frame: the tether ends when its target dies, when the effect has run its
## time, or when I move too far away (that takes the effect off too).
func _tick_live_wire() -> void:
	if player.storm_arrow_kit._wire_target == null:
		return
	var gone: bool = not is_instance_valid(player.storm_arrow_kit._wire_target) or not player.storm_arrow_kit._wire_target.is_alive() or player.is_dead()
	if not gone:
		var st: Node = player.storm_arrow_kit._wire_target.get_node_or_null("Status")
		var since := Time.get_ticks_msec() / 1000.0 - player.storm_arrow_kit._wire_since
		if since > StormArrowKit.WIRE_GRACE and (st == null or not st.has_from(LightningCasterKit.LIVE_WIRE_FX, player)):
			gone = true
		elif wire_breaks(player.global_position.distance_to(player.storm_arrow_kit._wire_target.global_position)):
			_drop_wire_effect(player.storm_arrow_kit._wire_target)
			gone = true
	if gone:
		player.storm_arrow_kit._wire_target = null
		if is_instance_valid(player.storm_arrow_kit._wire_line):
			player.storm_arrow_kit._wire_line.vanish()
		player.storm_arrow_kit._wire_line = null

## Thunderhead: the circle was clicked, the cast starts.
func _start_thunderhead(point: Vector3) -> void:
	if player.casting or not player.is_on_floor():
		return
	if not player.can_afford(LightningCasterKit.THUNDERHEAD_ID, true):
		return
	player.cast_point = point
	var res := Abilities.get_resource(LightningCasterKit.THUNDERHEAD_ID)
	player._begin_spell(LightningCasterKit.THUNDERHEAD_ID, str(res.display_name), float(res.cast_time))

func _raise_thunderhead() -> void:
	var res := Abilities.get_resource(LightningCasterKit.THUNDERHEAD_ID)
	player.cooldowns[LightningCasterKit.THUNDERHEAD_ID] = Abilities.cooldown_of(res)
	var tick := maxf(Balance.THUNDERHEAD_TICK / player.haste_mult(), 0.1)   # strikes come faster with Haste
	StormArrowKit.THUNDERHEAD.spawn(player.get_tree().current_scene, player.cast_point, float(res.radius), Balance.THUNDERHEAD_TIME, tick,
		player, float(res.damage))
	# The party sees the cloud; its damage comes from here.
	player._net_fx(LightningCasterKit.THUNDERHEAD_ID, player.cast_point, null, {"r": float(res.radius), "time": Balance.THUNDERHEAD_TIME, "tick": tick})

## Damage coefficients of a Forked Bolt's hits: two prongs of `damage` when there
## is a second enemy to fork to, one bigger hit when there isn't.
static func forked_bolt_hits(damage: float, has_other: bool) -> Array[float]:
	var out: Array[float] = []
	if has_other:
		out.append(damage)
		out.append(damage)
	else:
		out.append(Balance.FORKED_BOLT_SOLO)
	return out

## Forked Bolt's cast finished: the target, and the nearest other enemy in reach of it.
func _forked_bolt(tgt: Node3D) -> void:
	var res := Abilities.get_resource(LightningCasterKit.FORKED_BOLT_ID)
	var near := player._enemies_near(tgt.global_position, float(res.radius), tgt)
	var hits := forked_bolt_hits(float(res.damage), not near.is_empty())
	var scene := player.get_tree().current_scene
	Player.FROST_BOLT.spawn(scene, player._muzzle(), tgt, player, false, LightningCasterKit.FORKED_BOLT_ID, hits[0])
	if hits.size() > 1:
		# (The second prong is dealt as a proc, so one cast counts once for
		# anything that counts casts: Static, runes that count hits.)
		Player.FROST_BOLT.spawn(scene, player._muzzle(), near[0], player, true, LightningCasterKit.FORKED_BOLT_ID, hits[1])

## Flicker: a blink (it stops short of walls) that makes my next Lightning Bolt instant.
func _flicker() -> void:
	var col := Abilities.color_of(LightningCasterKit.FLICKER_ID)
	var from := player.global_position
	player.global_position += player._flat_forward() * player._dash_distance(Balance.FLICKER_DISTANCE + player._talent("arcane_long_step"))   # Long Step
	player._ring_effect(0.8, col, from)
	player._ring_effect(0.8, col)
	_parting_spark(from)   # Parting Spark: a zap around the spot I left
	player.storm_arrow_kit._snap_shot()           # Snap Shot: Storm Arrow is ready again, and cheaper
	player.arcane_caster._leave_afterimage(from)   # Rune of the Afterimage
	var fx := StatusContainer.make_buff(LightningCasterKit.FLICKER_FX, Abilities.ability_name(LightningCasterKit.FLICKER_ID), LightningCasterKit.FLICKER_FX, 0.0,
		Balance.FLICKER_TIME, 1, col)
	fx.stat_modifiers = {}
	fx.description = "Your next %s is instant." % Abilities.ability_name("lightningbolt")
	player.status.apply(fx, player)

## Parting Spark: Flicker zaps the enemies around the spot it left (a proc: it
## feeds nothing else). More than AOE_TARGET_CAP enemies share that many hits.
func _parting_spark(from: Vector3) -> void:
	var coef := player._talent("lightning_parting_spark")
	if coef <= 0.0:
		return
	var hit := player._enemies_near(from, Balance.PARTING_SPARK_RADIUS)
	if hit.is_empty():
		return
	coef *= Balance.aoe_share(hit.size())
	for e in hit:
		if is_instance_valid(e) and e.is_alive():
			player.deal_damage(e, coef, LightningCasterKit.PARTING_SPARK_ID, true, "lightning", PackedStringArray(["Lightning", "Spell"]))
	player._ring_effect(Balance.PARTING_SPARK_RADIUS, Abilities.color_of(LightningCasterKit.FLICKER_ID), from)

## Energy that doesn't fit when the Capacitor gives `stored` back to a bar with
## `room` left in it.
static func capacitor_overflow(stored: float, room: float) -> float:
	return maxf(stored - maxf(room, 0.0), 0.0)

## Overflow: the shield (as a coefficient: 1.0 = a standard hit's worth of
## health) that `energy` turns into at `per` per ENERGY_STEP Energy.
static func overflow_coef(energy: float, per: float) -> float:
	return maxf(per, 0.0) * maxf(energy, 0.0) / Balance.ENERGY_STEP

## Overflow: Energy the Capacitor couldn't give back becomes a shield on me. It
## never stacks, and never shrinks a bigger one that is still up.
func _overflow(energy: float) -> void:
	var coef := overflow_coef(energy, player._talent("lightning_overflow"))
	if coef <= 0.0:
		return
	var amount := int(round(player._combat().heal_amount(player, coef, LightningCasterKit.CAPACITOR_ID) * player.absorb_mult()))
	if amount <= 0:
		return
	var fx := StatusContainer.make_buff(LightningCasterKit.OVERFLOW_FX, "Overflow", LightningCasterKit.CAPACITOR_FX, 0.0,
		Balance.OVERFLOW_TIME, 1, Abilities.color_of(LightningCasterKit.CAPACITOR_ID))
	var armor := player._talent("frost_shield_armor")   # Hardened Frost: my shields add armor
	fx.stat_modifiers = {"armor%": armor} if armor > 0.0 else {}
	fx.tags = PackedStringArray(["Lightning"])
	fx.description = "A shield of Energy that didn't fit absorbs damage."
	var total := maxi(int(player.status.absorb_left(LightningCasterKit.OVERFLOW_FX)), amount)
	if player.status.apply(fx, player):
		player.status.set_absorb(LightningCasterKit.OVERFLOW_FX, total)

## Is `spell` the Lightning Bolt that Flicker makes instant?
func flicker_ready(spell: String) -> bool:
	return spell == "lightningbolt" and player.status != null and player.status.has(LightningCasterKit.FLICKER_FX)

## Energy the Capacitor takes out of a bar holding `energy`.
static func capacitor_takes(energy: float) -> float:
	return clampf(energy, 0.0, Balance.CAPACITOR_MAX)

## Capacitor: instant and off the global cooldown. The first use puts my Energy
## aside; using it again while it holds gives the Energy back (what doesn't fit
## in the bar is lost). Left alone, what it holds is lost when it runs out.
func _capacitor() -> void:
	var col := Abilities.color_of(LightningCasterKit.CAPACITOR_ID)
	if player.status.has(LightningCasterKit.CAPACITOR_FX):
		var room := player.resource_max("energy") - float(player.resources["energy"])
		player._gain("energy", player.storm_arrow_kit._capacitor_stored)
		_overflow(capacitor_overflow(player.storm_arrow_kit._capacitor_stored, room))   # Overflow: what didn't fit becomes a shield
		player.storm_arrow_kit._capacitor_stored = 0.0
		player.status.remove(LightningCasterKit.CAPACITOR_FX)
		_bottle_lightning()   # Rune of Bottled Lightning: my next Discharge is instant
		player.storm_arrow_kit._load_quiver()        # Loaded Quiver: my next Storm Arrows are free
		player._ring_effect(0.8, col)
		return
	if float(player.cooldowns.get(LightningCasterKit.CAPACITOR_ID, 0.0)) > 0.0:
		player._error("%s is not ready yet" % Abilities.ability_name(LightningCasterKit.CAPACITOR_ID))
		return
	var take := capacitor_takes(float(player.resources["energy"]))
	if take < 1.0:
		player._error("No Energy to store")
		return
	var res := Abilities.get_resource(LightningCasterKit.CAPACITOR_ID)
	player.cooldowns[LightningCasterKit.CAPACITOR_ID] = Abilities.cooldown_of(res)
	player.resources["energy"] = float(player.resources["energy"]) - take
	player.storm_arrow_kit._capacitor_stored = take
	var fx := StatusContainer.make_buff(LightningCasterKit.CAPACITOR_FX, str(res.display_name), LightningCasterKit.CAPACITOR_FX, 0.0,
		Balance.CAPACITOR_TIME, 1, col)
	fx.stat_modifiers = {}
	fx.description = "Holds %d Energy. Use %s again to take it back." % [int(round(take)), str(res.display_name)]
	player.status.apply(fx, player)
	player._ring_effect(1.0, col)
	player._bus().cast_finished.emit(LightningCasterKit.CAPACITOR_ID)

