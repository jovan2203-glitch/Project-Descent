@tool
extends McpTestSuite

# Pinning Frost, Third Bite and Hard Freeze (once the middle of the old tree's short
# rows; on the column-group tree since 2026-10-23), and Thick Hide (folded).

const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const Abilities = preload("res://scripts/abilities.gd")
const Effects = preload("res://scripts/core/effects.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")

func suite_name() -> String:
	return "frost_more_talents"

const NEW := {
	"frost_pinning_frost": ["frost_r2c14", "Pinning Frost", [5.0, 10.0, 15.0], ""],   # any root of mine (was Icepin's)
	"frost_third_bite": ["frost_r2c8", "Third Bite", [20.0, 40.0, 60.0], ""],         # any Frost ability that Freezes (was Winter's Bite's)
	"frost_hard_freeze": ["frost_r8c1", "Hard Freeze", [0.5, 1.0, 1.5], ""],
}

func test_where_they_sit() -> void:
	for key in NEW:
		var id := Talents.id_for_key(key)
		assert_eq(id, str(NEW[key][0]), "%s is where it should be" % key)
		var t := Talents.get_talent(id)
		assert_eq(str(t["name"]), str(NEW[key][1]))
		assert_eq(t["values"], NEW[key][2])
		assert_eq(int(t["max_rank"]), (NEW[key][2] as Array).size())
		assert_eq(str(t.get("requires", "")), str(NEW[key][3]))
		assert_true(TalentIcons.has_icon(id), "%s has an icon" % key)
		assert_eq(TextFillLeft.leftover(Talents.description(id)), "", "no placeholder left in its text")

const TextFillLeft = preload("res://scripts/core/text_fill.gd")

## Every slot of the Frost book holds a talent, and the removed ones stay gone.
func test_frost_tree_is_full() -> void:
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

## Thick Hide was folded into Winter Hide: its cooldown is 40 sec, and nothing else shortens it.
func test_thick_hide_was_folded_into_winter_hide() -> void:
	assert_eq(Talents.id_for_key("frost_thick_hide"), "", "Thick Hide is gone")
	assert_false(Abilities.COOLDOWN_TALENTS.has("winterhide"))
	var res := Abilities.get_resource("winterhide")
	assert_eq(float(res.cooldown), 40.0)
	assert_eq(Abilities.cooldown_of(res), 40.0)
