// District ground drawn procedurally: asphalt road grid with lane markings and
// crosswalks, plus block fill by ground_mode (0 city plaza, 1 crop fields,
// 2 forest floor, 3 suburban lawns), and a painted curb around the arena.
// Colours are daytime albedo; `night` darkens them and lights the boundary.
shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform float pitch = 35.0;
uniform float road_w = 10.0;
uniform float half_size = 70.0;
uniform int ground_mode = 0;
uniform float night = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float road_dist(float v) {
	return abs(mod(v + pitch * 0.5, pitch) - pitch * 0.5);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float hw = road_w * 0.5;
	float dx = road_dist(wpos.x);
	float dz = road_dist(wpos.z);
	bool on_x = dx < hw;
	bool on_z = dz < hw;
	bool natural = ground_mode == 1 || ground_mode == 2;

	// Plaza concrete with tile joints.
	vec3 c = vec3(0.66, 0.64, 0.6) * (0.93 + 0.12 * hash(floor(wpos.xz / 4.0)));
	vec2 tile = fract(wpos.xz / 3.0);
	if (tile.x < 0.04 || tile.y < 0.04) c *= 0.88;

	if (ground_mode == 1) {
		vec2 field = floor(wpos.xz / 22.0);
		float h = hash(field);
		vec3 crop = h < 0.35 ? vec3(0.4, 0.66, 0.22) : (h < 0.65 ? vec3(0.88, 0.74, 0.34) : vec3(0.55, 0.4, 0.26));
		float row = fract((hash(field + 7.0) > 0.5 ? wpos.x : wpos.z) / 1.6);
		c = crop * (row < 0.5 ? 0.82 : 1.0) * (0.94 + 0.1 * hash(floor(wpos.xz / 3.0)));
	} else if (ground_mode == 2) {
		float n = hash(floor(wpos.xz / 2.0)) * 0.6 + hash(floor(wpos.xz / 7.0)) * 0.4;
		c = mix(vec3(0.24, 0.44, 0.18), vec3(0.4, 0.46, 0.22), n);
	} else if (ground_mode == 3) {
		c = mix(vec3(0.38, 0.64, 0.27), vec3(0.46, 0.7, 0.31), hash(floor(wpos.xz / 3.0)));
	}

	if (dx < hw + 2.0 || dz < hw + 2.0) {
		if (natural) {
			c = vec3(0.6, 0.5, 0.36);  // dirt shoulder
		} else {
			c = vec3(0.82, 0.8, 0.76);  // sidewalk
			vec2 t = fract(wpos.xz / 1.5);
			if (t.x < 0.05 || t.y < 0.05) c *= 0.88;
		}
	}
	if (on_x || on_z) {
		c = vec3(0.3, 0.31, 0.35) * (0.95 + 0.1 * hash(floor(wpos.xz * 0.7)));
		vec3 yellow = vec3(1.0, 0.8, 0.2);
		vec3 white = vec3(0.95);
		if (on_x && !on_z) {
			if (dx < 0.22 && mod(wpos.z, 6.0) < 3.2) c = yellow;
			if (abs(dx - (hw - 0.7)) < 0.12) c = white;
			if (!natural && dz > hw + 0.6 && dz < hw + 3.6 && mod(wpos.x, 1.6) < 0.8) c = white;
		}
		if (on_z && !on_x) {
			if (dz < 0.22 && mod(wpos.x, 6.0) < 3.2) c = yellow;
			if (abs(dz - (hw - 0.7)) < 0.12) c = white;
			if (!natural && dx > hw + 0.6 && dx < hw + 3.6 && mod(wpos.z, 1.6) < 0.8) c = white;
		}
	}

	float outside = max(abs(wpos.x), abs(wpos.z)) - half_size;
	vec3 em = vec3(0.0);
	if (outside > 0.0) {
		c *= mix(0.82, 0.4, night);
	} else if (outside > -1.4) {
		// Red and white painted curb marking the arena edge.
		float s = step(0.5, fract((wpos.x + wpos.z) / 2.5));
		c = mix(vec3(0.9, 0.22, 0.2), vec3(0.96), s);
		em = vec3(1.0, 0.2, 0.55) * 3.0 * night;
	}
	ALBEDO = c * mix(1.0, 0.35, night);
	EMISSION = em;
	ROUGHNESS = 0.9;
}
