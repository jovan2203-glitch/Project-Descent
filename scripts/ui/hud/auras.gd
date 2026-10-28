extends HudElement

# Your buffs, or your debuffs (two elements: "buffs" and "debuffs"), as rows of
# icons with stacks, time left and tooltips. Size, icons per row, grow direction,
# sort order and time text come from UI Options > Auras.

const STATUS_ICONS = preload("res://scripts/ui/status_icons.gd")
const ROWS := 2

var debuffs := false
var _icons: HFlowContainer

static func make(show_debuffs: bool) -> HudElement:
	var e: HudElement = load("res://scripts/ui/hud/auras.gd").new()
	e.debuffs = show_debuffs
	e.key = "debuffs" if show_debuffs else "buffs"
	e.title = "Debuffs" if show_debuffs else "Buffs"
	e.always = true
	return e

func build() -> void:
	_icons = STATUS_ICONS.new()
	add_child(_icons)

func layout() -> void:
	if _icons == null:
		return
	var s := float(cfg("size"))
	var per_row := int(cfg("per_row"))
	_icons.set_icon_size(s)
	_icons.right_aligned = str(cfg("grow")) == "left"
	_icons.alignment = FlowContainer.ALIGNMENT_END if _icons.right_aligned else FlowContainer.ALIGNMENT_BEGIN
	_icons.sort_by = "time" if str(cfg("sort")) == "time" else "name"
	_icons.show_time = bool(cfg("show_time"))
	var w := per_row * (s + 3.0)
	set_box(Vector2(w, ROWS * (s + 14.0)))
	_icons.position = Vector2.ZERO
	_icons.size = Vector2(w, 0)
	_icons.custom_minimum_size = Vector2(w, 0)

func slow_update() -> void:
	if player == null or not visible:
		return
	var status: Node = player.get("status")
	var list: Array = status.list() if status else []
	_icons.show_effects(list.filter(func(e): return bool(e["debuff"]) == debuffs))
