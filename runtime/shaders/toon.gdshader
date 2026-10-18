// A PixelDoll's 3D surfaces: the model's texture (or a primitive piece's
// flat color) flattened to a few tones per swatch, lit in a few flat bands
// from one light fixed to the view (so every doll is lit the same wherever
// it stands), shadows cool and highlights warm, like hand-picked pixel art
// ramps. On recolored surfaces, texels near recolor_key take the palette's
// three shades by brightness (see DollSkin, DollPalette).
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D albedo_texture : source_color, filter_nearest, hint_default_white;
// Multiplies the texture; a piece built from primitives has only this.
uniform vec4 albedo_color : source_color = vec4(1.0);
// The texture's swatches (KayKit: 8 x 4, each a vertical gradient).
uniform vec2 atlas_grid = vec2(8.0, 4.0);
// Tones kept per swatch gradient; 0 keeps the texture as is.
uniform int albedo_steps : hint_range(0, 8) = 2;
// In view space: +x right, +y up, +z towards the camera.
uniform vec3 light_direction = vec3(0.3, 0.6, 0.75);
uniform int light_bands : hint_range(2, 6) = 2;
// How bright the darkest band is.
uniform float shadow_brightness : hint_range(0.0, 1.0) = 0.8;
// How bright the brightest band is (over 1 brightens the texture).
uniform float highlight_brightness : hint_range(0.5, 2.0) = 1.1;
uniform vec4 shadow_tint : source_color = vec4(0.9, 0.9, 1.0, 1.0);
uniform vec4 highlight_tint : source_color = vec4(1.0, 0.97, 0.88, 1.0);
uniform bool recolored = false;
uniform vec4 recolor_key : source_color = vec4(0.8, 0.1, 0.15, 1.0);
// Hue distance (0..0.5) a texel may be from recolor_key and still be recolored.
uniform float recolor_tolerance : hint_range(0.0, 0.5) = 0.06;
uniform vec4 palette_light : source_color = vec4(1.0);
uniform vec4 palette_mid : source_color = vec4(0.5);
uniform vec4 palette_dark : source_color = vec4(0.2);


vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}


vec3 recolor(vec3 color) {
	vec3 hsv = rgb_to_hsv(color);
	float key_hue = rgb_to_hsv(recolor_key.rgb).x;
	float hue_distance = abs(hsv.x - key_hue);
	hue_distance = min(hue_distance, 1.0 - hue_distance);
	if (hsv.y < 0.3 || hue_distance > recolor_tolerance) {
		return color;
	}
	float value = hsv.z;
	return value > 0.5 ? mix(palette_mid.rgb, palette_light.rgb, (value - 0.5) * 2.0)
			: mix(palette_dark.rgb, palette_mid.rgb, value * 2.0);
}


// UV moved to the middle of its step of its swatch's gradient.
vec2 flatten_uv(vec2 uv) {
	if (albedo_steps == 0) {
		return uv;
	}
	vec2 cell = floor(uv * atlas_grid);
	float along = fract(uv.y * atlas_grid.y);
	along = (floor(along * float(albedo_steps)) + 0.5) / float(albedo_steps);
	return vec2((cell.x + 0.5) / atlas_grid.x, (cell.y + along) / atlas_grid.y);
}


void fragment() {
	vec3 color = texture(albedo_texture, flatten_uv(UV)).rgb * albedo_color.rgb;
	if (recolored) {
		color = recolor(color);
	}
	float lit = clamp(dot(normalize(NORMAL), normalize(light_direction)), 0.0, 1.0);
	float band = min(floor(lit * float(light_bands)), float(light_bands - 1)) / float(light_bands - 1);
	vec3 shade = mix(shadow_tint.rgb * shadow_brightness, highlight_tint.rgb * highlight_brightness, band);
	ALBEDO = color * shade;
}
