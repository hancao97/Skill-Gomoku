shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
uniform float formation = 0.0;
uniform float rotation_phase = 0.0;
uniform float strength = 0.0;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float angle = atan(p.y,p.x);
	float quarter = fract(angle / 6.2831853 * 4.0 - rotation_phase);
	float four_trails = pow(quarter,3.0)*(1.0-smoothstep(.96,1.0,quarter));
	float merged = mix(four_trails,1.0,formation);
	float body = exp(-pow((r-.72)*25.0,2.0));
	float outer_edge = exp(-pow((r-0.76)*100.0,2.0))*.35;
	float inner_edge = exp(-pow((r-0.67)*100.0,2.0))*.24;
	float halo = exp(-pow((r-0.75)*13.0,2.0))*.18;
	ALBEDO = mix(vec3(.72,.78,.90),vec3(.98,.985,1.0),body) * 1.7;
	ALPHA = clamp(body*merged + (outer_edge+inner_edge*.55)*formation + halo,0.0,1.0)*strength;
}
