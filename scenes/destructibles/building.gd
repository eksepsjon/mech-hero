extends StaticBody3D
## A destructible building. Soaks bullets as cover, shows escalating damage
## (dead windows, scorch, smoke), then collapses into the street in a cloud
## of dust and debris, leaving low rubble behind. `decor` buildings are
## backdrop-only: no collision, no hull.

const SHADER := preload("res://shaders/building.gdshader")
const DECOR_SHADER := preload("res://shaders/building_decor.gdshader")
const MechBuilder := preload("res://scenes/mechs/mech_builder.gd")

const WINDOWLESS := ["container", "barn", "silo"]
const ROOF_COLORS := {
	"house": [Color(0.25, 0.12, 0.1), Color(0.15, 0.17, 0.2), Color(0.3, 0.2, 0.14)],
	"farmhouse": [Color(0.3, 0.1, 0.08)],
	"barn": [Color(0.18, 0.18, 0.2)],
	"cabin": [Color(0.12, 0.16, 0.12)],
}

static var _shared_mat: ShaderMaterial

var size := Vector3(10, 15, 10)
var center := Vector2.ZERO
var base_color := Color(0.25, 0.27, 0.32)
var window_color := Color(1.0, 0.8, 0.5)
var kind := "tower"
var neon := false
var neon_color := Color(1.0, 0.3, 0.7)
var decor := false
var seed_value := 0.0

var rect: Rect2
var max_hp := 100.0
var hp := 100.0
var collapsed := false
var value := 0

var _visual: Node3D
var _mesh: MeshInstance3D
var _shape: CollisionShape3D
var _smoke: CPUParticles3D
var _fade := 0.0
var _damage := 0.0
var _last_fx := 0
var _collapse_t := -1.0


func _ready() -> void:
	if _shared_mat == null:
		_shared_mat = ShaderMaterial.new()
		_shared_mat.shader = SHADER
	_shared_mat.set_shader_parameter("night", FX.night)
	position = Vector3(center.x, 0, center.y)
	rect = Rect2(center - Vector2(size.x, size.z) * 0.5, Vector2(size.x, size.z))
	_visual = Node3D.new()
	add_child(_visual)
	_mesh = MeshInstance3D.new()
	if kind == "silo":
		var cm := CylinderMesh.new()
		cm.top_radius = size.x * 0.5
		cm.bottom_radius = size.x * 0.5
		cm.height = size.y
		cm.radial_segments = 16
		_mesh.mesh = cm
	else:
		var bm := BoxMesh.new()
		bm.size = size
		_mesh.mesh = bm
	_mesh.position.y = size.y * 0.5
	_visual.add_child(_mesh)
	if decor:
		# Skyline filler: plain material uniforms, no per-instance shader slots.
		var m := ShaderMaterial.new()
		m.shader = DECOR_SHADER
		m.set_shader_parameter("base_color", base_color)
		m.set_shader_parameter("window_color", window_color)
		m.set_shader_parameter("height_half", size.y * 0.5)
		m.set_shader_parameter("facade_seed", seed_value)
		m.set_shader_parameter("night", FX.night)
		_mesh.material_override = m
		collision_layer = 0
		collision_mask = 0
		return
	_mesh.material_override = _shared_mat
	_mesh.set_instance_shader_parameter("base_color", base_color)
	var wc := window_color
	wc.a = 0.0 if kind in WINDOWLESS else 1.0
	_mesh.set_instance_shader_parameter("window_color", wc)
	_push_params()
	_add_details()
	collision_layer = 1
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box
	_shape.position.y = size.y * 0.5
	add_child(_shape)
	max_hp = 40.0 + size.x * size.y * size.z * 0.05
	if kind == "container":
		max_hp *= 0.5
	hp = max_hp
	value = int(max_hp) * randi_range(800_000, 1_400_000)
	World.register_building(self)


func _add_details() -> void:
	var top := size.y
	if kind == "container":
		return
	if ROOF_COLORS.has(kind):
		_add_roof()
		return
	if kind == "silo":
		MechBuilder.ball(_visual, size.x * 0.5, Vector3(0, top, 0), FX.mat(base_color.lightened(0.1), 0.6, 0.3),
				Vector3(1, 0.5, 1), 16)
		return
	if kind == "watchtower":
		# Cabin on top and a red aviation light.
		MechBuilder.box(_visual, Vector3(size.x + 2.0, 2.4, size.z + 2.0), Vector3(0, top + 1.2, 0), FX.mat(Color(0.3, 0.2, 0.12), 0.1, 0.8))
		MechBuilder.box(_visual, Vector3(size.x + 1.5, 0.5, size.z + 1.5), Vector3(0, top + 1.2, 0), FX.light_mat(Color(1.0, 0.75, 0.4), 3.0))
		MechBuilder.ball(_visual, 0.4, Vector3(0, top + 3.0, 0), FX.light_mat(Color(1.0, 0.1, 0.1), 6.0))
		return
	var dark := FX.mat(base_color.darkened(0.5), 0.4, 0.6)
	# Roof clutter: AC units, a water tank or an antenna with a blinking light.
	var n := clampi(int(size.x * size.z / 40.0), 1, 4)
	for k in n:
		var p := Vector3(randf_range(-0.35, 0.35) * size.x, top + 0.6, randf_range(-0.35, 0.35) * size.z)
		MechBuilder.box(_visual, Vector3(randf_range(1.2, 2.4), 1.2, randf_range(1.2, 2.4)), p, dark)
	if size.y > 14.0:
		MechBuilder.cyl(_visual, 0.12, 0.2, 5.0, Vector3(size.x * 0.25, top + 2.5, size.z * 0.2), dark)
		MechBuilder.ball(_visual, 0.35, Vector3(size.x * 0.25, top + 5.1, size.z * 0.2), FX.light_mat(Color(1.0, 0.1, 0.1), 6.0))
	elif kind == "shop":
		MechBuilder.cyl(_visual, 1.2, 1.2, 2.0, Vector3(-size.x * 0.25, top + 1.0, -size.z * 0.2), dark)
		# Glowing shop-front awning facing the street.
		MechBuilder.box(_visual, Vector3(size.x * 0.9, 0.4, 0.8), Vector3(0, 3.2, size.z * 0.5 + 0.4), FX.light_mat(neon_color, 2.0))
	if neon:
		# Vertical neon sign on one corner, horizontal strip on the roof edge.
		var side := 1.0 if randf() < 0.5 else -1.0
		var h := minf(size.y * 0.6, 12.0)
		MechBuilder.box(_visual, Vector3(0.4, h, 1.6), Vector3(side * (size.x * 0.5 + 0.2), size.y - h * 0.5 - 1.0, size.z * 0.3), FX.light_mat(neon_color, 5.0))
		MechBuilder.box(_visual, Vector3(size.x, 0.35, 0.35), Vector3(0, top - 0.2, size.z * 0.5 + 0.15), FX.light_mat(neon_color.lerp(Color.WHITE, 0.3), 4.0))


## Pitched roof: a prism along the building's long axis.
func _add_roof() -> void:
	var colors: Array = ROOF_COLORS[kind]
	var roof_color: Color = colors[int(seed_value) % colors.size()]
	var along_z := size.z >= size.x
	var span := size.x if along_z else size.z
	var h := span * (0.55 if kind == "barn" else 0.45)
	var pm := PrismMesh.new()
	pm.size = Vector3(span + 0.8, h, (size.z if along_z else size.x) + 0.8)
	var roof := MeshInstance3D.new()
	roof.mesh = pm
	roof.material_override = FX.mat(roof_color, 0.2, 0.7)
	roof.position.y = size.y + h * 0.5
	roof.rotation.y = 0.0 if along_z else PI * 0.5
	_visual.add_child(roof)
	if kind == "barn":
		# Big doors and a hay-loft light so barns read at a glance.
		MechBuilder.box(_visual, Vector3(size.x * 0.4, size.y * 0.6, 0.2), Vector3(0, size.y * 0.3, size.z * 0.5 + 0.1), FX.mat(Color(0.85, 0.82, 0.75), 0.0, 0.8))
		MechBuilder.box(_visual, Vector3(1.4, 1.0, 0.2), Vector3(0, size.y * 0.8, size.z * 0.5 + 0.1), FX.light_mat(Color(1.0, 0.75, 0.4), 3.0))
	else:
		MechBuilder.box(_visual, Vector3(0.6, h + 1.0, 0.6), Vector3(size.x * 0.25, size.y + h * 0.5 + 0.5, size.z * 0.15), FX.mat(Color(0.25, 0.2, 0.18), 0.0, 0.9))


func take_damage(amount: float, from_player: bool = false) -> void:
	if collapsed or decor:
		return
	if from_player and Game.stats.demolisher > 0:
		amount *= 1.0 + 1.5 * float(Game.stats.demolisher)
	hp -= amount
	var dmg := clampf(1.0 - hp / max_hp, 0.0, 1.0)
	_damage = dmg
	_push_params()
	var now := Time.get_ticks_msec()
	if now - _last_fx > 150:
		_last_fx = now
		var p := Vector3(center.x + randf_range(-0.5, 0.5) * size.x, randf_range(3.0, minf(size.y, 9.0)), center.y + randf_range(-0.5, 0.5) * size.z)
		FX.sparks(p, Color(1.0, 0.7, 0.4), 5)
		if randf() < 0.4:
			World.debris(p, 1, base_color, 0.6, 8.0)
	if dmg > 0.5 and _smoke == null:
		_start_smoke()
	if hp <= 0.0:
		collapse()


func _start_smoke() -> void:
	_smoke = CPUParticles3D.new()
	_smoke.mesh = FX._sphere
	_smoke.material_override = FX._smoke_mat
	_smoke.amount = 14
	_smoke.lifetime = 2.5
	_smoke.direction = Vector3.UP
	_smoke.spread = 15.0
	_smoke.initial_velocity_min = 4.0
	_smoke.initial_velocity_max = 7.0
	_smoke.gravity = Vector3(1.5, 1.0, 0.5)
	_smoke.scale_amount_min = 2.0
	_smoke.scale_amount_max = 4.0
	_smoke.color = Color(0.1, 0.1, 0.11, 0.6).lerp(Color(0.3, 0.3, 0.32, 0.6), 1.0 - FX.night)
	_smoke.color_ramp = FX._fade_ramp
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_smoke.emission_box_extents = Vector3(size.x * 0.3, 0.5, size.z * 0.3)
	_smoke.position.y = size.y
	_smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_smoke)


func collapse() -> void:
	if collapsed:
		return
	collapsed = true
	World.unregister_building(self)
	_shape.set_deferred("disabled", true)
	Game.add_collateral(value)
	_damage = 1.0
	_push_params()
	var big := size.y / 20.0
	var foot := maxf(size.x, size.z)
	FX.dust(Vector3(center.x, 1.0, center.y), foot / 5.0)
	FX.dust(Vector3(center.x, size.y * 0.5, center.y), foot / 7.0)
	FX.shake(0.15 + 0.25 * big)
	World.debris(Vector3(center.x, size.y * 0.6, center.y), int(5 + size.y * 0.5), base_color, 1.0 + big, 14.0)
	World.spawn_shards(center, 2 + int(size.y / 6.0))
	if size.y > 14.0:
		FX.hitstop(0.04)
	if Game.stats.demolisher > 0:
		var r := foot * 0.5 + 10.0
		FX.shockwave(Vector3(center.x, 0.3, center.y), r, Color(1.0, 0.7, 0.4), 0.5)
		for e in World.enemies_in_radius(center, r):
			e.take_damage(40.0 * float(Game.stats.demolisher), false)
	_collapse_t = 0.0
	var tw := create_tween()
	tw.tween_property(_visual, "position:y", -size.y - 2.0, 1.3 + big * 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_finish_collapse)


func _process(delta: float) -> void:
	if _collapse_t >= 0.0:
		_collapse_t += delta
		_visual.position.x = randf_range(-0.4, 0.4)
		_visual.position.z = randf_range(-0.4, 0.4)
		_visual.rotation.z = minf(_collapse_t * 0.05, 0.06)


func _finish_collapse() -> void:
	_collapse_t = -1.0
	_visual.queue_free()
	var rubble := FX.mat(base_color.darkened(0.35), 0.1, 0.95)
	var pile := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(size.x * 0.9, 1.2, size.z * 0.9)
	pile.mesh = pm
	pile.position.y = 0.6
	pile.material_override = rubble
	add_child(pile)
	for k in 6:
		var s := Vector3(randf_range(1.5, 4.0), randf_range(1.0, 2.6), randf_range(1.5, 4.0))
		var p := Vector3(randf_range(-0.4, 0.4) * size.x, s.y * 0.4, randf_range(-0.4, 0.4) * size.z)
		MechBuilder.box(self, s, p, rubble, Vector3(randf_range(-25, 25), randf_range(0, 90), randf_range(-25, 25)))
	if _smoke != null:
		_smoke.position.y = 2.0
		get_tree().create_timer(5.0, false).timeout.connect(_stop_smoke)


func _stop_smoke() -> void:
	if _smoke != null:
		_smoke.emitting = false


## Screen-door fade used by the arena when this building hides the player.
func set_fade(target: float, delta: float) -> void:
	var f := move_toward(_fade, target, delta * 4.0)
	if f != _fade:
		_fade = f
		_push_params()


func _push_params() -> void:
	_mesh.set_instance_shader_parameter("params", Vector4(_damage, size.y * 0.5, seed_value, _fade))
