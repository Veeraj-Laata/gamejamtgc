class_name NoirMenuRow
extends Control
## One command row. The selected row gets a slanted white slab that slides in.

var text: String = ""
var sub: String = ""
var selected: bool = false
var enabled: bool = true
var font: Font = null
var font_size: int = 26
var accent: Color = Color(0.02, 0.16, 0.95)

var _slide: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(300, 38)


func _process(delta: float) -> void:
	_t += delta
	var goal: float = 1.0 if selected else 0.0
	_slide = move_toward(_slide, goal, delta * 8.0)
	queue_redraw()


func _draw() -> void:
	var f: Font = font if font != null else ThemeDB.fallback_font
	var w: float = size.x
	var h: float = size.y
	var base_y: float = (h + f.get_ascent(font_size) - f.get_descent(font_size)) * 0.5

	var text_color: Color = Color(0.82, 0.88, 1.0)
	if not enabled:
		text_color = Color(0.30, 0.34, 0.48)

	if _slide > 0.01:
		var sw: float = w * _slide
		var skew: float = 12.0
		var slab: Color = Color(0.92, 0.95, 1.0)
		if not enabled:
			slab = Color(0.45, 0.48, 0.60)
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, 0), Vector2(sw, 0), Vector2(sw - skew, h), Vector2(0, h)
		]), slab)
		draw_line(Vector2(sw, 0), Vector2(sw - skew, h), accent, 4.0)
		text_color = Color(0.01, 0.02, 0.07)

	var tx: float = 14.0 + 10.0 * _slide
	draw_string(f, Vector2(tx, base_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	if sub != "":
		draw_string(f, Vector2(0, base_y), sub, HORIZONTAL_ALIGNMENT_RIGHT, w - 22.0, font_size - 6, text_color)
