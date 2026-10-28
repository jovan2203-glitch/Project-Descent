extends HudElement

# Your unit frame: name and health (+ shield, Bruise) in one bar, a thin bar per
# resource the abilities on your bars use (mana / energy / fury). A red edge while
# you are in combat. (The Holy healer's Verses are a Tracker: Trackers.spec_sets().)

const Categories = preload("res://scripts/categories.gd")
const RES_ORDER := ["mana", "energy", "fury"]

var _health: HudBar
var _powers := {}           # res -> HudBar
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
