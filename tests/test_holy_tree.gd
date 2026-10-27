@tool
extends McpTestSuite

# The Holy book's talents on the ribbon layout (Talents.GROUPS): Choir of One, Censer
# Bearer, Line of Light, Lightstring and the open ones. Their rules are in each spec's
# component (scripts/player/holy_*.gd) and holy_talents.gd; the hooks are checked in the
# player's source. (The older talents' rules: tests/test_holy_talents.gd and the specs' suites.)

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const Details = preload("res://scripts/core/details.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")

## Every talent of the book: key -> [group, ranks, the ability it needs ("" = none)].
const TREE := {
	# Choir of One.
	"holy_many_voices": ["Choir of One", 2, ""], "holy_watchful": ["Choir of One", 2, ""],
	"holy_mercys_ear": ["Choir of One", 2, ""], "holy_choir_loft": ["Choir of One", 2, ""],
	"holy_night_watch": ["Choir of One", 3, ""], "holy_key_change": ["Choir of One", 3, ""],
	"holy_open_doors": ["Choir of One", 4, "shelter"], "holy_swelling_chorus": ["Choir of One", 3, "singchorus"],
	"holy_warded_song": ["Choir of One", 3, ""], "holy_rising_voice": ["Choir of One", 3, ""],
	"holy_long_note": ["Choir of One", 3, ""], "holy_long_echo": ["Choir of One", 3, "reprise"],
	"holy_sheltering_light": ["Choir of One", 3, ""], "holy_tender_mercy": ["Choir of One", 3, ""],
	"holy_full_voice": ["Choir of One", 2, ""], "holy_held_note": ["Choir of One", 2, ""],
	"holy_mercy_seat": ["Choir of One", 3, ""], "holy_breath_between": ["Choir of One", 3, ""],
	"holy_radiance": ["Choir of One", 5, ""],
	# Censer Bearer.
	"holy_heavy_chain": ["Censer Bearer", 2, "censerswing"], "holy_absolution": ["Censer Bearer", 3, "absolve"],
	"holy_mote_magnet": ["Censer Bearer", 2, ""], "holy_wide_arc": ["Censer Bearer", 3, "hallowedarc"],
	"holy_bright_barrier": ["Censer Bearer", 3, ""], "holy_lingering_light": ["Censer Bearer", 2, ""],
	"holy_bright_motes": ["Censer Bearer", 3, ""], "holy_offering": ["Censer Bearer", 3, ""],
	"holy_full_censer": ["Censer Bearer", 3, ""], "holy_heavy_smoke": ["Censer Bearer", 3, ""],
	"holy_unbroken": ["Censer Bearer", 3, "unfallen"], "holy_heavy_motes": ["Censer Bearer", 3, ""],
	"holy_deep_pour": ["Censer Bearer", 3, "pourout"], "holy_turned_aside": ["Censer Bearer", 3, ""],
	"holy_cloying_smoke": ["Censer Bearer", 3, ""], "holy_shaken_loose": ["Censer Bearer", 3, ""],
	"holy_ringing_censer": ["Censer Bearer", 2, ""], "holy_hold_the_line": ["Censer Bearer", 3, ""],
	"holy_censers_weight": ["Censer Bearer", 5, ""],
	# The open talents.
	"holy_grace": ["Open", 3, ""], "holy_steadfast": ["Open", 3, ""], "holy_overflowing": ["Open", 3, ""],
	"holy_watchful_eye": ["Open", 2, ""], "holy_second_breath": ["Open", 2, ""], "holy_penitent": ["Open", 3, ""],
	"holy_candlelight": ["Open", 3, ""], "holy_first_light": ["Open", 3, ""], "holy_zeal": ["Open", 2, ""],
	# Line of Light.
	"holy_wide_burst": ["Line of Light", 3, "shatterall"], "holy_quick_lance": ["Line of Light", 3, "brightlance"],
	"holy_steady_ray": ["Line of Light", 3, "mendingray"], "holy_clear_glass": ["Line of Light", 2, ""],
	"holy_prismatic_burst": ["Line of Light", 3, "shatterall"], "holy_deep_crystal": ["Line of Light", 3, ""],
	"holy_quick_realign": ["Line of Light", 3, "realign"], "holy_thirsty_glass": ["Line of Light", 3, ""],
	"holy_sharp_facets": ["Line of Light", 2, ""], "holy_clear_mind": ["Line of Light", 3, ""],
	"holy_long_glass": ["Line of Light", 2, ""], "holy_bright_shards": ["Line of Light", 3, ""],
	"holy_polish": ["Line of Light", 3, ""], "holy_aftershine": ["Line of Light", 3, ""],
	"holy_lifeline": ["Line of Light", 3, ""], "holy_focused_light": ["Line of Light", 3, ""],
	"holy_last_glint": ["Line of Light", 2, ""], "holy_full_glass": ["Line of Light", 3, ""],
	"holy_brilliance": ["Line of Light", 5, ""],
	# Lightstring.
	"holy_full_quiver": ["Lightstring", 3, "prismarrow"], "holy_glimmering": ["Lightstring", 3, ""],
	"holy_steady_aim": ["Lightstring", 3, "refractingshot"], "holy_deep_burn": ["Lightstring", 3, "sunlitarrow"],
	"holy_wide_fan": ["Lightstring", 2, ""], "holy_split_light": ["Lightstring", 3, ""],
	"holy_long_volley": ["Lightstring", 3, "spectrumvolley"], "holy_wide_break": ["Lightstring", 3, "prismbreaker"],
	"holy_gilded": ["Lightstring", 3, ""], "holy_pinpoint": ["Lightstring", 3, ""],
	"holy_burnished": ["Lightstring", 3, ""], "holy_lined_up": ["Lightstring", 3, ""],
	"holy_bright_quiver": ["Lightstring", 2, ""], "holy_light_draw": ["Lightstring", 3, ""],
	"holy_full_gold": ["Lightstring", 3, ""], "holy_gilt_tips": ["Lightstring", 3, ""],
	"holy_dazzle": ["Lightstring", 3, ""], "holy_sundown": ["Lightstring", 3, ""],
	"holy_sunsteel": ["Lightstring", 5, ""],
}
## Each spec's capstone (its bottom-row talent).
const CAPSTONES := {"Choir of One": "holy_radiance", "Censer Bearer": "holy_censers_weight",
	"Line of Light": "holy_brilliance", "Lightstring": "holy_sunsteel"}

func suite_name() -> String:
	return "holy_tree"

func _src() -> String:
	return PlayerSource.text()

func _near(a: float, b: float, msg: String = "") -> void:
	assert_true(absf(a - b) <= 0.001, "%s (%s vs %s)" % [msg, a, b])

# --- The tree ----------------------------------------------------------------------------

func test_the_whole_book_is_designed() -> void:
	var ids := Talents.in_tree("holy")
	assert_eq(ids.size(), TREE.size(), "every slot of the Holy book holds a talent")
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

## The agreed shape: 19 slots and ~50-60 ranks per spec, few that need one ability.
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

func test_ribbons() -> void:
	assert_eq(Talents.columns_of("holy"), 13)
	assert_eq(Talents.groups_of("holy").size(), 5)
	for g in CAPSTONES:
		assert_false(Talents.UNFINISHED_SPECS.has(g), "%s is built" % g)
		assert_true(Talents.SHAPES.has(g), "%s has a shape" % g)
		var id := Talents.id_for_key(str(CAPSTONES[g]))
		assert_eq(Talents.tier_of(id), Talents.ROWS - 1, "%s's capstone is in the bottom row" % g)
		assert_true(Talents.capstone_gated(id))
		assert_contains(Talents.tooltip(id, 0), "Needs %d points in %s" % [Balance.CAPSTONE_GATE, g])
		assert_ne(str(Talents.get_talent(id).get("capstone", "")), "", "%s's capstone has a bonus at max rank" % g)
	assert_false(Talents.capstone_gated(Talents.id_for_key("holy_many_voices")))
	assert_false(Talents.capstone_gated(Talents.id_for_key("holy_zeal")), "the spine has no gate")
	assert_true(Talents.TREE_VERSION >= 12, "the new tree refunds every point")
	assert_eq(Talents.links_in_tree("holy").size(), 8, "two links per spec")
	for link in Talents.links_in_tree("holy"):
		assert_eq(Talents.group_of(link[0]), Talents.group_of(link[1]), "a link stays in its spec's ribbon")
		assert_eq(Talents.col_of(link[0]), Talents.col_of(link[1]), "straight down one column")
		assert_true(Talents.tier_of(link[1]) - Talents.tier_of(link[0]) >= 2, "it skips a row")
	# No open talent names a school: they key off what you do.
	for id in Talents.in_group("holy", Talents.OPEN_GROUP):
		assert_false(Talents.description(id).contains("Holy"), "%s works with any book" % id)

## Every book is on ribbons now: the old 10 x 7 grid has none left.
func test_every_book_is_on_ribbons() -> void:
	const Categories = preload("res://scripts/categories.gd")
	for cat in Categories.ORDER:
		if Talents.in_tree(str(cat)).is_empty():
			continue
		assert_false(Talents.groups_of(str(cat)).is_empty(), "%s is on ribbons" % cat)

# --- Rules -------------------------------------------------------------------------------

func test_choir_talents() -> void:
	_near(HymnsKit.verse_drain_every(0.0), Balance.VERSE_DRAIN_EVERY)
	_near(HymnsKit.verse_drain_every(6.0), 6.0, "Held Note")
	_near(HymnsKit.reprise_pct(0.0), Balance.REPRISE_PCT)
	_near(HymnsKit.reprise_pct(55.0), 55.0, "Long Echo")
	_near(HymnsKit.radiance_boost(Balance.VERSE_MAX, true), 1.0 + Balance.RADIANCE_MATCH_PCT / 100.0, "Radiance's capstone")
	_near(HymnsKit.radiance_boost(Balance.VERSE_MAX - 1, true), 1.0, "only when every Verse suits it")
	_near(HymnsKit.radiance_boost(Balance.VERSE_MAX, false), 1.0, "only with the capstone")

func test_censer_talents() -> void:
	assert_eq(CenserKit.incense_for_hit(true, false, 2), Balance.INCENSE_PER_BLOCK + 2, "Ringing Censer")
	assert_eq(CenserKit.incense_for_hit(false, false, 2), Balance.INCENSE_PER_HIT, "only on a block")
	_near(CenserKit.hold_the_line_block(100, 0.15, 100.0), 15.0, "Hold the Line: the Block once more")
	_near(CenserKit.hold_the_line_block(0, 0.15, 100.0), 0.0)
	assert_eq(str(Details.HIT_NAMES.get(CenserKit.TURNED_ASIDE_ID, "")), "Turned Aside", "its own meter line")

func test_prism_talents() -> void:
	var cap := PrismsKit.prism_cap(0.0)
	_near(PrismsKit.prism_charged(0.0, 4.0, cap, 30.0), 1.3, "Thirsty Glass")
	_near(PrismsKit.shatter_heal(1.0, 1, 30.0, 20.0), 1.56, "Focused Light and Brilliance, one ally")
	_near(PrismsKit.shatter_heal(1.0, 2, 30.0, 20.0), 1.2, "Focused Light only with one ally")
	_near(PrismsKit.beam_bonus(1, 1, 15.0, false), 1.15, "Full Glass")
	_near(PrismsKit.beam_bonus(1, 0, 15.0, false), 1.0, "no full prism")
	_near(PrismsKit.beam_bonus(Balance.BRILLIANCE_PRISMS, 0, 0.0, true), 1.0 + Balance.BRILLIANCE_PCT / 100.0, "Brilliance's capstone")
	_near(PrismsKit.beam_bonus(Balance.BRILLIANCE_PRISMS - 1, 0, 0.0, true), 1.0, "short of the prisms")

func test_lightstring_talents() -> void:
	_near(LightstringKit.line_mult(1, 1, 9.0, 0.0), 1.0 + (Balance.REFRACT_FOCUS_PCT + 9.0) / 100.0, "Pinpoint")
	_near(LightstringKit.line_mult(0, Balance.LINED_UP_PRISMS, 0.0, 12.0), 1.12, "Lined Up")
	_near(LightstringKit.line_mult(0, 1, 0.0, 12.0), 1.0, "one prism isn't a line")
	assert_true(HolyTalentsKit.glimmering_applies("glimmershot", Abilities.tags_of("glimmershot"), false, false), "Glimmering: an instant shot")
	assert_false(HolyTalentsKit.glimmering_applies("refractingshot", Abilities.tags_of("refractingshot"), false, false), "not a cast")
	assert_false(HolyTalentsKit.glimmering_applies("auto_ranged", Abilities.tags_of("auto_ranged"), false, false), "not an auto-shot")

func test_open_talents() -> void:
	assert_true(HolyTalentsKit.first_light_on(0.0))
	assert_true(HolyTalentsKit.first_light_on(Balance.FIRST_LIGHT_TIME))
	assert_false(HolyTalentsKit.first_light_on(Balance.FIRST_LIGHT_TIME + 0.1), "only at the start")

# --- Hooks -------------------------------------------------------------------------------

func test_hooks_in_place() -> void:
	var src := _src()
	for hook in [
		"verse_drain_every(_talent(\"holy_held_note\"))", "Balance.VIGIL_DR_PCT + _talent(\"holy_night_watch\")",
		"radiance_boost(matches, _capstone(\"holy_radiance\"))", "_talent(\"holy_breath_between\")",
		"Balance.FULL_CHOIR_REFUND + int(round(_talent(\"holy_full_voice\")))", "_talent(\"holy_rising_voice\")",
		"_talent(\"holy_mercy_seat\")", "reprise_pct(_talent(\"holy_long_echo\"))", "_talent(\"holy_tender_mercy\")",
		"_talent(\"holy_warded_song\")", "Balance.CHORUS_SPLASH_TARGETS + int(round(_talent(\"holy_choir_loft\")))",
		"int(round(_talent(\"holy_heavy_motes\")))", "_talent(\"holy_cloying_smoke\")", "_tick_hold_the_line()",
		"_talent(\"holy_shaken_loose\")", "_talent(\"holy_turned_aside\")", "int(round(_talent(\"holy_ringing_censer\")))",
		"_talent(\"holy_offering\")", "_talent(\"holy_full_censer\")", "_talent(\"holy_heavy_smoke\")",
		"_capstone(\"holy_censers_weight\")", "_talent(\"holy_thirsty_glass\")", "_talent(\"holy_full_glass\")",
		"_capstone(\"holy_brilliance\")", "_talent(\"holy_lifeline\")", "_capstone(\"holy_sunsteel\")", "_polish(i)",
		"_talent(\"holy_focused_light\"), _talent(\"holy_brilliance\")", "aftershine(a)", "bright_shards()",
		"_talent(\"holy_last_glint\")", "_talent(\"holy_gilded\")", "_talent(\"holy_full_gold\")",
		"_talent(\"holy_pinpoint\"), _talent(\"holy_lined_up\")", "_talent(\"holy_gilt_tips\")", "_talent(\"holy_sundown\")",
		"_talent(\"holy_dazzle\")", "_talent(\"holy_light_draw\")", "_talent(\"holy_candlelight\")", "_talent(\"holy_first_light\")",
		"_on_heal_done_holy", "_holy_talents_incoming(info)", "holy_talents.heal_mult(tgt, id)".replace("holy_talents.", ""),
	]:
		assert_contains(src, hook)
