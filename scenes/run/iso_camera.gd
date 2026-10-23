extends Camera3D
## Orthographic isometric follow camera with aim lead and trauma-based shake.
## Publishes its ground-plane right/forward vectors to World so input can be
## mapped from screen space to world space.

const PITCH := -35.264
const YAW := 45.0
const DISTANCE := 200.0

var target: Node3D
var zoom := 82.0
var lead := 8.0
var _focus := Vector3.ZERO


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = zoom
	near = 1.0
	far = 800.0
	rotation_degrees = Vector3(PITCH, YAW, 0)
	var r := transform.basis.x
	var f := -transform.basis.z
	World.cam_right = Vector2(r.x, r.z).normalized()
	World.cam_forward = Vector2(f.x, f.z).normalized()


func snap_to(p: Vector3) -> void:
	_focus = Vector3(p.x, 0, p.z)
	_apply(0.0)


func _process(delta: float) -> void:
	if target != null and is_instance_valid(target):
		var want := Vector3(target.global_position.x, 0, target.global_position.z)
		if "aim_dir" in target:
			var a: Vector2 = target.aim_dir
			want += Vector3(a.x, 0, a.y) * lead
		_focus = _focus.lerp(want, 1.0 - exp(-5.0 * delta))
	size = lerpf(size, zoom, 1.0 - exp(-3.0 * delta))
	_apply(delta)


func _apply(_delta: float) -> void:
	global_position = _focus + transform.basis.z * DISTANCE
	var s := FX.trauma * FX.trauma
	h_offset = randf_range(-1.0, 1.0) * s * 3.0
	v_offset = randf_range(-1.0, 1.0) * s * 3.0
