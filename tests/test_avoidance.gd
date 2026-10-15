@tool
extends McpTestSuite

# Dodge, Parry and Block: three percent stats that drop on gear. A hit that is
# dodged, parried or blocked deals no damage and applies none of its effects.
# Agility adds a little Dodge; Strength a little Parry and a little Block. Each
# has a cap (balance.gd).

const CombatSystem = preload("res://scripts/core/combat_system.gd")
const DamageInfo = preload("res://scripts/core/damage_info.gd")
const Stats = preload("res://scripts/core/stats.gd")
const Balance = preload("res://scripts/balance.gd")
const ItemDB = preload("res://scripts/core/item_db.gd")
const Items = preload("res://scripts/items.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")

var _saved_records := {}

func suite_name() -> String:
	return "avoidance"

func setup() -> void:
	_saved_records = ItemDB.records.duplicate(true)

func teardown() -> void:
	ItemDB.records = _saved_records

## A hit of 10 against these chances (%) and rolls (0..100).
func _hit(dodge: float, parry: float, block: float, roll_dodge: float, roll_parry: float, roll_block: float,
		can_block: bool = true) -> Dictionary:
	return CombatSystem.compute_damage(10.0, 0.0, 0.0, block, 0.0, 99.0, roll_block, true, can_block, 1.0, 0.5,
		dodge, parry, roll_dodge, roll_parry)

func test_the_three_stats() -> void:
	assert_eq(Stats.DODGE, "dodge")
	assert_eq(Stats.PARRY, "parry")
	assert_eq(Stats.BLOCK, "block_chance", "the block chance that was already in the game")
	for s in [Stats.DODGE, Stats.PARRY, Stats.BLOCK]:
		assert_true(Stats.is_percent(s), "%s is a percent stat" % s)
		assert_true(Stats.ORDER.has(s), "%s has a row in the stat panels" % s)
		assert_true(Stats.ORDER.find(s) > Stats.ORDER.find(Stats.ARMOR), "%s comes after Armor" % s)
		assert_true(Stats.DESCRIPTIONS.has(s), "%s has a description" % s)
		assert_false(Stats.describe(s).contains("{"), "%s: its cap is filled in" % s)
	assert_eq(Stats.label(Stats.DODGE), "Dodge")
	assert_eq(Stats.label(Stats.PARRY), "Parry")
	assert_eq(Stats.label(Stats.BLOCK), "Block")
	assert_eq(Stats.bonus_line(Stats.DODGE, 2.4), "+2.4% Dodge")
	assert_eq(Stats.bonus_line(Stats.PARRY, 1.0), "+1% Parry")
	assert_eq(Stats.bonus_line(Stats.BLOCK, 0.8), "+0.8% Block")
	assert_contains(Stats.describe(Stats.DODGE), "Capped at %s%%" % Stats.num(Balance.DODGE_CAP))
	assert_contains(Stats.describe(Stats.PARRY), "Capped at %s%%" % Stats.num(Balance.PARRY_CAP))
	assert_contains(Stats.describe(Stats.BLOCK), "Capped at %s%%" % Stats.num(Balance.BLOCK_CAP))

func test_numbers() -> void:
	assert_eq(Balance.DODGE_CAP, 30.0)
	assert_eq(Balance.PARRY_CAP, 30.0)
	assert_eq(Balance.BLOCK_CAP, 60.0)
	assert_eq(Stats.MAX_DODGE, Balance.DODGE_CAP)
	assert_eq(Stats.MAX_PARRY, Balance.PARRY_CAP)
	assert_eq(Stats.MAX_BLOCK, Balance.BLOCK_CAP)
	assert_eq(Balance.DODGE_PER_AGILITY, 0.006)
	assert_eq(Balance.PARRY_PER_STRENGTH, 0.006)
	assert_eq(Balance.BLOCK_PER_STRENGTH, 0.006)
	assert_eq(Balance.AVOIDANCE_ROLL, 0.8)
	assert_eq(Balance.AVOIDANCE_ROLL_WEIGHT, 0.5)

func test_a_dodged_hit_deals_nothing() -> void:
	var r := _hit(20.0, 0.0, 0.0, 19.0, 99.0, 99.0)
	assert_true(r["dodged"], "a roll under the chance is a dodge")
	assert_eq(r["amount"], 0)
	assert_false(r["parried"] or r["blocked"])
	r = _hit(20.0, 0.0, 0.0, 21.0, 99.0, 99.0)
	assert_false(r["dodged"], "a roll over it lands")
	assert_eq(r["amount"], 10)

func test_a_parried_hit_deals_nothing() -> void:
	var r := _hit(0.0, 20.0, 0.0, 99.0, 19.0, 99.0)
	assert_true(r["parried"])
	assert_eq(r["amount"], 0)
	assert_false(r["dodged"] or r["blocked"])
	assert_eq(_hit(0.0, 20.0, 0.0, 99.0, 21.0, 99.0)["amount"], 10)

func test_caps() -> void:
	assert_true(_hit(100.0, 0.0, 0.0, Balance.DODGE_CAP - 1.0, 99.0, 99.0)["dodged"])
	assert_false(_hit(100.0, 0.0, 0.0, Balance.DODGE_CAP + 1.0, 99.0, 99.0)["dodged"], "Dodge is capped")
	assert_true(_hit(0.0, 100.0, 0.0, 99.0, Balance.PARRY_CAP - 1.0, 99.0)["parried"])
	assert_false(_hit(0.0, 100.0, 0.0, 99.0, Balance.PARRY_CAP + 1.0, 99.0)["parried"], "Parry is capped")
	assert_true(_hit(0.0, 0.0, 100.0, 99.0, 99.0, Balance.BLOCK_CAP - 1.0)["blocked"])
	assert_false(_hit(0.0, 0.0, 100.0, 99.0, 99.0, Balance.BLOCK_CAP + 1.0)["blocked"], "Block is still capped")
	assert_eq(Stats.capped_avoid(Stats.DODGE, 45.0), Balance.DODGE_CAP)
	assert_eq(Stats.capped_avoid(Stats.PARRY, 45.0), Balance.PARRY_CAP)
	assert_eq(Stats.capped_avoid(Stats.DODGE, 12.5), 12.5)
	assert_eq(Stats.capped_avoid(Stats.DODGE, -5.0), 0.0)

## Each has its own roll; the first that succeeds (dodge, parry, block) is the one that counts.
func test_one_at_a_time_in_order() -> void:
	var all := _hit(20.0, 20.0, 20.0, 1.0, 1.0, 1.0)
	assert_true(all["dodged"])
	assert_false(all["parried"] or all["blocked"], "a dodged hit is not also parried or blocked")
	var two := _hit(20.0, 20.0, 20.0, 99.0, 1.0, 1.0)
	assert_true(two["parried"])
	assert_false(two["dodged"] or two["blocked"])
	var one := _hit(20.0, 20.0, 20.0, 99.0, 99.0, 1.0)
	assert_true(one["blocked"])
	assert_false(one["dodged"] or one["parried"])
	assert_eq(one["amount"], 0)

func test_what_cannot_be_blocked_cannot_be_dodged_or_parried() -> void:
	var r := _hit(100.0, 100.0, 100.0, 1.0, 1.0, 1.0, false)
	assert_false(r["dodged"] or r["parried"] or r["blocked"], "damage over time, exact hits")
	assert_eq(r["amount"], 10)

## Callers that pass no dodge / parry (the older tests) get neither.
func test_without_the_new_chances() -> void:
	var r := CombatSystem.compute_damage(5, 0, 0.0, 0.0, 0.0, 99.0, 1.0)
	assert_false(r["dodged"] or r["parried"] or r["blocked"])
	assert_eq(r["amount"], 5)

func test_total_avoidance() -> void:
	assert_eq(CombatSystem.avoid_chance(0.0, 0.0, 0.0), 0.0)
	assert_true(is_equal_approx(CombatSystem.avoid_chance(10.0, 0.0, 0.0), 10.0))
	assert_true(is_equal_approx(CombatSystem.avoid_chance(10.0, 10.0, 0.0), 19.0), "rolled one after the other")
	assert_true(is_equal_approx(CombatSystem.avoid_chance(100.0, 100.0, 100.0), 80.4), "everything at its cap")

func test_damage_info() -> void:
	var info := DamageInfo.make(null, null, 1.0, "enemy_melee")
	assert_false(info.avoided())
	assert_eq(info.avoid_kind(), "")
	info.dodged = true
	assert_true(info.avoided())
	assert_eq(info.avoid_kind(), "dodge")
	info.dodged = false
	info.parried = true
	assert_true(info.avoided())
	assert_eq(info.avoid_kind(), "parry")
	info.parried = false
	info.blocked = true
	assert_true(info.avoided())
	assert_eq(info.avoid_kind(), "block")
	assert_eq(CombatSystem.avoid_text("dodge"), "Dodge")
	assert_eq(CombatSystem.avoid_text("parry"), "Parry")
	assert_eq(CombatSystem.avoid_text("block"), "Block")

func test_the_player_is_told() -> void:
	var names := []
	for s in (load("res://scripts/signal_bus.gd") as Script).get_script_signal_list():
		names.append(str(s["name"]))
	assert_true(names.has("player_avoided"), "dodge / parry / block")
	assert_true(names.has("player_blocked"), "blocks keep their own signal")

# --- Agility and Strength ----------------------------------------------------------------

func test_agility_adds_a_little_dodge() -> void:
	var raw := func(k): return 1000.0 if k == Stats.AGILITY else 0.0
	assert_true(absf(Stats.resolve(Stats.DODGE, raw) - 1000.0 * Balance.DODGE_PER_AGILITY) < 0.001, "6% from 1,000 Agility")
	assert_eq(Stats.resolve(Stats.PARRY, raw), 0.0, "Agility gives no Parry")
	assert_eq(Stats.resolve(Stats.BLOCK, raw), 0.0, "or Block")

func test_strength_adds_a_little_parry_and_block() -> void:
	var raw := func(k): return 1000.0 if k == Stats.STRENGTH else 0.0
	assert_true(absf(Stats.resolve(Stats.PARRY, raw) - 1000.0 * Balance.PARRY_PER_STRENGTH) < 0.001)
	assert_true(absf(Stats.resolve(Stats.BLOCK, raw) - 1000.0 * Balance.BLOCK_PER_STRENGTH) < 0.001)
	assert_eq(Stats.resolve(Stats.DODGE, raw), 0.0, "Strength gives no Dodge")
	# It is slight: far less than the Critical Strike a point of Agility gives.
	assert_true(Balance.DODGE_PER_AGILITY < float(Stats.DERIVED[Stats.AGILITY][Stats.CRIT]) * 0.5)
	var mind := func(k): return 1000.0 if k == Stats.INTELLECT else 0.0
	for s in [Stats.DODGE, Stats.PARRY, Stats.BLOCK]:
		assert_eq(Stats.resolve(s, mind), 0.0, "Intellect gives no %s" % s)

func test_gear_adds_to_what_the_stats_give() -> void:
	var raw := func(k): return {Stats.AGILITY: 500.0, Stats.DODGE: 4.0}.get(k, 0.0)
	assert_true(absf(Stats.resolve(Stats.DODGE, raw) - (4.0 + 500.0 * Balance.DODGE_PER_AGILITY)) < 0.001)

# --- Block: the Block stat alone (Armor does not block) -----------------------------------

func test_block_is_the_block_stat_alone() -> void:
	assert_eq(Stats.total_block(5.0), 5.0)
	assert_eq(Stats.total_block(500.0), Balance.BLOCK_CAP, "capped")
	assert_eq(Stats.total_block(-5.0), 0.0)
	# Armor gives none: only gear's Block, Strength and buffs do.
	var armored := func(k): return 1.0e6 if k == Stats.ARMOR else 0.0
	assert_eq(Stats.resolve(Stats.BLOCK, armored), 0.0, "Armor gives no Block")
	var strong := func(k): return 1000.0 if k == Stats.STRENGTH else 0.0
	assert_true(absf(Stats.resolve(Stats.BLOCK, strong) - 6.0) < 0.001, "1,000 Strength: 6% Block")

func test_stat_panel_rows() -> void:
	assert_eq(Stats.panel_line(Stats.DODGE, 12.5), "Dodge  12.5%")
	assert_eq(Stats.panel_line(Stats.PARRY, 3.0), "Parry  3%")
	assert_eq(Stats.panel_line(Stats.DODGE, 80.0), "Dodge  %s%%" % Stats.num(Balance.DODGE_CAP), "the row shows what counts")
	assert_eq(Stats.panel_line(Stats.BLOCK, 5.0, {}), "Block  5%")
	assert_eq(Stats.panel_line(Stats.BLOCK, 5.0, {Stats.ARMOR: 1.0e9}), "Block  5%", "Armor does not count in the Block row")
	assert_eq(Stats.panel_line(Stats.BLOCK, 500.0, {}), "Block  %s%%" % Stats.num(Balance.BLOCK_CAP))
	assert_contains(Stats.describe(Stats.AGILITY), "Dodge")
	assert_contains(Stats.describe(Stats.STRENGTH), "Parry")
	assert_contains(Stats.describe(Stats.STRENGTH), "Block")

# --- Gear -------------------------------------------------------------------------------

func test_they_are_in_the_roll_pool() -> void:
	for s in [Stats.DODGE, Stats.PARRY, Stats.BLOCK]:
		assert_eq(float(ItemDB.ROLL_POOL.get(s, 0.0)), Balance.AVOIDANCE_ROLL, "%s rolls on gear" % s)
		assert_eq(float(ItemDB.ROLL_WEIGHTS.get(s, 1.0)), Balance.AVOIDANCE_ROLL_WEIGHT)
		assert_true(Stats.scales_like_percent(s), "%s grows on the gentle percent curve" % s)

func test_rolls_grow_with_item_level() -> void:
	var low := Balance.AVOIDANCE_ROLL * Stats.pct_scale(1)
	var high := Balance.AVOIDANCE_ROLL * Stats.pct_scale(50)
	assert_eq(low, 0.8)
	assert_true(high > 2.3 and high < 2.5, "about 2.4%% at item level 50 (%s)" % high)

func test_gear_really_rolls_them() -> void:
	var seen := {}
	for i in 600:
		var rolled := ItemDB.roll_stats(3, 50)
		for s in rolled:
			seen[s] = true
			if s == Stats.DODGE or s == Stats.PARRY or s == Stats.BLOCK:
				var v := float(rolled[s])
				assert_true(v > 2.0 and v < 7.5, "%s roll at item level 50: %s" % [s, v])
	for s in [Stats.DODGE, Stats.PARRY, Stats.BLOCK]:
		assert_true(seen.has(s), "%s shows up on dropped gear" % s)

func test_an_item_with_dodge() -> void:
	var item := ItemDB.create("helmet", "", 10, 1, {Stats.DODGE: 2.0})
	var d := Items.get_item(item)
	assert_eq(float(d["stats"].get(Stats.DODGE, 0.0)), 2.0)
	assert_contains(Items.tooltip(item), "+2% Dodge")
	var plain := ItemDB.create("helmet", "", 10, 0)
	assert_eq(float(Items.stat_changes(item, [plain]).get(Stats.DODGE, 0.0)), 2.0, "the comparison shows it")

## A character's Dodge / Parry / Block = what their gear rolled + what their stats give.
func test_a_character_gets_it_from_gear() -> void:
	var with: Node = track(PlayerDataScript.new())
	with._ready()
	# (Both helmets are Heavy: a piece's armor type decides which stat it carries.)
	with.equipment["Head"] = ItemDB.create("helmet", "", 10, 1, {Stats.DODGE: 2.0, Stats.PARRY: 1.5, Stats.BLOCK: 1.0}, 3)
	with._invalidate_stats()
	var without: Node = track(PlayerDataScript.new())
	without._ready()
	without.equipment["Head"] = ItemDB.create("helmet", "", 10, 0, {}, 3)
	without._invalidate_stats()
	var a: Dictionary = with.total_stats()
	var b: Dictionary = without.total_stats()
	assert_true(absf(Stats.from_totals(Stats.DODGE, a) - Stats.from_totals(Stats.DODGE, b) - 2.0) < 0.001)
	assert_true(absf(Stats.from_totals(Stats.PARRY, a) - Stats.from_totals(Stats.PARRY, b) - 1.5) < 0.001)
	assert_true(absf(Stats.from_totals(Stats.BLOCK, a) - Stats.from_totals(Stats.BLOCK, b) - 1.0) < 0.001)
