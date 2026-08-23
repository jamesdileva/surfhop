shader_type spatial;
render_mode unshaded;

// Surf ramp feedback (architecture 16.4): base white geometry that shifts
// toward a neon emissive tint while the player rides the surface. The glow
// amount is a per-instance uniform driven by VisualEffects from surf events,
// so every SurfRamp* mesh shares one shader with independent intensity.

instance uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform vec3 base_color : source_color = vec3(0.85, 0.85, 0.87);
uniform vec3 glow_color : source_color = vec3(0.15, 0.85, 1.0);

void fragment() {
	ALBEDO = mix(base_color, glow_color, glow);
	EMISSION = glow_color * glow * 1.4;
}
