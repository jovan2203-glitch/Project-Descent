extends Control
class_name InfoStrip

# A thin strip under a panel holding up to three info texts (UIConfig.INFO_TEXTS):
# FPS, ping, time, level / XP, bag space, combat time, your DPS / HPS. Its left
# end can hold buttons (the chat panel's micro menu). Texts refresh once a second.

const H := 20.0

## The panel element whose options pick the texts ("chat_panel" / "meter_panel").
var elem := ""
var buttons: HBoxContainer
var _labels: Array[Label] = []
var _shown: Array[Label] = []   # the texts picked in its options
var _left := 0.0
var _t := 0.0
static var _combat_start := -1.0
static var _combat_last := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 1)
	buttons.position = Vector2(1, 1)
	add_child(buttons)
	for i in 3:
		var l := UISkin.label("", 11)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(l)
		_labels.append(l)

func _ready() -> void:
	var bus := get_node_or_null("/root/SignalBus")
	if bus and not bus.combat_state_changed.is_connected(_on_combat):
		bus.combat_state_changed.connect(_on_combat)
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", UISkin.backdrop())
	add_child(bg)
	move_child(bg, 0)

static func _on_combat(on: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if on:
		_combat_start = now
	elif _combat_start >= 0.0:
		_combat_last = now - _combat_start
		_combat_start = -1.0

## Lay the texts out in the room right of the buttons.
func layout() -> void:
	_left = buttons.get_combined_minimum_size().x + 4.0 if buttons.get_child_count() > 0 else 0.0
	_shown.clear()
	for i in 3:
		_labels[i].visible = false
		if str(UIConfig.value(elem, "info_%d" % (i + 1))) != "none":
			_shown.append(_labels[i])
			_labels[i].add_theme_font_size_override("font_size", UISkin.font(11))
	_fit()
	_t = 0.0

## Share the room among the texts; ones that don't fit (a narrow panel next to
## the micro menu) are left out, last first, instead of running into each other.
func _fit() -> void:
	var room := size.x - _left
	var fits := _shown.duplicate()
	while not fits.is_empty():
		var need := 0.0
		for l in fits:
			need += _text_width(l) + 10.0
		if need <= room:
			break
		fits.pop_back()
	var w := room / maxf(fits.size(), 1)
	for l in _shown:
		l.visible = fits.has(l)
	for i in fits.size():
		fits[i].position = Vector2(_left + i * w, 0)
		fits[i].size = Vector2(w, H)

static func _text_width(l: Label) -> float:
	return l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		l.get_theme_font_size("font_size")).x

func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	var changed := false
	for i in 3:
		if _shown.has(_labels[i]):
			var t := text_of(str(UIConfig.value(elem, "info_%d" % (i + 1))))
			if _labels[i].text != t:
				changed = changed or t.length() != _labels[i].text.length()
				_labels[i].text = t
	if changed:
		_fit()

## The text an info slot shows right now.
func text_of(kind: String) -> String:
	match kind:
		"fps":
			return "%d fps" % Engine.get_frames_per_second()
		"ping":
			var net := get_node_or_null("/root/Net")
			if net == null or not bool(net.online) or (net.ping as Dictionary).is_empty():
				return "— ms"
			var worst := 0
			for v in (net.ping as Dictionary).values():
				worst = maxi(worst, int(v))
			return "%d ms" % worst
		"time":
			var t := Time.get_time_dict_from_system()
			return "%02d:%02d" % [int(t["hour"]), int(t["minute"])]
		"xp":
			var pd := get_node_or_null("/root/PlayerData")
			if pd == null:
				return ""
			var need: int = pd.xp_to_next(pd.level)
			return "Lv %d" % pd.level if need <= 0 else "Lv %d  %d%%" % [pd.level, int(100.0 * pd.xp / maxf(need, 1))]
		"bags":
			var pd := get_node_or_null("/root/PlayerData")
			if pd == null:
				return ""
			var free := 0
			for s in pd.inventory:
				if str(s) == "":
					free += 1
			return "Bags %d/%d" % [free, pd.inventory.size()]
		"combat":
			var secs := (Time.get_ticks_msec() / 1000.0 - _combat_start) if _combat_start >= 0.0 else _combat_last
			return "%d:%02d" % [int(secs) / 60, int(secs) % 60]
		"dps", "hps":
			var d := get_node_or_null("/root/Details")
			if d == null:
				return ""
			var seg: Dictionary = d.shown_segment()
			var per := 0.0
			if not seg.is_empty() and (seg["players"] as Dictionary).has(d.my_key()):
				per = d.player_total(seg["players"][d.my_key()], "damage" if kind == "dps" else "healing") / d.duration(seg)
			return "%s %s" % [kind.to_upper(), d.fmt(per)]
	return ""
