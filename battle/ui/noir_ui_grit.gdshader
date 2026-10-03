shader_type canvas_item;

render_mode unshaded;


uniform sampler2D screen_texture :
	hint_screen_texture,
	repeat_disable,
	filter_nearest;


uniform float threshold = 0.48;
uniform float contrast = 1.18;

uniform float fine_grain = 0.055;
uniform float coarse_grain = 0.16;

uniform float ink_breakup = 0.16;
uniform float paper_breakup = 0.08;


float hash21(vec2 p) {
	p = fract(
		p * vec2(
			127.1,
			311.7
		)
	);

	p += dot(
		p,
		p + 34.5
	);

	return fract(
		p.x * p.y
	);
}


void fragment() {
	vec4 source = textureLod(
		screen_texture,
		SCREEN_UV,
		0.0
	);

	if (source.a <= 0.0001) {
		COLOR = vec4(
			0.0,
			0.0,
			0.0,
			0.0
		);

	}


	// CanvasGroup's buffer may be premultiplied.
	vec3 color = source.rgb;

	if (source.a > 0.0001) {
		color /= source.a;
	}


	// -----------------------------------------------------
	// Convert everything to monochrome.
	// -----------------------------------------------------

	float luminance = dot(
		color,
		vec3(
			0.299,
			0.587,
			0.114
		)
	);


	// -----------------------------------------------------
	// Stable fine print grain.
	// Based on pixel position, so it does not animate.
	// -----------------------------------------------------

	vec2 pixel = (
		SCREEN_UV /
		SCREEN_PIXEL_SIZE
	);

	float fine_noise = hash21(
		floor(pixel * 0.50)
	);

	float coarse_noise = hash21(
		floor(pixel * 0.08)
	);


	// -----------------------------------------------------
	// Contrast.
	// -----------------------------------------------------

	luminance = (
		luminance - 0.5
	) * contrast + 0.5;


	// -----------------------------------------------------
	// Slight threshold wobble.
	// This creates the rough printed-ink edge.
	// -----------------------------------------------------

	float threshold_noise = (
		fine_noise - 0.5
	) * fine_grain;

	float black_white = smoothstep(
		threshold - 0.08,
		threshold + 0.08,
		luminance + threshold_noise
	);


	// -----------------------------------------------------
	// Coarse distressed ink.
	//
	// Large noise patches occasionally break up white
	// areas, like badly transferred/scratched ink.
	// -----------------------------------------------------

	float dark_break = step(
		0.91,
		coarse_noise
	);

	black_white = mix(
		black_white,
		0.0,
		dark_break * ink_breakup
	);


	// -----------------------------------------------------
	// Tiny paper speckle.
	//
	// Sparse bright imperfections survive inside darker
	// areas, giving the surface a printed-paper feeling.
	// -----------------------------------------------------

	float paper_noise = hash21(
		floor(pixel * 0.18) +
		vec2(19.3, 7.1)
	);

	float bright_speck = step(
		0.985,
		paper_noise
	);

	black_white = mix(
		black_white,
		1.0,
		bright_speck * paper_breakup
	);


	// -----------------------------------------------------
	// Final hard-ish ink.
	//
	// Keep a tiny amount of grayscale so antialiased
	// typography does not become ugly binary pixels.
	// -----------------------------------------------------

	float final_value = mix(
		0.015,
		0.985,
		black_white
	);

	vec3 final_color = vec3(
		final_value
	);


	COLOR = vec4(
		final_color,
		source.a
	);
}