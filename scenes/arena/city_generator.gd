extends RefCounted
## Procedural city layout for an arena: road grid → blocks → lots → buildings,
## then street furniture, parked cars, moving traffic and an unreachable
## backdrop skyline outside the arena.

const Building := preload("res://scenes/destructibles/building.gd")
const Prop := preload("res://scenes/destructibles/prop.gd")
const HALF := 70.0
const NEON := [Color(1.0, 0.25, 0.7), Color(0.2, 0.9, 1.0), Color(1.0, 0.75, 0.2), Color(0.6, 0.35, 1.0), Color(0.3, 1.0, 0.5)]

const VARIANTS := {
	"downtown": {"pitch": 35.0, "road": 10.0, "min_h": 6.4, "max_h": 25.6, "tall_chance": 0.5,
			"park_chance": 0.12, "traffic": 12, "parked": 0.55, "neon": 0.5,
			"palette": [Color(0.22, 0.24, 0.3), Color(0.3, 0.28, 0.27), Color(0.18, 0.22, 0.26), Color(0.36, 0.35, 0.4)],
			"window": Color(1.0, 0.82, 0.55)},
	"harbor": {"pitch": 46.0, "road": 12.0, "min_h": 6.4, "max_h": 16.0, "tall_chance": 0.2,
			"park_chance": 0.0, "traffic": 8, "parked": 0.35, "neon": 0.25, "containers": 0.55,
			"palette": [Color(0.3, 0.32, 0.34), Color(0.25, 0.27, 0.25), Color(0.35, 0.3, 0.26)],
			"window": Color(0.6, 0.85, 1.0)},
	"highway": {"pitch": 70.0, "road": 18.0, "min_h": 6.4, "max_h": 19.2, "tall_chance": 0.3,
			"park_chance": 0.1, "traffic": 24, "parked": 0.2, "neon": 0.35,
			"palette": [Color(0.28, 0.26, 0.24), Color(0.22, 0.25, 0.28), Color(0.32, 0.32, 0.34)],
			"window": Color(1.0, 0.7, 0.45)},
}
const CONTAINER_COLORS := [Color(0.7, 0.15, 0.1), Color(0.1, 0.3, 0.6), Color(0.85, 0.45, 0.1), Color(0.1, 0.5, 0.45), Color(0.6, 0.6, 0.62)]


static func road_centers(pitch: float) -> Array:
	var out: Array = []
	var k := -int(ceil(HALF / pitch))
	while k * pitch <= HALF + 0.01:
		var c := k * pitch
		if c >= -HALF - 0.01:
			out.append(c)
		k += 1
	return out


static func _spans(centers: Array, road: float) -> Array:
	var spans: Array = []
	var prev := -HALF
	for c in centers:
		var end: float = c - road * 0.5
		if end - prev > 8.0:
			spans.append(Vector2(prev, end))
		prev = maxf(prev, c + road * 0.5)
	if HALF - prev > 8.0:
		spans.append(Vector2(prev, HALF))
	return spans


static func generate(arena: Node3D, variant: String, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cfg: Dictionary = VARIANTS[variant]
	var road: float = cfg.road
	var centers := road_centers(cfg.pitch)
	var spans := _spans(centers, road)
	var clear: Array = [arena.spawn_pos, arena.gate_pos]
	for sx in spans:
		for sz in spans:
			var block := Rect2(sx.x + 2.0, sz.x + 2.0, sx.y - sx.x - 4.0, sz.y - sz.x - 4.0)
			if block.size.x >= 6.0 and block.size.y >= 6.0:
				_fill_block(arena, block, cfg, rng, clear)
	_street_props(arena, centers, road, cfg, rng, clear)
	_traffic(arena, centers, road, cfg, rng)
	_backdrop(arena, cfg, rng)


static func _near(p: Vector2, points: Array, d: float) -> bool:
	for q in points:
		if p.distance_to(q) < d:
			return true
	return false


static func _fill_block(arena: Node3D, block: Rect2, cfg: Dictionary, rng: RandomNumberGenerator, clear: Array) -> void:
	if rng.randf() < float(cfg.park_chance) and not _near(block.get_center(), clear, 20.0):
		_park(arena, block, rng)
		return
	var lots: Array = []
	_split(block, rng, lots, 0)
	for lot in lots:
		var c: Vector2 = lot.get_center()
		if _near(c, clear, 14.0 + lot.size.length() * 0.35):
			continue
		if rng.randf() < 0.08:
			_add_prop(arena, "kiosk", c, rng.randf() * TAU)
			continue
		if rng.randf() < float(cfg.get("containers", 0.0)):
			_containers(arena, lot.grow(-1.0), rng)
		else:
			_building(arena, lot.grow(-1.0), cfg, rng)


static func _split(r: Rect2, rng: RandomNumberGenerator, out: Array, depth: int) -> void:
	var longest := maxf(r.size.x, r.size.y)
	var want_split := longest > 22.0 or (longest > 13.0 and depth < 2 and rng.randf() < 0.6)
	if not want_split or depth > 3:
		out.append(r)
		return
	var t := rng.randf_range(0.38, 0.62)
	if r.size.x >= r.size.y:
		var w := r.size.x * t
		_split(Rect2(r.position, Vector2(w, r.size.y)), rng, out, depth + 1)
		_split(Rect2(r.position + Vector2(w, 0), Vector2(r.size.x - w, r.size.y)), rng, out, depth + 1)
	else:
		var h := r.size.y * t
		_split(Rect2(r.position, Vector2(r.size.x, h)), rng, out, depth + 1)
		_split(Rect2(r.position + Vector2(0, h), Vector2(r.size.x, r.size.y - h)), rng, out, depth + 1)


static func _building(arena: Node3D, r: Rect2, cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	if r.size.x < 4.0 or r.size.y < 4.0:
		return
	var b = Building.new()
	var tall := rng.randf() < float(cfg.tall_chance)
	var max_h: float = cfg.max_h
	var min_h: float = cfg.min_h
	var h := rng.randf_range(max_h * 0.65, max_h) if tall else rng.randf_range(min_h, min_h + 6.4)
	b.size = Vector3(r.size.x, maxf(snappedf(h, 3.2), 6.4), r.size.y)
	b.center = r.get_center()
	var palette: Array = cfg.palette
	b.base_color = palette[rng.randi() % palette.size()]
	b.window_color = cfg.window
	b.kind = "tower" if b.size.y > 12.0 else "shop"
	b.neon = rng.randf() < float(cfg.neon)
	b.neon_color = NEON[rng.randi() % NEON.size()]
	b.seed_value = rng.randf() * 100.0
	arena.add_child(b)


static func _containers(arena: Node3D, r: Rect2, rng: RandomNumberGenerator) -> void:
	var along_x := r.size.x >= r.size.y
	var length := 12.0
	var width := 2.6
	var rows := int(r.size.y / (width + 0.6)) if along_x else int(r.size.x / (width + 0.6))
	var cols := int(r.size.x / (length + 1.0)) if along_x else int(r.size.y / (length + 1.0))
	for i in rows:
		for j in cols:
			if rng.randf() < 0.2:
				continue
			var b = Building.new()
			b.kind = "container"
			var levels := rng.randi_range(1, 3)
			if along_x:
				b.size = Vector3(length, 2.6 * levels, width)
				b.center = r.position + Vector2(j * (length + 1.0) + length * 0.5, i * (width + 0.6) + width * 0.5)
			else:
				b.size = Vector3(width, 2.6 * levels, length)
				b.center = r.position + Vector2(i * (width + 0.6) + width * 0.5, j * (length + 1.0) + length * 0.5)
			b.base_color = CONTAINER_COLORS[rng.randi() % CONTAINER_COLORS.size()]
			b.seed_value = rng.randf() * 100.0
			arena.add_child(b)


static func _park(arena: Node3D, block: Rect2, rng: RandomNumberGenerator) -> void:
	var step := 5.0
	var x := block.position.x + 2.5
	while x < block.end.x - 1.0:
		var z := block.position.y + 2.5
		while z < block.end.y - 1.0:
			if rng.randf() < 0.55:
				_add_prop(arena, "tree", Vector2(x + rng.randf_range(-1, 1), z + rng.randf_range(-1, 1)), 0.0)
			z += step
		x += step
	_add_prop(arena, "lamp", block.get_center(), 0.0)


static func _add_prop(arena: Node3D, kind: String, p: Vector2, heading: float):
	if absf(p.x) > HALF - 1.0 or absf(p.y) > HALF - 1.0:
		return null
	var prop = Prop.new()
	prop.kind = kind
	prop.heading = heading
	prop.position = Vector3(p.x, 0, p.y)
	arena.add_child(prop)
	arena.props.append(prop)
	return prop


static func _near_intersection(t: float, centers: Array, road: float) -> bool:
	for c in centers:
		if absf(t - c) < road * 0.5 + 3.0:
			return true
	return false


static func _street_props(arena: Node3D, centers: Array, road: float, cfg: Dictionary, rng: RandomNumberGenerator, clear: Array) -> void:
	for c in centers:
		for axis in [0, 1]:
			var t := -HALF + 3.0
			var next_lamp := t
			while t < HALF - 3.0:
				if not _near_intersection(t, centers, road):
					for side in [-1.0, 1.0]:
						var off: float = c + side * (road * 0.5 - 1.4)
						var p := Vector2(off, t) if axis == 0 else Vector2(t, off)
						var heading := 0.0 if axis == 0 else PI * 0.5
						if not _near(p, clear, 8.0) and rng.randf() < float(cfg.parked):
							_add_prop(arena, "car", p, heading + (PI if rng.randf() < 0.5 else 0.0))
					if t >= next_lamp:
						next_lamp = t + 16.0
						for side in [-1.0, 1.0]:
							var off: float = c + side * (road * 0.5 + 0.9)
							var p := Vector2(off, t) if axis == 0 else Vector2(t, off)
							if not _near(p, clear, 6.0):
								_add_prop(arena, "lamp", p, (0.0 if axis == 0 else PI * 0.5) + (PI * 0.5 * side))
				t += rng.randf_range(6.5, 10.0)


static func _traffic(arena: Node3D, centers: Array, road: float, cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	var inner: Array = []
	for c in centers:
		if absf(c) < HALF - road:
			inner.append(c)
	if inner.is_empty():
		return
	for k in int(cfg.traffic):
		var c: float = inner[rng.randi() % inner.size()]
		var axis := rng.randi() % 2
		var lane := 1.0 if rng.randf() < 0.5 else -1.0
		var off := c + lane * road * 0.25
		var t := rng.randf_range(-HALF, HALF)
		var p := Vector2(off, t) if axis == 0 else Vector2(t, off)
		# Right-hand traffic: lane side decides the direction of travel.
		var dir := Vector2(0, lane) if axis == 0 else Vector2(-lane, 0)
		var car = _add_prop(arena, "car", p, atan2(-dir.x, -dir.y))
		if car != null:
			car.drive_dir = dir
			car.drive_speed = rng.randf_range(8.0, 14.0)
			arena.traffic.append(car)


static func _backdrop(arena: Node3D, cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	# The camera looks toward -X/-Z, so only the far sides get tall towers;
	# the near sides stay low so they never block the view.
	var palette: Array = cfg.palette
	var t := -HALF - 40.0
	while t < HALF + 40.0:
		for depth in [16.0, 34.0]:
			for side in range(4):
				var far := side < 2
				var p: Vector2
				match side:
					0:
						p = Vector2(t, -HALF - depth)
					1:
						p = Vector2(-HALF - depth, t)
					2:
						p = Vector2(t, HALF + depth)
					_:
						p = Vector2(HALF + depth, t)
				if rng.randf() < 0.2:
					continue
				var b = Building.new()
				b.decor = true
				var w := rng.randf_range(8.0, 13.0)
				var h := rng.randf_range(18.0, 48.0) if far else rng.randf_range(3.2, 6.4)
				b.size = Vector3(w, h, rng.randf_range(8.0, 13.0))
				b.center = p
				b.base_color = palette[rng.randi() % palette.size()].darkened(0.3)
				b.window_color = cfg.window
				b.seed_value = rng.randf() * 100.0
				arena.add_child(b)
		t += 15.0
