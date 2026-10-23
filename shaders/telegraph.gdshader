// Ground warning circle: pulsing rim plus a fill that grows with `progress`.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.25, 0.3, 1.0);
uniform float progress = 0.0;
uniform float energy = 2.5;
uniform float fade = 1.0;
uniform float fill_strength = 0.3;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float ring = smoothstep(0.86, 0.95, r) * (1.0 - smoothstep(0.97, 1.0, r));
	float fill = step(r, progress) * fill_strength;
	float pulse = 0.65 + 0.35 * sin(TIME * 18.0);
	ALBEDO = color.rgb * energy;
	ALPHA = clamp((ring * pulse + fill) * fade, 0.0, 1.0);
}
