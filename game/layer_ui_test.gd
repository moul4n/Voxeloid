extends SceneTree
var failed := false
func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func click_layer(main, ctrl: bool) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.ctrl_pressed = ctrl
	click.position = main.layer_button_rect(main.get_viewport_rect().size).get_center()
	main._unhandled_input(click)

func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.developer_mode = false
	main.voxels.seed_uniform(1000)
	click_layer(main, true)
	check(main.voxels.compacted_count == 0, "normal Ctrl-click bypassed layer requirements")
	main.developer_mode = true
	click_layer(main, true)
	check(main.voxels.compacted_count > 0 and main.voxels.count == 1000, "dev layer unlock failed or changed material count")
	main.voxels.clear()
	main.developer_mode = false
	for population in [100000, 750000, 1000000000]:
		main.voxels.seed_uniform(population)
		for zoom in [1.0, 0.002]:
			main.grain_renderer.update_field(main.voxels, Vector2.ZERO, zoom)
			var diameter: float = main.grain_renderer._surface_material.get_shader_parameter("display_diameter")
			var expected: float = main.voxels.grain_size * sqrt(float(population) / mini(population, main.grain_renderer.capacity))
			check(is_equal_approx(diameter, expected), "sample coverage shrinks with population or zoom")
	main.voxels.seed_uniform(750000)
	check(main.voxels.layer_status().ready, "750k compacted hydrogen should offer a layer")
	check(main.voxels.compacted_count == 0, "layer formed automatically")
	for zoom in [2.2, 1.0, 0.32, 0.01, 0.002]:
		main.zoom_level = zoom
		var rings: Array[float] = main.range_ring_radii(Vector2(1280, 800), Vector2(640, 400))
		check(rings.size() >= 3 and rings.size() <= 31, "range rings do not cover zoom")
		check(rings[0] * zoom >= 100.0 and rings[0] * zoom <= 275.0, "range ring spacing is unreadable")
	main.zoom_level = 0.32
	await capture(main, "loose-750k")
	click_layer(main, false)
	check(main.voxels.compacted_count > 0 and main.voxels.count == 750000, "ready layer click failed")
	check(main.voxels.compaction_active, "layer creation did not start animation")
	var initial_outer: float = main.voxels.max_height
	await capture(main, "forming-750k")
	for tick in 21:
		main.voxels.step(1.0 / 60.0)
	await capture(main, "shrinking-750k")
	for tick in 69:
		main.voxels.step(1.0 / 60.0)
	check(not main.voxels.compaction_active and main.voxels.max_height < initial_outer, "outer material did not follow shrinking core")
	await capture(main, "formed-750k")
	var draws: Dictionary = main.grain_renderer.get_draw_counts()
	check(int(draws.settled_logical) + main.voxels.compacted_count == main.voxels.settled_count, "renderer double-counted compacted grains")
	main.voxels.clear()
	await process_frame
	check(main.voxels.compacted_count == 0, "clear retained core layer")
	if not failed:
		print("Layer UI checks passed: gating, dev bypass, manual creation, rings, renderer, clear.")
	quit(1 if failed else 0)

func capture(main, label: String) -> void:
	main._layer_status_clock = 0.0
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../scratch/checks/" + label + ".png")
