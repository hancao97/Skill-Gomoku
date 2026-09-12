shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.3, 0.9, 0.85, 1.0);
uniform float strength = 1.0;
uniform float rainbow = 0.0;
uniform float ornate = 0.0;
void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p)*2.0;
	float angle = atan(p.y, p.x);
	float ring = exp(-pow((r-0.83)*62.0,2.0)) + exp(-pow((r-0.76)*80.0,2.0))*0.4;
	float rays = pow(abs(sin(angle*12.0 + TIME*0.5)),24.0) * smoothstep(0.60,0.67,r) * (1.0-smoothstep(0.71,0.73,r));
	float petals = exp(-pow((r-(0.5+sin(angle*8.0+TIME)*.055))*100.0,2.0));
	vec3 spectrum = .55 + .45*cos(angle + TIME + vec3(0.0,2.1,4.2));
	ALBEDO = mix(tint.rgb, spectrum, rainbow)*2.0;
	ALPHA = min(ring + (rays+petals*.35)*ornate,1.0) * tint.a * strength;
}
