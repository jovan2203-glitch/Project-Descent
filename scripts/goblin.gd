extends "res://scripts/enemy.gd"

# Goblin: small, fast and fragile. Quick jabs for low damage - dangerous in
# groups, easy to pick off alone. Everything else (AI, pathing, threat,
# animation, elite/boss ranks, loot, networking) comes from enemy.gd.
#
# Look: a procedural low-poly goblin on a Mixamo rig (scenes/models/
# goblin_model.tscn), at goblin height (~1.25 m). Swap that model scene for
# real art later; keep the rig humanoid so the animation files still fit.

func _init() -> void:
	display_name = "Goblin"
	elite_name = "Goblin Brute"
	boss_name = "Goblin Warchief"
	max_health = 4           # zombie: 6
	move_speed = 3.3         # zombie: 2.2 - goblins close in fast
	contact_damage = 1
	attack_cooldown = 0.7    # quick jabs (zombie: 1.0)
	attack_range = 0.9
	aggro_radius = 6.5       # sharper senses than a zombie (5.0)
	leash_radius = 16.0
	turn_speed = 14.0
	xp_reward = 8
	health_bar_height = 0.95
	animation_files = {"walk": ["res://assets/goblin/Walking.fbx", "res://assets/zombie/Walking.fbx",
		"res://assets/player/Walking.fbx"]}
	walk_anim_base_speed = 3.0
