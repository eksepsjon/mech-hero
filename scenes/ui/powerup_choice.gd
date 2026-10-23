extends CanvasLayer
## Between-stage upgrade picker: three cards, mouse / keyboard (1-3, arrows) /
## gamepad navigable. Pauses the game while open.

signal chosen(id: String)

const UI := preload("res://scenes/ui/ui_kit.gd")

var _cards: HBoxContainer
var _choices: Array = []
var _buttons: Array = []


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := UI.full_rect(Control.new())
	add_child(root)
	var bg := ColorRect.new()
	UI.full_rect(bg)
	bg.color = Color(0.0, 0.02, 0.06, 0.78)
	root.add_child(bg)
	var title := UI.label("SYSTEM UPGRADE", 56, UI.CYAN, 10)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 90
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var sub := UI.label("Select one module for your mech", 22, Color(0.7, 0.85, 1.0))
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 165
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)
	var center := CenterContainer.new()
	UI.full_rect(center)
	root.add_child(center)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 36)
	center.add_child(_cards)
	var hint := UI.label("[1] [2] [3]  ·  click  ·  D-pad + A", 18, Color(0.6, 0.7, 0.8))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -80
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)


func open(choices: Array) -> void:
	_choices = choices
	for c in _cards.get_children():
		c.queue_free()
	_buttons.clear()
	for i in choices.size():
		var b := _make_card(choices[i], i)
		_cards.add_child(b)
		_buttons.append(b)
	for i in _buttons.size():
		var b: Button = _buttons[i]
		b.focus_neighbor_left = _buttons[(i - 1 + _buttons.size()) % _buttons.size()].get_path()
		b.focus_neighbor_right = _buttons[(i + 1) % _buttons.size()].get_path()
	visible = true
	get_tree().paused = true
	(_buttons[0] as Button).grab_focus.call_deferred()


func _make_card(p: Dictionary, idx: int) -> Button:
	var color: Color = p.color
	var b := Button.new()
	b.custom_minimum_size = Vector2(300, 380)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", UI.style(UI.PANEL, color.darkened(0.35), 2))
	b.add_theme_stylebox_override("hover", UI.style(color.darkened(0.7), color, 5))
	b.add_theme_stylebox_override("focus", UI.style(color.darkened(0.7), color, 5))
	b.add_theme_stylebox_override("pressed", UI.style(color.darkened(0.5), Color.WHITE, 5))
	var v := VBoxContainer.new()
	UI.full_rect(v)
	v.offset_left = 24
	v.offset_right = -24
	v.offset_top = 22
	v.offset_bottom = -22
	v.add_theme_constant_override("separation", 14)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	v.add_child(UI.label("[%d]" % (idx + 1), 18, color.lerp(Color.WHITE, 0.3)))
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(0, 6)
	icon.color = color
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(icon)
	var name_label := UI.label(String(p.name).to_upper(), 30, color.lerp(Color.WHITE, 0.2), 8)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name_label)
	var lv := Game.stacks(p.id)
	v.add_child(UI.label("LV %d  >  %d   (max %d)" % [lv, lv + 1, p.max], 18, Color(0.7, 0.8, 0.9), 4))
	var desc := UI.label(p.desc, 22, Color.WHITE, 4)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(desc)
	b.pressed.connect(_pick.bind(idx))
	return b


func _pick(idx: int) -> void:
	if not visible or idx >= _choices.size():
		return
	visible = false
	get_tree().paused = false
	chosen.emit(String(_choices[idx].id))


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.is_pressed():
		return
	match (event as InputEventKey).physical_keycode:
		KEY_1:
			_pick(0)
		KEY_2:
			_pick(1)
		KEY_3:
			_pick(2)
