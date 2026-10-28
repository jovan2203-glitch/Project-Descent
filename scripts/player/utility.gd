extends "res://scripts/player/player_kit.gd"
class_name UtilityKit

# Hooked up from player.gd through its var "utility".
# --- Utility: each book's "Utility" divider ----------------------------------------------------
# Abilities anyone might take for the job they do, whatever they play (CLAUDE.md):
# - A root for every book, each working differently: Rootsnare (Nature: the
#   target and enemies near it), Cooling Slag (Fire: a pool that slows, then
#   hardens), Static Snare (Lightning: leaps on once it ends), Fixed Point
#   (Arcane: longer for each Arcane spell on cooldown), Binding Ring (Holy: a
#   ring around an ally roots the first enemies to come close). Frost (Icepin)
#   and Shadow (Tangle) had theirs already.
# - Tools, each with a rider only one spec of its book cashes in: Deep Roots
#   (Nature: less damage, Sap every second: the Colossus), Spore Sleep (Nature:
#   sleep until hit; Asp Venom when it wakes: Venomstring), Leaf Cloak (Nature:
#   threat dropped, then none for a while), Bellows (Fire: knockback; Heat for
#   each enemy thrown: Forge Heat), Storm Front (Lightning: party speed; Energy for
#   each ally), Climb the String (Shadow: hauls you to your target; a loose String
#   on an ally: Strings Attached), Circle of Silence (Holy: an interrupt that keeps
#   enemies inside it from casting), Holy Ground (Holy: a circle on the ground no
#   enemy can step into).
# Other books' utility (interrupts, blinks, defensives) is coded with its book;
# the "Utility" divider only shows it there (Abilities.SPECS).
# Enemies live on the host: effects go through CombatSystem, knockbacks through
# Net.drag, threat through Net.drop_threat, interrupts through Net.interrupt.
# Numbers: balance.gd (Utility section).

const ROOTSNARE_ID := "rootsnare"
const DEEP_ROOTS_ID := "deeproots"
const SPORE_SLEEP_ID := "sporesleep"
const LEAF_CLOAK_ID := "leafcloak"
const COOLING_SLAG_ID := "coolingslag"
const BELLOWS_ID := "bellows"
const STATIC_SNARE_ID := "staticsnare"
const STORM_FRONT_ID := "stormfront"
const FIXED_POINT_ID := "fixedpoint"
const BINDING_RING_ID := "bindingring"
const CIRCLE_OF_SILENCE_ID := "circleofsilence"
const CLIMB_STRING_ID := "climbthestring"
const HOLY_GROUND_ID := "holyground"   # (placed: Player._unhandled_input -> start_holy_ground)
## Instants (_use_drafted -> use).
const INSTANTS := [ROOTSNARE_ID, DEEP_ROOTS_ID, LEAF_CLOAK_ID, BELLOWS_ID, STORM_FRONT_ID,
	STATIC_SNARE_ID, FIXED_POINT_ID, BINDING_RING_ID, CIRCLE_OF_SILENCE_ID, CLIMB_STRING_ID]
## Cast at an enemy (Player.ENEMY_BOLTS -> finish_cast).
const CASTS := [SPORE_SLEEP_ID, COOLING_SLAG_ID]
const NATURE_TAGS := ["Nature", "Spell"]

# Effects on enemies (data/effects/*.tres).
const ROOTSNARED_FX := preload("res://data/effects/rootsnared.tres")
const ASLEEP_FX := preload("res://data/effects/asleep.tres")
const MOLTEN_SLAG_FX := preload("res://data/effects/molten_slag.tres")
const SLAGBOUND_FX := preload("res://data/effects/slagbound.tres")
const STATIC_SNARED_FX := preload("res://data/effects/static_snared.tres")
const FIXED_FX := preload("res://data/effects/fixed.tres")
const RINGBOUND_FX := preload("res://data/effects/ringbound.tres")
# Buffs on players (made here).
const DEEP_ROOTS_FX := "deep_roots"
const STORM_FRONT_FX := "storm_front"
const LEAF_CLOAK_FX := "leaf_cloak"

const NATURE_GREEN := Color(0.45, 0.9, 0.4)
const SLAG_ORANGE := Color(1.0, 0.5, 0.15)
const SLAG_GREY := Color(0.6, 0.5, 0.45)
const STATIC_BLUE := Color(0.55, 0.75, 1.0)
const ARCANE_VIOLET := Color(0.75, 0.55, 1.0)
const HOLY_GOLD := Color(1.0, 0.88, 0.45)
const FORGE_ORANGE := Color(1.0, 0.6, 0.25)
const STRING_VIOLET := Color(0.65, 0.4, 0.9)
const PULSE_EVERY := 0.5   # seconds between the rings that show a pool / a Binding Ring / a Circle of Silence
const SILENCE_CHECK := 0.1   # seconds between a Circle of Silence's looks for casts inside it

const NOT_SLEEPABLE := "Too strong to put to sleep"
const NO_CLIMB_TARGET := "No target"

var _deep_roots_on := false
var _deep_roots_next := 0.0
var _sleepers: Array = []   # enemies I put to sleep (Asp Venom when they wake)
var _snares: Array = []     # {"e", "until"}: Static Snares that will leap on when they end
var _pools: Array = []      # {"pos", "r", "harden", "next"}: Cooling Slag pools
var _rings: Array = []      # {"who", "until", "left", "hit", "next"}: Binding Rings
var _silences: Array = []   # {"pos", "r", "until", "next"}: Circles of Silence
var _grounds: Array = []    # {"pos", "r", "until", "next", "ring"}: Holy Grounds

# Rules as static functions (tests/test_utility.gd).

## Can Spore Sleep take an enemy of this rank? (Bosses and elites: no.)
static func sleepable(rank: String) -> bool:
	return rank != "boss" and rank != "elite"

## Fixed Point's root time with `cooling` other Arcane spells of mine on cooldown.
static func fixed_point_time(cooling: int) -> float:
	return minf(Balance.FIXED_POINT_TIME + Balance.FIXED_POINT_PER_COOLDOWN * maxi(cooling, 0), Balance.FIXED_POINT_MAX)

## Heat Bellows gives for throwing `thrown` enemies (1 each, capped).
static func bellows_heat(thrown: int) -> int:
	return clampi(thrown, 0, Balance.BELLOWS_HEAT_MAX)

## Where Climb the String sets me down: STRING_CLIMB_STOP short of `to`, on the way from `from` (flat).
static func climb_spot(from: Vector3, to: Vector3) -> Vector3:
	var d := Vector3(to.x - from.x, 0.0, to.z - from.z)
	if d.length() <= Balance.CLIMB_STRING_STOP:
		return from
	return Vector3(to.x, from.y, to.z) - d.normalized() * Balance.CLIMB_STRING_STOP

## Where Bellows throws an enemy standing at `at` (away from `me`, flat).
static func thrown_to(at: Vector3, me: Vector3, push: float) -> Vector3:
	var away := Vector3(at.x - me.x, 0.0, at.z - me.z)
	if away.length() < 0.01:
		away = Vector3(0, 0, -1)
	return at + away.normalized() * push

## The enemy a Static Snare leaps to from `from`: the nearest other within reach (-1 = none).
static func leap_pick(from: Vector3, spots: Array, reach: float) -> int:
	var best := -1
	var best_d := reach
	for i in spots.size():
		var p: Vector3 = spots[i]
		var d := Vector2(p.x - from.x, p.z - from.z).length()
		if d <= best_d:
			best_d = d
			best = i
	return best

## Fixed Point: its root lasts longer for each Arcane spell on cooldown (Player.effect_duration_bonus).
func duration_bonus(res: Resource) -> float:
	if res != null and str(res.id) == str(FIXED_FX.id):
		return fixed_point_time(player.arcane_caster.arcane_cooldowns(FIXED_POINT_ID)) - Balance.FIXED_POINT_TIME
	return 0.0

## Leaf Cloak: my damage makes no threat for a while after it.
func no_threat() -> bool:
	return player.status != null and player.status.has(LEAF_CLOAK_FX)

## Why a utility cast at `tgt` can't start ("" = it can).
func cast_error(id: String, tgt: Node) -> String:
	if id == SPORE_SLEEP_ID and tgt != null and not sleepable(str(tgt.get("rank"))):
		return NOT_SLEEPABLE
	return ""

## Why a utility instant can't be used right now ("" = it can).
func precheck(id: String) -> String:
	if id == CLIMB_STRING_ID:
		var to := climb_target()
		if to == null:
			return NO_CLIMB_TARGET
		if player.global_position.distance_to(to.global_position) > float(Abilities.get_resource(id).cast_range):
			return "Target out of range"
		if player.lightning_caster.surge_active():
			return "You can't move during %s" % Abilities.ability_name(LightningCasterKit.SURGE_ID)
		return player._target_error(to)
	return ""

## Who Climb the String hauls me to: my friendly target (not me), else my enemy target.
func climb_target() -> Node3D:
	if player.has_friendly_target() and not is_same(player.friendly_target, player):
		return player.friendly_target
	if player._has_valid_target():
		return player.target
	return null

func use(id: String, res: Resource) -> void:
	match id:
		ROOTSNARE_ID:
			_rootsnare(player.target, float(res.radius))
		BELLOWS_ID:
			_bellows(float(res.radius))
		DEEP_ROOTS_ID:
			_deep_roots()
		STORM_FRONT_ID:
			_storm_front(float(res.radius))
		CIRCLE_OF_SILENCE_ID:
			_circle_of_silence(player.target, float(res.radius))
		CLIMB_STRING_ID:
			_climb_the_string(climb_target())
		LEAF_CLOAK_ID:
			_leaf_cloak(float(res.radius))
		STATIC_SNARE_ID:
			_static_snare(player.target)
		FIXED_POINT_ID:
			_root(player.target, FIXED_FX, FIXED_POINT_ID, ["Arcane", "Spell"], "arcane")
			player._ring_effect(1.2, ARCANE_VIOLET, player.target.global_position)
		BINDING_RING_ID:
			_binding_ring(player.friendly_target if player.has_friendly_target() else player)

## A cast at an enemy landed (already paid).
func finish_cast(id: String, tgt: Node3D) -> void:
	if tgt == null or not is_instance_valid(tgt) or not tgt.is_alive():
		return
	match id:
		SPORE_SLEEP_ID:
			if not sleepable(str(tgt.get("rank"))):
				return
			_root(tgt, ASLEEP_FX, SPORE_SLEEP_ID, NATURE_TAGS, "nature")
			if not _sleepers.has(tgt):
				_sleepers.append(tgt)
			player._ring_effect(1.2, NATURE_GREEN, tgt.global_position)
		COOLING_SLAG_ID:
			var r := float(Abilities.get_resource(COOLING_SLAG_ID).radius)
			var at := Vector3(tgt.global_position.x, Combat.feet_y(tgt), tgt.global_position.z)
			_pools.append({"pos": at, "r": r, "harden": _now() + Balance.COOLING_SLAG_HARDEN, "next": 0.0})

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## Put `fx` on `e`, mine (crowd control: no damage).
func _root(e: Node, fx: Resource, id: String, tags: Array, dtype: String) -> void:
	player.fire_caster._apply_effect_hit(e, fx, id, PackedStringArray(tags), dtype)

# --- Nature ---------------------------------------------------------------------------------

func _rootsnare(foe: Node3D, radius: float) -> void:
	if foe == null or not is_instance_valid(foe):
		return
	var hit: Array = [foe]
	hit.append_array(player._enemies_near(foe.global_position, radius, foe))
	for e in hit:
		_root(e, ROOTSNARED_FX, ROOTSNARE_ID, NATURE_TAGS, "nature")
	player.weaver._add_mulch(player.weaver._ground_under(foe))   # (the Weaver's finishers use it)
	player._ring_effect(radius, NATURE_GREEN, foe.global_position)

static func make_deep_roots_fx() -> Resource:
	var fx := StatusContainer.make_buff(DEEP_ROOTS_FX, "Deep Roots", DEEP_ROOTS_FX, 0.0, Balance.DEEP_ROOTS_TIME, 1, NATURE_GREEN)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Nature", "Defensive"])
	fx.damage_mod_pct = -Balance.DEEP_ROOTS_PCT
	fx.modifies_incoming = true
	fx.mod_affects_dots = true
	fx.description = "Rooted deep: you take %s%% less damage and gain Sap every second. Moving ends it." % Stats.num(Balance.DEEP_ROOTS_PCT)
	return fx

func _deep_roots() -> void:
	player.status.apply(make_deep_roots_fx(), player)
	player.status.set_remaining(DEEP_ROOTS_FX, Balance.DEEP_ROOTS_TIME)
	_deep_roots_on = true
	_deep_roots_next = _now() + 1.0
	player._ring_effect(1.4, NATURE_GREEN)


static func make_leaf_cloak_fx() -> Resource:
	var fx := StatusContainer.make_buff(LEAF_CLOAK_FX, "Leaf Cloak", LEAF_CLOAK_FX, 0.0, Balance.LEAF_CLOAK_TIME, 1, NATURE_GREEN)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Nature"])
	fx.description = "Hidden under leaves: your damage makes no threat."
	return fx

func _leaf_cloak(radius: float) -> void:
	var net := player._net()
	for e in player._enemies_within(radius):
		if net:
			net.drop_threat(e, player)
		elif e.has_method("drop_threat"):
			e.drop_threat(player)
	player.status.apply(make_leaf_cloak_fx(), player)
	player.status.set_remaining(LEAF_CLOAK_FX, Balance.LEAF_CLOAK_TIME)
	player._ring_effect(1.4, NATURE_GREEN)

# --- The other books' roots ---------------------------------------------------------------

func _static_snare(foe: Node3D) -> void:
	if foe == null or not is_instance_valid(foe):
		return
	_root(foe, STATIC_SNARED_FX, STATIC_SNARE_ID, ["Lightning", "Spell"], "lightning")
	_snares.append({"e": foe, "until": _now() + Balance.STATIC_SNARE_TIME + player.effect_duration_bonus(STATIC_SNARED_FX)})
	player._ring_effect(1.2, STATIC_BLUE, foe.global_position)

func _binding_ring(who: Node3D) -> void:
	if who == null or not is_instance_valid(who):
		return
	for r in _rings:
		if is_same(r["who"], who):
			_rings.erase(r)   # a new one on the same ally starts over
			break
	_rings.append({"who": who, "until": _now() + Balance.BINDING_RING_TIME, "left": Balance.BINDING_RING_ROOTS, "hit": {}, "next": 0.0})

# --- The other books' tools -------------------------------------------------------------------

## Bellows (Fire): every enemy near me is thrown away (bosses are too heavy);
## 1 Heat for each one thrown (Forge Heat spends it).
func _bellows(radius: float) -> void:
	var net := player._net()
	var thrown := 0
	for e in player._enemies_within(radius):
		if not is_instance_valid(e) or not e.is_alive() or str(e.get("rank")) == "boss":
			continue
		var from: Vector3 = e.global_position
		var to := thrown_to(from, player.global_position, Balance.BELLOWS_PUSH)
		if not Combat.line_of_sight(player.get_world_3d(), from + Vector3(0, 0.3, 0), to + Vector3(0, 0.3, 0)):
			continue   # (a wall right behind it: it stays put)
		if net:
			net.drag(e, to, Balance.BELLOWS_DRAG_TIME)   # the host owns enemies in a party
		elif e.has_method("drag_to"):
			e.drag_to(to, Balance.BELLOWS_DRAG_TIME)
		thrown += 1
	player.fire_melee.gain_heat(bellows_heat(thrown))
	player._ring_effect(radius, FORGE_ORANGE)
	player._ring_effect(radius * 0.5, SLAG_ORANGE)

static func make_storm_front_fx(time: float) -> Resource:
	var fx := StatusContainer.make_buff(STORM_FRONT_FX, "Storm Front", Stats.MOVE_SPEED, Balance.STORM_FRONT_PCT, time, 1, STATIC_BLUE)
	fx.tags = PackedStringArray(["Lightning"])
	fx.description = "Carried by the storm: %s%% faster movement." % Stats.num(Balance.STORM_FRONT_PCT)
	return fx

## Storm Front (Lightning): me and every ally near me move faster; Energy for each ally it reaches.
func _storm_front(radius: float) -> void:
	var others := 0
	for a in player.fire_cooldowns._allies_within(radius):
		if is_same(a, player):
			_storm_front_on(player.status, player, Balance.STORM_FRONT_TIME)
			continue
		others += 1
		if (a as Node).is_in_group("friendly"):
			_storm_front_on((a as Node).get_node_or_null("Status"), player, Balance.STORM_FRONT_TIME)
		elif player._net():
			player._net().support_ally(a, player, "storm_front", {"t": Balance.STORM_FRONT_TIME})
	if others > 0:
		player._gain("energy", Balance.STORM_FRONT_ENERGY * others)
	player._ring_effect(radius, STATIC_BLUE)

## Storm Front reached me (or a friendly dummy) from `from`.
func _storm_front_on(st: Node, from: Node, time: float) -> void:
	if st == null or time <= 0.0:
		return
	st.apply(make_storm_front_fx(time), from)
	st.set_remaining(STORM_FRONT_FX, time)

## Climb the String (Shadow): a String hauls me to my target; on an ally it stays
## tied as a loose String (Strings Attached heals through it). Only I move.
func _climb_the_string(to: Node3D) -> void:
	if to == null or not is_instance_valid(to):
		return
	var from := player.global_position
	player._ring_effect(0.8, STRING_VIOLET, from)
	player.global_position = climb_spot(from, to.global_position)
	player.velocity = Vector3.ZERO
	player._ring_effect(0.8, STRING_VIOLET)
	if not to.is_in_group("enemies"):
		player.strings._tie_loose(to)

## Circle of Silence (Holy): a circle on the ground around the target. Whatever is
## casting inside is interrupted, and nothing inside can cast while it lasts.
func _circle_of_silence(foe: Node3D, radius: float) -> void:
	if foe == null or not is_instance_valid(foe):
		return
	var at := Vector3(foe.global_position.x, Combat.feet_y(foe), foe.global_position.z)
	_silences.append({"pos": at, "r": radius, "until": _now() + Balance.CIRCLE_OF_SILENCE_TIME, "next": 0.0, "ring": 0.0})

## Interrupt every enemy casting inside the circle, locking it out for `lockout` seconds.
func _silence_inside(at: Vector3, radius: float, lockout: float, show: bool) -> void:
	var net := player._net()
	for e in player._enemies_near(at, radius):
		if e.has_method("cast_progress") and float(e.cast_progress()) < 0.0:
			continue   # not casting (the cast bar shows on every machine): nothing to send
		if net:
			net.interrupt(e, player, lockout)   # the host owns enemy casts in a party
		elif e.has_method("interrupt"):
			e.interrupt(player, lockout)
	if show:
		player._ring_effect(radius, HOLY_GOLD, at)

# --- Every frame ------------------------------------------------------------------------------

func _tick_utility() -> void:
	if not _deep_roots_on and _sleepers.is_empty() and _snares.is_empty() and _pools.is_empty() and _rings.is_empty() \
			and _silences.is_empty() and _grounds.is_empty():
		return
	var now := _now()
	_tick_deep_roots(now)
	_tick_sleepers()
	_tick_snares(now)
	_tick_pools(now)
	_tick_rings(now)
	_tick_silences(now)
	_tick_grounds(now)

## A Circle of Silence cuts off any cast started inside it (checked every
## SILENCE_CHECK seconds; enemy.interrupt only acts on an enemy that is casting).
func _tick_silences(now: float) -> void:
	var lockout := float(Balance.INTERRUPT_LOCKOUT[CIRCLE_OF_SILENCE_ID])
	for i in range(_silences.size() - 1, -1, -1):
		var s: Dictionary = _silences[i]
		if now >= float(s["until"]):
			_silences.remove_at(i)
			continue
		if now >= float(s["next"]):
			s["next"] = now + SILENCE_CHECK
			_silence_inside(s["pos"], float(s["r"]), lockout, now >= float(s.get("ring", 0.0)))
			if now >= float(s.get("ring", 0.0)):
				s["ring"] = now + PULSE_EVERY

## Holy Ground (Holy): why it can't go down now ("" if it can), at `point` if given.
func holy_ground_error(point: Variant = null) -> String:
	if player.cooldown_left(HOLY_GROUND_ID) > 0.0:
		return "%s is not ready yet" % Abilities.ability_name(HOLY_GROUND_ID)
	if point is Vector3:
		var reach := float(Abilities.get_resource(HOLY_GROUND_ID).cast_range)
		if reach > 0.0 and Vector2(point.x - player.global_position.x, point.z - player.global_position.z).length() > reach:
			return "Out of range"
	return ""

## Holy Ground lands at `point` (paid here: it is placed, like Cinder Rain).
func start_holy_ground(point: Vector3) -> void:
	var err := holy_ground_error(point)
	if err != "":
		player._error(err)
		return
	if not player._pay(HOLY_GROUND_ID):
		return
	var res := Abilities.get_resource(HOLY_GROUND_ID)
	player.cooldowns[HOLY_GROUND_ID] = float(res.cooldown)
	_grounds.append({"pos": point, "r": float(res.radius), "until": _now() + Balance.HOLY_GROUND_TIME, "next": 0.0, "ring": 0.0})
	if Player.on_gcd(HOLY_GROUND_ID):
		player._start_gcd()
	player._bus().cast_finished.emit(HOLY_GROUND_ID)

## Where an enemy at `at` inside a Holy Ground at `mid` (radius `r`) is pushed: just past its edge.
static func out_of_ground(at: Vector3, mid: Vector3, r: float) -> Vector3:
	var away := Vector3(at.x - mid.x, 0.0, at.z - mid.z)
	if away.length() < 0.01:
		away = Vector3(0, 0, -1)
	return Vector3(mid.x, at.y, mid.z) + away.normalized() * (r + 0.3)

## Every enemy that got inside a Holy Ground is pushed back out (bosses are too strong).
func _tick_grounds(now: float) -> void:
	var net := player._net()
	for i in range(_grounds.size() - 1, -1, -1):
		var g: Dictionary = _grounds[i]
		if now >= float(g["until"]):
			_grounds.remove_at(i)
			continue
		if now >= float(g["ring"]):
			g["ring"] = now + PULSE_EVERY
			player._ring_effect(float(g["r"]), HOLY_GOLD, g["pos"])
		if now < float(g["next"]):
			continue
		g["next"] = now + Balance.HOLY_GROUND_CHECK
		var mid: Vector3 = g["pos"]
		for e in player._enemies_near(mid, float(g["r"])):
			if not is_instance_valid(e) or not e.is_alive() or str(e.get("rank")) == "boss":
				continue
			var to := out_of_ground(e.global_position, mid, float(g["r"]))
			if net:
				net.drag(e, to, Balance.HOLY_GROUND_PUSH_TIME)   # the host owns enemies in a party
			elif e.has_method("drag_to"):
				e.drag_to(to, Balance.HOLY_GROUND_PUSH_TIME)

func _tick_deep_roots(now: float) -> void:
	if not _deep_roots_on:
		return
	if player.status == null or not player.status.has(DEEP_ROOTS_FX) or player.is_dead():
		_deep_roots_on = false
		return
	if Vector2(player.velocity.x, player.velocity.z).length() > 0.5:
		player.status.remove(DEEP_ROOTS_FX)   # moving ends it
		_deep_roots_on = false
		return
	if now >= _deep_roots_next:
		_deep_roots_next = now + 1.0
		player.colossus._gain_sap(Balance.DEEP_ROOTS_SAP)

## A sleeper woke (hit, or slept it off): Asp Venom (Venomstring's Venom Flow counts it).
func _tick_sleepers() -> void:
	for i in range(_sleepers.size() - 1, -1, -1):
		var e: Variant = _sleepers[i]
		if e == null or not is_instance_valid(e) or not e.is_alive():
			_sleepers.remove_at(i)
			continue
		var st: Node = (e as Node).get_node_or_null("Status")
		if st != null and st.has(str(ASLEEP_FX.id)):
			continue
		_sleepers.remove_at(i)
		player.venomstring._apply_poison(e, "asp")

## A Static Snare ran out: it leaps once to the nearest other enemy.
func _tick_snares(now: float) -> void:
	for i in range(_snares.size() - 1, -1, -1):
		var s: Dictionary = _snares[i]
		if now < float(s["until"]):
			continue
		_snares.remove_at(i)
		var from: Variant = s["e"]
		if from == null or not is_instance_valid(from):
			continue
		var others: Array = player._enemies_near((from as Node3D).global_position, Balance.STATIC_SNARE_LEAP, from)
		var spots: Array = []
		for o in others:
			spots.append((o as Node3D).global_position)
		var pick := leap_pick((from as Node3D).global_position, spots, Balance.STATIC_SNARE_LEAP)
		if pick >= 0:
			_root(others[pick], STATIC_SNARED_FX, STATIC_SNARE_ID, ["Lightning", "Spell"], "lightning")
			player._ring_effect(1.2, STATIC_BLUE, (others[pick] as Node3D).global_position)

func _tick_pools(now: float) -> void:
	for i in range(_pools.size() - 1, -1, -1):
		var p: Dictionary = _pools[i]
		var at: Vector3 = p["pos"]
		var r := float(p["r"])
		if now >= float(p["harden"]):
			for e in player._enemies_near(at, r):
				_root(e, SLAGBOUND_FX, COOLING_SLAG_ID, ["Fire", "Spell"], "fire")
			player._ring_effect(r, SLAG_GREY, at)
			_pools.remove_at(i)
			continue
		if now >= float(p["next"]):
			p["next"] = now + PULSE_EVERY
			for e in player._enemies_near(at, r):
				_root(e, MOLTEN_SLAG_FX, COOLING_SLAG_ID, ["Fire", "Spell"], "fire")
			player._ring_effect(r, SLAG_ORANGE, at)

func _tick_rings(now: float) -> void:
	for i in range(_rings.size() - 1, -1, -1):
		var ring: Dictionary = _rings[i]
		var who: Variant = ring["who"]
		if now >= float(ring["until"]) or int(ring["left"]) <= 0 or who == null or not is_instance_valid(who) or not who.is_alive():
			_rings.remove_at(i)
			continue
		var at: Vector3 = (who as Node3D).global_position
		var r := float(Abilities.get_resource(BINDING_RING_ID).radius)
		if now >= float(ring["next"]):
			ring["next"] = now + PULSE_EVERY
			player._ring_effect(r, HOLY_GOLD, at)
		for e in player._enemies_near(at, r):
			var key: int = (e as Node).get_instance_id()
			if ring["hit"].has(key) or int(ring["left"]) <= 0:
				continue
			ring["hit"][key] = true
			ring["left"] = int(ring["left"]) - 1
			_root(e, RINGBOUND_FX, BINDING_RING_ID, ["Holy", "Spell"], "holy")
