extends "res://scripts/player/player_kit.gd"
class_name FrostHealerKit

# Hooked up from player.gd through its var "frost_healer".
# --- Frost healer: Cold Comfort ------------------------------------------------------------
# A shield healer built on Rime Shell: shells that pay off when they end. On an
# ally a Rime Shell of mine that BREAKS sends out Rime Shards (heals every ally
# near it for a share of the shield); one that RUNS OUT unbroken melts into
# Runoff (a heal over time for a share of what was left). Meltwater is the
# filler (stronger on an ally with my Thawing), Break the Ice breaks a shell on
# purpose for a burst heal, Rime Veil is a shield that keeps forming again, Frost
# Lattice links shells so a hit on one is taken from all of them, Rimefall shields the
# whole group (more for each of my shells out), Frost Tide lifts Thawing for a
# while, Stillwater saves an ally about to die. Spring Thaw is its rez (RezKit).
# Everything is decided on the healer's machine. A party member's machine is
# told through Net.support_ally (StringsKit.receive_support -> receive here):
# "frost_shield", "rime_break", "stillwater", "lattice" (their shell is linked)
# and "rime_drain" (their share of a hit on another linked shell); it answers
# "rime_broke" (my shell on them broke), "rime_runoff" (it ran out),
# "rime_broken" (Break the Ice took it off) and "lattice_bill" (a hit on their
# linked shell: the part the others pay). A friendly dummy is handled here.
# Frost Lattice, step by step: the hit shell soaks the whole hit at once but
# loses only 1/n of it (StatusContainer.set_share); the rest is billed here and
# taken evenly from the other linked shells.
# Own only: only my shells count and only my Thawing makes Meltwater stronger.
# Numbers: balance.gd (RIME_SHARDS_*, RUNOFF_*, RIME_VEIL_*, ...; Meltwater in HEALS).
# Talents: Deep Cracks, Slow Runoff, Shard Spray (Rime Shards / Runoff),
# Splinterheal (my shatters heal), Wide Lattice, Cold Spread (Break the Ice).

const RIME_SHELL_FX = preload("res://data/effects/rime_shell.tres")
const THAWING_FX = preload("res://data/effects/thawing.tres")
const StatusEffectScript = preload("res://scripts/data/status_effect_data.gd")

const MELTWATER_ID := "meltwater"
const RIME_VEIL_ID := "rimeveil"
const BREAK_ICE_ID := "breaktheice"
const LATTICE_ID := "frostlattice"
const RIMEFALL_ID := "rimefall"
const FROST_TIDE_ID := "frosttide"
const STILLWATER_ID := "stillwater"
## The instants of the kit (_use_drafted -> _frost_healer_use). Meltwater and Rimefall are cast: SUPPORT_CASTS.
const INSTANTS := [RIME_VEIL_ID, BREAK_ICE_ID, LATTICE_ID, FROST_TIDE_ID, STILLWATER_ID]
## Meter / log ids of the heals that are not an ability's own (Details.HIT_NAMES).
const RIME_SHARDS_ID := "rimeshards"
const RUNOFF_ID := "runoff"
const SPLINTERHEAL_ID := "splinterheal"
## Effects: shields (by id), Frost Tide on me, Stillwater on an ally.
const RIME_VEIL_FX := "rimeveil"
const RIMEFALL_FX := "rimefall"
const SHARD_SPRAY_FX := "shard_spray"
const FROST_TIDE_FX := "frost_tide"
const STILLWATER_FX := "stillwater"
const SHIELD_NAMES := {RIME_VEIL_FX: "Rime Veil", RIMEFALL_FX: "Rimefall", SHARD_SPRAY_FX: "Shard Spray"}
const ICE := Color(0.6, 0.9, 1.0)
const RIME_SHELL_KEY := "rime_shell"
const NO_SHELL := "That ally has none of your Rime Shells"
const NOT_LOW := "Only on an ally below %s%% health"
## A move this soon after being encased doesn't break Stillwater (the key was already down).
const STILLWATER_GRACE := 0.25

var _shells := {}      # ally instance id -> {"who", "amount", "at"}: my Rime Shells on allies (and me)
var _thawed := {}      # ally instance id -> when my last Rime Shell went on them (my Thawing)
var _veils := {}      # ally instance id -> {"who", "amount", "until", "next"}
var _lattice: Array = []
var _lattice_until := 0.0
var _runoffs: Array = []   # {"who", "per", "left", "next"}: Runoff heals still to come
var _stills: Array = []    # {"who", "until"}: friendly dummies I encased (I heal them when it melts)
# The other end: I am encased in someone's Stillwater.
var _still_from: Node = null
var _still_at := 0.0
var _still_until := 0.0

func _ready() -> void:
	var bus := get_node_or_null("/root/SignalBus")
	if bus:
		bus.damage_dealt.connect(_on_damage_dealt)

func _now() -> float:
	return player.strings._str_now()

# --- Rules (static: tests/test_frost_healer.gd) ---------------------------------------------

## Rime Shards: what each of `n` allies is healed when a shell of `amount` breaks (`bonus` % more: Deep Cracks).
static func shards_each(amount: int, n: int, bonus: float = 0.0) -> int:
	if n <= 0:
		return 0
	return int(round(maxi(amount, 0) * Balance.RIME_SHARDS_PCT / 100.0 * (1.0 + maxf(bonus, 0.0) / 100.0) * Balance.aoe_share(n)))

## Runoff: the whole heal from a shell that ran out with `left` in it (`bonus` % more: Slow Runoff).
static func runoff_total(left: int, bonus: float = 0.0) -> int:
	return int(round(maxi(left, 0) * Balance.RUNOFF_PCT / 100.0 * (1.0 + maxf(bonus, 0.0) / 100.0)))

## Meltwater's heal multiplier (on an ally with my Thawing or not).
static func meltwater_mult(thawing: bool) -> float:
	return 1.0 + Balance.MELTWATER_THAWING_PCT / 100.0 if thawing else 1.0

## Break the Ice: what each of `n` allies is healed from a shell with `left` in it.
static func break_heal_each(left: int, n: int) -> int:
	if n <= 0:
		return 0
	return int(round(maxi(left, 0) * Balance.BREAK_ICE_PCT / 100.0 * Balance.aoe_share(n)))

## Rimefall's shield (a share of a heal) with `shells` of my Rime Shells out.
static func rimefall_share(shells: int) -> float:
	return Balance.RIMEFALL_SHARE + Balance.RIMEFALL_PER_SHELL * clampi(shells, 0, Balance.RIMEFALL_MAX_SHELLS)

## Can Stillwater go on someone at `health` of `max_health`?
static func stillwater_ok(health: float, max_health: float) -> bool:
	return max_health > 0.0 and health > 0.0 and health * 100.0 < max_health * Balance.STILLWATER_HEALTH_PCT

## How many allies Frost Lattice links (Wide Lattice adds `extra`).
static func lattice_size(extra: float) -> int:
	return Balance.LATTICE_LINKS + int(round(maxf(extra, 0.0)))

# --- My shells ------------------------------------------------------------------------------

## A Rime Shell of mine of `amount` went on `who` (an ally, or me).
func note_shell(who: Node3D, amount: int) -> void:
	if who == null or not is_instance_valid(who) or amount <= 0:
		return
	_shells[who.get_instance_id()] = {"who": who, "amount": amount, "at": _now()}
	_thawed[who.get_instance_id()] = _now()

## Does `who` carry a Rime Shell of mine right now?
func has_my_shell(who: Variant) -> bool:   # untyped: may be a freed node
	if who == null or not is_instance_valid(who):
		return false
	var e: Variant = _shells.get((who as Node).get_instance_id())
	return e != null and _now() - float(e["at"]) < float(RIME_SHELL_FX.duration)

## Allies carrying a Rime Shell of mine.
func shells_out() -> Array:
	var out: Array = []
	for e in _shells.values():
		if has_my_shell(e["who"]) and (e["who"] as Node).is_alive():
			out.append(e["who"])
	return out

## Does `who` have my Thawing (a Rime Shell of mine went on them not long ago)?
func my_thawing_on(who: Variant) -> bool:
	if who == null or not is_instance_valid(who):
		return false
	var at: Variant = _thawed.get((who as Node).get_instance_id())
	return at != null and _now() - float(at) < float(THAWING_FX.duration)

## My Rime Shell on `who` broke (here, or their machine said so): Rime Shards.
func shell_broke(who: Node3D, amount: int) -> void:
	if who == null or not is_instance_valid(who) or player.is_dead():
		return
	_shells.erase(who.get_instance_id())
	_unlink(who)
	var near := player.prism_kit._allies_near(who.global_position, Balance.RIME_SHARDS_RADIUS)
	var each := shards_each(amount, near.size(), player._talent("frost_deep_cracks"))   # Deep Cracks
	var spray := int(round(each * player._talent("frost_shard_spray") / 100.0))   # Shard Spray: a share of the heal as a shield
	for a in near:
		player.strings._heal_exact(a, each, RIME_SHARDS_ID)
		if spray > 0:
			_frost_shield(a, SHARD_SPRAY_FX, spray, Balance.SHARD_SPRAY_TIME)
	player._ring_effect(Balance.RIME_SHARDS_RADIUS, ICE, who.global_position)

## My Rime Shell on `who` ran out with `left` still in it: Runoff heals them over time.
func shell_runoff(who: Node3D, left: int) -> void:
	if who == null or not is_instance_valid(who):
		return
	_shells.erase(who.get_instance_id())
	_unlink(who)
	var total := runoff_total(left, player._talent("frost_slow_runoff"))   # Slow Runoff
	var ticks := maxi(int(round(Balance.RUNOFF_TIME)), 1)
	if total <= 0:
		return
	_runoffs.append({"who": who, "per": maxi(int(round(float(total) / ticks)), 1), "left": ticks, "next": _now() + 1.0})
	if player.frost_melee._capstone("frost_slow_runoff"):
		player._gain("mana", player.mana_unit())   # Slow Runoff's capstone: a mana point back

# --- Frost Lattice: linked shells share every hit -----------------------------------------

## How much each of the `others` linked shells pays of a `billed` share of a hit.
static func lattice_each(billed: int, others: int) -> int:
	return int(ceil(float(maxi(billed, 0)) / others)) if others > 0 else 0

func _lattice_live() -> bool:
	return _lattice.size() > 1 and _now() < _lattice_until

## The linked allies whose shell of mine is still up.
func _linked() -> Array:
	return _lattice.filter(func(a): return is_instance_valid(a) and has_my_shell(a)) if _lattice_live() else []

## Tell every linked shell how many share its hits now (1 = the lattice is over).
func _share_out() -> void:
	var linked := _linked()
	var n := linked.size() if linked.size() > 1 else 1
	var left := maxf(_lattice_until - _now(), 0.0)
	for a in _lattice:
		if is_instance_valid(a):
			_set_share(a, n if linked.has(a) else 1, left)
	if n <= 1:
		_lattice.clear()

func _set_share(who: Node3D, n: int, time: float) -> void:
	if is_same(who, player) or who.is_in_group("friendly"):
		var st: Node = player.status if is_same(who, player) else who.get_node_or_null("Status")
		if st:
			st.set_share(RIME_SHELL_KEY, n, st._now() + time)
	elif player._net():
		player._net().support_ally(who, player, "lattice", {"n": n, "t": time})

## `who`'s shell left the lattice (it broke, ran out or was broken on purpose).
func _unlink(who: Node3D) -> void:
	if _lattice.has(who):
		_lattice.erase(who)
		_share_out()

## A hit on `who`'s linked shell: `billed` is the part the other linked shells pay.
func lattice_billed(who: Node3D, billed: int) -> void:
	if who == null or not is_instance_valid(who) or billed <= 0:
		return
	var others := _linked().filter(func(a): return a != who)
	var each := lattice_each(billed, others.size())
	for a in others:
		_drain_shell(a, each)

func _drain_shell(who: Node3D, amount: int) -> void:
	if is_same(who, player):
		player.status.drain_absorb(RIME_SHELL_KEY, amount, player)
	elif who.is_in_group("friendly"):
		var st: Node = who.get_node_or_null("Status")
		if st:
			st.drain_absorb(RIME_SHELL_KEY, amount, player)
	elif player._net():
		player._net().support_ally(who, player, "rime_drain", {"amount": amount})

# --- Shields --------------------------------------------------------------------------------

## A shield worth `share` of a heal, at my power (Rime Ward makes it bigger, like every shield).
func _shield_amount(share: float, id: String) -> int:
	return int(round(player._combat().heal_amount(player, Balance.REFERENCE_HEAL * share, id) * player.absorb_mult()))

## A shield of mine (`fx_id`: Rime Veil, Rimefall, Shard Spray) of `amount` on `who` for `time` sec.
func _frost_shield(who: Node3D, fx_id: String, amount: int, time: float) -> void:
	if who == null or not is_instance_valid(who) or amount <= 0 or time <= 0.0:
		return
	if is_same(who, player):
		frost_shield_on(player.status, player, fx_id, amount, time)
	elif who.is_in_group("friendly"):
		frost_shield_on(who.get_node_or_null("Status"), player, fx_id, amount, time)
	elif player._net():
		player._net().support_ally(who, player, "frost_shield", {"id": fx_id, "amount": amount, "time": time})

## The shield on whoever owns Status `st`: never smaller than what is there (it refills, never stacks).
static func frost_shield_on(st: Node, from: Node, fx_id: String, amount: int, time: float) -> void:
	if st == null or amount <= 0 or not SHIELD_NAMES.has(fx_id):
		return
	var total := maxi(int(st.absorb_left(fx_id)), amount)
	if not st.apply(make_shield_fx(fx_id, time), from):
		return
	st.set_remaining(fx_id, time)
	st.set_absorb(fx_id, total)

static func make_shield_fx(fx_id: String, time: float) -> Resource:
	var r := StatusEffectScript.new()
	r.id = StringName(fx_id)
	r.display_name = str(SHIELD_NAMES.get(fx_id, fx_id))
	r.description = "Ice absorbs damage."
	r.color = ICE
	r.tags = PackedStringArray(["Frost", "Defensive"])
	r.duration = time
	r.stack_mode = 0
	return r

static func make_frost_tide_fx() -> Resource:
	var fx := StatusContainer.make_buff(FROST_TIDE_FX, "Frost Tide", FROST_TIDE_FX, 0.0, Balance.FROST_TIDE_TIME, 1, ICE)
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Frost"])
	fx.description = "Your Rime Shell ignores Thawing and is instant on enemies too."
	return fx

static func make_stillwater_fx(time: float) -> Resource:
	var r := StatusEffectScript.new()
	r.id = StringName(STILLWATER_FX)
	r.display_name = "Stillwater"
	r.description = "Encased in still ice: no damage taken, but you can't act. Move to break out. Healed when it melts."
	r.color = ICE
	r.tags = PackedStringArray(["Frost", "Defensive"])
	r.duration = time
	r.stack_mode = 0
	r.stun = true
	r.modifies_incoming = true
	r.damage_mod_pct = -100.0
	return r

## Frost Tide is on me: Rime Shell ignores Thawing and is instant on enemies too.
func frost_tide_on() -> bool:
	return player.status != null and player.status.has_from(FROST_TIDE_FX, player)

# --- Using the kit -------------------------------------------------------------------------

## Why an instant of the kit can't be used right now ("" = it can).
func _frost_healer_precheck(id: String) -> String:
	if id == FROST_TIDE_ID:
		return ""
	var pick := player._pick_support_target(id)
	if pick[0] == null:
		return str(pick[1]) if str(pick[1]) != "" else "No target"
	var who: Node3D = pick[0]
	if (id == BREAK_ICE_ID or id == LATTICE_ID) and not has_my_shell(who):
		return NO_SHELL
	if id == STILLWATER_ID and not stillwater_ok(float(who.get("health")), float(who.get("max_health"))):
		return NOT_LOW % Stats.num(Balance.STILLWATER_HEALTH_PCT)
	return ""

func _frost_healer_use(id: String, res: Resource) -> void:
	if id == FROST_TIDE_ID:
		player.status.apply(make_frost_tide_fx(), player)
		player._ring_effect(2.0, ICE)
		return
	var who: Node3D = player._pick_support_target(id)[0]
	if who == null:
		return
	match id:
		RIME_VEIL_ID:
			var amount := _shield_amount(Balance.RIME_VEIL_SHARE, RIME_VEIL_ID)
			_veils[who.get_instance_id()] = {"who": who, "amount": amount, "until": _now() + Balance.RIME_VEIL_TIME, "next": _now() + Balance.RIME_VEIL_EVERY}
			_frost_shield(who, RIME_VEIL_FX, amount, Balance.RIME_VEIL_TIME)
			player._combat().float_text(who, "%s (%d)" % [Abilities.ability_name(RIME_VEIL_ID), amount], ICE, false)
		BREAK_ICE_ID:
			_break_the_ice(who)
		LATTICE_ID:
			_link(who)
		STILLWATER_ID:
			_stillwater(who)
	player._ring_effect(1.0, ICE, who.global_position)

## Meltwater's or Rimefall's cast finished (from _release_support).
func _frost_healer_cast(spell: String, tgt: Variant, _kind: String) -> void:
	if spell == RIMEFALL_ID:
		var res := Abilities.get_resource(RIMEFALL_ID)
		var amount := _shield_amount(rimefall_share(shells_out().size()), RIMEFALL_ID)
		for a in player.fire_cooldowns._allies_within(float(res.radius)):
			_frost_shield(a, RIMEFALL_FX, amount, Balance.RIMEFALL_TIME)
		player._ring_effect(float(res.radius), ICE)
		return
	if tgt == null or not is_instance_valid(tgt) or not tgt.is_alive():
		return
	var who: Node3D = tgt
	player.strings._heal_coef(who, float(Abilities.HEALS[MELTWATER_ID]) * meltwater_mult(my_thawing_on(who)), MELTWATER_ID)
	player._ring_effect(0.9, ICE, who.global_position)

# Break the Ice: my shell on an ally, broken on purpose.

func _break_the_ice(who: Node3D) -> void:
	if is_same(who, player) or who.is_in_group("friendly"):
		var st: Node = player.status if is_same(who, player) else who.get_node_or_null("Status")
		if st == null:
			return
		var left := int(st.shield_from(RIME_SHELL_KEY, player))
		SHIELDS.drop_rime_shield(st, false)   # (silently: it breaks here, not through its shatter)
		broken_on_purpose(who, left)
	elif player._net():
		player._net().support_ally(who, player, "rime_break", {})   # their machine takes it off and says how much was left

## Break the Ice took my shell off `who` with `left` in it: heal everyone near them, shatter on enemies.
func broken_on_purpose(who: Node3D, left: int) -> void:
	if who == null or not is_instance_valid(who) or player.is_dead():
		return
	_shells.erase(who.get_instance_id())
	_unlink(who)
	var res := Abilities.get_resource(BREAK_ICE_ID)
	var radius := float(res.radius) + player._talent("frost_cold_spread")   # Cold Spread
	var near := player.prism_kit._allies_near(who.global_position, radius)
	var each := break_heal_each(left, near.size())
	for a in near:
		player.strings._heal_exact(a, each, BREAK_ICE_ID)
	player._ring_effect(radius, ICE, who.global_position)
	if not player.frost_melee._has_rune("everlasting_rime"):
		player.shatter_at(who.global_position)   # (Everlasting Rime: its shells deal no damage)

# Frost Lattice: links my shells.

func _link(who: Node3D) -> void:
	var size := lattice_size(player._talent("frost_wide_lattice"))   # Wide Lattice
	var others := shells_out().filter(func(a): return a != who)
	others.sort_custom(func(a, b): return who.global_position.distance_to(a.global_position) < who.global_position.distance_to(b.global_position))
	for a in _lattice:   # (a new lattice replaces the old one)
		if is_instance_valid(a):
			_set_share(a, 1, 0.0)
	_lattice = [who] + others.slice(0, size - 1)
	_lattice_until = _now() + Balance.LATTICE_TIME
	_share_out()
	for a in _lattice:
		player._ring_effect(1.2, ICE, (a as Node3D).global_position)

# Stillwater: encased, then healed.

func _stillwater(who: Node3D) -> void:
	if is_same(who, player):
		encased_by(player, Balance.STILLWATER_TIME)
	elif who.is_in_group("friendly"):
		var st: Node = who.get_node_or_null("Status")
		if st:
			st.apply(make_stillwater_fx(Balance.STILLWATER_TIME), player)
		_stills.append({"who": who, "until": _now() + Balance.STILLWATER_TIME})
	elif player._net():
		player._net().support_ally(who, player, "stillwater", {"t": Balance.STILLWATER_TIME})
	player._combat().float_text(who, Abilities.ability_name(STILLWATER_ID), ICE, false)

## `from`'s Stillwater encases me for `time` sec.
func encased_by(from: Node, time: float) -> void:
	if from == null or not is_instance_valid(from) or player.is_dead():
		return
	player.status.apply(make_stillwater_fx(time), from)
	player.status.set_remaining_from(STILLWATER_FX, from, time)
	_still_from = from
	_still_at = _now()
	_still_until = _now() + time

## The ice melted (or I moved out of it): `from` heals me.
func _melt() -> void:
	var from := _still_from
	_still_from = null
	if from != null and is_instance_valid(from):
		player.status.remove_from(STILLWATER_FX, from)
	if player.is_alive():
		var amount := float(player.max_health) * Balance.STILLWATER_HEAL_PCT / 100.0
		player._combat().heal(from if from != null and is_instance_valid(from) else player, player, amount, STILLWATER_ID, true)

static func _moving() -> bool:
	for a in ["move_forward", "move_back", "move_left", "move_right"]:
		if InputMap.has_action(a) and Input.is_action_pressed(a):
			return true
	return false

# --- Every frame ----------------------------------------------------------------------------

func _tick_frost_healer() -> void:
	if _still_from != null:
		var now0 := _now()
		if now0 >= _still_until or (now0 - _still_at > STILLWATER_GRACE and _moving()):
			_melt()
	if _veils.is_empty() and _runoffs.is_empty() and _stills.is_empty():
		return
	var now := _now()
	for key in _veils.keys():
		var g: Dictionary = _veils[key]
		if now >= float(g["until"]) or not is_instance_valid(g["who"]) or not g["who"].is_alive():
			_veils.erase(key)
		elif now >= float(g["next"]):
			g["next"] = float(g["next"]) + Balance.RIME_VEIL_EVERY
			_frost_shield(g["who"], RIME_VEIL_FX, int(g["amount"]), float(g["until"]) - now)   # the ice forms again
	for r in _runoffs.duplicate():
		if now < float(r["next"]):
			continue
		r["next"] = float(r["next"]) + 1.0
		r["left"] = int(r["left"]) - 1
		if is_instance_valid(r["who"]) and r["who"].is_alive():
			player.strings._heal_exact(r["who"], int(r["per"]), RUNOFF_ID)
		if int(r["left"]) <= 0 or not is_instance_valid(r["who"]):
			_runoffs.erase(r)
	for e in _stills.duplicate():
		if now >= float(e["until"]):
			_stills.erase(e)
			var d: Variant = e["who"]
			if d != null and is_instance_valid(d):
				player._combat().heal(player, d, float(d.get("max_health")) * Balance.STILLWATER_HEAL_PCT / 100.0, STILLWATER_ID, true)

# --- Splinterheal (talent): my shatters on enemies heal --------------------------------------

func _on_damage_dealt(info: RefCounted) -> void:
	if info == null or not is_same(info.source, player) or int(info.amount) <= 0 or not info.tags.has("Shatter"):
		return
	var pct := player._talent("frost_splinterheal")
	var foe: Variant = info.target
	if pct <= 0.0 or foe == null or not is_instance_valid(foe) or not (foe as Node).is_in_group("enemies"):
		return
	var near := player.prism_kit._allies_near((foe as Node3D).global_position, Balance.SPLINTERHEAL_RADIUS)
	if near.is_empty():
		return
	var shares: Array = near.map(func(a): return player.hymns._health_share_of(a))
	var i := FireCooldownsKit.lowest_share(shares)
	if i >= 0:
		player.strings._heal_exact(near[i], int(round(int(info.amount) * pct / 100.0)), SPLINTERHEAL_ID)

# --- A party member's machine (StringsKit.receive_support) -----------------------------------

func receive(kind: String, from: Node, data: Dictionary) -> void:
	match kind:
		"frost_shield":
			if player.is_alive():
				frost_shield_on(player.status, from, str(data.get("id", "")), int(data.get("amount", 0)), float(data.get("time", 0.0)))
		"lattice":
			if player.status.shield_from(RIME_SHELL_KEY, from) > 0:
				player.status.set_share(RIME_SHELL_KEY, int(data.get("n", 1)), player.status._now() + float(data.get("t", 0.0)))
		"rime_drain":
			player.status.drain_absorb(RIME_SHELL_KEY, int(data.get("amount", 0)), from)
		"rime_break":
			var left := int(player.status.shield_from(RIME_SHELL_KEY, from))
			if left > 0:
				SHIELDS.drop_rime_shield(player.status, false)
				if player._net():
					player._net().support_ally(from, player, "rime_broken", {"left": left})
		"stillwater":
			encased_by(from, float(data.get("t", 0.0)))
		# (I am the healer: about my shell on that ally.)
		"rime_broke":
			shell_broke(from as Node3D, int(data.get("amount", 0)))
		"rime_runoff":
			shell_runoff(from as Node3D, int(data.get("left", 0)))
		"rime_broken":
			broken_on_purpose(from as Node3D, int(data.get("left", 0)))
		"lattice_bill":
			lattice_billed(from as Node3D, int(data.get("amount", 0)))
