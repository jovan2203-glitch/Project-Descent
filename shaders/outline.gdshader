shader_type spatial;
// Inverted-hull outline, used as a material_overlay on targeted enemies.
render_mode unshaded, cull_front, world_vertex_coords;

uniform vec4 outline_color : source_color = vec4(1.0, 0.1, 0.1, 1.0);
uniform float outline_width = 0.03;

void vertex() {
	VERTEX += normalize(NORMAL) * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
