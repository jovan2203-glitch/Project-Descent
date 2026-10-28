extends CanvasLayer


# The in-game HUD's shared core: the player, the SignalBus wiring, the per-frame
# calls into its elements, messages and the death screen. Each element (player
# and target frames, cast bars, action bars, auras, XP bar, spec bars, party
# frames) is its own file in scripts/ui/hud/ (HudElement): a new one gets its own
# file, never a section here. Their options are in UIConfig
# (scripts/ui/ui_config.gd), their places in Move UI (scripts/ui/ui_layout.gd).

@export var player_path: NodePath

const UI = preload("res://scripts/ui_kit.gd")
const Items = preload("res://scripts/items.gd")
const Abilities = preload("res://scripts/abilities.gd")
const Runes = preload("res://scripts/runes.gd")
const Balance = preload("res://scripts/balance.gd")
const HUD_DIR := "res://scripts/ui/hud/"
const ActionBar = preload("res://scripts/ui/hud/action_bar.gd")
const Auras = preload("res://scripts/ui/hud/auras.gd")
## The elements made from their own file, in drawing order.
const ELEMENTS := ["party_frames", "player_frame", "target_frame", "target_cast", "cast_bar", "xp_bar",
	"venom_bar", "wheel_strip", "chain_strip", "sharp_strip", "messages"]

var player: Node
var trackers: Node                  # scripts/ui/trackers/tracker_engine.gd
var _elements: Array = []           # every HudElement
var _by_key := {}                   # element key -> HudElement
var _error_label: Control           # the Messages element (Move UI: "Messages")
var _slow_t := 0.0

func _ready() -> void:
	player = get_node_or_null(player_path)
	for b in 4:
		_add(ActionBar.make(b))
	_add(Auras.make(false))
	_add(Auras.make(true))
	for script in ELEMENTS:
		_add(PartyFrames.new() if script == "party_frames" else load(HUD_DIR + script + ".gd").new())
	_error_label = element("messages")
	trackers = TrackerEngine.new()
	trackers.hud = self
	add_child(trackers)
	# Everything the HUD reacts to arrives through the SignalBus.
	var bus := get_node("/root/SignalBus")
	bus.level_up.connect(func(lv): _show_message("Level %d!" % lv, Color(0.8, 0.6, 1.0)))
	bus.player_died.connect(_on_player_died)
	bus.player_revived.connect(_clear_death_screen)
	bus.action_error.connect(_show_error)
	bus.item_looted.connect(func(id): _show_message("Looted: " + Items.item_name(id), Color(1.0, 0.82, 0.35)))
	bus.skill_card_unlocked.connect(func(cid): _show_message("New Skill Card: %s" % Abilities.ability_name(
		preload("res://scripts/skill_cards.gd").ability_of(cid)), Color(0.8, 0.6, 1.0)))
	bus.rune_triggered.connect(func(eid: String):
		if eid.begins_with("item:"):   # item Equip: / Use: effects
			_show_message(eid.trim_prefix("item:") + "!", Color(0.3, 0.95, 0.55))
		else:
			_show_message(Runes.rune_name(eid) + "!", Runes.color(eid).lightened(0.2)))
	var pd := get_node_or_null("/root/PlayerData")
	if pd:
		pd.changed_late.connect(_refresh_elements)
	get_node("/root/Settings").keybinds_changed.connect(_refresh_elements)

func _add(e: HudElement) -> void:
	e.hud = self
	add_child(e)
	_elements.append(e)
	_by_key[e.key] = e

## The element with this UIConfig key (null if there is none).
func element(key: String) -> Node:
	return _by_key.get(key)

func elements() -> Array:
	return _elements

## The bars changed (an ability placed or moved, a keybind): every element looks again.
func _refresh_elements() -> void:
	for e in _elements:
		e.refresh()

# --- Per-frame -----------------------------------------------------------------

func _process(delta: float) -> void:
	if player == null:
		return
	for e in _elements:
		if e.visible or e.tick_hidden:
			e.update(delta)
	_slow_t -= delta
	if _slow_t <= 0.0:
		_slow_t = 0.1
		var combat: bool = player.has_method("is_in_combat") and player.is_in_combat()
		for e in _elements:
			e.slow_update()
			e.fade_tick(combat)

# --- Messages ----------------------------------------------------------------

# Red "can't do that" message, fades after ~1.5 s.
func _show_error(msg: String) -> void:
	_show_message(msg, Color(1, 0.3, 0.25))

func _show_message(msg: String, color: Color) -> void:
	if _error_label:
		_error_label.show_message(msg, color)

## For elements and trackers: a message in the Messages element.
func show_message(msg: String, color: Color) -> void:
	_show_message(msg, color)

# --- Death screen -------------------------------------------------------------

var _death_nodes: Array = []

func _clear_death_screen() -> void:
	for n in _death_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_death_nodes.clear()

func _on_player_died() -> void:
	_clear_death_screen()
	var shade := ColorRect.new()
	shade.color = Color(0.25, 0, 0, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_death_nodes.append(shade)
	var label := Label.new()
	_death_nodes.append(label)
	var key: String = get_node("/root/Settings").key_text("restart")
	label.text = "You died\nPress %s to restart" % key
	var net := get_node_or_null("/root/Net")
	if net and net.with_others():
		label.text = "You died\nYour party fights on - the floor restarts if everyone falls"
	if not Balance.ROGUELIKE_DEATH:
		# No drawbacks for now: get back up, or leave.
		label.text = "You died\nPress %s to revive" % key
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		row.anchor_left = 0.5
		row.anchor_right = 0.5
		row.anchor_top = 0.5
		row.anchor_bottom = 0.5
		row.offset_left = -220
		row.offset_right = 220
		row.offset_top = 20
		row.offset_bottom = 70
		var revive := UIWindow.button("Revive", Vector2(160, 34))
		revive.tooltip_text = "Get back up at the dungeon entrance (or the last boss room you cleared), with full health."
		revive.pressed.connect(func(): get_node("/root/GameManager").revive_local())
		row.add_child(revive)
		var menu := UIWindow.button("Main Menu", Vector2(160, 34))
		menu.pressed.connect(func(): get_node("/root/GameManager").go_to_menu())
		row.add_child(menu)
		add_child(row)
		_death_nodes.append(row)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_bottom = -120
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	add_child(label)
	# What the death cost (PlayerData.apply_death already ran).
	var pd := get_node_or_null("/root/PlayerData")
	var d: Dictionary = pd.last_death if pd else {}
	if d.is_empty():
		return
	var lines: Array[String] = []
	var lock := int(d["lock"])
	lines.append("Level %d  →  %d%s" % [int(d["old_level"]), int(d["new_level"]),
		"  (level lock)" if lock > 0 else ""])
	lines.append("Items lost (gear + bag): %s" % (", ".join(d["lost"]) if not d["lost"].is_empty() else "none"))
	if not d["kept"].is_empty():
		lines.append("Kept (wearable at level %d): %s" % [int(d["new_level"]), ", ".join(d["kept"])])
	if not d["runes_learned"].is_empty():
		lines.append("Runes recovered from lost gear: %s" % ", ".join(d["runes_learned"].map(func(r): return Runes.rune_name(str(r)))))
	if int(d["abilities_lost"]) > 0:
		lines.append("Abilities lost: %d — equip Skill Cards to get them back" % int(d["abilities_lost"]))
	lines.append("Your bank, runes and Skill Cards are safe.")
	var info := UI.label("\n".join(lines), 17, Color(1.0, 0.85, 0.8))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.anchor_left = 0.5
	info.anchor_right = 0.5
	info.anchor_top = 0.5
	info.anchor_bottom = 0.5
	info.offset_left = -380
	info.offset_right = 380
	info.offset_top = 10
	info.offset_bottom = 200
	info.add_theme_color_override("font_outline_color", Color.BLACK)
	info.add_theme_constant_override("outline_size", 5)
	add_child(info)
	_death_nodes.append(info)

