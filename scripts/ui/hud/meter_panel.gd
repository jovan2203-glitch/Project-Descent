extends HudElement

# The bottom-right panel: the damage meter docked in it (Details.dock_into), an
# info strip with up to three texts under it. "Dock the damage meter" off: the
# meter floats where you drag it, and the panel shows only its strip.

var _holder: Control
var strip: InfoStrip

func _init() -> void:
	super()
	key = "meter_panel"
	mover_key = "meter"
	title = "Meter"

func build() -> void:
	_holder = Control.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	strip = InfoStrip.new()
	strip.elem = key
	add_child(strip)

func _exit_tree() -> void:
	var d := get_node_or_null("/root/Details")
	if d and d.has_method("undock"):
		d.undock()   # (the meter belongs to Details: it must outlive this scene)

func _docked() -> bool:
	return bool(cfg("docked")) and enabled()

func layout() -> void:
	if _holder == null:
		return
	var w := float(cfg("width"))
	var d := get_node_or_null("/root/Details")
	var docked := _docked() and d != null
	var h := 0.0
	if docked:
		d.dock_into(_holder)
		h = maxf(float(cfg("height")), d.meter_min_height())
	elif d:
		d.undock()
	_holder.visible = docked
	_holder.size = Vector2(w, h)
	var show_strip := bool(cfg("info_strip"))
	strip.visible = show_strip
	strip.position = Vector2(0, h + 2 if docked else 0.0)
	strip.size = Vector2(w, InfoStrip.H)
	strip.layout()
	set_box(Vector2(w, (h + 2 if docked else 0.0) + (InfoStrip.H if show_strip else 0.0)))

func slow_update() -> void:
	var d := get_node_or_null("/root/Details")
	if d == null:
		return
	# The meter hidden (K, or the bar button): the panel goes with it.
	var meter_on: bool = d.meter_enabled
	if _holder.visible != (meter_on and _docked()):
		_holder.visible = meter_on and _docked()
	# More players in the fight: the meter needs more room (and less after a reset).
	if _holder.visible and not is_equal_approx(_holder.size.y, maxf(float(cfg("height")), d.meter_min_height())):
		layout()
