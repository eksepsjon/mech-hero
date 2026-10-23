// Bullet orb: hot white core, team colour body and a dark rim so bullets stay
// readable on bright daytime ground as well as at night.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform float energy = 3.0;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 body = mix(COLOR.rgb, vec3(1.0), smoothstep(0.55, 0.92, facing)) * energy;
	vec3 rim = COLOR.rgb * 0.18;
	ALBEDO = mix(rim, body, smoothstep(0.12, 0.32, facing));
}
