extends CharacterBody3D
## The player's mech: twin-stick / WASD+mouse movement and aiming, boost dash
## with i-frames, smashing through buildings and props, orbiting guardian drones.

signal died

const MechBuilder := preload("res://scenes/mechs/mech_builder.gd")
const Weapon := preload("res://scenes/player/weapon.gd")

const PUSH_DPS := 110.0
const DASH_TIME := 0.22
const DASH_SPEED_MULT := 3.4
const AIM_HEIGHT := 6.0  # matches Bullets.HEIGHT

var radius := 3.6
var hit_radius := 2.6
var alive := true
var aim_dir := Vector2(-0.7071, -0.7071)
var move_dir := Vector2.ZERO
var firing := false
var invuln := 0.0
var dash_time := 0.0
var dash_cd := 0.0
var using_gamepad := false
var control_enabled := true
## Test hook: {"move": Vector2, "aim": Vector2, "fire": bool} in world space.
var auto_input = null
var parts: Dictionary
var weapon

var _dash_vec := Vector2.ZERO
var _walk := 0.0
var _last_step := 0.0
var _orbitals: Array = []
var _orbit_angle := 0.0
var _orbit_hit_cd: Dictionary = {}
var _meshes: Array = []
var _flash := 0.0
var _overlay_on := false
var _aim_line: MeshInstance3D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 14.0
	shape.shape = cyl
	shape.position.y = 7.0
	add_child(shape)
	parts = MechBuilder.build_player(self)
	_collect_meshes(parts.model)
	weapon = Weapon.new()
	weapon.player = self
	add_child(weapon)
	_aim_line = MeshInstance3D.new()
	var line := BoxMesh.new()
	line.size = Vector3(0.25, 0.05, 16.0)
	_aim_line.mesh = line
	_aim_line.material_override = FX.glow_add(Color(0.3, 0.9, 1.0), 2.0, 0.35)
	_aim_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aim_line.top_level = true
	add_child(_aim_line)
	World.player = self
	Game.stats_changed.connect(_sync_orbitals)
	_sync_orbitals()


func _collect_meshes(n: Node) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			_meshes.append(c)
		_collect_meshes(c)


## Mech-drop entrance: falls from the sky and slams into the street.
func drop_in() -> void:
	control_enabled = false
	invuln = 1.5
	parts.model.position.y = 80.0
	var tw := create_tween()
	tw.tween_property(parts.model, "position:y", 0.0, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_landed)


func _landed() -> void:
	control_enabled = true
	FX.dust(global_position, 2.5)
	FX.shockwave(global_position + Vector3(0, 0.3, 0), 18.0, Color(0.3, 0.9, 1.0), 0.5)
	FX.shake(0.45)
	if World.arena != null:
		World.arena.crush_props_in(World.xz(global_position), 10.0, true)


func can_be_hit() -> bool:
	return alive and invuln <= 0.0 and dash_time <= 0.0


## Returns true if the hit landed (false while invulnerable or dashing).
func take_damage(amount: float) -> bool:
	if not can_be_hit():
		return false
	Game.player_hp -= amount
	invuln = 0.55
	_flash = 0.1
	FX.shake(0.3)
	FX.hitstop(0.045)
	FX.sparks(global_position + Vector3(0, 8, 0), Color(1.0, 0.6, 0.3), 14)
	Game.player_damaged.emit()
	if Game.player_hp <= 0.0:
		Game.player_hp = 0.0
		_die()
	return true


func _die() -> void:
	alive = false
	velocity = Vector3.ZERO
	FX.explosion(global_position + Vector3(0, 6, 0), 2.5)
	FX.hitstop(0.12)
	World.debris(global_position + Vector3(0, 8, 0), 14, MechBuilder.PLAYER_ARMOR, 1.4, 20.0)
	parts.model.visible = false
	_aim_line.visible = false
	for o in _orbitals:
		o.visible = false
	died.emit()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.4):
		using_gamepad = true
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 2.0:
		using_gamepad = false
	elif event is InputEventMouseButton or event is InputEventKey:
		using_gamepad = false


func _physics_process(delta: float) -> void:
	if not alive:
		return
	invuln = maxf(invuln - delta, 0.0)
	dash_cd = maxf(dash_cd - delta, 0.0)
	if control_enabled:
		_read_input()
	else:
		move_dir = Vector2.ZERO
		firing = false

	var speed: float = Game.stats.move_speed
	if dash_time > 0.0:
		dash_time -= delta
		velocity = Vector3(_dash_vec.x, 0, _dash_vec.y) * speed * DASH_SPEED_MULT
		if Engine.get_physics_frames() % 2 == 0:
			FX.burst(global_position + Vector3(0, 6, 0), Color(0.3, 0.8, 1.0), 6, 6.0, 0.3, 1.6, 0.0, 180.0, 3.0)
	else:
		velocity = Vector3(move_dir.x, 0, move_dir.y) * speed
	move_and_slide()
	position.y = 0.0
	_smash(delta)
	weapon.update(delta, firing, aim_dir)
	_animate(delta)
	_update_orbitals(delta)
	_update_flash(delta)


func _read_input() -> void:
	if auto_input != null:
		move_dir = auto_input.get("move", Vector2.ZERO)
		var a: Vector2 = auto_input.get("aim", aim_dir)
		if a.length() > 0.1:
			aim_dir = a.normalized()
		firing = auto_input.get("fire", false)
		return
	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	move_dir = _screen_to_world(mv)
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() > 0.3:
		using_gamepad = true
	if using_gamepad:
		if stick.length() > 0.3:
			aim_dir = _screen_to_world(stick).normalized()
			firing = true
		else:
			if move_dir.length() > 0.2 and not Input.is_action_pressed("fire"):
				aim_dir = aim_dir.slerp(move_dir.normalized(), 0.2)
			firing = Input.is_action_pressed("fire")
	else:
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			var mp := get_viewport().get_mouse_position()
			var from := cam.project_ray_origin(mp)
			var dir := cam.project_ray_normal(mp)
			if absf(dir.y) > 0.001:
				var hit := from + dir * ((AIM_HEIGHT - from.y) / dir.y)
				var to := Vector2(hit.x, hit.z) - World.xz(global_position)
				if to.length() > 0.5:
					aim_dir = to.normalized()
		firing = Input.is_action_pressed("fire")
	if Input.is_action_just_pressed("dash"):
		try_dash()


func try_dash() -> void:
	if dash_cd > 0.0 or dash_time > 0.0:
		return
	dash_time = DASH_TIME
	dash_cd = Game.stats.dash_cd
	_dash_vec = move_dir.normalized() if move_dir.length() > 0.2 else aim_dir
	FX.dust(global_position, 1.0)
	FX.burst(global_position + Vector3(0, 9, 0), Color(1.0, 0.6, 0.2), 14, 14.0, 0.35, 1.2, 0.0, 60.0, 4.0)


func _screen_to_world(v: Vector2) -> Vector2:
	return World.cam_right * v.x - World.cam_forward * v.y


## Pushing into buildings grinds them down; walking over props crushes them.
func _smash(delta: float) -> void:
	var seen := {}
	for i in get_slide_collision_count():
		var c := get_slide_collision(i).get_collider()
		if c != null and c.has_method("take_damage") and not seen.has(c):
			seen[c] = true
			var mult := 4.0 if dash_time > 0.0 else 1.0
			c.take_damage(PUSH_DPS * mult * delta, true)
	if World.arena != null:
		World.arena.crush_props_in(World.xz(global_position), radius * 0.9, true)


func _animate(delta: float) -> void:
	var model: Node3D = parts.model
	var upper: Node3D = parts.upper
	var moving := velocity.length() > 1.0
	if moving:
		var face := Vector2(velocity.x, velocity.z).normalized()
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-face.x, -face.y), 1.0 - exp(-10.0 * delta))
		_walk += delta * velocity.length() * 0.32
	else:
		_walk = lerpf(_walk, roundf(_walk / PI) * PI, 1.0 - exp(-8.0 * delta))
	var aim_yaw := atan2(-aim_dir.x, -aim_dir.y)
	upper.rotation.y = lerp_angle(upper.rotation.y, wrapf(aim_yaw - model.rotation.y, -PI, PI), 1.0 - exp(-18.0 * delta))
	var s := sin(_walk)
	parts.leg_l.rotation.x = s * 0.55
	parts.leg_r.rotation.x = -s * 0.55
	upper.position.y = 8.2 + absf(s) * 0.35
	upper.rotation.z = s * 0.03
	# Footsteps: dust and a light camera thump on each stride.
	if moving and signf(s) != signf(_last_step) and dash_time <= 0.0:
		var foot: Node3D = parts.leg_l if s > 0.0 else parts.leg_r
		FX.dust(Vector3(foot.global_position.x, 0.2, foot.global_position.z), 0.6)
		FX.shake(0.035)
	_last_step = s
	_aim_line.global_position = global_position + Vector3(aim_dir.x * 13.0, AIM_HEIGHT, aim_dir.y * 13.0)
	_aim_line.rotation = Vector3(0, aim_yaw, 0)


func _update_flash(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	var blink := invuln > 0.0 and int(invuln * 12.0) % 2 == 0
	var on := _flash > 0.0 or blink
	if on != _overlay_on:
		_overlay_on = on
		for m in _meshes:
			m.material_overlay = FX.flash_mat if on else null


# --- guardian drones ----------------------------------------------------------------

func _sync_orbitals() -> void:
	var want: int = Game.stats.orbitals
	while _orbitals.size() < want:
		var o := Node3D.new()
		MechBuilder.ball(o, 1.1, Vector3.ZERO, FX.glow(Color(0.4, 1.0, 1.0), 6.0), Vector3.ONE, 8)
		MechBuilder.cyl(o, 1.8, 1.8, 0.15, Vector3.ZERO, FX.glow(Color(0.3, 0.8, 1.0), 2.0), Vector3.ZERO, 12)
		o.top_level = true
		add_child(o)
		_orbitals.append(o)


func _update_orbitals(delta: float) -> void:
	if _orbitals.is_empty():
		return
	_orbit_angle += delta * 2.6
	var center := World.xz(global_position)
	var n := _orbitals.size()
	for k in n:
		var a := _orbit_angle + TAU * k / n
		var p := center + Vector2.from_angle(a) * 9.0
		var o: Node3D = _orbitals[k]
		o.global_position = Vector3(p.x, Bullets.HEIGHT, p.y)
		Bullets.clear_radius(p, 1.6, Bullets.TEAM_ENEMY)
		for e in World.enemies_in_radius(p, 1.4):
			var cd: float = _orbit_hit_cd.get(e.get_instance_id(), 0.0)
			if Time.get_ticks_msec() / 1000.0 >= cd:
				_orbit_hit_cd[e.get_instance_id()] = Time.get_ticks_msec() / 1000.0 + 0.3
				Game.hit_enemy(e, float(Game.stats.damage) * 0.6)
