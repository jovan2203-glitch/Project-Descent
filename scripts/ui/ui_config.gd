class_name UIConfig

# Every option of the in-game UI, the four role layouts, and the player's own
# changes (Settings.ui_profile). An option's value is the player's own, else the
# role preset's, else the schema default:
#   UIConfig.value("player_frame", "width")
#   UIConfig.set_value("player_frame", "width", 260)   # saves, Settings.ui_config_changed("player_frame")
# The options window (ui_options.gd) builds its pages from schema(); the
# installer (ui_installer.gd) picks a role; Move UI asks preset_spot() for the
# place of an element the player never moved.

const ROLES := ["tank", "healer", "physical", "caster"]
const ROLE_NAMES := {"tank": "Tank", "healer": "Healer", "physical": "Physical DPS", "caster": "Caster DPS"}
const DEFAULT_ROLE := "physical"
const FADES := ["always", "combat", "no_combat", "mouseover"]
const FADE_NAMES := ["Always shown", "Only in combat", "Only out of combat", "Only on mouseover"]
const TEXT_FORMATS := ["value", "percent", "both", "deficit", "none"]
const TEXT_NAMES := ["1200 / 2000", "60%", "1200 - 60%", "-800", "None"]
const INFO_TEXTS := ["none", "fps", "ping", "time", "xp", "bags", "combat", "dps", "hps"]
const INFO_NAMES := ["None", "FPS", "Ping", "Time", "Level / XP", "Bag space", "Combat time", "DPS", "HPS"]
const EXPORT_PREFIX := "UI1:"

## Shared by every element (not General): shown or not, size, opacity and when it shows.
static func _shared() -> Array:
	return [
		_bool("enabled", true, "Enabled"),
		_float("scale", 1.0, 0.5, 2.0, 0.05, "Scale"),
		_float("alpha", 1.0, 0.1, 1.0, 0.05, "Opacity"),
		_enum("fade", "always", FADES, FADE_NAMES, "Show"),
	]

static var _schema: Dictionary = {}

## Element key -> {"label", "group", "shared" (bool), "options": [option dict...]}.
## An option: {id, type ("bool" / "int" / "float" / "enum" / "color"), default,
## min, max, step, values, names, label, tip}.
static func schema() -> Dictionary:
	if not _schema.is_empty():
		return _schema
	var s := {}
	s["general"] = _elem("General", "", false, [
		_int("font_size", 12, 9, 18, "Base font size"),
		_float("backdrop_alpha", 0.8, 0.0, 1.0, 0.05, "Backdrop opacity"),
		_enum("health_color", "class", ["class", "gradient", "flat", "custom"],
			["Spec colour", "Green to red", "Green", "Custom"], "Health colour"),
		_color("health_custom", Color(0.2, 0.72, 0.3), "Custom health colour"),
		_color("accent", Color(0.3, 0.75, 1.0), "Accent colour"),
		_bool("show_ids", true, "Show IDs in tooltips", "Ability, item and effect IDs at the bottom of tooltips (for Trackers)."),
	])
	s["player_frame"] = _elem("Player", "Unit Frames", true, [
		_int("width", 220, 120, 420, "Width"),
		_int("health_height", 26, 12, 60, "Health height"),
		_int("power_height", 6, 0, 24, "Power height"),
		_enum("text", "both", TEXT_FORMATS, TEXT_NAMES, "Health text"),
		_bool("show_name", true, "Show name"),
		_bool("combat_glow", true, "Combat glow", "A red edge while you are in combat."),
	])
	s["target_frame"] = _elem("Target", "Unit Frames", true, [
		_int("width", 220, 120, 420, "Width"),
		_int("health_height", 26, 12, 60, "Health height"),
		_int("power_height", 5, 0, 24, "Power height"),
		_enum("text", "both", TEXT_FORMATS, TEXT_NAMES, "Health text"),
		_enum("auras", "all", ["all", "debuffs", "buffs", "none"], ["Buffs and debuffs", "Debuffs", "Buffs", "None"], "Auras"),
		_int("aura_size", 20, 12, 40, "Aura size"),
		_bool("cast_detached", false, "Detach cast bar", "Its cast bar becomes an element of its own (Move UI: Target Cast Bar)."),
		_int("cast_height", 14, 8, 32, "Cast bar height"),
	])
	s["target_cast"] = _elem("Target Cast Bar", "Cast Bars", true, [
		_int("width", 220, 80, 500, "Width"),
		_int("height", 16, 8, 40, "Height"),
	])
	s["party_frames"] = _elem("Party", "Unit Frames", true, [
		_int("width", 160, 60, 320, "Width"),
		_int("height", 36, 20, 80, "Height"),
		_int("spacing", 4, 0, 20, "Spacing"),
		_enum("grow", "down", ["down", "up", "right"], ["Down", "Up", "Right"], "Grow"),
		_enum("sort", "party", ["party", "role"], ["Party order", "Tank, healer, damage"], "Sort"),
		_bool("show_self", true, "Show yourself"),
		_bool("show_solo", false, "Show when solo"),
		_float("range_alpha", 0.45, 0.1, 1.0, 0.05, "Out of range opacity"),
	])
	s["cast_bar"] = _elem("Player Cast Bar", "Cast Bars", true, [
		_int("width", 220, 80, 500, "Width"),
		_int("height", 18, 8, 40, "Height"),
		_bool("icon", true, "Icon"),
		_bool("show_time", true, "Time left"),
		_bool("spark", true, "Spark"),
	])
	for b in range(1, 5):
		s["action_bar_%d" % b] = _elem("Bar %d" % b, "Action Bars", true, [
			_bool("enabled", b == 1, "Enabled"),
			_int("buttons", 8, 1, 8, "Buttons"),
			_int("per_row", 1 if b == 4 else 8, 1, 8, "Buttons per row"),
			_int("size", 32, 20, 64, "Button size"),
			_int("spacing", 2, 0, 12, "Spacing"),
			_bool("backdrop", true, "Backdrop"),
			_bool("show_keybind", true, "Keybind text"),
			_bool("show_charges", true, "Charges text"),
			_bool("cooldown_text", true, "Cooldown text"),
		])
	s["buffs"] = _elem("Buffs", "Auras", true, _aura_opts("left"))
	s["debuffs"] = _elem("Debuffs", "Auras", true, _aura_opts("left"))
	s["xp_bar"] = _elem("XP Bar", "Bars", true, [
		_int("width", 274, 60, 900, "Width"),
		_int("height", 6, 3, 24, "Height"),
		_bool("show_text", true, "Text"),
	])
	s["messages"] = _elem("Messages", "Bars", true, [
		_int("font_size", 18, 10, 32, "Font size"),
	])
	s["chat_panel"] = _elem("Chat Panel", "Panels", true, _panel_opts(270, 150, ["time", "bags", "fps"]))
	s["meter_panel"] = _elem("Meter Panel", "Panels", true, _panel_opts(250, 150, ["dps", "combat", "ping"]) + [
		_bool("docked", true, "Dock the damage meter", "The damage meter sits in this panel. Off: it floats where you drag it."),
	])
	s["minimap"] = _elem("Minimap", "Panels", true, [
		_int("size", 150, 80, 320, "Size"),
		_bool("show_name", true, "Dungeon name"),
		_bool("show_clock", true, "Clock"),
	])
	for k in [["venom", "Venom"], ["wheel", "Wheel"], ["chain", "Chain"], ["sharpshooter", "Sharpshooter"]]:
		s[k[0]] = _elem(k[1], "Spec Bars", true, [])
	_schema = s
	return s

static func _aura_opts(grow: String) -> Array:
	return [
		_int("size", 26, 14, 48, "Icon size"),
		_int("per_row", 8, 1, 20, "Icons per row"),
		_enum("grow", grow, ["left", "right"], ["Left", "Right"], "Grow"),
		_enum("sort", "time", ["time", "name"], ["Time left", "Name"], "Sort"),
		_bool("show_time", true, "Time left"),
	]

static func _panel_opts(w: int, h: int, infos: Array) -> Array:
	var out := [
		_int("width", w, 150, 800, "Width"),
		_int("height", h, 60, 600, "Height"),
		_bool("info_strip", true, "Info strip"),
	]
	for i in 3:
		out.append(_enum("info_%d" % (i + 1), infos[i], INFO_TEXTS, INFO_NAMES, "Info text %d" % (i + 1)))
	return out

static func _elem(label: String, group: String, shared: bool, options: Array) -> Dictionary:
	var opts: Array = []
	if shared:
		for o in _shared():
			var has := false
			for mine in options:
				has = has or mine["id"] == o["id"]
			if not has:
				opts.append(o)
	opts.append_array(options)
	return {"label": label, "group": group, "shared": shared, "options": opts}

static func _bool(id: String, d: bool, label: String, tip := "") -> Dictionary:
	return {"id": id, "type": "bool", "default": d, "label": label, "tip": tip}

static func _int(id: String, d: int, mn: int, mx: int, label: String, tip := "") -> Dictionary:
	return {"id": id, "type": "int", "default": d, "min": mn, "max": mx, "step": 1, "label": label, "tip": tip}

static func _float(id: String, d: float, mn: float, mx: float, step: float, label: String, tip := "") -> Dictionary:
	return {"id": id, "type": "float", "default": d, "min": mn, "max": mx, "step": step, "label": label, "tip": tip}

static func _enum(id: String, d: String, values: Array, names: Array, label: String, tip := "") -> Dictionary:
	return {"id": id, "type": "enum", "default": d, "values": values, "names": names, "label": label, "tip": tip}

static func _color(id: String, d: Color, label: String, tip := "") -> Dictionary:
	return {"id": id, "type": "color", "default": d, "label": label, "tip": tip}

static func option(elem: String, opt: String) -> Dictionary:
	var e: Dictionary = schema().get(elem, {})
	for o in e.get("options", []):
		if o["id"] == opt:
			return o
	return {}

# --- Role layouts --------------------------------------------------------------------
# A spot is Move UI's anchor + offset ({ax, ay, x, y}, scripts/ui/ui_layout.gd):
# (0.5, 1) is the bottom centre, x the element centre's offset from the screen
# centre and y its bottom edge's offset from the screen bottom.

static func _at(ax: float, ay: float, x: float, y: float) -> Dictionary:
	return {"ax": ax, "ay": ay, "x": x, "y": y}

## Every role, on the 1152 x 648 UI space (wider screens get more room at the
## sides): bars stacked at the bottom centre with the XP bar under them, player
## and target frames above them on either side with their cast bars under them,
## auras left of the minimap, chat bottom-left, meter bottom-right.
static func _base_layout() -> Dictionary:
	return {
		"action_bar": _at(0.5, 1, 0, -12),
		"extra_bar_1": _at(0.5, 1, 0, -50),
		"extra_bar_2": _at(0.5, 1, 0, -88),
		"extra_bar_3": _at(1, 0.5, -4, -40),
		"xp_bar": _at(0.5, 1, 0, -3),
		"player_frame": _at(0.5, 1, -190, -182),
		"target_frame": _at(0.5, 1, 190, -182),
		"cast_bar": _at(0.5, 1, -190, -158),
		"target_cast": _at(0.5, 1, 190, -158),
		"buffs": _at(1, 0, -164, 4),
		"debuffs": _at(1, 0, -164, 86),
		"party_frames": _at(0, 0.5, 6, -70),
		"messages": _at(0.5, 0.5, 0, -110),
		"venom": _at(0.5, 1, 0, -236),
		"wheel": _at(0.5, 1, 0, -236),
		"chain": _at(0.5, 1, 0, -236),
		"sharpshooter": _at(0.5, 1, 0, -236),
		"minimap": _at(1, 0, -6, 20),
		"chat": _at(0, 1, 6, -6),
		"meter": _at(1, 1, -6, -6),
		"tracker:aura_bars": _at(0.5, 1, -190, -230),
		"tracker:cooldowns": _at(0.5, 1, 0, -132),
	}

const PRESETS := {
	"tank": {
		"layout": {},
		"overrides": {"player_frame": {"health_height": 30}, "debuffs": {"size": 30}},
	},
	"healer": {
		"layout": {
			"party_frames": {"ax": 0.5, "ay": 1, "x": 0, "y": -232},
			"tracker:aura_bars": {"ax": 0.5, "ay": 1, "x": -400, "y": -182},
			"tracker:cooldowns": {"ax": 0.5, "ay": 1, "x": 0, "y": -132},
		},
		"overrides": {"party_frames": {"width": 100, "height": 40, "grow": "right", "show_solo": true}},
	},
	"physical": {
		"layout": {},
		"overrides": {},
	},
	"caster": {
		"layout": {
			"cast_bar": {"ax": 0.5, "ay": 1, "x": 0, "y": -130},
			"tracker:cooldowns": {"ax": 0.5, "ay": 1, "x": 0, "y": -262},
		},
		"overrides": {"cast_bar": {"width": 274, "height": 20}},
	},
}

## Where `key` goes when the player never moved it ({} = the code's own spot).
static func preset_spot(key: String, role_id := "") -> Dictionary:
	var r := role_id if role_id != "" else role()
	var layout: Dictionary = PRESETS.get(r, {}).get("layout", {})
	if layout.has(key):
		return layout[key]
	return _base_layout().get(key, {})

## Every element key a preset places.
static func placed_keys(role_id := "") -> Array:
	var keys := _base_layout().keys()
	for k in PRESETS.get(role_id if role_id != "" else role(), {}).get("layout", {}):
		if not keys.has(k):
			keys.append(k)
	return keys

# --- Values ---------------------------------------------------------------------------

static func settings() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Settings") if tree != null else null

static func role() -> String:
	var s := settings()
	var r := str(s.get("ui_role")) if s != null and s.get("ui_role") != null else ""
	return r if ROLES.has(r) else DEFAULT_ROLE

static func profile() -> Dictionary:
	var s := settings()
	return s.ui_profile if s != null and s.get("ui_profile") is Dictionary else {}

## The value in effect: the player's, else the role preset's, else the default.
static func value(elem: String, opt: String) -> Variant:
	var p: Dictionary = profile().get(elem, {})
	if p.has(opt):
		return p[opt]
	return default_of(elem, opt, role())

static func default_of(elem: String, opt: String, role_id: String) -> Variant:
	var ov: Dictionary = PRESETS.get(role_id, {}).get("overrides", {}).get(elem, {})
	if ov.has(opt):
		return ov[opt]
	return option(elem, opt).get("default")

## `save` false: apply now, write the file later (a slider being dragged).
static func set_value(elem: String, opt: String, v: Variant, save := true) -> void:
	var s := settings()
	var o := option(elem, opt)
	if s == null or o.is_empty():
		return
	v = coerce(o, v)
	var p: Dictionary = s.ui_profile.get(elem, {})
	if v == default_of(elem, opt, role()):
		p.erase(opt)
	else:
		p[opt] = v
	if p.is_empty():
		s.ui_profile.erase(elem)
	else:
		s.ui_profile[elem] = p
	if save:
		s.save()
	s.ui_config_changed.emit(elem)

## Back to the role preset's values for one element.
static func reset(elem: String) -> void:
	var s := settings()
	if s == null:
		return
	s.ui_profile.erase(elem)
	s.save()
	s.ui_config_changed.emit(elem)

## Switch to a role's layout: its positions and values, nothing of the player's kept.
static func apply_role(role_id: String) -> void:
	var s := settings()
	if s == null or not ROLES.has(role_id):
		return
	s.ui_role = role_id
	s.ui_profile = {}
	s.ui_layout = {}
	s.save()
	for elem in schema():
		s.ui_config_changed.emit(elem)
	s.ui_config_changed.emit("")

## A value in range and of the option's type (imports and saves can hold anything).
static func coerce(o: Dictionary, v: Variant) -> Variant:
	match str(o.get("type")):
		"bool":
			return bool(v) if (v is bool or v is int or v is float) else o["default"]
		"int":
			return clampi(int(v), int(o["min"]), int(o["max"])) if (v is int or v is float) else o["default"]
		"float":
			return clampf(float(v), float(o["min"]), float(o["max"])) if (v is int or v is float) else o["default"]
		"enum":
			return str(v) if (o["values"] as Array).has(str(v)) else o["default"]
		"color":
			return v if v is Color else o["default"]
	return v

## Only known elements and options, each coerced (for loads and imports).
static func clean_profile(p: Variant) -> Dictionary:
	var out := {}
	if not (p is Dictionary):
		return out
	for elem in p:
		if not schema().has(str(elem)) or not (p[elem] is Dictionary):
			continue
		var d := {}
		for opt in p[elem]:
			var o := option(str(elem), str(opt))
			if not o.is_empty():
				d[str(opt)] = coerce(o, p[elem][opt])
		if not d.is_empty():
			out[str(elem)] = d
	return out

# --- Export / import (share a whole UI as one line of text) ----------------------------

static func export_profile() -> String:
	var s := settings()
	var data := {"role": role(), "profile": profile(), "layout": s.ui_layout if s != null else {}}
	return EXPORT_PREFIX + Marshalls.utf8_to_base64(var_to_str(data))

## Read an exported line ({} when it isn't one): {"role", "profile", "layout"}.
static func parse_export(text: String) -> Dictionary:
	text = text.strip_edges()
	if not text.begins_with(EXPORT_PREFIX):
		return {}
	var raw := Marshalls.base64_to_utf8(text.trim_prefix(EXPORT_PREFIX))
	var data: Variant = str_to_var(raw) if raw != "" else null
	if not (data is Dictionary):
		return {}
	var layout := {}
	if data.get("layout") is Dictionary:
		for k in data["layout"]:
			var d: Variant = data["layout"][k]
			if d is Dictionary and d.has("ax") and d.has("ay"):
				layout[str(k)] = {"ax": clampf(float(d["ax"]), 0, 1), "ay": clampf(float(d["ay"]), 0, 1),
					"x": float(d.get("x", 0.0)), "y": float(d.get("y", 0.0))}
	var r := str(data.get("role", DEFAULT_ROLE))
	return {"role": r if ROLES.has(r) else DEFAULT_ROLE, "profile": clean_profile(data.get("profile")), "layout": layout}

## Apply an exported line; false when it isn't one.
static func import_profile(text: String) -> bool:
	var d := parse_export(text)
	var s := settings()
	if d.is_empty() or s == null:
		return false
	s.ui_role = d["role"]
	s.ui_profile = d["profile"]
	s.ui_layout = d["layout"]
	s.save()
	for elem in schema():
		s.ui_config_changed.emit(elem)
	s.ui_config_changed.emit("")
	return true
