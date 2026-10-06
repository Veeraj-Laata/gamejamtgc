class_name NoirActionText
extends Control
## Big action name with a colour wave that sweeps across the letters.

var text: String = ""
var font: Font = null
var font_size: int = 60
var base_color: Color = Color(0.92, 0.95, 1.0)
var wave_color: Color = Color(0.02, 0.16, 0.95)
var progress: float = -0.3:
	set(v):
		progress = v
		queue_redraw()
var _tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func play(sweeps: int = 1) -> void:
	if _tween != null:
		_tween.kill()
	progress = -0.3
	_tween = create_tween()
	for i in sweeps:
		_tween.tween_property(self, "progress", 1.3, 0.6).from(-0.3)


func _draw() -> void:
	if text == "":
		return
	var f: Font = font if font != null else ThemeDB.fallback_font
	var total: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x0: float = (size.x - total) * 0.5
	var x: float = x0
	var base_y: float = (size.y + f.get_ascent(font_size) - f.get_descent(font_size)) * 0.5
	for i in text.length():
		var ch: String = text.substr(i, 1)
		var w: float = f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var u: float = (x - x0 + w * 0.5) / maxf(total, 1.0)
		var k: float = 1.0 - clampf(absf(u - progress) / 0.16, 0.0, 1.0)
		var col: Color = base_color.lerp(wave_color.lerp(Color(1, 1, 1, 1), 0.35), k)
		var pos: Vector2 = Vector2(x, base_y - k * 7.0)
		draw_string_outline(f, pos + Vector2(3, 3), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 1, wave_color)
		draw_string(f, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
		x += w
