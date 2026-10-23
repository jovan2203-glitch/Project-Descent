extends "res://scripts/player/player_kit.gd"
class_name StormArrowKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "storm_arrow_kit".
# --- Storm Arrow talents (the Lightning bow) -----------------------------------------------

## Energy a Storm Arrow costs: nothing out of a Loaded Quiver, `less` off after Snap Shot.
static func storm_arrow_cost(cost: float, loaded: bool, less: float) -> float:
	if loaded:
		return 0.0
	return maxf(cost - maxf(less, 0.0), 0.0)

## Is my next Storm Arrow one of Loaded Quiver's (free, and it ignores the cooldown)?
func quiver_loaded() -> bool:
	return player.status != null and player.status.has(LightningCasterKit.LOADED_QUIVER_FX)

## Loaded Quiver: I took my Energy back out of the Capacitor. My next Storm
## Arrows cost nothing and ignore the cooldown, one stack each.
func _load_quiver() -> void:
	var arrows := int(round(player._talent("lightning_loaded_quiver")))
	if arrows <= 0:
		return
	var arrow_name := Abilities.ability_name(LightningCasterKit.STORM_ARROW_ID)
	var fx := StatusContainer.make_buff(LightningCasterKit.LOADED_QUIVER_FX, "Loaded Quiver", LightningCasterKit.LOADED_QUIVER_FX, 0.0,
		Balance.LOADED_QUIVER_TIME, arrows, Abilities.color_of(LightningCasterKit.STORM_ARROW_ID))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Lightning"])
	fx.description = "Your next %s costs no Energy and ignores its cooldown, one stack each." % arrow_name
	player.status.remove(LightningCasterKit.LOADED_QUIVER_FX)
	if player.status.apply(fx, player):
		player.status.set_stacks(LightningCasterKit.LOADED_QUIVER_FX, arrows)

## Snap Shot: I Flickered. Storm Arrow is ready again, and the next one costs less.
func _snap_shot() -> void:
	var less := player._talent("lightning_snap_shot")
	if less <= 0.0:
		return
	player.cooldowns.erase(LightningCasterKit.STORM_ARROW_ID)
	var fx := StatusContainer.make_buff(LightningCasterKit.SNAP_SHOT_FX, "Snap Shot", LightningCasterKit.SNAP_SHOT_FX, 0.0,
		Balance.SNAP_SHOT_TIME, 1, Abilities.color_of(LightningCasterKit.STORM_ARROW_ID))
	fx.stat_modifiers = {}
	fx.tags = PackedStringArray(["Lightning"])
	fx.description = "Your next %s costs %s less Energy." % [Abilities.ability_name(LightningCasterKit.STORM_ARROW_ID), Stats.num(less)]
	player.status.apply(fx, player)

## A Storm Arrow left the bow; it had `cd_before` seconds of cooldown left when
## I let go (only a Loaded Quiver arrow can have any). A Loaded Quiver arrow
## uses a stack and leaves the cooldown as it was; otherwise Snap Shot's
## cheaper arrow is used up.
func _storm_arrow_fired(cd_before: float) -> void:
	if player.status.has(LightningCasterKit.LOADED_QUIVER_FX):
		player.status.spend_stacks(LightningCasterKit.LOADED_QUIVER_FX, 1)
		if cd_before > 0.0:
			player.cooldowns[LightningCasterKit.STORM_ARROW_ID] = cd_before
		else:
			player.cooldowns.erase(LightningCasterKit.STORM_ARROW_ID)
	elif player.status.has(LightningCasterKit.SNAP_SHOT_FX):
		player.status.remove(LightningCasterKit.SNAP_SHOT_FX)

## Grounded Arrow: damage each arc deals when a Lightning Bolt hit for `amount`,
## at `pct` % of it, with `count` enemies around (more than AOE_TARGET_CAP share
## that many arcs).
static func lightning_rod_damage(amount: int, pct: float, count: int = 1) -> float:
	return maxf(float(amount) * maxf(pct, 0.0) / 100.0, 0.0) * Balance.aoe_share(count)

## Grounded Arrow: my Lightning Bolt hit a target with MY Storm Arrow stuck in it
## (own only). An exact share of the hit arcs to the enemies around it: dealt as
## procs, so the arcs feed nothing else and their crit is already in the hit.
func _lightning_rod_arc(info: RefCounted) -> void:
	var pct := player._talent("lightning_rod")
	if pct <= 0.0 or bool(info.is_proc) or bool(info.is_dot) or int(info.amount) <= 0:
		return
	var foe: Node = info.target
	var st: Node = foe.get_node_or_null("Status")
	if st == null or not st.has_from(LightningCasterKit.ROD_FX, player):
		return
	var near := player._enemies_near(foe.global_position, Balance.LIGHTNING_ROD_RADIUS, foe)
	var each := lightning_rod_damage(int(info.amount), pct, near.size())
	for e in near:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var arc := DamageInfo.make(player, e, 1.0, LightningCasterKit.ROD_FX)
		arc.unit = each
		arc.exact = true
		arc.add_power = false
		arc.can_crit = false
		arc.can_block = false
		arc.is_proc = true
		arc.damage_type = "lightning"
		arc.tags = PackedStringArray(["Lightning", "Spell"])
		player._combat().deal(arc)
		player._ring_effect(0.6, Abilities.color_of(LightningCasterKit.STORM_ARROW_ID), e.global_position)
const LIVE_WIRE = preload("res://scripts/live_wire.gd")
const THUNDERHEAD = preload("res://scripts/thunderhead.gd")
## Seconds after Live Wire lands before a missing effect counts as "it ran out"
## (in a party the effect comes back from the host a moment later).
const WIRE_GRACE := 1.0
var _wire_target: Node3D        # the enemy my Live Wire is on
var _wire_line: Node3D          # its picture
var _wire_since := 0.0          # when it landed (seconds)
var _flicker_cast := false      # the current Lightning Bolt cast is Flicker's instant one
var _overture_cast := false     # the current cast is the Overture's instant one (Holy healer rune)
var _capacitor_stored := 0.0    # Energy put aside in the Capacitor

