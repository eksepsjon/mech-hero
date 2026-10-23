extends Node
## Plays a scripted run and saves screenshots for visual checks.
## Run (needs a display, e.g. xvfb-run):
##   godot --path . --fixed-fps 60 res://tests/screenshot.tscn -- <out_dir>

const Run := preload("res://scenes/run/run.gd")
const MainMenu := preload("res://scenes/ui/main_menu.gd")
const MenuBackdrop := preload("res://scenes/ui/menu_backdrop.gd")

var _out := "user://shots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_main.call_deferred()


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("saved ", name)


func _drive(player, t: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	Game.player_hp = Game.stats.max_hp
	var target = World.nearest_enemy(World.xz(player.global_position), 200.0)
	var aim := Vector2(-1, -1).normalized()
	if target != null:
		aim = (World.xz(target.global_position) - World.xz(player.global_position)).normalized()
	player.auto_input = {"move": Vector2(cos(t * 0.7), sin(t * 0.9)) * 0.6, "aim": aim, "fire": true}


func _main() -> void:
	var backdrop = MenuBackdrop.new()
	add_child(backdrop)
	var menu = MainMenu.new()
	add_child(menu)
	await _frames(90)
	await _shot("01_menu")
	backdrop.queue_free()
	menu.queue_free()
	World.reset()
	await _frames(2)

	Game.new_run(777)
	var run = Run.new()
	add_child(run)
	await _frames(40)
	await _shot("02_drop")
	for k in 360:
		_drive(World.player, k / 60.0)
		await _frames(1)
	await _shot("03_combat")
	for k in 300:
		_drive(World.player, 6.0 + k / 60.0)
		await _frames(1)
	await _shot("04_combat_later")

	# One combat shot per district type.
	for stage in [1, 2, 3]:
		run._build_stage.call_deferred(stage)
		await _frames(260)
		for k in 200:
			_drive(World.player, k / 60.0)
			await _frames(1)
		await _shot("04_%s" % Game.current_stage().variant)

	# Stage with mixed elites and spinners, partly upgraded.
	for id in ["multishot", "multishot", "diagonal", "orbitals", "missiles", "ricochet"]:
		Game.apply_powerup(id)
	run._build_stage.call_deferred(6)
	await _frames(400)
	for k in 420:
		_drive(World.player, k / 60.0)
		await _frames(1)
	await _shot("05_bullet_hell")

	run._choice.open(Game.roll_choices(3))
	await _frames(10)
	await _shot("06_upgrade_choice")
	run._choice._pick(0)
	await _frames(2)

	run._build_stage.call_deferred(Game.stage_count() - 1)
	await _frames(250)
	await _shot("07_boss_rise")
	for k in 420:
		_drive(World.player, k / 60.0)
		await _frames(1)
	await _shot("08_boss_fight")
	if run.boss != null and is_instance_valid(run.boss):
		run.boss.take_damage(run.boss.hp - run.boss.max_hp * 0.3)
		await _frames(150)
		for k in 200:
			_drive(World.player, k / 60.0)
			await _frames(1)
			if run.boss._laser_state == 2:
				break
		await _shot("09_boss_enraged")
	get_tree().quit()
