@tool
extends McpTestSuite

# The balance simulator (tools/balance_sim.gd) runs for every spec and gives
# sensible numbers. The report itself: docs/BALANCE_REPORT.md.

const Abilities = preload("res://scripts/abilities.gd")
const Sim = preload("res://tools/balance_sim.gd")
const SpecsInfo = preload("res://tools/balance_sim_specs.gd")

func suite_name() -> String:
	return "balance_sim"

func test_every_spec_has_a_role() -> void:
	for book in Abilities.SPECS:
		for spec in Abilities.SPECS[book]:
			assert_true(SpecsInfo.ROLES.has(spec[0]), "%s has a role in tools/balance_sim_specs.gd" % spec[0])

func test_every_spec_simulates() -> void:
	for book in Abilities.SPECS:
		for spec in Abilities.SPECS[book]:
			var role: String = SpecsInfo.ROLES.get(spec[0], "dps")
			var bare: Dictionary = Sim.simulate(spec[1], role, "no gear", spec[0])
			var full: Dictionary = Sim.simulate(spec[1], role, "geared", spec[0])
			var key := "hps" if role == "healer" else "dps"
			assert_true(float(bare[key]) > 0.0, "%s does something with no gear" % spec[0])
			assert_true(float(full[key]) >= float(bare[key]), "%s: gear helps" % spec[0])

func test_fight_overrides_name_real_specs() -> void:
	var names := []
	for book in Abilities.SPECS:
		for spec in Abilities.SPECS[book]:
			names.append(spec[0])
	assert_false(names.is_empty(), "there are specs")
	for name in SpecsInfo.FIGHTS:
		assert_true(names.has(name), "%s is a spec" % name)

func test_payoffs_name_real_abilities() -> void:
	for id in SpecsInfo.PAYOFF:
		assert_true(Abilities.get_resource(id) != null, "%s is an ability" % id)

func test_a_plain_hit_is_the_level_hit() -> void:
	# Level 50, no gear: a 1.0 spell hit is 460 before crit (the tooltips' numbers).
	var stat_of := func(s: String) -> float: return 0.0
	var b: Dictionary = Sim.button("frostbolt", {}, stat_of, 1.0, 2550.0)
	var coef := Abilities.hit_base("frostbolt", {})
	var crit := 1.0 + Sim.Stats.crit_chance(Abilities.get_resource("frostbolt").tags, stat_of) / 100.0
	assert_true(absf(float(b["dmg"]) - coef * 460.0 * crit) < 1.0, "frostbolt: %s" % str(b["dmg"]))
