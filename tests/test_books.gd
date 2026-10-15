@tool
extends McpTestSuite

# The books keep their places: one fixed order (Categories.ORDER) that every
# screen draws from as it is - the main menu's shelf and its row of book icons,
# the in-game talent view - and nothing sorts or filters it by what you know.

const Categories = preload("res://scripts/categories.gd")

func suite_name() -> String:
	return "books"

func test_the_order_is_fixed() -> void:
	assert_eq(Categories.ORDER, ["fire", "frost", "lightning", "arcane", "shadow", "nature", "holy", "martial"],
		"a new book goes at the end: no book ever changes its place")
	assert_eq(Categories.shelf_columns(Categories.ORDER.size()), 4, "two even rows of four")
	assert_false(Categories.ORDER.has(Categories.RUNE), "Rune Spells is its own tab above the books")

func test_every_screen_uses_that_order_as_it_is() -> void:
	var menu := FileAccess.get_file_as_string("res://scripts/main_menu.gd")
	# The shelf: one card for each book, in order, whatever you have learned.
	assert_contains(menu, "\tfor cat in Categories.ORDER:\n\t\tgrid.add_child(_shelf_book(cat))")
	assert_contains(menu, "grid.columns = Categories.shelf_columns(Categories.ORDER.size())")
	# The row of book icons over an open book.
	assert_contains(menu, "for cat in [Categories.RUNE] + Categories.ORDER:")
	# A card's size never follows its text, and the points label beside the icons has a fixed width.
	assert_contains(menu, "b.custom_minimum_size = Vector2(0, 130)")
	assert_contains(menu, "_talent_points_label.clip_text = true")
	# The in-game talent view.
	var view := FileAccess.get_file_as_string("res://scripts/ui/talent_tree_view.gd")
	assert_contains(view, "\tfor cat in Categories.ORDER:\n\t\tvar c: String = cat")
	for src in [menu, view]:
		assert_false(src.contains("ORDER.sort") or src.contains("ORDER.shuffle"), "nothing reorders the books")
