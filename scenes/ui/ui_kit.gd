extends RefCounted
## Small helpers for building the code-driven UI with a consistent mecha style.

const CYAN := Color(0.35, 0.92, 1.0)
const PANEL := Color(0.02, 0.04, 0.09, 0.92)


static func label(text: String, font_size: int, color: Color = Color.WHITE, outline: int = 6) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(2)
	s.skew = Vector2(-0.08, 0)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


static func button(text: String, accent: Color = CYAN, font_size: int = 28) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(320, 64)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.4))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", style(PANEL, accent.darkened(0.3), 2))
	b.add_theme_stylebox_override("hover", style(accent.darkened(0.6), accent, 4))
	b.add_theme_stylebox_override("focus", style(accent.darkened(0.6), accent, 4))
	b.add_theme_stylebox_override("pressed", style(accent.darkened(0.3), Color.WHITE, 4))
	return b


static func full_rect(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0
	return c


static func yen(amount: int) -> String:
	var s := str(amount)
	var out := ""
	var n := s.length()
	for i in n:
		out += s[i]
		var rem := n - i - 1
		if rem > 0 and rem % 3 == 0:
			out += ","
	return "¥" + out
