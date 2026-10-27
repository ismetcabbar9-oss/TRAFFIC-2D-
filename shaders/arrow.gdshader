// Roof arrow: a soft light band sweeps across the fill now and then (each
// arrow on its own phase), and `hint` turns it warm yellow with a halo.
// Layers come from UV.x: 0 = outline, 1 = fill, 2 = halo.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform float phase = 0.0; // seconds; spreads the sweeps between arrows
uniform float period = 3.6; // seconds between two sweeps
uniform float sweep_time = 0.9; // how long one sweep takes
uniform float shine_strength = 1.0;
uniform float glow_strength = 0.2; // faint halo that breathes with each sweep
uniform float hint : hint_range(0.0, 1.0) = 0.0;
uniform vec3 hint_color : source_color = vec3(1.0, 0.8, 0.22);

varying vec3 local_pos;
varying float layer;

void vertex() {
	local_pos = VERTEX;
	layer = UV.x;
}

void fragment() {
	float t = mod(TIME + phase, period) / sweep_time; // 0..1 while sweeping
	float band_pos = mix(-0.9, 1.0, t);
	float d = (local_pos.z + local_pos.x * 0.45) - band_pos;
	float shine = t < 1.0 ? exp(-d * d / 0.012) : 0.0;
	float breath = t < 1.0 ? sin(t * PI) : 0.0;

	if (layer > 1.5) {
		ALBEDO = mix(vec3(1.0, 0.97, 0.88), hint_color, hint);
		ALPHA = COLOR.a * max(hint, breath * glow_strength);
	} else if (layer > 0.5) {
		vec3 base = mix(COLOR.rgb, hint_color, hint);
		ALBEDO = base + vec3(0.1, 0.09, 0.06) * shine * shine_strength * (1.0 - hint);
		ALPHA = COLOR.a;
	} else {
		ALBEDO = mix(COLOR.rgb, COLOR.rgb * 0.6 + hint_color * 0.25, hint);
		ALPHA = COLOR.a;
	}
}
