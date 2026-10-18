// A PixelDoll's inner lines: a full-view pass that darkens
// each pixel lying behind a neighbor by more than depth_threshold (beyond
// what its own surface's slope explains), so parts in front (an arm, the
// head, the shield) read as drawn shapes. Depth only,
// so it also runs on the Mobile renderer.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
// World units a neighbor must be closer by to draw a line.
uniform float depth_threshold : hint_range(0.0, 2.0) = 0.08;
// What a lined pixel keeps of its color.
uniform float line_brightness : hint_range(0.0, 1.0) = 0.3;


void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}


float view_depth(vec2 uv, mat4 inv_projection) {
	float depth = texture(depth_texture, uv).r;
	vec4 view = inv_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return -view.z / view.w;
}


// How far a pixel lies behind the plane through its two neighbors along
// `axis`: 0 on a flat or sloped surface, the step's depth past an edge.
float step_behind(vec2 uv, vec2 axis, float depth, mat4 inv_projection) {
	// Capped, so a background neighbor reads as a gentle slope.
	float a = min(view_depth(uv + axis, inv_projection), depth + 0.3);
	float b = min(view_depth(uv - axis, inv_projection), depth + 0.3);
	return 2.0 * depth - a - b;
}


void fragment() {
	vec2 pixel = 1.0 / VIEWPORT_SIZE;
	float depth = view_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float behind = max(step_behind(SCREEN_UV, vec2(pixel.x, 0.0), depth, INV_PROJECTION_MATRIX),
			step_behind(SCREEN_UV, vec2(0.0, pixel.y), depth, INV_PROJECTION_MATRIX));
	vec4 color = texture(screen_texture, SCREEN_UV);
	// Only on the doll: the background is transparent.
	bool lined = color.a > 0.5 && behind > depth_threshold;
	ALBEDO = color.rgb * line_brightness;
	ALPHA = lined ? 1.0 : 0.0;
}
