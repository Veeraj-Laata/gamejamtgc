extends Control


const PANEL_COLOR: Color = Color(
	0.004,
	0.006,
	0.010,
	0.97
)

const PANEL_COLOR_2: Color = Color(
	0.010,
	0.014,
	0.022,
	0.97
)

const WHITE: Color = Color(
	0.88,
	0.89,
	0.91,
	1.0
)

const SUBTLE_WHITE: Color = Color(
	0.88,
	0.89,
	0.91,
	0.20
)


var motion_time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	motion_time += delta

	# Very restrained "living ink" motion.
	# It only redraws this small panel, not the whole screen.
	if fmod(motion_time, 0.08) < delta:
		queue_redraw()


func _draw() -> void:
	if size.x <= 10.0 or size.y <= 10.0:
		return

	var w: float = size.x
	var h: float = size.y

	var cut: float = min(
		24.0,
		w * 0.08
	)

	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 14.0),
		Vector2(cut, 0.0),
		Vector2(w - cut, 0.0),
		Vector2(w, 14.0),
		Vector2(w, h - 14.0),
		Vector2(w - cut * 0.55, h),
		Vector2(cut * 0.55, h),
		Vector2(0.0, h - 14.0)
	])

	# Base panel.
	draw_colored_polygon(
		points,
		PANEL_COLOR
	)

	# Slight internal offset gives it a printed/inked depth.
	var inner_points: PackedVector2Array = PackedVector2Array([
		Vector2(5.0, 16.0),
		Vector2(cut + 4.0, 5.0),
		Vector2(w - cut - 4.0, 5.0),
		Vector2(w - 5.0, 16.0),
		Vector2(w - 5.0, h - 15.0),
		Vector2(w - cut * 0.55, h - 5.0),
		Vector2(cut * 0.55, h - 5.0),
		Vector2(5.0, h - 15.0)
	])

	draw_colored_polygon(
		inner_points,
		PANEL_COLOR_2
	)

	# Main white angular ink outline.
	for i: int in points.size():
		var next_i: int = (
			i + 1
		) % points.size()

		var start: Vector2 = points[i]
		var end: Vector2 = points[next_i]

		draw_line(
			start,
			end,
			WHITE,
			2.0
		)

	# Broken secondary ink marks.
	var pulse: float = (
		sin(motion_time * 4.2) *
		0.8
	)

	draw_line(
		Vector2(
			cut + 12.0,
			7.0 + pulse
		),
		Vector2(
			w - cut - 36.0,
			7.0 + pulse
		),
		SUBTLE_WHITE,
		1.0
	)

	draw_line(
		Vector2(
			12.0,
			h - 9.0
		),
		Vector2(
			w * 0.42,
			h - 9.0
		),
		SUBTLE_WHITE,
		1.0
	)

	# Small diagonal "cut" marks at the corners.
	draw_line(
		Vector2(0.0, 14.0),
		Vector2(13.0, 26.0),
		WHITE,
		1.0
	)

	draw_line(
		Vector2(w, 14.0),
		Vector2(w - 13.0, 26.0),
		WHITE,
		1.0
	)
