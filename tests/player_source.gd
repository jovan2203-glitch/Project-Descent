extends RefCounted
class_name PlayerSource

# The player's whole source for tests that check a hook or a rule is written in:
# scripts/player.gd plus every component in scripts/player/ (player_kit.gd).
# (Not named test_*.gd: not a suite.)

static func text() -> String:
	var out := FileAccess.get_file_as_string("res://scripts/player.gd")
	var dir := DirAccess.open("res://scripts/player")
	if dir:
		for f in dir.get_files():
			if f.ends_with(".gd"):
				out += "\n" + FileAccess.get_file_as_string("res://scripts/player/" + f)
	return out
