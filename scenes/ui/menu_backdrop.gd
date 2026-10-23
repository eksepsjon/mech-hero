extends Node3D
## Attract mode behind the title: a city district with traffic, slowly panned,
## with buildings occasionally blowing up in the distance.

const Env := preload("res://scenes/run/environment.gd")
const Arena := preload("res://scenes/arena/arena.gd")

var _cam: Camera3D
var _t := 0.0
var _boom := 2.0


func _ready() -> void:
	FX.set_time("day")
	var arena = Arena.new()
	arena.variant = ["downtown", "harbor", "highway", "mixed", "rural", "forest"][randi() % 6]
	add_child(Env.build("day", arena.variant in ["rural", "forest"]))
	arena.gen_seed = randi()
	add_child(arena)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 90.0
	_cam.far = 800.0
	_cam.rotation_degrees = Vector3(-35.264, 45.0, 0)
	add_child(_cam)
	_cam.make_current()


func _process(delta: float) -> void:
	_t += delta
	var focus := Vector3(sin(_t * 0.07) * 40.0, 0, cos(_t * 0.05) * 30.0)
	_cam.global_position = focus + _cam.transform.basis.z * 200.0
	_cam.h_offset = randf_range(-1.0, 1.0) * FX.trauma * FX.trauma * 3.0
	_boom -= delta
	if _boom <= 0.0 and not World.buildings.is_empty():
		_boom = randf_range(2.5, 4.5)
		var b = World.buildings[randi() % World.buildings.size()]
		b.take_damage(1e6)
