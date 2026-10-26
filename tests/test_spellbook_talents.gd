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
