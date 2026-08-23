shader_type spatial;
render_mode unshaded;

// Neon edge treatment (architecture §16/16.4): minimal white geometry with
// emissive accentuation — a fresnel rim that lights silhouettes plus faint
// world-space grid lines every 128u. Tint is per-instance, driven by
// WorldMaterials from the loaded map's MapMetadata (or difficulty palette).

instance uniform vec4 tint : source_color = vec4(0.15, 0.85, 1.0, 1.0);
instance uniform float grid_strength : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	float fresnel = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.0);

	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 cell = abs(fract(world_pos / 128.0) - 0.5);
	float line_dist = min(min(cell.x, cell.y), cell.z);
	float grid = 1.0 - smoothstep(0.0, 0.03, line_dist);

	ALBEDO = vec3(0.92);
	EMISSION = tint.rgb * clamp(fresnel * 0.9 + grid * grid_strength, 0.0, 1.2);
}
