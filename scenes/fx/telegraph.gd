extends MeshInstance3D
## Ground warning circle that fills up over `duration` and then frees itself.
## With `ring_only` it is a fading shockwave ring instead.

const SHADER := preload("res://shaders/telegraph.gdshader")

var radius := 6.0
var duration := 1.0
var color := Color(1.0, 0.25, 0.3)
var ring_only := false
var auto_free := true
var _t := 0.0
var _mat: ShaderMaterial


func _ready() -> void:
	var m := PlaneMesh.new()
	m.size = Vector2(radius * 2.0, radius * 2.0)
	mesh = m
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("color", color)
	if ring_only:
		_mat.set_shader_parameter("fill_strength", 0.0)
		_mat.set_shader_parameter("energy", 4.0)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _physics_process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / duration, 0.0, 1.0)
	if ring_only:
		_mat.set_shader_parameter("fade", 1.0 - k)
	else:
		_mat.set_shader_parameter("progress", k)
	if auto_free and _t >= duration:
		queue_free()
