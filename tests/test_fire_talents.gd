@tool
extends McpTestSuite

# Fire talents. Smoldering Focus used to be a Legendary rune; now it is 5 ranks of
# 0.02% more Fire spell damage per Fury you hold (+10% at 100 Fury at max rank).
# The Fury maths itself is tests/test_fire_fury.gd.

const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const Runes = preload("res://scripts/runes.gd")
const Effects = preload("res://scripts/core/effects.gd")
const Chest = preload("res://scripts/dungeon/chest.gd")
const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const StatusContainer = preload("res://scripts/core/status_container.gd")
const StatusEffectScript = preload("res://scripts/data/status_effect_data.gd")
const DamageInfo = preload("res://scripts/core/damage_info.gd")

func suite_name() -> String:
	return "fire_talents"

func test_smoldering_focus_is_a_bottom_row_fire_talent() -> void:
	var id := Talents.id_for_key("fire_smoldering_focus")
	assert_eq(id, "fire_r10c2", "Steady Flame's capstone, the left of the Fire book's bottom row")
	assert_eq(Talents.tier_of(id), Talents.ROWS - 1, "bottom row")
	var t := Talents.get_talent(id)
	assert_false(bool(t.get("placeholder", true)), "a real talent")
	assert_true(bool(t.get("implemented", false)), "has an effect")
	assert_eq(Talents.max_rank(id), 5, "0 / 5")
	assert_true(TalentIcons.has_icon(id), "designed talents have an icon")

func test_smoldering_focus_bonus_is_split_evenly() -> void:
	var id := Talents.id_for_key("fire_smoldering_focus")
	var vals: Array = Talents.get_talent(id).get("values", [])
	assert_eq(vals.size(), 5, "one value per rank")
	for rank in range(1, 6):
		assert_true(is_equal_approx(Talents.value_at(id, rank), 0.02 * rank), "rank %d = %.2f%% per Fury" % [rank, 0.02 * rank])
	assert_true(is_equal_approx(FireFuryKit.smolder_pct(100.0, Talents.value_at(id, 5)), 10.0), "max rank at 100 Fury: +10%")
	assert_eq(Talents.value_at(id, 0), 0.0, "nothing without the talent")

func test_tempered_flame_is_a_top_row_fire_talent() -> void:
	var id := Talents.id_for_key("fire_tempered_flame")
	assert_eq(id, "fire_r2c1", "under Stoked Breath, at the top of Steady Flame's flame")
	assert_eq(Talents.tier_of(id), 1, "second row")
	assert_eq(Talents.max_rank(id), 3, "0 / 3")
	assert_eq(Talents.value_at(id, 1), 40.0)
	assert_eq(Talents.value_at(id, 3), 60.0)
	assert_eq(Talents.value_at(id, 1, "values2"), 7.0)
	assert_eq(Talents.value_at(id, 3, "values2"), 20.0)
	assert_true(TalentIcons.has_icon(id), "designed talents have an icon")
	assert_contains(Talents.description(id), Abilities.ability_name("fireball"), "names the spell as the game shows it")

## Four of the open talents (no ability needed), at the top of the open column.
func test_generic_fire_talents() -> void:
	var slots := {"fire_flash_point": "fire_r1c7", "fire_forge_hardened": "fire_r2c7",
		"fire_lingering_embers": "fire_r3c7", "fire_controlled_burn": "fire_r4c7"}
	for key in slots:
		var id := Talents.id_for_key(str(key))
		assert_eq(id, str(slots[key]), "%s has its slot" % key)
		assert_eq(Talents.max_rank(id), 3, "0 / 3")
		assert_eq(Talents.required_ability(id), "", "%s needs no ability" % key)
		assert_true(TalentIcons.has_icon(id), "%s has an icon" % key)
	var flash := Talents.id_for_key("fire_flash_point")
	assert_eq(Talents.get_talent(flash).get("values", []), [1.0, 2.0, 3.0])
	assert_eq(float(Talents.get_talent(flash)["stats"].get("crit_chance", 0.0)), 1.0, "+1% Critical Strike per rank")
	assert_eq(Talents.get_talent(Talents.id_for_key("fire_forge_hardened")).get("values", []), [2.0, 4.0, 6.0])
	assert_eq(Talents.get_talent(Talents.id_for_key("fire_lingering_embers")).get("values", []), [3.0, 6.0, 9.0])
	assert_eq(Talents.get_talent(Talents.id_for_key("fire_controlled_burn")).get("values", []), [5.0, 10.0, 15.0])
	# Cool Under Fire is gone (a defensive in a DPS tree), and nothing is moved any
	# more: the column-group tree refunded every point (TREE_VERSION).
	assert_eq(Talents.id_for_key("fire_cool_under_fire"), "")
	assert_eq(Talents.current_id("fire_r2c5"), "fire_r2c5", "Deep Brand's slot keeps its own points")

func test_every_designed_fire_talent_has_an_icon() -> void:
	for id in Talents.in_tree("fire"):
		var placeholder := bool(Talents.get_talent(id).get("placeholder", true))
		assert_eq(TalentIcons.has_icon(id), not placeholder, "%s: designed talents have an icon, empty ones don't" % id)

func test_tempered_flame_maths() -> void:
	var player_script: GDScript = load("res://scripts/player.gd")
	var none: Array = player_script.fire_crit_rules("fireball", 30.0, 0.0, 0.0)
	assert_true(is_equal_approx(float(none[0]), 30.0) and float(none[1]) == 0.0, "no talent: Firebolt is unchanged")
	var r1: Array = player_script.fire_crit_rules("fireball", 30.0, 40.0, 10.0)
	assert_true(is_equal_approx(float(r1[0]), 18.0), "rank 1: 40% less of 30% crit = 18%")
	assert_true(is_equal_approx(float(r1[1]), 3.0), "rank 1: +10% of 30% crit = +3% damage")
	var r2: Array = player_script.fire_crit_rules("fireball", 30.0, 60.0, 20.0)
	assert_true(is_equal_approx(float(r2[0]), 12.0), "rank 2: 60% less of 30% crit = 12%")
	assert_true(is_equal_approx(float(r2[1]), 6.0), "rank 2: +20% of 30% crit = +6% damage")
	var other: Array = player_script.fire_crit_rules("flamenova", 30.0, 60.0, 20.0)
	assert_true(is_equal_approx(float(other[0]), 30.0) and float(other[1]) == 0.0, "only Firebolt is tempered")

func test_vent_flames() -> void:
	var r := Abilities.get_resource("ventflames")
	assert_true(r != null, "Vent Flames exists")
	assert_eq(int(r.cast_type), 0, "instant")
	assert_eq(float(r.cooldown), 10.0, "10 s cooldown")
	assert_eq(float(r.damage), 2.0, "2 Frost Bolts of damage")
	assert_eq(str(r.damage_type), "fire")
	assert_true(r.tags.has("Fire") and r.tags.has("Spell"), "a Fire spell")
	assert_eq(Abilities.category_of("ventflames"), "fire")
	assert_true(Abilities.ALL.has("ventflames") and Abilities.DRAFT_POOL.has("ventflames") and SkillCards.ALL.has("ventflames"))
	assert_eq(SkillCards.ability_of("ventflames"), "ventflames")
	assert_eq(Abilities.resource_of("ventflames"), "fury")
	assert_true(Abilities.SPENDS_ALL.has("ventflames"), "spends all your Fury")
	assert_contains(Abilities.tooltip("ventflames"), "All Fury")
	var player_script: GDScript = load("res://scripts/player.gd")
	var v: Array = player_script.fire_crit_rules("ventflames", 30.0)
	assert_eq(float(v[0]), 100.0, "always crits")
	assert_eq(float(v[1]), 0.0, "no bonus from crit chance any more: it scales on Fury")
	var v0: Array = player_script.fire_crit_rules("ventflames", 0.0, 60.0, 20.0)
	assert_eq(float(v0[0]), 100.0, "crits even with no crit chance")

func test_cool_head() -> void:
	var r := Abilities.get_resource("coolhead")
	assert_true(r != null, "Cool Head exists")
	assert_eq(int(r.cast_type), 0, "instant")
	assert_eq(float(r.cooldown), 120.0, "2 minute cooldown")
	assert_eq(Balance.COOL_HEAD_TIME, 15.0, "lasts 15 s")
	assert_eq(Balance.CONCENTRATED_FIRE_WINDOW, 5.0, "5 s of instant casts afterwards")
	assert_eq(Abilities.category_of("coolhead"), "fire")
	assert_true(Abilities.ALL.has("coolhead") and Abilities.DRAFT_POOL.has("coolhead") and SkillCards.ALL.has("coolhead"))
	assert_eq(SkillCards.ability_of("coolhead"), "coolhead")
	var player_script: GDScript = load("res://scripts/player.gd")
	assert_true(FireCooldownsKit.is_fire_action(Abilities.tags_of("fireball")), "Fire spells count")
	assert_true(FireCooldownsKit.is_fire_action(Abilities.tags_of("searingstrike")), "Fire abilities count")
	assert_false(FireCooldownsKit.is_fire_action(Abilities.tags_of("frostbolt")), "other schools don't")
	assert_true(float(Abilities.get_resource("fireball").cast_time) > 0.0, "Firebolt has a cast time to make instant")

func test_concentrated_fire_stacks() -> void:
	var owner_node: Node = track(Node.new())
	var st: Node = StatusContainer.new()
	st.name = "Status"
	owner_node.add_child(st)
	var fx := StatusContainer.make_buff("concentrated_fire", "Concentrated Fire", "x", 0.0, 20.0, Balance.CONCENTRATED_FIRE_MAX, Color.WHITE)
	for i in 3:
		st.apply(fx)
	assert_eq(st.stacks_of("concentrated_fire"), 3, "one stack per Fire spell that hit")
	assert_true(st.set_remaining("concentrated_fire", 5.0))
	var left := float(st.list()[0]["remaining"])
	assert_true(left > 4.5 and left <= 5.001, "the window is 5 s once Cool Head ends")   # (+1 ms: float rounding of the clock)
	assert_true(st.spend_stacks("concentrated_fire"))
	assert_eq(st.stacks_of("concentrated_fire"), 2, "an instant cast spends one stack")
	st.spend_stacks("concentrated_fire")
	st.spend_stacks("concentrated_fire")
	assert_false(st.has("concentrated_fire"), "gone with the last stack")
	assert_false(st.spend_stacks("concentrated_fire"), "nothing to spend")

func test_afterburn_sits_right_of_smoldering_focus() -> void:
	var id := Talents.id_for_key("fire_afterburn")
	assert_eq(id, "fire_r4c3", "Steady Flame's group, beside Banked Coals")
	assert_eq(Talents.max_rank(id), 3, "0 / 3 (was 5): the same top")
	assert_true(is_equal_approx(Talents.value_at(id, 1), 0.17))
	assert_true(is_equal_approx(Talents.value_at(id, 3), 0.5), "rank 3 = (100 - crit chance) x 0.5")
	assert_true(TalentIcons.has_icon(id))

## The buff: only non-crit Fire spell hits get it, scaled from 100 - crit chance.
func test_afterburn_boosts_non_crits_from_missing_crit_chance() -> void:
	var owner_node: Node = track(Node.new())
	var carrier := GDScript.new()
	carrier.source_code = "@tool\nextends Node\nfunc get_stat(n: String) -> float:\n\treturn 20.0 if n == 'crit_chance' else 0.0\n"
	carrier.reload()
	owner_node.set_script(carrier)
	var st: Node = StatusContainer.new()
	st.name = "Status"
	owner_node.add_child(st)
	# (Loaded by path: the Effects registry may have listed the folder before this file existed.)
	var src: Resource = load("res://data/effects/afterburn.tres")
	var fx: Resource = StatusEffectScript.new()
	for p in ["id", "display_name", "duration", "stack_mode", "max_stacks", "damage_mod_pct", "modifies_incoming",
			"mod_damage_types", "mod_required_tags", "mod_affects_dots", "consume_on_use", "mod_crit_only",
			"mod_non_crit_only", "mod_scale_stat", "mod_scale_factor", "mod_scale_inverse"]:
		fx.set(p, src.get(p))
	assert_true(bool(fx.mod_non_crit_only) and bool(fx.mod_scale_inverse) and not bool(fx.mod_crit_only), "non-crits, from the crit chance you lack")
	assert_eq(int(fx.max_stacks), 20)
	assert_eq(float(fx.duration), 20.0)
	fx.mod_scale_factor = 0.5   # rank 5 (player.gd sets it from the rank)
	for i in 2:
		st.apply(fx)
	var crit := _hit("fire", ["Fire", "Spell"])
	crit.crit = true
	st.collect_damage_mods(crit, false)
	assert_eq(crit.bonus_pct, 0.0, "crits get nothing")
	var ability := _hit("fire", ["Fire", "Ability"])
	st.collect_damage_mods(ability, false)
	assert_eq(ability.bonus_pct, 0.0, "fire abilities aren't fire spells")
	var plain := _hit("fire", ["Fire", "Spell"])
	st.collect_damage_mods(plain, false)
	assert_true(absf(plain.bonus_pct - 80.0) < 0.001, "2 stacks x ((100 - 20 crit) x 0.5) = +80, got %s" % plain.bonus_pct)

func _hit(type: String, tags: Array) -> RefCounted:
	var info := DamageInfo.make(null, null, 3, "test")
	info.damage_type = type
	info.tags = PackedStringArray(tags)
	return info

func test_furnace_breath() -> void:
	var r := Abilities.get_resource("furnacebreath")
	assert_true(r != null, "Furnace Breath exists")
	assert_eq(int(r.cast_type), 0, "instant")
	assert_false(bool(r.requires_target), "a cone in front of you needs no target")
	assert_true(r.tags.has("Fire") and r.tags.has("Spell") and r.tags.has("Interrupt"))
	assert_true(float(r.radius) > 0.0 and float(r.radius) <= 8.0, "close range")
	assert_true(Balance.INTERRUPT_LOCKOUT.has("furnacebreath"), "it interrupts")
	var player_script: GDScript = load("res://scripts/player.gd")
	assert_false(player_script.on_gcd("furnacebreath"), "interrupts are off the global cooldown")
	assert_true(Abilities.DRAFT_POOL.has("furnacebreath") and SkillCards.ALL.has("furnacebreath"))
	# The cone: 90 degrees wide around where you face (forward = -Z).
	var fwd := Vector3(0, 0, -1)
	assert_true(FireTankKit.in_cone(fwd, Vector3(0, 0, -5), 90.0), "straight ahead")
	assert_true(FireTankKit.in_cone(fwd, Vector3(2, 0, -3), 90.0), "34 degrees to the side")
	assert_false(FireTankKit.in_cone(fwd, Vector3(3, 0, -2), 90.0), "56 degrees to the side")
	assert_false(FireTankKit.in_cone(fwd, Vector3(0, 0, 4), 90.0), "behind you")
	assert_true(FireTankKit.in_cone(fwd, Vector3(0, 3, -4), 90.0), "height doesn't matter")
	assert_true(FireTankKit.in_cone(fwd, Vector3.ZERO, 90.0), "standing on top of you")

func test_slag_skin() -> void:
	var r := Abilities.get_resource("slagskin")
	assert_true(r != null, "Slag Skin exists")
	assert_eq(int(r.cast_type), 0, "instant")
	assert_true(float(r.damage) > 0.0, "burns attackers")
	assert_true(float(r.threat_multiplier) > 1.0, "a tank tool: extra threat")
	assert_true(Balance.SLAG_ARMOR > 0.0 and Balance.SLAG_SKIN_TIME > 0.0)
	assert_eq(Abilities.category_of("slagskin"), "fire")
	assert_true(Abilities.DRAFT_POOL.has("slagskin") and SkillCards.ALL.has("slagskin"))

func test_banked_coals() -> void:
	var id := Talents.id_for_key("fire_banked_coals")
	assert_eq(id, "fire_r4c1", "Steady Flame's group")
	var row := Talents.in_row("fire", Talents.ROWS - 1)
	assert_eq(row, ["fire_r10c2", "fire_r10c5", "fire_r10c9", "fire_r10c12"] as Array[String], "the bottom row: one capstone per spec")
	assert_eq(row[0], Talents.id_for_key("fire_smoldering_focus"))
	assert_eq(Talents.max_rank(id), 2)
	assert_eq(Talents.value_at(id, 1), 25.0)
	assert_eq(Talents.value_at(id, 2), 50.0)
	assert_true(TalentIcons.has_icon(id))
	# A crit Vents 50% of your Fury; Banked Coals Vents 25% / 50% less of that.
	assert_true(is_equal_approx(FireFuryKit.vented(80.0, 0.0, false), 40.0))
	assert_true(is_equal_approx(FireFuryKit.vented(80.0, 25.0, false), 30.0), "rank 1: 37.5% of it")
	assert_true(is_equal_approx(FireFuryKit.vented(80.0, 50.0, false), 20.0), "rank 2: 25% of it")

## The container side: a carrier that keeps stacks still has them after the buff is used.
func test_spent_stacks_can_be_kept() -> void:
	var owner_node: Node = track(Node.new())
	var carrier := GDScript.new()
	carrier.source_code = "@tool\nextends Node\nfunc get_stat(_n: String) -> float:\n\treturn 20.0\nfunc stacks_kept_on_use(_res: Resource, stacks: int) -> int:\n\treturn stacks / 2\n"
	carrier.reload()
	owner_node.set_script(carrier)
	var st: Node = StatusContainer.new()
	st.name = "Status"
	owner_node.add_child(st)
	var fx: Resource = StatusEffectScript.new()
	fx.id = &"test_spend"
	fx.display_name = "Test"
	fx.duration = 20.0
	fx.stack_mode = 1
	fx.max_stacks = 20
	fx.damage_mod_pct = 10.0
	fx.consume_on_use = true
	for i in 4:
		st.apply(fx)
	var hit := _hit("fire", ["Fire", "Spell"])
	st.collect_damage_mods(hit, false)
	assert_true(absf(hit.bonus_pct - 40.0) < 0.001, "all 4 stacks boost the hit")
	st._flush_consumed()
	assert_eq(st.stacks_of("test_spend"), 2, "half the stacks are kept")
	var hit2 := _hit("fire", ["Fire", "Spell"])
	st.collect_damage_mods(hit2, false)
	st._flush_consumed()
	assert_eq(st.stacks_of("test_spend"), 1)
	var hit3 := _hit("fire", ["Fire", "Spell"])
	st.collect_damage_mods(hit3, false)
	st._flush_consumed()
	assert_false(st.has("test_spend"), "the last stack is spent")

func test_stoke() -> void:
	var r := Abilities.get_resource("stoke")
	assert_true(r != null, "Stoke exists")
	assert_eq(int(r.cast_type), 0, "instant")
	assert_eq(float(r.cooldown), 20.0, "20 s cooldown")
	assert_true(bool(r.requires_target))
	assert_eq(Abilities.category_of("stoke"), "fire")
	assert_true(Abilities.DRAFT_POOL.has("stoke") and SkillCards.ALL.has("stoke"))
	# What it eats: only MY copy of a DoT, worth ticks left x tick damage.
	var enemy: Node = track(Node.new())
	var me: Node = track(Node.new())
	var ally: Node = track(Node.new())
	var st: Node = StatusContainer.new()
	st.name = "Status"
	enemy.add_child(st)
	var burn: Resource = StatusEffectScript.new()
	burn.id = &"burning"
	burn.display_name = "Burning"
	burn.duration = 4.0
	burn.tick_damage = 0.1
	burn.tick_interval = 1.0
	burn.dot_hasted = false
	st.apply(burn, me)
	st.apply(burn, ally)
	assert_true(absf(st.dot_left("burning", me) - 0.4) < 0.001, "4 ticks of 0.1 left, got %s" % st.dot_left("burning", me))
	assert_eq(st.dot_left("burning", enemy), 0.0, "nothing from someone with no Burning there")
	assert_true(st.remove_from("burning", me))
	assert_false(st.has_from("burning", me), "my Burning is gone")
	assert_true(st.has_from("burning", ally), "an ally's Burning is left alone")
	assert_false(st.remove_from("burning", me), "nothing left to remove")

func test_ember_volley() -> void:
	var r := Abilities.get_resource("embervolley")
	assert_true(r != null, "Ember Volley exists")
	assert_eq(int(r.cast_type), 2, "a channel")
	assert_eq(float(r.cast_time), 3.0, "3 s")
	assert_eq(Balance.EMBER_VOLLEY_HITS, 6, "6 embers")
	assert_true(float(r.damage) > 0.0 and float(r.damage) < 1.0, "small hits")
	assert_true(r.tags.has("Fire") and r.tags.has("Spell"))
	assert_eq(Abilities.category_of("embervolley"), "fire")
	assert_true(Abilities.DRAFT_POOL.has("embervolley") and SkillCards.ALL.has("embervolley"))

func test_immolate() -> void:
	var r := Abilities.get_resource("immolate")
	assert_true(r != null, "Immolate exists")
	assert_eq(int(r.cast_type), 1, "has a cast time")
	assert_true(float(r.cast_time) > 0.0)
	assert_eq(float(r.damage), 0.0, "all of its damage is over time")
	assert_true(r.on_hit_effect != null, "applies the Immolate effect")
	var fx: Resource = r.on_hit_effect
	assert_eq(str(fx.id), "immolate")
	assert_true(float(fx.tick_damage) > 0.0 and float(fx.duration) > 4.0, "a longer burn than Burning")
	assert_eq(Balance.IMMOLATE_SPREAD_TARGETS, 2, "spreads to 2 others")
	assert_eq(Abilities.category_of("immolate"), "fire")
	assert_true(Abilities.DRAFT_POOL.has("immolate") and SkillCards.ALL.has("immolate"))
	var player_script: GDScript = load("res://scripts/player.gd")
	assert_true(player_script.ENEMY_BOLTS.has("immolate"), "cast at an enemy like the bolts")

## An effect-only hit (0 damage) must not use up Smoldering Focus / Afterburn.
func test_effect_only_hits_use_nothing_up() -> void:
	var owner_node: Node = track(Node.new())
	var st: Node = StatusContainer.new()
	st.name = "Status"
	owner_node.add_child(st)
	var fx: Resource = StatusEffectScript.new()
	fx.id = &"test_keep"
	fx.duration = 20.0
	fx.damage_mod_pct = 10.0
	fx.consume_on_use = true
	st.apply(fx)
	var landing := DamageInfo.make(null, null, 0.0, "immolate")
	landing.damage_type = "fire"
	landing.tags = PackedStringArray(["Fire", "Spell"])
	st.collect_damage_mods(landing, false)
	st._flush_consumed()
	assert_true(st.has("test_keep"), "Immolate landing leaves the buff alone")
	assert_eq(landing.bonus_pct, 0.0)

func test_fire_runes() -> void:
	for id in ["dull_edge", "hair_trigger", "sealed_kiln"]:
		assert_true(Runes.PATHS.has(id) and Runes.ALL.has(id), "%s is registered" % id)
		assert_eq(Runes.rarity(id), Runes.EPIC, "%s is Epic" % id)
	assert_eq(Balance.HAIR_TRIGGER_CHARGES, 2)
	assert_eq(Balance.DULL_EDGE_CRIT_CAP, 10.0)
	var player_script: GDScript = load("res://scripts/player.gd")
	var under: Array = player_script.dull_edge_split(6.0, 2.0, 10.0)
	assert_eq(under, [6.0, 2.0, 0.0], "under the cap: nothing changes")
	var over: Array = player_script.dull_edge_split(18.0, 4.0, 10.0)
	assert_eq(over, [10.0, 0.0, 12.0], "22% crit: 10% stays, 12% becomes Spell Power")
	var mixed: Array = player_script.dull_edge_split(7.0, 8.0, 10.0)
	assert_eq(mixed, [7.0, 3.0, 5.0], "spell crit fills what is left under the cap")

func test_scattered_embers() -> void:
	var id := Talents.id_for_key("fire_volley_targets")
	assert_eq(id, "fire_r5c2", "beside the Ember Volley choice talent")
	assert_eq(Talents.max_rank(id), 2, "0 / 2")
	assert_eq(Talents.value_at(id, 1), 1.0, "1 more target")
	assert_eq(Talents.value_at(id, 2), 2.0, "2 more targets")
	assert_eq(str(Talents.get_talent(id).get("requires", "")), "embervolley")
	assert_true(TalentIcons.has_icon(id))
	assert_true(Balance.EMBER_VOLLEY_SPLIT_RADIUS > 0.0)

func test_wall_of_fire() -> void:
	var r := Abilities.get_resource("walloffire")
	assert_true(r != null, "Wall of Fire exists")
	assert_eq(float(r.cooldown), 20.0, "20 s cooldown")
	assert_true(float(r.cast_time) > 0.0, "a cast (so Concentrated Fire can make it instant)")
	assert_false(bool(r.requires_target), "can be put down without a target")
	assert_eq(Abilities.category_of("walloffire"), "fire")
	assert_true(Abilities.DRAFT_POOL.has("walloffire") and SkillCards.ALL.has("walloffire"))
	const FireWall = preload("res://scripts/fire_wall.gd")
	# An 8 m x 2 m wall: length along X, thickness along Z.
	assert_true(FireWall.in_wall(Vector3(3.5, 0, 0.5), 8.0, 2.0), "inside")
	assert_false(FireWall.in_wall(Vector3(4.5, 0, 0), 8.0, 2.0), "past the end")
	assert_false(FireWall.in_wall(Vector3(0, 0, 1.5), 8.0, 2.0), "in front of it")
	assert_true(FireWall.in_wall(Vector3(0, 0, 1.3), 8.0, 2.0, 0.4), "a big enemy touching it")
	assert_true(FireWall.in_wall(Vector3(0, 5, 0), 8.0, 2.0), "height doesn't matter")

func test_level_head_rune() -> void:
	assert_true(Runes.PATHS.has("level_head") and Runes.ALL.has("level_head"))
	assert_eq(Runes.rarity("level_head"), Runes.EPIC)
	var player_script: GDScript = load("res://scripts/player.gd")
	var frostbolt := Abilities.get_resource("frostbolt")
	var firebolt := Abilities.get_resource("fireball")
	assert_true(FireCooldownsKit.concentrated_applies(firebolt.tags, float(firebolt.cast_time), false), "Fire casts: always")
	assert_false(FireCooldownsKit.concentrated_applies(frostbolt.tags, float(frostbolt.cast_time), false), "other schools: not without the rune")
	assert_true(FireCooldownsKit.concentrated_applies(frostbolt.tags, float(frostbolt.cast_time), true), "other schools: with the rune")
	assert_false(FireCooldownsKit.concentrated_applies(frostbolt.tags, 0.0, true), "instants have nothing to make instant")
	assert_false(FireCooldownsKit.concentrated_applies(Abilities.tags_of("frostarrow"), 1.2, true), "the rune is for spells, not abilities")

func test_kiln_blast() -> void:
	var r := Abilities.get_resource("kilnblast")
	assert_true(r != null, "Kiln Blast exists")
	assert_eq(float(r.cast_time), 3.5, "3.5 s cast")
	assert_eq(float(r.cooldown), 3.0, "3 s cooldown")
	assert_eq(float(r.damage), 3.0, "3 Frost Bolts")
	assert_eq(Balance.KILN_BLAST_IMMOLATE_PCT, 20.0, "+20% with your Immolate")
	assert_contains(Abilities.tooltip("kilnblast"), "20%", "the tooltip reads it from balance.gd")
	assert_eq(Abilities.resource_of("kilnblast"), "fury")
	assert_eq(Abilities.cost_of("kilnblast"), 40.0, "the non-crit spender: 40 Fury")
	var player_script: GDScript = load("res://scripts/player.gd")
	assert_true(player_script.ENEMY_BOLTS.has("kilnblast"), "cast at an enemy")
	assert_true(FireCooldownsKit.concentrated_applies(Abilities.tags_of("kilnblast"), float(r.cast_time), false), "can be made instant")

## Slow Fuse and Rekindle are gone, with Volatile Fuse and Flashover.
func test_slow_fuse_and_rekindle_are_gone() -> void:
	for id in ["slowfuse", "rekindle"]:
		assert_false(Abilities.PATHS.has(id), "%s is no ability" % id)
		assert_false(Abilities.ALL.has(id) or Abilities.DRAFT_POOL.has(id) or SkillCards.ALL.has(id), "%s is in no list" % id)
	for key in ["fire_fuse_crit", "fire_flashover", "fire_banked_mana"]:
		assert_eq(Talents.id_for_key(key), "", "%s is gone" % key)
	assert_false(ResourceLoader.exists("res://data/effects/slow_fuse.tres"))

## A debuff's stacks can change without restarting its timer.
func test_set_stacks_keeps_the_timer() -> void:
	var owner_node: Node = track(Node.new())
	var st: Node = StatusContainer.new()
	st.name = "Status"
	owner_node.add_child(st)
	var fx: Resource = StatusEffectScript.new()
	fx.id = &"test_charge"
	fx.display_name = "Test Charge"
	fx.duration = 5.0
	fx.max_stacks = 99
	st.apply(fx)
	var before := float(st.effects["test_charge"]["expires"])
	assert_true(st.set_stacks("test_charge", 4))
	assert_eq(st.stacks_of("test_charge"), 4)
	assert_eq(float(st.effects["test_charge"]["expires"]), before, "the timer stays")
	assert_false(st.set_stacks("nothing", 2))

func test_smoldering_focus_rune_is_gone() -> void:
	assert_false(Runes.PATHS.has("smoldering_focus"))
	assert_false(Runes.ALL.has("smoldering_focus"))
	assert_false(ResourceLoader.exists("res://data/runes/smoldering_focus.tres"), "its stale file is gone")
	assert_true(Effects.get_effect("smoldering_focus") == null, "the talent holds no stacks any more")
	assert_true(Runes.any_of_rarity(Runes.LEGENDARY), "the only Legendary rune is Dusk till Dawn")
	assert_true(Runes.any_of_rarity(Runes.EPIC))

func test_chests_never_roll_an_empty_rune_rarity() -> void:
	for i in 300:
		assert_true(Runes.any_of_rarity(Chest._roll_rune_rarity()), "a Mysterious Rune always has runes to offer")
