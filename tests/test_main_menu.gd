@tool
extends McpTestSuite

# The main menu: it builds without script errors (backdrop, lobby, Play screen,
# ready check, loadouts, What's new, last run), plus the rules behind its parts.

const Net = preload("res://scripts/net/net.gd")
const Abilities = preload("res://scripts/abilities.gd")

func suite_name() -> String:
	return "main_menu"

func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree

## The real menu scene in the tree (freed after the test). Under the last root
## child (the test runner, or the edited scene): the root itself is busy while the
## headless runner's _ready runs the suites.
func _menu() -> Node:
	var m: Node = load("res://scenes/main_menu.tscn").instantiate()
	var root := _tree().root
	root.get_child(root.get_child_count() - 1).add_child(m)
	track(m)
	assert_true(m.is_inside_tree(), "the menu is in the tree")
	return m

func test_menu_builds_and_switches_pages() -> void:
	var m := _menu()
	assert_true(m.has_node("Backdrop"), "the lobby backdrop is in the scene")
	for page in m.pages:
		m._show_page(page)
		m._process(0.1)
	m._show_page("Lobby")
	assert_true(m.get_node("Backdrop").visible, "backdrop shows in the Lobby")
	m._show_page("Bank")
	assert_false(m.get_node("Backdrop").visible, "and hides behind full pages")

func test_party_cards_have_role_strip_and_badge() -> void:
	var m := _menu()
	for slot in m.lobby_page._party_slots:
		assert_true(slot.has_node("Role") and slot.has_node("Strip") and slot.has_node("Ready"))

func test_play_screen_cards_and_summary() -> void:
	var m := _menu()
	var q = m.queue_page
	assert_true(q._queue_cards.size() == q._instances.size(), "one card per dungeon")
	q._queue_selected = 0
	q._refresh_queue()
	assert_true(m.queue_page.play_summary().begins_with(q._instances[0]["name"]), "PLAY names where it goes")
	assert_true(m._play_where.text != "", "PLAY shows its second line")

func test_ready_check_outcome() -> void:
	var ids := [1, 2, 3]
	assert_eq(Net.ready_outcome(ids, {1: true, 2: true, 3: true}, false), 1, "everyone ready")
	assert_eq(Net.ready_outcome(ids, {1: true, 2: true}, false), -1, "still waiting")
	assert_eq(Net.ready_outcome(ids, {1: true, 2: true}, true), 0, "a timeout fails it")
	assert_eq(Net.ready_outcome(ids, {1: true, 2: false}, false), 0, "one Not ready fails it at once")

func test_ready_check_alone_runs_at_once() -> void:
	var net: Node = _tree().root.get_node("Net")
	var ran := [false]
	net.start_ready_check(func(): ran[0] = true)
	assert_true(ran[0], "solo: no check, it just starts")

func test_main_spec_of_bar() -> void:
	assert_eq(Abilities.main_spec_of_bar([]), ["", ""])
	var spec := Abilities.spec_of("frostbolt")
	var main: Array = Abilities.main_spec_of_bar(["frostbolt", "", "frostbolt"])
	assert_eq(main[0], spec)
	assert_eq(main[1], Abilities.category_of("frostbolt"))

func test_best_clear_keeps_the_lowest_time() -> void:
	var pd: Node = _tree().root.get_node("PlayerData")
	var saved: Dictionary = pd.best_clears.duplicate(true)
	pd.best_clears = {}
	assert_true(pd.record_clear("crypt", "solo", 300.0), "first clear is a best")
	assert_false(pd.record_clear("crypt", "solo", 320.0), "slower is not")
	assert_true(pd.record_clear("crypt", "solo", 250.0), "faster is")
	assert_true(pd.record_clear("crypt", "party", 400.0), "each difficulty has its own")
	assert_eq(pd.best_clear("crypt", "solo"), 250.0)
	assert_eq(pd.best_clear("pit", "solo"), 0.0, "never cleared = 0")
	pd.best_clears = saved

func test_loadouts_save_and_apply() -> void:
	var pd: Node = _tree().root.get_node("PlayerData")
	var saved := {"loadouts": pd.loadouts.duplicate(true), "talents": pd.talents.duplicate(), "bar": pd.action_bar.duplicate(),
		"attrs": pd.attribute_points.duplicate()}
	pd.loadouts = []
	assert_eq(pd.save_loadout("Frost"), "")
	assert_eq(pd.loadouts.size(), 1)
	assert_eq(pd.loadouts[0]["name"], "Frost")
	pd.action_bar[0] = ""
	var res: Dictionary = pd.apply_loadout(0)
	assert_false(res.has("error"))
	assert_eq(pd.action_bar[0], saved["bar"][0], "the bar comes back")
	# A loadout from an older talent tree: its talents are dropped, the rest applies.
	pd.loadouts[0]["tree_version"] = -1
	pd.loadouts[0]["talents"] = {"x": 1}
	res = pd.apply_loadout(0)
	assert_true(pd.talents.is_empty(), "old-tree talents are dropped")
	assert_eq(res["notes"].size(), 1)
	for i in pd.MAX_LOADOUTS - 1:
		pd.save_loadout("")
	assert_true(pd.save_loadout("") != "", "no more than MAX_LOADOUTS")
	pd.loadouts = saved["loadouts"]
	pd.talents = saved["talents"]
	pd.action_bar = saved["bar"]
	pd.attribute_points = saved["attrs"]

func test_loadouts_panel_builds() -> void:
	var m := _menu()
	m.loadouts.toggle()
	assert_true(m.loadouts._panel.visible)
	m.loadouts.toggle()

func test_whats_new_markdown() -> void:
	var W = load("res://scripts/menu/whats_new.gd")
	var bb: String = W.to_bbcode("# Title\n## Items\n- New item: **Worn Tome** [Off Hand]")
	assert_true(bb.contains("[font_size=21]") and bb.contains("Title"), "a title")
	assert_true(bb.contains("[font_size=18]") and bb.contains("Items"), "a section")
	assert_true(bb.contains("  •  New item: [b]Worn Tome[/b]"), "bullets and bold")
	assert_true(bb.contains("[lb]Off Hand]"), "brackets are escaped")
	assert_true(W.load_notes() != "", "the newest patch notes are found")

func test_release_bundles_the_patch_notes() -> void:
	var wf := FileAccess.get_file_as_string("res://.github/workflows/release.yml")
	var bundle := wf.find("data/whats_new.md")
	assert_true(bundle != -1 and bundle < wf.find("--export-release"), "copied before the export")
	assert_true(FileAccess.get_file_as_string("res://export_presets.cfg").contains('include_filter="data/whats_new.md"'), "and exported")

func test_last_run_is_recorded_and_shown_once() -> void:
	var gm: Node = _tree().root.get_node("GameManager")
	var details: Node = _tree().root.get_node("Details")
	var saved_last: Dictionary = gm.last_run
	gm._begin_run_record()
	details.run_totals = {1: {"name": "Ana", "damage": 5000, "healing": 0}, 2: {"name": "Bo", "damage": 900, "healing": 7000}}
	gm._on_run_xp(120)
	gm._on_run_cleared({"dungeon": "The Pit", "time": 312.0, "kills": 40, "bosses": 2, "best": true})
	gm._finish_run_record(["worn_tome"])
	var run: Dictionary = gm.last_run
	assert_true(run["cleared"])
	assert_eq(run["xp"], 120)
	assert_eq(run["party"][0]["name"], "Ana", "sorted by damage")
	assert_eq(run["loot"], ["worn_tome"])
	gm._finish_run_record([])
	assert_eq(gm.last_run, run, "nothing recorded: the last run stays")
	var m := _menu()
	assert_true(m.last_run._card != null, "the card shows in the lobby")
	m.last_run.dismiss()
	assert_true(gm.last_run.is_empty(), "dismissed: shown once")
	gm.last_run = saved_last
