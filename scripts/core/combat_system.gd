extends Node

# Unified combat pipeline (autoload "CombatSystem").
# ALL damage and healing — player and enemies — goes through here:
#   deal(info) : crit roll -> coefficient x (level hit + Spell/Attack Power) ->
#                % modifiers -> crit x2 -> block (armor) -> resistance ->
#                absorb shields -> apply HP -> on-hit status effects -> threat ->
#                floating text -> SignalBus events (damage_dealt, player_hit, ...)
#   heal(source, target, coefficient) : restores HP and generates threat.
#
# Damage / heal amounts passed in are COEFFICIENTS (1.0 = one standard hit, see
# Stats.level_hit); the source's damage_unit() (its level) and power turn them
# into real numbers.
#
# A combatant needs: is_alive(), take_damage(int) (final HP change), and
# optionally get_stat(name), get_node("Status") (StatusContainer),
# add_threat(source, amount), receive_heal(int), damage_unit(), combat_level().

const DamageInfo = preload("res://scripts/core/damage_info.gd")
const Abilities = preload("res://scripts/abilities.gd")
const Stats = preload("res://scripts/core/stats.gd")

const CRIT_MULTIPLIER := 2
const HEAL_THREAT := Stats.HEAL_THREAT

func _bus() -> Node:
	return get_node("/root/SignalBus")

func _stat(node: Node, stat: String) -> float:
	return float(node.get_stat(stat)) if node and is_instance_valid(node) and node.has_method("get_stat") else 0.0

func _alive(node: Node) -> bool:
	return node != null and is_instance_valid(node) and (not node.has_method("is_alive") or node.is_alive())

## Real damage of a 1.0 coefficient for this combatant (its level's standard hit).
static func unit_of(node: Node) -> float:
	if node != null and is_instance_valid(node) and node.has_method("damage_unit"):
		return float(node.damage_unit())
	return 1.0

## Level used for armor -> block chance.
static func level_of(node: Node) -> int:
	if node != null and is_instance_valid(node) and node.has_method("combat_level"):
		return int(node.combat_level())
	return 1

# Convenience: build a DamageInfo for an ability id using its AbilityData
# (tags, damage type, on-hit effect, threat multiplier).
## `damage_type` / `tags` override the ability's own (used by rune and item
## effect hits, which have no AbilityData).
func ability_hit(source: Node, target: Node, base: float, ability_id: String, is_proc := false,
		damage_type: String = "", tags: PackedStringArray = PackedStringArray()) -> RefCounted:
	return deal(ability_hit_info(source, target, base, ability_id, is_proc, damage_type, tags))

## The DamageInfo ability_hit() deals, not dealt yet (tweak it, then deal()).
func ability_hit_info(source: Node, target: Node, base: float, ability_id: String, is_proc := false,
		damage_type: String = "", tags: PackedStringArray = PackedStringArray()) -> RefCounted:
	var info := DamageInfo.make(source, target, base, ability_id)
	var res := Abilities.get_resource(ability_id)
	if res:
		info.tags = res.tags
		info.damage_type = str(res.damage_type)
		if res.on_hit_effect:
			info.effects.append(res.on_hit_effect)
		var tm = res.get("threat_multiplier")
		if tm != null:
			info.threat_multiplier = float(tm)
	if damage_type != "":
		info.damage_type = damage_type
	if not tags.is_empty():
		info.tags = tags
	info.is_proc = is_proc
	return info

func deal(info: RefCounted) -> RefCounted:
	var src: Node = info.source
	var tgt: Node = info.target
	if not _alive(tgt):
		return info
	# An enemy running back to its spot can't be hit (same on every machine).
	if tgt.has_method("is_evading") and tgt.is_evading():
		float_text(tgt, "Evade", Color(0.8, 0.8, 0.8), false)
		return info
	if info.tags.is_empty() and info.ability_id != "":
		info.tags = Abilities.tags_of(info.ability_id)
	var src_ok: bool = _alive(src)
	# The attacker may swap the effects this hit carries (effect_override(eff) ->
	# Resource; Deepwinter: every Chill of theirs is a Freeze instead).
	if src_ok and not info.effects.is_empty() and src.has_method("effect_override"):
		for i in info.effects.size():
			info.effects[i] = src.effect_override(info.effects[i])
	# 1. Crit is rolled first so crit-only modifiers can see it.
	var roll_crit := randf() * 100.0
	var crit_chance := Stats.crit_chance(info.tags, func(s): return _stat(src, s)) if src_ok else 0.0
	# The attacker may change this hit's crit chance (talents / runes, e.g.
	# Cold Precision, Permafrost, Cool Head).
	if src_ok and src.has_method("adjust_crit"):
		crit_chance = float(src.adjust_crit(info, crit_chance))
	var can_crit: bool = info.can_crit and src_ok
	info.crit = can_crit and roll_crit < crit_chance
	# The attacker may make a crit hit harder (crit_hit_bonus(info) -> [pct, label]
	# or []; Ill Will). Asked for exact hits too, which skip the modifiers below.
	if info.crit and src.has_method("crit_hit_bonus"):
		var cb: Array = src.crit_hit_bonus(info)
		if cb.size() >= 2 and float(cb[0]) > 0.0:
			info.add_bonus(float(cb[0]), str(cb[1]))
	# 2. Spell Power / Attack Power (60/20 for spells, 20/60 for abilities;
	#    DoT ticks get a share of it).
	var power := 0.0
	if info.add_power and src_ok and src.has_method("get_stat"):
		power = Stats.power_bonus(info.tags, func(s): return _stat(src, s)) * info.power_share
	var unit: float = info.unit if info.unit > 0.0 else unit_of(src)
	# 3. Percent modifiers: attacker's buffs (outgoing), target's debuffs
	#    (incoming), then anything listening on SignalBus.damage_modify.
	if not info.exact:
		_collect_mods(src, info, false)
		_collect_mods(tgt, info, true)
		# Defenders block most of a hit from the front (enemy.incoming_damage_pct).
		if tgt.has_method("incoming_damage_pct"):
			var ip: float = tgt.incoming_damage_pct(info)
			if ip != 0.0:
				info.add_bonus(ip, "Shield")
		# The target may take more or less from this attacker (incoming_bonus(info) ->
		# [pct, label] or []; Clinch).
		if tgt.has_method("incoming_bonus"):
			var ib: Array = tgt.incoming_bonus(info)
			if ib.size() >= 2 and float(ib[0]) != 0.0:
				info.add_bonus(float(ib[0]), str(ib[1]))
		# Dungeon modifiers (e.g. Frost-Touched).
		var gm := get_node_or_null("/root/GameManager")
		if gm and gm.has_method("dungeon_damage_pct"):
			var dp: float = gm.dungeon_damage_pct(info)
			if dp != 0.0:
				info.add_bonus(dp, "Dungeon")
		_bus().damage_modify.emit(info)
	# 4. Maths: coefficient x (level hit + power), x modifiers, crit, block,
	#    resistance (compute_damage()).
	var r := compute_damage(
		info.base * unit, info.base * power, crit_chance,
		_stat(tgt, Stats.BLOCK),   # the Block stat: gear, Strength, buffs (Cinder Guard). Armor does not block.
		# Armor takes a share off everything (Stats.armor_reduction), then the school's resistance.
		0.0 if info.exact else Stats.mitigation(Stats.armor_reduction(_stat(tgt, Stats.ARMOR), level_of(tgt)),
			_stat(tgt, "resist_" + info.damage_type)),
		roll_crit, randf() * 100.0,
		can_crit, info.can_block and not info.is_dot,
		1.0 + info.bonus_pct / 100.0, randf(),
		_stat(tgt, Stats.DODGE), _stat(tgt, Stats.PARRY), randf() * 100.0, randf() * 100.0,
		float(tgt.parry_cap()) if tgt.has_method("parry_cap") else -1.0,
		float(tgt.dodge_cap()) if tgt.has_method("dodge_cap") else -1.0)
	var dmg: int = r["amount"]
	info.crit = r["crit"]
	info.blocked = r["blocked"]
	info.dodged = r["dodged"]
	info.parried = r["parried"]
	info.amount = dmg
	if info.force_parry_block:   # Reflex Arc: a parry and a block at once
		force_avoid(info)
		dmg = 0
	# A target may put something else in the way of a direct hit that got through
	# (stand_in_for(info) -> bool; Stand-In: a Reflection takes it). The hit then
	# counts as avoided: no damage, and none of its effects.
	if dmg > 0 and not info.is_dot and not info.avoided() and tgt.has_method("stand_in_for") and tgt.stand_in_for(info):
		info.stood_in = true
		info.amount = 0
		dmg = 0

	# Multiplayer: a party member (not the host) never changes an enemy's HP
	# itself. It shows its own hit and reports it to the host, which applies
	# the damage, on-hit effects and threat.
	var net := get_node_or_null("/root/Net")
	# Impact effect on the same frame as the damage number (WoW's crisp "it landed").
	_impact(info, tgt)
	if net and net.is_client() and tgt.is_in_group("enemies"):
		if info.avoided():
			float_text(tgt, avoid_text(info.avoid_kind()), Color(0.7, 0.85, 1.0), false)
		elif dmg > 0:
			# The host's shield on it (mirrored here) soaks the hit first.
			info.absorbed = int(tgt.net_soak(dmg)) if tgt.has_method("net_soak") else 0
			var c := Color(0.6, 0.9, 1.0) if info.is_dot else (Color(1, 0.85, 0.2) if info.crit else Color.WHITE)
			float_text(tgt, hit_text(dmg, info.absorbed, info.crit),
				c if dmg > info.absorbed else Color(0.7, 0.9, 1.0), info.crit and dmg > info.absorbed)
		if _alive(src) and src.is_in_group("player"):
			# My on-hit effects appear here at once, worked out with MY talents
			# (duration, slow strength) and ticking with my stats; the host keeps
			# the real copy and is told those numbers. The mirror keeps them in step.
			var fx_list: Array = [] if info.avoided() else info.effects
			var fx_params: Array = []
			var st_mine: Node = tgt.get_node_or_null("Status")
			for eff in fx_list:
				if st_mine and st_mine.apply(eff, src, info.tags):
					st_mine.mark_predicted(eff, src)
					fx_params.append(st_mine.params_of(eff, src))
				else:
					fx_params.append({})
			net.report_enemy_damage(tgt, dmg, info.ability_id, info.threat_multiplier, fx_list, info.tags, fx_params)
		_bus().damage_dealt.emit(info)
		if src and is_instance_valid(src) and src.is_in_group("player") and not info.avoided() and info.part != 2:
			_bus().player_hit.emit(info.ability_id, tgt, dmg, info.crit, info.is_proc)
		return info

	# 5. Apply
	var tgt_is_player := tgt.is_in_group("player")
	if info.avoided():
		float_text(tgt, avoid_text(info.avoid_kind()), Color(0.7, 0.85, 1.0), false)
		if tgt_is_player:
			if info.blocked:
				_bus().player_blocked.emit()
			_bus().player_avoided.emit(info.avoid_kind())
	elif dmg > 0:
		if tgt.has_method("count_hit"):
			tgt.count_hit(info.tags)   # (Pin the Shadow: a few hits, from anyone, free it)
		# Absorb shields (Rime Shell...) soak the hit first.
		var st_abs: Node = tgt.get_node_or_null("Status")
		var through := dmg
		if st_abs and st_abs.has_method("absorb_damage"):
			through = st_abs.absorb_damage(dmg)
		info.absorbed = dmg - through
		var col := Color(1, 0.35, 0.3) if tgt_is_player else (Color(1, 0.85, 0.2) if info.crit else Color.WHITE)
		if info.is_dot:
			col = Color(0.6, 0.9, 1.0)
		if through > 0:
			if tgt.has_method("note_attacker"):
				tgt.note_attacker(src)   # killing-blow tracking (on-kill runes)
			float_text(tgt, hit_text(dmg, info.absorbed, info.crit), col, info.crit)
			if is_instance_valid(tgt):
				if tgt.has_method("before_hit_lands"):
					tgt.before_hit_lands(info)   # (Catch: the hit it catches lands in full)
				tgt.take_damage(through)
		else:
			float_text(tgt, hit_text(dmg, info.absorbed, info.crit), Color(0.7, 0.9, 1.0), false)
	# 6. On-hit status effects: none from a hit that was dodged, parried or blocked.
	if not info.avoided():
		var status: Node = tgt.get_node_or_null("Status") if is_instance_valid(tgt) else null
		if status:
			for eff in info.effects:
				status.apply(eff, src, info.tags)
	# 7. Threat
	if is_instance_valid(tgt) and tgt.has_method("add_threat") and _alive(src):
		tgt.add_threat(src, max(dmg, 1) * info.threat_multiplier)
	# 8. Events
	_bus().damage_dealt.emit(info)
	# (The second half of a split hit - Frostfire Bolt - is the same hit: one event.)
	if src and is_instance_valid(src) and src.is_in_group("player") and not info.avoided() and info.part != 2:
		_bus().player_hit.emit(info.ability_id, tgt, dmg, info.crit, info.is_proc)
	return info

## Floating text of a hit of `dmg` of which a shield soaked `absorbed`.
static func hit_text(dmg: int, absorbed: int, crit: bool) -> String:
	var through := dmg - absorbed
	if through <= 0:
		return "Absorb %d" % absorbed
	var txt := str(through) + ("!" if crit else "")
	if absorbed > 0:
		txt += " (%d absorbed)" % absorbed
	return txt

## Put status effect `eff` from `source` on `target` without a hit (rune and
## item effects). An enemy's effects live on the host, so a party member's copy
## appears here at once and is reported like the effect of a real hit.
func apply_effect(source: Node, target: Node, eff: Resource, ability_id: String = "",
		tags: PackedStringArray = PackedStringArray()) -> void:
	if eff == null or not _alive(target):
		return
	if _alive(source) and source.has_method("effect_override"):
		eff = source.effect_override(eff)   # Deepwinter (see deal())
		if eff == null:
			return
	var st: Node = target.get_node_or_null("Status")
	if st == null:
		return
	var net := get_node_or_null("/root/Net")
	if net and net.is_client() and target.is_in_group("enemies"):
		if target.has_method("is_evading") and target.is_evading():
			return
		var params := {}
		if st.apply(eff, source, tags):
			st.mark_predicted(eff, source)
			params = st.params_of(eff, source)
		net.report_enemy_damage(target, 0, ability_id, 1.0, [eff], tags, [params])
		return
	st.apply(eff, source, tags)

const ImpactFX = preload("res://scripts/core/impact_fx.gd")

## Impact burst on the target for a direct hit (not DoT ticks, not 0-damage
## effect-only hits), at chest height, in the hit's school color.
func _impact(info: RefCounted, tgt: Node) -> void:
	if info.is_dot or not (tgt is Node3D) or (int(info.amount) <= 0 and not info.blocked):
		return
	var scene := get_tree().current_scene
	if scene:
		ImpactFX.spawn(scene, (tgt as Node3D).global_position + Vector3(0, 0.3, 0), str(info.damage_type), bool(info.crit))

func _collect_mods(who: Node, info: RefCounted, incoming: bool) -> void:
	if who == null or not is_instance_valid(who):
		return
	var status: Node = who.get_node_or_null("Status")
	if status and status.has_method("collect_damage_mods"):
		status.collect_damage_mods(info, incoming)

## Pure damage maths (no randomness inside: pass rolls in 0..100), used by deal()
## and by the automated tests.
## Order: + bonus (power) -> x multiplier (percent modifiers) -> crit x2 ->
## dodge / parry / block -> resist.
## `block_chance` is a percent (the Block stat; Armor is part of `resist`:
## Stats.armor_reduction and Stats.mitigation), and
## so are `dodge_chance` and `parry_chance`. Each has a roll and a cap of its
## own; they are checked in the order dodge, parry, block, and the first that
## succeeds takes the hit down to 0. `can_block` = false: none of the three.
## `roll_round` (0..1) rounds fractional damage: floor(x + roll). A random roll
## makes small numbers fair on average (2.4 -> 3 on 40% of hits); the default
## 0.5 is normal rounding.
static func compute_damage(base: float, bonus: float, crit_chance: float, block_chance: float, resist: float,
		roll_crit: float, roll_block: float, can_crit: bool = true, can_block: bool = true,
		multiplier: float = 1.0, roll_round: float = 0.5,
		dodge_chance: float = 0.0, parry_chance: float = 0.0,
		roll_dodge: float = 100.0, roll_parry: float = 100.0, parry_cap: float = -1.0,
		dodge_cap: float = -1.0) -> Dictionary:
	if parry_cap < 0.0:
		parry_cap = Stats.MAX_PARRY   # (a target may have a cap of its own: Humming Blade, Crossguard)
	if dodge_cap < 0.0:
		dodge_cap = Stats.MAX_DODGE   # (and a Dodge cap of its own: Reflections)
	var raw := maxf(float(base) + bonus, 0.0) * maxf(multiplier, 0.0)
	var dmg := maxi(int(floor(raw + roll_round)), 0) if raw > 0.0 else 0
	var crit := can_crit and roll_crit < crit_chance
	if crit:
		dmg *= CRIT_MULTIPLIER
	var dodged := can_block and dodge_chance > 0.0 and roll_dodge < minf(dodge_chance, dodge_cap)
	var parried := can_block and not dodged and parry_chance > 0.0 and roll_parry < minf(parry_chance, parry_cap)
	var blocked := can_block and not dodged and not parried and block_chance > 0.0 \
		and roll_block < minf(block_chance, Stats.MAX_BLOCK)
	if dodged or parried or blocked:
		dmg = 0
	var res := clampf(resist, -100.0, 90.0)
	if res != 0.0 and dmg > 0:
		dmg = maxi(int(round(dmg * (1.0 - res / 100.0))), 1)
	return {"amount": dmg, "crit": crit, "blocked": blocked, "dodged": dodged, "parried": parried}

## A hit a damage_modify listener marked (DamageInfo.force_parry_block: Reflex
## Arc) is avoided outright and counts as a parry and a block at once, so
## everything that reacts to either reacts to it.
static func force_avoid(info: RefCounted) -> void:
	info.dodged = false
	info.parried = true
	info.blocked = true
	info.amount = 0

## Floating text of a hit that did nothing: "Dodge", "Parry", "Block" or "Reflection".
static func avoid_text(kind: String) -> String:
	return kind.capitalize() if kind != "" else "Block"

## Chance (%) that at least one of dodge, parry and block stops a hit, each
## capped (they are rolled one after the other, so they don't simply add up).
static func avoid_chance(dodge: float, parry: float, block: float) -> float:
	var d := clampf(dodge, 0.0, Stats.MAX_DODGE) / 100.0
	var p := clampf(parry, 0.0, Stats.MAX_PARRY) / 100.0
	var b := clampf(block, 0.0, Stats.MAX_BLOCK) / 100.0
	return (1.0 - (1.0 - d) * (1.0 - p) * (1.0 - b)) * 100.0

# Damage-over-time tick from a status effect. DoTs crit and scale with a
# share of power unless the effect says otherwise (dot_can_crit / dot_power_share).
# `tags` = tags of the spell/ability that applied it (so a Fireball burn is a
# Spell tick and a Searing Strike burn an Ability tick).
## `unit` = the caster's damage unit when the DoT was applied (so a DoT keeps
## ticking at the right size even if its caster is gone).
func deal_dot(source: Node, target: Node, amount: float, damage_type: String, effect_id: String,
		tags: PackedStringArray = PackedStringArray(), res: Resource = null, unit: float = -1.0,
		threat_mult: float = 1.0, no_empower: bool = false) -> void:
	var info := DamageInfo.make(source if is_instance_valid(source) else null, target, amount, "dot_" + effect_id)
	info.no_empower = no_empower
	info.unit = unit
	info.threat_multiplier = threat_mult
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

## One-off hit from a status effect (e.g. Hoarfrost bursting when it runs out):
## crits and gets power like a normal hit of the spell that applied it.
func deal_burst(source: Node, target: Node, amount: float, damage_type: String, effect_id: String,
		tags: PackedStringArray = PackedStringArray(), unit: float = -1.0) -> void:
	if not _alive(target):
		return
	var info := DamageInfo.make(source if is_instance_valid(source) else null, target, amount, "burst_" + effect_id)
	info.unit = unit
	info.can_block = false
	info.damage_type = damage_type
	info.tags = tags
	info.is_proc = true
	deal(info)

# Healing. `amount` is a coefficient like damage (1.0 = a standard hit's worth
# of health); with `ability_id` the heal also gets the source's Spell / Attack
# Power like a hit from that spell / ability would. Use raw = true for an exact
# number of health points. Healing makes threat on every enemy fighting the
# healer or the healed target (HEAL_THREAT per point actually healed).
func heal(source: Node, target: Node, amount: float, ability_id: String = "", raw: bool = false) -> int:
	if not _alive(target) or amount <= 0.0:
		return 0
	var real := int(amount) if raw else heal_amount(source, amount, ability_id)
	# Dungeon modifiers (Bloodthirst: less healing; Lifesteal is handled separately).
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_method("heal_mult") and ability_id != "lifesteal":
		real = int(round(float(real) * float(gm.heal_mult())))
	# The one being healed may take more or less of it (heal_taken_mult(source,
	# ability_id) -> float; a Pact: Player.heal_taken_mult).
	if target.has_method("heal_taken_mult"):
		real = int(round(float(real) * maxf(float(target.heal_taken_mult(source, ability_id)), 0.0)))
	if real <= 0:
		return 0
	var missing := real
	var h = target.get("health")
	var mh = target.get("max_health")
	if h != null and mh != null:
		missing = clampi(int(mh) - int(h), 0, real)
	if target.has_method("receive_heal"):
		target.receive_heal(real)
	float_text(target, "+%d" % real, Color(0.45, 1.0, 0.45), false)
	_bus().healed.emit(source, target, real)
	_bus().heal_done.emit(source, target, real, missing, ability_id, false)
	heal_threat(source, target, missing)
	return real

## Real health restored by a heal of `coef` from `source` (crit not included).
func heal_amount(source: Node, coef: float, ability_id: String = "") -> int:
	var unit := unit_of(source)
	var p := 0.0
	if _alive(source) and source.has_method("get_stat"):
		var tags := Abilities.tags_of(ability_id) if ability_id != "" else PackedStringArray()
		if tags.is_empty():
			tags = PackedStringArray(["Spell"])   # untagged heals (runes, items) scale like spells
		p = Stats.power_bonus(tags, func(s): return _stat(source, s))
	return int(floor(coef * (unit + p) + randf()))

## Threat for `amount` healing done by `source` on `target`.
func heal_threat(source: Node, target: Node, amount: int) -> void:
	if not _alive(source) or amount <= 0:
		return
	var net := get_node_or_null("/root/Net")
	if net and net.is_client():
		net.report_heal_threat(source, target, amount * HEAL_THREAT)   # threat lives on the host
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("is_fighting") and (e.is_fighting(target) or e.is_fighting(source)):
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
	# Crits pop: start big and snap down (on the same frame as the impact).
	l.scale = Vector3.ONE * (1.7 if big else 1.0)
	if big:
		t.tween_property(l, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
