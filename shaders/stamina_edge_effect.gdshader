shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.0; // Overall effect opacity.
uniform int effect_mode = 0; // 0 = physical low-stamina, 1 = dream low-stamina.
uniform float effect_time = 0.0; // Elapsed time; drives the pulse and rotating lines.
uniform float fine_line_length_px = 65.0; // Fine-line reach inward from each screen edge, in pixels.
uniform float fine_line_end_fade_px = 30.0; // Soft fade width at the inward ends of the fine lines.
uniform float attempt_strength : hint_range(0.0, 1.0) = 0.0; // Temporary glow boost when realm switching is attempted.
uniform float attempt_size_px = 190.0; // Edge glow reach while the temporary boost is active.
uniform float glow_size_px = 110.0; // Normal edge glow reach, in pixels.
uniform vec2 effect_size_px = vec2(1024.0, 576.0); // Full game window size.

void fragment() {
	float edge_distance = min( // Distance in screen pixels to the nearest edge.
		min(UV.x * effect_size_px.x, (1.0 - UV.x) * effect_size_px.x),
		min(UV.y * effect_size_px.y, (1.0 - UV.y) * effect_size_px.y)
	);
	float glow = 1.0 - smoothstep(0.0, glow_size_px, edge_distance); // Normal glow spreads inward from every viewport edge.
	float attempt_glow = 1.0 - smoothstep(0.0, attempt_size_px, edge_distance);
	vec3 effect_color = vec3(0.9294, 0.2157, 0.7255); // Pink (RGB 237, 55, 185) for stamina and swap feedback.
	float detail = 0.75; // Base line visibility outside physical low-stamina mode.
	float fine_line_detail = 0.0;
	float fine_line_extent = 0.0;

	if (effect_mode == 0) {
		float angle = atan((UV.y - 0.5) * effect_size_px.y, (UV.x - 0.5) * effect_size_px.x); // Direction from playfield center.
		float streaks = smoothstep(0.75, 1.0, sin(angle * 19.0 + effect_time * 3.0)); // 19 = large-line density; 3 = rotation speed.
		float fine_streaks = smoothstep(
			0.84, // Higher threshold makes fine lines shorter/sparser.
			0.99, // Upper threshold controls how sharply each fine line appears.
			sin(angle * 43.0 + effect_time * 11.0) // 43 = fine-line density; 11 = faster rotation.
		);
		fine_line_extent = 1.0 - smoothstep(
			max(fine_line_length_px - fine_line_end_fade_px, 0.0),
			fine_line_length_px,
			edge_distance
		); // Restricts the fine-line layer to this many pixels inward from the edge.
		detail = mix(0.35, 1.0, streaks); // 0.35 = minimum large-line visibility; 1.0 = maximum.
		fine_line_detail = mix(0.2, 1.0, fine_streaks); // 0.2 = minimum fine-line visibility; 1.0 = maximum.
	}

	float pulse = effect_mode == 0
		? 0.8 + 0.2 * sin(effect_time * 4.0) // Physical: 0.8 base, 0.2 pulse depth, 4 = pulse speed.
		: 0.85 + 0.15 * sin(effect_time * 2.0); // Dream: 0.85 base, 0.15 pulse depth, 2 = pulse speed.
	float alpha = glow * strength * detail * pulse * 0.88; // 0.88 = overall maximum opacity multiplier.
	alpha = max(
		alpha,
		glow * strength * fine_line_extent * fine_line_detail * pulse * 0.88
	);
	alpha = max(alpha, attempt_glow * attempt_strength * 0.78);
	COLOR = vec4(effect_color, alpha);
}
