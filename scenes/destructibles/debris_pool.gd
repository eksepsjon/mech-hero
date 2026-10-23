extends Node3D
## Pooled rigid-body rubble chunks thrown out by collapses, explosions and crushes.

const MAX_CHUNKS := 150

var _free: Array = []
var _active: Array = []
var _box_mesh := BoxMesh.new()


func _make() -> Dictionary:
	var b := RigidBody3D.new()
	b.collision_layer = 16
	b.collision_mask = 32
	b.mass = 1.0
	b.freeze = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	shape.shape = box
	b.add_child(shape)
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh
	b.add_child(mi)
	add_child(b)
	return {"body": b, "shape": box, "mesh": mi, "life": 0.0, "dims": Vector3.ONE}


func spawn(pos: Vector3, count: int, color: Color, size: float, force: float) -> void:
	var m := FX.mat(color.darkened(0.15), 0.1, 0.9)
	for k in count:
		var item: Dictionary
		if not _free.is_empty():
			item = _free.pop_back()
		elif _active.size() < MAX_CHUNKS:
			item = _make()
		else:
			item = _active.pop_front()
		var s := size * randf_range(0.5, 1.2)
		var dims := Vector3(s * randf_range(0.6, 1.4), s * randf_range(0.5, 1.1), s * randf_range(0.6, 1.4))
		item.dims = dims
		item.shape.size = dims
		item.mesh.scale = dims
		item.mesh.material_override = m
		item.life = randf_range(2.5, 4.0)
		var b: RigidBody3D = item.body
		b.visible = true
		b.global_position = pos + Vector3(randf_range(-1, 1) * size * 2.0, randf_range(0.0, size * 2.0), randf_range(-1, 1) * size * 2.0)
		b.freeze = false
		b.linear_velocity = Vector3(randf_range(-1, 1), randf_range(0.6, 1.4), randf_range(-1, 1)).normalized() * force * randf_range(0.5, 1.2)
		b.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
		_active.append(item)


func _physics_process(delta: float) -> void:
	for i in range(_active.size() - 1, -1, -1):
		var item: Dictionary = _active[i]
		item.life -= delta
		if item.life < 0.5:
			item.mesh.scale = item.dims * maxf(item.life / 0.5, 0.01)
		if item.life <= 0.0:
			var b: RigidBody3D = item.body
			b.freeze = true
			b.visible = false
			b.global_position = Vector3(0, -50, 0)
			_active.remove_at(i)
			_free.append(item)


func active_count() -> int:
	return _active.size()
