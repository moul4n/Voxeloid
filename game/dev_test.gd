extends SceneTree

const MainScene := preload("res://main.tscn")

func check(condition: bool, message: String) -> bool:
	if not condition:
		push_error("DEV CONTROL CHECK FAILED: " + message)
		quit(1)
		return false
	return true

func mouse(button: MouseButton, pressed: bool, ctrl := false) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = Vector2(1130, 70)
	event.ctrl_pressed = ctrl
	return event

func _initialize() -> void:
	var main = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	if not check(main.developer_mode and main.voxels.capacity == 1000000000, "start-dev did not enable the billion-grain developer mode"): return
	main.developer_mode = true
	main.spawn_amount = 10
	main.create_element_menu()
	main._unhandled_input(mouse(MOUSE_BUTTON_WHEEL_UP, true, true))
	if not check(main.spawn_amount == 20, "Ctrl-wheel did not raise the amount by 10"): return
	main.spawn_amount = 90
	main._unhandled_input(mouse(MOUSE_BUTTON_WHEEL_UP, true, true))
	if not check(main.spawn_amount == 100, "Ctrl-wheel did not reach 100 in 10-grain steps"): return
	main._unhandled_input(mouse(MOUSE_BUTTON_WHEEL_UP, true, true))
	if not check(main.spawn_amount == 200, "Ctrl-wheel did not change to 100-grain steps"): return
	main._unhandled_input(mouse(MOUSE_BUTTON_WHEEL_DOWN, true, true))
	if not check(main.spawn_amount == 100, "Ctrl-wheel did not return to 100 in 100-grain steps"): return
	main._unhandled_input(mouse(MOUSE_BUTTON_WHEEL_DOWN, true, true))
	if not check(main.spawn_amount == 90, "Ctrl-wheel did not return to 10-grain steps below 100"): return
	main.spawn_amount = 10
	main._unhandled_input(mouse(MOUSE_BUTTON_WHEEL_DOWN, true, true))
	if not check(main.spawn_amount == 10, "Ctrl-wheel went below the 10-grain floor"): return
	main.spawn_amount = 10000
	main._unhandled_input(mouse(MOUSE_BUTTON_WHEEL_UP, true, true))
	if not check(main.spawn_amount == 20000, "10k-to-20k scroll step failed"): return
	main.spawn_amount = 100000
	main._unhandled_input(mouse(MOUSE_BUTTON_WHEEL_DOWN, true, true))
	if not check(main.spawn_amount == 90000, "100k-to-90k scroll step failed"): return
	main.spawn_amount = 500000
	main._unhandled_input(mouse(MOUSE_BUTTON_WHEEL_UP, true, true))
	if not check(main.spawn_amount == 500000, "Ctrl-wheel exceeded the 500,000-grain ceiling"): return
	main.spawn_amount = 10
	main._unhandled_input(mouse(MOUSE_BUTTON_LEFT, true, true))
	if not check(main.element_menu.visible and main.voxels.count == 0 and not main.holding_orb, "Ctrl-click did not show the selector without spawning"): return
	main.change_element(2)
	if not check(main.voxels.material.id == "C" and main.voxels.count == 0, "element change did not clear and select carbon"): return
	main._unhandled_input(mouse(MOUSE_BUTTON_LEFT, true))
	if not check(main.voxels.count == 10 and main.holding_orb, "dev click did not release the selected amount"): return
	main.spawn_clock = 0.0
	main._physics_process(1.0)
	if not check(main.voxels.count == 20, "dev hold did not release the selected amount per second"): return
	main._notification(main.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	if not check(not main.holding_orb, "focus loss did not stop the held release"): return
	main.voxels.clear()
	main.spawn_amount = 500000
	main._unhandled_input(mouse(MOUSE_BUTTON_LEFT, true))
	if not check(main.voxels.count == 500000, "maximum generator click did not emit 500k"): return
	main._physics_process(1.0)
	if not check(main.voxels.count == 1000000, "maximum generator hold did not emit another 500k per second"): return
	main._unhandled_input(mouse(MOUSE_BUTTON_LEFT, false))
	print("Dev control check passed: limits, selector, maximum click and hold, and focus loss.")
	quit(0)
