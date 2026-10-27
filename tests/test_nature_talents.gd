@tool
extends McpTestSuite

# The Nature book's older talents: the four specs' (Weaver, Shepherd, Colossus,
# Venomstring) and the open ones (Rough Bark, Green Thumb, Undergrowth,
# Clinging Vines). Their rules are static functions in each spec's component
# (scripts/player/nature_*.gd); the hooks are checked in the player's source.
# The tree itself and the newer talents: tests/test_nature_tree.gd.

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const Talents = preload("res://scripts/talents.gd")
const Keywords = preload("res://scripts/core/keywords.gd")
const Details = preload("res://scripts/core/details.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")

func suite_name() -> String:
	return "nature_talents"

func _src() -> String:
	return PlayerSource.text()

func _near(a: float, b: float, msg: String = "") -> void:
	assert_true(absf(a - b) <= 0.001, "%s (%s vs %s)" % [msg, a, b])

# --- The Weaver --------------------------------------------------------------------------

func test_weaver_rules() -> void:
	assert_eq(WeaverKit.thornshot_patch_every(false), Balance.THORNSHOT_PATCH_EVERY)
	assert_eq(WeaverKit.thornshot_patch_every(true), Balance.COMPOST_PATCH_EVERY, "Compost")
	_near(WeaverKit.rich_soil_per(Balance.MOSSBACK_PER_PATCH, 30.0), Balance.MOSSBACK_PER_PATCH * 1.3, "Rich Soil: each patch's share")
	_near(WeaverKit.rooted_coef(0.6, WeaverKit.rich_soil_per(0.6, 30.0), 0), 0.6, "Rich Soil leaves the base alone")
	_near(WeaverKit.overgrown_pct(2.0, 5), 10.0, "Overgrown at 5 patches")
	assert_false(WeaverKit.circling_hawk_turn(Balance.CIRCLING_HAWK_PATCHES - 1))
	assert_true(WeaverKit.circling_hawk_turn(Balance.CIRCLING_HAWK_PATCHES))
	var plain := WeaverKit.thornburst_with(0.0, false)
	_near(float(plain[0]), Balance.THORNBURST_DAMAGE)
	_near(float(plain[1]), Balance.THORNBURST_RADIUS)
	var full := WeaverKit.thornburst_with(30.0, true)
	_near(float(full[0]), Balance.THORNBURST_DAMAGE * 1.3, "Bramble Burst")
	_near(float(full[1]), Balance.BRAMBLE_BURST_RADIUS, "its capstone")
	assert_true(WeaverKit.rolls(100.0, 99.9))
	assert_false(WeaverKit.rolls(0.0, 0.0))
	assert_false(WeaverKit.rolls(15.0, 15.0))

func test_weaver_hooks() -> void:
	var src := _src()
	assert_contains(src, "thornshot_patch_every(_talent(\"nature_compost\") > 0.0)")
	assert_contains(src, "rich_soil_per(per, _talent(\"nature_rich_soil\"))")
	assert_contains(src, "_finisher_coef(MOSSBACK_ID, float(res.damage), Balance.MOSSBACK_PER_PATCH")
	assert_contains(src, "_finisher_coef(VIPERS_ID, float(res.damage), Balance.VIPERS_PER_PATCH")
	assert_contains(src, "rolls(_talent(\"nature_second_growth\"), randf() * 100.0)")
	assert_contains(src, "rolls(_talent(\"nature_fertile_ground\"), randf() * 100.0)")
	assert_contains(src, "_cut_cooldown(THORNWING_ID, cut)")

# --- The Shepherd ------------------------------------------------------------------------

func test_shepherd_rules() -> void:
	_near(ShepherdKit.dewfall_mult(2), 1.0 + Balance.DEWFALL_PER_BLOSSOM / 100.0 * 2)
	_near(ShepherdKit.dewfall_mult(2, 20.0), 1.4, "Morning Dew")
	_near(ShepherdKit.evergreen_heal(1000.0, 3, 0.25), 7.5, "Evergreen: 3 Blossoms")
	_near(ShepherdKit.evergreen_heal(1000.0, 0, 0.25), 0.0)
	_near(ShepherdKit.owl_dive_mult(false, 60.0), 1.0, "the first dive is whole")
	_near(ShepherdKit.owl_dive_mult(true, 60.0), 0.6, "Return Flight's second dive")

func test_cooldown_and_cast_time_talents() -> void:
	# Big Herd and Quick Return were folded into Wild Herd and Return to Bloom.
	assert_eq(float(Abilities.get_resource("wildherd").cooldown), 90.0)
	assert_eq(float(Abilities.get_resource("returntobloom").cast_time), 4.0)
	assert_eq(Talents.id_for_key("nature_big_herd"), "")
	assert_eq(Talents.id_for_key("nature_quick_return"), "")

func test_shepherd_hooks() -> void:
	var src := _src()
	assert_contains(src, "_tick_evergreen(now)")
	assert_contains(src, "_heal_exact(who, int(round(amount)), EVERGREEN_ID)")
	assert_contains(src, "dewfall_mult(blossoms_on(who), _talent(\"nature_morning_dew\"))")
	assert_contains(src, "_talent(\"nature_old_bark\")")
	assert_contains(src, "Balance.FULL_BLOOM_TIME + _talent(\"nature_deep_bloom\")")
	assert_eq(str(Details.HIT_NAMES.get("evergreen", "")), "Evergreen", "Evergreen has its own meter line")

# --- The Colossus ------------------------------------------------------------------------

func test_colossus_rules() -> void:
	_near(ColossusKit.sap_heal(1000, 5), 1000.0 * Balance.SAP_HEAL_PCT / 100.0 * 5)
	_near(ColossusKit.sap_heal(1000, 5, 0.3), 1000.0 * (Balance.SAP_HEAL_PCT + 0.3) / 100.0 * 5, "Rising Sap")
	_near(ColossusKit.crushing_grip_mult(3, 15.0), 1.45, "Crushing Grip")
	_near(ColossusKit.crushing_grip_mult(99, 15.0), 1.0 + 0.15 * Balance.CRUSHING_GRIP_HITS, "capped")
	var roots := ColossusKit.stomp_roots_with(8.0, 4.0, 2.0)
	_near(float(roots[0]), Balance.STOMP_ROOTS_TIME + 4.0)
	_near(float(roots[1]) / float(roots[0]), Balance.STOMP_ROOTS_DAMAGE / Balance.STOMP_ROOTS_TIME, "Spreading Roots: same damage per second")
	_near(float(roots[2]), 10.0)
	_near(ColossusKit.old_growth_pct(5, 2.0), 10.0, "Old Growth at 5 Sap")
	_near(ColossusKit.old_growth_pct(9, 2.0), 10.0, "never past SAP_MAX")

func test_colossus_hooks() -> void:
	var src := _src()
	assert_contains(src, "Balance.VINE_FIST_EXTRA + int(round(_talent(\"nature_broad_fist\")))")
	assert_contains(src, "_gain(\"fury\", back)")
	assert_contains(src, "crushing_grip_mult(_hands_hits, _talent(\"nature_crushing_grip\"))")
	assert_contains(src, "Balance.AWAKEN_TIME + _talent(\"nature_wide_awake\")")
	assert_contains(src, "_nature_talents_incoming(info)   # Old Growth")
	var grasped: Resource = load("res://data/effects/grasped.tres")
	_near(Abilities.effect_time_bonus(grasped, func(key: String, _f: String) -> float: return 1.0 if key == "nature_firm_hold" else 0.0), 1.0, "Firm Hold holds longer")

# --- Venomstring -------------------------------------------------------------------------

func test_venomstring_rules() -> void:
	_near(VenomstringKit.poison_mult(3), 1.0 + Balance.STEEPED_PCT / 100.0)
	_near(VenomstringKit.poison_mult(3, 10.0), 1.0 + (Balance.STEEPED_PCT + 10.0) / 100.0, "Soaked Through")
	_near(VenomstringKit.poison_mult(2, 10.0), 1.0 + Balance.TWO_POISONS_PCT / 100.0, "only on Steeped")
	_near(VenomstringKit.hungry_coef(1.0, 20.0, false), 1.2, "Hungry Venom")
	_near(VenomstringKit.hungry_coef(1.2, 20.0, true), 1.2, "only once")

func test_venomstring_hooks() -> void:
	var src := _src()
	assert_contains(src, "Balance.FANG_EXTEND + _talent(\"nature_long_fangs\")")
	assert_contains(src, "maxf(Balance.POISON_SPREAD, _talent(\"nature_hungry_venom\"))")
	assert_contains(src, "poison_mult(kinds, _talent(\"nature_soaked_through\"), _talent(\"nature_double_dose\"))")
	assert_contains(src, "_talent(\"nature_spring_trap\")")

# --- The open talents --------------------------------------------------------------------

func test_open_talent_rules() -> void:
	_near(NatureTalentsOpenKit.green_thumb_mult("sap", 12.0), 1.12, "Green Thumb: Sap")
	_near(NatureTalentsOpenKit.green_thumb_mult("puppetstring", 12.0), 1.12, "Green Thumb: the Strings")
	_near(NatureTalentsOpenKit.green_thumb_mult("dewfall", 12.0), 1.0, "not a heal over time")
	assert_true(NatureTalentsOpenKit.undergrowth_applies(true, true))
	assert_false(NatureTalentsOpenKit.undergrowth_applies(false, true), "only damage over time")
	assert_false(NatureTalentsOpenKit.undergrowth_applies(true, false), "only on my own root or slow")
	assert_true(NatureTalentsOpenKit.overgrown_applies(PackedStringArray(["Nature", "Spell"])))
	assert_false(NatureTalentsOpenKit.overgrown_applies(PackedStringArray(["Nature", "Ability"])), "spells only")
	assert_eq(NatureTalentsOpenKit.snagged_stacks(20.0), 1)
	assert_eq(NatureTalentsOpenKit.snagged_stacks(40.0), 2)
	assert_eq(NatureTalentsOpenKit.snagged_stacks(0.0), 0)
	var id := Talents.id_for_key("nature_rough_bark")
	_near(float(Talents.get_talent(id)["stats"].get("armor%", 0.0)), 3.0, "Rough Bark: Armor % per rank")

func test_undergrowth_and_vines_are_own_only() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/core/status_container.gd")
	assert_contains(src, "func has_cc_from(source: Node) -> bool:")
	assert_contains(src, "and applied_by(e, source)")
	assert_contains(src, "and not owned_elsewhere(e):")
	assert_contains(src, ".root_ended(get_parent(), r[1])")
	var fx: Resource = load("res://data/effects/snagged.tres")
	assert_true(bool(fx.is_debuff) and not bool(fx.root), "a slow, not a root (it can't set itself off)")
	assert_eq(int(fx.max_stacks), 2)
	_near(float(fx.stat_modifiers.get("move_speed", 0.0)), -Balance.CLINGING_VINES_SLOW_STEP)

func test_keyword() -> void:
	var t := Keywords.keyword_text("heal_over_time")
	assert_false(t.contains("{"), t)
	for id in ["sap", "evergreen", "puppetstring", "refrain"]:
		assert_true(Abilities.HEAL_OVER_TIME_IDS.has(id), "%s is a heal over time" % id)
