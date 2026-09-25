extends "res://scripts/enemy.gd"

# Zombie: everything (AI, pathing, threat, animation, ranks, loot, networking)
# comes from enemy.gd. This only sets the zombie's base stats and files.
# (The same values could also be set in the scene's Inspector instead.)

func _init() -> void:
	max_health = 6
	display_name = "Zombie"
	boss_name = "Zombie Lord"
	xp_reward = 10
	# Drops come from a data file (each item rolls separately at 90%, with rarity).
	loot = load("res://data/loot/zombie.tres")
	# Dedicated zombie walk if present, otherwise the player's walk.
	animation_files = {"walk": ["res://assets/zombie/Walking.fbx", "res://assets/player/Walking.fbx"]}
	walk_anim_base_speed = 3.0
