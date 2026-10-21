@tool
extends McpTestSuite

# The tank rule: while your bars make you a tank you deal Balance.TANK_DAMAGE_PCT
# of your damage for TANK_THREAT_MULT more threat (CombatSystem.deal asks the
# attacker: Player / RemotePlayer.outgoing_damage_mult / outgoing_threat_mult).
# Targets (CLAUDE.md): a tank at optimal play does 30-40% of a top DPS, and 1.3-1.7x its threat.

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const Sim = preload("res://tools/balance_sim.gd")
const SpecsInfo = preload("res://tools/balance_sim_specs.gd")

func suite_name() -> String:
	return "tank_rule"

func test_tanks_deal_less_for_more_threat() -> void:
	assert_eq(Abilities.role_damage_mult("tank"), Balance.TANK_DAMAGE_PCT / 100.0)
	assert_eq(Abilities.role_damage_mult("dps"), 1.0)
	assert_eq(Abilities.role_damage_mult("healer"), 1.0)
	assert_eq(Abilities.role_threat_mult("tank"), Balance.TANK_THREAT_MULT)
	assert_eq(Abilities.role_threat_mult("dps"), 1.0)

func test_the_role_comes_from_the_bars() -> void:
	var glacier: Array = []
	for spec in Abilities.SPECS["frost"]:
		if spec[0] == "Glacier Wall":
			glacier = spec[1]
	assert_false(glacier.is_empty())
	assert_eq(Abilities.role_of_bar(glacier), "tank")
	assert_eq(Abilities.role_of_bar(["frostbolt", "blizzard", "iceshards"]), "dps")

func test_the_game_and_the_puppets_use_it() -> void:
	var player := PlayerSource.text()
	assert_contains(player, "func outgoing_damage_mult()")
	assert_contains(player, "func outgoing_threat_mult()")
	var remote: String = (load("res://scripts/net/remote_player.gd") as GDScript).source_code
	assert_contains(remote, "func outgoing_damage_mult()", "the DoTs a party member's puppet ticks on the host")
	var combat: String = (load("res://scripts/core/combat_system.gd") as GDScript).source_code
	assert_contains(combat, "src.outgoing_damage_mult()")
	assert_contains(combat, "src.outgoing_threat_mult()")

func test_every_tank_lands_in_its_target() -> void:
	var lo := Sim.TARGET_DPS_GEARED * float(Sim.TARGET_TANK_SHARE[0])
	var hi := Sim.TARGET_DPS_GEARED * float(Sim.TARGET_TANK_SHARE[1])
	var tanks := 0
	for book in Abilities.SPECS:
		for spec in Abilities.SPECS[book]:
			if SpecsInfo.ROLES.get(spec[0], "dps") != "tank":
				continue
			tanks += 1
			var r: Dictionary = Sim.simulate(spec[1], "tank", "geared", spec[0], Sim.utility_of(book))
			var dps := float(r["dps"])
			assert_true(dps >= lo and dps <= hi, "%s: %d geared DPS, target %d-%d" % [spec[0], int(dps), int(lo), int(hi)])
			# Threat: ahead of a top DPS's steady damage, but not so far that a spike can't pull.
			var tlo := Sim.TARGET_DPS_GEARED * float(Sim.TARGET_TANK_THREAT[0])
			var thi := Sim.TARGET_DPS_GEARED * float(Sim.TARGET_TANK_THREAT[1])
			var tps := float(r["tps"])
			assert_true(tps >= tlo and tps <= thi, "%s: %d TPS, target %d-%d" % [spec[0], int(tps), int(tlo), int(thi)])
	assert_true(tanks >= 7, "every book's tank is checked")
