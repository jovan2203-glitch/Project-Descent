@tool
extends McpTestSuite

# Damage meter: a line of damage that a talent, rune, item or trinket brought names
# its source in brackets; abilities and a spec's own mechanics have none.

const Details = preload("res://scripts/core/details.gd")
const Abilities = preload("res://scripts/abilities.gd")
const Runes = preload("res://scripts/runes.gd")

func suite_name() -> String:
	return "meter_sources"

func test_talent_lines_say_talent() -> void:
	assert_eq(Details.spell_name("splittingarrow"), "Splitting Arrow (Talent)")
	assert_eq(Details.spell_name("coldretort"), "Cold Retort (Talent)")
	assert_eq(Details.spell_name("dot_smoldering_debris"), "Smoldering Debris (Talent)")
	assert_eq(Details.spell_name(Details.BONUS_PREFIX + "Splintering"), "Splintering (Talent)", "added damage too")

func test_rune_lines_name_the_rune() -> void:
	assert_eq(Details.spell_name("hoar_blade"), "Hoar Blade (%s)" % Runes.rune_name("hoar_blade"))
	assert_eq(Details.spell_name("overload"), "Overload (%s)" % Runes.rune_name("overload"))
	assert_eq(Details.spell_name(Details.BONUS_PREFIX + "Dusk"), "Dusk (Dusk till Dawn)")
	assert_eq(Details.spell_name(Details.BONUS_PREFIX + "Static"), "Static (%s)" % Runes.rune_name("overload"))
	assert_eq(Details.spell_name("rune_frost"), Runes.rune_name("frost"), "already named after its rune")

func test_abilities_and_spec_mechanics_have_none() -> void:
	for id in ["frostbolt", "fireball", "auto_melee", "auto_ranged", "frozen_shatter", "hound_bite", "benediction"]:
		assert_false(Details.spell_name(id).ends_with(")"), "%s: %s" % [id, Details.spell_name(id)])
	assert_eq(Details.spell_name("dot_corruption").find("(Talent)"), -1)

func test_every_named_line_reads_cleanly() -> void:
	for id in Details.HIT_NAMES:
		var n := Details.spell_name(str(id))
		assert_false(n.contains("()") or n.contains("( "), "%s: %s" % [id, n])
		assert_true(n.begins_with(str(Details.HIT_NAMES[id])), "%s keeps its own name first: %s" % [id, n])

func test_item_lines_name_the_item() -> void:
	var n := Details.spell_name("item_frost_shard")
	assert_true(n.begins_with("Shattering Cold ("), n)
	assert_false(n.ends_with("()"), n)
