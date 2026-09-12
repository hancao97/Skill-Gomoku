shader_type canvas_item;
uniform float reveal=0.0;
uniform float fade=1.0;
uniform bool white_stone=false;
void fragment(){
	vec4 source=texture(TEXTURE,UV);
	float rough=sin(UV.y*207.0)*.007+sin(UV.y*473.0)*.004;
	float sweep=1.0-smoothstep(reveal-.025,reveal+.014,UV.x+rough);
	vec3 ink=white_stone?vec3(.97):vec3(.006);
	// A narrow opposing outline keeps same-colour brushwork legible in the forest.
	vec2 texel=TEXTURE_PIXEL_SIZE*1.4;
	float edge=0.0;
	edge=max(edge,texture(TEXTURE,UV+vec2(texel.x,0)).a);
	edge=max(edge,texture(TEXTURE,UV-vec2(texel.x,0)).a);
	edge=max(edge,texture(TEXTURE,UV+vec2(0,texel.y)).a);
	edge=max(edge,texture(TEXTURE,UV-vec2(0,texel.y)).a);
	float outline=max(0.0,edge-source.a)*.50;
	COLOR=vec4(mix(white_stone?vec3(.035):vec3(.68),ink,source.a/max(source.a+outline,.001)),(source.a+outline)*sweep*fade);
}
