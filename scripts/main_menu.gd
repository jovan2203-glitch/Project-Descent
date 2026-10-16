extends Node3D
class_name MainMenu

# Main menu: 3D player on a pedestal with UI layered on top.
# Tabs: Lobby (party slots + Play), Character (gear slots), Abilities & Talents
# (category books), Skill Cards, Bank, Queue.

# --- Components ----------------------------------------------------------------------------
# Each tab's own code lives in a part (scripts/menu/*.gd, see menu_part.gd), made
# here as a child node; SPLIT_HOST=menu tools/split_batch.sh adds the line for each one.
var talent_tree: TalentTreePage = _part(TalentTreePage) as TalentTreePage
var pacts_page: PactsPage = _part(PactsPage) as PactsPage
var book_search: BookSearch = _part(BookSearch) as BookSearch
var cards_page: CardsPage = _part(CardsPage) as CardsPage
var character_page: CharacterPage = _part(CharacterPage) as CharacterPage
var lobby_page: LobbyPage = _part(LobbyPage) as LobbyPage
var esc: EscMenuPart = _part(EscMenuPart) as EscMenuPart
var bank_page: BankPage = _part(BankPage) as BankPage
var queue_page: QueuePage = _part(QueuePage) as QueuePage

func _part(script: Script) -> Node:
	var p: Node = script.new()
	p.name = str(script.get_global_name())
	p.set("menu", self)
	add_child(p)
	return p

# --- End of components ---

const UI = preload("res://scripts/ui_kit.gd")
const Items = preload("res://scripts/items.gd")
const Runes = preload("res://scripts/runes.gd")
const Talents = preload("res://scripts/talents.gd")
const TalentIcons = preload("res://scripts/talent_icons.gd")
const PARTY_SLOTS = 4
const SOCIAL_PANEL = preload("res://scripts/ui/social_panel.gd")

const LEFT_GEAR = ["Head", "Neck", "Shoulder", "Back", "Chest", "Gloves"]
const RIGHT_GEAR = ["Legs", "Boots", "Finger 1", "Finger 2", "Trinket 1", "Trinket 2"]
const WEAPON_SLOTS = ["Main Hand", "Off Hand"]
const COSMETIC_SLOTS = ["Back"]

const C_BG := Color(0.07, 0.075, 0.1, 0.85)
const C_BORDER := Color(0.35, 0.33, 0.3)
const C_ACCENT := Color(0.95, 0.75, 0.35)
const C_TEXT_DIM := Color(0.65, 0.65, 0.7)

@onready var camera: Camera3D = $Camera3D
@onready var model: Node3D = $PlayerModel

var ui: CanvasLayer
var pages := {}
var nav_buttons := {}
var play_button: Button
var friends_button: Button
var esc_menu: PanelContainer
var settings_panel: PanelContainer
var wipe_panel: PanelContainer
var esc_shade: ColorRect

## Party chat (and /commands) in the main menu too - the same chat box as in game,
## on its own layer above the menu. Collapse it with the "–" button.
const ChatBox = preload("res://scripts/ui/chat_box.gd")

var _chat_layer: CanvasLayer

func _add_chat() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ChatLayer"
	layer.layer = 5
	add_child(layer)
	_chat_layer = layer
	layer.visible = pages.has("Lobby") and pages["Lobby"].visible   # Lobby only
	var chat: PanelContainer = ChatBox.new()
	chat.name = "ChatBox"
	chat.bottom_gap = 40.0     # just above the level bar
	chat.avoid_above = lobby_page._party_row   # fill the space under the party cards
	chat.fill_height = true
	layer.add_child(chat)

func _ready() -> void:
	_add_chat.call_deferred()
	camera.look_at(Vector3(0, 0.95, 0))
	$KeyLight.look_at(Vector3(0, 0.9, 0))
	_play_idle()
	_build_ui()
	lobby_page._build_party_podiums()
	_show_page("Lobby")
	character_page._refresh_gear()
	get_node("/root/PlayerData").changed_late.connect(character_page._refresh_gear)
	bank_page._wire_bank()
	character_page._wire_gear()
	# Party / online
	var online := get_node("/root/Online")
	var net := get_node("/root/Net")
	online.changed.connect(lobby_page._refresh_party)
	net.members_changed.connect(lobby_page._refresh_party)
	online.toast.connect(_toast_ok)
	net.system_message.connect(_toast_ok)
	lobby_page._refresh_party()

# --- Party podiums + party members' characters ---------------------------------------
# Every party card has a 3D podium standing in it (behind the UI, lined up with
# the card each frame), and a party member's character stands on theirs. Cards
# are mostly see-through so the podium / character shows. Party members use the
# same base model as you for now; gear and character customization plug in at
# _make_party_model later.
const PARTY_MODEL = preload("res://assets/player/Idle.fbx")
# --- Gear: right-click -> bank, Alt+hover -> pick from bank -----------------------

var _toast_label: Label
var _toast_tween: Tween

const RuneScreens = preload("res://scripts/ui/rune_screens.gd")
const RuneManager = preload("res://scripts/ui/rune_manager.gd")
const MacroWindow = preload("res://scripts/ui/macro_window.gd")

# --- Input, per-frame updates and toasts ---------------------------------------------

func _toast_ok(msg: String) -> void:
	_toast_if(msg)
	_toast_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
	_toast_label.move_to_front()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ALT:
		if character_page._hovered_slot != "" and pages["Character"].visible:
			character_page._open_alt_popup()

func _process(delta: float) -> void:
	lobby_page._update_queue_banner()
	lobby_page._layout_party_3d()
	cards_page._check_bar_drag_end()
	character_page._update_gear_highlights()
	if character_page._alt_popup == null or not character_page._alt_popup.visible:
		return
	var mouse := get_viewport().get_mouse_position()
	var over := character_page._alt_popup.get_global_rect().has_point(mouse)
	if is_instance_valid(character_page._alt_popup_btn) and character_page._alt_popup_btn.is_visible_in_tree():
		over = over or character_page._alt_popup_btn.get_global_rect().has_point(mouse)
	if over:
		character_page._alt_grace = CharacterPage.ALT_GRACE
		return
	character_page._alt_grace -= delta
	if character_page._alt_grace <= 0.0:
		character_page._alt_popup.visible = false

func _toast_if(msg: String) -> void:
	if msg == "":
		return
	if _toast_label == null:
		_toast_label = UI.label("", 18, Color(1, 0.35, 0.3))
		_toast_label.anchor_left = 0.5
		_toast_label.anchor_right = 0.5
		_toast_label.anchor_top = 1.0
		_toast_label.anchor_bottom = 1.0
		_toast_label.offset_left = -300
		_toast_label.offset_right = 300
		_toast_label.offset_top = -140
		_toast_label.offset_bottom = -110
		_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ui.add_child(_toast_label)
	_toast_label.text = msg
	_toast_label.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
	_toast_label.move_to_front()
	_toast_label.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.2)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.5)

# --- Bank: show items, Ctrl+click multi-select, drag to trash --------------------

func _play_idle() -> void:
	var anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if anim and anim.has_animation("mixamo_com"):
		anim.get_animation("mixamo_com").loop_mode = Animation.LOOP_LINEAR
		anim.play("mixamo_com")

# --- UI construction ---------------------------------------------------------

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	pages["Lobby"] = lobby_page._build_lobby()
	pages["Character"] = character_page._build_character()
	pages["Abilities & Talents"] = _build_abilities_page()
	pages["Skill Cards"] = cards_page._build_cards_page()
	pages["Bank"] = bank_page._build_bank_page()
	pages["Queue"] = queue_page._build_queue_page()
	for p in pages.values():
		ui.add_child(p)

	_build_nav_bar()

	play_button = Button.new()
	play_button.text = "PLAY"
	play_button.anchor_left = 1.0
	play_button.anchor_right = 1.0
	play_button.anchor_top = 1.0
	play_button.anchor_bottom = 1.0
	play_button.offset_left = -250
	play_button.offset_right = -30
	play_button.offset_top = -100
	play_button.offset_bottom = -30
	play_button.add_theme_font_size_override("font_size", 30)
	play_button.add_theme_color_override("font_color", Color(0.1, 0.07, 0.03))
	play_button.add_theme_color_override("font_hover_color", Color(0.1, 0.07, 0.03))
	play_button.add_theme_color_override("font_pressed_color", Color(0.1, 0.07, 0.03))
	play_button.add_theme_stylebox_override("normal", _box(C_ACCENT, Color(1, 0.9, 0.6), 2, 8))
	play_button.add_theme_stylebox_override("hover", _box(C_ACCENT.lightened(0.15), Color(1, 0.95, 0.75), 2, 8))
	play_button.add_theme_stylebox_override("pressed", _box(C_ACCENT.darkened(0.15), Color(1, 0.9, 0.6), 2, 8))
	play_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	play_button.pressed.connect(_on_play)
	ui.add_child(play_button)

	# Friends & party panel sits left of Play.
	friends_button = UI.button("Friends", 20, Vector2(0, 0))
	friends_button.pressed.connect(lobby_page._toggle_social)
	friends_button.anchor_left = 1.0
	friends_button.anchor_right = 1.0
	friends_button.anchor_top = 1.0
	friends_button.anchor_bottom = 1.0
	friends_button.offset_left = -410
	friends_button.offset_right = -265
	friends_button.offset_top = -100
	friends_button.offset_bottom = -30
	friends_button.tooltip_text = "Friends & party"
	ui.add_child(friends_button)

	lobby_page.social = SOCIAL_PANEL.new()
	lobby_page.social.visible = false
	ui.add_child(lobby_page.social)

	lobby_page._queue_banner = _label("", 17, Color(0.55, 0.9, 1.0))
	lobby_page._queue_banner.anchor_left = 0.5
	lobby_page._queue_banner.anchor_right = 0.5
	lobby_page._queue_banner.offset_left = -400
	lobby_page._queue_banner.offset_right = 400
	lobby_page._queue_banner.offset_top = 46
	lobby_page._queue_banner.offset_bottom = 90
	lobby_page._queue_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_page._queue_banner.visible = false
	ui.add_child(lobby_page._queue_banner)

	_build_xp_bar()
	esc._build_esc_menu()

# --- XP bar (bottom center, every tab) -----------------------------------------

const XP_BAR_W := 640.0
var _xp_fill: ColorRect
var _xp_label: Label

func _build_xp_bar() -> void:
	var root := Control.new()
	root.anchor_left = 0.5
	root.anchor_right = 0.5
	root.anchor_top = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = -XP_BAR_W / 2.0
	root.offset_right = XP_BAR_W / 2.0
	root.offset_top = -20
	root.offset_bottom = -6
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	_xp_fill = ColorRect.new()
	_xp_fill.color = Color(0.6, 0.35, 0.95)
	_xp_fill.position = Vector2(1, 1)
	_xp_fill.size = Vector2(0, 12)
	_xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_xp_fill)
	_xp_label = UI.label("", 12, Color.WHITE)
	_xp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(_xp_label)
	get_node("/root/PlayerData").changed_late.connect(_update_xp_bar)
	get_node("/root/SignalBus").xp_changed.connect(_on_xp_changed)
	_update_xp_bar()

func _on_xp_changed(_l, _x, _n) -> void:
	_update_xp_bar()

var _shards_label: Label

func _refresh_shards() -> void:
	if is_instance_valid(_shards_label):
		_shards_label.text = "Rune Shards: %d" % int(get_node("/root/PlayerData").rune_shards)

func _update_xp_bar() -> void:
	var pd := get_node("/root/PlayerData")
	var need: int = pd.xp_to_next(pd.level)
	# At max level there is nothing left to earn: the whole bar is hidden.
	(_xp_fill.get_parent() as Control).visible = need > 0
	if need <= 0:
		return
	_xp_fill.size.x = (XP_BAR_W - 2.0) * clampf(float(pd.xp) / need, 0.0, 1.0)
	_xp_label.text = "Level %d  •  %d / %d XP" % [pd.level, pd.xp, need]

# --- Esc menu (Resume / Settings / Quit) --------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if wipe_panel.visible:
			esc._back_from_wipe()
		elif settings_panel.visible:
			esc._back_from_settings()
		elif esc_menu.visible:
			esc._hide_esc()
		elif book_search._search_query != "" and pages["Abilities & Talents"].visible:
			book_search._clear_search()   # Esc clears the search first
		elif pacts_page._pacts_page and pacts_page._pacts_page.visible and pages["Abilities & Talents"].visible:
			pacts_page._close_pacts()   # Esc closes the Pacts page first
		elif _book and _book.visible and pages["Abilities & Talents"].visible:
			_close_book()   # Esc closes an open book first
		elif pages["Queue"].visible:
			_show_page("Lobby")   # Esc backs out of the Play screen
		else:
			esc._show_overlay(esc_menu)

func _build_nav_bar() -> void:
	var bar := PanelContainer.new()
	bar.anchor_right = 1.0
	bar.offset_bottom = 40
	bar.add_theme_stylebox_override("panel", _box(Color(0.04, 0.045, 0.06, 0.95), C_BORDER, 0, 0, [0, 0, 0, 2]))
	ui.add_child(bar)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)

	var group := ButtonGroup.new()
	# The Queue screen has no tab: it opens from the PLAY button.
	for page_name in ["Lobby", "Character", "Abilities & Talents", "Skill Cards", "Bank"]:
		var b := Button.new()
		b.text = page_name
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(128, 34)
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_color_override("font_color", C_TEXT_DIM)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", C_ACCENT)
		b.add_theme_color_override("font_hover_pressed_color", C_ACCENT)
		b.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4))
		b.add_theme_stylebox_override("hover", _box(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 0, 4))
		b.add_theme_stylebox_override("pressed", _box(Color(1, 1, 1, 0.04), C_ACCENT, 0, 0, [0, 0, 0, 3]))
		b.add_theme_stylebox_override("hover_pressed", _box(Color(1, 1, 1, 0.07), C_ACCENT, 0, 0, [0, 0, 0, 3]))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(_show_page.bind(page_name))
		row.add_child(b)
		nav_buttons[page_name] = b

	# Cogwheel (top right): opens the Esc menu (Settings, Wipe Save, Quit...).
	var cog := Button.new()
	cog.focus_mode = Control.FOCUS_NONE
	cog.anchor_left = 1.0
	cog.anchor_right = 1.0
	cog.offset_left = -44
	cog.offset_right = -10
	cog.offset_top = 3
	cog.offset_bottom = 37
	cog.tooltip_text = "Menu (Esc)"
	cog.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6))
	cog.add_theme_stylebox_override("hover", _box(Color(1, 1, 1, 0.07), C_BORDER, 1, 6))
	cog.add_theme_stylebox_override("pressed", _box(Color(1, 1, 1, 0.1), C_ACCENT, 1, 6))
	cog.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var gear := Control.new()
	gear.set_anchors_preset(Control.PRESET_FULL_RECT)
	gear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear.draw.connect(func(): _draw_cog(gear, C_ACCENT if gear.get_meta("hot", false) else C_TEXT_DIM.lightened(0.25)))
	cog.add_child(gear)
	cog.mouse_entered.connect(func():
		gear.set_meta("hot", true)
		gear.queue_redraw())
	cog.mouse_exited.connect(func():
		gear.set_meta("hot", false)
		gear.queue_redraw())
	cog.pressed.connect(esc._toggle_esc_menu)
	ui.add_child(cog)

## A cogwheel icon: toothed ring with a hole.
func _draw_cog(c: Control, col: Color) -> void:
	var mid := c.size / 2.0
	var r := minf(c.size.x, c.size.y) * 0.3
	var teeth := 8
	for i in teeth:
		var a := TAU * i / teeth
		var d := Vector2(cos(a), sin(a))
		var side := Vector2(-d.y, d.x) * r * 0.22
		var inner := mid + d * r * 0.8
		var outer := mid + d * r * 1.32
		c.draw_colored_polygon(PackedVector2Array([inner - side, outer - side * 0.8, outer + side * 0.8, inner + side]), col)
	c.draw_circle(mid, r, col)
	c.draw_circle(mid, r * 0.42, Color(0.04, 0.045, 0.06))

func _full_rect_page() -> Control:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return page

# --- Abilities & Talents -----------------------------------------------------------
# Top: the action bar (drag abilities onto it, drag them off to remove).
# Below: a shelf of books, one per category. Opening a book shows that
# category's abilities on the left page and its talent tree on the right page.
# Talent rows unlock globally: 3 points in a row of ANY tree opens the next row
# in EVERY tree, so trees can be mixed freely.

const Abilities = preload("res://scripts/abilities.gd")
const Categories = preload("res://scripts/categories.gd")
const PAGE_BG := Color(0.12, 0.105, 0.085, 0.98)
const PAGE_BORDER := Color(0.32, 0.26, 0.18)
const INK := Color(0.93, 0.88, 0.78)
const INK_DIM := Color(0.62, 0.57, 0.5)

var _talent_points_label: Label
# Search (one bar at the top of the page): on the shelf it lists matches to pick
# from; in an open book it highlights them. Hovering an ability or a talent
# highlights everything that mentions it (or that it mentions).
const Keywords = preload("res://scripts/core/keywords.gd")
# --- Pacts: the tab above Rune Spells, and the page it opens ------------------------------
# One Pact at a time (scripts/pacts.gd; PlayerData.pact). It can only be changed
# here, so once a dungeon starts it is locked in.

const Pacts = preload("res://scripts/pacts.gd")
# --- Skill Cards: a loadout that guarantees abilities in level-up drafts ------------

const SkillCards = preload("res://scripts/skill_cards.gd")
# --- Queue: pick a dungeon and go in --------------------------------------------
# "Random Dungeon" is the real queue: you (and your party) get sent into a random
# dungeon from the pool. Below it every dungeon can be joined on its own - for
# testing. Enemy level = the group's average pulled toward its highest level.

const DB = preload("res://scripts/dungeon/dungeon_db.gd")

func _build_empty_page(title: String) -> Control:
	var page := _full_rect_page()
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -380
	panel.offset_right = 380
	panel.offset_top = -230
	panel.offset_bottom = 260
	panel.add_theme_stylebox_override("panel", _box(Color(0.05, 0.055, 0.075, 0.96), C_BORDER, 2, 10))
	page.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var t := _label(title, 28, C_ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := _label("Nothing here yet.", 16, C_TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	return page

# --- Behaviour ---------------------------------------------------------------

func _refresh_abilities() -> void:
	talent_tree._refresh_talents()
	pacts_page._refresh_pacts()
	if _book_cat != "":
		_refresh_book_abilities()
	if _book_cat == Categories.RUNE:
		_refresh_rune_page()

func _show_page(page_name: String) -> void:
	for k in pages:
		pages[k].visible = (k == page_name)
	if nav_buttons.has(page_name):
		nav_buttons[page_name].button_pressed = true
	else:
		for b in nav_buttons.values():
			b.set_pressed_no_signal(false)
	if page_name == "Queue":
		queue_page._refresh_queue()
	play_button.visible = (page_name == "Lobby")
	friends_button.visible = (page_name == "Lobby")
	if is_instance_valid(_chat_layer):
		_chat_layer.visible = page_name == "Lobby"   # the chat only shows in the Lobby
	if lobby_page.social and page_name != "Lobby" and page_name != "Queue":
		lobby_page.social.visible = false
	# Hide the 3D character behind full-panel pages.
	var shows_player := page_name in ["Lobby", "Character"]
	model.visible = shows_player
	$Pedestal.visible = shows_player

## PLAY opens the dungeon / queue screen.
func _on_play() -> void:
	_show_page("Queue")

# --- Helpers -----------------------------------------------------------------

func _padded(sb: StyleBoxFlat, m: int = 12) -> StyleBoxFlat:
	sb.content_margin_left = m
	sb.content_margin_right = m
	sb.content_margin_top = m - 2
	sb.content_margin_bottom = m - 2
	return sb

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# borders: [left, top, right, bottom] widths; overrides `border` when given.
func _box(bg: Color, border_color: Color, border: int, radius: int, borders: Array = []) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border_color
	if borders.size() == 4:
		sb.border_width_left = borders[0]
		sb.border_width_top = borders[1]
		sb.border_width_right = borders[2]
		sb.border_width_bottom = borders[3]
	else:
		sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

# --- Part: Shelf: the Abilities & Talents page, one book per category --------
var _shelf: PanelContainer
var _shelf_info := {}          # category -> Label (abilities / points summary)
## Highlight the open book's button in the quick switcher.
func _refresh_book_tabs() -> void:
	for c in _book_tab_buttons:
		var b: Button = _book_tab_buttons[c]
		var col := Categories.color(c)
		var on: bool = c == _book_cat
		b.add_theme_stylebox_override("normal", UI.box(col.darkened(0.7) if on else UI.BG, col if on else col.darkened(0.45), 2 if on else 1, 6))
		b.add_theme_stylebox_override("hover", UI.box(col.darkened(0.6), col, 2, 6))
var _shelf_browse: Array[Control] = []   # the shelf's books (hidden while results show)
var _shelf_hint: Label
const SHELF_HINT := "Open a book to see its abilities and talents  •  3 talent points in a row of any book unlock the next row in every book"
func _build_abilities_page() -> Control:
	var page := _full_rect_page()
	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 24
	outer.offset_right = -24
	outer.offset_top = 46
	outer.offset_bottom = -8
	outer.add_theme_constant_override("separation", 4)
	page.add_child(outer)

	# Header: talent points + reset, and (while a book is open) the book switcher.
	# No action bar here: learned abilities go on the bar in game (Spellbook, P).
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	outer.add_child(head)
	# A spacer as wide as the points/reset group on the right, so the book icons
	# sit in the true middle of the screen.
	# (It also holds the search bar: wide on the shelf, compact beside the book icons.)
	var mirror := HBoxContainer.new()
	mirror.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(mirror)
	book_search._search_edit = LineEdit.new()
	book_search._search_edit.placeholder_text = "Search abilities and talents  (name or keyword, e.g. chill)"
	book_search._search_edit.clear_button_enabled = true
	book_search._search_edit.custom_minimum_size = Vector2(460, 26)
	book_search._search_edit.add_theme_font_size_override("font_size", 13)
	book_search._search_edit.add_theme_stylebox_override("normal", _padded(UI.box(Color(0, 0, 0, 0.4), C_BORDER, 1, 6), 8))
	book_search._search_edit.add_theme_stylebox_override("focus", _padded(UI.box(Color(0, 0, 0, 0.5), C_ACCENT, 1, 6), 8))
	book_search._search_edit.text_changed.connect(book_search._on_search_changed)
	book_search._search_edit.text_submitted.connect(func(_t): book_search._search_edit.release_focus())
	mirror.add_child(book_search._search_edit)
	_book_tabs = HFlowContainer.new()
	_book_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_book_tabs.alignment = FlowContainer.ALIGNMENT_CENTER
	_book_tabs.add_theme_constant_override("h_separation", 3)
	_book_tabs.add_theme_constant_override("v_separation", 3)
	_book_tabs.visible = false
	head.add_child(_book_tabs)
	for cat in [Categories.RUNE] + Categories.ORDER:   # Rune Spells first, then the books
		var c: String = cat
		var tb := Button.new()   # the book's element emblem; name in the tooltip
		tb.focus_mode = Control.FOCUS_NONE
		tb.custom_minimum_size = Vector2(28, 28)
		tb.tooltip_text = Categories.cat_name(c)
		tb.pressed.connect(func(): _open_book(c))
		var em := Control.new()
		em.set_anchors_preset(Control.PRESET_FULL_RECT)
		em.offset_left = 3
		em.offset_top = 3
		em.offset_right = -3
		em.offset_bottom = -3
		em.mouse_filter = Control.MOUSE_FILTER_IGNORE
		em.draw.connect(func(): Categories.draw_emblem(em, c))
		tb.add_child(em)
		_book_tabs.add_child(tb)
		_book_tab_buttons[c] = tb
	var right_grp := HBoxContainer.new()
	right_grp.add_theme_constant_override("separation", 8)
	head.add_child(right_grp)
	# Shelf: the search bar takes the free space. Book open: it shrinks to the
	# width of the group on the right, so the book icons stay centred.
	var fit_search := func():
		var open: bool = _book_tabs.visible
		mirror.size_flags_horizontal = Control.SIZE_FILL if open else Control.SIZE_EXPAND_FILL
		mirror.custom_minimum_size.x = right_grp.size.x if open else 0.0
		book_search._search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL if open else Control.SIZE_SHRINK_BEGIN
		book_search._search_edit.custom_minimum_size.x = 0.0 if open else 460.0
		book_search._search_edit.placeholder_text = "Search this book" if open \
			else "Search abilities and talents  (name or keyword, e.g. chill)"
	_book_tabs.visibility_changed.connect(fit_search)
	right_grp.resized.connect(fit_search)
	_talent_points_label = UI.label("", 12, Color.WHITE)
	_talent_points_label.custom_minimum_size = Vector2(250, 0)   # fixed width: the icons never shift
	_talent_points_label.clip_text = true                         # (a Label grows with its text otherwise, and they would)
	_talent_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_talent_points_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right_grp.add_child(_talent_points_label)
	var reset := UI.button("Reset", 11, Vector2(56, 22))
	reset.tooltip_text = "Reset all talents"
	reset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reset.pressed.connect(func(): get_node("/root/PlayerData").reset_talents())
	right_grp.add_child(reset)

	# Shelf (category books) / open book
	var area := Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(area)
	_shelf = _build_shelf()
	area.add_child(_shelf)
	_book = _build_book()
	_book.visible = false
	area.add_child(_book)
	pacts_page._pacts_page = pacts_page._build_pacts_page()   # opened by the Pacts tab on the shelf
	pacts_page._pacts_page.visible = false
	area.add_child(pacts_page._pacts_page)

	var pd := get_node("/root/PlayerData")
	pd.changed_late.connect(_refresh_abilities)
	_refresh_abilities.call_deferred()
	return page

## Dropping an ability dragged from the bar onto `c` removes it from the bar.
func _accept_bar_drop(c: Control) -> void:
	c.set_drag_forwarding(
		func(_pos): return null,
		func(_pos, data): return data is Dictionary and data.get("type") == "ability" and int(data["from"]) >= 0,
		func(_pos, data): get_node("/root/PlayerData").clear_action_slot(int(data["from"])))

func _build_shelf() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _padded(UI.box(Color(0.05, 0.055, 0.075, 0.96), C_BORDER, 2, 10), 12))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.add_child(UI.label("Spellbooks", 20, C_ACCENT))
	var hint := UI.label(SHELF_HINT, 12, C_TEXT_DIM)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hint)
	_shelf_hint = hint
	v.add_child(head)
	# Search results (shown instead of the books while something is typed).
	book_search._search_results = ScrollContainer.new()
	book_search._search_results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	book_search._search_results.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	book_search._search_results.visible = false
	v.add_child(book_search._search_results)
	book_search._search_list = GridContainer.new()
	book_search._search_list.columns = 3
	book_search._search_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book_search._search_list.add_theme_constant_override("h_separation", 8)
	book_search._search_list.add_theme_constant_override("v_separation", 6)
	book_search._search_results.add_child(book_search._search_list)
	# Two slim tabs above the books: Pacts, then the spells taught by runes. Together
	# they are exactly as tall as the one Rune Spells tab used to be, so the books
	# did not move when Pacts were added.
	var rune_tab := VBoxContainer.new()
	rune_tab.add_theme_constant_override("separation", PactsPage.SHELF_TAB_GAP)
	rune_tab.add_child(pacts_page._shelf_pact_tab())
	rune_tab.add_child(_shelf_rune_tab())
	v.add_child(rune_tab)
	var grid := GridContainer.new()
	grid.columns = Categories.shelf_columns(Categories.ORDER.size())   # two even rows of books
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for cat in Categories.ORDER:
		grid.add_child(_shelf_book(cat))
	_shelf_browse = [rune_tab, grid]
	return panel

## The unique tab above the books: spells taught by runes (Frostfire Bolt).
## It opens like a book, but with the runes that teach them instead of talents.
func _shelf_rune_tab() -> Button:
	var cat: String = Categories.RUNE
	var col := Categories.color(cat)
	var cover := col.darkened(0.8)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, PactsPage.SHELF_TAB_HEIGHT)   # (it shares the height it had with the Pacts tab: the books stay where they were)
	b.tooltip_text = "%s\n%s" % [Categories.cat_name(cat), Categories.desc(cat)]
	b.add_theme_stylebox_override("normal", _box(cover, col.darkened(0.25), 0, 8, [2, 2, 2, 3]))
	b.add_theme_stylebox_override("hover", _box(cover.lightened(0.06), col, 0, 8, [3, 3, 3, 3]))
	b.add_theme_stylebox_override("pressed", _box(cover.lightened(0.1), col.lightened(0.2), 0, 8, [3, 3, 3, 3]))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(_open_book.bind(cat))
	_accept_bar_drop(b)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.offset_top = 2
	row.offset_bottom = -3
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var emblem := Control.new()
	emblem.custom_minimum_size = Vector2(20, 20)
	emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.draw.connect(func(): Categories.draw_emblem(emblem, cat))
	row.add_child(emblem)
	var name_l := _label(Categories.cat_name(cat), 15, col.lightened(0.35))
	name_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_l)
	var desc := _label(Categories.desc(cat), 12, C_TEXT_DIM)
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	desc.clip_text = true
	row.add_child(desc)
	var info := _label("", 12, C_TEXT_DIM)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)
	_shelf_info[cat] = info
	return b

func _shelf_book(cat: String) -> Button:
	var col := Categories.color(cat)
	var cover := col.darkened(0.78)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 130)
	b.tooltip_text = "%s\n%s" % [Categories.cat_name(cat), Categories.desc(cat)]
	b.add_theme_stylebox_override("normal", _box(cover, col.darkened(0.25), 0, 8, [12, 2, 2, 2]))
	b.add_theme_stylebox_override("hover", _box(cover.lightened(0.06), col, 0, 8, [12, 3, 3, 3]))
	b.add_theme_stylebox_override("pressed", _box(cover.lightened(0.1), col.lightened(0.2), 0, 8, [12, 3, 3, 3]))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(_open_book.bind(cat))
	_accept_bar_drop(b)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_right = -8
	v.offset_top = 8
	v.offset_bottom = -8
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var emblem := Control.new()
	emblem.custom_minimum_size = Vector2(56, 56)
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem.draw.connect(func(): Categories.draw_emblem(emblem, cat))
	v.add_child(emblem)
	var name_l := _label(Categories.cat_name(cat), 20, col.lightened(0.35))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	var info := _label("", 12, C_TEXT_DIM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)
	_shelf_info[cat] = info
	return b

# --- Part: The open book: abilities (left page) + rune page --------
var _book: PanelContainer
var _book_cat := ""            # open book's category ("" = shelf showing)
var _book_emblem: Control
var _book_title: Label
var _book_sub: Label
var _book_abilities: VBoxContainer
var _book_tabs: HFlowContainer
var _book_tab_buttons := {}   # category -> its quick-switch button

var _ability_cells := {}        # ability id -> its cell in the open book
func _build_book() -> PanelContainer:
	var book := PanelContainer.new()
	book.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	book.add_child(v)

	# Top frame: [Books] Abilities + hint  |  emblem + book name (centered)  |  Talents + hint
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var left_head := HBoxContainer.new()
	left_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_head.add_theme_constant_override("separation", 10)
	head.add_child(left_head)
	var back := UI.button("◀  Books", 13, Vector2(88, 28))
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_close_book)
	left_head.add_child(back)
	_head_section(left_head, "Abilities", "Grayed out = not learned. Put learned abilities on your bar in game (Spellbook, P).")

	var mid := VBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.custom_minimum_size = Vector2(460, 0)   # fixed: changing text never reflows the header
	mid.add_theme_constant_override("separation", 0)
	head.add_child(mid)
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 8)
	mid.add_child(title_row)
	_book_emblem = Control.new()
	_book_emblem.custom_minimum_size = Vector2(26, 26)
	_book_emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_book_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book_emblem.draw.connect(func(): Categories.draw_emblem(_book_emblem, _book_cat))
	title_row.add_child(_book_emblem)
	_book_title = _label("", 22, Color.WHITE)
	title_row.add_child(_book_title)
	_book_sub = _label("", 11, C_TEXT_DIM)
	_book_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_book_sub.clip_text = true
	_book_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mid.add_child(_book_sub)

	var right_head := HBoxContainer.new()
	right_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_head.add_theme_constant_override("separation", 10)
	head.add_child(right_head)
	_book_right_head = _head_section(right_head, "Talents", TALENT_HINT)

	var spread := HBoxContainer.new()   # the open book's two pages
	spread.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spread.add_theme_constant_override("separation", 0)
	v.add_child(spread)
	var left := _book_page(0.7)
	spread.add_child(left)
	var spine := ColorRect.new()
	spine.color = Color(0.05, 0.035, 0.02)
	spine.custom_minimum_size = Vector2(8, 0)
	spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spread.add_child(spine)
	var right := _book_page(1.0)
	spread.add_child(right)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_book_abilities = VBoxContainer.new()   # one divider + 2-column grid per spec
	_book_abilities.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_book_abilities.add_theme_constant_override("separation", 6)
	scroll.add_child(_book_abilities)
	# The talent grid scales itself to fill this page (no scrolling).
	talent_tree._book_tree = Control.new()
	talent_tree._book_tree.clip_contents = true
	talent_tree._book_tree.mouse_filter = Control.MOUSE_FILTER_PASS
	talent_tree._book_tree.resized.connect(talent_tree._layout_talent_canvas)
	right.add_child(talent_tree._book_tree)
	# Rune Spells have no talents: this page lists the runes that teach them instead.
	_rune_page = VBoxContainer.new()
	_rune_page.add_theme_constant_override("separation", 8)
	_rune_page.visible = false
	right.add_child(_rune_page)
	return book

const TALENT_HINT := "Left-click: invest  •  Right-click: refund  •  3 points in a row (any book) open the next row in every book  •  Maxing a talent opens the talents its lines point to"
const RUNE_HINT := "A rune spell is known while its rune is on your gear. Engrave runes in the Runes screen (Character page)."
var _book_right_head: Array = []   # [title Label, hint Label] over the right page
var _rune_page: VBoxContainer

## "Title  hint" for the book's top frame. Returns [title Label, hint Label].
func _head_section(parent: HBoxContainer, title: String, hint_text: String) -> Array:
	var t := _label(title, 18, INK)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(t)
	var hint := _label(hint_text, 11, INK_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(hint)
	return [t, hint]

## The Rune Spells book's right page: every rune that teaches a spell, and
## whether you have it on, know it, or haven't found it.
func _refresh_rune_page() -> void:
	for c in _rune_page.get_children():
		c.queue_free()
	var pd := get_node("/root/PlayerData")
	var intro := _label("Rune spells are never drafted and have no talents of their own. You know one while its rune is on your gear, and it follows the talents, runes and procs of every school it belongs to.", 13, INK_DIM)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rune_page.add_child(intro)
	var worn: Array = pd.rune_spells()
	for rid in Runes.TEACHES:
		var rune_id: String = rid
		var spell := Runes.spell_of(rune_id)
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _padded(UI.box(Color(0, 0, 0, 0.25), PAGE_BORDER, 1, 5), 8))
		row.tooltip_text = Runes.tooltip(rune_id)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(h)
		var glyph := Control.new()
		glyph.custom_minimum_size = Vector2(34, 34)
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.draw.connect(func(): Runes.draw_glyph(glyph, glyph.size / 2.0, 14.0, rune_id))
		h.add_child(glyph)
		var names := VBoxContainer.new()
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.add_theme_constant_override("separation", 0)
		names.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(names)
		names.add_child(_label("%s  (%s)" % [Runes.rune_name(rune_id), Runes.rarity_name(rune_id)], 15, Runes.rarity_color(rune_id)))
		names.add_child(_label("Teaches %s" % Abilities.ability_name(spell), 12, INK))
		var state := _label("Not found yet", 12, Color(0.8, 0.5, 0.45))
		if worn.has(spell):
			state.text = "On your gear"
			state.add_theme_color_override("font_color", Color(0.55, 0.9, 0.55))
		elif pd.known_runes.has(rune_id):
			state.text = "Known: not on your gear"
			state.add_theme_color_override("font_color", C_ACCENT)
		state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(state)
		_rune_page.add_child(row)

func _book_page(ratio: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = ratio
	p.add_theme_stylebox_override("panel", _padded(UI.box(PAGE_BG, PAGE_BORDER, 1, 4), 8))
	return p

func _open_book(cat: String) -> void:
	_book_cat = cat
	var col := Categories.color(cat)
	_book.add_theme_stylebox_override("panel", _padded(UI.box(col.darkened(0.8), col.darkened(0.2), 3, 12), 10))
	_book_title.text = Categories.cat_name(cat)
	_book_title.add_theme_color_override("font_color", col.lightened(0.35))
	_book_emblem.queue_redraw()
	var runes: bool = cat == Categories.RUNE
	talent_tree._book_tree.visible = not runes
	_rune_page.visible = runes
	if _book_right_head.size() == 2:
		(_book_right_head[0] as Label).text = "Runes" if runes else "Talents"
		(_book_right_head[1] as Label).text = RUNE_HINT if runes else TALENT_HINT
	talent_tree._build_talent_tree()
	_shelf.visible = false
	_book.visible = true
	_book_tabs.visible = true
	_refresh_book_tabs()
	_refresh_abilities()
	book_search._update_marks()

func _close_book() -> void:
	_book_cat = ""
	talent_tree._talent_buttons.clear()
	_ability_cells.clear()
	book_search._hover_key = ""
	book_search._search_focus = ""
	talent_tree._row_status.clear()
	_book.visible = false
	_book_tabs.visible = false
	_shelf.visible = true
	book_search._refresh_search()

func _refresh_book_abilities() -> void:
	for c in _book_abilities.get_children():
		c.queue_free()
	_ability_cells.clear()
	var specs := Abilities.specs_in(_book_cat)
	if specs.is_empty():
		_book_abilities.add_child(_label("No abilities in this book yet.", 14, INK_DIM))
		return
	var pd := get_node("/root/PlayerData")
	var col := Categories.color(_book_cat).lightened(0.35)
	for spec in specs:
		if spec[0] != "":
			_book_abilities.add_child(UI.spec_divider(spec[0], col, 14))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		_book_abilities.add_child(grid)
		for id in spec[1]:
			var cell := _book_ability_cell(pd, id)
			grid.add_child(cell)
			_ability_cells[id] = cell
			book_search._add_mark(cell)
			book_search._wire_hover(cell, "a:" + id)
	book_search._update_marks()

## One ability on the book's left page: icon + name (+ learned state). Learned
## ones are bright, unlearned ones dimmed with a red name. Hover for the tooltip.
## (No dragging here: the action bar is set up in game, Spellbook on P.)
func _book_ability_cell(pd: Node, id: String) -> Button:
	var learned: bool = pd.has_ability(id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 36)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("normal", UI.box(Color(0, 0, 0, 0.25), PAGE_BORDER, 1, 5))
	b.add_theme_stylebox_override("hover", UI.box(Color(1, 1, 1, 0.06), C_ACCENT, 1, 5))
	b.add_theme_stylebox_override("pressed", UI.box(Color(1, 1, 1, 0.06), C_ACCENT, 1, 5))
	b.set_meta("tip_ability", id)   # full ability tooltip on hover
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 5
	row.offset_right = -5
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func(): Abilities.draw_icon(icon, id))
	if not learned:
		icon.modulate = Color(0.5, 0.5, 0.5, 0.6)   # grayed out
	row.add_child(icon)
	var n := _label(Abilities.ability_name(id), 14, Color.WHITE if learned else Color(1.0, 0.45, 0.4))
	n.clip_text = true
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(n)
	return b
