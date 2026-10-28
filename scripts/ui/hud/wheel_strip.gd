extends HudElement

# The Wheel (Martial warrior): while the Wheel is out (one of its buttons is on the
# bars), its weapons in the order they turn, the held one large, with its uses left
# and Cracks. Out of combat, clicking it turns the Wheel to the next weapon.

const WHEEL_CELL := 30.0
const WHEEL_HELD := 40.0

var _row: HBoxContainer
var _label: Label
var _last := ""

func _init() -> void:
	super()
	key = "wheel"
	title = "Wheel"

func build() -> void:
	add_backdrop()
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Your Wheel. Out of combat, click it to turn it to the next weapon."
	gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_turn_wheel())
	var box := HBoxContainer.new()
	box.position = Vector2(4, 4)
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 3)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_row)
	_label = UISkin.label("", 11)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(_label)

func layout() -> void:
	set_box(Vector2(260, WHEEL_HELD + 8))

func wanted() -> bool:
	return player != null and player.get("wheel") != null and player.wheel.is_out()

func refresh() -> void:
	_last = ""
	refresh_visible()

func slow_update() -> void:
	refresh_visible()

func _turn_wheel() -> void:
	if player == null or player.get("wheel") == null:
		return
	if not player.wheel.turn_out_of_combat():
		player._error("The Wheel only turns out of combat")

func update(_delta: float) -> void:
	if player == null:
		return
	var ws: Array = player.wheel.weapons()
	var held: String = player.wheel.held_weapon()
	var k := "%s|%s|%d|%d" % [",".join(PackedStringArray(ws)), held, player.wheel.uses_left(), player.wheel.cracks()]
	if k == _last:
		return
	_last = k
	for c in _row.get_children():
		c.queue_free()
	# The held weapon first, then the rest in the order they will come.
	var start := maxi(ws.find(held), 0)
	for i in ws.size():
		var w := str(ws[(start + i) % ws.size()])
		var cell := Abilities.make_slot(WHEEL_HELD if i == 0 else WHEEL_CELL)
		cell.add_theme_stylebox_override("normal", UISkin.button_box())
		cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		Abilities.set_slot_ability(cell, w)
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.pressed.connect(_turn_wheel)
		if i > 0:
			cell.modulate.a = 0.85 if i == 1 else 0.55
		_row.add_child(cell)
	_label.text = "%d / %d uses\n%d Cracks" % [player.wheel.uses_left(), Balance.WHEEL_USES, player.wheel.cracks()]
	var w_total := WHEEL_HELD + (ws.size() - 1) * (WHEEL_CELL + 3) + 8 + 90
	set_box(Vector2(w_total, WHEEL_HELD + 8))
