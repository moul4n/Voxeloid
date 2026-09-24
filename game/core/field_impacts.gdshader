shader_type canvas_item;
render_mode unshaded;

const int FIELD_COLUMNS = 720;

uniform sampler2D field_texture : filter_nearest, repeat_disable;
uniform sampler2D impact_texture : filter_nearest, repeat_disable;
uniform float simulation_time = 0.0;
uniform float grain_diameter = 2.0;
uniform float distance_mode = 0.0;
uniform vec4 grain_tint : source_color = vec4(0.50, 0.82, 1.0, 1.0);
uniform float molten_surface_blend = 0.0;
uniform float molten_reservoir_radius = 42.0;

varying vec2 event_point;
varying float event_alpha;
varying float event_strength;
varying float event_seed;
varying float event_molten;

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
	vec4 event_a = texelFetch(impact_texture, ivec2(INSTANCE_ID, 0), 0);
	vec4 event_b = texelFetch(impact_texture, ivec2(INSTANCE_ID, 1), 0);
	float duration = max(event_a.z, 0.001);
	float age = clamp((simulation_time - event_a.y) / duration, 0.0, 1.0);
	float active = step(0.0001, event_a.z) * step(0.0, simulation_time - event_a.y) * (1.0 - step(1.0, age));
	float attack = smoothstep(0.0, 0.08, age);
	float decay = 1.0 - smoothstep(0.16, 1.0, age);
	event_alpha = active * attack * decay;
	event_strength = event_a.w;
	event_seed = event_b.y;
	event_molten = max(event_b.z, molten_surface_blend);
	float radius = mix(surface_at(event_a.x), molten_reservoir_radius, event_molten);
	float width = max(event_b.x, grain_diameter * 8.0) * mix(0.82, 1.25, distance_mode);
	float height = max(grain_diameter * 7.0, width * 0.26);
	vec2 radial = vec2(cos(event_a.x), sin(event_a.x));
	vec2 tangent = vec2(-radial.y, radial.x);
	event_point = VERTEX * 2.0;
	VERTEX = radial * (radius + height * 0.15) + tangent * VERTEX.x * width + radial * VERTEX.y * height;
}

void fragment() {
	float age = 1.0 - event_alpha;
	float flare = exp(-dot(event_point * vec2(1.8, 1.1), event_point * vec2(1.8, 1.1)) * 3.4);
	float arc_position = mix(0.10, 0.86, age);
	float arc_distance = abs(abs(event_point.x) - arc_position);
	float arc = (1.0 - smoothstep(0.025, 0.12, arc_distance)) * (1.0 - smoothstep(0.10, 0.92, abs(event_point.x)));
	arc *= 1.0 - smoothstep(0.12, 0.62, abs(event_point.y + 0.12 - 0.20 * cos(event_point.x * 3.14159)));
	float ray = (1.0 - smoothstep(0.0, 0.14, abs(event_point.x))) * (1.0 - smoothstep(0.08, 0.90, abs(event_point.y)));
	float shape = max(flare, max(arc * 0.70, ray * 0.28));
	float splash_radius = length(vec2(event_point.x * 0.82, (event_point.y + 0.16) * 1.75));
	float splash_crown = 1.0 - smoothstep(0.045, 0.16, abs(splash_radius - mix(0.18, 0.88, age)));
	splash_crown *= 1.0 - smoothstep(-0.02, 0.68, event_point.y);
	float inward_streak = (1.0 - smoothstep(0.04, 0.20, abs(event_point.x))) *
		(1.0 - smoothstep(-0.88, 0.20, event_point.y));
	float molten_shape = max(flare * 0.72, max(splash_crown * 0.92, inward_streak * (1.0 - age) * 0.62));
	shape = mix(shape, molten_shape, event_molten);
	float flicker = 0.92 + 0.08 * sin(event_seed * 9.7 + simulation_time * 31.0);
	vec3 hot = mix(grain_tint.rgb, vec3(1.0, 0.84, 0.52), 0.52 + event_strength * 0.24);
	hot = mix(hot, mix(vec3(1.0, 0.22, 0.025), vec3(1.0, 0.78, 0.20), shape), event_molten);
	COLOR = vec4(hot * (1.0 + shape * 0.45) * flicker, shape * event_alpha * (0.46 + event_strength * 0.42));
}
