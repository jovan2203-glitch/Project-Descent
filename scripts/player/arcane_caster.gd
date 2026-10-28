extends "res://scripts/player/player_kit.gd"
class_name ArcaneCasterKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "arcane_caster".
# --- Arcane caster: the cooldown kit -------------------------------------------------------
# Sigil Darts is the filler: a channel of darts with no cooldown. Unravel takes
# time off my other Arcane cooldowns, Lapse and Interval Ward make them recover
# faster, Rewind resets one, and Convergence hits harder for each one that is
# running. Countdown, Collapse and Mirror Sigil are the cooldowns worth juggling.
# "Arcane spell" = tagged Arcane + Spell. Interrupts are left out of every
# cooldown change (they share a cooldown of their own). Numbers are in balance.gd.

const ARCANE_MARK = preload("res://scripts/arcane_mark.gd")
const SIGIL_DARTS_ID := "arcanemissiles"
const UNRAVEL_ID := "unravel"
const COUNTDOWN_ID := "countdown"
const COUNTDOWN_FX := "countdown"
const CONVERGENCE_ID := "convergence"
const REWIND_ID := "rewind"
const LAPSE_ID := "lapse"
const LAPSE_FX := "lapse"
const MIRROR_ID := "mirrorsigil"
const MIRROR_FX := "mirror_sigil"
const COLLAPSE_ID := "collapse"
const SCATTER_ID := "scatter"
const SCATTER_FX := "scatter"
const SCATTER_LABEL := "Scatter"
const WARD_ID := "intervalward"
const WARD_FX := "interval_ward"
const AFTERIMAGE_RUNE := "afterimage"
const AFTERIMAGE_FX := "afterimage"
const ARCANE_TAGS := ["Arcane", "Spell"]
const GLINT_ID := "glint"
const GLINT_FX := "glint"
const MOMENTUM_RUNE := "momentum"
const CARRIED_RUNE := "carried_sigil"
## Rune of the Two-Way Mirror: Mirror Sigil also repeats my Reflections shattering.
const TWO_WAY_MIRROR_RUNE := "two_way_mirror"
const CHAIN_REACTION_ID := "chain_reaction"
const AFTERSHOCK_FX := "aftershock"

var _darts_total := 0            # darts this Sigil Darts launches in all (Seventh Sigil adds to it)
var _glint_cast := false         # the current cast / channel may go on while I move (Glint)
var _sigil_carried := false      # my Mirror Sigil moves with me (Rune of the Carried Sigil)
var _slow_mult_now := 1.0        # strength of the slow being applied right now (Aftershock's rank)

var _arcane_ids := {}            # ability id -> is it an Arcane spell (looked up once)
var _rewind_spell := ""          # the last Arcane spell I cast that Rewind can reset
var _darts_left := 0             # darts still to launch this channel
var _darts_dmg := 0.0
var _darts_fired := 0
var _darts_scattered := false    # this Sigil Darts used up Scatter
var _darts_targets: Array = []   # ... and deals its darts out between these
var _bolt_tag := ""              # the tag of the bolt whose hit is being dealt right now
var _countdowns := {}            # enemy instance id -> {"target": Node3D, "dealt": int, "base": float, "at": detonation time}
var _sigil_at := Vector3.ZERO    # where my Mirror Sigil stands
var _ward_until := 0.0           # when my Interval Ward would run out by itself
var _image_at := Vector3.ZERO    # where my Afterimage stands
var _image_spell := ""           # the spell the image is casting along with me
var _image_until := 0.0          # ... until this time

## Does the kit count something with these tags as an Arcane spell?
static func arcane_spell(tags: PackedStringArray, is_interrupt: bool = false) -> bool:
	return tags.has("Arcane") and tags.has("Spell") and not is_interrupt

func _is_arcane_spell(id: String) -> bool:
	if not _arcane_ids.has(id):
		_arcane_ids[id] = Abilities.PATHS.has(id) and arcane_spell(Abilities.tags_of(id), Player.INTERRUPT_LOCKOUT.has(id))
	return bool(_arcane_ids[id])

## How fast my Arcane cooldowns recover (1 = normal) with Lapse and / or Interval Ward up.
static func arcane_recovery_rate(lapse: bool, ward: bool) -> float:
	return 1.0 + (Balance.LAPSE_RATE_PCT if lapse else 0.0) / 100.0 \
		+ (Balance.INTERVAL_WARD_RATE_PCT if ward else 0.0) / 100.0

## How fast one cooldown recovers (1 = normal). `spell_rate` (Lapse, Interval
## Ward) is for my Arcane spells alone; Running Clock's `clock_pct` % is for
## everything Arcane: those spells and whatever else is in the Arcane book
## (never an interrupt).
static func arcane_cooldown_rate(spell_rate: float, is_spell: bool, in_book: bool, clock_pct: float) -> float:
	var rate := spell_rate if is_spell else 1.0
	if is_spell or in_book:
		rate += maxf(clock_pct, 0.0) / 100.0
	return rate

var _arcane_book_ids := {}      # ability id -> is it in the Arcane book and no interrupt (looked up once)

func _in_arcane_book(id: String) -> bool:
	if not _arcane_book_ids.has(id):
		_arcane_book_ids[id] = ArcaneTankKit.shatter_cuts(Abilities.category_of(id), Player.INTERRUPT_LOCKOUT.has(id))
	return bool(_arcane_book_ids[id])

func _arcane_rate() -> float:
	if player.status == null:
		return 1.0
	return arcane_recovery_rate(player.status.has(LAPSE_FX), player.status.has(WARD_FX))

## Arcane spells I have on cooldown (not counting `except`).
func arcane_cooldowns(except: String = "") -> int:
	var n := 0
	for id in player.cooldowns:
		if str(id) != except and float(player.cooldowns[id]) > 0.0 and _is_arcane_spell(str(id)):
			n += 1
	return n

## Convergence: % more damage with `count` other Arcane spells on cooldown.
static func convergence_bonus(count: int) -> float:
	return Balance.CONVERGENCE_PCT * clampi(count, 0, Balance.CONVERGENCE_MAX)

static func convergence_coef(base: float, count: int) -> float:
	return base * (1.0 + convergence_bonus(count) / 100.0)

## Unravel: what is left of a cooldown of `left` seconds after one cast.
static func unravel_cooldown(left: float) -> float:
	return maxf(left - Balance.UNRAVEL_SECONDS, 0.0)

func _unravel_cooldowns() -> void:
	for id in player.cooldowns.keys():
		if str(id) == UNRAVEL_ID or not _is_arcane_spell(str(id)):
			continue
		player.arcane_talents.time_taken_off()   # Unwinding
		var left := unravel_cooldown(float(player.cooldowns[id]))
		if left <= 0.0:
			player.cooldowns.erase(id)
		else:
			player.cooldowns[id] = left

## Can Rewind reset a spell with these tags and this cooldown?
static func rewind_allows(tags: PackedStringArray, cooldown: float, is_interrupt: bool = false) -> bool:
	return arcane_spell(tags, is_interrupt) and cooldown > 0.0 and cooldown < Balance.REWIND_MAX_COOLDOWN

## Every spell I finish casting: Rewind remembers the last one it could reset.
func _on_cast_for_arcane(id: String) -> void:
	if id == REWIND_ID or not Abilities.PATHS.has(id):
		return
	var res := Abilities.get_resource(id)
	if res and rewind_allows(res.tags, Abilities.cooldown_of(res), Player.INTERRUPT_LOCKOUT.has(id)):
		_rewind_spell = id

## An instant Arcane button that is off the global cooldown: ready and paid for?
func _arcane_instant_ok(id: String) -> bool:
	if float(player.cooldowns.get(id, 0.0)) > 0.0:
		player._error("%s is not ready yet" % Abilities.ability_name(id))
		return false
	return true

func _arcane_buff(fx_id: String, id: String, time: float, text: String) -> void:
	var fx := StatusContainer.make_buff(fx_id, Abilities.ability_name(id), fx_id, 0.0, time, 1, Abilities.color_of(id))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Arcane"])
	fx.description = text
	player.status.apply(fx, player)

## Rewind: the last Arcane spell I cast with a short cooldown is ready again.
func _rewind() -> void:
	if not _arcane_instant_ok(REWIND_ID):
		return
	if _rewind_spell == "" or float(player.cooldowns.get(_rewind_spell, 0.0)) <= 0.0:
		player._error("Nothing to rewind")
		return
	if not player._pay(REWIND_ID):
		return
	player.cooldowns.erase(_rewind_spell)
	player.cooldowns[REWIND_ID] = Abilities.cooldown_of(Abilities.get_resource(REWIND_ID))
	player._ring_effect(1.0, Abilities.color_of(REWIND_ID))
	player._ring_effect(0.6, Color(0.95, 0.9, 1.0))
	player._bus().cast_finished.emit(REWIND_ID)

## Lapse: my Arcane cooldowns recover faster for a while (see _tick_cooldowns).
func _lapse() -> void:
	if not _arcane_instant_ok(LAPSE_ID) or not player._pay(LAPSE_ID):
		return
	player.cooldowns[LAPSE_ID] = Abilities.cooldown_of(Abilities.get_resource(LAPSE_ID))
	_arcane_buff(LAPSE_FX, LAPSE_ID, Balance.LAPSE_TIME, "Your Arcane spells recover their cooldowns faster.")
	player._ring_effect(1.4, Abilities.color_of(LAPSE_ID))
	player._bus().cast_finished.emit(LAPSE_ID)

## Scatter: my next Sigil Darts is dealt out between the enemies around its target.
func _scatter() -> void:
	if not _arcane_instant_ok(SCATTER_ID) or not player._pay(SCATTER_ID):
		return
	player.cooldowns[SCATTER_ID] = Abilities.cooldown_of(Abilities.get_resource(SCATTER_ID))
	_arcane_buff(SCATTER_FX, SCATTER_ID, Balance.SCATTER_TIME,
		"Your next %s splits its darts between nearby enemies, and each dart deals more damage." % Abilities.ability_name(SIGIL_DARTS_ID))
	player._ring_effect(0.9, Abilities.color_of(SCATTER_ID))
	player._bus().cast_finished.emit(SCATTER_ID)

# Sigil Darts: a channel that launches ARCANE_MISSILES_COUNT darts, spread evenly
# over it (so Haste makes them come faster). Each dart is its own hit with its
# own crit roll. Paid for when the channel starts.

## Darts one Sigil Darts launches with `extra` more from Seventh Sigil.
static func dart_count(extra: float) -> int:
	return Balance.ARCANE_MISSILES_COUNT + maxi(int(round(extra)), 0)

func sigil_dart_count() -> int:
	return dart_count(player._talent("arcane_seventh_sigil"))

## Which of `targets` enemies dart number `fired` (0 = the first) goes to.
static func dart_target(fired: int, targets: int) -> int:
	return fired % targets if targets > 0 else 0

## Scatter: my target and the closest other enemies around it that I can see.
func _scatter_targets(tgt: Node3D) -> Array:
	var out: Array = [tgt]
	for e in player._enemies_near(tgt.global_position, Balance.SCATTER_RADIUS, tgt):
		if out.size() >= Balance.SCATTER_TARGETS:
			break
		if player.can_see(e):
			out.append(e)
	return out

func _start_sigil_darts() -> void:
	var id := SIGIL_DARTS_ID
	if player.casting or not player.is_on_floor():
		return
	if player.cooldown_left(id) > 0.0:
		player._error("%s is not ready yet" % Abilities.ability_name(id))
		return
	if not player._has_valid_target():
		player._error("No target")
		return
	var res := Abilities.get_resource(id)
	if res.cast_range > 0.0 and player.global_position.distance_to(player.target.global_position) > res.cast_range:
		player._error("Target out of range")
		return
	var sight_err := player._target_error(player.target)
	if sight_err != "":
		player._error(sight_err)
		return
	var echo := player.echoing()   # a free cast (Rune of the Wild Page) never channels: a burst
	var instant := echo or player.fire_cooldowns.concentrated_fire_ready(id)
	if not player._pay(id):
		return
	if float(res.cooldown) > 0.0:
		player.cooldowns[id] = Abilities.cooldown_of(res)
	_darts_dmg = float(res.damage)
	_darts_total = sigil_dart_count()
	_darts_fired = 0
	_darts_scattered = player.status.has(SCATTER_FX)
	_darts_targets = _scatter_targets(player.target) if _darts_scattered else []
	if _darts_scattered:
		player.status.remove(SCATTER_FX)   # this is the Sigil Darts it was waiting for
	if instant:
		# Concentrated Fire (Rune of the Level Head): no channel, the darts go out in a quick burst.
		player.status.spend_stacks(FireCooldownsKit.CONC_ID)
		var tgt := player.target
		for i in _darts_total:
			player.echo_timer(Balance.SIGIL_DARTS_BURST_GAP * i).timeout.connect(func():
				if player.is_alive() and is_instance_valid(tgt) and tgt.is_alive():
					_launch_dart(tgt))   # (a free cast's burst: its timers keep it an echo)
		player._bus().cast_finished.emit(id)   # an instant: starts the global cooldown like one
		return
	player._begin_spell(id, str(res.display_name), float(res.cast_time), true)
	_darts_left = _darts_total if player.casting and player.current_spell == id else 0

## One dart: at `main`, or (Scatter) at whichever enemy's turn it is.
func _launch_dart(main: Node3D) -> void:
	var tgt := main
	if _darts_scattered:
		var live := _darts_targets.filter(func(e): return is_instance_valid(e) and e.is_alive())
		if not live.is_empty():
			tgt = live[dart_target(_darts_fired, live.size())]
	_darts_fired += 1
	if not is_instance_valid(tgt) or not tgt.is_alive():
		return
	var bolt := Player.FROST_BOLT.spawn(player.get_tree().current_scene, player._muzzle(), tgt, player, false, SIGIL_DARTS_ID, _darts_dmg)
	if _darts_scattered:
		bolt.set("tag", SCATTER_FX)   # (its hit gets Scatter's bonus: bolt_tag, _on_damage_modify)

## A bolt of mine tells me its tag right before its hit is dealt ("" right after).
func bolt_tag(t: String) -> void:
	_bolt_tag = t

## Launch every dart that is due by now (`final` = all that are left).
func _sigil_darts_tick(final: bool = false) -> void:
	if _darts_left <= 0:
		return
	var hits := maxi(_darts_total, 1)
	var due := hits
	if not final:
		var every := maxf(player.cast_duration / hits, 0.01)
		due = mini(int(floor((player.cast_duration - maxf(player.cast_timer, 0.0)) / every + 0.0001)), hits)
	while hits - _darts_left < due:
		_darts_left -= 1
		if player._has_valid_target():
			_launch_dart(player.target)

# Countdown: a mark on one enemy (own only). It counts the Arcane damage I deal
# to that enemy, and after COUNTDOWN_TIME seconds it detonates for the ability's
# damage plus COUNTDOWN_SHARE_PCT % of what it counted. Casting it again on the
# same enemy sets the old mark off first.

## Countdown: the extra damage for `dealt` Arcane damage counted, at `pct` % of it.
static func countdown_bonus(dealt: int, pct: float) -> int:
	return int(round(maxf(float(dealt), 0.0) * maxf(pct, 0.0) / 100.0))

func _plant_countdown(tgt: Node3D) -> void:
	if tgt == null or not is_instance_valid(tgt) or not tgt.is_alive():
		return
	var key := tgt.get_instance_id()
	if _countdowns.has(key):
		_detonate_countdown(key)   # the old mark goes off now
		if not is_instance_valid(tgt) or not tgt.is_alive():
			return
	_countdowns[key] = {"target": tgt, "dealt": 0, "base": float(Abilities.get_resource(COUNTDOWN_ID).damage),
		"at": Time.get_ticks_msec() / 1000.0 + Balance.COUNTDOWN_TIME, "echo": player.echoing()}   # (echo: planted by a free cast)
	# The debuff shows the mark to the whole party (it only ever counts MY damage).
	player.fire_caster._apply_effect_hit(tgt, preload("res://scripts/core/effects.gd").get_effect(COUNTDOWN_FX), COUNTDOWN_ID,
		PackedStringArray(ARCANE_TAGS), "arcane")
	player._ring_effect(0.8, Abilities.color_of(COUNTDOWN_ID), tgt.global_position)

## A hit of mine landed: Arcane damage on a marked enemy is counted.
func _countdown_tally(foe: Node, id: String, damage_type: String, amount: int) -> void:
	if _countdowns.is_empty() or amount <= 0 or id == COUNTDOWN_ID or damage_type != "arcane":
		return
	var key := foe.get_instance_id()
	if _countdowns.has(key):
		_countdowns[key]["dealt"] = int(_countdowns[key]["dealt"]) + amount

func _tick_countdowns() -> void:
	if _countdowns.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	for key in _countdowns.keys():
		var c: Dictionary = _countdowns[key]
		if not is_instance_valid(c["target"]) or not c["target"].is_alive():
			_countdowns.erase(key)
		elif now >= float(c["at"]):
			_detonate_countdown(key)

func _detonate_countdown(key: int) -> void:
	var c: Dictionary = _countdowns[key]
	if bool(c.get("echo", false)) and not player.echoing():
		player.as_echo(func(): _detonate_countdown(key))   # a free cast's mark goes off as an echo
		return
	_countdowns.erase(key)
	var tgt: Variant = c["target"]
	if not is_instance_valid(tgt) or not tgt.is_alive():
		return
	var net := player._net()
	if net:
		net.remove_effect(tgt, player, COUNTDOWN_FX)   # the host owns enemy effects in a party
	else:
		var st: Node = tgt.get_node_or_null("Status")
		if st:
			st.remove_from(COUNTDOWN_FX, player)
	player._ring_effect(1.5, Abilities.color_of(COUNTDOWN_ID), tgt.global_position)
	player._ring_effect(0.8, Color(0.95, 0.9, 1.0), tgt.global_position)
	var at: Vector3 = tgt.global_position   # (kept: the target may not survive it)
	player.deal_damage(tgt, float(c["base"]), COUNTDOWN_ID, true)
	# What it counted was already worked out hit by hit: its share is dealt as it is.
	var extra := countdown_bonus(int(c["dealt"]), Balance.COUNTDOWN_SHARE_PCT)
	_exact_hit(tgt, extra, COUNTDOWN_ID, "arcane", PackedStringArray(ARCANE_TAGS))
	_chain_reaction(at, tgt, extra)   # Chain Reaction: part of it hits the enemies around

## Deal exactly `amount` damage to `foe` under ability `id`: a proc that can't
## crit or be avoided, with nothing added (its source was already worked out)
## but `bonuses`: [percent, label] rows that come on top, each a line of its own
## on the damage meter.
func _exact_hit(foe: Variant, amount: int, id: String, damage_type: String, tags: PackedStringArray, bonuses: Array = []) -> void:
	if amount <= 0 or foe == null or not is_instance_valid(foe) or not foe.is_alive():
		return
	var hit := DamageInfo.make(player, foe, 1.0, id)
	for b in bonuses:
		hit.add_bonus(float(b[0]), str(b[1]))
	hit.unit = float(amount)
	hit.exact = true
	hit.add_power = false
	hit.can_crit = false
	hit.can_block = false
	hit.is_proc = true
	hit.damage_type = damage_type
	hit.tags = tags
	player._combat().deal(hit)

# Echoes: Mirror Sigil and the Rune of the Afterimage repeat my spells. Each
# echo is an exact share of the hit it repeats (its crit and every modifier are
# already in it), flown from where the sigil / image stands, and dealt as a proc
# under its own name, so it has its own line on the damage meter and feeds nothing.

## Damage of an echo of a hit of `amount` at `pct` % of it.
static func echo_amount(amount: int, pct: float) -> int:
	return int(round(maxf(float(amount), 0.0) * maxf(pct, 0.0) / 100.0))

## Does Mirror Sigil repeat this hit? My Arcane spells' own hits (and Countdown
## going off), not damage over time, procs or another echo.
## `two_way` = the Rune of the Two-Way Mirror: a Reflection shattering is repeated too.
static func mirror_echoes(tags: PackedStringArray, is_proc: bool, id: String, two_way: bool = false) -> bool:
	if id == ArcaneTankKit.REFLECTION_SHATTER_ID:
		return two_way
	if id == MIRROR_ID or id == AFTERIMAGE_RUNE or not arcane_spell(tags):
		return false
	return not is_proc or id == COUNTDOWN_ID

func _echo_hit(info: RefCounted, pct: float, id: String, from: Vector3) -> void:
	var foe: Node = info.target
	var amount := echo_amount(int(info.amount), pct)
	if amount <= 0 or not (foe is Node3D):
		return
	# The picture of the spell flies from the sigil / image; the hit lands with it.
	# (What it repeats is not always an ability, e.g. a Reflection shattering: then it looks like the echo itself.)
	var look := str(info.ability_id) if Abilities.PATHS.has(str(info.ability_id)) or not Abilities.PATHS.has(id) else id
	Player.FROST_BOLT.spawn(player.get_tree().current_scene, from, foe, null, true, look, 0.0)
	var net := player._net()
	if net:
		net.send_fx("bolt", from, foe, look)
	var damage_type := str(info.damage_type)
	var tags: PackedStringArray = info.tags
	var wait := from.distance_to(foe.global_position) / maxf(Balance.BOLT_SPEED, 1.0)
	player.echo_timer(maxf(wait, 0.02)).timeout.connect(func():
		if player.is_alive():
			_exact_hit(foe, amount, id, damage_type, tags))

## Mirror Sigil: a cast, then the sigil stands where I stood.
func _start_mirror_sigil() -> void:
	if player.casting or not player.is_on_floor():
		return
	if player.cooldown_left(MIRROR_ID) > 0.0:
		player._error("%s is not ready yet" % Abilities.ability_name(MIRROR_ID))
		return
	if not player.can_afford(MIRROR_ID, true):
		return
	var res := Abilities.get_resource(MIRROR_ID)
	player.cast_point = player.global_position + player._flat_forward() * 5.0   # (what I face while casting)
	player._begin_spell(MIRROR_ID, str(res.display_name), float(res.cast_time))

func _place_mirror_sigil() -> void:
	var res := Abilities.get_resource(MIRROR_ID)
	player.cooldowns[MIRROR_ID] = Abilities.cooldown_of(res)
	_sigil_at = Vector3(player.global_position.x, Combat.feet_y(player), player.global_position.z)
	_sigil_carried = player.frost_melee._has_rune(CARRIED_RUNE)   # Rune of the Carried Sigil: it moves with me
	_arcane_buff(MIRROR_FX, MIRROR_ID, Balance.MIRROR_SIGIL_TIME,
		"Your sigil follows you and repeats the Arcane spells you cast." if _sigil_carried \
		else "Your sigil repeats the Arcane spells you cast.")
	_arcane_mark("sigil", _sigil_at, Balance.MIRROR_SIGIL_RADIUS, Balance.MIRROR_SIGIL_TIME, _sigil_carried)
	player._ring_effect(Balance.MIRROR_SIGIL_RADIUS, Abilities.color_of(MIRROR_ID))

## Show one of the kit's ground pictures, here and to the party (time 0 = take it away).
## `carried` = it moves with me (Rune of the Carried Sigil).
func _arcane_mark(kind: String, at: Vector3, r: float, time: float, carried: bool = false) -> void:
	if not player.is_inside_tree():
		return
	if time > 0.0:
		var mark := ARCANE_MARK.spawn(player.get_tree().current_scene, at, r, time, kind, "me")
		if carried:
			mark.set("follow", player)
	else:
		ARCANE_MARK.clear(player.get_tree(), kind, "me")
	player._net_fx("arcanemark", at, null, {"kind": kind, "r": r, "time": time, "follow": carried})

# Collapse: ground-targeted. COLLAPSE_DELAY seconds after the cast the circle
# falls in on its centre: it damages every enemy in it and drags them toward the
# middle (bosses are too heavy, and nobody is dragged through a wall).

## Where an enemy at `pos` ends up when a Collapse at `centre` drags it `pull`
## metres (never closer to the centre than `core`). Height is kept.
static func collapse_point(pos: Vector3, centre: Vector3, pull: float, core: float) -> Vector3:
	var to := Vector3(centre.x - pos.x, 0.0, centre.z - pos.z)
	var dist := to.length()
	var step := minf(maxf(pull, 0.0), maxf(dist - core, 0.0))
	if step <= 0.0 or dist <= 0.001:
		return pos
	return pos + to / dist * step

func _start_collapse(point: Vector3) -> void:
	if player.casting or not player.is_on_floor():
		return
	player.cast_point = point
	if not player.can_afford(COLLAPSE_ID, true):
		return
	var res := Abilities.get_resource(COLLAPSE_ID)
	player._begin_spell(COLLAPSE_ID, str(res.display_name), float(res.cast_time))

func _cast_collapse() -> void:
	var res := Abilities.get_resource(COLLAPSE_ID)
	player.cooldowns[COLLAPSE_ID] = Abilities.cooldown_of(res)
	var at := player.cast_point
	var r := float(res.radius)
	var coef := float(res.damage)
	_arcane_mark("collapse", at, r, Balance.COLLAPSE_DELAY)
	player.echo_timer(Balance.COLLAPSE_DELAY).timeout.connect(func(): _collapse_implode(at, r, coef))

func _collapse_implode(at: Vector3, r: float, coef: float) -> void:
	if player.is_dead():
		return
	var col := Abilities.color_of(COLLAPSE_ID)
	player._ring_effect(r * 0.4, col, at + Vector3(0, 0.9, 0))
	player._ring_effect(r * 0.15, Color(0.95, 0.9, 1.0), at + Vector3(0, 0.9, 0))
	var hit := player._enemies_near(at, r)
	var share := coef * Balance.aoe_share(hit.size())
	var net := player._net()
	for e in hit:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		player.deal_damage(e, share, COLLAPSE_ID)
		if not is_instance_valid(e) or not e.is_alive() or str(e.get("rank")) == "boss":
			continue   # (bosses are too heavy to pull)
		var from: Vector3 = e.global_position
		var to := collapse_point(from, at, Balance.COLLAPSE_PULL, Balance.COLLAPSE_CORE)
		if to.is_equal_approx(from) \
				or not Combat.line_of_sight(player.get_world_3d(), from + Vector3(0, 0.3, 0), to + Vector3(0, 0.3, 0)):
			continue
		if net:
			net.drag(e, to, Balance.COLLAPSE_DRAG_TIME)   # the host owns enemies in a party
		elif e.has_method("drag_to"):
			e.drag_to(to, Balance.COLLAPSE_DRAG_TIME)
		_aftershock(e)   # Aftershock: the ones it pulled are slowed

# Interval Ward: a shield on me. While it holds, my Arcane cooldowns recover
# faster (_arcane_rate). Broken early by damage, the time it had left comes off
# its own cooldown.

## Interval Ward's cooldown after the shield broke with `left` seconds to go.
static func ward_cooldown_after_break(cooldown: float, left: float) -> float:
	return maxf(cooldown - maxf(left, 0.0), 0.0)

func _interval_ward() -> void:
	var amount := int(round(player._combat().heal_amount(player, float(Abilities.HEALS[WARD_ID]), WARD_ID) * player.absorb_mult()))
	if amount <= 0:
		return
	var col := Abilities.color_of(WARD_ID)
	var fx := StatusContainer.make_buff(WARD_FX, Abilities.ability_name(WARD_ID), WARD_FX, 0.0,
		Balance.INTERVAL_WARD_TIME, 1, col)
	var armor := player._talent("frost_shield_armor")   # Hardened Frost: my shields add armor
	fx.stat_modifiers = {"armor%": armor} if armor > 0.0 else {}
	fx.tags = PackedStringArray(["Arcane"])
	fx.description = "A shield absorbs damage. While it holds, your Arcane spells recover their cooldowns faster."
	if player.status.apply(fx, player):
		player.status.set_absorb(WARD_FX, amount)
		_ward_until = Time.get_ticks_msec() / 1000.0 + Balance.INTERVAL_WARD_TIME
	player._ring_effect(1.3, col)

## My Interval Ward was used up by damage: what it had left comes off its cooldown.
func _ward_broke() -> void:
	var left := _ward_until - Time.get_ticks_msec() / 1000.0
	_ward_until = 0.0
	if left <= 0.0 or not player.cooldowns.has(WARD_ID):
		return
	var cd := ward_cooldown_after_break(float(player.cooldowns[WARD_ID]), left)
	if cd <= 0.0:
		player.cooldowns.erase(WARD_ID)
	else:
		player.cooldowns[WARD_ID] = cd

# Rune of the Afterimage: Phase Step and Flicker leave an image where I stood
# for AFTERIMAGE_TIME seconds. The first spell I deal damage with in that time is
# cast by the image too: every hit of that spell is echoed at AFTERIMAGE_PCT %.

## Seconds the image keeps casting once a spell has woken it: a channel for
## what is left of it, Ice Shards while shards are still to fire, anything else
## for a moment (so every enemy an area spell hits is echoed).
static func afterimage_window(channel_left: float, shards_left: int) -> float:
	if channel_left > 0.0:
		return channel_left + Balance.AFTERIMAGE_TRAVEL
	if shards_left > 0:
		return shards_left * Balance.ICE_SHARDS_INTERVAL + Balance.AFTERIMAGE_TRAVEL
	return Balance.AFTERIMAGE_BURST

func _leave_afterimage(from: Vector3) -> void:
	if player.status == null or not player.frost_melee._has_rune(AFTERIMAGE_RUNE):
		return
	_image_at = Vector3(from.x, from.y - (player.global_position.y - Combat.feet_y(player)), from.z)
	_image_spell = ""
	_image_until = 0.0
	var fx := StatusContainer.make_buff(AFTERIMAGE_FX, "Afterimage", AFTERIMAGE_FX, 0.0,
		Balance.AFTERIMAGE_TIME, 1, Color(0.75, 0.5, 1.0))
	fx.stat_modifiers = {}
	fx.description = "The next spell you deal damage with is also cast by your image."
	player.status.apply(fx, player)
	_arcane_mark("image", _image_at, 0.6, Balance.AFTERIMAGE_TIME)

## Every hit I deal: Countdown counts it, Mirror Sigil and the Afterimage repeat it.
func _on_damage_dealt_arcane(info: RefCounted) -> void:
	if not is_same(info.source, player) or info.avoided() or not is_instance_valid(info.target):
		return
	var amount := int(info.amount)
	if amount <= 0:
		return
	var id := str(info.ability_id)
	_countdown_tally(info.target, id, str(info.damage_type), amount)
	player.arcane_melee._trace_hit(info, id, amount)   # Arcane melee: a strike leaves a Trace
	player.arcane_open._echo_talent(info, id, amount)   # Echo: any spell or ability may be repeated
	player.fire_lightning_talents._spillover_talent(info, id, amount)   # Spillover: part of a critical strike jumps on
	if bool(info.is_dot) or player.status == null or not (info.target is Node3D):
		return
	if player.status.has(MIRROR_FX) and mirror_echoes(info.tags, bool(info.is_proc), id,
			id == ArcaneTankKit.REFLECTION_SHATTER_ID and player.frost_melee._has_rune(TWO_WAY_MIRROR_RUNE)):
		_echo_hit(info, mirror_pct(player._talent("arcane_polished_glass"), _sigil_carried), MIRROR_ID, _sigil_origin())
	if bool(info.is_proc) or not info.tags.has("Spell") or not Abilities.PATHS.has(id):
		return
	if bool(info.crit):
		_arcane_crit_talents(id)   # Etched Darts, Frayed
	var now := Time.get_ticks_msec() / 1000.0
	if player.status.has(AFTERIMAGE_FX):
		# This is the spell the image casts along with me.
		player.status.remove(AFTERIMAGE_FX)
		_image_spell = id
		var channel_left := player.cast_timer if player.casting and player.cast_is_channel and player.current_spell == id else 0.0
		var window := afterimage_window(channel_left, player.ice_shards_kit._shards_left if id == "iceshards" else 0)
		_image_until = now + window
		_arcane_mark("image", _image_at, 0.6, window + 0.3)   # it stays for as long as it is casting
	if id == _image_spell and now <= _image_until:
		_echo_hit(info, Balance.AFTERIMAGE_PCT, AFTERIMAGE_RUNE, _image_at + Vector3(0, 1.0, 0))

# Glint: an instant bolt. For GLINT_TIME seconds afterwards my next Unravel or
# Sigil Darts (with the Rune of Momentum: any spell with a cast time) can be cast
# or channelled while moving. A cast uses the buff up when it finishes, a
# channel when it starts.

## Can Glint let this be cast on the move? `any_spell` = the Rune of Momentum.
static func glint_applies(id: String, tags: PackedStringArray, cast_time: float, any_spell: bool) -> bool:
	if cast_time <= 0.0:
		return false
	return id == UNRAVEL_ID or id == SIGIL_DARTS_ID or (any_spell and tags.has("Spell"))

## Would casting `id` right now be a cast on the move from Glint?
func glint_ready(id: String) -> bool:
	if player.status == null or not player.status.has(GLINT_FX):
		return false
	var res := Abilities.get_resource(id)
	return res != null and glint_applies(id, res.tags, float(res.cast_time), player.frost_melee._has_rune(MOMENTUM_RUNE))

func _glint(res: Resource) -> void:
	Player.FROST_BOLT.spawn(player.get_tree().current_scene, player._muzzle(), player.target, player, false, GLINT_ID, float(res.damage))
	var text := "Your next spell with a cast time can be cast while moving."
	if not player.frost_melee._has_rune(MOMENTUM_RUNE):
		text = "Your next %s or %s can be cast while moving." % [Abilities.ability_name(UNRAVEL_ID),
			Abilities.ability_name(SIGIL_DARTS_ID)]
	# Keep Moving: the window lasts longer; its capstone: it covers more than one cast.
	var casts := Balance.KEEP_MOVING_CASTS if player.frost_melee._capstone("arcane_keep_moving") else 1
	var fx := StatusContainer.make_buff(GLINT_FX, Abilities.ability_name(GLINT_ID), GLINT_FX, 0.0,
		ArcaneOpenTalentsKit.glint_time(player._talent("arcane_keep_moving")), casts, Abilities.color_of(GLINT_ID))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Arcane"])
	fx.description = text
	player.status.remove(GLINT_FX)   # (a fresh one: every cast it covers is there again)
	player.status.apply(fx, player)
	if casts > 1:
		player.status.set_stacks(GLINT_FX, casts)

# --- Arcane talents ----------------------------------------------------------------------

## Take `seconds` off the cooldown of `id` (nothing happens if it is ready).
func _cut_cooldown(id: String, seconds: float) -> void:
	if not player.cooldowns.has(id):
		return
	if seconds > 0.0 and _is_arcane_spell(id):
		player.arcane_talents.time_taken_off()   # Unwinding
	var left := float(player.cooldowns[id]) - seconds
	if left <= 0.0:
		player.cooldowns.erase(id)
	else:
		player.cooldowns[id] = left

## One of my spells' own hits critically struck. Etched Darts: a dart may take
## time off Countdown and Collapse. Frayed: Unravel may take its time off again.
func _arcane_crit_talents(id: String) -> void:
	if _is_arcane_spell(id):
		# Etched Darts: any Arcane spell's crit may take time off the others.
		var etched := player._talent("arcane_etched_darts")
		if etched > 0.0 and randf() * 100.0 < etched:
			for cd in player.cooldowns.keys():
				if str(cd) != id and _is_arcane_spell(str(cd)):
					_cut_cooldown(str(cd), Balance.ETCHED_DARTS_SECONDS)
	if id == UNRAVEL_ID:
		var frayed := player._talent("arcane_frayed")
		if frayed > 0.0 and randf() * 100.0 < frayed:
			_unravel_cooldowns()

## Chain Reaction: damage each of `count` enemies around a Countdown takes when
## it counted `bonus` extra damage, at `pct` % of it (more than AOE_TARGET_CAP
## enemies share that many hits).
static func chain_reaction_damage(bonus: int, pct: float, count: int) -> int:
	if count <= 0:
		return 0
	return int(round(maxf(float(bonus), 0.0) * maxf(pct, 0.0) / 100.0 * Balance.aoe_share(count)))

## Chain Reaction: my Countdown went off at `at` on `main`. A share of what it
## counted hits the enemies around it, as its own line on the damage meter.
func _chain_reaction(at: Vector3, main: Variant, bonus: int) -> void:
	var pct := player._talent("arcane_chain_reaction")
	if pct <= 0.0 or bonus <= 0:
		return
	var skip: Node = main if (main != null and is_instance_valid(main)) else null
	var near := player._enemies_near(at, Balance.CHAIN_REACTION_RADIUS, skip)
	var each := chain_reaction_damage(bonus, pct, near.size())
	for e in near:
		_exact_hit(e, each, CHAIN_REACTION_ID, "arcane", PackedStringArray(ARCANE_TAGS))
		if is_instance_valid(e):
			player._ring_effect(0.6, Abilities.color_of(COUNTDOWN_ID), e.global_position)

## % of a hit my Mirror Sigil repeats: Polished Glass adds `talent_bonus`; the
## Rune of the Carried Sigil (`carried`) starts it lower.
static func mirror_pct(talent_bonus: float, carried: bool) -> float:
	return (Balance.CARRIED_SIGIL_PCT if carried else Balance.MIRROR_SIGIL_PCT) + maxf(talent_bonus, 0.0)

## Where my Mirror Sigil's echoes fly from: the shard over the sigil, or over
## my head when I carry it.
func _sigil_origin() -> Vector3:
	if _sigil_carried:
		return Vector3(player.global_position.x, Combat.feet_y(player) + ARCANE_MARK.CARRIED_HEIGHT, player.global_position.z)
	return _sigil_at + Vector3(0, ARCANE_MARK.SHARD_HEIGHT, 0)

## Aftershock: how many times the effect's own slow a talent value of `slow_pct` % is.
static func aftershock_mult(slow_pct: float) -> float:
	return maxf(slow_pct, 0.0) / Balance.AFTERSHOCK_SLOW_STEP

## Aftershock: an enemy my Collapse pulled is slowed (as strongly as the rank says).
func _aftershock(e: Node) -> void:
	var slow := player._talent("arcane_aftershock")
	if slow <= 0.0:
		return
	_slow_mult_now = aftershock_mult(slow)   # (slow_mult() answers with this while the effect is applied)
	player.fire_caster._apply_effect_hit(e, preload("res://scripts/core/effects.gd").get_effect(AFTERSHOCK_FX), COLLAPSE_ID,
		PackedStringArray(ARCANE_TAGS), "arcane")
	_slow_mult_now = 1.0

## Dead or downed: marks fizzle, the sigil and the image go.
func _clear_arcane() -> void:
	_countdowns.clear()
	_darts_left = 0
	_image_spell = ""
	_image_until = 0.0
	_arcane_mark("sigil", _sigil_at, 0.0, 0.0)
	_arcane_mark("image", _image_at, 0.0, 0.0)
	player.arcane_melee._clear_traces()
	player.decay._clear_decay()   # Shadow: my Decays go with me, and their debuffs

