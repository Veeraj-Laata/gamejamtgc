shader_type spatial;

render_mode
	unshaded,
	cull_front,
	depth_draw_never,
	blend_mix;


uniform vec4 outline_color : source_color =
	vec4(1.0, 1.0, 1.0, 1.0);


uniform float outline_width :
	hint_range(0.0, 0.10) = 0.03;


uniform float outline_strength :
	hint_range(0.0, 1.0) = 1.0;


uniform float model_scale = 1.0;


void vertex()
{
	float compensated_width = outline_width / max(model_scale, 0.001);

	VERTEX += NORMAL * compensated_width;
}


void fragment()
{
	ALBEDO = outline_color.rgb;
	ALPHA = outline_strength;
}