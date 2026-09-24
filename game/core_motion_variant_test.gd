extends SceneTree

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

func capture(main, suffix: String) -> Image:
	main.grain_renderer.update_field(main.voxels, main.get_viewport_rect().size * 0.5, main.zoom_level)
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image()
	result.save_png("res://../scratch/checks/core-motion-%s.png" % suffix)
	return result

func changed_pixels(first: Image, second: Image, center: Vector2i, radius: int) -> int:
	var changed := 0
	for y in range(maxi(center.y - radius, 0), mini(center.y + radius + 1, first.get_height())):
		for x in range(maxi(center.x - radius, 0), mini(center.x + radius + 1, first.get_width())):
			if Vector2(x - center.x, y - center.y).length_squared() > radius * radius:
				continue
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.012:
				changed += 1
	return changed

func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.zoom_level = 3.5
	main.voxels.seed_uniform(976958)
	for layer in 7:
		check(main.voxels.form_core_layer(true), "core motion setup failed to form layer %d" % layer)
		finish(main.voxels)
	main.voxels.sun_progression.ignition_unlocked = true
	main.voxels.sun_progression.completed_smu = 1000.0
	var conserved_mass: float = main.voxels.total_mass()
	main.grain_renderer.core_motion_variant = 0
	var bands_a := await capture(main, "bands-a")
	finish(main.voxels, 120)
	var bands_b := await capture(main, "bands-b")
	main.grain_renderer.core_motion_variant = 1
	var plumes := await capture(main, "plumes")
	var center := Vector2i(main.get_viewport_rect().size * 0.5)
	var radius := int(ceil(main.voxels.compacted_radius * main.zoom_level))
	var moving_pixels := changed_pixels(bands_a, bands_b, center, radius)
	var variant_pixels := changed_pixels(bands_b, plumes, center, radius)
	check(moving_pixels > 40, "band core remained visually static over two seconds")
	check(variant_pixels > 40, "core motion variants rendered the same image")
	check(is_equal_approx(main.voxels.total_mass(), conserved_mass), "core motion changed logical mass")
	check(main.voxels.sun_progression.spin == 0.0, "core motion enabled body rotation")
	print("CORE_MOTION changed pixels: bands=%d variants=%d" % [moving_pixels, variant_pixels])
	if failures == 0:
		print("Core motion checks passed: both variants move, differ and preserve geometry.")
	quit(1 if failures else 0)
