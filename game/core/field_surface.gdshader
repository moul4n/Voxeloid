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

varying float local_density_fraction;

float lookup_value(int column, int point, int channel) {
	return texelFetch(field_texture, ivec2(column, point + 1), 0)[channel];
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
	float area_jitter = random01(uint(particle_id) * 2u + 91u);
	// Stable sampling: appending grains must not start at the end of the
	// angular CDF or move every existing sample just because count changed.
	float quantile = random01(uint(particle_id) * 3u + 173u);

	int low = 0;
	int high = FIELD_COLUMNS - 1;
	for (int search = 0; search < SEARCH_STEPS; search++) {
		int middle = (low + high) / 2;
		float cumulative = texelFetch(field_texture, ivec2(middle, 0), 0).r;
		if (cumulative < quantile) {
			low = middle + 1;
		} else {
			high = middle;
		}
	}
	int column = min(low, FIELD_COLUMNS - 1);
	float cdf_end = texelFetch(field_texture, ivec2(column, 0), 0).r;
	float cdf_begin = 0.0;
	if (column > 0) {
		cdf_begin = texelFetch(field_texture, ivec2(column - 1, 0), 0).r;
	}
	float column_mass = max(cdf_end - cdf_begin, 0.000001);
	float column_fraction = clamp((quantile - cdf_begin) / column_mass, 0.0, 1.0);
	float angle = (float(column) + column_fraction) * (TAU / float(FIELD_COLUMNS));
	float lookup_position = area_jitter * float(RADIAL_LOOKUP_SAMPLES);
	int lookup_low = int(floor(lookup_position));
	int lookup_high = min(lookup_low + 1, RADIAL_LOOKUP_SAMPLES);
	float lookup_fraction = fract(lookup_position);
	float radius_squared = mix(
		lookup_value(column, lookup_low, 0),
		lookup_value(column, lookup_high, 0), lookup_fraction);
	float local_packing = mix(
		lookup_value(column, lookup_low, 1),
		lookup_value(column, lookup_high, 1), lookup_fraction);
	float radius = sqrt(max(radius_squared, 0.0));
	vec2 grain_position = vec2(cos(angle), sin(angle)) * radius;
	float density_fraction = clamp((local_packing - compaction_loose_packing) /
		max(compaction_max_packing - compaction_loose_packing, 0.001), 0.0, 1.0);
	local_density_fraction = density_fraction;
	VERTEX = grain_position + VERTEX * display_diameter * (1.0 + density_fraction * 0.75);
}

void fragment() {
	vec2 centered_uv = UV * 2.0 - vec2(1.0);
	float radial_distance = length(centered_uv);
	float antialias_width = max(fwidth(radial_distance), 0.001);
	float coverage = 1.0 - smoothstep(1.0 - antialias_width, 1.0 + antialias_width, radial_distance);
	float depth_tint = 1.0 - local_density_fraction * compaction_depth_darkening;
	// Packed grains merge into the matching continuous bulk underneath.
	float individual_visibility = 1.0 - smoothstep(0.30, 0.72, local_density_fraction);
	COLOR = vec4(grain_tint.rgb * depth_tint, grain_tint.a * coverage * individual_visibility);
}
