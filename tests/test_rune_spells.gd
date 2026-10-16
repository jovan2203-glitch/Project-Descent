@tool
extends McpTestSuite

# Spells taught by runes (the "Rune Spells" book) and Frostfire Bolt: a Frost
# Bolt's damage split half Frost / half Fire that counts as both a Frost Bolt
# and a Firebolt. Also the read-only talent view of the in-game Spellbook.

const Abilities = preload("res://scripts/abilities.gd")
const Categories = preload("res://scripts/categories.gd")
const Runes = preload("res://scripts/runes.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const DamageInfo = preload("res://scripts/core/damage_info.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")
const RuneDataScript = preload("res://scripts/data/rune_data.gd")
const TalentView = preload("res://scripts/ui/talent_tree_view.gd")

const SPELL := "frostfirebolt"
const RUNE := "frostfire_bolt"

func suite_name() -> String:
	return "rune_spells"

func test_frostfire_bolt_is_a_rune_spell() -> void:
	assert_true(Abilities.ALL.has(SPELL), "can go on the action bar")
	assert_false(Abilities.DRAFT_POOL.has(SPELL), "never offered by a draft")
	assert_false(Abilities.BASE.has(SPELL), "not known without the rune")
	assert_false(SkillCards.ALL.has(SPELL), "no Skill Card")
	assert_eq(Abilities.category_of(SPELL), Categories.RUNE)
	assert_eq(Array(Abilities.in_category(Categories.RUNE)), [SPELL, "polarstrike"])
	assert_false(Categories.ORDER.has(Categories.RUNE), "Rune Spells is a tab of its own: no talent tree")
	assert_eq(Categories.cat_name(Categories.RUNE), "Rune Spells")
	assert_eq(Categories.kind_name(Categories.RUNE), "Rune", "tooltips say 'Rune Spell'")
	assert_eq(Categories.kind_name("fire"), "Fire")

func test_frostfire_bolt_uses_frost_bolts_numbers() -> void:
	var ff: Resource = Abilities.get_resource(SPELL)
	var fb: Resource = Abilities.get_resource("frostbolt")
	assert_true(ff != null, "loads")
	assert_eq(str(ff.id), SPELL)
	assert_eq(float(ff.damage), float(fb.damage), "a Frost Bolt's damage")
	assert_eq(float(ff.cast_time), float(fb.cast_time))
	assert_eq(int(ff.resource_cost), int(fb.resource_cost))
	assert_eq(float(ff.cast_range), float(fb.cast_range))
	assert_true(ff.on_hit_effect == null, "damage only: no Chilled, no Burning of its own")
	assert_true(ff.tags.has("Frost") and ff.tags.has("Fire") and ff.tags.has("Spell"))
	assert_false(Abilities.tooltip(SPELL).contains("{"), "the description's numbers are filled in")

func test_frostfire_bolt_is_half_frost_half_fire() -> void:
	var player_script: GDScript = load("res://scripts/player.gd")
	var halves: Array = FrostfireKit.frostfire_halves(1.0)
	assert_eq(halves.size(), 2)
	assert_eq(float(halves[0][0]), 0.5)
	assert_eq(float(halves[1][0]), 0.5)
	assert_eq(str(halves[0][1]), "frost")
	assert_eq(str(halves[1][1]), "fire")
	assert_true((halves[0][2] as PackedStringArray).has("Frost") and not (halves[0][2] as PackedStringArray).has("Fire"),
		"the Frost half is only a Frost hit")
	assert_true((halves[1][2] as PackedStringArray).has("Fire") and not (halves[1][2] as PackedStringArray).has("Frost"),
		"the Fire half is only a Fire hit")
	var odd: Array = FrostfireKit.frostfire_halves(1.3)
	assert_true(absf(float(odd[0][0]) + float(odd[1][0]) - 1.3) < 0.0001, "nothing is lost in the split")
	assert_eq(DamageInfo.make(null, null, 1.0, SPELL).part, 0, "ordinary hits are whole")

func test_frostfire_bolt_counts_as_both_spells() -> void:
	assert_true(Abilities.is_a(SPELL, "frostbolt"))
	assert_true(Abilities.is_a(SPELL, "fireball"))
	assert_true(Abilities.is_a(SPELL, SPELL))
	assert_true(Abilities.is_a("frostbolt", "frostbolt"))
	assert_false(Abilities.is_a("frostbolt", "fireball"), "a Frost Bolt is still not a Firebolt")
	assert_false(Abilities.is_a(SPELL, "kilnblast"))
	# Tempered Flame names Firebolt: it changes Frostfire Bolt the same way.
	var player_script: GDScript = load("res://scripts/player.gd")
	assert_eq(player_script.fire_crit_rules(SPELL, 40.0, 60.0, 20.0), player_script.fire_crit_rules("fireball", 40.0, 60.0, 20.0))
	assert_eq(player_script.fire_crit_rules("frostbolt", 40.0, 60.0, 20.0), [40.0, 0.0], "a plain Frost Bolt is untouched")
	# Rune of Frostbound Insight names Frost Bolt.
	# (A fresh copy: the editor only makes placeholders of loaded data resources.)
	var insight: Resource = RuneDataScript.new()
	insight.required_abilities = load("res://data/runes/frostbound_insight.tres").get("required_abilities")
	assert_eq(insight.required_abilities, PackedStringArray(["frostbolt"]), "Frostbound Insight names Frost Bolt")
	assert_true(insight.applies_to_ability("frostbolt"))
	assert_true(insight.applies_to_ability(SPELL), "runes that name Frost Bolt count Frostfire Bolt")
	assert_false(insight.applies_to_ability("fireball"))

func test_second_half_only_feeds_runes_of_its_school() -> void:
	var any_hit: Resource = RuneDataScript.new()
	assert_false(any_hit.is_school_specific(), "counts hits: sees a Frostfire Bolt once")
	var spells: Resource = RuneDataScript.new()
	spells.required_tags = PackedStringArray(["Spell"])
	assert_false(spells.is_school_specific())
	var fire_tag: Resource = RuneDataScript.new()
	fire_tag.required_tags = PackedStringArray(["Fire", "Spell"])
	assert_true(fire_tag.is_school_specific(), "a Fire rune sees the Fire half")
	var frost_type: Resource = RuneDataScript.new()
	frost_type.required_damage_types = PackedStringArray(["frost"])
	assert_true(frost_type.is_school_specific())

func test_the_rune_teaches_the_spell_while_worn() -> void:
	assert_true(Runes.PATHS.has(RUNE) and Runes.ALL.has(RUNE), "registered")
	assert_eq(Runes.rarity(RUNE), Runes.RARE)
	assert_eq(Runes.max_copies(RUNE), 1, "one is enough")
	assert_eq(Runes.spell_of(RUNE), SPELL)
	assert_eq(Runes.rune_for_spell(SPELL), RUNE)
	assert_eq(Runes.spell_of("frost"), "")
	assert_eq(Runes.rune_for_spell("frostbolt"), "")
	var pd: Node = track(PlayerDataScript.new())
	pd._ready()
	assert_false(pd.has_ability(SPELL), "unknown without the rune")
	pd.equipment["Main Hand"] = "sword|" + RUNE
	assert_true(pd.has_ability(SPELL), "known while the rune is on your gear")
	assert_true(pd.available_abilities().has(SPELL))
	assert_eq(Array(pd.rune_spells()), [SPELL])
	assert_false(pd.learned_abilities.has(SPELL), "not learned for good: it comes from the rune")
	pd.equipment["Main Hand"] = "sword"
	assert_false(pd.has_ability(SPELL), "gone with the rune")
	assert_true(pd.has_ability("frostbolt"), "the base kit is untouched")

func test_talent_view_opens_your_main_book() -> void:
	assert_eq(TalentView.default_book({"fire": 3, "frost": 7, "holy": 1}, Categories.ORDER), "frost")
	assert_eq(TalentView.default_book({}, Categories.ORDER), str(Categories.ORDER[0]), "no points yet: the first book")
	assert_eq(TalentView.default_book({"fire": 2, "frost": 2}, Categories.ORDER), "fire", "a tie goes to the earlier book")
	assert_true(TalentView.width_for(340.0) >= 28.0 * 7.0, "the whole tree fits")
	assert_true(TalentView.cell_size(2000.0) <= 44.0 and TalentView.cell_size(100.0) >= 28.0, "cells stay readable")
