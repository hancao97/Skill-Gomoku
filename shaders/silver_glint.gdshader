shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
uniform float strength=1.0;
void vertex() {
	float sx=length(MODEL_MATRIX[0].xyz);
	float sy=length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*sx,INV_VIEW_MATRIX[1]*sy,INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p=(UV-.5)*2.0;
	float cross_a=exp(-abs(p.x)*65.0-abs(p.y)*3.8);
	float cross_b=exp(-abs(p.y)*65.0-abs(p.x)*3.8);
	float core=exp(-length(p)*24.0);
	ALBEDO=vec3(1.8,1.9,2.0);
	ALPHA=(cross_a+cross_b+core)*strength;
}
