@tool
extends McpTestSuite

# Talent links (Talents.LINKS): an ability's talents run top to bottom, the most
# important first, and maxing one opens the next even if its row is still locked.
# Also the slot changes that made room for them (save version 5 -> 6).

const Talents = preload("res://scripts/talents.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")

## Every link, as talent keys: [from, to].
const WANT := [
	["fire_thick_slag", "fire_hot_iron"], ["fire_hot_iron", "fire_clinker"],
	["fire_clinker", "fire_slag_mending"], ["fire_slag_mending", "fire_furnace_heart"],
	["fire_kindling", "fire_fresh_tinder"], ["fire_fresh_tinder", "fire_afterglow"],
	["fire_afterglow", "fire_forge_heat"], ["fire_forge_heat", "fire_white_heat"],
	["fire_lingering_embers", "fire_long_burn"], ["fire_long_burn", "fire_flashover"],
	["fire_fuse_crit", "fire_flashover"], ["fire_flashover", "fire_stoked_kiln"],
	["frost_absorb", "frost_shield_armor"], ["frost_shield_armor", "frost_ice_floe"],
	["frost_shard_proc", "frost_shardstorm"], ["frost_shardstorm", "frost_splinter"],
	["frost_hoarfrost", "frost_hoarfrost_burst"], ["frost_cold_snap", "frost_instinct"],
	["lightning_long_reach", "lightning_closed_circuit"], ["lightning_closed_circuit", "lightning_earth_return"],
	["lightning_earth_return", "lightning_tempo"], ["lightning_counter_charge", "lightning_second_stroke"],
	["lightning_running_start", "lightning_whip_crack"], ["lightning_quick_fuse", "lightning_rod"],
	["lightning_rod", "lightning_snap_shot"], ["lightning_snap_shot", "lightning_loaded_quiver"],
	["arcane_seventh_sigil", "arcane_etched_darts"], ["arcane_deep_well", "arcane_aftershock"],
	["arcane_sharp_edges", "arcane_clockwork"], ["arcane_clockwork", "arcane_spare_copy"],
	["arcane_light_feet", "arcane_empty_room"], ["arcane_empty_room", "arcane_bent_light"],
	["arcane_standing_ovation", "arcane_second_showing"], ["arcane_second_showing", "arcane_time_signature"],
	["shadow_interest", "shadow_small_change"],
	["shadow_lean_and_hungry", "shadow_fed"], ["shadow_fed", "shadow_worked_up"],
	["shadow_long_night", "shadow_take_it_with_you"], ["shadow_pincer", "shadow_again"],
	["shadow_long_thread", "shadow_spare_spool"],
	["holy_wide_arc", "holy_deep_pour"],
	["holy_wide_burst", "holy_prismatic_burst"],
	["holy_deep_burn", "holy_long_volley"],
	["nature_compost", "nature_bramble_burst"],
]

## Where every talent that changed slot sits now: key -> id.
const MOVED_TO := {
	"fire_long_burn": "fire_r5c3", "fire_volley_targets": "fire_r6c3", "fire_thick_pitch": "fire_r8c3",
	"frost_chilled_dmg": "frost_r1c1", "frost_cold_draw": "frost_r1c5", "frost_absorb": "frost_r1c7",
	"frost_shield_armor": "frost_r4c7", "frost_ice_floe": "frost_r8c7", "frost_hoarfrost_burst": "frost_r5c2",
	"frost_clean_break": "frost_r7c2", "frost_shardstorm": "frost_r6c4", "frost_splinter": "frost_r7c4",
	"frost_dot_duration": "frost_r8c1", "frost_slow_threat": "frost_r9c2", "frost_slow_dr": "frost_r9c6",
	"frost_instinct": "frost_r7c6",
	"lightning_quick_fuse": "lightning_r6c4", "lightning_tight_coil": "lightning_r5c4",
	"lightning_rod": "lightning_r7c4", "lightning_snap_shot": "lightning_r9c4",
	"lightning_second_stroke": "lightning_r6c7", "lightning_tempo": "lightning_r8c5",
	"lightning_parting_spark": "lightning_r8c6",
}

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

## Maxing a talent opens the next one of its line long before its row does.
func test_a_linked_talent_opens_before_its_row() -> void:
	var pd = PlayerDataScript.new()
	pd.level = 1   # 5 points
	pd.talents = {}
	var ward := _id("frost_absorb")
	var hard := _id("frost_shield_armor")
	var floe := _id("frost_ice_floe")
	assert_eq(Talents.tier_of(ward), 0)
	assert_eq(Talents.tier_of(hard), 3)
	assert_ne(pd.can_invest(hard), "", "row 4 is locked")
	for i in 3:
		assert_eq(pd.invest_talent(ward), "")
	assert_false(pd.tier_unlocked(3), "row 4 is still locked")
	assert_eq(pd.can_invest(hard), "", "a maxed Rime Ward opens Hardened Frost")
	assert_ne(pd.can_invest(floe), "", "Ice Floe waits for Hardened Frost to be maxed")
	assert_eq(pd.invest_talent(hard), "")
	assert_eq(pd.invest_talent(hard), "")
	assert_eq(pd.talent_points_left(), 0)
	assert_ne(pd.can_refund(ward), "", "Hardened Frost hangs on the maxed Rime Ward")
	assert_true(PlayerDataScript.talents_valid(pd.talents))
	pd.level = 10
	for i in 2:
		assert_eq(pd.invest_talent(hard), "")
	assert_eq(pd.can_invest(floe), "", "and the line goes on: Ice Floe, five rows early")
	# Points in talents opened by a link never open the rows below them.
	assert_false(pd.tier_unlocked(2), "row 3 still needs 3 points in row 2")
	pd.free()

## The talents that changed slot (save version 5 -> 6) are where LINKS_MOVED says,
## and an old save's points follow them.
func test_moved_talents_and_old_saves() -> void:
	const SaveSystemScript = preload("res://scripts/save_system.gd")
	assert_true(SaveSystemScript.VERSION >= 6)
	assert_eq(Talents.LINKS_MOVED.size(), MOVED_TO.size())
	var news: Array = Talents.LINKS_MOVED.values()
	for key in MOVED_TO:
		assert_eq(_id(str(key)), str(MOVED_TO[key]), "%s has its new slot" % key)
		assert_true(news.has(MOVED_TO[key]), "%s is a destination of LINKS_MOVED" % MOVED_TO[key])
	for old in Talents.LINKS_MOVED:
		assert_true(Talents.exists(str(Talents.LINKS_MOVED[old])), "%s is a slot of today's book" % Talents.LINKS_MOVED[old])
		assert_eq(news.count(Talents.LINKS_MOVED[old]), 1, "no two talents land in %s" % Talents.LINKS_MOVED[old])
		assert_false(Talents.MOVED.has(str(old)), "the every-load table never touches %s" % old)
	# A v5 save: Hardened Frost 4, Splintering 1, Shardstorm 2, Long Burn 3, Tempo 3,
	# and one talent that stayed put.
	var old_save := {"frost_r7c4": 4, "frost_r7c6": 1, "frost_r7c2": 2, "fire_r8c3": 3, "lightning_r6c7": 3, "frost_r1c3": 3}
	var now: Dictionary = Talents.rearranged(old_save, Talents.LINKS_MOVED, [])
	assert_eq(now, {_id("frost_shield_armor"): 4, _id("frost_splinter"): 1, _id("frost_shardstorm"): 2,
		_id("fire_long_burn"): 3, _id("lightning_tempo"): 3, "frost_r1c3": 3})
	for id in now:
		assert_true(int(now[id]) <= Talents.max_rank(str(id)), "%s: no more ranks than the talent has" % id)
