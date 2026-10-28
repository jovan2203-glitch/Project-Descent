@tool
extends McpTestSuite

# Move UI (scripts/ui/ui_layout.gd): a moved element is saved as its nearest of
# 9 screen anchors plus an offset, so it keeps its place on other screen sizes;
# movers snap to the grid, to other movers' edges and to the screen centre.

const Layout = preload("res://scripts/ui/ui_layout.gd")

func suite_name() -> String:
	return "ui_layout"

func test_saving_and_placing_round_trip() -> void:
	var screen := Vector2(1280, 720)
	var size := Vector2(200, 40)
	for pos in [Vector2(20, 20), Vector2(1060, 330), Vector2(540, 650), Vector2(600, 340)]:
		var d := Layout.save_for(pos, size, screen)
		assert_eq(Layout.position_for(d, size, screen), pos, "an element put at %s comes back there" % pos)

func test_nearest_anchor_keeps_corners_in_corners() -> void:
	var size := Vector2(200, 40)
	var d := Layout.save_for(Vector2(1064, 16), size, Vector2(1280, 720))
	assert_eq(Vector2(d["ax"], d["ay"]), Vector2(1, 0), "top right")
	# On a bigger screen it keeps the same gap to the top-right corner.
	assert_eq(Layout.position_for(d, size, Vector2(1920, 1080)), Vector2(1704, 16))
	var c := Layout.save_for(Vector2(540, 340), size, Vector2(1280, 720))
	assert_eq(Vector2(c["ax"], c["ay"]), Vector2(0.5, 0.5), "the middle stays centred")
	assert_eq(Layout.position_for(c, size, Vector2(1920, 1080)), Vector2(860, 520))

func test_never_placed_off_screen() -> void:
	var d := {"ax": 1.0, "ay": 1.0, "x": 500.0, "y": 500.0}
	assert_eq(Layout.position_for(d, Vector2(100, 50), Vector2(800, 600)), Vector2(700, 550))

func test_snapping() -> void:
	# To the grid.
	assert_eq(Layout.snapped_pos(Vector2(37, 70), Vector2(50, 20), 32, [], []), Vector2(32, 64))
	# To another mover's edge within reach (beats the grid): left edge onto x = 105.
	assert_eq(Layout.snapped_pos(Vector2(101, 70), Vector2(50, 20), 32, [105.0], []).x, 105.0)
	# Its centre onto the screen centre.
	assert_eq(Layout.snapped_pos(Vector2(613, 0), Vector2(50, 20), 0, [640.0], []).x, 615.0)

func test_the_hud_registers_its_pieces() -> void:
	var hud := HudSource.text()
	for key in ["player_frame", "cast_bar", "target_frame", "target_cast", "party_frames", "buffs", "debuffs",
			"action_bar", "extra_bar_%d", "xp_bar", "messages", "chat", "meter", "venom", "wheel", "chain", "sharpshooter"]:
		assert_true(hud.contains("\"%s\"" % key), "%s can be moved" % key)
	var ui := FileAccess.get_file_as_string("res://scripts/game_ui.gd")
	assert_true(ui.contains("\"minimap\""), "the minimap can be moved")
	assert_true(ui.contains("Can't move the interface in combat"), "only out of combat")

func test_edit_mode_opens_moves_and_locks() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var settings := tree.root.get_node_or_null("Settings")
	if settings == null:
		return   # (no autoloads in this run)
	var before: Dictionary = settings.ui_layout.duplicate(true)
	var host: Node = tree.current_scene   # (the test runner: the root is busy setting it up)
	var c := Control.new()
	c.size = Vector2(120, 30)
	host.add_child(c)
	var layout := Layout.new()
	host.add_child(layout)
	layout.add(c, "test_piece", "Test Piece")
	layout.start_edit()
	assert_true(layout.editing and layout._movers.has("test_piece"), "a mover per element")
	layout._place("test_piece", Vector2(300, 200))
	assert_true(settings.ui_layout.has("test_piece"), "a move is saved")
	assert_eq(c.global_position, Vector2(300, 200))
	layout.stop_edit()
	assert_false(layout.editing)
	settings.ui_layout = before
	settings.save()
	layout.free()
	c.free()
