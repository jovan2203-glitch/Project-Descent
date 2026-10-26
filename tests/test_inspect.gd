@tool
extends McpTestSuite

# Inspect: a party member's gear, stats, abilities and talents. Their game sends
# PlayerData.inspect_snapshot() (Net.request_inspect / _insp_ask / _insp_data,
# through the host's relay); ours loads it into a detached PlayerData and shows it
# in scripts/ui/inspect_window.gd. Opened from a lobby card or a party frame (right click).

const PlayerDataScript = preload("res://scripts/player_data.gd")
const InspectWindow = preload("res://scripts/ui/inspect_window.gd")
const TalentView = preload("res://scripts/ui/talent_tree_view.gd")
const Abilities = preload("res://scripts/abilities.gd")
const Talents = preload("res://scripts/talents.gd")

func suite_name() -> String:
	return "inspect"

func _src(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func _source_pd() -> Node:
	var pd: Node = track(PlayerDataScript.new())
	pd.level = 30
	pd.equipment["Main Hand"] = "sword"
	pd.attribute_points = {"intellect": 12}
	var tid := Talents.in_row("frost", 0)[0]
	pd.talents[tid] = 1
	pd.action_bar[0] = "frostbolt"
	return pd

func test_snapshot_round_trip() -> void:
	var a := _source_pd()
	var b: Node = track(PlayerDataScript.new())
	b.apply_snapshot(a.inspect_snapshot())
	assert_eq(b.level, 30)
	assert_eq(b.talents, a.talents)
	assert_eq(b.equipment, a.equipment)
	assert_eq(b.action_bar[0], "frostbolt")
	assert_eq(b.total_stats(), a.total_stats(), "their stats come out the same on our side")

func test_snapshot_ignores_junk() -> void:
	var b: Node = track(PlayerDataScript.new())
	b.apply_snapshot({"level": "x", "talents": {"no_such_talent": 5, "frost_r1c1": 99}, "equipment": {"Head": "no_such_item"},
		"attribute_points": {"intellect": "lots"}, "action_bar": "nope", "items": 7})
	assert_false(b.talents.has("no_such_talent"))
	for id in b.talents:
		assert_true(int(b.talents[id]) <= Talents.max_rank(str(id)), "ranks are capped")
	assert_true(b.equipment.is_empty(), "unknown items are dropped")
	assert_true(b.attribute_points.is_empty())

func test_request_goes_through_the_relay() -> void:
	var net := _src("res://scripts/net/net.gd")
	assert_contains(net, 'method.begins_with("_insp_")', "the host relays inspect messages")
	assert_contains(net, '_send_to_member(member, "_insp_ask", [my_id()])')
	assert_contains(net, '_send_to_member(asker, "_insp_data", [my_id(), _inspect_data()])')
	assert_contains(net, "if online and members.has(member):", "only party members' snapshots are shown")

func test_opened_from_lobby_cards_and_party_frames() -> void:
	assert_contains(_src("res://scripts/menu/lobby_page.gd"), 'request_inspect(int(slot.get_meta("member")))')
	var frames := _src("res://scripts/ui/party_frames.gd")
	assert_contains(frames, "e.button_index == MOUSE_BUTTON_RIGHT")
	assert_contains(frames, "net.request_inspect(net.member_of(body))")
	assert_contains(_src("res://scripts/main_menu.gd"), "net.inspect_received.connect(_on_inspect)")
	assert_contains(_src("res://scripts/game_ui.gd"), "inspect_received.connect(_on_inspect)")

func test_talent_view_reads_their_data() -> void:
	var pd := _source_pd()
	var v: Node = track(TalentView.new())
	v.data_source = pd
	assert_eq(v._pd(), pd)

func test_ability_tooltips_use_their_stats() -> void:
	Abilities.stat_override = {"intellect": 777.0}
	var s: float = Abilities.stat_source().call("intellect")
	Abilities.stat_override = {}
	assert_true(s >= 777.0, "while hovered, tooltips read the inspected player's stats")

func test_window_builds() -> void:
	var host := Control.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var win := InspectWindow.open(host, 1, _source_pd().inspect_snapshot().merged({"name": "Tester"}))
	assert_true(InspectWindow.is_open(host))
	assert_true(win.find_children("*", "Button", true, false).size() > 12, "gear slots and abilities are there")
	InspectWindow.close(host)
	host.queue_free()
