extends RefCounted

# Status effect (buff / debuff) registry. Every StatusEffectData .tres in
# res://data/effects/ is found automatically by its file name — drop a new
# file in the folder and it can be referenced by id everywhere.
# Usage: const Effects = preload("res://scripts/core/effects.gd")
#        Effects.get_effect("burning")          -> StatusEffectData
#        Effects.apply(enemy, "burning", player) -> applies it (true if it changed anything)
#        Effects.has(enemy, "chilled"), Effects.stacks(player, "stormfire")

const DIR := "res://data/effects/"

static var _paths := {}   # id -> path
static var _cache := {}   # id -> Resource

static func _scan() -> void:
	if not _paths.is_empty():
		return
	var d := DirAccess.open(DIR)
	if d == null:
		return
	for f in d.get_files():
		f = f.trim_suffix(".remap")   # exported builds
		if f.ends_with(".tres") or f.ends_with(".res"):
			_paths[f.get_basename()] = DIR + f

## All effect ids, sorted.
static func all_ids() -> Array:
	_scan()
	var out := _paths.keys()
	out.sort()
	return out

static func get_effect(id: String) -> Resource:
	_scan()
	if not _paths.has(id):
		return null
	if not _cache.has(id):
		_cache[id] = load(_paths[id])
	return _cache[id]

static func _status(who: Node) -> Node:
	if who == null or not is_instance_valid(who):
		return null
	return who.get_node_or_null("Status")

## Apply effect `id` to `target` (a character with a Status child).
static func apply(target: Node, id: String, source: Node = null) -> bool:
	var st := _status(target)
	var res := get_effect(id)
	return st.apply(res, source) if st and res else false

static func has(target: Node, id: String) -> bool:
	var st := _status(target)
	return st != null and st.has(id)

static func stacks(target: Node, id: String) -> int:
	var st := _status(target)
	return st.stacks_of(id) if st else 0

static func remove(target: Node, id: String) -> void:
	var st := _status(target)
	if st:
		st.remove(id)
