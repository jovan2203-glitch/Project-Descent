extends "res://scripts/player/player_kit.gd"
class_name WeaverKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "weaver".
# --- Nature caster: the Weaver ------------------------------------------------------------------
# Creatures woven of vines or grown from the ground, each here for one strike
# (the picture: scripts/nature_creature.gd). Woven ones (Briar Tiger, Thornwing)
# leave a patch of mulch on the ground where they strike (scripts/mulch_patch.gd);
# rooted finishers (Mossback, Choking Vipers) use up every patch of mine near
# their target and grow with each; Greenwood Stag carries every patch to the
# target. Thornshot is the filler: thorns also burst from my patches near its
# target (Thornburst), and every few that land leave a patch. Own only: the
# party sees my patches faint and nothing of theirs touches mine. Numbers:
# balance.gd (MULCH_* and the rest). Talents: Hunting Party (Briar Tiger),
# Compost (Thornshot), Bramble Burst (Thornburst), Rich Soil, Long Roots, Well
# Rotted and Harvest (both finishers), Second Growth (Mossback), Fertile Ground
# (Choking Vipers), Circling Hawk (Thornwing), Thick Mulch and Leaf Litter (the
# patches' time), Quickening (a patch speeds up the next cast) and Overgrown (my
# Nature spells, per patch: nature_talents_open.gd asks it; its capstone here).
# The hit bonuses of the woven and rooted creatures: nature_talents_open.gd.

const MULCH = preload("res://scripts/mulch_patch.gd")
const NATURE_CREATURE = preload("res://scripts/nature_creature.gd")
const THORNSHOT_ID := "thornshot"
const BRIAR_TIGER_ID := "briartiger"
const MOSSBACK_ID := "mossback"
const THORNWING_ID := "thornwing"
const VIPERS_ID := "chokingvipers"
const STAG_ID := "greenwoodstag"
## The instants of the kit (_use_drafted -> _weaver_use).
const WEAVER_INSTANTS := [MOSSBACK_ID, THORNWING_ID, VIPERS_ID, STAG_ID]
## Meter / log id of Thornburst (its own line: Details.HIT_NAMES).
const THORNBURST_ID := "thornburst"
const THORNBURST_TAGS := ["Nature", "Spell", "AoE"]
const VIPERS_TAGS := ["Nature", "Spell", "DoT"]
const CHOKED_FX := preload("res://data/effects/choked.tres")
## The Mulch buff on me (one stack per patch).
const MULCH_FX := "mulch"
## Quickening's buff: my next Nature spell with a cast time is faster.
const QUICKENING_FX := "quickening"

var _mulch: Array = []            # my patches, oldest first: {"key", "pos", "until", "at" (laid)}
var _mulch_seq := 0
var _mulch_told := 0.0
var _thornshots_landed := 0       # Thornshots that landed (every THORNSHOT_PATCH_EVERY-th leaves a patch)
var _tigers := 0                  # Briar Tigers cast (Hunting Party's capstone: every second one)
var _vipers: Array = []           # Choking Vipers on enemies: {"target", "coef", "ticks", "next", "every"}
var _mulch_fx: Resource = null

## My patches: [{"key", "pos" (on the ground), "until"}].
func mulch() -> Array:
	return _mulch

# Rules as static functions (tests/test_nature.gd).

## Indices of the `spots` within `reach` of `at` (flat distance).
static func mulch_within(spots: Array, at: Vector3, reach: float) -> Array:
	var out := []
	for i in spots.size():
		var p: Vector3 = spots[i]
		if Vector2(p.x - at.x, p.z - at.z).length() <= reach:
			out.append(i)
	return out

## A rooted finisher's damage (coefficient): its own `base`, + `per` for each of `patches`.
static func rooted_coef(base: float, per: float, patches: int) -> float:
	return base + per * maxi(patches, 0)

## Indices of the `points` (enemies) within `radius` of any of the `spots`: each once.
static func near_any(points: Array, spots: Array, radius: float) -> Array:
	var out := []
	for i in points.size():
		var e: Vector3 = points[i]
		for s in spots:
			var p: Vector3 = s
			if Vector2(p.x - e.x, p.z - e.z).length() <= radius:
				out.append(i)
				break
	return out

## Where the stag sets `n` patches down around `center`: one alone in the middle, more in a ring.
static func stag_spots(n: int, center: Vector3, ring: float) -> Array:
	var out := []
	if n <= 0:
		return out
	if n == 1:
		return [center]
	for i in n:
		var a := TAU * i / n
		out.append(center + Vector3(cos(a) * ring, 0.0, sin(a) * ring))
	return out

## How many ticks Choking Vipers makes with `haste` (a multiplier: 1.2 = 20% Haste).
## Each tick is the same size, so Haste makes more of them.
static func vipers_ticks(haste: float) -> int:
	return maxi(int(round(Balance.VIPERS_TIME * maxf(haste, 0.01) / Balance.VIPERS_TICK)), 1)

## Is the `n`-th Briar Tiger (from 1) one that Hunting Party's capstone doubles up?
static func hunting_party_turn(n: int) -> bool:
	return n > 0 and n % 2 == 0

## Every how many Thornshots that land leave a patch (Compost: fewer).
static func thornshot_patch_every(compost: bool) -> int:
	return Balance.COMPOST_PATCH_EVERY if compost else Balance.THORNSHOT_PATCH_EVERY

## What one patch adds to a finisher (`per`) with Rich Soil's `pct` %.
static func rich_soil_per(per: float, pct: float) -> float:
	return per * (1.0 + maxf(pct, 0.0) / 100.0)

## Overgrown: % more damage for my Nature spells with `patches` patches out.
static func overgrown_pct(per_patch: float, patches: int) -> float:
	return maxf(per_patch, 0.0) * maxi(patches, 0)

## Does a finisher that used `used` patches cut Thornwing's cooldown (Circling Hawk)?
static func circling_hawk_turn(used: int) -> bool:
	return used >= Balance.CIRCLING_HAWK_PATCHES

## Thornburst: [damage coefficient, radius] with Bramble Burst's `pct` % and its capstone.
static func thornburst_with(pct: float, capstone: bool) -> Array:
	return [Balance.THORNBURST_DAMAGE * (1.0 + maxf(pct, 0.0) / 100.0),
		Balance.BRAMBLE_BURST_RADIUS if capstone else Balance.THORNBURST_RADIUS]

## A roll of `pct` % (Second Growth, Fertile Ground): `roll` is 0-100.
static func rolls(pct: float, roll: float) -> bool:
	return pct > 0.0 and roll < pct

## Seconds a patch lies on the ground (`thick`: Thick Mulch's).
static func mulch_life(thick: float) -> float:
	return Balance.MULCH_TIME + maxf(thick, 0.0)

## Well Rotted: what `aged` old patches add on top to a finisher (`per` each, `pct` % more).
static func well_rotted_coef(per: float, aged: int, pct: float) -> float:
	return per * maxi(aged, 0) * maxf(pct, 0.0) / 100.0

## Harvest: mana a finisher that cost `cost` and used `used` patches gives back (`pct` %).
static func harvest_mana(cost: float, used: int, pct: float) -> float:
	return maxf(cost, 0.0) * maxf(pct, 0.0) / 100.0 if used >= Balance.HARVEST_PATCHES else 0.0

## Quickening: a cast of `duration` with `pct` % off.
static func quickening_cast(duration: float, pct: float) -> float:
	return duration * (1.0 - clampf(pct, 0.0, 100.0) / 100.0)

func _mulch_spots() -> Array:
	var out := []
	for p in _mulch:
		out.append(p["pos"])
	return out

func _ground_under(who: Node3D) -> Vector3:
	return Vector3(who.global_position.x, Combat.feet_y(who), who.global_position.z)

## A new patch at `at`. Past MULCH_MAX, my oldest goes.
func _add_mulch(at: Vector3) -> void:
	_mulch_seq += 1
	var key := "m%d" % _mulch_seq
	var now := Time.get_ticks_msec() / 1000.0
	_mulch.append({"key": key, "pos": at, "until": now + mulch_life(player._talent("nature_thick_mulch")), "at": now})   # + Thick Mulch
	while _mulch.size() > Balance.MULCH_MAX:
		var old: Dictionary = _mulch.pop_front()
		if player.is_inside_tree():
			MULCH.remove(player.get_tree(), "me:" + str(old["key"]))
	_sync_mulch()
	# Quickening: my next Nature spell with a cast time is faster.
	if player._talent("nature_quickening") > 0.0 and player.status != null:
		var fx := StatusContainer.make_buff(QUICKENING_FX, "Quickening", QUICKENING_FX, 0.0, Balance.QUICKENING_TIME, 1, MULCH.GLOW)
		fx.stat_modifiers = {}
		fx.tags = PackedStringArray(["Nature"])
		fx.description = "Your next Nature spell with a cast time casts faster."
		player.status.apply(fx, player)

## Quickening: my cast of `spell` (`duration` sec so far) with its buff used up.
func quickening(spell: String, duration: float) -> float:
	var pct := player._talent("nature_quickening")
	var tags := Abilities.tags_of(spell)
	if pct <= 0.0 or player.status == null or not player.status.has(QUICKENING_FX) or not (tags.has("Nature") and tags.has("Spell")):
		return duration
	player.status.remove(QUICKENING_FX)
	return quickening_cast(duration, pct)

## Use up every patch within reach of `at` (MULCH_REACH, + Long Roots): returns
## [how many, the middle of where they were, how many lay long enough for Well Rotted].
func _use_mulch(at: Vector3) -> Array:
	var used := mulch_within(_mulch_spots(), at, Balance.MULCH_REACH + player._talent("nature_long_roots"))   # + Long Roots
	var mid := Vector3.ZERO
	var now := Time.get_ticks_msec() / 1000.0
	var aged := 0
	for j in range(used.size() - 1, -1, -1):
		var p: Dictionary = _mulch[int(used[j])]
		mid += p["pos"]
		if now - float(p.get("at", now)) >= Balance.WELL_ROTTED_AGE:
			aged += 1
		if player.is_inside_tree():
			MULCH.remove(player.get_tree(), "me:" + str(p["key"]))
		_mulch.remove_at(int(used[j]))
	if not used.is_empty():
		mid /= used.size()
		_sync_mulch()
	return [used.size(), mid, aged]

## A finisher (`id`) used `used` patches, `aged` of them old: its damage with the
## talents that look at them (Rich Soil, Well Rotted), and Harvest's and
## Circling Hawk's rewards.
func _finisher_coef(id: String, base: float, per: float, used: int, aged: int) -> float:
	var each := rich_soil_per(per, player._talent("nature_rich_soil"))   # + Rich Soil
	_circling_hawk(used)
	player._gain("mana", harvest_mana(player.resource_cost(id), used, player._talent("nature_harvest")))   # Harvest
	return rooted_coef(base, each, used) + well_rotted_coef(each, aged, player._talent("nature_well_rotted"))   # + Well Rotted

## Overgrown's capstone: a finisher that used every patch leaves one behind.
func _overgrown_leaves(used: int, at: Vector3) -> void:
	if used >= Balance.OVERGROWN_PATCHES and player.frost_melee._capstone("nature_overgrown"):
		_add_mulch(at)

func _tick_weaver() -> void:
	_tick_vipers()
	if _mulch.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var gone := false
	for i in range(_mulch.size() - 1, -1, -1):
		if now >= float(_mulch[i]["until"]):
			MULCH.remove(player.get_tree(), "me:" + str(_mulch[i]["key"]))
			_mulch.remove_at(i)
			gone = true
			# Leaf Litter: a patch that ran out unused gives mana back.
			var litter := player._talent("nature_leaf_litter")
			if litter > 0.0 and not player.is_dead():
				player._gain("mana", player.resource_max("mana") * litter / 100.0)
	if gone:
		_sync_mulch()
	elif now - _mulch_told >= PrismsKit.PRISM_RETELL:
		_tell_mulch()

## The picture of my patches (and the party is told, so they see them faint).
func _sync_mulch() -> void:
	_sync_mulch_buff()
	if not player.is_inside_tree():
		return
	var keys := []
	for p in _mulch:
		var key := "me:" + str(p["key"])
		keys.append(key)
		MULCH.place(player.get_tree().current_scene, key, p["pos"], true)
	MULCH.keep_only(player.get_tree(), "me:", keys)
	_tell_mulch()

func _tell_mulch() -> void:
	_mulch_told = Time.get_ticks_msec() / 1000.0
	var list := []
	for p in _mulch:
		var pos: Vector3 = p["pos"]
		list.append([str(p["key"]), pos.x, pos.y, pos.z])
	player._net_fx("mulch", player.global_position, null, {"p": list})

## A creature of `kind` from `start` to strike at `end` (here, and faint for the party).
func _creature(kind: String, start: Vector3, end: Vector3) -> void:
	if not player.is_inside_tree():
		return
	NATURE_CREATURE.spawn(player.get_tree().current_scene, kind, start, end)
	player._net_fx("creature", start, null, {"k": kind, "to": end})

## After `delay` sec, `strike` runs (a creature's hit lands when its picture strikes).
func _after(delay: float, strike: Callable) -> void:
	if not player.is_inside_tree():
		strike.call()
		return
	player.get_tree().create_timer(delay).timeout.connect(strike)

## A woven creature (`kind`) strikes `enemy` for `coef`, then leaves a patch where it struck.
func _woven_strike(kind: String, enemy: Node3D, coef: float, id: String, is_proc: bool = false) -> void:
	var spot := _ground_under(enemy)
	_creature(kind, player._muzzle() if player.is_inside_tree() else player.global_position, enemy.global_position + Vector3(0, 0.6, 0))
	_after(Balance.WOVEN_STRIKE_DELAY, func():
		if player.is_dead():
			return
		if is_instance_valid(enemy) and enemy.is_alive():
			spot = _ground_under(enemy)
			player.deal_damage(enemy, coef, id, is_proc)
		_add_mulch(spot))

## Briar Tiger's cast finished (from _release_cast).
func _briar_tiger(enemy: Node3D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var coef := float(Abilities.get_resource(BRIAR_TIGER_ID).damage) * (1.0 + player._talent("nature_hunting_party") / 100.0)   # Hunting Party
	_tigers += 1
	_woven_strike("tiger", enemy, coef, BRIAR_TIGER_ID)
	if player.frost_melee._capstone("nature_hunting_party") and hunting_party_turn(_tigers):
		# Hunting Party's capstone: more tigers, at other enemies near the target.
		var others := player._enemies_near(enemy.global_position, Balance.HUNTING_PARTY_RADIUS, enemy)
		for i in mini(others.size(), Balance.HUNTING_PARTY_EXTRA):
			_woven_strike("tiger", others[i], coef, BRIAR_TIGER_ID, true)

## A Thornshot landed on `enemy` (from _on_hit_extra): Thornburst, and every few a patch.
func _thornshot_landed(enemy: Node, at: Vector3) -> void:
	var near := mulch_within(_mulch_spots(), at, Balance.MULCH_REACH)
	if not near.is_empty():
		var spots := []
		for i in near:
			spots.append(_mulch[int(i)]["pos"])
		# Bramble Burst: harder, and with its capstone further.
		var burst := thornburst_with(player._talent("nature_bramble_burst"), player.frost_melee._capstone("nature_bramble_burst"))
		var radius := float(burst[1])
		var foes := player._enemies_near(at, Balance.MULCH_REACH + radius)
		var points := []
		for e in foes:
			points.append((e as Node3D).global_position)
		var hit := near_any(points, spots, radius)
		var share := Balance.aoe_share(hit.size())
		for i in hit:
			player.deal_damage(foes[int(i)], float(burst[0]) * share, THORNBURST_ID, true, "nature", PackedStringArray(THORNBURST_TAGS))
		for s in spots:
			player._ring_effect(radius * 0.5, MULCH.GLOW, s)
	_thornshots_landed += 1
	if _thornshots_landed % thornshot_patch_every(player._talent("nature_compost") > 0.0) == 0 and enemy is Node3D:   # Compost
		_add_mulch(_ground_under(enemy))

## One of the kit's instants (paid for and put on cooldown by _use_drafted).
func _weaver_use(id: String, res: Resource) -> void:
	if not player._has_valid_target():
		return
	var enemy: Node3D = player.target
	var foot := _ground_under(enemy)
	match id:
		THORNWING_ID:
			_woven_strike("hawk", enemy, float(res.damage), id)
		MOSSBACK_ID:
			_mossback(enemy, foot)   # (the mouseover path: the mulch near the enemy)
		VIPERS_ID:
			_choking_vipers(foot)
		STAG_ID:
			var start: Vector3 = _mulch[_mulch.size() - 1]["pos"] if not _mulch.is_empty() else player.global_position
			_creature("stag", start, foot)
			_after(Balance.ROOTED_STRIKE_DELAY, func():
				if player.is_dead():
					return
				var alive: bool = is_instance_valid(enemy) and enemy.is_alive()
				if alive:
					player.deal_damage(enemy, float(res.damage), id)
				_stag_carry(_ground_under(enemy) if alive else foot))

## Greenwood Stag: every patch of mine moves to `center` (each keeps its time).
func _stag_carry(center: Vector3) -> void:
	var spots := stag_spots(_mulch.size(), center, Balance.MULCH_RING)
	for i in _mulch.size():
		_mulch[i]["pos"] = spots[i]
	_sync_mulch()

## Choking Vipers on `enemy`: `coef` in all over VIPERS_TIME, in equal ticks
## (Haste: more of them). Recasting on the same enemy starts it over.
func _start_vipers(enemy: Node, coef: float) -> void:
	for i in range(_vipers.size() - 1, -1, -1):
		if _vipers[i]["target"] == enemy:
			_vipers.remove_at(i)
	var base_ticks := maxi(int(round(Balance.VIPERS_TIME / Balance.VIPERS_TICK)), 1)
	var every := Balance.VIPERS_TICK / player.haste_mult()
	_vipers.append({"target": enemy, "coef": coef / base_ticks, "ticks": vipers_ticks(player.haste_mult()),
		"next": Time.get_ticks_msec() / 1000.0 + every, "every": every, "pos": _ground_under(enemy as Node3D)})

func _tick_vipers() -> void:
	if _vipers.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	for i in range(_vipers.size() - 1, -1, -1):
		var v: Dictionary = _vipers[i]
		var e: Variant = v["target"]
		if int(v["ticks"]) <= 0:
			_vipers.remove_at(i)
			continue
		if e == null or not is_instance_valid(e) or not e.is_alive():
			_vipers.remove_at(i)
			# Fertile Ground: it died with my vipers on it.
			if rolls(player._talent("nature_fertile_ground"), randf() * 100.0):
				_add_mulch(v["pos"])
			continue
		v["pos"] = _ground_under(e as Node3D)
		if now < float(v["next"]):
			continue
		v["ticks"] = int(v["ticks"]) - 1
		v["next"] = float(v["next"]) + float(v["every"])
		var info = player._combat().ability_hit_info(player, e, float(v["coef"]), VIPERS_ID, true, "nature", PackedStringArray(VIPERS_TAGS))
		info.is_dot = true
		player._combat().deal(info)

## Mossback / Choking Vipers pressed: with the mouse over a legal enemy
## (mouseover casting), straight at it with the mulch near it; otherwise a
## circle to place on the patches to use (pressing it again puts it away).
func _use_finisher(id: String) -> void:
	if player.placing and player.placing_id == id:
		player.cancel_placement()
		return
	player.cancel_placement()
	if _finisher_mouseover():
		player._use_drafted(id)
		return
	player._begin_placement(id)

## Is the enemy under the mouse my target for this press (mouseover casting)?
func _finisher_mouseover() -> bool:
	if not player.mouseover_on() or not player.is_inside_tree():
		return false
	var cam := player.get_viewport().get_camera_3d()
	if cam == null:
		return false
	var e: Node3D = player._enemy_at(player.get_viewport().get_mouse_position(), cam)
	return e != null and e == player.target

## Why the finisher's circle can't go down at `point` ("" = it can).
func _finisher_place_error(id: String, point: Vector3) -> String:
	if Vector2(point.x - player.global_position.x, point.z - player.global_position.z).length() > float(Abilities.get_resource(id).cast_range):
		return "Out of range"
	if id == MOSSBACK_ID:
		if not player._has_valid_target():
			return "No target"
		var sight := player._target_error(player.target)
		if sight != "":
			return sight
		if player.global_position.distance_to(player.target.global_position) > float(Abilities.get_resource(id).cast_range):
			return "Target out of range"
	elif player._enemies_near(point, float(Abilities.get_resource(id).radius)).is_empty():
		return "No enemies there"
	return ""

## The circle went down at `point`: the finisher uses the patches inside it.
func _start_finisher(id: String, point: Vector3) -> void:
	var err := _finisher_place_error(id, point)
	if err != "":
		player._error(err)
		return
	if not player._pay(id):
		return
	if Player.on_gcd(id):
		player._start_gcd()
	var center := Vector3(point.x, Combat.feet_y(player), point.z)
	if id == MOSSBACK_ID:
		_mossback(player.target, center)
	else:
		_choking_vipers(center)
	player._bus().cast_finished.emit(id)

## Mossback: the patches within MULCH_REACH of `center` grow a bear that mauls `enemy`.
func _mossback(enemy: Node3D, center: Vector3) -> void:
	var res := Abilities.get_resource(MOSSBACK_ID)
	var foot := _ground_under(enemy)
	var used := _use_mulch(center)
	var coef := _finisher_coef(MOSSBACK_ID, float(res.damage), Balance.MOSSBACK_PER_PATCH, int(used[0]), int(used[2]))
	var start: Vector3 = used[1] if int(used[0]) > 0 else foot + (player.global_position - foot).normalized() * 1.5
	_creature("bear", start, foot)
	_after(Balance.ROOTED_STRIKE_DELAY, func():
		if not player.is_dead() and is_instance_valid(enemy) and enemy.is_alive():
			foot = _ground_under(enemy)
			player.deal_damage(enemy, coef, MOSSBACK_ID)
			# Second Growth: the bear may leave a patch where it struck.
			if rolls(player._talent("nature_second_growth"), randf() * 100.0):
				_add_mulch(foot)
		if not player.is_dead():
			_overgrown_leaves(int(used[0]), foot))

## Circling Hawk: a finisher that used enough patches takes time off Thornwing.
func _circling_hawk(used: int) -> void:
	var cut := player._talent("nature_circling_hawk")
	if cut > 0.0 and circling_hawk_turn(used):
		player.arcane_caster._cut_cooldown(THORNWING_ID, cut)

## Choking Vipers: the patches within MULCH_REACH of `center` feed vipers that
## choke every enemy within its radius of `center` (split past the AoE cap).
func _choking_vipers(center: Vector3) -> void:
	var res := Abilities.get_resource(VIPERS_ID)
	var used := _use_mulch(center)
	var total := _finisher_coef(VIPERS_ID, float(res.damage), Balance.VIPERS_PER_PATCH, int(used[0]), int(used[2]))
	var foes := player._enemies_near(center, float(res.radius))
	var coef := total * Balance.aoe_share(foes.size())
	for e in foes:
		_creature("viper", _ground_under(e), (e as Node3D).global_position)
		player._combat().apply_effect(player, e, CHOKED_FX, VIPERS_ID, PackedStringArray(VIPERS_TAGS))
		player.nature_open.firm_hold_fury()   # Firm Hold: a hold of mine went on
		_start_vipers(e, coef)
	_overgrown_leaves(int(used[0]), center)

## The Mulch buff on me: one stack per patch (gone with the last one).
func _sync_mulch_buff() -> void:
	if player.status == null:
		return
	var n := _mulch.size()
	if n <= 0:
		player.status.remove(MULCH_FX)
		return
	if _mulch_fx == null:
		_mulch_fx = StatusContainer.make_buff(MULCH_FX, "Mulch", Stats.BLOCK, 0.0, Balance.MULCH_TIME, Balance.MULCH_MAX, MULCH.GLOW)
		_mulch_fx.stat_modifiers = {}
		_mulch_fx.show_time = false
		_mulch_fx.tags = PackedStringArray(["Nature"])
		_mulch_fx.description = "Patches of mulch your woven creatures left. Mossback and Choking Vipers use up the ones near where they strike."
	player.status.apply(_mulch_fx, player)
	if player.status.stacks_of(MULCH_FX) != n:
		player.status.set_stacks(MULCH_FX, n)

