@tool
extends McpTestSuite

# The Shadow healer: a demon that holds allies up on puppet Strings. A fixed
# handful of Strings (String ties one; its charges are the ones in your hand),
# heals shared along them, Crossed Strings (an ally's damage moved to an enemy),
# and the kit around them. Rules: player.gd, "Shadow healer: the Strings". The
# demon and the threads: scripts/puppeteer.gd (only a picture).

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")
const Keywords = preload("res://scripts/core/keywords.gd")
const Effects = preload("res://scripts/core/effects.gd")
const Details = preload("res://scripts/core/details.gd")
const StatusContainer = preload("res://scripts/core/status_container.gd")
const Puppeteer = preload("res://scripts/puppeteer.gd")

# In the order their Skill Cards unlock.
const KIT := ["puppetstring", "patchup", "hoist", "tug", "catscradle", "wrench", "pulltaut", "cuppedhands", "stringup", "restring",
	"knot", "tangle", "yank", "doublethread", "behinditsback", "slack", "stillstanding", "cutthestrings", "notfinished"]
const NAMES := {"puppetstring": "String", "patchup": "Patch Up", "hoist": "Hoist", "tug": "Tug", "catscradle": "Cat's Cradle",
	"wrench": "Wrench", "pulltaut": "Pull Taut", "cuppedhands": "Cupped Hands", "stringup": "String Up", "restring": "Restring",
	"knot": "Knot", "tangle": "Tangle", "yank": "Yank", "doublethread": "Double Thread", "behinditsback": "Behind Its Back",
	"slack": "Slack", "stillstanding": "Still Standing", "cutthestrings": "Cut the Strings", "notfinished": "Not Finished With You"}
const LEVELS := [4, 6, 8, 12, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 42, 44, 46]
# id: [cooldown, mana cost (in units), cast time, range, radius]
const NUMBERS := {
	"puppetstring": [0.0, 0, 0.0, 40.0, 0.0], "patchup": [0.0, 2, 2.0, 40.0, 0.0], "hoist": [0.0, 3, 2.0, 40.0, 0.0],
	"tug": [6.0, 1, 0.0, 40.0, 0.0], "catscradle": [20.0, 4, 0.0, 0.0, 30.0], "wrench": [8.0, 1, 0.0, 40.0, 0.0],
	"pulltaut": [15.0, 0, 0.0, 40.0, 0.0], "cuppedhands": [25.0, 2, 0.0, 40.0, 0.0], "stringup": [30.0, 2, 0.0, 30.0, 0.0],
	"restring": [20.0, 0, 0.0, 40.0, 0.0], "knot": [30.0, 0, 0.0, 40.0, 0.0], "tangle": [25.0, 2, 0.0, 30.0, 5.0],
	"yank": [45.0, 0, 0.0, 40.0, 0.0], "doublethread": [30.0, 0, 0.0, 0.0, 0.0], "behinditsback": [60.0, 0, 0.0, 0.0, 0.0],
	"slack": [60.0, 0, 0.0, 0.0, 0.0], "stillstanding": [120.0, 0, 0.0, 40.0, 0.0], "cutthestrings": [120.0, 0, 0.0, 0.0, 0.0],
	"notfinished": [300.0, 0, 0.0, 40.0, 0.0]}
const CASTS := ["patchup", "hoist"]
const HEALERS := ["patchup", "hoist", "tug", "catscradle", "pulltaut"]

func suite_name() -> String:
	return "strings"

func _player() -> GDScript:
	return load("res://scripts/player.gd")

func _has_method(method: String) -> bool:
	for m in PlayerSource.methods_of(_player()):
		if str(m["name"]) == method:
			return true
	return false

func _typed_number(raw: String) -> String:
	var text := RegEx.create_from_string("\\{[^}]*\\}").sub(raw, "", true)
	var m := RegEx.create_from_string("[0-9]+([.,][0-9]+)?").search(text)
	return m.get_string() if m else ""

func _status() -> Node:
	var owner_node: Node = track(Node.new())
	var st: Node = StatusContainer.new()
	st.name = "Status"
	owner_node.add_child(st)
	return st

## Something shaped like a character: 1.8 m tall and 0.8 m wide, its origin in its middle.
func _body(scene: Node, at: Vector3) -> Node3D:
	var b := Node3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	b.add_child(cs)
	b.position = at
	scene.add_child(b)
	return b

func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001

# --- The kit ---------------------------------------------------------------------------

func test_the_kit() -> void:
	assert_eq(KIT.size(), 19)
	for i in KIT.size():
		var id := str(KIT[i])
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s exists" % id)
		assert_eq(str(r.id), id)
		assert_eq(str(r.display_name), str(NAMES[id]))
		assert_eq(int(r.weapon_requirement), 0, "%s: any weapon" % id)
		assert_true(r.tags.has("Shadow") and r.tags.has("Spell") and not r.tags.has("Ability"), "%s is a Shadow spell" % id)
		assert_eq(r.tags.has("Heal"), HEALERS.has(id), "%s: the Heal tag" % id)
		assert_eq(str(r.damage_type), "shadow")
		assert_eq(int(r.cast_type), 1 if CASTS.has(id) else 0, "%s: how it is cast" % id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is draftable and has a card" % id)
		assert_eq(SkillCards.ability_of(id), id)
		assert_eq(SkillCards.level_of(id), int(LEVELS[i]), "%s: its card's level" % id)
		assert_eq(int(SkillCards.get_resource(id).sort_order), 421 + i, "%s: its place in the card list" % id)
		assert_eq(Abilities.category_of(id), "shadow")
		assert_false(Abilities.ICON_FORM.has(id), "%s has an icon of its own" % id)
		assert_eq(_typed_number(str(r.description)), "", "%s: number typed into its description" % id)
		var tip := Abilities.tooltip(id)
		assert_eq(TextFill.leftover(tip), "", "%s: every placeholder is filled" % id)
		assert_false(tip.contains("?"), "%s: %s" % [id, tip])
		assert_false(tip.contains("Frost Bolt"), "%s: real numbers" % id)
	# The book: the Hounds, Shadow Arrow, then the healer in the order it is learned.
	var book := Abilities.in_category("shadow")
	assert_true(book.find("shadowarrow") < book.find("puppetstring"))
	for i in range(1, KIT.size()):
		assert_true(book.find(KIT[i - 1]) < book.find(KIT[i]), "%s comes after %s" % [KIT[i], KIT[i - 1]])
	# No card of the kit shares its place in the list.
	var orders := {}
	for id in SkillCards.ALL:
		var order := int(SkillCards.get_resource(id).sort_order)
		if KIT.has(id) or KIT.has(str(orders.get(order, ""))):
			assert_false(orders.has(order), "%s: sort order %d is taken by %s" % [id, order, orders.get(order, "")])
		orders[order] = id

func test_numbers() -> void:
	for id in NUMBERS:
		var want: Array = NUMBERS[id]
		var r := Abilities.get_resource(id)
		var b: Dictionary = Balance.ABILITIES[id]
		assert_eq(float(r.cooldown), float(want[0]), "%s: cooldown" % id)
		assert_eq(int(b.get("cost", 0)), int(want[1]), "%s: cost" % id)
		if int(want[1]) > 0:
			assert_eq(Abilities.resource_of(id), "mana", "%s costs mana" % id)
		assert_eq(float(r.cast_time), float(want[2]), "%s: cast time" % id)
		if float(want[3]) > 0.0:
			assert_eq(float(r.cast_range), float(want[3]), "%s: range" % id)
		if float(want[4]) > 0.0:
			assert_eq(float(r.radius), float(want[4]), "%s: radius" % id)
	assert_eq(float(Abilities.get_resource("wrench").damage), 1.0)
	assert_eq(float(Abilities.HEALS["hoist"]), 2.8)
	assert_eq(float(Abilities.HEALS["patchup"]), 1.8)
	assert_true(float(Abilities.HEALS["patchup"]) < float(Abilities.HEALS["hoist"]), "the heal that needs no String is the worse one")
	assert_eq(float(Abilities.HEALS["tug"]), 0.6)
	assert_eq(float(Abilities.HEALS["catscradle"]), 1.0)
	# The Strings.
	assert_eq(Balance.STRING_MAX, 6)
	assert_eq(Balance.STRING_RECHARGE, 10.0)
	assert_eq(Balance.STRING_TIME, 15.0)
	assert_eq(Balance.STRING_ENEMY_TIME, 10.0)
	assert_eq(Balance.STRING_STACKS, 3)
	assert_eq(Balance.STRING_HEAL, 0.07)
	assert_eq(Balance.STRING_TICK, 1.0)
	assert_eq(Balance.STRING_GCD_MULT, 0.5)
	assert_eq(Balance.STRING_SHARE_PCT, 30.0)
	assert_eq(Balance.STRING_CROSS_PCT, 3.0)
	assert_eq(Balance.STRING_CROSS_RANGE, 30.0)
	assert_eq(Balance.STRING_LEASH, 60.0)
	assert_eq(Balance.LOOSE_STRING_TIME, 8.0)
	# The abilities around them.
	assert_eq(Balance.TUG_TIME, 4.0)
	assert_eq(Balance.TUG_SPEED_MULT, 2.0)
	assert_eq(Balance.KNOT_TIME, 30.0)
	assert_eq(Balance.DOUBLE_THREAD_TIME, 10.0)
	assert_eq(Balance.CUPPED_HANDS_TIME, 5.0)
	assert_eq(Balance.CUPPED_HANDS_SHIELD, 0.45)
	assert_eq(Balance.CUPPED_HANDS_PER_STRING, 0.2)
	assert_eq(Balance.BEHIND_ITS_BACK_TIME, 6.0)
	assert_eq(Balance.BEHIND_ITS_BACK_PCT, 40.0)
	assert_eq(Balance.SLACK_TIME, 4.0)
	assert_eq(Balance.SLACK_MANA, 1.0)
	assert_eq(Balance.NOT_FINISHED_STRINGS, 3)
	assert_eq(Balance.STRING_UP_TIME, 3.0)
	assert_eq(Balance.TANGLE_TIME, 4.0)
	assert_eq(Balance.STILL_STANDING_TIME, 8.0)
	assert_eq(Balance.STILL_STANDING_HOLD, 4.0)
	assert_eq(Balance.STILL_STANDING_HEALTH_PCT, 25.0)
	assert_eq(Balance.CUT_STRINGS_HEAL, 1.2)
	assert_eq(Balance.CUT_STRINGS_DAMAGE, 1.2)
	assert_eq(float(Abilities.get_resource("catscradle").cooldown), 20.0, "everyone on a String at once: not often")

func test_how_they_are_used() -> void:
	var p := _player()
	for id in CASTS:
		assert_true(p.SUPPORT_CASTS.has(id), "%s is cast at an ally like Heal" % id)
		assert_false(StringsKit.STRING_INSTANTS.has(id))
	assert_eq(StringsKit.STRING_INSTANTS.size(), 17)
	for id in KIT:
		if not CASTS.has(id):
			assert_true(StringsKit.STRING_INSTANTS.has(id), "%s is one of the kit's instants" % id)
	# Off the global cooldown: the three that only set something up.
	for id in ["doublethread", "restring", "behinditsback"]:
		assert_true(Abilities.OFF_GCD.has(id) and not p.on_gcd(id), "%s is off the global cooldown" % id)
	for id in KIT:
		if not ["doublethread", "restring", "behinditsback"].has(id):
			assert_true(p.on_gcd(id), "%s is on the global cooldown" % id)
	# Only the three that act on an enemy need one targeted.
	for id in KIT:
		assert_eq(bool(Abilities.get_resource(id).requires_target), ["wrench", "stringup", "tangle"].has(id), "%s: needs an enemy target" % id)
	for m in ["_tick_strings", "_show_strings", "_tie_string", "_string_use_up", "_strings_fall", "_cross_strings", "_crossed_damage",
			"_on_heal_done_strings", "_string_cast_heal", "_tug", "_cats_cradle", "_pull_taut", "_knot", "_wrench", "_cupped_hands",
			"_slack", "_still_standing", "_cut_the_strings", "_restring", "_yank", "_not_finished", "_string_up", "_tangle",
			"receive_support", "_on_string_state", "_crossed_incoming", "_crossed_taken", "_still_standing_limit",
			"string_charges", "strings_on", "on_my_string"]:
		assert_true(_has_method(m), "player.gd has %s" % m)

func test_it_is_wired_in() -> void:
	var src := PlayerSource.text()
	for piece in ["_bus().heal_done.connect(_on_heal_done_strings)", "\t_tick_strings()\n", "amount = _still_standing_limit(amount)",
			"_crossed_incoming(info)", "_crossed_taken(info)", "return _string_precheck(id)", "_string_use(id, res)",
			"_string_cast_heal(spell, tgt, kind)", "gcd_total = string_gcd(gcd_total)", "return str(string_charges())",
			"No Strings left in your hand", "if id == HOIST_ID and not on_my_string(pick[0])",
			"string_charges() < Balance.NOT_FINISHED_STRINGS"]:
		assert_contains(src, piece)
	# The party hears of it, and sees it.
	var net := FileAccess.get_file_as_string("res://scripts/net/net.gd")
	for piece in ["func support_ally(", "func _sup_do(", "p.receive_support(kind, body_of(caster), data)", "\"strings\":", "\"strungup\":",
			"\"tangle\":", "PUPPETEER.hold("]:
		assert_contains(net, piece)
	# A friendly dummy on a crossed String shares what it takes.
	assert_contains(FileAccess.get_file_as_string("res://scripts/training/ally_dummy.gd"), "damage_share")

# --- The Strings ------------------------------------------------------------------------

func test_strings_in_hand() -> void:
	var p := _player()
	assert_eq(StringsKit.strings_in_hand(0, 0), 6, "all of them")
	assert_eq(StringsKit.strings_in_hand(4, 0), 2)
	assert_eq(StringsKit.strings_in_hand(2, 1), 3, "one tied somewhere and one recovering are both out of my hand")
	assert_eq(StringsKit.strings_in_hand(6, 0), 0)
	assert_eq(StringsKit.strings_in_hand(5, 3), 0, "never less than none")
	assert_eq(StringsKit.strings_in_hand(-2, -1), 6)
	assert_eq(StringsKit.string_gcd(1.5), 0.75, "String: half a global cooldown")
	assert_eq(StringsKit.string_gcd(1.0), 0.5)

func test_tying_one_to_an_ally() -> void:
	var p := _player()
	# [Strings afterwards, free ones added, used up]
	assert_eq(StringsKit.string_placed(0), [1, 0, false])
	assert_eq(StringsKit.string_placed(1), [2, 0, false], "another one on the same ally: one more")
	assert_eq(StringsKit.string_placed(2), [3, 0, false])
	assert_eq(StringsKit.string_placed(3), [3, 0, true], "full: it only starts their time over, and is used up")
	assert_eq(StringsKit.string_placed(-1), [1, 0, false])
	# Double Thread: two for one.
	assert_eq(StringsKit.string_placed(0, true), [2, 1, false], "the second one is none of my six")
	assert_eq(StringsKit.string_placed(1, true), [3, 1, false])
	assert_eq(StringsKit.string_placed(2, true), [3, 0, false], "room for one only")
	assert_eq(StringsKit.string_placed(3, true), [3, 0, true])

func test_what_a_string_heals() -> void:
	var p := _player()
	assert_true(_near(StringsKit.string_tick_heal(1), 0.07))
	assert_true(_near(StringsKit.string_tick_heal(2), 0.14))
	assert_true(_near(StringsKit.string_tick_heal(3), 0.21), "three Strings: three times the heal")
	assert_eq(StringsKit.string_tick_heal(0), 0.0)
	assert_true(_near(StringsKit.string_tick_heal(0, true), 0.07), "a loose String of Cat's Cradle heals like one of mine")
	assert_true(_near(StringsKit.string_tick_heal(3, true), 0.28))
	assert_eq(StringsKit.string_tick_interval(1.0), 1.0, "every second")
	assert_true(_near(StringsKit.string_tick_interval(1.25), 0.8), "25% Haste: 25% more heals")
	assert_eq(StringsKit.string_tick_interval(1.0, true), 0.5, "Tug: twice as often")
	assert_true(_near(StringsKit.string_tick_interval(1.25, true), 0.4), "they multiply")
	assert_true(StringsKit.string_tick_interval(1000.0, true) >= 0.1, "never faster than the game can tick")
	# Over its whole time one String heals about a Tug and a half.
	assert_true(_near(StringsKit.pull_taut_coef(Balance.STRING_TIME), 1.05), "Pull Taut on a fresh String: all 15 heals")
	assert_true(_near(StringsKit.pull_taut_coef(5.0), 0.35))
	assert_eq(StringsKit.pull_taut_coef(0.0), 0.0)
	assert_eq(StringsKit.pull_taut_coef(-3.0), 0.0)
	assert_true(_near(StringsKit.pull_taut_coef(30.0), 1.05), "a knotted String gives no more than a fresh one")

func test_heals_are_shared_along_the_strings() -> void:
	var p := _player()
	assert_eq(StringsKit.string_share(100), 30)
	assert_eq(StringsKit.string_share(1000), 300)
	assert_eq(StringsKit.string_share(0), 0)
	assert_eq(StringsKit.string_share(-50), 0)
	for id in ["hoist", "patchup", "tug", "wrench"]:
		assert_true(Abilities.PATHS.has(id), "%s is an ability" % id)
		assert_true(StringsKit.shares_heal(id, true), "%s on an ally on a String is shared" % id)
	# Not the Strings' own heals, nor the ones that reach everybody already.
	for id in ["puppetstring", "catscradle", "pulltaut", "cutthestrings"]:
		assert_false(StringsKit.shares_heal(id, true), "%s is not shared" % id)
	# Not what is no spell or ability: Lifesteal, a talent's or a rune's heal, the share itself.
	for id in ["lifesteal", "stand_over", "rune_something", StringsKit.STRING_SHARE_ID]:
		assert_false(Abilities.PATHS.has(id))
		assert_false(StringsKit.shares_heal(id, Abilities.PATHS.has(id)), "%s is not shared" % id)

func test_crossed_strings_move_damage_to_the_enemy() -> void:
	var p := _player()
	# A hit of 100 with 25% crossed away lands for 75: the enemy takes the other 25.
	assert_true(_near(StringsKit.cross_redirect(75.0, -25.0, 25.0), 25.0))
	# With another 25% taken off by something else it lands for 50: still 25 of the 100.
	assert_true(_near(StringsKit.cross_redirect(50.0, -50.0, 25.0), 25.0))
	assert_eq(StringsKit.cross_redirect(75.0, -25.0, 0.0), 0.0, "not crossed: nothing moves")
	assert_eq(StringsKit.cross_redirect(0.0, -25.0, 25.0), 0.0)
	assert_eq(StringsKit.cross_redirect(10.0, -100.0, 25.0), 0.0)
	assert_eq(StringsKit.CROSSED_ID, "crossed_strings")
	assert_eq(Details.spell_name(StringsKit.CROSSED_ID), "Crossed Strings", "its own line on the meter")
	assert_eq(Details.spell_name(StringsKit.STRING_SHARE_ID), "Shared along the Strings")
	for id in [StringsKit.CROSSED_ID, StringsKit.STRING_SHARE_ID]:
		assert_true(Details.spell_color(id) != Color(0.7, 0.7, 0.75), "%s has a colour" % id)
	assert_true(Balance.STRING_CROSS_RANGE < Balance.STRING_LEASH, "a crossing breaks long before a String does")

func test_the_rest_of_the_kit() -> void:
	var p := _player()
	var heal := Balance.REFERENCE_HEAL
	assert_true(_near(StringsKit.cupped_hands_coef(0), heal * 0.45))
	assert_true(_near(StringsKit.cupped_hands_coef(1), heal * 0.65), "bigger for each String on that ally")
	assert_true(_near(StringsKit.cupped_hands_coef(3), heal * 1.05))
	assert_eq(StringsKit.slack_mana(0), 0.0)
	assert_eq(StringsKit.slack_mana(4), 4.0, "mana back for each String out")
	assert_true(StringsKit.still_standing_lives(25, 100, 25.0), "healed enough: it stays up")
	assert_false(StringsKit.still_standing_lives(24, 100, 25.0), "not enough: it falls when the Strings let go")
	assert_false(StringsKit.still_standing_lives(1, 0, 25.0))
	assert_true(Balance.NOT_FINISHED_STRINGS <= Balance.STRING_STACKS, "one ally can hold what Not Finished With You ties")
	assert_true(Balance.NOT_FINISHED_STRINGS <= Balance.STRING_MAX)

func test_the_buffs() -> void:
	var p := _player()
	var on_string: Resource = StringsKit.make_string_fx()
	assert_eq(str(on_string.id), StringsKit.STRING_BUFF)
	assert_true(bool(on_string.per_caster), "two healers' Strings are two buffs")
	assert_eq(int(on_string.max_stacks), Balance.STRING_STACKS + 1, "three of mine and a loose one")
	assert_eq(float(on_string.duration), Balance.STRING_TIME)
	var behind: Resource = StringsKit.make_behind_fx()
	assert_eq(float(behind.damage_mod_pct), -40.0)
	assert_true(bool(behind.modifies_incoming) and bool(behind.mod_affects_dots), "less of every kind of damage")
	assert_eq(float(behind.duration), 6.0)
	assert_eq(float(StringsKit.make_double_thread_fx().duration), 10.0)
	assert_eq(float(StringsKit.make_slack_fx().duration), 4.0)
	assert_eq(float(StringsKit.make_cupped_hands_fx(5.0).duration), 5.0)
	assert_eq(float(StringsKit.make_still_standing_fx(8.0).duration), 8.0)
	assert_eq(float(StringsKit.make_held_up_fx(4.0).duration), 4.0)
	for fx in [on_string, behind, StringsKit.make_double_thread_fx(), StringsKit.make_slack_fx(), StringsKit.make_cupped_hands_fx(5.0),
			StringsKit.make_still_standing_fx(8.0), StringsKit.make_held_up_fx(4.0)]:
		assert_false(bool(fx.is_debuff), "%s is a buff" % fx.id)
		assert_true(str(fx.description) != "", "%s says what it does" % fx.id)
		assert_true((fx.stat_modifiers as Dictionary).is_empty(), "%s changes no stat" % fx.id)
	# The buff shows how many Strings, from each healer on their own.
	var st := _status()
	var healer_a: Node = track(Node.new())
	var healer_b: Node = track(Node.new())
	st.apply(on_string, healer_a)
	st.apply(on_string, healer_b)
	assert_true(st.has_from(StringsKit.STRING_BUFF, healer_a) and st.has_from(StringsKit.STRING_BUFF, healer_b))
	assert_true(st.set_stacks_from(StringsKit.STRING_BUFF, healer_a, 3))
	assert_true(st.remove_from(StringsKit.STRING_BUFF, healer_a))
	assert_false(st.has_from(StringsKit.STRING_BUFF, healer_a))
	assert_true(st.has_from(StringsKit.STRING_BUFF, healer_b), "one healer's Strings going leaves the other's")

func test_string_up_and_tangle() -> void:
	Balance.apply_effects()
	var up: Resource = Effects.get_effect("strung_up")
	assert_true(up != null and bool(up.stun) and bool(up.is_debuff), "String Up stuns")
	assert_eq(float(up.duration), Balance.STRING_UP_TIME)
	assert_eq(str(Abilities.get_resource("stringup").on_hit_effect.id), "strung_up")
	var held: Resource = Effects.get_effect("tangled")
	assert_true(held != null and bool(held.root) and not bool(held.stun), "Tangle roots")
	assert_eq(float(held.duration), Balance.TANGLE_TIME)
	assert_eq(str(Abilities.get_resource("tangle").on_hit_effect.id), "tangled")
	assert_contains(Abilities.tooltip("stringup"), TextFill.num(Balance.STRING_UP_TIME) + " sec")
	assert_contains(Abilities.tooltip("tangle"), TextFill.num(Balance.TANGLE_TIME) + " sec")

func test_the_words() -> void:
	for kid in ["strings", "crossed"]:
		assert_true(Keywords.KEYWORDS.has(kid))
		assert_eq(_typed_number(str(Keywords.KEYWORDS[kid]["text"])), "", "%s: number typed into its text" % kid)
		var text := Keywords.keyword_text(kid)
		assert_eq(TextFill.leftover(text), "", "%s: every placeholder is filled" % kid)
		assert_false(text.contains("?"), text)
	assert_contains(Keywords.keyword_text("strings"), "holds 6 Strings")
	assert_contains(Keywords.keyword_text("strings"), "30%")
	assert_contains(Keywords.keyword_text("crossed"), "3% less damage")
	for id in ["puppetstring", "hoist", "tug", "pulltaut", "knot", "cuppedhands", "slack", "cutthestrings", "notfinished"]:
		assert_true(Keywords.mentions(Abilities.tooltip(id)).has("k:strings"), "%s: Shift explains the Strings" % id)
	for id in ["puppetstring", "wrench"]:
		assert_true(Keywords.mentions(Abilities.tooltip(id)).has("k:crossed"), "%s: Shift explains the crossing" % id)
	# String says what one does: the heal, how long, how many, and what it costs.
	var tip := Abilities.tooltip("puppetstring")
	assert_contains(tip, "for 15 sec")
	assert_contains(tip, "Up to 3")
	assert_contains(tip, "lasts 10 sec")
	assert_contains(tip, "50% of a global cooldown")

# --- Talents (where each sits: tests/test_shadow_talents.gd) --------------------------------

func test_talents_of_the_strings_themselves() -> void:
	var p := _player()
	# Long Thread: Strings on allies last longer, and Pull Taut gives all of that.
	assert_eq(StringsKit.string_time_with(0.0), 15.0)
	assert_eq(StringsKit.string_time_with(4.0), 19.0)
	assert_eq(StringsKit.string_time_with(-3.0), 15.0)
	assert_true(_near(StringsKit.pull_taut_coef(19.0, 19.0), 0.07 * 19.0), "a fresh String with Long Thread")
	assert_true(_near(StringsKit.pull_taut_coef(19.0), 1.05), "without it: no more than its usual time")
	# Spare Spool: used-up Strings are back sooner.
	assert_eq(StringsKit.string_recharge(0.0), 10.0)
	assert_eq(StringsKit.string_recharge(2.0), 8.0)
	assert_eq(StringsKit.string_recharge(50.0), 1.0, "never at once")
	# Taking the Weight: a bigger share, and (capstone) from further apart.
	assert_eq(StringsKit.cross_pct_with(0.0), Balance.STRING_CROSS_PCT)
	assert_eq(StringsKit.cross_pct_with(5.0), 5.0, "the talent's number replaces the usual one")
	assert_eq(StringsKit.cross_pct_with(7.0), 7.0)
	assert_eq(StringsKit.cross_range_with(false), 30.0)
	assert_eq(StringsKit.cross_range_with(true), 40.0)
	assert_eq(Balance.TAKING_THE_WEIGHT_RANGE, 40.0)
	assert_true(Balance.TAKING_THE_WEIGHT_RANGE < Balance.STRING_LEASH, "still well inside what a String reaches")
	# Full Harness: only with every String an ally can hold.
	assert_eq(StringsKit.full_harness_pct(3, 6.0), 6.0)
	assert_eq(StringsKit.full_harness_pct(2, 6.0), 0.0, "two Strings: nothing")
	assert_eq(StringsKit.full_harness_pct(3, 0.0), 0.0, "not without the talent")
	# First Stitch: so many heals of one String at once.
	assert_true(_near(StringsKit.first_stitch_coef(2.0), 0.14))
	assert_true(_near(StringsKit.first_stitch_coef(4.0), 0.28))
	assert_eq(StringsKit.first_stitch_coef(0.0), 0.0)
	assert_eq(Details.spell_name(StringsKit.FIRST_STITCH_ID), "First Stitch", "its own line on the meter")
	assert_false(StringsKit.shares_heal(StringsKit.FIRST_STITCH_ID, Abilities.PATHS.has(StringsKit.FIRST_STITCH_ID)), "and it is not shared along the Strings")
	# Steady Hands: every String heal.
	assert_eq(StringsKit.steady_heal(0.07, 0.0), 0.07)
	assert_true(_near(StringsKit.steady_heal(0.07, 15.0), 0.0805))
	assert_true(_near(StringsKit.steady_heal(StringsKit.string_tick_heal(3, true), 15.0), 0.28 * 1.15), "loose Strings too")
	var src := PlayerSource.text()
	for piece in ["_steady(string_tick_heal(int(e[\"n\"]), loose))", "_steady(pull_taut_coef(", "_steady(first_stitch_coef(stitch))",
			"string_recharge(_talent(\"shadow_spare_spool\"))", "data[\"cross\"] = _cross_pct()", "data[\"dr\"] = full_harness_pct(",
			"info.add_bonus(-float(s[\"dr\"]), FULL_HARNESS_LABEL)", "cross_range_with(_capstone(\"shadow_taking_the_weight\"))"]:
		assert_contains(src, piece)
	assert_false(src.contains("now + Balance.STRING_TIME"), "every String's time asks Long Thread")

func test_talents_of_one_ability_each() -> void:
	var p := _player()
	# Heave: Hoist heals more for each String on its target; (capstone) faster on a full one.
	assert_eq(StringsKit.heave_mult(0, 10.0), 1.0)
	assert_true(_near(StringsKit.heave_mult(2, 5.0), 1.1))
	assert_true(_near(StringsKit.heave_mult(3, 10.0), 1.3))
	assert_true(_near(StringsKit.heave_mult(9, 10.0), 1.3), "no more than an ally can hold")
	assert_eq(StringsKit.heave_mult(3, 0.0), 1.0)
	assert_eq(Balance.HEAVE_CAST, 0.5)
	assert_eq(StringsKit.heave_cast(2.0, 3, true), 1.5)
	assert_eq(StringsKit.heave_cast(2.0, 2, true), 2.0, "only on an ally with all three")
	assert_eq(StringsKit.heave_cast(2.0, 3, false), 2.0, "only the capstone")
	# Snap Back: Pull Taut's String straight back.
	assert_true(StringsKit.snaps_back(50.0, 49.9))
	assert_false(StringsKit.snaps_back(50.0, 50.0))
	assert_false(StringsKit.snaps_back(0.0, 0.0), "not without the talent")
	# Give and Take: Slack stops the healing for less long.
	assert_eq(StringsKit.slack_time(0.0), 4.0)
	assert_eq(StringsKit.slack_time(1.0), 3.0)
	assert_eq(StringsKit.slack_time(3.0), 1.0)
	assert_eq(StringsKit.slack_time(9.0), 0.0)
	# Long Drop: a hit of its own when String Up lets go.
	assert_eq(Details.spell_name(StringsKit.LONG_DROP_ID), "Long Drop")
	assert_true(Details.spell_color(StringsKit.LONG_DROP_ID) != Color(0.7, 0.7, 0.75))
	for m in ["_tick_long_drops", "_lean_on_me", "_others_heal_mult", "string_time", "_cross_pct", "_steady"]:
		assert_true(_has_method(m), "player.gd has %s" % m)
	var src := PlayerSource.text()
	for piece in ["coef *= heave_mult(strings_on(who), _talent(\"shadow_heave\"))", "heave_cast(duration, strings_on(_cast_target), _capstone(\"shadow_heave\"))",
			"snaps_back(_talent(\"shadow_snap_back\"), randf() * 100.0)", "slack_time(_talent(\"shadow_give_and_take\"))",
			"_long_drops.append(", "deal_damage(foe, coef, LONG_DROP_ID, true, \"shadow\"", "\t_tick_long_drops()"]:
		assert_contains(src, piece)

func test_the_open_talents_of_the_healer() -> void:
	var p := _player()
	# Many Hands: heals on anyone but me.
	assert_true(_near(StringsKit.many_hands_mult(true, 6.0), 1.06))
	assert_eq(StringsKit.many_hands_mult(false, 6.0), 1.0, "not on myself")
	assert_eq(StringsKit.many_hands_mult(true, 0.0), 1.0)
	# Lean On Me: less damage of every kind for a while.
	assert_eq(Balance.LEAN_ON_ME_TIME, 4.0)
	var lean: Resource = StringsKit.make_lean_on_me_fx(6.0)
	assert_eq(str(lean.id), StringsKit.LEAN_ON_ME_FX)
	assert_eq(float(lean.damage_mod_pct), -6.0)
	assert_true(bool(lean.modifies_incoming) and bool(lean.mod_affects_dots))
	assert_eq(float(lean.duration), 4.0)
	assert_false(bool(lean.is_debuff))
	# Left Hanging: every stun and root I apply, and nothing else.
	Balance.apply_effects()
	var with_talent := func(key: String, _field: String) -> float: return 20.0 if key == "shadow_left_hanging" else 0.0
	assert_true(_near(Abilities.effect_time_bonus(Effects.get_effect("strung_up"), with_talent), 0.6), "20% of String Up's 3 sec")
	assert_true(_near(Abilities.effect_time_bonus(Effects.get_effect("tangled"), with_talent), 0.8), "20% of Tangle's 4 sec")
	for id in ["stunned", "rooted"]:
		var fx: Resource = Effects.get_effect(id)
		assert_true(_near(Abilities.effect_time_bonus(fx, with_talent), float(fx.duration) * 0.2), "%s: another book's" % id)
	for id in ["chilled", "burning", "laid_open"]:
		assert_eq(Abilities.effect_time_bonus(Effects.get_effect(id), with_talent), 0.0, "%s is neither" % id)
	assert_eq(Abilities.effect_time_bonus(Effects.get_effect("strung_up"), func(_k: String, _f: String) -> float: return 0.0), 0.0)
	var src := PlayerSource.text()
	for piece in ["_lean_on_me()   # Lean On Me", "else _others_heal_mult(tgt)), id)", "coef *= _others_heal_mult(tgt)   # Many Hands",
			"Balance.STRING_UP_TIME + effect_duration_bonus(fx)"]:
		assert_contains(src, piece)

# --- The demon and the threads (scripts/puppeteer.gd) -------------------------------------

func test_where_the_demon_hangs() -> void:
	assert_eq(Puppeteer.behind_spot(Vector3.ZERO, 0.0), Vector3(0.0, Puppeteer.UP, Puppeteer.BACK), "behind (characters look down -Z) and above")
	var turned := Puppeteer.behind_spot(Vector3(3.0, 0.0, 0.0), PI)
	assert_true(turned.distance_to(Vector3(3.0, Puppeteer.UP, -Puppeteer.BACK)) < 0.001, "it stays behind whichever way they face")
	assert_eq(Puppeteer.thread_count(1), 2)
	assert_eq(Puppeteer.thread_count(2), 3)
	assert_eq(Puppeteer.thread_count(3), 4, "one more thread for each String")
	assert_eq(Puppeteer.thread_count(0), 2)
	assert_eq(Puppeteer.thread_count(9), 4)
	assert_eq(Puppeteer.hand_thread_length(50.0), Puppeteer.HAND_THREAD, "never a thread across the whole screen")
	assert_eq(Puppeteer.hand_thread_length(1.0), 1.0)
	assert_eq(Puppeteer.hand_thread_length(0.0), 0.3)

func test_holding_and_letting_go() -> void:
	var scene: Node3D = track(Node3D.new())
	var healer := _body(scene, Vector3.ZERO)
	var ally := _body(scene, Vector3(4.0, 0.0, -30.0))
	var foe := _body(scene, Vector3(-3.0, 0.0, -8.0))
	assert_true(Puppeteer.demon_of(healer) == null, "no Strings out: no demon")
	Puppeteer.hold(scene, healer, [[ally, 2, false], [foe, 1, true]])
	var demon := Puppeteer.demon_of(healer)
	assert_true(demon != null, "Strings out: the demon is there")
	assert_eq(demon.kind, Puppeteer.DEMON)
	assert_true(demon.spot().distance_to(Puppeteer.behind_spot(Vector3.ZERO, 0.0)) < 0.001, "behind its owner")
	assert_eq(demon.targets.size(), 2)
	var threads := Puppeteer.threads_of(healer)
	assert_eq(threads.size(), 2, "threads over everyone it holds")
	var over_ally: Node3D = threads[ally.get_instance_id()]
	var over_foe: Node3D = threads[foe.get_instance_id()]
	assert_eq(over_ally.threads_shown(), 3, "two Strings")
	assert_eq(over_foe.threads_shown(), 2)
	assert_true(over_foe.enemy and not over_ally.enemy)
	assert_true(over_ally.spot().distance_to(ally.position) < 0.001, "on the target, not strung from the demon")
	# A thread from its hands towards each of them, and it is short however far they are.
	demon._advance(0.1)
	assert_eq(demon.threads_shown(), 2)
	for line in demon._lines:
		if (line as MeshInstance3D).visible:
			assert_true((line as MeshInstance3D).basis.y.length() <= Puppeteer.HAND_THREAD + 0.001, "the thread fades out long before it gets there")
	# The threads over someone follow where they stand, never how they turn.
	ally.position = Vector3(5.0, 0.0, -30.0)
	ally.rotation.y = 1.3
	for i in 20:
		over_ally._advance(0.05)
	assert_true(over_ally.spot().distance_to(ally.position) < 0.05)
	assert_eq(over_ally.rotation.y, 0.0, "they do not spin with the one they hold")
	# The demon drifts after its owner: it is not bolted to their back.
	healer.position = Vector3(10.0, 0.0, 0.0)
	var goal := Puppeteer.behind_spot(healer.position, 0.0)
	demon._advance(0.05)
	var gap: float = (demon.spot() as Vector3).distance_to(goal)
	assert_true(gap > 1.0 and gap < 10.0, "one frame later it is on its way, not there: %s" % gap)
	for i in 60:
		demon._advance(0.05)
	assert_true(demon.spot().distance_to(goal) < 0.05, "then it catches up")
	# A third String on the ally; the enemy's is gone.
	Puppeteer.hold(scene, healer, [[ally, 3, false]])
	threads = Puppeteer.threads_of(healer)
	assert_eq(threads.size(), 1)
	assert_eq(over_ally.threads_shown(), 4)
	assert_true(over_foe.leaving(), "its threads fade out")
	assert_eq(Puppeteer.demon_of(healer).targets.size(), 1)
	# Nothing held any more: the demon goes too.
	Puppeteer.hold(scene, healer, [])
	assert_true(Puppeteer.demon_of(healer) == null)
	assert_true(Puppeteer.threads_of(healer).is_empty())
	assert_true(demon.leaving() and over_ally.leaving())
	assert_false(healer.has_meta(Puppeteer.META))

func test_strung_up_and_tangled_pictures() -> void:
	var scene: Node3D = track(Node3D.new())
	var foe := _body(scene, Vector3(2.0, 0.0, 2.0))
	var model := Node3D.new()
	model.name = "Model"
	foe.add_child(model)
	var up: Node3D = Puppeteer.string_up(scene, foe, 3.0)
	assert_true(up != null and up.lift and up.enemy)
	assert_eq(up.threads_shown(), 4)
	up._advance(0.3)
	assert_true(_near(model.position.y, Puppeteer.LIFT), "the enemy hangs off the ground: %s" % model.position.y)
	up._advance(3.0)
	assert_true(up.leaving(), "its time is up")
	up._advance(1.0)
	assert_eq(model.position.y, 0.0, "and it is let down again")
	var floor_threads: Node3D = Puppeteer.tangle(scene, Vector3(1.0, 0.0, 1.0), 5.0, 4.0)
	assert_true(floor_threads != null)
	assert_eq(floor_threads.kind, Puppeteer.FLOOR)
	assert_eq(floor_threads.radius, 5.0)
	assert_eq(floor_threads._lines.size(), 12, "threads across the floor")
	assert_true(floor_threads.spot().distance_to(Vector3(1.0, 0.0, 1.0)) < 0.001)
	floor_threads._advance(4.5)
	assert_true(floor_threads.leaving())
