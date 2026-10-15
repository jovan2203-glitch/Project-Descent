@tool
extends McpTestSuite

# Arcane melee: a damage dealer with a melee weapon in each hand, on cooldowns
# alone. Its strikes leave Traces (records of the damage they dealt) and Encore
# replays them. Swift Cut, Deep Cut, Late Cut, Wide Cut, Encore, Double Time, and
# the talents Standing Ovation, Long Memory, Clean Lines and Second Showing.

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const TextFill = preload("res://scripts/core/text_fill.gd")
const Keywords = preload("res://scripts/core/keywords.gd")
const Items = preload("res://scripts/items.gd")

const KIT := ["swiftcut", "deepcut", "latecut", "encore", "widecut", "doubletime"]
const NAMES := {"swiftcut": "Swift Cut", "deepcut": "Deep Cut", "latecut": "Late Cut", "encore": "Encore",
	"widecut": "Wide Cut", "doubletime": "Double Time"}
const LEVELS := {"swiftcut": 6, "deepcut": 14, "encore": 18, "latecut": 24, "widecut": 30, "doubletime": 40}
const STRIKES := ["swiftcut", "deepcut", "latecut", "widecut"]
# [key, name, ranks, the ability it needs, slot, values]
const TALENTS := [
	["arcane_long_memory", "Long Memory", 2, "encore", "arcane_r6c3", [2.0, 4.0]],
	["arcane_clean_lines", "Clean Lines", 2, "deepcut", "arcane_r6c4", [0.5, 1.0]],
	["arcane_standing_ovation", "Standing Ovation", 3, "encore", "arcane_r6c5", [5.0, 10.0, 15.0]],
	["arcane_second_showing", "Second Showing", 2, "encore", "arcane_r7c5", [10.0, 20.0]],
]
const MELEE := ["Ability", "Arcane", "Melee"]

func suite_name() -> String:
	return "arcane_melee"

func _player() -> GDScript:
	return load("res://scripts/player.gd")

func _file(id: String) -> Resource:
	return ResourceLoader.load("res://data/abilities/%s.tres" % id, "", ResourceLoader.CACHE_MODE_IGNORE)

func _typed_number(raw: String) -> String:
	var text := RegEx.create_from_string("\\{[^}]*\\}").sub(raw, "", true)
	var m := RegEx.create_from_string("[0-9]+([.,][0-9]+)?").search(text)
	return m.get_string() if m else ""

func _has_method(path: String, method: String) -> bool:
	for m in (load(path) as GDScript).get_script_method_list():
		if str(m["name"]) == method:
			return true
	return false

func _trace(id: String, key: int, amount: int, born: float, until: float) -> Dictionary:
	return {"id": id, "key": key, "amount": amount, "born": born, "until": until}

# --- The kit ---------------------------------------------------------------------------

func test_the_kit() -> void:
	for id in KIT:
		var r := _file(id)
		assert_true(r != null, "%s exists" % id)
		assert_eq(str(r.id), id)
		assert_eq(str(r.display_name), str(NAMES[id]))
		assert_true(bool(r.requires_dual_wield), "%s needs a weapon in each hand" % id)
		assert_eq(int(r.weapon_requirement), 1, "%s: melee weapons" % id)
		assert_eq(int(r.resource_type), 0, "%s has no resource: cooldowns alone" % id)
		assert_eq(int(r.resource_cost), 0)
		assert_eq(int(r.cast_type), 0, "%s is instant" % id)
		assert_true(r.tags.has("Ability") and r.tags.has("Arcane") and not r.tags.has("Spell"), "%s is an Arcane ability" % id)
		assert_eq(str(r.damage_type), "arcane")
		assert_eq(float(r.threat_multiplier), 1.0, "%s: a damage dealer's threat" % id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is draftable and has a card" % id)
		assert_eq(SkillCards.ability_of(id), id)
		assert_eq(SkillCards.level_of(id), int(LEVELS[id]), "%s: its card's level" % id)
		assert_eq(Abilities.category_of(id), "arcane")
		assert_false(Abilities.ICON_FORM.has(id), "%s has an icon of its own" % id)
		assert_eq(_typed_number(str(r.description)), "", "%s: number typed into its description" % id)
		var text := Abilities.fill(id, str(r.description), Callable(), {})
		assert_eq(TextFill.leftover(text), "", "%s: every placeholder is filled" % id)
		assert_false(text.contains("?"), "%s: %s" % [id, text])
		assert_false(text.contains("Frost Bolt"), "%s: real damage numbers" % id)
		assert_contains(Abilities.tooltip(id), "Requires a melee weapon in each hand")
	# No card shares its place in the list.
	var orders := {}
	for id in SkillCards.ALL:
		var order := int(SkillCards.get_resource(id).sort_order)
		if KIT.has(id) or KIT.has(str(orders.get(order, ""))):
			assert_false(orders.has(order), "%s: sort order %d is taken by %s" % [id, order, orders.get(order, "")])
		orders[order] = id

func test_numbers() -> void:
	var want := {"swiftcut": [0.0, 1.0], "deepcut": [6.0, 1.8], "latecut": [10.0, 0.8], "widecut": [8.0, 0.7],
		"encore": [0.0, 0.0], "doubletime": [90.0, 0.0]}   # (Encore has no cooldown: it needs Traces to replay)
	for id in want:
		var r := Abilities.get_resource(str(id))
		assert_eq(float(r.cooldown), float(want[id][0]), "%s: cooldown" % id)
		assert_eq(float(r.weapon_damage_multiplier), float(want[id][1]), "%s: weapon damage" % id)
		assert_eq(float(r.damage), 0.0)
	assert_eq(float(Abilities.get_resource("widecut").radius), 5.0)
	assert_eq(float(_file("encore").cooldown), 0.0, "the file agrees")
	assert_eq(float(Balance.ABILITIES["encore"]["cooldown"]), 0.0)
	assert_eq(Balance.TRACE_MAX, 3)
	assert_eq(Balance.TRACE_TIME, 10.0)
	assert_eq(Balance.ENCORE_PCT, 60.0)
	assert_eq(Balance.LATE_CUT_DELAY, 3.0)
	assert_eq(Balance.DOUBLE_TIME_TIME, 10.0)
	assert_eq(Balance.DOUBLE_TIME_TRACES, 2)
	var p := _player()
	for id in STRIKES + ["encore"]:
		assert_true(p.on_gcd(id), "%s is on the global cooldown" % id)
	assert_false(p.on_gcd("doubletime"), "Double Time is off the global cooldown")
	for id in ["swiftcut", "deepcut", "latecut", "encore"]:
		assert_true(bool(Abilities.get_resource(id).requires_target))
		assert_true(Abilities.uses_weapon_reach(id), "%s: within the weapon's reach" % id)
	assert_false(bool(Abilities.get_resource("widecut").requires_target), "it goes out around you")
	for id in STRIKES:
		assert_true(Abilities.has_scaling(id))
	assert_false(Abilities.has_scaling("encore"), "a share of recorded damage: nothing to scale")
	assert_false(Abilities.has_scaling("doubletime"))

## The strikes count both weapons, like Double Up.
func test_strikes_use_both_weapons() -> void:
	var sword := Items.get_item("sword")
	var dagger := Items.get_item("dagger")
	if Abilities.offhand_weapon().is_empty():
		var both := float(sword["damage"]) + float(dagger["damage"])
		assert_true(is_equal_approx(Abilities.hit_base("swiftcut", sword), both))
		assert_true(is_equal_approx(Abilities.hit_base("deepcut", sword), both * 1.8))
		assert_true(is_equal_approx(Abilities.hit_base("latecut", sword), both * 0.8))
		assert_true(is_equal_approx(Abilities.hit_base("widecut", sword), both * 0.7))
	for id in STRIKES:
		assert_contains(str(_file(id).description), "with both weapons")

func test_tooltips() -> void:
	assert_contains(Abilities.tooltip("swiftcut"), "leaves a Trace")
	assert_contains(Abilities.tooltip("latecut"), "3 sec later")
	assert_contains(Abilities.tooltip("latecut"), "the second hit is added to it")
	assert_contains(Abilities.tooltip("encore"), "60% of the damage it recorded")
	assert_contains(Abilities.tooltip("widecut"), "within 5 m")
	assert_contains(Abilities.tooltip("widecut"), "a single Trace")
	var dt := Abilities.tooltip("doubletime")
	assert_contains(dt, "For 10 sec")
	assert_contains(dt, "leaves 2 Traces")
	assert_contains(dt, "2 times as many")
	# Trace is a keyword, explained with the numbers from balance.gd.
	assert_true(Keywords.KEYWORDS.has("trace"))
	var entry: Dictionary = Keywords.KEYWORDS["trace"]
	assert_true(entry["forms"].has("Trace") and entry["forms"].has("Traces"))
	assert_eq(_typed_number(str(entry["text"])), "")
	var text := TextFill.constants(str(entry["text"]))
	assert_eq(TextFill.leftover(text), "")
	assert_contains(text, "up to 3")
	assert_contains(text, "10 sec")
	assert_contains(text, Abilities.ability_name("encore"))

# --- Traces -----------------------------------------------------------------------------

func test_what_leaves_a_trace() -> void:
	var p := _player()
	var melee := PackedStringArray(MELEE)
	assert_true(p.leaves_trace(melee, false, false, 100))
	assert_false(p.leaves_trace(melee, true, false, 100), "never a proc (Encore's replays, Late Cut's second hit)")
	assert_false(p.leaves_trace(melee, false, true, 100), "never damage over time")
	assert_false(p.leaves_trace(melee, false, false, 0), "a strike that did nothing leaves nothing")
	assert_false(p.leaves_trace(PackedStringArray(["Arcane", "Spell"]), false, false, 100), "not a spell")
	assert_false(p.leaves_trace(PackedStringArray(["Ability", "Arcane", "AoE"]), false, false, 100), "not Ripple: it is no strike")
	assert_false(p.leaves_trace(PackedStringArray(["Ability", "Lightning", "Melee"]), false, false, 100), "only Arcane")
	# The kit's strikes do, and so do the tank's and Arcane Strike.
	for id in STRIKES + ["doubleup", "missedbeat", "arcanestrike"]:
		assert_true(p.leaves_trace(Abilities.tags_of(id), false, false, 100), "%s leaves a Trace" % id)
	assert_true(_has_method("res://scripts/player.gd", "_trace_hit"))

func test_how_many_and_how_long() -> void:
	var p := _player()
	assert_eq(p.trace_cap(false, false), 3)
	assert_eq(p.trace_cap(true, false), 4, "Standing Ovation's capstone")
	assert_eq(p.trace_cap(false, true), 6, "Double Time")
	assert_eq(p.trace_cap(true, true), 8)
	assert_eq(p.trace_time(0.0), 10.0)
	assert_eq(p.trace_time(2.0), 12.0)
	assert_eq(p.trace_time(4.0), 14.0, "Long Memory")

func test_a_strike_leaves_a_trace() -> void:
	var p := _player()
	var t: Array = p.traces_after([], "swiftcut", 100, 1.0, 11.0, 1, 3, 1)
	assert_eq(t.size(), 1)
	assert_eq(int(t[0]["amount"]), 100)
	assert_eq(float(t[0]["until"]), 11.0)
	t = p.traces_after(t, "deepcut", 300, 3.0, 13.0, 1, 3, 2)
	t = p.traces_after(t, "swiftcut", 120, 5.0, 15.0, 1, 3, 3)
	assert_eq(t.size(), 3, "another Swift Cut later is a Trace of its own")
	# A fourth pushes out the oldest.
	t = p.traces_after(t, "latecut", 80, 7.0, 17.0, 1, 3, 4)
	assert_eq(t.size(), 3)
	assert_eq(str(t[0]["id"]), "deepcut", "the oldest is gone")
	assert_eq(str(t[2]["id"]), "latecut", "the newest is last")
	# The input is not changed.
	var before := [_trace("swiftcut", 1, 100, 1.0, 11.0)]
	p.traces_after(before, "deepcut", 5, 2.0, 12.0, 1, 3, 2)
	assert_eq(before.size(), 1)

func test_wide_cut_leaves_one_trace() -> void:
	var p := _player()
	var t: Array = p.traces_after([], "widecut", 50, 1.0, 11.0, 1, 3, 1)
	t = p.traces_after(t, "widecut", 90, 1.0, 11.0, 1, 3, 2)
	t = p.traces_after(t, "widecut", 70, 1.05, 11.05, 1, 3, 3)
	assert_eq(t.size(), 1, "however many enemies it hits")
	assert_eq(int(t[0]["amount"]), 90, "its largest hit")
	assert_eq(Balance.TRACE_MERGE_WINDOW, 0.25)
	t = p.traces_after(t, "widecut", 60, 9.0, 19.0, 1, 3, 4)
	assert_eq(t.size(), 2, "the next Wide Cut is a new Trace")

func test_late_cuts_second_hit_joins_its_trace() -> void:
	var p := _player()
	var t: Array = p.traces_after([], "latecut", 200, 1.0, 11.0, 1, 3, 7)
	t = p.traces_after(t, "swiftcut", 100, 2.5, 12.5, 1, 3, 8)
	assert_eq(p.newest_trace_key(t, "latecut"), 7)
	assert_eq(p.newest_trace_key(t, "deepcut"), -1)
	t = p.traces_added(t, 7, 200)
	assert_eq(int(t[0]["amount"]), 400, "both hits in one Trace")
	assert_eq(int(t[1]["amount"]), 100, "the others are untouched")
	assert_eq(p.traces_added(t, 99, 500), t, "a Trace that is gone gets nothing")
	assert_true(_has_method("res://scripts/player.gd", "_late_cut"))

func test_double_time() -> void:
	var p := _player()
	var cap: int = p.trace_cap(false, true)
	var t: Array = p.traces_after([], "deepcut", 300, 1.0, 11.0, Balance.DOUBLE_TIME_TRACES, cap, 1)
	assert_eq(t.size(), 2, "each strike leaves two")
	assert_eq(int(t[0]["key"]), int(t[1]["key"]), "copies of one strike")
	for i in 3:
		t = p.traces_after(t, "swiftcut", 100, 3.0 + i * 2.0, 13.0 + i * 2.0, Balance.DOUBLE_TIME_TRACES, cap, 2 + i)
	assert_eq(t.size(), 6, "and you hold twice as many")
	assert_eq(str(t[0]["id"]), "swiftcut", "the oldest pair was pushed out")
	# Late Cut's second hit joins both copies.
	var late: Array = p.traces_after([], "latecut", 200, 1.0, 11.0, 2, cap, 5)
	late = p.traces_added(late, 5, 200)
	assert_eq(int(late[0]["amount"]), 400)
	assert_eq(int(late[1]["amount"]), 400)

## Double Time ends while I hold more than the usual limit: those Traces stay
## (to be replayed, or to run out), and no new one comes until I am back within it.
func test_traces_kept_when_double_time_ends() -> void:
	var p := _player()
	var t: Array = []
	for i in 3:
		t = p.traces_after(t, "swiftcut", 100 + i, 1.0 + i, 11.0 + i, Balance.DOUBLE_TIME_TRACES, p.trace_cap(false, true), 1 + i)
	assert_eq(t.size(), 6)
	# Double Time is over: the limit is 3 again.
	var cap: int = p.trace_cap(false, false)
	var after: Array = p.traces_after(t, "deepcut", 500, 8.0, 18.0, 1, cap, 9)
	assert_eq(after.size(), 6, "none of them is lost")
	assert_eq(after, t, "and the new strike leaves nothing")
	# Five, then four held: still more than three.
	for held in [5, 4]:
		var some: Array = t.slice(0, held)
		assert_eq(p.traces_after(some, "deepcut", 500, 8.0, 18.0, 1, cap, 9), some, "%d held: nothing changes" % held)
	# They run out one by one as before, and Encore uses them all up.
	assert_eq(p.traces_alive(t, 11.5).size(), 4)
	# Back at the limit, a strike works as it always did: the oldest makes room.
	var three: Array = t.slice(3, 6)
	var next: Array = p.traces_after(three, "deepcut", 500, 8.0, 18.0, 1, cap, 9)
	assert_eq(next.size(), 3)
	assert_eq(str(next[2]["id"]), "deepcut")
	assert_eq(int(next[0]["key"]), int(three[1]["key"]), "the oldest was pushed out")
	# Below it, they simply add up.
	assert_eq(p.traces_after(t.slice(4, 6), "deepcut", 500, 8.0, 18.0, 1, cap, 9).size(), 3)
	# Standing Ovation's capstone: the limit it keeps is four.
	assert_eq(p.traces_after(t.slice(0, 4), "deepcut", 500, 8.0, 18.0, 1, p.trace_cap(true, false), 9).size(), 4)
	assert_eq(str(p.traces_after(t.slice(0, 4), "deepcut", 500, 8.0, 18.0, 1, p.trace_cap(true, false), 9)[3]["id"]), "deepcut")
	var tip := Abilities.tooltip("doubletime")
	assert_contains(tip, "When it ends you keep the Traces you hold")
	assert_eq(_typed_number(str(_file("doubletime").description)), "")

func test_traces_run_out() -> void:
	var p := _player()
	var t := [_trace("swiftcut", 1, 100, 0.0, 10.0), _trace("deepcut", 2, 300, 4.0, 14.0)]
	assert_eq(p.traces_alive(t, 9.9).size(), 2)
	assert_eq(p.traces_alive(t, 10.0).size(), 1, "one by one")
	assert_eq(str(p.traces_alive(t, 10.0)[0]["id"]), "deepcut")
	assert_eq(p.traces_alive(t, 14.0).size(), 0)

# --- Encore -----------------------------------------------------------------------------

func test_encore() -> void:
	var p := _player()
	assert_eq(p.encore_pct(0.0), 60.0)
	assert_eq(p.encore_amount(1000, 60.0), 600)
	assert_eq(p.encore_amount(333, 60.0), 200, "rounded")
	assert_eq(p.encore_amount(0, 60.0), 0)
	assert_true(p.encore_uses_traces(0.0, 0.0), "it uses the Traces up")
	assert_true(_has_method("res://scripts/player.gd", "_encore"))
	assert_true(_has_method("res://scripts/player.gd", "_wide_cut"))
	assert_true(_has_method("res://scripts/player.gd", "traces"))

## Encore's picture: a ghost of the character runs through the target for each
## Trace, and each Trace's hit lands as its ghost gets there.
func test_encores_ghosts() -> void:
	const TraceGhost = preload("res://scripts/trace_ghost.gd")
	assert_eq(TraceGhost.delay_of(0), 0.0, "the first sets off at once")
	assert_true(is_equal_approx(TraceGhost.delay_of(2), 2 * TraceGhost.STAGGER), "the rest follow one by one")
	var from := Vector3(0, 1, 0)
	var to := Vector3(0, 1, -4)
	# One ghost starts where the character stands; more of them start side by side.
	assert_true(TraceGhost.start_of(from, to, 0, 1).is_equal_approx(from))
	var left: Vector3 = TraceGhost.start_of(from, to, 0, 3)
	var mid: Vector3 = TraceGhost.start_of(from, to, 1, 3)
	var right: Vector3 = TraceGhost.start_of(from, to, 2, 3)
	assert_true(mid.is_equal_approx(from), "the middle one starts where the character stands")
	assert_true(is_equal_approx(left.distance_to(mid), TraceGhost.LANE))
	assert_true((left + right).is_equal_approx(from * 2.0), "the others either side of it")
	assert_true(is_equal_approx(left.z, from.z) and is_equal_approx(left.y, from.y), "side by side, across the line to the target")
	assert_true(TraceGhost.start_of(from, from, 2, 3).is_equal_approx(from), "no line to stand across: where the character is")
	# Its hit lands when it reaches the target: later for each one after the first.
	assert_true(is_equal_approx(TraceGhost.hit_time(from, to, 0, 1), 4.0 / TraceGhost.SPEED))
	var last := -1.0
	for i in 6:
		var at: float = TraceGhost.hit_time(from, to, i, 6)
		assert_true(at > last, "ghost %d lands after the one before it" % i)
		last = at
	assert_true(last < 1.0, "six Traces are all replayed within a second")
	assert_true(TraceGhost.MAX_GHOSTS >= _player().trace_cap(true, true), "a ghost for every Trace you can hold")
	# The party sees them too.
	assert_contains(FileAccess.get_file_as_string("res://scripts/net/net.gd"), "\"ghosts\":")
	assert_contains(FileAccess.get_file_as_string("res://scripts/player.gd"), "_net_fx(\"ghosts\"")

# --- Talents ----------------------------------------------------------------------------

func test_talents_are_in_the_tree() -> void:
	for row in TALENTS:
		var id := Talents.id_for_key(str(row[0]))
		assert_eq(id, str(row[4]), "%s sits in its slot" % row[1])
		var t := Talents.get_talent(id)
		assert_eq(str(t.get("name", "")), str(row[1]))
		assert_eq(Talents.max_rank(id), int(row[2]))
		assert_eq(t.get("values", []), row[5])
		assert_eq(Talents.required_ability(id), str(row[3]))
		assert_true(bool(t.get("implemented", false)), "%s does something" % row[1])
		assert_true(TalentIcons.has_icon(id), "%s has an icon" % row[1])
		var tip := Talents.tooltip(id, 1)
		assert_eq(TextFill.leftover(tip), "", "%s: every placeholder is filled" % row[1])
		assert_false(tip.contains("?"), "%s: %s" % [row[1], tip])
		assert_eq(_typed_number(str(t.get("desc", ""))), "", "%s: no typed numbers" % row[1])
		assert_eq(_typed_number(str(t.get("capstone", ""))), "", "%s: no typed numbers in the capstone" % row[1])
	# Encore's two are joined, the more important one on top.
	var ovation := Talents.id_for_key("arcane_standing_ovation")
	var showing := Talents.id_for_key("arcane_second_showing")
	assert_true(Talents.targets_of(ovation).has(showing))
	assert_true(Talents.tier_of(ovation) < Talents.tier_of(showing))
	assert_eq(Talents.col_of(ovation), Talents.col_of(showing), "straight down")

func test_talent_numbers() -> void:
	var p := _player()
	var d := func(key: String) -> String: return Talents.description(Talents.id_for_key(key))
	assert_contains(d.call("arcane_standing_ovation"), "65 / 70 / 75%")
	assert_eq(p.encore_pct(15.0), 75.0)
	assert_eq(p.encore_amount(1000, p.encore_pct(15.0)), 750)
	assert_eq(Balance.STANDING_OVATION_TRACES, 1)
	assert_contains(Talents.capstone_text(Talents.id_for_key("arcane_standing_ovation")), "1 more Trace")
	assert_contains(d.call("arcane_long_memory"), "2 / 4 sec longer")
	assert_contains(d.call("arcane_clean_lines"), "0.5 / 1 sec off the cooldown")
	assert_contains(d.call("arcane_clean_lines"), Abilities.ability_name("swiftcut"))
	assert_contains(d.call("arcane_clean_lines"), Abilities.ability_name("deepcut"))
	assert_contains(d.call("arcane_second_showing"), "10 / 20% chance")
	assert_false(p.encore_uses_traces(20.0, 19.9), "the chance came up: the Traces stay")
	assert_true(p.encore_uses_traces(20.0, 20.0))
	assert_true(p.encore_uses_traces(10.0, 50.0))
