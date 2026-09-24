extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func finish(field, ticks: int = 150) -> void:
	for tick in ticks:
		field.step(1.0 / 60.0)

func update_for(main, ticks: int) -> void:
	for tick in ticks:
		main.voxels.step(1.0 / 60.0)
		main.grain_renderer.update_field(main.voxels, main.get_viewport_rect().size * 0.5, main.zoom_level)

func capture(main, suffix: String) -> void:
	main.queue_redraw()
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../scratch/checks/molten-arrival-%s.png" % suffix)

func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.set_process(false)
	main.zoom_level = 0.25
	var field = main.voxels
	var renderer = main.grain_renderer

	field.seed_uniform(6000)
	check(field.form_core_layer(), "could not form first stellar layer")
	finish(field)
	for layer in 2:
		field.spawn_grains(int(field.sun_progression.required_mass()))
		finish(field)
		check(field.form_core_layer(), "could not form stellar layer %d" % (layer + 2))
		finish(field)
	renderer.update_field(field, main.get_viewport_rect().size * 0.5, main.zoom_level)
	check(not bool(field.get_sun_visual_state().get("ignited", false)), "molten presentation started before ignition")
	check(float(renderer.get_draw_counts().get("molten_surface_blend", 1.0)) < 0.01,
		"pre-ignition body did not retain its granular presentation")
	field.spawn_grains(int(field.sun_progression.required_mass()))
	finish(field)
	check(field.form_core_layer(), "could not form ignition stellar layer")
	finish(field)
	check(bool(field.get_sun_visual_state().get("ignited", false)), "fourth stellar layer did not reach ignition")
	renderer.update_field(field, main.get_viewport_rect().size * 0.5, main.zoom_level)
	var transition_blend := float(renderer.get_draw_counts().get("molten_surface_blend", 0.0))
	check(transition_blend > 0.0 and transition_blend < 0.20, "ignition did not begin as a gradual visual crossfade")

	# Let the presentation crossfade fully while retaining the same logical body.
	var body_before: float = float(field.total_mass())
	update_for(main, 840)
	var molten_state: Dictionary = renderer.get_draw_counts()
	check(float(molten_state.get("molten_surface_blend", 0.0)) > 0.99, "molten presentation did not finish its ignition crossfade")
	check(int(molten_state.settled) == 0, "ignited liquid retained a hidden settled-dot draw load")
	check(is_equal_approx(field.total_mass(), body_before), "molten visual transition changed body mass")
	check(is_equal_approx(renderer.get_visual_outer_radius(), float(field.compacted_radius)),
		"empty liquid reserve did not return ejections to the formed photosphere")

	var compacted_before: int = int(field.compacted_count)
	var loose_before: int = int(field.settled_count) - int(field.compacted_count)
	field.spawn_grains(500000, -0.55)
	var expected_total: float = body_before + 500000.0
	var observed_molten_impact := false
	var observed_molten_splash := false
	for tick in 220:
		field.step(1.0 / 60.0)
		renderer.update_field(field, main.get_viewport_rect().size * 0.5, main.zoom_level)
		for event in renderer._impact_events:
			observed_molten_impact = observed_molten_impact or float(event.get("molten", 0.0)) > 0.5
		for patch in renderer._bonded_patches:
			observed_molten_splash = observed_molten_splash or float(patch.get("molten", 0.0)) > 0.5
		if tick == 150:
			await capture(main, "impact")
	check(observed_molten_impact, "molten arrival did not create a hot impact")
	check(observed_molten_splash, "molten arrival used no splash event")
	check(field.count == field.settled_count and field.settled_count - field.compacted_count == loose_before + 500000,
		"molten arrival did not enter the uncommitted loose reservoir once")
	check(is_equal_approx(field.total_mass(), expected_total), "molten arrival changed conserved material")
	check(field.compacted_count == compacted_before, "molten arrival silently formed a committed layer")
	check(int(renderer.get_draw_counts().settled) == 0, "post-ignition arrival rebuilt a dot crust")
	var liquid_radius := float(renderer.get_draw_counts().get("molten_reservoir_radius", 0.0))
	var bulk_half_extent := float(renderer._bulk.scale.x) * 0.5
	check(bulk_half_extent >= liquid_radius, "molten reservoir exceeded its quad and flattened at four sides")
	check(is_equal_approx(renderer.get_visual_outer_radius(), liquid_radius),
		"halo and ejections did not move to the liquid reservoir edge")

	var player_owned_before := float(field.sun_progression.absorbed_mass)
	var reserve_before_feed: int = int(field.settled_count) - int(field.compacted_count)
	check(field.assimilate_player_core(), "player could not feed from liquid reserve")
	var reserve_after_feed: int = int(field.settled_count) - int(field.compacted_count)
	var transferred: int = reserve_before_feed - reserve_after_feed
	check(transferred > 0 and field.compacted_count == compacted_before, "feeding did not consume only uncommitted liquid")
	check(is_equal_approx(field.total_mass() + float(field.sun_progression.absorbed_mass),
		expected_total + player_owned_before), "feeding liquid lost or duplicated owned mass")
	renderer.update_field(field, main.get_viewport_rect().size * 0.5, main.zoom_level)
	await capture(main, "fed")

	# A fresh non-stellar field still uses the complete particle renderer.
	var granular = main.VoxelSystemScript.new(main.ElementsData.HYDROGEN, 10000)
	granular.seed_uniform(1000)
	renderer.update_field(granular, main.get_viewport_rect().size * 0.5, 1.0)
	var granular_state: Dictionary = renderer.get_draw_counts()
	check(float(granular_state.get("molten_surface_blend", 1.0)) < 0.01 and int(granular_state.settled) == 1000,
		"planet or pre-ignition mode lost the granular dot renderer")

	if failures == 0:
		print("Molten arrival checks passed: reversible presentation, liquid absorption, hot splash, exact reserve, player feeding and preserved granular mode.")
	quit(1 if failures else 0)
