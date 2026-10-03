shader_type spatial;

render_mode
	unshaded,
	cull_front,
	depth_draw_never,
	blend_mix;

uniform vec4 outline_color : source_color =
	vec4(1.0, 1.0, 1.0, 1.0);

uniform float outline_width :
	hint_range(0.0, 0.10) = 0.018;

uniform float outline_strength :
	hint_range(0.0, 1.0) = 1.0;


void vertex()
{
	VERTEX += NORMAL * outline_width;
}


void fragment()
{
	ALBEDO = outline_color.rgb;
	ALPHA = outline_strength;
}