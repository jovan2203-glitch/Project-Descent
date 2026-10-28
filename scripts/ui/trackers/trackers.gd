class_name Trackers

# Trackers: UI elements you build yourself (aura bars, cooldown icons, proc
# alerts, resource bars), like WeakAuras. This file is the data side: what a
# tracker and a group hold, the templates, the default groups per role,
# checking saved / imported data, and evaluating triggers. The engine
# (tracker_engine.gd) runs them, tracker_display.gd draws one, the editor
# (tracker_editor.gd, /trackers) builds them. Saved in Settings.trackers.
#
# A tracker: {id, name, kind "tracker", group (a group's id or ""), enabled,
#   display {type icon / bar / text / ring, width, height, color, text, icon,
#            glow, sound, show_missing},
#   triggers [trigger...], combine "any" / "all",
#   conditions [{check stacks / time / value / percent, op, value, set color / glow / alpha / text, to}],
#   load {spec, role, combat any / in / out, party any / yes / no, dungeon any / yes}}
# A group: {id, name, kind "group", enabled, grow down / up / left / right, spacing, sort none / time / name}
#
# Triggers read only what this client knows (your own state, your target's
# effects, the party frames), so a tracker works the same for host and guests.
# IDs: abilities (Abilities), items (Items), effects (Effects.all_ids() plus
# runtime ids such as rune procs): tooltips show them with "Show IDs in tooltips".

const DISPLAY_TYPES := ["icon", "bar", "text", "ring"]
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
const CHECKS := ["stacks", "time", "value", "percent"]
const SETS := ["color", "glow", "alpha", "text"]
const MAX_TRACKERS := 200
const AbilitiesScript = preload("res://scripts/abilities.gd")
const ItemsScript = preload("res://scripts/items.gd")
const EffectsScript = preload("res://scripts/core/effects.gd")
const EXPORT_PREFIX := "TRK1:"

# --- Making ---------------------------------------------------------------------------

static func new_id(prefix := "t") -> String:
	return "%s_%d_%d" % [prefix, Time.get_unix_time_from_system(), randi() % 100000]

static func default_display(type := "icon") -> Dictionary:
	return {"type": type, "width": 160 if type == "bar" else 40, "height": 18 if type == "bar" else 40,
		"color": Color(0.3, 0.75, 1.0), "text": "%name" if type == "bar" else "%stacks", "icon": "auto",
		"glow": false, "sound": false, "show_missing": false, "time_text": true}

static func default_load() -> Dictionary:
	return {"spec": "", "role": "", "combat": "any", "party": "any", "dungeon": "any"}

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
	return {"id": new_id("g"), "name": name, "kind": "group", "enabled": true, "grow": grow, "spacing": 2, "sort": "time"}

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
	disp["color"] = d["color"] if d.get("color") is Color else disp["color"]
	disp["text"] = str(d.get("text", disp["text"])).left(80)
	disp["icon"] = str(d.get("icon", "auto")).left(60)
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
			conds.append({"check": _pick(c.get("check"), CHECKS, "stacks"), "op": _pick(c.get("op"), OPS, ">="),
				"value": float(c.get("value", 0.0)) if (c.get("value") is float or c.get("value") is int) else 0.0,
				"set": _pick(c.get("set"), SETS, "color"), "to": _clean_to(c.get("to"))})
	out["conditions"] = conds.slice(0, 5)
	var l: Dictionary = t.get("load", {}) if t.get("load") is Dictionary else {}
	out["load"] = {"spec": str(l.get("spec", "")).left(40), "role": _pick(l.get("role"), ["", "tank", "healer", "dps"], ""),
		"combat": _pick(l.get("combat"), ["any", "in", "out"], "any"), "party": _pick(l.get("party"), ["any", "yes", "no"], "any"),
		"dungeon": _pick(l.get("dungeon"), ["any", "yes"], "any")}
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

## What one trigger sees: {active, name, stacks, time, duration, value, max, icon, color}.
## `ctx`: {player, target, party (Array of bodies), events ({key -> time}), now}.
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
				elif player.has_method("tracker_values"):
					var tv: Variant = player.tracker_values().get(res)
					if tv is Dictionary:
						v = float(tv.get("value", 0.0))
						mx = float(tv.get("max", 0.0))
					elif tv != null:
						v = float(tv)
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
## "all": every one active, the first one's values shown).
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
				return {"active": false, "name": shown["name"]}
		return shown
	for s in states:
		if bool(s["active"]):
			return s
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
	return true

## Conditions that hold for a state: the changes they make ({color, glow, alpha, text}).
static func apply_conditions(t: Dictionary, st: Dictionary) -> Dictionary:
	var out := {}
	for c in t.get("conditions", []):
		var v := 0.0
		match str(c["check"]):
			"stacks": v = float(st.get("stacks", 0))
			"time": v = float(st.get("time", 0.0))
			"value": v = float(st.get("value", 0.0))
			"percent": v = float(st.get("value", 0.0)) / maxf(float(st.get("max", 0.0)), 0.0001) * 100.0
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

## The text a display shows: %name %stacks %time %value %max %percent %target.
static func format_text(fmt: String, st: Dictionary, target_name := "") -> String:
	var stacks := int(st.get("stacks", 0))
	var mx := float(st.get("max", 0.0))
	var pct := int(round(float(st.get("value", 0.0)) / mx * 100.0)) if mx > 0.0 else 0
	return fmt.replace("%name", str(st.get("name", ""))) \
		.replace("%stacks", str(stacks) if stacks > 1 else "") \
		.replace("%time", UISkin.time_text(float(st.get("time", 0.0)))) \
		.replace("%value", UISkin.short(int(st.get("value", 0.0)))) \
		.replace("%max", UISkin.short(int(mx))) \
		.replace("%percent", str(pct)) \
		.replace("%target", target_name)

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
