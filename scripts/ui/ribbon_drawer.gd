extends RefCounted

# The ribbon layout's look (Talents.GROUPS): each spec is a bookmark ribbon hanging
# down the page, its talents wax seals whose places draw the spec's shape
# (Talents.SHAPES); the open talents are beads on a stitched thread down the spine.
# A ribbon unrolls to the deepest row its spec has points in; its capstone hangs at
# the tail with a gold ring that fills toward Balance.CAPSTONE_GATE. Links are threads
# from seal to seal. Used by the main menu's book (TalentTreePage) and the in-game
# Spellbook (talent_tree_view.gd); both keep their own buttons / cells for input and
# tooltips, and let these functions draw.
# Usage: const RibbonDrawer = preload("res://scripts/ui/ribbon_drawer.gd")

const Talents = preload("res://scripts/talents.gd")
const Categories = preload("res://scripts/categories.gd")
const Balance = preload("res://scripts/balance.gd")

const GOLD := Color(0.95, 0.75, 0.35)
const METAL := Color(0.72, 0.68, 0.6)
const METAL_DARK := Color(0.3, 0.27, 0.22)
const THREAD := Color(0.86, 0.8, 0.68)
## Height of the clasp and the points line above row 1, in px.
const HEAD_H := 34.0
## Room below row 10 for the ribbon's notched tail, in cells.
const TAIL := 0.35

## Spec group -> the stitch running down its ribbon's edges (one per spec in a book).
const EMBROIDERY := {
	"Hard Winter": "flake", "Cold Comfort": "cross", "Frostbitten Steel": "chevron", "Glacier Wall": "brick",
	"Winter Hunt": "arrowhead", "Steady Flame": "tongue", "Slagforged": "rivet", "Forge Heat": "zigzag",
	"Pitch and Cinder": "drop", "The Wheel": "ring", "Rogue": "x", "Brawler": "bar", "Sharpshooter": "dot",
	"Live Current": "cloud", "Stormdancer": "bolt", "Lightning Rod": "diamond", "Stormstring": "tick",
	"Clockwork": "cog", "Hall of Mirrors": "glint", "Second Act": "mask", "Aetherstring": "tick",
	"The Breach": "pit", "Pack of Two": "paw", "Strings Attached": "knot", "Nightstring": "tick",
	"Thornweaver": "thorn", "Shepherd": "petal", "Colossus": "leaf", "Venomstring": "fang",
	"Choir of One": "note", "Censer Bearer": "smoke", "Line of Light": "facet", "Lightstring": "ray",
}

## How many rows a group's ribbon reaches: one past the deepest row it has points in
## (at least the first row; all ROWS once its capstone has points).
static func depth(pd: Object, category: String, group: String) -> int:
	var deepest := 0
	for id in Talents.in_group(category, group):
		if pd != null and int(pd.talent_rank(id)) > 0:
			deepest = maxi(deepest, Talents.tier_of(id) + 1)
	return clampi(deepest + 1, 1, Talents.ROWS)

## Colour of a spec's ribbon: a darker shade of the book's colour, a little different per spec.
static func ribbon_color(category: String, index: int) -> Color:
	var col := Categories.color(category)
	return col.darkened(0.42 + 0.09 * (index % 3)).lerp(Color(0.12, 0.1, 0.09), 0.12 * (index % 2))

## The wax of a book's seals.
static func wax_color(category: String) -> Color:
	return Categories.color(category).lerp(Color.WHITE, 0.08)

## Centre of a talent's cell. `m`: {"x": left edge, "top": y of row 1, "cell": Vector2}.
static func center(m: Dictionary, id: String) -> Vector2:
	var cell: Vector2 = m["cell"]
	var cat := Talents.category_of(id)
	return Vector2(float(m["x"]) + (Talents.column_x(cat, Talents.col_of(id)) + 0.5) * cell.x,
		float(m["top"]) + (Talents.tier_of(id) + 0.5) * cell.y)

## Ribbons, spine, links and capstone rings of a book (under its seals). `unroll`:
## group -> rows its ribbon shows (a float while it grows; default `depth`).
static func draw_book(c: CanvasItem, category: String, m: Dictionary, pd: Object, unroll: Dictionary = {}) -> void:
	var cell: Vector2 = m["cell"]
	var top := float(m["top"])
	var seal := float(m["seal"])
	var font := ThemeDB.fallback_font
	var i := 0
	for g in Talents.groups_of(category):
		var gname := str(g[0])
		var x0 := float(m["x"]) + Talents.column_x(category, int(g[1])) * cell.x
		var x1 := float(m["x"]) + Talents.column_x(category, int(g[2])) * cell.x + cell.x
		if gname == Talents.OPEN_GROUP:
			_draw_spine(c, category, (x0 + x1) / 2.0, top, cell, pd, font)
			continue
		var reach := float(unroll.get(gname, depth(pd, category, gname)))
		_draw_ribbon(c, category, gname, i, x0 + cell.x * 0.06, x1 - cell.x * 0.06, top, cell, reach, pd, font)
		i += 1
	_draw_links(c, category, m, seal, pd)

static func _draw_ribbon(c: CanvasItem, category: String, gname: String, index: int, x0: float, x1: float, top: float,
		cell: Vector2, reach: float, pd: Object, font: Font) -> void:
	var col := ribbon_color(category, index)
	var w := x1 - x0
	var start := top - HEAD_H * 0.5
	var bottom := top + Talents.ROWS * cell.y
	var tail := bottom + cell.y * TAIL
	var notch := bottom + cell.y * TAIL * 0.2
	var full := PackedVector2Array([Vector2(x0, start), Vector2(x1, start), Vector2(x1, tail), Vector2((x0 + x1) / 2.0, notch),
		Vector2(x0, tail)])
	# Where it will reach: a faint stitched outline of the whole ribbon.
	var ghost := full.duplicate()
	ghost.append(ghost[0])
	for k in ghost.size() - 1:
		c.draw_dashed_line(ghost[k], ghost[k + 1], Color(col.lightened(0.35), 0.3), 1.0, 4.0)
	var end := top + reach * cell.y
	var unrolled := reach >= Talents.ROWS - 0.01
	if unrolled:
		c.draw_colored_polygon(full, col)
		end = tail
	else:
		c.draw_rect(Rect2(x0, start, w, end - start), col)
	# Stitched edges and the spec's own embroidery between the rows.
	var edge := Color(col.lightened(0.55), 0.6)
	var stitch_end := (bottom if unrolled else end) - 2.0
	for x in [x0 + 3.0, x1 - 3.0]:
		c.draw_dashed_line(Vector2(x, start + 3.0), Vector2(x, stitch_end), edge, 1.0, 3.0)
	var s := clampf(cell.x * 0.11, 2.5, 5.0)
	var kind := str(EMBROIDERY.get(gname, "dot"))
	for r in range(1, int(floor(minf(reach, Talents.ROWS)))):
		var y := top + r * cell.y
		for x in [x0 + s + 2.0, x1 - s - 2.0]:
			_glyph(c, kind, Vector2(x, y), s, edge)
	if not unrolled:
		# The rolled-up end: a fat lip across the ribbon.
		var lip := clampf(cell.y * 0.22, 5.0, 10.0)
		var box := StyleBoxFlat.new()
		box.bg_color = col.lightened(0.12)
		box.border_color = col.darkened(0.35)
		box.set_border_width_all(1)
		box.set_corner_radius_all(int(lip / 2.0))
		c.draw_style_box(box, Rect2(x0 - 2.0, end - lip / 2.0, w + 4.0, lip))
		c.draw_line(Vector2(x0, end), Vector2(x1, end), Color(col.lightened(0.4), 0.5), 1.0)
	# The clasp on top: the spec's name; under it, its points toward the capstone.
	var clasp := Rect2(x0 - 2.0, top - HEAD_H, w + 4.0, HEAD_H * 0.5)
	var cb := StyleBoxFlat.new()
	cb.bg_color = METAL
	cb.border_color = METAL_DARK
	cb.set_border_width_all(1)
	cb.set_corner_radius_all(3)
	c.draw_style_box(cb, clasp)
	_text_centered(c, font, gname, clasp.get_center() + Vector2(0, 0), clasp.size.x - 4.0, 12, METAL_DARK.darkened(0.3))
	var pts: int = pd.group_points(category, gname) if pd != null else 0
	# (An unfinished spec has no capstone yet: just its points.)
	var gated := not Talents.UNFINISHED_SPECS.has(gname)
	var line := str(pts) if pts >= Balance.CAPSTONE_GATE or not gated else "%d / %d" % [pts, Balance.CAPSTONE_GATE]
	_text_centered(c, font, line, Vector2((x0 + x1) / 2.0, top - HEAD_H * 0.25), w - 4.0, 11,
		Color(1, 1, 1, 0.9) if pts > 0 else Color(1, 1, 1, 0.55))
	# The capstone's ring: how far along the spec is toward its gate.
	for id in Talents.in_group(category, gname):
		if Talents.tier_of(id) == Talents.ROWS - 1:
			var at := Vector2((x0 + x1) / 2.0, top + (Talents.ROWS - 0.5) * cell.y)
			var rr := minf(cell.x, cell.y) * 0.5 + 1.0
			var f := clampf(float(pts) / Balance.CAPSTONE_GATE, 0.0, 1.0)
			c.draw_arc(at, rr, 0.0, TAU, 40, Color(GOLD, 0.18), 2.0, true)
			if f > 0.0:
				c.draw_arc(at, rr, -PI / 2.0, -PI / 2.0 + TAU * f, maxi(int(40 * f), 2), GOLD, 2.0, true)

## The open talents' thread down the book's spine (their seals are drawn as beads).
static func _draw_spine(c: CanvasItem, category: String, x: float, top: float, cell: Vector2, pd: Object, font: Font) -> void:
	var last := 0
	for id in Talents.in_group(category, Talents.OPEN_GROUP):
		last = maxi(last, Talents.tier_of(id))
	c.draw_dashed_line(Vector2(x, top - HEAD_H * 0.5), Vector2(x, top + (last + 0.5) * cell.y), Color(THREAD, 0.55), 1.5, 4.0)
	var pts: int = pd.group_points(category, Talents.OPEN_GROUP) if pd != null else 0
	var label := Talents.OPEN_GROUP if pts <= 0 else "%s %d" % [Talents.OPEN_GROUP, pts]
	_text_centered(c, font, label, Vector2(x, top - HEAD_H * 0.75), cell.x * (1.0 + Talents.GROUP_GAP * 1.6), 10, Color(THREAD, 0.8))

## Threads between linked seals: gold once the first is maxed.
static func _draw_links(c: CanvasItem, category: String, m: Dictionary, seal: float, pd: Object) -> void:
	for l in Talents.links_in_tree(category):
		var a := center(m, l[0])
		var b := center(m, l[1])
		var dir := (b - a).normalized()
		var from := a + dir * (seal * 0.5 + 6.0)   # past the first seal's rank tab
		var to := b - dir * (seal * 0.5 + 1.0)
		var maxed: bool = pd != null and int(pd.talent_rank(l[0])) >= Talents.max_rank(l[0])
		var col := GOLD if maxed else Color(THREAD, 0.65)
		c.draw_line(from, to, Color(0, 0, 0, 0.35), 4.0, true)
		c.draw_dashed_line(from, to, col, 2.0, 5.0)
		c.draw_circle(to, 2.5, col)

## One talent's seal, drawn on its button / cell `c` (a square Control; the seal fills it,
## its rank is draw_rank, on a layer above the icon). `state`: {"rank", "max", "open" (points can go in),
## "linked" (opened by a link only), "hover", "bead" (an open talent), "choice" (an
## unpicked choice slot)}.
static func draw_seal(c: Control, category: String, id: String, state: Dictionary) -> void:
	var s := c.size
	var mid := s / 2.0
	var r := minf(s.x, s.y) / 2.0
	var rank := int(state.get("rank", 0))
	var top_rank := int(state.get("max", 1))
	var can := bool(state.get("open", false))
	var hover := bool(state.get("hover", false))
	var wax := wax_color(category)
	if bool(state.get("bead", false)):
		var d := PackedVector2Array([mid + Vector2(0, -r), mid + Vector2(r, 0), mid + Vector2(0, r), mid + Vector2(-r, 0)])
		c.draw_colored_polygon(d, GOLD.darkened(0.15) if rank > 0 else Color(0.08, 0.07, 0.06, 0.9))
		d.append(d[0])
		c.draw_polyline(d, GOLD if rank >= top_rank else (THREAD if can or rank > 0 else Color(THREAD, 0.35)),
			2.0 if hover else 1.2, true)
	elif rank > 0:
		# Pressed wax: an uneven blob with the stamp's ring in it.
		var blob := PackedVector2Array()
		var wob := float(hash(id) % 1000)
		for k in 18:
			var a := TAU * k / 18.0
			blob.append(mid + Vector2(cos(a), sin(a)) * r * (0.97 + 0.05 * sin(a * 3.0 + wob)))
		c.draw_colored_polygon(blob, wax.darkened(0.15) if not hover else wax)
		blob.append(blob[0])
		c.draw_polyline(blob, GOLD if rank >= top_rank else wax.lightened(0.35), 2.0 if rank >= top_rank else 1.2, true)
		c.draw_arc(mid, r * 0.8, 0.0, TAU, 28, wax.darkened(0.45), 1.2, true)
	else:
		# An empty stamp outline: points can go here (bright) or not yet (faint).
		c.draw_circle(mid, r * 0.96, Color(0.05, 0.04, 0.03, 0.75 if can else 0.5))
		var rim := wax.lightened(0.3)
		if not can:
			rim = Color(rim, 0.35)
		elif bool(state.get("linked", false)):
			rim = GOLD.darkened(0.2)
		c.draw_arc(mid, r * 0.96, 0.0, TAU, 32, rim, 2.0 if hover else 1.2, true)
	if bool(state.get("choice", false)):
		c.draw_line(mid + Vector2(0, -r * 0.9), mid + Vector2(0, r * 0.9), Color(THREAD, 0.6), 1.2, true)

## A seal's rank: a bold "2/3" on a dark tab over its bottom edge (gold when
## maxed, white with points in it, dim while it can't take points). Drawn on its own
## Control above the seal's icon, the same size as the seal; `state` as draw_seal.
static func draw_rank(c: Control, state: Dictionary) -> void:
	var s := c.size
	var mid := s / 2.0
	var r := minf(s.x, s.y) / 2.0
	var rank := int(state.get("rank", 0))
	var top_rank := int(state.get("max", 1))
	var can := bool(state.get("open", false))
	var fsize := int(clampf(r * 0.62, 11.0, 16.0))
	var text := "%d/%d" % [rank, top_rank]
	var font := bold_font()
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	var tab := Rect2(Vector2(mid.x - ts.x / 2.0 - 4.0, s.y - fsize * 0.55), Vector2(ts.x + 8.0, fsize + 2.0))
	var ink := GOLD if rank >= top_rank else (Color.WHITE if rank > 0 or can else Color(0.62, 0.6, 0.58))
	c.draw_rect(tab, Color(0.03, 0.03, 0.04, 0.92))
	c.draw_rect(tab, Color(ink, 0.7), false, 1.0)
	var base := Vector2(mid.x - ts.x / 2.0, tab.position.y + (tab.size.y + font.get_ascent(fsize) - font.get_descent(fsize)) / 2.0)
	c.draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 3, Color.BLACK)
	c.draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, ink)

## Pulse colours: talents that would open the one you clicked (HELP), and talents
## holding up a point you tried to take back (BLOCK).
const HELP := Color(1.0, 0.93, 0.6)
const BLOCK := Color(1.0, 0.28, 0.22)

## A ring of light pulsing around `target` (a seal / talent button) three times.
static func pulse(target: Control, col: Color) -> void:
	var old := target.get_node_or_null("Pulse")
	if old:
		old.free()
	var p := Control.new()
	p.name = "Pulse"
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.draw.connect(func():
		var mid := p.size / 2.0
		var r := minf(p.size.x, p.size.y) / 2.0
		for k in 4:
			p.draw_arc(mid, r * (1.02 + 0.1 * k), 0.0, TAU, 40, Color(col, 0.9 - 0.22 * k), 3.0 - 0.5 * k, true))
	target.add_child(p)
	p.modulate.a = 0.0
	var t := p.create_tween()
	for i in 3:
		t.tween_property(p, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
		t.tween_property(p, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	t.tween_callback(p.queue_free)

static var _bold: Font
## The default font, emboldened (rank numbers).
static func bold_font() -> Font:
	if _bold == null:
		var f := FontVariation.new()
		f.base_font = ThemeDB.fallback_font
		f.variation_embolden = 0.9
		_bold = f
	return _bold

## A seal's state from PlayerData (the read-only Spellbook view; the book adds hover).
static func seal_state(pd: Object, id: String) -> Dictionary:
	var rank: int = pd.talent_rank(id) if pd != null else 0
	return {"rank": rank, "max": Talents.max_rank(id), "open": pd != null and bool(pd.talent_unlocked(id)),
		"bead": Talents.group_of(id) == Talents.OPEN_GROUP, "choice": Talents.is_choice_slot(id) and rank <= 0}

static func _text_centered(c: CanvasItem, font: Font, text: String, at: Vector2, max_w: float, size: int, col: Color) -> void:
	var fsize := size
	while fsize > 7 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > max_w:
		fsize -= 1
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	c.draw_string(font, Vector2(at.x - ts.x / 2.0, at.y + ts.y * 0.32), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)

## One stitch of a ribbon's embroidery, `s` from its middle to its edge.
static func _glyph(c: CanvasItem, kind: String, p: Vector2, s: float, col: Color) -> void:
	match kind:
		"flake":
			for k in 3:
				var v := Vector2(cos(k * PI / 3.0), sin(k * PI / 3.0)) * s
				c.draw_line(p - v, p + v, col, 1.0, true)
		"cross":
			c.draw_line(p - Vector2(s, 0), p + Vector2(s, 0), col, 1.2, true)
			c.draw_line(p - Vector2(0, s), p + Vector2(0, s), col, 1.2, true)
		"chevron":
			c.draw_polyline(PackedVector2Array([p + Vector2(-s, -s * 0.5), p + Vector2(0, s * 0.5), p + Vector2(s, -s * 0.5)]), col, 1.2, true)
		"brick":
			c.draw_rect(Rect2(p - Vector2(s, s * 0.5), Vector2(s * 2.0, s)), col, false, 1.0)
		"arrowhead":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, s), p + Vector2(-s * 0.7, -s * 0.6), p + Vector2(s * 0.7, -s * 0.6)]), col)
		"tongue":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.55, s * 0.4), p + Vector2(0, s),
				p + Vector2(-s * 0.55, s * 0.4)]), col)
		"rivet":
			c.draw_circle(p, s * 0.55, col)
			c.draw_arc(p, s, 0.0, TAU, 12, col, 1.0, true)
		"zigzag":
			c.draw_polyline(PackedVector2Array([p + Vector2(-s, 0), p + Vector2(-s * 0.5, -s * 0.6), p + Vector2(0, 0),
				p + Vector2(s * 0.5, s * 0.6), p + Vector2(s, 0)]), col, 1.0, true)
		"drop":
			c.draw_circle(p + Vector2(0, s * 0.25), s * 0.55, col)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.5, s * 0.1), p + Vector2(-s * 0.5, s * 0.1)]), col)
		"ring":
			c.draw_arc(p, s * 0.8, 0.0, TAU, 12, col, 1.2, true)
		"x":
			c.draw_line(p + Vector2(-s, -s), p + Vector2(s, s), col, 1.2, true)
			c.draw_line(p + Vector2(-s, s), p + Vector2(s, -s), col, 1.2, true)
		"bar":
			c.draw_line(p - Vector2(s, 0), p + Vector2(s, 0), col, 2.0, true)
		"cloud":
			c.draw_circle(p + Vector2(-s * 0.4, s * 0.1), s * 0.45, col)
			c.draw_circle(p + Vector2(s * 0.35, -s * 0.05), s * 0.55, col)
		"bolt":
			c.draw_polyline(PackedVector2Array([p + Vector2(s * 0.3, -s), p + Vector2(-s * 0.3, 0), p + Vector2(s * 0.3, 0),
				p + Vector2(-s * 0.3, s)]), col, 1.2, true)
		"diamond":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.6, 0), p + Vector2(0, s),
				p + Vector2(-s * 0.6, 0)]), col)
		"tick":
			c.draw_line(p - Vector2(0, s * 0.7), p + Vector2(0, s * 0.7), col, 1.2, true)
		"cog":
			c.draw_arc(p, s * 0.55, 0.0, TAU, 10, col, 1.2, true)
			for k in 4:
				var v := Vector2(cos(k * PI / 2.0), sin(k * PI / 2.0))
				c.draw_line(p + v * s * 0.55, p + v * s, col, 1.4, true)
		"glint":
			c.draw_line(p - Vector2(s, 0), p + Vector2(s, 0), col, 1.0, true)
			c.draw_line(p - Vector2(0, s), p + Vector2(0, s), col, 1.0, true)
			c.draw_circle(p, s * 0.25, col)
		"mask":
			c.draw_arc(p + Vector2(0, -s * 0.2), s * 0.75, 0.15, PI - 0.15, 8, col, 1.4, true)
			c.draw_circle(p + Vector2(-s * 0.35, -s * 0.2), s * 0.15, col)
			c.draw_circle(p + Vector2(s * 0.35, -s * 0.2), s * 0.15, col)
		"pit":
			c.draw_arc(p, s * 0.75, 0.0, PI, 8, col, 1.2, true)
			c.draw_line(p - Vector2(s * 0.75, 0), p + Vector2(s * 0.75, 0), col, 1.2, true)
		"paw":
			c.draw_circle(p + Vector2(0, s * 0.3), s * 0.4, col)
			for k in 3:
				c.draw_circle(p + Vector2((k - 1) * s * 0.55, -s * 0.45 + absf(k - 1) * s * 0.15), s * 0.18, col)
		"knot":
			c.draw_circle(p, s * 0.3, col)
			c.draw_line(p + Vector2(-s * 0.3, -s * 0.3), p + Vector2(-s * 0.8, -s), col, 1.0, true)
			c.draw_line(p + Vector2(s * 0.3, -s * 0.3), p + Vector2(s * 0.8, -s), col, 1.0, true)
		"thorn":
			c.draw_line(p + Vector2(-s * 0.8, s * 0.3), p + Vector2(s * 0.8, s * 0.3), col, 1.0, true)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.3, s * 0.3), p + Vector2(s * 0.3, s * 0.3), p + Vector2(0, -s * 0.7)]), col)
		"petal":
			for k in 4:
				var a := TAU * k / 4.0 + PI / 4.0
				c.draw_circle(p + Vector2(cos(a), sin(a)) * s * 0.4, s * 0.25, col)
		"leaf":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s * 0.8), p + Vector2(s * 0.45, 0), p + Vector2(0, s * 0.8), p + Vector2(-s * 0.45, 0)]), col)
		"fang":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.35, -s * 0.6), p + Vector2(s * 0.35, -s * 0.6), p + Vector2(0, s * 0.7)]), col)
		"note":
			c.draw_circle(p + Vector2(-s * 0.2, s * 0.4), s * 0.3, col)
			c.draw_line(p + Vector2(s * 0.1, s * 0.4), p + Vector2(s * 0.1, -s * 0.7), col, 1.0, true)
		"smoke":
			c.draw_arc(p + Vector2(0, s * 0.2), s * 0.45, PI, TAU, 8, col, 1.0, true)
			c.draw_arc(p + Vector2(s * 0.3, -s * 0.4), s * 0.3, 0.0, PI, 6, col, 1.0, true)
		"facet":
			c.draw_polyline(PackedVector2Array([p + Vector2(-s * 0.6, -s * 0.2), p + Vector2(0, -s * 0.7), p + Vector2(s * 0.6, -s * 0.2),
				p + Vector2(0, s * 0.7), p + Vector2(-s * 0.6, -s * 0.2)]), col, 1.0, true)
		"ray":
			c.draw_circle(p, s * 0.25, col)
			for k in 4:
				var a := TAU * k / 4.0
				c.draw_line(p + Vector2(cos(a), sin(a)) * s * 0.4, p + Vector2(cos(a), sin(a)) * s * 0.8, col, 1.0, true)
		_:
			c.draw_circle(p, s * 0.45, col)
