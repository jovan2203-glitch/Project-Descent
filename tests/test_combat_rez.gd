@tool
extends McpTestSuite

# The party's combat rez charges: none at the start of a run, one more every
# Balance.COMBAT_REZ_INTERVAL sec, unused ones stack. A revive in combat (tag
# "Revive") spends one; out-of-combat rezzes and the Training Room are free.
# Rules: scripts/player/rez.gd; the count: scripts/net/net.gd (host-owned).

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")

func suite_name() -> String:
	return "combat_rez"

func _net_src() -> String:
	return FileAccess.get_file_as_string("res://scripts/net/net.gd")

func test_one_charge_every_five_minutes_none_at_the_start() -> void:
	assert_eq(Balance.COMBAT_REZ_INTERVAL, 300.0)
	assert_eq(RezKit.charges(0.0, 0), 0, "no charge at the start of a run")
	assert_eq(RezKit.charges(299.0, 0), 0)
	assert_eq(RezKit.charges(300.0, 0), 1)
	assert_eq(RezKit.charges(899.0, 0), 2, "unused charges stack")
	assert_eq(RezKit.charges(900.0, 1), 2, "a used charge is gone")
	assert_eq(RezKit.charges(600.0, 3), 0, "never below zero")

func test_next_charge_countdown() -> void:
	assert_eq(RezKit.next_charge_in(0.0), 300.0)
	assert_eq(RezKit.next_charge_in(120.0), 180.0)
	assert_eq(RezKit.next_charge_in(420.0), 180.0)

func test_every_combat_revive_checks_and_spends_a_charge() -> void:
	var src := PlayerSource.text()
	for id in Abilities.ALL:
		var r := Abilities.get_resource(id)
		if r and r.tags.has("Revive"):
			assert_true(id == "lastverse" or id == "notfinished",
				"%s is a combat revive: give it rez_kit.combat_rez_error() and spend_combat_rez()" % id)
	assert_true(src.count("rez_kit.combat_rez_error()") >= 2, "Last Verse and Not Finished With You check for a charge first")
	assert_true(src.count("rez_kit.spend_combat_rez()") >= 2, "... and spend one when they go off")

func test_the_host_owns_the_count_and_a_new_run_resets_it() -> void:
	var src := _net_src()
	assert_true(src.contains("_rez_t0 = _now()   # a new run"), "start_game starts the timer over")
	assert_true(src.contains("run[\"rez_elapsed\"]") and src.contains("_rez_take(r)"), "the count rides along with the party info")
	assert_true(src.contains("func _rez_spend(t: int)"), "clients ask the host to spend one")

func test_free_in_the_training_room_and_offline() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/player/rez.gd")
	assert_true(src.contains("not (gm != null and gm.in_training())"), "the Training Room is free")
	assert_true(src.contains("bool(net.online)"), "offline is free (no one to revive anyway)")
