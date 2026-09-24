extends SceneTree

const Field := preload("res://core/material_field.gd")
const Renderer := preload("res://core/field_renderer.gd")

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func finish(field, ticks: int = 100) -> void:
	for tick in ticks:
		field.step(1.0 / 60.0)

func capture(field, renderer, zoom: float, suffix: String) -> Image:
	renderer.update_field(field, root.get_visible_rect().size * 0.5, zoom)
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image()
	result.save_png("res://../scratch/checks/stellar-layers-%s.png" % suffix)
	return result

func annulus_changes(first: Image, second: Image, center: Vector2, inner_radius: float, outer_radius: float) -> int:
	var changed := 0
	var bounds := int(ceil(outer_radius)) + 2
	for y in range(maxi(int(center.y) - bounds, 0), mini(int(center.y) + bounds + 1, first.get_height())):
		for x in range(maxi(int(center.x) - bounds, 0), mini(int(center.x) + bounds + 1, first.get_width())):
			var distance := Vector2(float(x), float(y)).distance_to(center)
			if distance < inner_radius or distance > outer_radius:
				continue
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.012:
				changed += 1
	return changed

func run() -> void:
	var field = Field.new()
	field.enable_sun_progression()
	field.seed_uniform(976958)
	for layer in 7:
		check(field.form_core_layer(true), "stellar motion setup failed at layer %d" % layer)
		finish(field)
	field.sun_progression.ignition_unlocked = true
	field.sun_progression.completed_smu = 1000.0
	var renderer = Renderer.new(500000)
	root.add_child(renderer)
	renderer.core_motion_variant = 1
	var zoom := 300.0 / maxf(field.compacted_radius, 1.0)
	var first := await capture(field, renderer, zoom, "start")
	finish(field, 120)
	var second := await capture(field, renderer, zoom, "moving")
	var layers: Array = field.get_body_layers()
	var center := root.get_visible_rect().size * 0.5
	for index in layers.size():
		var layer: Dictionary = layers[index]
		var changed := annulus_changes(first, second, center, float(layer.inner_radius) * zoom, float(layer.outer_radius) * zoom)
		print("STELLAR_LAYER %d changed_pixels=%d" % [index, changed])
		check(changed > 40, "stellar layer %d remained visually static" % index)

	renderer.core_motion_speed = 0.0
	field.material = field.material.duplicate(true)
	field.material.flow_rate = 0.0
	var frozen_a := await capture(field, renderer, zoom, "frozen-a")
	finish(field, 120)
	var frozen_b := await capture(field, renderer, zoom, "frozen-b")
	var frozen_changes := annulus_changes(frozen_a, frozen_b, center,
		float(layers[0].inner_radius) * zoom, float(layers[layers.size() - 1].outer_radius) * zoom)
	print("STELLAR_LAYER frozen_changed_pixels=%d" % frozen_changes)
	# Compatibility rendering can vary a few edge pixels between identical
	# frames. Anything below this tiny raster tolerance is visually frozen.
	check(frozen_changes <= 64, "zero motion speed did not freeze formed-layer animation")
	check(absf(field.total_mass() - 976958.0) < 0.01, "stellar animation changed logical mass")
	check(field.sun_progression.spin == 0.0, "stellar animation enabled body rotation")
	if failures == 0:
		print("Stellar layer motion checks passed: every zone moves, reduced motion freezes, mass and spin stay fixed.")
	quit(1 if failures else 0)
