class_name Trackers

# Trackers: UI elements you build yourself (aura bars, cooldown icons, proc
# alerts, resource bars), like WeakAuras. This file is the data side: what a
# tracker and a group hold, the templates, the default groups per role,
# checking saved / imported data, and evaluating triggers. The engine
# (tracker_engine.gd) runs them, tracker_display.gd draws one, the editor
# (tracker_editor.gd, /trackers) builds them. Saved in Settings.trackers.
#
# A tracker: {id, name, kind "tracker", group (a group's id or ""), enabled,
#   display {type icon / bar / text / ring / pips, width, height, color, text, text2,
#            text_color, text2_color, icon, glow, sound, show_missing, time_text, click},
#   triggers [trigger...], combine "any" / "all",
#   conditions [{trigger (0 = the shown one, 1-5), check stacks / time / value / percent / active,
#                op, value, set color / glow / alpha / text / text2 / text_color / text2_color, to}],
#   load {spec, role, combat any / in / out, party any / yes / no, dungeon any / yes,
#         bars (ability ids, comma-separated), bars_mode all / any}}
# A group: {id, name, kind "group", enabled, grow down / up / left / right, align start / center / end,
#   spacing, sort none / time / name}
#
# The spec displays (Venom, the Wheel, the Chain, the Sharpshooter's shots, Verses,
# Ice Shards, Bruise, Heat, Flow...) are ordinary trackers too (spec_sets()): given once, then the player's to change
# or delete. They read spec values (Player.tracker_values()) and may click a spec
# action (Player.tracker_actions()); no spec code lives here.
#
# Triggers read only what this client knows (your own state, your target's
# effects, the party frames), so a tracker works the same for host and guests.
# IDs: abilities (Abilities), items (Items), effects (Effects.all_ids() plus
# runtime ids such as rune procs): tooltips show them with "Show IDs in tooltips".

const DISPLAY_TYPES := ["icon", "bar", "text", "ring", "pips"]
const TRIGGER_TYPES := ["effect", "cooldown", "resource", "event", "item", "state"]
const TRIGGER_NAMES := ["Effect (buff / debuff)", "Cooldown", "Resource / value", "Event", "Item equipped", "State"]
const UNITS := ["player", "target", "party"]
const OPS := [">=", "<=", ">", "<", "="]
const EVENTS := ["ability_used", "cast_started", "cast_finished", "cast_interrupted", "crit", "kill",
	"damaged", "dodge", "parry", "block", "rune", "looted", "status_applied", "status_consumed", "level_up"]
const EVENT_NAMES := ["Ability used", "Cast started", "Cast finished", "Cast interrupted", "You crit",
	"You killed something", "You took damage", "You dodged", "You parried", "You blocked",
	"Rune / item effect went off", "Item looted", "Effect applied", "Effect consumed", "Level up"]
const STATES := ["in_combat", "no_combat", "has_target", "target_hostile", "target_casting", "party_dead",
	"in_dungeon", "boss_engaged"]
const STATE_NAMES := ["In combat", "Out of combat", "Have a target", "Target is hostile", "Target is casting",
	"A party member is dead", "In a dungeon", "Fighting a boss"]
const RESOURCES := ["health", "mana", "energy", "fury"]
const CHECKS := ["stacks", "time", "value", "percent", "active"]
const SETS := ["color", "glow", "alpha", "text", "text2", "text_color", "text2_color"]
const FIELDS := ["name", "stacks", "time", "value", "max", "percent"]
const MAX_TRACKERS := 200
const AbilitiesScript = preload("res://scripts/abilities.gd")
const ItemsScript = preload("res://scripts/items.gd")
const EffectsScript = preload("res://scripts/core/effects.gd")
const BalanceScript = preload("res://scripts/balance.gd")
const EXPORT_PREFIX := "TRK1:"

# --- Making ---------------------------------------------------------------------------

static func new_id(prefix := "t") -> String:
	return "%s_%d_%d" % [prefix, Time.get_unix_time_from_system(), randi() % 100000]

static func default_display(type := "icon") -> Dictionary:
	var wide := type == "bar" or type == "pips"
	return {"type": type, "width": 160 if wide else 40, "height": (18 if type == "bar" else 10) if wide else 40,
		"color": Color(0.3, 0.75, 1.0), "text": "%name" if type == "bar" else ("" if type == "pips" else "%stacks"),
		"text2": "", "text_color": Color.WHITE, "text2_color": Color.WHITE, "icon": "auto",
		"glow": false, "sound": false, "show_missing": false, "time_text": type != "pips", "click": ""}

static func default_load() -> Dictionary:
	return {"spec": "", "role": "", "combat": "any", "party": "any", "dungeon": "any", "bars": "", "bars_mode": "all"}

static func default_trigger(type: String) -> Dictionary:
	match type:
		"effect":
			return {"type": "effect", "unit": "player", "id": "", "own": true, "missing": false, "op": ">=", "stacks": 1}
		"cooldown":
			return {"type": "cooldown", "id": "", "show": "ready"}
		"resource":
			return {"type": "resource", "res": "health", "op": "<=", "value": 35.0, "percent": true}
		"event":
			return {"type": "event", "event": "ability_used", "id": "", "duration": 3.0}
		"item":
			return {"type": "item", "id": ""}
		"state":
			return {"type": "state", "state": "in_combat"}
	return {}

static func make_tracker(name: String, display_type: String, triggers: Array, group := "") -> Dictionary:
	return {"id": new_id(), "name": name, "kind": "tracker", "group": group, "enabled": true,
		"display": default_display(display_type), "triggers": triggers, "combine": "any",
		"conditions": [], "load": default_load()}

static func make_group(name: String, grow := "up") -> Dictionary:
	return {"id": new_id("g"), "name": name, "kind": "group", "enabled": true, "grow": grow, "align": "start",
		"spacing": 2, "sort": "time"}

## New-tracker templates: [name, description, maker].
static func templates() -> Array:
	return [
		["Proc bar", "A bar that fills with a buff's time left while you have it.", func():
			var t := make_tracker("Proc bar", "bar", [default_trigger("effect")])
			t["display"]["text"] = "%name  %stacks"
			return t],
		["Cooldown icon", "An ability's icon with its cooldown sweep; bright when ready.", func():
			var tr := default_trigger("cooldown")
			tr["show"] = "always"
			return make_tracker("Cooldown icon", "icon", [tr])],
		["Missing buff", "Shows while a buff of yours is NOT up (keep it running).", func():
			var tr := default_trigger("effect")
			tr["missing"] = true
			var t := make_tracker("Missing buff", "icon", [tr])
			t["display"]["glow"] = true
			return t],
		["Resource bar", "A bar for health, mana, energy, fury or a spec value (Venom, Verses...).", func():
			var tr := default_trigger("resource")
			tr["op"] = ">="
			tr["value"] = 0.0
			var t := make_tracker("Resource bar", "bar", [tr])
			t["display"]["text"] = "%value / %max"
			return t],
		["Debuff on target", "Your debuff on your target, with its time left.", func():
			var tr := default_trigger("effect")
			tr["unit"] = "target"
			var t := make_tracker("Debuff on target", "icon", [tr])
			t["display"]["text"] = "%stacks"
			return t],
		["Alert", "A text that flashes up for a few seconds when something happens.", func():
			var t := make_tracker("Alert", "text", [default_trigger("event")])
			t["display"]["text"] = "%name!"
			t["display"]["height"] = 28
			return t],
	]

## The "Aura Bars" and "Cooldowns" groups a role starts with (empty groups the
## player fills; a few examples from the abilities on the bars).
static func default_groups(role: String) -> Array:
	var aura := make_group("Aura Bars", "up")
	aura["id"] = "aura_bars"
	var cds := make_group("Cooldowns", "right")
	cds["id"] = "cooldowns"
	cds["sort"] = "none"
	var out := [aura, cds]
	# Healers and tanks keep low health in sight.
	if role == "healer" or role == "tank":
		var tr := default_trigger("resource")
		var low := make_tracker("Low health", "text", [tr])
		low["display"]["text"] = "Low health  %percent%"
		low["display"]["color"] = Color(1.0, 0.3, 0.25)
		low["display"]["height"] = 24
		low["display"]["width"] = 220
		low["load"]["combat"] = "in"
		out.append(low)
	return out

## The spec displays, as trackers anyone could have built: [set id, name, description,
## its items (a group first, then its trackers)]. Fixed ids, so each has a spot in
## UIConfig's layouts ("tracker:<id>") and is given once (Settings.tracker_builtins).
static func spec_sets() -> Array:
	return [
		["spec_venom", "Venom", "Venomstring: your Venom as a bar, brighter while Venom Flows.", _venom_set()],
		["spec_wheel", "Wheel", "The Wheel: the held weapon, the ones coming next, uses left and Cracks. Click it out of combat to turn it.", _wheel_set()],
		["spec_chain", "Chain", "The Brawler: the Chain's strikes so far, empty cells for the ones to come.", _chain_set()],
		["spec_sharp", "Sharpshooter", "The Sharpshooter's shots: cooldowns, Overcut (gold) and what your ready shots would take off each (blue; gold: it would become Overcut).", _sharp_set()],
		["spec_verses", "Verses", "Hymns: your Verses in their Hymn's colour and the Hymn you sing.", _verses_set()],
		["spec_ice_shards", "Ice Shards", "Hard Winter: your Ice Shards charges and the time to the next one.", _ice_shards_set()],
		["spec_bruise", "Bruise", "The Brawler: the Bruise still to be dealt to you, as a bar of your health.", _bruise_set()],
		["spec_glaze", "Glaze", "Frostbitten Steel: your Glaze.", _pips_set("spec_glaze", "glaze", Color(0.55, 0.85, 1.0), _spec_bars("Frostbitten Steel"))],
		["spec_layers", "Ice Layers", "Glacier Wall: your Layers of ice.", _pips_set("spec_layers", "ice_layers", Color(0.75, 0.92, 1.0), _spec_bars("Glacier Wall"))],
		["spec_sap", "Sap", "Colossus: your Sap.", _pips_set("spec_sap", "sap", Color(0.55, 0.85, 0.3), _spec_bars("Colossus"))],
		["spec_incense", "Incense", "Censer Bearer: your Incense as a bar.", _incense_set()],
		["spec_reflections", "Reflections", "Hall of Mirrors: your Reflections.", _pips_set("spec_reflections", "reflections", Color(0.8, 0.6, 1.0), _spec_bars("Hall of Mirrors"))],
		["spec_traces", "Traces", "Second Act: the Traces your Encore would replay.", _pips_set("spec_traces", "traces", Color(0.75, 0.55, 1.0), _spec_bars("Second Act"))],
		["spec_heat", "Heat", "Forge Heat: your Heat, each pip in its band's colour (red, orange, white).", _pips_set("spec_heat", "heat", Color(1.0, 0.55, 0.15), _spec_bars("Forge Heat"))],
		["spec_slag", "Slag", "Slagforged: your Slag.", _pips_set("spec_slag", "slag", Color(1.0, 0.45, 0.2), _spec_bars("Slagforged"))],
		["spec_flow", "Flow", "The Rogue: your Flow; gold with the time left while a Kill window is open.", _flow_set()],
	]

static func _fixed(t: Dictionary, id: String) -> Dictionary:
	t["id"] = id
	return t

static func _res(res: String, op := ">=", value := 0.0) -> Dictionary:
	var tr := default_trigger("resource")
	tr["res"] = res
	tr["op"] = op
	tr["value"] = value
	tr["percent"] = false
	return tr

static func _cond(trigger: int, check: String, op: String, value: float, what: String, to: Variant) -> Dictionary:
	return {"trigger": trigger, "check": check, "op": op, "value": value, "set": what, "to": to}

static func _venom_set() -> Array:
	var col := Color(0.4, 0.95, 0.3)
	var t := _fixed(make_tracker("Venom", "bar", [_res("venom"), _res("venom_flow", ">=", 1.0)]), "spec_venom")
	var d: Dictionary = t["display"]
	d["width"] = 274
	d["height"] = 12
	d["icon"] = "none"
	d["text"] = ""
	d["text2"] = "Venom %value"
	d["time_text"] = false
	d["color"] = col.darkened(0.25)
	t["conditions"] = [_cond(2, "active", ">=", 1.0, "color", col.lightened(0.25))]
	t["load"]["bars"] = ", ".join(PackedStringArray(VenomstringKit.POISON_ARROWS))
	return [t]

static func _wheel_set() -> Array:
	var g := _fixed(make_group("Wheel", "right"), "spec_wheel")
	g["align"] = "center"
	g["spacing"] = 3
	g["sort"] = "none"
	var bars := ", ".join(PackedStringArray(AbilitiesScript.WHEEL_SLOTS + AbilitiesScript.WHEEL_ORDER))
	var out := [g]
	for i in AbilitiesScript.WHEEL_ORDER.size():
		var t := _fixed(make_tracker("Held weapon" if i == 0 else "Weapon %d" % (i + 1), "icon",
			[_res("wheel_%d" % (i + 1), ">=", 1.0)], g["id"]), "spec_wheel_%d" % (i + 1))
		var d: Dictionary = t["display"]
		d["width"] = 40 if i == 0 else 30
		d["height"] = d["width"]
		d["text"] = ""
		d["time_text"] = false
		d["click"] = "turn_wheel"
		if i > 0:
			t["conditions"] = [_cond(1, "active", ">=", 1.0, "alpha", 0.85 if i == 1 else 0.55)]
		t["load"]["bars"] = bars
		t["load"]["bars_mode"] = "any"
		out.append(t)
	var uses := _fixed(make_tracker("Uses and Cracks", "text", [_res("wheel_uses"), _res("wheel_cracks")], g["id"]), "spec_wheel_uses")
	var ud: Dictionary = uses["display"]
	ud["width"] = 150
	ud["height"] = 16
	ud["color"] = Color.WHITE
	ud["text"] = "%value / %max uses   %2.value Cracks"
	uses["load"]["bars"] = bars
	uses["load"]["bars_mode"] = "any"
	out.append(uses)
	return out

static func _chain_set() -> Array:
	var g := _fixed(make_group("Chain", "right"), "spec_chain")
	g["spacing"] = 3
	g["sort"] = "none"
	var out := [g]
	for i in BalanceScript.CHAIN_LENGTH:
		var t := _fixed(make_tracker("Chain %d" % (i + 1), "icon", [_res("chain_%d" % (i + 1), ">=", 1.0)], g["id"]), "spec_chain_%d" % (i + 1))
		var d: Dictionary = t["display"]
		d["width"] = 32
		d["height"] = 32
		d["text"] = ""
		d["time_text"] = false
		d["show_missing"] = true
		t["load"]["bars"] = ", ".join(PackedStringArray(BrawlerKit.BUTTONS))
		t["load"]["bars_mode"] = "any"
		out.append(t)
	return out

static func _sharp_set() -> Array:
	var gold := Color(1.0, 0.83, 0.3)
	var blue := Color(0.42, 0.72, 1.0)
	var g := _fixed(make_group("Sharpshooter", "right"), "spec_sharp")
	g["spacing"] = 3
	g["sort"] = "none"
	var out := [g]
	for id in AbilitiesScript.SHARP_ENGINE:
		var cd := default_trigger("cooldown")
		cd["id"] = id
		cd["show"] = "always"
		var t := _fixed(make_tracker(AbilitiesScript.ability_name(id), "icon", [cd, _res("overcut_" + id), _res("cut_" + id)], g["id"]), "spec_sharp_" + id)
		var d: Dictionary = t["display"]
		d["width"] = 32
		d["height"] = 32
		d["text"] = ""
		d["text_color"] = gold
		d["text2_color"] = blue
		t["conditions"] = [
			_cond(2, "value", ">", 0.0, "text", "+%2.value%"),
			_cond(3, "value", ">", 0.0, "text2", "-%3.value"),
			_cond(3, "percent", ">=", 100.0, "text2_color", gold),
			_cond(1, "time", ">", 0.0, "alpha", 0.5),
		]
		t["load"]["bars"] = id
		out.append(t)
	return out

static func _verses_set() -> Array:
	var t := _fixed(make_tracker("Verses", "pips", [_res("verses")]), "spec_verses")
	var d: Dictionary = t["display"]
	d["width"] = 220
	d["height"] = 10
	d["color"] = Color(1.0, 0.8, 0.3)
	d["text2"] = "%name"
	t["load"]["bars"] = ", ".join(PackedStringArray(HymnsKit.SING_IDS.keys()))
	t["load"]["bars_mode"] = "any"
	return [t]

## A spec's abilities as a load rule's "bars" text (any of them on the bars loads it).
static func _spec_bars(spec: String) -> String:
	for book in AbilitiesScript.SPECS:
		for sp in AbilitiesScript.SPECS[book]:
			if str(sp[0]) == spec:
				return ", ".join(PackedStringArray(sp[1]))
	return ""

## A spec value as pips with its name beside them (`res`: a key of Player.tracker_values()).
static func _pips_set(id: String, res: String, col: Color, bars: String) -> Array:
	var t := _fixed(make_tracker(res.capitalize(), "pips", [_res(res)]), id)
	var d: Dictionary = t["display"]
	d["width"] = 220
	d["height"] = 10
	d["color"] = col
	d["text2"] = "%name"
	t["load"]["bars"] = bars
	t["load"]["bars_mode"] = "any"
	return [t]

static func _ice_shards_set() -> Array:
	var t: Dictionary = _pips_set("spec_ice_shards", "ice_shards", Color(0.6, 0.85, 1.0), "iceshards")[0]
	t["triggers"].append(_res("ice_shards_recharge"))
	t["conditions"] = [_cond(2, "value", ">", 0.0, "text2", "%name  %2.values")]
	t["load"]["bars_mode"] = "all"
	return [t]

static func _bruise_set() -> Array:
	var t := _fixed(make_tracker("Bruise", "bar", [_res("bruise", ">", 0.0)]), "spec_bruise")
	var d: Dictionary = t["display"]
	d["width"] = 274
	d["height"] = 12
	d["icon"] = "none"
	d["text"] = ""
	d["text2"] = "Bruise %value"
	d["time_text"] = false
	d["color"] = Color(0.6, 0.35, 0.7)
	t["load"]["bars"] = ", ".join(PackedStringArray(BrawlerKit.BUTTONS))
	t["load"]["bars_mode"] = "any"
	return [t]

static func _incense_set() -> Array:
	var t := _fixed(make_tracker("Incense", "bar", [_res("incense")]), "spec_incense")
	var d: Dictionary = t["display"]
	d["width"] = 274
	d["height"] = 12
	d["icon"] = "none"
	d["text"] = ""
	d["text2"] = "Incense %value"
	d["time_text"] = false
	d["color"] = Color(1.0, 0.85, 0.45)
	t["load"]["bars"] = _spec_bars("Censer Bearer")
	t["load"]["bars_mode"] = "any"
	return [t]

static func _flow_set() -> Array:
	var t: Dictionary = _pips_set("spec_flow", "flow", Color(0.85, 0.3, 0.3), _spec_bars("Rogue"))[0]
	var kill := default_trigger("effect")
	kill["id"] = "kill_window"
	kill["stacks"] = 1.0   # (as clean() keeps it)
	t["triggers"].append(kill)
	t["conditions"] = [_cond(2, "active", ">=", 1.0, "color", Color(1.0, 0.83, 0.3)),
		_cond(2, "active", ">=", 1.0, "text2", "Kill %2.time")]
	return [t]

## Put what's missing into `settings` (Settings): the role layout's starting groups
## (once, after the UI setup picked a role: Settings.tracker_builtins) and every
## spec set's trackers, unless the player deleted them (Settings.tracker_deleted,
## forget_builtin), so a deleted one stays deleted and a lost one comes back. They
## land in Settings.trackers as plain trackers, the same as ones the player built.
## The HUD and the editor (also from the main menu) both call it. True if it added any.
static func give_builtins(settings: Node) -> bool:
	var given: Array = settings.tracker_builtins
	var deleted: Array = settings.tracker_deleted
	var all: Dictionary = settings.trackers
	var added := false
	if not given.has("role_defaults") and bool(settings.ui_installed):
		for t in default_groups(UIConfig.role()):
			if not all.has(t["id"]):
				all[t["id"]] = t
		given.append("role_defaults")
		added = true
	for sp in spec_sets():
		for t in sp[3]:
			if not all.has(t["id"]) and not deleted.has(t["id"]) and all.size() < MAX_TRACKERS:
				all[t["id"]] = t
				added = true
	if added:
		settings.save()
	return added

## The player deleted tracker / group `id`: a spec set's one stays deleted (give_builtins).
static func forget_builtin(settings: Node, id: String) -> void:
	var deleted: Array = settings.tracker_deleted
	if deleted.has(id):
		return
	for sp in spec_sets():
		for t in sp[3]:
			if str(t["id"]) == id:
				deleted.append(id)
				return

## A spec set's items with fresh ids (adding it again from the editor while a copy is there).
static func fresh_copy(items: Array) -> Array:
	return parse_export(export_items(items))

# --- Checking -------------------------------------------------------------------------

## A tracker or group as saved / imported, made safe: known fields only, right types.
static func clean(t: Variant) -> Dictionary:
	if not (t is Dictionary) or not t.has("id"):
		return {}
	var kind := str(t.get("kind", "tracker"))
	if kind == "group":
		var g := make_group(str(t.get("name", "Group")))
		g["id"] = str(t["id"])
		g["enabled"] = bool(t.get("enabled", true))
		g["grow"] = _pick(t.get("grow"), ["down", "up", "left", "right"], "up")
		g["align"] = _pick(t.get("align"), ["start", "center", "end"], "start")
		g["spacing"] = clampi(int(t.get("spacing", 2)), 0, 40)
		g["sort"] = _pick(t.get("sort"), ["none", "time", "name"], "time")
		return g
	var out := make_tracker(str(t.get("name", "Tracker")).left(60), "icon", [], str(t.get("group", "")))
	out["id"] = str(t["id"])
	out["enabled"] = bool(t.get("enabled", true))
	out["combine"] = _pick(t.get("combine"), ["any", "all"], "any")
	var d: Dictionary = t.get("display", {}) if t.get("display") is Dictionary else {}
	var dt := _pick(d.get("type"), DISPLAY_TYPES, "icon")
	var disp := default_display(dt)
	disp["width"] = clampi(int(d.get("width", disp["width"])), 8, 800)
	disp["height"] = clampi(int(d.get("height", disp["height"])), 8, 400)
	for k in ["color", "text_color", "text2_color"]:
		disp[k] = d[k] if d.get(k) is Color else disp[k]
	disp["text"] = str(d.get("text", disp["text"])).left(80)
	disp["text2"] = str(d.get("text2", disp["text2"])).left(80)
	disp["icon"] = str(d.get("icon", "auto")).left(60)
	disp["click"] = str(d.get("click", "")).left(40)
	for b in ["glow", "sound", "show_missing", "time_text"]:
		disp[b] = bool(d.get(b, disp[b]))
	out["display"] = disp
	var trs: Array = []
	for tr in (t.get("triggers", []) if t.get("triggers") is Array else []):
		var c := clean_trigger(tr)
		if not c.is_empty():
			trs.append(c)
	out["triggers"] = trs.slice(0, 5)
	var conds: Array = []
	for c in (t.get("conditions", []) if t.get("conditions") is Array else []):
		if c is Dictionary:
			var n: Variant = c.get("trigger", 0)
			conds.append({"trigger": clampi(int(n) if (n is int or n is float) else 0, 0, 5),
				"check": _pick(c.get("check"), CHECKS, "stacks"), "op": _pick(c.get("op"), OPS, ">="),
				"value": float(c.get("value", 0.0)) if (c.get("value") is float or c.get("value") is int) else 0.0,
				"set": _pick(c.get("set"), SETS, "color"), "to": _clean_to(c.get("to"))})
	out["conditions"] = conds.slice(0, 5)
	var l: Dictionary = t.get("load", {}) if t.get("load") is Dictionary else {}
	out["load"] = {"spec": str(l.get("spec", "")).left(40), "role": _pick(l.get("role"), ["", "tank", "healer", "dps"], ""),
		"combat": _pick(l.get("combat"), ["any", "in", "out"], "any"), "party": _pick(l.get("party"), ["any", "yes", "no"], "any"),
		"dungeon": _pick(l.get("dungeon"), ["any", "yes"], "any"), "bars": str(l.get("bars", "")).left(200),
		"bars_mode": _pick(l.get("bars_mode"), ["all", "any"], "all")}
	return out

static func clean_trigger(tr: Variant) -> Dictionary:
	if not (tr is Dictionary):
		return {}
	var type := str(tr.get("type", ""))
	if not TRIGGER_TYPES.has(type):
		return {}
	var out := default_trigger(type)
	for k in out:
		if not tr.has(k):
			continue
		var d: Variant = out[k]
		var v: Variant = tr[k]
		if d is bool:
			out[k] = bool(v) if (v is bool or v is int) else d
		elif d is float or d is int:
			out[k] = float(v) if (v is float or v is int) else d
		else:
			out[k] = str(v).left(60)
	if out.has("unit"):
		out["unit"] = _pick(out["unit"], UNITS, "player")
	if out.has("op"):
		out["op"] = _pick(out["op"], OPS, ">=")
	if out.has("event"):
		out["event"] = _pick(out["event"], EVENTS, "ability_used")
	if out.has("state"):
		out["state"] = _pick(out["state"], STATES, "in_combat")
	if out.has("show"):
		out["show"] = _pick(out["show"], ["ready", "cooldown", "always"], "ready")
	if out.has("duration"):
		out["duration"] = clampf(float(out["duration"]), 0.2, 60.0)
	return out

static func _pick(v: Variant, allowed: Array, fallback: String) -> String:
	return str(v) if v != null and allowed.has(str(v)) else fallback

static func _clean_to(v: Variant) -> Variant:
	if v is Color or v is bool:
		return v
	if v is float or v is int:
		return clampf(float(v), 0.0, 1.0)
	return str(v).left(60) if v != null else ""

# --- Export / import --------------------------------------------------------------------

## One tracker, or a group with its trackers, as one line of text.
static func export_items(items: Array) -> String:
	return EXPORT_PREFIX + Marshalls.utf8_to_base64(var_to_str(items))

## The trackers / groups in an exported line, with new ids ([] when it isn't one).
static func parse_export(text: String) -> Array:
	text = text.strip_edges()
	if not text.begins_with(EXPORT_PREFIX):
		return []
	var raw := Marshalls.base64_to_utf8(text.trim_prefix(EXPORT_PREFIX))
	var data: Variant = str_to_var(raw) if raw != "" else null
	if not (data is Array):
		return []
	var ids := {}
	var out: Array = []
	for t in data:
		var c := clean(t)
		if c.is_empty():
			continue
		var fresh := new_id("g" if c["kind"] == "group" else "t") + "_%d" % out.size()
		ids[c["id"]] = fresh
		c["id"] = fresh
		out.append(c)
	for c in out:   # a group's trackers follow it to its new id
		if c["kind"] == "tracker" and ids.has(str(c["group"])):
			c["group"] = ids[c["group"]]
		elif c["kind"] == "tracker":
			c["group"] = ""
	return out.slice(0, MAX_TRACKERS)

# --- Evaluating -------------------------------------------------------------------------

## What one trigger sees: {active, name, stacks, time, duration, value, max, icon, color, colors}.
## `ctx`: {player, target, party (Array of bodies), events ({key -> time}), now,
## values (the player's tracker_values(), worked out once a sweep)}.
static func eval_trigger(tr: Dictionary, ctx: Dictionary) -> Dictionary:
	var st := {"active": false, "name": "", "stacks": 0, "time": 0.0, "duration": 0.0, "value": 0.0,
		"max": 0.0, "icon": "", "color": Color(0, 0, 0, 0)}
	var player: Node = ctx.get("player")
	match str(tr.get("type")):
		"effect":
			var id := str(tr.get("id", ""))
			var units: Array = []
			match str(tr.get("unit", "player")):
				"player": units = [player]
				"target": units = [ctx.get("target")]
				"party": units = ctx.get("party", [])
			var found: Dictionary = {}
			for u in units:
				if u == null or not is_instance_valid(u):
					continue
				var status: Node = u.get_node_or_null("Status")
				if status == null or not status.has_method("list"):
					continue
				for e in status.list():
					if str(e["id"]) != id:
						continue
					if bool(tr.get("own", true)) and str(tr.get("unit")) == "target" and not bool(e.get("mine", true)):
						continue   # own-only: an ally's copy doesn't count
					if found.is_empty() or float(e["remaining"]) > float(found["remaining"]):
						found = e
			var has := not found.is_empty() and compare(float(found.get("stacks", 0)), str(tr.get("op", ">=")), float(tr.get("stacks", 1)))
			st["name"] = str(found.get("name", effect_name(id)))
			st["icon"] = id
			if not found.is_empty():
				st["stacks"] = int(found["stacks"])
				st["time"] = float(found["remaining"])
				st["value"] = float(found["stacks"])
				st["color"] = found.get("color", Color.WHITE)
			st["active"] = has != bool(tr.get("missing", false))
		"cooldown":
			var id := str(tr.get("id", ""))
			st["name"] = AbilitiesScript.ability_name(id) if id != "" else ""
			st["icon"] = id
			if player == null or id == "":
				return st
			var left: float = player.cooldown_left(id) if player.has_method("cooldown_left") else 0.0
			var total: float = player.cooldown_total(id) if player.has_method("cooldown_total") else 0.0
			st["time"] = left
			st["duration"] = total
			var ch: String = player.charges_text(id) if player.has_method("charges_text") else ""
			st["stacks"] = int(ch) if ch.is_valid_int() else 0
			match str(tr.get("show", "ready")):
				"ready": st["active"] = left <= 0.0
				"cooldown": st["active"] = left > 0.0
				_: st["active"] = true
		"resource":
			var res := str(tr.get("res", "health"))
			var v := 0.0
			var mx := 0.0
			if player != null:
				if res == "health":
					v = float(player.health)
					mx = float(player.max_health)
				elif RESOURCES.has(res) and player.has_method("resource_points"):
					v = float(player.resource_points(res))
					mx = float(player.resource_max(res))
				else:
					var vals: Variant = ctx.get("values")
					if vals == null and player.has_method("tracker_values"):
						vals = player.tracker_values()
					var tv: Variant = (vals as Dictionary).get(res) if vals is Dictionary else null
					if tv is Dictionary:
						v = float(tv.get("value", 0.0))
						mx = float(tv.get("max", 0.0))
						st["icon"] = str(tv.get("icon", ""))
						if tv.has("name"):
							st["name"] = str(tv["name"])
						if tv.get("colors") is Array:
							st["colors"] = tv["colors"]
					elif tv != null:
						v = float(tv)
			if str(st["name"]) == "":
				st["name"] = res.capitalize()
			st["value"] = v
			st["max"] = mx
			var test := v / mx * 100.0 if bool(tr.get("percent", false)) and mx > 0.0 else v
			st["active"] = (mx > 0.0 or v != 0.0 or not RESOURCES.has(res)) and compare(test, str(tr.get("op", ">=")), float(tr.get("value", 0.0)))
		"event":
			var key := event_key(str(tr.get("event")), str(tr.get("id", "")))
			var at: Variant = (ctx.get("events", {}) as Dictionary).get(key)
			var dur := float(tr.get("duration", 3.0))
			var now := float(ctx.get("now", 0.0))
			st["name"] = str((ctx.get("event_names", {}) as Dictionary).get(key, EVENT_NAMES[maxi(EVENTS.find(str(tr.get("event"))), 0)]))
			st["icon"] = str(tr.get("id", ""))
			if at != null and now - float(at) < dur:
				st["active"] = true
				st["time"] = dur - (now - float(at))
				st["duration"] = dur
		"item":
			var id := str(tr.get("id", ""))
			var pd: Node = ctx.get("player_data")
			st["name"] = ItemsScript.item_name(id) if id != "" else ""
			if pd != null and id != "":
				for eq in (pd.equipment as Dictionary).values():
					if str(eq) != "" and ItemsScript.base_id(str(eq)) == id:
						st["active"] = true
		"state":
			st["name"] = STATE_NAMES[maxi(STATES.find(str(tr.get("state"))), 0)]
			st["active"] = state_on(str(tr.get("state")), ctx)
	return st

static func state_on(state: String, ctx: Dictionary) -> bool:
	var player: Node = ctx.get("player")
	var target: Node = ctx.get("target")
	var combat: bool = player != null and player.has_method("is_in_combat") and player.is_in_combat()
	match state:
		"in_combat": return combat
		"no_combat": return not combat
		"has_target": return target != null
		"target_hostile": return target != null and not (target.is_in_group("remote_player") or target.is_in_group("friendly") or target.is_in_group("player"))
		"target_casting": return target != null and target.has_method("cast_progress") and float(target.cast_progress()) >= 0.0
		"party_dead":
			for b in ctx.get("party", []):
				if b != null and is_instance_valid(b) and int(b.get("health")) <= 0:
					return true
			return false
		"in_dungeon": return bool(ctx.get("in_dungeon", false))
		"boss_engaged": return bool(ctx.get("boss", false))
	return false

## A whole tracker: its triggers combined ("any": the first active one shows;
## "all": every one active, the first one's values shown). "triggers" holds every
## trigger's state, for %2.value texts and conditions on another trigger.
static func eval_tracker(t: Dictionary, ctx: Dictionary) -> Dictionary:
	var states: Array = []
	for tr in t.get("triggers", []):
		states.append(eval_trigger(tr, ctx))
	if states.is_empty():
		return {"active": false}
	var shown: Dictionary = states[0]
	if str(t.get("combine", "any")) == "all":
		for s in states:
			if not bool(s["active"]):
				shown = {"active": false, "name": shown["name"]}
				break
	else:
		for s in states:
			if bool(s["active"]):
				shown = s
				break
	shown = shown.duplicate()
	shown["triggers"] = states
	return shown

## Whether a tracker's load rules let it run now. `ctx` adds spec, role, combat, party, in_dungeon.
static func loaded(t: Dictionary, ctx: Dictionary) -> bool:
	if not bool(t.get("enabled", true)):
		return false
	var l: Dictionary = t.get("load", {})
	if str(l.get("spec", "")) != "" and str(l["spec"]) != str(ctx.get("spec", "")):
		return false
	if str(l.get("role", "")) != "" and str(l["role"]) != str(ctx.get("role", "")):
		return false
	match str(l.get("combat", "any")):
		"in":
			if not bool(ctx.get("combat", false)):
				return false
		"out":
			if bool(ctx.get("combat", false)):
				return false
	match str(l.get("party", "any")):
		"yes":
			if not bool(ctx.get("in_party", false)):
				return false
		"no":
			if bool(ctx.get("in_party", false)):
				return false
	if str(l.get("dungeon", "any")) == "yes" and not bool(ctx.get("in_dungeon", false)):
		return false
	var want := bar_ids(str(l.get("bars", "")))
	if not want.is_empty():
		var on: Array = ctx.get("bars", [])
		var hits := want.filter(func(id): return on.has(id)).size()
		if hits == 0 or (str(l.get("bars_mode", "all")) == "all" and hits < want.size()):
			return false
	return true

## The ids in a load rule's "bars" text ("a, b, c").
static func bar_ids(text: String) -> Array:
	var out: Array = []
	for p in text.split(",", false):
		if p.strip_edges() != "":
			out.append(p.strip_edges())
	return out

## Conditions that hold for a state: the changes they make ({color, glow, alpha, text, ...}).
## A condition looks at the shown state (trigger 0) or at trigger N's own state.
static func apply_conditions(t: Dictionary, st: Dictionary) -> Dictionary:
	var out := {}
	for c in t.get("conditions", []):
		var src := _trigger_state(st, int(c.get("trigger", 0)))
		var v := 0.0
		match str(c["check"]):
			"stacks": v = float(src.get("stacks", 0))
			"time": v = float(src.get("time", 0.0))
			"value": v = float(src.get("value", 0.0))
			"percent": v = float(src.get("value", 0.0)) / maxf(float(src.get("max", 0.0)), 0.0001) * 100.0
			"active": v = 1.0 if bool(src.get("active", false)) else 0.0
		if compare(v, str(c["op"]), float(c["value"])):
			out[str(c["set"])] = c["to"]
	return out

static func compare(a: float, op: String, b: float) -> bool:
	match op:
		">=": return a >= b
		"<=": return a <= b
		">": return a > b
		"<": return a < b
		"=": return is_equal_approx(a, b)
	return false

## Trigger `n`'s own state (1-5), or the shown one (0, or no such trigger).
static func _trigger_state(st: Dictionary, n: int) -> Dictionary:
	var trs: Array = st.get("triggers", [])
	return trs[n - 1] if n >= 1 and n <= trs.size() else st

## The text a display shows: %name %stacks %time %value %max %percent %target, and
## %2.value (any field of trigger 2's own state).
static func format_text(fmt: String, st: Dictionary, target_name := "") -> String:
	if fmt.contains("."):
		for n in range(5, 0, -1):
			for f in FIELDS:
				var tag := "%%%d.%s" % [n, f]
				if fmt.contains(tag):
					fmt = fmt.replace(tag, field_text(f, _trigger_state(st, n)))
	for f in FIELDS:
		fmt = fmt.replace("%" + f, field_text(f, st))
	return fmt.replace("%target", target_name)

## One field of a state as text.
static func field_text(f: String, st: Dictionary) -> String:
	match f:
		"name": return str(st.get("name", ""))
		"stacks":
			var stacks := int(st.get("stacks", 0))
			return str(stacks) if stacks > 1 else ""
		"time": return UISkin.time_text(float(st.get("time", 0.0)))
		"value": return num_text(float(st.get("value", 0.0)))
		"max": return num_text(float(st.get("max", 0.0)))
		"percent":
			var mx := float(st.get("max", 0.0))
			return str(int(round(float(st.get("value", 0.0)) / mx * 100.0))) if mx > 0.0 else "0"
	return ""

## A number for a text: one decimal below 10 when it isn't whole (a 1.5 sec cut).
static func num_text(v: float) -> String:
	if absf(v) < 10.0 and not is_equal_approx(v, roundf(v)):
		return "%.1f" % v
	return UISkin.short(int(v))

## Events are remembered as "event" and "event:id" (an id filter matches the second).
static func event_key(event: String, id: String) -> String:
	return event if id == "" else "%s:%s" % [event, id]

static func effect_name(id: String) -> String:
	var r: Resource = EffectsScript.get_effect(id) if id != "" else null
	if r != null and r.get("display_name") != null:
		return str(r.display_name)
	return id.capitalize()

## Every id to pick from, for the editor's ID picker: [[id, name, kind]] of kind
## "ability", "item" or "effect".
static func all_ids() -> Array:
	var out: Array = []
	for id in AbilitiesScript.PATHS:
		out.append([str(id), AbilitiesScript.ability_name(str(id)), "ability"])
	for id in ItemsScript.PATHS:
		out.append([str(id), ItemsScript.item_name(str(id)), "item"])
	for id in EffectsScript.all_ids():
		out.append([str(id), effect_name(str(id)), "effect"])
	return out
