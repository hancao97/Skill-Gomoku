shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float speed = 10.0;
uniform vec3 tint : source_color = vec3(0.48, 0.70, 0.68);
varying float opacity;
void vertex() {
	VERTEX.y += mod(INSTANCE_CUSTOM.x * 14.0 - TIME * speed + 100000.0, 14.0);
	opacity = INSTANCE_CUSTOM.y;
}
void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;
	float a = pow(1.0 - x, 2.0) * sin(UV.y * 3.14159);
	ALBEDO = tint;
	ALPHA = a * opacity * 0.23;
}
