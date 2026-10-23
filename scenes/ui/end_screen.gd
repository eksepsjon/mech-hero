extends CanvasLayer
## Victory / defeat screen with run stats.

signal restart_requested
signal menu_requested

const UI := preload("res://scenes/ui/ui_kit.gd")

var victory := false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var root := UI.full_rect(Control.new())
	add_child(root)
	var bg := ColorRect.new()
	UI.full_rect(bg)
	bg.color = Color(0.0, 0.02, 0.06, 0.82)
	root.add_child(bg)
	var center := CenterContainer.new()
	UI.full_rect(center)
	root.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)
	var accent := Color(0.4, 1.0, 0.8) if victory else Color(1.0, 0.3, 0.35)
	var title := UI.label("KAIJU NEUTRALIZED" if victory else "MECH DESTROYED", 72, accent, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var stages := Game.stage_index + (1 if victory else 0)
	for line in [
		"Stages cleared   %d / %d" % [stages, Game.stage_count()],
		"Hostiles destroyed   %d" % Game.kills,
		"Collateral damage   %s" % UI.yen(Game.collateral),
		"Upgrades installed   %d" % Game.owned.size(),
	]:
		var l := UI.label(line, 26, Color(0.85, 0.9, 1.0))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	v.add_child(spacer)
	var again := UI.button("REDEPLOY", accent)
	again.pressed.connect(_on_restart)
	v.add_child(again)
	var menu := UI.button("MAIN MENU", Color(0.6, 0.7, 0.85))
	menu.pressed.connect(_on_menu)
	v.add_child(menu)
	again.grab_focus.call_deferred()


func _on_restart() -> void:
	get_tree().paused = false
	restart_requested.emit()


func _on_menu() -> void:
	get_tree().paused = false
	menu_requested.emit()
