extends Node

# Runs every test suite headless, the same way the godot-ai editor plugin does
# (its discovery and its McpTestRunner), without the editor: no cached preloads,
# no restarts. Not named test_*.gd, so discovery never picks it up itself.
#   godot --headless --path . --import            (once, or after new files)
#   godot --headless --path . res://tests/run_all.tscn -- [--suite=nature] [--test=venom]
# Exit code: 0 when everything passed and every suite loaded, 1 otherwise.
# tools/test.sh wraps both steps.

func _ready() -> void:
	var suite_filter := ""
	var test_filter := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--suite="):
			suite_filter = a.substr(8)
		elif a.begins_with("--test="):
			test_filter = a.substr(7)
	var found := _discover()
	var errors: Array = found["errors"]
	var results: Dictionary = McpTestRunner.new().run_suites(found["suites"], suite_filter, test_filter, {}, false, "")
	for f in results.get("failures", []):
		print("FAIL  %s > %s: %s" % [f.get("suite", "?"), f.get("test", "?"), str(f.get("message", "")).replace("\n", " | ")])
	for e in errors:
		print("LOAD ERROR  %s" % e)
	print("%d passed, %d failed, %d skipped, %d suites, %d ms" % [int(results.get("passed", 0)), int(results.get("failed", 0)),
		int(results.get("skipped", 0)), int(results.get("suite_count", 0)), int(results.get("duration_ms", 0))])
	var ok: bool = int(results.get("failed", 0)) == 0 and errors.is_empty() and int(results.get("total", 0)) > 0
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)

## Every tests/test_*.gd that is a McpTestSuite, sorted by suite name
## (as addons/godot_ai/handlers/test_handler.gd::_discover_suites does).
func _discover() -> Dictionary:
	var suites := []
	var errors := []
	var dir := DirAccess.open("res://tests")
	if dir == null:
		return {"suites": suites, "errors": ["res://tests is missing"]}
	for file_name in dir.get_files():
		if not (file_name.begins_with("test_") and file_name.ends_with(".gd")):
			continue
		var script = ResourceLoader.load("res://tests/" + file_name, "", ResourceLoader.CACHE_MODE_IGNORE)
		if script == null or not script.can_instantiate():
			errors.append("%s (load failed: parse error?)" % file_name)
			continue
		var instance = script.new()
		if instance is McpTestSuite:
			suites.append(instance)
		else:
			errors.append("%s (not a McpTestSuite)" % file_name)
	suites.sort_custom(func(a, b) -> bool: return a.suite_name() < b.suite_name())
	return {"suites": suites, "errors": errors}
