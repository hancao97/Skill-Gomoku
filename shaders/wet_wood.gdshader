shader_type spatial;
uniform sampler2D grain : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 wood = texture(grain, UV).rgb;
	vec2 p = world.xz;
	float sheen = sin(p.x * 15.0 + sin(p.y * 8.0)) * sin(p.y * 21.0);
	vec2 tile = floor(p * 2.6);
	vec2 local = fract(p * 2.6) - 0.5;
	float h = fract(sin(dot(tile, vec2(127.1, 311.7))) * 43758.5453);
	float age = fract(TIME * 0.7 + h);
	float radius = length(local);
	float wave = sin((radius - age * 0.72) * 90.0) * exp(-abs(radius - age * 0.65) * 28.0) * (1.0 - age);
	ALBEDO = wood * vec3(1.05, 0.94, 0.81);
	ROUGHNESS = 0.26 + sheen * 0.025;
	SPECULAR = 0.6;
	METALLIC = 0.035;
	NORMAL_MAP = vec3(0.5 + wave * local.x * 0.12, 0.5 + wave * local.y * 0.12, 1.0);
	NORMAL_MAP_DEPTH = 0.18;
}
