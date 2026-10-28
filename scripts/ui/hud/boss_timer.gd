extends HudElement

# The Boss Timer: during a 5 Player boss fight, the time left before the boss goes
# Berserk (boss_kit.gd), as a draining bar with the boss's name. Red for the last
# BERSERK_WARNING seconds, then "BERSERK" once it hits. Hidden otherwise.

var _bar: HudBar
var _boss: Node = null

func _init() -> void:
	super()
	key = "boss_timer"
	title = "Boss Timer"
	always = true
	tick_hidden = true

func build() -> void:
	add_backdrop()
	_bar = HudBar.new()
	add_child(_bar)

func layout() -> void:
	if _bar == null:
		return
	var w := float(cfg("width"))
	var h := float(cfg("height"))
	_bar.position = Vector2(1, 1)
	_bar.size = Vector2(w - 2, h)
	_bar.font_size = UISkin.font(12 if h >= 16 else 10)
	set_box(Vector2(w, h + 2))

func wanted() -> bool:
	return _boss != null

## A living boss whose Berserk timer is running (or has hit).
static func timed_boss(tree: SceneTree) -> Node:
	for e in tree.get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.get("rank") == "boss" and float(e.get("berserk_at")) > 0.0 and e.is_alive():
			return e
	return null

func slow_update() -> void:
	_boss = timed_boss(get_tree())
	refresh_visible()

func update(_delta: float) -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var total := maxf(float(_boss.berserk_total), 1.0)
	var left := maxf(float(_boss.berserk_at) - now, 0.0)
	var on: bool = _boss.berserk_on
	var nm := str(_boss.display_name) + "  " if bool(cfg("show_name")) else ""
	if on:
		_bar.fill_color = Color(0.85, 0.1, 0.08)
		_bar.set_fracs(1.0)
		_bar.set_texts(nm + "BERSERK")
		return
	_bar.fill_color = Color(0.9, 0.2, 0.12) if left <= Balance.BERSERK_WARNING else Color(0.95, 0.6, 0.2)
	_bar.set_fracs(left / total)
	_bar.set_texts(nm + "Berserk", "", "%d:%02d" % [int(left) / 60, int(left) % 60])
