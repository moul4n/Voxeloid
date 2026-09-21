extends SceneTree

const MainScene := preload("res://main.tscn")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	check(main.developer_mode, "developer launcher did not set --dev")
	check(main.dev_progression_panel != null and not main.dev_progression_panel.visible, "progression lab did not start hidden")
	var toggle := InputEventKey.new()
	toggle.keycode = KEY_F1
	toggle.pressed = true
	main._unhandled_input(toggle)
	check(main.dev_progression_panel.visible, "F1 did not open the progression lab")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../scratch/checks/dev-progression-lab.png")
	var before: StringName = main.progression_director.state.pinned_objective_id
	main._dev_complete_current_objective()
	check(main.progression_director.state.is_completed(before), "dev complete did not finish the selected objective")
	check(main.progression_director.state.unlocks.is_unlocked(&"indicator.capture_feedback"), "dev complete did not grant the objective reward")
	main.progression_tuning.metric_refresh_hz = 12.0
	main._dev_tuning_changed()
	check(is_equal_approx(main.progression_tuning.metric_refresh_seconds(), 1.0 / 12.0), "dev flow dial did not update refresh timing")
	main._dev_reset_progression()
	check(not main.progression_director.state.is_completed(&"sun.call_matter"), "dev reset retained completed guidance")
	if failures == 0:
		print("Developer progression lab checks passed: F1, completion override, tuning and reset.")
	quit(1 if failures else 0)
