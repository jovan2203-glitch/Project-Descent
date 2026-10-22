@tool
extends McpTestSuite

# The Fire archer, Pitch and Cinder: arrows that don't crit coat the target in
# layers of Pitch (faster burns), an arrow crit Ignites it (Fire damage around the
# target, Burning spread), Touch Off Ignites on purpose.
# Rules: scripts/player/fire_bow.gd.

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const Keywords = preload("res://scripts/core/keywords.gd")
const Details = preload("res://scripts/core/details.gd")

const BOW := ["flamingarrow", "coalshot", "pitcharrow", "cinderrain", "touchoff", "brushfire"]

func suite_name() -> String:
	return "fire_pitch"

func _bow() -> String:
	return (load("res://scripts/player/fire_bow.gd") as GDScript).source_code

func _spec(name: String) -> Array:
	for s in Abilities.SPECS["fire"]:
		if s[0] == name:
			return s[1]
	return []

func test_the_kit_is_the_pitch_and_cinder_spec() -> void:
	assert_eq(_spec("Pitch and Cinder"), BOW, "the Pitch and Cinder spec holds the kit")
	for id in BOW:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s loads" % id)
		if r == null:
			continue
		assert_eq(Abilities.category_of(id), "fire", "%s is Fire" % id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is drafted, with a Skill Card" % id)
		assert_eq(int(r.weapon_requirement), 2, "%s needs a bow" % id)
		var tip := Abilities.tooltip(id)
		assert_false(tip.contains("{") or tip.contains("}"), "%s: every number in its text is filled in: %s" % [id, tip])
	assert_eq(float(Abilities.get_resource("coalshot").cooldown), 0.0, "Coal Shot is the filler: no cooldown")
	assert_true(Abilities.get_resource("pitcharrow").on_hit_effect == null, "Pitch Arrow's layers come from the kit, not an on-hit effect")

func test_layers_and_ignites() -> void:
	assert_eq(FireBowKit.layers_from("flamingarrow", false), 1, "an arrow that doesn't crit adds a layer")
	assert_eq(FireBowKit.layers_from("auto_ranged", false), 1, "auto-shots too")
	assert_eq(FireBowKit.layers_from("auto_ranged", true), Balance.BRUSHFIRE_LAYERS, "more during Brushfire")
	assert_eq(FireBowKit.layers_from("pitcharrow", false), Balance.PITCH_ARROW_LAYERS)
	assert_eq(FireBowKit.layers_from("touchoff", false), 0, "Touch Off only Ignites")
	assert_eq(FireBowKit.ignite_coef(0), 0.0)
	assert_true(absf(FireBowKit.ignite_coef(4) - Balance.PITCH_IGNITE_PER_LAYER * 4.0) < 0.0001, "an Ignite is per layer")
	assert_true(absf(FireBowKit.ignite_coef(4, Balance.TOUCH_OFF_PCT) - Balance.PITCH_IGNITE_PER_LAYER * 4.0 * (1.0 + Balance.TOUCH_OFF_PCT / 100.0)) < 0.0001, "Touch Off: more")
	var bow := _bow()
	assert_contains(bow, "if info.crit:\n\t\tignite(tgt)", "an arrow crit Ignites")
	assert_contains(bow, "Balance.aoe_share(hit.size())", "an Ignite's damage is split past the cap")
	assert_contains(bow, "if not burning:\n\t\t\t_burn(e)", "an Ignite spreads Burning")

func test_hooks_are_in_place() -> void:
	var src := PlayerSource.text()
	assert_contains(src, "damage_dealt.connect(_pitch_on_hit)")
	assert_contains(src, "_bow_use(id)   # Fire archer: Pitch and Cinder")
	assert_contains(src, "_bow_precheck(id)   # Fire archer")

func test_keywords_and_meter() -> void:
	for k in ["pitch", "ignite"]:
		assert_true(Keywords.KEYWORDS.has(k), "%s is a keyword" % k)
		assert_false(Keywords.keyword_text(k).contains("{"), "%s explains itself" % k)
	assert_true(Details.HIT_NAMES.has("pitch_ignite"), "an Ignite has its own meter line")
