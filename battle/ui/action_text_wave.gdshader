shader_type canvas_item;


uniform vec4 base_color : source_color = vec4(
	0.90,
	0.91,
	0.92,
	1.0
);

uniform vec4 wave_color : source_color = vec4(
	0.52,
	0.10,
	0.14,
	1.0
);

uniform float wave_progress = -0.25;
uniform float wave_width = 0.18;
uniform float wave_strength = 0.75;


void fragment() {
	vec4 tex = texture(
		TEXTURE,
		UV
	);

	if (tex.a < 0.01) {
		COLOR = vec4(0.0);
		
	}

	float distance_to_wave = abs(
		UV.x - wave_progress
	);

	float wave = 1.0 - smoothstep(
		0.0,
		wave_width,
		distance_to_wave
	);

	float bright_center = 1.0 - smoothstep(
		0.0,
		wave_width * 0.35,
		distance_to_wave
	);

	float final_wave = max(
		wave * 0.65,
		bright_center
	);

	vec3 final_color = mix(
		base_color.rgb,
		wave_color.rgb,
		final_wave * wave_strength
	);

	COLOR = vec4(
		final_color,
		tex.a
	);
}