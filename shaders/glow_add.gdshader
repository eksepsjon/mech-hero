// Flat additive glow for beams, lightning and holograms.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform float energy = 3.0;
uniform float alpha = 1.0;

void fragment() {
	ALBEDO = color.rgb * energy;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
