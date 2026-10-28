extends RefCounted
class_name HudSource

# The in-game HUD's whole source for tests that check something is written in
# it: scripts/hud.gd plus every element in scripts/ui/hud/ (hud_element.gd) and
# the party frames. (Not named test_*.gd: not a suite.)

const HUD := "res://scripts/hud.gd"
const DIR := "res://scripts/ui/hud/"

## Every element file's path.
static func files() -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".gd"):
			out.append(DIR + f)
	out.sort()
	return out

static func text() -> String:
	var out := FileAccess.get_file_as_string(HUD)
	for f in files():
		out += "\n" + FileAccess.get_file_as_string(f)
	out += "\n" + FileAccess.get_file_as_string("res://scripts/ui/party_frames.gd")
	return out
