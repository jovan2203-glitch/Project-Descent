extends HudElement

# The target's cast bar on its own (Target > "Detach cast bar"). The target frame
# fills it (target_frame.gd: cast_bar()).

var _bar: HudBar

func _init() -> void:
	super()
	key = "target_cast"
	title = "Target Cast Bar"
	tick_hidden = true
	always = true

func build() -> void:
	add_backdrop()
	_bar = HudBar.new()
	_bar.fill_color = UISkin.ENEMY_CAST
	_bar.visible = false
	add_child(_bar)

func bar() -> HudBar:
	return _bar

func layout() -> void:
	if _bar == null:
		return
	var w := float(cfg("width"))
	var h := float(cfg("height"))
	_bar.position = Vector2(1, 1)
	_bar.size = Vector2(w - 2, h)
	_bar.font_size = UISkin.font(11 if h >= 14 else 9)
	set_box(Vector2(w, h + 2))

func enabled() -> bool:
	return super() and bool(UIConfig.value("target_frame", "cast_detached"))

func wanted() -> bool:
	return _bar != null and _bar.visible

func slow_update() -> void:
	refresh_visible()

func _on_config_changed(elem: String) -> void:
	if elem == "target_frame":
		apply_config()
	super(elem)

func update(_delta: float) -> void:
	refresh_visible()
