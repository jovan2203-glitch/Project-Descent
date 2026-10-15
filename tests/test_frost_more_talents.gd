@tool
extends McpTestSuite

# The four Frost talents in the middle of rows 2, 5, 8 and 10:
# Pinning Frost, Third Bite, Thick Hide, Hard Freeze.

const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const Abilities = preload("res://scripts/abilities.gd")
const Effects = preload("res://scripts/core/effects.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")

func suite_name() -> String:
	return "frost_more_talents"

const NEW := {
	"frost_pinning_frost": ["frost_r2c5", "Pinning Frost", [20.0, 40.0], "icepin"],     # off the middle since rows 2 and 5 were widened
	"frost_third_bite": ["frost_r5c3", "Third Bite", [40.0, 80.0], "froststrike"],
	"frost_thick_hide": ["frost_r8c4", "Thick Hide", [10.0, 20.0], "winterhide"],
	"frost_hard_freeze": ["frost_r10c4", "Hard Freeze", [0.5, 1.0, 1.5], ""],
}

func test_they_sit_in_the_middle_of_the_short_rows() -> void:
	for key in NEW:
		var id := Talents.id_for_key(key)
		assert_eq(id, str(NEW[key][0]), "%s is where it should be" % key)
		var t := Talents.get_talent(id)
		assert_eq(str(t["name"]), str(NEW[key][1]))
		assert_eq(t["values"], NEW[key][2])
		assert_eq(int(t["max_rank"]), (NEW[key][2] as Array).size())
		assert_eq(str(t.get("requires", "")), str(NEW[key][3]))
		if key == "frost_thick_hide" or key == "frost_hard_freeze":
			assert_eq(Talents.col_of(id), 3, "the middle column")
		assert_true(TalentIcons.has_icon(id), "%s has an icon" % key)
		assert_eq(TextFillLeft.leftover(Talents.description(id)), "", "no placeholder left in its text")

const TextFillLeft = preload("res://scripts/core/text_fill.gd")

## Every Frost row is still mirror-symmetric around the middle, 2-4 talents wide.
func test_frost_tree_stays_symmetrical() -> void:
	var rows: Array = Talents.layout("frost")
	assert_eq(rows.size(), Talents.ROWS)
	var total := 0
	for r in rows:
		var cols: Array = r
		total += cols.size()
		assert_true(cols.size() >= Talents.MIN_PER_ROW and cols.size() <= Talents.MAX_PER_ROW)
		for c in cols:
			assert_true(cols.has(Talents.COLUMNS - 1 - int(c)), "column %d has its mirror" % int(c))
	assert_eq(total, 34, "28 talents + the 6 bow talents")
	for id in Talents.in_tree("frost"):
		assert_false(bool(Talents.get_talent(id)["placeholder"]), "%s is designed" % id)
	# Endless Winter, Winter's Clarity and Deep Chill were removed.
	for gone in ["frost_blizzard_radius", "frost_mana_cost", "frost_slow"]:
		assert_eq(Talents.id_for_key(gone), "", "%s is gone" % gone)
	assert_eq(Abilities.radius_bonus("blizzard"), 0.0, "nothing widens Whiteout any more")

## Hard Freeze: Frozen lasts longer (the game and the tooltips ask the same function).
func test_hard_freeze_lengthens_frozen() -> void:
	var frozen: Resource = Effects.get_effect("frozen")
	var with_rank := func(rank: int) -> Callable:
		return func(key: String, _field: String) -> float:
			return Talents.value_at(Talents.id_for_key(key), rank) if key == "frost_hard_freeze" else 0.0
	assert_eq(Abilities.effect_time_bonus(frozen, with_rank.call(0)), 0.0)
	assert_eq(Abilities.effect_time_bonus(frozen, with_rank.call(1)), 0.5)
	assert_eq(Abilities.effect_time_bonus(frozen, with_rank.call(3)), 1.5)
	assert_eq(Abilities.effect_time_bonus(Effects.get_effect("chilled"), with_rank.call(3)), 0.0, "only Frozen")

## Thick Hide is the talent that shortens Winter Hide's cooldown, and needs it learned.
func test_thick_hide_is_wired_to_winter_hide() -> void:
	assert_eq(str(Abilities.COOLDOWN_TALENTS.get("winterhide", "")), "frost_thick_hide")
	var res := Abilities.get_resource("winterhide")
	assert_eq(Abilities.cooldown_of(res), float(res.cooldown), "no talent: the full cooldown")
	assert_eq(Abilities.cooldown_of(Abilities.get_resource("frostnova")), float(Abilities.get_resource("frostnova").cooldown))
	var pd = track(PlayerDataScript.new())
	pd.level = 50
	pd.talents = {"frost_r1c3": 3, "frost_r2c2": 3, "frost_r3c2": 3, "frost_r4c1": 3, "frost_r5c2": 2, "frost_r5c6": 1,
		"frost_r6c4": 3, "frost_r7c4": 3}
	var id := Talents.id_for_key("frost_thick_hide")
	assert_eq(pd.can_invest(id), "Requires Winter Hide to be learned")
	pd.learned_abilities.append("winterhide")
	assert_eq(pd.can_invest(id), "")
