extends Node3D
## Energy shard dropped by wreckage. Pops out, then homes in on the player to
## repair a little hull. After a stage is cleared every shard is magnetised.

var _vel := Vector3.ZERO
var _t := 0.0
var _mesh: MeshInstance3D


func _ready() -> void:
	World.shard_count += 1
	_mesh = MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.6
	m.height = 1.6
	m.radial_segments = 4
	m.rings = 2
	_mesh.mesh = m
	_mesh.material_override = FX.glow(Color(0.3, 1.0, 0.6), 5.0)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	_vel = Vector3(randf_range(-9, 9), randf_range(12, 20), randf_range(-9, 9))


func _exit_tree() -> void:
	World.shard_count -= 1


func _physics_process(delta: float) -> void:
	_t += delta
	_mesh.rotation.y += delta * 4.0
	if World.player_alive() and _t > 0.6:
		var target: Vector3 = World.player.global_position + Vector3(0, 6, 0)
		var to := target - global_position
		var d := to.length()
		if d < 3.5:
			Game.heal(1.5)
			FX.burst(global_position, Color(0.3, 1.0, 0.6), 4, 6.0, 0.2, 0.4, 0.0, 180.0, 4.0)
			queue_free()
			return
		if d < 20.0 or World.magnet:
			_vel = _vel.lerp(to / d * (40.0 + 50.0 * minf(_t, 2.0)), 1.0 - exp(-6.0 * delta))
			global_position += _vel * delta
			return
	_vel.y -= 40.0 * delta
	_vel.x *= 0.98
	_vel.z *= 0.98
	global_position += _vel * delta
	if global_position.y < 1.0:
		global_position.y = 1.0
		_vel.y = absf(_vel.y) * 0.3
	if _t > 25.0:
		queue_free()
