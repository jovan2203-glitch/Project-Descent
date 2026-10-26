@tool
extends McpTestSuite

# Talent hints: clicking a talent you can't put points in pulses the talents that
# would open it (PlayerData.talents_to_open); trying to take back a point others
# depend on pulses those others red (PlayerData.talents_blocking_refund).

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
	var pd := _pd()
	var low := _plain("arcane", 0, 3)
	var high := _plain("arcane", 1)
	assert_ne(pd.can_invest(high), "", "row 2 starts locked")
	var help: Array[String] = pd.talents_to_open(high)
	assert_true(help.has(low), "row 1 talents light up")
	for h in help:
		assert_true(Talents.tier_of(h) == 0 or Talents.sources_of(high).has(h), "only talents that open it: %s" % h)

func test_no_hints_without_points() -> void:
	var pd := _pd()
	pd.level = 1
	for id in Talents.in_row("arcane", 0):
		while pd.invest_talent(id) == "":
			pass
	assert_true(pd.talents_to_open(_plain("arcane", 1)).is_empty(), "nothing to suggest with no points left")

func test_refund_shows_what_depends_on_it() -> void:
	var pd := _pd()
	var low := _plain("arcane", 0, 3)
	var high := _plain("arcane", 1)
	for i in 3:
		assert_eq(pd.invest_talent(low), "")
	assert_eq(pd.invest_talent(high), "")
	assert_ne(pd.can_refund(low), "", "row 2 holds the third point up")
	assert_eq(pd.talents_blocking_refund(low), [high] as Array[String])

func test_valid_sets_have_nothing_unreachable() -> void:
	var pd := _pd()
	var low := _plain("arcane", 0, 3)
	for i in 3:
		pd.invest_talent(low)
	assert_true(PlayerDataScript.unreachable(pd.talents).is_empty())
	assert_true(PlayerDataScript.talents_valid(pd.talents))
