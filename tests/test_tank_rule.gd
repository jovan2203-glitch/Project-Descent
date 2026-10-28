@tool
extends McpTestSuite

# The tank rule, per hit: a tank spec's hits (its abilities, and the procs and
# talents of its kit: Abilities.TANK_HITS) deal Balance.TANK_DAMAGE_PCT of their
# damage for TANK_THREAT_MULT more threat. Nothing about the player (bars, gear)
# decides it: CombatSystem.deal asks Abilities.hit_damage_mult(info.ability_id).
# Targets (CLAUDE.md): a tank at optimal play does 30-40% of a top DPS, and 1.3-1.7x its threat.

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const Sim = preload("res://tools/balance_sim.gd")
const SpecsInfo = preload("res://tools/balance_sim_specs.gd")

const TANK_KITS := ["fire_tank", "frost_glacier", "lightning_tank", "arcane_tank", "nature_colossus", "holy_censer", "martial_brawler"]

func suite_name() -> String:
	return "tank_rule"

func test_tank_hits_deal_less_for_more_threat() -> void:
	assert_eq(Abilities.hit_damage_mult("brand"), Balance.TANK_DAMAGE_PCT / 100.0, "a tank ability")
	assert_eq(Abilities.hit_threat_mult("brand"), Balance.TANK_THREAT_MULT)
	assert_eq(Abilities.hit_damage_mult("reflection_shatter"), Balance.TANK_DAMAGE_PCT / 100.0, "a tank kit's proc")
	assert_eq(Abilities.hit_damage_mult("dot_smoldering_debris"), Balance.TANK_DAMAGE_PCT / 100.0, "a tank kit's ticks")
	for id in ["frostbolt", "fireball", "auto_melee", "auto_ranged", "rimelock"]:
		assert_eq(Abilities.hit_damage_mult(id), 1.0, id)
		assert_eq(Abilities.hit_threat_mult(id), 1.0, id)

## A DPS spell deals full damage whatever sits on the bars, and a tank ability
## deals the tank share whatever else does: the bars decide nothing.
func test_the_bars_decide_nothing() -> void:
	var combat: String = (load("res://scripts/core/combat_system.gd") as GDScript).source_code
	assert_contains(combat, "Abilities.hit_damage_mult(info.ability_id)")
	assert_contains(combat, "Abilities.hit_threat_mult(info.ability_id)")
	assert_false(combat.contains("outgoing_damage_mult"))
	assert_false(PlayerSource.text().contains("func outgoing_damage_mult"))
	var remote: String = (load("res://scripts/net/remote_player.gd") as GDScript).source_code
	assert_false(remote.contains("func outgoing_damage_mult"))

## Every hit id a tank kit deals with is a tank hit (a new proc must join TANK_HITS).
func test_every_tank_kit_hit_is_a_tank_hit() -> void:
	var re := RegEx.create_from_string("const ([A-Z_]+_ID) := \"([a-z_]+)\"")
	var deal_re := RegEx.create_from_string("(?:deal_damage[(][^,]+,[^,]+,|DamageInfo[.]make[(][^,]+,[^,]+,[^,]+,|_censer_proc_hit[(][^,]+,[^,]+,) *([A-Z_]+_ID)")
	for kit in TANK_KITS:
		var src: String = (load("res://scripts/player/%s.gd" % kit) as GDScript).source_code
		var ids := {}
		for m in re.search_all(src):
			ids[m.get_string(1)] = m.get_string(2)
		for m in deal_re.search_all(src):
			var c := m.get_string(1)
			if ids.has(c):
				assert_true(Abilities.is_tank_hit(str(ids[c])), "%s: %s (%s) is a tank hit" % [kit, c, ids[c]])

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
