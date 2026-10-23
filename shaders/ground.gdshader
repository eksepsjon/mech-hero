// District ground drawn procedurally: asphalt road grid with lane markings and
// crosswalks, plus block fill by ground_mode (0 city concrete, 1 crop fields,
// 2 forest floor, 3 suburban lawns), and a neon boundary line around the arena.
shader_type spatial;

uniform float pitch = 35.0;
uniform float road_w = 10.0;
uniform float half_size = 70.0;
uniform int ground_mode = 0;
uniform vec3 asphalt : source_color = vec3(0.045, 0.05, 0.065);
uniform vec3 sidewalk : source_color = vec3(0.17, 0.17, 0.19);
uniform vec3 block_col : source_color = vec3(0.1, 0.105, 0.115);
uniform vec3 boundary_col : source_color = vec3(1.0, 0.2, 0.55);

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
	vec3 c = block_col * (0.85 + 0.3 * hash(floor(wpos.xz / 4.0)));
	vec3 em = vec3(0.0);
	bool natural = ground_mode == 1 || ground_mode == 2;
	if (ground_mode == 1) {
		// Patchwork of crop fields with furrows.
		vec2 field = floor(wpos.xz / 22.0);
		float h = hash(field);
		vec3 crop = h < 0.35 ? vec3(0.07, 0.13, 0.04) : (h < 0.65 ? vec3(0.2, 0.16, 0.06) : vec3(0.11, 0.08, 0.05));
		float row = fract((hash(field + 7.0) > 0.5 ? wpos.x : wpos.z) / 1.6);
		c = crop * (row < 0.5 ? 0.75 : 1.0) * (0.9 + 0.2 * hash(floor(wpos.xz / 3.0)));
	} else if (ground_mode == 2) {
		// Needle-strewn forest floor.
		float n = hash(floor(wpos.xz / 2.0)) * 0.6 + hash(floor(wpos.xz / 7.0)) * 0.4;
		c = mix(vec3(0.03, 0.06, 0.035), vec3(0.08, 0.07, 0.045), n);
	} else if (ground_mode == 3) {
		// Lawns and gardens.
		c = mix(vec3(0.05, 0.1, 0.05), vec3(0.08, 0.12, 0.06), hash(floor(wpos.xz / 3.0)));
	}
	if (dx < hw + 2.0 || dz < hw + 2.0) {
		if (natural) {
			c = vec3(0.12, 0.1, 0.075);  // dirt shoulder
		} else {
			c = sidewalk;
			// paving tiles
			vec2 t = fract(wpos.xz / 1.5);
			if (t.x < 0.05 || t.y < 0.05) c *= 0.8;
		}
	}
	if (on_x || on_z) {
		c = asphalt * (0.9 + 0.2 * hash(floor(wpos.xz * 0.7)));
		vec3 yellow = vec3(0.95, 0.72, 0.15);
		vec3 white = vec3(0.75);
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
	if (outside > 0.0) {
		c *= 0.4;
	}
	float edge = abs(outside);
	if (edge < 0.5) {
		em = boundary_col * 3.0;
	} else if (outside < 0.0 && edge < 4.0) {
		// hazard stripes just inside the boundary
		float s = step(0.5, fract((wpos.x + wpos.z) / 3.0));
		em = boundary_col * 0.25 * s * (1.0 - edge / 4.0);
	}
	ALBEDO = c;
	EMISSION = em;
	ROUGHNESS = 0.85;
}
