shader_type canvas_item;
render_mode unshaded;

const int FIELD_COLUMNS = 720;
const float RIM_LIFETIME = 1.2;

uniform sampler2D field_texture : filter_nearest, repeat_disable;
uniform sampler2D rim_slots : filter_nearest, repeat_disable;
uniform float simulation_time = 0.0;
uniform float grain_diameter = 2.0;
uniform float display_diameter = 2.0;
uniform vec4 grain_tint : source_color = vec4(0.50, 0.82, 1.0, 1.0);
uniform int visual_epoch = 0;
uniform float distance_mode = 0.0;

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
	int slot_column = int(floor(texelFetch(rim_slots, ivec2(INSTANCE_ID, 0), 0).r + 0.5));
	int column = clamp(slot_column, 0, FIELD_COLUMNS - 1);
	float landing_time = texelFetch(field_texture, ivec2(column, 0), 0).b;
	float event_age = max(simulation_time - landing_time, 0.0);
	// A stable per-instance phase keeps a held emission visibly alive even as
	// the column's latest landing timestamp is refreshed every tick.
	float age = mod(simulation_time + random01(uint(INSTANCE_ID) * 17u + 7u) * RIM_LIFETIME, RIM_LIFETIME);
	float life = clamp(age / RIM_LIFETIME, 0.0, 1.0);
	uint identity = uint(INSTANCE_ID) ^ uint(max(visual_epoch, 0)) * 747796405u;
	float motion_type = random01(identity ^ 0x85ebca6bu);
	float here = surface_at(column);
	float left = surface_at(column - 1);
	float right = surface_at(column + 1);
	float downhill = (right < left) ? 1.0 : -1.0;
	float slope = abs(right - left);
	float slide = min(grain_diameter * (0.16 + life * 0.72) * (1.0 + slope * 0.12), grain_diameter * 1.15);
	float fan = (random01(uint(INSTANCE_ID) * 31u + 19u) - 0.5) * grain_diameter * 0.32;
	float column_jitter = 0.10 + random01(uint(INSTANCE_ID) * 43u + 23u) * 0.80;
	float angle = (float(column) + column_jitter) * (TAU / float(FIELD_COLUMNS));
	angle += downhill * slide / max(here, 1.0) + fan / max(here, 1.0);
	float bounce = motion_type > 0.72 && motion_type < 0.88 ? sin(life * PI) * grain_diameter * 0.55 : 0.0;
	float sink_rate = motion_type < 0.42 ? 0.62 : 0.42;
	float rim_offset = mix(grain_diameter * 1.45 + bounce, -grain_diameter * sink_rate, life);
	vec2 grain_position = vec2(cos(angle), sin(angle)) * (here + rim_offset);
	float event_freshness = 1.0 - smoothstep(RIM_LIFETIME * 0.55, RIM_LIFETIME, event_age);
	rim_alpha = smoothstep(0.0, 0.08, life) * (1.0 - smoothstep(0.64, 1.0, life)) * event_freshness;
	if (slot_column < 0 || slot_column >= FIELD_COLUMNS || event_age >= RIM_LIFETIME) { rim_alpha = 0.0; }
	rim_brightness = mix(0.96, 1.20, random01(identity ^ 0x63d83595u));
	rim_stretch = motion_type > 0.88 ? mix(1.2, 2.0, distance_mode) * sin(life * PI) : 1.0;
	vec2 radial = vec2(cos(angle), sin(angle));
	vec2 tangent = vec2(-radial.y, radial.x);
	VERTEX = grain_position + tangent * VERTEX.x * display_diameter + radial * VERTEX.y * display_diameter * rim_stretch;
}

void fragment() {
	vec2 centered_uv = UV * 2.0 - vec2(1.0);
	float radial_distance = length(centered_uv);
	float antialias_width = max(fwidth(radial_distance), 0.001);
	float coverage = 1.0 - smoothstep(1.0 - antialias_width, 1.0 + antialias_width, radial_distance);
	vec3 hot_tint = mix(grain_tint.rgb, vec3(1.0, 0.82, 0.52), 0.14);
	COLOR = vec4(hot_tint * rim_brightness, grain_tint.a * coverage * rim_alpha);
}
