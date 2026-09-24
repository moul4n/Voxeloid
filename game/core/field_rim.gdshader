shader_type canvas_item;
render_mode unshaded;

const int FIELD_COLUMNS = 720;

uniform sampler2D field_texture : filter_nearest, repeat_disable;
uniform sampler2D rim_slots : filter_nearest, repeat_disable;
uniform float simulation_time = 0.0;
uniform float grain_diameter = 2.0;
uniform float display_diameter = 2.0;
uniform vec4 grain_tint : source_color = vec4(0.50, 0.82, 1.0, 1.0);
uniform int visual_epoch = 0;
uniform float distance_mode = 0.0;
uniform float molten_surface_blend = 0.0;
uniform float molten_reservoir_radius = 42.0;

varying float rim_alpha;
varying float rim_brightness;
varying float rim_stretch;

uint hash_u32(uint value) {
	value += 0x9e3779b9u;
	value ^= value >> 16u;
	value *= 0x7feb352du;
	value ^= value >> 15u;
	value *= 0x846ca68bu;
	value ^= value >> 16u;
	return value;
}

float random01(uint value) {
	return float(hash_u32(value) & 0x00ffffffu) * (1.0 / 16777216.0);
}

float surface_at(int column) {
	int wrapped = (column + FIELD_COLUMNS) % FIELD_COLUMNS;
	return texelFetch(field_texture, ivec2(wrapped, 0), 0).g;
}

void vertex() {
	vec4 contact = texelFetch(rim_slots, ivec2(INSTANCE_ID, 0), 0);
	vec4 identity_data = texelFetch(rim_slots, ivec2(INSTANCE_ID, 1), 0);
	float life = clamp((simulation_time - contact.g) / max(contact.b, 0.001), 0.0, 1.0);
	uint local_id = uint(max(contact.a, 0.0));
	uint seed = uint(max(identity_data.r, 0.0));
	uint identity = local_id ^ seed ^ uint(max(visual_epoch, 0)) * 747796405u;
	float angle = contact.r + (random01(local_id ^ seed) - 0.5) * identity_data.g;
	int column = int(floor(mod(angle, TAU) * (float(FIELD_COLUMNS) / TAU))) % FIELD_COLUMNS;
	float here = mix(surface_at(column), molten_reservoir_radius, molten_surface_blend);
	float left = mix(surface_at(column - 1), molten_reservoir_radius, molten_surface_blend);
	float right = mix(surface_at(column + 1), molten_reservoir_radius, molten_surface_blend);
	float downhill = (right < left) ? 1.0 : -1.0;
	float slope = abs(right - left);
	float motion_type = random01(identity ^ 0x85ebca6bu);
	float slide = min(grain_diameter * life * (0.35 + slope * 0.16), grain_diameter * 1.35);
	angle += downhill * slide / max(here, 1.0);
	float bounce = motion_type > 0.55 ? sin(life * PI) * grain_diameter * mix(0.18, 0.72, motion_type) : 0.0;
	float settle = mix(grain_diameter * 0.35 + bounce, -grain_diameter * 0.34, life);
	vec2 radial = vec2(cos(angle), sin(angle));
	vec2 tangent = vec2(-radial.y, radial.x);
	vec2 grain_position = radial * (here + settle);
	rim_alpha = 1.0 - smoothstep(0.72, 1.0, life);
	if (identity_data.a <= 0.0 || simulation_time < contact.g) { rim_alpha = 0.0; }
	rim_brightness = mix(0.94, 1.18, random01(identity ^ 0x63d83595u));
	rim_stretch = motion_type > 0.88 ? 1.0 + mix(0.05, 0.45, distance_mode) * sin(life * PI) : 1.0;
	VERTEX = grain_position + tangent * VERTEX.x * display_diameter + radial * VERTEX.y * display_diameter * rim_stretch;
}

void fragment() {
	vec2 centered_uv = UV * 2.0 - vec2(1.0);
	float radial_distance = length(centered_uv);
	float antialias_width = max(fwidth(radial_distance), 0.001);
	float coverage = 1.0 - smoothstep(1.0 - antialias_width, 1.0 + antialias_width, radial_distance);
	vec3 hot_tint = mix(grain_tint.rgb, vec3(1.0, 0.82, 0.52), 0.10);
	COLOR = vec4(hot_tint * rim_brightness, grain_tint.a * coverage * rim_alpha);
}
