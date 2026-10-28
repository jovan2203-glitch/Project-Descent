extends Node
class_name TrackerEngine

# Runs the player's Trackers (Settings.trackers, scripts/ui/trackers/trackers.gd)
# in the HUD: one display per tracker or group (tracker_display.gd), each a Move
# UI element ("tracker:<id>"). Ten times a second it works out what every loaded
# tracker shows; events (SignalBus) are remembered with when they happened, for
# Event triggers. Trackers whose load rules don't match are hidden and cost nothing.

const GROUP := "tracker_engine"
const SWEEP := 0.1

var hud: Node
var _layer: Control
var _displays := {}         # id -> TrackerDisplay
var _events := {}           # Trackers.event_key -> time it last happened
var _event_names := {}      # Trackers.event_key -> what to call it (%name)
var _t := 0.0
var _boss := false

static func of(tree: SceneTree) -> TrackerEngine:
	return tree.get_first_node_in_group(GROUP) as TrackerEngine if tree != null else null

func _ready() -> void:
	add_to_group(GROUP)
	_layer = Control.new()
	_layer.name = "Trackers"
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	(hud if hud else get_parent()).add_child.call_deferred(_layer)
	var st := get_node_or_null("/root/Settings")
	if st:
		st.register_hud(_layer)
	var bus := get_node_or_null("/root/SignalBus")
	if bus:
		bus.ability_used.connect(func(id): _event("ability_used", id))
		bus.cast_started.connect(func(id, _d): _event("cast_started", id))
		bus.cast_finished.connect(func(id): _event("cast_finished", id))
		bus.cast_interrupted.connect(func(id): _event("cast_interrupted", id))
		bus.player_hit.connect(func(id, _t2, _a, crit, _p):
			if crit:
				_event("crit", id))
		bus.enemy_died.connect(func(_e): _event("kill", ""))
		bus.player_damaged.connect(func(_a): _event("damaged", ""))
		bus.player_avoided.connect(func(kind: String): _event(kind, ""))
		bus.rune_triggered.connect(func(id: String): _event("rune", id.trim_prefix("item:")))
		bus.item_looted.connect(func(id): _event("looted", id))
		bus.status_applied.connect(func(target, effect_name, _d, _s):
			if target != null and target.is_in_group("player"):
				_event("status_applied", "", str(effect_name)))
		bus.status_consumed.connect(func(target, effect_id, effect_name, _s):
			if target != null and target.is_in_group("player"):
				_event("status_consumed", str(effect_id), str(effect_name)))
		bus.level_up.connect(func(_l): _event("level_up", ""))
		bus.boss_engaged.connect(func(_b): _boss = true)
		bus.boss_defeated.connect(func(_b): _boss = false)
	var s := get_node_or_null("/root/Settings")
	if s and s.trackers.is_empty() and bool(s.ui_installed):
		ensure_defaults()
	rebuild.call_deferred()

## Remember an event (and its id-filtered form) with when it happened.
func _event(event: String, id: String, label := "") -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_events[event] = now
	var nm := label
	if nm == "" and id != "":
		nm = Trackers.AbilitiesScript.ability_name(id) if Trackers.AbilitiesScript.PATHS.has(id) else id.capitalize()
	if nm != "":
		_event_names[event] = nm
	if id != "":
		_events[Trackers.event_key(event, id)] = now
		_event_names[Trackers.event_key(event, id)] = nm
	_t = 0.0   # show it now, not at the next sweep

## The role layout's starting groups, when there are no trackers yet.
func ensure_defaults() -> void:
	var s := get_node_or_null("/root/Settings")
	if s == null or not s.trackers.is_empty():
		return
	for t in Trackers.default_groups(UIConfig.role()):
		s.trackers[t["id"]] = t
	s.save()
	rebuild()

## Make the displays again from Settings.trackers (after the editor changes them).
func rebuild() -> void:
	if _layer == null or not _layer.is_inside_tree():
		rebuild.call_deferred()
		return
	for d in _displays.values():
		d.queue_free()
	_displays.clear()
	var s := get_node_or_null("/root/Settings")
	if s == null:
		return
	# Groups first, so trackers can go into them.
	for id in s.trackers:
		var t: Dictionary = s.trackers[id]
		if str(t.get("kind")) == "group":
			var g := TrackerDisplay.new()
			g.setup(t)
			_layer.add_child(g)
			_displays[id] = g
			UILayout.register(get_tree(), g, "tracker:" + str(id), str(t["name"]), true)
	for id in s.trackers:
		var t: Dictionary = s.trackers[id]
		if str(t.get("kind")) == "group":
			continue
		var d := TrackerDisplay.new()
		d.setup(t)
		d.visible = false
		var parent: Node = _displays.get(str(t.get("group", "")))
		if parent != null:
			parent.add_child(d)
		else:
			_layer.add_child(d)
			UILayout.register(get_tree(), d, "tracker:" + str(id), str(t["name"]), true)
		_displays[id] = d
	_t = 0.0

func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = SWEEP
	sweep()

## What the triggers and load rules look at.
func context() -> Dictionary:
	var player: Node = hud.player if hud != null else get_tree().get_first_node_in_group("player")
	var target: Node = null
	if player != null and player.has_method("displayed_target"):
		var t = player.displayed_target()
		if t != null and is_instance_valid(t) and t.is_alive():
			target = t
	var frames := PartyFrames.of(get_tree())
	var party: Array = frames.members() if frames != null else ([player] if player else [])
	var net := get_node_or_null("/root/Net")
	var pd := get_node_or_null("/root/PlayerData")
	var spec := ""
	var role := "dps"
	if pd:
		role = Trackers.AbilitiesScript.role_of_bar(pd.action_bar)
		var specs := {}
		for id in pd.action_bar:
			var sp := Trackers.AbilitiesScript.spec_of(str(id))
			if sp != "":
				specs[sp] = int(specs.get(sp, 0)) + 1
		for sp in specs:
			if spec == "" or int(specs[sp]) > int(specs[spec]):
				spec = sp
	var scene := get_tree().current_scene
	return {"player": player, "target": target, "party": party, "events": _events, "event_names": _event_names,
		"now": Time.get_ticks_msec() / 1000.0, "player_data": pd, "spec": spec, "role": role,
		"combat": player != null and player.has_method("is_in_combat") and player.is_in_combat(),
		"in_party": net != null and net.with_others(), "boss": _boss,
		"in_dungeon": scene != null and scene.get("depth") != null}

func sweep() -> void:
	var s := get_node_or_null("/root/Settings")
	if s == null:
		return
	var ctx := context()
	for id in _displays:
		var d: TrackerDisplay = _displays[id]
		if d.is_group:
			continue
		var t: Dictionary = s.trackers.get(id, {})
		if t.is_empty() or d.preview:
			continue
		if not Trackers.loaded(t, ctx):
			if d.visible:
				d.show_state({"active": false}, {})
			continue
		var st := Trackers.eval_tracker(t, ctx)
		# A bar's fill by time needs the full time: the longest left seen this time it's up.
		var prev: Dictionary = d.st
		if bool(st.get("active", false)) and float(st.get("duration", 0.0)) <= 0.0 and float(st.get("time", 0.0)) > 0.0:
			st["duration"] = maxf(float(st["time"]), float(prev.get("duration", 0.0)) if bool(prev.get("active", false)) else 0.0)
		d.show_state(st, Trackers.apply_conditions(t, st))
	for id in _displays:
		var g: TrackerDisplay = _displays[id]
		if g.is_group:
			var kids: Array = []
			for c in g.get_children():
				if c is TrackerDisplay:
					kids.append(c)
			g.layout_group(kids)
			g.visible = bool(g.data.get("enabled", true))

## Editor preview: show a tracker with made-up values while you edit it.
func set_preview(id: String, on: bool) -> void:
	for k in _displays:
		var d: TrackerDisplay = _displays[k]
		d.preview = on and k == id
	_t = 0.0
	if on and _displays.has(id):
		var d: TrackerDisplay = _displays[id]
		d.show_state({"active": true, "name": str(d.data.get("name", "")), "stacks": 3, "time": 8.0, "duration": 12.0,
			"value": 60.0, "max": 100.0, "icon": "", "color": Color(0, 0, 0, 0)}, {})
