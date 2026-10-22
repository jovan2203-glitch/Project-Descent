@tool
extends McpTestSuite

# The Fire melee DPS, Forge Heat: Heat built on your Burning targets, Sparks (no
# melee crits while you hold Heat; a would-be crit is one more Heat) and the Heat
# bands (Red, Orange, White) every ability reacts to.
# Rules: scripts/player/fire_melee.gd.

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const Keywords = preload("res://scripts/core/keywords.gd")
const Details = preload("res://scripts/core/details.gd")

const DPS := ["searingstrike", "foldsteel", "quench", "flare", "rededge", "blastfurnace"]
const NEW := ["foldsteel", "rededge", "blastfurnace"]

func suite_name() -> String:
	return "fire_heat"

func _src() -> String:
	return PlayerSource.text()

func _melee() -> String:
	return (load("res://scripts/player/fire_melee.gd") as GDScript).source_code

func _spec(name: String) -> Array:
	for s in Abilities.SPECS["fire"]:
		if s[0] == name:
			return s[1]
	return []

func test_the_kit_is_the_forge_heat_spec() -> void:
	assert_eq(_spec("Forge Heat"), DPS, "the Forge Heat spec holds the kit")
	for id in DPS:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s loads" % id)
		if r == null:
			continue
		assert_eq(Abilities.category_of(id), "fire", "%s is Fire" % id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is drafted, with a Skill Card" % id)
		assert_true(SkillCards.level_of(id) > 0, "%s's card has a level" % id)
		assert_eq(int(r.weapon_requirement), 1, "%s needs a melee weapon" % id)
		var tip := Abilities.tooltip(id)
		assert_false(tip.contains("{") or tip.contains("}"), "%s: every number in its text is filled in: %s" % [id, tip])
	for id in ["searingstrike", "foldsteel", "quench", "flare", "rededge"]:
		assert_contains(Abilities.tooltip(id), "band", "%s says what it does in the Heat bands" % id)
	assert_true(Abilities.OFF_GCD.has("rededge") and Abilities.OFF_GCD.has("blastfurnace"), "the buffs are off the GCD")

func test_bands() -> void:
	assert_eq(FireMeleeKit.band_of(0), FireMeleeKit.Band.NONE)
	assert_eq(FireMeleeKit.band_of(1), FireMeleeKit.Band.RED)
	assert_eq(FireMeleeKit.band_of(Balance.HEAT_BAND_ORANGE - 1), FireMeleeKit.Band.RED)
	assert_eq(FireMeleeKit.band_of(Balance.HEAT_BAND_ORANGE), FireMeleeKit.Band.ORANGE)
	assert_eq(FireMeleeKit.band_of(Balance.HEAT_BAND_WHITE - 1), FireMeleeKit.Band.ORANGE)
	assert_eq(FireMeleeKit.band_of(Balance.HEAT_BAND_WHITE), FireMeleeKit.Band.WHITE)
	assert_eq(FireMeleeKit.band_of(Balance.HEAT_MAX_STACKS), FireMeleeKit.Band.WHITE)
	assert_eq(FireMeleeKit.fold_hits(FireMeleeKit.Band.RED), Balance.FOLD_STEEL_HITS)
	assert_eq(FireMeleeKit.fold_hits(FireMeleeKit.Band.ORANGE), Balance.FOLD_STEEL_HITS_ORANGE, "one more hit in Orange")
	assert_eq(FireMeleeKit.fold_hits(FireMeleeKit.Band.WHITE), Balance.FOLD_STEEL_HITS_ORANGE)

func test_heat_rules() -> void:
	var melee := _melee()
	assert_contains(melee, "st.has_from(\"burning\", player) or st.has_from(\"immolate\", player)", "Heat builds on your Burning or Blaze")
	assert_contains(melee, "if is_spark(info):\n\t\tgain += 1", "a Spark builds one more Heat")
	assert_contains(melee, "func adjust_crit(", "Sparks are rolled in adjust_crit")
	assert_contains(melee, "if b != Band.WHITE:\n\t\tplayer.status.spend_stacks(HEAT_ID, Balance.FLARE_HEAT_COST)", "Flare is free in White")
	assert_true(Balance.HEAT_BAND_ORANGE < Balance.HEAT_BAND_WHITE and Balance.HEAT_BAND_WHITE <= Balance.HEAT_MAX_STACKS)

func test_hooks_are_in_place() -> void:
	var src := _src()
	assert_contains(src, "_melee_use(id, res, w)   # Fire DPS: Forge Heat")
	assert_contains(src, "chance = adjust_crit(info, chance)   # Fire DPS: Sparks")
	assert_contains(src, "\t_tick_heat()")
	assert_contains(src, "heat_needed_now(id)")

func test_keywords_and_meter() -> void:
	for k in ["heat", "spark", "heat_band"]:
		assert_true(Keywords.KEYWORDS.has(k), "%s is a keyword" % k)
		assert_false(Keywords.keyword_text(k).contains("{"), "%s explains itself" % k)
	assert_true(Details.HIT_NAMES.has("red_edge"), "Red Edge's extra damage has its own meter line")
