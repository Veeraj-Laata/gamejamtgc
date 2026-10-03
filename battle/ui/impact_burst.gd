class_name ImpactBurst
extends Control
## Jagged comic burst with text, speed lines, pop-in and fade-out.
## Make one with ImpactBurst.make(...), add_child it, set position, call play().

var text: String = ""
var fill_color: Color = Color(0.92, 0.95, 1.0)
var text_color: Color = Color(0.01, 0.02, 0.07)
var outline_color: Color = Color(0, 0, 0, 1)
var accent: Color = Color(0.02, 0.16, 0.95)
var radius: float = 54.0
var spikes: int = 11
var font: Font = null
var font_size: int = 40

var _pts: PackedVector2Array = PackedVector2Array()
var _line_alpha: float = 1.0
var _lines: Array[Vector2] = []


static func make(p_text: String, p_fill: Color, p_text_color: Color, p_radius: float, p_font: Font, p_font_size: int) -> ImpactBurst:
	var b: ImpactBurst = ImpactBurst.new()
	b.text = p_text
	b.fill_color = p_fill
	b.text_color = p_text_color
	b.radius = p_radius
	b.font = p_font
	b.font_size = p_font_size
	return b


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2.ONE * radius * 3.0
	pivot_offset = size * 0.5
	_build()


func _build() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var c: Vector2 = size * 0.5
	var count: int = spikes * 2
	_pts = PackedVector2Array()
	for i in count:
		var ang: float = TAU * float(i) / float(count) + rng.randf_range(-0.07, 0.07)
		var r: float = radius * rng.randf_range(0.9, 1.12)
		if i % 2 == 1:
			r = radius * 0.55 * rng.randf_range(0.85, 1.15)
		_pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	_lines.clear()
	for i in 14:
		var a: float = TAU * float(i) / 14.0 + rng.randf_range(-0.1, 0.1)
		_lines.append(Vector2(cos(a), sin(a)))
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = size * 0.5
	for d in _lines:
		draw_line(c + d * radius * 1.25, c + d * radius * 1.55, Color(1, 1, 1, _line_alpha), 3.0)

	var shadow: PackedVector2Array = PackedVector2Array()
	for p in _pts:
		shadow.append(p + Vector2(6, 6))
	draw_colored_polygon(shadow, accent)
	draw_colored_polygon(_pts, fill_color)
	var closed: PackedVector2Array = _pts.duplicate()
	closed.append(_pts[0])
	draw_polyline(closed, outline_color, 4.0, true)

	if text != "":
		var f: Font = font if font != null else ThemeDB.fallback_font
		var y: float = c.y + (f.get_ascent(font_size) - f.get_descent(font_size)) * 0.5
		draw_string_outline(f, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, 6, Color(1, 1, 1, 0.9))
		draw_string(f, Vector2(0, y), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, text_color)


func play(hold: float = 0.45, rise: float = 40.0) -> void:
	rotation = randf_range(-0.2, 0.2)
	scale = Vector2(0.25, 0.25)
	var start_pos: Vector2 = position
	var t: Tween = create_tween()
	t.tween_property(self, "scale", Vector2(1.3, 1.3), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE, 0.07)
	t.parallel().tween_method(_set_line_alpha, 1.0, 0.0, 0.25)
	t.tween_property(self, "position", start_pos + Vector2(0, -rise), hold + 0.25)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.25).set_delay(hold)
	t.tween_callback(queue_free)


func _set_line_alpha(v: float) -> void:
	_line_alpha = v
	queue_redraw()
