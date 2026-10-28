extends Node

# Walks a player-sized body (real physics frames) up and down every staircase of
# seeded dungeons, in three lanes, and fails if it gets stuck, falls or ends at
# the wrong height. Test suites can't step physics, so this runs on its own:
#   godot --headless --path . res://tools/walk_check.tscn
# tools/test.sh runs it after the suites. Exit code 0 = every trip made it.

const Layouts = preload("res://scripts/dungeon/layouts.gd")
const Builder = preload("res://scripts/dungeon/biome_builder.gd")
const DB = preload("res://scripts/dungeon/dungeon_db.gd")
const Combat = preload("res://scripts/combat_utils.gd")
const SetPieces = preload("res://scripts/dungeon/set_pieces.gd")

const DUNGEONS := ["fort"]   # dungeon ids whose stairs are walked
const SEEDS := 12
const SPEED := 3.6          # the player's run speed
const STALL_TIME := 0.5     # s: moving less than STALL_DIST in this long = stuck
const STALL_DIST := 0.5
const LANES := [-0.8, 0.0, 0.8]   # metres off the stairs' middle line
const LEVEL_GAP := 80.0           # each test dungeon is built this far below the last

var _trips: Array = []      # {from, to, label}
var _body: CharacterBody3D
var _trip := -1
var _t := 0.0
var _last_t := 0.0
var _last_pos := Vector3.ZERO
var _fails := 0
var _wait := 10             # frames for the CSG collision to build

func _ready() -> void:
	var y := 0.0
	for id in DUNGEONS:
		var r: Resource = DB.find(id)
		for s in (1 if r.layout_scene else SEEDS):   # a hand-made map is the same every seed
			var rng := RandomNumberGenerator.new()
			rng.seed = s + 1
			var layout := _layout(r, rng)
			var b = Builder.new(r.biome, layout, s + 1)
			if b.ramps().is_empty():
				continue
			var holder := Node3D.new()
			holder.position.y = y
			add_child(holder)
			b.build_rock(holder)
			for rp in b.ramps():
				_add_trips(rp[0] + Vector3(0, y, 0), rp[1] + Vector3(0, y, 0), "%s seed %d at %s" % [r.id, s + 1, rp[0]], float(layout.get("corridor", 3.6)))
			# Platforms (towers) of a hand-made map: up their stairs onto the top.
			for room in layout["rooms"]:
				for pc in room.get("pieces", []):
					if str(pc["kind"]) != "platform":
						continue
					var h := float(pc["params"].get("height", 2.5))
					var ends: Array = SetPieces.make_platform(holder, pc["at"] + Vector3(0, y, 0), float(pc["yaw"]),
						pc["params"].get("size", Vector2(3.5, 3.5)), h)
					var low: Vector3 = ends[0]
					var top: Vector3 = ends[1]
					var out := low - top
					out.y = 0.0
					var a := low + out.normalized() * 1.5
					_trips.append({"from": a, "to": top, "label": "%s platform at %s (up)" % [r.id, pc["at"]]})
					_trips.append({"from": top, "to": a, "label": "%s platform at %s (down)" % [r.id, pc["at"]]})
			y -= LEVEL_GAP
	_body = CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	_body.add_child(cs)
	add_child(_body)
	Combat.setup_walker(_body)
	print("walk_check: %d trips" % _trips.size())

func _layout(r: Resource, rng: RandomNumberGenerator) -> Dictionary:
	if r.layout_scene:
		return Layouts.from_scene(r.layout_scene)
	return Layouts.build(str(r.layout), rng, clampi(r.bosses.size(), 1, 4), int(r.rooms_per_section))

func _add_trips(p0: Vector3, p1: Vector3, label: String, corridor: float) -> void:
	var d := p1 - p0
	d.y = 0.0
	d = d.normalized()
	var side := Vector3(-d.z, 0, d.x)
	for lane: float in LANES:
		var off := side * clampf(lane, -corridor * 0.5 + 0.6, corridor * 0.5 - 0.6)
		var a := p0 - d * 2.5 + off
		var b := p1 + d * 2.5 + off
		_trips.append({"from": a, "to": b, "label": "%s (lane %.1f, one way)" % [label, lane]})
		_trips.append({"from": b, "to": a, "label": "%s (lane %.1f, back)" % [label, lane]})

func _next() -> void:
	_trip += 1
	if _trip >= _trips.size():
		print("walk_check: %d / %d trips failed" % [_fails, _trips.size()])
		print("RESULT: %s" % ("PASS" if _fails == 0 else "FAIL"))
		get_tree().quit(0 if _fails == 0 else 1)
		return
	_body.global_position = _trips[_trip]["from"] + Vector3(0, 0.05, 0)
	_body.velocity = Vector3.ZERO
	_t = 0.0
	_last_t = 0.0
	_last_pos = _body.global_position

func _fail(why: String) -> void:
	_fails += 1
	print("FAIL  walk_check > %s: %s at %s" % [_trips[_trip]["label"], why, _body.global_position])
	_next()

func _physics_process(delta: float) -> void:
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			_next()
		return
	if _trip < 0 or _trip >= _trips.size():
		return
	_t += delta
	var to: Vector3 = _trips[_trip]["to"]
	var dir := to - _body.global_position
	dir.y = 0.0
	if not _body.is_on_floor():
		_body.velocity.y -= 9.8 * delta
	var hv := dir.normalized() * SPEED
	_body.velocity.x = hv.x
	_body.velocity.z = hv.z
	_body.move_and_slide()
	if dir.length() < 0.4:
		if absf(_body.global_position.y - to.y) > 0.3:
			_fail("ended at the wrong height (%.2f, wanted %.2f)" % [_body.global_position.y, to.y])
		else:
			_next()
		return
	if _body.global_position.y < to.y - 3.0 and _body.global_position.y < _trips[_trip]["from"].y - 3.0:
		_fail("fell through the floor")
	elif _t - _last_t >= STALL_TIME:
		var moved := Vector2(_body.global_position.x - _last_pos.x, _body.global_position.z - _last_pos.z).length()
		if moved < STALL_DIST:
			_fail("stuck")
		else:
			_last_t = _t
			_last_pos = _body.global_position
