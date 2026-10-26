@tool
extends McpTestSuite

# The Lightning book's talents on the ribbon layout (Talents.GROUPS): Live Current,
# Stormdancer, Lightning Rod, the open ones, and Stormstring's short ribbon (the bow
# is not built yet). Their rules are in scripts/player/lightning_talents.gd and each
# spec's component; the hooks are checked in the player's source.

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const Details = preload("res://scripts/core/details.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")

## Every talent of the book: key -> [group, ranks, the ability it needs ("" = none)].
const TREE := {
	# Live Current.
	"lightning_long_leap": ["Live Current", 3, ""], "lightning_charged_air": ["Live Current", 2, ""],
	"lightning_quick_fuse": ["Live Current", 3, "lightningbolt"], "lightning_deep_reserves": ["Live Current", 3, ""],
	"lightning_tight_coil": ["Live Current", 2, "balllightning"], "lightning_feedback": ["Live Current", 3, ""],
	"lightning_lingering_storm": ["Live Current", 2, ""], "lightning_crackle": ["Live Current", 3, ""],
	"lightning_conductive": ["Live Current", 3, ""], "lightning_high_voltage": ["Live Current", 3, ""],
	"lightning_deep_draw": ["Live Current", 3, ""], "lightning_standing_charge": ["Live Current", 3, "groundingsurge"],
	"lightning_conductor": ["Live Current", 3, ""], "lightning_afterflow": ["Live Current", 3, ""],
	"lightning_overflow": ["Live Current", 3, "capacitor"], "lightning_parting_spark": ["Live Current", 3, "flicker"],
	"lightning_snap_cast": ["Live Current", 2, ""], "lightning_full_circuit": ["Live Current", 3, ""],
	"lightning_storm_cycle": ["Live Current", 5, ""],
	# Stormdancer.
	"lightning_charged_strikes": ["Stormdancer", 3, ""], "lightning_quick_charge": ["Stormdancer", 3, ""],
	"lightning_keen_current": ["Stormdancer", 2, ""], "lightning_edge_current": ["Stormdancer", 3, ""],
	"lightning_whip_crack": ["Stormdancer", 3, "whiplash"], "lightning_third_beat": ["Stormdancer", 3, "cadence"],
	"lightning_running_start": ["Stormdancer", 3, "staticstep"], "lightning_sparking_swings": ["Stormdancer", 3, ""],
	"lightning_running_on_empty": ["Stormdancer", 3, ""], "lightning_afterspark": ["Stormdancer", 3, ""],
	"lightning_built_charge": ["Stormdancer", 3, ""], "lightning_redline": ["Stormdancer", 3, "overdrive"],
	"lightning_light_load": ["Stormdancer", 2, ""], "lightning_spinning_up": ["Stormdancer", 3, ""],
	"lightning_hot_wire": ["Stormdancer", 3, "twincurrent"], "lightning_charged_steel": ["Stormdancer", 3, ""],
	"lightning_short_fuse": ["Stormdancer", 2, ""], "lightning_calm_current": ["Stormdancer", 3, ""],
	"lightning_storm_dance": ["Stormdancer", 5, ""],
	# The open talents.
	"lightning_live_current": ["Open", 3, ""], "lightning_change_of_pace": ["Open", 3, ""],
	"lightning_storm_tempered": ["Open", 3, ""], "lightning_spillover": ["Open", 3, ""],
	"lightning_quick_step": ["Open", 3, ""], "lightning_dig_in": ["Open", 3, ""],
	"lightning_cut_the_line": ["Open", 3, ""], "lightning_fresh_charge": ["Open", 3, ""],
	"lightning_static_build": ["Open", 3, ""],
	# Lightning Rod.
	"lightning_long_reach": ["Lightning Rod", 3, ""], "lightning_spark_guard": ["Lightning Rod", 3, ""],
	"lightning_closed_circuit": ["Lightning Rod", 3, "thunderaegis"], "lightning_loud_steel": ["Lightning Rod", 2, ""],
	"lightning_quick_wrists": ["Lightning Rod", 3, "crossguard"], "lightning_counter_charge": ["Lightning Rod", 3, "returnstroke"],
	"lightning_charged_guard": ["Lightning Rod", 3, ""], "lightning_earth_return": ["Lightning Rod", 3, ""],
	"lightning_draw_down": ["Lightning Rod", 3, ""], "lightning_ring_true": ["Lightning Rod", 3, ""],
	"lightning_second_stroke": ["Lightning Rod", 3, "returnstroke"], "lightning_tempo": ["Lightning Rod", 3, ""],
	"lightning_hard_lessons": ["Lightning Rod", 3, ""], "lightning_wide_current": ["Lightning Rod", 3, ""],
	"lightning_charged_shell": ["Lightning Rod", 3, ""], "lightning_hard_stare": ["Lightning Rod", 2, ""],
	"lightning_eye_of_the_storm": ["Lightning Rod", 3, "drawthestorm"], "lightning_back_to_the_wall": ["Lightning Rod", 2, ""],
	"lightning_storm_anchor": ["Lightning Rod", 5, ""],
	# Stormstring (unfinished: a short ribbon).
	"lightning_rod": ["Stormstring", 3, "stormarrow"], "lightning_snap_shot": ["Stormstring", 3, "stormarrow"],
	"lightning_loaded_quiver": ["Stormstring", 2, "stormarrow"],
}
## Each finished spec's capstone (its bottom-row talent).
const CAPSTONES := {"Live Current": "lightning_storm_cycle", "Stormdancer": "lightning_storm_dance",
	"Lightning Rod": "lightning_storm_anchor"}

func suite_name() -> String:
	return "lightning_tree"

func _near(a: float, b: float, msg: String = "") -> void:
	assert_true(absf(a - b) <= 0.001, "%s (%s vs %s)" % [msg, a, b])

# --- The tree ----------------------------------------------------------------------------

func test_the_whole_book_is_designed() -> void:
	var ids := Talents.in_tree("lightning")
	assert_eq(ids.size(), TREE.size(), "every slot of the Lightning book holds a talent")
	for id in ids:
		assert_false(bool(Talents.get_talent(id).get("placeholder", true)), "%s is designed" % id)
	var names := {}
	for key in TREE:
		var id := Talents.id_for_key(key)
		assert_ne(id, "", "%s exists" % key)
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

## The agreed shape: 19 slots and ~50-60 ranks per finished spec, few that need one ability.
func test_each_spec_is_deep_and_mostly_keyword_talents() -> void:
	var slots := {}
	var ranks := {}
	var requires := {}
	for key in TREE:
		var g := str(TREE[key][0])
		slots[g] = int(slots.get(g, 0)) + 1
		ranks[g] = int(ranks.get(g, 0)) + int(TREE[key][1])
		if str(TREE[key][2]) != "":
			requires[g] = int(requires.get(g, 0)) + 1
	for g in CAPSTONES:
		assert_eq(int(slots[g]), 19, "%s: 19 talents" % g)
		assert_true(int(ranks[g]) >= 50 and int(ranks[g]) <= 60, "%s: %d ranks" % [g, int(ranks[g])])
		assert_true(float(requires.get(g, 0)) / 19.0 <= 0.27, "%s: about a quarter at most need one ability (%d)" % [g, int(requires.get(g, 0))])
	assert_eq(int(slots["Open"]), 9, "nine open talents")
	assert_eq(int(slots["Stormstring"]), 3, "the unfinished bow keeps its three")

func test_ribbons() -> void:
	assert_eq(Talents.columns_of("lightning"), 13)
	assert_eq(Talents.groups_of("lightning").size(), 5)
	assert_true(Talents.UNFINISHED_SPECS.has("Stormstring"))
	for g in CAPSTONES:
		var id := Talents.id_for_key(str(CAPSTONES[g]))
		assert_eq(Talents.tier_of(id), Talents.ROWS - 1, "%s's capstone is in the bottom row" % g)
		assert_true(Talents.capstone_gated(id))
		assert_contains(Talents.tooltip(id, 0), "Needs %d points in %s" % [Balance.CAPSTONE_GATE, g])
	assert_false(Talents.capstone_gated(Talents.id_for_key("lightning_feedback")))
	assert_false(Talents.capstone_gated(Talents.id_for_key("lightning_dig_in")), "the spine has no gate")
	for key in ["lightning_rod", "lightning_snap_shot", "lightning_loaded_quiver"]:
		assert_false(Talents.capstone_gated(Talents.id_for_key(key)), "%s: no gate in a short ribbon" % key)
	assert_true(Talents.TREE_VERSION >= 9, "the new tree refunds every point")
	assert_eq(Talents.links_in_tree("lightning").size(), 6, "two links per finished spec")
	for link in Talents.links_in_tree("lightning"):
		assert_eq(Talents.group_of(link[0]), Talents.group_of(link[1]), "a link stays in its spec's ribbon")
		assert_eq(Talents.col_of(link[0]), Talents.col_of(link[1]), "straight down one column")
		assert_true(Talents.tier_of(link[1]) - Talents.tier_of(link[0]) >= 2, "it skips a row")
	# No open talent names a school: they key off what you do.
	for id in Talents.in_group("lightning", Talents.OPEN_GROUP):
		assert_false(Talents.description(id).contains("Lightning"), "%s works with any book" % id)

# --- Rules -------------------------------------------------------------------------------

func test_talent_maths() -> void:
	_near(LightningTalentsKit.deep_draw(80.0, 15.0), 92.0, "Deep Draw: 15% more counted")
	_near(LightningTalentsKit.deep_draw(80.0, 0.0), 80.0, "no talent, as spent")
	_near(LightningTalentsKit.feedback(60.0, 30.0), 78.0, "Feedback on Leaping Arc")
	assert_eq(LightningTalentsKit.steps(40.0, 15.0, 50.0), [5.0, 1], "one step made, 5 carried")
	assert_eq(LightningTalentsKit.steps(0.0, 45.0, 20.0), [5.0, 2])
	assert_eq(LightningTalentsKit.steps(10.0, -5.0, 20.0), [10.0, 0], "nothing spent, nothing counted")
	assert_eq(LightningTalentsKit.static_build_stacks(0, 25.0), 2, "every 10 m")
	assert_eq(LightningTalentsKit.static_build_stacks(2, 30.0), Balance.STATIC_BUILD_STACKS, "never past its cap")
	_near(LightningTalentsKit.short_fuse_gcd(1.5, 0.1), 1.4, "Short Fuse")
	_near(LightningTalentsKit.short_fuse_gcd(Balance.GCD_MIN, 0.1), Balance.GCD_MIN, "never below the shortest GCD")

func test_what_counts() -> void:
	assert_true(LightningTalentsKit.weapon_ability("chargededge"), "Charged Edge swings a weapon")
	assert_true(LightningTalentsKit.weapon_ability("stormshield"), "so does Stormbreak")
	assert_false(LightningTalentsKit.weapon_ability("lightningbolt"), "a spell")
	assert_false(LightningTalentsKit.weapon_ability("searingstrike"), "not a Lightning ability")
	var spell := Abilities.tags_of("lightningbolt")
	assert_true(LightningTalentsKit.lightning_spell_hit("lightningbolt", spell, false, false))
	assert_false(LightningTalentsKit.lightning_spell_hit("lightningbolt", spell, true, false), "not a proc")
	assert_false(LightningTalentsKit.lightning_spell_hit("balllightning", Abilities.tags_of("balllightning"), false, false), "not a lingering zap")
	assert_false(LightningTalentsKit.lightning_spell_hit("chargededge", Abilities.tags_of("chargededge"), false, false), "not an ability")
	assert_true(Abilities.is_interrupt("jolt"), "Cut the Line: Jolt is an interrupt")

func test_hooks_are_in_place() -> void:
	var src := PlayerSource.text()
	for hook in ["_lightning_talents_outgoing(info)", "_lightning_talents_incoming(info)", "crit_hit_bonus(info)",
			"adjust_crit(info, chance)", "energy_spent(cost, id)", "regen_pct()",
			"light_load_speed()", "gcd_for(id, gcd_total)", "generated(id",
			"spell_energy(", "back_to_the_wall()", "_tick(_delta)",
			"note_forced(", "_hit_taken(info)", "auto_landed(foe)",
			"overdrive_zapped(", "lingering()", "snap_cast_ready(spell)",
			"spent_all()", "deep_draw(have", "_talent(\"lightning_eye_of_the_storm\""]:
		assert_contains(src, hook)
	for label in ["Long Leap", "Crackle", "Storm Dance", "Ring True", "Wide Current"]:
		assert_contains(FileAccess.get_file_as_string("res://scripts/player/lightning_talents.gd"), "\"%s\")" % label, "%s has its own damage line" % label)
	assert_eq(Details.HIT_NAMES.get(LightningTalentsKit.SPARKING_SWINGS_ID, ""), "Sparking Swings", "its own meter line")
	assert_eq(Details.HIT_NAMES.get(LightningTalentsKit.SPARK_GUARD_ID, ""), "Spark Guard", "its own meter line")
