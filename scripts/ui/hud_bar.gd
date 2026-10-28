extends Control
class_name HudBar

# One flat bar for the in-game UI (health, power, cast, XP, tracker bars): a
# dark track, the fill, an optional shield after it, an optional darker piece
# at the end of the fill (Bruise), a spark on the fill's edge, a faint top
# highlight and up to three texts. All drawn in _draw; setters redraw only on
# change, so updating every frame costs nothing while nothing moves.

var fill_color := Color(0.2, 0.72, 0.3):
	set(v):
		if v != fill_color:
			fill_color = v
			queue_redraw()
var bg_color := Color(0.11, 0.11, 0.12):
	set(v):
		if v != bg_color:
			bg_color = v
			queue_redraw()
var shield_color := Color(0.72, 0.9, 1.0, 0.85)
var extra_color := Color(0.32, 0.12, 0.38, 0.9)
var font_size := 12:
	set(v):
		if v != font_size:
			font_size = v
			queue_redraw()
var spark := false:
	set(v):
		if v != spark:
			spark = v
			queue_redraw()
## Fill from the right (a channel drains this way too: just lower `frac`).
var reverse := false
## 0..1 parts of the width.
var frac := 1.0
var shield_frac := 0.0
var extra_frac := 0.0
var text_left := ""
var text_center := ""
var text_right := ""
var text_color := Color(0.94, 0.94, 0.94)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Set the fill (and shield / extra) as parts of the width; redraws on change.
func set_fracs(f: float, shield := 0.0, extra := 0.0) -> void:
	f = clampf(f, 0.0, 1.0)
	shield = clampf(shield, 0.0, 1.0 - f)
	extra = clampf(extra, 0.0, f)
	if absf(f - frac) > 0.0005 or absf(shield - shield_frac) > 0.0005 or absf(extra - extra_frac) > 0.0005:
		frac = f
		shield_frac = shield
		extra_frac = extra
		queue_redraw()

func set_texts(left: String, center := "", right := "") -> void:
	if left != text_left or center != text_center or right != text_right:
		text_left = left
		text_center = center
		text_right = right
		queue_redraw()

func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), bg_color)
	var w := s.x * frac
	var x0 := s.x - w if reverse else 0.0
	if w > 0.0:
		draw_rect(Rect2(x0, 0, w, s.y), fill_color)
		draw_rect(Rect2(x0, 0, w, maxf(1.0, s.y * 0.35)), Color(1, 1, 1, 0.07))   # top highlight
	if extra_frac > 0.0:
		var ew := s.x * extra_frac
		draw_rect(Rect2(w - ew, 0, ew, s.y), extra_color)
	if shield_frac > 0.0:
		draw_rect(Rect2(w, 0, s.x * shield_frac, s.y), shield_color)
	if spark and frac > 0.0 and frac < 1.0:
		var sx := x0 if reverse else w
		draw_rect(Rect2(sx - 5.0, -1, 10.0, s.y + 2), Color(1, 1, 1, 0.18))
		draw_rect(Rect2(sx - 1.0, -1, 2.0, s.y + 2), Color(1, 1, 0.95, 0.95))
	var f := get_theme_default_font()
	var base := (s.y + font_size * 0.72) / 2.0
	if text_left != "":
		_text(f, Vector2(4, base), text_left, HORIZONTAL_ALIGNMENT_LEFT, s.x - 8)
	if text_center != "":
		_text(f, Vector2(0, base), text_center, HORIZONTAL_ALIGNMENT_CENTER, s.x)
	if text_right != "":
		_text(f, Vector2(4, base), text_right, HORIZONTAL_ALIGNMENT_RIGHT, s.x - 8)

func _text(f: Font, at: Vector2, t: String, align: HorizontalAlignment, width: float) -> void:
	draw_string_outline(f, at, t, align, width, font_size, 3, Color.BLACK)
	draw_string(f, at, t, align, width, font_size, text_color)
