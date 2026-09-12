shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled;
uniform float opacity = 1.0;
uniform bool membrane = false;
void fragment() {
	ALBEDO = vec3(.91);
	EMISSION = vec3(membrane ? .16 : .72);
	ALPHA = opacity * (membrane ? .075 : 1.0);
}
