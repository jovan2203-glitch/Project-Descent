@tool
extends McpTestSuite

# The Holy healer: three Hymns (stances), Verses that remember the Hymn they suit,
# and the boom of the Hymn you enter with a full set. Rules: player.gd, "Holy
# healer: the Hymns". The ring: scripts/hymn_ring.gd (only a picture).

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const Runes = preload("res://scripts/runes.gd")
const Keywords = preload("res://scripts/core/keywords.gd")
const Details = preload("res://scripts/core/details.gd")

const KIT := ["singmercy", "singchorus", "singvigil", "psalm", "outpour", "lift", "refrain", "canticle", "exultation",
	"antiphon", "shelter", "steadyvoice", "highnote", "reprise", "swell", "rest", "lastverse"]

func suite_name() -> String:
	return "hymns"

func _p() -> GDScript:
	return load("res://scripts/player.gd")

func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001

# --- The kit ---------------------------------------------------------------------------

func test_the_kit_is_in_the_holy_book() -> void:
	for id in KIT:
		assert_true(Abilities.get_resource(id) != null, "%s loads" % id)
		assert_eq(Abilities.category_of(id), "holy", "%s is Holy" % id)
		assert_true(Abilities.ALL.has(id), "%s can go on a bar" % id)
		var tip := Abilities.tooltip(id)
		assert_false(tip.contains("{") or tip.contains("}"), "%s: every number in its text is filled in: %s" % [id, tip])
	assert_eq(Abilities.SPECS["holy"][0][0], "Choir of One")
	for spec in Abilities.specs_in("holy"):
		assert_ne(spec[0], "", "every Holy ability is in a named spec")
	# Psalm is the starter heal: everyone has it, it is on the default bar, never drafted.
	assert_true(Abilities.BASE.has("psalm"))
	assert_false(Abilities.DRAFT_POOL.has("psalm"))
	assert_false(SkillCards.ALL.has("psalm"))
	for id in KIT:
		if id != "psalm":
			assert_true(Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is drafted, and has a Skill Card" % id)
	assert_true(Abilities.OFF_GCD.has("swell"), "Swell is off the global cooldown")
	for id in ["singmercy", "singchorus", "singvigil"]:
		assert_false(Abilities.OFF_GCD.has(id), "%s is on the global cooldown (no free swaps in a macro)" % id)

func test_numbers() -> void:
	# id: [cooldown, mana, cast time]
	var want := {"psalm": [0.0, 2, 2.0], "outpour": [0.0, 4, 3.0], "lift": [8.0, 1, 0.0], "refrain": [0.0, 2, 0.0],
		"canticle": [12.0, 3, 2.5], "exultation": [0.0, 4, 2.0], "antiphon": [15.0, 2, 0.0], "shelter": [12.0, 2, 0.0],
		"steadyvoice": [30.0, 2, 0.0], "highnote": [0.0, 2, 1.5], "swell": [60.0, 0, 0.0], "rest": [60.0, 0, 0.0],
		"lastverse": [180.0, 0, 0.0]}
	for id in want:
		var r := Abilities.get_resource(id)
		assert_eq(float(r.cooldown), float(want[id][0]), "%s cooldown" % id)
		assert_eq(int(r.resource_cost), int(want[id][1]), "%s mana" % id)
		if float(want[id][2]) > 0.0:
			assert_eq(float(r.cast_time), float(want[id][2]), "%s cast time" % id)
	# Heals in old Heals (REFERENCE_HEAL).
	var ref := Balance.REFERENCE_HEAL
	assert_true(_near(Abilities.HEALS["psalm"], ref))
	assert_true(_near(Abilities.HEALS["outpour"], ref * 2.2))
	assert_true(_near(Abilities.HEALS["lift"], ref * 0.5))
	assert_true(_near(Abilities.HEALS["shelter"], ref * 1.2))
	assert_true(_near(Balance.BENEDICTION_HEAL, ref * 3.0))
	assert_true(_near(Balance.CHORALE_HEAL, ref))
	assert_eq(Balance.VIGIL_WARD_PCT, 10.0, "Vigil's shield is 10% of the heal")
	assert_eq(Balance.VERSE_MAX, 6)
	assert_eq(Balance.REPRISE_COST, 3)
	# Exultation: the spammable group heal costs the most mana of the casts.
	for id in ["psalm", "canticle", "highnote"]:
		assert_gt(int(Abilities.get_resource("exultation").resource_cost), int(Abilities.get_resource(id).resource_cost))

func test_every_icon_is_its_own() -> void:
	# Each ability of the kit draws its own picture (none share one: ICON_FORM is for the generic ones).
	for id in KIT:
		assert_false(Abilities.ICON_FORM.has(id), "%s is drawn by hand" % id)
	var src := FileAccess.get_file_as_string("res://scripts/abilities.gd")
	for id in KIT:
		assert_contains(src, "\t\t\"%s\":\n" % id, "%s has a drawn icon" % id)

# --- Verses ------------------------------------------------------------------------------

func test_verses_cap_and_waste() -> void:
	var v: Array = HymnsKit.verses_after_gain([], "mercy", 2)
	assert_eq(v, ["mercy", "mercy"])
	v = HymnsKit.verses_after_gain(v, "chorus", 3)
	assert_eq(v, ["mercy", "mercy", "chorus", "chorus", "chorus"])
	v = HymnsKit.verses_after_gain(v, "vigil", 2)
	assert_eq(v.size(), 6, "never more than VERSE_MAX")
	assert_eq(v[5], "vigil", "the one past the cap is wasted")
	assert_eq(HymnsKit.verses_after_gain(v, "mercy", 1), v)

func test_what_each_ability_gives() -> void:
	var g: Dictionary = HymnsKit.VERSE_GAINS
	assert_eq(g["psalm"], [1, "mercy"])
	assert_eq(g["outpour"], [2, "mercy"])
	assert_eq(g["canticle"], [2, "chorus"])
	assert_eq(g["exultation"], [1, "chorus"], "the spammable group heal gives a white (Chorus) Verse")
	assert_eq(g["steadyvoice"], [2, "vigil"])
	assert_eq(g["shelter"], [1, "vigil"])
	assert_eq(g["highnote"], [1, ""], "High Note: a Verse of the Hymn you sing")

# --- Singing ------------------------------------------------------------------------------

func test_singing() -> void:
	# A full set: the Hymn you enter booms, and every Verse is spent (always, whatever the talents).
	assert_eq(HymnsKit.sing_outcome(6, "mercy", 3, false), [true, 0])
	assert_eq(HymnsKit.sing_outcome(6, "mercy", 0, true), [true, 0], "Rest keeps nothing through a boom")
	# Fewer: you lose them all ...
	assert_eq(HymnsKit.sing_outcome(5, "mercy", 0, false), [false, 0])
	# ... Key Change keeps 1 / 2 / 3 ...
	for rank in [1, 2, 3]:
		assert_eq(HymnsKit.sing_outcome(5, "chorus", rank, false), [false, rank])
	assert_eq(HymnsKit.sing_outcome(2, "chorus", 3, false), [false, 2], "never more than you had")
	# ... Rest keeps them all, and so does your first Hymn.
	assert_eq(HymnsKit.sing_outcome(4, "vigil", 0, true), [false, 4])
	assert_eq(HymnsKit.sing_outcome(4, "", 0, false), [false, 4])
	assert_eq(HymnsKit.sing_outcome(6, "", 0, false), [true, 0], "a full set booms even from no Hymn")

func test_booms_grow_with_matching_verses() -> void:
	var spent := ["mercy", "mercy", "chorus", "vigil", "mercy", "chorus"]
	assert_eq(HymnsKit.matching_verses(spent, "mercy"), 3)
	assert_eq(HymnsKit.matching_verses(spent, "vigil"), 1)
	assert_true(_near(HymnsKit.boom_mult(0, false), 1.0))
	assert_true(_near(HymnsKit.boom_mult(3, false), 1.3))
	assert_true(_near(HymnsKit.boom_mult(6, false), 1.6), "at most +60%")
	assert_true(_near(HymnsKit.boom_mult(6, true), 1.6 * 1.5), "Full Choir: 50% stronger")
	# Bulwark of Song lasts longer instead.
	assert_true(_near(HymnsKit.bulwark_song_time(0, false), Balance.BULWARK_SONG_TIME))
	assert_true(_near(HymnsKit.bulwark_song_time(4, false), Balance.BULWARK_SONG_TIME + 2.0))

func test_full_choir() -> void:
	assert_false(HymnsKit.is_full_choir(["mercy", "chorus"]))
	assert_true(HymnsKit.is_full_choir(["mercy", "chorus", "vigil"]))
	assert_true(HymnsKit.is_full_choir(["vigil", "vigil", "mercy", "chorus"]), "the last three, in any order")
	assert_false(HymnsKit.is_full_choir(["mercy", "chorus", "mercy"]))
	assert_false(HymnsKit.is_full_choir(["chorus", "chorus", "vigil"]))
	# (After a Full Choir the booms start counting over, so one is never part of the next.)

func test_reprise() -> void:
	assert_true(HymnsKit.reprise_ready(1.0, 3))
	assert_false(HymnsKit.reprise_ready(1.0, 2), "costs 3 Verses")
	assert_false(HymnsKit.reprise_ready(Balance.REPRISE_WINDOW + 0.1, 6), "only soon after a boom")

# --- Talents and runes ---------------------------------------------------------------------

func test_talents() -> void:
	var keys := {"holy_mercys_ear": 2, "holy_many_voices": 2, "holy_watchful": 2, "holy_key_change": 3, "holy_open_doors": 4}
	for key in keys:
		var id := Talents.id_for_key(key)
		assert_ne(id, "", "%s is in the tree" % key)
		assert_eq(Talents.category_of(id), "holy")
		assert_eq(int(Talents.get_talent(id)["max_rank"]), int(keys[key]), "%s ranks" % key)
		assert_true(TalentIcons.has_icon(id), "%s has an icon" % key)
	var open_doors := Talents.get_talent(Talents.id_for_key("holy_open_doors"))
	assert_contains(str(open_doors.get("requires", "")), "shelter")
	assert_eq(Balance.OPEN_DOORS_COOLDOWN, 4.0, "the capstone: Shelter every 4 sec")

func test_runes() -> void:
	for id in ["resounding", "overture"]:
		var r := Runes.get_resource(id)
		assert_true(r != null, "%s loads" % id)
		assert_eq(int(r.rarity), 2, "%s is Epic" % id)

func test_words_and_meter() -> void:
	for word in ["Hymn", "Verse", "Full Choir"]:
		assert_true(Keywords.paint(word).contains("["), "%s is a keyword" % word)
	assert_eq(Details.spell_name("benediction"), "Benediction")
	assert_eq(Details.spell_name("chorale"), "Chorale")
	assert_eq(Details.spell_name("chorus_splash"), "Chorus")
