shader_type spatial;

render_mode unshaded, cull_disabled;

uniform vec4 ground_color : source_color = vec4(
	0.002,
	0.003,
	0.010,
	1.0
);

uniform vec4 line_color : source_color = vec4(
	0.01,
	0.10,
	0.55,
	1.0
);

uniform float cell = 2.0;
uniform float line_width = 0.03;

varying vec3 world_pos;


void vertex() {
	world_pos = (
		MODEL_MATRIX *
		vec4(VERTEX, 1.0)
	).xyz;
}


void fragment() {
	vec2 grid_position = (
		world_pos.xz / cell
	);

	vec2 grid_fraction = fract(
		grid_position
	);

	vec2 distance_to_edge = (
		abs(
			grid_fraction - 0.5
		) * cell
	);

	float line = 1.0 - smoothstep(
		0.0,
		line_width,
		min(
			distance_to_edge.x,
			distance_to_edge.y
		)
	);

	float noise_value = fract(
		sin(
			dot(
				floor(grid_position),
				vec2(
					12.9898,
					78.233
				)
			)
		) * 43758.5453
	);

	float breakup = step(
		0.35,
		noise_value
	);

	vec3 final_color = mix(
		ground_color.rgb,
		line_color.rgb,
		line * 0.55 * breakup
	);

	ALBEDO = final_color;
}