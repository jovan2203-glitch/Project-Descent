@tool
extends McpTestSuite

# The Fire tank, Slagforged (a one-handed weapon and a shield; Slag). Blocks and
# melee hits forge Slag, a crit's Slag is brittle, and only Forge Blow shatters it.
# Rules: scripts/player/fire_tank.gd.

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const Keywords = preload("res://scripts/core/keywords.gd")

const TANK := ["slagskin", "brand", "cinderguard", "anvil", "redhotrivet", "forgeblow", "moltenshell"]
const NEW := ["redhotrivet", "forgeblow", "moltenshell"]

func suite_name() -> String:
	return "fire_slag"

func _src() -> String:
	return PlayerSource.text()

func _spec(name: String) -> Array:
	for s in Abilities.SPECS["fire"]:
		if s[0] == name:
			return s[1]
	return []

func _near(a: float, b: float, msg: String = "") -> void:
	assert_true(absf(a - b) <= 0.001, "%s (%s vs %s)" % [msg, a, b])

func test_the_kit_is_the_slagforged_spec() -> void:
	assert_eq(_spec("Slagforged"), TANK, "the Slagforged spec holds the kit")
	for id in NEW:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s loads" % id)
		if r == null:
			continue
		assert_eq(str(r.id), id)
		assert_eq(Abilities.category_of(id), "fire", "%s is Fire" % id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is drafted, with a Skill Card" % id)
		assert_true(SkillCards.level_of(id) > 0, "%s's card has a level" % id)
		assert_true(r.tags.has("Ability") and r.tags.has("Fire"), "%s is a Fire ability" % id)
		assert_eq(int(r.weapon_requirement), 1, "%s needs a melee weapon" % id)
		var tip := Abilities.tooltip(id)
		assert_false(tip.contains("{") or tip.contains("}"), "%s: every number in its text is filled in: %s" % [id, tip])
	assert_true(Abilities.OFF_GCD.has("redhotrivet") and Abilities.LONG_REACH.has("redhotrivet"), "the taunt is off the GCD and reaches past the weapon")
	assert_true(Abilities.OFF_GCD.has("moltenshell"), "Molten Shell is off the GCD")
	assert_eq(Abilities.resource_of("forgeblow"), "fury", "Forge Blow spends Fury")

func test_block_slag() -> void:
	assert_eq(FireTankKit.block_slag(false, false), 1, "a block gives one Slag")
	assert_eq(FireTankKit.block_slag(true, false), Balance.CINDER_GUARD_SLAG, "more during Cinder Guard")
	assert_eq(FireTankKit.block_slag(false, true), Balance.MOLTEN_SHELL_BLOCK_SLAG, "more during Molten Shell")
	_near(FireTankKit.shell_reduction(0), 0.0)
	_near(FireTankKit.shell_reduction(10), Balance.MOLTEN_SHELL_DR * 10.0, "Molten Shell: less damage per Slag")
	assert_true(Balance.MOLTEN_SHELL_MAX > Balance.SLAG_MAX_STACKS, "Molten Shell holds more Slag")

func test_only_forge_blow_shatters() -> void:
	var tank := (load("res://scripts/player/fire_tank.gd") as GDScript).source_code
	var on_hit := tank.substr(tank.find("func _slag_on_hit"), 600)
	assert_false(on_hit.contains("_slag_shatter()"), "a crit no longer shatters Slag")
	assert_contains(on_hit, "gain_slag(1, bool(info.crit))", "a crit's Slag is brittle")
	assert_contains(tank, "player._shield_bash_effect(Abilities.color_of(id))\n\t\t\t_slag_shatter()", "Forge Blow shatters it")
	assert_contains(_src(), "id == \"kilnblast\" or id == \"forgeblow\"", "Forge Blow never crits")

func test_hooks_are_in_place() -> void:
	var src := _src()
	assert_contains(src, "_tank_use(id, res)   # Fire tank: Slagforged")
	assert_contains(src, "_tank_precheck(id)   # Fire tank")
	assert_contains(src, "\t_tick_slag()")
	assert_contains(src, "_slag_incoming(info)   # Molten Shell")
	var cd := (load("res://scripts/player/fire_cooldowns.gd") as GDScript).source_code
	assert_contains(cd, "player.fire_tank._slag_hit_taken(info)")

func test_slag_keyword() -> void:
	var text := Keywords.keyword_text("slag")
	assert_false(text.contains("{"), "Slag explains itself")
	assert_contains(text, "brittle")
