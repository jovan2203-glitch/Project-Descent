extends RefCounted

# The Inspect window: a party member's gear (with runes), stats, abilities and
# talents, from the snapshot their game sent (Net.request_inspect ->
# Net.inspect_received). Opened by clicking a member's card in the main-menu
# lobby or right-clicking their party frame in game. Read only.
# The snapshot goes into a detached PlayerData (never in the tree, never saved),
# so stats, talent unlocks and the talent view work exactly as for you.
# Usage: const InspectWindow = preload("res://scripts/ui/inspect_window.gd")
#        InspectWindow.open(parent_control, member_id, data)

const UI = preload("res://scripts/ui_kit.gd")
const Stats = preload("res://scripts/core/stats.gd")
const Items = preload("res://scripts/items.gd")
const Runes = preload("res://scripts/runes.gd")
const Abilities = preload("res://scripts/abilities.gd")
const Macros = preload("res://scripts/core/macros.gd")
const PlayerDataScript = preload("res://scripts/player_data.gd")
const TalentView = preload("res://scripts/ui/talent_tree_view.gd")

const NAME := "InspectWindow"
const SLOT := 40.0
const TREE_HEIGHT := 520.0

## Opens (or replaces) the Inspect window under `parent` for `member`'s snapshot.
static func open(parent: Node, member: int, data: Dictionary) -> Control:
	close(parent)
	var pd: Node = PlayerDataScript.new()
	pd.apply_snapshot(data)
	var who := str(data.get("name", "?"))
	var win: PanelContainer
	win = UI.window("%s  •  Level %d" % [who, int(pd.level)], Vector2(0, 0), func(): close(parent), true)
	win.name = NAME
	win.set_meta("member", member)
	win.tree_exited.connect(func():
		Abilities.stat_override = {}
		pd.free())
	var content: VBoxContainer = win.get_meta("content")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	content.add_child(row)

	# Left: gear (runes are on the items' tooltips and listed under it), stats beside.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	var gear_row := HBoxContainer.new()
	gear_row.add_theme_constant_override("separation", 10)
	left.add_child(gear_row)
	var gear := UI.gear_layout(SLOT, 13, 8)
	gear_row.add_child(gear)
	for b in gear.find_children("*", "Button", true, false):
		if b.has_meta("slot_name"):
			UI.set_slot_item(b, str(pd.equipment.get(str(b.get_meta("slot_name")), "")), false, false)
	var stats := UI.stat_panel(205)
	stats.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	gear_row.add_child(stats)
	var totals: Dictionary = pd.total_stats()
	var values := {}
	for stat in Stats.ORDER:
		values[stat] = Stats.from_totals(stat, totals)
	UI.update_stat_panel(stats, values)
	left.add_child(_runes(pd))
	left.add_child(_abilities(pd, totals))

	# Right: their talents (the in-game Spellbook's view, reading their data).
	row.add_child(VSeparator.new())
	var talents: Control = TalentView.new()
	talents.data_source = pd
	talents.tree_height = TREE_HEIGHT
	row.add_child(talents)

	parent.add_child(win)
	# Centered on screen (a draggable window is placed by position).
	win.reset_size()
	win.position = ((win.get_viewport_rect().size - win.size) / 2.0).max(Vector2.ZERO)
	return win

## Closes the Inspect window under `parent`, if one is open.
static func close(parent: Node) -> void:
	var old := parent.get_node_or_null(NAME)
	if old:
		old.name = NAME + "_closing"
		old.queue_free()

static func is_open(parent: Node) -> bool:
	return parent.get_node_or_null(NAME) != null

## The runes on their equipped items.
static func _runes(pd: Node) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(UI.label("Runes", 15, UI.ACCENT))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 2)
	box.add_child(flow)
	for slot in pd.equipment:
		for r in Items.runes_of(str(pd.equipment[slot])):
			var l := UI.label("%s (%s)" % [Runes.rune_name(str(r)), slot], 13, Runes.color(str(r)))
			l.mouse_filter = Control.MOUSE_FILTER_STOP
			l.set_meta("tip_text", Runes.tooltip(str(r)))
			flow.add_child(l)
	if flow.get_child_count() == 0:
		flow.add_child(UI.label("None on their gear", 13, UI.TEXT_DIM))
	return box

## The abilities on their action bars (macros left out). Hovering one shows its
## tooltip with their stats (Abilities.stat_override).
static func _abilities(pd: Node, totals: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(UI.label("Abilities", 15, UI.ACCENT))
	var flow := HFlowContainer.new()
	flow.custom_minimum_size = Vector2(SLOT * 10.0, 0)
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	box.add_child(flow)
	var seen := {}
	for id in pd.action_bar:
		var a := str(id)
		if a == "" or Macros.is_macro(a) or seen.has(a):
			continue
		seen[a] = true
		var s := Abilities.make_slot(SLOT)
		Abilities.set_slot_ability(s, a)
		s.mouse_entered.connect(func(): Abilities.stat_override = totals)
		s.mouse_exited.connect(func(): Abilities.stat_override = {})
		flow.add_child(s)
	if seen.is_empty():
		flow.add_child(UI.label("Nothing on their bars", 13, UI.TEXT_DIM))
	return box
