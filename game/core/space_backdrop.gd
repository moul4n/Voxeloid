extends Node2D
const SkyShader = preload("res://core/space_backdrop.gdshader")
var sky: ColorRect
var sky_material: ShaderMaterial
var view_size := Vector2(1280, 800)
var body_center := Vector2.ZERO
var body_radius := 0.0
var clock := 0.0
var heat := 0.0
var ignited := false
var solar_progress := 0.0

const PROMINENCE_SLOT_COUNT := 7
const ERUPTION_SLOT_COUNT := 4
const PROMINENCE_SAMPLES := 33
const ERUPTION_SAMPLES := 29

func _init() -> void:
	z_index = -3
	sky = ColorRect.new()
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.z_index = -1
	sky_material = ShaderMaterial.new()
	sky_material.shader = SkyShader
	# Bake the haze once at low resolution instead of evaluating noise per pixel.
	var noise := FastNoiseLite.new()
	noise.seed = 6421
	noise.frequency = 0.018
	noise.fractal_octaves = 3
	var haze := NoiseTexture2D.new()
	haze.width = 256
	haze.height = 256
	haze.noise = noise
	haze.seamless = true
	sky_material.set_shader_parameter("haze_texture", haze)
	sky.material = sky_material
	add_child(sky)

func update_view(size: Vector2, center: Vector2, radius: float, time: float, state: Dictionary) -> void:
	view_size = size
	body_center = center
	body_radius = radius
	clock = time
	heat = float(state.get("heat", 0.0))
	ignited = bool(state.get("ignited", false))
	solar_progress = clampf(float(state.get("solar_progress", 0.0)), 0.0, 1.0)
	sky.size = size
	sky_material.set_shader_parameter("simulation_time", time)
	queue_redraw()

func ejections_active() -> bool:
	return ignited and body_radius >= 30.0

func _draw() -> void:
	var parallax := (body_center - view_size * 0.5) * 0.07
	for i in 144:
		var point := Vector2(fposmod(float(i * 193 + 29) + parallax.x, view_size.x), fposmod(float(i * 317 + 71) + parallax.y, view_size.y))
		var brightness := 0.28 + 0.13 * sin(clock * (0.2 + float(i % 7) * 0.025) + float(i))
		var tint := Color("7297bb") if i % 3 else Color("bb9972")
		tint.a = brightness
		draw_circle(point, 1.15 if i % 13 == 0 else 0.65, tint)
	if body_radius <= 1.0:
		return
	var glow := Color("ee8127") if ignited else Color("c25c22")
	for ring in range(12, 0, -1):
		glow.a = (0.003 + heat * 0.008) * (1.0 - float(ring) / 15.0)
		draw_circle(body_center, body_radius + float(ring) * (2.0 + body_radius * 0.007), glow)
	if not ejections_active():
		return
	_draw_prominence_ribbons()
	_draw_eruptive_plumes()

func _draw_prominence_ribbons() -> void:
	# These arches stay tied to two photosphere footpoints. Only their plasma
	# threads and brightness travel. Each slot fades out before choosing new
	# footpoints, avoiding a visible jump around the star.
	var readable_scale := clampf(body_radius, 180.0, 720.0)
	for index in PROMINENCE_SLOT_COUNT:
		var slot_seed := index * 97 + 31
		var duration := lerpf(54.0, 86.0, _hash01(slot_seed + 7))
		var cycle_position := clock / duration + _hash01(slot_seed + 19)
		var cycle := int(floor(cycle_position))
		var age := fposmod(cycle_position, 1.0)
		var seed := slot_seed + cycle * 131
		var active_chance := lerpf(0.56, 0.82, solar_progress)
		if _hash01(seed + 43) > active_chance:
			continue
		var grow := smoothstep(0.02, 0.26, age)
		var drain := 1.0 - smoothstep(0.72, 0.98, age)
		var lifecycle := grow * drain
		if lifecycle < 0.01:
			continue
		var anchor := _hash01(seed + 3) * TAU
		var half_span := lerpf(0.065, 0.135, _hash01(seed + 11))
		var target_height := readable_scale * lerpf(0.09, 0.19, _hash01(seed + 17))
		var breath := 0.94 + 0.06 * sin(clock * 0.11 + float(seed) * 0.13)
		var height := target_height * grow * breath
		var base_alpha := lifecycle * (0.19 + heat * 0.15) * (0.84 + 0.16 * sin(clock * 0.15 + float(seed)))
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		var hot_thread := PackedVector2Array()
		for sample in PROMINENCE_SAMPLES:
			var t := float(sample) / float(PROMINENCE_SAMPLES - 1)
			var u := t * 2.0 - 1.0
			var arch := sin(t * PI)
			var flow_mix := 0.5 + 0.5 * sin(clock * 0.065 + float(seed) * 0.21)
			var flow_a := sin(t * PI * 3.0 + clock * 0.19 + float(seed) * 0.27)
			var flow_b := sin(t * PI * 5.0 - clock * 0.13 + float(seed) * 0.17)
			var liquid_wave := lerpf(flow_a, flow_b, flow_mix) * arch
			var angle := anchor + u * half_span + liquid_wave * 0.0055
			var liquid_lift := 1.0 + 0.075 * liquid_wave + 0.035 * sin(t * PI * 7.0 - clock * 0.09)
			var radius := body_radius + height * arch * liquid_lift
			outer.append(body_center + Vector2.from_angle(angle) * radius)
			var inner_radius := body_radius + (height * 0.77 + readable_scale * 0.007 * liquid_wave * grow) * arch
			inner.append(body_center + Vector2.from_angle(angle - 0.006 * arch) * inner_radius)
			var thread_wave := sin(t * PI * 9.0 - clock * 0.16 + float(seed) * 0.31) * arch
			var thread_radius := body_radius + height * arch * (0.88 + liquid_wave * 0.032 + thread_wave * 0.025)
			hot_thread.append(body_center + Vector2.from_angle(angle + thread_wave * 0.0038) * thread_radius)
		draw_polyline(outer, Color(0.94, 0.20, 0.025, base_alpha * 0.42), 5.5, true)
		draw_polyline(outer, Color(1.0, 0.48, 0.055, base_alpha), 1.7, true)
		draw_polyline(inner, Color(1.0, 0.72, 0.20, base_alpha * 0.62), 1.0, true)
		draw_polyline(hot_thread, Color(1.0, 0.86, 0.36, base_alpha * 0.48), 0.85, true)
		_draw_active_footpoints(outer, float(seed), base_alpha * grow)
		_draw_flowing_heat_threads(hot_thread, float(seed), base_alpha)
		_draw_counter_streams(outer, float(seed), base_alpha)

func _draw_active_footpoints(points: PackedVector2Array, seed: float, alpha: float) -> void:
	# Small breathing roots visually weld both ends of the magnetic loop into
	# the moving photosphere instead of leaving two static line endpoints.
	for end_index in [0, points.size() - 1]:
		var root := points[end_index]
		var radial := (root - body_center).normalized()
		var tangent := Vector2(-radial.y, radial.x)
		var pulse := 0.72 + 0.28 * sin(clock * 0.23 + seed * 0.17 + float(end_index) * 0.11)
		var tongue := root + radial * (4.0 + pulse * 5.0)
		draw_line(root - tangent * 3.5, root + tangent * 3.5,
			Color(1.0, 0.35, 0.035, alpha * 0.42), 4.0, true)
		draw_line(root, tongue, Color(1.0, 0.68, 0.14, alpha * pulse), 1.4, true)
		draw_circle(tongue, 1.2 + pulse * 0.8, Color(1.0, 0.84, 0.30, alpha * 0.72))

func _draw_flowing_heat_threads(points: PackedVector2Array, seed: float, alpha: float) -> void:
	# Short hot filaments flow continuously through the arch. Their sub-sample
	# interpolation avoids the stepped motion of point-to-point highlights.
	for filament in 3:
		var along := fposmod(clock * (0.031 + float(filament) * 0.004) + seed * 0.071 + float(filament) * 0.29, 1.0)
		var head := along * float(points.size() - 1)
		var trail := PackedVector2Array()
		for sample in 7:
			trail.append(_sample_polyline(points, head - float(sample) * 0.44))
		var fade := 0.62 + 0.20 * sin(clock * 0.19 + seed + float(filament))
		draw_polyline(trail, Color(1.0, 0.80, 0.25, alpha * fade), 1.15, true)

func _draw_counter_streams(points: PackedVector2Array, seed: float, alpha: float) -> void:
	# Two small packets move in opposite directions along each magnetic arch.
	var travel := fposmod(clock * 0.055 + seed * 0.173, 1.0)
	for direction in 2:
		var along := travel if direction == 0 else 1.0 - travel
		var centre_index := along * float(points.size() - 1)
		for offset in range(-2, 3):
			var strength := 1.0 - absf(float(offset)) / 3.0
			var point := _sample_polyline(points, centre_index + float(offset))
			draw_circle(point, 1.1 + strength * 0.65,
				Color(1.0, 0.82, 0.38, alpha * strength * 0.8))

func _sample_polyline(points: PackedVector2Array, sample_position: float) -> Vector2:
	var bounded := clampf(sample_position, 0.0, float(points.size() - 1))
	var lower := int(floor(bounded))
	var upper := mini(lower + 1, points.size() - 1)
	return points[lower].lerp(points[upper], bounded - float(lower))

func _hash01(value: int) -> float:
	return fposmod(sin(float(value) * 12.9898 + 78.233) * 43758.5453, 1.0)

func _draw_eruptive_plumes() -> void:
	# An event rises radially, opens and twists, then fades. Long staggered
	# cycles keep eruptions occasional. A fully faded slot can return at a new
	# position, so both location and active plume count change slowly.
	var readable_scale := clampf(body_radius, 180.0, 720.0)
	for index in ERUPTION_SLOT_COUNT:
		var slot_seed := index * 149 + 71
		var duration := lerpf(46.0, 74.0, _hash01(slot_seed + 5))
		var cycle_position := clock / duration + _hash01(slot_seed + 23)
		var cycle := int(floor(cycle_position))
		var age := fposmod(cycle_position, 1.0)
		var seed := slot_seed + cycle * 173
		if _hash01(seed + 47) > lerpf(0.42, 0.62, solar_progress):
			continue
		var appear := smoothstep(0.03, 0.14, age)
		var disappear := 1.0 - smoothstep(0.72, 0.98, age)
		var envelope := appear * disappear
		if envelope < 0.01:
			continue
		var rise := smoothstep(0.02, 0.82, age)
		var anchor := _hash01(seed + 13) * TAU
		var target_reach := readable_scale * lerpf(0.27, 0.46 + solar_progress * 0.08, _hash01(seed + 29))
		var reach := lerpf(readable_scale * 0.025, target_reach, rise)
		for strand in 3:
			var points := PackedVector2Array()
			var strand_offset := float(strand - 1)
			for sample in ERUPTION_SAMPLES:
				var t := float(sample) / float(ERUPTION_SAMPLES - 1)
				var taper := 1.0 - t
				var flow_mix := 0.5 + 0.5 * sin(clock * 0.055 + float(seed) * 0.19)
				var wave_a := sin(t * PI * 2.1 + clock * 0.21 + float(seed) * 0.12 + strand_offset * 0.8)
				var wave_b := sin(t * PI * 4.3 - clock * 0.12 + float(seed) * 0.08 - strand_offset * 0.55)
				var liquid_wave := lerpf(wave_a, wave_b, flow_mix)
				var curl_direction := lerpf(-1.0, 1.0, _hash01(seed + 37))
				var angle := anchor + curl_direction * t * t * lerpf(0.035, 0.085, _hash01(seed + 41))
				angle += liquid_wave * 0.014 * t + strand_offset * 0.004 * taper
				var liquid_reach := 1.0 + 0.075 * sin(t * PI * 3.0 - clock * 0.10 + float(seed)) * taper
				var radius := body_radius + reach * t * liquid_reach
				points.append(body_center + Vector2.from_angle(angle) * radius)
			var strand_alpha := envelope * (0.16 + heat * 0.15) * (1.0 - absf(strand_offset) * 0.18)
			var glow_color := Color(0.96, 0.24, 0.025, strand_alpha * 0.45)
			var core_color := Color(1.0, 0.58, 0.09, strand_alpha)
			draw_polyline(points, glow_color, 6.0, true)
			draw_circle(points[0], 3.0, glow_color)
			draw_circle(points[-1], 3.0, glow_color)
			draw_polyline(points, core_color, 1.5, true)
			draw_circle(points[0], 0.75, core_color)
			draw_circle(points[-1], 0.75, core_color)
