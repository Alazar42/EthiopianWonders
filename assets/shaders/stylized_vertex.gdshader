shader_type spatial;

// Flat-shaded low-poly look driven by baked vertex colours.
// Colours are authored in sRGB. A vertex alpha below 1 makes that surface glow
// (lava, acid pools, volcano craters): emission = colour * (1 - alpha) * glow_strength.
uniform float glow_strength : hint_range(0.0, 8.0) = 3.0;

void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
	EMISSION = ALBEDO * (1.0 - COLOR.a) * glow_strength;
}
