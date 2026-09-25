extends Node

# Logging + local event feed (autoload "GameLog").
#
# 1. Leveled logging:  GameLog.debug/info/warn/error("category", "message")
#    - written to user://logs/game.log (the previous run is kept as game.prev.log)
#    - engine/script errors and print() output are captured into the same file
#    - warn/error also show in Godot's debugger (push_warning / push_error)
# 2. Event feed: everything that happens in the game, in plain words
#    ("Player cast Frost Bolt", "Zombie took 1 damage"). Built from SignalBus
#    events; shown in the chat's Logs tab and written to the log file.

enum Level { DEBUG, INFO, WARN, ERROR }
const LEVEL_NAMES := ["DEBUG", "INFO", "WARN", "ERROR"]
const LOG_DIR := "user://logs"
const LOG_PATH := "user://logs/game.log"
const PREV_PATH := "user://logs/game.prev.log"
const MAX_EVENTS := 200
const FLUSH_INTERVAL := 1.0

const ENGINE_CAPTURE = preload("res://scripts/core/engine_log_capture.gd")
const Abilities = preload("res://scripts/abilities.gd")
const Runes = preload("res://scripts/runes.gd")
const Items = preload("res://scripts/items.gd")

## Every log line (any level/category).
signal logged(level: int, category: String, text: String)
## Every gameplay event (for the chat Logs tab).
signal event_logged(text: String, color: Color)

var min_level: int = Level.DEBUG if OS.is_debug_build() else Level.INFO
var events: Array = []          # [{text, color, time}] newest last
var _file: FileAccess
var _capture: Logger
var _flush_timer := 0.0

const C_NORMAL := Color(0.85, 0.85, 0.88)
const C_PLAYER_HIT := Color(1.0, 1.0, 1.0)
const C_CRIT := Color(1.0, 0.85, 0.3)
const C_HURT := Color(1.0, 0.45, 0.4)
const C_HEAL := Color(0.5, 1.0, 0.5)
const C_STATUS := Color(0.55, 0.85, 1.0)
const C_LOOT := Color(1.0, 0.8, 0.35)
const C_XP := Color(0.8, 0.6, 1.0)
const C_DIM := Color(0.6, 0.6, 0.65)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_open_file()
	if not Engine.is_editor_hint():
		_capture = ENGINE_CAPTURE.new()
		OS.add_logger(_capture)
	info("game", "Session started (%s, Godot %s)" % [Time.get_datetime_string_from_system(), Engine.get_version_info().get("string", "")])
	_connect_events.call_deferred()

func _exit_tree() -> void:
	if _capture:
		OS.remove_logger(_capture)
	if _file:
		_file.flush()

func _open_file() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LOG_DIR))
	if FileAccess.file_exists(LOG_PATH):
		var prev := ProjectSettings.globalize_path(PREV_PATH)
		if FileAccess.file_exists(PREV_PATH):
			DirAccess.remove_absolute(prev)
		DirAccess.rename_absolute(ProjectSettings.globalize_path(LOG_PATH), prev)
	_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)

func _process(delta: float) -> void:
	if _capture:
		for entry in _capture.drain():
			_write(int(entry[0]), "engine", str(entry[1]))
	_flush_timer -= delta
	if _flush_timer <= 0.0 and _file:
		_flush_timer = FLUSH_INTERVAL
		_file.flush()

# --- Leveled logging -------------------------------------------------------------

func debug(category: String, text: String) -> void:
	log_line(Level.DEBUG, category, text)

func info(category: String, text: String) -> void:
	log_line(Level.INFO, category, text)

func warn(category: String, text: String) -> void:
	log_line(Level.WARN, category, text)

func error(category: String, text: String) -> void:
	log_line(Level.ERROR, category, text)

func log_line(level: int, category: String, text: String) -> void:
	if level < min_level:
		return
	_write(level, category, text)
	match level:
		Level.WARN: push_warning("[GameLog] %s: %s" % [category, text])
		Level.ERROR: push_error("[GameLog] %s: %s" % [category, text])
		_:
			if OS.is_debug_build():
				print("[GameLog] %s: %s" % [category, text])
	logged.emit(level, category, text)

func _write(level: int, category: String, text: String) -> void:
	if _file == null:
		return
	var t := Time.get_time_string_from_system()
	_file.store_line("%s [%s] %s: %s" % [t, LEVEL_NAMES[clampi(level, 0, 3)], category, text])
	if level >= Level.WARN:
		_file.flush()

# --- Event feed ------------------------------------------------------------------

## Add a line to the event feed (chat Logs tab) and the log file.
func event(text: String, color: Color = C_NORMAL) -> void:
	events.append({"text": text, "color": color, "time": Time.get_time_string_from_system()})
	if events.size() > MAX_EVENTS:
		events.remove_at(0)
	_write(Level.INFO, "event", text)
	event_logged.emit(text, color)

func _connect_events() -> void:
	var bus := get_node_or_null("/root/SignalBus")
	if bus == null:
		warn("log", "SignalBus missing: event feed disabled")
		return
	bus.cast_finished.connect(func(id): event("Player cast %s" % _ability(id), C_NORMAL))
	bus.cast_interrupted.connect(func(id): event("Player's %s was interrupted" % _ability(id), C_DIM))
	bus.damage_dealt.connect(_on_damage)
	bus.healed.connect(func(_s, t, n): event("%s was healed for %d" % [_who(t), n], C_HEAL))
	bus.status_applied.connect(_on_status)
	bus.status_consumed.connect(func(t, _id, nm, n): event("%s consumed %s%s" % [_who(t), nm, " (x%d)" % n if n > 1 else ""], C_STATUS))
	bus.enemy_aggroed.connect(func(e): event("%s noticed you" % _who(e), C_DIM))
	bus.enemy_died.connect(func(e): event("%s died" % _who(e), C_DIM))
	bus.player_died.connect(func(): event("Player died", C_HURT))
	bus.item_looted.connect(func(id): event("Looted %s" % Items.item_name(id), C_LOOT))
	bus.rune_triggered.connect(func(eid: String): event("%s triggered" % (
		eid.trim_prefix("item:") if eid.begins_with("item:") else Runes.rune_name(eid)), C_STATUS))
	bus.xp_gained.connect(func(n): event("Gained %d experience" % n, C_XP))
	bus.level_up.connect(func(lv): event("Reached level %d!" % lv, C_XP))
	bus.skill_card_unlocked.connect(func(id): event("Unlocked ability: %s" % _ability(id), C_XP))
	bus.game_state_changed.connect(func(s): info("game", "Game state -> %d" % s))

func _on_damage(info_obj: RefCounted) -> void:
	var src: Node = info_obj.source
	var tgt: Node = info_obj.target
	var tgt_name := _who(tgt)
	var src_name := _who(src)
	var what := _ability(str(info_obj.ability_id))
	var to_player := tgt != null and is_instance_valid(tgt) and tgt.is_in_group("player")
	if info_obj.blocked:
		event("%s blocked %s's %s" % [tgt_name, src_name, what], C_STATUS)
		return
	if int(info_obj.amount) <= 0:
		return
	var text := ""
	if info_obj.is_dot:
		text = "%s took %d damage from %s" % [tgt_name, info_obj.amount, what]
	else:
		text = "%s took %d damage from %s's %s" % [tgt_name, info_obj.amount, src_name, what]
	if info_obj.crit:
		text += " (critical)"
	if not info_obj.modifiers.is_empty():
		text += " [%s]" % ", ".join(info_obj.modifiers)
	var col := C_HURT if to_player else (C_CRIT if info_obj.crit else C_PLAYER_HIT)
	event(text, col)

func _on_status(target: Node, effect_name: String, is_debuff: bool, stacks: int) -> void:
	var who := _who(target)
	var s := " (x%d)" % stacks if stacks > 1 else ""
	if is_debuff:
		event("%s is afflicted by %s%s" % [who, effect_name, s], C_STATUS)
	else:
		event("%s gains %s%s" % [who, effect_name, s], C_STATUS)

# --- Naming helpers --------------------------------------------------------------

func _who(n: Node) -> String:
	if n == null or not is_instance_valid(n):
		return "Something"
	if n.is_in_group("player"):
		return "Player"
	var dn = n.get("display_name")
	if dn is String and dn != "":
		return dn
	var nm := String(n.name)
	while nm.length() > 1 and nm[nm.length() - 1].is_valid_int():
		nm = nm.substr(0, nm.length() - 1)
	return nm

func _ability(id: String) -> String:
	if id == "enemy_melee":
		return "attack"
	if id.begins_with("rune_"):
		return Runes.rune_name(id.trim_prefix("rune_"))
	if id.begins_with("item_"):   # item Equip: / Use: effect hits
		return id.trim_prefix("item_").capitalize()
	if id.begins_with("dot_"):
		return id.trim_prefix("dot_").capitalize()
	var n := Abilities.ability_name(id)
	return n if n != "" else id.capitalize()
