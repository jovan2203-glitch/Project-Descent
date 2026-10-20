@tool
extends McpTestSuite

# The Martial book's talents: the four specs' (the Wheel, the Rogue, the Brawler, the
# Sharpshooter) and the open ones (Conditioning, Catch Your Breath, Pinned Down). Their
# rules are static functions in each spec's component (scripts/player/martial_*.gd);
# the hooks are checked in the player's source.

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const Talents = preload("res://scripts/talents.gd")
const Details = preload("res://scripts/core/details.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")

## Every talent of the book: key -> [ranks, the ability it needs ("" = none)].
const TREE := {
	"martial_hard_break": [4, "wheelgreataxe"], "martial_well_drilled": [2, "wheelgreataxe"],
	"martial_wide_cleave": [2, "wheelgreataxe"], "martial_keen_edge": [2, "wheelgreatsword"],
	"martial_twice_over": [2, "wheelhalberd"], "martial_rattled": [2, "wheelmaul"], "martial_turning_wheel": [5, ""],
	"martial_clean_kill": [4, "goin"], "martial_in_and_out": [2, "cut"], "martial_barbed": [3, "cut"],
	"martial_steady_pace": [2, "cut"], "martial_mix_it_up": [2, "goin"], "martial_deep_pockets": [2, "snatch"],
	"martial_in_the_zone": [5, ""],
	"martial_conditioning": [3, ""], "martial_catch_your_breath": [2, ""], "martial_pinned_down": [2, "pintheshadow"],
	"martial_soak_it_up": [4, "punch"], "martial_tight_clinch": [2, "elbow"], "martial_soft_catch": [2, "catch"],
	"martial_knockout": [3, "punch"], "martial_wide_stance": [2, "brawlkick"], "martial_round_two": [2, "onemore"],
	"martial_scar_tissue": [5, ""],
	"martial_full_draw": [4, "heavydraw"], "martial_broadhead": [2, "pierce"], "martial_patience": [3, "quickshot"],
	"martial_extra_arrows": [2, "spread"], "martial_no_letup": [2, "quickshot"], "martial_easy_release": [2, "loose"],
	"martial_keen_eye": [5, ""],
}

func suite_name() -> String:
	return "martial_talents"

func _src() -> String:
	return PlayerSource.text()

func _near(a: float, b: float, msg: String = "") -> void:
	assert_true(absf(a - b) <= 0.001, "%s (%s vs %s)" % [msg, a, b])

# --- The tree ----------------------------------------------------------------------------

func test_the_whole_book_is_designed() -> void:
	var ids := Talents.in_tree("martial")
	assert_eq(ids.size(), TREE.size(), "every slot of the Martial book holds a talent")
	for id in ids:
		assert_false(bool(Talents.get_talent(id).get("placeholder", true)), "%s is designed" % id)
	for key in TREE:
		var id := Talents.id_for_key(key)
		assert_ne(id, "", "%s exists" % key)
		assert_eq(Talents.max_rank(id), int(TREE[key][0]), "%s: ranks" % key)
		assert_eq(Talents.required_ability(id), str(TREE[key][1]), "%s: the ability it needs" % key)
		assert_true(TalentIcons.has_icon(id), "%s has an icon" % key)
		var tip := Talents.tooltip(id, 0)
		assert_false(tip.contains("{") or tip.contains("}"), "%s: its text is filled in: %s" % [key, tip])

func test_rows_are_symmetric_and_hold_two_to_four() -> void:
	for row in Talents.layout("martial"):
		var cols: Array = row
		assert_true(cols.size() >= 2 and cols.size() <= 4, "row %s" % [cols])
		for c in cols:
			assert_true(cols.has(Talents.COLUMNS - 1 - int(c)), "row %s is mirror-symmetric" % [cols])

func test_each_spec_keeps_to_its_columns() -> void:
	var cols := {"wheel": [0, 1], "rogue": [2], "open": [3], "brawler": [4], "sharp": [5, 6]}
	var spec := {"martial_hard_break": "wheel", "martial_turning_wheel": "wheel", "martial_rattled": "wheel",
		"martial_clean_kill": "rogue", "martial_in_the_zone": "rogue", "martial_conditioning": "open",
		"martial_pinned_down": "open", "martial_soak_it_up": "brawler", "martial_scar_tissue": "brawler",
		"martial_full_draw": "sharp", "martial_keen_eye": "sharp", "martial_easy_release": "sharp"}
	for key in spec:
		assert_true((cols[spec[key]] as Array).has(Talents.col_of(Talents.id_for_key(key))), key)

# --- The Wheel ---------------------------------------------------------------------------

func test_wheel_rules() -> void:
	assert_eq(WheelKit.axe_cleave_targets(0.0), 1)
	assert_eq(WheelKit.axe_cleave_targets(2.0), 3, "Wide Cleave")
	_near(WheelKit.stagger_add(20.0, 50.0), 30.0, "Rattled")
	_near(WheelKit.turning_wheel_pct(2.5, 4), 10.0, "Turning Wheel: all four")
	_near(WheelKit.turning_wheel_pct(2.5, 9), 10.0, "one stack per weapon")
	_near(WheelKit.hard_break_fury(Balance.HARD_BREAK_CRACKS, true), Balance.HARD_BREAK_FURY, "Hard Break's capstone")
	_near(WheelKit.hard_break_fury(Balance.HARD_BREAK_CRACKS - 1, true), 0.0, "not enough Cracks")
	_near(WheelKit.hard_break_fury(99, false), 0.0, "only at max rank")

func test_wheel_hooks() -> void:
	var src := _src()
	assert_contains(src, "_set_cracks(_cracks + int(round(_talent(\"martial_well_drilled\"))))   # Well Drilled")
	assert_contains(src, "Balance.HALBERD_AGAIN_PCT + _talent(\"martial_twice_over\")")
	assert_contains(src, "stagger_add(Balance.STAGGER_PER_HIT + extra, _talent(\"martial_rattled\"))")
	assert_contains(src, "near.slice(0, axe_cleave_targets(_talent(\"martial_wide_cleave\")))")
	assert_contains(src, "_note_broken(held_weapon())")
	assert_contains(src, "else crit_hit_bonus(info)   # Keen Edge")

# --- The Rogue ---------------------------------------------------------------------------

func test_rogue_rules() -> void:
	assert_eq(RogueKit.flow_after(0, 1, true, 2), 1 + Balance.FLOW_SWITCH + 2, "In and Out")
	assert_eq(RogueKit.flow_after(0, 1, false, 2), 1, "only on a range switch")
	_near(RogueKit.variety_add("gut", "redwhirl", 0.0, 0.5), Balance.KILL_VARIETY + 0.5, "Mix It Up")
	_near(RogueKit.variety_add("gut", "redwhirl", Balance.KILL_VARIETY_MAX - 0.3, 0.5), 0.3, "still capped")
	_near(RogueKit.in_the_zone_crit(10, 0.5), 5.0, "In the Zone at 10 Flow")

func test_rogue_hooks() -> void:
	var src := _src()
	assert_contains(src, "Balance.FLOW_HOLD + _talent(\"martial_steady_pace\")")
	assert_contains(src, "_set_flow(Balance.CLEAN_KILL_FLOW)")
	assert_contains(src, "in_the_zone_crit(_kill_flow if in_kill() else _flow, zone)")
	assert_eq(str(Abilities.COOLDOWN_TALENTS.get("snatch", "")), "martial_deep_pockets", "Deep Pockets")

# --- The Brawler -------------------------------------------------------------------------

func test_brawler_rules() -> void:
	assert_eq(BrawlerKit.bruise_split(100, 46.0), [54, 46], "Soak It Up")
	assert_eq(BrawlerKit.bruise_split(100, 50.0), [50, 50], "Soft Catch at rank 2")
	_near(BrawlerKit.shake_off_pct(false), Balance.SHAKE_OFF_PCT)
	_near(BrawlerKit.shake_off_pct(true), Balance.SOAK_IT_UP_SHAKE_OFF, "Soak It Up's capstone")
	_near(BrawlerKit.scarred(100.0, 10.0), 90.0, "Scar Tissue")

func test_brawler_hooks() -> void:
	var src := _src()
	assert_contains(src, "Balance.BRUISE_PCT + _talent(\"martial_soak_it_up\")")
	assert_contains(src, "Balance.CLINCH_TIME + _talent(\"martial_tight_clinch\")")
	assert_contains(src, "scarred(amt, _talent(\"martial_scar_tissue\"))")
	assert_contains(src, "float(res.radius) + Abilities.radius_bonus(move)   # + Wide Stance")
	assert_eq(str(Abilities.RADIUS_TALENTS["sweep"][0]), "martial_wide_stance")
	assert_eq(str(Abilities.RADIUS_TALENTS["roundhouse"][0]), "martial_wide_stance")
	assert_eq(str(Abilities.COOLDOWN_TALENTS.get("onemore", "")), "martial_round_two", "Round Two")

# --- The Sharpshooter --------------------------------------------------------------------

func test_sharpshooter_rules() -> void:
	_near(SharpshooterKit.overcut_bonus(10.0, 11.0), 110.0, "Patience")
	_near(SharpshooterKit.overcut_bonus(99.0, 11.0), Balance.OVERCUT_MAX * 11.0, "still up to OVERCUT_MAX sec")
	assert_eq(SharpshooterKit.streak_after(9, "loose", 3), 6, "Easy Release: a third")
	assert_eq(SharpshooterKit.streak_after(9, "loose", 4), 6, "a quarter, rounded up")
	assert_eq(SharpshooterKit.streak_after(8, "loose", 4), 6)
	assert_eq(SharpshooterKit.streak_after(7, "loose"), 3, "half without it")

func test_sharpshooter_hooks() -> void:
	var src := _src()
	assert_contains(src, "Balance.SHARP_PIERCE_WIDTH + _talent(\"martial_broadhead\")")
	assert_contains(src, "Balance.SHARP_SPREAD_ARROWS + int(round(_talent(\"martial_extra_arrows\")))")
	assert_contains(src, "Balance.STREAK_HOLD + _talent(\"martial_no_letup\")")
	assert_contains(src, "Balance.FULL_DRAW_CUT if _capstone(\"martial_full_draw\") else Balance.SHARP_HEAVY_CUT")
	assert_contains(src, "chance += _talent(\"martial_keen_eye\")")

# --- Hits that get a bonus of their own ---------------------------------------------------

func test_damage_talents_have_their_own_lines() -> void:
	assert_eq(Abilities.martial_hit_talent("shrapnel"), "martial_hard_break")
	assert_eq(Abilities.martial_hit_talent("faultline"), "martial_hard_break")
	assert_eq(Abilities.martial_hit_talent("gut"), "martial_clean_kill")
	assert_eq(Abilities.martial_hit_talent("cut"), "", "a builder isn't a Kill form")
	assert_eq(Abilities.martial_hit_talent("haymaker"), "martial_knockout")
	assert_eq(Abilities.martial_hit_talent("heavydraw"), "martial_full_draw")
	_near(Abilities.martial_hit_pct("haymaker", func(key: String, _f: String) -> float: return 30.0 if key == "martial_knockout" else 0.0), 30.0)
	var src := _src()
	assert_contains(src, "_martial_talents_outgoing(info)")
	assert_contains(src, "info.add_bonus(barbed, \"Barbed\")")
	assert_contains(src, "info.add_bonus(turning, \"Turning Wheel\")")

# --- The open talents --------------------------------------------------------------------

func test_open_talents() -> void:
	var id := Talents.id_for_key("martial_conditioning")
	_near(float(Talents.get_talent(id)["stats"].get("max_health%", 0.0)), 2.0, "Conditioning: max health % per rank")
	assert_true(MartialTalentsKit.breath_triggers(30.0, 100.0, 10.0, 0.0))
	assert_false(MartialTalentsKit.breath_triggers(40.0, 100.0, 10.0, 0.0), "only below the line")
	assert_false(MartialTalentsKit.breath_triggers(30.0, 100.0, 10.0, 20.0), "once a minute")
	assert_false(MartialTalentsKit.breath_triggers(0.0, 100.0, 10.0, 0.0), "not when dead")
	_near(MartialTalentsKit.breath_tick_heal(1000.0, 20.0) * MartialTalentsKit.breath_ticks(), 200.0, "Catch Your Breath heals it all")
	assert_true(Abilities.HEAL_OVER_TIME_IDS.has(MartialTalentsKit.BREATH_ID), "a heal over time")
	assert_eq(str(Details.HIT_NAMES.get(MartialTalentsKit.BREATH_ID, "")), "Catch Your Breath", "its own meter line")

func test_pinned_down() -> void:
	var pinned: Resource = load("res://data/effects/pinned_shadow.tres")
	_near(Abilities.effect_time_bonus(pinned, func(key: String, f: String) -> float: return 4.0 if key == "martial_pinned_down" and f == "values2" else 0.0), 4.0, "lasts longer")
	assert_contains(_src(), "func effect_extra_hits(res: Resource) -> int:")
	var st := FileAccess.get_file_as_string("res://scripts/core/status_container.gd")
	assert_contains(st, "effects[id][\"hits\"] = -more")
	assert_contains(st, "out[\"hits\"] = int(effects[key][\"hits\"])", "the host learns it from the caster's machine")
