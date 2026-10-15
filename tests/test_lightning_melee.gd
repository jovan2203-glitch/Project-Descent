@tool
extends McpTestSuite

# Lightning melee: the Energy bar with a weapon. Charged Edge and Whiplash give
# Energy; Arc Cleave, Cadence, Twin Current, Static Step and Reflex Arc spend it;
# Overdrive, Back-Current, Faraday Guard and Split Second are its cooldowns.
# Polar Strike is taught by the Rune of Polarity.

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const Runes = preload("res://scripts/runes.gd")
const Categories = preload("res://scripts/categories.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")
const DamageInfo = preload("res://scripts/core/damage_info.gd")
const StatusContainer = preload("res://scripts/core/status_container.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")
const CombatSystem = preload("res://scripts/core/combat_system.gd")

const NEW := ["chargededge", "arccleave", "overdrive", "twincurrent", "staticstep", "backcurrent", "cadence",
	"splitsecond", "whiplash", "faradayguard", "reflexarc"]

func suite_name() -> String:
	return "lightning_melee"

func _player() -> GDScript:
	return load("res://scripts/player.gd")

func test_new_abilities_are_draftable_lightning_abilities() -> void:
	for id in NEW:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s exists" % id)
		assert_eq(str(r.id), id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is draftable and has a card" % id)
		assert_eq(SkillCards.ability_of(id), id)
		assert_true(SkillCards.level_of(id) > 0, "%s: its card has a level" % id)
		assert_eq(Abilities.category_of(id), "lightning")
		assert_true(r.tags.has("Lightning") and r.tags.has("Ability") and not r.tags.has("Spell"), "%s is a Lightning ability" % id)
		assert_eq(int(r.cast_type), 0, "%s is instant" % id)
		assert_eq(int(r.weapon_requirement), 1, "%s needs a melee weapon" % id)
		assert_eq(Abilities.resource_of(id), "energy", "%s runs on Energy" % id)
		assert_eq(str(r.damage_type), "lightning")
		assert_false(Abilities.ICON_FORM.has(id), "%s has an icon of its own" % id)
		assert_true(_player().on_gcd(id), "%s is on the global cooldown" % id)
		var tip := Abilities.tooltip(id)
		assert_eq(TextFill.leftover(tip), "", "%s: every placeholder is filled" % id)
		assert_false(tip.contains("?"), "%s: %s" % [id, tip])
	# No two cards share a place in the list.
	var orders := {}
	for id in SkillCards.ALL:
		var order := int(SkillCards.get_resource(id).sort_order)
		if NEW.has(id):
			assert_false(orders.has(order), "%s: sort order %d is taken" % [id, order])
		orders[order] = id

func test_thunder_strike_costs_energy() -> void:
	var r: Resource = ResourceLoader.load("res://data/abilities/thunderstrike.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_eq(int(r.resource_type), 2, "Energy, not Rage")
	var tuned := Abilities.get_resource("thunderstrike")
	assert_eq(int(tuned.resource_cost), 30)
	assert_eq(float(tuned.weapon_damage_multiplier), 1.0)
	assert_eq(float(tuned.cooldown), 10.0)
	assert_true(tuned.on_hit_effect != null and bool(tuned.on_hit_effect.stun), "still a stun")

func test_charged_edge() -> void:
	var r := Abilities.get_resource("chargededge")
	assert_eq(float(r.cooldown), 4.0)
	assert_eq(int(r.resource_cost), 0, "no cost")
	assert_eq(int(r.resource_generated), 20, "gives 20 Energy")
	assert_eq(float(r.weapon_damage_multiplier), 1.2)
	assert_eq(int(r.weapon_requirement), 1)
	assert_true(bool(r.requires_target))
	assert_contains(Abilities.tooltip("chargededge"), "Generates 20 Energy")

func test_arc_cleave() -> void:
	var r := Abilities.get_resource("arccleave")
	assert_eq(float(r.cooldown), 6.0)
	assert_eq(int(r.resource_cost), 35)
	assert_eq(float(r.weapon_damage_multiplier), 0.8)
	assert_eq(float(r.radius), 4.0)
	assert_false(bool(r.requires_target), "it sweeps around you")
	assert_true(r.tags.has("AoE"))
	assert_eq(Balance.aoe_share(5), 1.0)
	assert_true(Balance.aoe_share(10) < 1.0, "more than five enemies share the damage")

func test_overdrive() -> void:
	var r := Abilities.get_resource("overdrive")
	assert_eq(float(r.cooldown), 45.0)
	assert_eq(int(r.resource_cost), 0)
	assert_eq(float(r.damage), 0.1, "the zap")
	assert_eq(Balance.OVERDRIVE_TIME, 20.0)
	assert_eq(Balance.OVERDRIVE_SPEED_PCT, 40.0)
	assert_eq(Balance.OVERDRIVE_ENERGY, 5.0)
	var p := _player()
	assert_eq(p.overdrive_limit(), 50.0, "half the bar")
	assert_true(p.overdrive_holds(0.0))
	assert_true(p.overdrive_holds(50.0), "exactly half is fine")
	assert_false(p.overdrive_holds(50.5), "anything above ends it")
	assert_false(p.overdrive_holds(100.0))
	assert_true(is_equal_approx(p.auto_interval(2.8, 1.0, false), 2.8))
	assert_true(is_equal_approx(p.auto_interval(2.8, 1.0, true), 2.0), "40% faster swings")
	assert_true(is_equal_approx(p.auto_interval(2.8, 1.25, true), 1.6), "on top of Haste")

func test_twin_current() -> void:
	var r := Abilities.get_resource("twincurrent")
	assert_eq(float(r.cooldown), 20.0)
	assert_eq(int(r.resource_cost), 20)
	assert_eq(Balance.TWIN_CURRENT_HITS, 4)
	assert_eq(Balance.TWIN_CURRENT_PCT, 50.0)
	var p := _player()
	assert_eq(p.twin_current_damage(200), 100.0, "half the swing")
	assert_eq(p.twin_current_damage(0), 0.0)
	assert_false(Abilities.has_scaling("twincurrent"), "a share of the swing: nothing of its own to scale")
	# Four charges, one used per swing.
	var holder := Node.new()
	var st: Node = StatusContainer.new()
	holder.add_child(st)
	track(holder)
	var fx: Resource = StatusContainer.make_buff(p.TWIN_CURRENT_FX, "Twin Current", p.TWIN_CURRENT_FX, 0.0, 20.0, Balance.TWIN_CURRENT_HITS, Color.WHITE)
	st.apply(fx, null)
	st.set_stacks(p.TWIN_CURRENT_FX, Balance.TWIN_CURRENT_HITS)
	assert_eq(int(st.stacks_of(p.TWIN_CURRENT_FX)), 4)
	for i in 3:
		st.spend_stacks(p.TWIN_CURRENT_FX, 1)
	assert_eq(int(st.stacks_of(p.TWIN_CURRENT_FX)), 1)
	st.spend_stacks(p.TWIN_CURRENT_FX, 1)
	assert_false(st.has(p.TWIN_CURRENT_FX), "gone after the fourth")

func test_static_step() -> void:
	var r := Abilities.get_resource("staticstep")
	assert_eq(float(r.cooldown), 12.0)
	assert_eq(int(r.resource_cost), 20)
	assert_eq(float(r.cast_range), 15.0, "from up to 15 m")
	assert_eq(int(r.weapon_requirement), 1)
	assert_true(bool(r.requires_target))
	assert_eq(Balance.STATIC_STEP_TIME, 4.0)
	assert_eq(Balance.STATIC_STEP_PCT, 30.0)
	assert_true(Abilities.LONG_REACH.has("staticstep"))
	assert_false(Abilities.uses_weapon_reach("staticstep"), "usable from its own range, not the weapon's")
	assert_true(Abilities.uses_weapon_reach("chargededge"))
	assert_false(Abilities.uses_weapon_reach("lightningbolt"))
	var p := _player()
	assert_eq(p.static_step_travel(10.0, 2.0), 9.0, "it stops inside weapon reach")
	assert_eq(p.static_step_travel(0.5, 2.0), 0.0, "already there: it never goes backwards")

func test_next_weapon_ability_bonuses() -> void:
	var p := _player()
	assert_true(p.is_weapon_ability_hit("chargededge", false, false))
	assert_true(p.is_weapon_ability_hit("slam", false, false), "any weapon ability")
	assert_true(p.is_weapon_ability_hit("cadence", false, false))
	assert_false(p.is_weapon_ability_hit("auto_melee", false, false), "not auto-attacks")
	assert_false(p.is_weapon_ability_hit("chargededge", true, false), "not procs")
	assert_false(p.is_weapon_ability_hit("chargededge", false, true), "not damage over time")
	assert_false(p.is_weapon_ability_hit("lightningbolt", false, false), "not spells")
	assert_false(p.is_weapon_ability_hit("overdrive", false, false), "Overdrive's zap is not a weapon hit")
	assert_false(p.is_weapon_ability_hit("twincurrent", false, false))
	assert_true(p.polarity_applies("chargededge"))
	assert_false(p.polarity_applies("polarstrike"), "Polar Strike twice in a row gets nothing")

func test_back_current() -> void:
	var r := Abilities.get_resource("backcurrent")
	assert_eq(float(r.cooldown), 30.0)
	assert_eq(float(r.damage), 0.3)
	assert_eq(Balance.BACK_CURRENT_TIME, 5.0)
	assert_eq(Balance.BACK_CURRENT_ENERGY, 10.0)
	var p := _player()
	assert_true(p.is_melee_attack(PackedStringArray(["Physical", "Melee"]), false))
	assert_false(p.is_melee_attack(PackedStringArray(["Physical", "Melee"]), true), "never damage over time")
	assert_false(p.is_melee_attack(PackedStringArray(["Fire", "Spell"]), false), "not spells")

func test_cadence() -> void:
	var r := Abilities.get_resource("cadence")
	assert_eq(float(r.cooldown), 0.0, "no cooldown")
	assert_eq(int(r.resource_cost), 15, "15 Energy a press")
	assert_eq(float(r.radius), 4.0)
	assert_eq(Balance.CADENCE_WINDOW, 3.0)
	assert_eq(Balance.CADENCE_MULTS, [0.6, 0.9, 1.5])
	assert_eq(float(r.weapon_damage_multiplier), float(Balance.CADENCE_MULTS[0]), "the data's multiplier is the first press")
	var p := _player()
	assert_eq(p.cadence_step(0), 0)
	assert_eq(p.cadence_step(1), 1)
	assert_eq(p.cadence_step(2), 2)
	assert_eq(p.cadence_step(7), 2)
	assert_eq(p.cadence_mult(0), 0.6)
	assert_eq(p.cadence_mult(1), 0.9)
	assert_eq(p.cadence_mult(2), 1.5)
	# The tooltip quotes all three presses, each bigger than the last.
	var sword: Dictionary = Abilities.basic_weapon("cadence")
	var none := func(_s: String) -> float: return 0.0
	var parts := Abilities.fill("cadence", "{cad1}|{cad2}|{cad3}", none, sword).split("|")
	assert_eq(parts.size(), 3)
	assert_true(float(parts[0]) < float(parts[1]) and float(parts[1]) < float(parts[2]), "0.6x < 0.9x < 1.5x: %s" % str(parts))

func test_split_second() -> void:
	var r := Abilities.get_resource("splitsecond")
	assert_eq(float(r.cooldown), 60.0)
	assert_eq(Balance.SPLIT_SECOND_TIME, 8.0)
	assert_eq(Balance.SPLIT_SECOND_GCD, 0.5)
	var p := _player()
	assert_eq(p.split_second_gcd(1.5), 1.0, "0.5 s shorter")
	assert_eq(p.split_second_gcd(0.75), 0.5, "never below the floor")
	assert_eq(p.split_second_gcd(0.3), 0.3, "and never longer than it was")
	assert_false(Abilities.has_scaling("splitsecond"))

func test_whiplash() -> void:
	var r := Abilities.get_resource("whiplash")
	assert_eq(float(r.cooldown), 6.0)
	assert_eq(int(r.resource_cost), 0)
	assert_eq(int(r.resource_generated), 15)
	assert_eq(float(r.weapon_damage_multiplier), 0.7)
	assert_eq(float(r.cast_range), 20.0)
	assert_eq(int(r.weapon_requirement), 1, "a melee weapon's damage")
	assert_false(Abilities.uses_weapon_reach("whiplash"), "from 20 m, not from weapon reach")
	assert_contains(Abilities.tooltip_bbcode("whiplash", true), "Range 20 m")

func test_faraday_guard() -> void:
	var r := Abilities.get_resource("faradayguard")
	assert_eq(float(r.cooldown), 45.0)
	assert_eq(Balance.FARADAY_GUARD_TIME, 8.0)
	assert_eq(Balance.FARADAY_GUARD_PCT, 30.0)
	var p := _player()
	assert_eq(p.faraday_energy(10.0, 1000.0), 1.0, "1 Energy per 1% of max health")
	assert_eq(p.faraday_energy(150.0, 1000.0), 15.0)
	assert_eq(p.faraday_energy(0.0, 1000.0), 0.0)
	assert_eq(p.faraday_energy(50.0, 0.0), 0.0)
	# A hit of 100 before modifiers lands for 70: 30 was spared.
	assert_true(is_equal_approx(p.heat_sink_stored(70.0, -30.0, 30.0), 30.0))
	assert_eq(p.bonus_named([["Brand", -20.0], [p.FARADAY_LABEL, -30.0]], p.FARADAY_LABEL), -30.0)
	assert_eq(p.bonus_named([["Brand", -20.0]], p.FARADAY_LABEL), 0.0)
	assert_false(Abilities.has_scaling("faradayguard"))

func test_reflex_arc() -> void:
	var r := Abilities.get_resource("reflexarc")
	assert_eq(float(r.cooldown), 20.0)
	assert_eq(int(r.resource_cost), 20)
	assert_eq(float(r.weapon_damage_multiplier), 1.5, "the strike back")
	assert_false(bool(r.requires_target), "you use it before the attack comes")
	assert_eq(Balance.REFLEX_ARC_TIME, 3.0)
	# The avoiding modifier takes any hit down to nothing, whatever else is on it.
	var p := _player()
	var info := DamageInfo.make(null, null, 1.0, "enemy_melee")
	info.add_bonus(50.0, "Berserk")
	info.add_bonus(-p.AVOID_PCT, p.REFLEX_LABEL)
	var hit: Dictionary = CombatSystem.compute_damage(500.0, 0.0, 0.0, 0.0, 0.0, 99.0, 99.0, true, true, 1.0 + info.bonus_pct / 100.0, 0.99)
	assert_eq(int(hit["amount"]), 0, "avoided")
	assert_true(p.bonus_named(info.bonus_parts, p.REFLEX_LABEL) != 0.0)

func test_polar_strike_comes_from_a_rare_rune() -> void:
	var r := Abilities.get_resource("polarstrike")
	assert_true(r != null)
	assert_eq(float(r.cooldown), 3.0)
	assert_eq(int(r.resource_cost), 20)
	assert_eq(Abilities.resource_of("polarstrike"), "energy")
	assert_eq(float(r.weapon_damage_multiplier), 1.0)
	assert_eq(Balance.POLARITY_PCT, 25.0)
	assert_true(Abilities.ALL.has("polarstrike"), "can go on the action bar")
	assert_false(Abilities.DRAFT_POOL.has("polarstrike"), "never drafted")
	assert_false(SkillCards.ALL.has("polarstrike"), "no Skill Card")
	assert_eq(Abilities.category_of("polarstrike"), Categories.RUNE)
	assert_false(Abilities.ICON_FORM.has("polarstrike"))
	assert_eq(TextFill.leftover(Abilities.tooltip("polarstrike")), "")
	assert_true(_player().RUNE_INSTANTS.has("polarstrike"), "the player can use it")
	assert_true(Runes.PATHS.has("polarity") and Runes.ALL.has("polarity"), "the rune is registered")
	assert_eq(Runes.rarity("polarity"), Runes.RARE)
	assert_eq(Runes.max_copies("polarity"), 1)
	assert_eq(Runes.spell_of("polarity"), "polarstrike")
	assert_eq(Runes.rune_for_spell("polarstrike"), "polarity")
	var text := Runes.description("polarity")
	assert_contains(text, "Polar Strike")
	assert_eq(TextFill.leftover(text), "", "the rune's text is filled in")
	var pd: Node = track(PlayerDataScript.new())
	pd._ready()
	assert_false(pd.has_ability("polarstrike"), "unknown without the rune")
	pd.equipment["Main Hand"] = "sword|polarity"
	assert_true(pd.has_ability("polarstrike"), "known while the rune is on your gear")

func test_which_of_them_scale() -> void:
	for id in ["twincurrent", "staticstep", "splitsecond", "faradayguard"]:
		assert_false(Abilities.has_scaling(id), "%s has nothing to scale" % id)
	for id in ["chargededge", "arccleave", "overdrive", "backcurrent", "cadence", "whiplash", "reflexarc", "polarstrike"]:
		assert_true(Abilities.has_scaling(id), "%s scales" % id)
