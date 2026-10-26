@tool
extends McpTestSuite

# The Arcane book's talents on the ribbon layout (Talents.GROUPS): Clockwork, Hall of
# Mirrors, Second Act, the open ones, and Aetherstring's empty short ribbon (the bow is
# not built yet). Their rules are in scripts/player/arcane_talents.gd and each spec's
# component; the hooks are checked in the player's source.

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")

## Every talent of the book: key -> [group, ranks, the ability it needs ("" = none)].
const TREE := {
	# Clockwork.
	"arcane_etched_darts": ["Clockwork", 3, ""], "arcane_seventh_sigil": ["Clockwork", 2, "arcanemissiles"],
	"arcane_frayed": ["Clockwork", 3, "unravel"], "arcane_pinned_in_time": ["Clockwork", 3, ""],
	"arcane_thrifty_mind": ["Clockwork", 3, ""], "arcane_polished_glass": ["Clockwork", 3, "mirrorsigil"],
	"arcane_chain_reaction": ["Clockwork", 3, "countdown"], "arcane_wound_up": ["Clockwork", 3, ""],
	"arcane_sharp_mind": ["Clockwork", 3, ""], "arcane_clock_hands": ["Clockwork", 3, ""],
	"arcane_moving_parts": ["Clockwork", 3, ""], "arcane_second_hand": ["Clockwork", 3, ""],
	"arcane_keep_moving": ["Clockwork", 3, "glint"], "arcane_aftershock": ["Clockwork", 3, "collapse"],
	"arcane_light_touch": ["Clockwork", 3, ""], "arcane_on_the_dot": ["Clockwork", 3, ""],
	"arcane_turning_gears": ["Clockwork", 3, ""], "arcane_unwinding": ["Clockwork", 3, ""],
	"arcane_running_clock": ["Clockwork", 5, ""],
	# Hall of Mirrors.
	"arcane_light_feet": ["Hall of Mirrors", 3, ""], "arcane_sharp_edges": ["Hall of Mirrors", 3, ""],
	"arcane_clockwork": ["Hall of Mirrors", 2, ""], "arcane_second_self": ["Hall of Mirrors", 3, ""],
	"arcane_head_count": ["Hall of Mirrors", 3, ""], "arcane_glass_armor": ["Hall of Mirrors", 3, ""],
	"arcane_empty_room": ["Hall of Mirrors", 3, ""], "arcane_wide_rings": ["Hall of Mirrors", 3, "ripple"],
	"arcane_bent_light": ["Hall of Mirrors", 2, ""], "arcane_quick_answer": ["Hall of Mirrors", 3, ""],
	"arcane_glass_dust": ["Hall of Mirrors", 3, ""], "arcane_last_copy": ["Hall of Mirrors", 3, ""],
	"arcane_on_the_beat": ["Hall of Mirrors", 3, "missedbeat"], "arcane_understudy": ["Hall of Mirrors", 3, "standin"],
	"arcane_good_likeness": ["Hall of Mirrors", 3, "decoy"], "arcane_spare_copy": ["Hall of Mirrors", 2, ""],
	"arcane_full_crowd": ["Hall of Mirrors", 2, "crowdofone"], "arcane_crowded_room": ["Hall of Mirrors", 3, ""],
	"arcane_silvered": ["Hall of Mirrors", 5, ""],
	# The open talents.
	"arcane_quick_study": ["Open", 3, ""], "arcane_two_minds": ["Open", 3, ""], "arcane_echo": ["Open", 3, ""],
	"arcane_mirror_finish": ["Open", 3, ""], "arcane_overtime": ["Open", 3, ""], "arcane_slipstream": ["Open", 2, ""],
	"arcane_long_step": ["Open", 2, ""], "arcane_spare_moment": ["Open", 3, ""], "arcane_borrowed_time": ["Open", 3, ""],
	# Second Act.
	"arcane_long_memory": ["Second Act", 3, ""], "arcane_standing_ovation": ["Second Act", 3, ""],
	"arcane_fresh_trace": ["Second Act", 3, ""], "arcane_practiced_hand": ["Second Act", 3, ""],
	"arcane_heavy_hand": ["Second Act", 3, "deepcut"], "arcane_clean_lines": ["Second Act", 3, "deepcut"],
	"arcane_keen_cuts": ["Second Act", 2, ""], "arcane_quick_cuts": ["Second Act", 3, ""],
	"arcane_twin_blades": ["Second Act", 3, ""], "arcane_curtain_call": ["Second Act", 3, ""],
	"arcane_second_showing": ["Second Act", 3, ""], "arcane_no_loose_ends": ["Second Act", 3, "latecut"],
	"arcane_full_stage": ["Second Act", 3, ""], "arcane_full_house": ["Second Act", 2, "widecut"],
	"arcane_final_act": ["Second Act", 3, ""], "arcane_dress_rehearsal": ["Second Act", 3, "doubletime"],
	"arcane_curtain_rise": ["Second Act", 3, ""], "arcane_time_signature": ["Second Act", 3, ""],
	"arcane_fine_edge": ["Second Act", 5, ""],
}
## Each finished spec's capstone (its bottom-row talent).
const CAPSTONES := {"Clockwork": "arcane_running_clock", "Hall of Mirrors": "arcane_silvered", "Second Act": "arcane_fine_edge"}

func suite_name() -> String:
	return "arcane_tree"

func _near(a: float, b: float, msg: String = "") -> void:
	assert_true(absf(a - b) <= 0.001, "%s (%s vs %s)" % [msg, a, b])

# --- The tree ----------------------------------------------------------------------------

func test_the_whole_book_is_designed() -> void:
	var ids := Talents.in_tree("arcane")
	assert_eq(ids.size(), TREE.size(), "every slot of the Arcane book holds a talent")
	var names := {}
	for key in TREE:
		var id := Talents.id_for_key(key)
		assert_ne(id, "", "%s exists" % key)
		assert_false(bool(Talents.get_talent(id).get("placeholder", true)), "%s is designed" % key)
		assert_eq(Talents.group_of(id), str(TREE[key][0]), "%s: its spec's ribbon" % key)
		assert_eq(Talents.max_rank(id), int(TREE[key][1]), "%s: ranks" % key)
		assert_eq(Talents.required_ability(id), str(TREE[key][2]), "%s: the ability it needs" % key)
		assert_true(TalentIcons.has_icon(id), "%s has an icon" % key)
		for rank in [0, Talents.max_rank(id)]:
			var tip := Talents.tooltip(id, rank)
			assert_eq(TextFill.leftover(tip), "", "%s: its text is filled in: %s" % [key, tip])
			assert_false(tip.contains("?"), "%s: %s" % [key, tip])
		var name := str(Talents.get_talent(id)["name"])
		assert_false(names.has(name), "%s: one talent per name" % name)
		names[name] = true

## The agreed shape: 19 slots and ~50-60 ranks per finished spec, at most a quarter
## of the book's talents need one ability.
func test_each_spec_is_deep_and_mostly_keyword_talents() -> void:
	var slots := {}
	var ranks := {}
	var requires := 0
	for key in TREE:
		var g := str(TREE[key][0])
		slots[g] = int(slots.get(g, 0)) + 1
		ranks[g] = int(ranks.get(g, 0)) + int(TREE[key][1])
		if str(TREE[key][2]) != "":
			requires += 1
	for g in CAPSTONES:
		assert_eq(int(slots[g]), 19, "%s: 19 talents" % g)
		assert_true(int(ranks[g]) >= 50 and int(ranks[g]) <= 60, "%s: %d ranks" % [g, int(ranks[g])])
	assert_eq(int(slots["Open"]), 9, "nine open talents")
	assert_true(float(requires) / TREE.size() <= 0.25, "at most a quarter need one ability (%d of %d)" % [requires, TREE.size()])
	assert_true(Talents.in_group("arcane", "Aetherstring").is_empty(), "the unfinished bow has no talents yet")

func test_ribbons() -> void:
	assert_eq(Talents.columns_of("arcane"), 13)
	assert_eq(Talents.groups_of("arcane").size(), 5)
	assert_true(Talents.UNFINISHED_SPECS.has("Aetherstring"))
	for g in CAPSTONES:
		var id := Talents.id_for_key(str(CAPSTONES[g]))
		assert_eq(Talents.tier_of(id), Talents.ROWS - 1, "%s's capstone is in the bottom row" % g)
		assert_true(Talents.capstone_gated(id))
		assert_contains(Talents.tooltip(id, 0), "Needs %d points in %s" % [Balance.CAPSTONE_GATE, g])
	assert_false(Talents.capstone_gated(Talents.id_for_key("arcane_borrowed_time")), "the spine has no gate")
	assert_true(Talents.TREE_VERSION >= 10, "the new tree refunds every point")
	assert_eq(Talents.links_in_tree("arcane").size(), 6)
	for link in Talents.links_in_tree("arcane"):
		assert_eq(Talents.group_of(link[0]), Talents.group_of(link[1]), "a link stays in its spec's ribbon")
		assert_eq(Talents.col_of(link[0]), Talents.col_of(link[1]), "straight down one column")
		assert_true(Talents.tier_of(link[1]) - Talents.tier_of(link[0]) >= 2, "it skips a row")
	# No open talent names another book's ability: they key off what you do.
	for id in Talents.in_group("arcane", Talents.OPEN_GROUP):
		var text := Talents.description(id)
		for other in ["flicker", "staticstep", "cinderstep", "icyretreat"]:
			assert_false(text.contains(Abilities.ability_name(other)), "%s names no other book's ability" % id)
	assert_eq(Talents.id_for_key("arcane_loud_exit"), "", "Loud Exit was folded into Trade Places")

# --- Rules -------------------------------------------------------------------------------

func test_talent_maths() -> void:
	_near(ArcaneTalentsKit.wound_up_pct(3, 2.0), 6.0, "Wound Up per Arcane spell on cooldown")
	_near(ArcaneTalentsKit.wound_up_pct(9, 2.0), 2.0 * Balance.WOUND_UP_MAX, "never past its cap")
	_near(ArcaneTalentsKit.clock_hands_mult(3, 9.0), 0.91, "Clock Hands with three on cooldown")
	_near(ArcaneTalentsKit.clock_hands_mult(2, 9.0), 1.0, "not with two")
	assert_true(ArcaneTalentsKit.on_the_dot(0.0))
	assert_true(ArcaneTalentsKit.on_the_dot(Balance.ON_THE_DOT_TIME))
	assert_false(ArcaneTalentsKit.on_the_dot(Balance.ON_THE_DOT_TIME + 0.1), "too late")
	assert_false(ArcaneTalentsKit.on_the_dot(-1.0))
	assert_eq(ArcaneTalentsKit.fresh_trace_amount(1000, 1, 12.0), 1120, "Fresh Trace with one Trace held")
	assert_eq(ArcaneTalentsKit.fresh_trace_amount(1000, Balance.FRESH_TRACE_HELD, 12.0), 1000, "not with two")
	_near(ArcaneTalentsKit.spare_moment_rate(30.0, 6.0, false), 1.06, "Spare Moment on a long cooldown")
	_near(ArcaneTalentsKit.spare_moment_rate(10.0, 6.0, false), 1.0, "not a short one")
	_near(ArcaneTalentsKit.spare_moment_rate(30.0, 6.0, true), 1.0, "never an interrupt")
	assert_eq(ArcaneTankKit.second_self_more(30.0, 10.0), 1, "Second Self: one more")
	assert_eq(ArcaneTankKit.head_count_heal(1000, 1.5, 2), 30, "Head Count for each one made")

func test_what_counts() -> void:
	assert_true(ArcaneTalentsKit.arcane_spell_hit(Abilities.tags_of("unravel"), false, false))
	assert_false(ArcaneTalentsKit.arcane_spell_hit(Abilities.tags_of("unravel"), true, false), "not a proc")
	assert_false(ArcaneTalentsKit.arcane_spell_hit(Abilities.tags_of("deepcut"), false, false), "a cut is an ability")
	assert_true(ArcaneTalentsKit.arcane_ability_hit(Abilities.tags_of("deepcut"), false, false))
	for cut in ArcaneTalentsKit.CUTS:
		assert_true(Abilities.PATHS.has(cut), "%s exists" % cut)
	for cut in ["deepcut", "latecut", "widecut"]:
		assert_eq(str(Abilities.COOLDOWN_TALENTS.get(cut, "")), "arcane_quick_cuts", "Quick Cuts shortens %s" % cut)

func test_hooks_are_in_place() -> void:
	var src := PlayerSource.text()
	for hook in ["_arcane_talents_outgoing(info)", "_arcane_talents_incoming(info)", "crit_hit_bonus(info))   # Sharp Mind",
			"adjust_crit(info, chance)   # Keen Cuts", "cast_mult(spell)", "unwinding_ready(spell)", "UNWINDING_FX",
			"mana_mult(id)", "cooldown_rate(str(id))", "_tick_cooldowns()   # On the Dot", "dodge_bonus()", "armor_mult()",
			"time_taken_off()", "fresh_trace(", "replay_bonuses(foe)", "replayed(count)", "_hit_taken(info)   # Quick Answer",
			"second_self_more(", "head_count_heal("]:
		assert_contains(src, hook)
	var kit := FileAccess.get_file_as_string("res://scripts/player/arcane_talents.gd")
	for label in ["Pinned in Time", "Wound Up", "Moving Parts", "On the Dot", "Quick Answer", "Full Stage", "Curtain Rise",
			"Glass Dust", "Final Act", "Sharp Mind"]:
		assert_contains(kit, "\"%s\"" % label, "%s has its own damage line" % label)
