shader_type spatial;
uniform vec4 base_color : source_color = vec4(.13,.19,.16,1.0);
uniform float moss = 0.0;
uniform float wood = 0.0;
varying vec3 world;
varying vec3 world_normal;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise(vec3 p) {
	vec3 i=floor(p), f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
	mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex(){
	world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
	vec3 p=world*mix(vec3(3.0),vec3(25.0,1.5,25.0),wood);
	float n=noise(p)*.5+noise(p*3.1)*.3+noise(p*12.3)*.2;
	ALBEDO=base_color.rgb*(.55+n*.65);
	float cover=smoothstep(.35,.68,n)*smoothstep(.15,.72,world_normal.y)*moss;
	ALBEDO=mix(ALBEDO,vec3(.075,.145,.040)*(0.55+n*.65),cover);
	ROUGHNESS=mix(.47,.89,max(cover,wood));
	SPECULAR=.3;
}
