@tool
extends McpTestSuite

# Choice talents: one slot holding two talents, points go into only one of them
# (Talents.options_of; the first is in the Fire book's row 5, Damped or Wild Embers).

const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")

const SLOT := "fire_r5c1"

func suite_name() -> String:
	return "talent_choice"

func _a() -> String:
	return Talents.id_for_key("fire_damped_embers")

func _b() -> String:
	return Talents.id_for_key("fire_wild_embers")

func _pd() -> Object:
	var pd = PlayerDataScript.new()
	pd.level = 50
	if not pd.learned_abilities.has("embervolley"):
		pd.learned_abilities.append("embervolley")
	return pd

func test_the_slot_and_its_two() -> void:
	assert_true(Talents.is_choice_slot(SLOT))
	assert_eq(Talents.options_of(SLOT), [SLOT + "a", SLOT + "b"] as Array[String])
	assert_eq(_a(), SLOT + "a")
	assert_eq(_b(), SLOT + "b")
	assert_eq(Talents.sibling_of(_a()), _b())
	assert_eq(Talents.sibling_of(_b()), _a())
	assert_eq(Talents.sibling_of("fire_r2c1"), "", "an ordinary talent has no sibling")
	assert_eq(Talents.choice_slot_of(_a()), SLOT)
	assert_true(Talents.in_row("fire", 4).has(SLOT), "rows see the slot")
	assert_false(Talents.in_row("fire", 4).has(_a()), "not its two")
	for id in [_a(), _b()]:
		assert_eq(Talents.tier_of(id), 4, "%s sits in the slot's row" % id)
		assert_eq(Talents.max_rank(id), 3)
		assert_eq(Talents.required_ability(id), "embervolley")
		assert_true(TalentIcons.has_icon(id), "%s has an icon" % id)

func test_only_one_of_the_two_takes_points() -> void:
	var pd = _pd()
	pd.talents = {_a(): 1}
	assert_eq(pd.can_invest(_b()), "Remove your points from Damped Embers first")
	assert_eq(pd.can_invest(SLOT), "Pick one of the two talents in this slot", "the slot itself holds no points")
	assert_eq(pd.can_refund(SLOT), "Pick one of the two talents in this slot")
	assert_eq(pd.talent_rank(SLOT), 1, "the slot counts the one taken")
	pd.free()

func test_refunding_one_frees_the_other() -> void:
	var pd = _pd()
	pd.talents = {_a(): 1}
	pd.talents.erase(_a())
	assert_ne(pd.can_invest(_b()), "Remove your points from Damped Embers first")
	assert_eq(pd.talent_rank(SLOT), 0)
	pd.free()

func test_both_at_once_is_invalid() -> void:
	assert_false(PlayerDataScript.talents_valid({_a(): 1, _b(): 1}))
	var pd = _pd()
	pd.talents = {_a(): 1, _b(): 1}
	assert_false(pd.validate_talents(), "a profile holding both is refunded")
	assert_true(pd.talents.is_empty())
	pd.free()

## Points in one of the two count toward their row like any talent's.
func test_the_slot_counts_toward_row_unlocks() -> void:
	var pd = _pd()
	var ranks := {}
	for row in 4:
		var left := 3
		for id in Talents.in_row("fire", row):
			if left <= 0 or Talents.is_choice_slot(id):
				continue
			var n := mini(Talents.max_rank(id), left)
			ranks[id] = n
			left -= n
		assert_eq(left, 0, "row %d holds 3 points" % (row + 1))
	ranks[_a()] = 3
	assert_true(PlayerDataScript.talents_valid(ranks), "row 5 is open: the choice takes points")
	pd.free()

func test_tooltips_fill_for_both() -> void:
	for id in [_a(), _b()]:
		var tip := Talents.tooltip(id, 0)
		assert_false(tip.contains("{"), "%s: every number is filled in" % id)
		assert_contains(tip, "Choice: points go into this or")
	var slot_tip := Talents.tooltip(SLOT, 0)
	assert_contains(slot_tip, "Damped Embers")
	assert_contains(slot_tip, "Wild Embers")
	assert_false(slot_tip.contains("{"))
