extends Node3D
class_name MainMenu

# Main menu: 3D player on a pedestal with UI layered on top.
# Tabs: Lobby (party slots + Play), Character (gear slots), Abilities & Talents
# (category books), Skill Cards, Bank, Queue.

# --- Components ----------------------------------------------------------------------------
# Each tab's own code lives in a part (scripts/menu/*.gd, see menu_part.gd), made
# here as a child node; SPLIT_HOST=menu tools/split_batch.sh adds the line for each one.
var shelf: ShelfPage = _part(ShelfPage) as ShelfPage
var open_book: OpenBook = _part(OpenBook) as OpenBook
var talent_tree: TalentTreePage = _part(TalentTreePage) as TalentTreePage
var pacts_page: PactsPage = _part(PactsPage) as PactsPage
var book_search: BookSearch = _part(BookSearch) as BookSearch
var cards_page: CardsPage = _part(CardsPage) as CardsPage
var character_page: CharacterPage = _part(CharacterPage) as CharacterPage
var lobby_page: LobbyPage = _part(LobbyPage) as LobbyPage
var esc: EscMenuPart = _part(EscMenuPart) as EscMenuPart
var bank_page: BankPage = _part(BankPage) as BankPage
var queue_page: QueuePage = _part(QueuePage) as QueuePage
var ready_check: ReadyCheckPart = _part(ReadyCheckPart) as ReadyCheckPart
var loadouts: LoadoutsPart = _part(LoadoutsPart) as LoadoutsPart
var whats_new: WhatsNewPart = _part(WhatsNewPart) as WhatsNewPart
var last_run: LastRunPart = _part(LastRunPart) as LastRunPart

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
const RuneScreens = preload("res://scripts/ui/rune_screens.gd")
const RuneManager = preload("res://scripts/ui/rune_manager.gd")
const MacroWindow = preload("res://scripts/ui/macro_window.gd")
const Abilities = preload("res://scripts/abilities.gd")
const Categories = preload("res://scripts/categories.gd")
const Keywords = preload("res://scripts/core/keywords.gd")
const Pacts = preload("res://scripts/pacts.gd")
const SkillCards = preload("res://scripts/skill_cards.gd")
const DB = preload("res://scripts/dungeon/dungeon_db.gd")
const BuildInfo = preload("res://scripts/core/build_info.gd")
const InspectWindow = preload("res://scripts/ui/inspect_window.gd")
const MessageBanner = preload("res://scripts/ui/message_banner.gd")

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
	get_node("/root/PlayerData").changed_late.connect(lobby_page._my_info_changed)
	bank_page._wire_bank()
	character_page._wire_gear()
	# Party / online
	var online := get_node("/root/Online")
	var net := get_node("/root/Net")
	online.changed.connect(lobby_page._refresh_party)
	net.members_changed.connect(lobby_page._refresh_party)
	online.toast.connect(_toast_ok)
	net.system_message.connect(_toast_ok)
	net.inspect_received.connect(_on_inspect)
	get_node("/root/SignalBus").action_error.connect(_toast_if)   # (errors raised outside the menu's own code)
	lobby_page._refresh_party()

# --- Input, per-frame updates and toasts ---------------------------------------------

var _toast: Control   # MessageBanner: errors and notes, framed, low on the screen

func _toast_ok(msg: String) -> void:
	_banner().show_message(msg, Color(0.55, 1.0, 0.55))

func _banner() -> Control:
	if _toast == null:
		_toast = MessageBanner.new()
		_toast.bottom = -30.0   # just above the XP bar
		ui.add_child(_toast)
	return _toast

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ALT:
		if character_page._hovered_slot != "" and pages["Character"].visible:
			character_page._open_alt_popup()

func _process(delta: float) -> void:
	lobby_page._update_queue_banner()
	lobby_page._layout_party_3d()
	lobby_page._tick_my_info(delta)
	ready_check.update()
	cards_page._check_bar_drag_end()
	character_page._update_gear_highlights()
	character_page._update_alt_popup(delta)
	_update_spin(delta)

func _toast_if(msg: String) -> void:
	if msg != "":
		_banner().show_message(msg, MessageBanner.ERROR)

# --- The 3D player on the pedestal -----------------------------------------------------

func _play_idle() -> void:
	var anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if anim and anim.has_animation("mixamo_com"):
		anim.get_animation("mixamo_com").loop_mode = Animation.LOOP_LINEAR
		anim.play("mixamo_com")

# Drag on empty space (Lobby, Character) to turn your character; it turns back to
# face the camera SPIN_RETURN_DELAY s after you let go.
const SPIN_PER_PIXEL := 0.012
const SPIN_RETURN_DELAY := 2.0
const SPIN_RETURN_SPEED := 4.0
var _spin := 0.0
var _spinning := false
var _spin_idle := 0.0

func _spin_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_spinning = event.pressed and model.visible
		if not event.pressed:
			_spin_idle = SPIN_RETURN_DELAY
	elif event is InputEventMouseMotion and _spinning:
		_spin += event.relative.x * SPIN_PER_PIXEL

func _update_spin(delta: float) -> void:
	if not _spinning and _spin != 0.0:
		_spin_idle -= delta
		if _spin_idle <= 0.0:
			_spin = wrapf(_spin, -PI, PI)
			_spin = move_toward(_spin, 0.0, absf(_spin) * SPIN_RETURN_SPEED * delta + 0.002)
	model.rotation.y = _spin

# --- UI construction ---------------------------------------------------------

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	pages["Lobby"] = lobby_page._build_lobby()
	pages["Character"] = character_page._build_character()
	pages["Abilities & Talents"] = shelf._build_abilities_page()
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
	for state in [["normal", C_ACCENT, Color(1, 0.9, 0.6)], ["hover", C_ACCENT.lightened(0.15), Color(1, 0.95, 0.75)],
			["pressed", C_ACCENT.darkened(0.15), Color(1, 0.9, 0.6)]]:
		var sb := _box(state[1], state[2], 2, 8)
		sb.content_margin_bottom = 18   # room for the line below PLAY
		play_button.add_theme_stylebox_override(state[0], sb)
	play_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	play_button.pressed.connect(_on_play)
	ui.add_child(play_button)
	# Where PLAY goes: the Play screen's last choice and difficulty.
	_play_where = _label("", 13, Color(0.25, 0.17, 0.06))
	_play_where.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_play_where.offset_top = -24
	_play_where.offset_bottom = -6
	_play_where.offset_left = 6
	_play_where.offset_right = -6
	_play_where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play_where.clip_text = true
	_play_where.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_button.add_child(_play_where)

	# Build version under Play (party members must match).
	var ver := _label("Version %s" % BuildInfo.version(), 13, C_TEXT_DIM)
	ver.anchor_left = 1.0
	ver.anchor_right = 1.0
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = -250
	ver.offset_right = -30
	ver.offset_top = -26
	ver.offset_bottom = -6
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(ver)

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
	ready_check.build()
	whats_new.build()
	last_run.build()

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

# --- Esc key, nav bar and page frames ------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	_spin_input(event)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if InspectWindow.is_open(ui):
			InspectWindow.close(ui)
		elif wipe_panel.visible:
			esc._back_from_wipe()
		elif settings_panel.visible:
			esc._back_from_settings()
		elif esc_menu.visible:
			esc._hide_esc()
		elif book_search._search_query != "" and pages["Abilities & Talents"].visible:
			book_search._clear_search()   # Esc clears the search first
		elif pacts_page._pacts_page and pacts_page._pacts_page.visible and pages["Abilities & Talents"].visible:
			pacts_page._close_pacts()   # Esc closes the Pacts page first
		elif open_book._book and open_book._book.visible and pages["Abilities & Talents"].visible:
			open_book._close_book()   # Esc closes an open book first
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

# --- Book pages: colours shared by the Abilities & Talents parts -------------------------

const PAGE_BG := Color(0.12, 0.105, 0.085, 0.98)
const PAGE_BORDER := Color(0.32, 0.26, 0.18)
const INK := Color(0.93, 0.88, 0.78)
const INK_DIM := Color(0.62, 0.57, 0.5)

var _talent_points_label: Label

# --- Placeholder pages -------------------------------------------------------------------

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
	if open_book._book_cat != "":
		open_book._refresh_book_abilities()
	if open_book._book_cat == Categories.RUNE:
		open_book._refresh_rune_page()

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
	ready_check.refresh()
	whats_new.show_for(page_name)
	if lobby_page.social and page_name != "Lobby" and page_name != "Queue":
		lobby_page.social.visible = false
	# Hide the 3D character behind full-panel pages.
	var shows_player := page_name in ["Lobby", "Character"]
	model.visible = shows_player
	$Pedestal.visible = shows_player
	$Backdrop.visible = shows_player

## A party member's snapshot arrived (their card was clicked): show it.
func _on_inspect(member: int, data: Dictionary) -> void:
	InspectWindow.open(ui, member, data)

## PLAY opens the dungeon / queue screen.
func _on_play() -> void:
	_show_page("Queue")

var _play_where: Label

## PLAY's second line and tooltip: where you're going, party size, enemy level.
func refresh_play_button() -> void:
	if play_button == null or _play_where == null:
		return
	_play_where.text = queue_page.play_summary()
	var gm := get_node("/root/GameManager")
	var online := get_node("/root/Online")
	var lead := "Choose a dungeon" if online.is_leader() else "See where your party is going (only the leader can queue or start)"
	play_button.tooltip_text = "%s.\nParty: %d / %d   •   Enemy level: %d" % [lead, online.party_size(), online.max_party(),
		DB.party_level(gm.party_levels())]

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
