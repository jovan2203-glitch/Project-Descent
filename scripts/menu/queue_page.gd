extends "res://scripts/menu/menu_part.gd"
class_name QueuePage

# Queue (the Play screen): pick a dungeon and go in. "Random Dungeon" is the real
# queue: you (and your party) get sent into a random dungeon from the pool. Below it
# every dungeon can be joined on its own - for testing. Enemy level = the group's
# average pulled toward its highest level.

var _instances: Array = []
const QUEUE_ROWS := [["Queue", "Dungeon Finder"], ["Test", "Join a specific dungeon (testing)"], ["Raid", "Raids"]]

func _build_instances() -> void:
	_instances = [{"name": DB.title(DB.RANDOM_KEY), "kind": "Queue", "players": "1-5 players", "available": true,
		"key": DB.RANDOM_KEY, "desc": DB.description(DB.RANDOM_KEY), "difficulty": true}]
	for r in DB.recipes():
		_instances.append({"name": DB.title(str(r.id)), "kind": "Test", "players": "1-5 players", "available": true,
			"key": DB.key_for(str(r.id)), "difficulty": true,
			"desc": DB.description(str(r.id)) + ("" if r.in_random_pool else "\n(Not in the random pool.)")})
	for l in DB.LEGACY:
		_instances.append({"name": DB.title(str(l["id"])), "kind": "Test", "players": "1-5 players", "available": true,
			"key": DB.key_for(str(l["id"])), "difficulty": true, "desc": DB.description(str(l["id"]))})
	_instances.append({"name": "Crypt of Bones", "kind": "Raid", "players": "10 players", "available": false,
		"key": "", "desc": "An ancient tomb and its undying king. Coming soon."})

var _queue_selected := 0
var _queue_cards: Array[Button] = []
var _queue_enter: Button
var _queue_info: Label

func _build_queue_page() -> Control:
	_build_instances()
	var page := menu._full_rect_page()
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 40
	panel.offset_right = -40
	panel.offset_top = 52
	panel.offset_bottom = -20
	panel.add_theme_stylebox_override("panel", menu._padded(UI.box(Color(0.05, 0.055, 0.075, 0.96), MainMenu.C_BORDER, 2, 10), 16))
	page.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var head := HBoxContainer.new()
	var back := UI.button("←  Back", 16, Vector2(110, 36))
	back.tooltip_text = "Back to the lobby (Esc)"
	back.pressed.connect(menu._show_page.bind("Lobby"))
	head.add_child(back)
	var title := UI.label("   Play", 22, MainMenu.C_ACCENT)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title)
	var head_gap := Control.new()
	head_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_gap)
	# Training Room: solo practice area with dummies (DPS, AoE, healing, tanking).
	var training := UI.button("Training Room", 16, Vector2(170, 36))
	training.tooltip_text = "Practice alone: DPS dummies (single + group of 5), ally dummies to heal,\na tank dummy and a pack that hit back, and a damage / healing meter.\nNo XP, no loot and no death penalty."
	training.pressed.connect(func(): menu.get_node("/root/GameManager").start_training())
	head.add_child(training)
	v.add_child(head)

	# Everything between the header and the Queue / Enter Now row scrolls, so those
	# buttons stay pinned at the bottom of the panel at any resolution.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	for row_info in QUEUE_ROWS:
		body.add_child(UI.label(str(row_info[1]), 16, Color.WHITE))
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 12)
		row.add_theme_constant_override("v_separation", 12)
		body.add_child(row)
		for i in _instances.size():
			if _instances[i]["kind"] == row_info[0]:
				row.add_child(_instance_card(i))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	# Difficulty: sits right above Queue / Enter Now.
	_diff_box = VBoxContainer.new()
	_diff_box.add_theme_constant_override("separation", 6)
	_diff_box.visible = false
	body.add_child(_diff_box)
	_diff_box.add_child(UI.label("Difficulty", 16, Color.WHITE))
	_diff_row = HBoxContainer.new()
	_diff_row.add_theme_constant_override("separation", 8)
	_diff_box.add_child(_diff_row)
	_diff_hint = UI.label("", 13, MainMenu.C_TEXT_DIM)
	_diff_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diff_box.add_child(_diff_hint)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	v.add_child(bottom)
	_queue_info = UI.label("Select a dungeon.", 15, MainMenu.C_TEXT_DIM)
	_queue_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_queue_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_queue_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(_queue_info)
	# Queue: fill the group up to 5 with random players (a full party goes straight in).
	_queue_btn = UI.button("Queue", 22, Vector2(200, 56))
	_queue_btn.disabled = true
	_queue_btn.tooltip_text = "Find a group: you're matched with other players queueing for the same thing.\nA full party of 5 goes straight in."
	_queue_btn.pressed.connect(_toggle_queue)
	bottom.add_child(_queue_btn)
	_queue_enter = UI.button("Enter Now", 22, Vector2(200, 56))
	_queue_enter.add_theme_stylebox_override("normal", UI.box(MainMenu.C_ACCENT, Color(1, 0.9, 0.6), 2, 8))
	_queue_enter.add_theme_stylebox_override("hover", UI.box(MainMenu.C_ACCENT.lightened(0.15), Color(1, 0.95, 0.75), 2, 8))
	_queue_enter.add_theme_stylebox_override("disabled", UI.box(Color(0.2, 0.2, 0.22), MainMenu.C_BORDER, 2, 8))
	_queue_enter.add_theme_color_override("font_color", Color(0.1, 0.07, 0.03))
	_queue_enter.add_theme_color_override("font_hover_color", Color(0.1, 0.07, 0.03))
	_queue_enter.disabled = true
	_queue_enter.tooltip_text = "Go in right now with your current party (or solo)."
	_queue_enter.pressed.connect(_enter_instance)
	bottom.add_child(_queue_enter)
	_refresh_queue.call_deferred()
	return page

var _queue_btn: Button
var _diff_box: VBoxContainer
var _diff_row: HBoxContainer
var _diff_hint: Label
var _difficulty := "solo"
const DIFFICULTY_INFO := {
	"solo": "The normal game. Beatable on your own with any role.",
	"party": "Built for a group of 5. Enemies hit far harder and have more health: the tank has to use his defensive abilities to survive, big pulls are impossible without a healer, and archers and casters sometimes shoot someone other than the tank.",
}

## Difficulty the chosen instance will run on.
func _selected_difficulty() -> String:
	if _queue_selected < 0 or not _instances[_queue_selected].get("difficulty", false):
		return "solo"
	return _difficulty

func _refresh_difficulty() -> void:
	var inst: Dictionary = _instances[_queue_selected] if _queue_selected >= 0 else {}
	var has_diff: bool = inst.get("difficulty", false) and inst.get("available", false)
	_diff_box.visible = has_diff
	if not has_diff:
		return
	for c in _diff_row.get_children():
		c.queue_free()
	for d in ["solo", "party"]:
		var key: String = d
		var b := UI.button(menu.get_node("/root/GameManager").difficulty_label(key), 16, Vector2(150, 40))
		var on := key == _difficulty
		var col := MainMenu.C_ACCENT if key == "solo" else Color(0.95, 0.4, 0.3)
		b.add_theme_stylebox_override("normal", UI.box(col.darkened(0.45) if on else UI.BG, col if on else UI.BORDER, 2, 6))
		b.tooltip_text = DIFFICULTY_INFO[key]
		b.pressed.connect(func():
			_difficulty = key
			_refresh_queue())
		_diff_row.add_child(b)
	_diff_hint.text = DIFFICULTY_INFO[_difficulty]

## Queue key of the chosen card ("dungeon:random", "dungeon:<id>").
func _selected_key() -> String:
	return str(_instances[_queue_selected]["key"])

func _toggle_queue() -> void:
	var online := menu.get_node("/root/Online")
	if online.queue_instance != "":
		online.cancel_queue()
		return
	if _queue_selected < 0 or not _instances[_queue_selected]["available"]:
		return
	menu.get_node("/root/GameManager").difficulty = _selected_difficulty()
	online.queue_for(_selected_key())

func _instance_card(i: int) -> Button:
	var inst: Dictionary = _instances[i]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(300 if inst["kind"] == "Queue" else 230, 96)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var kind_text := "Random dungeon" if inst["kind"] == "Queue" else ("Raid" if inst["kind"] == "Raid" else "Dungeon")
	b.text = "%s\n%s  •  %s\n%s" % [inst["name"], kind_text, inst["players"], "" if inst["available"] else "Locked"]
	b.tooltip_text = inst["desc"]
	b.add_theme_font_size_override("font_size", 17 if inst["kind"] == "Queue" else 15)
	b.add_theme_color_override("font_color", Color.WHITE if inst["available"] else Color(0.5, 0.5, 0.55))
	b.pressed.connect(func():
		_queue_selected = i
		_refresh_queue())
	_queue_cards.append(b)
	_style_card(b, false, inst["available"])
	return b

func _style_card(b: Button, selected: bool, available: bool) -> void:
	var bg := Color(0.08, 0.09, 0.12, 0.95) if available else Color(0.05, 0.05, 0.06, 0.95)
	var border := MainMenu.C_ACCENT if selected else UI.BORDER
	b.add_theme_stylebox_override("normal", menu._padded(UI.box(bg, border, 3 if selected else 2, 8), 12))
	b.add_theme_stylebox_override("hover", menu._padded(UI.box(bg.lightened(0.06), MainMenu.C_ACCENT, 2, 8), 12))
	b.add_theme_stylebox_override("pressed", menu._padded(UI.box(bg.lightened(0.06), MainMenu.C_ACCENT, 3, 8), 12))

func _refresh_queue() -> void:
	if _queue_enter == null:
		return
	for i in _queue_cards.size():
		_style_card(_queue_cards[i], i == _queue_selected, _instances[i]["available"])
	var online := menu.get_node("/root/Online")
	var queued: bool = online.queue_instance != ""
	var leader: bool = online.is_leader()
	if _queue_btn:
		_queue_btn.text = "Leave Queue" if queued else "Queue"
		_queue_btn.disabled = not leader or (not queued and (_queue_selected < 0 or not _instances[_queue_selected]["available"]))
	_refresh_difficulty()
	if _queue_selected < 0:
		_queue_enter.disabled = true
		return
	var inst: Dictionary = _instances[_queue_selected]
	var who := "" if leader else "\nOnly the party leader can queue or start."
	var lvl: int = DB.party_level(menu.get_node("/root/GameManager").party_levels())
	_queue_info.text = "%s — %s\nEnemy level for your group: %d%s" % [inst["name"], inst["desc"], lvl, who]
	_queue_enter.disabled = not inst["available"] or not leader
	_queue_enter.text = "Enter Now" if inst["available"] else "Locked"

func _enter_instance() -> void:
	if _queue_selected < 0 or not _instances[_queue_selected]["available"]:
		return
	menu.get_node("/root/GameManager").difficulty = _selected_difficulty()
	menu.get_node("/root/Online").start_now(_selected_key())
