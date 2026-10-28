extends HudElement

# Your unit frame: name and health (+ shield, Bruise) in one bar, a thin bar per
# resource the abilities on your bars use (mana / energy / fury), and the Holy
# healer's Verses under them while a Sing ability is on a bar. A red edge while
# you are in combat.

const Categories = preload("res://scripts/categories.gd")
const RES_ORDER := ["mana", "energy", "fury"]
const SING_IDS := ["singmercy", "singchorus", "singvigil"]

var _health: HudBar
var _powers := {}           # res -> HudBar
var _verses: VersePips
var _glow: Panel
var _book_color := UISkin.HEALTH

func _init() -> void:
	super()
	key = "player_frame"
	title = "Player"

func build() -> void:
	add_backdrop()
	_health = HudBar.new()
	add_child(_health)
	_glow = Panel.new()
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(0.9, 0.2, 0.15, 0.9)
	sb.set_border_width_all(1)
	_glow.add_theme_stylebox_override("panel", sb)
	_glow.visible = false
	add_child(_glow)
	var bus := get_node_or_null("/root/SignalBus")
	if bus:
		bus.combat_state_changed.connect(func(on: bool): _glow.visible = on and bool(cfg("combat_glow")))
	refresh()

## The resources and Verses the abilities on the bars need (on every bar change).
func refresh() -> void:
	var ids := bar_ability_ids()
	var needed: Array[String] = []
	var books := {}
	for id in ids:
		var r := Abilities.resource_of(id)
		if r != "" and not needed.has(r):
			needed.append(r)
		var cat := Abilities.category_of(id)
		if cat != "":
			books[cat] = int(books.get(cat, 0)) + 1
	# Health in the colour of the book most of your abilities come from.
	var best := ""
	for cat in books:
		if best == "" or int(books[cat]) > int(books[best]):
			best = cat
	_book_color = Categories.color(best) if best != "" else UISkin.HEALTH
	for res in _powers.keys():
		if not needed.has(res):
			_powers[res].queue_free()
			_powers.erase(res)
	for res in RES_ORDER:
		if needed.has(res) and not _powers.has(res):
			var b := HudBar.new()
			b.fill_color = UISkin.POWER[res]
			add_child(b)
			_powers[res] = b
	var sing := false
	for id in ids:
		sing = sing or SING_IDS.has(id)
	if sing and _verses == null:
		_verses = VersePips.new()
		add_child(_verses)
	elif not sing and _verses != null:
		_verses.queue_free()
		_verses = null
	layout()

func layout() -> void:
	if _health == null:
		return
	var w := float(cfg("width"))
	var h := float(cfg("health_height"))
	var p := float(cfg("power_height"))
	_health.position = Vector2(1, 1)
	_health.size = Vector2(w - 2, h)
	_health.font_size = UISkin.font(12 if h >= 20 else 10)
	var y := 1.0 + h
	for res in RES_ORDER:
		if _powers.has(res):
			var b: HudBar = _powers[res]
			b.visible = p > 0
			if p > 0:
				b.position = Vector2(1, y + 1)
				b.size = Vector2(w - 2, p)
				b.font_size = UISkin.font(9)
				y += p + 1
	if _verses:
		_verses.position = Vector2(1, y + 1)
		_verses.size = Vector2(w - 2, maxf(p, 8.0) + 4.0)
		y += _verses.size.y + 1
	set_box(Vector2(w, y + 1))
	for b in _powers.values():
		(b as HudBar).queue_redraw()
	_health.queue_redraw()

func update(_delta: float) -> void:
	if player == null:
		return
	var mhp := float(maxi(player.max_health, 1))
	var frac := clampf(player.health / mhp, 0.0, 1.0)
	var shield := 0
	var st: Node = player.get_node_or_null("Status")
	if st and st.has_method("total_absorb"):
		shield = st.total_absorb()
	var bruise := 0.0
	if player.get("brawler") != null:
		bruise = float(player.brawler.bruise()) / mhp   # Martial tank: the health it will still take
	_health.fill_color = UISkin.health_color(frac, _book_color)
	_health.set_fracs(frac, shield / mhp, bruise)
	var txt := UISkin.value_text(str(cfg("text")), player.health, mhp)
	if shield > 0:
		txt += "  +" + UISkin.short(shield)
	var nm := PartyFrames.display_name_of(player) if bool(cfg("show_name")) else ""
	_health.set_texts(nm, "", txt)
	for res in _powers:
		var b: HudBar = _powers[res]
		var pts: int = player.resource_points(res)
		var mx: int = int(player.resource_max(res))
		b.set_fracs(float(pts) / maxf(mx, 1))
		b.set_texts("", "%d / %d" % [pts, mx] if b.size.y >= 8 else "")
	if _verses and "verses" in player:
		_verses.show_verses(player.verses, str(player.hymn), str(player.HYMN_NAMES.get(player.hymn, "No Hymn")))

## The Holy healer's Verses: one pip per Verse in its Hymn's colour, the Hymn's name.
class VersePips extends Control:
	var _key := "?"
	var _verses: Array = []
	var _name := ""
	var _hymn := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func show_verses(verses: Array, hymn: String, hymn_name: String) -> void:
		var k := "%s|%s" % [hymn, ",".join(PackedStringArray(verses))]
		if k == _key:
			return
		_key = k
		_verses = verses.duplicate()
		_hymn = hymn
		_name = hymn_name
		queue_redraw()

	func _draw() -> void:
		var Abilities = load("res://scripts/abilities.gd")
		var n: int = load("res://scripts/balance.gd").VERSE_MAX
		var text_w := size.x * 0.4
		var cell := (size.x - text_w - (n - 1) * 2.0) / n
		for i in n:
			var c: Color = Abilities.HYMN_COLORS.get(str(_verses[i]), UISkin.BAR_BG) if i < _verses.size() else UISkin.BAR_BG
			draw_rect(Rect2(i * (cell + 2.0), 1, cell, size.y - 2), c)
		var f := get_theme_default_font()
		var fs := UISkin.font(10)
		var at := Vector2(size.x - text_w + 4, (size.y + fs * 0.72) / 2.0)
		var col: Color = Abilities.HYMN_COLORS.get(_hymn, UISkin.DIM)
		draw_string_outline(f, at, _name, HORIZONTAL_ALIGNMENT_LEFT, text_w - 4, fs, 3, Color.BLACK)
		draw_string(f, at, _name, HORIZONTAL_ALIGNMENT_LEFT, text_w - 4, fs, col)
