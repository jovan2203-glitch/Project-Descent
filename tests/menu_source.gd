extends RefCounted
class_name MenuSource

# The main menu's whole source for tests that check something is written in it:
# scripts/main_menu.gd plus every part in scripts/menu/ (menu_part.gd), shown as it
# read before the split (like PlayerSource for the player): a part's "menu.x" reads
# "x" and its "menu" reads "self"; "<part var>.x", "<PartClass>.x" and "MainMenu.x" read "x".
# (Not named test_*.gd: not a suite.)

const MENU := "res://scripts/main_menu.gd"

## [[var, Class, file], ...] from scripts/menu/parts.txt.
static func parts() -> Array:
	var out := []
	for line in FileAccess.get_file_as_string("res://scripts/menu/parts.txt").split("\n", false):
		var p := line.split(" ", false)
		if p.size() == 3:
			out.append(p)
	return out

static func text() -> String:
	var out := FileAccess.get_file_as_string(MENU)
	var names := PackedStringArray(["MainMenu"])
	for p in parts():
		var part := FileAccess.get_file_as_string("res://scripts/menu/" + str(p[2]))
		part = _sub(part, "\\bmenu\\.(?=[A-Za-z_])", "")
		part = _sub(part, "\\bmenu\\b", "self")
		out += "\n" + part
		names.append(str(p[0]))
		names.append(str(p[1]))
	return _sub(out, "\\b(?:%s)\\.(?=[A-Za-z_])" % "|".join(names), "")

## The menu's consts, wherever they live now (main_menu.gd or a part).
static func constants() -> Dictionary:
	var out: Dictionary = (load(MENU) as Script).get_script_constant_map().duplicate()
	for p in parts():
		out.merge((load("res://scripts/menu/" + str(p[2])) as Script).get_script_constant_map())
	return out

## get_script_method_list() of main_menu.gd and every part.
static func methods() -> Array:
	var out: Array = (load(MENU) as Script).get_script_method_list()
	for p in parts():
		out.append_array((load("res://scripts/menu/" + str(p[2])) as Script).get_script_method_list())
	return out

static func _sub(text: String, pattern: String, with: String) -> String:
	return RegEx.create_from_string(pattern).sub(text, with, true)
