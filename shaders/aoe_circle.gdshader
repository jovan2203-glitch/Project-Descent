shader_type spatial;
// Ground circle for area spells: bright rim + soft fill. Used on a flat QuadMesh.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.45, 0.85, 1.0, 1.0);
uniform float fill_alpha = 0.18;
uniform float rim_alpha = 0.9;
uniform float rim_width = 0.06;
uniform float pulse = 0.0;

void fragment() {
	float d = distance(UV, vec2(0.5)) * 2.0;
	if (d > 1.0) discard;
	float rim = smoothstep(1.0 - rim_width, 1.0 - rim_width * 0.4, d) * (1.0 - smoothstep(0.97, 1.0, d));
	float wave = pulse * 0.08 * sin(d * 18.0 - TIME * 6.0);
	ALBEDO = color.rgb;
	ALPHA = clamp(fill_alpha + wave + rim * rim_alpha, 0.0, 1.0);
}
