@tool
extends McpTestSuite

# Martial tank: the Brawler (scripts/player/martial_brawler.gd). Bruise spreads
# part of every hit over time; Punch, Kick and Elbow go into a Chain whose last
# strike picks the move (three different: the strong one); Catch works on an
# enemy's melee tell and starts a Chain of its own. And the melee tells
# themselves (enemy.gd), which every enemy has.

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Effects = preload("res://scripts/core/effects.gd")
const Details = preload("res://scripts/core/details.gd")
const Keywords = preload("res://scripts/core/keywords.gd")

const STRIKES := ["punch", "brawlkick", "elbow"]
const BUTTONS := ["punch", "brawlkick", "elbow", "catch", "onemore", "toughitout", "comeon", "fightingstyle"]
const MOVES := ["rapidfists", "haymaker", "sweep", "roundhouse", "clinch", "shakeoff", "turnitaround", "throw", "takedown"]
const LEVELS := {"punch": 2, "catch": 4, "comeon": 6, "toughitout": 8, "onemore": 10}

func suite_name() -> String:
	return "brawler"

# --- The Chain --------------------------------------------------------------------------

func test_the_last_strike_picks_the_move_and_three_different_make_the_strong_one() -> void:
	var seen := {}
	for a in STRIKES:
		for b in STRIKES:
			for c in STRIKES:
				var move := BrawlerKit.chain_move([a, b, c])
				var mixed: bool = a != b and b != c and a != c
				assert_eq(move, str(Abilities.BRAWLER_MOVES[c][1 if mixed else 0]), "%s-%s-%s" % [a, b, c])
				seen[move] = true
	assert_eq(seen.size(), 6, "all 27 orders of three strikes make one of the 6 moves")
	assert_eq(BrawlerKit.chain_move(["punch", "punch", "punch"]), "rapidfists")
	assert_eq(BrawlerKit.chain_move(["brawlkick", "elbow", "punch"]), "haymaker")
	assert_eq(BrawlerKit.chain_move(["elbow", "punch", "brawlkick"]), "roundhouse")
	assert_eq(BrawlerKit.chain_move(["punch", "brawlkick", "elbow"]), "shakeoff")
	assert_eq(BrawlerKit.chain_move(["punch", "punch"]), "", "not full yet")

func test_catch_chains_pick_by_their_last_strike() -> void:
	for b in STRIKES:
		for c in STRIKES:
			assert_eq(BrawlerKit.chain_move(["catch", b, c]), str(Abilities.BRAWLER_CATCH_MOVES[c]), "catch-%s-%s" % [b, c])
	assert_eq(BrawlerKit.chain_move(["catch", "punch", "punch"]), "turnitaround")
	assert_eq(BrawlerKit.chain_move(["catch", "elbow", "brawlkick"]), "throw")
	assert_eq(BrawlerKit.chain_move(["catch", "punch", "elbow"]), "takedown")

func test_catch_always_starts_a_new_chain() -> void:
	assert_eq(BrawlerKit.chain_after(["punch", "elbow"], "catch"), ["catch"] as Array[String], "the strikes in it are lost")
	assert_eq(BrawlerKit.chain_after([], "punch"), ["punch"] as Array[String])
	assert_eq(BrawlerKit.chain_after(["punch"], "elbow"), ["punch", "elbow"] as Array[String])
	assert_eq(BrawlerKit.chain_after(["punch", "elbow", "punch"], "brawlkick"), ["brawlkick"] as Array[String], "a full chain starts over")

func test_the_buttons_show_the_move_only_at_the_last_step() -> void:
	assert_eq(BrawlerKit.would_finish(["punch", "elbow"], "brawlkick"), "roundhouse")
	assert_eq(BrawlerKit.would_finish(["punch", "elbow"], "punch"), "rapidfists")
	assert_eq(BrawlerKit.would_finish(["punch"], "punch"), "", "too early: nothing shown")
	assert_eq(BrawlerKit.would_finish([], "elbow"), "")
	assert_eq(BrawlerKit.would_finish(["punch", "elbow"], "catch"), "", "Catch never finishes a chain")

func test_chain_numbers() -> void:
	assert_eq(Balance.CHAIN_LENGTH, 3)
	assert_eq(Balance.CHAIN_TIMEOUT, 5.0)
	assert_eq(Balance.STRIKE_GCD, 1.0)
	assert_true(absf(BrawlerKit.strike_gcd(Balance.GCD_BASE) - 1.0) < 0.001, "the strikes' GCD is 1 s")
	assert_true(absf(BrawlerKit.strike_gcd(1.2) - 0.8) < 0.001, "Haste shortens it the same way")
	for id in ["punch", "brawlkick", "elbow", "catch"]:
		assert_true(BrawlerKit.short_gcd(id), "%s is on the short GCD" % id)
	assert_false(BrawlerKit.short_gcd("onemore"), "One More is on the normal GCD")
	assert_true(Abilities.OFF_GCD.has("fightingstyle"), "Fighting Style is off the GCD")

# --- Bruise -----------------------------------------------------------------------------

func test_bruise_takes_part_of_each_hit_and_spreads_it() -> void:
	assert_eq(Balance.BRUISE_PCT, 40.0)
	assert_eq(BrawlerKit.bruise_split(100), [60, 40])
	assert_eq(BrawlerKit.bruise_split(0), [0, 0])
	var split: Array = BrawlerKit.bruise_split(77)
	assert_eq(int(split[0]) + int(split[1]), 77, "nothing is lost")
	# 6 s in 0.5 s ticks: 12 even ticks.
	assert_true(absf(BrawlerKit.bruise_per_tick(120.0, Balance.BRUISE_TIME) - 10.0) < 0.001)
	assert_true(absf(BrawlerKit.bruise_per_tick(10.0, 0.1) - 10.0) < 0.001, "the last tick takes what is left")

func test_bruise_ticks_give_fury_and_tough_it_out_doubles_it() -> void:
	assert_true(absf(BrawlerKit.bruise_fury(50.0, 5000.0, false) - 1.0) < 0.001, "1 Fury per 1% of max health")
	assert_true(absf(BrawlerKit.bruise_fury(50.0, 5000.0, true) - Balance.TOUGH_IT_OUT_FURY) < 0.001)

func test_bruise_is_hooked_into_damage_taken_before_the_caps() -> void:
	var src := PlayerSource.text()
	var at := src.find("amount = bruise_take(amount)")
	assert_true(at > 0, "take_damage sends hits through Bruise")
	assert_true(at < src.find("amount = _still_standing_limit(amount)"), "before Still Standing and Unfallen, so its ticks still respect them")
	assert_contains(src, "if _ticking or amount <= 0 or not is_out():", "Bruise's own ticks don't go into Bruise")

# --- Catch ------------------------------------------------------------------------------

func test_catch_costs_the_chain_and_the_caught_hit_skips_bruise() -> void:
	var src := PlayerSource.text()
	assert_contains(src, "if _landing_caught:\n\t\t_landing_caught = false\n\t\t_caught_amount = amount\n\t\treturn amount", "the caught hit lands in full")
	assert_contains(src, "if bool(info.is_dot) or not PackedStringArray(info.tags).has(\"Melee\")", "only the enemy's melee hit is caught")
	assert_true(FileAccess.get_file_as_string("res://scripts/core/combat_system.gd").contains("tgt.before_hit_lands(info)"))
	assert_contains(src, "\"Your target shows no melee tell at you\"", "only usable on a melee tell")
	assert_eq(Balance.CATCH_GRACE, 0.3)

func test_one_more_repeats_with_the_same_caught_hit() -> void:
	var src := PlayerSource.text()
	assert_contains(src, "var caught := _last_caught_amount if again else _caught_amount")
	assert_eq(BrawlerKit.one_more_extra("haymaker"), Balance.HAYMAKER_FURY, "a repeated Haymaker spends its own Fury too")
	assert_eq(BrawlerKit.one_more_extra("sweep"), 0.0)
	assert_eq(Abilities.cost_of("onemore"), 25.0)
	assert_eq(float(Abilities.get_resource("onemore").cooldown), 15.0)

func test_bosses_are_never_thrown_or_put_down() -> void:
	var src := PlayerSource.text()
	assert_contains(src, "or str(e.get(\"rank\")) == \"boss\":\n\t\treturn", "no knockdown on bosses")
	assert_contains(src, "Balance.REVERSAL_COEF, REVERSAL_ID", "a boss takes a Reversal instead of a Throw")
	assert_contains(src, "_bruise = maxf(_bruise - float(caught), 0.0)   # a boss can't be put down")
	assert_eq(Details.HIT_NAMES.get("reversal", ""), "Reversal", "Reversal has its own meter line")

# --- Content ----------------------------------------------------------------------------

func test_every_brawler_ability_is_martial_and_needs_no_shield() -> void:
	var spec: Array = []
	for s in Abilities.SPECS["martial"]:
		if s[0] == "Brawler":
			spec = s[1]
	assert_eq(spec.size(), BUTTONS.size() + MOVES.size(), "the Brawler spec lists every button and move")
	for id in BUTTONS + MOVES:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s exists" % id)
		assert_eq(Abilities.category_of(id), "martial")
		assert_true(bool(r.forbids_shield), "%s can't be used with a shield" % id)
		assert_contains(Abilities.tooltip(id), Abilities.NO_SHIELD_LINE)
		assert_true(r.tags.has("Ability") and r.tags.has("Physical"), "%s is a physical ability" % id)
		assert_eq(int(r.weapon_requirement), 1, "%s needs a melee weapon" % id)
	assert_contains(PlayerSource.text(), "_error(\"Can't be used with a shield\")")

func test_moves_have_no_buttons() -> void:
	for id in MOVES:
		assert_true(Abilities.is_chain_move(id), id)
		assert_false(Abilities.listed_in_book(id), "%s is shown in the Chain's table, not the list" % id)
	for id in BUTTONS:
		assert_false(Abilities.is_chain_move(id), id)
	var table: Array = Abilities.brawler_move_table()
	assert_eq((table[0][1] as Array).size() + (table[1][1] as Array).size(), MOVES.size(), "the table shows every move")

func test_names_and_learning() -> void:
	var names := {"punch": "Punch", "brawlkick": "Kick", "elbow": "Elbow", "catch": "Catch", "onemore": "One More",
		"toughitout": "Tough It Out", "comeon": "Come On", "fightingstyle": "Fighting Style",
		"rapidfists": "Rapid Fists", "haymaker": "Haymaker", "sweep": "Sweep", "roundhouse": "Roundhouse",
		"clinch": "Clinch", "shakeoff": "Shake Off", "turnitaround": "Turn It Around", "throw": "Throw", "takedown": "Takedown"}
	for id in names:
		assert_eq(Abilities.ability_name(id), names[id])
	for id in LEVELS:
		assert_true(SkillCards.exists(id), "%s has a Skill Card" % id)
		assert_eq(SkillCards.level_of(id), LEVELS[id], "%s from level %d" % [id, LEVELS[id]])
		assert_true(Abilities.DRAFT_POOL.has(id))
	var pd_src := FileAccess.get_file_as_string("res://scripts/player_data.gd")
	assert_contains(pd_src, "return learned_abilities.has(\"punch\")", "Punch brings Kick, Elbow, Fighting Style and the moves")
	assert_contains(pd_src, "return learned_abilities.has(\"catch\")", "Catch brings the Catch moves")

func test_numbers_are_in_balance() -> void:
	for id in STRIKES:
		assert_eq(Abilities.generated_of(id), 10, "%s gives 10 Fury" % id)
	assert_eq(Balance.HAYMAKER_FURY, 30.0)
	assert_eq(Abilities.cost_of("toughitout"), 40.0)
	assert_eq(float(Abilities.get_resource("toughitout").cooldown), 30.0)
	assert_eq(Effects.get_effect("taken_down").duration, Balance.TAKEDOWN_TIME)
	assert_eq(Effects.get_effect("kicked_down").duration, Balance.KICKED_DOWN_TIME)
	for kid in ["bruise", "chain", "caught_hit", "melee_tell"]:
		assert_true(Keywords.KEYWORDS.has(kid), "keyword %s" % kid)

# --- Melee tells (every enemy) ----------------------------------------------------------

func test_a_melee_tell_shows_at_its_target_and_is_not_a_cast() -> void:
	var e: Node3D = track(load("res://scripts/enemy.gd").new())
	var me := Node3D.new()
	var other := Node3D.new()
	track(me)
	track(other)
	assert_eq(e.melee_tell, Balance.MELEE_TELL_TIME)
	assert_false(e.melee_tell_at(me))
	e._show_tell(me, 0.6)
	assert_true(e.melee_tell_at(me), "aimed at me")
	assert_false(e.melee_tell_at(other), "only at its target")
	assert_gt(float(e.melee_tell_end(me)), 0.0)
	assert_false(e.is_casting(), "not a cast: interrupts don't see it")
	e._cancel_swing()
	assert_false(e.melee_tell_at(me), "cancelled")

func test_melee_hits_wait_for_the_tell() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/enemy.gd")
	assert_contains(src, "if melee_tell > 0.0:\n\t\tif _swing_at <= 0.0:\n\t\t\t_start_swing(tgt)\n\t\treturn", "a melee attack starts a tell")
	assert_contains(src, "if stunned or state != State.ATTACK or not is_instance_valid(tgt) or _is_dead(tgt):\n\t\t_cancel_swing()", "a stun stops the hit")
	assert_contains(src, "_net.enemy_fx(self, \"swing\", tgt, {\"d\": melee_tell})", "the party is told")
	assert_contains(src, "melee_tell /= FRENZY_ATTACK")
	assert_contains(src, "melee_tell /= 1.0 + EB.ELITE_HASTE_ATTACK / 100.0")
	# The attack timer starts with the tell, so enemies hit as often as before.
	var attack := src.substr(src.find("func _attack(tgt: Node3D) -> void:"), 200)
	assert_contains(attack, "_attack_timer = attack_cooldown")
