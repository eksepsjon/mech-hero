extends "res://scenes/enemies/enemy_base.gd"
## Leviathan, the stage 10 kaiju. Rises out of the city, walks straight through
## buildings, and cycles bullet patterns that escalate over three phases:
##   1) radial rings, aimed fans, stomp shockwave
##   2) + spiral arms and drone summons
##   3) enraged: sweeping laser and dense rings

const Telegraph := preload("res://scenes/fx/telegraph.gd")
const PURPLE := Color(0.85, 0.2, 1.0)
const RED := Color(1.0, 0.15, 0.3)
const PATTERNS := {
	1: [["ring", 0.7], ["ring", 0.7], ["fan", 0.9], ["ring", 0.7], ["stomp", 2.2], ["fan", 0.8], ["fan", 1.2]],
	2: [["spiral", 3.6], ["fan", 0.7], ["summon", 1.0], ["ring", 0.6], ["ring", 0.6], ["stomp", 2.0], ["fan", 0.8]],
	3: [["laser", 4.4], ["ring", 0.45], ["ring", 0.45], ["ring", 0.45], ["stomp", 1.8], ["spiral", 3.0], ["fan", 0.6], ["fan", 0.6]],
}

var phase := 1
var _rising := false
var _step := 0
var _t := 2.0
var _invuln := 0.0
var _stomp_t := 0.0
var _spiral_t := 0.0
var _spiral_emit := 0.0
var _spiral_angle := 0.0
var _step_t := 0.0
var _laser_state := 0
var _laser_t := 0.0
var _laser_angle := 0.0
var _laser_sweep := 1.0
var _laser_tele: MeshInstance3D
var _laser_beam: MeshInstance3D
var _laser_mat: ShaderMaterial


func _configure() -> void:
	kind = "leviathan"
	max_hp = 2600.0
	radius = 11.0
	height = 32.0
	speed = 6.0
	contact_damage = 30.0
	heavy = true
	flying = false
	shard_count = 30
	accent = PURPLE
	parts = MechBuilder.build_leviathan(self)
	model = parts.model
	model.scale = Vector3.ONE * 1.15
	# A huge model under constant fire would read as a white blob with the normal flash.
	flash_material = FX.flash_mat_soft
	_laser_tele = _make_beam(Vector3(0.8, 0.1, 150.0), FX.glow_add(RED, 3.0, 0.5))
	_laser_mat = FX.glow_add(Color(1.0, 0.4, 0.9), 5.0, 0.9)
	_laser_beam = _make_beam(Vector3(4.5, 4.5, 150.0), _laser_mat)


func _ready() -> void:
	super._ready()
	# The kaiju wades through the city instead of colliding with it.
	collision_mask = 2


func _make_beam(size: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	mi.visible = false
	add_child(mi)
	return mi


## Emerges from below the streets with a long rumble.
func begin_rise() -> void:
	_rising = true
	targetable = false
	model.position.y = -45.0
	var tw := create_tween()
	tw.tween_property(model, "position:y", 0.0, 3.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_risen)
	var r := radius + 4.0
	var p := pos2()
	for b in World.buildings_in_rect(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0)):
		b.take_damage(99999.0)
	World.arena.crush_props_in(p, r, false)


func _risen() -> void:
	_rising = false
	targetable = true
	FX.shake(0.7)
	FX.shockwave(global_position + Vector3(0, 0.3, 0), 40.0, PURPLE, 0.8)
	_ring(40, 18.0, 0.0)


func _physics_process(delta: float) -> void:
	if _rising:
		FX.shake(0.06)
		if Engine.get_physics_frames() % 6 == 0:
			FX.dust(global_position + Vector3(randf_range(-12, 12), 0, randf_range(-12, 12)), 2.0)
		return
	super._physics_process(delta)


func _ai(delta: float) -> void:
	_invuln = maxf(_invuln - delta, 0.0)
	var to := to_player()
	var dist := to.length()
	var d := to / dist if dist > 0.1 else face
	face = d
	var spd := speed * (1.6 if phase == 3 else 1.0)
	if dist > 26.0 and _laser_state == 0:
		desired = d * spd
	_wade(delta)
	_animate_kaiju(delta)

	var ratio := hp / max_hp
	if phase == 1 and ratio < 0.66:
		_enter_phase(2)
	elif phase == 2 and ratio < 0.33:
		_enter_phase(3)
	if _invuln > 0.0:
		return

	if _stomp_t > 0.0:
		_stomp_t -= delta
		if _stomp_t <= 0.0:
			_stomp()
	if _spiral_t > 0.0:
		_spiral_t -= delta
		_spiral_emit -= delta
		while _spiral_emit <= 0.0:
			_spiral_emit += 0.07
			var arms := 5 if phase < 3 else 6
			for k in arms:
				shoot(Vector2.from_angle(_spiral_angle + TAU * k / arms), 17.0, 11.0, PURPLE, 1.3)
			_spiral_angle += 0.13
	_update_laser(delta, d)

	_t -= delta
	if _t <= 0.0:
		var steps: Array = PATTERNS[phase]
		var step: Array = steps[_step % steps.size()]
		_step += 1
		_t = step[1]
		_do(step[0], d)


func _do(action: String, d: Vector2) -> void:
	match action:
		"ring":
			_ring(30 if phase < 3 else 40, 22.0, _step * 0.13)
		"fan":
			var n := 9 if phase < 3 else 13
			for k in n:
				shoot(d.rotated((k - (n - 1) * 0.5) * 0.11), 30.0, 12.0, RED, 1.4)
		"stomp":
			_stomp_t = 0.9
			var t = Telegraph.new()
			t.radius = 22.0
			t.duration = 0.9
			t.color = RED
			World.arena.add_child(t)
			t.global_position = global_position + Vector3(0, 0.3, 0)
		"spiral":
			_spiral_t = 3.0
		"summon":
			if World.run != null:
				for k in 3:
					var p := pos2() + Vector2.from_angle(randf() * TAU) * 20.0
					World.run.spawn_enemy("drone", p, 0.2 * k)
		"laser":
			_laser_state = 1
			_laser_t = 1.0
			_laser_sweep = 1.0 if randf() < 0.5 else -1.0
			_laser_angle = d.angle() - _laser_sweep * 1.1


func _ring(n: int, spd: float, offset: float) -> void:
	for k in n:
		shoot(Vector2.from_angle(offset + TAU * k / n), spd, 12.0, PURPLE, 1.4)


func _stomp() -> void:
	FX.shake(0.6)
	FX.hitstop(0.05)
	World.explode(pos2(), 22.0, 25.0, Bullets.TEAM_ENEMY, 2.5)
	FX.shockwave(global_position + Vector3(0, 0.3, 0), 30.0, RED, 0.6)
	_ring(36, 13.0, 0.0)


func _update_laser(delta: float, _d: Vector2) -> void:
	if _laser_state == 0:
		return
	_laser_t -= delta
	var dir := Vector2.from_angle(_laser_angle)
	var origin := pos2() + dir * 8.0
	var yaw := atan2(-dir.x, -dir.y)
	var center := origin + dir * 75.0
	if _laser_state == 1:
		_laser_tele.visible = true
		_laser_tele.global_position = Vector3(center.x, 0.3, center.y)
		_laser_tele.rotation = Vector3(0, yaw, 0)
		if _laser_t <= 0.0:
			_laser_state = 2
			_laser_t = 2.4
			_laser_tele.visible = false
			_laser_beam.visible = true
			FX.shake(0.4)
	elif _laser_state == 2:
		_laser_angle += _laser_sweep * (2.2 / 2.4) * delta
		_laser_beam.global_position = Vector3(center.x, 8.0, center.y)
		_laser_beam.rotation = Vector3(0, yaw, 0)
		_laser_mat.set_shader_parameter("alpha", 0.7 + 0.3 * sin(_laser_t * 40.0))
		FX.shake(0.05)
		# Burn everything along the beam.
		for k in range(0, 30):
			var p := origin + dir * (k * 5.0)
			for b in World.buildings_at(p):
				if b.rect.has_point(p):
					b.take_damage(900.0 * delta)
			if k % 2 == 0:
				World.arena.crush_props_in(p, 3.0, false)
		if Engine.get_physics_frames() % 3 == 0:
			var hit := origin + dir * randf_range(10.0, 140.0)
			FX.sparks(Vector3(hit.x, 1.0, hit.y), Color(1.0, 0.5, 0.9), 6)
		if World.player_alive():
			var pp := World.xz(World.player.global_position)
			var rel := pp - origin
			var along := rel.dot(dir)
			if along > 0.0 and along < 150.0 and absf(rel.cross(dir)) < 2.5 + World.player.hit_radius:
				World.player.take_damage(22.0)
		if _laser_t <= 0.0:
			_laser_state = 0
			_laser_beam.visible = false


func _enter_phase(p: int) -> void:
	phase = p
	_step = 0
	_t = 1.6
	_invuln = 1.5
	_spiral_t = 0.0
	_laser_state = 0
	_laser_beam.visible = false
	_laser_tele.visible = false
	FX.shake(0.8)
	FX.shockwave(global_position + Vector3(0, 0.3, 0), 45.0, PURPLE if p == 2 else RED, 0.9)
	_ring(48, 16.0, 0.0)
	if World.run != null:
		World.run.hud.show_banner("LEVIATHAN ENRAGED" if p == 3 else "LEVIATHAN EVOLVING", RED, 1.6)


func take_damage(amount: float, crit: bool = false, show_number: bool = true) -> void:
	if _invuln > 0.0 or _rising:
		return
	super.take_damage(amount, crit, show_number)


func _wade(delta: float) -> void:
	var p := pos2()
	var r := radius + 1.5
	for b in World.buildings_in_rect(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0)):
		b.take_damage(700.0 * delta)
	if World.arena != null:
		World.arena.crush_props_in(p, radius, false)


var _stride := 0.0
func _animate_kaiju(delta: float) -> void:
	var moving := velocity.length() > 1.0
	if moving:
		var before := sin(_stride)
		_stride += delta * 2.4 * (1.6 if phase == 3 else 1.0)
		if signf(sin(_stride)) != signf(before):
			FX.shake(0.18)
			FX.dust(global_position + Vector3(face.x * 8.0, 0, face.y * 8.0), 2.0)
	var s := sin(_stride)
	var legs: Array = parts.legs
	for k in legs.size():
		var leg: Node3D = legs[k]
		leg.rotation.x = s * 0.3 * (1.0 if k % 3 == 0 else -1.0)
	parts.body.rotation.z = s * 0.04
	parts.head.rotation.x = sin(_stride * 0.5) * 0.08 - (0.25 if _laser_state > 0 else 0.0)
	var tail: Array = parts.tail
	for k in tail.size():
		var seg: Node3D = tail[k]
		seg.rotation.y = sin(_stride * 0.7 - k * 0.6) * 0.18


func _animate(delta: float) -> void:
	if face.length() > 0.01:
		var turn := 1.5 if _laser_state == 0 else 0.4
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-face.x, -face.y), 1.0 - exp(-turn * delta))


func die() -> void:
	if not alive:
		return
	alive = false
	World.enemies.erase(self)
	_laser_beam.visible = false
	_laser_tele.visible = false
	Game.on_enemy_killed(self)
	World.spawn_shards(pos2(), shard_count)
	FX.hitstop(0.2)
	FX.shake(1.0)
	for k in 10:
		get_tree().create_timer(0.15 * k, false).timeout.connect(_death_blast)
	var tw := create_tween()
	tw.tween_property(model, "rotation:z", 0.6, 2.0).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(model, "position:y", -30.0, 2.6).set_ease(Tween.EASE_IN).set_delay(0.6)
	tw.tween_callback(queue_free)
	defeated.emit()


func _death_blast() -> void:
	var p := global_position + Vector3(randf_range(-12, 12), randf_range(8, 28), randf_range(-12, 12))
	FX.explosion(p, 2.2)
	World.debris(p, 4, Color(0.12, 0.16, 0.18), 2.0, 20.0)
