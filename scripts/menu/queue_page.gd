extends "res://scripts/menu/menu_part.gd"
class_name QueuePage

# Queue (the Play screen): pick a dungeon and go in. "Random Dungeon" is the real
# queue: you (and your party) get sent into a random dungeon from the pool. Below it
# every dungeon has its own card and can be joined on its own - for testing. Enemy
# level = the group's average pulled toward its highest level. The right-hand panel
# shows the chosen dungeon (objectives, modifiers, enemy level, best clears), the
# difficulty, your Pact, and Queue / Enter Now. With a party, both go through a
# ready check first (Net "Ready check"). The choice is remembered (Settings).

const Names = preload("res://scripts/dungeon/names.gd")
const Mods = preload("res://scripts/dungeon/modifiers.gd")

var _instances: Array = []
const QUEUE_ROWS := [["Queue", "Dungeon Finder"], ["Test", "Join a specific dungeon (testing)"], ["Raid", "Raids"]]
const DETAILS_W := 390

func _build_instances() -> void:
	_instances = [{"name": DB.title(DB.RANDOM_KEY), "kind": "Queue", "players": "1-5 players", "available": true,
		"key": DB.RANDOM_KEY, "id": "", "desc": DB.description(DB.RANDOM_KEY), "difficulty": true}]
	for r in DB.recipes():
		_instances.append({"name": DB.title(str(r.id)), "kind": "Test", "players": "1-5 players", "available": true,
			"key": DB.key_for(str(r.id)), "id": str(r.id), "recipe": r, "difficulty": true,
			"desc": DB.description(str(r.id)) + ("" if r.in_random_pool else "\n(Not in the random pool.)")})
	for l in DB.LEGACY:
		_instances.append({"name": DB.title(str(l["id"])), "kind": "Test", "players": "1-5 players", "available": true,
			"key": DB.key_for(str(l["id"])), "id": str(l["id"]), "difficulty": true, "desc": DB.description(str(l["id"]))})
	_instances.append({"name": "Crypt of Bones", "kind": "Raid", "players": "10 players", "available": false,
		"key": "", "id": "", "desc": "An ancient tomb and its undying king. Coming soon."})

var _queue_selected := 0
var _queue_cards: Array[Button] = []
var _queue_enter: Button
var _queue_info: Label
var _detail_title: Label
var _detail_kind: Label
var _detail_desc: Label
var _detail_facts: RichTextLabel
var _pact_line: Label

func _build_queue_page() -> Control:
	_build_instances()
	_restore_choice()
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

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 16)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(split)

	# Left: the dungeon cards (scroll at any resolution).
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

	split.add_child(_build_details())
	_refresh_queue.call_deferred()
	return page

## The right-hand panel: the chosen dungeon, difficulty, Pact, Queue / Enter Now.
func _build_details() -> Control:
	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(DETAILS_W, 0)
	side.add_theme_stylebox_override("panel", menu._padded(UI.box(Color(0.07, 0.075, 0.1, 0.95), UI.BORDER, 1, 8), 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	side.add_child(v)
	_detail_title = UI.label("", 22, MainMenu.C_ACCENT)
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_detail_title)
	_detail_kind = UI.label("", 13, MainMenu.C_TEXT_DIM)
	v.add_child(_detail_kind)
	_detail_desc = UI.label("", 14, Color(0.88, 0.88, 0.9))
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_detail_desc)
	_detail_facts = RichTextLabel.new()
	_detail_facts.bbcode_enabled = true
	_detail_facts.fit_content = true
	_detail_facts.scroll_active = false
	_detail_facts.add_theme_font_size_override("normal_font_size", 14)
	_detail_facts.add_theme_font_size_override("bold_font_size", 14)
	v.add_child(_detail_facts)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	# Difficulty: sits right above Queue / Enter Now.
	_diff_box = VBoxContainer.new()
	_diff_box.add_theme_constant_override("separation", 6)
	_diff_box.visible = false
	v.add_child(_diff_box)
	_diff_box.add_child(UI.label("Difficulty", 16, Color.WHITE))
	_diff_row = HBoxContainer.new()
	_diff_row.add_theme_constant_override("separation", 8)
	_diff_box.add_child(_diff_row)
	_diff_hint = UI.label("", 13, MainMenu.C_TEXT_DIM)
	_diff_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diff_box.add_child(_diff_hint)
	_pact_line = UI.label("", 13, Pacts.COLOR.lightened(0.35))
	_pact_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_pact_line)
	_queue_info = UI.label("Select a dungeon.", 14, MainMenu.C_TEXT_DIM)
	_queue_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_queue_info)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	v.add_child(buttons)
	# Queue: fill the group up to 5 with random players (a full party goes straight in).
	_queue_btn = UI.button("Queue", 20, Vector2(0, 52))
	_queue_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_queue_btn.disabled = true
	_queue_btn.tooltip_text = "Find a group: you're matched with other players queueing for the same thing.\nA full party of 5 goes straight in. With a party, everyone confirms first."
	_queue_btn.pressed.connect(_toggle_queue)
	buttons.add_child(_queue_btn)
	_queue_enter = UI.button("Enter Now", 20, Vector2(0, 52))
	_queue_enter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_queue_enter.add_theme_stylebox_override("normal", UI.box(MainMenu.C_ACCENT, Color(1, 0.9, 0.6), 2, 8))
	_queue_enter.add_theme_stylebox_override("hover", UI.box(MainMenu.C_ACCENT.lightened(0.15), Color(1, 0.95, 0.75), 2, 8))
	_queue_enter.add_theme_stylebox_override("disabled", UI.box(Color(0.2, 0.2, 0.22), MainMenu.C_BORDER, 2, 8))
	_queue_enter.add_theme_color_override("font_color", Color(0.1, 0.07, 0.03))
	_queue_enter.add_theme_color_override("font_hover_color", Color(0.1, 0.07, 0.03))
	_queue_enter.disabled = true
	_queue_enter.tooltip_text = "Go in right now with your current party (or solo).\nWith a party, everyone confirms first."
	_queue_enter.pressed.connect(_enter_instance)
	buttons.add_child(_queue_enter)
	return side

var _queue_btn: Button
var _diff_box: VBoxContainer
var _diff_row: HBoxContainer
var _diff_hint: Label
var _difficulty := "solo"
const DIFFICULTY_INFO := {
	"solo": "The normal game. Beatable on your own with any role.",
	"party": "Built for a group of 5. Enemies hit far harder and have more health: the tank has to use his defensive abilities to survive, big pulls are impossible without a healer, and archers and casters sometimes shoot someone other than the tank.",
}

## The last choice (Settings), if that dungeon still exists.
func _restore_choice() -> void:
	var st := menu.get_node("/root/Settings")
	_difficulty = "party" if str(st.play_difficulty) == "party" else "solo"
	for i in _instances.size():
		if str(_instances[i]["key"]) == str(st.play_choice) and _instances[i]["available"]:
			_queue_selected = i

func _remember_choice() -> void:
	var st := menu.get_node("/root/Settings")
	var key := _selected_key()
	if str(st.play_choice) == key and str(st.play_difficulty) == _difficulty:
		return
	st.play_choice = key
	st.play_difficulty = _difficulty
	st.save()

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
			_remember_choice()
			_refresh_queue())
		_diff_row.add_child(b)
	_diff_hint.text = DIFFICULTY_INFO[_difficulty]

## Queue key of the chosen card ("dungeon:random", "dungeon:<id>").
func _selected_key() -> String:
	return str(_instances[_queue_selected]["key"])

## The PLAY button's second line: where you're going ("" = nothing chosen).
func play_summary() -> String:
	if _instances.is_empty() or _queue_selected < 0 or not _instances[_queue_selected]["available"]:
		return ""
	return "%s  •  %s" % [_instances[_queue_selected]["name"],
		menu.get_node("/root/GameManager").difficulty_label(_selected_difficulty())]

func _toggle_queue() -> void:
	var online := menu.get_node("/root/Online")
	if online.queue_instance != "":
		online.cancel_queue()
		return
	if _queue_selected < 0 or not _instances[_queue_selected]["available"]:
		return
	var key := _selected_key()
	var diff := _selected_difficulty()
	# With a party, everyone confirms first (Net ready check).
	menu.get_node("/root/Net").start_ready_check(func():
		menu.get_node("/root/GameManager").difficulty = diff
		online.queue_for(key))

func _instance_card(i: int) -> Button:
	var inst: Dictionary = _instances[i]
	var big: bool = inst["kind"] == "Queue"
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(340 if big else 250, 120 if big else 104)
	b.tooltip_text = inst["desc"]
	b.pressed.connect(func():
		_queue_selected = i
		if _instances[i]["available"]:
			_remember_choice()
		_refresh_queue())
	var v := VBoxContainer.new()
	v.name = "Body"
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -12
	v.offset_top = 6
	v.offset_bottom = -8
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var strip := ColorRect.new()
	strip.custom_minimum_size = Vector2(0, 4)
	strip.color = _tint(inst)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(strip)
	var name_l := UI.label(str(inst["name"]), 19 if big else 16, Color.WHITE if inst["available"] else Color(0.5, 0.5, 0.55))
	name_l.clip_text = true
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_l)
	var kind_text := "Random dungeon" if big else ("Raid" if inst["kind"] == "Raid" else "Dungeon")
	var kind_l := UI.label("%s  •  %s" % [kind_text, inst["players"]], 12, MainMenu.C_TEXT_DIM)
	kind_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(kind_l)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(gap)
	var foot := UI.label("", 13, MainMenu.C_TEXT_DIM)
	foot.name = "Foot"
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(foot)
	_queue_cards.append(b)
	_style_card(b, false, inst["available"])
	return b

## A card's colour: its dungeon's glow, gold for the queue, grey for locked.
func _tint(inst: Dictionary) -> Color:
	if not inst["available"]:
		return Color(0.35, 0.35, 0.38)
	var r = inst.get("recipe")   # (a DungeonRecipe, or null)
	if r != null and r.biome != null:
		return r.biome.glow_color
	return MainMenu.C_ACCENT

## A card's bottom line: best clear on the chosen difficulty, or what's in the pool.
func _card_foot(inst: Dictionary) -> String:
	if not inst["available"]:
		return "Coming soon"
	if inst["kind"] == "Queue":
		return "Any of %d dungeons" % DB.random_pool().size()
	var best := float(menu.get_node("/root/PlayerData").best_clear(str(inst["id"]), _difficulty))
	return "Best: %s" % _clock(best) if best > 0.0 else "Not cleared yet"

static func _clock(secs: float) -> String:
	var s := int(secs)
	return "%d:%02d" % [s / 60, s % 60]

func _style_card(b: Button, selected: bool, available: bool) -> void:
	var bg := Color(0.08, 0.09, 0.12, 0.95) if available else Color(0.05, 0.05, 0.06, 0.95)
	var border := MainMenu.C_ACCENT if selected else UI.BORDER
	b.add_theme_stylebox_override("normal", UI.box(bg.lightened(0.04) if selected else bg, border, 3 if selected else 2, 8))
	b.add_theme_stylebox_override("hover", UI.box(bg.lightened(0.06), MainMenu.C_ACCENT, 2, 8))
	b.add_theme_stylebox_override("pressed", UI.box(bg.lightened(0.06), MainMenu.C_ACCENT, 3, 8))

## The chosen dungeon's facts: objectives, modifiers, enemy level, best clears.
func _facts(inst: Dictionary, lvl: int) -> String:
	var dim := MainMenu.C_TEXT_DIM.to_html(false)
	var lines: Array[String] = []
	if inst["available"]:
		lines.append("[color=#%s]Enemy level for your group:[/color] [b]%d[/b]" % [dim, lvl])
	var r = inst.get("recipe")   # (a DungeonRecipe, or null)
	if r != null:
		var objs: Array[String] = []
		for o in r.objectives:
			var text := Names.t("obj_" + str(o))
			if str(o) == "clear_pct":
				text = text % int(r.clear_pct)
			if not objs.has(text):
				objs.append(text)
		if not objs.is_empty():
			lines.append("[color=#%s]Objectives:[/color] %s" % [dim, ", ".join(objs)])
		if not r.modifier_pool.is_empty() and int(r.modifier_count) > 0:
			var mods: Array[String] = []
			for m in r.modifier_pool:
				mods.append("[color=#%s]%s[/color]" % [Mods.color(str(m)).to_html(false), Mods.title(str(m))])
			lines.append("[color=#%s]Modifiers (%d of):[/color] %s" % [dim, int(r.modifier_count), ", ".join(mods)])
	if str(inst.get("id", "")) != "":
		var pd := menu.get_node("/root/PlayerData")
		var parts: Array[String] = []
		for d in ["solo", "party"]:
			var best := float(pd.best_clear(str(inst["id"]), d))
			parts.append("%s %s" % [menu.get_node("/root/GameManager").difficulty_label(d), _clock(best) if best > 0.0 else "—"])
		lines.append("[color=#%s]Best clear:[/color] %s" % [dim, "   ".join(parts)])
	return "\n".join(lines)

func _refresh_queue() -> void:
	if _queue_enter == null:
		return
	for i in _queue_cards.size():
		_style_card(_queue_cards[i], i == _queue_selected, _instances[i]["available"])
		_queue_cards[i].get_node("Body/Foot").text = _card_foot(_instances[i])
	var online := menu.get_node("/root/Online")
	var net := menu.get_node("/root/Net")
	var queued: bool = online.queue_instance != ""
	var leader: bool = online.is_leader()
	var checking: bool = not net.ready_check.is_empty()
	if _queue_btn:
		_queue_btn.text = "Leave Queue" if queued else "Queue"
		_queue_btn.disabled = not leader or checking or (not queued and (_queue_selected < 0 or not _instances[_queue_selected]["available"]))
	_refresh_difficulty()
	var pd := menu.get_node("/root/PlayerData")
	_pact_line.text = ("Pact: %s  (change it in Abilities & Talents)" % Pacts.title(str(pd.pact), str(pd.pact_book))) if str(pd.pact) != "" \
		else "No Pact held (Abilities & Talents → Pacts)."
	if _queue_selected < 0:
		_queue_enter.disabled = true
		return
	var inst: Dictionary = _instances[_queue_selected]
	var lvl: int = DB.party_level(menu.get_node("/root/GameManager").party_levels())
	_detail_title.text = str(inst["name"])
	_detail_kind.text = "%s  •  %s" % ["Random dungeon" if inst["kind"] == "Queue" else ("Raid" if inst["kind"] == "Raid" else "Dungeon"), inst["players"]]
	_detail_desc.text = str(inst["desc"])
	_detail_facts.text = _facts(inst, lvl)
	if checking:
		_queue_info.text = "Ready check: waiting for your party…"
	elif not leader:
		_queue_info.text = "Only the party leader can queue or start."
	else:
		_queue_info.text = ""
	_queue_info.visible = _queue_info.text != ""
	_queue_enter.disabled = not inst["available"] or not leader or checking
	_queue_enter.text = "Enter Now" if inst["available"] else "Locked"
	menu.refresh_play_button()

func _enter_instance() -> void:
	if _queue_selected < 0 or not _instances[_queue_selected]["available"]:
		return
	var key := _selected_key()
	var diff := _selected_difficulty()
	menu.get_node("/root/Net").start_ready_check(func():
		menu.get_node("/root/GameManager").difficulty = diff
		menu.get_node("/root/Online").start_now(key))
