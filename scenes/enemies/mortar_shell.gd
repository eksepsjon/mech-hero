extends Node3D
## Arcing mortar shell with a ground marker that fills until impact.

const Telegraph := preload("res://scenes/fx/telegraph.gd")

var start := Vector3.ZERO
var target := Vector2.ZERO
var duration := 1.3
var blast_radius := 7.0
var damage := 16.0
var _t := 0.0
var _marker


func _ready() -> void:
	var MechBuilder := preload("res://scenes/mechs/mech_builder.gd")
	MechBuilder.ball(self, 0.9, Vector3.ZERO, FX.glow(Color(1.0, 0.55, 0.1), 6.0), Vector3.ONE, 8)
	_marker = Telegraph.new()
	_marker.radius = blast_radius
	_marker.duration = duration
	_marker.color = Color(1.0, 0.45, 0.1)
	_marker.top_level = true
	add_child(_marker)
	_marker.global_position = Vector3(target.x, 0.2, target.y)
	global_position = start


func _physics_process(delta: float) -> void:
	_t += delta
	var u := clampf(_t / duration, 0.0, 1.0)
	var flat := start.lerp(Vector3(target.x, 0.0, target.y), u)
	global_position = flat + Vector3(0, 40.0 * 4.0 * u * (1.0 - u), 0)
	if u >= 1.0:
		World.explode(target, blast_radius, damage, Bullets.TEAM_ENEMY)
		queue_free()
