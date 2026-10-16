@tool
extends McpTestSuite

# Holy healer #2: the Prisms (nothing to do with the Hymns). Beams from your
# direct heals charge the prisms they pass through and are amplified by them;
# shattering a prism heals around it with its light. Mouseover casting (a
# setting for every ability) is tested here too. Rules: player.gd, "Holy healer:
# the Prisms" and "Mouseover casting". Pictures: scripts/prism.gd, light_beam.gd.

const Abilities = preload("res://scripts/abilities.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const Balance = preload("res://scripts/balance.gd")
const Talents = preload("res://scripts/talents.gd")
const Keywords = preload("res://scripts/core/keywords.gd")
const Details = preload("res://scripts/core/details.gd")

const KIT := ["setprism", "moveprism", "mendingray", "brightlance", "gleam", "prismward", "piercinglight", "realign",
	"shatterprism", "shatterall", "infuse", "kaleidoscope"]

func suite_name() -> String:
	return "prisms"

func _p() -> GDScript:
	return load("res://scripts/player.gd")

func _src() -> String:
	return FileAccess.get_file_as_string("res://scripts/player.gd")

# --- The kit ---------------------------------------------------------------------------

func test_the_kit_is_in_the_holy_book() -> void:
	for id in KIT:
		var r := Abilities.get_resource(id)
		assert_true(r != null, "%s loads" % id)
		assert_eq(Abilities.category_of(id), "holy", "%s is Holy" % id)
		assert_true(Abilities.ALL.has(id) and Abilities.DRAFT_POOL.has(id) and SkillCards.ALL.has(id), "%s is drafted, with a Skill Card" % id)
		assert_true(r.tags.has("Spell") and r.tags.has("Holy"), "%s is a Holy spell" % id)
		assert_eq(int(r.weapon_requirement), 0, "%s needs no weapon" % id)
		var tip := Abilities.tooltip(id)
		assert_false(tip.contains("{") or tip.contains("}"), "%s: every number in its text is filled in: %s" % [id, tip])
	var spec: Array = []
	for s in Abilities.SPECS["holy"]:
		if s[0] == "Line of Light":
			spec = s[1]
	assert_eq(spec, KIT, "the Line of Light spec holds the kit")
	for id in ["setprism", "moveprism", "shatterall"]:
		assert_true(Abilities.OFF_GCD.has(id), "%s is off the global cooldown" % id)

func test_nothing_to_do_with_the_hymns() -> void:
	var p := _p()
	for id in KIT:
		assert_false(p.HYMN_HEALS.has(id), "%s is not a Hymn heal" % id)
		assert_false(Balance.VERSE_GAINS.has(id), "%s gives no Verses" % id)
		assert_false(p.HYMN_INSTANTS.has(id), "%s is not a Hymn instant" % id)

func test_every_icon_is_its_own() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/abilities.gd")
	for id in KIT:
		assert_false(Abilities.ICON_FORM.has(id), "%s is drawn by hand" % id)
		assert_contains(src, "\t\t\"%s\":\n" % id, "%s has a drawn icon" % id)

func test_numbers() -> void:
	# id: [cooldown, mana points, cast time]
	var want := {"setprism": [8.0, 0.5, 0.0], "moveprism": [5.0, 1.0, 0.0], "mendingray": [0.0, 3.0, 3.0],
		"brightlance": [0.0, 3.5, 2.5], "gleam": [0.0, 1.0, 0.0], "prismward": [15.0, 2.0, 0.0],
		"piercinglight": [0.0, 1.5, 1.5], "realign": [20.0, 0.0, 0.0], "shatterprism": [0.0, 0.0, 0.0],
		"shatterall": [20.0, 0.0, 0.0], "infuse": [45.0, 1.0, 0.0], "kaleidoscope": [120.0, 0.0, 0.0]}
	for id in want:
		var r := Abilities.get_resource(id)
		assert_eq(float(r.cooldown), float(want[id][0]), "%s cooldown" % id)
		assert_true(is_equal_approx(float(r.resource_cost), float(want[id][1])), "%s mana" % id)
		if float(want[id][2]) > 0.0:
			assert_eq(float(r.cast_time), float(want[id][2]), "%s cast time" % id)
	var ref := Balance.REFERENCE_HEAL
	assert_true(is_equal_approx(Abilities.HEALS["brightlance"], ref * 1.8))
	assert_true(is_equal_approx(Abilities.HEALS["mendingray"], ref * 1.5))
	assert_true(is_equal_approx(Abilities.HEALS["gleam"], ref * 0.5))
	assert_eq(Balance.PRISM_MAX, 3)
	assert_eq(Balance.PRISM_TIME, 60.0, "a prism lasts 1 min")

# --- The beam ------------------------------------------------------------------------------

func test_on_beam() -> void:
	var p := _p()
	var me := Vector3.ZERO
	var tank := Vector3(10, 0, 0)
	assert_true(p.on_beam(me, tank, Vector3(5, 0, 0), 1.0), "right on the line")
	assert_true(p.on_beam(me, tank, Vector3(5, 0, 0.9), 1.0), "just beside it")
	assert_false(p.on_beam(me, tank, Vector3(5, 0, 1.5), 1.0), "too far beside it")
	assert_true(p.on_beam(me, tank, Vector3(5, 0, 1.5), 2.0), "Clear Glass: a wider line")
	assert_false(p.on_beam(me, tank, Vector3(-2, 0, 0), 1.0), "behind me")
	assert_false(p.on_beam(me, tank, Vector3(12, 0, 0), 1.0), "past the target")
	assert_true(p.on_beam(me, tank, Vector3(5, 3, 0), 1.0), "height doesn't matter (seen from above)")
	assert_false(p.on_beam(me, me, Vector3(0.1, 0, 0), 1.0), "no beam to myself")

func test_charge_and_cap() -> void:
	var p := _p()
	var cap: float = p.prism_cap(0.0)
	assert_true(is_equal_approx(cap, 3.0 * Balance.REFERENCE_HEAL), "3 old Heals")
	assert_true(is_equal_approx(p.prism_cap(40.0), cap * 1.4), "Deep Crystal")
	assert_true(is_equal_approx(p.prism_charged(0.0, 4.0, cap), 1.0), "25% of the heal")
	assert_true(is_equal_approx(p.prism_charged(cap - 0.1, 4.0, cap), cap), "never more than the cap")

func test_amplify() -> void:
	var p := _p()
	assert_true(is_equal_approx(p.amplify_mult(0, 0.0), 1.0))
	assert_true(is_equal_approx(p.amplify_mult(3, 0.0), 1.3), "+10% per prism")
	assert_true(is_equal_approx(p.amplify_mult(3, 10.0), 1.6), "Sharp Facets")

# --- Shattering, moving, targeting --------------------------------------------------------

func test_shatter() -> void:
	var p := _p()
	assert_true(is_equal_approx(p.shatter_share(6.0, 3), 2.0), "split evenly")
	assert_true(is_equal_approx(p.shatter_share(6.0, 0), 6.0), "no division by zero")
	assert_true(is_equal_approx(p.shatter_damage(6.6, 6.6, 0.0), Balance.PRISM_SHATTER_DAMAGE), "full prism: full damage")
	assert_true(is_equal_approx(p.shatter_damage(3.3, 6.6, 0.0), Balance.PRISM_SHATTER_DAMAGE * 0.5), "half full: half")
	assert_true(is_equal_approx(p.shatter_damage(6.6, 6.6, 20.0), Balance.PRISM_SHATTER_DAMAGE * 1.2), "Prismatic Burst")
	assert_eq(Details.HIT_NAMES.get("prism_shatter", ""), "Prism Shatter", "its own meter line")

func test_realign_keeps_the_shape() -> void:
	var p := _p()
	var old := [Vector3(0, 0, 0), Vector3(2, 0, 0), Vector3(1, 0, 2)]
	var got: Array = p.realign_spots(old, Vector3(10, 0, 10))
	assert_eq(got.size(), 3)
	for i in 3:
		for j in 3:
			assert_true(is_equal_approx((got[i] as Vector3).distance_to(got[j]), (old[i] as Vector3).distance_to(old[j])), "same distances")
	var mid: Vector3 = (got[0] + got[1] + got[2]) / 3.0
	assert_true(mid.distance_to(Vector3(10, 0, 10)) < 0.001, "centred on the spot")
	# Their time starts over.
	assert_contains(_src(), "_prisms[i][\"until\"] = until")

func test_picking_a_prism() -> void:
	var p := _p()
	var keys := ["p1", "p2", "p3"]
	var spots := [Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(20, 0, 0)]
	assert_eq(p.pick_prism(keys, spots, "p3", "p2", Vector3.ZERO), 2, "the mouseover one first")
	assert_eq(p.pick_prism(keys, spots, "", "p2", Vector3.ZERO), 1, "then the one I clicked")
	assert_eq(p.pick_prism(keys, spots, "", "", Vector3(19, 0, 0)), 2, "else my closest")
	assert_eq(p.pick_prism(keys, spots, "gone", "", Vector3(1, 0, 0)), 0, "a mouseover that isn't mine is ignored")
	assert_eq(p.pick_prism([], [], "", "", Vector3.ZERO), -1, "none")
	assert_eq(p.closest_index(spots, Vector3(9, 0, 0)), 1, "Move Prism: the one closest to the mouse")

func test_prism_rules_in_the_code() -> void:
	var src := _src()
	assert_contains(src, "while _prisms.size() > _prism_max():", "a new one replaces the oldest")
	assert_contains(src, "_prisms[i][\"light\"] = _my_prism_cap()", "Infuse fills it")
	assert_contains(src, "if all or on_beam(from, to, p[\"pos\"], width):", "Kaleidoscope: every prism counts")

# --- Mouseover casting ----------------------------------------------------------------------

func test_mouseover_setting() -> void:
	var s := FileAccess.get_file_as_string("res://scripts/settings.gd")
	assert_contains(s, "var mouseover_casting := false", "off by default")
	assert_contains(s, "cfg.set_value(\"ui\", \"mouseover_casting\", mouseover_casting)", "saved")
	assert_contains(s, "_row(grid, \"Mouseover casting\", mo)", "in Settings > Interface")

func test_mouseover_gives_the_target_back() -> void:
	var foe_script := GDScript.new()
	foe_script.source_code = "@tool\nextends Node3D\nfunc is_alive() -> bool:\n\treturn true\n"
	foe_script.reload()
	var real: Node3D = track(Node3D.new())
	real.set_script(foe_script)
	var other: Node3D = track(Node3D.new())
	other.set_script(foe_script)
	var pl: Node = track(_p().new())
	pl.set("target", other)
	pl.set("_mo_prev_target", real)
	pl.set("_mo_swapped", true)
	assert_eq(pl.displayed_target(), real, "the ring and frame show my real target meanwhile")
	pl._mouseover_end()   # not casting: an instant, so it is given back at once
	assert_eq(pl.get("target"), real)
	assert_false(bool(pl.get("_mo_swapped")))
	assert_eq(pl.displayed_target(), real)

# --- Talents, keyword ----------------------------------------------------------------------

func test_talents() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/talents.gd")
	for key in ["holy_clear_glass", "holy_deep_crystal", "holy_sharp_facets", "holy_wide_burst",
			"holy_prismatic_burst", "holy_quick_realign"]:
		assert_contains(src, "\"key\": \"%s\"" % key)
	assert_true(Talents.LINKS.has(["holy_wide_burst", "holy_prismatic_burst"]), "Wide Burst opens Prismatic Burst")
	assert_eq(Abilities.COOLDOWN_TALENTS.get("realign", ""), "holy_quick_realign")

func test_keyword() -> void:
	var t := Keywords.keyword_text("prism")
	assert_false(t.contains("{"), t)
	assert_contains(t, "your heals never target a prism")
