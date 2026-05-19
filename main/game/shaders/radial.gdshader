shader_type canvas_item;

uniform vec4 base_color : source_color;
uniform vec4 select_color : source_color;
uniform float inner_radius = 0.25;
uniform float outer_radius = 0.5; // Set this to 0.5 or less in the inspector for a perfect circle!
uniform int segment_count = 4;
uniform float float_angle = 0.0;
uniform float selection_strength = 0.0;

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv);
	
	// Keeps the shape perfectly circular within your UI container box
	if (dist < inner_radius || dist > outer_radius) {
		discard;
	}
	
	float angle = atan(uv.y, uv.x);
	
	// Fixes the fill/spinning glitch by calculating the true shortest angular distance
	float diff = abs(atan(sin(angle - float_angle), cos(angle - float_angle)));
	
	float step_angle = 2.0 * PI / float(segment_count);
	float highlight = 0.0;
	
	// Sharp pie-slice selection wedge
	if (diff < step_angle * 0.5) {
		highlight = selection_strength;
	}
	
	COLOR = mix(base_color, select_color, highlight);
}