class_name LootTableData
extends Resource

## Data-driven drop table. An enemy points at one of these (enemy.gd `loot`).
## roll(level) returns NEW item instance ids (ItemDB) ready to drop:
##   1. every `guaranteed` entry drops
##   2. every `chance_drops` entry rolls its own `chance`
##   3. `pool_rolls` times, one weighted pick from `pool` (or nothing, see nothing_weight)
## Each dropped item rolls a rarity from `rarity_weights` and may get an rune.

const ItemDB = preload("res://scripts/core/item_db.gd")
const Runes = preload("res://scripts/runes.gd")

@export var guaranteed: Array[Resource] = []
@export var chance_drops: Array[Resource] = []
@export var pool: Array[Resource] = []
@export_range(0, 10) var pool_rolls: int = 0
## Weight of "no drop" in each pool roll.
@export_range(0.0, 1000.0, 0.1) var nothing_weight: float = 0.0

@export_group("Rarity & runes")
## Weights for Common, Uncommon, Rare, Epic.
@export var rarity_weights: PackedFloat32Array = PackedFloat32Array([70.0, 22.0, 7.0, 1.0])
## Chance for each dropped item to carry a random rune.
@export_range(0.0, 1.0, 0.01) var rune_chance: float = 0.3
## Added to the enemy level to get the item level.
@export var item_level_bonus: int = 0
## Runes come from the player's "unlocked pool" (Runes.unlocked_pool: runes
## unlocked at the player's level + runes they know) instead of every rune.
@export var use_unlocked_pool: bool = false

## `rune_pool`: rune ids runes are drawn from (empty = every rune).
func roll(level: int = 1, rng: RandomNumberGenerator = null, rune_pool: Array = []) -> Array[String]:
	_pool = rune_pool if not rune_pool.is_empty() else Runes.ALL
	var r := rng if rng else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var picks: Array[Resource] = []
	for e in guaranteed:
		if e:
			picks.append(e)
	for e in chance_drops:
		if e and r.randf() < float(e.chance):
			picks.append(e)
	for i in pool_rolls:
		var p := _weighted_pick(r)
		if p:
			picks.append(p)
	var out: Array[String] = []
	for e in picks:
		out.append(make_item(e, level, r))
	return out

var _pool: Array = []

func make_item(entry: Resource, level: int, r: RandomNumberGenerator) -> String:
	var rarity := roll_rarity(r)
	if int(entry.min_rarity) >= 0:
		rarity = maxi(rarity, int(entry.min_rarity))
	var rune := ""
	var pool: Array = _pool if not _pool.is_empty() else Runes.ALL
	if r.randf() < rune_chance and not pool.is_empty():
		rune = Runes.pick_weighted(pool, r)   # rarer runes drop less often
	return ItemDB.create_rolled(str(entry.item_id), maxi(level + item_level_bonus, 1), rarity, rune)

func roll_rarity(r: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in rarity_weights:
		total += maxf(w, 0.0)
	if total <= 0.0:
		return 0
	var x := r.randf() * total
	for i in rarity_weights.size():
		x -= maxf(rarity_weights[i], 0.0)
		if x < 0.0:
			return mini(i, 3)
	return 0

func _weighted_pick(r: RandomNumberGenerator) -> Resource:
	var total := maxf(nothing_weight, 0.0)
	for e in pool:
		if e:
			total += maxf(float(e.weight), 0.0)
	if total <= 0.0:
		return null
	var x := r.randf() * total
	for e in pool:
		if e:
			x -= maxf(float(e.weight), 0.0)
			if x < 0.0:
				return e
	return null   # landed on "nothing"
