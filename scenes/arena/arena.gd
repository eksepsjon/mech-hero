extends Node3D
## One city district arena: procedural road ground, boundary walls and pylons,
## the extraction gate, debris pool, and the generated buildings and props.
## Also fades buildings that would hide the player from the iso camera.

const CityGenerator := preload("res://scenes/arena/city_generator.gd")
const DebrisPool := preload("res://scenes/destructibles/debris_pool.gd")
const MechBuilder := preload("res://scenes/mechs/mech_builder.gd")
const GROUND_SHADER := preload("res://shaders/ground.gdshader")

var variant := "downtown"
var gen_seed := 1
var spawn_pos := Vector2(50, 50)
var gate_pos := Vector2(-58, -58)
var gate_open := false
const PROP_CELL := 8.0

var props: Array = []
var traffic: Array = []
var _prop_cells: Dictionary = {}
var road_pitch := 35.0
var road_width := 10.0

var _gate: Node3D
var _gate_lights: Array = []
var _gate_beam: MeshInstance3D


func _ready() -> void:
	World.arena = self
	var cfg: Dictionary = CityGenerator.VARIANTS[variant]
	road_pitch = cfg.pitch
	road_width = cfg.road
	_build_ground()
	_build_walls()
	_build_gate()
	var pool = DebrisPool.new()
	pool.name = "Debris"
	add_child(pool)
	World.debris_pool = pool
	CityGenerator.generate(self, variant, gen_seed)


func _build_ground() -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(420, 420)
	mi.mesh = plane
	var m := ShaderMaterial.new()
	m.shader = GROUND_SHADER
	m.set_shader_parameter("pitch", road_pitch)
	m.set_shader_parameter("road_w", road_width)
	m.set_shader_parameter("half_size", World.HALF)
	m.set_shader_parameter("ground_mode", int(CityGenerator.VARIANTS[variant].get("ground", 0)))
	mi.material_override = m
	add_child(mi)
	var ground := StaticBody3D.new()
	ground.collision_layer = 32
	ground.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	ground.add_child(shape)
	add_child(ground)


func _build_walls() -> void:
	var h := World.HALF
	for spec in [[Vector3(0, 10, -h - 2), Vector3(h * 2 + 8, 20, 4)], [Vector3(0, 10, h + 2), Vector3(h * 2 + 8, 20, 4)],
			[Vector3(-h - 2, 10, 0), Vector3(4, 20, h * 2 + 8)], [Vector3(h + 2, 10, 0), Vector3(4, 20, h * 2 + 8)]]:
		var wall := StaticBody3D.new()
		wall.collision_layer = 2
		wall.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec[1]
		shape.shape = box
		wall.add_child(shape)
		wall.position = spec[0]
		add_child(wall)
	# Holographic boundary pylons.
	var post := FX.mat(Color(0.12, 0.12, 0.15), 0.6, 0.4)
	var tip := FX.glow(Color(1.0, 0.2, 0.55), 6.0)
	var t := -h
	while t <= h + 0.1:
		for p in [Vector2(t, -h), Vector2(t, h), Vector2(-h, t), Vector2(h, t)]:
			MechBuilder.box(self, Vector3(0.8, 4.0, 0.8), Vector3(p.x, 2.0, p.y), post)
			MechBuilder.box(self, Vector3(1.0, 0.6, 1.0), Vector3(p.x, 4.3, p.y), tip)
		t += 20.0


func _build_gate() -> void:
	_gate = Node3D.new()
	_gate.position = Vector3(gate_pos.x, 0, gate_pos.y)
	_gate.rotation.y = PI / 4.0
	add_child(_gate)
	var frame := FX.mat(Color(0.18, 0.2, 0.25), 0.7, 0.35)
	var red := FX.glow(Color(1.0, 0.15, 0.2), 5.0)
	for side in [-1.0, 1.0]:
		MechBuilder.box(_gate, Vector3(3.0, 24.0, 3.0), Vector3(side * 10.0, 12.0, 0), frame)
		_gate_lights.append(MechBuilder.box(_gate, Vector3(0.5, 20.0, 3.2), Vector3(side * 8.4, 12.0, 0), red))
	MechBuilder.box(_gate, Vector3(23.0, 3.0, 3.4), Vector3(0, 25.0, 0), frame)
	_gate_lights.append(MechBuilder.box(_gate, Vector3(17.0, 0.6, 3.6), Vector3(0, 23.6, 0), red))
	_gate_beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 7.0
	cyl.bottom_radius = 7.0
	cyl.height = 80.0
	_gate_beam.mesh = cyl
	_gate_beam.position.y = 40.0
	_gate_beam.material_override = FX.glow_add(Color(0.3, 1.0, 0.5), 1.5, 0.18)
	_gate_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gate_beam.visible = false
	_gate.add_child(_gate_beam)


func open_gate() -> void:
	gate_open = true
	var green := FX.glow(Color(0.3, 1.0, 0.5), 6.0)
	for l in _gate_lights:
		l.material_override = green
	_gate_beam.visible = true
	FX.shockwave(Vector3(gate_pos.x, 0.3, gate_pos.y), 16.0, Color(0.3, 1.0, 0.5), 0.8)
	var marker = preload("res://scenes/fx/telegraph.gd").new()
	marker.radius = 9.0
	marker.color = Color(0.3, 1.0, 0.5)
	marker.auto_free = false
	marker.duration = 1.0
	add_child(marker)
	marker.global_position = Vector3(gate_pos.x, 0.25, gate_pos.y)


## Static props live in a coarse grid so crush checks stay cheap in dense forests.
func add_prop(prop) -> void:
	props.append(prop)
	var c := _prop_cell(prop.pos2())
	if not _prop_cells.has(c):
		_prop_cells[c] = []
	_prop_cells[c].append(prop)


func set_prop_moving(prop) -> void:
	var c := _prop_cell(prop.pos2())
	if _prop_cells.has(c):
		_prop_cells[c].erase(prop)
	traffic.append(prop)


func _prop_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / PROP_CELL)), int(floor(p.y / PROP_CELL)))


## Crushes every prop touching the circle. Returns how many were crushed.
func crush_props_in(p: Vector2, r: float, by_player: bool) -> int:
	var n := 0
	var reach := r + 2.5  # largest prop radius
	var lo := _prop_cell(p - Vector2(reach, reach))
	var hi := _prop_cell(p + Vector2(reach, reach))
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for prop in _prop_cells.get(Vector2i(x, y), World.EMPTY):
				n += _try_crush(prop, p, r, by_player)
	for prop in traffic:
		n += _try_crush(prop, p, r, by_player)
	return n


func _try_crush(prop, p: Vector2, r: float, by_player: bool) -> int:
	if prop.crushed:
		return 0
	var rr: float = r + prop.radius
	if p.distance_squared_to(prop.pos2()) < rr * rr:
		prop.crush(by_player)
		return 1
	return 0


func _physics_process(delta: float) -> void:
	for car in traffic:
		car.drive(delta)


func _process(delta: float) -> void:
	if not World.player_alive():
		return
	var pp := World.xz(World.player.global_position)
	var toward_cam := -World.cam_forward
	for b in World.buildings:
		var d: Vector2 = b.center - pp
		var half: float = (b.size.x + b.size.z) * 0.3
		var along := d.dot(toward_cam)
		var lateral := absf(d.dot(World.cam_right))
		var hides: bool = along > -half and along < b.size.y * 1.45 + half and lateral < half + 5.0
		b.set_fade(1.0 if hides else 0.0, delta)
