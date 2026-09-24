shader_type canvas_item;
render_mode unshaded;

const int FIELD_COLUMNS = 720;

uniform sampler2D field_texture : filter_nearest, repeat_disable;
uniform sampler2D patch_texture : filter_nearest, repeat_disable;
uniform float simulation_time = 0.0;
uniform float grain_diameter = 2.0;
uniform float distance_mode = 0.0;
uniform vec4 grain_tint : source_color = vec4(0.50, 0.82, 1.0, 1.0);
uniform float molten_surface_blend = 0.0;
uniform float molten_reservoir_radius = 42.0;

varying vec2 patch_point;
varying float patch_alpha;
varying float patch_freshness;
varying float patch_seed;
varying float patch_molten;
varying float patch_age;

float surface_at(float angle) {
	float coordinate = mod(angle, TAU) * (float(FIELD_COLUMNS) / TAU);
	int lower = int(floor(coordinate)) % FIELD_COLUMNS;
	int upper = (lower + 1) % FIELD_COLUMNS;
	return mix(
		texelFetch(field_texture, ivec2(lower, 0), 0).g,
		texelFetch(field_texture, ivec2(upper, 0), 0).g,
		fract(coordinate));
}

void vertex() {
	vec4 patch_a = texelFetch(patch_texture, ivec2(INSTANCE_ID, 0), 0);
	vec4 patch_b = texelFetch(patch_texture, ivec2(INSTANCE_ID, 1), 0);
	float duration = max(patch_a.z, 0.001);
	float age = clamp((simulation_time - patch_a.y) / duration, 0.0, 1.0);
	float active = step(0.0001, patch_a.z) * step(0.0, simulation_time - patch_a.y) * (1.0 - step(1.0, age));
	float attach = smoothstep(0.0, 0.10, age);
	float assimilate = 1.0 - smoothstep(0.42, 1.0, age);
	patch_alpha = active * attach * (1.0 - smoothstep(0.78, 1.0, age));
	patch_freshness = assimilate;
	patch_seed = patch_b.z;
	patch_molten = max(patch_b.w, molten_surface_blend);
	patch_age = age;
	float strength = patch_a.w;
	float width = patch_b.x * mix(0.72, 1.0, attach) * mix(1.0, 1.16, age);
	float granular_height = patch_b.y * attach * mix(1.0, 0.0, smoothstep(0.32, 1.0, age));
	float splash_height = patch_b.y * pow(max(sin(age * 3.14159265), 0.0), 0.58) * (1.0 + strength * 0.45);
	float height = mix(granular_height, splash_height, patch_molten);
	height = max(height, grain_diameter * 0.05) * mix(1.0, 1.10, distance_mode);
	float centre_radius = mix(surface_at(patch_a.x), molten_reservoir_radius, patch_molten);
	// Bend every vertex around the live body rather than placing the patch on a
	// flat tangent. The lower edge now follows the material under its full width.
	float local_angle = patch_a.x + VERTEX.x * width / max(centre_radius, grain_diameter);
	float local_radius = mix(surface_at(local_angle), molten_reservoir_radius, patch_molten);
	vec2 radial = vec2(cos(local_angle), sin(local_angle));
	patch_point = VERTEX * 2.0;
	VERTEX = radial * (local_radius + (VERTEX.y + 0.5) * height);
}

void fragment() {
	float x = patch_point.x;
	float y = patch_point.y * 0.5 + 0.5;
	float broad = pow(max(1.0 - abs(x), 0.0), 0.72);
	float lobes = 0.82 + 0.12 * sin(x * 8.0 + patch_seed * 5.7) + 0.06 * sin(x * 19.0 - patch_seed * 3.1);
	float mound = clamp(broad * lobes, 0.0, 1.0);
	float edge_width = max(fwidth(y), 0.012);
	float side_fade = 1.0 - smoothstep(0.78, 1.0, abs(x));
	float fill = smoothstep(-edge_width, edge_width * 2.0, y) *
		(1.0 - smoothstep(mound - edge_width * 4.0, mound + edge_width * 2.0, y)) * side_fade;
	float liquid_top = 0.17 + 0.12 * sin(x * 8.0 + patch_seed * 4.7 + simulation_time * 5.0) * (1.0 - abs(x));
	float liquid_sheet = smoothstep(0.0, 0.08, y) * (1.0 - smoothstep(liquid_top, liquid_top + 0.10, y)) * side_fade;
	float crown_radius = length(vec2(x * 0.82, (y - 0.20) * 1.55));
	float crown = 1.0 - smoothstep(0.045, 0.15, abs(crown_radius - mix(0.22, 0.82, smoothstep(0.0, 0.58, patch_age))));
	crown *= side_fade * (1.0 - smoothstep(0.48, 1.0, patch_age));
	float sink = (1.0 - smoothstep(0.06, 0.24, abs(x))) * (1.0 - smoothstep(0.05, 0.78, y));
	float molten_fill = max(liquid_sheet, max(crown, sink * (1.0 - patch_age) * 0.52));
	fill = mix(fill, molten_fill, patch_molten);
	float bonding_line = (1.0 - smoothstep(0.0, 0.045, abs(y))) * (1.0 - smoothstep(0.60, 0.92, abs(x)));
	float grain_breakup = 0.98 + 0.02 * sin(x * 31.0 + patch_seed * 11.0) * sin(y * 17.0 - patch_seed * 7.0);
	vec3 fresh = mix(grain_tint.rgb, vec3(1.0, 0.71, 0.34), 0.08);
	vec3 color = mix(grain_tint.rgb, fresh, patch_freshness) * grain_breakup;
	vec3 liquid_color = mix(vec3(0.91, 0.18, 0.025), vec3(1.0, 0.72, 0.18), 0.5 + 0.5 * sin(x * 5.0 - simulation_time * 2.1 + patch_seed));
	color = mix(color, liquid_color, patch_molten);
	color *= 1.0 - bonding_line * patch_freshness * 0.035;
	COLOR = vec4(color, fill * patch_alpha * mix(0.82, 0.96, patch_freshness));
}
