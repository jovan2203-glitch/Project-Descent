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
	var opts := Talents.options_of(id)
	if not opts.is_empty():
		return opts.all(func(o): return has_icon(o))   # a choice slot: both of its talents
	return ICONED.has(_key_of(id))

static func _key_of(id: String) -> String:
	for key in ICONED:
		if Talents.id_for_key(key) == id:
			return key
	return ""

## Every talent key with a picture below.
const ICONED := ["frost_deep_cracks", "frost_cold_spread", "frost_slow_runoff", "frost_shard_spray", "frost_splinterheal", "frost_wide_lattice",
	"frost_haste", "frost_cold_draw", "frost_black_ice", "frost_clean_shatter", "frost_cold_harvest",
	"frost_thin_ice", "frost_absorb", "frost_shard_proc", "frost_bolt_cast",
	"frost_discipline", "frost_chilled_dmg", "frost_int_sp", "frost_honed_rime",
	"frost_hoarfrost", "frost_hoarfrost_burst", "frost_clean_break", "frost_piercing_cold",
	"frost_long_chill", "frost_cold_snap", "frost_splinter", "frost_shardstorm", "frost_shield_armor",
	"frost_slow_threat", "frost_slow_dr", "frost_glacial_heart", "frost_deep_freeze",
	"frost_ice_floe", "frost_shatterpoint", "frost_instinct",
	"frost_pinning_frost", "frost_third_bite", "frost_hard_freeze",
	"frost_cold_sweep", "frost_ice_fall", "frost_long_dark", "frost_glinting_rime", "frost_biting_hold", "frost_long_glaze",
	"frost_packed_ice", "frost_deep_tremor", "frost_turned_backs", "frost_cold_fury", "frost_regelation", "frost_old_ice", "frost_deep_strata",
	"frost_glass_cold", "frost_ice_needles", "frost_snowdrift", "frost_cold_front", "frost_cold_well", "frost_thaw_water",
	"frost_last_shelter", "frost_cold_hands", "frost_meltdown", "frost_long_frost", "frost_shard_reach", "frost_snowmelt",
	"frost_layered_veil", "frost_ice_bath", "frost_deep_snow", "frost_cold_rush", "frost_close_weave", "frost_frozen_hearth",
	"frost_sharp_glaze", "frost_glaze_hunger", "frost_hard_glaze", "frost_splitting_cold", "frost_shiver", "frost_rime_grip",
	"frost_cold_swing", "frost_thaw_strike", "frost_quick_rime", "frost_frost_heave", "frost_lasting_ice", "frost_deep_ice",
	"frost_spent_ice", "frost_hoar_coat", "frost_cold_retort", "frost_rime_pressure", "frost_reforming", "frost_cracking_ice",
	"frost_steady_footing", "frost_rime_armor", "frost_full_strata", "frost_frozen_quarry", "frost_frost_fletching", "frost_rime_tips",
	"frost_marked_ice", "frost_winter_quiver", "frost_splitting_arrow", "frost_deep_pin", "frost_numb_prey", "frost_swift_ice",
	"frost_ice_hunger", "frost_cold_eye", "frost_sleet_arrows", "frost_bitter_hunt", "frost_winter_coat",
	"fire_smoldering_focus", "fire_tempered_flame", "fire_afterburn",
	"fire_banked_coals", "fire_volley_targets", "fire_damped_embers", "fire_wild_embers",
	"fire_pressure_valve", "fire_heat_shimmer", "fire_thick_slag", "fire_hot_iron", "fire_blowback", "fire_clinker",
	"fire_warm_start", "fire_fresh_tinder", "fire_afterglow", "fire_long_coat", "fire_fed_furnace",
	"fire_slow_cooling", "fire_long_burn", "fire_spreading_fire", "fire_stoked_kiln", "fire_slag_mending",
	"fire_deep_brand", "fire_stoked_breath", "fire_warm_blood", "fire_white_heat",
	"fire_flash_point", "fire_forge_hardened", "fire_lingering_embers", "fire_controlled_burn",
	"fire_lean_fuel", "fire_hold_the_heat", "fire_long_focus", "fire_clean_burn", "fire_big_spend", "fire_low_flame", "fire_stay_lit", "fire_hard_crust", "fire_set_hard", "fire_red_iron", "fire_marked_iron", "fire_fuel_the_forge", "fire_deep_slag", "fire_riveted", "fire_heavy_hammer", "fire_glowing_seams", "fire_long_shell", "fire_spatter", "fire_quick_temper", "fire_molten_heart", "fire_bright_sparks", "fire_spark_bite", "fire_hard_quench", "fire_wide_flare", "fire_banked_fire", "fire_hammer_rhythm", "fire_fold_again", "fire_deep_sear", "fire_overheat", "fire_steady_arm", "fire_long_blast", "fire_cold_steel", "fire_quick_forge", "fire_molten_edge", "fire_sticky_pitch", "fire_light_string", "fire_big_flash", "fire_dripping", "fire_double_coat", "fire_hot_shafts", "fire_second_light", "fire_ember_bed", "fire_wide_rain", "fire_fuel_run", "fire_patient_fire", "fire_kindle_pack", "fire_long_brush", "fire_steady_bow", "fire_clean_shot", "fire_fire_line", "fire_pitch_black",
	"lightning_quick_charge", "lightning_conductive", "lightning_deep_reserves", "lightning_running_on_empty",
	"lightning_running_start", "lightning_third_beat", "lightning_redline",
	"lightning_long_reach", "lightning_counter_charge", "lightning_closed_circuit", "lightning_quick_wrists",
	"lightning_tempo", "lightning_quick_fuse", "lightning_tight_coil", "lightning_earth_return",
	"lightning_conductor", "lightning_high_voltage",
	"lightning_standing_charge", "lightning_whip_crack", "lightning_storm_cycle",
	"lightning_live_current", "lightning_charged_strikes", "lightning_storm_tempered", "lightning_quick_step",
	"lightning_calm_current", "lightning_overflow", "lightning_parting_spark", "lightning_hot_wire",
	"lightning_second_stroke", "lightning_snap_shot", "lightning_rod", "lightning_loaded_quiver",
	"arcane_seventh_sigil", "arcane_long_step", "arcane_frayed", "arcane_etched_darts", "arcane_chain_reaction",
	"arcane_polished_glass", "arcane_aftershock",
	"arcane_sharp_edges", "arcane_clockwork", "arcane_spare_copy", "arcane_second_self", "arcane_wide_rings",
	"arcane_on_the_beat", "arcane_head_count", "arcane_light_feet", "arcane_empty_room", "arcane_bent_light",
	"arcane_understudy", "arcane_good_likeness",
	"arcane_standing_ovation", "arcane_long_memory", "arcane_clean_lines", "arcane_second_showing",
	"arcane_practiced_hand", "arcane_heavy_hand", "arcane_curtain_call", "arcane_no_loose_ends", "arcane_time_signature",
	"arcane_full_house", "arcane_dress_rehearsal", "arcane_silvered", "arcane_running_clock", "arcane_fine_edge",
	"arcane_pinned_in_time", "arcane_thrifty_mind", "arcane_wound_up", "arcane_sharp_mind", "arcane_clock_hands", "arcane_moving_parts",
	"arcane_second_hand", "arcane_on_the_dot", "arcane_turning_gears", "arcane_unwinding", "arcane_glass_armor", "arcane_quick_answer",
	"arcane_glass_dust", "arcane_last_copy", "arcane_crowded_room", "arcane_fresh_trace", "arcane_keen_cuts", "arcane_quick_cuts",
	"arcane_twin_blades", "arcane_full_stage", "arcane_final_act", "arcane_curtain_rise", "arcane_spare_moment",
	"arcane_quick_study", "arcane_two_minds", "arcane_echo", "arcane_mirror_finish", "arcane_overtime",
	"arcane_light_touch", "arcane_slipstream", "arcane_borrowed_time", "arcane_keep_moving", "arcane_full_crowd",
	"fire_feed_the_flames", "fire_last_ember", "fire_tempered",
	"lightning_change_of_pace", "lightning_spillover", "lightning_dig_in",
	"lightning_long_leap", "lightning_charged_air", "lightning_feedback", "lightning_lingering_storm", "lightning_crackle",
	"lightning_deep_draw", "lightning_afterflow", "lightning_snap_cast", "lightning_full_circuit", "lightning_keen_current",
	"lightning_edge_current", "lightning_sparking_swings", "lightning_afterspark", "lightning_built_charge", "lightning_light_load",
	"lightning_spinning_up", "lightning_charged_steel", "lightning_short_fuse", "lightning_storm_dance", "lightning_spark_guard",
	"lightning_loud_steel", "lightning_charged_guard", "lightning_draw_down", "lightning_ring_true", "lightning_hard_lessons",
	"lightning_wide_current", "lightning_charged_shell", "lightning_hard_stare", "lightning_eye_of_the_storm",
	"lightning_back_to_the_wall", "lightning_storm_anchor", "lightning_cut_the_line", "lightning_fresh_charge", "lightning_static_build",
	"shadow_tainted_steel", "shadow_slow_death", "shadow_wasting", "shadow_finish_it", "shadow_spite",
	"shadow_carrion", "shadow_inevitable", "shadow_seep", "shadow_interest",
	"shadow_next_of_kin", "shadow_bitter_end", "shadow_no_floor", "shadow_small_change", "shadow_rot_through",
	"shadow_running_over", "shadow_bite_down",
	"shadow_thick_blood", "shadow_feeding_frenzy", "shadow_lean_and_hungry", "shadow_fed", "shadow_worked_up",
	"shadow_out_of_the_hole", "shadow_long_night", "shadow_take_it_with_you", "shadow_pack_leader",
	"shadow_still_wet", "shadow_share_the_kill", "shadow_pincer", "shadow_again", "shadow_stand_over",
	"shadow_slipped_leash",
	"shadow_first_stitch", "shadow_long_thread", "shadow_spare_spool", "shadow_full_harness", "shadow_taking_the_weight",
	"shadow_steady_hands", "shadow_heave", "shadow_long_drop", "shadow_snap_back", "shadow_give_and_take",
	"shadow_many_hands", "shadow_lean_on_me", "shadow_left_hanging",
	"shadow_deep_call", "shadow_ill_will", "shadow_hard_pull", "shadow_wide_pack",
	"shadow_held_open", "shadow_hungry_dark", "shadow_many_mouths", "shadow_shut_tight", "shadow_grasping_hands", "shadow_paid_in_full",
	"shadow_snarl", "shadow_blood_up", "shadow_fetch", "shadow_scent_of_blood",
	"shadow_quick_hands", "shadow_three_ply", "shadow_pass_it_on", "shadow_hold_fast", "shadow_fair_trade", "shadow_firm_grip",
	"shadow_loose_weave", "shadow_nothing_wasted",
	"holy_mercys_ear", "holy_many_voices", "holy_watchful", "holy_key_change", "holy_open_doors",
	"holy_grace", "holy_burnished", "holy_steadfast", "holy_long_note", "holy_overflowing", "holy_penitent", "holy_zeal",
	"holy_clear_mind", "holy_sheltering_light", "holy_long_glass", "holy_second_breath", "holy_heavy_chain", "holy_absolution",
	"holy_unbroken", "holy_glimmering", "holy_steady_aim", "holy_swelling_chorus", "holy_quick_lance", "holy_full_quiver",
	"holy_wide_break", "holy_watchful_eye", "holy_bright_motes", "holy_steady_ray", "holy_censers_weight",
	"holy_sunsteel", "holy_radiance", "holy_mote_magnet", "holy_bright_barrier", "holy_lingering_light", "holy_wide_arc",
	"holy_deep_pour", "holy_clear_glass", "holy_deep_crystal", "holy_sharp_facets", "holy_wide_burst",
	"holy_prismatic_burst", "holy_quick_realign", "holy_wide_fan", "holy_split_light", "holy_bright_quiver", "holy_deep_burn",
	"holy_long_volley",
	"nature_running_herd", "nature_hunting_party", "nature_thick_sap", "nature_lingering_venom",
	"nature_rough_bark", "nature_green_thumb", "nature_undergrowth", "nature_clinging_vines", "nature_long_fangs", "nature_hungry_venom",
	"nature_spring_trap", "nature_soaked_through", "nature_old_bark", "nature_morning_dew", "nature_return_flight", "nature_deep_bloom",
	"nature_evergreen", "nature_rising_sap", "nature_crushing_grip", "nature_broad_fist",
	"nature_spreading_roots", "nature_firm_hold", "nature_wide_awake", "nature_old_growth", "nature_rich_soil", "nature_compost",
	"nature_bramble_burst", "nature_fertile_ground", "nature_second_growth", "nature_circling_hawk", "nature_overgrown",
	"martial_hard_break", "martial_well_drilled", "martial_wide_cleave", "martial_keen_edge", "martial_twice_over", "martial_rattled",
	"martial_turning_wheel", "martial_clean_kill", "martial_in_and_out", "martial_barbed", "martial_steady_pace", "martial_mix_it_up",
	"martial_in_the_zone", "martial_conditioning", "martial_catch_your_breath", "martial_pinned_down",
	"martial_soak_it_up", "martial_tight_clinch", "martial_soft_catch", "martial_knockout", "martial_wide_stance",
	"martial_scar_tissue", "martial_full_draw", "martial_broadhead", "martial_patience", "martial_extra_arrows", "martial_no_letup",
	"martial_easy_release", "martial_keen_eye",
	"martial_iron_grip", "martial_heavy_hands", "martial_fresh_steel", "martial_sharp_fragments", "martial_weight_behind_it", "martial_breaking_point",
	"martial_ringing_blows", "martial_off_balance", "martial_spare_parts", "martial_big_swing", "martial_clean_swap", "martial_gather_pace",
	"martial_thrift", "martial_spare_knives", "martial_thrown_weight", "martial_close_work", "martial_fresh_legs", "martial_deep_flow",
	"martial_hot_start", "martial_easy_pickings", "martial_footloose", "martial_finish_strong", "martial_cold_read", "martial_light_fingers",
	"martial_pressure_point", "martial_weapon_training", "martial_keen_strikes", "martial_hardy", "martial_footing", "martial_grit",
	"martial_quick_feet", "martial_heavy_bag", "martial_calluses", "martial_slow_burn", "martial_counter_puncher", "martial_crowd_work",
	"martial_get_up", "martial_bad_intentions", "martial_hardened", "martial_iron_chin", "martial_last_laugh", "martial_back_up",
	"martial_ground_game", "martial_quick_release", "martial_deep_hold", "martial_on_a_roll", "martial_lucky_shot", "martial_long_range",
	"martial_waiting_game", "martial_clean_release", "martial_long_streak", "martial_second_arrow", "martial_hard_target", "martial_run_it_back",
	"martial_hold_steady",
	"nature_thick_mulch", "nature_well_rotted", "nature_long_roots", "nature_tight_weave", "nature_old_roots",
	"nature_steady_weave", "nature_harvest", "nature_leaf_litter", "nature_hunted", "nature_lush", "nature_quickening",
	"nature_second_bud", "nature_long_bloom", "nature_heavy_petals", "nature_soft_weave", "nature_pollen", "nature_canopy",
	"nature_in_full_flower", "nature_close_herd", "nature_new_shoots", "nature_nectar", "nature_patient_hands",
	"nature_wide_grove", "nature_morning_mist",
	"nature_startle", "nature_pack_hunter", "nature_tending", "nature_food_chain", "nature_hibernate",
	"nature_groundswell", "nature_heavy_limbs", "nature_long_sap", "nature_sap_run", "nature_taproot", "nature_long_limbs",
	"nature_called_out", "nature_creaking_bark", "nature_brimming", "nature_woodgrain", "nature_old_oak",
	"nature_slow_acting", "nature_virulent", "nature_fresh_host", "nature_double_dose", "nature_quick_venom", "nature_swollen",
	"nature_full_brew", "nature_full_glands", "nature_spare_venom", "nature_running_venom", "nature_dragging_feet",
	"nature_dripping_tips", "nature_final_bite", "nature_first_bite",
	"holy_choir_loft", "holy_night_watch", "holy_warded_song", "holy_rising_voice", "holy_long_echo", "holy_tender_mercy",
	"holy_full_voice", "holy_held_note", "holy_mercy_seat", "holy_breath_between",
	"holy_offering", "holy_full_censer", "holy_heavy_smoke", "holy_heavy_motes", "holy_turned_aside", "holy_cloying_smoke",
	"holy_shaken_loose", "holy_ringing_censer", "holy_hold_the_line",
	"holy_candlelight", "holy_first_light",
	"holy_thirsty_glass", "holy_bright_shards", "holy_polish", "holy_aftershine", "holy_lifeline", "holy_focused_light",
	"holy_last_glint", "holy_full_glass", "holy_brilliance",
	"holy_gilded", "holy_pinpoint", "holy_lined_up", "holy_light_draw", "holy_full_gold", "holy_gilt_tips", "holy_dazzle", "holy_sundown"]

## Pictures kept from talents that were folded into their abilities, free for new
## talents (draw one under its new key). Not given to any talent today.
const SPARE := ["frost_thick_hide", "frost_marked_prey", "lightning_honed_edge",
	"arcane_deep_well", "arcane_loud_exit", "shadow_cut_short", "nature_quick_return", "nature_big_herd", "martial_deep_pockets",
	"martial_round_two", "holy_last_rites", "holy_swift_light", "holy_high_censer"]

## `round_bg`: a round dark backing instead of the square one (the seals of the
## ribbon layout, scripts/ui/ribbon_drawer.gd).
static func draw(c: Control, id: String, round_bg := false) -> void:
	if not has_icon(id):
		return
	var s := c.size
	var mid := s / 2.0
	var k: float = minf(s.x, s.y) / 52.0
	var col := Categories.color(Talents.category_of(id))
	var light := col.lightened(0.5)
	var pad := 4.0 * k
	if round_bg:
		# On a wax seal (book-coloured): a near-black disc and brighter strokes, so
		# the picture doesn't sink into the wax.
		var rr := minf(s.x, s.y) / 2.0 - pad * 0.25
		c.draw_circle(mid, rr, col.darkened(0.88))
		c.draw_arc(mid, rr, 0.0, TAU, 28, Color(0, 0, 0, 0.8), 1.5, true)
		light = col.lightened(0.78)
		col = col.lightened(0.4)
	else:
		c.draw_rect(Rect2(Vector2(pad, pad), s - Vector2(pad, pad) * 2.0), col.darkened(0.75), true)
	var opts := Talents.options_of(id)
	if opts.is_empty():
		_draw_key(c, _key_of(id), mid, k, col, light)
		return
	# A choice slot: the talent picked, or both side by side at half size.
	var picked := _picked(opts)
	if picked != "":
		_draw_key(c, _key_of(picked), mid, k, col, light)
		return
	for i in 2:
		_draw_key(c, _key_of(opts[i]), mid + Vector2((i * 2 - 1) * 12.0, 0) * k, k * 0.5, col, light)
	c.draw_line(Vector2(mid.x, pad + 3.0 * k), Vector2(mid.x, s.y - pad - 3.0 * k), Color(light, 0.6), 1.5 * k, true)

## Which talent of a choice slot has points ("" = neither).
static func _picked(opts: Array[String]) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var pd: Node = tree.root.get_node_or_null("PlayerData") if tree else null
	if pd == null:
		return ""
	for o in opts:
		if int(pd.talent_rank(o)) > 0:
			return o
	return ""

# --- Shared bits -------------------------------------------------------------------

static func _p(mid: Vector2, k: float, raw: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in raw:
		out.append(mid + (v as Vector2) * k)
	return out

## A small bolt of lightning, about 20 x `s` tall, centred on `at` (`s` already holds k).
static func _bolt(c: Control, at: Vector2, s: float, col: Color) -> void:
	c.draw_colored_polygon(_p(at, s, [Vector2(3, -10), Vector2(-5, 1), Vector2(-0.5, 1), Vector2(-3, 10), Vector2(5, -2), Vector2(0.5, -2)]), col)

## An Energy cell (a little battery) 10 x 16 centred on `at`, filled to `full` (0-1).
static func _cell(c: Control, at: Vector2, k: float, col: Color, light: Color, full: float) -> void:
	var box := Rect2(at + Vector2(-5, -8) * k, Vector2(10, 16) * k)
	c.draw_rect(box, col.darkened(0.45), true)
	if full > 0.0:
		var h := 16.0 * clampf(full, 0.0, 1.0)
		c.draw_rect(Rect2(at + Vector2(-5, 8 - h) * k, Vector2(10, h) * k), light, true)
	c.draw_rect(box, WHITE, false, 1.4 * k)
	c.draw_rect(Rect2(at + Vector2(-2, -10) * k, Vector2(4, 2) * k), WHITE, true)

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

## A flame about 30 x `s` tall standing on `at` (its base a little below), with a bright core.
static func _fire(c: Control, at: Vector2, s: float, col: Color, core: Color) -> void:
	c.draw_colored_polygon(_p(at, s, [Vector2(0, -15), Vector2(6, -6), Vector2(8, 3), Vector2(5, 9), Vector2(-5, 9), Vector2(-8, 3), Vector2(-6, -6)]), col)
	c.draw_colored_polygon(_p(at, s, [Vector2(0, -6), Vector2(3, 0), Vector2(3, 6), Vector2(-3, 6), Vector2(-3, 0)]), core)

## A star with `points` points, `r` from its middle to a tip.
static func _star(c: Control, at: Vector2, r: float, col: Color, points: int) -> void:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a := PI * i / points - PI / 2.0
		pts.append(at + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.4))
	c.draw_colored_polygon(pts, col)

## An arrow from the bottom left to the top right: shaft, head and fletching.
static func _arrow_line(c: Control, mid: Vector2, k: float, shaft: Color, head: Color) -> void:
	c.draw_line(mid + Vector2(-14, 14) * k, mid + Vector2(9, -9) * k, shaft, 2.5 * k, true)
	c.draw_colored_polygon(_p(mid, k, [Vector2(14, -14), Vector2(6, -10), Vector2(10, -6)]), head)
	c.draw_line(mid + Vector2(-14, 14) * k, mid + Vector2(-17, 8) * k, head, 2.0 * k, true)
	c.draw_line(mid + Vector2(-14, 14) * k, mid + Vector2(-8, 17) * k, head, 2.0 * k, true)

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

## Nature's colours: amber Sap, a Blossom's pink, the three poisons, mana.
const SAP := Color(1.0, 0.72, 0.25)
const PINK := Color(1.0, 0.62, 0.82)
const VENOM := Color(0.4, 0.95, 0.3)
const ASP := Color(1.0, 0.85, 0.25)
const MANA := Color(0.35, 0.6, 1.0)

## A leaf from `at` pointing along `dir`, `length` long.
static func _leaf(c: Control, at: Vector2, dir: Vector2, length: float, fill: Color) -> void:
	var d := dir.normalized()
	var side := d.orthogonal() * length * 0.32
	c.draw_colored_polygon(PackedVector2Array([at, at + d * length * 0.5 + side, at + d * length, at + d * length * 0.5 - side]), fill)
	c.draw_line(at, at + d * length * 0.9, fill.darkened(0.35), maxf(length * 0.06, 1.0), true)

## A Blossom: five petals round a gold middle, `r` across.
static func _blossom(c: Control, at: Vector2, r: float, petal: Color) -> void:
	for i in 5:
		var a := TAU * i / 5.0 - PI / 2.0
		c.draw_circle(at + Vector2(cos(a), sin(a)) * r * 0.55, r * 0.42, petal)
	c.draw_circle(at, r * 0.28, HOLY_GOLD)

## A patch of Mulch on the ground.
static func _patch(c: Control, at: Vector2, k: float, scale: float = 1.0) -> void:
	_ellipse(c, at, Vector2(9, 3.5) * k * scale, WOOD.darkened(0.15), WOOD.lightened(0.25), 1.2 * k)
	for x in [-4.0, 0.0, 4.0]:
		c.draw_circle(at + Vector2(x, -0.5) * k * scale, 1.0 * k * scale, HOLY_GOLD)

## A snake's fang from `top` down `length`, a drop of `drip` at its tip.
static func _fang(c: Control, top: Vector2, length: float, k: float, drip: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([top + Vector2(-3.5, 0) * k, top + Vector2(3.5, 0) * k, top + Vector2(0.5, length) * k, top + Vector2(-0.5, length) * k]), WHITE)
	_drop(c, top + Vector2(0, length + 3.0) * k, 0.28 * k, drip, WHITE, k)

## Vigil's blue.
const VIGIL_BLUE := Color(0.45, 0.7, 1.0)

## A note of song at `at` (its head; the stem goes up), in `col`.
static func _note(c: Control, at: Vector2, k: float, col: Color) -> void:
	_ellipse(c, at, Vector2(3.2, 2.4) * k, col, col, 1.0 * k)
	c.draw_line(at + Vector2(3, 0) * k, at + Vector2(3, -12) * k, col, 1.8 * k, true)
	c.draw_line(at + Vector2(3, -12) * k, at + Vector2(8, -9) * k, col, 1.8 * k, true)

## A mote of light at `at`.
static func _mote(c: Control, at: Vector2, k: float, r: float = 4.5) -> void:
	c.draw_circle(at, r * k, Color(HOLY_GOLD, 0.8))
	c.draw_circle(at, r * 0.45 * k, WHITE)

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
		# --- Holy healer: Choir of One (the ribbon tree's newer talents) ---
		"holy_choir_loft":   # a gallery of small singers raised high, the song reaching more
			c.draw_rect(Rect2(mid + Vector2(-15, 2) * k, Vector2(30, 3) * k), HOLY_GOLD, true)
			for i in 4:
				c.draw_circle(mid + Vector2(-11 + i * 7.3, -3) * k, 2.6 * k, WHITE)
			for i in 3:
				c.draw_arc(mid + Vector2(0, 8) * k, (5.0 + i * 4.0) * k, PI * 0.15, PI * 0.85, 10, Color(WHITE, 0.8 - i * 0.2), 1.6 * k, true)
		"holy_night_watch":   # a moon over a blue ring, a figure safe inside
			c.draw_arc(mid + Vector2(0, 6) * k, 13.0 * k, 0.0, TAU, 24, VIGIL_BLUE, 2.4 * k, true)
			_figure(c, mid + Vector2(0, 8) * k, 6.0 * k, WHITE, 1.6 * k)
			c.draw_circle(mid + Vector2(10, -12) * k, 5.0 * k, WHITE)
			c.draw_circle(mid + Vector2(12, -13) * k, 4.2 * k, col.darkened(0.75))
		"holy_warded_song":   # a note inside a blue shield
			_shield(c, mid, k, Color(VIGIL_BLUE, 0.4), VIGIL_BLUE)
			_note(c, mid + Vector2(-3, 5) * k, k, WHITE)
		"holy_rising_voice":   # notes climbing higher, an arrow up
			for i in 3:
				_note(c, mid + Vector2(-12 + i * 8, 12 - i * 7) * k, k * (0.8 + i * 0.15), HOLY_GOLD if i < 2 else WHITE)
			c.draw_line(mid + Vector2(14, 12) * k, mid + Vector2(14, -10) * k, WHITE, 1.8 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(14, -15), Vector2(18, -9), Vector2(10, -9)]), WHITE)
		"holy_long_echo":   # a boom of light, its echo rings going far
			c.draw_circle(mid + Vector2(-8, 0) * k, 5.0 * k, HOLY_GOLD)
			for i in 3:
				c.draw_arc(mid + Vector2(-8, 0) * k, (9.0 + i * 5.0) * k, -PI * 0.35, PI * 0.35, 10, Color(HOLY_GOLD, 0.9 - i * 0.25), 2.0 * k, true)
		"holy_tender_mercy":   # a gold heart held in an open hand
			c.draw_arc(mid + Vector2(0, 8) * k, 11.0 * k, PI * 0.1, PI * 0.9, 12, WHITE, 3.0 * k, true)
			c.draw_circle(mid + Vector2(-3.5, -4) * k, 4.5 * k, HOLY_GOLD)
			c.draw_circle(mid + Vector2(3.5, -4) * k, 4.5 * k, HOLY_GOLD)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-8, -2.5), Vector2(8, -2.5), Vector2(0, 7)]), HOLY_GOLD)
		"holy_full_voice":   # three booms of the three Hymns, Verses coming back
			var hymn_cols := [HOLY_GOLD, WHITE, VIGIL_BLUE]
			for i in 3:
				c.draw_circle(mid + Vector2(-10 + i * 10, -6) * k, 4.5 * k, hymn_cols[i])
			for i in 3:
				c.draw_rect(Rect2(mid + Vector2(-9 + i * 7, 8) * k, Vector2(4, 6) * k), HOLY_GOLD, true)
		"holy_held_note":   # a note held under a long tie, a clock
			_note(c, mid + Vector2(-8, 8) * k, k, HOLY_GOLD)
			c.draw_arc(mid + Vector2(2, 12) * k, 10.0 * k, PI * 1.15, PI * 1.85, 12, WHITE, 1.6 * k, true)
			_clock(c, mid + Vector2(10, -8) * k, 6.0 * k, WHITE, k)
		"holy_mercy_seat":   # a column of gold light on a low health bar
			c.draw_rect(Rect2(mid + Vector2(-4, -16) * k, Vector2(8, 24) * k), Color(HOLY_GOLD, 0.6), true)
			c.draw_rect(Rect2(mid + Vector2(-1.5, -16) * k, Vector2(3, 24) * k), WHITE, true)
			c.draw_rect(Rect2(mid + Vector2(-14, 11) * k, Vector2(28, 4) * k), Color(0.2, 0.05, 0.06), true)
			c.draw_rect(Rect2(mid + Vector2(-14, 11) * k, Vector2(8, 4) * k), HOUND_RED, true)
		"holy_breath_between":   # a boom, and a drop of mana breathed back in
			c.draw_circle(mid + Vector2(-6, 4) * k, 8.0 * k, Color(HOLY_GOLD, 0.6))
			c.draw_circle(mid + Vector2(-6, 4) * k, 3.5 * k, WHITE)
			_drop(c, mid + Vector2(10, -6) * k, 0.45 * k, MANA, WHITE, k)
			c.draw_arc(mid + Vector2(4, 2) * k, 8.0 * k, -PI * 0.9, -PI * 0.3, 8, Color(WHITE, 0.6), 1.4 * k, true)
		# --- Holy tank: Censer Bearer (the ribbon tree's newer talents) ---
		"holy_offering":   # a censer tipped out, an offering of light in a bowl
			_censer(c, mid + Vector2(-6, -8) * k, k)
			c.draw_arc(mid + Vector2(4, 8) * k, 9.0 * k, 0.0, PI, 12, WHITE, 2.4 * k, true)
			_mote(c, mid + Vector2(4, 8) * k, k, 3.5)
		"holy_full_censer":   # a censer brimming with light, a shield behind it
			_shield(c, mid, k, Color(HOLY_GOLD, 0.25), HOLY_GOLD)
			_censer(c, mid + Vector2(0, 2) * k, k)
		"holy_heavy_smoke":   # thick smoke of light rolling off a censer
			_censer(c, mid + Vector2(-6, 6) * k, k)
			for i in 3:
				c.draw_arc(mid + Vector2(2 + i * 4, -6 - i * 3) * k, (5.0 + i) * k, PI * 0.9, PI * 2.1, 10, Color(HOLY_GOLD, 0.9 - i * 0.2), 2.4 * k, true)
		"holy_heavy_motes":   # one big mote, heavier than the rest
			_mote(c, mid + Vector2(2, 2) * k, k, 9.0)
			_mote(c, mid + Vector2(-12, -10) * k, k, 3.0)
			_mote(c, mid + Vector2(13, -11) * k, k, 3.0)
		"holy_turned_aside":   # a blow glancing off a shield of light, a heal
			_shield(c, mid + Vector2(-3, 0) * k, k, Color(HOLY_GOLD, 0.3), HOLY_GOLD)
			c.draw_line(mid + Vector2(16, -14) * k, mid + Vector2(6, -4) * k, HOUND_RED, 2.4 * k, true)
			c.draw_line(mid + Vector2(6, -4) * k, mid + Vector2(14, 2) * k, Color(HOUND_RED, 0.6), 2.0 * k, true)
			_plus(c, mid + Vector2(12, 12) * k, 3.5 * k, HEAL_GREEN, 2.2 * k)
		"holy_cloying_smoke":   # sweet smoke curling round enemy marks
			for i in 2:
				c.draw_circle(mid + Vector2(-8 + i * 16, 8) * k, 3.5 * k, HOUND_RED)
			c.draw_polyline(_p(mid, k, [Vector2(-14, 2), Vector2(-8, -4), Vector2(-2, 2), Vector2(4, -6), Vector2(10, 0), Vector2(16, -6)]), HOLY_GOLD, 2.6 * k, true)
			c.draw_arc(mid + Vector2(0, -12) * k, 5.0 * k, 0.0, TAU, 12, Color(HOLY_GOLD, 0.6), 1.6 * k, true)
		"holy_shaken_loose":   # a censer shaking, two motes falling free
			_censer(c, mid + Vector2(-4, -6) * k, k)
			for i in 2:
				c.draw_line(mid + Vector2(-14 + i * 18, -10) * k, mid + Vector2(-12 + i * 18, -4) * k, Color(WHITE, 0.6), 1.4 * k, true)
			_mote(c, mid + Vector2(-2, 12) * k, k, 3.5)
			_mote(c, mid + Vector2(8, 10) * k, k, 3.5)
		"holy_ringing_censer":   # a censer ringing as a blow is blocked
			_censer(c, mid + Vector2(-4, 2) * k, k)
			for i in 3:
				c.draw_arc(mid + Vector2(-4, 2) * k, (12.0 + i * 3.5) * k, -PI * 0.3, PI * 0.3, 8, Color(WHITE, 0.8 - i * 0.2), 1.6 * k, true)
		"holy_hold_the_line":   # a line of light on the ground, a figure standing on it, health low
			c.draw_line(mid + Vector2(-16, 8) * k, mid + Vector2(16, 8) * k, HOLY_GOLD, 3.0 * k, true)
			_figure(c, mid + Vector2(0, 0) * k, 7.0 * k, WHITE, 1.8 * k)
			c.draw_rect(Rect2(mid + Vector2(-14, 12) * k, Vector2(28, 4) * k), Color(0.2, 0.05, 0.06), true)
			c.draw_rect(Rect2(mid + Vector2(-14, 12) * k, Vector2(8, 4) * k), HOUND_RED, true)
		# --- Holy: the newer open talents ---
		"holy_candlelight":   # a candle lit from a heal, its flame a spark of harm
			c.draw_rect(Rect2(mid + Vector2(-4, -2) * k, Vector2(8, 16) * k), WHITE.darkened(0.15), true)
			_fire(c, mid + Vector2(0, -8) * k, 0.7 * k, HOLY_GOLD, WHITE)
			_plus(c, mid + Vector2(-12, 8) * k, 3.5 * k, HEAL_GREEN, 2.2 * k)
			_star(c, mid + Vector2(12, -10) * k, 4.5 * k, WHITE, 4)
		"holy_first_light":   # the sun rising over the edge of the world
			c.draw_line(mid + Vector2(-16, 8) * k, mid + Vector2(16, 8) * k, WHITE, 2.0 * k, true)
			c.draw_arc(mid + Vector2(0, 8) * k, 8.0 * k, PI, TAU, 14, HOLY_GOLD, 6.0 * k, true)
			for i in 5:
				var a := PI + PI * (i + 0.5) / 5.0
				c.draw_line(mid + Vector2(0, 8) * k + Vector2(cos(a), sin(a)) * 12.0 * k, mid + Vector2(0, 8) * k + Vector2(cos(a), sin(a)) * 17.0 * k, HOLY_GOLD, 1.8 * k, true)
		# --- Holy healer: Line of Light (the ribbon tree's newer talents) ---
		"holy_thirsty_glass":   # a prism drinking in a beam
			_pane(c, mid + Vector2(4, 0) * k, Vector2(6, 11) * k, Color(WHITE, 0.3), WHITE, 1.6 * k)
			c.draw_line(mid + Vector2(-16, 0) * k, mid + Vector2(-2, 0) * k, HEAL_GREEN, 3.0 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-1, 4), Vector2(9, 4), Vector2(9, 10), Vector2(-1, 10)]), HEAL_GREEN)
		"holy_bright_shards":   # shards of a prism, a drop of mana among them
			for i in 4:
				var a := TAU * i / 4.0 + 0.4
				_shard(c, mid + Vector2(cos(a), sin(a)) * 13.0 * k, Vector2(cos(a), sin(a)), 7.0 * k, 2.6 * k, WHITE, light, k)
			_drop(c, mid, 0.45 * k, MANA, WHITE, k)
		"holy_polish":   # a cloth polishing a prism to a shine
			_pane(c, mid + Vector2(-4, 0) * k, Vector2(6, 11) * k, Color(WHITE, 0.5), WHITE, 1.6 * k)
			c.draw_arc(mid + Vector2(8, 6) * k, 6.0 * k, PI * 0.2, PI * 1.6, 10, HOLY_GOLD, 3.0 * k, true)
			_star(c, mid + Vector2(-8, -10) * k, 4.0 * k, WHITE, 4)
		"holy_aftershine":   # a figure still glowing after a prism burst
			_figure(c, mid + Vector2(0, 2) * k, 8.0 * k, WHITE, 1.8 * k)
			c.draw_arc(mid + Vector2(0, 0) * k, 13.0 * k, 0.0, TAU, 20, Color(HEAL_GREEN, 0.6), 2.0 * k, true)
			for i in 3:
				_shard(c, mid + Vector2(-14 + i * 14, -14) * k, Vector2(0, -1), 5.0 * k, 2.0 * k, WHITE, light, k)
		"holy_lifeline":   # a beam reaching a low health bar
			c.draw_line(mid + Vector2(-16, -12) * k, mid + Vector2(10, 6) * k, HEAL_GREEN, 3.0 * k, true)
			_pane(c, mid + Vector2(-4, -4) * k, Vector2(3, 5) * k, WHITE, WHITE, 1.2 * k)
			c.draw_rect(Rect2(mid + Vector2(-14, 11) * k, Vector2(28, 4) * k), Color(0.2, 0.05, 0.06), true)
			c.draw_rect(Rect2(mid + Vector2(-14, 11) * k, Vector2(8, 4) * k), HEAL_GREEN, true)
		"holy_focused_light":   # a prism bursting all its light into one figure
			_pane(c, mid + Vector2(-8, -6) * k, Vector2(5, 8) * k, Color(WHITE, 0.7), WHITE, 1.4 * k)
			_figure(c, mid + Vector2(9, 6) * k, 6.0 * k, WHITE, 1.6 * k)
			for i in 3:
				c.draw_line(mid + Vector2(-4, -4 + i * 3) * k, mid + Vector2(6, 2 + i) * k, HEAL_GREEN, 1.6 * k, true)
		"holy_last_glint":   # a prism fading out, a last glint breaking from it
			_pane(c, mid + Vector2(-2, 2) * k, Vector2(6, 11) * k, Color(WHITE, 0.15), Color(WHITE, 0.5), 1.4 * k)
			_star(c, mid + Vector2(8, -9) * k, 7.0 * k, WHITE, 4)
			_hourglass(c, mid + Vector2(-12, -10) * k, 0.5 * k, HOLY_GOLD, WHITE)
		"holy_full_glass":   # a full prism, a beam going on brighter beyond it
			_pane(c, mid, Vector2(6, 11) * k, HEAL_GREEN, WHITE, 1.6 * k)
			c.draw_line(mid + Vector2(-16, 4) * k, mid + Vector2(-6, 2) * k, Color(HEAL_GREEN, 0.6), 2.0 * k, true)
			c.draw_line(mid + Vector2(6, 0) * k, mid + Vector2(16, -2) * k, HEAL_GREEN, 4.0 * k, true)
		"holy_brilliance":   # three prisms in a row, the beam through them blazing
			for i in 3:
				_pane(c, mid + Vector2(-10 + i * 10, 0) * k, Vector2(3, 6) * k, Color(WHITE, 0.6), WHITE, 1.2 * k)
			c.draw_line(mid + Vector2(-16, 0) * k, mid + Vector2(16, 0) * k, HEAL_GREEN, 2.2 * k, true)
			for i in 6:
				var a := TAU * i / 6.0
				c.draw_line(mid + Vector2(cos(a), sin(a)) * 11.0 * k, mid + Vector2(cos(a), sin(a)) * 15.0 * k, HOLY_GOLD, 1.6 * k, true)
		# --- Holy archer: Lightstring (the ribbon tree's newer talents) ---
		"holy_gilded":   # an arrow passing a gold prism, gold soaking into it
			_pane(c, mid + Vector2(4, -4) * k, Vector2(5, 9) * k, HOLY_GOLD, WHITE, 1.4 * k)
			c.draw_line(mid + Vector2(-16, 8) * k, mid + Vector2(14, -6) * k, WHITE, 2.0 * k, true)
			for i in 3:
				c.draw_circle(mid + Vector2(-8 + i * 4, 6 - i * 2) * k, 1.6 * k, HOLY_GOLD)
		"holy_pinpoint":   # a gold prism focusing an arrow onto one point
			_pane(c, mid + Vector2(-8, 0) * k, Vector2(4, 8) * k, HOLY_GOLD, WHITE, 1.2 * k)
			c.draw_line(mid + Vector2(-4, -6) * k, mid + Vector2(12, 0) * k, Color(HOLY_GOLD, 0.6), 1.4 * k, true)
			c.draw_line(mid + Vector2(-4, 6) * k, mid + Vector2(12, 0) * k, Color(HOLY_GOLD, 0.6), 1.4 * k, true)
			c.draw_circle(mid + Vector2(12, 0) * k, 3.0 * k, WHITE)
			c.draw_arc(mid + Vector2(12, 0) * k, 5.5 * k, 0.0, TAU, 12, WHITE, 1.2 * k, true)
		"holy_lined_up":   # two gold prisms in a line, one arrow through both
			for x in [-6.0, 6.0]:
				_pane(c, mid + Vector2(x, 0) * k, Vector2(3.5, 7) * k, HOLY_GOLD, WHITE, 1.2 * k)
			c.draw_line(mid + Vector2(-16, 0) * k, mid + Vector2(14, 0) * k, WHITE, 2.0 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(18, 0), Vector2(12, -4), Vector2(12, 4)]), WHITE)
		"holy_light_draw":   # a bow drawn lightly, an Energy bar barely dented
			c.draw_arc(mid + Vector2(-6, 0) * k, 13.0 * k, -PI * 0.45, PI * 0.45, 12, HOLY_GOLD, 2.6 * k, true)
			c.draw_line(mid + Vector2(-1, -12) * k, mid + Vector2(-1, 12) * k, Color(WHITE, 0.7), 1.2 * k, true)
			c.draw_rect(Rect2(mid + Vector2(8, -12) * k, Vector2(5, 24) * k), Color(0.25, 0.2, 0.05), true)
			c.draw_rect(Rect2(mid + Vector2(8, -9) * k, Vector2(5, 21) * k), Color(1.0, 0.9, 0.3), true)
		"holy_full_gold":   # a full gold prism splitting off a bright arrow
			_pane(c, mid + Vector2(-6, 0) * k, Vector2(6, 11) * k, HOLY_GOLD, WHITE, 1.6 * k)
			c.draw_line(mid + Vector2(0, -4) * k, mid + Vector2(16, -14) * k, WHITE, 2.4 * k, true)
			c.draw_line(mid + Vector2(0, 4) * k, mid + Vector2(16, 12) * k, WHITE, 2.4 * k, true)
		"holy_gilt_tips":   # an arrowhead dipped in gold
			c.draw_line(mid + Vector2(-14, 14) * k, mid + Vector2(4, -4) * k, WHITE.darkened(0.2), 2.0 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(12, -12), Vector2(2, -8), Vector2(8, -2)]), HOLY_GOLD)
			_star(c, mid + Vector2(13, -13) * k, 3.5 * k, WHITE, 4)
		"holy_dazzle":   # a refracted arrow with a blinding glint at its tip
			_pane(c, mid + Vector2(-10, 4) * k, Vector2(4, 7) * k, HOLY_GOLD, WHITE, 1.2 * k)
			c.draw_line(mid + Vector2(-6, 2) * k, mid + Vector2(8, -6) * k, WHITE, 2.0 * k, true)
			_star(c, mid + Vector2(10, -8) * k, 8.0 * k, WHITE, 6)
		"holy_sundown":   # the sun setting behind an arrow, a low health bar
			c.draw_arc(mid + Vector2(0, 4) * k, 9.0 * k, PI, TAU, 14, Color(1.0, 0.55, 0.25), 6.0 * k, true)
			c.draw_line(mid + Vector2(-16, 4) * k, mid + Vector2(16, 4) * k, WHITE, 1.6 * k, true)
			c.draw_line(mid + Vector2(-14, -12) * k, mid + Vector2(10, -6) * k, WHITE, 2.0 * k, true)
			c.draw_rect(Rect2(mid + Vector2(-14, 11) * k, Vector2(28, 4) * k), Color(0.2, 0.05, 0.06), true)
			c.draw_rect(Rect2(mid + Vector2(-14, 11) * k, Vector2(8, 4) * k), HOUND_RED, true)
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
		# --- Nature: the specs' linked talents ---
		"nature_running_herd":   # two fawns leaping one after the other, a heal between them
			for i in 2:
				var o := mid + Vector2(-8 + i * 13, 6 - i * 10) * k
				c.draw_colored_polygon(_p(o, k, [Vector2(-6, 2), Vector2(4, -2), Vector2(7, -6), Vector2(8, -2), Vector2(4, 3), Vector2(-5, 5)]), light if i == 1 else col.lightened(0.2))
				c.draw_line(o + Vector2(-4, 4) * k, o + Vector2(-7, 9) * k, light, 1.4 * k, true)
			c.draw_arc(mid + Vector2(-2, 4) * k, 10.0 * k, PI * 1.15, PI * 1.85, 10, Color(WHITE, 0.6), 1.6 * k, true)
			_plus(c, mid + Vector2(12, 12) * k, 3.5 * k, HEAL_GREEN, 2.2 * k)
		"nature_hunting_party":   # three claw marks: the tiger strikes more than one
			for i in 3:
				var x := -9.0 + i * 9.0
				c.draw_line(mid + Vector2(x + 3, -13) * k, mid + Vector2(x - 3, 13) * k, light if i == 1 else col.lightened(0.25), 3.0 * k, true)
			c.draw_circle(mid + Vector2(12, -11) * k, 3.0 * k, WHITE)
		"nature_thick_sap":   # a thick drop of amber sap on bark
			c.draw_rect(Rect2(mid + Vector2(-14, -15) * k, Vector2(28, 30) * k), col.darkened(0.3))
			for x in [-8.0, 0.0, 8.0]:
				c.draw_line(mid + Vector2(x, -15) * k, mid + Vector2(x + 1.0, 15) * k, col.darkened(0.5), 1.6 * k, true)
			_drop(c, mid + Vector2(0, 0) * k, 0.9 * k, Color(1.0, 0.72, 0.25), WHITE, k)
		"nature_lingering_venom":   # a green burst with one drop still hanging on after it
			c.draw_circle(mid + Vector2(-4, 4) * k, 8.0 * k, Color(0.4, 0.95, 0.3, 0.6))
			for i in 6:
				var a := TAU * i / 6.0
				var d := Vector2(cos(a), sin(a))
				c.draw_line(mid + Vector2(-4, 4) * k + d * 8.0 * k, mid + Vector2(-4, 4) * k + d * 12.0 * k, light, 1.8 * k, true)
			_drop(c, mid + Vector2(10, -6) * k, 0.45 * k, Color(0.4, 0.95, 0.3), WHITE, k)
		# --- Nature: the open talents ---
		"nature_rough_bark":   # a slab of rough bark, deep furrows across it
			c.draw_rect(Rect2(mid + Vector2(-13, -15) * k, Vector2(26, 30) * k), WOOD)
			for y in [-10.0, -3.0, 4.0, 11.0]:
				c.draw_polyline(_p(mid, k, [Vector2(-13, y), Vector2(-6, y - 2), Vector2(1, y + 1), Vector2(7, y - 1), Vector2(13, y + 1)]), WOOD.darkened(0.5), 2.0 * k, true)
			c.draw_rect(Rect2(mid + Vector2(-13, -15) * k, Vector2(26, 30) * k), light, false, 1.4 * k)
		"nature_green_thumb":   # a thumb with a sprout growing from it
			c.draw_rect(Rect2(mid + Vector2(-6, -2) * k, Vector2(12, 17) * k), Color(0.95, 0.78, 0.62))
			c.draw_circle(mid + Vector2(0, -2) * k, 6.0 * k, Color(0.95, 0.78, 0.62))
			c.draw_line(mid + Vector2(0, -8) * k, mid + Vector2(0, -16) * k, HEAL_GREEN, 2.0 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(0, -13), Vector2(-7, -17), Vector2(-3, -11)]), HEAL_GREEN)
			c.draw_colored_polygon(_p(mid, k, [Vector2(0, -15), Vector2(7, -19), Vector2(4, -12)]), HEAL_GREEN)
		"nature_undergrowth":   # low ferns, and a drip of poison under them
			for i in 3:
				var base := mid + Vector2(-10 + i * 10, 14) * k
				c.draw_line(base, base + Vector2(-3 + i * 3, -18) * k, light if i == 1 else col.lightened(0.2), 2.0 * k, true)
				for j in 3:
					var at := base + Vector2(-3 + i * 3, -18) * k * (0.35 + j * 0.25)
					c.draw_line(at, at + Vector2(-4, -2) * k, light, 1.3 * k, true)
					c.draw_line(at, at + Vector2(4, -2) * k, light, 1.3 * k, true)
			_drop(c, mid + Vector2(12, -10) * k, 0.4 * k, Color(0.4, 0.95, 0.3), WHITE, k)
		"nature_clinging_vines":   # vines still wrapped round a foot that pulls away
			c.draw_rect(Rect2(mid + Vector2(-5, -15) * k, Vector2(10, 22) * k), WHITE.darkened(0.3))
			c.draw_rect(Rect2(mid + Vector2(-5, 5) * k, Vector2(16, 6) * k), WHITE.darkened(0.3))
			for i in 3:
				var y := -6.0 + i * 6.0
				c.draw_arc(mid + Vector2(0, y) * k, 7.0 * k, PI * 0.1, PI * 0.9, 8, light, 2.2 * k, true)
			c.draw_line(mid + Vector2(-7, 12) * k, mid + Vector2(-15, 15) * k, light, 2.0 * k, true)
		# --- Nature archer: Venomstring ---
		"nature_long_fangs":   # two long fangs, a drop on the tip of one
			for x in [-6.0, 6.0]:
				c.draw_colored_polygon(_p(mid, k, [Vector2(x - 4, -14), Vector2(x + 4, -14), Vector2(x + 1, 12), Vector2(x, 14)]), WHITE)
			_drop(c, mid + Vector2(6, 16) * k, 0.3 * k, Color(0.4, 0.95, 0.3), WHITE, k)
		"nature_hungry_venom":   # a drop leaping in an arc from one skull-pale dot to the next
			c.draw_circle(mid + Vector2(-12, 10) * k, 4.0 * k, Color(WHITE, 0.4))
			c.draw_circle(mid + Vector2(12, 10) * k, 4.0 * k, light)
			c.draw_arc(mid + Vector2(0, 10) * k, 12.0 * k, PI * 1.05, PI * 1.95, 14, Color(0.4, 0.95, 0.3), 2.2 * k, true)
			_drop(c, mid + Vector2(0, -6) * k, 0.45 * k, Color(0.4, 0.95, 0.3), WHITE, k)
		"nature_spring_trap":   # thorny jaws snapping shut on three marks
			c.draw_arc(mid + Vector2(0, 4) * k, 14.0 * k, PI, TAU, 14, WOOD.lightened(0.3), 3.0 * k, true)
			for i in 5:
				var x := -12.0 + i * 6.0
				c.draw_colored_polygon(_p(mid, k, [Vector2(x - 2, 4), Vector2(x + 2, 4), Vector2(x, -3)]), light)
			for i in 3:
				c.draw_circle(mid + Vector2(-9 + i * 9, 12) * k, 2.4 * k, Color(1.0, 0.85, 0.25))
		"nature_soaked_through":   # three drops (green, yellow, white) soaking into one cloth
			c.draw_rect(Rect2(mid + Vector2(-14, 2) * k, Vector2(28, 12) * k), col.darkened(0.2))
			var drops := [Color(0.4, 0.95, 0.3), Color(1.0, 0.85, 0.25), Color(0.92, 0.95, 1.0)]
			for i in 3:
				_drop(c, mid + Vector2(-9 + i * 9, -8) * k, 0.38 * k, drops[i], WHITE, k)
				c.draw_circle(mid + Vector2(-9 + i * 9, 8) * k, 3.5 * k, Color(drops[i], 0.6))
		# --- Nature healer: the Shepherd ---
		"nature_old_bark":   # a ring of old roots round a shield
			_shield(c, mid, k, col.darkened(0.2), light)
			c.draw_arc(mid, 17.0 * k, 0.0, TAU, 20, WOOD.lightened(0.2), 3.0 * k, true)
			for i in 4:
				var a := TAU * i / 4.0 + 0.4
				c.draw_line(mid + Vector2(cos(a), sin(a)) * 15.0 * k, mid + Vector2(cos(a), sin(a)) * 21.0 * k, WOOD.lightened(0.2), 2.0 * k, true)
		"nature_morning_dew":   # dew drops on a blossom at sunrise
			c.draw_arc(mid + Vector2(0, 16) * k, 14.0 * k, PI, TAU, 14, HOLY_GOLD, 2.0 * k, true)
			for i in 5:
				var a := TAU * i / 5.0
				c.draw_circle(mid + Vector2(cos(a), sin(a)) * 6.0 * k, 4.5 * k, Color(1.0, 0.62, 0.82))
			c.draw_circle(mid, 3.0 * k, HOLY_GOLD)
			_drop(c, mid + Vector2(-12, -12) * k, 0.3 * k, Color(0.6, 0.85, 1.0), WHITE, k)
			_drop(c, mid + Vector2(12, -9) * k, 0.25 * k, Color(0.6, 0.85, 1.0), WHITE, k)
		"nature_return_flight":   # an owl's wings, and an arrow curving back up
			c.draw_colored_polygon(_p(mid, k, [Vector2(-16, 4), Vector2(-4, -2), Vector2(0, 4), Vector2(4, -2), Vector2(16, 4), Vector2(0, 10)]), light)
			c.draw_circle(mid + Vector2(0, -4) * k, 3.5 * k, light)
			c.draw_arc(mid + Vector2(0, -6) * k, 12.0 * k, PI * 1.1, PI * 1.9, 12, WHITE, 1.8 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(9, -16), Vector2(13, -10), Vector2(7, -11)]), WHITE)
		"nature_deep_bloom":   # a full blossom, a second ring of petals round it
			for i in 8:
				var a := TAU * i / 8.0
				c.draw_circle(mid + Vector2(cos(a), sin(a)) * 12.0 * k, 4.0 * k, Color(1.0, 0.62, 0.82, 0.6))
			for i in 5:
				var a := TAU * i / 5.0 + 0.3
				c.draw_circle(mid + Vector2(cos(a), sin(a)) * 6.0 * k, 4.2 * k, Color(1.0, 0.62, 0.82))
			c.draw_circle(mid, 3.0 * k, HOLY_GOLD)
		"nature_big_herd":   # three fawn heads in a row, and a clock
			for i in 3:
				var o := mid + Vector2(-11 + i * 9, 6) * k
				c.draw_colored_polygon(_p(o, k, [Vector2(-3, 4), Vector2(3, 4), Vector2(4, -2), Vector2(0, -6), Vector2(-4, -2)]), light if i == 1 else col.lightened(0.2))
			_clock(c, mid + Vector2(11, -10) * k, 6.0 * k, WHITE, k)
		"nature_quick_return":   # a sprout rising fast from the ground, motion lines beside it
			c.draw_line(mid + Vector2(-16, 14) * k, mid + Vector2(16, 14) * k, WOOD.lightened(0.2), 2.4 * k, true)
			c.draw_line(mid + Vector2(0, 14) * k, mid + Vector2(0, -10) * k, HEAL_GREEN, 2.4 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(0, -8), Vector2(-9, -14), Vector2(-3, -4)]), HEAL_GREEN)
			c.draw_colored_polygon(_p(mid, k, [Vector2(0, -10), Vector2(9, -16), Vector2(4, -6)]), HEAL_GREEN)
			for x in [-9.0, 9.0]:
				c.draw_line(mid + Vector2(x, 10) * k, mid + Vector2(x, 0) * k, Color(WHITE, 0.5), 1.4 * k, true)
		"nature_evergreen":   # a fir tree with a heal beside it
			for i in 3:
				var y := -14.0 + i * 8.0
				var w := 6.0 + i * 4.0
				c.draw_colored_polygon(_p(mid, k, [Vector2(0, y), Vector2(w, y + 10), Vector2(-w, y + 10)]), col.lightened(0.15 + 0.1 * i))
			c.draw_rect(Rect2(mid + Vector2(-2, 12) * k, Vector2(4, 4) * k), WOOD)
			_plus(c, mid + Vector2(13, -11) * k, 3.5 * k, HEAL_GREEN, 2.2 * k)
		# --- Nature tank: the Colossus ---
		"nature_rising_sap":   # amber sap climbing up a trunk, an arrow up
			c.draw_rect(Rect2(mid + Vector2(-7, -15) * k, Vector2(14, 30) * k), WOOD)
			c.draw_rect(Rect2(mid + Vector2(-3, -4) * k, Vector2(6, 19) * k), Color(1.0, 0.72, 0.25))
			c.draw_colored_polygon(_p(mid, k, [Vector2(0, -15), Vector2(6, -7), Vector2(-6, -7)]), Color(1.0, 0.72, 0.25))
			c.draw_line(mid + Vector2(13, 12) * k, mid + Vector2(13, -10) * k, WHITE, 2.0 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(13, -14), Vector2(17, -8), Vector2(9, -8)]), WHITE)
		"nature_crushing_grip":   # a closed wooden fist with cracks shooting out
			c.draw_rect(Rect2(mid + Vector2(-10, -8) * k, Vector2(20, 16) * k), WOOD.lightened(0.15))
			for i in 4:
				c.draw_line(mid + Vector2(-10 + i * 5, -8) * k, mid + Vector2(-10 + i * 5, -2) * k, WOOD.darkened(0.4), 1.4 * k, true)
			for i in 6:
				var a := TAU * i / 6.0
				var d := Vector2(cos(a), sin(a))
				c.draw_line(mid + d * 14.0 * k, mid + d * 19.0 * k, Color(1.0, 0.72, 0.25), 2.0 * k, true)
		"nature_broad_fist":   # a fist with three impact marks fanning out
			c.draw_circle(mid + Vector2(-8, 0) * k, 7.0 * k, WOOD.lightened(0.15))
			for i in 3:
				var a := -0.6 + i * 0.6
				var d := Vector2(cos(a), sin(a))
				c.draw_circle(mid + Vector2(-2, 0) * k + d * 14.0 * k, 3.0 * k, light)
				c.draw_line(mid + Vector2(-2, 0) * k + d * 4.0 * k, mid + Vector2(-2, 0) * k + d * 10.0 * k, Color(WHITE, 0.6), 1.4 * k, true)
		"nature_spreading_roots":   # roots spreading wide from a crack
			c.draw_line(mid + Vector2(-16, -4) * k, mid + Vector2(16, -4) * k, WOOD.darkened(0.3), 2.4 * k, true)
			for i in 5:
				var x := -14.0 + i * 7.0
				c.draw_polyline(_p(mid, k, [Vector2(x * 0.3, -4), Vector2(x * 0.7, 4), Vector2(x, 14)]), light if i == 2 else col.lightened(0.2), 2.0 * k, true)
		"nature_firm_hold":   # a wooden hand closed round a red mark, Fury beside it
			c.draw_circle(mid + Vector2(-2, 2) * k, 5.0 * k, HOUND_RED)
			c.draw_arc(mid + Vector2(-2, 2) * k, 9.0 * k, PI * 0.2, PI * 1.8, 14, WOOD.lightened(0.25), 4.0 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(12, -14), Vector2(16, -4), Vector2(13, -5), Vector2(15, 4), Vector2(9, -7), Vector2(12, -6)]), Color(1.0, 0.45, 0.2))
		"nature_wide_awake":   # an open glowing eye in bark, with a clock
			c.draw_rect(Rect2(mid + Vector2(-15, -10) * k, Vector2(30, 20) * k), WOOD)
			_ellipse(c, mid, Vector2(11, 6) * k, Color(1.0, 0.72, 0.25), WHITE, 1.4 * k)
			c.draw_circle(mid, 3.5 * k, col.darkened(0.6))
			_clock(c, mid + Vector2(13, -13) * k, 5.0 * k, WHITE, k)
		"nature_old_growth":   # an old, thick tree, its rings showing on the stump beside it
			c.draw_rect(Rect2(mid + Vector2(-14, -4) * k, Vector2(10, 20) * k), WOOD)
			c.draw_circle(mid + Vector2(-9, -9) * k, 9.0 * k, col.lightened(0.15))
			for r in [3.0, 6.0, 9.0]:
				c.draw_arc(mid + Vector2(9, 8) * k, r * k, 0.0, TAU, 14, Color(1.0, 0.72, 0.25), 1.4 * k, true)
		# --- Nature caster: Thornweaver (the ribbon tree's newer talents) ---
		"nature_thick_mulch":   # a deep heap of mulch, an hourglass on it
			_patch(c, mid + Vector2(0, 11) * k, k, 1.6)
			_patch(c, mid + Vector2(0, 6) * k, k, 1.2)
			_hourglass(c, mid + Vector2(0, -8) * k, k, SAP, WHITE)
		"nature_well_rotted":   # an old patch, gone dark, with a clock and a stronger glow
			_ellipse(c, mid + Vector2(0, 10) * k, Vector2(14, 5) * k, WOOD.darkened(0.45), HOLY_GOLD, 1.8 * k)
			for x in [-7.0, 0.0, 7.0]:
				c.draw_line(mid + Vector2(x, 8) * k, mid + Vector2(x, 2) * k, Color(HOLY_GOLD, 0.7), 1.4 * k, true)
			_clock(c, mid + Vector2(0, -8) * k, 7.0 * k, WHITE, k)
		"nature_long_roots":   # a bear's head, roots reaching far out to a distant patch
			c.draw_circle(mid + Vector2(-8, -4) * k, 7.0 * k, WOOD.lightened(0.15))
			c.draw_circle(mid + Vector2(-13, -10) * k, 2.5 * k, WOOD.lightened(0.15))
			c.draw_circle(mid + Vector2(-3, -10) * k, 2.5 * k, WOOD.lightened(0.15))
			c.draw_polyline(_p(mid, k, [Vector2(-8, 4), Vector2(-2, 9), Vector2(6, 8), Vector2(12, 12)]), light, 2.0 * k, true)
			_patch(c, mid + Vector2(12, 13) * k, k, 0.6)
		"nature_tight_weave":   # vines braided tight into a claw
			for i in 3:
				var off := float(i - 1) * 3.0
				c.draw_polyline(_p(mid, k, [Vector2(-14, 12 + off), Vector2(-6, 4 + off), Vector2(2, 0 - off), Vector2(10, -8)]), light if i == 1 else col.lightened(0.25), 2.0 * k, true)
			for i in 3:
				c.draw_line(mid + Vector2(8 + i * 3, -6) * k, mid + Vector2(12 + i * 3, -15) * k, WHITE, 1.8 * k, true)
		"nature_old_roots":   # thick old roots bursting up from the ground into a fist
			c.draw_line(mid + Vector2(-16, 14) * k, mid + Vector2(16, 14) * k, WOOD.darkened(0.2), 2.4 * k, true)
			for x in [-7.0, 0.0, 7.0]:
				c.draw_line(mid + Vector2(x * 1.5, 14) * k, mid + Vector2(x * 0.5, -2) * k, WOOD.lightened(0.15), 3.6 * k, true)
			c.draw_circle(mid + Vector2(0, -6) * k, 7.0 * k, WOOD.lightened(0.25))
			c.draw_arc(mid + Vector2(0, -6) * k, 7.0 * k, PI, TAU, 10, light, 1.6 * k, true)
		"nature_steady_weave":   # a hand held still, vines slowly winding from it
			c.draw_circle(mid + Vector2(-10, 6) * k, 6.0 * k, Color(0.95, 0.78, 0.62))
			c.draw_polyline(_p(mid, k, [Vector2(-5, 4), Vector2(1, -2), Vector2(6, 2), Vector2(11, -5), Vector2(15, -1)]), light, 2.2 * k, true)
			c.draw_arc(mid + Vector2(8, -10) * k, 6.0 * k, PI * 1.1, PI * 1.9, 8, Color(WHITE, 0.6), 1.4 * k, true)
		"nature_harvest":   # a sickle over the patches, a drop of mana rising
			c.draw_arc(mid + Vector2(-2, -2) * k, 11.0 * k, PI * 1.1, PI * 1.9, 14, WHITE, 2.6 * k, true)
			c.draw_line(mid + Vector2(-12, -3) * k, mid + Vector2(-12, 10) * k, WOOD.lightened(0.2), 2.6 * k, true)
			_patch(c, mid + Vector2(4, 12) * k, k, 0.8)
			_drop(c, mid + Vector2(10, -2) * k, 0.4 * k, MANA, WHITE, k)
		"nature_leaf_litter":   # leaves sinking into the ground, mana coming back up
			for i in 3:
				_leaf(c, mid + Vector2(-12 + i * 7, -6 + i * 4) * k, Vector2(1, 0.4), 9.0 * k, Color(0.85, 0.6, 0.25) if i != 1 else light)
			c.draw_line(mid + Vector2(-16, 13) * k, mid + Vector2(16, 13) * k, WOOD.lightened(0.2), 2.0 * k, true)
			_drop(c, mid + Vector2(12, -8) * k, 0.4 * k, MANA, WHITE, k)
		"nature_hunted":   # a tiger's eyes in the dark, a weakened mark below them
			for x in [-7.0, 7.0]:
				_ellipse(c, mid + Vector2(x, -6) * k, Vector2(5, 2.2) * k, SAP, WHITE, 1.0 * k)
				c.draw_line(mid + Vector2(x, -8) * k, mid + Vector2(x, -4) * k, Color(0, 0, 0), 1.4 * k, true)
			c.draw_rect(Rect2(mid + Vector2(-12, 8) * k, Vector2(24, 5) * k), Color(0.2, 0.05, 0.06), true)
			c.draw_rect(Rect2(mid + Vector2(-12, 8) * k, Vector2(7, 5) * k), HOUND_RED, true)
		"nature_lush":   # a lush leaf over a small drop of mana
			_leaf(c, mid + Vector2(-12, 10) * k, Vector2(1, -1), 26.0 * k, light)
			_drop(c, mid + Vector2(10, 8) * k, 0.45 * k, MANA, WHITE, k)
			c.draw_line(mid + Vector2(4, 14) * k, mid + Vector2(16, 14) * k, WHITE, 1.6 * k, true)
		"nature_quickening":   # a patch, and a shoot springing up fast from it
			_patch(c, mid + Vector2(-4, 12) * k, k, 1.2)
			c.draw_line(mid + Vector2(-4, 10) * k, mid + Vector2(-4, -10) * k, HEAL_GREEN, 2.4 * k, true)
			_leaf(c, mid + Vector2(-4, -4) * k, Vector2(1, -0.6), 9.0 * k, HEAL_GREEN)
			for i in 3:
				c.draw_line(mid + Vector2(6 + i * 4, 6 - i * 2) * k, mid + Vector2(6 + i * 4, -6 - i * 2) * k, Color(WHITE, 0.6), 1.4 * k, true)
		# --- Nature healer: Shepherd (the ribbon tree's newer talents) ---
		"nature_second_bud":   # a Blossom, a second bud opening beside it
			_blossom(c, mid + Vector2(-5, 3) * k, 14.0 * k, PINK)
			_blossom(c, mid + Vector2(10, -9) * k, 8.0 * k, PINK.lightened(0.3))
			_plus(c, mid + Vector2(12, 11) * k, 3.0 * k, WHITE, 2.0 * k)
		"nature_long_bloom":   # a Blossom with an hourglass behind it
			_hourglass(c, mid + Vector2(9, -4) * k, k, SAP, WHITE)
			_blossom(c, mid + Vector2(-5, 4) * k, 16.0 * k, PINK)
		"nature_heavy_petals":   # big petals falling onto roots, the roots glowing
			c.draw_line(mid + Vector2(-16, 13) * k, mid + Vector2(16, 13) * k, WOOD.lightened(0.2), 3.0 * k, true)
			for x in [-10.0, 0.0, 10.0]:
				c.draw_line(mid + Vector2(x, 13) * k, mid + Vector2(x * 0.6, 5) * k, Color(HEAL_GREEN, 0.8), 2.0 * k, true)
			for v in [Vector2(-9, -8), Vector2(3, -12), Vector2(10, -4)]:
				c.draw_circle(mid + (v as Vector2) * k, 4.5 * k, PINK)
		"nature_soft_weave":   # a fawn woven of soft vines, a heal beside it
			c.draw_colored_polygon(_p(mid, k, [Vector2(-12, 6), Vector2(2, 0), Vector2(6, -6), Vector2(8, -1), Vector2(3, 6), Vector2(-10, 9)]), light)
			for x in [-8.0, 0.0]:
				c.draw_line(mid + Vector2(x, 8) * k, mid + Vector2(x - 2, 15) * k, light, 1.4 * k, true)
			c.draw_arc(mid + Vector2(-2, 4) * k, 12.0 * k, PI * 1.1, PI * 1.6, 8, Color(PINK, 0.8), 1.4 * k, true)
			_plus(c, mid + Vector2(12, -10) * k, 4.0 * k, HEAL_GREEN, 2.4 * k)
		"nature_pollen":   # a full Blossom blowing pollen to a second ally
			_blossom(c, mid + Vector2(-8, 4) * k, 14.0 * k, PINK)
			for i in 4:
				c.draw_circle(mid + Vector2(1 + i * 4, -2 - i * 3) * k, 1.4 * k, HOLY_GOLD)
			_figure(c, mid + Vector2(13, -2) * k, 5.0 * k, WHITE, 1.4 * k)
		"nature_canopy":   # a canopy of leaves over a small figure
			for i in 5:
				_leaf(c, mid + Vector2(0, -2) * k, Vector2(cos(PI * (1.1 + i * 0.2)), sin(PI * (1.1 + i * 0.2))), 15.0 * k, light if i == 2 else col.lightened(0.2))
			_figure(c, mid + Vector2(0, 9) * k, 6.0 * k, WHITE, 1.6 * k)
			c.draw_circle(mid + Vector2(-12, 6) * k, 3.0 * k, PINK)
		"nature_in_full_flower":   # three Blossoms in a row, the heal growing over them
			for i in 3:
				_blossom(c, mid + Vector2(-11 + i * 11, 8) * k, 9.0 * k, PINK)
			_plus(c, mid + Vector2(0, -9) * k, 6.0 * k, HEAL_GREEN, 3.0 * k)
		"nature_close_herd":   # two fawns leaping close together, the second as bright as the first
			for i in 2:
				var o := mid + Vector2(-7 + i * 9, 4 - i * 7) * k
				c.draw_colored_polygon(_p(o, k, [Vector2(-6, 2), Vector2(4, -2), Vector2(7, -6), Vector2(8, -2), Vector2(4, 3), Vector2(-5, 5)]), light)
			_plus(c, mid + Vector2(-10, -10) * k, 3.0 * k, HEAL_GREEN, 2.0 * k)
			_plus(c, mid + Vector2(12, 10) * k, 3.0 * k, HEAL_GREEN, 2.0 * k)
		"nature_new_shoots":   # a bare ally, a fresh shoot coming up beside them
			_figure(c, mid + Vector2(-6, 2) * k, 7.0 * k, WHITE, 1.6 * k)
			c.draw_line(mid + Vector2(10, 14) * k, mid + Vector2(10, 0) * k, HEAL_GREEN, 2.0 * k, true)
			_leaf(c, mid + Vector2(10, 4) * k, Vector2(-1, -0.7), 8.0 * k, HEAL_GREEN)
			_leaf(c, mid + Vector2(10, 1) * k, Vector2(1, -0.8), 8.0 * k, HEAL_GREEN)
		"nature_nectar":   # a Blossom dripping a drop of mana
			_blossom(c, mid + Vector2(0, -5) * k, 16.0 * k, PINK)
			_drop(c, mid + Vector2(0, 12) * k, 0.45 * k, MANA, WHITE, k)
		"nature_patient_hands":   # two cupped hands, dew gathering slowly in them
			c.draw_arc(mid + Vector2(0, 2) * k, 12.0 * k, PI * 0.1, PI * 0.9, 12, Color(0.95, 0.78, 0.62), 4.0 * k, true)
			_drop(c, mid + Vector2(0, 2) * k, 0.45 * k, Color(0.6, 0.85, 1.0), WHITE, k)
			_clock(c, mid + Vector2(0, -12) * k, 5.0 * k, WHITE, k)
		"nature_wide_grove":   # a ring of trees spread wide
			for i in 6:
				var a := TAU * i / 6.0
				var at := mid + Vector2(cos(a), sin(a)) * 13.0 * k
				c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -5) * k, at + Vector2(4, 3) * k, at + Vector2(-4, 3) * k]), light if i % 2 == 0 else col.lightened(0.2))
			c.draw_arc(mid, 7.0 * k, 0.0, TAU, 16, Color(WHITE, 0.6), 1.4 * k, true)
		"nature_morning_mist":   # mist lying low over a Blossom, a small drop of mana
			_blossom(c, mid + Vector2(-4, 2) * k, 12.0 * k, PINK)
			for y in [8.0, 12.0]:
				c.draw_line(mid + Vector2(-16, y) * k, mid + Vector2(16, y) * k, Color(WHITE, 0.45), 2.0 * k, true)
			_drop(c, mid + Vector2(11, -9) * k, 0.38 * k, MANA, WHITE, k)
		# --- Nature: the newer open talents ---
		"nature_startle":   # a deer's head turning, alarm marks round it
			c.draw_colored_polygon(_p(mid, k, [Vector2(-4, 10), Vector2(4, 10), Vector2(6, 0), Vector2(0, -6), Vector2(-6, 0)]), light)
			for x in [-1.0, 1.0]:
				c.draw_polyline(_p(mid, k, [Vector2(x * 4, -5), Vector2(x * 8, -12), Vector2(x * 12, -14)]), light, 1.6 * k, true)
			for i in 3:
				var a := -0.5 + i * 0.5
				c.draw_line(mid + Vector2(10, 2) * k + Vector2(cos(a), sin(a)) * 3.0 * k, mid + Vector2(10, 2) * k + Vector2(cos(a), sin(a)) * 7.0 * k, WHITE, 1.6 * k, true)
		"nature_pack_hunter":   # a wolf's head flanking a beast that faces away
			c.draw_circle(mid + Vector2(-6, 6) * k, 8.0 * k, Color(WHITE, 0.25))
			c.draw_line(mid + Vector2(-6, -2) * k, mid + Vector2(-16, -6) * k, Color(WHITE, 0.4), 1.4 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(4, -4), Vector2(9, -14), Vector2(12, -6), Vector2(16, -2), Vector2(12, 4), Vector2(6, 4)]), light)
			c.draw_circle(mid + Vector2(10, -4) * k, 1.2 * k, Color(0, 0, 0))
		"nature_tending":   # a watering can over a sprouting heal
			c.draw_rect(Rect2(mid + Vector2(-14, -12) * k, Vector2(12, 9) * k), WHITE.darkened(0.25), true)
			c.draw_line(mid + Vector2(-2, -9) * k, mid + Vector2(6, -13) * k, WHITE.darkened(0.25), 2.0 * k, true)
			for i in 3:
				c.draw_line(mid + Vector2(6 + i * 2, -10) * k, mid + Vector2(5 + i * 2, -4) * k, Color(0.6, 0.85, 1.0), 1.2 * k, true)
			_plus(c, mid + Vector2(6, 9) * k, 5.5 * k, HEAL_GREEN, 2.8 * k)
		"nature_food_chain":   # a fallen shape, a heal rising from it to a figure
			_ellipse(c, mid + Vector2(-8, 11) * k, Vector2(8, 3) * k, Color(WHITE, 0.3), Color(WHITE, 0.5), 1.0 * k)
			c.draw_arc(mid + Vector2(0, 8) * k, 10.0 * k, PI * 1.05, PI * 1.6, 8, HEAL_GREEN, 1.8 * k, true)
			_figure(c, mid + Vector2(9, 0) * k, 6.0 * k, WHITE, 1.6 * k)
			_plus(c, mid + Vector2(-8, -10) * k, 3.5 * k, HEAL_GREEN, 2.2 * k)
		"nature_hibernate":   # a bear curled up asleep in a den, z's above
			c.draw_arc(mid + Vector2(0, 12) * k, 15.0 * k, PI, TAU, 16, WOOD.lightened(0.2), 3.0 * k, true)
			_ellipse(c, mid + Vector2(0, 8) * k, Vector2(10, 5) * k, WOOD.lightened(0.1), light, 1.2 * k)
			for i in 2:
				var o := mid + Vector2(4 + i * 6, -6 - i * 6) * k
				c.draw_polyline(PackedVector2Array([o, o + Vector2(4, 0) * k, o + Vector2(0, 4) * k, o + Vector2(4, 4) * k]), WHITE, 1.4 * k, true)
		# --- Nature tank: Colossus (the ribbon tree's newer talents) ---
		"nature_groundswell":   # the ground swelling up under a fist, Fury rising
			c.draw_polyline(_p(mid, k, [Vector2(-16, 14), Vector2(-8, 8), Vector2(0, 2), Vector2(8, 8), Vector2(16, 14)]), WOOD.lightened(0.2), 3.0 * k, true)
			c.draw_circle(mid + Vector2(0, -6) * k, 6.0 * k, WOOD.lightened(0.25))
			c.draw_colored_polygon(_p(mid, k, [Vector2(10, -16), Vector2(14, -6), Vector2(11, -7), Vector2(13, 2), Vector2(7, -9), Vector2(10, -8)]), Color(1.0, 0.45, 0.2))
		"nature_heavy_limbs":   # a heavy wooden fist coming down, Fury burning behind
			c.draw_rect(Rect2(mid + Vector2(-9, -6) * k, Vector2(18, 15) * k), WOOD.lightened(0.15))
			c.draw_rect(Rect2(mid + Vector2(-4, -16) * k, Vector2(8, 10) * k), WOOD)
			for i in 3:
				c.draw_line(mid + Vector2(-12 + i * 12, 12) * k, mid + Vector2(-14 + i * 14, 16) * k, Color(1.0, 0.45, 0.2), 2.0 * k, true)
		"nature_long_sap":   # a drop of Sap beside an hourglass
			_drop(c, mid + Vector2(-6, 2) * k, 0.9 * k, SAP, WHITE, k)
			_hourglass(c, mid + Vector2(10, 0) * k, k, SAP, WHITE)
		"nature_sap_run":   # Sap running down bark, one drop more than the rest
			c.draw_rect(Rect2(mid + Vector2(-13, -15) * k, Vector2(26, 30) * k), WOOD.darkened(0.2))
			for x in [-6.0, 2.0]:
				c.draw_line(mid + Vector2(x, -15) * k, mid + Vector2(x, 4) * k, SAP, 2.2 * k, true)
				_drop(c, mid + Vector2(x, 8) * k, 0.3 * k, SAP, WHITE, k)
			_drop(c, mid + Vector2(10, -2) * k, 0.4 * k, SAP.lightened(0.3), WHITE, k)
		"nature_taproot":   # a deep root drawing up Sap and turning it into Fury
			c.draw_line(mid + Vector2(-10, 16) * k, mid + Vector2(-10, -8) * k, WOOD.lightened(0.2), 3.0 * k, true)
			_drop(c, mid + Vector2(-10, 6) * k, 0.35 * k, SAP, WHITE, k)
			c.draw_line(mid + Vector2(-6, -8) * k, mid + Vector2(4, -8) * k, WHITE, 1.6 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(10, -16), Vector2(14, -6), Vector2(11, -7), Vector2(13, 2), Vector2(7, -9), Vector2(10, -8)]), Color(1.0, 0.45, 0.2))
		"nature_long_limbs":   # a foot stamping, its ring reaching wide
			c.draw_rect(Rect2(mid + Vector2(-5, -12) * k, Vector2(10, 14) * k), WOOD.lightened(0.15))
			c.draw_rect(Rect2(mid + Vector2(-5, 2) * k, Vector2(14, 5) * k), WOOD.lightened(0.15))
			c.draw_arc(mid + Vector2(0, 8) * k, 17.0 * k, PI * 1.05, PI * 1.95, 16, light, 2.0 * k, true)
			c.draw_arc(mid + Vector2(0, 8) * k, 11.0 * k, PI * 1.1, PI * 1.9, 12, Color(light, 0.5), 1.4 * k, true)
		"nature_called_out":   # three marks on enemies, each sending Fury back
			for i in 3:
				var at := mid + Vector2(-11 + i * 11, -8 + absf(i - 1) * 4.0) * k
				c.draw_circle(at, 3.5 * k, HOUND_RED)
				c.draw_line(at + Vector2(0, 4) * k, mid + Vector2(0, 12) * k, Color(1.0, 0.45, 0.2), 1.6 * k, true)
			c.draw_circle(mid + Vector2(0, 13) * k, 3.5 * k, WOOD.lightened(0.3))
		"nature_creaking_bark":   # bark cracking loudly, sound lines out
			c.draw_rect(Rect2(mid + Vector2(-10, -15) * k, Vector2(14, 30) * k), WOOD)
			c.draw_polyline(_p(mid, k, [Vector2(-3, -15), Vector2(-6, -5), Vector2(-1, 2), Vector2(-5, 15)]), WOOD.darkened(0.6), 2.0 * k, true)
			for i in 3:
				c.draw_arc(mid + Vector2(4, 0) * k, (5.0 + i * 4.0) * k, -PI * 0.3, PI * 0.3, 8, Color(WHITE, 0.8 - i * 0.2), 1.6 * k, true)
		"nature_brimming":   # five drops of Sap, the bark brimming over
			for i in 5:
				var a := PI * (1.1 + i * 0.2)
				_drop(c, mid + Vector2(0, 8) * k + Vector2(cos(a), sin(a)) * 12.0 * k, 0.3 * k, SAP, WHITE, k)
			_drop(c, mid + Vector2(0, 6) * k, 0.6 * k, SAP.lightened(0.2), WHITE, k)
		"nature_woodgrain":   # a shield of wood, its grain showing
			_shield(c, mid, k, WOOD.lightened(0.1), light)
			for x in [-5.0, 0.0, 5.0]:
				c.draw_polyline(_p(mid, k, [Vector2(x, -10), Vector2(x + 2, -2), Vector2(x - 1, 6), Vector2(x, 11)]), WOOD.darkened(0.4), 1.2 * k, true)
		"nature_old_oak":   # an oak, a low health bar, Sap glowing at its heart
			c.draw_rect(Rect2(mid + Vector2(-4, -2) * k, Vector2(8, 14) * k), WOOD)
			c.draw_circle(mid + Vector2(0, -8) * k, 10.0 * k, col.lightened(0.15))
			_drop(c, mid + Vector2(0, 3) * k, 0.3 * k, SAP, WHITE, k)
			c.draw_rect(Rect2(mid + Vector2(-14, 13) * k, Vector2(28, 4) * k), Color(0.2, 0.05, 0.06), true)
			c.draw_rect(Rect2(mid + Vector2(-14, 13) * k, Vector2(8, 4) * k), HOUND_RED, true)
		# --- Nature archer: Venomstring (the ribbon tree's newer talents) ---
		"nature_slow_acting":   # a drop of venom and an hourglass running slow
			_drop(c, mid + Vector2(-7, 2) * k, 0.75 * k, VENOM, WHITE, k)
			_hourglass(c, mid + Vector2(9, 0) * k, k, VENOM, WHITE)
		"nature_virulent":   # a big drop of venom, glowing hot
			c.draw_circle(mid + Vector2(0, 2) * k, 14.0 * k, Color(VENOM, 0.25))
			_drop(c, mid + Vector2(0, 0) * k, 1.0 * k, VENOM, WHITE, k)
		"nature_fresh_host":   # a drop jumping to a new mark, a clock over it
			c.draw_circle(mid + Vector2(-12, 10) * k, 3.5 * k, Color(WHITE, 0.35))
			c.draw_arc(mid + Vector2(0, 10) * k, 12.0 * k, PI * 1.05, PI * 1.95, 14, VENOM, 2.0 * k, true)
			c.draw_circle(mid + Vector2(12, 10) * k, 3.5 * k, light)
			_clock(c, mid + Vector2(0, -6) * k, 6.0 * k, WHITE, k)
		"nature_double_dose":   # two drops, green and yellow, running into one
			_drop(c, mid + Vector2(-8, -6) * k, 0.5 * k, VENOM, WHITE, k)
			_drop(c, mid + Vector2(8, -6) * k, 0.5 * k, ASP, WHITE, k)
			c.draw_line(mid + Vector2(-6, 0) * k, mid + Vector2(0, 8) * k, VENOM, 2.0 * k, true)
			c.draw_line(mid + Vector2(6, 0) * k, mid + Vector2(0, 8) * k, ASP, 2.0 * k, true)
			c.draw_circle(mid + Vector2(0, 11) * k, 3.5 * k, VENOM.lerp(ASP, 0.5))
		"nature_quick_venom":   # quick drips falling one after another
			for i in 4:
				_drop(c, mid + Vector2(-12 + i * 8, -10 + i * 6) * k, 0.3 * k, VENOM, WHITE, k)
			for i in 3:
				c.draw_line(mid + Vector2(-14 + i * 8, -14 + i * 6) * k, mid + Vector2(-17 + i * 8, -18 + i * 6) * k, Color(WHITE, 0.5), 1.2 * k, true)
		"nature_swollen":   # a swollen bulb of venom splitting into small copies
			c.draw_circle(mid + Vector2(0, -2) * k, 9.0 * k, VENOM)
			c.draw_arc(mid + Vector2(0, -2) * k, 9.0 * k, 0.0, TAU, 16, WHITE, 1.4 * k, true)
			for x in [-12.0, 0.0, 12.0]:
				c.draw_circle(mid + Vector2(x, 13) * k, 2.8 * k, VENOM.lightened(0.2))
		"nature_full_brew":   # a cauldron of the three venoms, an arrow striking it
			c.draw_arc(mid + Vector2(0, 2) * k, 11.0 * k, 0.0, PI, 12, WHITE.darkened(0.3), 3.0 * k, true)
			c.draw_line(mid + Vector2(-12, 2) * k, mid + Vector2(12, 2) * k, WHITE.darkened(0.3), 2.0 * k, true)
			var brew := [VENOM, ASP, Color(0.92, 0.95, 1.0)]
			for i in 3:
				c.draw_circle(mid + Vector2(-5 + i * 5, 4) * k, 2.6 * k, brew[i])
			c.draw_line(mid + Vector2(-14, -14) * k, mid + Vector2(-2, -2) * k, WHITE, 1.8 * k, true)
		"nature_full_glands":   # a snake's head, its glands swollen with venom
			c.draw_colored_polygon(_p(mid, k, [Vector2(-14, 4), Vector2(-4, -8), Vector2(10, -6), Vector2(14, 2), Vector2(4, 8), Vector2(-10, 8)]), col.lightened(0.2))
			for x in [-2.0, 6.0]:
				c.draw_circle(mid + Vector2(x, 2) * k, 3.0 * k, VENOM)
			c.draw_circle(mid + Vector2(6, -3) * k, 1.4 * k, Color(0, 0, 0))
			_fang(c, mid + Vector2(10, 6) * k, 6.0, k, VENOM)
		"nature_spare_venom":   # a vial of venom, half of it pouring back in
			c.draw_rect(Rect2(mid + Vector2(-7, -10) * k, Vector2(14, 22) * k), Color(WHITE, 0.2), true)
			c.draw_rect(Rect2(mid + Vector2(-7, 2) * k, Vector2(14, 10) * k), VENOM, true)
			c.draw_rect(Rect2(mid + Vector2(-7, -10) * k, Vector2(14, 22) * k), WHITE, false, 1.4 * k)
			c.draw_arc(mid + Vector2(10, -6) * k, 6.0 * k, -PI * 0.5, PI * 0.6, 8, VENOM, 1.8 * k, true)
		"nature_running_venom":   # an arrow riding a stream of venom
			c.draw_polyline(_p(mid, k, [Vector2(-16, 10), Vector2(-8, 6), Vector2(0, 8), Vector2(8, 4), Vector2(16, 6)]), VENOM, 3.0 * k, true)
			_arrow_line(c, mid + Vector2(0, -4) * k, k, WHITE, light)
		"nature_dragging_feet":   # an arrow at a foot slowed by yellow venom
			c.draw_rect(Rect2(mid + Vector2(4, -6) * k, Vector2(8, 16) * k), WHITE.darkened(0.3))
			c.draw_rect(Rect2(mid + Vector2(4, 6) * k, Vector2(12, 5) * k), WHITE.darkened(0.3))
			for i in 2:
				c.draw_arc(mid + Vector2(8, -1 + i * 6) * k, 6.0 * k, PI * 0.1, PI * 0.9, 8, ASP, 2.0 * k, true)
			c.draw_line(mid + Vector2(-16, -12) * k, mid + Vector2(0, 0) * k, light, 2.0 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(2, 2), Vector2(-4, 0), Vector2(0, -4)]), light)
		"nature_dripping_tips":   # an arrowhead dripping venom
			c.draw_line(mid + Vector2(-14, -14) * k, mid + Vector2(4, 4) * k, WHITE.darkened(0.2), 2.0 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(10, 10), Vector2(0, 6), Vector2(6, 0)]), light)
			for i in 2:
				_drop(c, mid + Vector2(6 + i * 6, 14 + i) * k, 0.25 * k, VENOM, WHITE, k)
		"nature_final_bite":   # two fangs closing on a low health bar
			_fang(c, mid + Vector2(-6, -15) * k, 12.0, k, VENOM)
			_fang(c, mid + Vector2(6, -15) * k, 12.0, k, VENOM)
			c.draw_rect(Rect2(mid + Vector2(-14, 12) * k, Vector2(28, 4) * k), Color(0.2, 0.05, 0.06), true)
			c.draw_rect(Rect2(mid + Vector2(-14, 12) * k, Vector2(8, 4) * k), HOUND_RED, true)
		"nature_first_bite":   # one fang, a clean mark, a spark of the first strike
			_fang(c, mid + Vector2(-4, -15) * k, 16.0, k, VENOM)
			_star(c, mid + Vector2(10, -6) * k, 6.0 * k, WHITE, 4)
		# --- Nature caster: the Weaver ---
		"nature_rich_soil":   # dark earth heaped up, gold flecks in it
			c.draw_colored_polygon(_p(mid, k, [Vector2(-16, 14), Vector2(-8, 0), Vector2(0, -6), Vector2(9, 0), Vector2(16, 14)]), WOOD.darkened(0.2))
			for v in [Vector2(-6, 6), Vector2(3, 2), Vector2(8, 9), Vector2(-1, 10)]:
				c.draw_circle(mid + (v as Vector2) * k, 1.8 * k, HOLY_GOLD)
		"nature_compost":   # fallen leaves turning into earth
			for i in 3:
				var o := mid + Vector2(-8 + i * 8, -8 + i * 3) * k
				c.draw_colored_polygon(_p(o, k, [Vector2(-5, 0), Vector2(0, -4), Vector2(5, 0), Vector2(0, 4)]), light if i == 1 else Color(0.85, 0.6, 0.25))
			c.draw_rect(Rect2(mid + Vector2(-15, 8) * k, Vector2(30, 7) * k), WOOD.darkened(0.2))
		"nature_bramble_burst":   # a bramble with thorns bursting out of it
			c.draw_arc(mid, 7.0 * k, 0.0, TAU, 14, col.lightened(0.2), 3.0 * k, true)
			for i in 8:
				var a := TAU * i / 8.0
				var d := Vector2(cos(a), sin(a))
				c.draw_colored_polygon(PackedVector2Array([mid + d * 9.0 * k + d.orthogonal() * 2.5 * k,
					mid + d * 9.0 * k - d.orthogonal() * 2.5 * k, mid + d * 18.0 * k]), light)
		"nature_fertile_ground":   # a fallen shape, a sprout coming up beside it
			c.draw_line(mid + Vector2(-16, 12) * k, mid + Vector2(16, 12) * k, WOOD, 3.0 * k, true)
			_ellipse(c, mid + Vector2(-6, 8) * k, Vector2(9, 3.5) * k, Color(WHITE, 0.3), Color(WHITE, 0.5), 1.0 * k)
			c.draw_line(mid + Vector2(9, 12) * k, mid + Vector2(9, -6) * k, HEAL_GREEN, 2.0 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(9, -4), Vector2(2, -10), Vector2(6, -1)]), HEAL_GREEN)
			c.draw_colored_polygon(_p(mid, k, [Vector2(9, -6), Vector2(16, -12), Vector2(13, -3)]), HEAL_GREEN)
		"nature_second_growth":   # a bear's paw print, a fresh shoot inside it
			c.draw_circle(mid + Vector2(0, 5) * k, 8.0 * k, WOOD.lightened(0.15))
			for i in 4:
				c.draw_circle(mid + Vector2(-9 + i * 6, -8 + absf(i - 1.5) * 2.0) * k, 3.0 * k, WOOD.lightened(0.15))
			c.draw_line(mid + Vector2(0, 10) * k, mid + Vector2(0, 1) * k, HEAL_GREEN, 1.8 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(0, 2), Vector2(-5, -2), Vector2(-1, 4)]), HEAL_GREEN)
		"nature_circling_hawk":   # a hawk on a circle round a clock
			_clock(c, mid, 8.0 * k, WHITE, k)
			c.draw_arc(mid, 15.0 * k, PI * 1.1, PI * 2.6, 20, light, 1.8 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(10, -16), Vector2(18, -12), Vector2(14, -10), Vector2(16, -6), Vector2(11, -10)]), light)
		"nature_overgrown":   # several mulch patches, vines climbing over all of them
			for i in 3:
				_ellipse(c, mid + Vector2(-10 + i * 10, 12) * k, Vector2(5, 2.5) * k, WOOD.darkened(0.1), WOOD.lightened(0.2), 1.0 * k)
			c.draw_polyline(_p(mid, k, [Vector2(-14, 10), Vector2(-10, -4), Vector2(-3, -12), Vector2(4, -6), Vector2(10, -14), Vector2(15, 8)]), light, 2.4 * k, true)
			for v in [Vector2(-10, -4), Vector2(4, -6), Vector2(10, -14)]:
				c.draw_circle(mid + (v as Vector2) * k, 2.4 * k, col.lightened(0.3))
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
		"shadow_held_open":   # two hands holding the hole open, and the time they buy
			_ellipse(c, mid + Vector2(0, 9) * k, Vector2(15, 5.5) * k, PIT, light, 1.8 * k)
			_claw(c, mid + Vector2(-11, 9) * k, Vector2(-0.35, -1).normalized(), 17.0 * k, col.lightened(0.2), WHITE, 2.0 * k)
			_claw(c, mid + Vector2(11, 9) * k, Vector2(0.35, -1).normalized(), 17.0 * k, col.lightened(0.2), WHITE, 2.0 * k)
			_clock(c, mid + Vector2(0, -8) * k, 6.5 * k, WHITE, k)
			c.draw_line(mid + Vector2(0, -8) * k, mid + Vector2(0, -12) * k, WHITE, 1.6 * k, true)
			c.draw_line(mid + Vector2(0, -8) * k, mid + Vector2(3, -6.5) * k, WHITE, 1.6 * k, true)
		"shadow_hungry_dark":   # the open hole, teeth round its rim, a spell falling into it
			_ellipse(c, mid + Vector2(0, 8) * k, Vector2(15, 7) * k, PIT, light, 1.8 * k)
			for i in 7:
				var a := PI * (i + 0.5) / 7.0
				var at := mid + Vector2(cos(a) * 13.0, 8.0 - sin(a) * 6.0) * k
				c.draw_colored_polygon(PackedVector2Array([at + Vector2(-1.6, 0) * k, at + Vector2(1.6, 0) * k, at + Vector2(0, 3.5) * k]), WHITE)
			c.draw_circle(mid + Vector2(4, -10) * k, 5.0 * k, col.lightened(0.3))
			c.draw_circle(mid + Vector2(4, -10) * k, 2.4 * k, WHITE)
			for i in 3:
				c.draw_line(mid + Vector2(6 + i * 3, -17 + i) * k, mid + Vector2(8 + i * 3, -21 + i) * k, Color(light, 0.7), 1.4 * k, true)
		"shadow_many_mouths":   # one wide sweep, and a hole under each enemy it reaches
			c.draw_arc(mid + Vector2(0, 6) * k, 16.0 * k, PI * 1.08, PI * 1.92, 18, Color(light, 0.8), 2.2 * k, true)
			for x in [-11.0, 0.0, 11.0]:
				_ellipse(c, mid + Vector2(x, 12 - absf(x) * 0.3) * k, Vector2(5, 2.2) * k, PIT, light, 1.3 * k)
				_claw(c, mid + Vector2(x, 12 - absf(x) * 0.3) * k, Vector2(0, -1), 11.0 * k, col.lightened(0.2), WHITE, 1.4 * k)
		"shadow_shut_tight":   # the hole shut to a slit, and the claws under it still raking
			_ellipse(c, mid + Vector2(0, -6) * k, Vector2(15, 2.2) * k, PIT, WHITE, 2.0 * k)
			for x in [-8.0, 0.0, 8.0]:
				c.draw_line(mid + Vector2(x - 2, -2) * k, mid + Vector2(x + 2, 14) * k, light, 2.4 * k, true)
				c.draw_line(mid + Vector2(x + 2, 14) * k, mid + Vector2(x + 5, 11) * k, light, 2.0 * k, true)
			c.draw_line(mid + Vector2(-17, -6) * k, mid + Vector2(17, -6) * k, Color(WHITE, 0.4), 1.0 * k, true)
		"shadow_grasping_hands":   # a hand out of the hole, a critical glint at its claws
			_ellipse(c, mid + Vector2(-2, 14) * k, Vector2(11, 3.5) * k, PIT, light, 1.6 * k)
			_claw(c, mid + Vector2(-2, 14) * k, Vector2(0.2, -1).normalized(), 26.0 * k, col.lightened(0.2), WHITE, 2.4 * k)
			_star(c, mid + Vector2(9, -11) * k, 7.5 * k, WHITE, 4)
		"shadow_paid_in_full":   # the hole closing for good, and mana rising out of it
			_ellipse(c, mid + Vector2(0, 13) * k, Vector2(13, 2.5) * k, PIT, light, 1.6 * k)
			_drop(c, mid + Vector2(0, -3) * k, 0.85 * k, Color(0.35, 0.6, 1.0), WHITE, k)
			for x in [-11.0, 11.0]:
				c.draw_line(mid + Vector2(x, 8) * k, mid + Vector2(x, -6) * k, Color(light, 0.7), 1.6 * k, true)
				c.draw_polyline(_p(mid, k, [Vector2(x - 3, -3), Vector2(x, -7), Vector2(x + 3, -3)]), Color(light, 0.7), 1.6 * k, true)
		"shadow_snarl":   # a Hound's head, jaws wide, its snarl going out
			_hound(c, mid + Vector2(-3, 2) * k, 1.05 * k, light, 1.0)
			for i in 3:
				var a := -0.5 + i * 0.5
				var d := Vector2(cos(a), sin(a))
				c.draw_line(mid + Vector2(13, 3) * k + d * 3.0 * k, mid + Vector2(13, 3) * k + d * 7.0 * k, WHITE, 1.6 * k, true)
		"shadow_blood_up":   # a Roused Hound, and the blood rising with it
			_hound(c, mid + Vector2(-5, 4) * k, 1.0 * k, light, 0.7)
			_drop(c, mid + Vector2(12, -6) * k, 0.45 * k, HOUND_RED, WHITE, k)
			c.draw_line(mid + Vector2(12, 12) * k, mid + Vector2(12, 4) * k, WHITE, 1.8 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(9, 7), Vector2(12, 4), Vector2(15, 7)]), WHITE, 1.8 * k, true)
		"shadow_fetch":   # a Hound going under, and what it brings back for you
			_ellipse(c, mid + Vector2(-4, 12) * k, Vector2(12, 3.5) * k, PIT, light, 1.6 * k)
			_hound(c, mid + Vector2(-6, 3) * k, 0.85 * k, light, 0.3)
			c.draw_rect(Rect2(mid + Vector2(9, -12) * k, Vector2(6, 20) * k), Color(0.2, 0.05, 0.06), true)
			c.draw_rect(Rect2(mid + Vector2(9, -2) * k, Vector2(6, 10) * k), HOUND_RED, true)
			c.draw_rect(Rect2(mid + Vector2(9, -12) * k, Vector2(6, 20) * k), WHITE, false, 1.2 * k)
		"shadow_scent_of_blood":   # a Hound's nose down, on a trail of blood
			_hound(c, mid + Vector2(-4, 0) * k, 0.95 * k, light, 0.4)
			for i in 3:
				_drop(c, mid + Vector2(-8 + i * 9, 13 - i * 2) * k, 0.3 * k, HOUND_RED, Color(WHITE, 0.6), k * 0.6)
		"shadow_quick_hands":   # the demon's hand, its threads flicking down fast
			_hand(c, mid + Vector2(-3, -13) * k, 1.0 * k)
			for i in 3:
				var x := -9.0 + i * 6.0
				_thread(c, mid + Vector2(x, -2) * k, mid + Vector2(x * 1.2, 14) * k, STRING_PALE, 1.4 * k)
			for i in 3:
				c.draw_line(mid + Vector2(10, -8 + i * 6) * k, mid + Vector2(17, -8 + i * 6) * k, Color(light, 0.5 + i * 0.2), 1.8 * k, true)
		"shadow_three_ply":   # three threads twisted into one strong one
			for i in 3:
				var pts := PackedVector2Array()
				for j in 13:
					var y := -17.0 + j * 2.8
					pts.append(mid + Vector2(sin(y * 0.35 + i * TAU / 3.0) * 4.5, y) * k)
				c.draw_polyline(pts, STRING_PALE if i == 0 else (light if i == 1 else WHITE), 1.6 * k, true)
			_plus(c, mid + Vector2(12, 9) * k, 5.0 * k, HEAL_GREEN, 2.6 * k)
		"shadow_pass_it_on":   # two held up on threads, a heal running along from one to the other
			_figure(c, mid + Vector2(-10, 6) * k, 11.0 * k, WHITE, 1.6 * k)
			_figure(c, mid + Vector2(10, 6) * k, 11.0 * k, Color(light, 0.9), 1.6 * k)
			c.draw_arc(mid + Vector2(0, -2) * k, 10.0 * k, PI * 1.1, PI * 1.9, 14, STRING_PALE, 1.6 * k, true)
			_plus(c, mid + Vector2(0, -12) * k, 4.5 * k, HEAL_GREEN, 2.4 * k)
			c.draw_colored_polygon(_p(mid, k, [Vector2(8, -9), Vector2(4, -12), Vector2(5, -6)]), STRING_PALE)
		"shadow_hold_fast":   # someone on the edge, the thread pulled tight to hold them
			_thread(c, mid + Vector2(0, -19) * k, mid + Vector2(0, -6) * k, STRING_PALE, 2.0 * k)
			_figure(c, mid + Vector2(0, 5) * k, 13.0 * k, WHITE, 1.8 * k)
			c.draw_rect(Rect2(mid + Vector2(-14, 15) * k, Vector2(28, 3) * k), Color(0.2, 0.2, 0.22), true)
			c.draw_rect(Rect2(mid + Vector2(-14, 15) * k, Vector2(8, 3) * k), Color(1.0, 0.35, 0.3), true)
			_plus(c, mid + Vector2(11, -5) * k, 4.5 * k, HEAL_GREEN, 2.4 * k)
		"shadow_fair_trade":   # a crossed thread: the blow sent on to the enemy, a heal sent back
			_figure(c, mid + Vector2(-11, 4) * k, 11.0 * k, WHITE, 1.6 * k)
			c.draw_circle(mid + Vector2(11, 2) * k, 5.0 * k, HOUND_RED)
			c.draw_line(mid + Vector2(-8, -4) * k, mid + Vector2(7, -1) * k, STRING_PALE, 1.6 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(7, -5), Vector2(11, -3), Vector2(6, 1)]), STRING_PALE)
			_plus(c, mid + Vector2(-2, 12) * k, 4.5 * k, HEAL_GREEN, 2.4 * k)
			c.draw_line(mid + Vector2(8, 10) * k, mid + Vector2(3, 12) * k, HEAL_GREEN, 1.6 * k, true)
		"shadow_firm_grip":   # a thread knotted round an enemy, and the clock it holds on for
			_thread(c, mid + Vector2(-15, -15) * k, mid + Vector2(2, 2) * k, STRING_PALE, 2.0 * k)
			c.draw_circle(mid + Vector2(6, 6) * k, 7.0 * k, HOUND_RED)
			c.draw_arc(mid + Vector2(6, 6) * k, 7.0 * k, PI * 0.9, PI * 1.6, 10, STRING_PALE, 2.0 * k, true)
			_clock(c, mid + Vector2(10, -10) * k, 6.0 * k, WHITE, k)
		"shadow_loose_weave":   # loose threads drifting in loops, and the time they stay
			for i in 2:
				var pts := PackedVector2Array()
				for j in 15:
					var t := j / 14.0
					pts.append(mid + Vector2(-16 + t * 22, -8 + i * 12 + sin(t * TAU * 1.5) * 4.0) * k)
				c.draw_polyline(pts, STRING_PALE if i == 0 else light, 1.6 * k, true)
			_clock(c, mid + Vector2(11, 5) * k, 6.5 * k, WHITE, k)
			c.draw_line(mid + Vector2(11, 5) * k, mid + Vector2(11, 1) * k, WHITE, 1.4 * k, true)
		"shadow_nothing_wasted":   # a thread run to its end, curling back into mana
			_thread(c, mid + Vector2(-12, -17) * k, mid + Vector2(-12, 6) * k, STRING_PALE, 1.8 * k)
			c.draw_arc(mid + Vector2(-5, 6) * k, 7.0 * k, 0.0, PI, 10, STRING_PALE, 1.8 * k, true)
			_drop(c, mid + Vector2(7, -2) * k, 0.7 * k, Color(0.35, 0.6, 1.0), WHITE, k)
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
		# --- Lightning: the ribbon tree's new talents ---
		"lightning_long_leap":   # an arc leaping from one enemy to the next, far apart
			for v in [Vector2(-14, 9), Vector2(0, -8), Vector2(14, 9)]:
				c.draw_circle(mid + v * k, 3.4 * k, col.lightened(0.1))
			c.draw_polyline(_p(mid, k, [Vector2(-12, 6), Vector2(-8, -2), Vector2(-5, 1), Vector2(-2, -6)]), WHITE, 2.2 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(2, -6), Vector2(5, 1), Vector2(8, -2), Vector2(12, 6)]), WHITE, 2.2 * k, true)
			c.draw_arc(mid + Vector2(0, 6) * k, 15.0 * k, PI * 1.1, PI * 1.9, 14, Color(light, 0.5), 1.6 * k, true)
		"lightning_charged_air":   # a spell let go: motes rising off the hand into a cell
			_hand(c, mid + Vector2(-6, 8) * k, 10.0 * k)
			for i in 3:
				c.draw_circle(mid + Vector2(-8 + i * 4, -2 - i * 5) * k, (1.6 + i * 0.4) * k, Color(light, 0.5 + i * 0.2))
			_cell(c, mid + Vector2(10, -4) * k, k, col, light, 0.7)
		"lightning_feedback":   # a bolt with the charge looping back into it
			c.draw_arc(mid, 14.0 * k, -PI * 0.3, PI * 1.3, 24, light, 2.2 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(13, -11), Vector2(15, -3), Vector2(8, -6)]), light)
			_bolt(c, mid, 1.2 * k, WHITE)
		"lightning_lingering_storm":   # a storm cloud, and the clock it stays for
			for v in [Vector2(-8, -9), Vector2(0, -12), Vector2(8, -9)]:
				c.draw_circle(mid + v * k, 6.0 * k, col.lightened(0.15))
			c.draw_rect(Rect2(mid + Vector2(-10, -9) * k, Vector2(20, 5) * k), col.lightened(0.15), true)
			_clock(c, mid + Vector2(0, 8) * k, 8.0 * k, WHITE, k)
			c.draw_line(mid + Vector2(0, 8) * k, mid + Vector2(0, 3) * k, WHITE, 1.8 * k, true)
			c.draw_line(mid + Vector2(0, 8) * k, mid + Vector2(4, 9) * k, WHITE, 1.8 * k, true)
		"lightning_crackle":   # an orb of lightning, sparks crackling off all round it
			c.draw_circle(mid, 8.0 * k, col.lightened(0.2))
			c.draw_arc(mid, 8.0 * k, 0, TAU, 20, WHITE, 1.6 * k, true)
			for i in 6:
				var a := TAU * i / 6.0 + 0.3
				var d := Vector2(cos(a), sin(a))
				var n := Vector2(-d.y, d.x)
				c.draw_polyline(PackedVector2Array([mid + d * 10.0 * k, mid + (d * 13.0 + n * 2.0) * k, mid + (d * 16.0 - n * 1.5) * k]), light, 1.6 * k, true)
		"lightning_deep_draw":   # a cell emptied at once, more pouring out of it than it held
			_cell(c, mid + Vector2(-7, -3) * k, k, col, light, 0.0)
			for i in 3:
				c.draw_line(mid + Vector2(3 + i * 4, -6 + i * 3) * k, mid + Vector2(12 + i * 2, 4 + i * 4) * k, Color(light, 0.9 - i * 0.2), 2.4 * k, true)
			_bolt(c, mid + Vector2(10, 9) * k, 0.8 * k, WHITE)
		"lightning_afterflow":   # an empty cell filling back up fast, arrows climbing beside it
			_cell(c, mid + Vector2(-5, 0) * k, k, col, light, 0.35)
			for i in 3:
				var x := 8.0 + i * 4.0
				c.draw_polyline(_p(mid, k, [Vector2(x - 2, 4 - i * 6), Vector2(x, 1 - i * 6), Vector2(x + 2, 4 - i * 6)]), Color(WHITE, 0.5 + i * 0.25), 2.0 * k, true)
		"lightning_snap_cast":   # a critical spark, and the bolt it lets fly at once
			_star(c, mid + Vector2(-8, -8) * k, 7.0 * k, light, 4)
			_bolt(c, mid + Vector2(5, 3) * k, 1.2 * k, WHITE)
			for i in 2:
				c.draw_line(mid + Vector2(-16, 6 + i * 5) * k, mid + Vector2(-6, 6 + i * 5) * k, Color(light, 0.7), 1.6 * k, true)
		"lightning_full_circuit":   # a closed loop of wire round a full cell
			c.draw_rect(Rect2(mid + Vector2(-15, -13) * k, Vector2(30, 26) * k), light, false, 2.0 * k)
			_cell(c, mid, k, col, light, 1.0)
			for v in [Vector2(-15, -13), Vector2(15, -13), Vector2(15, 13), Vector2(-15, 13)]:
				c.draw_circle(mid + v * k, 2.2 * k, WHITE)
		"lightning_keen_current":   # a blade's edge with the glint of a crit on it
			c.draw_line(mid + Vector2(-14, 14) * k, mid + Vector2(10, -10) * k, Color(0.92, 0.92, 0.96), 3.4 * k, true)
			c.draw_line(mid + Vector2(-16, 9) * k, mid + Vector2(-9, 16) * k, col, 3.0 * k, true)
			_star(c, mid + Vector2(9, -9) * k, 6.0 * k, WHITE, 4)
		"lightning_edge_current":   # a blade's strike running down into a cell
			c.draw_line(mid + Vector2(-15, 10) * k, mid + Vector2(3, -12) * k, Color(0.92, 0.92, 0.96), 3.2 * k, true)
			c.draw_line(mid + Vector2(-16, 5) * k, mid + Vector2(-10, 12) * k, col, 3.0 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(0, -2), Vector2(4, 2), Vector2(2, 3), Vector2(6, 7)]), light, 2.0 * k, true)
			_cell(c, mid + Vector2(11, 4) * k, k, col, light, 0.8)
		"lightning_sparking_swings":   # a swing's arc, sparks flying off where it lands
			c.draw_arc(mid + Vector2(-4, 6) * k, 14.0 * k, -PI * 0.95, -PI * 0.2, 16, Color(0.92, 0.92, 0.96), 3.0 * k, true)
			for v in [Vector2(10, -6), Vector2(14, 0), Vector2(9, 3), Vector2(15, -9)]:
				c.draw_line(mid + Vector2(7, -3) * k, mid + v * k, light, 1.6 * k, true)
			_bolt(c, mid + Vector2(-6, 8) * k, 0.7 * k, WHITE)
		"lightning_afterspark":   # a bolt spent, and the swing that follows it glowing
			_bolt(c, mid + Vector2(-8, -4) * k, 1.0 * k, WHITE)
			c.draw_arc(mid + Vector2(2, 4) * k, 13.0 * k, -PI * 0.4, PI * 0.45, 14, light, 3.0 * k, true)
			c.draw_line(mid + Vector2(11, 12) * k, mid + Vector2(16, 16) * k, WOOD, 3.0 * k, true)
		"lightning_built_charge":   # three bars stacking up, the top one sparking
			for i in 3:
				c.draw_rect(Rect2(mid + Vector2(-12 + i * 9, 10 - i * 8) * k, Vector2(7, 6 + i * 8) * k), col.lightened(0.1 + i * 0.15), true)
			_star(c, mid + Vector2(10, -11) * k, 5.0 * k, WHITE, 4)
		"lightning_light_load":   # a nearly empty cell, and the feather that is all it carries
			_cell(c, mid + Vector2(-8, 1) * k, k, col, light, 0.15)
			c.draw_line(mid + Vector2(4, 14) * k, mid + Vector2(14, -12) * k, WHITE, 1.8 * k, true)
			for i in 5:
				var at := mid + Vector2(5.5 + i * 1.9, 10 - i * 5.0) * k
				c.draw_line(at, at + Vector2(-5, -2) * k, Color(light, 0.8), 1.4 * k, true)
				c.draw_line(at, at + Vector2(4, -4) * k, Color(light, 0.8), 1.4 * k, true)
		"lightning_spinning_up":   # a cooldown clock with arrows spinning it on
			_clock(c, mid, 10.0 * k, WHITE, k)
			c.draw_line(mid, mid + Vector2(5, -5) * k, WHITE, 2.0 * k, true)
			c.draw_arc(mid, 15.0 * k, -PI * 0.1, PI * 0.7, 12, light, 2.2 * k, true)
			c.draw_arc(mid, 15.0 * k, PI * 0.9, PI * 1.7, 12, light, 2.2 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-6, 16), Vector2(-1, 13), Vector2(-2, 19)]), light)
			c.draw_colored_polygon(_p(mid, k, [Vector2(6, -16), Vector2(1, -13), Vector2(2, -19)]), light)
		"lightning_charged_steel":   # a blade's point bursting with light where it crits
			c.draw_colored_polygon(_p(mid, k, [Vector2(-12, 12), Vector2(-15, 9), Vector2(5, -11), Vector2(8, -8)]), Color(0.92, 0.92, 0.96))
			c.draw_line(mid + Vector2(-16, 6) * k, mid + Vector2(-9, 15) * k, col, 3.0 * k, true)
			_star(c, mid + Vector2(9, -10) * k, 8.0 * k, light, 6)
			c.draw_circle(mid + Vector2(9, -10) * k, 2.4 * k, WHITE)
		"lightning_short_fuse":   # a short fuse, its spark nearly at the charge
			c.draw_rect(Rect2(mid + Vector2(-12, -2) * k, Vector2(14, 14) * k), col.darkened(0.2), true)
			c.draw_rect(Rect2(mid + Vector2(-12, -2) * k, Vector2(14, 14) * k), light, false, 1.6 * k)
			_bolt(c, mid + Vector2(-5, 5) * k, 0.6 * k, WHITE)
			c.draw_polyline(_p(mid, k, [Vector2(2, -2), Vector2(6, -7), Vector2(10, -6)]), WOOD, 2.0 * k, true)
			_star(c, mid + Vector2(11, -7) * k, 4.5 * k, Color(1.0, 0.85, 0.4), 5)
		"lightning_storm_dance":   # two bolts crossing in a ring, like two dancers turning
			c.draw_arc(mid, 15.0 * k, 0, TAU, 28, Color(light, 0.6), 1.6 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-8, -12), Vector2(2, -1), Vector2(-2, 0), Vector2(8, 12), Vector2(-3, 2), Vector2(1, 1)]), WHITE)
			c.draw_colored_polygon(_p(mid, k, [Vector2(8, -12), Vector2(-2, -1), Vector2(2, 0), Vector2(-8, 12), Vector2(3, 2), Vector2(-1, 1)]), light)
		"lightning_spark_guard":   # a parrying blade, and the spark it sends back
			c.draw_line(mid + Vector2(-14, 14) * k, mid + Vector2(10, -10) * k, Color(0.92, 0.92, 0.96), 3.2 * k, true)
			c.draw_line(mid + Vector2(-15, 4) * k, mid + Vector2(-4, 15) * k, col, 3.0 * k, true)
			c.draw_line(mid + Vector2(14, -14) * k, mid + Vector2(4, 0) * k, Color(1.0, 0.4, 0.3), 2.4 * k, true)
			_bolt(c, mid + Vector2(9, 8) * k, 0.8 * k, light)
		"lightning_loud_steel":   # a two-handed blade, its ring heard far off
			c.draw_line(mid + Vector2(-6, 16) * k, mid + Vector2(-6, -14) * k, Color(0.92, 0.92, 0.96), 4.0 * k, true)
			c.draw_line(mid + Vector2(-13, 8) * k, mid + Vector2(1, 8) * k, col, 3.0 * k, true)
			for i in 3:
				c.draw_arc(mid + Vector2(-2, -3) * k, (6.0 + i * 5.0) * k, -PI * 0.35, PI * 0.35, 8, Color(light, 0.9 - i * 0.25), 1.8 * k, true)
		"lightning_charged_guard":   # a shield taking the next blow, a bolt on its face
			_shield(c, mid, k, col.darkened(0.3), light)
			_bolt(c, mid, 1.0 * k, WHITE)
		"lightning_draw_down":   # a cell draining into a mending cross
			_cell(c, mid + Vector2(-9, -2) * k, k, col, light, 0.5)
			c.draw_line(mid + Vector2(-2, 0) * k, mid + Vector2(4, 0) * k, Color(light, 0.8), 2.0 * k, true)
			_plus(c, mid + Vector2(10, 0) * k, 7.0 * k, Color(0.45, 1.0, 0.5), 3.4 * k)
		"lightning_ring_true":   # rings of lightning going out from someone in the middle
			_figure(c, mid + Vector2(0, 1) * k, 9.0 * k, WHITE, 1.6 * k)
			for i in 2:
				c.draw_arc(mid, (11.0 + i * 5.0) * k, 0, TAU, 28, Color(light, 0.9 - i * 0.35), 2.0 * k, true)
		"lightning_hard_lessons":   # a blow landing, and the charge it leaves behind
			c.draw_line(mid + Vector2(-16, -12) * k, mid + Vector2(-3, -1) * k, Color(1.0, 0.4, 0.3), 2.6 * k, true)
			_star(c, mid + Vector2(-3, -1) * k, 6.0 * k, Color(1.0, 0.6, 0.4), 5)
			_cell(c, mid + Vector2(9, 5) * k, k, col, light, 0.6)
		"lightning_wide_current":   # one charge branching out to three
			c.draw_circle(mid + Vector2(-12, 0) * k, 3.4 * k, WHITE)
			for v in [Vector2(12, -12), Vector2(14, 0), Vector2(12, 12)]:
				c.draw_polyline(_p(mid, k, [Vector2(-10, 0), (Vector2(-10, 0) + v) * 0.5 + Vector2(0, -3), v]), light, 2.0 * k, true)
				c.draw_circle(mid + v * k, 2.8 * k, col.lightened(0.2))
		"lightning_charged_shell":   # a full cell wrapped in a bubble of charge
			c.draw_arc(mid, 15.0 * k, 0, TAU, 28, light, 2.0 * k, true)
			c.draw_arc(mid, 15.0 * k, -PI * 0.8, -PI * 0.55, 6, WHITE, 2.4 * k, true)
			_cell(c, mid, k, col, light, 0.9)
		"lightning_hard_stare":   # an eye under a hard brow, locked on
			var eye := PackedVector2Array()
			for i in 17:
				var a := PI * i / 16.0
				eye.append(mid + Vector2(-cos(a) * 15.0, -sin(a) * 8.0 + 3.0) * k)
			for i in range(1, 16):
				var a := PI * i / 16.0
				eye.append(mid + Vector2(cos(a) * 15.0, sin(a) * 6.0 + 3.0) * k)
			c.draw_colored_polygon(eye, Color(0.92, 0.92, 0.96))
			c.draw_circle(mid + Vector2(0, 2) * k, 5.5 * k, col)
			c.draw_circle(mid + Vector2(0, 2) * k, 2.4 * k, Color(0.05, 0.05, 0.08))
			c.draw_line(mid + Vector2(-15, -10) * k, mid + Vector2(14, -6) * k, light, 2.6 * k, true)
		"lightning_eye_of_the_storm":   # a spiral of storm, still and bright in the middle
			var spiral := PackedVector2Array()
			for i in 30:
				var a := i * 0.42
				spiral.append(mid + Vector2(cos(a), sin(a)) * (2.0 + i * 0.5) * k)
			c.draw_polyline(spiral, light, 2.0 * k, true)
			c.draw_circle(mid, 3.0 * k, WHITE)
			_bolt(c, mid + Vector2(11, 10) * k, 0.6 * k, WHITE)
		"lightning_back_to_the_wall":   # someone pressed to a wall, blade still up
			for r in 4:
				c.draw_rect(Rect2(mid + Vector2(-17 + (r % 2) * 3, -16 + r * 8) * k, Vector2(8, 7) * k), col.darkened(0.2), false, 1.4 * k)
			_figure(c, mid + Vector2(2, 1) * k, 12.0 * k, WHITE, 1.8 * k)
			c.draw_line(mid + Vector2(6, 6) * k, mid + Vector2(15, -12) * k, Color(0.92, 0.92, 0.96), 2.4 * k, true)
		"lightning_storm_anchor":   # an anchor, a bolt running beside its shank
			c.draw_line(mid + Vector2(0, -13) * k, mid + Vector2(0, 13) * k, WHITE, 3.0 * k, true)
			c.draw_arc(mid + Vector2(0, -15) * k, 3.0 * k, 0, TAU, 12, WHITE, 2.0 * k, true)
			c.draw_line(mid + Vector2(-7, -7) * k, mid + Vector2(7, -7) * k, WHITE, 2.4 * k, true)
			c.draw_arc(mid + Vector2(0, 3) * k, 12.0 * k, PI * 0.1, PI * 0.9, 14, WHITE, 3.0 * k, true)
			_bolt(c, mid + Vector2(-10, -1) * k, 0.6 * k, light)
		"lightning_cut_the_line":   # a line of casting cut through, the gap sparking
			c.draw_line(mid + Vector2(-16, 0) * k, mid + Vector2(-4, 0) * k, light, 2.6 * k, true)
			c.draw_line(mid + Vector2(4, 0) * k, mid + Vector2(16, 0) * k, Color(light, 0.45), 2.6 * k, true)
			c.draw_line(mid + Vector2(-6, 12) * k, mid + Vector2(6, -12) * k, WHITE, 2.6 * k, true)
			_star(c, mid, 4.0 * k, Color(1.0, 0.85, 0.4), 4)
		"lightning_fresh_charge":   # a whole, unhurt heart with a bolt across it
			c.draw_circle(mid + Vector2(-6, -4) * k, 7.0 * k, Color(0.9, 0.3, 0.35))
			c.draw_circle(mid + Vector2(6, -4) * k, 7.0 * k, Color(0.9, 0.3, 0.35))
			c.draw_colored_polygon(_p(mid, k, [Vector2(-12.5, -1), Vector2(12.5, -1), Vector2(0, 14)]), Color(0.9, 0.3, 0.35))
			_bolt(c, mid + Vector2(0, 1) * k, 0.9 * k, WHITE)
		"lightning_static_build":   # footsteps, each leaving a spark that adds up
			for i in 3:
				var at := mid + Vector2(-11 + i * 9, 10 - i * 8) * k
				c.draw_circle(at, 3.2 * k, Color(WHITE, 0.45 + i * 0.25))
				_star(c, at + Vector2(5, -4) * k, (2.5 + i) * k, light, 4)
		# --- Arcane: the ribbon tree's new talents ---
		"arcane_pinned_in_time":   # a clock face with a pin driven through it
			_clock(c, mid, 12.0 * k, light, k)
			c.draw_line(mid + Vector2(-14, -14) * k, mid + Vector2(10, 10) * k, WHITE, 2.6 * k, true)
			c.draw_circle(mid + Vector2(-14, -14) * k, 3.0 * k, WHITE)
		"arcane_thrifty_mind":   # a mana drop, a little of it held back behind a line
			_drop(c, mid + Vector2(0, 1) * k, 1.1 * k, Color(0.45, 0.6, 1.0), WHITE, k)
			c.draw_line(mid + Vector2(-13, 6) * k, mid + Vector2(13, 6) * k, light, 2.2 * k, true)
		"arcane_wound_up":   # a spring wound tight, a key turning it
			var coil := PackedVector2Array()
			for i in 40:
				var a := i * 0.5
				coil.append(mid + Vector2(cos(a), sin(a)) * (1.5 + i * 0.3) * k)
			c.draw_polyline(coil, light, 1.8 * k, true)
			c.draw_line(mid + Vector2(11, -11) * k, mid + Vector2(16, -16) * k, WHITE, 2.4 * k, true)
			c.draw_circle(mid + Vector2(16, -16) * k, 2.4 * k, WHITE)
		"arcane_sharp_mind":   # a bright crit star over a thinking head
			c.draw_arc(mid + Vector2(0, 4) * k, 10.0 * k, PI, TAU, 16, light, 2.2 * k, true)
			c.draw_line(mid + Vector2(-10, 4) * k, mid + Vector2(-10, 14) * k, light, 2.2 * k, true)
			c.draw_line(mid + Vector2(10, 4) * k, mid + Vector2(10, 14) * k, light, 2.2 * k, true)
			_star(c, mid + Vector2(0, -10) * k, 7.0 * k, WHITE, 4)
		"arcane_clock_hands":   # a clock whose hands spin fast
			_clock(c, mid, 13.0 * k, light, k)
			c.draw_line(mid, mid + Vector2(0, -10) * k, WHITE, 2.4 * k, true)
			c.draw_line(mid, mid + Vector2(7, 3) * k, WHITE, 2.4 * k, true)
			c.draw_arc(mid, 7.0 * k, -PI * 0.5, PI * 0.1, 8, Color(WHITE, 0.5), 1.4 * k, true)
		"arcane_moving_parts":   # two gears turning together
			for g in [[Vector2(-6, -4), 8.0], [Vector2(8, 7), 6.0]]:
				var at: Vector2 = mid + (g[0] as Vector2) * k
				var r: float = float(g[1]) * k
				c.draw_arc(at, r, 0, TAU, 20, light, 2.4 * k, true)
				for i in 6:
					var a := TAU * i / 6.0
					c.draw_line(at + Vector2(cos(a), sin(a)) * r, at + Vector2(cos(a), sin(a)) * (r + 3.0 * k), light, 2.4 * k, true)
				c.draw_circle(at, 2.0 * k, WHITE)
		"arcane_second_hand":   # a thin second hand jumping one tick back
			_clock(c, mid, 13.0 * k, light, k)
			c.draw_line(mid, mid + Vector2(8, -8) * k, WHITE, 1.4 * k, true)
			c.draw_arc(mid, 10.0 * k, -PI * 0.25, -PI * 0.05, 6, Color(1.0, 0.85, 0.4), 2.0 * k, true)
		"arcane_on_the_dot":   # a clock hand landing exactly on its mark
			_clock(c, mid, 13.0 * k, light, k)
			c.draw_line(mid, mid + Vector2(0, -11) * k, WHITE, 2.4 * k, true)
			c.draw_circle(mid + Vector2(0, -13) * k, 2.6 * k, Color(1.0, 0.85, 0.4))
		"arcane_turning_gears":   # a gear, and the speed lines it throws off
			c.draw_arc(mid + Vector2(-3, 0) * k, 9.0 * k, 0, TAU, 20, light, 2.4 * k, true)
			for i in 8:
				var a := TAU * i / 8.0
				c.draw_line(mid + Vector2(-3, 0) * k + Vector2(cos(a), sin(a)) * 9.0 * k, mid + Vector2(-3, 0) * k + Vector2(cos(a), sin(a)) * 12.5 * k, light, 2.4 * k, true)
			for i in 3:
				c.draw_line(mid + Vector2(11, -8 + i * 8) * k, mid + Vector2(17, -8 + i * 8) * k, Color(WHITE, 0.5 + i * 0.2), 1.8 * k, true)
		"arcane_unwinding":   # a spring springing loose, an instant spark at its end
			var loose := PackedVector2Array()
			for i in 24:
				loose.append(mid + Vector2(-14 + i * 1.2, sin(i * 1.1) * (2.0 + i * 0.25)) * k)
			c.draw_polyline(loose, light, 2.0 * k, true)
			_star(c, mid + Vector2(14, 0) * k, 6.0 * k, WHITE, 4)
		"arcane_glass_armor":   # a breastplate of mirror panes
			_shield(c, mid, k, col.darkened(0.3), light)
			_pane(c, mid + Vector2(-4, -3) * k, Vector2(4, 6) * k, Color(WHITE, 0.6), WHITE, 1.2 * k)
			_pane(c, mid + Vector2(4, 3) * k, Vector2(4, 6) * k, Color(WHITE, 0.4), WHITE, 1.2 * k)
		"arcane_quick_answer":   # a step aside from a blow, and the blade already coming back
			_figure(c, mid + Vector2(-5, 0) * k, 12.0 * k, WHITE, 1.8 * k)
			c.draw_line(mid + Vector2(-17, -12) * k, mid + Vector2(-10, -12) * k, Color(1.0, 0.4, 0.3), 2.0 * k, true)
			c.draw_arc(mid + Vector2(2, 2) * k, 13.0 * k, -PI * 0.45, PI * 0.2, 12, light, 2.8 * k, true)
		"arcane_glass_dust":   # shards of glass hanging in the air like dust
			for v in [Vector2(-10, -8), Vector2(2, -12), Vector2(11, -4), Vector2(-4, 4), Vector2(8, 10), Vector2(-12, 11)]:
				_pane(c, mid + v * k, Vector2(2.5, 4) * k, Color(light, 0.7), WHITE, 1.0 * k)
		"arcane_last_copy":   # one figure and the single reflection left beside it
			_figure(c, mid + Vector2(-6, 0) * k, 12.0 * k, WHITE, 1.8 * k)
			_figure(c, mid + Vector2(7, 0) * k, 12.0 * k, Color(light, 0.55), 1.8 * k)
		"arcane_crowded_room":   # many reflections round one figure, all drawing eyes
			_figure(c, mid, 11.0 * k, WHITE, 1.8 * k)
			for v in [Vector2(-12, -6), Vector2(12, -6), Vector2(-12, 9), Vector2(12, 9)]:
				_figure(c, mid + v * k, 7.0 * k, Color(light, 0.5), 1.4 * k)
		"arcane_fresh_trace":   # the first faint line of a trace, glowing bright
			c.draw_line(mid + Vector2(-14, 10) * k, mid + Vector2(12, -10) * k, light, 3.0 * k, true)
			_star(c, mid + Vector2(12, -10) * k, 5.0 * k, WHITE, 4)
			c.draw_line(mid + Vector2(-14, 15) * k, mid + Vector2(-2, 6) * k, Color(light, 0.35), 1.6 * k, true)
		"arcane_keen_cuts":   # two crossed blades, a glint where they cross
			c.draw_line(mid + Vector2(-13, 13) * k, mid + Vector2(13, -13) * k, Color(0.92, 0.92, 0.96), 2.8 * k, true)
			c.draw_line(mid + Vector2(13, 13) * k, mid + Vector2(-13, -13) * k, Color(0.92, 0.92, 0.96), 2.8 * k, true)
			_star(c, mid, 6.0 * k, light, 4)
		"arcane_quick_cuts":   # a cut, and the clock hurrying it back
			c.draw_line(mid + Vector2(-15, 12) * k, mid + Vector2(2, -6) * k, Color(0.92, 0.92, 0.96), 3.0 * k, true)
			_clock(c, mid + Vector2(8, -7) * k, 7.0 * k, light, k)
			c.draw_arc(mid + Vector2(8, -7) * k, 10.0 * k, PI * 0.5, PI * 1.1, 8, WHITE, 1.6 * k, true)
		"arcane_twin_blades":   # two blades swinging, a ghostly line left behind
			for sx in [-1.0, 1.0]:
				c.draw_line(mid + Vector2(sx * 4, 14) * k, mid + Vector2(sx * 12, -12) * k, Color(0.92, 0.92, 0.96), 2.6 * k, true)
			c.draw_arc(mid + Vector2(0, 6) * k, 14.0 * k, -PI * 0.85, -PI * 0.15, 14, Color(light, 0.6), 1.8 * k, true)
		"arcane_full_stage":   # a stage with every spot taken by a trace
			c.draw_line(mid + Vector2(-16, 10) * k, mid + Vector2(16, 10) * k, light, 2.6 * k, true)
			for i in 3:
				_figure(c, mid + Vector2(-10 + i * 10, -1) * k, 9.0 * k, Color(WHITE, 0.55 + i * 0.2), 1.6 * k)
		"arcane_final_act":   # a falling curtain over a wounded foe
			c.draw_rect(Rect2(mid + Vector2(-16, -16) * k, Vector2(32, 5) * k), col.lightened(0.15), true)
			for x in [-14, -8, -2, 4, 10]:
				c.draw_line(mid + Vector2(x, -11) * k, mid + Vector2(x + 2, 4) * k, col.lightened(0.15), 4.0 * k, true)
			c.draw_rect(Rect2(mid + Vector2(-10, 10) * k, Vector2(20, 4) * k), Color(0.25, 0.1, 0.1), true)
			c.draw_rect(Rect2(mid + Vector2(-10, 10) * k, Vector2(6, 4) * k), Color(0.9, 0.3, 0.35), true)
		"arcane_curtain_rise":   # a curtain lifting, a blade ready behind it
			c.draw_rect(Rect2(mid + Vector2(-16, -16) * k, Vector2(32, 6) * k), col.lightened(0.15), true)
			for sx in [-1.0, 1.0]:
				c.draw_colored_polygon(_p(mid, k, [Vector2(sx * 16, -10), Vector2(sx * 8, -10), Vector2(sx * 14, 4)]), col.lightened(0.1))
			c.draw_line(mid + Vector2(-6, 14) * k, mid + Vector2(6, -4) * k, Color(0.92, 0.92, 0.96), 3.0 * k, true)
		"arcane_spare_moment":   # an hourglass with a little sand kept back at the top
			_hourglass(c, mid, k, Color(light, 0.8), WHITE)
			c.draw_circle(mid + Vector2(10, -12) * k, 2.6 * k, Color(1.0, 0.85, 0.4))
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
		"fire_long_coat":   # a heavy drop of pitch stretching down, a small flame on it (Thick Pitch's)
			var pitch := Color(0.12, 0.09, 0.08)
			c.draw_rect(Rect2(mid + Vector2(-15, -16) * k, Vector2(30, 6) * k), pitch, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-7, -10), Vector2(7, -10), Vector2(3, 0), Vector2(-3, 0)]), pitch)
			c.draw_circle(mid + Vector2(0, 6) * k, 8.0 * k, pitch)
			c.draw_arc(mid + Vector2(0, 6) * k, 8.0 * k, PI * 0.1, PI * 0.9, 12, light, 1.8 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(10, -4), Vector2(14, 3), Vector2(12, 8), Vector2(8, 8), Vector2(6, 3)]), col)
			c.draw_circle(mid + Vector2(10, 5) * k, 1.8 * k, Color(1.0, 0.9, 0.4))
		"fire_slow_cooling":   # a glowing bar on an anvil that stays hot: a clock beside it
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
		"fire_spreading_fire":   # a burning bowl inside a ring pushed outward
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
		"fire_fed_furnace":   # a heart with a furnace glow inside (Furnace Heart's)
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
		"fire_warm_start":   # crossed sticks catching their first flame
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
		"fire_heat_shimmer":   # a calm shield with a small flame held on it
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
		"fire_clinker":   # broken chunks of slag lying in a burning pool
			c.draw_line(mid + Vector2(-16, 12) * k, mid + Vector2(16, 12) * k, Color(1.0, 0.9, 0.4), 3.0 * k, true)
			c.draw_line(mid + Vector2(-12, 16) * k, mid + Vector2(12, 16) * k, col, 2.0 * k, true)
			for raw in [[Vector2(-14, 9), Vector2(-9, -3), Vector2(-3, 2), Vector2(-5, 9)], [Vector2(-1, 9), Vector2(3, -9), Vector2(9, -2), Vector2(7, 9)], [Vector2(10, 9), Vector2(13, 1), Vector2(17, 9)]]:
				var chunk := _p(mid, k, raw)
				c.draw_colored_polygon(chunk, Color(0.22, 0.18, 0.16))
				chunk.append(chunk[0])
				c.draw_polyline(chunk, light, 1.6 * k, true)
		"fire_stoked_breath":   # Stoked Breath: a calm flame filling a bar of Fury beside it
			c.draw_colored_polygon(_p(mid, k, [Vector2(-8, -12), Vector2(-2, -2), Vector2(-3, 10), Vector2(-13, 10), Vector2(-15, -1)]), col)
			c.draw_circle(mid + Vector2(-8, 5) * k, 3.0 * k, Color(1.0, 0.9, 0.4))
			for i in 5:
				var y := 12.0 - i * 6.0
				c.draw_rect(Rect2(mid + Vector2(5, y - 4) * k, Vector2(10, 4.5) * k), Color(0.9, 0.25, 0.1) if i < 4 else Color(0.25, 0.12, 0.1), true)
			c.draw_rect(Rect2(mid + Vector2(4, -17) * k, Vector2(12, 34) * k), light, false, 1.4 * k)
		"fire_damped_embers":   # Damped Embers: a row of steady embers under a lid that keeps them from flaring
			c.draw_line(mid + Vector2(-16, -6) * k, mid + Vector2(16, -6) * k, WHITE, 2.4 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(-6, -15), Vector2(0, -9), Vector2(6, -15)]), light, 2.2 * k, true)
			for i in 4:
				var at := mid + Vector2(-12 + i * 8, 6) * k
				c.draw_circle(at, 4.0 * k, Color(col, 0.85))
				c.draw_circle(at, 1.8 * k, Color(1.0, 0.9, 0.4))
			c.draw_line(mid + Vector2(-16, 14) * k, mid + Vector2(16, 14) * k, Color(light, 0.5), 1.5 * k, true)
		"fire_wild_embers":   # Wild Embers: embers flying out in all directions, two of them bursting
			for p in [Vector2(-13, -11), Vector2(12, -13), Vector2(-15, 8), Vector2(14, 10), Vector2(0, 15)]:
				var at := mid + (p as Vector2) * k
				c.draw_line(mid, at, Color(col, 0.55), 1.6 * k, true)
				c.draw_circle(at, 3.2 * k, light)
			for p in [Vector2(12, -13), Vector2(-15, 8)]:
				var star := PackedVector2Array()
				for i in 10:
					var a := TAU * i / 10.0
					star.append(mid + (p as Vector2) * k + Vector2(cos(a), sin(a)) * (6.5 if i % 2 == 0 else 2.5) * k)
				c.draw_colored_polygon(star, Color(1.0, 0.9, 0.4))
			c.draw_circle(mid, 4.5 * k, col)
			c.draw_circle(mid, 2.0 * k, WHITE)
		"fire_blowback":   # Blowback: a crit burst whose lost fury blows back onto a burning target
			var burst := PackedVector2Array()
			for i in 12:
				var a := TAU * i / 12.0
				burst.append(mid + Vector2(-9, -7) * k + Vector2(cos(a), sin(a)) * (9.0 if i % 2 == 0 else 3.5) * k)
			c.draw_colored_polygon(burst, Color(1.0, 0.9, 0.4))
			c.draw_arc(mid + Vector2(1, -1) * k, 12.0 * k, PI * 1.25, PI * 2.15, 14, light, 2.4 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(13, 3), Vector2(16, 9), Vector2(9, 9)]), light)
			c.draw_colored_polygon(_p(mid, k, [Vector2(8, 4), Vector2(13, 11), Vector2(11, 17), Vector2(3, 17), Vector2(1, 11)]), col)
			c.draw_circle(mid + Vector2(7, 13) * k, 2.2 * k, Color(1.0, 0.9, 0.4))
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
		# --- Fire on the column-group tree (2026-10-23) ---
		"fire_lean_fuel":   # a thin Fury bar with a small chunk cut off its cost
			c.draw_rect(Rect2(mid + Vector2(-15, -4) * k, Vector2(30, 8) * k), Color(0.2, 0.12, 0.1), true)
			c.draw_rect(Rect2(mid + Vector2(-15, -4) * k, Vector2(19, 8) * k), col, true)
			c.draw_rect(Rect2(mid + Vector2(-15, -4) * k, Vector2(30, 8) * k), light, false, 1.4 * k)
			c.draw_line(mid + Vector2(8, -12) * k, mid + Vector2(14, -12) * k, WHITE, 2.4 * k, true)
			c.draw_rect(Rect2(mid + Vector2(6, 8) * k, Vector2(7, 5) * k), Color(light, 0.6), true)
		"fire_hold_the_heat":   # a flame inside cupped hands
			_fire(c, mid + Vector2(0, -3) * k, k, col, Color(1.0, 0.9, 0.4))
			for s in [-1.0, 1.0]:
				c.draw_arc(mid + Vector2(0, 2) * k, 13.0 * k, PI * 0.5 - s * 0.2, PI * 0.5 + s * 1.3, 10, light, 3.0 * k, true)
		"fire_long_focus":   # an hourglass with a steady flame in its top half
			_hourglass(c, mid, k, Color(col, 0.6), light)
			_fire(c, mid + Vector2(0, -9) * k, k * 0.45, Color(1.0, 0.9, 0.4), WHITE)
		"fire_clean_burn":   # a clean, even flame on a level line, no sparks
			c.draw_line(mid + Vector2(-15, 13) * k, mid + Vector2(15, 13) * k, light, 2.0 * k, true)
			_fire(c, mid + Vector2(0, 0) * k, k * 1.15, col, Color(1.0, 0.9, 0.4))
			c.draw_line(mid + Vector2(-13, -14) * k, mid + Vector2(-7, -14) * k, Color(WHITE, 0.6), 1.4 * k, true)
		"fire_big_spend":   # a Fury bar pouring out into one big blast
			c.draw_rect(Rect2(mid + Vector2(-16, -14) * k, Vector2(9, 28) * k), Color(0.2, 0.12, 0.1), true)
			c.draw_rect(Rect2(mid + Vector2(-16, -14) * k, Vector2(9, 28) * k), light, false, 1.4 * k)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-7, -6), Vector2(16, -14), Vector2(16, 14), Vector2(-7, 6)]), Color(col, 0.8))
			c.draw_circle(mid + Vector2(9, 0) * k, 5.0 * k, WHITE)
		"fire_low_flame":   # a small, low flame under a high mark it never reaches
			_fire(c, mid + Vector2(0, 7) * k, k * 0.6, col, Color(1.0, 0.9, 0.4))
			c.draw_line(mid + Vector2(-14, -8) * k, mid + Vector2(14, -8) * k, Color(light, 0.7), 1.6 * k, true)
			for x in [-12.0, 12.0]:
				c.draw_line(mid + Vector2(x, -12) * k, mid + Vector2(x, -4) * k, Color(light, 0.7), 1.6 * k, true)
		"fire_stay_lit":   # a flame bursting, a second flame already relit beside it
			for i in 6:
				var a := TAU * i / 6.0
				c.draw_line(mid + Vector2(-6, -4) * k + Vector2(cos(a), sin(a)) * 5.0 * k, mid + Vector2(-6, -4) * k + Vector2(cos(a), sin(a)) * 10.0 * k, light, 1.8 * k, true)
			_fire(c, mid + Vector2(8, 6) * k, k * 0.7, col, Color(1.0, 0.9, 0.4))
		"fire_hard_crust":   # a shield with a thick crust of slag plates on its face
			_shield(c, mid, k, Color(0.24, 0.19, 0.17), light)
			for p in [Vector2(-5, -6), Vector2(4, -6), Vector2(0, 3)]:
				c.draw_rect(Rect2(mid + ((p as Vector2) + Vector2(-4, -3)) * k, Vector2(8, 6) * k), col, true)
		"fire_set_hard":   # a cracked slag stack held by a clamp, a clock beside it
			c.draw_rect(Rect2(mid + Vector2(-14, -6) * k, Vector2(16, 14) * k), Color(0.3, 0.22, 0.2), true)
			c.draw_polyline(_p(mid, k, [Vector2(-10, -6), Vector2(-6, 1), Vector2(-9, 8)]), Color(1.0, 0.9, 0.4), 1.6 * k, true)
			c.draw_rect(Rect2(mid + Vector2(-16, -9) * k, Vector2(20, 20) * k), light, false, 2.0 * k)
			_clock(c, mid + Vector2(10, -8) * k, 6.0 * k, WHITE, k)
		"fire_red_iron":   # a shield boss glowing red-hot
			_shield(c, mid, k, Color(0.4, 0.38, 0.4), light)
			c.draw_circle(mid, 6.0 * k, Color(1.0, 0.3, 0.12))
			c.draw_circle(mid, 3.0 * k, Color(1.0, 0.85, 0.4))
		"fire_marked_iron":   # a brand mark on a slab of slag breaking apart
			c.draw_colored_polygon(_p(mid, k, [Vector2(-14, -10), Vector2(-1, -12), Vector2(1, 12), Vector2(-13, 10)]), Color(0.3, 0.22, 0.2))
			c.draw_colored_polygon(_p(mid, k, [Vector2(3, -12), Vector2(15, -9), Vector2(13, 11), Vector2(4, 12)]), Color(0.3, 0.22, 0.2))
			c.draw_arc(mid, 7.0 * k, 0, TAU, 18, Color(1.0, 0.9, 0.4), 2.4 * k, true)
			c.draw_line(mid + Vector2(-4, 0) * k, mid + Vector2(4, 0) * k, light, 2.0 * k, true)
		"fire_fuel_the_forge":   # a blocked blow sending a spark into a Fury bar
			_shield(c, mid + Vector2(-5, 0) * k, k * 0.8, Color(0.3, 0.24, 0.22), light)
			c.draw_rect(Rect2(mid + Vector2(10, -14) * k, Vector2(6, 28) * k), Color(0.2, 0.12, 0.1), true)
			c.draw_rect(Rect2(mid + Vector2(10, 2) * k, Vector2(6, 12) * k), col, true)
			c.draw_line(mid + Vector2(3, -4) * k, mid + Vector2(9, -10) * k, Color(1.0, 0.9, 0.4), 2.0 * k, true)
		"fire_deep_slag":   # a tall stack of slag plates, one more on top
			for i in 5:
				c.draw_rect(Rect2(mid + Vector2(-10, 12 - i * 6) * k, Vector2(20, 5) * k), Color(0.3 + i * 0.05, 0.22, 0.2), true)
				c.draw_line(mid + Vector2(-10, 12 - i * 6) * k, mid + Vector2(10, 12 - i * 6) * k, Color(col, 0.8), 1.2 * k, true)
			_plus(c, mid + Vector2(13, -14) * k, 4.0 * k, WHITE, 2.0 * k)
		"fire_riveted":   # a glowing rivet head with a quick arrow round it
			c.draw_circle(mid, 7.0 * k, Color(1.0, 0.45, 0.15))
			c.draw_circle(mid, 3.5 * k, Color(1.0, 0.85, 0.4))
			c.draw_arc(mid, 13.0 * k, -PI * 0.2, PI * 1.3, 18, light, 2.0 * k, true)
			var tip := mid + Vector2(cos(PI * 1.3), sin(PI * 1.3)) * 13.0 * k
			c.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(5, 1) * k, tip + Vector2(1, 5) * k]), light)
		"fire_heavy_hammer":   # a heavy hammer with Fury sparks flying back to it
			c.draw_line(mid + Vector2(-12, 14) * k, mid + Vector2(4, -2) * k, Color(0.55, 0.4, 0.3), 3.2 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-2, -12), Vector2(10, -2), Vector2(14, -6), Vector2(2, -16)]), Color(0.5, 0.48, 0.5))
			for p in [Vector2(12, 8), Vector2(16, 2), Vector2(8, 13)]:
				c.draw_circle(mid + (p as Vector2) * k, 2.0 * k, col)
		"fire_glowing_seams":   # slag plates with bright seams between them, an eye of threat
			for x in [-12.0, -2.0, 8.0]:
				c.draw_rect(Rect2(mid + Vector2(x, -8) * k, Vector2(8, 16) * k), Color(0.28, 0.2, 0.18), true)
			for x in [-3.0, 7.0]:
				c.draw_line(mid + Vector2(x, -8) * k, mid + Vector2(x, 8) * k, Color(1.0, 0.85, 0.4), 2.0 * k, true)
			c.draw_arc(mid + Vector2(0, -13) * k, 4.0 * k, PI, TAU, 8, Color(1.0, 0.35, 0.25), 1.8 * k, true)
		"fire_long_shell":   # a molten shell with a long clock hand
			c.draw_arc(mid, 13.0 * k, 0, TAU, 28, col, 4.0 * k, true)
			c.draw_arc(mid, 15.5 * k, 0, TAU, 28, Color(1.0, 0.85, 0.4), 1.4 * k, true)
			c.draw_line(mid, mid + Vector2(0, -9) * k, WHITE, 2.0 * k, true)
			c.draw_line(mid, mid + Vector2(7, 3) * k, WHITE, 2.0 * k, true)
		"fire_spatter":   # slag bursting, one plate falling back onto the shield
			for a in [-2.6, -1.9, -1.2, -0.5]:
				var d := Vector2(cos(a), sin(a))
				c.draw_rect(Rect2(mid + d * 12.0 * k - Vector2(2, 2) * k, Vector2(4, 4) * k), Color(0.35, 0.25, 0.22), true)
			_shield(c, mid + Vector2(0, 5) * k, k * 0.6, Color(0.3, 0.24, 0.22), light)
			c.draw_rect(Rect2(mid + Vector2(-3, 2) * k, Vector2(6, 4) * k), col, true)
		"fire_quick_temper":   # a shield with a fast arrow round its rim
			_shield(c, mid, k * 0.75, Color(0.24, 0.19, 0.17), light)
			c.draw_arc(mid, 15.0 * k, PI * 0.9, PI * 2.1, 18, Color(1.0, 0.9, 0.4), 2.0 * k, true)
			var arc_end := mid + Vector2(cos(PI * 2.1), sin(PI * 2.1)) * 15.0 * k
			c.draw_colored_polygon(PackedVector2Array([arc_end, arc_end + Vector2(-5, -2) * k, arc_end + Vector2(-1, -6) * k]), Color(1.0, 0.9, 0.4))
		"fire_molten_heart":   # a heart of molten slag, plates around it
			var heart := _p(mid, k, [Vector2(0, 12), Vector2(-12, 0), Vector2(-12, -7), Vector2(-6, -12), Vector2(0, -7), Vector2(6, -12), Vector2(12, -7), Vector2(12, 0)])
			c.draw_colored_polygon(heart, col)
			heart.append(heart[0])
			c.draw_polyline(heart, Color(1.0, 0.9, 0.4), 1.8 * k, true)
			for p in [Vector2(-15, 10), Vector2(15, 10), Vector2(0, -16)]:
				c.draw_rect(Rect2(mid + ((p as Vector2) + Vector2(-2.5, -2)) * k, Vector2(5, 4) * k), Color(0.35, 0.25, 0.22), true)
		"fire_bright_sparks":   # a hammer strike throwing many bright sparks
			c.draw_rect(Rect2(mid + Vector2(-14, 8) * k, Vector2(28, 6) * k), Color(0.45, 0.43, 0.45), true)
			for a in [-2.8, -2.3, -1.8, -1.3, -0.8, -0.3]:
				var d := Vector2(cos(a), sin(a))
				c.draw_line(mid + Vector2(0, 7) * k + d * 4.0 * k, mid + Vector2(0, 7) * k + d * 16.0 * k, Color(1.0, 0.9, 0.4), 1.8 * k, true)
				c.draw_circle(mid + Vector2(0, 7) * k + d * 17.0 * k, 1.4 * k, WHITE)
		"fire_spark_bite":   # a spark with teeth biting into a blade's edge
			c.draw_line(mid + Vector2(-15, 12) * k, mid + Vector2(12, -12) * k, Color(0.85, 0.85, 0.9), 3.4 * k, true)
			for i in 3:
				var at := mid + Vector2(-4 + i * 5, -2 - i * 4) * k
				c.draw_colored_polygon(PackedVector2Array([at, at + Vector2(3, 4) * k, at + Vector2(-2, 4) * k]), Color(1.0, 0.9, 0.4))
			_star(c, mid + Vector2(7, -10) * k, 5.0 * k, WHITE, 4)
		"fire_hard_quench":   # a white-hot blade plunged into water, a big splash
			c.draw_rect(Rect2(mid + Vector2(-15, 4) * k, Vector2(30, 11) * k), Color(0.3, 0.55, 0.85, 0.7), true)
			c.draw_line(mid + Vector2(0, -16) * k, mid + Vector2(0, 8) * k, Color(1.0, 0.95, 0.75), 4.0 * k, true)
			for x in [-10.0, -5.0, 5.0, 10.0]:
				c.draw_line(mid + Vector2(x * 0.5, 3) * k, mid + Vector2(x, -5) * k, WHITE, 1.6 * k, true)
		"fire_wide_flare":   # a very wide flaming sweep
			c.draw_arc(mid + Vector2(0, 14) * k, 20.0 * k, PI * 1.02, PI * 1.98, 20, Color(col, 0.7), 7.0 * k, true)
			c.draw_arc(mid + Vector2(0, 14) * k, 20.0 * k, PI * 1.02, PI * 1.98, 20, Color(1.0, 0.9, 0.4), 1.8 * k, true)
			for x in [-17.0, 17.0]:
				c.draw_line(mid + Vector2(x, 10) * k, mid + Vector2(x * 1.05, 4) * k, WHITE, 2.0 * k, true)
		"fire_banked_fire":   # coals left glowing under a quenched blade
			c.draw_line(mid + Vector2(-12, -14) * k, mid + Vector2(10, 2) * k, Color(0.75, 0.78, 0.85), 3.4 * k, true)
			for p in [Vector2(-8, 11), Vector2(0, 13), Vector2(8, 11)]:
				c.draw_circle(mid + (p as Vector2) * k, 4.0 * k, Color(0.25, 0.15, 0.12))
				c.draw_circle(mid + (p as Vector2) * k, 2.2 * k, col)
		"fire_hammer_rhythm":   # a hammer and three beats of a rhythm
			c.draw_line(mid + Vector2(-14, 14) * k, mid + Vector2(-2, 2) * k, Color(0.55, 0.4, 0.3), 3.0 * k, true)
			c.draw_rect(Rect2(mid + Vector2(-6, -6) * k, Vector2(10, 7) * k), Color(0.5, 0.48, 0.5), true)
			for i in 3:
				c.draw_line(mid + Vector2(7 + i * 4, -6 + i * 2) * k, mid + Vector2(7 + i * 4, 6 + i * 2) * k, light, 2.0 * k, true)
				c.draw_circle(mid + Vector2(5 + i * 4, 6 + i * 2) * k, 2.0 * k, light)
		"fire_fold_again":   # a blade folded into many glowing layers, a plus
			for i in 5:
				c.draw_line(mid + Vector2(-14, -12 + i * 5) * k, mid + Vector2(6, -11 + i * 5) * k, Color(1.0, 0.45 + i * 0.1, 0.15 + i * 0.12), 3.0 * k, true)
			_plus(c, mid + Vector2(12, 8) * k, 4.0 * k, WHITE, 2.0 * k)
		"fire_deep_sear":   # a deep scorch mark burning into a surface
			c.draw_rect(Rect2(mid + Vector2(-15, -6) * k, Vector2(30, 20) * k), Color(0.45, 0.38, 0.32), true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-8, -6), Vector2(8, -6), Vector2(4, 10), Vector2(-4, 10)]), Color(0.15, 0.08, 0.05))
			_fire(c, mid + Vector2(0, -6) * k, k * 0.65, col, Color(1.0, 0.9, 0.4))
		"fire_overheat":   # a white-hot blade with heat waves rolling off it
			c.draw_line(mid + Vector2(-14, 14) * k, mid + Vector2(10, -10) * k, Color(1.0, 0.95, 0.75), 4.2 * k, true)
			for i in 3:
				var o := Vector2(4 + i * 4, 4 + i * 4)
				c.draw_arc(mid + o * k, 6.0 * k, -PI * 0.25, PI * 0.75, 8, Color(col, 0.9 - i * 0.25), 1.8 * k, true)
		"fire_steady_arm":   # an arm braced with a steady hand-clock beside it
			c.draw_line(mid + Vector2(-15, 12) * k, mid + Vector2(-3, 0) * k, light, 4.0 * k, true)
			c.draw_line(mid + Vector2(-3, 0) * k, mid + Vector2(-3, -12) * k, light, 4.0 * k, true)
			c.draw_circle(mid + Vector2(-3, -13) * k, 3.0 * k, light)
			_clock(c, mid + Vector2(9, 5) * k, 7.0 * k, Color(1.0, 0.75, 0.3), k)
		"fire_long_blast":   # a furnace mouth with a long flame and a clock
			c.draw_rect(Rect2(mid + Vector2(-15, -2) * k, Vector2(12, 14) * k), Color(0.3, 0.24, 0.22), true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-4, 1), Vector2(16, 3), Vector2(16, 7), Vector2(-4, 9)]), Color(1.0, 0.95, 0.75))
			_clock(c, mid + Vector2(8, -9) * k, 6.0 * k, WHITE, k)
		"fire_cold_steel":   # a cold blue-white blade with a crit star at its tip
			c.draw_line(mid + Vector2(-14, 14) * k, mid + Vector2(10, -10) * k, Color(0.75, 0.85, 1.0), 3.6 * k, true)
			c.draw_line(mid + Vector2(-16, 16) * k, mid + Vector2(-12, 12) * k, Color(0.4, 0.25, 0.15), 3.6 * k, true)
			_star(c, mid + Vector2(11, -11) * k, 6.0 * k, WHITE, 4)
		"fire_quick_forge":   # an anvil with a spark and a fast clock hand
			c.draw_colored_polygon(_p(mid, k, [Vector2(-15, 2), Vector2(9, 2), Vector2(9, 7), Vector2(3, 9), Vector2(3, 14), Vector2(-9, 14), Vector2(-9, 9), Vector2(-15, 7)]), Color(0.45, 0.43, 0.45))
			_star(c, mid + Vector2(-3, -4) * k, 4.0 * k, Color(1.0, 0.9, 0.4), 4)
			_clock(c, mid + Vector2(10, -9) * k, 6.0 * k, light, k)
			c.draw_line(mid + Vector2(10, -9) * k, mid + Vector2(14, -12) * k, WHITE, 1.6 * k, true)
		"fire_molten_edge":   # a blade dripping molten metal
			c.draw_line(mid + Vector2(-14, -12) * k, mid + Vector2(14, -6) * k, Color(0.75, 0.75, 0.8), 4.0 * k, true)
			c.draw_line(mid + Vector2(-14, -10) * k, mid + Vector2(14, -4) * k, Color(1.0, 0.5, 0.15), 2.0 * k, true)
			for p in [Vector2(-6, 2), Vector2(4, 6), Vector2(11, 1)]:
				_drop(c, mid + (p as Vector2) * k, k * 0.35, col, Color(1.0, 0.9, 0.4), k * 0.6)
		"fire_sticky_pitch":   # a dark blob of pitch with strings stretching from it
			c.draw_circle(mid + Vector2(-2, -2) * k, 9.0 * k, Color(0.12, 0.09, 0.08))
			for x in [-8.0, -1.0, 6.0]:
				c.draw_line(mid + Vector2(x, 5) * k, mid + Vector2(x * 1.2, 15) * k, Color(0.25, 0.18, 0.12), 1.8 * k, true)
			c.draw_arc(mid + Vector2(-2, -2) * k, 9.0 * k, PI * 1.1, PI * 1.6, 6, light, 1.6 * k, true)
		"fire_light_string":   # a thin bowstring drawn lightly, a small Energy spark
			c.draw_arc(mid + Vector2(6, 0) * k, 16.0 * k, PI * 0.6, PI * 1.4, 16, Color(0.6, 0.45, 0.3), 3.0 * k, true)
			c.draw_line(mid + Vector2(-3, -15) * k, mid + Vector2(-3, 15) * k, Color(light, 0.9), 1.0 * k, true)
			_star(c, mid + Vector2(10, -6) * k, 4.0 * k, Color(1.0, 0.9, 0.4), 4)
		"fire_big_flash":   # a huge flash bursting out of a coat of pitch
			c.draw_colored_polygon(_p(mid, k, [Vector2(-12, 8), Vector2(12, 8), Vector2(10, 15), Vector2(-10, 15)]), Color(0.12, 0.09, 0.08))
			for i in 8:
				var a := PI + PI * i / 7.0
				c.draw_line(mid + Vector2(0, 6) * k, mid + Vector2(0, 6) * k + Vector2(cos(a), sin(a)) * 17.0 * k, Color(1.0, 0.85, 0.4), 2.0 * k, true)
			c.draw_circle(mid + Vector2(0, 6) * k, 5.0 * k, WHITE)
		"fire_dripping":   # pitch dripping onto a flame that flares up
			c.draw_rect(Rect2(mid + Vector2(-14, -16) * k, Vector2(28, 5) * k), Color(0.12, 0.09, 0.08), true)
			for x in [-7.0, 6.0]:
				c.draw_circle(mid + Vector2(x, -6) * k, 2.4 * k, Color(0.12, 0.09, 0.08))
			_fire(c, mid + Vector2(0, 8) * k, k * 0.75, col, Color(1.0, 0.9, 0.4))
		"fire_double_coat":   # two pitch-dipped arrowheads side by side
			for x in [-6.0, 6.0]:
				c.draw_line(mid + Vector2(x, 16) * k, mid + Vector2(x, -4) * k, Color(0.75, 0.55, 0.35), 2.4 * k, true)
				c.draw_colored_polygon(_p(mid, k, [Vector2(x, -16), Vector2(x + 5, -5), Vector2(x - 5, -5)]), Color(0.12, 0.09, 0.08))
			c.draw_line(mid + Vector2(-14, -10) * k, mid + Vector2(14, -10) * k, Color(light, 0.5), 1.2 * k, true)
		"fire_hot_shafts":   # an arrow shaft wreathed in fire along its length
			_arrow_line(c, mid, k, Color(0.75, 0.55, 0.35), light)
			for i in 3:
				_fire(c, mid + Vector2(-8 + i * 7, 8 - i * 7) * k, k * 0.35, col, Color(1.0, 0.9, 0.4))
		"fire_second_light":   # a torch lit twice: two small flames on one torch
			c.draw_line(mid + Vector2(-6, 16) * k, mid + Vector2(2, -2) * k, Color(0.55, 0.4, 0.3), 3.2 * k, true)
			_fire(c, mid + Vector2(1, -7) * k, k * 0.55, col, Color(1.0, 0.9, 0.4))
			_fire(c, mid + Vector2(11, -11) * k, k * 0.4, light, WHITE)
		"fire_ember_bed":   # a bed of embers with a thin pitch coat on top
			for i in 5:
				var x := -14.0 + i * 7.0
				c.draw_circle(mid + Vector2(x, 9) * k, 3.4 * k, Color(0.25, 0.15, 0.12))
				c.draw_circle(mid + Vector2(x, 9) * k, 1.8 * k, col)
			c.draw_line(mid + Vector2(-16, 3) * k, mid + Vector2(16, 3) * k, Color(0.12, 0.09, 0.08), 3.0 * k, true)
			_fire(c, mid + Vector2(0, -6) * k, k * 0.5, col, Color(1.0, 0.9, 0.4))
		"fire_wide_rain":   # burning arrows falling over a wide circle
			c.draw_arc(mid + Vector2(0, 10) * k, 16.0 * k, PI, TAU, 18, Color(col, 0.7), 2.0 * k, true)
			for x in [-12.0, -4.0, 4.0, 12.0]:
				c.draw_line(mid + Vector2(x - 3, -14) * k, mid + Vector2(x, 6) * k, Color(0.75, 0.55, 0.35), 1.8 * k, true)
				c.draw_circle(mid + Vector2(x - 3, -15) * k, 1.6 * k, Color(1.0, 0.6, 0.2))
		"fire_fuel_run":   # a burst of flame feeding a bar of Energy
			_fire(c, mid + Vector2(-6, 2) * k, k * 0.8, col, Color(1.0, 0.9, 0.4))
			c.draw_rect(Rect2(mid + Vector2(8, -14) * k, Vector2(7, 28) * k), Color(0.15, 0.13, 0.1), true)
			c.draw_rect(Rect2(mid + Vector2(8, 0) * k, Vector2(7, 14) * k), Color(1.0, 0.85, 0.3), true)
		"fire_patient_fire":   # five pitch layers stacked under a steady aimed arrow
			for i in 5:
				c.draw_rect(Rect2(mid + Vector2(-12, 14 - i * 4) * k, Vector2(24, 3) * k), Color(0.15 + i * 0.03, 0.1, 0.08), true)
			c.draw_line(mid + Vector2(0, -16) * k, mid + Vector2(0, -2) * k, Color(0.75, 0.55, 0.35), 2.4 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(0, 1), Vector2(-4, -5), Vector2(4, -5)]), light)
		"fire_kindle_pack":   # one flash hitting a pack of three, a layer coming back
			for p in [Vector2(-11, 6), Vector2(0, 10), Vector2(11, 6)]:
				c.draw_circle(mid + (p as Vector2) * k, 4.0 * k, Color(light, 0.45))
			c.draw_circle(mid + Vector2(0, -6) * k, 6.0 * k, Color(1.0, 0.85, 0.4))
			c.draw_arc(mid + Vector2(0, -6) * k, 10.0 * k, PI * 0.2, PI * 0.8, 8, Color(0.12, 0.09, 0.08), 3.0 * k, true)
		"fire_long_brush":   # long grass burning in a long line, a clock above
			for i in 7:
				c.draw_line(mid + Vector2(-15 + i * 5, 15) * k, mid + Vector2(-13 + i * 5, 6) * k, Color(0.75, 0.62, 0.3), 1.4 * k, true)
			c.draw_line(mid + Vector2(-15, 6) * k, mid + Vector2(15, 6) * k, col, 3.0 * k, true)
			_clock(c, mid + Vector2(0, -8) * k, 7.0 * k, light, k)
		"fire_steady_bow":   # a bow held level, a calm Energy drop beside it
			c.draw_arc(mid + Vector2(-2, 0) * k, 14.0 * k, -PI * 0.4, PI * 0.4, 12, Color(0.6, 0.45, 0.3), 3.0 * k, true)
			c.draw_line(mid + Vector2(-2 + 14 * cos(-PI * 0.4), 14 * sin(-PI * 0.4)) * k, mid + Vector2(-2 + 14 * cos(PI * 0.4), 14 * sin(PI * 0.4)) * k, light, 1.0 * k, true)
			c.draw_circle(mid + Vector2(-11, 0) * k, 4.0 * k, Color(1.0, 0.85, 0.3))
		"fire_clean_shot":   # a clean arrow into a pitched target, no crit spark
			c.draw_circle(mid + Vector2(6, -6) * k, 9.0 * k, Color(0.12, 0.09, 0.08))
			c.draw_arc(mid + Vector2(6, -6) * k, 9.0 * k, 0, TAU, 20, light, 1.4 * k, true)
			c.draw_line(mid + Vector2(-15, 15) * k, mid + Vector2(4, -4) * k, Color(0.75, 0.55, 0.35), 2.4 * k, true)
		"fire_fire_line":   # a burning target far down a dotted line
			for i in 5:
				c.draw_circle(mid + Vector2(-15 + i * 5, 10 - i * 4) * k, 1.4 * k, Color(light, 0.8))
			c.draw_circle(mid + Vector2(10, -10) * k, 6.0 * k, Color(light, 0.35))
			_fire(c, mid + Vector2(10, -11) * k, k * 0.45, col, Color(1.0, 0.9, 0.4))
		"fire_pitch_black":   # a black sphere of pitch with a red-hot core showing through
			c.draw_circle(mid, 14.0 * k, Color(0.07, 0.05, 0.05))
			for i in 5:
				var a := TAU * i / 5.0
				c.draw_arc(mid, (5.0 + i * 1.8) * k, a, a + 0.9, 6, Color(col, 0.5 + i * 0.1), 1.4 * k, true)
			c.draw_circle(mid, 3.0 * k, Color(1.0, 0.35, 0.12))
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
		"frost_cold_draw":   # Cold Draw: a frosted target, three drops (Energy, Fury, mana) drawn out of it
			_ellipse(c, mid + Vector2(0, 8) * k, Vector2(14, 9) * k, col.darkened(0.4), light, 1.5 * k)
			_flake(c, mid + Vector2(0, 8) * k, 6.0 * k, Color(light, 0.9), 1.5 * k)
			var drops := [Color(1.0, 0.9, 0.35), Color(0.9, 0.25, 0.2), Color(0.35, 0.55, 1.0)]
			for i in 3:
				_drop(c, mid + Vector2(-11 + i * 11, -10 + absf(i - 1.0) * 3.0) * k, 0.42 * k, drops[i], WHITE, k * 0.7)
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
		# --- Cold Comfort (the Frost healer) ---
		"frost_deep_cracks":   # Deep Cracks: a shell split by deep cracks, shards bursting out
			c.draw_arc(mid, 13.0 * k, 0, TAU, 26, light, 2.5 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(-10, -8), Vector2(-2, -2), Vector2(-6, 6), Vector2(2, 12)]), WHITE, 2.2 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(10, -10), Vector2(3, -3), Vector2(8, 4)]), WHITE, 2.2 * k, true)
			_plus(c, mid + Vector2(14, 13) * k, 4.0 * k, Color(0.45, 1.0, 0.45), 2.0 * k)
		"frost_cold_spread":   # Cold Spread: rings of healing ice spreading out
			for i in 3:
				c.draw_arc(mid, (5.0 + i * 5.0) * k, 0, TAU, 20, Color(light if i < 2 else WHITE, 0.9 - i * 0.2), 2.0 * k, true)
			_plus(c, mid, 3.5 * k, Color(0.45, 1.0, 0.45), 2.0 * k)
		"frost_slow_runoff":   # Slow Runoff: drops running off a melting shell
			c.draw_arc(mid + Vector2(0, -4) * k, 11.0 * k, PI, TAU, 16, light, 2.5 * k, true)
			for p in [Vector2(-7, 6), Vector2(0, 11), Vector2(7, 6)]:
				_drop(c, mid + (p as Vector2) * k, 0.3 * k, Color(col, 0.9), WHITE, k * 0.6)
		"frost_shard_spray":   # Shard Spray: shards flying out, each with a little shield
			for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 1)]:
				_shard(c, mid + (d as Vector2).normalized() * 15.0 * k, (d as Vector2).normalized(), 9.0 * k, 3.0 * k, Color(col, 0.85), WHITE, k)
			c.draw_arc(mid, 5.0 * k, 0, TAU, 12, WHITE, 2.0 * k, true)
		"frost_splinterheal":   # Splinterheal: a shattering splinter turning into a heal
			_shard(c, mid + Vector2(-8, -8) * k, Vector2(-1, -1).normalized(), 14.0 * k, 4.0 * k, Color(col, 0.85), WHITE, k)
			c.draw_line(mid + Vector2(-2, -2) * k, mid + Vector2(6, 6) * k, light, 2.0 * k, true)
			_plus(c, mid + Vector2(9, 9) * k, 6.0 * k, Color(0.45, 1.0, 0.45), 3.0 * k)
		"frost_wide_lattice":   # Wide Lattice: four shells joined by threads of ice
			var spots := [Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)]
			for i in 4:
				c.draw_line(mid + (spots[i] as Vector2) * k, mid + (spots[(i + 1) % 4] as Vector2) * k, light, 2.0 * k, true)
			for p in spots:
				c.draw_circle(mid + (p as Vector2) * k, 4.5 * k, Color(col, 0.85))
				c.draw_arc(mid + (p as Vector2) * k, 4.5 * k, 0, TAU, 12, WHITE, 1.5 * k, true)
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
		"frost_clean_break":   # Clean Break: an ice block snapped in two, a drop of fury coming back out
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
		"frost_long_chill":   # Lingering Frost: hourglass with snow
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
		# --- Frost melee: Frostbitten Steel (Glaze) and Glacier Wall (Ice Layers) ---
		"frost_cold_sweep":   # Cold Sweep: a wide arc turning a chilled shape into a block of ice
			c.draw_arc(mid + Vector2(0, 8) * k, 15.0 * k, PI * 1.1, PI * 1.9, 14, WHITE, 2.4 * k, true)
			c.draw_circle(mid + Vector2(-8, -2) * k, 4.5 * k, Color(light, 0.5))
			c.draw_rect(Rect2(mid + Vector2(3, -7) * k, Vector2(10, 10) * k), Color(col, 0.8), true)
			c.draw_rect(Rect2(mid + Vector2(3, -7) * k, Vector2(10, 10) * k), WHITE, false, 1.4 * k)
		"frost_ice_fall":   # Ice Fall: one big slab falling with small chunks around it
			c.draw_colored_polygon(_p(mid, k, [Vector2(-7, -13), Vector2(7, -13), Vector2(9, 5), Vector2(-6, 8)]), Color(col, 0.85))
			for p in [Vector2(-14, 10), Vector2(13, 9), Vector2(0, 15)]:
				_shard(c, mid + (p as Vector2) * k, Vector2(0, 1), 7.0 * k, 2.2 * k, Color(light, 0.8), WHITE, k)
		"frost_long_dark":   # Long Dark: a dark snowflake with a clock in its middle
			c.draw_circle(mid, 14.0 * k, Color(0.05, 0.08, 0.16))
			_flake(c, mid, 12.0 * k, col, 2.0 * k)
			_clock(c, mid, 6.0 * k, WHITE, k)
		"frost_glinting_rime":   # Glinting Rime: a blade edge with five glints on it
			c.draw_line(mid + Vector2(-15, 12) * k, mid + Vector2(14, -12) * k, Color(0.92, 0.92, 0.96), 3.4 * k, true)
			for i in 5:
				_flake(c, mid + Vector2(-11 + i * 5.5, 9 - i * 5) * k + Vector2(3, 3) * k, 2.6 * k, WHITE, 1.4 * k)
		"frost_biting_hold":   # Biting Hold: two fangs closing on a frozen block
			c.draw_rect(Rect2(mid + Vector2(-7, -5) * k, Vector2(14, 12) * k), Color(col, 0.6), true)
			_shard(c, mid + Vector2(-4, -3) * k, Vector2(0, 1), 12.0 * k, 3.2 * k, Color(0.9, 0.95, 1.0), WHITE, k)
			_shard(c, mid + Vector2(4, 5) * k, Vector2(0, -1), 12.0 * k, 3.2 * k, Color(0.9, 0.95, 1.0), WHITE, k)
		"frost_long_glaze":   # Long Glaze: a blade with rime on it and an hourglass
			c.draw_line(mid + Vector2(-15, 12) * k, mid + Vector2(2, -6) * k, Color(0.92, 0.92, 0.96), 3.0 * k, true)
			for i in 3:
				c.draw_circle(mid + Vector2(-11 + i * 5, 7 - i * 5) * k, 2.0 * k, light)
			_hourglass(c, mid + Vector2(9, -1) * k, k * 0.6, Color(col, 0.6), WHITE)
		"frost_deep_tremor":   # Deep Tremor: rings in the ground, a stack of layers above
			for i in 3:
				c.draw_arc(mid + Vector2(0, 12) * k, (5.0 + i * 5.0) * k, PI, TAU, 12, Color(light, 0.9 - i * 0.25), 2.0 * k, true)
			for i in 3:
				c.draw_rect(Rect2(mid + Vector2(-6, -14 + i * 4) * k, Vector2(12, 3) * k), Color(col, 0.6 + i * 0.1), true)
		"frost_packed_ice":   # Packed Ice: a shield with layers pressed into one block
			_shield(c, mid, k, Color(col, 0.4), light)
			for i in 3:
				c.draw_line(mid + Vector2(-8, -6 + i * 5) * k, mid + Vector2(8, -6 + i * 5) * k, WHITE, 2.0 * k, true)
		"frost_turned_backs":   # Turned Backs: three red glares turned toward a shield
			_shield(c, mid + Vector2(8, 0) * k, k * 0.7, Color(col, 0.6), WHITE)
			for p in [Vector2(-12, -10), Vector2(-14, 0), Vector2(-12, 10)]:
				c.draw_circle(mid + (p as Vector2) * k, 2.4 * k, Color(1.0, 0.35, 0.25))
				c.draw_line(mid + (p as Vector2) * k + Vector2(3, 0) * k, mid + Vector2(-1, 0) * k, Color(1.0, 0.35, 0.25, 0.5), 1.2 * k, true)
		"frost_cold_fury":   # Cold Fury: a cracked layer with a drop of fury coming out
			c.draw_rect(Rect2(mid + Vector2(-14, 2) * k, Vector2(28, 10) * k), Color(col, 0.6), true)
			c.draw_polyline(_p(mid, k, [Vector2(-2, 2), Vector2(2, 6), Vector2(-1, 12)]), WHITE, 1.6 * k, true)
			_drop(c, mid + Vector2(0, -6) * k, 0.55 * k, Color(0.85, 0.2, 0.15), WHITE, k)
		"frost_regelation":   # Regelation: two halves of a layer drawn back together by arrows
			c.draw_rect(Rect2(mid + Vector2(-14, -4) * k, Vector2(12, 10) * k), Color(col, 0.7), true)
			c.draw_rect(Rect2(mid + Vector2(2, -4) * k, Vector2(12, 10) * k), Color(col, 0.7), true)
			for s in [-1.0, 1.0]:
				c.draw_line(mid + Vector2(s * 12, -10) * k, mid + Vector2(s * 3, -10) * k, WHITE, 1.8 * k, true)
				c.draw_line(mid + Vector2(s * 3, -10) * k, mid + Vector2(s * 6, -13) * k, WHITE, 1.8 * k, true)
			_drop(c, mid + Vector2(0, 12) * k, 0.4 * k, Color(0.85, 0.2, 0.15), WHITE, k)
		"frost_old_ice":   # Old Ice: a tall glacier wall with an hourglass on it
			c.draw_colored_polygon(_p(mid, k, [Vector2(-13, 15), Vector2(-13, -10), Vector2(-4, -15), Vector2(6, -12), Vector2(13, -15), Vector2(13, 15)]), Color(col, 0.65))
			_hourglass(c, mid + Vector2(0, 1) * k, k * 0.6, Color(light, 0.8), WHITE)
		"frost_deep_strata":   # Deep Strata: five thick layers, the bottom one darkest
			for i in 5:
				c.draw_rect(Rect2(mid + Vector2(-14, -14 + i * 6) * k, Vector2(28, 5) * k), Color(col.darkened(0.12 * i), 0.85), true)
				c.draw_line(mid + Vector2(-14, -14 + i * 6) * k, mid + Vector2(14, -14 + i * 6) * k, light, 1.0 * k, true)
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
		# --- Frost, the column-group tree (2026-10-23) ---
		"frost_winter_coat":   # Winter Coat: a thick fur-lined coat, a spell spark glancing off it
			c.draw_colored_polygon(_p(mid, k, [Vector2(-10, -12), Vector2(10, -12), Vector2(14, 14), Vector2(-14, 14)]), Color(light, 0.7))
			c.draw_line(mid + Vector2(0, -12) * k, mid + Vector2(0, 14) * k, WHITE, 1.4 * k, true)
			_star(c, mid + Vector2(12, -12) * k, 4.0 * k, Color(0.8, 0.6, 1.0), 4)
		"frost_glass_cold":   # Glass Cold: a bolt striking a glassy frozen block
			_pane(c, mid + Vector2(5, 4) * k, Vector2(10, 12), Color(col, 0.5), WHITE, 1.6 * k)
			_shard(c, mid + Vector2(2, 0) * k, Vector2(0.7, 0.7), 14.0 * k, 3.5 * k, light, WHITE, k)
		"frost_ice_needles":   # Ice Needles: a crit star throwing off thin needles of ice
			_star(c, mid + Vector2(-5, 5) * k, 9.0 * k, WHITE, 4)
			for i in 3:
				_shard(c, mid + Vector2(6 + i * 4, -14 + i * 6) * k, Vector2(0.8, -0.6), 9.0 * k, 1.6 * k, light, WHITE, k)
		"frost_snowdrift":   # Snowdrift: a heap of snow with three small shapes caught in it
			c.draw_colored_polygon(_p(mid, k, [Vector2(-16, 14), Vector2(-8, 2), Vector2(2, 6), Vector2(10, -2), Vector2(16, 14)]), Color(WHITE, 0.85))
			for x in [-9.0, 0.0, 9.0]:
				c.draw_circle(mid + Vector2(x, -8) * k, 3.0 * k, Color(col, 0.8))
		"frost_cold_front":   # Cold Front: a wall of cold air sweeping over a row of snowflakes
			c.draw_arc(mid + Vector2(-20, 0) * k, 22.0 * k, -PI * 0.35, PI * 0.35, 12, light, 3.0 * k, true)
			for i in 3:
				_flake(c, mid + Vector2(2 + i * 6, -10 + i * 10) * k, 4.0 * k, WHITE, 1.4 * k)
		"frost_cold_well":   # Cold Well: a well of ice with a mana drop rising out of it
			c.draw_rect(Rect2(mid + Vector2(-12, 4) * k, Vector2(24, 11) * k), Color(col, 0.6), true)
			c.draw_rect(Rect2(mid + Vector2(-12, 4) * k, Vector2(24, 11) * k), WHITE, false, 1.4 * k)
			_drop(c, mid + Vector2(0, -6) * k, k * 0.6, Color(0.35, 0.55, 1.0), WHITE, k)
		"frost_thaw_water":   # Thaw Water: a melting shell dripping into a heal
			c.draw_arc(mid + Vector2(0, -4) * k, 11.0 * k, PI, TAU, 14, light, 2.4 * k, true)
			_drop(c, mid + Vector2(0, 6) * k, k * 0.55, Color(col, 0.8), WHITE, k)
			_plus(c, mid + Vector2(10, 10) * k, 4.0 * k, Color(0.45, 1.0, 0.45), 2.0 * k)
		"frost_last_shelter":   # Last Shelter: a shield over a low red health bar
			_shield(c, mid + Vector2(0, -3) * k, k * 0.75, Color(col, 0.5), WHITE)
			c.draw_rect(Rect2(mid + Vector2(-13, 11) * k, Vector2(26, 4) * k), Color(0.15, 0.1, 0.1), true)
			c.draw_rect(Rect2(mid + Vector2(-13, 11) * k, Vector2(9, 4) * k), Color(0.9, 0.25, 0.2), true)
		"frost_cold_hands":   # Cold Hands: an open hand with a small mana drop, half of it frosted
			c.draw_arc(mid + Vector2(0, 6) * k, 11.0 * k, 0, PI, 12, light, 3.0 * k, true)
			for x in [-8.0, -3.0, 2.0, 7.0]:
				c.draw_line(mid + Vector2(x, 6) * k, mid + Vector2(x * 1.15, -3) * k, light, 2.4 * k, true)
			_drop(c, mid + Vector2(0, -8) * k, k * 0.4, Color(0.35, 0.55, 1.0), WHITE, k)
		"frost_meltdown":   # Meltdown: a broken shell, a mana drop falling out of it
			c.draw_arc(mid + Vector2(-3, -2) * k, 12.0 * k, PI * 0.7, PI * 1.6, 10, light, 2.4 * k, true)
			c.draw_arc(mid + Vector2(3, -2) * k, 12.0 * k, PI * 1.75, PI * 2.4, 10, light, 2.4 * k, true)
			_drop(c, mid + Vector2(0, 4) * k, k * 0.6, Color(0.35, 0.55, 1.0), WHITE, k)
		"frost_long_frost":   # Long Frost: a shield with a long clock beside it
			_shield(c, mid + Vector2(-5, 0) * k, k * 0.75, Color(col, 0.5), WHITE)
			_clock(c, mid + Vector2(9, -8) * k, 6.0 * k, light, k)
			c.draw_line(mid + Vector2(9, -8) * k, mid + Vector2(9, -12) * k, WHITE, 1.4 * k, true)
		"frost_shard_reach":   # Shard Reach: shards flying out to a far ring
			c.draw_arc(mid, 15.0 * k, 0, TAU, 28, Color(light, 0.6), 1.4 * k, true)
			for i in 4:
				var a := TAU * i / 4.0 + PI / 4.0
				_shard(c, mid + Vector2(cos(a), sin(a)) * 14.0 * k, Vector2(cos(a), sin(a)), 8.0 * k, 2.0 * k, light, WHITE, k)
		"frost_snowmelt":   # Snowmelt: quick drops running off a melting ball of snow
			c.draw_circle(mid + Vector2(0, -6) * k, 8.0 * k, Color(WHITE, 0.85))
			for x in [-7.0, 0.0, 7.0]:
				_drop(c, mid + Vector2(x, 9) * k, k * 0.3, Color(col, 0.85), WHITE, k * 0.6)
			c.draw_line(mid + Vector2(12, -2) * k, mid + Vector2(16, 6) * k, light, 1.6 * k, true)
		"frost_layered_veil":   # Layered Veil: three thin veils, one forming again
			for i in 3:
				c.draw_arc(mid + Vector2(0, 8 - i * 6) * k, 12.0 * k, PI, TAU, 14, Color(light, 0.5 + i * 0.25), 2.0 * k, true)
			c.draw_line(mid + Vector2(12, -12) * k, mid + Vector2(15, -15) * k, WHITE, 1.6 * k, true)
		"frost_ice_bath":   # Ice Bath: a tub of icy water with a heal rising out of it
			c.draw_colored_polygon(_p(mid, k, [Vector2(-14, 2), Vector2(14, 2), Vector2(10, 14), Vector2(-10, 14)]), Color(col, 0.65))
			c.draw_line(mid + Vector2(-14, 2) * k, mid + Vector2(14, 2) * k, WHITE, 1.6 * k, true)
			_plus(c, mid + Vector2(0, -8) * k, 5.0 * k, Color(0.45, 1.0, 0.45), 2.4 * k)
		"frost_deep_snow":   # Deep Snow: snow falling onto a thick shield
			_shield(c, mid + Vector2(0, 4) * k, k * 0.7, Color(col, 0.6), WHITE)
			for p in [Vector2(-10, -12), Vector2(0, -15), Vector2(10, -12)]:
				_flake(c, mid + (p as Vector2) * k, 3.0 * k, WHITE, 1.2 * k)
		"frost_cold_rush":   # Cold Rush: a heal plus with speed lines over a low health bar
			_plus(c, mid + Vector2(3, -4) * k, 7.0 * k, Color(0.45, 1.0, 0.45), 3.0 * k)
			for y in [-8.0, -4.0, 0.0]:
				c.draw_line(mid + Vector2(-16, y) * k, mid + Vector2(-8, y) * k, light, 1.4 * k, true)
			c.draw_rect(Rect2(mid + Vector2(-12, 11) * k, Vector2(7, 4) * k), Color(0.9, 0.25, 0.2), true)
		"frost_close_weave":   # Close Weave: three shells tied by a tight weave, a heal in the middle
			for p in [Vector2(-10, -8), Vector2(10, -8), Vector2(0, 10)]:
				c.draw_arc(mid + (p as Vector2) * k, 5.0 * k, 0, TAU, 12, light, 1.8 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(-10, -8), Vector2(10, -8), Vector2(0, 10), Vector2(-10, -8)]), Color(WHITE, 0.6), 1.2 * k, true)
			_plus(c, mid, 3.0 * k, Color(0.45, 1.0, 0.45), 1.8 * k)
		"frost_frozen_hearth":   # Frozen Hearth: a hearth with a cold blue fire, a shield over it
			c.draw_rect(Rect2(mid + Vector2(-14, 4) * k, Vector2(28, 11) * k), Color(0.3, 0.32, 0.38), true)
			_fire(c, mid + Vector2(0, 3) * k, k * 0.6, light, WHITE)
			c.draw_arc(mid + Vector2(0, 2) * k, 15.0 * k, PI * 1.05, PI * 1.95, 14, WHITE, 2.0 * k, true)
		"frost_sharp_glaze":   # Sharp Glaze: a blade edge, three glints of rime along it
			c.draw_line(mid + Vector2(-14, 14) * k, mid + Vector2(14, -14) * k, Color(0.8, 0.88, 1.0), 4.0 * k, true)
			for i in 3:
				_star(c, mid + Vector2(-6 + i * 7, 6 - i * 7) * k, 3.5 * k, WHITE, 4)
		"frost_glaze_hunger":   # Glaze Hunger: a glint splitting into two
			_star(c, mid + Vector2(-5, 3) * k, 8.0 * k, WHITE, 4)
			_star(c, mid + Vector2(8, -8) * k, 5.0 * k, light, 4)
			_plus(c, mid + Vector2(10, 9) * k, 3.5 * k, light, 1.8 * k)
		"frost_hard_glaze":   # Hard Glaze: glints poured into a drop of fury
			for i in 3:
				_star(c, mid + Vector2(-10 + i * 6, -10) * k, 3.0 * k, WHITE, 4)
			_drop(c, mid + Vector2(4, 5) * k, k * 0.6, Color(0.9, 0.3, 0.2), WHITE, k)
		"frost_splitting_cold":   # Splitting Cold: a heavy blade splitting a frozen block
			_pane(c, mid + Vector2(0, 5) * k, Vector2(12, 10), Color(col, 0.55), WHITE, 1.4 * k)
			c.draw_line(mid + Vector2(0, -16) * k, mid + Vector2(0, 14) * k, Color(0.85, 0.9, 1.0), 3.0 * k, true)
		"frost_shiver":   # Shiver: a frozen shape trembling, a glint shaken off it
			for x in [-2.0, 2.0]:
				c.draw_rect(Rect2(mid + Vector2(-9 + x, -6) * k, Vector2(14, 20) * k), Color(col, 0.35), false, 1.4 * k)
			_star(c, mid + Vector2(10, -11) * k, 5.0 * k, WHITE, 4)
		"frost_rime_grip":   # Rime Grip: a fist on a hilt, rime on the knuckles, a drop of fury
			c.draw_circle(mid + Vector2(-3, 2) * k, 8.0 * k, light)
			for x in [-8.0, -3.0, 2.0]:
				c.draw_circle(mid + Vector2(x, -5) * k, 2.2 * k, WHITE)
			_drop(c, mid + Vector2(10, -6) * k, k * 0.35, Color(0.9, 0.3, 0.2), WHITE, k * 0.7)
		"frost_cold_swing":   # Cold Swing: a wide arc through two shapes
			c.draw_arc(mid + Vector2(0, 10) * k, 16.0 * k, PI * 1.1, PI * 1.9, 16, WHITE, 3.0 * k, true)
			for x in [-8.0, 8.0]:
				c.draw_circle(mid + Vector2(x, 0) * k, 4.0 * k, Color(col, 0.75))
		"frost_thaw_strike":   # Thaw Strike: a melting block and a cheap, quick blade
			c.draw_rect(Rect2(mid + Vector2(-14, -2) * k, Vector2(12, 14) * k), Color(col, 0.5), true)
			_drop(c, mid + Vector2(-8, 12) * k, k * 0.25, Color(col, 0.9), WHITE, k * 0.6)
			c.draw_line(mid + Vector2(2, 12) * k, mid + Vector2(14, -12) * k, Color(0.85, 0.9, 1.0), 3.0 * k, true)
		"frost_quick_rime":   # Quick Rime: a blade with rime and fast swing lines
			c.draw_line(mid + Vector2(-10, 12) * k, mid + Vector2(10, -12) * k, Color(0.85, 0.9, 1.0), 3.5 * k, true)
			for i in 3:
				c.draw_arc(mid + Vector2(-2, 0) * k, (8.0 + i * 4.0) * k, -PI * 0.1, PI * 0.35, 6, Color(light, 0.8 - i * 0.2), 1.4 * k, true)
		"frost_frost_heave":   # Frost Heave: the ground heaving up into an ice block under a blade
			c.draw_colored_polygon(_p(mid, k, [Vector2(-16, 15), Vector2(-6, 2), Vector2(6, 2), Vector2(16, 15)]), Color(col, 0.6))
			_star(c, mid + Vector2(0, -8) * k, 7.0 * k, WHITE, 5)
		"frost_lasting_ice":   # Lasting Ice: stacked layers with an hourglass
			for i in 3:
				c.draw_rect(Rect2(mid + Vector2(-15, 8 - i * 6) * k, Vector2(18, 4) * k), Color(col, 0.5 + i * 0.15), true)
			_hourglass(c, mid + Vector2(10, 0) * k, k * 0.55, light, WHITE)
		"frost_deep_ice":   # Deep Ice: a tall stack of layers, the top ones new
			for i in 7:
				c.draw_rect(Rect2(mid + Vector2(-10, 13 - i * 4) * k, Vector2(20, 3) * k), Color(col, 0.4 + i * 0.08) if i < 5 else WHITE, true)
		"frost_spent_ice":   # Spent Ice: layers driven into a target, fury flying out
			for i in 3:
				c.draw_rect(Rect2(mid + Vector2(-15 + i * 5, -6) * k, Vector2(3, 12) * k), Color(col, 0.6 + i * 0.1), true)
			c.draw_circle(mid + Vector2(8, 0) * k, 6.0 * k, Color(light, 0.5))
			_drop(c, mid + Vector2(12, -10) * k, k * 0.3, Color(0.9, 0.3, 0.2), WHITE, k * 0.6)
		"frost_hoar_coat":   # Hoar Coat: a coat of frost layers with a heal on it
			c.draw_colored_polygon(_p(mid, k, [Vector2(-10, -12), Vector2(10, -12), Vector2(14, 14), Vector2(-14, 14)]), Color(col, 0.55))
			for y in [-4.0, 4.0]:
				c.draw_line(mid + Vector2(-12, y) * k, mid + Vector2(12, y) * k, WHITE, 1.2 * k, true)
			_plus(c, mid + Vector2(0, -2) * k, 4.0 * k, Color(0.45, 1.0, 0.45), 2.2 * k)
		"frost_cold_retort":   # Cold Retort: a cracked layer firing a shard back at a red glare
			c.draw_rect(Rect2(mid + Vector2(-15, -10) * k, Vector2(6, 20) * k), Color(col, 0.6), true)
			c.draw_line(mid + Vector2(-13, -4) * k, mid + Vector2(-10, 4) * k, WHITE, 1.2 * k, true)
			_shard(c, mid + Vector2(10, 0) * k, Vector2(1, 0), 14.0 * k, 3.0 * k, light, WHITE, k)
			c.draw_circle(mid + Vector2(13, -10) * k, 2.5 * k, Color(1.0, 0.35, 0.25))
		"frost_rime_pressure":   # Rime Pressure: layers under a glaring eye
			for i in 3:
				c.draw_rect(Rect2(mid + Vector2(-12, 12 - i * 5) * k, Vector2(24, 3) * k), Color(col, 0.6), true)
			c.draw_arc(mid + Vector2(0, -6) * k, 8.0 * k, PI * 1.1, PI * 1.9, 10, WHITE, 2.0 * k, true)
			c.draw_arc(mid + Vector2(0, -12) * k, 8.0 * k, PI * 0.1, PI * 0.9, 10, WHITE, 2.0 * k, true)
			c.draw_circle(mid + Vector2(0, -9) * k, 2.4 * k, Color(1.0, 0.35, 0.25))
		"frost_reforming":   # Reforming: a broken layer snapping back with a circling arrow
			c.draw_rect(Rect2(mid + Vector2(-9, -2) * k, Vector2(18, 5) * k), Color(col, 0.7), true)
			c.draw_arc(mid, 13.0 * k, PI * 0.2, PI * 1.7, 18, WHITE, 2.0 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(10, 9), Vector2(14, 4), Vector2(15, 11)]), WHITE)
		"frost_cracking_ice":   # Cracking Ice: a cracking layer and a clock running fast
			c.draw_rect(Rect2(mid + Vector2(-15, 4) * k, Vector2(18, 6) * k), Color(col, 0.7), true)
			c.draw_polyline(_p(mid, k, [Vector2(-10, 4), Vector2(-7, 7), Vector2(-9, 10)]), WHITE, 1.2 * k, true)
			_clock(c, mid + Vector2(8, -6) * k, 7.0 * k, light, k)
			c.draw_line(mid + Vector2(8, -6) * k, mid + Vector2(12, -10) * k, WHITE, 1.6 * k, true)
		"frost_steady_footing":   # Steady Footing: two boots planted on three layers
			for i in 3:
				c.draw_rect(Rect2(mid + Vector2(-14, 14 - i * 4) * k, Vector2(28, 3) * k), Color(col, 0.6), true)
			for x in [-6.0, 6.0]:
				c.draw_rect(Rect2(mid + Vector2(x - 3, -10) * k, Vector2(6, 12) * k), light, true)
		"frost_rime_armor":   # Rime Armor: a breastplate made of ice bricks
			c.draw_colored_polygon(_p(mid, k, [Vector2(-12, -12), Vector2(12, -12), Vector2(10, 12), Vector2(0, 15), Vector2(-10, 12)]), Color(col, 0.55))
			for y in [-5.0, 2.0, 9.0]:
				c.draw_line(mid + Vector2(-11, y) * k, mid + Vector2(11, y) * k, WHITE, 1.2 * k, true)
		"frost_full_strata":   # Full Strata: five full layers, a blade over them
			for i in 5:
				c.draw_rect(Rect2(mid + Vector2(-12, 13 - i * 4) * k, Vector2(24, 3) * k), Color(col, 0.5 + i * 0.1), true)
			c.draw_line(mid + Vector2(-12, -14) * k, mid + Vector2(12, -6) * k, WHITE, 3.0 * k, true)
		"frost_frozen_quarry":   # Frozen Quarry: an arrow into a frozen block
			_pane(c, mid + Vector2(6, -6) * k, Vector2(9, 10), Color(col, 0.55), WHITE, 1.4 * k)
			_arrow_line(c, mid, k * 0.8, Color(0.75, 0.6, 0.4), light)
		"frost_frost_fletching":   # Frost Fletching: frosted feathers on an arrow
			_arrow_line(c, mid, k, Color(0.75, 0.6, 0.4), WHITE)
			_flake(c, mid + Vector2(-12, 10) * k, 5.0 * k, light, 1.4 * k)
		"frost_rime_tips":   # Rime Tips: an arrowhead coated in rime
			c.draw_colored_polygon(_p(mid, k, [Vector2(0, -16), Vector2(9, 2), Vector2(-9, 2)]), light)
			c.draw_line(mid + Vector2(0, 2) * k, mid + Vector2(0, 16) * k, Color(0.75, 0.6, 0.4), 2.5 * k, true)
			_flake(c, mid + Vector2(0, -6) * k, 4.0 * k, WHITE, 1.2 * k)
		"frost_marked_ice":   # Marked Ice: an arrow into a chilled target, a shard coming out
			c.draw_circle(mid + Vector2(5, -5) * k, 9.0 * k, Color(col, 0.4))
			_arrow_line(c, mid, k * 0.75, Color(0.75, 0.6, 0.4), light)
			_shard(c, mid + Vector2(15, -15) * k, Vector2(0.7, -0.7), 7.0 * k, 2.0 * k, WHITE, light, k)
		"frost_winter_quiver":   # Winter Quiver: a quiver of icy arrows, an Energy spark
			c.draw_rect(Rect2(mid + Vector2(-8, -4) * k, Vector2(12, 18) * k), Color(0.45, 0.35, 0.25), true)
			for x in [-5.0, -1.0, 3.0]:
				c.draw_line(mid + Vector2(x, -4) * k, mid + Vector2(x, -15) * k, light, 2.0 * k, true)
			_star(c, mid + Vector2(11, -6) * k, 5.0 * k, Color(1.0, 0.9, 0.4), 4)
		"frost_splitting_arrow":   # Splitting Arrow: an arrow hitting ice and splitting off a shard
			_pane(c, mid + Vector2(-2, 2) * k, Vector2(8, 10), Color(col, 0.55), WHITE, 1.4 * k)
			c.draw_line(mid + Vector2(-16, 2) * k, mid + Vector2(-6, 2) * k, Color(0.75, 0.6, 0.4), 2.4 * k, true)
			_shard(c, mid + Vector2(15, -10) * k, Vector2(0.8, -0.6), 9.0 * k, 2.2 * k, light, WHITE, k)
		"frost_deep_pin":   # Deep Pin: an arrow pinned deep in the ground, a long clock
			c.draw_line(mid + Vector2(-16, 10) * k, mid + Vector2(16, 10) * k, light, 2.0 * k, true)
			c.draw_line(mid + Vector2(-4, -14) * k, mid + Vector2(-4, 14) * k, Color(0.75, 0.6, 0.4), 2.5 * k, true)
			_clock(c, mid + Vector2(8, -6) * k, 6.0 * k, WHITE, k)
		"frost_numb_prey":   # Numb Prey: a frozen shape struck by small auto-shots
			_figure(c, mid + Vector2(4, 0) * k, 14.0 * k, light, 2.0 * k)
			c.draw_rect(Rect2(mid + Vector2(-6, -14) * k, Vector2(20, 28) * k), Color(col, 0.35), true)
			for y in [-6.0, 4.0]:
				c.draw_line(mid + Vector2(-16, y) * k, mid + Vector2(-8, y) * k, WHITE, 1.6 * k, true)
		"frost_swift_ice":   # Swift Ice: an arrow with speed lines over a snowflake
			_flake(c, mid + Vector2(6, 6) * k, 7.0 * k, Color(light, 0.7), 1.6 * k)
			for y in [-10.0, -5.0, 0.0]:
				c.draw_line(mid + Vector2(-16, y) * k, mid + Vector2(14 - absf(y), y) * k, WHITE, 1.4 * k, true)
		"frost_ice_hunger":   # Ice Hunger: a frozen block with Energy pips drawn out of it
			_pane(c, mid + Vector2(-4, 2) * k, Vector2(10, 12), Color(col, 0.55), WHITE, 1.4 * k)
			for i in 3:
				c.draw_circle(mid + Vector2(10, -10 + i * 7) * k, 2.4 * k, Color(1.0, 0.9, 0.4))
		"frost_cold_eye":   # Cold Eye: a pale eye with a crit star in it
			c.draw_arc(mid + Vector2(0, 8) * k, 14.0 * k, PI * 1.15, PI * 1.85, 12, WHITE, 2.0 * k, true)
			c.draw_arc(mid + Vector2(0, -8) * k, 14.0 * k, PI * 0.15, PI * 0.85, 12, WHITE, 2.0 * k, true)
			_star(c, mid, 5.0 * k, light, 4)
		"frost_sleet_arrows":   # Sleet Arrows: one arrow and sleet spraying out to two more shapes
			_arrow_line(c, mid, k * 0.7, Color(0.75, 0.6, 0.4), light)
			for p in [Vector2(14, 0), Vector2(0, -14)]:
				c.draw_circle(mid + (p as Vector2) * k, 3.5 * k, Color(col, 0.6))
				_flake(c, mid + (p as Vector2) * k, 3.0 * k, WHITE, 1.0 * k)
		"frost_bitter_hunt":   # Bitter Hunt: a target ringed by frost, a root and an arrow
			c.draw_arc(mid, 13.0 * k, 0, TAU, 24, light, 2.0 * k, true)
			c.draw_arc(mid, 8.0 * k, 0, TAU, 20, WHITE, 1.6 * k, true)
			c.draw_line(mid + Vector2(-6, 14) * k, mid + Vector2(-3, 8) * k, Color(0.45, 0.35, 0.25), 2.0 * k, true)
			_arrow_line(c, mid, k * 0.6, Color(0.75, 0.6, 0.4), WHITE)
		"frost_deep_freeze":   # Deep Freeze: a body frozen in an ice block
			c.draw_colored_polygon(_p(mid, k, [Vector2(-12, -9), Vector2(-5, -15), Vector2(13, -15), Vector2(13, 8),
				Vector2(6, 15), Vector2(-12, 15)]), Color(col, 0.55))
			c.draw_polyline(_p(mid, k, [Vector2(-12, -9), Vector2(6, -9), Vector2(6, 15)]), WHITE, 1.4 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(6, -9), Vector2(13, -15)]), WHITE, 1.4 * k, true)
			c.draw_circle(mid + Vector2(-3, -2) * k, 3.0 * k, Color(0.15, 0.25, 0.4))
			c.draw_line(mid + Vector2(-3, 1) * k, mid + Vector2(-3, 9) * k, Color(0.15, 0.25, 0.4), 2.5 * k, true)
			c.draw_line(mid + Vector2(-8, 4) * k, mid + Vector2(2, 4) * k, Color(0.15, 0.25, 0.4), 2.0 * k, true)
		# --- Martial warrior: the Wheel ---
		"martial_hard_break":   # a blade snapping in two, shards flying
			c.draw_colored_polygon(_p(mid, k, [Vector2(-15, 12), Vector2(-11, 15), Vector2(-1, 3), Vector2(-4, 0)]), WHITE)
			c.draw_colored_polygon(_p(mid, k, [Vector2(2, -2), Vector2(5, 1), Vector2(15, -11), Vector2(13, -15)]), WHITE)
			for p in [Vector2(-3, -9), Vector2(6, 9), Vector2(10, 2)]:
				_shard(c, mid + (p as Vector2) * k, (p as Vector2).normalized(), 6.0 * k, 2.0 * k, light, WHITE, k)
		"martial_well_drilled":   # a weapon held level, three cracks along it
			c.draw_line(mid + Vector2(-15, 4) * k, mid + Vector2(15, -4) * k, WHITE, 5.0 * k, true)
			for x in [-7.0, 0.0, 7.0]:
				c.draw_polyline(_p(mid, k, [Vector2(x, -4 - x * 0.27), Vector2(x + 2, 0 - x * 0.27), Vector2(x - 1, 4 - x * 0.27)]), col.darkened(0.3), 1.6 * k, true)
			c.draw_line(mid + Vector2(-10, 12) * k, mid + Vector2(10, 12) * k, light, 2.0 * k, true)
		"martial_wide_cleave":   # an axe head, its swing reaching two marks beside it
			c.draw_colored_polygon(_p(mid, k, [Vector2(-4, -12), Vector2(8, -15), Vector2(10, 0), Vector2(-4, -3)]), WHITE)
			c.draw_line(mid + Vector2(-4, -12) * k, mid + Vector2(-4, 15) * k, WOOD.lightened(0.2), 3.0 * k, true)
			c.draw_arc(mid + Vector2(-4, -4) * k, 16.0 * k, -PI * 0.35, PI * 0.35, 12, light, 2.0 * k, true)
			for p in [Vector2(14, -8), Vector2(15, 2), Vector2(12, 11)]:
				c.draw_circle(mid + (p as Vector2) * k, 2.4 * k, light)
		"martial_keen_edge":   # a greatsword point, a star of light on its edge
			c.draw_colored_polygon(_p(mid, k, [Vector2(-3, 15), Vector2(3, 15), Vector2(3, -9), Vector2(0, -15), Vector2(-3, -9)]), Color(0.78, 0.9, 1.0))
			c.draw_line(mid + Vector2(-9, 9) * k, mid + Vector2(9, 9) * k, WHITE, 3.0 * k, true)
			for i in 4:
				var a := TAU * i / 4.0 + PI * 0.25
				c.draw_line(mid + Vector2(8, -8) * k, mid + Vector2(8, -8) * k + Vector2(cos(a), sin(a)) * 6.0 * k, WHITE, 1.8 * k, true)
		"martial_twice_over":   # a halberd blade and its echo behind it
			for off in [Vector2(-5, 3), Vector2(3, -3)]:
				var o := off as Vector2
				var a := 0.45 if o.x < 0 else 1.0
				c.draw_line(mid + (Vector2(-10, 14) + o) * k, mid + (Vector2(8, -12) + o) * k, Color(WOOD.lightened(0.3), a), 2.4 * k, true)
				c.draw_colored_polygon(_p(mid + o * k, k, [Vector2(4, -10), Vector2(13, -8), Vector2(10, 0), Vector2(6, -4)]), Color(0.5, 0.95, 0.6, a))
		"martial_rattled":   # a maul head, a dizzy ring of stars
			c.draw_rect(Rect2(mid + Vector2(-10, -2) * k, Vector2(20, 11) * k), Color(1.0, 0.75, 0.3))
			c.draw_line(mid + Vector2(0, 9) * k, mid + Vector2(0, 16) * k, WOOD.lightened(0.2), 3.0 * k, true)
			c.draw_arc(mid + Vector2(0, -9) * k, 9.0 * k, PI, TAU, 12, light, 1.6 * k, true)
			for x in [-8.0, 0.0, 8.0]:
				_plus(c, mid + Vector2(x, -12 + absf(x) * 0.4) * k, 2.4 * k, WHITE, 1.5 * k)
		"martial_turning_wheel":   # four weapons around a turning circle
			c.draw_arc(mid, 11.0 * k, 0, TAU, 24, light, 2.0 * k, true)
			var tones := [Color(1.0, 0.4, 0.35), Color(0.78, 0.9, 1.0), Color(0.5, 0.95, 0.6), Color(1.0, 0.75, 0.3)]
			for i in 4:
				var a := TAU * i / 4.0 - PI * 0.5
				var at := mid + Vector2(cos(a), sin(a)) * 11.0 * k
				c.draw_circle(at, 4.2 * k, tones[i])
			c.draw_colored_polygon(_p(mid, k, [Vector2(4, -15), Vector2(9, -12), Vector2(3, -10)]), WHITE)
		# --- Martial DPS: the Rogue ---
		"martial_clean_kill":   # a dagger through a red slash
			c.draw_line(mid + Vector2(-14, 12) * k, mid + Vector2(14, -12) * k, Color(0.95, 0.25, 0.3), 4.0 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-2, -15), Vector2(2, -15), Vector2(2, 5), Vector2(0, 9), Vector2(-2, 5)]), WHITE)
			c.draw_line(mid + Vector2(-6, 9) * k, mid + Vector2(6, 9) * k, WOOD.lightened(0.3), 2.6 * k, true)
			c.draw_line(mid + Vector2(0, 9) * k, mid + Vector2(0, 15) * k, WOOD, 3.0 * k, true)
		"martial_in_and_out":   # two arrows, one in, one out
			c.draw_line(mid + Vector2(-14, -6) * k, mid + Vector2(8, -6) * k, WHITE, 2.4 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(8, -11), Vector2(15, -6), Vector2(8, -1)]), WHITE)
			c.draw_line(mid + Vector2(14, 7) * k, mid + Vector2(-8, 7) * k, light, 2.4 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-8, 2), Vector2(-15, 7), Vector2(-8, 12)]), light)
		"martial_barbed":   # a barbed dagger blade
			c.draw_colored_polygon(_p(mid, k, [Vector2(-3, 14), Vector2(3, 14), Vector2(3, -8), Vector2(0, -15), Vector2(-3, -8)]), WHITE)
			for y in [-6.0, 0.0, 6.0]:
				c.draw_colored_polygon(_p(mid, k, [Vector2(-3, y), Vector2(-9, y + 5), Vector2(-3, y + 3)]), light)
				c.draw_colored_polygon(_p(mid, k, [Vector2(3, y), Vector2(9, y + 5), Vector2(3, y + 3)]), light)
		"martial_steady_pace":   # a ring of Flow, an hourglass inside
			c.draw_arc(mid, 15.0 * k, 0, TAU, 28, Color(0.55, 0.85, 1.0), 2.2 * k, true)
			_hourglass(c, mid + Vector2(0, -1) * k, 0.75 * k, light, WHITE)
		"martial_mix_it_up":   # three different blade marks, side by side
			c.draw_line(mid + Vector2(-14, 10) * k, mid + Vector2(-8, -10) * k, Color(0.95, 0.25, 0.3), 3.0 * k, true)
			c.draw_arc(mid + Vector2(0, 2) * k, 7.0 * k, PI * 1.1, PI * 1.9, 10, WHITE, 3.0 * k, true)
			c.draw_line(mid + Vector2(8, -10) * k, mid + Vector2(14, 10) * k, light, 3.0 * k, true)
			c.draw_line(mid + Vector2(-12, 14) * k, mid + Vector2(12, 14) * k, Color(WHITE, 0.5), 1.4 * k, true)
		"martial_deep_pockets":   # a pouch with a hand slipping in
			c.draw_colored_polygon(_p(mid, k, [Vector2(-11, -4), Vector2(11, -4), Vector2(13, 10), Vector2(0, 15), Vector2(-13, 10)]), WOOD.lightened(0.15))
			c.draw_line(mid + Vector2(-11, -4) * k, mid + Vector2(11, -4) * k, light, 2.4 * k, true)
			c.draw_line(mid + Vector2(4, -15) * k, mid + Vector2(1, -4) * k, Color(0.95, 0.78, 0.62), 4.0 * k, true)
			c.draw_circle(mid + Vector2(-4, 6) * k, 2.4 * k, Color(1.0, 0.85, 0.3))
		"martial_in_the_zone":   # an eye with a red ring round it
			c.draw_arc(mid, 15.0 * k, 0, TAU, 28, Color(0.95, 0.25, 0.3), 2.2 * k, true)
			_ellipse(c, mid, Vector2(10, 5) * k, Color(WHITE, 0.9), light, 1.4 * k)
			c.draw_circle(mid, 3.5 * k, col.darkened(0.6))
		# --- Martial: the open talents ---
		"martial_conditioning":   # a dumbbell over a heart line
			c.draw_line(mid + Vector2(-10, -6) * k, mid + Vector2(10, -6) * k, WHITE, 3.0 * k, true)
			for x in [-12.0, 12.0]:
				c.draw_rect(Rect2(mid + Vector2(x - 2.5, -12) * k, Vector2(5, 12) * k), light)
			c.draw_polyline(_p(mid, k, [Vector2(-15, 9), Vector2(-5, 9), Vector2(-2, 3), Vector2(2, 15), Vector2(5, 9), Vector2(15, 9)]), HEAL_GREEN, 2.0 * k, true)
		"martial_catch_your_breath":   # breath curling out, a green plus
			for i in 3:
				c.draw_arc(mid + Vector2(-6 + i * 5, -2 + i * 2) * k, (5.0 + i * 2.0) * k, PI * 1.2, PI * 1.9, 10, Color(WHITE, 0.9 - i * 0.2), 2.0 * k, true)
			_plus(c, mid + Vector2(8, 9) * k, 5.0 * k, HEAL_GREEN, 3.0 * k)
		"martial_pinned_down":   # a knife through a shadow on the floor
			_ellipse(c, mid + Vector2(0, 9) * k, Vector2(14, 5) * k, Color(0.08, 0.06, 0.1), light, 1.4 * k)
			c.draw_line(mid + Vector2(-5, -15) * k, mid + Vector2(1, 8) * k, WHITE, 3.0 * k, true)
			c.draw_line(mid + Vector2(-9, -9) * k, mid + Vector2(0, -12) * k, WOOD.lightened(0.3), 2.6 * k, true)
			for x in [-8.0, 8.0]:
				c.draw_circle(mid + Vector2(x, 9) * k, 1.6 * k, WHITE)
		# --- Martial tank: the Brawler ---
		"martial_soak_it_up":   # a fist meeting a purple bruise that spreads it out
			c.draw_circle(mid + Vector2(3, 3) * k, 12.0 * k, Color(0.6, 0.35, 0.7, 0.75))
			c.draw_circle(mid + Vector2(3, 3) * k, 6.0 * k, Color(0.75, 0.5, 0.85))
			c.draw_rect(Rect2(mid + Vector2(-15, -13) * k, Vector2(11, 10) * k), Color(0.95, 0.78, 0.62))
			c.draw_rect(Rect2(mid + Vector2(-15, -13) * k, Vector2(11, 10) * k), WHITE, false, 1.4 * k)
		"martial_tight_clinch":   # two arms locked around each other
			c.draw_arc(mid + Vector2(-4, 0) * k, 10.0 * k, -PI * 0.4, PI * 0.9, 14, Color(0.95, 0.78, 0.62), 4.0 * k, true)
			c.draw_arc(mid + Vector2(4, 0) * k, 10.0 * k, PI * 0.6, PI * 1.9, 14, light, 4.0 * k, true)
		"martial_soft_catch":   # an open hand, a hit landing softly in it
			c.draw_arc(mid + Vector2(0, 2) * k, 11.0 * k, 0, PI, 14, Color(0.95, 0.78, 0.62), 4.0 * k, true)
			c.draw_circle(mid + Vector2(0, 0) * k, 4.5 * k, WHITE)
			c.draw_circle(mid + Vector2(0, 12) * k, 3.0 * k, Color(0.6, 0.35, 0.7))
			c.draw_line(mid + Vector2(0, -15) * k, mid + Vector2(0, -7) * k, Color(WHITE, 0.6), 1.6 * k, true)
		"martial_knockout":   # a big fist, gold stars over it
			c.draw_rect(Rect2(mid + Vector2(-10, -4) * k, Vector2(20, 16) * k), Color(0.95, 0.78, 0.62))
			for x in [-5.0, 0.0, 5.0]:
				c.draw_line(mid + Vector2(x, -4) * k, mid + Vector2(x, 2) * k, Color(0.6, 0.45, 0.35), 1.3 * k, true)
			for x in [-10.0, 0.0, 10.0]:
				_plus(c, mid + Vector2(x, -12) * k, 3.0 * k, Color(1.0, 0.85, 0.3), 2.0 * k)
		"martial_wide_stance":   # two feet set wide, a sweep between them
			for x in [-11.0, 11.0]:
				c.draw_rect(Rect2(mid + Vector2(x - 3, -4) * k, Vector2(6, 16) * k), WHITE.darkened(0.2))
			c.draw_arc(mid + Vector2(0, 4) * k, 15.0 * k, PI * 1.15, PI * 1.85, 14, Color(0.5, 0.95, 0.6), 2.4 * k, true)
			c.draw_line(mid + Vector2(-15, 13) * k, mid + Vector2(15, 13) * k, light, 1.6 * k, true)
		"martial_round_two":   # a bell and a "2"
			c.draw_arc(mid + Vector2(-4, 2) * k, 10.0 * k, PI, TAU, 14, Color(1.0, 0.85, 0.3), 3.0 * k, true)
			c.draw_line(mid + Vector2(-15, 2) * k, mid + Vector2(7, 2) * k, Color(1.0, 0.85, 0.3), 3.0 * k, true)
			c.draw_circle(mid + Vector2(-4, 6) * k, 2.5 * k, WHITE)
			c.draw_polyline(_p(mid, k, [Vector2(7, -1), Vector2(10, -4), Vector2(14, -1), Vector2(8, 13), Vector2(15, 13)]), WHITE, 2.2 * k, true)
		"martial_scar_tissue":   # a shoulder plate with stitched scars
			_shield(c, mid, k, Color(col, 0.6), light)
			for y in [-5.0, 4.0]:
				c.draw_line(mid + Vector2(-7, y) * k, mid + Vector2(7, y + 2) * k, WHITE, 1.6 * k, true)
				for x in [-4.0, 0.0, 4.0]:
					c.draw_line(mid + Vector2(x, y - 2) * k, mid + Vector2(x, y + 3) * k, WHITE, 1.1 * k, true)
		# --- Martial archer: Sharpshooter ---
		"martial_full_draw":   # a bow drawn all the way back
			c.draw_arc(mid + Vector2(6, 0) * k, 15.0 * k, PI * 0.6, PI * 1.4, 16, WOOD.lightened(0.3), 3.0 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(0, -14), Vector2(-12, 0), Vector2(0, 14)]), WHITE, 1.4 * k, true)
			c.draw_line(mid + Vector2(-12, 0) * k, mid + Vector2(15, 0) * k, Color(1.0, 0.85, 0.3), 2.0 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(15, -3), Vector2(18, 0), Vector2(15, 3)]), Color(1.0, 0.85, 0.3))
		"martial_broadhead":   # a wide arrowhead
			c.draw_colored_polygon(_p(mid, k, [Vector2(0, -15), Vector2(13, 2), Vector2(4, 0), Vector2(-4, 0), Vector2(-13, 2)]), WHITE)
			c.draw_line(mid + Vector2(0, 0) * k, mid + Vector2(0, 15) * k, WOOD.lightened(0.3), 3.0 * k, true)
		"martial_patience":   # an arrow resting over a clock
			_clock(c, mid + Vector2(0, 3) * k, 11.0 * k, light, k)
			c.draw_line(mid + Vector2(0, 3) * k, mid + Vector2(0, -4) * k, WHITE, 1.8 * k, true)
			c.draw_line(mid + Vector2(-15, -12) * k, mid + Vector2(13, -12) * k, Color(1.0, 0.85, 0.3), 2.2 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(13, -15), Vector2(17, -12), Vector2(13, -9)]), Color(1.0, 0.85, 0.3))
		"martial_extra_arrows":   # five arrows fanned out
			for i in 5:
				var a := -PI * 0.5 + (i - 2) * 0.32
				var d := Vector2(cos(a), sin(a))
				c.draw_line(mid + Vector2(0, 14) * k, mid + Vector2(0, 14) * k + d * 26.0 * k, WHITE if i == 2 else light, 1.8 * k, true)
		"martial_no_letup":   # a quiver of lit fletchings
			c.draw_rect(Rect2(mid + Vector2(-7, -2) * k, Vector2(14, 17) * k), WOOD)
			for x in [-4.0, 0.0, 4.0]:
				c.draw_line(mid + Vector2(x, -2) * k, mid + Vector2(x, -12) * k, WHITE, 1.4 * k, true)
				c.draw_circle(mid + Vector2(x, -13) * k, 2.4 * k, Color(1.0, 0.85, 0.3))
		"martial_easy_release":   # fingers letting the string go gently
			c.draw_line(mid + Vector2(8, -15) * k, mid + Vector2(8, 15) * k, WHITE, 1.4 * k, true)
			c.draw_arc(mid + Vector2(-2, 0) * k, 6.0 * k, -PI * 0.5, PI * 0.5, 10, Color(0.95, 0.78, 0.62), 3.4 * k, true)
			for i in 3:
				c.draw_arc(mid + Vector2(8, 0) * k, (4.0 + i * 3.5) * k, -PI * 0.3, PI * 0.3, 6, Color(light, 0.8 - i * 0.2), 1.4 * k, true)
		"martial_keen_eye":   # an eye on a target
			c.draw_arc(mid, 15.0 * k, 0, TAU, 28, light, 1.6 * k, true)
			c.draw_arc(mid, 9.0 * k, 0, TAU, 24, light, 1.6 * k, true)
			_ellipse(c, mid, Vector2(8, 4) * k, WHITE, WHITE, 1.0 * k)
			c.draw_circle(mid, 2.6 * k, Color(1.0, 0.85, 0.3))
		# --- Martial: the column-group talents (2026-10-22) ---
		# The Wheel.
		"martial_iron_grip":   # a fist closed round a haft, a red Fury drop
			c.draw_line(mid + Vector2(0, -15) * k, mid + Vector2(0, 15) * k, WOOD.lightened(0.2), 4.0 * k, true)
			c.draw_rect(Rect2(mid + Vector2(-7, -5) * k, Vector2(14, 10) * k), WHITE)
			for y in [-2.5, 0.0, 2.5]:
				c.draw_line(mid + Vector2(-7, y) * k, mid + Vector2(7, y) * k, col.darkened(0.3), 1.0 * k, true)
			_drop(c, mid + Vector2(11, -10) * k, 0.8 * k, Color(0.95, 0.3, 0.25), WHITE, k)
		"martial_heavy_hands":   # a big hammer blow coming down, weight lines
			c.draw_rect(Rect2(mid + Vector2(-12, -14) * k, Vector2(24, 10) * k), WHITE)
			c.draw_line(mid + Vector2(0, -4) * k, mid + Vector2(0, 8) * k, WOOD.lightened(0.2), 3.5 * k, true)
			for x in [-9.0, 0.0, 9.0]:
				c.draw_line(mid + Vector2(x, 9) * k, mid + Vector2(x, 15) * k, light, 2.0 * k, true)
		"martial_fresh_steel":   # a new blade flying in, cracks already on it
			c.draw_colored_polygon(_p(mid, k, [Vector2(-12, 10), Vector2(-8, 13), Vector2(12, -9), Vector2(9, -12)]), WHITE)
			c.draw_polyline(_p(mid, k, [Vector2(-2, 1), Vector2(0, 3), Vector2(-1, 5)]), col.darkened(0.3), 1.4 * k, true)
			for i in 3:
				c.draw_line(mid + Vector2(-15 + i * 3, -2 - i * 4) * k, mid + Vector2(-8 + i * 3, -2 - i * 4) * k, light, 1.6 * k, true)
		"martial_sharp_fragments":   # three shards, each with a spark
			for p in [Vector2(-8, 6), Vector2(0, -6), Vector2(8, 6)]:
				_shard(c, mid + (p as Vector2) * k, Vector2(0, -1), 10.0 * k, 3.0 * k, light, WHITE, k)
				_plus(c, mid + ((p as Vector2) + Vector2(4, -10)) * k, 2.0 * k, WHITE, 1.2 * k)
		"martial_weight_behind_it":   # four notches filling up, the last one heaviest
			for i in 4:
				var h := 4.0 + i * 4.0
				c.draw_rect(Rect2(mid + Vector2(-13 + i * 7, 12 - h) * k, Vector2(5, h) * k), light if i < 3 else WHITE)
			c.draw_line(mid + Vector2(-14, 14) * k, mid + Vector2(14, 14) * k, WHITE, 1.6 * k, true)
		"martial_breaking_point":   # a weapon bent nearly in two, a white flash at the bend
			c.draw_polyline(_p(mid, k, [Vector2(-14, 10), Vector2(0, -2), Vector2(14, 10)]), WHITE, 4.0 * k, true)
			for i in 6:
				var a := TAU * i / 6.0
				c.draw_line(mid + Vector2(0, -6) * k, mid + Vector2(0, -6) * k + Vector2(cos(a), sin(a)) * 6.0 * k, Color(1.0, 0.9, 0.5), 1.6 * k, true)
		"martial_ringing_blows":   # a weapon with ringing arcs around its head
			c.draw_line(mid + Vector2(-12, 12) * k, mid + Vector2(4, -4) * k, WOOD.lightened(0.2), 3.0 * k, true)
			c.draw_circle(mid + Vector2(6, -6) * k, 4.0 * k, WHITE)
			for r in [8.0, 12.0]:
				c.draw_arc(mid + Vector2(6, -6) * k, r * k, -PI * 0.9, PI * 0.1, 10, light, 1.6 * k, true)
		"martial_off_balance":   # a figure tipping over, a curved fall arrow
			_figure(c, mid + Vector2(2, 2) * k, 0.8 * k, WHITE, 2.4 * k)
			c.draw_arc(mid + Vector2(-2, 4) * k, 13.0 * k, PI * 1.05, PI * 1.6, 10, light, 2.0 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-15, 1), Vector2(-11, 7), Vector2(-9, 1)]), light)
			c.draw_line(mid + Vector2(-14, 15) * k, mid + Vector2(14, 15) * k, col.darkened(0.2), 2.0 * k, true)
		"martial_spare_parts":   # broken pieces turning into red Fury drops
			c.draw_colored_polygon(_p(mid, k, [Vector2(-14, -4), Vector2(-4, -8), Vector2(-6, 0)]), WHITE)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-2, 6), Vector2(6, 2), Vector2(2, 12)]), WHITE)
			_drop(c, mid + Vector2(8, -8) * k, 0.65 * k, Color(0.95, 0.3, 0.25), WHITE, k)
			_drop(c, mid + Vector2(13, 6) * k, 0.55 * k, Color(0.95, 0.3, 0.25), WHITE, k)
		"martial_big_swing":   # a wide swing arc ending in a crack mark
			c.draw_arc(mid + Vector2(0, 6) * k, 15.0 * k, PI * 1.1, PI * 1.9, 18, WHITE, 3.0 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(10, -6), Vector2(13, -1), Vector2(10, 3), Vector2(13, 8)]), light, 2.0 * k, true)
			c.draw_circle(mid + Vector2(-13, 1) * k, 2.4 * k, light)
		"martial_clean_swap":   # one weapon out, the next in: two arrows passing
			c.draw_line(mid + Vector2(-14, -5) * k, mid + Vector2(10, -5) * k, light, 2.4 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-15, -5), Vector2(-9, -10), Vector2(-9, 0)]), light)
			c.draw_line(mid + Vector2(14, 6) * k, mid + Vector2(-10, 6) * k, WHITE, 2.4 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(15, 6), Vector2(9, 1), Vector2(9, 11)]), WHITE)
		"martial_gather_pace":   # a clock with a weapon for its hand
			_clock(c, mid, 13.0 * k, light, k)
			c.draw_line(mid, mid + Vector2(8, -8) * k, WHITE, 2.6 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(6, -11), Vector2(11, -11), Vector2(11, -6)]), WHITE)
		# The Rogue.
		"martial_thrift":   # a coin with a small Energy bolt
			c.draw_circle(mid, 12.0 * k, Color(1.0, 0.85, 0.35))
			c.draw_arc(mid, 12.0 * k, 0, TAU, 24, WHITE, 1.6 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(2, -8), Vector2(-3, 1), Vector2(2, 1), Vector2(-2, 9)]), col.darkened(0.5), 2.2 * k, true)
		"martial_spare_knives":   # five daggers stuck in a row
			for i in 5:
				var x := -12.0 + i * 6.0
				c.draw_line(mid + Vector2(x, -10) * k, mid + Vector2(x, 6) * k, WHITE if i < 3 else light, 2.0 * k, true)
				c.draw_line(mid + Vector2(x - 2, 6) * k, mid + Vector2(x + 2, 6) * k, WOOD.lightened(0.3), 2.0 * k, true)
			c.draw_line(mid + Vector2(-15, 12) * k, mid + Vector2(15, 12) * k, col.darkened(0.2), 2.0 * k, true)
		"martial_thrown_weight":   # a dagger in flight, speed lines behind it
			c.draw_colored_polygon(_p(mid, k, [Vector2(-2, -3), Vector2(12, 0), Vector2(-2, 3)]), WHITE)
			c.draw_line(mid + Vector2(-8, 0) * k, mid + Vector2(-2, 0) * k, WOOD.lightened(0.3), 2.6 * k, true)
			for y in [-7.0, 0.0, 7.0]:
				c.draw_line(mid + Vector2(-15, y) * k, mid + Vector2(-10, y) * k, light, 1.6 * k, true)
		"martial_close_work":   # two blades crossed close together
			c.draw_line(mid + Vector2(-12, 12) * k, mid + Vector2(10, -10) * k, WHITE, 3.0 * k, true)
			c.draw_line(mid + Vector2(12, 12) * k, mid + Vector2(-10, -10) * k, light, 3.0 * k, true)
			c.draw_circle(mid, 3.0 * k, Color(1.0, 0.9, 0.5))
		"martial_fresh_legs":   # a running leg with a green Energy flash
			c.draw_polyline(_p(mid, k, [Vector2(-6, -12), Vector2(0, -2), Vector2(-6, 6), Vector2(4, 12)]), WHITE, 3.0 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(0, -2), Vector2(8, 4), Vector2(12, 0)]), WHITE, 3.0 * k, true)
			c.draw_polyline(_p(mid, k, [Vector2(10, -14), Vector2(6, -7), Vector2(11, -7), Vector2(7, 0)]), Color(1.0, 0.9, 0.3), 1.8 * k, true)
		"martial_deep_flow":   # a Flow ring overflowing with two extra beads
			c.draw_arc(mid, 12.0 * k, 0, TAU, 28, Color(0.55, 0.85, 1.0), 2.4 * k, true)
			for i in 2:
				c.draw_circle(mid + Vector2(-4 + i * 8, -16) * k, 2.6 * k, WHITE)
			c.draw_circle(mid, 4.0 * k, light)
		"martial_hot_start":   # a red Kill ring with a flame at its start
			c.draw_arc(mid, 12.0 * k, -PI * 0.5, PI * 1.3, 24, Color(0.95, 0.25, 0.3), 2.6 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-3, -10), Vector2(0, -18), Vector2(3, -10), Vector2(0, -8)]), Color(1.0, 0.7, 0.3))
			c.draw_circle(mid, 3.0 * k, WHITE)
		"martial_easy_pickings":   # a target with three daggers in it
			c.draw_arc(mid, 13.0 * k, 0, TAU, 24, light, 1.8 * k, true)
			c.draw_circle(mid, 4.0 * k, Color(0.95, 0.3, 0.3))
			for a in [-0.6, 0.0, 0.6]:
				var d := Vector2(sin(a), -cos(a))
				c.draw_line(mid + d * 4.0 * k, mid + d * 14.0 * k, WHITE, 2.0 * k, true)
		"martial_footloose":   # two footprints, one near, one far, a bolt between
			_ellipse(c, mid + Vector2(-8, 8) * k, Vector2(3.5, 5.5) * k, WHITE, WHITE, 1.0 * k)
			_ellipse(c, mid + Vector2(8, -8) * k, Vector2(3.5, 5.5) * k, light, light, 1.0 * k)
			c.draw_polyline(_p(mid, k, [Vector2(-2, -4), Vector2(2, 0), Vector2(-1, 1), Vector2(3, 5)]), Color(1.0, 0.9, 0.3), 1.8 * k, true)
		"martial_finish_strong":   # a dagger driving down through a closing ring
			c.draw_arc(mid, 13.0 * k, PI * 0.2, PI * 1.8, 20, Color(0.95, 0.25, 0.3), 2.2 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-2, -15), Vector2(2, -15), Vector2(2, 4), Vector2(0, 9), Vector2(-2, 4)]), WHITE)
			c.draw_line(mid + Vector2(-6, -9) * k, mid + Vector2(6, -9) * k, WOOD.lightened(0.3), 2.4 * k, true)
		"martial_cold_read":   # an eye half shut, a Flow bead doubled
			c.draw_arc(mid + Vector2(0, 2) * k, 12.0 * k, PI * 1.15, PI * 1.85, 14, WHITE, 2.4 * k, true)
			c.draw_line(mid + Vector2(-11, -2) * k, mid + Vector2(11, -2) * k, WHITE, 2.0 * k, true)
			for x in [-5.0, 5.0]:
				c.draw_circle(mid + Vector2(x, 9) * k, 3.0 * k, Color(0.55, 0.85, 1.0))
		"martial_light_fingers":   # two fingers lifting a small bottle
			c.draw_rect(Rect2(mid + Vector2(-4, -2) * k, Vector2(8, 12) * k), Color(0.65, 0.85, 1.0))
			c.draw_rect(Rect2(mid + Vector2(-2, -6) * k, Vector2(4, 4) * k), WOOD.lightened(0.3))
			c.draw_line(mid + Vector2(-10, -14) * k, mid + Vector2(-3, -6) * k, WHITE, 3.0 * k, true)
			c.draw_line(mid + Vector2(10, -14) * k, mid + Vector2(3, -6) * k, WHITE, 3.0 * k, true)
		"martial_pressure_point":   # a fingertip pressing a glowing point
			c.draw_circle(mid + Vector2(0, 6) * k, 5.0 * k, Color(1.0, 0.85, 0.35))
			c.draw_arc(mid + Vector2(0, 6) * k, 9.0 * k, 0, TAU, 20, light, 1.4 * k, true)
			c.draw_line(mid + Vector2(10, -14) * k, mid + Vector2(2, 0) * k, WHITE, 4.0 * k, true)
		# The open talents.
		"martial_weapon_training":   # a practice dummy with a strike mark
			c.draw_line(mid + Vector2(0, -6) * k, mid + Vector2(0, 15) * k, WOOD.lightened(0.2), 3.0 * k, true)
			c.draw_line(mid + Vector2(-10, 0) * k, mid + Vector2(10, 0) * k, WOOD.lightened(0.2), 3.0 * k, true)
			c.draw_circle(mid + Vector2(0, -10) * k, 5.0 * k, WHITE)
			c.draw_line(mid + Vector2(6, -14) * k, mid + Vector2(14, -6) * k, light, 2.2 * k, true)
		"martial_keen_strikes":   # a fist with a star burst on its knuckles
			c.draw_rect(Rect2(mid + Vector2(-8, -2) * k, Vector2(14, 12) * k), WHITE)
			for i in 6:
				var a := TAU * i / 6.0
				c.draw_line(mid + Vector2(8, -6) * k, mid + Vector2(8, -6) * k + Vector2(cos(a), sin(a)) * 7.0 * k, Color(1.0, 0.85, 0.3), 1.8 * k, true)
		"martial_hardy":   # a heart with an upward arrow
			c.draw_circle(mid + Vector2(-5, -2) * k, 6.0 * k, Color(0.9, 0.3, 0.35))
			c.draw_circle(mid + Vector2(5, -2) * k, 6.0 * k, Color(0.9, 0.3, 0.35))
			c.draw_colored_polygon(_p(mid, k, [Vector2(-11, 0), Vector2(11, 0), Vector2(0, 13)]), Color(0.9, 0.3, 0.35))
			c.draw_line(mid + Vector2(0, 6) * k, mid + Vector2(0, -12) * k, WHITE, 2.2 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-4, -9), Vector2(0, -15), Vector2(4, -9)]), WHITE)
		"martial_footing":   # a boot with motion lines
			c.draw_colored_polygon(_p(mid, k, [Vector2(-6, -12), Vector2(2, -12), Vector2(2, 4), Vector2(12, 6), Vector2(12, 11), Vector2(-6, 11)]), WHITE)
			for y in [-6.0, 0.0, 6.0]:
				c.draw_line(mid + Vector2(-15, y) * k, mid + Vector2(-9, y) * k, light, 1.6 * k, true)
		"martial_grit":   # clenched teeth under a low health bar
			c.draw_rect(Rect2(mid + Vector2(-13, -12) * k, Vector2(26, 5) * k), col.darkened(0.4))
			c.draw_rect(Rect2(mid + Vector2(-13, -12) * k, Vector2(10, 5) * k), Color(0.9, 0.3, 0.35))
			c.draw_rect(Rect2(mid + Vector2(-11, 0) * k, Vector2(22, 10) * k), WHITE)
			for x in [-5.0, 0.0, 5.0]:
				c.draw_line(mid + Vector2(x, 0) * k, mid + Vector2(x, 10) * k, col.darkened(0.4), 1.2 * k, true)
			c.draw_line(mid + Vector2(-11, 5) * k, mid + Vector2(11, 5) * k, col.darkened(0.4), 1.2 * k, true)
		# The Brawler.
		"martial_quick_feet":   # two light steps and a Fury drop
			_ellipse(c, mid + Vector2(-7, 6) * k, Vector2(3, 5) * k, WHITE, WHITE, 1.0 * k)
			_ellipse(c, mid + Vector2(1, -4) * k, Vector2(3, 5) * k, light, light, 1.0 * k)
			_drop(c, mid + Vector2(10, 6) * k, 0.7 * k, Color(0.95, 0.3, 0.25), WHITE, k)
		"martial_heavy_bag":   # a hanging punching bag swinging
			c.draw_line(mid + Vector2(0, -16) * k, mid + Vector2(2, -10) * k, light, 1.6 * k, true)
			c.draw_rect(Rect2(mid + Vector2(-5, -10) * k, Vector2(14, 24) * k), Color(0.85, 0.35, 0.3))
			c.draw_arc(mid + Vector2(0, -16) * k, 26.0 * k, PI * 0.42, PI * 0.58, 6, WHITE, 1.4 * k, true)
		"martial_calluses":   # a wrapped fist with thick ridged knuckles
			c.draw_rect(Rect2(mid + Vector2(-9, -6) * k, Vector2(18, 14) * k), WHITE)
			for x in [-6.0, -2.0, 2.0, 6.0]:
				c.draw_circle(mid + Vector2(x, -6) * k, 2.4 * k, Color(0.8, 0.65, 0.55))
			c.draw_line(mid + Vector2(-9, 3) * k, mid + Vector2(9, 3) * k, Color(0.6, 0.35, 0.7), 2.0 * k, true)
		"martial_slow_burn":   # a purple bruise stretched along a long bar
			c.draw_rect(Rect2(mid + Vector2(-14, -3) * k, Vector2(28, 6) * k), col.darkened(0.4))
			for i in 7:
				c.draw_rect(Rect2(mid + Vector2(-14 + i * 4, -3) * k, Vector2(3, 6) * k), Color(0.6, 0.35, 0.7, 1.0 - i * 0.12))
			_hourglass(c, mid + Vector2(0, -11) * k, 0.4 * k, light, WHITE)
		"martial_counter_puncher":   # a caught fist turned back, a curved arrow
			c.draw_circle(mid + Vector2(-6, 4) * k, 6.0 * k, WHITE)
			c.draw_arc(mid + Vector2(2, 0) * k, 11.0 * k, -PI * 0.9, PI * 0.2, 14, light, 2.2 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(13, 0), Vector2(9, 6), Vector2(16, 6)]), light)
		"martial_crowd_work":   # one kick sweeping three small figures
			for x in [-10.0, 0.0, 10.0]:
				c.draw_circle(mid + Vector2(x, -8) * k, 3.0 * k, light)
				c.draw_line(mid + Vector2(x, -5) * k, mid + Vector2(x, 2) * k, light, 2.0 * k, true)
			c.draw_arc(mid + Vector2(0, 10) * k, 14.0 * k, PI * 1.1, PI * 1.9, 16, WHITE, 2.6 * k, true)
		"martial_get_up":   # a figure rising, a green plus beside it
			_figure(c, mid + Vector2(-3, 2) * k, 0.8 * k, WHITE, 2.4 * k)
			c.draw_line(mid + Vector2(-3, 15) * k, mid + Vector2(-3, 9) * k, light, 1.6 * k, true)
			_plus(c, mid + Vector2(10, -8) * k, 4.0 * k, Color(0.55, 1.0, 0.6), 2.2 * k)
		"martial_bad_intentions":   # a glaring pair of eyes over a raised fist
			for x in [-6.0, 6.0]:
				c.draw_colored_polygon(_p(mid, k, [Vector2(x - 4, -10), Vector2(x + 4, -12), Vector2(x + 3, -7), Vector2(x - 3, -7)]), Color(1.0, 0.4, 0.3))
			c.draw_rect(Rect2(mid + Vector2(-6, 0) * k, Vector2(12, 12) * k), WHITE)
		"martial_hardened":   # a purple-tinted plate with a rivet row
			_shield(c, mid, k, Color(0.6, 0.35, 0.7), WHITE)
			for x in [-5.0, 0.0, 5.0]:
				c.draw_circle(mid + Vector2(x, -6) * k, 1.6 * k, WHITE)
		"martial_iron_chin":   # a jaw outline with a hard metal edge
			c.draw_arc(mid + Vector2(0, -2) * k, 12.0 * k, PI * 0.1, PI * 0.9, 16, Color(0.75, 0.8, 0.9), 4.0 * k, true)
			c.draw_arc(mid + Vector2(0, -2) * k, 12.0 * k, PI * 0.9, PI * 2.1, 20, WHITE, 1.6 * k, true)
			for x in [-5.0, 5.0]:
				c.draw_circle(mid + Vector2(x, -5) * k, 1.8 * k, WHITE)
		"martial_last_laugh":   # a grin and a purple bruise fading away
			c.draw_arc(mid + Vector2(-2, -2) * k, 9.0 * k, PI * 0.15, PI * 0.85, 12, WHITE, 2.6 * k, true)
			for x in [-6.0, 2.0]:
				c.draw_circle(mid + Vector2(x, -7) * k, 1.8 * k, WHITE)
			for i in 3:
				c.draw_circle(mid + Vector2(11, -6 + i * 7) * k, (3.0 - i * 0.7) * k, Color(0.6, 0.35, 0.7, 1.0 - i * 0.3))
		"martial_back_up":   # a curved arrow springing up, a Fury drop at its tip
			c.draw_arc(mid + Vector2(-2, 6) * k, 11.0 * k, PI, PI * 1.85, 14, WHITE, 2.6 * k, true)
			_drop(c, mid + Vector2(8, -8) * k, 0.8 * k, Color(0.95, 0.3, 0.25), WHITE, k)
			c.draw_line(mid + Vector2(-15, 14) * k, mid + Vector2(15, 14) * k, col.darkened(0.2), 2.0 * k, true)
		"martial_ground_game":   # a figure flat on the floor, an hourglass over it
			c.draw_line(mid + Vector2(-13, 10) * k, mid + Vector2(9, 10) * k, WHITE, 3.0 * k, true)
			c.draw_circle(mid + Vector2(12, 9) * k, 3.2 * k, WHITE)
			c.draw_line(mid + Vector2(-15, 15) * k, mid + Vector2(15, 15) * k, col.darkened(0.2), 2.0 * k, true)
			_hourglass(c, mid + Vector2(0, -6) * k, 0.55 * k, light, WHITE)
		# The Sharpshooter.
		"martial_quick_release":   # a clock with a cut arc taken out of it
			c.draw_arc(mid, 13.0 * k, PI * 0.1, PI * 1.6, 20, WHITE, 2.2 * k, true)
			c.draw_arc(mid, 13.0 * k, PI * 1.6, PI * 2.1, 8, Color(0.55, 0.8, 1.0), 4.0 * k, true)
			c.draw_line(mid, mid + Vector2(0, -9) * k, light, 2.0 * k, true)
		"martial_deep_hold":   # a gold bar overflowing its frame
			c.draw_rect(Rect2(mid + Vector2(-13, -4) * k, Vector2(22, 8) * k), Color(1.0, 0.82, 0.35))
			c.draw_rect(Rect2(mid + Vector2(-13, -4) * k, Vector2(22, 8) * k), WHITE, false, 1.4 * k)
			c.draw_rect(Rect2(mid + Vector2(9, -3) * k, Vector2(6, 6) * k), Color(1.0, 0.82, 0.35, 0.7))
		"martial_on_a_roll":   # a row of fletchings, each brighter than the last
			for i in 5:
				var x := -12.0 + i * 6.0
				c.draw_colored_polygon(_p(mid, k, [Vector2(x - 2, 6), Vector2(x, -6 - i), Vector2(x + 2, 6)]), Color(1.0, 0.8, 0.35, 0.4 + i * 0.15))
		"martial_lucky_shot":   # a four-leaf clover with an arrow through it
			for i in 4:
				var a := TAU * i / 4.0 + PI * 0.25
				c.draw_circle(mid + Vector2(cos(a), sin(a)) * 5.0 * k, 4.5 * k, Color(0.45, 0.85, 0.45))
			c.draw_line(mid + Vector2(-14, 12) * k, mid + Vector2(12, -10) * k, WHITE, 2.0 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(15, -13), Vector2(8, -11), Vector2(12, -6)]), WHITE)
		"martial_long_range":   # an arrow far off with distance ticks
			c.draw_line(mid + Vector2(-15, 4) * k, mid + Vector2(12, 4) * k, WHITE, 1.8 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(15, 4), Vector2(9, 0), Vector2(9, 8)]), WHITE)
			for x in [-10.0, -3.0, 4.0]:
				c.draw_line(mid + Vector2(x, 8) * k, mid + Vector2(x, 12) * k, light, 1.6 * k, true)
			c.draw_circle(mid + Vector2(12, -8) * k, 3.0 * k, Color(0.95, 0.35, 0.3))
		"martial_waiting_game":   # an arrow resting while a gold bar grows
			c.draw_line(mid + Vector2(-13, -6) * k, mid + Vector2(10, -6) * k, WHITE, 1.8 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(13, -6), Vector2(7, -10), Vector2(7, -2)]), WHITE)
			for i in 3:
				c.draw_rect(Rect2(mid + Vector2(-10 + i * 7, 10 - i * 3) * k, Vector2(5, 3 + i * 3) * k), Color(1.0, 0.82, 0.35))
		"martial_clean_release":   # a gold arrow leaving the string, a fletching lit
			c.draw_arc(mid + Vector2(-8, 0) * k, 14.0 * k, -PI * 0.45, PI * 0.45, 12, light, 2.0 * k, true)
			c.draw_line(mid + Vector2(-4, 0) * k, mid + Vector2(14, 0) * k, Color(1.0, 0.82, 0.35), 2.4 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(-6, 0), Vector2(-10, -4), Vector2(-10, 4)]), WHITE)
		"martial_long_streak":   # a quiver with fletchings past its rim
			c.draw_colored_polygon(_p(mid, k, [Vector2(-7, -4), Vector2(7, -4), Vector2(5, 14), Vector2(-5, 14)]), WOOD.lightened(0.2))
			for i in 6:
				var x := -6.0 + i * 2.4
				c.draw_line(mid + Vector2(x, -4) * k, mid + Vector2(x, -12 - (i % 2) * 3) * k, Color(1.0, 0.82, 0.35), 1.6 * k, true)
		"martial_second_arrow":   # two arrows flying side by side, one fainter
			for o in [Vector2(0, -5), Vector2(0, 5)]:
				var a := 1.0 if (o as Vector2).y < 0 else 0.55
				c.draw_line(mid + (Vector2(-13, 0) + o) * k, mid + (Vector2(10, 0) + o) * k, Color(WHITE, a), 1.8 * k, true)
				c.draw_colored_polygon(_p(mid + o * k, k, [Vector2(14, 0), Vector2(8, -4), Vector2(8, 4)]), Color(WHITE, a))
		"martial_hard_target":   # a full health bar with an arrow into it
			c.draw_rect(Rect2(mid + Vector2(-13, -10) * k, Vector2(26, 6) * k), Color(0.45, 0.85, 0.45))
			c.draw_line(mid + Vector2(-10, 14) * k, mid + Vector2(4, -2) * k, WHITE, 2.0 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(7, -5), Vector2(0, -3), Vector2(4, 2)]), WHITE)
		"martial_run_it_back":   # a looping arrow coming round again
			c.draw_arc(mid, 11.0 * k, PI * 0.2, PI * 1.9, 24, WHITE, 2.4 * k, true)
			c.draw_colored_polygon(_p(mid, k, [Vector2(10, -7), Vector2(15, 0), Vector2(7, 0)]), WHITE)
			c.draw_circle(mid, 2.6 * k, light)
		"martial_hold_steady":   # a steady hand under a gold glow
			c.draw_circle(mid + Vector2(0, -8) * k, 6.0 * k, Color(1.0, 0.82, 0.35, 0.6))
			c.draw_line(mid + Vector2(-12, 6) * k, mid + Vector2(12, 6) * k, WHITE, 4.0 * k, true)
			for x in [-8.0, -3.0, 2.0, 7.0]:
				c.draw_line(mid + Vector2(x, 6) * k, mid + Vector2(x, 0) * k, WHITE, 2.4 * k, true)
