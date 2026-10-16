extends "res://scripts/player/player_kit.gd"
class_name FrostfireKit

# Moved out of scripts/player.gd as it was (player = the player node). Hooked up from
# player.gd through its var "frostfire_kit".
# --- Frostfire Bolt (taught by the Rune of Frostfire Bolt) ----------------------------
# A Frost Bolt's damage as two hits that land together: half Frost, half Fire.
# Each half is a hit of its own school (its own crit roll, its school's talents,
# runes and procs), and both carry the spell's id, which counts as a Frost Bolt
# AND a Firebolt (Abilities.is_a) for anything that names either.

const FROSTFIRE := "frostfirebolt"

## The two hits of a Frostfire Bolt of coefficient `base`: [[coefficient, damage type, tags], ...].
static func frostfire_halves(base: float) -> Array:
	var frost := base * Balance.FROSTFIRE_FROST_SHARE
	return [[frost, "frost", PackedStringArray(["Frost", "Spell", "Projectile"])],
		[base - frost, "fire", PackedStringArray(["Fire", "Spell", "Projectile"])]]

func _frostfire_hit(enemy: Node, base: float, is_proc: bool) -> int:
	var total := 0
	var halves := frostfire_halves(base)
	for i in halves.size():
		if not is_instance_valid(enemy) or not enemy.is_alive():
			break
		var info := DamageInfo.make(player, enemy, float(halves[i][0]), FROSTFIRE)
		info.damage_type = str(halves[i][1])
		info.tags = halves[i][2]
		info.is_proc = is_proc
		info.part = i + 1
		player._combat().deal(info)
		total += int(info.amount)
	return total

## Extra effects some abilities have when they land. Not for procs, so chain /
## splash hits (dealt as procs) never chain again.
func _on_hit_extra(enemy: Node, at: Vector3, id: String) -> void:
	match id:
		VenomstringKit.FANG_ARROW_ID:
			player.venomstring._fang_landed(enemy)   # Nature archer: my poisons on it last longer
		WeaverKit.THORNSHOT_ID:
			player.weaver._thornshot_landed(enemy, at)   # Nature caster: Thornburst, and every few a patch of mulch
		"chainlightning":
			# Leaping Arc: it leaps to the nearest other enemies. A leap with no new
			# enemy to reach comes back to the target instead, weaker.
			var others := player._enemies_near(at, float(Abilities.get_resource(id).radius), enemy)
			var leaps := mini(others.size(), Balance.LEAPING_ARC_JUMPS)
			var jump := float(Abilities.EXTRA_HITS[id])
			for i in leaps:
				Player.FROST_BOLT.spawn(player.get_tree().current_scene, at + Vector3(0, 0.3, 0), others[i], player, true, id, jump)
			for i in LightningCasterKit.arc_returns(others.size()):
				player.deal_damage(enemy, LightningCasterKit.arc_return_coef(jump), id, true)
		"stormshield":
			var jumps := 0
			for e in player._enemies_near(at, float(Abilities.get_resource(id).radius), enemy):
				Player.FROST_BOLT.spawn(player.get_tree().current_scene, at + Vector3(0, 0.3, 0), e, player, true, id,
					float(Abilities.EXTRA_HITS[id]))
				jumps += 1
				if jumps >= Balance.CHAIN_JUMPS:
					break
		"returnstroke":
			# Counter-Charge's capstone: the answer arcs on to nearby enemies.
			if player.frost_melee._capstone("lightning_counter_charge"):
				var arcs := 0
				for e in player._enemies_near(at, Balance.COUNTER_CHARGE_REACH, enemy):
					if arcs >= Balance.COUNTER_CHARGE_JUMPS:
						break
					Player.FROST_BOLT.spawn(player.get_tree().current_scene, at + Vector3(0, 0.3, 0), e, player, true, id,
						Balance.COUNTER_CHARGE_ARC)
					arcs += 1
		"stormarrow":
			# Lightning Rod: the arrow stays stuck in the target (the effect goes
			# through the combat pipeline, so in a party it reaches the host).
			if player._talent("lightning_rod") > 0.0:
				player.fire_caster._apply_effect_hit(enemy, preload("res://scripts/core/effects.gd").get_effect(LightningCasterKit.ROD_FX), LightningCasterKit.ROD_FX,
					PackedStringArray(["Lightning"]), "lightning")
			var r := float(Abilities.get_resource(id).radius)
			for e in player._enemies_near(at, r, enemy):
				player.deal_damage(e, float(Abilities.EXTRA_HITS[id]), id, true)
			player._ring_effect(r, Abilities.color_of(id), at)
		"shattershot":
			player.frost_bow._shatter_shot_landed(enemy, at)   # on a target I had Frozen: it thaws and the ice bursts
		"shadowstrike":
			# Share the Kill: Leeching Strike heals for more while my Hounds are out.
			player.heal(float(Abilities.HEALS[id]) * HoundsKit.leech_heal_mult(player.hounds.hounds_out(), player._talent("shadow_share_the_kill")), id)

# Instant, free cast triggered by an rune (e.g. Rune of Frost).
func proc_cast(ability_id: String, enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
		return
	match ability_id:
		"frostbolt":
			Player.FROST_BOLT.spawn(player.get_tree().current_scene, player._muzzle(), enemy, player, true)
		_:
			var base := float(Abilities.get_resource(ability_id).damage) if Abilities.get_resource(ability_id) else 1.0
			player.deal_damage(enemy, base, ability_id, true)

func _float_text(at: Node3D, text: String, color: Color, big: bool) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 64 if big else 44
	l.pixel_size = 0.006
	l.outline_size = 12
	l.modulate = color
	player.get_tree().current_scene.add_child(l)
	l.global_position = at.global_position + Vector3(randf_range(-0.3, 0.3), 1.5, 0)
	var t := l.create_tween()
	t.set_parallel(true)
	t.tween_property(l, "global_position:y", l.global_position.y + 0.9, 0.8)
	t.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	t.chain().tween_callback(l.queue_free)

