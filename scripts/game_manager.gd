extends Node

# Persistent cross-scene game state + scene flow (autoload "GameManager").
# Listens on SignalBus for kills/deaths (and gives kill XP); owns all scene
# changes, which go through a background-loading screen (change_scene()).
# Inventory/equipment/bank live in PlayerData; display options in Settings.
# Access from other scripts: get_node("/root/GameManager")

enum State { MENU, PLAYING, DEAD }

const MAIN_MENU := "res://scenes/main_menu.tscn"
const GAME_SCENE := "res://node_3d.tscn"
const MIN_LOADING_TIME := 0.35   # keep the loading screen up at least this long (no flicker)

var state: State = State.MENU

# Run stats (reset each time a run starts from the menu).
var kills := 0
var deaths := 0
var play_time := 0.0

func _bus() -> Node:
	return get_node("/root/SignalBus")

func _log() -> Node:
	return get_node_or_null("/root/GameLog")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bus().enemy_died.connect(_on_enemy_died)
	_bus().player_died.connect(_on_player_died)
	# Figure out where we started (running the cave scene directly skips the menu).
	await get_tree().process_frame
	var cur := get_tree().current_scene
	if cur and cur.scene_file_path != MAIN_MENU and cur.scene_file_path != "":
		current_instance = cur.scene_file_path
		_set_state(State.PLAYING)

func _process(delta: float) -> void:
	if state == State.PLAYING and not get_tree().paused:
		play_time += delta
	_poll_loading(delta)

func _set_state(s: State) -> void:
	if state == s:
		return
	state = s
	_bus().game_state_changed.emit(s)

func _on_enemy_died(enemy: Node) -> void:
	kills += 1
	var reward := int(enemy.get("xp_reward")) if enemy and enemy.get("xp_reward") != null else 0
	if reward > 0:
		get_node("/root/PlayerData").add_xp(reward)

func _on_player_died() -> void:
	deaths += 1
	# Roguelike: the death penalty is applied right away (see PlayerData.apply_death).
	var d: Dictionary = get_node("/root/PlayerData").apply_death()
	var gl := _log()
	if gl:
		gl.event("You died. Level %d -> %d. Lost %d item(s)%s." % [int(d["old_level"]), int(d["new_level"]),
			d["lost"].size(), (", learned %d rune(s)" % d["runes_learned"].size()) if not d["runes_learned"].is_empty() else ""],
			Color(1.0, 0.4, 0.35))
	_set_state(State.DEAD)

# --- Scene flow ------------------------------------------------------------------

var current_instance := GAME_SCENE

# Procedural dungeon run: floor number and the seed its layout is built from.
# Restarting after death keeps the seed (same layout); descending makes a new one.
var dungeon_depth := 1
var dungeon_seed := 0

func _net() -> Node:
	return get_node_or_null("/root/Net")

func _in_party_run() -> bool:
	var net := _net()
	return net != null and net.online and not net.run.is_empty()

# Launch into a dungeon/raid instance (defaults to the cave).
# In a party only the leader can start, and everyone goes in together.
## `scene_path` may carry a starting floor: "res://scenes/dungeon.tscn@5"
## (a checkpoint). The same string is the matchmaking queue key, so only players
## heading to the same floor are grouped together.
static func instance_key(scene_path: String, start_floor: int = 1) -> String:
	return scene_path if start_floor <= 1 else "%s@%d" % [scene_path, start_floor]

static func split_key(key: String) -> Array:   # [scene path, start floor]
	var at := key.rfind("@")
	if at > 0 and key.substr(at + 1).is_valid_int():
		return [key.substr(0, at), maxi(int(key.substr(at + 1)), 1)]
	return [key, 1]

func start_game(scene_key: String = GAME_SCENE) -> void:
	var parts := split_key(scene_key)
	var scene_path: String = parts[0]
	var start_floor: int = parts[1]
	# Only floors you've unlocked (checkpoints) can be started on.
	var pd := get_node("/root/PlayerData")
	if not pd.start_floors(scene_path).has(start_floor):
		start_floor = 1
	var net := _net()
	if net and net.online:
		if net.is_host():
			net.start_game(scene_path, start_floor)
		else:
			get_node("/root/Online").toast.emit("Only the party leader can start.")
		return
	kills = 0
	deaths = 0
	play_time = 0.0
	current_instance = scene_path
	dungeon_depth = start_floor
	dungeon_seed = randi()
	change_scene(scene_path, State.PLAYING)

## Go one floor deeper in the current procedural dungeon (new layout).
func descend() -> void:
	if _in_party_run():
		_net().descend()   # only the leader's button calls this
		return
	dungeon_depth += 1
	dungeon_seed = randi()
	change_scene(current_instance, State.PLAYING)

func restart() -> void:
	if _in_party_run():
		_net().request_restart()
		return
	var cur := get_tree().current_scene
	var path := cur.scene_file_path if cur else current_instance
	change_scene(path, State.PLAYING)

# Leaving the game (Esc > Quit): equipped gear stays on, the bag goes to the bank.
# In a party this leaves the group; if you were the leader the others migrate.
func go_to_menu() -> void:
	if _in_party_run():
		_net().leave_run()
		return
	net_to_menu()

## "Return to Lobby" after clearing a floor: the whole party goes back together.
func end_run() -> void:
	if _in_party_run() and _net().is_host():
		_net().return_to_menu()
		return
	go_to_menu()

## Net: load the party's dungeon floor (same seed on every machine).
func net_load(path: String, depth: int, seed_value: int) -> void:
	if state == State.MENU or path != current_instance:
		kills = 0
		deaths = 0
		play_time = 0.0
	current_instance = path
	dungeon_depth = depth
	dungeon_seed = seed_value
	change_scene(path, State.PLAYING)

## Net: back to the main menu.
func net_to_menu() -> void:
	get_node("/root/PlayerData").move_inventory_to_bank()
	# Level / XP / everything is saved right away when leaving a dungeon.
	var save := get_node_or_null("/root/SaveSystem")
	if save:
		save.save_profile()
	change_scene(MAIN_MENU, State.MENU)

func quit_game() -> void:
	var online := get_node_or_null("/root/Online")
	if online:
		online.leave_party(true)
	var save := get_node_or_null("/root/SaveSystem")
	if save:
		save.save_profile()
	var gl := _log()
	if gl:
		gl.info("game", "Quit")
	get_tree().quit()

# --- Background loading + loading screen -------------------------------------------

var _loading_path := ""
var _loading_state: State = State.MENU
var _loading_elapsed := 0.0
var _loaded_scene: PackedScene
var _hide_frames := 0
var _overlay: CanvasLayer
var _bar: ProgressBar
var _label: Label

func is_loading() -> bool:
	return _loading_path != ""

## Load `path` on a background thread while showing the loading screen, then
## switch to it and set the game state.
func change_scene(path: String, new_state: State = State.PLAYING) -> void:
	if is_loading():
		return
	get_tree().paused = false   # e.g. leaving from a paused "Dungeon cleared" screen
	_loading_path = path
	_loading_state = new_state
	_loading_elapsed = 0.0
	_loaded_scene = null
	_show_overlay(path)
	var gl := _log()
	if gl:
		gl.info("scene", "Loading %s" % path)
	var err := ResourceLoader.load_threaded_request(path)
	if err != OK:
		if gl:
			gl.warn("scene", "Threaded load failed (%s); loading directly" % error_string(err))
		_finish_change(load(path))

func _poll_loading(delta: float) -> void:
	if _hide_frames > 0:
		_hide_frames -= 1
		if _hide_frames == 0 and _overlay:
			_overlay.visible = false
		return
	if not is_loading():
		return
	_loading_elapsed += delta
	if _loaded_scene == null:
		var progress := []
		var status := ResourceLoader.load_threaded_get_status(_loading_path, progress)
		if progress.size() > 0:
			_bar.value = float(progress[0]) * 100.0
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				_loaded_scene = ResourceLoader.load_threaded_get(_loading_path)
				_bar.value = 100.0
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				var gl := _log()
				if gl:
					gl.error("scene", "Could not load %s" % _loading_path)
				_loaded_scene = load(_loading_path)
	if _loaded_scene and _loading_elapsed >= MIN_LOADING_TIME:
		_finish_change(_loaded_scene)

func _finish_change(scene: PackedScene) -> void:
	var path := _loading_path
	_loading_path = ""
	_loaded_scene = null
	if scene == null:
		_overlay.visible = false
		return
	get_tree().change_scene_to_packed(scene)
	_set_state(_loading_state)
	# Keep the overlay a few frames so the new scene's _ready work (navmesh bake)
	# happens behind it.
	_hide_frames = 3
	var gl := _log()
	if gl:
		gl.info("scene", "Entered %s" % path)

func _show_overlay(path: String) -> void:
	if _overlay == null:
		_overlay = CanvasLayer.new()
		_overlay.layer = 100
		add_child(_overlay)
		var bg := ColorRect.new()
		bg.color = Color(0.03, 0.035, 0.05)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		_overlay.add_child(bg)
		var box := VBoxContainer.new()
		box.anchor_left = 0.5
		box.anchor_right = 0.5
		box.anchor_top = 0.5
		box.anchor_bottom = 0.5
		box.offset_left = -220
		box.offset_right = 220
		box.offset_top = -40
		box.offset_bottom = 40
		box.add_theme_constant_override("separation", 10)
		_overlay.add_child(box)
		_label = Label.new()
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 22)
		_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35))
		box.add_child(_label)
		_bar = ProgressBar.new()
		_bar.custom_minimum_size = Vector2(440, 18)
		_bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.95, 0.75, 0.35)
		fill.set_corner_radius_all(4)
		var back := StyleBoxFlat.new()
		back.bg_color = Color(0.12, 0.12, 0.15)
		back.set_corner_radius_all(4)
		_bar.add_theme_stylebox_override("fill", fill)
		_bar.add_theme_stylebox_override("background", back)
		box.add_child(_bar)
	_label.text = "Loading…" if path == MAIN_MENU else "Entering %s…" % _pretty(path)
	_bar.value = 0.0
	_overlay.visible = true

func _pretty(path: String) -> String:
	if path == GAME_SCENE:
		return "The Cave"
	return path.get_file().get_basename().capitalize()
