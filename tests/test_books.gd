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
	var menu := MenuSource.text()
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

# Specs: each book's abilities split by playstyle under named dividers, in the
# main-menu book and the in-game spellbook alike.
const Abilities = preload("res://scripts/abilities.gd")

func test_every_ability_sits_in_exactly_one_spec_of_its_book() -> void:
	for cat in Categories.ORDER:
		assert_true(Abilities.SPECS.has(cat), "%s has specs" % cat)
		var seen := {}
		var names := {}
		for spec in Abilities.SPECS[cat]:
			assert_false(str(spec[0]).is_empty(), "every spec has a name")
			assert_false(names.has(spec[0]), "%s: no two specs share a name" % cat)
			names[spec[0]] = true
			for id in spec[1]:
				assert_eq(Abilities.category_of(id), cat, "%s is a %s ability" % [id, cat])
				assert_false(seen.has(id), "%s is in only one spec" % id)
				seen[id] = true
		for id in Abilities.in_category(cat):
			assert_true(seen.has(id), "%s has a spec in %s" % [id, cat])
		# Nothing falls through to the unnamed section.
		for spec in Abilities.specs_in(cat):
			assert_ne(spec[0], "", "%s: every ability is under a named spec" % cat)

func test_specs_in_keeps_only_what_is_asked_and_drops_empty_specs() -> void:
	var only_bolt := func(id: String) -> bool: return id == "frostbolt"
	var frost := Abilities.specs_in("frost", only_bolt)
	assert_eq(frost.size(), 1)
	assert_eq(frost[0][0], "Hard Winter")
	assert_eq(Array(frost[0][1]), ["frostbolt"])
	assert_true(Abilities.specs_in("frost", func(_id): return false).is_empty())
	# A book without specs (Rune Spells) is one unnamed section.
	var runes := Abilities.specs_in(Categories.RUNE)
	assert_eq(runes.size(), 1)
	assert_eq(runes[0][0], "")

func test_both_spellbooks_draw_the_specs() -> void:
	var menu := MenuSource.text()
	assert_contains(menu, "var specs := Abilities.specs_in(_book_cat)")
	assert_contains(menu, "UI.spec_divider(spec[0]")
	var game := FileAccess.get_file_as_string("res://scripts/game_ui.gd")
	assert_contains(game, "Abilities.specs_in(cat, learned)")
	assert_contains(game, "UI.spec_divider(spec[0]")

# --- Utility rules (CLAUDE.md) -----------------------------------------------------------

func _spec_of(id: String) -> String:
	for spec in Abilities.SPECS.get(Abilities.category_of(id), []):
		if (spec[1] as Array).has(id):
			return str(spec[0])
	return ""

func test_every_healer_spec_has_an_out_of_combat_rez() -> void:
	var roles: Dictionary = preload("res://tools/balance_sim_specs.gd").ROLES
	for spec_name in roles:
		assert_eq(Abilities.HEALER_SPECS.has(spec_name), str(roles[spec_name]) == "healer",
			"%s: HEALER_SPECS and the balance sim agree on who heals" % spec_name)
	for spec_name in Abilities.HEALER_SPECS:
		var found := false
		for cat in Abilities.SPECS:
			for spec in Abilities.SPECS[cat]:
				if spec[0] == spec_name:
					for id in spec[1]:
						if Abilities.get_resource(id).tags.has("Resurrect"):
							found = true
		assert_true(found, "%s has an out-of-combat rez" % spec_name)

func test_only_healers_revive() -> void:
	for id in Abilities.ALL:
		var r := Abilities.get_resource(id)
		if r and (r.tags.has("Revive") or r.tags.has("Resurrect")):
			assert_true(Abilities.HEALER_SPECS.has(_spec_of(id)), "%s revives but is not in a healer spec" % id)

func test_every_book_has_a_root() -> void:
	for cat in Categories.ORDER:
		var ids := Abilities.in_category(cat)
		if ids.is_empty():
			continue
		var found := false
		for id in ids:
			if Abilities.get_resource(id).tags.has("Root"):
				found = true
		assert_true(found, "%s has a root" % cat)
