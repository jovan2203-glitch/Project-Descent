extends "res://scripts/player/player_kit.gd"
class_name ArcaneTankKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "arcane_tank".
# --- Arcane tank (a dodge tank with a melee weapon in each hand) --------------------------
# No resource: cooldowns alone. It lives on Reflections, images of me that stand
# around me (a stacking buff; the picture is scripts/reflections.gd). Each one
# adds Dodge and raises my Dodge cap. An attack I dodge uses one up, and that
# Reflection shatters: damage around me, time off the cooldown of everything in
# the Arcane book, and a window for Missed Beat. Double Up, Ripple and Full Set
# make Reflections. Stand-In lets them take the attacks that get through, Trade
# Places turns them into health, Crowd of One stops dodges using them up, and
# Decoy sends one off for the enemies to attack. Numbers are in balance.gd.

const REFLECTIONS = preload("res://scripts/reflections.gd")
const DECOY = preload("res://scripts/decoy.gd")
const TRACE_GHOST = preload("res://scripts/trace_ghost.gd")
const REFLECTION_FX := "reflection"
## Meter / log id of a Reflection shattering (its own line: Details.HIT_NAMES).
const REFLECTION_SHATTER_ID := "reflection_shatter"
const REFLECTION_TAGS := ["Arcane", "Ability", "AoE"]
const DOUBLE_UP_ID := "doubleup"
const RIPPLE_ID := "ripple"
const FULL_SET_ID := "fullset"
const MISSED_BEAT_ID := "missedbeat"
const MISSED_BEAT_FX := "missed_beat"
const STAND_IN_ID := "standin"
const STAND_IN_FX := "stand_in"
const TRADE_PLACES_ID := "tradeplaces"
const CROWD_ID := "crowdofone"
const CROWD_FX := "crowd_of_one"
const DECOY_ID := "decoy"
const DUAL_WIELD_ERROR := "Requires a melee weapon in each hand"
## Seconds between telling the party again how many Reflections I have (someone
## who joined or reloaded since then sees them too).
const REFLECTION_RETELL := 3.0

var _reflection_fx: Resource
var _reflections_shown := 0      # how many the picture around me shows (and the party was told)
var _reflections_told := 0.0     # when the party was last told
var _hits_taken: Array = []      # [time, damage] of what I took lately (Trade Places)

## Dual wield: is a one-handed melee weapon in my Main Hand and another in my Off Hand?
func has_dual_wield() -> bool:
	var pd := player.get_node_or_null("/root/PlayerData")
	return pd != null and bool(pd.has_dual_wield())

## Damage coefficient of a strike with both weapons (Double Up, Missed Beat): the
## two weapons' damage together x the ability's multiplier + the ability's own.
## One hit, so what triggers on a hit triggers once.
static func dual_hit(main: float, off: float, mult: float, flat: float) -> float:
	return (maxf(main, 0.0) + maxf(off, 0.0)) * mult + flat

func _dual_weapon_hit(w: Dictionary, res: Resource) -> float:
	return dual_hit(float(w.get("damage", 0.0)), float(Abilities.offhand_weapon().get("damage", 0.0)),
		float(res.weapon_damage_multiplier), float(res.damage))

## How many Reflections I have.
func reflections() -> int:
	return player.status.stacks_of(REFLECTION_FX) if player.status != null else 0

## Reflections after gaining `more` on top of `have` (never more than REFLECTION_MAX).
static func reflections_after(have: int, more: int) -> int:
	return clampi(have + maxi(more, 0), 0, Balance.REFLECTION_MAX)

## The most Dodge chance (%) that counts with `stacks` Reflections.
static func dodge_cap_for(stacks: int) -> float:
	return Stats.MAX_DODGE + Balance.REFLECTION_DODGE_CAP * clampi(stacks, 0, Balance.REFLECTION_MAX)

## My Dodge cap right now (CombatSystem and the stat panel ask).
func dodge_cap() -> float:
	return dodge_cap_for(reflections())

## Does a Reflection shattering take time off the cooldown of an ability in the
## book `category`? Everything in the Arcane book, spells and abilities alike;
## never an interrupt (they share a cooldown of their own).
static func shatter_cuts(category: String, is_interrupt: bool) -> bool:
	return category == "arcane" and not is_interrupt

## Does a Ripple that hit `enemies` enemies make a Reflection? (`wide` = Wide
## Rings' capstone: fewer enemies are enough.)
static func ripple_makes_reflection(enemies: int, wide: bool = false) -> bool:
	return enemies >= (Balance.WIDE_RINGS_ENEMIES if wide else Balance.RIPPLE_REFLECTION_ENEMIES)

# The Arcane tank's talents. Down the left edge of the book, what makes and
# shatters Reflections: Sharp Edges (shatters hit harder; capstone: further),
# Clockwork (a shatter takes more off cooldowns), Spare Copy (a dodge may not
# use the Reflection up), Second Self (Double Up may make two), Wide Rings
# (Ripple reaches further; capstone: fewer enemies make a Reflection), On the
# Beat (Missed Beat hits harder; capstone: it makes a Reflection when I have
# none), Head Count (Full Set heals for each Reflection it makes). Down the right
# edge, staying alive: Light Feet (Dodge with two weapons: PlayerData), Empty
# Room (less damage taken with no Reflections), Bent Light (less non-Physical
# damage for each Reflection), Understudy (Stand-In comes back sooner), Loud Exit
# (Trade Places shatters what it gives up), Good Likeness (Decoy holds longer;
# capstone: it needs no Reflection).

const SHARP_EDGES_LABEL := "Sharp Edges"
const ON_THE_BEAT_LABEL := "On the Beat"
## Meter / log id of Head Count's healing (its own line: Details.HIT_NAMES).
const HEAD_COUNT_ID := "head_count"
## ... and of Silvered's.
const SILVERED_ID := "silvered"

## Health Silvered restores when a Reflection shatters (`pct` % of maximum health).
static func silvered_heal(max_hp: int, pct: float) -> int:
	return int(round(maxf(float(max_hp), 0.0) * maxf(pct, 0.0) / 100.0))

## Metres a shatter reaches (Sharp Edges' capstone: further).
static func shatter_radius_for(sharp_capstone: bool) -> float:
	return Balance.SHARP_EDGES_RADIUS if sharp_capstone else Balance.REFLECTION_SHATTER_RADIUS

## Seconds one shatter takes off each Arcane cooldown (`clockwork` = that talent's seconds).
static func shatter_cut(clockwork: float) -> float:
	return Balance.REFLECTION_SHATTER_COOLDOWN + maxf(clockwork, 0.0)

## Is the Reflection that took a dodged attack used up? Not during Crowd of One,
## and not when Spare Copy's chance comes up (`spare_pct` %, `roll` 0-100).
static func dodge_uses_reflection(crowd: bool, spare_pct: float, roll: float) -> bool:
	return not crowd and not (spare_pct > 0.0 and roll < spare_pct)

## Reflections one Double Up makes (Second Self: a `pct` % chance of more; `roll` 0-100).
static func double_up_reflections(pct: float, roll: float) -> int:
	return Balance.SECOND_SELF_REFLECTIONS if pct > 0.0 and roll < pct else 1

## Health Head Count restores when Full Set makes `made` Reflections (`pct` % of
## maximum health for each).
static func head_count_heal(max_hp: int, pct: float, made: int) -> int:
	return int(round(maxf(float(max_hp), 0.0) * maxf(pct, 0.0) / 100.0 * maxi(made, 0)))

## % less damage Empty Room spares me (`pct` = the talent): only with a weapon in
## each hand and no Reflections left.
static func empty_room_pct(pct: float, stacks: int, dual: bool) -> float:
	return pct if pct > 0.0 and stacks <= 0 and dual else 0.0

## % less damage Bent Light spares me from a hit of `damage_type`: `per` % for
## each Reflection, never from Physical damage.
static func bent_light_pct(per: float, stacks: int, damage_type: String) -> float:
	if per <= 0.0 or damage_type == "physical":
		return 0.0
	return per * clampi(stacks, 0, Balance.REFLECTION_MAX)

## Seconds a Decoy holds the enemies around it (`longer` = Good Likeness).
static func decoy_time(longer: float) -> float:
	return Balance.DECOY_TIME + maxf(longer, 0.0)

func shatter_radius() -> float:
	return shatter_radius_for(player.frost_melee._capstone("arcane_sharp_edges"))

## Does Decoy need (and use up) one of my Reflections? Not with Good Likeness' capstone.
func decoy_needs_reflection() -> bool:
	return not player.frost_melee._capstone("arcane_good_likeness")

## What I take (_on_damage_modify): Empty Room and Bent Light.
func _reflection_talents_incoming(info: RefCounted) -> void:
	var empty := player._talent("arcane_empty_room")
	if empty > 0.0:
		var spared := empty_room_pct(empty, reflections(), has_dual_wield())
		if spared > 0.0:
			info.add_bonus(-spared, "Empty Room")
	var bent := bent_light_pct(player._talent("arcane_bent_light"), reflections(), str(info.damage_type))
	if bent > 0.0:
		info.add_bonus(-bent, "Bent Light")

## Damage taken in the `window` seconds before `now`, from rows of [time, damage].
static func damage_in_window(rows: Array, now: float, window: float) -> int:
	var total := 0
	for r in rows:
		if r is Array and r.size() >= 2 and now - float(r[0]) <= window:
			total += int(r[1])
	return total

## Health Trade Places restores for `taken` damage with `stacks` Reflections given up.
static func trade_places_heal(taken: int, stacks: int) -> int:
	return int(round(maxf(float(taken), 0.0) * Balance.TRADE_PLACES_PCT / 100.0 * maxi(stacks, 0)))

## Why Trade Places can't be used ("" = it can).
static func trade_places_error(stacks: int, taken: int, full_health: bool) -> String:
	if stacks <= 0:
		return "You have no Reflections"
	if full_health:
		return "Already at full health"
	if taken <= 0:
		return "You have taken no damage to trade"
	return ""

func _reflection_buff() -> Resource:
	if _reflection_fx == null:
		_reflection_fx = StatusContainer.make_buff(REFLECTION_FX, "Reflection", Stats.DODGE, Balance.REFLECTION_DODGE,
			Balance.REFLECTION_TIME, Balance.REFLECTION_MAX, Abilities.color_of(DOUBLE_UP_ID))
		_reflection_fx.tags = PackedStringArray(["Arcane"])
		_reflection_fx.description = "An image of you. Each one adds {b:REFLECTION_DODGE}% Dodge and raises your Dodge cap by {b:REFLECTION_DODGE_CAP}%. An attack you dodge shatters one."
	return _reflection_fx

## Gain `more` Reflections (never more than REFLECTION_MAX). All of them last
## their full time again.
func _gain_reflections(more: int = 1) -> void:
	if player.status == null or more <= 0 or player.is_dead():
		return
	var want := reflections_after(reflections(), more)
	if not player.status.apply(_reflection_buff(), player):
		return
	if player.status.stacks_of(REFLECTION_FX) != want:
		player.status.set_stacks(REFLECTION_FX, want)

## Remember what I just took (Trade Places looks back TRADE_PLACES_WINDOW seconds).
func _note_damage_taken(amount: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_hits_taken.append([now, amount])
	while not _hits_taken.is_empty() and now - float(_hits_taken[0][0]) > Balance.TRADE_PLACES_WINDOW:
		_hits_taken.pop_front()

## Damage I took in the last `window` seconds.
func damage_taken_recently(window: float) -> int:
	return damage_in_window(_hits_taken, Time.get_ticks_msec() / 1000.0, window)

## One of my Reflections shatters: damage around me (a proc with its own line on
## the meter; it feeds nothing), time off my Arcane cooldowns, and Missed Beat
## may answer. `used_up` = false during Crowd of One: the Reflection stays.
func _shatter_reflection(used_up: bool = true) -> void:
	if reflections() <= 0:
		return
	if used_up:
		player.status.spend_stacks(REFLECTION_FX, 1)
	_shatter_burst()

## What a shattering Reflection does (also each one Trade Places gives up with
## Loud Exit): the damage around me, the time off my cooldowns, Missed Beat's window.
func _shatter_burst() -> void:
	var reach := shatter_radius()   # Sharp Edges' capstone: further
	var hit := player._enemies_within(reach)
	var coef := Balance.REFLECTION_SHATTER * Balance.aoe_share(hit.size())
	for e in hit:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var burst := DamageInfo.make(player, e, coef, REFLECTION_SHATTER_ID)
		burst.tags = PackedStringArray(REFLECTION_TAGS)
		burst.damage_type = "arcane"
		burst.threat_multiplier = Balance.REFLECTION_SHATTER_THREAT
		burst.is_proc = true
		burst.no_empower = true
		player._combat().deal(burst)
	player._ring_effect(reach, Abilities.color_of(DOUBLE_UP_ID))
	player._ring_effect(reach * 0.5, Color(0.95, 0.9, 1.0))
	_shatter_cooldowns()
	# Silvered: every shatter heals me a little.
	var silver := silvered_heal(player.max_health, player._talent("arcane_silvered"))
	if silver > 0 and player.health < player.max_health:
		player._combat().heal(player, player, float(silver), SILVERED_ID, true)
	var pd := player.get_node_or_null("/root/PlayerData")
	if pd and pd.has_ability(MISSED_BEAT_ID):
		player.arcane_caster._arcane_buff(MISSED_BEAT_FX, MISSED_BEAT_ID, Balance.MISSED_BEAT_WINDOW,
			"One of your Reflections shattered: %s can be used." % Abilities.ability_name(MISSED_BEAT_ID))

## A Reflection shattered: everything in the Arcane book that is on cooldown
## comes back a little sooner (spells and abilities alike; never an interrupt).
func _shatter_cooldowns() -> void:
	var cut := shatter_cut(player._talent("arcane_clockwork"))   # + Clockwork
	for id in player.cooldowns.keys():
		if shatter_cuts(Abilities.category_of(str(id)), Player.INTERRUPT_LOCKOUT.has(str(id))):
			player.arcane_caster._cut_cooldown(str(id), cut)

## Something hit me (_on_hit_taken): an attack I dodged shatters a Reflection,
## and so does one a Reflection stood in for (Stand-In).
func _reflection_kit_hit_taken(info: RefCounted) -> void:
	if reflections() <= 0:
		return
	if bool(info.stood_in):
		_shatter_reflection(true)
		var understudy := player._talent("arcane_understudy")   # Understudy: Stand-In comes back sooner
		if understudy > 0.0:
			player.arcane_caster._cut_cooldown(STAND_IN_ID, understudy)
	elif bool(info.dodged):
		# Crowd of One: it is not used up. Spare Copy: it may not be.
		_shatter_reflection(dodge_uses_reflection(player.status.has(CROWD_FX), player._talent("arcane_spare_copy"), randf() * 100.0))

## CombatSystem asks, for a direct hit that got through to me: does something
## else take it? During Stand-In a Reflection does (and shatters: see above).
func stand_in_for(_info: RefCounted) -> bool:
	return player.status != null and player.status.has(STAND_IN_FX) and reflections() > 0

## Ripple: everything around me is hit; more than AOE_TARGET_CAP enemies share
## that many hits' damage. Hitting enough of them makes a Reflection.
func _ripple(res: Resource) -> void:
	var col := Abilities.color_of(RIPPLE_ID)
	var reach := float(res.radius) + Abilities.radius_bonus(RIPPLE_ID)   # + Wide Rings
	var hit := player._enemies_within(reach)
	var coef := float(res.damage) * Balance.aoe_share(hit.size())
	for e in hit:
		if is_instance_valid(e) and e.is_alive():
			player.deal_damage(e, coef, RIPPLE_ID)
	if ripple_makes_reflection(hit.size(), player.frost_melee._capstone("arcane_wide_rings")):
		_gain_reflections(1)
	player._ring_effect(reach, col)
	player._ring_effect(reach * 0.7, Color(0.95, 0.9, 1.0))
	player._ring_effect(reach * 0.4, col)

## Full Set: Reflections until I have them all. Head Count heals me for each one
## it makes.
func _full_set() -> void:
	var made := Balance.REFLECTION_MAX - reflections()
	_gain_reflections(Balance.REFLECTION_MAX)
	var mend := head_count_heal(player.max_health, player._talent("arcane_head_count"), made)
	if mend > 0 and player.health < player.max_health:
		player._combat().heal(player, player, float(mend), HEAD_COUNT_ID, true)
	player._ring_effect(1.4, Abilities.color_of(FULL_SET_ID))
	player._ring_effect(0.9, Color(0.95, 0.9, 1.0))

func _start_stand_in() -> void:
	player.arcane_caster._arcane_buff(STAND_IN_FX, STAND_IN_ID, Balance.STAND_IN_TIME,
		"Each attack that gets through to you destroys one of your Reflections instead of hitting you.")
	player._ring_effect(1.2, Abilities.color_of(STAND_IN_ID))
	player._ring_effect(0.8, Color(0.95, 0.9, 1.0))

func _start_crowd_of_one() -> void:
	player.arcane_caster._arcane_buff(CROWD_FX, CROWD_ID, Balance.CROWD_OF_ONE_TIME,
		"A Reflection that takes an attack you dodge shatters, but is not used up.")
	var crowd := int(round(player._talent("arcane_full_crowd")))   # Full Crowd: it brings some with it
	if crowd > 0:
		_gain_reflections(crowd)
	player._ring_effect(1.6, Abilities.color_of(CROWD_ID))
	player._ring_effect(1.0, Color(0.95, 0.9, 1.0))

## Trade Places: every Reflection I have is given up (they do not shatter,
## unless I have Loud Exit), and each one heals me for a share of what I took in
## the last moments.
func _trade_places() -> void:
	var stacks := reflections()
	var amount := trade_places_heal(damage_taken_recently(Balance.TRADE_PLACES_WINDOW), stacks)
	# Loud Exit: each one I give up shatters on its way out.
	if player._talent("arcane_loud_exit") > 0.0:
		for i in stacks:
			_shatter_burst()
	player.status.remove(REFLECTION_FX)
	if amount > 0:
		player._combat().heal(player, player, float(amount), TRADE_PLACES_ID, true)
	player._ring_effect(1.2, Color(0.45, 1.0, 0.5))
	player._ring_effect(0.8, Abilities.color_of(TRADE_PLACES_ID))

## My buffs changed: the picture around me shows as many Reflections as I have,
## and the party is told when that number changes.
func _sync_reflections() -> void:
	var n := reflections()
	if n == _reflections_shown:
		return
	_reflections_shown = n
	REFLECTIONS.show_on(player, n)
	_tell_reflections()

func _tell_reflections() -> void:
	_reflections_told = Time.get_ticks_msec() / 1000.0
	player._net_fx("reflections", player.global_position, null, {"n": _reflections_shown})

func _tick_reflections() -> void:
	if _reflections_shown > 0 and Time.get_ticks_msec() / 1000.0 - _reflections_told >= REFLECTION_RETELL:
		_tell_reflections()

# Decoy: ground-targeted and instant. One of my Reflections goes to stand at the
# spot (scripts/decoy.gd): for DECOY_TIME seconds the enemies around it attack
# it. Enemies live on the host, so in a party the host makes the real one
# (Net.decoy). When its time is up it bursts: that damage is mine, dealt here.

## Why Decoy can't be used right now ("" = it can). `point` = where it would stand.
func _decoy_error(point: Variant = null) -> String:
	if player.cooldown_left(DECOY_ID) > 0.0:
		return "%s is not ready yet" % Abilities.ability_name(DECOY_ID)
	if not has_dual_wield():
		return DUAL_WIELD_ERROR
	if decoy_needs_reflection() and reflections() <= 0:
		return "You have no Reflections"
	if point is Vector3:
		var reach := float(Abilities.get_resource(DECOY_ID).cast_range)
		if reach > 0.0 and Vector2(point.x - player.global_position.x, point.z - player.global_position.z).length() > reach:
			return "Out of range"
	return ""

func _start_decoy(point: Vector3) -> void:
	if player.casting or not player.is_on_floor():
		return
	var err := _decoy_error(point)
	if err != "":
		player._error(err)
		return
	if not player._pay(DECOY_ID):
		return
	var res := Abilities.get_resource(DECOY_ID)
	player.cooldowns[DECOY_ID] = Abilities.cooldown_of(res)
	if decoy_needs_reflection():
		player.status.spend_stacks(REFLECTION_FX, 1)   # the Reflection that goes (Good Likeness' capstone: none does)
	var dir := point - player.global_position
	if Vector2(dir.x, dir.z).length() > 0.3:
		player.rotation.y = atan2(-dir.x, -dir.z)
	# It stands on the ground there, its centre as high over it as mine is.
	var at := Vector3(point.x, point.y + (player.global_position.y - Combat.feet_y(player)), point.z)
	var time := decoy_time(player._talent("arcane_good_likeness"))   # + Good Likeness
	var net := player._net()
	if net:
		net.decoy(player, at, player.rotation.y, float(res.radius), time)
	else:
		DECOY.spawn(player.get_tree().current_scene, player, at, player.rotation.y, time, float(res.radius))
	player._ring_effect(float(res.radius), Abilities.color_of(DECOY_ID), at)
	player.get_tree().create_timer(time).timeout.connect(func(): _decoy_burst(at))
	if Player.on_gcd(DECOY_ID):
		player._start_gcd()
	player._bus().cast_finished.emit(DECOY_ID)

## My Decoy's time is up: it bursts where it stood (a proc; more than
## AOE_TARGET_CAP enemies share that many hits' damage).
func _decoy_burst(at: Vector3) -> void:
	if player.is_dead():
		return
	var res := Abilities.get_resource(DECOY_ID)
	var hit := player._enemies_near(at, Balance.DECOY_BURST_RADIUS)
	var coef := float(res.damage) * Balance.aoe_share(hit.size())
	for e in hit:
		if is_instance_valid(e) and e.is_alive():
			player.deal_damage(e, coef, DECOY_ID, true)
	player._ring_effect(Balance.DECOY_BURST_RADIUS, Abilities.color_of(DECOY_ID), at)
	player._ring_effect(Balance.DECOY_BURST_RADIUS * 0.5, Color(0.95, 0.9, 1.0), at)

