extends RefCounted
class_name PlayerSource

# The player's whole source for tests that check a hook or a rule is written in:
# scripts/player.gd plus every component in scripts/player/ (player_kit.gd).
# It is shown as it read before the split, so those checks don't depend on where
# a piece of code lives: a component's "player.x" reads "x" and its "player"
# reads "self"; "<component>.x" and "<ComponentClass>.x" / "Player.x" read "x".
# (Not named test_*.gd: not a suite.)

static func text() -> String:
	var kits: Array = []   # [var, Class, file]
	for line in FileAccess.get_file_as_string("res://scripts/player/kits.txt").split("\n", false):
		var parts := line.split(" ", false)
		if parts.size() == 3:
			kits.append(parts)
	var out := FileAccess.get_file_as_string("res://scripts/player.gd")
	for k in kits:
		var kit := FileAccess.get_file_as_string("res://scripts/player/" + str(k[2]))
		kit = _sub(kit, "\\bplayer\\.(?=[A-Za-z_])", "")
		kit = _sub(kit, "\\bplayer\\b", "self")
		out += "\n" + kit
	var names := PackedStringArray(["Player"])
	for k in kits:
		names.append(str(k[0]))
		names.append(str(k[1]))
	return _sub(out, "\\b(?:%s)\\.(?=[A-Za-z_])" % "|".join(names), "")

static func _sub(text: String, pattern: String, with: String) -> String:
	var re := RegEx.create_from_string(pattern)
	return re.sub(text, with, true)
