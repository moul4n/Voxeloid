extends SceneTree

const MainScene := preload("res://main.tscn")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func capture(main, suffix: String) -> void:
	main.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../scratch/checks/progression-%s.png" % suffix)

func run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	await capture(main, "opening")
	main.voxels.seed_uniform(19)
	main._refresh_progression()
	await capture(main, "gather-core-target")
	check(not main._is_unlocked(&"action.feed_core"), "rendered player UI revealed Feed Core before 20 mass")
	main.voxels.seed_uniform(20)
	main._refresh_progression()
	await capture(main, "mass-unlock")
	var feed := InputEventMouseButton.new()
	feed.button_index = MOUSE_BUTTON_LEFT
	feed.pressed = true
	feed.position = main.core_action_rect().get_center()
	main._unhandled_input(feed)
	main._refresh_progression()
	await capture(main, "talent-unlock")
	await create_timer(0.42).timeout
	await capture(main, "core-feed")
	var open_tree := InputEventMouseButton.new()
	open_tree.button_index = MOUSE_BUTTON_LEFT
	open_tree.pressed = true
	open_tree.position = main.PlayerHud.talent_rect(main.get_viewport_rect().size).get_center()
	main._unhandled_input(open_tree)
	await capture(main, "talent-tree-open")
	var automatic: Dictionary = {}
	for node in main._talent_snapshot().nodes:
		if node.id == &"automatic_invocation":
			automatic = node
			break
	var spend := InputEventMouseButton.new()
	spend.button_index = MOUSE_BUTTON_LEFT
	spend.pressed = true
	spend.position = main.PlayerHud.talent_node_rect(main.get_viewport_rect().size, automatic).get_center()
	main._unhandled_input(spend)
	await capture(main, "first-talent")
	check(not main.space_backdrop.visible, "stellar background appeared after only one talent")
	main._buy_talent(&"resonant_pull", true)
	main._buy_talent(&"resonant_pull", true)
	await capture(main, "stellar-pull")
	main.voxels.seed_uniform(6000)
	main._refresh_progression()
	await capture(main, "compaction-ready")
	check(main._is_unlocked(&"action.compact_outer"), "rendered player UI never revealed compaction")
	check(main.space_backdrop.visible, "third talent spend did not reveal the stellar background")
	check(main.voxels.form_core_layer(), "rendered progression could not form First Matter")
	main._refresh_progression()
	# Prepare the earlier tutorial facts that this short render route deliberately skips.
	for pair in [[&"mass.total_gathered", 6000.0], [&"mass.body", 6000.0], [&"mass.core", 20.0], [&"core.level", 1.0], [&"capture.ambient_total", 1.0], [&"body.compactions", 1.0]]:
		main.progression_director.set_metric(pair[0], pair[1])
	main.progression_director.evaluate()
	await capture(main, "first-matter-boost")
	check(main.progression_director.current_objective().objective_id == &"sun.gather_layer_2", "rendered progression stopped after First Matter")
	check(is_equal_approx(main._talent_snapshot().automatic_rate, 1.45), "First Matter did not boost the live Flow talent")
	if failures == 0:
		print("Progression UI render passed: opening, talents, First Matter and its production boost captured.")
	quit(1 if failures else 0)
