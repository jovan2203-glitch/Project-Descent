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
	assert_eq(bells, 4, "bells in the Gatehouse, Courtyard, Archive and Siege Yard")
	for key in r.rosters:
		for role in r.rosters[key]:
			assert_true(Roles.ROLES.has(str(role)), "%s: %s is a real role" % [key, role])
			assert_true(Names.has(str(r.rosters[key][role]["name"])), "%s: skin name" % key)

func _fort_builder(l: Dictionary) -> RefCounted:
	return load("res://scripts/dungeon/biome_builder.gd").new(DB.find("fort").biome, l, 1)

## Points every half metre over a rect (x/z), for door-lane checks.
func _rect_points(c: Vector3, size: Vector2) -> Array:
	var out: Array = []
	var x := -size.x * 0.5
	while x <= size.x * 0.5 + 0.01:
		var z := -size.y * 0.5
		while z <= size.y * 0.5 + 0.01:
			out.append(c + Vector3(x, 0, z))
			z += 0.5
		x += 0.5
	return out

func test_fort_markers_stand_on_open_floor() -> void:
	var l := _fort()
	var b := _fort_builder(l)
	var rooms: Array = l["rooms"]
	for i in rooms.size():
		var r: Dictionary = rooms[i]
		var half: Vector2 = r["size"] * 0.5
		var spots: Array = []
		for p in r["packs"]:
			spots.append(["pack", p["at"]])
		for p in r["props"]:
			spots.append(["prop " + str(p["kind"]), p["at"]])
		for p in r["pieces"]:
			if p["kind"] != "wall":
				spots.append([str(p["kind"]), p["at"]])
		for s in spots:
			var at: Vector3 = s[1]
			var rel := Vector2(at.x - r["center"].x, at.z - r["center"].z)
			assert_true(absf(rel.x) <= half.x - 0.4 and absf(rel.y) <= half.y - 0.4, "%s: %s is inside the room" % [r["name"], s[0]])
			for rc: Rect2 in b.wall_blocks(i):
				assert_false(rc.has_point(Vector2(at.x, at.z)), "%s: %s is not inside a wall block" % [r["name"], s[0]])

func test_fort_walls_and_blocking_props_leave_doorways_clear() -> void:
	var l := _fort()
	var b := _fort_builder(l)
	var rooms: Array = l["rooms"]
	for i in rooms.size():
		var r: Dictionary = rooms[i]
		var areas: Array = []   # [what, center, size]
		for p in r["pieces"]:
			if p["kind"] == "wall":
				areas.append(["wall", p["at"], p["params"].get("size", Vector2(2, 2))])
		for p in r["props"]:
			assert_true(b.BIG.has(str(p["kind"])), "%s: prop kind %s exists" % [r["name"], p["kind"]])
			var info: Dictionary = b.BIG.get(str(p["kind"]), {})
			if info.get("block", false):
				var across_x := absf(sin(float(p["yaw"]))) > 0.5
				var size := Vector2(info["d"], info["w"]) if across_x else Vector2(info["w"], info["d"])
				areas.append([str(p["kind"]), p["at"], size])
		for a in areas:
			var bad := false
			for q in _rect_points(a[1], a[2]):
				if b.in_door_lane(i, q, 0.0):
					bad = true
			assert_false(bad, "%s: %s stays out of the doorway lanes" % [r["name"], a[0]])

func test_fort_pack_formations_are_known() -> void:
	for r in _fort()["rooms"]:
		for p in r["packs"]:
			assert_true(str(p["formation"]) in ["ring", "around", "line"], "%s: formation %s" % [r["name"], p["formation"]])

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
	assert_eq(BossKit.soak_share(100.0, 3, 3, 3, 4), 100.0, "need 4, only 3 alive: all three split 300")
	assert_eq(BossKit.soak_share(100.0, 5, 3, 3, 4), 400.0 / 3.0, "need 4: three of five inside still split 400")
	assert_eq(BossKit.soak_share(100.0, 5, 5, 3, 4), 80.0, "need 4: five inside split 400")
	assert_gt(BossKit.soak_share(0.1, 5, 5), 0.0, "never 0")

func test_berserk_timer_starts_stops_and_hits() -> void:
	var e: Node3D = track(load("res://scripts/enemy.gd").new())
	e.set_berserk(160.0, 160.0, false)
	assert_gt(float(e.berserk_at), Time.get_ticks_msec() / 1000.0 + 150.0, "running: hits in ~160 s")
	assert_false(e.berserk_on)
	e.set_berserk(0.0, 160.0, true)
	assert_true(e.berserk_on, "it hit")
	assert_gt(float(e.berserk_at), 0.0, "still shown once it hit")
	e.set_berserk(0.0, 0.0, false)
	assert_eq(float(e.berserk_at), 0.0, "a wipe or reset stops it")
	var hud := HudSource.text()
	assert_true(hud.contains("\"boss_timer\""), "the Boss Timer is a HUD element")

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
