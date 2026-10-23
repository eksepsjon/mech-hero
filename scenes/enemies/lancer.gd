extends "res://scenes/enemies/enemy_base.gd"
## Lancer: telegraphs a charge line, then rams straight through buildings.

enum State { APPROACH, WINDUP, CHARGE, RECOVER }

const CHARGE_SPEED := 75.0

var _state := State.APPROACH
var _t := 1.0
var _charge_dir := Vector2.ZERO
var _hit_player := false
var _line: MeshInstance3D
var _line_mat: ShaderMaterial


func _configure() -> void:
	kind = "lancer"
	max_hp = 75.0
	radius = 3.6
	height = 12.0
	speed = 15.0
	contact_damage = 0.0
	shard_count = 2
	accent = Color(1.0, 0.15, 0.2)
	parts = MechBuilder.build_lancer(self, accent)
	model = parts.model
	_line = MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(2.4, 0.1, 60.0)
	_line.mesh = m
	_line_mat = FX.glow_mix(accent, 1.4, 0.0)
	_line.material_override = _line_mat
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_line.top_level = true
	_line.visible = false
	add_child(_line)


func _ai(delta: float) -> void:
	_t -= delta
	var to := to_player()
	var dist := to.length()
	var d := to / dist if dist > 0.1 else face
	match _state:
		State.APPROACH:
			face = d
			desired = d * speed
			if dist < 50.0 and _t <= 0.0:
				_state = State.WINDUP
				_t = 0.9
				_charge_dir = d
				_line.visible = true
		State.WINDUP:
			if _t > 0.35:
				_charge_dir = d
			face = _charge_dir
			_line_mat.set_shader_parameter("alpha", 0.25 + 0.35 * sin(_t * 30.0) ** 2)
			var c := pos2() + _charge_dir * 30.0
			_line.global_position = Vector3(c.x, 0.25, c.y)
			_line.rotation = Vector3(0, atan2(-_charge_dir.x, -_charge_dir.y), 0)
			parts.lance.position.z = 1.5 * (1.0 - _t / 0.9)
			if _t <= 0.0:
				_state = State.CHARGE
				_t = 0.75
				_hit_player = false
				_line.visible = false
				collision_mask = 2
				FX.dust(global_position, 1.2)
		State.CHARGE:
			face = _charge_dir
			desired = _charge_dir * CHARGE_SPEED
			parts.lance.position.z = -1.0
			_charge_effects()
			if _t <= 0.0 or is_on_wall():
				_state = State.RECOVER
				_t = 1.1
				collision_mask = 1 | 2
				FX.shake(0.1)
		State.RECOVER:
			parts.lance.position.z = lerpf(parts.lance.position.z, 0.0, 0.1)
			if _t <= 0.0:
				_state = State.APPROACH
				_t = randf_range(0.8, 1.6)


func _charge_effects() -> void:
	var p := pos2()
	var r := radius + 0.5
	for b in World.buildings_in_rect(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0)):
		b.take_damage(400.0)
	if Engine.get_physics_frames() % 3 == 0:
		FX.dust(global_position, 0.7)
	if not _hit_player and World.player_alive():
		var rr: float = radius + World.player.hit_radius + 1.0
		if p.distance_squared_to(World.xz(World.player.global_position)) < rr * rr:
			if World.player.take_damage(24.0):
				_hit_player = true


func die() -> void:
	_line.visible = false
	super.die()
