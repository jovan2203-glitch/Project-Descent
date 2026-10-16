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
# While Slag Skin is up, each melee hit of mine that doesn't crit adds a stack of
# Slag (armor per stack; once per use, however many enemies it hit). A melee crit
# shatters every stack as Fire damage around me. Slag lasts exactly as long as
# Slag Skin does, so letting Slag Skin drop loses it.

const SLAG_STACK_ID := "slag"
var _slag_fx: Resource
var _slag_last := ""   # "<ability>@<frame>" of the last hit that added a stack

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
	if _slag_fx == null or not is_equal_approx(float(_slag_fx.stat_modifiers.get(Stats.ARMOR, 0.0)), per):
		_slag_fx = StatusContainer.make_buff(SLAG_STACK_ID, "Slag", Stats.ARMOR, per,
			Balance.SLAG_SKIN_TIME, Balance.SLAG_MAX_STACKS, Color(0.75, 0.45, 0.3))
		_slag_fx.description = "Hardened slag: Armor per stack. A melee critical strike of yours shatters it."
	return _slag_fx

## A hit of mine landed: melee hits (not procs) build or shatter Slag.
func _slag_on_hit(info: RefCounted, tags: PackedStringArray) -> void:
	if info.is_proc or int(info.amount) <= 0 or not tags.has("Melee") or not player.status.has(SLAG_ID):
		return
	if info.crit:
		_slag_shatter()
		return
	var key := "%s@%d" % [str(info.ability_id), Engine.get_process_frames()]
	if key == _slag_last:
		return   # the same swing hitting another enemy
	_slag_last = key
	player.status.apply(_slag_stack_fx(), player)
	_sync_slag()

func _slag_shatter() -> void:
	var stacks: int = player.status.stacks_of(SLAG_STACK_ID)
	if stacks <= 0:
		return
	player.status.remove(SLAG_STACK_ID)
	# Slag Mending: the breaking slag heals me, per stack.
	var mend := FireCooldownsKit.slag_mending_heal(player.max_health, stacks, player._talent("fire_slag_mending"))
	if mend > 0:
		player._combat().heal(player, player, float(mend), "slag_mending", true)
	var coef := slag_shatter_coef(stacks)
	var tags := PackedStringArray(["Fire", "Spell", "AoE"])
	var hit := player._enemies_within(Balance.SLAG_SHATTER_RADIUS)
	var share := Balance.aoe_share(hit.size())
	for e in hit:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		# (A proc: it never feeds Cool Head, Pressure Valve or hit-counting runes.)
		var info := DamageInfo.make(player, e, coef * share, "slag_shatter")
		info.tags = tags
		info.damage_type = "fire"
		info.threat_multiplier = Balance.SLAG_SHATTER_THREAT
		info.is_proc = true
		# Passive damage: a shatter must not spend a full stack of Smoldering Focus
		# (one crit did 15x a normal shatter that way) or build it / Afterburn.
		info.no_empower = true
		player._combat().deal(info)
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

