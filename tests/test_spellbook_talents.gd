@tool
extends McpTestSuite

# The in-game Spellbook's talent view: read only, except in the training area,
# where left click spends a point and right click takes one back.

const TalentView = preload("res://scripts/ui/talent_tree_view.gd")

func suite_name() -> String:
	return "spellbook_talents"

func test_read_only_unless_editable() -> void:
	var v: Node = track(TalentView.new())
	assert_false(v.editable, "starts read only")
	var src := FileAccess.get_file_as_string("res://scripts/ui/talent_tree_view.gd")
	assert_contains(src, "if not editable or not (ev is InputEventMouseButton)", "clicks do nothing unless editable")
	assert_contains(src, "_pd().invest_talent(id)")
	assert_contains(src, "_pd().refund_talent(which)")

func test_editable_only_in_the_training_area() -> void:
	var ui := FileAccess.get_file_as_string("res://scripts/game_ui.gd")
	assert_contains(ui, "var training: bool = gm != null and gm.in_training()")
	assert_contains(ui, "_talent_view.set_editable(training)")
	assert_contains(ui, "_talent_view.message.connect(_report)", "refused clicks are shown as errors")

func test_readable_size() -> void:
	assert_true(TalentView.MIN_RIBBON_CELL >= 34.0, "ribbon columns wide enough to read")

## Reset works only where talents can be changed; the Inspect window (someone else's) has none.
func test_reset_only_where_talents_change() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ui/talent_tree_view.gd")
	assert_contains(src, "if data_source == null:", "only on your own talents")
	assert_contains(src, "if editable and _pd():\n\t\t\t\t_pd().reset_talents()")
	assert_contains(src, "_reset.disabled = not editable")

## The search bar frames matches on both sides, with the main menu's matching.
func test_spellbook_search() -> void:
	var ui := FileAccess.get_file_as_string("res://scripts/game_ui.gd")
	assert_contains(ui, "_talent_view.set_search(_book_query)")
	assert_contains(ui, "Keywords.matches(\"a:\" + id, _book_query)")
	var src := FileAccess.get_file_as_string("res://scripts/ui/talent_tree_view.gd")
	assert_contains(src, "Keywords.matches(\"t:\" + str(id), _query)")

## Runes tab at the bottom: Rune Management inside the window, locked in combat.
func test_runes_tab() -> void:
	var ui := FileAccess.get_file_as_string("res://scripts/game_ui.gd")
	assert_contains(ui, "RuneManager.embed(runes,")
	assert_contains(ui, "_rune_lock.visible = _in_combat()")
	var rm: Control = track(load("res://scripts/ui/rune_manager.gd").new())
	assert_false(rm.embedded, "the main menu's stays a full window")
