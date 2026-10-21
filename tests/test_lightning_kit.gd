@tool
extends McpTestSuite

# Energy and Fury as bars of 100, and the Lightning caster's Energy kit:
# Leaping Arc (gives Energy), Lightning Bolt (spends some), Discharge and
# Ground Out (spend all of it), Ball Lightning and Grounding Surge.

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")
const BallLightning = preload("res://scripts/ball_lightning.gd")

const NEW := ["discharge", "balllightning", "groundout", "groundingsurge",
	"arcflash", "livewire", "thunderhead", "forkedbolt", "jolt", "flicker", "capacitor"]
const Thunderhead = preload("res://scripts/thunderhead.gd")
const LiveWire = preload("res://scripts/live_wire.gd")

func suite_name() -> String:
	return "lightning_kit"

func _player() -> GDScript:
	return load("res://scripts/player.gd")

func test_energy_and_fury_are_bars_of_100() -> void:
	assert_eq(Balance.RESOURCE_MAX, 100.0)
	assert_eq(Balance.ENERGY_REGEN, 10.0, "the bar still fills in 10 s")
	assert_eq(Balance.FURY_DECAY, 5.0)
	assert_eq(Balance.AUTO_ATTACK_FURY, 10.0)
	# Every Energy / Fury cost and gain is on the 100 scale.
	var seen := 0
	for id in Abilities.ALL:
		var res := Abilities.resource_of(id)
		if res != "energy" and res != "fury":
			continue
		var r := Abilities.get_resource(id)
		for v in [int(r.resource_cost), int(r.resource_generated)]:
			assert_true(v == 0 or (v >= 10 and v <= 100), "%s: %d %s is on the 100 scale" % [id, v, res])
			seen += 1 if v > 0 else 0
	assert_true(seen > 30, "the fury and energy abilities were checked (%d numbers)" % seen)
	assert_eq(int(Abilities.get_resource("cinderguard").resource_cost), 20)
	assert_eq(int(Abilities.get_resource("brand").resource_generated), 20)
	assert_eq(int(Abilities.get_resource("stormarrow").resource_cost), 30)

func test_leaping_arc() -> void:
	var r := Abilities.get_resource("chainlightning")
	assert_eq(int(r.cast_type), 1, "has a cast time now")
	assert_eq(float(r.cast_time), 1.5)
	assert_eq(float(r.cooldown), 6.0)
	assert_eq(float(r.damage), 1.6, "1.6 Frost Bolts")
	assert_eq(Abilities.resource_of("chainlightning"), "energy")
	assert_eq(int(r.resource_cost), 0)
	assert_eq(int(r.resource_generated), 60, "gives 60 Energy")
	assert_eq(Balance.LEAPING_ARC_JUMPS, 3)
	var p := _player()
	assert_true(p.ENEMY_BOLTS.has("chainlightning"), "cast at an enemy like the bolts")
	assert_eq(LightningCasterKit.arc_returns(0), 3, "one target: every leap comes back")
	assert_eq(LightningCasterKit.arc_returns(1), 2)
	assert_eq(LightningCasterKit.arc_returns(3), 0, "enough enemies: none do")
	assert_eq(LightningCasterKit.arc_returns(8), 0)
	assert_true(is_equal_approx(LightningCasterKit.arc_return_coef(0.6), 0.24), "a returning leap deals 40% of a leap")

func test_lightning_bolt_spends_energy() -> void:
	assert_eq(Abilities.resource_of("lightningbolt"), "energy")
	assert_eq(int(Abilities.get_resource("lightningbolt").resource_cost), 15)

func test_new_abilities_are_draftable_lightning_spells() -> void:
	for id in NEW:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s exists" % id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is draftable and has a card" % id)
		assert_eq(SkillCards.ability_of(id), id)
		assert_eq(Abilities.category_of(id), "lightning")
		assert_true(r.tags.has("Lightning") and r.tags.has("Spell"), "%s is a Lightning spell" % id)
		assert_false(Abilities.ICON_FORM.has(id), "%s has an icon of its own" % id)
		var tip := Abilities.tooltip(id)
		assert_eq(TextFill.leftover(tip), "", "%s: every placeholder is filled" % id)
		assert_false(tip.contains("?"), "%s: %s" % [id, tip])

func test_arc_flash() -> void:
	var r := Abilities.get_resource("arcflash")
	assert_eq(int(r.cast_type), 0, "instant")
	assert_eq(float(r.cooldown), 8.0)
	assert_eq(int(r.resource_cost), 40, "40 Energy")
	assert_eq(Abilities.resource_of("arcflash"), "energy")
	assert_eq(float(r.damage), 0.8)
	assert_eq(float(r.radius), 6.0)
	assert_false(bool(r.requires_target), "it bursts around you")

func test_live_wire() -> void:
	var r := Abilities.get_resource("livewire")
	assert_eq(float(r.cast_time), 1.5)
	assert_eq(float(r.cooldown), 0.0, "no cooldown")
	assert_eq(int(r.resource_cost), 20)
	assert_eq(float(r.cast_range), Balance.LIVE_WIRE_RANGE, "it can't be cast from further than it holds")
	var fx: Resource = r.on_hit_effect
	assert_true(fx != null and str(fx.id) == "live_wire", "its damage is the Live Wire effect")
	assert_eq(float(fx.duration), 10.0)
	assert_eq(float(fx.tick_damage), 0.2)
	assert_eq(float(fx.tick_interval), 1.0)
	assert_eq(str(fx.damage_type), "lightning")
	assert_eq(Balance.LIVE_WIRE_ENERGY, 3.0, "3 Energy per tick")
	var p := _player()
	assert_true(p.ENEMY_BOLTS.has("livewire"))
	assert_false(BottledLightningKit.wire_breaks(25.0))
	assert_true(BottledLightningKit.wire_breaks(25.1), "past 25 m it breaks")
	assert_true(LiveWire.breaks_at(30.0, 25.0), "a party member's line ends at the same range")
	assert_false(LiveWire.breaks_at(30.0, 0.0), "mine is ended by the game, not by the picture")

func test_thunderhead() -> void:
	var r := Abilities.get_resource("thunderhead")
	assert_eq(float(r.cast_time), 2.0)
	assert_eq(float(r.cooldown), 20.0)
	assert_eq(int(r.resource_cost), 50)
	assert_eq(float(r.damage), 0.5, "per strike")
	assert_eq(float(r.radius), 5.0)
	assert_false(bool(r.requires_target), "placed on the ground")
	assert_eq(Balance.THUNDERHEAD_TIME, 8.0)
	assert_eq(Balance.THUNDERHEAD_TICK, 1.0)
	assert_eq(Thunderhead.strikes(8.0, 1.0), 8, "one strike a second for 8 s")
	assert_true(Thunderhead.strikes(8.0, 0.8) > 8, "more with Haste")
	assert_true(Thunderhead.inside(Vector3.ZERO, 5.0, Vector3(3.0, 9.0, 3.0)), "height doesn't matter")
	assert_false(Thunderhead.inside(Vector3.ZERO, 5.0, Vector3(4.0, 0.0, 4.0)))

func test_forked_bolt() -> void:
	var r := Abilities.get_resource("forkedbolt")
	assert_eq(float(r.cast_time), 2.0)
	assert_eq(int(r.resource_cost), 25)
	assert_eq(float(r.damage), 0.9)
	var p := _player()
	assert_true(p.ENEMY_BOLTS.has("forkedbolt"))
	var two: Array = BottledLightningKit.forked_bolt_hits(0.9, true)
	assert_eq(two.size(), 2, "two prongs with a second enemy")
	assert_true(is_equal_approx(float(two[0]), 0.9) and is_equal_approx(float(two[1]), 0.9))
	var one: Array = BottledLightningKit.forked_bolt_hits(0.9, false)
	assert_eq(one.size(), 1, "one hit without")
	assert_true(is_equal_approx(float(one[0]), 1.3))

func test_jolt() -> void:
	var r := Abilities.get_resource("jolt")
	assert_eq(int(r.cast_type), 0, "instant")
	assert_true(r.tags.has("Interrupt"))
	assert_true(Abilities.is_interrupt("jolt"))
	assert_eq(float(Balance.INTERRUPT_LOCKOUT.get("jolt", 0.0)), 3.0, "3 s lockout")
	assert_eq(Balance.JOLT_ENERGY, 30.0)
	var p := _player()
	assert_false(p.on_gcd("jolt"), "interrupts are off the global cooldown")
	var after: Dictionary = p.interrupt_cooldowns("jolt", float(r.cooldown), {})
	assert_true(after.has("counterspell") and after.has("jolt"), "it shares the interrupt cooldown")
	assert_eq(float(after["jolt"]), float(r.cooldown))

func test_flicker() -> void:
	var r := Abilities.get_resource("flicker")
	assert_eq(int(r.cast_type), 0, "instant")
	assert_eq(float(r.cooldown), 15.0)
	assert_eq(int(r.resource_cost), 30)
	assert_true(r.tags.has("Movement"))
	assert_eq(Balance.FLICKER_DISTANCE, 10.0)
	assert_eq(Balance.FLICKER_TIME, 5.0)
	assert_true(_player().on_gcd("flicker"))
	# Pressed again within FLICKER_RETURN_TIME: back where it started, while its cooldown runs.
	assert_true(Balance.FLICKER_RETURN_TIME > 0.0 and Balance.FLICKER_RETURN_TIME < float(r.cooldown))
	var src := PlayerSource.text()
	assert_contains(src, "\tif id == FLICKER_ID and flicker_back_ready():\n\t\t# Flicker pressed again in time: snap back (free, while its cooldown runs).",
		"checked before the cooldown")

func test_capacitor() -> void:
	var r := Abilities.get_resource("capacitor")
	assert_eq(int(r.cast_type), 0, "instant")
	assert_eq(float(r.cooldown), 30.0)
	assert_eq(Balance.CAPACITOR_TIME, 20.0)
	var p := _player()
	assert_false(p.on_gcd("capacitor"), "off the global cooldown")
	assert_eq(BottledLightningKit.capacitor_takes(60.0), 60.0, "all of it")
	assert_eq(BottledLightningKit.capacitor_takes(140.0), 100.0, "up to 100")
	assert_eq(BottledLightningKit.capacitor_takes(0.0), 0.0)

func test_which_of_them_scale() -> void:
	for id in ["jolt", "flicker", "capacitor", "groundingsurge"]:
		assert_false(Abilities.has_scaling(id), "%s has nothing to scale" % id)
	for id in ["arcflash", "livewire", "thunderhead", "forkedbolt", "discharge", "groundout", "balllightning"]:
		assert_true(Abilities.has_scaling(id), "%s scales" % id)

func test_discharge() -> void:
	var r := Abilities.get_resource("discharge")
	assert_eq(float(r.cast_time), 2.0, "2 s cast")
	assert_eq(float(r.cooldown), 6.0, "6 s cooldown")
	assert_true(bool(r.requires_target))
	assert_true(Abilities.SPENDS_ALL.has("discharge"))
	assert_contains(Abilities.tooltip("discharge"), "All Energy")
	var p := _player()
	assert_true(p.ENEMY_BOLTS.has("discharge"))
	assert_true(is_equal_approx(LightningCasterKit.discharge_coef(10.0), 0.3), "0.3 Frost Bolts per 10 Energy")
	assert_true(is_equal_approx(LightningCasterKit.discharge_coef(100.0), 3.0), "a full bar = 3 Frost Bolts")
	assert_eq(LightningCasterKit.discharge_coef(0.0), 0.0)

func test_ground_out() -> void:
	var r := Abilities.get_resource("groundout")
	assert_eq(int(r.cast_type), 0, "instant")
	assert_eq(float(r.cooldown), 6.0, "6 s cooldown")
	assert_false(bool(r.requires_target))
	assert_true(Abilities.SPENDS_ALL.has("groundout"))
	var p := _player()
	assert_true(p.on_gcd("groundout"))
	assert_true(LightningCasterKit.ground_out_coef(100.0) > LightningCasterKit.ground_out_coef(50.0), "more Energy, bigger shield")
	assert_true(is_equal_approx(LightningCasterKit.ground_out_coef(100.0), Balance.GROUND_OUT_PER_STEP * 10.0))

func test_ball_lightning() -> void:
	var r := Abilities.get_resource("balllightning")
	assert_eq(float(r.cast_time), 2.0, "2 s cast")
	assert_false(bool(r.requires_target), "it can be sent straight ahead")
	assert_true(float(r.damage) > 0.0 and float(r.radius) > 0.0)
	assert_eq(Balance.BALL_LIGHTNING_TICK, 0.5, "a zap every 0.5 s")
	assert_eq(Balance.BALL_LIGHTNING_ENERGY, 2.0, "2 Energy per zap")
	assert_true(BallLightning.in_reach(Vector3.ZERO, 5.0, Vector3(4.0, 3.0, 0.0)), "height doesn't matter")
	assert_false(BallLightning.in_reach(Vector3.ZERO, 5.0, Vector3(5.5, 0.0, 0.0)))
	assert_true(BallLightning.in_reach(Vector3.ZERO, 5.0, Vector3(5.5, 0.0, 0.0), 0.6), "a big enemy touching it")
	assert_eq(BallLightning.energy_zaps(3), 3, "one zap per enemy")
	assert_eq(BallLightning.energy_zaps(9), Balance.AOE_TARGET_CAP, "capped like its damage")
	assert_eq(BallLightning.energy_zaps(0), 0)

func test_grounding_surge() -> void:
	var r := Abilities.get_resource("groundingsurge")
	assert_eq(int(r.cast_type), 0, "instant")
	assert_eq(Balance.GROUNDING_SURGE_TIME, 15.0, "15 s")
	var p := _player()
	assert_false(p.on_gcd("groundingsurge"), "off the global cooldown")
	assert_true(p.on_gcd("discharge"), "the rest of the kit is on it")
	assert_eq(LightningCasterKit.surge_energy_cost(30.0, true), 15.0, "Energy costs are halved")
	assert_eq(LightningCasterKit.surge_energy_cost(30.0, false), 30.0)
	assert_eq(LightningCasterKit.energy_left_after_all(80.0, true), 40.0, "a spend-all ability leaves half")
	assert_eq(LightningCasterKit.energy_left_after_all(80.0, false), 0.0, "without it everything goes")
