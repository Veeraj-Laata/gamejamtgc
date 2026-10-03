shader_type spatial;

render_mode unshaded;


uniform vec4 black_color : source_color =
	vec4(0.001, 0.002, 0.006, 1.0);

uniform vec4 blue_color : source_color =
	vec4(0.01, 0.16, 0.95, 1.0);

uniform float blue_strength :
	hint_range(0.0, 1.0) = 0.85;


void fragment()
{
	float facing = dot(
		normalize(NORMAL),
		normalize(VIEW)
	);

	facing = clamp(
		facing,
		0.0,
		1.0
	);


	float face_mask = smoothstep(
		0.72,
		0.92,
		facing
	);


	float rim = 1.0 - facing;

	rim = smoothstep(
		0.55,
		0.82,
		rim
	);


	float blue_mask = max(
		face_mask * 0.55,
		rim * 0.90
	);


	blue_mask *= blue_strength;


	ALBEDO = mix(
		black_color.rgb,
		blue_color.rgb,
		blue_mask
	);
}