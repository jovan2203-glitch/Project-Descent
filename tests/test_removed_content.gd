@tool
extends McpTestSuite

# Guard: Ray of Frost was removed from the game; no code may reference it again.

func suite_name() -> String:
	return "removed_content"

func _walk(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		if sub != "addons" and sub != "tests" and not sub.begins_with("."):
			_walk(dir.path_join(sub), out)

## Every hit is named after what caused it (see Details.HIT_NAMES).
func test_hit_names() -> void:
	const Details = preload("res://scripts/core/details.gd")
	assert_eq(Details.spell_name("frozen_shatter"), "Frozen Shatter")
	assert_eq(Details.spell_name("rimeshell"), "Rime Shell")
	assert_eq(Details.spell_name("item_frost_shard"), "Shattering Cold", "item effects use the effect's name")
	assert_eq(Details.spell_name("burst_hoarfrost"), "Hoarfrost (Burst)")
	assert_eq(Details.spell_name("icefloe"), "Ice Floe")

func test_no_ray_of_frost() -> void:
	var files := []
	_walk("res://", files)
	var hits := []
	var re := RegEx.create_from_string("(?i)rayoffrost|ray of frost|play_ray")
	for p in files:
		var lines := FileAccess.get_file_as_string(p).split("\n")
		for i in lines.size():
			if re.search(lines[i]) != null:
				hits.append("%s:%d" % [p, i + 1])
	assert_true(hits.is_empty(), "Ray of Frost references: " + ", ".join(hits))
