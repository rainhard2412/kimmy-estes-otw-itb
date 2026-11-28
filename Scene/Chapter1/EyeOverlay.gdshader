shader_type canvas_item;
// Waking-up eyelids drawn over the whole screen.
// open: 0 = eyes shut, 1 = fully open. blur: sleepy blur (mip level).

uniform float open : hint_range(0.0, 1.0) = 0.0;
uniform float blur : hint_range(0.0, 6.0) = 0.0;
uniform float softness = 0.12;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec3 scene = textureLod(screen_tex, SCREEN_UV, blur).rgb;
	vec2 p = UV * 2.0 - 1.0;

	// Almond-shaped opening: tallest in the middle, pinched at the sides.
	float h = open * 2.4 * (1.0 - 0.5 * p.x * p.x);
	float lid = smoothstep(-softness, softness, abs(p.y) - h);

	// Heavy vignette while still half asleep.
	float vig = smoothstep(0.3, 1.5, length(p)) * (1.0 - open) * 0.9;
	vec3 col = scene * (1.0 - vig);
	// Lids are dark with a hint of warm skin light coming through.
	col = mix(col, vec3(0.025, 0.01, 0.01), lid);
	COLOR = vec4(col, 1.0);
}
