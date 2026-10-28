extends "res://scripts/player/player_kit.gd"
class_name FireTankKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "fire_tank".
# --- Furnace Breath (cone) and Slag Skin (armor + burns attackers) ---------------------

## Is the point `to` (relative to you) inside a cone `arc_deg` wide around `forward`?
## Flat (height ignored). Something right on top of you always counts.
static func in_cone(forward: Vector3, to: Vector3, arc_deg: float) -> bool:
	var f := Vector2(forward.x, forward.z)
	var d := Vector2(to.x, to.z)
	if d.length() < 0.5 or f.length() < 0.001:
		return true
	return absf(rad_to_deg(f.angle_to(d))) <= arc_deg * 0.5 + 0.001

## Visible enemies within `radius` and inside a cone `arc_deg` wide in front of you.
func _enemies_in_cone(radius: float, arc_deg: float) -> Array:
	var fwd := player._flat_forward()
	return player._enemies_within(radius).filter(func(e): return in_cone(fwd, e.global_position - player.global_position, arc_deg))

const SLAG_ID := "slagskin"
var _slag_hit_at := {}   # attacker instance id -> last time Slag Skin burned it

## Slag Skin: an enemy whose attack reaches you (hit or blocked; not damage over
## time) is burned, at most once per SLAG_SKIN_ICD seconds each.
func _slag_skin_retaliate(info: RefCounted) -> void:
	if not is_same(info.target, player) or info.is_dot or player.status == null or not player.status.has(SLAG_ID) or player.is_dead():
		return
	var foe: Variant = info.source
	if foe == null or not is_instance_valid(foe) or not (foe is Node) or not foe.is_in_group("enemies") or not foe.is_alive():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var key: int = foe.get_instance_id()
	if now - float(_slag_hit_at.get(key, -100.0)) < Balance.SLAG_SKIN_ICD:
		return
	_slag_hit_at[key] = now
	var burn := float(Abilities.get_resource(SLAG_ID).damage)
	if info.blocked:
		burn = block_burn(burn, player._talent("fire_hot_iron"))   # Hot Iron
	# Passive damage: it never builds or spends Smoldering Focus / Afterburn.
	var back = player._combat().ability_hit_info(player, foe, burn, SLAG_ID, true)
	back.no_empower = true
	player._combat().deal(back)

# --- Slag (the Fire tank's armor) ---------------------------------------------------------
# While Slag Skin is up, each attack I block and each melee hit of mine adds a
# stack of Slag (armor per stack; a hit adds one per use, however many enemies it
# hit). A stack from a melee crit is brittle: it crumbles after SLAG_BRITTLE_TIME.
# Slag never breaks by itself: only Forge Blow shatters it, as Fire damage around
# me. Slag lasts exactly as long as Slag Skin does, so letting Slag Skin drop loses it.

const SLAG_STACK_ID := "slag"
const FORGE_BLOW_ID := "forgeblow"
const RIVET_ID := "redhotrivet"
const MOLTEN_SHELL_ID := "moltenshell"
const TANK_IDS := [FORGE_BLOW_ID, RIVET_ID, MOLTEN_SHELL_ID]
var _slag_fx: Resource
var _slag_last := ""   # "<ability>@<frame>" of the last hit that added a stack
var _brittle: Array = []   # expiry times of my brittle Slag stacks
var _shell_on := false   # Molten Shell was up last tick (to trim Slag when it ends)

## Most Slag I can hold right now.
func slag_cap() -> int:
	var deep := int(round(player._talent("fire_deep_slag")))   # Deep Slag
	if player.status and player.status.has(MOLTEN_SHELL_ID):
		return Balance.MOLTEN_SHELL_MAX + deep
	return Balance.SLAG_MAX_STACKS + deep

## Seconds a brittle stack of Slag lasts (Set Hard: longer).
func brittle_time() -> float:
	return Balance.SLAG_BRITTLE_TIME + player._talent("fire_set_hard")

func slag_stacks() -> int:
	return int(player.status.stacks_of(SLAG_STACK_ID)) if player.status else 0

## Slag one blocked attack gives: 1, or more during Cinder Guard / Molten Shell.
static func block_slag(guard: bool, shell: bool) -> int:
	var n := 1
	if guard:
		n = maxi(n, Balance.CINDER_GUARD_SLAG)
	if shell:
		n = maxi(n, Balance.MOLTEN_SHELL_BLOCK_SLAG)
	return n

## % less damage taken during Molten Shell while holding `stacks` Slag.
static func shell_reduction(stacks: int) -> float:
	return Balance.MOLTEN_SHELL_DR * maxi(stacks, 0)

## Add `n` Slag (only while Slag Skin is up). `brittle` stacks crumble after SLAG_BRITTLE_TIME.
func gain_slag(n: int, brittle: bool = false) -> void:
	if player.status == null or not player.status.has(SLAG_ID):
		return
	var fx := _slag_stack_fx()
	var now := Time.get_ticks_msec() / 1000.0
	for i in maxi(n, 0):
		var before := slag_stacks()
		player.status.apply(fx, player)
		if brittle and slag_stacks() > before:
			_brittle.append(now + brittle_time())
	_sync_slag()

## Brittle Slag crumbling, and Slag dropping back to its cap when Molten Shell ends.
func _tick_slag() -> void:
	if player.status == null:
		return
	var stacks: int = slag_stacks()
	if stacks <= 0:
		_brittle.clear()
	var shell: bool = player.status.has(MOLTEN_SHELL_ID)
	var normal: int = Balance.SLAG_MAX_STACKS + int(round(player._talent("fire_deep_slag")))
	if _shell_on and not shell and stacks > normal:
		player.status.set_stacks(SLAG_STACK_ID, normal)
	_shell_on = shell
	if _brittle.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	for i in range(_brittle.size() - 1, -1, -1):
		if float(_brittle[i]) <= now:
			_brittle.remove_at(i)
			player.status.spend_stacks(SLAG_STACK_ID, 1)
	while _brittle.size() > slag_stacks():
		_brittle.pop_front()   # (stacks trimmed some other way: the brittle ones went first)

## A blocked attack (not damage over time) adds Slag while Slag Skin is up.
## Fuel the Forge: every block gives Fury, Slag Skin or not.
func _slag_hit_taken(info: RefCounted) -> void:
	if not info.blocked or info.is_dot or player.status == null:
		return
	var fuel := player._talent("fire_fuel_the_forge")
	if fuel > 0.0:
		player._gain("fury", fuel)
	if player.status.has(SLAG_ID):
		gain_slag(block_slag(player.status.has(CINDER_GUARD_ID), player.status.has(MOLTEN_SHELL_ID)))

## Damage I take: Molten Shell takes some off for each Slag I hold.
func _slag_incoming(info: RefCounted) -> void:
	if player.status and player.status.has(MOLTEN_SHELL_ID):
		var cut := shell_reduction(slag_stacks())
		if cut > 0.0:
			info.add_bonus(-cut, "Molten Shell")

## Armor one Slag stack gives, in flat units, with Thick Slag at `talent_pct`.
static func slag_armor(talent_pct: float) -> float:
	return Balance.SLAG_ARMOR * (1.0 + talent_pct / 100.0)

## Damage coefficient of `stacks` Slag shattering.
static func slag_shatter_coef(stacks: int) -> float:
	return float(Balance.EXTRA_HITS["slagskin"]) * maxi(stacks, 0)

## Retaliation damage for an attack that was blocked, with Hot Iron at `hot_iron_pct`.
static func block_burn(base: float, hot_iron_pct: float) -> float:
	return base * (1.0 + hot_iron_pct / 100.0)

## Slag stacks run out together with Slag Skin.
func _sync_slag() -> void:
	if player.status and player.status.has(SLAG_STACK_ID):
		player.status.set_remaining(SLAG_STACK_ID, player.status.remaining_of(SLAG_ID))

func _slag_stack_fx() -> Resource:
	var per := slag_armor(player._talent("fire_thick_slag")) * player._flat_unit()
	var crust := player._talent("fire_hard_crust")   # Hard Crust: chance to block per stack
	var cap := slag_cap()
	if _slag_fx == null or not is_equal_approx(float(_slag_fx.stat_modifiers.get(Stats.ARMOR, 0.0)), per) \
			or not is_equal_approx(float(_slag_fx.stat_modifiers.get(Stats.BLOCK, 0.0)), crust) or int(_slag_fx.max_stacks) != cap:
		_slag_fx = StatusContainer.make_buff(SLAG_STACK_ID, "Slag", Stats.ARMOR, per,
			Balance.SLAG_SKIN_TIME, cap, Color(0.75, 0.45, 0.3))
		if crust > 0.0:
			_slag_fx.stat_modifiers[Stats.BLOCK] = crust
		_slag_fx.description = "Hardened slag: Armor per stack. Stacks from critical strikes are brittle and crumble after %s sec. Forge Blow shatters it." \
			% Stats.num(brittle_time())
	return _slag_fx

## A hit of mine landed: each melee hit (not procs) adds Slag; a crit's is brittle.
func _slag_on_hit(info: RefCounted, tags: PackedStringArray) -> void:
	if info.is_proc or int(info.amount) <= 0 or not tags.has("Melee") or not player.status.has(SLAG_ID):
		return
	var key := "%s@%d" % [str(info.ability_id), Engine.get_process_frames()]
	if key == _slag_last:
		return   # the same swing hitting another enemy
	_slag_last = key
	gain_slag(1, bool(info.crit))

# --- Forge Blow, Red-Hot Rivet, Molten Shell -------------------------------------------------

func _tank_precheck(id: String) -> String:
	if id == FORGE_BLOW_ID and slag_stacks() <= 0:
		return "You have no Slag"
	return ""

## One of Slagforged's new abilities (paid for and put on cooldown by _use_drafted).
func _tank_use(id: String, res: Resource) -> void:
	match id:
		FORGE_BLOW_ID:
			var fuel := player._talent("fire_heavy_hammer") * slag_stacks()   # Heavy Hammer: Fury back per stack
			player._shield_bash_effect(Abilities.color_of(id))
			_slag_shatter()
			if fuel > 0.0:
				player._gain("fury", fuel)
		RIVET_ID:
			if not player._has_valid_target():
				return
			var foe: Node3D = player.target
			player.deal_damage(foe, float(res.damage), id)
			player._net_taunt(foe, Balance.RIVET_TAUNT)
			gain_slag(Balance.RIVET_SLAG)
			player._ring_effect(0.8, Color(1.0, 0.45, 0.15), foe.global_position)
		MOLTEN_SHELL_ID:
			var fx := StatusContainer.make_buff(MOLTEN_SHELL_ID, Abilities.ability_name(id), MOLTEN_SHELL_ID, 0.0,
				Balance.MOLTEN_SHELL_TIME + player._talent("fire_long_shell"), 1, Abilities.color_of(id))   # + Long Shell
			fx.stat_modifiers = {}
			fx.description = "Your Slag holds up to %d, each block adds %d, and each Slag makes you take %s%% less damage." % [
				Balance.MOLTEN_SHELL_MAX, Balance.MOLTEN_SHELL_BLOCK_SLAG, Stats.num(Balance.MOLTEN_SHELL_DR)]
			player.status.apply(fx, player)
			_shell_on = true
			player._ring_effect(1.4, Abilities.color_of(id))
			player._ring_effect(0.9, Color(1.0, 0.85, 0.4))

## Forge Blow: every stack of Slag breaks at once, as Fire damage around me.
func _slag_shatter() -> void:
	var stacks: int = player.status.stacks_of(SLAG_STACK_ID)
	if stacks <= 0:
		return
	player.status.remove(SLAG_STACK_ID)
	_brittle.clear()
	# Slag Mending: the breaking slag heals me, per stack.
	var mend := FireCooldownsKit.slag_mending_heal(player.max_health, stacks, player._talent("fire_slag_mending"))
	if mend > 0:
		player._combat().heal(player, player, float(mend), "slag_mending", true)
	var coef := slag_shatter_coef(stacks)
	var tags := PackedStringArray(["Fire", "Spell", "AoE"])
	var hit := player._enemies_within(Balance.SLAG_SHATTER_RADIUS)
	var share := Balance.aoe_share(hit.size())
	var heart := FireTalentsKit.molten_heart_pct(stacks, player._talent("fire_molten_heart"))   # Molten Heart
	var marked := player._talent("fire_marked_iron")   # Marked Iron
	for e in hit:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		# (A proc: it never feeds Cool Head, Pressure Valve or hit-counting runes.)
		var info := DamageInfo.make(player, e, coef * share, "slag_shatter")
		info.tags = tags
		info.damage_type = "fire"
		info.threat_multiplier = Balance.SLAG_SHATTER_THREAT * (1.0 + heart / 100.0)
		info.is_proc = true
		# Passive damage: a shatter must not spend a full stack of Smoldering Focus
		# (one crit did 15x a normal shatter that way) or build it / Afterburn.
		info.no_empower = true
		if heart > 0.0:
			info.add_bonus(heart, "Molten Heart")
		var est: Node = e.get_node_or_null("Status")
		if marked > 0.0 and est != null and est.has_from(BRAND_FX_ID, player):
			info.add_bonus(marked, "Marked Iron")
		player._combat().deal(info)
	# Quick Temper: Cinder Guard comes back sooner. Spatter: a stack may stay.
	var temper := player._talent("fire_quick_temper")
	if temper > 0.0 and player.cooldowns.has("cinderguard"):
		player.cooldowns["cinderguard"] = float(player.cooldowns["cinderguard"]) - temper
	if randf() * 100.0 < player._talent("fire_spatter"):
		gain_slag(1)
	player._ring_effect(Balance.SLAG_SHATTER_RADIUS, Abilities.color_of(SLAG_ID))
	player._ring_effect(Balance.SLAG_SHATTER_RADIUS * 0.6, Color(0.25, 0.2, 0.18))
	# Smoldering Debris talent: the broken slag keeps burning where I stand. Each
	# tick is that share of what the shatter did to each enemy (before its crit;
	# ticks roll their own crit like any periodic damage).
	var debris := player._talent("fire_clinker")
	if debris > 0.0:
		var side := Balance.CLINKER_RADIUS * 2.0
		_fire_patch(Vector3(player.global_position.x, Combat.feet_y(player), player.global_position.z), player.rotation.y, side, side,
			Balance.CLINKER_TIME, Balance.CLINKER_TICK, debris_tick_coef(coef * share, debris), tags, DEBRIS_ID, true)

## Meter / log id of the Smoldering Debris patch (its ticks are "dot_" + this).
const DEBRIS_ID := "smoldering_debris"

## Coefficient of one Smoldering Debris tick: `pct` percent of the shatter's hit.
static func debris_tick_coef(shatter_coef_per_enemy: float, pct: float) -> float:
	return shatter_coef_per_enemy * pct / 100.0

## A strip (or square) of fire on the ground: `damage` to enemies standing in it
## every `tick` seconds, as periodic Fire damage of mine. Its length runs along
## its local X axis. Party members get the picture; the damage is dealt here.
func _fire_patch(at: Vector3, yaw: float, length: float, depth: float, time: float, tick: float,
		damage: float, tags: PackedStringArray, effect_id: String, passive: bool = false) -> void:
	var patch := Node3D.new()
	patch.set_script(FireCasterKit.FIRE_WALL)
	patch.length = length
	patch.depth = depth
	patch.duration = time
	patch.tick = maxf(tick / player.haste_mult(), 0.1)
	patch.damage = damage
	patch.tags = tags
	patch.effect_id = effect_id
	patch.passive = passive
	patch.source = player
	player.get_tree().current_scene.add_child(patch)
	patch.global_position = at
	patch.rotation.y = yaw
	player._net_fx("firewall", at, null, {"yaw": yaw, "len": length, "depth": depth, "time": time})

# --- Cinder Guard and Brand (Fire tank) ------------------------------------------------------

const CINDER_GUARD_ID := "cinder_guard"
const BRAND_FX_ID := "branded"

func tracker_values() -> Dictionary:
	return {"slag": {"value": slag_stacks(), "max": slag_cap()}}
