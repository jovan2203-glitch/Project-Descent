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

const StatusEffectScript = preload("res://scripts/data/status_effect_data.gd")
const Stats = preload("res://scripts/core/stats.gd")

# Active effects: key -> {res, stacks, expires, next_tick, tick, source, tags}
#   key  = the effect id, except for damage over time: "<id>@<source>" so each
#          caster has their own copy (two players' Burning both tick). Use
#          key_for(); has() / remove() / stacks_of() take the plain effect id.
#   tick = seconds between DoT ticks (hasted by the source when applied)
#   tags = tags of the spell/ability that applied it (DoT ticks count as that kind)
var effects := {}

## Storage key of `res` applied by `source`: DoTs are kept per caster.
static func key_for(res: Resource, source: Node) -> String:
	var id := str(res.id)
	if int(res.tick_damage) > 0 and source != null and is_instance_valid(source):
		return "%s@%d" % [id, source.get_instance_id()]
	return id

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
	var id := key_for(res, source)
	var now := _now()
	var announce := false   # new effect or new stack -> event feed
	if _consume_queue.has(id) and effects.has(id):
		# Used up earlier this frame: the new application starts fresh.
		_consume_queue.erase(id)
		effects.erase(id)
	var tick: float = maxf(float(res.tick_interval), 0.05)
	if res.tick_damage > 0 and res.dot_hasted:
		tick = maxf(tick / Stats.haste_mult(_stat_of(source, Stats.HASTE)), 0.05)
	# Re-applying your own (non-stacking) DoT: the old one is removed and a fresh
	# one starts (full duration, new tick timer, your current haste / tags).
	if effects.has(id) and res.tick_damage > 0 and int(res.stack_mode) == 0:
		effects.erase(id)
		effects[id] = {"res": res, "stacks": 1, "expires": now + res.duration,
			"next_tick": now + tick, "tick": tick, "source": source, "tags": tags}
	elif effects.has(id):
		var e: Dictionary = effects[id]
		match res.stack_mode:
			0:  # REFRESH
				e["expires"] = now + res.duration
			1:  # ADD_STACK (every new stack refreshes the duration of all stacks)
				var before := int(e["stacks"])
				e["stacks"] = mini(before + 1, max(res.max_stacks, 1))
				e["expires"] = now + res.duration
				announce = int(e["stacks"]) != before
			2:  # IGNORE
				return false
		e["source"] = source
		e["tick"] = tick
		if not tags.is_empty():
			e["tags"] = tags
	else:
		effects[id] = {"res": res, "stacks": 1, "expires": now + res.duration,
			"next_tick": now + tick, "tick": tick, "source": source, "tags": tags}
		announce = true
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
	if not keys.is_empty():
		changed.emit()

func clear() -> void:
	if not effects.is_empty():
		effects.clear()
		changed.emit()

## Any copy of effect `id` active (from any caster)?
func has(id: String) -> bool:
	return not _keys_of(id).is_empty()

## Sum of a stat modifier across active effects (per stack). Percent
## modifiers use the "<stat>%" key, e.g. stat_mod("intellect%").
func stat_mod(stat: String) -> float:
	var total := 0.0
	for e in effects.values():
		var mods: Dictionary = e["res"].stat_modifiers
		if mods.has(stat):
			total += float(mods[stat]) * int(e["stacks"])
	return total

## Stacks of an active effect (0 if not active; the highest copy for per-caster DoTs).
func stacks_of(id: String) -> int:
	var best := 0
	for k in _keys_of(id):
		best = maxi(best, int(effects[k]["stacks"]))
	return best

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
	var carrier := get_parent()
	for id in effects:
		var e: Dictionary = effects[id]
		var res: Resource = e["res"]
		if bool(res.modifies_incoming) != incoming:
			continue
		if not res.modifies(info.damage_type, info.tags, info.is_dot, info.crit):
			continue
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

func _flush_consumed() -> void:
	if _consume_queue.is_empty():
		return
	var bus := get_node_or_null("/root/SignalBus") if is_inside_tree() else null
	for id in _consume_queue:
		if effects.has(id):
			var e: Dictionary = effects[id]
			effects.erase(id)
			if bus:
				bus.status_consumed.emit(get_parent(), str(id), e["res"].display_name, int(e["stacks"]))
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
func list() -> Array:
	var now := _now()
	var out := []
	for id in effects:
		var e: Dictionary = effects[id]
		out.append({"id": str(e["res"].id), "name": e["res"].display_name, "color": e["res"].color,
			"stacks": e["stacks"], "remaining": max(float(e["expires"]) - now, 0.0),
			"debuff": e["res"].is_debuff, "desc": e["res"].description,
			"mods": e["res"].stat_modifiers})
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
			e["next_tick"] = now + float(e.get("tick", maxf(res.tick_interval, 0.05)))
			var cs := get_node_or_null("/root/CombatSystem")
			if cs:
				cs.deal_dot(e["source"], get_parent(), res.tick_damage * int(e["stacks"]), str(res.damage_type),
					str(res.id), e.get("tags", PackedStringArray()), res)
		if now >= float(e["expires"]):
			expired.append(id)
	for id in expired:
		effects.erase(id)
	if not expired.is_empty():
		changed.emit()
