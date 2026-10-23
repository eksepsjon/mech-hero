extends CharacterBody3D
## Shared enemy behaviour: hull, hit flash, burn, separation, building smashing,
## prop crushing, contact damage, sky-drop entrance and death. Subclasses set
## their stats and model in `_configure()` and steer via `_ai()`.

signal defeated

const MechBuilder := preload("res://scenes/mechs/mech_builder.gd")

var kind := "enemy"
var max_hp := 40.0
var hp := 40.0
var hp_mult := 1.0
var radius := 3.5
var height := 12.0
var speed := 10.0
var contact_damage := 10.0
var flying := false
var heavy := false
var elite := false
var alive := true
var targetable := true
var crush_dps := 90.0
var shard_count := 2
var accent := Color(1.0, 0.2, 0.4)
var model: Node3D
var model_base_y := 0.0
var parts: Dictionary = {}
var flash_material: Material

## Set by `_ai()` each frame: desired velocity and facing on the XZ plane.
var desired := Vector2.ZERO
var face := Vector2(0, 1)

var _meshes: Array = []
var _flash := 0.0
var _burn_t := 0.0
var _burn_dps := 0.0
var _burn_tick := 0.0
var _walk := 0.0
var _contact_cd := 0.0
var _dropping := false


func _configure() -> void:
	pass


func _ai(_delta: float) -> void:
	pass


func _on_contact() -> void:
	pass


func _ready() -> void:
	collision_layer = 8
	flash_material = FX.flash_mat
	_configure()
	collision_mask = 2 if flying else 1 | 2
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	if elite:
		hp_mult *= 1.7
		accent = Color(1.0, 0.75, 0.2)
		model.scale *= 1.15
		var ring := MechBuilder.cyl(model, radius * 1.1, radius * 1.1, 0.2, Vector3(0, 0.2, 0), FX.glow(accent, 3.0), Vector3.ZERO, 16)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	max_hp *= hp_mult
	hp = max_hp
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 10.0
	shape.shape = cyl
	shape.position.y = 5.0
	add_child(shape)
	_collect_meshes(model)
	model_base_y = model.position.y
	World.enemies.append(self)


func _collect_meshes(n: Node) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			_meshes.append(c)
		_collect_meshes(c)


func _exit_tree() -> void:
	World.enemies.erase(self)


## Drops from orbit onto the target point, flattening whatever is underneath.
func drop_in() -> void:
	_dropping = true
	targetable = false
	model.position.y = model_base_y + 80.0
	var tw := create_tween()
	tw.tween_property(model, "position:y", model_base_y, 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(_landed)


func _landed() -> void:
	_dropping = false
	targetable = true
	var p := World.xz(global_position)
	FX.dust(global_position, 1.0 + radius * 0.25)
	FX.shockwave(global_position + Vector3(0, 0.3, 0), radius * 3.0, accent, 0.4)
	FX.shake(0.06 + radius * 0.02)
	if not flying:
		var r := radius + 1.0
		for b in World.buildings_in_rect(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0)):
			b.take_damage(5000.0)
		if World.arena != null:
			World.arena.crush_props_in(p, radius * 1.6, false)


func pos2() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func to_player() -> Vector2:
	if not World.player_alive():
		return Vector2.ZERO
	return World.xz(World.player.global_position) - pos2()


func shoot(dir: Vector2, spd: float, dmg: float, color: Color, rad: float = 1.1) -> void:
	Bullets.spawn(Bullets.TEAM_ENEMY, pos2() + dir * (radius + 1.0), dir * spd, dmg, rad, color, 7.0)


func _physics_process(delta: float) -> void:
	if not alive or _dropping:
		return
	_contact_cd = maxf(_contact_cd - delta, 0.0)
	desired = Vector2.ZERO
	_ai(delta)
	var my := pos2()
	var sep := Vector2.ZERO
	for e in World.enemies:
		if e == self or e.flying != flying:
			continue
		var d: Vector2 = my - e.pos2()
		var min_d: float = radius + e.radius
		var l2 := d.length_squared()
		if l2 < min_d * min_d and l2 > 0.0001:
			var l := sqrt(l2)
			sep += d / l * (min_d - l)
	velocity = Vector3(desired.x + sep.x * 4.0, 0.0, desired.y + sep.y * 4.0)
	move_and_slide()
	position.y = 0.0
	if not flying:
		_smash(delta)
	_contact(my)
	_burn(delta)
	_animate(delta)
	var was_lit := _flash > 0.0
	_flash -= delta
	if was_lit and _flash <= 0.0:
		for m in _meshes:
			m.material_overlay = null


func _smash(delta: float) -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i).get_collider()
		if c != null and c.has_method("take_damage"):
			c.call("take_damage", crush_dps * delta, false)
	if World.arena != null and velocity.length() > 0.5:
		World.arena.crush_props_in(pos2(), radius * 0.9, false)


func _contact(my: Vector2) -> void:
	if contact_damage <= 0.0 or _contact_cd > 0.0 or not World.player_alive():
		return
	var rr: float = radius + World.player.hit_radius
	if my.distance_squared_to(World.xz(World.player.global_position)) < rr * rr:
		if World.player.take_damage(contact_damage):
			_contact_cd = 0.8
			_on_contact()


func _burn(delta: float) -> void:
	if _burn_t <= 0.0:
		return
	_burn_t -= delta
	_burn_tick -= delta
	if _burn_tick <= 0.0:
		_burn_tick = 0.5
		FX.burst(global_position + Vector3(0, height * 0.6, 0), Color(1.0, 0.45, 0.1), 5, 6.0, 0.5, 1.2, 8.0, 50.0, 4.0)
		take_damage(_burn_dps * 0.5, false, false)


func _animate(delta: float) -> void:
	if face.length() > 0.01:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-face.x, -face.y), 1.0 - exp(-8.0 * delta))
	var spd := velocity.length()
	if parts.has("leg_l"):
		if spd > 0.5:
			_walk += delta * spd * 0.35
		var s := sin(_walk)
		parts.leg_l.rotation.x = s * 0.5
		parts.leg_r.rotation.x = -s * 0.5


func apply_burn(dps: float, duration: float) -> void:
	_burn_dps = maxf(_burn_dps, dps)
	_burn_t = maxf(_burn_t, duration)


func take_damage(amount: float, crit: bool = false, show_number: bool = true) -> void:
	if not alive:
		return
	hp -= amount
	if _flash <= -0.08:
		_flash = 0.05
		for m in _meshes:
			m.material_overlay = flash_material
	if show_number:
		FX.damage_number(global_position + Vector3(0, height + 2.0, 0), amount, crit)
	if hp <= 0.0:
		die()


func die() -> void:
	if not alive:
		return
	alive = false
	World.enemies.erase(self)
	var s := 1.0 + radius * 0.15
	FX.explosion(global_position + Vector3(0, height * 0.5, 0), s)
	World.debris(global_position + Vector3(0, height * 0.5, 0), 4 + int(radius), MechBuilder.ENEMY_ARMOR, 1.0, 16.0)
	World.spawn_shards(pos2(), shard_count)
	Game.on_enemy_killed(self)
	if heavy or elite:
		FX.hitstop(0.05)
	defeated.emit()
	queue_free()
