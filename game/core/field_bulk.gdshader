shader_type canvas_item;
render_mode unshaded;
uniform sampler2D field_texture : filter_nearest, repeat_disable;
uniform float outer_radius = 1000.0;
uniform float compacted_radius = 42.0;
uniform float molten_reservoir_radius = 42.0;
uniform float player_radius = 42.0;
uniform float loose_packing = 0.72;
uniform float max_packing = 0.94;
uniform float darkening = 0.2;
uniform float grain_diameter = 2.0;
uniform float loose_fill_blend = 0.0;
uniform bool pressure_grain_mode = true;
uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D body_texture : filter_nearest, repeat_disable;
uniform int body_layer_count = 0;
uniform float animation_inner_radius = 0.0;
uniform float animation_outer_radius = 0.0;
uniform bool sun_enabled = false;
uniform float stellar_heat = 0.0;
uniform float stellar_ignition = 0.0;
uniform float stellar_spin = 0.0;
uniform float view_zoom = 1.0;
uniform float simulation_time = 0.0;
uniform float conversion_progress = 0.0;
uniform bool conversion_active = false;
uniform int core_motion_variant = 0;
uniform float core_motion_speed = 1.0;
varying vec2 local_point;

vec2 angular_field_position(vec2 point) {
	float coordinate = mod(atan(point.y, point.x), TAU) * (720.0 / TAU);
	return vec2(floor(coordinate), fract(coordinate));
}

vec4 smooth_field_value(vec2 angular_position, int row) {
	int lower = int(angular_position.x) % 720;
	int upper = (lower + 1) % 720;
	return mix(
		texelFetch(field_texture, ivec2(lower, row), 0),
		texelFetch(field_texture, ivec2(upper, row), 0),
		angular_position.y);
}

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
float phased_noise(vec2 p, float time, float seed) {
	float cycle = floor(time * 0.055);
	float phase = fract(time * 0.055);
	phase = phase * phase * (3.0 - 2.0 * phase);
	vec2 offset_a = vec2(hash21(vec2(cycle, seed)), hash21(vec2(seed, cycle + 7.3))) * 19.0;
	vec2 offset_b = vec2(hash21(vec2(cycle + 1.0, seed)), hash21(vec2(seed, cycle + 8.3))) * 19.0;
	return mix(value_noise(p + offset_a), value_noise(p + offset_b), phase);
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
		// Geometry drives angular lookup because QuadMesh UVs reverse canvas Y.
		// Blend the wrapped neighbouring columns without changing the 720-column solver.
		vec2 angular_position = angular_field_position(point);
		float rsq = radius * radius;
		float inner = smooth_field_value(angular_position, 1).r;
		float outer = smooth_field_value(angular_position, 17).r;
		// Fill to the physical core boundary, including the grain-centre offset.
		if (rsq <= outer) {
			int low = 0;
			int high = 16;
			for (int i = 0; i < 5; i++) {
				int mid = (low + high) / 2;
				if (smooth_field_value(angular_position, mid + 1).r < rsq) { low = mid + 1; }
				else { high = mid; }
			}
			int upper = clamp(low, 1, 16);
			vec2 a = smooth_field_value(angular_position, upper).rg;
			vec2 b = smooth_field_value(angular_position, upper + 1).rg;
			float packing = mix(a.y, b.y, clamp((rsq - a.x) / max(b.x - a.x, 0.00001), 0.0, 1.0));
			density = clamp((packing - loose_packing) / max(max_packing - loose_packing, 0.001), 0.0, 1.0);
			float surface_radius = sqrt(max(outer, 0.0));
			float edge_depth = (surface_radius - radius) / max(grain_diameter, 0.001);
			float continuous_fill = loose_fill_blend * smoothstep(-0.15, 1.35, edge_depth);
			// Pressure-grain mode replaces the smooth loose-matter disc with the
			// bounded MultiMesh samples. Committed layers and molten matter below
			// retain their dedicated continuous renderers.
			alpha = max(smoothstep(0.12, 0.48, density), continuous_fill) * (pressure_grain_mode ? 0.0 : 1.0);
		}
		float molten_edge = max(fwidth(radius) * 1.5, grain_diameter * 0.30);
		float molten_alpha = 1.0 - smoothstep(molten_reservoir_radius - molten_edge,
			molten_reservoir_radius + molten_edge, radius);
		alpha = mix(alpha, molten_alpha, smoothstep(0.02, 0.98, stellar_ignition));
	}
	float shimmer = 1.0 + local_pulse * 0.07 * (0.65 + 0.35 * sin(radius * 0.035));
	vec3 color = tint.rgb * (1.0 - density * darkening) * body_shade * shimmer;
	if (sun_enabled && radius > compacted_radius) {
		float loose_depth = 1.0 - clamp((radius - compacted_radius) / max(outer_radius - compacted_radius, 1.0), 0.0, 1.0);
		color *= 1.0 - loose_depth * 0.16;
		float molten = smoothstep(0.02, 0.98, stellar_ignition);
		if (molten > 0.0 && alpha > 0.0) {
			vec2 loose_domain = point * 0.070;
			float liquid_a = phased_noise(loose_domain * 0.52, simulation_time * 0.72, 79.0);
			float liquid_b = phased_noise(loose_domain * 0.81, simulation_time * 0.58, 97.0);
			float polar = atan(point.y, point.x);
			float fold = sin(polar * 11.0 - simulation_time * 0.19 + liquid_a * 5.4 + liquid_b * 2.1);
			float return_fold = sin(polar * -7.0 + simulation_time * 0.12 + liquid_b * 6.2 - liquid_a * 1.8);
			float flowing_line = pow(0.5 + 0.5 * (fold * 0.66 + return_fold * 0.34), 6.0);
			// Fine currents ride over the broad folds. They move through the liquid
			// instead of enlarging and translating the base texture as one sheet.
			vec2 detail_drift = vec2(sin(simulation_time * 0.083), cos(simulation_time * 0.067)) * 0.42;
			float liquid_detail = value_noise(point * 0.205 + detail_drift + vec2(liquid_a, liquid_b) * 0.75);
			float detail_return = value_noise(point * 0.128 - detail_drift * 0.72 + vec2(liquid_b, -liquid_a) * 0.58);
			float fine_current = sin(polar * 29.0 + radius * 0.115 - simulation_time * 0.34 + liquid_detail * 5.2);
			float fine_return = sin(polar * -19.0 + radius * 0.073 + simulation_time * 0.21 + detail_return * 4.1);
			float current_thread = pow(0.5 + 0.5 * (fine_current * 0.68 + fine_return * 0.32), 10.0);
			float eddy_edge = 1.0 - smoothstep(0.025, 0.115, abs(liquid_detail - detail_return));
			vec2 angular_position = angular_field_position(point);
			float field_surface = sqrt(max(smooth_field_value(angular_position, 17).r, 0.0));
			float local_surface = mix(field_surface, molten_reservoir_radius, molten);
			float surface_skin = 1.0 - smoothstep(0.0, max(grain_diameter * 4.5, 1.0), local_surface - radius);
			vec3 liquid_color = mix(vec3(0.82, 0.18, 0.025), vec3(1.0, 0.58, 0.12), 0.48 + 0.24 * fold);
			liquid_color *= 0.86 + (liquid_a - 0.5) * 0.12 + (liquid_b - 0.5) * 0.07 + (liquid_detail - 0.5) * 0.11;
			liquid_color += vec3(1.0, 0.48, 0.07) * flowing_line * (0.13 + stellar_heat * 0.16);
			liquid_color += vec3(1.0, 0.66, 0.16) * current_thread * (0.10 + stellar_heat * 0.13);
			liquid_color += vec3(0.34, 0.055, 0.008) * eddy_edge * 0.10;
			liquid_color += vec3(1.0, 0.69, 0.20) * surface_skin * (0.08 + flowing_line * 0.16);
			color = mix(color, liquid_color, molten * 0.92);
		}
	}
	if (sun_enabled && radius >= player_radius && radius <= compacted_radius && body_layer_count > 0) {
		float motion_time = simulation_time * max(core_motion_speed, 0.0);
		float heat = clamp(stellar_heat, 0.0, 1.0);
		float converting = step(animation_inner_radius, radius) * step(radius, animation_outer_radius) * (conversion_active ? 1.0 : 0.0);
		float shell_depth = clamp((radius - body_layer_inner) / max(body_layer_outer - body_layer_inner, 0.001), 0.0, 1.0);
		float depth = clamp(1.0 - (radius - player_radius) / max(compacted_radius - player_radius, 0.001), 0.0, 1.0);
		vec4 core_band = texelFetch(body_texture, ivec2(0, 0), 0);
		float core_outer = core_band.g;
		float core_width = max(core_band.g - core_band.r, 1.0);
		float core_boundary_width = max(core_width * 0.55, max(compacted_radius - core_outer, 0.0) * 0.035);
		float core_boundary_blend = 1.0 - smoothstep(0.0, core_boundary_width, abs(radius - core_outer));
		vec2 plasma_point = point;
		if (abs(stellar_spin) > 0.0001) {
			float angle = stellar_spin * simulation_time;
			mat2 turn = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle)));
			plasma_point = turn * plasma_point;
		}
		vec2 domain = plasma_point * 0.075 + vec2(body_layer_index * 11.7, body_layer_index * 7.3);
		domain = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80)) * domain;
		// Internal convection evolves slowly; it does not rotate the body.
		domain += vec2(sin(motion_time * 0.13), cos(motion_time * 0.11)) * 0.16;
		float broad = value_noise(domain * 0.42 + vec2(13.7, 4.2));
		float cells = value_noise(domain + vec2(2.1 + broad * 1.7, 17.3 - broad * 1.3));
		float fine = value_noise(domain * 2.3 + vec2(29.4, 8.6));
		float channels = 1.0 - smoothstep(0.025, 0.16, abs(cells - 0.5));
		float texture_value = (cells - 0.5) * 0.32;
		float hot_filament = 0.0;
		float core_plume_heat = 0.0;
		if (body_layer_index < 0.5) {
			// Slow counter-flowing molten bands. Polar motion keeps the centre
			// alive without implying that the whole star has unlocked rotation.
			float core_angle = atan(point.y, point.x);
			if (core_motion_variant == 0) {
				float molten_a = sin(core_angle * 7.0 - motion_time * 0.72 + shell_depth * 12.0 + broad * 4.2);
				float molten_b = sin(core_angle * -4.0 + motion_time * 0.43 + shell_depth * 18.0 + fine * 3.0);
				float folds = molten_a * 0.62 + molten_b * 0.38;
				float lava_crack = pow(1.0 - abs(sin(core_angle * 9.0 + shell_depth * 15.0 - motion_time * 0.58 + cells * 3.4)), 7.0);
				hot_filament = lava_crack * (0.12 + heat * 0.12);
				texture_value = (fine - 0.5) * 0.17 + folds * 0.105;
			} else {
				vec2 core_domain = point * 0.105;
				core_domain += vec2(sin(motion_time * 0.15), cos(motion_time * 0.11)) * 0.42;
				float rising = value_noise(core_domain * 0.58 + vec2(8.4, -motion_time * 0.145));
				float returning = value_noise(core_domain * 0.82 + vec2(-motion_time * 0.082, 17.1));
				float vertical_fold = 0.5 + 0.5 * sin(point.y * 0.11 - motion_time * 0.38 + rising * 5.2);
				float plume = smoothstep(0.30, 0.69, rising + (returning - 0.5) * 0.42 + (vertical_fold - 0.5) * 0.16);
				float return_lane = 1.0 - smoothstep(0.035, 0.17, abs(returning - 0.5));
				texture_value = (plume - 0.5) * 0.30 - return_lane * 0.085 + (vertical_fold - 0.5) * 0.09 + (fine - 0.5) * 0.055;
				hot_filament = pow(plume, 4.0) * (0.075 + heat * 0.085);
				core_plume_heat = plume;
			}
		} else if (body_layer_index < 1.5) {
			float broad_flow = phased_noise(domain * 0.48, motion_time, 11.0);
			float return_flow = phased_noise(domain * 0.72, motion_time, 23.0);
			float ribbons = sin(radius * 0.24 + broad_flow * 5.2 - return_flow * 2.4 + motion_time * 0.11);
			hot_filament = pow(0.5 + 0.5 * ribbons, 8.0) * 0.072;
			texture_value = ribbons * 0.082 + (broad_flow - 0.5) * 0.16 + (fine - 0.5) * 0.07;
		} else if (body_layer_index < 2.5) {
			float upflow = phased_noise(domain * 0.48, motion_time, 37.0);
			float downflow = phased_noise(domain * 0.73, motion_time, 43.0);
			float flow_field = upflow * 0.68 + downflow * 0.32;
			float flow_contour = 1.0 - smoothstep(0.018, 0.075, abs(fract(flow_field * 4.2 + motion_time * 0.012) - 0.5));
			float rising_cell = smoothstep(0.52, 0.78, upflow);
			float sinking_lane = 1.0 - smoothstep(0.035, 0.15, abs(downflow - 0.5));
			texture_value = (upflow - 0.5) * 0.20 + flow_contour * 0.085 - sinking_lane * 0.045;
			hot_filament = flow_contour * rising_cell * 0.050;
		} else {
			float surface_upflow = phased_noise(domain * 1.15, motion_time, 53.0);
			float surface_return = phased_noise(domain * 1.55, motion_time, 67.0);
			float living_lane = 1.0 - smoothstep(0.022, 0.085, abs(surface_upflow - surface_return));
			float granule_centre = smoothstep(0.46, 0.78, surface_upflow);
			texture_value = (surface_upflow - 0.5) * 0.14 + living_lane * 0.075 - (surface_return - 0.5) * 0.045;
			hot_filament = living_lane * granule_centre * smoothstep(0.58, 0.88, surface_upflow) * 0.042;
		}
		vec3 cool_color = vec3(0.64, 0.29, 0.065);
		float ignition_progress = smoothstep(0.0, 1.0, stellar_ignition) * smoothstep(0.80, 1.0, heat);
		vec3 preignition_color = mix(cool_color * (0.74 + body_layer_index * 0.07), vec3(0.92, 0.46, 0.12), smoothstep(0.50, 0.84, heat));
		vec3 startup_color = vec3(0.90, 0.22, 0.045);
		vec3 mature_color = startup_color;
		if (body_layer_index < 0.5) {
			startup_color = vec3(0.97, 0.34, 0.075);
			mature_color = vec3(1.0, 0.70, 0.24);
		} else if (body_layer_index < 1.5) {
			startup_color = vec3(0.92, 0.23, 0.035);
			mature_color = vec3(0.98, 0.55, 0.15);
		} else if (body_layer_index < 2.5) {
			startup_color = vec3(0.94, 0.18, 0.020);
			mature_color = vec3(1.0, 0.64, 0.21);
		} else {
			startup_color = vec3(0.91, 0.20, 0.025);
			mature_color = vec3(1.0, 0.57, 0.14);
		}
		vec3 solar_color = mix(preignition_color, mix(startup_color, mature_color, ignition_progress), stellar_ignition);
		float body_fraction = clamp((radius - player_radius) / max(compacted_radius - player_radius, 0.001), 0.0, 1.0);
		vec3 continuous_palette = mix(vec3(1.0, 0.68, 0.22), vec3(0.89, 0.19, 0.025), smoothstep(0.05, 0.88, body_fraction));
		continuous_palette = mix(continuous_palette, vec3(1.0, 0.58, 0.14), smoothstep(0.74, 1.0, body_fraction) * 0.55);
		solar_color = mix(solar_color, continuous_palette, stellar_ignition * 0.32);
		if (body_layer_index < 0.5 && core_motion_variant == 1) {
			vec3 plume_fire = mix(vec3(0.94, 0.22, 0.035), vec3(1.0, 0.73, 0.22), core_plume_heat);
			solar_color = mix(solar_color, plume_fire, 0.18 + core_plume_heat * 0.24);
		}
		if (stellar_ignition > 0.001 && body_layer_index >= float(body_layer_count - 1)) {
			float layer_position = (radius - body_layer_inner) / max(body_layer_outer - body_layer_inner, 0.001);
			float photosphere = smoothstep(0.94, 0.995, layer_position);
			vec3 rim_color = mix(vec3(0.98, 0.40, 0.04), vec3(1.0, 0.68, 0.20), ignition_progress);
			solar_color = mix(solar_color, rim_color, photosphere * 0.78 * stellar_ignition);
		}
		solar_color = mix(solar_color, vec3(1.0, 0.73, 0.24), smoothstep(0.72, 1.0, depth) * ignition_progress * 0.35);
		float texture_strength = 0.45 + heat * 0.20;
		float gentle_shimmer = 0.98 + 0.02 * sin(motion_time * 1.8 + broad * 6.283);
		float boundary = smoothstep(0.0, 0.04, shell_depth) * (1.0 - smoothstep(0.97, 1.0, shell_depth));
		boundary = max(boundary, core_boundary_blend * 0.92);
		solar_color *= 0.92 + 0.08 * boundary;
		// Soft relief on the cutaway; the geometry remains the mass-conserving field.
		vec2 body_xy = point / max(compacted_radius, 1.0);
		vec3 normal = normalize(vec3(body_xy, sqrt(max(1.0 - dot(body_xy, body_xy), 0.03))));
		vec3 light_direction = normalize(vec3(-0.48, -0.58, 0.85));
		float light = 0.72 + 0.28 * max(dot(normal, light_direction), 0.0);
		float bevel_width = max(fwidth(radius) * 1.5, min((body_layer_outer - body_layer_inner) * 0.12, 5.0));
		float inner_shadow = 1.0 - smoothstep(0.0, bevel_width, radius - body_layer_inner);
		float outer_edge = 1.0 - smoothstep(0.0, bevel_width, body_layer_outer - radius);
		float layer_width = max(body_layer_outer - body_layer_inner, 1.0);
		float internal_width = layer_width * 0.24;
		float layer_polar = atan(point.y, point.x);
		// Advect the boundary pattern around the star very slowly. Alternating
		// layers counter-rotate, creating local shear without spinning the body.
		float circulation_direction = mod(floor(body_layer_index), 2.0) < 0.5 ? 1.0 : -1.0;
		float circulating_polar = layer_polar - motion_time * 0.026 * circulation_direction;
		float counter_polar = layer_polar + motion_time * 0.016 * circulation_direction;
		float boundary_wave = (sin(circulating_polar * 9.0 + broad * 1.7) +
			sin(counter_polar * 15.0 + broad * 3.2) * 0.45) * internal_width * 0.10;
		float inner_internal = body_layer_index > 0.5 ? 1.0 - smoothstep(0.0, internal_width, radius - body_layer_inner + boundary_wave) : 0.0;
		float outer_internal = body_layer_index < float(body_layer_count - 1) ? 1.0 - smoothstep(0.0, internal_width, body_layer_outer - radius - boundary_wave) : 0.0;
		float internal_boundary_blend = max(inner_internal, outer_internal);
		inner_shadow *= 1.0 - core_boundary_blend;
		outer_edge *= 1.0 - core_boundary_blend;
		inner_shadow *= 1.0 - inner_internal;
		outer_edge *= 1.0 - outer_internal;
		vec3 relief_normal = normalize(vec3(-dFdx(texture_value) * 3.0, -dFdy(texture_value) * 3.0, 1.0));
		float relief = 0.91 + 0.09 * max(dot(relief_normal, light_direction), 0.0);
		solar_color *= light * relief * (1.0 - inner_shadow * 0.22);
		solar_color += vec3(0.11, 0.045, 0.005) * outer_edge;
		color = mix(color, solar_color * (1.0 + texture_value * texture_strength) * gentle_shimmer, 0.94);
		color += vec3(1.0, 0.45, 0.08) * hot_filament * (0.4 + heat * 0.6);
		vec3 shared_core_fire = mix(vec3(0.91, 0.19, 0.025), vec3(1.0, 0.67, 0.18), 0.5 + 0.5 * broad);
		color = mix(color, shared_core_fire * (0.90 + texture_value * 0.18), core_boundary_blend * 0.50);
		vec3 shared_layer_fire = mix(vec3(0.91, 0.25, 0.035), vec3(1.0, 0.72, 0.24), 0.45 + broad * 0.32);
		vec3 boundary_bridge = mix(continuous_palette, shared_layer_fire * (0.92 + texture_value * 0.14), 0.42);
		float boundary_circulation = clamp(0.5 + boundary_wave / max(internal_width * 0.24, 0.001), 0.0, 1.0);
		boundary_bridge *= 0.92 + boundary_circulation * 0.16;
		color = mix(color, boundary_bridge, internal_boundary_blend * (0.24 + stellar_ignition * 0.18));

		// Animated line-art heat crests leave the stellar core and fade through
		// the next band. Sparse embers use stable angular cells, not particles.
		float upper_room = max(compacted_radius - core_outer, 0.0);
		float ignition_flame = smoothstep(0.10, 0.82, stellar_ignition);
		float quiet_reach = max(core_width * 1.35, upper_room * 0.38);
		float ignited_reach = max(core_width * 2.2, upper_room * 0.84);
		float flame_reach = min(mix(quiet_reach, ignited_reach, ignition_flame), upper_room);
		float from_core = radius - core_outer;
		float polar = atan(point.y, point.x);
		float wave_a = 0.5 + 0.5 * sin(polar * 9.0 - motion_time * 0.46 + broad * 4.0);
		float wave_b = 0.5 + 0.5 * sin(polar * 15.0 + motion_time * 0.28 + fine * 2.7);
		float crest_height = flame_reach * (0.18 + 0.60 * wave_a * wave_a + 0.22 * wave_b);
		float line_width = max(core_width * mix(0.035, 0.060, ignition_flame), upper_room * 0.009);
		float flame_outline = 1.0 - smoothstep(line_width, line_width * 2.8, abs(from_core - crest_height));
		float root_line = 1.0 - smoothstep(line_width, line_width * 2.4, abs(from_core - crest_height * 0.38));
		float above_core = step(0.0, from_core) * step(from_core, flame_reach);
		float heat_activity = 0.34 + heat * 0.66;
		float fire_lines = above_core * (flame_outline + root_line * 0.38) * heat_activity;
		vec3 fire_color = mix(vec3(0.95, 0.19, 0.025), vec3(1.0, 0.78, 0.25), wave_b);
		float molten_aura = above_core * (1.0 - smoothstep(0.0, flame_reach * 0.62, from_core));
		float aura_flow = 0.5 + 0.5 * sin(polar * 7.0 - motion_time * 0.32 + from_core * 0.22 + broad * 3.6);
		color = mix(color, vec3(0.76, 0.16, 0.018) + fire_color * aura_flow * 0.28, molten_aura * heat_activity * 0.40);
		color += fire_color * fire_lines * 0.58;

		float sector_coordinate = (polar + PI) / TAU * 29.0;
		float sector = floor(sector_coordinate);
		float sector_seed = hash21(vec2(sector, 31.7));
		float sector_centre = abs(fract(sector_coordinate) - 0.5);
		float ember_lift = fract(motion_time * (0.024 + sector_seed * 0.018) + sector_seed);
		float ember_radius = core_outer + flame_reach * (0.18 + ember_lift * 0.92);
		float ember_dot = 1.0 - smoothstep(0.035, 0.105, sector_centre);
		ember_dot *= 1.0 - smoothstep(line_width, line_width * 3.2, abs(radius - ember_radius));
		ember_dot *= step(0.74, sector_seed) * above_core * (1.0 - ember_lift) * heat_activity;
		color += vec3(1.0, 0.61, 0.13) * ember_dot * 0.58;
		// Only the converting annulus breaks into bright inward-flowing threads.
		float conversion_depth = (radius - animation_inner_radius) / max(animation_outer_radius - animation_inner_radius, 0.001);
		float front = exp(-pow((conversion_depth - (1.0 - conversion_progress)) * 14.0, 2.0));
		float threads = pow(0.5 + 0.5 * sin(atan(point.y, point.x) * 48.0 + broad * 3.0), 6.0);
		color += vec3(1.0, 0.45, 0.08) * converting * sin(clamp(conversion_progress, 0.0, 1.0) * PI) * (front * 0.16 + threads * 0.07);
		// Preserve the glow's hue instead of clipping each channel toward white.
		color /= max(1.0, max(color.r, max(color.g, color.b)));
	}
	if (sun_enabled && stellar_ignition > 0.001 && radius >= player_radius) {
		float motion_time = simulation_time * max(core_motion_speed, 0.0);
		float molten = smoothstep(0.02, 0.98, stellar_ignition);
		float active_surface = mix(compacted_radius, max(compacted_radius, molten_reservoir_radius), molten);
		float polar = atan(point.y, point.x);
		float edge_width = max(grain_diameter * 2.8, active_surface * 0.0065);
		float edge_wave = (sin(polar * 13.0 - motion_time * 0.31) +
			sin(polar * 23.0 + motion_time * 0.19) * 0.46) * edge_width * 0.58;
		float from_surface = active_surface - radius;
		float edge_crest = 1.0 - smoothstep(edge_width * 0.35, edge_width * 1.55, abs(from_surface - edge_width * 0.72 - edge_wave));
		float edge_aura = smoothstep(-edge_width * 0.20, edge_width * 0.45, from_surface) *
			(1.0 - smoothstep(edge_width * 0.35, edge_width * 4.8, from_surface));
		float edge_flow = 0.5 + 0.5 * sin(polar * 17.0 - motion_time * 0.27 + from_surface * 0.18);
		vec3 edge_color = mix(vec3(0.96, 0.22, 0.025), vec3(1.0, 0.73, 0.19), edge_flow);
		color = mix(color, edge_color, edge_aura * (0.20 + stellar_heat * 0.18));
		color += edge_color * edge_crest * (0.16 + stellar_heat * 0.19);

		float reservoir_depth = molten_reservoir_radius - compacted_radius;
		if (reservoir_depth > grain_diameter * 0.5) {
			float interface_width = max(grain_diameter * 4.5, min(reservoir_depth * 0.16, compacted_radius * 0.055));
			// The formed-body/liquid boundary has two slow counter-flows. This
			// makes the blend circulate while the star's silhouette remains fixed.
			float interface_polar = polar - motion_time * 0.024;
			float interface_counter_polar = polar + motion_time * 0.014;
			float interface_detail = sin(radius * 0.031 - motion_time * 0.041);
			float interface_wave = (sin(interface_polar * 8.0 + interface_detail * 1.8) +
				sin(interface_counter_polar * 19.0 - interface_detail * 1.3) * 0.55) * interface_width * 0.34;
			float interface_blend = 1.0 - smoothstep(interface_width * 0.25, interface_width * 1.45,
				abs(radius - compacted_radius - interface_wave));
			float turmoil = 0.5 + 0.5 * sin(interface_polar * 11.0 + interface_counter_polar * 4.0 + radius * 0.09 + interface_detail * 2.1);
			vec3 interface_color = mix(vec3(0.88, 0.16, 0.018), vec3(1.0, 0.64, 0.14), turmoil);
			color = mix(color, interface_color, interface_blend * molten * 0.58);
		}
		color /= max(1.0, max(color.r, max(color.g, color.b)));
	}
	COLOR = vec4(color, tint.a * alpha);
}
