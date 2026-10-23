// A PixelDoll's 2D pass: its 3D render made solid, with a
// 1px outline around it. Keeps the node's modulate and self_modulate.
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.1, 0.08, 0.12, 1.0);
// Below it, a texel counts as empty.
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;

// The node's modulate: fragment()'s COLOR already holds the texture's
// alpha, which is 0 where the outline goes.
varying vec4 tint;


void vertex() {
	tint = COLOR;
}


void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	if (texel.a >= alpha_cut) {
		texel.a = 1.0;
	} else {
		vec2 step_size = TEXTURE_PIXEL_SIZE;
		float neighbors = max(
				max(texture(TEXTURE, UV + vec2(step_size.x, 0.0)).a, texture(TEXTURE, UV - vec2(step_size.x, 0.0)).a),
				max(texture(TEXTURE, UV + vec2(0.0, step_size.y)).a, texture(TEXTURE, UV - vec2(0.0, step_size.y)).a));
		texel = neighbors >= alpha_cut ? outline_color : vec4(0.0);
	}
	COLOR = texel * tint;
}
