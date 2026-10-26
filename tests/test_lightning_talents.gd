@tool
extends McpTestSuite

# Lightning talents that came before the ribbon tree (tests/test_lightning_tree.gd
# covers the layout and the new ones): where each sits now, its ranks and numbers,
# and what each does.

const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")

## key -> [slot, ranks, values, required ability]
const WANT := {
	# Live Current.
	"lightning_quick_fuse": ["lightning_r2c1", 3, [0.1, 0.15, 0.2], "lightningbolt"],
	"lightning_deep_reserves": ["lightning_r2c2", 3, [7.0, 13.0, 20.0], ""],
	"lightning_tight_coil": ["lightning_r2c3", 2, [1.0, 2.0], "balllightning"],
	"lightning_conductive": ["lightning_r4c1", 3, [1.0, 2.0, 3.0], ""],
	"lightning_high_voltage": ["lightning_r4c2", 3, [4.0, 7.0, 10.0], ""],
	"lightning_standing_charge": ["lightning_r5c2", 3, [2.0, 4.0, 6.0], "groundingsurge"],
	"lightning_conductor": ["lightning_r6c1", 3, [4.0, 7.0, 10.0], ""],
	"lightning_overflow": ["lightning_r7c2", 3, [0.07, 0.13, 0.2], "capacitor"],
	"lightning_parting_spark": ["lightning_r8c1", 3, [0.25, 0.55, 0.8], "flicker"],
	"lightning_storm_cycle": ["lightning_r10c2", 5, [200.0, 180.0, 160.0, 140.0, 120.0], ""],
	# Stormdancer.
	"lightning_charged_strikes": ["lightning_r1c4", 3, [1.0, 2.0, 3.0], ""],
	"lightning_quick_charge": ["lightning_r1c6", 3, [5.0, 10.0, 15.0], ""],
	"lightning_whip_crack": ["lightning_r3c4", 3, [7.0, 13.0, 20.0], "whiplash"],
	"lightning_third_beat": ["lightning_r3c5", 3, [10.0, 20.0, 30.0], "cadence"],
	"lightning_running_start": ["lightning_r3c6", 3, [7.0, 13.0, 20.0], "staticstep"],
	"lightning_running_on_empty": ["lightning_r4c6", 3, [3.0, 6.0, 9.0], ""],
	"lightning_redline": ["lightning_r6c5", 3, [0.3, 0.7, 1.0], "overdrive"],
	"lightning_hot_wire": ["lightning_r8c4", 3, [17.0, 33.0, 50.0], "twincurrent"],
	"lightning_calm_current": ["lightning_r9c6", 3, [5.0, 10.0, 15.0], ""],
	# Open (the spine).
	"lightning_live_current": ["lightning_r1c7", 3, [1.0, 2.0, 3.0], ""],
	"lightning_storm_tempered": ["lightning_r3c7", 3, [2.0, 4.0, 6.0], ""],
	"lightning_quick_step": ["lightning_r5c7", 3, [1.0, 2.0, 3.0], ""],
	# Lightning Rod.
	"lightning_earth_return": ["lightning_r4c10", 3, [0.3, 0.7, 1.0], ""],
	"lightning_second_stroke": ["lightning_r7c8", 3, [10.0, 20.0, 30.0], "returnstroke"],
	# Stormstring (a short ribbon until the spec is built).
	"lightning_rod": ["lightning_r1c12", 3, [13.0, 27.0, 40.0], "stormarrow"],
	"lightning_snap_shot": ["lightning_r2c12", 3, [10.0, 20.0, 30.0], "stormarrow"],
	"lightning_loaded_quiver": ["lightning_r3c12", 2, [1.0, 2.0], "stormarrow"],
}

func suite_name() -> String:
	return "lightning_talents"

func test_generic_stat_talents() -> void:
	var live := Talents.get_talent(Talents.id_for_key("lightning_live_current"))
	assert_eq(float(live["stats"].get("haste", 0.0)), 1.0, "+1% Haste per rank")
	var step := Talents.get_talent(Talents.id_for_key("lightning_quick_step"))
	assert_eq(float(step["stats"].get("dodge", 0.0)), 1.0, "+1% Dodge per rank")
	var pd: Node = track(PlayerDataScript.new())
	pd._ready()
	pd.level = 50
	pd.attribute_points = {"agility": 10}
	pd._invalidate_stats()
	var haste := float(pd.total_stats().get("haste", 0.0))
	var dodge := float(pd.total_stats().get("dodge", 0.0))
	var ap := float(pd.total_stats().get("attack_power", 0.0))
	pd.talents = {Talents.id_for_key("lightning_live_current"): 3, Talents.id_for_key("lightning_quick_step"): 2,
		Talents.id_for_key("lightning_storm_tempered"): 3}
	pd._invalidate_stats()
	var after: Dictionary = pd.total_stats()
	assert_true(absf(float(after.get("haste", 0.0)) - haste - 3.0) < 0.001, "+3% Haste")
	assert_true(absf(float(after.get("dodge", 0.0)) - dodge - 2.0) < 0.001, "+2% Dodge at rank 2")
	# Storm-Tempered: 6% of Agility as Attack Power.
	const StatsScript = preload("res://scripts/core/stats.gd")
	var agility: float = StatsScript.from_totals("agility", after)
	assert_true(agility > 0.0, "the character has Agility")
	assert_true(absf(float(after.get("attack_power", 0.0)) - ap - agility * 0.06) < 0.001, "6% of Agility")
	var d := func(key: String) -> String: return Talents.description(Talents.id_for_key(key))
	assert_contains(d.call("lightning_live_current"), "Haste by 1 / 2 / 3%")
	assert_contains(d.call("lightning_quick_step"), "Dodge chance by 1 / 2 / 3%")
	assert_contains(d.call("lightning_storm_tempered"), "2 / 4 / 6% of your Agility")
	assert_contains(d.call("lightning_charged_strikes"), "1 / 2 / 3 Energy")
	assert_contains(d.call("lightning_calm_current"), "5 / 10 / 15% less threat")

func test_overflow() -> void:
	var p := _player()
	assert_eq(BottledLightningKit.capacitor_overflow(100.0, 100.0), 0.0, "an empty bar takes it all")
	assert_eq(BottledLightningKit.capacitor_overflow(100.0, 40.0), 60.0, "60 Energy doesn't fit")
	assert_eq(BottledLightningKit.capacitor_overflow(30.0, 0.0), 30.0, "a full bar takes none of it")
	assert_eq(BottledLightningKit.capacitor_overflow(30.0, 50.0), 0.0)
	assert_eq(BottledLightningKit.capacitor_overflow(30.0, -5.0), 30.0)
	assert_true(is_equal_approx(BottledLightningKit.overflow_coef(60.0, 0.1), 0.6), "0.1 per 10 Energy")
	assert_true(is_equal_approx(BottledLightningKit.overflow_coef(60.0, 0.2), 1.2))
	assert_true(is_equal_approx(BottledLightningKit.overflow_coef(5.0, 0.2), 0.1), "part of a step counts")
	assert_eq(BottledLightningKit.overflow_coef(60.0, 0.0), 0.0, "no talent, no shield")
	assert_eq(BottledLightningKit.overflow_coef(0.0, 0.2), 0.0)
	assert_eq(Balance.OVERFLOW_TIME, 8.0)
	assert_eq(LightningCasterKit.OVERFLOW_FX, "overflow")
	var d := Talents.description(Talents.id_for_key("lightning_overflow"))
	assert_contains(d, Abilities.ability_name("capacitor"))
	assert_contains(d, "for 8 sec")
	assert_contains(d, "per 10 Energy")
	assert_false(d.contains("0.1"), "the shield is shown as a real amount: %s" % d)

func test_parting_spark() -> void:
	assert_eq(Balance.PARTING_SPARK_RADIUS, 4.0)
	assert_eq(LightningCasterKit.PARTING_SPARK_ID, "parting_spark")
	const Details = preload("res://scripts/core/details.gd")
	assert_eq(Details.spell_name("parting_spark"), "Parting Spark", "named after the talent on the meter")
	var d := Talents.description(Talents.id_for_key("lightning_parting_spark"))
	assert_contains(d, Abilities.ability_name("flicker"))
	assert_contains(d, "within 4 m")
	assert_contains(d, "Lightning damage")
	assert_false(d.contains("0.4"), "the zap is shown as real damage: %s" % d)

func test_snap_shot_and_loaded_quiver_costs() -> void:
	var p := _player()
	var arrow := float(Abilities.get_resource("stormarrow").resource_cost)
	assert_eq(arrow, 30.0)
	assert_eq(StormArrowKit.storm_arrow_cost(arrow, false, 0.0), 30.0, "no talent, full price")
	assert_eq(StormArrowKit.storm_arrow_cost(arrow, false, 15.0), 15.0, "Snap Shot rank 1")
	assert_eq(StormArrowKit.storm_arrow_cost(arrow, false, 30.0), 0.0, "Snap Shot rank 2: free")
	assert_eq(StormArrowKit.storm_arrow_cost(arrow, false, 50.0), 0.0, "never below zero")
	assert_eq(StormArrowKit.storm_arrow_cost(arrow, true, 0.0), 0.0, "a Loaded Quiver arrow is free")
	assert_eq(StormArrowKit.storm_arrow_cost(arrow, true, 15.0), 0.0)
	assert_eq(Balance.SNAP_SHOT_TIME, 5.0)
	assert_eq(Balance.LOADED_QUIVER_TIME, 10.0)
	assert_eq(LightningCasterKit.STORM_ARROW_ID, "stormarrow")
	var d := func(key: String) -> String: return Talents.description(Talents.id_for_key(key))
	assert_contains(d.call("lightning_snap_shot"), Abilities.ability_name("flicker"))
	assert_contains(d.call("lightning_snap_shot"), "within 5 sec cost 10 / 20 / 30 less Energy")
	assert_contains(d.call("lightning_loaded_quiver"), Abilities.ability_name("capacitor"))
	assert_contains(d.call("lightning_loaded_quiver"), "loads 1 / 2 %s for 10 sec" % Abilities.ability_name("stormarrow"))

func test_lightning_rod() -> void:
	const Effects = preload("res://scripts/core/effects.gd")
	const Details = preload("res://scripts/core/details.gd")
	var p := _player()
	var fx: Resource = Effects.get_effect(LightningCasterKit.ROD_FX)
	assert_true(fx != null, "the effect a Storm Arrow leaves exists")
	assert_true(bool(fx.per_caster), "own only: every archer has their own arrow in the target")
	assert_true(bool(fx.is_debuff))
	assert_eq(float(fx.duration), float(Balance.EFFECTS["res://data/effects/lightning_rod.tres"]["duration"]))
	assert_eq(float(fx.duration), 8.0)
	assert_eq(Balance.LIGHTNING_ROD_RADIUS, 4.0)
	assert_eq(TextFill.leftover(TextFill.effect(fx)), "", "the effect's text is filled in")
	assert_eq(Details.spell_name("lightning_rod"), "Grounded Arrow", "the arcs are named after the talent on the meter")
	assert_eq(StormArrowKit.lightning_rod_damage(200, 20.0), 40.0, "20% of the bolt")
	assert_eq(StormArrowKit.lightning_rod_damage(200, 40.0), 80.0)
	assert_eq(StormArrowKit.lightning_rod_damage(200, 0.0), 0.0, "no talent, no arc")
	assert_eq(StormArrowKit.lightning_rod_damage(0, 40.0), 0.0)
	assert_eq(StormArrowKit.lightning_rod_damage(200, 40.0, Balance.AOE_TARGET_CAP), 80.0, "up to the cap every arc is whole")
	assert_true(is_equal_approx(StormArrowKit.lightning_rod_damage(200, 40.0, Balance.AOE_TARGET_CAP * 2), 40.0), "twice the cap: half each")
	var d := Talents.description(Talents.id_for_key("lightning_rod"))
	assert_contains(d, "for 8 sec")
	assert_contains(d, "within 4 m")
	assert_contains(d, "13 / 27 / 40% of the damage")
	assert_contains(d, Abilities.ability_name("lightningbolt"))
	# Own only, on a real status container.
	const StatusContainer = preload("res://scripts/core/status_container.gd")
	var foe: Node = track(Node.new())
	var st: Node = StatusContainer.new()
	st.name = "Status"
	foe.add_child(st)
	var me: Node = track(Node.new())
	var ally: Node = track(Node.new())
	st.apply(fx, ally)
	assert_true(st.has_from(LightningCasterKit.ROD_FX, ally))
	assert_false(st.has_from(LightningCasterKit.ROD_FX, me), "an ally's arrow does nothing for my Lightning Bolts")
	st.apply(fx, me)
	assert_true(st.has_from(LightningCasterKit.ROD_FX, me))

func test_hot_wire_and_second_stroke() -> void:
	var d := func(key: String) -> String: return Talents.description(Talents.id_for_key(key))
	assert_contains(d.call("lightning_hot_wire"), "17 / 33 / 50% chance")
	assert_contains(d.call("lightning_hot_wire"), Abilities.ability_name("twincurrent"))
	assert_contains(d.call("lightning_second_stroke"), "10 / 20 / 30% chance")
	assert_contains(d.call("lightning_second_stroke"), Abilities.ability_name("returnstroke"))
	# They do nothing until their ability is learned.
	var pd = PlayerDataScript.new()
	pd.level = 50
	pd.learned_abilities.clear()
	pd.talents = {Talents.id_for_key("lightning_hot_wire"): 3, Talents.id_for_key("lightning_second_stroke"): 3,
		Talents.id_for_key("lightning_charged_strikes"): 3, Talents.id_for_key("lightning_calm_current"): 3}
	assert_eq(pd.talent_value("lightning_hot_wire"), 0.0, "Twin Current is not learned")
	assert_eq(pd.talent_value("lightning_second_stroke"), 0.0, "Return Stroke is not learned")
	assert_eq(pd.talent_value("lightning_charged_strikes"), 3.0, "generic talents just work")
	assert_eq(pd.talent_value("lightning_calm_current"), 15.0)
	pd.learned_abilities.append("twincurrent")
	pd.learned_abilities.append("returnstroke")
	assert_eq(pd.talent_value("lightning_hot_wire"), 50.0)
	assert_eq(pd.talent_value("lightning_second_stroke"), 30.0)
	pd.free()

func test_standing_charge() -> void:
	assert_eq(Balance.STANDING_CHARGE_EVERY, 1.0, "a stack each second")
	assert_eq(Balance.STANDING_CHARGE_MAX_STACKS, 5)
	var d := Talents.description(Talents.id_for_key("lightning_standing_charge"))
	assert_contains(d, Abilities.ability_name("groundingsurge"))
	assert_contains(d, "by 2 / 4 / 6%")
	assert_contains(d, "up to 5 times")
	assert_true(Balance.GROUNDING_SURGE_TIME >= Balance.STANDING_CHARGE_EVERY * Balance.STANDING_CHARGE_MAX_STACKS,
		"the Surge lasts long enough to reach full stacks")
	assert_eq(BottledLightningKit.STANDING_FX, "standing_charge")

func test_whip_crack() -> void:
	assert_eq(Balance.WHIP_CRACK_DISTANCE, 10.0)
	var p := _player()
	assert_true(BottledLightningKit.whip_crack_applies(10.5))
	assert_true(BottledLightningKit.whip_crack_applies(20.0))
	assert_false(BottledLightningKit.whip_crack_applies(10.0), "more than 10 m")
	assert_false(BottledLightningKit.whip_crack_applies(3.0))
	var step := float(Abilities.get_resource("staticstep").resource_cost)
	assert_eq(step, 20.0)
	assert_eq(BottledLightningKit.whip_crack_cost(step, 10.0), 10.0)
	assert_eq(BottledLightningKit.whip_crack_cost(step, 20.0), 0.0, "free at rank 2")
	assert_eq(BottledLightningKit.whip_crack_cost(step, 50.0), 0.0, "never below zero")
	assert_eq(BottledLightningKit.whip_crack_cost(step, 0.0), step)
	assert_true(float(Abilities.get_resource("whiplash").cast_range) > Balance.WHIP_CRACK_DISTANCE, "Whiplash reaches that far")
	var d := Talents.description(Talents.id_for_key("lightning_whip_crack"))
	assert_contains(d, "more than 10 m away")
	assert_contains(d, "7 / 13 / 20 less Energy")
	assert_contains(d, Abilities.ability_name("staticstep"))

func test_storm_cycle() -> void:
	var p := _player()
	assert_eq(BottledLightningKit.storm_cycle_step(0.0, 50.0, 200.0), [50.0, false])
	assert_eq(BottledLightningKit.storm_cycle_step(150.0, 30.0, 200.0), [180.0, false])
	assert_eq(BottledLightningKit.storm_cycle_step(180.0, 20.0, 200.0), [0.0, true], "200 Energy spent: the next cost is free")
	assert_eq(BottledLightningKit.storm_cycle_step(190.0, 40.0, 200.0), [30.0, true], "what is over carries into the next cycle")
	assert_eq(BottledLightningKit.storm_cycle_step(100.0, 30.0, 120.0), [10.0, true], "rank 5: every 120")
	assert_eq(BottledLightningKit.storm_cycle_step(50.0, 30.0, 0.0), [0.0, false], "no talent, nothing")
	assert_eq(BottledLightningKit.storm_cycle_step(50.0, -5.0, 200.0), [50.0, false])
	assert_eq(Balance.STORM_CYCLE_TIME, 60.0)
	var d := Talents.description(Talents.id_for_key("lightning_storm_cycle"))
	assert_contains(d, "Every 200 / 180 / 160 / 140 / 120 Energy")
	assert_eq(Talents.tier_of(Talents.id_for_key("lightning_storm_cycle")), Talents.ROWS - 1, "bottom row")
	assert_eq(Talents.group_of(Talents.id_for_key("lightning_storm_cycle")), "Live Current", "Live Current's capstone")
	assert_eq(Talents.col_of(Talents.id_for_key("lightning_storm_cycle")), 1, "in the middle of its ribbon")

## Rune of Bottled Lightning (Rare): taking Energy back out of the Capacitor makes the next Discharge instant.
func test_rune_of_bottled_lightning() -> void:
	const Runes = preload("res://scripts/runes.gd")
	assert_true(Runes.PATHS.has("bottled_lightning") and Runes.ALL.has("bottled_lightning"), "registered")
	assert_eq(Runes.rarity("bottled_lightning"), Runes.RARE)
	assert_eq(Runes.max_copies("bottled_lightning"), 1, "unique")
	assert_eq(Runes.rune_name("bottled_lightning"), "Rune of Bottled Lightning")
	assert_eq(Balance.BOTTLED_LIGHTNING_TIME, 8.0)
	assert_eq(BottledLightningKit.BOTTLED_RUNE, "bottled_lightning")
	var text := Runes.description("bottled_lightning")
	assert_eq(TextFill.leftover(text), "", "the rune's text is filled in")
	assert_false(text.contains("?"), text)
	assert_contains(text, Abilities.ability_name("capacitor"))
	assert_contains(text, Abilities.ability_name("discharge"))
	assert_contains(text, "within 8 sec instant")
	assert_true(float(Abilities.get_resource("discharge").cast_time) > 0.0, "Discharge has a cast time to skip")

func test_quick_fuse() -> void:
	var d := Talents.description(Talents.id_for_key("lightning_quick_fuse"))
	assert_contains(d, Abilities.ability_name("lightningbolt"))
	assert_contains(d, "0.1 / 0.15 / 0.2 sec faster")
	# Without the talent (the editor has no character) the cast time is the ability's own.
	var bolt := Abilities.get_resource("lightningbolt")
	assert_eq(Abilities.base_cast_time(bolt), float(bolt.cast_time))
	assert_true(float(bolt.cast_time) > 0.4, "0.2 s off still leaves a cast")

func test_tight_coil() -> void:
	var p := _player()
	assert_eq(LightningCasterKit.ball_zap_energy(0.0), Balance.BALL_LIGHTNING_ENERGY)
	assert_eq(LightningCasterKit.ball_zap_energy(2.0), Balance.BALL_LIGHTNING_ENERGY + 2.0, "2 more per zap at rank 2")
	var raw: Resource = ResourceLoader.load("res://data/abilities/balllightning.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	var text := Abilities.fill("balllightning", str(raw.description), Callable(), {})
	assert_contains(text, "each zap gives you %s Energy" % TextFill.num(Balance.BALL_LIGHTNING_ENERGY), "the tooltip quotes it (with the talent, more)")
	assert_eq(TextFill.leftover(text), "")

func test_earth_return() -> void:
	var p := _player()
	assert_eq(LightningCasterKit.earth_return_heal(1000, 1.0), 10, "1% of max health")
	assert_eq(LightningCasterKit.earth_return_heal(1000, 0.5), 5)
	assert_eq(LightningCasterKit.earth_return_heal(2550, 1.0), 26, "rounded")
	assert_eq(LightningCasterKit.earth_return_heal(1000, 0.0), 0, "no talent, nothing")
	assert_contains(Talents.description(Talents.id_for_key("lightning_earth_return")), "0.3 / 0.7 / 1% of your maximum health")
	assert_eq(preload("res://scripts/core/details.gd").spell_name("earth_return"), "Earth Return", "its own line on the healing meter")

func test_conductor() -> void:
	var p := _player()
	assert_true(LightningCasterKit.conductor_applies("lightning", true, false, false, 100), "a Lightning crit")
	assert_false(LightningCasterKit.conductor_applies("lightning", false, false, false, 100), "not a crit")
	assert_false(LightningCasterKit.conductor_applies("fire", true, false, false, 100), "Lightning damage only")
	assert_false(LightningCasterKit.conductor_applies("lightning", true, true, false, 100), "not arcs, zaps and other procs")
	assert_false(LightningCasterKit.conductor_applies("lightning", true, false, true, 100), "not periodic damage")
	assert_false(LightningCasterKit.conductor_applies("lightning", true, false, false, 0), "it has to land")
	assert_contains(Talents.description(Talents.id_for_key("lightning_conductor")), "4 / 7 / 10 Energy")

func test_high_voltage() -> void:
	assert_eq(Balance.HIGH_VOLTAGE_ENERGY, 80.0)
	var p := _player()
	assert_true(LightningCasterKit.high_voltage("lightning", 81.0))
	assert_true(LightningCasterKit.high_voltage("lightning", 120.0), "a bigger bar (Deep Reserves) counts too")
	assert_false(LightningCasterKit.high_voltage("lightning", 80.0), "80 is not above 80")
	assert_false(LightningCasterKit.high_voltage("lightning", 20.0))
	assert_false(LightningCasterKit.high_voltage("fire", 100.0), "Lightning damage only")
	# It never overlaps with Running on Empty.
	assert_true(Balance.HIGH_VOLTAGE_ENERGY > Balance.RUNNING_ON_EMPTY_ENERGY)
	var d := Talents.description(Talents.id_for_key("lightning_high_voltage"))
	assert_contains(d, "more than %s Energy" % TextFill.num(Balance.HIGH_VOLTAGE_ENERGY))
	assert_contains(d, "4 / 7 / 10%")

func _player() -> GDScript:
	return load("res://scripts/player.gd")

func test_the_talents_are_in_the_tree() -> void:
	for key in WANT:
		var want: Array = WANT[key]
		var id := Talents.id_for_key(str(key))
		assert_eq(id, str(want[0]), "%s has its slot" % key)
		var t := Talents.get_talent(id)
		assert_false(bool(t.get("placeholder", true)), "%s is a real talent" % key)
		assert_true(bool(t.get("implemented", false)), "%s has an effect" % key)
		assert_eq(Talents.max_rank(id), int(want[1]), "%s: ranks" % key)
		assert_eq(t.get("values", []), want[2], "%s: values" % key)
		assert_eq(Talents.required_ability(id), str(want[3]), "%s: the ability it needs" % key)
		assert_true(TalentIcons.has_icon(id), "%s has an icon" % key)
		assert_eq(TextFill.leftover(Talents.tooltip(id, 1)), "", "%s: every placeholder is filled" % key)
	for id in Talents.in_tree("lightning"):
		var placeholder := bool(Talents.get_talent(id).get("placeholder", true))
		assert_eq(TalentIcons.has_icon(id), not placeholder, "%s: designed talents have an icon, empty ones don't" % id)

func test_texts() -> void:
	var d := func(key: String) -> String: return Talents.description(Talents.id_for_key(key))
	assert_contains(d.call("lightning_quick_charge"), "5 / 10 / 15% faster")
	assert_contains(d.call("lightning_deep_reserves"), "by 7 / 13 / 20")
	assert_contains(d.call("lightning_running_on_empty"), "less than %s Energy" % TextFill.num(Balance.RUNNING_ON_EMPTY_ENERGY))
	assert_eq(Talents.id_for_key("lightning_honed_edge"), "", "Honed Edge was folded into Charged Edge")
	assert_contains(d.call("lightning_running_start"), "at least %s m" % TextFill.num(Balance.RUNNING_START_DISTANCE))
	assert_contains(d.call("lightning_redline"), "0.3 / 0.7 / 1 sec")
	assert_contains(d.call("lightning_redline"), "up to %s sec" % TextFill.num(Balance.REDLINE_MAX))
	var beat := Talents.id_for_key("lightning_third_beat")
	assert_true(Talents.has_capstone(beat), "Third Beat has a capstone")
	assert_contains(Talents.capstone_text(beat), "%s Energy" % TextFill.num(Balance.THIRD_BEAT_ENERGY))
	assert_contains(Talents.tooltip(Talents.id_for_key("lightning_redline"), 0), "Requires Overdrive to be learned")

func test_numbers() -> void:
	assert_eq(Balance.RUNNING_ON_EMPTY_ENERGY, 30.0)
	assert_eq(Balance.RUNNING_START_DISTANCE, 8.0)
	assert_eq(Balance.THIRD_BEAT_ENERGY, 15.0)
	assert_eq(Balance.REDLINE_MAX, 10.0)

func test_quick_charge() -> void:
	var p := _player()
	assert_eq(LightningMeleeKit.energy_regen(10.0, 0.0), 10.0)
	assert_true(is_equal_approx(LightningMeleeKit.energy_regen(10.0, 5.0), 10.5))
	assert_true(is_equal_approx(LightningMeleeKit.energy_regen(10.0, 15.0), 11.5), "15% faster")

func test_deep_reserves_moves_overdrives_limit() -> void:
	var p := _player()
	assert_eq(LightningMeleeKit.overdrive_limit(), 50.0, "half of 100")
	assert_eq(LightningMeleeKit.overdrive_limit(120.0), 60.0, "half of a bar of 120")
	assert_false(LightningMeleeKit.overdrive_holds(55.0), "55 is too much with a bar of 100")
	assert_true(LightningMeleeKit.overdrive_holds(55.0, 120.0), "but fine with a bar of 120")
	assert_false(LightningMeleeKit.overdrive_holds(60.5, 120.0))

func test_running_on_empty() -> void:
	var p := _player()
	var spell := PackedStringArray(["Lightning", "Spell"])
	var ability := PackedStringArray(["Ability", "Lightning", "Melee"])
	assert_true(LightningMeleeKit.running_on_empty("lightning", spell, 29.0))
	assert_true(LightningMeleeKit.running_on_empty("lightning", ability, 0.0))
	assert_false(LightningMeleeKit.running_on_empty("lightning", spell, 30.0), "30 is not below 30")
	assert_false(LightningMeleeKit.running_on_empty("lightning", spell, 80.0))
	assert_false(LightningMeleeKit.running_on_empty("fire", PackedStringArray(["Fire", "Spell"]), 0.0), "Lightning damage only")
	assert_false(LightningMeleeKit.running_on_empty("lightning", PackedStringArray(["Lightning", "Melee"]), 0.0), "spells and abilities, not Twin Current's echo")

func test_running_start() -> void:
	var p := _player()
	assert_true(LightningMeleeKit.running_start_applies(8.0))
	assert_true(LightningMeleeKit.running_start_applies(13.0))
	assert_false(LightningMeleeKit.running_start_applies(7.5), "a short hop gives nothing")

func test_redline() -> void:
	var p := _player()
	assert_eq(LightningMeleeKit.redline_add(1.0, 0.0), 1.0)
	assert_eq(LightningMeleeKit.redline_add(0.5, 4.0), 0.5)
	assert_eq(LightningMeleeKit.redline_add(1.0, 9.5), 0.5, "only what is left of the 10 s")
	assert_eq(LightningMeleeKit.redline_add(1.0, 10.0), 0.0, "no more after 10 s")
	assert_eq(LightningMeleeKit.redline_add(0.0, 0.0), 0.0, "no talent, nothing")

## Without talents (the editor has no character) the tooltips quote the base numbers.
func test_tooltips_without_talents() -> void:
	assert_eq(Abilities.generated_of("chargededge"), 30)
	assert_eq(Abilities.generated_of("whiplash"), 15)
	assert_eq(Abilities.generated_of("lightningbolt"), 0)
	assert_contains(Abilities.tooltip("chargededge"), "Generates 30 Energy")

## A talent of one ability does nothing until that ability is learned.
func test_ability_talents_need_their_ability() -> void:
	var pd = PlayerDataScript.new()
	pd.level = 50
	pd.learned_abilities.clear()
	var start := Talents.id_for_key("lightning_running_start")
	var beat := Talents.id_for_key("lightning_third_beat")
	pd.talents = {start: 3, beat: 3, Talents.id_for_key("lightning_deep_reserves"): 3,
		Talents.id_for_key("lightning_quick_charge"): 3}
	assert_eq(pd.talent_value("lightning_deep_reserves"), 20.0, "generic talents just work")
	assert_eq(pd.talent_value("lightning_quick_charge"), 15.0)
	assert_eq(pd.talent_value("lightning_running_start"), 0.0, "Static Step is not learned")
	assert_false(pd.talent_capstone("lightning_third_beat"), "Cadence is not learned")
	pd.learned_abilities.append("staticstep")
	pd.learned_abilities.append("cadence")
	assert_eq(pd.talent_value("lightning_running_start"), 20.0)
	assert_eq(pd.talent_value("lightning_third_beat"), 30.0)
	assert_true(pd.talent_capstone("lightning_third_beat"), "maxed: the capstone is on")
	pd.talents[beat] = 2
	assert_false(pd.talent_capstone("lightning_third_beat"), "not maxed: no capstone")
	pd.free()
