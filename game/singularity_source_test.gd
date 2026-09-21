extends SceneTree

const MainScene := preload("res://main.tscn")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func close_to(a: Vector2, b: Vector2, tolerance: float = 0.01) -> bool:
	return a.distance_to(b) <= tolerance

func source_screen_position(main, source: Dictionary) -> Vector2:
	var centre: Vector2 = main.get_viewport_rect().size * 0.5 + main.camera_pan
	return centre + Vector2.from_angle(float(source.angle)) * float(source.radius) * main.zoom_level

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	main.set_process(false)
	main.set_physics_process(false)
	var first: Dictionary = main.singularity_source()
	check(close_to(source_screen_position(main, first), main.singularity_screen_position()), "default arrival did not start behind H")
	main.camera_pan = Vector2(260, -140)
	main.zoom_level = 0.55
	var moved: Dictionary = main.singularity_source()
	check(close_to(source_screen_position(main, moved), main.singularity_screen_position()), "panned and zoomed arrival moved away from H")
	check(not is_equal_approx(float(first.angle), float(moved.angle)) and not is_equal_approx(float(first.radius), float(moved.radius)), "camera change did not change the world-space source")
	main.release_grains()
	check(main.voxels.batches.size() == 1, "H release did not create an arrival batch")
	var batch: Dictionary = main.voxels.batches[0]
	check(is_equal_approx(float(batch.angle), fposmod(float(moved.angle), TAU)), "arrival batch used the wrong H angle")
	check(is_equal_approx(float(batch.start_radius), float(moved.radius)), "arrival batch used the wrong H distance")
	main.zoom_level = 0.7
	var zoomed: Dictionary = main.singularity_source()
	main.release_grains()
	check(main.voxels.batches.size() == 2, "same-frame zoom merged arrivals from different H distances")
	check(is_equal_approx(float(main.voxels.batches[1].start_radius), float(zoomed.radius)), "zoomed arrival kept the previous H distance")
	if DisplayServer.get_name() != "headless":
		main.voxels.step(0.65)
		main._process(0.0)
		main.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../scratch/checks/singularity-screen-source.png")
	if failures == 0:
		print("Singularity source checks passed: fixed-screen H origin follows camera pan and zoom in world space.")
	quit(1 if failures else 0)
