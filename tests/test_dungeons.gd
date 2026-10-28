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

# --- Downgate Fort (hand-made map) -------------------------------------------------------

const BossKit = preload("res://scripts/dungeon/boss_kit.gd")
const Look = preload("res://scripts/dungeon/mechanic_look.gd")
const Stairs = preload("res://scripts/dungeon/pieces/stairs.gd")

func _fort() -> Dictionary:
	return Layouts.from_scene(DB.find("fort").layout_scene)

func test_fort_map_is_a_tree_of_neighbouring_rooms() -> void:
	var l := _fort()
	var rooms: Array = l["rooms"]
	assert_eq(rooms[0]["kind"], "start", "the first room is the start")
	assert_eq(l["links"].size(), rooms.size() - 1, "a tree: every room reachable once")
	assert_true(l.get("final_needs_wings", false), "the Keep needs the three wing bosses")
	var cells := {}
	for r in rooms:
		assert_false(cells.has(r["cell"]), "no two rooms on one cell")
		cells[r["cell"]] = true
		assert_true(r["size"].x <= float(l["cell"]) - 2.0 and r["size"].y <= float(l["cell"]) - 2.0, "%s fits its cell" % r["name"])
		assert_true(Names.has(str(r["name"])), "room name %s" % r["name"])
	for link in l["links"]:
		var d: Vector2i = rooms[link[1]]["cell"] - rooms[link[0]]["cell"]
		assert_eq(absi(d.x) + absi(d.y), 1, "linked rooms are neighbours (%s -> %s)" % [rooms[link[0]]["name"], rooms[link[1]]["name"]])
	var bosses := {}
	for r in rooms:
		if int(r["boss"]) >= 0:
			bosses[int(r["boss"])] = true
			assert_eq(r["kind"], "boss")
			assert_eq(int(r["section"]), int(r["boss"]), "a boss room ends its own section")
	assert_eq(bosses.size(), 4, "four boss rooms")

func test_fort_map_is_the_same_every_load() -> void:
	assert_eq(str(_fort()["links"]), str(_fort()["links"]))

func test_fort_packs_and_pieces_are_valid() -> void:
	var r := DB.find("fort")
	var l := _fort()
	var bells := 0
	for room in l["rooms"]:
		var key := str(room["roster"])
		var roster: Dictionary = r.rosters.get(key, r.roster)
		assert_true(key == "" or r.rosters.has(key), "roster %s exists" % key)
		for pack in room["packs"]:
			for role in pack["roles"]:
				assert_true(roster.has(str(role)), "%s: role %s is in its roster" % [room["name"], role])
		for pc in room["pieces"]:
			if pc["kind"] == "alarm_bell":
				bells += 1
			if pc["kind"] in ["ballista", "seal_light"]:
				var b := int(pc["params"].get("boss", -1))
				assert_true(b >= 0 and b < r.bosses.size(), "%s points at a real boss" % pc["kind"])
	assert_eq(bells, 2, "a bell in the Gatehouse and one in the Courtyard")
	for key in r.rosters:
		for role in r.rosters[key]:
			assert_true(Roles.ROLES.has(str(role)), "%s: %s is a real role" % [key, role])
			assert_true(Names.has(str(r.rosters[key][role]["name"])), "%s: skin name" % key)

func test_fort_has_stairs_down_from_the_bindery() -> void:
	var rooms: Array = _fort()["rooms"]
	assert_gt(float(rooms[0]["center"].y), float(rooms[1]["center"].y), "the Long Stair goes down into the fort")

func test_every_boss_ability_is_known_and_named() -> void:
	for r in DB.recipes():
		for b in r.bosses:
			var phases := {1: true}
			for a in b["abilities"]:
				if str(a.get("type", "")) == "phase" and a.has("to"):
					phases[int(a["to"])] = true
			for a in b["abilities"]:
				var t := str(a.get("type", ""))
				assert_true(Look.FAMILY.has(t), "%s: ability type %s has a mechanic family" % [r.id, t])
				if a.has("name"):
					assert_true(Names.has(str(a["name"])), "%s: ability name %s" % [r.id, a["name"]])
				if a.has("phase"):
					assert_true(phases.has(int(a["phase"])), "%s: phase %d is reached by a phase entry" % [r.id, int(a["phase"])])

func test_stack_damage_is_shared_evenly_and_never_zero() -> void:
	assert_eq(BossKit.soak_share(100.0, 1, 1), 100.0, "solo: you take the hit")
	assert_eq(BossKit.soak_share(100.0, 5, 3), 100.0, "3 of 5 stack: 300 split three ways")
	assert_eq(BossKit.soak_share(100.0, 5, 5), 60.0, "everyone stacks: 300 split five ways")
	assert_eq(BossKit.soak_share(100.0, 5, 1), 300.0, "alone in it: you take all of it")
	assert_eq(BossKit.soak_share(100.0, 5, 0), 300.0, "nobody in it: everyone takes all of it")
	assert_gt(BossKit.soak_share(0.1, 5, 5), 0.0, "never 0")

func test_stairs_steps_follow_the_slope() -> void:
	for h: float in [2.0, 3.0, 4.0]:
		var run := h * 3.0
		var n := Stairs.step_count(h)
		assert_true(h / n <= Stairs.STEP_RISE + 0.001, "risers stay under the navmesh climb")
		for i in n:
			var s: Array = Stairs.step_box(i, run, h)
			var mid_z := (float(s[1]) + float(s[2])) * 0.5
			var slope := h * (-mid_z) / run
			assert_true(absf(float(s[0]) - slope) <= h / n + 0.001, "step %d sits on the slope" % i)
		assert_eq(float(Stairs.step_box(n - 1, run, h)[0]), h, "the top step is flush with the upper floor")
