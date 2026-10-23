// Backdrop building outside the arena: same facade, plain material uniforms so the
// skyline doesn't use up per-instance shader slots.
shader_type spatial;
render_mode diffuse_toon, specular_toon;

uniform float night = 0.0;

uniform vec4 base_color : source_color = vec4(0.25, 0.27, 0.32, 1.0);
uniform vec4 window_color : source_color = vec4(1.0, 0.8, 0.5, 1.0);
uniform float height_half = 10.0;
uniform float facade_seed = 0.0;

#include "res://shaders/building_facade.gdshaderinc"

void vertex() {
	lpos = VERTEX;
	lnorm = NORMAL;
}

void fragment() {
	vec3 albedo;
	vec3 emission;
	float rough;
	facade(base_color.rgb, window_color, vec4(0.0, height_half, facade_seed, 0.0), TIME, night, albedo, emission, rough);
	ALBEDO = albedo;
	EMISSION = emission;
	ROUGHNESS = rough;
	METALLIC = 0.1;
}
