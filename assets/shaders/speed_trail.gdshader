shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled;

// Speed trail streak (architecture 16.4): soft additive billboard used by
// SpeedTrail.tscn particles spawned behind the player above 600 u/s.

uniform vec4 trail_color : source_color = vec4(0.5, 0.8, 1.0, 1.0);

void fragment() {
	float core = smoothstep(0.5, 0.0, distance(UV, vec2(0.5)));
	ALBEDO = trail_color.rgb * core;
	ALPHA = core * trail_color.a;
}
