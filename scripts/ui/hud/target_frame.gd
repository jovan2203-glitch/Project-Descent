extends HudElement

# Your target's frame: your enemy target, or your friendly target. Name, level
# and rank on its health bar (+ shield), its resource when it has one, its cast
# bar (so you know when and what to interrupt; a detached one is the Target Cast
# Bar element), and its buffs / debuffs with tooltips under it. An elite's trait
# is spelled out under the frame.

const STATUS_ICONS = preload("res://scripts/ui/status_icons.gd")
const ELITE_TRAITS = preload("res://scripts/core/elite_traits.gd")

var _health: HudBar
var _power: HudBar
var _cast: HudBar           # the attached cast bar (the detached one lives in target_cast.gd)
var _trait: Label
var _icons: HFlowContainer
var _last_cp := -1.0        # the target's cast progress last frame (-1 = not casting)
var _end_until := 0.0       # showing the end flash until this time
var _end_ok := true
var _last_target: Variant = null
var _target: Node = null

func _init() -> void:
	super()
	key = "target_frame"
	title = "Target Frame"
	always = true
	tick_hidden = true

func build() -> void:
	add_backdrop()
	_health = HudBar.new()
	add_child(_health)
	_power = HudBar.new()
	add_child(_power)
	_cast = HudBar.new()
	_cast.fill_color = UISkin.ENEMY_CAST
	add_child(_cast)
	_trait = UISkin.label("", 11, Color(1.0, 0.75, 0.3))
	_trait.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_trait)
	_icons = STATUS_ICONS.new()
	add_child(_icons)

func layout() -> void:
	if _health == null:
		return
	var w := float(cfg("width"))
	var h := float(cfg("health_height"))
	var p := float(cfg("power_height"))
	var detached := bool(cfg("cast_detached"))
	var ch := float(cfg("cast_height"))
	_health.position = Vector2(1, 1)
	_health.size = Vector2(w - 2, h)
	_health.font_size = UISkin.font(12 if h >= 20 else 10)
	var y := 1.0 + h
	_power.visible = p > 0
	_power.position = Vector2(1, y + 1)
	_power.size = Vector2(w - 2, p)
	if p > 0:
		y += p + 1
	# (The attached cast bar's row is always kept, so the frame doesn't jump.)
	_cast.visible = false
	if not detached:
		_cast.position = Vector2(1, y + 1)
		_cast.size = Vector2(w - 2, ch)
		_cast.font_size = UISkin.font(11 if ch >= 14 else 9)
		y += ch + 1
	set_box(Vector2(w, y + 1))
	_trait.position = Vector2(0, size.y + 2)
	_trait.size = Vector2(w, 0)
	var auras := str(cfg("auras"))
	_icons.visible = auras != "none"
	_icons.set_icon_size(float(cfg("aura_size")))
	_icons.position = Vector2(0, size.y + 2)
	_icons.size = Vector2(w, 0)
	_icons.custom_minimum_size = Vector2(w, 0)

func wanted() -> bool:
	return _target != null

func current_target() -> Node:
	if player == null:
		return null
	var t = player.displayed_target() if player.has_method("displayed_target") else player.get("target")   # (not a mouseover cast's)
	if t != null and is_instance_valid(t) and t.is_alive():
		return t
	var f = player.get("friendly_target")
	if f != null and is_instance_valid(f) and f.is_alive():
		return f
	return null

## The bar the target's cast shows on: the attached one, or the Target Cast Bar.
func cast_bar() -> HudBar:
	if bool(cfg("cast_detached")):
		var tc: Node = hud.element("target_cast") if hud else null
		return tc.bar() if tc else null
	return _cast

func update(_delta: float) -> void:
	_target = current_target()
	refresh_visible()
	var tgt := _target
	if tgt != _last_target:
		_last_target = tgt
		_last_cp = -1.0      # a new target: no leftover end flash from the old one
		_end_until = 0.0
		_trait.text = ""
	var cb := cast_bar()
	if tgt == null:
		if cb:
			cb.visible = false
		return
	var nm := str(tgt.get("display_name")) if tgt.get("display_name") != null else str(tgt.name)
	var lvl = tgt.get("level")
	var rank := str(tgt.get("rank")) if tgt.get("rank") != null else ""
	var friendly: bool = tgt.is_in_group("remote_player") or tgt.is_in_group("friendly")
	var left := "%s%s%s" % [("%d  " % int(lvl)) if lvl != null else "", nm,
		("  (" + rank.capitalize() + ")") if rank == "elite" or rank == "boss" else ""]
	var name_col := Color(0.55, 1.0, 0.55) if friendly else Color.WHITE
	if rank == "boss":
		name_col = Color(1.0, 0.55, 0.5)
	elif rank == "elite":
		name_col = Color(1.0, 0.8, 0.4)
	_health.text_color = name_col
	var hp := float(tgt.get("health")) if tgt.get("health") != null else 0.0
	var mhp := maxf(float(tgt.get("max_health")) if tgt.get("max_health") != null else 1.0, 1.0)
	var frac := clampf(hp / mhp, 0.0, 1.0)
	var st: Node = tgt.get_node_or_null("Status")
	var shield := 0
	if st and st.has_method("total_absorb"):
		shield = st.total_absorb()
	_health.fill_color = UISkin.health_color(frac) if friendly else UISkin.HOSTILE
	_health.set_fracs(frac, shield / mhp)
	var txt := UISkin.value_text(str(cfg("text")), hp, mhp)
	if shield > 0:
		txt += "  +" + UISkin.short(shield)
	_health.set_texts(left, "", txt)
	# Resource bar: any target that has one (e.g. a caster enemy's mana).
	var mres = tgt.get("max_resource")
	var has_res: bool = mres != null and float(mres) > 0.0
	_power.modulate.a = 1.0 if has_res else 0.0
	if has_res:
		var cur := float(tgt.get("resource")) if tgt.get("resource") != null else 0.0
		var rc = tgt.get("resource_color")
		_power.fill_color = rc if rc is Color else UISkin.POWER["mana"]
		_power.set_fracs(cur / float(mres))
	if cb:
		_update_cast(tgt, cb)

func _update_cast(tgt: Node, cb: HudBar) -> void:
	var cp := float(tgt.cast_progress()) if tgt.has_method("cast_progress") else -1.0
	var now := Time.get_ticks_msec() / 1000.0
	if cp >= 0.0:
		cb.fill_color = UISkin.ENEMY_CAST
		cb.spark = true
		cb.set_fracs(cp)
		cb.set_texts(str(tgt.cast_display_name()), "", "%.1f" % float(tgt.cast_time_left()))
		_end_until = 0.0
	elif _last_cp >= 0.0:
		# The cast just ended: white flash if it went off, red if it was interrupted.
		_end_ok = _last_cp >= 0.9
		_end_until = now + (0.25 if _end_ok else 0.6)
		cb.set_fracs(1.0)
		cb.spark = false
		cb.fill_color = Color(1, 1, 1) if _end_ok else UISkin.CAST_FAIL
		if not _end_ok:
			cb.set_texts("Interrupted")
	cb.visible = cp >= 0.0 or now < _end_until
	_last_cp = cp

func slow_update() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var trait_id := str(_target.get("elite_trait")) if _target.get("elite_trait") != null else ""
	var t := ELITE_TRAITS.desc(trait_id) if trait_id != "" else ""
	if _trait.text != t:
		_trait.text = t
	if not _icons.visible:
		return
	var st: Node = _target.get_node_or_null("Status")
	var list: Array = st.list() if st else []
	match str(cfg("auras")):
		"debuffs":
			list = list.filter(func(e): return bool(e["debuff"]))
		"buffs":
			list = list.filter(func(e): return not bool(e["debuff"]))
	_icons.position.y = size.y + 2 + (_trait.get_minimum_size().y + 2 if t != "" else 0.0)
	_icons.show_effects(list)
