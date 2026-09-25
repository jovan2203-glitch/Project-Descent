extends Node

# Unified combat pipeline (autoload "CombatSystem").
# ALL damage and healing — player and enemies — goes through here:
#   deal(info) : crit roll -> Spell/Attack Power -> % modifiers -> crit x2 ->
#                block (armor) -> resistance ->
#                apply HP -> on-hit status effects -> threat -> floating text ->
#                SignalBus events (damage_dealt, player_hit, ...)
#   heal(source, target, amount) : restores HP and generates threat.
#
# A combatant needs: is_alive(), take_damage(int) (final HP change), and
# optionally get_stat(name), get_node("Status") (StatusContainer),
# add_threat(source, amount), receive_heal(int).

const DamageInfo = preload("res://scripts/core/damage_info.gd")
const Abilities = preload("res://scripts/abilities.gd")
const Stats = preload("res://scripts/core/stats.gd")

const CRIT_MULTIPLIER := 2
const BLOCK_PER_ARMOR := 5.0    # % block chance per armor point
const MAX_BLOCK := 60.0
const HEAL_THREAT := 0.5        # threat per point healed

func _bus() -> Node:
	return get_node("/root/SignalBus")

func _stat(node: Node, stat: String) -> float:
	return float(node.get_stat(stat)) if node and is_instance_valid(node) and node.has_method("get_stat") else 0.0

func _alive(node: Node) -> bool:
	return node != null and is_instance_valid(node) and (not node.has_method("is_alive") or node.is_alive())

# Convenience: build a DamageInfo for an ability id using its AbilityData
# (tags, damage type, on-hit effect).
## `damage_type` / `tags` override the ability's own (used by rune and item
## effect hits, which have no AbilityData).
func ability_hit(source: Node, target: Node, base: int, ability_id: String, is_proc := false,
		damage_type: String = "", tags: PackedStringArray = PackedStringArray()) -> RefCounted:
	var info := DamageInfo.make(source, target, base, ability_id)
	var res := Abilities.get_resource(ability_id)
	if res:
		info.tags = res.tags
		info.damage_type = str(res.damage_type)
		if res.on_hit_effect:
			info.effects.append(res.on_hit_effect)
	if damage_type != "":
		info.damage_type = damage_type
	if not tags.is_empty():
		info.tags = tags
	info.is_proc = is_proc
	return deal(info)

func deal(info: RefCounted) -> RefCounted:
	var src: Node = info.source
	var tgt: Node = info.target
	if not _alive(tgt):
		return info
	if info.tags.is_empty() and info.ability_id != "":
		info.tags = Abilities.tags_of(info.ability_id)
	var src_ok: bool = _alive(src)
	# 1. Crit is rolled first so crit-only modifiers can see it.
	var roll_crit := randf() * 100.0
	var crit_chance := Stats.crit_chance(info.tags, func(s): return _stat(src, s)) if src_ok else 0.0
	var can_crit: bool = info.can_crit and src_ok
	info.crit = can_crit and roll_crit < crit_chance
	# 2. Spell Power / Attack Power (60/20 for spells, 20/60 for abilities;
	#    DoT ticks get a share of it).
	var power := 0.0
	if info.add_power and src_ok and src.has_method("get_stat"):
		power = Stats.power_bonus(info.tags, func(s): return _stat(src, s)) * info.power_share
	# 3. Percent modifiers: attacker's buffs (outgoing), target's debuffs
	#    (incoming), then anything listening on SignalBus.damage_modify.
	_collect_mods(src, info, false)
	_collect_mods(tgt, info, true)
	_bus().damage_modify.emit(info)
	# 4. Maths: base + power, x modifiers, crit, block, resistance (compute_damage()).
	var r := compute_damage(
		info.base, power, crit_chance, _stat(tgt, Stats.ARMOR),
		_stat(tgt, "resist_" + info.damage_type),
		roll_crit, randf() * 100.0,
		can_crit, info.can_block and not info.is_dot,
		1.0 + info.bonus_pct / 100.0, randf())
	var dmg: int = r["amount"]
	info.crit = r["crit"]
	info.blocked = r["blocked"]
	info.amount = dmg

	# Multiplayer: a party member (not the host) never changes an enemy's HP
	# itself. It shows its own hit and reports it to the host, which applies
	# the damage, on-hit effects and threat.
	var net := get_node_or_null("/root/Net")
	if net and net.is_client() and tgt.is_in_group("enemies"):
		if info.blocked:
			float_text(tgt, "Block", Color(0.7, 0.85, 1.0), false)
		elif dmg > 0:
			var c := Color(0.6, 0.9, 1.0) if info.is_dot else (Color(1, 0.85, 0.2) if info.crit else Color.WHITE)
			float_text(tgt, str(dmg) + ("!" if info.crit else ""), c, info.crit)
		if _alive(src) and src.is_in_group("player"):
			net.report_enemy_damage(tgt, dmg, info.ability_id, info.threat_multiplier, info.effects)
		_bus().damage_dealt.emit(info)
		if src and is_instance_valid(src) and src.is_in_group("player") and not info.blocked:
			_bus().player_hit.emit(info.ability_id, tgt, dmg, info.crit, info.is_proc)
		return info

	# 5. Apply
	var tgt_is_player := tgt.is_in_group("player")
	if info.blocked:
		float_text(tgt, "Block", Color(0.7, 0.85, 1.0), false)
		if tgt_is_player:
			_bus().player_blocked.emit()
	elif dmg > 0:
		var col := Color(1, 0.35, 0.3) if tgt_is_player else (Color(1, 0.85, 0.2) if info.crit else Color.WHITE)
		if info.is_dot:
			col = Color(0.6, 0.9, 1.0)
		float_text(tgt, str(dmg) + ("!" if info.crit else ""), col, info.crit)
		tgt.take_damage(dmg)
	# 6. On-hit status effects (even a blocked hit can still chill? no: only on damage)
	if not info.blocked:
		var status: Node = tgt.get_node_or_null("Status") if is_instance_valid(tgt) else null
		if status:
			for eff in info.effects:
				status.apply(eff, src, info.tags)
	# 7. Threat
	if is_instance_valid(tgt) and tgt.has_method("add_threat") and _alive(src):
		tgt.add_threat(src, max(dmg, 1) * info.threat_multiplier)
	# 8. Events
	_bus().damage_dealt.emit(info)
	if src and is_instance_valid(src) and src.is_in_group("player") and not info.blocked:
		_bus().player_hit.emit(info.ability_id, tgt, dmg, info.crit, info.is_proc)
	return info

func _collect_mods(who: Node, info: RefCounted, incoming: bool) -> void:
	if who == null or not is_instance_valid(who):
		return
	var status: Node = who.get_node_or_null("Status")
	if status and status.has_method("collect_damage_mods"):
		status.collect_damage_mods(info, incoming)

## Pure damage maths (no randomness inside: pass rolls in 0..100), used by deal()
## and by the automated tests.
## Order: + bonus (power) -> x multiplier (percent modifiers) -> crit x2 -> armor block -> resist.
## `roll_round` (0..1) rounds fractional damage: floor(x + roll). A random roll
## makes small numbers fair on average (2.4 -> 3 on 40% of hits); the default
## 0.5 is normal rounding.
static func compute_damage(base: int, bonus: float, crit_chance: float, armor: float, resist: float,
		roll_crit: float, roll_block: float, can_crit: bool = true, can_block: bool = true,
		multiplier: float = 1.0, roll_round: float = 0.5) -> Dictionary:
	var raw := maxf(float(base) + bonus, 0.0) * maxf(multiplier, 0.0)
	var dmg := maxi(int(floor(raw + roll_round)), 0) if raw > 0.0 else 0
	var crit := can_crit and roll_crit < crit_chance
	if crit:
		dmg *= CRIT_MULTIPLIER
	var block_chance := minf(armor * BLOCK_PER_ARMOR, MAX_BLOCK)
	var blocked := can_block and block_chance > 0.0 and roll_block < block_chance
	if blocked:
		dmg = 0
	var res := clampf(resist, -100.0, 90.0)
	if res != 0.0 and dmg > 0:
		dmg = maxi(int(round(dmg * (1.0 - res / 100.0))), 1)
	return {"amount": dmg, "crit": crit, "blocked": blocked}

# Damage-over-time tick from a status effect. DoTs crit and scale with a
# share of power unless the effect says otherwise (dot_can_crit / dot_power_share).
# `tags` = tags of the spell/ability that applied it (so a Fireball burn is a
# Spell tick and a Searing Strike burn an Ability tick).
func deal_dot(source: Node, target: Node, amount: int, damage_type: String, effect_id: String,
		tags: PackedStringArray = PackedStringArray(), res: Resource = null) -> void:
	var info := DamageInfo.make(source if is_instance_valid(source) else null, target, amount, "dot_" + effect_id)
	info.is_dot = true
	info.can_block = false
	info.damage_type = damage_type
	var t := PackedStringArray(tags)
	if not t.has("DoT"):
		t.append("DoT")
	info.tags = t
	info.can_crit = res == null or bool(res.dot_can_crit)
	var share := float(res.dot_power_share) if res else -1.0
	info.power_share = Stats.DOT_POWER_SHARE if share < 0.0 else share
	deal(info)

# Healing: restores HP and adds threat on every enemy fighting the healed target.
# With `ability_id`, the heal scales with the source's Spell / Attack Power like
# a hit from that spell / ability would.
func heal(source: Node, target: Node, amount: int, ability_id: String = "") -> void:
	if not _alive(target) or amount <= 0:
		return
	if ability_id != "" and _alive(source) and source.has_method("get_stat"):
		var p := Stats.power_bonus(Abilities.tags_of(ability_id), func(s): return _stat(source, s))
		amount = int(floor(amount + p + randf()))
	if target.has_method("receive_heal"):
		target.receive_heal(amount)
	float_text(target, "+%d" % amount, Color(0.45, 1.0, 0.45), false)
	_bus().healed.emit(source, target, amount)
	if _alive(source):
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.has_method("is_fighting") and e.is_fighting(target):
				e.add_threat(source, amount * HEAL_THREAT)

func float_text(at: Node, text: String, color: Color, big: bool) -> void:
	if not (at is Node3D) or not is_instance_valid(at):
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	# Damage numbers are pooled (reused Label3Ds).
	var pool := get_node_or_null("/root/Pool")
	var l: Label3D = pool.acquire("float_text", _new_float_label) if pool else _new_float_label()
	l.text = text
	l.font_size = 64 if big else 44
	l.modulate = color
	scene.add_child(l)
	l.global_position = (at as Node3D).global_position + Vector3(randf_range(-0.3, 0.3), 1.5, 0)
	var t := l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "global_position:y", l.global_position.y + 0.9, 0.8)
	t.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	if pool:
		t.chain().tween_callback(pool.release.bind(l))
	else:
		t.chain().tween_callback(l.queue_free)

func _new_float_label() -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.006
	l.outline_size = 12
	return l
