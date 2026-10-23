// Glowing bullet: team colour at the rim, hot white core where the surface faces the camera.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform float energy = 3.5;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 core = mix(COLOR.rgb, vec3(1.0), smoothstep(0.45, 0.9, facing));
	ALBEDO = core * energy;
}
