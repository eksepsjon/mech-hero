extends Node3D
## One run of the game. Builds each stage, drops enemy waves in, and drives the
## loop: clear → extraction gate → pick an upgrade → next stage, through to the
## kaiju boss and the victory / defeat screens.

signal request_menu
signal request_restart

const IsoCamera := preload("res://scenes/run/iso_camera.gd")
const Env := preload("res://scenes/run/environment.gd")
const Arena := preload("res://scenes/arena/arena.gd")
const Player := preload("res://scenes/player/player_mech.gd")
const Hud := preload("res://scenes/ui/hud.gd")
const PowerupChoice := preload("res://scenes/ui/powerup_choice.gd")
const EndScreen := preload("res://scenes/ui/end_screen.gd")
const PauseMenu := preload("res://scenes/ui/pause_menu.gd")
const EnemyFactory := preload("res://scenes/enemies/enemy_factory.gd")
const Telegraph := preload("res://scenes/fx/telegraph.gd")

enum State { INTRO, FIGHTING, CLEARED, CHOOSING, OVER }

var state := State.INTRO
var camera
var hud
var arena
var player
var boss = null
var pending := 0
var victory := false
var end_screen = null

var _env: Node3D
var _choice
var _waves: Array = []
var _wave_index := 0
var _last_wave_size := 0
var _intro := 0.0
var _token := 0


func _ready() -> void:
	World.run = self
	camera = IsoCamera.new()
	add_child(camera)
	camera.make_current()
	hud = Hud.new()
	add_child(hud)
	_choice = PowerupChoice.new()
	add_child(_choice)
	_choice.chosen.connect(_on_powerup_chosen)
	var pause = PauseMenu.new()
	add_child(pause)
	pause.quit_requested.connect(_emit_menu)
	_build_stage(Game.stage_index)


func _exit_tree() -> void:
	if World.run == self:
		World.run = null


func is_boss_stage() -> bool:
	return Game.current_stage().get("boss", false)


func _build_stage(index: int) -> void:
	_token += 1
	Game.stage_index = index
	Bullets.clear()
	if arena != null:
		remove_child(arena)
		arena.queue_free()
	if _env != null:
		remove_child(_env)
		_env.queue_free()
	World.reset()
	World.run = self
	var def := Game.current_stage()
	_env = Env.build(is_boss_stage())
	add_child(_env)
	arena = Arena.new()
	arena.variant = def.variant
	arena.gen_seed = Game.rng.randi()
	add_child(arena)
	player = Player.new()
	arena.add_child(player)
	player.global_position = Vector3(arena.spawn_pos.x, 0, arena.spawn_pos.y)
	player.died.connect(_on_player_died)
	player.drop_in()
	camera.target = player
	camera.zoom = 98.0 if is_boss_stage() else 84.0
	camera.snap_to(player.global_position)
	_waves = def.get("waves", [])
	_wave_index = 0
	_last_wave_size = 0
	pending = 0
	boss = null
	state = State.INTRO
	_intro = 1.8
	hud.hide_boss()
	hud.show_banner("STAGE %d / %d" % [index + 1, Game.stage_count()], Color(0.4, 0.95, 1.0), 1.7,
			String(def["name"]).to_upper())


func _physics_process(delta: float) -> void:
	match state:
		State.INTRO:
			_intro -= delta
			if _intro <= 0.0:
				state = State.FIGHTING
				if is_boss_stage():
					_start_boss()
				else:
					_next_wave()
		State.FIGHTING:
			if boss != null:
				if is_instance_valid(boss):
					hud.set_boss(boss.hp / boss.max_hp)
			elif pending == 0:
				var alive := World.enemies.size()
				if _wave_index < _waves.size():
					if alive <= maxi(1, _last_wave_size / 4):
						_next_wave()
				elif alive == 0:
					_stage_cleared()
		State.CLEARED:
			if World.player_alive() and World.xz(player.global_position).distance_to(arena.gate_pos) < 10.0:
				_enter_gate()
	hud.refresh(self)


func _next_wave() -> void:
	var wave: Array = _waves[_wave_index]
	_wave_index += 1
	var elite_stage: bool = Game.current_stage().get("elite", false)
	var total := 0
	for entry in wave:
		var kind: String = entry[0]
		for k in int(entry[1]):
			spawn_enemy(kind, _find_spawn(), 0.18 * total + randf_range(0.0, 0.3), elite_stage and kind != "drone")
			total += 1
	_last_wave_size = total
	if _wave_index > 1:
		hud.show_banner("WAVE %d" % _wave_index, Color(1.0, 0.4, 0.5), 1.0, "HOSTILES INBOUND")


## Marks the drop zone, then drops an enemy from orbit after `delay`.
func spawn_enemy(kind: String, p: Vector2, delay: float, elite: bool = false) -> void:
	pending += 1
	var t = Telegraph.new()
	t.radius = 7.0
	t.duration = 1.0 + delay
	t.color = Color(1.0, 0.75, 0.2) if elite else Color(1.0, 0.25, 0.35)
	arena.add_child(t)
	t.global_position = Vector3(p.x, 0.2, p.y)
	get_tree().create_timer(1.0 + delay, false).timeout.connect(_drop_enemy.bind(kind, p, elite, _token))


func _drop_enemy(kind: String, p: Vector2, elite: bool, token: int) -> void:
	if token != _token:
		return
	pending -= 1
	var e = EnemyFactory.create(kind)
	e.elite = elite
	e.hp_mult = Game.enemy_hp_mult()
	arena.add_child(e)
	e.global_position = Vector3(p.x, 0, p.y)
	e.drop_in()


func _find_spawn() -> Vector2:
	var pp := World.xz(player.global_position)
	var best := Vector2(-40, -40)
	for attempt in 40:
		var p := Vector2(randf_range(-62.0, 62.0), randf_range(-62.0, 62.0))
		if p.distance_to(pp) < 40.0:
			continue
		best = p
		# Prefer open street, but dropping onto a roof is allowed: it gets flattened.
		if World.building_at(p, 4.0) == null or attempt > 25:
			return p
	return best


func _stage_cleared() -> void:
	state = State.CLEARED
	arena.open_gate()
	World.magnet = true
	Bullets.clear_team(Bullets.TEAM_ENEMY)
	hud.show_banner("AREA SECURED", Color(0.4, 1.0, 0.6), 2.2, "PROCEED TO THE EXTRACTION GATE")


func _enter_gate() -> void:
	state = State.CHOOSING
	FX.shockwave(Vector3(arena.gate_pos.x, 0.3, arena.gate_pos.y), 20.0, Color(0.3, 1.0, 0.5), 0.5)
	var choices := Game.roll_choices(3)
	if choices.is_empty():
		_advance()
	else:
		_choice.open(choices)


func _on_powerup_chosen(id: String) -> void:
	Game.apply_powerup(id)
	_advance()


func _advance() -> void:
	Game.heal(float(Game.stats.max_hp) * 0.2)
	_build_stage.call_deferred(Game.stage_index + 1)


func _start_boss() -> void:
	hud.show_banner("KAIJU WARNING", Color(1.0, 0.2, 0.3), 3.0, "CATEGORY IV SIGNATURE: LEVIATHAN")
	var e = EnemyFactory.create("leviathan")
	e.hp_mult = 1.0
	arena.add_child(e)
	# Close enough that the emergence happens on screen, ahead of the player.
	var p: Vector2 = arena.spawn_pos + (arena.gate_pos - arena.spawn_pos).normalized() * 48.0
	e.global_position = Vector3(p.x, 0, p.y)
	e.begin_rise()
	e.defeated.connect(_on_boss_defeated)
	boss = e
	hud.show_boss("LEVIATHAN")
	for k in 2:
		spawn_enemy("walker", _find_spawn(), 2.5 + k * 0.5)


func _on_boss_defeated() -> void:
	victory = true
	state = State.OVER
	hud.set_boss(0.0)
	Bullets.clear_team(Bullets.TEAM_ENEMY)
	for e in World.enemies.duplicate():
		e.take_damage(1e9, false, false)
	hud.show_banner("KAIJU NEUTRALIZED", Color(0.4, 1.0, 0.8), 3.0, "THE CITY STILL STANDS (MOSTLY)")
	get_tree().create_timer(4.0, false).timeout.connect(_show_end)


func _on_player_died() -> void:
	if state == State.OVER:
		return
	state = State.OVER
	hud.show_banner("HULL BREACH", Color(1.0, 0.25, 0.3), 2.0, "MECH LOST")
	get_tree().create_timer(2.2, false).timeout.connect(_show_end)


func _show_end() -> void:
	end_screen = EndScreen.new()
	end_screen.victory = victory
	add_child(end_screen)
	end_screen.restart_requested.connect(_emit_restart)
	end_screen.menu_requested.connect(_emit_menu)


func _emit_restart() -> void:
	request_restart.emit()


func _emit_menu() -> void:
	request_menu.emit()


## Test / debug helper: destroys every enemy currently on the field.
func debug_kill_all() -> void:
	for e in World.enemies.duplicate():
		if e.targetable:
			e.take_damage(1e9, false, false)
