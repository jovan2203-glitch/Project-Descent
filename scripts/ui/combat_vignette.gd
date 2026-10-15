extends CanvasLayer

# Subtle red glow on the screen edges while the local player is in combat.
# Flashes a little brighter when combat starts, then breathes gently until it
# ends (SignalBus.combat_state_changed). Sits under the HUD and never blocks
# the mouse.

const SHADER := """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.85, 0.05, 0.04, 1.0);
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	// Distance to the nearest edge (0 in the middle, 1 at an edge), corners a bit stronger.
	float edge = max(abs(uv.x), abs(uv.y));
	float corner = length(uv) * 0.7071;
	float d = max(edge, corner);
	float a = smoothstep(0.72, 1.0, d);
	COLOR = vec4(tint.rgb, a * intensity);
}
"""

## Resting strength while in combat (0..1) - keep it subtle.
const BASE := 0.22
## Extra strength of the flash when combat starts.
const FLASH := 0.28
## Breathing: +- this much, this many seconds per cycle.
const PULSE := 0.06
const PULSE_PERIOD := 2.2

var _rect: ColorRect
var _mat: ShaderMaterial
var _in_combat := false
var _level := 0.0      # eased 0..1 "in combat" amount
var _flash := 0.0
var _t := 0.0

func _ready() -> void:
	layer = 0   # under the HUD (1) and windows (2)
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)
	get_node("/root/SignalBus").combat_state_changed.connect(_on_combat)
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("is_in_combat") and p.is_in_combat():
		_on_combat(true)

func _on_combat(on: bool) -> void:
	if on and not _in_combat:
		_flash = 1.0
	_in_combat = on

func _process(delta: float) -> void:
	_t += delta
	_level = move_toward(_level, 1.0 if _in_combat else 0.0, delta * (3.0 if _in_combat else 1.5))
	_flash = move_toward(_flash, 0.0, delta * 1.8)
	var pulse := sin(_t * TAU / PULSE_PERIOD) * PULSE if _in_combat else 0.0
	var v := _level * (BASE + pulse) + _flash * FLASH
	_rect.visible = v > 0.005
	if _rect.visible:
		_mat.set_shader_parameter("intensity", clampf(v, 0.0, 1.0))
