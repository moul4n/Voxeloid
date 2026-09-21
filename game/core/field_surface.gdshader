shader_type canvas_item;
render_mode unshaded;

const int FIELD_COLUMNS = 720;
const int SEARCH_STEPS = 10;
const int RADIAL_LOOKUP_SAMPLES = 16;

uniform sampler2D field_texture : filter_nearest, repeat_disable;
uniform float simulation_time = 0.0;
uniform float core_radius = 43.0;
uniform float grain_diameter = 2.0;
uniform float display_diameter = 2.0;
uniform int settled_count = 1;
uniform int logical_settled_count = 1;
uniform vec4 grain_tint : source_color = vec4(0.50, 0.82, 1.0, 1.0);
uniform float compaction_loose_packing = 0.72;
uniform float compaction_max_packing = 0.94;
uniform float compaction_depth_darkening = 0.20;
uniform int visual_epoch = 0;
uniform float distance_mode = 0.0;

varying float local_density_fraction;
varying float visual_brightness;
varying float visual_warmth;
varying float visual_glow;
varying float visual_core_radius;

float lookup_value(int column, int point, int channel) {
	int wrapped = (column + FIELD_COLUMNS) % FIELD_COLUMNS;
	return texelFetch(field_texture, ivec2(wrapped, point + 1), 0)[channel];
}

float smooth_lookup_value(int column, float column_fraction, int point, int channel) {
	return mix(
		lookup_value(column, point, channel),
		lookup_value(column + 1, point, channel),
		column_fraction);
}

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

void vertex() {
	int particle_id = INSTANCE_ID;
	uint identity = uint(particle_id) ^ uint(max(visual_epoch, 0)) * 747796405u;
	uint pair_id = uint(particle_id / 2);
	bool reverse_search = (particle_id & 1) == 1;
	float area_jitter = random01(uint(particle_id) * 2u + 91u);
	// Stable sampling: appending grains must not start at the end of the
	// angular CDF or move every existing sample just because count changed.
	float pair_quantile = random01(pair_id * 3u + 173u);
	// Reverse-CDF partners use the complementary quantile. On an even field
	// this places both members of a pair at the same angle; when local mass is
	// added, they then peel away from that point in opposite directions. Using
	// the same quantile here would put the partner across the body and only
	// balance the motion globally, leaving each local area visibly one-sided.
	float quantile = reverse_search ? 1.0 - pair_quantile : pair_quantile;

	int low = 0;
	int high = FIELD_COLUMNS - 1;
	for (int search = 0; search < SEARCH_STEPS; search++) {
		int middle = (low + high) / 2;
		int texture_column = reverse_search ? FIELD_COLUMNS - 1 - middle : middle;
		float cumulative = reverse_search ?
			texelFetch(field_texture, ivec2(texture_column, 0), 0).a :
			texelFetch(field_texture, ivec2(texture_column, 0), 0).r;
		if (cumulative < quantile) {
			low = middle + 1;
		} else {
			high = middle;
		}
	}
	int logical_column = min(low, FIELD_COLUMNS - 1);
	int column = reverse_search ? FIELD_COLUMNS - 1 - logical_column : logical_column;
	float cdf_end = reverse_search ?
		texelFetch(field_texture, ivec2(column, 0), 0).a :
		texelFetch(field_texture, ivec2(column, 0), 0).r;
	float cdf_begin = 0.0;
	if (logical_column > 0) {
		cdf_begin = reverse_search ?
			texelFetch(field_texture, ivec2(column + 1, 0), 0).a :
			texelFetch(field_texture, ivec2(column - 1, 0), 0).r;
	}
	float column_mass = max(cdf_end - cdf_begin, 0.000001);
	float travel_fraction = clamp((quantile - cdf_begin) / column_mass, 0.0, 1.0);
	float column_fraction = reverse_search ? 1.0 - travel_fraction : travel_fraction;
	float angle = (float(column) + column_fraction) * (TAU / float(FIELD_COLUMNS));
	float lookup_position = area_jitter * float(RADIAL_LOOKUP_SAMPLES);
	int lookup_low = int(floor(lookup_position));
	int lookup_high = min(lookup_low + 1, RADIAL_LOOKUP_SAMPLES);
	float lookup_fraction = fract(lookup_position);
	float radius_squared = mix(
		smooth_lookup_value(column, column_fraction, lookup_low, 0),
		smooth_lookup_value(column, column_fraction, lookup_high, 0), lookup_fraction);
	float local_packing = mix(
		smooth_lookup_value(column, column_fraction, lookup_low, 1),
		smooth_lookup_value(column, column_fraction, lookup_high, 1), lookup_fraction);
	float radius = sqrt(max(radius_squared, 0.0));
	vec2 grain_position = vec2(cos(angle), sin(angle)) * radius;
	float density_fraction = clamp((local_packing - compaction_loose_packing) /
		max(compaction_max_packing - compaction_loose_packing, 0.001), 0.0, 1.0);
	local_density_fraction = density_fraction;
	float size_hash = random01(identity ^ 0xa511e9b3u);
	float size_scale = mix(0.75, 1.30, smoothstep(0.08, 0.92, size_hash));
	visual_brightness = mix(0.95, 1.08, random01(identity ^ 0x63d83595u));
	visual_warmth = mix(-0.035, 0.045, random01(identity ^ 0x9e3779b9u));
	float glow_class = random01(identity ^ 0x85ebca6bu);
	visual_glow = glow_class > 0.995 ? 1.0 : (glow_class > 0.96 ? 0.56 : (glow_class > 0.80 ? 0.20 : 0.0));
	float halo_scale = 1.0 + visual_glow * mix(0.10, 0.20, distance_mode);
	visual_core_radius = 1.0 / halo_scale;
	VERTEX = grain_position + VERTEX * display_diameter * size_scale * halo_scale * (1.0 + density_fraction * 0.75);
}

void fragment() {
	vec2 centered_uv = UV * 2.0 - vec2(1.0);
	float radial_distance = length(centered_uv);
	float antialias_width = max(fwidth(radial_distance), 0.001);
	float coverage = 1.0 - smoothstep(visual_core_radius - antialias_width, visual_core_radius + antialias_width, radial_distance);
	float halo = (1.0 - smoothstep(visual_core_radius, 1.0, radial_distance)) * visual_glow;
	float depth_tint = 1.0 - local_density_fraction * compaction_depth_darkening;
	// Packed grains merge into the matching continuous bulk underneath.
	float individual_visibility = 1.0 - smoothstep(0.30, 0.72, local_density_fraction);
	vec3 varied_tint = grain_tint.rgb * visual_brightness;
	varied_tint = mix(varied_tint, vec3(1.0, 0.73, 0.38), max(visual_warmth, 0.0));
	varied_tint = mix(varied_tint, vec3(0.62, 0.80, 1.0), max(-visual_warmth, 0.0));
	float alpha = max(coverage, halo * 0.26) * individual_visibility;
	COLOR = vec4(varied_tint * depth_tint + halo * varied_tint * 0.18, grain_tint.a * alpha);
}
