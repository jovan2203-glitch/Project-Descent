@tool
extends McpTestSuite

# Phase 4 rules: level-up draft choices, Skill Card guarantees, learned
# abilities, the rune "unlocked pool" and elite/boss loot tables.

const DraftRules = preload("res://scripts/core/draft_rules.gd")
const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Runes = preload("res://scripts/runes.gd")
const Items = preload("res://scripts/items.gd")
const ItemDB = preload("res://scripts/core/item_db.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")
const LootTable = preload("res://scripts/data/loot_table_data.gd")
const LootEntry = preload("res://scripts/data/loot_entry_data.gd")

var _saved_records := {}

func suite_name() -> String:
	return "draft_and_loot"

func setup() -> void:
	_saved_records = ItemDB.records.duplicate(true)

func teardown() -> void:
	ItemDB.records = _saved_records

func _rng(s: int = 1) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func _pd() -> Node:
	var pd: Node = track(PlayerDataScript.new())
	pd._ready()
	return pd

# --- Draft choices ------------------------------------------------------------------

func test_draft_offers_three_unlearned_abilities() -> void:
	var c := DraftRules.make_choices(2, [], [], _rng())
	assert_eq(c.size(), 3)
	var ids := {}
	for x in c:
		assert_eq(x["type"], "ability")
		assert_true(Abilities.DRAFT_POOL.has(x["id"]), "only draft-pool abilities")
		ids[x["id"]] = true
	assert_eq(ids.size(), 3, "no duplicates")

func test_draft_skips_learned() -> void:
	var learned := Abilities.DRAFT_POOL.slice(0, Abilities.DRAFT_POOL.size() - 2)   # 2 left
	var c := DraftRules.make_choices(3, learned, [], _rng(5))
	assert_eq(c.size(), 3)
	var abilities := c.filter(func(x): return x["type"] == "ability")
	assert_eq(abilities.size(), 2, "only the 2 unlearned abilities")
	for x in abilities:
		assert_false(learned.has(x["id"]))
	assert_eq(c[2]["type"], "boon", "boon fills the last slot")

func test_draft_all_learned_gives_boons() -> void:
	var c := DraftRules.make_choices(9, Abilities.DRAFT_POOL.duplicate(), [], _rng(3))
	assert_eq(c.size(), 3)
	for x in c:
		assert_eq(x["type"], "boon")

func test_skill_card_guarantees_at_its_level() -> void:
	var levels := {"blink": 4}
	for s in 20:
		var c := DraftRules.make_choices(4, [], ["blink"], _rng(s), levels)
		assert_eq(c[0]["id"], "blink")
		assert_true(c[0]["guaranteed"])
	var other := DraftRules.make_choices(3, [], ["blink"], _rng(1), levels)
	for x in other:
		assert_false(x.get("guaranteed", false), "no guarantee at a different level")

func test_skill_card_ignored_when_already_learned() -> void:
	var c := DraftRules.make_choices(4, ["blink"], ["blink"], _rng(2), {"blink": 4})
	for x in c:
		assert_ne(x["id"], "blink")

func test_skill_card_files_match_registry() -> void:
	for cid in SkillCards.ALL:
		assert_eq(SkillCards.ability_of(cid), cid, "card %s grants its own ability" % cid)
		assert_gt(SkillCards.level_of(cid), 1)
		assert_true(Abilities.DRAFT_POOL.has(cid))

# --- Learning / boons ----------------------------------------------------------------

func test_learn_ability_goes_on_bar_and_is_available() -> void:
	var pd := _pd()
	assert_false(pd.has_ability("icelance"))
	pd.learn_ability("icelance")
	assert_true(pd.has_ability("icelance"))
	assert_true(pd.action_bar.has("icelance"), "placed in the first empty bar slot")
	assert_true(pd.available_abilities().has("icelance"))
	assert_true(pd.available_abilities().has("frostbolt"), "base kit still available")

func test_boon_adds_permanent_stat() -> void:
	var pd := _pd()
	DraftRules.apply_choice(pd, {"type": "boon", "stat": "strength", "amount": 1.0})
	assert_eq(float(pd.total_stats().get("strength", 0.0)), 1.0)

func test_boons_use_real_stats() -> void:
	const Stats = preload("res://scripts/core/stats.gd")
	for b in DraftRules.BOONS:
		assert_true(Stats.LABELS.has(str(b["stat"])), "%s boosts a known stat" % b["id"])

func test_card_loadout_limit() -> void:
	var pd := _pd()
	for c in SkillCards.ALL:
		pd.grant_card(c)
	for i in SkillCards.MAX_EQUIPPED:
		assert_eq(pd.toggle_card(SkillCards.ALL[i]), "")
	assert_ne(pd.toggle_card(SkillCards.ALL[SkillCards.MAX_EQUIPPED]), "", "loadout is full")
	assert_eq(pd.toggle_card(SkillCards.ALL[0]), "", "clicking again unequips")
	assert_eq(pd.equipped_cards.size(), SkillCards.MAX_EQUIPPED - 1)

func test_level_up_queues_draft_every_two_levels() -> void:
	var pd := _pd()
	var total := 0
	for lv in range(1, 5):
		total += PlayerDataScript.xp_to_next(lv)
	pd.add_xp(total)
	assert_eq(pd.level, 5)
	assert_eq(Array(pd.pending_drafts), [2, 4], "drafts only on even levels")

func test_level_cap_is_50() -> void:
	var pd := _pd()
	pd.set_level(99)
	assert_eq(pd.level, 50)
	assert_eq(PlayerDataScript.xp_to_next(50), 0)

func test_skill_card_between_drafts_guarantees_next_draft() -> void:
	var c := DraftRules.make_choices(6, [], ["blink"], _rng(1), {"blink": 5})
	assert_eq(c[0]["id"], "blink", "level-5 card is guaranteed at the level-6 draft")
	assert_true(c[0]["guaranteed"])

func test_every_ability_has_a_category() -> void:
	for id in Abilities.ALL:
		if Abilities.is_trinket_slot(id):
			continue   # item buttons (Use Trinket 1/2), not abilities in a book
		assert_ne(Abilities.category_of(id), "", "%s has a category" % id)

func test_all_abilities_load_with_matching_ids() -> void:
	for id in Abilities.ALL:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s loads" % id)
		if r:
			assert_eq(str(r.id), id)
	for id in Abilities.DRAFT_POOL:
		assert_true(Abilities.ALL.has(id), "%s is in ALL" % id)

func test_requested_books_have_abilities() -> void:
	const Categories = preload("res://scripts/categories.gd")
	for cat in Categories.ORDER:   # every book has abilities
		assert_gt(Abilities.in_category(cat).size(), 0, "%s has abilities" % cat)
	for cat in ["fire", "lightning", "arcane", "shadow", "holy", "nature", "rogue"]:
		assert_gt(Abilities.in_category(cat).size(), 2, "%s has abilities" % cat)
	var frost_weapon := Abilities.in_category("frost").filter(func(id):
		return int(Abilities.get_resource(id).weapon_requirement) != 0)
	assert_eq(frost_weapon.size(), 2, "frost has a melee and a bow ability")

# --- New gear: paired slots, item effects, shield abilities ------------------------


func test_every_item_loads_with_matching_id() -> void:
	for id in Items.ALL:
		var r := Items.get_resource(id)
		assert_true(r != null, "%s loads" % id)
		if r:
			assert_eq(str(r.id), id)

func test_rings_and_trinkets_fill_either_slot() -> void:
	var pd := _pd()
	pd.inventory[0] = ItemDB.create("ring_focus")
	pd.inventory[1] = ItemDB.create("ring_might")
	assert_eq(pd.equip_from_inventory(0), "")
	assert_eq(pd.equip_from_inventory(1), "", "second ring goes to the free finger")
	assert_eq(Items.base_id(pd.equipment.get("Finger 1", "")), "ring_focus")
	assert_eq(Items.base_id(pd.equipment.get("Finger 2", "")), "ring_might")
	pd.inventory[2] = ItemDB.create("storm_idol")
	assert_eq(pd.equip_from_inventory(2, "Trinket 2"), "", "dropped on Trinket 2")
	assert_eq(Items.base_id(pd.equipment.get("Trinket 2", "")), "storm_idol")
	pd.inventory[3] = ItemDB.create("shield")
	assert_ne(pd.equip_from_inventory(3, "Trinket 1"), "", "a shield isn't a trinket")

func test_trinkets_have_effects() -> void:
	for id in ["storm_idol", "phoenix_ember", "berserker_tooth", "arcane_clockwork",
			"frost_shard", "sand_hourglass", "sacred_reliquary"]:
		var has_one: bool = Items.equip_effect_of(id) != null or Items.use_effect_of(id) != null
		assert_true(has_one, "%s has an Equip: or Use: effect" % id)
	assert_true(Items.use_effect_of("sacred_reliquary") != null and Items.equip_effect_of("sacred_reliquary") != null)

func test_item_effect_scaling() -> void:
	var low := ItemDB.create("sand_hourglass", "", 1)
	var high := ItemDB.create("sand_hourglass", "", 21)
	assert_eq(Items.effect_scale(low), 1.0)
	assert_eq(Items.effect_scale(high), 3.0, "+10% per item level")
	var use := Items.use_effect_of(high)
	assert_eq(Items.scaled_buff(use, 3.0), 20.0, "percent buffs (haste) never scale")

func test_shield_abilities_need_a_shield() -> void:
	for id in ["shieldofdawn", "sacredbulwark", "stormshield", "thunderaegis"]:
		var r := Abilities.get_resource(id)
		assert_true(bool(r.requires_shield), "%s needs a shield" % id)
		assert_true(Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id))
	assert_eq(Abilities.category_of("shieldofdawn"), "holy")
	assert_eq(Abilities.category_of("stormshield"), "lightning")
	assert_eq(Items.item_type(ItemDB.create("shield")), "shield")

# --- Rune pool & loot ---------------------------------------------------------------

func test_unlocked_pool_grows_with_level() -> void:
	var lv1 := Runes.unlocked_pool(1)
	assert_true(lv1.has("frost"))
	assert_false(lv1.has("warding"), "warding unlocks at level 5")
	assert_true(Runes.unlocked_pool(5).has("warding"))
	assert_true(Runes.unlocked_pool(1, ["warding"]).has("warding"), "known runes always count")

func test_loot_runes_only_from_given_pool() -> void:
	var t: Resource = LootTable.new()
	var e: Resource = LootEntry.new()
	e.item_id = &"sword"
	var g: Array[Resource] = [e]
	t.guaranteed = g
	t.rune_chance = 1.0
	for s in 30:
		var drops: Array = t.roll(1, _rng(s), ["fury"])
		assert_eq(Items.rune_of(drops[0]), "fury")

func test_elite_and_boss_tables_load() -> void:
	var elite: Resource = load("res://data/loot/elite.tres")
	var boss: Resource = load("res://data/loot/boss.tres")
	assert_eq(elite.pool_rolls, 1)
	assert_eq(boss.pool_rolls, 2)
	assert_true(elite.use_unlocked_pool and boss.use_unlocked_pool)
	assert_eq(boss.rarity_weights[0], 0.0, "boss never drops Common")
