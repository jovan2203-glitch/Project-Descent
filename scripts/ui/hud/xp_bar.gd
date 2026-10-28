extends HudElement

# A thin XP bar (under the action bars by default). Hidden at max level.

var _bar: HudBar

func _init() -> void:
	super()
	key = "xp_bar"
	title = "XP Bar"

func build() -> void:
	add_backdrop()
	_bar = HudBar.new()
	_bar.fill_color = Color(0.6, 0.35, 0.95)
	add_child(_bar)
	var bus := get_node_or_null("/root/SignalBus")
	if bus:
		bus.xp_changed.connect(func(_l, _x, _n): refresh_xp())

func layout() -> void:
	if _bar == null:
		return
	var w := float(cfg("width"))
	var h := float(cfg("height"))
	_bar.position = Vector2(1, 1)
	_bar.size = Vector2(w - 2, h)
	_bar.font_size = UISkin.font(10 if h >= 10 else 9)
	set_box(Vector2(w, h + 2))
	refresh_xp()

func wanted() -> bool:
	var pd := get_node_or_null("/root/PlayerData")
	return pd != null and pd.xp_to_next(pd.level) > 0   # at max level there is nothing left to earn

func refresh_xp() -> void:
	refresh_visible()
	var pd := get_node_or_null("/root/PlayerData")
	if pd == null or _bar == null or not visible:
		return
	var need: int = pd.xp_to_next(pd.level)
	_bar.set_fracs(float(pd.xp) / maxf(need, 1))
	var txt := "Level %d  •  %d / %d XP" % [pd.level, pd.xp, need] if bool(cfg("show_text")) and _bar.size.y >= 8 else ""
	_bar.set_texts("", txt)
