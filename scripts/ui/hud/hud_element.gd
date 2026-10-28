extends Control
class_name HudElement

# One piece of the in-game HUD (player frame, target frame, cast bar, an action
# bar, auras, ...), moved out of scripts/hud.gd so that file stays the shared
# core (player, SignalBus wiring, per-frame calls, messages, death screen). A new
# HUD element gets its own file in scripts/ui/hud/, never a section in hud.gd.
#
# The HUD makes each element (hud._add) and calls update(delta) every frame while
# it shows and slow_update() ten times a second. `key` is both its options in
# UIConfig (scripts/ui/ui_config.gd) and its Move UI mover. Shared options
# (enabled, scale, opacity, when it shows) are handled here; an element reads
# its own with cfg("width") and lays itself out in apply_config().

const Abilities = preload("res://scripts/abilities.gd")
const Balance = preload("res://scripts/balance.gd")
const Macros = preload("res://scripts/core/macros.gd")
const Items = preload("res://scripts/items.gd")
const UI = preload("res://scripts/ui_kit.gd")

## The HUD (scripts/hud.gd): hud.player, hud.show_message(...), hud.element(key).
var hud: Node
## Options (UIConfig) and Move UI key.
var key := ""
## Move UI key when it differs from `key` (the action bars keep their old ones).
var mover_key := ""
## Move UI label.
var title := ""
## Move UI shows its mover even while it is hidden (target frame, cast bars).
var always := false
var _fade := 1.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	build()
	var s := get_node_or_null("/root/Settings")
	if s:
		s.ui_config_changed.connect(_on_config_changed)
		s.register_hud(self)
	apply_config()
	if mover_key != "-":
		UILayout.register(get_tree(), self, mover_key if mover_key != "" else key, title, always)

func _on_config_changed(elem: String) -> void:
	if elem == key or elem == "" or elem == "general":
		apply_config()

## The player (null in tests without one).
var player: Node:
	get:
		return hud.player if hud != null else null

func cfg(opt: String) -> Variant:
	return UIConfig.value(key, opt)

func enabled() -> bool:
	return bool(cfg("enabled"))

# --- What an element fills in ---------------------------------------------------------

## Make its nodes (once).
func build() -> void:
	pass

## Size and look from its options (on every change of them).
func layout() -> void:
	pass

## Every frame while it shows.
func update(_delta: float) -> void:
	pass

## Ten times a second, shown or not (what decides whether it shows goes here).
func slow_update() -> void:
	pass

## The abilities on the bars changed (PlayerData, keybinds).
func refresh() -> void:
	pass

## update() runs even while hidden (an element that shows itself: the cast bar).
var tick_hidden := false

## Whether it has anything to show right now (a target, a cast...).
func wanted() -> bool:
	return true

# --- Shared ---------------------------------------------------------------------------

func apply_config() -> void:
	var sc := float(cfg("scale")) if cfg("scale") != null else 1.0
	scale = Vector2(sc, sc)
	layout()
	refresh_visible()
	_apply_alpha()

func refresh_visible() -> void:
	var v := enabled() and wanted()
	if visible != v:
		visible = v

## Its Opacity option times its fading (Settings multiplies in the HUD opacity).
func hud_alpha() -> float:
	var a := float(cfg("alpha")) if cfg("alpha") != null else 1.0
	return a * _fade

func _apply_alpha() -> void:
	var s := get_node_or_null("/root/Settings")
	var a: float = s.hud_alpha_of(self) if s else hud_alpha()
	if not is_equal_approx(modulate.a, a):
		modulate.a = a

## The "Show" option: always, only in or out of combat, or on mouseover.
func fade_tick(in_combat: bool) -> void:
	var f := 1.0
	match str(cfg("fade")):
		"combat":
			f = 1.0 if in_combat else 0.0
		"no_combat":
			f = 0.0 if in_combat else 1.0
		"mouseover":
			f = 1.0 if get_global_rect().has_point(get_global_mouse_position()) else 0.0
	if f != _fade:
		_fade = f
		_apply_alpha()

## Its size on screen (Move UI and the layout math use the scaled size).
func screen_size() -> Vector2:
	return size * scale

## Set its size (and minimum, so containers don't grow it back).
func set_box(s: Vector2) -> void:
	custom_minimum_size = s
	size = s

## A panel child filling the element, with the skin's backdrop.
func add_backdrop(alpha := -1.0) -> Panel:
	var p := Panel.new()
	p.name = "Backdrop"
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UISkin.backdrop(alpha))
	add_child(p)
	return p

## Every ability id on the action bars (macros count for each ability in them).
func bar_ability_ids() -> Array[String]:
	var out: Array[String] = []
	var pd := get_node_or_null("/root/PlayerData")
	if pd == null:
		return out
	for slot_id in pd.action_bar:
		var ids: Array[String] = [str(slot_id)]
		if Macros.is_macro(str(slot_id)):
			ids = Macros.abilities_of(str(slot_id))
		for id in ids:
			if id != "" and not out.has(id):
				out.append(id)
	return out
