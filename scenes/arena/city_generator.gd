extends RefCounted
## Procedural district layout for an arena. City styles go road grid → blocks →
## lots → buildings; rural and forest styles lay out farmsteads or woodland around
## a single crossroads. Then street furniture, parked cars, moving traffic and an
## unreachable backdrop outside the arena.

const Building := preload("res://scenes/destructibles/building.gd")
const Prop := preload("res://scenes/destructibles/prop.gd")
const HALF := 70.0
const NEON := [Color(1.0, 0.25, 0.7), Color(0.2, 0.9, 1.0), Color(1.0, 0.75, 0.2), Color(0.6, 0.35, 1.0), Color(0.3, 1.0, 0.5)]

const VARIANTS := {
	"downtown": {"pitch": 35.0, "road": 10.0, "min_h": 6.4, "max_h": 25.6, "tall_chance": 0.5,
			"park_chance": 0.12, "traffic": 12, "parked": 0.55, "neon": 0.5,
			"palette": [Color(0.88, 0.84, 0.76), Color(0.68, 0.78, 0.88), Color(0.92, 0.72, 0.6), Color(0.74, 0.82, 0.7), Color(0.62, 0.64, 0.72)],
			"window": Color(1.0, 0.82, 0.55)},
	"harbor": {"pitch": 46.0, "road": 12.0, "min_h": 6.4, "max_h": 16.0, "tall_chance": 0.2,
			"park_chance": 0.0, "traffic": 8, "parked": 0.35, "neon": 0.25, "containers": 0.55,
			"palette": [Color(0.7, 0.72, 0.74), Color(0.62, 0.66, 0.62), Color(0.78, 0.7, 0.6)],
			"window": Color(0.6, 0.85, 1.0)},
	"highway": {"pitch": 70.0, "road": 18.0, "min_h": 6.4, "max_h": 19.2, "tall_chance": 0.3,
			"park_chance": 0.1, "traffic": 24, "parked": 0.2, "neon": 0.35,
			"palette": [Color(0.75, 0.7, 0.64), Color(0.64, 0.7, 0.76), Color(0.8, 0.8, 0.82)],
			"window": Color(1.0, 0.7, 0.45)},
	# Suburbs mixed with a few mid-rise blocks and parks.
	"mixed": {"style": "mixed", "ground": 3, "pitch": 46.0, "road": 10.0, "min_h": 6.4, "max_h": 19.2,
			"tall_chance": 0.35, "park_chance": 0.15, "house_chance": 0.6, "traffic": 10, "parked": 0.35,
			"neon": 0.3,
			"palette": [Color(0.82, 0.8, 0.76), Color(0.7, 0.76, 0.84), Color(0.86, 0.74, 0.66)],
			"window": Color(1.0, 0.8, 0.55)},
	# Farmland: one crossroads, crop fields, farmsteads with barns and silos.
	"rural": {"style": "rural", "ground": 1, "pitch": 140.0, "road": 9.0, "traffic": 5, "parked": 0.08,
			"lamp_spacing": 28.0, "neon": 0.0, "palette": [Color(0.3, 0.28, 0.25)],
			"window": Color(1.0, 0.75, 0.45)},
	# Dense cedar forest with clearings, cabins and a watchtower.
	"forest": {"style": "forest", "ground": 2, "pitch": 140.0, "road": 8.0, "traffic": 4, "parked": 0.05,
			"lamp_spacing": 36.0, "neon": 0.0, "palette": [Color(0.25, 0.22, 0.2)],
			"window": Color(1.0, 0.7, 0.4)},
}
const HOUSE_COLORS := [Color(0.7, 0.68, 0.62), Color(0.55, 0.62, 0.7), Color(0.72, 0.6, 0.5), Color(0.6, 0.66, 0.56), Color(0.78, 0.76, 0.72)]
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
	var style: String = cfg.get("style", "city")
	for sx in spans:
		for sz in spans:
			var block := Rect2(sx.x + 2.0, sz.x + 2.0, sx.y - sx.x - 4.0, sz.y - sz.x - 4.0)
			if block.size.x < 6.0 or block.size.y < 6.0:
				continue
			match style:
				"rural":
					_farmland(arena, block, rng, clear)
				"forest":
					_woodland(arena, block, rng, clear)
				_:
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
	if rng.randf() < float(cfg.get("house_chance", 0.0)):
		_suburb(arena, block, rng, clear)
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
	arena.add_prop(prop)
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
						next_lamp = t + float(cfg.get("lamp_spacing", 16.0))
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
			arena.set_prop_moving(car)
			car.drive_dir = dir
			car.drive_speed = rng.randf_range(8.0, 14.0)


static func _backdrop(arena: Node3D, cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	var style: String = cfg.get("style", "city")
	if style == "rural" or style == "forest":
		_tree_line(arena, rng, 1.0 if style == "forest" else 0.45)
		return
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
				b.base_color = palette[rng.randi() % palette.size()].darkened(0.12)
				b.window_color = cfg.window
				b.seed_value = rng.randf() * 100.0
				arena.add_child(b)
		t += 15.0


# --- rural ---------------------------------------------------------------------

static func _overlaps(r: Rect2, taken: Array) -> bool:
	for t in taken:
		if r.intersects(t):
			return true
	return false


static func _place(arena: Node3D, kind: String, center: Vector2, size: Vector3, color: Color,
		rng: RandomNumberGenerator, window: Color = Color(1.0, 0.75, 0.45)):
	var b = Building.new()
	b.kind = kind
	b.size = size
	b.center = center
	b.base_color = color
	b.window_color = window
	b.seed_value = rng.randf() * 100.0
	arena.add_child(b)
	return b


static func _farmland(arena: Node3D, block: Rect2, rng: RandomNumberGenerator, clear: Array) -> void:
	var inner := block.grow(-4.0)
	var taken: Array = []
	# Farmsteads: house, barn and silo grouped together.
	for k in rng.randi_range(1, 2):
		for attempt in 12:
			var c := Vector2(rng.randf_range(inner.position.x + 12.0, inner.end.x - 12.0),
					rng.randf_range(inner.position.y + 12.0, inner.end.y - 12.0))
			var yard := Rect2(c - Vector2(14, 12), Vector2(28, 24))
			if _near(c, clear, 26.0) or _overlaps(yard, taken) or not inner.encloses(yard):
				continue
			taken.append(yard)
			_place(arena, "farmhouse", c + Vector2(-7, -5), Vector3(9.0, 6.4, 7.5), Color(0.62, 0.56, 0.46), rng)
			_place(arena, "barn", c + Vector2(6, 3), Vector3(12.0, 8.0, 9.0), Color(0.5, 0.11, 0.08), rng)
			_place(arena, "silo", c + Vector2(-4, 7), Vector3(4.4, 14.0, 4.4), Color(0.55, 0.57, 0.6), rng)
			if rng.randf() < 0.6:
				_place(arena, "silo", c + Vector2(0.5, 8), Vector3(3.6, 11.0, 3.6), Color(0.6, 0.6, 0.62), rng)
			_add_prop(arena, "lamp", c + Vector2(-1, -9), 0.0)
			break
	# Windbreak tree row along one edge of the field.
	var along_x := rng.randf() < 0.5
	var t := 0.0
	var length := inner.size.x if along_x else inner.size.y
	while t < length:
		var p := inner.position + (Vector2(t, 1.0) if along_x else Vector2(1.0, t))
		if not _near(p, clear, 12.0) and not _overlaps(Rect2(p - Vector2(2, 2), Vector2(4, 4)), taken):
			_add_prop(arena, "tree", p, 0.0)
		t += rng.randf_range(4.5, 6.5)
	# Hay bales and the odd lone tree out in the fields.
	for k in 18:
		var p := Vector2(rng.randf_range(inner.position.x, inner.end.x), rng.randf_range(inner.position.y, inner.end.y))
		if _near(p, clear, 10.0) or _overlaps(Rect2(p - Vector2(2, 2), Vector2(4, 4)), taken):
			continue
		_add_prop(arena, "haybale" if k % 4 != 0 else "tree", p, rng.randf() * TAU)


# --- forest --------------------------------------------------------------------

static func _woodland(arena: Node3D, block: Rect2, rng: RandomNumberGenerator, clear: Array) -> void:
	var inner := block.grow(-2.0)
	var clearings: Array = []
	var taken: Array = []
	for k in 2:
		var c := Vector2(rng.randf_range(inner.position.x + 12.0, inner.end.x - 12.0),
				rng.randf_range(inner.position.y + 12.0, inner.end.y - 12.0))
		var r := rng.randf_range(9.0, 14.0)
		clearings.append([c, r])
		if _near(c, clear, 22.0):
			continue
		# Cabin in the clearing; sometimes a fire watchtower instead.
		if rng.randf() < 0.25:
			taken.append(_place(arena, "watchtower", c, Vector3(4.5, 19.2, 4.5), Color(0.35, 0.3, 0.25), rng).rect)
		else:
			var size := Vector3(rng.randf_range(7.0, 9.0), 3.2 * rng.randi_range(1, 2), rng.randf_range(6.0, 8.0))
			taken.append(_place(arena, "cabin", c, size, Color(0.36, 0.22, 0.13), rng).rect)
			_add_prop(arena, "lamp", c + Vector2(size.x * 0.5 + 2.0, 0), 0.0)
	var step := 7.0
	var x := inner.position.x + 2.0
	while x < inner.end.x - 1.0:
		var z := inner.position.y + 2.0
		while z < inner.end.y - 1.0:
			var p := Vector2(x + rng.randf_range(-2.5, 2.5), z + rng.randf_range(-2.5, 2.5))
			var open := _near(p, clear, 12.0) or _overlaps(Rect2(p - Vector2(3, 3), Vector2(6, 6)), taken)
			for cl in clearings:
				if p.distance_to(cl[0]) < cl[1]:
					open = true
			if not open and rng.randf() < 0.85:
				_add_prop(arena, "pine" if rng.randf() < 0.7 else "tree", p, rng.randf() * TAU)
			z += step
		x += step


# --- suburbs ---------------------------------------------------------------------

static func _suburb(arena: Node3D, block: Rect2, rng: RandomNumberGenerator, clear: Array) -> void:
	var cell := 11.0
	var nx := maxi(int(block.size.x / cell), 1)
	var nz := maxi(int(block.size.y / cell), 1)
	var cw := block.size.x / nx
	var cz := block.size.y / nz
	for i in nx:
		for j in nz:
			var c := block.position + Vector2((i + 0.5) * cw, (j + 0.5) * cz)
			if _near(c, clear, 16.0):
				continue
			if rng.randf() < 0.78:
				var size := Vector3(minf(rng.randf_range(6.5, 8.5), cw - 2.0), 3.2 * rng.randi_range(1, 2),
						minf(rng.randf_range(6.0, 8.0), cz - 2.0))
				_place(arena, "house", c + Vector2(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.8, 0.8)), size,
						HOUSE_COLORS[rng.randi() % HOUSE_COLORS.size()], rng)
				if rng.randf() < 0.4:
					_add_prop(arena, "tree", c + Vector2(cw * 0.4, cz * 0.4), 0.0)
				if rng.randf() < 0.3:
					_add_prop(arena, "car", c + Vector2(-cw * 0.38, 0), 0.0)
			else:
				_add_prop(arena, "tree", c, 0.0)
				_add_prop(arena, "tree", c + Vector2(3, 2), 0.0)


static func _tree_line(arena: Node3D, rng: RandomNumberGenerator, density: float) -> void:
	# Decorative woods outside the arena: single cone meshes, not crushable.
	var bark := FX.mat(Color(0.16, 0.4, 0.2), 0.0, 0.9)
	var dark := FX.mat(Color(0.12, 0.32, 0.17), 0.0, 0.9)
	var t := -HALF - 40.0
	while t < HALF + 40.0:
		for depth in [8.0, 18.0, 30.0]:
			for side in range(4):
				if rng.randf() > density:
					continue
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
				var far := side < 2
				var h := rng.randf_range(9.0, 16.0) if far else rng.randf_range(4.0, 6.0)
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = h * 0.32
				cone.height = h
				cone.radial_segments = 7
				var mi := MeshInstance3D.new()
				mi.mesh = cone
				mi.material_override = bark if rng.randf() < 0.5 else dark
				mi.position = Vector3(p.x + rng.randf_range(-3, 3), h * 0.5, p.y + rng.randf_range(-3, 3))
				arena.add_child(mi)
		t += 6.0
