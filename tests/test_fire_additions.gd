@tool
extends McpTestSuite

# Fire, third batch: the bow abilities (Pitch Arrow, Cinder Rain), the phoenix
# healing cooldown (Cinderwing) and six talents (Forge Heat, Long Burn, Deep
# Crucible, Stoked Kiln, Slag Mending, Furnace Heart).

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const StatusContainer = preload("res://scripts/core/status_container.gd")
const StatusEffectScript = preload("res://scripts/data/status_effect_data.gd")

const NEW := ["pitcharrow", "cinderrain", "cinderwing"]

func suite_name() -> String:
	return "fire_additions"

func _player() -> GDScript:
	return load("res://scripts/player.gd")

func _status() -> Node:
	var owner_node: Node = track(Node.new())
	var st: Node = StatusContainer.new()
	st.name = "Status"
	owner_node.add_child(st)
	return st

func test_new_abilities_are_registered() -> void:
	for id in NEW:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s loads" % id)
		if r == null:
			continue
		assert_eq(str(r.id), id)
		assert_eq(Abilities.category_of(id), "fire", "%s is in the Fire book" % id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is draftable and has a card" % id)
		assert_eq(SkillCards.ability_of(id), id)
		assert_true(SkillCards.level_of(id) > 1, "%s's card has a level" % id)
		assert_eq(int(r.cast_type), 0, "%s is instant" % id)
		assert_false(Abilities.tooltip(id).contains("{"), "%s: every number in the description is filled in" % id)

func test_bow_abilities_need_a_bow() -> void:
	for id in ["pitcharrow", "cinderrain"]:
		var r := Abilities.get_resource(id)
		assert_eq(int(r.weapon_requirement), 2, "%s needs a bow" % id)
		assert_true(r.tags.has("Ability") and r.tags.has("Fire") and r.tags.has("Ranged"), "%s is a Fire bow ability" % id)
		assert_eq(str(r.damage_type), "fire")
		assert_eq(Abilities.resource_of(id), "energy")
	assert_true(bool(Abilities.get_resource("pitcharrow").requires_target))
	assert_false(bool(Abilities.get_resource("cinderrain").requires_target), "placed on the ground")

func test_pitch_is_one_per_archer_and_speeds_up_their_burns() -> void:
	var fx: Resource = Abilities.get_resource("pitcharrow").on_hit_effect
	assert_true(fx != null, "Pitch Arrow leaves pitch on the target")
	assert_eq(str(fx.id), "pitched")
	assert_eq(float(fx.get("duration")), 12.0)
	assert_true(bool(fx.get("per_caster")), "each archer has their own pitch (own only)")
	var p := _player()
	assert_eq(Balance.PITCH_TICK_SPEED_PCT, 25.0)
	assert_eq(FireBowKit.pitch_speed("burning", true), 1.25)
	assert_eq(FireBowKit.pitch_speed("immolate", true), 1.25)
	assert_eq(FireBowKit.pitch_speed("hoarfrost", true), 1.0, "only Burning and Immolate")
	assert_eq(FireBowKit.pitch_speed("burning", false), 1.0, "no pitch of mine on it: normal speed")

## The container side: a caster that speeds up its burns gets shorter ticks; nobody else does.
func test_only_the_archers_own_burns_tick_faster() -> void:
	var archer: Node = track(Node.new())
	var fast := GDScript.new()
	fast.source_code = "@tool\nextends Node\nfunc dot_speed_mult(_target: Node, _res: Resource) -> float:\n\treturn 1.25\n"
	fast.reload()
	archer.set_script(fast)
	var ally: Node = track(Node.new())
	var st := _status()
	var burn: Resource = StatusEffectScript.new()
	burn.id = &"burning"
	burn.duration = 4.0
	burn.tick_damage = 0.1
	burn.tick_interval = 1.0
	burn.dot_hasted = false
	st.apply(burn, archer)
	st.apply(burn, ally)
	var mine: Dictionary = st.effects[StatusContainer.key_for(burn, archer)]
	var theirs: Dictionary = st.effects[StatusContainer.key_for(burn, ally)]
	assert_true(absf(st.tick_interval_of(mine) - 0.8) < 0.0001, "1 s / 1.25 = 0.8 s between my ticks")
	assert_eq(st.tick_interval_of(theirs), 1.0, "an ally's Burning on the same target is untouched")
	assert_true(absf(st.dot_left("burning", archer) - 0.5) < 0.001, "5 ticks fit in the 4 s instead of 4, got %s" % st.dot_left("burning", archer))
	assert_true(absf(st.dot_left("burning", ally) - 0.4) < 0.001)

func test_cinder_rain() -> void:
	var Rain: GDScript = load("res://scripts/cinder_rain.gd")
	assert_eq(Balance.CINDER_RAIN_TIME, 4.0, "4 s")
	assert_eq(Rain.tick_count(Balance.CINDER_RAIN_TIME, Balance.CINDER_RAIN_TICK), 8, "8 ticks without Haste")
	assert_eq(Rain.tick_count(4.0, 0.4), 10, "Haste: more ticks in the same 4 s")
	var c := Vector3(5, 0, 5)
	assert_true(Rain.inside(c, 4.0, Vector3(8.9, 2.0, 5)), "inside (height doesn't matter)")
	assert_false(Rain.inside(c, 4.0, Vector3(9.5, 0, 5)), "outside")
	assert_true(Rain.inside(c, 4.0, Vector3(9.5, 0, 5), 0.6), "a big enemy overlapping the edge counts")
	var r := Abilities.get_resource("cinderrain")
	assert_true(float(r.radius) > 0.0 and float(r.weapon_damage_multiplier) > 0.0)
	assert_true(r.tags.has("AoE"))
	assert_eq(Balance.aoe_share(8), 5.0 / 8.0, "8 enemies inside share 5 enemies' damage")

func test_phoenix() -> void:
	var Phoenix: GDScript = load("res://scripts/phoenix.gd")
	var r := Abilities.get_resource("cinderwing")
	assert_eq(float(r.cooldown), 60.0, "1 minute cooldown")
	assert_true(r.tags.has("Spell") and r.tags.has("Heal") and r.tags.has("Fire"))
	assert_false(bool(r.requires_target))
	assert_eq(Balance.PHOENIX_CASTS, 15)
	assert_eq(Balance.PHOENIX_INTERVAL, 1.1)
	assert_true(absf(float(Phoenix.life_time(Balance.PHOENIX_CASTS, Balance.PHOENIX_INTERVAL)) - 16.5) < 0.0001, "15 casts x 1.1 s")
	assert_true(float(Abilities.HEALS.get("cinderwing", 0.0)) > 0.0, "each cast heals")
	assert_true(Balance.PHOENIX_RANGE > 0.0)
	var p := _player()
	assert_eq(FireCooldownsKit.lowest_share([1.0, 0.4, 0.7]), 1, "the ally with the least health left")
	assert_eq(FireCooldownsKit.lowest_share([0.5, 0.5]), 0, "a tie: the first (you)")
	assert_eq(FireCooldownsKit.lowest_share([]), -1, "nobody in range")

func test_new_talents() -> void:
	var want := {
		"fire_forge_heat": ["fire_r7c2", [0.5, 1.0, 1.5, 2.0]],
		"fire_long_burn": ["fire_r5c3", [1.0, 2.0, 3.0]],   # moved up under Lingering Embers (Talents.LINKS_MOVED)
		"fire_deep_crucible": ["fire_r8c4", [0.7, 1.3, 2.0]],
		"fire_stoked_kiln": ["fire_r8c5", [7.0, 13.0, 20.0]],
		"fire_slag_mending": ["fire_r7c6", [0.7, 1.3, 2.0]],
		"fire_deep_brand": ["fire_r3c7", [2.0, 4.0, 6.0]],
		"fire_banked_mana": ["fire_r1c5", [5.0, 10.0]],
		"fire_warm_blood": ["fire_r4c4", [2.0, 4.0, 6.0]],
		"fire_white_heat": ["fire_r9c2", [5.0, 10.0, 15.0]],
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
	var crucible := Talents.id_for_key("fire_deep_crucible")
	assert_eq(Talents.value_at(crucible, 1, "values2"), 1.5, "+1.5 s")
	assert_eq(Talents.value_at(crucible, 3, "values2"), 4.0, "+4 s")

func test_talent_maths() -> void:
	var p := _player()
	# Forge Heat: the buff simply lasts longer.
	assert_eq(float(FireMeleeKit.make_heat_fx().duration), Balance.HEAT_TIME)
	assert_eq(float(FireMeleeKit.make_heat_fx(Balance.HEAT_TIME + 2.0).duration), 5.0, "4 / 4: 3 s + 2 s")
	# Long Burn raises what Fresh Tinder can fill up to.
	assert_eq(FireMeleeKit.tinder_time(14.0, 2.0, 12.0 + 3.0), 15.0)
	# Stoked Kiln: 20% -> 27 / 33 / 40%.
	var kiln := Talents.id_for_key("fire_stoked_kiln")
	assert_eq(Balance.KILN_BLAST_IMMOLATE_PCT + Talents.value_at(kiln, 1), 27.0)
	assert_eq(Balance.KILN_BLAST_IMMOLATE_PCT + Talents.value_at(kiln, 3), 40.0)
	# Deep Brand: 10% -> 12 / 14 / 16% less damage from the enemy I Branded.
	var brand := Talents.id_for_key("fire_deep_brand")
	assert_eq(Balance.BRAND_PCT + Talents.value_at(brand, 1), 12.0)
	assert_eq(Balance.BRAND_PCT + Talents.value_at(brand, 3), 16.0)
	assert_eq(str(Talents.get_talent(brand).get("requires", "")), "brand")
	# Pitch Arrow's pitch lasts as long as its cooldown (Thick Pitch was folded into it): it can be kept up.
	assert_eq(float(Abilities.get_resource("pitcharrow").on_hit_effect.get("duration")), float(Abilities.get_resource("pitcharrow").cooldown))
	assert_eq(Talents.id_for_key("fire_thick_pitch"), "", "Thick Pitch is gone")
	# Banked Mana: part of the mana cost comes back.
	assert_eq(FireCasterKit.banked_mana_refund(200.0, 5.0), 10.0)
	assert_eq(FireCasterKit.banked_mana_refund(200.0, 10.0), 20.0)
	assert_eq(FireCasterKit.banked_mana_refund(0.0, 10.0), 0.0, "a free cast gives nothing back")
	assert_eq(Abilities.resource_of("fireball"), "mana", "Firebolt costs mana: it can refund")
	assert_ne(Abilities.resource_of("searingstrike"), "mana", "abilities don't")
	# Warm Blood counts my burns: the same ones Rekindle refreshes.
	assert_true(Balance.REKINDLE_EFFECTS.has("burning") and Balance.REKINDLE_EFFECTS.has("immolate"))
	# White Heat: only at the maximum Heat, and no Fire slot is left empty.
	assert_eq(FireMeleeKit.white_heat_bonus(Balance.HEAT_MAX_STACKS, 15.0), 15.0)
	assert_eq(FireMeleeKit.white_heat_bonus(Balance.HEAT_MAX_STACKS - 1, 15.0), 0.0, "one stack short: nothing")
	assert_eq(FireMeleeKit.white_heat_bonus(0, 15.0), 0.0)
	assert_eq(FireMeleeKit.white_heat_bonus(Balance.HEAT_MAX_STACKS, 0.0), 0.0, "nothing without the talent")
	assert_contains(Talents.description(Talents.id_for_key("fire_white_heat")), "maximum %d Heat" % Balance.HEAT_MAX_STACKS)
	for id in Talents.in_tree("fire"):
		assert_false(bool(Talents.get_talent(id).get("placeholder", true)) and not Talents.FOLDED_INTO_ABILITIES.has(id), "%s: every Fire slot holds a talent, or was folded" % id)
	# Slag Mending: % of max health per stack.
	assert_eq(FireCooldownsKit.slag_mending_heal(1000, 6, 2.0), 120)
	assert_eq(FireCooldownsKit.slag_mending_heal(1000, 3, 1.0), 30)
	assert_eq(FireCooldownsKit.slag_mending_heal(1000, 6, 0.0), 0, "nothing without the talent")
	# Cinder Guard costs 20 Fury (Furnace Heart was folded into it).
	assert_eq(float(Abilities.get_resource("cinderguard").resource_cost), 20.0)
