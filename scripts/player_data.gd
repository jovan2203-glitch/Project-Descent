extends Node

# Global player inventory + equipment + runes + talents (autoload "PlayerData").
# Survives scene changes (death/restart, main menu <-> game).

signal changed
signal item_looted(id: String)

const Items = preload("res://scripts/items.gd")
const ItemDB = preload("res://scripts/core/item_db.gd")
const INVENTORY_SIZE := 20
const OFF_HAND := "Off Hand"
const MAIN_HAND := "Main Hand"

const BANK_SIZE := 300
const ACTION_SLOTS := 8

# --- Runes --------------------------------------------------------------
# Runes live on items ("sword|frost"). Extracting/transferring an rune
# teaches it permanently (known_runes); known runes can be applied to any
# equipped item from the Runes panel.
const Runes = preload("res://scripts/runes.gd")
const Talents = preload("res://scripts/talents.gd")
var known_runes: Array[String] = []
var gear_runes := {}   # legacy (slot-based runes) — folded into items on load

func learn_rune(rune_id: String) -> void:
	if rune_id != "" and not known_runes.has(rune_id):
		known_runes.append(rune_id)

## Rune limits (1 legendary, 4 different epics, max copies of the same rune):
## why `equip` (slot -> item) would break them, or "" if it's fine.
static func rune_limit_error(equip: Dictionary) -> String:
	var ids := []
	for slot in equip:
		ids.append(Items.rune_of(str(equip[slot])))
	return Runes.check_limits(ids)

## Rune limit check for equipping `item` into `slot` (optionally emptying `also_clear`).
func _equip_rune_error(slot: String, item: String, also_clear: String = "") -> String:
	var after := equipment.duplicate()
	after[slot] = item
	if also_clear != "":
		after.erase(also_clear)
	return rune_limit_error(after)

# Apply a known rune to the item equipped in `slot` (replaces any rune on it).
func apply_rune(slot: String, rune_id: String) -> String:
	if not known_runes.has(rune_id):
		return "You haven't learned that rune"
	var item: String = equipment.get(slot, "")
	if item == "":
		return "No item equipped in %s" % slot
	var ids := []
	for s in equipment:
		ids.append(rune_id if s == slot else Items.rune_of(str(equipment[s])))
	var err := Runes.check_limits(ids)
	if err != "":
		return err
	equipment[slot] = Items.with_rune(item, rune_id)
	changed.emit()
	return ""

# Item references: {"where": "bank"|"inv", "index": i} or {"where": "equip", "slot": s}
func get_item_at(ref: Dictionary) -> String:
	match ref.get("where", ""):
		"bank": return bank[int(ref["index"])]
		"inv": return inventory[int(ref["index"])]
		"equip": return equipment.get(str(ref["slot"]), "")
	return ""

func _set_item_at(ref: Dictionary, item: String) -> void:
	match ref.get("where", ""):
		"bank": bank[int(ref["index"])] = item
		"inv": inventory[int(ref["index"])] = item
		"equip":
			if item == "":
				equipment.erase(str(ref["slot"]))
			else:
				equipment[str(ref["slot"])] = item

func same_ref(a: Dictionary, b: Dictionary) -> bool:
	return a.get("where") == b.get("where") and a.get("index", -1) == b.get("index", -1) \
		and a.get("slot", "") == b.get("slot", "")

# All items (bank + equipped), optionally filtered by whether they're runed.
func list_items(runed: int = -1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot in equipment:
		var it: String = equipment[slot]
		if it != "" and (runed == -1 or (Items.rune_of(it) != "") == (runed == 1)):
			out.append({"where": "equip", "slot": slot})
	for i in BANK_SIZE:
		var it2 := bank[i]
		if it2 != "" and (runed == -1 or (Items.rune_of(it2) != "") == (runed == 1)):
			out.append({"where": "bank", "index": i})
	return out

# Learn the source item's rune and destroy the item.
func extract_rune(src: Dictionary) -> String:
	var item := get_item_at(src)
	var e := Items.rune_of(item)
	if e == "":
		return "That item has no rune"
	learn_rune(e)
	_set_item_at(src, "")
	ItemDB.destroy(item)
	changed.emit()
	return ""

# Move the source's rune onto the target, learn it, destroy the source.
func transfer_rune(src: Dictionary, tgt: Dictionary) -> String:
	if same_ref(src, tgt):
		return "Pick two different items"
	var item := get_item_at(src)
	var target := get_item_at(tgt)
	var e := Items.rune_of(item)
	if e == "":
		return "The source item has no rune"
	if target == "":
		return "Pick a target item"
	if tgt.get("where", "") == "equip":
		var ids := []
		for s in equipment:
			ids.append(e if s == str(tgt["slot"]) else Items.rune_of(str(equipment[s])))
		if src.get("where", "") == "equip":
			ids[equipment.keys().find(str(src["slot"]))] = ""   # the source item is destroyed
		var err := Runes.check_limits(ids)
		if err != "":
			return err
	learn_rune(e)
	_set_item_at(tgt, Items.with_rune(target, e))
	_set_item_at(src, "")
	ItemDB.destroy(item)
	changed.emit()
	return ""

## Every item instance id currently owned (bag, bank, equipped).
func all_item_ids() -> Array:
	var out := []
	for list in [inventory, bank, equipment.values()]:
		for id in list:
			if str(id) != "":
				out.append(str(id))
	return out

# --- Progression: XP and levels ----------------------------------------------------
# Kill XP comes in through GameManager (enemy_died -> add_xp). Levels raise base
# stats (level_stats) and give talent points (Talents.points_for_level).
const MAX_LEVEL := 50
## A level-up draft (new ability) is offered every this many levels (2, 4, 6...).
const DRAFT_EVERY := 2
var level := 1

static func is_draft_level(lv: int) -> bool:
	return lv >= DRAFT_EVERY and lv % DRAFT_EVERY == 0
var xp := 0

# --- Draft build: abilities learned from level-up drafts + Skill Card loadout ------
const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
var learned_abilities: Array[String] = []   # drafted abilities (permanent)
var equipped_cards: Array[String] = []      # Skill Card loadout (card ids)
var draft_boons := {}                       # stat -> permanent bonus from draft boons
var pending_drafts: Array[int] = []         # levels still waiting for a draft pick
## A guaranteed Skill Card ability was passed over: the next level-up (even one
## without a normal draft) offers it again.
var card_reoffer := false

## Abilities the player can use / put on the bar: base kit + drafted ones.
func available_abilities() -> Array[String]:
	var out: Array[String] = []
	for id in Abilities.ALL:
		if Abilities.BASE.has(id) or learned_abilities.has(id):
			out.append(id)
	return out

func has_ability(id: String) -> bool:
	return Abilities.BASE.has(id) or learned_abilities.has(id)

## Learn a drafted ability; it goes into the first empty action bar slot.
func learn_ability(id: String) -> void:
	if id == "" or has_ability(id):
		return
	learned_abilities.append(id)
	var free := action_bar.find("")
	if free != -1:
		action_bar[free] = id
	var bus := _bus()
	if bus:
		bus.ability_learned.emit(id)
	changed.emit()

func add_boon(stat: String, amount: float) -> void:
	draft_boons[stat] = float(draft_boons.get(stat, 0.0)) + amount
	changed.emit()

func toggle_card(card_id: String) -> String:
	if equipped_cards.has(card_id):
		equipped_cards.erase(card_id)
	elif not SkillCards.exists(card_id):
		return "Unknown Skill Card"
	elif not owned_cards.has(card_id):
		return "You haven't found that Skill Card yet (open chests in dungeons)"
	elif equipped_cards.size() >= SkillCards.MAX_EQUIPPED:
		return "You can equip up to %d Skill Cards" % SkillCards.MAX_EQUIPPED
	else:
		equipped_cards.append(card_id)
	changed.emit()
	return ""

func _bus() -> Node:
	return get_node_or_null("/root/SignalBus") if is_inside_tree() else null

# --- Skill Card collection (found in chests; permanent, survives death) ----------
var owned_cards: Array[String] = []

## Add a card to the collection. Returns false if it's unknown or already owned.
func grant_card(card_id: String) -> bool:
	if not SkillCards.exists(card_id) or owned_cards.has(card_id):
		return false
	owned_cards.append(card_id)
	changed.emit()
	return true

## A random card the player doesn't own yet ("" if they own them all).
func random_unowned_card(rng: RandomNumberGenerator = null) -> String:
	var pool: Array = SkillCards.ALL.filter(func(c): return not owned_cards.has(c))
	if pool.is_empty():
		return ""
	var i := rng.randi_range(0, pool.size() - 1) if rng else randi() % pool.size()
	return str(pool[i])

# --- Dungeon checkpoints (permanent, survive death) ---------------------------------
# Clearing floor 5, 10, 15... of a floor-based dungeon unlocks starting a run
# directly on that floor from the Play / queue screen.
const CHECKPOINT_EVERY := 5
var checkpoints := {}   # dungeon scene path -> highest checkpoint floor unlocked

static func is_checkpoint_floor(floor_n: int) -> bool:
	return floor_n >= CHECKPOINT_EVERY and floor_n % CHECKPOINT_EVERY == 0

## Called when a floor is cleared. Returns true if a new checkpoint was unlocked.
func clear_floor(scene_path: String, floor_n: int) -> bool:
	if not is_checkpoint_floor(floor_n) or floor_n <= int(checkpoints.get(scene_path, 0)):
		return false
	checkpoints[scene_path] = floor_n
	changed.emit()
	return true

## Floors you can start this dungeon on: 1 plus every unlocked checkpoint.
func start_floors(scene_path: String) -> Array[int]:
	var out: Array[int] = [1]
	var best := int(checkpoints.get(scene_path, 0))
	var f := CHECKPOINT_EVERY
	while f <= best:
		out.append(f)
		f += CHECKPOINT_EVERY
	return out

# --- Roguelike death + level lock -----------------------------------------------
# Dying: level drops to 1 (or to the level lock), equipped gear and the bag are
# lost (runes on lost items are learned first), drafted abilities and draft boons
# are lost. The bank, known runes and the Skill Card collection stay.
# With a level lock (10, 20, 30...), equipped gear you can still wear at the
# lock level is kept, and the drafts for every draft level up to it are
# re-offered so the build can be rebuilt (Skill Cards guarantee their picks).
const LEVEL_LOCK_STEP := 10
## Bag contents are lost on death too (set true to keep them instead).
const KEEP_BAG_ON_DEATH := false
var level_lock := 0            # 0 = no lock
var last_death := {}           # summary of the most recent death (HUD shows it)

## Valid lock levels right now (multiples of 10 up to your current level).
func lock_options() -> Array[int]:
	var out: Array[int] = []
	var lv := LEVEL_LOCK_STEP
	while lv <= MAX_LEVEL:
		if lv <= level:
			out.append(lv)
		lv += LEVEL_LOCK_STEP
	return out

## Set the level lock (0 clears it). Returns an error message or "".
func set_level_lock(lv: int) -> String:
	if lv != 0:
		if lv % LEVEL_LOCK_STEP != 0 or lv < LEVEL_LOCK_STEP or lv > MAX_LEVEL:
			return "Level lock must be a multiple of %d" % LEVEL_LOCK_STEP
		if lv > level:
			return "Reach level %d to lock it" % lv
	level_lock = lv
	changed.emit()
	return ""

## Can the item be equipped at this player level?
func level_ok(item: String, at_level: int = -1) -> bool:
	return Items.required_level(item) <= (level if at_level < 0 else at_level)

func _lose_item(item: String, lost: Array, runes_learned: Array) -> void:
	if item == "":
		return
	var r := Items.rune_of(item)
	if r != "":
		if not known_runes.has(r) and not runes_learned.has(r):
			runes_learned.append(r)
		learn_rune(r)
	lost.append(Items.item_name(item))
	ItemDB.destroy(item)

## Apply the death penalty. Returns (and stores in last_death) a summary.
func apply_death() -> Dictionary:
	var old_level := level
	var new_level := mini(level_lock, level) if level_lock > 0 else 1
	new_level = maxi(new_level, 1)
	var lost: Array = []
	var kept: Array = []
	var runes_learned: Array = []
	# Equipped gear: lost, unless a level lock is set and it's wearable at the lock level.
	for slot in equipment.keys():
		var it: String = equipment[slot]
		if level_lock > 0 and level_ok(it, new_level):
			kept.append(Items.item_name(it))
			continue
		_lose_item(it, lost, runes_learned)
		equipment.erase(slot)
	if not KEEP_BAG_ON_DEATH:
		for i in INVENTORY_SIZE:
			if inventory[i] != "":
				_lose_item(inventory[i], lost, runes_learned)
				inventory[i] = ""
	# Abilities: drafted ones are gone (the base kit stays).
	var lost_abilities := learned_abilities.size()
	learned_abilities.clear()
	for i in action_bar.size():
		if action_bar[i] != "" and not Abilities.BASE.has(action_bar[i]):
			action_bar[i] = ""
	draft_boons.clear()
	# Level + XP.
	level = new_level
	xp = 0
	pending_drafts.clear()
	card_reoffer = false
	for lv in range(DRAFT_EVERY, level + 1):
		if is_draft_level(lv):
			pending_drafts.append(lv)   # rebuild your abilities at the lock level
	validate_talents()
	validate_attributes()
	last_death = {"old_level": old_level, "new_level": new_level, "lost": lost, "kept": kept,
		"runes_learned": runes_learned, "abilities_lost": lost_abilities, "lock": level_lock}
	var bus := _bus()
	if bus:
		bus.xp_changed.emit(level, xp, xp_to_next(level))
	changed.emit()
	return last_death

static func xp_to_next(lv: int) -> int:
	return 0 if lv >= MAX_LEVEL else 20 + (lv - 1) * 15

func add_xp(amount: int) -> void:
	if amount <= 0 or level >= MAX_LEVEL:
		return
	xp += amount
	var bus := _bus()
	if bus:
		bus.xp_gained.emit(amount)
	while level < MAX_LEVEL and xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		if is_draft_level(level):
			pending_drafts.append(level)   # the Draft overlay picks these up
		elif card_reoffer and not pending_drafts.has(level):
			pending_drafts.append(level)   # re-offer the Skill Card you skipped
		if bus:
			bus.level_up.emit(level)
	if level >= MAX_LEVEL:
		xp = 0
	if bus:
		bus.xp_changed.emit(level, xp, xp_to_next(level))
	changed.emit()

## Debug / admin: jump to a level (XP resets, talents refunded if over budget).
func set_level(lv: int) -> void:
	level = clampi(lv, 1, MAX_LEVEL)
	xp = 0
	validate_talents()
	validate_attributes()
	var bus := _bus()
	if bus:
		bus.xp_changed.emit(level, xp, xp_to_next(level))
	changed.emit()

# --- Attribute points: 1 per level gained, spent on Intellect / Agility / Strength /
# Health / Mana. In game (level-up screen) points can only be added; in the main
# menu's Character tab they can be moved around freely.
const ATTRIBUTE_POINTS_PER_LEVEL := 1
## Stat -> how much one point gives. Primaries are 1:1 (they also feed derived
## stats, see Stats.DERIVED); straight Health / Mana points give more.
const ATTRIBUTE_VALUES := {
	"intellect": 1.0,
	"agility": 1.0,
	"strength": 1.0,
	"max_health": 3.0,
	"max_mana": 3.0,
}
const ATTRIBUTE_ORDER := ["strength", "agility", "intellect", "max_health", "max_mana"]
var attribute_points := {}   # stat -> points spent

func attribute_points_total() -> int:
	return (level - 1) * ATTRIBUTE_POINTS_PER_LEVEL

func attribute_points_spent() -> int:
	var n := 0
	for s in attribute_points:
		n += int(attribute_points[s])
	return n

func attribute_points_left() -> int:
	return attribute_points_total() - attribute_points_spent()

func attribute_rank(stat: String) -> int:
	return int(attribute_points.get(stat, 0))

## Spend `amount` points on `stat`. Returns an error message or "".
func add_attribute_point(stat: String, amount: int = 1) -> String:
	if not ATTRIBUTE_VALUES.has(stat):
		return "Unknown attribute"
	if amount <= 0:
		return ""
	if attribute_points_left() < amount:
		return "No attribute points left"
	attribute_points[stat] = attribute_rank(stat) + amount
	changed.emit()
	return ""

## Take a point back (main menu only — the level-up screen can't refund).
func remove_attribute_point(stat: String) -> String:
	if attribute_rank(stat) <= 0:
		return "No points in that attribute"
	attribute_points[stat] = attribute_rank(stat) - 1
	if int(attribute_points[stat]) <= 0:
		attribute_points.erase(stat)
	changed.emit()
	return ""

func reset_attributes() -> void:
	attribute_points.clear()
	changed.emit()

## Refund everything if more points are spent than the level allows (death).
func validate_attributes() -> bool:
	if attribute_points_spent() > attribute_points_total():
		attribute_points.clear()
		return false
	return true

func attribute_stats() -> Dictionary:
	var out := {}
	for s in attribute_points:
		out[s] = float(attribute_points[s]) * float(ATTRIBUTE_VALUES.get(s, 0.0))
	return out

## Base stats that grow with level (added to gear + talents).
func level_stats() -> Dictionary:
	var every4 := float((level - 1) / 4)
	return {"max_health": float(level - 1), "spell_power": every4, "attack_power": every4}


# --- Talents -----------------------------------------------------------------------
var talents := {}   # talent id -> rank

func talent_points_total() -> int:
	return Talents.points_for_level(level)

## Refund everything if more points are spent than the level allows.
func validate_talents() -> bool:
	if talent_points_spent() > talent_points_total():
		talents.clear()
		return false
	return true

func talent_rank(id: String) -> int:
	return int(talents.get(id, 0))

func talent_points_spent() -> int:
	var n := 0
	for id in talents:
		n += int(talents[id])
	return n

func talent_points_left() -> int:
	return talent_points_total() - talent_points_spent()

func tier_points(tier: int) -> int:
	var n := 0
	for id in talents:
		if Talents.tier_of(id) == tier:
			n += int(talents[id])
	return n

## Rows are global: row N opens in every tree once POINTS_TO_UNLOCK_NEXT points
## are spent in row N-1 across all trees combined.
func tier_unlocked(tier: int) -> bool:
	return tier == 0 or tier_points(tier - 1) >= Talents.POINTS_TO_UNLOCK_NEXT

## Points spent in one category's tree.
func tree_points(category: String) -> int:
	var n := 0
	for id in talents:
		if Talents.category_of(id) == category:
			n += int(talents[id])
	return n

# Returns "" if allowed, otherwise the reason.
func can_invest(id: String) -> String:
	var t := Talents.get_talent(id)
	if t.is_empty():
		return "Unknown talent"
	if talent_points_left() <= 0:
		return "No talent points left"
	if talent_rank(id) >= int(t["max_rank"]):
		return "Already at max rank"
	if not tier_unlocked(int(t["tier"])):
		return "Requires %d points in row %d (any tree)" % [Talents.POINTS_TO_UNLOCK_NEXT, int(t["tier"])]
	return ""

func can_refund(id: String) -> String:
	if talent_rank(id) <= 0:
		return "No points to refund"
	var tier := Talents.tier_of(id)
	# Would removing a point starve a lower row that already has points?
	for later in range(tier + 1, Talents.ROWS):
		if tier_points(later) > 0:
			var after := tier_points(later - 1) - (1 if later - 1 == tier else 0)
			if after < Talents.POINTS_TO_UNLOCK_NEXT:
				return "Points in row %d depend on this row" % (later + 1)
	return ""

func invest_talent(id: String) -> String:
	var err := can_invest(id)
	if err == "":
		talents[id] = talent_rank(id) + 1
		changed.emit()
	return err

func refund_talent(id: String) -> String:
	var err := can_refund(id)
	if err == "":
		talents[id] = talent_rank(id) - 1
		if talents[id] <= 0:
			talents.erase(id)
		changed.emit()
	return err

func reset_talents() -> void:
	talents.clear()
	changed.emit()

# --- Stats (gear + talents; buffs are added by the player at runtime) -------------

func gear_stats() -> Dictionary:
	var out := {}
	for slot in equipment:
		var d := Items.get_item(equipment[slot])
		for stat in d.get("stats", {}):
			out[stat] = float(out.get(stat, 0.0)) + float(d["stats"][stat])
	return out

func talent_stats() -> Dictionary:
	var out := {}
	for id in talents:
		var t := Talents.get_talent(id)
		for stat in t.get("stats", {}):
			out[stat] = float(out.get(stat, 0.0)) + float(t["stats"][stat]) * int(talents[id])
	return out

## Gear + talents + level + draft boons. Read many times per frame (movement,
## every hit), so the result is cached: rebuilt after `changed` fires and at
## most once per frame otherwise. Treat the returned dictionary as read-only.
func total_stats() -> Dictionary:
	var frame := Engine.get_process_frames()
	if _stats_dirty or frame != _stats_frame:
		_stats_cache = _compute_total_stats()
		_stats_frame = frame
		_stats_dirty = false
	return _stats_cache

var _stats_cache := {}
var _stats_frame := -1
var _stats_dirty := true

func _compute_total_stats() -> Dictionary:
	var out := gear_stats()
	for extra in [talent_stats(), level_stats(), draft_boons, attribute_stats()]:
		for stat in extra:
			out[stat] = float(out.get(stat, 0.0)) + float(extra[stat])
	return out

func _invalidate_stats() -> void:
	_stats_dirty = true

# Action bar layout: ability id per slot ("" = empty). Keys 1-8 use this.
var action_bar: Array[String] = ["frostbolt", "blizzard", "rayoffrost", "", "", "", "", ""]

# Put ability `id` in bar slot `to`. `from` = the bar slot it was dragged from
# (swap), or -1 when it came from the unplaced list.
func set_action_slot(to: int, id: String, from: int) -> void:
	if to < 0 or to >= ACTION_SLOTS:
		return
	if from >= 0 and from < ACTION_SLOTS:
		var tmp := action_bar[to]
		action_bar[to] = action_bar[from]
		action_bar[from] = tmp
	else:
		var existing := action_bar.find(id)
		if existing != -1:
			action_bar[existing] = ""
		action_bar[to] = id
	changed.emit()

func clear_action_slot(slot: int) -> void:
	if slot >= 0 and slot < ACTION_SLOTS:
		action_bar[slot] = ""
		changed.emit()

var inventory: Array[String] = []      # "" = empty slot
var equipment := {}                    # slot name -> item id
var bank: Array[String] = []

func _ready() -> void:
	# Connected first, so every other listener reads fresh stats.
	changed.connect(_invalidate_stats)
	inventory.resize(INVENTORY_SIZE)
	for i in INVENTORY_SIZE:
		inventory[i] = ""
	bank.resize(BANK_SIZE)
	for i in BANK_SIZE:
		bank[i] = ""

# Leaving the game: bag contents go to the bank (equipped gear stays on).
# Items that don't fit stay in the inventory. Returns how many moved.
func move_inventory_to_bank() -> int:
	var moved := 0
	for i in INVENTORY_SIZE:
		if inventory[i] == "":
			continue
		var free := bank.find("")
		if free == -1:
			break
		bank[free] = inventory[i]
		inventory[i] = ""
		moved += 1
	if moved > 0:
		changed.emit()
	return moved

# Equip bank item `index`; whatever was in that slot goes into the bank slot it
# came from. Returns an error message or "".
func equip_from_bank(index: int, to_slot: String = "") -> String:
	if index < 0 or index >= BANK_SIZE or bank[index] == "":
		return "Nothing to equip"
	var id := bank[index]
	var item := Items.get_item(id)
	if item.get("slot", "") == "":
		return "Can't equip that"
	var slot := _pick_slot(id, to_slot)
	if slot == "":
		return "That doesn't go in %s" % to_slot
	if not level_ok(id):
		return "Requires level %d" % Items.required_level(id)
	if is_slot_locked(slot):
		return "Off Hand is locked by a two-handed weapon"
	var old: String = equipment.get(slot, "")
	var offhand_item: String = equipment.get(OFF_HAND, "")
	var bumps_offhand: bool = item.get("locks_offhand", false) and offhand_item != ""
	var rune_err := _equip_rune_error(slot, id, OFF_HAND if bumps_offhand else "")
	if rune_err != "":
		return rune_err
	bank[index] = old
	equipment[slot] = id
	if bumps_offhand:
		var free := bank.find("")
		if free == -1:
			bank[index] = id
			if old == "":
				equipment.erase(slot)
			else:
				equipment[slot] = old
			return "Bank full (need room for your Off Hand item)"
		bank[free] = offhand_item
		equipment.erase(OFF_HAND)
	changed.emit()
	return ""

func unequip_to_bank(slot: String) -> String:
	var id: String = equipment.get(slot, "")
	if id == "":
		return ""
	var free := bank.find("")
	if free == -1:
		return "Bank full"
	bank[free] = id
	equipment.erase(slot)
	changed.emit()
	return ""

# Bank indices holding items that fit `slot`.
func bank_items_for_slot(slot: String) -> Array[int]:
	var out: Array[int] = []
	for i in BANK_SIZE:
		if bank[i] != "" and fits_slot(bank[i], slot):
			out.append(i)
	return out

## Sort the bank (items packed to the front). Modes:
##   "type"    - by gear slot / item type, best first within a type
##   "quality" - by rarity (legendary -> common), then item level
##   "rune"    - runed items first, by rune rarity (legendary, epic, rare, common)
const BANK_SORT_MODES := ["type", "quality", "rune"]
const _SLOT_ORDER := ["Main Hand", "Off Hand", "Head", "Neck", "Shoulder", "Back", "Chest",
	"Gloves", "Legs", "Boots", "Finger 1", "Trinket 1"]

func sort_bank(mode: String) -> void:
	var items: Array = []
	for id in bank:
		if id != "":
			items.append(id)
	var slot_rank := func(id: String) -> int:
		var s: String = Items.get_item(id).get("slot", "")
		var i := _SLOT_ORDER.find(s)
		return i if i != -1 else _SLOT_ORDER.size()
	var rune_rank := func(id: String) -> int:   # 4 = legendary ... 1 = common, 0 = no rune
		var r := Items.rune_of(id)
		return 0 if r == "" else Runes.rarity(r) + 1
	# Each key: [primary, secondary, ...]; compared in order, higher = earlier
	# unless noted. Item name last keeps the order stable.
	var key := func(id: String) -> Array:
		var rarity := Items.rarity_of(id)
		var lvl := Items.required_level(id)
		match mode:
			"quality":
				return [rarity, lvl, -slot_rank.call(id), rune_rank.call(id)]
			"rune":
				return [rune_rank.call(id), rarity, lvl, -slot_rank.call(id)]
		return [-slot_rank.call(id), rarity, lvl, rune_rank.call(id)]
	items.sort_custom(func(a, b):
		var ka: Array = key.call(a)
		var kb: Array = key.call(b)
		for i in ka.size():
			if ka[i] != kb[i]:
				return ka[i] > kb[i]
		return Items.item_name(a) < Items.item_name(b))
	for i in BANK_SIZE:
		bank[i] = items[i] if i < items.size() else ""
	changed.emit()

func delete_bank_items(indices: Array) -> void:
	for i in indices:
		if i >= 0 and i < BANK_SIZE:
			ItemDB.destroy(bank[i])
			bank[i] = ""
	changed.emit()

## Permanently destroy the item in bag slot `index`.
func delete_inventory_item(index: int) -> void:
	if index < 0 or index >= INVENTORY_SIZE or inventory[index] == "":
		return
	ItemDB.destroy(inventory[index])
	inventory[index] = ""
	changed.emit()

## Move bank items (drag & drop). One item swaps with whatever is at `to`.
## Several items land in consecutive slots starting at `to`; anything they
## displace goes into the slots they came from. Returns the new indices.
func move_bank_items(indices: Array, to: int) -> Array[int]:
	var src: Array[int] = []
	for i in indices:
		if int(i) >= 0 and int(i) < BANK_SIZE and bank[int(i)] != "" and not src.has(int(i)):
			src.append(int(i))
	var out: Array[int] = []
	if src.is_empty() or to < 0 or to >= BANK_SIZE:
		return out
	src.sort()
	if src.size() == 1:
		var tmp := bank[to]
		bank[to] = bank[src[0]]
		bank[src[0]] = tmp
		out.append(to)
		changed.emit()
		return out
	var moving: Array[String] = []
	for i in src:
		moving.append(bank[i])
		bank[i] = ""
	var start := mini(to, BANK_SIZE - moving.size())
	var displaced: Array[String] = []
	for k in moving.size():
		var t := start + k
		if bank[t] != "":
			displaced.append(bank[t])
		bank[t] = moving[k]
		out.append(t)
	for item in displaced:
		var free := -1
		for i in src:
			if bank[i] == "":
				free = i
				break
		if free == -1:
			free = bank.find("")
		bank[free] = item
	changed.emit()
	return out

func swap_inventory(a: int, b: int) -> void:
	if a == b:
		return
	var tmp := inventory[a]
	inventory[a] = inventory[b]
	inventory[b] = tmp
	changed.emit()

# Remove and return the item in an inventory slot (e.g. dropped on the floor).
func take_inventory_item(index: int) -> String:
	var id := inventory[index]
	inventory[index] = ""
	if id != "":
		changed.emit()
	return id

func first_free_slot() -> int:
	return inventory.find("")

## Put an item in the bag. `id` is an item instance id; a plain base id or old
## "base|rune" string is turned into a new instance first.
func add_item(id: String) -> bool:
	var i := first_free_slot()
	if i == -1:
		return false
	if not ItemDB.is_instance_id(id):
		id = ItemDB.from_legacy(id)
	inventory[i] = id
	item_looted.emit(id)
	var bus := _bus() if is_inside_tree() else null
	if bus:
		bus.item_looted.emit(id)
	changed.emit()
	return true

# --- Paired slots: a ring fits Finger 1 or 2, a trinket Trinket 1 or 2 -----------

const SLOT_PAIRS := {"Finger 1": "Finger 2", "Finger 2": "Finger 1",
	"Trinket 1": "Trinket 2", "Trinket 2": "Trinket 1"}

## Can `item` go into equipment slot `slot`?
static func fits_slot(item: String, slot: String) -> bool:
	var s: String = Items.get_item(item).get("slot", "")
	return s != "" and (s == slot or SLOT_PAIRS.get(s, "") == slot)

## The slot `item` goes into when equipped without choosing one: its own slot,
## or the paired slot when its own is taken and the other one is free.
func target_slot_for(item: String) -> String:
	var s: String = Items.get_item(item).get("slot", "")
	if SLOT_PAIRS.has(s) and equipment.get(s, "") != "" and equipment.get(SLOT_PAIRS[s], "") == "":
		return SLOT_PAIRS[s]
	return s

func _pick_slot(item: String, to_slot: String) -> String:
	if to_slot == "":
		return target_slot_for(item)
	return to_slot if fits_slot(item, to_slot) else ""

# True if a two-handed weapon in Main Hand is blocking the Off Hand.
func is_slot_locked(slot: String) -> bool:
	if slot != OFF_HAND:
		return false
	var main: String = equipment.get(MAIN_HAND, "")
	return main != "" and Items.get_item(main).get("locks_offhand", false)

# Equip the item in inventory slot `index` (into `to_slot` if given, e.g. the
# ring slot it was dropped on). Returns an error message, or "" on success.
func equip_from_inventory(index: int, to_slot: String = "") -> String:
	if index < 0 or index >= INVENTORY_SIZE or inventory[index] == "":
		return "Nothing to equip"
	var id := inventory[index]
	var item := Items.get_item(id)
	if item.get("slot", "") == "":
		return "Can't equip that"
	var slot := _pick_slot(id, to_slot)
	if slot == "":
		return "That doesn't go in %s" % to_slot
	if not level_ok(id):
		return "Requires level %d" % Items.required_level(id)
	if is_slot_locked(slot):
		return "Off Hand is locked by a two-handed weapon"

	# Two-handers need the Off Hand emptied into the bag first.
	var offhand_item: String = equipment.get(OFF_HAND, "")
	var bumps_offhand: bool = item.get("locks_offhand", false) and offhand_item != ""

	var old: String = equipment.get(slot, "")
	var rune_err := _equip_rune_error(slot, id, OFF_HAND if bumps_offhand else "")
	if rune_err != "":
		return rune_err
	inventory[index] = old            # swap the previously equipped item into this bag slot
	equipment[slot] = id
	if bumps_offhand:
		var free := first_free_slot()
		if free == -1:
			# Revert: no room for the off-hand item.
			equipment[slot] = old
			inventory[index] = id
			if old == "":
				equipment.erase(slot)
			return "Inventory full (need room for your Off Hand item)"
		inventory[free] = offhand_item
		equipment.erase(OFF_HAND)
	if old == "":
		pass
	changed.emit()
	return ""

# Move an equipped item back into the inventory.
func unequip(slot: String) -> String:
	var id: String = equipment.get(slot, "")
	if id == "":
		return ""
	var free := first_free_slot()
	if free == -1:
		return "Inventory full"
	inventory[free] = id
	equipment.erase(slot)
	changed.emit()
	return ""
