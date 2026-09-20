shader_type canvas_item;
render_mode unshaded;
uniform sampler2D field_texture : filter_nearest, repeat_disable;
uniform float outer_radius = 1000.0;
uniform float compacted_radius = 42.0;
uniform float player_radius = 42.0;
uniform float loose_packing = 0.72;
uniform float max_packing = 0.94;
uniform float darkening = 0.2;
uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D body_texture : filter_nearest, repeat_disable;
uniform int body_layer_count = 0;
uniform float animation_inner_radius = 0.0;
uniform float animation_outer_radius = 0.0;
uniform bool sun_enabled = false;
uniform float stellar_heat = 0.0;
uniform bool stellar_ignited = false;
uniform float stellar_spin = 0.0;
uniform float simulation_time = 0.0;
uniform float conversion_progress = 0.0;
uniform bool conversion_active = false;
varying vec2 local_point;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	// Quad UVs run opposite canvas Y; use geometry for angular field lookup.
	local_point = VERTEX * (2.0 * outer_radius);
}

// Bounded procedural granules: luminous cells separated by cooler lanes.
// Sites drift locally; the star itself does not spin until a talent enables it.
vec2 granule_distances(vec2 p) {
	vec2 base = floor(p);
	vec2 nearest = vec2(9.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 cell = base + vec2(float(x), float(y));
			vec2 seed = vec2(hash21(cell), hash21(cell + vec2(19.7, 7.1)));
			vec2 site = cell + vec2(0.5) + (seed - 0.5) * 0.62;
			site += sin(seed * TAU + simulation_time * 0.16) * 0.075;
			float distance_to_site = length(p - site);
			if (distance_to_site < nearest.x) {
				nearest.y = nearest.x;
				nearest.x = distance_to_site;
			} else {
				nearest.y = min(nearest.y, distance_to_site);
			}
		}
	}
	return nearest;
}

void fragment() {
	vec2 point = local_point;
	float radius = length(point);
	float alpha = 0.0;
	float density = 1.0;
	float local_pulse = 0.0;
	float body_shade = 1.0;
	float body_layer_index = 0.0;
	float body_layer_inner = player_radius;
	float body_layer_outer = compacted_radius;
	if (radius >= player_radius && radius <= compacted_radius) {
		alpha = 1.0;
		for (int i = 0; i < 4; i++) {
			if (i >= body_layer_count) { break; }
			vec4 layer = texelFetch(body_texture, ivec2(i, 0), 0);
			if (radius >= layer.r && radius <= layer.g) {
				body_shade = layer.b;
				body_layer_index = float(i);
				body_layer_inner = layer.r;
				body_layer_outer = layer.g;
				if (radius >= animation_inner_radius && radius <= animation_outer_radius) { local_pulse = layer.a; }
				break;
			}
		}
	} else if (radius > compacted_radius) {
		// Near three o'clock, float rounding can turn a tiny negative angle
		// into exactly TAU. Wrap the integer too; texel 720 is outside the field.
		int column = int(floor(mod(atan(point.y, point.x), TAU) * (720.0 / TAU))) % 720;
		float rsq = radius * radius;
		float inner = texelFetch(field_texture, ivec2(column, 1), 0).r;
		float outer = texelFetch(field_texture, ivec2(column, 17), 0).r;
		// Fill to the physical core boundary, including the grain-centre offset.
		if (rsq <= outer) {
			int low = 0;
			int high = 16;
			for (int i = 0; i < 5; i++) {
				int mid = (low + high) / 2;
				if (texelFetch(field_texture, ivec2(column, mid + 1), 0).r < rsq) { low = mid + 1; }
				else { high = mid; }
			}
			int upper = clamp(low, 1, 16);
			vec2 a = texelFetch(field_texture, ivec2(column, upper), 0).rg;
			vec2 b = texelFetch(field_texture, ivec2(column, upper + 1), 0).rg;
			float packing = mix(a.y, b.y, clamp((rsq - a.x) / max(b.x - a.x, 0.00001), 0.0, 1.0));
			density = clamp((packing - loose_packing) / max(max_packing - loose_packing, 0.001), 0.0, 1.0);
			alpha = smoothstep(0.12, 0.48, density);
		}
	}
	float shimmer = 1.0 + local_pulse * 0.07 * (0.65 + 0.35 * sin(radius * 0.035));
	vec3 color = tint.rgb * (1.0 - density * darkening) * body_shade * shimmer;
	if (sun_enabled && radius > compacted_radius) {
		float loose_depth = 1.0 - clamp((radius - compacted_radius) / max(outer_radius - compacted_radius, 1.0), 0.0, 1.0);
		color *= 1.0 - loose_depth * 0.16;
	}
	if (sun_enabled && radius >= player_radius && radius <= compacted_radius && body_layer_count > 0) {
		float heat = clamp(stellar_heat, 0.0, 1.0);
		float converting = step(animation_inner_radius, radius) * step(radius, animation_outer_radius) * (conversion_active ? 1.0 : 0.0);
		float shell_depth = clamp((radius - body_layer_inner) / max(body_layer_outer - body_layer_inner, 0.001), 0.0, 1.0);
		float depth = clamp(1.0 - (radius - player_radius) / max(compacted_radius - player_radius, 0.001), 0.0, 1.0);
		vec2 plasma_point = point;
		if (abs(stellar_spin) > 0.0001) {
			float angle = stellar_spin * simulation_time;
			mat2 turn = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
			plasma_point = turn * plasma_point;
		}
		vec2 domain = plasma_point * 0.075 + vec2(body_layer_index * 11.7, body_layer_index * 7.3);
		domain = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80)) * domain;
		// Internal convection evolves slowly; it does not rotate the body.
		domain += vec2(sin(simulation_time * 0.13), cos(simulation_time * 0.11)) * 0.16;
		float broad = value_noise(domain * 0.42 + vec2(13.7, 4.2));
		float cells = value_noise(domain + vec2(2.1 + broad * 1.7, 17.3 - broad * 1.3));
		float fine = value_noise(domain * 2.3 + vec2(29.4, 8.6));
		float channels = 1.0 - smoothstep(0.025, 0.16, abs(cells - 0.5));
		float texture_value = (cells - 0.5) * 0.32;
		float hot_filament = 0.0;
		if (body_layer_index < 0.5) {
			float folds = sin(domain.x * 2.7 + cells * 6.0 + sin(domain.y * 1.9 + broad * 4.0));
			hot_filament = pow(1.0 - abs(folds), 5.0) * 0.10;
			texture_value = (fine - 0.5) * 0.20 + folds * 0.045;
		} else if (body_layer_index < 1.5) {
			float ribbons = sin(radius * 0.33 + broad * 5.0 + cells * 2.0);
			hot_filament = pow(0.5 + 0.5 * ribbons, 8.0) * 0.065;
			texture_value = ribbons * 0.075 + (fine - 0.5) * 0.12;
		} else if (body_layer_index < 2.5) {
			vec2 granules = granule_distances(domain * 0.80 + vec2(broad, cells) * 0.55);
			float lane = 1.0 - smoothstep(0.025, 0.13, granules.y - granules.x);
			float cell_centre = 1.0 - smoothstep(0.06, 0.65, granules.x);
			texture_value = cell_centre * 0.17 - lane * 0.11 + (fine - 0.5) * 0.10;
			hot_filament = cell_centre * 0.035;
		} else {
			vec2 granules = granule_distances(domain * 1.8);
			texture_value = (0.35 - granules.x) * 0.26 + (fine - 0.5) * 0.13;
		}
		vec3 cool_color = vec3(0.64, 0.29, 0.065);
		float ignition_progress = stellar_ignited ? smoothstep(0.80, 1.0, heat) : 0.0;
		vec3 preignition_color = mix(cool_color * (0.74 + body_layer_index * 0.07), vec3(0.92, 0.46, 0.12), smoothstep(0.50, 0.84, heat));
		vec3 startup_color = vec3(0.90, 0.22, 0.045);
		vec3 mature_color = startup_color;
		if (body_layer_index < 0.5) {
			startup_color = vec3(0.96, 0.42, 0.18);
			mature_color = vec3(1.0, 0.82, 0.40);
		} else if (body_layer_index < 1.5) {
			startup_color = vec3(0.91, 0.25, 0.055);
			mature_color = vec3(0.96, 0.64, 0.25);
		} else if (body_layer_index < 2.5) {
			startup_color = vec3(0.95, 0.19, 0.025);
			mature_color = vec3(1.0, 0.77, 0.38);
		} else {
			startup_color = vec3(0.94, 0.29, 0.075);
			mature_color = vec3(1.0, 0.86, 0.48);
		}
		vec3 solar_color = mix(preignition_color, mix(startup_color, mature_color, ignition_progress), stellar_ignited ? 1.0 : 0.0);
		if (stellar_ignited && body_layer_index >= float(body_layer_count - 1)) {
			float layer_position = (radius - body_layer_inner) / max(body_layer_outer - body_layer_inner, 0.001);
			float photosphere = smoothstep(0.94, 0.995, layer_position);
			vec3 rim_color = mix(vec3(0.98, 0.40, 0.04), vec3(1.0, 0.68, 0.20), ignition_progress);
			solar_color = mix(solar_color, rim_color, photosphere * 0.78);
		}
		solar_color = mix(solar_color, vec3(1.0, 0.73, 0.24), smoothstep(0.72, 1.0, depth) * ignition_progress * 0.35);
		float texture_strength = 0.45 + heat * 0.20;
		float gentle_shimmer = 0.98 + 0.02 * sin(simulation_time * 1.8 + broad * 6.283);
		float boundary = smoothstep(0.0, 0.04, shell_depth) * (1.0 - smoothstep(0.97, 1.0, shell_depth));
		solar_color *= 0.92 + 0.08 * boundary;
		// Soft relief on the cutaway; the geometry remains the mass-conserving field.
		vec2 body_xy = point / max(compacted_radius, 1.0);
		vec3 normal = normalize(vec3(body_xy, sqrt(max(1.0 - dot(body_xy, body_xy), 0.03))));
		vec3 light_direction = normalize(vec3(-0.48, -0.58, 0.85));
		float light = 0.72 + 0.28 * max(dot(normal, light_direction), 0.0);
		float bevel_width = max(fwidth(radius) * 1.5, min((body_layer_outer - body_layer_inner) * 0.12, 5.0));
		float inner_shadow = 1.0 - smoothstep(0.0, bevel_width, radius - body_layer_inner);
		float outer_edge = 1.0 - smoothstep(0.0, bevel_width, body_layer_outer - radius);
		vec3 relief_normal = normalize(vec3(-dFdx(texture_value) * 3.0, -dFdy(texture_value) * 3.0, 1.0));
		float relief = 0.91 + 0.09 * max(dot(relief_normal, light_direction), 0.0);
		solar_color *= light * relief * (1.0 - inner_shadow * 0.22);
		solar_color += vec3(0.11, 0.045, 0.005) * outer_edge;
		color = mix(color, solar_color * (1.0 + texture_value * texture_strength) * gentle_shimmer, 0.94);
		color += vec3(1.0, 0.45, 0.08) * hot_filament * (0.4 + heat * 0.6);
		// Only the converting annulus breaks into bright inward-flowing threads.
		float conversion_depth = (radius - animation_inner_radius) / max(animation_outer_radius - animation_inner_radius, 0.001);
		float front = exp(-pow((conversion_depth - (1.0 - conversion_progress)) * 14.0, 2.0));
		float threads = pow(0.5 + 0.5 * sin(atan(point.y, point.x) * 48.0 + broad * 3.0), 6.0);
		color += vec3(1.0, 0.45, 0.08) * converting * sin(clamp(conversion_progress, 0.0, 1.0) * PI) * (front * 0.16 + threads * 0.07);
		// Preserve the glow's hue instead of clipping each channel toward white.
		color /= max(1.0, max(color.r, max(color.g, color.b)));
	}
	COLOR = vec4(color, tint.a * alpha);
}
