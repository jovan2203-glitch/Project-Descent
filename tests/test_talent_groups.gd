@tool
extends McpTestSuite

# The column-group layout (Talents.GROUPS): a book's specs side by side as column
# groups, and each spec's capstone (its bottom-row talent) gated behind
# Balance.CAPSTONE_GATE points in that spec. Martial is the first book on it.

const Talents = preload("res://scripts/talents.gd")
const Balance = preload("res://scripts/balance.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")

func suite_name() -> String:
	return "talent_groups"

## `n` points in `group`'s rows 1-9 of the Martial book, rows filled top to bottom,
## plus 3 points in every row of the other groups' talents so each row opens.
func _ranks_with(group: String, n: int) -> Dictionary:
	var ranks := {}
	var left := n
	for row in Talents.ROWS - 1:
		for id in Talents.in_row("martial", row):
			if Talents.group_of(id) != group or left <= 0:
				continue
			var take := mini(Talents.max_rank(id), left)
			ranks[id] = take
			left -= take
	# Open every row with the Open column (no gate there), 3 points a row where it has one.
	for row in Talents.ROWS - 1:
		var have := 0
		for id in Talents.in_row("martial", row):
			have += int(ranks.get(id, 0))
		if have >= Talents.POINTS_TO_UNLOCK_NEXT:
			continue
		for id in Talents.in_row("martial", row):
			if Talents.group_of(id) == "Open" and Talents.required_ability(id) == "":
				ranks[id] = mini(Talents.max_rank(id), Talents.POINTS_TO_UNLOCK_NEXT - have)
				have += int(ranks[id])
		for cat in ["frost", "fire", "lightning", "arcane", "shadow", "nature", "holy"]:
			for id in Talents.in_row(cat, row):
				if have >= Talents.POINTS_TO_UNLOCK_NEXT:
					break
				if Talents.required_ability(id) == "" and not Talents.is_choice_slot(id) and Talents.sources_of(id).is_empty():
					var add := mini(Talents.max_rank(id), Talents.POINTS_TO_UNLOCK_NEXT - have)
					ranks[id] = add
					have += add
	return ranks

func test_grid_per_book() -> void:
	assert_eq(Talents.columns_of("martial"), 13)
	assert_eq(Talents.columns_of("fire"), 13, "Fire is on ribbons too")
	assert_eq(Talents.columns_of("lightning"), 13, "Lightning too")
	assert_eq(Talents.columns_of("arcane"), 13, "Arcane")
	assert_eq(Talents.columns_of("shadow"), 13, "Shadow")
	assert_eq(Talents.columns_of("nature"), 13, "Nature")
	assert_eq(Talents.columns_of("holy"), 13, "and Holy: every book is on ribbons")
	assert_eq(Talents.columns_of("no_such_book"), Talents.COLUMNS, "a book without groups would keep the old grid")
	assert_eq(Talents.rows_of("martial"), Talents.ROWS)
	assert_true(Talents.groups_of("no_such_book").is_empty(), "no groups (and no gate) without a book's own pass")

func test_group_of() -> void:
	assert_eq(Talents.group_of(Talents.id_for_key("martial_hard_break")), "The Wheel")
	assert_eq(Talents.group_of(Talents.id_for_key("martial_thrift")), "Rogue")
	assert_eq(Talents.group_of(Talents.id_for_key("martial_grit")), Talents.OPEN_GROUP)
	assert_eq(Talents.group_of(Talents.id_for_key("martial_scar_tissue")), "Brawler")
	assert_eq(Talents.group_of(Talents.id_for_key("martial_keen_eye")), "Sharpshooter")
	assert_eq(Talents.group_of(Talents.id_for_key("fire_tempered_flame")), "Steady Flame")
	assert_eq(Talents.group_of(Talents.id_for_key("lightning_long_reach")), "Lightning Rod")
	assert_eq(Talents.group_of(Talents.id_for_key("lightning_rod")), "Stormstring", "an unfinished spec's short ribbon")
	assert_eq(Talents.group_of(Talents.id_for_key("arcane_echo")), Talents.OPEN_GROUP)
	assert_eq(Talents.group_of(Talents.id_for_key("shadow_interest")), "The Breach")
	assert_eq(Talents.group_of(Talents.id_for_key("nature_compost")), "Thornweaver")
	assert_eq(Talents.group_of(Talents.id_for_key("holy_grace")), Talents.OPEN_GROUP)
	assert_eq(Talents.group_of(Talents.id_for_key("holy_radiance")), "Choir of One")
	assert_eq(Talents.in_group("martial", "Rogue").size(), 19)

func test_the_gate_opens_at_25_points() -> void:
	var cap := Talents.id_for_key("martial_in_the_zone")
	var short := _ranks_with("Rogue", Balance.CAPSTONE_GATE - 1)
	assert_eq(PlayerDataScript.gate_points(short, "martial", "Rogue"), Balance.CAPSTONE_GATE - 1)
	var pd = PlayerDataScript.new()
	pd.level = 50
	pd.talents = short
	assert_true(PlayerDataScript.talents_valid(short), "the setup itself is legal")
	assert_eq(pd.can_invest(cap), "Requires %d points in Rogue (%d / %d)" % [Balance.CAPSTONE_GATE, Balance.CAPSTONE_GATE - 1, Balance.CAPSTONE_GATE])
	var enough := _ranks_with("Rogue", Balance.CAPSTONE_GATE)
	pd.talents = enough
	assert_eq(pd.can_invest(cap), "", "25 points in the Rogue: the capstone opens")
	pd.free()

func test_refunds_keep_the_gate() -> void:
	var cap := Talents.id_for_key("martial_scar_tissue")
	var ranks := _ranks_with("Brawler", Balance.CAPSTONE_GATE)
	ranks[cap] = 1
	assert_true(PlayerDataScript.talents_valid(ranks))
	var pd = PlayerDataScript.new()
	pd.level = 50
	pd.talents = ranks
	# Any Brawler talent of rows 1-9 holding points: taking one back drops the group under 25.
	var some := ""
	for id in ranks:
		if Talents.group_of(str(id)) == "Brawler" and str(id) != cap:
			some = str(id)
	assert_eq(pd.can_refund(some), "Other talents depend on this one", "the capstone needs those points")
	assert_eq(pd.can_refund(cap), "", "the capstone itself can always go")
	pd.free()

func test_talents_valid_rejects_a_capstone_under_the_gate() -> void:
	var ranks := _ranks_with("Sharpshooter", 10)
	ranks[Talents.id_for_key("martial_keen_eye")] = 1
	assert_false(PlayerDataScript.talents_valid(ranks), "10 points: the capstone can't hold points")
	var pd = PlayerDataScript.new()
	pd.level = 50
	pd.talents = ranks.duplicate()
	assert_false(pd.validate_talents(), "a profile like that is refunded")
	pd.free()

func test_capstone_points_dont_count_for_its_own_gate() -> void:
	var cap := Talents.id_for_key("martial_turning_wheel")
	var ranks := {cap: 5}
	assert_eq(PlayerDataScript.gate_points(ranks, "martial", "The Wheel"), 0)
