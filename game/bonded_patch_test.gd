extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.zoom_level = 0.18
	var renderer = main.grain_renderer
	main.voxels.seed_uniform(750000)
	main.voxels.spawn_grains(500000, -PI / 4.0)
	var observed_impact := false
	var observed_patch := false
	for tick in 130:
		main.voxels.step(1.0 / 60.0)
		renderer.update_field(main.voxels, Vector2(640, 400), main.zoom_level)
		var active: Dictionary = renderer.get_draw_counts()
		observed_impact = observed_impact or int(active.impacts) == 1
		observed_patch = observed_patch or int(active.patches) == 1
		if tick == 70 and DisplayServer.get_name() != "headless":
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../scratch/checks/bonded-impact.png")
	var draws: Dictionary = renderer.get_draw_counts()
	check(observed_impact, "one qualifying arrival did not create one impact event")
	check(observed_patch, "one qualifying arrival did not create one bonded patch")
	check(int(draws.settled) + int(draws.air) + int(draws.rim) <= 500000, "effects exceeded shared grain budget")
	check(absf(main.voxels.total_mass() - 1250000.0) < 0.01, "visual effects changed logical mass")

	renderer._clear_visual_effects()
	renderer._add_bonded_patch(0.01, 10.0, 0.8, 1, 2.0)
	renderer._add_bonded_patch(TAU - 0.01, 10.1, 0.8, 2, 2.0)
	check(renderer._bonded_patches.size() == 1, "patches did not merge across the angular seam")

	renderer._clear_visual_effects()
	for index in 80:
		renderer._add_bonded_patch(float(index) * TAU / 80.0, float(index), 0.5, index + 10, 2.0)
	check(renderer._bonded_patches.size() <= 64, "bonded patch pool exceeded its fixed capacity")
	for index in 48:
		renderer._add_impact_event(float(index) * TAU / 48.0, float(index), 0.5, index + 100, 2.0)
	check(renderer._impact_events.size() <= 32, "impact event pool exceeded its fixed capacity")

	main.voxels.clear()
	renderer.update_field(main.voxels, Vector2(640, 400), 0.23)
	check(renderer._bonded_patches.is_empty() and renderer._impact_events.is_empty(), "clear retained visual effects")
	if failures == 0:
		print("Bonded effect checks passed: one event per arrival, seam merging, fixed capacities, exact mass and clear invalidation.")
	quit(1 if failures else 0)
