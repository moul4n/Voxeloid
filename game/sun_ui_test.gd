extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func finish(field) -> void:
	for tick in 120:
		field.step(1.0 / 60.0)
func capture(main, suffix: String) -> void:
	main._layer_status_clock = 0.0
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../scratch/checks/sun-%s.png" % suffix)
func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.zoom_level = 0.75
	await capture(main, "empty")
	main.voxels.seed_uniform(6020)
	await capture(main, "warm-particles")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = main.core_action_rect().get_center()
	main._unhandled_input(event)
	check(main.voxels.sun_progression.player_level == 1 and main.voxels.count == 6000, "HUD absorb button did not transfer loose mass")
	check(main.voxels.form_core_layer(), "first HUD layer not ready")
	finish(main.voxels)
	await capture(main, "seed")
	for index in 6:
		main.voxels.spawn_grains(int(main.voxels.sun_progression.required_mass()))
		finish(main.voxels)
		check(main.voxels.form_core_layer(), "later Sun layer failed")
		if index == 2 or index == 5:
			for tick in 36:
				main.voxels.step(1.0 / 60.0)
			await capture(main, "compress-%d" % (index + 2))
		finish(main.voxels)
		if index == 1:
			main._refresh_progression()
			check(main._is_unlocked(&"action.compact_inner"), "stellar core densification action did not unlock")
			event.position = main.inner_button_rect(main.get_viewport_rect().size).get_center()
			main._unhandled_input(event)
			check(main.voxels.compaction_active, "stellar core milestone failed")
			var dense_state: Dictionary = main.voxels.get_sun_visual_state()
			check(float(dense_state.total_production_reward) > float(dense_state.production_reward), "densification reward was not shown in total production")
			check(main._is_unlocked(&"indicator.heat"), "densification did not reveal the heat indicator")
			await create_timer(0.42).timeout
			await capture(main, "densification-reward")
			finish(main.voxels)
		if index == 2:
			await capture(main, "ignition")
	main.zoom_level = 0.55
	await capture(main, "solar")
	check(main.voxels.get_sun_visual_state().stabilisation_available, "solar HUD state never unlocked")
	check(main.voxels.sun_progression.spin == 0.0, "rotation enabled without talent")
	main.voxels.clear()
	event.ctrl_pressed = true
	main.developer_mode = false
	main._unhandled_input(event)
	check(main.voxels.sun_progression.player_level == 0, "normal Ctrl-click bypassed player cost")
	main.developer_mode = true
	event.position = main.core_action_rect().get_center()
	main._unhandled_input(event)
	check(main.voxels.sun_progression.player_level == 1 and main.voxels.sun_progression.absorbed_mass == 0.0, "dev Ctrl-click did not grant a genuinely free level")
	if failures == 0:
		print("Sun UI checks passed: absorb input, densification reward, ignition/solar captures, separate player state, no automatic spin.")
	quit(1 if failures else 0)
