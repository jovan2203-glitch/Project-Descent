extends Node

# Data-driven boss moveset (child of a boss). Every boss in a dungeon recipe
# lists its abilities; this runs them. Host / solo only - party members see the
# telegraphs, casts and announcements through Net.
#
# Ability entry (from the recipe): {"type": "...", "name": "<names key>", ...}
# Common fields: cd (cooldown s), first (delay before first use), coef (x the
# boss's hit), color, below (only when under this share of health, 0..1).
#
#   slam      circle around the boss (radius, time). Boss stands still.
#   nova      like slam but huge and slow - run out (radius, time).
#   donut     everyone FARTHER than `inner` from the boss gets hit - get close (inner, time).
#   eruption  a circle under every player + `extra` random spots (radius, time).
#   barrage   `count` random circles all over the room (radius, time).
#   cone      frontal cone at its target (range, angle, time).
#   charge    line telegraph at a random player, then dashes along it (width, time).
#   summon    calls `count` enemies of `role` from the roster (time, interrupt).
#   big_cast  long cast that hits EVERY player hard unless interrupted (time).
#   heal      interruptible self-heal for `pct` of max health (time).
#   enrage    passive: below `below` health, attacks faster and hits harder.
#   berserk   passive, 5 Player only: `after` seconds into the fight, hits far
#             harder and attacks faster (a hard timer: balance.gd BERSERK_*).
#   soak      stack: a circle on a player; its damage (hit x up to `share_max`
#             players) is split between everyone inside (radius, time, share_max).
#             `need` n: the total is always hit x n, however many are alive.
#   spread    `count` players get a circle that follows them, then bursts on
#             everyone inside it (radius, time, count).
#   hazard    stay out: pools under players + `extra` spots that hurt every
#             `tick` s for `duration` s (radius, time = warning, duration, tick).
#   phase     passive: below `below` health, switch to phase `to` and/or call
#             `guards` {role, count} (immune until they die) or `summon` {role, count}.
#
# Any ability may carry "phase": n - it is only used in that phase (phase 1 first).
# How each one LOOKS comes from mechanic_look.gd (one shape per family).

const Names = preload("res://scripts/dungeon/names.gd")
const FX = preload("res://scripts/dungeon/boss_abilities.gd")
const Look = preload("res://scripts/dungeon/mechanic_look.gd")
const Balance = preload("res://scripts/balance.gd")

var boss: Node3D
var dungeon: Node
var abilities: Array = []
var room_center := Vector3.ZERO
var room_half := Vector2(9, 9)

var _cd: Array = []
var _next_think := 3.0
var _enraged := false
var _phase := 1
var _phase_done := {}       # index of a phase entry -> true once it happened
var _guards: Array = []     # alive guards keeping the boss immune
var _pools := 0             # stay_out pools on the floor right now
var _fight_time := 0.0      # seconds in combat (berserk)
var _berserk := false
var _berserk_warned := false

const MAX_POOLS := 12

func _net() -> Node:
	return get_node_or_null("/root/Net")

func _authority() -> bool:
	var n := _net()
	return n == null or not n.is_client()

func _ready() -> void:
	boss = get_parent() as Node3D
	for a in abilities:
		_cd.append(float(a.get("first", randf_range(4.0, 9.0))))

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _process(delta: float) -> void:
	if boss == null or not is_instance_valid(boss) or not boss.is_alive() or not _authority():
		return
	for i in _cd.size():
		_cd[i] = maxf(float(_cd[i]) - delta, 0.0)
	_check_enrage()
	_check_berserk(delta)
	_check_guards()
	if not boss.is_in_combat():
		return
	if _check_phases():
		return
	_next_think -= delta
	if _next_think > 0.0 or _busy():
		return
	_next_think = 1.0
	var tgt: Node3D = boss.top_threat()
	if tgt == null:
		return
	var order: Array = range(abilities.size())
	order.shuffle()
	var hp := float(boss.health) / maxf(float(boss.max_health), 1.0)
	for i in order:
		var a: Dictionary = abilities[i]
		var type := str(a.get("type", ""))
		if type == "enrage" or type == "phase" or type == "berserk" or float(_cd[i]) > 0.0:
			continue
		if a.has("phase") and int(a["phase"]) != _phase:
			continue
		if a.has("below") and hp > float(a["below"]):
			continue
		if not _use(a, type, tgt):
			continue
		var cd := float(a.get("cd", 12.0))
		_cd[i] = cd * (0.7 if _enraged else 1.0)
		_next_think = 1.8 if _enraged else 2.5
		return

func _busy() -> bool:
	return boss.is_casting() or _now() < float(boss.busy_until)

func _hold(seconds: float) -> void:
	boss.busy_until = _now() + seconds

func _title(a: Dictionary) -> String:
	return Names.t(str(a.get("name", "")))

## The ability's color, kept inside its family's color (mechanic_look.gd) so the
## shape and rim still read the same in every dungeon.
func _col(a: Dictionary, fallback: Color) -> Color:
	var c: Variant = a.get("color", fallback)
	var own: Color = c if c is Color else fallback
	return Look.color(Look.family(str(a.get("type", "")))).lerp(own, 0.35)

func _hit(a: Dictionary) -> float:
	return float(boss.contact_damage) * float(a.get("coef", 1.2))

## Returns false if the ability can't be used right now (e.g. target too far).
func _use(a: Dictionary, type: String, tgt: Node3D) -> bool:
	match type:
		"slam", "nova":
			var r := float(a.get("radius", 5.0 if type == "slam" else 9.0))
			if type == "slam" and boss._dist_to(tgt) > r + 2.0:
				return false
			_slam(a, r, float(a.get("time", 1.6 if type == "slam" else 2.6)))
		"donut":
			_donut(a, float(a.get("inner", 4.0)), float(a.get("time", 2.4)))
		"eruption":
			_eruption(a, float(a.get("radius", 2.2)), float(a.get("time", 1.5)), int(a.get("extra", 1)))
		"barrage":
			_barrage(a, float(a.get("radius", 2.0)), float(a.get("time", 1.6)), int(a.get("count", 6)))
		"cone":
			var rng := float(a.get("range", 8.0))
			if boss._dist_to(tgt) > rng:
				return false
			_cone(a, tgt, rng, float(a.get("angle", 70.0)), float(a.get("time", 1.3)))
		"charge":
			_charge(a, float(a.get("width", 2.2)), float(a.get("time", 1.4)))
		"summon":
			if bool(a.get("interrupt", true)) and boss.is_silenced():
				return false
			_summon(a)
		"big_cast":
			if boss.is_silenced():
				return false
			_big_cast(a)
		"heal":
			if boss.is_silenced() or float(boss.health) > float(boss.max_health) * 0.8:
				return false
			_heal(a)
		"soak":
			_soak(a, float(a.get("radius", 3.0)), float(a.get("time", 4.0)))
		"spread":
			_spread(a, float(a.get("radius", 3.0)), float(a.get("time", 4.0)), int(a.get("count", 2)))
		"hazard":
			if _pools >= MAX_POOLS:
				return false
			_hazard(a, float(a.get("radius", 2.5)), float(a.get("time", 1.2)), int(a.get("extra", 1)))
		_:
			return false
	return true

# --- Enrage (passive) --------------------------------------------------------------------

func _check_enrage() -> void:
	if _enraged:
		return
	for a in abilities:
		if str(a.get("type", "")) != "enrage":
			continue
		if float(boss.health) <= float(boss.max_health) * float(a.get("below", 0.3)):
			_enraged = true
			boss.attack_cooldown *= 0.65
			boss.move_speed *= 1.2
			boss.contact_damage *= float(a.get("damage", 1.25))
			FX.apply_enrage_look(boss)
			_announce("%s becomes enraged!" % boss.display_name, Color(1.0, 0.3, 0.2))
			var n := _net()
			if n and n.is_host():
				n.enemy_fx(boss, "enrage", null, {})
		return

## Berserk (5 Player only): a hard timer. `after` seconds into the fight the boss
## hits far harder and attacks faster; a warning comes BERSERK_WARNING s before.
## Leaving combat (a wipe or a reset) starts the clock over and ends Berserk.
func _check_berserk(delta: float) -> void:
	if not _party_mode():
		return
	if not boss.is_in_combat():
		if _fight_time > 0.0:
			_berserk_timer(0.0, 0.0, false)   # a wipe or a reset: the timer stops
		if _berserk:
			_berserk = false
			boss.attack_cooldown *= 1.0 + Balance.BERSERK_ATTACK_SPEED / 100.0
			boss.contact_damage /= Balance.BERSERK_DAMAGE
		_fight_time = 0.0
		_berserk_warned = false
		return
	if _berserk:
		return
	var started := _fight_time == 0.0
	_fight_time += delta
	for a in abilities:
		if str(a.get("type", "")) != "berserk":
			continue
		var after := float(a.get("after", 180.0))
		if started:
			_berserk_timer(after - _fight_time, after, false)
		if not _berserk_warned and _fight_time >= after - Balance.BERSERK_WARNING:
			_berserk_warned = true
			_announce("%s will go berserk in %d sec!" % [boss.display_name, int(Balance.BERSERK_WARNING)], Color(1.0, 0.3, 0.2))
		if _fight_time >= after:
			_berserk = true
			_berserk_timer(0.0, after, true)
			boss.attack_cooldown /= 1.0 + Balance.BERSERK_ATTACK_SPEED / 100.0
			boss.contact_damage *= Balance.BERSERK_DAMAGE
			FX.apply_enrage_look(boss)
			_announce("%s goes berserk!" % boss.display_name, Color(1.0, 0.15, 0.1))
			var n := _net()
			if n and n.is_host():
				n.enemy_fx(boss, "enrage", null, {})
		return

## The boss's Berserk timer here and on every party member's machine (the Boss Timer).
func _berserk_timer(left: float, total: float, on: bool) -> void:
	if boss.has_method("set_berserk"):
		boss.set_berserk(left, total, on)
	var n := _net()
	if n and n.is_host():
		n.enemy_fx(boss, "berserk", null, {"left": left, "total": total, "on": on})

func _party_mode() -> bool:
	var gm := get_node_or_null("/root/GameManager")
	return gm != null and gm.is_party_mode()

# --- Area attacks ----------------------------------------------------------------------------

func _slam(a: Dictionary, r: float, time: float) -> void:
	var at := _floor(boss.global_position)
	var col := _col(a, Color(1.0, 0.2, 0.1))
	_hold(time + 0.3)
	_announce("%s: %s!" % [boss.display_name, _title(a)])
	_circle_all(at, r, time, col)
	_after(time, func():
		boss.play_once("attack")
		var inside := func(p: Vector3) -> bool: return _flat(p, at) <= r
		_hit_where(inside, _hit(a), "boss_" + str(a.get("name", "")))
		_burst_all(at, r, col))

func _donut(a: Dictionary, inner: float, time: float) -> void:
	var at := _floor(boss.global_position)
	var col := _col(a, Color(0.8, 0.3, 1.0))
	var outer := maxf(room_half.x, room_half.y) * 1.5
	_hold(time + 0.3)
	_announce("%s: %s - get close!" % [boss.display_name, _title(a)], col)
	_circle_all(at, outer, time, col)
	_circle_all(at, inner, time, Look.color("safe"), "safe")   # the safe spot
	_after(time, func():
		boss.play_once("attack")
		var outside := func(p: Vector3) -> bool: return _flat(p, at) > inner
		_hit_where(outside, _hit(a), "boss_" + str(a.get("name", "")))
		_burst_all(at, outer * 0.6, col))

func _eruption(a: Dictionary, r: float, time: float, extra: int) -> void:
	var col := _col(a, Color(0.9, 0.85, 0.6))
	var spots: Array = []
	for b in _party():
		if b.is_alive():
			spots.append(_floor(b.global_position))
	for i in extra:
		spots.append(_random_spot())
	_announce("%s: %s - keep moving!" % [boss.display_name, _title(a)], col)
	for p in spots:
		_spot(a, p, r, time, col)

func _barrage(a: Dictionary, r: float, time: float, count: int) -> void:
	var col := _col(a, Color(1.0, 0.6, 0.2))
	_announce("%s: %s!" % [boss.display_name, _title(a)], col)
	for i in count:
		var p := _random_spot()
		var delay := randf() * 0.8
		_after(delay, func(): _spot(a, p, r, time, col))

func _spot(a: Dictionary, at: Vector3, r: float, time: float, col: Color) -> void:
	_circle_all(at, r, time, col)
	_after(time, func():
		var inside := func(p: Vector3) -> bool: return _flat(p, at) <= r
		_hit_where(inside, _hit(a), "boss_" + str(a.get("name", "")))
		_burst_all(at, r, col))

func _cone(a: Dictionary, tgt: Node3D, rng: float, angle: float, time: float) -> void:
	var at := _floor(boss.global_position)
	var dir := tgt.global_position - boss.global_position
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else -boss.global_basis.z
	var col := _col(a, Color(1.0, 0.3, 0.15))
	boss.rotation.y = atan2(-dir.x, -dir.z)
	_hold(time + 0.3)
	_announce("%s: %s!" % [boss.display_name, _title(a)], col)
	cone_telegraph(get_tree().current_scene, at, dir, rng, angle, time, col)
	var n := _net()
	if n and n.is_host():
		n.enemy_fx(boss, "cone", null, {"at": at, "dir": dir, "r": rng, "a": angle, "d": time, "c": col})
	var half := deg_to_rad(angle * 0.5)
	var in_cone := func(p: Vector3) -> bool:
		var v := p - at
		v.y = 0.0
		return v.length() <= rng and (v.length() < 0.5 or absf(dir.angle_to(v.normalized())) <= half)
	_after(time, func():
		boss.play_once("attack")
		_hit_where(in_cone, _hit(a), "boss_" + str(a.get("name", ""))))

func _charge(a: Dictionary, width: float, time: float) -> void:
	var alive: Array = []
	for b in _party():
		if b.is_alive():
			alive.append(b)
	if alive.is_empty():
		return
	var tgt: Node3D = alive.pick_random()
	var from := _floor(boss.global_position)
	var to := _clamp_room(_floor(tgt.global_position))
	var dir := to - from
	dir.y = 0.0
	if dir.length() < 1.0:
		return
	# Overshoot a little (it runs THROUGH where you stood), inside the room.
	to = _clamp_room(to + dir.normalized() * 3.0)
	var col := _col(a, Color(1.0, 0.45, 0.2))
	boss.rotation.y = atan2(-dir.x, -dir.z)
	_hold(time + 0.6)
	_announce("%s: %s!" % [boss.display_name, _title(a)], col)
	line_telegraph(get_tree().current_scene, from, to, width, time, col)
	var n := _net()
	if n and n.is_host():
		n.enemy_fx(boss, "line", null, {"at": from, "to": to, "w": width, "d": time, "c": col})
	_after(time, func():
		var t := boss.create_tween()
		t.tween_property(boss, "global_position", Vector3(to.x, boss.global_position.y, to.z), 0.35)
		var on_line := func(p: Vector3) -> bool: return _seg_dist(p, from, to) <= width * 0.5 + 0.4
		_hit_where(on_line, _hit(a), "boss_" + str(a.get("name", ""))))

# --- Phases --------------------------------------------------------------------------------

## A phase entry whose `below` was just crossed: change phase, and maybe call
## guards (immune until they die) or a wave. True if one happened this frame.
func _check_phases() -> bool:
	var hp := float(boss.health) / maxf(float(boss.max_health), 1.0)
	for i in abilities.size():
		var a: Dictionary = abilities[i]
		if str(a.get("type", "")) != "phase" or _phase_done.has(i) or hp > float(a.get("below", 0.5)):
			continue
		_phase_done[i] = true
		_phase_change(a)
		return true
	return false

func _phase_change(a: Dictionary) -> void:
	if a.has("to"):
		_phase = int(a["to"])
	if boss.is_casting() and boss._cast_tween:   # a phase change cuts any cast short
		boss._cast_tween.kill()
		boss._cast_tween = null
		boss._show_cast(false)
	var col := Look.color("guards")
	_announce("%s: %s!" % [boss.display_name, _title(a)], col)
	_burst_all(_floor(boss.global_position), 4.0, col)
	_hold(1.2)
	_next_think = 1.5
	if a.has("guards") and dungeon and dungeon.has_method("summon_adds"):
		var g: Dictionary = a["guards"]
		var made: Array = dungeon.summon_adds(boss.global_position, int(g.get("count", 2)),
			str(g.get("role", "defender")), boss)
		if not made.is_empty():
			_guards = made
			boss.mechanic_immune = true
			Look.guards(boss, made)
			var n := _net()
			if n and n.is_host():
				var ids: Array = []
				for e in made:
					ids.append(n.enemy_id(e))
				n.enemy_fx(boss, "guards", null, {"ids": ids})
			_announce("%s is shielded - kill the guards!" % boss.display_name, col)
	if a.has("summon") and dungeon and dungeon.has_method("summon_adds"):
		var s: Dictionary = a["summon"]
		dungeon.summon_adds(boss.global_position, int(s.get("count", 3)), str(s.get("role", "swarmer")), boss,
			room_center, room_half)

## Immune while any guard lives.
func _check_guards() -> void:
	if not boss.mechanic_immune:
		return
	for g in _guards:
		if is_instance_valid(g) and g.is_inside_tree() and g.is_alive():
			return
	_guards.clear()
	boss.mechanic_immune = false
	Look.guards_end(boss)
	var n := _net()
	if n and n.is_host():
		n.enemy_fx(boss, "guards_end", null, {})
	_announce("%s's guards are down!" % boss.display_name, Look.color("safe"))

# --- Stack, spread, stay out ------------------------------------------------------------------

## What each player standing in a stack circle takes: the total (the hit x up to
## `share_max` players) split evenly between everyone in it. Nobody in it = every
## player takes the whole total. Never 0.
## `need` > 0: the total is hit x `need`, or x everyone alive once fewer are
## (a short group can't soak it; after a death the rest still can, all together).
static func soak_share(hit: float, alive: int, inside: int, share_max := 3, need := 0) -> float:
	var total := hit * float(clampi(need, 1, maxi(alive, 1)) if need > 0 else clampi(alive, 1, maxi(share_max, 1)))
	return maxf(total / float(inside), 1.0) if inside > 0 else maxf(total, 1.0)

## Stack: a circle on a player (it moves with them); stand in it together.
func _soak(a: Dictionary, r: float, time: float) -> void:
	var alive := _alive()
	if alive.is_empty():
		return
	var who: Node3D = alive.pick_random()
	_announce("%s: %s - stack together!" % [boss.display_name, _title(a)], Look.color("stack"))
	Look.stack(get_tree().current_scene, _floor(who.global_position), r, time, who)
	var n := _net()
	if n and n.is_host():
		n.enemy_fx(boss, "stack", who, {"at": _floor(who.global_position), "r": r, "d": time})
	_after(time, func():
		var at := _floor(who.global_position) if is_instance_valid(who) else _floor(boss.global_position)
		var bodies := _alive()
		var inside: Array = bodies.filter(func(b): return _flat(b.global_position, at) <= r)
		var need := int(a.get("need", 0)) if _party_mode() else 0
		var share := soak_share(_hit(a), bodies.size(), inside.size(), int(a.get("share_max", 3)), need)
		var id := "boss_" + str(a.get("name", ""))
		for b in (inside if not inside.is_empty() else bodies):
			boss.deal_melee_hit(b, share, id)
		_burst_all(at, r, Look.color("stack")))

## Spread: up to `count` players get a circle that follows them, then bursts on
## everyone inside it (overlapping circles hit twice).
func _spread(a: Dictionary, r: float, time: float, count: int) -> void:
	var alive := _alive()
	alive.shuffle()
	var marked: Array = alive.slice(0, maxi(mini(count, alive.size()), 1))
	if marked.is_empty():
		return
	var col := Look.color("spread")
	_announce("%s: %s - spread out!" % [boss.display_name, _title(a)], col)
	var n := _net()
	for who in marked:
		Look.spread(get_tree().current_scene, who, r, time)
		if n and n.is_host():
			n.enemy_fx(boss, "spread", who, {"r": r, "d": time})
	_after(time, func():
		var id := "boss_" + str(a.get("name", ""))
		for who in marked:
			if not is_instance_valid(who):
				continue
			var at := _floor(who.global_position)
			var inside := func(p: Vector3) -> bool: return _flat(p, at) <= r
			_hit_where(inside, _hit(a), id)
			_burst_all(at, r, col))

## Stay out: pools land under players (+ `extra` random spots) after a short
## warning, then hurt anyone standing in them every `tick` s for `duration` s.
func _hazard(a: Dictionary, r: float, time: float, extra: int) -> void:
	var spots: Array = []
	for b in _alive():
		spots.append(_floor(b.global_position))
	for i in extra:
		spots.append(_random_spot())
	var duration := float(a.get("duration", 10.0))
	var tick := maxf(float(a.get("tick", 1.0)), 0.25)
	var tint := _col(a, Look.color("stay_out"))
	_announce("%s: %s!" % [boss.display_name, _title(a)], Look.color("stay_out"))
	var placed := 0
	for p in spots:
		if _pools >= MAX_POOLS:
			break
		_pools += 1
		placed += 1
		_circle_all(p, r, time, tint)
		_after(time, func():
			Look.pool(get_tree().current_scene, p, r, duration, tint)
			var n := _net()
			if n and n.is_host():
				n.enemy_fx(boss, "pool", null, {"at": p, "r": r, "d": duration, "c": tint})
			_pool_tick(a, p, r, tick, duration))
	# A pool always frees its slot, even if the boss dies first.
	get_tree().create_timer(time + duration).timeout.connect(func(): _pools = maxi(_pools - placed, 0))

func _pool_tick(a: Dictionary, at: Vector3, r: float, tick: float, left: float) -> void:
	if left <= 0.0:
		return
	var inside := func(p: Vector3) -> bool: return _flat(p, at) <= r
	_hit_where(inside, _hit(a), "boss_" + str(a.get("name", "")))
	_after(tick, func(): _pool_tick(a, at, r, tick, left - tick))

func _alive() -> Array:
	return _party().filter(func(b): return is_instance_valid(b) and b.is_alive())

# --- Casts (interruptible) --------------------------------------------------------------

func _cast(a: Dictionary, time: float, done: Callable) -> void:
	var title := _title(a)
	boss.cast_name = title
	_hold(time)
	boss._show_cast(true, time)
	var n := _net()
	if n and n.is_host():
		n.enemy_fx(boss, "cast", null, {"d": time, "n": title})
	var t := boss.create_tween()
	boss._cast_tween = t
	t.tween_interval(time)
	t.tween_callback(func():
		boss._cast_tween = null
		boss._show_cast(false)
		if is_instance_valid(boss) and boss.is_alive():
			done.call())

func _summon(a: Dictionary) -> void:
	var count := int(a.get("count", 3))
	var role := str(a.get("role", "swarmer"))
	var go := func():
		if dungeon and dungeon.has_method("summon_adds"):
			dungeon.summon_adds(boss.global_position, count, role, boss, room_center, room_half)
	if bool(a.get("interrupt", true)):
		_announce("%s begins %s - interrupt it!" % [boss.display_name, _title(a)], Color(0.8, 0.6, 1.0))
		_cast(a, float(a.get("time", 2.5)), go)
	else:
		_announce("%s: %s!" % [boss.display_name, _title(a)], Color(0.8, 0.6, 1.0))
		go.call()

func _big_cast(a: Dictionary) -> void:
	var col := _col(a, Color(0.9, 0.4, 1.0))
	_announce("%s is casting %s - INTERRUPT!" % [boss.display_name, _title(a)], col)
	_cast(a, float(a.get("time", 3.0)), func():
		var everyone := func(_p: Vector3) -> bool: return true
		_hit_where(everyone, _hit(a), "boss_" + str(a.get("name", "")))
		_burst_all(_floor(boss.global_position), maxf(room_half.x, room_half.y), col))

func _heal(a: Dictionary) -> void:
	_announce("%s begins %s - interrupt it!" % [boss.display_name, _title(a)], Color(0.45, 1.0, 0.5))
	_cast(a, float(a.get("time", 2.5)), func():
		var amount := maxi(int(round(float(boss.max_health) * float(a.get("pct", 0.12)))), 1)
		boss.receive_heal(amount)
		get_node("/root/CombatSystem").float_text(boss, "+%d" % amount, Color(0.45, 1.0, 0.45), true))

# --- Helpers ------------------------------------------------------------------------------

func _after(seconds: float, f: Callable) -> void:
	get_tree().create_timer(seconds).timeout.connect(func():
		if is_instance_valid(boss) and boss.is_alive():
			f.call())

func _party() -> Array:
	var n := _net()
	if n:
		return n.party_bodies()
	return get_tree().get_nodes_in_group("player")

func _floor(p: Vector3) -> Vector3:
	return Vector3(p.x, room_center.y, p.z)

func _flat(p: Vector3, q: Vector3) -> float:
	return Vector2(p.x - q.x, p.z - q.z).length()

func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var pa := Vector2(p.x - a.x, p.z - a.z)
	var ba := Vector2(b.x - a.x, b.z - a.z)
	var t := clampf(pa.dot(ba) / maxf(ba.length_squared(), 0.001), 0.0, 1.0)
	return (pa - ba * t).length()

func _random_spot() -> Vector3:
	return room_center + Vector3(randf_range(-room_half.x + 1.5, room_half.x - 1.5), 0,
		randf_range(-room_half.y + 1.5, room_half.y - 1.5))

func _clamp_room(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, room_center.x - room_half.x + 1.2, room_center.x + room_half.x - 1.2), room_center.y,
		clampf(p.z, room_center.z - room_half.y + 1.2, room_center.z + room_half.y - 1.2))

## Damage every living player whose position passes `test`.
func _hit_where(test: Callable, amount: float, id: String) -> void:
	for b in _party():
		if not is_instance_valid(b) or not b.is_alive():
			continue
		if test.call(b.global_position):
			boss.deal_melee_hit(b, amount, id)

func _circle_all(at: Vector3, r: float, time: float, col: Color, fam := "avoid") -> void:
	Look.area(get_tree().current_scene, at, r, time, fam, col)
	var n := _net()
	if n and n.is_host():
		n.enemy_fx(boss, "telegraph", null, {"at": at, "r": r, "d": time, "c": col, "f": fam})

func _burst_all(at: Vector3, r: float, col: Color) -> void:
	FX.burst(get_tree().current_scene, at, r, col)
	var n := _net()
	if n and n.is_host():
		n.enemy_fx(boss, "burst", null, {"at": at, "r": r, "c": col})

func _announce(text: String, col: Color = Color(1.0, 0.45, 0.35)) -> void:
	if dungeon and dungeon.has_method("_announce"):
		dungeon._announce(text, col)
	var n := _net()
	if n and n.is_host():
		n.enemy_fx(boss, "announce", null, {"t": text, "c": col})

# --- Telegraph shapes (also drawn on party members' machines) ------------------------------

static func _mat(col: Color, a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(col, a)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## Cone on the floor: faint wedge + a bright wedge growing outwards until it hits.
static func cone_telegraph(scene: Node, at: Vector3, dir: Vector3, rng: float, angle: float, time: float, col: Color) -> void:
	if scene == null:
		return
	var root := Node3D.new()
	scene.add_child(root)
	root.global_position = at + Vector3(0, 0.06, 0)
	root.rotation.y = atan2(dir.x, dir.z)
	var mk := func(radius: float, mat: Material) -> MeshInstance3D:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var half := deg_to_rad(angle * 0.5)
		var steps := 16
		for i in steps:
			var a0 := -half + 2.0 * half * float(i) / steps
			var a1 := -half + 2.0 * half * float(i + 1) / steps
			st.add_vertex(Vector3.ZERO)
			st.add_vertex(Vector3(sin(a0), 0, cos(a0)) * radius)
			st.add_vertex(Vector3(sin(a1), 0, cos(a1)) * radius)
		var m := MeshInstance3D.new()
		m.mesh = st.commit()
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(m)
		return m
	mk.call(rng, _mat(col, 0.22))
	var fill: MeshInstance3D = mk.call(rng, _mat(col, 0.42))
	fill.position.y = 0.01
	fill.scale = Vector3(0.01, 1, 0.01)
	var t := root.create_tween()
	t.tween_property(fill, "scale", Vector3.ONE, time)
	t.tween_callback(root.queue_free)

## Line on the floor from `from` to `to`, `width` wide; the fill runs along it.
static func line_telegraph(scene: Node, from: Vector3, to: Vector3, width: float, time: float, col: Color) -> void:
	if scene == null:
		return
	var dir := to - from
	dir.y = 0.0
	var length := dir.length()
	if length < 0.1:
		return
	var root := Node3D.new()
	scene.add_child(root)
	root.global_position = from + Vector3(0, 0.06, 0)
	root.rotation.y = atan2(dir.x, dir.z)
	var bg := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, 0.02, length)
	bg.mesh = bm
	bg.material_override = _mat(col, 0.22)
	bg.position = Vector3(0, 0, length * 0.5)
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bg)
	var pivot := Node3D.new()
	root.add_child(pivot)
	var fill := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(width, 0.03, length)
	fill.mesh = fm
	fill.material_override = _mat(col, 0.45)
	fill.position = Vector3(0, 0.01, length * 0.5)
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(fill)
	pivot.scale = Vector3(1, 1, 0.01)
	var t := root.create_tween()
	t.tween_property(pivot, "scale", Vector3.ONE, time)
	t.tween_callback(root.queue_free)
