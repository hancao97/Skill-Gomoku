shader_type spatial;
uniform float charge = 0.0;
void fragment() {
	float edge=pow(1.0-max(0.0,dot(NORMAL,VIEW)),6.0);
	vec3 prismatic=.5+.5*cos(TIME*1.8+VERTEX.y*9.0+vec3(0.0,2.1,4.2));
	ALBEDO=vec3(.009,.009,.014);
	ROUGHNESS=.18;
	METALLIC=.12;
	SPECULAR=.65;
	EMISSION=mix(vec3(.38,.41,.48),prismatic,.38)*edge*charge*1.8;
}
