extends "res://scripts/player/player_kit.gd"
class_name ArcaneMeleeKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "arcane_melee".
# --- Arcane melee (a damage dealer with a melee weapon in each hand) --------------------
# No resource: cooldowns alone. Every strike I land with an Arcane melee ability
# leaves a Trace on me: a record of the damage it dealt. I hold up to TRACE_MAX
# (the newest pushes out the oldest), each for TRACE_TIME seconds. Encore replays
# every Trace on my target for ENCORE_PCT % of what it recorded, and uses them up.
# Swift Cut, Deep Cut, Late Cut and Wide Cut are its strikes (the tank's strikes
# and Arcane Strike leave Traces too); Double Time makes each strike leave more
# Traces and lets me hold more. Traces are only kept while I know Encore.
# Talents: Long Memory (Traces last longer), Standing Ovation (Encore replays
# more; capstone: one more Trace), Clean Lines (a Swift Cut crit brings Deep Cut
# back sooner), Second Showing (Encore may keep the Traces). Numbers: balance.gd.

const TRACE_FX := "trace"
const SWIFT_CUT_ID := "swiftcut"
const DEEP_CUT_ID := "deepcut"
const LATE_CUT_ID := "latecut"
const WIDE_CUT_ID := "widecut"
const ENCORE_ID := "encore"
const DOUBLE_TIME_ID := "doubletime"
const DOUBLE_TIME_FX := "double_time"
const FULL_HOUSE_FX := "full_house"            # Full House: my next Encore reaches other enemies too
## The replays Full House adds on other enemies: their own line on the meter (Details.HIT_NAMES).
const FULL_HOUSE_HIT_ID := "full_house"
const DRESS_REHEARSAL_FX := "dress_rehearsal"  # Dress Rehearsal's capstone: my next Encore keeps the Traces
const CURTAIN_CALL_LABEL := "Curtain Call"
const TRACE_TAGS := ["Arcane", "Ability", "Melee"]

var _traces: Array = []       # oldest first: {"id": ability, "key": int, "amount": int, "born": float, "until": float}
var _trace_serial := 0        # the key of the next new Trace (copies of one strike share it)
var _trace_fx: Resource

## Does this hit leave a Trace? A hit of an Arcane melee ability that landed:
## never a proc (Encore's replays, Late Cut's second hit, echoes), damage over
## time or a spell.
static func leaves_trace(tags: PackedStringArray, is_proc: bool, is_dot: bool, amount: int) -> bool:
	return amount > 0 and not is_proc and not is_dot \
		and tags.has("Arcane") and tags.has("Melee") and tags.has("Ability")

## How many Traces I can hold (`extra` = Standing Ovation's capstone, `double` = Double Time).
static func trace_cap(extra: bool, double: bool) -> int:
	return (Balance.TRACE_MAX + (Balance.STANDING_OVATION_TRACES if extra else 0)) \
		* (Balance.DOUBLE_TIME_TRACES if double else 1)

## Seconds a Trace lasts (`longer` = Long Memory).
static func trace_time(longer: float) -> float:
	return Balance.TRACE_TIME + maxf(longer, 0.0)

## The Traces of `traces` that have not run out at `now`.
static func traces_alive(traces: Array, now: float) -> Array:
	var out := []
	for t in traces:
		if float(t["until"]) > now:
			out.append(t)
	return out

## `traces` (oldest first) after a hit of ability `id` dealt `amount` at `now`.
## The hits of one use of an ability share a Trace (a Trace of the same ability
## born within TRACE_MERGE_WINDOW): it keeps the largest of them, so Wide Cut
## leaves one Trace however many enemies it hits. Otherwise `copies` new Traces
## with the key `key` are added, and the oldest are pushed out past `cap`.
## Holding more than `cap` already (Double Time ended with more than the usual
## limit), nothing is added and nothing is pushed out: those Traces stay to be
## replayed or to run out, and new ones come once I am back within the limit.
static func traces_after(traces: Array, id: String, amount: int, now: float, until: float,
		copies: int, cap: int, key: int) -> Array:
	var out := traces.duplicate(true)
	var merged := false
	for t in out:
		if str(t["id"]) == id and now - float(t["born"]) <= Balance.TRACE_MERGE_WINDOW:
			t["amount"] = maxi(int(t["amount"]), amount)
			merged = true
	if out.size() > maxi(cap, 0):
		return out
	if not merged:
		for i in maxi(copies, 1):
			out.append({"id": id, "key": key, "amount": amount, "born": now, "until": until})
	while out.size() > maxi(cap, 0):
		out.pop_front()
	return out

## `traces` with `amount` added to every Trace with the key `key` (Late Cut's
## second hit joins the Trace its first one left).
static func traces_added(traces: Array, key: int, amount: int) -> Array:
	var out := traces.duplicate(true)
	for t in out:
		if int(t["key"]) == key:
			t["amount"] = int(t["amount"]) + maxi(amount, 0)
	return out

## The key of the newest Trace of ability `id` (-1 = none).
static func newest_trace_key(traces: Array, id: String) -> int:
	for i in range(traces.size() - 1, -1, -1):
		if str(traces[i]["id"]) == id:
			return int(traces[i]["key"])
	return -1

## % of a Trace's recorded damage Encore replays (`more` = Standing Ovation).
static func encore_pct(more: float) -> float:
	return Balance.ENCORE_PCT + maxf(more, 0.0)

## Damage of Encore's replay of a Trace that recorded `amount`.
static func encore_amount(amount: int, pct: float) -> int:
	return int(round(maxf(float(amount), 0.0) * maxf(pct, 0.0) / 100.0))

## Does Encore use my Traces up? (Second Showing: a `pct` % chance it does not;
## `roll` 0-100. `free` = Dress Rehearsal's capstone: the first Encore during
## Double Time never does.)
static func encore_uses_traces(pct: float, roll: float, free: bool = false) -> bool:
	return not free and not (pct > 0.0 and roll < pct)

## Damage the Trace of a hit of `amount` by ability `id` records (Heavy Hand:
## Deep Cut's records `heavy_pct` % more than the strike dealt).
static func trace_amount(id: String, amount: int, heavy_pct: float) -> int:
	if id == DEEP_CUT_ID and heavy_pct > 0.0:
		return int(round(float(amount) * (1.0 + heavy_pct / 100.0)))
	return amount

## Is a Trace with the key `key` among `traces`?
static func has_trace_key(traces: Array, key: int) -> bool:
	for t in traces:
		if int(t["key"]) == key:
			return true
	return false

## Seconds until Late Cut's second hit (`sooner` = No Loose Ends).
static func late_cut_delay(sooner: float) -> float:
	return maxf(Balance.LATE_CUT_DELAY - maxf(sooner, 0.0), 0.1)

## % more damage Practiced Hand gives Swift Cut: `per` % for each Trace I hold.
static func practiced_hand_pct(per: float, held: int) -> float:
	return maxf(per, 0.0) * maxi(held, 0)

## % more damage Curtain Call gives each replay when Encore replays `replayed` Traces.
static func curtain_call_pct(pct: float, replayed: int) -> float:
	return pct if pct > 0.0 and replayed >= Balance.CURTAIN_CALL_TRACES else 0.0

## Seconds Time Signature takes off my other Arcane cooldowns when Encore
## replays `replayed` Traces (`per` seconds for each).
static func time_signature_cut(per: float, replayed: int) -> float:
	return maxf(per, 0.0) * maxi(replayed, 0)

## Full House: does a Wide Cut that hit `enemies` enemies set up my next Encore?
## (`others` = the talent's number: the other enemies that Encore will reach.)
static func full_house_ready(others: float, enemies: int) -> bool:
	return others > 0.0 and enemies >= Balance.FULL_HOUSE_ENEMIES

## Full House: damage each other enemy takes from a replay of `amount`.
static func full_house_amount(amount: int) -> int:
	return int(round(maxf(float(amount), 0.0) * Balance.FULL_HOUSE_PCT / 100.0))

## Full House: the buff that says my next Encore reaches the enemies around its target.
static func make_full_house_fx() -> Resource:
	var fx := StatusContainer.make_buff(FULL_HOUSE_FX, "Full House", FULL_HOUSE_FX, 0.0, Balance.FULL_HOUSE_TIME, 1,
		Abilities.color_of(ENCORE_ID))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Arcane"])
	fx.description = "Your next %s also replays each Trace on other enemies near its target, for %s%% of its damage." % [
		Abilities.ability_name(ENCORE_ID), Stats.num(Balance.FULL_HOUSE_PCT)]
	return fx

## Dress Rehearsal's capstone: the buff that says my next Encore keeps the Traces
## (`time` = seconds Double Time lasts).
static func make_dress_rehearsal_fx(time: float) -> Resource:
	var fx := StatusContainer.make_buff(DRESS_REHEARSAL_FX, "Dress Rehearsal", DRESS_REHEARSAL_FX, 0.0, time, 1,
		Abilities.color_of(DOUBLE_TIME_ID))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Arcane"])
	fx.description = "Your next %s does not use up your Traces." % Abilities.ability_name(ENCORE_ID)
	return fx

## Seconds Double Time lasts (`longer` = Dress Rehearsal).
static func double_time_time(longer: float) -> float:
	return Balance.DOUBLE_TIME_TIME + maxf(longer, 0.0)

func _trace_now() -> float:
	return Time.get_ticks_msec() / 1000.0

## How many Traces I hold.
func traces() -> int:
	return _traces.size()

func _trace_buff() -> Resource:
	if _trace_fx == null:
		_trace_fx = StatusContainer.make_buff(TRACE_FX, "Trace", TRACE_FX, 0.0, Balance.TRACE_TIME,
			trace_cap(true, true), Abilities.color_of(ENCORE_ID))
		_trace_fx.stat_modifiers = {}
		_trace_fx.tags = PackedStringArray(["Arcane"])
		_trace_fx.description = "A record of the damage one of your strikes dealt. %s replays it." % Abilities.ability_name(ENCORE_ID)
	return _trace_fx

## The buff shows how many Traces I hold, and when the oldest of them runs out.
func _sync_traces() -> void:
	if player.status == null:
		return
	if _traces.is_empty():
		if player.status.has(TRACE_FX):
			player.status.remove(TRACE_FX)
		return
	if not player.status.has(TRACE_FX):
		player.status.apply(_trace_buff(), player)
	player.status.set_stacks(TRACE_FX, _traces.size())
	# (A moment longer than the Trace itself, so _tick_traces is what ends it.)
	player.status.set_remaining(TRACE_FX, maxf(float(_traces[0]["until"]) - _trace_now(), 0.0) + 0.1)

## Traces run out one by one (_process).
func _tick_traces() -> void:
	if _traces.is_empty():
		return
	var alive := traces_alive(_traces, _trace_now())
	if alive.size() != _traces.size():
		_traces = alive
		_sync_traces()

func _clear_traces() -> void:
	if _traces.is_empty():
		return
	_traces = []
	_sync_traces()

## Every hit I deal (_on_damage_dealt_arcane): a strike with an Arcane melee
## ability leaves a Trace of the damage it dealt. Clean Lines: a Swift Cut that
## critically strikes brings Deep Cut back sooner.
func _trace_hit(info: RefCounted, id: String, amount: int) -> void:
	if id == SWIFT_CUT_ID and bool(info.crit) and not bool(info.is_proc):
		var clean := player._talent("arcane_clean_lines")
		if clean > 0.0:
			player.arcane_caster._cut_cooldown(DEEP_CUT_ID, clean)
	if not Abilities.PATHS.has(id) or not leaves_trace(info.tags, bool(info.is_proc), bool(info.is_dot), amount):
		return
	_leave_trace(id, player.arcane_talents.fresh_trace(trace_amount(id, amount, player._talent("arcane_heavy_hand"))))   # Heavy Hand: Deep Cut's records more; Fresh Trace

## A strike of ability `id` leaves a Trace that records `amount` (or joins the
## Trace the same use already left: traces_after).
func _leave_trace(id: String, amount: int) -> void:
	var pd := player.get_node_or_null("/root/PlayerData")
	if pd == null or not pd.has_ability(ENCORE_ID):
		return   # nothing to replay them with
	var now := _trace_now()
	var double: bool = player.status != null and player.status.has(DOUBLE_TIME_FX)
	_trace_serial += 1
	# (Long Memory makes them last longer; so does Overtime, like the buff they are shown as.)
	_traces = traces_after(traces_alive(_traces, now), id, amount, now,
		now + trace_time(player._talent("arcane_long_memory")) * player.arcane_open.self_buff_time_mult(),
		Balance.DOUBLE_TIME_TRACES if double else 1, trace_cap(player.frost_melee._capstone("arcane_standing_ovation"), double), _trace_serial)
	_sync_traces()

## Late Cut: the cut lands, and lands again LATE_CUT_DELAY seconds later for the
## same damage (a proc: it can't crit or be avoided, the first hit already was
## rolled). The second hit joins the Trace the first one left.
func _late_cut(w: Dictionary, res: Resource) -> void:
	var foe: Node = player.target
	var first := player.deal_damage(foe, player.arcane_tank._dual_weapon_hit(w, res), LATE_CUT_ID)
	player._slash_effect(Abilities.color_of(LATE_CUT_ID))
	if first <= 0:
		return
	var key := newest_trace_key(_traces, LATE_CUT_ID)
	player.get_tree().create_timer(late_cut_delay(player._talent("arcane_no_loose_ends"))).timeout.connect(func():   # No Loose Ends: sooner
		if player.is_dead() or not is_instance_valid(foe) or not foe.is_alive():
			return
		player.arcane_caster._exact_hit(foe, first, LATE_CUT_ID, "arcane", PackedStringArray(TRACE_TAGS))
		if foe is Node3D:
			player._ring_effect(0.5, Abilities.color_of(LATE_CUT_ID), (foe as Node3D).global_position)
		if key >= 0 and has_trace_key(_traces, key):
			_traces = traces_added(_traces, key, first)
			_sync_traces()
		elif player.frost_melee._capstone("arcane_no_loose_ends"):
			_leave_trace(LATE_CUT_ID, first))   # its Trace is gone: this hit leaves one of its own

## Wide Cut: everything around me is hit with both weapons; more than
## AOE_TARGET_CAP enemies share that many hits' damage. Its hits leave one
## Trace between them (the largest: _trace_hit).
func _wide_cut(w: Dictionary, res: Resource) -> void:
	var col := Abilities.color_of(WIDE_CUT_ID)
	var reach := float(res.radius) + Abilities.radius_bonus(WIDE_CUT_ID)
	var hit := player._enemies_within(reach)
	var coef := player.arcane_tank._dual_weapon_hit(w, res) * Balance.aoe_share(hit.size())
	for e in hit:
		if is_instance_valid(e) and e.is_alive():
			player.deal_damage(e, coef, WIDE_CUT_ID)
	# Full House: a Wide Cut into a crowd, and my next Encore reaches the enemies around its target too.
	if full_house_ready(player._talent("arcane_full_house"), hit.size()):
		player.status.apply(make_full_house_fx(), player)
	for i in 2:
		player._slash_effect(col)
	player._ring_effect(reach, col)
	player._ring_effect(reach * 0.6, Color(0.95, 0.9, 1.0))

## Encore: every Trace I hold is replayed on my target, each for a share of the
## damage it recorded (exact: its crit and every modifier are already in it; a
## proc, so it leaves no Trace and feeds nothing). Then they are gone, unless
## Second Showing keeps them.
func _encore() -> void:
	var foe: Node = player.target
	var held := traces_alive(_traces, _trace_now())
	var pct := encore_pct(player._talent("arcane_standing_ovation"))   # + Standing Ovation
	# A ghost of me runs through the target for each Trace (scripts/trace_ghost.gd),
	# one after the other; each Trace's hit lands as its ghost gets there.
	var from := player.global_position
	var through := from
	if is_instance_valid(foe) and foe is Node3D:
		var there: Vector3 = (foe as Node3D).global_position
		through = Vector3(there.x, from.y + (Combat.feet_y(foe) - Combat.feet_y(player)), there.z)
	var count := held.size()
	# Curtain Call: a full replay hits harder (what it adds is its own line on the meter).
	var curtain := curtain_call_pct(player._talent("arcane_curtain_call"), count)
	var bonuses: Array = [[curtain, CURTAIN_CALL_LABEL]] if curtain > 0.0 else []
	# Full House: after a Wide Cut into a crowd, each Trace is replayed on the
	# enemies nearest the target too, for a share of its damage. This Encore uses it up.
	var others: Array = []
	if player.status.has(FULL_HOUSE_FX):
		player.status.remove(FULL_HOUSE_FX)
		var reach := int(round(player._talent("arcane_full_house")))
		if foe is Node3D:
			for e in player._enemies_near((foe as Node3D).global_position, Balance.FULL_HOUSE_RADIUS, foe):
				if others.size() >= reach:
					break
				others.append(e)
	ArcaneTankKit.TRACE_GHOST.run(player.get_tree().current_scene, player, from, through, count)
	player._net_fx("ghosts", from, null, {"to": through, "n": count})
	for i in count:
		var amount := encore_amount(int(held[i]["amount"]), pct)
		var share := full_house_amount(amount)
		player.get_tree().create_timer(maxf(ArcaneTankKit.TRACE_GHOST.hit_time(from, through, i, count), 0.02)).timeout.connect(func():
			if not player.is_alive():
				return
			if is_instance_valid(foe) and foe.is_alive():
				player.arcane_caster._exact_hit(foe, amount, ENCORE_ID, "arcane", PackedStringArray(TRACE_TAGS),
					bonuses + player.arcane_talents.replay_bonuses(foe))   # (+ Final Act)
				if foe is Node3D:
					player._ring_effect(0.5, Color(0.95, 0.9, 1.0), (foe as Node3D).global_position)
			for e in others:
				if is_instance_valid(e) and e.is_alive():
					player.arcane_caster._exact_hit(e, share, FULL_HOUSE_HIT_ID, "arcane", PackedStringArray(TRACE_TAGS),
						bonuses + player.arcane_talents.replay_bonuses(e))
					if e is Node3D:
						player._ring_effect(0.4, Abilities.color_of(ENCORE_ID), (e as Node3D).global_position))
	# Dress Rehearsal's capstone: the first Encore during Double Time keeps the Traces.
	var free: bool = player.status.has(DRESS_REHEARSAL_FX) and player.status.has(DOUBLE_TIME_FX)
	if player.status.has(DRESS_REHEARSAL_FX):
		player.status.remove(DRESS_REHEARSAL_FX)
	_traces = [] if encore_uses_traces(player._talent("arcane_second_showing"), randf() * 100.0, free) else held
	_sync_traces()
	# Time Signature: each Trace replayed takes time off everything else Arcane
	# (spells and abilities alike; never an interrupt).
	var signature := time_signature_cut(player._talent("arcane_time_signature"), held.size())
	if signature > 0.0:
		for cd in player.cooldowns.keys():
			if str(cd) != ENCORE_ID and (player.arcane_caster._in_arcane_book(str(cd)) or player.arcane_caster._is_arcane_spell(str(cd))):
				player.arcane_caster._cut_cooldown(str(cd), signature)
	player.arcane_talents.replayed(count)   # Curtain Rise
	player._slash_effect(Abilities.color_of(ENCORE_ID))

func _start_double_time() -> void:
	var time := double_time_time(player._talent("arcane_dress_rehearsal"))   # + Dress Rehearsal
	player.arcane_caster._arcane_buff(DOUBLE_TIME_FX, DOUBLE_TIME_ID, time,
		"Each of your strikes leaves more Traces, and you can hold more of them.")
	if player.frost_melee._capstone("arcane_dress_rehearsal"):
		player.status.apply(make_dress_rehearsal_fx(time), player)   # its capstone: the first Encore while it lasts keeps the Traces
	player._ring_effect(1.5, Abilities.color_of(DOUBLE_TIME_ID))
	player._ring_effect(0.9, Color(0.95, 0.9, 1.0))

