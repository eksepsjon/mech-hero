extends "res://scenes/enemies/enemy_base.gd"
## Turret walker: keeps mid range, strafes, and fires aimed triple bursts.

const BULLET := Color(1.0, 0.2, 0.6)

var _fire_cd := 0.0
var _burst_left := 0
var _burst_t := 0.0
var _strafe := 1.0
var _strafe_t := 0.0


func _configure() -> void:
	kind = "walker"
	max_hp = 60.0
	radius = 4.0
	height = 11.0
	speed = 9.0
	contact_damage = 8.0
	shard_count = 2
	accent = Color(1.0, 0.2, 0.6)
	parts = MechBuilder.build_walker(self, accent)
	model = parts.model
	_fire_cd = randf_range(1.2, 2.6)
	_strafe = 1.0 if randf() < 0.5 else -1.0


func _ai(delta: float) -> void:
	var to := to_player()
	var dist := to.length()
	if dist < 0.1:
		return
	var d := to / dist
	face = d
	var mv := Vector2.ZERO
	if dist > 48.0:
		mv = d
	elif dist < 26.0:
		mv = -d
	else:
		mv = Vector2(-d.y, d.x) * _strafe * 0.7
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe = -_strafe
		_strafe_t = randf_range(1.5, 3.0)
	desired = mv * speed

	_fire_cd -= delta
	# Swell slightly just before a burst as a tell.
	var swell := 1.1 if _fire_cd < 0.5 and _fire_cd > 0.0 else 1.0
	parts.upper.scale = Vector3.ONE * lerpf(parts.upper.scale.x, swell, 0.3)
	if _fire_cd <= 0.0 and dist < 75.0:
		_fire_cd = 2.6
		_burst_left = 3
		_burst_t = 0.0
	if _burst_left > 0:
		_burst_t -= delta
		if _burst_t <= 0.0:
			_burst_t = 0.14
			_burst_left -= 1
			var spread := [-0.3, -0.15, 0.0, 0.15, 0.3] if elite else [-0.2, 0.0, 0.2]
			for a in spread:
				shoot(d.rotated(a), 30.0, 10.0, BULLET)
			FX.muzzle(global_position + Vector3(d.x * 5.0, 7.6, d.y * 5.0), accent)
