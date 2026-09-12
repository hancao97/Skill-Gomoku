shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float amount=0.0;
uniform float pulse=0.0;
uniform bool white_stone=false;
uniform vec2 origin=vec2(.62,.5);
void fragment() {
	vec2 p=SCREEN_UV-origin;
	p.x*=1.6;
	float r=length(p);
	float angle=atan(p.y,p.x);
	float distortion=sin(r*68.0-pulse*15.0)*exp(-r*3.0)*pulse*.007;
	vec3 scene=texture(screen_texture,SCREEN_UV+normalize(p+vec2(.00001))*distortion).rgb;
	float luma=dot(scene,vec3(.2126,.7152,.0722));
	scene=mix(scene,mix(scene,vec3(luma),.50)*(white_stone? .95:.76),amount);
	float edge=smoothstep(.28,.79,length((SCREEN_UV-.5)*vec2(1.25,1.0)));
	scene*=1.0-edge*amount*.63;
	float line_a=pow(abs(sin(angle*71.0+sin(angle*19.0)*3.0)),42.0);
	float lines=line_a*smoothstep(.12,.62,r)*pulse*.48;
	scene=white_stone ? scene+vec3(lines*.75) : scene-vec3(lines*.55);
	float flash=exp(-r*2.2)*pulse*.17;
	scene=white_stone?scene+vec3(flash):scene*(1.0-flash*.9);
	float bars=(1.0-step(.055*amount,SCREEN_UV.y))+step(1.0-.055*amount,SCREEN_UV.y);
	COLOR=vec4(mix(scene,vec3(.004,.005,.008),clamp(bars,0.0,1.0)),1.0);
}
