@tool
extends McpTestSuite

# The Martial book's talents on the column-group layout (Talents.GROUPS): the four
# specs' (the Wheel, the Rogue, the Brawler, the Sharpshooter) and the open ones. Their
# rules are static functions in each spec's component (scripts/player/martial_*.gd);
# the hooks are checked in the player's source.

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const Talents = preload("res://scripts/talents.gd")
const Details = preload("res://scripts/core/details.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")

## Every talent of the book: key -> [group, ranks, the ability it needs ("" = none)].
const TREE := {
	# The Wheel.
	"martial_hard_break": ["The Wheel", 4, ""], "martial_iron_grip": ["The Wheel", 3, ""],
	"martial_well_drilled": ["The Wheel", 2, ""], "martial_heavy_hands": ["The Wheel", 3, ""],
	"martial_fresh_steel": ["The Wheel", 2, ""], "martial_sharp_fragments": ["The Wheel", 3, ""],
	"martial_wide_cleave": ["The Wheel", 2, "wheelgreataxe"], "martial_weight_behind_it": ["The Wheel", 3, ""],
	"martial_keen_edge": ["The Wheel", 3, "wheelgreatsword"], "martial_breaking_point": ["The Wheel", 3, ""],
	"martial_twice_over": ["The Wheel", 3, "wheelhalberd"], "martial_ringing_blows": ["The Wheel", 3, ""],
	"martial_rattled": ["The Wheel", 3, "wheelmaul"], "martial_off_balance": ["The Wheel", 3, ""],
	"martial_spare_parts": ["The Wheel", 3, ""], "martial_big_swing": ["The Wheel", 2, ""],
	"martial_clean_swap": ["The Wheel", 3, ""], "martial_gather_pace": ["The Wheel", 2, ""],
	"martial_turning_wheel": ["The Wheel", 5, ""],
	# The Rogue.
	"martial_clean_kill": ["Rogue", 4, ""], "martial_thrift": ["Rogue", 3, ""],
	"martial_in_and_out": ["Rogue", 2, ""], "martial_spare_knives": ["Rogue", 2, ""],
	"martial_barbed": ["Rogue", 3, ""], "martial_thrown_weight": ["Rogue", 3, ""],
	"martial_steady_pace": ["Rogue", 3, ""], "martial_close_work": ["Rogue", 3, ""],
	"martial_mix_it_up": ["Rogue", 3, ""], "martial_fresh_legs": ["Rogue", 3, ""],
	"martial_deep_flow": ["Rogue", 2, ""], "martial_hot_start": ["Rogue", 3, ""],
	"martial_easy_pickings": ["Rogue", 3, ""], "martial_footloose": ["Rogue", 3, ""],
	"martial_finish_strong": ["Rogue", 3, "closeitout"], "martial_cold_read": ["Rogue", 2, ""],
	"martial_light_fingers": ["Rogue", 2, "snatch"], "martial_pressure_point": ["Rogue", 3, ""],
	"martial_in_the_zone": ["Rogue", 5, ""],
	# The open talents.
	"martial_weapon_training": ["Open", 3, ""], "martial_conditioning": ["Open", 3, ""],
	"martial_keen_strikes": ["Open", 3, ""], "martial_hardy": ["Open", 3, ""],
	"martial_catch_your_breath": ["Open", 2, ""], "martial_footing": ["Open", 2, ""],
	"martial_grit": ["Open", 2, ""], "martial_pinned_down": ["Open", 2, "pintheshadow"],
	# The Brawler.
	"martial_soak_it_up": ["Brawler", 4, ""], "martial_quick_feet": ["Brawler", 3, ""],
	"martial_tight_clinch": ["Brawler", 3, "elbow"], "martial_heavy_bag": ["Brawler", 3, ""],
	"martial_soft_catch": ["Brawler", 3, "catch"], "martial_calluses": ["Brawler", 3, ""],
	"martial_knockout": ["Brawler", 3, "punch"], "martial_wide_stance": ["Brawler", 3, ""],
	"martial_slow_burn": ["Brawler", 2, ""], "martial_counter_puncher": ["Brawler", 3, "catch"],
	"martial_crowd_work": ["Brawler", 3, ""], "martial_get_up": ["Brawler", 2, ""],
	"martial_bad_intentions": ["Brawler", 3, ""], "martial_hardened": ["Brawler", 2, ""],
	"martial_iron_chin": ["Brawler", 3, ""], "martial_last_laugh": ["Brawler", 3, ""],
	"martial_back_up": ["Brawler", 3, ""], "martial_ground_game": ["Brawler", 2, ""],
	"martial_scar_tissue": ["Brawler", 5, ""],
	# The Sharpshooter.
	"martial_full_draw": ["Sharpshooter", 4, "heavydraw"], "martial_quick_release": ["Sharpshooter", 3, ""],
	"martial_broadhead": ["Sharpshooter", 3, "pierce"], "martial_deep_hold": ["Sharpshooter", 2, ""],
	"martial_patience": ["Sharpshooter", 3, ""], "martial_on_a_roll": ["Sharpshooter", 3, ""],
	"martial_extra_arrows": ["Sharpshooter", 2, "spread"], "martial_lucky_shot": ["Sharpshooter", 3, ""],
	"martial_no_letup": ["Sharpshooter", 3, ""], "martial_long_range": ["Sharpshooter", 3, ""],
	"martial_easy_release": ["Sharpshooter", 2, "loose"], "martial_waiting_game": ["Sharpshooter", 3, ""],
	"martial_clean_release": ["Sharpshooter", 3, ""], "martial_long_streak": ["Sharpshooter", 2, ""],
	"martial_second_arrow": ["Sharpshooter", 3, ""], "martial_hard_target": ["Sharpshooter", 3, ""],
	"martial_run_it_back": ["Sharpshooter", 3, ""], "martial_hold_steady": ["Sharpshooter", 2, ""],
	"martial_keen_eye": ["Sharpshooter", 5, ""],
}
## Each spec's capstone (its bottom-row talent).
const CAPSTONES := {"The Wheel": "martial_turning_wheel", "Rogue": "martial_in_the_zone",
	"Brawler": "martial_scar_tissue", "Sharpshooter": "martial_keen_eye"}

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
	var names := {}
	for key in TREE:
		var id := Talents.id_for_key(key)
		assert_ne(id, "", "%s exists" % key)
		assert_eq(Talents.group_of(id), str(TREE[key][0]), "%s: its spec's column group" % key)
		assert_eq(Talents.max_rank(id), int(TREE[key][1]), "%s: ranks" % key)
		assert_eq(Talents.required_ability(id), str(TREE[key][2]), "%s: the ability it needs" % key)
		assert_true(TalentIcons.has_icon(id), "%s has an icon" % key)
		var tip := Talents.tooltip(id, 0)
		assert_false(tip.contains("{") or tip.contains("}"), "%s: its text is filled in: %s" % [key, tip])
		var name := str(Talents.get_talent(id)["name"])
		assert_false(names.has(name), "%s: one talent per name" % name)
		names[name] = true

## The agreed shape: ~19 talents and ~50+ ranks per spec, few that need one ability.
func test_each_spec_is_deep_and_mostly_keyword_talents() -> void:
	var talents := {}
	var ranks := {}
	var requires := 0
	for key in TREE:
		var g := str(TREE[key][0])
		talents[g] = int(talents.get(g, 0)) + 1
		ranks[g] = int(ranks.get(g, 0)) + int(TREE[key][1])
		if str(TREE[key][2]) != "":
			requires += 1
	for g in CAPSTONES:
		assert_eq(int(talents[g]), 19, "%s: 19 talents" % g)
		assert_true(int(ranks[g]) >= 50 and int(ranks[g]) <= 60, "%s: %d ranks" % [g, int(ranks[g])])
	assert_true(float(requires) / TREE.size() <= 0.25, "at most a quarter need one ability (%d of %d)" % [requires, TREE.size()])

func test_column_groups() -> void:
	assert_eq(Talents.columns_of("martial"), 9)
	assert_eq(Talents.groups_of("martial").size(), 5)
	for row in Talents.layout("martial"):
		var cols: Array = row
		for c in cols:
			assert_true(cols.has(8 - int(c)), "row %s is mirror-symmetric" % [cols])
	# Row 10: one capstone per spec, and only those are gated.
	for g in CAPSTONES:
		var id := Talents.id_for_key(str(CAPSTONES[g]))
		assert_eq(Talents.tier_of(id), Talents.ROWS - 1, "%s's capstone is in the bottom row" % g)
		assert_true(Talents.capstone_gated(id))
		assert_contains(Talents.tooltip(id, 0), "Needs %d points in %s" % [Balance.CAPSTONE_GATE, g])
	assert_false(Talents.capstone_gated(Talents.id_for_key("martial_hard_break")))
	assert_false(Talents.capstone_gated(Talents.id_for_key("martial_pinned_down")), "the Open column has no gate")

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
	_near(MartialTalentsKit.weight_pct(3, 2.0), 6.0, "Weight Behind It: 3 uses taken")
	_near(MartialTalentsKit.weight_pct(0, 3.0), 0.0, "a fresh weapon")

func test_wheel_hooks() -> void:
	var src := _src()
	assert_contains(src, "_set_cracks(_cracks + int(round(_talent(\"martial_well_drilled\"))))   # Well Drilled")
	assert_contains(src, "Balance.HALBERD_AGAIN_PCT + _talent(\"martial_twice_over\")")
	assert_contains(src, "stagger_add(Balance.STAGGER_PER_HIT + extra, _talent(\"martial_rattled\"))")
	assert_contains(src, "near.slice(0, axe_cleave_targets(_talent(\"martial_wide_cleave\")))")
	assert_contains(src, "_note_broken(held_weapon())")
	assert_contains(src, "crit_hit_bonus(info))           # Keen Edge")
	assert_contains(src, "_gain(\"fury\", _talent(\"martial_iron_grip\"))   # Iron Grip")
	assert_contains(src, "_set_cracks(int(round(_talent(\"martial_fresh_steel\"))) if burst else 0)   # Fresh Steel")
	assert_contains(src, "float(_cracks) * _talent(\"martial_spare_parts\")")
	assert_contains(src, "_talent(\"martial_big_swing\")")
	assert_contains(src, "_gain(\"fury\", _talent(\"martial_ringing_blows\"))")
	assert_contains(src, "chance + float(_cracks) * per")
	assert_contains(src, "info.add_bonus(weight, \"Weight Behind It\")")
	assert_contains(src, "info.add_bonus(last, \"Breaking Point\")")
	assert_contains(src, "info.add_bonus(swap, \"Clean Swap\")")
	assert_contains(src, "info.add_bonus(pct, \"Off Balance\")")
	assert_true(Abilities.WHEEL_ARTS.has("rush") and Abilities.WHEEL_ARTS.size() == 4, "Gather Pace: the four Weapon Arts")
	assert_contains(FileAccess.get_file_as_string("res://scripts/abilities.gd"), "talent(\"martial_gather_pace\")")

# --- The Rogue ---------------------------------------------------------------------------

func test_rogue_rules() -> void:
	assert_eq(RogueKit.flow_after(0, 1, true, 2), 1 + Balance.FLOW_SWITCH + 2, "In and Out")
	assert_eq(RogueKit.flow_after(0, 1, false, 2), 1, "only on a range switch")
	assert_eq(RogueKit.flow_after(Balance.FLOW_MAX, 1, false), Balance.FLOW_MAX, "capped")
	assert_eq(RogueKit.flow_after(Balance.FLOW_MAX, 1, false, 0, Balance.FLOW_MAX + 2), Balance.FLOW_MAX + 1, "Deep Flow raises the cap")
	assert_eq(RogueKit.daggers_after(3, 1), Balance.DAGGER_MAX)
	assert_eq(RogueKit.daggers_after(3, 2, Balance.DAGGER_MAX + 2), 5, "Spare Knives")
	_near(RogueKit.variety_add("gut", "redwhirl", 0.0, 0.5), Balance.KILL_VARIETY + 0.5, "Mix It Up")
	_near(RogueKit.variety_add("gut", "redwhirl", Balance.KILL_VARIETY_MAX - 0.3, 0.5), 0.3, "still capped")
	_near(RogueKit.in_the_zone_crit(10, 0.5), 5.0, "In the Zone at 10 Flow")

func test_rogue_hooks() -> void:
	var src := _src()
	assert_contains(src, "Balance.FLOW_HOLD + _talent(\"martial_steady_pace\")")
	assert_contains(src, "_set_flow(Balance.CLEAN_KILL_FLOW)")
	assert_contains(src, "in_the_zone_crit(_kill_flow if in_kill() else _flow, zone)")
	assert_contains(src, "cost - _talent(\"martial_thrift\")")
	assert_contains(src, "Balance.KILL_CRIT_ENERGY + _talent(\"martial_fresh_legs\")")
	assert_contains(src, "_talent(\"martial_pressure_point\")")
	assert_contains(src, "_talent(\"martial_hot_start\")")
	assert_contains(src, "_gain(\"energy\", _talent(\"martial_footloose\"))")
	assert_contains(src, "gain *= 2   # Cold Read")
	assert_contains(src, "_talent(\"martial_light_fingers\")")
	assert_contains(src, "info.add_bonus(thrown, \"Thrown Weight\")")
	assert_contains(src, "info.add_bonus(close, \"Close Work\")")
	assert_contains(src, "info.add_bonus(pick, \"Easy Pickings\")")
	assert_eq(float(Abilities.get_resource("snatch").cooldown), 10.0, "Deep Pockets was folded into Snatch")

# --- The Brawler -------------------------------------------------------------------------

func test_brawler_rules() -> void:
	assert_eq(BrawlerKit.bruise_split(100, 46.0), [54, 46], "Soak It Up")
	assert_eq(BrawlerKit.bruise_split(100, 50.0), [50, 50], "Soft Catch at rank 2")
	_near(BrawlerKit.shake_off_pct(false), Balance.SHAKE_OFF_PCT)
	_near(BrawlerKit.shake_off_pct(true), Balance.SOAK_IT_UP_SHAKE_OFF, "Soak It Up's capstone")
	_near(BrawlerKit.scarred(100.0, 10.0), 90.0, "Scar Tissue")
	_near(BrawlerKit.crowd_work_fury(5, 4.0), 4.0 * Balance.CROWD_WORK_MAX, "Crowd Work: up to 3 enemies")
	_near(BrawlerKit.crowd_work_fury(2, 4.0), 8.0)
	assert_true(BrawlerKit.hardened_on(250.0, 1000.0), "Hardened: 25% of max health in Bruise")
	assert_false(BrawlerKit.hardened_on(150.0, 1000.0))

func test_brawler_hooks() -> void:
	var src := _src()
	assert_contains(src, "Balance.BRUISE_PCT + _talent(\"martial_soak_it_up\")")
	assert_contains(src, "Balance.CLINCH_TIME + _talent(\"martial_tight_clinch\")")
	assert_contains(src, "scarred(amt, _talent(\"martial_scar_tissue\"))")
	assert_contains(src, "float(res.radius) + Abilities.radius_bonus(move)   # + Wide Stance")
	assert_contains(src, "_gain(\"fury\", _talent(\"martial_quick_feet\"))")
	assert_contains(src, "(1.0 + _talent(\"martial_calluses\") / 100.0)")
	assert_contains(src, "Balance.BRUISE_TIME + _talent(\"martial_slow_burn\")")
	assert_contains(src, "_talent(\"martial_counter_puncher\") / 100.0")
	assert_contains(src, "_talent(\"martial_iron_chin\")")
	assert_contains(src, "_talent(\"martial_hardened\")")
	assert_contains(src, "_clear_bruise(_talent(\"martial_last_laugh\"))")
	assert_contains(src, "_gain(\"fury\", _talent(\"martial_back_up\"))")
	assert_contains(src, "_talent(\"martial_get_up\") / 100.0")
	assert_contains(src, "brawler.duration_bonus(res)".replace("brawler.", ""), "Ground Game: through the effect's duration")
	assert_contains(src, "info.threat_multiplier *= 1.0 + bad / 100.0")
	assert_eq(str(Abilities.RADIUS_TALENTS["sweep"][0]), "martial_wide_stance")
	assert_eq(str(Abilities.RADIUS_TALENTS["roundhouse"][0]), "martial_wide_stance")
	assert_eq(float(Abilities.get_resource("onemore").cooldown), 9.0, "Round Two was folded into One More")
	assert_eq(str(Details.HIT_NAMES.get(BrawlerKit.GET_UP_ID, "")), "Get Up", "Get Up's heal has its own meter line")

# --- The Sharpshooter --------------------------------------------------------------------

func test_sharpshooter_rules() -> void:
	_near(SharpshooterKit.overcut_bonus(10.0, 11.0), 110.0, "Patience")
	_near(SharpshooterKit.overcut_bonus(99.0, 11.0), Balance.OVERCUT_MAX * 11.0, "still up to OVERCUT_MAX sec")
	_near(SharpshooterKit.overcut_bonus(99.0, 8.0, Balance.OVERCUT_MAX + 5.0), (Balance.OVERCUT_MAX + 5.0) * 8.0, "Deep Hold")
	_near(SharpshooterKit.overcut_after(10.0, 10.0, Balance.OVERCUT_MAX + 2.5), Balance.OVERCUT_MAX + 2.5)
	assert_eq(SharpshooterKit.streak_after(9, "loose", 3), 6, "Easy Release: a third")
	assert_eq(SharpshooterKit.streak_after(9, "loose", 4), 6, "a quarter, rounded up")
	assert_eq(SharpshooterKit.streak_after(8, "loose", 4), 6)
	assert_eq(SharpshooterKit.streak_after(7, "loose"), 3, "half without it")
	assert_eq(SharpshooterKit.streak_after(Balance.STREAK_MAX, "quickshot"), Balance.STREAK_MAX)
	assert_eq(SharpshooterKit.streak_after(Balance.STREAK_MAX, "quickshot", 2, Balance.STREAK_MAX + 2), Balance.STREAK_MAX + 1, "Long Streak")
	_near(SharpshooterKit.long_range_pct(9.0, 3.0), 0.0, "close: nothing")
	_near(SharpshooterKit.long_range_pct(20.0, 3.0), 6.0, "two steps of 5 m past 10 m")
	var foe := Node.new()
	foe.set_meta("x", 0)
	var hp := GDScript.new()
	hp.source_code = "extends Node\nvar health := 90\nvar max_health := 100\n"
	hp.reload()
	foe.set_script(hp)
	assert_true(SharpshooterKit.hard_target(foe), "Hard Target: 90%")
	foe.set("health", 70)
	assert_false(SharpshooterKit.hard_target(foe))
	foe.free()

func test_sharpshooter_hooks() -> void:
	var src := _src()
	assert_contains(src, "Balance.SHARP_PIERCE_WIDTH + _talent(\"martial_broadhead\")")
	assert_contains(src, "Balance.SHARP_SPREAD_ARROWS + int(round(_talent(\"martial_extra_arrows\")))")
	assert_contains(src, "Balance.STREAK_HOLD + _talent(\"martial_no_letup\")")
	assert_contains(src, "Balance.FULL_DRAW_CUT if _capstone(\"martial_full_draw\") else Balance.SHARP_HEAVY_CUT")
	assert_contains(src, "chance += _talent(\"martial_keen_eye\")")
	assert_contains(src, "_talent(\"martial_quick_release\") / 100.0")
	assert_contains(src, "Balance.STREAK_PCT + _talent(\"martial_on_a_roll\")")
	assert_contains(src, "_talent(\"martial_lucky_shot\")")
	assert_contains(src, "_talent(\"martial_second_arrow\")")
	assert_contains(src, "_talent(\"martial_run_it_back\")")
	assert_contains(src, "_talent(\"martial_waiting_game\")")
	assert_contains(src, "_talent(\"martial_clean_release\")")
	assert_contains(src, "info.add_bonus(far, \"Long Range\")")
	assert_contains(src, "info.add_bonus(hard, \"Hard Target\")")
	assert_contains(src, "info.add_bonus(steady, \"Hold Steady\")")
	assert_eq(str(Details.HIT_NAMES.get(SharpshooterKit.SECOND_ARROW_ID, "")), "Second Arrow", "its own meter line")

# --- Hits that get a bonus of their own ---------------------------------------------------

func test_damage_talents_have_their_own_lines() -> void:
	assert_eq(Abilities.martial_hit_talent("shrapnel"), "martial_hard_break")
	assert_eq(Abilities.martial_hit_talent("faultline"), "martial_hard_break")
	assert_eq(Abilities.martial_hit_talent("gut"), "martial_clean_kill")
	assert_eq(Abilities.martial_hit_talent("cut"), "", "a builder isn't a Kill form")
	assert_eq(Abilities.martial_hit_talent("haymaker"), "martial_knockout")
	assert_eq(Abilities.martial_hit_talent("heavydraw"), "martial_full_draw")
	assert_true(Abilities.martial_hit_talents("chop").has("martial_heavy_hands"), "Heavy Hands: the Heavy Fillers")
	assert_true(Abilities.martial_hit_talents("closeitout").has("martial_finish_strong"))
	assert_true(Abilities.martial_hit_talents("haymaker").has("martial_heavy_bag"), "Haymaker is a strong move too")
	assert_true(Abilities.martial_hit_talents("throw").has("martial_counter_puncher"))
	_near(Abilities.martial_hit_pct("haymaker", func(key: String, _f: String) -> float: return 30.0 if key == "martial_knockout" else 0.0), 30.0)
	_near(Abilities.martial_hit_pct("haymaker", func(_key: String, _f: String) -> float: return 10.0), 20.0, "both of Haymaker's")
	for key in MartialTalentsKit.LABELS:
		assert_eq(str(MartialTalentsKit.LABELS[key]), str(Talents.get_talent(Talents.id_for_key(str(key)))["name"]), "%s: its line is named after it" % key)
	var src := _src()
	assert_contains(src, "_martial_talents_outgoing(info)")
	assert_contains(src, "info.add_bonus(barbed, \"Barbed\")")
	assert_contains(src, "info.add_bonus(turning, \"Turning Wheel\")")
	var combat := FileAccess.get_file_as_string("res://scripts/core/combat_system.gd")
	assert_contains(combat, "for i in range(0, cb.size() - 1, 2):", "several crit bonuses on one hit, each its own line")

# --- The open talents --------------------------------------------------------------------

func test_open_talents() -> void:
	var id := Talents.id_for_key("martial_conditioning")
	_near(float(Talents.get_talent(id)["stats"].get("max_health%", 0.0)), 2.0, "Conditioning: max health % per rank")
	_near(float(Talents.get_talent(Talents.id_for_key("martial_footing"))["stats"].get("move_speed", 0.0)), 3.0, "Footing: move speed per rank")
	assert_true(MartialTalentsKit.breath_triggers(30.0, 100.0, 10.0, 0.0))
	assert_false(MartialTalentsKit.breath_triggers(40.0, 100.0, 10.0, 0.0), "only below the line")
	assert_false(MartialTalentsKit.breath_triggers(30.0, 100.0, 10.0, 20.0), "once a minute")
	assert_false(MartialTalentsKit.breath_triggers(0.0, 100.0, 10.0, 0.0), "not when dead")
	_near(MartialTalentsKit.breath_tick_heal(1000.0, 20.0) * MartialTalentsKit.breath_ticks(), 200.0, "Catch Your Breath heals it all")
	assert_true(Abilities.HEAL_OVER_TIME_IDS.has(MartialTalentsKit.BREATH_ID), "a heal over time")
	assert_eq(str(Details.HIT_NAMES.get(MartialTalentsKit.BREATH_ID, "")), "Catch Your Breath", "its own meter line")
	assert_true(MartialTalentsKit.gritty(40.0, 100.0), "Grit: below half health")
	assert_false(MartialTalentsKit.gritty(60.0, 100.0))
	var src := _src()
	assert_contains(src, "info.add_bonus(training, \"Weapon Training\")")
	assert_contains(src, "info.add_bonus(grit, \"Grit\")")
	assert_contains(src, "return [pct, \"Keen Strikes\"]")
	assert_contains(src, "pct *= 1.0 + _talent(\"martial_hardy\") / 100.0   # Hardy")

func test_pinned_down() -> void:
	var pinned: Resource = load("res://data/effects/pinned_shadow.tres")
	_near(Abilities.effect_time_bonus(pinned, func(key: String, f: String) -> float: return 4.0 if key == "martial_pinned_down" and f == "values2" else 0.0), 4.0, "lasts longer")
	assert_contains(_src(), "func effect_extra_hits(res: Resource) -> int:")
	var st := FileAccess.get_file_as_string("res://scripts/core/status_container.gd")
	assert_contains(st, "effects[id][\"hits\"] = -more")
	assert_contains(st, "out[\"hits\"] = int(effects[key][\"hits\"])", "the host learns it from the caster's machine")
