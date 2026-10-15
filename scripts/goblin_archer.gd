extends "res://scripts/goblin.gd"

# Goblin Archer: hangs back and shoots arrows from range. Fragile - close the
# gap or break line of sight (it has to walk around to see you again).
# Ranged behaviour is the shared enemy.gd one (projectile = "arrow").

func _init() -> void:
	super._init()
	display_name = "Goblin Archer"
	elite_name = "Goblin Sharpshooter"
	boss_name = "Goblin Deadeye"
	max_health = 3           # goblin: 4
	move_speed = 3.0
	contact_damage = 0.8     # per arrow
	attack_cooldown = 1.7
	attack_range = 12.0      # shoots from here (needs line of sight)
	aggro_radius = 9.0       # spots you from further away than a melee goblin
	xp_reward = 9
	projectile = "arrow"
	projectile_damage_type = "physical"
	projectile_tags = PackedStringArray(["Physical", "Ranged"])
	model_tint = Color(0.92, 1.0, 0.9)
