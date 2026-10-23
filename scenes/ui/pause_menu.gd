extends CanvasLayer
## Pause overlay toggled with Esc / Start.

signal quit_requested

const UI := preload("res://scenes/ui/ui_kit.gd")

var _resume: Button


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := UI.full_rect(Control.new())
	add_child(root)
	var bg := ColorRect.new()
	UI.full_rect(bg)
	bg.color = Color(0.0, 0.02, 0.06, 0.7)
	root.add_child(bg)
	var center := CenterContainer.new()
	UI.full_rect(center)
	root.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	center.add_child(v)
	var title := UI.label("PAUSED", 64, UI.CYAN, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	_resume = UI.button("RESUME")
	_resume.pressed.connect(_toggle)
	v.add_child(_resume)
	var quit := UI.button("ABANDON RUN", Color(1.0, 0.4, 0.4))
	quit.pressed.connect(_quit)
	v.add_child(quit)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		# Don't steal pause while another overlay (upgrade pick, end screen) owns it.
		if not visible and get_tree().paused:
			return
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		_resume.grab_focus.call_deferred()


func _quit() -> void:
	visible = false
	get_tree().paused = false
	quit_requested.emit()
