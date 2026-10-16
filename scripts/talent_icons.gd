extends RefCounted

# Talent icons: one hand-drawn picture per designed talent (by its "key" in
# talents.gd), in the same style as the ability icons (book color on a dark
# square, drawn for a 52 px box and scaled). Empty / placeholder talents and
# talents without a picture here get no icon.
# Usage: const TalentIcons = preload("res://scripts/talent_icons.gd")

const Talents = preload("res://scripts/talents.gd")
const Categories = preload("res://scripts/categories.gd")

const WHITE := Color(0.95, 0.97, 1.0)
const WOOD := Color(0.5, 0.33, 0.18)
## The inside of the hole of a Breach (the Shadow caster's).
const PIT := Color(0.05, 0.02, 0.09)

## Does this talent have an icon?
static func has_icon(id: String) -> bool:
	var t := Talents.get_talent(id)
	if t.is_empty() or bool(t.get("placeholder", true)):
		return false
	return ICONED.has(_key_of(id))

static func _key_of(id: String) -> String:
	for key in ICONED:
		if Talents.id_for_key(key) == id:
			return key
	return ""

## Every talent key with a picture below.
const ICONED := ["frost_haste", "frost_cold_draw", "frost_black_ice", "frost_clean_shatter", "frost_cold_harvest",
	"frost_thin_ice", "frost_marked_prey", "frost_absorb", "frost_shard_proc", "frost_bolt_cast",
	"frost_discipline", "frost_chilled_dmg", "frost_int_sp", "frost_honed_rime",
	"frost_hoarfrost", "frost_hoarfrost_burst", "frost_clean_break", "frost_piercing_cold",
	"frost_dot_duration", "frost_cold_snap", "frost_splinter", "frost_shardstorm", "frost_shield_armor",
	"frost_slow_threat", "frost_slow_dr", "frost_glacial_heart", "frost_deep_freeze",
	"frost_ice_floe", "frost_shatterpoint", "frost_instinct",
	"frost_pinning_frost", "frost_third_bite", "frost_thick_hide", "frost_hard_freeze",
	"fire_smoldering_focus", "fire_tempered_flame", "fire_afterburn",
	"fire_banked_coals", "fire_volley_targets", "fire_fuse_crit",
	"fire_pressure_valve", "fire_cool_under_fire", "fire_thick_slag", "fire_hot_iron", "fire_flashover", "fire_clinker",
	"fire_kindling", "fire_fresh_tinder", "fire_afterglow",
	"fire_forge_heat", "fire_long_burn", "fire_deep_crucible", "fire_stoked_kiln", "fire_slag_mending", "fire_furnace_heart",
	"fire_deep_brand", "fire_thick_pitch", "fire_banked_mana", "fire_warm_blood", "fire_white_heat",
	"fire_flash_point", "fire_forge_hardened", "fire_lingering_embers", "fire_controlled_burn",
	"lightning_quick_charge", "lightning_conductive", "lightning_deep_reserves", "lightning_running_on_empty",
	"lightning_honed_edge", "lightning_running_start", "lightning_third_beat", "lightning_redline",
	"lightning_long_reach", "lightning_counter_charge", "lightning_closed_circuit", "lightning_quick_wrists",
	"lightning_tempo", "lightning_quick_fuse", "lightning_tight_coil", "lightning_earth_return",
	"lightning_conductor", "lightning_high_voltage",
	"lightning_standing_charge", "lightning_whip_crack", "lightning_storm_cycle",
	"lightning_live_current", "lightning_charged_strikes", "lightning_storm_tempered", "lightning_quick_step",
	"lightning_calm_current", "lightning_overflow", "lightning_parting_spark", "lightning_hot_wire",
	"lightning_second_stroke", "lightning_snap_shot", "lightning_rod", "lightning_loaded_quiver",
	"arcane_seventh_sigil", "arcane_long_step", "arcane_frayed", "arcane_etched_darts", "arcane_chain_reaction",
	"arcane_polished_glass", "arcane_deep_well", "arcane_aftershock",
	"arcane_sharp_edges", "arcane_clockwork", "arcane_spare_copy", "arcane_second_self", "arcane_wide_rings",
	"arcane_on_the_beat", "arcane_head_count", "arcane_light_feet", "arcane_empty_room", "arcane_bent_light",
	"arcane_understudy", "arcane_loud_exit", "arcane_good_likeness",
	"arcane_standing_ovation", "arcane_long_memory", "arcane_clean_lines", "arcane_second_showing",
	"arcane_practiced_hand", "arcane_heavy_hand", "arcane_curtain_call", "arcane_no_loose_ends", "arcane_time_signature",
	"arcane_full_house", "arcane_dress_rehearsal", "arcane_silvered", "arcane_running_clock", "arcane_fine_edge",
	"arcane_quick_study", "arcane_two_minds", "arcane_echo", "arcane_mirror_finish", "arcane_overtime",
	"arcane_light_touch", "arcane_slipstream", "arcane_borrowed_time", "arcane_keep_moving", "arcane_full_crowd",
	"fire_feed_the_flames", "fire_last_ember", "fire_tempered",
	"lightning_change_of_pace", "lightning_spillover", "lightning_dig_in",
	"shadow_tainted_steel", "shadow_slow_death", "shadow_wasting", "shadow_finish_it", "shadow_spite",
	"shadow_carrion", "shadow_inevitable", "shadow_seep", "shadow_interest",
	"shadow_next_of_kin", "shadow_bitter_end", "shadow_no_floor", "shadow_small_change", "shadow_rot_through",
	"shadow_cut_short", "shadow_running_over", "shadow_bite_down",
	"shadow_thick_blood", "shadow_feeding_frenzy", "shadow_lean_and_hungry", "shadow_fed", "shadow_worked_up",
	"shadow_out_of_the_hole", "shadow_long_night", "shadow_take_it_with_you", "shadow_pack_leader",
	"shadow_still_wet", "shadow_share_the_kill", "shadow_pincer", "shadow_again", "shadow_stand_over",
	"shadow_slipped_leash",
	"shadow_first_stitch", "shadow_long_thread", "shadow_spare_spool", "shadow_full_harness", "shadow_taking_the_weight",
	"shadow_steady_hands", "shadow_heave", "shadow_long_drop", "shadow_snap_back", "shadow_give_and_take",
	"shadow_many_hands", "shadow_lean_on_me", "shadow_left_hanging",
	"shadow_deep_call", "shadow_ill_will", "shadow_hard_pull", "shadow_wide_pack",
	"holy_mercys_ear", "holy_many_voices", "holy_watchful", "holy_key_change", "holy_open_doors",
	"holy_grace", "holy_burnished", "holy_steadfast", "holy_long_note", "holy_overflowing", "holy_penitent", "holy_zeal",
	"holy_clear_mind", "holy_sheltering_light", "holy_long_glass", "holy_second_breath", "holy_heavy_chain", "holy_absolution",
	"holy_unbroken", "holy_glimmering", "holy_steady_aim", "holy_swelling_chorus", "holy_quick_lance", "holy_full_quiver",
	"holy_wide_break", "holy_watchful_eye", "holy_last_rites", "holy_bright_motes", "holy_steady_ray", "holy_censers_weight",
	"holy_sunsteel", "holy_radiance", "holy_mote_magnet", "holy_bright_barrier", "holy_lingering_light", "holy_wide_arc",
	"holy_deep_pour", "holy_high_censer", "holy_clear_glass", "holy_deep_crystal", "holy_sharp_facets", "holy_wide_burst",
	"holy_prismatic_burst", "holy_quick_realign", "holy_wide_fan", "holy_split_light", "holy_bright_quiver", "holy_deep_burn",
	"holy_swift_light", "holy_long_volley"]

static func draw(c: Control, id: String) -> void:
	if not has_icon(id):
		return
	var s := c.size
	var mid := s / 2.0
	var k: float = minf(s.x, s.y) / 52.0
	var col := Categories.color(Talents.category_of(id))
	var light := col.lightened(0.5)
	var pad := 4.0 * k
	c.draw_rect(Rect2(Vector2(pad, pad), s - Vector2(pad, pad) * 2.0), col.darkened(0.75), true)
	_draw_key(c, _key_of(id), mid, k, col, light)

# --- Shared bits -------------------------------------------------------------------

static func _p(mid: Vector2, k: float, raw: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in raw:
		out.append(mid + (v as Vector2) * k)
	return out

static func _flake(c: Control, at: Vector2, r: float, col: Color, w: float) -> void:
	for i in 3:
		var a := i * PI / 3.0
		var v := Vector2(cos(a), sin(a)) * r
		c.draw_line(at - v, at + v, col, w, true)

static func _drop(c: Control, at: Vector2, s: float, fill: Color, rim: Color, k: float) -> void:
	var pts := PackedVector2Array([at + Vector2(0, -14) * s])
	for i in 13:
		var a := -PI * 0.2 + PI * 1.4 * i / 12.0   # right shoulder, round bottom, left shoulder
		pts.append(at + Vector2(cos(a) * 9.0, 3.0 + sin(a) * 9.0) * s)
	c.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	c.draw_polyline(pts, rim, 1.8 * k, true)

static func _shield(c: Control, mid: Vector2, k: float, fill: Color, rim: Color) -> void:
	var sh := _p(mid, k, [Vector2(0, -15), Vector2(12, -10), Vector2(10, 5), Vector2(0, 15), Vector2(-10, 5), Vector2(-12, -10)])
	c.draw_colored_polygon(sh, fill)
	sh.append(sh[0])
	c.draw_polyline(sh, rim, 2.0 * k, true)

static func _shard(c: Control, tip: Vector2, dir: Vector2, length: float, width: float, fill: Color, rim: Color, k: float) -> void:
	var side := Vector2(-dir.y, dir.x) * width
	var back := tip - dir * length
	var pts := PackedVector2Array([tip, back + side, back - dir * length * 0.15, back - side])
	c.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	c.draw_polyline(pts, rim, 1.3 * k, true)

static func _clock(c: Control, at: Vector2, r: float, col: Color, k: float) -> void:
	c.draw_arc(at, r, 0, TAU, 28, col, 2.2 * k, true)
	for i in 4:
		var a := TAU * i / 4.0
		c.draw_line(at + Vector2(cos(a), sin(a)) * r * 0.75, at + Vector2(cos(a), sin(a)) * r * 0.95, col, 1.5 * k, true)

## A little standing figure (head, arms, body, legs) about 1.4 x `s` tall, centred on `at`.
static func _figure(c: Control, at: Vector2, s: float, col: Color, w: float) -> void:
	c.draw_arc(at + Vector2(0, -s * 0.62), s * 0.22, 0, TAU, 12, col, w, true)
	c.draw_line(at + Vector2(0, -s * 0.4), at + Vector2(0, s * 0.2), col, w, true)
	c.draw_line(at + Vector2(-s * 0.3, -s * 0.15), at + Vector2(s * 0.3, -s * 0.15), col, w, true)
	c.draw_line(at + Vector2(0, s * 0.2), at + Vector2(-s * 0.25, s * 0.75), col, w, true)
	c.draw_line(at + Vector2(0, s * 0.2), at + Vector2(s * 0.25, s * 0.75), col, w, true)

## A pane of glass (a tall diamond `half` wide and high from its middle): filled and rimmed.
static func _pane(c: Control, at: Vector2, half: Vector2, fill: Color, rim: Color, w: float) -> void:
	var pts := PackedVector2Array([at + Vector2(0, -half.y), at + Vector2(half.x, 0), at + Vector2(0, half.y), at + Vector2(-half.x, 0)])
	c.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	c.draw_polyline(pts, rim, w, true)

## An hourglass about 30 x `k` tall centred on `at`, with what has run through it heaped below.
static func _hourglass(c: Control, at: Vector2, k: float, fill: Color, rim: Color) -> void:
	c.draw_colored_polygon(_p(at, k, [Vector2(-6, -9), Vector2(6, -9), Vector2(0, 0)]), fill)
	c.draw_colored_polygon(_p(at, k, [Vector2(-7, 15), Vector2(7, 15), Vector2(0, 8)]), fill)
	var top := _p(at, k, [Vector2(-10, -15), Vector2(10, -15), Vector2(0, 0), Vector2(-10, -15)])
	var bottom := _p(at, k, [Vector2(0, 0), Vector2(10, 15), Vector2(-10, 15), Vector2(0, 0)])
	c.draw_polyline(top, rim, 1.8 * k, true)
	c.draw_polyline(bottom, rim, 1.8 * k, true)

## A flat ring seen from the side (`half` wide and high from its middle): filled and rimmed.
static func _ellipse(c: Control, at: Vector2, half: Vector2, fill: Color, rim: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(at + Vector2(cos(a) * half.x, sin(a) * half.y))
	c.draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	c.draw_polyline(pts, rim, w, true)

## A clawing hand on an arm, from `base` along `dir` (a unit vector), `length`
## long in all: the arm, the palm, and four fingers that spread and hook. (The
## hands of the Shadow caster's Breach; the same shape as on its ability icons.)
static func _claw(c: Control, base: Vector2, dir: Vector2, length: float, arm: Color, nails: Color, w: float) -> void:
	var palm := base + dir * length * 0.66
	c.draw_line(base, palm, arm, w * 1.5, true)
	c.draw_circle(palm, w * 1.25, arm)
	for i in 4:
		var spread := (i - 1.5) * 0.4
		var finger := dir.rotated(spread)
		var knuckle := palm + finger * length * 0.2
		c.draw_line(palm, knuckle, arm, w * 0.8, true)
		c.draw_line(knuckle, knuckle + finger.rotated(-spread * 1.6) * length * 0.16, nails, w * 0.75, true)

## The red of a Hound's hide, and of blood (Shadow melee; the same as on its ability icons).
const HOUND_RED := Color(0.82, 0.16, 0.22)
const HEAL_GREEN := Color(0.45, 1.0, 0.45)

## A Hound's head from the side (the one on the ability icons: Abilities._hound_head).
static func _hound(c: Control, at: Vector2, s: float, horn: Color, open: float = 0.6, flip: float = 1.0) -> void:
	load("res://scripts/abilities.gd")._hound_head(c, at, s, horn, WHITE, open, flip)

## A plus sign `r` from its middle to the end of an arm.
static func _plus(c: Control, at: Vector2, r: float, col: Color, w: float) -> void:
	c.draw_line(at - Vector2(r, 0), at + Vector2(r, 0), col, w, true)
	c.draw_line(at - Vector2(0, r), at + Vector2(0, r), col, w, true)

## Holy gold (censer, gold prisms, the light of the book).
const HOLY_GOLD := Color(1.0, 0.82, 0.35)

## A censer hanging from its chain, centred on `at`.
static func _censer(c: Control, at: Vector2, k: float) -> void:
	c.draw_line(at + Vector2(0, -12) * k, at + Vector2(0, -5) * k, WHITE, 1.6 * k, true)
	c.draw_colored_polygon(_p(at, k, [Vector2(-7, -5), Vector2(7, -5), Vector2(5, 5), Vector2(-5, 5)]), HOLY_GOLD)
	c.draw_arc(at + Vector2(0, -5) * k, 7.0 * k, PI, TAU, 10, WHITE, 1.6 * k, true)
	c.draw_circle(at + Vector2(0, 0) * k, 2.0 * k, WHITE)

## The pale of a puppet String (Shadow healer; the same as on its ability icons).
const STRING_PALE := Color(0.93, 0.86, 1.0)

## A puppet String from `a` to `b`, with the knot it ends in.
static func _thread(c: Control, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	c.draw_line(a, b, col, w, true)
	c.draw_circle(b, w * 1.1, col)

## The demon's hand reaching down from `at`, its wrist (the one on the ability icons: Abilities._demon_hand).
static func _hand(c: Control, at: Vector2, s: float, flip: float = 1.0) -> void:
	load("res://scripts/abilities.gd")._demon_hand(c, at, s, HOUND_RED, WHITE, flip)

# --- One picture per talent ---------------------------------------------------------

static func _draw_key(c: Control, key: String, mid: Vector2, k: float, col: Color, light: Color) -> void:
	match key:
		# --- Holy healer: the Hymns ---
		"holy_mercys_ear":   # an ear, and a low heart it hears
			c.draw_arc(mid + Vector2(-4, -2) * k, 11.0 * k, PI * 0.6, PI * 2.1, 18, WHITE, 3.0 * k, true)
			c.draw_arc(mid + Vector2(-3, -1) * k, 5.0 * k, PI * 0.8, PI * 2.0, 10, light, 2.2 * k, true)
			c.draw_circle(mid + Vector2(11, 9) * k, 3.2 * k, Color(1.0, 0.8, 0.3))
			c.draw_circle(mid + Vector2(16, 9) * k, 3.2 * k, Color(1.0, 0.8, 0.3))
			c.draw_colored_polygon(_p(mid, k, [Vector2(8.2, 10), Vector2(18.8, 10), Vector2(13.5, 17)]), Color(1.0, 0.8, 0.3))
		"holy_many_voices":   # many small mouths of light singing as one
			for i in 5:
				var a := PI + PI * (i + 0.5) / 5.0
				c.draw_circle(mid + Vector2(cos(a), sin(a) + 0.7) * 14.0 * k, 3.4 * k, WHITE if i == 2 else light)
			c.draw_arc(mid + Vector2(0, 12) * k, 9.0 * k, PI * 1.15, PI * 1.85, 10, WHITE, 2.0 * k, true)
		"holy_watchful":   # an open eye under a blue arc
			c.draw_arc(mid + Vector2(0, 10) * k, 18.0 * k, PI * 1.2, PI * 1.8, 14, Color(0.45, 0.7, 1.0), 3.0 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-13, 4), Vector2(-5, -3), Vector2(5, -3), Vector2(13, 4), Vector2(5, 11), Vector2(-5, 11)]), WHITE)
			c.draw_circle(mid + Vector2(0, 4) * k, 4.2 * k, Color(0.2, 0.35, 0.7))
		"holy_key_change":   # a key whose bit is a note
			c.draw_arc(mid + Vector2(-9, -6) * k, 6.5 * k, 0.0, TAU, 16, WHITE, 3.0 * k, true)
			c.draw_line(mid + Vector2(-4, -1) * k, mid + Vector2(12, 15) * k, WHITE, 3.0 * k, true)
			c.draw_line(mid + Vector2(7, 10) * k, mid + Vector2(11, 6) * k, light, 2.5 * k, true)
			c.draw_line(mid + Vector2(10, 13) * k, mid + Vector2(14, 9) * k, light, 2.5 * k, true)
		"holy_open_doors":   # two doors of an arch swung open, light between them
			c.draw_colored_polygon(_p(mid, k, [Vector2(-4, 16), Vector2(-4, -8), Vector2(4, -8), Vector2(4, 16)]), Color(light, 0.8))
			c.draw_colored_polygon(_p(mid, k, [Vector2(-6, 16), Vector2(-6, -8), Vector2(-16, -12), Vector2(-16, 14)]), col.darkened(0.2))
			c.draw_colored_polygon(_p(mid, k, [Vector2(6, 16), Vector2(6, -8), Vector2(16, -12), Vector2(16, 14)]), col.darkened(0.2))
			c.draw_arc(mid + Vector2(0, -8) * k, 6.0 * k, PI, TAU, 10, WHITE, 2.5 * k, true)
		# --- Holy: open talents ---
		"holy_grace":   # an open hand, and a heal rising from it to someone else
			c.draw_colored_polygon(_p(mid, k, [Vector2(-14, 8), Vector2(-4, 14), Vector2(10, 14), Vector2(14, 8), Vector2(-2, 8)]), WHITE)
			for x in [-2.0, 3.0, 8.0]:
				c.draw_line(mid + Vector2(x, 8) * k, mid + Vector2(x + 1.0, 3) * k, WHITE, 2.4 * k, true)
			_plus(c, mid + Vector2(4, -9) * k, 6.0 * k, HEAL_GREEN, 3.0 * k)
		"holy_burnished":   # a polished golden disc with a shine across it
			c.draw_circle(mid, 13.0 * k, HOLY_GOLD)
			c.draw_arc(mid, 13.0 * k, 0, TAU, 24, WHITE, 1.8 * k, true)
			c.draw_line(mid + Vector2(-8, -3) * k, mid + Vector2(-2, -9) * k, WHITE, 2.4 * k, true)
			c.draw_line(mid + Vector2(-5, 2) * k, mid + Vector2(4, -7) * k, Color(WHITE, 0.7), 1.6 * k, true)
		"holy_steadfast":   # a shield, light along its rim
			_shield(c, mid, k, col.darkened(0.2), HOLY_GOLD)
			c.draw_line(mid + Vector2(0, -10) * k, mid + Vector2(0, 10) * k, WHITE, 2.2 * k, true)
			c.draw_line(mid + Vector2(-7, -4) * k, mid + Vector2(7, -4) * k, WHITE, 2.2 * k, true)
		"holy_long_note":   # a note held on and on
			c.draw_circle(mid + Vector2(-10, 8) * k, 4.5 * k, WHITE)
			c.draw_line(mid + Vector2(-6, 8) * k, mid + Vector2(-6, -12) * k, WHITE, 2.4 * k, true)
			c.draw_line(mid + Vector2(-6, -12) * k, mid + Vector2(16, -12) * k, light, 2.4 * k, true)
			for i in 3:
				c.draw_line(mid + Vector2(-2 + i * 6, -4) * k, mid + Vector2(2 + i * 6, -4) * k, Color(light, 0.9 - i * 0.25), 2.0 * k, true)
		"holy_overflowing":   # a cup running over, the spill becoming a shield
			c.draw_colored_polygon(_p(mid, k, [Vector2(-10, -8), Vector2(6, -8), Vector2(3, 6), Vector2(-7, 6)]), HOLY_GOLD)
			c.draw_line(mid + Vector2(-2, 6) * k, mid + Vector2(-2, 12) * k, HOLY_GOLD, 2.4 * k, true)
			c.draw_line(mid + Vector2(-7, 13) * k, mid + Vector2(3, 13) * k, HOLY_GOLD, 2.4 * k, true)
			c.draw_line(mid + Vector2(6, -9) * k, mid + Vector2(12, -2) * k, HEAL_GREEN, 2.4 * k, true)
			c.draw_arc(mid + Vector2(13, 6) * k, 6.0 * k, -PI * 0.5, PI * 0.5, 8, WHITE, 2.4 * k, true)
		"holy_penitent":   # a cracked heart, a heal mending it
			c.draw_circle(mid + Vector2(-5, -2) * k, 6.0 * k, Color(1.0, 0.45, 0.45))
			c.draw_circle(mid + Vector2(5, -2) * k, 6.0 * k, Color(1.0, 0.45, 0.45))
			c.draw_colored_polygon(_p(mid, k, [Vector2(-10.6, 0), Vector2(10.6, 0), Vector2(0, 13)]), Color(1.0, 0.45, 0.45))
			c.draw_polyline(_p(mid, k, [Vector2(0, -6), Vector2(-3, 0), Vector2(2, 4), Vector2(-1, 10)]), PIT, 1.8 * k, true)
			_plus(c, mid + Vector2(13, -12) * k, 4.0 * k, HEAL_GREEN, 2.4 * k)
		"holy_zeal":   # a figure dashing ahead, light streaming behind
			_figure(c, mid + Vector2(6, 0) * k, 16.0 * k, WHITE, 2.4 * k)
			for i in 3:
				c.draw_line(mid + Vector2(-16, -6 + i * 6) * k, mid + Vector2(-5, -6 + i * 6) * k, Color(HOLY_GOLD, 0.9 - i * 0.2), 2.2 * k, true)
		"holy_clear_mind":   # a head in profile, a clear drop of mana in it
			c.draw_arc(mid + Vector2(-1, -2) * k, 12.0 * k, PI * 0.75, PI * 2.25, 20, WHITE, 2.6 * k, true)
			c.draw_line(mid + Vector2(8, 6) * k, mid + Vector2(5, 15) * k, WHITE, 2.6 * k, true)
			_drop(c, mid + Vector2(-1, 0) * k, 0.45 * k, Color(0.45, 0.7, 1.0), WHITE, k)
		"holy_sheltering_light":   # a dome of light over a small figure
			c.draw_arc(mid + Vector2(0, 12) * k, 16.0 * k, PI, TAU, 20, HOLY_GOLD, 3.0 * k, true)
			c.draw_arc(mid + Vector2(0, 12) * k, 12.0 * k, PI, TAU, 16, Color(HOLY_GOLD, 0.45), 2.0 * k, true)
			_figure(c, mid + Vector2(0, 4) * k, 10.0 * k, WHITE, 2.0 * k)
			c.draw_line(mid + Vector2(-17, 12) * k, mid + Vector2(17, 12) * k, light, 2.0 * k, true)
		"holy_long_glass":   # a prism, and a clock face showing the time it stays
			_pane(c, mid + Vector2(-5, 0) * k, Vector2(8, 14) * k, Color(WHITE, 0.55), WHITE, 1.8 * k)
			_clock(c, mid + Vector2(9, 8) * k, 7.0 * k, HOLY_GOLD, k)
			c.draw_line(mid + Vector2(9, 8) * k, mid + Vector2(9, 3) * k, HOLY_GOLD, 1.8 * k, true)
		"holy_second_breath":   # a heal lifting a bar, and a drop of mana coming back
			c.draw_rect(Rect2(mid + Vector2(-15, -4) * k, Vector2(16, 8) * k), Color(0, 0, 0, 0.5))
			c.draw_rect(Rect2(mid + Vector2(-15, -4) * k, Vector2(13, 8) * k), HEAL_GREEN)
			c.draw_line(mid + Vector2(-12, 12) * k, mid + Vector2(-2, 6) * k, WHITE, 2.0 * k, true)
			_drop(c, mid + Vector2(10, 0) * k, 0.55 * k, Color(0.45, 0.7, 1.0), WHITE, k)
		# --- Holy: shared by several specs ---
		"holy_heavy_chain":   # a censer hanging from heavy links
			for i in 3:
				c.draw_arc(mid + Vector2(0, -15 + i * 6) * k, 3.2 * k, 0, TAU, 10, WHITE, 2.2 * k, true)
			_censer(c, mid + Vector2(0, 7) * k, k)
		"holy_absolution":   # a censer tipped, a heal pouring out of it
			_censer(c, mid + Vector2(-6, -4) * k, k)
			_plus(c, mid + Vector2(8, 10) * k, 6.0 * k, HEAL_GREEN, 3.0 * k)
		"holy_unbroken":   # a ring of light that never closes up, a clock inside
			c.draw_arc(mid, 15.0 * k, 0, TAU, 28, HOLY_GOLD, 3.0 * k, true)
			_clock(c, mid, 8.0 * k, WHITE, k)
			c.draw_line(mid, mid + Vector2(5, -3) * k, WHITE, 1.8 * k, true)
		"holy_glimmering":   # an arrow with a glint at its tip
			c.draw_line(mid + Vector2(-14, 14) * k, mid + Vector2(8, -8) * k, WOOD, 2.4 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(14, -14), Vector2(5, -10), Vector2(10, -5)]), WHITE)
			_plus(c, mid + Vector2(13, -13) * k, 6.0 * k, HOLY_GOLD, 1.8 * k)
		"holy_steady_aim":   # sights over a drawn bow
			c.draw_arc(mid + Vector2(-6, 0) * k, 14.0 * k, -PI * 0.45, PI * 0.45, 12, WOOD, 3.0 * k, true)
			c.draw_line(mid + Vector2(-1, -13) * k, mid + Vector2(-1, 13) * k, WHITE, 1.2 * k, true)
			c.draw_arc(mid + Vector2(8, 0) * k, 6.0 * k, 0, TAU, 14, HOLY_GOLD, 2.0 * k, true)
			c.draw_line(mid + Vector2(8, -9) * k, mid + Vector2(8, 9) * k, HOLY_GOLD, 1.4 * k, true)
			c.draw_line(mid + Vector2(-1, 0) * k, mid + Vector2(17, 0) * k, HOLY_GOLD, 1.4 * k, true)
		"holy_swelling_chorus":   # waves of song growing as they go
			c.draw_circle(mid + Vector2(-12, 0) * k, 3.5 * k, WHITE)
			for i in 3:
				c.draw_arc(mid + Vector2(-12, 0) * k, (7.0 + i * 6.0) * k, -0.7, 0.7, 10, Color(light, 1.0 - i * 0.2), (2.0 + i * 0.6) * k, true)
		"holy_quick_lance":   # a lance of light, cast in a flash
			c.draw_line(mid + Vector2(-14, 12) * k, mid + Vector2(12, -10) * k, HOLY_GOLD, 3.2 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(16, -14), Vector2(9, -11), Vector2(13, -7)]), WHITE)
			for i in 2:
				c.draw_line(mid + Vector2(-14 + i * 4, 2 + i * 4) * k, mid + Vector2(-6 + i * 4, -4 + i * 4) * k, Color(WHITE, 0.6), 1.6 * k, true)
		"holy_full_quiver":   # a quiver packed with golden arrows
			c.draw_colored_polygon(_p(mid, k, [Vector2(-8, -4), Vector2(6, -4), Vector2(4, 16), Vector2(-6, 16)]), WOOD)
			for x in [-5.0, -1.0, 3.0]:
				c.draw_line(mid + Vector2(x, -4) * k, mid + Vector2(x + 3.0, -15) * k, HOLY_GOLD, 2.0 * k, true)
				c.draw_circle(mid + Vector2(x + 3.0, -15) * k, 1.6 * k, WHITE)
		"holy_wide_break":   # a gold prism breaking, its ring reaching wide
			_pane(c, mid, Vector2(6, 10) * k, HOLY_GOLD, WHITE, 1.6 * k)
			c.draw_arc(mid, 16.0 * k, 0, TAU, 28, Color(HOLY_GOLD, 0.7), 2.2 * k, true)
			c.draw_line(mid + Vector2(-2, -6) * k, mid + Vector2(2, 4) * k, PIT, 1.4 * k, true)
		"holy_watchful_eye":   # an eye, the hit it saw, and the heal it makes stronger
			c.draw_colored_polygon(_p(mid, k, [Vector2(-14, -2), Vector2(-5, -9), Vector2(5, -9), Vector2(14, -2), Vector2(5, 5), Vector2(-5, 5)]), WHITE)
			c.draw_circle(mid + Vector2(0, -2) * k, 4.0 * k, HOLY_GOLD)
			c.draw_polyline(_p(mid, k, [Vector2(-12, 10), Vector2(-8, 14), Vector2(-4, 9)]), Color(1.0, 0.45, 0.45), 2.2 * k, true)
			_plus(c, mid + Vector2(9, 12) * k, 4.5 * k, HEAL_GREEN, 2.6 * k)
		"holy_last_rites":   # a book of hymns, a candle burning low beside it
			c.draw_colored_polygon(_p(mid, k, [Vector2(-15, -6), Vector2(-2, -3), Vector2(-2, 14), Vector2(-15, 11)]), WHITE)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-2, -3), Vector2(5, -6), Vector2(5, 11), Vector2(-2, 14)]), light)
			c.draw_rect(Rect2(mid + Vector2(10, 2) * k, Vector2(5, 12) * k), WHITE)
			c.draw_colored_polygon(_p(mid, k, [Vector2(12.5, -6), Vector2(10.5, 0), Vector2(14.5, 0)]), HOLY_GOLD)
		"holy_bright_motes":   # motes of light with a heal in them
			for v in [Vector2(-9, -8), Vector2(8, -6), Vector2(0, 9)]:
				c.draw_circle(mid + (v as Vector2) * k, 5.0 * k, Color(HOLY_GOLD, 0.8))
				c.draw_circle(mid + (v as Vector2) * k, 2.2 * k, WHITE)
			_plus(c, mid + Vector2(12, 11) * k, 4.0 * k, HEAL_GREEN, 2.4 * k)
		"holy_steady_ray":   # a straight, even beam from one point to another
			c.draw_circle(mid + Vector2(-14, 10) * k, 3.5 * k, WHITE)
			c.draw_circle(mid + Vector2(14, -10) * k, 3.5 * k, HEAL_GREEN)
			c.draw_line(mid + Vector2(-14, 10) * k, mid + Vector2(14, -10) * k, Color(WHITE, 0.45), 6.0 * k, true)
			c.draw_line(mid + Vector2(-14, 10) * k, mid + Vector2(14, -10) * k, WHITE, 2.0 * k, true)
		# --- Holy: the bottom row ---
		"holy_censers_weight":   # a heavy censer swinging down hard
			_censer(c, mid + Vector2(2, 2) * k, k)
			c.draw_line(mid + Vector2(-14, -14) * k, mid + Vector2(0, -4) * k, WHITE, 2.0 * k, true)
			for i in 2:
				c.draw_arc(mid + Vector2(2, 2) * k, (14.0 + i * 3.0) * k, PI * 0.6, PI * 1.0, 8, Color(light, 0.7 - i * 0.3), 2.0 * k, true)
		"holy_sunsteel":   # an arrowhead with a sun rising behind it
			c.draw_circle(mid + Vector2(0, 6) * k, 9.0 * k, HOLY_GOLD)
			for i in 7:
				var a := PI + PI * i / 6.0
				c.draw_line(mid + Vector2(0, 6) * k + Vector2(cos(a), sin(a)) * 11.0 * k,
					mid + Vector2(0, 6) * k + Vector2(cos(a), sin(a)) * 16.0 * k, HOLY_GOLD, 1.8 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(0, -12), Vector2(-6, 2), Vector2(6, 2)]), WHITE)
		"holy_radiance":   # a heal shining in every direction
			for i in 8:
				var a := TAU * i / 8.0
				c.draw_line(mid + Vector2(cos(a), sin(a)) * 10.0 * k, mid + Vector2(cos(a), sin(a)) * 16.0 * k, HOLY_GOLD, 2.0 * k, true)
			_plus(c, mid, 8.0 * k, HEAL_GREEN, 4.0 * k)
		# --- Holy tank: the Censer ---
		"holy_mote_magnet":   # motes drawn in from afar to a hand
			c.draw_arc(mid + Vector2(-6, 4) * k, 9.0 * k, PI * 0.5, PI * 1.5, 12, WHITE, 3.0 * k, true)
			for v in [Vector2(6, -10), Vector2(12, -2), Vector2(8, 8)]:
				c.draw_circle(mid + (v as Vector2) * k, 2.8 * k, HOLY_GOLD)
				c.draw_line(mid + (v as Vector2) * k, mid + (v as Vector2) * k + Vector2(-5, 1) * k, Color(HOLY_GOLD, 0.5), 1.4 * k, true)
		"holy_bright_barrier":   # a barrier of light in layers
			for i in 3:
				c.draw_arc(mid + Vector2(0, 14) * k, (8.0 + i * 5.0) * k, PI * 1.1, PI * 1.9, 14, Color(HOLY_GOLD, 1.0 - i * 0.25), 2.6 * k, true)
			c.draw_circle(mid + Vector2(0, 10) * k, 3.0 * k, WHITE)
		"holy_lingering_light":   # a mote of light beside an hourglass
			c.draw_circle(mid + Vector2(-8, 4) * k, 6.0 * k, Color(HOLY_GOLD, 0.8))
			c.draw_circle(mid + Vector2(-8, 4) * k, 2.6 * k, WHITE)
			_hourglass(c, mid + Vector2(9, 0) * k, 0.6 * k, HOLY_GOLD, WHITE)
		"holy_wide_arc":   # a censer's swing drawn wide
			c.draw_arc(mid + Vector2(0, 10) * k, 16.0 * k, PI * 1.05, PI * 1.95, 18, HOLY_GOLD, 3.0 * k, true)
			c.draw_arc(mid + Vector2(0, 10) * k, 11.0 * k, PI * 1.15, PI * 1.85, 14, Color(HOLY_GOLD, 0.5), 2.0 * k, true)
			c.draw_circle(mid + Vector2(15, 4) * k, 3.5 * k, WHITE)
		"holy_deep_pour":   # a censer tipped over, a wave of light pouring out
			_censer(c, mid + Vector2(-8, -6) * k, k)
			c.draw_polyline(_p(mid, k, [Vector2(-4, 4), Vector2(2, 10), Vector2(8, 6), Vector2(14, 12)]), HOLY_GOLD, 3.0 * k, true)
			c.draw_line(mid + Vector2(-16, 15) * k, mid + Vector2(16, 15) * k, Color(HOLY_GOLD, 0.6), 2.4 * k, true)
		"holy_high_censer":   # a censer hanging high over a ring on the ground
			_censer(c, mid + Vector2(0, -6) * k, k)
			_ellipse(c, mid + Vector2(0, 13) * k, Vector2(14, 3.5) * k, Color(HOLY_GOLD, 0.25), HOLY_GOLD, 1.6 * k)
			c.draw_line(mid + Vector2(0, 2) * k, mid + Vector2(0, 10) * k, Color(HOLY_GOLD, 0.5), 1.4 * k, true)
		# --- Holy healer #2: the Prisms ---
		"holy_clear_glass":   # a beam grazing a prism, the reach marked either side
			_pane(c, mid + Vector2(2, -4) * k, Vector2(5, 9) * k, Color(WHITE, 0.6), WHITE, 1.6 * k)
			c.draw_line(mid + Vector2(-16, 12) * k, mid + Vector2(16, 4) * k, HEAL_GREEN, 2.4 * k, true)
			c.draw_line(mid + Vector2(-16, 6) * k, mid + Vector2(16, -2) * k, Color(HEAL_GREEN, 0.4), 1.2 * k, true)
		"holy_deep_crystal":   # a prism filled high with light
			_pane(c, mid, Vector2(9, 15) * k, Color(WHITE, 0.25), WHITE, 1.8 * k)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-7, 3), Vector2(7, 3), Vector2(0, 14)]), HEAL_GREEN)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-8.5, 1), Vector2(8.5, 1), Vector2(7, 3), Vector2(-7, 3)]), Color(HEAL_GREEN, 0.6))
		"holy_sharp_facets":   # a cut gem, each facet catching a heal
			c.draw_colored_polygon(_p(mid, k, [Vector2(-12, -4), Vector2(-6, -12), Vector2(6, -12), Vector2(12, -4), Vector2(0, 14)]), Color(WHITE, 0.7))
			c.draw_polyline(_p(mid, k, [Vector2(-12, -4), Vector2(12, -4), Vector2(0, 14), Vector2(-6, -4), Vector2(-6, -12)]), light, 1.4 * k, true)
			c.draw_line(mid + Vector2(6, -12) * k, mid + Vector2(6, -4) * k, light, 1.4 * k, true)
			_plus(c, mid + Vector2(13, 11) * k, 3.5 * k, HEAL_GREEN, 2.2 * k)
		"holy_wide_burst":   # a prism shattering into a wide ring of healing
			_pane(c, mid, Vector2(5, 8) * k, Color(WHITE, 0.7), WHITE, 1.4 * k)
			c.draw_arc(mid, 13.0 * k, 0, TAU, 24, HEAL_GREEN, 2.2 * k, true)
			c.draw_arc(mid, 17.0 * k, 0, TAU, 28, Color(HEAL_GREEN, 0.45), 1.6 * k, true)
		"holy_prismatic_burst":   # shards of a prism flying out in colours
			var cols := [Color(1.0, 0.45, 0.45), HOLY_GOLD, HEAL_GREEN, Color(0.45, 0.7, 1.0), Color(0.8, 0.5, 1.0)]
			for i in 5:
				var a := TAU * i / 5.0 - PI / 2.0
				_shard(c, mid + Vector2(cos(a), sin(a)) * 15.0 * k, Vector2(cos(a), sin(a)), 8.0 * k, 3.0 * k, cols[i], WHITE, k)
			c.draw_circle(mid, 3.0 * k, WHITE)
		"holy_quick_realign":   # prisms turning around a circle of arrows
			c.draw_arc(mid, 12.0 * k, 0.3, TAU - 0.6, 24, light, 2.2 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(12, -2), Vector2(8, -8), Vector2(16, -7)]), light)
			_pane(c, mid + Vector2(-6, 0) * k, Vector2(3, 5) * k, WHITE, WHITE, 1.2 * k)
			_pane(c, mid + Vector2(5, 4) * k, Vector2(3, 5) * k, WHITE, WHITE, 1.2 * k)
		# --- Holy archer: Lightstring ---
		"holy_wide_fan":   # one prism fanning arrows out wide
			_pane(c, mid + Vector2(-8, 0) * k, Vector2(5, 9) * k, HOLY_GOLD, WHITE, 1.4 * k)
			for a in [-0.6, 0.0, 0.6]:
				var d := Vector2(cos(a), sin(a))
				c.draw_line(mid + Vector2(-3, 0) * k, mid + Vector2(-3, 0) * k + d * 17.0 * k, WHITE, 1.8 * k, true)
		"holy_split_light":   # an arrow of light splitting in two
			c.draw_line(mid + Vector2(-16, 0) * k, mid + Vector2(-2, 0) * k, HOLY_GOLD, 2.8 * k, true)
			c.draw_line(mid + Vector2(-2, 0) * k, mid + Vector2(14, -10) * k, HOLY_GOLD, 2.4 * k, true)
			c.draw_line(mid + Vector2(-2, 0) * k, mid + Vector2(14, 10) * k, HOLY_GOLD, 2.4 * k, true)
			c.draw_circle(mid + Vector2(-2, 0) * k, 3.0 * k, WHITE)
		"holy_bright_quiver":   # a quiver glowing gold, its light flowing out
			c.draw_colored_polygon(_p(mid, k, [Vector2(-8, -6), Vector2(6, -6), Vector2(4, 15), Vector2(-6, 15)]), HOLY_GOLD)
			c.draw_line(mid + Vector2(-1, -6) * k, mid + Vector2(2, -15) * k, WHITE, 2.0 * k, true)
			for i in 3:
				c.draw_circle(mid + Vector2(11, -6 + i * 7) * k, 1.8 * k, Color(HOLY_GOLD, 0.9 - i * 0.25))
		"holy_deep_burn":   # an arrow drinking the light out of a prism
			_pane(c, mid + Vector2(-6, -4) * k, Vector2(6, 10) * k, Color(HOLY_GOLD, 0.35), WHITE, 1.4 * k)
			c.draw_line(mid + Vector2(-16, 12) * k, mid + Vector2(12, -2) * k, WOOD, 2.4 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(16, -4), Vector2(9, -4), Vector2(12, 2)]), HOLY_GOLD)
			c.draw_line(mid + Vector2(-6, -4) * k, mid + Vector2(10, -1) * k, Color(1.0, 0.55, 0.2), 2.0 * k, true)
		"holy_swift_light":   # a step of light from one spot to a prism
			_pane(c, mid + Vector2(10, -4) * k, Vector2(4, 7) * k, HOLY_GOLD, WHITE, 1.2 * k)
			_figure(c, mid + Vector2(-8, 2) * k, 12.0 * k, WHITE, 2.0 * k)
			c.draw_arc(mid + Vector2(1, 4) * k, 9.0 * k, PI * 1.1, PI * 1.9, 10, Color(HOLY_GOLD, 0.8), 2.0 * k, true)
		"holy_long_volley":   # arrows still falling, a long trail of them
			for i in 4:
				var x := -12.0 + i * 8.0
				c.draw_line(mid + Vector2(x, -14 + i * 2) * k, mid + Vector2(x - 3.0, 6 + i * 2) * k, Color(HOLY_GOLD, 1.0 - i * 0.18), 2.0 * k, true)
			c.draw_line(mid + Vector2(-16, 15) * k, mid + Vector2(16, 15) * k, light, 2.0 * k, true)
		# --- Shadow: the Breach for builds that dip into it ---
		"shadow_tainted_steel":   # Baited Steel: a blade, and the hand that comes up after what it cut
			c.draw_line(mid + Vector2(-11, 5) * k, mid + Vector2(14, -18) * k, Color(0.9, 0.9, 0.95), 4.0 * k, true)
			c.draw_line(mid + Vector2(-15, 0) * k, mid + Vector2(-6, 9) * k, light, 3.0 * k, true)
			c.draw_line(mid + Vector2(-11, 5) * k, mid + Vector2(-16, 10) * k, WOOD, 3.2 * k, true)
			_ellipse(c, mid + Vector2(7, 15) * k, Vector2(10, 3.5) * k, PIT, light, 1.4 * k)
			_claw(c, mid + Vector2(7, 15) * k, Vector2(0.1, -1).normalized(), 17.0 * k, col.lightened(0.15), WHITE, 1.8 * k)
		# --- Shadow: the open talents ---
		"shadow_slow_death":   # an hourglass, and the dark still running through it
			_hourglass(c, mid, k, Color(col, 0.9), light)
			c.draw_line(mid, mid + Vector2(0, 8) * k, WHITE, 1.4 * k, true)
		"shadow_wasting":   # drops falling one close behind the other
			c.draw_line(mid + Vector2(-17, 3) * k, mid + Vector2(-9, 11) * k, Color(light, 0.5), 1.4 * k, true)
			c.draw_line(mid + Vector2(3, -17) * k, mid + Vector2(11, -9) * k, Color(light, 0.5), 1.4 * k, true)
			for i in 3:
				_drop(c, mid + Vector2(-11 + i * 11, -8 + i * 8) * k, (0.42 + i * 0.1) * k, Color(col, 0.9), light, k * 0.7)
		"shadow_finish_it":   # a health bar almost empty, and the blow that ends it
			c.draw_rect(Rect2(mid + Vector2(-15, 7) * k, Vector2(30, 7) * k), Color(0, 0, 0, 0.5), true)
			c.draw_rect(Rect2(mid + Vector2(-15, 7) * k, Vector2(7, 7) * k), Color(0.85, 0.2, 0.2), true)
			c.draw_rect(Rect2(mid + Vector2(-15, 7) * k, Vector2(30, 7) * k), light, false, 1.4 * k)
			_shard(c, mid + Vector2(0, 5) * k, Vector2(0, 1), 17.0 * k, 5.0 * k, Color(col, 0.9), light, k)
		"shadow_spite":   # a blow taken, and the spark it leaves behind
			_shield(c, mid + Vector2(-4, 3) * k, k * 0.8, Color(col, 0.6), light)
			c.draw_line(mid + Vector2(-18, -14) * k, mid + Vector2(-8, -4) * k, Color(0.85, 0.2, 0.2), 2.2 * k, true)
			for i in 6:
				var ray := Vector2(cos(TAU * i / 6.0), sin(TAU * i / 6.0))
				c.draw_line(mid + (Vector2(10, -8) + ray * 2.5) * k, mid + (Vector2(10, -8) + ray * 7.5) * k, WHITE, 1.6 * k, true)
		"shadow_carrion":   # what is left of an enemy, and the mana rising out of it
			c.draw_arc(mid + Vector2(0, 16) * k, 14.0 * k, PI, TAU, 16, light, 2.0 * k, true)
			c.draw_line(mid + Vector2(-15, 16) * k, mid + Vector2(15, 16) * k, light, 2.0 * k, true)
			for i in 3:
				c.draw_line(mid + Vector2(-6 + i * 6, 7) * k, mid + Vector2(-6 + i * 6, 13) * k, Color(col, 0.9), 1.6 * k, true)
			_drop(c, mid + Vector2(0, -8) * k, 0.5 * k, Color(0.35, 0.55, 1.0), WHITE, k * 0.7)
		"shadow_inevitable":   # a clock, and the dark closing in around it
			_clock(c, mid, 8.0 * k, WHITE, k)
			c.draw_line(mid, mid + Vector2(0, -5) * k, WHITE, 1.6 * k, true)
			c.draw_line(mid, mid + Vector2(4, 2) * k, WHITE, 1.6 * k, true)
			for i in 4:
				var inward := -Vector2(cos(TAU * i / 4.0 + PI / 4.0), sin(TAU * i / 4.0 + PI / 4.0))
				_shard(c, mid - inward * 11.0 * k, inward, 8.0 * k, 3.0 * k, Color(col, 0.9), light, k)
		# --- Shadow caster: the Breach ("decay" in the code) ---
		"shadow_seep":   # Lure: something withered dangled over the hole, and a hand rising to it
			_ellipse(c, mid + Vector2(0, 14) * k, Vector2(13, 4) * k, PIT, light, 1.5 * k)
			c.draw_line(mid + Vector2(0, -18) * k, mid + Vector2(0, -10) * k, Color(light, 0.6), 1.2 * k, true)
			c.draw_circle(mid + Vector2(0, -8) * k, 3.2 * k, light)
			c.draw_arc(mid + Vector2(0, -8) * k, 3.2 * k, 0, TAU, 12, WHITE, 1.2 * k, true)
			_claw(c, mid + Vector2(0, 14) * k, Vector2(0, -1), 18.0 * k, col.lightened(0.15), WHITE, 1.8 * k)
		"shadow_interest":   # stacks of coins, each taller than the last
			for i in 3:
				for j in 2 + i * 2:
					var coin := Rect2(mid + Vector2(-15.5 + i * 11, 11.4 - j * 4.5) * k, Vector2(9, 3.2) * k)
					c.draw_rect(coin, Color(col, 0.95), true)
					c.draw_rect(coin, light, false, 1.0 * k)
		"shadow_next_of_kin":   # one falls, and the hole under it moves under the one beside it
			_ellipse(c, mid + Vector2(-10, 14) * k, Vector2(7, 2.6) * k, Color(PIT, 0.5), Color(light, 0.4), 1.2 * k)
			_ellipse(c, mid + Vector2(10, 14) * k, Vector2(8, 3) * k, PIT, light, 1.5 * k)
			_figure(c, mid + Vector2(-10, 3) * k, 9.0 * k, Color(light, 0.45), 1.6 * k)
			_figure(c, mid + Vector2(10, 3) * k, 9.0 * k, WHITE, 1.6 * k)
			c.draw_arc(mid + Vector2(0, -5) * k, 10.0 * k, PI * 1.15, PI * 1.85, 12, light, 1.6 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(10, -6), Vector2(5, -11), Vector2(11, -12)]), light)
		"shadow_bitter_end":   # the hole all but shut, and the last hand out of it striking hardest
			_ellipse(c, mid + Vector2(0, 15) * k, Vector2(7, 2.2) * k, PIT, light, 1.4 * k)
			_claw(c, mid + Vector2(0, 15) * k, Vector2(0, -1), 24.0 * k, col.lightened(0.2), WHITE, 2.4 * k)
			for i in 5:
				var burst := Vector2(cos(PI + PI * (i + 0.5) / 5.0), sin(PI + PI * (i + 0.5) / 5.0))
				c.draw_line(mid + (Vector2(0, -6) + burst * 10.0) * k, mid + (Vector2(0, -6) + burst * 15.0) * k, WHITE, 1.6 * k, true)
		"shadow_no_floor":   # a pit with no bottom to it
			_ellipse(c, mid + Vector2(0, -8) * k, Vector2(14, 5) * k, Color(0, 0, 0, 0.7), light, 1.8 * k)
			for i in 4:
				c.draw_arc(mid + Vector2(0, -2.0 + i * 5.5) * k, (12.0 - i * 3.0) * k, 0.15 * PI, 0.85 * PI, 10,
					Color(col.lightened(0.2), 0.95 - i * 0.2), 1.6 * k, true)
		"shadow_small_change":   # the debt collected, and the coin left on the table
			c.draw_circle(mid + Vector2(-5, -4) * k, 10.0 * k, Color(col, 0.35))
			c.draw_arc(mid + Vector2(-5, -4) * k, 10.0 * k, 0, TAU, 24, Color(light, 0.5), 1.4 * k, true)
			c.draw_circle(mid + Vector2(10, 10) * k, 5.0 * k, Color(col, 0.95))
			c.draw_arc(mid + Vector2(10, 10) * k, 5.0 * k, 0, TAU, 16, WHITE, 1.6 * k, true)
			c.draw_line(mid + Vector2(-17, 16.5) * k, mid + Vector2(17, 16.5) * k, light, 1.6 * k, true)
		"shadow_rot_through":   # Hooked Claws: three raking marks, each ending in its hook
			for i in 3:
				var x := -10.0 + i * 10.0
				c.draw_line(mid + Vector2(x + 4, -16) * k, mid + Vector2(x - 3, 8) * k, light, 2.6 * k, true)
				c.draw_arc(mid + Vector2(x + 1.5, 8) * k, 4.5 * k, 0.2, PI, 8, WHITE, 2.2 * k, true)
				c.draw_circle(mid + Vector2(x + 4, -16) * k, 1.8 * k, col)
		"shadow_cut_short":   # a spell's sound, cut off
			for i in 3:
				c.draw_arc(mid + Vector2(-13, 2) * k, (6.0 + i * 6.0) * k, -PI * 0.3, PI * 0.3, 10, Color(light, 0.9 - i * 0.2), 1.8 * k, true)
			c.draw_circle(mid + Vector2(-13, 2) * k, 2.6 * k, light)
			c.draw_line(mid + Vector2(16, -15) * k, mid + Vector2(0, 16) * k, Color(0.85, 0.2, 0.2), 2.6 * k, true)
		"shadow_running_over":   # Wider Still: the hole, and how far it reaches now
			_ellipse(c, mid + Vector2(0, 4) * k, Vector2(17, 7) * k, Color(PIT, 0.55), Color(light, 0.6), 1.3 * k)
			_ellipse(c, mid + Vector2(0, 4) * k, Vector2(9, 4) * k, PIT, light, 1.7 * k)
			for sx: float in [-1.0, 1.0]:
				c.draw_line(mid + Vector2(10 * sx, 4) * k, mid + Vector2(16 * sx, 4) * k, WHITE, 1.6 * k, true)
				c.draw_colored_polygon(_p(mid, k, [Vector2(19 * sx, 4), Vector2(14 * sx, 0.5), Vector2(14 * sx, 7.5)]), WHITE)
			_claw(c, mid + Vector2(0, 4) * k, Vector2(0, -1), 17.0 * k, col.lightened(0.15), WHITE, 1.7 * k)
		"shadow_bite_down":   # jaws closing on what stands over the hole
			c.draw_line(mid + Vector2(-17, 0.5) * k, mid + Vector2(17, 0.5) * k, Color(light, 0.9), 3.4 * k, true)
			for i in 4:
				c.draw_colored_polygon(_p(mid + Vector2(-12 + i * 8, -12) * k, k, [Vector2(-4, 0), Vector2(4, 0), Vector2(0, 10)]), WHITE)
				c.draw_colored_polygon(_p(mid + Vector2(-12 + i * 8, 13) * k, k, [Vector2(-4, 0), Vector2(4, 0), Vector2(0, -10)]), WHITE)
			c.draw_line(mid + Vector2(-17, -13) * k, mid + Vector2(17, -13) * k, col.lightened(0.2), 2.4 * k, true)
			c.draw_line(mid + Vector2(-17, 14) * k, mid + Vector2(17, 14) * k, col.lightened(0.2), 2.4 * k, true)
		# --- Shadow: two more open talents ---
		"shadow_thick_blood":   # one heavy drop that will not fall
			_drop(c, mid + Vector2(0, 2) * k, 1.25 * k, HOUND_RED.darkened(0.15), light, k)
			c.draw_arc(mid + Vector2(-1, 6) * k, 7.0 * k, PI * 0.6, PI * 1.05, 8, Color(1.0, 0.8, 0.85), 2.0 * k, true)
			c.draw_line(mid + Vector2(-17, 18) * k, mid + Vector2(17, 18) * k, Color(light, 0.6), 1.6 * k, true)
		"shadow_feeding_frenzy":   # one down, and the jaws already going for the next
			_hound(c, mid + Vector2(-2, -5) * k, 1.15 * k, light, 1.0)
			for i in 3:
				c.draw_polyline(_p(mid + Vector2(-13 + i * 9, 14) * k, k, [Vector2(-3, -4), Vector2(2, 0), Vector2(-3, 4)]), WHITE, 2.0 * k, true)
		# --- Shadow melee: the Hounds themselves ---
		"shadow_lean_and_hungry":   # a Hound, and every rib of it showing
			_hound(c, mid + Vector2(3, -7) * k, 1.0 * k, light, 0.5)
			for i in 4:
				c.draw_arc(mid + Vector2(-12 + i * 7, 6) * k, 9.0 * k, PI * 0.15, PI * 0.6, 8, Color(light, 0.95 - i * 0.12), 2.0 * k, true)
		"shadow_fed":   # jaws shut on what they caught, and what drips from them
			_hound(c, mid + Vector2(-3, -5) * k, 1.2 * k, light, 0.0)
			_drop(c, mid + Vector2(9, 9) * k, 0.42 * k, HOUND_RED, WHITE, k * 0.7)
			_drop(c, mid + Vector2(2, 14) * k, 0.3 * k, HOUND_RED, WHITE, k * 0.6)
		"shadow_worked_up":   # jaws wide, hackles up
			_hound(c, mid + Vector2(-2, 3) * k, 1.2 * k, light, 1.0)
			for i in 4:
				var up := Vector2(cos(PI * (1.15 + i * 0.2)), sin(PI * (1.15 + i * 0.2)))
				c.draw_line(mid + (Vector2(-2, -7) + up * 7.0) * k, mid + (Vector2(-2, -7) + up * 13.0) * k, WHITE, 1.8 * k, true)
		"shadow_out_of_the_hole":   # the Hound up through the hole the hands come out of
			_ellipse(c, mid + Vector2(0, 14) * k, Vector2(16, 4.5) * k, PIT, light, 1.6 * k)
			_claw(c, mid + Vector2(11, 14) * k, Vector2(0.15, -1).normalized(), 15.0 * k, col.lightened(0.15), WHITE, 1.7 * k)
			_hound(c, mid + Vector2(-5, -1) * k, 1.05 * k, light, 0.7)
		"shadow_long_night":   # a moon that will be up a while yet, and the Hound under it
			c.draw_circle(mid + Vector2(8, -8) * k, 8.5 * k, Color(1.0, 0.95, 0.75))
			c.draw_circle(mid + Vector2(11.5, -10.5) * k, 7.2 * k, col.darkened(0.75))
			_hound(c, mid + Vector2(-5, 7) * k, 0.9 * k, light, 0.3)
		"shadow_take_it_with_you":   # something going under with them, feet first
			_ellipse(c, mid + Vector2(0, 12) * k, Vector2(15, 5) * k, PIT, light, 1.6 * k)
			_figure(c, mid + Vector2(0, 2) * k, 10.0 * k, WHITE, 1.9 * k)
			c.draw_arc(mid + Vector2(0, 9.5) * k, 15.0 * k, PI * 0.12, PI * 0.88, 14, light, 2.2 * k, true)
			for sx: float in [-1.0, 1.0]:
				c.draw_colored_polygon(_p(mid, k, [Vector2(9 * sx, 8), Vector2(15 * sx, 9), Vector2(10 * sx, 16)]), HOUND_RED)
				c.draw_line(mid + Vector2(16 * sx, -14) * k, mid + Vector2(16 * sx, -6) * k, light, 1.8 * k, true)
				c.draw_colored_polygon(_p(mid, k, [Vector2(16 * sx, -2), Vector2(16 * sx - 3.5, -7), Vector2(16 * sx + 3.5, -7)]), light)
		"shadow_pack_leader":   # the one in front, and the pack at its shoulders
			_hound(c, mid + Vector2(-13, -9) * k, 0.6 * k, Color(light, 0.75), 0.4)
			_hound(c, mid + Vector2(9, -11) * k, 0.6 * k, Color(light, 0.75), 0.4)
			_hound(c, mid + Vector2(-4, 6) * k, 1.2 * k, light, 0.8)
		# --- Shadow melee: one ability's talents each ---
		"shadow_still_wet":   # Open Up's gashes, still running
			for i in 3:
				var gash := Vector2(-9.0 + i * 9.0, 0)
				c.draw_line(mid + (Vector2(3, -17) + gash) * k, mid + (Vector2(-3, 2) + gash) * k, HOUND_RED, 4.2 * k, true)
				c.draw_line(mid + (Vector2(2.4, -14) + gash) * k, mid + (Vector2(-2.2, 0) + gash) * k, Color(1.0, 0.78, 0.84), 1.3 * k, true)
				_drop(c, mid + (Vector2(-3, 11 + (i % 2) * 5) + gash) * k, 0.3 * k, HOUND_RED, WHITE, k * 0.6)
		"shadow_share_the_kill":   # the blade's cut, and more of it coming back to you with the Hound there
			c.draw_line(mid + Vector2(-17, 16) * k, mid + Vector2(2, -3) * k, Color(0.9, 0.9, 0.95), 3.2 * k, true)
			c.draw_line(mid + Vector2(-18, 11) * k, mid + Vector2(-12, 17) * k, WOOD, 2.6 * k, true)
			_hound(c, mid + Vector2(3, 9) * k, 0.8 * k, light, 0.3)
			_plus(c, mid + Vector2(11, -10) * k, 6.5 * k, HEAL_GREEN, 3.4 * k)
		"shadow_pincer":   # two jaws closing from either side on the one between
			for sx: float in [-1.0, 1.0]:
				c.draw_arc(mid + Vector2(-3 * sx, 0) * k, 15.0 * k, PI * 0.5 - sx * PI * 0.5 - PI * 0.36, PI * 0.5 - sx * PI * 0.5 + PI * 0.36, 14,
					light, 3.0 * k, true)
				for sy: float in [-1.0, 1.0]:
					c.draw_colored_polygon(_p(mid, k, [Vector2(9 * sx, 13.5 * sy), Vector2(6.5 * sx, 9.5 * sy), Vector2(3 * sx, 6 * sy),
						Vector2(10.5 * sx, 9 * sy)]), HOUND_RED)
			c.draw_circle(mid, 3.6 * k, WHITE)
		"shadow_again":   # the same leap, come round once more
			c.draw_arc(mid, 15.0 * k, -PI * 0.35, PI * 1.35, 24, light, 2.6 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(4.5, -18.5), Vector2(13, -13.5), Vector2(4, -9)]), light)
			_hound(c, mid + Vector2(-1.5, 1.5) * k, 0.75 * k, WHITE, 0.9)
		"shadow_stand_over":   # the Hound over you, and you getting back up under it
			_hound(c, mid + Vector2(-4, -8) * k, 1.05 * k, light, 0.25)
			_figure(c, mid + Vector2(-6, 10) * k, 6.5 * k, WHITE, 1.6 * k)
			_plus(c, mid + Vector2(11, 9) * k, 5.5 * k, HEAL_GREEN, 3.0 * k)
		"shadow_slipped_leash":   # a collar with nothing in it, the leash snapped, and one more of them loose
			c.draw_arc(mid + Vector2(-9, 9) * k, 7.0 * k, PI * 0.2, PI * 1.9, 16, Color(0.82, 0.82, 0.88), 2.6 * k, true)
			c.draw_line(mid + Vector2(-3, 5) * k, mid + Vector2(1, 1) * k, Color(0.82, 0.82, 0.88), 2.0 * k, true)
			c.draw_line(mid + Vector2(5, -3) * k, mid + Vector2(-1, -5.5) * k, WHITE, 1.6 * k, true)
			c.draw_line(mid + Vector2(5, -3) * k, mid + Vector2(7.5, 3) * k, WHITE, 1.6 * k, true)
			_hound(c, mid + Vector2(7, -9) * k, 0.85 * k, light, 0.9)
			for i in 3:
				c.draw_circle(mid + Vector2(6 + i * 5.5, 15) * k, 1.9 * k, HOUND_RED)
		# --- Shadow healer: the Strings themselves ---
		"shadow_first_stitch":   # a needle, the thread it pulls, and the first of the mending
			c.draw_line(mid + Vector2(-15, 13) * k, mid + Vector2(9, -11) * k, Color(0.88, 0.9, 0.96), 2.6 * k, true)
			c.draw_arc(mid + Vector2(10.5, -12.5) * k, 2.6 * k, 0, TAU, 10, Color(0.88, 0.9, 0.96), 1.5 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(11, -12), Vector2(17, -3), Vector2(8, 3), Vector2(15, 10), Vector2(7, 16)]), STRING_PALE, 1.6 * k, true)
			_plus(c, mid + Vector2(-9, -9) * k, 6.0 * k, HEAL_GREEN, 3.2 * k)
		"shadow_long_thread":   # one thread, a long one, and the time it has
			_thread(c, mid + Vector2(-9, -20) * k, mid + Vector2(-9, 17) * k, STRING_PALE, 2.0 * k)
			_clock(c, mid + Vector2(7, 0) * k, 9.5 * k, light, k)
			c.draw_line(mid + Vector2(7, 0) * k, mid + Vector2(7, -6.5) * k, WHITE, 1.8 * k, true)
			c.draw_line(mid + Vector2(7, 0) * k, mid + Vector2(11.5, 2.5) * k, WHITE, 1.8 * k, true)
		"shadow_spare_spool":   # a spool wound full, one end hanging free
			c.draw_rect(Rect2(mid + Vector2(-8, -10) * k, Vector2(16, 20) * k), STRING_PALE.darkened(0.25), true)
			for i in 5:
				c.draw_line(mid + Vector2(-8, -8 + i * 4) * k, mid + Vector2(8, -6 + i * 4) * k, STRING_PALE, 1.3 * k, true)
			for sy: float in [-1.0, 1.0]:
				c.draw_line(mid + Vector2(-13, 12 * sy) * k, mid + Vector2(13, 12 * sy) * k, WOOD.lightened(0.15), 4.0 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(8, 6), Vector2(15, 2), Vector2(18, 9), Vector2(14, 17)]), STRING_PALE, 1.6 * k, true)
		"shadow_full_harness":   # every thread it can hold, and what that keeps off it
			for i in 3:
				_thread(c, mid + Vector2(-9 + i * 9, -21) * k, mid + Vector2(-5 + i * 5, -8 + absf(i - 1.0) * 3.0) * k, STRING_PALE, 1.5 * k)
			_figure(c, mid + Vector2(0, 5) * k, 11.0 * k, WHITE, 1.9 * k)
			for sx: float in [-1.0, 1.0]:
				c.draw_arc(mid + Vector2(0, 5) * k, 17.0 * k, PI * 0.5 - sx * PI * 0.5 - PI * 0.3, PI * 0.5 - sx * PI * 0.5 + PI * 0.3, 12, light, 2.4 * k, true)
		"shadow_taking_the_weight":   # the two threads crossed, and what the one is spared going to the other
			c.draw_line(mid + Vector2(-11, -20) * k, mid + Vector2(10, -4) * k, STRING_PALE, 1.6 * k, true)
			c.draw_line(mid + Vector2(11, -20) * k, mid + Vector2(-10, -4) * k, HOUND_RED.lightened(0.25), 1.6 * k, true)
			_figure(c, mid + Vector2(-10, 5) * k, 8.5 * k, WHITE, 1.7 * k)
			_figure(c, mid + Vector2(10, 5) * k, 8.5 * k, HOUND_RED, 1.7 * k)
			c.draw_line(mid + Vector2(-6, 18) * k, mid + Vector2(4, 18) * k, light, 2.0 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(9, 18), Vector2(3, 14.5), Vector2(3, 21.5)]), light)
		"shadow_steady_hands":   # the hand held still, every thread from it dead straight
			_hand(c, mid + Vector2(0, -16) * k, 1.15 * k)
			for i in 4:
				var x := (-4.5 + i * 3.0) * 1.3 * 1.15
				_thread(c, mid + Vector2(x, -2) * k, mid + Vector2(x, 13 + (i % 2) * 4) * k, STRING_PALE, 1.4 * k)
			for sx: float in [-1.0, 1.0]:
				_plus(c, mid + Vector2(15 * sx, 6) * k, 3.6 * k, HEAL_GREEN, 2.2 * k)
		# --- Shadow healer: one ability's talent each ---
		"shadow_heave":   # hauled up higher, hand over hand
			for sx: float in [-1.0, 1.0]:
				_thread(c, mid + Vector2(6 * sx, -21) * k, mid + Vector2(3 * sx, -10) * k, STRING_PALE, 1.5 * k)
				for i in 2:
					c.draw_polyline(_p(mid, k, [Vector2(17 * sx - 4, 6 - i * 9), Vector2(17 * sx, 0 - i * 9), Vector2(17 * sx + 4, 6 - i * 9)]),
						HEAL_GREEN, 2.4 * k, true)
			_figure(c, mid + Vector2(0, 1) * k, 10.0 * k, WHITE, 1.9 * k)
			c.draw_line(mid + Vector2(-11, 18) * k, mid + Vector2(11, 18) * k, Color(light, 0.7), 1.8 * k, true)
		"shadow_long_drop":   # the threads let go, and the ground coming up
			c.draw_line(mid + Vector2(-3, -21) * k, mid + Vector2(-3, -15) * k, STRING_PALE, 1.5 * k, true)
			c.draw_line(mid + Vector2(4, -21) * k, mid + Vector2(5, -16) * k, STRING_PALE, 1.5 * k, true)
			_figure(c, mid + Vector2(0, -2) * k, 9.0 * k, HOUND_RED, 1.9 * k)
			for sx: float in [-1.0, 1.0]:
				c.draw_line(mid + Vector2(10 * sx, -12) * k, mid + Vector2(10 * sx, -2) * k, Color(light, 0.8), 1.6 * k, true)
			c.draw_line(mid + Vector2(-16, 15) * k, mid + Vector2(16, 15) * k, light, 2.2 * k, true)
			for i in 5:
				var out := Vector2(cos(PI * (1.1 + i * 0.2)), sin(PI * (1.1 + i * 0.2)))
				c.draw_line(mid + (Vector2(0, 15) + out * 4.0) * k, mid + (Vector2(0, 15) + out * 9.0) * k, WHITE, 1.7 * k, true)
		"shadow_snap_back":   # the thread whipping round, back into the hand it left
			_hand(c, mid + Vector2(-9, -16) * k, 0.85 * k)
			c.draw_arc(mid + Vector2(3, 3) * k, 12.5 * k, -PI * 0.75, PI * 0.95, 22, STRING_PALE, 2.2 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-11, -1), Vector2(-4, -6), Vector2(-3.5, 2)]), STRING_PALE)
			c.draw_circle(mid + Vector2(-9, 7) * k, 2.2 * k, STRING_PALE)
		"shadow_give_and_take":   # a thread gone slack, and what runs back down it
			c.draw_circle(mid + Vector2(-17, -15) * k, 2.6 * k, HOUND_RED)
			c.draw_circle(mid + Vector2(17, -15) * k, 2.6 * k, HOUND_RED)
			c.draw_arc(mid + Vector2(0, -27) * k, 21.0 * k, PI * 0.2, PI * 0.8, 18, STRING_PALE, 2.0 * k, true)
			_drop(c, mid + Vector2(0, 8) * k, 0.75 * k, Color(0.3, 0.55, 1.0), WHITE, k)
		# --- Shadow: three more open talents (helping others, holding things in place) ---
		"shadow_many_hands":   # more hands than one to mend with
			_hand(c, mid + Vector2(-13, -15) * k, 0.72 * k)
			_hand(c, mid + Vector2(13, -15) * k, 0.72 * k, -1.0)
			_hand(c, mid + Vector2(0, -18) * k, 0.72 * k)
			_plus(c, mid + Vector2(0, 10) * k, 7.0 * k, HEAL_GREEN, 3.6 * k)
		"shadow_lean_on_me":   # one holding the other up, and safer for it
			_figure(c, mid + Vector2(-6, 4) * k, 11.0 * k, WHITE, 1.9 * k)
			c.draw_line(mid + Vector2(11, -5) * k, mid + Vector2(-2, 1) * k, light, 1.9 * k, true)
			c.draw_arc(mid + Vector2(12.5, -8) * k, 2.6 * k, 0, TAU, 10, light, 1.9 * k, true)
			c.draw_line(mid + Vector2(11, -5) * k, mid + Vector2(8, 5) * k, light, 1.9 * k, true)
			c.draw_line(mid + Vector2(8, 5) * k, mid + Vector2(14, 13) * k, light, 1.9 * k, true)
			c.draw_line(mid + Vector2(8, 5) * k, mid + Vector2(5, 13) * k, light, 1.9 * k, true)
			c.draw_arc(mid + Vector2(-6, 4) * k, 16.0 * k, PI * 0.65, PI * 1.35, 12, STRING_PALE, 2.6 * k, true)
		"shadow_left_hanging":   # still up there, long after it should have been let down
			_thread(c, mid + Vector2(-7, -21) * k, mid + Vector2(-7, -11) * k, STRING_PALE, 1.6 * k)
			_figure(c, mid + Vector2(-7, -2) * k, 9.0 * k, HOUND_RED, 1.9 * k)
			c.draw_line(mid + Vector2(-16, 17) * k, mid + Vector2(2, 17) * k, Color(light, 0.7), 1.8 * k, true)
			_hourglass(c, mid + Vector2(11, 3) * k, 0.7 * k, STRING_PALE.darkened(0.2), light)
		# --- Shadow: down the middle column ---
		"shadow_deep_call":   # the open hole, a hand already reaching out of it, and the call cut short
			_ellipse(c, mid + Vector2(-4, 14) * k, Vector2(13, 4.5) * k, PIT, light, 1.4 * k)
			_claw(c, mid + Vector2(-4, 14) * k, Vector2(-0.15, -1).normalized(), 24.0 * k, col.lightened(0.15), WHITE, 2.0 * k)
			_clock(c, mid + Vector2(11, -10) * k, 7.5 * k, light, k)
			c.draw_arc(mid + Vector2(11, -10) * k, 4.5 * k, -PI * 0.5, PI * 0.1, 8, WHITE, 2.4 * k, true)
		"shadow_ill_will":   # a drop of something slow, and the spite flaring off it
			_drop(c, mid + Vector2(-3, 2) * k, 1.05 * k, Color(col, 0.9), light, k)
			for i in 8:
				var ray := Vector2(cos(TAU * i / 8.0 - PI * 0.25), sin(TAU * i / 8.0 - PI * 0.25))
				c.draw_line(mid + (Vector2(10, -11) + ray * 2.5) * k, mid + (Vector2(10, -11) + ray * (8.0 if i % 2 == 0 else 5.5)) * k,
					Color(1, 0.85, 0.2), 1.8 * k, true)
		"shadow_hard_pull":   # the thread yanked hard, the healing coming quicker and staying longer
			_hand(c, mid + Vector2(-8, -16) * k, 0.85 * k)
			c.draw_polyline(_p(mid, k, [Vector2(-8, -6), Vector2(-2, 0), Vector2(-6, 4), Vector2(0, 10)]), STRING_PALE, 1.8 * k, true)
			_figure(c, mid + Vector2(2, 11) * k, 6.0 * k, WHITE, 1.6 * k)
			for i in 2:
				c.draw_polyline(_p(mid, k, [Vector2(10, 2 - i * 8), Vector2(14, -3 - i * 8), Vector2(18, 2 - i * 8)]), HEAL_GREEN, 2.4 * k, true)
		"shadow_wide_pack":   # the Hound biting one, and the bite carrying on to those beside it
			_hound(c, mid + Vector2(0, -7) * k, 0.9 * k, light, 0.8)
			for sx: float in [-1.0, 1.0]:
				c.draw_arc(mid + Vector2(0, 2) * k, 14.0 * k, PI * 0.5 - sx * PI * 0.5 - PI * 0.12, PI * 0.5 - sx * PI * 0.5 + PI * 0.12, 8,
					HOUND_RED, 2.4 * k, true)
				_figure(c, mid + Vector2(14 * sx, 12) * k, 5.5 * k, WHITE, 1.4 * k)
			_figure(c, mid + Vector2(0, 14) * k, 5.5 * k, HOUND_RED, 1.6 * k)
		# --- Fire and Lightning: the open talents ---
		"fire_feed_the_flames":   # a blade driven into something already burning
			var flame := _p(mid + Vector2(-4, 3) * k, k, [Vector2(0, -15), Vector2(7, -4), Vector2(9, 6), Vector2(4, 13), Vector2(-4, 13),
				Vector2(-9, 6), Vector2(-7, -3), Vector2(-3, -6)])
			c.draw_colored_polygon(flame, Color(col, 0.85))
			flame.append(flame[0])
			c.draw_polyline(flame, light, 1.5 * k, true)
			c.draw_colored_polygon(_p(mid + Vector2(-4, 6) * k, k, [Vector2(0, -6), Vector2(4, 1), Vector2(0, 6), Vector2(-4, 1)]), WHITE)
			c.draw_line(mid + Vector2(17, -15) * k, mid + Vector2(3, 0) * k, Color(0.9, 0.92, 0.98), 2.4 * k, true)
			c.draw_line(mid + Vector2(11, -15) * k, mid + Vector2(17, -9) * k, WOOD, 2.2 * k, true)
		"fire_last_ember":   # a burn guttering out, and the one ember that still glows
			for i in 4:
				c.draw_circle(mid + Vector2(-14 + i * 6.5, 9 - i * 4.5) * k, (1.6 + i * 0.5) * k, Color(light, 0.35 + i * 0.15))
			c.draw_circle(mid + Vector2(10, -8) * k, 7.0 * k, Color(col, 0.9))
			c.draw_arc(mid + Vector2(10, -8) * k, 7.0 * k, 0, TAU, 20, light, 1.6 * k, true)
			c.draw_circle(mid + Vector2(10, -8) * k, 3.0 * k, WHITE)
		"fire_tempered":   # a shield, and the plates each blow has hammered onto it
			_shield(c, mid, k, Color(col, 0.55), light)
			for i in 3:
				c.draw_polyline(_p(mid, k, [Vector2(-6, -7 + i * 6), Vector2(0, -3 + i * 6), Vector2(6, -7 + i * 6)]), WHITE, 1.9 * k, true)
		"lightning_change_of_pace":   # two arrows turning into one another: never the same thing twice
			for i in 2:
				var a0 := PI * (0.2 + i)
				c.draw_arc(mid, 12.0 * k, a0, a0 + PI * 0.65, 12, WHITE if i == 0 else light, 2.2 * k, true)
				var tip_a := a0 + PI * 0.65
				var tip := mid + Vector2(cos(tip_a), sin(tip_a)) * 12.0 * k
				var along := Vector2(-sin(tip_a), cos(tip_a))
				var across := Vector2(cos(tip_a), sin(tip_a))
				c.draw_colored_polygon(PackedVector2Array([tip + along * 6.0 * k, tip + across * 4.0 * k, tip - across * 4.0 * k]),
					WHITE if i == 0 else light)
			c.draw_circle(mid, 2.4 * k, col)
		"lightning_spillover":   # a hit that bursts on one enemy and jumps on to the next
			c.draw_circle(mid + Vector2(-9, 6) * k, 6.5 * k, Color(col, 0.8))
			for i in 6:
				var a := TAU * i / 6.0
				c.draw_line(mid + Vector2(-9, 6) * k + Vector2(cos(a), sin(a)) * 7.5 * k,
					mid + Vector2(-9, 6) * k + Vector2(cos(a), sin(a)) * 10.5 * k, WHITE, 1.4 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(-4, 1), Vector2(3, -1), Vector2(1, -6), Vector2(9, -9)]), WHITE, 1.8 * k, true)
			c.draw_arc(mid + Vector2(12, -11) * k, 4.5 * k, 0, TAU, 14, light, 1.7 * k, true)
		"lightning_dig_in":   # someone planted on their spot, feet set, the ground holding them
			_figure(c, mid + Vector2(0, -2) * k, 13.0 * k, WHITE, 1.8 * k)
			c.draw_line(mid + Vector2(-16, 10) * k, mid + Vector2(16, 10) * k, light, 2.4 * k, true)
			for sx in [-1.0, 1.0]:
				c.draw_line(mid + Vector2(sx * 9, 10) * k, mid + Vector2(sx * 12, 16) * k, Color(light, 0.8), 1.8 * k, true)
				c.draw_line(mid + Vector2(sx * 3, 10) * k, mid + Vector2(sx * 4, 16) * k, Color(light, 0.8), 1.8 * k, true)
		# --- Arcane: the open talents ---
		"arcane_quick_study":   # an open book, its pages turning fast
			for sx in [-1.0, 1.0]:
				var page := _p(mid, k, [Vector2(0, -9), Vector2(sx * 15, -12), Vector2(sx * 15, 9), Vector2(0, 12)])
				c.draw_colored_polygon(page, Color(col, 0.55))
				page.append(page[0])
				c.draw_polyline(page, WHITE, 1.5 * k, true)
			for i in 3:
				c.draw_line(mid + Vector2(4, -5 + i * 5) * k, mid + Vector2(12, -6.5 + i * 5) * k, Color(light, 0.9), 1.3 * k, true)
			c.draw_arc(mid + Vector2(-2, -10) * k, 9.0 * k, PI * 1.15, PI * 1.75, 10, light, 1.6 * k, true)
		"arcane_two_minds":   # two heads, one lending to the other
			c.draw_circle(mid + Vector2(-7, 0) * k, 8.5 * k, Color(col, 0.7))
			c.draw_arc(mid + Vector2(-7, 0) * k, 8.5 * k, 0, TAU, 22, WHITE, 1.7 * k, true)
			c.draw_arc(mid + Vector2(7, 0) * k, 8.5 * k, 0, TAU, 22, light, 1.7 * k, true)
			c.draw_line(mid + Vector2(-4, 0) * k, mid + Vector2(7, 0) * k, WHITE, 1.6 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(10, 0), Vector2(5, -3.5), Vector2(5, 3.5)]), WHITE)
		"arcane_echo":   # a hit, and the same hit again, fainter
			for i in 3:
				var at := mid + Vector2(-9 + i * 9, 0) * k
				var shade := Color(WHITE, 1.0 - i * 0.35)
				c.draw_arc(at, (8.0 - i * 1.5) * k, -PI * 0.42, PI * 0.42, 10, shade, (2.4 - i * 0.5) * k, true)
			c.draw_circle(mid + Vector2(-13, 0) * k, 3.2 * k, WHITE)
		"arcane_mirror_finish":   # a blow that meets a mirror and comes straight back
			_pane(c, mid + Vector2(5, 0) * k, Vector2(7, 16) * k, Color(col, 0.6), WHITE, 1.8 * k)
			c.draw_line(mid + Vector2(-17, -6) * k, mid + Vector2(-1, -3) * k, Color(0.95, 0.45, 0.4), 2.2 * k, true)
			c.draw_line(mid + Vector2(-1, 3) * k, mid + Vector2(-17, 7) * k, light, 2.2 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-18, 7.5), Vector2(-12, 3), Vector2(-11, 9)]), light)
		"arcane_overtime":   # an hourglass turned over for a little more
			var sand := _p(mid + Vector2(-3, 0) * k, k, [Vector2(-8, -14), Vector2(8, -14), Vector2(0, 0), Vector2(8, 14), Vector2(-8, 14), Vector2(0, 0)])
			sand.append(sand[0])
			c.draw_polyline(sand, WHITE, 1.9 * k, true)
			c.draw_colored_polygon(_p(mid + Vector2(-3, 0) * k, k, [Vector2(-5, 13), Vector2(5, 13), Vector2(0, 5)]), Color(col, 0.95))
			c.draw_line(mid + Vector2(9, -8) * k, mid + Vector2(17, -8) * k, light, 2.2 * k, true)
			c.draw_line(mid + Vector2(13, -12) * k, mid + Vector2(13, -4) * k, light, 2.2 * k, true)
		"arcane_light_touch":   # a feather
			c.draw_line(mid + Vector2(-14, 15) * k, mid + Vector2(12, -13) * k, WHITE, 1.6 * k, true)
			var vane := _p(mid, k, [Vector2(-6, 7), Vector2(-9, -3), Vector2(2, -15), Vector2(13, -14), Vector2(12, -3), Vector2(3, 8)])
			c.draw_colored_polygon(vane, Color(col, 0.7))
			vane.append(vane[0])
			c.draw_polyline(vane, light, 1.4 * k, true)
			for i in 3:
				c.draw_line(mid + Vector2(-3 + i * 4, 3 - i * 4.3) * k, mid + Vector2(-7 + i * 4.5, -3 - i * 3.5) * k, Color(WHITE, 0.6), 1.0 * k, true)
		"arcane_slipstream":   # someone already gone, the air still streaming after them
			_figure(c, mid + Vector2(9, 1) * k, 13.0 * k, WHITE, 1.8 * k)
			for i in 4:
				var y := -11.0 + i * 7.0
				c.draw_line(mid + Vector2(-18, y) * k, mid + Vector2(1 - (i % 2) * 5, y) * k, Color(light, 0.85 - i * 0.12), 1.7 * k, true)
		"arcane_borrowed_time":   # a clock, and the spark it hands on to what comes next
			_clock(c, mid + Vector2(-5, 3) * k, 10.0 * k, light, k)
			c.draw_line(mid + Vector2(-5, 3) * k, mid + Vector2(-5, -4) * k, WHITE, 1.6 * k, true)
			c.draw_line(mid + Vector2(-5, 3) * k, mid + Vector2(0, 5) * k, WHITE, 1.6 * k, true)
			c.draw_arc(mid + Vector2(3, -3) * k, 12.0 * k, PI * 1.45, PI * 1.95, 10, WHITE, 1.6 * k, true)
			var spark := mid + Vector2(14, -6) * k
			for a in [0.0, PI / 4.0, PI / 2.0, PI * 0.75]:
				var d := Vector2(cos(a), sin(a)) * (5.0 if is_zero_approx(fmod(a, PI / 2.0)) else 3.0) * k
				c.draw_line(spark - d, spark + d, WHITE, 1.5 * k, true)
		"arcane_keep_moving":   # a glint of light, and two footprints going on under it
			for a in [0.0, PI / 4.0, PI / 2.0, PI * 0.75]:
				var d := Vector2(cos(a), sin(a)) * (9.0 if is_zero_approx(fmod(a, PI / 2.0)) else 4.5) * k
				c.draw_line(mid + Vector2(2, -7) * k - d, mid + Vector2(2, -7) * k + d, WHITE, 1.7 * k, true)
			for i in 2:
				var foot := mid + Vector2(-9 + i * 12, 11 - i * 3) * k
				c.draw_circle(foot, 3.0 * k, light)
				c.draw_circle(foot + Vector2(1.5, -5) * k, 1.8 * k, light)
		"arcane_full_crowd":   # a full row of images, shoulder to shoulder
			for i in 5:
				var at := mid + Vector2(-14 + i * 7, 3) * k
				var shade := WHITE if i == 2 else Color(light, 0.75)
				c.draw_circle(at + Vector2(0, -7) * k, 3.0 * k, shade)
				c.draw_colored_polygon(PackedVector2Array([at + Vector2(-3.2, -3) * k, at + Vector2(3.2, -3) * k,
					at + Vector2(2.4, 10) * k, at + Vector2(-2.4, 10) * k]), shade)
			c.draw_line(mid + Vector2(-17, 14) * k, mid + Vector2(17, 14) * k, Color(col, 0.9), 1.6 * k, true)
		# --- Arcane melee (Traces and Encore) ---
		"arcane_standing_ovation":   # three cuts, each bigger than the last, and the sparks of applause over them
			for i in 3:
				var at := mid + Vector2(-11 + i * 10, 6) * k
				var tall := 5.0 + i * 3.0
				c.draw_line(at + Vector2(-3, tall) * k, at + Vector2(3, -tall) * k, Color(light, 0.55 + i * 0.2), (1.8 + i * 0.5) * k, true)
			for p in [Vector2(-12, -10), Vector2(-2, -14), Vector2(8, -15)]:
				var star := mid + (p as Vector2) * k
				c.draw_line(star + Vector2(-2.5, 0) * k, star + Vector2(2.5, 0) * k, WHITE, 1.3 * k, true)
				c.draw_line(star + Vector2(0, -2.5) * k, star + Vector2(0, 2.5) * k, WHITE, 1.3 * k, true)
		"arcane_long_memory":   # a cut kept under an hourglass that still has sand to run
			c.draw_line(mid + Vector2(-17, 12) * k, mid + Vector2(-3, -12) * k, Color(light, 0.7), 2.2 * k, true)
			var glass := _p(mid + Vector2(7, 0) * k, k, [Vector2(-7, -13), Vector2(7, -13), Vector2(0, 0), Vector2(7, 13), Vector2(-7, 13), Vector2(0, 0)])
			glass.append(glass[0])
			c.draw_polyline(glass, WHITE, 1.8 * k, true)
			c.draw_colored_polygon(_p(mid + Vector2(7, 0) * k, k, [Vector2(-4.5, -9), Vector2(4.5, -9), Vector2(0, -1)]), Color(col, 0.9))
			c.draw_colored_polygon(_p(mid + Vector2(7, 0) * k, k, [Vector2(-3, 12), Vector2(3, 12), Vector2(0, 8)]), Color(col, 0.9))
		"arcane_clean_lines":   # a thin quick line running straight into a heavy one
			c.draw_line(mid + Vector2(-17, 8) * k, mid + Vector2(-1, -4) * k, WHITE, 1.5 * k, true)
			c.draw_line(mid + Vector2(-17, 13) * k, mid + Vector2(-5, 4) * k, Color(WHITE, 0.6), 1.2 * k, true)
			c.draw_line(mid + Vector2(-1, 12) * k, mid + Vector2(15, -14) * k, Color(col, 0.6), 6.0 * k, true)
			c.draw_line(mid + Vector2(0, 11) * k, mid + Vector2(14, -13) * k, light, 2.6 * k, true)
			c.draw_circle(mid + Vector2(-1, -4) * k, 2.4 * k, WHITE)
		"arcane_second_showing":   # a cut inside two arrows chasing each other round: once more
			c.draw_line(mid + Vector2(-5, 8) * k, mid + Vector2(5, -8) * k, WHITE, 2.4 * k, true)
			for i in 2:
				var a0 := PI * (0.15 + i)
				c.draw_arc(mid, 14.0 * k, a0, a0 + PI * 0.7, 12, light, 1.9 * k, true)
				var tip_a := a0 + PI * 0.7
				var tip := mid + Vector2(cos(tip_a), sin(tip_a)) * 14.0 * k
				var along := Vector2(-sin(tip_a), cos(tip_a))
				var across := Vector2(cos(tip_a), sin(tip_a))
				c.draw_colored_polygon(PackedVector2Array([tip + along * 5.0 * k, tip + across * 3.5 * k, tip - across * 3.5 * k]), light)
		"arcane_practiced_hand":   # a cut, and the tally of the ones before it
			c.draw_line(mid + Vector2(-2, 13) * k, mid + Vector2(14, -14) * k, Color(col, 0.6), 5.0 * k, true)
			c.draw_line(mid + Vector2(-1, 12) * k, mid + Vector2(13, -13) * k, WHITE, 2.2 * k, true)
			for i in 3:
				c.draw_line(mid + Vector2(-16 + i * 4.5, -4) * k, mid + Vector2(-16 + i * 4.5, 8) * k, light, 1.8 * k, true)
			c.draw_line(mid + Vector2(-18, 6) * k, mid + Vector2(-5, -2) * k, light, 1.6 * k, true)
		"arcane_heavy_hand":   # a deep cut, pressed deeper by the weight coming down on it
			c.draw_colored_polygon(_p(mid, k, [Vector2(-15, 14), Vector2(-3, 2), Vector2(15, 4), Vector2(-1, 9)]), Color(col, 0.8))
			c.draw_polyline(_p(mid, k, [Vector2(-15, 14), Vector2(-3, 2), Vector2(15, 4), Vector2(-1, 9), Vector2(-15, 14)]),
				light, 1.5 * k, true)
			c.draw_rect(Rect2(mid + Vector2(-5, -16) * k, Vector2(10, 9) * k), WHITE, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-8, -7), Vector2(8, -7), Vector2(0, 1)]), WHITE)
		"arcane_curtain_call":   # the curtains drawn back, and the last cut between them
			for sx in [-1.0, 1.0]:
				var drape := _p(mid, k, [Vector2(sx * 17, -15), Vector2(sx * 5, -15), Vector2(sx * 9, -2),
					Vector2(sx * 12, 14), Vector2(sx * 17, 14)])
				c.draw_colored_polygon(drape, Color(col, 0.75))
				drape.append(drape[0])
				c.draw_polyline(drape, light, 1.4 * k, true)
			c.draw_line(mid + Vector2(-17, -15) * k, mid + Vector2(17, -15) * k, WHITE, 2.0 * k, true)
			c.draw_line(mid + Vector2(-3, 10) * k, mid + Vector2(3, -6) * k, WHITE, 2.2 * k, true)
		"arcane_no_loose_ends":   # a cut whose loose end is tied off in a knot
			c.draw_line(mid + Vector2(-16, 12) * k, mid + Vector2(2, -4) * k, WHITE, 2.2 * k, true)
			c.draw_arc(mid + Vector2(7, -8) * k, 6.5 * k, 0, TAU, 20, light, 2.0 * k, true)
			c.draw_line(mid + Vector2(2, -4) * k, mid + Vector2(12, -13) * k, WHITE, 2.2 * k, true)
			c.draw_circle(mid + Vector2(13, -14) * k, 2.2 * k, WHITE)
		"arcane_time_signature":   # the lines of a score, and a clock keeping the count on them
			for i in 4:
				c.draw_line(mid + Vector2(-17, -9 + i * 6) * k, mid + Vector2(17, -9 + i * 6) * k, Color(light, 0.55), 1.2 * k, true)
			c.draw_line(mid + Vector2(-9, -13) * k, mid + Vector2(-9, 13) * k, Color(light, 0.8), 1.6 * k, true)
			c.draw_circle(mid + Vector2(5, 0) * k, 8.0 * k, Color(0.08, 0.05, 0.14))
			_clock(c, mid + Vector2(5, 0) * k, 7.5 * k, WHITE, k)
			c.draw_line(mid + Vector2(5, 0) * k, mid + Vector2(5, -5.5) * k, WHITE, 1.5 * k, true)
			c.draw_line(mid + Vector2(5, 0) * k, mid + Vector2(9, 1.5) * k, WHITE, 1.5 * k, true)
		"arcane_full_house":   # a house, and the three inside it
			c.draw_polyline(_p(mid, k, [Vector2(-15, 15), Vector2(-15, -3), Vector2(0, -16), Vector2(15, -3), Vector2(15, 15),
				Vector2(-15, 15)]), light, 1.9 * k, true)
			for i in 3:
				var at := mid + Vector2(-8 + i * 8, 7) * k
				c.draw_circle(at + Vector2(0, -5) * k, 2.6 * k, WHITE)
				c.draw_line(at + Vector2(0, -2) * k, at + Vector2(0, 5) * k, WHITE, 2.0 * k, true)
		"arcane_dress_rehearsal":   # a figure alone in the spotlight
			c.draw_colored_polygon(_p(mid, k, [Vector2(-3, -17), Vector2(3, -17), Vector2(13, 15), Vector2(-13, 15)]), Color(light, 0.3))
			_figure(c, mid + Vector2(0, 3) * k, 13.0 * k, WHITE, 1.8 * k)
			c.draw_line(mid + Vector2(-16, 15) * k, mid + Vector2(16, 15) * k, col, 2.2 * k, true)
		"arcane_silvered":   # a pane of silvered glass that mends whoever looks into it
			_pane(c, mid + Vector2(-3, 0) * k, Vector2(9, 16) * k, Color(0.75, 0.78, 0.86, 0.85), WHITE, 1.8 * k)
			c.draw_line(mid + Vector2(-7, 3) * k, mid + Vector2(-1, -8) * k, Color(WHITE, 0.9), 1.6 * k, true)
			var mend := Color(0.45, 1.0, 0.5)
			c.draw_line(mid + Vector2(7, 8) * k, mid + Vector2(17, 8) * k, mend, 3.0 * k, true)
			c.draw_line(mid + Vector2(12, 3) * k, mid + Vector2(12, 13) * k, mend, 3.0 * k, true)
		"arcane_running_clock":   # a clock in a hurry, the wind of it streaming out behind
			_clock(c, mid + Vector2(5, 0) * k, 11.0 * k, light, k)
			c.draw_line(mid + Vector2(5, 0) * k, mid + Vector2(5, -8) * k, WHITE, 1.7 * k, true)
			c.draw_line(mid + Vector2(5, 0) * k, mid + Vector2(11, 2) * k, WHITE, 1.7 * k, true)
			for i in 3:
				var y := -8.0 + i * 8.0
				c.draw_line(mid + Vector2(-18, y) * k, mid + Vector2(-10 + (2 if i == 1 else 0), y) * k, Color(WHITE, 0.75), 1.6 * k, true)
		"arcane_fine_edge":   # one long, thin blade, and the gleam on its edge
			c.draw_line(mid + Vector2(-13, 12) * k, mid + Vector2(15, -15) * k, Color(col, 0.55), 5.0 * k, true)
			c.draw_line(mid + Vector2(-12, 11) * k, mid + Vector2(15, -15) * k, Color(0.9, 0.92, 0.98), 2.2 * k, true)
			c.draw_line(mid + Vector2(-15, 7) * k, mid + Vector2(-8, 14) * k, light, 2.2 * k, true)
			c.draw_line(mid + Vector2(-12, 11) * k, mid + Vector2(-17, 16) * k, WOOD, 3.0 * k, true)
			var gleam := mid + Vector2(7, -3) * k
			c.draw_line(gleam + Vector2(-5, 0) * k, gleam + Vector2(5, 0) * k, WHITE, 1.5 * k, true)
			c.draw_line(gleam + Vector2(0, -5) * k, gleam + Vector2(0, 5) * k, WHITE, 1.5 * k, true)
		# --- The Arcane tank (Reflections) ---
		"arcane_sharp_edges":   # a pane of glass flying apart into three sharp shards
			for d in [Vector2(0, -1), Vector2(0.87, 0.5), Vector2(-0.87, 0.5)]:
				_shard(c, mid + (d as Vector2) * 17.0 * k, d, 13.0 * k, 4.5 * k, Color(col, 0.8), WHITE, k)
			c.draw_circle(mid, 2.5 * k, WHITE)
		"arcane_clockwork":   # a clock face, and the shard of glass that winds it on
			_clock(c, mid + Vector2(-3, 3) * k, 12.0 * k, light, k)
			c.draw_line(mid + Vector2(-3, 3) * k, mid + Vector2(-3, -5) * k, WHITE, 1.6 * k, true)
			c.draw_line(mid + Vector2(-3, 3) * k, mid + Vector2(3, 6) * k, WHITE, 1.6 * k, true)
			_shard(c, mid + Vector2(17, -16) * k, Vector2(1, -1).normalized(), 10.0 * k, 3.6 * k, Color(col, 0.9), WHITE, k)
		"arcane_spare_copy":   # a pane of glass, and a second one kept behind it
			_pane(c, mid + Vector2(5, -2) * k, Vector2(8, 14) * k, Color(col, 0.3), Color(light, 0.6), 1.4 * k)
			_pane(c, mid + Vector2(-4, 2) * k, Vector2(8, 14) * k, Color(col, 0.7), WHITE, 1.8 * k)
			c.draw_line(mid + Vector2(10, 12) * k, mid + Vector2(17, 12) * k, WHITE, 1.8 * k, true)
			c.draw_line(mid + Vector2(13.5, 8.5) * k, mid + Vector2(13.5, 15.5) * k, WHITE, 1.8 * k, true)
		"arcane_second_self":   # one blow, two figures
			_figure(c, mid + Vector2(-8, 2) * k, 15.0 * k, WHITE, 1.8 * k)
			_figure(c, mid + Vector2(8, 2) * k, 15.0 * k, light, 1.8 * k)
			c.draw_arc(mid + Vector2(0, -8) * k, 8.0 * k, PI * 1.1, PI * 1.9, 12, col, 1.6 * k, true)
		"arcane_wide_rings":   # a ripple spreading out to both sides
			c.draw_circle(mid, 2.6 * k, WHITE)
			for i in 3:
				var r := (7.0 + i * 5.0) * k
				var shade := Color(light, 0.95 - i * 0.25)
				c.draw_arc(mid, r, -0.9, 0.9, 12, shade, 1.9 * k, true)
				c.draw_arc(mid, r, PI - 0.9, PI + 0.9, 12, shade, 1.9 * k, true)
		"arcane_on_the_beat":   # a beat line, struck right on its peak
			c.draw_polyline(_p(mid, k, [Vector2(-17, 5), Vector2(-7, 5), Vector2(-3, -13), Vector2(2, 11), Vector2(6, 5), Vector2(17, 5)]),
				light, 2.0 * k, true)
			c.draw_circle(mid + Vector2(-3, -13) * k, 3.0 * k, WHITE)
			for i in 4:
				c.draw_circle(mid + Vector2(-12 + i * 8, 15) * k, 1.3 * k, Color(light, 0.7))
		"arcane_head_count":   # four heads in a row, and the health each one brings
			for i in 4:
				var at := mid + Vector2(-13.5 + i * 9.0, 5) * k
				c.draw_circle(at, 3.4 * k, col)
				c.draw_arc(at, 3.4 * k, 0, TAU, 12, WHITE, 1.2 * k, true)
				c.draw_arc(at + Vector2(0, 10) * k, 5.0 * k, PI * 1.15, PI * 1.85, 8, light, 1.4 * k, true)
			var mend := Color(0.45, 1.0, 0.5)
			c.draw_line(mid + Vector2(-6, -10) * k, mid + Vector2(6, -10) * k, mend, 3.0 * k, true)
			c.draw_line(mid + Vector2(0, -16) * k, mid + Vector2(0, -4) * k, mend, 3.0 * k, true)
		"arcane_light_feet":   # two crossed blades, and quick steps under them
			for sx in [-1.0, 1.0]:
				c.draw_line(mid + Vector2(sx * -12, -15) * k, mid + Vector2(sx * 7, 4) * k, WHITE, 2.2 * k, true)
				c.draw_line(mid + Vector2(sx * 2.2, 4.8) * k, mid + Vector2(sx * 7.8, -0.8) * k, light, 2.0 * k, true)
				c.draw_line(mid + Vector2(sx * 7, 4) * k, mid + Vector2(sx * 11, 8) * k, WOOD, 2.8 * k, true)
			for i in 3:
				c.draw_line(mid + Vector2(-11 + i * 8, 15) * k, mid + Vector2(-5 + i * 8, 15) * k, Color(light, 0.8), 1.6 * k, true)
		"arcane_empty_room":   # the empty frame where the images stood, and the guard that holds in it
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var corner := mid + Vector2(sx * 16, sy * 16) * k
					c.draw_line(corner, corner + Vector2(-sx * 7, 0) * k, Color(light, 0.75), 1.6 * k, true)
					c.draw_line(corner, corner + Vector2(0, -sy * 7) * k, Color(light, 0.75), 1.6 * k, true)
			_shield(c, mid, k * 0.75, Color(col, 0.6), WHITE)
		"arcane_bent_light":   # a ray meets a pane of glass and leaves it bent and weaker
			_pane(c, mid, Vector2(7, 15) * k, Color(col, 0.6), WHITE, 1.8 * k)
			c.draw_line(mid + Vector2(-18, -10) * k, mid + Vector2(-4, -3) * k, Color(1.0, 0.75, 0.35), 2.6 * k, true)
			c.draw_line(mid + Vector2(-4, -3) * k, mid + Vector2(4, -1) * k, Color(WHITE, 0.6), 1.2 * k, true)
			c.draw_line(mid + Vector2(4, -1) * k, mid + Vector2(18, -12) * k, Color(light, 0.75), 1.4 * k, true)
		"arcane_understudy":   # the one who steps in, its guard, and the clock running for it
			_figure(c, mid + Vector2(-6, 1) * k, 15.0 * k, WHITE, 1.8 * k)
			_shield(c, mid + Vector2(9, -6) * k, k * 0.5, Color(col, 0.7), WHITE)
			_clock(c, mid + Vector2(9, 11) * k, 5.5 * k, light, k * 0.7)
			c.draw_line(mid + Vector2(9, 11) * k, mid + Vector2(9, 7.5) * k, WHITE, 1.2 * k, true)
			c.draw_line(mid + Vector2(9, 11) * k, mid + Vector2(11.5, 12) * k, WHITE, 1.2 * k, true)
		"arcane_loud_exit":   # a pane of glass bursting into its four quarters
			for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var at := mid + (d as Vector2) * 3.5 * k
				var piece := PackedVector2Array([at, at + Vector2(0, d.y * 13) * k, at + Vector2(d.x * 8, 0) * k])
				c.draw_colored_polygon(piece, Color(col, 0.75))
				piece.append(piece[0])
				c.draw_polyline(piece, WHITE, 1.3 * k, true)
				var out := (d as Vector2).normalized()
				c.draw_line(mid + out * 14.0 * k, mid + out * 19.0 * k, Color(light, 0.9), 1.5 * k, true)
		"arcane_good_likeness":   # an image of me in a ring, and everything turning to look at it
			c.draw_arc(mid, 17.0 * k, 0, TAU, 28, Color(col, 0.6), 1.4 * k, true)
			_figure(c, mid + Vector2(0, 1) * k, 14.0 * k, light, 1.8 * k)
			for sx in [-1.0, 1.0]:
				c.draw_colored_polygon(PackedVector2Array([mid + Vector2(sx * 8, 0) * k, mid + Vector2(sx * 14, -4) * k,
					mid + Vector2(sx * 14, 4) * k]), WHITE)
		"arcane_seventh_sigil":   # six darts in a ring and a seventh, brighter, joining them
			for i in 7:
				var a := -PI / 2.0 + TAU * i / 7.0
				var at := mid + Vector2(cos(a), sin(a)) * 12.0 * k
				if i == 0:
					c.draw_circle(at, 4.6 * k, WHITE)
					c.draw_line(at + Vector2(-7, 0) * k, at + Vector2(7, 0) * k, WHITE, 1.4 * k, true)
					c.draw_line(at + Vector2(0, -6) * k, at + Vector2(0, 7) * k, WHITE, 1.4 * k, true)
				else:
					c.draw_circle(at, 3.0 * k, Color(light, 0.75))
			c.draw_arc(mid, 12.0 * k, 0, TAU, 28, Color(col, 0.5), 1.2 * k, true)
		"arcane_long_step":   # the spot I left, a long dotted jump, and where I land
			c.draw_arc(mid + Vector2(-13, 6) * k, 5.0 * k, 0, TAU, 16, Color(light, 0.55), 1.6 * k, true)
			for i in 4:
				c.draw_circle(mid + Vector2(-6 + i * 4.5, 4.0 - i * 2.4) * k, 1.3 * k, Color(light, 0.8))
			c.draw_circle(mid + Vector2(13, -7) * k, 5.0 * k, col)
			c.draw_arc(mid + Vector2(13, -7) * k, 5.0 * k, 0, TAU, 16, WHITE, 1.6 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(4, -13), Vector2(13, -15), Vector2(10, -6)]), WHITE, 1.4 * k, true)
		"arcane_frayed":   # a thread coming apart into loose strands
			c.draw_line(mid + Vector2(-16, 12) * k, mid + Vector2(-2, -1) * k, light, 3.4 * k, true)
			for p in [Vector2(4, -15), Vector2(12, -9), Vector2(15, 1), Vector2(8, 7)]:
				c.draw_polyline(_p(mid, k, [Vector2(-2, -1), (Vector2(-2, -1) + (p as Vector2)) * 0.5 + Vector2(2, 2), p]),
					Color(WHITE, 0.9), 1.4 * k, true)
		"arcane_etched_darts":   # a dart with a clock face cut into it
			_shard(c, mid + Vector2(14, -14) * k, Vector2(1, -1).normalized(), 24.0 * k, 5.0 * k, Color(col, 0.8), WHITE, k)
			c.draw_circle(mid + Vector2(-7, 8) * k, 7.5 * k, Color(0.08, 0.05, 0.14))
			_clock(c, mid + Vector2(-7, 8) * k, 7.0 * k, light, k)
			c.draw_line(mid + Vector2(-7, 8) * k, mid + Vector2(-7, 3) * k, WHITE, 1.4 * k, true)
			c.draw_line(mid + Vector2(-7, 8) * k, mid + Vector2(-3, 9) * k, WHITE, 1.4 * k, true)
		"arcane_chain_reaction":   # one burst setting off three more
			for p in [Vector2(-12, 9), Vector2(12, 8), Vector2(1, -13)]:
				c.draw_line(mid, mid + (p as Vector2) * k, Color(light, 0.6), 1.4 * k, true)
				c.draw_circle(mid + (p as Vector2) * k, 4.2 * k, col)
				c.draw_arc(mid + (p as Vector2) * k, 4.2 * k, 0, TAU, 14, WHITE, 1.2 * k, true)
			for i in 8:
				var a := TAU * i / 8.0
				c.draw_line(mid + Vector2(cos(a), sin(a)) * 3.0 * k, mid + Vector2(cos(a), sin(a)) * 7.0 * k, WHITE, 1.5 * k, true)
			c.draw_circle(mid, 3.0 * k, WHITE)
		"arcane_polished_glass":   # a mirror with a gleam running across it
			var glass := _p(mid, k, [Vector2(0, -16), Vector2(11, 0), Vector2(0, 16), Vector2(-11, 0)])
			c.draw_colored_polygon(glass, Color(col, 0.6))
			glass.append(glass[0])
			c.draw_polyline(glass, WHITE, 1.8 * k, true)
			c.draw_line(mid + Vector2(-5, 2) * k, mid + Vector2(2, -9) * k, Color(WHITE, 0.9), 2.2 * k, true)
			c.draw_line(mid + Vector2(-1, 6) * k, mid + Vector2(5, -3) * k, Color(WHITE, 0.55), 1.4 * k, true)
			for p in [Vector2(14, -12), Vector2(-14, 11)]:
				var at := mid + (p as Vector2) * k
				c.draw_line(at + Vector2(-3, 0) * k, at + Vector2(3, 0) * k, light, 1.4 * k, true)
				c.draw_line(at + Vector2(0, -3) * k, at + Vector2(0, 3) * k, light, 1.4 * k, true)
		"arcane_deep_well":   # rings falling away into a dark middle
			for i in 3:
				var r := (15.0 - i * 4.5) * k
				c.draw_arc(mid, r, 0, TAU, 28, Color(light, 0.45 + i * 0.25), 1.8 * k, true)
			c.draw_circle(mid, 4.0 * k, Color(0.05, 0.03, 0.1))
			for a in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
				var d := Vector2(cos(a), sin(a))
				var side := Vector2(-d.y, d.x)
				c.draw_colored_polygon(PackedVector2Array([mid + d * 9.0 * k, mid + d * 15.0 * k + side * 3.0 * k,
					mid + d * 15.0 * k - side * 3.0 * k]), WHITE)
		"arcane_aftershock":   # cracked ground, and the tremor still spreading
			c.draw_polyline(_p(mid, k, [Vector2(-15, 6), Vector2(-7, 2), Vector2(-3, 8), Vector2(4, 1), Vector2(9, 7), Vector2(15, 3)]),
				WHITE, 2.0 * k, true)
			c.draw_line(mid + Vector2(-3, 8) * k, mid + Vector2(-5, 14) * k, Color(WHITE, 0.7), 1.4 * k, true)
			c.draw_line(mid + Vector2(4, 1) * k, mid + Vector2(6, -4) * k, Color(WHITE, 0.7), 1.4 * k, true)
			for i in 3:
				c.draw_arc(mid + Vector2(0, 4) * k, (8.0 + i * 5.0) * k, PI * 1.15, PI * 1.85, 12, Color(light, 0.85 - i * 0.25), 1.6 * k, true)
		"lightning_snap_shot":   # the flash I blinked out of, and an arrow already leaving it
			c.draw_arc(mid + Vector2(-8, 8) * k, 8.0 * k, 0, TAU, 20, Color(light, 0.5), 1.8 * k, true)
			for a in [PI * 0.75, PI * 1.25, PI * 0.25]:
				var d := Vector2(cos(a), sin(a))
				c.draw_line(mid + (Vector2(-8, 8) + d * 10.0) * k, mid + (Vector2(-8, 8) + d * 14.0) * k, Color(light, 0.8), 1.6 * k, true)
			c.draw_line(mid + Vector2(-8, 8) * k, mid + Vector2(10, -10) * k, WOOD, 2.6 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(17, -17), Vector2(6, -13), Vector2(13, -6)]), WHITE)
			c.draw_line(mid + Vector2(-8, 8) * k, mid + Vector2(-13, 6) * k, light, 2.0 * k, true)
			c.draw_line(mid + Vector2(-8, 8) * k, mid + Vector2(-6, 13) * k, light, 2.0 * k, true)
		"lightning_rod":   # an arrow stuck upright in its target, a bolt coming down it and arcing off both sides
			c.draw_line(mid + Vector2(-13, 14) * k, mid + Vector2(13, 14) * k, col.darkened(0.2), 3.0 * k, true)
			c.draw_line(mid + Vector2(0, 14) * k, mid + Vector2(0, -8) * k, WOOD, 2.6 * k, true)
			for x in [-1.0, 1.0]:
				c.draw_line(mid + Vector2(0, -6) * k, mid + Vector2(5 * x, -12) * k, light, 2.0 * k, true)
				c.draw_line(mid + Vector2(0, -2) * k, mid + Vector2(5 * x, -8) * k, light, 2.0 * k, true)
				c.draw_polyline(_p(mid, k, [Vector2(2 * x, 6), Vector2(8 * x, 2), Vector2(10 * x, 8), Vector2(17 * x, 5)]), WHITE, 2.0 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(-3, -17), Vector2(2, -13), Vector2(-2, -10), Vector2(0, -7)]), WHITE, 2.2 * k, true)
		"lightning_loaded_quiver":   # a quiver with two charged arrows standing ready in it
			c.draw_colored_polygon(_p(mid, k, [Vector2(-9, -2), Vector2(7, -2), Vector2(4, 16), Vector2(-6, 16)]), col.darkened(0.35))
			c.draw_polyline(_p(mid, k, [Vector2(-9, -2), Vector2(7, -2), Vector2(4, 16), Vector2(-6, 16), Vector2(-9, -2)]), light, 1.8 * k, true)
			c.draw_line(mid + Vector2(-8, 4) * k, mid + Vector2(6, 4) * k, light, 1.6 * k, true)
			for x in [-5.0, 3.0]:
				c.draw_line(mid + Vector2(x, -2) * k, mid + Vector2(x, -12) * k, WOOD, 2.2 * k, true)
				c.draw_colored_polygon(_p(mid, k, [Vector2(x, -18), Vector2(x - 3.5, -11), Vector2(x + 3.5, -11)]), WHITE)
			c.draw_colored_polygon(_p(mid, k, [Vector2(16, -9), Vector2(10, 0), Vector2(13, 0), Vector2(11, 8), Vector2(18, -3), Vector2(15, -3)]), WHITE)
		"lightning_live_current":   # a current running fast along a wire, chevrons hurrying it on
			var wave := PackedVector2Array()
			for i in 17:
				wave.append(mid + Vector2(-17 + i * 2.1, -6 + sin(i * 0.8) * 6.0) * k)
			c.draw_polyline(wave, light, 2.6 * k, true)
			for i in 3:
				c.draw_polyline(_p(mid, k, [Vector2(-10 + i * 9, 6), Vector2(-4 + i * 9, 11), Vector2(-10 + i * 9, 16)]),
					Color(WHITE, 0.5 + i * 0.25), 2.4 * k, true)
		"lightning_charged_strikes":   # a blade swinging, and the cell it tops up
			c.draw_arc(mid + Vector2(-14, 14) * k, 24.0 * k, -PI * 0.5, -PI * 0.12, 12, Color(light, 0.6), 1.8 * k, true)
			c.draw_line(mid + Vector2(-12, 12) * k, mid + Vector2(6, -14) * k, Color(0.92, 0.92, 0.96), 3.2 * k, true)
			c.draw_line(mid + Vector2(-16, 7) * k, mid + Vector2(-7, 13) * k, col, 3.0 * k, true)
			c.draw_line(mid + Vector2(-12, 12) * k, mid + Vector2(-16, 17) * k, WOOD, 3.6 * k, true)
			c.draw_rect(Rect2(mid + Vector2(7, 0) * k, Vector2(10, 16) * k), col.darkened(0.4), true)
			c.draw_rect(Rect2(mid + Vector2(7, 0) * k, Vector2(10, 16) * k), light, false, 1.6 * k)
			c.draw_rect(Rect2(mid + Vector2(10, -3) * k, Vector2(4, 3) * k), light, true)
			c.draw_line(mid + Vector2(9, 8) * k, mid + Vector2(15, 8) * k, WHITE, 2.0 * k, true)
			c.draw_line(mid + Vector2(12, 5) * k, mid + Vector2(12, 11) * k, WHITE, 2.0 * k, true)
		"lightning_storm_tempered":   # a storm cloud, and its bolt running down into an upright blade
			for v in [Vector2(-7, -11), Vector2(0, -14), Vector2(7, -11)]:
				c.draw_circle(mid + v * k, 5.5 * k, col.lightened(0.15))
			c.draw_rect(Rect2(mid + Vector2(-9, -11) * k, Vector2(18, 5) * k), col.lightened(0.15), true)
			c.draw_polyline(_p(mid, k, [Vector2(-1, -6), Vector2(-5, 0), Vector2(-1, 0), Vector2(-4, 5)]), WHITE, 2.2 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(4, -4), Vector2(8, 0), Vector2(8, 11), Vector2(0, 11), Vector2(0, 0)]), Color(0.92, 0.92, 0.96))
			c.draw_line(mid + Vector2(-4, 11) * k, mid + Vector2(12, 11) * k, light, 2.8 * k, true)
			c.draw_line(mid + Vector2(4, 11) * k, mid + Vector2(4, 17) * k, WOOD, 3.4 * k, true)
		"lightning_quick_step":   # a foot already gone: its faded print behind, the blow passing through it
			for i in 2:
				var at := mid + Vector2(-9 + i * 13, 5 - i * 8) * k
				var tone := Color(light, 0.35) if i == 0 else WHITE
				var sole := PackedVector2Array()
				for j in 14:
					var a := TAU * j / 14.0
					sole.append(at + Vector2(cos(a) * 5.0, sin(a) * 8.5) * k)
				c.draw_colored_polygon(sole, tone)
				c.draw_circle(at + Vector2(0, -11.5) * k, 2.4 * k, tone)
			c.draw_line(mid + Vector2(-17, -13) * k, mid + Vector2(-3, -13) * k, Color(1.0, 0.4, 0.3), 2.0 * k, true)
			for i in 2:
				c.draw_line(mid + Vector2(-17, 14 + i * 4) * k, mid + Vector2(-6 + i * 4, 14 + i * 4) * k, Color(light, 0.7), 1.6 * k, true)
		"lightning_calm_current":   # a bolt kept inside a ring, still water under it
			c.draw_arc(mid + Vector2(0, -3) * k, 12.0 * k, 0, TAU, 28, light, 2.2 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(3, -11), Vector2(-5, -2), Vector2(-1, -2), Vector2(-4, 6), Vector2(6, -5), Vector2(1, -5)]), WHITE)
			for i in 2:
				c.draw_line(mid + Vector2(-13 + i * 4, 13 + i * 4) * k, mid + Vector2(13 - i * 4, 13 + i * 4) * k, Color(light, 0.85 - i * 0.3), 2.0 * k, true)
		"lightning_overflow":   # a full cell, the charge spilling over its top into a shield
			c.draw_rect(Rect2(mid + Vector2(-16, -4) * k, Vector2(12, 20) * k), light, true)
			c.draw_rect(Rect2(mid + Vector2(-16, -4) * k, Vector2(12, 20) * k), WHITE, false, 1.6 * k)
			c.draw_rect(Rect2(mid + Vector2(-12, -7) * k, Vector2(4, 3) * k), WHITE, true)
			c.draw_arc(mid + Vector2(-4, -6) * k, 8.0 * k, PI, TAU, 10, WHITE, 2.2 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(4, -9), Vector2(1, -4), Vector2(7, -4)]), WHITE)
			var ward := _p(mid, k, [Vector2(9, -2), Vector2(17, 1), Vector2(16, 10), Vector2(9, 16), Vector2(2, 10), Vector2(1, 1)])
			c.draw_colored_polygon(ward, col.darkened(0.3))
			ward.append(ward[0])
			c.draw_polyline(ward, light, 1.8 * k, true)
		"lightning_parting_spark":   # the spot I left, sparks bursting out of it, and me already away
			c.draw_arc(mid + Vector2(-6, 4) * k, 10.0 * k, 0, TAU, 24, Color(light, 0.55), 1.8 * k, true)
			for i in 8:
				var a := TAU * i / 8.0 + 0.2
				var d := Vector2(cos(a), sin(a))
				c.draw_line(mid + (Vector2(-6, 4) + d * 2.5) * k, mid + (Vector2(-6, 4) + d * (7.0 if i % 2 == 0 else 5.0)) * k, WHITE, 1.8 * k, true)
			c.draw_line(mid + Vector2(3, -8) * k, mid + Vector2(13, -13) * k, light, 2.2 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(18, -16), Vector2(9, -15), Vector2(14, -8)]), light)
		"lightning_hot_wire":   # twin wires, one glowing hot, and the charge pip that stays lit
			c.draw_line(mid + Vector2(-17, -9) * k, mid + Vector2(17, -9) * k, Color(light, 0.6), 2.4 * k, true)
			c.draw_line(mid + Vector2(-17, 0) * k, mid + Vector2(17, 0) * k, Color(1.0, 0.5, 0.25), 5.0 * k, true)
			c.draw_line(mid + Vector2(-17, 0) * k, mid + Vector2(17, 0) * k, WHITE, 2.0 * k, true)
			for i in 4:
				var pip := mid + Vector2(-12 + i * 8, 12) * k
				c.draw_circle(pip, 3.2 * k, WHITE if i < 3 else col.darkened(0.3))
				c.draw_arc(pip, 3.2 * k, 0, TAU, 12, light, 1.2 * k, true)
		"lightning_second_stroke":   # the answer, and the same answer again right behind it
			for i in 2:
				var off := Vector2(-5 + i * 9, -3 + i * 5) * k
				var tone := Color(light, 0.55) if i == 0 else WHITE
				c.draw_arc(mid + off + Vector2(-6, 8) * k, 17.0 * k, -PI * 0.55, -PI * 0.05, 12, tone, (2.2 + i * 1.2) * k, true)
			c.draw_line(mid + Vector2(-16, -12) * k, mid + Vector2(-8, -12) * k, Color(1.0, 0.4, 0.3), 2.0 * k, true)
			for i in 2:
				c.draw_circle(mid + Vector2(-14 + i * 7, 14) * k, 2.6 * k, WHITE)
		"lightning_long_reach":   # a long two-handed blade, and the arc its point sweeps
			c.draw_arc(mid + Vector2(-10, 10) * k, 22.0 * k, -PI * 0.5, 0.0, 14, Color(light, 0.7), 1.8 * k, true)
			c.draw_line(mid + Vector2(-9, 9) * k, mid + Vector2(15, -15) * k, Color(light, 0.5), 6.0 * k, true)
			c.draw_line(mid + Vector2(-9, 9) * k, mid + Vector2(15, -15) * k, Color(0.92, 0.92, 0.96), 3.0 * k, true)
			c.draw_line(mid + Vector2(-14, 4) * k, mid + Vector2(-4, 14) * k, col, 3.0 * k, true)
			c.draw_line(mid + Vector2(-9, 9) * k, mid + Vector2(-16, 16) * k, WOOD, 4.0 * k, true)
		"lightning_counter_charge":   # the blow that came in, and a far fatter bolt going back
			c.draw_line(mid + Vector2(16, -11) * k, mid + Vector2(-4, -11) * k, Color(1.0, 0.4, 0.3), 2.0 * k, true)
			c.draw_arc(mid + Vector2(-5, -3) * k, 8.0 * k, PI * 0.5, PI * 1.5, 10, light, 2.2 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(-5, 5), Vector2(0, 2), Vector2(3, 10), Vector2(9, 6)]), WHITE, 4.5 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(18, 5), Vector2(8, -2), Vector2(9, 13)]), WHITE)
		"lightning_closed_circuit":   # a loop of wire closed on itself, charge running round it
			c.draw_arc(mid, 13.0 * k, 0, TAU, 28, light, 2.6 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(3, -9), Vector2(-5, 1), Vector2(-1, 1), Vector2(-4, 10), Vector2(6, -2), Vector2(1, -2)]), WHITE)
			for a in [0.4, 2.5, 4.6]:
				c.draw_circle(mid + Vector2(cos(a), sin(a)) * 13.0 * k, 2.8 * k, WHITE)
		"lightning_quick_wrists":   # a clock running down behind a blade held on guard
			_clock(c, mid + Vector2(3, -4) * k, 11.0 * k, light, k)
			c.draw_line(mid + Vector2(3, -4) * k, mid + Vector2(3, -11) * k, WHITE, 2.0 * k, true)
			c.draw_line(mid + Vector2(3, -4) * k, mid + Vector2(-2, -1) * k, WHITE, 2.0 * k, true)
			c.draw_line(mid + Vector2(-11, 14) * k, mid + Vector2(17, 11) * k, Color(0.92, 0.92, 0.96), 3.2 * k, true)
			c.draw_line(mid + Vector2(-11, 9) * k, mid + Vector2(-10, 19) * k, col, 2.8 * k, true)
			c.draw_line(mid + Vector2(-12, 14) * k, mid + Vector2(-18, 15) * k, WOOD, 3.4 * k, true)
		"lightning_quick_fuse":   # a bolt already on its way down, speed lines behind it
			c.draw_colored_polygon(_p(mid, k, [Vector2(6, -16), Vector2(-2, -2), Vector2(3, -2), Vector2(-1, 14), Vector2(12, -6), Vector2(6, -6), Vector2(11, -16)]), WHITE)
			for i in 3:
				c.draw_line(mid + Vector2(-17, -9 + i * 8) * k, mid + Vector2(-8 + i * 1.5, -9 + i * 8) * k, Color(light, 0.9 - i * 0.2), 2.0 * k, true)
		"lightning_tight_coil":   # a wound coil, a spark jumping off its end
			for i in 4:
				c.draw_arc(mid + Vector2(-9 + i * 5.5, 4) * k, 6.5 * k, 0, TAU, 16, light if i % 2 == 0 else col, 2.0 * k, true)
			c.draw_line(mid + Vector2(-18, 10) * k, mid + Vector2(-14, 9) * k, light, 2.0 * k, true)
			c.draw_line(mid + Vector2(12, -2) * k, mid + Vector2(14, -8) * k, light, 2.0 * k, true)
			c.draw_line(mid + Vector2(10.5, -12) * k, mid + Vector2(18.5, -12) * k, WHITE, 1.8 * k, true)
			c.draw_line(mid + Vector2(14.5, -16) * k, mid + Vector2(14.5, -8) * k, WHITE, 1.8 * k, true)
		"lightning_earth_return":   # the ground symbol, and health coming back up out of it
			c.draw_line(mid + Vector2(-7, -16) * k, mid + Vector2(-7, 2) * k, light, 2.4 * k, true)
			for i in 3:
				c.draw_line(mid + Vector2(-16 + i * 3, 3 + i * 5) * k, mid + Vector2(2 - i * 3, 3 + i * 5) * k, light, 2.4 * k, true)
			c.draw_rect(Rect2(mid + Vector2(9, -13) * k, Vector2(5, 17) * k), Color(0.45, 1.0, 0.5), true)
			c.draw_rect(Rect2(mid + Vector2(3, -7) * k, Vector2(17, 5) * k), Color(0.45, 1.0, 0.5), true)
		"lightning_conductor":   # a crit star, and the charge it sends back into the cell
			var burst := PackedVector2Array()
			for i in 12:
				var a := TAU * i / 12.0 - PI / 2.0
				burst.append(mid + Vector2(8, -7) * k + Vector2(cos(a), sin(a)) * (8.0 if i % 2 == 0 else 3.2) * k)
			c.draw_colored_polygon(burst, WHITE)
			c.draw_rect(Rect2(mid + Vector2(-16, 1) * k, Vector2(11, 15) * k), col.darkened(0.4), true)
			c.draw_rect(Rect2(mid + Vector2(-16, 1) * k, Vector2(11, 15) * k), light, false, 1.6 * k)
			c.draw_rect(Rect2(mid + Vector2(-13, -2) * k, Vector2(5, 3) * k), light, true)
			c.draw_rect(Rect2(mid + Vector2(-14, 9) * k, Vector2(7, 5) * k), light, true)
			c.draw_arc(mid + Vector2(3, 4) * k, 9.0 * k, 0.1, PI * 0.8, 10, light, 2.0 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-6, 11), Vector2(-1, 5), Vector2(1, 12)]), light)
		"lightning_high_voltage":   # a warning triangle with a bolt in it, a full cell beside it
			var tri := _p(mid, k, [Vector2(4, -15), Vector2(18, 11), Vector2(-10, 11)])
			c.draw_colored_polygon(tri, col.darkened(0.3))
			tri.append(tri[0])
			c.draw_polyline(tri, WHITE, 2.0 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(6, -7), Vector2(1, 1), Vector2(6, 1), Vector2(2, 8)]), WHITE, 2.4 * k, true)
			c.draw_rect(Rect2(mid + Vector2(-17, -8) * k, Vector2(5, 21) * k), light, true)
			c.draw_rect(Rect2(mid + Vector2(-17, -12) * k, Vector2(5, 2.5) * k), WHITE, true)
		"lightning_standing_charge":   # two planted feet, and a column of charge stacking up over them
			c.draw_line(mid + Vector2(-17, 15) * k, mid + Vector2(17, 15) * k, col.darkened(0.2), 2.6 * k, true)
			for x in [-7.0, 7.0]:
				c.draw_line(mid + Vector2(x, 15) * k, mid + Vector2(x, 8) * k, light, 3.0 * k, true)
				c.draw_line(mid + Vector2(x, 15) * k, mid + Vector2(x * 1.9, 15) * k, light, 3.0 * k, true)
			for i in 5:
				c.draw_rect(Rect2(mid + Vector2(-6, 3 - i * 4.5) * k, Vector2(12, 3) * k), WHITE if i == 4 else Color(light, 0.45 + i * 0.12), true)
		"lightning_whip_crack":   # a long lash, a crack at its tip, and the step it sets up
			c.draw_line(mid + Vector2(-17, 16) * k, mid + Vector2(-12, 11) * k, WOOD, 4.0 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(-12, 11), Vector2(-5, 10), Vector2(0, 4), Vector2(-3, -3), Vector2(4, -8), Vector2(11, -7)]), light, 2.4 * k, true)
			for a in [-1.2, -0.3, 0.6]:
				c.draw_line(mid + (Vector2(13, -8) + Vector2(cos(a), sin(a)) * 2.5) * k, mid + (Vector2(13, -8) + Vector2(cos(a), sin(a)) * 7.0) * k, WHITE, 1.8 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(2, 9), Vector2(9, 13), Vector2(2, 17)]), WHITE, 2.2 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(9, 9), Vector2(16, 13), Vector2(9, 17)]), Color(light, 0.7), 2.2 * k, true)
		"lightning_storm_cycle":   # two arrows chasing each other round a bolt
			c.draw_arc(mid, 14.0 * k, PI * 0.15, PI * 0.85, 12, light, 2.4 * k, true)
			c.draw_arc(mid, 14.0 * k, PI * 1.15, PI * 1.85, 12, light, 2.4 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-16, 4), Vector2(-9, 3), Vector2(-13, 10)]), light)
			c.draw_colored_polygon(_p(mid, k, [Vector2(16, -4), Vector2(9, -3), Vector2(13, -10)]), light)
			c.draw_colored_polygon(_p(mid, k, [Vector2(3, -9), Vector2(-5, 1), Vector2(-1, 1), Vector2(-4, 10), Vector2(6, -2), Vector2(1, -2)]), WHITE)
		"lightning_tempo":   # a metronome, its arm swinging faster with every beat
			c.draw_colored_polygon(_p(mid, k, [Vector2(-10, 15), Vector2(10, 15), Vector2(4, -13), Vector2(-4, -13)]), col.darkened(0.35))
			c.draw_polyline(_p(mid, k, [Vector2(-10, 15), Vector2(10, 15), Vector2(4, -13), Vector2(-4, -13), Vector2(-10, 15)]), light, 1.8 * k, true)
			c.draw_line(mid + Vector2(0, 11) * k, mid + Vector2(9, -15) * k, WHITE, 2.4 * k, true)
			c.draw_circle(mid + Vector2(6, -7) * k, 2.8 * k, WHITE)
			for i in 3:
				c.draw_arc(mid + Vector2(0, 11) * k, (17.0 + i * 3.5) * k, -PI * 0.5 - 0.75, -PI * 0.5 - 0.3, 6, Color(light, 0.9 - i * 0.25), 1.5 * k, true)
		"lightning_quick_charge":   # a cell filling up fast: a bolt in it, arrows climbing beside it
			c.draw_rect(Rect2(mid + Vector2(-13, -11) * k, Vector2(14, 25) * k), col.darkened(0.4), true)
			c.draw_rect(Rect2(mid + Vector2(-13, -11) * k, Vector2(14, 25) * k), light, false, 1.6 * k)
			c.draw_rect(Rect2(mid + Vector2(-9, -15) * k, Vector2(6, 4) * k), light, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-4, -8), Vector2(-10, 3), Vector2(-7, 3), Vector2(-9, 11), Vector2(-2, 0), Vector2(-5, 0)]), WHITE)
			for y in [-6.0, 4.0]:
				c.draw_polyline(_p(mid, k, [Vector2(6, y + 6), Vector2(11, y), Vector2(16, y + 6)]), WHITE, 2.4 * k, true)
		"lightning_conductive":   # a rod taking a bolt, a crit star where it lands
			c.draw_line(mid + Vector2(0, -2) * k, mid + Vector2(0, 16) * k, Color(0.75, 0.75, 0.8), 3.0 * k, true)
			c.draw_line(mid + Vector2(-7, 16) * k, mid + Vector2(7, 16) * k, Color(0.75, 0.75, 0.8), 3.0 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(-11, -17), Vector2(-4, -11), Vector2(-8, -8), Vector2(0, -3)]), light, 2.6 * k, true)
			var crit := PackedVector2Array()
			for i in 12:
				var a := TAU * i / 12.0 - PI / 2.0
				crit.append(mid + Vector2(0, -3) * k + Vector2(cos(a), sin(a)) * (8.0 if i % 2 == 0 else 3.2) * k)
			c.draw_colored_polygon(crit, WHITE)
			c.draw_circle(mid + Vector2(0, -3) * k, 2.2 * k, col)
		"lightning_deep_reserves":   # a tall cell with one more block stacked on top
			c.draw_rect(Rect2(mid + Vector2(-8, -6) * k, Vector2(16, 22) * k), col.darkened(0.4), true)
			c.draw_rect(Rect2(mid + Vector2(-8, -6) * k, Vector2(16, 22) * k), light, false, 1.6 * k)
			for i in 3:
				c.draw_rect(Rect2(mid + Vector2(-5, 10 - i * 6) * k, Vector2(10, 4) * k), light, true)
			c.draw_rect(Rect2(mid + Vector2(-8, -15) * k, Vector2(16, 7) * k), WHITE, true)
			c.draw_line(mid + Vector2(11, -11) * k, mid + Vector2(17, -11) * k, WHITE, 2.0 * k, true)
			c.draw_line(mid + Vector2(14, -14) * k, mid + Vector2(14, -8) * k, WHITE, 2.0 * k, true)
		"lightning_running_on_empty":   # a cell on its last bar, and the bolt it throws anyway
			c.draw_rect(Rect2(mid + Vector2(-15, -9) * k, Vector2(14, 24) * k), col.darkened(0.5), true)
			c.draw_rect(Rect2(mid + Vector2(-15, -9) * k, Vector2(14, 24) * k), light, false, 1.6 * k)
			c.draw_rect(Rect2(mid + Vector2(-11, -13) * k, Vector2(6, 4) * k), light, true)
			c.draw_rect(Rect2(mid + Vector2(-12, 9) * k, Vector2(8, 4) * k), Color(1.0, 0.4, 0.3), true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(10, -16), Vector2(2, -2), Vector2(7, -2), Vector2(3, 14), Vector2(16, -6), Vector2(10, -6), Vector2(15, -16)]), WHITE)
		"lightning_honed_edge":   # a blade drawn across a stone, sparks flying
			c.draw_colored_polygon(_p(mid, k, [Vector2(-15, 8), Vector2(9, 8), Vector2(13, 15), Vector2(-11, 15)]), Color(0.4, 0.38, 0.4))
			c.draw_line(mid + Vector2(-13, 6) * k, mid + Vector2(12, -13) * k, Color(light, 0.5), 6.0 * k, true)
			c.draw_line(mid + Vector2(-13, 6) * k, mid + Vector2(12, -13) * k, Color(0.92, 0.92, 0.96), 3.0 * k, true)
			for p in [Vector2(-6, -3), Vector2(-12, -6), Vector2(-2, -11)]:
				var at := mid + (p as Vector2) * k
				c.draw_line(at + Vector2(-2.5, 0) * k, at + Vector2(2.5, 0) * k, WHITE, 1.5 * k, true)
				c.draw_line(at + Vector2(0, -2.5) * k, at + Vector2(0, 2.5) * k, WHITE, 1.5 * k, true)
		"lightning_running_start":   # a long dash line ending in a spark of Energy
			for i in 3:
				c.draw_line(mid + Vector2(-17 + i * 3, -6 + i * 6) * k, mid + Vector2(-5 + i * 3, -6 + i * 6) * k, Color(light, 0.5 + 0.2 * i), 2.2 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(-3, -8), Vector2(5, 0), Vector2(-3, 8)]), light, 2.8 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(13, -12), Vector2(7, -1), Vector2(11, -1), Vector2(8, 10), Vector2(17, -4), Vector2(13, -4), Vector2(16, -12)]), WHITE)
		"lightning_third_beat":   # three beats, the third one struck bright
			c.draw_rect(Rect2(mid + Vector2(-15, 5) * k, Vector2(7, 9) * k), col, true)
			c.draw_rect(Rect2(mid + Vector2(-5, -1) * k, Vector2(7, 15) * k), col, true)
			c.draw_rect(Rect2(mid + Vector2(5, -9) * k, Vector2(9, 23) * k), WHITE, true)
			c.draw_line(mid + Vector2(-17, 15) * k, mid + Vector2(17, 15) * k, light, 1.8 * k, true)
			for a in [-2.3, -1.57, -0.84]:
				var ray := Vector2(cos(a), sin(a))
				c.draw_line(mid + (Vector2(9.5, -9) + ray * 3.0) * k, mid + (Vector2(9.5, -9) + ray * 8.0) * k, WHITE, 1.6 * k, true)
		"lightning_redline":   # a gauge held in the red, and a clock hand running on
			c.draw_arc(mid + Vector2(0, 4) * k, 14.0 * k, PI, PI * 1.65, 14, light, 3.0 * k, true)
			c.draw_arc(mid + Vector2(0, 4) * k, 14.0 * k, PI * 1.65, TAU, 10, Color(1.0, 0.35, 0.3), 3.0 * k, true)
			c.draw_line(mid + Vector2(0, 4) * k, mid + Vector2(11, -3) * k, WHITE, 2.4 * k, true)
			c.draw_circle(mid + Vector2(0, 4) * k, 2.6 * k, WHITE)
			c.draw_arc(mid + Vector2(-8, 13) * k, 4.5 * k, 0, TAU, 14, WHITE, 1.4 * k, true)
			c.draw_line(mid + Vector2(-8, 13) * k, mid + Vector2(-8, 10) * k, WHITE, 1.4 * k, true)
			c.draw_line(mid + Vector2(-8, 13) * k, mid + Vector2(-6, 14) * k, WHITE, 1.4 * k, true)
			c.draw_line(mid + Vector2(1, 13) * k, mid + Vector2(7, 13) * k, WHITE, 1.8 * k, true)
			c.draw_line(mid + Vector2(4, 10) * k, mid + Vector2(4, 16) * k, WHITE, 1.8 * k, true)
		"fire_flash_point":   # a crit burst flaring off a small flame
			c.draw_colored_polygon(_p(mid, k, [Vector2(-7, -2), Vector2(-1, 8), Vector2(-3, 15), Vector2(-11, 15), Vector2(-13, 8)]), col)
			c.draw_circle(mid + Vector2(-7, 11) * k, 2.2 * k, Color(1.0, 0.9, 0.4))
			var flash := PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16.0 - PI / 2.0
				flash.append(mid + Vector2(6, -6) * k + Vector2(cos(a), sin(a)) * (10.0 if i % 2 == 0 else 4.0) * k)
			c.draw_colored_polygon(flash, Color(1.0, 0.9, 0.4))
			flash.append(flash[0])
			c.draw_polyline(flash, WHITE, 1.4 * k, true)
			c.draw_circle(mid + Vector2(6, -6) * k, 2.6 * k, WHITE)
		"fire_forge_hardened":   # a hammer coming down on a glowing anvil
			c.draw_colored_polygon(_p(mid, k, [Vector2(-14, 5), Vector2(10, 5), Vector2(6, 10), Vector2(2, 10), Vector2(2, 15), Vector2(-8, 15), Vector2(-8, 10), Vector2(-11, 10)]), Color(0.4, 0.38, 0.4))
			c.draw_line(mid + Vector2(-13, 4) * k, mid + Vector2(9, 4) * k, Color(1.0, 0.9, 0.4), 2.4 * k, true)
			c.draw_line(mid + Vector2(14, -2) * k, mid + Vector2(1, -11) * k, WOOD, 3.0 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-6, -11), Vector2(1, -17), Vector2(6, -11), Vector2(-1, -5)]), light)
			for a in [-2.6, -1.9]:
				var d := Vector2(cos(a), sin(a))
				c.draw_line(mid + (Vector2(-4, 2) + d * 4.0) * k, mid + (Vector2(-4, 2) + d * 9.0) * k, WHITE, 1.6 * k, true)
		"fire_lingering_embers":   # a trail of embers still glowing, a clock over them
			for i in 4:
				var ember := mid + Vector2(-13 + i * 8, 11 - i * 2) * k
				c.draw_circle(ember, (4.5 - i * 0.8) * k, Color(col, 1.0 - i * 0.18))
				c.draw_circle(ember, (2.0 - i * 0.35) * k, Color(1.0, 0.9, 0.4))
			_clock(c, mid + Vector2(-3, -7) * k, 8.0 * k, light, k)
			c.draw_line(mid + Vector2(-3, -7) * k, mid + Vector2(-3, -13) * k, WHITE, 1.8 * k, true)
			c.draw_line(mid + Vector2(-3, -7) * k, mid + Vector2(2, -5) * k, WHITE, 1.8 * k, true)
		"fire_controlled_burn":   # a flame kept inside a ring
			c.draw_arc(mid + Vector2(0, -1) * k, 14.0 * k, 0, TAU, 28, light, 2.2 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(0, -11), Vector2(6, -1), Vector2(4, 7), Vector2(-4, 7), Vector2(-6, -1)]), col)
			c.draw_colored_polygon(_p(mid, k, [Vector2(0, -3), Vector2(3, 2), Vector2(0, 6), Vector2(-3, 2)]), Color(1.0, 0.9, 0.4))
			for x in [-1.0, 1.0]:
				c.draw_line(mid + Vector2(14 * x, -1) * k, mid + Vector2(18 * x, -1) * k, WHITE, 2.2 * k, true)
			c.draw_line(mid + Vector2(-9, 17) * k, mid + Vector2(9, 17) * k, WHITE, 2.0 * k, true)
		"fire_white_heat":   # a heat gauge filled to the top, its tip white-hot
			c.draw_rect(Rect2(mid + Vector2(-5, -14) * k, Vector2(10, 28) * k), Color(0.2, 0.15, 0.14), true)
			c.draw_rect(Rect2(mid + Vector2(-3, 2) * k, Vector2(6, 10) * k), col, true)
			c.draw_rect(Rect2(mid + Vector2(-3, -6) * k, Vector2(6, 8) * k), Color(1.0, 0.9, 0.4), true)
			c.draw_rect(Rect2(mid + Vector2(-3, -12) * k, Vector2(6, 6) * k), WHITE, true)
			c.draw_rect(Rect2(mid + Vector2(-5, -14) * k, Vector2(10, 28) * k), light, false, 1.6 * k)
			for a in [-2.2, -1.57, -0.94]:
				var ray := Vector2(cos(a), sin(a))
				c.draw_line(mid + (Vector2(0, -14) + ray * 3.0) * k, mid + (Vector2(0, -14) + ray * 8.0) * k, WHITE, 1.6 * k, true)
			for y in [-4.0, 4.0]:
				c.draw_line(mid + Vector2(8, y) * k, mid + Vector2(13, y) * k, light, 1.5 * k, true)
				c.draw_line(mid + Vector2(-13, y) * k, mid + Vector2(-8, y) * k, light, 1.5 * k, true)
		"fire_banked_mana":   # a mana drop coming back out of a small flame
			c.draw_colored_polygon(_p(mid, k, [Vector2(-7, -2), Vector2(-1, 8), Vector2(-3, 15), Vector2(-11, 15), Vector2(-13, 8)]), col)
			c.draw_circle(mid + Vector2(-7, 11) * k, 2.2 * k, Color(1.0, 0.9, 0.4))
			_drop(c, mid + Vector2(8, -3) * k, 0.8 * k, Color(0.3, 0.5, 1.0, 0.9), WHITE, k)
			c.draw_polyline(_p(mid, k, [Vector2(-2, 6), Vector2(3, 10), Vector2(9, 9)]), WHITE, 1.8 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(5, 12), Vector2(9, 9), Vector2(6, 5)]), WHITE, 1.8 * k, true)
		"fire_warm_blood":   # a drop of blood with a flame in it, behind a guard line
			_drop(c, mid + Vector2(0, 0) * k, 1.1 * k, Color(0.75, 0.15, 0.12), light, k)
			c.draw_colored_polygon(_p(mid, k, [Vector2(0, -3), Vector2(4, 4), Vector2(2, 9), Vector2(-2, 9), Vector2(-4, 4)]), Color(1.0, 0.9, 0.4))
			c.draw_arc(mid + Vector2(0, 2) * k, 17.0 * k, PI * 0.75, PI * 1.25, 10, WHITE, 2.2 * k, true)
			c.draw_arc(mid + Vector2(0, 2) * k, 17.0 * k, PI * 1.75, PI * 2.25, 10, WHITE, 2.2 * k, true)
		"fire_deep_brand":   # a brand mark burned deep: a glowing ring and cross with a second ring inside
			c.draw_circle(mid, 15.0 * k, Color(0.2, 0.15, 0.14))
			c.draw_arc(mid, 13.0 * k, 0, TAU, 28, Color(1.0, 0.9, 0.4), 3.0 * k, true)
			c.draw_arc(mid, 7.0 * k, 0, TAU, 20, col, 2.2 * k, true)
			c.draw_line(mid + Vector2(-13, 0) * k, mid + Vector2(13, 0) * k, light, 2.4 * k, true)
			c.draw_line(mid + Vector2(0, -13) * k, mid + Vector2(0, 13) * k, light, 2.4 * k, true)
			c.draw_circle(mid, 2.6 * k, WHITE)
		"fire_thick_pitch":   # a heavy drop of pitch stretching down, a small flame on it
			var pitch := Color(0.12, 0.09, 0.08)
			c.draw_rect(Rect2(mid + Vector2(-15, -16) * k, Vector2(30, 6) * k), pitch, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-7, -10), Vector2(7, -10), Vector2(3, 0), Vector2(-3, 0)]), pitch)
			c.draw_circle(mid + Vector2(0, 6) * k, 8.0 * k, pitch)
			c.draw_arc(mid + Vector2(0, 6) * k, 8.0 * k, PI * 0.1, PI * 0.9, 12, light, 1.8 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(10, -4), Vector2(14, 3), Vector2(12, 8), Vector2(8, 8), Vector2(6, 3)]), col)
			c.draw_circle(mid + Vector2(10, 5) * k, 1.8 * k, Color(1.0, 0.9, 0.4))
		"fire_forge_heat":   # a glowing bar on an anvil that stays hot: a clock beside it
			c.draw_colored_polygon(_p(mid, k, [Vector2(-16, 4), Vector2(4, 4), Vector2(1, 9), Vector2(-3, 9), Vector2(-3, 14), Vector2(-9, 14), Vector2(-9, 9), Vector2(-13, 9)]), Color(0.4, 0.38, 0.4))
			c.draw_line(mid + Vector2(-15, 1) * k, mid + Vector2(3, 1) * k, Color(1.0, 0.9, 0.4), 4.0 * k, true)
			c.draw_line(mid + Vector2(-15, -3) * k, mid + Vector2(3, -3) * k, Color(col, 0.6), 2.0 * k, true)
			_clock(c, mid + Vector2(10, -7) * k, 7.5 * k, light, k)
			c.draw_line(mid + Vector2(10, -7) * k, mid + Vector2(10, -12) * k, WHITE, 1.8 * k, true)
			c.draw_line(mid + Vector2(10, -7) * k, mid + Vector2(14, -6) * k, WHITE, 1.8 * k, true)
		"fire_long_burn":   # a tall candle flame over a long wick line
			c.draw_rect(Rect2(mid + Vector2(-4, 2) * k, Vector2(8, 14) * k), Color(0.85, 0.8, 0.7), true)
			c.draw_line(mid + Vector2(0, 2) * k, mid + Vector2(0, -2) * k, Color(0.15, 0.12, 0.1), 1.6 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(0, -17), Vector2(5, -8), Vector2(3, -2), Vector2(-3, -2), Vector2(-5, -8)]), col)
			c.draw_colored_polygon(_p(mid, k, [Vector2(0, -10), Vector2(2, -5), Vector2(0, -2), Vector2(-2, -5)]), Color(1.0, 0.9, 0.4))
			for i in 3:
				c.draw_line(mid + Vector2(9 + i * 3, 14 - i * 9) * k, mid + Vector2(9 + i * 3, 9 - i * 9) * k, Color(light, 0.9 - i * 0.25), 2.0 * k, true)
		"fire_deep_crucible":   # a crucible bowl inside a ring pushed outward
			c.draw_arc(mid + Vector2(0, 2) * k, 11.0 * k, 0, TAU, 24, Color(light, 0.6), 1.6 * k, true)
			c.draw_arc(mid + Vector2(0, 2) * k, 17.0 * k, 0, TAU, 30, light, 2.0 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-8, -3), Vector2(8, -3), Vector2(5, 8), Vector2(-5, 8)]), Color(0.2, 0.16, 0.15))
			c.draw_line(mid + Vector2(-8, -3) * k, mid + Vector2(8, -3) * k, Color(1.0, 0.9, 0.4), 2.6 * k, true)
			for a in [0.0, PI]:
				var d := Vector2(cos(a), sin(a))
				var tip := mid + Vector2(0, 2) * k + d * 16.0 * k
				c.draw_colored_polygon(PackedVector2Array([tip + d * 3.0 * k, tip - d * 3.0 * k + d.orthogonal() * 3.0 * k, tip - d * 3.0 * k - d.orthogonal() * 3.0 * k]), WHITE)
		"fire_stoked_kiln":   # a kiln mouth roaring, a blast leaving it
			c.draw_arc(mid + Vector2(-3, 8) * k, 13.0 * k, PI, TAU, 16, Color(0.55, 0.5, 0.48), 4.0 * k, true)
			c.draw_line(mid + Vector2(-16, 8) * k, mid + Vector2(-16, 16) * k, Color(0.55, 0.5, 0.48), 4.0 * k, true)
			c.draw_line(mid + Vector2(10, 8) * k, mid + Vector2(10, 16) * k, Color(0.55, 0.5, 0.48), 4.0 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-3, -3), Vector2(4, 6), Vector2(2, 14), Vector2(-8, 14), Vector2(-10, 6)]), col)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-3, 4), Vector2(0, 9), Vector2(-3, 14), Vector2(-6, 9)]), Color(1.0, 0.9, 0.4))
			for i in 2:
				c.draw_polyline(_p(mid, k, [Vector2(6 + i * 5, -8), Vector2(11 + i * 5, -13), Vector2(6 + i * 5, -18)]), WHITE if i == 0 else light, 2.2 * k, true)
		"fire_slag_mending":   # a cracked chunk of slag knitting shut around a healing cross
			var chunk := _p(mid, k, [Vector2(-14, 10), Vector2(-11, -8), Vector2(-2, -14), Vector2(11, -9), Vector2(14, 8), Vector2(2, 14)])
			c.draw_colored_polygon(chunk, Color(0.22, 0.18, 0.16))
			chunk.append(chunk[0])
			c.draw_polyline(chunk, col, 1.8 * k, true)
			c.draw_rect(Rect2(mid + Vector2(-2.5, -8) * k, Vector2(5, 16) * k), Color(0.45, 1.0, 0.5), true)
			c.draw_rect(Rect2(mid + Vector2(-8, -2.5) * k, Vector2(16, 5) * k), Color(0.45, 1.0, 0.5), true)
		"fire_furnace_heart":   # a heart with a furnace glow inside
			var heart := PackedVector2Array()
			for i in 24:
				var t := TAU * i / 24.0
				var hx := 16.0 * pow(sin(t), 3)
				var hy := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
				heart.append(mid + Vector2(hx, hy + 1.0) * 0.85 * k)
			c.draw_colored_polygon(heart, Color(0.24, 0.19, 0.17))
			heart.append(heart[0])
			c.draw_polyline(heart, light, 1.8 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(0, -8), Vector2(5, 0), Vector2(3, 6), Vector2(-3, 6), Vector2(-5, 0)]), col)
			c.draw_circle(mid + Vector2(0, 3) * k, 2.4 * k, Color(1.0, 0.9, 0.4))
		"fire_kindling":   # crossed sticks catching their first flame
			c.draw_line(mid + Vector2(-14, 14) * k, mid + Vector2(9, 3) * k, WOOD, 3.5 * k, true)
			c.draw_line(mid + Vector2(14, 14) * k, mid + Vector2(-9, 3) * k, WOOD, 3.5 * k, true)
			c.draw_line(mid + Vector2(-10, 16) * k, mid + Vector2(10, 16) * k, WOOD.darkened(0.25), 3.0 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(0, -16), Vector2(6, -5), Vector2(4, 4), Vector2(-4, 4), Vector2(-6, -5)]), col)
			c.draw_colored_polygon(_p(mid, k, [Vector2(0, -7), Vector2(3, -1), Vector2(0, 3), Vector2(-3, -1)]), Color(1.0, 0.9, 0.4))
			for p in [Vector2(-11, -8), Vector2(11, -10), Vector2(14, -1)]:
				c.draw_circle(mid + (p as Vector2) * k, 1.8 * k, light)
		"fire_fresh_tinder":   # a burn given more time: a flame, a clock and a plus
			c.draw_colored_polygon(_p(mid, k, [Vector2(-9, -15), Vector2(-3, -4), Vector2(-4, 6), Vector2(-9, 10), Vector2(-14, 6), Vector2(-15, -4)]), col)
			c.draw_circle(mid + Vector2(-9, 4) * k, 2.4 * k, Color(1.0, 0.9, 0.4))
			_clock(c, mid + Vector2(8, 6) * k, 8.5 * k, light, k)
			c.draw_line(mid + Vector2(8, 6) * k, mid + Vector2(8, 0) * k, WHITE, 1.8 * k, true)
			c.draw_line(mid + Vector2(8, 6) * k, mid + Vector2(12, 8) * k, WHITE, 1.8 * k, true)
			c.draw_line(mid + Vector2(5, -12) * k, mid + Vector2(13, -12) * k, WHITE, 2.4 * k, true)
			c.draw_line(mid + Vector2(9, -16) * k, mid + Vector2(9, -8) * k, WHITE, 2.4 * k, true)
		"fire_afterglow":   # a blade still glowing after the quench
			c.draw_line(mid + Vector2(-9, 9) * k, mid + Vector2(12, -12) * k, Color(col, 0.45), 9.0 * k, true)
			c.draw_line(mid + Vector2(-8, 8) * k, mid + Vector2(12, -12) * k, Color(1.0, 0.9, 0.4), 3.5 * k, true)
			c.draw_line(mid + Vector2(-13, 4) * k, mid + Vector2(-4, 13) * k, light, 3.0 * k, true)
			c.draw_line(mid + Vector2(-9, 9) * k, mid + Vector2(-15, 15) * k, WOOD, 3.5 * k, true)
			for i in 2:
				c.draw_arc(mid + Vector2(5, -5) * k, (10.0 + i * 5.0) * k, PI * 0.05, PI * 0.45, 8, Color(light, 0.75 - i * 0.3), 1.6 * k, true)
		"fire_pressure_valve":   # a valve wheel on a pipe, steam escaping
			c.draw_line(mid + Vector2(-17, 9) * k, mid + Vector2(17, 9) * k, Color(0.55, 0.5, 0.48), 5.0 * k, true)
			c.draw_line(mid + Vector2(0, 9) * k, mid + Vector2(0, -2) * k, Color(0.55, 0.5, 0.48), 3.0 * k, true)
			c.draw_arc(mid + Vector2(0, -6) * k, 7.0 * k, 0, TAU, 18, light, 2.4 * k, true)
			c.draw_line(mid + Vector2(-7, -6) * k, mid + Vector2(7, -6) * k, light, 2.0 * k, true)
			for x in [-11.0, 11.0]:
				c.draw_arc(mid + Vector2(x, -12) * k, 3.5 * k, PI * 0.8, PI * 2.1, 8, WHITE, 1.8 * k, true)
		"fire_cool_under_fire":   # a calm shield with a small flame held on it
			_shield(c, mid, k, Color(0.3, 0.42, 0.55), Color(0.65, 0.88, 1.0))
			c.draw_colored_polygon(_p(mid, k, [Vector2(0, -8), Vector2(5, 0), Vector2(3, 6), Vector2(-3, 6), Vector2(-5, 0)]), col)
			c.draw_circle(mid + Vector2(0, 3) * k, 2.2 * k, Color(1.0, 0.9, 0.4))
		"fire_thick_slag":   # layers of slag stacked up
			for i in 3:
				var y := 9.0 - i * 9.0
				c.draw_colored_polygon(_p(mid, k, [Vector2(-14 + i * 2, y), Vector2(14 - i * 2, y), Vector2(11 - i * 2, y + 7), Vector2(-11 + i * 2, y + 7)]), Color(0.22, 0.18, 0.16))
				c.draw_line(mid + Vector2(-14 + i * 2, y) * k, mid + Vector2(14 - i * 2, y) * k, col if i < 2 else Color(1.0, 0.9, 0.4), 2.2 * k, true)
		"fire_hot_iron":   # a glowing shield boss throwing sparks
			_shield(c, mid, k, Color(0.24, 0.19, 0.17), light)
			c.draw_circle(mid + Vector2(0, -2) * k, 6.0 * k, col)
			c.draw_circle(mid + Vector2(0, -2) * k, 3.0 * k, Color(1.0, 0.9, 0.4))
			for a in [-0.5, 0.3, 1.2]:
				var d := Vector2(cos(a), sin(a))
				c.draw_line(mid + (Vector2(0, -2) + d * 9.0) * k, mid + (Vector2(0, -2) + d * 15.0) * k, WHITE, 1.8 * k, true)
		"fire_flashover":   # one flame leaping to two more
			c.draw_colored_polygon(_p(mid, k, [Vector2(-9, -8), Vector2(-4, 2), Vector2(-6, 10), Vector2(-12, 10), Vector2(-14, 2)]), col)
			c.draw_circle(mid + Vector2(-9, 6) * k, 2.4 * k, Color(1.0, 0.9, 0.4))
			for p in [Vector2(11, -9), Vector2(12, 9)]:
				var at: Vector2 = mid + (p as Vector2) * k
				c.draw_line(mid + Vector2(-3, 1) * k, at + Vector2(-5, 0) * k, light, 1.8 * k, true)
				c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -6) * k, at + Vector2(4, 1) * k, at + Vector2(0, 5) * k, at + Vector2(-4, 1) * k]), col)
		"fire_clinker":   # broken chunks of slag lying in a burning pool
			c.draw_line(mid + Vector2(-16, 12) * k, mid + Vector2(16, 12) * k, Color(1.0, 0.9, 0.4), 3.0 * k, true)
			c.draw_line(mid + Vector2(-12, 16) * k, mid + Vector2(12, 16) * k, col, 2.0 * k, true)
			for raw in [[Vector2(-14, 9), Vector2(-9, -3), Vector2(-3, 2), Vector2(-5, 9)], [Vector2(-1, 9), Vector2(3, -9), Vector2(9, -2), Vector2(7, 9)], [Vector2(10, 9), Vector2(13, 1), Vector2(17, 9)]]:
				var chunk := _p(mid, k, raw)
				c.draw_colored_polygon(chunk, Color(0.22, 0.18, 0.16))
				chunk.append(chunk[0])
				c.draw_polyline(chunk, light, 1.6 * k, true)
		"fire_fuse_crit":   # Volatile Fuse: a charge with a crit burst feeding it
			c.draw_circle(mid + Vector2(-5, 6) * k, 9.0 * k, Color(0.16, 0.13, 0.13))
			c.draw_arc(mid + Vector2(-5, 6) * k, 9.0 * k, 0, TAU, 22, col, 2.0 * k, true)
			var burst := PackedVector2Array()
			for i in 12:
				var a := TAU * i / 12.0
				burst.append(mid + Vector2(10, -9) * k + Vector2(cos(a), sin(a)) * (8.0 if i % 2 == 0 else 3.5) * k)
			c.draw_colored_polygon(burst, Color(1.0, 0.9, 0.4))
			c.draw_line(mid + Vector2(5, -4) * k, mid + Vector2(0, 1) * k, WHITE, 2.2 * k, true)
			c.draw_line(mid + Vector2(-9, 6) * k, mid + Vector2(-1, 6) * k, light, 2.0 * k, true)
			c.draw_line(mid + Vector2(-5, 2) * k, mid + Vector2(-5, 10) * k, light, 2.0 * k, true)
		"fire_volley_targets":   # Scattered Embers: one volley splitting toward three targets
			var from := mid + Vector2(-15, 10) * k
			for p in [Vector2(14, -13), Vector2(16, 2), Vector2(6, 14)]:
				var to := mid + (p as Vector2) * k
				c.draw_line(from, to, Color(col, 0.7), 2.0 * k, true)
				c.draw_circle(to, 4.0 * k, light)
				c.draw_circle(to, 1.8 * k, WHITE)
			c.draw_circle(from, 4.5 * k, col)
			c.draw_circle(from, 2.0 * k, Color(1.0, 0.9, 0.4))
		"fire_banked_coals":   # Banked Coals: a heap of coals still glowing under ash
			for p in [Vector2(-10, 9), Vector2(0, 10), Vector2(10, 9), Vector2(-5, 1), Vector2(5, 1), Vector2(0, -7)]:
				var at := mid + (p as Vector2) * k
				c.draw_circle(at, 6.0 * k, Color(0.18, 0.14, 0.13))
				c.draw_arc(at, 6.0 * k, PI * 1.1, PI * 1.9, 10, col, 1.8 * k, true)
			for p in [Vector2(-5, 6), Vector2(5, 6), Vector2(0, -2)]:
				c.draw_circle(mid + (p as Vector2) * k, 2.0 * k, Color(1.0, 0.9, 0.4))
			c.draw_arc(mid + Vector2(0, 4) * k, 19.0 * k, PI * 1.2, PI * 1.8, 16, Color(WHITE, 0.6), 1.5 * k, true)
		"fire_afterburn":   # Afterburn: a crit burst whose glow trails into the next plain hit
			var star := PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16.0 - PI / 2.0
				star.append(mid + Vector2(-6, -5) * k + Vector2(cos(a), sin(a)) * (11.0 if i % 2 == 0 else 4.5) * k)
			c.draw_colored_polygon(star, Color(col, 0.9))
			star.append(star[0])
			c.draw_polyline(star, light, 1.4 * k, true)
			c.draw_circle(mid + Vector2(-6, -5) * k, 3.0 * k, WHITE)
			for i in 3:
				c.draw_circle(mid + Vector2(3 + i * 5, 5 + i * 4) * k, (2.6 - i * 0.5) * k, Color(light, 0.9 - i * 0.2))
			c.draw_circle(mid + Vector2(15, 14) * k, 4.0 * k, WHITE)
		"fire_tempered_flame":   # Tempered Flame: a steady flame, its crit spark pushed down
			var body := _p(mid, k, [Vector2(-6, -16), Vector2(0, -7), Vector2(3, 1), Vector2(1, 9), Vector2(-5, 13),
				Vector2(-11, 13), Vector2(-16, 8), Vector2(-16, 0), Vector2(-11, -8)])
			c.draw_colored_polygon(body, Color(col, 0.85))
			body.append(body[0])
			c.draw_polyline(body, light, 1.6 * k, true)
			c.draw_circle(mid + Vector2(-7, 5) * k, 4.0 * k, WHITE)
			c.draw_line(mid + Vector2(11, -13) * k, mid + Vector2(11, 8) * k, WHITE, 2.5 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(5, 2), Vector2(11, 9), Vector2(17, 2)]), WHITE, 2.5 * k, true)
			c.draw_line(mid + Vector2(5, 14) * k, mid + Vector2(17, 14) * k, light, 2.0 * k, true)
		"fire_smoldering_focus":   # Smoldering Focus: embers gathering under a flame with a white-hot core
			var flame := _p(mid, k, [Vector2(0, -17), Vector2(5, -9), Vector2(10, -2), Vector2(9, 6), Vector2(4, 11),
				Vector2(-4, 11), Vector2(-9, 6), Vector2(-10, -2), Vector2(-4, -8)])
			c.draw_colored_polygon(flame, Color(col, 0.85))
			flame.append(flame[0])
			c.draw_polyline(flame, light, 1.6 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(0, -6), Vector2(4, 1), Vector2(3, 7), Vector2(-3, 7), Vector2(-4, 1)]), WHITE)
			for x in [-12.0, -4.0, 4.0, 12.0]:
				c.draw_circle(mid + Vector2(x, 16) * k, 1.8 * k, light)
		"frost_haste":   # Frozen Focus: haste - double chevron with frost trail
			for i in 2:
				var x := -6.0 + i * 9.0
				c.draw_polyline(_p(mid, k, [Vector2(x - 5, -10), Vector2(x + 5, 0), Vector2(x - 5, 10)]), light if i == 1 else Color(col, 0.7), 3.5 * k, true)
			for y in [-7.0, 0.0, 7.0]:
				c.draw_line(mid + Vector2(-17, y) * k, mid + Vector2(-12, y) * k, Color(WHITE, 0.6), 1.5 * k, true)
		"frost_cold_draw":   # Cold Draw: an arrow in a cold target, the Energy it gives back flowing down the shaft
			c.draw_line(mid + Vector2(-13, 13) * k, mid + Vector2(9, -9) * k, WOOD, 2.5 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(15, -15), Vector2(5, -12), Vector2(12, -5)]), WHITE)
			_flake(c, mid + Vector2(11, -11) * k, 7.0 * k, Color(light, 0.8), 1.6 * k)
			c.draw_rect(Rect2(mid + Vector2(-17, -8) * k, Vector2(9, 14) * k), col.darkened(0.4), true)
			c.draw_rect(Rect2(mid + Vector2(-17, -8) * k, Vector2(9, 14) * k), light, false, 1.5 * k)
			c.draw_rect(Rect2(mid + Vector2(-15, -1) * k, Vector2(5, 5) * k), Color(1.0, 0.9, 0.4), true)
			c.draw_polyline(_p(mid, k, [Vector2(-15, -11), Vector2(-12.5, -14), Vector2(-10, -11)]), Color(1.0, 0.9, 0.4), 1.8 * k, true)
		"frost_black_ice":   # Black Ice: a dark sheet of ice with a frozen block standing on it
			var slick := PackedVector2Array()
			for i in 18:
				var a := TAU * i / 18.0
				slick.append(mid + Vector2(cos(a) * 16.0, 10 + sin(a) * 5.5) * k)
			c.draw_colored_polygon(slick, col.darkened(0.55))
			slick.append(slick[0])
			c.draw_polyline(slick, light, 1.6 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-7, 9), Vector2(-9, -6), Vector2(0, -15), Vector2(9, -6), Vector2(7, 9)]), Color(light, 0.85))
			c.draw_polyline(_p(mid, k, [Vector2(-7, 9), Vector2(-9, -6), Vector2(0, -15), Vector2(9, -6), Vector2(7, 9)]), WHITE, 1.5 * k, true)
			c.draw_line(mid + Vector2(0, -15) * k, mid + Vector2(0, 9) * k, Color(WHITE, 0.6), 1.2 * k, true)
		"frost_clean_shatter":   # Clean Shatter: a block of ice split clean in two by an arrow, a clock running back
			c.draw_colored_polygon(_p(mid, k, [Vector2(-16, -6), Vector2(-4, -9), Vector2(-3, 12), Vector2(-15, 12)]), Color(col, 0.75))
			c.draw_colored_polygon(_p(mid, k, [Vector2(4, -9), Vector2(16, -6), Vector2(15, 12), Vector2(3, 12)]), Color(col, 0.75))
			c.draw_polyline(_p(mid, k, [Vector2(-16, -6), Vector2(-4, -9), Vector2(-3, 12)]), WHITE, 1.5 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(16, -6), Vector2(4, -9), Vector2(3, 12)]), WHITE, 1.5 * k, true)
			c.draw_line(mid + Vector2(0, -17) * k, mid + Vector2(0, 6) * k, WOOD, 2.2 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-3.5, 4), Vector2(3.5, 4), Vector2(0, 13)]), WHITE)
			_clock(c, mid + Vector2(11, -12) * k, 5.0 * k, light, k * 0.7)
		"frost_cold_harvest":   # Cold Harvest: a frosted fletching, Energy pips falling out of it
			c.draw_line(mid + Vector2(-13, 3) * k, mid + Vector2(9, -17) * k, WOOD, 2.5 * k, true)
			_flake(c, mid + Vector2(-9, -1) * k, 8.0 * k, light, 2.0 * k)
			c.draw_circle(mid + Vector2(-9, -1) * k, 2.0 * k, WHITE)
			for i in 3:
				c.draw_circle(mid + Vector2(1 + i * 6.5, 7 + i * 3.0) * k, (3.2 - i * 0.5) * k, Color(1.0, 0.9, 0.4))
				c.draw_arc(mid + Vector2(1 + i * 6.5, 7 + i * 3.0) * k, (3.2 - i * 0.5) * k, 0, TAU, 12, WHITE, 1.0 * k, true)
		"frost_thin_ice":   # Thin Ice: a thin cracked sheet under a bowstring drawn half way, the cast bar already short
			c.draw_line(mid + Vector2(-17, 12) * k, mid + Vector2(17, 12) * k, light, 1.6 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(-9, 12), Vector2(-5, 8), Vector2(-1, 12), Vector2(4, 7), Vector2(8, 12)]), WHITE, 1.4 * k, true)
			c.draw_arc(mid + Vector2(-3, -4) * k, 11.0 * k, -PI * 0.42, PI * 0.42, 14, Color(0.6, 0.42, 0.25), 2.6 * k, true)
			c.draw_line(mid + Vector2(-11, -4) * k, mid + Vector2(9, -4) * k, light, 2.2 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(16, -4), Vector2(9, -8), Vector2(9, 0)]), WHITE)
			c.draw_rect(Rect2(mid + Vector2(-16, -17) * k, Vector2(20, 3.5) * k), col.darkened(0.4), true)
			c.draw_rect(Rect2(mid + Vector2(-16, -17) * k, Vector2(9, 3.5) * k), WHITE, true)
		"frost_marked_prey":   # Marked Prey: the mark on a target, ice shards flying into it
			c.draw_arc(mid + Vector2(5, 3) * k, 10.0 * k, 0, TAU, 24, light, 2.0 * k, true)
			for i in 4:
				var a := TAU * i / 4.0
				var d := Vector2(cos(a), sin(a))
				c.draw_line(mid + (Vector2(5, 3) + d * 8.0) * k, mid + (Vector2(5, 3) + d * 13.0) * k, WHITE, 2.0 * k, true)
			c.draw_circle(mid + Vector2(5, 3) * k, 2.4 * k, WHITE)
			for v in [Vector2(-3, -5), Vector2(-9, 0), Vector2(-5, -11)]:
				_shard(c, mid + (v as Vector2) * k, Vector2(0.75, 0.66).normalized(), 9.0 * k, 2.2 * k, Color(0.9, 0.95, 1.0), WHITE, k)
		"frost_absorb":   # Rime Ward: stronger shields - shield with a plus
			_shield(c, mid, k, Color(col, 0.5), light)
			c.draw_rect(Rect2(mid + Vector2(-2, -8) * k, Vector2(4, 14) * k), WHITE, true)
			c.draw_rect(Rect2(mid + Vector2(-7, -3) * k, Vector2(14, 4) * k), WHITE, true)
		"frost_shard_proc":   # Splintering Cold: a spell spark spawning a shard
			c.draw_circle(mid + Vector2(-7, 7) * k, 6.0 * k, Color(col, 0.6))
			c.draw_circle(mid + Vector2(-7, 7) * k, 3.0 * k, WHITE)
			_shard(c, mid + Vector2(14, -14) * k, Vector2(1, -1).normalized(), 14.0 * k, 4.0 * k, Color(col, 0.85), WHITE, k)
			for i in 3:
				c.draw_circle(mid + Vector2(-2 + i * 3, 2 - i * 3) * k, 1.3 * k, light)
		"frost_bolt_cast":   # Quickened Frost: faster Frost Bolt - bolt with speed lines
			c.draw_circle(mid + Vector2(5, -2) * k, 8.0 * k, col)
			c.draw_circle(mid + Vector2(5, -2) * k, 4.0 * k, WHITE)
			for y in [-8.0, -2.0, 4.0]:
				c.draw_line(mid + Vector2(-16, y) * k, mid + Vector2(-5, y) * k, Color(light, 0.8), 2.0 * k, true)
		"frost_discipline":   # Cold Discipline: calm, closed eye with a frost tear
			c.draw_arc(mid + Vector2(0, -8) * k, 13.0 * k, PI * 0.2, PI * 0.8, 12, light, 2.5 * k, true)
			for x in [-8.0, 0.0, 8.0]:
				c.draw_line(mid + Vector2(x, 3) * k, mid + Vector2(x * 1.2, 7) * k, light, 1.6 * k, true)
			_drop(c, mid + Vector2(0, 9) * k, 0.45 * k, Color(col, 0.8), WHITE, k)
		"frost_chilled_dmg":   # Bitter Cold: icicle fangs
			for x in [-7.0, 7.0]:
				c.draw_colored_polygon(_p(mid, k, [Vector2(x - 5, -12), Vector2(x + 5, -12), Vector2(x, 12)]), Color(col, 0.85))
				c.draw_polyline(_p(mid, k, [Vector2(x - 5, -12), Vector2(x, 12), Vector2(x + 5, -12)]), WHITE, 1.4 * k, true)
			c.draw_line(mid + Vector2(-15, -13) * k, mid + Vector2(15, -13) * k, light, 2.5 * k, true)
		"frost_int_sp":   # Frozen Mind: head with a frozen star in it
			c.draw_circle(mid + Vector2(0, -3) * k, 11.0 * k, Color(col, 0.45))
			c.draw_arc(mid + Vector2(0, -3) * k, 11.0 * k, 0, TAU, 24, light, 2.0 * k, true)
			c.draw_rect(Rect2(mid + Vector2(-5, 7) * k, Vector2(10, 7) * k), Color(col, 0.45), true)
			_flake(c, mid + Vector2(0, -3) * k, 6.0 * k, WHITE, 1.8 * k)
		"frost_honed_rime":   # Honed Rime: a rimed blade drawn across a whetstone, frost flying off
			c.draw_colored_polygon(_p(mid, k, [Vector2(-16, 6), Vector2(8, 6), Vector2(12, 14), Vector2(-12, 14)]), Color(0.42, 0.42, 0.46))
			c.draw_line(mid + Vector2(-16, 6) * k, mid + Vector2(8, 6) * k, Color(0.7, 0.7, 0.75), 1.6 * k, true)
			c.draw_line(mid + Vector2(-13, 4) * k, mid + Vector2(15, -14) * k, Color(0.9, 0.92, 0.97), 3.6 * k, true)
			c.draw_line(mid + Vector2(-13, 4) * k, mid + Vector2(15, -14) * k, light, 1.3 * k, true)
			c.draw_line(mid + Vector2(-16, 0) * k, mid + Vector2(-10, 8) * k, col, 3.0 * k, true)
			for p in [Vector2(-3, -11), Vector2(5, 0), Vector2(14, -3)]:
				_flake(c, mid + (p as Vector2) * k, 3.0 * k, WHITE, 1.4 * k)
		"frost_hoarfrost":   # Deep Hoarfrost: crystal cluster
			for sh in [[Vector2(0, -16), Vector2(5, -2), Vector2(0, 12), Vector2(-5, -2)],
					[Vector2(-10, -6), Vector2(-5, 2), Vector2(-8, 12), Vector2(-13, 3)],
					[Vector2(10, -6), Vector2(13, 3), Vector2(8, 12), Vector2(5, 2)]]:
				var pts := _p(mid, k, sh)
				c.draw_colored_polygon(pts, Color(col, 0.75))
				pts.append(pts[0])
				c.draw_polyline(pts, WHITE, 1.3 * k, true)
		"frost_hoarfrost_burst":   # Brittle Rime: cracked crystal bursting
			var hex := PackedVector2Array()
			for i in 6:
				var a := TAU * i / 6.0 + PI / 6.0
				hex.append(mid + Vector2(cos(a), sin(a)) * 10.0 * k)
			c.draw_colored_polygon(hex, Color(col, 0.5))
			c.draw_polyline(_p(mid, k, [Vector2(-3, -9), Vector2(1, -2), Vector2(-2, 3), Vector2(2, 9)]), WHITE, 1.8 * k, true)
			for i in 6:
				var a := TAU * i / 6.0
				var d := Vector2(cos(a), sin(a))
				c.draw_colored_polygon(PackedVector2Array([mid + d * 13.0 * k, mid + d * 17.0 * k + d.orthogonal() * 2.0 * k,
					mid + d * 17.0 * k - d.orthogonal() * 2.0 * k]), light)
		"frost_clean_break":   # Clean Break: an ice block snapped in two, a drop of rage coming back out
			c.draw_colored_polygon(_p(mid, k, [Vector2(-16, -4), Vector2(-4, -8), Vector2(-3, 13), Vector2(-15, 13)]), Color(col, 0.75))
			c.draw_colored_polygon(_p(mid, k, [Vector2(4, -8), Vector2(16, -4), Vector2(15, 13), Vector2(3, 13)]), Color(col, 0.75))
			c.draw_polyline(_p(mid, k, [Vector2(-16, -4), Vector2(-4, -8), Vector2(-3, 13)]), WHITE, 1.5 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(16, -4), Vector2(4, -8), Vector2(3, 13)]), WHITE, 1.5 * k, true)
			_drop(c, mid + Vector2(0, -7) * k, 0.55 * k, Color(0.85, 0.2, 0.15), WHITE, k)
			c.draw_polyline(_p(mid, k, [Vector2(-3, 6), Vector2(0, 2), Vector2(3, 6)]), WHITE, 1.8 * k, true)
			c.draw_line(mid + Vector2(0, 2) * k, mid + Vector2(0, 11) * k, WHITE, 1.8 * k, true)
		"frost_piercing_cold":   # Piercing Cold: a spike driven clean through a frozen block
			c.draw_rect(Rect2(mid + Vector2(-9, -9) * k, Vector2(18, 18) * k), Color(col, 0.5), true)
			c.draw_rect(Rect2(mid + Vector2(-9, -9) * k, Vector2(18, 18) * k), light, false, 1.5 * k)
			_shard(c, mid + Vector2(17, -15) * k, Vector2(1, -0.9).normalized(), 30.0 * k, 4.0 * k, Color(0.9, 0.95, 1.0), WHITE, k)
			for a in [0.4, 1.6]:
				var d := Vector2(cos(a), sin(a))
				c.draw_line(mid + (Vector2(4, -3) + d * 3.0) * k, mid + (Vector2(4, -3) + d * 9.0) * k, WHITE, 1.4 * k, true)
		"frost_dot_duration":   # Lingering Frost: hourglass with snow
			c.draw_line(mid + Vector2(-9, -14) * k, mid + Vector2(9, -14) * k, light, 2.5 * k, true)
			c.draw_line(mid + Vector2(-9, 14) * k, mid + Vector2(9, 14) * k, light, 2.5 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(-7, -13), Vector2(0, 0), Vector2(-7, 13)]), light, 1.8 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(7, -13), Vector2(0, 0), Vector2(7, 13)]), light, 1.8 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-6, 12), Vector2(6, 12), Vector2(0, 5)]), WHITE)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-5, -11), Vector2(5, -11), Vector2(0, -6)]), Color(WHITE, 0.6))
		"frost_cold_snap":   # Cold Snap: stopwatch snapped short by ice
			_clock(c, mid + Vector2(0, 2) * k, 12.0 * k, light, k)
			c.draw_rect(Rect2(mid + Vector2(-3, -15) * k, Vector2(6, 4) * k), light, true)
			c.draw_line(mid + Vector2(0, 2) * k, mid + Vector2(0, -6) * k, WHITE, 2.0 * k, true)
			c.draw_line(mid + Vector2(0, 2) * k, mid + Vector2(6, 5) * k, WHITE, 2.0 * k, true)
			_shard(c, mid + Vector2(15, 14) * k, Vector2(1, 1).normalized(), 9.0 * k, 3.0 * k, Color(col, 0.9), WHITE, k)
		"frost_splinter":   # Splintering: a shard hitting ice and splitting in two
			c.draw_rect(Rect2(mid + Vector2(-2, -12) * k, Vector2(7, 24) * k), Color(col, 0.55), true)
			_shard(c, mid + Vector2(-3, 0) * k, Vector2(1, 0), 13.0 * k, 3.5 * k, Color(col, 0.9), WHITE, k)
			_shard(c, mid + Vector2(16, -10) * k, Vector2(1, -0.8).normalized(), 9.0 * k, 2.5 * k, light, WHITE, k)
			_shard(c, mid + Vector2(16, 10) * k, Vector2(1, 0.8).normalized(), 9.0 * k, 2.5 * k, light, WHITE, k)
		"frost_shardstorm":   # Shardstorm: shards whirling around
			c.draw_arc(mid, 12.0 * k, 0.3, 5.3, 20, Color(light, 0.6), 1.6 * k, true)
			for i in 5:
				var a := TAU * i / 5.0
				var at := mid + Vector2(cos(a), sin(a)) * 12.0 * k
				var tangent := Vector2(-sin(a), cos(a))
				_shard(c, at + tangent * 4.0 * k, tangent, 8.0 * k, 2.5 * k, Color(col, 0.9), WHITE, k)
			c.draw_circle(mid, 3.0 * k, WHITE)
		"frost_shield_armor":   # Hardened Frost: shield plated with ice bricks
			_shield(c, mid, k, Color(col, 0.35), light)
			for y in [-6.0, 0.0, 6.0]:
				c.draw_line(mid + Vector2(-9, y) * k, mid + Vector2(9, y) * k, WHITE, 1.3 * k, true)
			for p in [Vector2(-3, -9), Vector2(3, -3), Vector2(-3, 3), Vector2(3, 9)]:
				c.draw_line(mid + (p as Vector2) * k, mid + ((p as Vector2) + Vector2(0, 3)) * k, WHITE, 1.3 * k, true)
		"frost_slow_threat":   # Chilling Presence: glaring eye over frost
			c.draw_colored_polygon(_p(mid, k, [Vector2(-15, -2), Vector2(-7, -9), Vector2(7, -9), Vector2(15, -2),
				Vector2(7, 5), Vector2(-7, 5)]), Color(col, 0.35))
			c.draw_circle(mid + Vector2(0, -2) * k, 5.5 * k, light)
			c.draw_circle(mid + Vector2(0, -2) * k, 2.5 * k, Color(0.9, 0.2, 0.15))
			c.draw_line(mid + Vector2(-12, -13) * k, mid + Vector2(-4, -10) * k, light, 2.0 * k, true)
			c.draw_line(mid + Vector2(12, -13) * k, mid + Vector2(4, -10) * k, light, 2.0 * k, true)
			_flake(c, mid + Vector2(0, 11) * k, 4.5 * k, WHITE, 1.5 * k)
		"frost_slow_dr":   # Numbing Cold: a blow stopped by an ice wall
			c.draw_rect(Rect2(mid + Vector2(3, -15) * k, Vector2(8, 30) * k), Color(col, 0.7), true)
			c.draw_rect(Rect2(mid + Vector2(3, -15) * k, Vector2(8, 30) * k), WHITE, false, 1.4 * k)
			c.draw_line(mid + Vector2(-16, 0) * k, mid + Vector2(-2, 0) * k, Color(0.85, 0.85, 0.9), 3.0 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(1, 0), Vector2(-5, -4), Vector2(-5, 4)]), Color(0.85, 0.85, 0.9))
			for a in [-0.7, 0.7]:
				c.draw_line(mid + Vector2(-1, 0) * k, mid + (Vector2(-1, 0) + Vector2(-cos(a), sin(a)) * 6.0) * k, Color(1, 0.6, 0.4), 1.5 * k, true)
		"frost_ice_floe":   # Ice Floe: a floe sliding on water, with a burst of speed
			for i in 3:
				var y := 9.0 + i * 3.5
				c.draw_arc(mid + Vector2(-8 + i * 6, y) * k, 4.0 * k, PI, TAU, 8, Color(col, 0.6), 1.4 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-10, 4), Vector2(-6, -4), Vector2(8, -6), Vector2(13, 2), Vector2(6, 7)]), Color(col, 0.8))
			c.draw_polyline(_p(mid, k, [Vector2(-10, 4), Vector2(-6, -4), Vector2(8, -6), Vector2(13, 2)]), WHITE, 1.5 * k, true)
			for y in [-12.0, -7.0]:
				c.draw_line(mid + Vector2(-16, y) * k, mid + Vector2(-6, y) * k, light, 1.8 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(6, -16), Vector2(12, -12), Vector2(6, -8)]), WHITE, 2.0 * k, true)
		"frost_shatterpoint":   # Shatterpoint: a shell cracking from one bright point
			c.draw_arc(mid, 13.0 * k, 0, TAU, 28, Color(light, 0.8), 2.0 * k, true)
			var hit := mid + Vector2(3, -3) * k
			for a in [0.3, 1.5, 2.6, 3.8, 5.0]:
				var d := Vector2(cos(a), sin(a))
				c.draw_polyline(PackedVector2Array([hit, hit + (d * 6.0 + d.orthogonal() * 2.0) * k, hit + d * 13.0 * k]), WHITE, 1.5 * k, true)
			for i in 4:
				var a := TAU * i / 4.0 + 0.6
				var d := Vector2(cos(a), sin(a))
				c.draw_colored_polygon(PackedVector2Array([mid + d * 16.0 * k, mid + d * 19.0 * k + d.orthogonal() * 2.0 * k,
					mid + d * 19.0 * k - d.orthogonal() * 2.0 * k]), light)
			c.draw_circle(hit, 3.0 * k, WHITE)
		"frost_pinning_frost":   # Pinning Frost: an arrow driven into the ground through a ring of frost
			c.draw_line(mid + Vector2(-17, 13) * k, mid + Vector2(17, 13) * k, Color(col, 0.6), 2.5 * k, true)
			c.draw_arc(mid + Vector2(-2, 13) * k, 10.0 * k, PI, TAU, 14, light, 1.8 * k, true)
			c.draw_line(mid + Vector2(12, -17) * k, mid + Vector2(-2, 11) * k, WOOD, 3.0 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-4, 15), Vector2(-5, 6), Vector2(2, 8)]), WHITE)
			c.draw_line(mid + Vector2(12, -17) * k, mid + Vector2(16, -11) * k, light, 2.0 * k, true)
			c.draw_line(mid + Vector2(12, -17) * k, mid + Vector2(6, -14) * k, light, 2.0 * k, true)
			_flake(c, mid + Vector2(-11, -6) * k, 5.0 * k, WHITE, 1.4 * k)
		"frost_third_bite":   # Third Bite: three fangs of ice, the third the biggest
			_shard(c, mid + Vector2(-12, 6) * k, Vector2(0, 1), 12.0 * k, 3.0 * k, Color(col, 0.7), light, k)
			_shard(c, mid + Vector2(-2, 9) * k, Vector2(0, 1), 16.0 * k, 3.5 * k, Color(col, 0.85), light, k)
			_shard(c, mid + Vector2(10, 15) * k, Vector2(0, 1), 26.0 * k, 5.0 * k, Color(0.9, 0.95, 1.0), WHITE, k)
			c.draw_line(mid + Vector2(-17, -11) * k, mid + Vector2(17, -11) * k, light, 2.2 * k, true)
		"frost_thick_hide":   # Thick Hide: a doubled hide with a clock on it (ready sooner)
			_shield(c, mid + Vector2(-3, -1) * k, k * 1.05, Color(col, 0.45), light)
			_shield(c, mid + Vector2(2, 2) * k, k * 0.8, col.darkened(0.25), WHITE)
			_clock(c, mid + Vector2(2, 1) * k, 6.0 * k, WHITE, k)
			c.draw_line(mid + Vector2(2, 1) * k, mid + Vector2(2, -3) * k, WHITE, 1.5 * k, true)
			c.draw_line(mid + Vector2(2, 1) * k, mid + Vector2(5, 2) * k, WHITE, 1.5 * k, true)
		"frost_hard_freeze":   # Hard Freeze: a figure locked in a block of ice, an hourglass beside it
			c.draw_rect(Rect2(mid + Vector2(-15, -13) * k, Vector2(19, 27) * k), Color(col, 0.55), true)
			c.draw_rect(Rect2(mid + Vector2(-15, -13) * k, Vector2(19, 27) * k), WHITE, false, 1.6 * k)
			c.draw_circle(mid + Vector2(-5.5, -5) * k, 3.2 * k, Color(0.05, 0.1, 0.16))
			c.draw_line(mid + Vector2(-5.5, -2) * k, mid + Vector2(-5.5, 9) * k, Color(0.05, 0.1, 0.16), 4.0 * k, true)
			c.draw_line(mid + Vector2(-12, -10) * k, mid + Vector2(-8, -6) * k, WHITE, 1.3 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(8, -10), Vector2(16, -10), Vector2(12, -2)]), light)
			c.draw_colored_polygon(_p(mid, k, [Vector2(8, 8), Vector2(16, 8), Vector2(12, 0)]), WHITE)
			c.draw_line(mid + Vector2(7, -11) * k, mid + Vector2(17, -11) * k, WHITE, 1.6 * k, true)
			c.draw_line(mid + Vector2(7, 9) * k, mid + Vector2(17, 9) * k, WHITE, 1.6 * k, true)
		"frost_instinct":   # Frozen Instinct: a Frost Bolt leaping out of an ice block
			c.draw_rect(Rect2(mid + Vector2(-15, 2) * k, Vector2(13, 13) * k), Color(col, 0.55), true)
			c.draw_rect(Rect2(mid + Vector2(-15, 2) * k, Vector2(13, 13) * k), WHITE, false, 1.3 * k)
			c.draw_line(mid + Vector2(-6, 4) * k, mid + Vector2(2, -4) * k, Color(light, 0.6), 3.0 * k, true)
			c.draw_circle(mid + Vector2(7, -8) * k, 7.0 * k, col)
			c.draw_circle(mid + Vector2(7, -8) * k, 3.5 * k, WHITE)
			for p in [Vector2(15, 4), Vector2(-4, -14)]:
				var at := mid + (p as Vector2) * k
				c.draw_line(at + Vector2(-3, 0) * k, at + Vector2(3, 0) * k, WHITE, 1.4 * k, true)
				c.draw_line(at + Vector2(0, -3) * k, at + Vector2(0, 3) * k, WHITE, 1.4 * k, true)
		"frost_glacial_heart":   # Glacial Heart: a faceted ice heart
			var heart := PackedVector2Array()
			for i in 24:
				var t := TAU * i / 24.0
				var x := 16.0 * pow(sin(t), 3)
				var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
				heart.append(mid + Vector2(x, y + 1.0) * 0.85 * k)
			c.draw_colored_polygon(heart, Color(col, 0.75))
			heart.append(heart[0])
			c.draw_polyline(heart, WHITE, 1.6 * k, true)
			c.draw_line(mid + Vector2(0, -6) * k, mid + Vector2(0, 12) * k, Color(WHITE, 0.7), 1.2 * k, true)
			c.draw_line(mid + Vector2(-9, -6) * k, mid + Vector2(0, 4) * k, Color(WHITE, 0.5), 1.2 * k, true)
			c.draw_line(mid + Vector2(9, -6) * k, mid + Vector2(0, 4) * k, Color(WHITE, 0.5), 1.2 * k, true)
		"frost_deep_freeze":   # Deep Freeze: a body frozen in an ice block
			c.draw_colored_polygon(_p(mid, k, [Vector2(-12, -9), Vector2(-5, -15), Vector2(13, -15), Vector2(13, 8),
				Vector2(6, 15), Vector2(-12, 15)]), Color(col, 0.55))
			c.draw_polyline(_p(mid, k, [Vector2(-12, -9), Vector2(6, -9), Vector2(6, 15)]), WHITE, 1.4 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(6, -9), Vector2(13, -15)]), WHITE, 1.4 * k, true)
			c.draw_circle(mid + Vector2(-3, -2) * k, 3.0 * k, Color(0.15, 0.25, 0.4))
			c.draw_line(mid + Vector2(-3, 1) * k, mid + Vector2(-3, 9) * k, Color(0.15, 0.25, 0.4), 2.5 * k, true)
			c.draw_line(mid + Vector2(-8, 4) * k, mid + Vector2(2, 4) * k, Color(0.15, 0.25, 0.4), 2.0 * k, true)
