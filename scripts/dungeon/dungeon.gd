extends Node3D

# Procedural dungeon instance ("The Crypt").
# Each floor is built from GameManager.dungeon_seed:
#   start room -> 5-8 combat rooms (random walk on a grid) -> boss room,
#   plus 1-2 side rooms. Rooms and corridors are carved out of solid rock with
#   CSG, the navmesh is baked afterwards, then spawn zones fill the rooms
#   (packs of zombies, elites). Entering the boss room seals the door and wakes
#   the Zombie Lord; killing him opens the door and the exit gate. Walking into
#   the gate clears the floor: descend deeper or return to the lobby.

const SPAWN_ZONE = preload("res://scripts/dungeon/spawn_zone.gd")
const DEFAULT_ENEMY = preload("res://scenes/zombie.tscn")
const UI = preload("res://scripts/ui_kit.gd")

## Enemy types that can appear in this dungeon's rooms (picked at random per
## enemy, seeded). Empty = zombies. New enemy scenes just get added here.
@export var enemy_pool: Array[PackedScene] = []
## Enemy scene used for the boss (it is scaled up as rank "boss"). Empty = first of enemy_pool, else zombie.
@export var boss_scene: PackedScene

const CELL := 22.0
const CORRIDOR_W := 3.6
const WALL_H := 6.0
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

@onready var player: Node3D = $Player
@onready var level_root: Node3D = $Level
@onready var enemies_root: Node3D = $Enemies
@onready var nav: NavigationRegion3D = $Navigation

var rng := RandomNumberGenerator.new()
var depth := 1
var seed_used := 0
var rooms: Array = []        # [{cell, center: Vector3, size: Vector2, kind}]
var links: Array = []        # [[room a, room b]] joined by a corridor
var zones: Array = []
var rooms_cleared := 0
var boss: Node3D
var boss_started := false
var boss_dead := false
var _boss_index := -1
var _boss_dir := Vector3.FORWARD
var _gate: StaticBody3D
var _gate_shape: CollisionShape3D
var _exit_mat: StandardMaterial3D
var _exit_light: OmniLight3D
var _complete := false
var _exit_pos := Vector3.ZERO

# Floor stats for the clear screen
var _start_time := 0.0
var _kills := 0
var _loot := 0
var _xp := 0

func _ready() -> void:
	var gm := get_node_or_null("/root/GameManager")
	depth = int(gm.dungeon_depth) if gm else 1
	seed_used = int(gm.dungeon_seed) if gm and int(gm.dungeon_seed) != 0 else randi()
	rng.seed = seed_used
	_generate_layout()
	var rock := _build_geometry()
	_build_boss_room()
	_populate()
	_place_chests()
	var offset: Vector3 = _net().spawn_offset() if _net() else Vector3.ZERO
	player.global_position = rooms[0]["center"] + Vector3(0, 1.0, 0) + offset
	nav.bake_half_extent = _extent() + 12.0
	nav.bake_from(rock)
	_build_ui()
	var bus := get_node("/root/SignalBus")
	bus.enemy_died.connect(_on_enemy_died)
	bus.item_looted.connect(_on_item_looted)
	bus.xp_gained.connect(_on_xp_gained)
	_start_time = Time.get_ticks_msec() / 1000.0
	var gl := get_node_or_null("/root/GameLog")
	if gl:
		gl.info("dungeon", "Floor %d generated (seed %d, %d rooms)" % [depth, seed_used, rooms.size()])
		gl.event("Entered The Crypt — Floor %d" % depth, Color(0.95, 0.75, 0.35))

func _on_enemy_died(_e: Node) -> void:
	_kills += 1

func _on_item_looted(_id: String) -> void:
	_loot += 1

func _on_xp_gained(n: int) -> void:
	_xp += n

# --- Layout ---------------------------------------------------------------------------

func _generate_layout() -> void:
	var main_len := 5 + mini(depth - 1, 3)   # combat rooms between start and boss
	var cells: Array = []
	for attempt in 200:
		cells = [Vector2i.ZERO]
		var ok := true
		for i in main_len + 1:
			var options := []
			for d in DIRS:
				var n: Vector2i = cells.back() + d
				if not cells.has(n):
					options.append(n)
			if options.is_empty():
				ok = false
				break
			cells.append(options[rng.randi_range(0, options.size() - 1)])
		if ok:
			break
	for i in cells.size():
		var kind := "combat"
		var size := Vector2(rng.randi_range(10, 14), rng.randi_range(10, 14))
		if i == 0:
			kind = "start"
			size = Vector2(10, 10)
		elif i == cells.size() - 1:
			kind = "boss"
			size = Vector2(16, 16)
		rooms.append({"cell": cells[i], "center": Vector3(cells[i].x * CELL, 0, cells[i].y * CELL),
			"size": size, "kind": kind})
		if i > 0:
			links.append([i - 1, i])
	_boss_index = cells.size() - 1
	# Side rooms hanging off combat rooms (never next to the boss room).
	var sides := 1 + (1 if depth >= 2 else 0)
	var occupied: Array = cells.duplicate()
	var boss_cell: Vector2i = cells.back()
	for n in sides:
		for attempt in 40:
			var host := rng.randi_range(1, cells.size() - 2)
			var c: Vector2i = cells[host] + DIRS[rng.randi_range(0, 3)]
			if occupied.has(c) or absi(c.x - boss_cell.x) + absi(c.y - boss_cell.y) <= 1:
				continue
			occupied.append(c)
			rooms.append({"cell": c, "center": Vector3(c.x * CELL, 0, c.y * CELL),
				"size": Vector2(rng.randi_range(9, 11), rng.randi_range(9, 11)), "kind": "side"})
			links.append([host, rooms.size() - 1])
			break

func _extent() -> float:
	var m := 0.0
	for r in rooms:
		var c: Vector3 = r["center"]
		m = maxf(m, maxf(absf(c.x), absf(c.z)) + maxf(r["size"].x, r["size"].y))
	return m

# --- Geometry (CSG) ---------------------------------------------------------------------

func _build_geometry() -> CSGCombiner3D:
	var rock := CSGCombiner3D.new()
	rock.name = "Rock"
	rock.use_collision = true
	level_root.add_child(rock)

	var wall := StandardMaterial3D.new()
	wall.albedo_color = Color(0.26, 0.26, 0.3)
	wall.roughness = 1.0
	var top := StandardMaterial3D.new()
	top.albedo_color = Color(0.07, 0.07, 0.08)
	top.roughness = 1.0

	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for r in rooms:
		var c: Vector3 = r["center"]
		var h: Vector2 = r["size"] * 0.5
		mn = mn.min(Vector2(c.x - h.x, c.z - h.y))
		mx = mx.max(Vector2(c.x + h.x, c.z + h.y))
	mn -= Vector2(6, 6)
	mx += Vector2(6, 6)
	var mass := CSGBox3D.new()
	mass.size = Vector3(mx.x - mn.x, 3.0, mx.y - mn.y)
	mass.position = Vector3((mn.x + mx.x) * 0.5, 0.5, (mn.y + mx.y) * 0.5)
	mass.material = top
	rock.add_child(mass)

	for r in rooms:
		_carve(rock, r["center"], Vector3(r["size"].x, WALL_H, r["size"].y), wall)
	for l in links:
		var a: Vector3 = rooms[l[0]]["center"]
		var b: Vector3 = rooms[l[1]]["center"]
		var size := Vector3(absf(b.x - a.x), WALL_H, CORRIDOR_W) if absf(b.x - a.x) > absf(b.z - a.z) \
			else Vector3(CORRIDOR_W, WALL_H, absf(b.z - a.z))
		_carve(rock, (a + b) * 0.5, size, wall)

	# Pillars in some bigger combat rooms (cover / line-of-sight breakers).
	for r in rooms:
		var s: Vector2 = r["size"]
		if r["kind"] == "combat" and minf(s.x, s.y) >= 12 and rng.randf() < 0.6:
			var along_x := rng.randf() < 0.5
			for side in [-1.0, 1.0]:
				var p := CSGCylinder3D.new()
				p.radius = 0.8
				p.height = 3.0
				p.sides = 7
				p.material = wall
				var off := Vector3(side * s.x * 0.25, 0, 0) if along_x else Vector3(0, 0, side * s.y * 0.25)
				p.position = r["center"] + off + Vector3(0, 0.5, 0)
				rock.add_child(p)

	# Lighting: a dim torch light per room (red in the boss room).
	for r in rooms:
		var light := OmniLight3D.new()
		var is_boss: bool = r["kind"] == "boss"
		light.light_color = Color(1.0, 0.35, 0.25) if is_boss else Color(1.0, 0.7, 0.45)
		light.light_energy = 1.6 if is_boss else 0.9
		light.omni_range = maxf(r["size"].x, r["size"].y) * 0.85
		light.position = r["center"] + Vector3(0, 4.2, 0)
		level_root.add_child(light)
	return rock

func _carve(rock: CSGCombiner3D, center: Vector3, size: Vector3, mat: Material) -> void:
	var box := CSGBox3D.new()
	box.operation = CSGShape3D.OPERATION_SUBTRACTION
	box.size = size
	box.position = center + Vector3(0, size.y * 0.5, 0)
	box.material = mat
	rock.add_child(box)

# --- Spawn zones -------------------------------------------------------------------------

func _populate() -> void:
	var last_combat := -1
	for i in rooms.size():
		if rooms[i]["kind"] == "combat":
			last_combat = i
	var combat_index := 0
	for i in rooms.size():
		var r: Dictionary = rooms[i]
		if r["kind"] != "combat" and r["kind"] != "side":
			continue
		var z := Node3D.new()
		z.set_script(SPAWN_ZONE)
		z.name = "SpawnZone%d" % i
		z.size = r["size"] - Vector2(3, 3)
		z.room_index = i
		z.enemy_scenes = enemy_pool
		z.enemy_level = depth + combat_index / 2
		if r["kind"] == "combat":
			combat_index += 1
			z.pack_size = 2 + rng.randi_range(0, 1 + mini(depth - 1, 2))
			var elite := i == last_combat or (combat_index >= 2 and rng.randf() < 0.35 + 0.1 * depth)
			z.elite_count = 1 if elite else 0
		else:
			z.pack_size = 1 + rng.randi_range(0, 1)
			z.elite_count = 1
		level_root.add_child(z)
		z.global_position = r["center"]
		z.spawn(enemies_root, rng)
		z.cleared.connect(_on_zone_cleared)
		zones.append(z)

# --- Chests (random Skill Cards) -----------------------------------------------------
# Side rooms always have one, combat rooms sometimes; both stay locked until
# the room is cleared. The boss drops one more when he dies. Uses its own RNG
# (seeded from the floor seed) so every machine in a party places the same chests.

const CHEST = preload("res://scripts/dungeon/chest.gd")
const COMBAT_CHEST_CHANCE := 0.25
var _chests := {}   # room index -> chest node

## One chest per floor: the boss drops it (2 Skill Cards). Set true to bring
## back the room chests (side rooms always, combat rooms sometimes).
const ROOM_CHESTS := false

func _place_chests() -> void:
	if not ROOM_CHESTS:
		return
	var r := RandomNumberGenerator.new()
	r.seed = seed_used + 7919
	for i in rooms.size():
		var room: Dictionary = rooms[i]
		var kind: String = room["kind"]
		if kind == "side" or (kind == "combat" and r.randf() < COMBAT_CHEST_CHANCE):
			# In a corner, away from the pillars (which sit on the room's axes).
			var h: Vector2 = room["size"] * 0.5 - Vector2(1.6, 1.6)
			var off := Vector3(h.x * (1 if r.randf() < 0.5 else -1), 0, h.y * (1 if r.randf() < 0.5 else -1))
			_chests[i] = _spawn_chest(room["center"] + off, room["center"], true)
	for z in zones:
		if z.is_cleared and _chests.has(int(z.room_index)):
			_chests[int(z.room_index)].unlock()

func _spawn_chest(at: Vector3, face: Vector3, locked: bool) -> Node3D:
	var c := Node3D.new()
	c.set_script(CHEST)
	c.locked = locked
	level_root.add_child(c)
	c.global_position = at
	var dir := face - at
	c.rotation.y = atan2(dir.x, dir.z)   # the chest's front (+Z) faces `face`
	return c

func _on_zone_cleared(zone: Node) -> void:
	if _chests.has(int(zone.room_index)):
		_chests[int(zone.room_index)].unlock()
	rooms_cleared += 1
	_update_header()
	get_node("/root/SignalBus").room_cleared.emit(int(zone.room_index))
	var gl := get_node_or_null("/root/GameLog")
	if gl:
		gl.event("Room cleared (%d / %d)" % [rooms_cleared, zones.size()], Color(0.6, 0.9, 0.6))
	_announce("Room cleared")

# --- Boss room: trigger, sealing gate, exit gate ------------------------------------------

func _build_boss_room() -> void:
	var r: Dictionary = rooms[_boss_index]
	var prev: Dictionary = rooms[_boss_index - 1]
	var c: Vector3 = r["center"]
	_boss_dir = (c - prev["center"]).normalized()
	var along_x := absf(_boss_dir.x) > 0.5
	var half: float = (r["size"].x if along_x else r["size"].y) * 0.5

	# Trigger: stepping well inside the boss room starts the fight.
	var trigger := Area3D.new()
	trigger.name = "BossTrigger"
	trigger.collision_layer = 0
	trigger.collision_mask = 1
	var ts := CollisionShape3D.new()
	var tb := BoxShape3D.new()
	tb.size = Vector3(r["size"].x - 5.0, 3.0, r["size"].y - 5.0)
	ts.shape = tb
	trigger.add_child(ts)
	level_root.add_child(trigger)
	trigger.global_position = c + Vector3(0, 1.5, 0)
	trigger.body_entered.connect(func(b):
		if b.is_in_group("player"):
			_start_boss(b))

	# Gate that seals the doorway during the fight.
	_gate = StaticBody3D.new()
	_gate.name = "BossGate"
	_gate.collision_layer = 1
	_gate_shape = CollisionShape3D.new()
	var gb := BoxShape3D.new()
	gb.size = Vector3(0.6, 4.0, CORRIDOR_W + 0.8) if along_x else Vector3(CORRIDOR_W + 0.8, 4.0, 0.6)
	_gate_shape.shape = gb
	_gate.add_child(_gate_shape)
	var gm := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = gb.size
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.9, 0.15, 0.1, 0.55)
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.emission_enabled = true
	gmat.emission = Color(1.0, 0.2, 0.1)
	gmat.emission_energy_multiplier = 1.5
	bm.material = gmat
	gm.mesh = bm
	_gate.add_child(gm)
	level_root.add_child(_gate)
	_gate.global_position = c - _boss_dir * half + Vector3(0, 2.0, 0)
	_set_gate(false)

	# Exit gate on the far side of the boss room.
	var exit := Node3D.new()
	exit.name = "ExitGate"
	level_root.add_child(exit)
	exit.global_position = c + _boss_dir * (half - 2.2)
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
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var as_ := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.5
	as_.shape = sph
	as_.position = Vector3(0, 1.0, 0)
	area.add_child(as_)
	exit.add_child(area)
	area.body_entered.connect(func(b):
		if b.is_in_group("player") and boss_dead and not _net_client():
			_complete_floor())
	_set_exit_active(false)

func _set_gate(closed: bool) -> void:
	_gate.visible = closed
	_gate_shape.set_deferred("disabled", not closed)

func _set_exit_active(active: bool) -> void:
	var col := Color(0.35, 0.85, 1.0) if active else Color(0.35, 0.3, 0.3)
	_exit_mat.albedo_color = col
	_exit_mat.emission = col
	_exit_mat.emission_energy_multiplier = 3.0 if active else 0.2
	_exit_light.light_color = col
	_exit_light.light_energy = 2.0 if active else 0.0

# --- Multiplayer ------------------------------------------------------------------------
# The host (or single player) runs the boss trigger and the exit gate and tells
# the party through Net.dungeon_event(); party members react in net_event().

func _net() -> Node:
	return get_node_or_null("/root/Net")

func _net_client() -> bool:
	return _net() != null and _net().is_client()

func _party() -> Array:
	return _net().party_bodies() if _net() else [player]

func net_event(ev: String, _data: Dictionary) -> void:
	match ev:
		"boss":
			_spawn_boss()
		"complete":
			_complete_floor()

func _in_boss_room(b: Node3D) -> bool:
	var r: Dictionary = rooms[_boss_index]
	var c: Vector3 = r["center"]
	return absf(b.global_position.x - c.x) < r["size"].x * 0.5 - 2.5 \
		and absf(b.global_position.z - c.z) < r["size"].y * 0.5 - 2.5

func _start_boss(who: Node3D = null) -> void:
	if boss_started or boss_dead or _net_client():
		return
	if who == null:
		who = player
	if not who.is_alive():
		return
	_spawn_boss()
	boss.add_threat(who, 5.0)
	if _net():
		_net().dungeon_event("boss")

func _spawn_boss() -> void:
	if boss_started:
		return
	boss_started = true
	# Solo: the door seals behind you. In a party it stays open so nobody is locked out.
	var seal: bool = not (_net() and _net().with_others())
	if seal:
		_set_gate(true)
	var scene: PackedScene = boss_scene if boss_scene \
		else (enemy_pool[0] if not enemy_pool.is_empty() else DEFAULT_ENEMY)
	boss = scene.instantiate()
	boss.name = "Boss"
	SPAWN_ZONE.tune(boss, "boss", depth + 2)
	var c: Vector3 = rooms[_boss_index]["center"]
	boss.position = enemies_root.to_local(c + _boss_dir * 2.0 + Vector3(0, boss.ground_offset(), 0))
	boss.rotation.y = atan2(_boss_dir.x, _boss_dir.z)   # face the door
	enemies_root.add_child(boss)
	boss.died.connect(_on_boss_died)
	get_node("/root/SignalBus").boss_engaged.emit(boss)
	var gl := get_node_or_null("/root/GameLog")
	if gl:
		gl.event("The %s awakens!" % boss.display_name + (" The door seals behind you." if seal else ""), Color(1.0, 0.4, 0.3))
	_announce("The %s awakens!" % boss.display_name, Color(1.0, 0.4, 0.3))
	_boss_bar.visible = true

func _on_boss_died() -> void:
	boss_dead = true
	_set_gate(false)
	_set_exit_active(true)
	# Boss chest, between the boss spot and the door.
	var bc: Vector3 = rooms[_boss_index]["center"]
	_chests[-1] = _spawn_chest(bc - _boss_dir * 2.5 + _boss_dir.cross(Vector3.UP) * 2.5, bc, false)
	get_node("/root/SignalBus").boss_defeated.emit(boss)
	var gl := get_node_or_null("/root/GameLog")
	if gl:
		gl.event("The %s is defeated. The exit gate is open!" % boss.display_name, Color(0.95, 0.75, 0.35))
	_announce("The exit gate is open!", Color(0.45, 0.9, 1.0))
	var t := create_tween()
	t.tween_interval(2.0)
	t.tween_callback(func(): _boss_bar.visible = false)

func _complete_floor() -> void:
	if _complete:
		return
	_complete = true
	var summary := {
		"depth": depth,
		"time": Time.get_ticks_msec() / 1000.0 - _start_time,
		"kills": _kills,
		"loot": _loot,
		"xp": _xp,
		"rooms": rooms_cleared,
		"rooms_total": zones.size(),
	}
	# Checkpoints: clearing floor 5, 10, 15... lets you start there from the menu.
	var new_checkpoint: bool = get_node("/root/PlayerData").clear_floor(scene_file_path, depth)
	summary["checkpoint"] = new_checkpoint
	get_node("/root/SignalBus").dungeon_cleared.emit(summary)
	var gl := get_node_or_null("/root/GameLog")
	if gl:
		gl.event("Floor %d cleared!" % depth, Color(0.95, 0.75, 0.35))
		if new_checkpoint:
			gl.event("Checkpoint unlocked: you can now start on Floor %d." % depth, Color(0.45, 0.9, 1.0))
	if _net() and _net().is_host():
		_net().dungeon_event("complete")
	_show_clear_screen(summary)
	if not (_net() and _net().with_others()):
		get_tree().paused = true

# --- Dungeon UI: header, boss bar, announcements, clear screen ---------------------------

var _ui: CanvasLayer
var _header: Label
var _boss_bar: VBoxContainer
var _boss_fill: ProgressBar
var _boss_name: Label
var _announce_label: Label
var _announce_tween: Tween

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 3
	_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui)
	_header = UI.label("", 16, UI.ACCENT)
	_header.anchor_left = 0.5
	_header.anchor_right = 0.5
	_header.offset_left = -300
	_header.offset_right = 300
	_header.offset_top = 10
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ui.add_child(_header)
	_update_header()

	_boss_bar = VBoxContainer.new()
	_boss_bar.anchor_left = 0.5
	_boss_bar.anchor_right = 0.5
	_boss_bar.offset_left = -230
	_boss_bar.offset_right = 230
	_boss_bar.offset_top = 36
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
	_boss_bar.visible = false

	_announce_label = UI.label("", 26, UI.ACCENT)
	_announce_label.anchor_left = 0.5
	_announce_label.anchor_right = 0.5
	_announce_label.anchor_top = 0.28
	_announce_label.anchor_bottom = 0.28
	_announce_label.offset_left = -400
	_announce_label.offset_right = 400
	_announce_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce_label.modulate.a = 0.0
	_ui.add_child(_announce_label)

func _update_header() -> void:
	if _header:
		_header.text = "The Crypt — Floor %d   •   Rooms cleared %d / %d" % [depth, rooms_cleared, zones.size()]

func _announce(text: String, color: Color = Color(0.6, 0.95, 0.6)) -> void:
	_announce_label.text = text
	_announce_label.add_theme_color_override("font_color", color)
	_announce_label.modulate.a = 1.0
	if _announce_tween:
		_announce_tween.kill()
	_announce_tween = create_tween()
	_announce_tween.tween_interval(1.6)
	_announce_tween.tween_property(_announce_label, "modulate:a", 0.0, 0.6)

func _process(_delta: float) -> void:
	# Exit gate (also catches a player already standing in it when it opened).
	# In a party the host checks everyone's character.
	if boss_dead and not _complete and not _net_client():
		for b in _party():
			var d := Vector2(b.global_position.x - _exit_pos.x, b.global_position.z - _exit_pos.z)
			if b.is_alive() and d.length() < 1.3:
				_complete_floor()
				break
	# Host: other players' characters don't touch the local trigger Area.
	if not boss_started and not boss_dead and _net() and _net().is_host():
		for b in _party():
			if b.is_alive() and _in_boss_room(b):
				_start_boss(b)
				break
	if _boss_bar and _boss_bar.visible and is_instance_valid(boss):
		_boss_fill.max_value = float(boss.max_health)
		_boss_fill.value = float(boss.health)
		_boss_name.text = "%s  —  %d / %d" % [boss.display_name, boss.health, boss.max_health]

func _show_clear_screen(s: Dictionary) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(shade)
	var panel := UI.small_panel("Floor %d cleared!" % int(s["depth"]))
	panel.offset_left = -230
	panel.offset_right = 230
	panel.offset_top = -190
	panel.offset_bottom = 190
	_ui.add_child(panel)
	var v: VBoxContainer = panel.get_meta("content")
	var secs := int(s["time"])
	for line in [
		"Time: %d:%02d" % [secs / 60, secs % 60],
		"Enemies slain: %d" % int(s["kills"]),
		"Rooms cleared: %d / %d" % [int(s["rooms"]), int(s["rooms_total"])],
		"Items looted: %d" % int(s["loot"]),
		"Experience gained: %d" % int(s["xp"]),
	]:
		var l := UI.label(line, 16, Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	if s.get("checkpoint", false):
		var cp := UI.label("Checkpoint unlocked! You can now start on Floor %d." % int(s["depth"]), 16, Color(0.45, 0.9, 1.0))
		cp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(cp)
		panel.offset_top -= 16
		panel.offset_bottom += 16
	var gm := get_node("/root/GameManager")
	if _net_client():
		# Party member: the leader decides where the group goes next.
		var wait := UI.label("Waiting for %s (party leader)…" % _net().leader_name(), 15, UI.ACCENT)
		wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(wait)
		var leave := UI.button("Leave Group", 18, Vector2(0, 44))
		leave.pressed.connect(_net().leave_run)
		v.add_child(leave)
		return
	var descend := UI.button("Descend to Floor %d" % (depth + 1), 18, Vector2(0, 44))
	descend.pressed.connect(gm.descend)
	v.add_child(descend)
	var lobby := UI.button("Return to Lobby", 18, Vector2(0, 44))
	lobby.pressed.connect(gm.end_run)
	v.add_child(lobby)
