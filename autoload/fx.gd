extends Node
## Shared visual feedback: cached materials, particle bursts, light flashes,
## shockwaves, lightning, damage numbers, screen shake and hit-stop.

const PARTICLE_SHADER := preload("res://shaders/particle_add.gdshader")
const GLOW_SHADER := preload("res://shaders/glow_add.gdshader")
const GLOW_MIX_SHADER := preload("res://shaders/glow_mix.gdshader")
const Telegraph := preload("res://scenes/fx/telegraph.gd")

const MAX_LIGHTS := 8
const MAX_NUMBERS := 40
const MAX_BURSTS := 110

var trauma := 0.0
## 0 = day, 1 = night. Set per stage via set_time(); drives signs, windows, ground.
var night := 0.0
var _outline_mat: StandardMaterial3D
var flash_mat: StandardMaterial3D
var flash_mat_soft: StandardMaterial3D
var _mats: Dictionary = {}
var _particle_mats: Dictionary = {}
var _smoke_mat: StandardMaterial3D
var _sphere: SphereMesh
var _cube: BoxMesh
var _fade_ramp: Gradient
var _lights := 0
var _numbers := 0
var _bursts := 0
var _hitstop := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sphere = SphereMesh.new()
	_sphere.radius = 0.5
	_sphere.height = 1.0
	_sphere.radial_segments = 6
	_sphere.rings = 3
	_cube = BoxMesh.new()
	_fade_ramp = Gradient.new()
	_fade_ramp.set_color(0, Color(1, 1, 1, 1))
	_fade_ramp.set_color(1, Color(1, 1, 1, 0))
	_smoke_mat = StandardMaterial3D.new()
	_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_smoke_mat.vertex_color_use_as_albedo = true
	_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_smoke_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	# Inverted-hull outline used as a next pass on mech and car materials.
	_outline_mat = StandardMaterial3D.new()
	_outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_outline_mat.grow = true
	_outline_mat.grow_amount = 0.12
	_outline_mat.albedo_color = Color(0.08, 0.08, 0.12)
	# Additive overlay: brightens whatever it covers instead of painting it white.
	flash_mat = StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flash_mat.albedo_color = Color(0.35, 0.35, 0.38)
	flash_mat_soft = flash_mat.duplicate()
	flash_mat_soft.albedo_color = Color(0.12, 0.1, 0.14)


func _process(delta: float) -> void:
	trauma = maxf(trauma - delta * 1.6, 0.0)


# --- camera feel --------------------------------------------------------------

func shake(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


func hitstop(duration: float) -> void:
	if _hitstop:
		return
	_hitstop = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop = false


# --- time of day -----------------------------------------------------------------

const TIMES := {"day": 0.0, "sunset": 0.35, "night": 1.0}


func set_time(time: String) -> void:
	night = TIMES.get(time, 0.0)


# --- materials ----------------------------------------------------------------

## Cached cel-shaded material, optionally with a dark outline pass.
func mat(color: Color, metallic: float = 0.3, roughness: float = 0.6, outline: bool = false) -> StandardMaterial3D:
	var key := "m%s|%.2f|%.2f|%s" % [color.to_html(), metallic, roughness, outline]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic * 0.4
	m.roughness = roughness
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	if outline:
		m.next_pass = _outline_mat
	_mats[key] = m
	return m


## Light fixture / sign: glows at night, a plain bright colour by day.
func light_mat(color: Color, energy: float = 4.0) -> StandardMaterial3D:
	if night >= 0.5:
		return glow(color, energy)
	var key := "s%s" % color.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := mat(color.lerp(Color.WHITE, 0.15), 0.0, 0.5).duplicate()
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.25
	_mats[key] = m
	return m


## Cached emissive material; energy above ~1 blooms.
func glow(color: Color, energy: float = 4.0) -> StandardMaterial3D:
	var key := "g%s|%.2f" % [color.to_html(), energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color * 0.3
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_mats[key] = m
	return m


## New (uncached) additive material, for things that fade individually.
func glow_add(color: Color, energy: float = 3.0, alpha: float = 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GLOW_SHADER
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("alpha", alpha)
	return m


## New alpha-blended material for telegraph lines (reads on bright ground).
func glow_mix(color: Color, energy: float = 1.5, alpha: float = 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GLOW_MIX_SHADER
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("alpha", alpha)
	return m


func _particle_mat(energy: float) -> ShaderMaterial:
	var key := snappedf(energy, 0.5)
	if _particle_mats.has(key):
		return _particle_mats[key]
	var m := ShaderMaterial.new()
	m.shader = PARTICLE_SHADER
	m.set_shader_parameter("energy", key)
	_particle_mats[key] = m
	return m


# --- spawning helpers -----------------------------------------------------------

func _parent() -> Node:
	if World.arena != null and is_instance_valid(World.arena):
		return World.arena
	return self


func _attach(node: Node3D, pos: Vector3) -> void:
	_parent().add_child(node)
	node.global_position = pos


func burst(pos: Vector3, color: Color, amount: int, speed: float, life: float, size: float,
		gravity: float = -25.0, spread: float = 180.0, energy: float = 3.0, smoke: bool = false) -> void:
	if _bursts >= MAX_BURSTS:
		return
	var p := CPUParticles3D.new()
	p.mesh = _sphere
	p.material_override = _smoke_mat if smoke else _particle_mat(energy)
	p.amount = maxi(amount, 1)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.92
	p.randomness = 0.5
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.damping_min = 1.0
	p.damping_max = 5.0
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	p.color = color
	p.color_ramp = _fade_ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_attach(p, pos)
	p.emitting = true
	_bursts += 1
	p.tree_exited.connect(_on_burst_exit)
	get_tree().create_timer(life + 0.2, false).timeout.connect(p.queue_free)


func _on_burst_exit() -> void:
	_bursts -= 1


func hit_spark(pos: Vector3, color: Color) -> void:
	burst(pos, color.lerp(Color.WHITE, 0.3), 5, 18.0, 0.25, 0.5, -10.0, 180.0, 4.0)


func sparks(pos: Vector3, color: Color, amount: int = 10) -> void:
	burst(pos, color, amount, 22.0, 0.45, 0.45, -35.0, 120.0, 5.0)


func dust(pos: Vector3, scale: float = 1.0) -> void:
	burst(pos + Vector3(0, 0.5, 0), Color(0.42, 0.4, 0.42, 0.55), int(8 * scale) + 4, 9.0 * scale,
			1.3, 3.0 * scale, 1.5, 85.0, 1.0, true)


func smoke(pos: Vector3, scale: float = 1.0) -> void:
	burst(pos, Color(0.12, 0.11, 0.12, 0.7).lerp(Color(0.35, 0.34, 0.36, 0.7), 1.0 - night), int(6 * scale) + 4, 7.0 * scale, 1.8,
			3.5 * scale, 4.0, 60.0, 1.0, true)


func muzzle(pos: Vector3, color: Color) -> void:
	burst(pos, color, 4, 9.0, 0.12, 0.9, 0.0, 180.0, 5.0)


func explosion(pos: Vector3, scale: float = 1.0) -> void:
	burst(pos, Color(1.0, 0.5, 0.12), int(18 * scale) + 8, 20.0 * scale, 0.55, 2.4 * scale, -4.0, 180.0, 4.0)
	burst(pos, Color(1.0, 0.9, 0.6), 10, 34.0 * scale, 0.4, 0.6 * scale, -40.0, 180.0, 6.0)
	smoke(pos + Vector3(0, 1, 0), scale)
	flash(pos + Vector3(0, 3, 0), Color(1.0, 0.6, 0.25), 14.0 * scale, 0.3)
	shockwave(Vector3(pos.x, 0.3, pos.z), 6.0 * scale, Color(1.0, 0.55, 0.2), 0.35)
	shake(0.12 * scale)


func flash(pos: Vector3, color: Color, light_range: float, life: float) -> void:
	if _lights >= MAX_LIGHTS:
		return
	var l := OmniLight3D.new()
	l.light_color = color
	l.omni_range = light_range
	l.light_energy = 6.0
	_attach(l, pos)
	_lights += 1
	l.tree_exited.connect(_on_light_exit)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life)
	tw.tween_callback(l.queue_free)


func _on_light_exit() -> void:
	_lights -= 1


func shockwave(pos: Vector3, radius: float, color: Color, life: float) -> void:
	var t = Telegraph.new()
	t.radius = 1.0
	t.duration = life
	t.color = color
	t.ring_only = true
	_attach(t, pos)
	var tw := t.create_tween()
	tw.tween_property(t, "scale", Vector3(radius, 1.0, radius), life).from(Vector3(0.2, 1.0, 0.2)) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func lightning(a: Vector3, b: Vector3, color: Color) -> void:
	var pts: Array = [a]
	for k in 3:
		pts.append(a.lerp(b, (k + 1) / 4.0) + Vector3(randf_range(-1.5, 1.5), randf_range(-1.0, 1.0), randf_range(-1.5, 1.5)))
	pts.append(b)
	for k in pts.size() - 1:
		beam_segment(pts[k], pts[k + 1], color, 0.45, 0.15)
	burst(b, color, 6, 14.0, 0.2, 0.5, 0.0, 180.0, 5.0)


func beam_segment(a: Vector3, b: Vector3, color: Color, width: float, life: float) -> void:
	var d := b - a
	if d.length() < 0.05:
		return
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(width, width, d.length())
	mi.mesh = m
	var mat_ := glow_add(color, 6.0)
	mi.material_override = mat_
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_parent().add_child(mi)
	var up := Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT
	mi.global_transform = Transform3D(Basis.looking_at(d, up), (a + b) * 0.5)
	var tw := mi.create_tween()
	tw.tween_method(_set_alpha.bind(mat_), 1.0, 0.0, life)
	tw.tween_callback(mi.queue_free)


func _set_alpha(value: float, m: ShaderMaterial) -> void:
	m.set_shader_parameter("alpha", value)


func damage_number(pos: Vector3, value: float, crit: bool) -> void:
	if _numbers >= MAX_NUMBERS:
		return
	var l := Label3D.new()
	l.text = str(int(round(value))) + ("!" if crit else "")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 76 if crit else 52
	l.outline_size = 14
	l.modulate = Color(1.0, 0.85, 0.2) if crit else Color(1, 1, 1)
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.pixel_size = 0.05
	_attach(l, pos + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)))
	_numbers += 1
	l.tree_exited.connect(_on_number_exit)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 5.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.35)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.3).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)


func _on_number_exit() -> void:
	_numbers -= 1
