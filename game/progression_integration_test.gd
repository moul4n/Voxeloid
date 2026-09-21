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
	main.set_process(false)
	main.set_physics_process(false)
	check(not main.developer_mode, "normal start enabled developer mode")
	check(not main.space_backdrop.visible, "normal start showed the decorative star field")
	check(not main.dust_renderer.visible, "normal start showed ambient dust before discovery")
	check(main.progression_director.current_objective().objective_id == &"sun.call_matter", "normal start did not select the first target")
	check(main.notification_tour.current_step().target_id == "spawn_orb", "opening guidance did not point at the material orb")
	var clear_event := InputEventKey.new()
	clear_event.keycode = KEY_C
	clear_event.pressed = true
	main.voxels.seed_uniform(2)
	main._unhandled_input(clear_event)
	check(main.voxels.count == 2, "release build accepted the developer clear key")
	main.voxels.seed_uniform(19)
	main._refresh_progression()
	check(main.progression_director.current_objective().objective_id == &"sun.hold_material", "20-mass target was not shown before the Core action")
	check(main.progression_director.current_objective().title == "Gather at least 20 mass", "20-mass target copy is not player-facing")
	check(not main._is_unlocked(&"action.feed_core"), "Core action appeared before 20 mass")
	main.voxels.seed_uniform(20)
	main._refresh_progression()
	check(main._is_unlocked(&"indicator.body_mass"), "settled matter did not reveal the mass indicator")
	check(main._is_unlocked(&"action.feed_core"), "settled matter did not reveal the Core action")
	var feed := InputEventMouseButton.new()
	feed.button_index = MOUSE_BUTTON_LEFT
	feed.pressed = true
	feed.position = main.core_action_rect().get_center()
	main._unhandled_input(feed)
	main._refresh_progression()
	check(main.voxels.sun_progression.player_level == 1, "player Core action was not wired to the existing model")
	check(main._core_feed_remaining > 0.0 and main._core_feed_amount == 20, "feeding the Core did not start the inward mass animation")
	check(main._is_unlocked(&"ui.talents"), "first Core level did not reveal the talent placeholder")
	main.voxels.seed_uniform(6000)
	main._refresh_progression()
	check(main._is_unlocked(&"action.compact_outer"), "first-shell mass did not unlock compaction")
	var compact_rect: Rect2 = main.layer_button_rect(main.get_viewport_rect().size)
	check(compact_rect.position.x == 34.0 and compact_rect.size == Vector2(250, 52), "player compaction action is not in the compact left action rail")
	check(main.grain_renderer.z_index <= -3, "world impact flashes can draw over player dialogs")
	check(main.voxels.form_core_layer(), "first layer could not be formed after its progression unlock")
	main._refresh_progression()
	check(main._is_unlocked(&"camera.wide"), "first permanent layer did not unlock the wider camera range")
	check(main._zoom_limits().x < main.progression_tuning.opening_min_zoom, "camera range did not widen after compaction")
	if failures == 0:
		print("Progression integration checks passed: clean start, gated UI, Core action, compaction and camera unlock.")
	quit(1 if failures else 0)
