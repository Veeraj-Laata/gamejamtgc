class_name NoirPanel
extends Control
## Procedural printed-comic panel.
##
## Performance:
## - Geometry is generated only when the panel is resized.
## - No per-frame redraw.
## - No animated outline.
## - No fullscreen effect.
##
## The panel stays monochrome. Action colours belong to active text,
## not to the static panel itself.


const PAPER: Color = Color(
	0.82,
	0.83,
	0.84,
	1.0
)

const PAPER_DARK: Color = Color(
	0.48,
	0.49,
	0.51,
	1.0
)

const INK: Color = Color(
	0.002,
	0.003,
	0.006,
	0.98
)

const INK_2: Color = Color(
	0.009,
	0.010,
	0.014,
	0.98
)

const INK_3: Color = Color(
	0.018,
	0.019,
	0.024,
	0.98
)

const WHITE: Color = Color(
	0.92,
	0.93,
	0.94,
	1.0
)

const GREY: Color = Color(
	0.58,
	0.59,
	0.61,
	1.0
)


# ---------------------------------------------------------
# Compatibility properties used by the existing HUD.
# ---------------------------------------------------------

@export var fill_color: Color = INK
@export var line_color: Color = WHITE
@export var accent_color: Color = WHITE

@export var line_width: float = 2.0
@export var corner_cut: float = 18.0
@export var padding: int = 16

@export var jag_step: float = 30.0
@export var jag: float = 0.0

@export var boil_amount: float = 0.0
@export var boil_fps: float = 0.0

@export var shape_seed: int = 1

@export var halftone_spacing: float = 8.0

@export var shadow_offset: Vector2 = Vector2(
	7.0,
	7.0
)

@export var highlight_speed: float = 0.0
@export var highlight_length: float = 0.0


# ---------------------------------------------------------
# Cached geometry.
# ---------------------------------------------------------

var _outer: PackedVector2Array = PackedVector2Array()
var _paper: PackedVector2Array = PackedVector2Array()
var _inner: PackedVector2Array = PackedVector2Array()
var _left_strip: PackedVector2Array = PackedVector2Array()

var _halftone_points: PackedVector2Array = PackedVector2Array()
var _halftone_radii: PackedFloat32Array = PackedFloat32Array()

var _built_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	resized.connect(
		_rebuild
	)

	_rebuild()


func _rebuild() -> void:
	if size.x < 20.0 or size.y < 20.0:
		return

	_built_size = size

	_outer = _make_outer_shape()

	_paper = _make_paper_shape()

	_inner = _make_inner_shape()

	_left_strip = _make_left_strip()

	_build_halftone()

	queue_redraw()


func _make_outer_shape() -> PackedVector2Array:
	var w: float = size.x
	var h: float = size.y

	var cut: float = clampf(
		corner_cut,
		8.0,
		minf(w, h) * 0.20
	)

	# Deliberately asymmetrical.
	return PackedVector2Array([
		Vector2(
			cut + 6.0,
			0.0
		),

		Vector2(
			w - cut - 10.0,
			0.0
		),

		Vector2(
			w - 1.0,
			cut + 7.0
		),

		Vector2(
			w - 2.0,
			h - cut - 5.0
		),

		Vector2(
			w - cut * 0.55,
			h - 1.0
		),

		Vector2(
			cut + 10.0,
			h
		),

		Vector2(
			1.0,
			h - cut
		),

		Vector2(
			0.0,
			cut + 10.0
		)
	])


func _make_paper_shape() -> PackedVector2Array:
	var w: float = size.x
	var h: float = size.y

	return PackedVector2Array([
		Vector2(
			18.0,
			4.0
		),

		Vector2(
			w - 23.0,
			3.0
		),

		Vector2(
			w - 3.0,
			18.0
		),

		Vector2(
			w - 5.0,
			h - 19.0
		),

		Vector2(
			w - 20.0,
			h - 3.0
		),

		Vector2(
			20.0,
			h
		),

		Vector2(
			3.0,
			h - 18.0
		),

		Vector2(
			4.0,
			19.0
		)
	])


func _make_inner_shape() -> PackedVector2Array:
	var inset: float = 15.0

	var w: float = size.x
	var h: float = size.y

	var cut: float = clampf(
		corner_cut - 5.0,
		6.0,
		minf(w, h) * 0.16
	)

	return PackedVector2Array([
		Vector2(
			inset + cut,
			inset
		),

		Vector2(
			w - inset - cut,
			inset
		),

		Vector2(
			w - inset,
			inset + cut
		),

		Vector2(
			w - inset,
			h - inset - cut
		),

		Vector2(
			w - inset - cut,
			h - inset
		),

		Vector2(
			inset + cut,
			h - inset
		),

		Vector2(
			inset,
			h - inset - cut
		),

		Vector2(
			inset,
			inset + cut
		)
	])


func _make_left_strip() -> PackedVector2Array:
	var w: float = size.x
	var h: float = size.y

	# Strong black vertical ink mass inspired by the reference.
	var strip_width: float = minf(
		42.0,
		w * 0.12
	)

	return PackedVector2Array([
		Vector2(
			10.0,
			20.0
		),

		Vector2(
			18.0,
			12.0
		),

		Vector2(
			18.0 + strip_width,
			15.0
		),

		Vector2(
			18.0 + strip_width - 4.0,
			h - 22.0
		),

		Vector2(
			17.0,
			h - 16.0
		),

		Vector2(
			10.0,
			h - 24.0
		)
	])


func _build_halftone() -> void:
	_halftone_points.clear()
	_halftone_radii.clear()

	var spacing: float = maxf(
		halftone_spacing,
		5.0
	)

	# Put the halftone predominantly in the right side,
	# behind the content rather than around the whole screen.
	var center: Vector2 = Vector2(
		size.x * 0.78,
		size.y * 0.54
	)

	var radius: float = minf(
		size.x * 0.34,
		size.y * 0.48
	)

	var y: float = (
		center.y - radius
	)

	var row: int = 0

	while y <= center.y + radius:
		var x: float = (
			center.x - radius
		)

		if row % 2 == 1:
			x += spacing * 0.5

		while x <= center.x + radius:
			var point: Vector2 = Vector2(
				x,
				y
			)

			var distance: float = (
				point.distance_to(center)
			)

			if distance <= radius:
				var strength: float = (
					1.0 -
					distance / radius
				)

				if strength > 0.08:
					var dot_radius: float = lerpf(
						0.55,
						2.0,
						strength
					)

					_halftone_points.append(
						point
					)

					_halftone_radii.append(
						dot_radius
					)

			x += spacing

		y += spacing
		row += 1


func _draw() -> void:
	if _outer.size() < 3:
		return

	# -----------------------------------------------------
	# Deep offset ink shadow.
	# -----------------------------------------------------

	draw_colored_polygon(
		_shift(
			_outer,
			shadow_offset
		),
		Color(
			0.0,
			0.0,
			0.0,
			0.72
		)
	)


	# -----------------------------------------------------
	# White paper edge.
	# -----------------------------------------------------

	draw_colored_polygon(
		_paper,
		PAPER
	)


	# -----------------------------------------------------
	# Large black printed plate.
	# -----------------------------------------------------

	var black_plate: PackedVector2Array = _shift(
		_outer,
		Vector2(
			5.0,
			5.0
		)
	)

	draw_colored_polygon(
		black_plate,
		fill_color
	)


	# -----------------------------------------------------
	# Interior black field.
	# -----------------------------------------------------

	draw_colored_polygon(
		_inner,
		INK_2
	)


	# -----------------------------------------------------
	# Dense black left ink column.
	# -----------------------------------------------------

	draw_colored_polygon(
		_left_strip,
		INK
	)


	# -----------------------------------------------------
	# Halftone.
	# -----------------------------------------------------

	for i: int in _halftone_points.size():
		var dot_alpha: float = 0.18

		draw_circle(
			_halftone_points[i],
			_halftone_radii[i],
			Color(
				WHITE.r,
				WHITE.g,
				WHITE.b,
				dot_alpha
			)
		)


	# -----------------------------------------------------
	# Primary white frame.
	# -----------------------------------------------------

	_draw_closed(
		_outer,
		WHITE,
		3.0
	)


	# -----------------------------------------------------
	# Secondary interior frame.
	# -----------------------------------------------------

	_draw_closed(
		_inner,
		PAPER_DARK,
		1.0
	)


	# -----------------------------------------------------
	# Strong inner white editorial line.
	# -----------------------------------------------------

	var editorial_y: float = minf(
		72.0,
		size.y * 0.34
	)

	draw_line(
		Vector2(
			54.0,
			editorial_y
		),
		Vector2(
			size.x - 34.0,
			editorial_y - 1.0
		),
		WHITE,
		2.0,
		true
	)


	# -----------------------------------------------------
	# Small broken registration marks.
	# -----------------------------------------------------

	_draw_registration_marks()


	# -----------------------------------------------------
	# Tiny ink ticks along left strip.
	# -----------------------------------------------------

	_draw_ink_ticks()


func _draw_closed(
	points: PackedVector2Array,
	color: Color,
	width: float
) -> void:
	if points.size() < 2:
		return

	for i: int in points.size():
		var next_index: int = (
			i + 1
		) % points.size()

		draw_line(
			points[i],
			points[next_index],
			color,
			width,
			true
		)


func _draw_registration_marks() -> void:
	var w: float = size.x
	var h: float = size.y

	var mark_color: Color = WHITE

	# Top-left cross.
	_draw_cross(
		Vector2(
			27.0,
			26.0
		),
		6.0,
		mark_color
	)

	# Top-right cross.
	_draw_cross(
		Vector2(
			w - 27.0,
			26.0
		),
		6.0,
		mark_color
	)

	# Right middle registration circle approximation.
	draw_arc(
		Vector2(
			w - 19.0,
			h * 0.50
		),
		6.0,
		0.0,
		TAU,
		16,
		mark_color,
		1.0,
		true
	)

	# Bottom center.
	_draw_cross(
		Vector2(
			w * 0.50,
			h - 13.0
		),
		5.0,
		mark_color
	)


func _draw_cross(
	center: Vector2,
	radius: float,
	color: Color
) -> void:
	draw_line(
		center - Vector2(
			radius,
			0.0
		),
		center + Vector2(
			radius,
			0.0
		),
		color,
		1.0,
		true
	)

	draw_line(
		center - Vector2(
			0.0,
			radius
		),
		center + Vector2(
			0.0,
			radius
		),
		color,
		1.0,
		true
	)


func _draw_ink_ticks() -> void:
	var x: float = 56.0

	for i: int in 5:
		var y: float = (
			88.0 +
			float(i) * 12.0
		)

		draw_line(
			Vector2(
				x,
				y
			),
			Vector2(
				x + 8.0 +
				float(i % 2) * 5.0,
				y
			),
			PAPER_DARK,
			1.0,
			true
		)


func _shift(
	points: PackedVector2Array,
	offset: Vector2
) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()

	for point: Vector2 in points:
		result.append(
			point + offset
		)

	return result
