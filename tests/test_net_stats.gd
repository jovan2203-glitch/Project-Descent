@tool
extends McpTestSuite

# Network stats for the F3 overlay and game.log: every message Net sends is
# counted (scripts/net/net.gd _out / _out_to), ping is a small echo, and GameLog
# writes a summary line every PERF_INTERVAL s.

const NET = preload("res://scripts/net/net.gd")
const GameLogScript = preload("res://scripts/core/game_log.gd")

func suite_name() -> String:
	return "net_stats"

func _net_src() -> String:
	return FileAccess.get_file_as_string("res://scripts/net/net.gd")

func test_every_send_is_counted() -> void:
	var re := RegEx.create_from_string("\\brpc(_id)?\\(")
	var raw := 0
	for line in _net_src().split("\n"):
		if re.search(line) != null and not line.begins_with("@rpc"):
			raw += 1
	assert_eq(raw, 0, "Net sends only through _out / _out_to (raw rpc() calls aren't counted)")

func test_traffic_rate() -> void:
	var n: Node = track(NET.new())
	n._count_sent([1, "abc", Vector3.ONE], 4)
	assert_eq(n._sent_msgs, 4, "a broadcast counts once per receiving peer")
	var bytes: int = n._sent_bytes
	assert_true(bytes > 0)
	n._rate_t = 0.5
	n._ping_t = 10.0   # (no ping: not in the tree)
	n._tick_stats(0.5)
	assert_true(absf(n.sent_kbps - bytes / 1024.0) < 0.001)
	assert_eq(roundi(n.sent_per_sec), 4)
	assert_eq(n._sent_msgs, 0, "counters restart every second")

func test_no_stats_outside_a_party() -> void:
	var n: Node = track(NET.new())
	assert_true(n.stats_lines().is_empty())

func test_log_has_a_perf_line() -> void:
	assert_eq(GameLogScript.PERF_INTERVAL, 30.0)
	assert_true(FileAccess.get_file_as_string("res://scripts/core/game_log.gd").contains('info("perf"'))
	assert_true(FileAccess.get_file_as_string("res://scripts/ui/debug_overlay.gd").contains("stats_lines()"), "the F3 overlay shows the network lines")
