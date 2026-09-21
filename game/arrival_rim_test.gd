extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.zoom_level = 0.23
	main.voxels.seed_uniform(750000)
	main.voxels.spawn_grains(500000, -PI / 4.0)
	for tick in 204:
		main.voxels.step(1.0 / 60.0)
		if tick in [35, 83, 113, 125, 155, 203]:
			await process_frame
			main.grain_renderer.update_field(main.voxels, main.get_viewport_rect().size * 0.5, main.zoom_level)
			var draws: Dictionary = main.grain_renderer.get_draw_counts()
			var rim := int(draws.get("rim", 0))
			check(int(draws.settled) + int(draws.air) + rim <= 500000, "arrival exceeded shared draw budget")
			check(rim <= 2048, "rim grew beyond its fixed pool")
			check(absf(main.voxels.total_mass() - 1250000.0) < 0.01, "landing lost material")
			if tick == 35:
				check(main.voxels.settled_count == 750000 and rim == 0, "rim appeared before impact")
			if tick == 113:
				check(main.voxels.settled_count > 750000 and main.voxels.settled_count < 1250000 and rim > 0, "large arrival did not settle progressively onto rim")
				if DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					var with_rim := root.get_texture().get_image()
					main.grain_renderer._rim_instances.visible = false
					await process_frame
					await RenderingServer.frame_post_draw
					var without_rim := root.get_texture().get_image()
					var changed_pixels := 0
					for y in range(0, mini(400, with_rim.get_height())):
						for x in range(640, mini(1000, with_rim.get_width())):
							if with_rim.get_pixel(x, y) != without_rim.get_pixel(x, y):
								changed_pixels += 1
					check(changed_pixels > 0, "rim is allocated but invisible during active landing")
					print("RIM visible changed pixels during landing: ", changed_pixels)
					main.grain_renderer._rim_instances.visible = true
			if tick == 125:
				check(main.voxels.settled_count == 1250000 and rim > 0, "rim did not bridge flight to deposited matter")
			if tick == 203:
				check(rim == 0, "rim particles never retired")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://../scratch/checks/arrival-rim-%03d.png" % tick)
	main.voxels.spawn_grains(10000, 0.0)
	for tick in 115:
		main.voxels.step(1.0 / 60.0)
	main.grain_renderer.update_field(main.voxels, main.get_viewport_rect().size * 0.5, main.zoom_level)
	check(int(main.grain_renderer.get_draw_counts().get("rim", 0)) > 0, "reset check needs an active landing")
	main.voxels.seed_uniform(100)
	main.grain_renderer.update_field(main.voxels, main.get_viewport_rect().size * 0.5, main.zoom_level)
	await process_frame
	check(int(main.grain_renderer.get_draw_counts().get("rim", 0)) == 0, "seed reset kept old rim activity")
	main.voxels.clear()
	main.grain_renderer.update_field(main.voxels, main.get_viewport_rect().size * 0.5, main.zoom_level)
	await process_frame
	var cleared: Dictionary = main.grain_renderer.get_draw_counts()
	check(int(cleared.settled) + int(cleared.air) + int(cleared.get("rim", 0)) == 0, "clear left arrival visuals")
	if failures == 0:
		print("Arrival rim checks passed: progressive landing, conserved count, bounded pool, retirement and reset.")
	quit(1 if failures else 0)
