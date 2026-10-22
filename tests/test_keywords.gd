@tool
extends McpTestSuite

# Keywords, search and "what mentions what" (scripts/core/keywords.gd), and the
# tooltips that use them.

const Keywords = preload("res://scripts/core/keywords.gd")
const Abilities = preload("res://scripts/abilities.gd")
const Talents = preload("res://scripts/talents.gd")
const Runes = preload("res://scripts/runes.gd")
const ItemTooltip = preload("res://scripts/ui/item_tooltip.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")

func suite_name() -> String:
	return "keywords"

func _names(keys: Array) -> Array:
	var out: Array = []
	for k in keys:
		out.append(Keywords.title(str(k)))
	return out

## Keywords and names are wrapped in orange; tags already there are left alone.
func test_paint_colours_keywords_and_names() -> void:
	var orange := "[color=#%s]" % Keywords.COLOR.to_html(false)
	var out := Keywords.paint("Deals [color=#ffffff]5[/color] damage and Chills it. See Vent Flames.")
	assert_contains(out, orange + "Chills[/color]")
	assert_contains(out, orange + "Vent Flames[/color]")
	assert_contains(out, "[color=#ffffff]5[/color]", "existing tags stay as they are")
	# A longer name wins over a keyword inside it, and a word is never cut.
	assert_contains(Keywords.paint("Frozen Focus"), orange + "Frozen Focus[/color]")
	assert_eq(Keywords.paint("preventing"), "preventing")
	assert_eq(Keywords.paint("Branded"), orange + "Branded[/color]", "Branded is the effect, not Brand + ed")

## Every form of a keyword is the same keyword.
func test_mentions_know_keyword_forms() -> void:
	assert_true(Keywords.mentions("Chilling it").has("k:chilled"))
	assert_true(Keywords.mentions("you Freeze an enemy").has("k:frozen"))
	assert_true(Keywords.mentions("uses Frost Bolt").has("a:frostbolt"))
	assert_false(Keywords.mentions("Frozen Focus").has("k:frozen"), "a name that holds a keyword is not the keyword")

## Shift: Frost Bolt's tooltip explains Chilled at the bottom.
func test_ability_tooltip_explains_keywords_on_shift() -> void:
	var plain := Abilities.tooltip_bbcode("frostbolt", false)
	var detailed := Abilities.tooltip_bbcode("frostbolt", true)
	assert_false(plain.contains("Keywords"), "only with Shift")
	assert_contains(detailed, "Keywords")
	var chilled := "[color=#%s]Chilled[/color]: " % Keywords.COLOR.to_html(false)
	assert_contains(detailed, chilled)
	assert_true(detailed.find(chilled) > detailed.find("Scaling"), "under the scaling details")
	assert_contains(plain, "[color=#%s]Chilling[/color]" % Keywords.COLOR.to_html(false), "keyword in orange")

## Talent and rune tooltips (plain text): orange keywords, Shift explains them,
## and the thing the tooltip is about is not explained to itself.
func test_plain_tooltips_paint_and_explain() -> void:
	var tip := Talents.tooltip(Talents.id_for_key("frost_chilled_dmg"), 0)
	var lines := ItemTooltip.keyword_lines(tip)
	assert_eq(lines.size(), 1, "Bitter Cold explains Chilled")
	assert_contains(lines[0], "Chilled")
	var shown := ItemTooltip.text_bbcode(tip, false, lines)
	assert_contains(shown, "Hold Shift to explain keywords")
	assert_true(shown.begins_with("Bitter Cold"), "the title line keeps its colour")
	assert_contains(ItemTooltip.text_bbcode(tip, true, lines), "Movement speed reduced")
	# A rune.
	var rune := Runes.tooltip("frozen_aegis")
	assert_false(ItemTooltip.keyword_lines(rune).is_empty(), "Frozen Aegis explains Frozen")
	# Nothing to explain: no hint.
	assert_eq(ItemTooltip.text_bbcode("Reset all talents", false, ItemTooltip.keyword_lines("Reset all talents")), "Reset all talents")
	# Square brackets in a plain tooltip are text, not tags.
	assert_contains(ItemTooltip.text_bbcode("a [b] c", false, []), "[lb]b]")

## "chill" and "chilled" both find everything that works with Chilled.
func test_search_finds_keyword_users() -> void:
	for q in ["chill", "chilled", "Chilling"]:
		var found := _names(Keywords.search(q, "at"))
		for name in ["Frost Bolt", "Whiteout", "Frost Arrow", "Bitter Cold", "Winter's Bite", "Rime Edge"]:
			assert_true(found.has(name), "'%s' finds %s" % [q, name])
		assert_false(found.has("Firebolt"), "'%s' does not find Firebolt" % q)
	# A name that only contains the word is found by that word, not by the keyword.
	assert_true(_names(Keywords.search("chill", "at")).has("Chilling Presence"))
	assert_false(_names(Keywords.search("frozen", "at")).has("Firebolt"))
	assert_true(_names(Keywords.search("freeze", "at")).has("Frostburst"), "an ability that Freezes")
	assert_false(_names(Keywords.search("freeze", "at")).has("Frozen Focus"), "Frozen Focus has nothing to do with Frozen")
	# Words match from their start: "vent" is not "preventing".
	var vent := _names(Keywords.search("vent", "at"))
	assert_true(vent.has("Vent Flames") and vent.has("Pressure Valve"))
	assert_false(vent.has("Kick"))
	# Names first.
	assert_eq(_names(Keywords.search("vent flames", "at"))[0], "Vent Flames")
	# Runes have their own search.
	assert_true(_names(Keywords.search("freeze", "r")).has("Rune of the Frozen Aegis"))
	assert_true(Keywords.search("", "atr").is_empty())

## Hover: a talent and the ability it changes point at each other.
func test_related_goes_both_ways() -> void:
	var valve := "t:" + Talents.id_for_key("fire_pressure_valve")
	assert_true(Keywords.related(valve).has("a:ventflames"))
	assert_true(Keywords.related("a:ventflames").has(valve))
	# Through "requires", even when the text does not name the ability.
	var brand := "t:" + Talents.id_for_key("fire_deep_brand")
	assert_true(Keywords.related("a:brand").has(brand))
	# A choice talent (one of the two in a slot), through "requires" too.
	var damped := "t:" + Talents.id_for_key("fire_damped_embers")
	assert_true(Keywords.related("a:embervolley").has(damped))
	assert_false(Keywords.related("a:ventflames").has("a:ventflames"), "never itself")

## A talent that only works with one ability says so, and takes no points
## until that ability is learned.
func test_single_ability_talents_need_the_ability() -> void:
	var id := Talents.id_for_key("fire_pressure_valve")
	assert_contains(Talents.tooltip(id, 0), "Requires Vent Flames to be learned")
	var pd = PlayerDataScript.new()
	pd.level = 50
	pd.learned_abilities.clear()
	# Open its row first (row 2 needs 3 points in row 1).
	var first := Talents.id_for_key("fire_stoked_breath")
	pd.talents = {first: 2, Talents.id_for_key("frost_absorb"): 1}
	assert_eq(pd.can_invest(id), "Requires Vent Flames to be learned")
	pd.learned_abilities.append("ventflames")
	assert_eq(pd.can_invest(id), "")
	# A talent of a starting ability is never blocked.
	assert_eq(pd.can_invest(Talents.id_for_key("fire_tempered_flame")), "")
	pd.free()
