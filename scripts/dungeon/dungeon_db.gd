extends RefCounted

# The list of dungeons: every recipe in res://data/dungeons/ (found
# automatically - drop a new .tres in there and it shows up), plus the legacy
# hand-made scenes kept for testing. Also turns queue keys into scenes and works
# out the enemy level for a party.
#
# Queue keys (what the Play screen queues for / what matchmaking matches on):
#   "dungeon:random"   a random dungeon from the pool (picked when the run starts)
#   "dungeon:<id>"     that specific dungeon (testing)

const Names = preload("res://scripts/dungeon/names.gd")
const Balance = preload("res://scripts/balance.gd")

const RECIPE_DIR := "res://data/dungeons/"
const RUN_SCENE := "res://scenes/dungeon_run.tscn"
const RANDOM_KEY := "dungeon:random"
const PREFIX := "dungeon:"

## Old hand-built dungeons: playable from the "specific dungeon" list, never random.
const LEGACY := [
	{"id": "legacy_crypt", "scene": "res://scenes/dungeon.tscn", "name": "dng_legacy_crypt",
		"desc": "dng_legacy_crypt_desc"},
]

static var _cache: Array = []

## Every recipe, sorted by id.
static func recipes() -> Array:
	if not _cache.is_empty():
		return _cache
	var files: Array[String] = []
	var dir := DirAccess.open(RECIPE_DIR)
	if dir:
		for f in dir.get_files():
			# Exported builds list "x.tres.remap"; load() still takes "x.tres".
			var file := f.trim_suffix(".remap")
			if file.ends_with(".tres") and not files.has(file):
				files.append(file)
	files.sort()
	for f in files:
		var r: Resource = load(RECIPE_DIR + f)
		if r != null and str(r.get("id")) != "":
			_cache.append(r)
	return _cache

static func find(id: String) -> Resource:
	for r in recipes():
		if str(r.id) == id:
			return r
	return null

static func random_pool() -> Array:
	return recipes().filter(func(r): return bool(r.in_random_pool))

static func legacy(id: String) -> Dictionary:
	for l in LEGACY:
		if str(l["id"]) == id:
			return l
	return {}

static func key_for(id: String) -> String:
	return PREFIX + id

static func is_dungeon_key(key: String) -> bool:
	return key.begins_with(PREFIX)

## Display name for a queue key or dungeon id.
static func title(key_or_id: String) -> String:
	var id := key_or_id.trim_prefix(PREFIX)
	if id == "random":
		return Names.t("dng_random")
	var r := find(id)
	if r:
		return Names.t(str(r.name_key))
	var l := legacy(id)
	if not l.is_empty():
		return Names.t(str(l["name"]))
	return id.capitalize()

static func description(key_or_id: String) -> String:
	var id := key_or_id.trim_prefix(PREFIX)
	if id == "random":
		return Names.t("dng_random_desc")
	var r := find(id)
	if r:
		return Names.t(str(r.desc_key))
	var l := legacy(id)
	return Names.t(str(l.get("desc", ""))) if not l.is_empty() else ""

## Turn a queue key into {"path": scene to load, "dungeon": recipe id ("" = none)}.
## A random key picks from the pool with `rng_value` (the host decides once).
static func resolve(key: String, rng_value: int) -> Dictionary:
	if not is_dungeon_key(key):
		return {"path": key, "dungeon": ""}   # a plain scene path (Training Room...)
	var id := key.trim_prefix(PREFIX)
	if id == "random":
		var pool := random_pool()
		if pool.is_empty():
			return {"path": RUN_SCENE, "dungeon": ""}
		id = str(pool[posmod(rng_value, pool.size())].id)
	var l := legacy(id)
	if not l.is_empty():
		return {"path": str(l["scene"]), "dungeon": id}
	return {"path": RUN_SCENE, "dungeon": id}

## Enemy level for a group: the average, pulled up toward the highest level
## (Balance.DUNGEON_LEVEL_TOP_WEIGHT), so a max-level player can't easily carry
## a level 1 friend. Solo = your own level.
static func party_level(levels: Array) -> int:
	if levels.is_empty():
		return 1
	var total := 0.0
	var top := 1
	for l in levels:
		total += float(l)
		top = maxi(top, int(l))
	var avg := total / float(levels.size())
	var w := clampf(Balance.DUNGEON_LEVEL_TOP_WEIGHT, 0.0, 1.0)
	return clampi(int(round(avg + (float(top) - avg) * w)), 1, 50)
