// Sea beyond the beach: soft moving ripples and a light foam line at the shore
// (the patch's +Z edge, UV.y = 1).
shader_type spatial;
render_mode cull_disabled;

uniform vec3 base_color : source_color = vec3(0.25, 0.72, 0.84);
uniform vec3 deep_color : source_color = vec3(0.12, 0.45, 0.66);
uniform float ripple_scale = 0.9;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * ripple_scale;
	float t = TIME * 0.6;
	float ripple = sin(p.x * 1.3 + t) * 0.5 + sin(p.y * 1.7 - t * 1.2 + p.x * 0.4) * 0.5;
	float sparkle = smoothstep(0.82, 1.0, ripple);
	float shore = smoothstep(0.985, 1.0, UV.y + sin(world_pos.x * 0.8 + TIME) * 0.004);
	float depth = smoothstep(1.0, 0.75, UV.y);
	vec3 color = mix(base_color, deep_color, depth * 0.6);
	color += vec3(0.08) * sparkle;
	color = mix(color, vec3(0.97, 0.98, 1.0), shore);
	ALBEDO = color;
	ROUGHNESS = 0.25;
	SPECULAR = 0.4;
}
