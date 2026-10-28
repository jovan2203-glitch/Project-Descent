extends HudElement

# One action bar (layout from PlayerData.action_bar). Bar 1 is the main bar
# (slots 1-8); bars 2-4 are switched on in UI Options > Action Bars (slots 9-16,
# 17-24, 25-32). A slot holds an ability or a macro; an on-use trinket shows as
# its "Use Trinket" button. Square buttons with a 1 px border, the keybind in
# the top corner, charges in the bottom one, a cooldown sweep with seconds left.
# Drag a button onto another slot (of any bar) to move it there: the two swap.

const SLOTS := 8

## 0 = the main bar, 1-3 the extra ones.
var bar := 0
var _buttons := {}          # slot (1..32) -> Button
var _cds := {}              # slot -> cooldown overlay Control
var _built_size := 0.0
var _styles := {}

static func make(b: int) -> HudElement:
	var e: HudElement = load("res://scripts/ui/hud/action_bar.gd").new()
	e.bar = b
	e.key = "action_bar_%d" % (b + 1)
	e.mover_key = "action_bar" if b == 0 else "extra_bar_%d" % b
	e.title = "Action Bar" if b == 0 else "Bar %d" % (b + 1)
	return e

static func bar_of(slot: int) -> int:
	return (slot - 1) / SLOTS

func build() -> void:
	add_backdrop()
	for state in ["normal", "hover", "active", "queued"]:
		_styles[state] = UISkin.button_box(state)

func layout() -> void:
	var sz := float(cfg("size"))
	if sz != _built_size:
		_build_slots(sz)
	var count := int(cfg("buttons"))
	var per_row := mini(int(cfg("per_row")), count)
	var gap := float(cfg("spacing"))
	var pad := 2.0
	var i := 0
	for slot in _slots():
		var b: Button = _buttons[slot]
		b.visible = i < count
		b.position = Vector2(pad + (i % per_row) * (sz + gap), pad + (i / per_row) * (sz + gap))
		(b.get_node("Key") as Label).visible = bool(cfg("show_keybind"))
		(b.get_node("Charges") as Label).visible = bool(cfg("show_charges"))
		_cds[slot].set_meta("text", bool(cfg("cooldown_text")))
		i += 1
	var rows := ceili(float(count) / per_row)
	set_box(Vector2(pad * 2 + per_row * sz + (per_row - 1) * gap, pad * 2 + rows * sz + (rows - 1) * gap))
	($Backdrop as Control).visible = bool(cfg("backdrop"))
	for state in _styles:
		_styles[state] = UISkin.button_box(state)

func _slots() -> Array:
	return range(bar * SLOTS + 1, bar * SLOTS + SLOTS + 1)

func _build_slots(sz: float) -> void:
	for b in _buttons.values():
		b.queue_free()
	_buttons.clear()
	_cds.clear()
	_built_size = sz
	for slot in _slots():
		add_child(_make_slot(slot, sz))
	refresh()

func _make_slot(i: int, sz: float) -> Button:
	var b := Abilities.make_slot(sz)
	b.size = Vector2(sz, sz)
	b.add_theme_stylebox_override("normal", _styles["normal"])
	b.add_theme_stylebox_override("hover", _styles["hover"])
	b.add_theme_stylebox_override("pressed", _styles["active"])
	b.pressed.connect(func(): if player: player.activate_ability(i))
	_buttons[i] = b
	# Cooldown overlay: dark fill that shrinks as the cooldown runs + seconds left.
	var cd := Control.new()
	cd.set_anchors_preset(Control.PRESET_FULL_RECT)
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := UISkin.font(15 if sz >= 44.0 else 13)
	cd.draw.connect(func():
		var frac: float = cd.get_meta("frac", 0.0)
		if frac <= 0.0:
			return
		var h := cd.size.y * frac
		cd.draw_rect(Rect2(Vector2(1, cd.size.y - h), Vector2(cd.size.x - 2, h - 1)), Color(0, 0, 0, 0.65), true)
		if not bool(cd.get_meta("text", true)):
			return
		var f := ThemeDB.fallback_font
		var txt := UISkin.time_text(float(cd.get_meta("left", 0.0)))
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font).x
		var p := Vector2((cd.size.x - tw) / 2.0, cd.size.y / 2.0 + font * 0.36)
		cd.draw_string_outline(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font, 4, Color.BLACK)
		cd.draw_string(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font, Color(1, 0.95, 0.6)))
	b.add_child(cd)
	_cds[i] = cd
	b.set_drag_forwarding(
		func(_pos): return _bar_drag(b, i),
		func(_pos, data): return _can_drop_on_slot(data),
		func(_pos, data): _drop_on_slot(i, data))
	var key_l := UISkin.label("", 11 if sz >= 36.0 else 9, Color(0.85, 0.85, 0.85))
	key_l.name = "Key"
	key_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	key_l.position = Vector2(0, 0)
	key_l.size = Vector2(sz - 3, 14)
	b.add_child(key_l)
	# Charge count (Ice Shards) in the bottom-right corner.
	var charges := UISkin.label("", 13 if sz >= 36.0 else 11, Color(0.75, 0.95, 1.0))
	charges.name = "Charges"
	charges.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	charges.position = Vector2(0, sz - 18)
	charges.size = Vector2(sz - 3, 16)
	b.add_child(charges)
	# The move a Brawler strike would finish its Chain with (Martial tank).
	var finish := UISkin.label("", 9, Color(1.0, 0.83, 0.3))
	finish.name = "Finish"
	finish.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	finish.position = Vector2(0, sz * 0.5 - 8)
	finish.size = Vector2(sz, 16)
	b.add_child(finish)
	return b

func _slot_id(i: int) -> String:
	var pd := get_node_or_null("/root/PlayerData")
	return pd.action_bar[i - 1] if pd and i >= 1 and i <= pd.action_bar.size() else ""

## Icons, tooltips and keybind texts (on every bar or keybind change).
func refresh() -> void:
	var settings := get_node_or_null("/root/Settings")
	for i in _buttons:
		var id := _slot_id(i)
		Abilities.set_slot_ability(_buttons[i], id)
		var key_l: Label = _buttons[i].get_node("Key")
		if settings:
			var text: String = settings.key_text(settings.slot_action(i))
			key_l.text = "" if text == "—" else short_key(text)   # extra-bar slots have no key until you bind one
		key_l.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85) if id != "" else UISkin.DIM)

## "Shift+1" -> "S1", "Mouse 4" -> "M4": keybinds as short as ElvUI-style buttons need.
static func short_key(text: String) -> String:
	return text.replace("Shift+", "S").replace("Ctrl+", "C").replace("Alt+", "A") \
		.replace("Mouse ", "M").replace("Middle Mouse", "MM").replace("Wheel Up", "WU").replace("Wheel Down", "WD")

func update(_delta: float) -> void:
	if player == null:
		return
	for i in _buttons:
		var b: Button = _buttons[i]
		if not b.visible:
			continue
		var slot_id := _slot_id(i)
		# A macro's button behaves like the ability it is linked to (none: always lit).
		var id := Macros.link_of(slot_id) if Macros.is_macro(slot_id) else slot_id
		if Abilities.WHEEL_SLOTS.has(id):
			id = player.wheel.form_of(id)   # Martial warrior: the held weapon's move
			if slot_id != id and Abilities.WHEEL_SLOTS.has(slot_id) \
					and str(b.get_node("AbilityIcon").get_meta("ability_id", "")) != id:
				Abilities.set_slot_ability(b, id)   # its icon and tooltip change with the weapon
		elif Abilities.ROGUE_KILL_FORMS.has(id):
			id = player.rogue.form_of(id)   # Martial DPS: a builder is its Kill form in a Kill window
			if Abilities.ROGUE_KILL_FORMS.has(slot_id) \
					and str(b.get_node("AbilityIcon").get_meta("ability_id", "")) != id:
				Abilities.set_slot_ability(b, id)   # its icon and tooltip change with the window
		var active := false
		var left := 0.0
		var total := 1.0
		if id != "":
			active = (player.casting and player.current_spell == id) \
				or (player.placing and id == player.placing_id)
			var usable := true
			if Abilities.info(id).get("needs_target", false):
				usable = player.has_valid_target()
			usable = usable and player.can_afford(id) and player.target_in_range(id)
			if Abilities.is_trinket_slot(id):
				usable = player.trinket_usable(id)   # an item with a Use: effect is equipped there
			b.get_node("AbilityIcon").modulate.a = 1.0 if usable else 0.4
			left = player.cooldown_left(id)
			total = max(player.cooldown_total(id), 0.01)
			if id == "iceshards" and player.has_method("shard_recharge_left"):
				# No charges: the overlay counts down to the next one.
				if int(player.ice_shard_charges) <= 0 and not player.shards_firing():
					left = player.shard_recharge_left()
					total = Balance.ICE_SHARDS_RECHARGE
		elif slot_id != "":
			b.get_node("AbilityIcon").modulate.a = 1.0   # a macro that isn't linked
		var ch: Label = b.get_node("Charges")
		var ch_text: String = player.charges_text(id) if id != "" and player.has_method("charges_text") else ""
		if ch.text != ch_text:
			ch.text = ch_text
		var fin: Label = b.get_node("Finish")
		var fin_text: String = player.brawler.finish_label(id) if Abilities.BRAWLER_STRIKES.has(id) else ""
		if fin.text != fin_text:
			fin.text = fin_text
		var cd: Control = _cds[i]
		var frac := clampf(left / total, 0.0, 1.0)
		if frac != float(cd.get_meta("frac", 0.0)) or left != float(cd.get_meta("left", 0.0)):
			cd.set_meta("frac", frac)
			cd.set_meta("left", left)
			cd.queue_redraw()
		var style: StyleBoxFlat = _styles["active"] if active else _styles["normal"]
		if id != "" and player.has_method("queued_ability") and player.queued_ability() == id:
			style = _styles["queued"]   # waiting in the spell queue: fires the moment it can
		if b.get_theme_stylebox("normal") != style:
			b.add_theme_stylebox_override("normal", style)

# --- Drag and drop ----------------------------------------------------------------------

func _player_in_combat() -> bool:
	return player != null and player.has_method("is_in_combat") and player.is_in_combat()

## The trinket button ("trinket_1" / "trinket_2") for the on-use trinket being
## dragged from the bag ("inv" drag), or "" if it isn't one.
func _dragged_trinket_item(data: Dictionary) -> String:
	var pd := get_node_or_null("/root/PlayerData")
	if pd == null or data.get("type") != "inv":
		return ""
	var item := str(pd.inventory[int(data["index"])])
	if item == "" or Items.use_effect_of(item) == null or not str(Items.get_item(item).get("slot", "")).begins_with("Trinket"):
		return ""
	return item

func _can_drop_on_slot(data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	match str(data.get("type", "")):
		"hud_bar":
			return true
		"ability":
			return not _player_in_combat()
		"inv":
			return _dragged_trinket_item(data) != "" and not _player_in_combat()
	return false

func _drop_on_slot(slot: int, data: Dictionary) -> void:
	var pd := get_node_or_null("/root/PlayerData")
	if pd == null:
		return
	match str(data.get("type", "")):
		"ability":   # from the spellbook (P), the macro window, or an equipped trinket
			pd.set_action_slot(slot - 1, str(data["id"]), -1)
		"inv":
			# An on-use trinket from the bag: put it on, then its button on the bar.
			var item := _dragged_trinket_item(data)
			var err: String = pd.equip_from_inventory(int(data["index"]))
			if err != "":
				hud.show_message(err, Color(1, 0.3, 0.25))
				return
			for button_id in Abilities.TRINKET_SLOTS:
				if str(pd.equipment.get(Abilities.TRINKET_SLOTS[button_id], "")) == item:
					pd.set_action_slot(slot - 1, str(button_id), -1)
		"hud_bar":
			var from := int(data["slot"])
			pd.set_action_slot(slot - 1, str(pd.action_bar[from - 1]), from - 1)

## Start dragging the button in bar slot `i`. Dropping it anywhere that isn't a
## slot leaves the bar as it was.
func _bar_drag(b: Button, i: int) -> Variant:
	var id := _slot_id(i)
	if id == "":
		return null
	var preview := Control.new()
	var icon := Control.new()
	icon.size = b.size
	icon.position = -icon.size / 2.0
	icon.modulate.a = 0.85
	icon.draw.connect(func(): Abilities.draw_icon(icon, id))
	preview.add_child(icon)
	b.set_drag_preview(preview)
	return {"type": "hud_bar", "slot": i}
