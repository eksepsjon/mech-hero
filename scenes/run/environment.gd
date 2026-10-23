extends RefCounted
## Lighting presets per time of day. Day is the bright, saturated Archero-style
## default; sunset and night are used for a few stages for variety.


static func build(time: String = "day", natural: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "Environment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.adjustment_enabled = true
	env.ssao_enabled = RenderingServer.get_current_rendering_method() == "forward_plus"
	env.ssao_radius = 2.0
	env.ssao_intensity = 1.2
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0
	sun.shadow_blur = 1.5
	match time:
		"night":
			env.background_color = Color(0.02, 0.025, 0.06)
			env.ambient_light_color = Color(0.4, 0.45, 0.7)
			env.ambient_light_energy = 0.75 if natural else 0.55
			env.tonemap_mode = Environment.TONE_MAPPER_ACES
			env.tonemap_exposure = 1.1
			env.glow_intensity = 0.9
			env.glow_strength = 1.1
			env.glow_hdr_threshold = 0.9
			env.adjustment_saturation = 1.0
			sun.rotation_degrees = Vector3(-55, -25, 0)
			sun.light_color = Color(0.65, 0.72, 1.0)
			sun.light_energy = 1.3 if natural else 0.9
		"sunset":
			env.background_color = Color(0.95, 0.62, 0.45)
			env.ambient_light_color = Color(0.85, 0.66, 0.62)
			env.ambient_light_energy = 0.6
			env.tonemap_exposure = 1.0
			env.glow_intensity = 0.6
			env.glow_hdr_threshold = 1.4
			env.adjustment_saturation = 1.15
			sun.rotation_degrees = Vector3(-28, -50, 0)
			sun.light_color = Color(1.0, 0.68, 0.45)
			sun.light_energy = 1.4
		_:
			env.background_color = Color(0.55, 0.76, 0.95)
			env.ambient_light_color = Color(0.72, 0.8, 0.95)
			env.ambient_light_energy = 0.7
			env.tonemap_exposure = 1.0
			env.glow_intensity = 0.5
			env.glow_hdr_threshold = 1.6
			env.adjustment_saturation = 1.2
			sun.rotation_degrees = Vector3(-60, -30, 0)
			sun.light_color = Color(1.0, 0.96, 0.88)
			sun.light_energy = 1.5
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	root.add_child(sun)
	return root
