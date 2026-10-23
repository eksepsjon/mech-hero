extends Node
## Registries for the stage being played: player, enemies, buildings (with a
## spatial grid for fast bullet lookups) and helpers for area effects.

const CELL := 8.0
const HALF := 70.0
const EMPTY: Array = []

var player = null
var enemies: Array = []
var buildings: Array = []
var arena = null
var run = null
var debris_pool = null
var magnet := false
var shard_count := 0
var cam_right := Vector2(1, 0)
var cam_forward := Vector2(0, -1)
var bounds := Rect2(-HALF, -HALF, HALF * 2.0, HALF * 2.0)
var _cells: Dictionary = {}


func reset() -> void:
	player = null
	enemies.clear()
	buildings.clear()
	arena = null
	debris_pool = null
	magnet = false
	_cells.clear()


static func xz(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func player_alive() -> bool:
	return player != null and is_instance_valid(player) and player.alive


# --- buildings ---------------------------------------------------------------

func register_building(b) -> void:
	buildings.append(b)
	for c in _cells_for(b.rect):
		if not _cells.has(c):
			_cells[c] = []
		_cells[c].append(b)


func unregister_building(b) -> void:
	buildings.erase(b)
	for c in _cells_for(b.rect):
		if _cells.has(c):
			_cells[c].erase(b)


func _cells_for(r: Rect2) -> Array:
	var out: Array = []
	for x in range(int(floor(r.position.x / CELL)), int(floor(r.end.x / CELL)) + 1):
		for y in range(int(floor(r.position.y / CELL)), int(floor(r.end.y / CELL)) + 1):
			out.append(Vector2i(x, y))
	return out


func buildings_at(p: Vector2) -> Array:
	return _cells.get(Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL))), EMPTY)


func building_at(p: Vector2, margin: float = 0.0):
	for b in buildings_at(p):
		if b.rect.grow(margin).has_point(p):
			return b
	if margin > 0.0:
		for b in buildings_in_rect(Rect2(p - Vector2(margin, margin), Vector2(margin, margin) * 2.0)):
			if b.rect.grow(margin).has_point(p):
				return b
	return null


func buildings_in_rect(r: Rect2) -> Array:
	var seen := {}
	for c in _cells_for(r):
		for b in _cells.get(c, EMPTY):
			if not seen.has(b) and b.rect.intersects(r):
				seen[b] = true
	return seen.keys()


# --- enemies -----------------------------------------------------------------

func enemies_in_radius(p: Vector2, r: float) -> Array:
	var out: Array = []
	for e in enemies:
		if e.alive and e.targetable:
			var rr: float = r + e.radius
			if p.distance_squared_to(xz(e.global_position)) < rr * rr:
				out.append(e)
	return out


func nearest_enemy(p: Vector2, max_dist: float, exclude: Array = []):
	var best = null
	var best_d := max_dist * max_dist
	for e in enemies:
		if not e.alive or not e.targetable or exclude.has(e):
			continue
		var d := p.distance_squared_to(xz(e.global_position))
		if d < best_d:
			best_d = d
			best = e
	return best


# --- area effects ------------------------------------------------------------

## Explosion that hurts the opposing team, damages structures and crushes props.
func explode(p: Vector2, radius: float, dmg: float, team: int, fx_scale: float = -1.0) -> void:
	var s := radius / 7.0 if fx_scale < 0.0 else fx_scale
	FX.explosion(Vector3(p.x, 2.0, p.y), s)
	if team == Bullets.TEAM_ENEMY and player_alive():
		var rr: float = radius + player.radius
		if p.distance_squared_to(xz(player.global_position)) < rr * rr:
			player.take_damage(dmg)
	if team == Bullets.TEAM_PLAYER:
		for e in enemies_in_radius(p, radius):
			e.take_damage(dmg, false)
	for b in buildings_in_rect(Rect2(p - Vector2(radius, radius), Vector2(radius, radius) * 2.0)):
		b.take_damage(dmg * 2.0, team == Bullets.TEAM_PLAYER)
	if arena != null:
		arena.crush_props_in(p, radius, false)


func debris(pos: Vector3, count: int, color: Color, size: float = 1.5, force: float = 12.0) -> void:
	if debris_pool != null:
		debris_pool.spawn(pos, count, color, size, force)


func spawn_shards(p: Vector2, n: int) -> void:
	if arena == null:
		return
	for k in n:
		if shard_count >= 160:
			return
		var s = preload("res://scenes/pickups/shard.gd").new()
		arena.add_child(s)
		s.global_position = Vector3(p.x + randf_range(-2, 2), 3.0, p.y + randf_range(-2, 2))
