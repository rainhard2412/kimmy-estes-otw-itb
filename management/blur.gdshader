shader_type canvas_item;
// Frosted-glass backdrop for the node map: blurs whatever is behind it.
// hint_screen_texture + mipmaps = a cheap, smooth blur at any strength.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod : hint_range(0.0, 6.0) = 3.0;
uniform vec4 tint : source_color = vec4(0.04, 0.05, 0.09, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	vec3 blurred = textureLod(screen_tex, SCREEN_UV, blur_lod).rgb;
	COLOR = vec4(mix(blurred, tint.rgb, tint_amount), 1.0);
}
