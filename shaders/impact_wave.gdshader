shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
uniform sampler2D grain : repeat_enable, filter_linear;
uniform float progress = 0.0;
uniform bool white_stone = false;
void fragment() {
	vec2 p=(UV-.5)*2.0;
	float r=length(p);
	float a=atan(p.y,p.x);
	float n=texture(grain,p*1.5+vec2(progress*.16,0.0)).r;
	float front=progress*.92;
	float band=exp(-pow((r-front + (n-.5)*.08)/(.028+.045*(1.0-progress)),2.0));
	float brush=pow(max(0.0,sin(a*19.0+n*8.0)),7.0)*exp(-abs(r-front)*9.0)*.5;
	float fade=1.0-smoothstep(.54,1.0,progress);
	ALBEDO=white_stone ? vec3(.92,.97,1.0) : vec3(.006,.007,.012);
	EMISSION=white_stone ? vec3(1.3,1.45,1.6)*band : vec3(0.0);
	ALPHA=clamp(band+brush,0.0,1.0)*fade;
}
