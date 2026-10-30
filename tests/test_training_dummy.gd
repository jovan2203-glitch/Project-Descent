@tool
extends McpTestSuite

# Training dummies never move on their own: nobody can push them, not even while
# an Incense aura keeps them fighting. A pull or drag still moves them.

func suite_name() -> String:
	return "training_dummy"

func test_dummies_are_pinned() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/training/dummy.gd")
	assert_contains(src, "global_position = Vector3(_spot.x, global_position.y, _spot.z)", "snapped back to its spot")
	assert_contains(src, "if _now_s() < busy_until:\n\t\t_spot = global_position", "a pull or drag moves it for good")
