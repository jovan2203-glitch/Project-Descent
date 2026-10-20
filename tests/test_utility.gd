@tool
extends McpTestSuite

# Each book's "Utility" divider (scripts/player/utility.gd): a root for every
# book, each working differently, and Nature's tools, useful to anyone, each
# with a rider only its Nature spec cashes in.

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const StatusContainer = preload("res://scripts/core/status_container.gd")

const NATURE := ["rootsnare", "deeproots", "sporesleep", "leafcloak"]
## The other books' tools coded in utility.gd (id -> book).
const TOOLS := {"bellows": "fire", "stormfront": "lightning", "climbthestring": "shadow", "circleofsilence": "holy"}
const ROOTS := {"rootsnare": "nature", "coolingslag": "fire", "staticsnare": "lightning", "fixedpoint": "arcane", "bindingring": "holy"}

func suite_name() -> String:
	return "utility"

func _utility_spec(book: String) -> Array:
	for s in Abilities.SPECS[book]:
		if s[0] == "Utility":
			return s[1]
	return []

func test_every_utility_ability_is_set_up() -> void:
	var all: Array = NATURE.duplicate()
	for id in ROOTS.keys() + TOOLS.keys():
		if not all.has(id):
			all.append(id)
	for id in all:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s loads" % id)
		assert_true(r.tags.has("Utility") and r.tags.has("Spell"), "%s is a utility spell" % id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is drafted, with a Skill Card" % id)
		assert_true(_utility_spec(Abilities.category_of(id)).has(id), "%s sits in its book's Utility divider" % id)
		assert_eq(float(r.damage), 0.0, "%s deals no damage (no scaling section)" % id)
		var tip := Abilities.tooltip(id)
		assert_false(tip.contains("{") or tip.contains("}") or tip.contains("?"), "%s: %s" % [id, tip])
		assert_true(UtilityKit.INSTANTS.has(id) != UtilityKit.CASTS.has(id), "%s is handled once" % id)
	for id in NATURE:
		assert_eq(Abilities.category_of(id), "nature")
	for id in TOOLS:
		assert_eq(Abilities.category_of(id), TOOLS[id], "%s is %s's" % [id, TOOLS[id]])

## Every book has a Utility divider, and every interrupt sits in one.
func test_every_book_has_a_utility_divider_with_its_interrupts() -> void:
	for book in Abilities.SPECS:
		if (Abilities.SPECS[book] as Array).is_empty():
			continue
		assert_false(_utility_spec(book).is_empty(), "%s has a Utility divider" % book)
	for id in Balance.INTERRUPT_LOCKOUT:
		assert_true(_utility_spec(Abilities.category_of(id)).has(id), "%s (an interrupt) is in its book's Utility" % id)
	assert_true(_utility_spec("shadow").has("tangle"), "Tangle needs no Strings: Utility")

func test_bellows_heat_is_capped() -> void:
	assert_eq(UtilityKit.bellows_heat(0), 0)
	assert_eq(UtilityKit.bellows_heat(2), 2)
	assert_eq(UtilityKit.bellows_heat(99), Balance.BELLOWS_HEAT_MAX)

func test_climb_the_string_stops_short() -> void:
	var at := UtilityKit.climb_spot(Vector3.ZERO, Vector3(10, 3, 0))
	assert_true(absf(float(at.x) - float(10.0 - Balance.CLIMB_STRING_STOP)) < 0.001, "short of the target, on the way to it")
	assert_true(absf(float(at.y)) < 0.001, "keeps my height (the move itself lands me on the floor)")
	var close := UtilityKit.climb_spot(Vector3.ZERO, Vector3(1, 0, 0))
	assert_true(close.length() < 0.001, "already that close: I stay put")

func test_circle_of_silence_is_an_interrupt() -> void:
	assert_true(Abilities.is_interrupt("circleofsilence"))
	assert_true(Abilities.get_resource("circleofsilence").tags.has("Interrupt"))
	assert_true(float(Abilities.get_resource("circleofsilence").cooldown) >= Balance.INTERRUPT_SHARED_COOLDOWN, "shares the interrupt cooldown")

func test_every_new_root_roots_in_its_own_book() -> void:
	for id in ROOTS:
		assert_eq(Abilities.category_of(id), ROOTS[id], "%s is %s's root" % [id, ROOTS[id]])
		assert_true(Abilities.get_resource(id).tags.has("Root"), "%s is tagged Root" % id)
	for fx in [UtilityKit.ROOTSNARED_FX, UtilityKit.SLAGBOUND_FX, UtilityKit.STATIC_SNARED_FX, UtilityKit.FIXED_FX, UtilityKit.RINGBOUND_FX]:
		assert_true(fx.root, "%s roots" % fx.id)
		assert_true(fx.is_debuff)

func test_bellows_throws_away_from_you() -> void:
	var to := UtilityKit.thrown_to(Vector3(2, 0, 0), Vector3.ZERO, 8.0)
	assert_true(absf(float(to.x) - float(10.0)) < 0.001, "8 m further out, straight away from you")
	assert_true(absf(float(to.z) - float(0.0)) < 0.001)
	var on_top := UtilityKit.thrown_to(Vector3(1, 0, 1), Vector3(1, 5, 1), 8.0)
	assert_true(absf(float(Vector2(on_top.x - 1.0, on_top.z - 1.0).length()) - float(8.0)) < 0.001, "standing on you: still thrown the full distance")
	assert_true(absf(float(on_top.y) - float(0.0)) < 0.001, "flat: height is not part of the push")

func test_fixed_point_grows_with_arcane_cooldowns() -> void:
	assert_true(absf(float(UtilityKit.fixed_point_time(0)) - float(Balance.FIXED_POINT_TIME)) < 0.001)
	assert_true(absf(float(UtilityKit.fixed_point_time(2)) - float(Balance.FIXED_POINT_TIME + 2.0 * Balance.FIXED_POINT_PER_COOLDOWN)) < 0.001)
	assert_true(absf(float(UtilityKit.fixed_point_time(99)) - float(Balance.FIXED_POINT_MAX)) < 0.001, "capped")

func test_static_snare_leaps_to_the_nearest_in_reach() -> void:
	var spots := [Vector3(7, 0, 0), Vector3(3, 0, 0), Vector3(20, 0, 0)]
	assert_eq(UtilityKit.leap_pick(Vector3.ZERO, spots, 8.0), 1, "the nearest")
	assert_eq(UtilityKit.leap_pick(Vector3.ZERO, [Vector3(9, 0, 0)], 8.0), -1, "nobody in reach: no leap")

func test_spore_sleep_spares_bosses_and_elites() -> void:
	assert_true(UtilityKit.sleepable("normal"))
	assert_false(UtilityKit.sleepable("elite"))
	assert_false(UtilityKit.sleepable("boss"))
	assert_true(UtilityKit.ASLEEP_FX.stun and UtilityKit.ASLEEP_FX.break_on_damage, "asleep: can't act, wakes when hit")

func test_damage_wakes_a_sleeper() -> void:
	var holder: Node = track(Node.new())
	var st: Node = StatusContainer.new()
	st.name = "Status"
	holder.add_child(st)
	st.apply(UtilityKit.ASLEEP_FX, holder)
	st.apply(UtilityKit.ROOTSNARED_FX, holder)
	assert_true(st.has_flag("stun"))
	st.break_on_damage()
	assert_false(st.has(str(UtilityKit.ASLEEP_FX.id)), "the sleep ended")
	assert_true(st.has(str(UtilityKit.ROOTSNARED_FX.id)), "a root does not end on damage")

func test_buffs_do_what_they_say() -> void:
	var roots: Resource = UtilityKit.make_deep_roots_fx()
	assert_true(absf(float(float(roots.damage_mod_pct)) - float(-Balance.DEEP_ROOTS_PCT)) < 0.001)
	assert_true(roots.modifies_incoming, "less damage TAKEN")
	var run: Resource = UtilityKit.make_storm_front_fx(Balance.STORM_FRONT_TIME)
	assert_true(absf(float(float(run.stat_modifiers.get("move_speed", 0.0))) - float(Balance.STORM_FRONT_PCT)) < 0.001)

func test_the_hooks_are_in_place() -> void:
	var src := PlayerSource.text()
	assert_contains(src, "utility._tick_utility()")
	assert_contains(src, "if utility.no_threat():\n\t\tinfo.threat_multiplier = 0.0", "Leaf Cloak: no threat")
	assert_contains(src, "utility.duration_bonus(res)", "Fixed Point's longer root")
	var enemy := FileAccess.get_file_as_string("res://scripts/enemy.gd")
	assert_contains(enemy, "status.break_on_damage()", "damage wakes a sleeper")
	assert_contains(enemy, "func drop_threat(source: Node)")
	var net := FileAccess.get_file_as_string("res://scripts/net/net.gd")
	assert_contains(net, "func _sup_drop_threat(", "a party member's Leaf Cloak reaches the host")
