extends "res://scripts/player/player_kit.gd"
class_name RogueKit

# Hooked up from player.gd through its var "rogue".
# --- Martial DPS: the Rogue, and Martial Utility ---------------------------------------
# Build up fast, then go in for the kill (docs/design/martial.md):
#   Flow     a buff of up to FLOW_MAX stacks, FLOW_PCT% more damage each. Every Rogue
#            hit adds some (auto attacks don't); a hit from a different range than my
#            last one (melee after a throw, a throw after melee) adds FLOW_SWITCH more.
#            FLOW_HOLD sec without a Rogue hit and it starts to drop.
#   Daggers  Cut, Knife Spread and Back Flip throw daggers that stick in the enemy (up
#            to DAGGER_MAX each, mine only); melee hits rip them out ("Ripped Out").
#   Kill     Go In spends all Flow on a Kill window of KILL_PER_FLOW sec per stack;
#            during it the builders' buttons take their Kill forms
#            (Abilities.ROGUE_KILL_FORMS, through form_of like the Wheel's buttons), my
#            crits give Energy back and a form that differs from the last adds time.
# Snatch uses one random stolen item. Martial Utility (any Martial spec) is coded here
# too: Pin the Shadow (the book's root: StatusEffectData.break_after_hits), Over the
# Shoulder (a sure crit through adjust_crit) and Play Dead (Enemy.forget).
# Everything runs on my machine; enemies change through CombatSystem / Net (host). The
# party sees the Flow ring and the daggers (scripts/rogue_fx.gd, Net fx "rogue*").
# Numbers: balance.gd (FLOW_*, KILL_*, DAGGER_* and the rest of the Rogue section).

const RogueFx = preload("res://scripts/rogue_fx.gd")
const RogueIcons = preload("res://scripts/ui/rogue_icons.gd")
const Effects = preload("res://scripts/core/effects.gd")
const PINNED_FX := preload("res://data/effects/pinned_shadow.tres")
const BLINDED_FX := preload("res://data/effects/blinded.tres")
const FLOW_FX := "rogue_flow"
const KILL_FX := "kill_window"
const ROLL_FX := "roll_with_it"
const WHETSTONE_FX := "whetstone"
const SMOKE_FX := "smoke_flask"
const SURE_CRIT_FX := "over_the_shoulder"
const PLAY_DEAD_FX := "playing_dead"
const RIP_ID := "rippedout"          # damage of ripped-out daggers (its own meter line: Details.HIT_NAMES)
const OIL_ID := "oiljar"             # Snatch's Oil Jar (its own meter line)
const MELEE := "melee"
const THROWN := "thrown"
const ROGUE_TAGS := ["Ability", "Physical", "Melee"]
const OIL_TAGS := ["Ability", "Fire"]
## Snatch's items, one picked at random.
const SNATCH_ITEMS := ["flashpowder", "whetstone", "smokeflask", "oiljar"]
const SNATCH_NAMES := {"flashpowder": "Flash Powder", "whetstone": "Whetstone", "smokeflask": "Smoke Flask", "oiljar": "Oil Jar"}
## Play Dead / Smoke Flask reach every enemy this close (that's everything in a fight).
const FORGET_REACH := 60.0
const TELL_EVERY := 3.0              # seconds between telling the party what my Flow ring shows

var _flow := 0
var _flow_at := 0.0                  # my last Rogue hit (Flow drops after FLOW_HOLD)
var _decay_at := 0.0
var _last_range := ""                # MELEE / THROWN: where my last Rogue hit came from
var _daggers := {}                   # enemy instance id -> {"e", "n", "until"}
var _kill_until := 0.0
var _kill_last := ""                 # the Kill form used last in this window
var _kill_extra := 0.0               # seconds variety has added to this window
var _kill_flow := 0                  # Flow spent on this window (In the Zone)
var _double_until := 0.0             # Kick Off: my next throw before this throws two daggers
var _hitting := ""                   # MELEE / THROWN while a Rogue hit is being dealt (Thrown Weight, Close Work)
var _cold_read := 0                  # Cold Read: Rogue hits still to build double Flow
var _whetstone := 0
var _sure_crit_until := 0.0
var _dead_until := 0.0
var _pools: Array = []               # Oil Jars: {"pos", "until", "next"}
var _was_in_combat := false
var _shown := ""
var _told := 0.0

# Rules as static functions (tests/test_rogue.gd).

## Flow after a hit that gives `gain` (`switch`: it came from a different range than my
## last; `extra`: more for it, In and Out; `most`: the cap, Deep Flow).
static func flow_after(flow: int, gain: int, switch: bool, extra: int = 0, most: int = Balance.FLOW_MAX) -> int:
	return mini(flow + gain + (Balance.FLOW_SWITCH + maxi(extra, 0) if switch else 0), most)

## Is a hit from `now_range` a range switch after one from `last`?
static func is_switch(last: String, now_range: String) -> bool:
	return last != "" and last != now_range

## Seconds of Kill window `flow` Flow buys (`mult`: Hit Your Stride).
static func window_time(flow: int, mult: float = 1.0) -> float:
	return float(flow) * Balance.KILL_PER_FLOW * mult

## Seconds a Kill form adds to the window: KILL_VARIETY when it differs from the one
## before it, while the window has had less than KILL_VARIETY_MAX added (`extra`: more
## each time, Mix It Up).
static func variety_add(last_form: String, form: String, added: float, extra: float = 0.0) -> float:
	if last_form == "" or last_form == form:
		return 0.0
	return clampf(Balance.KILL_VARIETY_MAX - added, 0.0, Balance.KILL_VARIETY + maxf(extra, 0.0))

## In the Zone: crit chance from `flow` Flow at `per` % a stack.
static func in_the_zone_crit(flow: int, per: float) -> float:
	return float(maxi(flow, 0)) * maxf(per, 0.0)

## Daggers in an enemy after `add` more stick in it (`most`: the cap, Spare Knives).
static func daggers_after(n: int, add: int, most: int = Balance.DAGGER_MAX) -> int:
	return clampi(n + add, 0, most)

## Flow Whirl / Knife Spread gives for `hit` enemies.
static func whirl_flow(hit: int) -> int:
	return mini(hit, Balance.WHIRL_FLOW_MAX)

## Close It Out's damage (coefficient) with `left` seconds of Kill window left.
static func close_it_out_coef(left: float) -> float:
	return Balance.CLOSE_IT_OUT_PER_SEC * maxf(left, 0.0)

## The Kill form of builder `id` (`id` itself outside a window or if it has none).
static func kill_form(id: String, in_window: bool) -> String:
	return str(Abilities.ROGUE_KILL_FORMS.get(id, id)) if in_window else id

## The builder a Kill form belongs to ("" if `id` is not one).
static func builder_of(form: String) -> String:
	for b in Abilities.ROGUE_KILL_FORMS:
		if str(Abilities.ROGUE_KILL_FORMS[b]) == form:
			return str(b)
	return ""

## Abilities sharing one cooldown: Back Flip with Kick Off, Drive Through with Dart In.
static func cooldown_partner(id: String) -> String:
	match id:
		"kickoff": return "backflip"
		"backflip": return "kickoff"
		"dartin": return "drivethrough"
		"drivethrough": return "dartin"
	return ""

## Where a vault over an enemy at `at` lands, coming from `from`: `gap` metres past it.
static func behind(from: Vector3, at: Vector3, gap: float) -> Vector3:
	var d := at - from
	d.y = 0.0
	d = d.normalized() if d.length() > 0.01 else Vector3.FORWARD
	return at + d * gap

# --- State ----------------------------------------------------------------------------

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func flow() -> int:
	return _flow

## Most Flow I can hold (+ Deep Flow).
func flow_max() -> int:
	return Balance.FLOW_MAX + int(round(player._talent("martial_deep_flow")))

## Most of my daggers one enemy can hold (+ Spare Knives).
func dagger_max() -> int:
	return Balance.DAGGER_MAX + int(round(player._talent("martial_spare_knives")))

func in_kill() -> bool:
	return _kill_until > _now()

func kill_left() -> float:
	return maxf(_kill_until - _now(), 0.0)

func playing_dead() -> bool:
	return _dead_until > _now()

## My daggers stuck in `e`.
func daggers_in(e: Node) -> int:
	if e == null or not is_instance_valid(e):
		return 0
	var d: Dictionary = _daggers.get(e.get_instance_id(), {})
	return int(d.get("n", 0)) if float(d.get("until", 0.0)) > _now() else 0

## What bar button `id` is right now: a builder takes its Kill form in a Kill window.
func form_of(id: String) -> String:
	return kill_form(id, in_kill())

# --- Using it -------------------------------------------------------------------------

## Why a Rogue / Martial Utility ability can't be used right now ("" = it can).
func _rogue_precheck(id: String) -> String:
	if Abilities.is_kill_form(id) and not in_kill():
		return "Only in a Kill window"
	match id:
		"goin":
			if in_kill():
				return "Already in a Kill window"
			if _flow < Balance.KILL_MIN_FLOW:
				return "Requires %d Flow" % Balance.KILL_MIN_FLOW
		"hityourstride":
			if in_kill():
				return "Already in a Kill window"
		"closeitout":
			if not in_kill():
				return "Only in a Kill window"
		"rollwithit":
			if _flow < Balance.ROLL_WITH_IT_FLOW:
				return "Requires %d Flow" % Balance.ROLL_WITH_IT_FLOW
		"whirl", "redwhirl":
			var res := Abilities.get_resource(id)
			if player._enemies_within(float(res.radius)).is_empty() and _spread_targets().is_empty():
				return "No enemy in reach"
	return ""

## Can `id` be used now (the bar dims it if not)? Only the Rogue's own conditions.
func usable_now(id: String) -> bool:
	if not Abilities.ROGUE_IDS.has(id) and not Abilities.MARTIAL_UTILITY.has(id):
		return true
	return _rogue_precheck(id) == ""

## One of the Rogue's or Martial Utility's abilities (paid for and put on cooldown by _use_drafted).
func _rogue_use(id: String, res: Resource) -> void:
	var partner := cooldown_partner(id)
	if partner != "":
		player.cooldowns[partner] = float(player.cooldowns.get(id, 0.0))   # one cooldown for both
	if Abilities.is_kill_form(id):
		_kill_form_used(id)
	var foe: Node3D = player.target if player._has_valid_target() else null
	match id:
		"cut", "gut":
			if foe:
				if _in_melee(foe):
					_melee_hit(foe, float(res.damage), id, 1)
				else:
					var thrown := Balance.CUT_THROWN if id == "cut" else Balance.GUT_THROWN
					var n := 2 if _now() < _double_until else 1
					_double_until = 0.0
					_throw(foe, thrown, id, n, 1)
		"twinstab", "throughandthrough":
			if foe:
				var landed := 0
				for _hand in 2:
					landed += player.deal_damage(foe, float(res.damage), id)
				player._slash_effect(_blade_col())
				_rip(foe, dagger_max())
				if landed > 0:
					_landed(MELEE, Balance.TWIN_STAB_FLOW)
		"whirl", "redwhirl":
			_whirl(id, res)
		"dartin", "drivethrough":
			if foe:
				if id == "dartin":
					_dash_to(foe)
				else:
					_vault_past(foe)
					player.cooldowns.erase("kickoff")   # Drive Through: Kick Off is ready again
					player.cooldowns.erase("backflip")
				_melee_hit(foe, float(res.damage), id, 1)
				_rip(foe, 1)
		"kickoff", "backflip":
			if foe:
				_melee_hit(foe, float(res.damage), id, 1)
				_flip_back(foe)
				if id == "kickoff":
					_double_until = _now() + Balance.KICK_OFF_WINDOW
				else:
					_throw(foe, Balance.BACK_FLIP_DAGGER_COEF, id, Balance.BACK_FLIP_DAGGERS, 0, true)
		"goin":
			_open_kill(window_time(_flow))
		"hityourstride":
			_set_flow(flow_max())
			_open_kill(window_time(flow_max(), Balance.HIT_YOUR_STRIDE_MULT))
		"closeitout":
			var left := kill_left()
			_end_kill()
			if player.frost_melee._capstone("martial_clean_kill"):
				_set_flow(Balance.CLEAN_KILL_FLOW)   # Clean Kill's capstone
			if foe:
				player.deal_damage(foe, close_it_out_coef(left), id)
				player._ring_effect(1.2, RogueIcons.KILL, foe.global_position)
		"rollwithit":
			_set_flow(_flow - Balance.ROLL_WITH_IT_FLOW)
			_roll_with_it()
		"snatch":
			if foe:
				var picks := SNATCH_ITEMS.duplicate()
				picks.shuffle()
				_snatch(foe, str(picks[0]))
				if randf() * 100.0 < player._talent("martial_light_fingers"):   # Light Fingers: a second thing
					_snatch(foe, str(picks[1]))
		"pintheshadow":
			if foe:
				_throw_fx(foe)
				player.fire_caster._apply_effect_hit(foe, PINNED_FX, id, PackedStringArray(["Ability", "Physical"]), "physical")
				player._ring_effect(0.9, RogueIcons.STEEL, foe.global_position)
		"overtheshoulder":
			if foe:
				_vault_past(foe)
				_sure_crit_until = _now() + Balance.OVER_SHOULDER_TIME
				_buff(SURE_CRIT_FX, Abilities.ability_name(id), Balance.OVER_SHOULDER_TIME, RogueIcons.GOLD,
					"Your next hit is a sure critical strike.")
		"playdead":
			_play_dead()
	_sync()

func _in_melee(foe: Node3D) -> bool:
	var w: Dictionary = player._weapon()
	return player._in_weapon_range(foe, float(w.get("attack_range", 1.5)))

func _blade_col() -> Color:
	return RogueIcons.KILL if in_kill() else RogueIcons.FLOW

## A melee hit of mine (`gain` Flow if it lands).
func _melee_hit(foe: Node3D, coef: float, id: String, gain: int) -> void:
	_hitting = MELEE
	var dealt: int = player.deal_damage(foe, coef, id)
	_hitting = ""
	player._slash_effect(_blade_col())
	if dealt > 0:
		_landed(MELEE, gain)

## Throw `n` daggers into `foe` for `coef` each; each that lands sticks. `gain` Flow
## if any lands (`picture_only_once`: one flying dagger shows for all of them).
func _throw(foe: Node3D, coef: float, id: String, n: int, gain: int, picture_only_once: bool = false) -> void:
	var landed := 0
	for i in n:
		if not is_instance_valid(foe) or not foe.is_alive():
			break
		if i == 0 or not picture_only_once:
			_throw_fx(foe)
		_hitting = THROWN
		var hit_now := player.deal_damage(foe, coef, id)
		_hitting = ""
		if hit_now > 0:
			landed += 1
	if landed > 0:
		_stick(foe, landed)
		if gain > 0:
			_landed(THROWN, gain)

func _throw_fx(foe: Node3D) -> void:
	var from: Vector3 = player._muzzle()
	var to: Vector3 = foe.global_position + Vector3(0, 1.0, 0)
	if player.is_inside_tree():
		RogueFx.throw(player.get_tree().current_scene, from, to)
	player._net_fx("rogue_throw", from, foe)

## `n` more of my daggers stick in `e`.
func _stick(e: Node3D, n: int) -> void:
	if e == null or not is_instance_valid(e) or not e.is_alive():
		return
	var key := e.get_instance_id()
	var have := daggers_in(e)
	_daggers[key] = {"e": e, "n": daggers_after(have, n, dagger_max()), "until": _now() + Balance.DAGGER_TIME}
	_show_daggers(e)

## Rip up to `most` of my daggers out of `e`: each deals DAGGER_RIP ("Ripped Out").
func _rip(e: Node3D, most: int) -> void:
	var have := daggers_in(e)
	var n := mini(have, most)
	if n <= 0:
		return
	_daggers[e.get_instance_id()]["n"] = have - n
	player.deal_damage(e, Balance.DAGGER_RIP * float(n), RIP_ID, true, "physical", PackedStringArray(ROGUE_TAGS))
	_show_daggers(e)

func _show_daggers(e: Node3D) -> void:
	var n := daggers_in(e)
	RogueFx.set_daggers(e, "me", n)
	player._net_fx("rogue_daggers", e.global_position, e, {"n": n})

## A Rogue hit landed from `where`: Flow (none in a Kill window).
func _landed(where: String, gain: int) -> void:
	var switch := is_switch(_last_range, where)
	if switch:
		player._gain("energy", player._talent("martial_footloose"))   # Footloose
	_last_range = where
	_flow_at = _now()
	_decay_at = _flow_at + Balance.FLOW_HOLD + player._talent("martial_steady_pace")   # + Steady Pace
	if in_kill():
		return
	if _cold_read > 0:
		_cold_read -= 1
		gain *= 2   # Cold Read: after a Kill window
	_set_flow(flow_after(_flow, gain, switch, int(round(player._talent("martial_in_and_out"))), flow_max()))   # In and Out

## Whirl / Red Whirl: everyone around me, or Knife Spread with nobody close.
func _whirl(id: String, res: Resource) -> void:
	var foes: Array = player._enemies_within(float(res.radius))
	if not foes.is_empty():
		var share := Balance.aoe_share(foes.size())
		var hit := 0
		for e in foes:
			if player.deal_damage(e, float(res.damage) * share, id) > 0:
				hit += 1
			_rip(e, dagger_max())
		player._ring_effect(float(res.radius), _blade_col())
		if hit > 0:
			_landed(MELEE, whirl_flow(hit))
		return
	var coef := Balance.KNIFE_SPREAD_COEF if id == "whirl" else Balance.RED_SPREAD_COEF
	var hit2 := 0
	for e in _spread_targets():
		_throw_fx(e)
		_hitting = THROWN
		var spread_hit := player.deal_damage(e, coef, id)
		_hitting = ""
		if spread_hit > 0:
			hit2 += 1
			_stick(e, 1)
	if hit2 > 0:
		_landed(THROWN, whirl_flow(hit2))

## Knife Spread's targets: my target first, then the closest enemies in front of me.
func _spread_targets() -> Array:
	var out: Array = []
	var fwd: Vector3 = player._flat_forward()
	if player._has_valid_target():
		var to: Vector3 = player.target.global_position - player.global_position
		to.y = 0.0
		if to.length() > 0.01:
			fwd = to.normalized()
		if player.global_position.distance_to(player.target.global_position) <= Balance.THROW_RANGE:
			out.append(player.target)
	for e in player._enemies_near(player.global_position, Balance.THROW_RANGE):
		if out.size() >= Balance.KNIFE_SPREAD_TARGETS:
			break
		if out.has(e) or not player.can_see(e):
			continue
		if WheelKit.in_arc(player.global_position, fwd, e.global_position, Balance.KNIFE_SPREAD_ARC):
			out.append(e)
	return out

# --- Moving ---------------------------------------------------------------------------

## Dart In: dash to the target, stopping in weapon reach (walls stop it).
func _dash_to(foe: Node3D) -> void:
	var from: Vector3 = player.global_position
	_face(foe.global_position)
	var gap := Vector2(foe.global_position.x - from.x, foe.global_position.z - from.z).length() \
		- Combat.hitbox_radius(foe) - Combat.hitbox_radius(player)
	var want := LightningMeleeKit.static_step_travel(gap, float(player._weapon().get("attack_range", 1.5)))
	var dist := minf(player._dash_distance(want), want) if want > 0.0 else 0.0
	if dist > 0.0:
		var to: Vector3 = from + player._flat_forward() * dist
		to.y = from.y + (Combat.feet_y(foe) - Combat.feet_y(player)) * dist / want + 0.05
		player.global_position = to
	player._ring_effect(0.8, _blade_col(), from)

## Drive Through / Over the Shoulder: over or through the target, landing behind it.
func _vault_past(foe: Node3D) -> void:
	var from: Vector3 = player.global_position
	var gap := Combat.hitbox_radius(foe) + Combat.hitbox_radius(player) + Balance.OVER_SHOULDER_GAP
	var to := behind(from, foe.global_position, gap)
	var start: Vector3 = foe.global_position + Vector3(0, 0.3, 0)
	var q := PhysicsRayQueryParameters3D.create(start, to + Vector3(0, 0.3, 0), 1, [player.get_rid()])
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		to = behind(from, foe.global_position, maxf(start.distance_to(hit.position) - 0.6, 0.0))   # a wall behind it
	to.y = foe.global_position.y + (Combat.feet_y(player) - Combat.feet_y(foe)) + 0.05
	player.global_position = to
	_face(foe.global_position)
	player._ring_effect(0.8, _blade_col(), from)
	player._ring_effect(0.8, _blade_col())

## Kick Off / Back Flip: flip away from the target, still facing it.
func _flip_back(foe: Node3D) -> void:
	var from: Vector3 = player.global_position
	var away: Vector3 = from - foe.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else -player._flat_forward()
	player.global_position += away * player._dash_distance(Balance.KICK_OFF_DISTANCE, away)
	_face(foe.global_position)
	player._ring_effect(0.8, _blade_col(), from)

func _face(at: Vector3) -> void:
	var dir: Vector3 = at - player.global_position
	if Vector2(dir.x, dir.z).length() > 0.01:
		player.rotation.y = atan2(-dir.x, -dir.z)

# --- The Kill -------------------------------------------------------------------------

func _set_flow(n: int) -> void:
	_flow = clampi(n, 0, flow_max())
	_show_flow()

func _open_kill(time: float) -> void:
	_kill_flow = _flow   # (In the Zone counts it through the window)
	_set_flow(0)
	_kill_until = _now() + time + player._talent("martial_hot_start")   # + Hot Start
	_kill_last = ""
	_kill_extra = 0.0
	_show_kill()
	player._ring_effect(1.6, RogueIcons.KILL)

func _end_kill() -> void:
	if _kill_until > 0.0:
		_cold_read = int(round(player._talent("martial_cold_read")))   # Cold Read
	_kill_until = 0.0
	_kill_last = ""
	if player.status:
		player.status.remove(KILL_FX)

## A Kill form went off: one that differs from the last adds to the window.
func _kill_form_used(form: String) -> void:
	var add := variety_add(_kill_last, form, _kill_extra, player._talent("martial_mix_it_up"))   # + Mix It Up
	_kill_last = form
	if add > 0.0 and in_kill():
		_kill_until += add
		_kill_extra += add
		_show_kill()

func _show_kill() -> void:
	var left := kill_left()
	if left <= 0.0:
		return
	_buff(KILL_FX, "Kill Window", left, RogueIcons.KILL,
		"Your builders take their Kill forms and your crits give Energy back.")

func _show_flow() -> void:
	if player.status == null:
		return
	if _flow <= 0:
		player.status.remove(FLOW_FX)
		return
	if not player.status.has(FLOW_FX):
		var fx := StatusContainer.make_buff(FLOW_FX, "Flow", FLOW_FX, 0.0, 3600.0, Balance.FLOW_MAX + 2, RogueIcons.FLOW)   # (+2: Deep Flow)
		fx.stat_modifiers = {}
		fx.tags = PackedStringArray(["Physical"])
		fx.description = "You deal %s%% more damage per stack. Go In spends it on a Kill window." % Stats.num(Balance.FLOW_PCT)
		player.status.apply(fx, player)
	if player.status.stacks_of(FLOW_FX) != _flow:
		player.status.set_stacks(FLOW_FX, _flow)

func _roll_with_it() -> void:
	var fx := StatusContainer.make_buff(ROLL_FX, Abilities.ability_name("rollwithit"), ROLL_FX, 0.0,
		Balance.ROLL_WITH_IT_TIME, 1, RogueIcons.FLOW)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Physical", "Defensive"])
	fx.damage_mod_pct = -Balance.ROLL_WITH_IT_PCT
	fx.modifies_incoming = true
	fx.mod_affects_dots = true
	fx.description = "Rolling with the blows: you take %s%% less damage." % Stats.num(Balance.ROLL_WITH_IT_PCT)
	player.status.apply(fx, player)
	player.status.set_remaining(ROLL_FX, Balance.ROLL_WITH_IT_TIME)
	player._ring_effect(1.0, RogueIcons.FLOW)

func _buff(fx_id: String, title: String, time: float, col: Color, text: String) -> void:
	if player.status == null:
		return
	var fx := StatusContainer.make_buff(fx_id, title, fx_id, 0.0, time, 1, col)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Physical"])
	fx.description = text
	player.status.apply(fx, player)
	player.status.set_remaining(fx_id, time)

# --- Snatch ---------------------------------------------------------------------------

func _snatch(foe: Node3D, item: String) -> void:
	player._combat().float_text(player, str(SNATCH_NAMES.get(item, item)), RogueIcons.GOLD, false)
	match item:
		"flashpowder":
			for e in player._enemies_within(Balance.FLASH_POWDER_REACH):
				if str(e.get("rank")) == "boss":
					continue
				if WheelKit.in_arc(player.global_position, player._flat_forward(), e.global_position, Balance.FLASH_POWDER_ARC):
					player.fire_caster._apply_effect_hit(e, BLINDED_FX, "snatch", PackedStringArray(ROGUE_TAGS), "physical")
			player._ring_effect(1.5, Color(1, 1, 0.85), player.global_position + player._flat_forward() * 2.0)
		"whetstone":
			_whetstone = Balance.WHETSTONE_HITS
			var fx := StatusContainer.make_buff(WHETSTONE_FX, SNATCH_NAMES["whetstone"], WHETSTONE_FX, 0.0, 3600.0,
				Balance.WHETSTONE_HITS, RogueIcons.STEEL)
			fx.stat_modifiers = {}
			fx.tags = PackedStringArray(["Physical"])
			fx.description = "Freshly sharpened: your next hits deal %s%% more damage." % Stats.num(Balance.WHETSTONE_PCT)
			player.status.apply(fx, player)
			player.status.set_stacks(WHETSTONE_FX, _whetstone)
		"smokeflask":
			_forget_all(0.0, true)
			var smoke := StatusContainer.make_buff(SMOKE_FX, SNATCH_NAMES["smokeflask"], Stats.DODGE,
				Balance.SMOKE_FLASK_DODGE, Balance.SMOKE_FLASK_TIME, 1, Color(0.7, 0.7, 0.75))
			smoke.tags = PackedStringArray(["Physical", "Defensive"])
			smoke.description = "Hidden in smoke: more Dodge."
			player.status.apply(smoke, player)
			player.status.set_remaining(SMOKE_FX, Balance.SMOKE_FLASK_TIME)
			player._ring_effect(2.0, Color(0.7, 0.7, 0.75))
		"oiljar":
			var at := foe.global_position
			_pools.append({"pos": at, "until": _now() + Balance.OIL_JAR_TIME, "next": _now()})
			player._ring_effect(Balance.OIL_JAR_RADIUS, Color(1.0, 0.5, 0.15), at)

func _tick_pools(now: float) -> void:
	for i in range(_pools.size() - 1, -1, -1):
		var p: Dictionary = _pools[i]
		if now > float(p["until"]):
			_pools.remove_at(i)
			continue
		if now < float(p["next"]):
			continue
		p["next"] = float(p["next"]) + Balance.OIL_JAR_TICK
		var foes: Array = player._enemies_near(p["pos"], Balance.OIL_JAR_RADIUS)
		var share := Balance.aoe_share(foes.size())
		for e in foes:
			player.deal_damage(e, Balance.OIL_JAR_COEF * share, OIL_ID, true, "fire", PackedStringArray(OIL_TAGS))
		player._ring_effect(Balance.OIL_JAR_RADIUS, Color(1.0, 0.5, 0.15), p["pos"])

# --- Play Dead / threat ---------------------------------------------------------------

func _play_dead() -> void:
	_dead_until = _now() + Balance.PLAY_DEAD_TIME
	_forget_all(Balance.PLAY_DEAD_TIME, false)
	_buff(PLAY_DEAD_FX, Abilities.ability_name("playdead"), Balance.PLAY_DEAD_TIME, RogueIcons.STEEL,
		"Enemies have forgotten you. Using anything or attacking ends it.")
	_pose(true)

## Play Dead ends early (I acted).
func _get_up() -> void:
	if _dead_until <= 0.0:
		return
	var was := playing_dead()
	_dead_until = 0.0
	if player.status:
		player.status.remove(PLAY_DEAD_FX)
	_pose(false)
	if was:
		_forget_all(0.0, false)   # they remember me again

func _pose(on: bool) -> void:
	RogueFx.play_dead(player, on)
	player._net_fx("rogue", player.global_position, null, {"dead": on, "f": _flow, "k": in_kill()})

## Every enemy near drops my threat; for `time` seconds it also forgets me
## (0: only the threat, or Play Dead is over). `drop_only`: Smoke Flask.
func _forget_all(time: float, drop_only: bool) -> void:
	var net: Node = player._net()
	for e in player.get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D) or not e.is_alive() or (e as Node3D).global_position.distance_to(player.global_position) > FORGET_REACH:
			continue
		if drop_only:
			if net:
				net.drop_threat(e, player)
			elif e.has_method("drop_threat"):
				e.drop_threat(player)
		elif net:
			net.forget(e, player, time)
		elif e.has_method("forget"):
			e.forget(player, time)

## Any ability I use (SignalBus.ability_used): Play Dead ends.
func _on_ability_used(id: String) -> void:
	if id != "playdead" and playing_dead():
		_get_up()

# --- Hits -----------------------------------------------------------------------------

## Over the Shoulder: my next hit (not over time) is a sure crit (Player.adjust_crit).
## In the Zone: my Flow (in a Kill window, the Flow spent on it) gives crit chance too.
func adjust_crit(info: RefCounted, chance: float) -> float:
	var zone := player._talent("martial_in_the_zone")
	if zone > 0.0:
		chance += in_the_zone_crit(_kill_flow if in_kill() else _flow, zone)
	if info.is_dot or info.is_proc or _sure_crit_until <= _now():
		return chance
	_sure_crit_until = 0.0
	if player.status:
		player.status.remove(SURE_CRIT_FX)
	return chance + 100.0

## SignalBus.damage_modify: my Flow and Whetstone make my hits harder.
func _on_damage_modify(info: RefCounted) -> void:
	if info.source != player:
		return
	if _flow > 0:
		info.add_bonus(Balance.FLOW_PCT * float(_flow), "Flow")
	if not info.is_dot and not str(info.ability_id).begins_with("auto_"):
		# Thrown Weight / Close Work: where the hit came from (a Rogue throw, or any melee ability).
		if _hitting == THROWN:
			var thrown := player._talent("martial_thrown_weight")
			if thrown > 0.0:
				info.add_bonus(thrown, "Thrown Weight")
		elif info.tags.has("Melee") and info.tags.has("Ability"):
			var close := player._talent("martial_close_work")
			if close > 0.0:
				info.add_bonus(close, "Close Work")
	# Easy Pickings: an enemy carrying enough of my daggers.
	var pick := player._talent("martial_easy_pickings")
	if pick > 0.0 and is_instance_valid(info.target) and daggers_in(info.target) >= Balance.EASY_PICKINGS_DAGGERS:
		info.add_bonus(pick, "Easy Pickings")
	if _whetstone > 0 and not info.is_dot:
		info.add_bonus(Balance.WHETSTONE_PCT, SNATCH_NAMES["whetstone"])
		_whetstone -= 1
		if player.status:
			if _whetstone <= 0:
				player.status.remove(WHETSTONE_FX)
			else:
				player.status.set_stacks(WHETSTONE_FX, _whetstone)

## SignalBus.damage_dealt: my crits in a Kill window give Energy; an attack ends Play Dead.
func _on_damage_dealt_rogue(info: RefCounted) -> void:
	if info.source != player:
		return
	if str(info.ability_id).begins_with("auto_") and playing_dead():
		_get_up()
	if info.crit and not info.is_dot and in_kill() \
			and (Abilities.ROGUE_IDS.has(str(info.ability_id)) or str(info.ability_id) == RIP_ID):
		player._gain("energy", Balance.KILL_CRIT_ENERGY + player._talent("martial_fresh_legs"))   # + Fresh Legs
	elif info.crit and not info.is_dot and not in_kill() and Abilities.ROGUE_IDS.has(str(info.ability_id)):
		if randf() * 100.0 < player._talent("martial_pressure_point"):   # Pressure Point
			_set_flow(_flow + 1)

# --- Every frame ----------------------------------------------------------------------

func _tick_rogue(_delta: float) -> void:
	var now := _now()
	if player.is_dead():
		_flow = 0
		_kill_until = 0.0
		_last_range = ""
	var fighting: bool = player.is_in_combat()
	if _was_in_combat and not fighting:
		_last_range = ""   # leaving combat: the next fight starts with no range to switch from
	_was_in_combat = fighting
	if _flow > 0 and now >= _decay_at and not in_kill():
		_set_flow(_flow - 1)
		_decay_at = now + Balance.FLOW_DECAY_EVERY
	if _kill_until > 0.0 and now >= _kill_until:
		_end_kill()
	if _dead_until > 0.0 and now >= _dead_until:
		_dead_until = 0.0
		_pose(false)
	if not _pools.is_empty():
		_tick_pools(now)
	for key in _daggers.keys():
		var d: Dictionary = _daggers[key]
		if not is_instance_valid(d["e"]) or not d["e"].is_alive() or now > float(d["until"]) or int(d["n"]) <= 0:
			if is_instance_valid(d["e"]):
				RogueFx.set_daggers(d["e"], "me", 0)
				player._net_fx("rogue_daggers", d["e"].global_position, d["e"], {"n": 0})
			_daggers.erase(key)
	_sync()
	if now - _told >= TELL_EVERY and _shown != "":
		_tell()

## The Flow ring shows my Flow and Kill window; the party is told when it changes.
func _sync() -> void:
	var want := "%d|%s" % [_flow, str(in_kill())] if (_flow > 0 or in_kill()) and not player.is_dead() else ""
	if want == _shown:
		return
	_shown = want
	if player.is_inside_tree():
		RogueFx.show_flow(player, _flow if want != "" else 0, flow_max(), in_kill() and want != "")
	_tell()

func _tell() -> void:
	_told = _now()
	player._net_fx("rogue", player.global_position, null, {"f": _flow if _shown != "" else 0, "k": in_kill() and _shown != "", "dead": playing_dead()})
