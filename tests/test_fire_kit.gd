@tool
extends McpTestSuite

# The rest of the Fire kit: Crucible, Cinder Step and Heat Sink for the caster,
# and the tank's Slag (Slag Skin, Brand, Cinder Guard, Anvil) with its talents.

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const Stats = preload("res://scripts/core/stats.gd")
const Crucible = preload("res://scripts/crucible.gd")
const CombatScript = preload("res://scripts/core/combat_system.gd")

const NEW := ["crucible", "cinderstep", "heatsink", "brand", "cinderguard", "anvil"]

func suite_name() -> String:
	return "fire_kit"

func _player() -> GDScript:
	return load("res://scripts/player.gd")

func test_new_abilities_are_registered() -> void:
	for id in NEW:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s loads" % id)
		if r == null:
			continue
		assert_eq(str(r.id), id)
		assert_eq(Abilities.category_of(id), "fire", "%s is in the Fire book" % id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is draftable and has a card" % id)
		assert_true(SkillCards.level_of(id) > 0, "%s's card has a level" % id)
		assert_false(Abilities.tooltip(id).contains("{"), "%s: every number in the description is filled in" % id)

func test_slag_skin_is_kept_up() -> void:
	var r := Abilities.get_resource("slagskin")
	assert_eq(int(r.cast_type), 0, "instant")
	assert_eq(float(r.cooldown), 13.0)
	assert_eq(Balance.SLAG_SKIN_TIME, 15.0)
	assert_true(float(r.cooldown) < Balance.SLAG_SKIN_TIME, "it can be refreshed before it drops")
	assert_eq(int(r.resource_cost), 0, "free: it is upkeep")
	assert_false(Abilities.tooltip("slagskin").contains("{"), "the Slag numbers are filled in")

func test_slag_stacks() -> void:
	var p := _player()
	assert_eq(FireTankKit.slag_armor(0.0), Balance.SLAG_ARMOR)
	assert_true(absf(float(FireTankKit.slag_armor(60.0)) - Balance.SLAG_ARMOR * 1.6) < 0.0001, "Thick Slag at 3 / 3: 60% more armor per stack")
	assert_eq(FireTankKit.slag_shatter_coef(0), 0.0, "nothing to shatter")
	assert_true(absf(float(FireTankKit.slag_shatter_coef(Balance.SLAG_MAX_STACKS)) - float(Balance.EXTRA_HITS["slagskin"]) * Balance.SLAG_MAX_STACKS) < 0.0001,
		"the shatter is per stack")
	assert_true(Balance.SLAG_MAX_STACKS > 1)

func test_blocks_burn_harder_with_hot_iron() -> void:
	var p := _player()
	assert_eq(FireTankKit.block_burn(0.3, 0.0), 0.3)
	assert_true(absf(float(FireTankKit.block_burn(0.3, 60.0)) - 0.48) < 0.0001)
	assert_true(Balance.CINDER_GUARD_BLOCK > 0.0 and Balance.CINDER_GUARD_TIME == 6.0)
	# Cinder Guard's block chance is added to the block chance from armor.
	var blocked: Dictionary = CombatScript.compute_damage(10.0, 0.0, 0.0, 0.0 + Balance.CINDER_GUARD_BLOCK, 0.0, 99.0, Balance.CINDER_GUARD_BLOCK - 1.0)
	assert_true(bool(blocked["blocked"]), "a roll under the bonus is a block even with no armor")
	var capped: Dictionary = CombatScript.compute_damage(10.0, 0.0, 0.0, 500.0, 0.0, 99.0, Stats.MAX_BLOCK + 1.0)
	assert_false(bool(capped["blocked"]), "block is still capped")

func test_tank_abilities() -> void:
	var brand := Abilities.get_resource("brand")
	assert_true(int(brand.resource_generated) > 0 and int(brand.resource_cost) == 0, "Brand builds fury")
	assert_true(float(brand.threat_multiplier) >= 3.0, "high threat")
	assert_true(brand.on_hit_effect != null, "leaves the brand on the target")
	var fx: Resource = load("res://data/effects/branded.tres")
	assert_true(bool(fx.get("per_caster")), "each tank has their own brand")
	assert_eq(float(fx.get("duration")), 10.0)
	var guard := Abilities.get_resource("cinderguard")
	assert_true(int(guard.resource_cost) > 0 and Abilities.resource_of("cinderguard") == "fury", "Cinder Guard spends fury")
	assert_true(bool(guard.requires_shield))
	var anvil := Abilities.get_resource("anvil")
	assert_true(bool(anvil.requires_shield) and float(anvil.radius) > 0.0, "a shield slam around you")
	assert_true(anvil.tags.has("Melee"), "a melee hit: it feeds Slag")
	assert_true(float(anvil.threat_multiplier) >= 4.0, "area threat")

func test_new_fire_talents() -> void:
	var want := {
		"fire_pressure_valve": ["fire_r2c2", [0.15, 0.35, 0.5]],
		"fire_cool_under_fire": ["fire_r3c4", [7.0, 13.0, 20.0]],   # moved down a row (Talents.MOVED)
		"fire_thick_slag": ["fire_r2c6", [20.0, 40.0, 60.0]],
		"fire_hot_iron": ["fire_r4c6", [15.0, 30.0, 45.0, 60.0]],
		"fire_blowback": ["fire_r6c5", [20.0, 35.0, 50.0]],
		"fire_clinker": ["fire_r6c6", [7.0, 13.0, 20.0]],
	}
	for key in want:
		var id := Talents.id_for_key(key)
		var vals: Array = want[key][1]
		assert_eq(id, str(want[key][0]), "%s sits where it should" % key)
		assert_eq(Talents.max_rank(id), vals.size(), "%s ranks" % key)
		for i in vals.size():
			assert_eq(Talents.value_at(id, i + 1), float(vals[i]), "%s rank %d" % [key, i + 1])
		assert_true(TalentIcons.has_icon(id), "%s has an icon" % key)
		assert_true(bool(Talents.get_talent(id).get("implemented", false)), "%s does something" % key)

func test_pressure_valve_cuts_vent_flames_cooldown() -> void:
	var p := _player()
	assert_eq(FireCasterKit.vent_after_cut(3.0, 0.5), 2.5)
	assert_eq(FireCasterKit.vent_after_cut(0.2, 0.5), 0.0, "never below ready")

func test_heat_sink() -> void:
	var p := _player()
	# A 100 damage hit with Heat Sink (-40%) deals 60: 40 was stored.
	assert_true(absf(float(FireCooldownsKit.heat_sink_stored(60.0, -40.0, 40.0)) - 40.0) < 0.001)
	# With another -10% on the same hit it deals 50, and Heat Sink's share is still 40.
	assert_true(absf(float(FireCooldownsKit.heat_sink_stored(50.0, -50.0, 40.0)) - 40.0) < 0.001)
	assert_eq(FireCooldownsKit.heat_sink_stored(0.0, -100.0, 40.0), 0.0, "nothing got through: nothing to count")
	assert_eq(FireCooldownsKit.heat_sink_coef(1.0, 0.0, 1000.0), 1.0, "nothing stored: the base burst")
	var full := 1000.0 * Balance.HEAT_SINK_FULL_AT / 100.0
	assert_eq(FireCooldownsKit.heat_sink_coef(1.0, full, 1000.0), 1.0 + Balance.HEAT_SINK_BONUS)
	assert_eq(FireCooldownsKit.heat_sink_coef(1.0, full * 0.5, 1000.0), 1.0 + Balance.HEAT_SINK_BONUS * 0.5)
	assert_eq(FireCooldownsKit.heat_sink_coef(1.0, full * 9.0, 1000.0), 1.0 + Balance.HEAT_SINK_BONUS, "capped")
	assert_eq(Balance.HEAT_SINK_TIME, 6.0)

func test_cinder_step_casts_on_the_move() -> void:
	var p := _player()
	assert_true(FireCooldownsKit.cinder_step_applies(PackedStringArray(["Fire", "Spell"]), 2.0, false), "a Fire spell with a cast time")
	assert_false(FireCooldownsKit.cinder_step_applies(PackedStringArray(["Fire", "Spell"]), 3.0, true), "not channels")
	assert_false(FireCooldownsKit.cinder_step_applies(PackedStringArray(["Fire", "Spell"]), 0.0, false), "instants don't need it")
	assert_false(FireCooldownsKit.cinder_step_applies(PackedStringArray(["Frost", "Spell"]), 1.5, false), "Fire only")
	assert_false(FireCooldownsKit.cinder_step_applies(PackedStringArray(["Fire", "Ability"]), 1.5, false), "spells only")
	for id in ["fireball", "kilnblast", "crucible", "walloffire", "frostfirebolt"]:
		var r := Abilities.get_resource(id)
		assert_true(FireCooldownsKit.cinder_step_applies(r.tags, float(r.cast_time), int(r.cast_type) == 2), "%s can be cast on the move" % id)
	var volley := Abilities.get_resource("embervolley")
	assert_false(FireCooldownsKit.cinder_step_applies(volley.tags, float(volley.cast_time), int(volley.cast_type) == 2), "Ember Volley is a channel")

func test_crucible() -> void:
	var r := Abilities.get_resource("crucible")
	assert_eq(float(r.cast_time), 1.5)
	assert_eq(int(r.cast_type), 3, "placed on the ground")
	assert_eq(float(r.cooldown), 0.0)
	assert_eq(Balance.CRUCIBLE_TIME, 10.0)
	assert_eq(Balance.CRUCIBLE_DOT_PCT, 15.0)
	var p := _player()
	assert_eq(FireCooldownsKit.crucible_time(false, 0.0, 10.0, false), 10.0, "a fresh one lasts the full time")
	assert_eq(FireCooldownsKit.crucible_time(true, 4.0, 10.0, false), 4.0, "a moved one keeps what it had left")
	assert_eq(FireCooldownsKit.crucible_time(true, 4.0, 10.0, true), 10.0, "unless moving is set to refresh it")
	var c := Vector3(10, 0, 10)
	assert_true(Crucible.inside(c, 5.0, Vector3(14.9, 3.0, 10)), "inside (height doesn't matter)")
	assert_false(Crucible.inside(c, 5.0, Vector3(15.4, 0, 10)), "outside")
	assert_true(Crucible.inside(c, 5.0, Vector3(15.4, 0, 10), 0.5), "a big enemy overlapping the edge counts")
