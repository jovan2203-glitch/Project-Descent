extends "res://scripts/player/player_kit.gd"
class_name FireTalentsKit

# The Fire book's talents that change a hit (the column-group tree, talents.gd):
# damage and threat bonuses on my hits, and less damage taken. Each damage bonus
# is its own line (info.add_bonus with the talent's name). The rest of the Fire
# talents live with the rules they change, in each spec's component (fire_fury.gd,
# fire_tank.gd, fire_melee.gd, fire_bow.gd). Hooked up from player.gd
# (_on_damage_modify) through its var "fire_talents".

## Is `id` an arrow of mine (a bow ability or an auto-shot)?
static func is_arrow(id: String, tags: PackedStringArray) -> bool:
	return id == "auto_ranged" or (tags.has("Ranged") and tags.has("Ability") and not id.begins_with("dot_"))

## Is this a tick of my Burning?
static func is_burning_tick(id: String) -> bool:
	return id == "dot_burning"

## Big Spend: % more for a spell or ability that spent `spent` Fury.
static func big_spend_pct(spent: float, pct: float) -> float:
	return pct if spent >= Balance.BIG_SPEND_FURY else 0.0

## Low Flame: % more while my sheet critical strike chance is below its line.
static func low_flame_pct(crit: float, pct: float) -> float:
	return pct if crit < Balance.LOW_FLAME_CRIT else 0.0

## Molten Heart: % more damage and threat for a shatter of `stacks` Slag.
static func molten_heart_pct(stacks: int, pct: float) -> float:
	return pct * maxi(stacks - Balance.MOLTEN_HEART_ABOVE, 0)

## A hit of mine, before its damage is worked out.
func _fire_talents_outgoing(info: RefCounted) -> void:
	var id := str(info.ability_id)
	var tags: PackedStringArray = info.tags
	var fire := str(info.damage_type) == "fire"
	var tgt: Variant = info.target
	var spell := fire and tags.has("Spell")
	# Steady Flame.
	if spell and not info.is_dot and not info.crit:
		var clean := player._talent("fire_clean_burn")
		if clean > 0.0:
			info.add_bonus(clean, "Clean Burn")
	if spell:
		var low := low_flame_pct(Stats.crit_chance(tags, func(s): return player.get_stat(s)), player._talent("fire_low_flame"))
		if low > 0.0:
			info.add_bonus(low, "Low Flame")
	if id == FireCasterKit.VENT_ID:
		var big := big_spend_pct(player.fire_fury.last_spent, player._talent("fire_big_spend"))
		if big > 0.0:
			info.add_bonus(big, "Big Spend")
	var costs_fury := Abilities.resource_of(id) == "fury" and (Abilities.cost_of(id) > 0 or id == FireCasterKit.VENT_ID)
	if not info.is_dot and costs_fury and player.fire_caster._my_blaze_on(tgt):
		var kiln := player._talent("fire_stoked_kiln")
		if kiln > 0.0:
			info.add_bonus(kiln, "Stoked Kiln")
	# Slagforged.
	if tags.has("Shield") and tags.has("Ability"):
		var red := player._talent("fire_red_iron")
		if red > 0.0:
			info.add_bonus(red, "Red Iron")
	if player.fire_tank.slag_stacks() >= player.fire_tank.slag_cap() and player.fire_tank.slag_stacks() > 0:
		var seams := player._talent("fire_glowing_seams")
		if seams > 0.0:
			info.threat_multiplier *= 1.0 + seams / 100.0
	# Forge Heat.
	if FireMeleeKit.is_spark(info):
		var bite := player._talent("fire_spark_bite")
		if bite > 0.0:
			info.add_bonus(bite, "Spark Bite")
	if (id == "quench" or id == "flare") and player.fire_melee.last_heat_spent > 0:
		var hard := player._talent("fire_hard_quench") * player.fire_melee.last_heat_spent
		if hard > 0.0:
			info.add_bonus(hard, "Hard Quench")
	if is_burning_tick(id):
		var sear := player._talent("fire_deep_sear")
		if sear > 0.0:
			info.add_bonus(sear, "Deep Sear")
	# Pitch and Cinder.
	var layers: int = player.fire_bow.layers_on(tgt) if tgt is Node else 0
	if is_burning_tick(id):
		var drip := player._talent("fire_dripping")
		if drip > 0.0 and layers >= Balance.DRIPPING_LAYERS:
			info.add_bonus(drip, "Dripping")
		var line := player._talent("fire_fire_line")
		if line > 0.0 and tgt is Node3D and (tgt as Node3D).global_position.distance_to(player.global_position) > Balance.FIRE_LINE_RANGE:
			info.add_bonus(line, "Fire Line")
	if id == FireBowKit.IGNITE_ID:
		var flash := player._talent("fire_big_flash")
		if flash > 0.0:
			info.add_bonus(flash, "Big Flash")
	if is_arrow(id, tags) and layers > 0:
		var patient := player._talent("fire_patient_fire")
		if patient > 0.0 and layers >= Balance.PITCH_MAX_LAYERS:
			info.add_bonus(patient, "Patient Fire")
		var clean_shot := player._talent("fire_clean_shot")
		if clean_shot > 0.0 and not info.crit:
			info.add_bonus(clean_shot, "Clean Shot")
		var black := player._talent("fire_pitch_black") * layers
		if black > 0.0:
			info.add_bonus(black, "Pitch Black")

## A hit on me, before its damage is worked out.
func _fire_talents_incoming(info: RefCounted) -> void:
	# Heat Shimmer: my Slag takes some off every spell.
	var shimmer := player._talent("fire_heat_shimmer") * player.fire_tank.slag_stacks()
	if shimmer > 0.0 and info.tags.has("Spell"):
		info.add_bonus(-shimmer, "Heat Shimmer")

## [pct, label] for a crit of mine (CombatSystem asks through Player.crit_hit_bonus).
func crit_hit_bonus(info: RefCounted) -> Array:
	# Cold Steel: with no Heat held, my melee crits hit harder (a crit while holding
	# Heat is a Spark, so a melee crit always means no Heat).
	var cold := player._talent("fire_cold_steel")
	if cold > 0.0 and info.tags.has("Melee") and not info.is_dot and player.fire_melee.heat_stacks() <= 0:
		return [cold, "Cold Steel"]
	return []

## I just entered combat: Warm Start.
func _on_combat_start() -> void:
	var warm := player._talent("fire_warm_start")
	if warm > 0.0:
		player._gain("fury", warm)
