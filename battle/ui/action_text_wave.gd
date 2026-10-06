extends Label


const WAVE_SHADER: Shader = preload(
	"res://battle/ui/action_text_wave.gdshader"
)


var wave_material: ShaderMaterial
var wave_tween: Tween


var base_color: Color = Color(
	0.90,
	0.91,
	0.92,
	1.0
)

var action_color: Color = Color(
	0.52,
	0.10,
	0.14,
	1.0
)


func _ready() -> void:
	add_theme_color_override(
		"font_color",
		base_color
	)

	wave_material = ShaderMaterial.new()
	wave_material.shader = WAVE_SHADER

	wave_material.set_shader_parameter(
		"base_color",
		base_color
	)

	wave_material.set_shader_parameter(
		"wave_color",
		action_color
	)

	wave_material.set_shader_parameter(
		"wave_progress",
		-0.25
	)

	wave_material.set_shader_parameter(
		"wave_width",
		0.18
	)

	wave_material.set_shader_parameter(
		"wave_strength",
		0.75
	)

	material = wave_material


func set_action_color(
	new_color: Color
) -> void:
	action_color = new_color

	if wave_material == null:
		return

	wave_material.set_shader_parameter(
		"wave_color",
		action_color
	)


func play_wave(
	duration: float = 1.25
) -> void:
	if wave_material == null:
		return

	if wave_tween != null and wave_tween.is_valid():
		wave_tween.kill()

	wave_material.set_shader_parameter(
		"wave_progress",
		-0.25
	)

	wave_material.set_shader_parameter(
		"wave_strength",
		0.0
	)

	wave_tween = create_tween()

	wave_tween.tween_method(
		_set_wave_strength,
		0.0,
		0.75,
		0.18
	)

	wave_tween.parallel().tween_method(
		_set_wave_progress,
		-0.25,
		1.25,
		duration
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_IN_OUT
	)

	wave_tween.tween_method(
		_set_wave_strength,
		0.75,
		0.0,
		0.30
	)


func _set_wave_progress(
	value: float
) -> void:
	if wave_material == null:
		return

	wave_material.set_shader_parameter(
		"wave_progress",
		value
	)


func _set_wave_strength(
	value: float
) -> void:
	if wave_material == null:
		return

	wave_material.set_shader_parameter(
		"wave_strength",
		value
	)
