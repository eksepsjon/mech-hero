extends "res://scenes/enemies/enemy_base.gd"
## Fast flying kamikaze drone: weaves toward the player and rams for contact damage.

var _weave := 0.0
var _recoil := 0.0


func _configure() -> void:
	kind = "drone"
	max_hp = 18.0
	radius = 2.4
	height = 12.0
	speed = 24.0
	contact_damage = 10.0
	flying = true
	shard_count = 1
	accent = Color(1.0, 0.35, 0.2)
	parts = MechBuilder.build_drone(self, accent)
	model = parts.model
	model.position.y = 10.0
	_weave = randf() * TAU


func _ai(delta: float) -> void:
	_weave += delta * 3.0
	_recoil = maxf(_recoil - delta, 0.0)
	var to := to_player()
	if to.length() > 0.1:
		var d := to.normalized()
		face = d
		var weave := Vector2(-d.y, d.x) * sin(_weave) * 0.6
		desired = (d + weave).normalized() * speed
		if _recoil > 0.0:
			desired = -d * speed * 0.8
	parts.body.position.y = sin(_weave * 1.3) * 0.6
	for r in parts.rotors:
		r.rotation.y += delta * 30.0


func _on_contact() -> void:
	_recoil = 0.45
