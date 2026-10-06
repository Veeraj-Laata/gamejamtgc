shader_type spatial;

render_mode unshaded, cull_back;

uniform vec4 corruption_color : source_color =
	vec4(0.0, 0.0, 0.0, 1.0);

void fragment()
{
	ALBEDO = vec3(0.0, 0.0, 0.0);
}