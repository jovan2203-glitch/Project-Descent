@tool
extends McpTestSuite

# Talent hints: clicking a talent you can't put points in pulses the talents that
# would open it (PlayerData.talents_to_open); trying to take back a point others
# depend on pulses those others red (PlayerData.talents_blocking_refund). Every
# book on the ribbon layout (Talents.GROUPS) gets them, capstones included.

const PlayerDataScript = preload("res://scripts/player_data.gd")
const Talents = preload("res://scripts/talents.gd")

func suite_name() -> String:
	return "talent_hints"

## A plain talent of `cat`'s row `row`: no ability needed, no link, not a choice.
func _plain(cat: String, row: int, min_rank := 1) -> String:
	for id in Talents.in_row(cat, row):
		if Talents.required_ability(id) == "" and Talents.sources_of(id).is_empty() \
				and not Talents.is_choice_slot(id) and Talents.max_rank(id) >= min_rank and not Talents.capstone_gated(id):
			return id
	return ""

func _pd() -> Node:
	var pd: Node = track(PlayerDataScript.new())
	pd.level = 50
	pd.learned_abilities.clear()
	return pd

func test_locked_talent_points_to_the_row_above() -> void:
	for cat in Talents.GROUPS:
		var pd := _pd()
		var low := _plain(cat, 0, 3)
		var high := _plain(cat, 1)
		assert_ne(low, "", "%s: a plain row 1 talent" % cat)
		assert_ne(pd.can_invest(high), "", "%s: row 2 starts locked" % cat)
		var help: Array[String] = pd.talents_to_open(high)
		assert_true(help.has(low), "%s: row 1 talents light up" % cat)
		for h in help:
			assert_true(Talents.tier_of(h) == 0 or Talents.sources_of(high).has(h), "%s: only talents that open it: %s" % [cat, h])

## Clicking any spec's locked capstone lights something up to work toward.
func test_a_locked_capstone_lights_the_way() -> void:
	for cat in Talents.GROUPS:
		for g in Talents.groups_of(cat):
			var group := str(g[0])
			if group == Talents.OPEN_GROUP or Talents.UNFINISHED_SPECS.has(group):
				continue
			var cap := ""
			for id in Talents.in_group(cat, group):
				if Talents.capstone_gated(id):
					cap = id
			assert_ne(cap, "", "%s %s has a capstone" % [cat, group])
			var pd := _pd()
			assert_ne(pd.can_invest(cap), "", "%s %s: its capstone starts locked" % [cat, group])
			assert_false(pd.talents_to_open(cap).is_empty(), "%s %s: clicking its capstone lights up talents" % [cat, group])

func test_no_hints_without_points() -> void:
	for cat in Talents.GROUPS:
		var pd := _pd()
		pd.level = 1
		for id in Talents.in_row(cat, 0):
			while pd.invest_talent(id) == "":
				pass
		assert_true(pd.talents_to_open(_plain(cat, 1)).is_empty(), "%s: nothing to suggest with no points left" % cat)

func test_refund_shows_what_depends_on_it() -> void:
	for cat in Talents.GROUPS:
		var pd := _pd()
		var low := _plain(cat, 0, 3)
		var high := _plain(cat, 1)
		for i in 3:
			assert_eq(pd.invest_talent(low), "", "%s: %s" % [cat, low])
		assert_eq(pd.invest_talent(high), "", "%s: %s" % [cat, high])
		assert_ne(pd.can_refund(low), "", "%s: row 2 holds the third point up" % cat)
		assert_eq(pd.talents_blocking_refund(low), [high] as Array[String], cat)

func test_valid_sets_have_nothing_unreachable() -> void:
	var pd := _pd()
	var low := _plain("arcane", 0, 3)
	for i in 3:
		pd.invest_talent(low)
	assert_true(PlayerDataScript.unreachable(pd.talents).is_empty())
	assert_true(PlayerDataScript.talents_valid(pd.talents))

## Both ways a book draws its talents pulse them on a refused click.
func test_both_tree_screens_pulse() -> void:
	for path in ["res://scripts/menu/talent_tree.gd", "res://scripts/ui/talent_tree_view.gd"]:
		var src := FileAccess.get_file_as_string(path)
		assert_contains(src, "talents_to_open(id), RibbonDrawer.HELP", path)
		assert_contains(src, "talents_blocking_refund(which), RibbonDrawer.BLOCK", path)
