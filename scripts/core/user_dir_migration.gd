extends RefCounted

## One-time move of saves / settings when the game got its own save folder.
##
## Before the rename to "Project: Descent" the game saved to
##   %APPDATA%/Godot/app_userdata/New Game Project/
## It now uses a fixed custom folder (project setting
## application/config/custom_user_dir_name = "ProjectDescent"):
##   %APPDATA%/ProjectDescent/
## On the first start with the new folder, everything from the old folder is
## copied over (the old folder is left in place as a backup). Called from
## PlayerData._init(), which is the first autoload, so it runs before anything
## reads user://.

const OLD_DIR_NAME := "New Game Project"
const MARKER := "user://.migrated_from_old_name"
const SKIP := ["logs", "shader_cache", "vulkan", ".godot"]


static func run() -> void:
	if FileAccess.file_exists(MARKER):
		return
	var old_dir := OS.get_data_dir().path_join("Godot/app_userdata").path_join(OLD_DIR_NAME)
	var new_dir := OS.get_user_data_dir()
	if old_dir.simplify_path() != new_dir.simplify_path() and DirAccess.dir_exists_absolute(old_dir):
		_copy_dir(old_dir, new_dir)
		print("Moved saves from %s to %s" % [old_dir, new_dir])
	var f := FileAccess.open(MARKER, FileAccess.WRITE)
	if f:
		f.store_string(Time.get_datetime_string_from_system())


## Copies files that don't exist yet in `to` (never overwrites newer data).
static func _copy_dir(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to)
	var d := DirAccess.open(from)
	if d == null:
		return
	d.include_hidden = true
	for sub in d.get_directories():
		if sub in SKIP:
			continue
		_copy_dir(from.path_join(sub), to.path_join(sub))
	for file in d.get_files():
		var dst := to.path_join(file)
		if not FileAccess.file_exists(dst):
			DirAccess.copy_absolute(from.path_join(file), dst)
