// Flat alpha-blended glow for telegraph lines that must read on bright ground.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform float energy = 1.5;
uniform float alpha = 1.0;

void fragment() {
	ALBEDO = color.rgb * energy;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
