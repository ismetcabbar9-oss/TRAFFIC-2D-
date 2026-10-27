// Additive round glow (lamp light pools, bulbs, headlights): bright center
// fading to nothing at the quad's edge. Unlit, so it reads at night.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 glow_color : source_color = vec3(1.0, 0.85, 0.55);
uniform float strength = 0.6;
uniform float stretch = 1.0; // > 1 makes an oval (headlight beams), along UV.y

void fragment() {
	vec2 d = (UV - vec2(0.5)) * 2.0;
	d.y /= stretch;
	float r = length(d);
	float a = pow(clamp(1.0 - r, 0.0, 1.0), 1.8);
	ALBEDO = glow_color * a * strength;
}
