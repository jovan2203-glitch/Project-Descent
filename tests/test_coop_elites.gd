@tool
extends McpTestSuite

# Downed / revive, pings and elite traits: the rules that can be checked
# without running a party.

const EliteTraits = preload("res://scripts/core/elite_traits.gd")
const Balance = preload("res://scripts/balance.gd")

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

func test_revive_is_off_the_gcd() -> void:
	var player_script: GDScript = load("res://scripts/player.gd")
	assert_false(player_script.on_gcd("revive"), "reviving doesn't trigger the global cooldown")
	assert_true(player_script.on_gcd("frostbolt"))
