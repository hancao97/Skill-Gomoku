shader_type spatial;
render_mode blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, unshaded, shadows_disabled, fog_disabled;
uniform float charge : hint_range(0.0,1.0) = 0.0;

void vertex() {
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
}

float hash(vec2 p) {
	return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}

float noise(vec2 p) {
	vec2 i=floor(p), f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}

float stroke(vec2 p,float angle,float width,float reach,float seed) {
	vec2 axis=vec2(cos(angle),sin(angle));
	float along=dot(p,axis);
	float across=dot(p,vec2(-axis.y,axis.x));
	// Curved ink veins with fibres flowing inward rather than a rotating star.
	float bend=sin(along*5.0+seed)*along*along*.19;
	float fibre=noise(vec2(along*35.0+TIME*2.2,seed))*.34+.66;
	float taper=(.48+along*.8)*(1.0-smoothstep(reach*.46,reach,along));
	float spread=max(.001,width*taper*fibre);
	float blade=1.0-smoothstep(spread*.20,spread,abs(across+bend));
	float torn=noise(vec2(across*420.0+seed,along*24.0+TIME*2.7));
	float fringe=exp(-abs(across+bend)/max(spread*2.0,.001))*.26*torn;
	return (blade*mix(.35,1.0,torn)+fringe)*smoothstep(.11,.18,along)*(1.0-smoothstep(reach*.78,reach,along));
}

void fragment() {
	vec2 p=(UV-.5)*2.0;
	float r=length(p);
	float angle=atan(p.y,p.x);
	float power=charge*charge;
	float reach=.18+.76*pow(charge,.8);
	float rays=0.0;
	rays+=stroke(p,.32,.042,reach,1.2);
	rays+=stroke(p,1.72,.016,reach*.80,3.3);
	rays+=stroke(p,2.64,.056,reach*.92,5.4);
	rays+=stroke(p,3.57,.018,reach,7.5);
	rays+=stroke(p,4.34,.014,reach*.70,9.6);
	rays+=stroke(p,5.25,.049,reach*.94,11.7);
	rays+=stroke(p,6.08,.013,reach*.69,13.8);
	float turbulence=noise(p*13.0+vec2(TIME*.25,-TIME*.35));
	float spiral=angle+r*9.0-TIME*.7;
	float collar=exp(-pow((r-.235)/.073,2.0));
	collar*=pow(max(0.0,sin(spiral*3.0+sin(angle*7.0)*.4)),1.2);
	collar*=.20+smoothstep(.2,.75,noise(p*57.0+vec2(TIME*.3)))*.80;
	float orbit=exp(-pow((r-.225-sin(spiral*2.0)*.038)/.018,2.0));
	orbit*=smoothstep(-.55,.45,sin(spiral*2.0));
	float mist=exp(-r*7.0)*turbulence*1.50;
	// Evaluate one angular lane per pixel instead of 26 overlapping emitters.
	float lane=(angle+r*.6+sin(angle*4.0)*.12)*4.14;
	float seed=hash(vec2(floor(lane),17.0));
	float angular=fract(lane)-.5;
	float line=exp(-angular*angular*850.0);
	float tip=.17+(1.0-fract(seed+TIME*(.27+seed*.3)))*(reach-.12);
	float length=.06+seed*.19;
	float strands=line*smoothstep(tip-length,tip,r)*(1.0-smoothstep(tip,tip+.025,r));
	strands*=smoothstep(.15,.24,r)*(1.0-smoothstep(reach*.78,reach,r))*.85*power;
	float mask=smoothstep(.125,.164,r)*(1.0-smoothstep(.91,1.0,r));
	float density=clamp(rays+collar*1.45+orbit*.55+mist+strands,0.0,1.0);
	// Black is pigment, not additive light. Graphite fibres give the ink depth.
	float graphite=pow(turbulence,3.0)*.022;
	ALBEDO=vec3(.003+graphite);
	ALPHA=density*mask*(.10+.88*charge);
}
