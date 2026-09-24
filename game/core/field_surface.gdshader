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
uniform bool stable_sample_mode = false;
uniform float sampling_blend = 0.0;
uniform float dense_surface_blend = 0.0;
uniform float molten_surface_blend = 0.0;
uniform bool pressure_grain_mode = true;

varying float local_density_fraction;
varying float pressure_weld_fraction;
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
	float area_jitter = stable_sample_mode ? INSTANCE_CUSTOM.b : random01(uint(particle_id) * 2u + 91u);
	int column = 0;
	float column_fraction = 0.5;
	float dense_quantile = random01(uint(particle_id / 2) * 3u + 173u);
	if (stable_sample_mode) {
		column = clamp(int(floor(INSTANCE_CUSTOM.r * float(FIELD_COLUMNS))), 0, FIELD_COLUMNS - 1);
		column_fraction = clamp(INSTANCE_CUSTOM.g, 0.0, 0.999999);
	}
	if (!stable_sample_mode || sampling_blend > 0.0) {
		int low = 0;
		int high = FIELD_COLUMNS - 1;
		for (int search = 0; search < SEARCH_STEPS; search++) {
			int middle = (low + high) / 2;
			float cumulative = texelFetch(field_texture, ivec2(middle, 0), 0).r;
			if (cumulative < dense_quantile) { low = middle + 1; }
			else { high = middle; }
		}
		int dense_column = min(low, FIELD_COLUMNS - 1);
		float cdf_end = texelFetch(field_texture, ivec2(dense_column, 0), 0).r;
		float cdf_begin = dense_column > 0 ? texelFetch(field_texture, ivec2(dense_column - 1, 0), 0).r : 0.0;
		float column_mass = max(cdf_end - cdf_begin, 0.000001);
		float dense_fraction = clamp((dense_quantile - cdf_begin) / column_mass, 0.0, 1.0);
		if (stable_sample_mode) {
			float stable_angle = (float(column) + column_fraction) * (TAU / float(FIELD_COLUMNS));
			float dense_angle = (float(dense_column) + dense_fraction) * (TAU / float(FIELD_COLUMNS));
			float angle_delta = mod(dense_angle - stable_angle + PI, TAU) - PI;
			float blended_angle = stable_angle + angle_delta * sampling_blend;
			float blended_coordinate = mod(blended_angle, TAU) * (float(FIELD_COLUMNS) / TAU);
			column = int(floor(blended_coordinate)) % FIELD_COLUMNS;
			column_fraction = fract(blended_coordinate);
		} else {
			column = dense_column;
			column_fraction = dense_fraction;
		}
	}
	float angle = (float(column) + column_fraction) * (TAU / float(FIELD_COLUMNS));
	float edge_bias = dense_surface_blend * (pressure_grain_mode ? 0.0 : 1.0);
	float edge_fraction = mix(area_jitter, mix(0.68, 1.0, area_jitter), edge_bias);
	float lookup_position = edge_fraction * float(RADIAL_LOOKUP_SAMPLES);
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
	// Visual contact begins before maximum physical packing. This makes the
	// grain-to-grain squeeze readable through the range that previously switched
	// to a featureless fill, while still using the authoritative packing value.
	float pressure_deformation = smoothstep(0.015, 0.55, density_fraction);
	float pressure_weld = smoothstep(0.62, 0.96, pressure_deformation);
	pressure_weld_fraction = pressure_weld;
	float size_hash = random01(identity ^ 0xa511e9b3u);
	float size_scale = mix(0.75, 1.30, smoothstep(0.08, 0.92, size_hash));
	// Deeply compressed grains converge in size as their gaps disappear. Loose
	// grains retain the full original variation.
	size_scale = mix(size_scale, 1.08, pressure_deformation * 0.75);
	size_scale = mix(size_scale, 1.04, pressure_weld * 0.85);
	visual_brightness = mix(0.95, 1.08, random01(identity ^ 0x63d83595u));
	visual_warmth = mix(-0.035, 0.045, random01(identity ^ 0x9e3779b9u));
	float glow_class = random01(identity ^ 0x85ebca6bu);
	visual_glow = glow_class > 0.995 ? 1.0 : (glow_class > 0.96 ? 0.56 : (glow_class > 0.80 ? 0.20 : 0.0));
	float halo_scale = 1.0 + visual_glow * mix(0.10, 0.20, distance_mode);
	visual_core_radius = 1.0 / halo_scale;
	// Pressure first closes gaps, then flattens grains along the local surface.
	// At zero pressure this is exactly the original round particle. Because the
	// scale is derived from local packing, consumption reverses it smoothly.
	// The final pressure range visually welds contacts into an almost continuous
	// mass. It is still the same reversible grain population, not a solid phase.
	float merge_scale = 1.0 + pressure_deformation * 1.80 + pressure_weld * 1.50;
	float tangent_shape = 1.0 + pressure_deformation * 0.24 * (1.0 - pressure_weld * 0.55);
	float radial_shape = 1.0 - pressure_deformation * 0.10 * (1.0 - pressure_weld * 0.50);
	float tangent_scale = merge_scale * tangent_shape;
	float radial_scale = merge_scale * radial_shape;
	vec2 radial_axis = vec2(cos(angle), sin(angle));
	vec2 tangent_axis = vec2(-radial_axis.y, radial_axis.x);
	vec2 shaped_vertex = tangent_axis * VERTEX.x * tangent_scale + radial_axis * VERTEX.y * radial_scale;
	VERTEX = grain_position + shaped_vertex * display_diameter * size_scale * halo_scale;
}

void fragment() {
	vec2 centered_uv = UV * 2.0 - vec2(1.0);
	float radial_distance = length(centered_uv);
	float antialias_width = max(fwidth(radial_distance), 0.001);
	float coverage = 1.0 - smoothstep(visual_core_radius - antialias_width, visual_core_radius + antialias_width, radial_distance);
	float halo = (1.0 - smoothstep(visual_core_radius, 1.0, radial_distance)) * visual_glow;
	float depth_tint = 1.0 - local_density_fraction * compaction_depth_darkening;
	// Packed grains merge into the matching continuous bulk underneath.
	float merged_visibility = 1.0 - smoothstep(0.30, 0.72, local_density_fraction);
	float individual_visibility = pressure_grain_mode ? 1.0 : merged_visibility;
	vec3 varied_tint = grain_tint.rgb * visual_brightness;
	varied_tint = mix(varied_tint, vec3(1.0, 0.73, 0.38), max(visual_warmth, 0.0));
	varied_tint = mix(varied_tint, vec3(0.62, 0.80, 1.0), max(-visual_warmth, 0.0));
	varied_tint = mix(varied_tint, grain_tint.rgb, pressure_weld_fraction * 0.68);
	float edge_visibility = mix(1.0, 0.78, dense_surface_blend * (pressure_grain_mode ? 0.0 : 1.0));
	float alpha = max(coverage, halo * 0.26) * individual_visibility * edge_visibility;
	alpha *= 1.0 - smoothstep(0.0, 0.995, molten_surface_blend);
	COLOR = vec4(varied_tint * depth_tint + halo * varied_tint * 0.18, grain_tint.a * alpha);
}
