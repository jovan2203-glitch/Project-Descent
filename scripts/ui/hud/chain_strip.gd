extends HudElement

# The Chain (Martial tank: the Brawler): while the Brawler is out, the Chain's
# inputs so far (the same as the orbs on your back), empty cells for the ones
# still to come.

const CHAIN_CELL := 32.0

var _row: HBoxContainer
var _last := "-"

func _init() -> void:
	super()
	key = "chain"
	title = "Chain"

func build() -> void:
	add_backdrop()
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "Your Chain. The strike that ends it picks the move; three different strikes make the strong one."
	_row = HBoxContainer.new()
	_row.position = Vector2(4, 4)
	_row.add_theme_constant_override("separation", 3)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)

func layout() -> void:
	set_box(Vector2(8 + Balance.CHAIN_LENGTH * (CHAIN_CELL + 3) - 3, CHAIN_CELL + 8))

func wanted() -> bool:
	return player != null and player.get("brawler") != null and player.brawler.is_out()

func refresh() -> void:
	_last = "-"
	refresh_visible()

func slow_update() -> void:
	refresh_visible()

func update(_delta: float) -> void:
	if player == null:
		return
	var inputs: Array = player.brawler.chain()
	var k := ",".join(PackedStringArray(inputs))
	if k == _last:
		return
	_last = k
	for c in _row.get_children():
		c.queue_free()
	for i in Balance.CHAIN_LENGTH:
		var cell := Abilities.make_slot(CHAIN_CELL)
		cell.add_theme_stylebox_override("normal", UISkin.button_box())
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i < inputs.size():
			Abilities.set_slot_ability(cell, str(inputs[i]))
		else:
			cell.modulate.a = 0.35
		_row.add_child(cell)
