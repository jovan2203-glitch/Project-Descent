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

## The meter's threat bars read an enemy's threat table: biggest first, who it attacks marked.
func test_threat_rows_for_the_meter() -> void:
	var e: Node3D = track(load("res://scripts/enemy.gd").new())
	var me := Node3D.new()
	var mate := Node3D.new()
	track(me)
	track(mate)
	me.add_to_group("player")
	mate.add_to_group("remote_player")
	e.threat[mate.get_instance_id()] = {"node": mate, "value": 40.0}
	e.threat[me.get_instance_id()] = {"node": me, "value": 100.0}
	var rows: Array = e.threat_rows()
	assert_eq(rows.size(), 2)
	assert_true(bool(rows[0]["me"]) and bool(rows[0]["aggro"]), "I'm on top and it attacks me")
	assert_eq(float(rows[0]["value"]), 100.0)
	assert_false(bool(rows[1]["me"]) or bool(rows[1]["aggro"]))
	assert_eq(float(rows[1]["value"]), 40.0)
	var src := FileAccess.get_file_as_string("res://scripts/core/details.gd")
	assert_contains(src, "rows = tgt.threat_rows()", "the meter shows them for my target")
