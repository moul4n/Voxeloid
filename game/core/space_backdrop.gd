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
	sky.size = size
	sky_material.set_shader_parameter("simulation_time", time)
	queue_redraw()

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
	if not ignited or body_radius < 30.0:
		return
	for index in 5:
		var points := PackedVector2Array()
		var anchor := float(index) * 1.37 + 0.3
		var activity := 0.6 + 0.4 * sin(clock * 0.4 + float(index) * 1.8)
		for sample in 17:
			var t := float(sample) / 16.0
			var angle := anchor + (t - 0.5) * 0.12
			var radius := body_radius + sin(t * PI) * body_radius * 0.085 * activity
			points.append(body_center + Vector2.from_angle(angle) * radius)
		draw_polyline(points, Color(0.95, 0.35, 0.045, 0.12 + activity * 0.12), 3.0, true)
		draw_polyline(points, Color(1.0, 0.61, 0.11, 0.24 + activity * 0.2), 1.0, true)
