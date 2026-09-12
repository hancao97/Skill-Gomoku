shader_type canvas_item;
void fragment() {
	vec2 p = UV - 0.5;
	float v = smoothstep(0.3,0.73,length(p * vec2(1.0,0.90)));
	float grain = fract(sin(dot(UV * vec2(1440.,900.) + floor(TIME*12.),vec2(12.9898,78.233)))*43758.5453);
	COLOR = vec4(vec3(0.009,0.023,0.02),v*.56 + grain*.017);
}
