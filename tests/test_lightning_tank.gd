@tool
extends McpTestSuite

# Lightning tank: a parry tank with a two-handed weapon, on the Energy bar.
# Stormbreak gives Energy; Humming Blade raises Parry and its cap and makes
# parries give Energy; a parry opens Return Stroke; Shock Ring and Crossguard
# spend Energy; Draw the Storm pulls enemies in and makes parries zap them.
# (Stormbreak and Humming Blade keep the ids of the shield abilities they were:
# "stormshield" and "thunderaegis".)

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const Stats = preload("res://scripts/core/stats.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")
const CombatSystem = preload("res://scripts/core/combat_system.gd")
const ItemDB = preload("res://scripts/core/item_db.gd")
const Items = preload("res://scripts/items.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")

const KIT := ["stormshield", "thunderaegis", "returnstroke", "shockring", "crossguard", "drawthestorm", "reelin", "recharge"]
const Runes = preload("res://scripts/runes.gd")

## key -> [slot, ranks, values, required ability]
const WANT := {
	"lightning_long_reach": ["lightning_r3c5", 3, [1.0, 2.0, 3.0], ""],   # moved down a row (Talents.MOVED)
	"lightning_counter_charge": ["lightning_r3c7", 3, [10.0, 20.0, 30.0], "returnstroke"],
	"lightning_closed_circuit": ["lightning_r4c5", 3, [2.0, 4.0, 6.0], "thunderaegis"],
	"lightning_quick_wrists": ["lightning_r5c6", 3, [0.3, 0.7, 1.0], "crossguard"],
	"lightning_tempo": ["lightning_r8c5", 3, [2.0, 4.0, 6.0], ""],   # moved down under Earth Return (Talents.LINKS_MOVED)
}

var _saved_records := {}

func suite_name() -> String:
	return "lightning_tank"

func setup() -> void:
	_saved_records = ItemDB.records.duplicate(true)

func teardown() -> void:
	ItemDB.records = _saved_records

func _player() -> GDScript:
	return load("res://scripts/player.gd")

## The ability's data straight from its file (what the game loads when it starts).
func _file(id: String) -> Resource:
	return ResourceLoader.load("res://data/abilities/%s.tres" % id, "", ResourceLoader.CACHE_MODE_IGNORE)

func _typed_number(raw: String) -> String:
	var text := RegEx.create_from_string("\\{[^}]*\\}").sub(raw, "", true)
	var m := RegEx.create_from_string("[0-9]+([.,][0-9]+)?").search(text)
	return m.get_string() if m else ""

func test_the_kit_is_lightning_and_needs_a_two_handed_weapon() -> void:
	for id in KIT:
		var r := _file(id)
		assert_true(r != null, "%s exists" % id)
		assert_eq(str(r.id), id)
		assert_true(bool(r.requires_two_hand), "%s needs a two-handed weapon" % id)
		assert_false(bool(r.requires_shield), "%s needs no shield" % id)
		assert_eq(int(r.weapon_requirement), 1, "%s: a melee weapon" % id)
		assert_eq(Abilities.weapon_need(r), "a two-handed melee weapon")
		assert_eq(int(r.resource_type), 2, "%s runs on Energy" % id)
		assert_eq(int(r.cast_type), 0, "%s is instant" % id)
		assert_true(r.tags.has("Ability") and r.tags.has("Lightning") and not r.tags.has("Spell"), "%s is a Lightning ability" % id)
		assert_false(r.tags.has("Shield"), "%s is not a shield ability any more" % id)
		assert_eq(str(r.damage_type), "lightning")
		assert_true(r.get("on_hit_effect") == null, "%s applies no effect" % id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is draftable and has a card" % id)
		assert_eq(SkillCards.ability_of(id), id)
		assert_true(SkillCards.level_of(id) > 1, "%s: its card has a level" % id)
		assert_eq(Abilities.category_of(id), "lightning")
		assert_false(Abilities.ICON_FORM.has(id), "%s has an icon of its own" % id)
		assert_eq(_typed_number(str(r.description)), "", "%s: number typed into its description" % id)
		var text := Abilities.fill(id, str(r.description), Callable(), {})
		assert_eq(TextFill.leftover(text), "", "%s: every placeholder is filled" % id)
		assert_false(text.contains("?"), "%s: %s" % [id, text])
	assert_eq(str(_file("stormshield").display_name), "Stormbreak")
	assert_eq(str(_file("thunderaegis").display_name), "Humming Blade")
	assert_eq(str(_file("returnstroke").display_name), "Return Stroke")
	assert_eq(str(_file("shockring").display_name), "Shock Ring")
	assert_eq(str(_file("crossguard").display_name), "Crossguard")
	assert_eq(str(_file("drawthestorm").display_name), "Draw the Storm")
	assert_eq(str(_file("reelin").display_name), "Reel In")
	assert_eq(str(_file("recharge").display_name), "Recharge")
	# No two cards share a place in the list.
	var orders := {}
	for id in SkillCards.ALL:
		var order := int(SkillCards.get_resource(id).sort_order)
		if ["returnstroke", "shockring", "crossguard", "drawthestorm", "reelin", "recharge"].has(id):
			assert_false(orders.has(order), "%s: sort order %d is taken" % [id, order])
		orders[order] = id

func test_requirement_text() -> void:
	assert_eq(Abilities.weapon_need(_file("chargededge")), "a melee weapon")
	assert_eq(Abilities.weapon_need(_file("stormarrow")), "a bow")
	assert_eq(Abilities.weapon_need(_file("lightningbolt")), "")
	assert_eq(str(Abilities.basic_weapon("returnstroke").get("name", "")), str(Items.get_item("greatsword")["name"]),
		"tooltips show its damage with a two-handed weapon when none is equipped")

func test_stormbreak() -> void:
	var r := Abilities.get_resource("stormshield")
	assert_eq(float(r.cooldown), 6.0)
	assert_eq(int(r.resource_cost), 0)
	assert_eq(int(r.resource_generated), 25, "gives 25 Energy")
	assert_eq(float(r.weapon_damage_multiplier), 1.0)
	assert_eq(float(r.damage), 0.0)
	assert_eq(float(r.threat_multiplier), 4.0, "high threat")
	assert_eq(Balance.CHAIN_JUMPS, 3, "arcs to 3 enemies")
	assert_eq(float(Balance.EXTRA_HITS["stormshield"]), 0.2)
	assert_true(bool(_file("stormshield").requires_target))
	assert_true(_file("stormshield").tags.has("Melee"))

func test_humming_blade() -> void:
	var r := Abilities.get_resource("thunderaegis")
	assert_eq(float(r.cooldown), 12.0)
	assert_eq(int(r.resource_cost), 0, "no cost")
	assert_eq(float(r.weapon_damage_multiplier), 0.0)
	assert_eq(float(r.damage), 0.0)
	assert_eq(Balance.HUMMING_BLADE_TIME, 15.0)
	assert_eq(Balance.HUMMING_BLADE_PARRY, 10.0)
	assert_eq(Balance.HUMMING_BLADE_PARRY_CAP, 45.0)
	assert_eq(Balance.HUMMING_BLADE_ENERGY, 10.0)
	assert_true(Balance.HUMMING_BLADE_TIME > float(r.cooldown), "it can be kept up")
	var p := _player()
	assert_eq(LightningTankKit.parry_energy(0.0), 10.0)
	assert_eq(LightningTankKit.parry_energy(6.0), 16.0, "Closed Circuit")
	var text := Abilities.fill("thunderaegis", str(_file("thunderaegis").description), Callable(), {})
	assert_contains(text, "increased by 10%")
	assert_contains(text, "45% instead of 30%")
	assert_contains(text, "gives you 10 Energy")

func test_parry_cap() -> void:
	var p := _player()
	assert_eq(LightningTankKit.parry_cap_for(false, false), Stats.MAX_PARRY)
	assert_eq(LightningTankKit.parry_cap_for(true, false), Balance.HUMMING_BLADE_PARRY_CAP)
	assert_eq(LightningTankKit.parry_cap_for(false, true), 100.0, "Crossguard: everything")
	assert_eq(LightningTankKit.parry_cap_for(true, true), 100.0)
	# 40% Parry, a roll of 35: over the usual cap of 30, under Humming Blade's 45.
	var usual: Dictionary = CombatSystem.compute_damage(10.0, 0.0, 0.0, 0.0, 0.0, 99.0, 99.0, true, true, 1.0, 0.5, 0.0, 40.0, 99.0, 35.0)
	assert_false(usual["parried"])
	var humming: Dictionary = CombatSystem.compute_damage(10.0, 0.0, 0.0, 0.0, 0.0, 99.0, 99.0, true, true, 1.0, 0.5, 0.0, 40.0, 99.0, 35.0,
		Balance.HUMMING_BLADE_PARRY_CAP)
	assert_true(humming["parried"])
	assert_eq(humming["amount"], 0)
	assert_false(CombatSystem.compute_damage(10.0, 0.0, 0.0, 0.0, 0.0, 99.0, 99.0, true, true, 1.0, 0.5, 0.0, 80.0, 99.0, 46.0,
		Balance.HUMMING_BLADE_PARRY_CAP)["parried"], "45 is still a cap")
	# The stat panel shows what counts.
	assert_eq(Stats.capped_avoid(Stats.PARRY, 40.0), 30.0)
	assert_eq(Stats.capped_avoid(Stats.PARRY, 40.0, 45.0), 40.0)
	assert_eq(Stats.panel_line(Stats.PARRY, 40.0), "Parry  30%")
	assert_eq(Stats.panel_line(Stats.PARRY, 40.0, {"parry_cap": 45.0}), "Parry  40%")

func test_return_stroke() -> void:
	var r := Abilities.get_resource("returnstroke")
	assert_eq(float(r.cooldown), 0.0, "no cooldown: one use per parry")
	assert_eq(int(r.resource_cost), 15)
	assert_eq(float(r.weapon_damage_multiplier), 1.2)
	assert_eq(float(r.threat_multiplier), 4.0, "high threat")
	assert_true(bool(r.requires_target))
	assert_eq(Balance.RETURN_STROKE_WINDOW, 4.0)
	assert_true(Abilities.OFF_GCD.has("returnstroke"))
	assert_false(_player().on_gcd("returnstroke"), "off the global cooldown")
	assert_true(Abilities.uses_weapon_reach("returnstroke"))
	assert_contains(str(r.description), "{b:RETURN_STROKE_WINDOW}")

func test_shock_ring() -> void:
	var r := Abilities.get_resource("shockring")
	assert_eq(float(r.cooldown), 8.0)
	assert_eq(int(r.resource_cost), 30)
	assert_eq(float(r.damage), 0.5)
	assert_eq(float(r.radius), 6.0)
	assert_eq(float(r.threat_multiplier), 4.0, "high threat")
	assert_false(bool(r.requires_target), "it goes out around you")
	assert_true(r.tags.has("AoE"))
	assert_true(_player().on_gcd("shockring"))

func test_crossguard() -> void:
	var r := Abilities.get_resource("crossguard")
	assert_eq(float(r.cooldown), 25.0)
	assert_eq(int(r.resource_cost), 40)
	assert_eq(Balance.CROSSGUARD_TIME, 3.0)
	assert_false(Abilities.has_scaling("crossguard"), "nothing to scale")
	# +100% Parry with all of it counting: every roll is a parry.
	var hit: Dictionary = CombatSystem.compute_damage(10.0, 0.0, 0.0, 0.0, 0.0, 99.0, 99.0, true, true, 1.0, 0.5, 0.0, 100.0, 99.0, 99.9,
		LightningTankKit.parry_cap_for(false, true))
	assert_true(hit["parried"])
	assert_eq(hit["amount"], 0)
	# What cannot be parried (damage over time) still lands.
	var dot: Dictionary = CombatSystem.compute_damage(10.0, 0.0, 0.0, 0.0, 0.0, 99.0, 99.0, true, false, 1.0, 0.5, 0.0, 100.0, 99.0, 1.0, 100.0)
	assert_false(dot["parried"])
	assert_eq(dot["amount"], 10)

func test_draw_the_storm() -> void:
	var r := Abilities.get_resource("drawthestorm")
	assert_eq(float(r.cooldown), 90.0)
	assert_eq(int(r.resource_cost), 0)
	assert_eq(float(r.radius), 8.0, "pulls enemies within 8 m")
	assert_eq(Balance.DRAW_THE_STORM_TIME, 8.0)
	assert_eq(Balance.DRAW_THE_STORM_TAUNT, 3.0)
	assert_eq(Balance.DRAW_THE_STORM_ZAP_RADIUS, 6.0)
	assert_eq(float(Balance.EXTRA_HITS["drawthestorm"]), 0.3, "the zap")
	assert_true(Abilities.has_scaling("drawthestorm"), "its zap scales")

func test_reel_in() -> void:
	var r := Abilities.get_resource("reelin")
	assert_eq(float(r.cooldown), 12.0)
	assert_eq(int(r.resource_cost), 20)
	assert_eq(float(r.cast_range), 25.0)
	assert_true(bool(r.requires_target))
	assert_eq(Balance.REEL_IN_TAUNT, 3.0)
	assert_true(Abilities.LONG_REACH.has("reelin"))
	assert_false(Abilities.uses_weapon_reach("reelin"), "from 25 m, not from weapon reach")
	assert_false(Abilities.has_scaling("reelin"), "it deals no damage")
	assert_contains(Abilities.fill("reelin", str(_file("reelin").description), Callable(), {}), "up to 25 m away")
	# It lands `gap` metres from me, on the line between us.
	var p := _player()
	var at: Vector3 = LightningTankKit.reel_in_point(Vector3.ZERO, Vector3(20, 0, 0), 1.5)
	assert_true(at.distance_to(Vector3(1.5, 0, 0)) < 0.001, "dragged to 1.5 m in front of me: %s" % at)
	var diagonal: Vector3 = LightningTankKit.reel_in_point(Vector3(2, 0, 2), Vector3(5, 3, 6), 1.0)
	assert_true(absf(Vector2(diagonal.x - 2.0, diagonal.z - 2.0).length() - 1.0) < 0.001, "1 m away, measured on the ground")
	assert_eq(LightningTankKit.reel_in_point(Vector3.ZERO, Vector3(1, 0, 0), 1.5), Vector3(1, 0, 0), "already next to me: it stays put")
	# Enemies can be dragged; the host does it for party members.
	var enemy: GDScript = load("res://scripts/enemy.gd")
	var has_pull := false
	for m in enemy.get_script_method_list():
		has_pull = has_pull or str(m["name"]) == "pull_to"
	assert_true(has_pull, "enemies can be dragged")
	var net: GDScript = load("res://scripts/net/net.gd")
	var net_methods := []
	for m in net.get_script_method_list():
		net_methods.append(str(m["name"]))
	assert_true(net_methods.has("pull") and net_methods.has("_sup_pull"), "the pull goes through the host")

func test_recharge() -> void:
	var r := Abilities.get_resource("recharge")
	assert_eq(float(r.cooldown), 30.0)
	assert_eq(int(r.resource_cost), 0, "it spends all of it instead")
	assert_true(Abilities.SPENDS_ALL.has("recharge"))
	assert_eq(Balance.RECHARGE_PCT_PER_STEP, 1.5)
	assert_false(Abilities.has_scaling("recharge"), "a share of max health: nothing to scale")
	var p := _player()
	assert_eq(LightningTankKit.recharge_heal(1000, 100.0), 150, "15% of max health at a full bar")
	assert_eq(LightningTankKit.recharge_heal(1000, 10.0), 15, "1.5% per 10 Energy")
	assert_eq(LightningTankKit.recharge_heal(1000, 0.0), 0)
	assert_eq(LightningTankKit.recharge_heal(2550, 60.0), 230, "9% of 2550, rounded")
	var text := Abilities.fill("recharge", str(_file("recharge").description), Callable(), {})
	assert_contains(text, "1.5% of your maximum health per 10 Energy")
	assert_contains(text, "up to 15%")
	assert_contains(Abilities.tooltip("recharge"), "All Energy")

## Rune of Resonance (Rare): Return Stroke without a parry, for more Energy and a short cooldown.
func test_rune_of_resonance() -> void:
	assert_true(Runes.PATHS.has("resonance") and Runes.ALL.has("resonance"), "registered")
	assert_eq(Runes.rarity("resonance"), Runes.RARE)
	assert_eq(Runes.max_copies("resonance"), 1, "unique")
	assert_eq(Runes.rune_name("resonance"), "Rune of Resonance")
	assert_eq(Balance.RESONANCE_COST, 40.0)
	assert_eq(Balance.RESONANCE_COOLDOWN, 3.0)
	var p := _player()
	assert_eq(LightningTankKit.RESONANCE_RUNE, "resonance")
	# After a parry it is Return Stroke as always, rune or not.
	assert_eq(LightningTankKit.return_stroke_cost(15.0, true, true), 15.0, "with a parry it costs no more")
	assert_eq(LightningTankKit.return_stroke_cost(15.0, true, false), 15.0)
	assert_eq(LightningTankKit.return_stroke_cost(15.0, false, true), 40.0, "without one: 40 Energy")
	assert_true(LightningTankKit.return_stroke_usable(true, false))
	assert_true(LightningTankKit.return_stroke_usable(false, true), "the rune lets it be used without a parry")
	assert_false(LightningTankKit.return_stroke_usable(false, false), "no parry, no rune: not usable")
	var text := Runes.description("resonance")
	assert_eq(TextFill.leftover(text), "", "the rune's text is filled in")
	assert_false(text.contains("?"), text)
	assert_contains(text, Abilities.ability_name("returnstroke"))
	assert_contains(text, "40 Energy")
	assert_contains(text, "3 sec cooldown")
	var raw: Resource = ResourceLoader.load("res://data/runes/resonance.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_eq(_typed_number(str(raw.description)), "", "no number typed into its text")

## Tempo: every parry makes auto-attacks faster (attack speed, not Haste).
func test_tempo() -> void:
	assert_eq(Balance.TEMPO_TIME, 5.0)
	assert_eq(Balance.TEMPO_MAX_STACKS, 3)
	var p := _player()
	assert_true(is_equal_approx(LightningMeleeKit.auto_interval(1.6, 1.0, false, 0.0), 1.6))
	assert_true(is_equal_approx(LightningMeleeKit.auto_interval(1.6, 1.0, false), 1.6), "nothing without the talent")
	assert_true(is_equal_approx(LightningMeleeKit.auto_interval(1.6, 1.0, false, 18.0), 1.6 / 1.18), "three stacks at rank 3: 18% faster swings")
	assert_true(is_equal_approx(LightningMeleeKit.auto_interval(1.6, 1.25, false, 6.0), 1.6 / 1.25 / 1.06), "on top of Haste")
	assert_true(is_equal_approx(LightningMeleeKit.auto_interval(1.6, 1.0, true, 6.0), 1.6 / 1.4 / 1.06), "and of Overdrive")
	var text := Talents.description(Talents.id_for_key("lightning_tempo"))
	assert_contains(text, "attack speed by 2 / 4 / 6%")
	assert_contains(text, "for 5 sec")
	assert_contains(text, "up to 3 times")

## Reflex Arc's avoided attack counts as a parry AND a block, so everything that
## reacts to either (Return Stroke, Humming Blade, Cinder Guard...) reacts to it.
func test_reflex_arc_counts_as_a_parry_and_a_block() -> void:
	const DamageInfo = preload("res://scripts/core/damage_info.gd")
	var info := DamageInfo.make(null, null, 1.0, "enemy_melee")
	assert_false(info.force_parry_block, "an ordinary hit is not marked")
	info.dodged = true   # (even if the roll said dodge: Reflex Arc takes it)
	info.amount = 40
	CombatSystem.force_avoid(info)
	assert_true(info.parried, "a parry")
	assert_true(info.blocked, "and a block")
	assert_false(info.dodged)
	assert_eq(int(info.amount), 0)
	assert_true(info.avoided())
	assert_eq(info.avoid_kind(), "parry", "shown as a parry")
	var text := str(_file("reflexarc").description)
	assert_contains(text, "both a parry and a block")
	assert_eq(_typed_number(text), "")

# --- Talents -------------------------------------------------------------------------

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
		for text in [Talents.tooltip(id, 1), Talents.capstone_text(id)]:
			assert_eq(TextFill.leftover(text), "", "%s: every placeholder is filled" % key)
			assert_false(text.contains("?"), "%s: %s" % [key, text])

func test_talent_texts() -> void:
	var d := func(key: String) -> String: return Talents.description(Talents.id_for_key(key))
	assert_contains(d.call("lightning_long_reach"), "by 1 / 2 / 3%")
	assert_contains(d.call("lightning_long_reach"), "two-handed weapon")
	assert_contains(d.call("lightning_counter_charge"), "10 / 20 / 30% more damage")
	assert_contains(d.call("lightning_closed_circuit"), "2 / 4 / 6 more Energy")
	assert_contains(d.call("lightning_quick_wrists"), "0.3 / 0.7 / 1 sec")
	var counter := Talents.id_for_key("lightning_counter_charge")
	assert_true(Talents.has_capstone(counter), "Counter-Charge has a capstone")
	assert_contains(Talents.capstone_text(counter), "up to %d nearby enemies" % Balance.COUNTER_CHARGE_JUMPS)
	assert_false(Talents.capstone_text(counter).contains("Frost Bolts"), "a real damage number")
	assert_eq(Balance.COUNTER_CHARGE_JUMPS, 2)
	assert_eq(Balance.COUNTER_CHARGE_ARC, 0.3)
	assert_contains(Talents.tooltip(counter, 0), "Requires %s to be learned" % Abilities.ability_name("returnstroke"))
	assert_false(Talents.tooltip(Talents.id_for_key("lightning_long_reach"), 0).contains("Requires"), "Long Reach needs no ability")

func test_quick_wrists() -> void:
	var p := _player()
	assert_eq(LightningTankKit.quick_wrists_cooldown(10.0, 1.0), 9.0)
	assert_eq(LightningTankKit.quick_wrists_cooldown(10.0, 0.5), 9.5)
	assert_eq(LightningTankKit.quick_wrists_cooldown(0.4, 1.0), 0.0, "never below zero")
	assert_eq(LightningTankKit.quick_wrists_cooldown(5.0, 0.0), 5.0)

## A talent of one ability does nothing until that ability is learned.
func test_ability_talents_need_their_ability() -> void:
	var pd = PlayerDataScript.new()
	pd.level = 50
	pd.learned_abilities.clear()
	pd.talents = {Talents.id_for_key("lightning_closed_circuit"): 3, Talents.id_for_key("lightning_quick_wrists"): 3,
		Talents.id_for_key("lightning_counter_charge"): 3}
	assert_eq(pd.talent_value("lightning_closed_circuit"), 0.0, "Humming Blade is not learned")
	assert_eq(pd.talent_value("lightning_quick_wrists"), 0.0, "Crossguard is not learned")
	assert_false(pd.talent_capstone("lightning_counter_charge"), "Return Stroke is not learned")
	pd.learned_abilities.append("thunderaegis")
	pd.learned_abilities.append("crossguard")
	pd.learned_abilities.append("returnstroke")
	assert_eq(pd.talent_value("lightning_closed_circuit"), 6.0)
	assert_eq(pd.talent_value("lightning_quick_wrists"), 1.0)
	assert_eq(pd.talent_value("lightning_counter_charge"), 30.0)
	assert_true(pd.talent_capstone("lightning_counter_charge"), "maxed: the capstone is on")
	pd.free()

## Long Reach: Parry only while a two-handed weapon is in the Main Hand.
func test_long_reach() -> void:
	var pd: Node = track(PlayerDataScript.new())
	pd._ready()
	pd.level = 50
	pd.equipment["Main Hand"] = ItemDB.create("greatsword", "", 10)
	pd._invalidate_stats()
	assert_true(pd.has_two_hander())
	var before := Stats.from_totals(Stats.PARRY, pd.total_stats())
	pd.talents = {Talents.id_for_key("lightning_long_reach"): 3}
	pd._invalidate_stats()
	assert_true(absf(Stats.from_totals(Stats.PARRY, pd.total_stats()) - before - 3.0) < 0.001, "+3% Parry with a two-hander")
	pd.equipment["Main Hand"] = ItemDB.create("sword", "", 10)
	pd._invalidate_stats()
	assert_false(pd.has_two_hander())
	assert_eq(Stats.from_totals(Stats.PARRY, pd.total_stats()), 0.0, "nothing with a one-handed sword")
	pd.equipment["Main Hand"] = ""
	pd._invalidate_stats()
	assert_false(pd.has_two_hander(), "an empty hand is not a two-hander")

# --- The two-handed weapon ----------------------------------------------------------------

func test_greatsword() -> void:
	assert_true(Items.ALL.has("greatsword") and Items.PATHS.has("greatsword"))
	var d := Items.get_item("greatsword")
	assert_eq(str(d.get("weapon", "")), "melee")
	assert_true(bool(d.get("locks_offhand", false)), "two-handed")
	assert_eq(str(d.get("slot", "")), "Main Hand")
	assert_true(float(d.get("damage", 0.0)) > float(Items.get_item("sword").get("damage", 0.0)), "hits harder than a one-handed sword")
	assert_true(float(d["stats"].get(Stats.STRENGTH, 0.0)) > 0.0, "a Strength weapon")
	assert_true(bool(Items.get_item("staff").get("locks_offhand", false)), "the staff is two-handed too")

func test_it_drops() -> void:
	for table in ["zombie", "elite", "boss"]:
		var t: Resource = ResourceLoader.load("res://data/loot/%s.tres" % table, "", ResourceLoader.CACHE_MODE_IGNORE)
		var ids := []
		for e in t.get("pool"):
			ids.append(str(e.get("item_id")))
		assert_true(ids.has("greatsword"), "%s can drop a greatsword" % table)
		assert_true(ids.has("staff") and ids.has("shield"), "%s: the rest of the pool is still there" % table)

## Every character gets each starter weapon once: an existing character that
## already has the first three is given only the ones added since (the
## greatsword, and the dagger of the Arcane tank).
func test_existing_characters_get_a_greatsword() -> void:
	var pd: Node = track(PlayerDataScript.new())
	pd._ready()
	assert_true(pd.STARTER_WEAPONS.has("greatsword"))
	pd.starter_weapons_have = pd.STARTER_WEAPONS_V1.duplicate()
	pd.give_starter_weapons()
	var given := []
	for item in pd.bank:
		if str(item) != "":
			given.append(Items.base_id(str(item)))
	assert_eq(given, ["greatsword", "dagger"])
	assert_true(pd.starter_weapons_given)
	pd.give_starter_weapons()
	assert_eq(pd.bank.filter(func(i): return str(i) != "").size(), 2, "only once")
	# A new character gets all of them.
	var fresh: Node = track(PlayerDataScript.new())
	fresh._ready()
	fresh.give_starter_weapons()
	assert_eq(fresh.bank.filter(func(i): return str(i) != "").size(), pd.STARTER_WEAPONS.size())
