shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

uniform vec4 glow_color : source_color = vec4(0.55, 0.8, 1.0, 1.0);
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;
uniform float strength : hint_range(0.0, 1.0) = 0.65;

void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	ALBEDO = glow_color.rgb;
	ALPHA = clamp(rim * strength, 0.0, 1.0);
}
