extends RefCounted

# Which build this is. The release workflow (.github/workflows/release.yml)
# stamps the tag's version into project.godot (application/config/version)
# before exporting; editor and local runs have none and count as "dev".
# Party members must run the same build: Online tags lobbies with it and Net
# turns away a joiner whose build differs from the host's.
# Usage: const BuildInfo = preload("res://scripts/core/build_info.gd")

static func version() -> String:
	var v := str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	return v if v != "" else "dev"

## Shown to someone turned away for running a different build.
static func mismatch_text(host_version: String, mine: String) -> String:
	return "That party is on version %s and you're on %s. Everyone needs the same version to play together." % [host_version, mine]
