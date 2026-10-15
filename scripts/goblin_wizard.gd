extends "res://scripts/goblin.gd"

# Goblin Wizard: casts slow, hard-hitting firebolts from range. Each cast has a
# visible wind-up (its staff glows, "Casting Firebolt" overhead) - interrupt it
# (Counterspell, Kick, Pummel) or get out of range / line of sight before it
# finishes and the bolt fizzles. Very fragile in melee.
# Ranged behaviour is the shared enemy.gd one (projectile = "bolt").

func _init() -> void:
	super._init()
	display_name = "Goblin Wizard"
	elite_name = "Goblin Firecaller"
	boss_name = "Goblin Archmage"
	max_health = 3           # goblin: 4
	move_speed = 2.8
	contact_damage = 1.5     # per firebolt
	attack_cooldown = 3.0    # includes the cast
	attack_windup = 1.2      # cast time before the bolt flies
	attack_range = 14.0
	aggro_radius = 9.0
	xp_reward = 10
	projectile = "bolt"
	projectile_color = Color(1.0, 0.42, 0.12)
	cast_name = "Firebolt"
	projectile_damage_type = "fire"
	projectile_tags = PackedStringArray(["Fire", "Spell", "Ranged"])
