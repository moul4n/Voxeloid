shader_type canvas_item;
render_mode unshaded;

const int FIELD_COLUMNS = 720;
const int MAX_BATCHES = 1024;
const int SEARCH_STEPS = 11;

uniform sampler2D batch_texture : filter_nearest, repeat_disable;
uniform sampler2D field_texture : filter_nearest, repeat_disable;
uniform float simulation_time = 0.0;
uniform float core_radius = 43.0;
uniform float grain_diameter = 2.0;
uniform float display_diameter = 2.0;
uniform int air_batch_count = 0;
uniform int drawn_air_count = 1;
uniform int logical_air_count = 1;
uniform vec4 grain_tint : source_color = vec4(0.50, 0.82, 1.0, 1.0);
uniform int visual_epoch = 0;
uniform float distance_mode = 0.0;

varying float arrival_alpha;
varying float visual_brightness;
varying float visual_warmth;
varying float visual_glow;
varying float trail_strength;

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

uniform float impact_settle_seconds = 0.55;

void vertex() {
	int particle_id = INSTANCE_ID;
	int batch_limit = clamp(air_batch_count, 1, MAX_BATCHES);
	float quantile = (float(particle_id) + 0.5) / max(float(drawn_air_count), 1.0);
	int low = 0;
	int high = batch_limit - 1;
	for (int search = 0; search < SEARCH_STEPS; search++) {
		int middle = (low + high) / 2;
		float cumulative = texelFetch(batch_texture, ivec2(middle, 0), 0).r;
		if (cumulative < quantile) {
			low = middle + 1;
		} else {
			high = middle;
		}
	}
	int batch_index = min(low, batch_limit - 1);
	vec4 batch_a = texelFetch(batch_texture, ivec2(batch_index, 0), 0);
	vec4 batch_b = texelFetch(batch_texture, ivec2(batch_index, 1), 0);
	float previous_count = 0.0;
	if (batch_index > 0) {
		previous_count = texelFetch(batch_texture, ivec2(batch_index - 1, 0), 0).r;
	}
	float batch_fraction = clamp((quantile - previous_count) / max(batch_a.r - previous_count, 0.000001), 0.0, 1.0);
	float batch_amount = max((batch_a.r - previous_count) * float(logical_air_count), 1.0);
	uint local_id = uint(floor(batch_fraction * batch_amount));
	uint identity = local_id ^ uint(max(visual_epoch, 0)) * 747796405u ^ uint(max(batch_b.a, 0.0));
	float angle_jitter = random01(local_id ^ uint(max(batch_b.a, 0.0)));
	float angle = batch_a.g + (angle_jitter - 0.5) * batch_b.b;
	float duration = max(batch_a.a, 0.0001);
	float progress = clamp((simulation_time - batch_a.b) / duration, 0.0, 1.0);
	int column = int(floor(mod(angle, TAU) * (float(FIELD_COLUMNS) / TAU))) % FIELD_COLUMNS;
	// Keep the trajectory inward.  A growing surface may occlude it, but never
	// pushes a visible particle back out through the field.
	float endpoint = min(batch_b.g, batch_b.r);
	// Spread a burst along its flight instead of drawing a single thin arc.
	float fall_power = mix(1.65, 2.35, random01(local_id ^ 8179u));
	float radius = mix(batch_b.r, endpoint, pow(progress, fall_power));
	float surface_radius = texelFetch(field_texture, ivec2(column, 0), 0).g;
	float handoff_radius = surface_radius + grain_diameter * 0.35;
	float final_fade = 1.0 - smoothstep(1.0 - min(max(impact_settle_seconds, 0.01) / duration, 0.35), 1.0, progress);
	float occluded = smoothstep(handoff_radius - grain_diameter * 0.35, handoff_radius + grain_diameter * 0.35, radius);
	arrival_alpha = final_fade * occluded;
	float speed_shape = sin(progress * PI);
	float trail_random = mix(0.72, 1.28, random01(identity ^ 0x27d4eb2du));
	float trail_length = 1.0 + speed_shape * trail_random * mix(0.65, 1.55, distance_mode);
	float size_scale = mix(0.72, 1.36, smoothstep(0.06, 0.94, random01(identity ^ 0xa511e9b3u)));
	visual_brightness = mix(0.90, 1.18, random01(identity ^ 0x63d83595u));
	visual_warmth = mix(0.0, 0.10, random01(identity ^ 0x9e3779b9u));
	float glow_class = random01(identity ^ 0x85ebca6bu);
	visual_glow = glow_class > 0.995 ? 1.0 : (glow_class > 0.96 ? 0.62 : (glow_class > 0.80 ? 0.24 : 0.0));
	float phase = random01(identity ^ 0xc2b2ae35u) * TAU;
	float speed = mix(2.2, 5.4, random01(identity ^ 0x165667b1u));
	float twinkle = glow_class > 0.80 ? 1.0 + 0.10 * sin(simulation_time * speed + phase) : 1.0;
	visual_brightness *= twinkle;
	trail_strength = clamp((trail_length - 1.0) / 1.55, 0.0, 1.0);
	vec2 radial = vec2(cos(angle), sin(angle));
	vec2 tangent = vec2(-radial.y, radial.x);
	VERTEX = radial * radius + tangent * VERTEX.x * display_diameter * size_scale + radial * VERTEX.y * display_diameter * size_scale * trail_length;
}

void fragment() {
	vec2 centered_uv = UV * 2.0 - vec2(1.0);
	float radial_distance = length(centered_uv);
	float antialias_width = max(fwidth(radial_distance), 0.001);
	float coverage = 1.0 - smoothstep(1.0 - antialias_width, 1.0 + antialias_width, radial_distance);
	float trail_fade = mix(1.0, smoothstep(-1.0, 0.72, centered_uv.y), trail_strength * 0.58);
	float halo = (1.0 - smoothstep(0.58, 1.0, radial_distance)) * visual_glow;
	vec3 varied_tint = mix(grain_tint.rgb * visual_brightness, vec3(1.0, 0.78, 0.48), visual_warmth);
	float alpha = max(coverage * trail_fade, halo * 0.28) * arrival_alpha;
	COLOR = vec4(varied_tint + halo * varied_tint * 0.24, grain_tint.a * alpha);
}
