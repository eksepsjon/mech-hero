extends Node
## All bullets in the game. They are plain data in packed arrays, simulated on
## the XZ plane, collided by hand against enemies / the player / buildings, and
## drawn with one MultiMesh per team. This keeps thousands of bullets cheap.

const TEAM_PLAYER := 0
const TEAM_ENEMY := 1
const FLAG_HOMING := 1
const FLAG_CHAIN := 2
const CAPACITY := 3000
const HEIGHT := 6.0
const BULLET_SHADER := preload("res://shaders/bullet.gdshader")

var count := 0
var last_step_usec := 0

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _rad := PackedFloat32Array()
var _dmg := PackedFloat32Array()
var _life := PackedFloat32Array()
var _team := PackedByteArray()
var _pierce := PackedInt32Array()
var _bounce := PackedInt32Array()
var _flags := PackedInt32Array()
var _col := PackedColorArray()
var _last := PackedInt64Array()

var _mm_player: MultiMesh
var _mm_enemy: MultiMesh
var _buf_player := PackedFloat32Array()
var _buf_enemy := PackedFloat32Array()


func _ready() -> void:
	_pos.resize(CAPACITY)
	_vel.resize(CAPACITY)
	_rad.resize(CAPACITY)
	_dmg.resize(CAPACITY)
	_life.resize(CAPACITY)
	_team.resize(CAPACITY)
	_pierce.resize(CAPACITY)
	_bounce.resize(CAPACITY)
	_flags.resize(CAPACITY)
	_col.resize(CAPACITY)
	_last.resize(CAPACITY)
	_buf_player.resize(CAPACITY * 16)
	_buf_enemy.resize(CAPACITY * 16)
	_mm_player = _make_multimesh()
	_mm_enemy = _make_multimesh()


func _make_multimesh() -> MultiMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	var m := ShaderMaterial.new()
	m.shader = BULLET_SHADER
	mesh.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = CAPACITY
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-600, -50, -600), Vector3(1200, 100, 1200))
	add_child(mmi)
	return mm


func spawn(team: int, p: Vector2, v: Vector2, dmg: float, radius: float, color: Color,
		life: float = 3.0, pierce: int = 0, bounce: int = 0, flags: int = 0) -> void:
	if count >= CAPACITY:
		return
	var i := count
	_pos[i] = p
	_vel[i] = v
	_rad[i] = radius
	_dmg[i] = dmg
	_life[i] = life
	_team[i] = team
	_pierce[i] = pierce
	_bounce[i] = bounce
	_flags[i] = flags
	_col[i] = color
	_last[i] = 0
	count += 1


func clear() -> void:
	count = 0
	_mm_player.visible_instance_count = 0
	_mm_enemy.visible_instance_count = 0


func clear_team(team: int, with_fx: bool = true) -> void:
	var i := 0
	var fx_budget := 40
	while i < count:
		if _team[i] == team:
			if with_fx and fx_budget > 0:
				fx_budget -= 1
				FX.hit_spark(Vector3(_pos[i].x, HEIGHT, _pos[i].y), _col[i])
			_remove(i)
		else:
			i += 1


## Removes bullets of `team` within `r` of `p`. Returns how many were removed.
func clear_radius(p: Vector2, r: float, team: int) -> int:
	var removed := 0
	var i := 0
	while i < count:
		var rr := r + _rad[i]
		if _team[i] == team and _pos[i].distance_squared_to(p) < rr * rr:
			_remove(i)
			removed += 1
		else:
			i += 1
	return removed


func count_team(team: int) -> int:
	var n := 0
	for i in count:
		if _team[i] == team:
			n += 1
	return n


func _remove(i: int) -> void:
	var last := count - 1
	if i != last:
		_pos[i] = _pos[last]
		_vel[i] = _vel[last]
		_rad[i] = _rad[last]
		_dmg[i] = _dmg[last]
		_life[i] = _life[last]
		_team[i] = _team[last]
		_pierce[i] = _pierce[last]
		_bounce[i] = _bounce[last]
		_flags[i] = _flags[last]
		_col[i] = _col[last]
		_last[i] = _last[last]
	count = last


func _physics_process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_step(delta)
	_render()
	last_step_usec = Time.get_ticks_usec() - t0


func _step(delta: float) -> void:
	var enemies: Array = []
	var epos := PackedVector2Array()
	var erad := PackedFloat32Array()
	for e in World.enemies:
		if is_instance_valid(e) and e.alive and e.targetable:
			enemies.append(e)
			epos.append(Vector2(e.global_position.x, e.global_position.z))
			erad.append(e.radius)
	var ne := enemies.size()
	var player = World.player
	var has_player: bool = World.player_alive()
	var ppos := Vector2.ZERO
	var prad := 0.0
	if has_player:
		ppos = Vector2(player.global_position.x, player.global_position.z)
		prad = player.hit_radius
	var b: Rect2 = World.bounds
	var i := 0
	while i < count:
		var life := _life[i] - delta
		if life <= 0.0:
			_remove(i)
			continue
		_life[i] = life
		var p := _pos[i]
		var v := _vel[i]
		var team := _team[i]
		var r := _rad[i]
		if (_flags[i] & FLAG_HOMING) != 0 and ne > 0:
			v = _home(p, v, epos, delta)
		p += v * delta

		# Arena bounds.
		if not b.has_point(p):
			if _bounce[i] > 0:
				_bounce[i] -= 1
				if p.x < b.position.x or p.x > b.end.x:
					v.x = -v.x
				if p.y < b.position.y or p.y > b.end.y:
					v.y = -v.y
				p.x = clampf(p.x, b.position.x, b.end.x)
				p.y = clampf(p.y, b.position.y, b.end.y)
			else:
				_remove(i)
				continue

		# Buildings soak bullets from both teams.
		var blocked := false
		for bld in World.buildings_at(p):
			var rect: Rect2 = bld.rect
			if not rect.has_point(p):
				continue
			var from_player := team == TEAM_PLAYER
			bld.take_damage(_dmg[i] * (1.0 if from_player else 0.5), from_player)
			if from_player and _bounce[i] > 0:
				_bounce[i] -= 1
				var dl := p.x - rect.position.x
				var dr := rect.end.x - p.x
				var dt := p.y - rect.position.y
				var db := rect.end.y - p.y
				if minf(dl, dr) < minf(dt, db):
					v.x = -v.x
					p.x = rect.position.x - 0.1 if dl < dr else rect.end.x + 0.1
				else:
					v.y = -v.y
					p.y = rect.position.y - 0.1 if dt < db else rect.end.y + 0.1
			else:
				blocked = true
			break
		if blocked:
			_remove(i)
			continue

		if team == TEAM_PLAYER:
			var consumed := false
			for j in ne:
				var rr := r + erad[j]
				if p.distance_squared_to(epos[j]) >= rr * rr:
					continue
				var e = enemies[j]
				if not e.alive:
					continue
				var eid: int = e.get_instance_id()
				if _last[i] == eid:
					continue
				Game.hit_enemy(e, _dmg[i], _flags[i])
				FX.hit_spark(Vector3(p.x, HEIGHT, p.y), _col[i])
				if _pierce[i] > 0:
					_pierce[i] -= 1
					_last[i] = eid
				else:
					consumed = true
				break
			if consumed:
				_remove(i)
				continue
		elif has_player:
			var rr := r + prad
			if p.distance_squared_to(ppos) < rr * rr and player.take_damage(_dmg[i]):
				_remove(i)
				continue

		_pos[i] = p
		_vel[i] = v
		i += 1


func _home(p: Vector2, v: Vector2, epos: PackedVector2Array, delta: float) -> Vector2:
	var best := -1
	var best_d := INF
	for j in epos.size():
		var d := p.distance_squared_to(epos[j])
		if d < best_d:
			best_d = d
			best = j
	var want := (epos[best] - p).angle()
	var spd := minf(v.length() + 70.0 * delta, 85.0)
	var ang := v.angle()
	var diff := wrapf(want - ang, -PI, PI)
	ang += clampf(diff, -6.0 * delta, 6.0 * delta)
	return Vector2.from_angle(ang) * spd


func _render() -> void:
	var np := 0
	var ne := 0
	for i in count:
		var p := _pos[i]
		var c := _col[i]
		var r := _rad[i]
		if _team[i] == TEAM_PLAYER:
			# Stretched along the velocity so player fire reads as tracer streaks.
			var d := _vel[i].normalized()
			var l := r * 2.6
			var k := np * 16
			_buf_player[k] = d.x * l
			_buf_player[k + 1] = 0.0
			_buf_player[k + 2] = -d.y * r
			_buf_player[k + 3] = p.x
			_buf_player[k + 4] = 0.0
			_buf_player[k + 5] = r
			_buf_player[k + 6] = 0.0
			_buf_player[k + 7] = HEIGHT
			_buf_player[k + 8] = d.y * l
			_buf_player[k + 9] = 0.0
			_buf_player[k + 10] = d.x * r
			_buf_player[k + 11] = p.y
			_buf_player[k + 12] = c.r
			_buf_player[k + 13] = c.g
			_buf_player[k + 14] = c.b
			_buf_player[k + 15] = c.a
			np += 1
		else:
			var k := ne * 16
			_buf_enemy[k] = r
			_buf_enemy[k + 1] = 0.0
			_buf_enemy[k + 2] = 0.0
			_buf_enemy[k + 3] = p.x
			_buf_enemy[k + 4] = 0.0
			_buf_enemy[k + 5] = r
			_buf_enemy[k + 6] = 0.0
			_buf_enemy[k + 7] = HEIGHT
			_buf_enemy[k + 8] = 0.0
			_buf_enemy[k + 9] = 0.0
			_buf_enemy[k + 10] = r
			_buf_enemy[k + 11] = p.y
			_buf_enemy[k + 12] = c.r
			_buf_enemy[k + 13] = c.g
			_buf_enemy[k + 14] = c.b
			_buf_enemy[k + 15] = c.a
			ne += 1
	if np > 0:
		_mm_player.buffer = _buf_player
	_mm_player.visible_instance_count = np
	if ne > 0:
		_mm_enemy.buffer = _buf_enemy
	_mm_enemy.visible_instance_count = ne
