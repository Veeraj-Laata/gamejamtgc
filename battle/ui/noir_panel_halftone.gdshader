shader_type canvas_item;

render_mode unshaded;


uniform float dot_scale = 42.0;
uniform float dot_size = 0.20;
uniform float dot_alpha = 0.16;


void fragment() {
	vec2 grid = UV * dot_scale;

	vec2 cell = fract(grid) - vec2(0.5);

	float distance_from_center = length(cell);

	float dot_mask = 1.0 - smoothstep(
		dot_size * 0.65,
		dot_size,
		distance_from_center
	);

	// Fade the dots toward the left and bottom.
	// This keeps the center of the UI clean while
	// still giving the panel a printed texture.
	float density = 1.0 - smoothstep(
		0.15,
		0.95,
		UV.x
	);

	float vertical_fade = smoothstep(
		0.05,
		0.45,
		UV.y
	);

	float alpha = (
		dot_mask *
		density *
		vertical_fade *
		dot_alpha
	);

	COLOR = vec4(
		1.0,
		1.0,
		1.0,
		alpha
	);
}