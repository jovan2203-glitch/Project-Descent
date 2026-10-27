@tool
extends McpTestSuite

# Talent links (Talents.LINKS): an ability's talents run top to bottom, the most
# important first, and maxing one opens the next even if its row is still locked.
# Also the slot changes that made room for them (save version 5 -> 6).

const Talents = preload("res://scripts/talents.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")

## Every link, as talent keys: [from, to].
const WANT := [
	# Every book is on ribbons.
	["martial_twice_over", "martial_gather_pace"], ["martial_steady_pace", "martial_deep_flow"],
	["martial_mix_it_up", "martial_hot_start"], ["martial_get_up", "martial_back_up"],
	["martial_clean_release", "martial_run_it_back"],
	["fire_stoked_breath", "fire_lean_fuel"], ["fire_clean_burn", "fire_stay_lit"],
	["fire_fuel_the_forge", "fire_heavy_hammer"], ["fire_banked_fire", "fire_overheat"],
	["fire_spreading_fire", "fire_fuel_run"],
	["frost_chilled_dmg", "frost_instinct"], ["frost_instinct", "frost_cold_front"],
	["frost_thaw_water", "frost_meltdown"], ["frost_long_glaze", "frost_long_dark"],
	["frost_cold_fury", "frost_rime_pressure"], ["frost_frost_fletching", "frost_splitting_arrow"],
	["frost_rime_tips", "frost_numb_prey"],
	["lightning_conductive", "lightning_conductor"], ["lightning_deep_draw", "lightning_afterflow"],
	["lightning_afterspark", "lightning_light_load"], ["lightning_built_charge", "lightning_spinning_up"],
	["lightning_counter_charge", "lightning_second_stroke"], ["lightning_earth_return", "lightning_tempo"],
	["arcane_etched_darts", "arcane_sharp_mind"], ["arcane_second_hand", "arcane_unwinding"],
	["arcane_sharp_edges", "arcane_glass_dust"], ["arcane_quick_answer", "arcane_spare_copy"],
	["arcane_last_copy", "arcane_crowded_room"],
	["arcane_standing_ovation", "arcane_time_signature"],
	["shadow_interest", "shadow_small_change"], ["shadow_shut_tight", "shadow_bitter_end"],
	["shadow_long_night", "shadow_take_it_with_you"], ["shadow_pincer", "shadow_again"],
	["shadow_long_thread", "shadow_spare_spool"], ["shadow_three_ply", "shadow_full_harness"],
	["holy_many_voices", "holy_choir_loft"], ["holy_watchful", "holy_night_watch"],
	["holy_wide_arc", "holy_deep_pour"], ["holy_heavy_motes", "holy_shaken_loose"],
	["holy_wide_burst", "holy_prismatic_burst"], ["holy_thirsty_glass", "holy_full_glass"],
	["holy_deep_burn", "holy_long_volley"], ["holy_gilded", "holy_full_gold"],
	["nature_compost", "nature_bramble_burst"], ["nature_thick_mulch", "nature_well_rotted"],
	["nature_second_bud", "nature_pollen"], ["nature_long_bloom", "nature_canopy"],
	["nature_groundswell", "nature_heavy_limbs"], ["nature_long_sap", "nature_brimming"],
	["nature_slow_acting", "nature_fresh_host"], ["nature_double_dose", "nature_full_brew"],
]

func suite_name() -> String:
	return "talent_links"

func setup() -> void:
	Talents.set_links(null)

func _id(key: String) -> String:
	return Talents.id_for_key(key)

func test_every_link_is_there() -> void:
	var have := Talents.links()
	assert_eq(have.size(), Talents.LINKS.size(), "no link of LINKS was thrown away as invalid")
	assert_eq(have.size(), WANT.size())
	for w in WANT:
		var from := _id(str(w[0]))
		var to := _id(str(w[1]))
		assert_ne(from, "", "%s exists" % w[0])
		assert_ne(to, "", "%s exists" % w[1])
		assert_true(have.has([from, to]), "%s -> %s is linked" % [w[0], w[1]])
		assert_true(Talents.targets_of(from).has(to))
		assert_true(Talents.sources_of(to).has(from))
		assert_contains(Talents.tooltip(from, 0), "Maxing this unlocks %s" % Talents.get_talent(to)["name"])
		assert_contains(Talents.tooltip(to, 0), "Also unlocked by maxing %s" % Talents.get_talent(from)["name"])

## A link goes down (or sideways) inside one book, and never touches the bottom
## row: the 5-rank talents there always need the whole row to open.
func test_links_go_down_and_stop_above_the_bottom_row() -> void:
	for l in Talents.links():
		var names := "%s -> %s" % [Talents.get_talent(l[0])["name"], Talents.get_talent(l[1])["name"]]
		assert_eq(Talents.category_of(l[0]), Talents.category_of(l[1]), "%s: one book" % names)
		assert_true(Talents.tier_of(l[0]) <= Talents.tier_of(l[1]), "%s: the first talent is not below the next" % names)
		assert_true(Talents.tier_of(l[1]) < Talents.ROWS - 1, "%s: not into the bottom row" % names)
		assert_false(bool(Talents.get_talent(l[0]).get("placeholder", true)), "%s: a designed talent" % names)
		assert_false(bool(Talents.get_talent(l[1]).get("placeholder", true)), "%s: a designed talent" % names)

func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))

## Gap in px between the line a-b and the square button of talent `id`
## (0 = the line runs behind the button).
func _gap(a: Vector2, b: Vector2, id: String, cell: Vector2, btn: float) -> float:
	var c := (Vector2(Talents.col_of(id), Talents.tier_of(id)) + Vector2(0.5, 0.5)) * cell
	var h := btn / 2.0
	var rect := Rect2(c - Vector2(h, h), Vector2(btn, btn))
	if rect.has_point(a) or rect.has_point(b):
		return 0.0
	var corners := [rect.position, rect.position + Vector2(btn, 0), rect.end, rect.position + Vector2(0, btn)]
	var best := INF
	for i in 4:
		var p: Vector2 = corners[i]
		var q: Vector2 = corners[(i + 1) % 4]
		if Geometry2D.segment_intersects_segment(a, b, p, q) != null:
			return 0.0
		best = minf(best, _seg_dist(p, a, b))
		best = minf(best, minf(_seg_dist(a, p, q), _seg_dist(b, p, q)))
	return best

## No line runs behind (or scrapes) another talent, in the main menu's wide cells
## and in the in-game view's small square ones.
func test_no_line_runs_behind_another_talent() -> void:
	for shape in [[Vector2(34, 34), 28.0], [Vector2(44, 44), 38.0], [Vector2(90, 58), 50.0], [Vector2(60, 58), 50.0]]:
		var cell: Vector2 = shape[0]
		var btn: float = shape[1]
		for l in Talents.links():
			var a := (Vector2(Talents.col_of(l[0]), Talents.tier_of(l[0])) + Vector2(0.5, 0.5)) * cell
			var b := (Vector2(Talents.col_of(l[1]), Talents.tier_of(l[1])) + Vector2(0.5, 0.5)) * cell
			for other in Talents.in_tree(Talents.category_of(l[0])):
				if other == l[0] or other == l[1]:
					continue
				var gap := _gap(a, b, other, cell, btn)
				assert_true(gap >= 5.0, "%s -> %s passes %.1f px from %s (cells %s)" % [Talents.get_talent(l[0])["name"],
					Talents.get_talent(l[1])["name"], gap, Talents.get_talent(other)["name"], cell])

## Maxing a talent opens the next one of its line before its row does: Arcane's
## Sharp Edges -> Spare Seconds -> Spare Copy, down the left edge of rows 2-4.
func test_a_linked_talent_opens_before_its_row() -> void:
	var pd = PlayerDataScript.new()
	pd.level = 10
	pd.learned_abilities.clear()
	var etched := _id("arcane_etched_darts")
	var sharp := _id("arcane_sharp_mind")
	var wound := _id("arcane_wound_up")
	assert_eq([Talents.tier_of(etched), Talents.tier_of(sharp), Talents.tier_of(wound)], [0, 4, 4])
	assert_ne(pd.can_invest(sharp), "", "row 5 is locked")
	for i in Talents.max_rank(etched):
		assert_eq(pd.invest_talent(etched), "")
	assert_false(pd.tier_unlocked(4), "row 5 is still locked")
	assert_eq(pd.can_invest(sharp), "", "a maxed Etched Darts opens Sharp Mind")
	assert_ne(pd.can_invest(wound), "", "the rest of row 5 stays locked")
	assert_eq(pd.invest_talent(sharp), "")
	assert_true(PlayerDataScript.talents_valid(pd.talents))
	pd.free()

## The slot changes of save version 5 -> 6 were all Lightning's; they went with the
## Lightning ribbon tree, which refunded every point (Talents.TREE_VERSION). An old
## save's ranks pass through the migration untouched and are refunded on load.
func test_moved_talents_and_old_saves() -> void:
	const SaveSystemScript = preload("res://scripts/save_system.gd")
	assert_true(SaveSystemScript.VERSION >= 6)
	assert_true(Talents.LINKS_MOVED.is_empty(), "every book it moved talents in has been rebuilt")
	var old_save := {"lightning_r6c7": 3, "lightning_r1c2": 3}
	assert_eq(Talents.rearranged(old_save, Talents.LINKS_MOVED, []), old_save)
