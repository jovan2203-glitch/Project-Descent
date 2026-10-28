extends "res://scripts/menu/menu_part.gd"
class_name LastRunPart

# The last-run card in the lobby (top right), shown once after you come back from
# a dungeon (GameManager.last_run): cleared or left early, time, bosses, enemies,
# XP, the loot that went to your bank, and the party's damage and healing for the
# whole run. ✕ dismisses it.

const CLEARED_COL := Color(0.45, 0.95, 0.5)
const LEFT_COL := Color(1.0, 0.7, 0.4)
const DMG_COL := Color(0.95, 0.55, 0.3)
const HEAL_COL := Color(0.45, 0.9, 0.5)
const MAX_LOOT := 12

var _card: PanelContainer

func _gm() -> Node:
	return menu.get_node("/root/GameManager")

func build() -> void:
	var run: Dictionary = _gm().last_run
	if run.is_empty():
		return
	_card = PanelContainer.new()
	_card.anchor_left = 1.0
	_card.anchor_right = 1.0
	_card.offset_left = -376
	_card.offset_right = -16
	_card.offset_top = 52
	_card.add_theme_stylebox_override("panel", menu._padded(UI.box(Color(0.05, 0.055, 0.075, 0.94), MainMenu.C_BORDER, 2, 10), 12))
	menu.pages["Lobby"].add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_card.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var title := UI.label("Last run: %s" % str(run["title"]), 16, MainMenu.C_ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	head.add_child(title)
	var close := UI.button("✕", 12, Vector2(26, 24))
	close.tooltip_text = "Dismiss"
	close.pressed.connect(dismiss)
	head.add_child(close)

	var cleared := bool(run["cleared"])
	var secs := int(run["time"])
	var status := UI.label("%s  •  %s  •  %d:%02d%s" % ["Cleared" if cleared else "Left early",
		_gm().difficulty_label(str(run["diff"])), secs / 60, secs % 60, "  (new best!)" if run["best"] else ""],
		13, CLEARED_COL if cleared else LEFT_COL)
	v.add_child(status)
	var xp := "%d XP" % int(run["xp"])
	if int(run["levels"]) > 0:
		xp += "  (+%d level%s)" % [int(run["levels"]), "" if int(run["levels"]) == 1 else "s"]
	v.add_child(UI.label("Bosses: %d   •   Enemies: %d   •   %s" % [int(run["bosses"]), int(run["kills"]), xp], 13, Color(0.88, 0.88, 0.9)))

	var loot: Array = run["loot"]
	if not loot.is_empty():
		v.add_child(UI.label("Loot (in your bank)", 13, MainMenu.C_TEXT_DIM))
		var grid := HFlowContainer.new()
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		v.add_child(grid)
		for i in mini(loot.size(), MAX_LOOT):
			var s := UI.slot(36, "")
			UI.set_slot_item(s, str(loot[i]))
			grid.add_child(s)
		if loot.size() > MAX_LOOT:
			grid.add_child(UI.label("+%d" % (loot.size() - MAX_LOOT), 13, MainMenu.C_TEXT_DIM))

	var party: Array = run["party"]
	if not party.is_empty():
		v.add_child(UI.label("Damage / healing (whole run)", 13, MainMenu.C_TEXT_DIM))
		var top := 1
		for p in party:
			top = maxi(top, maxi(int(p["damage"]), int(p["healing"])))
		for p in party:
			v.add_child(_party_row(p, top))

func _party_row(p: Dictionary, top: int) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	var line := HBoxContainer.new()
	row.add_child(line)
	var n := UI.label(str(p["name"]), 13, Color.WHITE)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	line.add_child(n)
	line.add_child(UI.label(_short(int(p["damage"])), 13, DMG_COL))
	if int(p["healing"]) > 0:
		line.add_child(UI.label("   " + _short(int(p["healing"])), 13, HEAL_COL))
	for pair in [[int(p["damage"]), DMG_COL], [int(p["healing"]), HEAL_COL]]:
		if int(pair[0]) <= 0:
			continue
		var bar := ColorRect.new()
		bar.color = pair[1].darkened(0.2)
		bar.custom_minimum_size = Vector2(maxf(2.0, 330.0 * float(pair[0]) / float(top)), 4)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		row.add_child(bar)
	return row

static func _short(n: int) -> String:
	if n >= 1000000:
		return "%.1fM" % (n / 1000000.0)
	if n >= 10000:
		return "%.0fk" % (n / 1000.0)
	if n >= 1000:
		return "%.1fk" % (n / 1000.0)
	return str(n)

func dismiss() -> void:
	_gm().last_run = {}
	if _card:
		_card.queue_free()
		_card = null
