shader_type spatial;

render_mode unshaded;

uniform vec4 black_color : source_color =
	vec4(0.001, 0.003, 0.008, 1.0);

uniform vec4 blue_color : source_color =
	vec4(0.005, 0.10, 0.75, 1.0);

uniform vec4 accent_color : source_color =
	vec4(0.02, 0.85, 0.42, 1.0);

uniform sampler2D albedo_tex : source_color;

uniform float blue_amount :
	hint_range(0.0, 1.0) = 0.88;

uniform float shadow_cutoff :
	hint_range(0.0, 1.0) = 0.06;

uniform float light_cutoff :
	hint_range(0.0, 1.0) = 0.20;

uniform float accent_strength :
	hint_range(0.0, 1.0) = 0.0;

uniform float halftone_scale :
	hint_range(5.0, 150.0) = 85.0;

uniform float dot_size :
	hint_range(0.05, 0.9) = 0.13;

uniform float halftone_strength :
	hint_range(0.0, 1.0) = 0.16;

uniform float animation_speed :
	hint_range(0.0, 5.0) = 0.75;

uniform float blue_amount_animation :
	hint_range(0.0, 0.5) = 0.035;

uniform float shadow_animation :
	hint_range(0.0, 0.25) = 0.009;

uniform float light_animation :
	hint_range(0.0, 0.25) = 0.018;


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


float halftone(vec2 uv)
{
	vec2 grid = uv * halftone_scale;
	vec2 cell = fract(grid) - 0.5;
	float distance_to_center = length(cell);

	return 1.0 - smoothstep(
		dot_size - 0.02,
		dot_size + 0.02,
		distance_to_center
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

	float t = TIME * animation_speed;

	float wave_a = sin(t);
	float wave_b = sin(
		t * 0.63 + 1.7
	);
	float wave_c = sin(
		t * 1.37 + 4.1
	);

	float animated_blue_amount =
		blue_amount
		+
		wave_a *
		blue_amount_animation
		+
		wave_b *
		blue_amount_animation *
		0.35;

	float animated_shadow_cutoff =
		shadow_cutoff
		+
		wave_b *
		shadow_animation
		+
		wave_c *
		shadow_animation *
		0.35;

	float animated_light_cutoff =
		light_cutoff
		+
		wave_c *
		light_animation
		+
		wave_a *
		light_animation *
		0.30;

	animated_blue_amount = clamp(
		animated_blue_amount,
		0.0,
		0.895
	);

	animated_shadow_cutoff = clamp(
		animated_shadow_cutoff,
		0.035,
		0.085
	);

	animated_light_cutoff = clamp(
		animated_light_cutoff,
		0.145,
		0.225
	);

	float shadow_mask = step(
		animated_shadow_cutoff,
		lum
	);

	float light_mask = smoothstep(
		animated_light_cutoff - 0.055,
		animated_light_cutoff + 0.055,
		lum
	);

	float blue_mask =
		light_mask *
		animated_blue_amount;

	blue_mask +=
		shadow_mask *
		0.05;

	blue_mask = clamp(
		blue_mask,
		0.0,
		0.895
	);

	float dots = halftone(
		UV
	);

	float midtone =
		smoothstep(
			0.18,
			0.42,
			lum
		) *
		(
			1.0 -
			smoothstep(
				0.55,
				0.85,
				lum
			)
		);

	float print_amount =
		dots *
		midtone *
		halftone_strength;

	vec3 blue_environment = mix(
		black_color.rgb,
		blue_color.rgb,
		blue_mask
	);

	vec3 accent_environment = mix(
		black_color.rgb,
		accent_color.rgb,
		blue_mask
	);

	vec3 environment_color = mix(
		blue_environment,
		accent_environment,
		clamp(
			accent_strength,
			0.0,
			1.0
		)
	);

	environment_color = mix(
		environment_color,
		black_color.rgb,
		print_amount
	);

	ALBEDO = environment_color;
}