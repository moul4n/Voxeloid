extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func click(main, rect: Rect2, ctrl: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.ctrl_pressed = ctrl
	event.position = rect.get_center()
	main._unhandled_input(event)
func finish(field) -> void:
	for tick in 100:
		field.step(1.0 / 60.0)
func run() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	# Exercise the retained planet-layer controls; Sun progression has its own UI test.
	main.voxels.sun_progression = null
	main.voxels.material.inner_layer_min_mass = 200000.0
	var size: Vector2 = main.get_viewport_rect().size
	main.voxels.seed_uniform(3000000)
	main.developer_mode = false
	click(main, main.automation_button_rect(size), true)
	check(not main.voxels.inner_automation_unlocked, "normal Ctrl-click granted upgrade")
	for i in 2:
		click(main, main.layer_button_rect(size))
		finish(main.voxels)
	check(main.voxels.compacted_count == 200000, "outer button did not form initial planet core")
	check(main.voxels.inner_layer_status().ready, "inner milestone did not become ready")
	main.zoom_level = 0.6
	await capture(main, "nested-before")
	click(main, main.inner_button_rect(size))
	check(main.voxels.compaction_active, "inner button did not start local animation")
	for tick in 20:
		main.voxels.step(1.0 / 60.0)
	var animated_layers: Array = main.voxels.get_body_layers()
	for index in range(2, animated_layers.size()):
		check(is_zero_approx(float(animated_layers[index].pulse)), "unrelated mantle or surface flickers during inner conversion")
	await capture(main, "nested-during")
	finish(main.voxels)
	await capture(main, "nested-after")
	var layers: Array = main.voxels.get_body_layers()
	check(layers.size() == 4, "core, two mantles and surface not present")
	check(main.voxels.count == 3000000 and main.voxels.compacted_count == 200000, "inner conversion changed collected count")
	check(int(layers[0].count) == 180000, "inner conversion did not use 90 percent")
	main.developer_mode = true
	click(main, main.automation_button_rect(size), true)
	check(main.voxels.inner_automation_unlocked and main.voxels.inner_automation_enabled, "dev Ctrl-click did not unlock automation")
	click(main, main.automation_button_rect(size))
	check(not main.voxels.inner_automation_enabled, "automation toggle cannot stop")
	main.change_element(1)
	check(main.voxels.inner_automation_unlocked and not main.voxels.inner_automation_enabled, "element selection discarded player upgrade")
	if failures == 0:
		print("Nested layer UI checks passed: manual outer, inner button, separate layers, upgrade gate and dev unlock.")
	quit(1 if failures else 0)
func capture(main, name: String) -> void:
	main._layer_status_clock = 0.0
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../scratch/checks/" + name + ".png")
