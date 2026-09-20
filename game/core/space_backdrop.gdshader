shader_type canvas_item;
render_mode unshaded;
uniform float simulation_time = 0.0;
uniform sampler2D haze_texture : filter_linear, repeat_enable;
void fragment() {
	float haze = texture(haze_texture, UV * vec2(1.0, 0.72) + vec2(simulation_time * 0.00015, 0.0)).r;
	float wisp = smoothstep(0.45, 0.85, haze) * 0.26;
	vec3 deep = vec3(0.012, 0.022, 0.041);
	vec3 colour = deep + vec3(0.019, 0.036, 0.052) * wisp;
	colour += vec3(0.019, 0.009, 0.027) * smoothstep(0.65, 0.85, haze) * 0.3;
	colour *= 1.0 - smoothstep(0.25, 0.8, length(UV - 0.5)) * 0.4;
	COLOR = vec4(colour, 1.0);
}
