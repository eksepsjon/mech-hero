extends Node
## Run state that survives between stages: stage index, player stats and hull,
## owned power-ups and score counters. Also builds the input map and resolves
## player damage against enemies (crits, burn, chain lightning, lifesteal).

signal stats_changed
signal player_damaged

const PowerUps := preload("res://data/powerups.gd")
const Stages := preload("res://data/stages.gd")

const BASE_STATS := {
	"max_hp": 120.0,
	"damage": 10.0,
	"fire_rate": 6.0,
	"bullet_speed": 85.0,
	"move_speed": 24.0,
	"dash_cd": 1.4,
	"front": 1,
	"diagonal": 0,
	"side": 0,
	"rear": 0,
	"pierce": 0,
	"bounce": 0,
	"crit": 0.05,
	"crit_mult": 2.0,
	"orbitals": 0,
	"missiles": 0,
	"chain": 0,
	"burn": 0,
	"lifesteal": 0,
	"demolisher": 0,
	"rampage": 0,
}

var stats: Dictionary = {}
var owned: Dictionary = {}
var stage_index := 0
var kills := 0
var collateral := 0
var player_hp := 0.0
var rampage_time := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	_setup_input()
	new_run()


func _process(delta: float) -> void:
	rampage_time = maxf(rampage_time - delta, 0.0)


func new_run(seed_value: int = 0) -> void:
	stats = BASE_STATS.duplicate()
	owned.clear()
	stage_index = 0
	kills = 0
	collateral = 0
	rampage_time = 0.0
	player_hp = stats.max_hp
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	stats_changed.emit()


func stage_count() -> int:
	return Stages.STAGES.size()


func current_stage() -> Dictionary:
	return Stages.STAGES[stage_index]


func enemy_hp_mult() -> float:
	return 1.0 + 0.14 * stage_index


func stacks(id: String) -> int:
	return owned.get(id, 0)


func roll_choices(count: int = 3) -> Array:
	var pool: Array = []
	for p in PowerUps.LIST:
		if stacks(p.id) < p.max:
			pool.append(p)
	var out: Array = []
	while out.size() < count and not pool.is_empty():
		var total := 0.0
		for p in pool:
			total += p.weight
		var r := rng.randf() * total
		var pick: Dictionary = pool[pool.size() - 1]
		for p in pool:
			r -= p.weight
			if r <= 0.0:
				pick = p
				break
		out.append(pick)
		pool.erase(pick)
	return out


func apply_powerup(id: String) -> void:
	owned[id] = stacks(id) + 1
	match id:
		"multishot":
			stats.front += 1
		"diagonal":
			stats.diagonal += 1
		"side":
			stats.side += 1
		"rear":
			stats.rear += 1
		"ricochet":
			stats.bounce += 1
		"pierce":
			stats.pierce += 1
		"rapid":
			stats.fire_rate *= 1.2
		"damage":
			stats.damage *= 1.25
		"crit":
			stats.crit += 0.1
		"armor":
			stats.max_hp += 30.0
			heal(30.0)
		"thrusters":
			stats.dash_cd *= 0.75
			stats.move_speed += 2.0
		"orbitals":
			stats.orbitals += 2
		"missiles":
			stats.missiles += 2
		"chain":
			stats.chain += 1
		"burn":
			stats.burn += 1
		"lifesteal":
			stats.lifesteal += 1
		"demolisher":
			stats.demolisher += 1
		"rampage":
			stats.rampage += 1
	stats_changed.emit()


func heal(amount: float) -> void:
	player_hp = minf(player_hp + amount, float(stats.max_hp))


func add_collateral(amount: int) -> void:
	collateral += amount


## Applies one player hit to an enemy, including crit and on-hit effects.
func hit_enemy(enemy, base_damage: float, flags: int = 0) -> void:
	if not is_instance_valid(enemy) or not enemy.alive:
		return
	var dmg := base_damage
	var crit := rng.randf() < float(stats.crit)
	if crit:
		dmg *= float(stats.crit_mult)
	if stats.burn > 0:
		enemy.apply_burn(float(stats.damage) * 0.35 * float(stats.burn), 3.0)
	var chains: bool = stats.chain > 0 and (flags & Bullets.FLAG_CHAIN) == 0 and rng.randf() < 0.3
	var origin: Vector3 = enemy.global_position
	enemy.take_damage(dmg, crit)
	if chains:
		_chain_lightning(origin, enemy, dmg * 0.6)


func _chain_lightning(origin: Vector3, source, dmg: float) -> void:
	var from := origin + Vector3(0, 7, 0)
	var hit: Array = [source]
	for k in int(stats.chain) + 1:
		var next = World.nearest_enemy(Vector2(from.x, from.z), 26.0, hit)
		if next == null:
			return
		hit.append(next)
		var to: Vector3 = next.global_position + Vector3(0, 7, 0)
		FX.lightning(from, to, Color(0.55, 0.75, 1.0))
		next.take_damage(dmg, false)
		from = to


func on_enemy_killed(_enemy) -> void:
	kills += 1
	if stats.lifesteal > 0:
		heal(2.0 * float(stats.lifesteal))


func on_prop_crushed() -> void:
	if stats.rampage > 0:
		rampage_time = 1.5 + float(stats.rampage)


# --- input -------------------------------------------------------------------

func _setup_input() -> void:
	_bind("move_up", [KEY_W, KEY_UP], [], [[JOY_AXIS_LEFT_Y, -1.0]])
	_bind("move_down", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_LEFT_Y, 1.0]])
	_bind("move_left", [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_bind("move_right", [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_bind("aim_up", [], [], [[JOY_AXIS_RIGHT_Y, -1.0]])
	_bind("aim_down", [], [], [[JOY_AXIS_RIGHT_Y, 1.0]])
	_bind("aim_left", [], [], [[JOY_AXIS_RIGHT_X, -1.0]])
	_bind("aim_right", [], [], [[JOY_AXIS_RIGHT_X, 1.0]])
	_bind("fire", [], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]], [MOUSE_BUTTON_LEFT])
	_bind("dash", [KEY_SPACE, KEY_SHIFT], [JOY_BUTTON_A, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER], [[JOY_AXIS_TRIGGER_LEFT, 1.0]], [MOUSE_BUTTON_RIGHT])
	_bind("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], [])


func _bind(action: String, keys: Array, buttons: Array, axes: Array, mouse: Array = []) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.25)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var ev := InputEventJoypadButton.new()
		ev.button_index = b
		InputMap.action_add_event(action, ev)
	for a in axes:
		var ev := InputEventJoypadMotion.new()
		ev.axis = a[0]
		ev.axis_value = a[1]
		InputMap.action_add_event(action, ev)
	for m in mouse:
		var ev := InputEventMouseButton.new()
		ev.button_index = m
		InputMap.action_add_event(action, ev)
