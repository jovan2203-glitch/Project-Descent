@tool
extends McpTestSuite

# Party members must run the same build. The release workflow stamps the tag's
# version into project.godot; Online tags Steam lobbies with it (and checks it
# before connecting) and Net's host turns away a joiner on another build.
# Rules: scripts/core/build_info.gd.

const BuildInfo = preload("res://scripts/core/build_info.gd")

func suite_name() -> String:
	return "build_version"

func _src(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func test_editor_runs_are_dev() -> void:
	assert_eq(str(ProjectSettings.get_setting("application/config/version", "")), "", "the version is only stamped by the release workflow")
	assert_eq(BuildInfo.version(), "dev")

func test_release_workflow_stamps_the_tag_version() -> void:
	var wf := _src("res://.github/workflows/release.yml")
	var stamp := wf.find("config/version")
	assert_true(stamp != -1, "release.yml writes application/config/version")
	assert_true(stamp < wf.find("--export-release"), "stamped before the export")

func test_mismatch_message_names_both_versions() -> void:
	var t := BuildInfo.mismatch_text("0.0.23", "0.0.22")
	assert_true(t.contains("0.0.23") and t.contains("0.0.22"))

func test_lobbies_are_tagged_and_filtered_by_version() -> void:
	var src := _src("res://scripts/net/online.gd")
	assert_true(src.contains('addRequestLobbyListStringFilter("ver", BuildInfo.version()'), "queue search only finds the same build")
	assert_eq(src.count('setLobbyData(lobby_id, "ver", BuildInfo.version())'), src.count('setLobbyData(lobby_id, "game", GAME_KEY)'), "every lobby tag write also tags the version")
	assert_true(src.contains('getLobbyData(lid, "ver")'), "joining checks the lobby's version before connecting")

func test_host_rejects_other_builds() -> void:
	var src := _src("res://scripts/net/net.gd")
	assert_true(src.contains('"ver": BuildInfo.version()'), "joiners send their version")
	var hello := src.find("func _hello(")
	var check := src.find("BuildInfo.mismatch_text", hello)
	assert_true(check != -1 and check < src.find("members[member] = info", hello), "checked before the joiner is added")
