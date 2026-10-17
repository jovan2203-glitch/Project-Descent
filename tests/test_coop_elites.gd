@tool
extends McpTestSuite

# Downed / revive, pings and elite traits: the rules that can be checked
# without running a party.

const EliteTraits = preload("res://scripts/core/elite_traits.gd")
const Balance = preload("res://scripts/balance.gd")
const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")

func suite_name() -> String:
	return "coop_elites"

func test_unstoppable_resists_cc_only() -> void:
	var frozen: Resource = load("res://data/effects/frozen.tres")
	var stunned: Resource = load("res://data/effects/stunned.tres")
	var burning: Resource = load("res://data/effects/burning.tres")
	Balance.apply_effects()
	assert_true(EliteTraits.resists("unstoppable", frozen), "Unstoppable ignores Frozen (a slow)")
	assert_true(EliteTraits.resists("unstoppable", stunned), "Unstoppable ignores stuns")
	assert_false(EliteTraits.resists("unstoppable", burning), "DoTs still apply")
	assert_false(EliteTraits.resists("hasted", frozen), "other traits aren't immune")

func test_trait_roll_is_seeded() -> void:
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 12345
	b.seed = 12345
	for i in 20:
		assert_eq(EliteTraits.roll(a), EliteTraits.roll(b), "same seed, same traits (party sync)")

func test_every_trait_has_text() -> void:
	for t in EliteTraits.TRAITS:
		assert_true(EliteTraits.title(t) != "" and EliteTraits.desc(t) != "", "%s has a name and description" % t)

func test_bleed_out_never_below_minimum() -> void:
	for downs in 10:
		var t := maxf(Balance.DOWNED_BLEED_OUT - Balance.DOWNED_REPEAT_PENALTY * downs, Balance.DOWNED_MIN_BLEED_OUT)
		assert_true(t >= Balance.DOWNED_MIN_BLEED_OUT)

func test_only_healer_abilities_revive() -> void:
	# No F-revive: no Interact keybind, no revive channel in the player.
	var settings := FileAccess.get_file_as_string("res://scripts/settings.gd")
	assert_false(settings.contains("\"interact\""), "the Interact (revive) keybind is gone")
	var src := PlayerSource.text()
	assert_false(src.contains("_try_revive"), "nobody revives by pressing a key")
	assert_false(src.contains("\"revive\""), "no revive channel")
	var player_script: GDScript = load("res://scripts/player.gd")
	assert_true(player_script.on_gcd("frostbolt"))

func test_out_of_combat_rez_rules() -> void:
	assert_eq(RezKit.rez_error(true, true), RezKit.IN_COMBAT_ERROR, "never in combat")
	assert_eq(RezKit.rez_error(false, false), RezKit.NO_TARGET_ERROR, "needs a fallen ally")
	assert_eq(RezKit.rez_error(false, true), "")
	for id in RezKit.IDS:
		var r := Abilities.get_resource(id)
		assert_true(r != null, id)
		assert_true(r.tags.has("Resurrect"), "%s is a rez" % id)
		assert_eq(int(r.cast_type), 1, "%s has a cast time" % id)
		assert_true(SkillCards.ALL.has(id) and Abilities.DRAFT_POOL.has(id), "%s is draftable and has a card" % id)
		var tip := Abilities.tooltip(id)
		assert_false(tip.contains("{") or tip.contains("}"), "%s: %s" % [id, tip])
	assert_true(Balance.RAISE_HEALTH_PCT > 0.0 and Balance.RAISE_MANA_PCT > 0.0)
