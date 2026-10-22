extends Node

# Status effect component. Add one as a child named "Status" to any character
# (player, enemies). Handles duration, stacking, stat modifiers (flat and
# "<stat>%" percent keys), damage modifiers, damage over time and crowd
# control. Owner reads:
#   stat_mod("move_speed"), has_flag("stun"/"root"), list()
# Effects are StatusEffectData resources (or built at runtime by make_buff()).
#
# Debuff design note: a debuff that changes damage taken (modifies_incoming)
# helps EVERY ally hitting that target, so keep those rare and hard to apply;
# most interactions should be buffs on the attacker.

signal changed
## A shield was used up by damage (not removed / expired). `id` = its effect key.
signal shield_broken(id: String)
## A shared shield (Frost Lattice: set_share) soaked a hit and paid only its own
## share: `billed` is the rest, for the other shells it is linked with to pay.
signal shield_shared(id: String, billed: int, source: Node)
## A shield ran out of time with `left` still in it (not broken, not removed).
## `source` = who put it on (Runoff: Rime Shell's caster heals what was left).
signal shield_expired(id: String, left: int, source: Node)

const StatusEffectScript = preload("res://scripts/data/status_effect_data.gd")
const COMBAT = preload("res://scripts/core/combat_system.gd")
const Stats = preload("res://scripts/core/stats.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")

# Active effects: key -> {res, stacks, expires, next_tick, tick, source, tags}
#   key  = the effect id, except for damage over time (and effects marked
#          per_caster): "<id>@<source>" so each caster has their own copy (two
#          players' Burning both tick). Use key_for(); has() / remove() /
#          stacks_of() take the plain effect id.
#
# Multiplayer: an enemy's effects live on the host and are mirrored to everyone
# (enemy.net_apply_status). The DAMAGE of a damage-over-time effect - its ticks
# and its burst - is dealt on the machine of the player who cast it, with that
# player's stats, talents and runes, and reported to the host like any other
# hit. Every other machine (the host included) only shows the effect.
#   tick = seconds between DoT ticks (hasted by the source when applied)
#   tags = tags of the spell/ability that applied it (DoT ticks count as that kind)
var effects := {}

## Storage key of `res` applied by `source`: DoTs are kept per caster.
static func key_for(res: Resource, source: Node) -> String:
	var id := str(res.id)
	if (float(res.tick_damage) > 0.0 or bool(res.get("per_caster"))) and source != null and is_instance_valid(source):
		return "%s@%d" % [id, source.get_instance_id()]
	return id

## Is this effect's damage dealt on another machine? True when another party
## member cast it: their machine ticks it, this one only shows it.
static func owned_elsewhere(e: Dictionary) -> bool:
	var src: Variant = e.get("source")
	return src != null and is_instance_valid(src) and (src as Node).is_in_group("remote_player")

# --- Multiplayer helpers ------------------------------------------------------------

## Tags of the spell / ability that last applied each effect on this machine
## (effect id -> tags). A mirrored copy of my own DoT is given these.
static var _tag_hints := {}

static func tag_hint(effect_id: String) -> PackedStringArray:
	return _tag_hints.get(effect_id, PackedStringArray(["Spell"]))

## Seconds between ticks of DoT `res` cast by `source` (their Haste makes it faster).
static func tick_for(res: Resource, source: Node) -> float:
	var tick := maxf(float(res.tick_interval), 0.05)
	if float(res.tick_damage) > 0.0 and bool(res.dot_hasted):
		tick = maxf(tick / Stats.haste_mult(_stat_of(source, Stats.HASTE)), 0.05)
	return tick

## Keys this machine just ended itself (key -> time until which a mirrored
## copy from the host must not bring it back).
var _suppressed := {}

func suppress(key: String, seconds: float = 0.6) -> void:
	_suppressed[key] = _now() + seconds

func is_suppressed(key: String) -> bool:
	if not _suppressed.has(key):
		return false
	if _now() >= float(_suppressed[key]):
		_suppressed.erase(key)
		return false
	return true

## Mark `source`'s copy of `res` as applied by a hit on this machine just now:
## the host will list it shortly, until then the mirror must leave it alone.
func mark_predicted(res: Resource, source: Node) -> void:
	var key := key_for(res, source)
	if effects.has(key):
		effects[key]["predicted"] = _now()

## What the caster's talents made of `source`'s copy of `res`: {"dur": seconds
## left, "slow": slow strength}. Sent to the host so its copy matches.
func params_of(res: Resource, source: Node) -> Dictionary:
	var key := key_for(res, source)
	if not effects.has(key):
		return {}
	var out := {"dur": maxf(float(effects[key]["expires"]) - _now(), 0.0)}
	if effects[key].has("slow_mult"):
		out["slow"] = float(effects[key]["slow_mult"])
	if int(effects[key].get("hits", 0)) < 0:
		out["hits"] = int(effects[key]["hits"])   # (Pinned Down: more hits to shake it)
	return out

## Host: give `source`'s copy of `res` the numbers its caster's machine worked out.
func tune(res: Resource, source: Node, params: Dictionary) -> void:
	var key := key_for(res, source)
	if not effects.has(key):
		return
	if float(params.get("dur", 0.0)) > 0.0:
		effects[key]["expires"] = _now() + float(params["dur"])
	if float(params.get("slow", 0.0)) > 0.0:
		effects[key]["slow_mult"] = float(params["slow"])
	if int(params.get("hits", 0)) < 0:
		effects[key]["hits"] = int(params["hits"])

## Keys of every active copy of effect `id`.
func _keys_of(id: String) -> Array:
	var out := []
	for k in effects:
		if k == id or str(k).begins_with(id + "@"):
			out.append(k)
	return out

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

# Every character carries one of these; most have no effects most of the
# time, so per-frame processing is only on while something is active.
func _ready() -> void:
	set_process(not effects.is_empty())

static func _stat_of(node: Node, stat: String) -> float:
	if node == null or not is_instance_valid(node) or not node.has_method("get_stat"):
		return 0.0
	return float(node.get_stat(stat))

## Apply an effect from `source` (may be null). `tags` = tags of the spell /
## ability that applied it. Returns true if it changed anything.
func apply(res: Resource, source: Node = null, tags: PackedStringArray = PackedStringArray()) -> bool:
	if res == null:
		return false
	var owner_node := get_parent()
	if owner_node.has_method("is_alive") and not owner_node.is_alive():
		return false
	# Immunities (Unstoppable elites ignore stuns / roots / slows).
	if owner_node.has_method("resists_effect") and owner_node.resists_effect(res):
		return false
	var id := key_for(res, source)
	var now := _now()
	var announce := false   # new effect or new stack -> event feed
	# (My own untagged applications count too: a rune's poison has no spell tags.)
	if not tags.is_empty() or (source != null and is_instance_valid(source) and source.is_in_group("player")):
		_tag_hints[str(res.id)] = tags
	_suppressed.erase(id)
	if _consume_queue.has(id) and effects.has(id):
		# Used up earlier this frame: the new application starts fresh (on top of
		# whatever stacks the carrier keeps).
		_consume_queue.erase(id)
		_use_up(id)
	var tick: float = maxf(float(res.tick_interval), 0.05)
	var unit := COMBAT.unit_of(source)
	if res.tick_damage > 0 and res.dot_hasted:
		tick = maxf(tick / Stats.haste_mult(_stat_of(source, Stats.HASTE)), 0.05)
	# Re-applying your own (non-stacking) DoT: the old one is removed and a fresh
	# one starts (full duration, new tick timer, your current haste / tags).
	if effects.has(id) and res.tick_damage > 0 and int(res.stack_mode) == 0:
		effects.erase(id)
		effects[id] = {"res": res, "stacks": 1, "expires": now + res.duration,
			"next_tick": now + tick, "tick": tick, "source": source, "tags": tags, "unit": unit}
	elif effects.has(id):
		var e: Dictionary = effects[id]
		match res.stack_mode:
			0:  # REFRESH
				e["expires"] = now + res.duration
				e.erase("hits")   # (Pin the Shadow: a new one takes its hits over)
			1:  # ADD_STACK (every new stack refreshes the duration of all stacks)
				var before := int(e["stacks"])
				e["stacks"] = mini(before + 1, max(res.max_stacks, 1))
				e["expires"] = now + res.duration
				announce = int(e["stacks"]) != before
			2:  # IGNORE
				return false
		e["source"] = source
		e["tick"] = tick
		e["unit"] = unit
		if not tags.is_empty():
			e["tags"] = tags
	else:
		effects[id] = {"res": res, "stacks": 1, "expires": now + res.duration,
			"next_tick": now + tick, "tick": tick, "source": source, "tags": tags, "unit": unit}
		announce = true
	# Slows from a caster with slow talents (Deep Chill) are stronger.
	if effects.has(id) and float(res.stat_modifiers.get("move_speed", 0.0)) < 0.0 \
			and source != null and is_instance_valid(source) and source.has_method("slow_mult"):
		effects[id]["slow_mult"] = float(source.slow_mult(tags))
	# Casters can lengthen effects they apply (Deep Hoarfrost).
	if effects.has(id) and source != null and is_instance_valid(source) and source.has_method("effect_duration_bonus"):
		effects[id]["expires"] = float(effects[id]["expires"]) + float(source.effect_duration_bonus(res))
	# ... make effects that end after a number of hits take more of them (Pinned Down):
	# the count starts below 0.
	if effects.has(id) and int(res.get("break_after_hits") if res.get("break_after_hits") != null else 0) > 0 \
			and source != null and is_instance_valid(source) and source.has_method("effect_extra_hits"):
		var more := int(source.effect_extra_hits(res))
		if more > 0:
			effects[id]["hits"] = -more
	# ... and make the buffs they put on themselves last longer (Overtime).
	if effects.has(id) and source != null and is_instance_valid(source) and is_same(source, owner_node) \
			and not bool(res.is_debuff) and source.has_method("self_buff_time_mult"):
		var longer := float(source.self_buff_time_mult(res))
		if longer != 1.0:
			effects[id]["expires"] = now + (float(effects[id]["expires"]) - now) * longer
	# Whose it is: a shared effect (Chilled, Frozen...) has one copy for everyone,
	# so every caster is remembered for as long as their own application would
	# run. has_from() answers from this: what an ally does to the same effect
	# never changes whether it counts as mine.
	if effects.has(id) and source != null and is_instance_valid(source):
		var by: Dictionary = effects[id].get("by", {})
		by[source.get_instance_id()] = float(effects[id]["expires"])
		effects[id]["by"] = by
	# A damage-over-time effect that just (re)started: its first tick already comes
	# at the speed its caster gives it on this target (Pitch Arrow).
	if effects.has(id) and res.tick_damage > 0 and is_equal_approx(float(effects[id]["next_tick"]), now + tick):
		effects[id]["next_tick"] = now + tick_interval_of(effects[id])
	set_process(true)
	changed.emit()
	if announce and is_inside_tree():
		var bus := get_node_or_null("/root/SignalBus")
		if bus:
			bus.status_applied.emit(owner_node, res.display_name, res.is_debuff, int(effects[id]["stacks"]))
	return true

func remove(id: String) -> void:
	var keys := _keys_of(id)
	for k in keys:
		effects.erase(k)
		absorbs.erase(k)
	if not keys.is_empty():
		changed.emit()

## The carrier took damage: effects that end on damage (Spore Sleep's sleep) end.
func break_on_damage() -> void:
	var gone: Array = []
	for k in effects:
		if effects[k]["res"].break_on_damage:
			gone.append(k)
	for k in gone:
		effects.erase(k)
		absorbs.erase(k)
	if not gone.is_empty():
		changed.emit()

## The carrier took a direct hit (not over time), from anyone: effects that end
## after a number of hits (Pin the Shadow) count it.
func count_hit() -> void:
	var gone: Array = []
	for k in effects:
		var need: Variant = effects[k]["res"].get("break_after_hits")
		if need == null or int(need) <= 0:
			continue
		effects[k]["hits"] = int(effects[k].get("hits", 0)) + 1
		if int(effects[k]["hits"]) >= int(need):
			gone.append(k)
	for k in gone:
		effects.erase(k)
		absorbs.erase(k)
	if not gone.is_empty():
		changed.emit()

func clear() -> void:
	absorbs.clear()
	if not effects.is_empty():
		effects.clear()
		changed.emit()

# --- Absorb shields -------------------------------------------------------------------
# An active effect can carry a shield that soaks incoming damage (after
# mitigation). When the shield is used up the effect ends and `on_break`
# runs (e.g. Rime Shell shattering). Expiring or being removed never calls it.

var absorbs := {}   # effect key -> {"amount": int, "on_break": Callable, "keep": bool}
## Who cast the shield that broke last (read it inside shield_broken).
var last_shield_source: Variant = null

## Give the active effect `id` a shield of `amount` health. Replaces any old one.
## `keep_effect`: the effect stays (for the rest of its time) when the shield is
## used up - a Rime Shell on an enemy keeps weakening it after it shattered.
func set_absorb(id: String, amount: int, on_break: Callable = Callable(), keep_effect: bool = false) -> void:
	if not effects.has(id) or amount <= 0:
		return
	absorbs[id] = {"amount": amount, "full": amount, "on_break": on_break, "keep": keep_effect}
	effects[id].erase("net_absorb")
	changed.emit()

## Make the shield on effect `id` `amount` bigger, keeping what happens when it
## breaks (Frost Lattice grows a Rime Shell). Nothing if it has no shield.
func add_absorb(id: String, amount: int) -> void:
	if not absorbs.has(id) or amount <= 0:
		return
	absorbs[id]["amount"] = int(absorbs[id]["amount"]) + amount
	absorbs[id]["full"] = int(absorbs[id].get("full", 0)) + amount
	changed.emit()

## Frost Lattice: until `until` (this machine's clock), the shield on effect `id`
## is one of `n` linked shells. A hit on it costs it only 1/n; the rest is billed
## to the others (shield_shared). n = 1 ends it.
func set_share(id: String, n: int, until: float = 0.0) -> void:
	if not absorbs.has(id):
		return
	absorbs[id]["share"] = maxi(n, 1)
	absorbs[id]["share_until"] = until

## How many linked shells share effect `id`'s hits right now (1 = none).
func share_of(id: String) -> int:
	if not absorbs.has(id) or _now() >= float(absorbs[id].get("share_until", 0.0)):
		return 1
	return maxi(int(absorbs[id].get("share", 1)), 1)

## Take `amount` off `source`'s shield on effect `id` (another linked shell's
## share of a hit). Used up: it breaks, as if a hit had broken it.
func drain_absorb(id: String, amount: int, source: Node = null) -> void:
	if not absorbs.has(id) or amount <= 0 or (source != null and shield_from(id, source) <= 0):
		return
	absorbs[id]["amount"] = int(absorbs[id]["amount"]) - amount
	if int(absorbs[id]["amount"]) <= 0:
		last_shield_source = effects[id].get("source") if effects.has(id) else null
		break_absorb(id, false)
		shield_broken.emit(id)
	else:
		changed.emit()

## How much of effect `id`'s shield is still there, 0..1 (Rime Shell's cracks).
func absorb_fraction(id: String) -> float:
	if not absorbs.has(id):
		return 0.0
	return clampf(float(absorbs[id]["amount"]) / float(maxi(int(absorbs[id].get("full", 1)), 1)), 0.0, 1.0)

## Shield health left on `source`'s copy of effect `id` (0 = none, or it already
## broke). Works on a mirrored copy too (a party member's machine only knows the
## number the host sent: enemy.net_apply_status).
func shield_from(id: String, source: Node) -> int:
	for k in _keys_of(id):
		if not applied_by(effects[k], source):
			continue
		if absorbs.has(k):
			return int(absorbs[k]["amount"])
		return int(effects[k].get("net_absorb", 0))
	return 0

## Shield health left on effect `id` (0 = none).
func absorb_left(id: String) -> int:
	return int(absorbs[id]["amount"]) if absorbs.has(id) else 0

## Total shield health on this character.
func total_absorb() -> int:
	var n := 0
	for k in absorbs:
		n += int(absorbs[k]["amount"])
	return n

## Soak `dmg` with shields. Returns the damage that gets through. Shields
## that run out end their effect and break (on_break).
func absorb_damage(dmg: int) -> int:
	if absorbs.is_empty() or dmg <= 0:
		return dmg
	var broken: Array = []
	var shared: Array = []   # [id, billed, source]
	for k in absorbs.keys():
		if dmg <= 0:
			break
		var a: Dictionary = absorbs[k]
		var n := share_of(str(k))
		# A linked shell can soak n times its own shield: it pays 1/n, the others the rest.
		var soak := mini(int(a["amount"]) * n, dmg)
		var own := soak if n <= 1 else int(ceil(float(soak) / n))
		a["amount"] = int(a["amount"]) - own
		dmg -= soak
		if soak - own > 0:
			var src: Variant = effects[k].get("source") if effects.has(k) else null
			shared.append([str(k), soak - own, src if src != null and is_instance_valid(src) else null])
		if int(a["amount"]) <= 0:
			broken.append(k)
	for k in broken:
		last_shield_source = effects[k].get("source") if effects.has(k) else null
		break_absorb(str(k), false)
		shield_broken.emit(str(k))
	if broken.is_empty():
		changed.emit()
	for sh in shared:
		shield_shared.emit(sh[0], sh[1], sh[2])
	return dmg

## End the shield of effect `id` now, and the effect with it unless the shield
## was set to keep it (set_absorb's keep_effect). `silent` = don't run on_break.
## Returns true if there was a shield.
func break_absorb(id: String, silent: bool = false) -> bool:
	if not absorbs.has(id):
		return false
	var cb: Callable = absorbs[id]["on_break"]
	var keep := bool(absorbs[id].get("keep", false))
	absorbs.erase(id)
	if keep and effects.has(id):
		effects[id].erase("net_absorb")
	else:
		effects.erase(id)
	changed.emit()
	if not silent and cb.is_valid():
		cb.call()
	return true

## Any copy of effect `id` active (from any caster)?
func has(id: String) -> bool:
	return not _keys_of(id).is_empty()

## Is effect `id` applied by `source` active? This is the "own only" check:
## talents and abilities that react to an effect ask this, never has().
func has_from(id: String, source: Node) -> bool:
	for k in _keys_of(id):
		if applied_by(effects[k], source):
			return true
	return false

## Is a root, hold or slow applied by `source` active here? (Own only: Undergrowth.)
func has_cc_from(source: Node) -> bool:
	for k in effects:
		var e: Dictionary = effects[k]
		var res: Resource = e["res"]
		if (res.root or float(res.stat_modifiers.get("move_speed", 0.0)) < 0.0) and applied_by(e, source):
			return true
	return false

## Is any damage-over-time effect applied by `source` active here? (Own only:
## Feed the Flames.) One that ticks by itself (tick_damage), or one tagged "DoT"
## whose damage its caster deals (Decay).
func has_dot_from(source: Node) -> bool:
	for e in effects.values():
		if (float(e["res"].tick_damage) > 0.0 or e["res"].tags.has("DoT")) and applied_by(e, source):
			return true
	return false

## Instance ids of everyone who has a damage-over-time effect on this character
## right now ({instance id: true}). An enemy notes it as it dies, before its
## effects are cleared (Carrion).
func dot_owner_ids() -> Dictionary:
	var out := {}
	for e in effects.values():
		if float(e["res"].tick_damage) <= 0.0 and not e["res"].tags.has("DoT"):
			continue
		var src: Variant = e.get("source")
		if src != null and is_instance_valid(src):
			out[(src as Node).get_instance_id()] = true
	return out

## Did `source` put effect entry `e` there? True for its latest caster, and for
## anyone else whose own application of it would still be running.
func applied_by(e: Dictionary, source: Node) -> bool:
	return own_expires(e, source) > 0.0

## When `source`'s own application of effect entry `e` runs out (0 if it isn't
## theirs). An ally refreshing a shared effect doesn't move this.
func own_expires(e: Dictionary, source: Node) -> float:
	if source == null or not is_instance_valid(source):
		return 0.0
	var by: Dictionary = e.get("by", {})
	var mine := float(by.get(source.get_instance_id(), 0.0))
	if mine > _now():
		return mine
	return float(e["expires"]) if is_same(e.get("source"), source) else 0.0

## Make `source`'s copy of effect `id` run out right now (next frame), so an
## effect that bursts when it expires (Hoarfrost) bursts early. Returns true if
## there was one.
func expire_now(id: String, source: Node = null) -> bool:
	var found := false
	for k in _keys_of(id):
		if source == null or effects[k]["source"] == source:
			effects[k]["expires"] = 0.0
			found = true
	return found

## Deal the burst of `source`'s copy of effect `id` right now WITHOUT ending it
## (Brittle Rime): the effect keeps ticking and still bursts when it runs out.
## Mirrored effects on a party member's machine never deal damage. Returns true
## if anything burst.
func burst_now(id: String, source: Node = null) -> bool:
	var cs := get_node_or_null("/root/CombatSystem")
	if cs == null:
		return false
	var did := false
	for k in _keys_of(id):
		var e: Dictionary = effects[k]
		if source != null and e["source"] != source:
			continue
		var er = e["res"].get("expire_damage")
		if er == null or float(er) <= 0.0 or float(e.get("next_tick", 0.0)) == INF or owned_elsewhere(e):
			continue
		cs.deal_burst(e["source"], get_parent(), float(er) * int(e["stacks"]), str(e["res"].damage_type),
			str(e["res"].id), e.get("tags", PackedStringArray()), float(e.get("unit", -1.0)))
		did = true
	return did

## Sum of a stat modifier across active effects (per stack). Percent
## modifiers use the "<stat>%" key, e.g. stat_mod("intellect%").
func stat_mod(stat: String) -> float:
	var total := 0.0
	# Slows on a carrier with slow resistance (Glacial Heart) are weaker.
	var slow_taken := 1.0
	if stat == "move_speed" and not effects.is_empty():
		var carrier := get_parent()
		if carrier and carrier.has_method("slow_taken_mult"):
			slow_taken = float(carrier.slow_taken_mult())
	for e in effects.values():
		var mods: Dictionary = e["res"].stat_modifiers
		if mods.has(stat):
			var v := float(mods[stat]) * int(e["stacks"])
			if stat == "move_speed" and v < 0.0:
				v *= float(e.get("slow_mult", 1.0)) * slow_taken
			total += v
	return total

## Set the stacks of effect `id` without touching its duration (Slow Fuse
## growing). Returns true if it was active.
func set_stacks(id: String, stacks: int) -> bool:
	var keys := _keys_of(id)
	for k in keys:
		effects[k]["stacks"] = clampi(stacks, 1, maxi(int(effects[k]["res"].max_stacks), 1))
	if not keys.is_empty():
		changed.emit()
	return not keys.is_empty()

## set_stacks for `source`'s own copy only (per-caster effects).
func set_stacks_from(id: String, source: Node, stacks: int) -> bool:
	var found := false
	for k in _keys_of(id):
		if effects[k]["source"] == source:
			effects[k]["stacks"] = clampi(stacks, 1, maxi(int(effects[k]["res"].max_stacks), 1))
			found = true
	if found:
		changed.emit()
	return found

## Stacks of an active effect (0 if not active; the highest copy for per-caster DoTs).
func stacks_of(id: String) -> int:
	var best := 0
	for k in _keys_of(id):
		best = maxi(best, int(effects[k]["stacks"]))
	return best

## Remove only `source`'s copy of effect `id` (per-caster DoTs). Returns true
## if there was one.
func remove_from(id: String, source: Node) -> bool:
	var found := false
	for k in _keys_of(id):
		if effects[k]["source"] == source:
			effects.erase(k)
			absorbs.erase(k)
			suppress(str(k))
			found = true
	if found:
		changed.emit()
	return found

## Seconds between ticks of DoT entry `e` on this target right now: its hasted
## interval, made shorter if its caster speeds up their own burns here
## (Pitch Arrow: caster.dot_speed_mult(target, effect) -> 1.25 = 25% faster).
func tick_interval_of(e: Dictionary) -> float:
	var tick := maxf(float(e.get("tick", e["res"].tick_interval)), 0.05)
	var src: Variant = e.get("source")
	if src != null and is_instance_valid(src) and src.has_method("dot_speed_mult"):
		tick /= maxf(float(src.dot_speed_mult(get_parent(), e["res"])), 0.1)
	return maxf(tick, 0.05)

## Damage `source`'s copy of DoT `id` still has to deal, as a coefficient:
## ticks left x tick damage x stacks (0 if it has none).
func dot_left(id: String, source: Node) -> float:
	var total := 0.0
	var now := _now()
	for k in _keys_of(id):
		var e: Dictionary = effects[k]
		if e["source"] != source:
			continue
		var per := float(e["res"].tick_damage) * int(e["stacks"])
		if per <= 0.0:
			continue
		var tick := tick_interval_of(e)
		var next := float(e.get("next_tick", INF))
		var end := float(e["expires"])
		var ticks := 0
		if next == INF:   # mirrored on a party member's machine: no tick timer here
			ticks = int(floor(maxf(end - now, 0.0) / tick + 0.001))
		elif next <= end + 0.001:
			ticks = int(floor((end - next) / tick + 0.001)) + 1
		total += per * ticks
	return total

## Take `n` stacks off effect `id`; it ends when none are left. Returns true
## if the effect was active.
func spend_stacks(id: String, n: int = 1) -> bool:
	var keys := _keys_of(id)
	for k in keys:
		var left := int(effects[k]["stacks"]) - n
		if left <= 0:
			effects.erase(k)
			absorbs.erase(k)
		else:
			effects[k]["stacks"] = left
	if not keys.is_empty():
		changed.emit()
	return not keys.is_empty()

## Seconds left on effect `id` (0 if not active; the longest copy for per-caster DoTs).
func remaining_of(id: String) -> float:
	var best := 0.0
	for k in _keys_of(id):
		best = maxf(best, float(effects[k]["expires"]) - _now())
	return best

## Make effect `id` run out `seconds` from now. Returns true if it was active.
func set_remaining(id: String, seconds: float) -> bool:
	var keys := _keys_of(id)
	for k in keys:
		effects[k]["expires"] = _now() + maxf(seconds, 0.0)
	if not keys.is_empty():
		changed.emit()
	return not keys.is_empty()

## Seconds left on `source`'s own copy of effect `id` (0 if it has none).
func remaining_from(id: String, source: Node) -> float:
	for k in _keys_of(id):
		if effects[k]["source"] == source:
			return maxf(float(effects[k]["expires"]) - _now(), 0.0)
	return 0.0

## Make `source`'s own copy of effect `id` run out `seconds` from now, without
## touching its tick timer (Fresh Tinder feeding an Immolate). `hold` = seconds
## a party member's machine keeps this clock before the host's copy may correct
## it (the host is told at the same moment). Returns true if there was one.
func set_remaining_from(id: String, source: Node, seconds: float, hold: float = 0.0) -> bool:
	var found := false
	for k in _keys_of(id):
		if effects[k]["source"] == source:
			effects[k]["expires"] = _now() + maxf(seconds, 0.0)
			if hold > 0.0:
				effects[k]["clock_hold"] = _now() + hold
			found = true
	if found:
		changed.emit()
	return found

## Any active effect carrying this tag (e.g. "Fire", "DoT")?
func has_tag(tag: String) -> bool:
	for e in effects.values():
		if e["res"].tags.has(tag):
			return true
	return false

# --- Damage modifiers ------------------------------------------------------------
# CombatSystem calls this for the attacker (incoming = false) and the target
# (incoming = true) of every hit, after the crit roll. Matching effects add
# their percent to the DamageInfo; "consume on use" ones are removed at the end
# of the frame, so all hits of one AoE cast share a single consumption.

var _consume_queue := {}   # effect id -> true (removed at end of frame)

func collect_damage_mods(info: RefCounted, incoming: bool) -> void:
	if float(info.base) <= 0.0:
		return   # an effect-only hit (Immolate, Hoarfrost...) has no damage to boost: it uses nothing up
	var carrier := get_parent()
	for id in effects:
		var e: Dictionary = effects[id]
		var res: Resource = e["res"]
		if bool(res.modifies_incoming) != incoming:
			continue
		if not res.modifies(info.damage_type, info.tags, info.is_dot, info.crit):
			continue
		if res.consume_on_use and bool(info.get("no_empower")):
			continue   # passive damage never spends a "your next ..." buff
		var stacks := int(e["stacks"])
		var label: String = res.display_name + (" x%d" % stacks if stacks > 1 else "")
		# "crit_chance" means this hit's real crit chance (incl. Spell Critical Strike for spells).
		var per_stack: float = res.mod_pct_per_stack(func(s):
			if s == Stats.CRIT:
				return Stats.crit_chance(info.tags, func(x): return _stat_of(carrier, x))
			return _stat_of(carrier, s))
		info.add_bonus(per_stack * stacks, label)
		if res.consume_on_use and not _consume_queue.has(id):
			if _consume_queue.is_empty():
				_flush_consumed.call_deferred()
			_consume_queue[id] = true

## A "consume on use" effect was used: it ends, unless its carrier keeps some
## of the stacks (stacks_kept_on_use(res, stacks) -> int; nothing uses it right now).
func _use_up(id: String) -> void:
	var e: Dictionary = effects[id]
	var stacks := int(e["stacks"])
	var keep := 0
	var carrier := get_parent()
	if carrier and carrier.has_method("stacks_kept_on_use"):
		keep = clampi(int(carrier.stacks_kept_on_use(e["res"], stacks)), 0, stacks)
	if keep > 0:
		e["stacks"] = keep
	else:
		effects.erase(id)

func _flush_consumed() -> void:
	if _consume_queue.is_empty():
		return
	var bus := get_node_or_null("/root/SignalBus") if is_inside_tree() else null
	for id in _consume_queue:
		if effects.has(id):
			var e: Dictionary = effects[id]
			var spent := int(e["stacks"])
			_use_up(str(id))
			if bus:
				bus.status_consumed.emit(get_parent(), str(id), e["res"].display_name, spent)
	_consume_queue.clear()
	changed.emit()

## "stun" / "root": any active effect with that crowd-control flag.
func has_flag(flag: String) -> bool:
	for e in effects.values():
		if flag == "stun" and e["res"].stun:
			return true
		if flag == "root" and (e["res"].root or e["res"].stun):
			return true
	return false

## For UI: [{id, name, color, stacks, remaining, debuff, desc}]
## `amount`: the stack count is an amount of damage (Decay), `timeless`: it has
## no clock to show (a closed Decay), `mine`: this machine's player applied it.
func list() -> Array:
	var now := _now()
	var out := []
	for id in effects:
		var e: Dictionary = effects[id]
		var src: Variant = e.get("source")
		out.append({"id": str(e["res"].id), "name": e["res"].display_name, "color": e["res"].color,
			"stacks": e["stacks"], "remaining": max(float(e["expires"]) - now, 0.0),
			"debuff": e["res"].is_debuff, "desc": TextFill.effect(e["res"], float(e.get("slow_mult", 1.0))),
			"mods": e["res"].stat_modifiers, "absorb": absorb_left(id), "icon": e["res"].icon,
			"amount": e["res"].get("stacks_are_amount") == true, "timeless": e["res"].get("show_time") == false,
			"mine": src != null and is_instance_valid(src) and (src as Node).is_in_group("player")})
	return out

## Build a simple runtime buff (used by rune procs). `stat` may be a percent
## key like "intellect%".
static func make_buff(id: String, display_name: String, stat: String, amount: float,
		duration: float, max_stacks: int, color: Color) -> Resource:
	var r := StatusEffectScript.new()
	r.id = StringName(id)
	r.display_name = display_name
	r.color = color
	r.duration = duration
	r.max_stacks = max(max_stacks, 1)
	r.stack_mode = 1 if max_stacks > 1 else 0
	r.stat_modifiers = {stat: amount}
	return r

func _process(_delta: float) -> void:
	if effects.is_empty():
		set_process(false)
		return
	var now := _now()
	var expired: Array = []
	for id in effects:
		var e: Dictionary = effects[id]
		var res: Resource = e["res"]
		# Damage over time
		if res.tick_damage > 0 and now >= float(e["next_tick"]):
			e["next_tick"] = now + tick_interval_of(e)
			var cs := get_node_or_null("/root/CombatSystem")
			if cs and not owned_elsewhere(e):   # a party member's DoT ticks on their machine
				cs.deal_dot(e["source"], get_parent(), float(res.tick_damage) * int(e["stacks"]), str(res.damage_type),
					str(res.id), e.get("tags", PackedStringArray()), res, float(e.get("unit", -1.0)))
		if now >= float(e["expires"]):
			expired.append(id)
	var bursts: Array = []
	var last_ticks: Array = []   # [effect entry, % of a tick]: dealt below, once the effects are gone
	var roots_ended: Array = []  # [caster, effect]: roots and holds that ran out (told below: Clinging Vines)
	var shields_out: Array = []   # [id, left, source]: shields that ran out of time (told below)
	for id in expired:
		var e: Dictionary = effects[id]
		if absorbs.has(id) and int(absorbs[id]["amount"]) > 0 and float(e["expires"]) > 0.0:
			var ssrc: Variant = e.get("source")
			shields_out.append([str(id), int(absorbs[id]["amount"]), ssrc if ssrc != null and is_instance_valid(ssrc) else null])
		var er = e["res"].get("expire_damage")
		if er != null and float(er) > 0.0:
			bursts.append([e, float(er)])
		# A damage-over-time effect that ran its full time (not one ended early:
		# expire_now sets "expires" to 0) may tick once more, for a share of a tick,
		# if its caster says so (source.dot_last_tick_pct(res): Last Ember). The
		# caster's machine deals it, like every tick.
		if float(e["res"].tick_damage) > 0.0 and float(e["expires"]) > 0.0 and not owned_elsewhere(e) \
				and float(e.get("next_tick", 0.0)) != INF:
			var src: Variant = e.get("source")
			if src != null and is_instance_valid(src) and (src as Node).has_method("dot_last_tick_pct"):
				var last_pct := float(src.dot_last_tick_pct(e["res"]))
				if last_pct > 0.0:
					last_ticks.append([e, last_pct])
		# A root or hold ran out: its caster may want to know (source.root_ended:
		# Clinging Vines). Their own machine is told, never a mirrored copy's.
		if e["res"].root and not e["res"].stun and not owned_elsewhere(e):
			var rsrc: Variant = e.get("source")
			if rsrc != null and is_instance_valid(rsrc) and (rsrc as Node).has_method("root_ended"):
				roots_ended.append([rsrc, e["res"]])
		effects.erase(id)
		absorbs.erase(id)
		suppress(str(id))   # ended here: a late snapshot from the host must not restart it
	# Effects that burst when they run out (Hoarfrost). The caster's machine
	# deals it (mirrored copies and other players' effects never do).
	for b in bursts:
		var e: Dictionary = b[0]
		if float(e.get("next_tick", 0.0)) == INF or owned_elsewhere(e):
			continue
		var cs := get_node_or_null("/root/CombatSystem")
		if cs:
			cs.deal_burst(e["source"], get_parent(), float(b[1]) * int(e["stacks"]), str(e["res"].damage_type),
				str(e["res"].id), e.get("tags", PackedStringArray()), float(e.get("unit", -1.0)))
	for t in last_ticks:
		var e: Dictionary = t[0]
		var cs := get_node_or_null("/root/CombatSystem")
		if cs and is_instance_valid(e.get("source")):
			cs.deal_dot(e["source"], get_parent(), float(e["res"].tick_damage) * int(e["stacks"]) * float(t[1]) / 100.0,
				str(e["res"].damage_type), str(e["res"].id), e.get("tags", PackedStringArray()), e["res"],
				float(e.get("unit", -1.0)))
	for r in roots_ended:
		if is_instance_valid(r[0]):
			r[0].root_ended(get_parent(), r[1])
	for so in shields_out:
		shield_expired.emit(so[0], so[1], so[2])
	if not expired.is_empty():
		changed.emit()
