shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec3 color_root : source_color = vec3(0.08, 0.35, 0.12);
uniform vec3 color_tip : source_color = vec3(0.55, 0.86, 0.18);
uniform vec3 color_variation : source_color = vec3(0.82, 0.94, 0.28);
uniform float mesh_height : hint_range(0.1, 2.0) = 0.63;
uniform float wind_speed : hint_range(0.1, 10.0) = 2.4;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.22;
uniform vec2 wind_direction = vec2(0.707, 0.707);

varying float v_height;
varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_height = clamp(VERTEX.y / mesh_height, 0.0, 1.0);
	
	// Two-frequency wind wave travelling across world coordinates
	float wave1 = sin(TIME * wind_speed + (v_world_pos.x * wind_direction.x + v_world_pos.z * wind_direction.y) * 1.4);
	float wave2 = cos(TIME * (wind_speed * 0.65) + (v_world_pos.x * 0.5 - v_world_pos.z * 0.7) * 2.1);
	float total_wind = (wave1 * 0.7 + wave2 * 0.3) * wind_strength;
	
	// Quadratic sway: root remains anchored at 0.0, blade tips flex dynamically
	float sway = v_height * v_height * total_wind;
	vec2 w_dir = normalize(wind_direction);
	VERTEX.x += sway * w_dir.x;
	VERTEX.z += sway * w_dir.y;
	
	// Soften normals toward UP for unified, luminous low-poly stylized lighting
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.72));
}

void fragment() {
	// World-space organic patch variation across meadow fields
	float patch = sin(v_world_pos.x * 0.15) * cos(v_world_pos.z * 0.15) * 0.5 + 0.5;
	vec3 tip_col = mix(color_tip, color_variation, patch * 0.45);
	
	// Vertical root-to-tip color gradient
	ALBEDO = mix(color_root, tip_col, v_height);
	ROUGHNESS = 0.75;
	SPECULAR = 0.15;
}
