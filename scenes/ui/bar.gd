extends Control
## Segmented meter with a trailing "ghost" fill that shows recent losses.

var value := 1.0
var color := Color(0.3, 0.95, 1.0)
var back := Color(0.02, 0.04, 0.08, 0.8)
var segments := 10
var _ghost := 1.0


func _process(delta: float) -> void:
	_ghost = move_toward(_ghost, value, delta * 0.5) if _ghost > value else value
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, back)
	draw_rect(Rect2(0, 0, size.x * clampf(_ghost, 0.0, 1.0), size.y), Color(1, 1, 1, 0.45))
	draw_rect(Rect2(0, 0, size.x * clampf(value, 0.0, 1.0), size.y), color)
	for k in range(1, segments):
		var x := size.x * k / segments
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0, 0, 0, 0.55), 2.0)
	draw_rect(r, color.lightened(0.35), false, 2.0)
