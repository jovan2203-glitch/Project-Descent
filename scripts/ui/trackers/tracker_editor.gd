extends Node
class_name TrackerEditor

# The Trackers editor (/trackers, Settings > Interface, UI Options): the list of
# your trackers and groups on the left (Up / Down orders them); on the right the
# picked one's pages: Display (icon / bar / text / ring / pips, size, colours, two
# texts with %name %stacks %time %value %max %percent %target and %2.value for
# trigger 2, on click), Triggers (what makes it show), Conditions (change colour /
# glow / opacity / a text when a value of any trigger passes a mark) and Load
# (spec, role, combat, party, dungeon, abilities on your bars). New from a
# template or a spec set (the Venom bar, the Wheel...), duplicate, delete, and
# Import / Export one tracker or a whole group as a line of text. Changes apply
# at once; the picked tracker shows with made-up values while you edit. While it
# is open, clicking a tracker on screen opens it here (TrackerDisplay.picking).
# The window can be resized (corner grip) and minimized to its title bar.

const NODE := "TrackerEditor"
const AbilitiesScript = preload("res://scripts/abilities.gd")

var win: UIWindow
var _list: Tree
var _right: VBoxContainer
var _sel := ""
var _open_on := ""   # (a new window: the tracker to pick once it is built)

static func open(tree: SceneTree, id := "") -> void:
	var s := tree.root.get_node_or_null("Settings")
	if s != null:
		Trackers.give_builtins(s)   # the spec sets are in the list even before a dungeon
	var w := UIWindow.make(tree, NODE, "Trackers", Vector2(940, 600))
	var e: TrackerEditor
	if w.is_new:
		e = TrackerEditor.new()
		e.name = "Editor"
		e.win = w
		e._open_on = id
		w.add_child(e)   # (built in _ready: the window joins the tree a frame later)
		w.tree_exiting.connect(func():
			var engine := TrackerEngine.of(tree)
			if engine:
				engine.set_preview("", false)
				engine.set_picking(false))
		return
	e = w.get_node("Editor")
	if id != "":
		e.select(id)

## Built once in the tree: before that, /root/Settings can't be reached and the
## list would come up empty ("No trackers yet") while the trackers are there.
func _ready() -> void:
	_build()
	if _open_on != "":
		select(_open_on)
	# While it is open, click a tracker on screen to open it here.
	var engine := TrackerEngine.of(get_tree())
	if engine:
		engine.set_picking(true)
	win.enable_resize(Vector2(620, 380))
	win.enable_minimize()

func _settings() -> Node:
	return UIConfig.settings()   # (from the main loop: works before this joins the tree too)

func _all() -> Dictionary:
	var s := _settings()
	return s.trackers if s else {}

## Save and let the HUD's engine make its displays again.
func _changed(rebuild_list := false) -> void:
	var s := _settings()
	if s:
		s.save()
	var engine := TrackerEngine.of(get_tree())
	if engine:
		engine.rebuild()
		engine.set_preview.call_deferred(_sel, true)
	if rebuild_list:
		_fill_list()

func _build() -> void:
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 10)
	win.body.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	cols.add_child(left)
	_list = Tree.new()
	_list.hide_root = true
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.focus_mode = Control.FOCUS_NONE
	_list.add_theme_stylebox_override("panel", UISkin.backdrop(0.6, 4))
	_list.item_selected.connect(func():
		var it := _list.get_selected()
		if it:
			select(str(it.get_metadata(0))))
	left.add_child(_list)
	var new_row := HBoxContainer.new()
	left.add_child(new_row)
	var templates := OptionButton.new()
	templates.focus_mode = Control.FOCUS_NONE
	templates.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n_templates := Trackers.templates().size()
	for t in Trackers.templates():
		templates.add_item(t[0])
		templates.set_item_tooltip(templates.item_count - 1, t[1])
	for sp in Trackers.spec_sets():
		templates.add_item("Spec: " + str(sp[1]))
		templates.set_item_tooltip(templates.item_count - 1, sp[2])
	new_row.add_child(templates)
	var add := UIWindow.button("New")
	add.tooltip_text = "A new tracker from the picked template, or a whole spec set."
	add.pressed.connect(func():
		if templates.selected >= n_templates:
			_add_spec_set(Trackers.spec_sets()[templates.selected - n_templates])
			return
		var t: Dictionary = (Trackers.templates()[templates.selected][2] as Callable).call()
		var cur: Dictionary = _all().get(_sel, {})
		if str(cur.get("kind")) == "group":
			t["group"] = _sel
		elif not cur.is_empty():
			t["group"] = cur.get("group", "")
		_all()[t["id"]] = t
		_sel = t["id"]
		_changed(true)
		select(t["id"]))
	new_row.add_child(add)
	var row2 := HBoxContainer.new()
	left.add_child(row2)
	for spec in [["Group", "A new group: its trackers stack one after another."], ["Copy", "Duplicate the picked one."],
			["Delete", "Delete the picked one (a group's trackers stay, ungrouped)."]]:
		var b := UIWindow.button(spec[0])
		b.tooltip_text = spec[1]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(b)
		b.pressed.connect({"Group": _new_group, "Copy": _duplicate, "Delete": _delete}[spec[0]])
	var order_row := HBoxContainer.new()
	left.add_child(order_row)
	for dir in [-1, 1]:
		var b := UIWindow.button("Up" if dir < 0 else "Down")
		b.tooltip_text = "Move the picked one %s the list (its place in a group sorted \"As listed\")." % ("up" if dir < 0 else "down")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _move(dir))
		order_row.add_child(b)
	var row3 := HBoxContainer.new()
	left.add_child(row3)
	var imp := UIWindow.button("Import")
	imp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	imp.pressed.connect(func(): _text_popup("Import trackers", "", true))
	row3.add_child(imp)
	var export_b := UIWindow.button("Export")
	export_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_b.tooltip_text = "The picked tracker, or a group with its trackers, as one line to share."
	export_b.pressed.connect(func():
		if _sel != "":
			_text_popup("Export", Trackers.export_items(_export_set(_sel)), false))
	row3.add_child(export_b)
	# Place them on screen: Move UI, where every tracker has a box to drag (right-click it:
	# exact spot, and Options brings you back here).
	var move := UIWindow.button("Move on screen")
	move.tooltip_text = "Close this and drag your trackers where you want them (Move UI). In the game only, out of combat."
	move.pressed.connect(func():
		var s := _settings()
		if s:
			s.move_ui_requested.emit()
		win.queue_free())
	left.add_child(move)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(scroll)
	_right = VBoxContainer.new()
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.add_theme_constant_override("separation", 6)
	scroll.add_child(_right)
	_fill_list()
	if not _all().is_empty():
		select(str(_all().keys()[0]))
	else:
		_empty_page()

func _fill_list() -> void:
	_list.clear()
	var root := _list.create_item()
	var groups := {}
	var all := _all()
	for id in all:
		if str(all[id].get("kind")) == "group":
			var it := _list.create_item(root)
			it.set_text(0, "▸ " + str(all[id]["name"]))
			it.set_custom_color(0, UISkin.accent())
			it.set_metadata(0, id)
			groups[id] = it
			if id == _sel:
				it.select(0)
	for id in all:
		var t: Dictionary = all[id]
		if str(t.get("kind")) == "group":
			continue
		var it := _list.create_item(groups.get(str(t.get("group", "")), root))
		it.set_text(0, str(t["name"]) + ("" if bool(t.get("enabled", true)) else "  (off)"))
		it.set_metadata(0, id)
		if id == _sel:
			it.select(0)

func _export_set(id: String) -> Array:
	var all := _all()
	var out: Array = [all[id]]
	if str(all[id].get("kind")) == "group":
		for k in all:
			if str(all[k].get("group", "")) == id:
				out.append(all[k])
	return out

func _new_group() -> void:
	var g := Trackers.make_group("New group")
	_all()[g["id"]] = g
	_sel = g["id"]
	_changed(true)
	select(g["id"])

## Duplicate the picked tracker, or a group with its trackers.
func _duplicate() -> void:
	if not _all().has(_sel):
		return
	var items := Trackers.fresh_copy(_export_set(_sel))
	if items.is_empty():
		return
	items[0]["name"] = str(items[0]["name"]) + " copy"
	if str(items[0]["kind"]) == "tracker":
		items[0]["group"] = str(_all()[_sel].get("group", ""))
	for it in items:
		if _all().size() < Trackers.MAX_TRACKERS:
			_all()[it["id"]] = it
	_sel = items[0]["id"]
	_changed(true)
	select(_sel)

## Add a spec set again (its own ids while they're free, so it goes to its spot).
func _add_spec_set(sp: Array) -> void:
	var items: Array = (sp[3] as Array).duplicate(true)
	if items.any(func(it): return _all().has(it["id"])):
		items = Trackers.fresh_copy(items)
	for it in items:
		if _all().size() < Trackers.MAX_TRACKERS:
			_all()[it["id"]] = it
	_sel = items[0]["id"]
	_changed(true)
	select(_sel)

## Move the picked one past its neighbour (same group, or both ungrouped).
func _move(dir: int) -> void:
	var all := _all()
	if not all.has(_sel):
		return
	var keys := all.keys()
	var kind := str(all[_sel].get("kind"))
	var grp := str(all[_sel].get("group", ""))
	var same := func(k): return str(all[k].get("kind")) == kind and (kind == "group" or str(all[k].get("group", "")) == grp)
	var i := keys.find(_sel)
	var j := i + dir
	while j >= 0 and j < keys.size() and not same.call(keys[j]):
		j += dir
	if j < 0 or j >= keys.size():
		return
	keys[i] = keys[j]
	keys[j] = _sel
	var ordered := {}
	for k in keys:
		ordered[k] = all[k]
	all.clear()
	all.merge(ordered)
	_changed(true)

func _delete() -> void:
	var all := _all()
	if not all.has(_sel):
		return
	if str(all[_sel].get("kind")) == "group":
		for k in all:
			if str(all[k].get("group", "")) == _sel:
				all[k]["group"] = ""
	all.erase(_sel)
	if _settings():
		Trackers.forget_builtin(_settings(), _sel)   # a spec set's one stays deleted
	_sel = ""
	_changed(true)
	if all.is_empty():
		_empty_page()
	else:
		select(str(all.keys()[0]))

func _empty_page() -> void:
	_clear_right()
	_right.add_child(_wrap("No trackers yet. Pick a template on the left and press New.\n\nA tracker shows something you care about: a buff's time left as a bar, an ability's cooldown as an icon, a warning when a buff is missing, Venom or mana as a bar, a flash of text when something happens. Tooltips show the IDs of abilities, items and effects to build them from.", UISkin.DIM))

func _clear_right() -> void:
	for c in _right.get_children():
		c.queue_free()

func _wrap(text: String, col := UISkin.TEXT) -> Label:
	var l := UISkin.label(text, 13, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(600, 0)
	return l

## Show the pages of tracker / group `id`.
func select(id: String) -> void:
	if not _all().has(id):
		return
	_sel = id
	var engine := TrackerEngine.of(get_tree())
	if engine:
		engine.set_preview(id, true)
	_clear_right()
	var t: Dictionary = _all()[id]
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	_right.add_child(head)
	var name_e := LineEdit.new()
	name_e.text = str(t["name"])
	name_e.custom_minimum_size = Vector2(260, 0)
	name_e.text_submitted.connect(func(v: String):
		t["name"] = v.left(60)
		_changed(true))
	name_e.focus_exited.connect(func():
		if name_e.text != str(t["name"]):
			t["name"] = name_e.text.left(60)
			_changed(true))
	head.add_child(name_e)
	head.add_child(_check("Enabled", bool(t.get("enabled", true)), func(on):
		t["enabled"] = on
		_changed(true)))
	if str(t.get("kind")) == "group":
		_group_page(t)
		return
	head.add_child(UISkin.label("Group", 13, UISkin.DIM))
	var groups: Array = [""]
	var names: Array = ["None"]
	for k in _all():
		if str(_all()[k].get("kind")) == "group":
			groups.append(k)
			names.append(str(_all()[k]["name"]))
	head.add_child(_option(names, maxi(groups.find(str(t.get("group", ""))), 0), func(i):
		t["group"] = groups[i]
		_changed(true)))
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 430)
	_right.add_child(tabs)
	tabs.add_child(_display_page(t))
	tabs.add_child(_triggers_page(t))
	tabs.add_child(_conditions_page(t))
	tabs.add_child(_load_page(t))

# --- Pages --------------------------------------------------------------------------------

func _page(title: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = title
	v.add_theme_constant_override("separation", 6)
	return v

func _field(parent: Control, label: String, w: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := UISkin.label(label, 13)
	l.custom_minimum_size = Vector2(150, 0)
	row.add_child(l)
	row.add_child(w)
	parent.add_child(row)

func _group_page(g: Dictionary) -> void:
	var v := _page("Group")
	_right.add_child(v)
	_field(v, "Grow", _option(["Down", "Up", "Left", "Right"], ["down", "up", "left", "right"].find(str(g["grow"])), func(i):
		g["grow"] = ["down", "up", "left", "right"][i]
		_changed()))
	_field(v, "Align", _option(["Start", "Centre", "End"], ["start", "center", "end"].find(str(g.get("align", "start"))), func(i):
		g["align"] = ["start", "center", "end"][i]
		_changed()))
	_field(v, "Spacing", _spin(0, 40, 1, float(g["spacing"]), func(x):
		g["spacing"] = int(x)
		_changed()))
	_field(v, "Sort", _option(["As listed", "Least time left first", "Name"], ["none", "time", "name"].find(str(g["sort"])), func(i):
		g["sort"] = ["none", "time", "name"][i]
		_changed()))
	v.add_child(_wrap("Only the trackers that are showing take a place, one after another. Move the group with Move UI (it's called \"%s\")." % g["name"], UISkin.DIM))

func _display_page(t: Dictionary) -> Control:
	var v := _page("Display")
	var d: Dictionary = t["display"]
	_field(v, "Type", _option(["Icon", "Bar", "Text", "Ring", "Pips"], Trackers.DISPLAY_TYPES.find(str(d["type"])), func(i):
		var fresh := Trackers.default_display(Trackers.DISPLAY_TYPES[i])
		for k in ["color", "text", "text2", "text_color", "text2_color", "icon", "glow", "sound", "show_missing", "click"]:
			fresh[k] = d[k]
		t["display"] = fresh
		_changed()
		select(t["id"])))
	_field(v, "Width", _spin(8, 800, 1, float(d["width"]), func(x):
		d["width"] = int(x)
		_changed()))
	_field(v, "Height", _spin(8, 400, 1, float(d["height"]), func(x):
		d["height"] = int(x)
		_changed()))
	var cp := ColorPickerButton.new()
	cp.color = d["color"]
	cp.custom_minimum_size = Vector2(60, 24)
	cp.popup_closed.connect(func():
		d["color"] = cp.color
		_changed())
	_field(v, "Colour", cp)
	var spots: Array = {"icon": ["bottom right", "top"], "bar": ["left", "centre"], "text": ["centre", "right"],
		"ring": ["centre", "under"], "pips": ["over the pips", "right of them"]}[str(d["type"])]
	for k in [["text", "Text (%s)" % spots[0], "e.g. %name  %stacks"], ["text2", "Text 2 (%s)" % spots[1], "e.g. %time"]]:
		var row := HBoxContainer.new()
		row.add_child(_line(str(d[k[0]]), k[2], func(s):
			d[k[0]] = s.left(80)
			_changed()))
		if str(d["type"]) != "text" or k[0] == "text2":
			row.add_child(_color_button(d[k[0] + "_color"], func(c):
				d[k[0] + "_color"] = c
				_changed()))
		_field(v, k[1], row)
	v.add_child(_wrap("Texts: %name %stacks %time %value %max %percent %target. Another trigger's: %2.value, %3.time... Pips: one per point up to the max.", UISkin.DIM))
	var icon_row := HBoxContainer.new()
	var icon_e := _line(str(d["icon"]), "auto, none, or an ID", func(s):
		d["icon"] = s.strip_edges()
		_changed())
	icon_row.add_child(icon_e)
	var pick := UIWindow.button("Pick")
	pick.pressed.connect(func(): _pick_id(func(id):
		icon_e.text = id
		d["icon"] = id
		_changed()))
	icon_row.add_child(pick)
	_field(v, "Icon", icon_row)
	_field(v, "Time left", _check("", bool(d.get("time_text", true)), func(on):
		d["time_text"] = on
		_changed()))
	_field(v, "Glow", _check("", bool(d["glow"]), func(on):
		d["glow"] = on
		_changed()))
	_field(v, "Sound when it shows", _check("", bool(d["sound"]), func(on):
		d["sound"] = on
		_changed()))
	_field(v, "Show while missing", _check("", bool(d.get("show_missing", false)), func(on):
		d["show_missing"] = on
		_changed()))
	v.add_child(_wrap("Show while missing: it stays (dim) while its triggers are off, e.g. an empty cell; only while it's loaded.", UISkin.DIM))
	# On click: a spec action (Player.tracker_actions(), e.g. turning the Wheel).
	var acts: Array = [""]
	var act_names: Array = ["Nothing"]
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("tracker_actions"):
		var known: Dictionary = player.tracker_actions()
		for k in known:
			acts.append(k)
			act_names.append(str(known[k]))
	if not acts.has(str(d.get("click", ""))):
		acts.append(str(d["click"]))
		act_names.append(str(d["click"]))
	_field(v, "On click", _option(act_names, acts.find(str(d.get("click", ""))), func(i):
		d["click"] = acts[i]
		_changed()))
	return v

func _triggers_page(t: Dictionary) -> Control:
	var v := _page("Triggers")
	_field(v, "Show when", _option(["Any trigger is on", "All triggers are on"], ["any", "all"].find(str(t["combine"])), func(i):
		t["combine"] = ["any", "all"][i]
		_changed()))
	var trs: Array = t["triggers"]
	for i in trs.size():
		v.add_child(_trigger_box(t, trs, i))
	var add_row := HBoxContainer.new()
	var kind := _option(Trackers.TRIGGER_NAMES, 0, func(_i): pass)
	add_row.add_child(kind)
	var add := UIWindow.button("Add trigger")
	add.pressed.connect(func():
		if trs.size() < 5:
			trs.append(Trackers.default_trigger(Trackers.TRIGGER_TYPES[kind.selected]))
			_changed()
			select(t["id"]))
	add_row.add_child(add)
	v.add_child(add_row)
	return v

func _trigger_box(t: Dictionary, trs: Array, i: int) -> Control:
	var tr: Dictionary = trs[i]
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UISkin.backdrop(0.5, 6))
	var v := VBoxContainer.new()
	box.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := UISkin.label("%d. %s" % [i + 1, Trackers.TRIGGER_NAMES[Trackers.TRIGGER_TYPES.find(str(tr["type"]))]], 13, UISkin.accent())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var del := UIWindow.button("Remove")
	del.pressed.connect(func():
		trs.remove_at(i)
		_changed()
		select(t["id"]))
	head.add_child(del)
	var set_and_save := func(k: String, val: Variant):
		tr[k] = val
		_changed()
	match str(tr["type"]):
		"effect":
			_field(v, "On", _option(["You", "Your target", "Anyone in the party"], Trackers.UNITS.find(str(tr["unit"])), func(x): set_and_save.call("unit", Trackers.UNITS[x])))
			_field(v, "Effect ID", _id_row(str(tr["id"]), func(id): set_and_save.call("id", id)))
			_field(v, "Stacks", _op_value(str(tr["op"]), float(tr["stacks"]), func(op): set_and_save.call("op", op), func(x): set_and_save.call("stacks", x)))
			_field(v, "Show while it's missing", _check("", bool(tr["missing"]), func(on): set_and_save.call("missing", on)))
			_field(v, "Only mine (on a target)", _check("", bool(tr["own"]), func(on): set_and_save.call("own", on)))
		"cooldown":
			_field(v, "Ability ID", _id_row(str(tr["id"]), func(id): set_and_save.call("id", id)))
			_field(v, "Show", _option(["When ready", "While on cooldown", "Always"], ["ready", "cooldown", "always"].find(str(tr["show"])), func(x): set_and_save.call("show", ["ready", "cooldown", "always"][x])))
		"resource":
			var names: Array = Trackers.RESOURCES.duplicate()
			var player := get_tree().get_first_node_in_group("player")
			if player and player.has_method("tracker_values"):
				for k in player.tracker_values():
					if not names.has(k):
						names.append(k)
			if not names.has(str(tr["res"])):
				names.append(str(tr["res"]))
			_field(v, "Value", _option(names.map(func(n): return str(n).capitalize()), names.find(str(tr["res"])), func(x): set_and_save.call("res", names[x])))
			_field(v, "Show when", _op_value(str(tr["op"]), float(tr["value"]), func(op): set_and_save.call("op", op), func(x): set_and_save.call("value", x)))
			_field(v, "As a percent", _check("", bool(tr["percent"]), func(on): set_and_save.call("percent", on)))
		"event":
			_field(v, "Event", _option(Trackers.EVENT_NAMES, Trackers.EVENTS.find(str(tr["event"])), func(x): set_and_save.call("event", Trackers.EVENTS[x])))
			_field(v, "Only this ID", _id_row(str(tr["id"]), func(id): set_and_save.call("id", id)))
			_field(v, "Show for (s)", _spin(0.2, 60, 0.1, float(tr["duration"]), func(x): set_and_save.call("duration", x)))
		"item":
			_field(v, "Item ID", _id_row(str(tr["id"]), func(id): set_and_save.call("id", id)))
		"state":
			_field(v, "State", _option(Trackers.STATE_NAMES, Trackers.STATES.find(str(tr["state"])), func(x): set_and_save.call("state", Trackers.STATES[x])))
	return box

func _conditions_page(t: Dictionary) -> Control:
	var v := _page("Conditions")
	v.add_child(_wrap("When a value passes a mark, change how the tracker looks.", UISkin.DIM))
	var conds: Array = t["conditions"]
	for i in conds.size():
		var c: Dictionary = conds[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(UISkin.label("If", 13))
		var srcs := ["Shown"]
		for n in (t["triggers"] as Array).size():
			srcs.append("Trigger %d" % (n + 1))
		row.add_child(_option(srcs, int(c.get("trigger", 0)), func(x): _setk(c, "trigger", x)))
		row.add_child(_option(["Stacks", "Time left", "Value", "Percent", "Is on (1 / 0)"], Trackers.CHECKS.find(str(c["check"])), func(x):
			c["check"] = Trackers.CHECKS[x]
			_changed()))
		row.add_child(_op_value(str(c["op"]), float(c["value"]), func(op): _setk(c, "op", op), func(x): _setk(c, "value", x)))
		row.add_child(UISkin.label("set", 13))
		row.add_child(_option(["Colour", "Glow", "Opacity", "Text", "Text 2", "Text colour", "Text 2 colour"], Trackers.SETS.find(str(c["set"])), func(x):
			c["set"] = Trackers.SETS[x]
			c["to"] = [Color(1, 0.3, 0.25), true, 0.5, "%name", "%name", Color(1, 0.3, 0.25), Color(1, 0.3, 0.25)][x]
			_changed()
			select(t["id"])))
		match str(c["set"]):
			"color", "text_color", "text2_color":
				row.add_child(_color_button(c["to"] if c["to"] is Color else Color.RED, func(col):
					c["to"] = col
					_changed()))
			"glow":
				row.add_child(_check("", bool(c["to"]) if c["to"] is bool else true, func(on):
					c["to"] = on
					_changed()))
			"alpha":
				row.add_child(_spin(0.0, 1.0, 0.05, float(c["to"]) if (c["to"] is float or c["to"] is int) else 0.5, func(x):
					c["to"] = x
					_changed()))
			"text", "text2":
				row.add_child(_line(str(c["to"]), "%name", func(s):
					c["to"] = s.left(60)
					_changed()))
		var del := UIWindow.button("X", Vector2(26, 24))
		del.pressed.connect(func():
			conds.remove_at(i)
			_changed()
			select(t["id"]))
		row.add_child(del)
		v.add_child(row)
	var add := UIWindow.button("Add condition")
	add.pressed.connect(func():
		if conds.size() < 5:
			conds.append({"check": "time", "op": "<=", "value": 3.0, "set": "color", "to": Color(1, 0.3, 0.25)})
			_changed()
			select(t["id"]))
	v.add_child(add)
	return v

func _load_page(t: Dictionary) -> Control:
	var v := _page("Load")
	var l: Dictionary = t["load"]
	v.add_child(_wrap("A tracker only runs (and shows) when all of these match.", UISkin.DIM))
	var specs: Array = [""]
	for cat in AbilitiesScript.SPECS:
		for sp in AbilitiesScript.SPECS[cat]:
			specs.append(str(sp[0]))
	var names := specs.map(func(s): return "Any" if s == "" else s)
	_field(v, "Spec", _option(names, maxi(specs.find(str(l["spec"])), 0), func(i):
		l["spec"] = specs[i]
		_changed()))
	var roles := ["", "tank", "healer", "dps"]
	_field(v, "Role", _option(["Any", "Tank", "Healer", "Damage"], roles.find(str(l["role"])), func(i):
		l["role"] = roles[i]
		_changed()))
	_field(v, "Combat", _option(["Any time", "In combat", "Out of combat"], ["any", "in", "out"].find(str(l["combat"])), func(i):
		l["combat"] = ["any", "in", "out"][i]
		_changed()))
	_field(v, "Party", _option(["Any", "In a party", "Alone"], ["any", "yes", "no"].find(str(l["party"])), func(i):
		l["party"] = ["any", "yes", "no"][i]
		_changed()))
	_field(v, "Dungeon", _option(["Anywhere", "In a dungeon"], ["any", "yes"].find(str(l["dungeon"])), func(i):
		l["dungeon"] = ["any", "yes"][i]
		_changed()))
	var bars_row := HBoxContainer.new()
	var bars_e := _line(str(l.get("bars", "")), "ability IDs, comma-separated", func(s):
		l["bars"] = s.strip_edges().left(200)
		_changed())
	bars_row.add_child(bars_e)
	var pick := UIWindow.button("Add")
	pick.tooltip_text = "Add an ability's ID."
	pick.pressed.connect(func(): _pick_id(func(id):
		var ids := Trackers.bar_ids(str(l.get("bars", "")))
		if not ids.has(id):
			ids.append(id)
		l["bars"] = ", ".join(PackedStringArray(ids)).left(200)
		bars_e.text = l["bars"]
		_changed()))
	bars_row.add_child(pick)
	bars_row.add_child(_option(["All of them", "Any of them"], ["all", "any"].find(str(l.get("bars_mode", "all"))), func(i):
		l["bars_mode"] = ["all", "any"][i]
		_changed()))
	_field(v, "On my bars", bars_row)
	v.add_child(_wrap("On my bars: only while these abilities are on your action bars (macros count). Empty: always.", UISkin.DIM))
	return v

## Set one field and save.
func _setk(d: Dictionary, k: String, v: Variant) -> void:
	d[k] = v
	_changed()

# --- Widgets -------------------------------------------------------------------------------

func _option(names: Array, selected: int, on_pick: Callable) -> OptionButton:
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_NONE
	for n in names:
		ob.add_item(str(n))
	ob.selected = clampi(selected, 0, maxi(names.size() - 1, 0))
	ob.item_selected.connect(func(i: int): on_pick.call(i))
	return ob

func _color_button(col: Color, on_pick: Callable) -> ColorPickerButton:
	var cp := ColorPickerButton.new()
	cp.color = col
	cp.custom_minimum_size = Vector2(50, 24)
	cp.popup_closed.connect(func(): on_pick.call(cp.color))
	return cp

func _check(text: String, on: bool, on_toggle: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.focus_mode = Control.FOCUS_NONE
	c.button_pressed = on
	c.toggled.connect(func(v: bool): on_toggle.call(v))
	return c

func _spin(mn: float, mx: float, step: float, value: float, on_change: Callable) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(90, 0)
	s.value_changed.connect(func(x: float): on_change.call(x))
	return s

func _line(text: String, hint: String, on_set: Callable) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.placeholder_text = hint
	e.custom_minimum_size = Vector2(240, 0)
	e.text_submitted.connect(func(s: String): on_set.call(s))
	e.focus_exited.connect(func(): on_set.call(e.text))
	return e

func _op_value(op: String, value: float, on_op: Callable, on_value: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_child(_option(Trackers.OPS, Trackers.OPS.find(op), func(i): on_op.call(Trackers.OPS[i])))
	row.add_child(_spin(-100000, 100000, 0.1, value, on_value))
	return row

func _id_row(id: String, on_set: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var e := _line(id, "an ID (Pick, or from a tooltip)", func(s): on_set.call(s.strip_edges()))
	row.add_child(e)
	var pick := UIWindow.button("Pick")
	pick.pressed.connect(func(): _pick_id(func(picked):
		e.text = picked
		on_set.call(picked)))
	row.add_child(pick)
	return row

## The ID picker: search abilities, items and effects by name or ID.
func _pick_id(on_pick: Callable) -> void:
	var w := UIWindow.make(get_tree(), "TrackerIdPicker", "Pick an ID", Vector2(520, 460))
	for c in w.body.get_children():
		c.queue_free()
	var all := Trackers.all_ids()
	var row := HBoxContainer.new()
	w.body.add_child(row)
	var search := LineEdit.new()
	search.placeholder_text = "Search by name or ID"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(search)
	var kinds := ["", "ability", "effect", "item"]
	var kind := _option(["All", "Abilities", "Effects", "Items"], 0, func(_i): pass)
	row.add_child(kind)
	var list := ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	w.body.add_child(list)
	var fill := func():
		list.clear()
		var q := search.text.strip_edges().to_lower()
		var k: String = kinds[kind.selected]
		for e in all:
			if list.item_count >= 300:
				break
			if k != "" and e[2] != k:
				continue
			if q != "" and not (str(e[0]).to_lower().contains(q) or str(e[1]).to_lower().contains(q)):
				continue
			list.add_item("%s   (%s: %s)" % [e[1], e[2], e[0]])
			list.set_item_metadata(list.item_count - 1, e[0])
	search.text_changed.connect(func(_t): fill.call())
	kind.item_selected.connect(func(_i): fill.call())
	list.item_activated.connect(func(i: int):
		on_pick.call(str(list.get_item_metadata(i)))
		w.queue_free())
	fill.call()
	search.grab_focus.call_deferred()

func _text_popup(title: String, text: String, importing: bool) -> void:
	var w := UIWindow.make(get_tree(), "TrackerText", title, Vector2(560, 260))
	for c in w.body.get_children():
		c.queue_free()
	var te := TextEdit.new()
	te.text = text
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.size_flags_vertical = Control.SIZE_EXPAND_FILL
	w.body.add_child(te)
	var row := HBoxContainer.new()
	w.body.add_child(row)
	var note := UISkin.label("", 12, UISkin.DIM)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(note)
	var b := UIWindow.button("Import" if importing else "Copy")
	b.pressed.connect(func():
		if not importing:
			DisplayServer.clipboard_set(te.text)
			note.text = "Copied."
			return
		var items := Trackers.parse_export(te.text)
		if items.is_empty():
			note.text = "That isn't an exported tracker."
			return
		for it in items:
			if _all().size() < Trackers.MAX_TRACKERS:
				_all()[it["id"]] = it
		_sel = items[0]["id"]
		_changed(true)
		select(_sel)
		w.queue_free())
	row.add_child(b)
