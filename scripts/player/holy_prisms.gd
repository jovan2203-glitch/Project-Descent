extends "res://scripts/player/player_kit.gd"
class_name PrismsKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "prism_kit".
# --- Holy healer: the Prisms ------------------------------------------------------------------
# The second Holy healer (nothing to do with the Hymns). I place up to PRISM_MAX
# floating prisms (the picture: scripts/prism.gd). My direct heals send a beam
# from me to the ally (scripts/light_beam.gd); every prism of mine the beam
# passes through stores part of the heal as light, and the heal is stronger for
# each. Shattering a prism heals the allies around it with its light (split
# evenly) and hurts the enemies there. My heals never target a prism: only
# Shatter Prism and Infuse do (the prism under the mouse with mouseover
# casting, the one I clicked, or else my closest). Realign and Move Prism move
# them (they flicker out and in). Own only: only my beams charge my prisms; the
# party sees them. Numbers are in balance.gd; the talents (Clear Glass, Deep
# Crystal, Sharp Facets, Wide Burst, Prismatic Burst, Quick Realign) in talents.gd.

const PRISM = preload("res://scripts/prism.gd")
const LIGHT_BEAM = preload("res://scripts/light_beam.gd")
const SET_PRISM_ID := "setprism"
const MOVE_PRISM_ID := "moveprism"
const MENDING_RAY_ID := "mendingray"
const BRIGHT_LANCE_ID := "brightlance"
const GLEAM_ID := "gleam"
const PRISM_WARD_ID := "prismward"
const PIERCING_LIGHT_ID := "piercinglight"
const REALIGN_ID := "realign"
const SHATTER_PRISM_ID := "shatterprism"
const SHATTER_ALL_ID := "shatterall"
const INFUSE_ID := "infuse"
const KALEIDOSCOPE_ID := "kaleidoscope"
## The instants of the kit (_use_drafted -> _prism_use).
const PRISM_INSTANTS := [MOVE_PRISM_ID, GLEAM_ID, PRISM_WARD_ID, SHATTER_PRISM_ID, SHATTER_ALL_ID, INFUSE_ID, KALEIDOSCOPE_ID]
## Abilities used on one of my prisms.
const PRISM_TARGET_IDS := [SHATTER_PRISM_ID, INFUSE_ID, "prismbreaker", "stepoflight"]
const PRISM_WARD_FX := "prism_ward"
const KALEIDOSCOPE_FX := "kaleidoscope"
## Meter / log id of a shattering prism's heal and damage (its own line: Details.HIT_NAMES).
const PRISM_SHATTER_ID := "prism_shatter"
const PRISM_LIGHT := Color(0.95, 0.97, 1.0)
const PRISM_RETELL := 3.0
## How close (on screen) the mouse has to be to a prism to pick it.
const PRISM_PICK_PX := 40.0

var _prisms: Array = []           # my prisms, oldest first: {"key", "pos", "light", "until"}
var _prism_seq := 0
var prism_target := ""            # the key of the prism I clicked ("" = none)
var _prisms_told := 0.0
var _ray_who: Variant = null      # Mending Ray: who it heals ...
var _ray_left := 0                # ... and the ticks it has left

## My prisms: [{"key", "pos" (on the ground), "light", "until"}].
func prisms() -> Array:
	return _prisms

## Is `p` on the beam from `from` to `to`? Within `width` metres of the line
## (seen from above) and between the two ends.
static func on_beam(from: Vector3, to: Vector3, p: Vector3, width: float) -> bool:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var q := Vector2(p.x, p.z)
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.0001:
		return false
	var t := (q - a).dot(ab) / len2
	if t <= 0.0 or t >= 1.0:
		return false
	return q.distance_to(a + ab * t) <= width

## The most light a prism holds (`deep` = Deep Crystal's %), as a heal coefficient.
static func prism_cap(deep: float) -> float:
	return Balance.PRISM_CAP_HEALS * Balance.REFERENCE_HEAL * (1.0 + maxf(deep, 0.0) / 100.0)

## A prism's light after a beam carrying `coef` passes through it.
static func prism_charged(light: float, coef: float, cap: float) -> float:
	return minf(maxf(light, 0.0) + maxf(coef, 0.0) * Balance.PRISM_CHARGE_PCT / 100.0, cap)

## How much stronger a heal is after passing through `n` prisms (`sharp` = Sharp Facets' %).
static func amplify_mult(n: int, sharp: float) -> float:
	return 1.0 + float(maxi(n, 0)) * (Balance.PRISM_AMPLIFY_PCT + maxf(sharp, 0.0)) / 100.0

## The share of a shattering prism's `light` each of `allies` allies gets.
static func shatter_share(light: float, allies: int) -> float:
	return maxf(light, 0.0) / float(maxi(allies, 1))

## Damage (coefficient) a shattering prism deals with `light` of `cap` (`burst` = Prismatic Burst's %).
static func shatter_damage(light: float, cap: float, burst: float) -> float:
	if cap <= 0.0:
		return 0.0
	return Balance.PRISM_SHATTER_DAMAGE * clampf(light / cap, 0.0, 1.0) * (1.0 + maxf(burst, 0.0) / 100.0)

## Realign: where prisms standing at `old` go around `center`. Each keeps its
## offset from the middle of the group, so the shape stays the same.
static func realign_spots(old: Array, center: Vector3) -> Array:
	var out := []
	if old.is_empty():
		return out
	var mid := Vector3.ZERO
	for p in old:
		mid += p
	mid /= float(old.size())
	for p in old:
		var off: Vector3 = p - mid
		out.append(Vector3(center.x + off.x, center.y, center.z + off.z))
	return out

## Index of the point in `points` closest to `to` (seen from above), -1 if none.
static func closest_index(points: Array, to: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in points.size():
		var p: Vector3 = points[i]
		var d := Vector2(p.x - to.x, p.z - to.z).length_squared()
		if d < best_d:
			best_d = d
			best = i
	return best

## Which prism a prism ability goes to: the mouseover one, else the one I
## clicked, else my closest. Returns its index (-1 = none).
static func pick_prism(keys: Array, spots: Array, mouseover: String, clicked: String, me: Vector3) -> int:
	if mouseover != "" and keys.has(mouseover):
		return keys.find(mouseover)
	if clicked != "" and keys.has(clicked):
		return keys.find(clicked)
	return closest_index(spots, me)

func _my_prism_cap() -> float:
	return prism_cap(player._talent("holy_deep_crystal"))   # + Deep Crystal

func _prism_index(key: String) -> int:
	for i in _prisms.size():
		if str(_prisms[i]["key"]) == key:
			return i
	return -1

func _prism_spots() -> Array:
	var out := []
	for p in _prisms:
		out.append(p["pos"])
	return out

func _prism_keys() -> Array:
	var out := []
	for p in _prisms:
		out.append(str(p["key"]))
	return out

## The prism a prism ability goes to (index into _prisms, -1 = none). `kind`:
## "white", "gold", or "" for either colour.
func _target_prism(kind: String = "white") -> int:
	var keys := []
	var spots := []
	var at := []
	for i in _prisms.size():
		if kind == "" or str(_prisms[i].get("kind", "white")) == kind:
			keys.append(str(_prisms[i]["key"]))
			spots.append(_prisms[i]["pos"])
			at.append(i)
	var j := pick_prism(keys, spots, player._mo_prism, prism_target, player.global_position)
	return int(at[j]) if j >= 0 else -1

## How many of my prisms are of `kind` ("white" / "gold").
func prisms_of(kind: String) -> int:
	var n := 0
	for p in _prisms:
		if str(p.get("kind", "white")) == kind:
			n += 1
	return n

## The key of my prism under the mouse ("" = none).
func _prism_at(screen_pos: Vector2, cam: Camera3D) -> String:
	var best := ""
	var best_d := PRISM_PICK_PX
	for p in _prisms:
		var at: Vector3 = p["pos"] + Vector3(0, Balance.PRISM_HOVER, 0)
		if cam.is_position_behind(at):
			continue
		var d := cam.unproject_position(at).distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = str(p["key"])
	return best

## A heal / shield / damage beam from me to `to`, carrying `coef`. Every WHITE
## prism of mine on it is charged (gold ones are the archer's: the beam passes
## them by); returns how much stronger the heal is for them (Kaleidoscope: every
## white prism counts, wherever it is).
func _prism_beam(to: Vector3, coef: float) -> float:
	var from := player.global_position
	var width := Balance.PRISM_BEAM_WIDTH + player._talent("holy_clear_glass")   # + Clear Glass
	var all: bool = player.status != null and player.status.has(KALEIDOSCOPE_FX)
	var cap := _my_prism_cap()
	var n := 0
	for p in _prisms:
		if str(p.get("kind", "white")) != "white":
			continue
		if all or on_beam(from, to, p["pos"], width):
			p["light"] = prism_charged(float(p["light"]), coef, cap)
			n += 1
	var start := player._muzzle() if player.is_inside_tree() else from
	LIGHT_BEAM.flash(player.get_tree().current_scene, start, to + Vector3(0, 0.9, 0), PRISM_LIGHT)
	player._net_fx("beam", start, null, {"to": to + Vector3(0, 0.9, 0)})
	if n > 0:
		_sync_prisms()
	return amplify_mult(n, player._talent("holy_sharp_facets"))   # + Sharp Facets

## A heal of the kit on `who` (`coef` before the prisms): through the beam.
func _prism_heal(who: Variant, coef: float, id: String) -> void:
	if who == null or not is_instance_valid(who):
		return
	var mult := _prism_beam((who as Node3D).global_position, coef)
	player._heal_coef(who, coef * mult, id)

## Set Prism, Realign, Prism Arrow (ground-targeted).
func _prism_place_error(id: String, point: Variant = null) -> String:
	if id == LightstringKit.PRISM_ARROW_ID:
		if player._weapon().get("weapon", "") != "ranged":
			return "Requires a bow"
		if player.lightstring._prism_arrows <= 0:
			return "%s is not ready yet" % Abilities.ability_name(id)
	elif player.cooldown_left(id) > 0.0:
		return "%s is not ready yet" % Abilities.ability_name(id)
	if id == REALIGN_ID and _prisms.is_empty():
		return "You have no prisms"
	if point is Vector3:
		var reach := float(Abilities.get_resource(id).cast_range)
		if Vector2(point.x - player.global_position.x, point.z - player.global_position.z).length() > reach:
			return "Out of range"
	return ""

func _start_prism_place(id: String, point: Vector3) -> void:
	var err := _prism_place_error(id, point)
	if err != "":
		player._error(err)
		return
	if not player._pay(id):
		return
	var ground := Vector3(point.x, Combat.feet_y(player), point.z)
	if id == LightstringKit.PRISM_ARROW_ID:
		player.lightstring._prism_arrow_used()   # (charges)
		LIGHT_BEAM.flash(player.get_tree().current_scene, player._muzzle(), ground + Vector3(0, Balance.PRISM_HOVER, 0), PRISM.GOLD)   # (the arrow's streak)
		_add_prism(ground, "gold")
	else:
		player.cooldowns[id] = Abilities.cooldown_of(Abilities.get_resource(id))   # (Quick Realign)
		if id == SET_PRISM_ID:
			_add_prism(ground, "white")
		else:
			_realign(ground)
	if Player.on_gcd(id):
		player._start_gcd()
	player._bus().cast_finished.emit(id)

## A new prism of `kind` ("white": the healer's; "gold": the archer's). Both
## colours count toward PRISM_MAX: past it, my oldest goes, whatever its colour.
func _add_prism(at: Vector3, kind: String = "white") -> void:
	_prism_seq += 1
	var key := "p%d" % _prism_seq
	_prisms.append({"key": key, "pos": at, "light": 0.0, "kind": kind,
		"until": Time.get_ticks_msec() / 1000.0 + player.holy_talents._prism_time()})   # (+ Long Glass)
	while _prisms.size() > player.holy_talents._prism_max():   # (Rune of the Fourth Facet: one more)
		var old: Dictionary = _prisms.pop_front()
		PRISM.remove(player.get_tree(), "me:" + str(old["key"]))
	_sync_prisms()

## Realign: every prism flickers over to `center`, in the same shape, and its time starts over.
func _realign(center: Vector3) -> void:
	var spots := realign_spots(_prism_spots(), center)
	var until := Time.get_ticks_msec() / 1000.0 + player.holy_talents._prism_time()   # (+ Long Glass)
	for i in _prisms.size():
		_prisms[i]["pos"] = spots[i]
		_prisms[i]["until"] = until
	_sync_prisms()

## The ground point under the mouse (and whether I can see it).
func _mouse_ground() -> Array:
	var cam := player.get_viewport().get_camera_3d()
	if cam == null:
		return [null, false]
	var at := player.get_viewport().get_mouse_position()
	var plane := Plane(Vector3.UP, Combat.feet_y(player))
	var hit: Variant = plane.intersects_ray(cam.project_ray_origin(at), cam.project_ray_normal(at))
	if hit == null:
		return [null, false]
	var seen := Combat.line_of_sight(player.get_world_3d(), Combat.sight_point(player), (hit as Vector3) + Vector3(0, 0.3, 0))
	return [hit, seen]

## Why a prism ability can't be used right now ("" = it can).
func _prism_precheck(id: String) -> String:
	match id:
		GLEAM_ID, PRISM_WARD_ID:
			var pick := player._pick_support_target(id)
			if pick[0] == null and str(pick[1]) != "":
				return str(pick[1])
		MOVE_PRISM_ID:
			if _prisms.is_empty():
				return "You have no prisms"
			var g := _mouse_ground()
			if g[0] == null or not bool(g[1]):
				return "Not in line of sight"
			var p: Vector3 = g[0]
			if Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length() > float(Abilities.get_resource(id).cast_range):
				return "Out of range"
		SHATTER_PRISM_ID, SHATTER_ALL_ID, INFUSE_ID:
			if prisms_of("white") <= 0:
				return "You have no white prisms"
			if id == INFUSE_ID:
				var i := _target_prism()
				if i >= 0 and float(_prisms[i]["light"]) >= _my_prism_cap():
					return "That prism is full"
	return ""

## One of the kit's instants (paid for and put on cooldown by _use_drafted).
func _prism_use(id: String, res: Resource) -> void:
	match id:
		GLEAM_ID:
			var who: Node3D = player._pick_support_target(id)[0]
			if who:
				_prism_heal(who, float(Abilities.HEALS[id]), id)
		PRISM_WARD_ID:
			var who: Node3D = player._pick_support_target(id)[0]
			if who:
				var coef := float(Abilities.HEALS[id])
				var mult := _prism_beam(who.global_position, coef)
				player.hymns._hymn_ward(who, PRISM_WARD_FX, player._combat().heal_amount(player, coef * mult, id), Balance.PRISM_WARD_TIME)
				player._ring_effect(1.0, PRISM_LIGHT, who.global_position)
		MOVE_PRISM_ID:
			var g := _mouse_ground()
			if g[0] != null:
				var spot: Vector3 = g[0]
				var i := closest_index(_prism_spots(), spot)
				if i >= 0:
					_prisms[i]["pos"] = Vector3(spot.x, Combat.feet_y(player), spot.z)
					_sync_prisms()
		SHATTER_PRISM_ID:
			var i := _target_prism()
			if i >= 0:
				_shatter_prism(i)
		SHATTER_ALL_ID:
			# Every white prism (gold ones are the archer's: Prism Breaker).
			for i in range(_prisms.size() - 1, -1, -1):
				if i < _prisms.size() and str(_prisms[i].get("kind", "white")) == "white":
					_shatter_prism(i)
		INFUSE_ID:
			var i := _target_prism()
			if i >= 0:
				_prisms[i]["light"] = _my_prism_cap()
				player._ring_effect(1.0, PRISM_LIGHT, _prisms[i]["pos"])
				_sync_prisms()
		KALEIDOSCOPE_ID:
			var fx := StatusContainer.make_buff(KALEIDOSCOPE_FX, Abilities.ability_name(id), Stats.BLOCK, 0.0,
				Balance.KALEIDOSCOPE_TIME, 1, PRISM_LIGHT)
			fx.stat_modifiers = {}
			fx.tags = PackedStringArray(["Holy"])
			fx.description = "Your heals' beams pass through every white prism you have, wherever it stands."
			player.status.apply(fx, player)
			player._ring_effect(1.4, PRISM_LIGHT)

## The prism at index `i` shatters: its light heals the allies around it (split
## evenly between them) and it hurts the enemies there (both a proc line).
func _shatter_prism(i: int) -> void:
	var p: Dictionary = _prisms[i]
	_prisms.remove_at(i)
	var at: Vector3 = p["pos"]
	var light := float(p["light"])
	var reach := Balance.PRISM_SHATTER_RADIUS + player._talent("holy_wide_burst")   # + Wide Burst
	var allies := _allies_near(at, reach)
	var share := shatter_share(light, allies.size())
	for a in allies:
		player._heal_coef(a, share, PRISM_SHATTER_ID)
	var foes := player._enemies_near(at, reach)
	var coef := shatter_damage(light, _my_prism_cap(), player._talent("holy_prismatic_burst")) * Balance.aoe_share(foes.size())   # + Prismatic Burst
	if coef > 0.0:
		for e in foes:
			player.deal_damage(e, coef, PRISM_SHATTER_ID, true, "holy", PackedStringArray(["Holy", "Spell", "AoE"]))
	PRISM.shatter(player.get_tree(), "me:" + str(p["key"]))
	player._net_fx("prism_burst", at, null, {"k": str(p["key"]), "r": reach})
	player._ring_effect(reach, PRISM_LIGHT, at)
	if str(p["key"]) == prism_target:
		prism_target = ""
	_sync_prisms()

## Allies (me included) within `radius` of `point`.
func _allies_near(point: Vector3, radius: float) -> Array:
	var out: Array = []
	var me_d := Vector2(player.global_position.x - point.x, player.global_position.z - point.z).length()
	if player.is_alive() and me_d <= radius:
		out.append(player)
	for a in player.get_tree().get_nodes_in_group("remote_player") + player.get_tree().get_nodes_in_group("friendly"):
		if a is Node3D and a.is_alive() and Vector2(a.global_position.x - point.x, a.global_position.z - point.z).length() <= radius:
			out.append(a)
	return out

## Mending Ray (a channel on an ally): paid when it starts, its heal in ticks.
func _start_mending_ray() -> void:
	var id := MENDING_RAY_ID
	if player.casting or not player.is_on_floor():
		return
	var pick := player._pick_support_target(id)
	if pick[0] == null:
		if str(pick[1]) != "":
			player._error(str(pick[1]))
		return
	if not player._pay(id):
		return
	_ray_who = pick[0]
	player.cast_point = (pick[0] as Node3D).global_position
	var res := Abilities.get_resource(id)
	player._begin_spell(id, str(res.display_name), float(res.cast_time), true)
	_ray_left = Balance.MENDING_RAY_TICKS if player.casting and player.current_spell == id else 0

## The ticks of Mending Ray that are due by now (`final` = all that are left).
func _mending_ray_tick(final: bool = false) -> void:
	if _ray_left <= 0:
		return
	if _ray_who == null or not is_instance_valid(_ray_who) or not (_ray_who as Node3D).is_alive():
		_ray_left = 0
		if player.casting:
			player._cancel_cast()
		return
	player.cast_point = (_ray_who as Node3D).global_position   # (I keep facing them)
	var ticks := Balance.MENDING_RAY_TICKS
	var due := ticks
	if not final:
		var every := maxf(player.cast_duration / ticks, 0.01)
		due = mini(int(floor((player.cast_duration - maxf(player.cast_timer, 0.0)) / every + 0.0001)), ticks)
	var coef := float(Abilities.HEALS[MENDING_RAY_ID]) / float(ticks) * (1.0 + player._talent("holy_steady_ray") / 100.0)   # + Steady Ray
	while ticks - _ray_left < due:
		_ray_left -= 1
		_prism_heal(_ray_who, coef, MENDING_RAY_ID)

## Bright Lance landed (_release_support).
func _prism_cast_heal(spell: String, tgt: Variant, kind: String) -> void:
	var who: Variant = tgt if kind == "ally" and tgt != null and is_instance_valid(tgt) else player
	_prism_heal(who, float(Abilities.HEALS.get(spell, 0.0)), spell)

## Piercing Light landed (_release of a bolt): a beam into the enemy. The prisms
## on it store part of its damage as light.
func _piercing_light(tgt: Node3D) -> void:
	if tgt == null or not is_instance_valid(tgt) or not tgt.is_alive():
		return
	var coef := float(Abilities.get_resource(PIERCING_LIGHT_ID).damage)
	_prism_beam(tgt.global_position, coef)
	player.deal_damage(tgt, coef, PIERCING_LIGHT_ID)

## Every frame: prisms that ran out fade, and the party is told again now and then.
func _tick_prisms() -> void:
	if _prisms.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var gone := false
	for i in range(_prisms.size() - 1, -1, -1):
		if now >= float(_prisms[i]["until"]):
			PRISM.remove(player.get_tree(), "me:" + str(_prisms[i]["key"]))
			_prisms.remove_at(i)
			gone = true
	if gone:
		_sync_prisms()
	elif now - _prisms_told >= PRISM_RETELL:
		_tell_prisms()

## The picture of my prisms (and the party is told): where they stand, how full.
## (A prism that appears somewhere new flickers in: scripts/prism.gd.)
func _sync_prisms() -> void:
	var cap := _my_prism_cap()
	var keys := []
	for p in _prisms:
		var key := "me:" + str(p["key"])
		keys.append(key)
		PRISM.place(player.get_tree().current_scene, key, p["pos"] + Vector3(0, Balance.PRISM_HOVER, 0), float(p["light"]) / cap,
			true, str(p["key"]) == prism_target, str(p.get("kind", "white")) == "gold")
	PRISM.keep_only(player.get_tree(), "me:", keys)
	_tell_prisms()

func _tell_prisms() -> void:
	_prisms_told = Time.get_ticks_msec() / 1000.0
	var cap := _my_prism_cap()
	var list := []
	for p in _prisms:
		var pos: Vector3 = p["pos"]
		list.append([str(p["key"]), pos.x, pos.y + Balance.PRISM_HOVER, pos.z, float(p["light"]) / cap, str(p.get("kind", "white"))])
	player._net_fx("prisms", player.global_position, null, {"p": list})

## A click on one of my prisms makes it my prism target (Shatter Prism, Infuse).
func _click_prism(screen_pos: Vector2, cam: Camera3D) -> bool:
	var key := _prism_at(screen_pos, cam)
	if key == "":
		return false
	prism_target = key
	_sync_prisms()
	return true

