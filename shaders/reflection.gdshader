shader_type spatial;
// A Reflection (Arcane tank) and the Decoy: a see-through copy of a character.
// Purple glass: what is behind it shows through, blurred and bent a little, and
// its edges glow. Unshaded, so it reads the same in a dark cave as in daylight.
render_mode unshaded, cull_back, depth_draw_always, shadows_disabled, world_vertex_coords;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.70, 0.42, 1.0, 1.0);
uniform float blur : hint_range(0.0, 6.0) = 3.0;        // how blurred what is behind it looks
uniform float glass : hint_range(0.0, 1.0) = 0.45;      // how much of the purple covers it
uniform float bend : hint_range(0.0, 0.2) = 0.03;       // how far it bends what is behind it
uniform float rim_power : hint_range(0.5, 6.0) = 2.0;   // how tight the glowing edge is
uniform float wobble : hint_range(0.0, 0.05) = 0.008;   // how much its surface shimmers (metres)
uniform float fade : hint_range(0.0, 1.0) = 1.0;        // 0 = gone, 1 = fully there
uniform float flash : hint_range(0.0, 1.0) = 0.0;       // whitens it (shattering, being struck)

void vertex() {
	VERTEX += normalize(NORMAL) * wobble * sin(TIME * 3.0 + VERTEX.y * 14.0);
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float facing = clamp(dot(n, normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	vec3 behind = textureLod(screen_tex, SCREEN_UV + n.xy * bend, blur).rgb;
	vec3 col = mix(behind, tint.rgb, clamp(glass + rim * 0.35, 0.0, 1.0));
	col += tint.rgb * rim * 0.7;
	col = mix(col, vec3(1.0), flash * 0.7);
	ALBEDO = col;
	ALPHA = fade;
}
