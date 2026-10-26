@tool
extends McpTestSuite

# Fire melee: Heat (built by melee hits on a target with your own Immolate),
# Searing Strike as its builder, Quench and Flare as its spenders, and the
# Kindling / Fresh Tinder / Afterglow talents.

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const StatusContainer = preload("res://scripts/core/status_container.gd")
const StatusEffectScript = preload("res://scripts/data/status_effect_data.gd")
const DamageInfo = preload("res://scripts/core/damage_info.gd")
const Details = preload("res://scripts/core/details.gd")

func suite_name() -> String:
	return "fire_melee"

func _player() -> GDScript:
	return load("res://scripts/player.gd")

func _status() -> Node:
	var owner_node: Node = track(Node.new())
	var st: Node = StatusContainer.new()
	st.name = "Status"
	owner_node.add_child(st)
	return st

func _hit(type: String, tags: Array, dot := false) -> RefCounted:
	var info := DamageInfo.make(null, null, 3, "test")
	info.damage_type = type
	info.tags = PackedStringArray(tags)
	info.is_dot = dot
	return info

func test_spenders_are_registered() -> void:
	for id in ["quench", "flare"]:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s loads" % id)
		if r == null:
			continue
		assert_eq(str(r.id), id)
		assert_eq(Abilities.category_of(id), "fire", "%s is in the Fire book" % id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is draftable and has a card" % id)
		assert_eq(SkillCards.ability_of(id), id)
		assert_true(SkillCards.level_of(id) > 1, "%s's card has a level" % id)
		assert_eq(int(r.weapon_requirement), 1, "%s needs a melee weapon" % id)
		assert_true(r.tags.has("Ability") and r.tags.has("Fire") and r.tags.has("Melee"), "%s is a Fire melee ability" % id)
		assert_eq(str(r.damage_type), "fire")
		assert_eq(int(r.cast_type), 0, "instant")
		assert_eq(int(r.resource_cost), 0, "%s runs on Heat, not on a resource bar" % id)
		assert_eq(float(r.weapon_damage_multiplier), 1.0)
	assert_true(Abilities.get_resource("flare").tags.has("AoE"))
	assert_true(float(Abilities.get_resource("flare").radius) > 0.0)
	for id in ["quench", "flare", "searingstrike", "immolate"]:
		assert_false(Abilities.tooltip(id).contains("{"), "%s: every number in the description is filled in" % id)
	assert_contains(Abilities.tooltip("immolate"), "Heat", "Immolate explains what it starts")

func test_heat_numbers() -> void:
	assert_eq(Balance.HEAT_DAMAGE_PCT, 4.0, "+4% per stack")
	assert_eq(Balance.HEAT_MAX_STACKS, 10)
	assert_eq(Balance.HEAT_TIME, 3.0, "lost after 3 s without a new stack")
	assert_eq(Balance.SEARING_STRIKE_HEAT, 2)
	assert_eq(Balance.QUENCH_MIN_HEAT, 3)
	assert_eq(Balance.QUENCH_PCT_PER_HEAT, 25.0)
	assert_eq(Balance.FLARE_HEAT_COST, 3)

func test_what_builds_and_spends_heat() -> void:
	var p := _player()
	assert_eq(FireMeleeKit.heat_from("auto_melee"), 1, "an auto-attack builds 1")
	assert_eq(FireMeleeKit.heat_from("froststrike"), 1, "any melee ability builds 1")
	assert_eq(FireMeleeKit.heat_from("searingstrike"), 2, "Searing Strike builds 2")
	assert_eq(FireMeleeKit.heat_from("quench"), 0, "the spenders build none")
	assert_eq(FireMeleeKit.heat_from("flare"), 0)
	assert_eq(FireMeleeKit.heat_needed("quench"), 3)
	assert_eq(FireMeleeKit.heat_needed("flare"), 3)
	assert_eq(FireMeleeKit.heat_needed("searingstrike"), 0)
	assert_true(Abilities.tags_of("searingstrike").has("Melee") and Abilities.tags_of("auto_melee").has("Melee"),
		"Heat comes from hits tagged Melee")
	assert_false(Abilities.tags_of("immolate").has("Melee"))

func test_quench_damage() -> void:
	var p := _player()
	assert_eq(FireMeleeKit.quench_coef(1.0, 0), 1.0)
	assert_true(absf(float(FireMeleeKit.quench_coef(1.0, 3)) - 1.75) < 0.0001, "3 Heat: +75%")
	assert_true(absf(float(FireMeleeKit.quench_coef(1.0, 10)) - 3.5) < 0.0001, "10 Heat: 3.5x")
	assert_true(absf(float(FireMeleeKit.quench_coef(2.0, 10)) - 7.0) < 0.0001, "it multiplies the weapon hit")

## The buff: +4% per stack, only on Fire damage dealt by abilities.
func test_heat_boosts_fire_abilities_only() -> void:
	var st := _status()
	var fx: Resource = FireMeleeKit.make_heat_fx()
	assert_eq(str(fx.id), "heat")
	assert_false(bool(fx.is_debuff), "a buff on you")
	assert_false(bool(fx.consume_on_use), "hits don't use it up")
	assert_false(bool(fx.mod_crit_only) or bool(fx.mod_non_crit_only), "crits play no part")
	for i in 3:
		st.apply(fx)
	assert_eq(st.stacks_of("heat"), 3)
	var ability := _hit("fire", ["Ability", "Fire", "Melee"])
	st.collect_damage_mods(ability, false)
	assert_true(absf(ability.bonus_pct - 12.0) < 0.001, "3 stacks x 4%% = +12, got %s" % ability.bonus_pct)
	var crit := _hit("fire", ["Ability", "Fire", "Melee"])
	crit.crit = true
	st.collect_damage_mods(crit, false)
	assert_true(absf(crit.bonus_pct - 12.0) < 0.001, "a crit gets the same bonus")
	var spell := _hit("fire", ["Fire", "Spell"])
	st.collect_damage_mods(spell, false)
	assert_eq(spell.bonus_pct, 0.0, "not spells")
	var frost := _hit("frost", ["Ability", "Frost", "Melee"])
	st.collect_damage_mods(frost, false)
	assert_eq(frost.bonus_pct, 0.0, "only Fire damage")
	var auto := _hit("physical", ["Physical", "Melee", "AutoAttack"])
	st.collect_damage_mods(auto, false)
	assert_eq(auto.bonus_pct, 0.0, "auto-attacks aren't abilities")
	var burn := _hit("fire", ["Ability", "Fire", "Melee", "DoT"], true)
	st.collect_damage_mods(burn, false)
	assert_true(absf(burn.bonus_pct - 12.0) < 0.001, "an ability's burn (Searing Strike's Burning) counts")
	var immolate_tick := _hit("fire", ["Fire", "Spell", "Projectile", "DoT"], true)
	st.collect_damage_mods(immolate_tick, false)
	assert_eq(immolate_tick.bonus_pct, 0.0, "Immolate is a spell")
	st._flush_consumed()
	assert_eq(st.stacks_of("heat"), 3, "still there after the hits")

func test_heat_caps_and_every_stack_restarts_the_timer() -> void:
	var st := _status()
	var fx: Resource = FireMeleeKit.make_heat_fx()
	for i in Balance.HEAT_MAX_STACKS + 4:
		st.apply(fx)
	assert_eq(st.stacks_of("heat"), Balance.HEAT_MAX_STACKS, "capped")
	st.set_remaining("heat", 0.5)
	st.apply(fx)
	var left: float = st.remaining_of("heat")
	assert_true(left > Balance.HEAT_TIME - 0.2 and left <= Balance.HEAT_TIME + 0.001, "a hit at the cap still restarts the %s s" % Balance.HEAT_TIME)

func test_flare_spends_three_and_quench_takes_it_all() -> void:
	var st := _status()
	var fx: Resource = FireMeleeKit.make_heat_fx()
	for i in 7:
		st.apply(fx)
	st.set_remaining("heat", 1.5)
	st.spend_stacks("heat", Balance.FLARE_HEAT_COST)
	assert_eq(st.stacks_of("heat"), 4, "Flare costs 3")
	assert_true(st.remaining_of("heat") <= 1.501, "spending Heat doesn't restart its timer")
	st.spend_stacks("heat", Balance.FLARE_HEAT_COST)
	assert_eq(st.stacks_of("heat"), 1)
	st.remove("heat")
	assert_false(st.has("heat"), "Quench removes all of it")

func test_fresh_tinder_never_passes_the_base_duration() -> void:
	var p := _player()
	assert_eq(FireMeleeKit.tinder_time(5.0, 1.0, 12.0), 6.0)
	assert_eq(FireMeleeKit.tinder_time(5.0, 2.0, 12.0), 7.0)
	assert_eq(FireMeleeKit.tinder_time(11.5, 2.0, 12.0), 12.0, "capped at the base duration")
	assert_eq(FireMeleeKit.tinder_time(12.0, 1.0, 12.0), 12.0)
	assert_eq(FireMeleeKit.tinder_time(13.0, 1.0, 12.0), 13.0, "never shortens a longer one")
	assert_eq(Balance.FRESH_TINDER_SECONDS, 1.0)

## Only my own Immolate is fed, and its tick timer is left alone.
func test_feeding_only_touches_my_own_copy() -> void:
	var enemy: Node = track(Node.new())
	var me: Node = track(Node.new())
	var ally: Node = track(Node.new())
	var st: Node = StatusContainer.new()
	st.name = "Status"
	enemy.add_child(st)
	var fx: Resource = StatusEffectScript.new()
	fx.id = &"immolate"
	fx.display_name = "Immolate"
	fx.duration = 12.0
	fx.tick_damage = 0.2
	fx.tick_interval = 1.0
	fx.dot_hasted = false
	st.apply(fx, me)
	st.apply(fx, ally)
	assert_true(st.has_from("immolate", me) and st.has_from("immolate", ally), "each caster has their own copy")
	var my_key: String = StatusContainer.key_for(fx, me)
	var tick_before := float(st.effects[my_key]["next_tick"])
	assert_true(st.set_remaining_from("immolate", me, 5.0))
	var mine: float = st.remaining_from("immolate", me)
	assert_true(mine > 4.8 and mine <= 5.001, "mine now has 5 s left, got %s" % mine)   # (+1 ms: float rounding of the clock)
	var theirs: float = st.remaining_from("immolate", ally)
	assert_true(theirs > 11.8, "an ally's Immolate is left alone, got %s" % theirs)
	assert_eq(float(st.effects[my_key]["next_tick"]), tick_before, "the tick timer doesn't move")
	assert_false(st.set_remaining_from("immolate", enemy, 5.0), "nothing from someone with no Immolate there")
	assert_eq(st.remaining_from("immolate", enemy), 0.0)

func test_afterglow_damage() -> void:
	var p := _player()
	assert_eq(FireMeleeKit.afterglow_damage(200, 10.0), 20.0)
	assert_eq(FireMeleeKit.afterglow_damage(200, 20.0), 40.0)
	assert_eq(FireMeleeKit.afterglow_damage(0, 20.0), 0.0)
	assert_eq(Balance.AFTERGLOW_TIME, 4.0)
	assert_eq(Details.spell_name("afterglow"), "Afterglow", "its hits are named after it in the meter")

func test_melee_talents() -> void:
	var want := {
		"fire_fresh_tinder": ["fire_r2c10", [10.0, 20.0, 30.0], ""],
		"fire_afterglow": ["fire_r2c9", [7.0, 13.0, 20.0], "quench"],
	}
	for key in want:
		var id := Talents.id_for_key(key)
		var vals: Array = want[key][1]
		assert_eq(id, str(want[key][0]), "%s sits where it should" % key)
		assert_eq(Talents.max_rank(id), vals.size(), "%s ranks" % key)
		for i in vals.size():
			assert_eq(Talents.value_at(id, i + 1), float(vals[i]), "%s rank %d" % [key, i + 1])
		assert_eq(str(Talents.get_talent(id).get("requires", "")), str(want[key][2]))
		assert_true(TalentIcons.has_icon(id), "%s has an icon" % key)
		assert_true(bool(Talents.get_talent(id).get("implemented", false)), "%s does something" % key)
	assert_false(Talents.has_capstone(Talents.id_for_key("fire_fresh_tinder")), "Fresh Tinder's capstone went with its rework")
	assert_eq(Talents.id_for_key("fire_kindling"), "", "Kindling is gone (Sparks build the extra Heat now)")

func test_swings_glow_hotter() -> void:
	var p := _player()
	var cold: Color = FireMeleeKit.heat_tint(0)
	var hot: Color = FireMeleeKit.heat_tint(Balance.HEAT_MAX_STACKS)
	assert_true(cold.b > cold.r, "no Heat: steel")
	assert_true(hot.r >= 0.99 and hot.r > hot.b, "full Heat: white-hot")
	assert_true(FireMeleeKit.heat_tint(5).b < cold.b, "warming up in between")
