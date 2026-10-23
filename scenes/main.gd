extends Node
## Top-level flow: title screen ⇄ run.

const Run := preload("res://scenes/run/run.gd")
const MainMenu := preload("res://scenes/ui/main_menu.gd")
const MenuBackdrop := preload("res://scenes/ui/menu_backdrop.gd")

var _current: Array = []


func _ready() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	_show_menu()


func _clear() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	for n in _current:
		if is_instance_valid(n):
			remove_child(n)
			n.queue_free()
	_current.clear()
	Bullets.clear()
	World.reset()


func _show_menu() -> void:
	_clear()
	var backdrop = MenuBackdrop.new()
	add_child(backdrop)
	var menu = MainMenu.new()
	add_child(menu)
	menu.start_requested.connect(_start_run, CONNECT_DEFERRED)
	_current = [backdrop, menu]


func _start_run() -> void:
	_clear()
	Game.new_run()
	var run = Run.new()
	run.request_menu.connect(_show_menu, CONNECT_DEFERRED)
	run.request_restart.connect(_start_run, CONNECT_DEFERRED)
	add_child(run)
	_current = [run]
