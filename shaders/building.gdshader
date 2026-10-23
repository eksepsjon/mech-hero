// Gameplay building: per-instance colours and state, packed into three vec4 slots.
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform float night = 0.0;

instance uniform vec4 base_color : source_color = vec4(0.25, 0.27, 0.32, 1.0);
instance uniform vec4 window_color : source_color = vec4(1.0, 0.8, 0.5, 1.0);
instance uniform vec4 params = vec4(0.0, 5.0, 0.0, 0.0);

#include "res://shaders/building_facade.gdshaderinc"

void vertex() {
	lpos = VERTEX;
	lnorm = NORMAL;
}

void fragment() {
	// Screen-door fade while this building hides the player.
	if (params.w > 0.01) {
		vec2 sp = floor(FRAGCOORD.xy);
		if (fract(sin(dot(sp, vec2(12.9898, 78.233))) * 43758.5453) < params.w * 0.8) {
			discard;
		}
	}
	vec3 albedo;
	vec3 emission;
	float rough;
	facade(base_color.rgb, window_color, params, TIME, night, albedo, emission, rough);
	ALBEDO = albedo;
	EMISSION = emission;
	ROUGHNESS = rough;
	METALLIC = 0.1;
}
