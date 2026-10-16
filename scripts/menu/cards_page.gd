extends "res://scripts/menu/menu_part.gd"
class_name CardsPage

# Moved out of scripts/main_menu.gd as it was (menu = the menu node). Hooked up from
# main_menu.gd through its var "cards_page".
# --- Part: Skill Cards: a loadout that guarantees abilities in level-up drafts --------
var _cards_row: VBoxContainer
var _cards_tabs: HFlowContainer
var _cards_count_label: Label
var _cards_filter := ""   # "" = all books, else a category id

func _build_cards_page() -> Control:
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
	head.add_theme_constant_override("separation", 14)
	head.add_child(UI.label("Skill Cards", 22, MainMenu.C_ACCENT))
	_cards_count_label = UI.label("", 15, Color.WHITE)
	_cards_count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_cards_count_label)
	v.add_child(head)
	var hint := UI.label("Skill Cards are found in dungeon chests and are kept forever. Click a card you own to equip or unequip it. Once you reach an equipped card's level, your next ability draft (every %d levels) is guaranteed to offer its ability — so after dying, your cards bring your abilities back." % menu.get_node("/root/PlayerData").DRAFT_EVERY, 13, MainMenu.C_TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	# Book filter: All + one tab per category (same books as Abilities & Talents).
	_cards_tabs = HFlowContainer.new()
	_cards_tabs.add_theme_constant_override("h_separation", 6)
	_cards_tabs.add_theme_constant_override("v_separation", 6)
	v.add_child(_cards_tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_cards_row = VBoxContainer.new()
	_cards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_row.add_theme_constant_override("separation", 10)
	scroll.add_child(_cards_row)
	menu.get_node("/root/PlayerData").changed_late.connect(_refresh_cards)
	_refresh_cards.call_deferred()
	return page

func _refresh_cards() -> void:
	if _cards_row == null:
		return
	var pd := menu.get_node("/root/PlayerData")
	_cards_count_label.text = "%d / %d collected  •  %d / %d equipped" % [pd.owned_cards.size(), SkillCards.ALL.size(),
		pd.equipped_cards.size(), SkillCards.MAX_EQUIPPED]
	for c in _cards_row.get_children():
		c.queue_free()
	_refresh_card_tabs(pd)
	# Grouped by book (same order as the spellbook shelf); within a book owned
	# cards first, then by card level.
	var by_cat := {}
	for cid in SkillCards.ALL:
		var cat := Abilities.category_of(SkillCards.ability_of(cid))
		if _cards_filter != "" and cat != _cards_filter:
			continue
		if not by_cat.has(cat):
			by_cat[cat] = []
		by_cat[cat].append(cid)
	var cats: Array = Categories.ORDER.filter(func(c): return by_cat.has(c))
	for c in by_cat:
		if not cats.has(c):
			cats.append(c)   # cards whose ability has no book
	for cat in cats:
		var list: Array = by_cat[cat]
		list.sort_custom(func(a, b):
			var oa: bool = pd.owned_cards.has(a)
			var ob: bool = pd.owned_cards.has(b)
			if oa != ob:
				return oa
			if SkillCards.level_of(a) != SkillCards.level_of(b):
				return SkillCards.level_of(a) < SkillCards.level_of(b)
			return Abilities.ability_name(SkillCards.ability_of(a)) < Abilities.ability_name(SkillCards.ability_of(b)))
		var owned_n := list.filter(func(c): return pd.owned_cards.has(c)).size()
		var title := menu._label("%s   %d / %d" % [Categories.cat_name(cat) if cat != "" else "Other", owned_n, list.size()],
			17, Categories.color(cat).lightened(0.3) if cat != "" else Color.WHITE)
		_cards_row.add_child(title)
		var flow := HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", 12)
		flow.add_theme_constant_override("v_separation", 12)
		_cards_row.add_child(flow)
		for cid in list:
			flow.add_child(_card_button(pd, cid))

## Filter tabs: All + every book, each with owned / total.
func _refresh_card_tabs(pd: Node) -> void:
	for c in _cards_tabs.get_children():
		c.queue_free()
	var counts := {}   # cat -> [owned, total]
	for cid in SkillCards.ALL:
		var cat := Abilities.category_of(SkillCards.ability_of(cid))
		if not counts.has(cat):
			counts[cat] = [0, 0]
		counts[cat][1] += 1
		if pd.owned_cards.has(cid):
			counts[cat][0] += 1
	var tabs: Array = [""]
	for cat in Categories.ORDER:
		if counts.has(cat):
			tabs.append(cat)
	for cat in tabs:
		var c: String = cat
		var on := c == _cards_filter
		var col := Categories.color(c) if c != "" else MainMenu.C_ACCENT
		var text := "All  %d / %d" % [pd.owned_cards.size(), SkillCards.ALL.size()] if c == "" \
			else "%s  %d / %d" % [Categories.cat_name(c), counts[c][0], counts[c][1]]
		var b := UI.button(text, 14, Vector2(0, 32))
		b.add_theme_color_override("font_color", col.lightened(0.35) if on else col.lightened(0.1))
		b.add_theme_stylebox_override("normal", UI.box(col.darkened(0.7) if on else UI.BG, col if on else col.darkened(0.4), 2 if on else 1, 6))
		b.pressed.connect(func():
			_cards_filter = c
			_refresh_cards())
		_cards_tabs.add_child(b)

func _card_button(pd: Node, cid: String) -> Button:
		var aid := SkillCards.ability_of(cid)
		var cat := Abilities.category_of(aid)
		var equipped: bool = pd.equipped_cards.has(cid)
		var learned: bool = pd.has_ability(aid)
		var owned: bool = pd.owned_cards.has(cid)
		var b := Button.new()
		if not owned:
			b.modulate = Color(1, 1, 1, 0.35)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(240, 76)
		var border := MainMenu.C_ACCENT if equipped else UI.BORDER
		b.add_theme_stylebox_override("normal", UI.box(Color(0.08, 0.085, 0.11, 0.95), border, 2 if equipped else 1, 8))
		b.add_theme_stylebox_override("hover", UI.box(Color(0.11, 0.11, 0.15, 0.95), MainMenu.C_ACCENT, 2, 8))
		b.add_theme_stylebox_override("pressed", UI.box(Color(0.11, 0.11, 0.15, 0.95), MainMenu.C_ACCENT, 2, 8))
		b.tooltip_text = SkillCards.tooltip(cid)
		b.pressed.connect(func(): menu._toast_if(pd.toggle_card(cid)))
		var icon := Control.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2(10, 12)
		icon.size = Vector2(52, 52)
		icon.draw.connect(func(): Abilities.draw_icon(icon, aid))
		b.add_child(icon)
		var info := VBoxContainer.new()
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.position = Vector2(72, 10)
		info.size = Vector2(160, 56)
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		info.add_theme_constant_override("separation", 1)
		b.add_child(info)
		info.add_child(menu._label(Abilities.ability_name(aid), 16, Color.WHITE if equipped else Color(0.85, 0.85, 0.9)))
		info.add_child(menu._label("%s  •  Level %d" % [Categories.cat_name(cat), SkillCards.level_of(cid)], 12, Categories.color(cat)))
		var state := "Equipped" if equipped else ("Not equipped" if owned else "Not found — open chests")
		if learned:
			state += "  •  learned"
		info.add_child(menu._label(state, 11, MainMenu.C_ACCENT if equipped else MainMenu.C_TEXT_DIM))
		return b

# Bar slot being dragged (-1 = none). Letting go anywhere that doesn't take the
# ability (empty space, the nav bar, other panels...) removes it from the bar.
var _bar_drag_from := -1

func _check_bar_drag_end() -> void:
	if _bar_drag_from == -1 or menu.get_viewport().gui_is_dragging():
		return
	var from := _bar_drag_from
	_bar_drag_from = -1
	if not menu.get_viewport().gui_is_drag_successful():
		menu.get_node("/root/PlayerData").clear_action_slot(from)

func _ability_preview(id: String) -> Control:
	var root := Control.new()
	var s := Abilities.make_slot(44)
	s.modulate.a = 0.85
	s.position = Vector2(-22, -22)
	Abilities.set_slot_ability(s, id)
	root.add_child(s)
	return root
