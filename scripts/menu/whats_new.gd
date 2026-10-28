extends "res://scripts/menu/menu_part.gd"
class_name WhatsNewPart

# "What's new" in the lobby: the newest patch notes in a panel that opens from a
# button at the top left. A dot on the button until you've opened these notes
# (Settings.last_seen_notes keeps a hash of them). Builds read res://data/whats_new.md,
# which the release workflow copies from the newest docs/PATCH_NOTES_*.md; in the
# editor the newest docs/PATCH_NOTES_*.md is read directly.

const BUNDLED := "res://data/whats_new.md"
const NOTES_DIR := "res://docs/"

var button: Button
var _dot: ColorRect
var _panel: PanelContainer
var _text: RichTextLabel
var _notes := ""

## The newest patch notes ("" = none found).
static func load_notes() -> String:
	if FileAccess.file_exists(BUNDLED):
		return FileAccess.get_file_as_string(BUNDLED)
	var newest := ""
	var dir := DirAccess.open(NOTES_DIR)
	if dir:
		for f in dir.get_files():
			# "..._2026-10-16" before "..._2026-10-16-2": compare without ".md".
			if f.begins_with("PATCH_NOTES_") and f.ends_with(".md") and f.get_basename() > newest.get_basename():
				newest = f
	return FileAccess.get_file_as_string(NOTES_DIR + newest) if newest != "" else ""

## Patch notes markdown -> RichTextLabel BBCode: headings, bullets, **bold**.
static func to_bbcode(md: String) -> String:
	var accent := MainMenu.C_ACCENT.to_html(false)
	var out: Array[String] = []
	for raw in md.split("\n"):
		var line := raw.strip_edges(false, true).replace("[", "[lb]")
		line = _bold(line)
		if line.begins_with("### "):
			line = "[b]%s[/b]" % line.substr(4)
		elif line.begins_with("## "):
			line = "\n[font_size=18][color=#%s]%s[/color][/font_size]" % [accent, line.substr(3)]
		elif line.begins_with("# "):
			line = "[font_size=21][color=#%s]%s[/color][/font_size]" % [accent, line.substr(2)]
		elif line.begins_with("- ") or line.begins_with("* "):
			line = "  •  " + line.substr(2)
		out.append(line)
	return "\n".join(out).strip_edges()

static func _bold(line: String) -> String:
	var parts := line.split("**")
	if parts.size() < 3:
		return line
	var s := ""
	for i in parts.size():
		s += parts[i]
		if i < parts.size() - 1:
			s += "[b]" if i % 2 == 0 else "[/b]"
	if parts.size() % 2 == 0:   # an odd "**" left open
		s += "[/b]"
	return s

func build() -> void:
	_notes = load_notes()
	button = UI.button("What's new", 14, Vector2(130, 32))
	button.position = Vector2(16, 52)
	button.tooltip_text = "The latest patch notes"
	button.visible = _notes != ""
	button.pressed.connect(toggle)
	menu.ui.add_child(button)
	_dot = ColorRect.new()
	_dot.color = Color(1.0, 0.45, 0.3)
	_dot.size = Vector2(8, 8)
	_dot.position = Vector2(118, 4)
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.visible = _notes != "" and str(menu.get_node("/root/Settings").last_seen_notes) != _hash()
	button.add_child(_dot)

func _hash() -> String:
	return str(_notes.hash())

func toggle() -> void:
	if _panel == null:
		_build_panel()
	_panel.visible = not _panel.visible
	if _panel.visible:
		_panel.move_to_front()
		_dot.visible = false
		var st := menu.get_node("/root/Settings")
		if str(st.last_seen_notes) != _hash():
			st.last_seen_notes = _hash()
			st.save()

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 16
	_panel.offset_right = 476
	_panel.offset_top = 90
	_panel.offset_bottom = -60
	_panel.add_theme_stylebox_override("panel", menu._padded(UI.box(Color(0.05, 0.055, 0.075, 0.97), MainMenu.C_BORDER, 2, 10), 14))
	# Its own layer, above the lobby chat (layer 5).
	var layer := CanvasLayer.new()
	layer.layer = 6
	menu.add_child(layer)
	layer.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := UI.label("What's new", 18, MainMenu.C_ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := UI.button("✕", 13, Vector2(28, 26))
	close.pressed.connect(toggle)
	head.add_child(close)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 14)
	_text.add_theme_font_size_override("bold_font_size", 14)
	_text.text = to_bbcode(_notes)
	v.add_child(_text)

## Shown only in the Lobby.
func show_for(page_name: String) -> void:
	if button:
		button.visible = page_name == "Lobby" and _notes != ""
	if _panel and page_name != "Lobby":
		_panel.visible = false
