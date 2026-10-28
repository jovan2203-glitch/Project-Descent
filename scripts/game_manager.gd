extends Node

# Persistent cross-scene game state + scene flow (autoload "GameManager").
# Listens on SignalBus for kills/deaths (and gives kill XP); owns all scene
# changes, which go through a background-loading screen (change_scene()).
# Inventory/equipment/bank live in PlayerData; display options in Settings.
# Access from other scripts: get_node("/root/GameManager")

enum State { MENU, PLAYING, DEAD }

const MAIN_MENU := "res://scenes/main_menu.tscn"
const TRAINING_SCENE := "res://scenes/training.tscn"
const DB = preload("res://scripts/dungeon/dungeon_db.gd")
const Mods = preload("res://scripts/dungeon/modifiers.gd")
const Balance = preload("res://scripts/balance.gd")
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
	_bus().xp_gained.connect(_on_run_xp)
	_bus().dungeon_cleared.connect(_on_run_cleared)
	# Figure out where we started (running a dungeon scene directly skips the menu).
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

func in_training() -> bool:
	var cur := get_tree().current_scene
	return cur != null and cur.scene_file_path == TRAINING_SCENE

func _on_player_died() -> void:
	deaths += 1
	if not Balance.ROGUELIKE_DEATH:
		# Death costs nothing for now: revive (R) or go back to the menu.
		get_node("/root/PlayerData").last_death = {}
		var gl0 := _log()
		if gl0:
			gl0.event("You died. Press %s to revive, or leave from the menu (Esc)." % get_node("/root/Settings").key_text("restart"),
				Color(1.0, 0.4, 0.35))
		_set_state(State.DEAD)
		return
	if in_training():
		# Practice: dying in the Training Room costs nothing (restart to go again).
		get_node("/root/PlayerData").last_death = {}
		_set_state(State.DEAD)
		return
	# Roguelike: the death penalty is applied right away (see PlayerData.apply_death).
	var d: Dictionary = get_node("/root/PlayerData").apply_death()
	var gl := _log()
	if gl:
		gl.event("You died. Level %d -> %d. Lost %d item(s)%s." % [int(d["old_level"]), int(d["new_level"]),
			d["lost"].size(), (", learned %d rune(s)" % d["runes_learned"].size()) if not d["runes_learned"].is_empty() else ""],
			Color(1.0, 0.4, 0.35))
	_set_state(State.DEAD)

# --- Scene flow ------------------------------------------------------------------

var current_instance := DB.RUN_SCENE

# Procedural dungeon run: floor number and the seed its layout is built from.
# Restarting after death keeps the seed (same layout); descending makes a new one.
var dungeon_depth := 1
var dungeon_seed := 0
## Recipe id of the dungeon being played (data/dungeons/<id>.tres).
var dungeon_id := ""
## Enemy level: the party's average pulled toward its highest level (DungeonDB.party_level).
var dungeon_level := 1
## Dungeon modifiers of this run (rolled from the seed: the same for the whole party).
var dungeon_modifiers: Array[String] = []

func has_modifier(id: String) -> bool:
	return state != State.MENU and dungeon_modifiers.has(id)

## CombatSystem: % damage change from the run's modifiers (Frost-Touched...).
func dungeon_damage_pct(info: RefCounted) -> float:
	if dungeon_modifiers.is_empty() or state == State.MENU:
		return 0.0
	return Mods.damage_pct(dungeon_modifiers, info)

func heal_mult() -> float:
	return Mods.heal_mult(dungeon_modifiers) if state != State.MENU else 1.0

func lifesteal_mult() -> float:
	return Mods.lifesteal_mult(dungeon_modifiers) if state != State.MENU else 1.0

## Levels of everyone in the group (yours is always current).
func party_levels() -> Array:
	var mine := int(get_node("/root/PlayerData").level)
	var net := _net()
	if net == null or not net.online:
		return [mine]
	var out: Array = []
	for m in net.members:
		out.append(mine if int(m) == int(net.my_id()) else int(net.members[m].get("level", 1)))
	if out.is_empty():
		out.append(mine)
	return out

## Everything a run needs besides the scene: which dungeon and the enemy level.
## Decided once (by the leader) and sent to the whole party.
func _prepare_run(key: String) -> Dictionary:
	var res := DB.resolve(key, randi())
	return {"path": str(res["path"]), "extra": {"dungeon": str(res["dungeon"]),
		"lvl": DB.party_level(party_levels())}}

func _apply_run_extra(extra: Dictionary, seed_value: int) -> void:
	dungeon_id = str(extra.get("dungeon", ""))
	dungeon_level = maxi(int(extra.get("lvl", get_node("/root/PlayerData").level)), 1)
	dungeon_modifiers.clear()
	var r: Resource = DB.find(dungeon_id)
	if r and Mods.ENABLED:
		dungeon_modifiers.assign(Mods.roll(Array(r.modifier_pool), int(r.modifier_count), seed_value))

# --- Difficulty ----------------------------------------------------------------------
# "solo": the normal game, beatable alone. "party": tuned for a 5-player group -
# enemies hit far harder (the tank has to use his defensive abilities, and a big
# pull needs a healer), have more health, and archers / casters sometimes shoot
# someone who isn't tanking them. Picked on the Play screen; in a party the
# leader's choice counts (sent with the run).
const DIFFICULTIES := ["solo", "party"]
var difficulty := "solo"

func is_party_mode() -> bool:
	return difficulty == "party"

## Bosses have their own 5 Player numbers (balance.gd PARTY_BOSS_*).
func enemy_damage_mult(boss := false) -> float:
	if not is_party_mode():
		return 1.0
	return Balance.PARTY_BOSS_DAMAGE_MULT if boss else Balance.PARTY_DAMAGE_MULT

## `pack`: placed trash (tougher than adds that join a fight: boss summons, alarms, waves).
func enemy_health_mult(boss := false, pack := false) -> float:
	if not is_party_mode():
		return 1.0
	if boss:
		return Balance.PARTY_BOSS_HEALTH_MULT
	return Balance.PARTY_HEALTH_MULT if pack else Balance.PARTY_ADD_HEALTH_MULT

func off_target_chance() -> float:
	return Balance.PARTY_OFF_TARGET_CHANCE if is_party_mode() else 0.0

static func difficulty_label(d: String) -> String:
	return "5 Player" if d == "party" else "Singleplayer"

func _net() -> Node:
	return get_node_or_null("/root/Net")

func _in_party_run() -> bool:
	var net := _net()
	return net != null and net.online and not net.run.is_empty()

# Launch into a dungeon. `scene_key` is a queue key ("dungeon:random",
# "dungeon:<id>", see dungeon_db.gd) or a plain scene path.
# In a party only the leader can start, and everyone goes in together.
func start_game(scene_key: String = DB.RANDOM_KEY) -> void:
	var net := _net()
	if net and net.online:
		if net.is_host():
			var prep := _prepare_run(scene_key)
			net.start_game(str(prep["path"]), 1, prep["extra"])
		else:
			get_node("/root/Online").toast.emit("Only the party leader can start.")
		return
	var run := _prepare_run(scene_key)
	kills = 0
	deaths = 0
	play_time = 0.0
	get_node("/root/PlayerData").start_pact_run()   # a new dungeon: a broken Pact is whole again
	current_instance = str(run["path"])
	dungeon_depth = 1
	dungeon_seed = randi()
	_apply_run_extra(run["extra"], dungeon_seed)
	_begin_run_record()
	change_scene(current_instance, State.PLAYING)

## Training Room (solo): dummies to test damage, healing and tanking. No XP,
## no loot, no death penalty.
func start_training() -> void:
	difficulty = "solo"
	get_node("/root/PlayerData").start_pact_run()   # (Pacts can be tried here: broken ones come back each visit)
	current_instance = TRAINING_SCENE
	dungeon_depth = 1
	dungeon_seed = 0
	dungeon_id = ""
	dungeon_modifiers.clear()
	change_scene(TRAINING_SCENE, State.PLAYING)

## Go one floor deeper in the current procedural dungeon (new layout).
func descend() -> void:
	if _in_party_run():
		_net().descend()   # only the leader's button calls this
		return
	dungeon_depth += 1
	dungeon_seed = randi()
	change_scene(current_instance, State.PLAYING)

func restart() -> void:
	if not Balance.ROGUELIKE_DEATH:
		revive_local()
		return
	if _in_party_run():
		_net().request_restart()
		return
	var cur := get_tree().current_scene
	var path := cur.scene_file_path if cur else current_instance
	change_scene(path, State.PLAYING)

## No-drawback death: stand back up with full health at the dungeon's revive
## point (entrance / last boss room cleared). Works solo and in a party.
func revive_local() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null or not p.has_method("respawn"):
		return
	var scene := get_tree().current_scene
	var at: Vector3 = scene.respawn_point() if scene and scene.has_method("respawn_point") else p.get("start_position")
	p.respawn(at)
	_set_state(State.PLAYING)
	var gl := _log()
	if gl:
		gl.event("You got back up.", Color(1.0, 0.9, 0.5))

## Raised by a healer's out-of-combat rez (Net._sup_raise): back up where you fell,
## with part of your health and mana. `who` names the healer for the log.
func raise_local(who: String = "") -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null or not p.has_method("respawn") or not p.is_dead():
		return
	p.respawn(p.global_position, Balance.RAISE_HEALTH_PCT, Balance.RAISE_MANA_PCT)
	_set_state(State.PLAYING)
	var gl := _log()
	if gl:
		gl.event("%s brought you back." % who if who != "" and who != "?" else "You were brought back.", Color(1.0, 0.9, 0.5))

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
func net_load(path: String, depth: int, seed_value: int, diff: String = "", extra: Dictionary = {}) -> void:
	if DIFFICULTIES.has(diff):
		difficulty = diff
	_apply_run_extra(extra, seed_value)
	if state == State.MENU or path != current_instance:
		kills = 0
		deaths = 0
		play_time = 0.0
		get_node("/root/PlayerData").start_pact_run()   # a new dungeon (not the next floor of this one)
		_begin_run_record()
	current_instance = path
	dungeon_depth = depth
	dungeon_seed = seed_value
	change_scene(path, State.PLAYING)

## Net: back to the main menu.
func net_to_menu() -> void:
	var pd := get_node("/root/PlayerData")
	var bag: Array = pd.inventory.filter(func(id): return str(id) != "")
	pd.move_inventory_to_bank()
	_finish_run_record(bag)
	# Level / XP / everything is saved right away when leaving a dungeon.
	var save := get_node_or_null("/root/SaveSystem")
	if save:
		save.save_profile()
	change_scene(MAIN_MENU, State.MENU)

# --- Last run (the menu's summary card) ------------------------------------------------
# A dungeon run is recorded from its start until you're back in the menu; the
# Training Room isn't one. last_run is shown once in the lobby, then cleared.

var _run_record := {}
## {"title", "cleared", "time", "bosses", "kills", "xp", "levels", "loot": item ids,
##  "party": [{"name", "damage", "healing"}], "best", "diff"}; {} = nothing to show.
var last_run := {}

func _begin_run_record() -> void:
	var pd := get_node("/root/PlayerData")
	_run_record = {"t0": Time.get_ticks_msec() / 1000.0, "level": int(pd.level), "xp": 0,
		"title": DB.title(dungeon_id) if dungeon_id != "" else current_instance.get_file().get_basename().capitalize()}
	last_run = {}
	var details := get_node_or_null("/root/Details")
	if details:
		details.reset_run()

func _on_run_xp(amount: int) -> void:
	if not _run_record.is_empty():
		_run_record["xp"] += amount

func _on_run_cleared(summary: Dictionary) -> void:
	if not _run_record.is_empty():
		_run_record["clear"] = summary

func _finish_run_record(loot: Array) -> void:
	if _run_record.is_empty():
		return
	var r := _run_record
	_run_record = {}
	var clear: Dictionary = r.get("clear", {})
	var party: Array = []
	var details := get_node_or_null("/root/Details")
	if details:
		for m in details.run_totals:
			party.append(details.run_totals[m].duplicate())
		party.sort_custom(func(a, b): return int(a["damage"]) > int(b["damage"]))
	last_run = {"title": str(clear.get("dungeon", r["title"])), "cleared": not clear.is_empty(),
		"time": float(clear.get("time", Time.get_ticks_msec() / 1000.0 - float(r["t0"]))),
		"bosses": int(clear.get("bosses", 0)), "kills": int(clear.get("kills", kills)), "xp": int(r["xp"]),
		"levels": int(get_node("/root/PlayerData").level) - int(r["level"]), "loot": loot, "party": party,
		"best": bool(clear.get("best", false)), "diff": difficulty}

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
	if path == DB.RUN_SCENE and dungeon_id != "":
		return DB.title(dungeon_id)
	if path == TRAINING_SCENE:
		return "the Training Room"
	return path.get_file().get_basename().capitalize()
