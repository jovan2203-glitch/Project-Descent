extends Node3D

# Generic dungeon runner: builds and runs ANY dungeon recipe (data/dungeons/).
#
#   recipe (GameManager.dungeon_id) -> layout style (layouts.gd) -> rooms built
#   from the biome kit (biome_builder.gd) -> packs from the roster (roles.gd) ->
#   sections with objectives -> 3-4 bosses (boss_kit.gd) -> exit portal.
#
# A dungeon has a start and an end. It's split into SECTIONS, one per boss:
# clear the section's objective and the gate into its boss room opens; kill the
# boss and the way onwards opens. The last boss opens the exit portal.
#
# Enemy level = GameManager.dungeon_level (the party's average pulled toward
# its highest level). Dungeon modifiers (GameManager.dungeon_modifiers) are
# shown when you load in.
#
# Multiplayer: every machine builds the same dungeon from the run seed. The
# host (or solo player) decides everything that happens (objectives, gates,
# bosses, waves, summons) and tells the party through Net.dungeon_event();
# party members react in net_event().

const Names = preload("res://scripts/dungeon/names.gd")
const Roles = preload("res://scripts/dungeon/roles.gd")
const Mods = preload("res://scripts/dungeon/modifiers.gd")
const Layouts = preload("res://scripts/dungeon/layouts.gd")
const Builder = preload("res://scripts/dungeon/biome_builder.gd")
const DB = preload("res://scripts/dungeon/dungeon_db.gd")
const BOSS_KIT = preload("res://scripts/dungeon/boss_kit.gd")
const FX = preload("res://scripts/dungeon/boss_abilities.gd")
const Look = preload("res://scripts/dungeon/mechanic_look.gd")
const SET_PIECES = preload("res://scripts/dungeon/set_pieces.gd")
const ELITE_TRAITS = preload("res://scripts/core/elite_traits.gd")
const CHEST = preload("res://scripts/dungeon/chest.gd")
const UI = preload("res://scripts/ui_kit.gd")

const MAX_PACK := 7
const DEFEND_RADIUS := 3.2
const DEFEND_SPAWN_EVERY := 9.0
const WAVE_GAP := 2.5

@onready var player: Node3D = $Player
@onready var level_root: Node3D = $Level
@onready var enemies_root: Node3D = $Enemies
@onready var nav: NavigationRegion3D = $Navigation

var recipe: Resource
var rng := RandomNumberGenerator.new()
var seed_used := 0
var enemy_level := 1
var modifiers: Array = []
var layout := {}
var rooms: Array = []
var links: Array = []
var sections: Array = []      # per boss: {objective, done, active, rooms, total, killed, keys, ...}
var bosses: Array = []        # boss nodes (null until spawned)
var boss_started: Array = []
var boss_dead: Array = []
var boss_rooms: Array = []    # boss index -> room index
var gates: Array = []         # {body, shape, mesh, label, kind: "entry"/"exit", boss}
var _chests := {}             # for the map
var _exit_pos := Vector3.ZERO
var _exit_mat: StandardMaterial3D
var _exit_light: OmniLight3D
var _complete := false
var _safe_room := 0
var _add_serial := 0
var _builder: RefCounted
var _set_pieces: Node
var map_title := ""

# Run stats for the clear screen.
var _start_time := 0.0
var _kills := 0
var _loot := 0
var _xp := 0

# --- Setup ---------------------------------------------------------------------------------

func _ready() -> void:
	var gm := get_node_or_null("/root/GameManager")
	var id := str(gm.dungeon_id) if gm else ""
	recipe = DB.find(id)
	if recipe == null:
		var all := DB.recipes()
		recipe = all[0] if not all.is_empty() else null
	if recipe == null:
		push_error("dungeon_run: no dungeon recipes in %s" % DB.RECIPE_DIR)
		return
	seed_used = int(gm.dungeon_seed) if gm and int(gm.dungeon_seed) != 0 else randi()
	rng.seed = seed_used
	enemy_level = int(gm.dungeon_level) if gm else 1
	modifiers = Array(gm.dungeon_modifiers) if gm else []
	map_title = Names.t(str(recipe.name_key))
	var boss_count := clampi(recipe.bosses.size(), 1, 4)
	if recipe.layout_scene:
		layout = Layouts.from_scene(recipe.layout_scene)
	else:
		layout = Layouts.build(str(recipe.layout), rng, boss_count, int(recipe.rooms_per_section))
	rooms = layout["rooms"]
	links = layout["links"]
	for k in boss_count:
		bosses.append(null)
		boss_started.append(false)
		boss_dead.append(false)
		boss_rooms.append(-1)
	for i in rooms.size():
		if int(rooms[i]["boss"]) >= 0:
			boss_rooms[int(rooms[i]["boss"])] = i
	_setup_sections(boss_count)
	# Geometry + look.
	var kit: Resource = recipe.biome
	_builder = Builder.new(kit, layout, seed_used)
	Look.theme = kit.mechanic_theme if kit else null
	# Finished art (a hand-made map's art_scene) replaces the generated greybox.
	var art: Node3D = recipe.art_scene.instantiate() if recipe.art_scene else null
	var rock: CSGCombiner3D = null
	if art:
		level_root.add_child(art)
	else:
		rock = _builder.build_rock(level_root)
		_builder.dress(level_root)
	var we := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		we.environment = we.environment.duplicate()
		_builder.apply_environment(we.environment)
	_build_gates()
	_build_boss_triggers()
	_build_exit()
	_build_objective_markers()
	_populate()
	_set_pieces = SET_PIECES.new()
	_set_pieces.name = "SetPieces"
	_set_pieces.dungeon = self
	add_child(_set_pieces)
	_set_pieces.build()
	# Player start.
	var offset: Vector3 = _net().spawn_offset() if _net() else Vector3.ZERO
	player.global_position = rooms[0]["center"] + Vector3(0, 1.0, 0) + offset
	# Navmesh (every level of a descent).
	var lo := 0.0
	var hi := 0.0
	var ext := 0.0
	for r in rooms:
		var c: Vector3 = r["center"]
		lo = minf(lo, c.y)
		hi = maxf(hi, c.y)
		ext = maxf(ext, maxf(absf(c.x), absf(c.z)) + maxf(r["size"].x, r["size"].y))
	nav.bake_half_extent = ext + 12.0
	nav.bake_min_y = lo - 1.0
	nav.bake_max_y = hi + 1.5
	# On a descent the tops of the lower levels' walls are inside that height
	# band: without this they were baked as floor and drawn on the map as rooms.
	nav.floor_filter = func(p: Vector3) -> bool: return _builder.is_floor(p) or _set_pieces.is_floor(p)   # + platform tops and stairs
	nav.bake_from(rock if rock else art)
	# Performance: once the navmesh is baked, split the rock into per-cell meshes.
	var start_chunker := func():
		var ch := Node.new()
		ch.set_script(preload("res://scripts/dungeon/rock_chunker.gd"))
		ch.rock = rock
		ch.cell = float(layout.get("cell", 22.0))
		add_child(ch)
	if rock:
		nav.bake_finished.connect(start_chunker, CONNECT_ONE_SHOT)
	_build_ui()
	var bus := get_node("/root/SignalBus")
	bus.enemy_died.connect(_on_enemy_died)
	bus.player_died.connect(_on_local_death)
	bus.item_looted.connect(func(_i): _loot += 1)
	bus.xp_gained.connect(func(n): _xp += int(n))
	_start_time = _now()
	var gl := get_node_or_null("/root/GameLog")
	if gl:
		gl.info("dungeon", "%s generated (%s, seed %d, %d rooms, enemy level %d, modifiers %s)" % [
			map_title, recipe.layout, seed_used, rooms.size(), enemy_level, str(modifiers)])
		gl.event("Entered %s — enemy level %d" % [map_title, enemy_level], Color(0.95, 0.75, 0.35))
		for m in modifiers:
			gl.event("Modifier — %s: %s" % [Mods.title(m), Mods.desc(m)], Mods.color(m))
	_show_modifier_banner()
	_update_header()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## Sections: one per boss. Objective from the recipe (cycled); the special
## rooms for waves / defend are picked here.
func _setup_sections(boss_count: int) -> void:
	var objs: Array = Array(recipe.objectives)
	if objs.is_empty():
		objs = ["clear_pct"]
	for k in boss_count:
		var obj := str(objs[k % objs.size()])
		if k == boss_count - 1 and layout.get("final_needs_wings", false):
			obj = "wing_bosses"
		var sec := {"objective": obj, "done": false, "active": false, "rooms": [], "total": 0, "killed": 0,
			"keys": 0, "wave": -1, "wave_alive": 0, "progress": 0.0, "timer_end": 0.0, "bonus": false,
			"special": -1, "next_spawn": 0.0, "spawned": 0}
		sections.append(sec)
	for i in rooms.size():
		var s := int(rooms[i]["section"])
		if s >= 0 and s < sections.size() and int(rooms[i]["boss"]) < 0:
			sections[s]["rooms"].append(i)
	for k in sections.size():
		var sec: Dictionary = sections[k]
		if sec["objective"] == "survive_waves" or sec["objective"] == "defend":
			var best := -1
			# A hand-made map can mark the spot (SetPieceMarker defend_spot).
			for i in sec["rooms"]:
				for pc in rooms[i].get("pieces", []):
					if str(pc["kind"]) == "defend_spot" and best < 0:
						best = i
						sec["spot"] = pc["at"]
			for i in sec["rooms"]:
				if sec.has("spot"):
					break
				if rooms[i]["kind"] == "combat" and (best < 0 or rooms[i]["size"].x * rooms[i]["size"].y > rooms[best]["size"].x * rooms[best]["size"].y):
					best = i
			if best < 0:
				sec["objective"] = "reach_exit"
			else:
				sec["special"] = best
				rooms[best]["kind"] = "arena" if sec["objective"] == "survive_waves" else "channel"
				if sec["objective"] == "survive_waves":
					rooms[best]["size"] = rooms[best]["size"].max(Vector2(16, 16))

# --- Enemies ---------------------------------------------------------------------------------

## Room ri's roster: its own (recipe.rosters[room.roster]) or the main one.
func _roster(ri: int) -> Dictionary:
	if ri >= 0 and ri < rooms.size():
		var key := str(rooms[ri].get("roster", ""))
		if key != "" and recipe.rosters.has(key):
			return recipe.rosters[key]
	return recipe.roster

func _roster_skin(role: String, ri := -1) -> Dictionary:
	var roster := _roster(ri)
	if roster.has(role):
		return roster[role]
	if recipe.roster.has(role):
		return recipe.roster[role]
	# A role the roster doesn't have: dress it as the first skin.
	for k in roster:
		return roster[k]
	return {"scene": "res://scenes/zombie.tscn"}

func _pick_role(r: RandomNumberGenerator, allow_swarm := true, ri := -1) -> String:
	var total := 0.0
	var roster := _roster(ri)
	for k in roster:
		if allow_swarm or k != "swarmer":
			total += float(roster[k].get("weight", 1.0))
	var roll := r.randf() * total
	for k in roster:
		if not allow_swarm and k == "swarmer":
			continue
		roll -= float(roster[k].get("weight", 1.0))
		if roll <= 0.0:
			return str(k)
	return str(roster.keys()[0]) if not roster.is_empty() else "brute"

## Build one enemy (not yet in the tree).
func _make_enemy(role: String, rank: String, enemy_name: String, r: RandomNumberGenerator, ri := -1) -> Node3D:
	var skin := _roster_skin(role, ri)
	var scene: PackedScene = load(str(skin.get("scene", "res://scenes/zombie.tscn")))
	var e: Node3D = scene.instantiate()
	e.name = enemy_name
	Roles.apply(e, role, skin)
	e.apply_rank(rank, enemy_level)
	if rank == "elite":
		e.apply_elite_trait(ELITE_TRAITS.roll(r))
		if modifiers.has("volatile"):
			e.death_explode = true
	if layout.get("roam", false) and rank == "normal":
		e.roam_radius = 5.0
	return e

## A pack of `slots` (swarmers count triple) + `elites` in room `ri`.
func _spawn_pack(ri: int, slots: int, elites: int, prefix: String, r: RandomNumberGenerator, section: int) -> Array:
	var plan: Array = []   # [role, rank]
	for n in elites:
		plan.append([_pick_role(r, false, ri), "elite"])
	for n in slots:
		var role := _pick_role(r, true, ri)
		for k in Roles.pack_count(role):
			if plan.size() < MAX_PACK:
				plan.append([role, "normal"])
	return _spawn_plan(ri, plan, _points(rooms[ri], plan.size(), r), prefix, r, section)

## A hand-placed pack (a PackMarker): exactly its roles, around its spot.
func _spawn_marker_pack(ri: int, pack: Dictionary, prefix: String, r: RandomNumberGenerator, section: int) -> Array:
	var plan: Array = []
	for n in int(pack.get("elites", 0)):
		plan.append([_pick_role(r, false, ri), "elite"])
	for role in pack.get("roles", []):
		if plan.size() < MAX_PACK:
			plan.append([str(role), "normal"])
	var at: Vector3 = pack["at"]
	var pts: Array = []
	for i in plan.size():
		var a := TAU * float(i) / float(maxi(plan.size(), 1)) + r.randf_range(-0.3, 0.3)
		var rad := 0.0 if plan.size() == 1 else 1.4 + 0.25 * plan.size()
		pts.append(at + Vector3(cos(a), 0, sin(a)) * rad)
	var out := _spawn_plan(ri, plan, pts, prefix, r, section)
	if pack.get("keybearer", false):
		for e in out:
			if e.rank == "elite":
				_make_keybearer(e)
	return out

func _spawn_plan(ri: int, plan: Array, pts: Array, prefix: String, r: RandomNumberGenerator, section: int) -> Array:
	var room: Dictionary = rooms[ri]
	var out: Array = []
	for i in plan.size():
		var e := _make_enemy(plan[i][0], plan[i][1], "%s_E%d" % [prefix, i], r, ri)
		e.set_meta("section", section)
		# A point is (x, z) on the room's floor, or a Vector3 (on a platform).
		var p: Variant = pts[i]
		var at: Vector3 = p if p is Vector3 else Vector3(p.x, room["center"].y, p.y)
		e.position = enemies_root.to_local(at + Vector3(0, e.ground_offset(), 0))
		e.rotation.y = r.randf() * TAU
		enemies_root.add_child(e)
		out.append(e)
	return out

func _points(room: Dictionary, count: int, r: RandomNumberGenerator) -> Array:
	var out: Array = []
	var half: Vector2 = room["size"] * 0.5 - Vector2(2.2, 2.2)   # clear of wall rocks and big props
	var c: Vector3 = room["center"]
	for i in count:
		var best := Vector2(c.x, c.z)
		for attempt in 30:
			var p := Vector2(c.x + r.randf_range(-half.x, half.x), c.z + r.randf_range(-half.y, half.y))
			best = p
			var ok := true
			for q in out:
				if p.distance_to(q) < 1.6:
					ok = false
					break
			if ok:
				break
		out.append(best)
	return out

## Seeded packs in every combat / side room (same on every machine).
func _populate() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = seed_used + 1234
	# Keybearer sections: make sure two rooms have an elite.
	var key_rooms := {}
	# Hand-placed packs first (hand-made maps).
	var marker_keys := {}   # section -> true when a PackMarker carries its keys
	for i in rooms.size():
		var packs: Array = rooms[i].get("packs", [])
		var s := int(rooms[i]["section"])
		for n in packs.size():
			var pack := _spawn_marker_pack(i, packs[n], "R%dP%d" % [i, n], r, s)
			if packs[n].get("keybearer", false):
				marker_keys[s] = true
			if s >= 0 and s < sections.size():
				sections[s]["total"] = int(sections[s]["total"]) + pack.size()
	for k in sections.size():
		if sections[k]["objective"] != "key_elites" or marker_keys.has(k):
			continue
		var cands: Array = sections[k]["rooms"].filter(func(i): return rooms[i]["kind"] in ["combat", "side"])
		cands.sort()
		for n in mini(2, cands.size()):
			key_rooms[cands[n]] = true
	for i in rooms.size():
		var room: Dictionary = rooms[i]
		if not (room["kind"] in ["combat", "side", "channel"]) or room.get("no_random", false):
			continue
		var s := int(room["section"])
		var slots := r.randi_range(int(recipe.pack_min), int(recipe.pack_max))
		var elites := 1 if (key_rooms.has(i) or room["kind"] == "side" or r.randf() < float(recipe.elite_chance)) else 0
		if room["kind"] == "channel":
			slots = 1   # the attackers come while you hold the circle
			elites = 0
		var pack := _spawn_pack(i, slots, elites, "R%d" % i, r, s)
		for e in pack:
			if key_rooms.has(i) and e.rank == "elite" and not e.has_meta("key"):
				_make_keybearer(e)
				key_rooms.erase(i)
		if s >= 0 and s < sections.size():
			sections[s]["total"] = int(sections[s]["total"]) + pack.size()
	for k in sections.size():
		var sec: Dictionary = sections[k]
		for e in enemies_root.get_children():
			if e.has_meta("key") and int(e.get_meta("section", -1)) == k:
				sec["keys"] = int(sec["keys"]) + 1
		if sec["objective"] == "key_elites" and int(sec["keys"]) == 0:
			sec["objective"] = "clear_pct"

func _make_keybearer(e: Node3D) -> void:
	e.set_meta("key", true)
	e.display_name = "%s %s" % [Names.t("keybearer"), e.display_name]
	e.show_name = true
	if e._name_label:
		e._name_label.text = e.display_name
	var key := MeshInstance3D.new()
	var km := TorusMesh.new()
	km.inner_radius = 0.12
	km.outer_radius = 0.2
	key.mesh = km
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.2)
	mat.emission_energy_multiplier = 3.0
	key.material_override = mat
	key.position = Vector3(0, float(e.health_bar_height) + 0.9, 0)
	key.rotation.x = PI / 2.0
	e.add_child(key)

func _on_enemy_died(e: Node) -> void:
	_kills += 1
	if e == null or not is_instance_valid(e):
		return
	var s := int(e.get_meta("section", -1))
	if s >= 0 and s < sections.size():
		var sec: Dictionary = sections[s]
		sec["killed"] = int(sec["killed"]) + 1
		if e.has_meta("key"):
			sec["keys"] = maxi(int(sec["keys"]) - 1, 0)
			if not _net_client():
				_announce("Keybearer slain (%d left)" % int(sec["keys"]), Color(1.0, 0.85, 0.3))
		if e.has_meta("wave"):
			sec["wave_alive"] = maxi(int(sec["wave_alive"]) - 1, 0)
		if not _net_client():
			_check_section(s)
	_update_header()

# --- Sections & objectives (host / solo decides) --------------------------------------------

func _objective_text(k: int) -> String:
	if k < 0 or k >= sections.size():
		return ""
	var sec: Dictionary = sections[k]
	var obj := str(sec["objective"])
	match obj:
		"clear_pct":
			var need := _clear_need(k)
			return "%s  (%d / %d)" % [Names.t("obj_clear_pct") % int(recipe.clear_pct), mini(int(sec["killed"]), need), need]
		"key_elites":
			return "%s  (%d left)" % [Names.t("obj_key_elites"), int(sec["keys"])]
		"survive_waves":
			return "%s  (%d / %d)" % [Names.t("obj_survive_waves"), clampi(int(sec["wave"]) + 1, 0, int(recipe.waves)), int(recipe.waves)]
		"defend":
			return "%s  (%d%%)" % [Names.t("obj_defend"), int(float(sec["progress"]) / maxf(float(recipe.defend_time), 1.0) * 100.0)]
		"timed_escape":
			if float(sec["timer_end"]) > 0.0 and not bool(boss_started[k]):
				return "%s  (%d s)" % [Names.t("obj_timed_escape"), maxi(int(ceil(float(sec["timer_end"]) - _now())), 0)]
			return Names.t("obj_timed_escape")
		"wing_bosses":
			var dead := 0
			for i in k:
				if boss_dead[i]:
					dead += 1
			return "%s  (%d / %d)" % [Names.t("obj_wing_bosses"), dead, k]
	return Names.t("obj_" + obj)

func _clear_need(k: int) -> int:
	return int(ceil(float(sections[k]["total"]) * float(recipe.clear_pct) / 100.0))

## The section a position is in (by room), or -1 in a passage.
func _room_at(p: Vector3) -> int:
	for i in rooms.size():
		var r: Dictionary = rooms[i]
		var c: Vector3 = r["center"]
		if absf(p.x - c.x) <= r["size"].x * 0.5 and absf(p.z - c.z) <= r["size"].y * 0.5 and absf(p.y - c.y) < 2.5:
			return i
	return -1

func _activate(k: int) -> void:
	var sec: Dictionary = sections[k]
	if sec["active"]:
		return
	sec["active"] = true
	match str(sec["objective"]):
		"reach_exit":
			_complete_section(k)
		"timed_escape":
			sec["timer_end"] = _now() + float(recipe.escape_time)
			_announce("%s: %d seconds!" % [Names.t("obj_timed_escape"), int(recipe.escape_time)], Color(1.0, 0.8, 0.3))
			if _net() and _net().is_host():
				_net().dungeon_event("timer", {"s": k, "t": float(recipe.escape_time)})
			_complete_section(k)   # the gate is open; getting there in time earns a bonus chest
		"wing_bosses", "clear_pct", "key_elites":
			_check_section(k)
	_update_header()

func _check_section(k: int) -> void:
	var sec: Dictionary = sections[k]
	if sec["done"]:
		return
	var done := false
	match str(sec["objective"]):
		"clear_pct":
			done = int(sec["killed"]) >= _clear_need(k)
		"key_elites":
			done = int(sec["keys"]) <= 0
		"survive_waves":
			done = int(sec["wave"]) >= int(recipe.waves) - 1 and int(sec["wave_alive"]) <= 0
		"wing_bosses":
			done = true
			for i in k:
				done = done and bool(boss_dead[i])
		"reach_exit", "timed_escape":
			done = bool(sec["active"])
	if done:
		_complete_section(k)

func _complete_section(k: int) -> void:
	var sec: Dictionary = sections[k]
	if sec["done"]:
		return
	sec["done"] = true
	_set_gates("entry", k, false)
	if _net() and _net().is_host():
		_net().dungeon_event("sec_done", {"s": k})
	var bn := _boss_title(k)
	if str(sec["objective"]) != "timed_escape" and str(sec["objective"]) != "reach_exit":
		_announce("The way to %s is open!" % bn, Color(0.45, 0.9, 1.0))
		var gl := get_node_or_null("/root/GameLog")
		if gl:
			gl.event("Objective complete. The way to %s is open." % bn, Color(0.45, 0.9, 1.0))
	_update_header()

func _boss_title(k: int) -> String:
	return Names.t(str(recipe.bosses[k].get("name", "")))

# Waves (arena rooms) ---------------------------------------------------------------------------

func _start_wave(k: int, w: int) -> void:
	var sec: Dictionary = sections[k]
	sec["wave"] = w
	var r := RandomNumberGenerator.new()
	r.seed = seed_used + k * 1000 + w * 37
	var room: int = sec["special"]
	var pack := _spawn_pack(room, 2 + w, 1 if w == int(recipe.waves) - 1 else 0, "W%d_%d" % [k, w], r, k)
	sec["wave_alive"] = pack.size()
	sec["total"] = int(sec["total"]) + pack.size()
	for e in pack:
		e.set_meta("wave", true)
		_spawn_flash(e.global_position)
		if not _net_client():
			var tgt := _nearest_body(e.global_position)
			if tgt:
				e.add_threat(tgt, 1.0)
	_announce("Wave %d / %d" % [w + 1, int(recipe.waves)], Color(1.0, 0.6, 0.3))
	_update_header()

func _spawn_flash(at: Vector3) -> void:
	FX.burst(get_tree().current_scene, at, 1.4, Color(0.8, 0.6, 1.0))

func _nearest_body(from: Vector3) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for b in _party():
		if is_instance_valid(b) and b.is_alive():
			var d: float = b.global_position.distance_to(from)
			if d < bd:
				bd = d
				best = b
	return best

# Defend (channel circles) -----------------------------------------------------------------------

var _circles := {}   # section -> {"root": Node3D, "fill": MeshInstance3D}

func _build_objective_markers() -> void:
	for k in sections.size():
		var sec: Dictionary = sections[k]
		if str(sec["objective"]) != "defend":
			continue
		var c := _defend_center(k)
		var root := Node3D.new()
		level_root.add_child(root)
		root.position = c + Vector3(0, 0.04, 0)
		var disc := MeshInstance3D.new()
		var dm := CylinderMesh.new()
		dm.top_radius = DEFEND_RADIUS
		dm.bottom_radius = DEFEND_RADIUS
		dm.height = 0.02
		disc.mesh = dm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.4, 0.8, 1.0, 0.25)
		disc.material_override = mat
		root.add_child(disc)
		var fill := MeshInstance3D.new()
		var fm := CylinderMesh.new()
		fm.top_radius = DEFEND_RADIUS
		fm.bottom_radius = DEFEND_RADIUS
		fm.height = 0.03
		fill.mesh = fm
		var fmat := StandardMaterial3D.new()
		fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fmat.albedo_color = Color(0.4, 0.9, 1.0, 0.5)
		fill.material_override = fmat
		fill.scale = Vector3(0.01, 1, 0.01)
		root.add_child(fill)
		var l := OmniLight3D.new()
		l.light_color = Color(0.4, 0.8, 1.0)
		l.light_energy = 1.5
		l.omni_range = 6.0
		l.position = Vector3(0, 1.0, 0)
		root.add_child(l)
		var label := Label3D.new()
		label.text = Names.t("obj_defend")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 36
		label.outline_size = 8
		label.pixel_size = 0.01
		label.modulate = Color(0.6, 0.9, 1.0)
		label.position = Vector3(0, 2.2, 0)
		root.add_child(label)
		_circles[k] = {"root": root, "fill": fill}

## Middle of section k's defend circle (its marked spot, else the room's middle).
func _defend_center(k: int) -> Vector3:
	var sec: Dictionary = sections[k]
	return sec["spot"] if sec.has("spot") else rooms[int(sec["special"])]["center"]

func _update_circle(k: int) -> void:
	if not _circles.has(k):
		return
	var p := clampf(float(sections[k]["progress"]) / maxf(float(recipe.defend_time), 1.0), 0.0, 1.0)
	(_circles[k]["fill"] as MeshInstance3D).scale = Vector3(maxf(p, 0.01), 1, maxf(p, 0.01))

func _defend_spawn(k: int, n: int) -> void:
	var sec: Dictionary = sections[k]
	var r := RandomNumberGenerator.new()
	r.seed = seed_used + k * 777 + n * 13
	var pack := _spawn_pack(int(sec["special"]), 2, 0, "C%d_%d" % [k, n], r, -1)
	for e in pack:
		_spawn_flash(e.global_position)
		if not _net_client():
			var tgt := _nearest_body(e.global_position)
			if tgt:
				e.add_threat(tgt, 1.0)

# --- Summoned adds (bosses, Summoners) ------------------------------------------------------------

## Host / solo: `count` enemies of `role` appear around `at` (or around the
## room's edge when a room is given) and go for the nearest player.
func summon_adds(at: Vector3, count: int, role: String, owner: Node = null,
		room_center := Vector3.INF, room_half := Vector2.ZERO) -> Array:
	var made: Array = []
	if _net_client():
		return made
	var names: Array = []
	var pts: Array = []
	var start := randf() * TAU
	for i in count:
		_add_serial += 1
		names.append("Add_%d" % _add_serial)
		var ang := start + TAU * float(i) / float(maxi(count, 1))
		if room_center != Vector3.INF:
			var rr := minf(room_half.x, room_half.y) - 2.0
			pts.append(room_center + Vector3(cos(ang), 0, sin(ang)) * rr)
		else:
			pts.append(at + Vector3(cos(ang), 0, sin(ang)) * 2.5)
	var owner_name := str(owner.name) if owner and is_instance_valid(owner) else ""
	for i in names.size():
		var e := _spawn_add(str(names[i]), pts[i], role, owner_name)
		made.append(e)
		var tgt := _nearest_body(e.global_position)
		if tgt:
			e.add_threat(tgt, 1.0)
	if _net() and _net().is_host():
		_net().dungeon_event("adds", {"names": names, "pts": pts, "role": role, "owner": owner_name})
	return made

func _spawn_add(add_name: String, at: Vector3, role: String, owner_name: String) -> Node3D:
	var r := RandomNumberGenerator.new()
	r.seed = hash(add_name) + seed_used
	var e := _make_enemy(role, "normal", add_name, r, _room_at(at))
	e.set_meta("summoned_by", owner_name)
	e.position = enemies_root.to_local(at + Vector3(0, e.ground_offset(), 0))
	e.rotation.y = randf() * TAU
	enemies_root.add_child(e)
	FX.burst(get_tree().current_scene, at, 1.6, Color(0.7, 0.5, 1.0))
	return e

# --- Gates ------------------------------------------------------------------------------------------

func _build_gates() -> void:
	var cw: float = layout.get("corridor", 3.6)
	for l in links:
		var p := int(l[0])
		var c := int(l[1])
		if int(rooms[c]["boss"]) >= 0:
			gates.append(_gate(rooms[c], rooms[p]["center"], cw, "entry", int(rooms[c]["boss"])))
		if int(rooms[p]["boss"]) >= 0:
			gates.append(_gate(rooms[p], rooms[c]["center"], cw, "exit", int(rooms[p]["boss"])))

## A gate across the doorway of `room` on the side facing `toward`.
func _gate(room: Dictionary, toward: Vector3, cw: float, kind: String, k: int) -> Dictionary:
	var c: Vector3 = room["center"]
	var d := toward - c
	d.y = 0.0
	var along_x := absf(d.x) > absf(d.z)
	var dir := Vector3(signf(d.x), 0, 0) if along_x else Vector3(0, 0, signf(d.z))
	var half: float = (room["size"].x if along_x else room["size"].y) * 0.5
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.6, 4.0, cw + 0.8) if along_x else Vector3(cw + 0.8, 4.0, 0.6)
	shape.shape = bs
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bs.size
	var mat := StandardMaterial3D.new()
	var col := Color(0.9, 0.15, 0.1) if kind == "exit" else Color(0.95, 0.55, 0.15)
	mat.albedo_color = Color(col, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.5
	bm.material = mat
	mesh.mesh = bm
	body.add_child(mesh)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.outline_size = 8
	label.pixel_size = 0.01
	label.modulate = col.lightened(0.4)
	label.position = Vector3(0, 2.6, 0)
	body.add_child(label)
	level_root.add_child(body)
	body.global_position = c + dir * half + Vector3(0, 2.0, 0)
	var g := {"body": body, "shape": shape, "mesh": mesh, "label": label, "kind": kind, "boss": k, "closed": true}
	_apply_gate(g, true)
	return g

func _apply_gate(g: Dictionary, closed: bool) -> void:
	g["closed"] = closed
	(g["mesh"] as MeshInstance3D).visible = closed
	(g["label"] as Label3D).visible = closed
	(g["shape"] as CollisionShape3D).set_deferred("disabled", not closed)
	if closed:
		var k := int(g["boss"])
		(g["label"] as Label3D).text = ("Sealed: %s" % _objective_text(k).split("  (")[0]) if g["kind"] == "entry" \
			else "Sealed until %s falls" % _boss_title(k)

func _set_gates(kind: String, k: int, closed: bool) -> void:
	for g in gates:
		if g["kind"] == kind and int(g["boss"]) == k:
			_apply_gate(g, closed)

# --- Bosses --------------------------------------------------------------------------------------

func _build_boss_triggers() -> void:
	for k in boss_rooms.size():
		var ri: int = boss_rooms[k]
		if ri < 0:
			continue
		var r: Dictionary = rooms[ri]
		var trigger := Area3D.new()
		trigger.collision_layer = 0
		trigger.collision_mask = 1
		var ts := CollisionShape3D.new()
		var tb := BoxShape3D.new()
		tb.size = Vector3(r["size"].x - 5.0, 3.0, r["size"].y - 5.0)
		ts.shape = tb
		trigger.add_child(ts)
		level_root.add_child(trigger)
		trigger.global_position = r["center"] + Vector3(0, 1.5, 0)
		var idx: int = k
		trigger.body_entered.connect(func(b):
			if b.is_in_group("player"):
				_start_boss(idx, b))

func _in_room(b: Node3D, ri: int, margin := 2.5) -> bool:
	var r: Dictionary = rooms[ri]
	var c: Vector3 = r["center"]
	return absf(b.global_position.x - c.x) < r["size"].x * 0.5 - margin \
		and absf(b.global_position.z - c.z) < r["size"].y * 0.5 - margin and absf(b.global_position.y - c.y) < 2.5

func _start_boss(k: int, who: Node3D = null) -> void:
	if boss_started[k] or boss_dead[k] or _net_client() or not sections[k]["done"]:
		return
	if who == null:
		who = player
	if not who.is_alive():
		return
	# Timed escape: made it in time?
	var sec: Dictionary = sections[k]
	if str(sec["objective"]) == "timed_escape" and float(sec["timer_end"]) > 0.0 and _now() <= float(sec["timer_end"]):
		sec["bonus"] = true
		_announce("Made it in time! A bonus chest awaits.", Color(1.0, 0.85, 0.3))
	_spawn_boss(k)
	if bosses[k]:
		bosses[k].add_threat(who, 5.0)
	if _net():
		_net().dungeon_event("boss", {"k": k, "bonus": sec["bonus"]})

func _spawn_boss(k: int) -> void:
	if boss_started[k]:
		return
	boss_started[k] = true
	var data: Dictionary = recipe.bosses[k]
	var ri: int = boss_rooms[k]
	var room: Dictionary = rooms[ri]
	# Solo: the door seals behind you. In a party it stays open so nobody is locked out.
	var seal: bool = not (_net() and _net().with_others())
	if seal:
		_set_gates("entry", k, true)
		for g in gates:
			if g["kind"] == "entry" and int(g["boss"]) == k:
				(g["label"] as Label3D).text = "Sealed during the fight"
	var skin: Dictionary = data.get("skin", {})
	var scene: PackedScene = load(str(skin.get("scene", "res://scenes/zombie.tscn")))
	var e: Node3D = scene.instantiate()
	e.name = "Boss%d" % k
	var role := str(data.get("role", ""))
	if role != "":
		Roles.apply(e, role, skin)
	elif skin.has("tint"):
		e.model_tint = skin["tint"]
	e.boss_scale *= float(skin.get("scale", 1.0))
	e.apply_rank("boss", enemy_level)
	e.display_name = _boss_title(k)
	e.max_health = maxi(int(round(float(e.max_health) * float(data.get("hp", 1.0)))), 1)
	e.contact_damage = float(e.contact_damage) * float(data.get("dmg", 1.0))
	# Where it stands: the middle of the room, facing the way you came in.
	var entry_dir := Vector3.FORWARD
	for l in links:
		if int(l[1]) == ri:
			entry_dir = (rooms[int(l[0])]["center"] - room["center"])
	entry_dir.y = 0.0
	entry_dir = entry_dir.normalized() if entry_dir.length() > 0.01 else Vector3.FORWARD
	var at: Vector3 = room["center"] - entry_dir * 2.0
	e.position = enemies_root.to_local(at + Vector3(0, e.ground_offset(), 0))
	e.rotation.y = atan2(entry_dir.x, entry_dir.z) + PI
	enemies_root.add_child(e)
	bosses[k] = e
	e.died.connect(_on_boss_died.bind(k))
	var kit := Node.new()
	kit.name = "BossKit"
	kit.set_script(BOSS_KIT)
	kit.abilities = Array(data.get("abilities", []))
	kit.dungeon = self
	kit.room_center = room["center"]
	kit.room_half = room["size"] * 0.5
	e.add_child(kit)
	get_node("/root/SignalBus").boss_engaged.emit(e)
	var gl := get_node_or_null("/root/GameLog")
	if gl:
		gl.event("%s awakens!" % e.display_name + (" The door seals behind you." if seal else ""), Color(1.0, 0.4, 0.3))
	_announce("%s awakens!" % e.display_name, Color(1.0, 0.4, 0.3))
	_watch_boss = e
	_boss_bar.visible = true
	_update_header()

## Solo: dying mid boss fight resets it - the boss (and its summons) go away,
## the sealed door opens, and walking back in starts the fight fresh.
func _on_local_death() -> void:
	if _net() and _net().with_others():
		return   # in a party the fight goes on; the door never sealed
	for k in bosses.size():
		if not boss_started[k] or boss_dead[k]:
			continue
		var b: Node3D = bosses[k]
		for e in enemies_root.get_children():
			if str(e.name).begins_with("Add_") and b and e.get_meta("summoned_by", "") == str(b.name):
				e.queue_free()
		if is_instance_valid(b):
			b.queue_free()
		bosses[k] = null
		boss_started[k] = false
		_set_gates("entry", k, false)
		if _boss_bar:
			_boss_bar.visible = false

func _on_boss_died(k: int) -> void:
	# Summons crumble with their master.
	var boss_node: Node3D = bosses[k]
	if not _net_client():
		for e in enemies_root.get_children():
			if str(e.name).begins_with("Add_") and e.has_method("is_alive") and e.is_alive():
				if boss_node == null or e.get_meta("summoned_by", "") == str(boss_node.name):
					e.take_damage(e.health)
	boss_dead[k] = true
	var ri: int = boss_rooms[k]
	_safe_room = ri
	_set_gates("entry", k, false)
	_set_gates("exit", k, false)
	# Boss chest (a bonus card if the timed run was beaten).
	var c: Vector3 = rooms[ri]["center"]
	var chest := _spawn_chest(c + Vector3(2.5, 0, 2.5), c)
	if sections[k]["bonus"]:
		chest.cards = 3
	_chests[k] = chest
	get_node("/root/SignalBus").boss_defeated.emit(boss_node)
	var gl := get_node_or_null("/root/GameLog")
	var bn := _boss_title(k)
	var last := k == bosses.size() - 1
	if gl:
		gl.event("%s is defeated!%s" % [bn, " The exit portal is open!" if last else ""], Color(0.95, 0.75, 0.35))
	_announce("%s is defeated!" % bn if not last else "The exit portal is open!", Color(0.45, 0.9, 1.0))
	if last:
		_set_exit_active(true)
	# Hub: the wing bosses open the final boss.
	if not _net_client():
		for s in sections.size():
			if str(sections[s]["objective"]) == "wing_bosses":
				_check_section(s)
	var t := create_tween()
	t.tween_interval(2.0)
	t.tween_callback(func():
		if _watch_boss == boss_node:
			_boss_bar.visible = false)
	_update_header()

func _spawn_chest(at: Vector3, face: Vector3) -> Node3D:
	var ch := Node3D.new()
	ch.set_script(CHEST)
	ch.locked = false
	level_root.add_child(ch)
	ch.global_position = at
	var dir := face - at
	ch.rotation.y = atan2(dir.x, dir.z)
	return ch

# --- Exit portal -----------------------------------------------------------------------------------

func _build_exit() -> void:
	var k := bosses.size() - 1
	var ri: int = boss_rooms[k]
	if ri < 0:
		return
	var r: Dictionary = rooms[ri]
	var c: Vector3 = r["center"]
	# The side of the room away from its entrance.
	var away := Vector3.BACK
	for l in links:
		if int(l[1]) == ri:
			away = r["center"] - rooms[int(l[0])]["center"]
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	var along_x := absf(away.x) > 0.5
	var half: float = (r["size"].x if along_x else r["size"].y) * 0.5
	var exit := Node3D.new()
	exit.name = "ExitPortal"
	level_root.add_child(exit)
	exit.global_position = c + away * (half - 2.2)
	_exit_pos = exit.global_position
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.1
	torus.outer_radius = 1.35
	torus.rings = 32
	_exit_mat = StandardMaterial3D.new()
	_exit_mat.emission_enabled = true
	torus.material = _exit_mat
	ring.mesh = torus
	ring.position = Vector3(0, 1.4, 0)
	ring.rotation = Vector3(0, 0, PI / 2.0) if along_x else Vector3(PI / 2.0, 0, 0)
	exit.add_child(ring)
	_exit_light = OmniLight3D.new()
	_exit_light.position = Vector3(0, 1.4, 0)
	_exit_light.omni_range = 5.0
	exit.add_child(_exit_light)
	_set_exit_active(false)

func _set_exit_active(active: bool) -> void:
	if _exit_mat == null:
		return
	var col := Color(0.35, 0.85, 1.0) if active else Color(0.35, 0.3, 0.3)
	_exit_mat.albedo_color = col
	_exit_mat.emission = col
	_exit_mat.emission_energy_multiplier = 3.0 if active else 0.2
	_exit_light.light_color = col
	_exit_light.light_energy = 2.0 if active else 0.0

func _complete_dungeon() -> void:
	if _complete:
		return
	_complete = true
	var summary := {
		"dungeon": map_title,
		"time": _now() - _start_time,
		"kills": _kills,
		"loot": _loot,
		"xp": _xp,
		"bosses": boss_dead.count(true),
		"level": enemy_level,
		"id": str(recipe.id),
		"diff": str(get_node("/root/GameManager").difficulty),
	}
	# Best clear times per difficulty (the Play screen shows them).
	summary["best"] = get_node("/root/PlayerData").record_clear(summary["id"], summary["diff"], summary["time"])
	get_node("/root/SignalBus").dungeon_cleared.emit(summary)
	var gl := get_node_or_null("/root/GameLog")
	if gl:
		gl.event("%s cleared!" % map_title, Color(0.95, 0.75, 0.35))
	if _net() and _net().is_host():
		_net().dungeon_event("complete")
	_show_clear_screen(summary)
	if not (_net() and _net().with_others()):
		get_tree().paused = true

# --- Revive point (no-drawback death) ---------------------------------------------------------------

## Where a dead player comes back: the last boss room cleared, else the entrance.
func respawn_point() -> Vector3:
	var c: Vector3 = rooms[_safe_room]["center"] if _safe_room >= 0 and _safe_room < rooms.size() else rooms[0]["center"]
	return c + Vector3(0, 1.0, 0)

# --- Multiplayer ---------------------------------------------------------------------------------------

func _net() -> Node:
	return get_node_or_null("/root/Net")

func _net_client() -> bool:
	return _net() != null and _net().is_client()

func _party() -> Array:
	return _net().party_bodies() if _net() else [player]

func net_event(ev: String, data: Dictionary) -> void:
	match ev:
		"sec_done":
			var k := int(data.get("s", -1))
			if k >= 0 and k < sections.size():
				sections[k]["active"] = true
				_complete_section(k)
		"activate":
			var k := int(data.get("s", -1))
			if k >= 0 and k < sections.size():
				sections[k]["active"] = true
				_update_header()
		"timer":
			var k := int(data.get("s", -1))
			if k >= 0 and k < sections.size():
				sections[k]["active"] = true
				sections[k]["timer_end"] = _now() + float(data.get("t", 0.0))
		"boss":
			var k := int(data.get("k", -1))
			if k >= 0 and k < sections.size():
				sections[k]["done"] = true
				sections[k]["bonus"] = bool(data.get("bonus", false))
				_spawn_boss(k)
		"wave":
			var k := int(data.get("s", -1))
			if k >= 0 and k < sections.size():
				_start_wave(k, int(data.get("w", 0)))
		"defend":
			var k := int(data.get("s", -1))
			if k >= 0 and k < sections.size():
				sections[k]["progress"] = float(data.get("p", 0.0))
				_update_circle(k)
				_update_header()
		"cspawn":
			var k := int(data.get("s", -1))
			if k >= 0 and k < sections.size():
				_defend_spawn(k, int(data.get("n", 0)))
		"adds":
			var names: Array = data.get("names", [])
			var pts: Array = data.get("pts", [])
			for i in mini(names.size(), pts.size()):
				_spawn_add(str(names[i]), pts[i], str(data.get("role", "swarmer")), str(data.get("owner", "")))
		"complete":
			_complete_dungeon()
		"bell", "ballista", "ballista_load":
			if _set_pieces:
				_set_pieces.net_event(ev, data)

# --- Per-frame (host / solo runs the dungeon) ------------------------------------------------------

var _tick := 0.0
var _defend_sent := 0.0

func _process(delta: float) -> void:
	_update_boss_bar()
	if _complete:
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.25
		_update_header()
	if _net_client():
		return
	var bodies := _party()
	# Which rooms are the players in?
	for b in bodies:
		if not is_instance_valid(b) or not b.is_alive():
			continue
		var ri := _room_at(b.global_position)
		if ri < 0:
			continue
		var s := int(rooms[ri]["section"])
		if s >= 0 and s < sections.size() and not sections[s]["active"]:
			_activate(s)
			if _net() and _net().is_host():
				_net().dungeon_event("activate", {"s": s})
		# Party members' characters don't touch the local boss trigger: check them here.
		var bk := int(rooms[ri]["boss"])
		if bk >= 0 and not boss_started[bk] and sections[bk]["done"] and _in_room(b, ri):
			_start_boss(bk, b)
	for k in sections.size():
		var sec: Dictionary = sections[k]
		if sec["done"] or not sec["active"]:
			continue
		match str(sec["objective"]):
			"survive_waves":
				var arena: int = sec["special"]
				var someone_in := false
				for b in bodies:
					if is_instance_valid(b) and b.is_alive() and _in_room(b, arena, 1.0):
						someone_in = true
				if int(sec["wave"]) < 0:
					if someone_in:
						_host_wave(k, 0)
				elif int(sec["wave_alive"]) <= 0:
					if float(sec["next_spawn"]) <= 0.0:
						sec["next_spawn"] = _now() + WAVE_GAP
					elif _now() >= float(sec["next_spawn"]):
						sec["next_spawn"] = 0.0
						if int(sec["wave"]) >= int(recipe.waves) - 1:
							_check_section(k)
						else:
							_host_wave(k, int(sec["wave"]) + 1)
			"defend":
				var c := _defend_center(k)
				var inside := false
				for b in bodies:
					if is_instance_valid(b) and b.is_alive() and Vector2(b.global_position.x - c.x, b.global_position.z - c.z).length() <= DEFEND_RADIUS:
						inside = true
				if inside:
					sec["progress"] = float(sec["progress"]) + delta
					if float(sec["next_spawn"]) <= 0.0:
						sec["next_spawn"] = _now() + 3.0
					if _now() >= float(sec["next_spawn"]):
						sec["next_spawn"] = _now() + DEFEND_SPAWN_EVERY
						var n := int(sec["spawned"])
						sec["spawned"] = n + 1
						_defend_spawn(k, n)
						if _net() and _net().is_host():
							_net().dungeon_event("cspawn", {"s": k, "n": n})
				_update_circle(k)
				if _now() - _defend_sent > 0.5 and _net() and _net().is_host():
					_defend_sent = _now()
					_net().dungeon_event("defend", {"s": k, "p": float(sec["progress"])})
				if float(sec["progress"]) >= float(recipe.defend_time):
					_complete_section(k)
	# Exit portal (also catches someone already standing in it).
	if boss_dead[bosses.size() - 1]:
		for b in bodies:
			var d := Vector2(b.global_position.x - _exit_pos.x, b.global_position.z - _exit_pos.z)
			if is_instance_valid(b) and b.is_alive() and d.length() < 1.4:
				_complete_dungeon()
				break

func _host_wave(k: int, w: int) -> void:
	_start_wave(k, w)
	if _net() and _net().is_host():
		_net().dungeon_event("wave", {"s": k, "w": w})

# --- UI: header, modifier banner, boss bar, announcements, clear screen -------------------------------

var _ui: CanvasLayer
var _header: Label
var _mods_label: Label
var _boss_bar: VBoxContainer
var _boss_fill: ProgressBar
var _boss_name: Label
var _boss_icons: HFlowContainer
var _announce_label: Label
var _announce_tween: Tween
var _watch_boss: Node3D

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 3
	_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui)
	# Banners and panels shown later get the in-game UI's look once built.
	_ui.child_entered_tree.connect(func(c: Node): UISkin.restyle.call_deferred(c))
	_header = UI.label("", 16, UI.ACCENT)
	_header.anchor_left = 0.5
	_header.anchor_right = 0.5
	_header.offset_left = -420
	_header.offset_right = 420
	_header.offset_top = 8
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.add_theme_color_override("font_outline_color", Color.BLACK)
	_header.add_theme_constant_override("outline_size", 5)
	_ui.add_child(_header)
	# Active modifiers, always visible under the header.
	_mods_label = UI.label("", 13, Color(0.85, 0.8, 1.0))
	_mods_label.anchor_left = 0.5
	_mods_label.anchor_right = 0.5
	_mods_label.offset_left = -420
	_mods_label.offset_right = 420
	_mods_label.offset_top = 30
	_mods_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mods_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_mods_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_mods_label.add_theme_constant_override("outline_size", 4)
	var tips: Array[String] = []
	for m in modifiers:
		tips.append("%s: %s" % [Mods.title(m), Mods.desc(m)])
	_mods_label.text = ("Modifiers: " + "  •  ".join(modifiers.map(func(m): return Mods.title(m)))) if not modifiers.is_empty() else ""
	_mods_label.tooltip_text = "\n".join(tips)
	_ui.add_child(_mods_label)

	_boss_bar = VBoxContainer.new()
	_boss_bar.anchor_left = 0.5
	_boss_bar.anchor_right = 0.5
	_boss_bar.offset_left = -230
	_boss_bar.offset_right = 230
	_boss_bar.offset_top = 52
	_boss_bar.add_theme_constant_override("separation", 2)
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_boss_bar)
	_boss_name = UI.label("Boss", 15, Color(1.0, 0.45, 0.4))
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_bar.add_child(_boss_name)
	_boss_fill = ProgressBar.new()
	_boss_fill.custom_minimum_size = Vector2(460, 16)
	_boss_fill.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.8, 0.12, 0.1)
	fill.set_corner_radius_all(3)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.1, 0.05, 0.05, 0.85)
	back.set_corner_radius_all(3)
	_boss_fill.add_theme_stylebox_override("fill", fill)
	_boss_fill.add_theme_stylebox_override("background", back)
	_boss_bar.add_child(_boss_fill)
	_boss_icons = preload("res://scripts/ui/status_icons.gd").new()
	_boss_icons.icon_size = 24.0
	_boss_icons.alignment = FlowContainer.ALIGNMENT_CENTER
	_boss_bar.add_child(_boss_icons)
	_boss_bar.visible = false

	_announce_label = UI.label("", 26, UI.ACCENT)
	_announce_label.anchor_left = 0.5
	_announce_label.anchor_right = 0.5
	_announce_label.anchor_top = 0.28
	_announce_label.anchor_bottom = 0.28
	_announce_label.offset_left = -450
	_announce_label.offset_right = 450
	_announce_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_announce_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_announce_label.add_theme_constant_override("outline_size", 6)
	_announce_label.modulate.a = 0.0
	_ui.add_child(_announce_label)

## Which section the players are working on (for the header).
func _current_section() -> int:
	for k in sections.size():
		if not boss_dead[k] and sections[k]["active"]:
			return k
	for k in sections.size():
		if not boss_dead[k]:
			return k
	return -1

func _update_header() -> void:
	if _header == null:
		return
	var gm := get_node_or_null("/root/GameManager")
	var mode: String = gm.difficulty_label(gm.difficulty) if gm else "Singleplayer"
	var k := _current_section()
	var goal := ""
	if k < 0 or boss_dead[bosses.size() - 1]:
		goal = Names.t("obj_exit")
	elif sections[k]["done"]:
		goal = Names.t("obj_boss") % _boss_title(k)
	else:
		goal = _objective_text(k)
	_header.text = "%s  (%s, enemy level %d)   •   %s   •   Bosses %d / %d" % [
		map_title, mode, enemy_level, goal, boss_dead.count(true), bosses.size()]
	for g in gates:
		if g["closed"] and g["kind"] == "entry" and not boss_started[int(g["boss"])]:
			(g["label"] as Label3D).text = "Sealed: %s" % _objective_text(int(g["boss"]))

func _update_boss_bar() -> void:
	if _boss_bar and _boss_bar.visible and is_instance_valid(_watch_boss):
		_boss_fill.max_value = float(_watch_boss.max_health)
		_boss_fill.value = float(_watch_boss.health)
		_boss_name.text = "%s  —  %d / %d" % [_watch_boss.display_name, _watch_boss.health, _watch_boss.max_health]
		var bst: Node = _watch_boss.get_node_or_null("Status")
		_boss_icons.show_effects(bst.list() if bst else [])

func _announce(text: String, color: Color = Color(0.6, 0.95, 0.6)) -> void:
	if _announce_label == null:
		return
	_announce_label.text = text
	_announce_label.add_theme_color_override("font_color", color)
	_announce_label.modulate.a = 1.0
	if _announce_tween:
		_announce_tween.kill()
	_announce_tween = create_tween()
	_announce_tween.tween_interval(1.8)
	_announce_tween.tween_property(_announce_label, "modulate:a", 0.0, 0.6)

## Big panel when you load in: the dungeon, enemy level and this run's modifiers.
func _show_modifier_banner() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.14
	panel.anchor_bottom = 0.14
	panel.offset_left = -300
	panel.offset_right = 300
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UI.box(Color(0.04, 0.045, 0.06, 0.92), UI.ACCENT.darkened(0.3), 2, 10)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 14
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	_ui.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	var t := UI.label(map_title, 26, UI.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := UI.label("Enemy level %d   •   %d bosses" % [enemy_level, bosses.size()], 14, UI.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	if modifiers.is_empty():
		var none := UI.label("No dungeon modifiers this time.", 15, Color(0.8, 0.8, 0.85))
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(none)
	else:
		var head := UI.label("Dungeon Modifiers", 18, Color.WHITE)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(head)
		for m in modifiers:
			var name_l := UI.label(Mods.title(m), 20, Mods.color(m))
			name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(name_l)
			var d := UI.label(Mods.desc(m), 15, Color(0.9, 0.9, 0.92))
			d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.custom_minimum_size = Vector2(540, 0)
			v.add_child(d)
	var tw := panel.create_tween()
	# (60% shorter than it used to be: 8 / 4 s on screen and a 1 s fade.)
	tw.tween_interval(3.2 if not modifiers.is_empty() else 1.6)
	tw.tween_property(panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(panel.queue_free)

func _show_clear_screen(s: Dictionary) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(shade)
	var panel := UI.small_panel("%s cleared!" % map_title)
	panel.offset_left = -240
	panel.offset_right = 240
	panel.offset_top = -200
	panel.offset_bottom = 200
	_ui.add_child(panel)
	var v: VBoxContainer = panel.get_meta("content")
	var secs := int(s["time"])
	for line in [
		"Time: %d:%02d%s" % [secs / 60, secs % 60, "  (new best!)" if s.get("best", false) else ""],
		"Bosses defeated: %d" % int(s["bosses"]),
		"Enemies slain: %d" % int(s["kills"]),
		"Items looted: %d" % int(s["loot"]),
		"Experience gained: %d" % int(s["xp"]),
	]:
		var l := UI.label(line, 16, Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	var gm := get_node("/root/GameManager")
	if _net_client():
		var wait := UI.label("Waiting for %s (party leader)…" % _net().leader_name(), 15, UI.ACCENT)
		wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(wait)
		var leave := UI.button("Leave Group", 18, Vector2(0, 44))
		leave.pressed.connect(_net().leave_run)
		v.add_child(leave)
		return
	var again := UI.button("Next Random Dungeon", 18, Vector2(0, 44))
	again.pressed.connect(func(): gm.start_game(DB.RANDOM_KEY))
	v.add_child(again)
	var lobby := UI.button("Return to Lobby", 18, Vector2(0, 44))
	lobby.pressed.connect(gm.end_run)
	v.add_child(lobby)
