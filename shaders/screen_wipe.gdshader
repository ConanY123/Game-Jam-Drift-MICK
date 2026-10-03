shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform bool opening = false;
uniform vec4 wipe_color : source_color = vec4(0.015, 0.02, 0.055, 1.0);
uniform vec4 edge_color : source_color = vec4(0.35, 0.85, 1.0, 1.0);
uniform float edge_width : hint_range(0.001, 0.05) = 0.003;
uniform float angle_degrees : hint_range(10.0, 80.0) = 65.0;

void fragment() {
	float aspect_correction = SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y;
	float slope = aspect_correction / tan(radians(angle_degrees));
	float position = UV.x - slope * (UV.y - 0.5);
	float min_position = -slope * 0.5;
	float max_position = 1.0 + slope * 0.5;
	float boundary = mix(min_position, max_position, progress);
	float covered = opening ? step(boundary, position) : step(position, boundary);
	float edge = 1.0 - smoothstep(edge_width, edge_width * 2.0, abs(position - boundary));
	COLOR = mix(vec4(0.0), wipe_color, covered);
	COLOR = mix(COLOR, edge_color, edge * covered);
}
