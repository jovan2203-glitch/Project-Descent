extends HudElement

# Your cast bar: the spell's icon, a bar in its school's colour (Frost blue, Fire
# orange...) with a spark on its edge, its name and time left. A white flash when
# it goes off, red "Interrupted" when it doesn't. Channels drain from full.

const Categories = preload("res://scripts/categories.gd")

var _bar: HudBar
var _icon: Control
var _was_casting := false
var _hide_timer := 0.0
var _ok := true

func _init() -> void:
	super()
	key = "cast_bar"
	title = "Cast Bar"
	always = true
	tick_hidden = true

func build() -> void:
	add_backdrop()
	_icon = Control.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.draw.connect(func(): Abilities.draw_icon(_icon, str(_icon.get_meta("id", ""))))
	add_child(_icon)
	_bar = HudBar.new()
	add_child(_bar)

func layout() -> void:
	if _bar == null:
		return
	var w := float(cfg("width"))
	var h := float(cfg("height"))
	var icon := bool(cfg("icon"))
	_icon.visible = icon
	_icon.position = Vector2(1, 1)
	_icon.size = Vector2(h, h)
	var x := h + 2.0 if icon else 1.0
	_bar.position = Vector2(x, 1)
	_bar.size = Vector2(w - x - 1, h)
	_bar.font_size = UISkin.font(12 if h >= 18 else 10)
	set_box(Vector2(w, h + 2))

func wanted() -> bool:
	return player != null and (player.casting or _hide_timer > 0.0)

func update(delta: float) -> void:
	if player == null:
		return
	if player.casting:
		var total: float = maxf(player.cast_duration, 0.001)
		var remaining: float = maxf(player.cast_timer, 0.0)
		var progress := remaining / total if player.cast_is_channel else 1.0 - remaining / total
		var id := str(player.current_spell)
		if str(_icon.get_meta("id", "")) != id:
			_icon.set_meta("id", id)
			_icon.queue_redraw()
		_bar.fill_color = school_color(id)
		_bar.spark = bool(cfg("spark"))
		_bar.set_fracs(progress)
		_bar.set_texts(str(player.cast_name), "", "%.1f" % remaining if bool(cfg("show_time")) else "")
		_was_casting = true
		_hide_timer = 0.0
		modulate_bar(1.0)
		refresh_visible()
		return
	if _was_casting:
		_was_casting = false
		_bar.spark = false
		if player.cast_timer <= 0.0:
			# Went off: a full bar flashing white as it fades (channels end empty).
			_ok = true
			_bar.set_fracs(0.0 if player.cast_is_channel else 1.0)
			_bar.set_texts(_bar.text_left)
			_hide_timer = 0.3
		else:
			_ok = false
			_bar.fill_color = UISkin.CAST_FAIL
			_bar.set_fracs(1.0)
			_bar.set_texts("Interrupted")
			_hide_timer = 0.6
	if _hide_timer > 0.0:
		_hide_timer -= delta
		if _ok:
			_bar.fill_color = _bar.fill_color.lerp(Color.WHITE, 0.35)
		modulate_bar(clampf(_hide_timer / 0.25, 0.0, 1.0))
	refresh_visible()

## Fades the bar itself (the element's own alpha is its Opacity option).
func modulate_bar(a: float) -> void:
	if _bar.modulate.a != a:
		for c in get_children():
			(c as CanvasItem).modulate.a = a

## A spell's school colour (Frost blue, Fire orange...).
static func school_color(spell: String) -> Color:
	var cat := Abilities.category_of(spell)
	return Categories.color(cat).lightened(0.15) if cat != "" else UISkin.CAST
