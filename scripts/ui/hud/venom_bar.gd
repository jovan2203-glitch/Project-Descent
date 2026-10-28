extends HudElement

# Venom (Nature archer: Venomstring): a thin bar, shown only while Adder, Asp and
# Krait Arrow are all on the bars (macros count). It fills from the player's
# Venom (scripts/player/nature_venomstring.gd) and glows while Venom Flows.

const VENOM_ARROWS := ["adderarrow", "asparrow", "kraitarrow"]
const VENOM_COLOR := Color(0.4, 0.95, 0.3)
const W := 274.0
const H := 12.0

var _bar: HudBar
var _wanted := false

func _init() -> void:
	super()
	key = "venom"
	title = "Venom"

func build() -> void:
	add_backdrop()
	_bar = HudBar.new()
	_bar.position = Vector2(1, 1)
	_bar.size = Vector2(W - 2, H - 2)
	add_child(_bar)
	refresh()

func layout() -> void:
	set_box(Vector2(W, H))
	if _bar:
		_bar.font_size = UISkin.font(9)

func refresh() -> void:
	var ids := bar_ability_ids()
	_wanted = VENOM_ARROWS.all(func(a): return ids.has(a))
	refresh_visible()

func wanted() -> bool:
	return _wanted

func update(_delta: float) -> void:
	if player == null or not player.has_method("venom"):
		return
	var v: float = player.venom()
	var flowing: bool = player.venom_flow()
	_bar.set_fracs(v / Balance.VENOM_MAX)
	_bar.fill_color = VENOM_COLOR.lightened(0.25) if flowing else VENOM_COLOR.darkened(0.25)
	_bar.set_texts("", "Venom %d" % int(v))
