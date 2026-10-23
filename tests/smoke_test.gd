extends Node
## Headless gameplay smoke test. Drives a real run through the core systems and
## exits non-zero if anything fails.
## Run: godot --headless --fixed-fps 60 res://tests/smoke_test.tscn

const Run := preload("res://scenes/run/run.gd")

var _failures: Array = []
var run


func _ready() -> void:
	_main.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_failures.append(what)


func _frames(n: int) -> void:
	for k in n:
		await get_tree().physics_frame


func _god_mode() -> void:
	Game.stats.max_hp = 1e9
	Game.player_hp = 1e9


func _main() -> void:
	Game.new_run(12345)
	_god_mode()
	run = Run.new()
	add_child(run)
	await _frames(5)
	var player = World.player
	_check(player != null, "player spawned")
	_check(World.buildings.size() > 10, "city generated buildings (%d)" % World.buildings.size())
	_check(World.arena.props.size() > 10, "city generated props (%d)" % World.arena.props.size())
	_check(World.arena.traffic.size() > 0, "traffic is driving (%d cars)" % World.arena.traffic.size())

	await _frames(140)
	_check(World.enemies.size() + run.pending > 0, "first wave dropping in")

	# Weapon fires bullets.
	player.auto_input = {"move": Vector2.ZERO, "aim": Vector2(-1, -1).normalized(), "fire": true}
	await _frames(20)
	_check(Bullets.count_team(Bullets.TEAM_PLAYER) > 0, "player weapon spawns bullets")
	player.auto_input = {"move": Vector2.ZERO, "aim": Vector2(-1, -1).normalized(), "fire": false}

	# A bullet fired into a building damages it.
	var b = World.buildings[0]
	var hp0: float = b.hp
	var start: Vector2 = Vector2(b.rect.position.x - 3.0, b.center.y)
	Bullets.spawn(Bullets.TEAM_PLAYER, start, Vector2(80, 0), 10.0, 0.8, Color.CYAN)
	await _frames(6)
	_check(b.hp < hp0, "bullet damages building (%.1f -> %.1f)" % [hp0, b.hp])

	# Collapse.
	var count0 := World.buildings.size()
	b.take_damage(1e6)
	await _frames(2)
	_check(b.collapsed and World.buildings.size() == count0 - 1, "building collapses and leaves the grid")
	_check(World.debris_pool.active_count() > 0, "collapse throws debris (%d chunks)" % World.debris_pool.active_count())
	await _frames(120)
	_check(is_instance_valid(b), "collapsed building leaves rubble node")

	# Walking onto a car crushes it.
	var car = null
	for p in World.arena.props:
		if p.kind == "car" and not p.crushed and p.drive_speed == 0.0:
			car = p
			break
	_check(car != null, "found a parked car")
	if car != null:
		var collateral0 := Game.collateral
		player.global_position = Vector3(car.position.x, 0, car.position.z)
		await _frames(3)
		_check(car.crushed, "player crushes car underfoot")
		_check(Game.collateral > collateral0, "collateral counter increases")

	# Pushing into a building grinds it down.
	var target = null
	for bb in World.buildings:
		if bb.kind != "container" and bb.size.x > 6.0:
			target = bb
			break
	if target != null:
		var thp: float = target.hp
		player.global_position = Vector3(target.rect.position.x - 4.5, 0, target.center.y)
		player.auto_input = {"move": Vector2(1, 0), "aim": Vector2(1, 0), "fire": false}
		await _frames(30)
		_check(target.collapsed or target.hp < thp, "pushing into a building damages it")
		player.auto_input = {"move": Vector2.ZERO, "aim": Vector2(1, 0), "fire": false}

	# Kill an enemy.
	for k in 120:
		if not World.enemies.is_empty() and World.enemies[0].targetable:
			break
		await _frames(1)
	_check(not World.enemies.is_empty(), "enemies on the field")
	if not World.enemies.is_empty():
		var e = World.enemies[0]
		Game.hit_enemy(e, 1e6)
		await _frames(2)
		_check(not is_instance_valid(e) or not e.alive, "enemy dies")
		_check(Game.kills >= 1, "kill counted")

	# Let the AI fight for a while (enemy patterns, explosions, shells) under god mode.
	player.auto_input = {"move": Vector2(0.3, -0.3), "aim": Vector2(-1, -1).normalized(), "fire": true}
	await _frames(600)
	_check(Bullets.count_team(Bullets.TEAM_ENEMY) > 0 or World.enemies.size() > 0, "combat running")

	# Clear the stage.
	for k in 4000:
		if run.state == run.State.CLEARED:
			break
		if k % 10 == 0:
			run.debug_kill_all()
		await _frames(1)
	_check(run.state == run.State.CLEARED, "stage clears after all waves")
	_check(World.arena.gate_open, "extraction gate opens")

	# Walk into the gate, pick an upgrade.
	player.auto_input = {"move": Vector2.ZERO, "aim": Vector2(-1, -1), "fire": false}
	player.global_position = Vector3(World.arena.gate_pos.x, 0, World.arena.gate_pos.y)
	await _frames(3)
	_check(run.state == run.State.CHOOSING and run._choice.visible, "upgrade choice opens at gate")
	_check(get_tree().paused, "game paused during choice")
	var picked: String = run._choice._choices[0].id
	run._choice._pick(0)
	await _frames(10)
	_check(Game.stacks(picked) == 1, "upgrade '%s' applied" % picked)
	_check(Game.stage_index == 1, "advanced to stage 2")
	_check(World.player != null and World.player != player, "new stage built with fresh player")
	_god_mode()

	# Apply every power-up to stress the weapon code paths.
	for p in preload("res://data/powerups.gd").LIST:
		Game.apply_powerup(p.id)
	_god_mode()
	await _frames(150)
	World.player.auto_input = {"move": Vector2.ZERO, "aim": Vector2(-1, -1).normalized(), "fire": true}
	await _frames(240)
	_check(Bullets.count_team(Bullets.TEAM_PLAYER) > 10, "fully upgraded weapon fires (%d bullets)" % Bullets.count_team(Bullets.TEAM_PLAYER))

	# Bullet stress test.
	Bullets.clear()
	var pp := World.xz(World.player.global_position)
	for k in 2000:
		var p := Vector2(randf_range(-65, 65), randf_range(-65, 65))
		if p.distance_to(pp) < 20.0:
			continue
		Bullets.spawn(Bullets.TEAM_ENEMY, p, Vector2.from_angle(randf() * TAU) * 5.0, 1.0, 1.0, Color.MAGENTA, 30.0)
	var total := 0
	for k in 30:
		await _frames(1)
		total += Bullets.last_step_usec
	print("      bullet step with %d bullets: %.2f ms avg" % [Bullets.count, total / 30.0 / 1000.0])
	_check(total / 30.0 < 16000.0, "bullet manager under 16ms with ~2000 bullets")
	Bullets.clear()

	# Boss stage.
	run._build_stage.call_deferred(Game.stage_count() - 1)
	await _frames(5)
	_god_mode()
	await _frames(320)
	var boss = run.boss
	_check(boss != null and is_instance_valid(boss), "kaiju boss spawned")
	if boss != null:
		# Hold fire: a fully upgraded mech would delete the boss before the checks.
		World.player.auto_input = {"move": Vector2.ZERO, "aim": Vector2(1, 1).normalized(), "fire": false}
		await _frames(240)
		_check(Bullets.count_team(Bullets.TEAM_ENEMY) > 0, "boss fires bullet patterns (%d)" % Bullets.count_team(Bullets.TEAM_ENEMY))
		boss.take_damage(boss.max_hp * 0.4)
		await _frames(200)
		_check(boss.phase == 2, "boss enters phase 2")
		boss.take_damage(boss.max_hp * 0.35)
		await _frames(420)
		_check(boss.phase == 3, "boss enters phase 3")
		boss.take_damage(1e9)
		await _frames(30)
		_check(run.victory and run.state == run.State.OVER, "boss defeat triggers victory")
		await _frames(300)
		_check(run.end_screen != null, "victory screen shown")

	print("\n%d failure(s)" % _failures.size())
	get_tree().paused = false
	get_tree().quit(1 if not _failures.is_empty() else 0)
