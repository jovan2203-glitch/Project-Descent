extends HFlowContainer


# A row of small buff / debuff icons with mouse-over tooltips. Used by the
# player's buff bar (top right), the target frame and the boss bar.
#   var icons := preload("res://scripts/ui/status_icons.gd").new()
#   icons.show_effects(some_node.get_node("Status").list())
# Buffs come first (green border), then debuffs (red border). An effect's
# `icon` texture is used when it has one, otherwise its initials on its color.

const UI = preload("res://scripts/ui_kit.gd")

@export var icon_size := 26.0
## Grow from the right edge (the player's bar sits left of the minimap).
@export var right_aligned := false
## Order: "type" (buffs first, then debuffs, by name) or "time" (least time left first).
var sort_by := "type"
## Show the time left under each icon.
var show_time := true

const BUFF_BORDER := Color(0.35, 0.9, 0.4)
const DEBUFF_BORDER := Color(1.0, 0.3, 0.25)

func _ready() -> void:
	add_theme_constant_override("h_separation", 3)
	add_theme_constant_override("v_separation", 3)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if right_aligned:
		alignment = FlowContainer.ALIGNMENT_END

## `effects`: StatusContainer.list() rows ({id, name, color, stacks, remaining, debuff, desc, absorb}).
func show_effects(effects: Array) -> void:
	var list := effects.duplicate()
	list.sort_custom(func(a, b):
		if sort_by == "time":
			var la := float(a["remaining"]) if float(a["remaining"]) > 0.0 else 1e9
			var lb := float(b["remaining"]) if float(b["remaining"]) > 0.0 else 1e9
			if la != lb:
				return la < lb
		elif bool(a["debuff"]) != bool(b["debuff"]):
			return not bool(a["debuff"])
		return str(a["name"]) < str(b["name"]))
	# The same effect from several casters (DoTs) shows once, with a count.
	var merged: Array = []
	var seen := {}
	for e in list:
		var key := str(e["id"])
		if seen.has(key):
			var m: Dictionary = merged[seen[key]]
			m["copies"] = int(m["copies"]) + 1
			if bool(e.get("amount", false)):
				# An amount (Decay): each player has their own. Show mine, not an ally's.
				if bool(e.get("mine", false)) and not bool(m.get("mine", false)):
					m["stacks"] = e["stacks"]
					m["remaining"] = e["remaining"]
					m["mine"] = true
				continue
			m["remaining"] = maxf(float(m["remaining"]), float(e["remaining"]))
			continue
		var c: Dictionary = e.duplicate()
		c["copies"] = 1
		seen[key] = merged.size()
		merged.append(c)
	while get_child_count() < merged.size():
		add_child(_make_icon())
	for i in get_child_count():
		var icon: Control = get_child(i)
		icon.visible = i < merged.size()
		if i < merged.size():
			_fill(icon, merged[i])

func _make_icon() -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(icon_size, icon_size + 11)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var box := Panel.new()
	box.name = "Box"
	box.position = Vector2.ZERO
	box.size = Vector2(icon_size, icon_size)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	var tex := TextureRect.new()
	tex.name = "Tex"
	tex.position = Vector2(1, 1)
	tex.size = Vector2(icon_size - 2, icon_size - 2)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tex)
	var abbr := _small_label(int(icon_size * 0.42))
	abbr.name = "Abbr"
	abbr.size = Vector2(icon_size, icon_size)
	abbr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	abbr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(abbr)
	var stacks := _small_label(int(icon_size * 0.38))
	stacks.name = "Stacks"
	stacks.size = Vector2(icon_size - 2, icon_size)
	stacks.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stacks.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	box.add_child(stacks)
	var time := _small_label(10)
	time.name = "Time"
	time.position = Vector2(-6, icon_size - 1)
	time.size = Vector2(icon_size + 12, 12)
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(time)
	return root

static func _small_label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## An amount in the little room an icon has: "850", "1.2k", "34k", "1.5m".
static func compact(n: int) -> String:
	if n < 1000:
		return str(maxi(n, 0))
	if n < 10000:
		return "%.1fk" % (n / 1000.0)
	if n < 1000000:
		return "%dk" % int(n / 1000.0)
	return "%.1fm" % (n / 1000000.0)

static func _initials(name: String) -> String:
	var words := name.split(" ", false)
	if words.size() >= 2:
		return (words[0].substr(0, 1) + words[1].substr(0, 1)).to_upper()
	return name.substr(0, 2)

func _fill(p: Control, e: Dictionary) -> void:
	var debuff := bool(e["debuff"])
	var col: Color = e.get("color", Color.WHITE)
	var key := "%s|%s" % [e["id"], debuff]
	if p.get_meta("key", "") != key:
		p.set_meta("key", key)
		var sb := StyleBoxFlat.new()
		sb.bg_color = col.darkened(0.55)
		sb.border_color = DEBUFF_BORDER if debuff else BUFF_BORDER
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(0)
		sb.shadow_color = Color.BLACK
		sb.shadow_size = 1
		sb.anti_aliasing = false
		(p.get_node("Box") as Panel).add_theme_stylebox_override("panel", sb)
		var icon_tex: Texture2D = e.get("icon")
		(p.get_node("Box/Tex") as TextureRect).texture = icon_tex
		var abbr: Label = p.get_node("Box/Abbr")
		abbr.text = "" if icon_tex else _initials(str(e["name"]))
		abbr.add_theme_color_override("font_color", col.lightened(0.45))
	var stacks := int(e["stacks"])
	var copies := int(e.get("copies", 1))
	# (An effect whose stack count is an amount of damage shows that number: Decay.)
	var is_amount := bool(e.get("amount", false))
	var count := str(stacks) if stacks > 1 else (str(copies) if copies > 1 else "")
	(p.get_node("Box/Stacks") as Label).text = compact(stacks) if is_amount else count
	# (One that lasts until something ends it has no clock: a closed Decay.)
	var left := 0.0 if bool(e.get("timeless", false)) else float(e["remaining"])
	(p.get_node("Time") as Label).text = "" if not show_time else ("%dm" % ceili(left / 60.0)) if left >= 60.0 else ("%d" % ceili(left) if left > 0.0 else "")
	var tip := str(e["name"])
	if is_amount:
		tip += "  (%d damage left)" % stacks
	elif stacks > 1:
		tip += "  (%d stacks)" % stacks
	if copies > 1:
		tip += "  (x%d)" % copies
	tip += "\n" + ("Debuff" if debuff else "Buff")
	var desc := str(e.get("desc", ""))
	if desc != "":
		tip += "\n" + desc
	var absorb := int(e.get("absorb", 0))
	if absorb > 0:
		tip += "\nAbsorbs %d more damage" % absorb
	if left > 0.0:
		tip += "\n%d s remaining" % ceili(left)
	if bool(UIConfig.value("general", "show_ids")):
		tip += "\nID: %s" % e["id"]
	if p.tooltip_text != tip:
		p.tooltip_text = tip

## A new icon size: the icons are made again at the next show_effects.
func set_icon_size(s: float) -> void:
	if is_equal_approx(s, icon_size):
		return
	icon_size = s
	for c in get_children():
		c.queue_free()
		remove_child(c)
