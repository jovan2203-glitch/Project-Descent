@tool
extends McpTestSuite

# The Nature caster, the Weaver: creatures here for one strike. Woven ones
# (Briar Tiger, Thornwing) leave mulch where they strike; rooted finishers
# (Mossback, Choking Vipers) use up the patches near their target and grow with
# each; Greenwood Stag carries the patches to the target. Thornshot is the filler
# (Thornburst out of the mulch, every 3rd leaves a patch). Rules: player.gd,
# "Nature caster: the Weaver".

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const Talents = preload("res://scripts/talents.gd")
const Keywords = preload("res://scripts/core/keywords.gd")
const Details = preload("res://scripts/core/details.gd")

const KIT := ["thornshot", "briartiger", "mossback", "thornwing", "chokingvipers", "greenwoodstag"]
const HEALER := ["dewfall", "fawn", "rootguard", "owl", "heartwoodelk", "wildherd"]
const TANK := ["vinefist", "grasp", "stomp", "giantshands", "heartsap", "awaken"]
const ARCHER := ["fangarrow", "adderarrow", "asparrow", "kraitarrow", "venomburst", "spittingvolley", "bloatarrow", "coilback", "venomsurge"]
const OLD := ["wrath", "insectswarm", "entanglingroots", "regrowth"]

func suite_name() -> String:
	return "nature"

func _p() -> GDScript:
	return load("res://scripts/player.gd")

func _src() -> String:
	return PlayerSource.text()

# --- The kit ---------------------------------------------------------------------------

func test_the_kit_is_a_nature_caster_spec() -> void:
	for id in KIT:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s loads" % id)
		assert_eq(Abilities.category_of(id), "nature", "%s is Nature" % id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is drafted, with a Skill Card" % id)
		assert_true(r.tags.has("Spell") and r.tags.has("Nature"), "%s is a Nature spell" % id)
		assert_eq(Abilities.resource_of(id), "mana", "%s uses mana" % id)
		var tip := Abilities.tooltip(id)
		assert_false(tip.contains("{") or tip.contains("}"), "%s: every number in its text is filled in: %s" % [id, tip])
	var spec: Array = []
	for s in Abilities.SPECS["nature"]:
		if s[0] == "Thornweaver":
			spec = s[1]
	assert_eq(spec, KIT, "the Thornweaver spec holds the kit")

func test_the_placeholders_are_gone() -> void:
	for id in OLD:
		assert_false(Abilities.PATHS.has(id) or Abilities.ALL.has(id) or SkillCards.ALL.has(id), "%s was wiped" % id)
		assert_false(ResourceLoader.exists("res://data/abilities/%s.tres" % id), "%s has no data left" % id)

func test_numbers() -> void:
	assert_eq(float(Abilities.get_resource("thornshot").cast_time), 1.5)
	assert_eq(float(Abilities.get_resource("briartiger").cast_time), 1.5)
	assert_eq(float(Abilities.get_resource("briartiger").cooldown), 6.0)
	assert_eq(float(Abilities.get_resource("thornwing").cooldown), 10.0)
	assert_eq(float(Abilities.get_resource("greenwoodstag").cooldown), 15.0)
	assert_eq(float(Abilities.get_resource("chokingvipers").radius), Balance.MULCH_REACH)
	assert_eq(Balance.MULCH_MAX, 5)
	assert_eq(Balance.VIPERS_HOLD, 0.5)
	var p := _p()
	# Mossback: 0.6 + 0.6 per patch (3.6 at 5); Vipers: 0.4 + 0.4 per patch (2.4 at 5).
	_near(WeaverKit.rooted_coef(float(Abilities.get_resource("mossback").damage), Balance.MOSSBACK_PER_PATCH, 0), 0.6)
	_near(WeaverKit.rooted_coef(float(Abilities.get_resource("mossback").damage), Balance.MOSSBACK_PER_PATCH, 5), 3.6)
	_near(WeaverKit.rooted_coef(float(Abilities.get_resource("chokingvipers").damage), Balance.VIPERS_PER_PATCH, 5), 2.4)

# --- Mulch -------------------------------------------------------------------------------

func test_finishers_use_only_nearby_patches() -> void:
	var p := _p()
	var spots := [Vector3(0, 0, 0), Vector3(7.9, 0, 0), Vector3(8.5, 0, 0), Vector3(0, 5, 3)]
	assert_eq(WeaverKit.mulch_within(spots, Vector3.ZERO, Balance.MULCH_REACH), [0, 1, 3], "within 8 m, flat distance")

func test_thornburst_hits_each_enemy_once() -> void:
	var p := _p()
	var spots := [Vector3(0, 0, 0), Vector3(1, 0, 0)]
	var enemies := [Vector3(0.5, 0, 0), Vector3(3.9, 0, 0), Vector3(10, 0, 0)]
	assert_eq(WeaverKit.near_any(enemies, spots, Balance.THORNBURST_RADIUS), [0, 1], "near two patches still counts once")

func test_the_stag_sets_patches_down_around_the_target() -> void:
	var p := _p()
	var c := Vector3(10, 0, 4)
	assert_eq(WeaverKit.stag_spots(0, c, Balance.MULCH_RING), [])
	assert_eq(WeaverKit.stag_spots(1, c, Balance.MULCH_RING), [c])
	var five: Array = WeaverKit.stag_spots(5, c, Balance.MULCH_RING)
	assert_eq(five.size(), 5)
	for s in five:
		_near((s as Vector3).distance_to(c), Balance.MULCH_RING)
		assert_true(WeaverKit.mulch_within([s], c, Balance.MULCH_REACH).size() == 1, "every carried patch is in reach of the target")

func test_mulch_cap_and_oldest_first() -> void:
	var pl: Node = track(_p().new())
	for i in Balance.MULCH_MAX + 2:
		pl.weaver._add_mulch(Vector3(i, 0, 0))
	assert_eq(pl.mulch().size(), Balance.MULCH_MAX)
	assert_eq((pl.mulch()[0]["pos"] as Vector3).x, 2.0, "the two oldest went")
	var used: Array = pl.weaver._use_mulch(Vector3(4, 0, 0))
	assert_eq(int(used[0]), Balance.MULCH_MAX, "a finisher uses every patch in reach")
	assert_true(pl.mulch().is_empty())

func test_vipers_tick_with_haste() -> void:
	var p := _p()
	assert_eq(WeaverKit.vipers_ticks(1.0), 3)
	assert_eq(WeaverKit.vipers_ticks(1.34), 4, "Haste gives more ticks of the same size")

func test_hunting_party_every_second_tiger() -> void:
	var p := _p()
	assert_false(WeaverKit.hunting_party_turn(1))
	assert_true(WeaverKit.hunting_party_turn(2))
	assert_false(WeaverKit.hunting_party_turn(3))
	assert_true(WeaverKit.hunting_party_turn(4))

# --- Hooks, talent, keywords, meter --------------------------------------------------------

func test_hooks_are_in_place() -> void:
	var src := _src()
	assert_contains(src, "_thornshot_landed(enemy, at)   # Nature caster")
	assert_contains(src, "_briar_tiger(target)   # Nature caster")
	assert_contains(src, "_weaver_use(id, res)   # Nature caster: the Weaver")
	assert_contains(src, "\t_tick_weaver()\n")
	assert_contains(src, "and id != THORNWING_ID:")
	assert_contains(src, "_use_finisher(id)   # Nature caster")
	assert_contains(src, "_start_finisher(placing_id, cast_point)")
	assert_contains(src, "return str(_mulch.size())   # Nature caster")
	assert_eq(float(Abilities.get_resource("mossback").radius), Balance.MULCH_REACH, "Mossback's circle covers the patches it can use")
	var fx: Resource = load("res://data/effects/choked.tres")
	assert_true(bool(fx.root) and not bool(fx.stun), "Choking Vipers holds in place, never stuns")
	_near(float(fx.duration), Balance.VIPERS_HOLD)
	assert_false(Abilities.is_interrupt("chokingvipers"), "it never interrupts")

func test_talent() -> void:
	var id := Talents.id_for_key("nature_hunting_party")
	assert_true(id != "", "Hunting Party exists")
	assert_eq(Talents.max_rank(id), 4)
	assert_true(Talents.has_capstone(id))
	assert_eq(str(Talents.get_talent(id).get("requires", "")), "briartiger")

func test_keywords_and_meter() -> void:
	var t := Keywords.keyword_text("mulch")
	assert_false(t.contains("{"), t)
	assert_eq(str(Details.HIT_NAMES.get("thornburst", "")), "Thornburst")

func _near(a: float, b: float, msg: String = "") -> void:
	assert_true(absf(a - b) <= 0.001, "%s (%s vs %s)" % [msg, a, b])

# --- The healer: the Shepherd ----------------------------------------------------------------

func test_the_healer_kit_is_a_nature_spec() -> void:
	for id in HEALER:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s loads" % id)
		assert_eq(Abilities.category_of(id), "nature", "%s is Nature" % id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is drafted, with a Skill Card" % id)
		assert_true(r.tags.has("Spell") and r.tags.has("Nature"), "%s is a Nature spell" % id)
		assert_eq(Abilities.resource_of(id), "mana", "%s uses mana" % id)
		var tip := Abilities.tooltip(id)
		assert_false(tip.contains("{") or tip.contains("}"), "%s: every number in its text is filled in: %s" % [id, tip])
	var spec: Array = []
	for s in Abilities.SPECS["nature"]:
		if s[0] == "Shepherd":
			spec = s[1]
	assert_eq(spec, HEALER + ["returntobloom"], "the Shepherd spec holds the kit and its out-of-combat rez")
	for id in ["dewfall", "fawn", "owl", "rootguard", "heartwoodelk"]:
		assert_true(float(Balance.HEALS.get(id, 0.0)) > 0.0, "%s has a heal" % id)

func test_blossoms() -> void:
	var p := _p()
	assert_eq(ShepherdKit.blossom_add(0, 1), 1)
	assert_eq(ShepherdKit.blossom_add(2, 2), Balance.BLOSSOM_MAX, "never past the cap")
	assert_eq(ShepherdKit.blossom_add(Balance.BLOSSOM_MAX, 1), Balance.BLOSSOM_MAX)
	assert_true(ShepherdKit.overheals(500, 300), "more than they were missing: an extra Blossom")
	assert_false(ShepherdKit.overheals(300, 300))
	_near(ShepherdKit.dewfall_mult(0), 1.0)
	_near(ShepherdKit.dewfall_mult(3), 1.0 + 3.0 * Balance.DEWFALL_PER_BLOSSOM / 100.0)
	var pl: Node = track(_p().new())
	pl.shepherd._blossoms[pl.get_instance_id()] = {"who": pl, "n": 2, "until": pl.strings._str_now() + 5.0}
	assert_eq(pl.blossoms_on(pl), 2)
	pl.shepherd._blossoms[pl.get_instance_id()]["until"] = pl.strings._str_now() - 1.0
	assert_eq(pl.blossoms_on(pl), 0, "ran out")

func test_fawn_bounces_to_the_lowest_once() -> void:
	var p := _p()
	assert_eq(ShepherdKit.fawn_pick([0.9, 0.3, 0.5], [false, false, false]), 1)
	assert_eq(ShepherdKit.fawn_pick([0.9, 0.3, 0.5], [false, true, false]), 2, "never the same ally twice")
	assert_eq(ShepherdKit.fawn_pick([0.9], [true]), -1)
	assert_eq(ShepherdKit.fawn_bounces(1, true), Balance.FAWN_BOUNCES)
	assert_eq(ShepherdKit.fawn_bounces(2, true), Balance.FAWN_BOUNCES + Balance.RUNNING_HERD_EXTRA, "Running Herd: every second Fawn")
	assert_eq(ShepherdKit.fawn_bounces(2, false), Balance.FAWN_BOUNCES)

func test_rooted_heals_grow_with_blossoms() -> void:
	var p := _p()
	_near(WeaverKit.rooted_coef(float(Balance.HEALS["rootguard"]), Balance.ROOTGUARD_PER_BLOSSOM, 3), 1.76 + 3.0 * 0.88)
	_near(WeaverKit.rooted_coef(float(Balance.HEALS["heartwoodelk"]), Balance.ELK_PER_BLOSSOM, 0), 1.1)

func test_shepherd_hooks_and_talent() -> void:
	var src := _src()
	assert_contains(src, "_shepherd_cast_heal(spell, tgt, kind)   # Nature healer")
	assert_contains(src, "_shepherd_use(id, res)   # Nature healer")
	assert_contains(src, "_shepherd_precheck(id)   # Nature healer")
	assert_contains(src, "\t_tick_shepherd()\n")
	assert_contains(src, "_owl_taken(info)")
	assert_contains(src, "\"rootguard_broke\":")
	assert_true(HymnsKit.HYMN_DR_NAMES.has(ShepherdKit.FULL_BLOOM_FX), "Full Bloom goes through the less-damage-taken path")
	var id := Talents.id_for_key("nature_running_herd")
	assert_true(id != "", "Running Herd exists")
	assert_true(Talents.has_capstone(id))
	assert_eq(str(Talents.get_talent(id).get("requires", "")), "fawn")
	for k in ["blossom", "full_bloom"]:
		assert_false(Keywords.keyword_text(k).contains("{"), k)
	assert_eq(str(Details.HIT_NAMES.get("owlstrike", "")), "Owl's Strike")

# The Nature tank, the Colossus: limbs of a vine giant; Sap heals over time. Rules:
# player.gd, "Nature tank: the Colossus".

func test_the_tank_kit_is_a_nature_spec() -> void:
	for id in TANK:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s loads" % id)
		assert_eq(Abilities.category_of(id), "nature", "%s is Nature" % id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is drafted, with a Skill Card" % id)
		assert_true(r.tags.has("Ability") and r.tags.has("Nature"), "%s is a Nature ability" % id)
		assert_eq(Abilities.resource_of(id), "fury", "%s uses Fury" % id)
		var tip := Abilities.tooltip(id)
		assert_false(tip.contains("{") or tip.contains("}"), "%s: every number in its text is filled in: %s" % [id, tip])
	var spec: Array = []
	for s in Abilities.SPECS["nature"]:
		if s[0] == "Colossus":
			spec = s[1]
	assert_eq(spec, TANK, "the Colossus spec holds the kit")
	assert_true(Abilities.generated_of("vinefist") > 0, "Vine Fist builds Fury")

func test_sap() -> void:
	var p := _p()
	assert_eq(ColossusKit.sap_after(0, 1), 1)
	assert_eq(ColossusKit.sap_after(4, 3), Balance.SAP_MAX, "never past the cap")
	_near(ColossusKit.sap_heal(1000, 0), 0.0)
	_near(ColossusKit.sap_heal(1000, Balance.SAP_MAX), 1000.0 * Balance.SAP_HEAL_PCT / 100.0 * Balance.SAP_MAX)
	_near(ColossusKit.heartsap_pct(0, 0.0), Balance.HEARTSAP_BASE_PCT)
	_near(ColossusKit.heartsap_pct(5, 0.0), Balance.HEARTSAP_BASE_PCT + 5.0 * Balance.HEARTSAP_PER_SAP)
	_near(ColossusKit.heartsap_pct(5, 10.0), (Balance.HEARTSAP_BASE_PCT + 5.0 * Balance.HEARTSAP_PER_SAP) * 1.1, "Thick Sap")
	assert_eq(ColossusKit.stomp_sap(0), 0)
	assert_eq(ColossusKit.stomp_sap(1), Balance.STOMP_SAP)
	assert_eq(ColossusKit.stomp_sap(Balance.STOMP_SAP_HITS), Balance.STOMP_SAP_MANY)
	assert_eq(ColossusKit.hands_amount(1000, false), int(round(1000.0 * Balance.GIANTS_HANDS_PCT / 100.0)))
	assert_eq(ColossusKit.hands_amount(1000, true), int(round(1000.0 * Balance.GIANTS_HANDS_PCT / 100.0 * (1.0 + Balance.AWAKEN_HANDS_PCT / 100.0))), "Awaken: bigger hands")

func test_colossus_hooks_and_talent() -> void:
	var src := _src()
	assert_contains(src, "_colossus_use(id, res)   # Nature tank")
	assert_contains(src, "_colossus_precheck(id)   # Nature tank")
	assert_contains(src, "\t_tick_colossus()\n")
	assert_contains(src, "_colossus_hit_taken(info)")
	var id := Talents.id_for_key("nature_thick_sap")
	assert_true(id != "", "Thick Sap exists")
	assert_true(Talents.has_capstone(id))
	assert_eq(str(Talents.get_talent(id).get("requires", "")), "heartsap")
	assert_false(Keywords.keyword_text("sap").contains("{"))
	for k in ["stomproots", "giantsslam", "sap"]:
		assert_true(Details.HIT_NAMES.has(k), "%s has its own meter line" % k)

# The Nature archer, Venomstring: three poisons, Venom while all three are up, Venom Burst.
# Rules: player.gd, "Nature archer: Venomstring".

func test_the_archer_kit_is_a_nature_spec() -> void:
	for id in ARCHER:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s loads" % id)
		assert_eq(Abilities.category_of(id), "nature", "%s is Nature" % id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is drafted, with a Skill Card" % id)
		assert_true(r.tags.has("Ability") and r.tags.has("Nature") and r.tags.has("Ranged"), "%s is a Nature bow ability" % id)
		assert_eq(int(r.weapon_requirement), 2, "%s needs a bow" % id)
		var tip := Abilities.tooltip(id)
		assert_false(tip.contains("{") or tip.contains("}"), "%s: every number in its text is filled in: %s" % [id, tip])
	var spec: Array = []
	for s in Abilities.SPECS["nature"]:
		if s[0] == "Venomstring":
			spec = s[1]
	assert_eq(spec, ARCHER, "the Venomstring spec holds the kit")
	for id in ["adderarrow", "asparrow", "kraitarrow"]:
		assert_eq(float(Abilities.get_resource(id).cooldown), 0.0, "%s has no cooldown" % id)

func test_venom_rules() -> void:
	var p := _p()
	assert_false(VenomstringKit.venom_flowing(["adder", "asp"], false), "two kinds: no Venom")
	assert_true(VenomstringKit.venom_flowing(["krait", "adder", "asp"], false), "all three anywhere: Venom flows")
	assert_true(VenomstringKit.venom_flowing([], true), "Venom Surge keeps it flowing")
	_near(VenomstringKit.poison_mult(1), 1.0)
	_near(VenomstringKit.poison_mult(2), 1.0 + Balance.TWO_POISONS_PCT / 100.0)
	_near(VenomstringKit.poison_mult(3), 1.0 + Balance.STEEPED_PCT / 100.0, "Steeped")
	_near(VenomstringKit.burst_damage(10.0, 3, 0.0), 10.0 * (1.0 + 3.0 * Balance.BURST_PER_POISON / 100.0))
	_near(VenomstringKit.burst_damage(10.0, 1, 10.0), 10.0 * (1.0 + Balance.BURST_PER_POISON / 100.0) * 1.1, "Lingering Venom")
	_near(VenomstringKit.poison_every(1.0, false), Balance.POISON_TICK)
	_near(VenomstringKit.poison_every(1.0, true), Balance.POISON_TICK / (1.0 + Balance.KRAIT_HASTE / 100.0), "Krait: faster ticks")
	assert_true(VenomstringKit.poison_total("adder") > VenomstringKit.poison_total("asp") and VenomstringKit.poison_total("asp") > VenomstringKit.poison_total("krait"))
	assert_eq(VenomstringKit.nearest_within(Vector3.ZERO, [Vector3(9, 0, 0), Vector3(3, 0, 0), Vector3(30, 0, 0)], Balance.POISON_SPREAD), 1)
	assert_eq(VenomstringKit.nearest_within(Vector3.ZERO, [Vector3(30, 0, 0)], Balance.POISON_SPREAD), -1, "nobody near: it goes nowhere")

func test_venomstring_hooks_and_talent() -> void:
	var src := _src()
	assert_contains(src, "_venom_use(id, res, w)   # Nature archer")
	assert_contains(src, "_venom_precheck(id)   # Nature archer")
	assert_contains(src, "_poison_landed(enemy, ability_id, base)")
	assert_contains(src, "_fang_landed(enemy)")
	assert_contains(src, "\t_tick_venom(_delta)\n")
	assert_contains(src, "_start_adder_arrow()")
	assert_contains(FileAccess.get_file_as_string("res://scripts/hud.gd"), "_refresh_venom_bar()")
	assert_contains(FileAccess.get_file_as_string("res://scripts/arrow.gd"), "_snake_tint(id)")
	var id := Talents.id_for_key("nature_lingering_venom")
	assert_true(id != "", "Lingering Venom exists")
	assert_true(Talents.has_capstone(id))
	assert_eq(str(Talents.get_talent(id).get("requires", "")), "venomburst")
	for k in ["venom", "venom_flow", "steeped"]:
		assert_false(Keywords.keyword_text(k).contains("{"), k)
	assert_true(Details.HIT_NAMES.has("venomburst_splash"))
