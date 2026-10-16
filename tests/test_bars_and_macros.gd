@tool
extends McpTestSuite

# Extra action bars, macros, /give, and unbinding keys.

const PlayerDataScript = preload("res://scripts/player_data.gd")
const Macros = preload("res://scripts/core/macros.gd")
const SettingsScript = preload("res://scripts/settings.gd")
const DebugCommands = preload("res://scripts/core/debug_commands.gd")
const Items = preload("res://scripts/items.gd")

func suite_name() -> String:
	return "bars_and_macros"

func _pd() -> Node:
	return track(PlayerDataScript.new())

## Four bars of eight slots; slots 9-32 belong to the extra bars.
func test_action_bar_has_four_bars() -> void:
	var pd := _pd()
	assert_eq(pd.ACTION_SLOTS_TOTAL, 32)
	assert_eq(pd.action_bar.size(), 32)
	assert_eq(pd.action_bar[0], "frostbolt", "the main bar keeps its starting abilities")
	pd.set_action_slot(20, "slam", -1)
	assert_eq(pd.action_bar[20], "slam", "an ability can go on an extra bar")
	assert_eq(pd.action_bar[4], "", "... and leaves the slot it was in")
	pd.set_action_slot(31, "slam", 20)
	assert_eq(pd.action_bar[31], "slam", "moved between extra-bar slots")
	pd.clear_action_slot(31)
	assert_eq(pd.action_bar[31], "")
	pd.set_action_slot(32, "slam", -1)   # out of range: ignored
	assert_false(pd.action_bar.has("slam"))

## Every slot has an Input Map action; the extra ones start without a key.
func test_every_slot_has_a_keybind_action() -> void:
	assert_eq(SettingsScript.slot_action(1), "ability_1")
	assert_eq(SettingsScript.slot_action(8), "ability_8")
	assert_eq(SettingsScript.slot_action(9), "bar2_1")
	assert_eq(SettingsScript.slot_action(17), "bar3_1")
	assert_eq(SettingsScript.slot_action(32), "bar4_8")
	var names := {}
	for a in SettingsScript.actions():
		assert_false(names.has(a[0]), "action %s is listed once" % a[0])
		names[a[0]] = a
	for slot in range(1, 33):
		assert_true(names.has(SettingsScript.slot_action(slot)), "slot %d can be bound" % slot)
	assert_true((names["bar2_1"][2] as Array).is_empty(), "extra slots have no default key")
	assert_eq(str(names["bar3_4"][1]), "Left bar 4")

func test_macro_text_is_understood() -> void:
	var p := Macros.parse("# opener\n/cast Trinket 1\n/use Vent Flames\nFrost Bolt\n\n/castsequence reset=6 Frost Bolt, Firebolt, slam")
	assert_true((p["problems"] as Array).is_empty(), str(p["problems"]))
	var steps: Array = p["steps"]
	assert_eq(steps.size(), 4)
	assert_eq(str(steps[0]["ability"]), "trinket_1")
	assert_eq(str(steps[1]["ability"]), "ventflames", "by its name")
	assert_eq(str(steps[2]["ability"]), "frostbolt", "a bare name works too")
	assert_eq(str(steps[3]["kind"]), "sequence")
	assert_eq(steps[3]["abilities"], ["frostbolt", "fireball", "slam"])
	assert_eq(float(steps[3]["reset"]), 6.0)
	# Mistakes are reported with their line, and the rest still works.
	var bad := Macros.parse("/cast Frost Bolt\n/cast Frots Bolt\n/dance")
	assert_eq((bad["steps"] as Array).size(), 1)
	assert_eq((bad["problems"] as Array).size(), 2)
	assert_contains(str(bad["problems"][0]), "Line 2")
	assert_contains(str(bad["problems"][1]), "/dance")
	assert_eq(Macros.abilities_in("/cast Heavy Blow\n/castsequence Heavy Blow, Headsman's Cut"), ["slam", "execute"])

func test_macros_are_kept_on_the_bar() -> void:
	var pd := _pd()
	var uid: int = pd.add_macro()
	assert_true(uid > 0)
	pd.update_macro(uid, {"name": "  Burst  ", "link": "ventflames", "text": "/cast Vent Flames"})
	assert_eq(str(pd.macro_by_uid(uid)["name"]), "Burst")
	var id := Macros.bar_id(uid)
	assert_true(Macros.is_macro(id))
	assert_eq(Macros.uid_of(id), uid)
	pd.set_action_slot(9, id, -1)
	# Losing your abilities (death / prestige) leaves macros and the base kit on the bar.
	pd.action_bar[10] = "frostnova"
	assert_true(PlayerDataScript.keeps_bar_slot(id))
	assert_true(PlayerDataScript.keeps_bar_slot("frostbolt"))
	assert_false(PlayerDataScript.keeps_bar_slot("frostnova"))
	pd.prestige()
	assert_eq(pd.action_bar[9], id)
	assert_eq(pd.action_bar[10], "")
	# Deleting a macro takes it off the bar.
	pd.delete_macro(uid)
	assert_eq(pd.action_bar[9], "")
	assert_true(pd.macro_by_uid(uid).is_empty())
	# A second macro never reuses a live uid.
	var a: int = pd.add_macro()
	var b: int = pd.add_macro()
	assert_ne(a, b)

func test_give_understands_names_rarities_and_levels() -> void:
	assert_eq(DebugCommands.parse_give(["storm", "idol", "epic", "30"]), {"item": "storm idol", "rarity": 3, "level": 30})
	assert_eq(DebugCommands.parse_give(["sword"]), {"item": "sword", "rarity": 0, "level": 0})
	assert_eq(DebugCommands.parse_give(["sword", "3"]), {"item": "sword", "rarity": 3, "level": 0}, "one small number is a rarity (the old form)")
	assert_eq(DebugCommands.parse_give(["sword", "3", "30"]), {"item": "sword", "rarity": 3, "level": 30}, "the old form")
	assert_eq(DebugCommands.parse_give(["helmet", "25"]), {"item": "helmet", "rarity": 0, "level": 25}, "a bigger number is the item level")
	assert_eq(DebugCommands.parse_give(["helmet", "Rare"]), {"item": "helmet", "rarity": 2, "level": 0})
	assert_eq(DebugCommands.find_items("sword"), ["sword"])
	assert_eq(DebugCommands.find_items(Items.item_name("storm_idol")), ["storm_idol"], "by its shown name")
	assert_eq(DebugCommands.find_items("storm_idol"), ["storm_idol"])
	assert_true(DebugCommands.find_items("zzz").is_empty())
	assert_true(DebugCommands.give_help().size() >= 4, "the item list, by kind")
