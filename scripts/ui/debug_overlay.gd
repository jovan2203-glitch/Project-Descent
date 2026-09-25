extends CanvasLayer

# On-screen FPS / stats overlay (top-right). Toggle with F3 ("debug_overlay"
# action) or /fps in chat.

const UPDATE_INTERVAL := 0.25
const ENEMY = preload("res://scripts/enemy.gd")

var _label: Label
var _timer := 0.0

func _ready() -> void:
	layer = 50
	add_to_group("debug_overlay")
	_label = Label.new()
	_label.anchor_left = 1.0
	_label.anchor_right = 1.0
	_label.offset_left = -330
	_label.offset_right = -12
	_label.offset_top = 12
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	visible = false

func toggle() -> void:
	visible = not visible
	_timer = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		toggle()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not visible:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = UPDATE_INTERVAL
	var lines: Array[String] = []
	lines.append("FPS %d  (%.1f ms)" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	lines.append("Physics %.1f ms  •  Draw calls %d" % [Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	lines.append("Nodes %d  •  Objects %d" % [Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT)])
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var p: Vector3 = player.global_position
		var st: String = player.state_name() if player.has_method("state_name") else "?"
		lines.append("Player %s  HP %d/%d  %s" % [st, player.health, player.max_health, "GOD" if player.get("god_mode") else ""])
		lines.append("Pos (%.1f, %.1f, %.1f)" % [p.x, p.y, p.z])
	var pd := get_node_or_null("/root/PlayerData")
	if pd:
		lines.append("Level %d  XP %d/%d" % [pd.level, pd.xp, pd.xp_to_next(pd.level)])
	var states := {}
	var enemies := get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		var s := "?"
		if e.get("state") != null:
			s = ENEMY.STATE_NAMES[clampi(int(e.state), 0, ENEMY.STATE_NAMES.size() - 1)]
		states[s] = int(states.get(s, 0)) + 1
	var parts: Array[String] = []
	for s in states:
		parts.append("%s %d" % [s, states[s]])
	lines.append("Enemies %d  %s" % [enemies.size(), ", ".join(parts)])
	var pool := get_node_or_null("/root/Pool")
	if pool:
		var reused := 0
		var created := 0
		for k in pool.stats:
			reused += int(pool.stats[k]["reused"])
			created += int(pool.stats[k]["created"])
		lines.append("Pool: %d created, %d reused" % [created, reused])
	_label.text = "\n".join(lines)
