shader_type canvas_item;
uniform float reveal=0.0;
uniform float fade=1.0;
uniform bool white_stone=false;
void fragment(){
	vec4 source=texture(TEXTURE,UV);
	float rough=sin(UV.y*207.0)*.007+sin(UV.y*473.0)*.004;
	float sweep=1.0-smoothstep(reveal-.025,reveal+.014,UV.x+rough);
	vec3 ink=white_stone?vec3(.025,.025,.045):vec3(.96,.965,.99);
	COLOR=vec4(ink,source.a*sweep*fade);
}
