shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
uniform sampler2D smoke_noise : repeat_enable, filter_linear;
uniform bool white_stone = false;
uniform float opacity = 1.0;
varying float age;
varying float seed;
void vertex() {
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0]*sx,INV_VIEW_MATRIX[1]*sy,INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
	age = INSTANCE_CUSTOM.y;
	seed = INSTANCE_CUSTOM.x;
}
void fragment() {
	vec2 p = UV-0.5;
	float noise_a = texture(smoke_noise,UV*.75 + vec2(seed*.17,-age*.31)).r;
	float noise_b = texture(smoke_noise,UV*1.7 + vec2(age*.08,seed*.13)).r;
	float billow = noise_a*.72 + noise_b*.28;
	float edge = length(p*vec2(1.0,.88));
	float mask = smoothstep(.13,.56,billow-edge*.86) * (1.0-smoothstep(.30,.51,edge));
	float fade = smoothstep(0.0,.14,age) * (1.0-smoothstep(.38,1.0,age));
	ALBEDO = white_stone ? vec3(.91,.95,1.0) : mix(vec3(.004,.004,.007),vec3(.055,.055,.065),noise_b*.28);
	EMISSION = white_stone ? vec3(.6,.68,.8)*mask : vec3(0.0);
	ALPHA = mask*fade*opacity*(white_stone ? .24 : .72)*COLOR.a;
}
