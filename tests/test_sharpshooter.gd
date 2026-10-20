@tool
extends McpTestSuite

# Martial archer: Sharpshooter (scripts/player/martial_sharpshooter.gd). No resource:
# every shot is on a cooldown and each hit cuts another shot's (Abilities.SHARP_LINKS);
# a cut on a ready shot becomes Overcut on it. Streak builds per engine shot; Loose
# halves it; at full Streak Heavy Draw is instant and a sure crit.

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Keywords = preload("res://scripts/core/keywords.gd")

const IDS := ["quickshot", "pierce", "spread", "heavydraw", "followup", "loose", "breathe", "fasthands"]
const ENGINE := ["quickshot", "pierce", "spread", "heavydraw", "followup"]
const LEVELS := {"quickshot": 2, "pierce": 4, "spread": 6, "heavydraw": 8, "followup": 10, "breathe": 12, "fasthands": 16}

func suite_name() -> String:
	return "sharpshooter"

func _spec(name: String) -> Array:
	for s in Abilities.SPECS["martial"]:
		if s[0] == name:
			return s[1]
	return []

# --- Cuts and Overcut -------------------------------------------------------------------

func test_a_cut_shortens_a_cooldown_and_the_rest_becomes_overcut() -> void:
	var r := SharpshooterKit.cut_result(5.0, 3.0)
	assert_eq(float(r["left"]), 2.0)
	assert_eq(float(r["overcut"]), 0.0, "still cooling: no Overcut")
	r = SharpshooterKit.cut_result(1.0, 3.0)
	assert_eq(float(r["left"]), 0.0, "ready")
	assert_eq(float(r["overcut"]), 2.0, "what went past ready")
	r = SharpshooterKit.cut_result(0.0, 3.0)
	assert_eq(float(r["overcut"]), 3.0, "a ready shot takes it all as Overcut")

func test_a_reset_readies_a_cooling_shot_or_fills_a_ready_one() -> void:
	var r := SharpshooterKit.reset_result(7.0, 16.0)
	assert_eq(float(r["left"]), 0.0)
	assert_eq(float(r["overcut"]), 0.0, "a cooling shot is just ready")
	r = SharpshooterKit.reset_result(0.0, 16.0)
	assert_eq(float(r["overcut"]), 16.0, "a ready shot gets its whole cooldown")

func test_overcut_caps_and_adds_damage_per_second() -> void:
	assert_eq(SharpshooterKit.overcut_after(10.0, 16.0), Balance.OVERCUT_MAX)
	assert_eq(SharpshooterKit.overcut_after(2.0, 3.0), 5.0)
	assert_eq(SharpshooterKit.overcut_bonus(5.0), 5.0 * Balance.OVERCUT_PCT)
	assert_eq(SharpshooterKit.overcut_bonus(99.0), Balance.OVERCUT_MAX * Balance.OVERCUT_PCT, "capped")
	assert_eq(SharpshooterKit.overcut_bonus(Balance.OVERCUT_MAX), 100.0, "a full charge doubles the shot")

func test_pierce_cuts_more_per_enemy_up_to_its_cap() -> void:
	assert_eq(SharpshooterKit.pierce_cut(0), 0.0)
	assert_eq(SharpshooterKit.pierce_cut(1), Balance.SHARP_PIERCE_CUT_FIRST, "a lone enemy still gives the first cut")
	assert_eq(SharpshooterKit.pierce_cut(2), Balance.SHARP_PIERCE_CUT_FIRST + Balance.SHARP_PIERCE_CUT_PER)
	assert_eq(SharpshooterKit.pierce_cut(20), Balance.SHARP_PIERCE_CUT_MAX)

func test_pierce_hits_what_is_on_its_line() -> void:
	var dir := Vector3(1, 0, 0)
	assert_true(SharpshooterKit.on_line(Vector3.ZERO, dir, 30.0, 1.5, Vector3(10, 0, 0.5)))
	assert_false(SharpshooterKit.on_line(Vector3.ZERO, dir, 30.0, 1.5, Vector3(10, 0, 2.0)), "off to the side")
	assert_true(SharpshooterKit.on_line(Vector3.ZERO, dir, 30.0, 1.5, Vector3(10, 0, 1.2), 0.6), "a big hitbox reaches it")
	assert_false(SharpshooterKit.on_line(Vector3.ZERO, dir, 30.0, 1.5, Vector3(-5, 0, 0)), "behind me")
	assert_false(SharpshooterKit.on_line(Vector3.ZERO, dir, 30.0, 1.5, Vector3(40, 0, 0)), "past the bow's range")

func test_spread_puts_every_arrow_somewhere() -> void:
	assert_eq(SharpshooterKit.spread_order(["a"], 3), ["a", "a", "a"], "a lone enemy takes them all")
	assert_eq(SharpshooterKit.spread_order(["a", "b"], 3), ["a", "b", "a"])
	assert_eq(SharpshooterKit.spread_order(["a", "b", "c"], 3), ["a", "b", "c"])
	assert_eq(SharpshooterKit.spread_order([], 3), [])

func test_fast_hands_doubles_cuts() -> void:
	assert_eq(SharpshooterKit.cut_mult(false), 1.0)
	assert_eq(SharpshooterKit.cut_mult(true), Balance.FAST_HANDS_MULT)

# --- Streak -----------------------------------------------------------------------------

func test_engine_shots_build_streak_and_loose_halves_it() -> void:
	for id in ENGINE:
		assert_eq(SharpshooterKit.streak_after(3, id), 4, id)
	assert_eq(SharpshooterKit.streak_after(Balance.STREAK_MAX, "heavydraw"), Balance.STREAK_MAX, "it stays at full")
	assert_eq(SharpshooterKit.streak_after(7, "loose"), 3, "halved, rounded down")
	assert_eq(SharpshooterKit.streak_after(1, "loose"), 0)
	assert_eq(SharpshooterKit.streak_after(5, "breathe"), 5, "Breathe and Fast Hands don't count")
	assert_eq(SharpshooterKit.streak_after(5, "fasthands"), 5)

# --- Hooks ------------------------------------------------------------------------------

func test_the_player_runs_the_engine() -> void:
	var src := PlayerSource.text()
	assert_contains(src, "_sharp_use(id, res)   # Martial archer: Sharpshooter")
	assert_contains(src, "_on_damage_dealt_sharp)   # Martial archer: hits bring other shots back sooner")
	assert_contains(src, "_start_heavy_draw()   # Martial archer")
	assert_contains(src, "_loose_heavy_draw()   # Martial archer")
	assert_contains(src, "chance = adjust_crit(info, chance)   # Sharpshooter")
	assert_contains(src, "_tick_sharp(_delta)")
	assert_contains(src, "Abilities.BROUGHT_BUTTONS.has(id)", "Loose (and the other brought buttons) can be pressed")
	var pd_src := FileAccess.get_file_as_string("res://scripts/player_data.gd")
	assert_contains(pd_src, "return learned_abilities.has(\"quickshot\")", "Quick Shot brings Loose")

func test_every_brought_button_is_usable() -> void:
	for id in Abilities.BROUGHT_BUTTONS:
		assert_true(Abilities.get_resource(id) != null, id)
		assert_true(SkillCards.exists(str(Abilities.BROUGHT_BUTTONS[id])), "%s comes with a real card" % id)
		assert_false(Abilities.DRAFT_POOL.has(id), "%s has no card of its own" % id)

# --- Content ----------------------------------------------------------------------------

func test_the_sharpshooter_spec_and_its_abilities() -> void:
	assert_eq(_spec("Sharpshooter"), IDS)
	for id in IDS:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s exists" % id)
		assert_eq(Abilities.category_of(id), "martial")
		assert_eq(int(r.weapon_requirement), 2, "%s needs a bow" % id)
		assert_eq(Abilities.resource_of(id), "", "%s costs nothing" % id)
		assert_true(r.tags.has("Ability") and r.tags.has("Physical"), "%s is a physical ability" % id)
		var tip := Abilities.tooltip(id)
		assert_false(tip.contains("{") or tip.contains("}"), "%s: %s" % [id, tip])
	for id in ENGINE:
		assert_gt(float(Abilities.get_resource(id).cooldown), 0.0, "%s has a cooldown" % id)
		assert_true(Abilities.SHARP_LINKS.has(id), id)
	assert_eq(float(Abilities.get_resource("loose").cooldown), 0.0, "Loose is the filler")
	assert_eq(int(Abilities.get_resource("heavydraw").cast_type), 1, "Heavy Draw is a cast")
	for id in ["breathe", "fasthands"]:
		assert_true(Abilities.OFF_GCD.has(id), "%s is off the global cooldown" % id)

func test_names_and_learning() -> void:
	var names := {"quickshot": "Quick Shot", "pierce": "Pierce", "spread": "Spread", "heavydraw": "Heavy Draw",
		"followup": "Follow Up", "loose": "Loose", "breathe": "Breathe", "fasthands": "Fast Hands"}
	for id in names:
		assert_eq(Abilities.ability_name(id), names[id])
	for id in LEVELS:
		assert_true(SkillCards.exists(id), "%s has a Skill Card" % id)
		assert_eq(SkillCards.level_of(id), LEVELS[id], "%s from level %d" % [id, LEVELS[id]])
		assert_true(Abilities.DRAFT_POOL.has(id))
	assert_false(SkillCards.exists("loose"), "Loose comes with Quick Shot")

func test_numbers_are_in_balance() -> void:
	assert_eq(float(Abilities.get_resource("quickshot").cooldown), 8.0)
	assert_eq(float(Abilities.get_resource("heavydraw").cooldown), 20.0)
	assert_eq(float(Abilities.get_resource("heavydraw").cast_time), 1.5)
	assert_eq(float(Abilities.get_resource("fasthands").cooldown), 120.0)
	for kid in ["overcut", "streak"]:
		assert_true(Keywords.KEYWORDS.has(kid), "keyword %s" % kid)
