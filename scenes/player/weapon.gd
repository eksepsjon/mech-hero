extends Node
## Player arm cannons and missile pods. Reads the current stats every shot so
## stacked power-ups (multishot, fans, rear guns, pierce, ricochet) just work.

const SHOT_COLOR := Color(0.35, 0.95, 1.0)
const MISSILE_COLOR := Color(1.0, 0.55, 0.2)

var player
var _cool := 0.0
var _missile_cool := 1.0
var _arm := 1.0


func update(delta: float, firing: bool, aim: Vector2) -> void:
	_cool -= delta
	var rate: float = Game.stats.fire_rate * (1.5 if Game.rampage_time > 0.0 else 1.0)
	if firing and _cool <= 0.0:
		_cool = 1.0 / rate
		fire(aim)
	elif not firing:
		_cool = maxf(_cool, 0.0)
	if Game.stats.missiles > 0:
		_missile_cool -= delta
		if _missile_cool <= 0.0 and not World.enemies.is_empty():
			_missile_cool = 1.8
			_fire_missiles(aim)


func fire(aim: Vector2) -> void:
	var s := Game.stats
	var origin := World.xz(player.global_position)
	var perp := Vector2(-aim.y, aim.x)
	var front: int = s.front
	for k in front:
		var off := (k - (front - 1) * 0.5) * 1.5
		_shot(origin + aim * 5.5 + perp * off, aim)
	for k in int(s.diagonal):
		var a := deg_to_rad(26.0 + 14.0 * k)
		_shot(origin + aim * 4.0, aim.rotated(a))
		_shot(origin + aim * 4.0, aim.rotated(-a))
	if s.side > 0:
		_shot(origin + perp * 4.0, perp)
		_shot(origin - perp * 4.0, -perp)
	var rear: int = s.rear
	for k in rear:
		var a := PI + (k - (rear - 1) * 0.5) * 0.25
		_shot(origin - aim * 3.0, aim.rotated(a))
	# Alternate arms for the muzzle flash and recoil kick.
	_arm = -_arm
	var arm: Node3D = player.parts.arm_r if _arm > 0.0 else player.parts.arm_l
	var tip := arm.global_position + Vector3(aim.x, 0, aim.y) * 5.5
	FX.muzzle(Vector3(tip.x, Bullets.HEIGHT, tip.z), SHOT_COLOR)
	arm.position.z = 0.9
	arm.create_tween().tween_property(arm, "position:z", 0.0, 0.1)


func _shot(p: Vector2, d: Vector2) -> void:
	var s := Game.stats
	Bullets.spawn(Bullets.TEAM_PLAYER, p, d * float(s.bullet_speed), float(s.damage), 0.8, SHOT_COLOR,
			1.4, int(s.pierce), int(s.bounce))


func _fire_missiles(aim: Vector2) -> void:
	var s := Game.stats
	var origin := World.xz(player.global_position)
	var n: int = s.missiles
	for k in n:
		var side := -1.0 if k % 2 == 0 else 1.0
		var d := aim.rotated(side * (1.3 + 0.15 * (k / 2)))
		Bullets.spawn(Bullets.TEAM_PLAYER, origin + d * 3.0, d * 30.0, float(s.damage) * 1.3, 1.0,
				MISSILE_COLOR, 3.0, 0, 0, Bullets.FLAG_HOMING)
	FX.burst(player.global_position + Vector3(0, 12, 2), MISSILE_COLOR, 10, 10.0, 0.3, 1.0, 0.0, 70.0, 4.0)
