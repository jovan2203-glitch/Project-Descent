@tool
extends McpTestSuite

# Steady Flame's Fury (FireFuryKit, scripts/player/fire_fury.gd): Fire spell hits
# that don't crit build it from your crit chance, Fire spell crits Vent part of
# it, and the spenders use it. Maths here; the hooks are checked in the source.

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const Talents = preload("res://scripts/talents.gd")
const Runes = preload("res://scripts/runes.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")

func suite_name() -> String:
	return "fire_fury"

func _src() -> String:
	return PlayerSource.text()

func test_gain_grows_with_crit_chance() -> void:
	assert_true(is_equal_approx(FireFuryKit.fury_gain(0.0, false, 0.0, false), Balance.FIRE_FURY_BASE), "no crit chance: the base")
	assert_true(is_equal_approx(FireFuryKit.fury_gain(30.0, false, 0.0, false), Balance.FIRE_FURY_BASE + 30.0 * Balance.FIRE_FURY_PER_CRIT))
	assert_true(FireFuryKit.fury_gain(40.0, false, 0.0, false) > FireFuryKit.fury_gain(20.0, false, 0.0, false), "more crit chance, more Fury")
	assert_true(is_equal_approx(FireFuryKit.fury_gain(30.0, true, 0.0, false), FireFuryKit.fury_gain(30.0, false, 0.0, false) * Balance.FIRE_FURY_EMBER_MULT), "an ember gives a third")

func test_stoked_breath_and_sealed_kiln_scale_the_gain() -> void:
	var plain := FireFuryKit.fury_gain(25.0, false, 0.0, false)
	var id := Talents.id_for_key("fire_stoked_breath")
	assert_eq(id, "fire_r1c1")
	assert_true(TalentIcons.has_icon(id))
	assert_true(is_equal_approx(FireFuryKit.fury_gain(25.0, false, Talents.value_at(id, 4), false), plain * 1.2), "rank 4: 20% more")
	assert_true(is_equal_approx(FireFuryKit.fury_gain(25.0, false, 0.0, true), plain * (1.0 - Balance.SEALED_KILN_PCT / 100.0)), "Sealed Kiln: 30% less")

func test_vent_maths() -> void:
	assert_true(is_equal_approx(FireFuryKit.vented(60.0, 0.0, false), 60.0 * Balance.FIRE_FURY_VENT_PCT / 100.0))
	assert_eq(FireFuryKit.vented(0.0, 0.0, false), 0.0, "nothing to Vent")
	assert_eq(FireFuryKit.vented(90.0, 0.0, true), 0.0, "Sealed Kiln: crits Vent nothing")
	assert_true(is_equal_approx(FireFuryKit.vented(100.0, 50.0, false), 25.0), "Banked Coals rank 2: 25% instead of 50%")

func test_vent_flames_spends_all_and_scales_on_it() -> void:
	assert_true(Abilities.SPENDS_ALL.has("ventflames"))
	assert_eq(Abilities.resource_of("ventflames"), "fury")
	assert_eq(FireFuryKit.vent_spend(80.0, false), 80.0, "spends all")
	assert_eq(FireFuryKit.vent_spend(80.0, true), 40.0, "Hair Trigger: half")
	assert_true(is_equal_approx(FireFuryKit.vent_coef(2.0, 50.0), 2.0 * (1.0 + 50.0 * Balance.VENT_FURY_PCT / 100.0)), "+1% per Fury spent")
	assert_eq(FireFuryKit.vent_coef(2.0, 0.0), 2.0)
	assert_eq(Balance.VENT_FURY_MIN, 20.0)
	assert_contains(_src(), "Balance.VENT_FURY_MIN if all_res == \"fury\"", "needs some Fury to spend (can_afford)")
	assert_false(FireFuryKit.builds_fury("ventflames"), "spending it all builds none back")

## Which spells build: the free ones, not those that cost Fury.
func test_spenders_build_nothing() -> void:
	for id in ["fireball", "embervolley", "immolate"]:
		assert_eq(Abilities.resource_of(id), "fury", "%s is a Fury spell" % id)
		assert_eq(Abilities.cost_of(id), 0.0, "%s is free" % id)
		assert_true(FireFuryKit.builds_fury(id), "%s builds Fury" % id)
	var costs := {"kilnblast": 40.0, "stoke": 20.0, "flamenova": 30.0, "walloffire": 30.0, "crucible": 20.0}
	for id in costs:
		assert_eq(Abilities.resource_of(id), "fury", "%s costs Fury" % id)
		assert_eq(Abilities.cost_of(id), float(costs[id]), "%s: %d Fury" % [id, int(costs[id])])
		assert_false(FireFuryKit.builds_fury(id), "%s builds none" % id)
	assert_eq(Abilities.resource_of("furnacebreath"), "mana", "the Utility Fire spells keep their mana costs")

## The hooks: once per cast (each ember its own), never from ticks or procs, and
## Vent Flames' own sure crit Vents nothing.
func test_the_hit_hook() -> void:
	var src := _src()
	assert_contains(src, "\t_fury_on_hit(info)", "fed by the Fire hit hook")
	assert_contains(src, "if info.is_proc or info.is_dot or id == VENT_ID:")
	assert_contains(src, "key = \"embervolley#%d\" % info.get_instance_id()", "every ember is its own")
	assert_contains(src, "store_crit(info, chance)", "the crit chance before the spell's own changes")

func test_no_decay_while_casting() -> void:
	assert_contains(_src(), "if not casting:   # (no Fury is lost while casting or channeling")

func test_kiln_blast_never_crits() -> void:
	assert_contains(_src(), "or id == \"kilnblast\"")
	assert_contains(Abilities.tooltip("kilnblast"), "Cannot critically strike")

func test_damped_and_wild_embers_move_only_ember_crits() -> void:
	var player_script: GDScript = load("res://scripts/player.gd")
	var wild: Array = player_script.fire_crit_rules("embervolley", 30.0, 0.0, 0.0, 20.0)
	assert_true(is_equal_approx(float(wild[0]), 50.0), "Wild Embers rank 2: +20 crit chance")
	var damped: Array = player_script.fire_crit_rules("embervolley", 30.0, 0.0, 0.0, -30.0)
	assert_eq(float(damped[0]), 0.0, "Damped Embers rank 3: 30 less, never below 0")
	var bolt: Array = player_script.fire_crit_rules("fireball", 30.0, 0.0, 0.0, 30.0)
	assert_eq(float(bolt[0]), 30.0, "Firebolt is untouched")
	assert_contains(_src(), "_talent(\"fire_wild_embers\") - _talent(\"fire_damped_embers\")")

func test_smoldering_focus_and_blowback() -> void:
	assert_eq(FireFuryKit.smolder_pct(50.0, 0.1), 5.0)
	assert_eq(FireFuryKit.smolder_pct(0.0, 0.1), 0.0, "no Fury, no bonus")
	assert_contains(_src(), "info.add_bonus(smolder, \"Smoldering Focus\")", "its own damage-meter line")
	var id := Talents.id_for_key("fire_blowback")
	assert_eq(id, "fire_r5c1")
	assert_true(TalentIcons.has_icon(id))
	assert_true(is_equal_approx(FireFuryKit.blowback_coef(40.0, 50.0), 20.0 * Balance.BLOWBACK_PER_FURY), "half of 40 Vented burns")
	assert_eq(FireFuryKit.blowback_coef(40.0, 0.0), 0.0)
	assert_false(Talents.description(id).contains("{"), "every number is filled in")
	assert_contains(_src(), "deal_dot(self, tgt, float(b[\"per_tick\"]), \"fire\", \"blowback\"", "a Fire DoT of its own (dot_blowback)")

func test_runes() -> void:
	assert_true(Runes.PATHS.has("sealed_kiln") and Runes.ALL.has("sealed_kiln"))
	assert_eq(Runes.rarity("sealed_kiln"), Runes.EPIC)
	assert_contains(_src(), "Stats.crit_chance(info.tags, func(s): return Stats.resolve(s, _raw_stat))", "Dull Mind: Fury from the uncapped crit chance")
	assert_contains(_src(), "return Stats.SPELL_POWER if has_mind", "Dull Mind keeps its Spell Power")
