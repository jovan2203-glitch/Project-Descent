extends RefCounted

# Macros: action-bar buttons the player writes (Esc menu > Macros).
# A macro is a short text, one command per line:
#   /cast <ability>                 use that ability        (also: /use, or just the name)
#   /castsequence A, B, C           each press uses the next one in the list
#   /castsequence reset=6 A, B, C   ... starting over after 6 sec without a press
#   # anything                      a note (ignored)
# One press runs every line from the top. Everything that is off the global
# cooldown (trinkets, interrupts) goes off together; of the abilities that use
# the global cooldown, the first one that can be used is.
# A macro may be LINKED to one ability: its button then shows that ability's
# cooldown, charges, range and tooltip.
#
# Macros live in PlayerData.macros as {"uid", "name", "icon", "link", "text"}.
# On the action bar a macro is the id "macro:<uid>".
# Usage: const Macros = preload("res://scripts/core/macros.gd")

const PREFIX := "macro:"
const MAX_MACROS := 40
const MAX_NAME := 24
const MAX_TEXT := 600
## Icon keys: "a:<ability id>" or "t:<talent id>" ("" = the plain macro glyph).
const DEFAULT_ICON := ""

static func is_macro(id: String) -> bool:
	return id.begins_with(PREFIX)

static func bar_id(uid: int) -> String:
	return PREFIX + str(uid)

static func uid_of(id: String) -> int:
	return int(id.trim_prefix(PREFIX)) if is_macro(id) else -1

static func _pd() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("PlayerData") if tree and tree.root else null

static func _abilities() -> GDScript:
	return load("res://scripts/abilities.gd")

## The macro behind bar id `id` ({} if it was deleted).
static func find(id: String) -> Dictionary:
	var pd := _pd()
	if pd == null or not is_macro(id):
		return {}
	return pd.macro_by_uid(uid_of(id))

static func exists(id: String) -> bool:
	return not find(id).is_empty()

## The ability a macro is linked to ("" = none, or it no longer exists).
static func link_of(id: String) -> String:
	var link := str(find(id).get("link", ""))
	return link if link != "" and _abilities().get_resource(link) != null else ""

# --- Reading the text ----------------------------------------------------------------------

## The ability a name in a macro means: its name ("Frost Bolt"), its id, or
## "Trinket 1" / "Trinket 2". "" if there is none.
static func ability_by_name(text: String) -> String:
	var want := text.strip_edges().to_lower()
	if want == "":
		return ""
	var A := _abilities()
	if want == "trinket 1" or want == "trinket1":
		return "trinket_1"
	if want == "trinket 2" or want == "trinket2":
		return "trinket_2"
	for id in A.ALL:
		if want == str(id) or want == str(A.ability_name(str(id))).to_lower():
			return str(id)
	return ""

## What a macro does, line by line:
##   {"steps": [{"kind": "cast", "ability": id} | {"kind": "sequence", "abilities": [ids], "reset": seconds}],
##    "problems": ["Line 2: ..."]}
static func parse(text: String) -> Dictionary:
	var steps: Array = []
	var problems: Array[String] = []
	var n := 0
	for raw in text.split("\n"):
		n += 1
		var line := str(raw).strip_edges()
		if line == "" or line.begins_with("#") or line.begins_with("--"):
			continue
		var lower := line.to_lower()
		if lower.begins_with("/castsequence") or lower.begins_with("/sequence"):
			var rest := line.substr(line.find(" ") + 1).strip_edges() if line.contains(" ") else ""
			var reset := 0.0
			if rest.to_lower().begins_with("reset="):
				var end := rest.find(" ")
				reset = maxf(float(rest.substr(6, (end - 6) if end > 0 else -1)), 0.0)
				rest = rest.substr(end + 1).strip_edges() if end > 0 else ""
			var ids: Array = []
			for part in rest.split(",", false):
				var id := ability_by_name(str(part))
				if id == "":
					problems.append("Line %d: no ability called \"%s\"" % [n, str(part).strip_edges()])
				else:
					ids.append(id)
			if ids.is_empty():
				problems.append("Line %d: a sequence needs abilities, separated by commas" % n)
			else:
				steps.append({"kind": "sequence", "abilities": ids, "reset": reset})
			continue
		var name := line
		if lower.begins_with("/cast ") or lower.begins_with("/use "):
			name = line.substr(line.find(" ") + 1)
		elif line.begins_with("/"):
			problems.append("Line %d: unknown command \"%s\" (use /cast or /castsequence)" % [n, line.split(" ")[0]])
			continue
		var id := ability_by_name(name)
		if id == "":
			problems.append("Line %d: no ability called \"%s\"" % [n, name.strip_edges()])
		else:
			steps.append({"kind": "cast", "ability": id})
	return {"steps": steps, "problems": problems}

## Every ability a macro can use (for resource bars and the like).
static func abilities_in(text: String) -> Array[String]:
	var out: Array[String] = []
	for st in parse(text)["steps"]:
		var ids: Array = [st["ability"]] if st["kind"] == "cast" else st["abilities"]
		for id in ids:
			if not out.has(str(id)):
				out.append(str(id))
	return out

static func abilities_of(id: String) -> Array[String]:
	var m := find(id)
	var none: Array[String] = []
	return abilities_in(str(m.get("text", ""))) if not m.is_empty() else none

# --- Icon and tooltip ------------------------------------------------------------------------

## Draw icon `key` ("a:<ability>", "t:<talent>") filling `c`; anything else
## draws the plain macro glyph.
static func draw_icon_key(c: Control, key: String) -> void:
	if key.begins_with("a:") and _abilities().get_resource(key.substr(2)) != null:
		_abilities().draw_icon(c, key.substr(2))
		return
	if key.begins_with("t:"):
		var icons: GDScript = load("res://scripts/talent_icons.gd")
		if icons.has_icon(key.substr(2)):
			icons.draw(c, key.substr(2))
			return
	# Plain glyph: a scroll with lines.
	var s := c.size
	var k: float = minf(s.x, s.y) / 52.0
	var mid := s / 2.0
	c.draw_rect(Rect2(Vector2(5, 5), s - Vector2(10, 10)), Color(0.16, 0.13, 0.09), true)
	c.draw_rect(Rect2(mid + Vector2(-13, -16) * k, Vector2(26, 32) * k), Color(0.85, 0.78, 0.6), true)
	for i in 4:
		var y := -9.0 + i * 6.5
		c.draw_line(mid + Vector2(-8, y) * k, mid + Vector2(8 if i < 3 else 2, y) * k, Color(0.3, 0.24, 0.16), 2.0 * k)

## A macro's action-bar icon: its own picture with a small "M" in the corner.
static func draw_icon(c: Control, id: String) -> void:
	var m := find(id)
	var key := str(m.get("icon", DEFAULT_ICON))
	if key == "" and str(m.get("link", "")) != "":
		key = "a:" + str(m.get("link", ""))   # no picture chosen: the linked ability's
	draw_icon_key(c, key)
	var f := ThemeDB.fallback_font
	var size := maxi(int(c.size.y * 0.24), 9)
	var p := Vector2(c.size.x - size * 0.95, size * 1.05)
	c.draw_string_outline(f, p, "M", HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color.BLACK)
	c.draw_string(f, p, "M", HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.95, 0.75, 0.35))

## Tooltip of a macro button: the linked ability's tooltip under the macro's
## name, or (not linked) what the macro does.
static func tooltip_bbcode(id: String, detailed: bool = false) -> String:
	var m := find(id)
	var dim := "9e9ead"
	if m.is_empty():
		return "[color=#%s]This macro was deleted.[/color]" % dim
	var head := "[color=#f2bf59]Macro: %s[/color]" % str(m.get("name", "")).replace("[", "[lb]")
	var link := link_of(id)
	if link != "":
		return head + "\n" + str(_abilities().tooltip_bbcode(link, detailed))
	var lines: Array[String] = [head]
	var text := str(m.get("text", "")).strip_edges()
	lines.append(text.replace("[", "[lb]") if text != "" else "[color=#%s]Empty.[/color]" % dim)
	lines.append("[color=#%s][font_size=11]Not linked to an ability: no cooldown is shown. Link one in Esc > Macros.[/font_size][/color]" % dim)
	return "\n".join(lines)
