shader_type spatial;
render_mode blend_add, depth_draw_never, depth_test_disabled, cull_disabled, unshaded, shadows_disabled;
uniform float charge : hint_range(0.0,1.0) = 0.0;

void vertex() {
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
}

float beam(vec2 p,float angle,float width,float reach) {
	vec2 axis=vec2(cos(angle),sin(angle));
	float along=dot(p,axis);
	float across=abs(dot(p,vec2(-axis.y,axis.x)));
	float spread=width*(.16+max(along,0.0)*1.4);
	float blade=1.0-smoothstep(spread*.60,spread*1.7,across);
	float bloom=exp(-across/max(spread*2.5,.001))*.23;
	return (blade+bloom)*smoothstep(.022,.075,along)*(1.0-smoothstep(reach*.46,reach,along));
}

void fragment() {
	vec2 p=(UV-.5)*2.0;
	float r=length(p);
	float power=charge*charge;
	float reach=.11+.86*pow(charge,.85);
	float drift=sin(TIME*.38)*.028;
	float rays=0.0;
	// Broad, asymmetrical light blades interleaved with hairline rays.
	rays+=beam(p,.38+drift,.078,reach);
	rays+=beam(p,2.16-drift,.092,reach*.90);
	rays+=beam(p,3.63+drift,.115,reach);
	rays+=beam(p,5.28-drift,.087,reach*.94);
	rays+=beam(p,1.02+drift,.027,reach*.87);
	rays+=beam(p,2.85-drift,.024,reach*.83);
	rays+=beam(p,4.51+drift,.019,reach*.92);
	rays+=beam(p,5.91-drift,.025,reach);
	float halo=exp(-r*15.0)*smoothstep(.023,.060,r)*(1.0+power*2.0);
	float threads=pow(abs(sin(atan(p.y,p.x)*13.0+TIME*.18)),70.0);
	threads*=exp(-r*5.0)*smoothstep(.055,.13,r)*power*.40;
	float shape=(rays+halo+threads)*(1.0-smoothstep(.90,1.0,r));
	ALBEDO=mix(vec3(.47,.57,.90),vec3(1.5,1.65,1.95),charge)*(.10+power*1.45);
	float core_mask=smoothstep(.060,.105,r);
	ALPHA=clamp(shape,0.0,1.0)*core_mask*(.05+.90*charge);
}
