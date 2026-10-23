// Shared building facade: lit window grid per floor, damage that kills/flickers
// windows and scorches walls.
// p = (damage, half_height, seed, fade); win_col.a = has windows.
// night 0..1: by day windows are glass; at night they light up and walls darken.
// The caller handles the fade (discard must live in fragment()).
const float floor_h = 3.2;
const float bay_w = 2.6;

varying vec3 lpos;
varying vec3 lnorm;

float hash_seeded(vec2 p, float seed) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.13) * 43758.5453);
}

void facade(vec3 base, vec4 win_col, vec4 p, float time, float night_amt,
		out vec3 albedo, out vec3 emission, out float roughness) {
	float damage = p.x;
	float half_height = p.y;
	float seed = p.z;
	float windows = win_col.a;
	vec3 col = base * mix(1.0, 0.45, night_amt);
	vec3 em = vec3(0.0);
	float rough = 0.8;
	if (abs(lnorm.y) < 0.5) {
		float u = abs(lnorm.x) > 0.5 ? lpos.z : lpos.x;
		float y = lpos.y + half_height;
		vec2 cell = vec2(floor(u / bay_w), floor(y / floor_h));
		vec2 f = vec2(fract(u / bay_w), fract(y / floor_h));
		float side_id = dot(lnorm.xz, vec2(3.0, 7.0));
		float h = hash_seeded(cell + side_id, seed);
		bool win = windows > 0.5 && f.x > 0.18 && f.x < 0.82 && f.y > 0.28 && f.y < 0.78
			&& y < half_height * 2.0 - 0.8;
		if (win) {
			float lit = step(0.32 + damage * 0.55, h);
			float flick = step(0.5, fract(sin(time * 23.0 + h * 91.0) * 437.5));
			lit *= mix(1.0, flick, step(0.35, damage) * step(0.75, h));
			vec3 glass = mix(vec3(0.42, 0.6, 0.78), vec3(0.78, 0.88, 0.96), step(0.72, h));
			col = mix(glass, vec3(0.03, 0.04, 0.07), night_amt);
			col = mix(col, vec3(0.05), step(h, damage * 0.7));  // shattered panes
			rough = 0.1;
			vec3 wc = mix(win_col.rgb, vec3(0.55, 0.8, 1.0), step(0.82, hash_seeded(cell + 3.1, seed)));
			em = wc * lit * (0.5 + h * 1.4) * night_amt;
		} else if (windows > 0.5 && f.y < 0.1) {
			col *= 0.7;
		} else if (windows < 0.5 && fract(u / 0.6) < 0.15) {
			// corrugated container walls
			col *= 0.75;
		}
		float scorch = smoothstep(0.4, 1.0, damage) * step(0.55, hash_seeded(floor(vec2(u, y) / 1.3) + 9.0, seed));
		col = mix(col, vec3(0.02), scorch * 0.85);
		em *= 1.0 - scorch;
	} else {
		col *= 0.72;
	}
	albedo = col * (1.0 - damage * 0.35);
	emission = em * 2.2;
	roughness = rough;
}
