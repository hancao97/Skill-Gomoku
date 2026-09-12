shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.65, 0.79, 0.72, 0.32);
uniform float speed = 0.65;
varying float age;
void vertex() {
	age = fract(TIME * speed + INSTANCE_CUSTOM.x);
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float ring = exp(-pow((d - age) * 70.0, 2.0));
	float inner = exp(-pow((d - age * 0.72) * 80.0, 2.0)) * 0.25;
	ALBEDO = tint.rgb;
	ALPHA = (ring + inner) * (1.0 - age) * smoothstep(0.0, 0.1, age) * tint.a;
}
