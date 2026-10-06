class_name NoirBar
extends Control
## Slanted bar with diagonal hatching. On damage the colour drops instantly and
## a pale ghost slab drains after a short delay.

@export var max_value: float = 100.0
@export var value: float = 100.0
@export var fill_color: Color = Color(0.02, 0.16, 0.95)
@export var ghost_color: Color = Color(0.85, 0.90, 1.0)
@export var back_color: Color = Color(0.01, 0.015, 0.04)
@export var line_color: Color = Color(0.86, 0.90, 1.0)
@export var slant: float = 6.0

var _ghost: float = 100.0
var _tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost = value


func set_values(new_value: float, new_max: float) -> void:
	if is_equal_approx(new_value, value) and is_equal_approx(new_max, max_value):
		return
	max_value = maxf(new_max, 1.0)
	var old: float = value
	value = clampf(new_value, 0.0, max_value)
	if _tween != null:
		_tween.kill()
	if value >= old:
		_ghost = value
		queue_redraw()
		return
	queue_redraw()
	_tween = create_tween()
	_tween.tween_interval(0.35)
	_tween.tween_method(_set_ghost, _ghost, value, 0.45)


func snap() -> void:
	_ghost = value
	queue_redraw()


func _set_ghost(v: float) -> void:
	_ghost = v
	queue_redraw()


func _slab(x1: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(slant, 0), Vector2(x1 + slant, 0), Vector2(x1, size.y), Vector2(0, size.y)
	])


func _draw() -> void:
	var span: float = size.x - slant
	if span < 2.0:
		return
	draw_colored_polygon(_slab(span), back_color)
	var gx: float = span * _ghost / max_value
	var vx: float = span * value / max_value
	if gx > vx and gx > 1.0:
		draw_colored_polygon(_slab(gx), ghost_color)
	if vx > 1.0:
		draw_colored_polygon(_slab(vx), fill_color)
		# hatching inside the fill
		var x: float = 4.0
		while x < vx:
			draw_line(Vector2(x + slant, 0), Vector2(x, size.y), Color(0, 0, 0, 0.35), 1.0)
			x += 6.0
	var o: PackedVector2Array = _slab(span)
	o.append(o[0])
	draw_polyline(o, line_color, 1.5, true)
