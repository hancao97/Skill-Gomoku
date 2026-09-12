shader_type spatial;
uniform float charge = 0.0;
void fragment() {
	float edge=pow(1.0-max(0.0,dot(NORMAL,VIEW)),6.0);
	float flowing=sin(VERTEX.y*24.0+sin(VERTEX.x*16.0)*2.0-TIME*2.2)*.5+.5;
	ALBEDO=vec3(.006+pow(flowing,8.0)*charge*.004);
	ROUGHNESS=.18;
	METALLIC=.12;
	SPECULAR=.65;
	EMISSION=vec3(.20)*edge*charge*(.65+flowing*.35);
}
