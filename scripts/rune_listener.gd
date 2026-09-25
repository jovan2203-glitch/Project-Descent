extends Node

# Broad rune listener ("combat engine" side of runes AND item effects).
# Added as a child of the player. It:
#   1. scans equipped gear for runes and item "Equip:" effects and registers
#      each one's trigger criteria (re-scans whenever equipment changes);
#   2. listens to combat events on the SignalBus (hits, casts, kills, damage taken,
#      health) plus a periodic timer;
#   3. tracks each entry's condition (chance, every-Nth, N-in-a-row with tag and
#      crit filters, health threshold, interval) and an internal cooldown;
#   4. fires the effect: stat buff, instant free cast, bonus damage, heal,
#      status, or damage to everything around you.
# Item "Use:" effects (trinkets) are fired by use_item_effect().
#
# Item effects never count toward rune limits, and their amounts scale with
# the item's level (Items.stat_scale), like the item's stats.

const Items = preload("res://scripts/items.gd")
const Runes = preload("res://scripts/runes.gd")
const Abilities = preload("res://scripts/abilities.gd")

# RuneData enums (mirrored so this works even before class_names are registered).
enum Trigger { ON_HIT, ON_CAST, ON_KILL, ON_DAMAGE_TAKEN, ON_LOW_HEALTH, PERIODIC }
enum ThresholdMode { CHANCE, COUNT, CONSECUTIVE, HEALTH_FRACTION, SECONDS }
enum Effect { STAT_BUFF, INSTANT_CAST, BONUS_DAMAGE, HEAL, APPLY_STATUS, AOE_DAMAGE }
enum StatusTarget { SELF, TARGET, PARTY }

var player: Node   # the player (parent)

# Registered entries: key -> {res, counter, cooldown_until, timer, was_low, scale, item_name}
#   runes:        "<slot>:<rune id>"
#   item effects: "<slot>:item:<effect id>"
var active := {}
# "Use:" cooldowns per item instance id -> time it's ready again (seconds).
var use_ready_at := {}

func _ready() -> void:
	player = get_parent()
	var bus := get_node("/root/SignalBus")
	bus.damage_dealt.connect(_on_damage_dealt)
	bus.cast_finished.connect(_on_cast_finished)
	bus.enemy_died.connect(_on_enemy_died)
	bus.player_damaged.connect(_on_player_damaged)
	bus.player_health_changed.connect(_on_health_changed)
	get_node("/root/PlayerData").changed.connect(rescan)
	rescan()

# 1. Scan equipped gear and (re)register runes + item effects, keeping counters
# for ones that are still equipped.
func rescan() -> void:
	var pd := get_node("/root/PlayerData")
	var fresh := {}
	var counted := []   # runes activated so far (limits: 1 legendary, 4 epics, copies)
	for slot in pd.equipment:
		var item: String = pd.equipment[slot]
		# Built-in item effect (never limited).
		var eq: Resource = Items.equip_effect_of(item)
		if eq:
			var ikey := "%s:item:%s" % [slot, str(eq.id)]
			fresh[ikey] = active[ikey] if active.has(ikey) else _entry(eq, Items.effect_scale(item), Items.item_name(item))
		# Rune.
		var eid := Items.rune_of(item)
		if eid == "":
			continue
		var res := Runes.get_resource(eid)
		if res == null:
			continue
		if Runes.check_limits(counted + [eid]) != "":
			continue   # over the limit (e.g. an old save): this copy stays inactive
		counted.append(eid)
		var key := "%s:%s" % [slot, eid]
		fresh[key] = active[key] if active.has(key) else _entry(res, 1.0, "")
	active = fresh

func _entry(res: Resource, scale: float, item_name: String) -> Dictionary:
	return {"res": res, "counter": 0, "cooldown_until": 0.0, "timer": 0.0, "was_low": false,
		"scale": scale, "item_name": item_name}

func registered_runes() -> Array:
	return active.values().map(func(e): return e["res"].id)

# --- 2. Events -----------------------------------------------------------------------

# Every damage event; only hits dealt by THIS player (not blocked) count.
func _on_damage_dealt(info: RefCounted) -> void:
	if info.source != player or info.blocked:
		return
	var tags: PackedStringArray = info.tags if not info.tags.is_empty() else Abilities.tags_of(str(info.ability_id))
	var target: Node = info.target
	var crit: bool = info.crit
	for e in active.values():
		var res: Resource = e["res"]
		if res.trigger != Trigger.ON_HIT:
			continue
		if info.is_dot and not res.include_dots:
			continue
		if info.is_proc and not res.include_procs:
			continue   # proc hits (runes, chain jumps, splash) only feed runes that opt in
		if not res.applies_to_tags(tags) or not res.applies_to_damage_type(str(info.damage_type)) \
				or not res.applies_to_ability(str(info.ability_id)):
			continue   # non-matching hits neither count nor break a streak
		if (res.require_crit and not crit) or (res.require_non_crit and crit):
			if res.threshold_mode == ThresholdMode.CONSECUTIVE:
				e["counter"] = 0   # streak broken
			continue
		if _condition_met(e):
			_fire(e, target)

func _on_cast_finished(ability_id: String) -> void:
	var tags := Abilities.tags_of(ability_id)
	for e in active.values():
		var res: Resource = e["res"]
		if res.trigger == Trigger.ON_CAST and res.applies_to_tags(tags) \
				and res.applies_to_ability(ability_id) and _condition_met(e):
			_fire(e, _current_target())

func _on_enemy_died(_enemy: Node) -> void:
	for e in active.values():
		if e["res"].trigger == Trigger.ON_KILL and _condition_met(e):
			_fire(e, _current_target())

func _on_player_damaged(_amount: int) -> void:
	for e in active.values():
		if e["res"].trigger == Trigger.ON_DAMAGE_TAKEN and _condition_met(e):
			_fire(e, _current_target())

func _on_health_changed(current: int, maximum: int) -> void:
	var frac: float = float(current) / float(max(maximum, 1))
	for e in active.values():
		var res: Resource = e["res"]
		if res.trigger != Trigger.ON_LOW_HEALTH:
			continue
		var low: bool = frac <= float(res.threshold)
		if low and not e["was_low"] and _off_cooldown(e):
			_fire(e, _current_target())
		e["was_low"] = low

func _process(delta: float) -> void:
	for e in active.values():
		var res: Resource = e["res"]
		if res.trigger != Trigger.PERIODIC:
			continue
		e["timer"] += delta
		if e["timer"] >= max(res.threshold, 0.1):
			e["timer"] = 0.0
			if _off_cooldown(e):
				_fire(e, _current_target())

# --- 3. Condition tracking ---------------------------------------------------------

static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _off_cooldown(e: Dictionary) -> bool:
	return _now() >= float(e["cooldown_until"])

func _condition_met(e: Dictionary) -> bool:
	if not _off_cooldown(e):
		return false
	var res: Resource = e["res"]
	match res.threshold_mode:
		ThresholdMode.CHANCE:
			return randf() < res.threshold
		ThresholdMode.COUNT, ThresholdMode.CONSECUTIVE:
			e["counter"] += 1
			if e["counter"] >= int(round(res.threshold)):
				e["counter"] = 0
				return true
			return false
	return true

# --- 4. Effects ------------------------------------------------------------------------

func _fire(e: Dictionary, target: Node) -> void:
	var res: Resource = e["res"]
	e["cooldown_until"] = _now() + res.internal_cooldown
	var ok := apply_effect(res, target, float(e.get("scale", 1.0)))
	if not ok:
		return
	var item_name := str(e.get("item_name", ""))
	if item_name != "":
		get_node("/root/SignalBus").rune_triggered.emit("item:" + item_name)
	else:
		get_node("/root/SignalBus").rune_triggered.emit(str(res.id))

## Run a RuneData effect. `scale` multiplies amounts (item level scaling).
## Returns false if nothing happened (e.g. a damage effect with no target).
func apply_effect(res: Resource, target: Node, scale: float = 1.0) -> bool:
	var amount := maxi(int(round(float(res.effect_amount) * scale)), 1)
	# Hit ids name the source in the combat log: "rune_frost", "item_storm_idol".
	var hit_id := ("rune_" if Runes.PATHS.has(str(res.id)) else "item_") + str(res.id)
	match int(res.effect):
		Effect.STAT_BUFF:
			player.add_buff(str(res.id), str(res.buff_stat), Items.scaled_buff(res, scale),
				res.buff_duration, res.max_stacks, str(res.display_name))
		Effect.INSTANT_CAST:
			if res.cast_ability == null or target == null:
				return false
			player.proc_cast(str(res.cast_ability.id), target)
		Effect.BONUS_DAMAGE:
			if target == null or not is_instance_valid(target):
				return false
			player.deal_damage(target, amount, hit_id, true, str(res.damage_type), res.effect_tags)
			if res.status_effect and int(res.status_target) == StatusTarget.TARGET:
				_apply_to(target, res.status_effect)
		Effect.HEAL:
			player.heal(amount)
		Effect.APPLY_STATUS:
			if res.status_effect == null:
				return false
			elif int(res.status_target) == StatusTarget.TARGET:
				if target == null:
					return false
				_apply_to(target, res.status_effect)
			else:
				_apply_to(player, res.status_effect)
				if int(res.status_target) == StatusTarget.PARTY:
					var net := get_node_or_null("/root/Net")
					if net:
						net.send_party_status(res.status_effect)
		Effect.AOE_DAMAGE:
			var r := float(res.radius)
			for enemy in player.enemies_within(r):
				player.deal_damage(enemy, amount, hit_id, true, str(res.damage_type), res.effect_tags)
				if res.status_effect:
					_apply_to(enemy, res.status_effect)
			player.ring_effect(r, res.color)
	return true

func _apply_to(who: Node, eff: Resource) -> void:
	if who and is_instance_valid(who):
		var st: Node = who.get_node_or_null("Status")
		if st:
			st.apply(eff, player)

func _current_target() -> Node:
	if player.has_method("has_valid_target") and player.has_valid_target():
		return player.target
	return null

# --- Item "Use:" effects (trinkets on the action bar) -------------------------------

## Seconds until the item's Use effect is ready (0 = ready).
func use_cooldown_left(item: String) -> float:
	return maxf(float(use_ready_at.get(item, 0.0)) - _now(), 0.0)

## Fire the "Use:" effect of the item in `slot`. Returns an error message or "".
func use_item_effect(slot: String) -> String:
	var pd := get_node("/root/PlayerData")
	var item: String = pd.equipment.get(slot, "")
	if item == "":
		return "No item equipped in %s" % slot
	var res: Resource = Items.use_effect_of(item)
	if res == null:
		return "%s has no Use effect" % Items.item_name(item)
	if use_cooldown_left(item) > 0.0:
		return "%s is not ready yet" % Items.item_name(item)
	var target := _current_target()
	if int(res.effect) in [Effect.BONUS_DAMAGE, Effect.INSTANT_CAST] and target == null:
		return "No target"
	if int(res.effect) == Effect.APPLY_STATUS and int(res.status_target) == StatusTarget.TARGET and target == null:
		return "No target"
	if not apply_effect(res, target, Items.effect_scale(item)):
		return "Nothing happened"
	use_ready_at[item] = _now() + float(res.internal_cooldown)
	get_node("/root/SignalBus").rune_triggered.emit("item:" + Items.item_name(item))
	return ""
