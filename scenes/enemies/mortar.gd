extends "res://scenes/enemies/enemy_base.gd"
## Mortar crawler: hangs back and lobs shells that land on marked circles.

const Shell := preload("res://scenes/enemies/mortar_shell.gd")

var _fire_cd := 0.0
var _strafe := 1.0


func _configure() -> void:
	kind = "mortar"
	max_hp = 85.0
	radius = 4.2
	height = 10.0
	speed = 7.0
	contact_damage = 8.0
	heavy = true
	shard_count = 3
	accent = Color(1.0, 0.55, 0.1)
	parts = MechBuilder.build_mortar(self, accent)
	model = parts.model
	_fire_cd = randf_range(1.5, 3.0)
	_strafe = 1.0 if randf() < 0.5 else -1.0


func _ai(delta: float) -> void:
	var to := to_player()
	var dist := to.length()
	if dist < 0.1:
		return
	var d := to / dist
	face = d
	if dist > 62.0:
		desired = d * speed
	elif dist < 38.0:
		desired = -d * speed
	else:
		desired = Vector2(-d.y, d.x) * _strafe * speed * 0.4
	_fire_cd -= delta
	if _fire_cd <= 0.0 and dist < 90.0:
		_fire_cd = 3.4
		_fire(to)


func _fire(to: Vector2) -> void:
	var target := pos2() + to
	var lead := Vector2.ZERO
	if World.player_alive():
		lead = Vector2(World.player.velocity.x, World.player.velocity.z) * 0.6
	var n := 5 if elite else 3
	for k in n:
		var s = Shell.new()
		s.start = global_position + Vector3(0, 11, 0)
		s.target = target + lead + (Vector2.ZERO if k == 0 else Vector2(randf_range(-8, 8), randf_range(-8, 8)))
		s.duration = 1.3 + k * 0.15
		World.arena.add_child(s)
	parts.tube.position.y = 5.2
	parts.tube.create_tween().tween_property(parts.tube, "position:y", 6.0, 0.4)
	FX.burst(global_position + Vector3(0, 12, 0), accent, 12, 14.0, 0.4, 1.2, -10.0, 40.0, 4.0)
	FX.smoke(global_position + Vector3(0, 12, 0), 0.6)
