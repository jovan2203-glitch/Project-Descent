@tool
extends McpTestSuite

# The Holy tank: the Censer. Incense (its fullness, a stacking buff) gives Block
# and a little aura; motes of light on the ground give it back and heal; Raise
# the Censer grabs a pack; Unfallen keeps you up. Rules: player.gd, "Holy tank:
# the Censer". Pictures: scripts/censer.gd, scripts/light_mote.gd.

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const Talents = preload("res://scripts/talents.gd")
const Runes = preload("res://scripts/runes.gd")
const Keywords = preload("res://scripts/core/keywords.gd")
const Details = preload("res://scripts/core/details.gd")
const Stats = preload("res://scripts/core/stats.gd")
const StatusContainer = preload("res://scripts/core/status_container.gd")

const KIT := ["censerswing", "hallowedarc", "beckon", "pourout", "absolve", "aureole", "gatherthelight",
	"raisethecenser", "unfallen"]

func suite_name() -> String:
	return "holy_tank"

func _p() -> GDScript:
	return load("res://scripts/player.gd")

func _src() -> String:
	return PlayerSource.text()

# --- The kit ---------------------------------------------------------------------------

func test_the_kit_is_in_the_holy_book() -> void:
	for id in KIT:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s loads" % id)
		assert_eq(Abilities.category_of(id), "holy", "%s is Holy" % id)
		assert_true(Abilities.ALL.has(id), "%s can go on a bar" % id)
		assert_true(Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is drafted, and has a Skill Card" % id)
		assert_true(bool(r.requires_off_hand), "%s needs an off hand" % id)
		assert_false(bool(r.requires_shield), "%s does not need a shield" % id)
		assert_eq(Abilities.resource_of(id), "mana", "%s uses mana" % id)
		assert_true(r.tags.has("Ability") and r.tags.has("Holy"), "%s is a Holy ability (not a spell)" % id)
		var tip := Abilities.tooltip(id)
		assert_false(tip.contains("{") or tip.contains("}"), "%s: every number in its text is filled in: %s" % [id, tip])
		assert_contains(tip, "an off hand", id)
	var spec: Array = []
	for s in Abilities.SPECS["holy"]:
		if s[0] == "Censer Bearer":
			spec = s[1]
	assert_eq(spec, KIT, "the Censer Bearer spec holds the kit")
	for id in ["aureole", "gatherthelight", "unfallen"]:
		assert_true(Abilities.OFF_GCD.has(id), "%s is off the global cooldown" % id)

func test_every_icon_is_its_own() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/abilities.gd")
	for id in KIT:
		assert_false(Abilities.ICON_FORM.has(id), "%s is drawn by hand" % id)
		assert_contains(src, "\t\t\"%s\":\n" % id, "%s has a drawn icon" % id)

func test_numbers() -> void:
	# id: [cooldown, mana points]
	var want := {"censerswing": [0.0, 0.4], "hallowedarc": [8.0, 1.0], "beckon": [10.0, 1.0], "pourout": [12.0, 2.0],
		"absolve": [10.0, 1.5], "aureole": [20.0, 0.0], "gatherthelight": [30.0, 0.0], "raisethecenser": [90.0, 2.0],
		"unfallen": [120.0, 0.0]}
	for id in want:
		var r := Abilities.get_resource(id)
		assert_eq(float(r.cooldown), float(want[id][0]), "%s cooldown" % id)
		assert_true(is_equal_approx(float(r.resource_cost), float(want[id][1])), "%s mana" % id)
	assert_eq(Balance.INCENSE_MAX, 100)
	assert_eq(Balance.INCENSE_TIME, 30.0)
	assert_eq(Balance.MOTE_VALUE, 10)
	assert_eq(Balance.MOTE_MAX, 12)
	# Fractional mana costs reach the game (not rounded to whole points).
	assert_true(is_equal_approx(Abilities.cost_of("censerswing"), 0.4))

## Nonstop tanking runs you out of mana eventually: 4 to 8 minutes on base mana.
func test_mana_runs_out_in_minutes() -> void:
	# Uses per minute of a busy rotation: every cooldown on time, the filler in between.
	var per_min := {"hallowedarc": 7.0, "beckon": 3.0, "pourout": 3.0, "absolve": 4.0, "raisethecenser": 0.67}
	var gcds := 60.0 / 1.5
	var filler := gcds - 7.0 - 3.0 - 3.0 - 4.0 - 0.67
	var spend := filler * Abilities.cost_of("censerswing")
	for id in per_min:
		spend += float(per_min[id]) * Abilities.cost_of(id)
	var regen := Balance.MANA_REGEN * 60.0
	var pool := 10.0   # base mana, in points (each is 10% of base mana)
	assert_gt(spend, regen, "it drains")
	var minutes := pool / (spend - regen)
	assert_true(minutes >= 4.0 and minutes <= 8.0, "runs dry in %.1f minutes" % minutes)

# --- Incense ---------------------------------------------------------------------------

func test_incense_cap_and_gain() -> void:
	var p := _p()
	assert_eq(CenserKit.incense_after(0, 10), 10)
	assert_eq(CenserKit.incense_after(95, 10), 100, "never more than INCENSE_MAX")
	assert_eq(CenserKit.incense_after(40, -5), 40, "no negative gains")
	assert_eq(CenserKit.incense_for_hit(false, false), Balance.INCENSE_PER_HIT)
	assert_eq(CenserKit.incense_for_hit(true, false), Balance.INCENSE_PER_BLOCK)
	assert_eq(CenserKit.incense_for_hit(true, true), Balance.INCENSE_PER_BLOCK * Balance.UNFALLEN_INCENSE_MULT, "Unfallen: more")
	assert_gt(Balance.MOTE_VALUE, Balance.INCENSE_PER_HIT, "hits give little; motes are the main source")

func test_incense_gives_block_per_stack() -> void:
	var p := _p()
	assert_true(is_equal_approx(CenserKit.incense_block_per_stack(0.0), Balance.INCENSE_BLOCK))
	assert_true(is_equal_approx(CenserKit.incense_block_per_stack(0.04), Balance.INCENSE_BLOCK + 0.04), "Bright Barrier")
	# On a real status container: the stat grows with the stacks.
	var owner_node: Node = track(Node.new())
	var st: Node = StatusContainer.new()
	st.name = "Status"
	owner_node.add_child(st)
	var fx: Resource = StatusContainer.make_buff("incense", "Incense", Stats.BLOCK, Balance.INCENSE_BLOCK,
		Balance.INCENSE_TIME, Balance.INCENSE_MAX, Color.WHITE)
	st.apply(fx, null)
	st.set_stacks("incense", 100)
	assert_true(is_equal_approx(st.stat_mod(Stats.BLOCK), Balance.INCENSE_BLOCK * 100.0), "a full censer: +15% Block")

func test_aura() -> void:
	var p := _p()
	assert_true(is_equal_approx(CenserKit.incense_aura_coef(100), Balance.INCENSE_AURA_FULL))
	assert_true(is_equal_approx(CenserKit.incense_aura_coef(50), Balance.INCENSE_AURA_FULL * 0.5))
	assert_eq(CenserKit.incense_aura_coef(0), 0.0)
	assert_true(is_equal_approx(CenserKit.incense_aura_coef(500), Balance.INCENSE_AURA_FULL), "capped")
	assert_eq(Details.HIT_NAMES.get("incense_aura", ""), "Incense", "its own meter line")

# --- Motes of light ---------------------------------------------------------------------

func test_spending_drops_motes() -> void:
	var p := _p()
	assert_eq(CenserKit.motes_for_spend(100, 60.0), [10, 10, 10, 10, 10], "60 Incense in motes, at most MOTE_SPEND_MAX")
	assert_eq(CenserKit.motes_for_spend(40, 60.0), [10, 10, 4], "24: two full motes and a smaller one")
	assert_eq(CenserKit.motes_for_spend(30, 60.0), [10, 8])
	assert_eq(CenserKit.motes_for_spend(100, 80.0), [10, 10, 10, 10, 10], "Deep Pour's capstone: still at most 5")
	assert_eq(CenserKit.motes_for_spend(0, 60.0), [])
	assert_eq(CenserKit.motes_for_spend(1, 60.0), [], "less than one Incense back: nothing")

func test_picking_up_motes() -> void:
	var src := _src()
	# Walking over one picks it up: Incense, a heal with its own meter line, the Bright Burst.
	assert_contains(src, "_gain_incense(int(m.get(\"value\", Balance.MOTE_VALUE)))")
	assert_contains(src, "heal(Balance.MOTE_HEAL_SHARE * Balance.REFERENCE_HEAL * (1.0 + _talent(\"holy_bright_motes\") / 100.0), LIGHT_MOTE_ID)")
	assert_contains(src, "if _has_rune(BRIGHT_BURST_RUNE):")
	assert_eq(Details.HIT_NAMES.get("light_mote", ""), "Light Mote")
	# Too many on the ground: the oldest fades.
	assert_contains(src, "while _motes.size() > Balance.MOTE_MAX:")
	# Gather the Light picks up every one.
	assert_contains(src, "while not _motes.is_empty():\n\t\t\t\t_pick_up_mote(_motes.size() - 1)")
	# Own only: only the owner checks pickups; party members see them faint.
	var net := FileAccess.get_file_as_string("res://scripts/net/net.gd")
	assert_contains(net, "LIGHT_MOTE.spawn(w, at, mkey, false,")

# --- Raise the Censer and Unfallen --------------------------------------------------------

func test_raise_the_censer() -> void:
	var src := _src()
	# The pack around it must attack you; it sheds motes; your Incense is kept and gives nothing.
	assert_contains(src, "_net_taunt(e, Balance.RAISE_CENSER_TAUNT)")
	assert_contains(src, "_drop_mote(_raise_at)")
	assert_contains(src, "status.remove(INCENSE_FX)")
	assert_eq(int(Balance.RAISE_CENSER_TIME / Balance.RAISE_CENSER_SHED_EVERY), 8, "8 motes over its time")
	assert_contains(Abilities.tooltip("raisethecenser"), "no Block and no aura")
	# High Censer shortens its cooldown.
	assert_eq(Abilities.COOLDOWN_TALENTS.get("raisethecenser", ""), "holy_high_censer")

func test_unfallen() -> void:
	var p := _p()
	assert_eq(CenserKit.unfallen_limit(500, 300), 299, "never the last point")
	assert_eq(CenserKit.unfallen_limit(100, 300), 100, "a hit that doesn't kill is untouched")
	assert_eq(CenserKit.unfallen_limit(50, 1), 0)
	assert_eq(CenserKit.unfallen_heal(1000), 300, "30% of what you took")
	assert_eq(CenserKit.unfallen_heal(0), 0)
	assert_contains(_src(), "amount = _unfallen_cap(amount)")

# --- Talents, rune, keywords -------------------------------------------------------------

func test_talents() -> void:
	for key in ["holy_mote_magnet", "holy_bright_barrier", "holy_lingering_light", "holy_wide_arc",
			"holy_deep_pour", "holy_high_censer"]:
		assert_contains(FileAccess.get_file_as_string("res://scripts/talents.gd"), "\"key\": \"%s\"" % key)
	assert_true(Talents.LINKS.has(["holy_wide_arc", "holy_deep_pour"]), "Wide Arc opens Deep Pour")
	assert_eq(Abilities.RADIUS_TALENTS.get("hallowedarc", [""])[0], "holy_wide_arc")

func test_bright_burst_rune() -> void:
	assert_true(Runes.ALL.has("bright_burst"))
	assert_eq(Runes.rarity_name("bright_burst"), "Epic")
	assert_eq(Details.HIT_NAMES.get("bright_burst", ""), "Bright Burst", "its own meter line")
	assert_false(Runes.description("bright_burst").contains("{"))

func test_keywords() -> void:
	assert_false(Keywords.keyword_text("incense").contains("{"), Keywords.keyword_text("incense"))
	assert_false(Keywords.keyword_text("mote").contains("{"), Keywords.keyword_text("mote"))
	assert_contains(Keywords.keyword_text("mote"), "Only you can pick up yours")
