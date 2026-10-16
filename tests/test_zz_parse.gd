@tool
extends McpTestSuite

# Smoke test: every dungeon recipe builds its layout, rock and dressing, and
# every roster skin / boss can be made. Runs without playing the game.

const DB = preload("res://scripts/dungeon/dungeon_db.gd")
const Layouts = preload("res://scripts/dungeon/layouts.gd")
const Builder = preload("res://scripts/dungeon/biome_builder.gd")
const Roles = preload("res://scripts/dungeon/roles.gd")

func suite_name() -> String:
	return "zz_parse"

func test_scripts_parse() -> void:
	for f in ["res://scripts/dungeon/rock_chunker.gd", "res://scripts/dungeon/dungeon_run.gd", "res://scripts/dungeon/dungeon.gd",
			"res://scripts/enemy.gd", "res://scripts/player.gd", "res://scripts/dungeon/flicker_light.gd",
			"res://scripts/game_ui.gd", "res://scripts/ui/map_view.gd", "res://scripts/ui/map_data.gd",
			"res://scripts/dungeon/biome_builder.gd", "res://scripts/main_menu.gd", "res://scripts/hud.gd",
			"res://scripts/net/net.gd", "res://scripts/player_data.gd", "res://scripts/core/status_container.gd",
			"res://scripts/abilities.gd", "res://scripts/talents.gd", "res://scripts/talent_icons.gd",
			"res://scripts/runes.gd", "res://scripts/balance.gd", "res://scripts/fire_wall.gd",
			"res://scripts/core/combat_system.gd", "res://scripts/data/status_effect_data.gd",
			"res://scripts/rune_listener.gd", "res://scripts/ui/talent_tree_view.gd", "res://scripts/categories.gd",
			"res://scripts/data/rune_data.gd", "res://scripts/core/damage_info.gd", "res://scripts/frost_bolt.gd",
			"res://scripts/crucible.gd", "res://scripts/skill_cards.gd", "res://scripts/ball_lightning.gd",
			"res://scripts/thunderhead.gd", "res://scripts/live_wire.gd", "res://scripts/lash.gd"]:
		var s: GDScript = ResourceLoader.load(f, "", ResourceLoader.CACHE_MODE_REPLACE)
		assert_true(s != null and s.reload(true) == OK, "parses: " + f)

func test_menu_parts_parse() -> void:
	# Every part of the main menu (scripts/menu/parts.txt: var Class file) parses; its typed
	# `menu` makes a reference to something the menu doesn't have a parse error.
	for line in FileAccess.get_file_as_string("res://scripts/menu/parts.txt").split("\n", false):
		var parts := line.split(" ", false)
		if parts.size() != 3:
			continue
		var f := "res://scripts/menu/" + parts[2]
		var s: GDScript = ResourceLoader.load(f, "", ResourceLoader.CACHE_MODE_REPLACE)
		assert_true(s != null and s.reload(true) == OK, "parses: " + f)
		assert_eq(str(s.get_global_name()), parts[1], f + " is class " + parts[1])

func test_build_every_dungeon() -> void:
	for r in DB.recipes():
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var l := Layouts.build(str(r.layout), rng, r.bosses.size(), int(r.rooms_per_section))
		var root := Node3D.new()
		var b = Builder.new(r.biome, l, 5)
		b.darkness = true
		var rock: CSGCombiner3D = b.build_rock(root)
		b.dress(root)
		var env := Environment.new()
		b.apply_environment(env)
		assert_true(rock.get_child_count() > l["rooms"].size(), "%s: rock built" % r.id)
		assert_true(root.get_child_count() > 5, "%s: dressed" % r.id)
		var meshes := root.find_children("*", "MeshInstance3D", true, false).size()
		var lights := root.find_children("*", "OmniLight3D", true, false).size()
		assert_true(meshes < 600, "%s: decoration merged (%d meshes, %d lights)" % [r.id, meshes, lights])
		assert_true(lights < 150, "%s: light budget (%d lights)" % [r.id, lights])
		root.free()

## Enemy scripts aren't @tool, so the editor only makes placeholder instances:
## this check can't run here (kept for a future in-game test runner).
func _make_every_enemy_and_boss() -> void:
	for r in DB.recipes():
		for role in r.roster:
			var e: Node3D = load(str(r.roster[role]["scene"])).instantiate()
			Roles.apply(e, str(role), r.roster[role])
			e.apply_rank("elite", 20)
			assert_true(e.max_health > 0, "%s %s" % [r.id, role])
			e.free()
		for bd in r.bosses:
			var skin: Dictionary = bd["skin"]
			var e: Node3D = load(str(skin["scene"])).instantiate()
			if str(bd.get("role", "")) != "":
				Roles.apply(e, str(bd["role"]), skin)
			e.boss_scale *= float(skin.get("scale", 1.0))
			e.apply_rank("boss", 20)
			var kit := Node.new()
			kit.set_script(preload("res://scripts/dungeon/boss_kit.gd"))
			kit.abilities = Array(bd.get("abilities", []))
			e.add_child(kit)
			assert_true(kit.abilities.size() >= 2, "%s has a moveset" % bd["name"])
			e.free()
