shader_type spatial;

render_mode unshaded;

uniform vec4 dark_color : source_color =
	vec4(0.16, 0.008, 0.045, 1.0);

uniform vec4 pink_color : source_color =
	vec4(1.0, 0.05, 0.42, 1.0);

uniform float pulse_speed :
	hint_range(0.0, 3.0) = 0.90;

uniform float min_strength :
	hint_range(0.0, 1.0) = 0.55;

uniform float max_strength :
	hint_range(0.0, 1.0) = 0.82;

uniform sampler2D albedo_tex : source_color;


float luminance(vec3 color)
{
	return dot(
		color,
		vec3(
			0.299,
			0.587,
			0.114
		)
	);
}


void fragment()
{
	vec3 base_color = texture(
		albedo_tex,
		UV
	).rgb;

	float lum = luminance(
		base_color
	);

	// Cheap triangle-wave pulse. Avoids a per-fragment trig call while
	// keeping the same slow breathing/pulsing look.
	float phase = fract(TIME * pulse_speed * 0.15915494);
	float wave = 1.0 - abs(phase * 2.0 - 1.0);

	float strength = mix(
		min_strength,
		max_strength,
		wave
	);

	vec3 train_color = mix(
		dark_color.rgb,
		pink_color.rgb,
		strength
	);

	// Preserve some original surface detail.
	train_color *= mix(
		0.55,
		1.0,
		lum
	);

	ALBEDO = train_color;
}