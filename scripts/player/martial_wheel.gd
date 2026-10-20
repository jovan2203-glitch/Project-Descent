extends "res://scripts/player/player_kit.gd"
class_name WheelKit

# Hooked up from player.gd through its var "wheel".
# --- Martial warrior: the Wheel ----------------------------------------------------------
# Four floating two-handers ride on my back in a fixed order (Abilities.WHEEL_ORDER,
# the ones I have learned); I hold the one in front. My bar holds four buttons
# (Abilities.WHEEL_SLOTS) that take the held weapon's form (Abilities.WHEEL_FORMS):
# Filler (gives Fury, 1 Crack), Heavy Filler (costs Fury, 2 Cracks), the Weapon
# Art (movement, control or defence; no damage) and Finisher (more for
# every Crack, then the next weapon comes in). The held weapon takes WHEEL_USES
# uses - any ability of any book that goes off, except off-GCD ones and trinkets -
# then it breaks and its Cracks are lost. While held, each weapon has a rider on
# all my ability hits: the Greataxe cleaves, the Greatsword crits more, the Halberd
# can hit again, the Maul builds Stagger (full = knocked down; never bosses).
# The Wheel is out while one of its buttons is on my bars. Leaving combat makes the
# held weapon whole again; out of combat the HUD's Wheel strip turns it.
# Everything runs on my machine; the party sees the weapons ("wheel" fx).
# Numbers: balance.gd (WHEEL_*, CRACKS_*, BREAK_*, STAGGER_* and the moves').

const WHEEL_PICTURE = preload("res://scripts/weapon_wheel.gd")
const Effects = preload("res://scripts/core/effects.gd")
const CRACKS_FX := "cracks"
const SWORD_FX := "wheel_greatsword"      # the Greatsword's rider: more crit while it is held
const BLADE_GUARD_FX := "bladeguard"
const KNOCKED_DOWN_FX := "knocked_down"   # a full Stagger
const SHAKEN_DOWN_FX := "shaken_down"     # Earthshake
## Meter / log ids of the riders (their own lines: Details.HIT_NAMES).
const AXE_CLEAVE_ID := "axecleave"
const SECOND_HIT_ID := "secondhit"
const WHEEL_TAGS := ["Ability", "Physical", "Melee"]
const BREAKS := ["shrapnel", "shardlance", "flyinghead", "faultline"]
const MAUL_MOVES := ["thud", "crush", "faultline"]   # add STAGGER_MAUL_EXTRA
const TELL_EVERY := 3.0                    # seconds between telling the party what my Wheel shows

var _held := 0              # index into weapons() of the weapon in my hands
var _uses := 0              # uses it has taken
var _cracks := 0            # Cracks in it
var _stagger := {}          # enemy instance id -> [Stagger, when I last hit it]
var _cracks_fx: Resource = null
var _sword_fx: Resource = null
var _was_in_combat := false
var _shown := ""            # what the picture / the party last saw
var _told := 0.0

# Rules as static functions (tests/test_martial.gd).

## Break's damage (coefficient) with `cracks` Cracks: next to nothing without them.
static func break_coef(base: float, per: float, cracks: int) -> float:
	return base + per * float(maxi(cracks, 0))

## Does using `id` take one of the held weapon's uses? (Off-GCD abilities and trinkets don't.)
static func counts_as_use(id: String) -> bool:
	return Player.on_gcd(id)

## The weapon after index `i` on a Wheel of `n` weapons.
static func next_index(i: int, n: int) -> int:
	return 0 if n <= 0 else (i + 1) % n

## Stagger `have` plus `add`: [Stagger left, knocked down?]. Full Stagger knocks down and starts over.
static func stagger_after(have: float, add: float) -> Array:
	var now := have + maxf(add, 0.0)
	if now >= Balance.STAGGER_MAX:
		return [0.0, true]
	return [now, false]

## Is `forward` within half of `arc_deg` of the direction to `to` (flat)?
static func in_arc(from: Vector3, forward: Vector3, to: Vector3, arc_deg: float) -> bool:
	var d := Vector2(to.x - from.x, to.z - from.z)
	if d.length() < 0.01:
		return true
	return absf(rad_to_deg(Vector2(forward.x, forward.z).angle_to(d))) <= arc_deg * 0.5 + 0.01

# --- State ----------------------------------------------------------------------------

## The weapons I have learned, in the order they turn.
func weapons() -> Array[String]:
	var pd := player.get_node_or_null("/root/PlayerData")
	return pd.wheel_weapons() if pd else ([] as Array[String])

## Is my Wheel out? (A weapon learned and one of its buttons on my bars, macros counted.)
func is_out() -> bool:
	if weapons().is_empty():
		return false
	var pd := player.get_node_or_null("/root/PlayerData")
	if pd == null:
		return false
	for slot_id in pd.action_bar:
		var id := Macros.link_of(str(slot_id)) if Macros.is_macro(str(slot_id)) else str(slot_id)
		if Abilities.WHEEL_SLOTS.has(id) or Abilities.wheel_weapon_of(id) != "":
			return true
	return false

## The weapon in my hands ("" with none learned).
func held_weapon() -> String:
	var ws := weapons()
	if ws.is_empty():
		return ""
	_held = clampi(_held, 0, ws.size() - 1)
	return ws[_held]

func cracks() -> int:
	return _cracks

func uses_left() -> int:
	return maxi(Balance.WHEEL_USES - _uses, 0)

## What bar button `id` is right now: a Wheel button takes the held weapon's form.
func form_of(id: String) -> String:
	var i := Abilities.WHEEL_SLOTS.find(id)
	if i < 0:
		return id
	var w := held_weapon()
	return str(Abilities.WHEEL_FORMS[w][i]) if w != "" else id

## The number on a Break button: the Cracks in the held weapon.
func charges_text(id: String) -> String:
	if not BREAKS.has(id) and id != "wheelbreak":
		return ""
	return str(_cracks) if _cracks > 0 else ""

# --- Turning --------------------------------------------------------------------------

## The held weapon breaks (Break, or its last use): the next one comes in, whole.
func _turn(burst: bool) -> void:
	var ws := weapons()
	if burst and player.is_inside_tree():
		WHEEL_PICTURE.burst(player, held_weapon())
		player._net_fx("wheel_burst", player.global_position, null, {"w": held_weapon()})
	_held = next_index(_held, ws.size())
	_uses = 0
	_set_cracks(0)
	_sync()

## Out of combat: the HUD's Wheel strip turns it to the next weapon.
func turn_out_of_combat() -> bool:
	if player.is_in_combat() or weapons().size() < 2:
		return false
	_turn(false)
	return true

## Something went off (cast_finished): a use for the held weapon; Break turns it.
func _on_cast_finished(id: String) -> void:
	if not is_out() or not counts_as_use(id):
		return
	if BREAKS.has(id):
		_turn(true)
		return
	_uses += 1
	if _uses >= Balance.WHEEL_USES:
		_turn(true)   # its last use: it breaks, and its Cracks are lost
	else:
		_sync()

func _set_cracks(n: int) -> void:
	_cracks = maxi(n, 0)
	if player.status == null:
		return
	if _cracks <= 0:
		player.status.remove(CRACKS_FX)
		return
	if _cracks_fx == null:
		_cracks_fx = StatusContainer.make_buff(CRACKS_FX, "Cracks", Stats.BLOCK, 0.0, 3600.0, 999, Color(1.0, 0.85, 0.5))
		_cracks_fx.stat_modifiers = {}
		_cracks_fx.tags = PackedStringArray(["Physical"])
		_cracks_fx.description = "Cracks in the weapon you hold. Your finisher deals more for each one."
	player.status.apply(_cracks_fx, player)
	if player.status.stacks_of(CRACKS_FX) != _cracks:
		player.status.set_stacks(CRACKS_FX, _cracks)

func _tick_wheel() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var fighting: bool = player.is_in_combat()
	if _was_in_combat and not fighting:
		_uses = 0   # leaving combat: the held weapon is whole again
		_set_cracks(0)
		_stagger.clear()
	_was_in_combat = fighting
	# The Greatsword's rider: more crit while it is in my hands.
	var sword: bool = is_out() and held_weapon() == "wheelgreatsword"
	if player.status != null:
		if sword and not player.status.has(SWORD_FX):
			if _sword_fx == null:
				_sword_fx = StatusContainer.make_buff(SWORD_FX, "Greatsword", Stats.CRIT, Balance.SWORD_CRIT_PCT, 3600.0, 1, Color(0.78, 0.9, 1.0))
				_sword_fx.tags = PackedStringArray(["Physical"])
				_sword_fx.description = "You hold the Greatsword: more critical strike chance."
			player.status.apply(_sword_fx, player)
		elif not sword and player.status.has(SWORD_FX):
			player.status.remove(SWORD_FX)
	if not _stagger.is_empty():
		for key in _stagger.keys():
			if now - float(_stagger[key][1]) > Balance.STAGGER_FADE:
				_stagger.erase(key)
	_sync()
	if now - _told >= TELL_EVERY and _shown != "":
		_tell()

## The picture shows what the Wheel is now, and the party is told when it changes.
func _sync() -> void:
	var want := ""
	if is_out() and not player.is_dead():
		want = "%s|%d|%d" % [",".join(weapons()), _held, _cracks]
	if want == _shown:
		return
	_shown = want
	if player.is_inside_tree():
		WHEEL_PICTURE.show_on(player, weapons() if want != "" else ([] as Array[String]), _held, _cracks)
	_tell()

func _tell() -> void:
	_told = Time.get_ticks_msec() / 1000.0
	var out := _shown != ""
	player._net_fx("wheel", player.global_position, null, {"w": weapons() if out else [], "h": _held, "c": _cracks})

# --- Using the moves --------------------------------------------------------------------

## Why a Wheel move can't be used right now ("" = it can).
func _wheel_precheck(id: String) -> String:
	if Abilities.WHEEL_ORDER.has(id):
		return "Use its moves: they are on your Wheel's buttons"
	if Abilities.WHEEL_SLOTS.has(id) or weapons().is_empty():
		return "You have no weapon on your Wheel"
	if Abilities.wheel_weapon_of(id) != held_weapon():
		return "You aren't holding the %s" % Abilities.ability_name(Abilities.wheel_weapon_of(id))
	if id == "dragin" and player._has_valid_target() and str(player.target.get("rank")) == "boss":
		return "Bosses are too heavy to drag"
	return ""

## One of the Wheel's moves (paid for and put on cooldown by _use_drafted).
func _wheel_use(id: String, res: Resource) -> void:
	var col: Color = WHEEL_PICTURE.color_of(Abilities.wheel_weapon_of(id))
	match id:
		"hack", "chop":
			_cleave(res, col)
		"slash", "lunge", "thud", "crush":
			if player._has_valid_target():
				player.deal_damage(player.target, float(res.damage), id)
				player._slash_effect(col)
		"jab", "hook":
			_sweep(res, col)
		"rush":
			_rush(col)
		"bladeguard":
			_blade_guard(col)
		"dragin":
			_drag_in()
		"earthshake":
			_earthshake(res, col)
		"shrapnel":
			_shrapnel(res, col)
		"shardlance":
			if player._has_valid_target():
				player.deal_damage(player.target, break_coef(float(res.damage), Balance.SHARD_LANCE_PER_CRACK, _cracks), id)
		"flyinghead":
			_flying_head(res)
		"faultline":
			_fault_line(res, col)
	var slot := Abilities.wheel_slot_index(id)
	if slot == 0:
		_set_cracks(_cracks + Balance.CRACKS_QUICK)
	elif slot == 1:
		_set_cracks(_cracks + Balance.CRACKS_FULL)

## Hack / Chop: the target, and part of it to a few enemies near it.
func _cleave(res: Resource, col: Color) -> void:
	if not player._has_valid_target():
		return
	var foe: Node3D = player.target
	var others: Array = player._enemies_near(foe.global_position, Balance.HACK_CLEAVE_REACH, foe).slice(0, Balance.HACK_CLEAVE_TARGETS)
	player.deal_damage(foe, float(res.damage), str(res.id))
	for o in others:
		if is_instance_valid(o) and o.is_alive():
			player.deal_damage(o, float(res.damage) * Balance.HACK_CLEAVE_PCT / 100.0, str(res.id))
	player._slash_effect(col)

## Enemies within `reach` m in front of me, in an `arc_deg` wide arc, nearest first.
func _in_front(reach: float, arc_deg: float) -> Array:
	var fwd: Vector3 = player._flat_forward()
	var out := []
	for e in player._enemies_within(reach):
		if in_arc(player.global_position, fwd, e.global_position, arc_deg):
			out.append(e)
	out.sort_custom(func(a, b): return player.global_position.distance_squared_to(a.global_position) < player.global_position.distance_squared_to(b.global_position))
	return out

## Jab / Hook: a sweep through up to a few enemies in front of me (the target first).
func _sweep(res: Resource, col: Color) -> void:
	var hit: Array = []
	if player._has_valid_target():
		hit.append(player.target)
	for e in _in_front(Balance.HALBERD_SWEEP_REACH, Balance.HALBERD_SWEEP_ARC):
		if hit.size() >= Balance.HALBERD_SWEEP_TARGETS:
			break
		if not hit.has(e):
			hit.append(e)
	var share := Balance.aoe_share(hit.size())
	for e in hit:
		player.deal_damage(e, float(res.damage) * share, str(res.id))
	player._slash_effect(col)

## Rush: a dash straight ahead, through enemies (walls stop it).
func _rush(col: Color) -> void:
	var from: Vector3 = player.global_position
	var dir: Vector3 = player._flat_forward()
	player.global_position += dir * player._dash_distance(Balance.RUSH_DISTANCE)
	player._ring_effect(0.8, col, from)
	player._ring_effect(0.8, col)

## Blade Guard: less damage taken for a moment.
func _blade_guard(col: Color) -> void:
	var fx := StatusContainer.make_buff(BLADE_GUARD_FX, Abilities.ability_name("bladeguard"), BLADE_GUARD_FX, 0.0,
		Balance.BLADE_GUARD_TIME, 1, col)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Physical", "Defensive"])
	fx.damage_mod_pct = -Balance.BLADE_GUARD_PCT
	fx.modifies_incoming = true
	fx.mod_affects_dots = true
	fx.description = "The Greatsword raised before you: you take %s%% less damage." % Stats.num(Balance.BLADE_GUARD_PCT)
	player.status.apply(fx, player)
	player.status.set_remaining(BLADE_GUARD_FX, Balance.BLADE_GUARD_TIME)

## Drag In: the Halberd's hook drags the target to me (it isn't made to attack me).
func _drag_in() -> void:
	if not player._has_valid_target() or str(player.target.get("rank")) == "boss":
		return
	var foe: Node3D = player.target
	var gap := Combat.hitbox_radius(foe) + Combat.hitbox_radius(player) + Balance.DRAG_IN_GAP
	var to := LightningTankKit.reel_in_point(player.global_position, foe.global_position, gap)
	to.y = foe.global_position.y + (Combat.feet_y(player) - Combat.feet_y(foe))   # onto my level
	var net := player._net()
	if net:
		net.drag(foe, to, Balance.DRAG_IN_TIME)   # the host owns enemies in a party
	elif foe.has_method("drag_to"):
		foe.drag_to(to, Balance.DRAG_IN_TIME)

## Knock `e` down with effect `fx_id` (never a boss).
func _knock_down(e: Node, fx_id: String, from_id: String) -> void:
	if e == null or not is_instance_valid(e) or not e.is_alive() or str(e.get("rank")) == "boss":
		return
	player.fire_caster._apply_effect_hit(e, Effects.get_effect(fx_id), from_id, PackedStringArray(WHEEL_TAGS), "physical")

## Earthshake: every enemy near me is knocked down. No damage.
func _earthshake(res: Resource, col: Color) -> void:
	for e in player._enemies_within(float(res.radius)):
		_knock_down(e, SHAKEN_DOWN_FX, "earthshake")
	player._ring_effect(float(res.radius), col)

## Shrapnel: the Greataxe bursts around me.
func _shrapnel(res: Resource, col: Color) -> void:
	var foes: Array = player._enemies_within(float(res.radius))
	var coef := break_coef(float(res.damage), Balance.BREAK_PER_CRACK, _cracks) * Balance.aoe_share(foes.size())
	for e in foes:
		player.deal_damage(e, coef, "shrapnel")
	player._ring_effect(float(res.radius), col)

## Flying Head: into the target, then bouncing on to a few more.
func _flying_head(res: Resource) -> void:
	if not player._has_valid_target():
		return
	var coef := break_coef(float(res.damage), Balance.BREAK_PER_CRACK, _cracks)
	var last: Node3D = player.target
	var hit := [last]
	player.deal_damage(last, coef, "flyinghead")
	for i in Balance.FLYING_HEAD_BOUNCES:
		if not is_instance_valid(last):
			break
		var next: Node3D = null
		for e in player._enemies_near(last.global_position, Balance.FLYING_HEAD_REACH):
			if not hit.has(e):
				next = e
				break
		if next == null:
			break
		hit.append(next)
		player.deal_damage(next, coef * Balance.FLYING_HEAD_BOUNCE_PCT / 100.0, "flyinghead")
		last = next

## Fault Line: a shockwave in a cone ahead of me (toward my target if I have one).
func _fault_line(res: Resource, col: Color) -> void:
	if player._has_valid_target():
		var dir: Vector3 = player.target.global_position - player.global_position
		player.rotation.y = atan2(-dir.x, -dir.z)
	var foes := _in_front(float(res.radius), Balance.FAULT_LINE_ARC)
	var coef := break_coef(float(res.damage), Balance.BREAK_PER_CRACK, _cracks) * Balance.aoe_share(foes.size())
	for e in foes:
		player.deal_damage(e, coef, "faultline")
	player._ring_effect(1.5, col, player.global_position + player._flat_forward() * float(res.radius) * 0.5)

# --- The riders -----------------------------------------------------------------------

## One of my hits landed (damage_dealt): the held weapon's rider.
func _on_damage_dealt_wheel(info: RefCounted) -> void:
	if not is_same(info.source, player) or info.avoided() or int(info.amount) <= 0:
		return
	if bool(info.is_proc) or bool(info.is_dot) or str(info.ability_id).begins_with("auto_") or not is_out():
		return
	var tgt: Node = info.target
	if tgt == null or not is_instance_valid(tgt) or not tgt.is_in_group("enemies"):
		return
	var tags: PackedStringArray = info.tags if not info.tags.is_empty() else Abilities.tags_of(str(info.ability_id))
	match held_weapon():
		"wheelgreataxe":
			if not tgt.is_alive():
				return
			var near: Array = player._enemies_near(tgt.global_position, Balance.AXE_CLEAVE_REACH, tgt)
			if not near.is_empty():
				player.deal_damage(near[0], float(info.base) * Balance.AXE_CLEAVE_PCT / 100.0, AXE_CLEAVE_ID, true, str(info.damage_type), tags)
		"wheelhalberd":
			if tgt.is_alive() and randf() * 100.0 < Balance.HALBERD_AGAIN_PCT:
				player.deal_damage(tgt, float(info.base), SECOND_HIT_ID, true, str(info.damage_type), tags)
		"wheelmaul":
			var extra := Balance.STAGGER_MAUL_EXTRA if MAUL_MOVES.has(str(info.ability_id)) else 0.0
			_add_stagger(tgt, Balance.STAGGER_PER_HIT + extra)

## Stagger on `e` (never a boss); full knocks it down and starts over.
func _add_stagger(e: Node, amount: float) -> void:
	if not e.is_alive() or str(e.get("rank")) == "boss":
		return
	var key := e.get_instance_id()
	var have := float(_stagger[key][0]) if _stagger.has(key) else 0.0
	var after := stagger_after(have, amount)
	_stagger[key] = [float(after[0]), Time.get_ticks_msec() / 1000.0]
	if bool(after[1]):
		_knock_down(e, KNOCKED_DOWN_FX, "wheelmaul")

## Stagger I have built on `e` (0 if none).
func stagger_on(e: Node) -> float:
	var key := e.get_instance_id() if e != null and is_instance_valid(e) else 0
	return float(_stagger[key][0]) if _stagger.has(key) else 0.0
