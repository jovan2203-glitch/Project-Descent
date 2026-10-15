@tool
extends McpTestSuite

# Dungeon system rules: recipes, layouts, party level, modifiers, prestige.

const DB = preload("res://scripts/dungeon/dungeon_db.gd")
const Layouts = preload("res://scripts/dungeon/layouts.gd")
const Names = preload("res://scripts/dungeon/names.gd")
const Roles = preload("res://scripts/dungeon/roles.gd")
const Mods = preload("res://scripts/dungeon/modifiers.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")

func suite_name() -> String:
	return "dungeons"

func test_recipes_load_with_3_to_4_named_bosses() -> void:
	var all := DB.recipes()
	assert_true(all.size() >= 4, "the four starter dungeons exist")
	for r in all:
		assert_true(r.bosses.size() >= 3 and r.bosses.size() <= 4, "%s has 3-4 bosses" % r.id)
		assert_true(Names.has(str(r.name_key)), "%s has a name" % r.id)
		assert_true(r.biome != null, "%s has a biome kit" % r.id)
		var seen := {}
		for b in r.bosses:
			assert_true(Names.has(str(b.get("name", ""))), "boss name key %s" % b.get("name", ""))
			assert_false(seen.has(b["name"]), "bosses are all different")
			seen[b["name"]] = true
			assert_true(ResourceLoader.exists(str(b["skin"]["scene"])), "boss skin scene exists")
		for role in r.roster:
			assert_true(Roles.ROLES.has(str(role)), "%s: roster role %s is a real role" % [r.id, role])
			assert_true(ResourceLoader.exists(str(r.roster[role]["scene"])), "skin scene exists")

func test_legacy_crypt_not_in_random_pool() -> void:
	for r in DB.random_pool():
		assert_ne(str(r.id), "legacy_crypt")
	for i in 30:
		var res := DB.resolve(DB.RANDOM_KEY, i)
		assert_eq(res["path"], DB.RUN_SCENE, "random always picks a recipe dungeon")
	assert_eq(DB.resolve(DB.key_for("legacy_crypt"), 0)["path"], "res://scenes/dungeon.tscn")

func test_party_level_is_weighted_up() -> void:
	assert_eq(DB.party_level([20]), 20, "solo = your level")
	assert_eq(DB.party_level([50, 1]), 38, "a max-level friend drags the level up, not down")
	assert_true(DB.party_level([50, 1, 1, 1, 1]) > 11, "higher than the plain average")

func test_layouts_are_trees_with_every_boss() -> void:
	for style in ["linear", "hub", "descent", "cavern", "arena", "maze"]:
		for bosses in [3, 4]:
			var rng := RandomNumberGenerator.new()
			rng.seed = 42 + bosses
			var l := Layouts.build(style, rng, bosses, 2)
			var rooms: Array = l["rooms"]
			assert_eq(l["links"].size(), rooms.size() - 1, "%s: a tree (every room reachable once)" % style)
			var found := {}
			for r in rooms:
				if int(r["boss"]) >= 0:
					found[int(r["boss"])] = true
			assert_eq(found.size(), bosses, "%s: one room per boss" % style)
			var cells := {}
			for r in rooms:
				assert_false(cells.has(r["cell"]), "%s: no two rooms on one cell" % style)
				cells[r["cell"]] = true

func test_layouts_are_seeded() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 777
	b.seed = 777
	var la := Layouts.build("maze", a, 3, 2)
	var lb := Layouts.build("maze", b, 3, 2)
	assert_eq(str(la["links"]), str(lb["links"]), "same seed, same dungeon (party sync)")

func test_modifier_roll_is_seeded_and_unique() -> void:
	var pool := Array(Mods.ALL)
	var x := Mods.roll(pool, 2, 99)
	var y := Mods.roll(pool, 2, 99)
	assert_eq(str(x), str(y))
	assert_eq(x.size(), 2)
	assert_ne(x[0], x[1])
	for m in Mods.ALL:
		assert_true(Names.has("mod_" + m) and Names.has("mod_%s_desc" % m), "modifier %s has text" % m)

func test_prestige_keeps_only_starter_abilities() -> void:
	var pd: Node = track(PlayerDataScript.new())
	pd._ready()
	pd.level = 30
	pd.learn_ability("frostnova")
	pd.action_bar[5] = "frostnova"
	var d: Dictionary = pd.prestige()
	assert_eq(pd.level, 1)
	assert_eq(pd.xp, 0)
	assert_eq(int(d["old_level"]), 30)
	assert_false(pd.has_ability("frostnova"), "learned abilities forgotten")
	assert_false(pd.action_bar.has("frostnova"))
	assert_true(pd.has_ability("frostbolt"), "starter kit stays")
