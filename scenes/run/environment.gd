extends RefCounted
## Night-time lighting setup: HDR glow for the neon look, moonlight with shadows.


static func build(boss: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "Environment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.02, 0.05) if boss else Color(0.02, 0.025, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.35, 0.5) if boss else Color(0.4, 0.45, 0.7)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.1
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.ssao_enabled = RenderingServer.get_current_rendering_method() == "forward_plus"
	env.ssao_radius = 2.0
	env.ssao_intensity = 1.5
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55, -25, 0)
	moon.light_color = Color(1.0, 0.5, 0.55) if boss else Color(0.65, 0.72, 1.0)
	moon.light_energy = 0.9
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 260.0
	root.add_child(moon)
	return root
