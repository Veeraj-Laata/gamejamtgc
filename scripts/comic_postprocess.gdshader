shader_type canvas_item;


uniform sampler2D screen_texture :
	hint_screen_texture,
	filter_nearest;


uniform vec4 black_color : source_color =
	vec4(0.001, 0.003, 0.008, 1.0);


uniform vec4 blue_color : source_color =
	vec4(0.005, 0.10, 0.75, 1.0);


uniform vec4 green_color : source_color =
	vec4(0.02, 0.85, 0.42, 1.0);


uniform float blue_threshold :
	hint_range(0.0, 1.0) = 0.18;


uniform float green_threshold :
	hint_range(0.0, 1.0) = 0.20;


uniform float halftone_scale :
	hint_range(5.0, 150.0) = 65.0;


uniform float dot_size :
	hint_range(0.05, 0.9) = 0.28;


uniform float halftone_strength :
	hint_range(0.0, 1.0) = 0.20;


uniform float edge_strength :
	hint_range(0.0, 3.0) = 0.45;


uniform float edge_threshold :
	hint_range(0.001, 1.0) = 0.10;


float blue_signal(
	vec3 color
)
{
	return color.b;
}


float green_signal(
	vec3 color
)
{
	return color.g;
}


float green_strength(
	vec3 color
)
{
	/*
		Reactive green/teal pixels have:

		high green
		low-ish red
		meaningful green > blue
	*/

	float green_difference =
		color.g - color.b;

	float red_suppression =
		1.0 - color.r;

	float mask_a = smoothstep(
		green_threshold - 0.05,
		green_threshold + 0.05,
		color.g
	);

	float mask_b = smoothstep(
		0.02,
		0.20,
		green_difference
	);

	float mask_c = smoothstep(
		0.15,
		0.80,
		red_suppression
	);

	return clamp(
		mask_a *
		mask_b *
		mask_c,
		0.0,
		1.0
	);
}


float halftone(
	vec2 uv
)
{
	vec2 grid =
		uv *
		halftone_scale;


	vec2 cell =
		fract(grid) -
		0.5;


	float distance_to_center =
		length(cell);


	return 1.0 - smoothstep(
		dot_size - 0.02,
		dot_size + 0.02,
		distance_to_center
	);
}


void fragment()
{
	vec2 uv =
		SCREEN_UV;


	vec3 source =
		texture(
			screen_texture,
			uv
		).rgb;


	/*
		----------------------------------------
		BLUE DETECTION
		----------------------------------------
	*/

	float blue_signal_value =
		blue_signal(
			source
		);


	float blue_mask =
		smoothstep(
			blue_threshold - 0.04,
			blue_threshold + 0.04,
			blue_signal_value
		);


	/*
		----------------------------------------
		GREEN / TEAL DETECTION
		----------------------------------------
	*/

	float green_mask =
		green_strength(
			source
		);


	/*
		----------------------------------------
		HALFTONE
		----------------------------------------
	*/

	float dots =
		halftone(
			uv
		);


	float dark_print =
		dots *
		(
			1.0 -
			max(
				blue_mask,
				green_mask
			)
		) *
		halftone_strength;


	/*
		----------------------------------------
		EDGE DETECTION
		----------------------------------------
	*/

	vec2 px =
		SCREEN_PIXEL_SIZE *
		1.5;


	float left =
		blue_signal(
			texture(
				screen_texture,
				uv -
				vec2(px.x, 0.0)
			).rgb
		);


	float right =
		blue_signal(
			texture(
				screen_texture,
				uv +
				vec2(px.x, 0.0)
			).rgb
		);


	float up =
		blue_signal(
			texture(
				screen_texture,
				uv -
				vec2(0.0, px.y)
			).rgb
		);


	float down =
		blue_signal(
			texture(
				screen_texture,
				uv +
				vec2(0.0, px.y)
			).rgb
		);


	float edge =
		abs(
			left -
			right
		) +
		abs(
			up -
			down
		);


	edge = smoothstep(
		edge_threshold,
		edge_threshold + 0.05,
		edge
	);


	edge *=
		edge_strength;


	/*
		----------------------------------------
		BASE COLOR
		----------------------------------------
	*/

	vec3 result =
		black_color.rgb;


	/*
		BLUE WORLD
	*/

	result = mix(
		result,
		blue_color.rgb,
		blue_mask
	);


	/*
		GREEN / TEAL REACTIVE OBJECTS

		This is intentionally AFTER the blue
		layer so green can survive the
		post-process.
	*/

	result = mix(
		result,
		green_color.rgb,
		green_mask
	);


	/*
		----------------------------------------
		PRINT / HALFTONE
		----------------------------------------
	*/

	result = mix(
		result,
		black_color.rgb,
		clamp(
			dark_print,
			0.0,
			1.0
		)
	);


	/*
		----------------------------------------
		EDGE INK
		----------------------------------------
		*/

	result = mix(
		result,
		black_color.rgb,
		clamp(
			edge,
			0.0,
			1.0
		)
	);


	COLOR = vec4(
		result,
		1.0
	);
}