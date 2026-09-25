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
	return player != null and player.has_method("is_alive") and player.is_alive()

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
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.anchor_left = 0.5
	v.anchor_right = 0.5
	v.anchor_top = 0.5
	v.anchor_bottom = 0.5
	v.offset_left = -380
	v.offset_right = 380
	v.offset_top = -210
	v.offset_bottom = 210
	v.add_theme_constant_override("separation", 16)
	_root.add_child(v)
	_title = UI.label("", 28, UI.ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	var sub := UI.label("Pick a new ability or bonus. It lasts until you die.", 14, UI.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 18)
	v.add_child(_cards)

func _make_card(index: int, choice: Dictionary) -> Control:
	var is_ability: bool = choice["type"] == "ability"
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(230, 300)
	var border := UI.ACCENT if choice.get("guaranteed", false) else UI.BORDER
	b.add_theme_stylebox_override("normal", UI.box(UI.PANEL_BG, border, 2, 10))
	b.add_theme_stylebox_override("hover", UI.box(Color(0.1, 0.1, 0.14, 0.98), UI.ACCENT, 3, 10))
	b.add_theme_stylebox_override("pressed", UI.box(Color(0.12, 0.12, 0.16, 0.98), UI.ACCENT, 3, 10))
	b.pressed.connect(pick.bind(index))

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -14
	v.offset_top = 12
	v.offset_bottom = -12
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)

	var key := UI.label("[%d]" % (index + 1), 12, UI.TEXT_DIM)
	var settings := get_node_or_null("/root/Settings")
	if settings:
		key.text = "[%s]" % settings.key_text("ability_%d" % (index + 1))
	v.add_child(key)

	var icon := Control.new()
	icon.custom_minimum_size = Vector2(72, 72)
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
			icon.draw_circle(m, 30.0, Color(0.25, 0.18, 0.35))
			icon.draw_rect(Rect2(m + Vector2(-5, -20), Vector2(10, 40)), Color(0.85, 0.7, 1.0), true)
			icon.draw_rect(Rect2(m + Vector2(-20, -5), Vector2(40, 10)), Color(0.85, 0.7, 1.0), true))
	v.add_child(icon)

	var name_text := Abilities.ability_name(str(choice["id"])) if is_ability else str(choice["name"])
	var name_l := UI.label(name_text, 20, Color.WHITE)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)

	var kind := UI.label("New ability" if is_ability else "Bonus (until death)", 12, UI.TEXT_DIM)
	kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(kind)

	var desc_text := ""
	if is_ability:
		var tip := Abilities.tooltip(str(choice["id"])).split("\n")
		desc_text = "\n".join(tip.slice(1))   # skip the name line
	else:
		desc_text = str(choice["desc"])
	var desc := UI.label(desc_text, 13, Color(0.85, 0.85, 0.9))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(200, 0)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(desc)
	if is_ability:
		var hint := UI.label("Hold Shift for details", 11, UI.TEXT_DIM)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(hint)

	if choice.get("guaranteed", false):
		var tag := UI.label("★ Skill Card", 13, UI.ACCENT)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(tag)
	return b
