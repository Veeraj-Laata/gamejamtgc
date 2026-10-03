shader_type canvas_item;
// Dark blue vignette with halftone dots and a little film grain.
// Cheap, one full-screen quad. Disable the node if you ever need the frames.

uniform vec4 tint : source_color = vec4(0.0, 0.01, 0.07, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.8;
uniform float dot_scale = 70.0;
uniform float grain = 0.05;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 c = uv - 0.5;
	c.x *= 1.25;
	float d = length(c);
	float vig = smoothstep(0.30, 0.90, d);

	vec2 g = uv * vec2(dot_scale * 1.78, dot_scale);
	g.x += 0.5 * mod(floor(g.y), 2.0);
	vec2 cell = fract(g) - 0.5;
	float r = mix(0.0, 0.62, vig);
	float dots = 1.0 - smoothstep(r - 0.06, r + 0.06, length(cell));

	float n = hash(uv * 900.0 + floor(TIME * 12.0)) - 0.5;
	float a = vig * strength * 0.75 + dots * vig * 0.45 + n * grain;
	COLOR = vec4(tint.rgb, clamp(a, 0.0, 0.92));
}
