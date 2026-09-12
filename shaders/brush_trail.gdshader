shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
uniform vec4 ink : source_color = vec4(.005,.005,.012,1.0);
uniform float strength = 1.0;
uniform float flow = 0.0;
uniform sampler2D grain : repeat_enable, filter_linear;
void fragment() {
	float noise_a = texture(grain,vec2(UV.x*2.0,UV.y*8.0-flow)).r;
	float edge = abs(UV.x-.5)*2.0;
	float rough_edge = 1.0-smoothstep(.56+noise_a*.30,.94,edge);
	float scratches = smoothstep(.12,.30,noise_a);
	ALBEDO = ink.rgb;
	EMISSION = ink.rgb*1.2;
	ALPHA = rough_edge * mix(.5,1.0,scratches) * strength * ink.a;
}
