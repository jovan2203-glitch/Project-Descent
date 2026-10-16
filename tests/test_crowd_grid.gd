@tool
extends McpTestSuite

# scripts/core/crowd_grid.gd: crowd separation finds every body close enough to
# overlap, through cell borders and for big bodies, without scanning the whole group.

const CrowdGrid = preload("res://scripts/core/crowd_grid.gd")

func suite_name() -> String:
	return "crowd_grid"

## Which of `bodies` ([[name, position, radius], ...]) a lookup at `at` returns.
func _found(bodies: Array, at: Vector3, radius := 0.4) -> Array:
	var out := []
	for e in CrowdGrid.query(CrowdGrid.build(bodies), at, radius):
		out.append(e[0])
	return out

func test_neighbours_across_a_cell_border_are_found() -> void:
	var c := CrowdGrid.CELL
	var found := _found([["a", Vector3(c - 0.1, 0, 0), 0.4], ["b", Vector3(c + 0.1, 0, 0), 0.4]], Vector3(c - 0.1, 0, 0))
	assert_true(found.has("a") and found.has("b"), "both sides of the border: %s" % str(found))

func test_far_bodies_are_skipped() -> void:
	var found := _found([["a", Vector3.ZERO, 0.4], ["far", Vector3(CrowdGrid.CELL * 10.0, 0, 0), 0.4]], Vector3.ZERO)
	assert_false(found.has("far"), "a body ten cells away isn't looked at: %s" % str(found))

func test_a_big_body_reaches_past_its_cell() -> void:
	# A boss with a 5 m hitbox, centred two cells away, still overlaps a small enemy.
	var found := _found([["a", Vector3.ZERO, 0.4], ["boss", Vector3(CrowdGrid.CELL * 2.0 - 0.5, 0, 0), 5.0]], Vector3.ZERO)
	assert_true(found.has("boss"), "the big body is found: %s" % str(found))

func test_negative_coordinates() -> void:
	var found := _found([["a", Vector3(-0.1, 0, -0.1), 0.4], ["b", Vector3(0.1, 0, 0.1), 0.4]], Vector3(-0.1, 0, -0.1))
	assert_true(found.has("b"), "across the origin: %s" % str(found))

func test_height_is_ignored() -> void:
	var found := _found([["a", Vector3.ZERO, 0.4], ["above", Vector3(0.2, 3.0, 0), 0.4]], Vector3.ZERO)
	assert_true(found.has("above"), "flat (XZ) grid: %s" % str(found))

func test_enemies_use_it() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/enemy.gd")
	var body := src.substr(src.find("func _crowd_velocity"), 600)
	assert_true(body.contains("CrowdGrid.near"), "crowd separation reads the shared grid")
	assert_false(body.contains("get_nodes_in_group"), "and doesn't scan the whole group")
