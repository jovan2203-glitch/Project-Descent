extends CanvasLayer

# Level-up draft overlay (autoload "Draft").
# Every level gained queues a draft (PlayerData.pending_drafts). While playing,
# the overlay opens, PAUSES the game and offers 3 choices (DraftRules): Skill
# Card guarantees first, then random unlearned abilities, then stat boons.
# Clicking a card (or pressing its action-bar key 1/2/3) learns it and resumes.

const DraftRules = preload("res://scripts/core/draft_rules.gd")
const Abilities = preload("res://scripts/abilities.gd")
const UI = preload("res://scripts/ui_kit.gd")
const OPEN_DELAY := 0.6   # short beat after the level-up before pausing

var is_open := false
var _level := 0
var _choices: Array = []
var _root: Control
var _cards: HBoxContainer
var _title: Label
var _delay := -1.0

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false

func _pd() -> Node:
	return get_node_or_null("/root/PlayerData")

func _can_open() -> bool:
	var gm := get_node_or_null("/root/GameManager")
	if gm == null or int(gm.state) != 1 or gm.is_loading():   # 1 = GameManager.State.PLAYING
		return false
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("is_alive") or not player.is_alive():
		return false
	# Never mid-fight: the draft waits until combat ends.
	return not (player.has_method("is_in_combat") and player.is_in_combat())

func _process(delta: float) -> void:
	if is_open:
		return
	var pd := _pd()
	if pd == null or pd.pending_drafts.is_empty() or not _can_open():
		_delay = -1.0
		return
	if _delay < 0.0:
		_delay = OPEN_DELAY
	_delay -= delta
	if _delay <= 0.0:
		_delay = -1.0
		open(int(pd.pending_drafts[0]))

func open(level: int) -> void:
	var pd := _pd()
	_level = level
	# Between normal drafts this is a Skill Card re-offer: card abilities + boons only.
	var cards_only: bool = not pd.is_draft_level(level)
	_choices = DraftRules.make_choices(level, Array(pd.learned_abilities), Array(pd.equipped_cards),
		null, {}, cards_only)
	if cards_only and not _choices.any(func(c): return c.get("guaranteed", false)):
		pd.pending_drafts.erase(level)   # nothing to re-offer any more (card unequipped / learned)
		pd.card_reoffer = false
		return
	_title.text = ("Level %d — Skill Card" if cards_only else "Level %d — choose one") % level
	for c in _cards.get_children():
		c.queue_free()
	for i in _choices.size():
		_cards.add_child(_make_card(i, _choices[i]))
	is_open = true
	visible = true
	# With other players the world can't stop for one person's level-up.
	var net := get_node_or_null("/root/Net")
	_paused_it = not (net and net.with_others())
	if _paused_it:
		get_tree().paused = true
	var bus := get_node_or_null("/root/SignalBus")
	if bus:
		bus.draft_opened.emit(level, _choices)

func pick(index: int) -> void:
	if not is_open or index < 0 or index >= _choices.size():
		return
	var pd := _pd()
	var choice: Dictionary = _choices[index]
	pd.pending_drafts.erase(_level)
	# Passed over a guaranteed Skill Card? It comes back on the next level-up.
	pd.card_reoffer = DraftRules.skipped_card(_choices, choice)
	DraftRules.apply_choice(pd, choice)   # emits PlayerData.changed (autosave)
	var gl := get_node_or_null("/root/GameLog")
	if gl:
		var what := Abilities.ability_name(str(choice["id"])) if choice["type"] == "ability" else "%s (%s)" % [choice["name"], choice["desc"]]
		gl.event("Drafted %s" % what, Color(0.8, 0.6, 1.0))
	close()

var _paused_it := false

func close() -> void:
	is_open = false
	visible = false
	if _paused_it:
		_paused_it = false
		get_tree().paused = false

func _input(event: InputEvent) -> void:
	if not is_open:
		return
	for i in 3:
		if event.is_action_pressed("ability_%d" % (i + 1)):
			get_viewport().set_input_as_handled()
			pick(i)
			return
	if event is InputEventKey:
		get_viewport().set_input_as_handled()   # nothing else reacts while drafting

# --- UI ------------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	# Centered column that grows with the cards (tall cards push it, never clip).
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)
	_title = UI.label("", 28, UI.ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	var sub := UI.label("Pick a new ability or bonus. It lasts until you die.", 14, UI.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 16)
	v.add_child(_cards)

const CARD_WIDTH := 240.0
const CARD_MIN_HEIGHT := 300.0

## A card grows to fit its text (a Button can't, so it's a clickable panel).
func _make_card(index: int, choice: Dictionary) -> Control:
	var is_ability: bool = choice["type"] == "ability"
	var b := PanelContainer.new()
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.custom_minimum_size = Vector2(CARD_WIDTH, CARD_MIN_HEIGHT)
	var border := UI.ACCENT if choice.get("guaranteed", false) else UI.BORDER
	var normal := _card_box(UI.PANEL_BG, border, 2)
	var hover := _card_box(Color(0.1, 0.1, 0.14, 0.98), UI.ACCENT, 3)
	b.add_theme_stylebox_override("panel", normal)
	b.mouse_entered.connect(func(): b.add_theme_stylebox_override("panel", hover))
	b.mouse_exited.connect(func(): b.add_theme_stylebox_override("panel", normal))
	b.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			pick(index))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)

	var key := UI.label("[%d]" % (index + 1), 11, UI.TEXT_DIM)
	var settings := get_node_or_null("/root/Settings")
	if settings:
		key.text = "[%s]" % settings.key_text("ability_%d" % (index + 1))
	v.add_child(key)

	var icon := Control.new()
	icon.custom_minimum_size = Vector2(64, 64)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_ability:
		var aid := str(choice["id"])
		icon.draw.connect(func(): Abilities.draw_icon(icon, aid))
		# Hold Shift over the card for the detailed breakdown (ItemTooltip).
		b.set_meta("tip_ability", aid)
		b.set_meta("tip_detail_only", true)
	else:
		icon.draw.connect(func():
			var m := icon.size / 2.0
			icon.draw_circle(m, 28.0, Color(0.25, 0.18, 0.35))
			icon.draw_rect(Rect2(m + Vector2(-5, -18), Vector2(10, 36)), Color(0.85, 0.7, 1.0), true)
			icon.draw_rect(Rect2(m + Vector2(-18, -5), Vector2(36, 10)), Color(0.85, 0.7, 1.0), true))
	v.add_child(icon)

	var name_text := Abilities.ability_name(str(choice["id"])) if is_ability else str(choice["name"])
	var name_l := _wrapped(name_text, 18, Color.WHITE)
	v.add_child(name_l)

	var kind := _wrapped("New ability" if is_ability else "Bonus (until death)", 11, UI.TEXT_DIM)
	v.add_child(kind)

	var desc_text := ""
	if is_ability:
		# Description + cost / cast / cooldown + requirements (no name, no tag list).
		var tip := Abilities.tooltip(str(choice["id"])).split("\n")
		var keep: Array[String] = []
		for i in range(1, tip.size()):
			if not tip[i].begins_with("Tags:"):
				keep.append(tip[i])
		desc_text = "\n".join(keep)
	else:
		desc_text = str(choice["desc"])
	v.add_child(_wrapped(desc_text, 12, Color(0.85, 0.85, 0.9)))
	if is_ability:
		v.add_child(_wrapped("Hold Shift for details", 10, UI.TEXT_DIM))

	if choice.get("guaranteed", false):
		v.add_child(_wrapped("★ Skill Card", 12, UI.ACCENT))
	return b

func _card_box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb := UI.box(bg, border, width, 10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	return sb

## Centered label that wraps inside the card instead of spilling out of it.
func _wrapped(text: String, size: int, color: Color) -> Label:
	var l := UI.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(CARD_WIDTH - 24.0, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
