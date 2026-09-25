extends Logger

# Captures engine/script errors, warnings and print() output so GameLog can
# write them into the log file. Logger virtuals may run on any thread, so
# entries are queued under a mutex and drained by GameLog on the main thread.

var _pending: Array = []
var _mutex := Mutex.new()

func _log_message(message: String, error: bool) -> void:
	_push(3 if error else 1, message.strip_edges())

func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
	var msg := rationale if rationale != "" else code
	var level := 2 if error_type == 1 else 3   # ERROR_TYPE_WARNING = 1
	_push(level, "%s (%s:%d @ %s)" % [msg, file, line, function])

func _push(level: int, text: String) -> void:
	if text == "" or text.begins_with("[GameLog]"):
		return   # GameLog's own output is already in the file
	_mutex.lock()
	_pending.append([level, text])
	_mutex.unlock()

func drain() -> Array:
	_mutex.lock()
	var out := _pending
	_pending = []
	_mutex.unlock()
	return out
