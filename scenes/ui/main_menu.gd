extends CanvasLayer
## Title screen over the attract-mode city.

signal start_requested

const UI := preload("res://scenes/ui/ui_kit.gd")


func _ready() -> void:
	layer = 10
	var root := UI.full_rect(Control.new())
	add_child(root)
	var shade := ColorRect.new()
	UI.full_rect(shade)
	shade.color = Color(0.0, 0.01, 0.04, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	v.offset_left = 110
	v.offset_top = -260
	v.offset_bottom = 260
	v.add_theme_constant_override("separation", 14)
	root.add_child(v)
	v.add_child(UI.label("MECH HERO", 110, UI.CYAN, 16))
	v.add_child(UI.label("KAIJU DEFENSE INITIATIVE  //  HEAVY FRAME DIVISION", 24, Color(1.0, 0.45, 0.65), 6))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	v.add_child(spacer)
	var start := UI.button("DEPLOY")
	start.pressed.connect(_on_start)
	v.add_child(start)
	var quit := UI.button("QUIT", Color(0.6, 0.7, 0.85))
	quit.pressed.connect(get_tree().quit)
	v.add_child(quit)
	var help := UI.label(
		"WASD move  ·  Mouse aim  ·  LMB fire  ·  Space / RMB boost  ·  Esc pause\n" +
		"Gamepad: left stick move  ·  right stick aim + fire  ·  A / bumpers boost",
		18, Color(0.7, 0.8, 0.95), 4)
	help.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	help.offset_top = -90
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(help)
	start.grab_focus.call_deferred()


func _on_start() -> void:
	start_requested.emit()
