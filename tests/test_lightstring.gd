@tool
extends McpTestSuite

# The Holy archer, Lightstring: a bow and gold prisms. Shots through a gold prism
# refract at another enemy near it (none: the shot is stronger) and charge it;
# Sunlit Arrow drains the light, Prism Breaker shatters one into the enemies,
# Spectrum Volley makes them shoot. Prisms are colour-attuned: heals use only
# white ones, arrows only gold ones, and the limit of 3 counts both. Rules:
# player.gd, "Holy archer: Lightstring" and "Holy healer: the Prisms".

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const Talents = preload("res://scripts/talents.gd")
const Keywords = preload("res://scripts/core/keywords.gd")
const Details = preload("res://scripts/core/details.gd")
const Stats = preload("res://scripts/core/stats.gd")

const KIT := ["glimmershot", "prismarrow", "refractingshot", "sunlitarrow", "prismbreaker", "stepoflight", "spectrumvolley"]

func suite_name() -> String:
	return "lightstring"

func _p() -> GDScript:
	return load("res://scripts/player.gd")

func _src() -> String:
	return PlayerSource.text()

# --- The kit ---------------------------------------------------------------------------

func test_the_kit_is_a_holy_bow_spec() -> void:
	for id in KIT:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s loads" % id)
		assert_eq(Abilities.category_of(id), "holy", "%s is Holy" % id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is drafted, with a Skill Card" % id)
		assert_eq(int(r.weapon_requirement), 2, "%s needs a bow" % id)
		assert_true(r.tags.has("Ability") and r.tags.has("Holy"), "%s is a Holy ability" % id)
		assert_eq(Abilities.resource_of(id), "energy", "%s uses Energy" % id)
		var tip := Abilities.tooltip(id)
		assert_false(tip.contains("{") or tip.contains("}"), "%s: every number in its text is filled in: %s" % [id, tip])
	var spec: Array = []
	for s in Abilities.SPECS["holy"]:
		if s[0] == "Lightstring":
			spec = s[1]
	assert_eq(spec, KIT, "the Lightstring spec holds the kit")
	for id in ["prismarrow", "stepoflight"]:
		assert_true(Abilities.OFF_GCD.has(id), "%s is off the global cooldown" % id)
	var src := FileAccess.get_file_as_string("res://scripts/abilities.gd")
	for id in KIT:
		assert_false(Abilities.ICON_FORM.has(id), "%s is drawn by hand" % id)
		assert_contains(src, "\t\t\"%s\":\n" % id, "%s has a drawn icon" % id)

func test_numbers() -> void:
	# id: [cooldown, energy, weapon multiplier]
	var want := {"prismarrow": [12.0, 15, 0.0], "glimmershot": [0.0, 20, 1.0], "refractingshot": [8.0, 30, 2.0],
		"sunlitarrow": [12.0, 30, 1.2], "prismbreaker": [15.0, 25, 0.0], "stepoflight": [20.0, 0, 0.0],
		"spectrumvolley": [120.0, 0, 0.0]}
	for id in want:
		var r := Abilities.get_resource(id)
		assert_eq(float(r.cooldown), float(want[id][0]), "%s cooldown" % id)
		assert_eq(int(r.resource_cost), int(want[id][1]), "%s energy" % id)
		assert_true(is_equal_approx(float(r.weapon_damage_multiplier), float(want[id][2])), "%s weapon multiplier" % id)
	assert_eq(float(Abilities.get_resource("refractingshot").cast_time), 2.0)
	assert_eq(Balance.PRISM_ARROW_CHARGES, 2)

# --- Refraction -----------------------------------------------------------------------------

func test_refraction_picks_another_enemy() -> void:
	var p := _p()
	var spots := [Vector3(0, 0, 0), Vector3(3, 0, 0), Vector3(6, 0, 0)]
	assert_eq(LightstringKit.refract_target(Vector3(2, 0, 0), spots, 0, 8.0), 1, "the closest one that isn't the target")
	assert_eq(LightstringKit.refract_target(Vector3(0, 0, 0), spots, 0, 8.0), 1, "never the shot's own target")
	assert_eq(LightstringKit.refract_target(Vector3(0, 0, 0), [Vector3(0, 0, 0)], 0, 8.0), -1, "alone: none (the shot focuses)")
	assert_eq(LightstringKit.refract_target(Vector3(0, 0, 0), [Vector3(0, 0, 0), Vector3(20, 0, 0)], 0, 8.0), -1, "too far: none")
	assert_eq(Details.HIT_NAMES.get("refraction", ""), "Refraction", "its own meter line")
	# Refracted and volley arrows are Holy procs.
	assert_contains(_src(), "if ability_id == REFRACTION_ID or ability_id == VOLLEY_ARROW_ID:")

func test_charging() -> void:
	var p := _p()
	var cap: float = PrismsKit.prism_cap(0.0)
	assert_true(is_equal_approx(LightstringKit.gold_charged(0.0, 2.0, Balance.GOLD_CHARGE_PCT, cap), 0.5), "25% of the shot")
	assert_true(is_equal_approx(LightstringKit.gold_charged(cap - 0.1, 2.0, 25.0, cap), cap), "never past the cap")
	assert_true(Balance.AUTO_SHOT_CHARGE_PCT < Balance.GOLD_CHARGE_PCT, "auto-shots charge less")
	assert_true(Balance.AUTO_SHOT_REFRACT_PCT < Balance.REFRACT_PCT, "and refract less")

func test_sunlit_arrow() -> void:
	var p := _p()
	var full: float = PrismsKit.prism_cap(0.0)
	assert_eq(LightstringKit.sunlit_bonus([], 0.0), 0.0)
	assert_true(is_equal_approx(LightstringKit.sunlit_bonus([full], 0.0), full * Balance.SUNLIT_DRAIN))
	assert_true(is_equal_approx(LightstringKit.sunlit_bonus([full], 20.0), full * Balance.SUNLIT_DRAIN * 1.2), "Deep Burn")
	# The big moment stays a big moment: three full prisms add about +0.6, so the
	# whole shot (1.2x a basic bow) is around a standard hit, about 1000 when it crits.
	var bow := 0.45
	var shot: float = 1.2 * bow + LightstringKit.sunlit_bonus([full, full, full], 0.0)
	assert_true(shot > 0.9 and shot < 1.4, "Sunlit Arrow through three full prisms: %.2f" % shot)

func test_prism_breaker_and_volley() -> void:
	var p := _p()
	assert_true(is_equal_approx(LightstringKit.breaker_damage(0.0), Balance.BREAKER_DAMAGE))
	var full: float = PrismsKit.prism_cap(0.0)
	assert_true(LightstringKit.breaker_damage(full) < 1.2, "a full prism: about 1.0")
	assert_true(is_equal_approx(LightstringKit.volley_damage(0.0), Balance.VOLLEY_DAMAGE))

# --- Colours ----------------------------------------------------------------------------------

func test_colours_never_mix() -> void:
	var src := _src()
	# Heals: only white prisms.
	assert_contains(src, "if str(p.get(\"kind\", \"white\")) != \"white\":\n\t\t\tcontinue")
	# Arrows: only gold prisms.
	assert_contains(src, "if str(p.get(\"kind\", \"white\")) != \"gold\" or not on_beam(")
	# The healer's prism abilities aim at white prisms; the archer's Breaker at gold ones.
	assert_contains(src, "func _target_prism(kind: String = \"white\") -> int:")
	assert_contains(src, "var i := _target_prism(\"gold\")")
	# Shatter All only shatters white ones.
	assert_contains(src, "str(_prisms[i].get(\"kind\", \"white\")) == \"white\":\n\t\t\t\t\t_shatter_prism(i)")
	# Set Prism makes white, Prism Arrow gold; the limit counts both.
	assert_contains(src, "_add_prism(ground, \"gold\")")
	assert_contains(src, "_add_prism(ground, \"white\")")
	assert_contains(src, "while _prisms.size() > _prism_max():")

func test_picking_a_prism_by_colour() -> void:
	var p := _p()
	# pick_prism works on whatever list it gets; _target_prism hands it one colour.
	assert_eq(PrismsKit.pick_prism(["p2"], [Vector3(10, 0, 0)], "p1", "", Vector3.ZERO), 0, "a mouseover of the other colour is ignored")

# --- Talents, keywords ---------------------------------------------------------------------

func test_talents() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/talents.gd")
	for key in ["holy_wide_fan", "holy_split_light", "holy_bright_quiver", "holy_deep_burn", "holy_swift_light", "holy_long_volley"]:
		assert_contains(src, "\"key\": \"%s\"" % key)
	assert_true(Talents.LINKS.has(["holy_deep_burn", "holy_long_volley"]), "Deep Burn opens Long Volley")
	assert_eq(Abilities.COOLDOWN_TALENTS.get("stepoflight", ""), "holy_swift_light")

func test_keywords() -> void:
	var r := Keywords.keyword_text("refraction")
	assert_false(r.contains("{"), r)
	var pr := Keywords.keyword_text("prism")
	assert_contains(pr, "Light never moves between the colours")
