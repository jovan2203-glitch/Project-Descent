extends HudElement

# The engine (Martial archer: Sharpshooter): while the Sharpshooter is out, its
# five shots in the order they feed each other, each with its cooldown (or
# Overcut, gold) under it, and above it what the shots that are ready right now
# would take off it if they hit (blue: it comes back sooner; gold: it's ready, so
# that time would become Overcut).

const SHARP_CELL := 32.0
const SHARP_BLUE := Color(0.42, 0.72, 1.0)
const SHARP_GOLD := Color(1.0, 0.83, 0.3)

var _row: HBoxContainer
var _cells := {}   # shot id -> {"cell", "under", "over"}

func _init() -> void:
	super()
	key = "sharpshooter"
	title = "Sharpshooter"

func build() -> void:
	add_backdrop()
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "Your shots, in the order they feed each other. Above a shot: what your ready shots would take off it. Gold: Overcut."
	_row = HBoxContainer.new()
	_row.position = Vector2(4, 2)
	_row.add_theme_constant_override("separation", 3)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)

func layout() -> void:
	if size == Vector2.ZERO:
		set_box(Vector2(260, SHARP_CELL + 32))

func wanted() -> bool:
	return player != null and player.get("sharp") != null and player.sharp.is_out()

func slow_update() -> void:
	var was := visible
	refresh_visible()
	if visible and not was:
		refresh()

func refresh() -> void:
	refresh_visible()
	if not visible:
		return
	for c in _row.get_children():
		c.queue_free()
	_cells.clear()
	var pd := get_node_or_null("/root/PlayerData")
	var first := true
	var w := 8.0
	for id in Abilities.SHARP_ENGINE:
		if pd and not pd.has_ability(id):
			continue
		if not first:
			var arrow := UISkin.label("+" if id == "followup" else "›", 12, UISkin.DIM)
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_row.add_child(arrow)
			w += 14.0
		first = false
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var over := _small_label()
		var cell := Abilities.make_slot(SHARP_CELL)
		cell.add_theme_stylebox_override("normal", UISkin.button_box())
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Abilities.set_slot_ability(cell, id)
		var under := _small_label()
		col.add_child(over)
		col.add_child(cell)
		col.add_child(under)
		_row.add_child(col)
		_cells[id] = {"cell": cell, "under": under, "over": over}
		w += SHARP_CELL + 3.0
	set_box(Vector2(w, SHARP_CELL + 32))

func _small_label() -> Label:
	var l := UISkin.label("", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(SHARP_CELL, 14)
	return l

func update(_delta: float) -> void:
	if player == null:
		return
	var incoming := {}   # shot -> seconds the ready shots would take off it
	for src in _cells:
		if player.cooldown_left(src) > 0.0:
			continue
		var cuts: Dictionary = player.sharp.cut_preview(src)
		for t in cuts:
			if t != src:
				incoming[t] = float(incoming.get(t, 0.0)) + float(cuts[t])
	for id in _cells:
		var parts: Dictionary = _cells[id]
		var left: float = float(player.cooldowns.get(id, 0.0))
		var overcut: float = player.sharp.overcut_of(id)
		var under: Label = parts["under"]
		var under_text := "+%d%%" % int(round(SharpshooterKit.overcut_bonus(overcut, player.sharp.overcut_per()))) if overcut > 0.0 \
			else ("%.0f" % ceilf(left) if left > 0.0 else "")
		if under.text != under_text:
			under.text = under_text
			under.add_theme_color_override("font_color", SHARP_GOLD if overcut > 0.0 else Color.WHITE)
		var over: Label = parts["over"]
		var cut: float = float(incoming.get(id, 0.0))
		var over_text := "-%.1f" % cut if cut > 0.0 else ""
		if over.text != over_text:
			over.text = over_text
		var over_gold := left <= cut
		if bool(over.get_meta("gold", false)) != over_gold or not over.has_meta("gold"):
			over.set_meta("gold", over_gold)
			over.add_theme_color_override("font_color", SHARP_GOLD if over_gold else SHARP_BLUE)
		var a := 1.0 if left <= 0.0 else 0.5
		if (parts["cell"] as Control).modulate.a != a:
			(parts["cell"] as Control).modulate.a = a
