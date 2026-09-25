extends Node3D

# A rectangular area that spawns a pack of enemies (placed by the dungeon
# generator, or by hand in a level). Emits `cleared` when all of them are dead.
#
#   zone.size = Vector2(8, 8); zone.pack_size = 3; zone.elite_count = 1
#   zone.spawn(enemies_parent, rng)

signal cleared(zone: Node)

## Used when neither enemy_scenes nor enemy_scene is set.
const DEFAULT_ENEMY_SCENE := "res://scenes/zombie.tscn"

@export var size := Vector2(8, 8)
@export var pack_size := 3
@export var elite_count := 0
@export var enemy_level := 1
## Enemy types this zone can spawn; each enemy picks one at random (seeded, so
## every machine in a party spawns the same ones).
@export var enemy_scenes: Array[PackedScene] = []
## Single enemy type (older setting; used when enemy_scenes is empty).
@export var enemy_scene: PackedScene
@export var room_index := -1

var enemies: Array = []
var _alive := 0
var is_cleared := false

func _pick_scene(rng: RandomNumberGenerator) -> PackedScene:
	if not enemy_scenes.is_empty():
		return enemy_scenes[rng.randi_range(0, enemy_scenes.size() - 1)]
	return enemy_scene if enemy_scene else load(DEFAULT_ENEMY_SCENE)

func spawn(parent: Node, rng: RandomNumberGenerator) -> void:
	var total := pack_size + elite_count
	var points := _pick_points(total, rng)
	for i in points.size():
		var rank := "elite" if i < elite_count else "normal"
		var e: Node3D = _pick_scene(rng).instantiate()
		# Fixed name: in multiplayer every machine must name the same enemy the same.
		e.name = "%s_E%d" % [name, i]
		tune(e, rank, enemy_level)
		e.position = parent.to_local(Vector3(points[i].x, global_position.y + e.ground_offset(), points[i].y))
		e.rotation.y = rng.randf() * TAU
		parent.add_child(e)
		enemies.append(e)
		_alive += 1
		e.died.connect(_on_enemy_died)
	if _alive == 0:
		is_cleared = true

# Random points inside the zone, at least 1.6 m apart.
func _pick_points(count: int, rng: RandomNumberGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var half := size * 0.5
	for i in count:
		var best := Vector2.ZERO
		for attempt in 30:
			var p := Vector2(global_position.x + rng.randf_range(-half.x, half.x),
				global_position.z + rng.randf_range(-half.y, half.y))
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

func _on_enemy_died() -> void:
	_alive -= 1
	if _alive <= 0 and not is_cleared:
		is_cleared = true
		cleared.emit(self)

## Scale an enemy for its rank and level. Call BEFORE adding it to the tree.
## The scaling itself lives in enemy.gd (apply_rank), so it works for every
## enemy type, based on that type's own stats.
static func tune(e: Node, rank: String, lvl: int) -> void:
	e.apply_rank(rank, lvl)
