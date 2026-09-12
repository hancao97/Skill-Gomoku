shader_type spatial;
render_mode cull_disabled;
uniform vec4 leaf_color : source_color = vec4(.08,.19,.11,1.0);
varying float shade;
void vertex() {
	vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	float wind=sin(TIME*.8+world.x*.7+world.z*.3)*sin(TIME*.5+world.z*.5);
	VERTEX.x += wind*.045*clamp(world.y,0.0,5.0);
	VERTEX.z += wind*.025;
	shade=.8+.2*sin(world.x*5.0+world.y*6.0);
}
void fragment(){
	ALBEDO=leaf_color.rgb*shade;
	ROUGHNESS=.95;
	SPECULAR=.1;
}
