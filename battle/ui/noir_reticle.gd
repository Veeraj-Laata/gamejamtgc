class_name NoirReticle
extends Control
## Target marker: four rotating corner brackets and a bobbing pointer.
## Position this control at the target's screen anchor (size is ignored).

var color: Color = Color(0.92, 0.95, 1.0)
var accent: Color = Color(0.95, 0.04, 0.10)
var radius: float = 44.0
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_t = randf() * 3.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var r: float = radius + sin(_t * 8.0) * 3.0
	var arm: float = r * 0.5
	var rot: float = _t * 0.7
	for i in 4:
		var sx: float = 1.0 if (i % 2 == 0) else -1.0
		var sy: float = 1.0 if (i < 2) else -1.0
		var corner: Vector2 = Vector2(sx * r, sy * r).rotated(rot)
		var a: Vector2 = corner + Vector2(-sx * arm, 0).rotated(rot)
		var b: Vector2 = corner + Vector2(0, -sy * arm).rotated(rot)
		draw_polyline(PackedVector2Array([a + Vector2(2, 2), corner + Vector2(2, 2), b + Vector2(2, 2)]), Color(accent, 0.9), 4.0)
		draw_polyline(PackedVector2Array([a, corner, b]), color, 2.5)

	# pointer above
	var bob: float = sin(_t * 6.0) * 4.0
	var tip: Vector2 = Vector2(0, -r * 1.55 + bob)
	var tri: PackedVector2Array = PackedVector2Array([
		tip + Vector2(-11, -18), tip + Vector2(11, -18), tip
	])
	draw_colored_polygon(tri, color)
	draw_polyline(PackedVector2Array([tri[0], tri[2], tri[1]]), accent, 2.0)
