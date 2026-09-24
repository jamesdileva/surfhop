shader_type spatial;
render_mode unshaded;

// Surf ramp feedback (architecture 16.4): base white geometry that shifts
// toward a neon emissive tint while the player rides the surface. The glow
// amount is a per-instance uniform driven by VisualEffects from surf events,
// so every SurfRamp* mesh shares one shader with independent intensity.

// NOTE: base/glow colors MUST stay `instance uniform` — VisualEffects sets
// them per-ramp via set_instance_shader_parameter (map accent as dark base,
// difficulty tint as glow). Plain `uniform` silently ignores per-instance
// values and every ramp renders the near-white defaults (white-on-white).
instance uniform float glow : hint_range(0.0, 1.0) = 0.0;
instance uniform vec3 base_color : source_color = vec3(0.85, 0.85, 0.87);
instance uniform vec3 glow_color : source_color = vec3(0.15, 0.85, 1.0);

void fragment() {
	ALBEDO = mix(base_color, glow_color, glow);
	EMISSION = glow_color * glow * 1.4;
}
