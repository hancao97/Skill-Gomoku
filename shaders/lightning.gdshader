shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled;

uniform bool white_stone = false;
uniform float strength = 1.0;
uniform float reveal = 1.0;

void fragment() {
	float x = abs(UV.x-.5)*2.0;
	float core = exp(-x*x*30.0);
	float rim = exp(-pow((x-.39)*10.0,2.0));
	float mist = exp(-x*x*4.0)*.20;
	float visible_path = 1.0-smoothstep(reveal-.05,reveal,UV.y);
	vec3 cold_white = vec3(.86,.92,1.0);
	// Black owns a dark fissure with an electric edge; White owns a silver filament.
	ALBEDO = white_stone ? cold_white : mix(vec3(.004,.003,.009),vec3(.75,.72,.91),rim);
	EMISSION = white_stone ? cold_white*(core*5.0+mist) : vec3(.72,.69,.91)*(rim*3.7+mist*.5);
	ALPHA = (white_stone ? max(core,mist) : max(max(core,rim),mist)) * strength * visible_path;
}
