extends Node
class_name UIOptions

# UI Options: every option of the in-game UI (UIConfig.schema()), one page per
# element, applied as you change it. Left: the elements by group (General, Unit
# Frames, Action Bars, Auras, Cast Bars, Bars, Panels). Right: the
# page. Under them: the role layout, Move UI, Trackers, Reset all and Export /
# Import of the whole UI as one line of text.
# Opened from Settings > Interface, /ui in chat, Move UI's top bar, or a mover's
# right-click panel (straight onto its element's page).

const NODE := "UIOptions"
const GROUP_ORDER := ["", "Unit Frames", "Action Bars", "Auras", "Cast Bars", "Bars", "Panels"]

var win: UIWindow
var _tree: Tree
var _page: VBoxContainer
var _page_title: Label
var _elem := "general"
var _items := {}   # elem -> TreeItem

static func open(tree: SceneTree, elem := "") -> void:
	var w := UIWindow.make(tree, NODE, "UI Options", Vector2(820, 560))
	var o: UIOptions
	if w.is_new:
		o = UIOptions.new()
		o.name = "Options"
		o.win = w
		w.add_child(o)
		o._build()
	else:
		o = w.get_node("Options")
	o.show_page(elem if elem != "" and UIConfig.schema().has(elem) else o._elem)

func _build() -> void:
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 10)
	win.body.add_child(cols)
	_tree = Tree.new()
	_tree.custom_minimum_size = Vector2(200, 0)
	_tree.hide_root = true
	_tree.focus_mode = Control.FOCUS_NONE
	_tree.add_theme_stylebox_override("panel", UISkin.backdrop(0.6, 4))
	cols.add_child(_tree)
	var root := _tree.create_item()
	var groups := {}
	var schema := UIConfig.schema()
	for g in GROUP_ORDER:
		var parent := root
		if g != "":
			parent = _tree.create_item(root)
			parent.set_text(0, g)
			parent.set_selectable(0, false)
			parent.set_custom_color(0, UISkin.accent())
			groups[g] = parent
		for elem in schema:
			if str(schema[elem]["group"]) == g:
				var it := _tree.create_item(parent)
				it.set_text(0, str(schema[elem]["label"]))
				it.set_metadata(0, elem)
				_items[elem] = it
	_tree.item_selected.connect(func():
		var it := _tree.get_selected()
		if it and it.get_metadata(0) != null:
			show_page(str(it.get_metadata(0))))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	cols.add_child(right)
	var head := HBoxContainer.new()
	right.add_child(head)
	_page_title = UISkin.label("", 15, UISkin.TEXT)
	_page_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_page_title)
	var reset := UIWindow.button("Reset page")
	reset.tooltip_text = "Back to the role layout's values for this element."
	reset.pressed.connect(func():
		UIConfig.reset(_elem)
		show_page(_elem))
	head.add_child(reset)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_page = VBoxContainer.new()
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_theme_constant_override("separation", 6)
	scroll.add_child(_page)
	win.body.add_child(_footer())

func _footer() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(UISkin.label("Layout", 13, UISkin.DIM))
	var roles := OptionButton.new()
	roles.focus_mode = Control.FOCUS_NONE
	for r in UIConfig.ROLES:
		roles.add_item(UIConfig.ROLE_NAMES[r])
	roles.selected = UIConfig.ROLES.find(UIConfig.role())
	row.add_child(roles)
	var apply := UIWindow.button("Apply layout")
	apply.tooltip_text = "Every element to the picked layout's place and values (your own changes and moves are dropped)."
	apply.pressed.connect(func():
		UIConfig.apply_role(UIConfig.ROLES[roles.selected])
		show_page(_elem))
	row.add_child(apply)
	var move := UIWindow.button("Move UI")
	move.pressed.connect(func():
		var s := UIConfig.settings()
		if s:
			s.move_ui_requested.emit())
	row.add_child(move)
	var trk := UIWindow.button("Trackers")
	trk.pressed.connect(func(): TrackerEditor.open(get_tree()))
	row.add_child(trk)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var export_b := UIWindow.button("Export")
	export_b.tooltip_text = "Your whole UI (layout, positions, options) as one line to share."
	export_b.pressed.connect(func(): _text_popup("Export UI", UIConfig.export_profile(), false))
	row.add_child(export_b)
	var imp := UIWindow.button("Import")
	imp.pressed.connect(func(): _text_popup("Import UI", "", true))
	row.add_child(imp)
	var reset_all := UIWindow.button("Reset all")
	reset_all.tooltip_text = "Back to the current layout's places and values."
	reset_all.pressed.connect(func():
		UIConfig.apply_role(UIConfig.role())
		show_page(_elem))
	row.add_child(reset_all)
	return row

## Show an element's page: one row per option.
func show_page(elem: String) -> void:
	_elem = elem
	var e: Dictionary = UIConfig.schema()[elem]
	_page_title.text = str(e["label"])
	if _items.has(elem) and _tree.get_selected() != _items[elem]:
		_items[elem].select(0)
		_tree.scroll_to_item(_items[elem])
	for c in _page.get_children():
		c.queue_free()
	for o in e["options"]:
		_page.add_child(_row(elem, o))
	if elem == "general":
		_page.add_child(_scale_row())

func _row(elem: String, o: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := UISkin.label(str(o["label"]), 13)
	l.custom_minimum_size = Vector2(190, 0)
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	l.tooltip_text = str(o.get("tip", ""))
	row.add_child(l)
	var id := str(o["id"])
	var v: Variant = UIConfig.value(elem, id)
	match str(o["type"]):
		"bool":
			var c := CheckBox.new()
			c.focus_mode = Control.FOCUS_NONE
			c.button_pressed = bool(v)
			c.toggled.connect(func(on: bool): UIConfig.set_value(elem, id, on))
			row.add_child(c)
		"int", "float":
			var s := HSlider.new()
			s.focus_mode = Control.FOCUS_NONE
			s.min_value = float(o["min"])
			s.max_value = float(o["max"])
			s.step = float(o["step"])
			s.value = float(v)
			s.custom_minimum_size = Vector2(240, 22)
			s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(s)
			var val := UISkin.label(_num(o, v), 13, UISkin.DIM)
			row.add_child(val)
			s.value_changed.connect(func(x: float):
				val.text = _num(o, x)
				UIConfig.set_value(elem, id, int(x) if o["type"] == "int" else x, false))
			s.drag_ended.connect(func(_c):
				var st := UIConfig.settings()
				if st:
					st.save())
		"enum":
			var ob := OptionButton.new()
			ob.focus_mode = Control.FOCUS_NONE
			for n in o["names"]:
				ob.add_item(str(n))
			ob.selected = maxi((o["values"] as Array).find(str(v)), 0)
			ob.item_selected.connect(func(i: int): UIConfig.set_value(elem, id, o["values"][i]))
			row.add_child(ob)
		"color":
			var cp := ColorPickerButton.new()
			cp.focus_mode = Control.FOCUS_NONE
			cp.color = v if v is Color else Color.WHITE
			cp.custom_minimum_size = Vector2(60, 24)
			cp.color_changed.connect(func(c: Color): UIConfig.set_value(elem, id, c, false))
			cp.popup_closed.connect(func():
				var st := UIConfig.settings()
				if st:
					st.save())
			row.add_child(cp)
	return row

static func _num(o: Dictionary, v: Variant) -> String:
	if o["type"] == "int":
		return str(int(v))
	if float(o["max"]) <= 2.0:
		return "%d%%" % int(round(float(v) * 100.0))
	return "%.2f" % float(v)

## General: the interface size and HUD opacity (the same as Settings > Interface).
func _scale_row() -> Control:
	var box := VBoxContainer.new()
	var s := UIConfig.settings()
	if s == null:
		return box
	for spec in [["Interface size", "ui_scale", s.UI_SCALE_MIN, s.UI_SCALE_MAX], ["HUD opacity", "ui_opacity", s.UI_OPACITY_MIN, 1.0]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var l := UISkin.label(spec[0], 13)
		l.custom_minimum_size = Vector2(190, 0)
		row.add_child(l)
		var sl := HSlider.new()
		sl.focus_mode = Control.FOCUS_NONE
		sl.min_value = spec[2]
		sl.max_value = spec[3]
		sl.step = 0.05
		sl.value = float(s.get(spec[1]))
		sl.custom_minimum_size = Vector2(240, 22)
		row.add_child(sl)
		var val := UISkin.label("%d%%" % int(round(sl.value * 100)), 13, UISkin.DIM)
		row.add_child(val)
		var prop: String = spec[1]
		sl.value_changed.connect(func(x: float): val.text = "%d%%" % int(round(x * 100)))
		sl.drag_ended.connect(func(_c):
			s.set(prop, sl.value)
			s.apply_interface()
			s.save())
		box.add_child(row)
	return box

## A window with one text box: Export (to copy) or Import (paste, then Import).
func _text_popup(title: String, text: String, importing: bool) -> void:
	var w := UIWindow.make(get_tree(), "UIOptionsText", title, Vector2(560, 260))
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
	if importing:
		var b := UIWindow.button("Import")
		b.pressed.connect(func():
			if UIConfig.import_profile(te.text):
				w.queue_free()
				show_page(_elem)
			else:
				note.text = "That isn't an exported UI.")
		row.add_child(b)
	else:
		var b := UIWindow.button("Copy")
		b.pressed.connect(func():
			DisplayServer.clipboard_set(te.text)
			note.text = "Copied.")
		row.add_child(b)
