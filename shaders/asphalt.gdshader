// Asphalt / paving: base color broken up by fine grain and soft large blotches
// sampled in world space, so neighbouring pieces line up seamlessly.
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.27, 0.29, 0.34);
uniform float grain = 0.07; // strength of the fine speckle
uniform float blotch = 0.05; // strength of the large, soft variation
uniform float grain_scale = 7.0;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float fine = value_noise(p * grain_scale) * 0.6 + value_noise(p * grain_scale * 3.7) * 0.4;
	float large = value_noise(p * 0.3);
	ALBEDO = base_color * (1.0 + (fine - 0.5) * grain * 2.0 + (large - 0.5) * blotch * 2.0);
	ROUGHNESS = 0.92;
}
