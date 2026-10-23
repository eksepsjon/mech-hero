extends Node3D
## Small prop the mechs crush underfoot: cars (some drive, some explode),
## street lamps, trees, pines, hay bales and kiosks. Kept tiny on purpose to sell the mech scale.

const MechBuilder := preload("res://scenes/mechs/mech_builder.gd")
const CAR_COLORS := [Color(0.8, 0.1, 0.12), Color(0.9, 0.9, 0.92), Color(0.1, 0.12, 0.15),
		Color(0.15, 0.3, 0.7), Color(0.95, 0.7, 0.1), Color(0.4, 0.42, 0.45), Color(0.1, 0.45, 0.3)]

var kind := "car"
var radius := 2.2
var crushed := false
var heading := 0.0
var drive_dir := Vector2.ZERO
var drive_speed := 0.0
var color := Color.WHITE
var value := 0
var _visual: Node3D


func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	rotation.y = heading
	match kind:
		"car":
			_build_car()
		"lamp":
			_build_lamp()
		"tree":
			_build_tree()
		"kiosk":
			_build_kiosk()
		"pine":
			_build_pine()
		"haybale":
			_build_haybale()


func pos2() -> Vector2:
	return Vector2(position.x, position.z)


func _build_car() -> void:
	radius = 2.3
	color = CAR_COLORS[randi() % CAR_COLORS.size()]
	value = randi_range(2, 9) * 1_000_000
	var paint := FX.mat(color, 0.6, 0.3)
	var glass := FX.mat(Color(0.05, 0.07, 0.1), 0.8, 0.1)
	MechBuilder.box(_visual, Vector3(1.9, 0.75, 4.4), Vector3(0, 0.65, 0), paint)
	MechBuilder.box(_visual, Vector3(1.7, 0.7, 2.3), Vector3(0, 1.35, 0.25), glass)
	var head := FX.glow(Color(1.0, 0.95, 0.8), 5.0)
	var tail := FX.glow(Color(1.0, 0.1, 0.1), 4.0)
	for x in [-0.65, 0.65]:
		MechBuilder.box(_visual, Vector3(0.45, 0.22, 0.1), Vector3(x, 0.75, -2.22), head)
		MechBuilder.box(_visual, Vector3(0.45, 0.2, 0.1), Vector3(x, 0.75, 2.22), tail)


func _build_lamp() -> void:
	radius = 0.9
	value = 300_000
	var pole := FX.mat(Color(0.25, 0.27, 0.3), 0.7, 0.4)
	MechBuilder.cyl(_visual, 0.12, 0.18, 6.0, Vector3(0, 3.0, 0), pole, Vector3.ZERO, 6)
	MechBuilder.box(_visual, Vector3(0.15, 0.15, 1.6), Vector3(0, 5.9, -0.7), pole)
	MechBuilder.box(_visual, Vector3(0.5, 0.2, 0.7), Vector3(0, 5.8, -1.4), FX.glow(Color(1.0, 0.85, 0.6), 6.0))


func _build_tree() -> void:
	radius = 1.6
	value = 200_000
	MechBuilder.cyl(_visual, 0.25, 0.35, 2.4, Vector3(0, 1.2, 0), FX.mat(Color(0.2, 0.13, 0.08), 0.0, 0.9), Vector3.ZERO, 6)
	var leaves := FX.mat(Color(0.08, 0.25, 0.12), 0.0, 0.9)
	MechBuilder.ball(_visual, 1.6, Vector3(0, 3.4, 0), leaves, Vector3.ONE, 8)
	MechBuilder.ball(_visual, 1.1, Vector3(0.6, 4.5, 0.3), leaves, Vector3.ONE, 8)


func _build_pine() -> void:
	radius = 1.5
	value = 150_000
	var s := randf_range(0.8, 1.35)
	_visual.scale = Vector3.ONE * s
	MechBuilder.cyl(_visual, 0.2, 0.3, 2.0, Vector3(0, 1.0, 0), FX.mat(Color(0.2, 0.13, 0.08), 0.0, 0.9), Vector3.ZERO, 6)
	var needles := FX.mat([Color(0.05, 0.16, 0.08), Color(0.04, 0.12, 0.07), Color(0.07, 0.18, 0.1)][randi() % 3], 0.0, 0.9)
	MechBuilder.cyl(_visual, 0.0, 2.0, 4.0, Vector3(0, 3.5, 0), needles, Vector3.ZERO, 7)
	MechBuilder.cyl(_visual, 0.0, 1.4, 3.2, Vector3(0, 5.6, 0), needles, Vector3.ZERO, 7)


func _build_haybale() -> void:
	radius = 1.2
	value = 40_000
	MechBuilder.cyl(_visual, 0.9, 0.9, 1.6, Vector3(0, 0.9, 0), FX.mat(Color(0.6, 0.48, 0.2), 0.0, 1.0), Vector3(0, 0, 90), 10)


func _build_kiosk() -> void:
	radius = 1.8
	value = 1_500_000
	var body := FX.mat(Color(0.85, 0.85, 0.88), 0.3, 0.5)
	MechBuilder.box(_visual, Vector3(1.4, 2.2, 1.0), Vector3(0, 1.1, 0), body)
	var c: Color = [Color(1.0, 0.2, 0.4), Color(0.2, 0.8, 1.0), Color(1.0, 0.8, 0.2)][randi() % 3]
	MechBuilder.box(_visual, Vector3(1.2, 1.4, 0.1), Vector3(0, 1.3, -0.52), FX.glow(c, 3.0))


func drive(delta: float) -> void:
	if crushed or drive_speed <= 0.0:
		return
	position += Vector3(drive_dir.x, 0, drive_dir.y) * drive_speed * delta
	var lim := World.HALF + 6.0
	if position.x > lim:
		position.x = -lim
	elif position.x < -lim:
		position.x = lim
	if position.z > lim:
		position.z = -lim
	elif position.z < -lim:
		position.z = lim


func crush(by_player: bool) -> void:
	if crushed:
		return
	crushed = true
	drive_speed = 0.0
	Game.add_collateral(value)
	if by_player:
		Game.on_prop_crushed()
	var p := global_position
	match kind:
		"car":
			var wreck := FX.mat(Color(0.07, 0.07, 0.08), 0.3, 0.8)
			for c in _visual.get_children():
				(c as MeshInstance3D).material_override = wreck
			var tw := create_tween()
			tw.tween_property(_visual, "scale", Vector3(1.2, 0.25, 1.1), 0.07)
			FX.sparks(p + Vector3(0, 1, 0), Color(1.0, 0.8, 0.4), 8)
			World.debris(p + Vector3(0, 1.5, 0), 2, color, 0.5, 9.0)
			if randf() < 0.35:
				get_tree().create_timer(randf_range(0.15, 0.45), false).timeout.connect(_explode)
		"lamp":
			FX.sparks(p + Vector3(0, 5, 0), Color(0.7, 0.85, 1.0), 10)
			World.debris(p + Vector3(0, 3, 0), 2, Color(0.3, 0.3, 0.32), 0.4, 6.0)
			visible = false
		"tree", "pine":
			World.debris(p + Vector3(0, 3, 0), 3, Color(0.08, 0.25, 0.1), 0.7, 7.0)
			FX.burst(p + Vector3(0, 3, 0), Color(0.3, 0.8, 0.3), 8, 8.0, 0.6, 0.5, -15.0, 120.0, 1.5)
			visible = false
		"haybale":
			World.debris(p + Vector3(0, 1, 0), 2, Color(0.6, 0.48, 0.2), 0.5, 7.0)
			FX.burst(p + Vector3(0, 1, 0), Color(0.9, 0.75, 0.3), 12, 10.0, 0.8, 0.4, -12.0, 140.0, 1.5)
			visible = false
		_:
			FX.sparks(p + Vector3(0, 1, 0), Color(1.0, 0.9, 0.5), 8)
			World.debris(p + Vector3(0, 1, 0), 2, Color(0.8, 0.8, 0.85), 0.5, 7.0)
			visible = false
	if randf() < 0.5:
		World.spawn_shards(pos2(), 1)


func _explode() -> void:
	World.explode(pos2(), 9.0, 28.0, Bullets.TEAM_PLAYER, 1.2)
	FX.burst(global_position + Vector3(0, 1, 0), Color(1.0, 0.5, 0.1), 16, 5.0, 1.5, 1.0, 6.0, 30.0, 4.0)
