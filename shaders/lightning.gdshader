shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled;

uniform bool white_stone = false;
uniform float strength = 1.0;
uniform float reveal = 1.0;

void fragment() {
	float x = abs(UV.x-.5)*2.0;
	float core = exp(-x*x*(white_stone?30.0:4.0));
	float rim = exp(-pow((x-.77)*22.0,2.0));
	float mist = exp(-x*x*4.0)*.20;
	float visible_path = 1.0-smoothstep(reveal-.05,reveal,UV.y);
	vec3 cold_white = vec3(.96,.97,1.0);
	// Black owns a dark fissure with an electric edge; White owns a silver filament.
	ALBEDO = white_stone ? cold_white : mix(vec3(.003),vec3(.11),rim*.6);
	EMISSION = white_stone ? cold_white*(core*5.0+mist) : vec3(.035)*rim;
	ALPHA = (white_stone ? max(core,mist) : max(max(core,rim),mist)) * strength * visible_path;
}
