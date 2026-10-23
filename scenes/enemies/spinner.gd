extends "res://scenes/enemies/enemy_base.gd"
## Spinner fortress: barely moves, sprays rotating spiral bullet arms in bursts.

const BULLET := Color(0.75, 0.3, 1.0)

var _angle := 0.0
var _emit_t := 0.0
var _phase_t := 2.0
var _active := false
var _dir := 1.0


func _configure() -> void:
	kind = "spinner"
	max_hp = 130.0
	radius = 4.6
	height = 10.0
	speed = 4.0
	contact_damage = 10.0
	heavy = true
	shard_count = 4
	accent = Color(0.75, 0.3, 1.0)
	parts = MechBuilder.build_spinner(self, accent)
	model = parts.model
	_angle = randf() * TAU
	_phase_t = randf_range(1.0, 2.0)


func _ai(delta: float) -> void:
	var to := to_player()
	var dist := to.length()
	if dist > 0.1:
		var d := to / dist
		desired = (d if dist > 50.0 else Vector2(-d.y, d.x) * 0.5) * speed
	_phase_t -= delta
	if _phase_t <= 0.0:
		_active = not _active
		_phase_t = 3.2 if _active else 1.6
		if _active:
			_dir = -_dir
	parts.ring.rotation.y += delta * (5.0 if _active else 0.8) * _dir
	if not _active:
		return
	_emit_t -= delta
	var arms := 6 if elite else 4
	while _emit_t <= 0.0:
		_emit_t += 0.1
		for k in arms:
			shoot(Vector2.from_angle(_angle + TAU * k / arms), 19.0, 8.0, BULLET, 1.0)
		_angle += 0.2 * _dir
