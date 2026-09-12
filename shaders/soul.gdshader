shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.27, 0.9, 0.82, 1.0);
uniform float strength = 1.0;
uniform float rainbow = 0.0;
void fragment() {
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.4);
	vec3 spectrum = 0.5 + 0.5*cos(TIME*2.0 + VERTEX.y*3.0 + vec3(0.0,2.1,4.2));
	ALBEDO = mix(tint.rgb, spectrum, rainbow) * 2.0;
	ALPHA = (fresnel * 0.75 + 0.04) * tint.a * strength;
}
